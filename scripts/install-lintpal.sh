#!/usr/bin/env bash
set -euo pipefail

truthy() { case "${1,,}" in 1|true|yes|on) return 0;; *) return 1;; esac; }

path="${INPUT_LINTPAL_PATH:-lintpal}"
if [[ "$path" != lintpal ]]; then
  [[ -x "$path" ]] || { echo "lintpal binary is not executable: $path" >&2; exit 127; }
  echo "LINTPAL_BIN=$path" >> "$GITHUB_ENV"
  exit 0
fi
if ! truthy "${INPUT_INSTALL:-true}"; then
  command -v lintpal >/dev/null || { echo 'lintpal was not found on PATH' >&2; exit 127; }
  echo 'LINTPAL_BIN=lintpal' >> "$GITHUB_ENV"
  exit 0
fi
command -v npm >/dev/null || { echo 'npm is required to install lintpal' >&2; exit 127; }
root="${RUNNER_TEMP:-/tmp}/lintpal-action"
mkdir -p "$root"
npm install --global --prefix "$root" "lintpal@${INPUT_LINTPAL_VERSION:-0.4.0}" --omit=dev --no-audit --no-fund
bin="$root/bin/lintpal"
[[ -x "$bin" ]] || { echo "installed lintpal binary was not found: $bin" >&2; exit 127; }
"$bin" version
echo "LINTPAL_BIN=$bin" >> "$GITHUB_ENV"
