#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave7.js（燃灯·尘世·桃源，25 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id、式神卡。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave7.js"

# (uid, role, name, title, archetype, color, strategy, subpack)
UNITS = [
    # 燃灯志异 ranmeng
    ("gulonghuo", 293, "古笼火", "鬼火", "复活 / 投射", "#f0a050", "气绝投射补刀，复活叠伤终击。", "ranmeng"),
    ("chuanyuan", 294, "川猿", "百相", "变幻 / 成长", "#a0c0b0", "互换攻守身板，仿模取极连打。", "ranmeng"),
    ("erkounv", 295, "二口女", "血口", "充能 / 专注", "#e08090", "充能代专注，附体血口追猎。", "ranmeng"),
    ("xiaoxiuzhishou", 296, "小袖之手", "纫针", "投射 / 破甲", "#d0a0c0", "伤式神连打牌手，千针点杀。", "ranmeng"),
    ("quanshen-lizhan", 292, "犬神·历战", "心剑", "成长 / 团辅", "#c09070", "升级叠力传业，心流道场辅攻。", "ranmeng"),
    ("yaodaoji-zhuren", 289, "妖刀姬·呪刃", "呪刃", "直击 / 觉醒", "#e07070", "打脸抽专属，呪刃切换连斩。", "ranmeng"),
    ("datiangou-gangfeng", 290, "大天狗·钢风", "钢风", "起源 / 连击", "#90a0d0", "战斗回起源，钢风倒计时再临。", "ranmeng"),
    ("qingxingdeng-huihuo", 291, "青行灯·辉火", "辉火", "召唤 / 过牌", "#f0c060", "三类出牌召辉灯，灯火长明。", "ranmeng"),
    # 尘世轮回 chenshi
    ("kongquemingwang", 605, "孔雀明王", "翎羽", "破甲 / 迅捷", "#40c0a0", "孔雀翎叠破甲，祈舞反击。", "chenshi"),
    ("fenpopo", 603, "粉婆婆", "画颜", "过量治疗 / 投射", "#f0a0c0", "过量治疗转投射，粉盒续航。", "chenshi"),
    ("jiao", 606, "椒图", "涌流", "护主 / 生命精华", "#60b0e0", "分担牌手伤害，明珠反击。", "chenshi"),
    ("ji", 604, "季", "四时", "形态 / 轮转", "#a0d080", "四时牌轮转进场离场，华落重生。", "chenshi"),
    ("jutun-wangkong", 602, "酒吞童子·忘空", "忘空", "不屈 / 爆发", "#d06050", "残血叠力不屈，灭道殉神。", "chenshi"),
    ("caitong-lvli", 607, "茨木童子·旅立", "旅立", "召唤 / 追猎", "#e08040", "攻击召鬼蚀之手，炼狱道。", "chenshi"),
    ("qingfangzhu-fanchen", 299, "青坊主·凡尘", "凡尘", "治疗 / 生命精华", "#c0b080", "受伤得精华，佛心过量转攻。", "chenshi"),
    ("panguan-xuanmo", 601, "判官·悬墨", "悬墨", "消灭 / 复活", "#8090a0", "敌绝得精华，落笔归魂控场。", "chenshi"),
    # 桃源故里 taoyuan
    ("langyazi", 615, "琅琊子", "咒诀", "咒印 / 消灭", "#b090d0", "出牌召寐咒，诀印锁敌。", "taoyuan"),
    ("yanling", 614, "言灵", "语罪", "反制 / 眩晕", "#9090e0", "语罪触发反制眩晕，真言道。", "taoyuan"),
    ("huimingdeng", 608, "慧明灯", "明灯", "坚守 / 战力", "#f0d080", "受战伤坚守入场，业障叠力。", "taoyuan"),
    ("shifagui", 609, "食发鬼", "发鬼", "战力 / 乏力", "#c080a0", "回合叠战力，发鞭削敌。", "taoyuan"),
    ("tiannimei", 611, "天逆每", "惧翼", "恐惧 / 成长", "#a070c0", "结附恐惧收惧翼，惧刃斩杀。", "taoyuan"),
    ("guniao-yuxiang", 610, "姑获鸟·玉响", "玉响", "坚守 / 机动", "#e0b090", "坚守叠战力，被攻即撤。", "taoyuan"),
    ("taohua-luoying", 612, "桃花妖·落英", "落英", "战力 / 团辅", "#f0a0b0", "叠战力坚毅护体，春风笑收割。", "taoyuan"),
    ("yimulian-linglai", 613, "一目连·灵籁", "灵籁", "眩晕 / 风符", "#80c0d0", "眩晕触发风符·守，风雷谷。", "taoyuan"),
    ("shantu-zuofu", 616, "山兔/座敷童子", "如意", "运势 / 衍生", "#f0c070", "运势得如意骰子，黄金六曜。", "taoyuan"),
]

ROLE_TO_UID = {role: uid for uid, role, *_ in UNITS}
OID_UNIT_OVERRIDE: dict[int, str] = {}

RARITY = {"R": "R", "SR": "SR", "SSR": "SSR", None: "R", "": "R", "N": "R", "SKIN": "R"}
TYPE = {"战斗": "combat", "法术": "spell", "形态": "form", "式神": None, "结界": "realm", "觉醒": "awakening", "衍生": "spell", "协战": None}


def slug(text: str) -> str:
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "card"


