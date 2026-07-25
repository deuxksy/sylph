# Tailscale OpenTofu 일원화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tailscale ACL/tag 관리를 GitHub Actions GitOps에서 로컬 OpenTofu(R2 state backend)로 전환한다.

**Architecture:** `policy.hujson`을 `tailscale_acl` resource로 `file()` 참조해 관리. 디바이스 tag는 `tailscale_device_tags`로 선언. state는 Cloudflare R2 S3 backend(`terraform-state` bucket)에 저장하고 `use_lockfile`로 잠금. 자격증명은 sops 암호화 `.env.sops`를 `scripts/tofu.sh` wrapper로 주입.

**Tech Stack:** OpenTofu ≥1.10, tailscale/tailscale provider, Cloudflare R2 (S3 backend), sops/age, bash

## Global Constraints

- Tailnet ID: `TY1qnFMXke11CNTRL`
- R2 endpoint: `https://e0924c382d21ac0f10aee606b82687ce.r2.cloudflarestorage.com`
- R2 bucket: `terraform-state` / state key: `sylph/main/terraform.tfstate`
- OpenTofu `required_version = ">= 1.10"` (use_lockfile 요구)
- provider 버전: exact pin + `.terraform.lock.hcl` 커밋 (`~>` 범위 금지)
- projector: hostname `ADT-3`, node ID `nE7nEXsjp211CNTRL`, tags `["tag:projector"]`
- 디바이스 식별자는 `node_id` 사용 (`id`는 legacy)
- sops 복호화: `sops -d --input-type dotenv --output-type binary .env.sops`
- `tailscale_device_tags`는 전체 tag set 교체 — 선언 외 tag는 삭제됨 (해당 resource가 tag의 유일한 owner)
- **diff 0 확인 전 apply 금지** (stop condition)

---

### Task 1: Preflight Baseline 기록

**Files:**
- Create: 없음 (검증 전용, 결과는 터미널 출력으로 기록)

**Interfaces:**
- Consumes: 기존 `.env.sops` (TS_OAUTH_CLIENT_ID/SECRET, `TS_API_CLIENT_*`는 레거시 alias)
- Produces: baseline 확인 결과 — OAuth scope OK, live policy 일치, projector tag 상태

- [ ] **Step 1: OAuth token 발급 + scope 검증 (`GET .../acl`)**

```bash
set -a; source <(sops -d --input-type dotenv --output-type binary .env.sops); set +a
TOKEN=$(curl -sS -X POST "https://api.tailscale.com/api/v2/oauth/token" \
  -u "${TS_API_CLIENT_ID}:${TS_API_CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')
curl -sS -o /tmp/live-acl.json -w "%{http_code}" \
  "https://api.tailscale.com/api/v2/tailnet/TY1qnFMXke11CNTRL/acl" \
  -H "Authorization: Bearer $TOKEN"
```

Expected: `200` 출력. `403`이면 OAuth client scope 부족 → Admin Console에서 `policy_file` write 포함해 재발급 후 `.env.sops` 갱신. **이 단계 실패 시 이후 모든 Task 중단.**

- [ ] **Step 2: live policy와 `policy.hujson` 비교**

```bash
python3 -c "
import json5, json
live = json.load(open('/tmp/live-acl.json'))
local = json5.load(open('policy.hujson'))
print('MATCH' if live == local else 'DRIFT')
"
```

Expected: `MATCH`. `DRIFT`이면 live 정책이 로컬과 다름 — 차이를 확인하고 `policy.hujson`을 live에 맞춘 뒤 진행 (OpenTofu가 덮어쓸 내용을 사전 인지하기 위함).

- [ ] **Step 3: projector tag 상태 기록**

```bash
curl -sS "https://api.tailscale.com/api/v2/tailnet/TY1qnFMXke11CNTRL/devices" \
  -H "Authorization: Bearer $TOKEN" | \
  jq -c '.devices[] | select(.hostname == "ADT-3") | {nodeId, tags}'
```

Expected: `{"nodeId":"nE7nEXsjp211CNTRL","tags":["tag:projector"]}`. tags가 더 있으면 Task 4의 `devices.tf` 선언에 모두 포함해야 함 (전체 교체 주의).

- [ ] **Step 4: Commit (baseline 기록 없음, 변경 파일 없으면 skip)**

변경 사항 없음. 결과만 확인하고 Task 2로 진행.

---

### Task 2: OpenTofu scaffold + wrapper + gitignore

**Files:**
- Create: `opentofu/backend.tf`
- Create: `opentofu/versions.tf`
- Create: `opentofu/main.tf`
- Create: `opentofu/devices.tf`
- Create: `scripts/tofu.sh`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Global Constraints의 R2/tailnet/projector 값
- Produces: `./scripts/tofu.sh <args>` 실행 진입점, `opentofu/` 모듈

