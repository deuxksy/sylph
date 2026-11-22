# Phase 1 로컬 Tailscale 점검 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로컬 Mac(eve)의 Tailscale 상태를 pytest-testinfra로 점검하는 `mise run test` 확립 — Phase 1 첫 increment.

**Architecture:** 도구체인(mise 3.14 + uv pyproject) → 테스트 파일(시스템 상태 점검 5종) → mise 태스크 연결 순서. 테스트가 곧 산출물 — 별도 프로덕션 코드 없음.

**Tech Stack:** Python 3.14, uv, pytest 9.x, pytest-testinfra 10.2.2, mise tasks.

**Spec:** `docs/superpowers/specs/2026-11-22-phase1-testinfra-design.md`

## Global Constraints

- `requires-python = ">=3.14"`, mise `[tools]` python = `"3.14"`
- 경로 상수(spec 지정): `TAILSCALE = "/opt/homebrew/bin/tailscale"`, socket `--socket=/var/run/tailscaled.socket`, 서비스 `system/sh.brew.tailscale`, plist `/Library/LaunchDaemons/sh.brew.tailscale.plist`
- sudo 사용 금지 — read 명령만
- 시스템 상태를 변경하는 검증(서비스 중지 등) 금지
- `tests/apply-aperture-test.sh`·ansible·scripts 무수정

## Review Focus

1. `launchctl print-disabled system` 무sudo 권한 거부 — spec fallback 규칙(실측 후 제외 판정) → Task 2 Step 4
2. `launchctl print` 출력 형식 변화(macOS 업데이트) — `state = running` 매칭은 정규식 `^\s*state = running\s*$`(multi-line) 사용 → Task 2 test 코드에 고정
3. `BackendState`가 `NeedsLogin` 등 비정상 상태 — skip하지 않고 FAIL이 정답(점검 목적) → Task 2 test에 skip 없음을 명시
4. tailscale CLI 미응답/소켓 부재 — traceback 대신 `result.rc == 0` assert + stderr 메시지로 명확한 실패 → Task 2 test 코드에 고정
5. 비 Apple Silicon Mac에서 실행 — `/opt/homebrew` 경로가 없으면 즉시 FAIL(하드코딩 의도) → Task 2 test 코드에 고정

---

### Task 1: Python 도구체인

**Files:**
- Modify: `mise.toml` (`[tools]` 추가)
- Create: `pyproject.toml`
- Create: `.python-version`
- Create: `uv.lock` (uv sync 생성)
- Modify: `.gitignore` (`.venv/` 없을 때만)

**Interfaces:**
- Produces: `uv run pytest` 실행 환경, Python 3.14 고정, pytest testpaths = `["tests"]`

- [ ] **Step 1: mise.toml 최상단에 tools 추가**

```toml
[tools]
python = "3.14"
```

(`[hooks]` 앞에 배치 — TOML 테이블 순서 무관하나 가독성)

- [ ] **Step 2: pyproject.toml + .python-version 생성**

`pyproject.toml`:

```toml
[project]
name = "sylph-tests"
version = "0.1.0"
requires-python = ">=3.14"
dependencies = []

[dependency-groups]
dev = [
    "pytest",
    "pytest-testinfra",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

`.python-version`: `3.14` 한 줄 (uv의 Python 선택 결정성 — PATH의 3.15가 우선되는 것 방지)

- [ ] **Step 3: 의존 설치·lock 생성**

Run: `uv sync`
Expected: `uv.lock` 생성, `.venv/` 생성, pytest·pytest-testinfra 설치 완료 메시지. mise가 3.14 다운로드(최초 수 분)할 수 있음.

- [ ] **Step 4: 버전 검증**

Run: `uv run python -V`
Expected: `Python 3.14.x`

- [ ] **Step 5: Commit**

```bash
git add mise.toml pyproject.toml .python-version uv.lock .gitignore
git commit -m "feat(tools): Python 3.14 도구체인 및 uv 의존 관리 추가"
```

### Task 2: 로컬 Tailscale 점검 테스트

**Files:**
- Test: `tests/test_local_tailscale.py`

**Interfaces:**
- Consumes: Task 1의 `uv run pytest` 환경, testinfra `host` fixture
- Produces: test 함수 5종 — `test_tailscale_binary_exists`, `test_launchd_service_running`, `test_run_at_load_enabled`, `test_backend_state_running`, `test_tailscale_ssh_enabled` (+ Step 4 결과에 따라 `test_service_not_disabled`)

- [ ] **Step 1: 테스트 파일 작성**

```python
import json
import re

