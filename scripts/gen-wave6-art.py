#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 32 wave6-pack shikigami.

Re-runnable: writes assets/wave6/<id>.svg and <id>-awakened.svg.
Style matches assets/wave3/* — ink-night aesthetic, viewBox 0 0 200 260.
No external resources, unique gradient IDs prefixed by unit id. No NetEase art.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave6"

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


# ---------- motif builders (pure original SVG shapes) ----------

def m_jinnaluo(p):
    # kinnara: winged lute / harp arcs (紧那罗)
    return f"""  <g>
    <path d="M60 170c10-50 30-80 40-80s30 30 40 80" fill="url(#{p}-body)" opacity=".55" stroke="#2a2040" stroke-width="1.6"/>
    <path d="M70 70c-18 20-22 50-10 80M130 70c18 20 22 50 10 80" fill="none" stroke="url(#{p}-acc)" stroke-width="2.2"/>
    <path d="M78 90h44M76 105h48M78 120h44" stroke="url(#{p}-gold)" stroke-width="1.2" opacity=".8"/>
    <polygon points="{star_pts(100, 58, 6, 16, 5)}" fill="url(#{p}-gold)" opacity=".85"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_lingyanji(p):
    # sacred bell + flame (铃彦姬)
    return f"""  <g>
    <path d="M75 160c0-40 8-70 25-70s25 30 25 70Z" fill="url(#{p}-body)" stroke="#3a2010" stroke-width="1.8"/>
    <rect x="70" y="158" width="60" height="10" rx="3" fill="url(#{p}-gold)"/>
    <circle cx="100" cy="168" r="5" fill="url(#{p}-acc)"/>
    <path d="M100 70c-8 12-4 22 0 28 4-6 8-16 0-28Z" fill="url(#{p}-acc)"/>
    <path d="M88 82c-4 8-2 14 0 18M112 82c4 8 2 14 0 18" stroke="url(#{p}-gold)" stroke-width="1.3" fill="none"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_rurineque(p):
    # sparrow ghost / hollow nest (入内雀)
    return f"""  <g>
    <ellipse cx="100" cy="130" rx="40" ry="36" fill="url(#{p}-body)" opacity=".65" stroke="#1a2818" stroke-width="1.8"/>
    <path d="M70 120c-14-10-24-8-32 2 14 4 24 8 32 14M130 120c14-10 24-8 32 2-14 4-24 8-32 14" fill="url(#{p}-acc)" opacity=".85"/>
    <circle cx="88" cy="125" r="5" fill="#0a1008"/><circle cx="112" cy="125" r="5" fill="#0a1008"/>
    <path d="M96 142c3 4 8 4 11 0" stroke="#1a2818" stroke-width="1.4" fill="none"/>
    <path d="M100 88c-6-14 0-24 8-30 2 12 0 22-8 30Z" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_shouwu(p):
    # floating head + tachi (首无)
    return f"""  <g>
    <circle cx="100" cy="100" r="32" fill="url(#{p}-body)" stroke="#2a1820" stroke-width="1.8"/>
    <path d="M85 95c2-6 8-8 12-2M115 95c-2-6-8-8-12-2" stroke="#2a1820" stroke-width="1.4" fill="none"/>
    <path d="M90 115c6 6 14 6 20 0" stroke="#2a1820" stroke-width="1.4" fill="none"/>
    <path d="M145 60v100" stroke="url(#{p}-gold)" stroke-width="3" stroke-linecap="round"/>
    <path d="M138 60h14M138 70h14" stroke="url(#{p}-acc)" stroke-width="2"/>
    <path d="M70 175c20-10 40-10 60 0" stroke="url(#{p}-body)" stroke-width="2" fill="none" opacity=".6"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_gunvhongye(p):
    # red maple + doll seal (鬼女红叶)
    return f"""  <g fill="url(#{p}-acc)" opacity=".9">
    <path d="M100 155c-18-22-34-28-48-24 10 14 24 24 40 30Z"/>
    <path d="M100 155c18-22 34-28 48-24-10 14-24 24-40 30Z"/>
    <path d="M100 155c-6-28 0-44 8-54 2 14 2 36-2 54Z"/>
  </g>
  <g>
    <rect x="88" y="78" width="24" height="34" rx="3" fill="url(#{p}-body)" stroke="#401820" stroke-width="1.4"/>
    <circle cx="100" cy="70" r="10" fill="url(#{p}-gold)" opacity=".75"/>
    <path d="M92 90h16M92 98h16" stroke="#401820" stroke-width="1.2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_choushizhinv(p):
    # straw doll + nail (丑时之女)
    return f"""  <g>
    <rect x="88" y="100" width="24" height="50" rx="4" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="1.6"/>
    <circle cx="100" cy="88" r="12" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="1.4"/>
    <path d="M88 115h-18M112 115h18M88 140h-14M112 140h14" stroke="url(#{p}-acc)" stroke-width="2" stroke-linecap="round"/>
    <path d="M100 55v20" stroke="url(#{p}-gold)" stroke-width="2.5" stroke-linecap="round"/>
    <path d="M96 55h8l-4-12Z" fill="url(#{p}-gold)"/>
    <circle cx="100" cy="118" r="4" fill="#401010"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yifanmumian(p):
    # cloth bandage wrap / mummy ribbon (一反木绵)
    return f"""  <g fill="none" stroke="url(#{p}-body)" stroke-width="5" stroke-linecap="round">
    <path d="M55 80c30 10 60 10 90-5"/>
    <path d="M50 110c35 12 70 8 100-8"/>
    <path d="M55 140c30 14 65 10 95-6"/>
    <path d="M65 168c28 10 55 8 80-4"/>
  </g>
  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.6" opacity=".7">
    <path d="M55 80c30 10 60 10 90-5"/>
    <path d="M50 110c35 12 70 8 100-8"/>
  </g>
  <circle cx="100" cy="55" r="8" fill="url(#{p}-gold)" opacity=".75"/>
""" + dots(p, DEFAULT_DOTS)


def m_yecha(p):
    # oni claw / fang mask (夜叉)
    return f"""  <g>
    <path d="M70 95c10-30 50-30 60 0 8 22-4 55-30 55S62 117 70 95Z" fill="url(#{p}-body)" stroke="#201828" stroke-width="1.8"/>
    <path d="M78 100l-8-18M100 95v-20M122 100l8-18" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round"/>
    <path d="M82 118c4 8 12 12 18 4M118 118c-4 8-12 12-18 4" stroke="#201828" stroke-width="1.5" fill="none"/>
    <circle cx="88" cy="112" r="3" fill="url(#{p}-gold)"/><circle cx="112" cy="112" r="3" fill="url(#{p}-gold)"/>
    <path d="M55 175c25 12 65 12 90 0" stroke="url(#{p}-body)" stroke-width="2" fill="none" opacity=".5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_huangchuanzhizhu(p):
    # river god / wave crest (荒川之主)
    return f"""  <g>
    <path d="M40 150c20-30 40-30 60 0 20-30 40-30 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="3"/>
    <path d="M40 170c20-24 40-24 60 0 20-24 40-24 60 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2" opacity=".8"/>
    <path d="M100 70c-16 20-16 50 0 70 16-20 16-50 0-70Z" fill="url(#{p}-body)" opacity=".7"/>
    <polygon points="{star_pts(100, 70, 5, 14, 4)}" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_wannianzhu(p):
    # bamboo flute sword (万年竹)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.4" stroke-linecap="round">
    <path d="M75 195V75"/>
    <path d="M75 105c-14-8-24-6-32 2M75 140c14-8 24-6 32 2M75 170c-14-8-24-6-32 2"/>
  </g>
  <g>
    <path d="M125 60v100" stroke="url(#{p}-body)" stroke-width="3.5" stroke-linecap="round"/>
    <path d="M118 58h14l-7-14Z" fill="url(#{p}-gold)"/>
    <circle cx="125" cy="120" r="3" fill="#102010"/>
    <circle cx="125" cy="145" r="3" fill="#102010"/>
    <circle cx="125" cy="95" r="3" fill="#102010"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_shuzhu(p):
    # prayer beads (数珠)
    beads = []
    for i in range(12):
        x, y = polar(100, 125, 42, -90 + i * 30)
        beads.append(f'    <circle cx="{x:.1f}" cy="{y:.1f}" r="6" fill="url(#{p}-body)" stroke="#2a2418" stroke-width="1"/>')
    return f"""  <g>
{chr(10).join(beads)}
    <circle cx="100" cy="83" r="8" fill="url(#{p}-gold)"/>
    <path d="M100 91v18" stroke="url(#{p}-gold)" stroke-width="2"/>
    <rect x="92" y="155" width="16" height="28" rx="2" fill="url(#{p}-acc)" opacity=".75"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_sanweihu(p):
    # three-tail fox swirl (三尾狐)
    return f"""  <g fill="none" stroke="url(#{p}-body)" stroke-width="3.2" stroke-linecap="round">
    <path d="M100 160c-20-10-35-35-25-60 8 20 18 35 25 45"/>
    <path d="M100 160c20-10 35-35 25-60-8 20-18 35-25 45"/>
    <path d="M100 160c0-30 0-55 0-75"/>
  </g>
  <g>
    <ellipse cx="100" cy="95" rx="16" ry="14" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M88 88l-6-14M112 88l6-14" stroke="url(#{p}-gold)" stroke-width="2" stroke-linecap="round"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_jicanghai(p):
    # charge blade / mountain cleave (季沧海)
    return f"""  <g>
    <path d="M60 175L130 55l20 10-70 120Z" fill="url(#{p}-body)" opacity=".75" stroke="#203040" stroke-width="1.6"/>
    <path d="M125 60l18 8" stroke="url(#{p}-gold)" stroke-width="2"/>
    <path d="M70 150c20-8 40-8 55 2" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
    <circle cx="95" cy="120" r="10" fill="url(#{p}-acc)" opacity=".55"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_wuchen(p):
    # dual ring blade / step void (无尘)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.5">
    <circle cx="75" cy="115" r="28"/>
    <circle cx="125" cy="115" r="28"/>
  </g>
  <g fill="none" stroke="url(#{p}-gold)" stroke-width="1.4" opacity=".8">
    <circle cx="75" cy="115" r="18"/>
    <circle cx="125" cy="115" r="18"/>
  </g>
  <path d="M100 70v90" stroke="url(#{p}-body)" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M55 175h90" stroke="url(#{p}-body)" stroke-width="2" opacity=".5"/>
""" + dots(p, DEFAULT_DOTS)


def m_ninghongye(p):
    # phoenix feather arrow (宁红夜)
    return f"""  <g>
    <path d="M55 175L145 70" stroke="url(#{p}-body)" stroke-width="3" stroke-linecap="round"/>
    <path d="M145 70l-4 18-14-8Z" fill="url(#{p}-gold)"/>
    <path d="M55 175c-6-4-8-12-4-18M55 175c4-6 12-8 18-4" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
    <path d="M90 130c-10-18-8-34 2-46 4 16 4 32-2 46Z" fill="url(#{p}-acc)" opacity=".7"/>
    <path d="M115 105c10-14 22-18 34-14-10 8-20 14-34 14Z" fill="url(#{p}-acc)" opacity=".6"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_tayumenhutao(p):
    # onmyoji crest / peach ward (土御门胡桃)
    return f"""  <g>
    <circle cx="100" cy="120" r="38" fill="url(#{p}-body)" opacity=".55" stroke="#2a2838" stroke-width="1.6"/>
    <polygon points="{star_pts(100, 120, 10, 34, 5, -90)}" fill="none" stroke="url(#{p}-gold)" stroke-width="1.4" opacity=".85"/>
    <path d="M100 95c-8 8-8 22 0 30 8-8 8-22 0-30Z" fill="url(#{p}-acc)" opacity=".75"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_baize(p):
    # baize beast face / lore scroll (白泽)
    return f"""  <g>
    <path d="M70 130c8-35 22-55 30-55s22 20 30 55c-10 18-20 28-30 28s-20-10-30-28Z" fill="url(#{p}-body)" stroke="#203028" stroke-width="1.6"/>
    <path d="M78 95l-12-22M122 95l12-22" stroke="url(#{p}-gold)" stroke-width="2" stroke-linecap="round"/>
    <circle cx="88" cy="120" r="4" fill="#102018"/><circle cx="112" cy="120" r="4" fill="#102018"/>
    <path d="M92 138c5 5 11 5 16 0" stroke="#203028" stroke-width="1.3" fill="none"/>
    <rect x="72" y="168" width="56" height="18" rx="2" fill="url(#{p}-acc)" opacity=".55"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_hudiejing(p):
    # butterfly wings (蝴蝶精)
    return f"""  <g>
    <path d="M100 120c-30-35-55-30-55-5 0 22 22 35 45 25" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M100 120c30-35 55-30 55-5 0 22-22 35-45 25" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M100 120c-18 15-28 35-18 50 14-4 24-18 25-38" fill="url(#{p}-body)" opacity=".7"/>
    <path d="M100 120c18 15 28 35 18 50-14-4-24-18-25-38" fill="url(#{p}-body)" opacity=".7"/>
    <circle cx="100" cy="115" r="8" fill="url(#{p}-body)"/>
    <path d="M95 100c-2-12-8-18-14-22M105 100c2-12 8-18 14-22" stroke="url(#{p}-gold)" stroke-width="1.5" fill="none"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_luoxinfu(p):
    # spider mark / silk web (络新妇)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.3" opacity=".8">
    <path d="M100 70v100M55 120h90M70 85l60 70M130 85l-60 70"/>
    <circle cx="100" cy="120" r="40"/>
    <circle cx="100" cy="120" r="24"/>
    <circle cx="100" cy="120" r="10"/>
  </g>
  <g>
    <ellipse cx="100" cy="120" rx="10" ry="12" fill="url(#{p}-body)" stroke="#201020" stroke-width="1.2"/>
    <path d="M90 110l-14-10M110 110l14-10M90 130l-14 10M110 130l14 10" stroke="url(#{p}-gold)" stroke-width="1.4"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yitiao(p):
    # diligence scroll / sword stance (一条)
    return f"""  <g>
    <rect x="78" y="75" width="44" height="70" rx="3" fill="url(#{p}-body)" opacity=".7" stroke="#2a2830" stroke-width="1.4"/>
    <path d="M88 90h24M88 105h24M88 120h18" stroke="url(#{p}-acc)" stroke-width="1.4"/>
    <path d="M55 175h90" stroke="url(#{p}-gold)" stroke-width="2"/>
    <path d="M70 175l30-40 30 40" fill="none" stroke="url(#{p}-body)" stroke-width="2"/>
    <circle cx="100" cy="60" r="8" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_jialouluo(p):
    # garuda wing / golden halberd (迦楼罗)
    return f"""  <g>
    <path d="M100 95c-25-25-55-28-70-12 20 8 40 20 55 38" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M100 95c25-25 55-28 70-12-20 8-40 20-55 38" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M100 85v70" stroke="url(#{p}-gold)" stroke-width="3" stroke-linecap="round"/>
    <path d="M100 85l-8 12h16Z" fill="url(#{p}-gold)"/>
    <path d="M88 145h24l-12 28Z" fill="url(#{p}-body)" opacity=".75"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_huajing(p):
    # whale calf / armor shell (化鲸)
    return f"""  <g>
    <path d="M55 145c15-40 35-60 45-60s30 20 45 60c-12 16-28 24-45 24s-33-8-45-24Z" fill="url(#{p}-body)" stroke="#183040" stroke-width="1.8"/>
    <path d="M75 135c8-24 18-38 25-38s17 14 25 38" fill="none" stroke="url(#{p}-gold)" stroke-width="1.3" opacity=".7"/>
    <path d="M100 70c-8-16-22-24-36-26 6 14 14 24 24 32M100 70c8-16 22-24 36-26-6 14-14 24-24 32" fill="url(#{p}-acc)" opacity=".8"/>
    <ellipse cx="88" cy="130" rx="4" ry="5" fill="#0a1820"/><ellipse cx="112" cy="130" rx="4" ry="5" fill="#0a1820"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yinge(p):
    # shadow crocodile / ghost scale (影鳄)
    return f"""  <g>
    <path d="M45 145c20-35 50-50 70-45 25 6 40 25 40 45-25 10-55 12-85 5Z" fill="url(#{p}-body)" stroke="#102018" stroke-width="1.6"/>
    <path d="M55 140c15-20 35-28 55-24" fill="none" stroke="url(#{p}-acc)" stroke-width="1.5"/>
    <circle cx="130" cy="115" r="5" fill="url(#{p}-gold)"/>
    <path d="M60 150l8 6 8-6 8 6 8-6" stroke="#102018" stroke-width="1.3" fill="none"/>
    <path d="M70 105c-4-12 0-22 8-28" stroke="url(#{p}-acc)" stroke-width="1.8" fill="none"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_bujianyue(p):
    # mountain peak + vanishing realm (不见岳)
    return f"""  <g>
    <path d="M45 175L95 85l25 40 15-25 25 75Z" fill="url(#{p}-body)" opacity=".7" stroke="#203028" stroke-width="1.5"/>
    <path d="M85 105l12-22 10 18" fill="none" stroke="url(#{p}-gold)" stroke-width="1.6"/>
    <rect x="70" y="155" width="60" height="4" rx="2" fill="url(#{p}-acc)" opacity=".5"/>
    <circle cx="100" cy="70" r="10" fill="none" stroke="url(#{p}-gold)" stroke-width="1.4" opacity=".7"/>
    <circle cx="100" cy="70" r="3" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_xuzuozhinan(p):
    # thunder god bolt / storm (须佐之男)
    bolt = "M110 55L75 120h25L90 175l50-80h-28L135 55Z"
    return f"""  <g>
    <path d="{bolt}" fill="url(#{p}-gold)" opacity=".9" stroke="#5a3010" stroke-width="1"/>
    <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.6" opacity=".7">
      <path d="M45 80c20-15 40-15 55 0"/>
      <path d="M100 80c20-15 40-15 55 0"/>
      <path d="M55 160c15-12 35-12 50 0"/>
      <path d="M105 160c15-12 35-12 50 0"/>
    </g>
    <circle cx="100" cy="112" r="8" fill="url(#{p}-body)" opacity=".5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_liyujing(p):
    # carp / bubble shield (鲤鱼精)
    return f"""  <g>
    <ellipse cx="100" cy="125" rx="36" ry="28" fill="url(#{p}-body)" stroke="#183040" stroke-width="1.6"/>
    <path d="M64 125c-14-12-22-12-28-4 10 4 18 10 28 12M136 125c14-12 22-12 28-4-10 4-18 10-28 12" fill="url(#{p}-acc)" opacity=".8"/>
    <circle cx="115" cy="118" r="3.5" fill="#102030"/>
    <path d="M95 135c6 5 14 5 20 0" stroke="#183040" stroke-width="1.3" fill="none"/>
    <circle cx="70" cy="75" r="8" fill="none" stroke="url(#{p}-gold)" stroke-width="1.3" opacity=".7"/>
    <circle cx="88" cy="58" r="5" fill="none" stroke="url(#{p}-gold)" stroke-width="1.1" opacity=".6"/>
    <circle cx="125" cy="70" r="4" fill="none" stroke="url(#{p}-gold)" stroke-width="1.1" opacity=".55"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_chongshi(p):
    # insect master / moth swarm (虫师)
    return f"""  <g>
    <ellipse cx="100" cy="125" rx="18" ry="30" fill="url(#{p}-body)" stroke="#203018" stroke-width="1.5"/>
    <path d="M82 115c-22-18-38-14-44 2 18 2 32 8 44 18Z" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M118 115c22-18 38-14 44 2-18 2-32 8-44 18Z" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M82 135c-16 10-24 22-18 34 12-4 24-14 30-24Z" fill="url(#{p}-body)" opacity=".6"/>
    <path d="M118 135c16 10 24 22 18 34-12-4-24-14-30-24Z" fill="url(#{p}-body)" opacity=".6"/>
    <path d="M92 100c-2-12-8-18-14-22M108 100c2-12 8-18 14-22" stroke="url(#{p}-gold)" stroke-width="1.4" fill="none"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_xieenv(p):
    # scorpion stinger (蝎女)
    return f"""  <g>
    <ellipse cx="95" cy="140" rx="28" ry="18" fill="url(#{p}-body)" stroke="#301820" stroke-width="1.5"/>
    <path d="M70 145c-18 0-28 8-32 18M70 135c-16-6-28-4-36 4M120 145c16 2 28 10 30 20M120 135c14-8 28-6 36 2" stroke="url(#{p}-acc)" stroke-width="2.2" fill="none" stroke-linecap="round"/>
    <path d="M115 130c20-15 30-35 22-55-4 18-14 32-28 42" fill="none" stroke="url(#{p}-gold)" stroke-width="2.5" stroke-linecap="round"/>
    <path d="M137 75l6-12 4 12Z" fill="url(#{p}-gold)"/>
    <circle cx="85" cy="135" r="3" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_xunxiangxing(p):
    # incense trail / binding smoke (寻香行)
    return f"""  <g>
    <rect x="94" y="145" width="12" height="40" rx="2" fill="url(#{p}-body)"/>
    <path d="M100 145c-2-18 8-28 4-45-2-12 4-22 2-35" fill="none" stroke="url(#{p}-acc)" stroke-width="2" stroke-linecap="round"/>
    <path d="M85 155c-8-15 2-28-2-42M115 155c8-15-2-28 2-42" fill="none" stroke="url(#{p}-body)" stroke-width="1.6" opacity=".7" stroke-linecap="round"/>
    <circle cx="106" cy="55" r="5" fill="url(#{p}-gold)" opacity=".7"/>
    <path d="M55 185h90" stroke="url(#{p}-gold)" stroke-width="1.5" opacity=".5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_linghaidie(p):
    # sea spirit butterfly / wave (灵海蝶)
    return f"""  <g>
    <path d="M100 115c-28-28-52-24-55-2 2 20 22 30 45 22" fill="url(#{p}-acc)" opacity=".75"/>
    <path d="M100 115c28-28 52-24 55-2-2 20-22 30-45 22" fill="url(#{p}-acc)" opacity=".75"/>
    <ellipse cx="100" cy="115" rx="8" ry="16" fill="url(#{p}-body)"/>
    <path d="M40 175c20-15 40-15 60 0 20-15 40-15 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="2" opacity=".65"/>
    <circle cx="100" cy="70" r="7" fill="none" stroke="url(#{p}-gold)" stroke-width="1.4"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yujuchong(p):
    # silkworm moth / cocoon (於菊虫)
    return f"""  <g>
    <ellipse cx="100" cy="130" rx="22" ry="32" fill="url(#{p}-body)" stroke="#2a2818" stroke-width="1.5"/>
    <path d="M85 110h30M82 125h36M85 140h30" stroke="url(#{p}-acc)" stroke-width="1.3" opacity=".8"/>
    <path d="M78 115c-20-8-34-2-40 10 16 2 30 2 40-2Z" fill="url(#{p}-acc)" opacity=".7"/>
    <path d="M122 115c20-8 34-2 40 10-16 2-30 2-40-2Z" fill="url(#{p}-acc)" opacity=".7"/>
    <path d="M92 95c-2-10-6-16-12-20M108 95c2-10 6-16 12-20" stroke="url(#{p}-gold)" stroke-width="1.3" fill="none"/>
    <circle cx="100" cy="175" r="6" fill="url(#{p}-gold)" opacity=".55"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_hainren(p):
    # ninja blade / poison mist (海忍)
    return f"""  <g>
    <path d="M65 170L135 75" stroke="url(#{p}-body)" stroke-width="3.5" stroke-linecap="round"/>
    <path d="M135 75l-6 16-14-6Z" fill="url(#{p}-gold)"/>
    <path d="M55 95c20 5 40 5 55-5M55 115c25 8 50 6 70-6M55 135c22 8 45 6 65-4" fill="none" stroke="url(#{p}-acc)" stroke-width="1.5" opacity=".65"/>
    <circle cx="85" cy="145" r="5" fill="url(#{p}-acc)" opacity=".7"/>
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
    # 空弦绮话
    ("jinnaluo", "紧那罗", "紧那罗：箜篌弦音与飞天羽，弦振入夜",
     pal("#120c18", "#1c1430", "#0c0814", "#c0a0e0", "#e0d0f0", "#a090c0", "#8060c0", "#402070", "#8060c0"),
     m_jinnaluo),
    ("lingyanji", "铃彦姬", "铃彦姬：神火铃与焰舌，铃振焰升",
     pal("#180c08", "#28140c", "#100804", "#f0a060", "#f0d0b0", "#d08050", "#d05020", "#702010", "#d05020"),
     m_lingyanji),
    ("rurineque", "入内雀", "入内雀：雀影空巢，羽落幽夜",
     pal("#0c140c", "#142018", "#080e0a", "#80c0a0", "#c0e0d0", "#70a090", "#40a070", "#184830", "#40a070"),
     m_rurineque),
    ("shouwu", "首无", "首无：飞首与妖刀，首断刀鸣",
     pal("#140c12", "#20141c", "#0c080c", "#e08090", "#f0c8d0", "#c07080", "#c04060", "#601830", "#c04060"),
     m_shouwu),
    ("gunvhongye", "鬼女红叶", "鬼女红叶：红枫与娃娃符，枫落咒起",
     pal("#180c0c", "#281414", "#100808", "#f09080", "#f0c8c0", "#d08070", "#d04030", "#701818", "#d04030"),
     m_gunvhongye),
    ("choushizhinv", "丑时之女", "丑时之女：草人咒锥，钉影缠怨",
     pal("#120e0c", "#1c1614", "#0c0a08", "#c0a090", "#e0d0c0", "#a08878", "#906050", "#403028", "#906050"),
     m_choushizhinv),
    ("yifanmumian", "一反木绵", "一反木绵：白布缠魂，绵影回生",
     pal("#0e1218", "#182030", "#0a0c12", "#a0b8e0", "#d0d8f0", "#8898c0", "#5070b0", "#203860", "#5070b0"),
     m_yifanmumian),
    ("yecha", "夜叉", "夜叉：鬼面利爪，黄泉夜行",
     pal("#120818", "#1c1030", "#0a0610", "#c080e0", "#e0c0f0", "#9070c0", "#8040c0", "#381868", "#8040c0"),
     m_yecha),
    # 振剑归川
    ("huangchuanzhizhu", "荒川之主", "荒川之主：川浪与水神冠，归流卷潮",
     pal("#081418", "#102830", "#061014", "#70c0d0", "#b0e0f0", "#60a0b0", "#3080a0", "#184050", "#3080a0"),
     m_huangchuanzhizhu),
    ("wannianzhu", "万年竹", "万年竹：竹笛剑影，叶剑清风",
     pal("#0c140c", "#142014", "#080e08", "#80c090", "#c0e8c8", "#70a880", "#40a050", "#184828", "#40a050"),
     m_wannianzhu),
    ("shuzhu", "数珠", "数珠：念珠与降魔杖，珠转禅心",
     pal("#141008", "#201810", "#0c0a06", "#e0c080", "#f0e0b8", "#c0a870", "#c09040", "#604018", "#c09040"),
     m_shuzhu),
    ("sanweihu", "三尾狐", "三尾狐：三尾焰弧，媚影红焰",
     pal("#180810", "#28101c", "#10060c", "#f080b0", "#f0c0d8", "#d07098", "#d03070", "#701840", "#d03070"),
     m_sanweihu),
    ("jicanghai", "季沧海", "季沧海：蓄力崩山斩，烈势如火",
     pal("#180c08", "#28140c", "#100804", "#f0a050", "#f0d0a8", "#d08848", "#d05818", "#702810", "#d05818"),
     m_jicanghai),
    ("wuchen", "无尘", "无尘：双环振刀，步虚剑阵",
     pal("#0c0c14", "#141420", "#080810", "#90a0e0", "#d0d4f0", "#8890c0", "#5060a0", "#202850", "#5060a0"),
     m_wuchen),
    ("ninghongye", "宁红夜", "宁红夜：凤凰羽箭，赤练无明",
     pal("#140810", "#20101c", "#0c060c", "#e070a0", "#f0c0d0", "#c07090", "#c03060", "#601038", "#c03060"),
     m_ninghongye),
    ("tayumenhutao", "土御门胡桃", "土御门胡桃：阴阳桔梗印，净天地",
     pal("#101018", "#181828", "#0a0a12", "#a0a0e0", "#d8d0f0", "#9088c0", "#6050b0", "#282060", "#6050b0"),
     m_tayumenhutao),
    # 远山遥泽
    ("baize", "白泽", "白泽：瑞兽知世，达知溯命",
     pal("#0e1410", "#18241c", "#0a0e0c", "#a0d0b0", "#d0e8d8", "#88b098", "#50a070", "#204830", "#50a070"),
     m_baize),
    ("hudiejing", "蝴蝶精", "蝴蝶精：蝶翅醉春风，战技飞花",
     pal("#140c18", "#201430", "#0c0814", "#e0a0f0", "#f0d0f8", "#c088d0", "#c050d0", "#602080", "#c050d0"),
     m_hudiejing),
    ("luoxinfu", "络新妇", "络新妇：蛛网印记，噬心罗网",
     pal("#120814", "#1c1020", "#0c060c", "#d080c0", "#e8c0e0", "#a870a0", "#a03888", "#501840", "#a03888"),
     m_luoxinfu),
    ("yitiao", "一条", "一条：勤勉修行卷，孤斗重任",
     pal("#12100c", "#1c1814", "#0c0a08", "#d0b880", "#e8d8b0", "#b0a078", "#a08040", "#504020", "#a08040"),
     m_yitiao),
    ("jialouluo", "迦楼罗", "迦楼罗：金翼化生戟，龙息炽羽",
     pal("#141008", "#20180c", "#0c0a04", "#f0d060", "#f8e8a8", "#d0b050", "#d0a020", "#705010", "#d0a020"),
     m_jialouluo),
    ("huajing", "化鲸", "化鲸：幼鲸体甲齿甲，母亲守护",
     pal("#0a1418", "#122430", "#080e12", "#80c0e0", "#c0e0f0", "#70a0c0", "#4080b0", "#183850", "#4080b0"),
     m_huajing),
    ("yinge", "影鳄", "影鳄：鬼鳄匿影，伏猎啖噬",
     pal("#0a1410", "#102018", "#080c0a", "#70b090", "#b0d8c8", "#689888", "#308060", "#184030", "#308060"),
     m_yinge),
    ("bujianyue", "不见岳", "不见岳：古山云衣，幻境峰回",
     pal("#101418", "#182028", "#0a0e12", "#a0b0c0", "#d0d8e0", "#8898a8", "#6080a0", "#283848", "#6080a0"),
     m_bujianyue),
    # 鸣雷启蛰
    ("xuzuozhinan", "须佐之男", "须佐之男：天雷万象，雷冢神威",
     pal("#100c18", "#1c1430", "#0a0810", "#d0a0f0", "#e8d0f8", "#a888d0", "#9060e0", "#402080", "#9060e0"),
     m_xuzuozhinan),
    ("liyujing", "鲤鱼精", "鲤鱼精：泡泡加护，赤鲤跃波",
     pal("#0a1418", "#122430", "#080e12", "#80d0e0", "#c0e8f0", "#70b0c0", "#30a0b0", "#184858", "#30a0b0"),
     m_liyujing),
    ("chongshi", "虫师", "虫师：虫群剧毒，簌簌虫痕",
     pal("#0c1408", "#142010", "#080c06", "#a0c060", "#d8e8b8", "#90a868", "#60a030", "#284818", "#60a030"),
     m_chongshi),
    ("xieenv", "蝎女", "蝎女：蝎尾剧毒，百蝎之毒",
     pal("#140810", "#201018", "#0c060c", "#e07080", "#f0c0c0", "#c06878", "#c02840", "#601020", "#c02840"),
     m_xieenv),
    ("xunxiangxing", "寻香行", "寻香行：燃香蚀印，缚梦明香",
     pal("#14100c", "#201814", "#0c0a08", "#e0b080", "#f0d8b8", "#c0a078", "#c08040", "#604020", "#c08040"),
     m_xunxiangxing),
    ("linghaidie", "灵海蝶", "灵海蝶：海灵结附，碧海幽波",
     pal("#0a1218", "#122030", "#080c12", "#80c0f0", "#c0dcf8", "#70a0c8", "#4080c0", "#183860", "#4080c0"),
     m_linghaidie),
    ("yujuchong", "於菊虫", "於菊虫：毒丝若虫，破茧夜噬",
     pal("#141008", "#20180c", "#0c0a04", "#e0c060", "#f0e0a8", "#c0a850", "#c09020", "#604810", "#c09020"),
     m_yujuchong),
    ("hainren", "海忍", "海忍：千刃潜影，宿怨影逝",
     pal("#0c1018", "#141c2c", "#080a12", "#8090c0", "#c8d0e8", "#8088b0", "#5060a0", "#202850", "#5060a0"),
     m_hainren),
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
