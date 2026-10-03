#!/bin/bash
#
# Markdown Preview for CotEditor: install, update, uninstall and check it.
# https://github.com/mlmeehan/coteditor-markdown-preview
#
# Install or update with one line in Terminal:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mlmeehan/coteditor-markdown-preview/main/install.sh)"
#
# Options go after " -- ", for example to uninstall:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mlmeehan/coteditor-markdown-preview/main/install.sh)" -- --uninstall
#
# Run with --help to see every option.
#
# The installer lists the files it installs in _markdown-preview/.installed,
# and updates and --uninstall only ever replace or remove those. If you edited
# the installed script, or something else has its name, that file is moved to
# _markdown-preview/backup/ first. Copies of the script you made under other
# names are left alone.
#
# Copyright (c) 2026 Michael Meehan. Released under the MIT License.

set -eu -o pipefail

readonly REPO="mlmeehan/coteditor-markdown-preview"
readonly MENU_NAME="Markdown Preview"
readonly SUPPORT_NAME="_markdown-preview"
readonly ARCHIVE="coteditor-markdown-preview.tar.gz"
readonly DEFAULT_SHORTCUT="@M"
readonly NOTICES="LICENSE THIRD-PARTY-NOTICES.md"
readonly INSTALL_URL="https://raw.githubusercontent.com/$REPO/main/install.sh"
# Every copy of the preview script contains this, which is how copies are
# recognized.
readonly MARKER="github.com/$REPO"
# CotEditor doesn't run scripts with your shell's PATH, so the preview script
# finds cmark-gfm only in these folders.
readonly CMARK_DIRS="/opt/homebrew/bin /usr/local/bin /opt/local/bin"

scripts_dir="${MARKDOWN_PREVIEW_SCRIPTS_DIR:-$HOME/Library/Application Scripts/com.coteditor.CotEditor}"
scripts_dir=${scripts_dir%/}
support_dir="$scripts_dir/$SUPPORT_NAME"
manifest="$support_dir/.installed"

# --- Output ------------------------------------------------------------------------

