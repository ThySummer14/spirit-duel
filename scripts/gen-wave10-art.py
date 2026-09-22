#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for wave10 (炭治郎 / 祢豆子).

Re-runnable: writes assets/wave10/<id>.svg and <id>-awakened.svg.
viewBox 0 0 200 260. Unique gradient IDs prefixed by unit id. No NetEase art.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave10"

W, H = 200, 260


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def defs(p: str, bg1: str, bg2: str, bg3: str, halo: str, body1: str, body2: str,
         acc1: str, acc2: str) -> str:
    return f"""  <defs>
    <linearGradient id="{p}-bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{bg1}"/>
      <stop offset=".55" stop-color="{bg2}"/>
      <stop offset="1" stop-color="{bg3}"/>
    </linearGradient>
    <radialGradient id="{p}-halo" cx=".5" cy=".44" r=".6">
      <stop offset="0" stop-color="{halo}" stop-opacity=".45"/>
      <stop offset=".5" stop-color="{acc1}" stop-opacity=".18"/>
      <stop offset="1" stop-color="{acc1}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="{p}-body" x1=".2" y1="0" x2=".9" y2="1">
      <stop offset="0" stop-color="{body1}"/>
      <stop offset=".55" stop-color="{body2}"/>
      <stop offset="1" stop-color="{acc1}"/>
    </linearGradient>
    <linearGradient id="{p}-acc" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{acc1}"/>
      <stop offset="1" stop-color="{acc2}"/>
    </linearGradient>
    <linearGradient id="{p}-gold" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ffd98a"/>
      <stop offset="1" stop-color="#c9762c"/>
    </linearGradient>
  </defs>"""


def shell(uid: str, title: str, desc: str, body: str, pal: dict, awakened: bool) -> str:
    p = uid.replace("-", "")
    d = defs(p, pal["bg1"], pal["bg2"], pal["bg3"], pal["halo"],
             pal["body1"], pal["body2"], pal["acc1"], pal["acc2"])
    t = esc(title) + (" · 觉醒相" if awakened else "")
    dd = esc(desc)
    if awakened:
        dd += "。觉醒相：鎏金环阵与绯焰符印"
    frame = (
        f'  <rect width="{W}" height="{H}" fill="none" '
        f'stroke="{pal["frame"]}" stroke-opacity=".35" stroke-width="1.5" rx="10"/>\n'
    )
    awk = ""
    if awakened:
        awk = f"""  <g aria-hidden="true">
    <circle cx="100" cy="112" r="99" fill="{pal["awk_bloom"]}" opacity=".55"/>
    <g fill="none" stroke="url(#{p}-gold)">
      <circle cx="100" cy="112" r="90" stroke-width="1.6" stroke-dasharray="11 7" opacity=".78"/>
      <circle cx="100" cy="112" r="83.5" stroke-width=".8" opacity=".4"/>
    </g>
    <g>
      <circle cx="24.7" cy="68.5" r="6" fill="url(#{p}-gold)" stroke="#59371b" stroke-width="1"/>
      <circle cx="24.7" cy="68.5" r="1.8" fill="{pal["awk_core"]}"/>
      <circle cx="175.3" cy="68.5" r="6" fill="url(#{p}-gold)" stroke="#59371b" stroke-width="1"/>
      <circle cx="175.3" cy="68.5" r="1.8" fill="{pal["awk_core"]}"/>
      <circle cx="100" cy="199" r="6" fill="url(#{p}-gold)" stroke="#59371b" stroke-width="1"/>
      <circle cx="100" cy="199" r="1.8" fill="{pal["awk_core"]}"/>
    </g>
    <path d="M100 16c5 7 5.5 12 0 19-5.5-7-5-12 0-19z" fill="url(#{p}-gold)"/>
    <g stroke="url(#{p}-gold)" stroke-width="1" opacity=".7">
      <path d="M84 26h-7M123 26h7M88 14l-5-4M112 14l5-4M88 38l-5 4M112 38l5 4"/>
    </g>
    <g fill="#ffd98a" opacity=".8">
      <circle cx="38" cy="88" r="2.4"/><circle cx="162" cy="94" r="2"/>
      <circle cx="52" cy="170" r="1.8"/><circle cx="150" cy="176" r="2.2"/>
    </g>
    <g fill="#ffe6a8" opacity=".7">
      <circle cx="66" cy="48" r="1.2"/><circle cx="134" cy="48" r="1.2"/>
      <circle cx="100" cy="208" r="1.4"/>
    </g>
  </g>
"""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
        f'role="img" aria-labelledby="title desc">\n'
        f'  <title id="title">{t}</title>\n'
        f'  <desc id="desc">{dd}</desc>\n'
        f"{d}\n"
        f'  <rect width="{W}" height="{H}" fill="url(#{p}-bg)"/>\n'
        f'  <circle cx="100" cy="112" r="86" fill="url(#{p}-halo)"/>\n'
        f"{body}"
        f'  <ellipse cx="100" cy="222" rx="52" ry="9" fill="#000" opacity=".4"/>\n'
        f"{awk}"
        f"{frame}"
        f"</svg>\n"
    )


