#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 27 wave9-pack shikigami.

Re-runnable: writes assets/wave9/<id>.svg and <id>-awakened.svg.
Style matches assets/wave6/* — ink-night aesthetic, viewBox 0 0 200 260.
No external resources, unique gradient IDs prefixed by unit id. No NetEase art.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave9"

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


def pal(bg1, bg2, bg3, halo, body1, body2, acc1, acc2, frame,
        awk_bloom="rgba(255, 233, 178, 0.35)", awk_core="#ff8a3d"):
    return {
        "bg1": bg1, "bg2": bg2, "bg3": bg3, "halo": halo,
        "body1": body1, "body2": body2, "acc1": acc1, "acc2": acc2,
        "frame": frame, "awk_bloom": awk_bloom, "awk_core": awk_core,
    }


# ---------- motif builders (pure original SVG shapes) ----------

def m_yatiangou(p):
    # crow tengu mask + maple leaf (鸦天狗·秋叶)
    return f"""  <g>
    <path d="M72 120c8-36 48-36 56 0 6 28-8 52-28 52s-34-24-28-52Z" fill="url(#{p}-body)" stroke="#2a2418" stroke-width="1.8"/>
    <path d="M80 118l-10-22M100 112v-24M120 118l10-22" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round"/>
    <circle cx="88" cy="128" r="3.5" fill="url(#{p}-gold)"/><circle cx="112" cy="128" r="3.5" fill="url(#{p}-gold)"/>
    <path d="M100 175c-16-14-30-16-42-10 10 12 24 20 42 24 18-4 32-12 42-24-12-6-26-4-42 10Z" fill="url(#{p}-acc)" opacity=".85"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_shuweng(p):
    # scroll + brush (书翁·志行)
    return f"""  <g>
    <rect x="68" y="90" width="64" height="70" rx="4" fill="url(#{p}-body)" stroke="#1a2838" stroke-width="1.8"/>
    <path d="M78 105h44M78 120h44M78 135h30" stroke="#1a2838" stroke-width="1.3"/>
    <path d="M140 70v70" stroke="url(#{p}-gold)" stroke-width="3" stroke-linecap="round"/>
    <path d="M140 70c-6 4-6 12 0 16 6-4 6-12 0-16Z" fill="url(#{p}-acc)"/>
    <polygon points="{star_pts(70, 70, 5, 13, 5)}" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_huojinshen(p):
    # cursed veil / blossom seal (祸津神)
    return f"""  <g>
    <path d="M60 150c10-40 25-70 40-70s30 30 40 70" fill="url(#{p}-body)" opacity=".55" stroke="#3a1820" stroke-width="1.6"/>
    <path d="M75 100c-10 16-12 40-4 58M125 100c10 16 12 40 4 58" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
    <circle cx="100" cy="108" r="14" fill="url(#{p}-gold)" opacity=".75"/>
    <path d="M100 88c-4 8-4 14 0 20 4-6 4-12 0-20Z" fill="url(#{p}-acc)"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_sibing(p):
    # tray + dumpling (四饼)
    return f"""  <g>
    <ellipse cx="100" cy="150" rx="48" ry="14" fill="url(#{p}-body)" stroke="#3a2810" stroke-width="1.8"/>
    <ellipse cx="100" cy="138" rx="36" ry="16" fill="url(#{p}-acc)" opacity=".85"/>
    <circle cx="88" cy="128" r="10" fill="url(#{p}-gold)" opacity=".8"/>
    <circle cx="112" cy="128" r="10" fill="url(#{p}-gold)" opacity=".8"/>
    <circle cx="100" cy="148" r="10" fill="url(#{p}-gold)" opacity=".65"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_dayueling(p):
    # magatama jewel + waves (大岳丸·渝心)
    return f"""  <g>
    <path d="M100 78c22 0 36 18 36 38 0 28-22 48-36 48s-36-20-36-48c0-20 14-38 36-38Z" fill="url(#{p}-body)" stroke="#102838" stroke-width="1.8"/>
    <path d="M100 92c12 0 20 10 20 22 0 16-12 28-20 28s-20-12-20-28c0-12 8-22 20-22Z" fill="url(#{p}-gold)" opacity=".75"/>
    <path d="M55 175c15-10 30-10 45 0s30 10 45 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2.2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_chili(p):
    # coiled dragon breath (螭璃)
    return f"""  <g>
    <path d="M70 160c0-30 14-55 30-55s30 25 30 55" fill="none" stroke="url(#{p}-body)" stroke-width="10" stroke-linecap="round" opacity=".7"/>
    <path d="M78 150c8-24 16-36 22-36s14 12 22 36" fill="none" stroke="url(#{p}-acc)" stroke-width="3"/>
    <circle cx="100" cy="96" r="12" fill="url(#{p}-gold)" opacity=".8"/>
    <path d="M92 88c-4-10 0-18 8-22 2 10 0 18-8 22ZM108 88c4-10 0-18-8-22-2 10 0 18 8 22Z" fill="url(#{p}-acc)"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_jieshen(p):
    # red string + knot (缘结神·遂愿)
    return f"""  <g>
    <path d="M50 140c20-30 40-30 50-10 10-20 30-20 50 10" fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
    <circle cx="100" cy="130" r="16" fill="none" stroke="url(#{p}-gold)" stroke-width="3"/>
    <circle cx="100" cy="130" r="6" fill="url(#{p}-gold)"/>
    <path d="M70 90c10-16 50-16 60 0" fill="none" stroke="url(#{p}-body)" stroke-width="2.5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_tieshu(p):
    # iron rat coin (铁鼠·豪贾)
    return f"""  <g>
    <circle cx="100" cy="125" r="36" fill="url(#{p}-body)" stroke="#3a2808" stroke-width="1.8"/>
    <rect x="90" y="115" width="20" height="20" rx="2" fill="url(#{p}-gold)"/>
    <circle cx="82" cy="108" r="4" fill="#2a2008"/><circle cx="118" cy="108" r="4" fill="#2a2008"/>
    <path d="M55 95c10-20 30-28 45-28" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yijin(p):
    # golden feather (以津真天·千寻)
    return f"""  <g>
    <path d="M100 70c18 30 22 60 8 95-20-10-34-40-30-78 8 6 14 8 22-17Z" fill="url(#{p}-body)" stroke="#183040" stroke-width="1.5"/>
    <path d="M108 95c8 18 8 40 0 58" stroke="url(#{p}-gold)" stroke-width="2" fill="none"/>
    <path d="M70 120c-12-8-22-6-30 4 12 4 22 8 30 12M130 120c12-8 22-6 30 4-12 4-22 8-30 12" fill="url(#{p}-acc)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_baizang(p):
    # white fox flame (白藏主·砺心)
    return f"""  <g>
    <path d="M100 85c20 8 34 28 34 50 0 20-14 36-34 36s-34-16-34-36c0-22 14-42 34-50Z" fill="url(#{p}-body)" stroke="#203018" stroke-width="1.8"/>
    <path d="M78 95l-8-28 18 16M122 95l8-28-18 16" fill="url(#{p}-acc)"/>
    <circle cx="88" cy="128" r="3" fill="#102008"/><circle cx="112" cy="128" r="3" fill="#102008"/>
    <path d="M100 70c-6 10-2 18 0 24 2-6 6-14 0-24Z" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_guijinyang(p):
    # gold sheep horn + notice slip (鬼金羊)
    return f"""  <g>
    <path d="M78 150c0-30 10-55 22-55s22 25 22 55Z" fill="url(#{p}-body)" stroke="#281838" stroke-width="1.8"/>
    <path d="M78 110c-14-8-18-24-8-34 4 14 10 22 18 26M122 110c14-8 18-24 8-34-4 14-10 22-18 26" fill="url(#{p}-acc)"/>
    <rect x="86" y="155" width="28" height="36" rx="2" fill="url(#{p}-gold)" opacity=".85" transform="rotate(-8 100 170)"/>
    <path d="M92 168h16M92 178h12" stroke="#3a2810" stroke-width="1.2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_longche(p):
    # ghost cart wheel + toad (胧车)
    return f"""  <g>
    <circle cx="100" cy="130" r="40" fill="none" stroke="url(#{p}-body)" stroke-width="6"/>
    <circle cx="100" cy="130" r="10" fill="url(#{p}-gold)"/>
    <path d="M100 90v20M100 150v20M60 130h20M120 130h20" stroke="url(#{p}-acc)" stroke-width="2.5"/>
    <ellipse cx="100" cy="175" rx="18" ry="10" fill="url(#{p}-acc)" opacity=".75"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_pinfashen(p):
    # poverty mask + broken coin (贫乏神)
    return f"""  <g>
    <path d="M72 115c8-28 48-28 56 0 4 22-8 45-28 45s-32-23-28-45Z" fill="url(#{p}-body)" stroke="#2a2418" stroke-width="1.8"/>
    <path d="M82 118h12M106 118h12" stroke="#2a2418" stroke-width="2"/>
    <path d="M88 140c6 6 18 6 24 0" stroke="#2a2418" stroke-width="1.5" fill="none"/>
    <path d="M55 165l18-8 8 14-18 8Z" fill="url(#{p}-acc)" opacity=".8"/>
    <path d="M145 165l-18-8-8 14 18 8Z" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_longjue(p):
    # dragon pearl + qian/kun arcs (龙珏)
    return f"""  <g>
    <circle cx="100" cy="125" r="28" fill="url(#{p}-body)" stroke="#103040" stroke-width="1.8"/>
    <circle cx="100" cy="125" r="12" fill="url(#{p}-gold)" opacity=".85"/>
    <path d="M60 100c20-25 60-25 80 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2.5"/>
    <path d="M60 150c20 25 60 25 80 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2.5"/>
    <polygon points="{star_pts(100, 70, 5, 14, 5)}" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_fengyang(p):
    # twin swords sun/moon (封阳君)
    return f"""  <g>
    <path d="M75 160l20-70 8 4-14 72Z" fill="url(#{p}-body)" stroke="#3a2808" stroke-width="1.4"/>
    <path d="M125 160l-20-70-8 4 14 72Z" fill="url(#{p}-acc)" stroke="#3a2808" stroke-width="1.4"/>
    <circle cx="100" cy="85" r="16" fill="url(#{p}-gold)" opacity=".8"/>
    <path d="M100 60v-10M100 120v-8" stroke="url(#{p}-gold)" stroke-width="2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_jintian(p):
    # nine-tail fox fire (烬天玉藻前)
    return f"""  <g>
    <path d="M100 155c-8-20-8-40 0-58 8 18 8 38 0 58Z" fill="url(#{p}-body)"/>
    <path d="M85 155c-12-16-18-36-14-54 12 12 18 30 18 50M115 155c12-16 18-36 14-54-12 12-18 30-18 50" fill="url(#{p}-acc)" opacity=".85"/>
    <path d="M70 155c-14-12-24-30-24-48 16 10 26 26 30 44M130 155c14-12 24-30 24-48-16 10-26 26-30 44" fill="url(#{p}-acc)" opacity=".65"/>
    <polygon points="{star_pts(100, 70, 6, 16, 5)}" fill="url(#{p}-gold)" opacity=".85"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_chanxin(p):
    # twin mirrors (禅心云外镜)
    return f"""  <g>
    <circle cx="82" cy="125" r="28" fill="url(#{p}-body)" stroke="#202838" stroke-width="1.8"/>
    <circle cx="118" cy="125" r="28" fill="url(#{p}-acc)" opacity=".75" stroke="#202838" stroke-width="1.8"/>
    <circle cx="82" cy="125" r="12" fill="url(#{p}-gold)" opacity=".7"/>
    <path d="M118 110v30M103 125h30" stroke="#202838" stroke-width="1.5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_zhaocaimao(p):
    # maneki cat paw + coin (招财猫)
    return f"""  <g>
    <ellipse cx="100" cy="140" rx="34" ry="30" fill="url(#{p}-body)" stroke="#3a2808" stroke-width="1.8"/>
    <circle cx="100" cy="100" r="22" fill="url(#{p}-body)" stroke="#3a2808" stroke-width="1.8"/>
    <path d="M85 88l-6-16 14 8M115 88l6-16-14 8" fill="url(#{p}-acc)"/>
    <circle cx="92" cy="100" r="2.5" fill="#3a2808"/><circle cx="108" cy="100" r="2.5" fill="#3a2808"/>
    <circle cx="130" cy="120" r="14" fill="url(#{p}-gold)" opacity=".85"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_maozhang(p):
    # shop curtain + blueprint (猫掌柜·焕宴)
    return f"""  <g>
    <path d="M60 85h80v20H60Z" fill="url(#{p}-acc)" opacity=".85"/>
    <path d="M68 105v20M84 105v24M100 105v20M116 105v24M132 105v20" stroke="url(#{p}-acc)" stroke-width="3"/>
    <rect x="75" y="135" width="50" height="40" rx="3" fill="url(#{p}-body)" stroke="#3a2018" stroke-width="1.5"/>
    <path d="M85 150h30M85 162h20" stroke="#3a2018" stroke-width="1.2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_geluoduo(p):
    # hanafuda card + moon (歌留多)
    return f"""  <g>
    <rect x="72" y="85" width="56" height="80" rx="4" fill="url(#{p}-body)" stroke="#3a2028" stroke-width="1.8"/>
    <circle cx="100" cy="125" r="18" fill="url(#{p}-gold)" opacity=".8"/>
    <path d="M85 105c5-8 25-8 30 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
    <path d="M88 155c8 6 16 6 24 0" stroke="#3a2028" stroke-width="1.4" fill="none"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_kaguya(p):
    # bamboo + moon rabbit (因幡辉夜姬)
    return f"""  <g>
    <rect x="88" y="75" width="10" height="100" rx="3" fill="url(#{p}-body)" stroke="#282038" stroke-width="1.2"/>
    <path d="M88 100h10M88 130h10" stroke="#282038" stroke-width="1.2"/>
    <path d="M108 150c0-20 12-35 24-35s18 12 18 28-10 28-22 28-20-8-20-21Z" fill="url(#{p}-acc)" opacity=".8"/>
    <circle cx="145" cy="85" r="14" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_daixiao(p):
    # night crane + sword ink (待宵姑获鸟)
    return f"""  <g>
    <path d="M70 150c20-40 40-55 55-50-5 20-2 45 10 65-25 5-50-2-65-15Z" fill="url(#{p}-body)" stroke="#182838" stroke-width="1.6"/>
    <path d="M125 100l25-25" stroke="url(#{p}-gold)" stroke-width="3" stroke-linecap="round"/>
    <circle cx="125" cy="100" r="5" fill="url(#{p}-acc)"/>
    <path d="M60 165c20 8 50 10 75 0" stroke="url(#{p}-body)" stroke-width="2" fill="none" opacity=".6"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_shanfeng(p):
    # mountain hawk + wind slash (初翎山风)
    return f"""  <g>
    <path d="M55 160l45-70 45 70Z" fill="url(#{p}-body)" opacity=".7" stroke="#1a3020" stroke-width="1.6"/>
    <path d="M75 130c20-25 50-25 70 0" fill="none" stroke="url(#{p}-acc)" stroke-width="3"/>
    <path d="M60 100c25-15 55-15 80 0M70 85c20-10 40-10 60 0" fill="none" stroke="url(#{p}-gold)" stroke-width="2" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_fenghuang(p):
    # phoenix flame feather (凤凰火·净羽)
    return f"""  <g>
    <path d="M100 165c-20-25-30-55-22-85 8 18 14 28 22 35 8-7 14-17 22-35 8 30-2 60-22 85Z" fill="url(#{p}-body)" stroke="#401808" stroke-width="1.5"/>
    <path d="M100 120c-8-12-10-28-6-42 4 10 6 18 6 28 0-10 2-18 6-28 4 14 2 30-6 42Z" fill="url(#{p}-gold)" opacity=".8"/>
    <path d="M55 145c15-5 30-5 40 2M145 145c-15-5-30-5-40 2" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_xixueji(p):
    # blood moon drop (吸血姬·曦忆)
    return f"""  <g>
    <circle cx="100" cy="125" r="34" fill="url(#{p}-body)" stroke="#3a1020" stroke-width="1.8"/>
    <path d="M100 95c10 16 16 28 16 40 0 12-8 20-16 20s-16-8-16-20c0-12 6-24 16-40Z" fill="url(#{p}-acc)" opacity=".85"/>
    <circle cx="100" cy="125" r="8" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yinghua(p):
    # glass cherry blossom (樱花妖·璃景)
    return f"""  <g>
    <g fill="url(#{p}-acc)" opacity=".9">
      <path d="M100 125c-8-22-2-38 8-48 2 16 0 34-8 48Z"/>
      <path d="M100 125c8-22 24-28 38-24-12 12-24 20-38 24Z"/>
      <path d="M100 125c22-8 34 2 40 14-16 0-30-4-40-14Z"/>
      <path d="M100 125c8 22-2 38-14 44 0-16 4-32 14-44Z"/>
      <path d="M100 125c-22 8-34-2-38-14 14 2 28 6 38 14Z"/>
    </g>
    <circle cx="100" cy="125" r="8" fill="url(#{p}-gold)" opacity=".85"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_shenqilou(p):
    # mirage tower + knowledge seal (蜃气楼)
    return f"""  <g>
    <path d="M75 170V100l25-25 25 25v70Z" fill="url(#{p}-body)" opacity=".65" stroke="#182830" stroke-width="1.8"/>
    <path d="M85 120h30M85 140h30M85 155h18" stroke="#182830" stroke-width="1.3"/>
    <path d="M60 90c25-20 55-20 80 0" fill="none" stroke="url(#{p}-acc)" stroke-width="2.5" opacity=".8"/>
    <polygon points="{star_pts(100, 70, 5, 14, 4)}" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


UNITS = [
    # 龙渊秘境
    ("yatiangou-qiuye", "鸦天狗·秋叶", "鸦天狗·秋叶：天狗面与秋枫，神通授剑",
     pal("#18140c", "#282014", "#100e08", "#d0c090", "#f0e8d0", "#c0b080", "#a08040", "#503810", "#a08040"),
     m_yatiangou),
    ("shuweng-zhixing", "书翁·志行", "书翁·志行：书卷游记与笔墨，志行无量",
     pal("#0c1218", "#142030", "#080c12", "#a0b8d0", "#d0e0f0", "#8098b0", "#5080b0", "#203850", "#5080b0"),
     m_shuweng),
    ("huojinshen", "祸津神", "祸津神：咒纱与祸花，灾厄缠心",
     pal("#180c10", "#281418", "#10080c", "#c08090", "#f0c0c8", "#b07080", "#a04058", "#501020", "#a04058"),
     m_huojinshen),
    ("sibing", "四饼", "四饼：托盘折敷与猫又，本膳旨味",
     pal("#18140c", "#282014", "#100e08", "#e0b070", "#f8e8c0", "#c09060", "#c08030", "#603810", "#c08030"),
     m_sibing),
    ("dayueling-yuxin", "大岳丸·渝心", "大岳丸·渝心：八尺琼勾玉与海浪，麓鸣铃鹿",
     pal("#0c1418", "#142430", "#080c12", "#70a0c0", "#c0d8e8", "#6088a0", "#3080b0", "#103850", "#3080b0"),
     m_dayueling),
    ("chili", "螭璃", "螭璃：蟠龙吐息与龙宫宝，归墟行云",
     pal("#0c1814", "#142820", "#080e0c", "#60b0a0", "#b0e0d0", "#509888", "#28a080", "#104838", "#28a080"),
     m_chili),
    # 星缘百策
    ("jieshen-suiyuan", "缘结神·遂愿", "缘结神·遂愿：红缘结与福签，缘定三生",
     pal("#180c14", "#281420", "#10080e", "#f0a0c0", "#f8d0e0", "#c080a0", "#e05080", "#601838", "#e05080"),
     m_jieshen),
    ("tieshu-haojia", "铁鼠·豪贾", "铁鼠·豪贾：金钱与豪商算盘，孤注一掷",
     pal("#181408", "#28200c", "#100e04", "#d0a040", "#f0d890", "#b08830", "#c08800", "#503000", "#c08800"),
     m_tieshu),
    ("yijin-qianxun", "以津真天·千寻", "以津真天·千寻：金羽流光与风引，千羽庇佑",
     pal("#0c1418", "#142430", "#080c12", "#a0d0e0", "#d0eef8", "#70a8c0", "#40a0c8", "#184860", "#40a0c8"),
     m_yijin),
    ("baizangzhu-lixin", "白藏主·砺心", "白藏主·砺心：白狐青焰，狐心双焰",
     pal("#0c180c", "#142814", "#080e08", "#c0d0a0", "#e8f0d0", "#90a870", "#60a030", "#284818", "#60a030"),
     m_baizang),
    ("guijinyang", "鬼金羊", "鬼金羊：金角预告信，鬼宿奇惊",
     pal("#140c18", "#201428", "#0c0812", "#b0a0e0", "#e0d8f8", "#9080c0", "#7050c0", "#302060", "#7050c0"),
     m_guijinyang),
    ("longche", "胧车", "胧车：幽灵牛车与呱太，呱太军团",
     pal("#0c180c", "#142814", "#080e08", "#80c090", "#c8e8d0", "#60a078", "#30a060", "#184830", "#30a060"),
     m_longche),
    # 斗转万象
    ("pinfashen", "贫乏神", "贫乏神：贫穷面具与破币，灾厄降临",
     pal("#18140c", "#242014", "#100e08", "#908060", "#d0c8a8", "#807050", "#806828", "#382808", "#806828"),
     m_pinfashen),
    ("longjue", "龙珏", "龙珏：龙珠与乾坤两仪，飞龙行道",
     pal("#0c1418", "#142430", "#080c12", "#50a0c0", "#a8d0e8", "#4088a8", "#2080b0", "#103850", "#2080b0"),
     m_longjue),
    ("fengyangjun", "封阳君", "封阳君：双刀日月与易势，望月星河",
     pal("#181408", "#28200c", "#100e04", "#e0c060", "#f8e8a8", "#c0a040", "#d0a000", "#504000", "#d0a000"),
     m_fengyang),
    ("jintianyuzaoqian", "烬天玉藻前", "烬天玉藻前：九尾狐火与烬羽，浮世悲歌",
     pal("#180c0c", "#281414", "#100808", "#e06050", "#f8c0b0", "#c05040", "#d03020", "#501008", "#d03020"),
     m_jintian),
    ("chanxinyunwaijing", "禅心云外镜", "禅心云外镜：阴阳双镜与莲印，万法皆空",
     pal("#0c1218", "#142030", "#080c12", "#c0c8e0", "#e8ecf8", "#a0a8c0", "#8088c0", "#303860", "#8088c0"),
     m_chanxin),
    ("zhaocaimao", "招财猫", "招财猫：招手御守与金币，洒金成雨",
     pal("#181408", "#28200c", "#100e04", "#f0c070", "#f8e8b0", "#c0a050", "#e0a020", "#604000", "#e0a020"),
     m_zhaocaimao),
    ("maozhanggui-huanyan", "猫掌柜·焕宴", "猫掌柜·焕宴：暖帘蓝图与猫侍应，新生祭典",
     pal("#180c0c", "#281414", "#100808", "#e09080", "#f8d0c0", "#c07868", "#d06040", "#502010", "#d06040"),
     m_maozhang),
    # 花札祈梦
    ("geluoduo", "歌留多", "歌留多：花札与芒上月，花月乱舞",
     pal("#180c10", "#281418", "#10080c", "#f0b0a0", "#f8d8d0", "#c09080", "#e07060", "#502018", "#e07060"),
     m_geluoduo),
    ("yinfanhuiyeji", "因幡辉夜姬", "因幡辉夜姬：竹月与因幡兔，月光流照",
     pal("#140c18", "#201430", "#0c0812", "#d0c0f0", "#ebe0ff", "#a890d0", "#8060d0", "#382060", "#8060d0"),
     m_kaguya),
    ("daixiaoguhuoniao", "待宵姑获鸟", "待宵姑获鸟：夜鹤与墨剑，金羽流焰",
     pal("#0c1218", "#142030", "#080c12", "#80a0c0", "#c8d8e8", "#6888a8", "#4068a0", "#183050", "#4068a0"),
     m_daixiao),
    ("chulingshanfeng", "初翎山风", "初翎山风：山鹰与风刃，啸火入阵",
     pal("#0c180c", "#142814", "#080e08", "#70b080", "#c0e0c8", "#589070", "#30a050", "#184828", "#30a050"),
     m_shanfeng),
    ("fenghuanghuo-jingyu", "凤凰火·净羽", "凤凰火·净羽：净羽凤焰与火种，夜火流空",
     pal("#180c08", "#28140c", "#100804", "#f08050", "#f8c8a8", "#c06840", "#e05010", "#502000", "#e05010"),
     m_fenghuang),
    ("xixueji-xiyi", "吸血姬·曦忆", "吸血姬·曦忆：血月与曦忆，二重禁忌",
     pal("#180810", "#281018", "#10060c", "#c05070", "#f0b0c0", "#a04058", "#c02048", "#500818", "#c02048"),
     m_xixueji),
    ("yinghuayao-lijing", "樱花妖·璃景", "樱花妖·璃景：琉璃樱与花雨，璃魄华舞",
     pal("#180c10", "#281418", "#10080c", "#f0a0b0", "#f8d0d8", "#c08090", "#e06080", "#501828", "#e06080"),
     m_yinghua),
    ("shenqilou", "蜃气楼", "蜃气楼：蜃气楼阁与百识符，胧月夜",
     pal("#0c1218", "#142030", "#080c12", "#90a0b0", "#d0d8e0", "#788898", "#506878", "#203040", "#506878"),
     m_shenqilou),
]


def build(uid: str, title: str, desc: str, palette: dict, motif_fn, awakened: bool) -> str:
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
