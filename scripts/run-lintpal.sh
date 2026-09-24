#!/usr/bin/env bash
set -euo pipefail

required() { [[ -n "$2" ]] || { echo "required input is empty: $1" >&2; exit 2; }; }
truthy() { case "${1,,}" in 1|true|yes|on) return 0;; *) return 1;; esac; }
append_lines() { local flag="$1" value="$2" line; while IFS= read -r line; do [[ -z "$line" ]] || lint+=("$flag" "$line"); done <<< "$value"; }

bin="${LINTPAL_BIN:-lintpal}"
command -v "$bin" >/dev/null 2>&1 || [[ -x "$bin" ]] || { echo "lintpal binary was not found: $bin" >&2; exit 127; }
required base "${INPUT_BASE:-}"; required head "${INPUT_HEAD:-}"; required report-path "${INPUT_REPORT_PATH:-}"
mkdir -p "$(dirname "$INPUT_REPORT_PATH")"

lint=("$bin" lint --base "$INPUT_BASE" --head "$INPUT_HEAD" --provider "${INPUT_PROVIDER:-jev}" --rules "${INPUT_RULES:-.lintpal/rules}" --block-on "${INPUT_BLOCK_ON:-high}" --format json --out "$INPUT_REPORT_PATH")
[[ -z "${INPUT_MODEL:-}" ]] || lint+=(--model "$INPUT_MODEL")
[[ -z "${INPUT_TIMEOUT:-}" ]] || lint+=(--timeout "$INPUT_TIMEOUT")
[[ -z "${INPUT_MAX_CONCURRENCY:-}" ]] || lint+=(--max-concurrency "$INPUT_MAX_CONCURRENCY")
[[ -z "${INPUT_BASE_URL:-}" ]] || lint+=(--base-url "$INPUT_BASE_URL")
[[ -z "${INPUT_AUTH_TOKEN_ENV:-}" ]] || lint+=(--auth-token-env "$INPUT_AUTH_TOKEN_ENV")
append_lines --include "${INPUT_INCLUDE:-}"
append_lines --exclude "${INPUT_EXCLUDE:-}"
"${lint[@]}"

feedback=("$bin" feedback github --in "$INPUT_REPORT_PATH" --base "$INPUT_BASE" --head "$INPUT_HEAD" --review-channel "${INPUT_REVIEW_CHANNEL:-lintpal}")
[[ -z "${INPUT_REPO:-}" ]] || feedback+=(--repo "$INPUT_REPO")
[[ -z "${INPUT_PR_NUMBER:-}" ]] || feedback+=(--pr-number "$INPUT_PR_NUMBER")
truthy "${INPUT_GATE:-true}" && feedback+=(--gate)
echo "report-path=$INPUT_REPORT_PATH" >> "$GITHUB_OUTPUT"
set +e
"${feedback[@]}"
status=$?
set -e
if [[ "$status" == 10 ]] && truthy "${INPUT_GATE:-true}"; then
  printf '::error::LintPal found blocking findings at or above the %s threshold.\n' "${INPUT_BLOCK_ON:-high}"
fi
exit "$status"
