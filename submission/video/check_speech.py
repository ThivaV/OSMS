"""Listens back to Biscuit's clips: Meta's SeamlessM4T v2 transcribes each one, compared with its line.

The same idea as OSMS's briefings, where Muse Voice Transcribe hears every chapter before a reader
does; here it runs on this Mac (facebook/seamless-m4t-v2-large from the Hugging Face cache), so it
costs nothing. LTX makes the voice from the words in the prompt and can slur a name, so a clip that
scores low is worth a look, and another seed (scenes.py) when it is wrong.

    python check_speech.py            # every clip in build/dog/
    python check_speech.py outro      # just these
"""

import difflib
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import torch
from transformers import AutoProcessor, SeamlessM4Tv2ForSpeechToText

from scenes import BY_KEY, SCENES

HERE = Path(__file__).resolve().parent
DOG = HERE / "build/dog"
MODEL = "facebook/seamless-m4t-v2-large"


def audio(clip: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", str(clip), "-ac", "1", "-ar", "16000", "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout  # fmt: skip
    return np.frombuffer(raw, dtype=np.float32)


def pitch(samples: np.ndarray, rate: int = 16000) -> float:
    """Biscuit's median pitch in Hz, from the voiced 40 ms frames: one voice should stay near one value."""
    size, found = int(rate * 0.04), []
    lo, hi = rate // 600, rate // 90
    for start in range(0, len(samples) - size, size):
        frame = samples[start : start + size] - samples[start : start + size].mean()
        if np.sqrt((frame**2).mean()) < 0.02:
            continue
        ac = np.correlate(frame, frame, "full")[size - 1 :]
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] > 0.4 * ac[0]:
            found.append(rate / lag)
    return float(np.median(found)) if found else 0.0


def words(text: str) -> list[str]:
    # Biscuit says "O S M S" and "Fast A P I"; compare letters as one word, as a listener hears them.
    text = re.sub(r"\b((?:[A-Z] ){1,4}[A-Z0-9])\b", lambda m: m.group(1).replace(" ", ""), text)
    return re.findall(r"[a-z0-9']+", text.lower())


def main(keys: list[str]) -> None:
    processor = AutoProcessor.from_pretrained(MODEL)
    model = SeamlessM4Tv2ForSpeechToText.from_pretrained(MODEL, torch_dtype=torch.float32).eval()
    report = {}
    for scene in [BY_KEY[k] for k in keys] or SCENES:
        clip = DOG / f"{scene.key}.mp4"
        if not clip.exists():
            continue
        samples = audio(clip)
        # Seamless hears about 30 s at a time; every clip is shorter.
        inputs = processor(audio=samples, sampling_rate=16000, return_tensors="pt")
        with torch.inference_mode():
            tokens = model.generate(**inputs, tgt_lang="eng", num_beams=3, max_new_tokens=200)
        heard = processor.decode(tokens[0], skip_special_tokens=True)
        score = difflib.SequenceMatcher(None, words(scene.say), words(heard)).ratio()
        hz = pitch(samples)
        report[scene.key] = {"score": round(score, 2), "pitch_hz": round(hz), "heard": heard}
        print(f"{scene.key}: {score:.2f}  {hz:.0f} Hz  heard: {heard}", flush=True)
    out = HERE / "build/speech-check.json"
    old = json.loads(out.read_text()) if out.exists() else {}
    out.write_text(json.dumps({**old, **report}, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv[1:])