def unit_of(oid: int) -> str:
    if oid in OID_UNIT_OVERRIDE:
        return OID_UNIT_OVERRIDE[oid]
    return ROLE_TO_UID[oid // 100]


def C(name, type, level, cost, rarity, starter, text, effects, **kw):
    d = dict(name=name, type=type, level=level, cost=cost, rarity=rarity,
             starter=starter, text=text, effects=effects, deck_limit=kw.pop("deck_limit", 2))
    d.update(kw)
    return d


def F(atk, hp):
    return {"attack": atk, "hp": hp}


# 手写映射：每人 8 张可构筑牌（跳过式神卡、SKIN、空协战）
# 简化原则同 wave6；officialText 保留原文。starter 合计=8，SSR starter≤1，觉醒恰好 1 张。
CARD_MAP: dict[int, dict] = {
    # ---- 古笼火 293 ----
    29301: C("引路火苗", "spell", 1, 0, "R", 1,
             "瞬发。气绝时可用：复活古笼火，并使其生命变为 1（简化为复活）。",
             [("always", "revive", "source", 1)],
             keywords=["INSTANT"], tags=["瞬发", "复活", "投射"]),
    29302: C("恶戏之火", "combat", 1, 1, "R", 1,
             "出击 +2。专注简化：本次攻击额外 +1 力量。",
             [("source-ready", "assault", "source", 3)],
             tags=["出击", "专注", "投射"]),
    29303: C("燃尽", "spell", 1, 1, "SR", 1,
             "消灭古笼火简化：古笼火受到 3 点伤害，并对所有敌方式神造成 2 点伤害。",
             [("always", "damage", "source", 3), ("always", "damage", "all-enemy-units", 2)],
             tags=["消灭", "群伤", "投射"]),
    29304: C("飘摇鬼火", "form", 2, 1, "R", 2,
             "获得 +2/+2。受到伤害后，获得 1 点力量（运势简化）。",
             [("always", "form", "source", F(2, 2))],
             formAbility="受到伤害后，古笼火获得 1 点力量。",
             formHooks=[{"id": "form-gulong-sway", "event": "unit-damaged", "effect": "passive-buff-self-on-damaged", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "运势", "投射"]),
    29305: C("觉醒·古笼火", "awakening", 2, 1, "SR", 1,
             "气绝时可用：复活古笼火。觉醒：+1/+2，气绝投射改为 3 点。",
             [("always", "awaken", "source", F(1, 2)), ("always", "revive", "source", 1)],
             deck_limit=1, tags=["觉醒", "复活", "投射"]),
    29306: C("火风车", "combat", 2, 1, "R", 1,
             "出击 +3。追猎简化：对随机敌方造成 1 点伤害。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "all-enemy-units", 1)],
             tags=["出击", "追猎", "投射"]),
    29307: C("灵运", "realm", 3, 1, "SR", 0,
             "幻境（耐久 6）：己方回合开始时，为所有己方式神恢复 2 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "复活", "团辅"]),
    29308: C("歧路笼火", "spell", 3, 2, "SSR", 0,
             "对敌方牌手和所有式神各造成 3 点伤害（蓄力简化）。",
             [("always", "damage", "enemy-avatar", 3), ("always", "damage", "all-enemy-units", 3)],
             deck_limit=2, tags=["蓄力", "群伤", "终结"]),

    # ---- 川猿 294 ----
    29401: C("变幻自在", "spell", 1, 0, "R", 1,
             "瞬发。川猿获得 +1/+1，并抽一张牌（互换简化）。",
             [("always", "buff-stats", "source", F(1, 1)), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "变幻", "过牌"]),
    29402: C("猿形毕露", "spell", 1, 1, "SR", 1,
             "使一个敌方式神 -2 力量，并为川猿恢复 2 点生命（互换简化）。",
             [("always", "debuff-stats", "selected-enemy", F(2, 0)), ("always", "heal", "source", 2)],
             tags=["变幻", "削弱", "治疗"]),
    29403: C("仿模", "combat", 1, 1, "R", 2,
             "出击 +2。选择一项简化：川猿获得 +1/+1。",
             [("source-ready", "assault", "source", 2), ("always", "buff-stats", "source", F(1, 1))],
             tags=["出击", "变幻", "复制"]),
    29404: C("花纸散", "spell", 2, 1, "SR", 1,
             "对一个敌方式神造成 4 点伤害，并为川猿恢复 3 点生命。",
             [("always", "damage", "selected-enemy", 4), ("always", "heal", "source", 3)],
             tags=["伤害", "治疗", "变幻"]),
    29405: C("诸象皆流", "spell", 3, 2, "SSR", 0,
             "所有己方式神获得 +2/+2（互换极值简化）。",
             [("always", "buff-stats", "all-ally-units", F(2, 2))],
             deck_limit=2, tags=["变幻", "团辅", "终结"]),
    29406: C("觉醒·川猿", "awakening", 2, 1, "R", 1,
             "抽一张牌。觉醒：+1/+2，回合开始获得 +1/+1。",
             [("always", "awaken", "source", F(1, 2)), ("always", "draw", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "变幻", "过牌"]),
    29407: C("天衣无缝", "combat", 3, 1, "R", 1,
             "出击 +3。追猎：获得 2 点护甲。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
             tags=["出击", "追猎", "变幻"]),
    29408: C("猿猴夺月", "form", 3, 1, "SR", 1,
             "获得 +3/+3。己方回合开始时，川猿获得 +1/+1。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，川猿获得 +1/+1。",
             formHooks=[{"id": "form-yuan-moon", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
             tags=["形态", "变幻", "成长"]),

    # ---- 二口女 295 ----
    29501: C("意外收获", "combat", 1, 0, "R", 2,
             "出击 +1。专注：抽一张牌。",
             [("source-ready", "assault", "source", 1), ("always", "draw", "ally-player", 1)],
             tags=["出击", "专注", "过牌"]),
    29502: C("附体", "form", 1, 1, "R", 1,
             "获得 +1/+2。专注：永久 +1/+1 并入面板。",
             [("always", "form", "source", F(2, 3))],
             tags=["形态", "专注", "充能"]),
    29503: C("恐惧", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，随机己方 +1 力量（简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 0},
             deck_limit=2, tags=["幻境", "专注", "充能"]),
    29504: C("血口", "combat", 2, 1, "R", 1,
             "出击 +3。追猎。专注：获得不屈。",
             [("source-ready", "assault", "source", 3), ("always", "grant-unyielding", "source", 1)],
             keywords=["UNYIELDING"], tags=["出击", "追猎", "不屈"]),
    29505: C("觉醒·二口女", "awakening", 2, 1, "SR", 1,
             "瞬发。获得 1 点能量并投射 2 点。觉醒：+1/+2，充能升级。",
             [("always", "awaken", "source", F(1, 2)), ("always", "energy-gain", "ally-player", 1), ("always", "damage-enemy-front", "auto", 2)],
             keywords=["INSTANT"], deck_limit=1, tags=["觉醒", "充能", "专注"]),
    29506: C("共生", "form", 2, 2, "SSR", 0,
             "获得 +3/+3。完成交战后，抽一张牌（专注随机简化）。",
             [("always", "form", "source", F(3, 3))],
             formAbility="完成交战后，抽一张牌。",
             formHooks=[{"id": "form-er-symb", "event": "combat-resolved", "effect": "passive-draw-self", "params": {"count": 1}, "priority": 40}],
             deck_limit=2, tags=["形态", "充能", "专注"]),
    29507: C("歉意", "combat", 3, 1, "SR", 1,
             "瞬发。出击 +1，并对所有敌方角色造成 2 点伤害。",
             [("source-ready", "assault", "source", 1), ("always", "damage", "all-enemy-units", 2), ("always", "damage", "enemy-avatar", 2)],
             keywords=["INSTANT"], tags=["瞬发", "群伤", "专注"]),
    29508: C("妖噬", "spell", 3, 1, "R", 1,
             "对一个敌方式神造成 6 点伤害。专注简化：额外 2 点。",
             [("always", "damage", "selected-enemy", 6), ("always", "damage", "selected-enemy", 2)],
             tags=["伤害", "专注", "终结"]),

    # ---- 小袖之手 296 ----
    29601: C("纫针", "spell", 1, 0, "R", 2,
             "瞬发。对一个敌方式神造成 2 点伤害，并对敌方牌手造成 1 点伤害。",
             [("always", "damage", "selected-enemy", 2), ("always", "damage", "enemy-avatar", 1)],
             keywords=["INSTANT"], tags=["瞬发", "伤害", "投射"]),
    29602: C("缝补", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害（咒缚简化）。",
             [("always", "damage", "selected-enemy", 4)],
             tags=["伤害", "咒缚", "投射"]),
    29603: C("补缀添香", "form", 1, 1, "R", 1,
             "获得 +2/+3。使用法术牌后，随机敌方 -1 力量（简化为回合触发）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，随机敌方 -1 力量。",
             formHooks=[{"id": "form-xiu-patch", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "投射", "召唤"]),
    29604: C("绵里藏针", "spell", 2, 1, "SR", 1,
             "使一个敌方式神 -2/-2，并对其造成 3 点伤害。",
             [("always", "debuff-stats", "selected-enemy", F(2, 2)), ("always", "damage", "selected-enemy", 3)],
             tags=["削弱", "伤害", "投射"]),
    29605: C("丝缕相连", "form", 2, 1, "SR", 2,
             "获得 +2/+3。己方回合开始时，随机对敌方造成 1 点伤害。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-xiu-thread", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "投射", "召唤"]),
    29606: C("穿针引线", "spell", 2, 1, "SSR", 0,
             "瞬发。对一个敌方式神造成 3 点伤害并获得 2 点破甲。",
             [("always", "damage", "selected-enemy", 3), ("always", "apply-armor-break", "selected-enemy", 2)],
             keywords=["INSTANT"], deck_limit=2, tags=["瞬发", "破甲", "投射"]),
    29607: C("千针刺", "spell", 3, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害，重复 2 次（原 4 次简化）。",
             [("always", "damage", "selected-enemy", 3), ("always", "damage", "selected-enemy", 3)],
             tags=["伤害", "投射", "终结"]),
    29608: C("觉醒·小袖之手", "awakening", 3, 1, "SR", 1,
             "随机对两个敌方式神造成 2 点伤害。觉醒：+1/+2，伤式神连打牌手 2 点。",
             [("always", "awaken", "source", F(1, 2)), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=1, tags=["觉醒", "投射", "伤害"]),

    # ---- 犬神·历战 292 ----
    29201: C("心剑", "combat", 1, 1, "R", 2,
             "出击 +2。起源简化：再获得 +1 力量。",
             [("source-ready", "assault", "source", 3)],
             keywords=["ORIGIN"], tags=["出击", "起源", "成长"]),
    29202: C("传业授道", "form", 1, 1, "R", 1,
             "获得 +1/+3。进场简化：其他己方 +1/+1 并入回合触发。",
             [("always", "form", "source", F(1, 3))],
             formAbility="己方回合开始时，其他己方式神获得 1 点力量。",
             formHooks=[{"id": "form-quan-teach", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1, "hp": 0}, "priority": 40}],
             tags=["形态", "团辅", "成长"]),
    29203: C("心流道场", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌（攻击加力简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "团辅", "成长"]),
    29204: C("无心斩", "combat", 2, 1, "R", 1,
             "出击 +2。追猎。眩晕被攻击的式神。",
             [("source-ready", "assault", "source", 2), ("always", "freeze", "selected-enemy", 1)],
             keywords=["STUN"], tags=["出击", "追猎", "眩晕"]),
    29205: C("固守之誓", "form", 2, 1, "SR", 1,
             "获得 +2/+4。受到伤害后，获得 2 点护甲。",
             [("always", "form", "source", F(2, 4))],
             formAbility="受到伤害后，犬神·历战获得 2 点护甲。",
             formHooks=[{"id": "form-quan-oath", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "守护", "护甲"]),
    29206: C("为师之道", "combat", 2, 1, "SR", 1,
             "出击 +2。犬神·历战与其他己方各 +1/+1。",
             [("source-ready", "assault", "source", 2), ("always", "buff-stats", "all-ally-units", F(1, 1))],
             tags=["出击", "团辅", "成长"]),
    29207: C("免许皆传", "spell", 3, 1, "R", 1,
             "使一个己方其他式神永久 +2/+2，并使其发起攻击简化：自身出击。",
             [("always", "buff-stats", "all-other-allies", F(2, 2)), ("source-ready", "assault", "source", 2)],
             tags=["团辅", "出击", "成长"]),
    29208: C("往昔之日", "awakening", 3, 2, "SSR", 1,
             "觉醒：+2/+2，回合结束获得 1 点力量与护甲。战斗牌瞬发简化为面板。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "source", F(1, 1)), ("always", "shield", "source", 1)],
             deck_limit=1, tags=["觉醒", "起源", "成长"]),

    # ---- 妖刀姬·呪刃 289 ----
    28901: C("呪刃之血", "combat", 1, 1, "SR", 1,
             "出击 +2。复活妖刀姬·呪刃，并对敌方牌手造成 1 点伤害。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 1), ("always", "revive", "source", 1)],
             tags=["出击", "直击", "复活"]),
    28902: C("呪刃·噬", "awakening", 1, 1, "R", 1,
             "出击 +2。觉醒：+1/+2，对敌方牌手造成伤害后抽一张牌。",
             [("always", "awaken", "source", F(1, 2)), ("source-ready", "assault", "source", 2)],
             deck_limit=1, keywords=["ORIGIN"], tags=["觉醒", "直击", "呪刃"]),
    28903: C("呪刃·御", "combat", 1, 1, "SR", 1,
             "出击 +1。起源见切：获得 2 点护甲。",
             [("source-ready", "assault", "source", 1), ("always", "shield", "source", 2)],
             keywords=["ORIGIN"], tags=["出击", "护甲", "呪刃"]),
    28904: C("呪刃·疾", "combat", 2, 1, "R", 2,
             "出击 +3。起源战意：获得迅捷简化为先攻。",
             [("source-ready", "assault", "source", 3)],
             keywords=["ORIGIN", "FIRST_STRIKE"], tags=["出击", "迅捷", "呪刃"]),
    28905: C("呪刃·隐", "combat", 2, 1, "R", 1,
             "出击 +2。起源一闪：若目标生命≤2，必杀简化为暴击。",
             [("source-ready", "assault", "source", 2)],
             keywords=["ORIGIN", "CRIT"], tags=["出击", "暴击", "呪刃"]),
    28906: C("呪刃散华", "form", 1, 1, "SSR", 0,
             "获得 +2/+2。迅捷。气绝后复活并 +1 力量（切换简化）。",
             [("always", "form", "source", F(2, 2))],
             formAbility="完成交战后，妖刀姬·呪刃获得 1 点力量。",
             formHooks=[{"id": "form-yao-bloom", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             deck_limit=2, tags=["形态", "呪刃", "直击"]),
    28907: C("妖刀烬战", "spell", 3, 1, "R", 1,
             "抽两张牌，并使妖刀姬·呪刃获得 +1 力量。",
             [("always", "draw", "ally-player", 2), ("always", "buff-stats", "source", F(1, 0))],
             tags=["过牌", "呪刃", "强化"]),
    28908: C("无尽刃狱", "realm", 3, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "呪刃", "终结"]),

    # ---- 大天狗·钢风 290 ----
    29001: C("风神迅袭", "combat", 1, 1, "R", 2,
             "出击 +2。起源：风神一扇。",
             [("source-ready", "assault", "source", 2)],
             keywords=["ORIGIN"], tags=["出击", "起源", "钢风"]),
    29002: C("叶隐", "spell", 1, 0, "R", 1,
             "瞬发。移动简化：大天狗·钢风获得 2 点护甲，并抽一张牌。",
             [("always", "shield", "source", 2), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "移动", "过牌"]),
    29003: C("御风之主", "form", 1, 1, "SR", 1,
             "获得 +2/+2。己方回合结束简化：回合开始为自身 2 点护甲。",
             [("always", "form", "source", F(2, 2))],
             formAbility="己方回合开始时，大天狗·钢风获得 2 点护甲。",
             formHooks=[{"id": "form-tengu-lord", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "护甲", "钢风"]),
    29004: C("天狗风烈", "combat", 2, 1, "R", 1,
             "出击 +3。起源天狗风乱。连击简化为额外 1 点出击。",
             [("source-ready", "assault", "source", 4)],
             keywords=["ORIGIN", "COMBO"], tags=["出击", "连击", "钢风"]),
    29005: C("钢羽之刃", "combat", 2, 1, "R", 1,
             "出击 +2。追猎，先攻。",
             [("source-ready", "assault", "source", 2)],
             keywords=["ORIGIN", "FIRST_STRIKE"], tags=["出击", "追猎", "钢风"]),
    29006: C("天狗的正义", "form", 2, 1, "SR", 2,
             "获得 +3/+3。使用法术牌后获得护甲简化：回合开始 1 点护甲。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，大天狗·钢风获得 1 点护甲并抽一张牌。",
             formHooks=[
                 {"id": "form-tengu-just-a", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40},
                 {"id": "form-tengu-just-b", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
             ],
             tags=["形态", "护甲", "钢风"]),
    29007: C("暴风迫临", "combat", 3, 1, "R", 1,
             "出击 +3。起源羽刃暴风。对敌方牌手造成 2 点伤害。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 2)],
             keywords=["ORIGIN"], tags=["出击", "直击", "钢风"]),
    29008: C("龙卷蔽空", "awakening", 3, 2, "SSR", 1,
             "觉醒：+2/+2，己方回合开始时对敌方前线造成 2 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 2)],
             deck_limit=1, tags=["觉醒", "起源", "钢风"]),

    # ---- 青行灯·辉火 291 ----
    29101: C("夜火辉耀", "spell", 1, 0, "R", 2,
             "瞬发。对一个式神造成 2 点伤害。专注：伤害 +2 简化为 3 点。",
             [("always", "damage", "selected-enemy", 3)],
             keywords=["INSTANT"], tags=["瞬发", "伤害", "辉火"]),
    29102: C("燃灯夜话", "spell", 1, 1, "R", 1,
             "占卜 1 并抽一张牌（检视简化）。",
             [("always", "divination", "ally-player", 1), ("always", "draw", "ally-player", 1)],
             tags=["过牌", "占卜", "辉火"]),
    29103: C("叙话成书", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "过牌", "辉火"]),
    29104: C("夜灯余晖", "spell", 2, 1, "R", 1,
             "抽两张牌（瞬发手牌简化）。",
             [("always", "draw", "ally-player", 2)],
             tags=["过牌", "辉火", "强化"]),
    29105: C("璨灯", "form", 2, 1, "SR", 2,
             "获得 +2/+3。己方回合开始时，抽一张牌。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-lamp-bright", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "过牌", "辉火"]),
    29106: C("离魂灯", "combat", 2, 1, "R", 1,
             "出击 +2。远程。击杀简化：对敌方牌手造成 2 点伤害。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 2)],
             keywords=["REMOTE"], tags=["出击", "远程", "辉火"]),
    29107: C("灯火长明", "realm", 3, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，为所有己方恢复 2 点生命并抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "复活", "辉火"]),
    29108: C("此间百闻", "awakening", 3, 1, "SSR", 1,
             "瞬发。对敌方前线造成 3 点伤害。觉醒：+2/+2，回合开始投射 3 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3)],
             keywords=["INSTANT"], deck_limit=1, tags=["觉醒", "辉火", "投射"]),

    # ---- 孔雀明王 605 ----
    60501: C("羽化", "spell", 1, 0, "R", 2,
             "获得 1 点能量，并抽一张牌（孔雀翎简化）。",
             [("always", "energy-gain", "ally-player", 1), ("always", "draw", "ally-player", 1)],
             tags=["过牌", "孔雀翎", "强化"]),
    60502: C("离笼曲", "form", 1, 1, "R", 1,
             "获得 +1/+3。迅捷。攻击破甲目标免疫简化：破甲敌方 -1 力量。",
             [("always", "form", "source", F(1, 3))],
             formAbility="己方回合开始时，敌方前线 -1 力量。",
             formHooks=[{"id": "form-peacock-cage", "event": "turn-started", "effect": "passive-armor-break-enemy-front", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "破甲", "孔雀翎"]),
    60503: C("翎羽苏生", "spell", 1, 1, "SR", 1,
             "气绝时可用：复活孔雀明王，并获得 1 点能量。",
             [("always", "revive", "source", 1), ("always", "energy-gain", "ally-player", 1)],
             tags=["复活", "孔雀翎", "治疗"]),
    60504: C("迷离之境", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "破甲", "孔雀翎"]),
    60505: C("祈神之舞", "form", 2, 1, "SR", 2,
             "获得 +2/+3。完成交战后，使交战目标获得 1 点破甲。",
             [("always", "form", "source", F(2, 3))],
             formAbility="完成交战后，使交战目标获得 1 点破甲。",
             formHooks=[{"id": "form-peacock-dance", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "破甲", "孔雀翎"]),
    60506: C("流羽斩", "combat", 3, 1, "R", 1,
             "出击 +2。使一个敌方式神 -3 力量并获得 3 点破甲。",
             [("source-ready", "assault", "source", 2), ("always", "debuff-stats", "selected-enemy", F(3, 0)), ("always", "apply-armor-break", "selected-enemy", 3)],
             tags=["出击", "破甲", "孔雀翎"]),
    60507: C("荆棘舞", "combat", 3, 1, "SR", 1,
             "出击 +3。获得屏障简化为 2 点护甲。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
             tags=["出击", "屏障", "孔雀翎"]),
    60508: C("觉醒·孔雀明王", "awakening", 3, 1, "SSR", 1,
             "觉醒：贯通先攻，+2/+2。己方回合开始，获得 1 点能量与 1 点力量。",
             [("always", "awaken", "source", F(2, 2)), ("always", "energy-gain", "ally-player", 1), ("always", "buff-stats", "source", F(1, 0))],
             deck_limit=1, tags=["觉醒", "孔雀翎", "破甲"]),

    # ---- 粉婆婆 603 ----
    60301: C("负心", "spell", 1, 0, "R", 2,
             "对一个敌方式神造成 2 点伤害，并对其牌手造成 1 点伤害（生命精华简化）。",
             [("always", "damage", "selected-enemy", 2), ("always", "damage", "enemy-avatar", 1)],
             tags=["伤害", "投射", "生命精华"]),
    60302: C("画颜", "form", 1, 1, "SR", 2,
             "获得 +2/+3。己方回合开始时，随机对敌方造成 2 点伤害（过量治疗投射简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
             formHooks=[{"id": "form-fen-paint", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "投射", "生命精华"]),
    60303: C("抹粉施脂", "spell", 1, 1, "R", 1,
             "气绝时可用：复活一个己方式神，并为所有己方恢复 2 点生命。",
             [("always", "revive", "knocked-ally", 1), ("always", "heal", "all-ally-units", 2)],
             tags=["复活", "治疗", "生命精华"]),
    60304: C("眸之色·嫣", "form", 2, 1, "SR", 1,
             "获得 +2/+4。己方回合开始时，获得 1 点能量（生命精华简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，你获得 1 点能量。",
             formHooks=[{"id": "form-fen-eye", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "过量治疗", "生命精华"]),
    60305: C("烟粉缭绕", "spell", 2, 1, "R", 1,
             "为所有己方式神恢复 2 点生命，并为粉婆婆恢复 3 点生命。",
             [("always", "heal", "all-ally-units", 2), ("always", "heal", "source", 3)],
             tags=["治疗", "过量治疗", "生命精华"]),
    60306: C("怨恨之容", "realm", 3, 1, "R", 1,
             "瞬发。幻境（耐久 5）：己方回合开始时，你获得 1 点能量。",
             [("always", "realm", "ally-player", None)],
             keywords=["INSTANT"],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 0},
             deck_limit=2, tags=["幻境", "过量治疗", "生命精华"]),
    60307: C("颊之色·雪", "spell", 3, 1, "SR", 1,
             "对一个式神造成 6 点伤害，并为你恢复 3 点生命。",
             [("always", "damage", "selected-enemy", 6), ("always", "heal-avatar", "ally-player", 3)],
             tags=["伤害", "治疗", "生命精华"]),
    60308: C("觉醒·粉婆婆", "awakening", 3, 2, "SSR", 1,
             "觉醒：+2/+2。过量治疗投射 3 点，并恢复 3 点生命。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3), ("always", "heal", "source", 3)],
             deck_limit=1, tags=["觉醒", "过量治疗", "投射"]),

    # ---- 椒图 606 ----
    60601: C("涌流", "form", 1, 1, "R", 2,
             "获得 +1/+3。己方牌手受伤后，投射 1 点（简化为回合触发）。",
             [("always", "form", "source", F(1, 3))],
             formAbility="己方回合开始时，对敌方前线造成 1 点伤害。",
             formHooks=[{"id": "form-jiao-flow", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "投射", "护主"]),
    60602: C("明珠障目", "spell", 1, 0, "R", 1,
             "瞬发。气绝时可用：复活一个己方式神，并对己方牌手造成 2 点伤害。",
             [("always", "revive", "knocked-ally", 1), ("always", "damage-self", "source", 0)],
             keywords=["INSTANT"], tags=["瞬发", "复活", "护主"]),
    60603: C("春樱日和", "form", 2, 1, "R", 1,
             "获得 +3/+4。受到伤害后，恢复 2 点生命（伤害转移简化）。",
             [("always", "form", "source", F(3, 4))],
             formAbility="受到伤害后，椒图恢复 2 点生命。",
             formHooks=[{"id": "form-jiao-sakura", "event": "unit-damaged", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "护主", "治疗"]),
    60604: C("润物无声", "realm", 2, 1, "SR", 2,
             "幻境（耐久 5）：己方回合开始时，为所有己方式神恢复 1 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "护主", "团辅"]),
    60605: C("觉醒·椒图", "awakening", 2, 1, "SR", 1,
             "抽一张牌。觉醒：+1/+3，牌手受伤后获得护甲（精华简化）。",
             [("always", "awaken", "source", F(1, 3)), ("always", "draw", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "护主", "生命精华"]),
    60606: C("水花弹", "spell", 3, 1, "R", 1,
             "对一个式神造成 5 点伤害（受伤次数简化）。",
             [("always", "damage", "selected-enemy", 5)],
             tags=["伤害", "护主", "投射"]),
    60607: C("沧海珠泪", "form", 3, 2, "SSR", 0,
             "获得 +3/+5。受到伤害后，随机敌方 -1 力量（伤害重分配简化）。",
             [("always", "form", "source", F(3, 5))],
             formAbility="受到伤害后，随机敌方 -1 力量。",
             formHooks=[{"id": "form-jiao-tear", "event": "unit-damaged", "effect": "passive-armor-break-enemy-on-damage", "params": {"amount": 1}, "priority": 40}],
             deck_limit=2, tags=["形态", "护主", "终结"]),
    60608: C("借水扬波", "combat", 3, 1, "SR", 1,
             "出击 +3。受到伤害后获得 1 点护甲（转移简化）。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 1)],
             tags=["出击", "护主", "护甲"]),

    # ---- 季 604 ----
    60401: C("四时·春", "form", 1, 1, "R", 2,
             "获得 +2/+3。进场简化：为你和战斗区恢复 2 点生命。",
             [("always", "form", "source", F(2, 3)), ("always", "heal-avatar", "ally-player", 2), ("always", "heal", "source", 2)],
             tags=["形态", "四时", "治疗"]),
    60402: C("四时·夏", "form", 1, 1, "R", 1,
             "获得 +2/+2。进场：投射 3 点伤害。",
             [("always", "form", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3)],
             tags=["形态", "四时", "投射"]),
    60403: C("四时·秋", "form", 1, 1, "R", 1,
             "获得 +2/+2。随机对敌方准备区造成 2 点伤害（简化为随机敌方）。",
             [("always", "form", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 1)],
             tags=["形态", "四时", "伤害"]),
    60404: C("四时·冬", "form", 1, 1, "R", 1,
             "获得 +1/+4。离场简化：对敌方牌手造成 3 点伤害。",
             [("always", "form", "source", F(1, 4)), ("always", "damage", "enemy-avatar", 3)],
             tags=["形态", "四时", "直击"]),
    60405: C("华落四时生", "spell", 3, 2, "SSR", 0,
             "为所有己方式神恢复 3 点生命，并对所有敌方式神造成 2 点伤害。",
             [("always", "heal", "all-ally-units", 3), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=2, tags=["四时", "团辅", "终结"]),
    60406: C("四色堇", "combat", 2, 1, "SR", 1,
             "出击 +3。远程。击杀简化：抽一张牌。",
             [("source-ready", "assault", "source", 3), ("always", "draw", "ally-player", 1)],
             keywords=["REMOTE"], tags=["出击", "四时", "过牌"]),
    60407: C("弥天叶唳", "realm", 3, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，抽一张牌并获得 1 点能量。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "四时", "过牌"]),
    60408: C("觉醒·季", "awakening", 2, 1, "SR", 1,
             "抽两张牌。觉醒：+1/+2，形态牌获得瞬发（简化为面板）。",
             [("always", "awaken", "source", F(1, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "四时", "过牌"]),

    # ---- 酒吞童子·忘空 602 ----
    60201: C("无羁", "combat", 1, 1, "SR", 1,
             "出击 +3。起源狂气。增强简化：若生命≤3，额外 +2。",
             [("source-ready", "assault", "source", 3)],
             keywords=["ORIGIN"], tags=["出击", "起源", "忘空"]),
    60202: C("千丈岳", "realm", 1, 1, "R", 1,
             "幻境（耐久 4）：进场对自身造成 2 点伤害并抽一张牌（简化并入）。",
             [("always", "damage-self", "source", 2), ("always", "draw", "ally-player", 1), ("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "不屈", "忘空"]),
    60203: C("一念魔佛", "awakening", 2, 1, "SR", 1,
             "获得不屈。觉醒：+1/+2，生命变为 1 后永久 +1 力量。",
             [("always", "awaken", "source", F(1, 2)), ("always", "grant-unyielding", "source", 1)],
             deck_limit=1, tags=["觉醒", "不屈", "忘空"]),
    60204: C("万念不殆", "form", 2, 1, "R", 2,
             "获得 +2/+4。气绝时复活（简化为受到伤害后 +1 力量）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="受到伤害后，酒吞童子·忘空获得 1 点力量。",
             formHooks=[{"id": "form-jutun-mind", "event": "unit-damaged", "effect": "passive-buff-self-on-damaged", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "不屈", "成长"]),
    60205: C("死斗", "combat", 2, 1, "R", 1,
             "出击 +2。追猎。获得不屈。",
             [("source-ready", "assault", "source", 2), ("always", "grant-unyielding", "source", 1)],
             keywords=["UNYIELDING"], tags=["出击", "追猎", "不屈"]),
    60206: C("何渡鬼道", "spell", 3, 1, "SR", 1,
             "为所有己方式神恢复 4 点生命，并获得 1 点护甲。",
             [("always", "heal", "all-ally-units", 4), ("always", "shield", "all-ally-units", 1)],
             tags=["治疗", "护甲", "忘空"]),
    60207: C("且醉且歌", "form", 3, 1, "R", 1,
             "获得 +4/+4。瞬发。帷幕简化为 2 点护甲。",
             [("always", "form", "source", F(4, 4)), ("always", "shield", "source", 2)],
             keywords=["INSTANT"], tags=["形态", "瞬发", "忘空"]),
    60208: C("灭道殉神", "combat", 3, 2, "SSR", 0,
             "对自身造成 2 点伤害，并对所有敌方式神造成 4 点伤害。",
             [("always", "damage-self", "source", 2), ("always", "damage", "all-enemy-units", 4)],
             deck_limit=2, tags=["群伤", "自伤", "终结"]),

    # ---- 茨木童子·旅立 607 ----
    60701: C("鬼之焰", "spell", 1, 1, "R", 1,
             "对一个准备区敌方式神造成 4 点伤害（鬼蚀之手简化）。",
             [("always", "damage", "selected-enemy", 4)],
             keywords=["CRIT"], tags=["伤害", "召唤", "旅立"]),
    60702: C("伊吹山", "realm", 2, 1, "SR", 1,
             "幻境（耐久 4）：己方回合开始时，随机对敌方造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "召唤", "旅立"]),
    60703: C("狂意之焰", "spell", 2, 1, "R", 1,
             "对敌方前线造成 4 点伤害，并使茨木童子·旅立获得 +1 力量。",
             [("always", "damage-enemy-front", "auto", 4), ("always", "buff-stats", "source", F(1, 0))],
             tags=["伤害", "召唤", "旅立"]),
    60704: C("炼狱道", "awakening", 3, 1, "SR", 1,
             "出击 +2。觉醒：+2/+2，攻击后对敌方前线造成 2 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("source-ready", "assault", "source", 2)],
             deck_limit=1, tags=["觉醒", "召唤", "旅立"]),
    60705: C("登程", "form", 2, 1, "R", 2,
             "获得 +2/+3。己方回合开始时，获得 1 点力量（召唤迅捷简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，茨木童子·旅立获得 1 点力量。",
             formHooks=[{"id": "form-cainu-depart", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "召唤", "成长"]),
    60706: C("鬼蚀乱舞", "combat", 1, 1, "R", 1,
             "出击 +2。瞬发。",
             [("source-ready", "assault", "source", 2)],
             keywords=["INSTANT"], tags=["出击", "瞬发", "召唤"]),
    60707: C("深渊之焰", "spell", 3, 1, "SR", 1,
             "对所有敌方式神造成 3 点伤害（鬼蚀之手双倍简化）。",
             [("always", "damage", "all-enemy-units", 3)],
             tags=["群伤", "召唤", "旅立"]),
    60708: C("豪气解放", "spell", 3, 2, "SSR", 0,
             "气绝时可用：复活茨木童子·旅立，并对敌方前线造成 5 点伤害。",
             [("always", "revive", "source", 1), ("always", "damage-enemy-front", "auto", 5)],
             deck_limit=2, tags=["复活", "伤害", "终结"]),

    # ---- 青坊主·凡尘 299 ----
    29901: C("渡魂", "combat", 1, 1, "SR", 1,
             "出击 +2。起源慈悲。必杀简化：暴击。",
             [("source-ready", "assault", "source", 2)],
             keywords=["ORIGIN", "CRIT"], tags=["出击", "起源", "凡尘"]),
    29902: C("佛心", "realm", 2, 1, "R", 2,
             "幻境（耐久 5）：己方回合开始时，为你和青坊主恢复 2 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "治疗", "生命精华"]),
    29903: C("一叶菩提", "spell", 1, 0, "R", 1,
             "瞬发。抽一张牌，并为青坊主恢复 3 点生命。",
             [("always", "draw", "ally-player", 1), ("always", "heal", "source", 3)],
             keywords=["INSTANT"], tags=["瞬发", "治疗", "生命精华"]),
    29904: C("归凡入世", "form", 2, 1, "R", 1,
             "获得 +3/+3。未受伤简化为回合开始 +1 力量。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，若在战斗区，获得 1 点力量。",
             formHooks=[{"id": "form-qing-mortal", "event": "turn-started", "effect": "passive-buff-self-if-front", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "成长", "凡尘"]),
    29905: C("伏魔", "combat", 2, 1, "R", 1,
             "出击 +3。追猎。治疗自身 2 点生命。",
             [("source-ready", "assault", "source", 3), ("always", "heal", "source", 2)],
             tags=["出击", "追猎", "治疗"]),
    29906: C("无量", "realm", 2, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，为所有己方式神恢复 2 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "治疗", "团辅"]),
    29907: C("万法皆识", "form", 3, 1, "SR", 1,
             "获得 +3/+4。完成交战后，恢复 2 点生命并抽一张牌。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，恢复 2 点生命并抽一张牌。",
             formHooks=[
                 {"id": "form-qing-law-a", "event": "combat-resolved", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40},
                 {"id": "form-qing-law-b", "event": "combat-resolved", "effect": "passive-draw-self", "params": {"count": 1}, "priority": 40},
             ],
             tags=["形态", "治疗", "生命精华"]),
    29908: C("垢去明存", "awakening", 3, 1, "SSR", 1,
             "使一个己方其他式神 +2/+2。觉醒：+2/+2，受伤后获得 1 点护甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "all-other-allies", F(2, 2))],
             deck_limit=1, tags=["觉醒", "生命精华", "凡尘"]),

    # ---- 判官·悬墨 601 ----
    60101: C("死契", "spell", 1, 1, "SR", 1,
             "消灭一个敌方式神简化：造成 6 点伤害，并对自身造成 3 点伤害。",
             [("always", "damage", "selected-enemy", 6), ("always", "damage-self", "source", 3)],
             tags=["消灭", "伤害", "悬墨"]),
    60102: C("摄魂", "form", 1, 1, "R", 1,
             "获得 +2/+3。倒计时简化：回合开始抽一张牌。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-panguan-soul", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "过牌", "悬墨"]),
    60103: C("黄泉岸", "realm", 1, 1, "R", 1,
             "幻境（耐久 4）：进场抽一张牌，回合开始对敌方前线 1 点伤害。",
             [("always", "draw", "ally-player", 1), ("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "消灭", "悬墨"]),
    60104: C("鬼使勒令", "spell", 2, 1, "R", 1,
             "使一个己方其他式神 +2 力量（发起攻击简化）。",
             [("always", "buff-stats", "all-other-allies", F(2, 0))],
             keywords=["CRIT"], tags=["出击", "必杀", "悬墨"]),
    60105: C("罚恶赏善", "form", 2, 1, "SR", 2,
             "获得 +2/+4。己方回合开始时，为所有己方恢复 1 点生命（倒计时-1简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
             formHooks=[{"id": "form-panguan-judge", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "消灭", "团辅"]),
    60106: C("落笔归魂", "awakening", 2, 1, "SR", 1,
             "对随机敌方造成 2 点伤害。觉醒：+1/+2，敌方气绝后抽一张牌（精华简化）。",
             [("always", "awaken", "source", F(1, 2)), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=1, tags=["觉醒", "复活", "悬墨"]),
    60107: C("荒寂", "spell", 3, 1, "R", 1,
             "消灭所有幻境简化：对所有敌方式神造成 2 点伤害并移除护甲。",
             [("always", "damage", "all-enemy-units", 2), ("always", "remove-shield", "selected-enemy", 0)],
             tags=["消灭", "幻境", "悬墨"]),
    60108: C("生死狭间", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：进场复活一个己方式神；回合开始随机消灭简化为 3 点伤害。",
             [("always", "revive", "knocked-ally", 1), ("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 3},
             deck_limit=2, tags=["幻境", "消灭", "终结"]),

    # ---- 琅琊子 615 ----
    61501: C("钱眼", "spell", 1, 0, "SR", 1,
             "瞬发。消灭一个敌方幻境简化：对敌方前线造成 3 点伤害并抽一张牌。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "消灭", "咒印"]),
    61502: C("忘诀", "spell", 2, 1, "R", 1,
             "眩晕一个敌方式神，并抽一张牌（忘咒简化）。",
             [("always", "freeze", "selected-enemy", 1), ("always", "draw", "ally-player", 1)],
             keywords=["STUN"], tags=["眩晕", "咒印", "过牌"]),
    61503: C("镇诀", "spell", 1, 1, "R", 2,
             "使一个敌方式神 -2 力量，并获得 1 点护甲（镇咒简化）。",
             [("always", "debuff-stats", "selected-enemy", F(2, 0)), ("always", "shield", "source", 1)],
             tags=["削弱", "咒印", "护甲"]),
    61504: C("灭诀", "spell", 1, 1, "SR", 1,
             "对一个敌方式神造成等同于场上幻境简化：造成 5 点伤害。",
             [("always", "damage", "selected-enemy", 5)],
             tags=["伤害", "咒印", "消灭"]),
    61505: C("魂诀", "spell", 2, 1, "R", 1,
             "对敌方牌手造成 2 点伤害，并为琅琊子恢复 2 点生命（魂咒简化）。",
             [("always", "damage", "enemy-avatar", 2), ("always", "heal", "source", 2)],
             tags=["直击", "咒印", "治疗"]),
    61506: C("觉醒·琅琊子", "awakening", 2, 1, "SR", 1,
             "对所有敌方式神造成 2 点伤害。觉醒：+1/+2，出牌后投射 2 点（寐咒简化）。",
             [("always", "awaken", "source", F(1, 2)), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=1, tags=["觉醒", "咒印", "投射"]),
    61507: C("桃源洞天", "realm", 3, 1, "R", 1,
             "幻境（耐久 6）：己方回合开始时，为所有己方式神恢复 2 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "咒印", "治疗"]),
    61508: C("永生诀", "spell", 3, 2, "SSR", 0,
             "消灭一个敌方式神简化：造成 8 点伤害，并使琅琊子获得 +2/+2。",
             [("always", "damage", "selected-enemy", 8), ("always", "buff-stats", "source", F(2, 2))],
             deck_limit=2, tags=["消灭", "咒印", "终结"]),

    # ---- 言灵 614 ----
    61401: C("言动", "spell", 1, 1, "R", 2,
             "对一个式神造成 3 点伤害。增强简化：额外 1 点。",
             [("always", "damage", "selected-enemy", 4)],
             tags=["伤害", "语罪", "反制"]),
    61402: C("育言", "form", 1, 1, "SR", 1,
             "获得 +1/+3。语罪触发抽牌简化：回合开始抽一张牌。",
             [("always", "form", "source", F(1, 3))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-yan-nurture", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "语罪", "过牌"]),
    61403: C("诳默", "spell", 1, 0, "R", 1,
             "响应：被攻击时自动使用。获得 2 点护甲并眩晕攻击者简化为护甲。",
             [("always", "shield", "source", 2)],
             keywords=["RESPONSE"], timing="response", responseTo=["assault"],
             tags=["响应", "语罪", "反制"]),
    61404: C("诳灭", "spell", 2, 1, "R", 1,
             "消灭一个上回合未使用过牌的敌方式神简化：造成 5 点伤害。",
             [("always", "damage", "selected-enemy", 5)],
             tags=["消灭", "语罪", "反制"]),
    61405: C("真言道", "realm", 2, 2, "SSR", 0,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 3 点伤害（反制简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 3},
             deck_limit=2, tags=["幻境", "语罪", "反制"]),
    61406: C("授言", "form", 2, 1, "SR", 2,
             "获得 +2/+3。语罪眩晕简化：回合开始眩晕随机敌方。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，眩晕一个敌方式神（随机）。",
             formHooks=[{"id": "form-yan-teach", "event": "turn-started", "effect": "passive-freeze-combat-defender", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "语罪", "眩晕"]),
    61407: C("言归", "spell", 3, 1, "R", 1,
             "对所有敌方式神造成 2 点伤害，并为你恢复 3 点生命。",
             [("always", "damage", "all-enemy-units", 2), ("always", "heal-avatar", "ally-player", 3)],
             tags=["群伤", "语罪", "治疗"]),
    61408: C("觉醒·言灵", "awakening", 3, 2, "SR", 1,
             "对所有敌方式神造成 2 点伤害。觉醒：+1/+2，回合开始随机敌方 -1 力量。",
             [("always", "awaken", "source", F(1, 2)), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=1, tags=["觉醒", "语罪", "反制"]),

    # ---- 慧明灯 608 ----
    60801: C("净秽", "spell", 1, 1, "SR", 1,
             "消灭一个上回合对你造成过战斗伤害的式神简化：造成 5 点伤害。",
             [("always", "damage", "selected-enemy", 5)],
             keywords=["INSTANT"], tags=["疾速", "消灭", "战力"]),
    60802: C("嗔念", "spell", 1, 0, "R", 2,
             "坚守：+2 战力简化为自身 +2 力量，并使一个敌方 -1 力量。",
             [("always", "buff-stats", "source", F(2, 0)), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             tags=["坚守", "战力", "削弱"]),
    60803: C("佛智", "combat", 1, 1, "R", 1,
             "出击 +2。追猎。战斗结束后恢复 3 点生命简化为治疗 2。",
             [("source-ready", "assault", "source", 2), ("always", "heal-avatar", "ally-player", 2)],
             tags=["出击", "追猎", "治疗"]),
    60804: C("觉醒·慧明灯", "awakening", 2, 1, "SR", 1,
             "坚守 +2 战力/+2 护甲。觉醒：+1/+3，回合开始获得 2 点护甲。",
             [("always", "awaken", "source", F(1, 3)), ("always", "shield", "source", 2)],
             deck_limit=1, tags=["觉醒", "坚守", "战力"]),
    60805: C("正念", "form", 2, 1, "SR", 2,
             "获得 +2/+4。己方回合结束简化：开始时投射 2 点并治疗 2。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，对敌方前线造成 2 点伤害并恢复 2 点生命。",
             formHooks=[
                 {"id": "form-hui-mind-a", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40},
                 {"id": "form-hui-mind-b", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40},
             ],
             tags=["形态", "坚守", "战力"]),
    60806: C("业回", "spell", 2, 1, "R", 1,
             "气绝时可用：复活一个己方式神，并获得 2 点护甲。",
             [("always", "revive", "knocked-ally", 1), ("always", "shield", "source", 2)],
             tags=["复活", "坚守", "护甲"]),
    60807: C("业障", "form", 3, 1, "R", 1,
             "获得 +4/+4。出击额外 +2 简化为面板。",
             [("always", "form", "source", F(4, 4))],
             tags=["形态", "坚守", "战力"]),
    60808: C("明识灯", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 6）：己方回合开始时，为所有己方获得 2 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "坚守", "团辅"]),

    # ---- 食发鬼 609 ----
    60901: C("发刺", "combat", 1, 1, "R", 2,
             "出击 +2。疾速，穿刺，贯通简化为面板 +1。",
             [("source-ready", "assault", "source", 3)],
             keywords=["PIERCE"], tags=["出击", "穿刺", "战力"]),
    60902: C("发缠", "combat", 1, 1, "R", 1,
             "出击 +1。获得 3 点护甲（战力转甲简化）。",
             [("source-ready", "assault", "source", 1), ("always", "shield", "source", 3)],
             tags=["出击", "护甲", "战力"]),
    60903: C("战怖迷烟", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，其他己方 +1 力量。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "战力", "团辅"]),
    60904: C("觉醒·食发鬼", "awakening", 2, 1, "SSR", 1,
             "使一个敌方 -2 力量，自身 +2 力量。觉醒：+2/+1，回合开始再 +1 力量。",
             [("always", "awaken", "source", F(2, 1)), ("always", "debuff-stats", "selected-enemy", F(2, 0)), ("always", "buff-stats", "source", F(2, 0))],
             deck_limit=1, tags=["觉醒", "战力", "乏力"]),
    60905: C("发鞭", "combat", 2, 1, "R", 1,
             "出击 +3。追猎。使被攻击者 -2 力量。",
             [("source-ready", "assault", "source", 3), ("always", "debuff-stats", "selected-enemy", F(2, 0))],
             tags=["出击", "追猎", "乏力"]),
    60906: C("真实之颜", "form", 3, 1, "SR", 1,
             "获得 +3/+4。己方回合开始时，对所有敌方造成 1 点伤害并自身 +1 力量。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，对所有敌方式神造成 1 点伤害，食发鬼获得 1 点力量。",
             formHooks=[
                 {"id": "form-hair-face-a", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40},
                 {"id": "form-hair-face-b", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
             ],
             tags=["形态", "战力", "群伤"]),
    60907: C("无畏迷烟", "realm", 3, 1, "SR", 1,
             "瞬发。幻境（耐久 5）：己方回合开始时，所有己方 +1 力量。",
             [("always", "realm", "ally-player", None)],
             keywords=["INSTANT"],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "战力", "团辅"]),
    60908: C("食发之喜", "form", 2, 1, "SR", 1,
             "获得 +2/+4。气绝时可用：复活并 +2 力量简化为面板。",
             [("always", "form", "source", F(3, 4)), ("always", "revive", "source", 1)],
             tags=["形态", "复活", "战力"]),

    # ---- 天逆每 611 ----
    61101: C("惧影随", "combat", 1, 1, "R", 2,
             "出击 +2。消灭式神时恐惧简化：使目标 -1 力量。",
             [("source-ready", "assault", "source", 2), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             keywords=["FIRST_STRIKE"], tags=["出击", "恐惧", "惧翼"]),
    61102: C("颤栗", "spell", 1, 1, "R", 1,
             "使一个敌方式神 -2 力量，并使天逆每获得 +1 力量与 1 点能量。",
             [("always", "debuff-stats", "selected-enemy", F(2, 0)), ("always", "buff-stats", "source", F(1, 0)), ("always", "energy-gain", "ally-player", 1)],
             tags=["恐惧", "惧翼", "削弱"]),
    61103: C("觉醒·天逆每", "awakening", 1, 0, "SR", 1,
             "瞬发。使一个敌方 -2 力量。觉醒：+1/+2，回合开始获得 1 点能量。",
             [("always", "awaken", "source", F(1, 2)), ("always", "debuff-stats", "selected-enemy", F(2, 0)), ("always", "energy-gain", "ally-player", 1)],
             keywords=["INSTANT"], deck_limit=1, tags=["觉醒", "恐惧", "惧翼"]),
    61104: C("恐惧之夜", "realm", 2, 2, "SSR", 0,
             "幻境（耐久 5）：己方回合开始时，随机敌方 -2 力量并抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "恐惧", "惧翼"]),
    61105: C("惧中人", "form", 2, 1, "SR", 2,
             "获得 +2/+3。完成交战后，交战目标 -1 力量。",
             [("always", "form", "source", F(2, 3))],
             formAbility="完成交战后，使交战目标 -1 力量。",
             formHooks=[{"id": "form-tian-fear", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "恐惧", "惧翼"]),
    61106: C("惧刃之风", "combat", 2, 1, "R", 1,
             "出击 +4。攻击式神时战力翻倍简化为 +2。",
             [("source-ready", "assault", "source", 4)],
             tags=["出击", "恐惧", "惧翼"]),
    61107: C("剖视", "spell", 3, 1, "R", 1,
             "使所有敌方式神 -2 力量，并获得 1 点能量。",
             [("always", "debuff-stats", "selected-enemy", F(2, 0)), ("always", "energy-gain", "ally-player", 1)],
             tags=["恐惧", "惧翼", "群伤"]),
    61108: C("惧意蔓延", "combat", 3, 1, "SR", 1,
             "出击 +3。疾速，免疫战斗伤害简化为 3 点护甲。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 3)],
             keywords=["INSTANT"], tags=["出击", "疾速", "惧翼"]),

    # ---- 姑获鸟·玉响 610 ----
    61001: C("伞阵", "combat", 1, 1, "R", 2,
             "出击 +1。起源伞剑。坚守 +1 战力简化为 +1 力量。",
             [("source-ready", "assault", "source", 1), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["ORIGIN"], tags=["出击", "坚守", "玉响"]),
    61002: C("后山羽舍", "realm", 1, 1, "R", 1,
             "幻境（耐久 6）：己方回合开始时，其他己方 +1 力量与 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "坚守", "团辅"]),
    61003: C("佯攻", "spell", 1, 1, "SR", 1,
             "疾速。获得 +1 力量并抽一张牌。",
             [("always", "buff-stats", "source", F(1, 0)), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["疾速", "坚守", "过牌"]),
    61004: C("燕返", "combat", 2, 1, "SR", 1,
             "出击 +2。免疫战斗伤害简化为 3 点护甲。疾速。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 3)],
             keywords=["INSTANT"], tags=["出击", "疾速", "玉响"]),
    61005: C("送子歌", "form", 2, 2, "SSR", 0,
             "获得 +2/+3。己方回合开始时，获得 1 点力量与护甲。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，姑获鸟·玉响获得 1 点力量与 1 点护甲。",
             formHooks=[
                 {"id": "form-guniao-song-a", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
                 {"id": "form-guniao-song-b", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "坚守", "玉响"]),
    61006: C("追剑", "combat", 2, 1, "R", 1,
             "出击 +3。追猎。击杀获得 2 力量简化为完成交战 +1 力量。",
             [("source-ready", "assault", "source", 3)],
             tags=["出击", "追猎", "成长"]),
    61007: C("鹤守", "form", 3, 1, "R", 1,
             "获得 +3/+4。其他己方出击后获得战力简化：回合开始其他己方 +1 力量。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，其他己方式神获得 1 点力量。",
             formHooks=[{"id": "form-guniao-crane", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "坚守", "团辅"]),
    61008: C("回天之翼", "awakening", 3, 1, "SR", 1,
             "坚守 +2 战力。觉醒：+2/+2，被攻即撤简化为受到伤害后 2 点护甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "source", F(2, 0))],
             deck_limit=1, tags=["觉醒", "坚守", "玉响"]),

    # ---- 桃花妖·落英 612 ----
    61201: C("廿四风", "spell", 1, 0, "SR", 1,
             "瞬发。使一个己方式神 +1 力量。弹回简化为抽一张牌。",
             [("always", "buff-stats", "selected-ally", F(1, 0)), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "战力", "落英"]),
    61202: C("花月夜", "form", 1, 1, "R", 2,
             "获得 +1/+3。己方回合开始时，战斗区 +1 力量（简化为自身）。",
             [("always", "form", "source", F(1, 3))],
             formAbility="己方回合开始时，姑获鸟式神获得 1 点力量（自身）。",
             formHooks=[{"id": "form-tao-night", "event": "turn-started", "effect": "passive-buff-self-if-front", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "战力", "落英"]),
    61203: C("桃花雨", "spell", 2, 1, "R", 1,
             "疾速。所有己方式神 +2 力量。",
             [("always", "buff-stats", "all-ally-units", F(2, 0))],
             keywords=["INSTANT"], tags=["疾速", "战力", "团辅"]),
    61204: C("潭水游", "spell", 2, 1, "SR", 1,
             "疾速。坚守 +2 战力/+1 护甲：自身 +2/+1。",
             [("always", "buff-stats", "source", F(2, 1)), ("always", "shield", "source", 1)],
             keywords=["INSTANT"], tags=["疾速", "坚守", "战力"]),
    61205: C("桃刹舞", "spell", 2, 1, "R", 1,
             "使一个己方其他式神 +3 力量，并为你恢复 2 点生命。",
             [("always", "buff-stats", "all-other-allies", F(3, 0)), ("always", "heal-avatar", "ally-player", 2)],
             tags=["战力", "治疗", "落英"]),
    61206: C("归风灼华", "form", 2, 2, "SSR", 0,
             "获得 +2/+3。进场/回合开始：抽一张牌（灼华简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，抽一张牌并获得 1 点力量。",
             formHooks=[
                 {"id": "form-tao-bloom-a", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-tao-bloom-b", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "战力", "落英"]),
    61207: C("春风笑", "spell", 3, 1, "R", 1,
             "使一个己方其他式神 +5 力量，并对敌方前线造成 3 点伤害。",
             [("always", "buff-stats", "all-other-allies", F(5, 0)), ("always", "damage-enemy-front", "auto", 3)],
             tags=["战力", "伤害", "落英"]),
    61208: C("桃运之佑", "awakening", 3, 2, "SR", 1,
             "坚守 +3 战力。觉醒：+2/+2，战斗区己方获得 2 点护甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "source", F(3, 0)), ("always", "shield", "all-ally-units", 1)],
             deck_limit=1, tags=["觉醒", "战力", "坚毅"]),

    # ---- 一目连·灵籁 613 ----
    61301: C("风止", "combat", 1, 1, "R", 2,
             "出击 +2。对敌方式神造成战斗伤害时眩晕：改为出击后眩晕。",
             [("source-ready", "assault", "source", 2), ("always", "freeze", "selected-enemy", 1)],
             keywords=["STUN"], tags=["出击", "眩晕", "风符"]),
    61302: C("风憩", "spell", 1, 1, "R", 1,
             "气绝时可用：复活一目连·灵籁，然后眩晕一个敌方式神。",
             [("always", "revive", "source", 1), ("always", "freeze", "selected-enemy", 1)],
             keywords=["STUN"], tags=["复活", "眩晕", "风符"]),
    61303: C("风神之森", "realm", 1, 1, "SR", 1,
             "幻境（耐久 3）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 3, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "眩晕", "风符"]),
    61304: C("岚风", "spell", 2, 1, "R", 1,
             "瞬发。眩晕一个敌方式神并对其造成 2 点伤害。",
             [("always", "freeze", "selected-enemy", 1), ("always", "damage", "selected-enemy", 2)],
             keywords=["INSTANT", "STUN"], tags=["瞬发", "眩晕", "风符"]),
    61305: C("渡世之风", "awakening", 2, 1, "SR", 1,
             "使用一张风符·守简化：获得 3 点护甲。觉醒：+1/+3，眩晕后护甲。",
             [("always", "awaken", "source", F(1, 3)), ("always", "shield", "source", 3)],
             deck_limit=1, tags=["觉醒", "眩晕", "风符"]),
    61306: C("驰风", "combat", 2, 1, "R", 1,
             "出击 +3。追猎。眩晕被攻击者。",
             [("source-ready", "assault", "source", 3), ("always", "freeze", "selected-enemy", 1)],
             keywords=["STUN"], tags=["出击", "追猎", "眩晕"]),
    61307: C("风神之佑", "combat", 3, 2, "SSR", 0,
             "出击 +3。使用风符·守简化：获得 3 点护甲并暴击。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 3)],
             keywords=["CRIT"], deck_limit=2, tags=["出击", "风符", "终结"]),
    61308: C("风雷谷", "realm", 3, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 5 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 5},
             deck_limit=2, tags=["幻境", "眩晕", "风符"]),

    # ---- 山兔/座敷童子 616 ----
    61601: C("冲呀！", "combat", 1, 1, "R", 2,
             "出击 +3。增强如意骰子简化：必杀→暴击。",
             [("source-ready", "assault", "source", 3)],
             keywords=["CRIT"], tags=["出击", "运势", "如意骰子"]),
    61602: C("圆月之时", "awakening", 3, 2, "SR", 1,
             "觉醒：+2/+2。如意骰子不耗火并投射点数伤害简化：投射 4 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 4)],
             deck_limit=1, tags=["觉醒", "运势", "如意骰子"]),
    61603: C("来得巧", "spell", 1, 1, "R", 1,
             "运势 1：对一个敌方式神造成 3 点伤害（骰子点数简化）。",
             [("always", "damage", "selected-enemy", 3)],
             keywords=["FORTUNE"], tags=["运势", "伤害", "如意骰子"]),
    61604: C("运势套索", "spell", 2, 1, "SR", 1,
             "将一张如意骰子简化：获得 1 点能量，并移入战斗区（fortify）。",
             [("always", "energy-gain", "ally-player", 1), ("always", "fortify", "source", 2)],
             keywords=["ORIGIN"], tags=["运势", "如意骰子", "出击"]),
    61605: C("福来运转", "form", 2, 1, "R", 1,
             "获得 +2/+3。远程，迅捷。攻击时刷新骰子简化：完成交战抽一张牌。",
             [("always", "form", "source", F(2, 3))],
             formAbility="完成交战后，抽一张牌。",
             formHooks=[{"id": "form-shantu-luck", "event": "combat-resolved", "effect": "passive-draw-self", "params": {"count": 1}, "priority": 40}],
             keywords=["REMOTE"], tags=["形态", "运势", "过牌"]),
    61606: C("新年之约", "form", 1, 1, "SR", 2,
             "获得 +2/+3。进场获骰子简化：回合开始获得 1 点能量。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，你获得 1 点能量。",
             formHooks=[{"id": "form-shantu-year", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "运势", "如意骰子"]),
    61607: C("出入平安", "form", 3, 1, "R", 1,
             "获得 +3/+4。己方攻击得屏障简化：回合开始 2 点护甲。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，山兔/座敷童子获得 2 点护甲。",
             formHooks=[{"id": "form-shantu-peace", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "运势", "护甲"]),
    61608: C("黄金六曜骰", "realm", 2, 2, "SSR", 0,
             "唯一。幻境（耐久 6）：己方回合开始时，抽一张牌并获得 1 点能量。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "运势", "如意骰子"]),
}

TOKENS: list = [
    dict(id="kongqueling", unitId="kongquemingwang", name="孔雀翎", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。对敌方前线造成 1 点伤害，并使目标获得 1 点破甲。",
         keywords=["INSTANT"],
         effects=[("always", "damage-enemy-front", "auto", 1), ("always", "apply-armor-break", "selected-enemy", 1)]),
    dict(id="juyi", unitId="tiannimei", name="惧翼", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。对一个敌方式神造成 1 点伤害，并使其 -1 力量。",
         keywords=["INSTANT"],
         effects=[("always", "damage", "selected-enemy", 1), ("always", "debuff-stats", "selected-enemy", F(1, 0))]),
    dict(id="ruyishaizi", unitId="shantu-zuofu", name="如意骰子", type="spell", level=1, cost=0, rarity="common",
         text="投射：造成 2 点伤害，或为一个己方式神恢复 2 点生命。",
         keywords=["FORTUNE"],
         effects=[("always", "damage-enemy-front", "auto", 2), ("always", "heal", "source", 2)]),
    dict(id="shengmingjinghua", unitId="fenpopo", name="生命精华", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。为你恢复 2 点生命，并抽一张牌。",
         keywords=["INSTANT"],
         effects=[("always", "heal-avatar", "ally-player", 2), ("always", "draw", "ally-player", 1)]),
    dict(id="huidengzhihuo", unitId="qingxingdeng-huihuo", name="辉灯之火", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。对敌方前线造成 2 点伤害。",
         keywords=["INSTANT", "PROJECTILE"],
         effects=[("always", "damage-enemy-front", "auto", 2)]),
    dict(id="guishizhishou", unitId="caitong-lvli", name="鬼蚀之手", type="combat", level=1, cost=0, rarity="common",
         text="出击 +2。追猎。",
         keywords=[],
         effects=[("source-ready", "assault", "source", 2)]),
    dict(id="meizhou", unitId="langyazi", name="寐咒", type="spell", level=1, cost=0, rarity="common",
         text="敌方回合开始时简化：对敌方牌手造成 1 点伤害（结附简化）。",
         effects=[("always", "damage", "enemy-avatar", 1)]),
    dict(id="fengfushou", unitId="yimulian-linglai", name="风符·守", type="combat", level=1, cost=0, rarity="common",
         text="出击 +1。获得 2 点护甲。",
         effects=[("source-ready", "assault", "source", 1), ("always", "shield", "source", 2)]),
]
EXTRA_TOKENS: list = []

# 被动映射：uid -> (passive, awakenedPassive)；formHooks/被动仅用已注册 passive-*
PASSIVES = {
    "gulonghuo": (
        dict(id="gulonghuo-ember", name="鬼火残响", text="气绝时简化：完成交战后，对敌方牌手造成 1 点伤害。",
             hooks=[dict(id="ember-echo", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="gulonghuo-ember-awakened", name="歧路燃尽", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="ember-echo-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "chuanyuan": (
        dict(id="chuanyuan-swap", name="百相变幻", text="己方回合开始时，获得 1 点力量与 1 点生命。",
             hooks=[dict(id="ape-swap", event="turn-started", effect="passive-buff-self", params={"attack": 1, "hp": 1})]),
        dict(id="chuanyuan-swap-awakened", name="天衣万象", text="己方回合开始时，获得 2 点力量与 1 点生命。",
             hooks=[dict(id="ape-swap-a", event="turn-started", effect="passive-buff-self", params={"attack": 2, "hp": 1})]),
    ),
    "erkounv": (
        dict(id="erkounv-charge", name="充能血口", text="己方回合开始时，你获得 1 点能量（充能简化）。",
             hooks=[dict(id="mouth-charge", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="erkounv-charge-awakened", name="双口共命", text="己方回合开始时，你获得 1 点能量，二口女获得 1 点力量。",
             hooks=[
                 dict(id="mouth-charge-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="mouth-charge-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "xiaoxiuzhishou": (
        dict(id="xiaoxiu-thread", name="丝线直击", text="完成交战后，对敌方牌手造成 1 点伤害。",
             hooks=[dict(id="thread-face", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="xiaoxiu-thread-awakened", name="千针连缀", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="thread-face-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "quanshen-lizhan": (
        dict(id="quanshen-teach", name="历战传业", text="己方回合开始时，其他己方式神获得 1 点力量（升级叠力简化）。",
             hooks=[dict(id="sword-teach", event="turn-started", effect="passive-buff-other-allies", params={"attack": 1})]),
        dict(id="quanshen-teach-awakened", name="免许心流", text="己方回合开始时，其他己方式神获得 2 点力量。",
             hooks=[dict(id="sword-teach-a", event="turn-started", effect="passive-buff-other-allies", params={"attack": 2})]),
    ),
    "yaodaoji-zhuren": (
        dict(id="yaodaoji-curse", name="呪刃直击", text="完成交战后，对敌方牌手造成 1 点伤害并抽一张牌。",
             hooks=[
                 dict(id="curse-face", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1}),
                 dict(id="curse-draw", event="combat-resolved", effect="passive-draw-self", params={"count": 1}),
             ]),
        dict(id="yaodaoji-curse-awakened", name="无尽妖刀", text="完成交战后，对敌方牌手造成 2 点伤害并抽一张牌。",
             hooks=[
                 dict(id="curse-face-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2}),
                 dict(id="curse-draw-a", event="combat-resolved", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "datiangou-gangfeng": (
        dict(id="datiangou-origin", name="起源再临", text="完成交战后，对敌方前线造成 1 点伤害（起源倒计时简化）。",
             hooks=[dict(id="tengu-origin", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="datiangou-origin-awakened", name="龙卷钢风", text="完成交战后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="tengu-origin-a", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "qingxingdeng-huihuo": (
        dict(id="qingxingdeng-lamp", name="三类辉灯", text="己方回合开始时，抽一张牌（三类出牌简化）。",
             hooks=[dict(id="lamp-three", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="qingxingdeng-lamp-awakened", name="此间长明", text="己方回合开始时，抽一张牌并对敌方前线造成 1 点伤害。",
             hooks=[
                 dict(id="lamp-three-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
                 dict(id="lamp-three-a2", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1}),
             ]),
    ),
    "kongquemingwang": (
        dict(id="kongque-plume", name="孔雀翎羽", text="己方回合开始时，获得 1 点能量（孔雀翎简化）。",
             hooks=[dict(id="plume-gain", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="kongque-plume-awakened", name="流羽破甲", text="己方回合开始时，获得 1 点能量并使敌方前线获得 1 点破甲。",
             hooks=[
                 dict(id="plume-gain-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="plume-break-a", event="turn-started", effect="passive-armor-break-enemy-front", params={"amount": 1}),
             ]),
    ),
    "fenpopo": (
        dict(id="fenpopo-overheal", name="过量画颜", text="恢复生命时，目标获得 1 点护甲（过量治疗简化）。",
             hooks=[dict(id="powder-over", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 1})]),
        dict(id="fenpopo-overheal-awakened", name="怨粉投射", text="恢复生命时，目标获得 2 点护甲。",
             hooks=[dict(id="powder-over-a", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 2})]),
    ),
    "jiao": (
        dict(id="jiao-shell", name="明珠护主", text="己方回合开始时，若在战斗区，获得 2 点护甲（分担伤害简化）。",
             hooks=[dict(id="shell-guard", event="turn-started", effect="passive-shield-self-if-front", params={"amount": 2})]),
        dict(id="jiao-shell-awakened", name="沧海珠泪", text="己方回合开始时，获得 2 点护甲并恢复 1 点生命。",
             hooks=[
                 dict(id="shell-guard-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="shell-guard-a2", event="turn-started", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "ji": (
        dict(id="ji-season", name="四时轮转", text="己方回合开始时，随机对一个敌方角色造成 1 点伤害（四时流转简化）。",
             hooks=[dict(id="season-turn", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="ji-season-awakened", name="华落四时", text="己方回合开始时，随机对一个敌方角色造成 2 点伤害并抽一张牌。",
             hooks=[
                 dict(id="season-turn-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 2}),
                 dict(id="season-turn-a2", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "jutun-wangkong": (
        dict(id="jutun-forget", name="忘空残血", text="受到伤害后，获得 1 点力量（生命变为 1 时叠力简化）。",
             hooks=[dict(id="forget-blood", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"amount": 1})]),
        dict(id="jutun-forget-awakened", name="一念魔佛", text="受到伤害后，获得 2 点力量。",
             hooks=[dict(id="forget-blood-a", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"amount": 2})]),
    ),
    "caitong-lvli": (
        dict(id="caitong-hand", name="鬼蚀之手", text="完成交战后，对敌方前线造成 1 点伤害（召唤鬼蚀之手简化）。",
             hooks=[dict(id="oni-hand", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="caitong-hand-awakened", name="炼狱鬼蚀", text="完成交战后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="oni-hand-a", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "qingfangzhu-fanchen": (
        dict(id="qingfang-essence", name="凡尘精华", text="受到伤害后，获得 1 点护甲（生命精华简化）。",
             hooks=[dict(id="mortal-essence", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="qingfang-essence-awakened", name="垢去明存", text="受到伤害后，获得 2 点护甲。",
             hooks=[dict(id="mortal-essence-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "panguan-xuanmo": (
        dict(id="panguan-ink", name="悬墨勾魂", text="完成交战后，使交战目标获得 1 点破甲（敌绝得精华简化）。",
             hooks=[dict(id="ink-soul", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="panguan-ink-awakened", name="生死落笔", text="完成交战后，使交战目标获得 2 点破甲。",
             hooks=[dict(id="ink-soul-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "langyazi": (
        dict(id="langyazi-curse", name="寐咒缠身", text="完成交战后，对敌方牌手造成 1 点伤害（召寐咒简化）。",
             hooks=[dict(id="sleep-curse", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="langyazi-curse-awakened", name="永生诀印", text="完成交战后，对敌方牌手造成 2 点伤害并获得 1 点力量。",
             hooks=[
                 dict(id="sleep-curse-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2}),
                 dict(id="sleep-curse-a2", event="combat-resolved", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "yanling": (
        dict(id="yanling-sin", name="语罪反制", text="完成交战后，使交战目标 -1 力量（语罪触发简化）。",
             hooks=[dict(id="word-sin", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="yanling-sin-awakened", name="真言道", text="完成交战后，使交战目标 -2 力量。",
             hooks=[dict(id="word-sin-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "huimingdeng": (
        dict(id="huiming-stand", name="坚守明灯", text="己方回合开始时，若在战斗区，获得 2 点护甲（坚守简化）。",
             hooks=[dict(id="lamp-stand", event="turn-started", effect="passive-shield-self-if-front", params={"amount": 2})]),
        dict(id="huiming-stand-awakened", name="业障灯明", text="己方回合开始时，获得 2 点护甲与 1 点力量。",
             hooks=[
                 dict(id="lamp-stand-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="lamp-stand-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "shifagui": (
        dict(id="shifagui-power", name="回合叠力", text="己方回合开始时，获得 2 点力量（+2 战力）。",
             hooks=[dict(id="hair-power", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
        dict(id="shifagui-power-awakened", name="真实之颜", text="己方回合开始时，获得 2 点力量并恢复 1 点生命。",
             hooks=[
                 dict(id="hair-power-a", event="turn-started", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="hair-power-a2", event="turn-started", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "tiannimei": (
        dict(id="tiannimei-fear", name="惧翼结附", text="己方回合开始时，你获得 1 点能量（惧翼简化）。",
             hooks=[dict(id="fear-wing", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="tiannimei-fear-awakened", name="恐惧之夜", text="己方回合开始时，你获得 1 点能量，天逆每获得 1 点力量。",
             hooks=[
                 dict(id="fear-wing-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="fear-wing-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "guniao-yuxiang": (
        dict(id="guniao-stand", name="坚守玉响", text="己方回合开始时，若在战斗区，获得 1 点力量与 1 点护甲。",
             hooks=[
                 dict(id="jade-stand-a", event="turn-started", effect="passive-buff-self-if-front", params={"attack": 1}),
                 dict(id="jade-stand-b", event="turn-started", effect="passive-shield-self-if-front", params={"amount": 1}),
             ]),
        dict(id="guniao-stand-awakened", name="回天之翼", text="己方回合开始时，获得 2 点力量与 1 点护甲。",
             hooks=[
                 dict(id="jade-stand-a2", event="turn-started", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="jade-stand-b2", event="turn-started", effect="passive-shield-self", params={"amount": 1}),
             ]),
    ),
    "taohua-luoying": (
        dict(id="taohua-force", name="落英战力", text="己方回合开始时，其他己方式神获得 1 点力量（战力团辅简化）。",
             hooks=[dict(id="petal-force", event="turn-started", effect="passive-buff-other-allies", params={"attack": 1})]),
        dict(id="taohua-force-awakened", name="桃运坚毅", text="己方回合开始时，其他己方获得 1 点力量与 1 点生命。",
             hooks=[dict(id="petal-force-a", event="turn-started", effect="passive-buff-other-allies", params={"attack": 1, "hp": 1})]),
    ),
    "yimulian-linglai": (
        dict(id="yimulian-wind", name="风符守", text="完成交战后，获得 2 点护甲（风符·守简化）。",
             hooks=[dict(id="wind-charm", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 2})]),
        dict(id="yimulian-wind-awakened", name="风神之佑", text="完成交战后，获得 3 点护甲并恢复 1 点生命。",
             hooks=[
                 dict(id="wind-charm-a", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 3}),
                 dict(id="wind-charm-a2", event="combat-resolved", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "shantu-zuofu": (
        dict(id="shantu-dice", name="如意骰子", text="己方回合开始时，你获得 1 点能量（运势得骰简化）。",
             hooks=[dict(id="dice-luck", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="shantu-dice-awakened", name="黄金六曜", text="己方回合开始时，你获得 1 点能量并抽一张牌。",
             hooks=[
                 dict(id="dice-luck-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="dice-luck-a2", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
}


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def normalize_starters() -> None:
    """强制：每单位 8 张可玩牌，starter 合计=8，觉醒 starter=1，SSR starter≤1。"""
    by_unit: dict[str, list[int]] = {}
    for oid, meta in CARD_MAP.items():
        by_unit.setdefault(unit_of(oid), []).append(oid)
    for uid, oids in by_unit.items():
        cards = [CARD_MAP[o] for o in sorted(oids)]
        assert len(cards) == 8, (uid, len(cards))
        awakes = [c for c in cards if c["type"] == "awakening"]
        assert len(awakes) == 1, (uid, [c["name"] for c in awakes])
        for c in cards:
            c["starter"] = 0
        awakes[0]["starter"] = 1
        others = [c for c in cards if c is not awakes[0]]
        ssrs = [c for c in others if c.get("rarity") == "SSR"]
        # 其余 7 张分 7 份：一张 2、一张 0（优先 SSR）、五张 1
        boost = max(others, key=lambda c: (-(1 if c.get("rarity") == "SSR" else 0), int(c.get("level", 1)), -int(c.get("cost", 1))))
        skip = ssrs[0] if ssrs else others[-1]
        if skip is boost:
            skip = next(c for c in others if c is not boost)
        for c in others:
            if c is boost:
                c["starter"] = 2
            elif c is skip:
                c["starter"] = 0
            else:
                c["starter"] = 1


def main() -> None:
    cards_raw = json.loads((DATA / "cards.json").read_text(encoding="utf-8"))
    by_id = {}
    for c in cards_raw:
        try:
            oid = int(c["id"])
        except Exception:
            continue
        if oid in by_id:
            continue
        by_id[oid] = c

    shiks = {s["name"]: s for s in json.loads((DATA / "shikigami.json").read_text(encoding="utf-8"))}
    normalize_starters()

    lines = []
    lines.append("/**")
    lines.append(" * 燃灯·尘世·桃源（wave7，25 式神）内容 — 由 scripts/gen-wave7-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE7_PACK_ID = 'wave7';")
    lines.append("export const WAVE7_PACK_NAME = '燃灯·尘世·桃源';")
    lines.append("export const WAVE7_SUBPACKS = Object.freeze({ ranmeng: '燃灯志异', chenshi: '尘世轮回', taoyuan: '桃源故里' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE7_UNIT_DEFINITIONS = Object.freeze([")

    for uid, role, name, title, archetype, color, strategy, subpack in UNITS:
        shik = shiks[name]
        pw, lf = int(shik["power"]), int(shik["life"])
        pid, aid = PASSIVES[uid]
        pid_h = ",\n".join(
            "      { id: %s, event: %s, effect: %s, params: %s }" % (
                js_str(h["id"]), js_str(h["event"]), js_str(h["effect"]),
                json.dumps(h["params"], ensure_ascii=False),
            ) for h in pid["hooks"]
        )
        aid_h = ",\n".join(
            "      { id: %s, event: %s, effect: %s, params: %s }" % (
                js_str(h["id"]), js_str(h["event"]), js_str(h["effect"]),
                json.dumps(h["params"], ensure_ascii=False),
            ) for h in aid["hooks"]
        )
        lines.append("  {")
        lines.append(f"    id: {js_str(uid)},")
        lines.append(f"    name: {js_str(name)},")
        lines.append(f"    title: {js_str(title)},")
        lines.append(f"    role: {js_str(archetype)},")
        lines.append(f"    strategy: {js_str(strategy)},")
        lines.append(f"    maxHp: {lf},")
        lines.append(f"    attack: {pw},")
        lines.append(f"    art: {js_str(f'assets/wave7/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave7/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave7')},")
        lines.append(f"    subpack: {js_str(subpack)},")
        lines.append(f"    officialRole: {js_str(str(role))},")
        lines.append(f"    officialAbility: {js_str(shik.get('ability') or '')},")
        lines.append("    passive: passive(" + js_str(pid["id"]) + ", " + js_str(pid["name"]) + ", " + js_str(pid["text"]) + ", [\n" + pid_h + "\n    ]),")
        lines.append("    awakenedPassive: passive(" + js_str(aid["id"]) + ", " + js_str(aid["name"]) + ", " + js_str(aid["text"]) + ", [\n" + aid_h + "\n    ]),")
        lines.append("  },")

    lines.append("]);")
    lines.append("")
    lines.append("function eff(condition, action, target, value = null) {")
    lines.append("  return { condition, action, target, value };")
    lines.append("}")
    lines.append("")
    lines.append("function wave7Card(officialId, unitId, meta) {")
    lines.append("  const effects = Object.freeze((meta.effects ?? []).map((step) => Object.freeze(eff(step[0], step[1], step[2], step[3] ?? null))));")
    lines.append("  return Object.freeze({")
    lines.append("    id: meta.id ?? `c${officialId}`,")
    lines.append("    unitId,")
    lines.append("    name: meta.name,")
    lines.append("    type: meta.type,")
    lines.append("    typeLabel: ({ combat: '战斗牌', spell: '法术牌', form: '形态牌', realm: '幻境牌', awakening: '觉醒牌' })[meta.type] ?? '牌',")
    lines.append("    level: meta.level,")
    lines.append("    cost: meta.cost ?? 1,")
    lines.append("    copies: meta.deckLimit ?? 2,")
    lines.append("    deckLimit: meta.deckLimit ?? 2,")
    lines.append("    starterCopies: meta.starter ?? 0,")
    lines.append("    rarity: ({ R: 'common', SR: 'rare', SSR: 'ssr', common: 'common', rare: 'rare', ssr: 'ssr' })[meta.rarity] ?? 'common',")
    lines.append("    tags: Object.freeze(meta.tags ?? []),")
    lines.append("    keywords: Object.freeze((meta.keywords ?? []).map((key) => CARD_KEYWORDS[key]).filter(Boolean)),")
    lines.append("    timing: meta.timing ?? 'main',")
    lines.append("    responseTo: Object.freeze(meta.responseTo ?? []),")
    lines.append("    text: meta.text,")
    lines.append("    officialText: meta.officialText ?? meta.text,")
    lines.append("    target: meta.target ?? 'auto',")
    lines.append("    effect: effects[0]?.action ?? 'noop',")
    lines.append("    value: effects[0]?.value ?? null,")
    lines.append("    effects,")
    lines.append("    pack: 'wave7',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE7_CARD_DEFINITIONS = Object.freeze([")

    unit_subpack = {u[0]: u[7] for u in UNITS}
    used_ids = set()
    for official_id, meta in sorted(CARD_MAP.items(), key=lambda kv: (kv[1].get("id") or f"c{kv[0]}", kv[0])):
        unit_id = unit_of(official_id)
        gid = meta.get("id") or f"c{official_id}"
        if gid in used_ids:
            continue
        used_ids.add(gid)
        src = by_id.get(official_id, {})
        meta = dict(meta)
        meta["id"] = gid
        meta["subpack"] = unit_subpack[unit_id]
        meta["officialText"] = (src.get("desc") or meta.get("text") or "").replace("\n", " ")
        body = [
            f"id: {js_str(gid)}",
            f"name: {js_str(meta['name'])}",
            f"type: {js_str(meta['type'])}",
            f"level: {int(meta['level'])}",
            f"cost: {int(meta.get('cost', 1))}",
            f"rarity: {js_str(meta.get('rarity', 'R'))}",
            f"starter: {int(meta.get('starter', 0))}",
            f"deckLimit: {int(meta.get('deck_limit', 2))}",
            f"text: {js_str(meta['text'])}",
            f"officialText: {js_str(meta['officialText'])}",
            f"target: {js_str(meta.get('target', 'auto'))}",
        ]
        if meta.get("keywords"):
            body.append("keywords: [" + ", ".join(js_str(k) for k in meta["keywords"]) + "]")
        if meta.get("timing"):
            body.append(f"timing: {js_str(meta['timing'])}")
        if meta.get("responseTo"):
            body.append("responseTo: [" + ", ".join(js_str(k) for k in meta["responseTo"]) + "]")
        if meta.get("tags"):
            body.append("tags: [" + ", ".join(js_str(t) for t in meta["tags"]) + "]")
        if meta.get("formAbility"):
            body.append(f"formAbility: {js_str(meta['formAbility'])}")
        if meta.get("formHooks"):
            body.append("formHooks: " + json.dumps(meta["formHooks"], ensure_ascii=False))
        if meta.get("combatOption"):
            body.append("combatOption: " + json.dumps(meta["combatOption"], ensure_ascii=False))
        if meta.get("encourage"):
            body.append("encourage: " + json.dumps(meta["encourage"], ensure_ascii=False))
        if meta.get("realm"):
            body.append("realm: " + json.dumps(meta["realm"], ensure_ascii=False))
        effs = meta.get("effects") or []
        eff_s = ",\n".join(
            "      [%s, %s, %s, %s]" % (
                js_str(c), js_str(a), js_str(t),
                json.dumps(v, ensure_ascii=False) if v is not None else "null",
            ) for c, a, t, v in effs
        )
        if eff_s:
            body.append("effects: [\n" + eff_s + ",\n    ]")
        body.append(f"subpack: {js_str(unit_subpack[unit_id])}")
        lines.append(f"  wave7Card({official_id}, {js_str(unit_id)}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    for tok in TOKENS + EXTRA_TOKENS:
        body = [
            f"id: {js_str(tok['id'])}",
            f"name: {js_str(tok['name'])}",
            f"type: {js_str(tok['type'])}",
            f"level: {int(tok['level'])}",
            f"cost: {int(tok.get('cost', 0))}",
            f"rarity: {js_str(tok.get('rarity', 'common'))}",
            f"starter: 0",
            f"deckLimit: 2",
            f"token: true",
            f"text: {js_str(tok['text'])}",
            f"officialText: {js_str(tok['text'])}",
            f"target: {js_str(tok.get('target', 'auto'))}",
            f"tags: [{js_str('token')}]",
        ]
        if tok.get("keywords"):
            body.append("keywords: [" + ", ".join(js_str(k) for k in tok["keywords"]) + "]")
        effs = tok.get("effects") or []
        eff_s = ",\n".join(
            "      [%s, %s, %s, %s]" % (
                js_str(c), js_str(a), js_str(t),
                json.dumps(v, ensure_ascii=False) if v is not None else "null",
            ) for c, a, t, v in effs
        )
        body.append("effects: [\n" + eff_s + ",\n    ]")
        body.append(f"subpack: {js_str(unit_subpack[tok['unitId']])}")
        lines.append(f"  wave7Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave7UnitIds() {")
    lines.append("  return WAVE7_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
