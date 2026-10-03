#!/bin/bash
#%%%{CotEditorXInput=AllText}%%%
#
# Markdown Preview for CotEditor
# https://github.com/mlmeehan/coteditor-markdown-preview
#
# Shows the frontmost CotEditor document as GitHub-flavored Markdown in your
# web browser. CotEditor passes the document's text on standard input and, if
# the document has been saved, its path as the first argument.
#
# The files this script uses live in the "_markdown-preview" folder next to
# it, which CotEditor keeps out of the Script menu. Settings go in the
# "config" file there, and your own styles in "custom.css".
#
# Copyright (c) 2026 Michael Meehan. Released under the MIT License.

set -eu -o pipefail
# bash 5.2 and later would expand "&" in ${text//x/y}; macOS's bash 3.2 never does.
shopt -u patsub_replacement 2>/dev/null || true

readonly VERSION="1.0.0"
# The files in _markdown-preview this version needs. The installer checks a
# release has them all before installing it.
readonly REQUIRED_FILES="prepare.awk preview.css preview.js"
# shellcheck disable=SC2016  # shown to the user as-is
readonly INSTALL_COMMAND='/bin/bash -c "$(curl -fsSL https://github.com/mlmeehan/coteditor-markdown-preview/releases/latest/download/install.sh)"'

# MARKDOWN_PREVIEW_NO_OPEN=1 prints where the preview was written instead of
# opening it, and never shows a dialog. The tests and `install.sh --doctor`
# use it.
headless=${MARKDOWN_PREVIEW_NO_OPEN:-}

# Explains a problem, then stops. Text written to standard error appears in
# CotEditor's Console (Window > Console); the alert offers an optional
# Terminal command on a "Copy Command" button.
report() {
  local message=$1 command=${2:-}

  printf 'Markdown Preview: %s\n' "$message" >&2
  if [[ -n $command ]]; then
    printf 'Run this in Terminal to fix it: %s\n' "$command" >&2
  fi

  if [[ -z $headless ]]; then
    /usr/bin/osascript - "$message" "$command" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run {errorText, fixCommand}
  activate
  if fixCommand is "" then
    display alert "Markdown Preview" message errorText as critical
  else
    set choice to display alert "Markdown Preview" message (errorText & return & return & fixCommand) as critical buttons {"Copy Command", "OK"} default button "OK"
    if button returned of choice is "Copy Command" then set the clipboard to fixCommand
  end if
end run
APPLESCRIPT
  fi
  exit 1
}

here=$(cd -P -- "$(dirname -- "$0")" && pwd)
support="$here/_markdown-preview"

for part in $REQUIRED_FILES; do
  if [[ ! -f "$support/$part" ]]; then
    report "A file it needs is missing: $support/$part. Reinstalling Markdown Preview restores it." \
      "$INSTALL_COMMAND"
  fi
done

# --- Settings -----------------------------------------------------------------

browser=""
theme="auto"
remote_libraries="on"

lowercase() {
  printf '%s' "$1" | /usr/bin/tr '[:upper:]' '[:lower:]'
}

# Reads "name = value" lines from the config file. "#" starts a comment,
# case doesn't matter, and quotes around a value are optional.
read_config() {
  local line key value
  local pattern='^[[:space:]]*([A-Za-z_]+)[[:space:]]*=[[:space:]]*(.*)$'

  [[ -f "$support/config" ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    [[ $line =~ $pattern ]] || continue
    key=$(lowercase "${BASH_REMATCH[1]}")
    value=${BASH_REMATCH[2]}
    value=${value%"${value##*[![:space:]]}"}
    case $value in
      \"*\" | \'*\') value=${value:1:${#value}-2} ;;
    esac
    case $key in
      browser) browser=$value ;;
      theme) theme=$(lowercase "$value") ;;
      remote_libraries) remote_libraries=$(lowercase "$value") ;;
    esac
  done < "$support/config"
}

read_config

case $theme in
  light | dark) ;;
  *) theme="auto" ;;
esac

case $remote_libraries in
  off | no | false | 0) remote_libraries="false" ;;
  *) remote_libraries="true" ;;
esac

# --- cmark-gfm ------------------------------------------------------------------