if [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
  bold=$'\033[1m' dim=$'\033[2m' red=$'\033[31m' green=$'\033[32m' yellow=$'\033[33m' plain=$'\033[0m'
else
  bold="" dim="" red="" green="" yellow="" plain=""
fi

heading() { printf '\n%s%s%s\n' "$bold" "$*" "$plain"; }
ok() { printf '  %s✓%s %s\n' "$green" "$plain" "$*"; }
note() { printf '  %s·%s %s\n' "$dim" "$plain" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$plain" "$*"; }
bad() { printf '  %s✗%s %s\n' "$red" "$plain" "$*"; }
die() {
  printf '\n%sError:%s %s\n' "$red" "$plain" "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Markdown Preview for CotEditor installer

Usage: install.sh [options]

  (no options)      Install, or update to the latest release.
  --shortcut KEYS   Keyboard shortcut in CotEditor's notation: modifier symbols
                    followed by one letter. ^ is Control, ~ Option, \$ Shift and
                    @ Command; an uppercase letter adds Shift. The default is
                    @M (Command-Shift-M). Use "none" for no shortcut. Updates
                    keep the shortcut you chose before.
  --version TAG     Install a specific release, such as v1.0.0.
  --no-deps         Don't install cmark-gfm with Homebrew.
  --uninstall       Remove Markdown Preview. A config or custom.css you
                    changed is kept.
  --doctor          Check the installation and print a report you can paste
                    into a bug report.
  --from DIR        Install from a local folder, such as the src folder of a
                    clone of the repository.
  -h, --help        Show this help.

Updates and --uninstall replace or remove only files the installer put there.
If you edited the installed script, or something else has its name, that file
is moved to $SUPPORT_NAME/backup/ in CotEditor's Scripts folder first. Copies
of the script you made under other names are left alone.

Pass options after " -- " when using the one-line installer:
  /bin/bash -c "\$(curl -fsSL $INSTALL_URL)" -- --doctor
EOF
}

# --- Helpers -----------------------------------------------------------------------

require_macos() {
  [[ $(uname -s) == Darwin ]] || die "Markdown Preview is a CotEditor script, and CotEditor runs on macOS."
  if [[ $(id -u) -eq 0 ]]; then
    die "Please run this without sudo. It installs into your own Library folder."
  fi
}

# Prints cmark-gfm's path if it's where the preview script will find it.
find_cmark_gfm() {
  local dir
  for dir in $CMARK_DIRS; do
    if [[ -x "$dir/cmark-gfm" ]]; then
      printf '%s\n' "$dir/cmark-gfm"
      return 0
    fi
  done
  return 1
}

cmark_version() {
  "$1" --version 2>/dev/null | awk 'NR == 1 { print $2 }'
}

# The command that lets CotEditor find a cmark-gfm installed somewhere else.
link_command() {
  printf 'sudo mkdir -p /usr/local/bin && sudo ln -s "%s" /usr/local/bin/cmark-gfm' "$1"
}

find_brew() {
  local candidate
  for candidate in "$(command -v brew 2>/dev/null || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -n $candidate && -x $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

find_coteditor() {
  local app found
  for app in /Applications/CotEditor.app "$HOME/Applications/CotEditor.app"; do
    if [[ -d $app ]]; then
      printf '%s\n' "$app"
      return 0
    fi
  done
  if command -v mdfind >/dev/null 2>&1; then
    found=$(mdfind "kMDItemCFBundleIdentifier == 'com.coteditor.CotEditor'" 2>/dev/null || true)
    app=${found%%$'\n'*}
    if [[ -n $app ]]; then
      printf '%s\n' "$app"
      return 0
    fi
  fi
  return 1
}

app_version() {
  defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null || true
}

script_version() {
  awk -F '"' '/^readonly VERSION=/ { print $2; exit }' "$1" 2>/dev/null || true
}

lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Quotes around a setting's value are optional: browser = "Google Chrome".
unquote() {
  local value=$1
  case $value in
    \"*\" | \'*\') value=${value:1:${#value}-2} ;;
  esac
  printf '%s' "$value"
}

# has_line LIST LINE: whether a list of lines contains LINE.
has_line() {
  [[ $'\n'$1 == *$'\n'"$2"$'\n'* ]]
}

# The names in a folder, separated by commas.
list_dir() {
  local file out=""
  shopt -s nullglob dotglob
  for file in "$1"/*; do
    out+="${out:+, }${file##*/}"
  done
  shopt -u nullglob dotglob
  printf '%s' "$out"
}

# Prints a file's SHA-256, or fails if no tool here can compute it. (macOS's
# shasum is a Perl script, which a customized Perl setup can break.)
sha256() {
  local sum="" pattern='^[0-9a-f]{64}$'
  sum=$(shasum -a 256 "$1" 2>/dev/null | awk '{ print $1 }') || true
  if ! [[ $sum =~ $pattern ]]; then
    sum=$(sha256sum "$1" 2>/dev/null | awk '{ print $1 }') || true
  fi
  if ! [[ $sum =~ $pattern ]]; then
    sum=$(openssl dgst -sha256 -r "$1" 2>/dev/null | awk '{ print $1 }') || true
  fi
  [[ $sum =~ $pattern ]] || return 1
  printf '%s\n' "$sum"
}

# --- Shortcuts ----------------------------------------------------------------------

# The shortcut part of a script file name: "Markdown Preview.@M.sh" -> "@M".
shortcut_of() {
  local name=${1##*/}
  name=${name%.*}
  if [[ $name == *.* ]]; then
    printf '%s' "${name##*.}"
  fi
}

valid_shortcut() {
  local pattern='^[$~@^]+[A-Za-z]$'
  [[ $1 =~ $pattern ]]
}

# One spelling per shortcut, so that "@M", "$@m" and "@$m" compare equal.
canonical_shortcut() {
  local keys=$1 key modifiers out="" symbol
  key=${keys: -1}
  modifiers=${keys%?}
  if [[ $key == [A-Z] ]]; then
    modifiers+='$'
    key=$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')
  fi
  for symbol in '^' '~' '$' '@'; do
    if [[ $modifiers == *"$symbol"* ]]; then
      out+=$symbol
    fi
  done
  printf '%s%s' "$out" "$key"
}

# "@M" -> "⇧⌘M", in the order macOS menus use.
describe_shortcut() {
  local canonical out="" key
  canonical=$(canonical_shortcut "$1")
  key=${canonical: -1}
  [[ $canonical == *'^'* ]] && out+="⌃"
  [[ $canonical == *'~'* ]] && out+="⌥"
  [[ $canonical == *'$'* ]] && out+="⇧"
  [[ $canonical == *'@'* ]] && out+="⌘"
  printf '%s%s' "$out" "$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"
}

# Other scripts that use the same shortcut; CotEditor runs only one of them.
shortcut_conflicts() {
  local ours=$1 keys=$2 wanted file other
  [[ -n $keys ]] || return 0
  wanted=$(canonical_shortcut "$keys")
  while IFS= read -r file; do
    [[ $file == "$ours" ]] && continue
    other=$(shortcut_of "$file")
    if [[ -n $other ]] && valid_shortcut "$other" && [[ $(canonical_shortcut "$other") == "$wanted" ]]; then
      printf '%s\n' "${file#"$scripts_dir"/}"
    fi
  done < <(find "$scripts_dir" -path "$support_dir" -prune -o -type f -print 2>/dev/null)
}

# --- Downloads ----------------------------------------------------------------------

work=""
staged=""

# Removes the download, and any temporary copies an interrupted install left.
cleanup() {
  local file
  while IFS= read -r file; do
    if [[ -n $file ]]; then
      rm -f "$file"
    fi
  done <<< "$staged"
  if [[ -n $work ]]; then
    rm -rf "$work"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fetch() {
  curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
    --retry 3 --connect-timeout 15 --output "$2" "$1"
}

# The tag of the latest release, from the address github.com sends
# /releases/latest to.
latest_tag() {
  local url
  url=$(curl --proto '=https' --tlsv1.2 --fail --silent --retry 3 --connect-timeout 15 \
    --output /dev/null --write-out '%{redirect_url}' "https://github.com/$REPO/releases/latest") || return 1
  case $url in
    https://github.com/*/releases/tag/?*) printf '%s\n' "${url##*/}" ;;
    *) return 1 ;;
  esac
}

# Downloads a release, checks it against its SHA256SUMS and unpacks it.
# Sets $payload to the unpacked folder.
download_release() {
  local tag=$1 base expected actual
  if [[ $tag == latest ]]; then
    # Find out which release that is first, so that both files come from the
    # same one even if a new release is published in between.
    tag=$(latest_tag) || tag="latest"
  fi
  if [[ $tag == latest ]]; then
    note "Downloading the latest release…"
    base="https://github.com/$REPO/releases/latest/download"
  else
    note "Downloading release $tag…"
    base="https://github.com/$REPO/releases/download/$tag"
  fi

  work=$(mktemp -d "${TMPDIR:-/tmp}/markdown-preview.XXXXXX")
  fetch "$base/$ARCHIVE" "$work/$ARCHIVE" ||
    die "Couldn't download $base/$ARCHIVE. Check your internet connection, or that release \"$tag\" exists."
  fetch "$base/SHA256SUMS" "$work/SHA256SUMS" ||
    die "Couldn't download the checksums for release \"$tag\"."

  expected=$(awk -v name="$ARCHIVE" '{ sub(/^\*/, "", $2) } $2 == name { print $1 }' "$work/SHA256SUMS")
  actual=$(sha256 "$work/$ARCHIVE") ||
    die "Couldn't compute the download's checksum: shasum, sha256sum and openssl all failed."
  if [[ -z $expected || $expected != "$actual" ]]; then
    die "The download didn't match its published checksum, so nothing was installed."
  fi

  mkdir "$work/unpacked"
  tar -xzf "$work/$ARCHIVE" -C "$work/unpacked"
  payload="$work/unpacked/coteditor-markdown-preview"
}

# --- What's installed ----------------------------------------------------------------

# The manifest, _markdown-preview/.installed, has a line for the menu script,
#   script<TAB>its file name<TAB>its SHA-256
# and one for each file the installer put in _markdown-preview:
#   file<TAB>its name
recorded_script=""
recorded_sum=""
recorded_files=""

read_manifest() {
  local kind name sum
  recorded_script="" recorded_sum="" recorded_files=""
  [[ -f $manifest ]] || return 0
  while IFS=$'\t' read -r kind name sum || [[ -n $kind ]]; do
    # Plain file names only, so nothing outside the two folders is touched,
    # and never your settings, styles or backups.
    case $name in
      "" | */* | . | .. | config | custom.css | backup | .installed) continue ;;
    esac
    case $kind in
      script)
        recorded_script=$name
        recorded_sum=$sum
        ;;
      file) recorded_files+="$name"$'\n' ;;
    esac
  done < "$manifest"
}

# Writes the new manifest under a temporary name.
stage_manifest() {
  local script=$1 sum=$2 files=$3 name
  staged+="$manifest.partial"$'\n'
  {
    printf '# Files installed by the Markdown Preview installer. Updates and\n'
    printf '# --uninstall replace or remove only these.\n'
    printf 'script\t%s\t%s\n' "$script" "$sum"
    while IFS= read -r name; do
      if [[ -n $name ]]; then
        printf 'file\t%s\n' "$name"
      fi
    done <<< "$files"
  } > "$manifest.partial" || die "Couldn't write $manifest.partial, so nothing was changed."
}

# Paths of every copy of the preview script in the Scripts folder.
marked_scripts() {
  local file
  [[ -d $scripts_dir ]] || return 0
  shopt -s nullglob
  for file in "$scripts_dir"/*.sh; do
    if [[ -f $file ]] && grep -q "$MARKER" "$file" 2>/dev/null; then
      printf '%s\n' "$file"
    fi
  done
  shopt -u nullglob
}

# Whether a file name is one the installer gives the script, possibly numbered
# to order the Script menu: "Markdown Preview.@M.sh", "01)Markdown Preview.sh".
standard_name() {
  local pattern='^([0-9]+\))?Markdown Preview(\.[$~@^]+[A-Za-z])?\.sh$'
  [[ $1 =~ $pattern ]]
}

current=""
current_state=""

# Finds the copy of the script the installer manages. Sets $current to its
# path, or to nothing, and $current_state to "unchanged", "edited" (since it
# was installed) or "unrecorded" (installed by hand).
locate_script() {
  local file
  current=""
  current_state=""
  if [[ -n $recorded_script ]]; then
    file="$scripts_dir/$recorded_script"
    if [[ -f $file && ! -L $file ]] && grep -q "$MARKER" "$file" 2>/dev/null; then
      current=$file
      if [[ -n $recorded_sum && $(sha256 "$file" || true) == "$recorded_sum" ]]; then
        current_state="unchanged"
      else
        current_state="edited"
      fi
      return 0
    fi
    # Renamed, for example to change its shortcut: recognize it by its content.
    if [[ -n $recorded_sum ]]; then
      while IFS= read -r file; do
        if [[ -n $file && ! -L $file ]] && [[ $(sha256 "$file" || true) == "$recorded_sum" ]]; then
          current=$file
          current_state="unchanged"
          return 0
        fi
      done <<< "$(marked_scripts)"
    fi
    return 0
  fi
  # No manifest: installed by hand, under the name the installer would use.
  while IFS= read -r file; do
    if [[ -n $file && ! -L $file ]] && standard_name "${file##*/}"; then
      current=$file
      current_state="unrecorded"
      return 0
    fi
  done <<< "$(marked_scripts)"
}

# Copies of the script other than the one at $1, which may be empty: ones you
# made yourself, such as an edited duplicate. The installer leaves them alone.
other_copies() {
  local file
  while IFS= read -r file; do
    if [[ -n $file ]] && ! [[ -n $1 && $file -ef $1 ]]; then
      printf '%s\n' "$file"
    fi
  done <<< "$(marked_scripts)"
}

# Moves a file into _markdown-preview/backup/, next to any earlier backups,
# and prints where it went. It runs in a command substitution, where set -e
# doesn't apply, so every step checks for itself.
back_up() {
  local file=$1 name dest n=2
  name=${file##*/}
  mkdir -p "$support_dir/backup" || return 1
  dest="$support_dir/backup/$name"
  while [[ -e $dest || -L $dest ]]; do
    dest="$support_dir/backup/${name%.sh} $n.sh"
    n=$((n + 1))
  done
  mv "$file" "$dest" || return 1
  printf '%s\n' "$SUPPORT_NAME/backup/${dest##*/}"
}

# Moves a script that's in the way to backup/ and says why. If it can't, it
# stops before anything is replaced.
set_aside() {
  local file=$1 why=$2 saved
  saved=$(back_up "$file") ||
    die "Couldn't move \"${file##*/}\" to $SUPPORT_NAME/backup/, so the installer stopped before replacing or removing it."
  case $why in
    edited) warn "\"${file##*/}\" was edited after it was installed, so it's been saved as $saved" ;;
    unrecorded) note "Saved the earlier \"${file##*/}\" as $saved, in case you had changed it" ;;
    *) warn "Moved \"${file##*/}\", which the installer didn't create, to $saved" ;;
  esac
}

