// Draws OSMS's app icons from the SVGs in this folder, with headless Chrome and nothing
// else: each SVG fills a viewport of the icon's exact size on a transparent background.
//
//   make icons      (or: node frontend/assets/brand/render.mjs)
//
// Small sizes use the simplified mark (osms-icon-small.svg, osms-favicon.svg): four thin
// threads vanish at 16 px.
import { spawn } from "node:child_process";
import { copyFileSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const frontend = join(here, "..", "..");
const chrome = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const mac = join(frontend, "macos/Runner/Assets.xcassets/AppIcon.appiconset");
const web = join(frontend, "web");

const targets = [
  ["osms-icon-small.svg", 16, join(mac, "app_icon_16.png")],
  ["osms-icon-small.svg", 32, join(mac, "app_icon_32.png")],
  ["osms-icon-small.svg", 64, join(mac, "app_icon_64.png")],
  ["osms-icon.svg", 128, join(mac, "app_icon_128.png")],
  ["osms-icon.svg", 256, join(mac, "app_icon_256.png")],
  ["osms-icon.svg", 512, join(mac, "app_icon_512.png")],
  ["osms-icon.svg", 1024, join(mac, "app_icon_1024.png")],
  ["osms-favicon.svg", 32, join(web, "favicon.png")],
  ["osms-icon.svg", 192, join(web, "icons/Icon-192.png")],
  ["osms-icon.svg", 512, join(web, "icons/Icon-512.png")],
  ["osms-icon-maskable.svg", 192, join(web, "icons/Icon-maskable-192.png")],
  ["osms-icon-maskable.svg", 512, join(web, "icons/Icon-maskable-512.png")],
  ["osms-icon-maskable.svg", 180, join(web, "icons/apple-touch-icon.png")],
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const profile = mkdtempSync(join(tmpdir(), "osms-icons-"));
const port = 9400 + Math.floor(Math.random() * 400);
const browser = spawn(chrome, ["--headless=new", `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, "about:blank"], {
  stdio: "ignore",
});

try {
  let pages = [];
  for (let i = 0; i < 50 && !pages.some((p) => p.type === "page"); i++) {
    await sleep(200);
    pages = await fetch(`http://127.0.0.1:${port}/json/list`).then((r) => r.json()).catch(() => []);
  }
  const page = pages.find((p) => p.type === "page");
  if (!page) throw new Error(`Chrome didn't start (${chrome})`);
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve) => ws.addEventListener("open", resolve, { once: true }));
  let id = 0;
  const pending = new Map();
  ws.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    pending.get(message.id)?.(message);
  });
  const send = (method, params = {}) =>
    new Promise((resolve) => {
      pending.set(++id, resolve);
      ws.send(JSON.stringify({ id, method, params }));
    });

  await send("Emulation.setDefaultBackgroundColorOverride", { color: { r: 0, g: 0, b: 0, a: 0 } });
  for (const [svg, size, out] of targets) {
    await send("Emulation.setDeviceMetricsOverride", { width: size, height: size, deviceScaleFactor: 1, mobile: false });
    await send("Page.navigate", { url: pathToFileURL(join(here, svg)).href });
    await sleep(400);
    const { result } = await send("Page.captureScreenshot", { format: "png", clip: { x: 0, y: 0, width: size, height: size, scale: 1 } });
    writeFileSync(out, Buffer.from(result.data, "base64"));
    console.log(`${String(size).padStart(4)} px  ${svg.padEnd(24)} → ${out.slice(frontend.length + 1)}`);
  }
  copyFileSync(join(here, "osms-favicon.svg"), join(web, "favicon.svg"));
  console.log("        osms-favicon.svg         → web/favicon.svg");
  ws.close();
} finally {
  browser.kill();
  await sleep(300);
  rmSync(profile, { recursive: true, force: true });
}