# CotEditor runs scripts with a minimal PATH, so look where Homebrew and
# MacPorts install it too. MARKDOWN_PREVIEW_CMARK_GFM overrides the search.
find_cmark_gfm() {
  local candidate
  for candidate in "$(command -v cmark-gfm 2>/dev/null || true)" \
    /opt/homebrew/bin/cmark-gfm /usr/local/bin/cmark-gfm /opt/local/bin/cmark-gfm; do
    if [[ -n $candidate && -x $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if [[ -n ${MARKDOWN_PREVIEW_CMARK_GFM:-} ]]; then
  cmark=$MARKDOWN_PREVIEW_CMARK_GFM
  if [[ ! -x $cmark ]]; then
    report "MARKDOWN_PREVIEW_CMARK_GFM is set to $cmark, which isn't a program it can run."
  fi
elif ! cmark=$(find_cmark_gfm); then
  report "It needs cmark-gfm, GitHub's Markdown renderer, which isn't installed. Install it with Homebrew, then try again." \
    "brew install cmark-gfm"
fi

# Raw HTML is kept (<details>, <kbd>, <sub>, ...); scripts inside the document
# are blocked by the page's Content-Security-Policy, as on GitHub.
cmark_options=(
  --unsafe
  --validate-utf8
  --extension table
  --extension strikethrough
  --extension autolink
  --extension tasklist
  --extension footnotes
)

# --- The page -------------------------------------------------------------------

document=${1:-}
if [[ -n $document ]]; then
  folder=$(cd -P -- "$(dirname -- "$document")" 2>/dev/null && pwd) || folder=$HOME
  name=$(basename -- "$document")
else
  folder=$HOME
  name="Untitled"
fi

# Percent-encodes a path for use in a file:// URL.
file_url_path() {
  URL_PATH=$1 LC_ALL=C /usr/bin/awk 'BEGIN {
    for (i = 1; i < 256; i++) code[sprintf("%c", i)] = i
    path = ENVIRON["URL_PATH"]
    for (i = 1; i <= length(path); i++) {
      c = substr(path, i, 1)
      if (c ~ /[-A-Za-z0-9._~\/]/) printf "%s", c
      else printf "%%%02X", code[c]
    }
  }'
}

escape_html() {
  local text=$1
  text=${text//&/&amp;}
  text=${text//</&lt;}
  text=${text//>/&gt;}
  text=${text//\"/&quot;}
  printf '%s' "$text"
}

# Relative links and images resolve against the document's folder.
base_url="file://$(file_url_path "${folder%/}")/"

# Only the page's own script, which carries this nonce, and the libraries it
# loads may run; scripts written into the document are blocked. The host is
# a fallback for browsers that predate 'strict-dynamic'.
nonce=$(/usr/bin/od -An -N16 -tx1 /dev/urandom | /usr/bin/tr -d ' \n')
script_sources="'nonce-$nonce' 'strict-dynamic'"
if [[ $remote_libraries == true ]]; then
  script_sources+=" https://cdn.jsdelivr.net"
fi

# Each document keeps one preview file, rewritten every time.
cache="${TMPDIR:-/tmp}"
cache="${cache%/}/coteditor-markdown-preview"
mkdir -p -- "$cache"
key=$(printf '%s' "${document:-untitled}" | /usr/bin/cksum)
output="$cache/preview-${key%% *}.html"
partial="$output.$$"
trap 'rm -f -- "$partial"' EXIT

render() {
  printf '<!doctype html>\n<html lang="en" data-theme="%s" class="math-pending">\n<head>\n' "$theme"
  printf '<meta charset="utf-8">\n'
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
  printf '<meta http-equiv="Content-Security-Policy" content="script-src %s; object-src '"'none'"'">\n' \
    "$script_sources"
  printf '<base href="%s">\n' "$base_url"
  printf '<title>%s</title>\n' "$(escape_html "$name")"
  printf '<style>\n'
  cat -- "$support/preview.css" || return 1
  if [[ -f "$support/custom.css" ]]; then
    cat -- "$support/custom.css" || return 1
  fi
  printf '</style>\n'
  printf '<script type="application/json" id="preview-settings">{"remoteLibraries": %s, "version": "%s"}</script>\n' \
    "$remote_libraries" "$VERSION"
  printf '</head>\n<body>\n<main class="page">\n<article class="markdown-body" id="content">\n'
  LC_ALL=C /usr/bin/awk -f "$support/prepare.awk" | "$cmark" "${cmark_options[@]}" || return 1
  printf '</article>\n</main>\n<script nonce="%s">\n' "$nonce"
  cat -- "$support/preview.js" || return 1
  printf '</script>\n</body>\n</html>\n'
}

if ! render > "$partial"; then
  report "The document couldn't be rendered. The details are in CotEditor's Console (Window > Console)."
fi
mv -f -- "$partial" "$output"

# --- Show it ----------------------------------------------------------------------

# The app that opens web links, which isn't always the app that opens .html
# files (developers often hand those to an editor).
default_browser() {
  /usr/bin/osascript -l JavaScript -e '
    ObjC.import("AppKit");
    const app = $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL(
      $.NSURL.URLWithString("https://example.com"));
    app.isNil() ? "" : app.path.js;' 2>/dev/null
}

if [[ -z $browser ]]; then
  browser=$(default_browser) || browser=""
fi

if [[ -n $headless ]]; then
  printf '%s\n' "$output"
  printf 'Opens with: %s\n' "${browser:-the default app for .html files}"
  exit 0
fi

if [[ -n $browser ]]; then
  /usr/bin/open -a "$browser" "$output" ||
    report "The preview couldn't be opened with \"$browser\". Check the browser setting in $support/config."
else
  /usr/bin/open "$output"
fi
