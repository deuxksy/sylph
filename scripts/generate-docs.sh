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
