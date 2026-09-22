#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate original stylized SVG portraits for the 10 wave11 derived shikigami.

Re-runnable: writes assets/wave11/<id>.svg and <id>-awakened.svg.
Style matches assets/wave6/* — ink-night aesthetic, viewBox 0 0 200 260.
No external resources, unique gradient IDs prefixed by unit id. No NetEase art.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "wave11"

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

def m_fanqie(p):
    # loyal tomato dog (番茄)
    return f"""  <g>
    <ellipse cx="100" cy="130" rx="36" ry="32" fill="url(#{p}-body)" stroke="#3a2018" stroke-width="1.8"/>
    <path d="M72 112c-10-16-4-28 8-22M128 112c10-16 4-28-8-22" fill="url(#{p}-acc)" stroke="#3a2018" stroke-width="1.4"/>
    <circle cx="88" cy="124" r="4" fill="#2a1010"/><circle cx="112" cy="124" r="4" fill="#2a1010"/>
    <path d="M94 142c4 5 8 5 12 0" stroke="#2a1010" stroke-width="1.5" fill="none"/>
    <ellipse cx="100" cy="136" rx="5" ry="3" fill="#401010"/>
    <path d="M100 78c-4 8-4 16 0 22 4-6 4-14 0-22Z" fill="url(#{p}-gold)"/>
    <path d="M55 175c20 10 70 10 90 0" stroke="url(#{p}-body)" stroke-width="2.5" fill="none" opacity=".55"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_bingqiang(p):
    # ice wall guardian (冰墙)
    return f"""  <g>
    <rect x="68" y="70" width="64" height="110" rx="6" fill="url(#{p}-body)" opacity=".7" stroke="#203848" stroke-width="1.8"/>
    <path d="M78 85l12-18 8 14 10-20 10 18 12-14 8 16" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
    <path d="M80 120h40M80 145h40M80 165h40" stroke="#203848" stroke-width="1.2" opacity=".5"/>
    <circle cx="100" cy="105" r="10" fill="url(#{p}-acc)" opacity=".55"/>
    <polygon points="{star_pts(100, 55, 5, 14, 6)}" fill="url(#{p}-gold)" opacity=".8"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_zhiren(p):
    # paper doll (纸人)
    return f"""  <g>
    <rect x="88" y="105" width="24" height="48" rx="3" fill="url(#{p}-body)" stroke="#3a3020" stroke-width="1.5"/>
    <circle cx="100" cy="92" r="13" fill="url(#{p}-body)" stroke="#3a3020" stroke-width="1.4"/>
    <path d="M88 120h-20M112 120h20M90 150l-12 18M110 150l12 18" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round"/>
    <circle cx="95" cy="90" r="2" fill="#2a2010"/><circle cx="105" cy="90" r="2" fill="#2a2010"/>
    <path d="M96 98c2 3 6 3 8 0" stroke="#2a2010" stroke-width="1.2" fill="none"/>
    <path d="M100 55c-2 8 0 14 4 18" stroke="url(#{p}-gold)" stroke-width="1.8" fill="none"/>
    <circle cx="104" cy="52" r="4" fill="url(#{p}-gold)"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_yanyanluo_fenshen(p):
    # smoke clone (烟烟罗分身)
    return f"""  <g fill="none" stroke="url(#{p}-body)" stroke-width="3" stroke-linecap="round" opacity=".75">
    <path d="M55 150c15-25 30-40 45-40s30 15 45 40"/>
    <path d="M60 125c12-20 25-32 40-32s28 12 40 32"/>
    <path d="M70 100c8-14 18-22 30-22s22 8 30 22"/>
  </g>
  <g>
    <ellipse cx="100" cy="88" rx="16" ry="14" fill="url(#{p}-acc)" opacity=".65"/>
    <circle cx="93" cy="86" r="2.5" fill="#2a2030"/><circle cx="107" cy="86" r="2.5" fill="#2a2030"/>
    <path d="M70 175c20 8 50 8 70 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none" opacity=".5"/>
    <circle cx="48" cy="130" r="6" fill="url(#{p}-acc)" opacity=".35"/>
    <circle cx="155" cy="140" r="5" fill="url(#{p}-acc)" opacity=".3"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_jinran_buye(p):
    # ember night dance (烬染不夜)
    return f"""  <g>
    <path d="M100 165c-25-15-35-45-20-75 8 18 15 32 20 45 5-13 12-27 20-45 15 30 5 60-20 75Z" fill="url(#{p}-body)" opacity=".75" stroke="#402010" stroke-width="1.5"/>
    <path d="M100 155c-8-12-12-28-8-42 3 10 6 18 8 28 2-10 5-18 8-28 4 14 0 30-8 42Z" fill="url(#{p}-acc)" opacity=".7"/>
    <circle cx="100" cy="70" r="6" fill="url(#{p}-gold)"/>
    <circle cx="72" cy="95" r="3" fill="url(#{p}-gold)" opacity=".8"/>
    <circle cx="130" cy="100" r="2.5" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_xueqiu_jingling(p):
    # snowball spirit cluster (雪球精灵)
    return f"""  <g>
    <circle cx="100" cy="135" r="32" fill="url(#{p}-body)" stroke="#203040" stroke-width="1.6"/>
    <circle cx="72" cy="105" r="18" fill="url(#{p}-acc)" opacity=".65" stroke="#203040" stroke-width="1.2"/>
    <circle cx="128" cy="108" r="16" fill="url(#{p}-acc)" opacity=".55" stroke="#203040" stroke-width="1.2"/>
    <circle cx="100" cy="88" r="14" fill="url(#{p}-body)" opacity=".8" stroke="#203040" stroke-width="1.2"/>
    <circle cx="90" cy="132" r="3.5" fill="#1a2838"/><circle cx="110" cy="132" r="3.5" fill="#1a2838"/>
    <path d="M94 145c4 4 8 4 12 0" stroke="#1a2838" stroke-width="1.4" fill="none"/>
    <polygon points="{star_pts(100, 55, 4, 12, 5)}" fill="url(#{p}-gold)" opacity=".75"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_huangjinyu_ling(p):
    # golden feather spirit (黄金羽灵)
    return f"""  <g>
    <path d="M100 170c-30-20-45-55-30-90 10 22 20 40 30 55 10-15 20-33 30-55 15 35 0 70-30 90Z" fill="url(#{p}-body)" opacity=".7" stroke="#403018" stroke-width="1.5"/>
    <path d="M78 100c8 5 14 5 22 2M100 115c8 5 14 5 22 2M85 125c6 4 11 4 16 2" stroke="url(#{p}-gold)" stroke-width="1.3" opacity=".8"/>
    <ellipse cx="100" cy="78" rx="12" ry="10" fill="url(#{p}-acc)" opacity=".7"/>
    <circle cx="96" cy="76" r="2" fill="#302008"/><circle cx="104" cy="76" r="2" fill="#302008"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_mingdeng_shou(p):
    # lantern bearer spirit (明灯使)
    return f"""  <g>
    <rect x="82" y="100" width="36" height="50" rx="6" fill="url(#{p}-body)" stroke="#403020" stroke-width="1.6"/>
    <path d="M88 100h24M88 150h24" stroke="url(#{p}-gold)" stroke-width="1.5"/>
    <path d="M100 88v-12" stroke="url(#{p}-gold)" stroke-width="2"/>
    <ellipse cx="100" cy="125" rx="10" ry="14" fill="url(#{p}-acc)" opacity=".75"/>
    <path d="M82 110h-14M118 110h14M82 140h-10M118 140h10" stroke="url(#{p}-body)" stroke-width="2" stroke-linecap="round"/>
    <circle cx="100" cy="70" r="6" fill="url(#{p}-gold)" opacity=".85"/>
    <path d="M70 175c20 8 50 8 70 0" stroke="url(#{p}-body)" stroke-width="2" fill="none" opacity=".45"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_xinmo(p):
    # heart demon / hannya hint (心魔)
    return f"""  <g>
    <path d="M70 100c8-32 22-50 30-50s22 18 30 50c-10 22-20 35-30 35s-20-13-30-35Z" fill="url(#{p}-body)" stroke="#301828" stroke-width="1.6"/>
    <path d="M78 90l-10-22M122 90l10-22" stroke="url(#{p}-acc)" stroke-width="2.2" stroke-linecap="round"/>
    <circle cx="88" cy="105" r="4" fill="#f0d0a0"/><circle cx="112" cy="105" r="4" fill="#f0d0a0"/>
    <circle cx="88" cy="105" r="1.5" fill="#301018"/><circle cx="112" cy="105" r="1.5" fill="#301018"/>
    <path d="M90 125c5 8 15 8 20 0" stroke="#301828" stroke-width="1.5" fill="none"/>
    <path d="M85 160c10 12 20 12 30 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
    <polygon points="{star_pts(100, 55, 4, 11, 5)}" fill="url(#{p}-gold)" opacity=".7"/>
  </g>
""" + dots(p, DEFAULT_DOTS)


def m_shouhu_ling(p):
    # guardian spirit / shield + dog silhouette (守护灵)
    return f"""  <g>
    <path d="M100 70l40 18v35c0 28-18 48-40 58-22-10-40-30-40-58V88Z" fill="url(#{p}-body)" opacity=".75" stroke="#203040" stroke-width="1.8"/>
    <path d="M100 85l28 12v28c0 20-12 34-28 42-16-8-28-22-28-42V97Z" fill="url(#{p}-acc)" opacity=".45"/>
    <circle cx="100" cy="115" r="8" fill="url(#{p}-gold)" opacity=".85"/>
    <path d="M100 123v18" stroke="url(#{p}-gold)" stroke-width="2"/>
    <path d="M55 175c25 10 65 10 90 0" stroke="url(#{p}-body)" stroke-width="2" fill="none" opacity=".5"/>
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
    ("fanqie", "番茄", "番茄：跳跳妹妹的忠犬，赤心护主",
     pal("#180c0c", "#281414", "#100808", "#e06040", "#f0c0b0", "#c05038", "#c03820", "#601810", "#c03820"),
     m_fanqie),
    ("bingqiang", "冰墙", "冰墙：雪女冰壁守护者，寒棱不融",
     pal("#0a1418", "#122838", "#081018", "#90c8e8", "#c8e4f0", "#6088a8", "#3080a8", "#183850", "#3080a8"),
     m_bingqiang),
    ("zhiren", "纸人", "纸人：山兔戏谑套索，纸舞捣乱",
     pal("#141008", "#201810", "#0c0a06", "#e8c888", "#f0e0c0", "#c0a070", "#c09040", "#604018", "#c09040"),
     m_zhiren),
    ("yanyanluo-fenshen", "烟烟罗分身", "烟烟罗分身：烟雾散形，瘴蚀真形",
     pal("#100c14", "#181424", "#0a0810", "#b0a0c8", "#d0c8e0", "#8878a8", "#6050a0", "#282050", "#6050a0"),
     m_yanyanluo_fenshen),
    ("jinran-buye", "烬染不夜", "烬染不夜：不知火星火，夜舞余烬",
     pal("#180c08", "#28140c", "#100804", "#f08850", "#f0c0a0", "#c06840", "#d04820", "#702010", "#d04820"),
     m_jinran_buye),
    ("xueqiu-jingling", "雪球精灵", "雪球精灵：雪球集合体，越滚越大",
     pal("#0c1418", "#142838", "#081018", "#c8e0f0", "#e0f0f8", "#90b0c8", "#5090b0", "#204058", "#5090b0"),
     m_xueqiu_jingling),
    ("huangjinyu-ling", "黄金羽灵", "黄金羽灵：以津真天金羽，振翅洒金",
     pal("#141008", "#201810", "#0c0a06", "#e8c050", "#f0e0a0", "#c0a040", "#c09020", "#604810", "#c09020"),
     m_huangjinyu_ling),
    ("mingdeng-shou", "明灯使", "明灯使：青行灯灯灵，引魂长明",
     pal("#14100c", "#201814", "#0c0a08", "#f0d890", "#f0e8c0", "#c0a870", "#c09040", "#604020", "#c09040"),
     m_mingdeng_shou),
    ("xinmo", "心魔", "心魔：觉般若执念，蚀心削志",
     pal("#140810", "#201018", "#0c060c", "#c07090", "#e0b0c0", "#a05878", "#a03058", "#501830", "#a03058"),
     m_xinmo),
    ("shouhu-ling", "守护灵", "守护灵：犬神兵俑信念，永世护主",
     pal("#0c1014", "#141c28", "#080a10", "#90b0c0", "#c0d0d8", "#708898", "#406880", "#183040", "#406880"),
     m_shouhu_ling),
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
