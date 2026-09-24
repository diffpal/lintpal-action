#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/work/.lintpal/rules"
cat > "$tmp/bin/lintpal" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\0' "$@" >> "$CALLS"
printf '\n' >> "$CALLS"
if [[ "$1 $2" == 'feedback github' ]]; then exit "${FEEDBACK_STATUS:-0}"; fi
report=''; while [[ $# -gt 0 ]]; do [[ "$1" == --out ]] && { report="$2"; break; }; shift; done
[[ -z "$report" ]] || printf '{"version":"v5"}\n' > "$report"
exit "${LINT_STATUS:-0}"
SCRIPT
chmod +x "$tmp/bin/lintpal"

cat > "$tmp/bin/npm" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$NPM_ARGS"
prefix=''; while [[ $# -gt 0 ]]; do [[ "$1" == --prefix ]] && { prefix="$2"; shift 2; continue; }; shift; done
mkdir -p "$prefix/bin"; printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/bin/lintpal"; chmod +x "$prefix/bin/lintpal"
SCRIPT
chmod +x "$tmp/bin/npm"
PATH="$tmp/bin:$PATH" RUNNER_TEMP="$tmp/install" GITHUB_ENV="$tmp/env" NPM_ARGS="$tmp/npm-args" \
  INPUT_INSTALL=true INPUT_LINTPAL_VERSION=0.4.1 INPUT_LINTPAL_PATH=lintpal "$root/scripts/install-lintpal.sh"
grep -Fx 'lintpal@0.4.1' "$tmp/npm-args"
grep -Fq 'LINTPAL_BIN=' "$tmp/env"

run() {
  : > "$tmp/calls"; : > "$tmp/output"
  (cd "$tmp/work" && CALLS="$tmp/calls" GITHUB_OUTPUT="$tmp/output" LINTPAL_BIN="$tmp/bin/lintpal" \
    INPUT_BASE='base sha' INPUT_HEAD='head sha' INPUT_PROVIDER=jev INPUT_RULES=.lintpal/rules \
    INPUT_BLOCK_ON=high INPUT_GATE=true INPUT_REPORT_PATH="$tmp/work/out/report.json" \
    INPUT_REVIEW_CHANNEL=lintpal INPUT_REPO=owner/repo INPUT_PR_NUMBER=7 \
    INPUT_INCLUDE=$'*.go\ncmd/**' INPUT_EXCLUDE=$'vendor/**' "$root/scripts/run-lintpal.sh")
}
run
python3 - "$tmp/calls" <<'PY'
import sys
calls=[x.split('\0')[:-1] for x in open(sys.argv[1]).read().splitlines()]
assert len(calls)==2, calls
assert calls[0][:2]==['lint','--base'] and calls[0][2]=='base sha', calls
assert '--block-on' in calls[0] and '--include' in calls[0] and '--exclude' in calls[0], calls
assert calls[1][:2]==['feedback','github'] and '--gate' in calls[1], calls
PY
grep -Fx "report-path=$tmp/work/out/report.json" "$tmp/output"

set +e
(cd "$tmp/work" && CALLS="$tmp/calls" GITHUB_OUTPUT="$tmp/output" LINTPAL_BIN="$tmp/bin/lintpal" \
  LINT_STATUS=4 INPUT_BASE=base INPUT_HEAD=head INPUT_REPORT_PATH="$tmp/work/out/report.json" "$root/scripts/run-lintpal.sh")
status=$?
set -e
[[ "$status" == 4 ]]

set +e
log="$tmp/gate.log"
(cd "$tmp/work" && CALLS="$tmp/calls" GITHUB_OUTPUT="$tmp/output" LINTPAL_BIN="$tmp/bin/lintpal" \
  FEEDBACK_STATUS=10 INPUT_BASE=base INPUT_HEAD=head INPUT_REPORT_PATH="$tmp/work/out/report.json" INPUT_GATE=true "$root/scripts/run-lintpal.sh") >"$log" 2>&1
status=$?
set -e
[[ "$status" == 10 ]]
grep -Fq '::error::LintPal found blocking findings' "$log"

set +e
(cd "$tmp/work" && CALLS="$tmp/calls" GITHUB_OUTPUT="$tmp/output" LINTPAL_BIN="$tmp/bin/lintpal" \
  FEEDBACK_STATUS=4 INPUT_BASE=base INPUT_HEAD=head INPUT_REPORT_PATH="$tmp/work/out/report.json" "$root/scripts/run-lintpal.sh")
status=$?
set -e
[[ "$status" == 4 ]]

echo 'lintpal action smoke tests passed'
