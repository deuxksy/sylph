# Tailscale ACL 문서화 자동화 설계

**생성일:** 2026-03-07
**상태:** 승인됨

## 개요

Tailscale ACL 정책(`policy.hujson`)을 자동으로 문서화하여 팀원 간 쉽게 공유할 수 있는 시스템을 구축합니다.

### 목표

- 팀원이 현재 ACL 정책을 쉽게 이해할 수 있도록 함
- 수동 명령어로 필요할 때만 문서 생성
- GitHub PR 시 변경사항을 자동으로 코멘트로 표시

### 포함 기능

1. 📄 Markdown 문서 생성 (`docs/acl.md`)
2. 📊 Mermaid 다이어그램 (전체 정책 시각화)
3. 💬 PR 자동 코멘트 (변경 요약 + 비교 + 영향도 + 보안 경고)
4. 🌐 GitHub Pages 지원 (GitHub Markdown 자동 렌더링)

---

## 아키텍처

### 파일 구조

```
tailscale-acl/
├── policy.hujson              # 기존 ACL 정책 파일
├── .github/
│   └── workflows/
│       ├── tailscale-acl.yml  # 기존 ACL 적용 워크플로우
│       └── acl-docs.yml       # 새로운 문서화 워크플로우
├── scripts/
│   └── generate-docs.sh       # 메인 문서화 스크립트
├── docs/
│   └── acl.md                 # 생성된 문서 (git 커밋)
└── README.md                  # 사용법 안내
```

### 데이터 흐름

```
1. 스크립트 실행
   │
   ▼
2. policy.hujson 검증 (jq JSON 유효성, 필수 필드 확인)
   │
   ▼
3. jq로 데이터 추출 (groups, tagOwners, acls, ssh)
   │
   ▼
4. 데이터 변환 및 정규화 (와일드카드 전개, autogroup 변환)
   │
   ▼
5. 문서 생성 (Markdown + 테이블 + Mermaid 다이어그램)
   │
   ▼
6. 파일 출력 (docs/acl.md, .pr-comment.md)
```

---

## 컴포넌트

### 1. ACL 파서 (`parse_acl` 함수)

- `policy.hujson`을 읽고 jq로 파싱
- JSON 형태의 구조화된 데이터 반환

### 2. Markdown 생성기 (`generate_markdown` 함수)

- 파싱된 데이터를 Markdown 형식으로 변환
- 섹션: 개요, 그룹, 태그, ACL 규칙 표, SSH 규칙, 다이어그램

### 3. 다이어그램 생성기 (`generate_diagram` 함수)

- Mermaid flowchart/graph 생성
- 노드: 태그, 그룹, 사용자
- 엣지: ACL 연결, SSH 연결, 태그 소유권
- 연결 유형별 색상 구분

### 4. PR 코멘트 생성기 (`generate_pr_comment` 함수)

- git diff로 이전/현재 policy.hujson 비교
- 변경 요약, 전후 비교, 영향도, 보안 경고 출력

### 5. 메인 루프

- 인자 파싱 (-p, -o, --pr-comment)
- 함수 호출 순서 orchestration
- 파일 출력 및 로깅

---

## CLI 인터페이스

```bash
./scripts/generate-docs.sh [OPTIONS]

Options:
  -p, --policy FILE    policy.hujson 경로 (기본값: ../policy.hujson)
  -o, --output DIR     출력 디렉토리 (기본값: ../docs)
  --pr-comment         PR 코멘트용 diff도 생성 (.pr-comment.md)
  --compare REF        비교할 git 참조 (기본값: HEAD~1)
  -h, --help           도움말 표시
  -v, --verbose        상세 로그 출력
```

---

## GitHub Action

```yaml
name: ACL Documentation

on:
  pull_request:
    paths:
      - 'policy.hujson'
  workflow_dispatch:

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Generate docs
        run: |
          chmod +x scripts/generate-docs.sh
          ./scripts/generate-docs.sh --pr-comment

      - name: PR Comment
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const comment = fs.readFileSync('.pr-comment.md', 'utf8');
            github.rest.issues.createComment({
              ...context.issue,
              body: comment
            });
```

---

## 문서 포맷

### docs/acl.md 구조

1. 헤더 (생성일, 커밋 정보)
2. 개요
3. 그룹 및 사용자 테이블
4. 태그 및 소유자 테이블
5. ACL 규칙 테이블
6. SSH 규칙 테이블
7. Mermaid 네트워크 연결 다이어그램
8. 참고 링크

### PR 코멘트 구조

1. 변경사항 요약
2. 추가/수정/삭제된 항목
3. 변경 전후 비교 (diff)
4. 영향받는 리소스
5. 보안 경고

---

## 에러 핸들링

- 파일 존재 확인
- jq 설치 확인
- JSON 형식 검증
- 필수 필드 검증 (groups, acls, tagOwners, ssh)
- 출력 디렉토리 생성 및 쓰기 권한 확인

---

## 기술 스택

- **언어:** Bash
- **파서:** jq
- **다이어그램:** Mermaid
- **CI/CD:** GitHub Actions

---

## 다음 단계

이 디자인 문서가 승인된 후 `writing-plans` 스킬을 사용하여 상세 구현 계획을 작성합니다.
