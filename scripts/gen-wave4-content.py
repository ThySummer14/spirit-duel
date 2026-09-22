#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave4.js（吉运·四相·善恶，26 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave4.js"

# (uid, role, name, title, archetype, color, strategy, subpack)
UNITS = [
    ("jieshen", 216, "缘结神", "缘结", "缘结 / 过牌", "#e08a6a", "为牌库结缘，抽缘结牌续航。", "jiyun"),
    ("gitongwan", 214, "鬼童丸", "修罗", "成长 / 连击", "#8a4a5a", "筛牌成长，修罗骸锁连打。", "jiyun"),
    ("banruo", 215, "般若", "嫉恨", "占卜 / 爆发", "#c05050", "占卜窥顶，妒生千面爆发。", "jiyun"),
    ("tieshu", 212, "铁鼠", "财宝", "幸运钱币 / 节奏", "#d4a020", "敛财叠钱币，天降横财收割。", "jiyun"),
    ("hetong", 213, "河童", "川流", "运势 / 占卜", "#4a9a8a", "运势占卜叠骰点，川沼怪谈。", "jiyun"),
    ("zhuiyueshen", 197, "追月神", "宵月", "充能 / 节奏", "#9a8ac0", "抽牌结宵月，神无月控火。", "jiyun"),
    ("baimugui", 196, "百目鬼", "窥视", "占卜 / 投射", "#6a5a9a", "占卜触发投射，诅咒之眼。", "jiyun"),
    ("wushizhiling", 193, "武士之灵", "幽魂", "气绝 / 亡语", "#7a6a5a", "切腹转幽魂，怨灵斩收割。", "jiyun"),
    ("guishiheibai", 194, "鬼使黑/鬼使白", "无常", "切换 / 爆能", "#4a4a5a", "黑白切换，索命宣判。", "jiyun"),
    ("huoqumo", 204, "火取魔", "红莲", "派系成长 / 贯通", "#c04030", "红莲连打成长，火取剑豪。", "sixiang"),
    ("yuanjiulanghu", 205, "源九郎狐", "紫岩", "治疗 / 成长", "#8a60b0", "过量治疗转攻，御先狐甲破。", "sixiang"),
    ("yingxueji", 207, "樱雪姬", "青岚", "投射 / 控制", "#d07090", "青岚连打投射，写意清场。", "sixiang"),
    ("jingliuliqian", 206, "净琉璃御前", "苍叶", "派系强化 / 直击", "#50a090", "苍叶共鸣增伤，净琉璃齐攻。", "sixiang"),
    ("egui", 217, "饿鬼", "饱腹", "吞噬 / 成长", "#a06030", "移除目标结饱腹，吞天成长。", "sixiang"),
    ("duyanxiaoseng", 188, "独眼小僧", "金刚", "反击 / 承伤", "#8a7a50", "受击投射反击，怒目金刚。", "sixiang"),
    ("mianqiling", 208, "面灵气", "千面", "派系 / 灵巧", "#7060a0", "换面应敌，妒心轮回。", "sixiang"),
    ("jiumingmao", 201, "九命猫", "九命", "复活 / 连击", "#d08040", "九命复归，猫乱步连打。", "sixiang"),
    ("axiuluo", 224, "阿修罗", "业火", "自伤 / 成长", "#b03030", "以伤换力，无尽业火。", "sixiang"),
    ("bayiqidashe", 220, "八岐大蛇", "蛇魔", "献祭 / 复制", "#4a6030", "献祭转蛇魔，狭间蛇神。", "shanewu"),
    ("jinyuji", 227, "金鱼姬", "金鱼", "结附 / 法术", "#e08090", "金鱼应援强化，荒川金鱼姬。", "shanewu"),
    ("huangkulou", 226, "荒骷髅", "亡骨", "气绝 / 复活", "#6a5a40", "气绝可用牌，花海突刺。", "shanewu"),
    ("gouchang", 211, "垢尝", "净甲", "护甲 / 反伤", "#60a0a0", "受伤叠甲，阶前雪。", "shanewu"),
    ("dishitian", 225, "帝释天", "莲华", "莲华 / 控制", "#e0c060", "结莲华压制，圣子复制。", "shanewu"),
    ("xieji", 210, "蟹姬", "横行", "增强 / 连打", "#d06040", "同名连用叠强，少主救救我。", "shanewu"),
    ("yuzaoqian", 221, "玉藻前", "狐火", "法术 / 投射", "#c04060", "手外用牌投射，九尾煌炎。", "shanewu"),
    ("huibishou", 209, "惠比寿", "福运", "升级 / 复活", "#40a080", "升级赐福，十日戎。", "shanewu"),
]

ROLE_TO_UID = {role: uid for uid, role, *_ in UNITS}

RARITY = {"R": "R", "SR": "SR", "SSR": "SSR", None: "R", "": "R", "N": "R", "SKIN": "R"}


def slug(text: str) -> str:
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "card"


