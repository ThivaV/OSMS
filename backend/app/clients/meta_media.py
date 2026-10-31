"""Muse Image and SAM 3.1 on Meta Model API: one illustration, and what is in it.

Muse Image (`POST /v1/images/generations`) has no image search to turn off: it refuses
`enable_image_search` as an unknown parameter (Oct 31). SAM 3.1 (`POST /v1/responses`)
takes one noun phrase and one image per request and answers with one record per match:
`<|box;x1=..;y1=..;x2=..;y2=..;w=..;h=..;c=..|><|mask;...|>`, comma-separated, empty
when nothing matches."""

import base64
import re
from dataclasses import dataclass

import httpx

from app.config import META_API_URL

IMAGE_MODEL = "muse-image-1.0"
SAM_MODEL = "sam-3.1"
_BOX = re.compile(r"<\|box;([^|]*)\|>")


class MediaError(RuntimeError):
    pass


@dataclass(frozen=True)
class Box:
    x1: int
    y1: int
    x2: int
    y2: int
    width: int  # the image's
    height: int
    confidence: float

    @property
    def centre(self) -> tuple[float, float]:
        return ((self.x1 + self.x2) / 2 / self.width, (self.y1 + self.y2) / 2 / self.height)


def parse_boxes(text: str) -> list[Box]:
    boxes = []
    for record in _BOX.findall(text or ""):
        fields = dict(part.split("=", 1) for part in record.split(";") if "=" in part)
        try:
            boxes.append(
                Box(
                    *(int(fields[k]) for k in ("x1", "y1", "x2", "y2", "w", "h")),
                    confidence=float(fields.get("c", 1.0)),
                )
            )
        except (KeyError, ValueError):
            continue
    return boxes


class MetaMedia:
    image_model = IMAGE_MODEL
    sam_model = SAM_MODEL

    def __init__(self, api_key: str, *, http: httpx.Client | None = None) -> None:
        self.api_key = api_key
        self.http = http or httpx.Client(timeout=180.0)

    def _post(self, path: str, body: dict) -> dict:
        try:
            response = self.http.post(f"{META_API_URL}{path}", headers={"Authorization": f"Bearer {self.api_key}"}, json=body)
        except httpx.HTTPError as error:
            raise MediaError(f"{body['model']} unreachable: {type(error).__name__}") from None
        if not response.is_success:
            # A refusal is content_policy_violation; never echo the body.
            raise MediaError(f"{body['model']} answered {response.status_code}")
        return response.json()

    def draw(self, prompt: str) -> bytes:
        """One WebP illustration."""
        body = self._post(
            "/images/generations",
            {"model": IMAGE_MODEL, "prompt": prompt, "n": 1, "size": "1024x1024", "response_format": "b64_json", "output_format": "webp"},
        )
        try:
            return base64.b64decode(body["data"][0]["b64_json"])
        except (KeyError, IndexError, ValueError):
            raise MediaError(f"{IMAGE_MODEL} returned no image") from None

    def find(self, image: bytes, phrase: str) -> list[Box]:
        """Where `phrase` appears in the WebP image."""
        body = self._post(
            "/responses",
            {
                "model": SAM_MODEL,
                "metadata": {"include_confidence": "true"},
                "input": [
                    {
                        "type": "message",
                        "role": "user",
                        "content": [
                            {"type": "input_text", "text": phrase},
                            {"type": "input_image", "image_url": "data:image/webp;base64," + base64.b64encode(image).decode()},
                        ],
                    }
                ],
            },
        )
        text = "".join(
            part.get("text", "") for item in body.get("output") or [] for part in item.get("content") or [] if isinstance(part, dict)
        )
        return parse_boxes(text)
