// Makes the README's screenshots in docs/images from the feature tour: each
// one shows a few of its sections, in light and dark, in a plain window frame.
//
//   cd tests/browser && npm ci && npx playwright install webkit
//   npm run images
//
// It uses WebKit, Safari's engine, at 2x, and needs cmark-gfm. Run it on a
// Mac, so the page uses the same system font as it does for most users.

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { webkit } from "playwright";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const tour = path.join(repo, "examples", "feature-tour.md");
const images = path.join(repo, "docs", "images");

// File name, then the heading ids of the first section shown and of the
// section after the last one.
const SHOTS = [
  ["preview", "#math", "#alerts"],
  ["code", "#table", "#math"],
  ["alerts", "#alerts", "#images-details-and-footnotes"],
];

const FRAME = {
  light: { bar: "#f3f4f6", border: "#d4d8de", title: "#5b636e" },
  dark: { bar: "#1d2128", border: "#3a404a", title: "#99a2ad" },
};

execFileSync("/bin/bash", [path.join(repo, "tools", "fetch-libraries.sh")], { stdio: ["ignore", "ignore", "inherit"] });
const output = execFileSync("/bin/bash", [path.join(repo, "src", "Markdown Preview.sh"), tour], {
  input: readFileSync(tour),
  env: { ...process.env, MARKDOWN_PREVIEW_NO_OPEN: "1" },
});
const file = output.toString().split("\n")[0];

const browser = await webkit.launch();
for (const scheme of ["light", "dark"]) {
  const context = await browser.newContext({ colorScheme: scheme, viewport: { width: 1100, height: 900 }, deviceScaleFactor: 2 });
  const page = await context.newPage();
  await page.goto("file://" + file);
  await page.waitForLoadState("networkidle").catch(() => {});
  await page.waitForTimeout(1500);

  // Page coordinates, so the scroll position doesn't matter.
  const box = (selector) => page.locator(selector).evaluate((element) => {
    const rect = element.getBoundingClientRect();
    return { x: rect.x + window.scrollX, y: rect.y + window.scrollY, width: rect.width };
  });
  const column = await box("#content");

  for (const [name, first, next] of SHOTS) {
    const from = await box(first);
    const to = await box(next);
    const clip = { x: column.x - 32, y: from.y - 20, width: column.width + 64, height: to.y - from.y - 4 };
    const shot = await page.screenshot({ fullPage: true, clip });

    const colors = FRAME[scheme];
    const frame = await context.newPage();
    await frame.setContent(`<!doctype html>
      <style>
        body { margin: 0; background: transparent; }
        .window { display: inline-block; overflow: hidden; border: 1px solid ${colors.border}; border-radius: 10px; }
        .bar { position: relative; height: 32px; background: ${colors.bar}; border-bottom: 1px solid ${colors.border};
          font: 13px -apple-system, sans-serif; color: ${colors.title}; text-align: center; line-height: 32px; }
        .lights { position: absolute; left: 12px; top: 10px; display: flex; gap: 8px; }
        .lights i { width: 12px; height: 12px; border-radius: 50%; }
        img { display: block; width: ${clip.width}px; }
      </style>
      <div class="window">
        <div class="bar"><span class="lights"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i></span>feature-tour.md</div>
        <img src="data:image/png;base64,${shot.toString("base64")}">
      </div>`);
    await frame.locator("img").evaluate((img) => img.decode());
    const target = path.join(images, `${name}-${scheme}.png`);
    await frame.locator(".window").screenshot({ path: target, omitBackground: true });
    await frame.close();
    console.log(`Wrote ${path.relative(repo, target)}`);
  }
  await context.close();
}
await browser.close();
