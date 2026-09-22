#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave8.js（祝星·湮灭·千录，25 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id、式神卡。重制式神为独立 unit。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave8.js"

# (uid, role, name, title, archetype, color, strategy, subpack)
UNITS = [
    # 祝星启明 zhuxing
    ("chen", 621, "辰", "行度", "祝星 / 启悟", "#f0d070", "启悟叠祝星，行度调度控场。", "zhuxing"),
    ("tianzhao", 623, "天照", "天晖", "天晖 / 启悟", "#f0c060", "天晖铺启悟区，满三启悟爆发。", "zhuxing"),
    ("yuedu", 622, "月读", "虚月", "启悟 / 控场", "#c0b0e8", "虚假之月扰乱手牌，月烬控场。", "zhuxing"),
    ("gunv", 619, "骨女", "骸骨", "骸 / 转生", "#d0c0b0", "气绝召骸，脱胎换骨反复回场。", "zhuxing"),
    ("yunv", 620, "雨女", "天泪", "启悟 / 回复", "#80b0d0", "启悟回血转甲，雨霖铃团辅。", "zhuxing"),
    ("huang-qiming", 617, "荒·启命", "星河", "启悟 / 追猎", "#90a0f0", "战斗启悟星爆，星猎追猎收割。", "zhuxing"),
    ("zhuiyueshen-shuiyue", 618, "追月神·水月", "流明", "启悟 / 过牌", "#a0c8e8", "启悟调度流明，映月过牌续航。", "zhuxing"),
    ("wushi-maoshi", 624, "武士之灵·猫侍", "武魂", "启悟 / 转生", "#c09080", "武魂形态转生，怨灵斩启悟。", "zhuxing"),
    # 湮灭双生 yanmie
    ("yixienamei", 625, "伊邪那美", "蛇群", "生命1 / 召唤", "#80c080", "压血为一，蛇群围猎爆发。", "yanmie"),
    ("guishibai", 627, "鬼使白", "白符", "复活 / 团辅", "#d0e0f0", "复活触发团辅，点灯锁复活。", "yanmie"),
    ("guishihei", 628, "鬼使黑", "黑刃", "击杀成长 / 追猎", "#606080", "战斗击杀永久成长，索魂追猎。", "yanmie"),
    ("tongnantongnv", 632, "童男童女", "羽护", "护甲 / 战力", "#e0c0a0", "叠甲转战力，羽护攻守一体。", "yanmie"),
    ("zhiwu", 633, "纸舞", "落纸", "灵咒 / 投射", "#f0e0d0", "灵咒结附投射，纸刃叠伤。", "yanmie"),
    ("daorenshen", 626, "盗人神", "财宝", "财宝 / 直击", "#d0a060", "打脸取宝，财宝增强终结。", "yanmie"),
    ("ertong", 631, "二瞳", "猫灵", "幻境 / 占卜", "#a0d0c0", "幻境占卜过牌，猫灵铃压制。", "yanmie"),
    ("yingcao-pupu", 630, "萤草·蒲蒲", "光种", "形态 / 投射", "#b0e080", "光种形态连打，投射补伤。", "yanmie"),
    ("mianqiling-xinsu", 629, "面灵气·心宿", "面相", "派系 / 爆发", "#e0a0c0", "多派系面相，面由心生叠效。", "yanmie"),
    # 千录晴诗 qianlu
    ("fansi", 638, "饭笥", "饱足", "饱足 / 成长", "#e0b070", "饱足叠层，神明料理复用。", "qianlu"),
    ("longzi", 634, "泷", "溢能", "充能 / 溢能", "#70b0e0", "充能溢能减耗，决荡连打。", "qianlu"),
    ("maochuan", 639, "猫川", "代价", "投射 / 代价", "#c0a070", "首用投射，代价牌高收益。", "qianlu"),
    ("alaina", 641, "阿莱娜", "灵咒", "灵咒 / 投射", "#d0a0d0", "灵咒附库投射，沙之书锁场。", "qianlu"),
    ("youning", 640, "攸宁", "诗乐", "鼓舞 / 过牌", "#a0c0a0", "异名手牌鼓舞，诗经复用。", "qianlu"),
    ("xiaolunan-qianshou", 635, "小鹿男·千守", "森灵", "转生 / 溢能", "#80b070", "气绝转森之灵，溢能续航。", "qianlu"),
    ("rihefang-qingyang", 637, "日和坊·晴阳", "晴阳", "充能 / 溢能", "#f0c080", "代付能量，晴之姿团辅。", "qianlu"),
    ("yanyanluo-fumiao", 636, "烟烟罗·浮缈", "浮缈", "充能 / 溢能", "#c0a0b0", "溢能投射，烟霞群伤。", "qianlu"),
]