# --- Install --------------------------------------------------------------------------

ensure_cmark_gfm() {
  local cmark elsewhere brew
  if cmark=$(find_cmark_gfm); then
    ok "cmark-gfm $(cmark_version "$cmark") is installed"
    return 0
  fi

  if elsewhere=$(command -v cmark-gfm 2>/dev/null); then
    warn "cmark-gfm is installed at $elsewhere, where CotEditor won't find it. Link it with:"
    note "$(link_command "$elsewhere")"
    return 0
  fi

  if [[ $install_deps -eq 1 ]] && brew=$(find_brew); then
    note "Installing cmark-gfm, GitHub's Markdown renderer, with Homebrew…"
    if "$brew" install cmark-gfm; then
      if cmark=$(find_cmark_gfm); then
        ok "Installed cmark-gfm"
      else
        elsewhere="$("$brew" --prefix)/bin/cmark-gfm"
        warn "Homebrew installed cmark-gfm at $elsewhere, where CotEditor won't find it. Link it with:"
        note "$(link_command "$elsewhere")"
      fi
      return 0
    fi
    warn "Homebrew couldn't install cmark-gfm. Try \"brew install cmark-gfm\" yourself."
    return 0
  fi

  warn "The preview needs cmark-gfm, GitHub's Markdown renderer, which isn't installed."
  if find_brew >/dev/null; then
    note "Install it with: brew install cmark-gfm"
  else
    note "Install Homebrew from https://brew.sh, then run: brew install cmark-gfm"
    note "With MacPorts instead: sudo port install cmark-gfm"
  fi
}