- [ ] **Step 1: provider 최신 stable 버전 확인**

```bash
curl -sS "https://registry.opentofu.org/v1/providers/tailscale/tailscale/versions" | \
  jq -r '.versions[].version' | grep -vE 'alpha|beta|rc' | sort -V | tail -1
```

Expected: 버전 문자열 1개 (예: `0.29.2`). 이 값을 다음 Step의 `<LATEST>`에 사용.

- [ ] **Step 2: `opentofu/backend.tf` 작성**

```hcl
# Terraform Backend (Cloudflare R2)
# S3-compatible backend. terraform-state bucket은 homelab과 공유, key로 분리.

terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://e0924c382d21ac0f10aee606b82687ce.r2.cloudflarestorage.com"
    }
    bucket                      = "terraform-state"
    key                         = "sylph/main/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }
}
```

- [ ] **Step 3: `opentofu/versions.tf` 작성 (`<LATEST>`는 Step 1 결과로 치환)**

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "<LATEST>"
    }
  }
}
```

- [ ] **Step 4: `opentofu/main.tf` 작성**

```hcl
provider "tailscale" {
  # TAILSCALE_OAUTH_CLIENT_ID / TAILSCALE_OAUTH_CLIENT_SECRET / TAILSCALE_TAILNET
  # env는 scripts/tofu.sh가 주입
}

resource "tailscale_acl" "acl" {
  acl = file("${path.module}/../policy.hujson")
}
```

- [ ] **Step 5: `opentofu/devices.tf` 작성**

```hcl
# tag-device.sh와의 역할 분리: 여기 선언된 디바이스는 이 resource가 tag의 유일한 owner.
# (tailscale_device_tags는 전체 tag set을 교체함)
data "tailscale_device" "projector" {
  hostname = "ADT-3"
}

resource "tailscale_device_tags" "projector" {
  device_id = data.tailscale_device.projector.node_id
  tags      = ["tag:projector"]
}
```

- [ ] **Step 6: `scripts/tofu.sh` 작성 + 실행 권한**

```bash
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

export TAILSCALE_OAUTH_CLIENT_ID="$TS_API_CLIENT_ID"
export TAILSCALE_OAUTH_CLIENT_SECRET="$TS_API_CLIENT_SECRET"
export TAILSCALE_TAILNET="TY1qnFMXke11CNTRL"

tofu "$@"
```

```bash
chmod +x scripts/tofu.sh
```

- [ ] **Step 7: `.gitignore`에 OpenTofu 항목 추가**

`.gitignore` 끝에 추가:

```gitignore
# OpenTofu
.terraform/
*.tfstate
*.tfstate.*
crash.log
```

> `.terraform.lock.hcl`은 추가하지 않음 — 커밋 대상.

- [ ] **Step 8: 검증 — syntax check**

```bash
bash -n scripts/tofu.sh && echo "tofu.sh syntax OK"
cd opentofu && tofu fmt -check -diff && tofu validate -no-color 2>&1 | head -5; cd ..
```

Expected: `tofu.sh syntax OK`. `tofu fmt` diff 없음. `validate`는 init 전이라 backend 에러가 날 수 있음 — HCL 문법 에러가 아니면 Task 3에서 재확인.

- [ ] **Step 9: Commit**

```bash
git add opentofu/ scripts/tofu.sh .gitignore
git commit -m "feat: OpenTofu scaffold for Tailscale tailnet management"
```

---

### Task 3: .env.sops R2 키 추가 + tofu init

**Files:**
- Modify: `.env.sops` (sops 재암호화)

**Interfaces:**
- Consumes: Task 2의 `scripts/tofu.sh`, `opentofu/`
- Produces: R2 backend에 연결된 초기화된 작업 디렉토리, 빈 state 확인

- [ ] **Step 1: homelab에서 R2 자격증명 조회**

```bash
sops -d /home/deck/git/homelab/proxmox/opentofu/secrets.sops.yaml 2>/dev/null | grep -iE "r2|aws_access|aws_secret"
```

Expected: R2 access key/secret 값. 없으면 사용자에게 homelab R2 키를 요청 (homelab backend.tf가 사용하는 것과 동일 키).

- [ ] **Step 2: `.env.sops`에 R2 키 추가 후 재암호화**

```bash
sops -d --input-type dotenv --output-type binary .env.sops > .env
cat >> .env <<'EOF'
AWS_ACCESS_KEY_ID=<R2_ACCESS_KEY>
AWS_SECRET_ACCESS_KEY=<R2_SECRET_KEY>
EOF
# 실패 시 기존 .env.sops 보존을 위해 임시 파일로 암호화 후 교체
sops -e --input-type binary .env > .env.sops.new
mv .env.sops.new .env.sops
rm .env
```

`<R2_ACCESS_KEY>`/`<R2_SECRET_KEY>`는 Step 1 결과로 치환.

- [ ] **Step 3: 재암호화 검증**

```bash
sops -d --input-type dotenv --output-type binary .env.sops | sed 's/=.*/=<OK>/'
```

Expected: 4개 키 모두 `=<OK>`로 출력 (`TS_OAUTH_CLIENT_ID`, `TS_OAUTH_CLIENT_SECRET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).

