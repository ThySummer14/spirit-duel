#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 26 wave4-pack shikigami.

Re-runnable: writes assets/wave4/<id>.svg and <id>-awakened.svg.
Style matches assets/wave3/* — ink-night aesthetic,
viewBox 0 0 200 260. No external resources, unique gradient IDs prefixed by unit id.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave4"

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


# ---------- motif builders (folklore motifs, pure geometry) ----------

def m_jieshen(p):
    # red braided knot of fate
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round">
    <path d="M70 90c20-20 40-20 60 0s20 40 0 50-40 20-60 0-20-40 0-50z"/>
    <path d="M85 115c12-10 28-10 40 0s12 28 0 36-28 12-40 0-12-28 0-36z"/>
  </g>
  <circle cx="100" cy="130" r="6" fill="url(#{p}-gold)"/>
  <path d="M100 55c8 10 10 18 0 28-10-10-8-18 0-28z" fill="url(#{p}-body)"/>
""" + dots(p, [(40, 80, 2, ".6"), (160, 86, 1.8, ".55"), (34, 150, 1.6, ".5"),
               (168, 154, 1.6, ".5"), (100, 36, 1.8, ".55"), (70, 200, 1.5, ".5"),
               (130, 200, 1.5, ".5")])


def m_gitongwan(p):
    # oni horns + chain
    return f"""  <g>
    <path d="M100 70c-18-22-34-28-48-24 8 16 20 28 36 36Z" fill="url(#{p}-acc)"/>
    <path d="M100 70c18-22 34-28 48-24-8 16-20 28-36 36Z" fill="url(#{p}-acc)"/>
    <ellipse cx="100" cy="130" rx="30" ry="34" fill="url(#{p}-body)" stroke="#2a1418" stroke-width="2"/>
    <circle cx="88" cy="124" r="4" fill="#1a0a0c"/><circle cx="112" cy="124" r="4" fill="#1a0a0c"/>
    <path d="M90 145c6 6 14 6 20 0" stroke="#2a1418" stroke-width="1.5" fill="none"/>
  </g>
  <path d="M55 185c15-8 30-8 45 0s30 8 45 0" fill="none" stroke="url(#{p}-gold)" stroke-width="2"/>
""" + dots(p, [(40, 90, 2, ".6"), (162, 92, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 30, 1.5, ".5"), (64, 205, 1.4, ".5"),
               (136, 205, 1.4, ".5")])


def m_banruo(p):
    # hannya mask half + jealousy flames
    return f"""  <g>
    <path d="M70 90h60l-8 50-22 20-22-20Z" fill="url(#{p}-body)" stroke="#3a1818" stroke-width="2"/>
    <path d="M78 70c-4-18 0-30 10-38 2 12 2 24 0 36M122 70c4-18 0-30-10-38-2 12-2 24 0 36" fill="url(#{p}-acc)"/>
    <path d="M85 115h12M103 115h12" stroke="#1a0808" stroke-width="2"/>
    <path d="M90 135c6 4 14 4 20 0" stroke="#1a0808" stroke-width="1.5" fill="none"/>
  </g>
  <g fill="url(#{p}-acc)" opacity=".7">
    <path d="M55 175c8-14 8-24 0-34 14 6 22 18 22 34Z"/>
    <path d="M145 175c-8-14-8-24 0-34-14 6-22 18-22 34Z"/>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 157, 1.6, ".5"), (100, 32, 1.5, ".5"), (68, 210, 1.4, ".5"),
               (132, 210, 1.4, ".5")])


def m_tieshu(p):
    # coin stack + rat ears
    return f"""  <g>
    <ellipse cx="100" cy="175" rx="34" ry="10" fill="url(#{p}-gold)" stroke="#4a3010" stroke-width="1.4"/>
    <ellipse cx="100" cy="162" rx="30" ry="9" fill="url(#{p}-gold)" stroke="#4a3010" stroke-width="1.2"/>
    <ellipse cx="100" cy="150" rx="26" ry="8" fill="url(#{p}-gold)" stroke="#4a3010" stroke-width="1.2"/>
    <circle cx="100" cy="150" r="4" fill="#2a1808"/>
    <path d="M78 85c-8-18-6-30 4-36 4 12 6 24 4 36M122 85c8-18 6-30-4-36-4 12-6 24-4 36" fill="url(#{p}-body)"/>
    <ellipse cx="100" cy="115" rx="24" ry="22" fill="url(#{p}-body)" stroke="#4a3010" stroke-width="1.6"/>
    <circle cx="90" cy="112" r="3.5" fill="#1a1008"/><circle cx="110" cy="112" r="3.5" fill="#1a1008"/>
  </g>
""" + dots(p, [(40, 80, 2, ".6"), (160, 82, 1.8, ".55"), (36, 140, 1.6, ".5"),
               (168, 142, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_hetong(p):
    # kappa plate + river ripples
    return f"""  <g>
    <ellipse cx="100" cy="115" rx="28" ry="32" fill="url(#{p}-body)" stroke="#1a3830" stroke-width="2"/>
    <ellipse cx="100" cy="100" rx="14" ry="10" fill="url(#{p}-acc)" opacity=".8"/>
    <circle cx="90" cy="118" r="3.5" fill="#0a1814"/><circle cx="110" cy="118" r="3.5" fill="#0a1814"/>
    <path d="M100 85c-10-16-8-30 2-40 6 12 8 26 4 40Z" fill="url(#{p}-acc)"/>
  </g>
  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.6" opacity=".65">
    <path d="M45 175c18-8 36-8 54 0s36 8 54 0"/>
    <path d="M55 190c15-6 30-6 45 0s30 6 45 0"/>
    <path d="M65 205c12-4 24-4 36 0s24 4 36 0"/>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (34, 145, 1.6, ".5"),
               (168, 147, 1.6, ".5"), (100, 30, 1.5, ".5")])


def m_zhuiyueshen(p):
    # moon phases
    return f"""  <g>
    <circle cx="100" cy="105" r="36" fill="url(#{p}-body)" opacity=".55"/>
    <circle cx="112" cy="105" r="30" fill="url(#{p}-bg)" opacity=".85"/>
    <circle cx="100" cy="105" r="8" fill="url(#{p}-gold)"/>
  </g>
  <g fill="url(#{p}-acc)" opacity=".7">
    <circle cx="55" cy="70" r="6"/><circle cx="55" cy="70" r="3" fill="url(#{p}-bg)"/>
    <circle cx="145" cy="70" r="6"/>
    <circle cx="48" cy="160" r="5" fill="url(#{p}-bg)" stroke="url(#{p}-acc)" stroke-width="1"/>
    <circle cx="152" cy="160" r="5"/>
  </g>
""" + dots(p, [(40, 100, 2, ".6"), (160, 102, 1.8, ".55"), (70, 200, 1.6, ".5"),
               (130, 200, 1.6, ".5"), (100, 32, 1.8, ".55")])


def m_baimugui(p):
    # many eyes
    return f"""  <g>
    <ellipse cx="100" cy="130" rx="36" ry="40" fill="url(#{p}-body)" stroke="#2a2040" stroke-width="2"/>
  </g>
  <g>
    <ellipse cx="82" cy="115" rx="10" ry="7" fill="#1a1028"/><circle cx="82" cy="115" r="3" fill="url(#{p}-gold)"/>
    <ellipse cx="118" cy="115" rx="10" ry="7" fill="#1a1028"/><circle cx="118" cy="115" r="3" fill="url(#{p}-gold)"/>
    <ellipse cx="100" cy="95" rx="8" ry="6" fill="#1a1028"/><circle cx="100" cy="95" r="2.5" fill="url(#{p}-gold)"/>
    <ellipse cx="70" cy="145" rx="7" ry="5" fill="#1a1028"/><circle cx="70" cy="145" r="2" fill="url(#{p}-gold)"/>
    <ellipse cx="130" cy="145" rx="7" ry="5" fill="#1a1028"/><circle cx="130" cy="145" r="2" fill="url(#{p}-gold)"/>
    <ellipse cx="100" cy="155" rx="7" ry="5" fill="#1a1028"/><circle cx="100" cy="155" r="2" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, [(36, 80, 2, ".6"), (164, 82, 1.8, ".55"), (34, 185, 1.6, ".5"),
               (168, 187, 1.6, ".5"), (100, 30, 1.5, ".5")])


def m_wushizhiling(p):
    # broken katana + ghost flame
    return f"""  <g>
    <path d="M75 195l20-110 8 2-12 108Z" fill="url(#{p}-body)" stroke="#2a2820" stroke-width="1.4"/>
    <path d="M125 150l-8 20 18-6Z" fill="url(#{p}-acc)" opacity=".5"/>
    <path d="M75 85l20-8 8 2-12 14Z" fill="url(#{p}-acc)"/>
  </g>
  <g fill="url(#{p}-acc)" opacity=".75">
    <path d="M130 90c10-16 10-30 0-42 16 8 24 22 20 42-2 12-10 18-20 18Z"/>
  </g>
  <ellipse cx="100" cy="130" rx="14" ry="18" fill="url(#{p}-body)" opacity=".35"/>
""" + dots(p, [(40, 95, 2, ".6"), (160, 100, 1.8, ".55"), (36, 160, 1.6, ".5"),
               (168, 162, 1.6, ".5"), (100, 36, 1.5, ".5"), (68, 210, 1.4, ".5"),
               (132, 210, 1.4, ".5")])


def m_guishiheibai(p):
    # black/white dual sickles
    return f"""  <g>
    <path d="M60 80c-8 30 0 60 20 80" fill="none" stroke="#1a1a22" stroke-width="8" stroke-linecap="round"/>
    <path d="M60 80c-8 30 0 60 20 80" fill="none" stroke="url(#{p}-body)" stroke-width="3" stroke-linecap="round"/>
    <path d="M140 80c8 30 0 60-20 80" fill="none" stroke="#e8e8f0" stroke-width="8" stroke-linecap="round"/>
    <path d="M140 80c8 30 0 60-20 80" fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
    <circle cx="100" cy="140" r="16" fill="url(#{p}-body)" stroke="#2a2a38" stroke-width="1.5"/>
    <path d="M100 130v20M90 140h20" stroke="#2a2a38" stroke-width="1.2"/>
  </g>
""" + dots(p, [(38, 90, 2, ".6"), (164, 92, 1.8, ".55"), (34, 170, 1.6, ".5"),
               (168, 172, 1.6, ".5"), (100, 32, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_huoqumo(p):
    # red lotus flame
    return f"""  <g fill="url(#{p}-acc)" opacity=".9">
    <path d="M100 155c-24-20-36-40-30-58 14 8 24 24 30 42 6-18 16-34 30-42 6 18-6 38-30 58Z"/>
    <path d="M100 155c-14-24-14-44-4-58 6 14 8 34 4 58Z"/>
  </g>
  <ellipse cx="100" cy="115" rx="14" ry="20" fill="url(#{p}-body)" opacity=".55"/>
  <path d="M70 195c20-10 40-10 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="2" opacity=".5"/>
""" + dots(p, [(40, 80, 2, ".6"), (160, 82, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 157, 1.6, ".5"), (100, 36, 1.8, ".55"), (68, 205, 1.4, ".5"),
               (132, 205, 1.4, ".5")])


def m_yuanjiulanghu(p):
    # fox tails + amethyst crystal
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.4" stroke-linecap="round">
    <path d="M70 180c-10-30-8-55 6-75"/>
    <path d="M100 185c0-35 2-60 0-85"/>
    <path d="M130 180c10-30 8-55-6-75"/>
  </g>
  <polygon points="100,75 118,110 100,145 82,110" fill="url(#{p}-body)" stroke="#3a2050" stroke-width="1.6"/>
  <circle cx="100" cy="112" r="6" fill="url(#{p}-gold)" opacity=".7"/>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 32, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_yingxueji(p):
    # snow sakura brush
    return f"""  <g fill="url(#{p}-acc)" opacity=".85">
    <circle cx="85" cy="95" r="9"/><circle cx="115" cy="95" r="9"/>
    <circle cx="100" cy="82" r="9"/><circle cx="100" cy="108" r="9"/>
    <circle cx="100" cy="95" r="4" fill="url(#{p}-gold)"/>
  </g>
  <g fill="#e8f0ff" opacity=".75">
    <circle cx="55" cy="130" r="2"/><circle cx="145" cy="140" r="2.2"/>
    <circle cx="70" cy="170" r="1.6"/><circle cx="130" cy="175" r="1.8"/>
    <circle cx="100" cy="155" r="2"/>
  </g>
  <path d="M100 125v55" stroke="url(#{p}-body)" stroke-width="2" fill="none" opacity=".55"/>
  <path d="M85 195c15-8 30-8 45 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.6" opacity=".5"/>
""" + dots(p, [(40, 80, 2, ".6"), (160, 82, 1.8, ".55"), (36, 160, 1.6, ".5"),
               (168, 162, 1.6, ".5"), (100, 36, 1.8, ".55")])


def m_jingliuliqian(p):
    # glass leaf blades
    return f"""  <g>
    <path d="M100 60c-20 30-20 70 0 100 20-30 20-70 0-100Z" fill="url(#{p}-body)" opacity=".65" stroke="#1a3830" stroke-width="1.6"/>
    <path d="M70 90c-12 24-12 54 0 78 16-18 18-50 0-78Z" fill="url(#{p}-acc)" opacity=".75"/>
    <path d="M130 90c12 24 12 54 0 78-16-18-18-50 0-78Z" fill="url(#{p}-acc)" opacity=".75"/>
  </g>
  <path d="M100 70v80" stroke="url(#{p}-gold)" stroke-width="1.4" opacity=".7"/>
  <path d="M70 195c20-8 40-8 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.6" opacity=".5"/>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (34, 155, 1.6, ".5"),
               (168, 157, 1.6, ".5"), (100, 32, 1.8, ".55"), (68, 205, 1.4, ".5"),
               (132, 205, 1.4, ".5")])


def m_egui(p):
    # gaping maw + dumpling
    return f"""  <g>
    <ellipse cx="100" cy="130" rx="38" ry="32" fill="url(#{p}-body)" stroke="#3a2810" stroke-width="2"/>
    <path d="M75 130c8 16 42 16 50 0" fill="#1a1008" opacity=".8"/>
    <path d="M80 115c5 8 15 8 20 0M100 115c5 8 15 8 20 0" stroke="#3a2810" stroke-width="1.5" fill="none"/>
  </g>
  <ellipse cx="140" cy="95" rx="14" ry="10" fill="url(#{p}-acc)" stroke="#3a2810" stroke-width="1.2"/>
  <path d="M130 90c4-6 16-6 20 0" fill="none" stroke="url(#{p}-gold)" stroke-width="1.2"/>
""" + dots(p, [(36, 85, 2, ".6"), (164, 70, 1.8, ".55"), (34, 175, 1.6, ".5"),
               (168, 177, 1.6, ".5"), (100, 40, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_duiyanxiaoseng(p):
    # stone monk eye
    return f"""  <g>
    <ellipse cx="100" cy="125" rx="34" ry="40" fill="url(#{p}-body)" stroke="#3a3020" stroke-width="2"/>
    <ellipse cx="100" cy="118" rx="12" ry="16" fill="#1a1408"/>
    <circle cx="100" cy="118" r="5" fill="url(#{p}-gold)"/>
    <path d="M78 95c8-6 36-6 44 0" stroke="#3a3020" stroke-width="1.5" fill="none"/>
    <path d="M85 155c10 6 20 6 30 0" stroke="#3a3020" stroke-width="1.5" fill="none"/>
  </g>
  <path d="M55 195h90" stroke="url(#{p}-acc)" stroke-width="2" opacity=".55"/>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 157, 1.6, ".5"), (100, 36, 1.5, ".5"), (68, 210, 1.4, ".5"),
               (132, 210, 1.4, ".5")])


def m_mianqiling(p):
    # noh mask stack
    return f"""  <g>
    <ellipse cx="85" cy="115" rx="22" ry="28" fill="url(#{p}-body)" stroke="#2a2040" stroke-width="1.6" opacity=".7"/>
    <ellipse cx="115" cy="115" rx="22" ry="28" fill="url(#{p}-acc)" stroke="#2a2040" stroke-width="1.6" opacity=".85"/>
    <ellipse cx="100" cy="135" rx="26" ry="30" fill="url(#{p}-body)" stroke="#2a2040" stroke-width="2"/>
    <circle cx="90" cy="130" r="3" fill="#1a1028"/><circle cx="110" cy="130" r="3" fill="#1a1028"/>
    <path d="M92 148c5 4 11 4 16 0" stroke="#2a2040" stroke-width="1.4" fill="none"/>
  </g>
""" + dots(p, [(36, 85, 2, ".6"), (164, 87, 1.8, ".55"), (34, 165, 1.6, ".5"),
               (168, 167, 1.6, ".5"), (100, 34, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_jiumingmao(p):
    # cat paw + nine lives loop
    return f"""  <g>
    <ellipse cx="100" cy="130" rx="28" ry="32" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="2"/>
    <circle cx="88" cy="122" r="4" fill="#1a1008"/><circle cx="112" cy="122" r="4" fill="#1a1008"/>
    <path d="M85 95l-8-18 18 8M115 95l8-18-18 8" fill="url(#{p}-acc)"/>
    <path d="M94 145c4 3 8 3 12 0" stroke="#3a2818" stroke-width="1.4" fill="none"/>
  </g>
  <g fill="none" stroke="url(#{p}-gold)" stroke-width="1.6" opacity=".8">
    <circle cx="100" cy="130" r="48" stroke-dasharray="8 6"/>
  </g>
""" + dots(p, [(36, 85, 2, ".6"), (164, 87, 1.8, ".55"), (34, 165, 1.6, ".5"),
               (168, 167, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_axiuluo(p):
    # asura multi-arm + hellfire
    return f"""  <g>
    <ellipse cx="100" cy="125" rx="24" ry="30" fill="url(#{p}-body)" stroke="#3a1414" stroke-width="2"/>
    <circle cx="92" cy="120" r="3.5" fill="#1a0808"/><circle cx="108" cy="120" r="3.5" fill="#1a0808"/>
    <path d="M76 100c-18-8-30-4-38 8 14 2 24 8 30 18M124 100c18-8 30-4 38 8-14 2-24 8-30 18" fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
    <path d="M70 150c-14 6-24 16-28 28M130 150c14 6 24 16 28 28" fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
    <path d="M88 95c-2-12 2-22 12-28 2 10 2 20 0 28M112 95c2-12-2-22-12-28-2 10-2 20 0 28" fill="url(#{p}-acc)" opacity=".8"/>
  </g>
""" + dots(p, [(36, 85, 2, ".6"), (164, 87, 1.8, ".55"), (34, 175, 1.6, ".5"),
               (168, 177, 1.6, ".5"), (100, 34, 1.5, ".5")])


def m_bayiqidashe(p):
    # eight-headed snake silhouette
    return f"""  <g fill="url(#{p}-body)" opacity=".85">
    <path d="M100 180c-6-30-20-50-40-60 8 22 16 40 24 60Z"/>
    <path d="M100 180c6-30 20-50 40-60-8 22-16 40-24 60Z"/>
    <path d="M100 175c0-40 0-70 0-100 8 20 12 50 8 100Z"/>
  </g>
  <g fill="url(#{p}-acc)">
    <circle cx="55" cy="100" r="8"/><circle cx="80" cy="85" r="7"/>
    <circle cx="100" cy="75" r="8"/><circle cx="120" cy="85" r="7"/>
    <circle cx="145" cy="100" r="8"/><circle cx="70" cy="120" r="6"/>
    <circle cx="130" cy="120" r="6"/><circle cx="100" cy="110" r="6"/>
  </g>
  <circle cx="100" cy="175" r="5" fill="url(#{p}-gold)"/>
""" + dots(p, [(34, 85, 2, ".6"), (166, 87, 1.8, ".55"), (34, 165, 1.6, ".5"),
               (168, 167, 1.6, ".5"), (100, 36, 1.5, ".5")])


def m_jinyuji(p):
    # goldfish fan
    return f"""  <g>
    <ellipse cx="100" cy="125" rx="22" ry="28" fill="url(#{p}-body)" stroke="#4a2030" stroke-width="1.8"/>
    <path d="M100 153c-10 12-10 28 0 40 10-12 10-28 0-40Z" fill="url(#{p}-acc)"/>
    <circle cx="92" cy="118" r="3" fill="#1a080c"/><circle cx="108" cy="118" r="3" fill="#1a080c"/>
  </g>
  <g fill="none" stroke="url(#{p}-gold)" stroke-width="1.5" opacity=".7">
    <path d="M55 85c20-15 50-15 70 0"/>
    <path d="M50 100c25-12 55-12 80 0"/>
    <path d="M48 165c20 10 64 10 84 0"/>
  </g>
""" + dots(p, [(40, 80, 2, ".6"), (160, 82, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 36, 1.8, ".55"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_huangkulou(p):
    # giant skull + bone spikes
    return f"""  <g>
    <ellipse cx="100" cy="120" rx="32" ry="34" fill="url(#{p}-body)" stroke="#2a2418" stroke-width="2"/>
    <ellipse cx="88" cy="115" rx="7" ry="5" fill="#121008"/><ellipse cx="112" cy="115" rx="7" ry="5" fill="#121008"/>
    <path d="M92 140c5 6 11 6 16 0" stroke="#2a2418" stroke-width="1.5" fill="none"/>
    <path d="M70 100l-18-20M130 100l18-20M65 140l-20 8M135 140l20 8" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
  </g>
  <path d="M75 175v25M100 180v22M125 175v25" stroke="url(#{p}-body)" stroke-width="3" stroke-linecap="round"/>
""" + dots(p, [(38, 85, 2, ".6"), (162, 87, 1.8, ".55"), (34, 165, 1.6, ".5"),
               (168, 167, 1.6, ".5"), (100, 36, 1.5, ".5")])


def m_gouchang(p):
    # scrub brush + bubbles
    return f"""  <g>
    <rect x="85" y="100" width="30" height="55" rx="4" fill="url(#{p}-body)" stroke="#1a3030" stroke-width="1.6"/>
    <path d="M85 100c0-12 6-20 15-20s15 8 15 20" fill="url(#{p}-acc)"/>
    <g fill="#c8f0f0" opacity=".65">
      <circle cx="60" cy="95" r="8"/><circle cx="145" cy="90" r="6"/>
      <circle cx="55" cy="145" r="5"/><circle cx="150" cy="140" r="7"/>
      <circle cx="100" cy="75" r="4"/>
    </g>
    <g fill="none" stroke="#8ad0d0" stroke-width="1" opacity=".7">
      <circle cx="60" cy="95" r="8"/><circle cx="145" cy="90" r="6"/>
    </g>
  </g>
""" + dots(p, [(36, 85, 2, ".6"), (164, 87, 1.8, ".55"), (34, 175, 1.6, ".5"),
               (168, 177, 1.6, ".5"), (100, 40, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_dishitian(p):
    # lotus throne + halo
    return f"""  <g>
    <circle cx="100" cy="95" r="28" fill="url(#{p}-gold)" opacity=".35" stroke="url(#{p}-acc)" stroke-width="1.4"/>
    <ellipse cx="100" cy="130" rx="22" ry="28" fill="url(#{p}-body)" stroke="#4a3820" stroke-width="1.8"/>
  </g>
  <g fill="url(#{p}-acc)" opacity=".85">
    <path d="M100 175c-18-8-28-20-24-32 10 4 18 14 24 26 6-12 14-22 24-26 4 12-6 24-24 32Z"/>
    <path d="M100 175c-10-4-16-12-12-20 6 2 10 8 12 16 2-8 6-14 12-16 4 8-2 16-12 20Z"/>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 157, 1.6, ".5"), (100, 36, 1.8, ".55"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_xieji(p):
    # crab claw + shell
    return f"""  <g>
    <ellipse cx="100" cy="135" rx="34" ry="26" fill="url(#{p}-body)" stroke="#3a2018" stroke-width="2"/>
    <path d="M70 125c-18-8-28-4-34 8 12 0 22 4 28 12" fill="url(#{p}-acc)" stroke="#3a2018" stroke-width="1.2"/>
    <path d="M130 125c18-8 28-4 34 8-12 0-22 4-28 12" fill="url(#{p}-acc)" stroke="#3a2018" stroke-width="1.2"/>
    <circle cx="88" cy="130" r="3.5" fill="#1a1008"/><circle cx="112" cy="130" r="3.5" fill="#1a1008"/>
    <path d="M85 105c5-12 25-12 30 0" fill="url(#{p}-acc)" stroke="#3a2018" stroke-width="1.2"/>
  </g>
""" + dots(p, [(36, 90, 2, ".6"), (164, 92, 1.8, ".55"), (34, 175, 1.6, ".5"),
               (168, 177, 1.6, ".5"), (100, 40, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_yuzaoqian(p):
    # nine-tail fox + kitsunebi
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round">
    <path d="M100 175c-30-5-48-25-50-50"/>
    <path d="M100 175c-18-12-28-35-24-58"/>
    <path d="M100 175c0-25 0-50 0-72"/>
    <path d="M100 175c18-12 28-35 24-58"/>
    <path d="M100 175c30-5 48-25 50-50"/>
  </g>
  <ellipse cx="100" cy="125" rx="18" ry="24" fill="url(#{p}-body)" stroke="#3a1828" stroke-width="1.6"/>
  <circle cx="94" cy="120" r="2.5" fill="#1a080c"/><circle cx="106" cy="120" r="2.5" fill="#1a080c"/>
  <path d="M88 100l-6-14 14 6M112 100l6-14-14 6" fill="url(#{p}-acc)"/>
""" + dots(p, [(32, 90, 2, ".6"), (168, 92, 1.8, ".55"), (34, 175, 1.6, ".5"),
               (168, 177, 1.6, ".5"), (100, 36, 1.8, ".55")])


def m_huibishou(p):
    # tai fish + treasure boat
    return f"""  <g>
    <ellipse cx="100" cy="120" rx="26" ry="32" fill="url(#{p}-body)" stroke="#1a3830" stroke-width="2"/>
    <circle cx="100" cy="112" r="6" fill="url(#{p}-gold)"/>
    <path d="M85 145c5 8 25 8 30 0" stroke="#1a3830" stroke-width="1.5" fill="none"/>
  </g>
  <g>
    <path d="M55 175h90l-10 20H65Z" fill="url(#{p}-acc)" opacity=".7"/>
    <path d="M100 175v-25l25 15Z" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (160, 87, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 152, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 210, 1.4, ".5"),
               (130, 210, 1.4, ".5")])


# ---------- unit table ----------

def pal(bg1, bg2, bg3, halo, body1, body2, acc1, acc2, frame,
        awk_bloom="rgba(255, 233, 178, 0.35)", awk_core="#ff8a3d"):
    return {
        "bg1": bg1, "bg2": bg2, "bg3": bg3, "halo": halo,
        "body1": body1, "body2": body2, "acc1": acc1, "acc2": acc2,
        "frame": frame, "awk_bloom": awk_bloom, "awk_core": awk_core,
    }


UNITS = [
    ("jieshen", "缘结神", "缘结神：绯色缘结与月绳，双环相扣",
     pal("#140c10", "#201418", "#0c080c", "#f0a080", "#f8d8c8", "#e09080", "#d06050", "#702820", "#d06050"),
     m_jieshen),
    ("gitongwan", "鬼童丸", "鬼童丸：鬼角与锁链，修罗夜行",
     pal("#12080c", "#1c1014", "#0c060a", "#c07080", "#e0c0c8", "#a07080", "#a04050", "#501828", "#a04050"),
     m_gitongwan),
    ("banruo", "般若", "般若：般若面具与嫉火，半面如刃",
     pal("#140808", "#201010", "#0c0606", "#e08080", "#f0d0d0", "#c08080", "#c04040", "#601818", "#c04040"),
     m_banruo),
    ("tieshu", "铁鼠", "铁鼠：钱币叠垒与鼠耳，金光聚宝",
     pal("#141008", "#201810", "#0c0a06", "#e0c070", "#f0e0b0", "#c0a060", "#c09030", "#604010", "#c09030"),
     m_tieshu),
    ("hetong", "河童", "河童：河童皿与流水纹，川波三叠",
     pal("#0a1412", "#122420", "#080e0c", "#70c0b0", "#c0e8e0", "#70a898", "#308878", "#184038", "#308878"),
     m_hetong),
    ("zhuiyueshen", "追月神", "追月神：月相轮回与宵月，三相拱月",
     pal("#100c18", "#181428", "#0a0812", "#b0a0e0", "#d8d0f0", "#9080b0", "#7060a0", "#302860", "#7060a0"),
     m_zhuiyueshen),
    ("baimugui", "百目鬼", "百目鬼：百目窥视，瞳阵罗列",
     pal("#100818", "#181028", "#0a0612", "#a080d0", "#d0c0e8", "#8870b0", "#6040a0", "#282050", "#6040a0"),
     m_baimugui),
    ("wushizhiling", "武士之灵", "武士之灵：断刀与幽魂焰，刀折魂存",
     pal("#120e0a", "#1c1610", "#0c0a08", "#c0b090", "#e0d8c0", "#a09070", "#907050", "#403020", "#907050"),
     m_wushizhiling),
    ("guishiheibai", "鬼使黑/鬼使白", "鬼使黑/鬼使白：黑白双镰交辉，无常引路",
     pal("#0c0c10", "#14141c", "#08080c", "#9090b0", "#d0d0e0", "#8888a0", "#505070", "#202038", "#505070"),
     m_guishiheibai),
    ("huoqumo", "火取魔", "火取魔：红莲业火与剑豪，焰瓣如刃",
     pal("#140808", "#241010", "#0c0606", "#e07050", "#f0c8b8", "#c06050", "#c03828", "#601810", "#c03828"),
     m_huoqumo),
    ("yuanjiulanghu", "源九郎狐", "源九郎狐：狐尾与紫水晶，紫岩生辉",
     pal("#120c18", "#1c1428", "#0c0812", "#b080d0", "#e0d0f0", "#9080b0", "#7050a0", "#382060", "#7050a0"),
     m_yuanjiulanghu),
    ("yingxueji", "樱雪姬", "樱雪姬：雪樱五瓣与画笔，樱雪纷飞",
     pal("#140c12", "#24141c", "#0c080c", "#f0a0c0", "#f8d8e8", "#e090b0", "#d06090", "#702040", "#d06090"),
     m_yingxueji),
    ("jingliuliqian", "净琉璃御前", "净琉璃御前：琉璃叶刃与镜光，苍叶如璃",
     pal("#0a1412", "#122420", "#080e0c", "#80c8b8", "#c8e8e0", "#70a898", "#408878", "#184838", "#408878"),
     m_jingliuliqian),
    ("egui", "饿鬼", "饿鬼：巨口与饭团，饥火中烧",
     pal("#140e08", "#201810", "#0c0a08", "#d0a060", "#e8d0a8", "#b08860", "#a06030", "#503010", "#a06030"),
     m_egui),
    ("duyanxiaoseng", "独眼小僧", "独眼小僧：石像独目与袈裟，怒目金刚",
     pal("#12100a", "#1c1810", "#0c0a08", "#c0a860", "#e0d4a8", "#a89060", "#907830", "#403810", "#907830"),
     m_duiyanxiaoseng),
    ("mianqiling", "面灵气", "面灵气：能乐面具叠影，千面轮转",
     pal("#100c18", "#181428", "#0a0812", "#a890d0", "#d0c8e8", "#8878b0", "#6050a0", "#282058", "#6050a0"),
     m_mianqiling),
    ("jiumingmao", "九命猫", "九命猫：猫爪与九命环，九环绕身",
     pal("#140e0a", "#201810", "#0c0a08", "#e0a060", "#f0d0a8", "#c09060", "#c07030", "#603810", "#c07030"),
     m_jiumingmao),
    ("axiuluo", "阿修罗", "阿修罗：多臂与狱火，业焰环身",
     pal("#140808", "#201010", "#0c0606", "#d06050", "#e8b8b0", "#b06058", "#a03030", "#501010", "#a03030"),
     m_axiuluo),
    ("bayiqidashe", "八岐大蛇", "八岐大蛇：八首蛇影，狭间蛇神",
     pal("#0c140c", "#142014", "#0a0e08", "#90b060", "#d0e0b0", "#88a060", "#508030", "#204010", "#508030"),
     m_bayiqidashe),
    ("jinyuji", "金鱼姬", "金鱼姬：金鱼与扇舞，尾摇金波",
     pal("#140c12", "#24141c", "#0c080c", "#f0a090", "#f8d0c8", "#e09080", "#e06070", "#802030", "#e06070"),
     m_jinyuji),
    ("huangkulou", "荒骷髅", "荒骷髅：巨颅与骨刺，三途亡骨",
     pal("#120e0a", "#1c1610", "#0c0a08", "#c0a870", "#e0d4a8", "#a09060", "#907838", "#403818", "#907838"),
     m_huangkulou),
    ("gouchang", "垢尝", "垢尝：澡刷与净泡，阶前净雪",
     pal("#0a1414", "#122424", "#080e0e", "#80c8c8", "#c8e8e8", "#70a8a8", "#408888", "#184040", "#408888"),
     m_gouchang),
    ("dishitian", "帝释天", "帝释天：莲华座与金光轮，圣洁如王",
     pal("#141008", "#201810", "#0c0a06", "#e0c870", "#f0e4b0", "#c0a860", "#c09830", "#604810", "#c09830"),
     m_dishitian),
    ("xieji", "蟹姬", "蟹姬：蟹钳与甲壳，横行无忌",
     pal("#140c0a", "#201410", "#0c0808", "#e08060", "#f0c8b0", "#c07860", "#c05040", "#602018", "#c05040"),
     m_xieji),
    ("yuzaoqian", "玉藻前", "玉藻前：九尾与狐火，煌炎九尾",
     pal("#140810", "#201018", "#0c060c", "#e06080", "#f0c0d0", "#c06888", "#c03060", "#601030", "#c03060"),
     m_yuzaoqian),
    ("huibishou", "惠比寿", "惠比寿：鲷鱼与宝船，福运十日",
     pal("#0c1410", "#14241c", "#080e0c", "#80c8a0", "#c8e8d0", "#70a888", "#408868", "#184030", "#408868"),
     m_huibishou),
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
