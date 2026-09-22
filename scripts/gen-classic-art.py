#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 29 classic-pack shikigami.

Re-runnable: writes assets/classic/<id>.svg and <id>-awakened.svg.
Style matches assets/ember.svg — ink-night Japanese aesthetic, viewBox 0 0 200 260.
No external resources, unique gradient IDs prefixed by unit id.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "classic"

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


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def star_pts(cx, cy, r_in, r_out, n, rot=0):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        x, y = polar(cx, cy, r, rot + i * 180.0 / n)
        pts.append(f"{x:.1f},{y:.1f}")
    return " ".join(pts)


def petal_path(cx, cy, ang, length, width):
    """Single petal as quadratic curves, tip at angle."""
    a = math.radians(ang)
    tx, ty = cx + length * math.cos(a), cy + length * math.sin(a)
    px, py = polar(cx, cy, width, ang + 90)
    qx, qy = polar(cx, cy, width, ang - 90)
    mx1, my1 = polar(cx, cy, length * 0.55, ang + 35)
    mx2, my2 = polar(cx, cy, length * 0.55, ang - 35)
    return (
        f"M{cx:.1f} {cy:.1f} Q{mx1:.1f} {my1:.1f} {tx:.1f} {ty:.1f} "
        f"Q{mx2:.1f} {my2:.1f} {cx:.1f} {cy:.1f}Z"
    )


# ---------- motif builders (each returns body SVG, uses #{p}-* gradients) ----------

def m_yaodaoji(p):
    # blade + red ribbon
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-linecap="round">
    <path d="M72 210 Q88 150 118 48" stroke-width="5" opacity=".9"/>
    <path d="M72 210 Q88 150 118 48" stroke="#fdf3e7" stroke-width="1.6" opacity=".7"/>
    <path d="M64 198h22l-4 18H68Z" fill="url(#{p}-body)" stroke="{p and '#5c2418'}" stroke-width="1.5"/>
  </g>
  <path d="M120 52c-2 20 6 38 18 54 8 10 22 18 34 14-10 16-32 14-46 2-12-10-18-30-14-48 2-8 6-16 8-22Z" fill="url(#{p}-acc)" opacity=".85"/>
  <path d="M78 88c18 6 34 4 48-6-8 18-28 28-48 22Z" fill="url(#{p}-body)" opacity=".9"/>
  <path d="M100 96c8 12 12 24 10 38-10-4-16-16-18-28Z" fill="url(#{p}-body)" opacity=".75"/>
  <path d="M86 70l8 12M104 64l6 14" stroke="url(#{p}-gold)" stroke-width="1.4" opacity=".7"/>
""" + dots(p, [(46, 72, 2, ".7"), (158, 90, 2.4, ".8"), (170, 140, 1.6, ".5"),
               (40, 150, 1.8, ".6"), (128, 188, 2, ".7"), (60, 200, 1.5, ".5"),
               (100, 30, 1.8, ".6"), (140, 44, 1.2, ".5")])


def m_jutun_tongzi(p):
    # oni horns + gourd / wine
    return f"""  <g>
    <path d="M70 78c-8-28-4-48 6-58 2 18 8 32 18 42" fill="url(#{p}-acc)" opacity=".9"/>
    <path d="M130 78c8-28 4-48-6-58-2 18-8 32-18 42" fill="url(#{p}-acc)" opacity=".9"/>
  </g>
  <ellipse cx="100" cy="118" rx="38" ry="44" fill="url(#{p}-body)" stroke="#3a1a10" stroke-width="2"/>
  <ellipse cx="84" cy="112" rx="8" ry="5" fill="#2a0c08" transform="rotate(-12 84 112)"/>
  <ellipse cx="116" cy="112" rx="8" ry="5" fill="#2a0c08" transform="rotate(12 116 112)"/>
  <ellipse cx="86" cy="111" rx="2.6" ry="3" fill="#ffb066"/>
  <ellipse cx="114" cy="111" rx="2.6" ry="3" fill="#ffb066"/>
  <path d="M88 132c6 8 18 8 24 0" stroke="#5c2418" stroke-width="2.2" fill="none" stroke-linecap="round"/>
  <path d="M148 150c8-6 18-4 22 6 4 10-2 20-12 24-8 2-14-2-16-8 8 2 16-2 18-10 2-8-4-12-12-12Z" fill="url(#{p}-acc)" opacity=".85"/>
  <path d="M150 148c4-8 2-16-4-22 10 2 16 12 14 24" fill="url(#{p}-body)" opacity=".8"/>
  <path d="M60 168h80l-8 28H68Z" fill="url(#{p}-body)" opacity=".55"/>
""" + dots(p, [(48, 88, 2.2, ".7"), (156, 100, 1.8, ".6"), (42, 160, 2, ".55"),
               (170, 180, 1.6, ".5"), (100, 36, 1.8, ".55"), (72, 200, 1.5, ".5"),
               (130, 190, 2, ".65")])


def m_bingyong(p):
    # armor plates + shield
    plates = []
    for i, (x, y, w, h) in enumerate([
        (62, 70, 36, 22), (102, 62, 36, 22), (54, 98, 40, 24),
        (106, 98, 40, 24), (62, 128, 36, 22), (102, 128, 36, 22),
        (72, 156, 56, 20),
    ]):
        plates.append(
            f'    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="3" '
            f'fill="url(#{p}-body)" stroke="#2a2a32" stroke-width="1.6"/>'
        )
        plates.append(
            f'    <rect x="{x+3}" y="{y+3}" width="{w-6}" height="{h-6}" rx="2" '
            f'fill="none" stroke="url(#{p}-gold)" stroke-width=".8" opacity=".55"/>'
        )
    body = "\n".join(plates)
    return f"""  <g>
{body}
  </g>
  <path d="M100 58c-22 4-34 18-34 34 0 28 16 48 34 58 18-10 34-30 34-58 0-16-12-30-34-34Z" fill="url(#{p}-acc)" opacity=".35" stroke="url(#{p}-gold)" stroke-width="1.5"/>
  <path d="M100 78v52M82 100h36" stroke="url(#{p}-gold)" stroke-width="2" stroke-linecap="round"/>
  <path d="M70 188h60l-6 18H76Z" fill="url(#{p}-body)" opacity=".5"/>
  <path d="M88 48h24l-4 14H92Z" fill="url(#{p}-acc)"/>
""" + dots(p, [(40, 80, 1.8, ".55"), (164, 90, 2, ".6"), (36, 150, 1.6, ".5"),
               (168, 160, 1.8, ".55"), (100, 28, 1.6, ".5"), (56, 200, 1.4, ".45"),
               (148, 200, 1.6, ".5")])


def m_datiangou(p):
    # wings + fan
    return f"""  <g>
    <path d="M78 100c-24-22-48-24-62-12 20 4 36 16 48 34-18-8-36-6-50 6 24 2 46 10 58 24Z" fill="url(#{p}-body)" opacity=".85"/>
    <path d="M122 100c24-22 48-24 62-12-20 4-36 16-48 34 18-8 36-6 50 6-24 2-46 10-58 24Z" fill="url(#{p}-body)" opacity=".85"/>
  </g>
  <ellipse cx="100" cy="108" rx="30" ry="34" fill="url(#{p}-acc)" opacity=".9" stroke="#2a1016" stroke-width="2"/>
  <path d="M78 78 72 48l22 16h12l22-16-6 30" fill="none" stroke="url(#{p}-gold)" stroke-width="2.5" stroke-linejoin="round"/>
  <ellipse cx="88" cy="104" rx="6" ry="4" fill="#1a0a08"/>
  <ellipse cx="112" cy="104" rx="6" ry="4" fill="#1a0a08"/>
  <circle cx="89" cy="103" r="1.8" fill="#ffd98a"/><circle cx="113" cy="103" r="1.8" fill="#ffd98a"/>
  <path d="M148 130l36 8-28 24Z" fill="url(#{p}-body)" stroke="url(#{p}-gold)" stroke-width="1.2"/>
  <path d="M152 138l22 5M150 148l16 2" stroke="#5c2418" stroke-width="1" opacity=".6"/>
  <path d="M90 132c6 6 14 6 20 0" stroke="#3a0f0a" stroke-width="1.8" fill="none" stroke-linecap="round"/>
