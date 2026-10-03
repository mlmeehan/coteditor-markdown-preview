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
  (`$TMPDIR/coteditor-markdown-preview/`). It never uploads anything.
- The page loads Mermaid, KaTeX, highlight.js and an emoji list from
  cdn.jsdelivr.net when a document needs them. Every script and stylesheet is
  pinned to an exact version and checked with Subresource Integrity, so a
  modified file is refused; the fonts KaTeX's stylesheet loads come from the
  same pinned version. `remote_libraries = off` in the settings stops loading
  them.
- Images and other files a document links to on the web load as they would in
  any browser, whatever the settings.
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
