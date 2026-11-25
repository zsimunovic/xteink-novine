#!/usr/bin/env python3
"""Testovi za InkApp "Novine" na računalu (Lua 5.4 preko lupa), s lažnim ctx-om uređaja.

Upotreba:  pip install lupa && python3 inkapp/test_novine.py
Ne zamjenjuje probu na uređaju: fontovi su procjena (širina po znaku), a Lua na uređaju je 5.5.
"""
import re
import sys
from pathlib import Path

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parent
APP = ROOT / "novine"
IZDANJE = (ROOT.parent / "najnovije.txt").read_text(encoding="utf-8")
W, H = 480, 800
CHAR_W = {"small": 10, "medium": 12, "large": 15}
LINE_H = {"small": 20, "medium": 24, "large": 30}


class Font:
    def __init__(self, name):
        self.name = name
        self.line_height = LINE_H[name]

    def measure(self, s):
        return len(s) * CHAR_W[self.name]


class G:
    """Bilježi naredbe crtanja i provjerava da tekst stane na ekran."""

    def __init__(self):
        self.cmds, self.texts, self.errors = [], [], []

    def _c(self, *a):
        self.cmds.append(a)

    def clear(self, *a): self._c("clear")
    def line(self, *a): self._c("line", *a)
    def rect(self, x, y, w, h, *a): self._c("rect", x, y, w, h)
    def circle(self, *a): self._c("circle")
    def polyline(self, *a): self._c("polyline")

    def text(self, x, y, s, opts=None):
        self._c("text", x, y, s)
        f = opts["font"] if opts is not None and opts["font"] is not None else Font("medium")
        w = f.measure(s)
        self.texts.append(s)
        if x < 0 or x + w > W + 1 or y < 0 or y + f.line_height > H:
            self.errors.append(f"izvan ekrana: x={x} y={y} w={w} '{s[:40]}'")


