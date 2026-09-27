# Sylph - Network & Domain Management System

[![ACL Documentation](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml)
[![OpenTofu](https://github.com/deuxksy/sylph/actions/workflows/opentofu.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/opentofu.yml)

Sylph는 Tailscale ACL 정책(`opentofu/policy.hujson`)을 OpenTofu로 관리하고 자동으로 문서화하는 시스템입니다. ACL 변경은 PR에서 `tofu plan`으로 검증되고 main 병합 시 GitHub Actions가 자동 apply합니다. 네트워크 문서와 디바이스 인벤토리는 스크립트로 항상 최신 상태로 재생성됩니다.

> **Source**: 상세 아키텍처·운영 가이드는 Notion에서 관리

## 문서 인덱스

| 문서 | 분류 | 설명 |
| :--- | :--- | :--- |
| [docs/acl.md](docs/acl.md) | Reference | ACL 정책 문서 (`./scripts/generate-docs.sh` 자동 생성) |
| [docs/network-diagram.md](docs/network-diagram.md) | Reference | 네트워크 연결 다이어그램 |
| [docs/devices.json](docs/devices.json) | Reference | Tailnet 디바이스 스냅샷 (`./scripts/sync-config.sh` 생성) |

## 라이선스

MIT
