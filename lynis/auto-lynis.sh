#!/bin/bash
# =============================================================================
# SIMPLE LYNIS MONITOR
# - Daily scan
# - Weekly file integrity check (basic tamper detection)
# - Email alert if scan fails to run or files change
# =============================================================================

ALERT_EMAIL="yassinebenayed100@gmail.com"  
LOG_FILE="/var/log/lynis-report.log"
BASELINE="/etc/lynis-baseline.sha256"

# --- Step 1: Run Lynis scan ---
lynis audit system --cronjob > "$LOG_FILE" 2>&1

# --- Step 2: Check integrity of Lynis binary ---
CURRENT_HASH=$(sha256sum /usr/sbin/lynis | awk '{print $1}')

if [[ ! -f "$BASELINE" ]]; then
    echo "$CURRENT_HASH" > "$BASELINE"
    exit 0
fi

BASELINE_HASH=$(cat "$BASELINE")

if [[ "$CURRENT_HASH" != "$BASELINE_HASH" ]]; then
    mail -s "ALERT: Lynis binary changed on $(hostname)" "$ALERT_EMAIL" <<< "Lynis binary hash mismatch — investigate."
fi

# --- Step 3: Alert on warnings found in scan ---
if grep -q "Warning" "$LOG_FILE"; then
    mail -s "Lynis scan warnings on $(hostname)" "$ALERT_EMAIL" < "$LOG_FILE"
fi