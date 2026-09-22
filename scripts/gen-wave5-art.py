#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 24 wave5-pack shikigami.

Re-runnable: writes assets/wave5/<id>.svg and <id>-awakened.svg.
Style matches assets/ember.svg / assets/wave3/* — ink-night aesthetic,
viewBox 0 0 200 260. No external resources, unique gradient IDs prefixed by unit id.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave5"

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

def m_tengji(p):
    # wisteria vine (藤姬)
    return f"""  <g>
    <path d="M100 200v-55" stroke="url(#{p}-body)" stroke-width="3" fill="none"/>
    <path d="M100 150c-18-8-34-6-46 6M100 165c18-8 34-6 46 6" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
    <g fill="url(#{p}-acc)" opacity=".9">
      <ellipse cx="54" cy="156" rx="7" ry="11"/>
      <ellipse cx="68" cy="148" rx="6" ry="10"/>
      <ellipse cx="82" cy="144" rx="5" ry="9"/>
      <ellipse cx="146" cy="171" rx="7" ry="11"/>
      <ellipse cx="132" cy="163" rx="6" ry="10"/>
      <ellipse cx="118" cy="159" rx="5" ry="9"/>
    </g>
    <circle cx="100" cy="145" r="6" fill="url(#{p}-body)"/>
  </g>
""" + dots(p, [(40, 80, 2, ".6"), (160, 86, 1.8, ".55"), (34, 150, 1.6, ".5"),
               (168, 154, 1.6, ".5"), (100, 40, 1.8, ".55"), (70, 200, 1.5, ".5"),
               (130, 200, 1.5, ".5")])


def m_huaniajuan(p):
    # painted scroll / bird (花鸟卷)
    return f"""  <g>
    <rect x="55" y="70" width="90" height="110" rx="4" fill="url(#{p}-body)" stroke="#4a2840" stroke-width="1.8"/>
    <path d="M70 140c15-25 35-35 60-30" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
    <path d="M100 100c8-12 20-16 28-10-10 2-18 8-22 16Z" fill="url(#{p}-acc)"/>
    <path d="M78 155c8-4 16-4 24 0M110 160c8-4 16-4 24 0" stroke="url(#{p}-gold)" stroke-width="1.3" fill="none"/>
  </g>
""" + dots(p, [(42, 80, 2, ".6"), (158, 82, 1.8, ".55"), (38, 160, 1.6, ".5"),
               (164, 162, 1.6, ".5"), (100, 32, 1.8, ".55"), (68, 200, 1.5, ".5"),
               (132, 200, 1.5, ".5")])


def m_yanmo(p):
    # mirror of karma + ghost flame (阎魔)
    return f"""  <g>
    <circle cx="100" cy="115" r="36" fill="url(#{p}-body)" opacity=".75" stroke="#4a2030" stroke-width="2"/>
    <ellipse cx="100" cy="115" rx="18" ry="24" fill="#1a1020"/>
    <polygon points="{star_pts(100, 115, 4, 14, 5)}" fill="url(#{p}-gold)" opacity=".85"/>
  </g>
  <g fill="url(#{p}-acc)" opacity=".8">
    <path d="M55 175c-8-18 2-30 10-28-2 10 4 18 10 22-6 4-14 8-20 6Z"/>
    <path d="M145 175c8-18-2-30-10-28 2 10-4 18-10 22 6 4 14 8 20 6Z"/>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (162, 88, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 158, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_kuileishi(p):
    # marionette cross + strings (傀儡师)
    return f"""  <g stroke="url(#{p}-gold)" stroke-width="1.4" opacity=".85">
    <path d="M60 55h80M100 55v30"/>
  </g>
  <g fill="none" stroke="url(#{p}-body)" stroke-width="1.2" opacity=".75">
    <path d="M70 55l-8 70M130 55l8 70M100 85v55M80 70l-6 55M120 70l6 55"/>
  </g>
  <g>
    <ellipse cx="100" cy="155" rx="22" ry="28" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="1.8"/>
    <circle cx="100" cy="125" r="12" fill="url(#{p}-acc)"/>
    <path d="M88 125h6M106 125h6" stroke="#1a1008" stroke-width="1.6"/>
  </g>
""" + dots(p, [(42, 90, 2, ".6"), (158, 92, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 30, 1.5, ".5"), (72, 205, 1.4, ".5"),
               (128, 205, 1.4, ".5")])


def m_baizangzhu(p):
    # fox mask / mountain (白藏主)
    return f"""  <g>
    <path d="M70 70l-12-22 28 14M130 70l12-22-28 14" fill="url(#{p}-acc)" opacity=".85"/>
    <ellipse cx="100" cy="120" rx="34" ry="30" fill="url(#{p}-body)" stroke="#4a3820" stroke-width="2"/>
    <path d="M82 115c4 6 10 6 14 0M104 115c4 6 10 6 14 0" stroke="#2a2010" stroke-width="1.5" fill="none"/>
    <ellipse cx="100" cy="132" rx="5" ry="3" fill="#2a2010"/>
    <path d="M55 185c20-18 70-18 90 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2" opacity=".6"/>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (162, 88, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 158, 1.6, ".5"), (100, 36, 1.5, ".5"), (68, 205, 1.4, ".5"),
               (132, 205, 1.4, ".5")])


def m_rulianshi(p):
    # coffin + snow blossom (入殓师)
    return f"""  <g>
    <rect x="65" y="100" width="70" height="90" rx="4" fill="url(#{p}-body)" stroke="#2a3038" stroke-width="2"/>
    <path d="M65 125h70M65 165h70" stroke="url(#{p}-gold)" stroke-width="1.2" opacity=".7"/>
    <circle cx="100" cy="145" r="8" fill="url(#{p}-acc)"/>
  </g>
  <g fill="url(#{p}-gold)" opacity=".75">
    <path d="M100 55c6 8 6 16 0 24-6-8-6-16 0-24z"/>
    <path d="M88 62c8 2 14 8 14 16-8-2-14-8-14-16z"/>
    <path d="M112 62c-8 2-14 8-14 16 8-2 14-8 14-16z"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (158, 88, 1.8, ".55"), (38, 160, 1.6, ".5"),
               (164, 162, 1.6, ".5"), (100, 32, 1.5, ".5"), (70, 210, 1.4, ".5"),
               (130, 210, 1.4, ".5")])


def m_fengli(p):
    # wind swirl + shuriken (风狸)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round">
    <path d="M55 100c20-20 50-20 70 0"/>
    <path d="M50 130c25-18 60-18 85 4"/>
    <path d="M58 160c22-12 52-12 78 4"/>
  </g>
  <g>
    <polygon points="{star_pts(100, 105, 6, 24, 4, 20)}" fill="url(#{p}-body)" stroke="#2a3830" stroke-width="1.4"/>
    <circle cx="100" cy="105" r="5" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, [(40, 80, 2, ".6"), (162, 82, 1.8, ".55"), (34, 150, 1.6, ".5"),
               (170, 155, 1.6, ".5"), (100, 30, 1.5, ".5"), (66, 205, 1.4, ".5"),
               (134, 205, 1.4, ".5")])


def m_guanhu(p):
    # bamboo tube cannon + fox paw (管狐)
    return f"""  <g>
    <rect x="85" y="70" width="30" height="100" rx="8" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="2"/>
    <path d="M85 100h30M85 130h30" stroke="url(#{p}-gold)" stroke-width="1.3"/>
    <circle cx="100" cy="70" r="10" fill="url(#{p}-acc)"/>
    <path d="M70 175c10-8 50-8 60 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
    <circle cx="78" cy="168" r="4" fill="url(#{p}-acc)" opacity=".7"/>
    <circle cx="100" cy="162" r="4" fill="url(#{p}-acc)" opacity=".7"/>
    <circle cx="122" cy="168" r="4" fill="url(#{p}-acc)" opacity=".7"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (160, 88, 1.8, ".55"), (38, 155, 1.6, ".5"),
               (164, 158, 1.6, ".5"), (100, 32, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_song(p):
    # pine branch + brush (松)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round">
    <path d="M70 190V95"/>
    <path d="M70 115c-14-8-24-6-34 2M70 145c14-8 24-6 34 2"/>
    <path d="M130 185V110"/>
    <path d="M130 130c14-8 24-6 32 2"/>
  </g>
  <g>
    <rect x="92" y="75" width="16" height="70" rx="3" fill="url(#{p}-body)" stroke="#2a3020" stroke-width="1.5"/>
    <path d="M96 75c2-10 6-14 8-18 2 4 6 8 8 18" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (160, 88, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 32, 1.5, ".5"), (72, 210, 1.4, ".5"),
               (128, 210, 1.4, ".5")])


def m_yunwaijing(p):
    # circular mirror + floating clouds (云外镜)
    return f"""  <g>
    <circle cx="100" cy="115" r="38" fill="url(#{p}-body)" stroke="#3a4060" stroke-width="2.2"/>
    <circle cx="100" cy="115" r="26" fill="#1a2030" opacity=".8"/>
    <path d="M78 100c8 4 16 4 24 0M78 125c8 4 16 4 24 0" stroke="url(#{p}-gold)" stroke-width="1.3" fill="none"/>
  </g>
  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.8" opacity=".75">
    <path d="M45 70c12-10 28-8 38 2"/>
    <path d="M120 55c14-8 30-6 40 4"/>
    <path d="M50 175c16-10 36-8 50 2"/>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (162, 88, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 158, 1.6, ".5"), (100, 30, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_liangmianfo(p):
    # dual masks wind/thunder (两面佛)
    return f"""  <g>
    <ellipse cx="72" cy="115" rx="24" ry="30" fill="url(#{p}-body)" stroke="#4a3020" stroke-width="1.8"/>
    <ellipse cx="128" cy="115" rx="24" ry="30" fill="url(#{p}-acc)" stroke="#3a2030" stroke-width="1.8"/>
    <circle cx="64" cy="108" r="3" fill="#1a1010"/><circle cx="80" cy="108" r="3" fill="#1a1010"/>
    <circle cx="120" cy="108" r="3" fill="#1a1010"/><circle cx="136" cy="108" r="3" fill="#1a1010"/>
    <path d="M64 128c6 5 12 5 18 0M120 128c6 5 12 5 18 0" stroke="#2a1810" stroke-width="1.3" fill="none"/>
    <path d="M100 70l-6 20h10l-8 22" fill="none" stroke="url(#{p}-gold)" stroke-width="2"/>
  </g>
""" + dots(p, [(40, 80, 2, ".6"), (162, 82, 1.8, ".55"), (36, 160, 1.6, ".5"),
               (168, 162, 1.6, ".5"), (100, 32, 1.5, ".5"), (68, 205, 1.4, ".5"),
               (132, 205, 1.4, ".5")])


def m_heitongzi(p):
    # black twin blade (黑童子)
    return f"""  <g>
    <path d="M100 55v100" stroke="url(#{p}-body)" stroke-width="4"/>
    <path d="M85 70h30" stroke="url(#{p}-gold)" stroke-width="2"/>
    <path d="M100 55c-8-8-8-16 0-22 8 6 8 14 0 22z" fill="url(#{p}-acc)"/>
  </g>
  <g fill="url(#{p}-acc)" opacity=".55">
    <circle cx="70" cy="140" r="14"/>
    <circle cx="130" cy="155" r="10"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (160, 88, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 32, 1.5, ".5"), (72, 205, 1.4, ".5"),
               (128, 205, 1.4, ".5")])


def m_baitongzi(p):
    # white twin ribbon (白童子)
    return f"""  <g>
    <path d="M100 55v95" stroke="url(#{p}-body)" stroke-width="3"/>
    <path d="M100 80c-20 8-30 22-28 40M100 100c20 8 30 22 28 40" fill="none" stroke="url(#{p}-acc)" stroke-width="3"/>
    <circle cx="100" cy="55" r="8" fill="url(#{p}-gold)"/>
    <path d="M72 180c18-12 38-12 56 0" fill="none" stroke="url(#{p}-gold)" stroke-width="1.5" opacity=".7"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (160, 88, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 30, 1.5, ".5"), (70, 210, 1.4, ".5"),
               (130, 210, 1.4, ".5")])


def m_xiazhongshaonv(p):
    # ornate box + dice (匣中少女)
    return f"""  <g>
    <rect x="60" y="95" width="80" height="70" rx="6" fill="url(#{p}-body)" stroke="#3a2040" stroke-width="2"/>
    <path d="M60 115h80" stroke="url(#{p}-gold)" stroke-width="1.4"/>
    <rect x="88" y="125" width="24" height="24" rx="3" fill="url(#{p}-acc)" stroke="#2a1030" stroke-width="1.2"/>
    <circle cx="96" cy="133" r="2.5" fill="#1a1020"/><circle cx="104" cy="141" r="2.5" fill="#1a1020"/>
  </g>
  <g fill="url(#{p}-gold)" opacity=".8">
    <polygon points="{star_pts(100, 70, 4, 12, 5)}"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (160, 88, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 32, 1.5, ".5"), (70, 205, 1.4, ".5"),
               (130, 205, 1.4, ".5")])


def m_yi(p):
    # go board + stones (弈)
    return f"""  <g>
    <rect x="55" y="85" width="90" height="90" rx="3" fill="url(#{p}-body)" stroke="#2a3040" stroke-width="1.8"/>
    <g stroke="#1a2030" stroke-width="1">
      <path d="M55 115h90M55 145h90M85 85v90M115 85v90"/>
    </g>
    <circle cx="85" cy="115" r="6" fill="#1a1a22"/>
    <circle cx="115" cy="145" r="6" fill="#e8e0d0"/>
    <circle cx="115" cy="115" r="6" fill="#1a1a22"/>
    <circle cx="85" cy="145" r="6" fill="#e8e0d0"/>
  </g>
""" + dots(p, [(42, 80, 2, ".6"), (160, 82, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 32, 1.5, ".5"), (72, 205, 1.4, ".5"),
               (128, 205, 1.4, ".5")])


def m_xiaosongwan(p):
    # pinecone + squirrel ears (小松丸)
    return f"""  <g>
    <path d="M78 70l-8-18 16 10M122 70l8-18-16 10" fill="url(#{p}-acc)"/>
    <ellipse cx="100" cy="125" rx="32" ry="36" fill="url(#{p}-body)" stroke="#4a3020" stroke-width="2"/>
    <path d="M80 115h8M112 115h8" stroke="#2a1808" stroke-width="2"/>
    <ellipse cx="100" cy="135" rx="6" ry="4" fill="#2a1808"/>
    <g fill="url(#{p}-acc)" opacity=".75">
      <ellipse cx="70" cy="175" rx="8" ry="12"/>
      <ellipse cx="88" cy="180" rx="7" ry="11"/>
      <ellipse cx="112" cy="180" rx="7" ry="11"/>
      <ellipse cx="130" cy="175" rx="8" ry="12"/>
    </g>
  </g>
""" + dots(p, [(40, 85, 2, ".6"), (162, 88, 1.8, ".55"), (36, 155, 1.6, ".5"),
               (168, 158, 1.6, ".5"), (100, 32, 1.5, ".5"), (70, 210, 1.4, ".5"),
               (130, 210, 1.4, ".5")])


def m_wuwu(p):
    # cat bowl + paw (五丸)
    return f"""  <g>
    <path d="M65 140h70l-8 35H73Z" fill="url(#{p}-body)" stroke="#4a3020" stroke-width="2"/>
    <ellipse cx="100" cy="140" rx="35" ry="10" fill="url(#{p}-acc)" opacity=".75"/>
    <circle cx="100" cy="95" r="16" fill="url(#{p}-acc)"/>
    <path d="M88 88l-6-12 12 6M112 88l6-12-12 6" fill="url(#{p}-acc)"/>
    <circle cx="94" cy="94" r="2" fill="#1a1010"/><circle cx="106" cy="94" r="2" fill="#1a1010"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (160, 88, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 32, 1.5, ".5"), (72, 210, 1.4, ".5"),
               (128, 210, 1.4, ".5")])


def m_qianji(p):
    # pearl spear / tide (千姬)
    return f"""  <g>
    <path d="M100 50v120" stroke="url(#{p}-body)" stroke-width="3.5"/>
    <path d="M100 50c-8 10-8 22 0 30 8-8 8-20 0-30z" fill="url(#{p}-gold)"/>
    <circle cx="100" cy="95" r="8" fill="url(#{p}-acc)"/>
    <path d="M55 175c15-12 35-12 45 0 10-12 30-12 45 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2.2"/>
    <path d="M60 190c14-8 32-8 40 0 8-8 26-8 40 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.5" opacity=".6"/>
  </g>
""" + dots(p, [(42, 85, 2, ".6"), (160, 88, 1.8, ".55"), (38, 160, 1.6, ".5"),
               (164, 162, 1.6, ".5"), (100, 30, 1.5, ".5"), (70, 210, 1.4, ".5"),
               (130, 210, 1.4, ".5")])


def m_shiling(p):
    # cooking pot + flame (食灵)
    return f"""  <g>
    <path d="M65 125h70v35c0 12-16 22-35 22s-35-10-35-22Z" fill="url(#{p}-body)" stroke="#4a2820" stroke-width="2"/>
    <ellipse cx="100" cy="125" rx="35" ry="10" fill="url(#{p}-acc)" opacity=".7"/>
    <path d="M85 85c-4-12 4-22 12-28 2 10 8 16 8 28-4-4-8-4-10 2-4-4-8-2-10-2z" fill="url(#{p}-gold)"/>
    <path d="M55 135h-10M155 135h10" stroke="url(#{p}-body)" stroke-width="3"/>
  </g>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 36, 1.5, ".5"), (72, 210, 1.4, ".5"),
               (128, 210, 1.4, ".5")])


def m_maozhanggui(p):
    # shop banner + cat coin (猫掌柜)
    return f"""  <g>
    <path d="M60 65h80v12H60Z" fill="url(#{p}-gold)"/>
    <path d="M70 77v55M130 77v55" stroke="url(#{p}-body)" stroke-width="2.5"/>
    <path d="M70 90h60v50H70Z" fill="url(#{p}-body)" stroke="#4a3020" stroke-width="1.5" opacity=".85"/>
    <circle cx="100" cy="160" r="18" fill="url(#{p}-acc)" stroke="#4a3020" stroke-width="1.6"/>
    <path d="M88 155c4 4 8 4 12 0M88 165c4 4 8 4 12 0" stroke="#2a1808" stroke-width="1.3" fill="none"/>
  </g>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 210, 1.4, ".5"),
               (130, 210, 1.4, ".5")])


def m_xingxiongtongzi(p):
    # sake bowl + horn (星熊童子)
    return f"""  <g>
    <path d="M70 130h60l-8 35H78Z" fill="url(#{p}-body)" stroke="#4a2020" stroke-width="2"/>
    <ellipse cx="100" cy="130" rx="30" ry="9" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M85 80c-10-18-4-32 8-40 2 14 2 28-2 40M115 80c10-18 4-32-8-40-2 14-2 28 2 40" fill="url(#{p}-acc)" opacity=".85"/>
    <circle cx="100" cy="100" r="12" fill="url(#{p}-body)" stroke="#3a1818" stroke-width="1.5"/>
    <path d="M94 98h5M106 98h5" stroke="#1a0808" stroke-width="1.5"/>
  </g>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 36, 1.5, ".5"), (72, 210, 1.4, ".5"),
               (128, 210, 1.4, ".5")])


def m_yixigong(p):
    # sugar figure / candy (饴细工)
    return f"""  <g>
    <ellipse cx="100" cy="145" rx="28" ry="34" fill="url(#{p}-body)" stroke="#4a3820" stroke-width="2"/>
    <circle cx="100" cy="105" r="16" fill="url(#{p}-acc)"/>
    <circle cx="94" cy="103" r="2.5" fill="#2a1808"/><circle cx="106" cy="103" r="2.5" fill="#2a1808"/>
    <path d="M94 114c4 4 8 4 12 0" stroke="#2a1808" stroke-width="1.4" fill="none"/>
    <path d="M72 80c8-16 20-22 28-18-10 4-18 12-22 22Z" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 210, 1.4, ".5"),
               (130, 210, 1.4, ".5")])


def m_limao(p):
    # tanuki belly + gourd (狸猫)
    return f"""  <g>
    <ellipse cx="100" cy="140" rx="34" ry="38" fill="url(#{p}-body)" stroke="#3a2818" stroke-width="2"/>
    <circle cx="88" cy="130" r="4" fill="#1a1008"/><circle cx="112" cy="130" r="4" fill="#1a1008"/>
    <ellipse cx="100" cy="148" rx="8" ry="5" fill="#2a1808"/>
    <path d="M78 78c-8-14-4-26 6-32 0 12 2 22 6 32M122 78c8-14 4-26-6-32 0 12-2 22-6 32" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M145 100c8 0 12 8 10 18s-10 14-16 10 0-28 6-28z" fill="url(#{p}-gold)" opacity=".75"/>
  </g>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 36, 1.5, ".5"), (72, 210, 1.4, ".5"),
               (128, 210, 1.4, ".5")])


def m_tuwan(p):
    # rabbit ears + carrot/ingredient (兔丸)
    return f"""  <g>
    <path d="M82 85c-8-28-6-48 2-55 8 12 12 32 10 55M118 85c8-28 6-48-2-55-8 12-12 32-10 55" fill="url(#{p}-acc)" opacity=".85"/>
    <ellipse cx="100" cy="135" rx="30" ry="32" fill="url(#{p}-body)" stroke="#4a3020" stroke-width="2"/>
    <circle cx="90" cy="128" r="3.5" fill="#1a1008"/><circle cx="110" cy="128" r="3.5" fill="#1a1008"/>
    <ellipse cx="100" cy="142" rx="5" ry="3.5" fill="#2a1808"/>
    <path d="M130 165c12 4 18 14 14 24-10-2-18-12-14-24z" fill="url(#{p}-gold)" opacity=".75"/>
  </g>
""" + dots(p, [(42, 90, 2, ".6"), (160, 92, 1.8, ".55"), (38, 165, 1.6, ".5"),
               (164, 168, 1.6, ".5"), (100, 36, 1.5, ".5"), (70, 210, 1.4, ".5"),
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
    ("tengji", "藤姬", "藤姬：紫藤垂落如瀑，花串层叠",
     pal("#140c1c", "#201430", "#0c0814", "#c090e0", "#e8d0f8", "#a080c0", "#8050c0", "#302060", "#8050c0"),
     m_tengji),
    ("huaniajuan", "花鸟卷", "花鸟卷：丹青画卷与飞鸟，笔意流转",
     pal("#180c14", "#28141c", "#10080c", "#e0a0c0", "#f0d0e0", "#c090a8", "#c06088", "#602040", "#c06088"),
     m_huaniajuan),
    ("yanmo", "阎魔", "阎魔：业镜与幽魂焰，冥府威仪",
     pal("#140818", "#241028", "#0c0610", "#c080d0", "#e0c0e8", "#9060a8", "#8030a0", "#301050", "#8030a0"),
     m_yanmo),
    ("kuileishi", "傀儡师", "傀儡师：悬丝傀儡与操偶十字，丝线垂落",
     pal("#141008", "#201810", "#0c0a06", "#c0a070", "#e0d0a8", "#a08860", "#a07030", "#503010", "#a07030"),
     m_kuileishi),
    ("baizangzhu", "白藏主", "白藏主：狐面与梦山轮廓，山影如卧",
     pal("#141008", "#201810", "#0c0a06", "#e0c070", "#f0e0b0", "#c0a060", "#c09030", "#604010", "#c09030"),
     m_baizangzhu),
    ("rulianshi", "入殓师", "入殓师：棺木与落雪花，静穆肃然",
     pal("#0e1218", "#182030", "#0a0c12", "#90a8c0", "#d0dce8", "#8898b0", "#607890", "#283848", "#607890"),
     m_rulianshi),
    ("fengli", "风狸", "风狸：旋风与手里剑，残影如电",
     pal("#0c1412", "#14201c", "#080c0a", "#80c8a8", "#d0e8d8", "#88b098", "#40a070", "#184830", "#40a070"),
     m_fengli),
    ("guanhu", "管狐", "管狐：竹管火器与狐爪，印记生焰",
     pal("#141008", "#201810", "#0c0a06", "#d0a060", "#f0e0b0", "#b08860", "#b07030", "#503010", "#b07030"),
     m_guanhu),
    ("song", "松", "松：松枝与词章笔，针叶对生",
     pal("#0c140c", "#142014", "#0a0e08", "#80b070", "#d0e0c0", "#88a868", "#50a040", "#204818", "#50a040"),
     m_song),
    ("yunwaijing", "云外镜", "云外镜：圆镜与浮云，镜心映月",
     pal("#0c101c", "#141c30", "#080a14", "#90a0e0", "#d0d8f8", "#8890c0", "#5070c0", "#203870", "#5070c0"),
     m_yunwaijing),
    ("liangmianfo", "两面佛", "两面佛：风雷双面，左风右雷",
     pal("#140c08", "#241410", "#0c0806", "#d09070", "#f0d0b0", "#b08070", "#c05030", "#602010", "#c05030"),
     m_liangmianfo),
    ("heitongzi", "黑童子", "黑童子：墨刃与暗影，双影并立",
     pal("#0c0a14", "#141020", "#080810", "#8080b0", "#c8c8e0", "#8080a0", "#505080", "#202040", "#505080"),
     m_heitongzi),
    ("baitongzi", "白童子", "白童子：白绫与柔光，羁绊如带",
     pal("#141210", "#201c18", "#0c0a08", "#e0d0c0", "#f8f0e8", "#d0c0b0", "#c0a090", "#605040", "#c0a090"),
     m_baitongzi),
    ("xiazhongshaonv", "匣中少女", "匣中少女：藏珍之匣与骰子，光华内蕴",
     pal("#140c1c", "#201430", "#0c0814", "#c080e0", "#e8d0f8", "#a080c0", "#9040c0", "#381860", "#9040c0"),
     m_xiazhongshaonv),
    ("yi", "弈", "弈：星罗棋盘与黑白子，落子如星",
     pal("#0c0e16", "#141824", "#080a10", "#90a0c0", "#d0d8e8", "#8890a8", "#506080", "#202840", "#506080"),
     m_yi),
    ("xiaosongwan", "小松丸", "小松丸：松果与圆耳，果鳞层叠",
     pal("#141008", "#201810", "#0c0a06", "#e0b070", "#f0e0b8", "#c0a068", "#c08030", "#604010", "#c08030"),
     m_xiaosongwan),
    ("wuwu", "五丸", "五丸：猫碗与肉垫，料理生香",
     pal("#180e08", "#281810", "#100a06", "#f0b070", "#f8e0c0", "#e0a070", "#e08030", "#704010", "#e08030"),
     m_wuwu),
    ("qianji", "千姬", "千姬：海原贝戟与潮纹，珠光流转",
     pal("#081018", "#102030", "#060a12", "#70b0e0", "#c0e0f8", "#70a0c0", "#3080b0", "#183858", "#3080b0"),
     m_qianji),
    ("shiling", "食灵", "食灵：汤锅与灶火，热气腾腾",
     pal("#180c08", "#281410", "#100806", "#f0a070", "#f8d0b0", "#d08868", "#d05030", "#602010", "#d05030"),
     m_shiling),
    ("maozhanggui", "猫掌柜", "猫掌柜：店招与猫钱，招幌垂落",
     pal("#181008", "#281c10", "#100a06", "#f0c080", "#f8e8c0", "#d0b080", "#d09040", "#604010", "#d09040"),
     m_maozhanggui),
    ("xingxiongtongzi", "星熊童子", "星熊童子：酒碗与鬼角，酒波微漾",
     pal("#180c0c", "#281414", "#100808", "#e08080", "#f0c0c0", "#c07878", "#c04040", "#601818", "#c04040"),
     m_xingxiongtongzi),
    ("yixigong", "饴细工", "饴细工：糖人小像与糖丝，晶莹透亮",
     pal("#181408", "#282010", "#100e06", "#f0d080", "#f8f0c0", "#e0c880", "#e0a030", "#705010", "#e0a030"),
     m_yixigong),
    ("limao", "狸猫", "狸猫：狸腹与酒葫芦，醉眼朦胧",
     pal("#140c08", "#201410", "#0c0806", "#d09060", "#f0d0b0", "#b08868", "#b05030", "#502010", "#b05030"),
     m_limao),
    ("tuwan", "兔丸", "兔丸：长耳与食材，软萌可掬",
     pal("#14100c", "#201814", "#0c0a08", "#e0b090", "#f8e8d8", "#d0b098", "#d08060", "#604030", "#d08060"),
     m_tuwan),
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
