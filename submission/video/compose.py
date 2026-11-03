"""Assembles the demo video, exactly three minutes: Biscuit's clips, the recordings of the app and
the cards, timed to Biscuit's words, with captions, and one line of the real briefing.

    python compose.py                 # ../osms-demo.mp4
    python compose.py --still 42.5    # one frame, build/check/still-42.5.png, to look before rendering

Needs build/dog/*.mp4 (dog.py), build/app/*.mp4 (record.mjs) and build/briefing-audio (README).
"""

import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageDraw

import cards
from look import (
    CREAM, ON_STAGE, ON_STAGE_2, W, H, circle_mask, rounded_mask, sans, serif, shadow, stage, text_image, wrap,
)  # fmt: skip
from scenes import SCENES, Scene

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
OUT = HERE.parent / "osms-demo.mp4"
FPS = 30
TOTAL = 180.0  # the hackathon's three minutes, to the frame

# Where things sit on the 1920x1080 stage.
APP = (40, 74, 1600, 900)  # the app's recording, under a browser bar
BAR_H = 40
PIP = (1620, 712, 288)  # Biscuit's circle beside the app: x, y, diameter
SIDE = (1666, 76, 234)  # the note beside the app: x, y, width
PANEL_XY = (40, 40)  # a card
BIG = (1312, 120, 560)  # Biscuit beside a card: x, y, size
CAPTION_Y = 990

# Parts of a recording to keep, in seconds: Ask's wait for its answer is cut, and the story opens sooner.
CUTS = {"story": [(2.0, None)], "ask": [(0, 5.2), (11.6, None)], "listenIn": [(0.8, None)]}
# The briefing's own voice: its chapter for story #706 opens with this sentence (SeamlessM4T v2).
LISTEN_IN = {"start": 77.65, "seconds": 3.8, "line": "“Engadget reports that Apple launched its iPad mini last week.”"}
DEMO_URL = "app.onestory-osms.duckdns.org/#/demo"
URLS = {"yours": "localhost:8080 · a local copy, signed in as a test reader"}


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=kw.pop("text", True), **kw)


def duration(path) -> float:
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)]).stdout
    return float(out.strip())


def speech_span(clip: Path) -> tuple[float, float]:
    """When Biscuit starts and stops talking in a clip."""
    log = subprocess.run(
        ["ffmpeg", "-i", str(clip), "-af", "silencedetect=noise=-38dB:d=0.3", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr  # fmt: skip
    total = duration(clip)
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", log)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", log)]
    begin = ends[0] if starts and starts[0] < 0.05 and ends else 0.0
    end = total
    # ffmpeg closes a trailing silence at the end of the file (or leaves it open).
    if starts and starts[-1] > begin and (len(ends) < len(starts) or ends[-1] > total - 0.1):
        end = starts[-1]
    return begin, end


def loudness(path: Path, start=0.0, seconds=None) -> float:
    cmd = ["ffmpeg", "-ss", str(start)] + (["-t", str(seconds)] if seconds else []) + ["-i", str(path), "-af", "ebur128", "-f", "null", "-"]
    log = subprocess.run(cmd, capture_output=True, text=True).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", log)[-1])


@dataclass
class Segment:
    key: str
    seconds: float
    layout: str  # "big" (a card), "pip" (the app), "listen-in"
    scene: Scene | None = None
    card: str | None = None
    shot: str | None = None
    speech: tuple[float, float] = (0.0, 0.0)
    captions: list[tuple[float, str]] = field(default_factory=list)

    @property
    def frames(self) -> int:
        return round(self.seconds * FPS)

    def cue(self, phrase: str) -> float:
        """The second a phrase of the caption is spoken, its words spread evenly over the speech."""
        text = self.scene.caption
        i = text.lower().find(phrase.lower())
        if i < 0:
            raise ValueError(f"{self.key}: '{phrase}' isn't in its caption")
        a, b = self.speech
        return a + (b - a) * i / len(text)