- [ ] **Step 4: `tofu init`**

```bash
./scripts/tofu.sh init
```

Expected: `OpenTofu has been successfully initialized!`. 실패 시 R2 자격증명/endpoint 확인.

- [ ] **Step 5: state가 비어있는지 확인 (기존 state 충돌 방지)**

```bash
./scripts/tofu.sh state list
```

Expected: 출력 없음 (빈 state). 리소스가 보이면 `sylph/main/terraform.tfstate`에 기존 state 존재 — **중단하고 사용자에게 확인** (다른 state 덮어쓰기 금지).

- [ ] **Step 6: Commit**

```bash
git add .env.sops opentofu/.terraform.lock.hcl
git commit -m "chore: R2 credentials 추가 및 OpenTofu init (lock file)"
```

---

### Task 4: 기존 리소스 import + plan diff 0 검증

**Files:**
- Modify: 없음 (state만 변경)

**Interfaces:**
- Consumes: Task 3의 초기화된 작업 디렉토리, Task 1의 baseline 값
- Produces: live 리소스를 흡수한 state, diff 0 확인

- [ ] **Step 1: ACL import**

```bash
./scripts/tofu.sh import tailscale_acl.acl acl
```

Expected: `Import successful!`. import ID는 리터럴 `acl` (provider가 ID 값을 쓰지 않음). **import 선행 필수** — 없으면 apply 시 `overwrite_existing_content` 없이는 거부됨.

- [ ] **Step 2: device_tags import**

```bash
./scripts/tofu.sh import tailscale_device_tags.projector nE7nEXsjp211CNTRL
```

Expected: `Import successful!`.

- [ ] **Step 3: plan — diff 0 확인 (핵심 검증 게이트)**

```bash
./scripts/tofu.sh plan -detailed-exitcode
echo "exit: $?"
```

Expected: `exit: 0` (No changes). `exit: 2`(diff 있음)이면 **apply 금지** — diff 내용을 분석:
- ACL diff: live policy와 `policy.hujson` 불일치 (Task 1 Step 2 재확인)
- tags diff: projector에 선언 외 tag 존재 (Task 1 Step 3 재확인 후 `devices.tf` 보정)

- [ ] **Step 4: Commit (state는 R2에 있으므로 로컬 변경 없음, skip)**

파일 변경 없음. Task 5로 진행.

---

### Task 5: GitOps apply job 제거 + 문서 갱신

**Files:**
- Modify: `.github/workflows/tailscale-acl.yml`
- Modify: `README.md`
- Modify: `.ai/RULES.md`

**Interfaces:**
- Consumes: Task 4의 diff 0 확인 (OpenTofu가 ACL ownership을 가진 상태)
- Produces: PR validation만 남은 workflow, 전환된 운영 문서

- [ ] **Step 1: `tailscale-acl.yml`에서 `acl-apply` job 삭제**

30–45행의 `acl-apply:` 블록 전체를 삭제. 결과:

```yaml
name: Sync Tailscale ACLs

on:
  push:
    branches:
      - main
    paths:
      - 'policy.hujson'
  pull_request:
    paths:
      - 'policy.hujson'
  workflow_dispatch:

jobs:
  acl-check:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Test ACL
        uses: tailscale/gitops-acl-action@v1
        with:
          tailnet: TY1qnFMXke11CNTRL
          oauth-client-id: ${{ secrets.TS_API_CLIENT_ID }}
          oauth-secret: ${{ secrets.TS_API_CLIENT_SECRET }}
          policy-file: policy.hujson
          action: test # validation 전용 (apply는 OpenTofu가 담당)
```

> PR test(validation) job은 유지 — server-side policy 검증 gate 보존. apply는 이후 `./scripts/tofu.sh apply`만.

- [ ] **Step 2: workflow YAML 검증**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/tailscale-acl.yml')); print('YAML OK')"
```

Expected: `YAML OK`.

- [ ] **Step 3: `.ai/RULES.md` 갱신 — GitHub Actions 섹션**

`### GitHub Actions (2개 워크플로우)` 섹션을 아래로 교체:

```markdown
### GitHub Actions (2개 워크플로우)
- **tailscale-acl.yml**: PR/push 시 ACL **test(validation)만** 실행 (`tailscale/gitops-acl-action@v1`, `action: test`)
- **acl-docs.yml**: PR에서 문서 생성 후 PR 코멘트로 결과 게시
- ACL apply는 OpenTofu(`./scripts/tofu.sh apply`)가 담당 — Actions에서 apply하지 않음
- Secrets: `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_CLIENT_SECRET` 필요
```

