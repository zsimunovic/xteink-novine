#!/usr/bin/env python3
"""Nacrtaj približni pregled ekrana aplikacije u PNG (početni, čitanje, zaključani ekran) i ikonu.

Upotreba:  python3 inkapp/pregled.py [izlazna_mapa]
Fontovi su sistemski (Arial), pa se izgled malo razlikuje od uređaja.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import test_novine as T

FONT_FILE = "/System/Library/Fonts/Supplemental/Arial.ttf"
SIZES = {"small": 17, "medium": 21, "large": 26}


class PFont:
    def __init__(self, name):
        self.name = name
        self.line_height = T.LINE_H[name]
        self.pil = ImageFont.truetype(FONT_FILE, SIZES[name])

    def measure(self, s):
        return int(self.pil.getlength(s))


class PG(T.G):
    def __init__(self):
        super().__init__()
        self.img = Image.new("L", (T.W, T.H), 255)
        self.d = ImageDraw.Draw(self.img)

    def line(self, x1, y1, x2, y2, *a):
        self.d.line([x1, y1, x2, y2], fill=0, width=1)

    def rect(self, x, y, w, h, *a):
        self.d.rectangle([x, y, x + w, y + h], outline=0, width=2)

    def text(self, x, y, s, opts=None):
        f = opts["font"] if opts is not None and opts["font"] is not None else FONTS["medium"]
        self.d.text((x, y + 2), s, font=f.pil, fill=0)


FONTS = {n: PFont(n) for n in SIZES}


def snap(lua, path):
    g = PG()
    lua.globals().on_draw(lua.globals().ctx, g)
    frame = Image.new("L", (T.W + 40, T.H + 40), 90)
    frame.paste(g.img, (20, 20))
    frame.save(path)
    return path


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    T.Font = PFont  # pravi razmaci slova
    lua, _ = T.make_lua("2026-11-25", {})
    lua.globals().on_load(lua.globals().ctx)
    print(snap(lua, out / "1-pocetni.png"))
    T.tap(lua, 200, 210 + 68 + 10)      # Hrvatska
    print(snap(lua, out / "2-hrvatska.png"))
    files = _files(lua)
    lua2, _ = T.make_lua("2026-11-25", files, lock=True)
    lua2.globals().on_load(lua2.globals().ctx)
    print(snap(lua2, out / "3-zakljucani.png"))
    icon(Path(__file__).resolve().parent / "novine" / "icon.png")


def _files(lua):
    return dict(lua.globals().FILES.items())


def icon(path):
    """96x96 crno na bijelom: presavijene novine."""
    img = Image.new("1", (96, 96), 1)
    d = ImageDraw.Draw(img)
    d.rectangle([10, 14, 86, 82], outline=0, width=4)
    d.rectangle([18, 22, 78, 34], fill=0)
    for y in (42, 50, 58, 66):
        d.line([18, y, 44, y], fill=0, width=3)
    d.rectangle([52, 42, 78, 68], outline=0, width=3)
    img.save(path)
    print(path)


if __name__ == "__main__":
    main()
