# Sylph 공통 작업 지침

이 파일은 이 저장소에서 작업하는 모든 AI 코딩 도구에 적용된다.

> **참고:** `CLAUDE.md`/`GEMINI.md`는 `@./.ai/RULES.md` import, `AGENTS.md`는 링크 참조(Codex는 native import 미지원)이다.

## Project Overview

Sylph는 Tailscale ACL 정책(`opentofu/policy.hujson`)을 관리·문서화하는 시스템. Tailnet: `TY1qnFMXke11CNTRL`.

## Architecture

### opentofu/policy.hujson
- ACL을 적용하면 변경 사항이 Tailnet 전체에 영향을 준다.

### scripts/generate-docs.sh
- `main()`이 두 번 정의되며, 마지막 정의가 `--pr-comment`를 처리한다.
- `--pr-comment`의 기본 출력 경로는 `docs/.pr-comment.md`다.

### scripts/tag-device.sh
- Tailscale API(OAuth client)로 디바이스에 tag 부여
- 안드로이드/iOS 등 CLI 불가 기기 tag 적용 목적
- sops 암호화된 `.env.sops`에서 `TS_OAUTH_CLIENT_ID`/`TS_OAUTH_CLIENT_SECRET` 로드 (`TS_API_CLIENT_*`는 레거시 alias로 호환)
- 사용: `./scripts/tag-device.sh <hostname> <tag> [--replace]`
- OAuth client 발급 시 scope `Devices: Write` 필요

### opentofu/
- `tailscale_acl`: `policy.hujson`을 `file()`로 참조해 tailnet policy 관리
- `tailscale_device_tags`: 디바이스 tag 선언 관리 (전체 교체 — 선언된 resource가 tag의 유일한 owner)
- `scripts/tofu.sh`는 `.env`를 우선 사용하고, 없으면 `.env.sops`를 복호화한다.
- `scripts/tofu.sh`는 OAuth와 R2 자격 증명을 주입하며, R2 자격 증명이 비어 있으면 종료한다.
- GitHub Actions의 Plan과 Apply는 `TS_OAUTH_CLIENT_ID`와 `TS_OAUTH_CLIENT_SECRET` 시크릿을 사용한다.
- 사용: `./scripts/tofu.sh plan|apply|import ...`

### .env.sops
- JSON 형식: 전체 내용이 `data` 키 하나에 암호화됨 → `sops -d .env.sops`는 실패
- 수동 복호화: `sops -d --input-type json --output-type binary .env.sops > .env`
- `scripts/tofu.sh`, `scripts/tag-device.sh`는 dotenv → JSON 순으로 형식 자동 감지

## ACL 수정 Workflow

1. `opentofu/policy.hujson` 수정
2. `./scripts/generate-docs.sh` 실행 → `docs/acl.md` 확인
3. 커밋 + PR 생성
4. 정책 변경 PR에서 OpenTofu Plan과 ACL 문서 댓글이 실행된다.
5. 대상 경로가 변경된 `main` 푸시에서 Plan이 성공하면 `opentofu.yml`이 `production` 환경에서 Apply를 실행한다.