# Copies a file next to where it goes, under a temporary name.
stage() {
  staged+="$2"$'\n'
  cp "$1" "$2" || die "Couldn't copy ${1##*/}, so nothing was changed."
}

# Checks that the release, or the folder given with --from, has everything its
# own script needs, before anything is changed.
check_payload() {
  local name required
  [[ -f "$payload/$MENU_NAME.sh" ]] || die "$payload doesn't contain \"$MENU_NAME.sh\"."
  required=$(awk -F '"' '/^readonly REQUIRED_FILES=/ { print $2; exit }' "$payload/$MENU_NAME.sh")
  for name in ${required:-prepare.awk preview.css preview.js}; do
    [[ -f "$payload/$SUPPORT_NAME/$name" ]] ||
      die "$payload doesn't contain $SUPPORT_NAME/$name, so nothing was installed."
  done
  for name in $NOTICES; do
    [[ -f "$payload/$name" || -f "$payload/../$name" ]] ||
      die "$payload doesn't contain $name, so nothing was installed."
  done
}

do_install() {
  local app new_version new_sum target dest keys file name others conflicts
  local new_files="" updating=0 kept_config=0 replacing=0

  require_macos
  heading "Markdown Preview for CotEditor"

  if [[ -n $from ]]; then
    [[ -d $from ]] || die "No folder at $from."
    payload=$(cd "$from" && pwd)
  else
    download_release "$version"
  fi
  check_payload
  new_version=$(script_version "$payload/$MENU_NAME.sh")
  new_sum=$(sha256 "$payload/$MENU_NAME.sh") ||
    die "Couldn't compute checksums: shasum, sha256sum and openssl all failed. Nothing was changed."

  if app=$(find_coteditor); then
    ok "CotEditor $(app_version "$app") is installed"
  else
    warn "CotEditor isn't installed. Get it from the Mac App Store or with: brew install --cask coteditor"
  fi

  ensure_cmark_gfm

  if [[ -L $support_dir ]]; then
    die "$support_dir is a symbolic link, and installing would change the files it points to. Remove the link, then install again."
  fi

  read_manifest
  locate_script
  if [[ -n $current || -n $recorded_script ]]; then
    updating=1
  fi

  # Updates keep the name, and so the shortcut, unless --shortcut asks for a
  # different one.
  if [[ $shortcut == none ]]; then
    target="$MENU_NAME.sh"
  elif [[ -n $shortcut ]]; then
    target="$MENU_NAME.$shortcut.sh"
  elif [[ -n $current ]]; then
    target=${current##*/}
  else
    target="$MENU_NAME.$DEFAULT_SHORTCUT.sh"
  fi
  dest="$scripts_dir/$target"

  # First copy everything next to where it goes, under temporary names, so
  # that a failure part-way (a full disk, Ctrl-C) leaves things as they were.
  mkdir -p "$support_dir"
  for file in "$payload/$SUPPORT_NAME"/*; do
    name=${file##*/}
    case $name in
      # Your settings, styles and backups are never replaced.
      config | custom.css | backup | *.partial) continue ;;
    esac
    if [[ -f $file ]]; then
      stage "$file" "$support_dir/$name.partial"
      new_files+="$name"$'\n'
    fi
  done
  for name in $NOTICES; do
    for file in "$payload/$name" "$payload/../$name"; do
      if [[ -f $file ]]; then
        stage "$file" "$support_dir/$name.partial"
        new_files+="$name"$'\n'
        break
      fi
    done
  done
  # A name starting with a dot keeps the new script out of the Script menu
  # until it's ready.
  stage "$payload/$MENU_NAME.sh" "$scripts_dir/.$MENU_NAME.partial"
  chmod 755 "$scripts_dir/.$MENU_NAME.partial"
  stage_manifest "$target" "$new_sum" "$new_files"

  # Make room for the script. Whatever has its name goes to backup/ unless
  # it's the installer's own unchanged copy, and so does an edited copy under
  # an earlier name. If that fails, nothing has been replaced yet.
  if [[ -e $dest || -L $dest ]]; then
    if [[ -n $current ]] && [[ $dest -ef $current ]]; then
      if [[ $current_state == unchanged ]]; then
        replacing=1
      else
        set_aside "$dest" "$current_state"
      fi
      current=""
    else
      set_aside "$dest" other
    fi
  fi
  if [[ -n $current && $current_state != unchanged ]]; then
    set_aside "$current" "$current_state"
    current=""
  fi
  if [[ -e $dest || -L $dest ]] && [[ $replacing -eq 0 ]]; then
    die "\"$target\" is in the way, so nothing was replaced."
  fi

  # Then switch over. Renaming is instant, and the menu script goes last so
  # that it never appears without the files it needs.
  while IFS= read -r name; do
    if [[ -n $name ]]; then
      mv -f "$support_dir/$name.partial" "$support_dir/$name"
    fi
  done <<< "$new_files"
  if [[ -f "$support_dir/config" ]]; then
    kept_config=1
  elif [[ -f "$support_dir/config.example" ]]; then
    cp "$support_dir/config.example" "$support_dir/config"
  fi
  mv -f "$scripts_dir/.$MENU_NAME.partial" "$dest"
  mv -f "$manifest.partial" "$manifest"

  # The unchanged copy under its earlier name, after a change of shortcut.
  if [[ -n $current ]]; then
    rm -f "$current"
  fi

  # Files an earlier version had that this one doesn't.
  while IFS= read -r name; do
    if [[ -n $name ]] && ! has_line "$new_files" "$name"; then
      rm -f "$support_dir/$name"
    fi
  done <<< "$recorded_files"

  if command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$dest" "$support_dir" 2>/dev/null || true
  fi

  keys=$(shortcut_of "$target")
  if [[ $updating -eq 1 ]]; then
    ok "Updated Markdown Preview to ${new_version:-a new version}"
  else
    ok "Installed Markdown Preview ${new_version}"
  fi
  if [[ -n $keys ]] && valid_shortcut "$keys"; then
    ok "Shortcut: $(describe_shortcut "$keys")  (Script menu ▸ $MENU_NAME)"
  else
    ok "No shortcut. Run it from the Script menu ▸ $MENU_NAME"
    keys=""
  fi
  if [[ $kept_config -eq 1 ]]; then
    note "Kept your settings in $SUPPORT_NAME/config"
  fi

  others=$(other_copies "$dest")
  if [[ -n $others ]]; then
    while IFS= read -r file; do
      note "Left \"${file##*/}\" alone: it's a copy of Markdown Preview the installer didn't make"
    done <<< "$others"
  fi

  conflicts=$(shortcut_conflicts "$dest" "$keys")
  if [[ -n $conflicts ]]; then
    while IFS= read -r file; do
      warn "\"$file\" uses the same shortcut, and CotEditor runs only one of them. Rename or remove it."
    done <<< "$conflicts"
  fi

  printf '\nOpen a Markdown file in CotEditor and choose Script ▸ %s' "$MENU_NAME"
  if [[ -n $keys ]]; then
    printf ' or press %s' "$(describe_shortcut "$keys")"
  fi
  printf '.\nInstalled in: %s\n' "$scripts_dir"
}

