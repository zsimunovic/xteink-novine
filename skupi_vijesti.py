#!/usr/bin/env python3
"""Skupi vijesti iz RSS izvora (zadnjih N sati) i prognozu za Zagreb.

Upotreba:  python3 skupi_vijesti.py [sati=26] > /tmp/vijesti.txt
Ispisuje sažet tekstualni popis koji Claude čita da napiše izdanje.
"""
import html
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CFG = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
SATI = int(sys.argv[1]) if len(sys.argv) > 1 else 26
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
ATOM = "{http://www.w3.org/2005/Atom}"

# Riječi koje izbacuju vijest (naslov, opis ili URL). Usklađeno s UPUTE.md.
IZBACI = re.compile(
    r"masterchef|master chef|horoskop|recept|black friday|black week|popust|sniženj|akcij[ia] u"
    r"|/sport|/lifestyle|/horoskop|/recepti|/zdravlje|/fit|/moda|/ljepota",
    re.I,
)


def get(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def cisto(t):
    t = re.sub(r"<[^>]+>", " ", t or "")
    return re.sub(r"\s+", " ", html.unescape(t)).strip()


def datum(s):
    s = (s or "").strip()
    if not s:
        return None
    try:
        d = parsedate_to_datetime(s)
    except (TypeError, ValueError):
        try:
            d = datetime.fromisoformat(s.replace("Z", "+00:00"))
        except ValueError:
            return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def izvor(naziv, url, od):
    root = ET.fromstring(get(url))
    items = root.findall(".//item") or root.findall(f".//{ATOM}entry")
    out = []
    for it in items:
        def f(tag):
            return it.findtext(tag) or it.findtext(ATOM + tag) or ""
        link = f("link")
        if not link:
            el = it.find(ATOM + "link")
            link = el.get("href", "") if el is not None else ""
        cats = " ".join(c.text or "" for c in it.findall("category"))
        d = datum(f("pubDate") or f("updated") or f("published"))
        if d and d < od:
            continue
        naslov = cisto(f("title"))
        opis = cisto(f("description") or f("summary"))[:350]
        if IZBACI.search(" ".join([naslov, opis, link, cats])):
            continue
        out.append((d, naslov, opis))
    return out


def vrijeme_zagreb():
    lat, lon = 45.815, 15.982
    url = (
        "https://api.open-meteo.com/v1/forecast?"
        f"latitude={lat}&longitude={lon}&timezone=Europe%2FZagreb&forecast_days=1"
        "&daily=temperature_2m_min,temperature_2m_max,precipitation_sum,"
        "precipitation_probability_max,wind_gusts_10m_max,weather_code"
        "&hourly=precipitation_probability"
    )
    data = json.loads(get(url))
    d = data["daily"]
    hourly = data["hourly"]["precipitation_probability"]
    kisni_sati = [i for i, p in enumerate(hourly) if p is not None and p >= 50]
    return (
        f"min {d['temperature_2m_min'][0]} °C, max {d['temperature_2m_max'][0]} °C, "
        f"oborina {d['precipitation_sum'][0]} mm (vjerojatnost do {d['precipitation_probability_max'][0]} %), "
        f"udari vjetra do {d['wind_gusts_10m_max'][0]} km/h, WMO kod {d['weather_code'][0]}, "
        f"sati s vjerojatnošću oborine ≥50 %: {kisni_sati or 'nema'}"
    )


def upozorenja():
    data = json.loads(get("https://feeds.meteoalarm.org/api/v1/warnings/feeds-croatia"))
    out = set()
    for w in data.get("warnings", []):
        for info in w.get("alert", {}).get("info", []):
            if not info.get("language", "").startswith("hr"):
                continue
            podrucja = " ".join(a.get("areaDesc", "") for a in info.get("area", []))
            istek = datum(info.get("expires", ""))
            if istek and istek < datetime.now(timezone.utc):
                continue
            if "zagreb" in podrucja.lower():
                out.add(f"{info.get('event', '')} – {info.get('headline', '')} "
                        f"({info.get('onset', '')[:16]} do {info.get('expires', '')[:16]})")
    return sorted(out)


def hacker_news(od, min_bodova=100, koliko=25):
    """Najpopularnije IT priče na Hacker Newsu u razdoblju (signal popularnosti, ne izvor činjenica)."""
    url = ("https://hn.algolia.com/api/v1/search?tags=story&hitsPerPage=100"
           f"&numericFilters=created_at_i>{int(od.timestamp())},points>{min_bodova}")
    hits = json.loads(get(url)).get("hits", [])
    hits.sort(key=lambda h: h.get("points") or 0, reverse=True)
    out = []
    for h in hits:
        naslov = cisto(h.get("title"))
        link = h.get("url") or f"https://news.ycombinator.com/item?id={h.get('objectID')}"
        if not naslov or IZBACI.search(naslov + " " + link):
            continue
        out.append((h.get("points") or 0, h.get("num_comments") or 0, naslov, link))
        if len(out) >= koliko:
            break
    return out


def main():
    od = datetime.now(timezone.utc) - timedelta(hours=SATI)
    print(f"# Vijesti od {od.isoformat(timespec='minutes')} (zadnjih {SATI} h)\n")

    print("## Vrijeme Zagreb (Open-Meteo, danas)")
    try:
        print(vrijeme_zagreb())
    except Exception as e:  # noqa: BLE001
        print(f"(nedostupno: {e})")
    try:
        upz = upozorenja()
        print("Upozorenja (Meteoalarm/DHMZ): " + ("; ".join(upz) if upz else "nema"))
    except Exception as e:  # noqa: BLE001
        print(f"Upozorenja: (nedostupno: {e})")
    print()

    ukupno = 0
    for naziv, url in CFG["izvori"].items():
        try:
            vijesti = izvor(naziv, url, od)
        except Exception as e:  # noqa: BLE001
            print(f"## {naziv}: GREŠKA ({e})\n")
            continue
        print(f"## {naziv} ({len(vijesti)})")
        for d, n, o in vijesti:
            t = d.astimezone().strftime("%d.%m. %H:%M") if d else "?"
            print(f"- [{t}] {n} :: {o}")
        print()
        ukupno += len(vijesti)
    print("## Hacker News – najpopularnije IT priče (bodovi, komentari)")
    try:
        for bod, kom, n, link in hacker_news(od):
            print(f"- [{bod} b, {kom} kom.] {n} :: {link}")
    except Exception as e:  # noqa: BLE001
        print(f"GREŠKA ({e})")
    print()
    print(f"# Ukupno {ukupno} vijesti")


if __name__ == "__main__":
    main()
