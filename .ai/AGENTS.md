# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **참고:** `CLAUDE.md`는 `.ai/AGENTS.md`의 심볼릭 링크이다.

## Project Overview

Sylph는 Tailscale ACL 정책(`policy.hujson`)을 관리·문서화하는 시스템. Tailnet: `TY1qnFMXke11CNTRL`.

## Key Commands

```bash
# ACL 문서 생성 (docs/acl.md)
./scripts/generate-docs.sh

# PR 코멘트 diff 포함
./scripts/generate-docs.sh --pr-comment

# diff 비교 기준 변경
./scripts/generate-docs.sh --pr-comment --compare HEAD~3

# 상세 로그
./scripts/generate-docs.sh -v
```

Dependencies: `jq`, `python3` + `json5` (`pip install json5`)

## Architecture

### policy.hujson
- HUJSON 형식 (주석 `//`, 후행 콤마 허용)
- Sections: `groups` → `tagOwners` → `nodeAttrs` → `acls` → `ssh`
- `nodeAttrs`: funnel 포트 제한(443만), tag:server/pc 파일 공유 허용
- ACL 변경은 Tailnet 전체에 즉시 영향 → 신중하게 수정
- Tags: `https`, `docker`, `k8s`, `k8s-operator`, `heritage`, `mobile`, `server`, `network`, `pc`, `ai`, `kyolim`

### 산출물
- `docs/acl.md` — ACL 정책 문서 (자동 생성)
- `docs/network-diagram.md` — 네트워크 다이어그램
- `.pr-comment.md` — PR 변경사항 요약 (`--pr-comment` 시)

### scripts/generate-docs.sh
- HUJSON → JSON 변환: Python `json5`로 주석 제거 + `json5.loads()` 파싱 후 `jq`로 각 섹션 추출
- Markdown 생성: groups/tags/acls/ssh 테이블 + Mermaid 다이어그램
- PR 코멘트: `--pr-comment` 시 `.pr-comment.md`에 diff 요약 생성
- **주의:** `main()` 함수가 두 번 정의됨 (430행, 556행). 두 번째가 실제 실행됨 — `--pr-comment` 플래그 처리는 두 번째 `main()`에만 있음

### GitHub Actions (2개 워크플로우)
- **tailscale-acl.yml**: PR에서 ACL test → main push 시 ACL apply (`tailscale/gitops-acl-action@v1`)
- **acl-docs.yml**: PR에서 문서 생성 후 PR 코멘트로 결과 게시
- Secrets: `TS_API_CLIENT_ID`, `TS_API_CLIENT_SECRET` 필요

### MCP Servers (.mcp.json.example)
Cloudflare(다중 서비스: docs/bindings/builds/observability/radar 등), GlobalPing, Serena 설정 예시 포함.

## ACL 수정 Workflow

1. `policy.hujson` 수정
2. `./scripts/generate-docs.sh` 실행 → `docs/acl.md` 확인
3. 커밋 + PR 생성
4. GitHub Actions: ACL test + 문서 코멘트 자동 실행
5. main 병합 시에만 실제 Tailscale에 apply
