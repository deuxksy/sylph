# macOS Tailscale Ansible Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to implement this plan task by task. Checkboxes track implementation.

**Goal:** 포맷 직후의 Apple Silicon Mac에 Homebrew 기반 Tailscale과 부팅 서비스를 설치하고, 첫 인증 이후 Tailscale SSH를 활성화한다.

**Architecture:** 최초 설치는 로컬 콘솔에서 실행한다. 같은 플레이북이 등록된 장비의 설정을 읽어 필요한 작업만 수행하며, Tailscale 경로로 연결된 원격 실행은 점검에 사용한다.

**Tech Stack:** Ansible, Homebrew, macOS `launchd`, Tailscale CLI.

**Spec:** [macOS Tailscale Ansible 설계](../specs/2026-11-22-macos-tailscale-ansible-design.md).

## 공통 제약

- 최초 실행은 Tailscale 앱과 CLI가 모두 없는 Apple Silicon Mac을 기준으로 한다. 기존 Homebrew 설치를 사용하며 기존 Tailscale 포뮬러를 자동 업그레이드하지 않는다.
- 운영자는 첫 Tailnet 로그인을 직접 한다. 기존 등록 상태 파일과 노드 ID를 보존한다.
- 운영 중인 데몬은 재시작하지 않는다. GUI 연결 해제, 삭제, 전환 복구는 운영자가 수행한다.
- OpenTofu의 정책과 장비 태그, Aperture 설정, Linux 및 Raspberry Pi 플레이북은 그대로 둔다.

## 검토할 실패 경로

| 조건 | 기대 동작 | 검증 작업 |
|---|---|---|
| Homebrew 경로가 셸의 PATH에 없음 | 절대 경로 검사로 기존 설치를 판별 | 1 |
| Homebrew와 Tailscale이 모두 없음 | Homebrew를 준비한 뒤 Tailscale만 설치 | 1 |
| 서비스가 실행 중이지만 Tailnet 미인증 | SSH 변경 전에 멈추고 로그인 후 재실행을 안내 | 2 |
| GUI VPN이 연결되어 있거나 확인 결과가 모호함 | 장비 설정을 변경하기 전에 종료 | 2 |
| 원격 장비가 오프라인이거나 SSH 설정이 기대와 다름 | 안전한 관리 경로가 생길 때까지 읽기 전용 결과만 기록 | 3 |

## 작업 1. 신규 Mac의 설치 준비

**파일** — `ansible/tailscale-macos.yml`, `docs/okf/how-to/manage-tailscale-devices.md`

**인터페이스** — 플레이 대상 그룹은 `macos_tailscale`이다. 최초 실행은 작업 3의 로컬 인벤토리 항목을 `--limit macos_bootstrap`으로 선택한다.

- [x] macOS Command Line Tools와 Ansible 컨트롤러를 먼저 준비하는 로컬 콘솔 절차를 문서화한다. Homebrew가 없는 분기까지 시험할 수 있도록, Ansible 준비는 Homebrew에 의존하지 않는 Python 가상 환경 절차로 안내한다. 설치 전제조건에 OS의 사용자 확인이 필요한 경우 그 지점과 재실행 방법을 적는다.
- [x] 플레이북에서 `Darwin`과 `arm64`를 확인하고, `/opt/homebrew/bin/brew` 존재 여부로 분기한다. 로컬 콘솔 실행에서만 Homebrew 공식 설치 방법을 사용한다. 설치는 로그인한 관리자 사용자로 실행하고, 설치 후 절대 경로를 다시 확인한다.
- [x] 같은 절대 경로에서 `brew list --versions tailscale`로 설치 여부를 확인하고, 포뮬러가 없을 때만 `brew install tailscale`을 일반 사용자로 실행한다. 기존 포뮬러가 있으면 설치 태스크를 건너뛴다.
- [ ] 초기화한 테스트 Mac에서 Homebrew가 없는 경우와 이미 있는 경우를 각각 검증한다. 두 경우 모두 `/opt/homebrew/bin/tailscale`이 생기고, 기존 Homebrew가 있는 쪽에서는 설치 태스크가 생략되어야 한다. 실제 초기화 실험 장비가 없으면 그 검증을 미실행으로 기록한다.

## 작업 2. 부팅 서비스와 Tailscale SSH 관리

