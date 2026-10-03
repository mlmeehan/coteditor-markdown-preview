# Security policy

## Reporting a vulnerability

Please report security problems privately through GitHub: open the
[Security tab](https://github.com/mlmeehan/coteditor-markdown-preview/security)
and choose **Report a vulnerability**. You'll get a reply within a week. If
that button isn't there, open an issue asking for a private way to get in
touch, without any details of the problem. Please don't describe security
problems in public issues.

Only the latest release receives fixes.

## What the preview does

So you can judge the risks:

- The script reads the document CotEditor passes it, converts it on your Mac
  and writes one HTML file to your temporary folder
  (`$TMPDIR/coteditor-markdown-preview/`), next to a copy of the libraries
  below. It refuses that folder if it's a link or isn't yours. It never
  uploads anything.
- Mermaid, KaTeX, highlight.js and an emoji list are installed with the
  script, in `_markdown-preview/lib`, and the page loads them from there; it
  contacts no server of its own. Their pinned versions are downloaded from
  npm when a release is built and checked against the packages' integrity
  hashes. The installer checks the release against its SHA-256 checksum and
  each library file against the SHA-256 listed in `lib/manifest.txt`, and the
  doctor checks them again.
- Images and other files a document links to on the web load as they would in
  any browser.
- Raw HTML in documents is rendered, but the page's Content Security Policy
  only lets the preview's own script, and the libraries it loads, run.
  Scripts, script links and event handlers written into a document are
  blocked.
- The one-line command runs the `install.sh` attached to the latest release,
  not the one on the main branch; its hash is in that release's
  `SHA256SUMS` if you want to check it before running it. The installer
  downloads releases over HTTPS from GitHub and checks them against the
  release's `SHA256SUMS`. It puts its files only in CotEditor's
  Scripts folder in your Library, and only replaces or removes files it
  installed itself. Unless you pass `--no-deps`, it also installs cmark-gfm
  with Homebrew. It never uses `sudo`.

## Verifying the installer

The one-line install command runs the installer straight from the download.
To read it first, or check it against the release's checksum, download it
and its `SHA256SUMS` instead:

```sh
cd "$(mktemp -d)"
curl -fsSLO https://github.com/mlmeehan/coteditor-markdown-preview/releases/latest/download/install.sh
curl -fsSLO https://github.com/mlmeehan/coteditor-markdown-preview/releases/latest/download/SHA256SUMS
grep ' install.sh$' SHA256SUMS | shasum -a 256 -c
less install.sh
/bin/bash install.sh
```

`shasum` prints `install.sh: OK` when the file matches. Options go after the
file name, as in `/bin/bash install.sh --doctor`. For a manual install, check
the archive the same way: download `coteditor-markdown-preview.tar.gz` too and
run `grep ' coteditor-markdown-preview.tar.gz$' SHA256SUMS | shasum -a 256 -c`.

The checksums are published in the same release as the files, so they show
that a download arrived complete and unchanged, but not who made it. For that,
each release's `install.sh` and archive have a signed
[build provenance attestation](https://docs.github.com/en/actions/concepts/security/artifact-attestations),
which records that this repository's release workflow built them from the
tagged commit. With the [GitHub CLI](https://cli.github.com) installed, check a
downloaded file with:

```sh
gh attestation verify install.sh --repo mlmeehan/coteditor-markdown-preview \
  --signer-workflow mlmeehan/coteditor-markdown-preview/.github/workflows/release.yml
```

It prints `✓ Verification succeeded!` and the workflow and tag that built
the file.
The release workflow runs the same check before marking a release as the
latest.
