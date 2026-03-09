# Sylph 프로젝트

Sylph는 Tailscale ACL 정책을 관리하고 문서화하며 Cloudflare 도메인을 통합 관리하는 시스템입니다.

## 프로젝트 구조

```
sylph/
├── policy.hujson          # Tailscale ACL 정책 파일 (HUJSON 형식)
├── scripts/
│   └── generate-docs.sh   # ACL 문서 자동 생성 스크립트
├── .github/
│   └── workflows/
│       └── sylph.yml          # GitHub Actions 워크플로우
└── docs/
    └── plans/             # 프로젝트 계획 문서
```

## 주요 파일

### policy.hujson
- Tailscale ACL 정책을 정의하는 HUJSON 파일
- 주석 포함 JSON 형식 (HUJSON: JSON with comments and trailing commas)
- 그룹, 태그 소유자, ACL 규칙, SSH 규칙을 포함

### scripts/generate-docs.sh
- policy.hujson에서 Markdown 문서를 자동 생성
- PR 주석 diff 생성 가능
- 의존성: jq, json5 (Python 패키지)

### .github/workflows/sylph.yml
- policy.hujson 변경 시 자동으로 ACL 테스트 및 적용
- PR 단계: 문법 및 정책 테스트만 수행
- main 브랜치 병합 시: 실제 Tailscale에 ACL 적용

## 작업 가이드

### ACL 수정
1. `policy.hujson` 파일 수정
2. `./scripts/generate-docs.sh` 실행으로 문서 생성
3. 커밋 후 PR 생성
4. GitHub Actions가 자동으로 검증

### 문서 생성
```bash
./scripts/generate-docs.sh                    # 기본 문서 생성
./scripts/generate-docs.sh --pr-comment        # PR 주석 포함
./scripts/generate-docs.sh -v                  # 상세 출력
```

## 개발 참고사항

- policy.hujson는 HUJSON 형식이므로 주석(`//`)과 후행 콤마 사용 가능
- ACL 변경 시 Tailscale 네트워크에 직접 영향을 주므로 신중해야 함
- GitHub Actions를 통해서만 main 브랜치에서 적용됨
