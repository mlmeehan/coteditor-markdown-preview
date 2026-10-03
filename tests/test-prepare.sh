#!/bin/bash
#
# Runs src/_markdown-preview/prepare.awk against the cases in
# tests/prepare-cases.txt and the fixture pairs in tests/prepare/.
#
# Uses /usr/bin/awk (the BWK awk that ships with macOS) unless AWK is set,
# for example: AWK=gawk tests/test-prepare.sh

set -eu -o pipefail

here=$(cd -P -- "$(dirname -- "$0")" && pwd)
program="$here/../src/_markdown-preview/prepare.awk"
awk_bin=${AWK:-/usr/bin/awk}
work=$(mktemp -d "${TMPDIR:-/tmp}/prepare-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Split the cases into numbered files: N.name, N.md and N.expected.
awk -v dir="$work" '
  /^%%% / {
    if (file != "") close(file)
    if ($0 == "%%% expect") {
      file = dir "/" n ".expected"
      printf "" > file
      next
    }
    n++
    print substr($0, 5) > (dir "/" n ".name")
    close(dir "/" n ".name")
    file = dir "/" n ".md"
    printf "" > file
    next
  }
  file != "" { print > file }
' "$here/prepare-cases.txt"

# Drops trailing blank lines so that cases don't depend on them.
trimmed() {
  awk '{ line[NR] = $0 } END { n = NR; while (n > 0 && line[n] == "") n--; for (i = 1; i <= n; i++) print line[i] }' "$1"
}

passed=0
failed=0

run_case() {
  local name=$1 input=$2 expected=$3
  LC_ALL=C "$awk_bin" -f "$program" < "$input" > "$work/actual" 2> "$work/errors" || true
  trimmed "$work/actual" > "$work/actual.trimmed"
  trimmed "$expected" > "$work/expected.trimmed"
  if [[ -s "$work/errors" ]] || ! cmp -s "$work/actual.trimmed" "$work/expected.trimmed"; then
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$name"
    cat "$work/errors"
    diff -u "$work/expected.trimmed" "$work/actual.trimmed" | sed '1,2d; s/^/     /' || true
  else
    passed=$((passed + 1))
  fi
}

n=1
while [[ -f "$work/$n.name" ]]; do
  run_case "$(cat "$work/$n.name")" "$work/$n.md" "$work/$n.expected"
  n=$((n + 1))
done

for input in "$here"/prepare/*.md; do
  run_case "${input##*/}" "$input" "${input%.md}.expected"
done

printf 'prepare.awk with %s: %d passed, %d failed\n' "$awk_bin" "$passed" "$failed"
[[ $failed -eq 0 ]]