# --- Uninstall --------------------------------------------------------------------------

do_uninstall() {
  local file name others removed=0

  require_macos
  heading "Removing Markdown Preview"

  # A link, for example to a copy of the repository: remove the link, never
  # what it points to.
  if [[ -L $support_dir ]]; then
    rm -f "$support_dir"
    ok "Removed the link $SUPPORT_NAME; the folder it pointed to is untouched"
    removed=1
  fi

  read_manifest
  locate_script
  if [[ -n $current ]]; then
    if [[ $current_state == unchanged ]]; then
      rm -f "$current"
    else
      set_aside "$current" "$current_state"
    fi
    ok "Removed \"${current##*/}\" from the Script menu"
    removed=1
  fi

  others=$(other_copies "")
  if [[ -n $others ]]; then
    while IFS= read -r file; do
      note "Left \"${file##*/}\" alone: it's a copy of Markdown Preview the installer didn't make"
    done <<< "$others"
  fi

  if [[ -d $support_dir ]]; then
    if [[ -f "$support_dir/config" && -f "$support_dir/config.example" ]] &&
      cmp -s "$support_dir/config" "$support_dir/config.example"; then
      rm -f "$support_dir/config"
    fi
    if [[ -f $manifest ]]; then
      while IFS= read -r name; do
        if [[ -n $name ]]; then
          rm -f "$support_dir/$name"
        fi
      done <<< "$recorded_files"
      rm -f "$manifest"
    else
      # Installed by hand: the files a release contains.
      for name in prepare.awk preview.css preview.js config.example $NOTICES; do
        rm -f "$support_dir/$name"
      done
    fi
    ok "Removed its support files"
    if ! rmdir "$support_dir" 2>/dev/null; then
      note "Kept what you changed or added, in $support_dir: $(list_dir "$support_dir")"
    fi
    removed=1
  fi

  if [[ $removed -eq 0 ]]; then
    note "Markdown Preview isn't installed in $scripts_dir"
  fi
  note "cmark-gfm stays installed. To remove it too: brew uninstall cmark-gfm"
}