def caption_chunks(text: str, width: int, f) -> list[str]:
    """Caption lines that fit, broken after punctuation where it can."""
    chunks, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if line and f.getlength(trial) > width:
            chunks.append(line)
            line = word
        elif line and re.search(r"[.?!:]$", line) and f.getlength(line) > width * 0.45:
            chunks.append(line)
            line = word
        else:
            line = trial
    return chunks + [line] if line else chunks


def timeline() -> list[Segment]:
    segs = []
    for scene in SCENES:
        clip = BUILD / "dog" / f"{scene.key}.mp4"
        if clip.exists():
            begin, end = speech_span(clip)
            seconds = min(duration(clip), end + 0.35)
        else:  # not made yet: a still can still be looked at, from the planned length
            begin, end, seconds = 0.3, scene.seconds - 0.3, scene.seconds
        seg = Segment(scene.key, round(seconds * FPS) / FPS, scene.layout, scene, speech=(begin, end))
        if scene.shot.startswith("card:"):
            seg.card = scene.shot[5:]
        else:
            seg.shot = scene.shot[4:]
        width = 1500 if scene.layout == "pip" else 1780
        chunks = caption_chunks(scene.caption, width, sans(36, 550))
        total = sum(len(c) for c in chunks)
        at = begin
        for c in chunks:
            seg.captions.append((at, c))
            at += (end - begin) * len(c) / total
        segs.append(seg)
        if scene.key == "listen":
            seg = Segment("listenIn", LISTEN_IN["seconds"], "pip", shot="listenIn")
            seg.captions = [(0.15, LISTEN_IN["line"])]
            segs.append(seg)
    # What's left of the three minutes goes to a title before Biscuit's first line (up to 2 s,
    # when there's room for it) and to the closing card held after the last.
    spare = round(TOTAL * FPS) - sum(s.frames for s in segs)
    title = min(2 * FPS, spare - FPS)
    if title >= FPS:
        segs.insert(0, Segment("title", title / FPS, "big", card="title"))
        spare -= title
    if spare < FPS // 2:
        sys.exit(f"The cut runs {-spare / FPS + 0.5:.1f} s too long; shorten a line in scenes.py")
    segs.append(Segment("end", spare / FPS, "big", card="outro"))
    return segs


# --- Pictures ----------------------------------------------------------------------------------


def frames_of(cmd, size):
    """Reads raw RGB frames from an ffmpeg command, one Image at a time."""
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    n = size[0] * size[1] * 3
    last = None
    while True:
        buf = p.stdout.read(n)
        if len(buf) < n:
            break
        last = Image.frombytes("RGB", size, buf)
        yield last
    p.wait()
    while last is not None:  # a source that runs short holds its last frame
        yield last


def app_frames(seg: Segment):
    """The recording, cut and fitted to the segment: sped up a little if long, held if short."""
    src = BUILD / "app" / f"{seg.shot}.mp4"
    total = duration(src)
    ranges = [(a, b if b is not None else total) for a, b in CUTS.get(seg.shot, [(0, None)])]
    length = sum(b - a for a, b in ranges)
    speed = min(1.3, max(1.0, length / seg.seconds))
    parts = "".join(f"[0:v]trim={a}:{b},setpts=PTS-STARTPTS[p{i}];" for i, (a, b) in enumerate(ranges))
    joined = "".join(f"[p{i}]" for i in range(len(ranges))) + f"concat=n={len(ranges)}:v=1[c];"
    graph = (
        parts + joined
        + f"[c]setpts=PTS/{speed:.4f},fps={FPS},scale={APP[2]}:{APP[3]}:flags=lanczos,format=rgb24[v]"
    )  # fmt: skip
    cmd = ["ffmpeg", "-loglevel", "error", "-i", str(src), "-filter_complex", graph, "-map", "[v]",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]  # fmt: skip
    return frames_of(cmd, (APP[2], APP[3]))


