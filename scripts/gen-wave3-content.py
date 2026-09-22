#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave3.js（月夜幻响 + 沧海刀鸣，19 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave3.js"

# (uid, role, name, title, archetype, color, strategy, subpack)
UNITS = [
    ("biyehua", 170, "彼岸花", "赤团华", "自伤 / 反噬", "#c45a7a", "以自伤换反噬，花开彼岸反射对手。", "yueye"),
    ("huang", 178, "荒", "星辰", "幻境 / 投射", "#6a7ad4", "铺幻境叠耐久，星轨星陨投射收割。", "yueye"),
    ("jiuciliang", 179, "久次良", "鲸骨", "护甲 / 成长", "#4a8aaa", "护甲转力量，方圆之备战阵固守。", "yueye"),
    ("huiyeji", 176, "辉夜姬", "竹取", "幻境 / 叠层", "#d4a0c0", "五难题材叠耐久，蓬莱玉枝续航。", "yueye"),
    ("xixueji", 173, "吸血姬", "猩红", "吸血 / 成长", "#a04050", "吸血回血叠力量护甲，猩红之月开法术吸血。", "yueye"),
    ("tianjingxia", 168, "天井下", "妖怪屋", "灵力 / 甲破", "#c0a060", "灵力手牌循环，甲破转化资源。", "yueye"),
    ("longyechaji", 177, "泷夜叉姬", "胧月", "幻境 / 连击", "#8a6ad4", "双幻境护体，胧月无眠连打。", "yueye"),
    ("mengpo", 171, "孟婆", "奈何", "耗牌 / 爆能", "#9a8070", "移除牌库压爆能，汤盆冲撞爆发。", "yueye"),
    ("shanfeng", 175, "山风", "岚", "倒计时 / 爆发", "#5a9a6a", "倒计时连击，岚突加速爆发。", "yueye"),
    ("dayueling", 190, "大岳丸", "铃鹿山", "曲玉 / 强化", "#3a6a8a", "八尺琼曲玉结附强化，麓鸣连击。", "canghai"),
    ("guiqie", 191, "鬼切", "三刃", "鬼斩 / 响应", "#6a6a8a", "三鬼斩响应连打，刀鸣之刃双倍。", "canghai"),
    ("wuguishi", 192, "巫蛊师", "蛊蚀", "叠毒 / 消灭", "#5a7a4a", "蛊蚀叠层，噬命蛊斩杀。", "canghai"),
    ("yinghuayao", 184, "樱花妖", "樱", "治疗 / 反打", "#e8a0b0", "樱落攻守切换，樱吹雪团战。", "canghai"),
    ("xun", 186, "薰", "鸮", "守护 / 不屈", "#8a9ad4", "鸮之守护护攻，鸮之庇佑不屈。", "canghai"),
    ("renmianshu", 181, "人面树", "祸根", "自愈 / 咒杀", "#6a8a5a", "敌方回合自愈，灾厄之花咒杀。", "canghai"),
    ("tiaotiaogege", 183, "跳跳哥哥", "棺", "棺材 / 阵法", "#7a6a5a", "棺材替换复归，释煞阵清场。", "canghai"),
    ("shimengmo", 187, "食梦貘", "梦魇", "梦魇 / 耗库", "#5a4a7a", "梦魇贴牌耗库，支配者成长。", "canghai"),
    ("yujiazhu", 189, "御馔津", "符咒", "充能 / 爆能", "#c0a040", "符咒爆能转战斗，奉祝之愿追击。", "canghai"),
    ("sanmu", 185, "三目", "委托", "委托 / 节奏", "#8a7a5a", "紧急委托循环，蜃楼观光团辅。", "canghai"),
]

ROLE_TO_UID = {role: uid for uid, role, *_ in UNITS}
# 官方 id 特例：177081 不满足 role*100 规则
OID_UNIT_OVERRIDE = {177081: "longyechaji"}

RARITY = {"R": "R", "SR": "SR", "SSR": "SSR", None: "R", "": "R", "N": "R", "SKIN": "R"}
TYPE = {"战斗": "combat", "法术": "spell", "形态": "form", "式神": None, "结界": "realm", "觉醒": "awakening", "衍生": "spell", "协战": None}


def slug(text: str) -> str:
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "card"


