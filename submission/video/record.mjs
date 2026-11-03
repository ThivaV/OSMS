// Records the live web app for the demo video: a headless Chrome, driven through its
// DevTools port and the app's accessibility tree, filmed with the DevTools screencast.
//
//   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
//     --remote-debugging-port=9333 --user-data-dir=build/chrome --hide-scrollbars --mute-audio
//   node record.mjs today story ...      # each shot to build/app/<shot>.mp4
//   node record.mjs --explore <url>      # print the labels on screen and save build/app/explore.png
//
// The browser shows 1440x810 points at 4/3 scale, so frames are 1920x1080. Headless Chrome
// draws no pointer, so the page gets one of ours: a DOM arrow that follows the mouse events
// sent here, with a ring on every click. Nothing is clicked by script that a viewer couldn't.
import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const PORT = process.env.CDP_PORT ?? "9333";
const OUT = new URL("build/app/", import.meta.url).pathname;
const DEMO = process.env.DEMO_URL ?? "https://app.onestory-osms.duckdns.org/#/demo";
const LOCAL = process.env.LOCAL_URL ?? "http://localhost:8080/#/";
const W = 1440, H = 810, SCALE = 4 / 3;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --- DevTools -------------------------------------------------------------------------
const pages = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const ws = new WebSocket(pages.find((p) => p.type === "page").webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r, { once: true }));
let id = 0;
const pending = new Map();
const listeners = new Map();
ws.addEventListener("message", (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) pending.get(m.id)(m), pending.delete(m.id);
  else if (m.method && listeners.has(m.method)) listeners.get(m.method)(m.params);
});
const send = (method, params = {}) =>
  new Promise((resolve) => {
    const n = ++id;
    pending.set(n, resolve);
    ws.send(JSON.stringify({ id: n, method, params }));
  });
const evaluate = async (expression) =>
  (await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true })).result?.result?.value;

// --- The pointer --------------------------------------------------------------------------
const POINTER = `(() => {
  if (document.getElementById('osms-pointer')) return;
  const style = document.createElement('style');
  style.textContent = \`
    #osms-pointer { position: fixed; left: 0; top: 0; z-index: 2147483647; pointer-events: none;
      width: 26px; height: 26px; transform: translate(-100px, -100px); filter: drop-shadow(0 2px 3px rgba(0,0,0,.35)); }
    .osms-ring { position: fixed; z-index: 2147483646; pointer-events: none; width: 44px; height: 44px;
      margin: -22px 0 0 -22px; border-radius: 50%; border: 3px solid rgba(37, 99, 235, .85);
      animation: osms-ring .55s ease-out forwards; }
    @keyframes osms-ring { from { transform: scale(.3); opacity: 1 } to { transform: scale(1.4); opacity: 0 } }\`;
  document.head.appendChild(style);
  const p = document.createElement('div');
  p.id = 'osms-pointer';
  p.innerHTML = '<svg viewBox="0 0 26 26" width="26" height="26"><path d="M3 2 L3 21 L8.5 16 L12 24 L15.5 22.5 L12 15 L19.5 15 Z" fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg>';
  document.body.appendChild(p);
  const at = (e) => { p.style.transform = 'translate(' + (e.clientX - 3) + 'px,' + (e.clientY - 2) + 'px)'; };
  window.addEventListener('pointermove', at, true);
  window.addEventListener('mousemove', at, true);
  window.addEventListener('pointerdown', (e) => {
    const r = document.createElement('div');
    r.className = 'osms-ring'; r.style.left = e.clientX + 'px'; r.style.top = e.clientY + 'px';
    document.body.appendChild(r); setTimeout(() => r.remove(), 700);
  }, true);
})()`;

let mouse = { x: W * 0.62, y: H * 0.55 };
const mouseEvent = (type, x, y, extra = {}) =>
  send("Input.dispatchMouseEvent", { type, x, y, button: "none", pointerType: "mouse", ...extra });
const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);

// Motion follows the clock, not a step count: while the GPU is busy, each event takes longer
// to land, and a fixed number of steps would stretch the shot.
async function over(ms, step) {
  const start = Date.now();
  for (let t = 0; t < 1; ) {
    t = Math.min(1, (Date.now() - start) / ms);
    await step(ease(t));
    await sleep(12);
  }
}

async function moveTo(x, y, ms = 700) {
  const from = { ...mouse };
  await over(ms, (t) => mouseEvent("mouseMoved", from.x + (x - from.x) * t, from.y + (y - from.y) * t));
  mouse = { x, y };
}