def make_lua(today, files, net_ok=True, lock=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.FONTS = lua.table_from({n: Font(n) for n in CHAR_W})
    g.FILES = lua.table_from(files)
    g.REQS = lua.table()
    g.P = lua.table_from({"body": IZDANJE if net_ok else None, "today": today})
    lua.execute(r"""
      P.fonts, P.files, P.reqs = FONTS, FILES, REQS
      local y, m, d = P.today:match('(%d+)-(%d+)-(%d+)')
      ctx = {
        fonts = { small = P.fonts.small, medium = P.fonts.medium, large = P.fonts.large },
        storage = {
          read = function(self, n) local v = P.files[n]; if v == nil then return nil, 'not_found' end; return v end,
          write = function(self, n, s) P.files[n] = s; return true end,
        },
        clock = {
          now = function(self) return { year = tonumber(y), month = tonumber(m), day = tonumber(d),
                                        hour = 7, minute = 5, second = 0, epoch_sec = 1795000000, valid = true } end,
          millis = function(self) return 1000 end,
        },
        net = {
          keep_wifi = function(self, ms) end,
          request = function(self, req, fn)
            table.insert(P.reqs, req.url)
            if P.body then fn(ctx, { status = 200, body = P.body }) else fn(ctx, { ok = false, err = 'no_network' }) end
            return {}
          end,
        },
        lockscreen = {
          is_default = function(self) return P.files['_lock'] == '1' end,
          set_default = function(self) P.files['_lock'] = '1' end,
          clear_default = function(self) P.files['_lock'] = '0' end,
        },
        lock = { done = function(self) P.files['_done'] = '1' end, set_interval = function(self, s) end },
        invalidate = function(self) end,
      }
    """)
    src = (APP / ("lockscreen.lua" if lock else "index.lua")).read_text(encoding="utf-8")
    lua.execute(src)
    return lua, Live(lua)


class Live:
    """Pogled na Lua tablice REQS i FILES nakon poziva."""

    def __init__(self, lua):
        self.lua = lua

    @property
    def reqs(self):
        return list(self.lua.globals().REQS.values())

    @property
    def files(self):
        return dict(self.lua.globals().FILES.items())


def draw(lua):
    g = G()
    lua.globals().on_draw(lua.globals().ctx, g)
    return g


def tap(lua, x, y):
    ev = lua.table_from({"type": "pointer", "phase": "up", "gesture": "tap", "x": x, "y": y})
    lua.globals().on_input(lua.globals().ctx, ev)


def check(cond, msg):
    if not cond:
        print("NEUSPJEH:", msg)
        sys.exit(1)
    print("ok  ", msg)


def main():
    # 1. prvo pokretanje: nema spremljenog izdanja -> preuzme ga
    lua, live = make_lua("2026-11-25", {})
    lua.globals().on_load(lua.globals().ctx)
    reqs, files = live.reqs, live.files
    check(len(reqs) == 1 and reqs[0].startswith("https://zsimunovic.github.io/xteink-novine/najnovije.txt"), "preuzima najnovije.txt pri prvom otvaranju")
    check("izdanje.txt" in files, "sprema izdanje za čitanje bez Wi-Fija")
    g = draw(lua)
    check(not g.errors, "početni ekran stane na ekran " + "; ".join(g.errors[:3]))
    check(any("srijeda, 25. studenoga 2026." in t for t in g.texts), "početni ekran ima datum")
    for naziv in ["Ukratko", "Hrvatska", "Svijet", "Ekonomija i financije", "Tehnologija i AI", "Za kraj"]:
        check(naziv in g.texts, f"početni ekran ima rubriku '{naziv}'")
    check(not any("–" in t or "»" in t for t in g.texts), "nesigurni znakovi (–, ») zamijenjeni")

    # 2. čitanje: proći kroz sve stranice svih rubrika
    tap(lua, 200, 210 + 10)  # prvi redak = Ukratko
    seen, pages, max_cmds = set(), 0, 0
    for _ in range(200):
        g = draw(lua)
        check(not g.errors, f"stranica {pages + 1} stane na ekran") if g.errors else None
        max_cmds = max(max_cmds, len(g.cmds))
        seen.update(g.texts)
        pages += 1
        if "Osvježi" in g.texts:  # vratili smo se na početni ekran
            break
        tap(lua, 400, 400)       # desni dio ekrana = sljedeća stranica
    check(pages > 5, f"prolazak kroz cijelo izdanje ({pages} ekrana)")
    check(max_cmds < 300, f"najviše {max_cmds} naredbi crtanja po ekranu (granica ~1024)")
    body = " ".join(seen)
    for rijec in ["Zadravec", "Tidal", "Za kraj", "Zašto je važno:", "Izvor:"]:
        check(rijec in body, f"tekst sadrži '{rijec}'")

    # 3. idući dan, bez mreže: prikaže staro izdanje i upozori
    lua, live = make_lua("2026-11-26", files, net_ok=False)
    lua.globals().on_load(lua.globals().ctx)
    check(len(live.reqs) == 1, "staro izdanje -> pokuša preuzeti novo")
    g = draw(lua)
    check(any("Nema veze" in t for t in g.texts), "bez mreže javi poruku")
    check(any("izdanje od 25.11." in t for t in g.texts), "upozori da je izdanje staro")

    # 4. isti dan: ne preuzima ponovno
    lua, live = make_lua("2026-11-25", files)
    lua.globals().on_load(lua.globals().ctx)
    check(len(live.reqs) == 0, "današnje izdanje već spremljeno -> nema preuzimanja")

    # 5. gumb za zaključani ekran
    tap(lua, 360, 750)
    files = live.files
    check(files.get("_lock") == "1" and "lock=1" in files.get("postavke.txt", ""), "gumb uključi zaključani ekran")

    # 6. zaključani ekran
    lua, live = make_lua("2026-11-25", files, lock=True)
    lua.globals().on_load(lua.globals().ctx)
    g = draw(lua)
    check(not g.errors, "zaključani ekran stane na ekran " + "; ".join(g.errors[:3]))
    check("NOVINE" in g.texts and any("Zadravec" in t for t in g.texts), "zaključani ekran prikazuje Ukratko")
    check(live.files.get("_done") == "1", "zaključani ekran javlja ctx.lock:done()")
    check(len(live.reqs) == 0, "zaključani ekran ne preuzima kad je izdanje današnje")
    lua, live = make_lua("2026-11-26", files, lock=True)
    lua.globals().on_load(lua.globals().ctx)
    check(len(live.reqs) == 1, "zaključani ekran s mrežom preuzme novo izdanje idući dan")

    # 7. Lua 5.5: varijable for-petlje se ne smiju mijenjati unutar petlje
    for name in ["index.lua", "lockscreen.lua"]:
        lines = (APP / name).read_text(encoding="utf-8").split("\n")
        bad = []
        for i, ln in enumerate(lines):
            m = re.match(r"^(\s*).*\bfor\s+([\w, ]+?)\s+(?:=|in)\b.*\bdo\b", ln)
            if not m:
                continue
            ind, names = len(m.group(1)), [v.strip() for v in m.group(2).split(",") if v.strip() != "_"]
            body = []
            if not re.search(r"\bend\s*$", ln):
                for ln2 in lines[i + 1:]:
                    if re.match(r"^\s{%d}end\b" % ind, ln2):
                        break
                    body.append(ln2)
            else:
                body = [ln.split(" do ", 1)[-1]]
            for v in names:
                if any(re.search(rf"(^|[;\s]){v}\s*=[^=]", b) for b in body):
                    bad.append(f"{v} (redak {i + 1})")
        check(not bad, f"{name}: nema dodjele varijablama for-petlje ({', '.join(bad) or 'ništa'})")

    print("\nSve prošlo.")


if __name__ == "__main__":
    main()