""" + dots(p, [(40, 70, 2, ".65"), (160, 66, 1.8, ".6"), (34, 140, 2.2, ".7"),
               (168, 150, 1.6, ".5"), (100, 32, 1.8, ".55"), (70, 190, 1.5, ".5"),
               (134, 196, 1.8, ".6")])


def m_xuenv(p):
    # snowflake + ice veil
    flake = []
    for ang in range(0, 360, 60):
        x2, y2 = polar(100, 100, 42, ang)
        flake.append(f'<path d="M100 100L{x2:.0f} {y2:.0f}" />')
        bx, by = polar(100, 100, 24, ang)
        for da in (35, -35):
            ax, ay = polar(bx, by, 12, ang + da)
            flake.append(f'<path d="M{bx:.0f} {by:.0f}L{ax:.0f} {ay:.0f}" />')
    arms = "".join(flake)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.8" stroke-linecap="round" opacity=".85">
    {arms}
  </g>
  <circle cx="100" cy="100" r="5" fill="url(#{p}-acc)" opacity=".7"/>
  <ellipse cx="100" cy="120" rx="34" ry="40" fill="url(#{p}-body)" opacity=".55" stroke="#a8d0e0" stroke-width="1.5"/>
  <path d="M66 118c8 28 22 44 34 52 12-8 26-24 34-52" fill="url(#{p}-body)" opacity=".45"/>
  <path d="M78 96c6 4 14 4 20 0M102 96c6 4 14 4 20 0" stroke="#c8e8f4" stroke-width="1.4" fill="none"/>
  <ellipse cx="86" cy="112" rx="5" ry="3.5" fill="#1a3040"/><ellipse cx="114" cy="112" rx="5" ry="3.5" fill="#1a3040"/>
  <circle cx="87" cy="111" r="1.5" fill="#e8f8ff"/><circle cx="115" cy="111" r="1.5" fill="#e8f8ff"/>
  <path d="M100 150c-18 10-28 30-28 48h56c0-18-10-38-28-48Z" fill="url(#{p}-body)" opacity=".5"/>
""" + dots(p, [(44, 64, 2, ".75"), (158, 58, 1.8, ".7"), (36, 130, 2.4, ".8"),
               (166, 140, 1.6, ".55"), (100, 28, 1.8, ".6"), (62, 180, 1.6, ".55"),
               (142, 186, 2, ".65"), (80, 48, 1.2, ".5")], f"url(#{p}-body)")


def m_yingcao(p):
    # glowing grass / wisps
    blades = []
    for i, (x, tipx, tipy, bow) in enumerate([
        (70, 55, 55, 30), (85, 80, 40, 20), (100, 100, 32, 0),
        (115, 122, 38, -18), (130, 148, 52, -28),
    ]):
        blades.append(
            f'    <path d="M{x} 200 Q{x + bow} 120 {tipx} {tipy}" fill="none" '
            f'stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round" opacity=".85"/>'
        )
    body = "\n".join(blades)
    return f"""  <g>
{body}
    <path d="M78 200c-10-30-8-55 4-72 4 24 8 44 18 58" fill="none" stroke="url(#{p}-body)" stroke-width="1.8" opacity=".7"/>
    <path d="M122 200c10-28 10-52 0-70-2 22-6 42-14 56" fill="none" stroke="url(#{p}-body)" stroke-width="1.8" opacity=".7"/>
  </g>
  <circle cx="100" cy="92" r="22" fill="url(#{p}-halo)" opacity=".9"/>
  <circle cx="100" cy="92" r="8" fill="url(#{p}-acc)" opacity=".75"/>
  <circle cx="100" cy="92" r="3" fill="#e8ff9a"/>
  <path d="M88 120c8 10 16 10 24 0-2 16-8 26-12 32-4-6-10-16-12-32Z" fill="url(#{p}-body)" opacity=".7"/>
  <ellipse cx="68" cy="130" rx="7" ry="10" fill="url(#{p}-acc)" opacity=".55" transform="rotate(-20 68 130)"/>
  <ellipse cx="136" cy="140" rx="6" ry="9" fill="url(#{p}-acc)" opacity=".5" transform="rotate(25 136 140)"/>
  <ellipse cx="52" cy="160" rx="5" ry="8" fill="url(#{p}-acc)" opacity=".4" transform="rotate(-30 52 160)"/>
  <ellipse cx="150" cy="168" rx="5" ry="7" fill="url(#{p}-acc)" opacity=".4" transform="rotate(20 150 168)"/>
""" + dots(p, [(50, 70, 2.2, ".8"), (154, 78, 2, ".75"), (40, 110, 1.8, ".6"),
               (164, 120, 2.4, ".7"), (86, 50, 1.5, ".55"), (118, 48, 1.5, ".55"),
               (72, 180, 1.6, ".5"), (132, 188, 1.8, ".55")])


def m_taohuayao(p):
    # peach blossom
    petals = "".join(
        f'  <path d="{petal_path(100, 100, a, 48, 18)}" fill="url(#{p}-acc)" opacity="{0.55 + (i % 3) * 0.12}"/>'
        for i, a in enumerate(range(0, 360, 72))
    )
    return f"""  <g transform="rotate(18 100 100)">
{petals}
  </g>
  <circle cx="100" cy="100" r="14" fill="url(#{p}-body)" opacity=".85"/>
  <circle cx="100" cy="100" r="6" fill="#ffd98a" opacity=".9"/>
  <ellipse cx="100" cy="148" rx="28" ry="36" fill="url(#{p}-body)" opacity=".45" stroke="#e8a0b8" stroke-width="1.3"/>
  <path d="M82 130c8 8 28 8 36 0-4 20-12 34-18 42-6-8-14-22-18-42Z" fill="url(#{p}-body)" opacity=".55"/>
  <ellipse cx="88" cy="142" rx="5" ry="3.5" fill="#4a2030"/><ellipse cx="112" cy="142" rx="5" ry="3.5" fill="#4a2030"/>
  <path d="M94 158c4 5 8 5 12 0" stroke="#8a4060" stroke-width="1.5" fill="none" stroke-linecap="round"/>
  <path d="M100 184c-12 8-18 20-18 30h36c0-10-6-22-18-30Z" fill="url(#{p}-body)" opacity=".4"/>
  <path d="M48 70c10-4 16 2 14 10-8 0-12-4-14-10ZM152 88c10 2 14 10 10 16-8-2-12-8-10-16Z" fill="url(#{p}-acc)" opacity=".7"/>
""" + dots(p, [(44, 50, 2, ".65"), (160, 55, 1.8, ".6"), (36, 120, 2.2, ".7"),
               (168, 130, 1.6, ".5"), (100, 28, 1.8, ".55"), (60, 190, 1.5, ".5"),
               (144, 198, 1.8, ".6")])


def m_guniao(p):
    # bird wings + umbrella
    return f"""  <g>
    <path d="M82 108c-28-18-54-16-68-2 18 2 34 12 46 28-16-4-32 0-44 12 22 0 44 8 56 20Z" fill="url(#{p}-body)" opacity=".8"/>
    <path d="M118 108c28-18 54-16 68-2-18 2-34 12-46 28 16-4 32 0 44 12-22 0-44 8-56 20Z" fill="url(#{p}-body)" opacity=".8"/>
  </g>
  <ellipse cx="100" cy="100" rx="26" ry="30" fill="url(#{p}-acc)" opacity=".9" stroke="#2a1830" stroke-width="1.8"/>
  <path d="M88 78c-2-14 2-24 8-28 0 12 2 20 6 26" fill="url(#{p}-body)"/>
  <path d="M112 78c2-14-2-24-8-28 0 12-2 20-6 26" fill="url(#{p}-body)"/>
  <ellipse cx="90" cy="96" rx="5" ry="3.5" fill="#1a0a18"/><ellipse cx="110" cy="96" rx="5" ry="3.5" fill="#1a0a18"/>
  <path d="M96 108h8l-4 8Z" fill="#e8a050"/>
  <path d="M148 70c22 4 36 18 36 34h-72c0-16 14-30 36-34Z" fill="url(#{p}-body)" opacity=".85" stroke="url(#{p}-gold)" stroke-width="1.2"/>
  <path d="M148 70v70" stroke="url(#{p}-gold)" stroke-width="2" stroke-linecap="round"/>
  <path d="M148 140c0 6-4 8-8 8" stroke="url(#{p}-gold)" stroke-width="1.5" fill="none"/>
  <path d="M88 124c6 8 18 8 24 0" stroke="#3a1830" stroke-width="1.5" fill="none"/>
""" + dots(p, [(36, 80, 2, ".65"), (164, 50, 1.8, ".55"), (30, 140, 2.2, ".7"),
               (170, 150, 1.6, ".5"), (100, 30, 1.6, ".5"), (56, 190, 1.5, ".5"),
               (130, 198, 1.8, ".55")])


