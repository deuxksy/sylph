# Tailscale 네트워크 다이어그램

생성일: 2026-03-09

## 네트워크 topology

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

## 태그별 디바이스 분류

| 태그 | 디바이스 | 수량 |
|------|----------|------|
| `tag:mobile` | 13-mini, pro, z-5 | 3대 |
| `tag:pc` | eve, Surface | 2대 |
| `tag:server` | girl, walle | 2대 |
| `tag:docker` | heritage | 1대 |
| `tag:https` | arv | 1대 |
| `tag:network` | arv | 1대 |

## 네트워크 기능

### 🔐 Private Mesh VPN
- 모든 디바이스 간 P2P 연결
- 전체 암호화 통신

### 🌐 Exit Node
- **walle**: 인터넷 트래픽 라우팅 가능

### 🌐 Subnet Router
- **arv**: 192.168.1.0/24, 192.168.8.0/24 네트워크 노출

### 🔌 Tailscale Funnel
- **arv** (tag:https): 443 포트 공개

### 📁 파일 공유 (Taildrop)
- **tag:server**, **tag:pc**: 파일 수신 가능

