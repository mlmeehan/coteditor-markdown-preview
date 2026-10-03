#!/bin/bash
#
# Builds _markdown-preview/lib: the browser libraries the preview uses, so
# that previews work without an internet connection. Each package is
# downloaded from the npm registry, checked against the integrity hash pinned
# below, and only the files the preview loads are kept, with their licenses.
#
#   tools/fetch-libraries.sh            # into src/_markdown-preview/lib
#   tools/fetch-libraries.sh DIR        # somewhere else
#
# install.sh --from and the tests run it for you. When DIR is already up to
# date it says so and downloads nothing; delete DIR to download it again.
#
# To upgrade a package, see "Updating a library" in CONTRIBUTING.md.

set -eu -o pipefail

# name, version, npm integrity hash. One package per line: the pins at the top
# of lib/manifest.txt are these lines, and tools/mermaid-notices.mjs reads
# Mermaid's version from here.
readonly PACKAGES='
katex                    0.18.9   sha512-8ad9RyoKsb/g8/yLFE+KAlP+DhbCTRUNi/V9XGsxn0R+trJJltNwzcDNo0q/DEkOy5fQUQTAQyCXCYSE+OakTQ==
mermaid                  11.17.2  sha512-V6K3C8EBdEsPFZXSKMJe6ppQOENxuHARr9GvHX4hh47lAbhMRD9qf4oEK7LoaRQxULMa80/qt5gHO73aCleBBg==
@highlightjs/cdn-assets  11.12.0  sha512-KvOKXODaiFmId9xaq3xc5xCL66wVLUuOngDbO9B/kewbFTqdGbn2nJxNhN3H5R1cgDTVj6R8vH0zgiNDEGjpDw==
markdown-it-emoji        3.1.0    sha512-NhmMEH2ywduD4Nty1E8uB5NqfLhAT1VR0dyvoJyStKOqCzbZmVdn/+8wj7zpDsb/fLBikpCPsWwxqKlvMmbz4g==
'
readonly REGISTRY="https://registry.npmjs.org"

here=$(cd -P -- "$(dirname -- "$0")" && pwd)
repo=$(dirname -- "$here")

dest=""
for arg in "$@"; do
  case $arg in
    -*) printf 'Unknown option %s\n' "$arg" >&2; exit 2 ;;
    *) dest=$arg ;;
  esac
done
dest=${dest:-$repo/src/_markdown-preview/lib}
dest=${dest%/}

die() {
  printf 'fetch-libraries: %s\n' "$*" >&2
  exit 1
}