def m_bailang(p):
    # bow + wolf
    return f"""  <path d="M160 60c-28 20-28 80 0 120" fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
  <path d="M160 60c12 28 12 72 0 120" fill="none" stroke="#c8e0f0" stroke-width="1.2" opacity=".7"/>
  <path d="M160 60c18 32 18 68 0 120" fill="none" stroke="url(#{p}-gold)" stroke-width="1" opacity=".5"/>
  <g>
    <path d="M72 88 58 58l28 18h28l28-18-14 30c6 10 8 22 4 34-8 22-24 36-44 36s-36-14-44-36c-4-12-2-24 4-34Z" fill="url(#{p}-body)" opacity=".85" stroke="#2a3848" stroke-width="1.8"/>
    <path d="M72 88 58 58l28 18M128 88l14-30-28 18" fill="none" stroke="#2a3848" stroke-width="1.8"/>
    <ellipse cx="84" cy="108" rx="7" ry="4.5" fill="#0a1820" transform="rotate(-10 84 108)"/>
    <ellipse cx="116" cy="108" rx="7" ry="4.5" fill="#0a1820" transform="rotate(10 116 108)"/>
    <circle cx="86" cy="107" r="2" fill="#9ad0f0"/><circle cx="114" cy="107" r="2" fill="#9ad0f0"/>
    <path d="M100 118v10M94 128h12" stroke="#2a3848" stroke-width="1.4" stroke-linecap="round"/>
    <path d="M88 136c8 8 16 8 24 0" stroke="#2a3848" stroke-width="1.6" fill="none" stroke-linecap="round"/>
    <path d="M88 142l4 8 8-4 8 4 4-8" fill="none" stroke="url(#{p}-gold)" stroke-width="1.2"/>
  </g>
  <path d="M48 160c16-4 28 4 32 16-14 4-28-2-32-16Z" fill="url(#{p}-acc)" opacity=".6"/>
""" + dots(p, [(40, 70, 2, ".65"), (48, 130, 1.8, ".55"), (36, 180, 2, ".6"),
               (176, 100, 1.6, ".5"), (100, 32, 1.6, ".5"), (70, 196, 1.5, ".5"),
               (140, 190, 1.8, ".55")])


def m_caitongzi(p):
    # claw + oni
    return f"""  <path d="M70 80c-6-26-2-46 8-56 0 16 4 30 12 40M130 80c6-26 2-46-8-56 0 16-4 30-12 40" fill="url(#{p}-acc)" opacity=".9"/>
  <ellipse cx="100" cy="112" rx="36" ry="40" fill="url(#{p}-body)" stroke="#3a1828" stroke-width="2"/>
  <path d="M78 96c8-2 14 0 18 4M122 96c-8-2-14 0-18 4" stroke="#5c2040" stroke-width="2" fill="none" stroke-linecap="round"/>
  <ellipse cx="84" cy="108" rx="7" ry="5" fill="#2a0818"/><ellipse cx="116" cy="108" rx="7" ry="5" fill="#2a0818"/>
  <circle cx="86" cy="107" r="2.2" fill="#ff8a6a"/><circle cx="114" cy="107" r="2.2" fill="#ff8a6a"/>
  <path d="M88 130c8 10 16 10 24 0" stroke="#5c2040" stroke-width="2" fill="none" stroke-linecap="round"/>
  <path d="M148 130c8-16 20-28 34-32-4 12-6 22-2 32 8 2 14 10 14 20-12-2-22-8-28-16-4 10-12 16-22 18 4-8 6-14 4-22Z" fill="url(#{p}-acc)" opacity=".9"/>
  <path d="M52 150c-8-4-16-2-22 6 10 2 18 2 24-2" fill="url(#{p}-acc)" opacity=".6"/>
  <path d="M72 70c10 8 22 12 28 12s18-4 28-12" stroke="url(#{p}-gold)" stroke-width="1.3" fill="none" opacity=".7"/>
""" + dots(p, [(42, 72, 2, ".65"), (162, 70, 1.8, ".6"), (34, 140, 2.2, ".7"),
               (172, 160, 1.6, ".5"), (100, 34, 1.6, ".5"), (60, 192, 1.5, ".5"),
               (140, 198, 1.8, ".55")])


def m_xuetongzi(p):
    # child + snow
    return f"""  <g fill="none" stroke="url(#{p}-body)" stroke-width="1.5" stroke-linecap="round" opacity=".8">
    <path d="M40 70l10 0M45 65l0 10M160 80l8 0M164 76l0 8"/>
    <path d="M48 140l8 0M52 136l0 8M155 150l8 0M159 146l0 8"/>
  </g>
  <circle cx="100" cy="88" r="32" fill="url(#{p}-body)" opacity=".7" stroke="#c0d8e8" stroke-width="1.6"/>
  <path d="M78 72c6-14 14-22 22-22s16 8 22 22" fill="url(#{p}-acc)" opacity=".75"/>
  <ellipse cx="88" cy="88" rx="5" ry="4" fill="#1a3040"/><ellipse cx="112" cy="88" rx="5" ry="4" fill="#1a3040"/>
  <circle cx="89" cy="87" r="1.5" fill="#e8f8ff"/><circle cx="113" cy="87" r="1.5" fill="#e8f8ff"/>
  <path d="M94 102c4 4 8 4 12 0" stroke="#4a7088" stroke-width="1.5" fill="none" stroke-linecap="round"/>
  <path d="M82 118c-8 10-12 28-10 48h56c2-20-2-38-10-48-8 6-28 6-36 0Z" fill="url(#{p}-body)" opacity=".55"/>
  <path d="M70 150h60M75 165h50" stroke="#a0c8e0" stroke-width="1" opacity=".5"/>
  <circle cx="100" cy="48" r="10" fill="url(#{p}-acc)" opacity=".55"/>
  <circle cx="100" cy="48" r="4" fill="#e8f8ff" opacity=".7"/>
""" + dots(p, [(42, 60, 2, ".75"), (160, 55, 1.8, ".7"), (36, 120, 2.4, ".8"),
               (166, 125, 1.6, ".55"), (100, 28, 1.5, ".5"), (62, 188, 1.6, ".55"),
               (140, 192, 2, ".65"), (78, 42, 1.2, ".5")], f"url(#{p}-body)")


def m_shantong(p):
    # mountain + club
    return f"""  <path d="M40 160 70 90l30 40 24-50 36 80Z" fill="url(#{p}-body)" opacity=".75" stroke="#3a3028" stroke-width="1.5"/>
  <path d="M70 90 85 120M94 130l10-20M124 80l8 30" stroke="#5c4838" stroke-width="1.2" opacity=".5"/>
  <ellipse cx="100" cy="128" rx="30" ry="34" fill="url(#{p}-acc)" opacity=".85" stroke="#3a2818" stroke-width="1.8"/>
  <path d="M82 108c6-4 12-4 16 0M102 108c6-4 12-4 16 0" stroke="#5c3820" stroke-width="2" fill="none" stroke-linecap="round"/>
  <ellipse cx="88" cy="120" rx="5" ry="4" fill="#2a1808"/><ellipse cx="112" cy="120" rx="5" ry="4" fill="#2a1808"/>
  <path d="M90 140c6 6 14 6 20 0" stroke="#5c3820" stroke-width="1.8" fill="none" stroke-linecap="round"/>
  <path d="M150 80c8 4 12 14 10 24-10 30-8 60 4 80-14-4-24-18-28-36-4-18 2-48 14-68Z" fill="url(#{p}-body)" opacity=".8"/>
  <path d="M154 78c6-2 12 2 14 8-6 2-12 0-14-8Z" fill="url(#{p}-acc)" opacity=".7"/>
  <path d="M60 188h80l-6 16H66Z" fill="url(#{p}-body)" opacity=".45"/>
""" + dots(p, [(40, 70, 2, ".55"), (164, 60, 1.8, ".55"), (36, 140, 1.8, ".5"),
               (170, 150, 1.6, ".5"), (100, 32, 1.6, ".5"), (56, 196, 1.4, ".45"),
               (148, 196, 1.6, ".5")])


def m_tiaotiaodidi(p):
    # hops + toxic bubbles
    return f"""  <circle cx="56" cy="70" r="12" fill="url(#{p}-acc)" opacity=".35" stroke="url(#{p}-acc)" stroke-width="1.2"/>
  <circle cx="56" cy="70" r="4" fill="url(#{p}-acc)" opacity=".6"/>
  <circle cx="150" cy="55" r="16" fill="url(#{p}-acc)" opacity=".3" stroke="url(#{p}-acc)" stroke-width="1.2"/>
  <circle cx="150" cy="55" r="5" fill="url(#{p}-acc)" opacity=".55"/>
  <circle cx="168" cy="100" r="9" fill="url(#{p}-acc)" opacity=".35"/>
  <circle cx="38" cy="110" r="7" fill="url(#{p}-acc)" opacity=".3"/>
  <ellipse cx="100" cy="130" rx="32" ry="36" fill="url(#{p}-body)" opacity=".8" stroke="#2a3820" stroke-width="1.8"/>
  <path d="M84 78 78 58l18 12M116 78l6-20-18 12" fill="none" stroke="#2a3820" stroke-width="2.2" stroke-linecap="round"/>
  <ellipse cx="86" cy="124" rx="7" ry="8" fill="#1a2810"/><ellipse cx="114" cy="124" rx="7" ry="8" fill="#1a2810"/>
  <circle cx="88" cy="122" r="2.5" fill="#b0e040"/><circle cx="116" cy="122" r="2.5" fill="#b0e040"/>
  <path d="M90 148c6 8 14 8 20 0" stroke="#2a3820" stroke-width="2" fill="none" stroke-linecap="round"/>
  <path d="M88 158c4 4 20 4 24 0" stroke="#6a8830" stroke-width="1.2" fill="none" opacity=".6"/>
  <path d="M78 172c-6 10-8 22-6 32h56c2-10 0-22-6-32-8 6-36 6-44 0Z" fill="url(#{p}-body)" opacity=".55"/>
  <path d="M82 200c-4 6-4 12 0 16M118 200c4 6 4 12 0 16" stroke="#2a3820" stroke-width="2" fill="none" stroke-linecap="round"/>
""" + dots(p, [(70, 90, 2, ".5"), (134, 85, 1.8, ".5"), (160, 150, 2, ".6"),
               (44, 160, 1.6, ".5"), (100, 40, 1.5, ".45")])


