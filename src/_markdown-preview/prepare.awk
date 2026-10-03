# prepare.awk - runs on the Markdown before cmark-gfm renders it.
# Part of Markdown Preview for CotEditor (MIT License).
#
#   - YAML (---) or TOML (+++) front matter at the top of the file becomes a
#     collapsed <details> block instead of being rendered as Markdown.
#   - $...$ and $$...$$ math is swapped for inline HTML placeholders so that
#     Markdown can't mangle the TeX (\\, \{, _, *, |). KaTeX renders them in
#     the browser. Code spans, code blocks, raw HTML, link definitions and \$
#     are left alone.
#
# Run it with LC_ALL=C so that every awk treats the text as bytes. It is
# written for the BWK awk that ships with macOS and also works with mawk/gawk.

{
  sub(/\r$/, "")
  line[++n] = $0
}

END {
  blank = 1
  for (i = front_matter(); i <= n; i++) {
    s = line[i]

    if (fence_len) {
      print s
      if (closes_fence(s)) fence_len = 0
      continue
    }
    if (raw_html) {
      print s
      if (raw_html == 1 && tolower(s) ~ /<\/(script|pre|style|textarea)>/) raw_html = 0
      if (raw_html == 2 && index(s, "-->")) raw_html = 0
      continue
    }
    if (s ~ /^[ \t]*$/) {
      print s
      blank = 1
      continue
    }

    indent = indentation(s)
    if (indented_code && indent >= 4) {
      print s
      continue
    }
    indented_code = (indent >= 4 && blank && !in_list)
    if (s ~ /^ ? ? ?([-+*]|[0-9]+[.)])([ \t]|$)/) in_list = 1
    else if (indent == 0 && (blank || s ~ /^#/)) in_list = 0
    blank = 0

    # Lines over 20 kB (generated or minified content) are passed through as-is
    # because macOS awk slows down quadratically on very long lines.
    if (indented_code || opens_fence(s) || opens_raw_html(s) ||
        index(s, "$") == 0 || length(s) > 20000 || s ~ /^ ? ? ?\[[^]^][^]]*\]:/) {
      print s
      continue
    }
    print protect_math(i)
    i = last_line
  }
}

function front_matter(   kind, last, k, fence) {
  if (n == 0) return 1
  if (line[1] ~ /^---[ \t]*$/) kind = "yaml"
  else if (line[1] ~ /^\+\+\+[ \t]*$/) kind = "toml"
  else return 1

  for (last = 2; last <= n; last++) {
    if (kind == "yaml" && line[last] ~ /^(---|\.\.\.)[ \t]*$/) break
    if (kind == "toml" && line[last] ~ /^\+\+\+[ \t]*$/) break
    if (kind == "yaml" && !yaml_line(line[last])) return 1
  }
  if (last > n) return 1

  if (last > 2) {
    fence = "```"
    for (k = 2; k < last; k++)
      while (index(line[k], fence)) fence = fence "`"
    print "<details class=\"front-matter\">"
    print "<summary>Front matter</summary>"
    print ""
    print fence kind
    for (k = 2; k < last; k++) print line[k]
    print fence
    print ""
    print "</details>"
    print ""
  }
  return last + 1
}

function yaml_line(s) {
  return s ~ /^[ \t]*$/ || s ~ /^[ \t]*#/ || s ~ /^[ \t]/ ||
         s ~ /^-([ \t]|$)/ || s ~ /^[^ \t:#][^:]*:([ \t]|$)/
}

function indentation(s,   k, col, c) {
  col = 0
  for (k = 1; k <= length(s); k++) {
    c = substr(s, k, 1)
    if (c == " ") col++
    else if (c == "\t") col += 4 - col % 4
    else break
  }
  return col
}

function opens_fence(s,   t, c, k) {
  t = s
  while (match(t, /^[ \t]*(>|[-+*][ \t]|[0-9]+[.)][ \t])/)) t = substr(t, RLENGTH + 1)
  sub(/^[ \t]+/, "", t)
  c = substr(t, 1, 1)
  if (c != "`" && c != "~") return 0
  k = 0
  while (substr(t, k + 1, 1) == c) k++
  if (k < 3 || (c == "`" && index(substr(t, k + 1), "`"))) return 0
  fence_char = c
  fence_len = k
  return 1
}

function closes_fence(s,   t, k) {
  t = s
  while (match(t, /^[ \t]*>/)) t = substr(t, RLENGTH + 1)
  sub(/^[ \t]+/, "", t)
  k = 0
  while (substr(t, k + 1, 1) == fence_char) k++
  return (k >= fence_len && substr(t, k + 1) ~ /^[ \t]*$/)
}

function opens_raw_html(s,   t) {
  t = tolower(s)
  if (t ~ /^ ? ? ?<(script|pre|style|textarea)([ \t>]|$)/) {
    if (t !~ /<\/(script|pre|style|textarea)>/) raw_html = 1
    return 1
  }
  if (t ~ /^ ? ? ?<!--/) {
    if (!index(substr(t, index(t, "<!--") + 4), "-->")) raw_html = 2
    return 1
  }
  return 0
}