def unit_of(oid: int) -> str:
    if oid in OID_UNIT_OVERRIDE:
        return OID_UNIT_OVERRIDE[oid]
    return ROLE_TO_UID[oid // 100]


# 手写映射：只收录可构筑的专属牌（跳过式神卡、SKIN 重复、空描述协战）
# 简化原则同经典/wave2；officialText 保留原文。
CARD_MAP: dict[int, dict] = {
    # ---- 彼岸花 170 ----
    17001: dict(name="血华散", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="抽两张牌，然后对你造成 3 点伤害（抽牌总等级简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2), ("always", "damage-self", "source", 3)],
                tags=["过牌", "自伤"]),
    17002: dict(name="赤团华", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。己方式神完成交战后，对敌方牌手造成 1 点伤害（对你伤害简化为反噬）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5})],
                formAbility="己方方式神完成交战后，对敌方牌手造成 1 点伤害。",
                formHooks=[{"id": "form-biyehua-red", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "反噬"]),
    17003: dict(name="花开彼岸", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +7/+5。迅捷。彼岸花受到伤害时，对敌方前线造成 2 点伤害（反射简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 7, "hp": 5}), ("always", "damage-enemy-front", "auto", 2)],
                formAbility="彼岸花受到伤害时，对敌方前线造成 2 点伤害。",
                formHooks=[{"id": "form-biyehua-bloom", "event": "unit-damaged", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "反射"]),
    17004: dict(name="黄泉花境", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 4）：己方回合开始时，所有己方式神获得 1 点护甲（鼓舞简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
                tags=["幻境", "鼓舞"]),
    17005: dict(name="火照之路", type="realm", level=1, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 8）：己方回合开始时，抽一张牌（手牌瞬发简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                keywords=["INSTANT"], tags=["幻境", "过牌"]),
    17006: dict(name="觉醒·彼岸花", type="awakening", level=1, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="对双方牌手各造成 3 点伤害。觉醒：+1/+1，自伤反噬升级。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "damage", "enemy-avatar", 3), ("always", "damage-self", "source", 3)],
                tags=["觉醒", "反噬"]),
    17007: dict(name="彼岸归航", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 10）：己方回合开始时，抽两张牌（牌库顶使用简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 10, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 2},
                tags=["幻境", "过牌"]),
    17008: dict(name="死亡之花", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="对一个式神造成 4 点伤害（增强 +1 简化并入卡面）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["伤害"]),

    # ---- 荒 178 ----
    17801: dict(name="星轨", type="realm", level=1, cost=1, rarity="R", starter=2,
                text="幻境（耐久 4）：己方回合开始时，投射：造成 3 点伤害（按耐久简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 3},
                keywords=["PIERCE", "PROJECTILE"], tags=["幻境", "投射"]),
    17802: dict(name="余辉", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="抽三张牌（弃幻境简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 3)],
                tags=["过牌", "幻境"]),
    17803: dict(name="荒海", type="realm", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。幻境（耐久 1）：己方回合开始时，抽一张牌。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 1, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                keywords=["INSTANT"], tags=["幻境", "瞬发"]),
    17804: dict(name="星陨", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 4）：己方回合开始时，对敌方前线造成 2 点伤害。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                tags=["幻境", "伤害"]),
    17805: dict(name="星辰之境", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+5（每幻境 +1/+1 简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                tags=["形态", "幻境"]),
    17806: dict(name="月坠", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 15）：己方回合开始时，对敌方前线造成 5 点伤害（叠耐久自毁简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 15, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 5},
                tags=["幻境", "终结"]),
    17807: dict(name="命运螺旋", type="form", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +5/+8。进场投射 2 点伤害（幻境连击简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 8}), ("always", "damage-enemy-front", "auto", 2)],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-huang-spiral", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "幻境"]),
    17808: dict(name="觉醒·荒", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1，完成交战后己方幻境获得护甲（耐久简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒", "幻境"]),

    # ---- 久次良 179 ----
    17901: dict(name="鲸骨·驻", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    17902: dict(name="铃鹿山的守护", type="realm", level=1, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 6）：己方回合开始时，所有己方式神获得 1 点护甲。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
                tags=["幻境", "护甲"]),
    17903: dict(name="白骨之盾", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个己方其他式神获得 4 点护甲。响应：当己方其他式神被攻击时，自动对其使用。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 4)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "护甲"]),
    17904: dict(name="鱼鳞之备", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+6。进场获得 2 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6}), ("always", "shield", "source", 2)],
                formAbility="己方回合开始时，若久次良在战斗区，获得 2 点护甲。",
                formHooks=[{"id": "form-jiuciliang-scale", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "护甲"]),
    17905: dict(name="鲸骨·开", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +3，并获得 1 点护甲（每幻境 +1 简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "shield", "source", 1)],
                tags=["出击", "护甲"]),
    17906: dict(name="方圆之备", type="form", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +5/+8。进场时，己方所有式神获得 3 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 8}), ("always", "shield", "all-ally-units", 3)],
                formAbility="己方回合开始时，为所有己方式神恢复 1 点护甲。",
                formHooks=[{"id": "form-jiuciliang-square", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "团辅"]),
    17907: dict(name="觉醒·久次良", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+2 与 2 点护甲（护甲转力量简化并入面板）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 2}), ("always", "shield", "source", 2)],
                tags=["觉醒", "护甲"]),
    17908: dict(name="铃鹿山的秘宝", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 10）：己方回合开始时，所有己方式神获得 2 点护甲（生命不低于 1 简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 10, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
                tags=["幻境", "保护"]),

    # ---- 辉夜姬 176 ----
    17601: dict(name="燕子安贝", type="realm", level=1, cost=1, rarity="R", starter=1,
                text="幻境（耐久 5）：己方回合开始时，所有己方式神获得 1 点护甲（回血叠耐久简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
                tags=["幻境", "治疗"]),
    17602: dict(name="火鼠裘", type="realm", level=1, cost=1, rarity="R", starter=1,
                text="幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害（反伤简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                tags=["幻境", "反伤"]),
    17603: dict(name="五道难题", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="抽一张牌并获得 1 点鬼火（从牌库选择幻境简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "幻境", "过牌"]),
    17604: dict(name="佛前石钵", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 5）：己方回合开始时，己方前线获得 2 点护甲（召唤石钵简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 2},
                tags=["幻境", "召唤"]),
    17605: dict(name="龙首之玉", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 5）：己方回合开始时，投射：造成 2 点伤害。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                keywords=["PROJECTILE"], tags=["幻境", "投射"]),
    17606: dict(name="觉醒·辉夜姬", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1，幻境叠层强化（简化为回合开始抽 1 并获得 1 护甲）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "draw", "ally-player", 1)],
                tags=["觉醒", "幻境"]),
    17607: dict(name="蓬莱玉枝", type="realm", level=3, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 5）：己方回合开始时，抽一张牌（耐久 ≥10 翻倍简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                tags=["幻境", "过牌"]),
    17608: dict(name="竹取物语", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+5。回合开始抽一张牌并获得 1 点护甲（随机召唤幻境简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5}), ("always", "draw", "ally-player", 1)],
                formAbility="己方回合开始时，抽一张牌并获得 1 点护甲。",
                formHooks=[{"id": "form-huiye-tale", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "幻境"]),

    # ---- 吸血姬 173 ----
    17301: dict(name="血袭", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2。吸血（简化：恢复 2 点生命）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "heal", "source", 2)],
                tags=["出击", "吸血"]),
    17302: dict(name="血蝠之盾", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个式神获得不屈。响应：当你的式神被攻击时，自动对其使用（伤害转承简化）。",
                target="ally-unit", effects=[("always", "grant-unyielding", "selected-ally", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "不屈"]),
    17303: dict(name="血怒", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="瞬发。对一个式神造成 3 点伤害，并为你恢复 3 点生命（吸血/增强简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "heal-avatar", "ally-avatar", 3)],
                keywords=["INSTANT"], tags=["瞬发", "吸血"]),
    17304: dict(name="初拥", type="spell", level=2, cost=0, rarity="R", starter=1,
                text="瞬发。对一个式神造成 1 点伤害，吸血姬恢复 2 点生命。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 1), ("always", "heal", "source", 2)],
                keywords=["INSTANT"], tags=["瞬发", "吸血"]),
    17305: dict(name="渴血之时", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。吸血（简化：进场恢复 3 点生命）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "heal", "source", 3)],
                tags=["形态", "吸血"]),
    17306: dict(name="血香", type="combat", level=2, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="出击 +3，并追加连击。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "heal", "source", 2)],
                keywords=["COMBO"], tags=["出击", "连击", "吸血"]),
    17307: dict(name="觉醒·吸血姬", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1，并恢复 3 点生命。恢复生命时额外获得力量与护甲。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "heal", "source", 3)],
                tags=["觉醒", "吸血"]),
    17308: dict(name="猩红之月", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+8。你的法术牌获得吸血（简化：进场恢复 5 点生命）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 8}), ("always", "heal-avatar", "ally-avatar", 5)],
                formAbility="己方回合开始时，为你恢复 2 点生命。",
                formHooks=[{"id": "form-xixue-moon", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "吸血"]),

    # ---- 天井下 168 ----
    16801: dict(name="骚声", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="瞬发。移除一个角色上的护甲或破甲（简化：移除敌方前线护甲）。",
                target="auto", effects=[("always", "remove-shield", "auto", 99)],
                keywords=["INSTANT"], tags=["瞬发", "破甲"]),
    16802: dict(name="欢愉之音", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+5（甲破效果 +1 简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5})],
                tags=["形态", "灵力"]),
    16803: dict(name="遮雨", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="为你恢复 4 点生命（按最大甲破简化）。",
                target="auto", effects=[("always", "heal-avatar", "ally-avatar", 4)],
                tags=["治疗"]),
    16804: dict(name="妖怪屋的醒转", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="将一张「妖怪屋·灵力」置入手牌，天井下获得 +1/+1。",
                target="auto", effects=[("always", "token-to-hand", "ally-player", {"tokens": ["yaowu-lingli"], "count": 1}), ("always", "buff-stats", "source", {"attack": 1, "hp": 1})],
                tags=["召唤", "灵力"]),
    16805: dict(name="破碎之音", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +6/+5。击杀有破甲的式神时，对敌方牌手造成 3 点伤害（简化：进场投射 3 伤）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 5}), ("always", "damage-enemy-front", "auto", 3)],
                formAbility="己方回合开始时，投射：造成 3 点伤害。",
                formHooks=[{"id": "form-tianjing-break", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "破甲"]),
    16806: dict(name="焕然之音", type="form", level=2, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +5/+6。回合开始抽一张牌（护甲 ≥5 过牌简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 6})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-tianjing-bright", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "过牌"]),
    16807: dict(name="汇聚", type="spell", level=3, cost=0, rarity="R", starter=1,
                text="瞬发。天井下获得 5 点护甲（甲破转移简化）。",
                target="auto", effects=[("always", "shield", "source", 5)],
                keywords=["INSTANT"], tags=["瞬发", "护甲"]),
    16808: dict(name="觉醒·天井下", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+2/+2。回合开始将「妖怪屋·灵力之泉」置入手牌。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2}), ("always", "token-to-hand", "ally-player", {"tokens": ["yaowu-quan"], "count": 1})],
                tags=["觉醒", "灵力"]),

    # ---- 泷夜叉姬 177 ----
    17701: dict(name="曜断", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。出击 +2（有幻境获得瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["INSTANT"], tags=["出击", "瞬发"]),
    17702: dict(name="残阳无影", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，然后投射：造成 2 点伤害（召唤幻境简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "damage-enemy-front", "auto", 2)],
                tags=["出击", "幻境"]),
    17703: dict(name="新月之哀", type="realm", level=1, cost=0, rarity="R", starter=1,
                text="瞬发。幻境（耐久 1）：己方回合开始时，己方前线获得 1 点护甲（非战斗伤害转耐久简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 1, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 1},
                keywords=["INSTANT"], tags=["幻境", "瞬发"]),
    17704: dict(name="日轮之城", type="realm", level=1, cost=0, rarity="R", starter=1,
                text="瞬发。幻境（耐久 1）：己方回合开始时，己方前线获得 1 点护甲（战斗伤害转耐久简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 1, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 1},
                keywords=["INSTANT"], tags=["幻境", "瞬发"]),
    17705: dict(name="觉醒·泷夜叉姬", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1（有幻境先攻与每幻境 +1 力量简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒", "幻境"]),
    17706: dict(name="月之奥义", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +3（消灭敌方幻境简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                tags=["出击", "幻境"]),
    17707: dict(name="胧月无眠", type="combat", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="贯通、连击。出击 +4（再使用简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["PIERCE", "COMBO"], tags=["贯通", "连击", "爆发"]),
    177081: dict(name="永劫轮回", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +3/+7。进场投射 2 点伤害（双幻境召唤简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7}), ("always", "damage-enemy-front", "auto", 2)],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-longye-cycle", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "幻境"]),

    # ---- 孟婆 171 ----
    17101: dict(name="孟婆汤", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使所有敌方式神本回合 -2 力量（移除牌库简化）。",
                target="auto", effects=[("always", "debuff-stats", "all-enemy-units", {"attack": 2, "hp": 0})],
                tags=["削弱", "耗牌"]),
    17102: dict(name="意外之喜", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。抽两张牌（弃一张简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                keywords=["INSTANT"], tags=["瞬发", "过牌"]),
    17103: dict(name="天降之物", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。回合开始双方各受 1 点反噬（移除牌库简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "damage", "all-enemy-units", 1)],
                formAbility="己方回合开始时，对敌方所有式神造成 1 点伤害。",
                formHooks=[{"id": "form-mengpo-drop", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "耗牌"]),
    17104: dict(name="牙牙我们走", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+7。贯通（爆能简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 7})],
                keywords=["PIERCE"], tags=["形态", "贯通"]),
    17105: dict(name="汤盆冲撞", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="投射：造成 4 点伤害（爆能翻倍简化）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 4)],
                keywords=["PROJECTILE"], tags=["投射", "伤害"]),
    17106: dict(name="奈何桥头", type="form", level=2, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +4/+6。敌方回合开始时，随机对一个敌方式神造成 2 点伤害（移除同名简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                formAbility="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
                formHooks=[{"id": "form-mengpo-bridge", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "耗牌"]),
    17107: dict(name="觉醒·孟婆", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+2。对敌方牌手造成伤害时额外 1 点（移除五张牌简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 2})],
                tags=["觉醒", "耗牌"]),
    17108: dict(name="忘忧的旋律", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="使所有敌方式神 -3 力量（移除同名牌简化）。",
                target="auto", effects=[("always", "debuff-stats", "all-enemy-units", {"attack": 3, "hp": 0})],
                tags=["削弱", "终结"]),

    # ---- 山风 175 ----
    17501: dict(name="烈", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+4。触发倒计时时永久 +1/+1（简化：回合开始 +1/+1）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 4}), ("always", "buff-stats", "source", {"attack": 1, "hp": 1})],
                formAbility="己方回合开始时，山风获得 +1/+1。",
                formHooks=[{"id": "form-shanfeng-fierce", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "成长"]),
    17502: dict(name="迅", type="spell", level=1, cost=1, rarity="SR", starter=2,
                text="山风获得不屈。响应：当山风被攻击时，自动使用并获得 2 点护甲（倒计时 -2 简化）。",
                target="auto", effects=[("always", "grant-unyielding", "source", 1), ("always", "shield", "source", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "倒计时"]),
    17503: dict(name="势", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。贯通（倒计时减时叠力量简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                keywords=["PIERCE"], tags=["形态", "贯通"]),
    17504: dict(name="刚", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+8，并获得 4 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8}), ("always", "shield", "source", 4)],
                formAbility="己方回合开始时，若山风在战斗区，获得 2 点护甲。",
                formHooks=[{"id": "form-shanfeng-hard", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "护甲"]),
    17505: dict(name="斩", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+8（倒计时必杀简化为连击）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8})],
                keywords=["COMBO"], tags=["形态", "必杀"]),
    17506: dict(name="突", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="山风获得 +2/+2 与 2 点护甲（倒计时 -2 过量简化）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 2, "hp": 2}), ("always", "shield", "source", 2)],
                tags=["爆发", "倒计时"]),
    17507: dict(name="岚", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对所有敌方式神造成 3 点伤害（倒计时连击简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 3)],
                tags=["清场", "倒计时"]),
    17508: dict(name="觉醒·山风", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+1/+1 与不屈。触发倒计时攻击时免疫战斗伤害（简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "grant-unyielding", "source", 1)],
                tags=["觉醒", "倒计时"]),

    # ---- 大岳丸 190 ----
    19001: dict(name="麓鸣·穿", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="贯通。出击 +2，并将八尺琼曲玉结附于大岳丸（简化为 +1 力量）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "buff-stats", "source", {"attack": 1, "hp": 0})],
                keywords=["PIERCE"], tags=["出击", "贯通"]),
    19002: dict(name="覆土之术", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个己方式神获得不屈。响应：当己方式神被攻击时，自动对其使用（曲玉结附简化）。",
                target="ally-unit", effects=[("always", "grant-unyielding", "selected-ally", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "曲玉"]),
    19004: dict(name="无尽剑狱", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="眩晕一个敌方式神 2 回合（曲玉结附持续眩晕简化）。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 2)],
                keywords=["STUN"], tags=["控制", "眩晕"]),
    19005: dict(name="麓鸣·袭", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +3，并获得 2 点护甲（免疫战斗伤害简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
                tags=["出击", "曲玉"]),
    19006: dict(name="麓鸣·灭", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 3 点伤害，大岳丸获得 2 点护甲。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "shield", "source", 2)],
                tags=["伤害", "曲玉"]),
    19007: dict(name="觉醒·大岳丸", type="awakening", level=2, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。八尺琼曲玉结附于大岳丸时效果翻倍（简化为 +2 力量）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                tags=["觉醒", "曲玉"]),
    19008: dict(name="麓鸣·轰", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="出击 +4（友方式神追击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                tags=["出击", "爆发"]),
    19009: dict(name="铃鹿山之志", type="form", level=2, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +4/+6。回合开始将一张「挪移」置入手牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                formAbility="己方回合开始时，将一张「挪移」置入手牌。",
                formHooks=[{"id": "form-dayue-will", "event": "turn-started", "effect": "passive-token-to-hand", "params": {"tokens": ["nuoyi"], "count": 1}, "priority": 40}],
                tags=["形态", "曲玉"]),

    # ---- 鬼切 191 ----
    19101: dict(name="鬼刃·两断", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +3（髭切必杀简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                tags=["出击", "鬼斩"]),
    19102: dict(name="鬼影闪", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="瞬发。鬼切进入战斗区并获得 2 点护甲，抽一张牌。",
                target="auto", effects=[("always", "fortify", "source", 2), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "鬼斩", "过牌"]),
    19103: dict(name="刀鸣之刃", type="form", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +3/+8。回合开始 +1 力量（鬼斩双倍简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8})],
                formAbility="己方回合开始时，鬼切获得 1 点力量。",
                formHooks=[{"id": "form-guiqie-blade", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "鬼斩"]),
    19104: dict(name="散华之刃", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +2/+6。敌方回合开始时，鬼切获得 2 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6}), ("always", "shield", "source", 2)],
                formAbility="己方回合开始时，若鬼切在战斗区，获得 2 点护甲。",
                formHooks=[{"id": "form-guiqie-scatter", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "鬼斩"]),
    19105: dict(name="鬼刃·罗城门", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2，并抽一张牌（友切反制简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
                tags=["出击", "鬼斩"]),
    19106: dict(name="复仇之刃", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+6。准备区也可触发鬼斩（简化：回合开始 +1 力量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6})],
                formAbility="己方回合开始时，鬼切获得 1 点力量。",
                formHooks=[{"id": "form-guiqie-venge", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "鬼斩"]),
    19107: dict(name="觉醒·鬼切", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。鬼切的战斗牌获得瞬发（简化为 +2 力量）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                keywords=["INSTANT"], tags=["觉醒", "鬼斩"]),
    19108: dict(name="鬼刃·影杀", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="连击。出击 +3（直接攻击牌手简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["COMBO"], tags=["出击", "连击", "鬼斩"]),

    # ---- 巫蛊师 192 ----
    19201: dict(name="施蛊", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个敌方式神获得 2 点破甲（蛊蚀简化）。",
                target="enemy-unit", effects=[("always", "apply-armor-break", "selected-enemy", 2)],
                tags=["蛊蚀", "破甲"]),
    19202: dict(name="无尽蛊", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +1/+6。结附蛊蚀的式神气绝时抽一张牌（简化：回合开始抽 1）。",
                target="auto", effects=[("always", "form", "source", {"attack": 1, "hp": 6})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-wugu-endless", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "蛊蚀"]),
    19203: dict(name="增殖", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="使所有敌方式神获得 1 点破甲（蛊蚀增殖简化）。",
                target="auto", effects=[("always", "apply-armor-break", "all-enemy-units", 1)],
                tags=["蛊蚀", "破甲"]),
    19204: dict(name="食魂蛊", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+7。气绝蛊蚀式神时为你恢复生命（简化：进场恢复 3）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7}), ("always", "heal-avatar", "ally-avatar", 3)],
                formAbility="己方回合开始时，为你恢复 2 点生命。",
                formHooks=[{"id": "form-wugu-devour", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "蛊蚀"]),
    19205: dict(name="噬命蛊", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="对一个式神造成 5 点伤害（消灭有蛊蚀式神简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)],
                tags=["蛊蚀", "斩杀"]),
    19206: dict(name="魔蛊毒爆", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对所有敌方式神造成 2 点伤害并施加 2 点破甲（蛊蚀爆裂简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2), ("always", "apply-armor-break", "all-enemy-units", 2)],
                tags=["蛊蚀", "清场"]),
    19207: dict(name="觉醒·巫蛊师", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。战斗伤害时额外施加破甲（蛊蚀 +1 简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "apply-armor-break", "all-enemy-units", 1)],
                tags=["觉醒", "蛊蚀"]),
    19208: dict(name="缚蝶蛊狱", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 10）：己方回合开始时，对敌方前线造成 1 点伤害（伤害转蛊蚀简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 10, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
                tags=["幻境", "蛊蚀"]),

    # ---- 樱花妖 184 ----
    18401: dict(name="樱落", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个敌方角色造成 3 点伤害，并为己方前线恢复 2 点生命（攻守二选一简化为组合）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "heal", "all-ally-units", 2)],
                tags=["伤害", "治疗"]),
    18402: dict(name="弥生之舞", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+6。己方式神完成交战后恢复 2 点生命（无论是否气绝简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6})],
                formAbility="己方式神完成交战后，为其恢复 2 点生命。",
                formHooks=[{"id": "form-sakura-miya", "event": "combat-resolved", "effect": "passive-heal-allies-on-combat", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "治疗"]),
    18403: dict(name="绽放", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="为所有己方式神恢复 3 点生命。",
                target="auto", effects=[("always", "heal", "all-ally-units", 3)],
                tags=["治疗"]),
    18404: dict(name="绚烂之舞", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+7。敌方完成交战后对其前线造成 2 点伤害（简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7}), ("always", "damage-enemy-front", "auto", 2)],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-sakura-splendid", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "压制"]),
    18405: dict(name="觉醒·樱花妖", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1，并为所有己方式神恢复 2 点生命（气绝倒计时互转简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "heal", "all-ally-units", 2)],
                tags=["觉醒", "治疗"]),
    18406: dict(name="花云之誓", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="对敌方前线造成 2 点伤害，并为所有己方式神恢复 2 点生命（随机重复 7 次简化）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 2), ("always", "heal", "all-ally-units", 2)],
                tags=["伤害", "治疗"]),
    18407: dict(name="樱吹雪", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对所有敌方式神造成 2 点伤害，并为所有己方式神恢复 3 点生命（击杀/复活重复简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2), ("always", "heal", "all-ally-units", 3)],
                tags=["清场", "治疗"]),
    18408: dict(name="飘零之舞", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +3/+7。迅捷、远程、连击。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7})],
                keywords=["REMOTE", "COMBO"], tags=["形态", "连击"]),

    # ---- 薰 186 ----
    18601: dict(name="鸮之利爪", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。结附鸮之守护的式神 +2 力量（简化为薰 +2 力量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                tags=["形态", "鸮之守护"]),
    18602: dict(name="温柔的守护", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。使一个己方式神获得 3 点护甲，并抽一张牌。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 3), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "守护", "过牌"]),
    18603: dict(name="决意", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+4。回合开始获得 1 点护甲（鸮之守护生命简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 4})],
                formAbility="己方回合开始时，薰获得 1 点护甲。",
                formHooks=[{"id": "form-xun-resolve", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "守护"]),
    18604: dict(name="干扰投掷", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个式神造成 1 点伤害并眩晕。响应：当敌方式神攻击你结附鸮之守护的式神时，自动对其使用。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 1), ("always", "freeze", "selected-enemy", 1)],
                keywords=["RESPONSE", "STUN"], timing="response", responseTo=["assault"], tags=["响应", "控制"]),
    18605: dict(name="鸮之警惕", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+5 与 3 点护甲（帷幕简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "shield", "source", 3)],
                formAbility="己方回合开始时，若薰在战斗区，获得 2 点护甲。",
                formHooks=[{"id": "form-xun-alert", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "守护"]),
    18606: dict(name="觉醒·薰", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。攻击时结附鸮之守护（简化为完成交战后 +2 护甲）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "shield", "source", 2)],
                tags=["觉醒", "守护"]),
    18607: dict(name="祈愿之翼", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="使己方所有式神获得 4 点护甲（鸮之守护全体化简化）。",
                target="auto", effects=[("always", "shield", "all-ally-units", 4)],
                tags=["团辅", "守护"]),
    18608: dict(name="鸮之庇佑", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +5/+8 与不屈。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 8}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "不屈"]),

    # ---- 人面树 181 ----
    18101: dict(name="扎根", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+7。不会从战斗区移回准备区（简化为回合开始 +2 护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7}), ("always", "shield", "source", 2)],
                formAbility="己方回合开始时，人面树获得 2 点护甲。",
                formHooks=[{"id": "form-renmian-root", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "站场"]),
    18102: dict(name="神木诅咒", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="使一个敌方式神 -2 力量（形态变诅咒之木简化）。",
                target="enemy-unit", effects=[("always", "debuff-stats", "selected-enemy", {"attack": 2, "hp": 0})],
                tags=["诅咒", "削弱"]),
    18103: dict(name="汲取养分", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+6。回合开始获得 1 点生命（鬼火转生命简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6}), ("always", "heal", "source", 1)],
                formAbility="己方回合开始时，人面树恢复 1 点生命。",
                formHooks=[{"id": "form-renmian-feed", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "成长"]),
    18104: dict(name="神木庇佑", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="使一个其他式神获得不屈（以其生命战斗简化）。",
                target="ally-unit", effects=[("always", "grant-unyielding", "selected-ally", 1)],
                tags=["保护", "不屈"]),
    18105: dict(name="灾厄之花", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 5 点伤害（下回合自毁简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)],
                tags=["诅咒", "伤害"]),
    18106: dict(name="祸根", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+12。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 12})],
                tags=["形态", "站场"]),
    18107: dict(name="凋零之森", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 20）：己方回合开始时，对敌方前线造成 3 点伤害（半血伤害简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 20, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 3},
                tags=["幻境", "诅咒"]),
    18108: dict(name="觉醒·人面树", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+3/+2。敌方回合开始时恢复全部生命（简化为回合开始恢复 4）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 3, "hp": 2}), ("always", "heal", "source", 4)],
                tags=["觉醒", "自愈"]),

    # ---- 跳跳哥哥 183 ----
    18301: dict(name="棺击", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1。其他式神气绝时 +1/+1（简化为进场 +1/+1）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "buff-stats", "source", {"attack": 1, "hp": 1})],
                tags=["出击", "棺材"]),
    18302: dict(name="集煞阵", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +5/+7（气绝减倒计时简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 7})],
                formAbility="己方回合开始时，跳跳哥哥获得 1 点力量。",
                formHooks=[{"id": "form-tiaoge-gather", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "倒计时"]),
    18303: dict(name="不弃", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个非召唤物式神获得不屈。响应：当跳跳哥哥将气绝时，自动对其使用（替换为棺材简化）。",
                target="ally-unit", effects=[("always", "grant-unyielding", "selected-ally", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["damage"], tags=["响应", "棺材"]),
    18304: dict(name="死而复生", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="复活所有己方气绝式神各 2 点生命（替换为棺材简化）。气绝时也可使用。",
                target="knocked-ally", effects=[("always", "revive-all", "all-ally-units", 2)],
                tags=["复活", "棺材"]),
    18305: dict(name="罡身阵", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +7/+6。气绝时替换为棺材（简化为获得不屈）。",
                target="auto", effects=[("always", "form", "source", {"attack": 7, "hp": 6}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "棺材"]),
    18306: dict(name="棺封", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="对一个式神造成 6 点伤害（消灭并替换棺材简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 6)],
                tags=["棺材", "斩杀"]),
    18307: dict(name="释煞阵", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +7/+9。回合开始对所有敌方式神造成 1 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 7, "hp": 9}), ("always", "damage", "all-enemy-units", 1)],
                formAbility="己方回合开始时，对敌方所有式神造成 1 点伤害。",
                formHooks=[{"id": "form-tiaoge-release", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "清场"]),
    18308: dict(name="觉醒·跳跳哥哥", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+2/+2。出击或使用战斗牌改为结附迟钝（简化为 +3 力量）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2}), ("always", "buff-stats", "source", {"attack": 3, "hp": 0})],
                tags=["觉醒", "棺材"]),

    # ---- 食梦貘 187 ----
    18701: dict(name="入眠", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使所有敌方式神本回合 -1 力量（梦魇贴牌简化）。",
                target="auto", effects=[("always", "debuff-stats", "all-enemy-units", {"attack": 1, "hp": 0})],
                tags=["梦魇", "削弱"]),
    18702: dict(name="梦中低语", type="realm", level=1, cost=1, rarity="R", starter=1,
                text="幻境（耐久 4）：己方回合开始时，抽一张牌（梦魇贴牌简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                tags=["幻境", "梦魇"]),
    18703: dict(name="惊梦", type="combat", level=1, cost=1, rarity="SR", starter=2,
                text="出击 +2，并获得 2 点护甲。响应：当敌方抽到梦魇牌时（简化为被攻击时）自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
                keywords=["RESPONSE", "INSTANT"], timing="response", responseTo=["assault"], tags=["响应", "梦魇"]),
    18704: dict(name="觉醒·食梦貘", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。贯通。对敌方牌手造成战斗伤害时贴 3 张梦魇（简化为 +2 破甲）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "apply-armor-break", "all-enemy-units", 2)],
                keywords=["PIERCE"], tags=["觉醒", "梦魇"]),
    18705: dict(name="梦境浮现", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+7。使用法术牌时贴梦魇（简化为回合开始对敌方前线 1 伤）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7})],
                formAbility="己方回合开始时，对敌方前线造成 1 点伤害。",
                formHooks=[{"id": "form-shimeng-dream", "event": "turn-started", "effect": "passive-damage-enemy-front", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "梦魇"]),
    18706: dict(name="永眠之梦", type="realm", level=2, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害（抽到梦魇消灭简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                tags=["幻境", "梦魇"]),
    18707: dict(name="食梦", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="使所有敌方式神 -1 力量，并为你恢复 5 点生命（按梦魂数量简化）。",
                target="auto", effects=[("always", "debuff-stats", "all-enemy-units", {"attack": 1, "hp": 0}), ("always", "heal-avatar", "ally-avatar", 5)],
                tags=["梦魇", "治疗"]),
    18708: dict(name="梦境中的支配者", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+8（按敌方梦魂数成长简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 8})],
                formAbility="己方回合开始时，食梦貘获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-shimeng-king", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "梦魇"]),

    # ---- 御馔津 189 ----
    18901: dict(name="驱魔符", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个式神造成 3 点伤害（形态气绝简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)],
                tags=["符咒", "伤害"]),
    18902: dict(name="御狩之愿", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+7。连击。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7})],
                keywords=["COMBO"], tags=["形态", "连击"]),
    18903: dict(name="丰穗", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="抽一张牌，御馔津获得 3 点能量（简化为你获得 2 点鬼火）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 2)],
                tags=["充能", "过牌"]),
    18904: dict(name="封魔符", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="眩晕一个敌方式神 2 回合，并使其本回合力量变为 0。响应：当御馔津被攻击时，自动使用。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 2), ("always", "set-attack-zero-this-turn", "selected-enemy", 1)],
                keywords=["RESPONSE", "STUN"], timing="response", responseTo=["assault"], tags=["响应", "眩晕", "符咒"]),
    18905: dict(name="觉醒·御馔津", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。符咒爆能转战斗并免疫战斗伤害（简化为 +2 力量）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                tags=["觉醒", "符咒"]),
    18906: dict(name="狐狩界", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 8）：己方回合开始时，获得 1 点鬼火（爆能 -1 简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                keywords=["INSTANT"], tags=["幻境", "符咒"]),
    18907: dict(name="破魔符", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="贯通。对所有敌方式神造成 3 点伤害（暴击贯通简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 3)],
                keywords=["PIERCE", "CRIT"], tags=["符咒", "清场"]),
    18908: dict(name="奉祝之愿", type="form", level=1, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +3/+6。出击时可指定攻击任一敌方式神（简化为远程）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                keywords=["REMOTE"], tags=["形态", "符咒"]),

    # ---- 三目 185 ----
    18501: dict(name="委托整理", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="抽一张牌并获得 1 点鬼火（完成紧急委托简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
                tags=["委托", "过牌"]),
    18502: dict(name="日常委托", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="将一张「紧急委托」置入手牌，并抽一张牌（每日随机效果简化）。",
                target="auto", effects=[("always", "token-to-hand", "ally-player", {"tokens": ["jinji-weituo"], "count": 1}), ("always", "draw", "ally-player", 1)],
                tags=["委托", "过牌"]),
    18503: dict(name="多事多忙", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6（敌方也可完成委托简化为回合开始抽 1）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-sanmu-busy", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "委托"]),
    18504: dict(name="二帚流", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +1，连击（攻击 5 次简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["COMBO"], tags=["出击", "连击"]),
    18505: dict(name="扫除时间", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 6 点伤害（先给不屈再 10 伤简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 6)],
                tags=["委托", "伤害"]),
    18506: dict(name="平和猫又屋", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+5 与不屈（气绝时复活简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 5}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "不屈"]),
    18507: dict(name="蜃楼观光", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="使所有己方式神获得 +2/+2（增强再 +3/+3 简化）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 2})],
                tags=["团辅", "委托"]),
    18508: dict(name="觉醒·三目", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+2/+2。使用紧急委托时再置入手牌（简化为 token 入手）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2}), ("always", "token-to-hand", "ally-player", {"tokens": ["jinji-weituo"], "count": 1})],
                tags=["觉醒", "委托"]),
}

