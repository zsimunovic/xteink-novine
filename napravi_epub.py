#!/usr/bin/env python3
"""Složi EPUB novine za Xteink X4 Pro iz JSON izdanja.

Upotreba:  python3 napravi_epub.py izdanja/2026-11-25.json
Rezultat:  epub/Novine-2026-11-25.epub
"""
import io
import json
import sys
import uuid
import zipfile
from datetime import date
from html import escape
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONTS = Path("/System/Library/Fonts/Supplemental")
MJESECI = ["siječnja", "veljače", "ožujka", "travnja", "svibnja", "lipnja", "srpnja",
           "kolovoza", "rujna", "listopada", "studenoga", "prosinca"]
DANI = ["ponedjeljak", "utorak", "srijeda", "četvrtak", "petak", "subota", "nedjelja"]

CSS = """
body { font-family: serif; margin: 0 0.4em; line-height: 1.35; }
h1 { font-size: 1.5em; margin: 0.2em 0 0.1em; text-align: center; }
h2 { font-size: 1.25em; margin: 0.4em 0 0.6em; padding-bottom: 0.2em; border-bottom: 2px solid #000; }
h3 { font-size: 1.05em; margin: 1em 0 0.25em; }
p { margin: 0 0 0.3em; text-align: left; }
.datum { text-align: center; font-style: italic; margin-bottom: 0.8em; }
.izvor { font-size: 0.8em; font-style: italic; color: #444; margin-bottom: 0.6em; }
ul.ukratko { padding-left: 1.1em; margin: 0.4em 0; }
ul.ukratko li { margin-bottom: 0.5em; }
.vrijeme { border: 1px solid #000; padding: 0.3em 0.5em; margin: 0.4em 0 0.6em; }
.zasto { font-size: 0.9em; margin: 0.15em 0 0.3em 0.6em; padding-left: 0.4em; border-left: 2px solid #000; }
.zanimljivost { font-style: italic; margin: 0.8em 0.6em; }
.autor { text-align: right; margin-right: 0.6em; }
ol.sadrzaj { padding-left: 1.3em; }
ol.sadrzaj li { margin-bottom: 0.3em; }
hr { border: 0; border-top: 1px solid #000; margin: 0.8em 0; }
"""


def lijepi_datum(d: date) -> str:
    return f"{DANI[d.weekday()]}, {d.day}. {MJESECI[d.month - 1]} {d.year}."


def xhtml(title: str, body: str) -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" '
        'lang="hr" xml:lang="hr">\n'
        f'<head><meta charset="utf-8"/><title>{escape(title)}</title>'
        '<link rel="stylesheet" type="text/css" href="stil.css"/></head>\n'
        f'<body>\n{body}\n</body></html>\n'
    )


def naslovnica(izd: dict, d: date) -> bytes:
    """Siva JPG naslovnica 480x800 (rezolucija X4 Pro)."""
    W, H = 480, 800
    img = Image.new("L", (W, H), 255)
    dr = ImageDraw.Draw(img)

    linux = {  # zamjene kad nema macOS fontova (npr. u oblaku)
        "Georgia.ttf": "DejaVuSerif.ttf",
        "Georgia Bold.ttf": "DejaVuSerif-Bold.ttf",
        "Georgia Italic.ttf": "DejaVuSerif-Italic.ttf",
    }

    def font(name, size):
        kandidati = [FONTS / name]
        for d in ("/usr/share/fonts/truetype/dejavu", "/usr/share/fonts/dejavu"):
            kandidati.append(Path(d) / linux.get(name, "DejaVuSerif.ttf"))
            kandidati.append(Path(d) / "DejaVuSerif.ttf")
        for k in kandidati:
            try:
                return ImageFont.truetype(str(k), size)
            except OSError:
                continue
        return ImageFont.load_default(size=size)

    def centar(y, text, f):
        w = dr.textlength(text, font=f)
        dr.text(((W - w) / 2, y), text, font=f, fill=0)

    dr.rectangle([20, 20, W - 20, H - 20], outline=0, width=3)
    centar(70, "NOVINE", font("Georgia Bold.ttf", 72))
    centar(160, izd.get("naslov", "Jutarnji pregled"), font("Georgia Italic.ttf", 30))
    dr.line([60, 215, W - 60, 215], fill=0, width=2)
    centar(230, lijepi_datum(d), font("Georgia.ttf", 24))
    dr.line([60, 270, W - 60, 270], fill=0, width=2)

    f = font("Georgia.ttf", 21)
    y = 300
    for r in izd["rubrike"]:
        centar(y, r["naziv"], f)
        y += 36
    centar(H - 80, f"{sum(len(r['clanci']) for r in izd['rubrike'])} vijesti", font("Georgia Italic.ttf", 20))

    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=90)
    return buf.getvalue()


