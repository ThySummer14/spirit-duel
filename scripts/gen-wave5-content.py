#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave5.js（繁花·浮生·喧哗，24 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id。Tokens OK。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave5.js"

# (uid, role, name, title, archetype, color, strategy, subpack)
UNITS = [
    ("tengji", 228, "藤姬", "紫藤", "藤色 / 结附", "#9a6ad4", "结附藤色叠层，繁花之庭续航。", "fanhua"),
    ("huaniajuan", 229, "花鸟卷", "丹青", "画境 / 叠层", "#d4a0b8", "铺画境叠耐久，画魂投射收割。", "fanhua"),
    ("yanmo", 230, "阎魔", "冥府", "魂鬼 / 强化", "#6a3a5a", "魂鬼代打成长，冥府之主收束。", "fanhua"),
    ("kuileishi", 231, "傀儡师", "傀儡", "融合 / 形态", "#8a6a4a", "多形态融合，同心傀儡术叠层。", "fanhua"),
    ("baizangzhu", 233, "白藏主", "梦山", "守护 / 免疫", "#c0a060", "免伤固守，梦山狐影减伤。", "fanhua"),
    ("rulianshi", 236, "入殓师", "织雪", "织雪 / 复生", "#7a8a9a", "气绝织雪，荼蘼之棺终局。", "fanhua"),
    ("fengli", 232, "风狸", "残影", "分身 / 连击", "#5a9a7a", "分身连打，六甲秘祝复数召唤。", "fanhua"),
    ("guanhu", 235, "管狐", "狐怒", "倒计时 / 印记", "#8a6a3a", "狐怒印记叠层，爆破之势清场。", "fanhua"),
    ("song", 244, "松", "词章", "连引 / 节奏", "#6a8a5a", "用牌连引循环，夜乐屋控场。", "fusheng"),
    ("yunwaijing", 242, "云外镜", "镜花", "连引 / 强化", "#8a9ad4", "连引叠效，浮世万象永续强化。", "fusheng"),
    ("liangmianfo", 238, "两面佛", "风雷", "风雷 / 连引", "#c07050", "风雷互引，风雷万象爆发。", "fusheng"),
    ("heitongzi", 240, "黑童子", "罪罚", "合击 / 成长", "#4a3a5a", "黑白连引合击，连斩追击。", "fusheng"),
    ("baitongzi", 241, "白童子", "羁绊", "守护 / 合击", "#d0c0b0", "黑白互援，不灭帷幕站场。", "fusheng"),
    ("xiazhongshaonv", 243, "匣中少女", "藏珍", "充能 / 爆能", "#a06ad4", "投骰充能爆能，璀璨之匣终结。", "fusheng"),
    ("yi", 239, "弈", "星罗", "占卜 / 调度", "#5a6a8a", "占卜调度控顶，棋布星罗成长。", "fusheng"),
    ("xiaosongwan", 245, "小松丸", "松果", "运势 / 倒计时", "#c09040", "运势减倒计时，秋收冬藏成长。", "fusheng"),
    ("wuwu", 252, "五丸", "猫厨", "烹饪 / 连击", "#e0a060", "战伤烹饪叠层，猫咪日和站场。", "xuanhua"),
    ("qianji", 247, "千姬", "海原", "贝戟 / 强化", "#4a8ac0", "召唤海原贝戟，永生之汐控场。", "xuanhua"),
    ("shiling", 253, "食灵", "食神", "烹饪 / 成长", "#d07050", "烹饪叠力量，食神团辅。", "xuanhua"),
    ("maozhanggui", 246, "猫掌柜", "猫又", "召唤 / 食材", "#e0b070", "猫召唤物进场，猫又屋之主压场。", "xuanhua"),
    ("xingxiongtongzi", 251, "星熊童子", "酒碗", "压制 / 破甲", "#a05050", "压制破甲削弱，敌在酒碗处眩晕。", "xuanhua"),
    ("yixigong", 249, "饴细工", "糖人", "烹饪 / 糖人", "#e0c060", "法术烹饪，甘如暖阳终局。", "xuanhua"),
    ("limao", 248, "狸猫", "醉翁", "眩晕 / 反打", "#9a5030", "眩晕反打成长，饮啖醉饱结界。", "xuanhua"),
    ("tuwan", 250, "兔丸", "美食", "运势 / 食材", "#d0a080", "运势失败叠食材，争食贯穿。", "xuanhua"),
]

ROLE_TO_UID = {role: uid for uid, role, *_ in UNITS}

RARITY = {"R": "R", "SR": "SR", "SSR": "SSR", None: "R", "": "R", "N": "R", "SKIN": "R"}
TYPE = {"战斗": "combat", "法术": "spell", "形态": "form", "式神": None, "结界": "realm", "觉醒": "awakening", "衍生": "spell", "协战": None}


def slug(text: str) -> str:
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "card"


