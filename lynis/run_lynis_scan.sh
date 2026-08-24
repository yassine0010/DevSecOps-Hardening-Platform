#!/bin/bash
# =============================================================================
# LYNIS HARDENED SCAN RUNNER
# Purpose:  Run Lynis inside the network namespace with all security controls
# Run as:   sudo bash 02_run_lynis_scan.sh
# =============================================================================

set -euo pipefail

LYNIS_INSTALL_DIR="/usr/local/lynis"
LYNIS_LOG_DIR="/var/log/lynis"
LYNIS_REPORT_DIR="/var/log/lynis/reports"
BASELINE_DIR="/etc/lynis-security"
BASELINE_FILE="${BASELINE_DIR}/baseline.sha256"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="${LYNIS_REPORT_DIR}/report_${TIMESTAMP}.dat"
LOG_FILE="${LYNIS_LOG_DIR}/lynis_${TIMESTAMP}.log"

log()  { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
fail() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && fail "Must run as root."

# -----------------------------------------------------------------------------
# STEP 1: Integrity check BEFORE running the scan
# -----------------------------------------------------------------------------
# This is the dead man's switch — we verify Lynis hasn't been tampered with
# BEFORE trusting it to run on our system. If this fails, we abort entirely.
log "Running pre-scan integrity check..."

if [[ ! -f "${BASELINE_FILE}" ]]; then
    fail "Baseline file not found at ${BASELINE_FILE}. Run 01_install_lynis.sh first."
fi

# Re-hash all the same files we hashed at install time and compare
CURRENT_HASH=$(find "${LYNIS_INSTALL_DIR}" -type f \( \
    -name "lynis" \
    -o -name "*.sh" \
    -o -name "*.inc" \
    -o -name "RELEASE" \
    -o -name "default.prf" \
\) | sort | xargs sha256sum)

BASELINE_HASH=$(cat "${BASELINE_FILE}")

if [[ "${CURRENT_HASH}" != "${BASELINE_HASH}" ]]; then
    fail "INTEGRITY CHECK FAILED — Lynis files have changed since baseline was recorded.
    This may indicate tampering. DO NOT run the scan.
    Investigate immediately, then re-install from a verified source."
fi

log "Integrity check passed. Lynis files match baseline."

# -----------------------------------------------------------------------------
# STEP 2: Verify the network namespace exists
# -----------------------------------------------------------------------------
if ! ip netns list | grep -q "lynis-ns"; then
    log "Network namespace 'lynis-ns' not found. Creating it now..."
    ip netns add lynis-ns
fi

# -----------------------------------------------------------------------------
# STEP 3: Run the scan inside the network namespace
# -----------------------------------------------------------------------------
# ip netns exec lynis-ns → run the following command inside the isolated namespace
# --logfile           → where to write the detailed log
# --report-file       → where to write the machine-readable report
# --quiet             → suppress interactive prompts (safe for automation)
# --no-colors         → cleaner output for log files
log "Starting Lynis scan inside isolated network namespace..."
log "Report will be saved to: ${REPORT_FILE}"

ip netns exec lynis-ns \
    "${LYNIS_INSTALL_DIR}/lynis" audit system \
    --logfile "${LOG_FILE}" \
    --report-file "${REPORT_FILE}" \
    --quiet \
    --no-colors

SCAN_EXIT_CODE=$?

# -----------------------------------------------------------------------------
# STEP 4: Lock down the report immediately after scan completes
# -----------------------------------------------------------------------------
# The report now exists and contains a full weakness map of this system.
# Lock it down immediately.
if [[ -f "${REPORT_FILE}" ]]; then
    chmod 600 "${REPORT_FILE}"    # only root can read
    chown root:root "${REPORT_FILE}"
    log "Report secured: ${REPORT_FILE} (permissions: 600)"
fi

if [[ -f "${LOG_FILE}" ]]; then
    chmod 600 "${LOG_FILE}"
    chown root:root "${LOG_FILE}"
fi

# -----------------------------------------------------------------------------
# STEP 5: Extract the hardening index score for alerting
# -----------------------------------------------------------------------------
# Lynis embeds a "hardening index" score in the report (0–100).
# We extract it and log it — so you can track improvement over time.
if [[ -f "${REPORT_FILE}" ]]; then
    HARDENING_INDEX=$(grep "^hardening_index=" "${REPORT_FILE}" | cut -d= -f2 || echo "unknown")
    log "Hardening index: ${HARDENING_INDEX}/100"
    echo "${TIMESTAMP} hardening_index=${HARDENING_INDEX}" >> "${LYNIS_LOG_DIR}/hardening_history.log"
fi

# -----------------------------------------------------------------------------
# STEP 6: Ship report off-host (placeholder — configure your destination)
# -----------------------------------------------------------------------------
# Uncomment and configure one of these options:

# Option A: SCP to jump box
# scp -i /root/.ssh/jumpbox_key "${REPORT_FILE}" lynis-collector@jumpbox-ip:/secure/lynis/reports/

# Option B: Send to central log server via rsync
# rsync -az --delete "${REPORT_FILE}" logserver:/var/log/lynis-reports/$(hostname)/

log "REMINDER: Ship report off-host to your centralized log server."
log "          Local copy alone is not sufficient — a compromised host can delete it."

echo ""
echo "============================================================"
echo " Lynis scan complete."
echo " Hardening index: ${HARDENING_INDEX}/100"
echo " Report: ${REPORT_FILE}"
echo " Log:    ${LOG_FILE}"
echo "============================================================"

exit ${SCAN_EXIT_CODE}