- [ ] **Step 4: `.ai/RULES.md` 갱신 — Architecture에 opentofu 섹션 추가**

`### scripts/tag-device.sh` 섹션 뒤에 추가:

```markdown
### opentofu/
- `tailscale_acl`: `policy.hujson`을 `file()`로 참조해 tailnet policy 관리
- `tailscale_device_tags`: 디바이스 tag 선언 관리 (전체 교체 — 선언된 resource가 tag의 유일한 owner)
- State: Cloudflare R2 `terraform-state` bucket, key `sylph/main/terraform.tfstate`, `use_lockfile`
- 자격증명: `.env.sops` (TS OAuth + R2 키)를 `scripts/tofu.sh`가 주입
- 사용: `./scripts/tofu.sh plan|apply|import ...`
```

- [ ] **Step 5: `.ai/RULES.md` 갱신 — ACL 수정 Workflow**

`## ACL 수정 Workflow` 섹션을 아래로 교체:

```markdown
## ACL 수정 Workflow

1. `policy.hujson` 수정
2. `./scripts/generate-docs.sh` 실행 → `docs/acl.md` 확인
3. 커밋 + PR 생성
4. GitHub Actions: ACL test(validation) + 문서 코멘트 자동 실행
5. main 병합 후 로컬에서 `./scripts/tofu.sh plan` 확인 → `./scripts/tofu.sh apply`
```

- [ ] **Step 6: README.md 갱신 — 파일 구조 + 워크플로우 설명**

`## 파일 구조` 섹션의 트리를 아래로 교체:

```text
.
├── policy.hujson              # ACL 정책 파일
├── opentofu/                  # OpenTofu tailnet 관리 (ACL apply, device tags)
├── scripts/
│   ├── generate-docs.sh       # 문서 생성 스크립트
│   ├── tag-device.sh          # API tag 부여 (OpenTofu 미관리 디바이스용 fallback)
│   └── tofu.sh                # OpenTofu 실행 wrapper (sops 자격증명 주입)
├── docs/
│   └── acl.md                 # 생성된 문서
└── .github/workflows/
    ├── tailscale-acl.yml      # ACL validation 워크플로우 (test only)
    └── acl-docs.yml           # 문서화 워크플로우
```

`### GitHub Actions` 섹션(123–125행) 본문을 아래로 교체:

```markdown
PR이 생성되거나 `policy.hujson`이 변경되면 자동으로 PR에 변경사항 코멘트가 생성됩니다.
ACL의 실제 적용(apply)은 로컬에서 OpenTofu로 수행합니다: `./scripts/tofu.sh plan && ./scripts/tofu.sh apply`
```

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/tailscale-acl.yml README.md .ai/RULES.md
git commit -m "feat: ACL apply를 GitOps에서 OpenTofu로 전환 (Actions는 validation 전용)"
```

---

### Task 6: E2E 검증 + push

**Files:**
- Modify: 없음

**Interfaces:**
- Consumes: Task 1–5 전부
- Produces: 전환 완료 확인, origin 반영

- [ ] **Step 1: 최종 plan 재확인**

```bash
./scripts/tofu.sh plan -detailed-exitcode; echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 2: projector tag 유지 확인 (API)**

```bash
set -a; source <(sops -d --input-type dotenv --output-type binary .env.sops); set +a
TOKEN=$(curl -sS -X POST "https://api.tailscale.com/api/v2/oauth/token" \
  -u "${TS_OAUTH_CLIENT_ID}:${TS_OAUTH_CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')
curl -sS "https://api.tailscale.com/api/v2/tailnet/TY1qnFMXke11CNTRL/devices" \
  -H "Authorization: Bearer $TOKEN" | \
  jq -c '.devices[] | select(.hostname == "ADT-3") | .tags'
```

Expected: `["tag:projector"]`.

- [ ] **Step 3: workflow 테스트 (선택 — policy.hujson 미변경이라 트리거 안 됨, 문법만 확인)**

Task 5 Step 2의 YAML 검증으로 대체 완료. 실제 PR test job 동작은 다음 ACL 변경 PR에서 자연 확인.

- [ ] **Step 4: push**

```bash
git push origin main
```

Expected: push 성공. push 시 `policy.hujson`은 변경되지 않았으므로 `tailscale-acl.yml`/`acl-docs.yml` 모두 트리거되지 않음 (paths 필터).

- [ ] **Step 5: checkpoint tag**

```bash
git tag -a v0.2.0 -m "checkpoint: OpenTofu 일원화 전환 완료"
git push origin v0.2.0
```
