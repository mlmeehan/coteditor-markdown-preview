# Syntax reference

Markdown Preview renders [GitHub Flavored Markdown](https://github.github.com/gfm/) with [cmark-gfm](https://github.com/github/cmark-gfm), the parser GitHub uses, and adds diagrams, math, highlighting, alerts and emoji in the page. This page covers the details, and the [differences from GitHub](#differences-from-github) at the end. To see it all at once, preview [`examples/feature-tour.md`](../examples/feature-tour.md).

- [Markdown](#markdown)
- [Table of contents](#table-of-contents)
- [Alerts and callouts](#alerts-and-callouts)
- [Code](#code)
- [Math](#math)
- [Diagrams](#diagrams)
- [Emoji](#emoji)
- [Front matter](#front-matter)
- [Images](#images)
- [Raw HTML](#raw-html)
- [Differences from GitHub](#differences-from-github)

## Markdown

Everything in the GFM spec works: tables, task lists, strikethrough, autolinks (`https://…` and `www.…`) and footnotes (`Text[^1]` … `[^1]: The note.`).

Headings get a `#` link that appears on hover, and their ids follow GitHub's rules, so `[link](#some-heading)` works the same here and on GitHub. Relative links and images resolve against the document's folder; a document you haven't saved yet has no folder, so save it first.

## Table of contents

Put `[TOC]` on a line of its own (`[[TOC]]` and `[[_TOC_]]` work too, in any case). It becomes a nested list of links to the headings. When the document has exactly one level-1 heading, that title is left out of the list.

## Alerts and callouts

GitHub's five alerts:

```markdown
> [!NOTE]
> Useful information that readers should know, even when skimming.
```

`NOTE`, `TIP`, `IMPORTANT`, `WARNING` and `CAUTION`, in any case.

[Obsidian callouts](https://help.obsidian.md/Editing+and+formatting/Callouts) work too. Text after the marker becomes the title, and each type takes the color and icon of one of the five:

| Shown as | Callout types |
| --- | --- |
| Note | `note`, `info`, `todo`, `abstract`, `summary`, `tldr` |
| Tip | `tip`, `hint`, `success`, `check`, `done` |
| Important | `important`, `question`, `help`, `faq`, `example`, `quote`, `cite` |
| Warning | `warning`, `attention` |
| Caution | `caution`, `danger`, `error`, `failure`, `fail`, `missing`, `bug` |

```markdown
> [!bug] Crashes on launch
> Only when the window is restored.
```

Obsidian's fold markers (`[!note]-` and `[!note]+`) are accepted, but the callout is always shown open. Without a title, the type's own name is used (`Bug`).

## Code

Fenced code blocks with a language are highlighted with [highlight.js](https://highlightjs.org), which knows about 60 languages and their usual short names (`js`, `py`, `sh`, `ps1`, `tex`, …). Each block shows its language as a label and has a copy button.

A block without a language, with an unknown one, or marked `text`, `txt`, `plain`, `plaintext` or `none` stays plain text. Indented code blocks are never highlighted.

## Math

Math is rendered with [KaTeX](https://katex.org). See its [list of supported functions](https://katex.org/docs/supported).

| Write | For |
| --- | --- |
| `$x^2$` or `` $`x^2`$ `` | inline math |
| `$$x^2$$`, on one line or across several | display math |
| a ` ```math ` code block | display math |

Like [pandoc](https://pandoc.org/MANUAL.html#math), a `$` only starts inline math when the next character isn't a space, and only ends it when the previous character isn't a space and the next isn't a digit. So `$5 and $10` stays text. Write `\$` for a dollar sign that should never start math. Math inside code spans and code blocks is left alone.

Display math across several lines can't contain a blank line, and works inside block quotes and lists. A formula KaTeX can't parse is shown in red with the error as its tooltip.

## Diagrams

A ` ```mermaid ` code block becomes a [Mermaid](https://mermaid.js.org) diagram: flowcharts, sequence, class, state, entity-relationship and Gantt diagrams, pie charts, mind maps, timelines and [the rest](https://mermaid.js.org/intro/). Diagrams use Mermaid's dark theme in dark mode.

A diagram with a mistake shows Mermaid's error message above its source, and the rest of the page still renders.

## Emoji

Shortcodes such as `:rocket:`, `:tada:` and `:+1:` become emoji, using the same names as GitHub. Shortcodes inside code stay as typed. GitHub's own images, such as `:octocat:` and `:shipit:`, aren't emoji and stay as text.

## Front matter

YAML front matter (between `---` lines) or TOML front matter (between `+++` lines) at the very top of the file is shown as a collapsed *Front matter* block, instead of a horizontal rule and stray text.

## Images

An image that sits on a line of its own and is at least 200 pixels wide is centered, like a figure. Smaller images, badges and images inside text stay inline. Images on the web load as they would in any browser.

## Raw HTML

HTML in the document is rendered as written: `<details>`, `<kbd>`, `<sub>`, `<sup>`, `<mark>`, `<img width="…">`, `<picture>` and so on. Scripts are the exception; the page's [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP) blocks them, including event handlers such as `onclick`.

## Differences from GitHub

The parser is the same, so ordinary Markdown renders the same way. The differences are in what happens around it.

**Things that work here but not on GitHub**

- `[TOC]` and Obsidian callouts. GitHub shows them as plain text and a plain block quote.
- HTML GitHub removes: `<style>`, `<iframe>`, `<textarea>`, `style="…"` and `class="…"` attributes and other markup GitHub's sanitizer strips. A document that relies on them will look different on GitHub.

**Things GitHub does that this doesn't**

- References to people, issues, pull requests and commits (`@name`, `#123`, `org/repo#123`, commit hashes) stay plain text, because a file on your Mac belongs to no repository.
- ` ```geojson `, ` ```topojson ` and ` ```stl ` blocks aren't turned into maps or 3D models; they're shown as code.
- GitHub's custom emoji, such as `:octocat:`, stay as text.
- Front matter is a collapsed block, not a table.
- Relative links point at files next to the document, not at pages in a repository.

**Things that are close but not identical**

- Math: GitHub renders it with MathJax, this with KaTeX. Common LaTeX looks the same, but a few commands exist in only one of them.
- Diagrams: GitHub and this use different Mermaid versions, so the newest diagram types or options may work in one before the other.
- Heading ids are the same, but GitHub adds a `user-content-` prefix to the ids in the page, so a script or stylesheet that targets them by id won't carry over. Links like `#some-heading` work in both.
- Styles: the page follows GitHub's look, but it isn't GitHub's stylesheet, so spacing and fonts can differ slightly.

**How previewing works**

- The preview is a snapshot of the document when you pressed ⇧⌘M. It doesn't update as you type and doesn't follow your scroll position; preview again to see changes.
- It shows what's in CotEditor, saved or not.
