#!/usr/bin/env python3
"""Složi OPDS katalog (opds.xml) i index.html iz izdanja u mapi izdanja/.

Upotreba:  python3 napravi_katalog.py
Adresa stranice čita se iz config.json ("base_url").
"""
import json
import uuid
from datetime import date, datetime, timezone
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CFG = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
BASE = CFG["base_url"].rstrip("/") + "/"
MAX_IZDANJA = CFG.get("max_izdanja", 14)
MJESECI = ["siječnja", "veljače", "ožujka", "travnja", "svibnja", "lipnja", "srpnja",
           "kolovoza", "rujna", "listopada", "studenoga", "prosinca"]
NS = "xteink-novine/"


def izdanja():
    out = []
    for p in sorted((ROOT / "izdanja").glob("*.json"), reverse=True):
        izd = json.loads(p.read_text(encoding="utf-8"))
        if (ROOT / "epub" / f"Novine-{izd['datum']}.epub").exists():
            out.append(izd)
    return out[:MAX_IZDANJA]


def naslov(izd):
    d = date.fromisoformat(izd["datum"])
    return f"Novine – {d.day}. {MJESECI[d.month - 1]} {d.year}."


def main():
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lista = izdanja()
    kind = "application/atom+xml;profile=opds-catalog;kind=acquisition"
    entries = []
    for izd in lista:
        datum = izd["datum"]
        epub = f"{BASE}epub/Novine-{datum}.epub"
        cover = f"{BASE}naslovnice/Novine-{datum}.jpg"
        summary = " • ".join(izd.get("ukratko", [])[:3])
        entries.append(f"""  <entry>
    <title>{escape(naslov(izd))}</title>
    <id>urn:uuid:{uuid.uuid5(uuid.NAMESPACE_URL, NS + datum)}</id>
    <updated>{datum}T05:00:00Z</updated>
    <author><name>Jutarnji pregled</name></author>
    <dc:language>hr</dc:language>
    <dc:issued>{datum}</dc:issued>
    <summary>{escape(summary)}</summary>
    <link rel="http://opds-spec.org/acquisition" href="{epub}" type="application/epub+zip"/>
    <link rel="http://opds-spec.org/image" href="{cover}" type="image/jpeg"/>
    <link rel="http://opds-spec.org/image/thumbnail" href="{cover}" type="image/jpeg"/>
  </entry>""")

    feed = f"""<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/terms/" xmlns:opds="http://opds-spec.org/2010/catalog">
  <id>urn:uuid:{uuid.uuid5(uuid.NAMESPACE_URL, NS + 'katalog')}</id>
  <title>Novine</title>
  <subtitle>Dnevni pregled vijesti za Xteink</subtitle>
  <updated>{now}</updated>
  <author><name>Jutarnji pregled</name></author>
  <link rel="self" href="{BASE}opds.xml" type="{kind}"/>
  <link rel="start" href="{BASE}opds.xml" type="{kind}"/>
{chr(10).join(entries)}
</feed>
"""
    (ROOT / "opds.xml").write_text(feed, encoding="utf-8")

    li = "\n".join(
        f'<li><a href="epub/Novine-{i["datum"]}.epub">{escape(naslov(i))}</a></li>' for i in lista
    )
    html = f"""<!doctype html>
<html lang="hr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Novine</title>
<style>body{{font-family:Georgia,serif;max-width:36rem;margin:2rem auto;padding:0 1rem;line-height:1.5}}code{{background:#eee;padding:.1em .3em}}</style>
</head><body>
<h1>Novine</h1>
<p>Dnevni pregled vijesti za e-čitač. OPDS katalog: <code>{BASE}opds.xml</code></p>
<ul>
{li}
</ul>
</body></html>
"""
    (ROOT / "index.html").write_text(html, encoding="utf-8")
    print(f"opds.xml: {len(lista)} izdanja")


if __name__ == "__main__":
    main()