# --- Doctor -------------------------------------------------------------------------------

problems=0

problem() {
  bad "$@"
  problems=$((problems + 1))
}

# Whether "open -a" would find an app with this name (or at this path). Looks
# it up without opening or revealing anything, and assumes it's there when it
# can't tell.
app_exists() {
  local found
  if [[ $1 == */* ]]; then
    [[ -d $1 ]]
    return
  fi
  [[ -x /usr/bin/osascript ]] || return 0
  found=$(/usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      ObjC.import("AppKit");
      const path = $.NSWorkspace.sharedWorkspace.fullPathForApplication(argv[0]);
      return path.isNil() ? "" : path.js;
    }' "$1" 2>/dev/null) || return 0
  [[ -n $found ]]
}

# Lists the settings and points out any the preview script would ignore.
check_settings() {
  local line key value shown=""
  local pattern='^[[:space:]]*([A-Za-z_]+)[[:space:]]*=[[:space:]]*(.*)$'

  if [[ ! -f "$support_dir/config" ]]; then
    note "Settings: defaults (there's no config file)"
    return 0
  fi
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    if [[ -z ${line//[[:space:]]/} ]]; then
      continue
    fi
    if ! [[ $line =~ $pattern ]]; then
      warn "Settings: ignoring \"$line\", which isn't \"name = value\""
      continue
    fi
    key=$(lowercase "${BASH_REMATCH[1]}")
    value=${BASH_REMATCH[2]}
    value=${value%"${value##*[![:space:]]}"}
    value=$(unquote "$value")
    shown+="${shown:+; }$key = $value"
    case $key in
      browser)
        if [[ -n $value ]] && ! app_exists "$value"; then
          problem "Settings: there's no app called \"$value\". Use the name the browser has in your Applications folder, without \".app\"."
        fi
        ;;
      theme)
        case $(lowercase "$value") in
          auto | light | dark) ;;
          *) warn "Settings: theme can be auto, light or dark, so \"$value\" is treated as auto" ;;
        esac
        ;;
      remote_libraries)
        case $(lowercase "$value") in
          on | off | yes | no | true | false | 1 | 0) ;;
          *) warn "Settings: remote_libraries can be on or off, so \"$value\" is treated as on" ;;
        esac
        ;;
      *)
        warn "Settings: there's no setting called \"$key\". The settings are browser, theme and remote_libraries."
        ;;
    esac
  done < "$support_dir/config"
  note "Settings: ${shown:-defaults}"
}

do_doctor() {
  local app cmark="" elsewhere brew name keys conflicts file output latest others files
  local installed_version="" sample status

  heading "Markdown Preview doctor"

  if command -v sw_vers >/dev/null 2>&1; then
    ok "macOS $(sw_vers -productVersion)"
  else
    note "System: $(uname -sr)"
  fi

  if app=$(find_coteditor); then
    ok "CotEditor $(app_version "$app") at $app"
  else
    problem "CotEditor not found"
  fi

  if [[ -d $scripts_dir ]]; then
    ok "Scripts folder: $scripts_dir"
  else
    problem "Scripts folder is missing: $scripts_dir"
  fi
  if [[ -L $support_dir ]]; then
    note "$SUPPORT_NAME is a link to $(readlink "$support_dir")"
  fi

  read_manifest
  locate_script
  if [[ -z $current ]]; then
    problem "Markdown Preview isn't installed"
  else
    name=${current##*/}
    installed_version=$(script_version "$current")
    keys=$(shortcut_of "$name")
    if [[ -n $keys ]] && valid_shortcut "$keys"; then
      ok "Installed: \"$name\", version $installed_version, shortcut $(describe_shortcut "$keys")"
    else
      ok "Installed: \"$name\", version $installed_version, no shortcut"
      keys=""
    fi
    case $current_state in
      edited) note "It was edited after it was installed. Updating saves your copy in $SUPPORT_NAME/backup/." ;;
      unrecorded) note "It was installed by hand." ;;
    esac
    if [[ ! -x $current ]]; then
      problem "The script isn't executable. Fix: chmod +x \"$current\""
    fi
    if command -v xattr >/dev/null 2>&1 && xattr -p com.apple.quarantine "$current" >/dev/null 2>&1; then
      problem "The script is quarantined. Fix: xattr -d com.apple.quarantine \"$current\""
    fi
    conflicts=$(shortcut_conflicts "$current" "$keys")
    if [[ -n $conflicts ]]; then
      while IFS= read -r file; do
        warn "\"$file\" uses the same shortcut; CotEditor runs only one of them"
      done <<< "$conflicts"
    fi
  fi
  others=$(other_copies "$current")
  if [[ -n $others ]]; then
    while IFS= read -r file; do
      note "Also in the Scripts folder: \"${file##*/}\", a copy of Markdown Preview the installer didn't make"
    done <<< "$others"
  fi

  files=$recorded_files
  if [[ -z $files ]]; then
    files=$'prepare.awk\npreview.css\npreview.js\n'
  fi
  while IFS= read -r name; do
    if [[ -n $name && ! -f "$support_dir/$name" ]]; then
      problem "Missing support file: $SUPPORT_NAME/$name"
    fi
  done <<< "$files"

  check_settings
  if [[ -f "$support_dir/custom.css" ]]; then
    note "custom.css is in use"
  fi

  if cmark=$(find_cmark_gfm); then
    ok "cmark-gfm: $cmark ($(cmark_version "$cmark"))"
  elif elsewhere=$(command -v cmark-gfm 2>/dev/null); then
    problem "cmark-gfm is at $elsewhere, where CotEditor won't find it. Fix: $(link_command "$elsewhere")"
  else
    problem "cmark-gfm isn't installed. Fix: brew install cmark-gfm"
  fi

  if brew=$(find_brew); then
    note "Homebrew: $brew"
  else
    note "Homebrew isn't installed"
  fi

  if curl -fsS --max-time 8 -o /dev/null https://cdn.jsdelivr.net/npm/katex@0.18.9/dist/katex.min.js 2>/dev/null; then
    ok "cdn.jsdelivr.net is reachable (diagrams, math and highlighting)"
  else
    warn "cdn.jsdelivr.net isn't reachable, so diagrams, math and highlighting show as source text"
  fi

  if [[ -n $current && -n $cmark ]]; then
    sample="${TMPDIR:-/tmp}/markdown-preview-doctor.md"
    # shellcheck disable=SC2016  # literal Markdown math
    printf '# Doctor\n\nInline $x^2$ and a table:\n\n| a | b |\n|---|---|\n| 1 | 2 |\n' > "$sample"
    # Run it the way CotEditor does: without your shell's PATH or settings.
    # shellcheck disable=SC2094  # the script only reads the sample
    if output=$(env -i HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      MARKDOWN_PREVIEW_NO_OPEN=1 "$current" "$sample" < "$sample" 2>&1); then
      ok "Test preview: ${output%%$'\n'*}"
      note "${output#*$'\n'}"
    else
      problem "Test preview failed:"
      printf '%s\n' "$output" | sed 's/^/      /'
    fi
    rm -f "$sample"
  fi

  if latest=$(latest_tag) && [[ -n $installed_version ]]; then
    if [[ ${latest#v} == "$installed_version" ]]; then
      ok "Up to date ($latest)"
    else
      warn "Version $latest is available. Update with: /bin/bash -c \"\$(curl -fsSL $INSTALL_URL)\""
    fi
  fi

  if [[ $problems -eq 0 ]]; then
    status="No problems found."
  else
    status="$problems problem(s) found."
  fi
  printf '\n%s\n' "$status"
  [[ $problems -eq 0 ]]
}

# --- Main -----------------------------------------------------------------------------------

action="install"
shortcut=""
version="latest"
install_deps=1
from=""
payload=""

# Options for the one-line installer go after " -- ". Without it, bash takes
# the first option as the script's name ($0), so put it back.
case $0 in
  --) ;;
  -*) set -- "$0" "$@" ;;
