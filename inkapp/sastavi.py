#!/usr/bin/env python3
"""Sastavi novine/index.lua i novine/lockscreen.lua iz src/ (common.lua ide na početak obiju).

Upotreba:  python3 inkapp/sastavi.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
OUT = ROOT / "novine"


def bundle(main: str) -> str:
    common = (SRC / "common.lua").read_text(encoding="utf-8")
    body = (SRC / main).read_text(encoding="utf-8")
    return (
        f"-- SASTAVLJENO iz inkapp/src/common.lua i inkapp/src/{main} (sastavi.py) -- mijenjaj te datoteke.\n"
        "local N = (function()\n" + common + "end)()\n\n" + body
    )


def main():
    OUT.mkdir(exist_ok=True)
    (OUT / "index.lua").write_text(bundle("app.lua"), encoding="utf-8")
    (OUT / "lockscreen.lua").write_text(bundle("lock.lua"), encoding="utf-8")
    print("novine/index.lua, novine/lockscreen.lua")


if __name__ == "__main__":
    main()