function protect_math(li,   s, out, c, k, j) {
  s = line[li]
  out = ""
  last_line = li
  while (match(s, /[\\`<$]/)) {
    out = out substr(s, 1, RSTART - 1)
    s = substr(s, RSTART)
    c = substr(s, 1, 1)

    if (c == "\\") {
      k = 2
    } else if (c == "`") {
      k = code_span(s)
    } else if (c == "<") {
      k = html_tag(s)
    } else if (substr(s, 2, 1) == "`") {
      # GitHub's $`...`$ syntax is handled in the browser.
      k = code_span(substr(s, 2)) + 1
      if (code_closed && substr(s, k + 1, 1) == "$") k++
    } else if (substr(s, 2, 1) == "$") {
      j = display_end(s, 3)
      if (j > 3) {
        out = out placeholder(substr(s, 3, j - 3), "block")
        s = substr(s, j + 2)
        continue
      }
      if (j == 0 && display_lines(substr(s, 3))) {
        out = out placeholder(display_tex, "block")
        s = display_rest
        continue
      }
      k = 2
    } else if ((j = inline_end(s)) > 0) {
      out = out placeholder(substr(s, 2, j - 2), "inline")
      s = substr(s, j + 1)
      continue
    } else {
      k = 1
    }
    out = out substr(s, 1, k)
    s = substr(s, k + 1)
  }
  return out s
}

# Length of the code span at the start of s, or of the backtick run if unclosed.
function code_span(s,   run, rest, used) {
  run = 0
  while (substr(s, run + 1, 1) == "`") run++
  rest = substr(s, run + 1)
  used = run
  while (match(rest, /`+/)) {
    used += RSTART - 1 + RLENGTH
    if (RLENGTH == run) {
      code_closed = 1
      return used
    }
    rest = substr(rest, RSTART + RLENGTH)
  }
  code_closed = 0
  return run
}

# Length of the HTML tag, comment or autolink at the start of s (1 if none).
function html_tag(s,   k) {
  if (substr(s, 1, 4) == "<!--") {
    k = index(substr(s, 5), "-->")
    return k ? k + 6 : length(s)
  }
  if (match(s, /^<[A-Za-z][A-Za-z0-9-]*([ \t]+[A-Za-z_:][A-Za-z0-9_.:-]*([ \t]*=[ \t]*([^ \t"'=<>`]+|'[^']*'|"[^"]*"))?)*[ \t]*\/?>/) ||
      match(s, /^<\/[A-Za-z][A-Za-z0-9-]*[ \t]*>/) ||
      match(s, /^<[A-Za-z][A-Za-z0-9.+-]+:[^ \t<>]*>/))
    return RLENGTH
  return 1
}

# Position of the $ closing inline math opened at the start of s, or 0.
# Same rules as pandoc: no space after the opening $ or before the closing $,
# and no digit right after the closing $ (so "$5 and $10" stays text).
function inline_end(s,   k, c, len) {
  c = substr(s, 2, 1)
  if (c == "" || c == " " || c == "\t") return 0
  len = length(s)
  for (k = 2; k <= len; k++) {
    c = substr(s, k, 1)
    if (c == "\\") {
      k++
    } else if (c == "$") {
      if (substr(s, k - 1, 1) ~ /[ \t]/ || substr(s, k + 1, 1) ~ /[0-9]/) return 0
      return k
    }
  }
  return 0
}

# Position of the next unescaped "$$" in s, searching from position k, or 0.
function display_end(s, k,   len, c) {
  len = length(s)
  for (; k < len; k++) {
    c = substr(s, k, 1)
    if (c == "\\") k++
    else if (c == "$" && substr(s, k + 1, 1) == "$") return k
  }
  return 0
}

# $$ display math that continues on the following lines (no blank lines).
function display_lines(first,   quoted, tex, k, t, j) {
  quoted = (line[last_line] ~ /^[ \t]*>/)
  tex = first
  for (k = last_line + 1; k <= n; k++) {
    t = line[k]
    if (quoted) sub(/^[ \t]*(>[ \t]?)*/, "", t)
    if (t ~ /^[ \t]*$/ || t ~ /^[ \t]*(```|~~~)/) return 0
    j = display_end(t, 1)
    if (j) {
      display_tex = tex "\n" substr(t, 1, j - 1)
      display_rest = substr(t, j + 2)
      last_line = k
      return 1
    }
    tex = tex "\n" t
  }
  return 0
}

function placeholder(tex, mode) {
  gsub(/&/, "\\&amp;", tex)
  gsub(/"/, "\\&quot;", tex)
  gsub(/</, "\\&lt;", tex)
  gsub(/>/, "\\&gt;", tex)
  gsub(/[|]/, "\\&#124;", tex)
  gsub(/\n/, "\\&#10;", tex)
  return "<span class=\"md-math\" data-mode=\"" mode "\" data-tex=\"" tex "\"></span>"
}