async function clickAt(x, y, ms) {
  await moveTo(x, y, ms);
  await sleep(120);
  await mouseEvent("mousePressed", x, y, { button: "left", buttons: 1, clickCount: 1 });
  await sleep(70);
  await mouseEvent("mouseReleased", x, y, { button: "left", buttons: 0, clickCount: 1 });
}

// A smooth scroll of dy points over ms, at the pointer (or at x, y).
async function scroll(dy, ms = 1500, x = mouse.x, y = mouse.y) {
  let done = 0;
  await over(ms, async (t) => {
    const to = Math.round(dy * t);
    if (to !== done) await mouseEvent("mouseWheel", x, y, { deltaX: 0, deltaY: to - done });
    done = to;
  });
}

async function type(text) {
  for (const ch of text) {
    await send("Input.dispatchKeyEvent", { type: "keyDown", text: ch, key: ch, unmodifiedText: ch });
    await send("Input.dispatchKeyEvent", { type: "keyUp", key: ch });
    await sleep(70);
  }
}

async function press(key, code, keyCode, modifiers = 0) {
  await send("Input.dispatchKeyEvent", { type: "rawKeyDown", key, code, windowsVirtualKeyCode: keyCode, modifiers });
  await send("Input.dispatchKeyEvent", { type: "keyUp", key, code, windowsVirtualKeyCode: keyCode, modifiers });
}

// --- Finding things on screen ---------------------------------------------------------
const nodes = () =>
  evaluate(`[...document.querySelectorAll('flt-semantics')].map(n => {
    const r = n.getBoundingClientRect();
    const leaf = !n.querySelector('flt-semantics');
    const label = (n.getAttribute('aria-label') || (leaf ? n.innerText : '') || '').trim();
    return { label, x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width, h: r.height, top: r.y, left: r.x };
  }).filter(n => n.label && n.w > 0 && n.h > 0 && n.y > 0 && n.y < ${H} && n.x > 0 && n.x < ${W})`);

async function find(pattern, { within, timeout = 8000 } = {}) {
  const re = new RegExp(pattern, "i");
  const until = Date.now() + timeout;
  while (Date.now() < until) {
    const hits = (await nodes()).filter((n) => re.test(n.label) && (!within || within(n)));
    // The smallest match is the control itself, not a container that mentions it.
    if (hits.length) return hits.sort((a, b) => a.w * a.h - b.w * b.h)[0];
    await sleep(250);
  }
  throw new Error(`not on screen: ${pattern}`);
}

async function click(pattern, opts = {}) {
  const hit = await find(pattern, opts);
  await clickAt(hit.x + (opts.dx ?? 0), hit.y + (opts.dy ?? 0), opts.ms ?? 800);
  console.log("  clicked", JSON.stringify(hit.label.slice(0, 70)));
  return hit;
}

async function hover(pattern, opts = {}) {
  const hit = await find(pattern, opts);
  await moveTo(hit.x + (opts.dx ?? 0), hit.y + (opts.dy ?? 0), opts.ms ?? 800);
  return hit;
}

// Scrolls the pane under the pointer until pattern is on screen, near the top third.
async function scrollTo(pattern, { step = 260, ms = 700, tries = 14, top = H * 0.32 } = {}) {
  const re = new RegExp(pattern, "i");
  for (let i = 0; i < tries; i++) {
    const hit = (await nodes()).find((n) => re.test(n.label));
    if (hit && hit.y < H * 0.8) {
      if (Math.abs(hit.top - top) > 40) await scroll(hit.top - top, 900);
      return hit;
    }
    await scroll(step, ms);
  }
  throw new Error(`never scrolled to: ${pattern}`);
}

// --- Loading and filming -----------------------------------------------------------------
async function open(url = DEMO) {
  await send("Emulation.setDeviceMetricsOverride", { width: W, height: H, deviceScaleFactor: SCALE, mobile: false });
  // A new page every time: the same address with another #route wouldn't reload.
  await send("Page.navigate", { url: "about:blank" });
  await sleep(400);
  await send("Page.navigate", { url });
  await sleep(9000);
  await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
  await sleep(1200);
  await evaluate(POINTER);
  await mouseEvent("mouseMoved", mouse.x, mouse.y);
  await sleep(1500); // pictures
}

let frames = [];
listeners.set("Page.screencastFrame", (p) => {
  frames.push({ data: p.data, at: p.metadata.timestamp });
  send("Page.screencastFrameAck", { sessionId: p.sessionId });
});

