#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 25 wave8-pack shikigami.

Re-runnable: writes assets/wave8/<id>.svg and <id>-awakened.svg.
Style matches assets/wave6/* — ink-night aesthetic, viewBox 0 0 200 260.
No external resources, unique gradient IDs prefixed by unit id. No NetEase art.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave8"

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

def m_chen(p):
    return f"""  <g>
    <polygon points="{star_pts(100, 100, 20, 48, 5)}" fill="url(#{p}-body)" opacity=".55" stroke="#2a2040" stroke-width="1.4"/>
    <circle cx="100" cy="100" r="18" fill="none" stroke="url(#{p}-gold)" stroke-width="1.4"/>
    <path d="M100 52v-12M100 160v12M52 100H40M160 100h12" stroke="url(#{p}-acc)" stroke-width="1.6"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_tianzhao(p):
    return f"""  <g>
    <circle cx="100" cy="100" r="42" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.4"/>
    <g stroke="url(#{p}-gold)" stroke-width="2">
      <path d="M100 40v-16M100 176v16M40 100H24M176 100h16"/>
      <path d="M58 58l-11-11M153 58l11-11M58 142l-11 11M153 142l11 11"/>
    </g>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yuedu(p):
    return f"""  <g>
    <path d="M130 55a55 55 0 1 0 0 90 48 48 0 0 1 0-90z" fill="url(#{p}-body)" opacity=".55" stroke="#2a2040" stroke-width="1.4"/>
    <circle cx="78" cy="100" r="14" fill="url(#{p}-acc)" opacity=".45"/>
    <path d="M55 70c20 10 20 50 0 60" fill="none" stroke="url(#{p}-gold)" stroke-width="1.4"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_gunv(p):
    return f"""  <g>
    <ellipse cx="100" cy="70" rx="28" ry="32" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.4"/>
    <path d="M72 100c-8 30-6 60 4 80M128 100c8 30 6 60-4 80" fill="none" stroke="url(#{p}-acc)" stroke-width="3"/>
    <path d="M85 110c5 25 5 45 0 65M115 110c-5 25-5 45 0 65" stroke="url(#{p}-gold)" stroke-width="1.2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yunv(p):
    return f"""  <g>
    <path d="M60 50c20 30 20 70 0 110M100 45c10 35 10 75 0 115M140 50c-20 30-20 70 0 110" fill="none" stroke="url(#{p}-acc)" stroke-width="2.2"/>
    <ellipse cx="100" cy="175" rx="40" ry="12" fill="url(#{p}-body)" opacity=".45"/>
    <circle cx="100" cy="90" r="10" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_huangqiming(p):
    return f"""  <g>
    <polygon points="{star_pts(100, 95, 14, 50, 6)}" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.3"/>
    <path d="M50 160c20-20 80-20 100 0" fill="none" stroke="url(#{p}-gold)" stroke-width="1.6"/>
    <circle cx="100" cy="95" r="12" fill="url(#{p}-acc)" opacity=".6"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_zhuiyue(p):
    return f"""  <g>
    <circle cx="100" cy="100" r="36" fill="none" stroke="url(#{p}-acc)" stroke-width="2.4"/>
    <circle cx="100" cy="100" r="22" fill="url(#{p}-body)" opacity=".5"/>
    <path d="M100 50c18 10 18 30 0 40 18 10 18 30 0 40" fill="none" stroke="url(#{p}-gold)" stroke-width="1.5"/>
    <circle cx="100" cy="55" r="5" fill="url(#{p}-gold)" opacity=".8"/>
    <circle cx="100" cy="145" r="5" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_wushimaoshi(p):
    return f"""  <g>
    <path d="M70 70l12-28 18 18 18-18 12 28v50c0 30-14 50-30 50s-30-20-30-50z" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.4"/>
    <path d="M78 110h12M110 110h12" stroke="url(#{p}-gold)" stroke-width="2"/>
    <path d="M88 140c8 8 16 8 24 0" fill="none" stroke="url(#{p}-acc)" stroke-width="1.5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yixienamei(p):
    return f"""  <g>
    <path d="M55 170c20-10 30-40 20-70s10-50 40-50 45 25 35 55-5 55 20 75" fill="none" stroke="url(#{p}-acc)" stroke-width="3.2"/>
    <path d="M70 130c15-5 25-25 20-45s15-35 35-30" fill="none" stroke="url(#{p}-gold)" stroke-width="1.6"/>
    <ellipse cx="100" cy="95" rx="18" ry="28" fill="url(#{p}-body)" opacity=".45"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_daorenshen(p):
    return f"""  <g>
    <rect x="70" y="85" width="60" height="45" rx="6" fill="url(#{p}-body)" opacity=".55" stroke="#2a2040" stroke-width="1.4"/>
    <path d="M70 100h60M85 85v-8h30v8" stroke="url(#{p}-gold)" stroke-width="1.6"/>
    <polygon points="{star_pts(100, 108, 6, 14, 4)}" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_guishibai(p):
    return f"""  <g>
    <rect x="82" y="55" width="36" height="100" rx="4" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.3"/>
    <path d="M90 75h20M90 95h20M90 115h14" stroke="url(#{p}-gold)" stroke-width="1.3"/>
    <circle cx="100" cy="145" r="8" fill="url(#{p}-acc)" opacity=".55"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_guishihei(p):
    return f"""  <g>
    <path d="M55 175L145 55" stroke="url(#{p}-acc)" stroke-width="6" stroke-linecap="round"/>
    <path d="M65 165l-8 20 20-8z" fill="url(#{p}-gold)" opacity=".75"/>
    <circle cx="130" cy="75" r="16" fill="url(#{p}-body)" opacity=".5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_mianqiling(p):
    return f"""  <g>
    <ellipse cx="100" cy="105" rx="42" ry="52" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.4"/>
    <path d="M75 95c5-8 15-8 20 0M105 95c5-8 15-8 20 0" fill="none" stroke="url(#{p}-gold)" stroke-width="1.6"/>
    <path d="M85 130c10 10 20 10 30 0" fill="none" stroke="url(#{p}-acc)" stroke-width="1.5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yingcao(p):
    return f"""  <g>
    <circle cx="100" cy="100" r="28" fill="url(#{p}-body)" opacity=".5"/>
    <g fill="url(#{p}-acc)" opacity=".65">
      <ellipse cx="100" cy="62" rx="12" ry="22"/>
      <ellipse cx="100" cy="138" rx="12" ry="22"/>
      <ellipse cx="62" cy="100" rx="22" ry="12"/>
      <ellipse cx="138" cy="100" rx="22" ry="12"/>
    </g>
    <circle cx="100" cy="100" r="12" fill="url(#{p}-gold)" opacity=".75"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_ertong(p):
    return f"""  <g>
    <circle cx="80" cy="105" r="28" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.2"/>
    <circle cx="125" cy="105" r="28" fill="url(#{p}-body)" opacity=".45" stroke="#2a2040" stroke-width="1.2"/>
    <circle cx="80" cy="105" r="10" fill="url(#{p}-gold)" opacity=".7"/>
    <circle cx="125" cy="105" r="10" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_tongnan(p):
    return f"""  <g>
    <path d="M100 55c-25 15-35 50-20 90 15 25 45 25 60 0 15-40 5-75-20-90-5-3-15-3-20 0z" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.3"/>
    <path d="M70 90c-20 5-30 25-15 40M130 90c20 5 30 25 15 40" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_zhiwu(p):
    return f"""  <g>
    <path d="M55 80l45-25 45 25-45 25z" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.2"/>
    <path d="M55 120l45-25 45 25-45 25z" fill="url(#{p}-acc)" opacity=".45" stroke="#2a2040" stroke-width="1"/>
    <path d="M55 160l45-25 45 25-45 25z" fill="url(#{p}-body)" opacity=".4" stroke="#2a2040" stroke-width="1"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_fansi(p):
    return f"""  <g>
    <ellipse cx="100" cy="120" rx="48" ry="32" fill="url(#{p}-body)" opacity=".55" stroke="#2a2040" stroke-width="1.4"/>
    <circle cx="100" cy="95" r="22" fill="url(#{p}-acc)" opacity=".5"/>
    <path d="M70 120h60" stroke="url(#{p}-gold)" stroke-width="1.5"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_longzi(p):
    return f"""  <g>
    <path d="M60 50c30 20 30 70 0 110 40-10 55-50 40-110z" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.3"/>
    <path d="M95 45c25 25 25 75 0 115 35-15 45-55 30-115z" fill="url(#{p}-acc)" opacity=".4"/>
    <path d="M50 175c30-15 70-15 100 0" fill="none" stroke="url(#{p}-gold)" stroke-width="1.8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_maochuan(p):
    return f"""  <g>
    <rect x="65" y="60" width="70" height="90" rx="4" fill="url(#{p}-body)" opacity=".5" stroke="#2a2040" stroke-width="1.3"/>
    <path d="M75 80h50M75 100h40M75 120h45" stroke="url(#{p}-gold)" stroke-width="1.3"/>
    <path d="M135 100c15 5 20 25 5 35" fill="none" stroke="url(#{p}-acc)" stroke-width="1.8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_alaina(p):
    return f"""  <g>
    <path d="M55 150c10-50 30-80 45-80s35 30 45 80" fill="url(#{p}-body)" opacity=".45" stroke="#2a2040" stroke-width="1.3"/>
    <path d="M70 130c15-30 25-45 30-45s15 15 30 45" fill="none" stroke="url(#{p}-acc)" stroke-width="1.8"/>
    <circle cx="100" cy="85" r="12" fill="url(#{p}-gold)" opacity=".65"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_youning(p):
    return f"""  <g>
    <path d="M55 140c20-40 40-60 45-60s25 20 45 60" fill="none" stroke="url(#{p}-acc)" stroke-width="2.4"/>
    <circle cx="75" cy="115" r="8" fill="url(#{p}-gold)" opacity=".7"/>
    <circle cx="100" cy="95" r="8" fill="url(#{p}-gold)" opacity=".7"/>
    <circle cx="125" cy="115" r="8" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_xiaolunan(p):
    return f"""  <g>
    <path d="M100 55v90" stroke="url(#{p}-acc)" stroke-width="3"/>
    <path d="M100 80c-25-5-35-25-30-40 20 5 30 20 30 40zM100 80c25-5 35-25 30-40-20 5-30 20-30 40z" fill="url(#{p}-body)" opacity=".5"/>
    <path d="M100 110c-30 0-45-15-40-35 25 5 40 15 40 35zM100 110c30 0 45-15 40-35-25 5-40 15-40 35z" fill="url(#{p}-acc)" opacity=".45"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_rihe(p):
    return f"""  <g>
    <circle cx="100" cy="100" r="34" fill="url(#{p}-body)" opacity=".55"/>
    <g stroke="url(#{p}-gold)" stroke-width="1.8">
      <path d="M100 50v-12M100 162v12M50 100H38M162 100h12M64 64l-9-9M145 64l9-9M64 136l-9 9M145 136l9 9"/>
    </g>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yanyan(p):
    return f"""  <g>
    <path d="M50 150c20-20 30-50 25-80 20 15 30 45 25 80 20-10 35-40 30-75 25 25 25 65 5 85" fill="url(#{p}-body)" opacity=".45" stroke="#2a2040" stroke-width="1.2"/>
    <path d="M70 90c15-8 25-8 40 0M85 120c10-5 20-5 30 0" fill="none" stroke="url(#{p}-gold)" stroke-width="1.3"/>
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
    # 祝星启明
    ("chen", "辰", "辰：行度星轨，祝星启悟",
     pal("#141008", "#201810", "#0c0a06", "#f0d070", "#f8e8a8", "#d0b050", "#d0a020", "#705010", "#d0a020"),
     m_chen),
    ("tianzhao", "天照", "天照：天晖曜日，启悟神光",
     pal("#181008", "#281810", "#100804", "#f0c060", "#f8e0a0", "#d0a050", "#d08020", "#704010", "#d08020"),
     m_tianzhao),
    ("yuedu", "月读", "月读：虚月无光，启悟惑星",
     pal("#0e0c18", "#181428", "#0a0812", "#c0b0e8", "#e0d8f0", "#a090c0", "#8060c0", "#402070", "#8060c0"),
     m_yuedu),
    ("gunv", "骨女", "骨女：骸骨转生，怨生赤霞",
     pal("#120e0c", "#1c1614", "#0c0a08", "#d0c0b0", "#e8d8c8", "#a89080", "#806050", "#403028", "#806050"),
     m_gunv),
    ("yunv", "雨女", "雨女：天泪断桥，启悟雨霖",
     pal("#0a1218", "#122030", "#080c12", "#80b0d0", "#c0d8f0", "#70a0c0", "#4080b0", "#183858", "#4080b0"),
     m_yunv),
    ("huang-qiming", "荒·启命", "荒·启命：命运星河，启悟星猎",
     pal("#0c0c18", "#141428", "#080810", "#90a0f0", "#d0d4f8", "#8090c0", "#5060b0", "#202860", "#5060b0"),
     m_huangqiming),
    ("zhuiyueshen-shuiyue", "追月神·水月", "追月神·水月：流明映月，启悟对歌",
     pal("#0a1418", "#122430", "#080e12", "#a0c8e8", "#c8e0f8", "#70a0c8", "#4080b8", "#183858", "#4080b8"),
     m_zhuiyue),
    ("wushi-maoshi", "武士之灵·猫侍", "武士之灵·猫侍：武魂默想，初心诛心",
     pal("#140c0c", "#201414", "#0c0808", "#c09080", "#e0c0b0", "#a87868", "#904840", "#482018", "#904840"),
     m_wushimaoshi),
    # 湮灭双生
    ("yixienamei", "伊邪那美", "伊邪那美：蛇群压血，灭世神吻",
     pal("#0c1410", "#142018", "#080e0a", "#80c080", "#c0e0c0", "#70a070", "#40a050", "#184828", "#40a050"),
     m_yixienamei),
    ("guishibai", "鬼使白", "鬼使白：白符归魂，点灯借尸",
     pal("#101418", "#182030", "#0a0e12", "#d0e0f0", "#e8f0fa", "#a0b0c8", "#7088a8", "#304058", "#7088a8"),
     m_guishibai),
    ("guishihei", "鬼使黑", "鬼使黑：黑刃索魂，天下太平",
     pal("#0c0c12", "#14141c", "#08080c", "#606080", "#a0a0b8", "#707088", "#404058", "#202030", "#404058"),
     m_guishihei),
    ("mianqiling-xinsu", "面灵气·心宿", "面灵气·心宿：面相四相，心生相窥",
     pal("#180c14", "#28141c", "#10080c", "#e0a0c0", "#f0c8d8", "#c080a0", "#c04080", "#601840", "#c04080"),
     m_mianqiling),
    ("yingcao-pupu", "萤草·蒲蒲", "萤草·蒲蒲：光种四叶，醒神之约",
     pal("#101408", "#182010", "#0a0e06", "#b0e080", "#d8f0b0", "#90b060", "#60a030", "#284818", "#60a030"),
     m_yingcao),
    ("ertong", "二瞳", "二瞳：猫灵铃迎，代理掌柜",
     pal("#0a1412", "#10201c", "#080c0a", "#a0d0c0", "#c8e8e0", "#70a898", "#40a088", "#184840", "#40a088"),
     m_ertong),
    ("tongnantongnv", "童男童女", "童男童女：羽护童歌，月光同怀",
     pal("#14100c", "#201814", "#0c0a08", "#e0c0a0", "#f0d8b8", "#c0a078", "#c08040", "#604020", "#c08040"),
     m_tongnan),
    ("zhiwu", "纸舞", "纸舞：落纸日轮，砚上翩跹",
     pal("#14120e", "#201c18", "#0c0a08", "#f0e0d0", "#f8f0e8", "#c0b0a0", "#a08060", "#504030", "#a08060"),
     m_zhiwu),
    ("daorenshen", "盗人神", "盗人神：财宝日行，断予夜偷",
     pal("#141008", "#201810", "#0c0a04", "#d0a060", "#f0d0a0", "#b08040", "#a06020", "#503010", "#a06020"),
     m_daorenshen),
    # 千录晴诗
    ("fansi", "饭笥", "饭笥：饱足月见，神明料理",
     pal("#140e08", "#201810", "#0c0a06", "#e0b070", "#f0d0a0", "#c09050", "#a06030", "#503018", "#a06030"),
     m_fansi),
    ("longzi", "泷", "泷：涛泷溢能，决荡王牌",
     pal("#081418", "#102830", "#061014", "#70b0e0", "#b0d8f0", "#60a0c0", "#3080b0", "#184058", "#3080b0"),
     m_longzi),
    ("maochuan", "猫川", "猫川：卷轴代价，长河垄断",
     pal("#120e0a", "#1c1812", "#0c0a06", "#c0a070", "#e0d0a8", "#a89060", "#906838", "#483018", "#906838"),
     m_maochuan),
    ("alaina", "阿莱娜", "阿莱娜：灵咒圣书，沙之终焉",
     pal("#140c14", "#201420", "#0c080c", "#d0a0d0", "#e8c8e8", "#b080b0", "#a050a0", "#502050", "#a050a0"),
     m_alaina),
    ("youning", "攸宁", "攸宁：诗乐无邪，诂训重章",
     pal("#0c140e", "#142018", "#080e0a", "#a0c0a0", "#c8e0c8", "#80a880", "#508850", "#284828", "#508850"),
     m_youning),
    ("xiaolunan-qianshou", "小鹿男·千守", "小鹿男·千守：森灵巡山，巨鹿神像",
     pal("#0c140c", "#142014", "#080e08", "#80b070", "#c0d8b0", "#70a060", "#408830", "#204818", "#408830"),
     m_xiaolunan),
    ("rihefang-qingyang", "日和坊·晴阳", "日和坊·晴阳：晴阳曝日，五月快晴",
     pal("#141008", "#201810", "#0c0a04", "#f0c080", "#f8e0b0", "#d0a060", "#c08030", "#604010", "#c08030"),
     m_rihe),
    ("yanyanluo-fumiao", "烟烟罗·浮缈", "烟烟罗·浮缈：浮缈雾锁，瀑上烟霞",
     pal("#120e12", "#1c161c", "#0c0a0c", "#c0a0b0", "#e0c8d0", "#a88898", "#885870", "#402838", "#885870"),
     m_yanyan),
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
