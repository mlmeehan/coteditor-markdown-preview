#!/bin/bash
#
# Smoke tests for "src/Markdown Preview.sh". Each test runs the script the way
# CotEditor does (document text on standard input, its path as the first
# argument) with MARKDOWN_PREVIEW_NO_OPEN=1, then inspects the HTML it wrote.
# Needs cmark-gfm. The libraries are fetched first if they're missing, which
# needs the network once.

set -eu -o pipefail

here=$(cd -P -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
/bin/bash "$repo/tools/fetch-libraries.sh" >/dev/null
work=$(mktemp -d "${TMPDIR:-/tmp}/script-tests.XXXXXX")
# A test makes a folder read-only, so make everything writable again first.
trap 'chmod -R u+w "$work" 2>/dev/null; rm -rf "$work"' EXIT
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
expect_in "$page" "'strict-dynamic'; object-src" "lets the page's script load its libraries"
# Links in the document itself are the document's business.
outside=$(awk '/<article /{ skip = 1 } !skip { print } /<\/article>/{ skip = 0 }' "$page")
if grep -E -q 'https?://' <<< "$outside"; then
  fail "the page itself refers to nothing on the internet" "$(grep -E -o '.{0,30}https?://.{0,30}' <<< "$outside" | head -n 3)"
else
  pass "the page itself refers to nothing on the internet"
fi
library_url=$(sed -n 's/.*"libraries": "\([^"]*\)".*/\1/p' "$page")
lib=${library_url#file://}
lib=${lib%/}
if [[ $lib == "$TMPDIR/coteditor-markdown-preview/lib-"* ]] && cmp -s "$lib/manifest.txt" "$repo/src/_markdown-preview/lib/manifest.txt"; then
  pass "copies the libraries next to the preview"
else
  fail "copies the libraries next to the preview" "libraries: $library_url"
fi
rm "$lib/katex/katex.min.js"
preview "$repo/src" "$repo/examples/feature-tour.md" > /dev/null
if [[ -f "$lib/katex/katex.min.js" ]]; then
  pass "restores a library file macOS cleaned up"
else
  fail "restores a library file macOS cleaned up"
fi
# This test folder's path has a dot in it (script-tests.XXXXXX).
mkdir "$TMPDIR/coteditor-markdown-preview/lib-123" "$TMPDIR/coteditor-markdown-preview/lib-123.456"
rm "$lib/manifest.txt"
preview "$repo/src" "$repo/examples/feature-tour.md" > /dev/null
if [[ ! -e "$TMPDIR/coteditor-markdown-preview/lib-123" ]]; then
  pass "removes libraries copied for another version"
else
  fail "removes libraries copied for another version"
fi
if [[ -d "$TMPDIR/coteditor-markdown-preview/lib-123.456" ]]; then
  pass "leaves a copy another preview is still making"
else
  fail "leaves a copy another preview is still making"
fi
if errors=$(preview "$repo/src" "$repo/examples/feature-tour.md" 2>&1 >/dev/null) && [[ -z $errors ]]; then
  pass "says nothing when the libraries are already copied"
else
  fail "says nothing when the libraries are already copied" "$errors"
fi
# A copy that can't be replaced, such as one left by another user.
rm -rf "$lib"
mkdir "$lib"
touch "$lib/stray"
chmod a-w "$lib"
if errors=$(preview "$repo/src" "$repo/examples/feature-tour.md" 2>&1 >/dev/null); then
  fail "reports libraries it couldn't copy" "$errors"
elif [[ $errors == *"The libraries couldn't be copied"* ]]; then
  pass "reports libraries it couldn't copy"
else
  fail "reports libraries it couldn't copy" "$errors"
fi
chmod u+w "$lib"
rm -rf "$lib"
mkdir -p "$work/linked-tmp" "$work/elsewhere"
ln -s "$work/elsewhere" "$work/linked-tmp/coteditor-markdown-preview"
if errors=$(TMPDIR="$work/linked-tmp" preview "$repo/src" "$repo/examples/feature-tour.md" 2>&1); then
  fail "refuses a preview folder that's a link" "$errors"
elif [[ $errors == *"isn't a folder of yours"* && -z $(ls -A "$work/elsewhere") ]]; then
  pass "refuses a preview folder that's a link"
else
  fail "refuses a preview folder that's a link" "$errors"
fi
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
printf 'browser = Safari   # a comment\ntheme = dark\nunknown = 1\n' > "$src/_markdown-preview/config"
printf '/* custom styles marker */\n' > "$src/_markdown-preview/custom.css"
output=$(preview "$src" "$repo/examples/feature-tour.md")
page=${output%%$'\n'*}
expect_in "$page" 'data-theme="dark"' "theme = dark"
expect_in "$page" '/* custom styles marker */' "includes custom.css"
if [[ $output == *"Opens with: Safari"* ]]; then pass "browser = Safari"; else fail "browser = Safari" "$output"; fi

src=$(copy_src case)
printf 'Theme = Dark\nbrowser = "Google Chrome"\n' > "$src/_markdown-preview/config"
output=$(preview "$src" "$repo/examples/feature-tour.md")
page=${output%%$'\n'*}
expect_in "$page" 'data-theme="dark"' "setting names and values ignore case"
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

src=$(copy_src no-libraries)
rm "$src/_markdown-preview/lib/mermaid/mermaid.min.js"
if errors=$(preview "$src" "$repo/examples/feature-tour.md" 2>&1); then
  fail "reports a missing library" "$errors"
else
  case $errors in
    *"libraries"*"Reinstalling"*) pass "reports a missing library" ;;
    *) fail "reports a missing library" "$errors" ;;
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
