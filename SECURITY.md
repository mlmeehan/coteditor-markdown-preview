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
