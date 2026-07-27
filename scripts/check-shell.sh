#!/usr/bin/env bash
# Lightweight maintainer check: bash -n on shell scripts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local f="$1"
  if ! bash -n "$f"; then
    echo "syntax error: $f" >&2
    fail=1
  else
    echo "ok  $f"
  fi
}

while IFS= read -r -d '' f; do
  # Skip non-shell files
  case "$f" in
    *.py|*.pyc|*.md|*.json|*.yml|*.yaml) continue ;;
  esac
  if head -1 "$f" | grep -qE '^#!.*(bash|sh)'; then
    check "$f"
  elif [[ "$f" == */bin/* ]]; then
    check "$f"
  fi
done < <(find "${ROOT}/bin" "${ROOT}/bootstrap" "${ROOT}/scripts" -type f -print0 2>/dev/null)

# Explicitly skip __pycache__
exit "${fail}"