esac

while [[ $# -gt 0 ]]; do
  case $1 in
    --shortcut)
      [[ $# -ge 2 ]] || die "--shortcut needs a value, such as @M."
      shortcut=$2
      shift 2
      ;;
    --shortcut=*)
      shortcut=${1#*=}
      shift
      ;;
    --version)
      [[ $# -ge 2 ]] || die "--version needs a release tag, such as v1.0.0."
      version=$2
      shift 2
      ;;
    --version=*)
      version=${1#*=}
      shift
      ;;
    --no-deps)
      install_deps=0
      shift
      ;;
    --uninstall)
      action="uninstall"
      shift
      ;;
    --doctor)
      action="doctor"
      shift
      ;;
    --from)
      [[ $# -ge 2 ]] || die "--from needs a folder."
      from=$2
      shift 2
      ;;
    --from=*)
      from=${1#*=}
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      ;;
    *)
      die "Unknown option \"$1\". Run with --help to see the options."
      ;;
  esac
done

if [[ -n $shortcut && $shortcut != none ]] && ! valid_shortcut "$shortcut"; then
  die "\"$shortcut\" isn't a CotEditor shortcut. Use modifier symbols (^ ~ \$ @) followed by one letter, such as @M."
fi
if [[ $version != latest && $version != v* ]]; then
  version="v$version"
fi

case $action in
  install) do_install ;;
  uninstall) do_uninstall ;;
  doctor) do_doctor ;;
esac
