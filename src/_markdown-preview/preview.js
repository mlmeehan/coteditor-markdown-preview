/*
 * preview.js - finishes the HTML that cmark-gfm produced: Mermaid diagrams,
 * KaTeX math, syntax highlighting, alerts, emoji, heading anchors, a table of
 * contents and copy buttons.
 * Part of Markdown Preview for CotEditor (MIT License).
 */
(() => {
  "use strict";

  // Libraries load only when a document needs them, from the "lib" folder
  // installed next to this file (the preview script copies it next to the
  // page). Nothing is fetched from the internet. Versions are pinned in
  // tools/fetch-libraries.sh, which builds that folder.
  const LIBRARIES = {
    katexStyle: "katex/katex.min.css",
    katex: "katex/katex.min.js",
    mermaid: "mermaid/mermaid.min.js",
    highlight: "highlight/highlight.min.js",
    emoji: "emoji/emoji.js",
  };

  // highlight.js's common bundle covers bash, c, cpp, csharp, css, diff, go,
  // graphql, ini/toml, java, javascript, json, kotlin, less, lua, makefile,
  // markdown, objectivec, perl, php, python, r, ruby, rust, scss, shell, sql,
  // swift, typescript, vbnet, wasm, xml/html and yaml. These load on demand.
  // tools/fetch-libraries.sh reads this list to decide which grammars to
  // install, so keep it to quoted names inside `new Set([` ... `]);`:
  const GRAMMARS = new Set([
    "apache", "applescript", "awk", "clojure", "cmake", "dart", "dockerfile", "dos",
    "elixir", "erlang", "fsharp", "gradle", "groovy", "haskell", "http", "julia",
    "latex", "matlab", "nginx", "nix", "ocaml", "pgsql", "powershell", "properties",
    "protobuf", "scala", "vim",
  ]);
  const GRAMMAR_ALIASES = {
    apacheconf: "apache", bat: "dos", batch: "dos", clj: "clojure", cmd: "dos",
    docker: "dockerfile", edn: "clojure", erl: "erlang", ex: "elixir", exs: "elixir",
    "f#": "fsharp", fs: "fsharp", hs: "haskell", https: "http", ml: "ocaml",
    nginxconf: "nginx", nixos: "nix", osascript: "applescript", postgres: "pgsql",
    postgresql: "pgsql", proto: "protobuf", ps: "powershell", ps1: "powershell",
    pwsh: "powershell", tex: "latex",
  };

  // Alert styles. Obsidian callout names map onto GitHub's five.
  const ALERT_KINDS = new Map([
    ["note", "note"], ["info", "note"], ["todo", "note"], ["abstract", "note"],
    ["summary", "note"], ["tldr", "note"],
    ["tip", "tip"], ["hint", "tip"], ["success", "tip"], ["check", "tip"], ["done", "tip"],
    ["important", "important"], ["question", "important"], ["help", "important"],
    ["faq", "important"], ["example", "important"], ["quote", "important"], ["cite", "important"],
    ["warning", "warning"], ["attention", "warning"],
    ["caution", "caution"], ["danger", "caution"], ["error", "caution"], ["failure", "caution"],
    ["fail", "caution"], ["missing", "caution"], ["bug", "caution"],
  ]);

  // Octicons (MIT): info, light-bulb, report, alert, stop, copy, check.
  const ICONS = {
    note: '<path d="M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8Zm8-6.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13ZM6.5 7.75A.75.75 0 0 1 7.25 7h1a.75.75 0 0 1 .75.75v2.75h.25a.75.75 0 0 1 0 1.5h-2a.75.75 0 0 1 0-1.5h.25v-2h-.25a.75.75 0 0 1-.75-.75ZM8 6a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"/>',
    tip: '<path d="M8 1.5c-2.363 0-4 1.69-4 3.75 0 .984.424 1.625.984 2.304l.214.253c.223.264.47.556.673.848.284.411.537.896.621 1.49a.75.75 0 0 1-1.484.211c-.04-.282-.163-.547-.37-.847a8.456 8.456 0 0 0-.542-.68c-.084-.1-.173-.205-.268-.32C3.201 7.75 2.5 6.766 2.5 5.25 2.5 2.31 4.863 0 8 0s5.5 2.31 5.5 5.25c0 1.516-.701 2.5-1.328 3.259-.095.115-.184.22-.268.319-.207.245-.383.453-.541.681-.208.3-.33.565-.37.847a.751.751 0 0 1-1.485-.212c.084-.593.337-1.078.621-1.489.203-.292.45-.584.673-.848.075-.088.147-.173.213-.253.561-.679.985-1.32.985-2.304 0-2.06-1.637-3.75-4-3.75ZM5.75 12h4.5a.75.75 0 0 1 0 1.5h-4.5a.75.75 0 0 1 0-1.5ZM6 15.25a.75.75 0 0 1 .75-.75h2.5a.75.75 0 0 1 0 1.5h-2.5a.75.75 0 0 1-.75-.75Z"/>',
    important: '<path d="M0 1.75C0 .784.784 0 1.75 0h12.5C15.216 0 16 .784 16 1.75v9.5A1.75 1.75 0 0 1 14.25 13H8.06l-2.573 2.573A1.458 1.458 0 0 1 3 14.543V13H1.75A1.75 1.75 0 0 1 0 11.25Zm1.75-.25a.25.25 0 0 0-.25.25v9.5c0 .138.112.25.25.25h2a.75.75 0 0 1 .75.75v2.19l2.72-2.72a.749.749 0 0 1 .53-.22h6.5a.25.25 0 0 0 .25-.25v-9.5a.25.25 0 0 0-.25-.25Zm7 2.25v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 9a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"/>',
    warning: '<path d="M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"/>',
    caution: '<path d="M4.47.22A.749.749 0 0 1 5 0h6c.199 0 .389.079.53.22l4.25 4.25c.141.14.22.331.22.53v6a.749.749 0 0 1-.22.53l-4.25 4.25A.749.749 0 0 1 11 16H5a.749.749 0 0 1-.53-.22L.22 11.53A.749.749 0 0 1 0 11V5c0-.199.079-.389.22-.53Zm.84 1.28L1.5 5.31v5.38l3.81 3.81h5.38l3.81-3.81V5.31L10.69 1.5ZM8 4a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 8 4Zm0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"/>',
    copy: '<path d="M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 0 1 0 1.5h-1.5a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-1.5a.75.75 0 0 1 1.5 0v1.5A1.75 1.75 0 0 1 9.25 16h-7.5A1.75 1.75 0 0 1 0 14.25Z"/><path d="M5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0 1 14.25 11h-7.5A1.75 1.75 0 0 1 5 9.25Zm1.75-.25a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-7.5a.25.25 0 0 0-.25-.25Z"/>',
    check: '<path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z"/>',
  };

  const root = document.documentElement;
  const content = document.getElementById("content");
  const settings = readSettings();
  const systemDark = window.matchMedia("(prefers-color-scheme: dark)");
  const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
  const icon = (name) => `<svg viewBox="0 0 16 16" aria-hidden="true">${ICONS[name]}</svg>`;

  function readSettings() {
    try {
      return JSON.parse(document.getElementById("preview-settings").textContent);
    } catch {
      return {};
    }
  }

  function prefersDark() {
    const theme = root.dataset.theme;
    return theme === "dark" || (theme !== "light" && systemDark.matches);
  }

  const pending = new Map();

  // Adds a script or stylesheet from the lib folder once and resolves when it
  // has loaded.
  function load(file, kind = "script") {
    if (!settings.libraries) return Promise.reject(new Error("The lib folder isn't installed"));
    const url = settings.libraries + file;
    if (!pending.has(url)) {
      pending.set(url, new Promise((resolve, reject) => {
        const element = document.createElement(kind === "style" ? "link" : "script");
        if (kind === "style") {
          element.rel = "stylesheet";
          element.href = url;
        } else {
          element.src = url;
        }
        element.addEventListener("load", () => resolve(), { once: true });
        element.addEventListener("error", () => reject(new Error(`Could not load ${url}`)), { once: true });
        document.head.append(element);
      }));
    }
    return pending.get(url);
  }

  function mathElement(tex, mode) {
    const element = document.createElement(mode === "block" ? "div" : "span");
    element.className = "md-math";
    element.dataset.mode = mode;
    element.dataset.tex = tex;
    return element;
  }

  // <base> points at the document's folder so relative images and links work.
  // These two helpers keep in-page references pointing at this page instead.

  // url(#id) references inside SVG resolve against <base> in Safari, which
  // drops arrowheads, shadows and gradients.
  function pinSvgReferences(svg) {
    const page = document.URL.split("#")[0];
    const pin = (text) => text.replace(/url\(\s*(['"]?)#/g, (match, quote) => `url(${quote}${page}#`);
    for (const element of [svg, ...svg.querySelectorAll("*")]) {
      for (const attribute of Array.from(element.attributes)) {
        if (attribute.value.includes("url(")) {
          attribute.value = pin(attribute.value);
        } else if (/^(xlink:)?href$/.test(attribute.name) && attribute.value.startsWith("#") &&
            element.localName !== "a") {
          attribute.value = page + attribute.value;
        }
      }
      if (element.localName === "style") element.textContent = pin(element.textContent);
    }
  }

  // "#section" links (footnotes, the table of contents, heading anchors).
  function followInPageLinks() {
    const decode = (text) => {
      try {
        return decodeURIComponent(text);
      } catch {
        return text;
      }
    };

    document.addEventListener("click", (event) => {
      const link = event.target.closest && event.target.closest('a[href^="#"]');
      if (!link || event.defaultPrevented || event.button !== 0 ||
          event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
        return;
      }
      event.preventDefault();

      const fragment = link.getAttribute("href").slice(1);
      if (!fragment) {
        window.scrollTo({ top: 0 });
        return;
      }
      const target = document.getElementById(decode(fragment));
      if (!target) return;

      if (decode(location.hash.slice(1)) === target.id) {
        target.scrollIntoView();
      } else {
        location.hash = fragment;
      }
    });
  }

  // Code blocks become Mermaid diagrams, display math, or highlighted code
  // with a language label and a copy button.
  function prepareCodeBlocks() {
    const diagrams = [];
    const highlightable = [];

    for (const pre of Array.from(content.querySelectorAll("pre"))) {
      const code = pre.firstElementChild && pre.firstElementChild.tagName === "CODE"
        ? pre.firstElementChild
        : null;
      const match = code && /(?:^|\s)language-(\S+)/.exec(code.className);
      const language = match ? match[1].toLowerCase() : "";

      if (language === "mermaid") {
        const figure = document.createElement("div");
        figure.className = "diagram is-pending";
        pre.replaceWith(figure);
        figure.append(pre);
        diagrams.push({ figure, pre, source: code.textContent });
        continue;
      }

      if (language === "math") {
        pre.replaceWith(mathElement(code.textContent.replace(/\n$/, ""), "block"));
        continue;
      }

      const block = document.createElement("div");
      block.className = "code-block";
      pre.replaceWith(block);
      block.append(pre, codeToolbar(pre, match ? match[1] : ""));

      if (language && !["plaintext", "plain", "text", "txt", "none"].includes(language)) {
        highlightable.push({ code, language });
      }
    }

    return { diagrams, highlightable };
  }

  function codeToolbar(pre, label) {
    const toolbar = document.createElement("div");
    toolbar.className = "code-toolbar";

    if (label) {
      const name = document.createElement("span");
      name.className = "code-language";
      name.textContent = label;
      toolbar.append(name);
    }

    const button = document.createElement("button");
    button.type = "button";
    button.className = "code-copy";
    button.title = "Copy";
    button.setAttribute("aria-label", "Copy code");
    button.innerHTML = icon("copy");

    let reset = 0;
    button.addEventListener("click", async () => {
      const copied = await copyText(pre);
      button.innerHTML = icon(copied ? "check" : "copy");
      button.title = copied ? "Copied" : "Copy failed";
      button.toggleAttribute("data-copied", copied);
      window.clearTimeout(reset);
      reset = window.setTimeout(() => {
        button.innerHTML = icon("copy");
        button.title = "Copy";
        button.removeAttribute("data-copied");
      }, 1500);
    });

    toolbar.append(button);
    return toolbar;
  }

  async function copyText(pre) {
    const text = pre.textContent.replace(/\n$/, "");
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // Older browsers or a denied permission: copy through a selection.
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(pre);
      selection.removeAllRanges();
      selection.addRange(range);
      try {
        return document.execCommand("copy");
      } catch {
        return false;
      } finally {
        selection.removeAllRanges();
      }
    }
  }

  // GitHub's $`...`$ math arrives as a code span wrapped in dollar signs.
  function prepareCodeSpanMath() {
    for (const code of Array.from(content.querySelectorAll("code"))) {
      if (code.closest("pre")) continue;
      const before = code.previousSibling;
      const after = code.nextSibling;
      if (!before || !after || before.nodeType !== Node.TEXT_NODE || after.nodeType !== Node.TEXT_NODE) continue;
      if (!before.data.endsWith("$") || !after.data.startsWith("$")) continue;
      before.data = before.data.slice(0, -1);
      after.data = after.data.slice(1);
      code.replaceWith(mathElement(code.textContent, "inline"));
    }
  }

  // > [!NOTE], [!TIP], [!IMPORTANT], [!WARNING] and [!CAUTION] blockquotes.
  // Text after the marker on the same line becomes a custom title (Obsidian).
  function prepareAlerts() {
    for (const quote of Array.from(content.querySelectorAll("blockquote"))) {
      const paragraph = quote.firstElementChild;
      if (!paragraph || paragraph.tagName !== "P") continue;
      const first = paragraph.firstChild;
      if (!first || first.nodeType !== Node.TEXT_NODE) continue;

      const marker = /^\s*\[!([a-z]+)\][+-]?(?=\s|$)/i.exec(first.data);
      const kind = marker && ALERT_KINDS.get(marker[1].toLowerCase());
      if (!kind) continue;

      first.data = first.data.slice(marker[0].length);
      const titleNodes = takeFirstLine(paragraph);
      const hasCustomTitle = titleNodes.textContent.trim() !== "";
      if (!paragraph.textContent.trim() && !paragraph.querySelector("img, .md-math")) {
        paragraph.remove();
      }

      const label = document.createElement("span");
      if (hasCustomTitle) {
        if (titleNodes.firstChild && titleNodes.firstChild.nodeType === Node.TEXT_NODE) {
          titleNodes.firstChild.data = titleNodes.firstChild.data.replace(/^\s+/, "");
        }
        label.append(titleNodes);
      } else {
        const name = marker[1].toLowerCase();
        label.textContent = name.charAt(0).toUpperCase() + name.slice(1);
      }

      const title = document.createElement("p");
      title.className = "markdown-alert-title";
      title.innerHTML = icon(kind);
      title.append(label);

      const alert = document.createElement("div");
      alert.className = `markdown-alert markdown-alert-${kind}`;
      alert.append(title, ...Array.from(quote.childNodes));
      quote.replaceWith(alert);
    }
  }

  // Removes and returns the nodes before the first line break of a paragraph.
  function takeFirstLine(paragraph) {
    const nodes = document.createDocumentFragment();
    while (paragraph.firstChild) {
      const node = paragraph.firstChild;
      if (node.nodeName === "BR") {
        node.remove();
        break;
      }
      if (node.nodeType === Node.TEXT_NODE) {
        const newline = node.data.indexOf("\n");
        if (newline !== -1) {
          nodes.append(node.data.slice(0, newline));
          node.data = node.data.slice(newline + 1);
          break;
        }
      }
      nodes.append(node);
    }
    return nodes;
  }

  function prepareTaskLists() {
    const boxes = content.querySelectorAll(
      'li > input[type="checkbox"]:first-child, li > p:first-child > input[type="checkbox"]:first-child'
    );
    for (const box of boxes) {
      const item = box.closest("li");
      item.classList.add("task-list-item");
      item.parentElement.classList.add("contains-task-list");
    }
  }

  // A large image on a line of its own is centered; badges and images inside
  // text stay inline.
  function prepareFigures() {
    for (const image of Array.from(content.querySelectorAll("img"))) {
      const parent = image.parentElement;
      const holder = parent.tagName === "A" && parent.childNodes.length === 1 ? parent : image;
      const paragraph = holder.parentElement;
      if (!paragraph || paragraph.tagName !== "P") continue;
      const alone = Array.from(paragraph.childNodes).every(
        (node) => node === holder || (node.nodeType === Node.TEXT_NODE && !node.data.trim())
      );
      if (!alone) continue;

      const check = () => {
        if (image.naturalWidth >= 200) paragraph.classList.add("figure");
      };
      if (image.complete) check();
      else image.addEventListener("load", check, { once: true });
    }
  }

  // Heading ids follow GitHub's rules, so links written for GitHub work here.
  function prepareHeadings() {
    const used = new Set(Array.from(document.querySelectorAll("[id]"), (element) => element.id));
    const headings = Array.from(content.querySelectorAll("h1, h2, h3, h4, h5, h6"));

    for (const heading of headings) {
      if (!heading.id) {
        const base = headingText(heading)
          .trim()
          .toLowerCase()
          .replace(/:[a-z0-9_+-]+:/g, "")
          .replace(/[^\p{L}\p{M}\p{N}\p{Pc}\- ]/gu, "")
          .replace(/ /g, "-") || "section";
        let id = base;
        for (let n = 1; used.has(id); n++) id = `${base}-${n}`;
        used.add(id);
        heading.id = id;
      }

      const anchor = document.createElement("a");
      anchor.className = "heading-anchor";
      anchor.setAttribute("href", "#" + heading.id);
      anchor.setAttribute("aria-label", "Link to this section");
      anchor.textContent = "#";
      heading.append(anchor);
    }
    return headings;
  }

  function headingText(node) {
    let text = "";
    for (const child of node.childNodes) {
      if (child.nodeType === Node.TEXT_NODE) {
        text += child.data;
      } else if (child.nodeType === Node.ELEMENT_NODE && !child.classList.contains("heading-anchor")) {
        text += child.classList.contains("md-math") ? child.dataset.tex : headingText(child);
      }
    }
    return text;
  }

  // [TOC], [[TOC]] or [[_TOC_]] on a line of its own.
  function prepareTableOfContents(headings) {
    for (const marker of Array.from(content.querySelectorAll("p"))) {
      if (!/^\[\[?_?toc_?\]\]?$/i.test(marker.textContent.trim())) continue;

      const singleTitle = headings.filter((heading) => heading.tagName === "H1").length === 1;
      const entries = headings.filter((heading) => !(singleTitle && heading.tagName === "H1"));

      const nav = document.createElement("nav");
      nav.className = "toc";
      nav.setAttribute("aria-label", "Table of contents");
      const title = document.createElement("p");
      title.className = "toc-title";
      title.textContent = "Contents";
      const list = document.createElement("ul");
      nav.append(title, list);

      const open = [];
      for (const heading of entries) {
        const level = Number(heading.tagName[1]);
        while (open.length && open[open.length - 1].level >= level) open.pop();
        let parentList = list;
        if (open.length) {
          const parentItem = open[open.length - 1].item;
          parentList = parentItem.querySelector(":scope > ul") ||
            parentItem.appendChild(document.createElement("ul"));
        }
        const item = document.createElement("li");
        const link = document.createElement("a");
        link.setAttribute("href", "#" + heading.id);
        link.textContent = headingText(heading).trim();
        item.append(link);
        parentList.append(item);
        open.push({ level, item });
      }
      marker.replaceWith(nav);
    }
  }

  // Everything below needs a library. Each part fails on its own and leaves
  // its source text in place.

  async function renderEmoji() {
    const pattern = /:([a-z0-9_+-]+):/g;
    const nodes = [];
    const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (/:[a-z0-9_+-]+:/.test(node.data) &&
          !node.parentElement.closest("code, pre, kbd, samp, script, style, textarea, svg, .md-math, .diagram")) {
        nodes.push(node);
      }
    }
    if (!nodes.length) return;

    await load(LIBRARIES.emoji);
    const table = window.markdownPreviewEmoji;
    for (const node of nodes) {
      node.data = node.data.replace(pattern, (text, name) => (hasOwn(table, name) ? table[name] : text));
    }
  }

  async function renderMath() {
    try {
      const targets = Array.from(content.querySelectorAll(".md-math"));
      if (!targets.length) return;
      await Promise.all([load(LIBRARIES.katexStyle, "style"), load(LIBRARIES.katex)]);
      const macros = {};
      for (const element of targets) {
        try {
          window.katex.render(element.dataset.tex, element, {
            displayMode: element.dataset.mode === "block",
            throwOnError: false,
            macros,
          });
        } catch (error) {
          console.warn("Markdown Preview: math", error);
        }
      }
    } finally {
      root.classList.remove("math-pending");
    }
  }

  async function renderDiagrams(diagrams) {
    if (!diagrams.length) return;

    try {
      await load(LIBRARIES.mermaid);
    } catch (error) {
      for (const diagram of diagrams) {
        showDiagramNote(diagram, "Mermaid could not be loaded, so the diagram source is shown instead. Reinstalling Markdown Preview restores it.");
      }
      throw error;
    }

    let count = 0;
    let queue = Promise.resolve();

    const draw = async () => {
      const theme = prefersDark() ? "dark" : "default";
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "strict",
        theme,
        fontFamily: getComputedStyle(document.body).fontFamily,
      });

      for (const diagram of diagrams) {
        const id = `mermaid-diagram-${++count}`;
        try {
          const { svg, bindFunctions } = await window.mermaid.render(id, diagram.source);
          diagram.figure.innerHTML = svg;
          if (bindFunctions) bindFunctions(diagram.figure);
          for (const element of diagram.figure.querySelectorAll("svg")) pinSvgReferences(element);
          diagram.figure.className = "diagram";
          diagram.figure.dataset.theme = theme;
        } catch (error) {
          for (const leftover of [document.getElementById(id), document.getElementById("d" + id)]) {
            if (leftover && !leftover.closest(".diagram")) leftover.remove();
          }
          showDiagramNote(diagram, (error && (error.message || error.str)) || String(error));
        }
      }
    };

    queue = queue.then(draw);
    await queue;
    if (root.dataset.theme === "auto") {
      systemDark.addEventListener("change", () => {
        queue = queue.then(draw);
      });
    }
  }

  function showDiagramNote(diagram, message) {
    const note = document.createElement("div");
    note.className = "diagram-note";
    note.textContent = message;
    diagram.figure.className = "diagram has-note";
    diagram.figure.replaceChildren(note, diagram.pre);
  }

  async function highlightCode(blocks) {
    if (!blocks.length) return;
    await load(LIBRARIES.highlight);
    const hljs = window.hljs;

    const grammars = new Set();
    for (const { language } of blocks) {
      if (hljs.getLanguage(language)) continue;
      const name = hasOwn(GRAMMAR_ALIASES, language) ? GRAMMAR_ALIASES[language] : language;
      if (GRAMMARS.has(name)) grammars.add(name);
    }
    await Promise.allSettled(
      Array.from(grammars, (name) => load(`highlight/languages/${name}.min.js`))
    );

    for (const { code, language } of blocks) {
      // An alias the grammar itself doesn't declare.
      const name = hasOwn(GRAMMAR_ALIASES, language) ? GRAMMAR_ALIASES[language] : language;
      if (!hljs.getLanguage(language) && hljs.getLanguage(name)) {
        hljs.registerAliases(language, { languageName: name });
      }
      if (hljs.getLanguage(language)) hljs.highlightElement(code);
    }
  }

  // ---------------------------------------------------------------------------

  for (const svg of Array.from(content.querySelectorAll("svg"))) pinSvgReferences(svg);
  followInPageLinks();
  const { diagrams, highlightable } = prepareCodeBlocks();
  prepareCodeSpanMath();
  prepareAlerts();
  prepareTaskLists();
  prepareFigures();
  prepareTableOfContents(prepareHeadings());

  Promise.allSettled([
    renderEmoji(),
    renderMath(),
    renderDiagrams(diagrams),
    highlightCode(highlightable),
  ]).then((results) => {
    for (const result of results) {
      if (result.status === "rejected") console.warn("Markdown Preview:", result.reason);
    }
  });
})();