def unit_of(oid: int) -> str:
    return ROLE_TO_UID[oid // 100]


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


# 手写映射：只收录可构筑的专属牌（跳过式神卡、SKIN 重复、空描述协战）
# 简化原则同经典/wave3；officialText 保留原文。
CARD_MAP: dict[int, dict] = {
    # ---- 藤姬 228 ----
    22801: dict(name="紫藤舞", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="使一个己方式神获得 2 点护甲。响应：当己方式神被攻击时，自动对其使用。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "护甲"]),
    22802: dict(name="繁花之庭", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +1/+1。进场获得 2 点护甲（藤色结附简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 1, "hp": 1}), ("always", "shield", "source", 2)],
                formAbility="己方回合开始时，藤姬获得 1 点护甲。",
                formHooks=[{"id": "form-tengji-garden", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "藤色"]),
    22803: dict(name="解忧", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个敌方式神造成 5 点伤害（消灭非召唤物简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)], tags=["伤害"]),
    22804: dict(name="织梦", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="抽两张牌（召唤幻役并结附藤色简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)], tags=["过牌", "幻役"]),
    22805: dict(name="觉醒·藤姬", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，藤姬获得 2 点力量（结附藤色简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "藤色"]),
    22806: dict(name="幽玄之响", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="抽一张牌，并对敌方前线造成 1 点伤害。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "damage-enemy-front", "auto", 1)],
                tags=["过牌", "伤害"]),
    22807: dict(name="幻夜回声", type="spell", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="对一个敌方式神造成 4 点伤害（复制式神简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)], tags=["伤害", "幻役"]),
    22808: dict(name="千年华", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 8）：己方回合开始时，所有己方式神获得 1 点护甲。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
                tags=["幻境", "藤色"]),

    # ---- 花鸟卷 229 ----
    22901: dict(name="花鸟风月", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。抽一张牌（召唤画境简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "画境"]),
    22902: dict(name="归鸟", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个式神造成 3 点伤害（移除画境增强简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害", "画境"]),
    22903: dict(name="画中少女", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+5。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5})],
                formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
                formHooks=[{"id": "form-huaniajuan-girl", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "画境"]),
    22904: dict(name="觉醒·花鸟卷", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，抽一张牌。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "画境"]),
    22905: dict(name="芬芳", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="随机对一个敌方角色造成 2 点伤害并恢复 2 点生命。",
                target="auto", effects=[("always", "damage", "auto", 2), ("always", "heal", "source", 2)],
                tags=["伤害", "治疗"]),
    22906: dict(name="花鸟相闻", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个敌方式神造成 3 点伤害，并抽一张牌。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "draw", "ally-player", 1)],
                tags=["伤害", "过牌"]),
    22907: dict(name="入画", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对一个敌方式神造成 5 点伤害（消灭最低力量简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)], tags=["伤害", "画境"]),
    22908: dict(name="画魂", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="贯通，吸血。投射：造成 5 点伤害（按耐久简化）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 5)],
                keywords=["PIERCE", "PROJECTILE"], tags=["贯通", "投射"]),

    # ---- 阎魔 230 ----
    23001: dict(name="夺魂", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个敌方式神造成 3 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害"]),
    23002: dict(name="阎魔之目", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+3（魂鬼帷幕简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 3})],
                formAbility="己方回合开始时，阎魔获得 1 点护甲。",
                formHooks=[{"id": "form-yanmo-eye", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "魂鬼"]),
    23003: dict(name="业镜", type="realm", level=1, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 6）：己方回合开始时，所有己方式神获得 1 点护甲。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
                tags=["幻境", "强化"]),
    23004: dict(name="审判之司", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+4。进场获得 2 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 4}), ("always", "shield", "source", 2)],
                formAbility="完成交战后，阎魔获得 1 点护甲。",
                formHooks=[{"id": "form-yanmo-judge", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "魂鬼"]),
    23005: dict(name="怨魂重压", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="瞬发。出击 +2（魂鬼攻击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["INSTANT"], tags=["瞬发", "魂鬼"]),
    23006: dict(name="觉醒·阎魔", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1 与迅捷（昂扬简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "魂鬼"]),
    23007: dict(name="慈爱之惠", type="form", level=3, cost=1, rarity="R", starter=0, deck_limit=2,
                text="获得 +5/+5 与不屈（魂鬼贯通不屈简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5}), ("always", "grant-unyielding", "source", None)],
                formAbility="己方回合开始时，阎魔获得 1 点力量。",
                formHooks=[{"id": "form-yanmo-mercy", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "不屈"]),
    23008: dict(name="冥府之主", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="迅捷。获得 +5/+5。己方回合开始时，阎魔获得 2 点力量（魂鬼气绝成长简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5}), ("source-ready", "assault", "source", 2)],
                keywords=["INSTANT"],
                formAbility="己方回合开始时，阎魔获得 2 点力量。",
                formHooks=[{"id": "form-yanmo-lord", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 2}, "priority": 40}],
                tags=["形态", "成长"]),

    # ---- 傀儡师 231 ----
    23101: dict(name="布线", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。抽两张牌（取回形态简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                keywords=["INSTANT"], tags=["瞬发", "融合"]),
    23102: dict(name="机关·傀儡术", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +1/+1。进场投射：造成 3 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 1, "hp": 1}), ("always", "damage-enemy-front", "auto", 3)],
                formAbility="己方使用形态牌后，对敌方前线造成 1 点伤害。",
                formHooks=[{"id": "form-kuileishi-machine", "event": "card-played", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "融合", "投射"]),
    23103: dict(name="庇护·傀儡术", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +2/+2。进场获得 4 点护甲（屏障简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 2}), ("always", "shield", "source", 4)],
                formAbility="己方回合开始时，若在战斗区，获得 2 点护甲。",
                formHooks=[{"id": "form-kuileishi-ward", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "融合", "护甲"]),
    23104: dict(name="操控·傀儡术", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +2/+2。进场抽一张牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 2}), ("always", "draw", "ally-player", 1)],
                formAbility="己方使用形态牌后，抽一张牌。",
                formHooks=[{"id": "form-kuileishi-control", "event": "card-played", "effect": "passive-draw-self-on-form", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "融合", "过牌"]),
    23105: dict(name="出击·傀儡术", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +1/+1。出击 +2（迅捷简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 1, "hp": 1}), ("source-ready", "assault", "source", 2)],
                tags=["形态", "融合", "出击"]),
    23106: dict(name="觉醒·傀儡师", type="awakening", level=2, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方使用形态牌后，对敌方前线造成 2 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "融合"]),
    23107: dict(name="牵丝", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="抽两张牌。",
                target="auto", effects=[("always", "draw", "ally-player", 2)], tags=["过牌", "融合"]),
    23108: dict(name="同心·傀儡术", type="form", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="贯通。获得 +3/+3。己方回合开始时，傀儡师获得 1 点力量与 1 点生命。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 3})],
                keywords=["PIERCE"],
                formAbility="己方回合开始时，傀儡师获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-kuileishi-heart", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "融合", "贯通"]),

    # ---- 白藏主 233 ----
    23301: dict(name="守护誓约", type="form", level=1, cost=1, rarity="R", starter=2,
                text="获得 +3/+6（免疫非战斗伤害简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="己方回合开始时，若在战斗区，获得 2 点护甲。",
                formHooks=[{"id": "form-baizang-oath", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "守护"]),
    23302: dict(name="枕霜而眠", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。使一个敌方式神获得 -2 力量（本回合力量降低简化）。",
                target="enemy-unit", effects=[("always", "debuff-stats", "selected-enemy", {"attack": 2})],
                keywords=["INSTANT"], tags=["瞬发", "削弱"]),
    23303: dict(name="交给小白吧！", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="所有己方式神获得 2 点护甲，抽一张牌。响应：当敌方以你单一角色为目标使用法术或战斗牌时，自动使用并反制。",
                target="auto", effects=[("always", "shield", "all-ally-units", 2), ("always", "draw", "ally-player", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["damage"], tags=["响应", "帷幕"]),
    23304: dict(name="狂烈", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="眩晕一个敌方式神。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 1)],
                keywords=["STUN"], tags=["眩晕"]),
    23305: dict(name="觉醒·白藏主", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。完成交战后，白藏主获得 2 点护甲（攻防免伤简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "守护"]),
    23306: dict(name="无垢之心", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+7。进场获得 3 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7}), ("always", "shield", "source", 3)],
                formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
                formHooks=[{"id": "form-baizang-pure", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "净化"]),
    23307: dict(name="残炎", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对所有敌方式神造成 3 点伤害（按其力量伤害简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 3)], tags=["伤害", "清场"]),
    23308: dict(name="梦山狐影", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+6。进场获得 5 点护甲（减伤结界简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 6}), ("always", "shield", "source", 5)],
                formAbility="己方回合开始时，白藏主获得 3 点护甲。",
                formHooks=[{"id": "form-baizang-fox", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "减伤"]),

    # ---- 入殓师 236 ----
    23601: dict(name="哀恸", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1，并获得 2 点护甲（免疫战斗伤害简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "shield", "source", 2)],
                tags=["出击", "织雪"]),
    23602: dict(name="相合伞", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="抽一张牌，并获得 1 点护甲（召唤织雪简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "shield", "source", 1)],
                tags=["织雪"]),
    23603: dict(name="粉妆", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="为一个气绝的己方式神恢复 3 点生命（复活召唤物简化）。",
                target="knocked-ally", effects=[("always", "revive", "selected-ally", 3)], tags=["复活", "织雪"]),
    23604: dict(name="纳棺人", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+5。进场获得 2 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5}), ("always", "shield", "source", 2)],
                formAbility="其他己方气绝时，入殓师获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-rulianshi-coffin", "event": "unit-knocked-out", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "织雪"]),
    23605: dict(name="觉醒·入殓师", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，入殓师获得 1 点力量与 1 点生命（织雪永久强化简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "织雪"]),
    23606: dict(name="离魂", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个敌方式神造成 5 点伤害（消灭简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)], tags=["伤害", "织雪"]),
    23607: dict(name="葬仪", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对所有敌方角色造成 2 点伤害。",
                target="auto", effects=[("always", "burn-all", "auto", 2)], tags=["伤害", "清场"]),
    23608: dict(name="荼蘼盛放之棺", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="入殓师获得 +4/+4（织雪按生命召唤简化）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 4, "hp": 4})], tags=["织雪", "终局"]),

    # ---- 风狸 232 ----
    23201: dict(name="龙卷·手里剑", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="远程。出击 +0。",
                target="auto", effects=[("source-ready", "assault", "source", 0)],
                keywords=["REMOTE"], tags=["远程", "分身"]),
    23202: dict(name="残影·替身术", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2（召唤物攻击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)], tags=["出击", "分身"]),
    23203: dict(name="残影·分身术", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。抽一张牌（召唤分身简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "分身"]),
    23204: dict(name="风车·雷火弹", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="对敌方牌手造成 2 点伤害。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 2)],
                tags=["伤害", "分身"]),
    23205: dict(name="狸隐术", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2。抽一张牌（取回分身术简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
                tags=["出击", "分身"]),
    23206: dict(name="足跃", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +3（直击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)], tags=["出击", "直击"]),
    23207: dict(name="觉醒·风狸", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+1/+0 与迅捷。完成交战后，风狸获得 1 点力量（分身连打简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 0})], tags=["觉醒", "分身"]),
    23208: dict(name="六甲秘祝", type="form", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +2/+6。己方回合开始时，抽一张牌（额外分身简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-fengli-six", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "分身"]),

    # ---- 管狐 235 ----
    23501: dict(name="竹林飞弹", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="瞬发。对一个敌方式神造成 2 点伤害（狐怒印记+倒计时简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2)],
                keywords=["INSTANT"], tags=["瞬发", "狐怒"]),
    23502: dict(name="破竹之势", type="form", level=2, cost=1, rarity="R", starter=2,
                text="获得 +3/+5。己方回合开始时，对敌方牌手造成 1 点伤害（倒计时 3 打 5 简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5}), ("always", "damage", "enemy-avatar", 1)],
                formAbility="己方回合开始时，对敌方牌手造成 1 点伤害。",
                formHooks=[{"id": "form-guanhu-break", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "倒计时"]),
    23503: dict(name="震撼弹", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="眩晕所有敌方式神（印记眩晕简化）。",
                target="auto", effects=[("always", "freeze", "all-enemy-units", 1)],
                keywords=["STUN"], tags=["眩晕", "狐怒"]),
    23504: dict(name="饭纲契约", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2（狐怒印记简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)], tags=["出击", "狐怒"]),
    23505: dict(name="觉醒·管狐", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，随机对一个敌方式神造成 2 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "狐怒"]),
    23506: dict(name="竹管投掷", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="追猎，免疫战斗伤害。出击 +4（印记加攻简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4), ("always", "shield", "source", 3)],
                tags=["出击", "狐怒"]),
    23507: dict(name="雷云爆弹", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对一名敌方角色造成 5 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)], tags=["伤害", "狐怒"]),
    23508: dict(name="爆破之势", type="form", level=1, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +3/+5。己方回合开始时，对所有敌方角色造成 2 点伤害（倒计时爆破简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5}), ("always", "damage", "all-enemy-units", 2)],
                formAbility="己方回合开始时，对所有敌方角色造成 2 点伤害。",
                formHooks=[{"id": "form-guanhu-blast", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "爆破"]),

    # ---- 松 244 ----
    24401: dict(name="词章洗练", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="远程。出击 +1（移动敌方式神简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["REMOTE"], tags=["远程", "连引"]),
    24402: dict(name="觉醒·松", type="awakening", level=2, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。使用牌后，抽一张牌（连引所有未气绝式神简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "连引"]),
    24403: dict(name="十二段草子", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。抽一张牌（占卜简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "占卜"]),
    24404: dict(name="绮丽", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="获得 3 点护甲（伤害转嫁简化）。响应：当己方战斗区式神被攻击时，自动使用此牌。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "shield", "source", 3)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "连引"]),
    24405: dict(name="拨弦", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="使一个敌方式神获得 -2 力量（内斗简化）。",
                target="enemy-unit", effects=[("always", "debuff-stats", "selected-enemy", {"attack": 2})],
                tags=["削弱", "连引"]),
    24406: dict(name="人形使", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
                formHooks=[{"id": "form-song-puppet", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "连引"]),
    24407: dict(name="夜乐屋", type="realm", level=3, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 5）：己方回合开始时，眩晕一个随机敌方式神（进场与回合开始简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                keywords=["STUN"], tags=["幻境", "眩晕"]),
    24408: dict(name="梦浮世", type="form", level=3, cost=1, rarity="R", starter=0, deck_limit=2,
                text="获得 +4/+7。己方式神连引时，对敌方所有式神造成 1 点伤害（用牌触发简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7}), ("always", "damage", "all-enemy-units", 1)],
                formAbility="己方使用法术牌后，对敌方前线造成 1 点伤害。",
                formHooks=[{"id": "form-song-dream", "event": "card-played", "effect": "passive-damage-enemy-front-on-spell", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "连引"]),

    # ---- 云外镜 242 ----
    24201: dict(name="落影", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对一个敌方角色造成 3 点伤害（连引吸血简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害", "连引"]),
    24202: dict(name="浮世万象", type="form", level=1, cost=1, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +3/+5。己方回合开始时，云外镜获得 1 点力量与 1 点生命（连引永久强化简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5})],
                formAbility="己方回合开始时，云外镜获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-yunwai-myriad", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "连引"]),
    24203: dict(name="斗转", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="追猎。出击 +2（交换力量简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)], tags=["出击", "连引"]),
    24204: dict(name="昙无", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="投射：造成 4 点伤害。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 4)],
                keywords=["PROJECTILE"], tags=["投射", "连引"]),
    24205: dict(name="镜花水月", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+6（连引迅捷简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                formAbility="己方使用形态牌后，抽一张牌。",
                formHooks=[{"id": "form-yunwai-mirror", "event": "card-played", "effect": "passive-draw-self-on-form", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "连引"]),
    24206: dict(name="觉醒·云外镜", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。使用牌后，抽一张牌（连引同名牌瞬发简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "连引"]),
    24207: dict(name="镜怒", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="暴击。出击 +4（连引暴击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["CRIT"], tags=["出击", "连引"]),
    24208: dict(name="通悟", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对敌方所有角色造成 2 点伤害，抽一张牌。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2), ("always", "draw", "ally-player", 1)],
                tags=["伤害", "过牌"]),

    # ---- 两面佛 238 ----
    23801: dict(name="神威", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1。对敌方所有角色造成 1 点伤害（连引增强简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "damage", "all-enemy-units", 1)],
                tags=["出击", "风雷"]),
    23802: dict(name="声闻", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个式神造成 3 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害", "风雷"]),
    23803: dict(name="觉醒·两面佛", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。使用牌后，抽一张牌（风雷互引简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "风雷"]),
    23804: dict(name="雷嗔电怒", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2。抽一张牌（战伤过牌简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
                tags=["出击", "风雷"]),
    23805: dict(name="风起云涌", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="本回合两面佛获得 3 点力量与 3 点护甲（追猎简化）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 3}), ("always", "shield", "source", 3)],
                tags=["强化", "风雷"]),
    23806: dict(name="惊雷", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="连击。出击 +3（连引瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["COMBO"], tags=["出击", "风雷"]),
    23807: dict(name="烈风", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对一个敌方角色造成 4 点伤害，并对所有敌方角色造成 2 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4), ("always", "damage", "all-enemy-units", 2)],
                tags=["伤害", "风雷"]),
    23808: dict(name="风雷万象", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +4/+7。己方使用法术牌后，对敌方前线造成 1 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7})],
                formAbility="己方使用法术牌后，对敌方前线造成 1 点伤害。",
                formHooks=[{"id": "form-liangmian-all", "event": "card-played", "effect": "passive-damage-enemy-front-on-spell", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "风雷"]),

    # ---- 黑童子 240 ----
    24001: dict(name="罪罚·黑", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="贯通。出击 +1。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["PIERCE"], tags=["出击", "合击"]),
    24002: dict(name="替换", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。抽一张牌（移动己方式神简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "合击"]),
    24003: dict(name="黑之羁绊", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +5/+4。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 4})],
                formAbility="己方回合开始时，黑童子获得 1 点力量。",
                formHooks=[{"id": "form-heitongzi-bond", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "合击"]),
    24004: dict(name="守护之心", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+8。受到伤害时，黑童子获得 1 点力量。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="受到伤害时，黑童子获得 1 点力量。",
                formHooks=[{"id": "form-heitongzi-guard", "event": "unit-damaged", "effect": "passive-buff-self-on-damaged", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "合击"]),
    24005: dict(name="合击", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +3（白童子追击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)], tags=["出击", "合击"]),
    24006: dict(name="觉醒·黑童子", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。使用牌后，抽一张牌（黑白连引简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "合击"]),
    24007: dict(name="黑之双影", type="form", level=3, cost=1, rarity="R", starter=1,
                text="贯通。获得 +6/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6})],
                keywords=["PIERCE"],
                formAbility="完成交战后，黑童子获得 1 点力量。",
                formHooks=[{"id": "form-heitongzi-shadow", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "合击"]),
    24008: dict(name="连斩", type="combat", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="出击 +4。连击（再次攻击简化为高爆发）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["COMBO"], tags=["出击", "合击"]),

    # ---- 白童子 241 ----
    24101: dict(name="罪罚·白", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="吸血。出击 +1。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "heal", "source", 1)],
                tags=["出击", "合击"]),
    24102: dict(name="招魂", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。为一个气绝的己方式神恢复 2 点生命（复活黑童子简化）。",
                target="knocked-ally", effects=[("always", "revive", "selected-ally", 2)],
                keywords=["INSTANT"], tags=["瞬发", "复活"]),
    24103: dict(name="白之羁绊", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
                formHooks=[{"id": "form-baitongzi-bond", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "合击"]),
    24104: dict(name="牺牲之愿", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+8。受到伤害时，白童子获得 1 点生命。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="受到伤害时，白童子获得 1 点生命。",
                formHooks=[{"id": "form-baitongzi-sacrifice", "event": "unit-damaged", "effect": "passive-buff-self-on-damaged", "params": {"hp": 1}, "priority": 40}],
                tags=["形态", "合击"]),
    24105: dict(name="祈愿", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="所有己方式神获得 2 点力量与 2 点生命。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 2})], tags=["强化", "合击"]),
    24106: dict(name="觉醒·白童子", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。使用牌后，抽一张牌（黑白连引简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "合击"]),
    24107: dict(name="白之双影", type="form", level=3, cost=1, rarity="R", starter=1,
                text="吸血。获得 +6/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6}), ("always", "heal", "source", 2)],
                formAbility="完成交战后，白童子获得 1 点生命。",
                formHooks=[{"id": "form-baitongzi-shadow", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"hp": 1}, "priority": 40}],
                tags=["形态", "合击"]),
    24108: dict(name="不灭", type="combat", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 8 点护甲与不屈（帷幕必杀简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 8), ("always", "grant-unyielding", "source", None)],
                tags=["出击", "不屈"]),

    # ---- 匣中少女 243 ----
    24301: dict(name="流光", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个式神造成 3 点伤害（爆能 10 打 10 简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害", "充能"]),
    24302: dict(name="藏珍之匣", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。进场抽一张牌（运势占卜简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "draw", "ally-player", 1)],
                formAbility="己方回合开始时，你获得 1 点能量。",
                formHooks=[{"id": "form-xiazhong-treasure", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "充能"]),
    24303: dict(name="开匣", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="抽一张牌（召唤惜物简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)], tags=["过牌", "充能"]),
    24304: dict(name="觉醒·匣中少女", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1，并获得 2 点能量（充能 10 简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "energy-gain", "ally-player", 2)],
                tags=["觉醒", "充能"]),
    24305: dict(name="华丽之匣", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+5（爆能加生命简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 5})],
                formAbility="己方回合开始时，匣中少女获得 1 点生命。",
                formHooks=[{"id": "form-xiazhong-splendid", "event": "turn-started", "effect": "passive-buff-self", "params": {"hp": 1}, "priority": 40}],
                tags=["形态", "充能"]),
    24306: dict(name="回梦", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="为所有己方角色恢复 3 点生命（复活+回血简化）。",
                target="auto", effects=[("always", "revive-all", "auto", 3), ("always", "heal-avatar", "ally-avatar", 3)],
                tags=["复活", "治疗"]),
    24307: dict(name="溢彩", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="瞬发。抽两张牌（从卡包取牌简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                keywords=["INSTANT"], tags=["瞬发", "过牌"]),
    24308: dict(name="璀璨之匣", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="贯通。获得 +7/+7。己方回合结束时，投射：造成 3 点伤害（爆能投射简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 7, "hp": 7}), ("always", "damage-enemy-front", "auto", 3)],
                keywords=["PIERCE", "PROJECTILE"],
                formAbility="己方回合开始时，对敌方前线造成 3 点伤害。",
                formHooks=[{"id": "form-xiazhong-brilliant", "event": "turn-started", "effect": "passive-damage-enemy-front", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "爆能"]),

    # ---- 弈 239 ----
    23901: dict(name="长考", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。抽两张牌（洗回手牌换抽简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                keywords=["INSTANT"], tags=["瞬发", "占卜"]),
    23902: dict(name="征子", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +2，并获得 2 点护甲（洗牌免伤简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
                tags=["出击", "占卜"]),
    23903: dict(name="气合", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个敌方式神造成 3 点伤害（洗回手牌简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害", "占卜"]),
    23904: dict(name="神之一手", type="spell", level=2, cost=1, rarity="SSR", starter=0, deck_limit=2,
                text="抽三张牌（从牌库取任意牌简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 3)], tags=["过牌", "占卜"]),
    23905: dict(name="觉醒·弈", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，抽一张牌（占卜 2 简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "占卜"]),
    23906: dict(name="治孤", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。为你恢复 3 点生命，抽一张牌。",
                target="auto", effects=[("always", "heal-avatar", "ally-avatar", 3), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "治疗"]),
    23907: dict(name="复盘", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="抽两张牌，并对敌方前线造成 2 点伤害（洗回幻境形态简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2), ("always", "damage-enemy-front", "auto", 2)],
                tags=["过牌", "控制"]),
    23908: dict(name="棋布星罗", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +5/+5（按牌库量成长简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                formAbility="己方回合开始时，弈获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-yi-stars", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "成长"]),

    # ---- 小松丸 245 ----
    24501: dict(name="好奇", type="form", level=1, cost=1, rarity="R", starter=2,
                text="获得 +2/+7。己方回合开始时，小松丸获得 1 点力量与 1 点生命（倒计时简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7})],
                formAbility="己方回合开始时，小松丸获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-xiaosongwan-curious", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "运势"]),
    24502: dict(name="松果搬运", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。抽一张牌（运势 4 抽牌简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT", "FORTUNE"], tags=["瞬发", "运势"]),
    24503: dict(name="松果一击", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个敌方式神造成 3 点伤害（运势眩晕简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害", "运势"]),
    24504: dict(name="胆怯", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +8/+8（气绝倒计时惩罚简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 8, "hp": 8})],
                formAbility="己方回合开始时，小松丸获得 2 点护甲。",
                formHooks=[{"id": "form-xiaosongwan-timid", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "运势"]),
    24505: dict(name="森林偶像", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="瞬发。获得 +2/+6。进场抽一张牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6}), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"],
                formAbility="己方使用形态牌后，抽一张牌。",
                formHooks=[{"id": "form-xiaosongwan-idol", "event": "card-played", "effect": "passive-draw-self-on-form", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "运势"]),
    24506: dict(name="灵敏跃击", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="追猎。出击 +2，并获得 2 点护甲（运势免伤简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
                keywords=["FORTUNE"], tags=["出击", "运势"]),
    24507: dict(name="觉醒·小松丸", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+0/+0 与迅捷。运势成功时成长简化为回合开始 +1/+1。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 0, "hp": 0})], tags=["觉醒", "运势"]),
    24508: dict(name="秋收冬藏", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +7/+7。己方回合开始时，抽一张牌（美味松果简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 7, "hp": 7})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-xiaosongwan-harvest", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "成长"]),

    # ---- 五丸 252 ----
    25201: dict(name="料理小猫", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1（佳肴瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1)], tags=["出击", "烹饪"]),
    25202: dict(name="最强猫侍应", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +2（食材佳肴叠攻简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)], tags=["出击", "烹饪"]),
    25203: dict(name="玩闹时光", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。烹饪，抽一张牌。",
                target="auto", effects=[("always", "cook-ingredient", "auto", "fish"), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT", "COOK"], tags=["瞬发", "烹饪"]),
    25204: dict(name="厨艺研行", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="先攻。出击 +3（使用佳肴简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["FIRST_STRIKE"], tags=["出击", "烹饪"]),
    25205: dict(name="猫咪日和", type="form", level=2, cost=1, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +4/+5。己方回合开始时，五丸获得 2 点护甲并发起攻击简化。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "shield", "source", 2)],
                formAbility="己方回合开始时，五丸获得 2 点护甲。",
                formHooks=[{"id": "form-wuwu-sunny", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "烹饪"]),
    25206: dict(name="猫为鱼干强", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="贯通。出击 +3。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["PIERCE"], tags=["出击", "烹饪"]),
    25207: dict(name="吃饱再干活", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+7。使用牌后，抽一张牌（佳肴过牌简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7})],
                formAbility="己方使用法术牌后，抽一张牌。",
                formHooks=[{"id": "form-wuwu-full", "event": "card-played", "effect": "passive-heal-draw-avatar-on-own-card", "params": {"amount": 1, "spellDraw": 1}, "priority": 40}],
                tags=["形态", "烹饪"]),
    25208: dict(name="觉醒·五丸", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1 与连击。完成交战后，五丸获得 1 点力量（烹饪叠层简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "烹饪"]),

    # ---- 千姬 247 ----
    24701: dict(name="千汐", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="出击 +3（海原贝戟攻击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
                tags=["出击", "贝戟"]),
    24702: dict(name="汐梦", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个式神造成 3 点伤害（贝戟投射简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["伤害", "贝戟"]),
    24703: dict(name="深海歌姬", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。己方回合开始时，所有其他己方式神获得 1 点力量（压制削弱反向简化为团辅）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="己方回合开始时，所有其他己方式神获得 1 点力量。",
                formHooks=[{"id": "form-qianji-diva", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "贝戟"]),
    24704: dict(name="唤潮", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="眩晕一个敌方式神。抽一张牌。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 1), ("always", "draw", "ally-player", 1)],
                keywords=["STUN"], tags=["眩晕", "贝戟"]),
    24705: dict(name="觉醒·千姬", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，千姬获得 2 点力量（贝戟强化简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "贝戟"]),
    24706: dict(name="塑潮使者", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+6。进场获得迅捷与远程（召唤贝戟简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6}), ("source-ready", "assault", "source", 2)],
                keywords=["INSTANT", "REMOTE"],
                formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
                formHooks=[{"id": "form-qianji-tide", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "贝戟"]),
    24707: dict(name="海潮入梦", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="出击 +4（贝戟攻击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)], tags=["出击", "贝戟"]),
    24708: dict(name="永生之汐", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +6/+6。进场眩晕一个随机敌方式神（贝戟离场伤害简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6}), ("always", "freeze", "auto", 1)],
                keywords=["STUN"],
                formAbility="己方回合开始时，对敌方前线造成 2 点伤害。",
                formHooks=[{"id": "form-qianji-eternal", "event": "turn-started", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "贝戟"]),

    # ---- 食灵 253 ----
    25301: dict(name="现场烹饪", type="form", level=1, cost=1, rarity="R", starter=2,
                text="获得 +2/+6。己方回合开始时，烹饪。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6}), ("always", "cook-ingredient", "auto", "rice")],
                formAbility="己方回合开始时，食灵获得 1 点力量（烹饪叠力简化）。",
                formHooks=[{"id": "form-shiling-site", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                keywords=["COOK"], tags=["形态", "烹饪"]),
    25302: dict(name="开锅", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +0。烹饪。",
                target="auto", effects=[("source-ready", "assault", "source", 0), ("always", "cook-ingredient", "auto", "fish")],
                keywords=["COOK"], tags=["出击", "烹饪"]),
    25303: dict(name="梦想料理", type="realm", level=1, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 5）：进场烹饪。己方回合开始时，抽一张牌。",
                target="auto", effects=[("always", "realm", "ally-player", None), ("always", "cook-ingredient", "auto", "herb")],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                keywords=["COOK"], tags=["幻境", "烹饪"]),
    25304: dict(name="觉醒·食灵", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。烹饪。完成交战后，食灵获得 1 点力量。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "cook-ingredient", "auto", "fish")],
                keywords=["COOK"], tags=["觉醒", "烹饪"]),
    25305: dict(name="热血主厨", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+7。己方回合开始时，食灵获得 1 点力量与 1 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 7})],
                formAbility="己方回合开始时，食灵获得 1 点力量与 1 点护甲。",
                formHooks=[{"id": "form-shiling-chef", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "烹饪"]),
    25306: dict(name="快速烹饪", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。烹饪。",
                target="auto", effects=[("always", "cook-ingredient", "auto", "rice")],
                keywords=["INSTANT", "COOK"], tags=["瞬发", "烹饪"]),
    25307: dict(name="热浪", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="追猎。出击 +5（佳肴叠层简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 5)], tags=["出击", "烹饪"]),
    25308: dict(name="食神", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +6/+7。己方回合开始时，所有己方式神获得 1 点力量与 1 点护甲（食材团辅简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 7}), ("always", "cook-ingredient", "auto", "herb")],
                keywords=["COOK"],
                formAbility="己方回合开始时，所有己方式神获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-shiling-god", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "烹饪"]),

    # ---- 猫掌柜 246 ----
    24601: dict(name="食材购入", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。烹饪，并抽一张牌（取食材简化）。",
                target="auto", effects=[("always", "cook-ingredient", "auto", "fish"), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT", "COOK"], tags=["瞬发", "食材"]),
    24602: dict(name="一条召来", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个敌方式神造成 3 点伤害（召唤一条攻击简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["召唤", "食材"]),
    24603: dict(name="四饼出阵", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个敌方式神造成 3 点伤害（召唤四饼攻击简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)], tags=["召唤", "食材"]),
    24604: dict(name="觉醒·猫掌柜", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，烹饪（食材置入手牌简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "cook-ingredient", "auto", "rice")],
                keywords=["COOK"], tags=["觉醒", "食材"]),
    24605: dict(name="二瞳助战", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="所有己方式神获得 2 点护甲（召唤二瞳简化）。",
                target="auto", effects=[("always", "shield", "all-ally-units", 2)], tags=["召唤", "护甲"]),
    24606: dict(name="猫合战", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对敌方牌手造成 2 点伤害，并抽一张牌（召唤攻击简化）。",
                target="auto", effects=[("always", "damage", "enemy-avatar", 2), ("always", "draw", "ally-player", 1)],
                tags=["召唤", "伤害"]),
    24607: dict(name="猫乱斗", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对所有敌方角色造成 2 点伤害（多召唤物乱斗简化）。",
                target="auto", effects=[("always", "burn-all", "auto", 2)], tags=["召唤", "清场"]),
    24608: dict(name="猫又屋之主", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +6/+6。己方回合开始时，烹饪并抽一张牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6}), ("always", "cook-ingredient", "auto", "herb")],
                keywords=["COOK"],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-maozhanggui-lord", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "召唤"]),

    # ---- 星熊童子 251 ----
    25101: dict(name="听咱一言", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个敌方式神获得 -1 力量与 1 点破甲（压制简化）。",
                target="enemy-unit", effects=[("always", "debuff-stats", "selected-enemy", {"attack": 1}), ("always", "apply-armor-break", "selected-enemy", 1)],
                tags=["压制", "破甲"]),
    25102: dict(name="众矢之的", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。使一个敌方式神获得 -2 力量与 2 点破甲。",
                target="enemy-unit", effects=[("always", "debuff-stats", "selected-enemy", {"attack": 2}), ("always", "apply-armor-break", "selected-enemy", 2)],
                keywords=["INSTANT"], tags=["瞬发", "压制"]),
    25103: dict(name="暴力禁止", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+6。敌方使用战斗牌后，对其牌手造成 2 点伤害（反击简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6})],
                formAbility="完成交战后，对敌方牌手造成 1 点伤害并恢复 1 点生命。",
                formHooks=[{"id": "form-xingxiong-ban", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "压制"]),
    25104: dict(name="刀下留人", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。使一个敌方式神获得 -2 力量与 2 点破甲。响应：当敌方式神出击时，自动使用。",
                target="enemy-unit", effects=[("always", "debuff-stats", "selected-enemy", {"attack": 2}), ("always", "apply-armor-break", "selected-enemy", 2)],
                keywords=["INSTANT", "RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "压制"]),
    25105: dict(name="悠然自乐", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6})],
                formAbility="敌方使用战斗牌后，星熊童子获得 1 点力量与 1 点生命（本回合战斗牌触发简化为交战）。",
                formHooks=[{"id": "form-xingxiong-easy", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "压制"]),
    25106: dict(name="觉醒·星熊童子", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，使敌方前线获得 2 点破甲（压制简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "压制"]),
    25107: dict(name="离间之音", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +5/+8。敌方回合开始时，使一个随机敌方式神获得 -1 力量（激怒简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 8}), ("always", "debuff-stats", "selected-enemy", {"attack": 1})],
                formAbility="己方回合开始时，使敌方前线获得 1 点破甲。",
                formHooks=[{"id": "form-xingxiong-sound", "event": "turn-started", "effect": "passive-armor-break-enemy-front", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "压制"]),
    25108: dict(name="敌在酒碗处", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="瞬发。眩晕一个敌方式神（伤害转嫁简化为高伤害）。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 2), ("always", "damage", "selected-enemy", 4)],
                keywords=["INSTANT", "STUN"], tags=["眩晕", "压制"]),

    # ---- 饴细工 249 ----
    24901: dict(name="大火熬糖", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个角色造成 3 点伤害，并为你恢复 1 点生命。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "heal-avatar", "ally-avatar", 1)],
                tags=["伤害", "烹饪"]),
    24902: dict(name="回炉成浆", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="抽两张牌（佳肴瞬发简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)], tags=["过牌", "烹饪"]),
    24903: dict(name="糖人大师", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+6。进场烹饪（召唤糖人简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6}), ("always", "cook-ingredient", "auto", "rice")],
                formAbility="己方使用法术牌后，烹饪。",
                formHooks=[{"id": "form-yixigong-master", "event": "card-played", "effect": "passive-damage-enemy-front-on-spell", "params": {"amount": 1}, "priority": 40}],
                keywords=["COOK"], tags=["形态", "烹饪"]),
    24904: dict(name="融芯化火", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 4 点伤害（食材加伤简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)], tags=["伤害", "烹饪"]),
    24905: dict(name="一物一心", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。己方回合开始时，烹饪。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "cook-ingredient", "auto", "fish")],
                formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
                formHooks=[{"id": "form-yixigong-one", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
                keywords=["COOK"], tags=["形态", "烹饪"]),
    24906: dict(name="觉醒·饴细工", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。使用法术牌后，对敌方前线造成 1 点伤害（烹饪简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "烹饪"]),
    24907: dict(name="苦中作甜", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对所有敌方角色造成 2 点伤害，并烹饪（召唤糖人简化）。",
                target="auto", effects=[("always", "burn-all", "auto", 2), ("always", "cook-ingredient", "auto", "herb")],
                keywords=["COOK"], tags=["伤害", "烹饪"]),
    24908: dict(name="甘如暖阳", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="瞬发。烹饪。为所有己方式神恢复 5 点生命，为你恢复 5 点生命（终局强化简化）。",
                target="auto", effects=[("always", "cook-ingredient", "auto", "rice"), ("always", "heal", "all-ally-units", 5), ("always", "heal-avatar", "ally-avatar", 5)],
                keywords=["INSTANT", "COOK"], tags=["治疗", "终局"]),

    # ---- 狸猫 248 ----
    24801: dict(name="劝酒", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="对一个式神造成 3 点伤害，并获得 1 点护甲（妖酒简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "shield", "source", 1)],
                tags=["伤害", "眩晕"]),
    24802: dict(name="换杯", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="免疫战斗伤害。出击 +1。响应：当狸猫被攻击时，自动使用此牌。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "shield", "source", 4)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "眩晕"]),
    24803: dict(name="品酒专家", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+6。己方回合开始时，若在战斗区，获得 2 点护甲（妖酒简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6})],
                formAbility="己方回合开始时，若在战斗区，获得 2 点护甲。",
                formHooks=[{"id": "form-limao-expert", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "眩晕"]),
    24804: dict(name="觉醒·狸猫", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。受到伤害时，狸猫获得 2 点力量（眩晕反打简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})], tags=["觉醒", "眩晕"]),
    24805: dict(name="嗜酒如命", type="form", level=2, cost=1, rarity="R", starter=1,
                text="帷幕。获得 +4/+6。进场获得 2 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6}), ("always", "shield", "source", 2)],
                formAbility="己方回合开始时，狸猫获得 1 点护甲。",
                formHooks=[{"id": "form-limao-drunk", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "眩晕"]),
    24806: dict(name="醉翁之意", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +4/+8。受到伤害时，狸猫获得 2 点力量与 1 点生命（眩晕反击简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="受到伤害时，狸猫获得 2 点力量。",
                formHooks=[{"id": "form-limao-drunkard", "event": "unit-damaged", "effect": "passive-buff-self-on-damaged", "params": {"attack": 2}, "priority": 40}],
                tags=["形态", "眩晕"]),
    24807: dict(name="烈焰之酒", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对所有敌方角色造成 3 点伤害（眩晕加伤简化）。",
                target="auto", effects=[("always", "burn-all", "auto", 3)], tags=["伤害", "眩晕"]),
    24808: dict(name="饮啖醉饱", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 6）：己方回合开始时，所有己方式神获得 2 点护甲（忽略眩晕+瞬发简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
                tags=["幻境", "眩晕"]),

    # ---- 兔丸 250 ----
    25001: dict(name="觅食", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1。烹饪（运势 4 简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "cook-ingredient", "auto", "fish")],
                keywords=["COOK", "FORTUNE"], tags=["出击", "食材"]),
    25002: dict(name="孤独的美食兔", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。完成交战后，烹饪。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "cook-ingredient", "auto", "rice")],
                formAbility="完成交战后，兔丸获得 1 点力量。",
                formHooks=[{"id": "form-tuwan-lonely", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                keywords=["COOK"], tags=["形态", "食材"]),
    25003: dict(name="兔丸特制食谱", type="spell", level=1, cost=1, rarity="SSR", starter=0, deck_limit=2,
                text="瞬发。抽两张牌，并烹饪两次（多食材简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2), ("always", "cook-ingredient", "auto", "fish"), ("always", "cook-ingredient", "auto", "herb")],
                keywords=["INSTANT", "COOK"], tags=["过牌", "食材"]),
    25004: dict(name="觉醒·兔丸", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。己方回合开始时，烹饪（运势失败食材简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "cook-ingredient", "auto", "rice")],
                keywords=["COOK"], tags=["觉醒", "食材"]),
    25005: dict(name="试吃大会", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+7。完成交战后，对敌方牌手造成 1 点伤害（不明食材简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7})],
                formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
                formHooks=[{"id": "form-tuwan-taste", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "食材"]),
    25006: dict(name="萌动", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="追猎。出击 +3。",
                target="auto", effects=[("source-ready", "assault", "source", 3)], tags=["出击", "食材"]),
    25007: dict(name="料理之魂", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +6/+6。进场对敌方前线造成 3 点伤害（不明食材简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6}), ("always", "damage-enemy-front", "auto", 3)],
                formAbility="己方回合开始时，兔丸获得 1 点力量与 1 点生命。",
                formHooks=[{"id": "form-tuwan-soul", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "食材"]),
    25008: dict(name="争食", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="贯通。出击 +4（不明食材简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["PIERCE"], tags=["出击", "食材"]),
}

