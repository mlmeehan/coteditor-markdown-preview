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
- A settings file for the browser, the appearance and loading libraries from
  the internet, and `custom.css` for your own styles.
- A Content Security Policy that blocks scripts inside previewed documents.
- A one-line installer that verifies downloads against their checksums and
  can update, change the shortcut, uninstall and diagnose problems. It only
  replaces or removes files it installed, and moves anything else in its way
  to a backup folder.

[Unreleased]: https://github.com/mlmeehan/coteditor-markdown-preview/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/mlmeehan/coteditor-markdown-preview/releases/tag/v1.0.0
