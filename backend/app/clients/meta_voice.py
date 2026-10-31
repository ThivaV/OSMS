"""Muse Voice Transcribe (Meta Model API): speech to text, batch. Checks every briefing
chapter by transcribing it back. English and Tamil, not Danish."""

import json

import httpx

from app.config import META_API_URL, VOICE_TRANSCRIBE_ID

# Ours → the names its `languageBias` takes (a bias, not a forced language).
LANGUAGES = {"en": "English", "ta": "Tamil"}
MAX_BYTES = 32 * 1024 * 1024  # and at most 10 minutes: a chapter is far shorter


class TranscribeError(RuntimeError):
    pass


class Transcriber:
    by = VOICE_TRANSCRIBE_ID

    def __init__(self, api_key: str, *, http: httpx.Client | None = None) -> None:
        self.api_key = api_key
        self.http = http or httpx.Client(timeout=120.0)

    def handles(self, language: str) -> bool:
        return language in LANGUAGES

    def transcribe(self, wav: bytes, language: str) -> str:
        """Mono 16-bit PCM WAV at 16 or 24 kHz."""
        if len(wav) > MAX_BYTES:
            raise TranscribeError("audio too long to check")
        request = {
            "mode": "PUSH_TO_TALK",
            "model": VOICE_TRANSCRIBE_ID,
            "audioEncoding": "WAV",
            "languageBias": [LANGUAGES[language]],
        }
        try:
            response = self.http.post(
                f"{META_API_URL}/asr/transcribe",
                headers={"Authorization": f"Bearer {self.api_key}"},
                files={
                    "request": (None, json.dumps(request), "application/json"),
                    "audio": ("chapter.wav", wav, "audio/wav"),
                },
            )
        except httpx.HTTPError as error:
            raise TranscribeError(f"{VOICE_TRANSCRIBE_ID} unreachable: {type(error).__name__}") from None
        if not response.is_success:
            # Never the body: it can echo what was sent.
            raise TranscribeError(f"{VOICE_TRANSCRIBE_ID} answered {response.status_code}")
        return str(response.json().get("transcript") or "")
