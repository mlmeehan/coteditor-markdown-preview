# Troubleshooting

Most problems come down to a handful of causes. Start with the doctor, then find your symptom below.

## Run the doctor

Paste this into Terminal:

```sh
/bin/bash -c "$(curl -fsSL https://github.com/mlmeehan/coteditor-markdown-preview/releases/latest/download/install.sh)" -- --doctor
```

It checks CotEditor, the installed script and its files, cmark-gfm, your settings, clashing shortcuts and whether the page can reach its libraries, then renders a small test document the way CotEditor runs the script. Anything marked ✗ is a problem, usually with the fix printed next to it. If you open an issue, include this report.

## CotEditor's Console

When the script runs into a problem, it explains it in an alert and writes the details to CotEditor's Console: choose **Window ▸ Console**. Errors from cmark-gfm or awk appear there too.

---

## Markdown Preview isn't in the Script menu

The Script menu lists what's in `~/Library/Application Scripts/com.coteditor.CotEditor/` (choose **Script menu ▸ Open Scripts Folder** to see it). Markdown Preview appears when:

- `Markdown Preview.@M.sh` (or however you named it) is in that folder itself, next to the `_markdown-preview` folder. A copy in a subfolder shows up in a submenu instead, and can't find the `_markdown-preview` folder it needs;
- the file name ends in `.sh`.

Reinstalling puts everything back in place. CotEditor picks up changes to the folder automatically; if the menu still looks stale, quit and reopen CotEditor.

## "The script can't be executed because you don't have permission to execute it"

The script has lost its executable flag, which happens when it's copied by hand. Reinstall, or make it executable again:

```sh
chmod +x ~/Library/Application\ Scripts/com.coteditor.CotEditor/Markdown\ Preview*.sh
```

## The menu item works, but ⇧⌘M doesn't

A shortcut can only belong to one command. If something else already uses ⇧⌘M, CotEditor ignores it for the script. Check:

- **Other scripts.** The installer and the doctor list scripts in the Scripts folder that use the same shortcut, such as an older Markdown preview script. Remove or rename them.
- **CotEditor's own shortcuts.** If you assigned ⇧⌘M to a menu command in **CotEditor ▸ Settings ▸ Shortcuts** (**Key Bindings** in older versions), or to a snippet in **Settings ▸ Snippets**, that wins.
- **macOS app shortcuts.** **System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ App Shortcuts** can also claim it.

Or pick a different shortcut for the preview:

```sh
/bin/bash -c "$(curl -fsSL https://github.com/mlmeehan/coteditor-markdown-preview/releases/latest/download/install.sh)" -- --shortcut '@~p'
```

`^` is Control, `~` Option, `$` Shift and `@` Command, followed by one letter; an uppercase letter adds Shift. `@~p` is ⌥⌘P.

## "It needs cmark-gfm, GitHub's Markdown renderer, which isn't installed"

Install it with Homebrew:

```sh
brew install cmark-gfm
```

or with MacPorts: `sudo port install cmark-gfm`.

CotEditor doesn't run scripts with your shell's `PATH`, so the script looks for cmark-gfm in `/opt/homebrew/bin`, `/usr/local/bin` and `/opt/local/bin`. If you installed it somewhere else (with Nix, for example), the installer and the doctor tell you, and you can link it into one of those:

```sh
sudo mkdir -p /usr/local/bin && sudo ln -s "$(command -v cmark-gfm)" /usr/local/bin/cmark-gfm
```

## Nothing happens when I run it

1. Look in CotEditor's **Window ▸ Console** for a message.
2. Run the doctor. Its "Test preview" line shows whether the script can render, and "Opens with" shows which app it would hand the page to.
3. If the doctor reports that the script is quarantined, run the fix it prints. This happens when the files were copied by hand from a browser download.

## The preview opens in the wrong app

The page opens in your default web browser. To use a specific one, set it in `~/Library/Application Scripts/com.coteditor.CotEditor/_markdown-preview/config`:

```ini
browser = Google Chrome
```

Use the name the app has in your Applications folder, without `.app`: Safari, Google Chrome, Firefox, Microsoft Edge, Arc, Brave Browser… The doctor tells you if there's no app with that name.