def m_qingshe(p):
    # snake
    return f"""  <path d="M60 200c20-20 20-50 0-70 24-24 60-24 80 0 16 20 12 50-10 70" fill="none" stroke="url(#{p}-acc)" stroke-width="10" stroke-linecap="round" opacity=".85"/>
  <path d="M60 200c20-20 20-50 0-70 24-24 60-24 80 0 16 20 12 50-10 70" fill="none" stroke="#2a4838" stroke-width="2" stroke-dasharray="4 6" opacity=".5"/>
  <ellipse cx="100" cy="88" rx="28" ry="32" fill="url(#{p}-body)" opacity=".8" stroke="#1a3828" stroke-width="1.8"/>
  <path d="M82 72c8-6 14-6 20-2 6-4 12-4 20 2" stroke="#3a6850" stroke-width="1.5" fill="none"/>
  <ellipse cx="88" cy="88" rx="6" ry="4" fill="#0a2010" transform="rotate(-15 88 88)"/>
  <ellipse cx="112" cy="88" rx="6" ry="4" fill="#0a2010" transform="rotate(15 112 88)"/>
  <circle cx="89" cy="87" r="1.8" fill="#c0f060"/><circle cx="113" cy="87" r="1.8" fill="#c0f060"/>
  <path d="M100 100v8M96 112h8" stroke="#1a3828" stroke-width="1.5" stroke-linecap="round"/>
  <path d="M100 120c-4 8 4 12 0 20 6-2 10-10 8-18Z" fill="url(#{p}-acc)" opacity=".8"/>
  <path d="M72 55c12-8 24-8 28 0-8 4-18 4-28 0ZM100 55c4-8 16-8 28 0-10 4-20 4-28 0Z" fill="url(#{p}-acc)" opacity=".55"/>
""" + dots(p, [(40, 80, 2, ".55"), (164, 75, 1.8, ".55"), (34, 140, 2, ".6"),
               (170, 145, 1.6, ".5"), (100, 30, 1.5, ".45"), (56, 188, 1.5, ".5"),
               (148, 190, 1.8, ".55")])


def m_zhen(p):
    # toxic bird feathers
    return f"""  <g>
    <path d="M100 70c-8 20-8 50 0 80 8-30 8-60 0-80Z" fill="url(#{p}-acc)" opacity=".85"/>
    <path d="M72 90c-4 24 0 50 14 70 2-28-2-52-14-70Z" fill="url(#{p}-acc)" opacity=".7"/>
    <path d="M128 90c4 24 0 50-14 70-2-28 2-52 14-70Z" fill="url(#{p}-acc)" opacity=".7"/>
    <path d="M52 110c0 22 8 42 22 56-4-24-10-42-22-56Z" fill="url(#{p}-body)" opacity=".65"/>
    <path d="M148 110c0 22-8 42-22 56 4-24 10-42 22-56Z" fill="url(#{p}-body)" opacity=".65"/>
  </g>
  <ellipse cx="100" cy="78" rx="22" ry="26" fill="url(#{p}-body)" opacity=".85" stroke="#2a2038" stroke-width="1.6"/>
  <path d="M92 58c2-12 6-18 8-18s6 6 8 18" fill="url(#{p}-acc)"/>
  <ellipse cx="90" cy="76" rx="5" ry="3.5" fill="#1a0820"/><ellipse cx="110" cy="76" rx="5" ry="3.5" fill="#1a0820"/>
  <circle cx="91" cy="75" r="1.5" fill="#e080c0"/><circle cx="111" cy="75" r="1.5" fill="#e080c0"/>
  <path d="M96 88h8l-4 6Z" fill="#c06040"/>
  <path d="M88 170c8 8 16 8 24 0" stroke="url(#{p}-gold)" stroke-width="1.3" fill="none" opacity=".6"/>
  <path d="M100 160v28M90 172l10 8 10-8" stroke="url(#{p}-acc)" stroke-width="1.5" fill="none"/>
""" + dots(p, [(38, 70, 2.2, ".7"), (164, 65, 2, ".65"), (30, 130, 2.4, ".75"),
               (172, 135, 1.8, ".55"), (100, 32, 1.6, ".5"), (54, 186, 1.6, ".5"),
               (148, 190, 2, ".6"), (70, 50, 1.3, ".5")], f"url(#{p}-body)")


def m_haifangzhu(p):
    # waves + monk
    return f"""  <path d="M20 160c20-16 40-16 60 0s40 16 60 0 40-16 60 0v50H20Z" fill="url(#{p}-acc)" opacity=".55"/>
  <path d="M20 175c20-14 40-14 60 0s40 14 60 0 40-14 60 0v40H20Z" fill="url(#{p}-body)" opacity=".5"/>
  <path d="M20 190c18-10 36-10 54 0s36 10 54 0 36-10 54 0v25H20Z" fill="url(#{p}-acc)" opacity=".4"/>
  <ellipse cx="100" cy="100" rx="32" ry="36" fill="url(#{p}-body)" opacity=".75" stroke="#1a3848" stroke-width="1.8"/>
  <path d="M78 88c6-16 14-24 22-24s16 8 22 24" fill="none" stroke="#2a5868" stroke-width="2"/>
  <ellipse cx="88" cy="98" rx="5" ry="3.5" fill="#0a2030"/><ellipse cx="112" cy="98" rx="5" ry="3.5" fill="#0a2030"/>
  <path d="M92 116c5 5 11 5 16 0" stroke="#2a5868" stroke-width="1.5" fill="none" stroke-linecap="round"/>
  <path d="M100 70v-8M88 74l-4-8M112 74l4-8" stroke="url(#{p}-gold)" stroke-width="1.4" stroke-linecap="round"/>
  <circle cx="100" cy="140" r="4" fill="url(#{p}-gold)" opacity=".7"/>
  <g fill="none" stroke="url(#{p}-gold)" stroke-width="1.4">
    <circle cx="82" cy="148" r="3"/><circle cx="92" cy="154" r="3"/>
    <circle cx="108" cy="154" r="3"/><circle cx="118" cy="148" r="3"/>
    <circle cx="100" cy="146" r="3"/>
  </g>
""" + dots(p, [(36, 80, 2, ".55"), (168, 75, 1.8, ".55"), (30, 130, 2, ".6"),
               (174, 140, 1.6, ".5"), (100, 30, 1.5, ".45"), (50, 200, 1.5, ".5"),
               (154, 205, 1.6, ".5")])


