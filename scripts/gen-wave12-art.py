#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original SVG portraits for wave12 origin2 (8 units)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave12"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 200, 260

# id, title, colors, motif path fragment
UNITS = [
    ("yueying", "月隐", "#1a2238", "#2a3558", "#8a9bc0", "#c8d4f0",
     '<ellipse cx="100" cy="120" rx="36" ry="48" fill="url(#p-body)"/><path d="M70 70 L100 40 L130 70 L120 90 L80 90 Z" fill="url(#p-accent)" opacity=".9"/><circle cx="100" cy="130" r="14" fill="#f0e8d0" opacity=".85"/>'),
    ("shizhu", "石主", "#2a281c", "#3d3828", "#a89870", "#d4c4a0",
     '<rect x="60" y="80" width="80" height="90" rx="12" fill="url(#p-body)"/><rect x="75" y="55" width="50" height="40" rx="8" fill="url(#p-accent)"/><circle cx="88" cy="100" r="6" fill="#f0e8d0"/><circle cx="112" cy="100" r="6" fill="#f0e8d0"/>'),
    ("yanling-huo", "焰铃", "#301818", "#4a2020", "#e07040", "#ffb060",
     '<circle cx="100" cy="115" r="40" fill="url(#p-body)"/><path d="M100 55 Q130 90 100 130 Q70 90 100 55" fill="url(#p-accent)"/><rect x="92" y="145" width="16" height="30" rx="4" fill="#c0a060"/>'),
    ("shuimo", "潮语", "#142828", "#1e3c3c", "#5a9aaa", "#a0d8e0",
     '<ellipse cx="100" cy="120" rx="45" ry="50" fill="url(#p-body)"/><path d="M55 140 Q100 100 145 140" stroke="url(#p-accent)" stroke-width="8" fill="none"/><circle cx="85" cy="110" r="8" fill="#e8f4f8"/><circle cx="115" cy="110" r="8" fill="#e8f4f8"/>'),
    ("leiyin", "雷音", "#241838", "#382850", "#c0a0e0", "#e8d0ff",
     '<polygon points="100,45 130,110 100,105 70,110" fill="url(#p-accent)"/><rect x="70" y="105" width="60" height="70" rx="10" fill="url(#p-body)"/><path d="M85 130 L115 130 M90 150 L110 150" stroke="#f0e8d0" stroke-width="3"/>'),
    ("xingchen", "尘轨", "#2c2818", "#443c20", "#d0c080", "#f0e8b0",
     '<circle cx="100" cy="115" r="38" fill="url(#p-body)"/><circle cx="100" cy="115" r="22" fill="none" stroke="url(#p-accent)" stroke-width="4"/><circle cx="130" cy="85" r="6" fill="#f8f0c0"/><circle cx="70" cy="145" r="4" fill="#f8f0c0"/>'),
    ("momo", "墨蚀", "#1c1828", "#2e2840", "#6a5a80", "#b0a0c8",
     '<ellipse cx="100" cy="125" rx="42" ry="45" fill="url(#p-body)"/><path d="M70 90 Q100 70 130 90" stroke="url(#p-accent)" stroke-width="10" fill="none"/><ellipse cx="88" cy="120" rx="6" ry="8" fill="#e8e0f0"/><ellipse cx="112" cy="120" rx="6" ry="8" fill="#e8e0f0"/>'),
    ("jinguang", "辉印", "#302818", "#4a3c20", "#e0c060", "#ffe890",
     '<circle cx="100" cy="110" r="36" fill="url(#p-body)"/><circle cx="100" cy="110" r="20" fill="none" stroke="url(#p-accent)" stroke-width="5"/><rect x="85" y="150" width="30" height="36" rx="6" fill="url(#p-accent)" opacity=".85"/>'),
]


def svg(uid: str, title: str, bg1: str, bg2: str, c1: str, c2: str, motif: str, awakened: bool) -> str:
    p = uid.replace("-", "_") + ("_a" if awakened else "")
    ring = f'<circle cx="100" cy="115" r="72" fill="none" stroke="#c9762c" stroke-width="3" opacity=".7"/>' if awakened else ""
    gold = ' filter="url(#p-glow)"' if awakened else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" role="img" aria-labelledby="{p}-t {p}-d">
  <title id="{p}-t">{"觉醒·" if awakened else ""}{title}</title>
  <desc id="{p}-d">灵枢原创式神立绘</desc>
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
  <rect width="{W}" height="{H}" fill="url(#{p}-bg)"/>
  <rect width="{W}" height="{H}" fill="url(#{p}-halo)"/>
  {ring}
  <g{gold}>{motif}</g>
  <text x="100" y="230" text-anchor="middle" font-family="sans-serif" font-size="16" fill="#f0e8d0">{title}</text>
</svg>
'''


def main() -> None:
    for uid, title, bg1, bg2, c1, c2, motif in UNITS:
        (OUT / f"{uid}.svg").write_text(svg(uid, title, bg1, bg2, c1, c2, motif, False), encoding="utf-8")
        (OUT / f"{uid}-awakened.svg").write_text(svg(uid, title, bg1, bg2, c1, c2, motif, True), encoding="utf-8")
    print(f"Wrote {len(UNITS)*2} SVGs to {OUT}")


if __name__ == "__main__":
    main()
