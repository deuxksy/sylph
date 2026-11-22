# Phase 1 첫 increment — 로컬 Tailscale 상태 점검 (pytest-testinfra) 설계

- 날짜: 2026-11-22
- 상태: 대화 기반 설계 승인 → 문서화
- 상위: ROADMAP.md "Python 기반 인프라 자동화 스택" Phase 1

## 의도

로컬 Mac(eve)의 Tailscale 상태 점검을 pytest + pytest-testinfra로 자동화한다.
`ansible/tailscale-macos.yml`이 확인하던 항목을 상시 실행 가능한 테스트로 재현해,
Python 검증 계층(Phase 1)의 첫 가동을 확립한다. 성공 기준 = `mise run test` 한 번으로
로컬 Tailscale 건전성을 판정한다.

## 목표 / 비목표

- 목표: Python 도구체인 확립(3.14·uv), 로컬 상태 점검 테스트, mise `test` 태스크 연결
- 비목표: CI 연동(로컬 Mac 상태라 CI 러너에서 무의미), 원격 노드 SSH 점검(다음
  increment — Testinfra ssh backend × Tailscale SSH는 미검증), 기존
  `tests/apply-aperture-test.sh`의 pytest 전환(별개 과제), tofu drift 점검

## 접근 방식 (비교한 대안)

1. **로컬 Mac 자체 점검 (선택)** — testinfra local backend. SSH 변수가 없어 도구체인
   검증에 집중. playbook 점검 항목과 동일 기준
2. 원격 Linux 노드(mo 등) Tailscale SSH 점검 — paramiko × Tailscale SSH 조합 미검증,
   스파이크 선행 필요. 다음 increment로 연기
3. 인프라 drift 중심(tofu plan 일치·태그 일치) — testinfra 부적합, 순수 pytest 과제.
   Phase 1 후반 별도 처리

## 설계

### 도구체인

- `mise.toml`에 `[tools]` 추가: `python = "3.14"` — mise 관리 빌드(brew와 무관하게 재현)
- `pyproject.toml` 신규:
  - `requires-python = ">=3.14"`
  - `[dependency-groups]` dev = `pytest`, `pytest-testinfra`
  - `[tool.pytest.ini_options]` testpaths = `["tests"]`
- `uv.lock` 생성·커밋

### 테스트 — `tests/test_local_tailscale.py`

playbook이 쓰는 경로·명령을 그대로 기준으로 한다:

| 점검 | 방법 |
| :--- | :--- |
| Tailscale 바이너리 | `host.file("/opt/homebrew/bin/tailscale").exists` |
| launchd 서비스 running | `host.run("launchctl print system/sh.brew.tailscale")` stdout에 `state = running` |
| 부팅 시 시작 | PlistBuddy `Print :RunAtLoad` == `true` (plist: `/Library/LaunchDaemons/sh.brew.tailscale.plist`), 서비스 disabled 아님 |
| tailnet 연결 | `tailscale --socket=/var/run/tailscaled.socket status --json` → `BackendState == "Running"` |
| Tailscale SSH | `tailscale --socket=/var/run/tailscaled.socket debug prefs --json` → `RunSSH == true` |

launchd 점근은 sudo 없이 가능한 read 명령만 사용한다. 주의: playbook에서
`launchctl print-disabled system`은 `become: true`로 실행했다 — 무sudo 실행이
권한 거부로 실패하면 disabled 점검은 제외하고 RunAtLoad·`state = running`만으로
판정한다 (구현 시 실측으로 결정).

### mise 태스크

```toml
[tasks.test]
run = "uv run pytest tests/test_local_tailscale.py -v"
description = "로컬 Tailscale 상태 점검 (pytest-testinfra)"

[tasks.test-aperture]
run = "bash tests/apply-aperture-test.sh"
description = "apply-aperture.sh 유닛 테스트 (bash)"
```

`test-aperture`는 기존 bash 테스트의 발견 경로 확보가 목적 — 본체 무수정.

## 내 판단 (거부 가능)

- 실패 상황을 실제로 유발(서비스 중지 등)하는 검증은 하지 않는다 — 파괴적.
  항목별 존재·출력 형태만 확인
- `pyproject.toml`의 `[project]` 이름은 `sylph-tests` — 이 저장소는 패키지 배포가
  목적이 아니므로 최소 형태만

## 검증

1. `uv run pytest tests/test_local_tailscale.py -v` — 전 항목 PASS
2. `mise run test` — 동일 결과
3. `mise tasks ls` — `test`·`test-aperture` 노출
4. `uv run python -V` — 3.14.x (mise 고정 반영)

## 빌더에게 남기는 것

- `tailscale status --json`의 `BackendState`가 `Running`이 아닌 순간(로그인 직후 등)의
  재시도 정책은 필요 시 `until/retries` 대신 pytest marker로 skip 사유를 남기는
  정도로만 — 과도한 대기 로직 금지
