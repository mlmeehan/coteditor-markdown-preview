# Contributing

Thanks for helping! Bug reports, rendering fixes, new languages and clearer
docs are all welcome. For anything bigger than a small fix, please open an
issue first so we can agree on the approach.

## How the project is laid out

| Path | What it is |
| --- | --- |
| `src/Markdown Preview.sh` | The script CotEditor runs. Installed as `Markdown Preview.@M.sh`. |
| `src/_markdown-preview/prepare.awk` | Runs before cmark-gfm: folds front matter and protects math from Markdown. |
| `src/_markdown-preview/preview.css` | The page's look, in light and dark. |
| `src/_markdown-preview/preview.js` | Diagrams, math, highlighting, alerts, emoji, anchors and the table of contents. Pinned library versions and hashes are at the top. |
| `src/_markdown-preview/config.example` | The settings file template. |
| `install.sh` | The installer, updater, uninstaller and doctor. |
| `examples/feature-tour.md` | A document that uses every feature. |
| `tests/` | Tests; see below. |

## Ground rules

- **Run on a stock Mac.** The script must work with macOS's own `/bin/bash`
  (version 3.2) and `/usr/bin/awk` (the BWK "one true awk"). That rules out
  bash 4 features such as associative arrays, `${var,,}` and `mapfile`, and
  gawk extensions such as `gensub` or `match()` with an array.
- **No new dependencies.** cmark-gfm is the only thing users install. Browser
  libraries come from jsDelivr, pinned to exact versions with Subresource
  Integrity hashes, and load only when a document needs them.
- **Keep it quiet when it works.** CotEditor treats anything the script writes
  to standard error as an error, so print nothing there on success.

## Running the tests

On a Mac, with [Homebrew](https://brew.sh):

```sh
brew install cmark-gfm shellcheck

shellcheck "src/Markdown Preview.sh" install.sh tests/*.sh
tests/test-prepare.sh     # prepare.awk, against tests/prepare-cases.txt
tests/test-script.sh      # the preview script, run the way CotEditor runs it
tests/test-installer.sh   # the installer, in a temporary folder
tests/check-sri.sh        # pinned libraries still match jsDelivr (needs network)
```

`test-installer.sh` never touches your real Scripts folder, and needs macOS.
`test-prepare.sh` and `test-script.sh` also run on Linux with bash 5 and gawk
or mawk (`AWK=mawk tests/test-prepare.sh`), but CI runs everything on macOS
because that's what matters.

The browser tests render the feature tour in Chromium and WebKit, Safari's
engine, and save screenshots to `tests/browser/screenshots/`:

```sh
cd tests/browser
npm ci
npx playwright install chromium webkit
npm test
```

### Adding a prepare.awk test

Add a case to `tests/prepare-cases.txt`: a `%%% name` line, the Markdown, a
`%%% expect` line, then the expected output.

## Trying your changes in CotEditor

Install your working copy over the released version:

```sh
./install.sh --from src --no-deps
```

Run the one-line installer again to go back to the latest release.

## Updating a library

Libraries are pinned in `LIBRARIES` and `GRAMMARS` at the top of
`src/_markdown-preview/preview.js`. To move to a new version, change the
version in the URL and replace its hash with:

```sh
curl -sL URL | openssl dgst -sha384 -binary | openssl base64 -A
```

Then run `tests/check-sri.sh` and the browser tests. Mermaid stays on 11.x for
now: 12.0 changed the default layout and theme, so diagrams would look
different from most other renderers.

To support another highlight.js language, add its file from
`@highlightjs/cdn-assets/languages/` to `GRAMMARS` with its hash, and any
aliases people use for it to `GRAMMAR_ALIASES`.

## Releasing

1. Update `VERSION` in `src/Markdown Preview.sh`.
2. Move the "Unreleased" notes in `CHANGELOG.md` under a new version heading
   and update the links at the bottom.
3. Commit, then tag and push both:
   `git tag v1.2.3 && git push --atomic origin main v1.2.3`.

The Release workflow checks the tag against `VERSION`, runs the tests and
publishes `coteditor-markdown-preview.tar.gz`, `install.sh` and `SHA256SUMS`
as a pre-release. It installs that with the one-line command on a fresh Mac,
and only if that works marks it as the latest release, which is the one the
installer downloads.
