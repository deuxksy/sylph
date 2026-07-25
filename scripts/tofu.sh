#!/bin/bash
# sops로 .env.sops 복호화 → env 주입 → tofu 실행
# 사용: ./scripts/tofu.sh init|plan|apply|import ...
set -euo pipefail
cd "$(dirname "$0")/../opentofu"

ENV_TMP=$(mktemp)
trap 'rm -f "$ENV_TMP"' EXIT
if ! sops -d --input-type dotenv --output-type binary ../.env.sops > "$ENV_TMP" 2>/dev/null; then
    echo "Error: sops decryption failed for .env.sops" >&2
    exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_TMP"
set +a
rm -f "$ENV_TMP"

if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "Error: R2 credentials (AWS_ACCESS_KEY_ID/SECRET) missing in .env.sops" >&2
    exit 1
fi

export TAILSCALE_OAUTH_CLIENT_ID="${TS_OAUTH_CLIENT_ID:-$TS_API_CLIENT_ID}"
export TAILSCALE_OAUTH_CLIENT_SECRET="${TS_OAUTH_CLIENT_SECRET:-$TS_API_CLIENT_SECRET}"
export TAILSCALE_TAILNET="TY1qnFMXke11CNTRL"

tofu "$@"
