#!/usr/bin/env bash
# Lightweight maintainer check: bash -n on scripts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
while IFS= read -r -d '' f; do
  if ! bash -n "$f"; then
    echo "syntax error: $f" >&2
    fail=1
  else
    echo "ok  $f"
  fi
done < <(find "${ROOT}/bin" "${ROOT}/bootstrap" "${ROOT}/scripts" -type f -print0 2>/dev/null)

exit "${fail}"
