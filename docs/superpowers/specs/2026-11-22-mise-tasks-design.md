# mise tasks 진입점 도입 설계

- 날짜: 2026-11-22
- 상태: 승인 (대화 기반)
- 범위: 소규모 변경 (v2 첫 조각, ROADMAP Phase 1 선두 시험)

## 의도

기존 `scripts/*.sh` 구현은 그대로 두고 `mise.toml [tasks]`를 선언적 진입점으로 얹는다.
목적: 모든 AI agent(Claude Code·Codex·agy)가 `mise tasks ls`로 실행 가능한 작업을
자가발견하고, 문서 해석 없이 동일한 진입점을 사용하게 한다.

## 목표 / 비목표

- 목표: 스크립트 5개의 mise 태스크 랩, agent 발견 경로 단일화
- 비목표: 스크립트 본체 수정, Python 도구체인 도입(3.14 고정·pytest는 Phase 1 정식 착수 때)

## 접근 방식 (비교한 대안)

1. **하이브리드: mise 진입점 + sh 구현 (선택)** — 로직은 sh에 남아 디버깅 가능성 유지,
   진입점만 선언적 메타데이터로. 도구 추가 0 (mise는 이미 전 agent 공용)
2. sh 직접 실행 유지 — 도구는 0이지만 발견성이 문서(RULES.md)에 의존하고 agent별 해석·stale 리스크
3. poethepoet — Python 표준이지만 `pyproject.toml` 신규 골격 필요. Phase 1에서
   Python 의존 관리 시작 시점 재평가

## 설계

```toml
[tasks.docs]
run = "./scripts/generate-docs.sh"
desc = "ACL 문서 재생성"
sources = ["opentofu/policy.hujson", "scripts/generate-docs.sh"]
outputs = ["docs/okf/reference/acl.md"]

[tasks.tofu]
run = "./scripts/tofu.sh"
desc = "OpenTofu 래퍼 — mise run tofu plan"

[tasks.tag-device]
run = "./scripts/tag-device.sh"
desc = "디바이스 태그 부여 — mise run tag-device <hostname> <tag>"

[tasks.apply-aperture]
run = "./scripts/apply-aperture.sh"
desc = "Aperture 설정 live 반영 — 주의: 실행 즉시 서비스 변경"

[tasks.sync-config]
run = "./scripts/sync-config.sh"
desc = "live 설정 → 로컬 스냅샷 동기화 (config.json·devices.json)"
```

스크립트 5개 실동작 확인(2026-11-22): `generate-docs.sh` CI 활성 사용·본문 멱등(헤더
생성일·커밋만 갱신), `tofu.sh`·`tag-device.sh` RULES.md 문서화·usage 정상,
`sync-config.sh` --help 정상·최근 관리(2026-11-22), `apply-aperture.sh` 문법 검증만
(live PUT 부작용으로 실행 제외).

- 인자 전달: 태스크명 뒤 인자가 스크립트로 그대로 전달됨 (`mise run tofu plan`,
  `mise run docs -- --pr-comment`)
- `.ai/RULES.md` 스크립트 설명에 mise 진입점 한 줄 추가
- `ROADMAP.md` Phase 1 갱신: 태스크 러너 = mise tasks 확정, poethepoet 재평가 조건 명시

## 내 판단 (거부 가능)

- Python 3.14 고정 제외: sh 태스크는 Python 불필요. mise 자체 3.14 다운로드 부수효과가
  있어 Phase 1 정식 착수 때 함께 적용

## 검증

1. `mise tasks ls` — 태스크 5개 노출 확인
2. `mise run docs` — 실행 후 본문 diff 없음(헤더 생성일·커밋 hash만 갱신)
3. `mise run tofu` — 무인자 시 usage 출력이 직접 실행과 일치

## 빌더에게 남기는 것

없음 — 위 설계 그대로 구현 가능
