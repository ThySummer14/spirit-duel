#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 19 wave3-pack shikigami.

Re-runnable: writes assets/wave3/<id>.svg and <id>-awakened.svg.
Style matches assets/ember.svg / assets/wave2/* — ink-night aesthetic,
viewBox 0 0 200 260. No external resources, unique gradient IDs prefixed by unit id.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave3"

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


# ---------- motif builders ----------

def m_biyehua(p):
    # spider lily (彼岸花)
    return f"""  <g>
    <path d="M100 200v-50" stroke="url(#{p}-body)" stroke-width="3" fill="none"/>
    <g fill="url(#{p}-acc)" opacity=".9">
      <path d="M100 150c-20-30-40-40-55-38 8 18 22 34 40 44Z"/>
      <path d="M100 150c20-30 40-40 55-38-8 18-22 34-40 44Z"/>
      <path d="M100 150c-8-34-2-52 8-62 4 16 6 36 2 52Z"/>
      <path d="M100 150c-28-18-48-16-58-6 14 10 32 16 48 14Z"/>
      <path d="M100 150c28-18 48-16 58-6-14 10-32 16-48 14Z"/>
      <path d="M100 150c-12-28-28-38-42-36 6 16 16 30 30 40Z"/>
      <path d="M100 150c12-28 28-38 42-36-6 16-16 30-30 40Z"/>
    </g>
    <circle cx="100" cy="152" r="6" fill="url(#{p}-body)"/>
  </g>
""" + dots(p, [(40, 80, 2, ".6"), (160, 86, 1.8, ".55"), (34, 150, 1.6, ".5"),
               (168, 154, 1.6, ".5"), (100, 40, 1.8, ".55"), (70, 200, 1.5, ".5"),
               (130, 200, 1.5, ".5")])


def m_huang(p):
    # starfield / moon (荒)
    return f"""  <g>
    <circle cx="100" cy="100" r="40" fill="url(#{p}-body)" opacity=".55"/>
    <circle cx="100" cy="100" r="28" fill="url(#{p}-acc)" opacity=".75"/>
    <polygon points="{star_pts(100, 100, 8, 22, 6)}" fill="url(#{p}-gold)" opacity=".9"/>
    <circle cx="100" cy="100" r="5" fill="#1a2030"/>
  </g>
  <g fill="url(#{p}-gold)" opacity=".85">
    <circle cx="48" cy="60" r="2"/><circle cx="152" cy="58" r="1.6"/>
    <circle cx="36" cy="120" r="1.5"/><circle cx="168" cy="118" r="1.8"/>
    <circle cx="60" cy="170" r="1.4"/><circle cx="145" cy="175" r="1.6"/>
  </g>
  <path d="M70 190c20-8 40-8 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.6" opacity=".5"/>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (30, 160, 1.6, ".5"),
               (172, 160, 1.6, ".5"), (100, 28, 1.8, ".55")])


def m_jiuciliang(p):
    # whale bone / armor shell (久次良)
    return f"""  <g>
    <path d="M60 160c10-50 30-80 40-80s30 30 40 80c-14 20-26 30-40 30s-26-10-40-30Z" fill="url(#{p}-body)" stroke="#1a3040" stroke-width="2"/>
    <path d="M75 150c8-30 18-48 25-48s17 18 25 48" fill="none" stroke="url(#{p}-gold)" stroke-width="1.4" opacity=".7"/>
    <path d="M88 100c4 8 8 8 12 0M100 100c4 8 8 8 12 0" stroke="#0a1820" stroke-width="1.3" fill="none"/>
    <path d="M100 70c-8-18-20-28-34-30 6 16 14 28 24 36M100 70c8-18 20-28 34-30-6 16-14 28-24 36" fill="url(#{p}-acc)" opacity=".85"/>
  </g>
""" + dots(p, [(40, 90, 2, ".6"), (164, 92, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 30, 1.5, ".5"), (64, 200, 1.5, ".5"),
               (136, 200, 1.5, ".5")])


def m_huiyeji(p):
    # bamboo / moon jar (辉夜姬)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round">
    <path d="M70 200V70"/>
    <path d="M70 100c-12-6-20-4-28 2M70 130c12-6 20-4 28 2M70 160c-12-6-20-4-28 2"/>
    <path d="M130 200V80"/>
    <path d="M130 110c12-6 20-4 28 2M130 140c-12-6-20-4-28 2"/>
  </g>
  <g>
    <ellipse cx="100" cy="120" rx="28" ry="34" fill="url(#{p}-body)" opacity=".7" stroke="#4a2840" stroke-width="1.8"/>
    <circle cx="100" cy="100" r="12" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, [(42, 80, 2, ".6"), (158, 82, 1.8, ".55"), (38, 160, 1.6, ".5"),
               (164, 162, 1.6, ".5"), (100, 32, 1.8, ".55"), (68, 200, 1.5, ".5"),
               (132, 200, 1.5, ".5")], f"url(#{p}-body)")


def m_xixueji(p):
    # bat wing / blood moon (吸血姬)
    return f"""  <g>
    <circle cx="100" cy="96" r="34" fill="url(#{p}-acc)" opacity=".75"/>
    <circle cx="88" cy="90" r="22" fill="url(#{p}-body)" opacity=".4"/>
  </g>
  <g fill="url(#{p}-body)" opacity=".9">
    <path d="M100 130c-30-10-52-6-62 8 16 2 30 10 38 22-10-2-20 2-28 10 18 0 36 6 46 16Z"/>
    <path d="M100 130c30-10 52-6 62 8-16 2-30 10-38 22 10-2 20 2 28 10-18 0-36 6-46 16Z"/>
  </g>
  <path d="M92 88c2 4 6 4 8 0M104 88c2 4 6 4 8 0" stroke="#3a1018" stroke-width="1.4" fill="none"/>
""" + dots(p, [(40, 70, 2, ".6"), (160, 72, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 28, 1.6, ".5"), (60, 200, 1.5, ".5"),
               (140, 200, 1.5, ".5")], f"url(#{p}-body)")


def m_tianjingxia(p):
    # well roof / house spirit (天井下)
    return f"""  <g>
    <path d="M50 100h100l-12-30H62Z" fill="url(#{p}-acc)" stroke="#4a3010" stroke-width="1.6"/>
    <rect x="62" y="100" width="76" height="50" rx="4" fill="url(#{p}-body)" stroke="#4a3010" stroke-width="1.6"/>
    <rect x="88" y="112" width="24" height="20" rx="2" fill="#2a1808" opacity=".7"/>
    <circle cx="100" cy="122" r="4" fill="url(#{p}-gold)"/>
  </g>
  <path d="M40 165c20 10 100 10 120 0" fill="none" stroke="url(#{p}-body)" stroke-width="2" opacity=".5"/>
  <path d="M55 180c18 8 72 8 90 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.5" opacity=".4"/>
""" + dots(p, [(42, 80, 2, ".6"), (158, 82, 1.8, ".55"), (36, 140, 1.6, ".5"),
               (168, 142, 1.6, ".5"), (100, 40, 1.5, ".5"), (70, 200, 1.5, ".5"),
               (130, 200, 1.5, ".5")])


def m_longyechaji(p):
    # double crescent / blade tide (泷夜叉姬)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round">
    <path d="M70 60c-20 30-20 70 0 100"/>
    <path d="M130 60c20 30 20 70 0 100"/>
    <path d="M85 75c-10 22-10 50 0 72"/>
    <path d="M115 75c10 22 10 50 0 72"/>
  </g>
  <ellipse cx="100" cy="115" rx="22" ry="30" fill="url(#{p}-body)" opacity=".65" stroke="#2a1a40" stroke-width="1.6"/>
  <path d="M100 40l4 16-4 6-4-6Z" fill="url(#{p}-gold)"/>
  <path d="M70 190c20-8 40-8 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.6" opacity=".5"/>
""" + dots(p, [(40, 90, 2, ".6"), (160, 92, 1.8, ".55"), (34, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 28, 1.8, ".55"), (64, 200, 1.5, ".5"),
               (136, 200, 1.5, ".5")])


def m_mengpo(p):
    # soup bowl / bridge (孟婆)
    return f"""  <g>
    <path d="M60 130c0 22 18 40 40 40s40-18 40-40Z" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="1.8"/>
    <path d="M55 130h90" stroke="url(#{p}-gold)" stroke-width="2"/>
    <path d="M75 115c5-12 15-18 25-18s20 6 25 18" fill="none" stroke="url(#{p}-acc)" stroke-width="1.6" opacity=".8"/>
    <ellipse cx="88" cy="100" rx="3" ry="5" fill="url(#{p}-body)" opacity=".6"/>
    <ellipse cx="112" cy="98" rx="2.5" ry="4" fill="url(#{p}-body)" opacity=".6"/>
  </g>
  <path d="M40 185c25-10 95-10 120 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2.2" opacity=".7"/>
  <path d="M50 198c22-6 78-6 100 0" fill="none" stroke="url(#{p}-acc)" stroke-width="1.4" opacity=".45"/>
""" + dots(p, [(42, 80, 2, ".6"), (158, 82, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_shanfeng(p):
    # mountain gale / leaf blade (山风)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.4" stroke-linecap="round" opacity=".85">
    <path d="M40 80c24 4 40 18 48 36"/>
    <path d="M36 110c22 2 38 14 46 30"/>
    <path d="M160 80c-24 4-40 18-48 36"/>
    <path d="M164 110c-22 2-38 14-46 30"/>
  </g>
  <path d="M100 50c-8 30-8 70 0 110 8-40 8-80 0-110Z" fill="url(#{p}-body)" stroke="#1a3020" stroke-width="1.8"/>
  <path d="M100 60c18 8 28 24 30 42-14-4-24-16-30-30Z" fill="url(#{p}-acc)" opacity=".8"/>
  <path d="M70 195c20-10 40-10 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.6" opacity=".5"/>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (34, 155, 1.6, ".5"),
               (168, 157, 1.6, ".5"), (100, 30, 1.6, ".5"), (66, 205, 1.4, ".5"),
               (134, 205, 1.4, ".5")])


def m_dayueling(p):
    # three sacred treasures / wave fortress (大岳丸)
    return f"""  <g>
    <circle cx="70" cy="90" r="14" fill="url(#{p}-gold)" stroke="#2a3040" stroke-width="1.4"/>
    <path d="M130 70l8 40-8 8-8-8Z" fill="url(#{p}-acc)" stroke="#2a3040" stroke-width="1.2"/>
    <rect x="90" y="120" width="20" height="36" rx="3" fill="url(#{p}-body)" stroke="#2a3040" stroke-width="1.4"/>
  </g>
  <path d="M35 175c22-14 42-4 55 10 12-16 34-24 55-10 10 6 14 14 16 22H22c2-10 6-18 13-22Z" fill="url(#{p}-body)" opacity=".75"/>
  <path d="M55 182c14-6 28-2 35 6 8-8 22-12 35-6" fill="none" stroke="#c0d8f0" stroke-width="1.2" opacity=".55"/>
""" + dots(p, [(40, 70, 2, ".6"), (164, 72, 1.8, ".55"), (34, 130, 1.6, ".5"),
               (170, 136, 1.6, ".5"), (100, 30, 1.5, ".5"), (68, 205, 1.4, ".5"),
               (132, 205, 1.4, ".5")])


def m_guiqie(p):
    # three oni blades (鬼切)
    return f"""  <g>
    <path d="M55 195l18-120 8 2-10 118Z" fill="url(#{p}-body)" stroke="#2a2838" stroke-width="1.3"/>
    <path d="M55 75l18-8 8 2-10 14Z" fill="url(#{p}-acc)"/>
    <path d="M100 200l2-130 10 0-2 130Z" fill="url(#{p}-body)" stroke="#2a2838" stroke-width="1.3"/>
    <path d="M96 70h20l-4 16H100Z" fill="url(#{p}-acc)"/>
    <path d="M145 195l-18-120 8-2 14 122Z" fill="url(#{p}-body)" stroke="#2a2838" stroke-width="1.3"/>
    <path d="M133 75l18 8 8-2-10-14Z" fill="url(#{p}-acc)"/>
  </g>
  <ellipse cx="100" cy="130" rx="20" ry="16" fill="url(#{p}-body)" opacity=".4" stroke="url(#{p}-gold)" stroke-width="1"/>
""" + dots(p, [(40, 90, 2, ".6"), (162, 92, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 28, 1.5, ".5"), (62, 205, 1.4, ".5"),
               (138, 205, 1.4, ".5")])


def m_wuguishi(p):
    # moth / gu jar (巫蛊师)
    return f"""  <g>
    <path d="M100 90c-24-20-48-18-58-2 16 4 30 14 38 28-12-4-24 0-32 10 18 0 34 6 44 16Z" fill="url(#{p}-body)" opacity=".85"/>
    <path d="M100 90c24-20 48-18 58-2-16 4-30 14-38 28 12-4 24 0 32 10-18 0-34 6-44 16Z" fill="url(#{p}-body)" opacity=".85"/>
    <ellipse cx="100" cy="115" rx="12" ry="28" fill="url(#{p}-acc)" stroke="#203018" stroke-width="1.4"/>
  </g>
  <g>
    <ellipse cx="100" cy="175" rx="22" ry="18" fill="url(#{p}-body)" stroke="#203018" stroke-width="1.5"/>
    <path d="M88 160h24v-8c0-4-4-6-12-6s-12 2-12 6Z" fill="url(#{p}-acc)"/>
  </g>
""" + dots(p, [(40, 80, 2, ".6"), (160, 82, 1.8, ".55"), (34, 145, 1.6, ".5"),
               (168, 147, 1.6, ".5"), (100, 32, 1.5, ".5"), (66, 210, 1.4, ".5"),
               (134, 210, 1.4, ".5")])


def m_yinghuayao(p):
    # sakura petals (樱花妖)
    return f"""  <g fill="url(#{p}-acc)" opacity=".9">
    <circle cx="80" cy="90" r="10"/><circle cx="120" cy="90" r="10"/>
    <circle cx="100" cy="75" r="10"/><circle cx="100" cy="110" r="10"/>
    <circle cx="100" cy="95" r="5" fill="url(#{p}-gold)"/>
  </g>
  <g fill="url(#{p}-body)" opacity=".75">
    <ellipse cx="55" cy="145" rx="7" ry="10" transform="rotate(-25 55 145)"/>
    <ellipse cx="145" cy="150" rx="7" ry="10" transform="rotate(25 145 150)"/>
    <ellipse cx="70" cy="185" rx="6" ry="9" transform="rotate(-15 70 185)"/>
    <ellipse cx="130" cy="190" rx="6" ry="9" transform="rotate(15 130 190)"/>
    <ellipse cx="100" cy="170" rx="8" ry="11"/>
  </g>
  <path d="M100 125v55" stroke="url(#{p}-body)" stroke-width="2" fill="none" opacity=".6"/>
""" + dots(p, [(40, 80, 2, ".6"), (160, 82, 1.8, ".55"), (36, 130, 1.6, ".5"),
               (168, 132, 1.6, ".5"), (100, 36, 1.8, ".55"), (60, 205, 1.4, ".5"),
               (140, 205, 1.4, ".5")])


def m_xun(p):
    # owl wing (薰)
    return f"""  <g>
    <path d="M100 85c-20-18-48-16-60 2 18 4 34 14 44 30-14-4-26 0-34 10 20 0 38 8 50 20Z" fill="url(#{p}-body)" opacity=".9"/>
    <path d="M100 85c20-18 48-16 60 2-18 4-34 14-44 30 14-4 26 0 34 10-20 0-38 8-50 20Z" fill="url(#{p}-body)" opacity=".9"/>
    <ellipse cx="100" cy="110" rx="24" ry="30" fill="url(#{p}-acc)" stroke="#1a2030" stroke-width="1.8"/>
    <circle cx="90" cy="105" r="6" fill="#0a0e18"/><circle cx="110" cy="105" r="6" fill="#0a0e18"/>
    <circle cx="91" cy="104" r="2" fill="#d0e8ff"/><circle cx="111" cy="104" r="2" fill="#d0e8ff"/>
    <path d="M100 118l3 6h-6Z" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, [(36, 80, 2, ".6"), (164, 82, 1.8, ".55"), (32, 145, 1.6, ".5"),
               (170, 147, 1.6, ".5"), (100, 30, 1.5, ".5"), (64, 205, 1.4, ".5"),
               (136, 205, 1.4, ".5")])


def m_renmianshu(p):
    # tree face (人面树)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.4" stroke-linecap="round">
    <path d="M78 70c-10-18-12-34-4-48M78 55c-14-6-24-4-32 2"/>
    <path d="M122 70c10-18 12-34 4-48M122 55c14-6 24-4 32 2"/>
  </g>
  <ellipse cx="100" cy="120" rx="34" ry="40" fill="url(#{p}-body)" stroke="#2a3818" stroke-width="2"/>
  <ellipse cx="86" cy="115" rx="6" ry="4" fill="#1a2810"/>
  <ellipse cx="114" cy="115" rx="6" ry="4" fill="#1a2810"/>
  <path d="M88 135c8 8 16 8 24 0" stroke="#2a3818" stroke-width="1.6" fill="none"/>
  <path d="M100 160v40" stroke="url(#{p}-body)" stroke-width="4" fill="none"/>
  <path d="M85 185c-12 4-20 12-24 22M115 185c12 4 20 12 24 22" stroke="url(#{p}-body)" stroke-width="2.2" fill="none"/>
""" + dots(p, [(40, 95, 2, ".6"), (162, 98, 1.8, ".55"), (34, 155, 1.6, ".5"),
               (168, 157, 1.6, ".5"), (100, 28, 1.5, ".5")])


def m_tiaotiaogege(p):
    # coffin (跳跳哥哥)
    return f"""  <g>
    <path d="M75 70h50l12 40v70H63v-70Z" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="2"/>
    <path d="M85 100h30v20H85Z" fill="url(#{p}-gold)" opacity=".65"/>
    <path d="M100 100v20M85 110h30" stroke="#3a2818" stroke-width="1.2"/>
    <path d="M75 70c5-12 45-12 50 0" fill="url(#{p}-acc)" stroke="#3a2818" stroke-width="1.4"/>
  </g>
  <path d="M55 195h90" stroke="url(#{p}-acc)" stroke-width="2" opacity=".6"/>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 32, 1.5, ".5"), (68, 210, 1.4, ".5"),
               (132, 210, 1.4, ".5")])


def m_shimengmo(p):
    # dream mist / tapir (食梦貘)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2" stroke-linecap="round" opacity=".8">
    <path d="M45 100c16-18 40-14 50 4 8 16-2 32-18 36"/>
    <path d="M50 140c12-14 32-12 40 4"/>
    <path d="M155 100c-16-18-40-14-50 4-8 16 2 32 18 36"/>
    <path d="M150 140c-12-14-32-12-40 4"/>
  </g>
  <ellipse cx="100" cy="115" rx="30" ry="34" fill="url(#{p}-body)" opacity=".7" stroke="#2a2040" stroke-width="1.8"/>
  <ellipse cx="88" cy="112" rx="5" ry="3.5" fill="#1a1030"/>
  <ellipse cx="112" cy="112" rx="5" ry="3.5" fill="#1a1030"/>
  <path d="M94 130c4 4 8 4 12 0" stroke="#2a2040" stroke-width="1.4" fill="none"/>
  <ellipse cx="100" cy="85" rx="8" ry="6" fill="url(#{p}-gold)" opacity=".6"/>
""" + dots(p, [(40, 75, 2, ".6"), (160, 77, 1.8, ".55"), (34, 155, 1.8, ".55"),
               (168, 157, 1.6, ".5"), (100, 30, 1.6, ".5"), (64, 205, 1.4, ".5"),
               (136, 205, 1.4, ".5")], f"url(#{p}-body)")


def m_yujiazhu(p):
    # bow + ofuda (御馔津)
    return f"""  <g>
    <path d="M70 55c-22 32-22 78 0 110" fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
    <path d="M70 55h10M70 165h10" stroke="url(#{p}-gold)" stroke-width="1.5"/>
    <path d="M76 58v104" stroke="url(#{p}-body)" stroke-width="1.1" opacity=".65"/>
  </g>
  <g>
    <rect x="120" y="85" width="28" height="48" rx="2" fill="url(#{p}-body)" stroke="#4a3010" stroke-width="1.4"/>
    <path d="M128 95h12M128 105h12M128 115h12" stroke="url(#{p}-acc)" stroke-width="1.4"/>
  </g>
  <path d="M45 185c25-8 85-8 110 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.8" opacity=".5"/>
""" + dots(p, [(42, 80, 2, ".6"), (168, 80, 1.8, ".55"), (36, 140, 1.6, ".5"),
               (172, 150, 1.6, ".5"), (100, 32, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_sanmu(p):
    # three eyes / cat banner (三目)
    return f"""  <g>
    <ellipse cx="100" cy="115" rx="36" ry="34" fill="url(#{p}-body)" stroke="#3a3020" stroke-width="2"/>
    <circle cx="82" cy="108" r="6" fill="#1a1408"/><circle cx="118" cy="108" r="6" fill="#1a1408"/>
    <circle cx="100" cy="92" r="5" fill="url(#{p}-gold)"/>
    <path d="M92 128c5 6 11 6 16 0" stroke="#3a3020" stroke-width="1.6" fill="none"/>
    <path d="M70 95l-14-8M130 95l14-8M72 125l-14 8M128 125l14 8" stroke="url(#{p}-acc)" stroke-width="1.4"/>
  </g>
  <path d="M55 185h90l-8 20H63Z" fill="url(#{p}-acc)" opacity=".55"/>
""" + dots(p, [(40, 80, 2, ".6"), (160, 82, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 36, 1.5, ".5"), (68, 210, 1.4, ".5"),
               (132, 210, 1.4, ".5")])


# ---------- unit table ----------

def pal(bg1, bg2, bg3, halo, body1, body2, acc1, acc2, frame,
        awk_bloom="rgba(255, 233, 178, 0.35)", awk_core="#ff8a3d"):
    return {
        "bg1": bg1, "bg2": bg2, "bg3": bg3, "halo": halo,
        "body1": body1, "body2": body2, "acc1": acc1, "acc2": acc2,
        "frame": frame, "awk_bloom": awk_bloom, "awk_core": awk_core,
    }


UNITS = [
    ("biyehua", "彼岸花", "彼岸花：赤团华绽放于夜色，花瓣如刃",
     pal("#180c10", "#281418", "#10080c", "#f0a0b0", "#f8d0c8", "#e08090", "#d04060", "#701830", "#d04060"),
     m_biyehua),
    ("huang", "荒", "荒：星轨与月轮，中央星芒聚辉",
     pal("#0c101c", "#141c30", "#0a0c14", "#8090e0", "#d0d8f8", "#8890c0", "#5060c0", "#203070", "#5060c0"),
     m_huang),
    ("jiuciliang", "久次良", "久次良：鲸骨护甲与鲸尾，层甲如鳞",
     pal("#0a1418", "#122428", "#080e12", "#70b0c0", "#c0e0e8", "#70a0b0", "#3080a0", "#184050", "#3080a0"),
     m_jiuciliang),
    ("huiyeji", "辉夜姬", "辉夜姬：竹影与月壶，竹叶对生",
     pal("#140c18", "#201428", "#0c0810", "#d0a0e0", "#e8d0f0", "#b090c0", "#a060c0", "#502070", "#a060c0"),
     m_huiyeji),
    ("xixueji", "吸血姬", "吸血姬：血月与蝠翼，双翼环月",
     pal("#18080c", "#2c1018", "#10060a", "#f08090", "#f0c0c8", "#c06078", "#c02848", "#601028", "#c02848"),
     m_xixueji),
    ("tianjingxia", "天井下", "天井下：妖怪屋顶与灵灯，檐角飞翘",
     pal("#141008", "#201810", "#0c0a06", "#e0c070", "#f0e0b0", "#c0a060", "#c09030", "#604010", "#c09030"),
     m_tianjingxia),
    ("longyechaji", "泷夜叉姬", "泷夜叉姬：双新月与刀浪，月刃交叠",
     pal("#120c1c", "#1c1430", "#0c0814", "#a080e0", "#d0c0f0", "#9080c0", "#7050c0", "#302060", "#7050c0"),
     m_longyechaji),
    ("mengpo", "孟婆", "孟婆：汤碗与奈何桥，桥影卧波",
     pal("#120e0c", "#1c1614", "#0c0a08", "#c0a080", "#e0d0b8", "#a08870", "#8a6040", "#403020", "#8a6040"),
     m_mengpo),
    ("shanfeng", "山风", "山风：叶刃与山岚，风卷双弧",
     pal("#0c140c", "#142014", "#0a0e08", "#80c080", "#d0e8c8", "#88b070", "#50a040", "#204818", "#50a040"),
     m_shanfeng),
    ("dayueling", "大岳丸", "大岳丸：三神器与海浪，铃鹿山势",
     pal("#0a1218", "#122030", "#080c12", "#70a0d0", "#c0d8f0", "#7090b0", "#4070a0", "#183850", "#4070a0"),
     m_dayueling),
    ("guiqie", "鬼切", "鬼切：三柄鬼刃并立，刃鸣夜色",
     pal("#0c0c14", "#141420", "#080810", "#9090c0", "#d0d0e0", "#8888a8", "#505080", "#202040", "#505080"),
     m_guiqie),
    ("wuguishi", "巫蛊师", "巫蛊师：蛊蛾与蛊罐，双翼展开",
     pal("#0c1408", "#142010", "#080c06", "#90c060", "#d0e8b0", "#88a860", "#50a030", "#204810", "#50a030"),
     m_wuguishi),
    ("yinghuayao", "樱花妖", "樱花妖：五瓣樱与落英，花瓣旋落",
     pal("#180c12", "#28141c", "#10080c", "#f0a0c0", "#f8d0e0", "#e090b0", "#e06090", "#802040", "#e06090"),
     m_yinghuayao),
    ("xun", "薰", "薰：鸮翼与守护羽，双翼护心",
     pal("#0c1018", "#141c2c", "#080a12", "#80a0e0", "#c8d8f8", "#8090c0", "#5070c0", "#203870", "#5070c0"),
     m_xun),
    ("renmianshu", "人面树", "人面树：树干面容与根须，枝角如冠",
     pal("#0c140c", "#142014", "#0a0e08", "#90b060", "#d0e0b0", "#88a060", "#60a030", "#284818", "#60a030"),
     m_renmianshu),
    ("tiaotiaogege", "跳跳哥哥", "跳跳哥哥：棺木与封印，棺盖金印",
     pal("#120e0a", "#1c1610", "#0c0a08", "#c0a070", "#e0d0a8", "#a08860", "#a07030", "#503010", "#a07030"),
     m_tiaotiaogege),
    ("shimengmo", "食梦貘", "食梦貘：梦雾与貘面，双雾环抱",
     pal("#0e0a18", "#181228", "#0a0812", "#a080d0", "#d0c0e8", "#9080b0", "#6050a0", "#282050", "#6050a0"),
     m_shimengmo),
    ("yujiazhu", "御馔津", "御馔津：长弓与符咒，弦张符悬",
     pal("#141008", "#201810", "#0c0a06", "#e0c070", "#f0e0b0", "#c0a060", "#c09030", "#604010", "#c09030"),
     m_yujiazhu),
    ("sanmu", "三目", "三目：三眼猫又与委托旗，旗幡垂落",
     pal("#120e0a", "#1c1610", "#0c0a08", "#c0a880", "#e0d4b8", "#a89880", "#9a7848", "#4a3820", "#9a7848"),
     m_sanmu),
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