def unit_of(oid: int) -> str:
    return ROLE_TO_UID[oid // 100]


# 手写映射：只收录可构筑的专属牌（跳过式神卡、SKIN 重复、空描述协战）
# 简化原则同经典/wave2/wave3；officialText 保留原文。
CARD_MAP: dict[int, dict] = {
    # ---- 缘结神 216 ----
    21601: dict(name="旅人", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="抽两张牌（缘结抽取简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                tags=["过牌", "缘结"]),
    21602: dict(name="结缘女神", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+4。回合开始抽一张牌（缘结触发简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 4})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-jieshen-goddess", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "缘结"]),
    21603: dict(name="绯色花月", type="realm", level=1, cost=1, rarity="R", starter=2,
                text="幻境（耐久 5）：己方回合开始时，抽一张牌（多结缘一张简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                tags=["幻境", "缘结"]),
    21604: dict(name="木偶商人", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。抽牌时获得 1 点鬼火（缘结牌触发简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "energy-gain", "ally-player", 1)],
                formAbility="己方回合开始时，获得 1 点鬼火。",
                formHooks=[{"id": "form-jieshen-puppet", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "缘结"]),
    21605: dict(name="神赐良缘", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+5。己方回合开始时，占卜 1（缘结复活简化为占卜）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5}), ("always", "divination", "ally-player", 1)],
                formAbility="己方回合开始时，占卜 1。",
                formHooks=[{"id": "form-jieshen-fate", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                keywords=["DIVINATION"], tags=["形态", "缘结", "占卜"]),
    21606: dict(name="月下花", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="使一个己方式神获得 +3/+3 与 3 点护甲（鼓舞简化）。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 3, "hp": 3}), ("always", "shield", "selected-ally", 3)],
                tags=["鼓舞", "缘结"]),
    21607: dict(name="都要在一起！", type="spell", level=3, cost=0, rarity="R", starter=0, deck_limit=2,
                text="瞬发。抽三张牌（缘结洗回简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 3)],
                keywords=["INSTANT"], tags=["瞬发", "缘结", "过牌"]),
    21608: dict(name="觉醒·缘结神", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。回合结束多结缘简化为回合开始抽一张牌。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "draw", "ally-player", 1)],
                tags=["觉醒", "缘结"]),

    # ---- 鬼童丸 214 ----
    21401: dict(name="嗜杀冲动", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。进场投射 2 点伤害（抽到自动攻击简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "damage-enemy-front", "auto", 2)],
                formAbility="己方回合开始时，投射：造成 1 点伤害。",
                formHooks=[{"id": "form-gitong-frenzy", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "成长"]),
    21402: dict(name="降诛", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。出击 +2（抽到回合瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["INSTANT"], tags=["出击", "瞬发"]),
    21403: dict(name="引路人", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。离场洗回简化为进场获得 +1/+1。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "buff-stats", "source", {"attack": 1, "hp": 1})],
                tags=["形态", "成长"]),
    21404: dict(name="觉醒·鬼童丸", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。回合开始筛牌简化为获得 +1/+1。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒", "成长"]),
    21405: dict(name="修罗之鬼", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+6 与不屈（抽到不屈简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "不屈"]),
    21406: dict(name="猎魂狂杀", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2，连击（追猎必杀简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["COMBO"], tags=["出击", "连击"]),
    21407: dict(name="修罗骸锁", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="出击 +3，然后抽一张牌（再攻击简化为过牌）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "draw", "ally-player", 1)],
                tags=["出击", "过牌"]),
    21408: dict(name="残月鬼衣", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +7/+7。进场占卜 3，气绝复归简化为获得不屈。",
                target="auto", effects=[("always", "form", "source", {"attack": 7, "hp": 7}), ("always", "divination", "ally-player", 3), ("always", "grant-unyielding", "source", 1)],
                keywords=["DIVINATION"], tags=["形态", "占卜"]),

    # ---- 般若 215 ----
    21501: dict(name="鬼袭", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1，本次战斗免疫伤害简化为获得 2 点护甲。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "shield", "source", 2)],
                tags=["出击"]),
    21502: dict(name="换面", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +1，并抽一张牌（置顶简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "draw", "ally-player", 1)],
                tags=["出击", "过牌"]),
    21503: dict(name="怨海唤声", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2。本回合已占卜则瞬发（简化为瞬发）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["INSTANT"], tags=["出击", "占卜"]),
    21504: dict(name="嫉恨之心", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，般若永久 +2 力量（洗回叠伤简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                tags=["出击", "成长"]),
    21505: dict(name="恶戏", type="combat", level=1, cost=0, rarity="R", starter=1,
                text="出击 +1（牌库顶自动使用简化为 0 费出击）。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                tags=["出击"]),
    21506: dict(name="妒生千面", type="combat", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="出击 +4，连击（五张恶戏简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["COMBO"], tags=["出击", "爆发"]),
    21507: dict(name="复仇之香", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +3/+8，暴击（简化为进场投射 3 伤害）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8}), ("always", "damage-enemy-front", "auto", 3)],
                keywords=["CRIT"], tags=["形态", "暴击"]),
    21508: dict(name="觉醒·般若", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1，迅捷。首次伤牌手占卜简化为进场占卜 2。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "divination", "ally-player", 2)],
                keywords=["DIVINATION"], tags=["觉醒", "占卜"]),

    # ---- 铁鼠 212 ----
    21201: dict(name="敛财", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1。将一张「幸运钱币」置入手牌。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "token-to-hand", "ally-player", {"tokens": ["xingyun-qianbi"], "count": 1})],
                tags=["出击", "幸运钱币"]),
    21202: dict(name="生财有术", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+4。回合开始将一张「幸运钱币」置入手牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 4})],
                formAbility="己方回合开始时，将一张「幸运钱币」置入手牌。",
                formHooks=[{"id": "form-tieshu-coin", "event": "turn-started", "effect": "passive-token-to-hand", "params": {"tokens": ["xingyun-qianbi"], "count": 1}, "priority": 40}],
                tags=["形态", "幸运钱币"]),
    21203: dict(name="钱儿响叮当", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +2，并获得 2 点护甲（钱币增强简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
                tags=["出击", "幸运钱币"]),
    21204: dict(name="有鼠如宝", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+4。受到伤害时获得 2 点护甲（钱币响应简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 4})],
                formAbility="受到伤害时，获得 1 点护甲。",
                formHooks=[{"id": "form-tieshu-treasure", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "幸运钱币"]),
    21205: dict(name="骗局", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +1，必杀简化为投射 2 点伤害。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "damage-enemy-front", "auto", 2)],
                tags=["出击", "幸运钱币"]),
    21206: dict(name="钱多不压身", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+5。回合开始铁鼠获得 +1/+1（钱币强化简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                formAbility="己方回合开始时，铁鼠获得 +1/+1。",
                formHooks=[{"id": "form-tieshu-rich", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "幸运钱币"]),
    21207: dict(name="天降横财", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="投射：造成 4 点伤害，再对敌方前线造成 3 点伤害（多钱币投射简化）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 4), ("always", "damage-enemy-front", "auto", 3)],
                keywords=["PROJECTILE"], tags=["投射", "幸运钱币", "终结"]),
    21208: dict(name="觉醒·铁鼠", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。将一张「幸运钱币」置入手牌，并获得 1 点鬼火。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "token-to-hand", "ally-player", {"tokens": ["xingyun-qianbi"], "count": 1}), ("always", "energy-gain", "ally-player", 1)],
                tags=["觉醒", "幸运钱币"]),

    # ---- 河童 213 ----
    21301: dict(name="河中窥探", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="占卜 3，抽一张牌。",
                target="auto", effects=[("always", "divination", "ally-player", 3), ("always", "draw", "ally-player", 1)],
                keywords=["DIVINATION"], tags=["占卜", "过牌"]),
    21302: dict(name="水流弹", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个式神造成 2 点伤害并施加 2 点破甲（运势追伤简化并入）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2), ("always", "apply-armor-break", "selected-enemy", 2)],
                tags=["伤害", "破甲"]),
    21303: dict(name="鲤之缘", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。进场占卜 1（骰点加成简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "divination", "ally-player", 1)],
                keywords=["DIVINATION"], tags=["形态", "占卜"]),
    21304: dict(name="夏之河童", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+7。完成交战后恢复 2 点生命（运势吸血简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7}), ("always", "heal", "source", 2)],
                formAbility="完成交战后，河童恢复 2 点生命。",
                formHooks=[{"id": "form-hetong-summer", "event": "combat-resolved", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "吸血"]),
    21305: dict(name="觉醒·河童", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。占卜 1 并抽一张牌。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "divination", "ally-player", 1), ("always", "draw", "ally-player", 1)],
                keywords=["DIVINATION"], tags=["觉醒", "占卜"]),
    21306: dict(name="大河之歌", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="对所有敌方式神造成 2 点伤害（按顶牌等级简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["伤害", "清场"]),
    21307: dict(name="乱流", type="realm", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害（乱流干扰简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                tags=["幻境", "干扰"]),
    21308: dict(name="川沼怪谈", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +8/+8 与不屈（骰点叠层简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 8, "hp": 8}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "不屈", "终结"]),

    # ---- 追月神 197 ----
    19701: dict(name="月海潮生", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="占卜 2，并获得 1 点鬼火。",
                target="auto", effects=[("always", "divination", "ally-player", 2), ("always", "energy-gain", "ally-player", 1)],
                keywords=["DIVINATION"], tags=["占卜", "充能"]),
    19702: dict(name="满月", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="为一个己方式神恢复 5 点生命（移除灵咒回满简化）。",
                target="ally-unit", effects=[("always", "heal", "selected-ally", 5)],
                tags=["治疗"]),
    19703: dict(name="邀月", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="抽两张牌（置顶简化省略）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                tags=["过牌", "宵月"]),
    19704: dict(name="月盈则亏", type="spell", level=3, cost=2, rarity="SR", starter=0, deck_limit=2,
                text="复活一个己方气绝式神，并对所有敌方式神造成 2 点伤害（消灭/复活简化）。",
                target="knocked-ally", effects=[("always", "revive", "selected-ally", None), ("always", "damage", "all-enemy-units", 2)],
                tags=["复活", "清场"]),
    19705: dict(name="月食", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="响应：当你的式神被攻击时，自动使用，使其获得 3 点护甲（敌方失火简化）。",
                target="auto", effects=[("always", "shield", "source", 3)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "控火"]),
    19706: dict(name="觉醒·追月神", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。抽一张牌并获得 1 点鬼火（宵月强化简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
                tags=["觉醒", "宵月"]),
    19707: dict(name="清辉月华", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。进场获得 1 点鬼火（移除宵月出击简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "energy-gain", "ally-player", 1)],
                formAbility="己方回合开始时，获得 1 点鬼火。",
                formHooks=[{"id": "form-zhuiyue-clear", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "宵月"]),
    19708: dict(name="神无月之佑", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 8）：己方回合开始时，抽一张牌并获得 1 点护甲（清空鬼火简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                tags=["幻境", "保护"]),

    # ---- 百目鬼 196 ----
    19601: dict(name="瞥视未来", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="占卜 1，抽两张牌。",
                target="auto", effects=[("always", "divination", "ally-player", 1), ("always", "draw", "ally-player", 2)],
                keywords=["DIVINATION"], tags=["占卜", "过牌"]),
    19602: dict(name="瞳炎", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对一个敌方式神造成 2 点伤害，并抽一张牌（洗回叠伤简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2), ("always", "draw", "ally-player", 1)],
                tags=["伤害", "占卜"]),
    19603: dict(name="洞察之眼", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。回合开始占卜 1（占卜 +1 简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="己方回合开始时，占卜 1。",
                formHooks=[{"id": "form-baimu-insight", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "占卜"]),
    19604: dict(name="念袭", type="spell", level=1, cost=0, rarity="R", starter=1,
                text="瞬发。投射：造成 1 点伤害（移动式神简化）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 1)],
                keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射"]),
    19605: dict(name="觉醒·百目鬼", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。占卜 2 并对敌方前线造成 1 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "divination", "ally-player", 2), ("always", "damage-enemy-front", "auto", 1)],
                keywords=["DIVINATION"], tags=["觉醒", "占卜", "投射"]),
    19606: dict(name="鬼眸", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 4 点伤害，并抽一张牌。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4), ("always", "draw", "ally-player", 1)],
                tags=["伤害", "过牌"]),
    19607: dict(name="全知之眼", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对一个敌方式神造成 5 点伤害（消灭对应式神简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)],
                tags=["伤害", "终结"]),
    19608: dict(name="诅咒之眼", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +4/+8。回合开始对敌方前线造成 2 点伤害（诅咒占卜简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-baimu-curse", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "诅咒"]),

    # ---- 武士之灵 193 ----
    19301: dict(name="武士之心", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2（幽魂瞬发简化为常驻瞬发）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["INSTANT"], tags=["出击", "幽魂"]),
    19302: dict(name="切腹", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对你造成 3 点伤害，武士之灵永久 +3 力量（自绝转幽魂简化）。",
                target="auto", effects=[("always", "damage-self", "source", 3), ("always", "buff-stats", "source", {"attack": 3, "hp": 0})],
                tags=["自伤", "幽魂"]),
    19303: dict(name="唐竹", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +3（失去直击牌手简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                tags=["出击"]),
    19304: dict(name="不甘之怒", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，连击（气绝再使用简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["COMBO"], tags=["出击", "连击"]),
    19305: dict(name="荣耀终刻", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="出击 +4（无文本卡面按大伤害战斗简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                tags=["出击", "爆发"]),
    19306: dict(name="怨灵斩", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2。若有己方气绝式神，额外 +2 力量简化为并入 +4。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                tags=["出击", "亡语"]),
    19307: dict(name="灭魂", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2，并对敌方牌手造成 2 点伤害（追猎简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 2)],
                tags=["出击", "幽魂"]),
    19308: dict(name="觉醒·武士之灵", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+2/+0，迅捷。对你造成 2 点伤害（不能复活/永迅捷简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 0}), ("always", "damage-self", "source", 2)],
                tags=["觉醒", "幽魂"]),

    # ---- 鬼使黑/鬼使白 194 ----
    19401: dict(name="冥界之镰", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1，贯通（爆能瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["PIERCE"], tags=["出击", "贯通"]),
    19402: dict(name="兄弟之忆", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="鬼使获得 +2/+1 并获得 2 点护甲（切换攻击简化）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 2, "hp": 1}), ("always", "shield", "source", 2)],
                tags=["切换", "鬼使白"]),
    19403: dict(name="惩戒", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2（爆能追猎简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击", "切换"]),
    19404: dict(name="觉醒·鬼使黑/鬼使白", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1，充能迅捷简化为获得 1 点能量与 +1/+1。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "energy-gain", "ally-player", 1)],
                tags=["觉醒", "切换"]),
    19405: dict(name="无常鬼使", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="鬼使获得 +3/+1，并立刻出击 +2（响应切换简化）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 3, "hp": 1}), ("source-ready", "assault", "source", 2)],
                tags=["切换", "响应"]),
    19406: dict(name="索命", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="出击 +3，并投射：造成 2 点伤害（叠层复制简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "damage-enemy-front", "auto", 2)],
                keywords=["PROJECTILE"], tags=["出击", "投射"]),
    19408: dict(name="夺命宣判", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +6/+5，必杀。回合结束切换简化为回合开始获得 2 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 5})],
                formAbility="己方回合开始时，获得 2 点护甲。",
                formHooks=[{"id": "form-guishi-judge", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "切换"]),
    19409: dict(name="活死人", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。造成伤害时获得 1 点能量（简化为完成交战后获得 1 点能量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="完成交战后，你获得 1 点能量。",
                formHooks=[{"id": "form-guishi-undead", "event": "combat-resolved", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "充能"]),

    # ---- 火取魔 204 ----
    20401: dict(name="夜袭", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2（出击加成/瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击", "红莲"]),
    20402: dict(name="蛮勇剑豪", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6，贯通（高力量加成简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                keywords=["PIERCE"], tags=["形态", "贯通", "红莲"]),
    20403: dict(name="任侠", type="spell", level=2, cost=0, rarity="SR", starter=1,
                text="瞬发。使一个己方式神获得 +3 力量（追猎增强简化）。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 3, "hp": 0})],
                keywords=["INSTANT"], tags=["瞬发", "红莲"]),
    20404: dict(name="鵺之火", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 6）：己方回合开始时，抽一张牌（最大力量判定简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                tags=["幻境", "红莲"]),
    20405: dict(name="叶隐剑豪", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+4，贯通（每红莲式神 +1/+1 简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 4})],
                keywords=["PIERCE"], tags=["形态", "贯通", "红莲"]),
    20406: dict(name="觉醒·火取魔", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。所有其他己方式神获得 +1/+1（红莲共鸣简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1})],
                tags=["觉醒", "红莲"]),
    20407: dict(name="义盟", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="使所有己方式神获得 +2/+2 与 2 点护甲（鼓舞简化）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 2}), ("always", "shield", "all-ally-units", 2)],
                tags=["鼓舞", "红莲"]),
    20408: dict(name="火取剑豪", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+5，贯通。回合开始火取魔获得 +1/+1（吸收队友简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                formAbility="己方回合开始时，火取魔获得 +1/+1。",
                formHooks=[{"id": "form-huoqu-blade", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                keywords=["PIERCE"], tags=["形态", "成长", "红莲"]),

    # ---- 源九郎狐 205 ----
    20501: dict(name="狐手", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2，并恢复 2 点生命（过量治疗转力量简化并入）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "heal", "source", 2)],
                tags=["出击", "治疗", "紫岩"]),
    20502: dict(name="狐辞", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。为一个角色恢复 3 点生命，或为源九郎狐获得 3 点护甲（二选一简化为兼得护甲）。",
                target="ally-unit", effects=[("always", "heal", "selected-ally", 3), ("always", "shield", "source", 3)],
                keywords=["INSTANT"], tags=["瞬发", "治疗", "紫岩"]),
    20503: dict(name="觉醒·源九郎狐", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。所有其他己方式神获得 +1/+1（紫岩共鸣简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1})],
                tags=["觉醒", "紫岩"]),
    20504: dict(name="御先狐", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+7。完成交战后，使目标获得 3 点破甲并获得 3 点护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7}), ("always", "shield", "source", 3)],
                formAbility="完成交战后，对敌方前线施加 2 点破甲。",
                formHooks=[{"id": "form-yuanjiu-miko", "event": "combat-resolved", "effect": "passive-armor-break-enemy-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "破甲", "紫岩"]),
    20505: dict(name="初音鼓", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="复活一个己方气绝式神，使其获得 +1/+1（移动/派系增强简化）。",
                target="knocked-ally", effects=[("always", "revive", "selected-ally", None), ("always", "buff-stats", "selected-ally", {"attack": 1, "hp": 1})],
                tags=["复活", "紫岩"]),
    20506: dict(name="狐狸六法", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 6）：己方回合开始时，所有己方式神获得 1 点护甲（最大生命判定简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
                tags=["幻境", "紫岩"]),
    20508: dict(name="灵狐之嗣", type="form", level=3, cost=1, rarity="R", starter=0, deck_limit=2,
                text="获得 +4/+4 与不屈（派系数量叠层简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 4}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "不屈", "紫岩"]),
    20509: dict(name="道行初音旅", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="所有己方式神永久获得 +2/+2（回合结束叠层简化）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 2})],
                tags=["成长", "紫岩", "终结"]),

    # ---- 樱雪姬 207 ----
    20701: dict(name="意临", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="眩晕一个式神。将一张「俱利伽罗丸」置入手牌。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 1), ("always", "token-to-hand", "ally-player", {"tokens": ["julijialuo-wan"], "count": 1})],
                keywords=["STUN"], tags=["眩晕", "青岚"]),
    20702: dict(name="窥秘之瞳", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+5。回合开始投射 2 点伤害（能量眩晕简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 5})],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-yingxue-gaze", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "投射", "青岚"]),
    20703: dict(name="勾勒", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="抽两张牌（占卜 3 简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                tags=["过牌", "青岚"]),
    20704: dict(name="画境苏生", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+6，远程（派系叠力量简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                keywords=["REMOTE"], tags=["形态", "远程", "青岚"]),
    20705: dict(name="红染之樱", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 6）：己方回合开始时，抽一张牌（二连青岚过牌简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                tags=["幻境", "青岚"]),
    20706: dict(name="觉醒·樱雪姬", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。所有其他己方式神获得 +1/+1，并投射 2 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1}), ("always", "damage-enemy-front", "auto", 2)],
                tags=["觉醒", "投射", "青岚"]),
    20707: dict(name="写意", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="眩晕所有敌方式神，然后对所有敌方式神造成 2 点伤害（随机眩晕+消灭简化）。",
                target="auto", effects=[("always", "freeze", "all-enemy-units", 1), ("always", "damage", "all-enemy-units", 2)],
                keywords=["STUN"], tags=["眩晕", "清场", "青岚"]),
    20708: dict(name="山之石雪之雫", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 10）：己方回合开始时，己方前线获得 3 点护甲（免疫战斗/眩晕简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 10, "trigger": "owner-turn-start", "triggerEffect": "shield-front", "triggerValue": 3},
                tags=["幻境", "保护", "青岚"]),

    # ---- 净琉璃御前 206 ----
    20601: dict(name="无染", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+5，迅捷（派系叠力量简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5})],
                tags=["形态", "苍叶"]),
    20602: dict(name="明澈", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2（运势强化简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击", "苍叶"]),
    20603: dict(name="启示", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对一个式神造成 3 点伤害（贯通增强简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)],
                tags=["伤害", "苍叶"]),
    20604: dict(name="琉璃光境", type="realm", level=2, cost=1, rarity="R", starter=1,
                text="幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害（对牌手伤害 +1 简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                tags=["幻境", "苍叶"]),
    20605: dict(name="双生", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +6/+5。完成交战后获得 +1 力量（倒计时攻击简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 5})],
                formAbility="完成交战后，净琉璃御前获得 1 点力量。",
                formHooks=[{"id": "form-jingliu-twin", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "苍叶"]),
    20606: dict(name="觉醒·净琉璃御前", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。所有其他己方式神获得 +1/+1（苍叶共鸣简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1})],
                tags=["觉醒", "苍叶"]),
    20607: dict(name="暗羽", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="所有己方式神获得 +2 力量（直击简化）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 0})],
                tags=["强化", "苍叶"]),
    20608: dict(name="净琉璃", type="combat", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="出击 +4，贯通。所有己方式神获得 1 点护甲（齐攻简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 4), ("always", "shield", "all-ally-units", 1)],
                keywords=["PIERCE"], tags=["出击", "贯通", "苍叶", "终结"]),

    # ---- 饿鬼 217 ----
    21701: dict(name="生食", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1，对目标施加 2 点破甲，并获得 2 点护甲（吞噬护甲简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "apply-armor-break", "auto", 2), ("always", "shield", "source", 2)],
                tags=["出击", "吞噬"]),
    21702: dict(name="饥不择食", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +1，移除敌方前线护甲简化为施加 3 点破甲。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "apply-armor-break", "auto", 3)],
                tags=["出击", "吞噬", "幻境"]),
    21703: dict(name="大快朵颐", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+6，迅捷（饱腹迅捷简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6})],
                tags=["形态", "吞噬"]),
    21704: dict(name="鲸吞", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 4 点伤害（移除形态简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["伤害", "吞噬"]),
    21705: dict(name="酒饱饭足", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+8 与不屈（饱腹强化简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "不屈", "吞噬"]),
    21706: dict(name="回味", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="抽两张牌，饿鬼获得 +2/+2 并恢复 3 点生命（三重回味简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2), ("always", "buff-stats", "source", {"attack": 2, "hp": 2}), ("always", "heal", "source", 3)],
                tags=["过牌", "成长", "吞噬"]),
    21707: dict(name="吞天", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+5。回合开始饿鬼获得 +1/+1（移除次数叠层简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                formAbility="己方回合开始时，饿鬼获得 +1/+1。",
                formHooks=[{"id": "form-egui-devour", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "成长", "吞噬"]),
    21708: dict(name="觉醒·饿鬼", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。对一个敌方式神施加 3 点破甲并偷取简化为饿鬼 +2/+2。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒", "吞噬"]),

    # ---- 独眼小僧 188 ----
    18801: dict(name="布施", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。独眼小僧获得 2 点护甲（强制交战简化）。",
                target="auto", effects=[("always", "shield", "source", 2)],
                keywords=["INSTANT"], tags=["瞬发", "金刚"]),
    18802: dict(name="心经", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +0/+7。回合开始恢复 4 点生命（回合结束回满简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 0, "hp": 7})],
                formAbility="己方回合开始时，恢复 4 点生命。",
                formHooks=[{"id": "form-duyan-sutra", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 4}, "priority": 40}],
                tags=["形态", "治疗", "金刚"]),
    18803: dict(name="投石", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个式神造成 1 点伤害，并使所有敌方式神 -1 力量（激怒简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 1), ("always", "debuff-stats", "all-enemy-units", {"attack": 1, "hp": 0})],
                tags=["伤害", "削弱", "金刚"]),
    18804: dict(name="金刚经", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +0/+8。受到伤害时获得 2 点护甲（承伤-1 简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 0, "hp": 8})],
                formAbility="受到伤害时，获得 2 点护甲。",
                formHooks=[{"id": "form-duyan-vajra", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "护甲", "金刚"]),
    18805: dict(name="觉醒·独眼小僧", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。受到伤害时，对敌方前线造成 1 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒", "反击", "金刚"]),
    18806: dict(name="石像冲击", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +1，并对敌方前线造成 2 点伤害（激怒简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "damage-enemy-front", "auto", 2)],
                tags=["出击", "反击", "金刚"]),
    18807: dict(name="无欲则刚", type="form", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="获得 +0/+12，不屈。回合开始获得 2 点护甲（承伤简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 0, "hp": 12}), ("always", "grant-unyielding", "source", 1)],
                formAbility="己方回合开始时，获得 2 点护甲。",
                formHooks=[{"id": "form-duyan-firm", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "不屈", "金刚"]),
    18808: dict(name="怒目金刚", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +6/+10。完成交战后对敌方前线造成 3 点伤害（非战斗 +2 简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 10})],
                formAbility="己方回合开始时，投射：造成 3 点伤害。",
                formHooks=[{"id": "form-duyan-wrath", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "反击", "金刚"]),

    # ---- 面灵气 208 ----
    20801: dict(name="新生双面", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。抽一张牌，面灵气获得 +1/+1（换派系简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "buff-stats", "source", {"attack": 1, "hp": 1})],
                keywords=["INSTANT"], tags=["瞬发", "千面"]),
    20802: dict(name="心生七面", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +2，并获得 2 点护甲（同派必杀/异派免伤简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
                tags=["出击", "千面"]),
    20803: dict(name="幻化万象", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6（变换派系简化为面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                tags=["形态", "千面"]),
    20804: dict(name="自欺", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 4 点伤害（按派系数叠伤简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["伤害", "千面"]),
    20805: dict(name="禁断之面", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="抽三张牌（按派系数抽牌简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 3)],
                tags=["过牌", "千面"]),
    20806: dict(name="轮回之面", type="form", level=2, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+5。回合开始面灵气获得 +1/+1（随机换派系简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                formAbility="己方回合开始时，面灵气获得 +1/+1。",
                formHooks=[{"id": "form-mianqi-cycle", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "千面"]),
    20807: dict(name="觉醒·面灵气", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+2/+2。受到伤害时获得 2 点护甲（派系增减伤强化简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒", "千面"]),
    20808: dict(name="妒心", type="spell", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="投射：造成 4 点伤害，再对敌方前线造成 2 点伤害（三连派系投射简化）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 4), ("always", "damage-enemy-front", "auto", 2)],
                keywords=["PROJECTILE"], tags=["投射", "千面"]),

    # ---- 九命猫 201 ----
    20101: dict(name="猫爪", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2（九命叠伤简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击", "九命"]),
    20102: dict(name="铃铛", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+4（九命力量简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 4})],
                tags=["形态", "九命"]),
    20103: dict(name="延命", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+4。回合开始恢复 2 点生命（移除九命简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 4})],
                formAbility="己方回合开始时，恢复 2 点生命。",
                formHooks=[{"id": "form-jiu-life", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "九命"]),
    20104: dict(name="猫车", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="瞬发。获得 +3/+3。其他式神气绝时，九命猫获得 +1/+1（移动复活简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 3})],
                formAbility="其他式神气绝时，九命猫获得 +1/+1。",
                formHooks=[{"id": "form-jiu-cart", "event": "unit-knocked-out", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                keywords=["INSTANT"], tags=["形态", "九命"]),
    20105: dict(name="报复", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2。响应：当九命猫被攻击时，自动使用并获得 2 点护甲（死后反击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["出击", "响应", "九命"]),
    20106: dict(name="猫乱步", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，连击（追猎两连简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["COMBO"], tags=["出击", "连击", "九命"]),
    20107: dict(name="向死而生", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="九命猫获得 +2/+2、迅捷与不屈，并抽两张牌（终极复归简化）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 2, "hp": 2}), ("always", "grant-unyielding", "source", 1), ("always", "draw", "ally-player", 2)],
                tags=["成长", "九命", "终结"]),
    20108: dict(name="觉醒·九命猫", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1 与不屈（气绝复归攻击简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "grant-unyielding", "source", 1)],
                tags=["觉醒", "九命"]),

    # ---- 阿修罗 224 ----
    22401: dict(name="黑暗之子", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+7。完成交战后对你造成 1 点伤害（攻击反噬简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7}), ("always", "damage-self", "source", 1)],
                formAbility="完成交战后，对你造成 1 点伤害。",
                formHooks=[{"id": "form-axiuluo-dark", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "自伤"]),
    22402: dict(name="征伐", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，贯通。对你造成 2 点伤害（承伤转移简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "damage-self", "source", 2)],
                keywords=["PIERCE"], tags=["出击", "自伤", "贯通"]),
    22403: dict(name="浴血", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1。瞬发（自伤后瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["INSTANT"], tags=["出击", "自伤"]),
    22404: dict(name="狱渊魔神", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+7。进场时对你造成 3 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 7}), ("always", "damage-self", "source", 3)],
                tags=["形态", "自伤"]),
    22405: dict(name="破渊", type="combat", level=2, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="出击 +3。对你造成 2 点伤害，阿修罗获得 +2 力量（气绝可用简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "damage-self", "source", 2), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                tags=["出击", "自伤", "爆发"]),
    22406: dict(name="无生炼狱", type="realm", level=1, cost=0, rarity="R", starter=1,
                text="瞬发。幻境（耐久 7）：己方回合开始时，为你恢复 2 点生命（自伤回血简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 7, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                keywords=["INSTANT"], tags=["幻境", "自伤"]),
    22407: dict(name="觉醒·阿修罗", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+2/+2。对你造成 2 点伤害，阿修罗再获得 +2 力量。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2}), ("always", "damage-self", "source", 2), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                tags=["觉醒", "自伤"]),
    22408: dict(name="无尽业火", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="出击 +3。对双方所有式神各造成 2 点伤害（对所有角色简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "damage", "all-enemy-units", 2), ("always", "damage", "all-ally-units", 2)],
                tags=["出击", "自伤", "清场"]),

    # ---- 八岐大蛇 220 ----
    22001: dict(name="不洁之力", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个己方其他式神获得 2 力量并立刻出击 +2（献祭攻击简化）。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 2, "hp": 0})],
                tags=["强化", "蛇魔"]),
    22002: dict(name="神念之影", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。回合开始所有己方式神获得 +1 力量（蛇魔昂扬简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="己方回合开始时，所有己方式神获得 1 点力量。",
                formHooks=[{"id": "form-she-shadow", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "蛇魔"]),
    22003: dict(name="献祭", type="spell", level=2, cost=0, rarity="SR", starter=1,
                text="瞬发。对你造成 2 点伤害，抽两张牌并获得 1 点鬼火（消灭队友简化）。",
                target="auto", effects=[("always", "damage-self", "source", 2), ("always", "draw", "ally-player", 2), ("always", "energy-gain", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "蛇魔", "过牌"]),
    22004: dict(name="八岐之影", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +6/+6 与不屈（致死献祭简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "蛇魔", "不屈"]),
    22005: dict(name="神愤之炎", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对所有敌方式神造成 2 点伤害（蛇魔齐攻简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["伤害", "蛇魔", "清场"]),
    22006: dict(name="善恶无则", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="对一个敌方式神造成 5 点伤害，并施加 3 点破甲（变为蛇魔简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5), ("always", "apply-armor-break", "selected-enemy", 3)],
                tags=["伤害", "蛇魔"]),
    22007: dict(name="狭间蛇神", type="form", level=3, cost=1, rarity="R", starter=0, deck_limit=2,
                text="获得 +4/+8。回合开始对随机敌方造成 3 点伤害简化为对敌方前线 3 点。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="己方回合开始时，投射：造成 3 点伤害。",
                formHooks=[{"id": "form-she-narrow", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "蛇魔"]),
    22008: dict(name="觉醒·八岐大蛇", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+2/+2。所有己方式神获得 +1/+1（蛇魔复制简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2}), ("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1})],
                tags=["觉醒", "蛇魔"]),

    # ---- 金鱼姬 227 ----
    22701: dict(name="金鱼·应援", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个己方式神获得 +2/+2（结附金鱼强化简化）。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 2, "hp": 2})],
                tags=["强化", "金鱼"]),
    22702: dict(name="金鱼·修行", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +1，然后移回准备区简化为获得 2 点护甲。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "shield", "source", 2)],
                tags=["出击", "金鱼"]),
    22703: dict(name="金鱼·休憩", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。为一个己方角色恢复 5 点生命。",
                target="ally-unit", effects=[("always", "heal", "selected-ally", 5)],
                keywords=["INSTANT"], tags=["瞬发", "治疗", "金鱼"]),
    22704: dict(name="鱼鱼，我们走！", type="spell", level=2, cost=0, rarity="SR", starter=1,
                text="瞬发。使所有己方式神本回合 +2 力量，抽一张牌（进攻强化简化）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 0}), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "强化", "金鱼"]),
    22705: dict(name="鱼鱼，在这里！", type="spell", level=2, cost=0, rarity="SR", starter=1,
                text="瞬发。所有己方式神获得 2 点护甲，抽一张牌（防御强化简化）。",
                target="auto", effects=[("always", "shield", "all-ally-units", 2), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "护甲", "金鱼"]),
    22706: dict(name="觉醒·金鱼姬", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。将一张「金鱼」置入手牌并抽一张牌。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "token-to-hand", "ally-player", {"tokens": ["jinyu"], "count": 1}), ("always", "draw", "ally-player", 1)],
                tags=["觉醒", "金鱼"]),
    22707: dict(name="扇舞", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="抽一张牌，使所有己方式神获得 +1/+1，并为你恢复 3 点生命（三连 1 级牌简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1}), ("always", "heal-avatar", "ally-avatar", 3)],
                tags=["过牌", "强化", "金鱼"]),
    22708: dict(name="荒川的金鱼姬", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +3/+8。回合开始使所有己方式神 +1/+1（自动用牌简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8})],
                formAbility="己方回合开始时，所有己方式神获得 +1/+1。",
                formHooks=[{"id": "form-jinyu-arikawa", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "强化", "金鱼"]),

    # ---- 荒骷髅 226 ----
    22601: dict(name="毒雾冲击", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1，并对所有敌方式神造成 1 点伤害（战斗区群伤简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "damage", "all-enemy-units", 1)],
                tags=["出击", "亡骨"]),
    22602: dict(name="诘问", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对一个式神造成 3 点伤害（气绝可用/减倒计时简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)],
                tags=["伤害", "亡骨"]),
    22603: dict(name="彼岸的召唤", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+6 与不屈（气绝复活简化为不屈）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "复活", "亡骨"]),
    22604: dict(name="不灭的忠诚", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="响应：当你的式神被攻击时，自动使用，使其获得 4 点护甲（复活响应简化）。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 4)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "护甲", "亡骨"]),
    22605: dict(name="亡者的宴会", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对所有敌方式神造成 2 点伤害（气绝可用群伤简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["伤害", "清场", "亡骨"]),
    22606: dict(name="三途之骨", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +4/+7（敌方回合结束气绝简化为高血形态）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7})],
                tags=["形态", "亡骨"]),
    22607: dict(name="花海突刺", type="combat", level=3, cost=1, rarity="SR", starter=0, deck_limit=2,
                text="出击 +3，连击，并投射：造成 2 点伤害（三连击简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "damage-enemy-front", "auto", 2)],
                keywords=["COMBO", "PROJECTILE"], tags=["出击", "连击", "亡骨"]),
    22608: dict(name="觉醒·荒骷髅", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。荒骷髅获得 3 点护甲与不屈（复活成长简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "shield", "source", 3), ("always", "grant-unyielding", "source", 1)],
                tags=["觉醒", "亡骨"]),

    # ---- 垢尝 211 ----
    21101: dict(name="涂泡泡", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1，并获得 1 点护甲（有甲瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "shield", "source", 1)],
                tags=["出击", "净甲"]),
    21102: dict(name="亮闪闪", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。所有角色获得 1 点护甲，抽一张牌。",
                target="auto", effects=[("always", "shield", "all-ally-units", 1), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "护甲", "净甲"]),
    21103: dict(name="快去洗澡！", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2（追猎必杀简化为出击 +2 与 2 点破甲）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "apply-armor-break", "auto", 2)],
                tags=["出击", "净甲"]),
    21104: dict(name="霉球研究", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+8，贯通。回合开始对敌方前线造成 2 点伤害（护甲投射简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-gouchang-mold", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                keywords=["PIERCE"], tags=["形态", "贯通", "净甲"]),
    21105: dict(name="浴中歌", type="realm", level=1, cost=1, rarity="R", starter=1,
                text="幻境（耐久 8）：己方回合开始时，所有己方式神获得 1 点护甲（有甲 +1 力量简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
                tags=["幻境", "护甲", "净甲"]),
    21106: dict(name="觉醒·垢尝", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+0 与不屈。受伤叠甲强化为获得 2 点护甲。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 0}), ("always", "grant-unyielding", "source", 1), ("always", "shield", "source", 2)],
                tags=["觉醒", "净甲"]),
    21107: dict(name="一篓打尽", type="combat", level=3, cost=1, rarity="R", starter=0, deck_limit=2,
                text="出击 +3，并获得 3 点护甲（移甲叠伤简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "shield", "source", 3)],
                tags=["出击", "净甲"]),
    21108: dict(name="阶前雪", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +6/+5 与不屈。受到伤害时获得 2 点护甲（气绝复归简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 5}), ("always", "grant-unyielding", "source", 1)],
                formAbility="受到伤害时，获得 2 点护甲。",
                formHooks=[{"id": "form-gouchang-snow", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "护甲", "净甲"]),

    # ---- 帝释天 225 ----
    22501: dict(name="恩赐", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。对一个敌方式神造成 2 点伤害，并抽一张牌（结附莲华简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "莲华"]),
    22502: dict(name="圣洁之王", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。回合开始对敌方前线造成 2 点伤害（莲华持续伤简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-dishi-holy", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "莲华"]),
    22503: dict(name="诸善奉行", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="使所有敌方式神 -2 力量（莲华削弱简化）。",
                target="auto", effects=[("always", "debuff-stats", "all-enemy-units", {"attack": 2, "hp": 0})],
                tags=["削弱", "莲华"]),
    22504: dict(name="十善业道", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 4 点伤害（莲华消灭简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["伤害", "莲华"]),
    22505: dict(name="觉醒·帝释天", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。对一个敌方式神造成 3 点伤害并抽一张牌。",
                target="enemy-unit", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "damage", "selected-enemy", 3), ("always", "draw", "ally-player", 1)],
                tags=["觉醒", "莲华"]),
    22506: dict(name="理想国", type="realm", level=2, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 5）：己方回合开始时，所有敌方式神 -1 力量（莲华沉默简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                tags=["幻境", "莲华", "控制"]),
    22507: dict(name="仁慈之王", type="form", level=3, cost=1, rarity="R", starter=0, deck_limit=2,
                text="获得 +5/+7。回合开始获得 1 点鬼火并抽一张牌（莲华回火简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 7})],
                formAbility="己方回合开始时，获得 1 点鬼火并抽一张牌。",
                formHooks=[{"id": "form-dishi-mercy", "event": "turn-started", "effect": "passive-heal-draw-avatar-on-own-card", "params": {"amount": 1, "draw": 1}, "priority": 40}],
                tags=["形态", "莲华"]),
    22508: dict(name="圣子", type="form", level=2, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +4/+6。使用法术时复制简化为回合开始对敌方前线造成 3 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                formAbility="己方回合开始时，投射：造成 3 点伤害。",
                formHooks=[{"id": "form-dishi-son", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "莲华", "终结"]),

    # ---- 蟹姬 210 ----
    21001: dict(name="睡觉觉", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="抽两张牌（复制洗库简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                tags=["过牌", "横行"]),
    21002: dict(name="夹住你咯", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2，并获得 1 点护甲（同名叠强简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "shield", "source", 1)],
                tags=["出击", "横行"]),
    21003: dict(name="吃饱饱", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。抽一张牌（同名多抽简化）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "过牌", "横行"]),
    21004: dict(name="这下有劲了", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+6（帷幕叠层简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6})],
                tags=["形态", "横行"]),
    21005: dict(name="螺螺锤", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个敌方角色造成 4 点伤害（同名追伤简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["伤害", "横行"]),
    21006: dict(name="梦里啥都有", type="realm", level=2, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 8）：己方回合开始时，抽一张牌（手牌复制简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
                tags=["幻境", "过牌", "横行"]),
    21007: dict(name="觉醒·蟹姬", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+2/+2。抽一张牌（同名瞬发简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2}), ("always", "draw", "ally-player", 1)],
                tags=["觉醒", "横行"]),
    21008: dict(name="少主救救我", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +4/+8。回合开始蟹姬获得 +1/+1（弹回反击简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="己方回合开始时，蟹姬获得 +1/+1。",
                formHooks=[{"id": "form-xieji-lord", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "横行"]),

    # ---- 玉藻前 221 ----
    22101: dict(name="灵击", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个敌方式神造成 2 点伤害（法伤叠层简化）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2)],
                tags=["伤害", "狐火"]),
    22102: dict(name="狐火", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="投射：造成 3 点伤害。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 3)],
                keywords=["PROJECTILE"], tags=["投射", "狐火"]),
    22103: dict(name="堕天", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对所有敌方式神造成 1 点伤害（随机分配 4 点简化）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 1)],
                tags=["伤害", "清场", "狐火"]),
    22104: dict(name="祈念", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+4。回合开始抽一张牌（化身用牌简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 4})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-yuzao-pray", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "狐火"]),
    22105: dict(name="幽梦", type="realm", level=2, cost=1, rarity="SR", starter=1,
                text="幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害（气绝用牌简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
                tags=["幻境", "狐火"]),
    22106: dict(name="燃雪", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，远程，并抽一张牌（用 1 级法术简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
                keywords=["REMOTE"], tags=["出击", "远程", "狐火"]),
    22107: dict(name="觉醒·玉藻前", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。投射：造成 3 点伤害（手外用牌投射升级简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "damage-enemy-front", "auto", 3)],
                tags=["觉醒", "投射", "狐火"]),
    22108: dict(name="九尾煌炎", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +3/+7。回合开始投射 3 点伤害（高频化身简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7})],
                formAbility="己方回合开始时，投射：造成 3 点伤害。",
                formHooks=[{"id": "form-yuzao-nine", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "投射", "狐火"]),

    # ---- 惠比寿 209 ----
    20901: dict(name="赐福", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="使所有己方式神获得 +1/+1（双方升级简化）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1})],
                tags=["强化", "福运"]),
    20902: dict(name="吉兆", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个式神获得 +1/+1，抽一张牌（增强叠层简化）。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 1, "hp": 1}), ("always", "draw", "ally-player", 1)],
                tags=["强化", "过牌", "福运"]),
    20903: dict(name="转祸为福", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。其他式神气绝时，惠比寿获得 +1/+1（升级复活简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                formAbility="其他式神气绝时，惠比寿获得 +1/+1。",
                formHooks=[{"id": "form-huibishou-bless", "event": "unit-knocked-out", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
                tags=["形态", "复活", "福运"]),
    20904: dict(name="福笹", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="使一个己方其他式神获得 +2 力量与 2 点护甲（临时升级简化）。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 2, "hp": 0}), ("always", "shield", "selected-ally", 2)],
                tags=["强化", "福运"]),
    20905: dict(name="觉醒·惠比寿", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：+1/+1。所有己方式神获得 +1 生命（升级赐福简化）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "buff-stats", "all-ally-units", {"attack": 0, "hp": 1})],
                tags=["觉醒", "福运"]),
    20906: dict(name="海之惠", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +3/+8。回合开始抽一张牌（升级检索简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-huibishou-sea", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "过牌", "福运"]),
    20907: dict(name="十日戎", type="realm", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="幻境（耐久 10）：己方回合开始时，所有己方式神获得 2 点护甲（3 级继续升级简化）。",
                target="auto", effects=[("always", "realm", "ally-player", None)],
                realm={"hp": 10, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
                tags=["幻境", "保护", "福运"]),
    20908: dict(name="遨游", type="spell", level=3, cost=1, rarity="R", starter=0, deck_limit=2,
                text="使所有己方式神获得 +2/+2（最低级升级简化）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 2})],
                tags=["强化", "福运"]),
}

TOKENS = [
    dict(id="xingyun-qianbi", unitId="tieshu", name="幸运钱币", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。投射：造成 1 点伤害，并获得 1 点鬼火。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 1), ("always", "energy-gain", "ally-player", 1)],
         token=True, keywords=["INSTANT", "PROJECTILE"], tags=["token", "幸运钱币"]),
    dict(id="julijialuo-wan", unitId="yingxueji", name="俱利伽罗丸", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。投射：造成 2 点伤害。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 2)],
         token=True, keywords=["INSTANT", "PROJECTILE"], tags=["token", "青岚"]),
    dict(id="jinyu", unitId="jinyuji", name="金鱼", type="spell", level=1, cost=0, rarity="common",
         text="使一个己方式神获得 +2/+2 与 2 点护甲。", target="ally-unit",
         effects=[("always", "buff-stats", "selected-ally", {"attack": 2, "hp": 2}), ("always", "shield", "selected-ally", 2)],
         token=True, tags=["token", "金鱼"]),
    dict(id="yuanjie", unitId="jieshen", name="缘结", type="spell", level=1, cost=0, rarity="common",
         text="抽一张牌，并获得 1 点护甲。", target="auto",
         effects=[("always", "draw", "ally-player", 1), ("always", "shield", "all-ally-units", 1)],
         token=True, tags=["token", "缘结"]),
]

