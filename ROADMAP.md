# Roadmap

장기 과제와 추진 방향을 기록한다. 완료되거나 무효가 된 항목은 제거한다.

## Python 기반 인프라 자동화 스택

상태: 장기 과제 (시작 미정) · 등록: 2026-11-22

### 버전 체계

- 세대 구분 (2026-11-22 결정): 기존 시스템(OpenTofu·Ansible·bash, `YYMMDDHHMM` timestamp 태그) = **v1** (릴리즈 태그 `v1.0.0`), Python 스택 전환 = **v2** (`v2.0.0`)
- 과거 SemVer 태그(v0.1.0·v0.2.0, 2026-07)는 초기 실험기 유물로 존치
- v2 완료 시점에 `v2.0.0` 태그 생성

기존 IaC(OpenTofu·Ansible·bash)를 유지하면서 Python 생태계의 검증·자동화 도구를 단계적으로 도입한다.

### 공통 — 도구체인

- Python 버전: `mise.toml`에 `3.14` 고정. 근거(2026-11-22 실측): pyinfra 3.11.2·pytest 9.2.0·poethepoet 0.49.0이 PyPI classifier에 3.14까지 공식 선언, 이슈 트래커에 3.14 관련 open 이슈 없음. 3.15는 아직 pyinfra·poethepoet 미선언. 3.14 EOL 2030-10로 가장 긴 지원 기간
- 패키지 관리: uv + uvx

### Phase 1 — 검증 계층 (우선)

- Testinfra: 배포 후 포트·데몬·파일 상태 검증을 pytest로 자동화. 수동 검증(tofu plan 3-way 일치 등)을 대체
  - 설치명 주의: PyPI 분포명은 `pytest-testinfra`(10.2.2, 2025-03). `testinfra`라는 옛 분포명은 2020년에 멈춘 유령 패키지(6.0.0)
  - 유지보수 저활동(연 1회 릴리즈 수준)이지만 pytest 얹은 얇은 플러그인이라 파손 표면 작음
- 태스크 러너: **mise tasks 확정** (2026-11-22 시행) — `mise.toml [tasks]` 선언적 진입점, 모든 AI agent가 `mise tasks ls`로 자가발견. 스크립트 본체는 무수정
  - poethepoet은 `pyproject.toml` 도입 시점(Phase 1 정식 착수)에 재평가 — mise 태스크가 uv 실행을 커버하므로 uv 표준과 충돌 없음
  - invoke 탈락: 단일 유지관리자 정체(2026-04 이후 무활동), 신버전 Python 대응 지연 전례(pyinvoke/invoke#1015), Python 재작성 필요

### Phase 2 — 구성 관리 대체 (조건부)

- pyinfra: Ansible(`ansible/tailscale-macos.yml`) 대체 후보
- macOS 지원 검증 결과(2026-11-22, pyinfra 3.x 공식 문서):
  - `brew` 모듈 존재 — `brew.packages`·`brew.casks`·`brew.tap`·`brew.trust` ("Manage brew packages on mac/OSX")
  - macOS 특화 모듈은 brew가 사실상 전부. `defaults`(plist)·launchd 관리 모듈은 없음
  - 단, 현 playbook은 macOS 특화 Ansible 모듈을 사용하지 않음 — 전부 `ansible.builtin.command`(brew/launchctl/PlistBuddy/scutil/tailscale CLI) + `stat`/`assert` 조합. pyinfra의 generic operation(`server.shell`, `files.download`)으로 직접 매핑되고, Jinja2 `from_json` 대신 순수 Python 파싱으로 단순화 가능
- 스파이크 범위: `@local` 실행 + sudo 조합으로 launchctl/PlistBuddy 제어 검증

### 제외

- Pulumi: 안정 운영 중인 OpenTofu 파이프라인을 대체할 편익이 없음
- Kopf: K8s를 운영하지 않아 대상 아님