## Diagrams, math or code highlighting show as plain text

Those three, and emoji shortcodes, are drawn by libraries the page loads from cdn.jsdelivr.net the first time it needs them. They show as source text when:

- you're offline, and the libraries aren't in your browser's cache yet;
- a firewall, VPN, proxy or content blocker stops cdn.jsdelivr.net (the doctor checks this);
- `remote_libraries = off` is set in the config file.

If only one diagram stays as text, it most likely has a syntax error: the error message appears above its source. Try the diagram in the [Mermaid Live Editor](https://mermaid.live), keeping in mind the preview uses Mermaid 11.

## Math isn't recognized

The rules follow GitHub and pandoc:

- Inline math needs a non-space character right after the opening `$` and right before the closing `$`, and the closing `$` can't be followed by a digit. That's why `$5 and $10` stays text. Write `\$` for a literal dollar sign.
- Display math is `$$…$$`; it can span several lines, but not a blank line.
- `` $`…`$ `` and ` ```math ` blocks always work, because nothing in them can be mistaken for Markdown.
- Math inside code spans and code blocks is left alone, as are lines longer than 20,000 characters.

If math renders in red, KaTeX couldn't parse it; hover over it for the error. KaTeX supports most, but not all, LaTeX math commands: see [Supported Functions](https://katex.org/docs/supported.html).

## Images or links to other files don't work

Relative paths resolve against the folder of the document you're previewing:

- Save new documents first; an unsaved document has no folder.
- Spaces in a path need to be written as `%20`, or the whole destination wrapped in angle brackets: `![Diagram](<my images/diagram.png>)`.
- Images from the web need an internet connection.

## Links to headings go nowhere

Heading anchors follow GitHub's rules: lowercase, punctuation removed, spaces turned into hyphens, and `-1`, `-2` added to repeated headings. `## What's new?` becomes `#whats-new`. Hover over a heading in the preview and click the `#` next to it to see its anchor.

## A script or event handler in my document doesn't run

That's intentional. Like GitHub, the preview blocks scripts inside documents, so previewing a Markdown file you downloaded can't run code. Other raw HTML still renders.

## My browser fills up with preview tabs

Each preview opens a new tab with a snapshot of the document, so close older ones as you go. Every preview of a document is written to the same file, which means reloading an older tab also shows the latest version.

## An update moved a script to `_markdown-preview/backup`

The installer only replaces or removes files it installed itself, and keeps a list of them in `_markdown-preview/.installed`. When something else is where it wants to put the script, it moves that file to `_markdown-preview/backup/` instead of overwriting it, and tells you. That happens when:

- you edited the installed script: your edited copy is saved, and a fresh copy is installed;
- another script had the same name, such as an older Markdown preview script;
- you installed Markdown Preview by hand, so there's no list yet: the previous copy is saved in case you changed it.

Copies of the script you made yourself under other names, such as one you duplicated to try a change, are left alone by updates and by `--uninstall`.

The other files in `_markdown-preview` belong to the installer, apart from `config`, `custom.css` and `backup`: updates replace them and `--uninstall` removes them, without saving changes. Keep your changes in `config` and `custom.css`.

## Start over

Uninstall, then install again:

```sh
/bin/bash -c "$(curl -fsSL https://github.com/mlmeehan/coteditor-markdown-preview/releases/latest/download/install.sh)" -- --uninstall
/bin/bash -c "$(curl -fsSL https://github.com/mlmeehan/coteditor-markdown-preview/releases/latest/download/install.sh)"
```

Uninstalling keeps a `config` or `custom.css` you changed, and anything in `backup`. To go back to the default settings too, delete your settings file between the two commands:

```sh
rm -f ~/Library/Application\ Scripts/com.coteditor.CotEditor/_markdown-preview/config
```

To remove everything, including `custom.css` and the backups, delete the whole `_markdown-preview` folder instead.

## Still stuck?

[Open an issue](https://github.com/mlmeehan/coteditor-markdown-preview/issues/new/choose) with the doctor's report, what you expected, what happened instead and, if it's about rendering, the smallest piece of Markdown that shows it.
