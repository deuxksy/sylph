#!/bin/bash
# Tailscale ACL Documentation Generator
# Auto-generates documentation from policy.hujson

set -euo pipefail

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Generate documentation from Tailscale ACL policy.hujson

Options:
  -p, --policy FILE     Path to policy.hujson (default: ../policy.hujson)
  -o, --output DIR      Output directory (default: ../docs)
  --pr-comment          Generate PR comment diff (.pr-comment.md)
  --compare REF         Git ref to compare (default: HEAD~1)
  -h, --help            Show this help message
  -v, --verbose         Enable verbose output

Examples:
  $(basename "$0")                          # Basic usage
  $(basename "$0") --pr-comment             # With PR comment
  $(basename "$0") -p custom/acl.json       # Custom policy file
HELP
}

# Default values
POLICY_FILE="policy.hujson"
OUTPUT_DIR="docs"
PR_COMMENT=false
COMPARE_REF="HEAD~1"
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--policy)
            POLICY_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --pr-comment)
            PR_COMMENT=true
            shift
            ;;
        --compare)
            COMPARE_REF="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

log_info() {
    echo "ℹ️  $*"
}

log_error() {
    echo "❌ $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 $*"
    fi
}

# Convert HUJSON to JSON using json5
hujson_to_json() {
    local hujson_file="$1"
    python3 -c "
import sys
import json5
import json

# Read file and parse as JSON5 (which allows trailing commas)
with open('$hujson_file') as f:
    content = f.read()

# Remove // comments first
lines = []
for line in content.split('\n'):
    comment_idx = line.find('//')
    if comment_idx != -1:
        line = line[:comment_idx]
    lines.append(line)

content = '\n'.join(lines)
data = json5.loads(content)
# Use json.dumps for standard JSON output
print(json.dumps(data, indent=2))
"
}

check_dependencies() {
    log_verbose "Checking dependencies..."

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Install with: sudo apt install jq"
        exit 1
    fi

    log_verbose "✓ jq is installed: $(jq --version)"

    # Check json5 Python package
    if ! python3 -c "import json5" 2>/dev/null; then
        log_error "json5 Python package is not installed. Install with: pip install json5"
        exit 1
    fi

    log_verbose "✓ json5 Python package is available"
}

check_policy_file() {
    log_verbose "Checking policy file: $POLICY_FILE"

    if [[ ! -f "$POLICY_FILE" ]]; then
        log_error "Policy file not found: $POLICY_FILE"
        exit 1
    fi

    log_verbose "✓ Policy file exists"
}

validate_json() {
    log_verbose "Validating JSON format..."

    if ! hujson_to_json "$POLICY_FILE" | jq '.' > /dev/null 2>&1; then
        log_error "Invalid JSON format in $POLICY_FILE"
        exit 1
    fi

    log_verbose "✓ JSON is valid"
}

validate_required_fields() {
    log_verbose "Checking required fields..."

    local required_fields=("groups" "acls" "tagOwners" "ssh")
    local missing_fields=()

    for field in "${required_fields[@]}"; do
        if ! hujson_to_json "$POLICY_FILE" | jq -e ".$field" > /dev/null 2>&1; then
            missing_fields+=("$field")
        fi
    done

    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        log_error "Missing required fields: ${missing_fields[*]}"
        exit 1
    fi

    log_verbose "✓ All required fields present: ${required_fields[*]}"
}

check_output_dir() {
    log_verbose "Checking output directory: $OUTPUT_DIR"

    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_verbose "Creating output directory..."
        mkdir -p "$OUTPUT_DIR" || {
            log_error "Cannot create output directory: $OUTPUT_DIR"
            exit 1
        }
    fi

    if [[ ! -w "$OUTPUT_DIR" ]]; then
        log_error "No write permission for: $OUTPUT_DIR"
        exit 1
    fi

    log_verbose "✓ Output directory ready"
}

validate_all() {
    log_info "Validating inputs..."
    check_dependencies
    check_policy_file
    validate_json
    validate_required_fields
    check_output_dir
    log_info "✓ All validations passed"
}

# Parser functions
parse_groups() {
    log_verbose "Parsing groups..."

    hujson_to_json "$POLICY_FILE" | jq -r '.groups | to_entries[] |
        "\(.key)|\(.value | join(", "))"'
}

parse_tag_owners() {
    log_verbose "Parsing tag owners..."

    hujson_to_json "$POLICY_FILE" | jq -r '.tagOwners | to_entries[] |
        "\(.key)|\(.value | join(", "))"'
}

parse_acls() {
    log_verbose "Parsing ACL rules..."

    hujson_to_json "$POLICY_FILE" | jq -r '.acls[] |
        "\(.src | join(", "))|\(.dst | join(", "))|\(.action)"'
}