ROLE_TO_UID = {role: uid for uid, role, *_ in UNITS}
# 官方 id 特例：若出现不满足 role*100 的 id，在此覆盖
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
# 简化原则同 wave6；officialText 保留原文。starter 合计=8，SSR starter=0，觉醒恰好 1 张。
CARD_MAP: dict[int, dict] = {
    # ---- 荒·启命 617 ----
    61701: C("命运星河", "realm", 1, 1, "SR", 1,
             "幻境（耐久 6）：进场获得迅捷。己方回合开始时，对敌方前线造成 2 点伤害（星诫增伤简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             keywords=["INSTANT"], tags=["幻境", "启悟", "星爆"]),
    61702: C("星归", "spell", 1, 1, "R", 2,
             "启悟简化：占卜 2 并抽一张牌，将两张「星爆」简化为投射伤害。",
             [("always", "divination", "ally-player", 2), ("always", "draw", "ally-player", 1), ("always", "damage-enemy-front", "auto", 1)],
             tags=["启悟", "星爆", "占卜"]),
    61703: C("星流", "combat", 1, 1, "R", 1,
             "出击 +2。穿刺。未启悟使用后置入启悟区（简化为抽一张牌）。",
             [("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
             keywords=["PIERCE"], tags=["穿刺", "启悟", "出击"]),
    61704: C("神赐之日", "awakening", 2, 1, "SR", 1,
             "对敌方前线造成 3 点伤害。觉醒：+2/+2，回合开始对敌方前线造成 2 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3)],
             deck_limit=1, tags=["觉醒", "启悟", "星爆"]),
    61705: C("星猎", "combat", 2, 1, "R", 1,
             "出击 +3。追猎，疾速。",
             [("source-ready", "assault", "source", 3)],
             keywords=["FIRST_STRIKE"], tags=["出击", "追猎", "疾速"]),
    61706: C("星辰之旅", "form", 2, 1, "R", 1,
             "获得 +3/+3。使用启悟区的牌简化：己方回合开始时抽一张牌并获得 1 点护甲。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，抽一张牌并获得 1 点护甲。",
             formHooks=[
                 {"id": "form-huang-star-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-huang-star-shield", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40},
             ],
             tags=["形态", "启悟", "战力"]),
    61707: C("千年之守", "form", 3, 2, "R", 1,
             "获得 +4/+5。法术命中后反击简化：完成交战后，对敌方前线造成 2 点伤害。",
             [("always", "form", "source", F(4, 5))],
             formAbility="完成交战后，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-huang-guard", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "启悟", "终结"]),
    61708: C("星云黑洞", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，对敌方前线造成 3 点伤害并抽一张牌（启悟区中立免费简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "damage-enemy-front", "value": 3},
                 {"effect": "draw", "value": 1},
             ]},
             deck_limit=2, tags=["幻境", "启悟", "终结"]),

    # ---- 追月神·水月 618 ----
    61801: C("携月", "spell", 1, 1, "R", 2,
             "启悟简化：占卜 2 并抽一张牌，调度手牌资源。",
             [("always", "divination", "ally-player", 2), ("always", "draw", "ally-player", 1)],
             tags=["启悟", "过牌", "调度"]),
    61802: C("映月", "spell", 1, 1, "R", 1,
             "抽一张牌并获得 1 点鬼火（置入启悟区简化）。",
             [("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
             tags=["启悟", "过牌", "鬼火"]),
    61803: C("鉴明舞", "form", 1, 1, "SR", 1,
             "获得 +2/+3。己方回合开始时，抽一张牌（启悟区堆叠简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-yue-dance", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "启悟", "过牌"]),
    61804: C("罪月", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 5 点伤害，并对所有敌方式神造成 1 点伤害（二选一合并）。",
             [("always", "damage", "selected-enemy", 5), ("always", "damage", "all-enemy-units", 1)],
             tags=["伤害", "启悟", "群伤"]),
    61805: C("飞彩凝辉", "spell", 3, 2, "SSR", 0,
             "启悟后抽满简化：抽三张牌，并对敌方前线造成 3 点伤害。",
             [("always", "draw", "ally-player", 3), ("always", "damage-enemy-front", "auto", 3)],
             deck_limit=2, tags=["启悟", "过牌", "终结"]),
    61806: C("对月歌", "form", 2, 1, "SR", 1,
             "获得 +3/+3。手牌与启悟区对换简化：己方回合开始时，抽一张牌并获得 1 点力量。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，抽一张牌并获得 1 点力量。",
             formHooks=[
                 {"id": "form-yue-song-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-yue-song-buff", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
             ],
             tags=["形态", "启悟", "过牌"]),
    61807: C("流晖濯明", "awakening", 3, 1, "SR", 1,
             "抽两张牌。觉醒：+2/+2，回合开始获得 1 点力量并抽一张牌（溯光简化）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "启悟", "溯光"]),
    61808: C("引月", "spell", 2, 0, "R", 1,
             "瞬发。占卜 1，抽一张牌，若启悟使用则获得 1 点鬼火（简化为直接获得鬼火）。",
             [("always", "divination", "ally-player", 1), ("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "启悟", "占卜"]),

    # ---- 骨女 619 ----
    61901: C("怨生", "combat", 1, 1, "R", 2,
             "出击 +2。追猎。本次战斗若骨女气绝，消灭对方简化为重伤。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "selected-enemy", 2)],
             keywords=["FIRST_STRIKE"], tags=["出击", "追猎", "骸"]),
    61902: C("赤霞鸟", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，为己方前线获得 2 点护甲（骸召唤简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 2},
             tags=["幻境", "坚守", "骸"]),
    61903: C("借皮", "spell", 1, 1, "R", 1,
             "眩晕一个敌方式神，并为骨女恢复 3 点生命（召骸简化）。",
             [("always", "freeze", "selected-enemy", 1), ("always", "heal", "source", 3)],
             keywords=["STUN"], tags=["眩晕", "治疗", "骸"]),
    61904: C("骨刃", "spell", 2, 1, "SR", 1,
             "消灭一个敌方式神简化：对一个敌方式神造成 6 点伤害。",
             [("always", "damage", "selected-enemy", 6)],
             tags=["消灭", "伤害", "骸"]),
    61905: C("觉醒·骨女", "awakening", 2, 1, "SR", 1,
             "气绝时可用：召唤一个「骸」简化为获得 3 点护甲。觉醒：+2/+2，气绝倒计时压缩简化为不屈。",
             [("always", "awaken", "source", F(2, 2)), ("always", "shield", "source", 3)],
             deck_limit=1, keywords=["UNYIELDING"], tags=["觉醒", "骸", "转生"]),
    61906: C("脱胎换骨", "form", 2, 1, "R", 1,
             "获得 +2/+4。气绝时可用：复活骨女（简化并入形态）。",
             [("always", "form", "source", F(2, 4)), ("always", "revive", "source", 1)],
             tags=["形态", "复活", "骸"]),
    61907: C("一步一息", "combat", 3, 1, "R", 1,
             "出击 +3。追猎。眩晕被攻击的式神。",
             [("source-ready", "assault", "source", 3), ("always", "freeze", "selected-enemy", 1)],
             keywords=["FIRST_STRIKE", "STUN"], tags=["出击", "追猎", "眩晕"]),
    61908: C("帐下梦", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，对敌方前线造成 2 点伤害，并为所有己方式神恢复 1 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "damage-enemy-front", "value": 2},
             ]},
             deck_limit=2, tags=["幻境", "骸", "终结"]),

    # ---- 雨女 620 ----
    62001: C("相思泪", "spell", 1, 0, "R", 2,
             "瞬发。启悟简化：抽一张牌，并为你恢复 1 点生命。",
             [("always", "draw", "ally-player", 1), ("always", "heal-avatar", "ally-avatar", 1)],
             keywords=["INSTANT"], tags=["瞬发", "启悟", "过牌"]),
    62002: C("断桥", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：进场时启悟简化。己方回合开始时，为己方前线获得 2 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 2},
             tags=["幻境", "启悟", "坚守"]),
    62003: C("雨未歇", "form", 1, 1, "SR", 1,
             "获得 +2/+4。进场启悟，为你恢复 2 点生命。",
             [("always", "form", "source", F(2, 4)), ("always", "heal-avatar", "ally-avatar", 2)],
             tags=["形态", "启悟", "天之泪"]),
    62004: C("望君还", "spell", 2, 1, "R", 1,
             "启悟简化：抽两张牌，并为你恢复 2 点生命。",
             [("always", "draw", "ally-player", 2), ("always", "heal-avatar", "ally-avatar", 2)],
             tags=["启悟", "过牌", "治疗"]),
    62005: C("觉醒·雨女", "awakening", 2, 1, "SR", 1,
             "为你恢复 5 点生命。觉醒：+1/+3，使用启悟区的牌简化为回合开始为所有己方恢复 1 点生命。",
             [("always", "awaken", "source", F(1, 3)), ("always", "heal-avatar", "ally-avatar", 5)],
             deck_limit=1, tags=["觉醒", "启悟", "治疗"]),
    62006: C("梨花怨", "spell", 2, 1, "SR", 1,
             "对一个敌方式神造成 4 点伤害，或恢复一个己方角色 4 点生命（启悟区数量简化）。",
             [("always", "damage", "selected-enemy", 4), ("always", "heal", "selected-ally", 4)],
             tags=["伤害", "治疗", "启悟"]),
    62007: C("雨霖铃", "spell", 3, 1, "R", 1,
             "瞬发。复活所有己方气绝式神简化为复活一个己方式神，并抽一张牌。",
             [("always", "revive-all", "ally-player", 1), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "复活", "启悟"]),
    62008: C("雨居", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，启悟抽牌简化为抽一张牌并为你恢复 2 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "draw", "value": 1},
             ]},
             deck_limit=2, tags=["幻境", "启悟", "终结"]),

    # ---- 辰 621 ----
    62101: C("行度", "spell", 1, 0, "R", 2,
             "瞬发。启悟简化：占卜 1 并抽一张牌（祝星牌置入启悟区）。",
             [("always", "divination", "ally-player", 1), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "启悟", "祝星"]),
    62102: C("祝星捷辰", "form", 1, 1, "SR", 1,
             "获得 +2/+3。己方回合开始时，对随机敌方造成 1 点伤害（祝星联动简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-chen-burst", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "启悟", "祝星"]),
    62103: C("双星", "spell", 1, 1, "R", 1,
             "启悟简化：抽两张牌（复制祝星牌）。",
             [("always", "draw", "ally-player", 2)],
             tags=["启悟", "祝星", "过牌"]),
    62104: C("星星之火", "form", 2, 1, "R", 1,
             "获得 +3/+3。增强简化：己方回合开始时获得 1 点力量（启悟区祝星叠层）。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，获得 1 点力量。",
             formHooks=[{"id": "form-chen-spark", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "增强", "祝星"]),
    62105: C("换斗", "spell", 2, 1, "R", 1,
             "启悟简化：占卜 2 并抽一张牌，随机造成 2 点伤害。",
             [("always", "divination", "ally-player", 2), ("always", "draw", "ally-player", 1), ("always", "damage", "selected-enemy", 2)],
             tags=["启悟", "祝星", "占卜"]),
    62106: C("星天外", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，若祝星简化：抽一张牌；否则对敌方前线造成 1 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             keywords=["INSTANT"], tags=["幻境", "启悟", "祝星"]),
    62107: C("守门人", "form", 3, 2, "SSR", 0,
             "获得 +3/+6。不屈。受到致命伤害简化为回合开始获得 3 点护甲。",
             [("always", "form", "source", F(3, 6)), ("always", "shield", "source", 3)],
             deck_limit=2, keywords=["UNYIELDING"], tags=["形态", "启悟", "终结"]),
    62108: C("觉醒·辰", "awakening", 3, 1, "SR", 1,
             "启悟简化：抽两张牌。觉醒：+1/+2，回合开始占卜 1。",
             [("always", "awaken", "source", F(1, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "启悟", "祝星"]),

    # ---- 月读 622 ----
    62201: C("谎言", "spell", 1, 1, "R", 2,
             "抽一张牌，并对一个敌方式神造成 2 点伤害（虚假之月简化）。",
             [("always", "draw", "ally-player", 1), ("always", "damage", "selected-enemy", 2)],
             tags=["启悟", "虚假之月", "过牌"]),
    62202: C("空亡", "spell", 1, 1, "R", 1,
             "投射：造成 3 点伤害，并使目标获得 1 点破甲。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "apply-armor-break", "selected-enemy", 1)],
             keywords=["PROJECTILE"], tags=["投射", "启悟", "破甲"]),
    62203: C("月烬天极", "form", 1, 1, "SR", 1,
             "获得 +2/+4。迅捷。敌方使用启悟区的牌简化：敌方回合开始时抽一张牌。",
             [("always", "form", "source", F(2, 4))],
             formAbility="敌方回合开始时，抽一张牌（压制启悟简化）。",
             formHooks=[{"id": "form-yuedu-veil", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             keywords=["INSTANT"], tags=["形态", "启悟", "压制"]),
    62204: C("觉醒·月读", "awakening", 3, 1, "SR", 1,
             "对所有敌方式神造成 2 点伤害。觉醒：+2/+2，迅捷，回合开始随机对敌方造成 2 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=1, keywords=["INSTANT"], tags=["觉醒", "虚假之月", "启悟"]),
    62205: C("虚诞月落", "spell", 2, 1, "R", 1,
             "响应：被攻击时自动使用。对敌方前线造成 3 点伤害（反制虚假之月简化）。",
             [("always", "damage-enemy-front", "auto", 3)],
             keywords=["RESPONSE"], timing="response", responseTo=["assault", "damage"],
             tags=["响应", "虚假之月", "启悟"]),
    62206: C("月烬宵宴", "form", 2, 1, "SR", 1,
             "获得 +3/+4。进场选择眩晕一个敌方式神，并对其造成 2 点伤害。",
             [("always", "form", "source", F(3, 4)), ("always", "freeze", "selected-enemy", 1), ("always", "damage", "selected-enemy", 2)],
             keywords=["STUN"], tags=["形态", "眩晕", "虚假之月"]),
    62207: C("惑星", "spell", 2, 1, "R", 1,
             "对所有敌方式神造成 2 点伤害，并对敌方牌手造成 1 点伤害。",
             [("always", "damage", "all-enemy-units", 2), ("always", "damage", "enemy-avatar", 1)],
             tags=["群伤", "虚假之月", "启悟"]),
    62208: C("无光月海", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，对敌方前线造成 2 点伤害并抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "damage-enemy-front", "value": 2},
                 {"effect": "draw", "value": 1},
             ]},
             deck_limit=2, tags=["幻境", "虚假之月", "终结"]),

    # ---- 天照 623 ----
    62301: C("光涤", "spell", 1, 1, "R", 2,
             "启悟简化：抽两张牌，并对一个敌方式神造成 2 点伤害（天晖附着）。",
             [("always", "draw", "ally-player", 2), ("always", "damage", "selected-enemy", 2)],
             tags=["启悟", "天晖", "过牌"]),
    62302: C("太阳女神", "form", 1, 1, "SR", 1,
             "获得 +2/+4。己方回合开始时，抽一张牌并造成 1 点伤害（天晖置入启悟区）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，抽一张牌并对敌方前线造成 1 点伤害。",
             formHooks=[
                 {"id": "form-tenka-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-tenka-dmg", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40},
             ],
             tags=["形态", "启悟", "天晖"]),
    62303: C("刑神场", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：进场启悟。己方回合开始时，抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "启悟", "天晖"]),
    62304: C("无灭", "spell", 2, 1, "R", 1,
             "对一个式神造成 5 点伤害，并抽一张牌（天晖置入启悟区）。",
             [("always", "damage", "selected-enemy", 5), ("always", "draw", "ally-player", 1)],
             tags=["伤害", "启悟", "天晖"]),
    62305: C("觉醒·天照", "awakening", 2, 1, "SR", 1,
             "抽两张牌。觉醒：+2/+2，回合开始对敌方前线造成 2 点伤害并抽一张牌（天晖≥3启悟）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "天晖", "启悟"]),
    62306: C("神圣裁决", "form", 2, 1, "SR", 1,
             "获得 +3/+3。进场启悟并抽两张牌（天晖投射翻倍简化）。",
             [("always", "form", "source", F(3, 3)), ("always", "draw", "ally-player", 2)],
             formAbility="己方回合开始时，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-tenka-judge", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "天晖", "投射"]),
    62307: C("神光", "spell", 3, 0, "R", 1,
             "瞬发。启悟简化：抽三张牌，并对敌方前线造成 2 点伤害。",
             [("always", "draw", "ally-player", 3), ("always", "damage-enemy-front", "auto", 2)],
             keywords=["INSTANT"], tags=["瞬发", "启悟", "天晖"]),
    62308: C("高天原", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，抽一张牌并为所有己方式神恢复 1 点生命（天晖复活简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "draw", "value": 1},
                 {"effect": "shield-all-allies", "value": 1},
             ]},
             deck_limit=2, tags=["幻境", "天晖", "终结"]),

    # ---- 武士之灵·猫侍 624 ----
    62401: C("初心", "combat", 1, 1, "R", 2,
             "出击 +2。未启悟使用时将「武士之心」简化为抽一张牌。",
             [("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
             tags=["出击", "启悟", "武士之心"]),
    62402: C("默想", "spell", 1, 0, "R", 1,
             "瞬发。启悟简化：抽一张牌并获得 1 点鬼火。",
             [("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "启悟", "默想"]),
    62403: C("五条渡口", "realm", 1, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害（消灭形态/幻境简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "压制", "武魂"]),
    62404: C("武士之魂", "awakening", 2, 1, "SR", 1,
             "气绝时可用：复活自己（武魂形态简化）。觉醒：+2/+2，回合开始获得 1 点力量。",
             [("always", "awaken", "source", F(2, 2)), ("always", "revive", "source", 1)],
             deck_limit=1, tags=["觉醒", "武魂", "启悟"]),
    62405: C("生灵斩", "combat", 2, 1, "R", 1,
             "出击 +3。增强简化：获得 2 点护甲（敌方未气绝数量）。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
             tags=["出击", "怨灵斩", "增强"]),
    62406: C("诛心", "combat", 2, 1, "SR", 1,
             "出击 +4。贯通。未启悟使用时将「灭魂」简化为对敌方牌手造成 2 点伤害。",
             [("source-ready", "assault", "source", 4), ("always", "damage", "enemy-avatar", 2)],
             keywords=["PIERCE"], tags=["出击", "必杀", "启悟"]),
    62407: C("忠义无双", "spell", 3, 2, "SSR", 0,
             "不消耗鬼火简化为 0 费无效，此处：复活自己并获得迅捷与力量（双选一合并）。",
             [("always", "revive", "source", 1), ("always", "buff-stats", "source", F(2, 2)), ("always", "shield", "source", 2)],
             deck_limit=2, tags=["迅捷", "昂扬", "启悟"]),
    62408: C("武藏", "combat", 3, 1, "R", 1,
             "出击 +5。直击。抽到置入启悟区简化：抽一张牌。",
             [("source-ready", "assault", "source", 5), ("always", "draw", "ally-player", 1)],
             tags=["出击", "直击", "启悟"]),

    # ---- 伊邪那美 625 ----
    62501: C("灭世之舞", "form", 1, 1, "R", 2,
             "获得 +2/+2。完成交战后，使交战目标获得 2 点破甲（生命变为1简化）。",
             [("always", "form", "source", F(2, 2))],
             formAbility="完成交战后，使交战目标获得 2 点破甲。",
             formHooks=[{"id": "form-izanami-dance", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "蛇群", "破甲"]),
    62502: C("虚无之海", "realm", 1, 1, "SR", 1,
             "幻境（耐久 6）：进场使一个式神获得不屈。己方回合开始时，为所有己方式神获得 1 点护甲。",
             [("always", "grant-unyielding", "selected-ally", None), ("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             keywords=["UNYIELDING"], tags=["幻境", "不屈", "蛇群"]),
    62503: C("创造", "spell", 1, 0, "R", 1,
             "瞬发。召唤「蛇群」简化：对一个敌方式神造成 2 点伤害并获得 1 点力量。",
             [("always", "damage", "selected-enemy", 2), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "蛇群", "战技"]),
    62504: C("觉醒·伊邪那美", "awakening", 2, 1, "SR", 1,
             "对一个敌方式神造成 3 点伤害。觉醒：+1/+2，生命变为1简化为完成交战后目标 -2 护甲。",
             [("always", "awaken", "source", F(1, 2)), ("always", "damage", "selected-enemy", 3)],
             deck_limit=1, tags=["觉醒", "蛇群", "生命1"]),
    62505: C("毁灭女神", "form", 2, 1, "R", 1,
             "获得 +3/+3。进场和回合开始使力量最大敌方攻击为0简化：己方回合开始时，随机敌方 -2 力量。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，随机敌方 -2 力量（生命变为1简化）。",
             formHooks=[{"id": "form-izanami-ruin", "event": "turn-started", "effect": "passive-armor-break-enemy-on-damage", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "生命1", "压制"]),
    62506: C("破坏", "spell", 2, 1, "R", 1,
             "对一个式神造成 4 点伤害，若是青岚简化：额外造成 2 点伤害。",
             [("always", "damage", "selected-enemy", 4), ("always", "damage", "selected-enemy", 2)],
             tags=["伤害", "蛇群", "破坏"]),
    62507: C("采撷", "spell", 3, 1, "SR", 1,
             "敌方每有一个未气绝式神便造成伤害简化：对所有敌方式神造成 2 点伤害。",
             [("always", "damage", "all-enemy-units", 2)],
             tags=["蛇群", "群伤", "采撷"]),
    62508: C("神赐之吻", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。贯通。不屈。生命为1免疫简化：进场获得 3 点护甲。",
             [("always", "form", "source", F(4, 4)), ("always", "shield", "source", 3)],
             deck_limit=2, keywords=["PIERCE", "UNYIELDING"], tags=["形态", "蛇群", "终结"]),

    # ---- 盗人神 626 ----
    62601: C("攻无备", "combat", 1, 1, "R", 2,
             "出击 +3。直击。使用过财宝简化：本次攻击获得必杀。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 2)],
             tags=["出击", "直击", "财宝"]),
    62602: C("爪留情", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害，并抽一张牌（财宝简化）。",
             [("always", "damage", "selected-enemy", 3), ("always", "draw", "ally-player", 1)],
             tags=["伤害", "财宝", "过牌"]),
    62603: C("日行盗", "form", 1, 1, "SR", 1,
             "获得 +2/+4。使用财宝叠战力简化：完成交战后获得 1 点力量。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，获得 1 点力量。",
             formHooks=[{"id": "form-daoren-day", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "财宝", "战力"]),
    62604: C("珍宝阁", "realm", 2, 1, "R", 1,
             "幻境（耐久 6）：进场和回合开始抽牌简化为己方回合开始时，抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "财宝", "过牌"]),
    62605: C("如期至", "combat", 2, 1, "R", 1,
             "出击 +3。追猎，贯通。使用过财宝简化：获得 2 点护甲。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
             keywords=["PIERCE", "FIRST_STRIKE"], tags=["出击", "追猎", "财宝"]),
    62606: C("夜行偷", "form", 2, 1, "SR", 1,
             "获得 +3/+3。迅捷。弃牌得宝简化：进场抽一张牌。",
             [("always", "form", "source", F(3, 3)), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["形态", "迅捷", "财宝"]),
    62607: C("觉醒·盗人神", "awakening", 3, 1, "SR", 1,
             "对敌方牌手造成 3 点伤害。觉醒：+2/+2，完成交战后对敌方牌手造成 2 点伤害（巨额财宝简化）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "enemy-avatar", 3)],
             deck_limit=1, tags=["觉醒", "财宝", "直击"]),
    62608: C("断予尾", "spell", 3, 2, "SSR", 0,
             "随机攻击简化：对所有敌方式神造成 3 点伤害，并对敌方牌手造成 3 点伤害。",
             [("always", "damage", "all-enemy-units", 3), ("always", "damage", "enemy-avatar", 3)],
             deck_limit=2, keywords=["CRIT"], tags=["暴击", "戏法", "财宝"]),

    # ---- 鬼使白 627 ----
    62701: C("金符密诏", "spell", 1, 1, "R", 2,
             "复活一个己方式神，并使其获得 1 点力量（移动/消灭二选合并简化）。",
             [("always", "revive", "knocked-ally", 1), ("always", "buff-stats", "selected-ally", F(1, 0))],
             tags=["复活", "白符", "团辅"]),
    62702: C("别父日", "realm", 1, 1, "SR", 1,
             "幻境（耐久 6）：进场坚守：+1/+1 简化。己方回合开始时，为所有己方式神获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "坚守", "复活"]),
    62703: C("少时月白", "form", 1, 1, "R", 1,
             "获得 +2/+4。气绝时可用，进场复活自己。",
             [("always", "form", "source", F(2, 4)), ("always", "revive", "source", 1)],
             keywords=["INSTANT"], tags=["形态", "复活", "瞬发"]),
    62704: C("归魂入窍", "spell", 2, 1, "R", 1,
             "复活一个己方式神，若是红莲简化：使其发起攻击（改为获得 2 点力量）。",
             [("always", "revive", "knocked-ally", 1), ("always", "buff-stats", "selected-ally", F(2, 0))],
             tags=["复活", "白符", "派系"]),
    62705: C("离魂善后", "spell", 2, 1, "SR", 1,
             "对一个敌方式神造成 3 点伤害，然后复活一个己方式神并抽一张牌。",
             [("always", "damage", "selected-enemy", 3), ("always", "revive", "knocked-ally", 1), ("always", "draw", "ally-player", 1)],
             tags=["消灭", "复活", "过牌"]),
    62706: C("点灯人", "form", 2, 1, "R", 1,
             "获得 +3/+3。敌方气绝不复活简化：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-guishi-lamp", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "压制", "复活"]),
    62707: C("觉醒·鬼使白", "awakening", 3, 1, "SR", 1,
             "复活一个己方式神。觉醒：+1/+3，己方式神复活时获得力量并造成伤害简化为回合开始对敌方前线 2 点。",
             [("always", "awaken", "source", F(1, 3)), ("always", "revive", "knocked-ally", 1)],
             deck_limit=1, tags=["觉醒", "复活", "战力"]),
    62708: C("借尸还魂", "spell", 3, 2, "SSR", 0,
             "消灭一个敌方式神简化：对一个敌方式神造成 8 点伤害，然后双方各复活一个式神简化为复活一个己方。",
             [("always", "damage", "selected-enemy", 8), ("always", "revive", "knocked-ally", 1)],
             deck_limit=2, tags=["消灭", "复活", "终结"]),

    # ---- 鬼使黑 628 ----
    62801: C("返魄回体", "combat", 1, 1, "R", 2,
             "出击 +2。气绝时可用：复活自己（并随机复活苍叶简化）。",
             [("source-ready", "assault", "source", 2), ("always", "revive", "source", 1)],
             tags=["出击", "复活", "黑刃"]),
    62802: C("少时黑羽", "form", 1, 1, "SR", 1,
             "获得 +2/+4。索魂简化：完成交战后使目标 -1 力量，自身免疫战斗伤简化为 +1 护甲。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，使交战目标 -1 力量，并获得 1 点护甲。",
             formHooks=[
                 {"id": "form-guishi-feather-brk", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 1}, "priority": 40},
                 {"id": "form-guishi-feather-sh", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 1}, "priority": 40},
             ],
             tags=["形态", "索魂", "成长"]),
    62803: C("辞母时", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，随机使敌方准备区式神结附索魂简化为对敌方前线造成 1 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "索魂", "贯通"]),
    62804: C("守夜人", "form", 2, 1, "R", 1,
             "获得 +3/+3。击杀重置简化：完成交战后获得 1 点鬼火。",
             [("always", "form", "source", F(3, 3))],
             formAbility="完成交战后，获得 1 点鬼火。",
             formHooks=[{"id": "form-guishi-watch", "event": "combat-resolved", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "索魂", "成长"]),
    62805: C("觉醒·鬼使黑", "awakening", 2, 1, "SR", 1,
             "对一个敌方式神造成 4 点伤害。觉醒：+2/+1，战斗中消灭式神永久+1力量简化为回合开始 +1 力量。",
             [("always", "awaken", "source", F(2, 1)), ("always", "damage", "selected-enemy", 4)],
             deck_limit=1, tags=["觉醒", "索魂", "成长"]),
    62806: C("漆黑长刃", "combat", 2, 1, "R", 1,
             "出击 +4。疾速。消灭式神额外成长简化：获得 1 点力量。",
             [("source-ready", "assault", "source", 4), ("always", "buff-stats", "source", F(1, 1))],
             keywords=["FIRST_STRIKE"], tags=["出击", "疾速", "成长"]),
    62807: C("锁魂夺魄", "spell", 3, 0, "SR", 1,
             "瞬发。使所有敌方式神结附索魂并力量变为0简化：对所有敌方式神造成 2 点伤害。",
             [("always", "damage", "all-enemy-units", 2), ("always", "debuff-stats", "all-enemy-units", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "索魂", "群伤"]),
    62808: C("天下太平", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。迅捷，贯通。帷幕简化：获得 3 点护甲。",
             [("always", "form", "source", F(4, 4)), ("always", "shield", "source", 3)],
             deck_limit=2, keywords=["INSTANT", "PIERCE"], tags=["形态", "贯通", "终结"]),

    # ---- 面灵气·心宿 629 ----
    62901: C("相生表里", "spell", 1, 1, "R", 2,
             "使一个己方式神发起攻击简化：为一个己方式神获得 3 点护甲与不屈。",
             [("always", "shield", "selected-ally", 3), ("always", "grant-unyielding", "selected-ally", None)],
             keywords=["UNYIELDING"], tags=["派系", "必杀", "不屈"]),
    62902: C("婴儿面具", "spell", 1, 1, "R", 1,
             "对一个式神造成等同于派系数量的伤害简化：造成 3 点伤害。",
             [("always", "damage", "selected-enemy", 3)],
             tags=["伤害", "面相", "派系"]),
    62903: C("面观四相", "form", 1, 1, "SR", 1,
             "获得 +2/+4。派系形态简化：完成交战后，随机对敌方造成 1 点伤害。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-mask-four", "event": "combat-resolved", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "面相", "派系"]),
    62904: C("潜识之面", "spell", 2, 1, "R", 1,
             "随机检索各派系牌简化：抽两张牌。",
             [("always", "draw", "ally-player", 2)],
             tags=["起源", "过牌", "面相"]),
    62905: C("无识之面", "spell", 2, 1, "SR", 1,
             "使己方各派系式神攻击简化：对所有敌方式神造成 2 点伤害。",
             [("always", "damage", "all-enemy-units", 2)],
             tags=["群伤", "面相", "派系"]),
    62906: C("面由心生", "awakening", 2, 1, "SR", 1,
             "为所有己方式神获得 2 点力量。觉醒：+1/+2，使用手牌叠派系效果简化为回合开始随机对敌方 1 点伤害。",
             [("always", "awaken", "source", F(1, 2)), ("always", "buff-stats", "all-ally-units", F(2, 0))],
             deck_limit=1, tags=["觉醒", "面相", "派系"]),
    62907: C("母亲面具", "spell", 3, 1, "R", 1,
             "消灭一个式神简化：对一个敌方式神造成 6 点伤害，并复活一个己方式神。",
             [("always", "damage", "selected-enemy", 6), ("always", "revive", "knocked-ally", 1)],
             tags=["消灭", "复活", "面相"]),
    62908: C("面面相窥", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。派系轮转简化：己方回合开始时，抽一张牌并为所有己方恢复 1 点生命。",
             [("always", "form", "source", F(4, 4))],
             formAbility="己方回合开始时，抽一张牌并为所有己方恢复 1 点生命。",
             formHooks=[
                 {"id": "form-mask-gaze-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-mask-gaze-heal", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "派系", "终结"]),

    # ---- 萤草·蒲蒲 630 ----
    63001: C("一起回家", "spell", 1, 1, "R", 2,
             "将一个形态移回手上简化：使一个敌方式神获得 3 点破甲并抽一张牌。",
             [("always", "apply-armor-break", "selected-enemy", 3), ("always", "draw", "ally-player", 1)],
             tags=["形态", "弹回", "光种"]),
    63002: C("洞悉之种", "form", 1, 1, "SR", 1,
             "获得 +2/+3。瞬发。进场投射：造成 2 点伤害（治愈之光）。",
             [("always", "form", "source", F(2, 3)), ("always", "damage-enemy-front", "auto", 2)],
             keywords=["INSTANT", "PROJECTILE"], tags=["形态", "投射", "光种"]),
    63003: C("风的方向", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌（形态进场过牌简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "过牌", "光种"]),
    63004: C("力量之种", "form", 2, 1, "SR", 1,
             "获得 +3/+3。瞬发。进场对敌方前线造成 3 点伤害并 -2 力量（勇气之光）。",
             [("always", "form", "source", F(3, 3)), ("always", "damage-enemy-front", "auto", 3), ("always", "debuff-stats", "selected-enemy", F(2, 0))],
             keywords=["INSTANT"], tags=["形态", "勇气", "光种"]),
    63005: C("心愿达成", "spell", 2, 1, "R", 1,
             "穿刺。对一个敌方式神造成 5 点伤害，并移除其形态简化为 2 点破甲。",
             [("always", "damage", "selected-enemy", 5), ("always", "apply-armor-break", "selected-enemy", 2)],
             keywords=["PIERCE"], tags=["穿刺", "伤害", "光种"]),
    63006: C("菡蒲蒲之约", "awakening", 3, 1, "SR", 1,
             "为所有己方恢复 2 点生命。觉醒：+1/+3，触发形态进场效果简化为回合开始随机对敌方 2 点伤害。",
             [("always", "awaken", "source", F(1, 3)), ("always", "heal", "all-ally-units", 2)],
             deck_limit=1, tags=["觉醒", "形态", "光种"]),
    63007: C("神奇四叶草", "realm", 2, 1, "R", 1,
             "幻境（耐久 6）：己方回合开始时，为己方前线获得 2 点护甲（形态攻击简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 2},
             tags=["幻境", "戏法", "光种"]),
    63008: C("醒神之种", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。瞬发。进场对敌方前线造成 3 点伤害，并对敌方牌手造成 3 点伤害（安魂之光）。",
             [("always", "form", "source", F(4, 4)), ("always", "damage-enemy-front", "auto", 3), ("always", "damage", "enemy-avatar", 3)],
             deck_limit=2, keywords=["INSTANT"], tags=["形态", "投射", "终结"]),

    # ---- 童男童女 632 ----
    63201: C("羽护", "spell", 1, 1, "R", 2,
             "为一个己方式神 +3 护甲，并发起攻击简化为抽一张牌（护甲≥3）。",
             [("always", "shield", "selected-ally", 3), ("always", "draw", "ally-player", 1)],
             tags=["护甲", "战力", "羽护"]),
    63202: C("童羽歌", "spell", 1, 0, "R", 1,
             "瞬发。为一个己方式神 +1 护甲，或占卜 1（合并为护甲+占卜）。",
             [("always", "shield", "selected-ally", 1), ("always", "divination", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "护甲", "占卜"]),
    63203: C("命魂祭献", "form", 3, 2, "SSR", 0,
             "获得 +2/+5。进场为一个己方式神 +3 护甲。攻击后未受伤消灭简化：完成交战后使目标 2 点破甲。",
             [("always", "form", "source", F(2, 5)), ("always", "shield", "selected-ally", 3)],
             deck_limit=2, tags=["形态", "护甲", "消灭"]),
    63204: C("千纸千烛", "form", 2, 1, "R", 1,
             "获得 +3/+4。进场获得「童羽歌」简化：抽一张牌。",
             [("always", "form", "source", F(3, 4)), ("always", "draw", "ally-player", 1)],
             tags=["形态", "童羽歌", "护甲"]),
    63205: C("羽衣", "spell", 2, 1, "R", 1,
             "使一个己方式神 +3 护甲，并恢复 3 点生命（羽刃简化）。",
             [("always", "shield", "selected-ally", 3), ("always", "heal", "selected-ally", 3)],
             tags=["护甲", "治疗", "羽衣"]),
    63206: C("热田神宫", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：进场坚守：+2 护甲简化。己方回合开始时，为己方前线获得 2 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 2},
             tags=["幻境", "坚守", "护甲"]),
    63207: C("隐身术", "combat", 3, 1, "R", 1,
             "出击 +2。战斗后为一个己方 +2 护甲并再攻击简化为获得 2 点力量。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "selected-ally", 2), ("always", "buff-stats", "source", F(2, 0))],
             tags=["出击", "护甲", "隐身"]),
    63208: C("月光同怀", "awakening", 3, 1, "SR", 1,
             "为一个己方式神 +3 护甲。觉醒：+2/+2，获得护甲转战力简化为回合开始获得 1 点力量与 1 点护甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "shield", "selected-ally", 3)],
             deck_limit=1, tags=["觉醒", "战力", "护甲"]),

    # ---- 纸舞 633 ----
    63301: C("纸刃", "spell", 1, 1, "R", 2,
             "为一个己方其他式神 +2 力量，并使其获得迅捷简化为抽一张牌。",
             [("always", "buff-stats", "selected-ally", F(2, 0)), ("always", "draw", "ally-player", 1)],
             tags=["落纸", "迅捷", "灵咒"]),
    63302: C("日轮美景", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，占卜简化为抽一张牌（灵咒数量）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "占卜", "落纸"]),
    63303: C("纸短情长", "form", 1, 1, "R", 1,
             "获得 +2/+4。被结附灵咒时攻击简化：完成交战后获得 1 点力量。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，获得 1 点力量。",
             formHooks=[{"id": "form-zhiwu-long", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "落纸", "灵咒"]),
    63304: C("觉醒·纸舞", "awakening", 2, 1, "SR", 1,
             "为一个己方 +2 力量。觉醒：+2/+2，结附灵咒投射简化为回合开始对敌方前线 2 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "selected-ally", F(2, 0))],
             deck_limit=1, tags=["觉醒", "落纸", "投射"]),
    63305: C("纸燕", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成等同于结附灵咒力量总和的伤害简化：造成 5 点伤害。",
             [("always", "damage", "selected-enemy", 5)],
             tags=["伤害", "落纸", "灵咒"]),
    63306: C("东湖木屋", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：进场坚守：+2 护甲简化。己方回合开始时，为所有己方获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "坚守", "落纸"]),
    63307: C("叠心", "spell", 3, 1, "R", 1,
             "使纸舞与结附灵咒的式神攻击简化：对所有敌方式神造成 2 点伤害，并为所有己方 +1 力量。",
             [("always", "damage", "all-enemy-units", 2), ("always", "buff-stats", "all-ally-units", F(1, 0))],
             tags=["坚守", "战力", "灵咒"]),
    63308: C("砚上翩跹", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。进场和回合开始获得纸刃简化：抽一张牌并获得 1 点力量。",
             [("always", "form", "source", F(4, 4)), ("always", "draw", "ally-player", 1)],
             formAbility="己方回合开始时，抽一张牌并获得 1 点力量。",
             formHooks=[
                 {"id": "form-zhiwu-ink-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-zhiwu-ink-buff", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "纸刃", "终结"]),

    # ---- 二瞳 631 ----
    63101: C("猫灵铃·迎", "realm", 1, 1, "R", 2,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 1 点伤害（猫灵召唤简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "猫灵", "占卜"]),
    63102: C("代理掌柜", "form", 1, 1, "SR", 1,
             "获得 +2/+4。占卜后过牌简化：己方回合开始时，抽一张牌。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-ertong-keep", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "占卜", "过牌"]),
    63103: C("通阴晓阳", "spell", 1, 0, "R", 1,
             "瞬发。随机展示幻境检索简化：占卜 2 并抽一张牌。",
             [("always", "divination", "ally-player", 2), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "占卜", "幻境"]),
    63104: C("觉醒·二瞳", "awakening", 2, 1, "SR", 1,
             "召唤猫灵简化：为所有己方恢复 2 点生命。觉醒：+1/+3，幻境占卜简化为回合开始抽一张牌。",
             [("always", "awaken", "source", F(1, 3)), ("always", "heal", "all-ally-units", 2)],
             deck_limit=1, tags=["觉醒", "猫灵", "占卜"]),
    63105: C("猫灵铃·逻", "realm", 2, 1, "R", 1,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害（猫灵攻击简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "猫灵", "压制"]),
    63106: C("妙香", "spell", 2, 1, "R", 1,
             "瞬发。抽两张牌，并为幻境瞬发简化为获得 1 点护甲。",
             [("always", "draw", "ally-player", 2), ("always", "shield", "source", 1)],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "幻境"]),
    63107: C("猫大明神", "form", 3, 2, "R", 1,
             "获得 +4/+4。幻境复现简化：己方回合开始时，对随机敌方造成 2 点伤害。",
             [("always", "form", "source", F(4, 4))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
             formHooks=[{"id": "form-ertong-god", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "猫灵", "幻境"]),
    63108: C("猫灵铃·迴", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，对敌方前线造成 2 点伤害并为所有己方获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "damage-enemy-front", "value": 2},
                 {"effect": "shield-all-allies", "value": 1},
             ]},
             deck_limit=2, tags=["幻境", "猫灵", "终结"]),

    # ---- 泷 634 ----
    63401: C("涛泷之佑", "combat", 1, 1, "SR", 2,
             "出击 +2。免疫战斗伤害简化为获得 3 点护甲（溢能）。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 3)],
             tags=["出击", "溢能", "护甲"]),
    63402: C("黄金雨", "spell", 1, 1, "R", 1,
             "获得 1 点能量，占卜 1，抽一张牌。",
             [("always", "energy-gain", "ally-player", 1), ("always", "divination", "ally-player", 1), ("always", "draw", "ally-player", 1)],
             tags=["占卜", "溢能", "过牌"]),
    63403: C("远海公子", "form", 1, 1, "R", 1,
             "获得 +2/+4。迅捷。使用溢能/爆能叠战力简化：完成交战后获得 1 点力量。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，获得 1 点力量。",
             formHooks=[{"id": "form-long-sea", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             keywords=["INSTANT"], tags=["形态", "迅捷", "溢能"]),
    63404: C("湍刃", "combat", 2, 1, "R", 1,
             "出击 +4。疾速（溢能减耗简化）。",
             [("source-ready", "assault", "source", 4)],
             keywords=["FIRST_STRIKE"], tags=["出击", "疾速", "溢能"]),
    63405: C("觉醒·泷", "awakening", 2, 1, "SR", 1,
             "对敌方牌手造成 3 点伤害。觉醒：+2/+2，充能溢能减耗简化为回合开始获得 1 点能量。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "enemy-avatar", 3)],
             deck_limit=1, tags=["觉醒", "充能", "溢能"]),
    63406: C("黄金黎明夜", "realm", 2, 1, "R", 1,
             "幻境（耐久 6）：进场使一个己方发起攻击简化。己方回合开始时，抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "过牌", "溢能"]),
    63407: C("泷之决荡", "combat", 3, 2, "SSR", 0,
             "出击 +5。攻击后自动使用同名牌简化：再对敌方牌手造成 3 点伤害。",
             [("source-ready", "assault", "source", 5), ("always", "damage", "enemy-avatar", 3)],
             deck_limit=2, tags=["出击", "溢能", "终结"]),
    63408: C("王牌掌事人", "form", 3, 1, "SR", 1,
             "获得 +4/+4。溢能/爆能获得迅捷昂扬屏障简化：进场获得 3 点护甲。",
             [("always", "form", "source", F(4, 4)), ("always", "shield", "source", 3)],
             keywords=["INSTANT"], tags=["形态", "迅捷", "溢能"]),

    # ---- 小鹿男·千守 635 ----
    63501: C("巡山", "combat", 1, 1, "R", 2,
             "出击 +2。追猎，疾速（溢能）。",
             [("source-ready", "assault", "source", 2)],
             keywords=["FIRST_STRIKE"], tags=["出击", "追猎", "溢能"]),
    63502: C("一律呦鸣式", "form", 1, 2, "SSR", 0,
             "获得 +2/+5。气绝时移回手上简化：气绝时可用：复活自己。",
             [("always", "form", "source", F(2, 5)), ("always", "revive", "source", 1)],
             deck_limit=2, tags=["形态", "溢能", "转生"]),
    63503: C("七角溪畔", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：气绝时可用，进场复活小鹿男简化为投射：对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None), ("always", "damage-enemy-front", "auto", 2)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             keywords=["PROJECTILE"], tags=["幻境", "投射", "森之灵"]),
    63504: C("万木有灵", "awakening", 2, 1, "SR", 1,
             "为所有己方恢复 2 点生命。觉醒：+2/+2，气绝转森之灵简化为获得 2 点力量与 2 点护甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "heal", "all-ally-units", 2)],
             deck_limit=1, tags=["觉醒", "森之灵", "充能"]),
    63505: C("鹿魁", "form", 2, 1, "R", 1,
             "获得 +3/+4。坚毅简化：进场获得 2 点护甲。",
             [("always", "form", "source", F(3, 4)), ("always", "shield", "source", 2)],
             tags=["形态", "溢能", "坚毅"]),
    63506: C("巨鹿神像", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：气绝时可用，进场获得森之力/森之佑简化。己方回合开始时，为所有己方获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "森之灵", "爆能"]),
    63507: C("击鼓奏谣", "combat", 3, 1, "SR", 1,
             "出击 +3。永久加成转战力护甲简化：获得 3 点护甲并抽一张牌。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 3), ("always", "draw", "ally-player", 1)],
             tags=["出击", "溢能", "战力"]),
    63508: C("葬谣", "combat", 3, 1, "R", 1,
             "出击 +5。必杀简化为贯通。",
             [("source-ready", "assault", "source", 5)],
             keywords=["PIERCE"], tags=["出击", "必杀", "溢能"]),

    # ---- 烟烟罗·浮缈 636 ----
    63601: C("雾锁烟迷", "spell", 1, 1, "R", 2,
             "对一个式神造成 3 点伤害，若已眩晕伤害翻倍简化：并眩晕目标。",
             [("always", "damage", "selected-enemy", 3), ("always", "freeze", "selected-enemy", 1)],
             keywords=["STUN"], tags=["眩晕", "溢能", "浮缈"]),
    63602: C("醉春烟", "form", 1, 1, "SR", 1,
             "获得 +2/+4。能量不足变为3简化：回合开始获得 1 点能量，否则占卜。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，获得 1 点能量并抽一张牌。",
             formHooks=[
                 {"id": "form-yanyan-drunk-en", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40},
                 {"id": "form-yanyan-drunk-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
             ],
             tags=["形态", "占卜", "充能"]),
    63603: C("露草行烟", "spell", 1, 1, "R", 1,
             "使一个己方 +1 力量并发起攻击简化：获得 1 点力量并获得 1 点能量。",
             [("always", "buff-stats", "selected-ally", F(1, 0)), ("always", "energy-gain", "ally-player", 1)],
             tags=["战力", "充能", "溢能"]),
    63604: C("烟消云散", "awakening", 2, 1, "SR", 1,
             "对所有敌方角色造成 1 点伤害。觉醒：+2/+2，溢能投射/否则获能简化为回合开始对敌方前线 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 1)],
             deck_limit=1, tags=["觉醒", "投射", "充能"]),
    63605: C("玉生香", "form", 2, 1, "SR", 1,
             "获得 +3/+4。能量不足变为3简化：回合开始对所有敌方角色造成 1 点伤害。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，对所有敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-yanyan-jade", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "溢能", "群伤"]),
    63606: C("命途灯烟", "spell", 2, 1, "R", 1,
             "随机获得弃掉/使用过的溢能牌简化：抽两张牌并获得 1 点能量。",
             [("always", "draw", "ally-player", 2), ("always", "energy-gain", "ally-player", 1)],
             tags=["溢能", "过牌", "充能"]),
    63607: C("烟罗事务所", "realm", 3, 1, "R", 1,
             "幻境（耐久 6）：每回合一次，使用溢能牌召唤分身简化为己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "浮缈", "溢能"]),
    63608: C("瀑上烟霞", "spell", 3, 2, "SSR", 0,
             "重复三次溢能选择简化：对所有敌方角色造成 3 点伤害，并获得 2 点能量。",
             [("always", "damage", "all-enemy-units", 3), ("always", "damage", "enemy-avatar", 3), ("always", "energy-gain", "ally-player", 2)],
             deck_limit=2, tags=["溢能", "群伤", "终结"]),

    # ---- 日和坊·晴阳 637 ----
    63701: C("乍晴", "spell", 1, 1, "R", 2,
             "获得 1 点能量。使牌库随机牌获得溢能投射简化：对敌方前线造成 2 点伤害并抽一张牌。",
             [("always", "energy-gain", "ally-player", 1), ("always", "damage-enemy-front", "auto", 2), ("always", "draw", "ally-player", 1)],
             keywords=["PROJECTILE"], tags=["溢能", "投射", "晴阳"]),
    63702: C("曝日", "spell", 1, 1, "R", 1,
             "对一个式神造成 3 点伤害，减少其能量简化为 1 点破甲，日和坊获得 1 点能量。",
             [("always", "damage", "selected-enemy", 3), ("always", "apply-armor-break", "selected-enemy", 1), ("always", "energy-gain", "ally-player", 1)],
             tags=["伤害", "充能", "溢能"]),
    63703: C("夕立晴", "form", 1, 1, "SR", 1,
             "获得 +2/+5。溢能/爆能鼓舞简化：回合开始为所有己方 +1 力量。",
             [("always", "form", "source", F(2, 5))],
             formAbility="己方回合开始时，所有己方式神获得 1 点力量。",
             formHooks=[{"id": "form-rihe-evening", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "鼓舞", "溢能"]),
    63704: C("晴之姿", "awakening", 2, 1, "SR", 1,
             "为你恢复 3 点生命。觉醒：+2/+3，代付能量简化为回合开始获得 1 点能量。",
             [("always", "awaken", "source", F(2, 3)), ("always", "heal-avatar", "ally-avatar", 3)],
             deck_limit=1, tags=["觉醒", "充能", "溢能"]),
    63705: C("晴柔", "spell", 2, 1, "SR", 1,
             "获得 2 点能量。使牌获得溢能攻击简化：为所有己方 +1 力量。",
             [("always", "energy-gain", "ally-player", 2), ("always", "buff-stats", "all-ally-units", F(1, 0))],
             tags=["溢能", "战力", "晴阳"]),
    63706: C("天照晴晖", "realm", 2, 1, "R", 1,
             "幻境（耐久 6）：进场选择己方获得能量并抽牌简化。己方回合开始时，抽一张牌并获得 1 点能量。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "draw", "value": 1},
             ]},
             tags=["幻境", "溢能", "过牌"]),
    63707: C("快晴", "spell", 3, 0, "R", 1,
             "瞬发。占卜 2，抽两张牌，自动使用溢能简化为获得 1 点鬼火。",
             [("always", "divination", "ally-player", 2), ("always", "draw", "ally-player", 2), ("always", "energy-gain", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "占卜", "溢能"]),
    63708: C("五月晴", "form", 3, 2, "SSR", 0,
             "获得 +3/+6。进场获得 10 能量简化：获得 2 点能量与 2 点力量，过量转回复简化为恢复 3 点生命。",
             [("always", "form", "source", F(3, 6)), ("always", "energy-gain", "ally-player", 2), ("always", "buff-stats", "source", F(2, 0)), ("always", "heal-avatar", "ally-avatar", 3)],
             deck_limit=2, tags=["形态", "溢能", "终结"]),

    # ---- 饭笥 638 ----
    63801: C("食欲倍增", "spell", 1, 1, "R", 2,
             "使一个己方发起攻击简化：为一个己方 +2 力量，并使其发起攻击简化为抽一张牌。",
             [("always", "buff-stats", "selected-ally", F(2, 0)), ("always", "draw", "ally-player", 1)],
             tags=["饱足", "战技", "饭笥"]),
    63802: C("月见料理人", "form", 1, 1, "SR", 1,
             "获得 +2/+4。进场坚守。攻击得食材/被攻得精华简化：完成交战后获得 2 点护甲。",
             [("always", "form", "source", F(2, 4)), ("always", "shield", "source", 2)],
             formAbility="完成交战后，获得 2 点护甲。",
             formHooks=[{"id": "form-fansi-moon", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "坚守", "食材"]),
    63803: C("蓄食待发", "combat", 1, 1, "R", 1,
             "出击 +3。穿刺。增强：被其他牌选中叠力量简化为获得 1 点力量。",
             [("source-ready", "assault", "source", 3), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["PIERCE"], tags=["出击", "穿刺", "饱足"]),
    63804: C("寻味飞扑", "combat", 2, 1, "R", 1,
             "出击 +4。贯通。曾被选中获得疾速追猎简化为获得 1 点护甲。",
             [("source-ready", "assault", "source", 4), ("always", "shield", "source", 1)],
             keywords=["PIERCE", "FIRST_STRIKE"], tags=["出击", "贯通", "饱足"]),
    63805: C("神明料理", "realm", 2, 2, "SSR", 0,
             "幻境（耐久 8）：每回合一次复制法术简化。己方回合开始时，抽一张牌并为所有己方恢复 1 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "draw", "value": 1},
                 {"effect": "shield-all-allies", "value": 1},
             ]},
             deck_limit=2, tags=["幻境", "食材", "终结"]),
    63806: C("食之神明", "form", 2, 1, "SR", 1,
             "获得 +3/+4。进场获得食材与精华简化：抽一张牌并获得 2 点护甲。",
             [("always", "form", "source", F(3, 4)), ("always", "draw", "ally-player", 1), ("always", "shield", "source", 2)],
             tags=["形态", "食材", "生命精华"]),
    63807: C("胃口大开", "combat", 3, 1, "R", 1,
             "出击 +5。战斗后使己方再攻击简化为获得 2 点力量。",
             [("source-ready", "assault", "source", 5), ("always", "buff-stats", "source", F(2, 0))],
             tags=["出击", "饱足", "战力"]),
    63808: C("觉醒·饭笥", "awakening", 3, 1, "SR", 1,
             "为一个己方随机使用食材简化：为所有己方恢复 2 点生命。觉醒：+2/+2，单目标手牌叠战力护甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "heal", "all-ally-units", 2)],
             deck_limit=1, tags=["觉醒", "食材", "饱足"]),

    # ---- 猫川 639 ----
    63901: C("合作·卷轴", "combat", 1, 1, "R", 2,
             "出击 +3。免疫战斗伤害简化为获得 3 点护甲，并获得代价牌简化为抽一张牌。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 3), ("always", "draw", "ally-player", 1)],
             tags=["出击", "代价", "投射"]),
    63902: C("藤原生意人", "form", 1, 1, "SR", 1,
             "获得 +2/+4。首次使用手牌抽牌简化：己方回合开始时，抽一张牌。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-maochuan-biz", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "投射", "过牌"]),
    63903: C("预支·卷轴", "spell", 2, 1, "R", 1,
             "瞬发。抽两张牌（预支的代价简化）。",
             [("always", "draw", "ally-player", 2)],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "代价"]),
    63904: C("投资·卷轴", "spell", 1, 0, "R", 1,
             "瞬发。使一个未攻击己方发起攻击简化：获得 1 点鬼火与 1 点力量。",
             [("always", "energy-gain", "ally-player", 1), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "投资", "代价"]),
    63905: C("觉醒·猫川", "awakening", 2, 1, "SR", 1,
             "对敌方前线造成 3 点伤害。觉醒：+2/+2，首次使用投射简化为回合开始对敌方前线 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3)],
             deck_limit=1, tags=["觉醒", "投射", "代价"]),
    63906: C("膨胀·卷轴", "combat", 2, 1, "SR", 1,
             "出击 +4。追猎，连击简化为再对敌方牌手造成 2 点伤害。",
             [("source-ready", "assault", "source", 4), ("always", "damage", "enemy-avatar", 2)],
             keywords=["FIRST_STRIKE"], tags=["出击", "追猎", "代价"]),
    63907: C("垄断·卷轴", "spell", 3, 1, "R", 1,
             "对一个敌方式神和敌方牌手各造成 6 点伤害。",
             [("always", "damage", "selected-enemy", 6), ("always", "damage", "enemy-avatar", 6)],
             tags=["伤害", "垄断", "代价"]),
    63908: C("猫川长河", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：进场获得本局代价牌简化。己方回合开始时，抽一张牌并为所有己方获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffects": [
                 {"effect": "draw", "value": 1},
                 {"effect": "shield-all-allies", "value": 1},
             ]},
             deck_limit=2, tags=["幻境", "代价牌", "终结"]),

    # ---- 攸宁 640 ----
    64001: C("无邪颂歌", "spell", 1, 0, "R", 2,
             "瞬发。随机展示异名牌置入手牌简化：抽一张牌。",
             [("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "诗乐"]),
    64002: C("捷思奏雅", "spell", 1, 1, "SR", 1,
             "瞬发。使己方变身简化：抽两张牌并为所有己方 +1 力量。",
             [("always", "draw", "ally-player", 2), ("always", "buff-stats", "all-ally-units", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "诗乐"]),
    64003: C("采风成乐", "spell", 1, 1, "R", 1,
             "选择己方获得异名战斗牌简化：为一个己方 +2 力量并使其获得 2 点护甲。",
             [("always", "buff-stats", "selected-ally", F(2, 0)), ("always", "shield", "selected-ally", 2)],
             tags=["战力", "鼓舞", "诗乐"]),
    64004: C("诗经", "form", 2, 2, "SSR", 0,
             "获得 +3/+4。异名法术复制/否则抽牌简化：己方回合开始时，抽一张牌并随机对敌方造成 2 点伤害。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，抽一张牌并随机对一个敌方角色造成 2 点伤害。",
             formHooks=[
                 {"id": "form-youning-poem-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-youning-poem-dmg", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "诗经", "终结"]),
    64005: C("重章叠句", "spell", 2, 1, "R", 1,
             "对一个式神造成 5 点伤害，若异名则伤害+2简化为固定 5 点并抽一张牌。",
             [("always", "damage", "selected-enemy", 5), ("always", "draw", "ally-player", 1)],
             tags=["伤害", "诗乐", "过牌"]),
    64006: C("思无邪", "form", 1, 1, "R", 1,
             "获得 +2/+3。升级获得异名牌简化：回合结束弃掉简化为完成交战后抽一张牌。",
             [("always", "form", "source", F(2, 3))],
             formAbility="完成交战后，抽一张牌。",
             formHooks=[{"id": "form-youning-think", "event": "combat-resolved", "effect": "passive-draw-self", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "鼓舞", "过牌"]),
    64007: C("觉醒·攸宁", "awakening", 3, 1, "SR", 1,
             "为所有己方 +2 力量。觉醒：+2/+2，使用手牌随机效果简化为回合开始随机对敌方 3 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "all-ally-units", F(2, 0))],
             deck_limit=1, tags=["觉醒", "鼓舞", "诗乐"]),
    64008: C("诂训", "spell", 3, 0, "SR", 1,
             "瞬发。随机获得各式神异名牌简化：抽三张牌。",
             [("always", "draw", "ally-player", 3)],
             keywords=["INSTANT"], tags=["瞬发", "百家之长", "过牌"]),

    # ---- 阿莱娜 641 ----
    64101: C("九次幂", "spell", 1, 1, "R", 2,
             "战技。检视敌方牌库顶结附灵咒简化：对一个敌方式神造成 3 点伤害并 1 点破甲。",
             [("always", "damage", "selected-enemy", 3), ("always", "apply-armor-break", "selected-enemy", 1)],
             tags=["战技", "灵咒", "无穷无尽"]),
    64102: C("圣书", "form", 1, 1, "SR", 1,
             "获得 +2/+4。为牌库结附无穷无尽简化：完成交战后对敌方牌手造成 1 点伤害。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
             formHooks=[{"id": "form-alaina-book", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "灵咒", "无穷无尽"]),
    64103: C("时间回溯", "spell", 1, 1, "R", 1,
             "双方各抽三张再洗回简化：抽两张牌并占卜 1。",
             [("always", "draw", "ally-player", 2), ("always", "divination", "ally-player", 1)],
             tags=["占卜", "灵咒", "过牌"]),
    64104: C("觉醒·阿莱娜", "awakening", 2, 1, "SR", 1,
             "双方各抽一张灵咒牌简化：抽两张牌。觉醒：+2/+2，抽到灵咒投射简化为回合开始对敌方前线 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "灵咒", "投射"]),
    64105: C("诡秘书室", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：为敌方牌库结附无穷无尽简化。己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "灵咒", "无穷无尽"]),
    64106: C("沙之束缚", "spell", 2, 1, "R", 1,
             "响应：敌方使用手牌时自动使用。眩晕一个敌方式神并对其造成 3 点伤害。",
             [("always", "freeze", "selected-enemy", 1), ("always", "damage", "selected-enemy", 3)],
             keywords=["RESPONSE", "STUN"], timing="response", responseTo=["damage", "assault"],
             tags=["响应", "灵咒", "反制"]),
    64107: C("时空终焉之境", "spell", 3, 0, "R", 1,
             "瞬发。为敌方牌库结附无穷无尽并各抽灵咒牌简化：抽两张牌并对所有敌方造成 1 点伤害。",
             [("always", "draw", "ally-player", 2), ("always", "damage", "all-enemy-units", 1)],
             keywords=["INSTANT"], tags=["瞬发", "戏法", "灵咒"]),
    64108: C("沙之书", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。无始无终与无穷无尽简化：己方回合开始时，抽一张牌并对敌方前线造成 2 点伤害。",
             [("always", "form", "source", F(4, 4))],
             formAbility="己方回合开始时，抽一张牌并对敌方前线造成 2 点伤害。",
             formHooks=[
                 {"id": "form-alaina-sand-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-alaina-sand-dmg", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "灵咒", "终结"]),
}

# 无额外 token；如需可在此追加
TOKENS: list = []
EXTRA_TOKENS: list = []

# 被动映射：uid -> (passive, awakenedPassive)；formHooks/被动仅用已注册 passive-*
PASSIVES = {
    "huang-qiming": (
        dict(id="huang-qiming-star", name="星诫启悟", text="己方回合开始时，对敌方前线造成 1 点伤害（启悟星爆简化）。",
             hooks=[dict(id="star-oath", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="huang-qiming-star-awakened", name="命运星河", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="star-oath-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "zhuiyueshen-shuiyue": (
        dict(id="zhuiyue-lumen", name="流明结附", text="己方回合开始时，获得 1 点护甲（流明简化）。",
             hooks=[dict(id="lumen-ward", event="turn-started", effect="passive-shield-self-if-front", params={"amount": 1})]),
        dict(id="zhuiyue-lumen-awakened", name="溯光流明", text="己方回合开始时，获得 2 点护甲并抽一张牌。",
             hooks=[
                 dict(id="lumen-ward-a", event="turn-started", effect="passive-shield-self-if-front", params={"amount": 2}),
                 dict(id="lumen-ward-a2", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "gunv": (
        dict(id="gunv-bone", name="骸骨转生", text="气绝时简化：受到伤害后获得 1 点护甲（召骸缓冲）。",
             hooks=[dict(id="bone-rebirth", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="gunv-bone-awakened", name="脱胎换骨", text="受到伤害后获得 2 点护甲。",
             hooks=[dict(id="bone-rebirth-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "yunv": (
        dict(id="yunv-tear", name="天泪启悟", text="恢复生命时，目标获得 1 点护甲（过量治疗转甲简化）。",
             hooks=[dict(id="rain-tear", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 1})]),
        dict(id="yunv-tear-awakened", name="雨霖天泪", text="恢复生命时，目标获得 2 点护甲。",
             hooks=[dict(id="rain-tear-a", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 2})]),
    ),
    "chen": (
        dict(id="chen-course", name="行度祝星", text="己方回合开始时，抽一张牌（行度置入手牌简化）。",
             hooks=[dict(id="star-course", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="chen-course-awakened", name="守门人辰", text="己方回合开始时，抽一张牌并占卜 1（启悟祝星简化）。",
             hooks=[
                 dict(id="star-course-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
                 dict(id="star-course-a2", event="turn-started", effect="passive-shield-self", params={"amount": 1}),
             ]),
    ),
    "tianzhao": (
        dict(id="tianzhao-halo", name="天晖启悟", text="己方回合开始时，对敌方前线造成 1 点伤害（天晖置入启悟区）。",
             hooks=[dict(id="sky-halo", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="tianzhao-halo-awakened", name="高天原晖", text="己方回合开始时，对敌方前线造成 2 点伤害并抽一张牌。",
             hooks=[
                 dict(id="sky-halo-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2}),
                 dict(id="sky-halo-a2", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "yuedu": (
        dict(id="yuedu-moon", name="虚假之月", text="己方回合开始时，随机对一个敌方角色造成 1 点伤害（扰乱手牌简化）。",
             hooks=[dict(id="false-moon", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="yuedu-moon-awakened", name="月烬虚月", text="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
             hooks=[dict(id="false-moon-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 2})]),
    ),
    "wushi-maoshi": (
        dict(id="wushi-soul", name="武魂形态", text="气绝时简化：受到伤害后获得 1 点护甲（武魂缓冲）。",
             hooks=[dict(id="bushi-soul", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="wushi-soul-awakened", name="武士之魂", text="受到伤害后获得 2 点护甲。",
             hooks=[dict(id="bushi-soul-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "yixienamei": (
        dict(id="yixienamei-snake", name="蛇群压血", text="完成交战后，使交战目标获得 1 点破甲（生命变为1简化）。",
             hooks=[dict(id="snake-swarm", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="yixienamei-snake-awakened", name="灭世蛇群", text="完成交战后，使交战目标获得 2 点破甲。",
             hooks=[dict(id="snake-swarm-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "guishibai": (
        dict(id="guishibai-revive", name="白符复活", text="其他式神气绝时，为所有己方恢复 1 点生命（复活团辅简化）。",
             hooks=[dict(id="white-talisman", event="unit-knocked-out", effect="passive-heal-all-allies", params={"amount": 1})]),
        dict(id="guishibai-revive-awakened", name="点灯归魂", text="其他式神气绝时，为所有己方恢复 2 点生命。",
             hooks=[dict(id="white-talisman-a", event="unit-knocked-out", effect="passive-heal-all-allies", params={"amount": 2})]),
    ),
    "guishihei": (
        dict(id="guishihei-kill", name="索魂成长", text="完成交战后，鬼使黑获得 1 点力量（击杀永久成长简化）。",
             hooks=[dict(id="soul-chain", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="guishihei-kill-awakened", name="漆黑长刃", text="完成交战后，鬼使黑获得 2 点力量。",
             hooks=[dict(id="soul-chain-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "tongnantongnv": (
        dict(id="tongnannv-armor", name="羽护战力", text="受到伤害后，获得 1 点护甲（护甲转战力简化）。",
             hooks=[dict(id="feather-guard", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="tongnannv-armor-awakened", name="月光同怀", text="受到伤害后，获得 2 点护甲。",
             hooks=[dict(id="feather-guard-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "zhiwu": (
        dict(id="zhiwu-paper", name="落纸投射", text="己方回合开始时，对敌方前线造成 1 点伤害（灵咒投射简化）。",
             hooks=[dict(id="paper-fall", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="zhiwu-paper-awakened", name="砚上灵咒", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="paper-fall-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "daorenshen": (
        dict(id="daoren-treasure", name="财宝直击", text="完成交战后，对敌方牌手造成 1 点伤害（打脸取宝简化）。",
             hooks=[dict(id="treasure-cut", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="daoren-treasure-awakened", name="巨额财宝", text="完成交战后，对敌方牌手造成 2 点伤害并获得 1 点力量。",
             hooks=[
                 dict(id="treasure-cut-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2}),
                 dict(id="treasure-cut-a2", event="combat-resolved", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "ertong": (
        dict(id="ertong-divine", name="幻境占卜", text="己方回合开始时，抽一张牌（幻境占卜简化）。",
             hooks=[dict(id="cat-divine", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="ertong-divine-awakened", name="猫大明神", text="己方回合开始时，抽一张牌并随机对敌方造成 1 点伤害。",
             hooks=[
                 dict(id="cat-divine-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
                 dict(id="cat-divine-a2", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1}),
             ]),
    ),
    "yingcao-pupu": (
        dict(id="yingcao-seed", name="光种形态", text="完成交战后，对敌方牌手造成 1 点伤害（形态投射简化）。",
             hooks=[dict(id="seed-light", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="yingcao-seed-awakened", name="醒神之种", text="完成交战后，对敌方牌手造成 2 点伤害并恢复 1 点生命。",
             hooks=[
                 dict(id="seed-light-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2}),
                 dict(id="seed-light-a2", event="combat-resolved", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "mianqiling-xinsu": (
        dict(id="mianqiling-faction", name="面相派系", text="完成交战后，随机对一个敌方角色造成 1 点伤害（派系爆发简化）。",
             hooks=[dict(id="mask-faction", event="combat-resolved", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="mianqiling-faction-awakened", name="面由心生", text="完成交战后，随机对一个敌方角色造成 2 点伤害。",
             hooks=[dict(id="mask-faction-a", event="combat-resolved", effect="passive-damage-random-enemy", params={"amount": 2})]),
    ),
    "fansi": (
        dict(id="fansi-full", name="饱足成长", text="完成交战后，获得 1 点力量（饱足叠层简化）。",
             hooks=[dict(id="full-belly", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="fansi-full-awakened", name="食之神明", text="完成交战后，获得 2 点力量并恢复 1 点生命。",
             hooks=[
                 dict(id="full-belly-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="full-belly-a2", event="combat-resolved", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "longzi": (
        dict(id="longzi-overflow", name="充能溢能", text="己方回合开始时，你获得 1 点能量（充能简化）。",
             hooks=[dict(id="overflow-charge", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="longzi-overflow-awakened", name="王牌掌事人", text="己方回合开始时，你获得 1 点能量，泷获得 1 点力量。",
             hooks=[
                 dict(id="overflow-charge-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="overflow-charge-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "maochuan": (
        dict(id="maochuan-first", name="首用投射", text="己方回合开始时，对敌方前线造成 1 点伤害（首用投射简化）。",
             hooks=[dict(id="first-use", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="maochuan-first-awakened", name="契约代价", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="first-use-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "alaina": (
        dict(id="alaina-script", name="灵咒投射", text="己方回合开始时，对敌方前线造成 1 点伤害（抽到灵咒投射简化）。",
             hooks=[dict(id="spell-mark", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="alaina-script-awakened", name="沙之书灵咒", text="己方回合开始时，对敌方前线造成 2 点伤害并抽一张牌。",
             hooks=[
                 dict(id="spell-mark-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2}),
                 dict(id="spell-mark-a2", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "youning": (
        dict(id="youning-encourage", name="鼓舞诗乐", text="己方回合开始时，若在战斗区，获得 1 点力量（鼓舞简化）。",
             hooks=[dict(id="poem-encourage", event="turn-started", effect="passive-buff-self-if-front", params={"attack": 1})]),
        dict(id="youning-encourage-awakened", name="思无邪诗", text="己方回合开始时，获得 1 点力量并随机对敌方造成 1 点伤害。",
             hooks=[
                 dict(id="poem-encourage-a", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
                 dict(id="poem-encourage-a2", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1}),
             ]),
    ),
    "xiaolunan-qianshou": (
        dict(id="xiaolunan-forest", name="森之灵转生", text="气绝时简化：受到伤害后获得 1 点护甲（森之灵缓冲）。",
             hooks=[dict(id="forest-soul", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="xiaolunan-forest-awakened", name="万木有灵", text="受到伤害后获得 2 点护甲并获得 1 点力量。",
             hooks=[
                 dict(id="forest-soul-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="forest-soul-a2", event="unit-damaged", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "rihefang-qingyang": (
        dict(id="rihe-charge", name="晴阳充能", text="己方回合开始时，你获得 1 点能量（代付能量简化）。",
             hooks=[dict(id="sunny-charge", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="rihe-charge-awakened", name="五月晴晖", text="己方回合开始时，你获得 1 点能量，日和坊·晴阳获得 1 点力量。",
             hooks=[
                 dict(id="sunny-charge-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="sunny-charge-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "yanyanluo-fumiao": (
        dict(id="yanyan-float", name="浮缈充能", text="己方回合开始时，你获得 1 点能量（溢能投射简化）。",
             hooks=[dict(id="float-smoke", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="yanyan-float-awakened", name="瀑上烟霞", text="己方回合开始时，你获得 1 点能量并随机对敌方造成 1 点伤害。",
             hooks=[
                 dict(id="float-smoke-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="float-smoke-a2", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1}),
             ]),
    ),
}


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


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

    # 角色校验：与 shikigami.json 对齐
    for uid, role, name, *_ in UNITS:
        sh = shiks.get(name)
        if not sh:
            raise SystemExit(f"shikigami.json missing {name}")
        if int(sh["role"]) != role:
            raise SystemExit(f"role mismatch {name}: {sh['role']} != {role}")

    lines = []
    lines.append("/**")
    lines.append(" * 祝星·湮灭·千录（wave8，25 式神）内容 — 由 scripts/gen-wave8-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE8_PACK_ID = 'wave8';")
    lines.append("export const WAVE8_PACK_NAME = '祝星·湮灭·千录';")
    lines.append("export const WAVE8_SUBPACKS = Object.freeze({ zhuxing: '祝星启明', yanmie: '湮灭双生', qianlu: '千录晴诗' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE8_UNIT_DEFINITIONS = Object.freeze([")

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
        lines.append(f"    art: {js_str(f'assets/wave8/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave8/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave8')},")
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
    lines.append("function wave8Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave8',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE8_CARD_DEFINITIONS = Object.freeze([")

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
        lines.append(f"  wave8Card({official_id}, {js_str(unit_id)}, {{")
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
        lines.append(f"  wave8Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave8UnitIds() {")
    lines.append("  return WAVE8_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    # 自检
    units = UNITS
    assert len(units) == 25, len(units)
    by_unit: dict[str, list] = {u[0]: [] for u in units}
    for oid, meta in CARD_MAP.items():
        by_unit[unit_of(oid)].append(meta)
    for uid, cards in by_unit.items():
        assert len(cards) == 8, (uid, len(cards))
        starter = sum(c.get("starter", 0) for c in cards)
        assert starter == 8, (uid, starter)
        aw = [c for c in cards if c.get("type") == "awakening"]
        assert len(aw) == 1, (uid, len(aw))
        assert aw[0].get("starter") == 1, uid
        ssr_starter = [c for c in cards if c.get("rarity") == "SSR" and c.get("starter", 0) > 0]
        assert len(ssr_starter) <= 1, (uid, ssr_starter)
        for c in cards:
            assert 0 <= int(c.get("cost", 1)) <= 2, (uid, c["name"], c.get("cost"))

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
