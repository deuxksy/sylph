#!/bin/bash
# Tailscale Device Tag Manager
# Tailscale API(OAuth client)로 디바이스에 tag를 부여한다.
# 안드로이드/iOS 기기처럼 tailscale CLI를 사용할 수 없는 노드에 tag 적용 목적.

set -euo pipefail

TAILNET="TY1qnFMXke11CNTRL"
API_BASE="https://api.tailscale.com/api/v2"

show_help() {
    cat << HELP
Usage: $(basename "$0") <hostname> <tag> [OPTIONS]

Attach a Tailscale tag to a device via OAuth client credentials.

Arguments:
  hostname               Tailscale device hostname (e.g. projector)
  tag                    Tag name without "tag:" prefix (e.g. projector)

Options:
  --env FILE             Encrypted env file (default: .env.sops)
  --tailnet ID           Tailnet ID (default: ${TAILNET})
  --replace              Replace existing tags (default: append/merge)
  -h, --help             Show this help message

Environment (loaded from sops-encrypted .env.sops):
  TS_API_CLIENT_ID       Tailscale OAuth client ID (scope: devices:write)
  TS_API_CLIENT_SECRET   Tailscale OAuth client secret

Examples:
  $(basename "$0") projector projector
  $(basename "$0") projector projector --replace
  $(basename "$0") projector projector --env ~/secrets/ts.env.sops

Setup (one-time):
  1. Issue OAuth client at https://login.tailscale.com/admin/settings/oauth
     with scope "Devices: Write".
  2. Encrypt credentials:
       sops -e .env > .env.sops && rm .env
HELP
}

REPLACE=false
ENV_FILE=".env.sops"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        --replace) REPLACE=true; shift ;;
        --env) ENV_FILE="$2"; shift 2 ;;
        --tailnet) TAILNET="$2"; shift 2 ;;
        -*) echo "Unknown option: $1" >&2; show_help >&2; exit 2 ;;
        *) break ;;
    esac
done

HOSTNAME="${1:-}"
TAG="${2:-}"

if [[ -z "$HOSTNAME" || -z "$TAG" ]]; then
    echo "Error: hostname and tag are required" >&2
    show_help >&2
    exit 2
fi

# tag: prefix 정규화
TAG="tag:${TAG#tag:}"

# sops 복호화 후 환경변수 로드 (평문 .env는 .gitignore에 등록됨)
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: encrypted env file not found: $ENV_FILE" >&2
    echo "Run: sops -e .env > $ENV_FILE" >&2
    exit 1
fi

if ! command -v sops >/dev/null 2>&1; then
    echo "Error: sops not installed" >&2
    exit 1
fi

set +a
eval "$(sops -d "$ENV_FILE")"
set -a

if [[ -z "${TS_API_CLIENT_ID:-}" || -z "${TS_API_CLIENT_SECRET:-}" ]]; then
    echo "Error: TS_API_CLIENT_ID / TS_API_CLIENT_SECRET missing in $ENV_FILE" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq not installed" >&2
    exit 1
fi

# 1. OAuth access token 발급 (client_credentials, Basic auth)
echo "ℹ️  Requesting OAuth access token..."
TOKEN_RESPONSE=$(curl -sS -f -X POST "${API_BASE}/oauth/token" \
    -u "${TS_API_CLIENT_ID}:${TS_API_CLIENT_SECRET}" \
    -d "grant_type=client_credentials" \
    2>/dev/null) || {
        echo "Error: OAuth token request failed" >&2
        exit 1
    }
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "Error: access_token missing in response" >&2
    echo "$TOKEN_RESPONSE" >&2
    exit 1
fi
echo "✓ Token acquired"

# 2. 디바이스 목록 조회 → nodeId 확보
echo "ℹ️  Looking up device: $HOSTNAME"
DEVICES=$(curl -sS -f "${API_BASE}/tailnet/${TAILNET}/devices" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    2>/dev/null) || {
        echo "Error: device list request failed" >&2
        exit 1
    }

NODE_ID=$(echo "$DEVICES" | jq -r --arg h "$HOSTNAME" \
    '.devices[] | select(.hostname == $h) | .nodeId' | head -n1)

if [[ -z "$NODE_ID" ]]; then
    echo "Error: device not found: $HOSTNAME" >&2
    echo "Available devices:" >&2
    echo "$DEVICES" | jq -r '.devices[].hostname' | sed 's/^/  - /' >&2
    exit 1
fi
CURRENT_TAGS=$(echo "$DEVICES" | jq -r --arg h "$HOSTNAME" \
    '.devices[] | select(.hostname == $h) | .tags // [] | join(", ")')
echo "✓ Found: nodeId=$NODE_ID, current tags=[${CURRENT_TAGS}]"

# 3. tag 병합 또는 교체 (jq로 JSON 생성하여 injection 방지)
if $REPLACE; then
    NEW_TAGS=$(jq -n --arg t "$TAG" '[$t]')
    echo "ℹ️  Replacing tags with: [$TAG]"
else
    NEW_TAGS=$(echo "$DEVICES" | jq -c --arg h "$HOSTNAME" --arg t "$TAG" \
        '(.devices[] | select(.hostname == $h) | .tags // []) + [$t] | unique')
    echo "ℹ️  Merging tags: $(echo "$NEW_TAGS" | jq -c '.')"
fi

# 4. tag 부여 (POST /device/{nodeId}) — body도 jq로 생성하여 파이프
echo "ℹ️  Applying tags to $HOSTNAME..."
RESPONSE=$(jq -n --argjson tags "$NEW_TAGS" '{"tags": $tags}' | \
    curl -sS -w "\n%{http_code}" -X POST "${API_BASE}/device/${NODE_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @- \
    2>/dev/null) || {
        echo "Error: tag application request failed" >&2
        exit 1
    }

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]]; then
    APPLIED=$(echo "$BODY" | jq -r '.tags // [] | join(", ")')
    echo "✓ Tags applied: [$APPLIED]"
    echo "✓ Done: $HOSTNAME → $TAG"
else
    echo "Error: HTTP $HTTP_CODE" >&2
    echo "$BODY" >&2
    exit 1
fi
