#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../aperture/config.json"
APERTURE_HOST="${APERTURE_HOST:-ai}"
APERTURE_URL="http://${APERTURE_HOST}/api/config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config not found at $CONFIG_FILE"
    exit 1
fi

echo "Validating config..."
python3 -c "import json; json.load(open('$CONFIG_FILE'))" && echo "Valid JSON" || { echo "Invalid JSON"; exit 1; }

echo "Fetching current hash..."
CURRENT_HASH=$(curl -s "$APERTURE_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['hash'])")
echo "Current hash: $CURRENT_HASH"

echo "Applying config to Aperture ($APERTURE_URL)..."
PAYLOAD=$(python3 -c "
import json
config = json.load(open('$CONFIG_FILE'))
print(json.dumps({'hash': '$CURRENT_HASH', 'config': json.dumps(config, indent=4)}))
")
RESPONSE=$(echo "$PAYLOAD" | curl -s -w "\n%{http_code}" -X PUT "$APERTURE_URL" -d @- -H "Content-Type: application/json")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Success: config applied"
else
    echo "Error (HTTP $HTTP_CODE): $BODY"
    echo "Warning: keyid references may have been invalidated. Restore via dashboard."
    exit 1
fi
