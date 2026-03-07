# Tailscale ACL 문서

> 자동 생성일: 2026-03-07 22:04:57 +0700
> 커밋: `7a35f6b` (Crong)

---

## 📋 개요

이 문서는 Tailscale ACL 정책(`policy.hujson`)을 기반으로 자동 생성되었습니다.


## 👥 그룹 및 사용자

| 그룹 | 사용자 |
|------|--------|
| `🔍 Parsing groups...` |  |
| `group:admin` | ksymailing@gmail.com |
| `group:member` | deuxksy@gmail.com |
| `group:develop` | deuxksy@gmail.com |


## 🏷️ 태그 및 소유자

| 태그 | 소유자 |
|------|--------|
| `🔍 Parsing tag owners...` |  |
| `tag:https` | group:admin, autogroup:admin |
| `tag:docker` | group:admin, autogroup:admin |
| `tag:heritage` | group:admin, autogroup:admin |
| `tag:mobile` | group:admin, autogroup:admin |
| `tag:server` | group:admin, autogroup:admin |
| `tag:network` | group:admin, autogroup:admin |
| `tag:pc` | group:admin, autogroup:admin |


## 🔐 ACL 규칙

| 소스 | 대상 | 액션 |
|------|------|------|
| `🔍 Parsing ACL rules...` | `` |  |
| `*` | `*:*` | accept |


## 🔑 SSH 규칙

| 액션 | 소스 | 대상 | 허용 사용자 |
|------|------|------|-------------|
| 🔍 Parsing SSH rules... | `` | `` | `` |
| accept | `group:admin, group:member, group:develop` | `tag:server, tag:network, autogroup:self` | `autogroup:nonroot, crong, deck` |


## 📊 네트워크 연결 다이어그램

```mermaid
graph TB
    subgraph "그룹"
        🔍 Parsing groups...["🔍 Parsing groups..."]
        G-admin["group:admin"]
        G-member["group:member"]
        G-develop["group:develop"]
    end

    subgraph "태그"
        T-docker["tag:docker"]
        T-heritage["tag:heritage"]
        T-https["tag:https"]
        T-mobile["tag:mobile"]
        T-network["tag:network"]
        T-pc["tag:pc"]
        T-server["tag:server"]
    end

    G-admin -->|소유| T-https
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-https
    G-admin -->|소유| T-docker
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-docker
    G-admin -->|소유| T-heritage
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-heritage
    G-admin -->|소유| T-mobile
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-mobile
    G-admin -->|소유| T-server
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-server
    G-admin -->|소유| T-network
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-network
    G-admin -->|소유| T-pc
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-pc

    classDef groupStyle fill:#e1f5fe,stroke:#01579b
    classDef tagStyle fill:#f3e5f5,stroke:#4a148c

    class 🔍 Parsing groups... G-admin G-member G-develop  groupStyle
    class T-docker T-heritage T-https T-mobile T-network T-pc T-server  tagStyle
```


---

## 🔗 참고

- [Tailscale ACL 문서](https://tailscale.com/kb/1018/acls/)
- [SSH 설명서](https://tailscale.com/kb/1193/tailscale-ssh/)
- [policy.hujson](../policy.hujson)

---
*이 문서는 \`scripts/generate-docs.sh\`에 의해 자동 생성되었습니다.*
