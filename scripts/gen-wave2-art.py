#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 9 wave2-pack shikigami.

Re-runnable: writes assets/wave2/<id>.svg and <id>-awakened.svg.
Style matches assets/ember.svg / assets/classic/* — ink-night Japanese aesthetic,
viewBox 0 0 200 260. No external resources, unique gradient IDs prefixed by unit id.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave2"

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

def m_yaohu(p):
    # fox mask + wind blades (妖狐)
    return f"""  <g>
    <path d="M100 48c-22 8-34 28-34 52 0 30 16 54 34 66 18-12 34-36 34-66 0-24-12-44-34-52Z" fill="url(#{p}-body)" stroke="#2a1a30" stroke-width="2"/>
    <path d="M72 78l-18-28 28 12ZM128 78l18-28-28 12Z" fill="url(#{p}-acc)" opacity=".9"/>
    <ellipse cx="86" cy="108" rx="9" ry="5" fill="#1a0a18"/>
    <ellipse cx="114" cy="108" rx="9" ry="5" fill="#1a0a18"/>
    <circle cx="87" cy="107" r="2" fill="#f0c0ff"/><circle cx="115" cy="107" r="2" fill="#f0c0ff"/>
    <path d="M94 124c4 5 8 5 12 0" stroke="#3a2038" stroke-width="1.8" fill="none"/>
  </g>
  <g fill="none" stroke="url(#{p}-acc)" stroke-width="1.8" stroke-linecap="round" opacity=".85">
    <path d="M40 70c18 4 28 18 30 34"/>
    <path d="M36 96c16 2 26 12 30 26"/>
    <path d="M160 70c-18 4-28 18-30 34"/>
    <path d="M164 96c-16 2-26 12-30 26"/>
  </g>
""" + dots(p, [(42, 60, 2.2, ".7"), (158, 62, 2, ".65"), (34, 140, 1.8, ".55"),
               (166, 142, 1.8, ".55"), (100, 30, 1.6, ".5"), (68, 190, 1.6, ".5"),
               (132, 192, 1.8, ".55")])


def m_tiaotiaomeimei(p):
    # girl pigtail + tomato (跳跳妹妹)
    return f"""  <g>
    <circle cx="78" cy="78" r="14" fill="url(#{p}-body)" stroke="#4a2030" stroke-width="1.5"/>
    <circle cx="122" cy="78" r="14" fill="url(#{p}-body)" stroke="#4a2030" stroke-width="1.5"/>
    <ellipse cx="100" cy="110" rx="36" ry="40" fill="url(#{p}-body)" stroke="#4a2030" stroke-width="2"/>
    <ellipse cx="86" cy="108" rx="5" ry="4" fill="#2a1018"/>
    <ellipse cx="114" cy="108" rx="5" ry="4" fill="#2a1018"/>
    <circle cx="87" cy="107" r="1.5" fill="#ffe0f0"/><circle cx="115" cy="107" r="1.5" fill="#ffe0f0"/>
    <path d="M92 124c5 7 12 7 16 0" stroke="#5a2838" stroke-width="1.8" fill="none" stroke-linecap="round"/>
  </g>
  <g>
    <ellipse cx="148" cy="168" rx="22" ry="18" fill="#e04858" stroke="#7a2028" stroke-width="1.6"/>
    <path d="M148 150c-2 6-2 10 0 14 4-4 8-8 10-12-4 0-8-2-10-2Z" fill="#3d8f4a"/>
    <ellipse cx="140" cy="164" rx="4" ry="3" fill="#ff8090" opacity=".7"/>
  </g>
  <path d="M70 178h60l-8 24H78Z" fill="url(#{p}-body)" opacity=".55"/>
""" + dots(p, [(40, 100, 2, ".6"), (164, 96, 1.8, ".55"), (36, 160, 1.6, ".5"),
               (172, 130, 1.5, ".5"), (100, 28, 1.6, ".5"), (56, 200, 1.5, ".5"),
               (120, 40, 1.3, ".45")])


def m_buzhinhuo(p):
    # phoenix dance / fire lotus (不知火·不夜之火)
    return f"""  <g>
    <path d="M100 40c-8 18-28 28-36 50-6 16-2 34 10 46 8-20 18-34 26-48 8 14 18 28 26 48 12-12 16-30 10-46-8-22-28-32-36-50Z" fill="url(#{p}-acc)" opacity=".85"/>
    <ellipse cx="100" cy="118" rx="28" ry="34" fill="url(#{p}-body)" opacity=".7" stroke="#5a1810" stroke-width="1.6"/>
    <path d="M78 92c8 4 16 4 22 0M100 92c8 4 16 4 22 0" stroke="#ffd0a0" stroke-width="1.3" fill="none"/>
  </g>
  <g fill="none" stroke="url(#{p}-gold)" stroke-width="1.2" opacity=".65">
    <path d="M60 150c20 16 60 16 80 0"/>
    <path d="M52 168c28 18 68 18 96 0"/>
    <path d="M70 188c16 10 44 10 60 0"/>
  </g>
  <path d="M100 200c-10-8-16-18-16-28h32c0 10-6 20-16 28Z" fill="url(#{p}-acc)" opacity=".55"/>
""" + dots(p, [(44, 70, 2.2, ".7"), (156, 74, 2, ".65"), (38, 140, 1.8, ".55"),
               (164, 146, 1.8, ".55"), (100, 26, 1.8, ".55"), (64, 196, 1.6, ".5"),
               (136, 198, 1.6, ".5")], f"url(#{p}-body)")


def m_xiaolunan(p):
    # deer antlers + forest mist (小鹿男)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2.4" stroke-linecap="round">
    <path d="M78 70c-8-18-8-34 2-48M78 58c-14-6-24-4-32 2M78 44c-10-8-14-18-12-28"/>
    <path d="M122 70c8-18 8-34-2-48M122 58c14-6 24-4 32 2M122 44c10-8 14-18 12-28"/>
  </g>
  <ellipse cx="100" cy="112" rx="34" ry="40" fill="url(#{p}-body)" stroke="#2a3a20" stroke-width="2"/>
  <ellipse cx="86" cy="108" rx="5.5" ry="4" fill="#1a2810"/>
  <ellipse cx="114" cy="108" rx="5.5" ry="4" fill="#1a2810"/>
  <circle cx="87" cy="107" r="1.6" fill="#d0f0a0"/><circle cx="115" cy="107" r="1.6" fill="#d0f0a0"/>
  <path d="M94 126c4 4 8 4 12 0" stroke="#2a3a20" stroke-width="1.6" fill="none"/>
  <path d="M40 170c20 10 100 10 120 0" fill="none" stroke="url(#{p}-body)" stroke-width="2" opacity=".5"/>
  <path d="M50 186c24 8 76 8 100 0" fill="none" stroke="url(#{p}-body)" stroke-width="1.6" opacity=".4"/>
""" + dots(p, [(42, 100, 2, ".6"), (160, 104, 1.8, ".55"), (36, 150, 1.6, ".5"),
               (168, 154, 1.6, ".5"), (100, 24, 1.5, ".5"), (70, 200, 1.5, ".5"),
               (130, 200, 1.5, ".5")])


def m_yanyanluo(p):
    # smoke curls + paper doll (烟烟罗)
    return f"""  <g fill="none" stroke="url(#{p}-acc)" stroke-width="2" stroke-linecap="round" opacity=".8">
    <path d="M48 80c16-20 40-16 48 4 8 18-4 34-20 36"/>
    <path d="M52 120c12-14 32-12 38 4"/>
    <path d="M152 80c-16-20-40-16-48 4-8 18 4 34 20 36"/>
    <path d="M148 120c-12-14-32-12-38 4"/>
  </g>
  <ellipse cx="100" cy="118" rx="32" ry="38" fill="url(#{p}-body)" opacity=".75" stroke="#3a2a48" stroke-width="1.8"/>
  <path d="M88 88h24l-4 28H92Z" fill="#e8d8f0" opacity=".5"/>
  <ellipse cx="88" cy="116" rx="5" ry="3.5" fill="#2a1838"/>
  <ellipse cx="112" cy="116" rx="5" ry="3.5" fill="#2a1838"/>
  <circle cx="89" cy="115" r="1.4" fill="#e0c0ff"/><circle cx="113" cy="115" r="1.4" fill="#e0c0ff"/>
  <path d="M100 168c-20 8-30 24-30 40h60c0-16-10-32-30-40Z" fill="url(#{p}-body)" opacity=".5"/>
""" + dots(p, [(40, 70, 2.2, ".7"), (160, 68, 2, ".65"), (34, 140, 2, ".6"),
               (168, 144, 1.8, ".55"), (100, 28, 1.6, ".5"), (62, 190, 1.6, ".5"),
               (140, 194, 1.8, ".55")], f"url(#{p}-body)")


def m_rihefang(p):
    # sun disk + rain clouds (日和坊)
    return f"""  <g>
    <circle cx="100" cy="96" r="36" fill="url(#{p}-acc)" opacity=".85"/>
    <circle cx="100" cy="96" r="24" fill="#ffe8a0" opacity=".55"/>
  </g>
  <g fill="url(#{p}-body)" opacity=".75">
    <ellipse cx="62" cy="150" rx="28" ry="16"/>
    <ellipse cx="88" cy="146" rx="24" ry="14"/>
    <ellipse cx="130" cy="152" rx="30" ry="15"/>
    <ellipse cx="110" cy="148" rx="22" ry="13"/>
  </g>
  <g stroke="url(#{p}-body)" stroke-width="1.5" opacity=".5" stroke-linecap="round">
    <path d="M58 172v12M78 176v10M98 174v12M118 176v10M138 172v12"/>
  </g>
  <path d="M88 96c4 6 8 6 12 0M100 96c4 6 8 6 12 0" stroke="#8a5010" stroke-width="1.4" fill="none" opacity=".5"/>
""" + dots(p, [(44, 70, 2, ".6"), (156, 74, 1.8, ".55"), (36, 120, 1.6, ".5"),
               (168, 124, 1.6, ".5"), (100, 28, 1.8, ".55"), (70, 200, 1.5, ".5"),
               (132, 200, 1.5, ".5")], f"url(#{p}-body)")


def m_lianyou(p):
    # three club/axe/spear silhouettes (镰鼬三太郎)
    return f"""  <g>
    <path d="M58 200l20-120 8 2-8 118Z" fill="url(#{p}-body)" stroke="#3a2810" stroke-width="1.4"/>
    <ellipse cx="72" cy="72" rx="16" ry="12" fill="url(#{p}-acc)" stroke="#3a2810" stroke-width="1.4"/>
    <path d="M100 205l4-130 10 0-2 130Z" fill="url(#{p}-body)" stroke="#3a2810" stroke-width="1.4"/>
    <path d="M96 78h20l-4 18H100Z" fill="url(#{p}-acc)" stroke="#3a2810" stroke-width="1.2"/>
    <path d="M142 200l-18-115 8-2 14 117Z" fill="url(#{p}-body)" stroke="#3a2810" stroke-width="1.4"/>
    <path d="M128 70c12-16 30-18 42-6-14 4-28 8-42 6Z" fill="url(#{p}-acc)"/>
    <path d="M128 70c8 10 22 14 36 10-12 8-26 6-36-10Z" fill="url(#{p}-acc)" opacity=".8"/>
  </g>
  <ellipse cx="100" cy="128" rx="22" ry="18" fill="url(#{p}-body)" opacity=".45" stroke="url(#{p}-gold)" stroke-width="1"/>
""" + dots(p, [(42, 90, 2, ".6"), (162, 96, 1.8, ".55"), (38, 150, 1.6, ".5"),
               (168, 150, 1.6, ".5"), (100, 30, 1.5, ".5"), (60, 198, 1.5, ".5"),
               (140, 198, 1.5, ".5")])


def m_yatiangou(p):
    # crow wings + sword (鸦天狗)
    return f"""  <g>
    <path d="M90 100c-28-18-52-14-64 2 18 2 34 12 44 28-14-4-28 0-38 10 20 0 40 8 50 20Z" fill="url(#{p}-body)" opacity=".9"/>
    <path d="M110 100c28-18 52-14 64 2-18 2-34 12-44 28 14-4 28 0 38 10-20 0-40 8-50 20Z" fill="url(#{p}-body)" opacity=".9"/>
    <ellipse cx="100" cy="108" rx="28" ry="32" fill="url(#{p}-acc)" opacity=".9" stroke="#1a2028" stroke-width="2"/>
    <path d="M88 78l-8-24 20 12ZM112 78l8-24-20 12Z" fill="url(#{p}-acc)"/>
    <ellipse cx="88" cy="106" rx="5" ry="4" fill="#0a0c10"/>
    <ellipse cx="112" cy="106" rx="5" ry="4" fill="#0a0c10"/>
    <circle cx="89" cy="105" r="1.4" fill="#c0e0ff"/><circle cx="113" cy="105" r="1.4" fill="#c0e0ff"/>
    <path d="M100 118l4 8h-8Z" fill="#e8a040"/>
  </g>
  <path d="M148 56l8 90-10 2-8-90Z" fill="url(#{p}-gold)" stroke="#3a2810" stroke-width="1"/>
""" + dots(p, [(36, 80, 2, ".6"), (164, 84, 1.8, ".55"), (32, 140, 1.8, ".55"),
               (170, 146, 1.6, ".5"), (100, 28, 1.5, ".5"), (64, 198, 1.5, ".5"),
               (136, 198, 1.5, ".5")])


def m_lingyuyuqian(p):
    # bow + wave crest (铃鹿御前·海国)
    return f"""  <g>
    <path d="M70 50c-24 30-24 80 0 110" fill="none" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
    <path d="M70 50c8 30 8 80 0 110" fill="none" stroke="#e8f0f8" stroke-width="1" opacity=".5"/>
    <path d="M70 50h12M70 160h12" stroke="url(#{p}-gold)" stroke-width="1.5"/>
    <path d="M76 54v102" stroke="url(#{p}-body)" stroke-width="1.2" opacity=".7"/>
    <path d="M82 100h50l-8 6-8-6Z" fill="url(#{p}-gold)"/>
    <path d="M132 100l24 0-24 8Z" fill="url(#{p}-gold)"/>
  </g>
  <path d="M40 170c20-12 40-4 50 8 10-14 30-20 50-8 12 6 18 16 20 24H28c2-10 6-18 12-24Z" fill="url(#{p}-body)" opacity=".75"/>
  <path d="M55 176c14-6 28-2 35 6 8-8 22-12 35-6" fill="none" stroke="#d0e8f8" stroke-width="1.2" opacity=".6"/>
  <ellipse cx="145" cy="90" rx="16" ry="20" fill="url(#{p}-body)" opacity=".5" stroke="url(#{p}-gold)" stroke-width="1"/>
""" + dots(p, [(40, 70, 2, ".6"), (164, 70, 1.8, ".55"), (34, 130, 1.6, ".5"),
               (170, 140, 1.6, ".5"), (100, 30, 1.5, ".5"), (68, 200, 1.5, ".5"),
               (132, 200, 1.5, ".5")])


# ---------- unit table ----------

def pal(bg1, bg2, bg3, halo, body1, body2, acc1, acc2, frame,
        awk_bloom="rgba(255, 233, 178, 0.35)", awk_core="#ff8a3d"):
    return {
        "bg1": bg1, "bg2": bg2, "bg3": bg3, "halo": halo,
        "body1": body1, "body2": body2, "acc1": acc1, "acc2": acc2,
        "frame": frame, "awk_bloom": awk_bloom, "awk_core": awk_core,
    }


UNITS = [
    ("yaohu", "妖狐", "狐面与风刃：白狐面具居中，双侧风刃掠过夜色",
     pal("#140c18", "#201428", "#0c0810", "#d0a0f0", "#e8d0f8", "#b090d0", "#9060c0", "#502080", "#9060c0"),
     m_yaohu),
    ("tiaotiaomeimei", "跳跳妹妹", "双马尾与番茄：少女环形与一枚番茄跃出",
     pal("#180c12", "#28141c", "#10080c", "#f0a0b0", "#f8d0d8", "#e090a8", "#e85070", "#902040", "#e85070"),
     m_tiaotiaomeimei),
    ("buzhinhuo", "不知火", "凤凰焰舞与火莲：焰翼上扬，脚下火莲三叠",
     pal("#180c0c", "#2c1410", "#100808", "#ff9060", "#f8d0b0", "#e07040", "#e85030", "#8a2010", "#e85030"),
     m_buzhinhuo),
    ("xiaolunan", "小鹿男", "鹿角与森雾：枝角如冠，山雾自脚下升起",
     pal("#0e140c", "#182014", "#0a0e08", "#c0e080", "#e0f0c0", "#a0c060", "#70b040", "#305018", "#70b040"),
     m_xiaolunan),
    ("yanyanluo", "烟烟罗", "烟卷与纸人：双侧烟涡盘绕，中央纸人垂袖",
     pal("#120c18", "#1c1424", "#0c0810", "#c0a0e0", "#e0d0f0", "#a088c0", "#8060b0", "#402060", "#8060b0"),
     m_yanyanluo),
    ("rihefang", "日和坊", "日轮与雨云：上日下云，晴雨同框",
     pal("#141008", "#201810", "#0c0a06", "#f0d070", "#f8e8b0", "#e0b850", "#e0a020", "#805010", "#e0a020"),
     m_rihefang),
    ("lianyou", "镰鼬", "三太郎兵器：斧、棒、戟三器并立",
     pal("#14100c", "#201814", "#0e0a08", "#d0a860", "#e8d0a0", "#b08850", "#c08830", "#603810", "#c08830"),
     m_lianyou),
    ("yatiangou", "鸦天狗", "鸦羽与佩刀：墨羽展开，金柄太刀斜倚",
     pal("#0c1218", "#14202c", "#0a0c12", "#80b0d0", "#d0e0f0", "#88a8c0", "#5080b0", "#203850", "#5080b0"),
     m_yatiangou),
    ("lingyuyuqian", "铃鹿御前", "长弓与海浪：弯弓张弦，脚下海浪层叠",
     pal("#0a1418", "#12242c", "#080e12", "#60c0d0", "#c0e8f0", "#70a8b8", "#30a0b0", "#185060", "#30a0b0"),
     m_lingyuyuqian),
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