parse_ssh() {
    log_verbose "Parsing SSH rules..."

    hujson_to_json "$POLICY_FILE" | jq -r '.ssh[] |
        "\(.action)|\(.src | join(", "))|\(.dst | join(", "))|\(.users | join(", "))"'
}

# Markdown generation functions
get_metadata() {
    local commit_hash
    local commit_date
    local author

    if git rev-parse --git-dir > /dev/null 2>&1; then
        commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        commit_date=$(git log -1 --format="%ci" 2>/dev/null || echo "unknown")
        author=$(git log -1 --format="%an" 2>/dev/null || echo "unknown")
    else
        commit_hash="unknown"
        commit_date=$(date +%Y-%m-%d)
        author="unknown"
    fi

    echo "$commit_hash|$commit_date|$author"
}

generate_header() {
    local metadata
    local commit_hash
    local commit_date
    local author

    metadata=$(get_metadata)
    IFS='|' read -r commit_hash commit_date author <<< "$metadata"

    cat << HEADER
# Tailscale ACL 문서

> 자동 생성일: $commit_date
> 커밋: \`$commit_hash\` ($author)

---

## 📋 개요

이 문서는 Tailscale ACL 정책(\`policy.hujson\`)을 기반으로 자동 생성되었습니다.

HEADER
}

generate_groups_section() {
    local output="## 👥 그룹 및 사용자\n\n"
    output+="| 그룹 | 사용자 |\n"
    output+="|------|--------|\n"

    while IFS='|' read -r group members; do
        output+="| \`$group\` | $members |\n"
    done < <(parse_groups)

    echo -e "$output"
}

generate_tags_section() {
    local output="## 🏷️ 태그 및 소유자\n\n"
    output+="| 태그 | 소유자 |\n"
    output+="|------|--------|\n"

    while IFS='|' read -r tag owners; do
        output+="| \`$tag\` | $owners |\n"
    done < <(parse_tag_owners)

    echo -e "$output"
}

generate_acls_section() {
    local output="## 🔐 ACL 규칙\n\n"
    output+="| 소스 | 대상 | 액션 |\n"
    output+="|------|------|------|\n"

    while IFS='|' read -r src dst action; do
        # 포트 정보 추출 (dst:port 형식)
        local dst_display="$dst"
        if [[ "$dst" =~ \*:[0-9]+ ]]; then
            dst_display="모든 포트"
        elif [[ "$dst" =~ : ]]; then
            dst_display="\`$dst\`"
        else
            dst_display="\`$dst\`"
        fi

        output+="| \`$src\` | $dst_display | $action |\n"
    done < <(parse_acls)

    echo -e "$output"
}

generate_ssh_section() {
    local output="## 🔑 SSH 규칙\n\n"
    output+="| 액션 | 소스 | 대상 | 허용 사용자 |\n"
    output+="|------|------|------|-------------|\n"

    while IFS='|' read -r action src dst users; do
        output+="| $action | \`$src\` | \`$dst\` | \`$users\` |\n"
    done < <(parse_ssh)

    echo -e "$output"
}

generate_diagram() {
    cat << 'DIAGRAM'
## 📊 네트워크 연결 다이어그램

```mermaid
graph TB
    subgraph "그룹"
DIAGRAM

    # 그룹 노드
    while IFS='|' read -r group members; do
        local node_id="${group//group:/G-}"
        echo "        $node_id[\"$group\"]"
    done < <(parse_groups)

    cat << 'DIAGRAM2'
    end

    subgraph "태그"
DIAGRAM2

    # 태그 노드
    hujson_to_json "$POLICY_FILE" | jq -r '.tagOwners | keys[]' | while read -r tag; do
        local node_id="${tag//tag:/T-}"
        echo "        $node_id[\"$tag\"]"
    done

    cat << 'DIAGRAM3'
    end

DIAGRAM3

    # 소유권 연결
    hujson_to_json "$POLICY_FILE" | jq -r '.tagOwners | to_entries[] | "\(.key)|\(.value[])"' | while IFS='|' read -r tag owner; do
        local tag_id="${tag//tag:/T-}"
        if [[ "$owner" == group:* ]]; then
            local owner_id="${owner//group:/G-}"
            echo "    $owner_id -->|소유| $tag_id"
        else
            echo "    auto-$owner[\"$owner\"] -->|소유| $tag_id"
        fi
    done

    cat << 'STYLE'

    classDef groupStyle fill:#e1f5fe,stroke:#01579b
    classDef tagStyle fill:#f3e5f5,stroke:#4a148c

STYLE

    # 클래스 적용
    local groups=$(parse_groups | cut -d'|' -f1 | sed 's/group:/G-/g' | tr '\n' ' ')
    local tags=$(hujson_to_json "$POLICY_FILE" | jq -r '.tagOwners | keys[]' | sed 's/tag:/T-/g' | tr '\n' ' ')
    echo "    class $groups groupStyle"
    echo "    class $tags tagStyle"

    cat << 'END'
```
END
}

generate_footer() {
    cat << 'FOOTER'

---

## 🔗 참고

- [Tailscale ACL 문서](https://tailscale.com/kb/1018/acls/)
- [SSH 설명서](https://tailscale.com/kb/1193/tailscale-ssh/)
- [policy.hujson](../policy.hujson)

---
*이 문서는 \`scripts/generate-docs.sh\`에 의해 자동 생성되었습니다.*
FOOTER
}

generate_document() {
    log_info "Generating documentation..."

    {
        generate_header
        echo ""
        generate_groups_section
        echo ""
        generate_tags_section
        echo ""
        generate_acls_section
        echo ""
        generate_ssh_section
        echo ""
        generate_diagram
        echo ""
        generate_footer
    } > "$OUTPUT_DIR/acl.md"

    log_info "✓ Documentation generated: $OUTPUT_DIR/acl.md"
}

main() {
    validate_all
    generate_document

    if [[ "$VERBOSE" == "true" ]]; then
        cat "$OUTPUT_DIR/acl.md"
    fi
}

# PR Comment generation
compare_policies() {
    local old_file
    local new_file

    # git 이력이 있는 경우 이전 버전 가져오기
    if git rev-parse --git-dir > /dev/null 2>&1; then
        old_file=$(git show "$COMPARE_REF:policy.hujson" 2>/dev/null || echo "")
        new_file=$(cat "$POLICY_FILE")

        if [[ -z "$old_file" ]]; then
            echo "NEW|파일이 새로 생성되었습니다"
            return
        fi

        # 임시 파일로 비교
        local old_tmp=$(mktemp)
        local new_tmp=$(mktemp)

        echo "$old_file" > "$old_tmp"
        echo "$new_file" > "$new_tmp"

        # diff 분석
        local diff_output=$(diff -u "$old_tmp" "$new_tmp" || true)

        rm -f "$old_tmp" "$new_tmp"

        # 변경사항 파싱
        analyze_diff "$diff_output"
    else
        echo "NOGIT|git 이력이 없습니다"
    fi
}

analyze_diff() {
    local diff="$1"
    local added=0
    local modified=0
    local deleted=0

    # 간단한 변경 감지
    if echo "$diff" | grep -q "^+.*\"groups\""; then
        ((modified++))
    fi
    if echo "$diff" | grep -q "^+.*\"acls\""; then
        ((modified++))
    fi
    if echo "$diff" | grep -q "^+.*\"tagOwners\""; then
        ((modified++))
    fi
    if echo "$diff" | grep -q "^+.*\"ssh\""; then
        ((modified++))
    fi

    # 추가된 라인 수
    local added_lines=$(echo "$diff" | grep -c "^+" || true)
    # 삭제된 라인 수
    local deleted_lines=$(echo "$diff" | grep -c "^-" || true)

    echo "CHANGES|$modified|+$added_lines|-$deleted_lines"
}

generate_pr_comment() {
    log_info "Generating PR comment..."

    local metadata
    local commit_hash
    local commit_date

    metadata=$(get_metadata)
    IFS='|' read -r commit_hash commit_date _ <<< "$metadata"

    cat > ".pr-comment.md" << PR_COMMENT
## 📋 ACL 변경사항 요약

**커밋:** \`$commit_hash\`
**변경일:** $commit_date

---

### 📊 변경 분석

PR_COMMENT

    # 변경사항 분석 추가
    local comparison=$(compare_policies)
    IFS='|' read -r change_type rest <<< "$comparison"

    case "$change_type" in
        "NEW")
            echo "**상태:** 🆕 새로운 ACL 정책 파일" >> ".pr-comment.md"
            ;;
        "NOGIT")
            echo "**상태:** ⚠️ Git 이력 없음 (변경 추적 불가)" >> ".pr-comment.md"
            ;;
        "CHANGES")
            IFS='|' read -r _ modified added deleted <<< "$comparison"
            echo "**상태:** 📝 ACL 정책 수정" >> ".pr-comment.md"
            echo "" >> ".pr-comment.md"
            echo "변경된 섹션: $modified개" >> ".pr-comment.md"
            echo "라인 변경: $added / $deleted" >> ".pr-comment.md"
            ;;
    esac

    cat >> ".pr-comment.md" << 'PR_COMMENT_END'

---

### 📄 전체 문서 보기

생성된 문서는 `docs/acl.md`에서 확인할 수 있습니다.

PR_COMMENT_END

    log_info "✓ PR comment generated: .pr-comment.md"
}

main() {
    validate_all
    generate_document

    if [[ "$PR_COMMENT" == "true" ]]; then
        generate_pr_comment
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        cat "$OUTPUT_DIR/acl.md"
        if [[ "$PR_COMMENT" == "true" ]]; then
            cat ".pr-comment.md"
        fi
    fi
}

# 메인 함수 호출
main "$@"
