# mise tasks 진입점 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `scripts/*.sh`를 `mise.toml [tasks]` 선언적 진입점으로 랩해 모든 AI agent가 `mise tasks ls`로 자가발견하게 한다.

**Architecture:** 기존 sh 스크립트는 무수정, `mise.toml`에 태스크 선언만 추가. `.ai/RULES.md`·`ROADMAP.md`에 진입점 변화를 기록해 발견 경로를 단일화한다.

**Tech Stack:** mise 2026.11.11 (내장 task runner), TOML. 테스트 프레임워크 없음 — 검증은 명령 출력 비교.

**Spec:** `docs/superpowers/specs/2026-11-22-mise-tasks-design.md`

## Global Constraints

- 스크립트 본체(`scripts/*.sh`) 수정 금지 — 선언만 추가
- 태스크명: `docs`·`tofu`·`tag-device`·`apply-aperture`·`sync-config` (spec 지정)
- `apply-aperture` desc에는 "주의: 실행 즉시 서비스 변경" 문구 필수
- Python 3.14 고정은 이번 범위 밖 (spec 비목표)

## Review Focus

1. 인자 passthrough — `mise run tofu plan`처럼 태스크명 뒤 인자가 스크립트에 그대로 전달되는가 → Task 1 Step 4로 확인
2. 하이픈 태스크명(`tag-device` 등)의 TOML 파싱 — `mise tasks ls`가 선언한 태스크를 전부 인식하는가 → Task 1 Step 3
3. `docs` 멱등 오인 — 실행 시 acl.md **헤더(생성일·커밋)는 갱신되는 게 정상**, 본문만 무변경이 기준 → Task 1 Step 5
4. agent가 `apply-aperture`를 몰라서 실행하는 사고 — `mise tasks ls` 출력에 경고 desc가 보여야 함 → Task 1 Step 3
5. 기존 `[hooks]` enter와 공존 — 태스크 추가 후 mise 설정이 여전히 유효한가 → Task 1 Step 3 (`mise tasks ls` 자체가 설정 전체 파싱에 성공해야 출력됨)

---

### Task 1: mise.toml 태스크 5개 선언

**Files:**
- Modify: `mise.toml` (기존 `[hooks]` 뒤에 `[tasks.*]` 5블록 추가)

**Interfaces:**
- Consumes: `scripts/generate-docs.sh`, `scripts/tofu.sh`, `scripts/tag-device.sh`, `scripts/apply-aperture.sh`, `scripts/sync-config.sh` (무수정)
- Produces: `mise run <task> [args...]` 진입점 5종, `mise tasks ls` 목록

- [ ] **Step 1: mise.toml에 태스크 블록 추가**

기존 `[hooks]` 섹션 뒤에 추가 (spec의 TOML 그대로):

```toml
[tasks.docs]
run = "./scripts/generate-docs.sh"
desc = "ACL 문서 재생성"
sources = ["opentofu/policy.hujson", "scripts/generate-docs.sh"]
outputs = ["docs/okf/reference/acl.md"]

[tasks.tofu]
run = "./scripts/tofu.sh"
desc = "OpenTofu 래퍼 — mise run tofu plan"

[tasks.tag-device]
run = "./scripts/tag-device.sh"
desc = "디바이스 태그 부여 — mise run tag-device <hostname> <tag>"

[tasks.apply-aperture]
run = "./scripts/apply-aperture.sh"
desc = "Aperture 설정 live 반영 — 주의: 실행 즉시 서비스 변경"

[tasks.sync-config]
run = "./scripts/sync-config.sh"
desc = "live 설정 → 로컬 스냅샷 동기화 (config.json·devices.json)"
```

- [ ] **Step 2: 설정 파싱 검증**

Run: `mise tasks ls`
Expected: 선언한 태스크가 이름·desc와 함께 목록에 나열 (하이픈 이름 포함, apply-aperture 경고 desc 보임). 에러 없으면 `[hooks]`와 공존 확인도 겸함.

- [ ] **Step 3: 무인자 usage passthrough 검증**

Run: `mise run tag-device`
Expected: `Error: hostname and tag are required` + Usage 출력 — 직접 실행(`./scripts/tag-device.sh`)과 동일. exit non-zero.

- [ ] **Step 4: 인자 passthrough 검증**

Run: `mise run tofu -- --help 2>&1 | head -3` 와 `./scripts/tofu.sh -- --help 2>&1 | head -3` 출력 비교 — 아니면 `mise run tofu` (무인자 tofu usage)로 대체.
Expected: 두 경로 모두 tofu 본체 usage 출력.

- [ ] **Step 5: docs 본문 멱등 검증**

Run: `mise run docs && git diff --stat docs/okf/reference/acl.md`
Expected: diff가 헤더 2줄(자동 생성일·커밋 hash)만 변경. 확인 후 `git restore docs/okf/reference/acl.md`로 원복.

- [ ] **Step 6: Commit**

```bash
git add mise.toml
git commit -m "feat(mise): 스크립트 5개 태스크 진입점 추가"
```

### Task 2: 문서에 진입점·발견 경로 기록

**Files:**
- Modify: `.ai/RULES.md` (발견 안내 1줄 + 스크립트 섹션 3곳에 mise 진입점)
- Modify: `README.md` (빠른 확인 섹션에 `mise tasks ls` 추가)
- Modify: `ROADMAP.md` (Phase 1 태스크 러너 항목 갱신)

**Interfaces:**
- Consumes: Task 1의 태스크명
- Produces: 문서 기록 (agent·인간 발견 경로 단일화)

- [ ] **Step 1: `.ai/RULES.md` 발견 안내 + 스크립트별 진입점**

- 발견 안내: 스크립트 관련 섹션 상단 적절한 곳에 "실행 가능한 작업은 `mise tasks ls`로 확인" 한 줄
- `### scripts/generate-docs.sh` 섹션: `mise run docs` 언급
- `### scripts/tag-device.sh` 섹션: `mise run tag-device <hostname> <tag> [--replace]` 언급
- `### opentofu/` 섹션(tofu.sh 사용법): `mise run tofu plan|apply|...` 언급
- `apply-aperture.sh`·`sync-config.sh`는 RULES.md에 섹션이 없으므로 추가하지 않음 (Surgical Changes)

- [ ] **Step 2: `README.md` 빠른 확인 섹션에 발견 명령 추가**

기존 ansible `--list-hosts` 명령 앞에 `mise tasks ls` 한 줄 추가 (문서 인덱스 역할 유지, 상세 불필요)

- [ ] **Step 3: ROADMAP.md Phase 1 갱신**

태스크 러너 항목을: mise tasks로 확정(2026-11-22 시행), poethepoet은 `pyproject.toml` 도입 시점 재평가로 변경. 시행 결과 한 줄 포함.

- [ ] **Step 4: 검증**

Run: `grep -c 'mise' .ai/RULES.md` → 4 이상, `grep -c 'mise tasks' README.md` → 1. `mise tasks ls` 여전히 정상.

- [ ] **Step 5: Commit**

```bash
git add .ai/RULES.md README.md ROADMAP.md
git commit -m "docs: RULES·README·ROADMAP에 mise 태스크 진입점 반영"
```
