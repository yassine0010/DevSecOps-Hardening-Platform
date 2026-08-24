#!/bin/bash
# =============================================================================
# LYNIS SECURED INSTALLATION SCRIPT
# Version:  3.1.7 (latest stable as of June 2026)
# Purpose:  Download, verify, and install Lynis with full security controls
# Run as:   sudo bash 01_install_lynis.sh
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
LYNIS_VERSION="3.1.7"
LYNIS_INSTALL_DIR="/usr/local/lynis"
LYNIS_LOG_DIR="/var/log/lynis"
LYNIS_REPORT_DIR="/var/log/lynis/reports"
BASELINE_DIR="/etc/lynis-security"
BASELINE_FILE="${BASELINE_DIR}/baseline.sha256"

# IMPORTANT: Both the tarball AND signature must come from the SAME source.
# GitHub auto-generates its own tarball which differs from CISOfy's — the
# signature will never match a GitHub tarball because CISOfy didn't sign it.
# Always download from cisofy.com/files/ where the signed tarball lives.
CISOFY_BASE_URL="https://downloads.cisofy.com/lynis"
DOWNLOAD_URL="${CISOFY_BASE_URL}/lynis-${LYNIS_VERSION}.tar.gz"
SIGNATURE_URL="${CISOFY_BASE_URL}/lynis-${LYNIS_VERSION}.tar.gz.asc"

# SHA256 of the official CISOfy tarball for 3.1.7
# Source: https://cisofy.com/downloads/lynis/
# Used as a first sanity check before GPG verification
EXPECTED_SHA256="b5314a07fd85fa3ffc7da57b508f0108ec3280d84e4af823f805d95cbbc2428c"

