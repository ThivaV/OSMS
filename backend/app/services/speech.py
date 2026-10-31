"""The briefing's voice: Meta's open speech models, run by the worker. SeamlessM4T v2
speaks English and Danish (its text-to-speech-translation task, same language in and
out); MMS-TTS speaks Tamil, which SeamlessM4T can't. Both are CC-BY-NC 4.0: the demo
is fine, never sell the audio. Weights download on first use (`uv sync --extra models`).

Every chapter is checked by transcribing it back (Muse Voice Transcribe; Danish, which
it doesn't cover, by SeamlessM4T's own speech recognition) and comparing with the script."""

import io
import re
import unicodedata
import wave
from difflib import SequenceMatcher
from typing import ClassVar, Protocol

import numpy as np

RATE = 16_000  # both models speak at 16 kHz; Muse Voice Transcribe takes 16 or 24 kHz
PAUSE_S = 0.35  # between sentences
CHAPTER_PAUSE_S = 0.9

#: How close the transcript must be to the script, by characters (spaces and punctuation
#: ignored, so it works for Tamil's long words too). Provisional, like every threshold:
#: the author sets it from real chapters.
CHECK_SIMILARITY = 0.8


class Voice(Protocol):
    def speak(self, text: str, language: str, *, attempt: int = 0) -> np.ndarray: ...


class Checker(Protocol):
    by: str

    def handles(self, language: str) -> bool: ...

    def transcribe(self, wav: bytes, language: str) -> str: ...


def silence(seconds: float) -> np.ndarray:
    return np.zeros(int(RATE * seconds), dtype=np.float32)


def wav_bytes(audio: np.ndarray) -> bytes:
    pcm = (np.clip(audio, -1.0, 1.0) * 32767).astype("<i2")
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    return buffer.getvalue()


def _letters(text: str) -> str:
    text = unicodedata.normalize("NFC", text).casefold()
    return "".join(ch for ch in text if unicodedata.category(ch)[0] in "LMN")


def similarity(script: str, transcript: str) -> float:
    a, b = _letters(script), _letters(transcript)
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b, autojunk=False).ratio()


def sentences_of(text: str) -> list[str]:
    return [s for s in (part.strip() for part in re.split(r"(?<=[.!?।])\s+", text)) if s]


class MetaSpeech:
    """SeamlessM4T v2 (en, da) and MMS-TTS (ta), loaded on first use on the Mac's GPU."""

    SEAMLESS = "facebook/seamless-m4t-v2-large"
    MMS: ClassVar[dict[str, str]] = {"ta": "facebook/mms-tts-tam"}
    SEAMLESS_LANGS: ClassVar[dict[str, str]] = {"en": "eng", "da": "dan"}
    SPEAKERS = (4, 11)  # a remake uses the next voice

    def __init__(self) -> None:
        self._seamless = None
        self._mms: dict[str, tuple] = {}

    def _torch(self):
        import torch

        device = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
        return torch, device

    def _seamless_model(self):
        if self._seamless is None:
            from transformers import AutoProcessor, SeamlessM4Tv2Model

            torch, device = self._torch()
            dtype = torch.float16 if device != "cpu" else torch.float32
            model = SeamlessM4Tv2Model.from_pretrained(self.SEAMLESS, torch_dtype=dtype).to(device)
            self._seamless = (AutoProcessor.from_pretrained(self.SEAMLESS), model, device)
        return self._seamless

    def speak(self, text: str, language: str, *, attempt: int = 0) -> np.ndarray:
        parts: list[np.ndarray] = []
        for sentence in sentences_of(text):
            parts += [self._sentence(sentence, language, attempt), silence(PAUSE_S)]
        return np.concatenate(parts[:-1]) if parts else silence(0.1)

    def _sentence(self, text: str, language: str, attempt: int) -> np.ndarray:
        torch, _ = self._torch()
        if language in self.SEAMLESS_LANGS:
            processor, model, device = self._seamless_model()
            lang = self.SEAMLESS_LANGS[language]
            inputs = processor(text=text, src_lang=lang, return_tensors="pt").to(device)
            with torch.no_grad():
                # use_cache=False: transformers 5's cache breaks SeamlessM4T v2's generate.
                out = model.generate(
                    **inputs, tgt_lang=lang, speaker_id=self.SPEAKERS[attempt % 2], generate_speech=True, use_cache=False
                )
            return out[0].float().cpu().numpy().squeeze().astype(np.float32)
        if language in self.MMS:
            from transformers import AutoTokenizer, VitsModel

            if language not in self._mms:
                self._mms[language] = (AutoTokenizer.from_pretrained(self.MMS[language]), VitsModel.from_pretrained(self.MMS[language]))
            tokenizer, vits = self._mms[language]
            torch.manual_seed(attempt)  # VITS samples its timing: a remake differs
            with torch.no_grad():
                return vits(**tokenizer(text, return_tensors="pt")).waveform[0].numpy().astype(np.float32)
        raise ValueError(f"no voice for {language!r}")


class SeamlessListener:
    """Danish, which Muse Voice Transcribe doesn't cover: SeamlessM4T v2's own speech
    recognition. The same model family that spoke it, so a weaker check; it says so."""

    by = "seamless-m4t-v2-large (speech recognition)"

    def __init__(self, speech: MetaSpeech) -> None:
        self.speech = speech

    def handles(self, language: str) -> bool:
        return language == "da"

    def transcribe(self, wav: bytes, language: str) -> str:
        torch, _ = self.speech._torch()
        processor, model, device = self.speech._seamless_model()
        with wave.open(io.BytesIO(wav)) as audio:
            samples = np.frombuffer(audio.readframes(audio.getnframes()), dtype="<i2").astype(np.float32) / 32767
        inputs = processor(audio=samples, sampling_rate=RATE, return_tensors="pt").to(device)
        inputs["input_features"] = inputs["input_features"].to(model.dtype)
        with torch.no_grad():
            out = model.generate(**inputs, tgt_lang="dan", generate_speech=False, use_cache=False)
        return processor.batch_decode(out.sequences, skip_special_tokens=True)[0]