# 衍生/食材 token（可入手牌使用）
TOKENS = [
    dict(id="tengji-huanse", unitId="tengji", name="藤色", type="spell", level=1, cost=0, rarity="common",
         text="使一个己方式神获得 1 点力量与 1 点生命。", target="ally-unit",
         effects=[("always", "buff-stats", "selected-ally", {"attack": 1, "hp": 1})], token=True, tags=["token", "藤色"]),
    dict(id="yanmo-hungui", unitId="yanmo", name="魂鬼", type="spell", level=1, cost=0, rarity="common",
         text="投射：造成 2 点伤害。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 2)], token=True, keywords=["PROJECTILE"], tags=["token", "魂鬼"]),
    dict(id="rulianshi-zhixue", unitId="rulianshi", name="织雪", type="spell", level=1, cost=0, rarity="common",
         text="对一个敌方式神造成 2 点伤害。", target="enemy-unit",
         effects=[("always", "damage", "selected-enemy", 2)], token=True, tags=["token", "织雪"]),
    dict(id="fengli-fenshen", unitId="fengli", name="分身·风狸", type="spell", level=1, cost=0, rarity="common",
         text="出击 +1。", target="auto",
         effects=[("source-ready", "assault", "source", 1)], token=True, tags=["token", "分身"]),
    dict(id="yaojiu", unitId="limao", name="妖酒", type="spell", level=1, cost=0, rarity="common",
         text="狸猫获得 2 点力量与 1 点护甲。", target="auto",
         effects=[("always", "buff-stats", "source", {"attack": 2}), ("always", "shield", "source", 1)], token=True, tags=["token", "眩晕"]),
    dict(id="shi-cai", unitId="tuwan", name="不明食材", type="spell", level=1, cost=0, rarity="common",
         text="烹饪。抽一张牌。", target="auto",
         effects=[("always", "cook-ingredient", "auto", "herb"), ("always", "draw", "ally-player", 1)], token=True, keywords=["COOK"], tags=["token", "食材"]),
    dict(id="jia-yao", unitId="shiling", name="佳肴", type="spell", level=1, cost=0, rarity="common",
         text="所有己方式神获得 1 点力量与 1 点生命。", target="auto",
         effects=[("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1})], token=True, tags=["token", "烹饪"]),
]

EXTRA_TOKENS: list = []

# 被动映射：uid -> (passive, awakenedPassive)
PASSIVES = {
    "tengji": (
        dict(id="tengji-huanse", name="藤色", text="己方回合开始时，藤姬获得 1 点力量（结附藤色简化）。",
             hooks=[dict(id="huanse", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="tengji-huanse-awakened", name="千年藤色", text="己方回合开始时，藤姬获得 2 点力量。",
             hooks=[dict(id="huanse-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "huaniajuan": (
        dict(id="huaniajuan-huajing", name="画境", text="部署幻境时，己方前线获得 1 点护甲（画境耐久简化）。",
             hooks=[dict(id="huajing", event="realm-deployed", effect="passive-shield-front-on-realm", params={"amount": 1})]),
        dict(id="huaniajuan-huajing-awakened", name="丹青画魂", text="部署幻境时，己方前线获得 2 点护甲。",
             hooks=[dict(id="huajing-a", event="realm-deployed", effect="passive-shield-front-on-realm", params={"amount": 2})]),
    ),
    "yanmo": (
        dict(id="yanmo-hungui", name="魂鬼代打", text="完成交战后，阎魔获得 1 点力量（魂鬼攻击简化）。",
             hooks=[dict(id="hungui", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="yanmo-hungui-awakened", name="冥府魂鬼", text="完成交战后，阎魔获得 2 点力量。",
             hooks=[dict(id="hungui-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "kuileishi": (
        dict(id="kuileishi-form", name="傀儡有形", text="使用形态牌后，傀儡师获得 1 点力量与 1 点生命（有形态+3/+3简化）。",
             hooks=[dict(id="puppet-form", event="card-played", effect="passive-draw-self-on-form", params={"amount": 0})]),
        dict(id="kuileishi-form-awakened", name="觉醒傀儡术", text="使用形态牌后，傀儡师获得 2 点力量与 2 点生命。",
             hooks=[dict(id="puppet-form-a", event="card-played", effect="passive-draw-self-on-form", params={"amount": 1})]),
    ),
    "baizangzhu": (
        dict(id="baizangzhu-shield", name="梦山守护", text="完成交战后，白藏主获得 1 点护甲（攻防免伤简化）。",
             hooks=[dict(id="fox-guard", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1})]),
        dict(id="baizangzhu-shield-awakened", name="无垢梦山", text="完成交战后，白藏主获得 2 点护甲。",
             hooks=[dict(id="fox-guard-a", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 2})]),
    ),
    "rulianshi": (
        dict(id="rulianshi-zhixue", name="织雪复生", text="受到伤害时，入殓师获得 1 点力量（气绝织雪简化）。",
             hooks=[dict(id="zhixue", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 1})]),
        dict(id="rulianshi-zhixue-awakened", name="荼蘼织雪", text="受到伤害时，入殓师获得 2 点力量。",
             hooks=[dict(id="zhixue-a", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 2})]),
    ),
    "fengli": (
        dict(id="fengli-fenshen", name="残影分身", text="完成交战后，对敌方牌手造成 1 点伤害（分身攻击简化）。",
             hooks=[dict(id="fenshen", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="fengli-fenshen-awakened", name="六甲分身", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="fenshen-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "guanhu": (
        dict(id="guanhu-countdown", name="倒计时·管狐", text="己方回合开始时，对敌方前线造成 1 点伤害（倒计时 2 简化）。",
             hooks=[dict(id="fox-count", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="guanhu-countdown-awakened", name="狐怒倒计时", text="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
             hooks=[dict(id="fox-count-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 2})]),
    ),
    "song": (
        dict(id="song-chain", name="词章连引", text="使用法术牌后，抽一张牌（连引简化）。",
             hooks=[dict(id="song-chain", event="card-played", effect="passive-heal-draw-avatar-on-own-card", params={"amount": 0, "spellDraw": 1})]),
        dict(id="song-chain-awakened", name="十二段连引", text="使用法术牌后，抽一张牌并恢复 1 点生命。",
             hooks=[dict(id="song-chain-a", event="card-played", effect="passive-heal-draw-avatar-on-own-card", params={"amount": 1, "spellDraw": 1})]),
    ),
    "yunwaijing": (
        dict(id="yunwaijing-chain", name="镜花连引", text="使用牌后，云外镜获得 1 点护甲（连引强化简化）。",
             hooks=[dict(id="mirror-chain", event="card-played", effect="passive-heal-avatar-on-own-card", params={"amount": 1})]),
        dict(id="yunwaijing-chain-awakened", name="浮世连引", text="使用牌后，为牌手恢复 2 点生命。",
             hooks=[dict(id="mirror-chain-a", event="card-played", effect="passive-heal-avatar-on-own-card", params={"amount": 2})]),
    ),
    "liangmianfo": (
        dict(id="liangmianfo-wind", name="风雷互引", text="使用法术牌后，对敌方前线造成 1 点伤害（风雷连引简化）。",
             hooks=[dict(id="wind-thunder", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 1})]),
        dict(id="liangmianfo-wind-awakened", name="风雷万象", text="使用法术牌后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="wind-thunder-a", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 2})]),
    ),
    "heitongzi": (
        dict(id="heitongzi-bond", name="罪罚之黑", text="完成交战后，黑童子获得 1 点力量（黑白连引简化）。",
             hooks=[dict(id="black-bond", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="heitongzi-bond-awakened", name="黑之羁绊", text="完成交战后，黑童子获得 2 点力量。",
             hooks=[dict(id="black-bond-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "baitongzi": (
        dict(id="baitongzi-bond", name="罪罚之白", text="完成交战后，白童子获得 1 点生命（黑白连引简化）。",
             hooks=[dict(id="white-bond", event="combat-resolved", effect="passive-buff-self", params={"hp": 1})]),
        dict(id="baitongzi-bond-awakened", name="白之羁绊", text="完成交战后，白童子获得 2 点生命。",
             hooks=[dict(id="white-bond-a", event="combat-resolved", effect="passive-buff-self", params={"hp": 2})]),
    ),
    "xiazhongshaonv": (
        dict(id="xiazhongshaonv-charge", name="充能", text="己方回合开始时，你获得 1 点能量（投骰充能简化）。",
             hooks=[dict(id="dice-charge", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="xiazhongshaonv-charge-awakened", name="匣中充能", text="己方回合开始时，你获得 1 点能量，匣中少女获得 1 点力量。",
             hooks=[
                 dict(id="dice-charge-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="dice-charge-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "yi": (
        dict(id="yi-divination", name="星罗占卜", text="己方回合开始时，抽一张牌（洗牌占卜简化）。",
             hooks=[dict(id="star-divine", event="turn-started", effect="passive-draw-self", params={"amount": 1})]),
        dict(id="yi-divination-awakened", name="神之一手", text="己方回合开始时，抽一张牌，弈获得 1 点力量。",
             hooks=[
                 dict(id="star-divine-a", event="turn-started", effect="passive-draw-self", params={"amount": 1}),
                 dict(id="star-divine-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "xiaosongwan": (
        dict(id="xiaosongwan-fortune", name="运势松果", text="己方回合开始时，小松丸获得 1 点力量（运势减倒计时简化）。",
             hooks=[dict(id="pine-fortune", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="xiaosongwan-fortune-awakened", name="秋收运势", text="己方回合开始时，小松丸获得 2 点力量。",
             hooks=[dict(id="pine-fortune-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "wuwu": (
        dict(id="wuwu-cook", name="烹饪小猫", text="完成交战后，五丸获得 1 点力量（战伤烹饪简化）。",
             hooks=[dict(id="cat-cook", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="wuwu-cook-awakened", name="猫厨连击", text="完成交战后，五丸获得 2 点力量。",
             hooks=[dict(id="cat-cook-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "qianji": (
        dict(id="qianji-spear", name="海原贝戟", text="己方回合开始时，所有其他己方式神获得 1 点力量（贝戟团辅简化）。",
             hooks=[dict(id="spear-tide", event="turn-started", effect="passive-buff-other-allies", params={"attack": 1})]),
        dict(id="qianji-spear-awakened", name="永生贝戟", text="己方回合开始时，所有其他己方式神获得 1 点力量与 1 点生命。",
             hooks=[dict(id="spear-tide-a", event="turn-started", effect="passive-buff-other-allies", params={"attack": 1, "hp": 1})]),
    ),
    "shiling": (
        dict(id="shiling-cook", name="烹饪成长", text="完成交战后，食灵获得 1 点力量（烹饪叠力简化）。",
             hooks=[dict(id="food-spirit", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="shiling-cook-awakened", name="食神烹饪", text="完成交战后，食灵获得 2 点力量。",
             hooks=[dict(id="food-spirit-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "maozhanggui": (
        dict(id="maozhanggui-food", name="食材补给", text="己方回合开始时，将一张「不明食材」置入手牌（召唤物用食材简化）。",
             hooks=[dict(id="cat-food", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["shi-cai"], "count": 1})]),
        dict(id="maozhanggui-food-awakened", name="猫又屋食材", text="己方回合开始时，将一张「佳肴」置入手牌。",
             hooks=[dict(id="cat-food-a", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["jia-yao"], "count": 1})]),
    ),
    "xingxiongtongzi": (
        dict(id="xingxiongtongzi-suppress", name="压制", text="己方回合开始时，使敌方前线获得 1 点破甲（压制破甲简化）。",
             hooks=[dict(id="suppress", event="turn-started", effect="passive-armor-break-enemy-front", params={"amount": 1})]),
        dict(id="xingxiongtongzi-suppress-awakened", name="酒碗压制", text="己方回合开始时，使敌方前线获得 2 点破甲。",
             hooks=[dict(id="suppress-a", event="turn-started", effect="passive-armor-break-enemy-front", params={"amount": 2})]),
    ),
    "yixigong": (
        dict(id="yixigong-cook", name="熬糖烹饪", text="使用法术牌后，饴细工获得 1 点力量（法术烹饪简化）。",
             hooks=[dict(id="sugar-cook", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 1})]),
        dict(id="yixigong-cook-awakened", name="糖人烹饪", text="使用法术牌后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="sugar-cook-a", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 2})]),
    ),
    "limao": (
        dict(id="limao-stun", name="醉翁反打", text="受到伤害时，狸猫获得 1 点力量（眩晕反打简化）。",
             hooks=[dict(id="drunk-hit", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 1})]),
        dict(id="limao-stun-awakened", name="烈酒反打", text="受到伤害时，狸猫获得 2 点力量。",
             hooks=[dict(id="drunk-hit-a", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 2})]),
    ),
    "tuwan": (
        dict(id="tuwan-food", name="觅食", text="己方回合开始时，将一张「不明食材」置入手牌（运势失败食材简化）。",
             hooks=[dict(id="bunny-food", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["shi-cai"], "count": 1})]),
        dict(id="tuwan-food-awakened", name="美食之魂", text="己方回合开始时，将一张「佳肴」置入手牌，兔丸获得 1 点力量。",
             hooks=[
                 dict(id="bunny-food-a", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["jia-yao"], "count": 1}),
                 dict(id="bunny-food-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
}


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
        non_awaken_ssr = [(oid, m) for oid, m in ssr_starters if m.get("type") != "awakening"]
        awaken_ssr = [(oid, m) for oid, m in ssr_starters if m.get("type") == "awakening"]
        if len(non_awaken_ssr) + (1 if awaken_ssr else 0) > 1:
            for oid, meta in non_awaken_ssr:
                cut = meta.get("starter") or 0
                meta["starter"] = 0
                total -= cut
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


def main() -> None:
    shiks = {s["name"]: s for s in json.loads((DATA / "shikigami.json").read_text(encoding="utf-8"))}
    cards = json.loads((DATA / "cards.json").read_text(encoding="utf-8"))
    by_id = {}
    for c in cards:
        oid = c.get("id")
        if oid is None:
            continue
        by_id[oid] = c

    normalize_keywords()
    normalize_starters()

    lines = []
    lines.append("/**")
    lines.append(" * 繁花·浮生·喧哗（wave5，24 式神）内容 — 由 scripts/gen-wave5-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE5_PACK_ID = 'wave5';")
    lines.append("export const WAVE5_PACK_NAME = '繁花·浮生·喧哗';")
    lines.append("export const WAVE5_SUBPACKS = Object.freeze({ fanhua: '繁花入梦', fusheng: '浮生方醒', xuanhua: '喧哗烩战' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE5_UNIT_DEFINITIONS = Object.freeze([")

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
        lines.append(f"    art: {js_str(f'assets/wave5/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave5/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave5')},")
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
    lines.append("function wave5Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave5',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE5_CARD_DEFINITIONS = Object.freeze([")

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
        lines.append(f"  wave5Card({official_id}, {js_str(unit_id)}, {{")
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
        lines.append(f"  wave5Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave5UnitIds() {")
    lines.append("  return WAVE5_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
