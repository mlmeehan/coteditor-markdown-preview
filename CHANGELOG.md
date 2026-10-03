# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-10-03

The first public release.

### Added

- Preview the frontmost document from CotEditor's Script menu, with the
  shortcut ⇧⌘M, rendered by cmark-gfm: GitHub Flavored Markdown tables, task
  lists, strikethrough and autolinks, plus footnotes.
- Mermaid diagrams; KaTeX math written as `$…$`, `$$…$$`, `` $`…`$ `` or
  ` ```math `; syntax highlighting for about 60 languages; GitHub alerts and
  Obsidian callouts; emoji shortcodes; YAML and TOML front matter; heading
  anchors that match GitHub's; and `[TOC]`.
- Light and dark appearance, print styles, and copy buttons on code blocks.
- Previews work without an internet connection: Mermaid, KaTeX and its fonts,
  highlight.js and the emoji list are installed with Markdown Preview.
- A settings file for the browser and the appearance, and `custom.css` for
  your own styles.
- A one-line installer that verifies downloads against their checksums and
  can update, change the shortcut, uninstall and diagnose problems. It only
  replaces or removes files it installed, and moves anything else in its way
  to a backup folder.

### Security

- A Content Security Policy that blocks scripts inside previewed documents.
- The preview refuses to write to a temporary folder that's a link or belongs
  to someone else, since the page runs the libraries copied there.
- The installer and the doctor check every library file against its SHA-256.
- Signed build provenance attestations for `install.sh` and the release
  archive, which `gh attestation verify` checks.

[Unreleased]: https://github.com/mlmeehan/coteditor-markdown-preview/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/mlmeehan/coteditor-markdown-preview/releases/tag/v1.0.0
