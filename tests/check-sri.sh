#!/bin/bash
#
# Checks that every library pinned in preview.js still matches its Subresource
# Integrity hash on jsDelivr. A mismatch would stop that library from loading,
# so CI runs this weekly as well as on every change.

set -eu -o pipefail

here=$(cd -P -- "$(dirname -- "$0")" && pwd)
js="$here/../src/_markdown-preview/preview.js"

# Prints "url hash" for each pinned file in preview.js.
pins() {
  awk '
    /const CDN = "/ { split($0, q, "\""); cdn = q[2] }
    /const GRAMMAR_URL = CDN \+ "/ { split($0, q, "\""); grammars = cdn q[2] }
    /^ *CDN \+ "/ { split($0, q, "\""); url = cdn q[2]; next }
    url != "" && /"sha384-/ { split($0, q, "\""); print url, q[2]; url = ""; next }
    /^ *[a-z]+: "sha384-/ { name = $1; sub(/:$/, "", name); split($0, q, "\""); print grammars name ".min.js", q[2] }
  ' "$js"
}

checked=0
failed=0
while read -r url expected; do
  actual="sha384-$(curl -fsSL --retry 3 "$url" | openssl dgst -sha384 -binary | openssl base64 -A)"
  checked=$((checked + 1))
  if [[ $actual != "$expected" ]]; then
    failed=$((failed + 1))
    printf 'MISMATCH %s\n  pinned: %s\n  served: %s\n' "$url" "$expected" "$actual"
  fi
done < <(pins)

if [[ $checked -lt 30 ]]; then
  printf 'Only found %d pinned files in preview.js; the parser needs updating.\n' "$checked"
  exit 1
fi
printf 'Pinned libraries: %d checked, %d mismatched\n' "$checked" "$failed"
[[ $failed -eq 0 ]]