**파일** — `ansible/tailscale-macos.yml`, `docs/okf/how-to/manage-tailscale-devices.md`

**인터페이스** — 서비스 이름 `system/sh.brew.tailscale`, CLI `/opt/homebrew/bin/tailscale`, Unix 소켓 `/var/run/tailscaled.socket`. 상태 조회는 Ansible 변경 건수에 포함하지 않는다.

- [x] 설치나 서비스 변경 전에 `scutil --nc list`로 연결된 Tailscale GUI VPN을 확인한다. GUI 연결이 활성 상태이거나 판별에 실패하면 중단한다.
- [x] `launchctl print system/sh.brew.tailscale`과 등록된 plist의 `RunAtLoad`를 확인한다. 로컬에서 서비스가 등록되지 않았거나 시작되지 않았을 때만 관리자 권한으로 `/opt/homebrew/bin/brew services start tailscale`을 실행한다. 이미 실행 중인 서비스의 시작 상태가 기대와 다르면 재시작 대신 진단 결과를 출력한다.
- [x] 소켓을 명시해 `status --json`을 조회한다. `NeedsLogin`이면 로컬 콘솔에서 같은 소켓으로 `tailscale up`을 실행하고 다시 플레이북을 실행하도록 안내한다. 그 외 `Running` 이외의 상태에서는 SSH 설정을 변경하지 않는다.
- [x] `Running` 상태에서 `debug prefs`의 `RunSSH`를 확인한다. 로컬에서 값이 꺼졌을 때만 관리자 권한으로 `tailscale set --ssh`를 실행한다. 전체 prefs JSON은 로그에 쓰지 않는다. 변경 뒤 `RunSSH`, 노드 ID와 DNS 이름을 다시 확인한다.
- [ ] 이미 등록된 `eve`에서 두 번 실행한 뒤 두 번째 실행의 `changed=0`과 동일한 노드 ID를 확인한다. 별도 Tailnet 피어에서 `eve`로 새 SSH 로그인을 확인한다. 미인증 상태와 GUI 연결 상태의 차단은 초기 설치 실험 환경에서 검증한다.

## 작업 3. 인벤토리와 원격 점검

**파일** — `ansible/inventory.ini`, `ansible/tailscale-macos.yml`, `README.md`, `docs/okf/README.md`, `docs/okf/how-to/manage-tailscale-devices.md`

**인터페이스** — `macos_tailscale` 그룹에 로컬 실행용 `macos_bootstrap`과 점검용 `eve`, `axiom`을 정의한다. 실행 명령은 항상 `--limit`으로 한 장비를 선택한다.

- [x] `macos_bootstrap`은 `ansible_connection=local`로 정의한다. 원격 대상은 검증된 SSH 호스트 키를 요구하도록 macOS 그룹에만 명시적으로 설정한다. 플레이는 `serial: 1`로 실행하고, 원격 경로에서는 설치, 서비스 시작, SSH 상태 변경 태스크를 실행하지 않는다.
- [x] `ansible-playbook -i ansible/inventory.ini ansible/tailscale-macos.yml --syntax-check`를 실행한다. `--list-hosts --limit macos_bootstrap`과 `--list-hosts --limit axiom`이 각각 한 대를 표시하는지 확인한다.
- [ ] `axiom`의 접속 가능 여부와 서비스 상태를 읽기 전용으로 점검한다. 연결할 수 없으면 결과를 기록한다. 검증 목적으로 원격 데몬을 재시작하거나 GUI를 전환하지 않는다.
- [x] README와 OKF 인덱스에서 최초 설치 순서, 인증 후 재실행, 운영 상태 점검, 기존 GUI에서의 수동 전환 가이드를 연결한다. 문서 링크와 `git diff --check`를 확인한다.

## 실행 결과

- `eve`의 로컬 플레이를 두 번 실행했다. 두 실행 모두 `changed=0`이었으며 노드 ID와 DNS 이름 검증을 통과했다. `walle`에서 `eve`로 Tailscale SSH 로그인을 확인했다.
- 초기화한 테스트 Mac이 없어 Homebrew 설치, Tailscale 최초 설치·로그인, GUI 연결 차단 분기의 실기기 검증은 남아 있다.
- `axiom`은 Tailnet에서 오프라인이며 상태 점검을 완료하지 못했다.
