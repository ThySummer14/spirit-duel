#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate SVG portraits for wave13 destiny shikigami (6 units)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave13"
OUT.mkdir(parents=True, exist_ok=True)

UNITS = [
    ("shiyao-longyechaji", "时曜", "#1c2438", "#2c3858", "#7a8ab8", "#c0d0f0",
     '<polygon points="100,40 135,105 100,100 65,105" fill="url(#p-accent)"/><rect x="72" y="100" width="56" height="75" rx="10" fill="url(#p-body)"/><path d="M80 130 H120" stroke="#e8e0f0" stroke-width="3"/>'),
    ("baize-yuanqi", "缘起", "#1a2c24", "#284038", "#a0c8b0", "#d0f0d8",
     '<ellipse cx="100" cy="120" rx="40" ry="48" fill="url(#p-body)"/><circle cx="100" cy="95" r="16" fill="#f0e8d0"/><path d="M60 150 Q100 120 140 150" stroke="url(#p-accent)" stroke-width="6" fill="none"/>'),
    ("shenqi-huang", "神启", "#1c2038", "#2c3458", "#8898c8", "#c0d0ff",
     '<circle cx="100" cy="110" r="36" fill="url(#p-body)"/><circle cx="100" cy="110" r="18" fill="none" stroke="url(#p-accent)" stroke-width="4"/><circle cx="135" cy="75" r="5" fill="#f0f0ff"/><circle cx="65" cy="150" r="4" fill="#f0f0ff"/>'),
    ("xuan", "璇玑", "#2a2038", "#403058", "#c8b8d8", "#f0e0ff",
     '<circle cx="100" cy="115" r="38" fill="url(#p-body)"/><path d="M70 115 A30 30 0 0 1 130 115 A30 30 0 0 1 70 115" fill="none" stroke="url(#p-accent)" stroke-width="5"/><circle cx="85" cy="105" r="5" fill="#f8f0ff"/><circle cx="115" cy="125" r="5" fill="#2a2038"/>'),
    ("yuyuan-banruo", "御怨", "#301820", "#482838", "#c06070", "#f0a0b0",
     '<ellipse cx="100" cy="120" rx="38" ry="46" fill="url(#p-body)"/><path d="M75 95 Q100 80 125 95" stroke="url(#p-accent)" stroke-width="8" fill="none"/><path d="M80 145 Q100 160 120 145" stroke="#f0d0d8" stroke-width="3" fill="none"/>'),
    ("luohou", "蚀日", "#201420", "#342034", "#6a5060", "#a08090",
     '<circle cx="100" cy="115" r="42" fill="url(#p-body)"/><circle cx="100" cy="115" r="24" fill="#100810"/><circle cx="128" cy="90" r="8" fill="url(#p-accent)" opacity=".8"/>'),
]


def svg(uid, title, bg1, bg2, c1, c2, motif, awakened):
    p = uid.replace("-", "_") + ("_a" if awakened else "")
    ring = '<circle cx="100" cy="115" r="72" fill="none" stroke="#c9762c" stroke-width="3" opacity=".7"/>' if awakened else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 260" role="img">
  <title>{"觉醒·" if awakened else ""}{title}</title>
  <defs>
    <linearGradient id="{p}-bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{bg1}"/><stop offset="1" stop-color="{bg2}"/>
    </linearGradient>
    <radialGradient id="{p}-halo" cx=".5" cy=".42" r=".55">
      <stop offset="0" stop-color="{c2}" stop-opacity=".4"/><stop offset="1" stop-color="{c1}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="{p}-body" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{c2}"/><stop offset="1" stop-color="{c1}"/>
    </linearGradient>
    <linearGradient id="{p}-accent" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{c2}"/><stop offset="1" stop-color="#f0e0b0"/>
    </linearGradient>
  </defs>
  <rect width="200" height="260" fill="url(#{p}-bg)"/>
  <rect width="200" height="260" fill="url(#{p}-halo)"/>
  {ring}
  <g>{motif}</g>
  <text x="100" y="230" text-anchor="middle" font-family="sans-serif" font-size="15" fill="#f0e8d0">{title}</text>
</svg>
'''


def main():
    for uid, title, bg1, bg2, c1, c2, motif in UNITS:
        (OUT / f"{uid}.svg").write_text(svg(uid, title, bg1, bg2, c1, c2, motif, False), encoding="utf-8")
        (OUT / f"{uid}-awakened.svg").write_text(svg(uid, title, bg1, bg2, c1, c2, motif, True), encoding="utf-8")
    print(f"Wrote {len(UNITS)*2} SVGs to {OUT}")


if __name__ == "__main__":
    main()