def dog_frames(seg: Segment, size: int, crop: str):
    clip = BUILD / "dog" / f"{seg.scene.key}.mp4"
    if not clip.exists():
        clip = BUILD / "first-frame.png"
    cmd = ["ffmpeg", "-loglevel", "error", "-i", str(clip), "-vf",
           f"fps={FPS},{crop}scale={size}:{size}:flags=lanczos,format=rgb24", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]  # fmt: skip
    return frames_of(cmd, (size, size))


class Stage:
    """The fixed parts of each layout, drawn once."""

    def __init__(self):
        self.app_mask = rounded_mask((APP[2], APP[3] + BAR_H), 18)
        self.app_bottom = self.app_mask.crop((0, BAR_H, APP[2], APP[3] + BAR_H))
        self.pip_mask = circle_mask(PIP[2])
        self.big_mask = rounded_mask((BIG[2], BIG[2]), 34)
        self.panel_mask = rounded_mask(cards.PANEL, 22)

        self.pip = stage()
        shadow(self.pip, self.app_mask, (APP[0], APP[1] - BAR_H))
        ring = circle_mask(PIP[2] + 12)
        shadow(self.pip, ring, (PIP[0] - 6, PIP[1] - 6), blur=18)
        self.pip.paste((255, 255, 255), (PIP[0] - 6, PIP[1] - 6), ring)
        name = text_image("Biscuit, your guide", sans(22, 600), ON_STAGE_2, width=300, align="center")
        self.pip.paste(name, (PIP[0] + PIP[2] // 2 - 150, PIP[1] + PIP[2] + 14), name)

        self.big = stage()
        shadow(self.big, self.panel_mask, PANEL_XY)
        frame = rounded_mask((BIG[2] + 16, BIG[2] + 16), 40)
        shadow(self.big, frame, (BIG[0] - 8, BIG[1] - 8))
        self.big.paste((255, 255, 255), (BIG[0] - 8, BIG[1] - 8), frame)
        d = ImageDraw.Draw(self.big)
        d.text((BIG[0] + BIG[2] // 2, BIG[1] + BIG[2] + 40), "Biscuit", font=serif(46, 600), fill=ON_STAGE, anchor="mt")
        d.text((BIG[0] + BIG[2] // 2, BIG[1] + BIG[2] + 104), "your guide to OSMS", font=sans(24, 500), fill=ON_STAGE_2, anchor="mt")
        self.bars = {}
        self.sides = {}
        self.caps = {}

    def bar(self, url: str) -> Image.Image:
        if url not in self.bars:
            bar = Image.new("RGB", (APP[2], BAR_H), (232, 231, 228))
            d = ImageDraw.Draw(bar)
            for i, c in enumerate([(237, 106, 94), (245, 191, 79), (98, 197, 84)]):
                d.ellipse((18 + i * 22, 14, 30 + i * 22, 26), fill=c)
            f = sans(18, 500)
            w = int(f.getlength(url)) + 40
            d.rounded_rectangle(((APP[2] - w) // 2, 7, (APP[2] + w) // 2, BAR_H - 7), 13, fill=(250, 250, 248))
            d.text((APP[2] // 2, BAR_H // 2), url, font=f, fill=(90, 98, 110), anchor="mm")
            self.bars[url] = bar
        return self.bars[url]

    def side(self, label: str, points: tuple[str, ...], step: int) -> Image.Image:
        """The note beside the app: its label, and its points one by one."""
        key = (label, points, step)
        if key not in self.sides:
            x, y, w = SIDE
            img = Image.new("RGBA", (w, 620), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            f = serif(34, 600)
            yy = 0
            for line in wrap(label, f, w):
                d.text((0, yy), line, font=f, fill=ON_STAGE)
                yy += 40
            yy += 22
            pf = sans(21, 500)
            for p in points[:step]:
                d.ellipse((0, yy + 9, 9, yy + 18), fill=(150, 125, 245))
                for line in wrap(p, pf, w - 22):
                    d.text((22, yy), line, font=pf, fill=ON_STAGE_2)
                    yy += 27
                yy += 14
            self.sides[key] = img
        return self.sides[key]

    def caption(self, text: str, width: int) -> Image.Image:
        if (text, width) not in self.caps:
            f = sans(36, 550)
            lines = wrap(text, f, width)
            img = Image.new("RGBA", (width, 46 * len(lines) + 8), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            for i, line in enumerate(lines):
                d.text((width // 2 + 2, i * 46 + 2), line, font=f, fill=(0, 0, 0, 160), anchor="mt")
                d.text((width // 2, i * 46), line, font=f, fill=(255, 255, 255), anchor="mt")
            self.caps[(text, width)] = img
        return self.caps[(text, width)]


def render(segs: list[Segment], sink, only: float | None = None):
    st = Stage()
    first = Image.open(BUILD / "first-frame.png").convert("RGB").resize((BIG[2], BIG[2]), Image.LANCZOS)
    prev = None
    t_global = 0.0
    for si, seg in enumerate(segs):
        start = t_global
        t_global += seg.frames / FPS
        if only is not None and not (start <= only < t_global):
            continue
        card = None
        if seg.card:
            card = cards.CARDS[seg.card](seg.cue if seg.scene else (lambda _p: 0.0))
            if seg.key == "end":  # the closing card holds, fully drawn
                outro = next(s for s in segs if s.key == "outro")
                card = cards.CARDS["outro"](outro.cue)
        apps = app_frames(seg) if seg.shot else None
        dog = None
        if seg.scene and seg.layout == "pip":
            # Biscuit's head and shoulders, for the circle.
            dog = dog_frames(seg, PIP[2], "crop=432:432:72:0,")
        elif seg.scene:
            dog = dog_frames(seg, BIG[2], "")
        last_dog = None
        for i in range(seg.frames):
            t = i / FPS
            if only is not None and abs(start + t - only) > 0.5 / FPS:
                if apps:
                    next(apps)
                if dog:
                    next(dog)
                continue
            if seg.layout == "big":
                frame = st.big.copy()
                t_card = t + (next(s for s in segs if s.key == "outro").seconds if seg.key == "end" else 0)
                frame.paste(card.frame(t_card), PANEL_XY, st.panel_mask)
                if dog:
                    last_dog = next(dog)
                elif seg.key == "end":
                    last_dog = last_dog or Image.open(BUILD / "dog" / "outro-last.png").convert("RGB").resize((BIG[2], BIG[2]))
                else:
                    last_dog = first
                frame.paste(last_dog, BIG[:2], st.big_mask)
                width, cx = 1780, W // 2
            else:
                frame = st.pip.copy()
                frame.paste(st.bar(URLS.get(seg.key, DEMO_URL)), (APP[0], APP[1] - BAR_H), st.app_mask.crop((0, 0, APP[2], BAR_H)))
                frame.paste(next(apps), APP[:2], st.app_bottom)
                if dog:
                    frame.paste(next(dog), PIP[:2], st.pip_mask)
                else:  # the briefing speaks: Biscuit listens, headphones on
                    frame.paste(listening(st), PIP[:2], st.pip_mask)
                scene = seg.scene
                label, points = (scene.label, scene.points) if scene else (
                    "Listen in", ("The briefing’s own voice: SeamlessM4T v2", "Checked by Muse Voice Transcribe"))
                step = min(len(points), int(t / 0.6))
                side = st.side(label, points, step)
                frame.paste(side, SIDE[:2], side)
                width, cx = 1500, APP[0] + APP[2] // 2
            text = None
            for at, c in seg.captions:
                if t >= at:
                    text = c
            if text:
                cap = st.caption(text, width)
                frame.paste(cap, (cx - width // 2, CAPTION_Y - (cap.height - 54) // 2), cap)
            # A quick dissolve between segments, and a fade in and out of the whole cut.
            if prev is not None and i < 8 and seg.key != "end":
                frame = Image.blend(prev, frame, (i + 1) / 9)
            g = start + t
            fade = min(1.0, g / 0.5, (TOTAL - g) / 0.8)
            if fade < 1:
                frame = Image.blend(Image.new("RGB", (W, H)), frame, max(0.0, fade))
            if only is not None:
                frame.save(BUILD / "check" / f"still-{only}.png")
                return
            sink.write(frame.tobytes())
            if i == seg.frames - 1:
                prev = frame
        print(f"  {seg.key}: {seg.seconds:.2f} s", flush=True)


_listening = None


def listening(st) -> Image.Image:
    global _listening
    if _listening is None:
        _listening = Image.open(BUILD / "first-frame.png").convert("RGB").crop((72, 0, 504, 432)).resize((PIP[2], PIP[2]), Image.LANCZOS)
    return _listening


# --- Sound ----------------------------------------------------------------------------------


def soundtrack(segs: list[Segment]) -> Path:
    """Biscuit's voice, then the briefing's, each brought to -16 LUFS, in one 48 kHz track."""
    parts = BUILD / "audio"
    parts.mkdir(parents=True, exist_ok=True)
    listing = []
    for i, seg in enumerate(segs):
        out = parts / f"{i:02d}-{seg.key}.wav"
        d = seg.frames / FPS
        tail = f"afade=t=in:d=0.02,afade=t=out:st={max(0, d - 0.06):.3f}:d=0.06,apad,atrim=0:{d:.4f}"
        if seg.scene:
            clip = BUILD / "dog" / f"{seg.scene.key}.mp4"
            gain = -16 - loudness(clip, 0, d)
            cmd = ["-i", str(clip), "-af", f"atrim=0:{d:.4f},volume={gain:.2f}dB,alimiter=limit=0.9,{tail}"]
        elif seg.key == "listenIn":
            src = BUILD / "briefing-audio"
            gain = -16 - loudness(src, LISTEN_IN["start"], d)
            cmd = ["-ss", str(LISTEN_IN["start"]), "-t", f"{d:.4f}", "-i", str(src), "-af", f"volume={gain:.2f}dB,alimiter=limit=0.9,{tail}"]
        else:
            cmd = ["-f", "lavfi", "-t", f"{d:.4f}", "-i", "anullsrc=r=48000:cl=stereo"]
        run(["ffmpeg", "-y", "-loglevel", "error", *cmd, "-ar", "48000", "-ac", "2", "-c:a", "pcm_s16le", str(out)])
        listing.append(f"file '{out}'")
    (parts / "list.txt").write_text("\n".join(listing) + "\n")
    track = BUILD / "soundtrack.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(parts / "list.txt"), "-c", "copy", str(track)])
    return track


def main():
    segs = timeline()
    (BUILD / "check").mkdir(parents=True, exist_ok=True)
    last = BUILD / "dog" / "outro-last.png"
    run(["ffmpeg", "-y", "-loglevel", "error", "-sseof", "-0.1", "-i", str(BUILD / "dog" / "outro.mp4"), "-frames:v", "1", str(last)])
    if "--still" in sys.argv:
        render(segs, None, only=float(sys.argv[sys.argv.index("--still") + 1]))
        return
    plan = [{"key": s.key, "seconds": round(s.seconds, 3), "captions": s.captions} for s in segs]
    (BUILD / "timeline.json").write_text(json.dumps(plan, indent=2, ensure_ascii=False))
    track = soundtrack(segs)
    enc = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
         "-i", "-", "-i", str(track), "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "slow", "-crf", "18",
         "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-t", f"{TOTAL}", str(OUT)],
        stdin=subprocess.PIPE,
    )  # fmt: skip
    render(segs, enc.stdin)
    enc.stdin.close()
    enc.wait()
    print(f"{OUT}: {duration(OUT):.2f} s")


if __name__ == "__main__":
    main()
