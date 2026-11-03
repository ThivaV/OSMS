"""Biscuit's clips: LTX-2.5 animates the first frame and speaks the line, picture and voice together.

Runs `ltx-2-mlx` from the modelsgoalsdataknowledge checkout, with the model pack and settings its
cartoon reels use (distilled, 8-bit, seed 7, --low-ram). One clip per process and one at a time:
the model needs most of this Mac's memory, and a separate process hands all of it back. A clip
already made is kept; delete it, or change its scene's seed, to make it again.

    python dog.py                 # every missing clip, in the order of the cut
    python dog.py outro problem   # just these
"""

import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

from scenes import BY_KEY, FRAME_RATE, SCENES, Scene

HERE = Path(__file__).resolve().parent
LTX_HOME = Path(os.environ.get("LTX_HOME", Path.home() / "src/dev/modelsgoalsdataknowledge"))
LTX = LTX_HOME / ".venv/bin/ltx-2-mlx"
PACK = LTX_HOME / ".models/video/ltx-2.5-mlx-q8"
FIRST_FRAME = HERE / "build/first-frame.png"
OUT = HERE / "build/dog"
SIZE = 576  # square; a multiple of 64, as the two-stage pipeline needs

CHARACTER = (
    "The friendly cartoon puppy in the picture, with floppy brown ears, a cream muzzle and teal headphones "
    "around its neck,"
)


def prompt(scene: Scene) -> str:
    action = (
        "waving its paw hello, then gesturing gently with small happy head tilts"
        if scene.wave
        else "lowering its paw and gesturing gently, with small happy head tilts and blinks"
    )
    return (
        f"A square animated cartoon clip, one continuous shot. {CHARACTER} sits on a plain cream background, "
        f"looks straight at the camera and talks in English with a bright, warm, cheerful young cartoon voice at "
        f"a clear, steady pace, with expressive animated mouth movements, {action}, saying, \"{scene.say}\" "
        "Smooth, simple flat 2D cartoon animation in the picture's own style and colours. No on-screen text, no "
        "captions, no logos, no music, no sound effects, no other characters."
    )


def first_frame() -> Path:
    """Biscuit waving (assets/biscuit-wave.png), cropped square around the dog."""
    if not FIRST_FRAME.exists():
        from PIL import Image

        FIRST_FRAME.parent.mkdir(parents=True, exist_ok=True)
        art = Image.open(HERE / "assets/biscuit-wave.png").convert("RGB")
        art.crop((380, 40, 1500, 1160)).resize((SIZE, SIZE), Image.LANCZOS).save(FIRST_FRAME)
    return FIRST_FRAME


def make(scene: Scene) -> Path:
    clip = OUT / f"{scene.key}.mp4"
    meta = clip.with_suffix(".json")
    text = prompt(scene)
    key = {"prompt_sha256": hashlib.sha256(text.encode()).hexdigest(), "frames": scene.frames, "seed": scene.seed}
    if clip.exists() and meta.exists() and json.loads(meta.read_text())["key"] == key:
        print(f"{scene.key}: kept")
        return clip
    OUT.mkdir(parents=True, exist_ok=True)
    partial = clip.with_name(clip.stem + ".partial.mp4")
    cmd = [
        str(LTX), "generate", "--distilled", "--model", str(PACK), "--prompt", text,
        "--height", str(SIZE), "--width", str(SIZE), "--frames", str(scene.frames),
        "--frame-rate", str(FRAME_RATE), "--seed", str(scene.seed), "--output", str(partial),
        "--image", str(first_frame()), "0", "1.0", "--low-ram",
    ]  # fmt: skip
    print(f"{scene.key}: {scene.frames} frames ({scene.frames / FRAME_RATE:.1f} s)...", flush=True)
    started = time.monotonic()
    with clip.with_suffix(".log").open("w") as log:
        done = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=90 * 60)
    if done.returncode != 0 or not partial.exists():
        sys.exit(f"{scene.key}: ltx-2-mlx failed (exit {done.returncode}); see {clip.with_suffix('.log')}")
    partial.replace(clip)
    took = round(time.monotonic() - started)
    meta.write_text(json.dumps({"key": key, "prompt": text, "took_seconds": took}, indent=2))
    print(f"{scene.key}: done in {took} s", flush=True)
    return clip


if __name__ == "__main__":
    if not LTX.exists() or not PACK.exists():
        sys.exit(f"No ltx-2-mlx or model pack under {LTX_HOME}; set LTX_HOME to the modelsgoalsdataknowledge checkout")
    for scene in [BY_KEY[k] for k in sys.argv[1:]] or SCENES:
        make(scene)
