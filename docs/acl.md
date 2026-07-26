# Tailscale ACL 문서

> 자동 생성일: 2026-07-25 15:12:21 +0900
> 커밋: `9dd2f69` (Crong)

---

## 📋 개요

이 문서는 Tailscale ACL 정책(`policy.hujson`)을 기반으로 자동 생성되었습니다.


## 👥 그룹 및 사용자

| 그룹 | 사용자 |
|------|--------|
| `group:admin` | ksymailing@gmail.com |
| `group:member` | azc2004@gmail.com, sj92031@gmail.com |
| `group:develop` | deuxksy@gmail.com |


## 🏷️ 태그 및 소유자

| 태그 | 소유자 |
|------|--------|
| `tag:https` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:docker` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:k8s` | tag:k8s-operator |
| `tag:k8s-operator` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:heritage` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:mobile` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:projector` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:server` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:network` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:pc` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:windows` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:mac` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:linux` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:ai` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:kyolim` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:oci` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:pi` | group:member, group:develop, group:admin, autogroup:admin |
| `tag:github-action` | group:member, group:develop, group:admin, autogroup:admin |


## 🔐 ACL 규칙

| 소스 | 대상 | 액션 |
|------|------|------|
| `*` | `tag:ai:*` | accept |
| `*` | `*:*` | accept |


## 🔑 SSH 규칙

| 액션 | 소스 | 대상 | 허용 사용자 |
|------|------|------|-------------|
| accept | `group:admin, group:member, group:develop, autogroup:admin` | `tag:server, tag:network, tag:pi, autogroup:self` | `autogroup:nonroot, crong, deck` |


## 📊 네트워크 연결 다이어그램

```mermaid
graph TB
    subgraph "그룹"
        G-admin["group:admin"]
        G-member["group:member"]
        G-develop["group:develop"]
    end

    subgraph "태그"
        T-ai["tag:ai"]
        T-docker["tag:docker"]
        T-github-action["tag:github-action"]
        T-heritage["tag:heritage"]
        T-https["tag:https"]
        T-k8s["tag:k8s"]
        T-k8s-operator["tag:k8s-operator"]
        T-kyolim["tag:kyolim"]
        T-linux["tag:linux"]
        T-mac["tag:mac"]
        T-mobile["tag:mobile"]
        T-network["tag:network"]
        T-oci["tag:oci"]
        T-pc["tag:pc"]
        T-pi["tag:pi"]
        T-projector["tag:projector"]
        T-server["tag:server"]
        T-windows["tag:windows"]
    end

    G-member -->|소유| T-https
    G-develop -->|소유| T-https
    G-admin -->|소유| T-https
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-https
    G-member -->|소유| T-docker
    G-develop -->|소유| T-docker
    G-admin -->|소유| T-docker
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-docker
    auto-tag:k8s-operator["tag:k8s-operator"] -->|소유| T-k8s
    G-member -->|소유| T-k8s-operator
    G-develop -->|소유| T-k8s-operator
    G-admin -->|소유| T-k8s-operator
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-k8s-operator
    G-member -->|소유| T-heritage
    G-develop -->|소유| T-heritage
    G-admin -->|소유| T-heritage
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-heritage
    G-member -->|소유| T-mobile
    G-develop -->|소유| T-mobile
    G-admin -->|소유| T-mobile
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-mobile
    G-member -->|소유| T-projector
    G-develop -->|소유| T-projector
    G-admin -->|소유| T-projector
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-projector
    G-member -->|소유| T-server
    G-develop -->|소유| T-server
    G-admin -->|소유| T-server
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-server
    G-member -->|소유| T-network
    G-develop -->|소유| T-network
    G-admin -->|소유| T-network
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-network
    G-member -->|소유| T-pc
    G-develop -->|소유| T-pc
    G-admin -->|소유| T-pc
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-pc
    G-member -->|소유| T-windows
    G-develop -->|소유| T-windows
    G-admin -->|소유| T-windows
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-windows
    G-member -->|소유| T-mac
    G-develop -->|소유| T-mac
    G-admin -->|소유| T-mac
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-mac
    G-member -->|소유| T-linux
    G-develop -->|소유| T-linux
    G-admin -->|소유| T-linux
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-linux
    G-member -->|소유| T-ai
    G-develop -->|소유| T-ai
    G-admin -->|소유| T-ai
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-ai
    G-member -->|소유| T-kyolim
    G-develop -->|소유| T-kyolim
    G-admin -->|소유| T-kyolim
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-kyolim
    G-member -->|소유| T-oci
    G-develop -->|소유| T-oci
    G-admin -->|소유| T-oci
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-oci
    G-member -->|소유| T-pi
    G-develop -->|소유| T-pi
    G-admin -->|소유| T-pi
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-pi
    G-member -->|소유| T-github-action
    G-develop -->|소유| T-github-action
    G-admin -->|소유| T-github-action
    auto-autogroup:admin["autogroup:admin"] -->|소유| T-github-action

    classDef groupStyle fill:#e1f5fe,stroke:#01579b
    classDef tagStyle fill:#f3e5f5,stroke:#4a148c

    class G-admin G-member G-develop  groupStyle
    class T-ai T-docker T-github-action T-heritage T-https T-k8s T-k8s-operator T-kyolim T-linux T-mac T-mobile T-network T-oci T-pc T-pi T-projector T-server T-windows  tagStyle
```


---

## 🔗 참고

- [Tailscale ACL 문서](https://tailscale.com/kb/1018/acls/)
- [SSH 설명서](https://tailscale.com/kb/1193/tailscale-ssh/)
- [policy.hujson](../policy.hujson)

---
*이 문서는 \`scripts/generate-docs.sh\`에 의해 자동 생성되었습니다.*