TOKENS = [
    dict(id="yaowu-lingli", unitId="tianjingxia", name="妖怪屋·灵力", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。投射：造成 1 点伤害。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 1)], token=True, keywords=["INSTANT", "PROJECTILE"], tags=["token"]),
    dict(id="yaowu-quan", unitId="tianjingxia", name="妖怪屋·灵力之泉", type="spell", level=1, cost=0, rarity="common",
         text="投射：造成 2 点伤害，并为你恢复 2 点生命。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 2), ("always", "heal-avatar", "ally-avatar", 2)], token=True, tags=["token"]),
    dict(id="nuoyi", unitId="dayueling", name="挪移", type="spell", level=1, cost=0, rarity="common",
         text="投射：造成 1 点伤害（挪移简化）。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 1)], token=True, tags=["token"]),
    dict(id="jinji-weituo", unitId="sanmu", name="紧急委托", type="spell", level=1, cost=0, rarity="common",
         text="抽一张牌，并获得 1 点鬼火。", target="auto",
         effects=[("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)], token=True, tags=["token", "委托"]),
]

EXTRA_TOKENS: list = []

# 被动映射：uid -> (passive, awakenedPassive)
PASSIVES = {
    "biyehua": (
        dict(id="biyehua-backlash", name="反噬", text="彼岸花受到伤害时，对敌方前线造成 1 点伤害（自伤触发简化）。",
             hooks=[dict(id="backlash", event="unit-damaged", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="biyehua-backlash-awakened", name="赤团华", text="彼岸花受到伤害时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="backlash-a", event="unit-damaged", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "huang": (
        dict(id="huang-realm", name="星辰共鸣", text="完成交战后，己方前线获得 1 点护甲（幻境耐久简化）。",
             hooks=[dict(id="starlink", event="combat-resolved", effect="passive-shield-front-on-realm", params={"amount": 1})]),
        dict(id="huang-realm-awakened", name="命运回响", text="完成交战后，己方前线获得 2 点护甲。",
             hooks=[dict(id="starlink-a", event="combat-resolved", effect="passive-shield-front-on-realm", params={"amount": 2})]),
    ),
    "jiuciliang": (
        dict(id="jiuciliang-armor", name="鲸骨之壳", text="受到伤害时，获得 1 点护甲（护甲时 +1 力量简化）。",
             hooks=[dict(id="whale-shell", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="jiuciliang-armor-awakened", name="铃鹿山守护", text="受到伤害时，获得 2 点护甲。",
             hooks=[dict(id="whale-shell-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "huiyeji": (
        dict(id="huiyeji-realm", name="竹取叠辉", text="部署幻境时，己方前线获得 1 点护甲（耐久叠加简化）。",
             hooks=[dict(id="bamboo-stack", event="realm-deployed", effect="passive-shield-front-on-realm", params={"amount": 1})]),
        dict(id="huiyeji-realm-awakened", name="辉夜叠华", text="部署幻境时，己方前线获得 2 点护甲。",
             hooks=[dict(id="bamboo-stack-a", event="realm-deployed", effect="passive-shield-front-on-realm", params={"amount": 2})]),
    ),
    "xixueji": (
        dict(id="xixueji-thirst", name="渴血", text="恢复生命时，吸血姬获得 1 点力量与 1 点护甲。",
             hooks=[
                 dict(id="thirst-atk", event="unit-healed", effect="passive-buff-self", params={"attack": 1}),
                 dict(id="thirst-shield", event="unit-healed", effect="passive-shield-self", params={"amount": 1}),
             ]),
        dict(id="xixueji-thirst-awakened", name="猩红渴血", text="恢复生命时，吸血姬获得 2 点力量与 2 点护甲。",
             hooks=[
                 dict(id="thirst-atk-a", event="unit-healed", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="thirst-shield-a", event="unit-healed", effect="passive-shield-self", params={"amount": 2}),
             ]),
    ),
    "tianjingxia": (
        dict(id="tianjingxia-lingli", name="妖怪屋灵力", text="己方回合开始时，将「妖怪屋·灵力」置入手牌。",
             hooks=[dict(id="lingli", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["yaowu-lingli"], "count": 1})]),
        dict(id="tianjingxia-lingli-awakened", name="灵力之泉", text="己方回合开始时，将「妖怪屋·灵力之泉」置入手牌。",
             hooks=[dict(id="lingli-a", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["yaowu-quan"], "count": 1})]),
    ),
    "longyechaji": (
        dict(id="longyechaji-realm", name="胧月之力", text="己方回合开始时，若泷夜叉姬在战斗区，获得 1 点力量（有幻境 +1 简化）。",
             hooks=[dict(id="glimmer", event="turn-started", effect="passive-buff-self-if-front", params={"attack": 1})]),
        dict(id="longyechaji-realm-awakened", name="永劫胧月", text="己方回合开始时，泷夜叉姬获得 2 点力量。",
             hooks=[dict(id="glimmer-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "mengpo": (
        dict(id="mengpo-forget", name="忘忧", text="完成交战后，对敌方牌手造成 1 点伤害（移除牌库简化）。",
             hooks=[dict(id="forget", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="mengpo-forget-awakened", name="奈何忘川", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="forget-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "shanfeng": (
        dict(id="shanfeng-countdown", name="倒计时·岚", text="完成交战后，山风获得 1 点力量（倒计时攻击简化）。",
             hooks=[dict(id="gale", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="shanfeng-countdown-awakened", name="不屈岚击", text="完成交战后，山风获得 2 点力量与 1 点护甲。",
             hooks=[
                 dict(id="gale-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="gale-a2", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1}),
             ]),
    ),
    "dayueling": (
        dict(id="dayueling-tama", name="八尺琼曲玉", text="己方回合开始时，大岳丸获得 1 点力量（曲玉效果 +1 简化）。",
             hooks=[dict(id="tama", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="dayueling-tama-awakened", name="曲玉翻倍", text="己方回合开始时，大岳丸获得 2 点力量。",
             hooks=[dict(id="tama-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "guiqie": (
        dict(id="guiqie-blade", name="鬼斩", text="己方回合开始时，鬼切获得 1 点力量（结附鬼斩简化）。",
             hooks=[dict(id="oni-cut", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="guiqie-blade-awakened", name="三刃鬼斩", text="己方回合开始时，鬼切获得 2 点力量。",
             hooks=[dict(id="oni-cut-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "wuguishi": (
        dict(id="wuguishi-gu", name="蛊蚀", text="造成战斗伤害时，使目标获得 1 点破甲。",
             hooks=[dict(id="gu-hit", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="wuguishi-gu-awakened", name="蛊蚀增殖", text="造成战斗伤害时，使目标获得 2 点破甲。",
             hooks=[dict(id="gu-hit-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "yinghuayao": (
        dict(id="yinghuayao-sakura", name="樱落护佑", text="恢复生命时，目标获得 1 点护甲（气绝倒计时简化）。",
             hooks=[dict(id="sakura-guard", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 1})]),
        dict(id="yinghuayao-sakura-awakened", name="樱吹雪", text="完成交战后，为所有己方式神恢复 2 点生命。",
             hooks=[dict(id="sakura-guard-a", event="combat-resolved", effect="passive-heal-allies-on-combat", params={"amount": 2})]),
    ),
    "xun": (
        dict(id="xun-owl", name="鸮之守护", text="完成交战后，薰获得 2 点护甲。",
             hooks=[dict(id="owl-guard", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 2})]),
        dict(id="xun-owl-awakened", name="鸮之庇佑", text="完成交战后，薰获得 3 点护甲。",
             hooks=[dict(id="owl-guard-a", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 3})]),
    ),
    "renmianshu": (
        dict(id="renmianshu-root", name="扎根复苏", text="己方回合开始时，若在战斗区，恢复 4 点生命（敌方回合满血简化）。",
             hooks=[dict(id="root-heal", event="turn-started", effect="passive-heal-self-if-front", params={"amount": 4})]),
        dict(id="renmianshu-root-awakened", name="祸根不灭", text="己方回合开始时，若在战斗区，恢复 4 点生命并获得 1 点护甲。",
             hooks=[dict(id="root-heal-a", event="turn-started", effect="passive-heal-shield-self-if-front", params={"amount": 4, "shield": 1})]),
    ),
    "tiaotiaogege": (
        dict(id="tiaotiaogege-coffin", name="集煞", text="其他式神气绝时，跳跳哥哥获得 1 点力量与 1 点生命。",
             hooks=[dict(id="coffin-gather", event="unit-knocked-out", effect="passive-buff-self", params={"attack": 1, "hp": 1})]),
        dict(id="tiaotiaogege-coffin-awakened", name="释煞", text="其他式神气绝时，跳跳哥哥获得 2 点力量与 2 点生命。",
             hooks=[dict(id="coffin-gather-a", event="unit-knocked-out", effect="passive-buff-self", params={"attack": 2, "hp": 2})]),
    ),
    "shimengmo": (
        dict(id="shimengmo-nightmare", name="梦魇", text="完成交战后，对敌方牌手造成 1 点伤害（贴梦魇简化）。",
             hooks=[dict(id="nightmare", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="shimengmo-nightmare-awakened", name="永眠梦魇", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="nightmare-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "yujiazhu": (
        dict(id="yujiazhu-charge", name="充能", text="己方回合开始时，你获得 1 点能量（充能简化）。",
             hooks=[dict(id="charge-up", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="yujiazhu-charge-awakened", name="符咒充能", text="己方回合开始时，你获得 1 点能量，御馔津获得 1 点力量。",
             hooks=[
                 dict(id="charge-up-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="charge-up-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "sanmu": (
        dict(id="sanmu-quest", name="紧急委托", text="己方回合开始时，将一张「紧急委托」置入手牌。",
             hooks=[dict(id="quest", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["jinji-weituo"], "count": 1})]),
        dict(id="sanmu-quest-awakened", name="无尽委托", text="己方回合开始时，将一张「紧急委托」置入手牌，三目获得 1 点力量。",
             hooks=[
                 dict(id="quest-a", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["jinji-weituo"], "count": 1}),
                 dict(id="quest-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
}


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def js_effects(effects) -> str:
    parts = []
    for cond, action, target, value in effects:
        val = "null" if value is None else (
            json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list)) else json.dumps(value)
        )
        parts.append(
            "    { condition: %s, action: %s, target: %s, value: %s }," % (
                js_str(cond), js_str(action), js_str(target), val)
        )
    return "\n".join(parts) if parts else "    { condition: 'always', action: 'noop', target: 'source', value: null },"


def normalize_keywords() -> None:
    """冻结动作补眩晕关键词；apply-keyword 使用 keywordId；空效果补 noop。"""
    for meta in CARD_MAP.values():
        effects = meta.get("effects") or []
        if not effects:
            meta["effects"] = [("always", "noop", "source", None)]
            effects = meta["effects"]
        if any(e[1] == "freeze" for e in effects):
            kws = meta.setdefault("keywords", [])
            if "STUN" not in kws:
                kws.append("STUN")
        for step in effects:
            if step[1] == "apply-keyword" and isinstance(step[3], dict) and "keyword" in step[3]:
                step[3]["keywordId"] = step[3].pop("keyword").lower().replace("_", "-")
                mapping = {"instant": "instant", "remote": "remote", "pierce": "pierce", "combo": "combo"}
                step[3]["keywordId"] = mapping.get(step[3]["keywordId"], step[3]["keywordId"])


def normalize_starters() -> None:
    """每名式神起始构筑恰好 8 张；觉醒类型恰好 1；SSR 默认构筑至多 1。"""
    by_unit: dict[str, list[tuple[int, dict]]] = {}
    for oid, meta in CARD_MAP.items():
        by_unit.setdefault(unit_of(oid), []).append((oid, meta))
    for uid, items in by_unit.items():
        items_sorted = sorted(items, key=lambda kv: (-(kv[1].get("starter") or 0), kv[0]))
        total = sum((m.get("starter") or 0) for _, m in items_sorted)
        for oid, meta in items_sorted:
            if total <= 8:
                break
            cut = min(total - 8, meta.get("starter") or 0)
            meta["starter"] = (meta.get("starter") or 0) - cut
            total -= cut
        ssr_starters = [(oid, m) for oid, m in items_sorted if m.get("rarity") == "SSR" and (m.get("starter") or 0) > 0]
        # 觉醒 SSR 允许 1 张进构筑；其余 SSR 置 0
        non_awaken_ssr = [(oid, m) for oid, m in ssr_starters if m.get("type") != "awakening"]
        awaken_ssr = [(oid, m) for oid, m in ssr_starters if m.get("type") == "awakening"]
        if len(non_awaken_ssr) + (1 if awaken_ssr else 0) > 1:
            for oid, meta in non_awaken_ssr:
                cut = meta.get("starter") or 0
                meta["starter"] = 0
                total -= cut
            # 若觉醒 SSR 也不在，上面已去掉非觉醒；若只保留觉醒 SSR 即可
        if total < 8:
            for oid, meta in items_sorted:
                if total >= 8:
                    break
                if meta.get("type") == "awakening" or meta.get("rarity") == "SSR":
                    continue
                room = min(8 - total, (meta.get("deck_limit") or 2) - (meta.get("starter") or 0))
                if room > 0:
                    meta["starter"] = (meta.get("starter") or 0) + room
                    total += room
        if total < 8:
            for oid, meta in items_sorted:
                if total >= 8:
                    break
                if meta.get("type") == "awakening":
                    continue
                room = min(8 - total, (meta.get("deck_limit") or 2) - (meta.get("starter") or 0))
                if room > 0:
                    meta["starter"] = (meta.get("starter") or 0) + room
                    total += room
        if total < 8:
            for oid, meta in items_sorted:
                if total >= 8:
                    break
                room = min(8 - total, (meta.get("deck_limit") or 2) - (meta.get("starter") or 0))
                if room > 0 and meta.get("type") != "awakening":
                    meta["starter"] = (meta.get("starter") or 0) + room
                    total += room
        # 强制觉醒 starter 恰 1
        for oid, meta in items_sorted:
            if meta.get("type") == "awakening":
                meta["starter"] = 1
                meta["deck_limit"] = 1


def main() -> None:
    normalize_keywords()
    normalize_starters()
    cards = json.loads((DATA / "cards.json").read_text(encoding="utf-8"))
    shiks = {s["name"]: s for s in json.loads((DATA / "shikigami.json").read_text(encoding="utf-8"))}
    by_id = {}
    for c in cards:
        oid = int(c["id"])
        if oid in by_id:
            continue
        if (c.get("xiyoudu") or "") == "SKIN":
            continue
        if not (c.get("desc") or "").strip() and c.get("type") == "协战":
            continue
        by_id[oid] = c

    lines = []
    lines.append("/**")
    lines.append(" * 月夜幻响 + 沧海刀鸣（wave3，19 式神）内容 — 由 scripts/gen-wave3-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE3_PACK_ID = 'wave3';")
    lines.append("export const WAVE3_PACK_NAME = '月夜沧海';")
    lines.append("export const WAVE3_SUBPACKS = Object.freeze({ yueye: '月夜幻响', canghai: '沧海刀鸣' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE3_UNIT_DEFINITIONS = Object.freeze([")

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
        lines.append(f"    art: {js_str(f'assets/wave3/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave3/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave3')},")
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
    lines.append("function wave3Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave3',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE3_CARD_DEFINITIONS = Object.freeze([")

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
        lines.append(f"  wave3Card({official_id}, {js_str(unit_id)}, {{")
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
        lines.append(f"  wave3Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave3UnitIds() {")
    lines.append("  return WAVE3_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
