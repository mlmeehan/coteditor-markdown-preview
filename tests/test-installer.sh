#!/bin/bash
#
# Tests install.sh against a temporary scripts folder, never your real one.
# Installs from the local src folder. The libraries are fetched first if
# they're missing, which needs the network that once; after that the tests run
# offline. The installed script is test-run, so cmark-gfm must be installed.
# Needs macOS.

set -eu -o pipefail

here=$(cd -P -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
installer="$repo/install.sh"
/bin/bash "$repo/tools/fetch-libraries.sh" >/dev/null
work=$(mktemp -d "${TMPDIR:-/tmp}/installer-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT

export MARKDOWN_PREVIEW_SCRIPTS_DIR="$work/Application Scripts/com.coteditor.CotEditor"
export TMPDIR="$work/tmp"
mkdir -p "$TMPDIR"
scripts=$MARKDOWN_PREVIEW_SCRIPTS_DIR
support="$scripts/_markdown-preview"

passed=0
failed=0

check() {
  local label=$1
  shift
  if "$@"; then
    passed=$((passed + 1))
    printf '  ok   %s\n' "$label"
  else
    failed=$((failed + 1))
    printf '  FAIL %s\n' "$label"
    if [[ -n ${log:-} ]]; then
      printf '%s\n' "$log" | sed 's/^/       /'
    fi
  fi
}

contains() { [[ $1 == *"$2"* ]]; }
lacks() { [[ $1 != *"$2"* ]]; }
lacks_text() { ! grep -q -- "$1" "$2"; }
only_one_script() { [[ $(grep -l "github.com/mlmeehan/coteditor-markdown-preview" "$scripts"/*.sh | wc -l) -eq 1 ]]; }
no_partials() { [[ -z $(find "$scripts" -name '*.partial') ]]; }

install() { log=$("$installer" --from "$repo/src" --no-deps "$@" 2>&1); }

# macOS's bash 3.2 reads a byte of a character such as "…" right after $name
# as part of the name, so it needs braces: ${name}…
no_bare_names() { ! LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$@"; }

echo "Shell files"
check "no \$name right before a non-ASCII character" \
  no_bare_names "$installer" "$repo/src/Markdown Preview.sh" "$repo"/tools/*.sh

echo "Fresh install"
install
check "installs with Command-Shift-M" test -x "$scripts/Markdown Preview.@M.sh"
for file in prepare.awk preview.css preview.js config config.example LICENSE THIRD-PARTY-NOTICES.md .installed; do
  check "installs $file" test -f "$support/$file"
done
check "installs the libraries" test -f "$support/lib/mermaid/mermaid.min.js"
check "with their licenses" test -f "$support/lib/katex/fonts/OFL.txt"
check "lists the lib folder" grep -q "^folder$(printf '\t')lib$" "$support/.installed"
check "reports the shortcut" contains "$log" "⇧⌘M"
check "leaves no temporary files" no_partials
# shellcheck disable=SC2016  # literal Markdown math
output=$(printf '# Hi $x$\n' | MARKDOWN_PREVIEW_NO_OPEN=1 "$scripts/Markdown Preview.@M.sh")
page=${output%%$'\n'*}
check "the installed script renders" grep -q 'class="md-math"' "$page"

echo "Updates"
printf 'theme = dark\n' >> "$support/config"
install
check "says it updated" contains "$log" "Updated"
check "keeps a changed config" grep -q '^theme = dark' "$support/config"
check "mentions the kept config" contains "$log" "Kept your settings"
check "replaces the lib folder rather than nesting it" test ! -e "$support/lib/lib"
check "leaves no old lib folder" test ! -e "$support/lib.old"

# An update from a version without the lib folder.
mv "$support/lib" "$work/lib-saved"
install
check "adds the lib folder to an earlier install" test -f "$support/lib/manifest.txt"
rm -rf "$work/lib-saved"

install --shortcut '@~p'
check "--shortcut renames the script" test -x "$scripts/Markdown Preview.@~p.sh"
check "--shortcut removes the old name" test ! -e "$scripts/Markdown Preview.@M.sh"
check "describes Option-Command-P" contains "$log" "⌥⌘P"

mv "$scripts/Markdown Preview.@~p.sh" "$scripts/01)Markdown Preview.@~p.sh"
install
check "keeps a name you changed" test -x "$scripts/01)Markdown Preview.@~p.sh"
check "leaves one copy" only_one_script

install --shortcut none
check "--shortcut none" test -x "$scripts/Markdown Preview.sh"
check "--shortcut none leaves one copy" only_one_script

echo "Other scripts"
printf '#!/bin/sh\necho mine\n' > "$scripts/Markdown Preview.@M.sh"
printf '#!/bin/sh\necho other\n' > "$scripts/Preview.@M.sh"
install --shortcut '@M'
check "moves a different script out of the way" grep -q 'echo mine' "$support/backup/Markdown Preview.@M.sh"
check "installs over it" grep -q 'github.com/mlmeehan' "$scripts/Markdown Preview.@M.sh"
check "warns about a shortcut clash" contains "$log" "\"Preview.@M.sh\" uses the same shortcut"
check "leaves other scripts alone" grep -q 'echo other' "$scripts/Preview.@M.sh"

echo "Your own copies"
installed="$scripts/Markdown Preview.@M.sh"
variant="$scripts/Markdown Preview in Chrome.@~M.sh"
duplicate="$scripts/Markdown Preview.@M copy.sh"
cp "$installed" "$variant"
printf '# my change\n' >> "$variant"
cp "$installed" "$duplicate"
install
check "an update keeps a copy you edited" grep -q '^# my change' "$variant"
check "an update keeps a duplicate" test -f "$duplicate"
check "and still updates its own" test -x "$installed"
check "says it left your copy alone" contains "$log" "\"Markdown Preview in Chrome.@~M.sh\" alone"

printf '# edited in place\n' >> "$installed"
install
check "saves the installed script you edited" grep -q '^# edited in place' "$support/backup/Markdown Preview.@M 2.sh"
check "without replacing an earlier backup" grep -q 'echo mine' "$support/backup/Markdown Preview.@M.sh"
check "and installs a fresh copy" lacks_text 'edited in place' "$installed"
check "says why" contains "$log" "was edited after it was installed"

printf '# edited again\n' >> "$installed"
mv "$support/backup" "$work/backup-saved"
printf 'not a folder\n' > "$support/backup"
if install; then false; fi
check "stops if it can't save your edits" grep -q '^# edited again' "$installed"
check "and says so" contains "$log" "Couldn't move \"Markdown Preview.@M.sh\""
rm -f "$support/backup"
mv "$work/backup-saved" "$support/backup"
install
check "saves them once it can" grep -q '^# edited again' "$support/backup/Markdown Preview.@M 3.sh"

echo "Failures"
broken="$work/broken-src"
cp -R "$repo/src" "$broken"
cp "$repo/LICENSE" "$repo/THIRD-PARTY-NOTICES.md" "$broken/"
printf '/* new version */\n' >> "$broken/_markdown-preview/preview.css"
chmod 000 "$broken/_markdown-preview/preview.js"
if log=$("$installer" --from "$broken" --no-deps 2>&1); then false; fi
check "a failed update changes nothing" lacks_text 'new version' "$support/preview.css"
check "says so" contains "$log" "nothing was changed"
check "and cleans up after itself" no_partials

chmod 644 "$broken/_markdown-preview/preview.js"
mv "$broken/_markdown-preview/preview.js" "$work/preview.js"
if log=$("$installer" --from "$broken" --no-deps 2>&1); then false; fi
check "refuses a version that's missing a file" contains "$log" "doesn't contain _markdown-preview/preview.js"
check "and keeps the installed one" test -f "$support/preview.js"
mv "$work/preview.js" "$broken/_markdown-preview/preview.js"

mv "$broken/_markdown-preview/lib/highlight/highlight.min.js" "$work/highlight.min.js"
if log=$("$installer" --from "$broken" --no-deps 2>&1); then false; fi
check "refuses a version that's missing a library" contains "$log" "_markdown-preview/lib are missing or damaged"
check "and keeps the installed libraries" test -f "$support/lib/highlight/highlight.min.js"
mv "$work/highlight.min.js" "$broken/_markdown-preview/lib/highlight/highlight.min.js"
cp "$broken/_markdown-preview/lib/emoji/emoji.js" "$work/emoji.js"
printf '\n' >> "$broken/_markdown-preview/lib/emoji/emoji.js"
if log=$("$installer" --from "$broken" --no-deps 2>&1); then false; fi
check "refuses a version with a damaged library" contains "$log" "_markdown-preview/lib are missing or damaged"
mv "$work/emoji.js" "$broken/_markdown-preview/lib/emoji/emoji.js"

rm "$support/lib/katex/katex.min.css"
log=$("$installer" --doctor 2>&1 || true)
check "doctor notices a missing library file" contains "$log" "1 library file(s) are missing or damaged"
printf '\n' >> "$support/lib/katex/katex.min.js"
log=$("$installer" --doctor 2>&1 || true)
check "and a damaged one" contains "$log" "2 library file(s) are missing or damaged"
install

mkdir "$work/broken-tools"
for tool in shasum sha256sum openssl; do
  printf '#!/bin/sh\nexit 1\n' > "$work/broken-tools/$tool"
  chmod 755 "$work/broken-tools/$tool"
done
if log=$(PATH="$work/broken-tools:$PATH" "$installer" --from "$broken" --no-deps 2>&1); then false; fi
check "stops when checksums can't be computed" contains "$log" "Couldn't compute checksums"
check "before changing anything" lacks_text 'new version' "$support/preview.css"

echo "Options"
if log=$("$installer" --shortcut 'M' 2>&1); then false; fi
check "rejects a shortcut without modifiers" contains "$log" "isn't a CotEditor shortcut"
if log=$("$installer" --shortcut '@F1' 2>&1); then false; fi
check "rejects a non-letter key" contains "$log" "isn't a CotEditor shortcut"
if log=$("$installer" --bogus 2>&1); then false; fi
check "rejects unknown options" contains "$log" "Unknown option"
log=$("$installer" --help)
check "--help" contains "$log" "Usage: install.sh"
# A mistyped option without the " -- " the one-line command needs.
if log=$(/bin/bash -c "$(cat "$installer")" --uninstal 2>&1); then false; fi
check "rejects a mistyped option without --" contains "$log" "Unknown option \"--uninstal\""

echo "Doctor"
printf 'them = dark\nTheme = Dark\n' >> "$support/config"
log=$("$installer" --doctor 2>&1 || true)
check "finds the installation" contains "$log" "Installed: \"Markdown Preview.@M.sh\""
check "finds cmark-gfm" contains "$log" "cmark-gfm: "
check "runs a test preview" contains "$log" "Test preview: "
tested=$(sed -n 's/.*Test preview: //p' <<< "$log")
check "removes its test preview" test -n "$tested" -a ! -e "$tested"
check "and its sample document" test -z "$(find "$TMPDIR" -name 'markdown-preview*')"
check "notices the clash" contains "$log" "uses the same shortcut"
check "mentions your own copies" contains "$log" "\"Markdown Preview in Chrome.@~M.sh\", a copy"
check "points out an unknown setting" contains "$log" "no setting called \"them\""
check "checks the libraries" contains "$log" "Libraries (no internet needed): katex"
check "accepts values in any case" lacks "$log" "\"Dark\" is treated"
# Looking up the browser needs macOS itself, not the stand-in uname.
if [[ $(/usr/bin/uname -s) == Darwin ]]; then
  cp "$support/config" "$work/config-saved"
  printf 'browser = Safari\n' >> "$support/config"
  log=$("$installer" --doctor 2>&1 || true)
  check "finds the browser" lacks "$log" "no app called"
  printf 'browser = No Such Browser\n' >> "$support/config"
  log=$("$installer" --doctor 2>&1 || true)
  check "points out a browser that isn't there" contains "$log" "no app called \"No Such Browser\""
  cp "$work/config-saved" "$support/config"
fi

echo "Uninstall"
printf '/* mine */\n' > "$support/custom.css"
# Without the " -- " the one-line command needs before options.
log=$(/bin/bash -c "$(cat "$installer")" --uninstall 2>&1)
check "works without the --" contains "$log" "Removing Markdown Preview"
check "removes the script" test ! -e "$scripts/Markdown Preview.@M.sh"
check "removes program files" test ! -e "$support/preview.js"
check "removes the libraries" test ! -e "$support/lib"
check "keeps custom.css" test -f "$support/custom.css"
check "keeps a changed config" test -f "$support/config"
check "keeps backups" test -d "$support/backup"
check "keeps other scripts" test -f "$scripts/Preview.@M.sh"
check "keeps a copy you edited" test -f "$variant"
check "keeps a duplicate" test -f "$duplicate"
rm -rf "$support/custom.css" "$support/config" "$support/backup"
install
log=$("$installer" --uninstall 2>&1)
check "removes everything when nothing was changed" test ! -e "$support"

echo "Installed by hand"
mkdir -p "$support"
cp "$repo/src/Markdown Preview.sh" "$scripts/Markdown Preview.@M.sh"
cp -R "$repo/src/_markdown-preview/"* "$support/"
install
check "updates a copy installed by hand" contains "$log" "Updated"
check "saves the earlier copy, in case you changed it" test -f "$support/backup/Markdown Preview.@M.sh"
check "starts keeping its list of files" test -f "$support/.installed"
log=$("$installer" --uninstall 2>&1)
check "uninstall removes the libraries too" test ! -e "$support/lib"
rm -rf "$support"
mkdir -p "$support"
cp -R "$repo/src/_markdown-preview/"* "$support/"
cp "$repo/src/Markdown Preview.sh" "$scripts/Markdown Preview.@M.sh"
log=$("$installer" --uninstall 2>&1)
check "uninstalls a copy installed by hand, libraries and all" test ! -e "$support/lib"
rm -rf "$support"

echo "Links"
clone="$work/clone"
cp -R "$repo/src/_markdown-preview" "$clone"
ln -s "$clone" "$support"
if install; then false; fi
check "won't install through a linked folder" contains "$log" "symbolic link"
check "leaves the linked folder alone" test ! -e "$clone/config"
log=$("$installer" --uninstall 2>&1)
check "uninstall removes only the link" test ! -L "$support"
check "and leaves what it pointed to" test -f "$clone/preview.js"

printf '\nInstaller: %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
