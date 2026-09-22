#!/usr/bin/env python3
"""Generate original stylized SVG portraits for the 25 wave7-pack shikigami.

Style matches assets/wave6/* — ink-night aesthetic, viewBox 0 0 200 260.
Pure original geometry only. Do not use NetEase official art.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "wave7"
W, H = 200, 260


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace('"', "&quot;"))


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
    f = fill or f"url(#{p}-acc)"
    parts = [f'  <g fill="{f}">']
    for x, y, r, o in pts:
        parts.append(f'    <circle cx="{x}" cy="{y}" r="{r}" opacity="{o}"/>')
    parts.append("  </g>")
    return "\n".join(parts)


def pal(bg1, bg2, bg3, halo, body1, body2, acc1, acc2, frame,
        awk_bloom="rgba(255, 233, 178, 0.35)", awk_core="#ff8a3d"):
    return {
        "bg1": bg1, "bg2": bg2, "bg3": bg3, "halo": halo,
        "body1": body1, "body2": body2, "acc1": acc1, "acc2": acc2,
        "frame": frame, "awk_bloom": awk_bloom, "awk_core": awk_core,
    }


# ---------- motif builders (pure original SVG shapes) ----------
# kind: flame | ape | mouth | needle | sword | blade | wind | lamp
#       plume | powder | shell | season | oni | hand | ink | scroll
#       word | lamp2 | hair | wing | petal | breeze | dice

def m_kind(p: str, kind: str) -> str:
    body = f'  <path d="M100 48c22 18 34 40 34 64 0 28-16 48-34 62-18-14-34-34-34-62 0-24 12-46 34-64z" fill="url(#{p}-body)" stroke="url(#{p}-acc)" stroke-width="1.4"/>'
    extras = {
        "flame": f'''
  <path d="M100 62c8 14 14 24 14 36 0 14-6 24-14 32-8-8-14-18-14-32 0-12 6-22 14-36z" fill="url(#{p}-acc)" opacity=".85"/>
  <path d="M78 118c-10 4-16 12-18 22M122 118c10 4 16 12 18 22" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
  <circle cx="100" cy="100" r="8" fill="#ffe0a0" opacity=".7"/>
''',
        "ape": f'''
  <ellipse cx="100" cy="108" rx="28" ry="34" fill="url(#{p}-acc)" opacity=".55"/>
  <circle cx="82" cy="96" r="7" fill="{p and '#f0f0f0'}" opacity=".55"/>
  <circle cx="118" cy="96" r="7" fill="#f0f0f0" opacity=".55"/>
  <path d="M72 78c8-16 48-16 56 0" stroke="url(#{p}-acc)" stroke-width="2.2" fill="none"/>
  <path d="M70 148c10 18 50 18 60 0" stroke="url(#{p}-body)" stroke-width="3" fill="none"/>
''',
        "mouth": f'''
  <path d="M70 110c12 18 48 18 60 0-8 22-52 22-60 0z" fill="url(#{p}-acc)"/>
  <path d="M78 108h44" stroke="#f8e8e8" stroke-width="2" opacity=".7"/>
  <circle cx="86" cy="104" r="3" fill="#fff" opacity=".65"/>
  <circle cx="114" cy="104" r="3" fill="#fff" opacity=".65"/>
  <path d="M88 140c4 10 20 10 24 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
''',
        "needle": f'''
  <path d="M100 40v120M70 90h60M78 120h44" stroke="url(#{p}-acc)" stroke-width="1.8" fill="none"/>
  <circle cx="100" cy="40" r="5" fill="url(#{p}-acc)"/>
  <path d="M64 70l72 40M136 70l-72 40" stroke="url(#{p}-acc)" stroke-width="1.2" opacity=".75"/>
  <circle cx="100" cy="100" r="6" fill="none" stroke="#f0f0f0" stroke-width="1.5"/>
''',
        "sword": f'''
  <path d="M100 36l8 28v70l-8 18-8-18V64z" fill="url(#{p}-acc)"/>
  <path d="M78 88h44M86 72h28" stroke="#e8d8b0" stroke-width="2.5"/>
  <circle cx="100" cy="150" r="7" fill="url(#{p}-body)" stroke="url(#{p}-acc)"/>
  <path d="M64 168c12-10 60-10 72 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
''',
        "blade": f'''
  <path d="M64 70c30-20 62-10 72 18-28 4-52 2-72-18z" fill="url(#{p}-acc)"/>
  <path d="M70 120c24-8 50-6 64 10-22 6-46 4-64-10z" fill="url(#{p}-acc)" opacity=".75"/>
  <path d="M100 48v110" stroke="url(#{p}-body)" stroke-width="2"/>
  <circle cx="100" cy="100" r="5" fill="#f0c8c8" opacity=".7"/>
''',
        "wind": f'''
  <path d="M52 90c20-24 76-24 96 0-28 8-68 8-96 0z" fill="url(#{p}-acc)" opacity=".8"/>
  <path d="M58 120c22-16 62-16 84 0-24 8-60 8-84 0z" fill="url(#{p}-acc)" opacity=".55"/>
  <path d="M70 150c18-12 42-12 60 0-16 6-44 6-60 0z" fill="url(#{p}-acc)" opacity=".4"/>
  <circle cx="100" cy="88" r="8" fill="#f0f8ff" opacity=".55"/>
''',
        "lamp": f'''
  <rect x="88" y="70" width="24" height="50" rx="4" fill="url(#{p}-acc)"/>
  <path d="M100 70c-12-8-12-22 0-30 12 8 12 22 0 30z" fill="#ffe0a0" opacity=".8"/>
  <path d="M78 120h44v8H78zM84 80h32" stroke="#e8c878" stroke-width="2"/>
  <circle cx="100" cy="148" r="10" fill="url(#{p}-body)" stroke="url(#{p}-acc)"/>
''',
        "plume": f'''
  <path d="M100 44c-8 30-8 60 0 90 8-30 8-60 0-90z" fill="url(#{p}-acc)"/>
  <path d="M82 70c-18 20-22 48-10 72M118 70c18 20 22 48 10 72" stroke="url(#{p}-acc)" stroke-width="2.2" fill="none"/>
  <path d="M70 96c-12 8-18 22-16 36M130 96c12 8 18 22 16 36" stroke="url(#{p}-acc)" stroke-width="1.6" fill="none" opacity=".75"/>
  <circle cx="100" cy="148" r="6" fill="#e0fff8" opacity=".65"/>
''',
        "powder": f'''
  <ellipse cx="100" cy="100" rx="36" ry="28" fill="url(#{p}-acc)" opacity=".55"/>
  <path d="M64 100c12 24 60 24 72 0" stroke="url(#{p}-body)" stroke-width="2" fill="none"/>
  <circle cx="78" cy="88" r="5" fill="#f8d0e0" opacity=".7"/>
  <circle cx="122" cy="88" r="5" fill="#f8d0e0" opacity=".7"/>
  <path d="M86 130c8 14 20 14 28 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
''',
        "shell": f'''
  <path d="M60 120c0-34 18-56 40-56s40 22 40 56c0 20-16 36-40 36s-40-16-40-36z" fill="url(#{p}-acc)" opacity=".65"/>
  <path d="M72 118c8-22 48-22 56 0" stroke="#d0f0ff" stroke-width="1.8" fill="none" opacity=".7"/>
  <circle cx="100" cy="118" r="10" fill="url(#{p}-body)" stroke="#b0e0ff"/>
  <path d="M88 70c4-14 20-14 24 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
''',
        "season": f'''
  <circle cx="100" cy="100" r="34" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
  <path d="M100 66v34l24 14" stroke="url(#{p}-acc)" stroke-width="2.2" fill="none"/>
  <circle cx="72" cy="72" r="7" fill="#a0e0a0" opacity=".7"/>
  <circle cx="128" cy="72" r="7" fill="#f0a060" opacity=".7"/>
  <circle cx="72" cy="128" r="7" fill="#e0c060" opacity=".7"/>
  <circle cx="128" cy="128" r="7" fill="#a0c0f0" opacity=".7"/>
''',
        "oni": f'''
  <path d="M78 70c8-18 36-18 44 0l8 20H70z" fill="url(#{p}-acc)"/>
  <path d="M70 96h60l-8 40H78z" fill="url(#{p}-body)" stroke="url(#{p}-acc)"/>
  <circle cx="88" cy="110" r="4" fill="#ffe080"/>
  <circle cx="112" cy="110" r="4" fill="#ffe080"/>
  <path d="M84 130h32M88 138h24" stroke="#201010" stroke-width="2"/>
  <path d="M74 58l-8-16M126 58l8-16" stroke="url(#{p}-acc)" stroke-width="3"/>
''',
        "hand": f'''
  <path d="M100 58c8 0 14 8 14 18v36c0 8-6 14-14 14s-14-6-14-14V76c0-10 6-18 14-18z" fill="url(#{p}-acc)"/>
  <path d="M86 88V70M114 88V72M78 100V84M122 100V86" stroke="url(#{p}-acc)" stroke-width="5" stroke-linecap="round"/>
  <path d="M84 128c8 18 24 18 32 0" stroke="url(#{p}-body)" stroke-width="2.5" fill="none"/>
''',
        "ink": f'''
  <path d="M100 48c14 20 22 40 22 58 0 18-10 30-22 38-12-8-22-20-22-38 0-18 8-38 22-58z" fill="url(#{p}-acc)"/>
  <path d="M78 150h44M86 162h28" stroke="url(#{p}-acc)" stroke-width="3" stroke-linecap="round"/>
  <circle cx="100" cy="96" r="6" fill="#f0f0f8" opacity=".7"/>
  <path d="M68 80c-8 20-6 40 4 54M132 80c8 20 6 40-4 54" stroke="url(#{p}-acc)" stroke-width="1.6" fill="none" opacity=".7"/>
''',
        "scroll": f'''
  <rect x="72" y="60" width="56" height="90" rx="3" fill="url(#{p}-body)" stroke="url(#{p}-acc)"/>
  <path d="M84 80h32M84 96h32M84 112h24M84 128h28" stroke="url(#{p}-acc)" stroke-width="1.8"/>
  <path d="M72 60c-8 0-8 8 0 8M128 150c8 0 8-8 0-8" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
''',
        "word": f'''
  <circle cx="100" cy="100" r="36" fill="none" stroke="url(#{p}-acc)" stroke-width="2"/>
  <path d="M84 88h32M84 104h32M90 120h20" stroke="url(#{p}-acc)" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M64 70l16 12M136 70l-16 12M64 130l16-12M136 130l-16-12" stroke="url(#{p}-acc)" stroke-width="1.5"/>
''',
        "lamp2": f'''
  <path d="M100 52c18 12 28 32 28 52 0 24-12 42-28 54-16-12-28-30-28-54 0-20 10-40 28-52z" fill="url(#{p}-acc)" opacity=".55"/>
  <circle cx="100" cy="100" r="14" fill="#fff2c0" opacity=".75"/>
  <path d="M100 70v-16M84 124h32" stroke="url(#{p}-acc)" stroke-width="2"/>
''',
        "hair": f'''
  <path d="M56 110c20-40 68-40 88 0-20 8-68 8-88 0z" fill="url(#{p}-acc)"/>
  <path d="M64 128c18-20 54-20 72 0" stroke="url(#{p}-acc)" stroke-width="2.5" fill="none"/>
  <path d="M72 148c16-12 40-12 56 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none" opacity=".7"/>
  <circle cx="100" cy="100" r="5" fill="#f0d0e0" opacity=".7"/>
''',
        "wing": f'''
  <path d="M100 70c-30-20-50-8-54 18 22 4 42 2 54-18z" fill="url(#{p}-acc)"/>
  <path d="M100 70c30-20 50-8 54 18-22 4-42 2-54-18z" fill="url(#{p}-acc)"/>
  <path d="M100 70v70" stroke="url(#{p}-body)" stroke-width="3"/>
  <path d="M78 130c10 16 34 16 44 0" stroke="url(#{p}-acc)" stroke-width="2" fill="none"/>
''',
        "petal": f'''
  <circle cx="100" cy="100" r="12" fill="#ffe0a8"/>
  <ellipse cx="100" cy="72" rx="12" ry="22" fill="url(#{p}-acc)" opacity=".8"/>
  <ellipse cx="100" cy="128" rx="12" ry="22" fill="url(#{p}-acc)" opacity=".8"/>
  <ellipse cx="72" cy="100" rx="22" ry="12" fill="url(#{p}-acc)" opacity=".8"/>
  <ellipse cx="128" cy="100" rx="22" ry="12" fill="url(#{p}-acc)" opacity=".8"/>
''',
        "breeze": f'''
  <path d="M60 88c24-8 56-8 80 4M70 116c20-6 44-6 62 2M80 144c14-4 30-4 42 2" stroke="url(#{p}-acc)" stroke-width="2.4" fill="none" stroke-linecap="round"/>
  <circle cx="100" cy="100" r="8" fill="url(#{p}-acc)" opacity=".7"/>
  <path d="M100 48c-6 14-6 28 0 42 6-14 6-28 0-42z" fill="url(#{p}-acc)" opacity=".65"/>
''',
        "dice": f'''
  <rect x="74" y="74" width="52" height="52" rx="8" fill="url(#{p}-acc)" stroke="#f0d080"/>
  <circle cx="88" cy="88" r="4" fill="#201810"/>
  <circle cx="112" cy="88" r="4" fill="#201810"/>
  <circle cx="100" cy="100" r="4" fill="#201810"/>
  <circle cx="88" cy="112" r="4" fill="#201810"/>
  <circle cx="112" cy="112" r="4" fill="#201810"/>
  <path d="M100 48v16M100 148v16" stroke="url(#{p}-acc)" stroke-width="2"/>
''',
    }
    spark = dots(p, [(40, 80, 1.8, ".55"), (160, 84, 1.6, ".5"), (48, 160, 1.5, ".45"),
                     (152, 164, 1.8, ".5"), (100, 36, 1.4, ".4"), (100, 190, 1.6, ".45")])
    return body + "\n" + extras.get(kind, "") + "\n" + spark


UNITS = [
    # 燃灯志异
    ("gulonghuo", "古笼火", "古笼火：鬼火灯笼，歧路燃尽",
     pal("#180c08", "#28140c", "#100804", "#f0a050", "#f0d0a8", "#d08848", "#d05818", "#702810", "#d05818"), "flame"),
    ("chuanyuan", "川猿", "川猿：百相猿面，变幻自在",
     pal("#0c1410", "#142018", "#080e0a", "#a0c0b0", "#d0e8d8", "#88a898", "#50a080", "#204838", "#50a080"), "ape"),
    ("erkounv", "二口女", "二口女：血口双唇，充能附体",
     pal("#140c12", "#20141c", "#0c080c", "#e08090", "#f0c8d0", "#c07080", "#c04060", "#601830", "#c04060"), "mouth"),
    ("xiaoxiuzhishou", "小袖之手", "小袖之手：纫针丝缕，千针直击",
     pal("#120c14", "#1c1424", "#0c0810", "#d0a0c0", "#e8d0e0", "#a880a0", "#a04888", "#502040", "#a04888"), "needle"),
    ("quanshen-lizhan", "犬神·历战", "犬神·历战：心剑道场，历战传业",
     pal("#14100c", "#201814", "#0c0a08", "#c09070", "#e8d0b8", "#a88068", "#a06040", "#503020", "#a06040"), "sword"),
    ("yaodaoji-zhuren", "妖刀姬·呪刃", "妖刀姬·呪刃：呪刃妖刀，直击连斩",
     pal("#140810", "#20101c", "#0c060c", "#e07070", "#f0c0c0", "#c06868", "#c02828", "#601010", "#c02828"), "blade"),
    ("datiangou-gangfeng", "大天狗·钢风", "大天狗·钢风：钢羽风神，起源再临",
     pal("#0c1018", "#141c30", "#080a12", "#90a0d0", "#d0d8f0", "#8890c0", "#5060a0", "#202850", "#5060a0"), "wind"),
    ("qingxingdeng-huihuo", "青行灯·辉火", "青行灯·辉火：辉灯夜话，百闻长明",
     pal("#141008", "#20180c", "#0c0a04", "#f0c060", "#f8e8a8", "#d0b050", "#d0a020", "#705010", "#d0a020"), "lamp"),
    # 尘世轮回
    ("kongquemingwang", "孔雀明王", "孔雀明王：翎羽破甲，祈神流羽",
     pal("#081410", "#10241c", "#06100c", "#40c0a0", "#b0e8d8", "#60a088", "#30a080", "#184840", "#30a080"), "plume"),
    ("fenpopo", "粉婆婆", "粉婆婆：画颜烟粉，过量投射",
     pal("#140c14", "#201424", "#0c0810", "#f0a0c0", "#f8d0e0", "#c080a0", "#c05080", "#602040", "#c05080"), "powder"),
    ("jiao", "椒图", "椒图：明珠涌流，护主分担",
     pal("#081418", "#102430", "#061014", "#60b0e0", "#b0e0f0", "#60a0c0", "#3080b0", "#184058", "#3080b0"), "shell"),
    ("ji", "季", "季：四时轮转，华落重生",
     pal("#0c140c", "#142014", "#080e08", "#a0d080", "#d8e8c0", "#88a868", "#50a040", "#204820", "#50a040"), "season"),
    ("jutun-wangkong", "酒吞童子·忘空", "酒吞童子·忘空：忘空残血，灭道殉神",
     pal("#140808", "#201010", "#0c0606", "#d06050", "#f0b0a0", "#b05848", "#c03020", "#601010", "#c03020"), "oni"),
    ("caitong-lvli", "茨木童子·旅立", "茨木童子·旅立：鬼蚀之手，旅立登程",
     pal("#140c08", "#201410", "#0c0806", "#e08040", "#f0c8a0", "#c08050", "#c05020", "#602810", "#c05020"), "hand"),
    ("qingfangzhu-fanchen", "青坊主·凡尘", "青坊主·凡尘：佛心渡魂，垢去明存",
     pal("#14120c", "#201c14", "#0c0a08", "#c0b080", "#e8e0b8", "#a89870", "#a08040", "#504020", "#a08040"), "scroll"),
    ("panguan-xuanmo", "判官·悬墨", "判官·悬墨：悬墨勾魂，生死落笔",
     pal("#0c1014", "#141c24", "#080c10", "#8090a0", "#c8d0d8", "#808898", "#506070", "#202830", "#506070"), "ink"),
    # 桃源故里
    ("langyazi", "琅琊子", "琅琊子：咒诀寐印，桃源永生",
     pal("#120c18", "#1c1430", "#0c0810", "#b090d0", "#e0d0f0", "#9078b0", "#8050b0", "#382068", "#8050b0"), "scroll"),
    ("yanling", "言灵", "言灵：语罪真言，反制授言",
     pal("#0c0c18", "#141430", "#080810", "#9090e0", "#d0d0f8", "#8080c0", "#5050b0", "#202060", "#5050b0"), "word"),
    ("huimingdeng", "慧明灯", "慧明灯：坚守明灯，业障灯明",
     pal("#141008", "#201810", "#0c0a06", "#f0d080", "#f8e8b8", "#d0b060", "#d0a030", "#705018", "#d0a030"), "lamp2"),
    ("shifagui", "食发鬼", "食发鬼：发鬼战力，真实之颜",
     pal("#140c14", "#201420", "#0c080c", "#c080a0", "#e8c0d8", "#a87090", "#a04070", "#502040", "#a04070"), "hair"),
    ("tiannimei", "天逆每", "天逆每：惧翼恐惧，惧刃蔓延",
     pal("#120818", "#1c1030", "#0a0610", "#a070c0", "#d8c0f0", "#8860a0", "#8040c0", "#381868", "#8040c0"), "wing"),
    ("guniao-yuxiang", "姑获鸟·玉响", "姑获鸟·玉响：玉响伞阵，回天之翼",
     pal("#14100c", "#201814", "#0c0a08", "#e0b090", "#f0d8c0", "#c0a080", "#c08050", "#604028", "#c08050"), "wing"),
    ("taohua-luoying", "桃花妖·落英", "桃花妖·落英：落英战力，桃运坚毅",
     pal("#140c10", "#201418", "#0c080c", "#f0a0b0", "#f8d0d8", "#c08090", "#c05068", "#602030", "#c05068"), "petal"),
    ("yimulian-linglai", "一目连·灵籁", "一目连·灵籁：灵籁风符，风神之佑",
     pal("#081418", "#102430", "#061014", "#80c0d0", "#c0e8f0", "#70a0b0", "#4080a0", "#184050", "#4080a0"), "breeze"),
    ("shantu-zuofu", "山兔/座敷童子", "山兔/座敷童子：如意骰子，黄金六曜",
     pal("#141008", "#20180c", "#0c0a04", "#f0c070", "#f8e0a8", "#d0a850", "#d08820", "#704810", "#d08820"), "dice"),
]


def build(uid: str, title: str, desc: str, palette: dict, kind: str, awakened: bool) -> str:
    p = uid.replace("-", "")
    body = m_kind(p, kind)
    return shell(uid, title, desc, body, palette, awakened)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for uid, title, desc, palette, kind in UNITS:
        for awk in (False, True):
            name = f"{uid}-awakened.svg" if awk else f"{uid}.svg"
            svg = build(uid, title, desc, palette, kind, awk)
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
