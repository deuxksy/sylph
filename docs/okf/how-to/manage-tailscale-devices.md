# Tailscale 장비 설정

OpenTofu는 Tailnet 접근 정책과 장비 태그를 관리합니다. Ansible은 장비에 접속해 해당 장비의 Tailscale 설정을 적용합니다.

## Ansible 플레이북 선택

| 플레이북 | 인벤토리 그룹 | 하는 일 |
|---|---|---|
| [tailscale-ssh.yml](../../../ansible/tailscale-ssh.yml) | `tailscale-ssh` | 등록된 Linux 장비에서 Tailscale SSH를 활성화하고 새 연결에서 설정을 검증합니다. |
| [tailscale-pi.yml](../../../ansible/tailscale-pi.yml) | `rpi` | Raspberry Pi를 서브넷 라우터와 Exit Node로 설정합니다. |
| [tailscale-macos.yml](../../../ansible/tailscale-macos.yml) | `macos_tailscale` | Apple Silicon Mac에서 Homebrew Tailscale을 설치하고 부팅 서비스와 SSH 상태를 확인합니다. |

실행 전에 [인벤토리](../../../ansible/inventory.ini)의 접속 계정과 대상 그룹을 확인합니다. 저장소 루트에서 대상만 확인하려면 다음 명령을 사용합니다.

```bash
ansible-playbook -i ansible/inventory.ini ansible/tailscale-ssh.yml --list-hosts
ansible-playbook -i ansible/inventory.ini ansible/tailscale-pi.yml --list-hosts
```

## 초기화한 macOS에 설치

Tailscale이 설치되지 않은 Apple Silicon Mac의 로컬 콘솔에서 시작합니다. 인터넷에 연결하고 관리자 권한이 있는 일반 사용자로 로그인합니다. Command Line Tools가 없으면 `xcode-select --install`을 실행하고 macOS 설치 창에서 완료합니다.

저장소 루트에서 Homebrew 없이도 Ansible을 실행할 수 있도록 Python 가상 환경을 준비합니다. 사용 가능한 `python3`가 없다면 먼저 Python을 설치합니다.

```bash
python3 -m venv ~/.venvs/sylph-ansible
~/.venvs/sylph-ansible/bin/python -m pip install ansible-core
sudo -v
~/.venvs/sylph-ansible/bin/ansible-playbook -i ansible/inventory.ini ansible/tailscale-macos.yml --limit macos_bootstrap -K
```

Homebrew가 있으면 설치를 건너뜁니다. 플레이북이 `NeedsLogin`을 알리면 로컬 콘솔에서 아래 명령을 실행하고 브라우저에서 Tailnet 인증을 완료합니다.

```bash
sudo /opt/homebrew/bin/tailscale --socket=/var/run/tailscaled.socket up
```

같은 플레이북을 다시 실행하면 Tailscale SSH를 활성화합니다. Tailnet 정책과 장비 태그는 OpenTofu에서 관리합니다. 정책 적용 후 다른 Tailnet 장비에서 `tailscale ssh <계정>@<Mac 이름>`으로 새 연결을 열어 로그인합니다.

## 설정한 macOS 점검

`eve`와 `axiom`은 Homebrew의 오픈소스 `tailscaled`를 사용합니다. 로컬 재실행에서 이미 정상인 설치와 서비스는 변경되지 않습니다. 원격에서는 기존 서비스와 SSH 상태를 조회합니다.

```bash
ansible-playbook -i ansible/inventory.ini ansible/tailscale-macos.yml --limit axiom --check -K
```

원격 점검 전에 신뢰할 수 있는 경로에서 대상 SSH 호스트 키를 확인합니다. `axiom`이 오프라인이면 로컬 콘솔이나 독립된 관리 경로에서 확인합니다.

## 기존 GUI 앱으로 연결된 Mac

전환 작업은 로컬 콘솔이나 별도 관리 경로가 있는 상태에서 진행합니다. 기존 GUI VPN 연결을 유지한 채 테스트용 오픈소스 데몬에서 먼저 새 SSH 로그인을 확인합니다. GUI 연결을 끈 뒤 새 경로에서 다시 접속해 검증한 다음 플레이북으로 서비스 상태를 확인합니다.