async function film(name, actions) {
  frames = [];
  await send("Page.startScreencast", { format: "jpeg", quality: 92, maxWidth: 1920, maxHeight: 1080 });
  const started = Date.now() / 1000;
  // A still page sends no frames; a nudge of the pointer makes the first one.
  await mouseEvent("mouseMoved", mouse.x + 1, mouse.y);
  await actions();
  const stopped = Date.now() / 1000;
  await send("Page.stopScreencast");
  await sleep(300);
  const dir = join(OUT, name);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  // Each frame lasts until the next one; the last until filming stopped.
  const list = [];
  frames.forEach((f, i) => {
    const file = `${String(i).padStart(5, "0")}.jpg`;
    writeFileSync(join(dir, file), Buffer.from(f.data, "base64"));
    const next = i + 1 < frames.length ? frames[i + 1].at : Math.max(stopped, f.at + 0.04);
    list.push(`file '${file}'`, `duration ${Math.max(0.001, next - f.at).toFixed(4)}`);
  });
  list.push(`file '${String(frames.length - 1).padStart(5, "0")}.jpg'`);
  writeFileSync(join(dir, "frames.txt"), list.join("\n") + "\n");
  execFileSync("ffmpeg", [
    "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", join(dir, "frames.txt"),
    "-vf", "scale=1920:1080:flags=lanczos,fps=30,format=yuv420p", "-c:v", "libx264", "-crf", "14",
    "-preset", "slow", join(OUT, `${name}.mp4`),
  ]);
  const seconds = stopped - started;
  console.log(`${name}: ${frames.length} frames over ${seconds.toFixed(1)} s (${(frames.length / seconds).toFixed(1)} fps)`);
}

// --- The shots ----------------------------------------------------------------------------
// Story titles as the live demo has them on Nov 3; check them before recording again.
const IPAD = "Apple Launches iPad Mini";
const IMAC = "Apple unveils M6 iMac";
const CHINA = "Apple sets December China debut";

// Opens a story from the search box (the ⌘K palette), the way a reader jumps to one.
async function palette(query, title) {
  await click("^Search or jump to", { ms: 900 });
  await sleep(700);
  await type(query);
  await sleep(900);
  await click(title, { within: (n) => n.y > 120 });
  await sleep(1600);
}

const DETAIL = { x: W * 0.73, y: H * 0.5 }; // the open story's pane, where wheel events scroll it
const inDetail = (n) => n.x > W * 0.45;
const inSidebar = (n) => n.x < W * 0.18;

