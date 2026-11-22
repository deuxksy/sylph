# Sylph - Network & Domain Management System

[![ACL Documentation](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml)
[![OpenTofu](https://github.com/deuxksy/sylph/actions/workflows/opentofu.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/opentofu.yml)

Sylph는 Tailscale 접근 정책(`opentofu/policy.hujson`)과 장비 태그를 OpenTofu로 관리합니다. 정책 변경 PR에서 GitHub Actions가 Plan을 실행하고, 관련 변경이 `main`에 푸시되면 Plan 성공 후 Apply를 실행합니다. ACL 문서와 장비 인벤토리는 필요할 때 스크립트로 갱신합니다.

> **Source**: 상세 아키텍처·운영 가이드는 Notion에서 관리

## 문서 인덱스

[프로젝트 문서](docs/README.md) · [OKF 문서 인덱스](docs/okf/README.md)

## 라이선스

[MIT](LICENSE)
