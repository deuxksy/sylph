# Sylph - Network & Domain Management System

[![ACL Documentation](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml)
[![OpenTofu](https://github.com/deuxksy/sylph/actions/workflows/opentofu.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/opentofu.yml)

Sylph는 Tailnet 접근 정책, 개별 장비의 Tailscale 설정, Aperture 게이트웨이 설정을 한 저장소에서 관리합니다. OpenTofu로 접근 규칙과 장비 태그를 검증하고, Ansible로 장비 설정을 재현하며, Aperture를 통해 모델 제공자와 접근 권한을 관리합니다.

- **Tailscale ACL**은 Tailnet 접근 규칙과 Tailscale SSH 권한을 정의합니다. OpenTofu가 이 정책과 장비 태그를 관리합니다. [ACL 정책 문서](docs/okf/reference/acl.md)
- **Ansible**은 개별 장비의 Tailscale SSH, 서브넷 라우터, Exit Node를 설정합니다. [장비 설정 가이드](docs/okf/how-to/manage-tailscale-devices.md)
- **Aperture**는 LLM 요청을 연결된 모델 제공자에게 라우팅하는 게이트웨이입니다. 제공자와 접근 권한은 `aperture/config.json`에서 관리합니다. [Aperture 설정 문서](docs/okf/reference/aperture.md)

GitHub Actions는 정책 변경 PR에서 OpenTofu Plan을 실행합니다. 관련 변경이 `main`에 푸시되면 Plan 성공 후 Apply를 실행합니다. ACL 문서와 장비 인벤토리는 필요할 때 스크립트로 갱신합니다.

## 빠른 확인

```bash
ansible-playbook -i ansible/inventory.ini ansible/tailscale-macos.yml --limit macos_bootstrap --list-hosts
```

## 문서 인덱스

[프로젝트 문서](docs/README.md) · [OKF 문서 인덱스](docs/okf/README.md)

## 라이선스

[MIT](LICENSE)
