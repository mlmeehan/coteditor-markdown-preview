# Third-party notices

## Included in this project

`src/_markdown-preview/preview.js` contains icon outlines from
[Primer Octicons](https://github.com/primer/octicons) (info, light-bulb,
report, alert, stop, copy and check), used under the MIT License:

```text
MIT License

Copyright (c) 2026 GitHub Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Browser libraries included in releases

Releases include these libraries in `_markdown-preview/lib`, unmodified except
as noted, so previews work offline. Each folder holds the library's license
file, which applies to the files in it.

| Project | Version | Used for | License | License file |
| --- | --- | --- | --- | --- |
| [KaTeX](https://katex.org) | 0.18.9 | Math | MIT | `lib/katex/LICENSE` |
| KaTeX fonts | 0.18.9 | Math | SIL Open Font License 1.1 | `lib/katex/fonts/OFL.txt` |
| [Mermaid](https://mermaid.js.org) | 11.17.2 | Diagrams | MIT | `lib/mermaid/LICENSE` |
| [highlight.js](https://highlightjs.org) | 11.12.0 | Syntax highlighting | BSD-3-Clause | `lib/highlight/LICENSE` |
| [markdown-it-emoji](https://github.com/markdown-it/markdown-it-emoji) | 3.1.0 | The emoji shortcode list | MIT | `lib/emoji/LICENSE` |

- The KaTeX fonts are Copyright (c) 2009-2010 Design Science, Inc. and
  Copyright (c) 2014-2018 Khan Academy, with Reserved Font Names KaTeX_AMS,
  KaTeX_Caligraphic, KaTeX_Fraktur, KaTeX_Main, KaTeX_Math, KaTeX_SansSerif,
  KaTeX_Script, KaTeX_Size1-4 and KaTeX_Typewriter. They are included
  unmodified and are not sold on their own.
- `mermaid.min.js` bundles other open-source packages. Their names, versions,
  licenses and copyright notices are in `lib/mermaid/BUNDLED-LICENSES.txt`.
  DOMPurify, offered under MPL-2.0 or Apache-2.0, is used under Apache-2.0.
- Only the highlight.js grammars the preview uses are included.
- The emoji list is the package's `lib/data/full.mjs` from markdown-it-emoji,
  with `export default` changed to an assignment to
  `window.markdownPreviewEmoji` so that a page opened from a file can load it.

## Installed separately

| Project | Used for | License |
| --- | --- | --- |
| [cmark-gfm](https://github.com/github/cmark-gfm) | Rendering Markdown | BSD-2-Clause |
