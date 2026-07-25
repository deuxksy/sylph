# Sylph - Network & Domain Management System

[![ACL Documentation](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/acl-docs.yml)
[![Sync Tailscale ACLs](https://github.com/deuxksy/sylph/actions/workflows/tailscale-acl.yml/badge.svg?branch=main)](https://github.com/deuxksy/sylph/actions/workflows/tailscale-acl.yml)

Sylph는 Tailscale ACL 정책(`policy.hujson`)을 자동으로 문서화하고 Cloudflare(DNS)를 통한 도메인을 통합 관리하는 시스템입니다.

## Topology

```mermaid
graph TB
    subgraph "Tailnet: ksymailing@gmail.com"
        subgraph "Mobile (tag:mobile)"
            M1[13-mini<br/>iOS]
            M2[pro<br/>iOS]
            M3[z-5<br/>Android]
        end

        subgraph "PC (tag:pc)"
            PC1[eve<br/>macOS]
            PC2[Surface<br/>Windows]
        end

        subgraph "Server (tag:server)"
            S1[girl<br/>Linux]
            S2[walle<br/>Linux<br/>Exit Node]
        end

        subgraph "Infrastructure"
            I1[heritage<br/>Linux<br/>tag:docker]
            I2[arv<br/>Linux<br/>tag:https, tag:network<br/>Subnet Router]
            I3[steward<br/>Linux]
        end
    end

    M1 & M2 & M3 -.->|Mesh VPN| PC1
    M1 & M2 & M3 -.->|Mesh VPN| PC2
    M1 & M2 & M3 -.->|Mesh VPN| S1
    M1 & M2 & M3 -.->|Mesh VPN| S2
    M1 & M2 & M3 -.->|Mesh VPN| I1
    M1 & M2 & M3 -.->|Mesh VPN| I2

    PC1 -.->|Mesh VPN| S1
    PC1 -.->|Mesh VPN| S2
    PC1 -.->|Mesh VPN| I1
    PC1 -.->|Mesh VPN| I2

    PC2 -.->|Mesh VPN| S1
    PC2 -.->|Mesh VPN| S2
    PC2 -.->|Mesh VPN| I1
    PC2 -.->|Mesh VPN| I2

    S1 -.->|Mesh VPN| S2
    S1 -.->|Mesh VPN| I1
    S1 -.->|Mesh VPN| I2

    S2 -.->|Mesh VPN| I1
    S2 -.->|Mesh VPN| I2

    I1 -.->|Mesh VPN| I2

    S2 ==>|Exit Node| Internet((🌐 Internet))
    I2 ==>|Subnet Routes| LAN[192.168.1.0/24<br/>192.168.8.0/24]

    style M1 fill:#e1f5fe
    style M2 fill:#e1f5fe
    style M3 fill:#e1f5fe
    style PC1 fill:#f3e5f5
    style PC2 fill:#f3e5f5
    style S1 fill:#fff3e0
    style S2 fill:#ffebee
    style I1 fill:#e8f5e9
    style I2 fill:#e8f5e9
```

## Hardware Specs

| 장비 | 하드웨어 | OS | 특이사항 |
|------|----------|-----|----------|
| 13-mini | - | iOS | tag:mobile |
| pro | - | iOS | tag:mobile |
| z-5 | - | Android | tag:mobile |
| eve | - | macOS | tag:pc |
| Surface | - | Windows | tag:pc |
| girl | - | Linux | tag:server |
| walle | - | Linux | Exit Node, tag:server |
| heritage | - | Linux | tag:docker |
| arv | - | Linux | tag:https, tag:network, Subnet Router |
| steward | - | Linux | tag:network |

## Workflow

```mermaid
graph LR
    A[policy.hujson 수정] --> B[문서 생성]
    B --> C[PR 생성]
    C --> D{GitHub Actions}
    D -->|policy.hujson 변경| E[PR 코멘트 생성]
    D -->|workflow_dispatch| E
    E --> F[문서 검토]
    F --> G[main 병합]
```

## 기능

- 📄 **Markdown 문서 생성** - ACL 정책을 사람이 읽기 쉬운 형태로 변환
- 📊 **Mermaid 다이어그램** - 네트워크 연결을 시각화
- 💬 **PR 자동 코멘트** - 변경사항을 PR에 자동으로 코멘트
- ✅ **문법 검증** - HUJSON/JSON 유효성 검사

## 사용법

### 로컬에서 문서 생성

```bash
# 기본 사용 (docs/acl.md 생성)
./scripts/generate-docs.sh

# PR 코멘트용 diff도 생성
./scripts/generate-docs.sh --pr-comment

# 상세 로그 출력
./scripts/generate-docs.sh --verbose

# 도움말
./scripts/generate-docs.sh --help
```

### GitHub Actions

PR이 생성되거나 `policy.hujson`이 변경되면 자동으로 PR에 변경사항 코멘트가 생성됩니다.
ACL의 실제 적용(apply)은 로컬에서 OpenTofu로 수행합니다: `./scripts/tofu.sh plan && ./scripts/tofu.sh apply`

## 파일 구조

```
.
├── policy.hujson              # ACL 정책 파일
├── opentofu/                  # OpenTofu tailnet 관리 (ACL apply, device tags)
├── scripts/
│   ├── generate-docs.sh       # 문서 생성 스크립트
│   ├── tag-device.sh          # API tag 부여 (OpenTofu 미관리 디바이스용 fallback)
│   └── tofu.sh                # OpenTofu 실행 wrapper (sops 자격증명 주입)
├── docs/
│   └── acl.md                 # 생성된 문서
└── .github/workflows/
    ├── tailscale-acl.yml      # ACL validation 워크플로우 (test only)
    └── acl-docs.yml           # 문서화 워크플로우
```

## CLI 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `-p, --policy FILE` | policy.hujson 경로 | `policy.hujson` |
| `-o, --output DIR` | 출력 디렉토리 | `docs` |
| `--pr-comment` | PR 코멘트용 diff 생성 | - |
| `--compare REF` | 비교할 git 참조 | `HEAD~1` |
| `-v, --verbose` | 상세 로그 출력 | - |
| `-h, --help` | 도움말 표시 | - |

## 네트워크 진단 도구

이 프로젝트는 네트워크 문제 해결을 위해 다음 MCP 서버들을 사용합니다.

### GlobalPing

전 세계 분산 프로브를 통한 네트워크 진단 도구입니다.

- **ping** - 호스트 도달 가능성 확인
- **traceroute** - 네트워크 경로 추적
- **DNS查询** - DNS 레코드 확인
- **HTTP** - HTTP 엔드포인트 테스트

```bash
# 예: arv.bun-bull.ts.net 경로 추적
# MCP: globalping traceroute
```

### Cloudflare Radar

인터넷 트래픽 및 공격 인사이트를 제공합니다.

- **트래픽 분석** - HTTP/DNS 트렌드
- **공격 탐지** - L3/L7 DDoS 공격 현황
- **BGP 정보** - 라우팅 변경사항 및 이상 징후
- **인터넷 품질** - 속도 및 품질 메트릭

```bash
# 예: ASN 정보 조회
# MCP: cloudflare-radar get_as_details
```

## 요구사항

- `jq` - JSON 처리
- `python3` + `json5` - HUJSON 파싱

```bash
# Ubuntu/Debian
sudo apt install jq python3-pip
pip install json5

# macOS
brew install jq python3
pip3 install json5
```

## 문서 형식

생성되는 문서는 다음 섹션들을 포함합니다:

- 📋 개요
- 👥 그룹 및 사용자
- 🏷️ 태그 및 소유자
- 🔐 ACL 규칙
- 🔑 SSH 규칙
- 📊 네트워크 연결 다이어그램 (Mermaid)
- 🔗 참고 링크

## 라이선스

MIT
