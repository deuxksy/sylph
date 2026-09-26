#!/bin/bash
# Live 설정 → Local 동기화 스크립트
# 1. Aperture 설정 → aperture/config.json (secret은 Aperture가 keyid 참조로 마스킹, 평문 미포함)
# 2. Tailnet 디바이스 인벤토리 → docs/devices.json
# ACL(policy.hujson)은 이 스크립트로 가져오지 않음 — repo가 Source of Truth (tofu plan으로 drift 확인).

set -euo pipefail

TAILNET="TY1qnFMXke11CNTRL"
API_BASE="https://api.tailscale.com/api/v2"
APERTURE_URL="${APERTURE_URL:-https://ai.bun-bull.ts.net}"
ENV_FILE="${ENV_FILE:-.env.sops}"

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Sync live Tailscale/Aperture configuration into local files.

Options:
  --aperture-url URL     Aperture base URL (default: ${APERTURE_URL})
  --env FILE             Encrypted env file (default: ${ENV_FILE})
  -h, --help             Show this help message

Environment (loaded from sops-encrypted .env.sops):
  TS_OAUTH_CLIENT_ID       Tailscale OAuth client ID
  TS_OAUTH_CLIENT_SECRET   Tailscale OAuth client secret

Outputs:
  aperture/config.json    Aperture 설정 (keyid 참조, 커밋 가능)
  docs/devices.json       Tailnet 디바이스 스냅샷 (hostname/os/tags/user)
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --aperture-url) APERTURE_URL="$2"; shift 2 ;;
        --env)          ENV_FILE="$2"; shift 2 ;;
        -h|--help)      show_help; exit 0 ;;
        *)              echo "Unknown option: $1" >&2; show_help; exit 1 ;;
    esac
done

for cmd in sops jq curl; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "❌ $cmd not installed" >&2; exit 1; }
done
[[ -f "$ENV_FILE" ]] || { echo "❌ Env file not found: $ENV_FILE" >&2; exit 1; }

# --- sops 복호화 (dotenv → JSON 순서로 형식 자동 감지, tag-device.sh와 동일 패턴) ---
ENV_TMP=$(mktemp)
trap 'rm -f "$ENV_TMP"' EXIT
if ! sops -d --input-type dotenv --output-type binary "$ENV_FILE" > "$ENV_TMP" 2>/dev/null; then
    if ! sops -d --input-type json --output-type binary "$ENV_FILE" > "$ENV_TMP" 2>/dev/null; then
        echo "❌ sops decryption failed for $ENV_FILE" >&2
        exit 1
    fi
fi
set -a
# shellcheck disable=SC1090
source "$ENV_TMP"
set +a

if [[ -z "${TS_OAUTH_CLIENT_ID:-}" || -z "${TS_OAUTH_CLIENT_SECRET:-}" ]]; then
    echo "❌ TS_OAUTH_CLIENT_ID / TS_OAUTH_CLIENT_SECRET missing in $ENV_FILE" >&2
    exit 1
fi

# --- 1. Aperture 설정 동기화 ---
echo "ℹ️  Fetching Aperture config from ${APERTURE_URL}..."
if curl -sS -f --max-time 15 "${APERTURE_URL}/api/config" -o /tmp/aperture-sync.json 2>/dev/null; then
    jq -e '.config | fromjson' /tmp/aperture-sync.json > /dev/null
    # 평문 secret 방어: keyid 참조 외 실제 키 패턴이 있으면 중단
    if jq -r '.config' /tmp/aperture-sync.json | grep -qE '"(apikey|client_secret|token)":\s*"(sk-|tskey-)[A-Za-z0-9_-]{20,}'; then
        echo "❌ Plain-text secret detected in Aperture export — aborting" >&2
        exit 1
    fi
    jq -r '.config' /tmp/aperture-sync.json > aperture/config.json
    echo "✅ aperture/config.json ($(wc -l < aperture/config.json | tr -d ' ') lines, hash: $(jq -r .hash /tmp/aperture-sync.json))"
else
    echo "⚠️  Aperture unreachable — skipping (tailnet ACL에서 ${APERTURE_URL} 접근 허용 필요)"
fi

# --- 2. Tailnet 디바이스 인벤토리 스냅샷 ---
echo "ℹ️  Requesting OAuth access token..."
TOKEN=$(curl -sS -f -X POST "${API_BASE}/oauth/token" \
    -u "${TS_OAUTH_CLIENT_ID}:${TS_OAUTH_CLIENT_SECRET}" \
    -d "grant_type=client_credentials" | jq -r '.access_token')

echo "ℹ️  Fetching tailnet devices..."
# 임시 노드(SSH console 등 os=js)와 이름 중복 localhost 제외한 안정적 스냅샷
curl -sS -f -H "Authorization: Bearer ${TOKEN}" \
    "${API_BASE}/tailnet/${TAILNET}/devices" | \
    jq '[.devices[]
        | select(.os != "js")
        | {hostname, os, user, tags: (.tags // [])}] | sort_by(.hostname)' \
    > docs/devices.json
echo "✅ docs/devices.json ($(jq 'length' docs/devices.json) devices)"
