"""The video's look: the app's own fonts and colours, and the drawing helpers the cards share."""

from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
FONTS = HERE.parent.parent / "frontend/assets/fonts"
INTER = FONTS / "inter/Inter-Variable.ttf"
SERIF = FONTS / "newsreader/Newsreader-Variable.ttf"
SERIF_ITALIC = FONTS / "newsreader/Newsreader-Italic-Variable.ttf"
LOGO = HERE.parent.parent / "frontend/web/icons/Icon-512.png"

W, H = 1920, 1080

# The app's light palette, sampled from the live site.
INK = (20, 32, 46)
INK2 = (74, 88, 104)
INK3 = (110, 122, 136)
CANVAS = (247, 246, 242)
SURFACE = (255, 255, 255)
BORDER = (222, 226, 232)
ACCENT = (98, 64, 214)
ACCENT_SOFT = (237, 233, 251)
# The stage around the app: deep navy, so the light app reads as the subject.
STAGE_TOP = (19, 28, 45)
STAGE_BOTTOM = (8, 13, 23)
ON_STAGE = (236, 240, 246)
ON_STAGE_2 = (160, 172, 190)
CREAM = (255, 237, 194)  # Biscuit's own background


@lru_cache(maxsize=None)
def font(path: Path, size: int, weight: int = 400) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), size)
    axes = []
    for axis in f.get_variation_axes():
        name = axis.get("name", b"")
        name = (name.decode(errors="ignore") if isinstance(name, bytes) else str(name)).lower()
        if "weight" in name:
            axes.append(max(axis["minimum"], min(axis["maximum"], weight)))
        elif "optical" in name:
            axes.append(max(axis["minimum"], min(axis["maximum"], size)))
        else:
            axes.append(axis["default"])
    if axes:
        f.set_variation_by_axes(axes)
    return f


def sans(size, weight=400):
    return font(INTER, size, weight)


def serif(size, weight=500, italic=False):
    return font(SERIF_ITALIC if italic else SERIF, size, weight)


def rounded_mask(size, radius, scale=4) -> Image.Image:
    """An antialiased rounded rectangle (drawn large, then shrunk)."""
    w, h = size
    big = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius * scale, fill=255)
    return big.resize((w, h), Image.LANCZOS)


def circle_mask(d, scale=4) -> Image.Image:
    big = Image.new("L", (d * scale, d * scale), 0)
    ImageDraw.Draw(big).ellipse((0, 0, d * scale - 1, d * scale - 1), fill=255)
    return big.resize((d, d), Image.LANCZOS)


def shadow(canvas: Image.Image, mask: Image.Image, xy, blur=28, offset=(0, 14), opacity=0.55):
    """A soft drop shadow under mask at xy, drawn into canvas."""
    pad = blur * 3
    sh = Image.new("L", (mask.width + pad * 2, mask.height + pad * 2), 0)
    sh.paste(mask, (pad, pad))
    sh = sh.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * opacity))
    black = Image.new("RGB", sh.size, (0, 0, 0))
    canvas.paste(black, (xy[0] - pad + offset[0], xy[1] - pad + offset[1]), sh)


def stage() -> Image.Image:
    """The navy backdrop, lit a little from the top left."""
    top, bottom = Image.new("RGB", (W, H), STAGE_TOP), Image.new("RGB", (W, H), STAGE_BOTTOM)
    ramp = Image.linear_gradient("L").resize((W, H)).rotate(-28, expand=False, fillcolor=255)
    return Image.composite(bottom, top, ramp)


def wrap(text: str, f: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if f.getlength(trial) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line] if line else lines


def text_block(draw, xy, text, f, fill, width, leading=1.22) -> int:
    """Draws wrapped text; returns its height."""
    x, y = xy
    step = int(f.size * leading)
    lines = wrap(text, f, width)
    for i, line in enumerate(lines):
        draw.text((x, y + i * step), line, font=f, fill=fill)
    return step * len(lines)


def text_image(text, f, fill, width=None, leading=1.22, align="left") -> Image.Image:
    lines = wrap(text, f, width) if width else [text]
    step = int(f.size * leading)
    w = int(max(f.getlength(line) for line in lines)) + 4
    img = Image.new("RGBA", (width or w, step * len(lines) + int(f.size * 0.35)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, line in enumerate(lines):
        x = (img.width - f.getlength(line)) / 2 if align == "center" else 0
        d.text((x, i * step), line, font=f, fill=fill)
    return img


def pill(text, f, fg, bg, border=None, pad=(18, 9), radius=None, dot=None) -> Image.Image:
    tw = int(f.getlength(text))
    dot_w = int(f.size * 0.9) if dot else 0
    w, h = tw + pad[0] * 2 + dot_w, int(f.size * 1.25) + pad[1] * 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = radius if radius is not None else h // 2
    d.rounded_rectangle((0, 0, w - 1, h - 1), r, fill=bg, outline=border, width=2 if border else 0)
    if dot:
        s = int(f.size * 0.45)
        cy = h // 2
        d.ellipse((pad[0], cy - s // 2, pad[0] + s, cy + s // 2), fill=dot)
    d.text((pad[0] + dot_w, pad[1] + int(f.size * 0.05)), text, font=f, fill=fg)
    return img


def box(size, fill=SURFACE, border=BORDER, radius=16, width=2) -> Image.Image:
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=fill, outline=border, width=width)
    return img
