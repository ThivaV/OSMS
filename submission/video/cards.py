"""The cards Biscuit presents: the problem, the Meta models, Fireworks, the architecture, the close.

Each card is a light panel in the app's style. Its parts appear when Biscuit says them: `cue`
turns a phrase of the scene's caption into the second it is spoken.
"""

from typing import Callable

from PIL import Image, ImageDraw

from look import (
    ACCENT, ACCENT_SOFT, BORDER, CANVAS, INK, INK2, INK3, LOGO, SURFACE, box, pill, sans, serif, text_image, wrap,
)  # fmt: skip

PANEL = (1220, 900)
PAD = 64
INNER = PANEL[0] - PAD * 2

Cue = Callable[[str], float]


def _ease(a: float) -> float:
    return 1 - (1 - a) ** 3


class Card:
    """A panel whose items fade and rise into place at their times (and may leave at t1)."""

    def __init__(self):
        self.base = Image.new("RGBA", PANEL, CANVAS + (255,))
        self.items: list[tuple[Image.Image, tuple[int, int], float, float | None, bool]] = []

    def add(self, img, xy, t0=0.0, t1=None, rise=True):
        self.items.append((img, (int(xy[0]), int(xy[1])), t0, t1, rise))
        return img

    def header(self, eyebrow, title):
        self.add(text_image(eyebrow, sans(22, 650), ACCENT), (PAD, 52))
        self.add(text_image(title, serif(56, 600), INK, width=INNER, leading=1.08), (PAD, 86), 0.15)

    def frame(self, t: float) -> Image.Image:
        panel = self.base.copy()
        for img, (x, y), t0, t1, rise in self.items:
            a = _ease(max(0.0, min(1.0, (t - t0) / 0.35)))
            if t1 is not None:
                a = min(a, _ease(max(0.0, min(1.0, (t1 - t) / 0.25))))
            if a <= 0:
                continue
            if a < 1:
                img = img.copy()
                img.putalpha(img.getchannel("A").point(lambda v: int(v * a)))
            panel.alpha_composite(img, (x, y + (int((1 - a) * 14) if rise else 0)))
        return panel


def _flow(items, x0, y0, width, gap=12) -> list[tuple[int, int]]:
    """Positions for pills laid out left to right, wrapping."""
    out, x, y, row_h = [], x0, y0, 0
    for img in items:
        if x > x0 and x + img.width > x0 + width:
            x, y = x0, y + row_h + gap
            row_h = 0
        out.append((x, y))
        x += img.width + gap
        row_h = max(row_h, img.height)
    return out


def title_card(cue: Cue) -> Card:
    c = Card()
    logo = Image.open(LOGO).convert("RGBA").resize((168, 168), Image.LANCZOS)
    c.add(logo, (PAD, 250))
    c.add(text_image("OSMS", serif(128, 650), INK), (PAD + 200, 226))
    c.add(text_image("One Story, Many Sources", serif(48, 500, italic=True), INK2), (PAD + 206, 372))
    c.add(text_image("A three-minute tour, presented by Biscuit", sans(30, 500), INK3), (PAD, 520))
    c.add(text_image("Meta AI hackathon · live on the web and macOS", sans(24, 500), ACCENT), (PAD, 572))
    return c


# The same event, as three of the demo's sources headlined it on Nov 2 (story #706).
HEADLINES = [
    ("9to5Mac", "Three new iPad models are reportedly launching early next year, here’s what’s coming"),
    ("Engadget", "Apple is reportedly launching three new iPads early next year"),
    ("GSMArena", "Apple plans to refresh three iPads in the first half of 2027"),
]
TABS = ["9to5Mac", "Engadget", "GSMArena", "The Verge", "TechCrunch", "Computerworld", "Ingeniøren", "Mobilsiden",
        "A podcast", "arXiv"]  # fmt: skip
DOTS = [(29, 117, 189), (214, 69, 65), (60, 60, 60), (233, 77, 145), (10, 160, 80), (200, 30, 40), (240, 140, 0),
        (40, 110, 200), (130, 90, 220), (179, 27, 27)]  # fmt: skip


def _brand(c: Card):
    logo = Image.open(LOGO).convert("RGBA").resize((44, 44), Image.LANCZOS)
    c.add(logo, (PANEL[0] - PAD - 150, 46))
    c.add(text_image("OSMS", serif(34, 650), INK), (PANEL[0] - PAD - 96, 46))