# CISOfy GPG signing key — tarball signing key (NOT the apt repo key)
# Primary key fingerprint verified via: gpg --fingerprint software@cisofy.com
# Signing subkey (3E82FB7C) certified by primary key — used to sign 3.1.7
CISOFY_GPG_KEY_URL="https://cisofy.com/files/cisofy-software.pub"
CISOFY_GPG_KEY_EMAIL="software@cisofy.com"
CISOFY_PRIMARY_FINGERPRINT="84FAA9983B24AEF24D6C87F1FEBB7D1812576482"
CISOFY_SUBKEY_ID="3E82FB7C68F57341349ED2C17A9A1D9D5B27C6D3"
CISOFY_KEYSERVER="keyserver.ubuntu.com"

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------
log()  { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
warn() { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
fail() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && fail "This script must be run as root (sudo)."

# -----------------------------------------------------------------------------
# STEP 1: Install required dependencies
# -----------------------------------------------------------------------------
log "Installing dependencies..."
apt-get update -qq
apt-get install -y -qq gnupg wget coreutils iproute2 strace

# -----------------------------------------------------------------------------
# STEP 2: Import CISOfy primary GPG key
# -----------------------------------------------------------------------------
log "Downloading CISOfy primary GPG key..."
wget -q -O /tmp/cisofy-software.pub "${CISOFY_GPG_KEY_URL}" \
    || fail "Failed to download CISOfy GPG key."

log "Importing CISOfy primary GPG key..."
gpg --import /tmp/cisofy-software.pub 2>/dev/null \
    || fail "Failed to import CISOfy primary GPG key."

rm -f /tmp/cisofy-software.pub

# -----------------------------------------------------------------------------
# STEP 3: Verify primary key fingerprint
# -----------------------------------------------------------------------------
log "Verifying primary key fingerprint..."

IMPORTED_FINGERPRINT=$(gpg --with-colons --fingerprint "${CISOFY_GPG_KEY_EMAIL}" 2>/dev/null \
    | grep "^fpr" \
    | head -1 \
    | cut -d: -f10 \
    | tr '[:lower:]' '[:upper:]')

[[ -z "${IMPORTED_FINGERPRINT}" ]] && \
    fail "Could not extract fingerprint. Run: sudo gpg --fingerprint ${CISOFY_GPG_KEY_EMAIL}"

log "Imported fingerprint: ${IMPORTED_FINGERPRINT}"
log "Expected fingerprint: ${CISOFY_PRIMARY_FINGERPRINT}"

[[ "${IMPORTED_FINGERPRINT}" != "${CISOFY_PRIMARY_FINGERPRINT}" ]] && \
    fail "PRIMARY KEY FINGERPRINT MISMATCH. Possible key substitution attack. Do NOT proceed."

log "Primary key fingerprint verified."

# -----------------------------------------------------------------------------
# STEP 4: Import signing subkey (used to sign 3.1.7)
# -----------------------------------------------------------------------------
# CISOfy added a new signing subkey in October 2025 which was used to sign
# Lynis 3.1.7. GPG trust model: primary key certifies the subkey, so if we
# trust the primary (verified above), we trust its certified subkeys.
log "Importing CISOfy signing subkey from keyserver..."

gpg --keyserver "${CISOFY_KEYSERVER}" \
    --recv-keys "${CISOFY_SUBKEY_ID}" 2>/dev/null \
    || fail "Failed to fetch signing subkey from ${CISOFY_KEYSERVER}.
    Check internet access and try again."

# Confirm the subkey is now listed under the CISOfy key
gpg --with-colons --fingerprint "${CISOFY_GPG_KEY_EMAIL}" 2>/dev/null \
    | grep -i "${CISOFY_SUBKEY_ID}" > /dev/null \
    || fail "Signing subkey ${CISOFY_SUBKEY_ID} not found under ${CISOFY_GPG_KEY_EMAIL}.
    Cannot proceed with verification."

log "Signing subkey verified and linked to CISOfy primary key."

# -----------------------------------------------------------------------------
# STEP 5: Download tarball AND signature from the same CISOfy source
# -----------------------------------------------------------------------------
# Both files must come from cisofy.com/files/ — NOT GitHub.
# GitHub auto-generates tarballs with different content/structure.
# CISOfy only signs the tarball they host themselves.
log "Downloading Lynis ${LYNIS_VERSION} tarball from cisofy.com..."

TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

wget -q -O "${TMPDIR}/lynis.tar.gz" "${DOWNLOAD_URL}" \
    || fail "Failed to download Lynis tarball from ${DOWNLOAD_URL}"

log "Downloading signature file from cisofy.com..."
wget -q -O "${TMPDIR}/lynis.tar.gz.asc" "${SIGNATURE_URL}" \
    || fail "Failed to download signature file from ${SIGNATURE_URL}"

log "Downloads complete."

# -----------------------------------------------------------------------------
# STEP 6: SHA256 sanity check first
# -----------------------------------------------------------------------------
# Quick integrity check before the more expensive GPG verification.
log "Verifying SHA256 checksum..."

ACTUAL_SHA256=$(sha256sum "${TMPDIR}/lynis.tar.gz" | awk '{print $1}')

log "Actual SHA256:   ${ACTUAL_SHA256}"
log "Expected SHA256: ${EXPECTED_SHA256}"

[[ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]] && \
    fail "SHA256 MISMATCH.
    Expected: ${EXPECTED_SHA256}
    Got:      ${ACTUAL_SHA256}
    File is corrupted or tampered. Do NOT proceed."

log "SHA256 checksum verified."

# -----------------------------------------------------------------------------
# STEP 7: GPG signature verification
# -----------------------------------------------------------------------------
log "Verifying GPG signature..."

gpg --verify "${TMPDIR}/lynis.tar.gz.asc" "${TMPDIR}/lynis.tar.gz" 2>&1 \
    || fail "GPG SIGNATURE VERIFICATION FAILED.
    The downloaded file does not match CISOfy's signature.
    Do NOT proceed."

log "GPG signature verified successfully."

# -----------------------------------------------------------------------------
# STEP 8: Extract and install
# -----------------------------------------------------------------------------
log "Extracting Lynis to ${LYNIS_INSTALL_DIR}..."

mkdir -p "${LYNIS_INSTALL_DIR}"
tar -xzf "${TMPDIR}/lynis.tar.gz" -C "${LYNIS_INSTALL_DIR}" --strip-components=1

chown -R 0:0 "${LYNIS_INSTALL_DIR}"
chmod -R 755 "${LYNIS_INSTALL_DIR}"
chmod 750 "${LYNIS_INSTALL_DIR}/lynis"

ln -sf "${LYNIS_INSTALL_DIR}/lynis" /usr/local/bin/lynis
log "Lynis installed to ${LYNIS_INSTALL_DIR}."

# -----------------------------------------------------------------------------
# STEP 9: Create secured log and report directories
# -----------------------------------------------------------------------------
log "Creating secured log/report directories..."

mkdir -p "${LYNIS_LOG_DIR}" "${LYNIS_REPORT_DIR}"
chown -R root:root "${LYNIS_LOG_DIR}"
chmod 700 "${LYNIS_LOG_DIR}"
chmod 700 "${LYNIS_REPORT_DIR}"

# -----------------------------------------------------------------------------
# STEP 10: Generate integrity baseline hash
# -----------------------------------------------------------------------------
log "Generating integrity baseline hash..."

mkdir -p "${BASELINE_DIR}"
chmod 700 "${BASELINE_DIR}"

find "${LYNIS_INSTALL_DIR}" -type f \( \
    -name "lynis"          \
    -o -name "*.sh"        \
    -o -name "*.inc"       \
    -o -name "RELEASE"     \
    -o -name "default.prf" \
\) | sort | xargs sha256sum > "${BASELINE_FILE}"

chmod 400 "${BASELINE_FILE}"
chown root:root "${BASELINE_FILE}"

log "Baseline saved to ${BASELINE_FILE}"
echo ""
echo "=== BASELINE SAMPLE (first 5 entries) ==="
head -5 "${BASELINE_FILE}"
echo "=========================================="

# -----------------------------------------------------------------------------
# STEP 11: Create persistent network namespace
# -----------------------------------------------------------------------------
log "Creating isolated network namespace 'lynis-ns'..."

ip netns add lynis-ns 2>/dev/null \
    || warn "Network namespace 'lynis-ns' already exists, skipping."

cat > /etc/systemd/system/lynis-netns.service << 'SYSTEMD'
[Unit]
Description=Lynis isolated network namespace
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip netns add lynis-ns
ExecStop=/sbin/ip netns del lynis-ns

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable lynis-netns.service --quiet
log "Network namespace 'lynis-ns' created and enabled at boot."

# -----------------------------------------------------------------------------
# STEP 12: Strace profiling
# -----------------------------------------------------------------------------
log "Profiling network calls (should be empty inside namespace)..."
ip netns exec lynis-ns \
    strace -f -e trace=network \
    "${LYNIS_INSTALL_DIR}/lynis" audit system --quiet 2>&1 \
    | grep -v "ENOENT" \
    > "${BASELINE_DIR}/lynis-network-profile.txt" 2>&1 || true

log "Profiling file write operations..."
strace -f -e trace=write,openat \
    "${LYNIS_INSTALL_DIR}/lynis" audit system --quiet 2>&1 \
    | grep "O_WRONLY\|O_RDWR" \
    > "${BASELINE_DIR}/lynis-writes-profile.txt" 2>&1 || true

log "Profiling complete."

# -----------------------------------------------------------------------------
# DONE
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Lynis ${LYNIS_VERSION} installation complete."
echo "============================================================"
echo ""
echo " CRITICAL — do these manually before running scans:"
echo ""
echo " 1. Copy baseline OFF-HOST immediately:"
echo "    scp ${BASELINE_FILE} user@jumpbox:/secure/lynis/\$(hostname)/"
echo ""
echo " 2. Review what Lynis writes to disk:"
echo "    cat ${BASELINE_DIR}/lynis-writes-profile.txt"
echo ""
echo " 3. Review network calls (should be empty):"
echo "    cat ${BASELINE_DIR}/lynis-network-profile.txt"
echo ""
echo " 4. Set up monitoring:  sudo bash 03_integrity_monitor.sh"
echo " 5. Run first scan:     sudo bash 02_run_lynis_scan.sh"
echo "============================================================"
EOF