TAILSCALE = "/opt/homebrew/bin/tailscale"
SOCKET = "--socket=/var/run/tailscaled.socket"
SERVICE = "system/sh.brew.tailscale"
PLIST = "/Library/LaunchDaemons/sh.brew.tailscale.plist"


def test_tailscale_binary_exists(host):
    assert host.file(TAILSCALE).exists


def test_launchd_service_running(host):
    result = host.run(f"launchctl print {SERVICE}")
    assert result.rc == 0, result.stderr
    assert re.search(r"^\s*state = running\s*$", result.stdout, re.M)


def test_run_at_load_enabled(host):
    result = host.run(f"/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' {PLIST}")
    assert result.rc == 0, result.stderr
    assert result.stdout.strip() == "true"


def test_backend_state_running(host):
    result = host.run(f"{TAILSCALE} {SOCKET} status --json")
    assert result.rc == 0, result.stderr
    assert json.loads(result.stdout)["BackendState"] == "Running"


def test_tailscale_ssh_enabled(host):
    result = host.run(f"{TAILSCALE} {SOCKET} debug prefs --json")
    assert result.rc == 0, result.stderr
    assert json.loads(result.stdout)["RunSSH"] is True
```

skip/xfail 없이 실패를 그대로 노출한다(Review Focus 3).

- [ ] **Step 2: 전체 실행**

Run: `uv run pytest tests/test_local_tailscale.py -v`
Expected: 전 항목 PASS (건전한 로컬 Mac 기준)

- [ ] **Step 3: 실패 감지 확인 (watch-it-fail)**

`TAILSCALE` 상수를 `/nonexistent/tailscale`로 임시 변경 → `uv run pytest tests/test_local_tailscale.py::test_tailscale_binary_exists -v` FAIL 확인 → 상수 원복 → 재실행 PASS.
Expected: 변경 시 FAIL, 원복 시 PASS (테스트가 실제로 감지能力을 가짐)

- [ ] **Step 4: disabled 점검 실측 (spec fallback)**

Run: `launchctl print-disabled system`
- 성공(rc 0)이면 `test_service_not_disabled` 추가 — stdout에 `sh.brew.tailscale` = `disabled` 표기 없음을 assert
- 권한 거부면 추가하지 않음 — 실행 결과를 ledger에 Ruling으로 기록

- [ ] **Step 5: Commit**

```bash
git add tests/test_local_tailscale.py
git commit -m "test: 로컬 Tailscale 상태 점검 testinfra 테스트 추가"
```

### Task 3: mise 태스크 연결

**Files:**
- Modify: `mise.toml` (태스크 2개 추가)

**Interfaces:**
- Consumes: Task 2의 테스트 파일 경로
- Produces: `mise run test`, `mise run test-aperture` 진입점

- [ ] **Step 1: 태스크 추가**

```toml
[tasks.test]
run = "uv run pytest tests/test_local_tailscale.py -v"
description = "로컬 Tailscale 상태 점검 (pytest-testinfra)"

[tasks.test-aperture]
run = "bash tests/apply-aperture-test.sh"
description = "apply-aperture.sh 유닛 테스트 (bash)"
```

- [ ] **Step 2: 태스크 실행 검증**

Run: `mise run test`
Expected: 전 항목 PASS

Run: `mise run test-aperture`
Expected: `PASS:` 라인 7개, exit 0

Run: `mise tasks ls`
Expected: `test`·`test-aperture` 노출

- [ ] **Step 3: Commit**

```bash
git add mise.toml
git commit -m "feat(mise): test·test-aperture 태스크 추가"
```
