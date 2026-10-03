// Renders Markdown with the preview script and checks the result in real
// browsers: Chromium, and WebKit (Safari's engine) and Firefox when they are
// installed.
//
//   cd tests/browser && npm ci && npx playwright install chromium webkit firefox
//   npm test
//
// Screenshots of the feature tour are written to tests/browser/screenshots.
// Needs cmark-gfm. The libraries are fetched first if they're missing; after
// that, pages are opened with the network blocked, since everything they use
// is installed with them.

import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium, firefox, webkit } from "playwright";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const tour = path.join(repo, "examples", "feature-tour.md");
const shots = path.join(here, "screenshots");
mkdirSync(shots, { recursive: true });
execFileSync("/bin/bash", [path.join(repo, "tools", "fetch-libraries.sh")], { stdio: ["ignore", "ignore", "inherit"] });

let failures = 0;
function check(label, condition, detail = "") {
  if (condition) {
    console.log(`  ok   ${label}`);
  } else {
    failures++;
    console.log(`  FAIL ${label}${detail ? ` (${detail})` : ""}`);
  }
}

// Runs the preview script the way CotEditor does and returns the page's path.
function preview(markdownFile, { srcDir = path.join(repo, "src") } = {}) {
  const output = execFileSync("/bin/bash", [path.join(srcDir, "Markdown Preview.sh"), markdownFile], {
    input: readFileSync(markdownFile),
    env: { ...process.env, MARKDOWN_PREVIEW_NO_OPEN: "1" },
  });
  return output.toString().split("\n")[0];
}

// A copy of src/ with a config file, for testing settings.
function configuredCopy(config) {
  const dir = mkdtempSync(path.join(tmpdir(), "markdown-preview-"));
  cpSync(path.join(repo, "src"), dir, { recursive: true });
  writeFileSync(path.join(dir, "_markdown-preview", "config"), config);
  return dir;
}