const SHOTS = {
  // Meet OSMS: Today, one card per event.
  async today() {
    await open();
    await film("today", async () => {
      await sleep(1800);
      await moveTo(W * 0.5, H * 0.5, 900);
      await scroll(520, 4200);
      await sleep(900);
      await scroll(560, 4200);
      await sleep(900);
      await moveTo(W * 0.4, H * 0.62, 1100);
      await sleep(1500);
    });
  },

  // One story from three sources: cited sentences, the publisher's picture, What's new.
  async story() {
    await open();
    await film("story", async () => {
      await sleep(500);
      await palette("iPad mini", IPAD);
      await sleep(1800);
      await hover("^Source: Engadget", { within: inDetail, ms: 900 });
      await sleep(1800);
      await click("^What.s new$", { within: inDetail, ms: 900 });
      await sleep(1200);
      await moveTo(W * 0.66, H * 0.42, 900);
      await sleep(2600);
    });
  },

  // Disagreements, a correction in the timeline, and a Danish quote with its translation.
  async sections() {
    await open();
    await palette("China debut", CHINA);
    await moveTo(DETAIL.x, DETAIL.y, 400);
    await film("sections", async () => {
      await sleep(400);
      await click("^Sources agree so far$", { within: inDetail, ms: 800 });
      await sleep(2000);
      await hover("^Corrected|corrected iOS 27.3", { within: inDetail, ms: 900 });
      await sleep(2200);
      await palette("M6 iMac", IMAC);
      await click("^What.s new$", { within: inDetail, ms: 800 });
      await sleep(900);
      await hover("Apple har præsenteret", { within: inDetail, ms: 900 });
      await sleep(2600);
    });
  },

  // How OSMS decided: every model call behind the story.
  async decided() {
    await open();
    await palette("iPad mini", IPAD);
    await click("^Every source$", { within: inDetail, ms: 500 });
    await sleep(1000);
    await film("decided", async () => {
      await sleep(500);
      await click("^Show the decisions$", { within: inDetail, ms: 900 });
      await sleep(1800);
      await hover("^Checked the item|Muse Spark", { within: inDetail, ms: 800 });
      await sleep(1200);
      await scroll(260, 1400);
      await hover("muse-spark-open", { within: inDetail, ms: 800 });
      await sleep(1600);
      await scroll(700, 4200);
      await sleep(1200);
      await scroll(700, 3600);
      await sleep(1000);
    });
  },

  // Listen: the morning briefing, its chapters, earlier briefings and podcasts.
  async listen() {
    await open();
    await film("listen", async () => {
      await sleep(600);
      await click("^Listen$", { within: inSidebar, ms: 900 });
      await sleep(1800);
      await hover("Apple Launches Mini Plans More iPads", { ms: 1000 });
      await sleep(1400);
      await click("^Play$", { within: (n) => n.y > H * 0.2 && n.y < H * 0.6 && n.x < W * 0.4, ms: 900 });
      await sleep(2600);
      await moveTo(W * 0.5, H * 0.55, 700);
      await scroll(520, 3000);
      await sleep(1500);
      await scroll(520, 2600);
      await sleep(1200);
    });
  },

  // The briefing's chapter for a story, from the story's own Listen button.
  async listenIn() {
    await open();
    await palette("iPad mini", IPAD);
    await moveTo(DETAIL.x, DETAIL.y, 400);
    await film("listenIn", async () => {
      await sleep(300);
      await click("^Listen$", { within: inDetail, ms: 800 });
      await sleep(4500);
    });
  },

  // Ask this story, answered from its checked facts.
  async ask() {
    await open();
    await palette("iPad mini", IPAD);
    await moveTo(DETAIL.x, DETAIL.y, 400);
    await film("ask", async () => {
      await sleep(400);
      await click("^Ask this story$", { within: inDetail, ms: 800 });
      await sleep(1200);
      await click("^What is new here\\?$", { within: inDetail, ms: 900 });
      await find("^Answered from|Source:", { within: (n) => inDetail(n) && n.y > H * 0.25, timeout: 30000 }).catch(() => null);
      await sleep(2500);
      await scroll(300, 1500);
      await sleep(3000);
    });
  },

  // Signed in, on a local copy (see README): Add a source by pasting a site, then a story
  // saved by OSMS for every device. A second take needs a fresh copy, or another site.
  async yours() {
    await open(LOCAL);
    await moveTo(W * 0.09, H * 0.55, 300);
    await film("yours", async () => {
      await sleep(400);
      await scroll(600, 900);
      await click("^Add a source$", { within: inSidebar, ms: 700 });
      await sleep(700);
      await type(process.env.SITE ?? "macrumors.com");
      await sleep(300);
      await click("^Find$", { ms: 600 });
      await find("^Subscribe$", { timeout: 20000 });
      await sleep(500);
      await hover("^Latest$", { ms: 700 });
      await sleep(1300);
      await click("^Subscribe$", { ms: 700 });
      await sleep(2000);
      await click("AI firms back shared opt-out", { within: (n) => n.x > W * 0.2 && n.x < W * 0.8 && n.y > H * 0.5, ms: 800 });
      await sleep(1600);
      await click("^Save for later$", { within: inDetail, ms: 700 });
      await sleep(800);
      await moveTo(W * 0.09, H * 0.5, 600);
      await scroll(-800, 700);
      await click("^Saved$", { within: inSidebar, ms: 600 });
      await sleep(2200);
    });
  },

  // Save and Share in the demo (kept on the page only), then Saved.
  async save() {
    await open();
    await palette("iPad mini", IPAD);
    await moveTo(DETAIL.x, DETAIL.y, 400);
    await film("save", async () => {
      await sleep(300);
      await click("^Save for later$", { within: inDetail, ms: 800 });
      await sleep(1000);
      await click("^Share$", { within: inDetail, ms: 600 });
      await sleep(1600);
      await click("^Saved$", { within: inSidebar, ms: 900 });
      await sleep(2200);
    });
  },
};

// --- Main -----------------------------------------------------------------------------------
mkdirSync(OUT, { recursive: true });
const args = process.argv.slice(2);
if (args[0] === "--explore") {
  await open(args[1] ?? DEMO);
  for (const step of args.slice(2)) {
    const [verb, ...rest] = step.split(":");
    const arg = rest.join(":");
    if (verb === "click") await click(arg);
    else if (verb === "scroll") await scroll(Number(arg), 900);
    else if (verb === "sidebar") await moveTo(W * 0.09, H * 0.6, 300), await scroll(Number(arg), 900);
    else if (verb === "wait") await sleep(Number(arg));
    else if (verb === "palette") await palette(arg.split("|")[0], arg.split("|")[1]);
    else if (verb === "type") await type(arg);
    else if (verb === "goto") await open(arg);
  }
  console.log((await nodes()).map((n) => `${Math.round(n.x)},${Math.round(n.y)} ${n.label.slice(0, 70)}`).join("\n"));
  const { result } = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(join(OUT, "explore.png"), Buffer.from(result.data, "base64"));
} else {
  for (const shot of args.length ? args : Object.keys(SHOTS)) {
    console.log(shot);
    await SHOTS[shot]();
  }
}
ws.close();