# The highlight.js grammars preview.js loads on demand, read from its GRAMMARS
# list (in the preview.js next to DIR when there is one).
preview_js="$(dirname -- "$dest")/preview.js"
[[ -f $preview_js ]] || preview_js="$repo/src/_markdown-preview/preview.js"
grammars=$(awk '
  /const GRAMMARS = new Set\(\[/ { inside = 1; next }
  inside && /\]\);/ { exit }
  inside { while (match($0, /"[a-z0-9]+"/)) { print substr($0, RSTART + 1, RLENGTH - 2); $0 = substr($0, RSTART + RLENGTH) } }
' "$preview_js")
[[ $(wc -l <<< "$grammars") -ge 20 ]] || die "couldn't find the GRAMMARS list in preview.js."

# lib/manifest.txt is the pinned packages, one per line as in PACKAGES, then a
# blank line, then every other file in lib as `shasum -a 256` prints it:
#   <SHA-256><two spaces><path relative to lib>
# The preview script names its copy of lib after the manifest's checksum, and
# it and install.sh read the file list; they can't share code with this
# script, since each runs on its own.
pins=$(awk 'NF == 3 { print $1, $2, $3 }' <<< "$PACKAGES")

# Up to date: the same versions, every file present, and every grammar
# preview.js asks for. This needs no network, so it's cheap to run every time.
up_to_date() {
  local sum file name
  [[ -f "$dest/manifest.txt" ]] || return 1
  [[ $(sed -n '/^$/q;p' "$dest/manifest.txt") == "$pins" ]] || return 1
  while read -r sum file; do
    [[ -n $sum && -f "$dest/$file" ]] || return 1
  done < <(sed '1,/^$/d' "$dest/manifest.txt")
  while IFS= read -r name; do
    grep -q "  highlight/languages/$name\\.min\\.js$" "$dest/manifest.txt" || return 1
  done <<< "$grammars"
}

# Left by an interrupted run.
rm -rf "$dest.old"

if up_to_date; then
  printf 'Libraries are up to date in %s\n' "$dest"
  exit 0
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/fetch-libraries.XXXXXX")
trap 'rm -rf "$work"' EXIT
out="$work/lib"
mkdir -p "$out"

# Downloads a package, checks its hash and unpacks its contents into DIR.
unpack() {
  local name=$1 dir=$2 version expected actual file
  read -r _ version expected < <(awk -v name="$name" '$1 == name' <<< "$PACKAGES")
  file="$work/${name//\//_}.tgz"
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --connect-timeout 15 -o "$file" \
    "$REGISTRY/$name/-/${name##*/}-$version.tgz" || die "couldn't download $name $version."
  actual="sha512-$(openssl dgst -sha512 -binary "$file" | openssl base64 -A)"
  [[ $actual == "$expected" ]] || die "$name $version doesn't match its pinned hash (got $actual)."
  mkdir -p "$dir" || die "couldn't create $dir."
  # npm packages keep everything in a top-level package/ folder.
  tar -xzf "$file" -C "$dir" --strip-components 1 || die "couldn't unpack $name $version."
}

copy() {
  [[ -f $1 ]] || die "$1 is missing."
  mkdir -p "$(dirname -- "$2")" || die "couldn't create $(dirname -- "$2")."
  cp -- "$1" "$2" || die "couldn't copy $1 to $2."
}

katex=$work/katex
unpack katex "$katex"
copy "$katex/dist/katex.min.js" "$out/katex/katex.min.js"
copy "$katex/dist/katex.min.css" "$out/katex/katex.min.css"
copy "$katex/LICENSE" "$out/katex/LICENSE"
# All formats, unmodified: the stylesheet lists each one, and the fonts'
# license (OFL) covers them as they are.
for file in "$katex"/dist/fonts/KaTeX_*; do
  copy "$file" "$out/katex/fonts/${file##*/}"
done
copy "$here/licenses/katex-fonts-OFL.txt" "$out/katex/fonts/OFL.txt"

mermaid=$work/mermaid
unpack mermaid "$mermaid"
copy "$mermaid/dist/mermaid.min.js" "$out/mermaid/mermaid.min.js"
copy "$mermaid/LICENSE" "$out/mermaid/LICENSE"
copy "$here/licenses/mermaid-bundled.txt" "$out/mermaid/BUNDLED-LICENSES.txt"

highlight=$work/highlight
unpack @highlightjs/cdn-assets "$highlight"
copy "$highlight/highlight.min.js" "$out/highlight/highlight.min.js"
copy "$highlight/LICENSE" "$out/highlight/LICENSE"
while IFS= read -r name; do
  copy "$highlight/languages/$name.min.js" "$out/highlight/languages/$name.min.js"
done <<< "$grammars"

# The emoji table is an ES module, which browsers won't load from a file://
# page, so it becomes a plain script that sets a global.
emoji=$work/emoji
unpack markdown-it-emoji "$emoji"
copy "$emoji/LICENSE" "$out/emoji/LICENSE"
awk '
  /^export default \{/ { sub(/^export default /, "window.markdownPreviewEmoji = "); found++ }
  { print }
  END { if (found != 1) exit 1 }
' "$emoji/lib/data/full.mjs" > "$out/emoji/emoji.js" || die "the emoji table's format changed."

{
  printf '%s\n\n' "$pins"
  (cd "$out" && find . -type f ! -name manifest.txt | sed 's|^\./||' | LC_ALL=C sort |
    tr '\n' '\0' | xargs -0 shasum -a 256) || die "couldn't list the files in $out."
} > "$out/manifest.txt"

# Swap the new folder in.
mkdir -p "$(dirname -- "$dest")"
if [[ -e $dest ]]; then
  mv "$dest" "$dest.old"
fi
mv "$out" "$dest"
rm -rf "$dest.old"
printf 'Libraries written to %s (%s files)\n' "$dest" "$(sed '1,/^$/d' "$dest/manifest.txt" | wc -l | tr -d ' ')"