def problem_card(cue: Cue) -> Card:
    c = Card()
    _brand(c)
    c.header("THE PROBLEM", "The same news reaches you ten times.")
    tabs = [pill(t, sans(21, 550), INK, SURFACE, BORDER, dot=DOTS[i]) for i, t in enumerate(TABS)]
    start = cue("ten times")
    for i, (img, xy) in enumerate(zip(tabs, _flow(tabs, PAD, 186, INNER))):
        c.add(img, xy, start + i * 0.12)
    c.add(text_image("One event, three headlines · Monday 2 November", sans(20, 550), INK3), (PAD, 318), cue("tech sites"))
    for i, ((who, headline), cue_at) in enumerate(zip(HEADLINES, ["tech sites", "Danish paper", "podcast"])):
        card = box((INNER, 86), radius=14)
        d = ImageDraw.Draw(card)
        tag = pill(who, sans(19, 650), INK, ACCENT_SOFT, None, pad=(14, 6))
        card.alpha_composite(tag, (20, (86 - tag.height) // 2))
        f = serif(28, 500)
        line = headline
        while f.getlength(line) > INNER - tag.width - 64:
            line = line.rsplit(" ", 1)[0] + "…"
        d.text((tag.width + 40, 24), line, font=f, fill=INK)
        c.add(card, (PAD, 350 + i * 100), cue(cue_at))
    questions = ["What’s new?", "Where do they disagree?", "Who said what?"]
    chips = [pill(q, sans(28, 650), ACCENT, ACCENT_SOFT, None, pad=(22, 12)) for q in questions]
    for img, xy, at in zip(chips, _flow(chips, PAD, 680, INNER, gap=16), ["What's new", "Where do they", "Who said"]):
        c.add(img, xy, cue(at))
    c.add(text_image("Ten tabs, one story.", serif(46, 600, italic=True), INK), (PAD, 786), cue("Ten tabs"))
    return c


MODELS = [
    ("Muse Spark", "Meta Model API", "Triage, facts, the fact check, summaries, briefing scripts and Ask", "Muse Spark triages"),
    ("Muse Spark Open", "open weights, via Fireworks", "The judge: are two reports the same event?", "Muse Spark Open"),
    ("Muse Image", "Meta Model API", "An illustration when no source has a picture", "Muse Image"),
    ("SAM 3.1", "Meta Model API", "Checks each illustration for faces, logos and text, then crops it", "SAM 3.1"),
    ("SeamlessM4T v2", "open weights", "The briefing’s voice in English and Danish; checks the Danish", "SeamlessM4T"),
    ("MMS-TTS", "open weights", "The briefing’s voice in Tamil", "MMS-TTS"),
    ("Muse Voice Transcribe", "Meta Model API", "Listens back to every English and Tamil chapter before it’s published",
     "speak the briefing"),  # fmt: skip
]


def meta_card(cue: Cue) -> Card:
    c = Card()
    c.header("META AI INSIDE", "Seven Meta models do the work.")
    times = [cue(m[3]) for m in MODELS]
    for i, (name, where, job, _) in enumerate(MODELS):
        y = 178 + i * 92
        t0 = times[i]
        t1 = times[i + 1] if i + 1 < len(times) else None
        for lit in (False, True):
            row = box((INNER, 80), fill=ACCENT_SOFT if lit else SURFACE, border=ACCENT if lit else BORDER, radius=14)
            d = ImageDraw.Draw(row)
            if lit:
                d.rounded_rectangle((0, 0, 7, 79), 3, fill=ACCENT)
            d.text((26, 12), name, font=sans(27, 700), fill=INK)
            d.text((26, 48), where, font=sans(17, 500), fill=ACCENT if lit else INK3)
            job_f = sans(23, 450)
            lines = wrap(job, job_f, INNER - 380)
            for j, line in enumerate(lines[:2]):
                d.text((360, (80 - 28 * len(lines[:2])) // 2 + j * 28), line, font=job_f, fill=INK if lit else INK2)
            if lit:  # lights up once the row has landed, in place
                c.add(row, (PAD, y), t0 + 0.35, t1, rise=False)
            else:
                c.add(row, (PAD, y), t0)
    c.add(
        text_image("Every call is logged with its model, prompt version, tokens and latency, and shown on its story.",
                   sans(20, 500), INK3, width=INNER),
        (PAD, 830), times[-1] + 0.4,
    )  # fmt: skip
    return c


# Why the judge runs on Fireworks (backend/app/config.py, DEPLOY.md, agent/guardrails.py).
WHY_FIREWORKS = [
    ("Serverless open weights", "Muse Spark Open with no GPU on our one CPU server, paid per token", "serverless"),
    ("An independent judge", "A different model, from a different provider, than Muse Spark, which writes", "independent judge"),
    ("A ready backup", "If the Meta Model API fails, the agents that find and check facts fail over to it", "ready backup"),
]


def fireworks_card(cue: Cue) -> Card:
    c = Card()
    c.header("WHERE FIREWORKS FITS", "The judge runs on Fireworks.")
    c.add(text_image("A real call from story #706’s decision log: are these two reports one event?", sans(20, 550), INK3),
          (PAD, 180), 0.3)  # fmt: skip
    receipt = box((INNER, 196), radius=14)
    d = ImageDraw.Draw(receipt)
    x = 22
    for text, f, fill in [("Same story?", sans(22, 650), INK), ("accounts/fireworks/models/muse-spark-open", sans(21, 650), ACCENT),
                          ("03:32", sans(20, 500), INK3)]:  # fmt: skip
        d.text((x, 18), text, font=f, fill=fill)
        x += int(f.getlength(text)) + 16
    d.text((22, 54), "Three new iPad models are reportedly launching early next year, here’s what’s coming · 9to5Mac",
           font=sans(18, 450), fill=INK3)  # fmt: skip
    quote = ("“Item A previews three future iPads launching next year while Item B reports Geekbench results for the "
             "already-unveiled OLED iPad mini, different announcements.”")  # fmt: skip
    y = 86
    for line in wrap(quote, sans(21, 450), INNER - 44):
        d.text((22, y), line, font=sans(21, 450), fill=INK)
        y += 28
    d.text((22, y + 8), "1143 tokens · 5.1 s", font=sans(18, 500), fill=INK3)
    c.add(receipt, (PAD, 214), 0.5)
    for i, (title, body, at) in enumerate(WHY_FIREWORKS):
        row = box((INNER, 92), radius=14, fill=ACCENT_SOFT, border=ACCENT)
        d = ImageDraw.Draw(row)
        d.ellipse((22, 26, 62, 66), fill=ACCENT)
        d.text((42, 46), str(i + 1), font=sans(22, 700), fill=SURFACE, anchor="mm")
        d.text((84, 14), title, font=sans(25, 700), fill=INK)
        d.text((84, 52), body, font=sans(20, 450), fill=INK2)
        c.add(row, (PAD, 440 + i * 108), cue(at))
    c.add(text_image("✓  Only public source text ever goes to Fireworks; a reader’s data never does.", sans(22, 600), INK),
          (PAD, 784), cue("ready backup") + 0.8)  # fmt: skip
    return c


def _node(title, body, size, fill=SURFACE, border=BORDER, title_f=None):
    img = box(size, fill=fill, border=border, radius=14)
    d = ImageDraw.Draw(img)
    d.text((18, 14), title, font=title_f or sans(23, 700), fill=INK)
    y = 14 + int((title_f or sans(23, 700)).size * 1.35)
    f = sans(17, 450)
    for line in wrap(body, f, size[0] - 36):
        d.text((18, y), line, font=f, fill=INK2)
        y += 22
    return img


def _arrow(card: Card, x0, y0, x1, y1, t0):
    w, h = abs(x1 - x0) + 24, abs(y1 - y0) + 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ax0, ay0, ax1, ay1 = 12 if x1 >= x0 else w - 12, 12 if y1 >= y0 else h - 12, 0, 0
    ax1, ay1 = ax0 + (x1 - x0), ay0 + (y1 - y0)
    d.line((ax0, ay0, ax1, ay1), fill=INK3, width=3)
    if abs(x1 - x0) >= abs(y1 - y0):
        s = 1 if x1 > x0 else -1
        d.polygon([(ax1, ay1), (ax1 - 11 * s, ay1 - 7), (ax1 - 11 * s, ay1 + 7)], fill=INK3)
    else:
        s = 1 if y1 > y0 else -1
        d.polygon([(ax1, ay1), (ax1 - 7, ay1 - 11 * s), (ax1 + 7, ay1 - 11 * s)], fill=INK3)
    card.add(img, (min(x0, x1) - 12, min(y0, y1) - 12), t0)


STAGES = [
    ("Triage", "Muse Spark", "triages"),
    ("Embed", "BGE-M3 vectors", "clusters"),
    ("Cluster", "judge: Muse Spark Open on Fireworks", "clusters"),
    ("Facts", "found, then checked: Muse Spark", "checks"),
    ("Write", "summary, briefing script: Muse Spark", "writes"),
    ("Voice", "SeamlessM4T v2, MMS-TTS; heard back before anyone hears it", "writes"),
]


def architecture_card(cue: Cue) -> Card:
    COL, GAP = 332, 48  # three columns, spanning the pipeline's lane exactly
    c = Card()
    c.header("UNDER THE HOOD", "A pipeline, not a chatbot.")
    a = cue("safe fetcher")
    c.add(_node("Sources", "Sites and feeds · podcasts · arXiv · YouTube · Mastodon, Bluesky, Reddit", (COL, 112)), (PAD, 176), a - 0.4)
    c.add(_node("Safe fetcher", "Public addresses only · every redirect re-checked · robots.txt", (COL, 112)), (PAD + COL + GAP, 176), a)
    _arrow(c, PAD + COL + 4, 232, PAD + COL + GAP - 4, 232, a)
    b = cue("FastAPI worker")
    c.add(_node("Worker + jobs queue", "Retries, one step at a time", (COL, 112)), (PAD + 2 * (COL + GAP), 176), b)
    _arrow(c, PAD + 2 * COL + GAP + 4, 232, PAD + 2 * (COL + GAP) - 4, 232, b)
    lane = box((INNER, 196), fill=(250, 249, 246), border=BORDER, radius=18)
    c.add(lane, (PAD, 320), b)
    _arrow(c, PAD + 2 * (COL + GAP) + COL // 2, 290, PAD + 2 * (COL + GAP) + COL // 2, 318, b)
    w = (INNER - 28 - 5 * 12) // 6
    for i, (name, who, at) in enumerate(STAGES):
        chip = _node(name, who, (w, 164), fill=SURFACE, border=ACCENT, title_f=sans(22, 700))
        c.add(chip, (PAD + 14 + i * (w + 12), 336), cue(at) + (0.35 if i in (2, 5) else 0))
    d = cue("One Flutter app")
    c.add(_node("SQLite + Milvus Lite", "Stories, facts and their history; vectors", (COL, 104)), (PAD, 560), d - 0.5)
    c.add(_node("FastAPI", "Short-lived tokens from Better Auth", (COL, 104)), (PAD + COL + GAP, 560), d - 0.25)
    c.add(_node("Flutter app", "One codebase: the web and macOS", (COL, 104), fill=ACCENT_SOFT, border=ACCENT), (PAD + 2 * (COL + GAP), 560), d)
    _arrow(c, PAD + COL + 4, 612, PAD + COL + GAP - 4, 612, d - 0.25)
    _arrow(c, PAD + 2 * COL + GAP + 4, 612, PAD + 2 * (COL + GAP) - 4, 612, d)
    _arrow(c, PAD + 165, 518, PAD + 165, 556, d - 0.5)
    e = cue("articles stay as links")
    c.add(text_image("✓  Links only: never the publishers’ text, pictures or audio", sans(22, 600), INK), (PAD, 700), e)
    c.add(text_image("✓  One reader’s data never reaches another", sans(22, 600), INK), (PAD, 738), e + 0.25)
    c.add(text_image("One Google Cloud VM behind Caddy, deployed keyless from GitHub Actions when the tests pass.",
                     sans(20, 500), INK3, width=INNER), (PAD, 800), e + 0.5)  # fmt: skip
    return c


def outro_card(cue: Cue) -> Card:
    c = Card()
    logo = Image.open(LOGO).convert("RGBA").resize((132, 132), Image.LANCZOS)
    c.add(logo, (PAD, 70))
    c.add(text_image("OSMS", serif(104, 650), INK), (PAD + 160, 52))
    c.add(text_image("One Story, Many Sources", serif(40, 500, italic=True), INK2), (PAD + 166, 172))
    a = cue("live today")
    c.add(text_image("Live today, open source (MIT)", sans(26, 600), INK2), (PAD, 290), a)
    c.add(text_image("github.com/ThivaV/OSMS", sans(42, 700), INK), (PAD, 326), a + 0.2)
    b = cue("Try the demo")
    c.add(text_image("Try the demo, no account needed", sans(26, 600), INK2), (PAD, 420), b)
    c.add(text_image("app.onestory-osms.duckdns.org/#/demo", sans(42, 700), ACCENT), (PAD, 456), b + 0.2)
    c.add(text_image("Web and macOS, one codebase · the judge served by Fireworks · built for the Meta AI hackathon",
                     sans(24, 500), INK3), (PAD, 556), b + 0.5)  # fmt: skip
    chips = [pill(m[0], sans(21, 600), INK, SURFACE, BORDER, pad=(16, 8)) for m in MODELS]
    for i, (img, xy) in enumerate(zip(chips, _flow(chips, PAD, 620, INNER))):
        c.add(img, xy, cue("One story") + i * 0.08)
    # The LTX-2.x licence asks for generated media to be disclosed as such.
    c.add(text_image("Biscuit is AI-generated: picture by an image model, animation and voice by LTX-2.5 (Lightricks). "
                     "Every app shot is the real app, recorded live.", sans(19, 500), INK3, width=INNER),
          (PAD, 806), cue("Biscuit out"))  # fmt: skip
    return c


CARDS = {
    "title": title_card,
    "problem": problem_card,
    "meta": meta_card,
    "fireworks": fireworks_card,
    "architecture": architecture_card,
    "outro": outro_card,
}
