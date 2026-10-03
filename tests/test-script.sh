#!/bin/bash
#
# Smoke tests for "src/Markdown Preview.sh". Each test runs the script the way
# CotEditor does (document text on standard input, its path as the first
# argument) with MARKDOWN_PREVIEW_NO_OPEN=1, then inspects the HTML it wrote.
# Needs cmark-gfm.

set -eu -o pipefail

here=$(cd -P -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
work=$(mktemp -d "${TMPDIR:-/tmp}/script-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work/tmp"
mkdir -p "$TMPDIR"

passed=0
failed=0

pass() {
  passed=$((passed + 1))
  printf '  ok   %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf '  FAIL %s\n' "$1"
  if [[ -n ${2:-} ]]; then
    printf '%s\n' "$2" | sed 's/^/       /'
  fi
}

# expect_in FILE TEXT LABEL / expect_not_in FILE TEXT LABEL
expect_in() {
  if grep -qF -- "$2" "$1"; then pass "$3"; else fail "$3" "expected to find: $2"; fi
}
expect_not_in() {
  if grep -qF -- "$2" "$1"; then fail "$3" "did not expect: $2"; else pass "$3"; fi
}

# A private copy of src/, so tests can add a config or break things.
copy_src() {
  local dir="$work/src-$1"
  rm -rf "$dir"
  cp -R "$repo/src" "$dir"
  printf '%s\n' "$dir"
}

# preview SRC_DIR MARKDOWN_FILE: runs the script; prints its output.
# shellcheck disable=SC2094  # the script only reads the document
preview() {
  MARKDOWN_PREVIEW_NO_OPEN=1 /bin/bash "$1/Markdown Preview.sh" "$2" < "$2"
}

echo "Feature tour"
output=$(preview "$repo/src" "$repo/examples/feature-tour.md")
page=${output%%$'\n'*}
if [[ -f $page ]]; then pass "writes a preview file"; else fail "writes a preview file" "$output"; fi
expect_in "$page" '<title>feature-tour.md</title>' "title is the file name"
expect_in "$page" 'data-theme="auto"' "follows the system appearance by default"
expect_in "$page" 'class="md-math" data-mode="inline"' "protects inline math"
expect_in "$page" 'class="md-math" data-mode="block"' "protects display math"
expect_in "$page" 'class="language-mermaid"' "keeps Mermaid blocks"
expect_in "$page" '<details class="front-matter">' "folds front matter"
expect_in "$page" '<section class="footnotes"' "renders footnotes"
expect_in "$page" '<td align="right">1,024</td>' "renders aligned tables"
expect_in "$page" 'type="checkbox"' "renders task lists"
expect_in "$page" "'strict-dynamic' https://cdn.jsdelivr.net" "lets the page's script load its libraries"
nonce=$(sed -n "s/.*'nonce-\([0-9a-f]*\)'.*/\1/p" "$page" | head -n 1)
if [[ ${#nonce} -eq 32 ]] && grep -qF "<script nonce=\"$nonce\">" "$page"; then
  pass "only the page's own script carries the CSP nonce"
else
  fail "only the page's own script carries the CSP nonce" "nonce: $nonce"
fi
again=$(preview "$repo/src" "$repo/examples/feature-tour.md")
if [[ ${again%%$'\n'*} == "$page" ]]; then pass "reuses one file per document"; else fail "reuses one file per document"; fi
if [[ $output == *$'\n'"Opens with: "* ]]; then pass "reports the browser"; else fail "reports the browser" "$output"; fi

echo "Paths and names"
folder="$work/Café Notes & Docs"
mkdir -p "$folder"
cp "$repo/examples/feature-tour.md" "$folder/a<b>&\"c\".md"
output=$(preview "$repo/src" "$folder/a<b>&\"c\".md")
page=${output%%$'\n'*}
expect_in "$page" "Caf%C3%A9%20Notes%20%26%20Docs/\">" "percent-encodes the base folder"
expect_in "$page" '<title>a&lt;b&gt;&amp;&quot;c&quot;.md</title>' "escapes the title"
output=$(cd "$work" && printf '# Untitled\n' | MARKDOWN_PREVIEW_NO_OPEN=1 /bin/bash "$repo/src/Markdown Preview.sh")
page=${output%%$'\n'*}
expect_in "$page" '<title>Untitled</title>' "handles unsaved documents"

echo "Settings"
src=$(copy_src settings)
printf 'browser = Safari   # a comment\ntheme = dark\nremote_libraries = off\nunknown = 1\n' > "$src/_markdown-preview/config"
printf '/* custom styles marker */\n' > "$src/_markdown-preview/custom.css"
output=$(preview "$src" "$repo/examples/feature-tour.md")
page=${output%%$'\n'*}
expect_in "$page" 'data-theme="dark"' "theme = dark"
expect_in "$page" '"remoteLibraries": false' "remote_libraries = off reaches the page"
if grep 'Content-Security-Policy' "$page" | grep -q 'cdn.jsdelivr.net'; then
  fail "remote_libraries = off blocks the CDN"
else
  pass "remote_libraries = off blocks the CDN"
fi
expect_in "$page" '/* custom styles marker */' "includes custom.css"
if [[ $output == *"Opens with: Safari"* ]]; then pass "browser = Safari"; else fail "browser = Safari" "$output"; fi

src=$(copy_src case)
printf 'Theme = Dark\nREMOTE_LIBRARIES = Off\nbrowser = "Google Chrome"\n' > "$src/_markdown-preview/config"
output=$(preview "$src" "$repo/examples/feature-tour.md")
page=${output%%$'\n'*}
expect_in "$page" 'data-theme="dark"' "setting names and values ignore case"
expect_in "$page" '"remoteLibraries": false' "remote_libraries = Off"
if [[ $output == *"Opens with: Google Chrome"$'\n'* || $output == *"Opens with: Google Chrome" ]]; then
  pass "quotes around a value are optional"
else
  fail "quotes around a value are optional" "$output"
fi

echo "Problems"
if errors=$(MARKDOWN_PREVIEW_CMARK_GFM=/nonexistent/cmark-gfm preview "$repo/src" "$repo/examples/feature-tour.md" 2>&1); then
  fail "reports a missing cmark-gfm" "$errors"
else
  case $errors in
    *"MARKDOWN_PREVIEW_CMARK_GFM"*) pass "reports a missing cmark-gfm" ;;
    *) fail "reports a missing cmark-gfm" "$errors" ;;
  esac
fi

src=$(copy_src missing)
rm "$src/_markdown-preview/preview.js"
if errors=$(preview "$src" "$repo/examples/feature-tour.md" 2>&1); then
  fail "reports a missing support file" "$errors"
else
  case $errors in
    *"preview.js"*) pass "reports a missing support file" ;;
    *) fail "reports a missing support file" "$errors" ;;
  esac
fi

src=$(copy_src broken)
printf 'BEGIN {\n' > "$src/_markdown-preview/prepare.awk"
if errors=$(preview "$src" "$repo/examples/feature-tour.md" 2>&1); then
  fail "reports a rendering failure" "$errors"
else
  case $errors in
    *"couldn't be rendered"*) pass "reports a rendering failure" ;;
    *) fail "reports a rendering failure" "$errors" ;;
  esac
fi
leftovers=$(find "$TMPDIR/coteditor-markdown-preview" -name '*.html.*' 2>/dev/null)
if [[ -z $leftovers ]]; then pass "cleans up after a failure"; else fail "cleans up after a failure" "$leftovers"; fi

printf '\nScript: %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
