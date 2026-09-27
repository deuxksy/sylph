# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **참고:** `CLAUDE.md`/`GEMINI.md`는 `@./.ai/RULES.md` import, `AGENTS.md`는 링크 참조(Codex는 native import 미지원)이다.

## Project Overview

Sylph는 Tailscale ACL 정책(`policy.hujson`)을 관리·문서화하는 시스템. Tailnet: `TY1qnFMXke11CNTRL`.

## Architecture

### policy.hujson
- ACL 변경은 Tailnet 전체에 즉시 영향 → 신중하게 수정

### scripts/generate-docs.sh
- **주의:** `main()` 함수가 두 번 정의됨 (430행, 556행). 두 번째가 실제 실행됨 — `--pr-comment` 플래그 처리는 두 번째 `main()`에만 있음

### scripts/tag-device.sh
- Tailscale API(OAuth client)로 디바이스에 tag 부여
- 안드로이드/iOS 등 CLI 불가 기기 tag 적용 목적
- sops 암호화된 `.env.sops`에서 `TS_OAUTH_CLIENT_ID`/`TS_OAUTH_CLIENT_SECRET` 로드 (`TS_API_CLIENT_*`는 레거시 alias로 호환)
- 사용: `./scripts/tag-device.sh <hostname> <tag> [--replace]`
- OAuth client 발급 시 scope `Devices: Write` 필요

### opentofu/
- `tailscale_acl`: `policy.hujson`을 `file()`로 참조해 tailnet policy 관리
- `tailscale_device_tags`: 디바이스 tag 선언 관리 (전체 교체 — 선언된 resource가 tag의 유일한 owner)
- 자격증명: `.env.sops`의 `TS_OAUTH_CLIENT_ID`/`TS_OAUTH_CLIENT_SECRET` + R2용 `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`를 `scripts/tofu.sh`가 주입 (없으면 에러 종료)
- 사용: `./scripts/tofu.sh plan|apply|import ...`

### .env.sops
- JSON 형식: 전체 내용이 `data` 키 하나에 암호화됨 → `sops -d .env.sops`는 실패
- 수동 복호화: `sops -d --input-type json --output-type binary .env.sops > .env`
- `scripts/tofu.sh`, `scripts/tag-device.sh`는 dotenv → JSON 순으로 형식 자동 감지

## ACL 수정 Workflow

1. `policy.hujson` 수정
2. `./scripts/generate-docs.sh` 실행 → `docs/acl.md` 확인
3. 커밋 + PR 생성
4. GitHub Actions: ACL test(validation) + 문서 코멘트 자동 실행
5. main 병합 시 `opentofu.yml`이 `tofu apply` 자동 실행 (GitHub environment 승인 게이트 경유)