def m_yimulian(p):
    # wind + one eye / shrine
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.6" stroke-linecap="round" opacity=".7">
    <path d="M30 70c30-16 60-16 80 0 20 14 40 14 60 0"/>
    <path d="M24 95c34-12 70-12 96 4 20 12 40 12 56-2"/>
    <path d="M32 125c28-8 56-6 78 6 24 14 48 12 62-4"/>
  </g>
  <path d="M70 50h60l8 20H62Z" fill="url(#{p}-body)" opacity=".7" stroke="#3a4838" stroke-width="1.3"/>
  <path d="M75 50V36M125 50V36M70 36h60" stroke="url(#{p}-gold)" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M78 70v90h44V70" fill="none" stroke="url(#{p}-body)" stroke-width="2.5" opacity=".7"/>
  <ellipse cx="100" cy="110" rx="36" ry="22" fill="url(#{p}-acc)" opacity=".55" stroke="url(#{p}-gold)" stroke-width="1.5"/>
  <ellipse cx="100" cy="110" rx="14" ry="16" fill="url(#{p}-body)" stroke="#2a3828" stroke-width="1.5"/>
  <circle cx="100" cy="110" r="6" fill="#1a2818"/>
  <circle cx="101" cy="108" r="2" fill="#c0e870"/>
  <path d="M86 110h-20M114 110h20" stroke="url(#{p}-gold)" stroke-width="1.2" opacity=".6"/>
  <path d="M100 160v30M88 175h24" stroke="url(#{p}-body)" stroke-width="2" stroke-linecap="round" opacity=".6"/>
""" + dots(p, [(36, 60, 2, ".55"), (166, 55, 1.8, ".5"), (28, 120, 2, ".6"),
               (174, 130, 1.6, ".5"), (100, 28, 1.5, ".45"), (56, 196, 1.5, ".5"),
               (148, 198, 1.6, ".5")])


def m_shuweng(p):
    # books + brush
    return f"""  <g>
    <rect x="55" y="130" width="90" height="18" rx="2" fill="url(#{p}-body)" opacity=".8" stroke="#2a3040" stroke-width="1.2"/>
    <rect x="60" y="148" width="80" height="16" rx="2" fill="url(#{p}-body)" opacity=".65" stroke="#2a3040" stroke-width="1.2"/>
    <rect x="65" y="164" width="70" height="14" rx="2" fill="url(#{p}-body)" opacity=".5" stroke="#2a3040" stroke-width="1.2"/>
  </g>
  <ellipse cx="100" cy="95" rx="30" ry="34" fill="url(#{p}-body)" opacity=".8" stroke="#2a3040" stroke-width="1.8"/>
  <path d="M80 82c6-4 12-4 16 0M104 82c6-4 12-4 16 0" stroke="#4a5870" stroke-width="1.5" fill="none"/>
  <ellipse cx="88" cy="95" rx="4.5" ry="3.5" fill="#1a2030"/><ellipse cx="112" cy="95" rx="4.5" ry="3.5" fill="#1a2030"/>
  <path d="M92 112c5 4 11 4 16 0" stroke="#4a5870" stroke-width="1.4" fill="none" stroke-linecap="round"/>
  <path d="M100 62c-8-4-8-14 0-18 8 4 8 14 0 18Z" fill="url(#{p}-acc)" opacity=".8"/>
  <path d="M148 60 168 48l4 6-18 14Z" fill="url(#{p}-acc)" opacity=".85"/>
  <path d="M168 48l8-6" stroke="url(#{p}-gold)" stroke-width="2" stroke-linecap="round"/>
  <path d="M148 60l-2 10 8-2Z" fill="#c9762c"/>
  <path d="M40 100h28v40H40Z" fill="none" stroke="url(#{p}-acc)" stroke-width="1.5" opacity=".5"/>
  <path d="M48 112h12M48 122h12" stroke="url(#{p}-acc)" stroke-width="1" opacity=".4"/>
""" + dots(p, [(36, 70, 1.8, ".5"), (164, 100, 1.6, ".5"), (32, 150, 1.8, ".55"),
               (170, 160, 1.5, ".45"), (100, 32, 1.4, ".45"), (50, 196, 1.4, ".45"),
               (150, 198, 1.5, ".5")])


def m_jue(p):
    # third eye / mind
    return f"""  <ellipse cx="100" cy="108" rx="38" ry="44" fill="url(#{p}-body)" opacity=".7" stroke="#3a2848" stroke-width="1.8"/>
  <path d="M72 90c10-8 18-8 28-2 10-6 18-6 28 2" stroke="#5a3870" stroke-width="1.6" fill="none"/>
  <ellipse cx="84" cy="108" rx="7" ry="5" fill="#1a0828" transform="rotate(-12 84 108)"/>
  <ellipse cx="116" cy="108" rx="7" ry="5" fill="#1a0828" transform="rotate(12 116 108)"/>
  <circle cx="86" cy="107" r="2" fill="#c090f0"/><circle cx="114" cy="107" r="2" fill="#c090f0"/>
  <ellipse cx="100" cy="78" rx="10" ry="7" fill="url(#{p}-acc)" stroke="url(#{p}-gold)" stroke-width="1.2"/>
  <circle cx="100" cy="78" r="3" fill="#1a0828"/>
  <circle cx="101" cy="77" r="1.2" fill="#e8c0ff"/>
  <path d="M92 128c5 5 11 5 16 0" stroke="#5a3870" stroke-width="1.5" fill="none" stroke-linecap="round"/>
  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.2" opacity=".55">
    <path d="M55 70c-10 8-14 20-12 32"/>
    <path d="M145 70c10 8 14 20 12 32"/>
    <path d="M50 130c-4 12 0 24 10 32"/>
    <path d="M150 130c4 12 0 24-10 32"/>
  </g>
  <g fill="none" stroke="url(#{p}-gold)" stroke-width="1" opacity=".5">
    <circle cx="100" cy="108" r="55" stroke-dasharray="3 7"/>
  </g>
""" + dots(p, [(40, 80, 2, ".55"), (164, 75, 1.8, ".55"), (34, 145, 2, ".6"),
               (170, 150, 1.6, ".5"), (100, 36, 1.5, ".5"), (58, 188, 1.5, ".5"),
               (144, 192, 1.8, ".55")])


def m_quanshen(p):
    # dog + sword
    return f"""  <path d="M72 78 55 48l32 20M128 78l17-30-32 20" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="1.5"/>
  <ellipse cx="100" cy="112" rx="34" ry="38" fill="url(#{p}-body)" opacity=".85" stroke="#3a2818" stroke-width="1.8"/>
  <ellipse cx="84" cy="108" rx="7" ry="5" fill="#2a1808" transform="rotate(-10 84 108)"/>
  <ellipse cx="116" cy="108" rx="7" ry="5" fill="#2a1808" transform="rotate(10 116 108)"/>
  <circle cx="86" cy="107" r="2.2" fill="#e8b060"/><circle cx="114" cy="107" r="2.2" fill="#e8b060"/>
  <path d="M100 118v8M94 128c4 4 8 4 12 0" stroke="#3a2818" stroke-width="1.5" fill="none" stroke-linecap="round"/>
  <path d="M88 138c8 8 16 8 24 0" stroke="#3a2818" stroke-width="1.8" fill="none" stroke-linecap="round"/>
  <path d="M148 55 162 48l-2 80-10 4Z" fill="url(#{p}-acc)" stroke="#3a2818" stroke-width="1.2"/>
  <path d="M152 55v72" stroke="url(#{p}-gold)" stroke-width="1" opacity=".6"/>
  <path d="M144 132h22l-2 10h-18Z" fill="url(#{p}-gold)" stroke="#3a2818" stroke-width="1"/>
  <path d="M152 142v22" stroke="#5c3820" stroke-width="3" stroke-linecap="round"/>
  <path d="M70 160c-8 8-12 20-10 32h80c2-12-2-24-10-32-8 8-52 8-60 0Z" fill="url(#{p}-body)" opacity=".5"/>
""" + dots(p, [(40, 72, 2, ".55"), (168, 90, 1.8, ".5"), (34, 140, 1.8, ".55"),
               (172, 160, 1.6, ".5"), (100, 32, 1.5, ".45"), (56, 192, 1.5, ".5"),
               (140, 196, 1.6, ".5")])


def m_panguan(p):
    # brush + ledger / death
    return f"""  <rect x="48" y="120" width="70" height="54" rx="3" fill="url(#{p}-body)" opacity=".75" stroke="#2a2030" stroke-width="1.5"/>
  <path d="M58 134h50M58 146h42M58 158h36" stroke="#5a4858" stroke-width="1.2" opacity=".7"/>
  <path d="M140 40 155 35l6 8-12 8Z" fill="url(#{p}-acc)" opacity=".9"/>
  <path d="M148 48 120 120" stroke="url(#{p}-body)" stroke-width="3" stroke-linecap="round"/>
  <path d="M120 120c-4 8-4 14 2 18 4-6 6-12 4-18Z" fill="url(#{p}-acc)"/>
  <path d="M122 138c2 4 2 8 0 12" stroke="#c04040" stroke-width="1.5" opacity=".7"/>
  <ellipse cx="100" cy="88" rx="30" ry="34" fill="url(#{p}-body)" opacity=".7" stroke="#2a2030" stroke-width="1.8"/>
  <path d="M78 78 72 55h56l-6 23" fill="#1a1020" stroke="#2a2030" stroke-width="1.5"/>
  <path d="M72 55h56" stroke="url(#{p}-gold)" stroke-width="1.5"/>
  <ellipse cx="88" cy="90" rx="6" ry="4" fill="#0a0810"/><ellipse cx="112" cy="90" rx="6" ry="4" fill="#0a0810"/>
  <circle cx="89" cy="89" r="1.8" fill="#c0c0d0"/><circle cx="113" cy="89" r="1.8" fill="#c0c0d0"/>
  <path d="M92 108c5 3 11 3 16 0" stroke="#5a4858" stroke-width="1.4" fill="none"/>
  <path d="M100 122v20" stroke="#2a2030" stroke-width="1.5" opacity=".5"/>
""" + dots(p, [(36, 70, 1.8, ".5"), (168, 80, 1.6, ".5"), (30, 150, 1.8, ".55"),
               (172, 155, 1.5, ".45"), (100, 30, 1.4, ".45"), (50, 196, 1.4, ".45"),
               (148, 198, 1.5, ".5")])


def m_yijin_zhentian(p):
    # golden feathers
    return f"""  <g>
    <path d="M100 55c-6 25-6 55 0 85 6-30 6-60 0-85Z" fill="url(#{p}-acc)" opacity=".9"/>
    <path d="M72 75c-2 25 4 50 16 70 0-28-6-52-16-70Z" fill="url(#{p}-acc)" opacity=".75"/>
    <path d="M128 75c2 25-4 50-16 70 0-28 6-52 16-70Z" fill="url(#{p}-acc)" opacity=".75"/>
    <path d="M52 95c2 22 10 42 24 56-6-24-14-42-24-56Z" fill="url(#{p}-body)" opacity=".7"/>
    <path d="M148 95c-2 22-10 42-24 56 6-24 14-42 24-56Z" fill="url(#{p}-body)" opacity=".7"/>
    <path d="M86 50c4 18 4 40 0 58M114 50c-4 18-4 40 0 58" fill="none" stroke="#8a6020" stroke-width="1" opacity=".5"/>
  </g>
  <ellipse cx="100" cy="72" rx="20" ry="24" fill="url(#{p}-body)" opacity=".85" stroke="#4a3010" stroke-width="1.5"/>
  <path d="M92 54c2-10 5-15 8-15s6 5 8 15" fill="url(#{p}-acc)"/>
  <ellipse cx="92" cy="72" rx="4.5" ry="3.5" fill="#2a1808"/><ellipse cx="108" cy="72" rx="4.5" ry="3.5" fill="#2a1808"/>
  <circle cx="93" cy="71" r="1.4" fill="#ffe080"/><circle cx="109" cy="71" r="1.4" fill="#ffe080"/>
  <path d="M96 84h8l-4 5Z" fill="#c07020"/>
  <path d="M80 175c12-8 28-8 40 0-6 14-14 22-20 26-6-4-14-12-20-26Z" fill="url(#{p}-acc)" opacity=".55"/>
""" + dots(p, [(36, 70, 2.2, ".75"), (164, 65, 2, ".7"), (28, 130, 2.4, ".8"),
               (172, 135, 1.8, ".55"), (100, 30, 1.6, ".5"), (54, 188, 1.6, ".5"),
               (148, 192, 2, ".65"), (68, 48, 1.3, ".5")], f"url(#{p}-acc)")


def m_fenghuanghuo(p):
    # phoenix flame
    return f"""  <path d="M100 30c18 14 26 32 20 50 10-8 12-22 8-36 14 14 18 34 8 52 10-2 18-12 18-24 8 20 2 44-14 58-8 8-18 12-28 12h-24c-10 0-20-4-28-12-16-14-22-38-14-58 0 12 8 22 18 24-10-18-6-38 8-52-4 14-2 28 8 36-6-18 2-36 20-50Z" fill="url(#{p}-acc)" opacity=".9"/>
  <path d="M100 72c10 16 16 32 14 50-8-6-14-18-14-32-2 14-8 26-14 32-2-18 4-34 14-50Z" fill="url(#{p}-body)" opacity=".85"/>
  <ellipse cx="100" cy="130" rx="22" ry="26" fill="url(#{p}-body)" opacity=".8" stroke="#5c2010" stroke-width="1.5"/>
  <ellipse cx="92" cy="126" rx="5" ry="3.5" fill="#2a0808"/><ellipse cx="108" cy="126" rx="5" ry="3.5" fill="#2a0808"/>
  <circle cx="93" cy="125" r="1.5" fill="#ffcc80"/><circle cx="109" cy="125" r="1.5" fill="#ffcc80"/>
  <path d="M96 142c3 3 5 3 8 0" stroke="#5c2010" stroke-width="1.4" fill="none"/>
  <path d="M100 55c-4 12 0 20 4 28 4-10 4-20-4-28Z" fill="#ffe6a8" opacity=".8"/>
  <g fill="none" stroke="url(#{p}-gold)" stroke-width="1.2" opacity=".6">
    <path d="M70 160c-8 12-10 28-6 42"/>
    <path d="M130 160c8 12 10 28 6 42"/>
    <path d="M100 160v40"/>
  </g>
""" + dots(p, [(44, 60, 2.4, ".8"), (158, 55, 2, ".7"), (32, 120, 2.4, ".75"),
               (170, 125, 1.8, ".55"), (100, 24, 1.8, ".55"), (56, 180, 1.8, ".55"),
               (146, 186, 2, ".65"), (72, 40, 1.3, ".5")])


def m_qingfangzhu(p):
    # monk beads + green light
    beads = []
    for i in range(8):
        a = -120 + i * 22
        x, y = polar(100, 145, 38, a)
        beads.append(f'    <circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="url(#{p}-acc)" stroke="#1a3828" stroke-width="1"/>')
    bead_body = "\n".join(beads)
    return f"""  <circle cx="100" cy="100" r="48" fill="url(#{p}-halo)" opacity=".8"/>
  <ellipse cx="100" cy="92" rx="30" ry="34" fill="url(#{p}-body)" opacity=".75" stroke="#1a3828" stroke-width="1.8"/>
  <path d="M82 78c6-12 12-18 18-18s12 6 18 18" fill="none" stroke="#2a5840" stroke-width="1.5"/>
  <ellipse cx="88" cy="92" rx="5" ry="3.5" fill="#0a2018"/><ellipse cx="112" cy="92" rx="5" ry="3.5" fill="#0a2018"/>
  <path d="M92 108c5 4 11 4 16 0" stroke="#2a5840" stroke-width="1.4" fill="none" stroke-linecap="round"/>
  <path d="M85 78h30" stroke="url(#{p}-gold)" stroke-width="1.2" opacity=".6"/>
  <g>
{bead_body}
    <path d="M100 120v10" stroke="url(#{p}-gold)" stroke-width="1.5"/>
  </g>
  <path d="M78 168c8 20 14 34 22 42 8-8 14-22 22-42" fill="url(#{p}-body)" opacity=".5"/>
""" + dots(p, [(38, 68, 2.2, ".7"), (164, 62, 2, ".65"), (30, 125, 2.2, ".7"),
               (172, 130, 1.8, ".55"), (100, 28, 1.5, ".5"), (56, 185, 1.6, ".5"),
               (148, 190, 1.8, ".6")])


def m_qingwa_ciqi(p):
    # frog + dice / mahjong
    return f"""  <path d="M78 70c-8-18-4-32 4-38 0 14 4 24 10 32M122 70c8-18 4-32-4-38 0 14-4 24-10 32" fill="url(#{p}-acc)" opacity=".85"/>
  <circle cx="82" cy="62" r="10" fill="url(#{p}-body)" stroke="#2a3818" stroke-width="1.5"/>
  <circle cx="118" cy="62" r="10" fill="url(#{p}-body)" stroke="#2a3818" stroke-width="1.5"/>
  <circle cx="82" cy="62" r="4" fill="#1a2808"/><circle cx="118" cy="62" r="4" fill="#1a2808"/>
  <circle cx="83" cy="61" r="1.4" fill="#c0e040"/><circle cx="119" cy="61" r="1.4" fill="#c0e040"/>
  <ellipse cx="100" cy="120" rx="40" ry="36" fill="url(#{p}-body)" opacity=".85" stroke="#2a3818" stroke-width="1.8"/>
  <path d="M78 118c10 10 34 10 44 0" stroke="#2a3818" stroke-width="2" fill="none" stroke-linecap="round"/>
  <path d="M85 112c5 3 10 3 14 0M105 112c5 3 10 3 14 0" stroke="#4a6828" stroke-width="1.2" fill="none"/>
  <rect x="55" y="155" width="28" height="28" rx="4" fill="#e8e0d0" stroke="#5a5040" stroke-width="1.3"/>
  <circle cx="63" cy="163" r="2.5" fill="#2a2820"/><circle cx="75" cy="175" r="2.5" fill="#2a2820"/>
  <rect x="118" y="150" width="28" height="28" rx="4" fill="#d8e8d0" stroke="#3a5840" stroke-width="1.3"/>
  <text x="132" y="169" text-anchor="middle" font-size="14" fill="#2a4830" font-family="serif">發</text>
  <rect x="88" y="170" width="26" height="26" rx="3" fill="#c8d8e8" stroke="#3a4858" stroke-width="1.2"/>
  <circle cx="95" cy="177" r="2" fill="#2a3040"/><circle cx="101" cy="183" r="2" fill="#2a3040"/><circle cx="107" cy="177" r="2" fill="#2a3040"/>
""" + dots(p, [(36, 90, 2, ".55"), (166, 85, 1.8, ".55"), (30, 130, 1.8, ".5"),
               (172, 140, 1.6, ".5"), (100, 28, 1.5, ".45")])


def m_shantu(p):
    # rabbit + dice
    return f"""  <path d="M78 78c-10-30-6-52 2-60 2 20 6 36 14 48M122 78c10-30 6-52-2-60-2 20-6 36-14 48" fill="url(#{p}-body)" stroke="#4a3830" stroke-width="1.3"/>
  <path d="M82 60c-4-16-2-30 1-36 2 14 4 24 8 32" fill="url(#{p}-acc)" opacity=".5"/>
  <path d="M118 60c4-16 2-30-1-36-2 14-4 24-8 32" fill="url(#{p}-acc)" opacity=".5"/>
  <ellipse cx="100" cy="115" rx="34" ry="36" fill="url(#{p}-body)" opacity=".85" stroke="#4a3830" stroke-width="1.8"/>
  <ellipse cx="86" cy="112" rx="6" ry="5" fill="#2a2020"/><ellipse cx="114" cy="112" rx="6" ry="5" fill="#2a2020"/>
  <circle cx="87" cy="111" r="2" fill="#f0c0c0"/><circle cx="115" cy="111" r="2" fill="#f0c0c0"/>
  <ellipse cx="100" cy="124" rx="4" ry="3" fill="#c08080"/>
  <path d="M94 132c3 3 5 3 8 0M102 132c3 3 5 3 8 0" stroke="#4a3830" stroke-width="1.2" fill="none"/>
  <path d="M100 138v6M88 140h-10M112 140h10" stroke="#4a3830" stroke-width="1" opacity=".6"/>
  <g transform="rotate(-12 55 175)">
    <rect x="40" y="160" width="30" height="30" rx="4" fill="#e8d8c8" stroke="#5a4838" stroke-width="1.3"/>
    <circle cx="48" cy="168" r="2.2" fill="#3a2820"/><circle cx="62" cy="182" r="2.2" fill="#3a2820"/>
  </g>
  <g transform="rotate(14 150 170)">
    <rect x="135" y="155" width="30" height="30" rx="4" fill="#e8d8c8" stroke="#5a4838" stroke-width="1.3"/>
    <circle cx="143" cy="163" r="2.2" fill="#3a2820"/><circle cx="150" cy="170" r="2.2" fill="#3a2820"/>
    <circle cx="157" cy="177" r="2.2" fill="#3a2820"/>
  </g>
""" + dots(p, [(36, 80, 2, ".55"), (166, 75, 1.8, ".55"), (30, 130, 1.8, ".5"),
               (172, 125, 1.6, ".5"), (100, 28, 1.5, ".45"), (70, 196, 1.5, ".5"),
               (134, 198, 1.6, ".5")])


def m_yaoginshi(p):
    # koto / strings
    return f"""  <g fill="none" stroke="url(#{p}-body)" stroke-width="1.4" stroke-linecap="round" opacity=".75">
    <path d="M40 150 155 95"/>
    <path d="M42 158 157 103"/>
    <path d="M44 166 159 111"/>
    <path d="M46 174 161 119"/>
  </g>
  <path d="M35 145c30-8 60-8 85 5 20 10 35 8 50-2l6 12c-18 12-38 14-58 4-22-12-52-12-82-2Z" fill="url(#{p}-body)" opacity=".8" stroke="#2a2038" stroke-width="1.5"/>
  <path d="M50 155c20-4 40-2 55 6" stroke="url(#{p}-gold)" stroke-width="1" opacity=".5"/>
  <ellipse cx="100" cy="85" rx="28" ry="32" fill="url(#{p}-body)" opacity=".75" stroke="#2a2038" stroke-width="1.6"/>
  <path d="M80 72c8-8 14-8 20-2 6-6 12-6 20 2" stroke="#5a4070" stroke-width="1.4" fill="none"/>
  <ellipse cx="88" cy="85" rx="5" ry="3.5" fill="#1a0820"/><ellipse cx="112" cy="85" rx="5" ry="3.5" fill="#1a0820"/>
  <circle cx="89" cy="84" r="1.5" fill="#d0a0f0"/><circle cx="113" cy="84" r="1.5" fill="#d0a0f0"/>
  <path d="M94 100c4 3 8 3 12 0" stroke="#5a4070" stroke-width="1.3" fill="none"/>
  <path d="M100 55c-6-4-6-12 0-16 6 4 6 12 0 16Z" fill="url(#{p}-acc)" opacity=".8"/>
  <g fill="url(#{p}-acc)" opacity=".5">
    <circle cx="60" cy="90" r="3"/><circle cx="145" cy="75" r="2.5"/><circle cx="55" cy="120" r="2"/>
  </g>
""" + dots(p, [(32, 70, 1.8, ".5"), (170, 65, 1.6, ".5"), (28, 130, 1.8, ".55"),
               (174, 145, 1.5, ".45"), (100, 30, 1.4, ".45"), (48, 196, 1.4, ".45"),
               (152, 190, 1.5, ".5")])


def m_qingxingdeng(p):
    # blue lantern
    return f"""  <path d="M100 30v20" stroke="url(#{p}-gold)" stroke-width="2" stroke-linecap="round"/>
  <path d="M88 50h24l6 8H82Z" fill="url(#{p}-body)" stroke="#1a2840" stroke-width="1.3"/>
  <path d="M78 58h44v70H78Z" fill="url(#{p}-acc)" opacity=".55" stroke="#1a2840" stroke-width="1.6"/>
  <path d="M78 75h44M78 95h44M78 115h44" stroke="#2a4868" stroke-width="1" opacity=".6"/>
  <path d="M90 70v50M110 70v50" stroke="#2a4868" stroke-width="1" opacity=".5"/>
  <path d="M82 128h36l-4 10H86Z" fill="url(#{p}-body)" stroke="#1a2840" stroke-width="1.3"/>
  <ellipse cx="100" cy="92" rx="14" ry="20" fill="#80c8ff" opacity=".55"/>
  <ellipse cx="100" cy="92" rx="6" ry="10" fill="#c8e8ff" opacity=".7"/>
  <ellipse cx="100" cy="165" rx="28" ry="34" fill="url(#{p}-body)" opacity=".55" stroke="#1a2840" stroke-width="1.5"/>
  <ellipse cx="88" cy="160" rx="5" ry="3.5" fill="#0a1828"/><ellipse cx="112" cy="160" rx="5" ry="3.5" fill="#0a1828"/>
  <path d="M94 178c4 3 8 3 12 0" stroke="#2a4868" stroke-width="1.3" fill="none"/>
  <path d="M70 185c8 18 16 28 30 36 14-8 22-18 30-36" fill="url(#{p}-body)" opacity=".4"/>
  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1" opacity=".4">
    <circle cx="100" cy="92" r="50"/><circle cx="100" cy="92" r="62"/>
  </g>
""" + dots(p, [(42, 70, 2.2, ".7"), (160, 65, 2, ".65"), (34, 130, 2.4, ".75"),
               (168, 135, 1.8, ".55"), (100, 24, 1.5, ".5"), (56, 190, 1.6, ".5"),
               (148, 194, 2, ".6"), (70, 48, 1.3, ".5")], f"url(#{p}-body)")


def m_zuofutongzi(p):
    # child + lucky charms
    return f"""  <ellipse cx="100" cy="88" rx="30" ry="34" fill="url(#{p}-body)" opacity=".8" stroke="#3a2818" stroke-width="1.8"/>
  <path d="M80 72c6-14 12-22 20-22s14 8 20 22" fill="url(#{p}-acc)" opacity=".7"/>
  <ellipse cx="88" cy="88" rx="5" ry="4" fill="#2a1808"/><ellipse cx="112" cy="88" rx="5" ry="4" fill="#2a1808"/>
  <circle cx="89" cy="87" r="1.6" fill="#ffb060"/><circle cx="113" cy="87" r="1.6" fill="#ffb060"/>
  <path d="M94 104c4 4 8 4 12 0" stroke="#5c3820" stroke-width="1.4" fill="none" stroke-linecap="round"/>
  <path d="M82 118c-8 12-12 30-10 50h56c2-20-2-38-10-50-8 6-28 6-36 0Z" fill="url(#{p}-body)" opacity=".55"/>
  <g>
    <rect x="42" y="120" width="22" height="30" rx="3" fill="#e8c848" stroke="#8a6020" stroke-width="1.2"/>
    <text x="53" y="140" text-anchor="middle" font-size="12" fill="#8a3020" font-family="serif">福</text>
    <rect x="136" y="115" width="22" height="30" rx="3" fill="#e8c848" stroke="#8a6020" stroke-width="1.2"/>
    <text x="147" y="135" text-anchor="middle" font-size="12" fill="#8a3020" font-family="serif">禄</text>
  </g>
  <circle cx="55" cy="175" r="12" fill="url(#{p}-acc)" opacity=".7" stroke="#8a3020" stroke-width="1.2"/>
  <text x="55" y="180" text-anchor="middle" font-size="12" fill="#fff0c0" font-family="serif">吉</text>
  <circle cx="148" cy="175" r="12" fill="url(#{p}-acc)" opacity=".7" stroke="#8a3020" stroke-width="1.2"/>
  <text x="148" y="180" text-anchor="middle" font-size="12" fill="#fff0c0" font-family="serif">祥</text>
  <path d="M100 50c-4-12 0-20 4-24 2 8 2 16-4 24Z" fill="url(#{p}-acc)" opacity=".8"/>
""" + dots(p, [(36, 70, 2, ".55"), (166, 65, 1.8, ".55"), (30, 145, 1.8, ".5"),
               (172, 145, 1.6, ".5"), (100, 28, 1.5, ".45"), (70, 200, 1.5, ".5"),
               (134, 200, 1.6, ".5")])


# ---------- unit table ----------

def pal(bg1, bg2, bg3, halo, body1, body2, acc1, acc2, frame,
        awk_bloom="rgba(255, 233, 178, 0.35)", awk_core="#ff8a3d"):
    return {
        "bg1": bg1, "bg2": bg2, "bg3": bg3, "halo": halo,
        "body1": body1, "body2": body2, "acc1": acc1, "acc2": acc2,
        "frame": frame, "awk_bloom": awk_bloom, "awk_core": awk_core,
    }


UNITS = [
    # (id, title, desc, palette, motif_fn)
    ("yaodaoji", "妖刀姬", "太刀与绯红丝带：修长刀身贯穿画心，朱带缠柄飞舞夜色",
     pal("#1c0e12", "#2a1016", "#120a0c", "#ffb066", "#fdf3e7", "#f4d9c0", "#e75b32", "#8f1f1c", "#e75b32"),
     m_yaodaoji),
    ("jutun-tongzi", "酒吞童子", "鬼角与酒葫芦：赤面鬼角童子，腰悬酒葫芦，酒气成焰",
     pal("#1a0c10", "#2c1218", "#10080c", "#e88860", "#f0c8b0", "#c87858", "#d04838", "#7a2020", "#c05040"),
     m_jutun_tongzi),
    ("bingyong", "兵俑", "甲胄与方盾：层叠甲片如阵，中央鎏金盾徽，铁壁之姿",
     pal("#121218", "#1c1c24", "#0c0c10", "#8a90a0", "#c8ccd4", "#8a90a0", "#6a7080", "#3a4050", "#6a7080"),
     m_bingyong),
    ("datiangou", "大天狗", "羽翼与团扇：墨羽张开，金骨团扇斜倚，天狗昂首",
     pal("#140c14", "#20101c", "#0e0810", "#c080a0", "#e8c8d8", "#a06080", "#a03050", "#501828", "#a03050"),
     m_datiangou),
    ("xuenv", "雪女", "冰晶雪花与雪面：六出冰花悬于额前，冰绡垂落",
     pal("#0c1418", "#142028", "#0a0e12", "#a8d8f0", "#e0f0f8", "#a0c8e0", "#70b0d8", "#306080", "#70b0d8"),
     m_xuenv),
    ("yingcao", "萤草", "萤火与草叶：柔光草叶生辉，萤点浮游如星",
     pal("#0e140c", "#182014", "#0a0e08", "#c8e070", "#e8f0c0", "#a0c060", "#b0d040", "#507020", "#a0c050"),
     m_yingcao),
    ("taohuayao", "桃花妖", "桃花五瓣：桃枝花心盛放，落英缤纷",
     pal("#180c12", "#28141c", "#100a0e", "#f0a0b8", "#f8d0e0", "#e090a8", "#e86088", "#902848", "#e86088"),
     m_taohuayao),
    ("guniao", "姑获鸟", "鸟翼与纸伞：暗翼舒展，朱伞斜撑，夜行之姿",
     pal("#120c16", "#1c1424", "#0c0810", "#a078c0", "#d0b8e0", "#8060a0", "#7040a0", "#381850", "#7040a0"),
     m_guniao),
    ("bailang", "白狼", "长弓与狼首：白狼侧影，弯弓如月",
     pal("#0c1218", "#14202c", "#0a0c12", "#80b8d8", "#d0e4f0", "#88a8c0", "#5088b0", "#204060", "#5088b0"),
     m_bailang),
    ("caitongzi", "茨木童子", "鬼角与断腕鬼爪：赤鬼面，一爪如焰张开",
     pal("#180814", "#281018", "#10060c", "#e07090", "#f0c0c8", "#c06078", "#c02858", "#601028", "#c02858"),
     m_caitongzi),
    ("xuetongzi", "雪童子", "童子与飘雪：圆面童子，雪点与冰晶环绕",
     pal("#0c141a", "#142028", "#0a1014", "#b0d8f0", "#e4f0f8", "#a0c0d8", "#80b8d0", "#407088", "#80b8d0"),
     m_xuetongzi),
    ("shantong", "山童", "远山与木棒：山形背影，肩扛木棒，山野之气",
     pal("#14100c", "#201814", "#0e0a08", "#c0a060", "#d8c8a0", "#a08860", "#a07830", "#503810", "#a07830"),
     m_shantong),
    ("tiaotiaodidi", "跳跳弟弟", "跳跃与毒泡：尖耳少年腾跃，毒泡浮游",
     pal("#0e140c", "#182018", "#0a0e0a", "#90c060", "#c8e0b0", "#80a860", "#70a830", "#305010", "#70a830"),
     m_tiaotiaodidi),
    ("qingshe", "清姬", "青蛇盘绕：蛇身环抱，信子吐出，鳞光隐隐",
     pal("#0c1412", "#14201c", "#0a0e0c", "#70c0a0", "#c0e0d0", "#70a890", "#40a878", "#185838", "#40a878"),
     m_qingshe),
    ("zhen", "鸩", "毒羽层叠：鸩鸟羽片成阵，紫粉毒光",
     pal("#120c18", "#1c1424", "#0c0810", "#c080d8", "#e0c0f0", "#9070b0", "#a040a0", "#501850", "#a040a0"),
     m_zhen),
    ("haifangzhu", "海坊主", "浪涛与僧珠：层层海浪托起光头僧形，胸前僧珠",
     pal("#0c1218", "#142028", "#0a0c12", "#60a8c8", "#c0dce8", "#70a0b8", "#4088b0", "#184058", "#4088b0"),
     m_haifangzhu),
    ("yimulian", "一目连", "神风与独目：风纹盘旋，独目居中，神社鸟居之形",
     pal("#0e140c", "#182018", "#0a0e0c", "#a0c870", "#d8e8c0", "#90b070", "#70a848", "#385818", "#70a848"),
     m_yimulian),
    ("shuweng", "书翁", "书卷与毛笔：叠书为基，笔锋悬于上方，书卷气",
     pal("#12100c", "#1c1814", "#0c0a08", "#c0b080", "#e0d8c0", "#a89870", "#b09050", "#584020", "#b09050"),
     m_shuweng),
    ("jue", "觉", "第三目与心念：额前竖瞳，心绪如环",
     pal("#120c18", "#1c1424", "#0c0810", "#b080e0", "#d8c0f0", "#8870b0", "#8048c0", "#381860", "#8048c0"),
     m_jue),
    ("quanshen", "犬神", "犬首与太刀：忠犬昂首，太刀立于身侧",
     pal("#14100c", "#201814", "#0e0a08", "#d0a060", "#e8d0b0", "#b08860", "#c07830", "#603810", "#c07830"),
     m_quanshen),
    ("panguan", "判官", "判官笔与生死簿：高冠判官，朱笔点名，卷宗在侧",
     pal("#100c12", "#18141c", "#0a080c", "#a08090", "#d0c0c8", "#887078", "#804050", "#401820", "#804050"),
     m_panguan),
    ("yijin-zhentian", "以津真天", "金羽层叠：金羽如箭簇排列，夜空流金",
     pal("#14100c", "#201810", "#0e0a08", "#e0b050", "#f0e0b0", "#c0a060", "#d0a030", "#704810", "#d0a030"),
     m_yijin_zhentian),
    ("fenghuanghuo", "凤凰火", "凤焰冲天：火舌成凤，翼焰张开，核心炽白",
     pal("#1c0c0c", "#2c1410", "#120808", "#ff9060", "#f8d0b0", "#e07040", "#e85030", "#8a2010", "#e85030"),
     m_fenghuanghuo),
    ("qingfangzhu", "青坊主", "青光与念珠：青灯之光，环列念珠，僧形端坐",
     pal("#0c1410", "#142018", "#0a0e0c", "#70d0a0", "#c0e8d0", "#70a888", "#30b070", "#185838", "#30b070"),
     m_qingfangzhu),
    ("qingwa-ciqi", "青蛙瓷器", "青蛙与麻将骰子：蛙鼓腮，骰子与發字牌散落",
     pal("#0e140c", "#182014", "#0a0e08", "#b0d060", "#d8e8b0", "#90a860", "#88b038", "#405818", "#88b038"),
     m_qingwa_ciqi),
    ("shantu", "山兔", "兔耳与骰子：长耳兔形，骰子滚落两侧",
     pal("#14100e", "#201818", "#0e0a0a", "#e0a898", "#f0d0c8", "#c09088", "#d07060", "#703028", "#d07060"),
     m_shantu),
    ("yaoginshi", "妖琴师", "琴弦与琴身：琴弦斜贯，琴身横陈，弦上音尘",
     pal("#120c16", "#1c1424", "#0c0810", "#a088c8", "#d0c0e0", "#8878a8", "#7050a8", "#382050", "#7050a8"),
     m_yaoginshi),
    ("qingxingdeng", "青行灯", "青灯提行：幽蓝灯笼高悬，灯芯冷光，面影在灯后",
     pal("#0a1218", "#12202c", "#080c12", "#60b0e0", "#c0d8f0", "#7090b0", "#4090d0", "#184068", "#4090d0"),
     m_qingxingdeng),
    ("zuofutongzi", "座敷童子", "童子与福禄吉样：福字挂件、钱袋式神，喜庆夜色",
     pal("#180c0c", "#281414", "#100808", "#f0b060", "#f8e0c0", "#e0a070", "#e07840", "#902820", "#e07840"),
     m_zuofutongzi),
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
