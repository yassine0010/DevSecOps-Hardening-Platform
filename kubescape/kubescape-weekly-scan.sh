#!/usr/bin/env bash
set -euo pipefail

# Load credentials from a restricted-permission file, not hardcoded here
source /etc/kubescape-scan/env

REPORT_PATH="/tmp/kubescape-report-$(date +%Y%m%d).json"

# Run the scan
kubescape scan framework nsa,mitre --format json --output "$REPORT_PATH"

# Push to DefectDojo
RESPONSE=$(curl -s -X POST "${DEFECTDOJO_URL}/api/v2/reimport-scan/" \
  -H "Authorization: Token ${DEFECTDOJO_TOKEN}" \
  -F "scan_type=Kubescape JSON Importer" \
  -F "file=@${REPORT_PATH}" \
  -F "product_type_name=Research and Development" \
  -F "product_name=cluster-security" \
  -F "engagement_name=Kubescape-Cluster-Scans" \
  -F "auto_create_context=true" \
  -F "active=true" \
  -F "verified=false" \
  -F "close_old_findings=true" \
  -F "deduplication_on_engagement=true" \
  -F "scan_date=$(date +%Y-%m-%d)")

echo "$RESPONSE"
echo "Kubescape scan complete and pushed to DefectDojo: $REPORT_PATH"

# Clean up old reports so /tmp doesn't accumulate forever
find /tmp -name "kubescape-report-*.json" -mtime +30 -delete