async function open(browser, file, colorScheme = "light") {
  const context = await browser.newContext({ colorScheme, viewport: { width: 1100, height: 900 } });
  await context.addInitScript(() => {
    window.__violations = [];
    document.addEventListener("securitypolicyviolation", (event) => window.__violations.push(event.blockedURI));
  });
  const page = await context.newPage();
  const problems = [];
  const requests = [];
  page.on("pageerror", (error) => problems.push(`page error: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error" && !/Failed to load resource/.test(message.text())) {
      problems.push(`console: ${message.text()}`);
    }
  });
  page.on("request", (request) => {
    if (!request.url().startsWith("file:")) requests.push(request.url());
  });
  // No network: a request to anything but a file fails, and is listed.
  await context.route(/^(?!file:)/, (route) => route.abort());
  await page.goto("file://" + file);
  await page.waitForLoadState("networkidle").catch(() => {});
  await page.waitForTimeout(1000);
  return { page, context, problems, requests };
}

const count = (page, selector) => page.locator(selector).count();

async function featureTour(browser, name) {
  const file = preview(tour);

  for (const scheme of ["light", "dark"]) {
    console.log(`${name}, feature tour, ${scheme}`);
    const { page, context, problems, requests } = await open(browser, file, scheme);

    check("math renders", (await count(page, ".katex")) === 5, `${await count(page, ".katex")} found`);
    check("no math errors", (await count(page, ".katex-error")) === 0);
    // Fonts nothing uses yet stay unloaded, and WebKit reports a font it can't
    // load only in the console, so ask for one and check it arrived.
    const fonts = await page.evaluate(() => document.fonts.load("1em KaTeX_Main").then(
      (faces) => `${faces.filter((face) => face.status === "loaded").length} loaded`,
      (error) => String(error)));
    check("math fonts load", /^[1-9]\d* loaded$/.test(fonts), fonts);
    check("both diagrams render", (await count(page, ".diagram svg")) === 2);
    check("diagram theme follows the appearance",
      (await page.locator(".diagram").first().getAttribute("data-theme")) === (scheme === "dark" ? "dark" : "default"));
    check("code is highlighted", (await count(page, "code.hljs")) === 4, `${await count(page, "code.hljs")} found`);
    check("five alerts and a callout", (await count(page, ".markdown-alert")) === 6);
    check("callout title",
      (await page.locator(".markdown-alert-important .markdown-alert-title").last().textContent()) === "Obsidian callouts work too");
    check("table of contents", (await count(page, ".toc a")) === 8);
    check("task list", (await count(page, ".task-list-item")) === 3);
    check("footnotes", (await count(page, ".footnotes li")) === 2);
    check("front matter folds away", (await count(page, "details.front-matter")) === 1);
    check("large image becomes a figure", (await count(page, "p.figure")) === 1);
    check("copy buttons", (await count(page, ".code-copy")) === 4);
    check("emoji", (await page.textContent("h1 + p")).includes("✨"));
    check("emoji left alone in code", (await page.textContent("#content")).includes(":not_in_code:"));
    check("currency stays text", (await page.textContent("#content")).includes("Prices such as $5 and $10"));
    check("arrowheads point at this page",
      (await page.locator(".diagram svg [marker-end]").first().getAttribute("marker-end")).includes(path.basename(file)));

    await page.click("sup.footnote-ref a");
    await page.waitForTimeout(500);
    const url = new URL(page.url());
    check("footnote link stays on the page", url.pathname.endsWith(path.basename(file)) && url.hash === "#fn-preview",
      page.url());

    check("no errors", problems.length === 0, problems.join("; "));
    check("no network requests", requests.length === 0, requests.join(", "));

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(200);
    await page.screenshot({ path: path.join(shots, `${name}-${scheme}.png`), fullPage: true });
    await context.close();
  }
}

async function edgeCases(browser, name) {
  console.log(`${name}, edge cases`);
  const file = preview(path.join(here, "fixtures", "edge-cases.md"));
  const { page, context, problems } = await open(browser, file);

  check("broken diagram explains itself", (await page.textContent(".diagram-note")).includes("Parse error"));
  check("broken diagram keeps its source", (await count(page, ".diagram pre")) === 1);
  check("broken math shows an error", (await count(page, ".katex-error")) === 1);
  check("good math still renders", (await count(page, ".katex")) >= 1);
  check("unknown language stays plain", (await count(page, "code.language-hcl.hljs")) === 0);
  check("scripts in the document are blocked", (await page.title()) === "edge-cases.md", await page.title());
  check("library scripts written into the document are blocked",
    await page.evaluate(() => typeof window.confetti === "undefined" &&
      window.__violations.some((uri) => uri.includes("confetti"))));
  check("no page errors", !problems.some((p) => p.startsWith("page error")), problems.join("; "));
  await context.close();
}

async function settings(browser, name) {
  console.log(`${name}, settings`);
  const dark = configuredCopy("theme = dark\n");
  const { page, context, requests } = await open(browser, preview(tour, { srcDir: dark }), "light");

  check("theme = dark wins over a light system",
    (await page.evaluate(() => getComputedStyle(document.body).backgroundColor)) !== "rgb(255, 255, 255)");
  check("no network requests", requests.length === 0, requests.join(", "));
  await context.close();
}

const engines = [["chromium", chromium], ["webkit", webkit], ["firefox", firefox]];
for (const [name, engine] of engines) {
  let browser;
  try {
    // Honor a proxy when one is configured (some sandboxes need it).
    const proxy = process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY } : undefined;
    browser = await engine.launch({ proxy });
  } catch (error) {
    if (name !== "chromium" && !process.env.CI) {
      console.log(`Skipping ${name}: ${error.message.split("\n")[0]}`);
      continue;
    }
    throw error;
  }
  await featureTour(browser, name);
  await edgeCases(browser, name);
  await settings(browser, name);
  await browser.close();
}

if (!existsSync(path.join(shots, "chromium-light.png"))) failures++;
console.log(failures ? `\n${failures} check(s) failed` : "\nAll browser checks passed");
process.exit(failures ? 1 : 0);