def napravi(json_path: Path) -> Path:
    izd = json.loads(json_path.read_text(encoding="utf-8"))
    d = date.fromisoformat(izd["datum"])
    title = f"Novine – {d.day}. {MJESECI[d.month - 1]} {d.year}."
    uid = f"urn:uuid:{uuid.uuid5(uuid.NAMESPACE_URL, 'xteink-novine/' + izd['datum'])}"

    # --- poglavlja ---
    chapters = []  # (id, file, naslov, xhtml)
    ukratko = "".join(f"<li>{escape(t)}</li>" for t in izd["ukratko"])
    sadrzaj = "".join(
        f'<li><a href="r{i}.xhtml">{escape(r["naziv"])}</a></li>'
        for i, r in enumerate(izd["rubrike"], 1)
    )
    prva = (
        f'<h1>{escape(izd.get("naslov", "Novine"))}</h1>'
        f'<p class="datum">{escape(lijepi_datum(d))}<br/>{escape(izd.get("razdoblje", ""))}</p>'
        + (f'<p class="vrijeme"><b>Vrijeme:</b> {escape(izd["vrijeme"])}</p>' if izd.get("vrijeme") else "")
        + f'<h2>Ukratko</h2><ul class="ukratko">{ukratko}</ul>'
        f'<hr/><h3>Sadržaj</h3><ol class="sadrzaj">{sadrzaj}</ol>'
    )
    chapters.append(("uvod", "uvod.xhtml", "Ukratko", xhtml("Ukratko", prva)))

    for i, r in enumerate(izd["rubrike"], 1):
        body = [f'<h2>{escape(r["naziv"])}</h2>']
        for c in r["clanci"]:
            body.append(f'<h3>{escape(c["naslov"])}</h3>')
            body.append(f'<p>{escape(c["tekst"])}</p>')
            if c.get("zasto"):
                body.append(f'<p class="zasto"><b>Zašto je važno:</b> {escape(c["zasto"])}</p>')
            if c.get("izvor"):
                body.append(f'<p class="izvor">Izvor: {escape(c["izvor"])}</p>')
        chapters.append((f"r{i}", f"r{i}.xhtml", r["naziv"], xhtml(r["naziv"], "\n".join(body))))

    zan = izd.get("zanimljivost")
    if zan:
        kraj = f'<h2>Za kraj</h2><p class="zanimljivost">{escape(zan["tekst"])}</p>'
        if zan.get("autor"):
            kraj += f'<p class="autor">— {escape(zan["autor"])}</p>'
        chapters.append(("kraj", "kraj.xhtml", "Za kraj", xhtml("Za kraj", kraj)))

    # --- nav (EPUB3) i toc.ncx (EPUB2, za starije čitače) ---
    nav_li = "".join(f'<li><a href="{f}">{escape(n)}</a></li>' for _, f, n, _ in chapters)
    nav = xhtml("Sadržaj", f'<nav epub:type="toc" id="toc"><h2>Sadržaj</h2><ol>{nav_li}</ol></nav>')
    ncx_points = "".join(
        f'<navPoint id="np{k}" playOrder="{k}"><navLabel><text>{escape(n)}</text></navLabel>'
        f'<content src="{f}"/></navPoint>'
        for k, (_, f, n, _) in enumerate(chapters, 1)
    )
    ncx = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
        f'<head><meta name="dtb:uid" content="{uid}"/></head>'
        f'<docTitle><text>{escape(title)}</text></docTitle>'
        f'<navMap>{ncx_points}</navMap></ncx>'
    )

    manifest = "".join(
        f'<item id="{i}" href="{f}" media-type="application/xhtml+xml"/>' for i, f, _, _ in chapters
    )
    spine = "".join(f'<itemref idref="{i}"/>' for i, _, _, _ in chapters)
    opf = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="hr">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        f'<dc:identifier id="bookid">{uid}</dc:identifier>'
        f'<dc:title>{escape(title)}</dc:title>'
        '<dc:creator>Jutarnji pregled</dc:creator>'
        '<dc:language>hr</dc:language>'
        f'<dc:date>{izd["datum"]}</dc:date>'
        f'<meta property="dcterms:modified">{izd["datum"]}T05:00:00Z</meta>'
        '<meta name="cover" content="cover-img"/>'
        '</metadata><manifest>'
        '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
        '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
        '<item id="css" href="stil.css" media-type="text/css"/>'
        '<item id="cover-img" href="naslovnica.jpg" media-type="image/jpeg" properties="cover-image"/>'
        '<item id="cover" href="naslovnica.xhtml" media-type="application/xhtml+xml"/>'
        f'{manifest}</manifest>'
        f'<spine toc="ncx"><itemref idref="cover"/>{spine}</spine></package>'
    )
    cover_page = xhtml(
        title,
        '<div style="text-align:center"><img src="naslovnica.jpg" alt="Naslovnica" '
        'style="max-width:100%;max-height:100%"/></div>',
    )

    out_dir = ROOT / "epub"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / f"Novine-{izd['datum']}.epub"
    cover_jpg = naslovnica(izd, d)
    cov_dir = ROOT / "naslovnice"
    cov_dir.mkdir(exist_ok=True)
    (cov_dir / f"Novine-{izd['datum']}.jpg").write_bytes(cover_jpg)
    with zipfile.ZipFile(out, "w") as z:
        z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr(
            "META-INF/container.xml",
            '<?xml version="1.0"?><container version="1.0" '
            'xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>'
            '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>'
            '</rootfiles></container>',
            compress_type=zipfile.ZIP_DEFLATED,
        )
        files = {
            "content.opf": opf, "nav.xhtml": nav, "toc.ncx": ncx, "stil.css": CSS,
            "naslovnica.xhtml": cover_page,
        }
        files.update({f: x for _, f, _, x in chapters})
        for name, content in files.items():
            z.writestr(f"OEBPS/{name}", content, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/naslovnica.jpg", cover_jpg, compress_type=zipfile.ZIP_DEFLATED)
    return out


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(napravi(Path(sys.argv[1])))