EXTRA_TOKENS: list = []

# 被动映射：uid -> (passive, awakenedPassive)
PASSIVES = {
    "jieshen": (
        dict(id="jieshen-bind", name="缘结", text="己方回合结束时，将一张「缘结」置入手牌（牌库结缘简化）。",
             hooks=[dict(id="bind", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["yuanjie"], "count": 1})]),
        dict(id="jieshen-bind-awakened", name="神赐缘结", text="己方回合开始时，将一张「缘结」置入手牌并抽一张牌。",
             hooks=[
                 dict(id="bind-a", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["yuanjie"], "count": 1}),
                 dict(id="bind-a2", event="turn-started", effect="passive-draw-self", params={"amount": 1}),
             ]),
    ),
    "gitongwan": (
        dict(id="gitongwan-fury", name="嗜杀", text="完成交战后，鬼童丸获得 1 点力量。",
             hooks=[dict(id="fury", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="gitongwan-fury-awakened", name="修罗嗜杀", text="完成交战后，鬼童丸获得 2 点力量与 1 点生命。",
             hooks=[
                 dict(id="fury-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2, "hp": 1}),
             ]),
    ),
    "banruo": (
        dict(id="banruo-envy", name="嫉恨", text="完成交战后，对敌方牌手造成 1 点伤害（占卜触发简化）。",
             hooks=[dict(id="envy", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="banruo-envy-awakened", name="妒生千面", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="envy-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "tieshu": (
        dict(id="tieshu-coin", name="幸运钱币", text="己方回合开始时，铁鼠获得 1 点力量（升级给币简化）。",
             hooks=[dict(id="coin", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="tieshu-coin-awakened", name="天降横财", text="己方回合开始时，铁鼠获得 1 点力量，并将一张「幸运钱币」置入手牌。",
             hooks=[
                 dict(id="coin-a", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
                 dict(id="coin-a2", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["xingyun-qianbi"], "count": 1}),
             ]),
    ),
    "hetong": (
        dict(id="hetong-fortune", name="川流占卜", text="己方回合开始时，抽一张牌（运势占卜简化）。",
             hooks=[dict(id="stream", event="turn-started", effect="passive-draw-self", params={"amount": 1})]),
        dict(id="hetong-fortune-awakened", name="川沼回响", text="己方回合开始时，抽一张牌并获得 1 点护甲。",
             hooks=[
                 dict(id="stream-a", event="turn-started", effect="passive-draw-self", params={"amount": 1}),
                 dict(id="stream-a2", event="turn-started", effect="passive-shield-self", params={"amount": 1}),
             ]),
    ),
    "zhuiyueshen": (
        dict(id="zhuiyueshen-moon", name="宵月", text="当你抽到牌时简化：己方回合开始时，追月神获得 1 点力量。",
             hooks=[dict(id="moon", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="zhuiyueshen-moon-awakened", name="神无月", text="己方回合开始时，追月神获得 2 点力量。",
             hooks=[dict(id="moon-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "baimugui": (
        dict(id="baimugui-gaze", name="窥视", text="己方回合开始时，对敌方前线造成 1 点伤害（占卜投射简化）。",
             hooks=[dict(id="gaze", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="baimugui-gaze-awakened", name="百目窥视", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="gaze-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "wushizhiling": (
        dict(id="wushizhiling-ghost", name="幽魂形态", text="气绝相关简化：完成交战后，获得 1 点力量。",
             hooks=[dict(id="ghost", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="wushizhiling-ghost-awakened", name="不灭幽魂", text="完成交战后，获得 2 点力量。",
             hooks=[dict(id="ghost-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "guishiheibai": (
        dict(id="guishiheibai-swap", name="无常切换", text="己方回合开始时，获得 1 点能量（充能切换简化）。",
             hooks=[dict(id="swap", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="guishiheibai-swap-awakened", name="黑白无常", text="己方回合开始时，获得 1 点能量，鬼使获得 1 点力量。",
             hooks=[
                 dict(id="swap-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="swap-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "huoqumo": (
        dict(id="huoqumo-honglian", name="红莲之火", text="完成交战后，火取魔获得 1 点力量与 1 点生命。",
             hooks=[
                 dict(id="lotus", event="combat-resolved", effect="passive-buff-self", params={"attack": 1, "hp": 1}),
             ]),
        dict(id="huoqumo-honglian-awakened", name="红莲盛放", text="完成交战后，火取魔获得 2 点力量与 1 点生命。",
             hooks=[
                 dict(id="lotus-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2, "hp": 1}),
             ]),
    ),
    "yuanjiulanghu": (
        dict(id="yuanjiulanghu-ziyan", name="紫岩之愈", text="恢复生命时，源九郎狐获得 1 点生命（派系成长简化）。",
             hooks=[dict(id="ziyan", event="unit-healed", effect="passive-buff-self", params={"hp": 1})]),
        dict(id="yuanjiulanghu-ziyan-awakened", name="紫岩共鸣", text="恢复生命时，源九郎狐获得 1 点力量与 1 点生命。",
             hooks=[dict(id="ziyan-a", event="unit-healed", effect="passive-buff-self", params={"attack": 1, "hp": 1})]),
    ),
    "yingxueji": (
        dict(id="yingxueji-qinglan", name="青岚投射", text="使用法术牌后简化：完成交战后，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="qinglan", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="yingxueji-qinglan-awakened", name="青岚连击", text="完成交战后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="qinglan-a", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "jingliuliqian": (
        dict(id="jingliuliqian-cangye", name="苍叶之刃", text="完成交战后，净琉璃御前获得 1 点力量（派系共鸣简化）。",
             hooks=[dict(id="cangye", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="jingliuliqian-cangye-awakened", name="净琉璃", text="完成交战后，净琉璃御前获得 2 点力量。",
             hooks=[dict(id="cangye-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "egui": (
        dict(id="egui-full", name="饱腹", text="完成交战后，饿鬼恢复 2 点生命并获得 1 点护甲。",
             hooks=[
                 dict(id="full", event="combat-resolved", effect="passive-heal-self-if-front", params={"amount": 2}),
                 dict(id="full-s", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1}),
             ]),
        dict(id="egui-full-awakened", name="暴食饱腹", text="完成交战后，饿鬼恢复 3 点生命并获得 2 点护甲。",
             hooks=[
                 dict(id="full-a", event="combat-resolved", effect="passive-heal-self-if-front", params={"amount": 3}),
                 dict(id="full-a2", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 2}),
             ]),
    ),
    "duyanxiaoseng": (
        dict(id="duyanxiaoseng-counter", name="金刚反击", text="受到伤害时，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="counter", event="unit-damaged", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="duyanxiaoseng-counter-awakened", name="怒目反击", text="受到伤害时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="counter-a", event="unit-damaged", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "mianqiling": (
        dict(id="mianqiling-mask", name="千面", text="受到伤害时，获得 1 点护甲（派系减伤简化）。",
             hooks=[dict(id="mask", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="mianqiling-mask-awakened", name="轮回之面", text="受到伤害时，获得 2 点护甲并获得 1 点力量。",
             hooks=[
                 dict(id="mask-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="mask-a2", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 1}),
             ]),
    ),
    "jiumingmao": (
        dict(id="jiumingmao-nine", name="九命", text="气绝复归简化：完成交战后，获得 1 点力量。",
             hooks=[dict(id="nine", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="jiumingmao-nine-awakened", name="九命不灭", text="完成交战后，获得 2 点力量与 1 点护甲。",
             hooks=[
                 dict(id="nine-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="nine-a2", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1}),
             ]),
    ),
    "axiuluo": (
        dict(id="axiuluo-karma", name="业火", text="受到伤害时，阿修罗获得 1 点力量（自伤叠力简化）。",
             hooks=[dict(id="karma", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 1})]),
        dict(id="axiuluo-karma-awakened", name="无尽业火", text="受到伤害时，阿修罗获得 2 点力量。",
             hooks=[dict(id="karma-a", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 2})]),
    ),
    "bayiqidashe": (
        dict(id="bayiqidashe-snake", name="蛇魔", text="其他式神气绝时，八岐大蛇获得 2 点力量与 1 点生命。",
             hooks=[dict(id="snake", event="unit-knocked-out", effect="passive-buff-self", params={"attack": 2, "hp": 1})]),
        dict(id="bayiqidashe-snake-awakened", name="混沌蛇魔", text="其他式神气绝时，八岐大蛇获得 3 点力量与 2 点生命。",
             hooks=[dict(id="snake-a", event="unit-knocked-out", effect="passive-buff-self", params={"attack": 3, "hp": 2})]),
    ),
    "jinyuji": (
        dict(id="jinyuji-goldfish", name="金鱼", text="己方回合开始时，金鱼姬获得 1 点生命（结附金鱼简化）。",
             hooks=[dict(id="goldfish", event="turn-started", effect="passive-buff-self", params={"hp": 1})]),
        dict(id="jinyuji-goldfish-awakened", name="荒川金鱼", text="己方回合开始时，金鱼姬获得 1 点力量与 1 点生命。",
             hooks=[dict(id="goldfish-a", event="turn-started", effect="passive-buff-self", params={"attack": 1, "hp": 1})]),
    ),
    "huangkulou": (
        dict(id="huangkulou-bone", name="亡骨", text="其他式神气绝时，荒骷髅获得 2 点护甲。",
             hooks=[dict(id="bone", event="unit-knocked-out", effect="passive-shield-self", params={"amount": 2})]),
        dict(id="huangkulou-bone-awakened", name="不灭亡骨", text="其他式神气绝时，荒骷髅获得 3 点护甲与 1 点力量。",
             hooks=[
                 dict(id="bone-a", event="unit-knocked-out", effect="passive-shield-self", params={"amount": 3}),
                 dict(id="bone-a2", event="unit-knocked-out", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "gouchang": (
        dict(id="gouchang-armor", name="净甲", text="受到伤害时，获得 1 点护甲。",
             hooks=[dict(id="clean", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="gouchang-armor-awakened", name="净甲不屈", text="受到伤害时，获得 2 点护甲。",
             hooks=[dict(id="clean-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "dishitian": (
        dict(id="dishitian-lotus", name="莲华", text="完成交战后，对敌方前线造成 1 点伤害（莲华结附简化）。",
             hooks=[dict(id="lotus", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="dishitian-lotus-awakened", name="莲华圣洁", text="完成交战后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="lotus-a", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "xieji": (
        dict(id="xieji-crab", name="横行", text="己方回合开始时，蟹姬获得 1 点护甲（同名瞬发简化）。",
             hooks=[dict(id="crab", event="turn-started", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="xieji-crab-awakened", name="横行无忌", text="己方回合开始时，蟹姬获得 2 点护甲与 1 点力量。",
             hooks=[
                 dict(id="crab-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="crab-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "yuzaoqian": (
        dict(id="yuzaoqian-fox", name="狐火", text="使用法术相关简化：完成交战后，对敌方牌手造成 1 点伤害。",
             hooks=[dict(id="fox", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="yuzaoqian-fox-awakened", name="九尾狐火", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="fox-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "huibishou": (
        dict(id="huibishou-bless", name="福运", text="其他式神获得强化时简化：己方回合开始时，所有己方式神恢复 1 点生命。",
             hooks=[dict(id="bless", event="turn-started", effect="passive-heal-all-allies", params={"amount": 1})]),
        dict(id="huibishou-bless-awakened", name="十日戎福", text="己方回合开始时，所有己方式神恢复 2 点生命。",
             hooks=[dict(id="bless-a", event="turn-started", effect="passive-heal-all-allies", params={"amount": 2})]),
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
    lines.append(" * 吉运·四相·善恶（wave4，26 式神）内容 — 由 scripts/gen-wave4-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE4_PACK_ID = 'wave4';")
    lines.append("export const WAVE4_PACK_NAME = '吉运·四相·善恶';")
    lines.append("export const WAVE4_SUBPACKS = Object.freeze({ jiyun: '吉运缘结', sixiang: '四相琉璃', shanewu: '善恶无明' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE4_UNIT_DEFINITIONS = Object.freeze([")

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
        lines.append(f"    art: {js_str(f'assets/wave4/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave4/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave4')},")
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
    lines.append("function wave4Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave4',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE4_CARD_DEFINITIONS = Object.freeze([")

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
        lines.append(f"  wave4Card({official_id}, {js_str(unit_id)}, {{")
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
        lines.append(f"  wave4Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave4UnitIds() {")
    lines.append("  return WAVE4_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