def dots(p: str, pts, fill: str | None = None) -> str:
    fill = fill or f"url(#{p}-acc)"
    parts = [f'<g fill="{fill}">']
    for x, y, r, o in pts:
        parts.append(f'    <circle cx="{x}" cy="{y}" r="{r}" opacity="{o}"/>')
    parts.append("  </g>")
    return "\n".join(parts) + "\n"


DEFAULT_DOTS = [(40, 80, 2, ".6"), (160, 86, 1.8, ".55"), (34, 150, 1.6, ".5"),
                (168, 154, 1.6, ".5"), (100, 40, 1.8, ".55"), (70, 200, 1.5, ".5"),
                (130, 200, 1.5, ".5")]


def m_tanjirou(p):
    # water-breath blade + flowing surface slash (炭治郎)
    return f"""  <g>
    <path d="M55 165c18-28 35-28 50 0 15-28 32-28 50 0" fill="none" stroke="url(#{p}-body)" stroke-width="3"/>
    <path d="M55 180c18-22 35-22 50 0 15-22 32-22 50 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2" opacity=".85"/>
    <path d="M62 55L145 155" stroke="url(#{p}-body)" stroke-width="4" stroke-linecap="round"/>
    <path d="M145 155l-8 14-12-6Z" fill="url(#{p}-gold)"/>
    <path d="M70 48h18l-9-14Z" fill="url(#{p}-gold)" opacity=".85"/>
    <path d="M88 95c8-18 16-28 24-34-2 16-2 30 2 44" fill="url(#{p}-acc)" opacity=".65"/>
    <path d="M100 70c10-8 22-10 34-6-12 6-22 12-30 22" fill="url(#{p}-body)" opacity=".5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_nezuko(p):
    # bamboo tube + blood blossom + sleep moon (祢豆子)
    return f"""  <g>
    <rect x="88" y="88" width="24" height="70" rx="8" fill="url(#{p}-body)" stroke="#3a2018" stroke-width="1.6"/>
    <path d="M88 110h24M88 135h24" stroke="#3a2018" stroke-width="1.2" opacity=".7"/>
    <path d="M100 55c-14 8-18 22-10 34 12-4 20-16 20-30Z" fill="url(#{p}-acc)" opacity=".85"/>
    <path d="M72 95c-8 10-8 24 2 32 8-6 12-18 8-30Z" fill="url(#{p}-acc)" opacity=".65"/>
    <path d="M128 95c8 10 8 24-2 32-8-6-12-18-8-30Z" fill="url(#{p}-acc)" opacity=".65"/>
    <path d="M78 48c8-10 22-12 32-4-10 2-18 8-22 16-4-4-8-8-10-12Z" fill="url(#{p}-gold)" opacity=".75"/>
    <circle cx="100" cy="175" r="6" fill="url(#{p}-gold)" opacity=".5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def pal(bg1, bg2, bg3, halo, body1, body2, acc1, acc2, frame,
        awk_bloom="rgba(255, 233, 178, 0.35)", awk_core="#ff8a3d"):
    return {
        "bg1": bg1, "bg2": bg2, "bg3": bg3, "halo": halo,
        "body1": body1, "body2": body2, "acc1": acc1, "acc2": acc2,
        "frame": frame, "awk_bloom": awk_bloom, "awk_core": awk_core,
    }


UNITS = [
    ("tanjirou", "炭治郎", "炭治郎：水之型刀光与水面斩，兄妹之绊",
     pal("#0a1820", "#123040", "#081018", "#2a6f8e", "#c0e8f0", "#5088a0", "#2a8ab0", "#103848", "#2a8ab0"),
     m_tanjirou),
    ("nezuko", "祢豆子", "祢豆子：竹筒与爆血花，妹妹守护睡眠",
     pal("#180c14", "#281420", "#100810", "#c45c78", "#f0c8d8", "#c07088", "#d04070", "#601838", "#d04070"),
     m_nezuko),
]


def build(uid, title, desc, palette, motif_fn, awakened: bool) -> str:
    p = uid.replace("-", "")
    body = motif_fn(p)
    return shell(uid, title, desc, body, palette, awakened)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for uid, title, desc, palette, motif_fn in UNITS:
        for awk in (False, True):
            name = f"{uid}-awakened.svg" if awk else f"{uid}.svg"
            svg = build(uid, title, desc, palette, motif_fn, awk)
            path = OUT / name
            path.write_text(svg, encoding="utf-8")
            written.append((path, len(svg.encode("utf-8"))))
    over = [p for p, n in written if n > 8192]
    print(f"wrote {len(written)} files to {OUT}")
    if over:
        print(f"WARNING: {len(over)} files over 8KB:")
        for p in over:
            print(f"  {p.name}")
    else:
        print("all files under 8KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
