# Aperture Configuration

Aperture(`http://ai`) LLM Gateway 설정.

## 구조

```
aperture/
└── config.json    # Aperture 전체 설정 (providers, grants, hooks)
```

## MCP Server Proxying

Aperture MCP 프록시는 `mcp.servers`에 `url`만 지정 가능하여 **Authorization 헤더 전달 불가**.

테스트 결과 (2026-05-22):

| MCP 서버 | 응답 | 결과 |
| :--- | :--- | :--- |
| Figma (`mcp.figma.com`) | `Unauthorized` | 인증 필요 → 사용 불가 |
| Notion (`mcp.notion.com`) | `invalid_token` | OAuth 토큰 필요 → 사용 불가 |

### Aperture MCP 프록시 유효 사용처

- 인증 없는 자체 구축 HTTP MCP 서버 (tailnet 내부)
- 공개 MCP 서버

### 불가능한 유형

| 유형 | 예시 | 사유 |
| :--- | :--- | :--- |
| OAuth 클라우드 MCP | Figma, Notion | Aperture가 인증 헤더 전달 불가 |
| Bearer 토큰 MCP | GitHub, Z.AI | 동일 |
| stdio MCP | context7, github | mcp-proxy 사이드카 필요 |
| 로컬 리소스 MCP | serena, filesystem | 로컬 파일 접근 필요 |

## 참고

- [Aperture MCP Server Proxying](https://tailscale.com/docs/aperture/mcp-server) (Alpha)
- [Aperture Configuration Reference](https://tailscale.com/docs/aperture/configuration)
- API keys는 `keyid:` 참조 방식 → 실제 시크릿은 Aperture 내부 키스토어에 저장
- API PUT은 키스토어 참조 끊김 위험 → 대시보드 UI로 변경 권장
