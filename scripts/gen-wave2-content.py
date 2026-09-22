#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave2.js（妖狐·怪谈·不夜之火 9 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave2.js"

# 与 assets/wave2/ 命名一致
UNITS = [
    ("yaohu", 134, "妖狐", "风弹", "运势 / 法术", "#b07ad4", "法术触发风弹，风刃攒手，狂风清场。"),
    ("tiaotiaomeimei", 146, "跳跳妹妹", "顽童", "召唤 / 连击", "#e86a8a", "召唤番茄协同出击，战斗牌连打。"),
    ("buzhinhuo", 167, "不知火", "不夜", "鼓舞 / 形态", "#e85d4c", "鼓舞叠力叠甲，形态接管节奏。"),
    ("xiaolunan", 163, "小鹿男", "森之子", "充能 / 成长", "#7ab87a", "充能叠甲，鹿角贯通爆发。"),
    ("yanyanluo", 164, "烟烟罗", "烟霞", "能量 / 投射", "#9a8ab0", "爆能X灌伤，分身烟雾压场。"),
    ("rihefang", 166, "日和坊", "晴阳", "治疗 / 充能", "#f0c050", "阳光续航，能量换治疗与过牌。"),
    ("lianyou", 133, "镰鼬", "三太郎", "能量 / 连击", "#d4a040", "三太郎斧戟棒连打，能量转力量。"),
    ("yatiangou", 139, "鸦天狗", "天狗", "移动 / 投射", "#5a7a9a", "位移触发投射，群鸦乱舞控场。"),
    ("lingyuyuqian", 180, "铃鹿御前", "海国", "破甲 / 连击", "#3a8a9a", "伤害叠破甲，义道双倍爆发。"),
]

RARITY = {"R": "R", "SR": "SR", "SSR": "SSR", None: "R", "": "R", "N": "R", "SKIN": "R"}
TYPE = {"战斗": "combat", "法术": "spell", "形态": "form", "式神": None, "结界": "realm", "觉醒": "awakening", "衍生": "spell", "协战": None}


def slug(text: str) -> str:
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "card"


# 手写映射：只收录可构筑的专属牌（跳过式神卡、SKIN 重复、空描述协战）
# 简化原则同经典包；officialText 保留原文。
CARD_MAP: dict[int, dict] = {
    # ---- 妖狐 134 ----
    13401: dict(name="风刃", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。投射：造成 2 点伤害。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 2)],
                keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射"]),
    13402: dict(name="聚气", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="瞬发。妖狐永久获得 1 点力量（基础能力伤害永久 +1 简化）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 1, "hp": 0})],
                keywords=["INSTANT"], tags=["瞬发", "成长"]),
    13403: dict(name="命运之人", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +2/+5。回合开始时，将一张「风刃」置入手牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 5})],
                formAbility="己方回合开始时，将一张「风刃」置入手牌。",
                formHooks=[{"id": "form-yaohu-fate", "event": "turn-started", "effect": "passive-token-to-hand", "params": {"tokens": ["fengren"], "count": 1}, "priority": 40}],
                tags=["形态", "补牌"]),
    13404: dict(name="无羁风弹", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对所有其他式神各造成 2 点伤害（随机重复简化为全体）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["清场"]),
    13405: dict(name="狂风刃卷", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="对所有敌方式神造成 2 点伤害，并对敌方牌手造成 2 点伤害。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2), ("match-active", "damage", "enemy-avatar", 2)],
                tags=["终结", "清场"]),
    13406: dict(name="觉醒·妖狐", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：使用法术或运势成功时，随机对一个敌方角色造成 2 点伤害（简化为 +1/+1 与法术风弹被动）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),
    13407: dict(name="叠风斩", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对一个式神造成 3 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)],
                tags=["伤害"]),
    13408: dict(name="爱意绵绵", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+8。手牌法术伤害 +1（简化并入面板）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                tags=["形态"]),

    # ---- 鸦天狗 139 ----
    13901: dict(name="追风", type="spell", level=1, cost=0, rarity="R", starter=2,
                text="瞬发。移动鸦天狗（简化为投射 1 伤），抽一张牌。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 1), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "移动", "过牌"]),
    13902: dict(name="正义之刺", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2。若己方战斗区有其他式神，使其先攻击一次（简化 +2）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    13903: dict(name="羽迹", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="眩晕一个式神并造成 2 点伤害，然后移动鸦天狗（简化投射 1 伤）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2), ("always", "freeze", "selected-enemy", 1), ("always", "damage-enemy-front", "auto", 1)],
                keywords=["STUN"], tags=["控制", "移动"]),
    13904: dict(name="群鸦乱舞", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+8。在战斗区时，回合结束对敌方全体 1 伤并自愈（简化：进场全体 1 伤）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8}), ("always", "damage", "all-enemy-units", 1), ("always", "heal", "source", 1)],
                formAbility="己方回合开始时，对敌方所有式神造成 1 点伤害，自身恢复 1 点生命。",
                formHooks=[{"id": "form-yatien-crows", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "压制"]),
    13905: dict(name="鸦羽疾走", type="spell", level=2, cost=0, rarity="R", starter=1,
                text="响应：被攻击时取消本次攻击（简化：获得不屈与 2 护甲）。",
                target="auto", effects=[("always", "grant-unyielding", "source", 1), ("always", "shield", "source", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "移动"]),
    13906: dict(name="正义必胜", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +2（每移动一次 +2 力量简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击", "增强"]),
    13907: dict(name="英雄无畏", type="spell", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="眩晕一个敌方式神 2 回合。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 2)],
                keywords=["STUN"], tags=["控制", "眩晕"]),
    13908: dict(name="觉醒·鸦天狗", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：远程。移动时发动远程攻击（简化为 +2/+0 与远程）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 0})],
                keywords=["REMOTE"], tags=["觉醒", "远程"]),

    # ---- 跳跳妹妹 146 ----
    14601: dict(name="坏人走开", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="贯通。出击。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["PIERCE"], tags=["出击", "贯通"]),
    14602: dict(name="去咬他！", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="召唤「番茄」并使其攻击（简化：造成 3 点伤害并送一张番茄）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "token-to-hand", "ally-player", {"tokens": ["fanqie"], "count": 1})],
                tags=["召唤", "番茄"]),
    14603: dict(name="坐下！", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="召唤「番茄」并使其永久 +1/+1（简化：跳跳妹妹 +1/+1 并送一张番茄）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 1, "hp": 1}), ("always", "token-to-hand", "ally-player", {"tokens": ["fanqie"], "count": 1})],
                tags=["召唤", "成长"]),
    14604: dict(name="生气了啦！", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +1，并额外先攻击一次。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["COMBO"], tags=["出击", "连击"]),
    14605: dict(name="别过来啊！", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="响应：被攻击时自动使用。召唤「番茄」并使其攻击（简化：对敌方前线 3 伤）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 3), ("always", "token-to-hand", "ally-player", {"tokens": ["fanqie"], "count": 1})],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "召唤"]),
    14606: dict(name="不玩了啦！", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="可以在气绝时使用，复活跳跳妹妹（简化：出击 +3 且获得不屈）。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("always", "grant-unyielding", "source", 1)],
                tags=["出击", "复活"]),
    14607: dict(name="出击！", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="召唤「番茄」并强化其能力（简化：跳跳妹妹 +2 力量并送一张番茄）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 2, "hp": 0}), ("always", "token-to-hand", "ally-player", {"tokens": ["fanqie"], "count": 1})],
                tags=["召唤", "成长"]),
    14608: dict(name="觉醒「跳跳妹妹」", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：跳跳妹妹变成「番茄」形态（简化为 +2/+2）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒"]),

    # ---- 小鹿男 163 ----
    16301: dict(name="祝福之愿", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+6。攻击或被攻击时，使其他充能式神获得 1 能量（简化：回合开始获得 1 能量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 6}), ("always", "energy-gain", "ally-player", 1)],
                formAbility="己方回合开始时，你获得 1 点能量（简化鬼火/能量收益）。",
                formHooks=[{"id": "form-lunan-bless", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "充能"]),
    16302: dict(name="森之佑", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="使一个己方式神获得 1 力量、1 生命和 1 护甲。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 1, "hp": 1}), ("always", "shield", "selected-ally", 1)],
                tags=["支援", "护甲"]),
    16303: dict(name="森之力", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="眩晕一个式神并造成 3 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "freeze", "selected-enemy", 1)],
                keywords=["STUN"], tags=["控制", "伤害"]),
    16304: dict(name="自强之愿", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。攻击或被攻击时消耗 1 能量获得 2 护甲（简化：进场 +2 护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "shield", "source", 2)],
                formAbility="己方回合开始时，若小鹿男在战斗区，获得 2 护甲。",
                formHooks=[{"id": "form-lunan-self", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "护甲"]),
    16305: dict(name="森之守", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="使你的一个式神获得帷幕（简化：获得 5 护甲）。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 5)],
                tags=["护甲"]),
    16306: dict(name="鹿角冲撞", type="combat", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="贯通、连击。出击 +4。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["PIERCE", "COMBO"], tags=["贯通", "连击", "爆发"]),
    16307: dict(name="生生不息", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+9。攻击或被攻击时投射 3 伤（简化：回合开始投射 3 伤）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 9}), ("always", "damage-enemy-front", "auto", 3)],
                formAbility="己方回合开始时，投射：造成 3 点伤害。",
                formHooks=[{"id": "form-lunan-life", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "投射"]),
    16308: dict(name="觉醒·小鹿男", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="复活小鹿男。觉醒：复活时获得 2 能量（简化为 +1/+2 与护甲）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 2}), ("always", "shield", "source", 2)],
                tags=["觉醒", "充能"]),

    # ---- 烟烟罗 164 ----
    16401: dict(name="顽皮鬼", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="对一个敌方式神造成 2 点伤害（爆能X额外伤简化并入卡面）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2)],
                tags=["伤害"]),
    16402: dict(name="烟雾缭绕", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +2/+4，并获得 2 护甲（分身简化为护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 4}), ("always", "shield", "source", 2)],
                tags=["形态", "分身"]),
    16403: dict(name="贪食鬼", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="对敌方战斗区式神造成 3 点伤害，你恢复 3 点生命。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 3), ("always", "heal-avatar", "ally-avatar", 3)],
                tags=["伤害", "回复"]),
    16404: dict(name="扑朔迷离", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="响应：被攻击时自动使用。在战斗区召唤分身（简化：获得 4 护甲）。",
                target="auto", effects=[("always", "shield", "source", 4)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "分身"]),
    16405: dict(name="烟雾升腾", type="spell", level=1, cost=0, rarity="R", starter=1,
                text="瞬发。获得 3 能量（简化为 2 点鬼火）。",
                target="auto", effects=[("always", "energy-gain", "ally-player", 2)],
                keywords=["INSTANT"], tags=["瞬发", "能量"]),
    16406: dict(name="觉醒·烟烟罗", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="获得 2 能量。觉醒：获得能量时翻倍（简化为 +1/+1 与额外能量）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "energy-gain", "ally-player", 2)],
                tags=["觉醒", "能量"]),
    16407: dict(name="无孔不入", type="form", level=3, cost=1, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +4/+6。进场和回合开始时召唤分身并复制法术（简化：进场投射 2 伤）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6}), ("always", "damage-enemy-front", "auto", 2)],
                formAbility="己方回合开始时，投射：造成 2 点伤害。",
                formHooks=[{"id": "form-yanyan-pervade", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "分身"]),
    16408: dict(name="暴躁鬼", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="投射：造成 3 点伤害。若击杀获得能量（简化：额外恢复 2 鬼火）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 3), ("always", "energy-gain", "ally-player", 2)],
                keywords=["PROJECTILE"], tags=["投射", "能量"]),

    # ---- 日和坊 166 ----
    16601: dict(name="沐浴阳光", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="为所有己方式神恢复 3 点生命，并各获得 1 能量（简化为玩家 +1 鬼火）。",
                target="auto", effects=[("always", "heal", "all-ally-units", 3), ("always", "energy-gain", "ally-player", 1)],
                tags=["治疗", "充能"]),
    16602: dict(name="阳炎", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对一个式神造成 1 点伤害并眩晕。响应：敌方升级时自动使用。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 1), ("always", "freeze", "selected-enemy", 1)],
                keywords=["RESPONSE", "STUN"], timing="response", responseTo=["damage"], tags=["响应", "眩晕"]),
    16603: dict(name="祈晴", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+7。回合结束消耗能量抽一张牌（简化：回合开始抽 1 张）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-rihe-clear", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "过牌"]),
    16604: dict(name="冬日暖阳", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="使所有己方式神获得 1 力量、1 生命与 2 能量（简化为 +1/+1 与玩家 +2 鬼火）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 1}), ("always", "energy-gain", "ally-player", 2)],
                tags=["团辅", "充能"]),
    16605: dict(name="滋养", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +2/+7。回合开始消耗能量获得 1 鬼火。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7}), ("always", "energy-gain", "ally-player", 1)],
                formAbility="己方回合开始时，你获得 1 点鬼火。",
                formHooks=[{"id": "form-rihe-nourish", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "鬼火"]),
    16606: dict(name="日出有曜", type="spell", level=2, cost=0, rarity="R", starter=1,
                text="瞬发。清除一个角色的护甲与破甲（简化：移除敌方前线护甲）。",
                target="auto", effects=[("always", "remove-shield", "auto", 99)],
                keywords=["INSTANT"], tags=["瞬发", "破甲"]),
    16607: dict(name="觉醒·日和坊", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="瞬发。觉醒：能量不足可消耗生命；消耗能量的效果不再消耗能量（简化为 +1/+3 与群体治疗）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 3}), ("always", "heal", "all-ally-units", 2)],
                keywords=["INSTANT"], tags=["觉醒"]),
    16608: dict(name="晴雨", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +3/+8。己方其他角色受伤时恢复 3 点；回合结束群体治疗。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8}), ("always", "heal", "all-ally-units", 3)],
                formAbility="己方回合开始时，为所有己方式神恢复 3 点生命。",
                formHooks=[{"id": "form-rihe-rain", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "治疗"]),

    # ---- 不知火 167 ----
    16701: dict(name="不夜之舞", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+5。出击加成在使用战斗牌时也生效（简化：回合开始鼓舞 +1 力量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 5}), ("always", "buff-stats", "source", {"attack": 1, "hp": 0})],
                formAbility="己方回合开始时，不知火获得 1 点力量。",
                formHooks=[{"id": "form-buye-dance", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "鼓舞"]),
    16702: dict(name="自由之歌", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="鼓舞：获得 +3 力量与 +3 护甲。",
                target="auto", effects=[],
                keywords=["ENCOURAGE"], tags=["鼓舞"], encourage={"attack": 3, "shield": 3}),
    16703: dict(name="真意之歌", type="spell", level=1, cost=0, rarity="R", starter=1,
                text="瞬发。重置出击次数（简化：获得 1 点鬼火）。",
                target="auto", effects=[("always", "energy-gain", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "节奏"]),
    16704: dict(name="初会之舞", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="远程。己方式神对牌手造成伤害时抽一张牌（简化：造成战斗伤害抽 1）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                keywords=["REMOTE"],
                formAbility="不知火完成交战后，抽一张牌。",
                formHooks=[{"id": "form-buye-first", "event": "combat-resolved", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "过牌"]),
    16705: dict(name="星火之歌", type="spell", level=3, cost=1, rarity="R", starter=2,
                text="召唤一个「烬染不夜」（简化：对所有敌方式神造成 2 点伤害）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["清场", "烬染"]),
    16706: dict(name="离殇之舞", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +4/+6。出击加成不会因出击而消耗（简化：进场 +2 力量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6}), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                tags=["形态", "鼓舞"]),
    16707: dict(name="惊鸿之舞", type="form", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="获得 +5/+7。每个回合开始时随机触发一个效果（简化：回合开始 +2 力量或 +2 护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 7}), ("always", "buff-stats", "source", {"attack": 2, "hp": 2})],
                formAbility="己方回合开始时，随机获得 2 点力量或 2 点护甲。",
                formHooks=[{"id": "form-buye-swan", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 2, "hp": 0}, "priority": 40}],
                tags=["形态", "随机"]),
    16708: dict(name="觉醒·不知火", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：回合开始鼓舞 +1 力量，鼓舞效果额外 +1 力量与 +1 护甲。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 1})],
                tags=["觉醒", "鼓舞"]),

    # ---- 镰鼬 133 ----
    13301: dict(name="三太郎之斧", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +2（爆能3：+3 力量简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击", "爆能"]),
    13302: dict(name="同心协力", type="spell", level=2, cost=0, rarity="R", starter=1,
                text="瞬发。获得 1 能量并抽一张牌。",
                target="auto", effects=[("always", "energy-gain", "ally-player", 1), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "过牌"]),
    13303: dict(name="人多势众", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+5。每有能量便获得力量（简化：回合开始 +1 力量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5})],
                formAbility="己方回合开始时，镰鼬获得 1 点力量。",
                formHooks=[{"id": "form-lianyou-crowd", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "成长"]),
    13304: dict(name="二太郎之戟", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2，并施加 2 破甲。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("target-alive", "apply-armor-break", "selected-enemy", 2)],
                tags=["出击", "破甲"]),
    13305: dict(name="声东击西", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="免疫本次战斗伤害。响应：被攻击时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"],
                combatOption={"immuneCombatDamage": True}, tags=["响应", "防御"]),
    13306: dict(name="同生共死", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+5 与不屈（致死免疫简化）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5}), ("always", "grant-unyielding", "source", 1)],
                tags=["形态", "不屈"]),
    13307: dict(name="觉醒·镰鼬", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：充能。对牌手造成伤害时获得能量；能量可代替出击（简化为 +2/+1）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 1})],
                tags=["觉醒"]),
    13308: dict(name="一太郎之棒", type="combat", level=3, cost=2, rarity="SR", starter=1,
                text="出击 +3，造成伤害后眩晕目标且本回合力量变为 0。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("target-alive", "freeze", "selected-enemy", 1), ("target-alive", "set-attack-zero-this-turn", "selected-enemy", 1)],
                keywords=["STUN"], tags=["出击", "眩晕"]),

    # ---- 铃鹿御前 180 ----
    18001: dict(name="白刃", type="combat", level=1, cost=0, rarity="R", starter=1,
                text="不消耗鬼火。出击 +1（增强瞬发简化）。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                tags=["免费", "出击"]),
    18002: dict(name="霸主", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+5。免疫有破甲敌人的伤害（简化：进场 3 护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5}), ("always", "shield", "source", 3)],
                tags=["形态", "防御"]),
    18003: dict(name="光影", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +2。若造成高额伤害则抽牌回血（简化：抽 1 张并恢复 2 点生命）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1), ("always", "heal", "source", 2)],
                tags=["出击", "续航"]),
    18004: dict(name="冥弓", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="造成 4 点伤害，随机分配给所有敌方式神（简化：全体式神各 1 伤）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 1)],
                tags=["群伤"]),
    18005: dict(name="觉醒·铃鹿御前", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="投射：造成 2 点伤害。觉醒：伤害时施加等量破甲。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "damage-enemy-front", "auto", 2), ("always", "apply-armor-break", "all-enemy-units", 1)],
                keywords=["PROJECTILE"], tags=["觉醒", "破甲"]),
    18006: dict(name="无往", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="对有破甲或战斗区敌人造成额外 2 点伤害（简化：出击 +2 并施加 1 破甲）。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("target-alive", "apply-armor-break", "selected-enemy", 1)],
                tags=["出击", "破甲"]),
    18007: dict(name="归乡", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+8。出击时投射 3 伤（简化：进场投射 3 伤）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8}), ("always", "damage-enemy-front", "auto", 3)],
                formAbility="己方回合开始时，投射：造成 3 点伤害。",
                formHooks=[{"id": "form-lingyu-home", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "投射"]),
    18008: dict(name="义道", type="combat", level=3, cost=2, rarity="SSR", starter=0, deck_limit=2,
                text="贯通、连击。对有破甲的式神造成双倍伤害（简化：出击 +4）。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["PIERCE", "COMBO"], tags=["贯通", "连击", "爆发"]),
}

TOKENS = [
    dict(id="fengren", unitId="yaohu", name="风刃", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。投射：造成 2 点伤害。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 2)], token=True, keywords=["INSTANT", "PROJECTILE"], tags=["token"]),
    dict(id="fanqie", unitId="tiaotiaomeimei", name="番茄", type="spell", level=1, cost=0, rarity="common",
         text="番茄扑击：对敌方战斗区造成 3 点伤害（召唤简化）。", target="auto",
         effects=[("always", "damage-enemy-front", "auto", 3)], token=True, tags=["token", "召唤"]),
    dict(id="jinran-buye", unitId="buzhinhuo", name="烬染不夜", type="spell", level=1, cost=0, rarity="common",
         text="烬染不夜：对所有敌方式神造成 2 点伤害（召唤简化）。", target="auto",
         effects=[("always", "damage", "all-enemy-units", 2)], token=True, tags=["token"]),
]

EXTRA_TOKENS: list = []

# 被动映射：role -> (passive, awakenedPassive)
PASSIVES = {
    134: (
        dict(id="yaohu-luck", name="风弹", text="使用法术牌时，对敌方前线造成 1 点伤害（运势4简化）。",
             hooks=[dict(id="wind-shot", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 1})]),
        dict(id="yaohu-luck-awakened", name="命运回响", text="使用法术牌时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="wind-shot-a", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 2})]),
    ),
    139: (
        dict(id="yatiangou-move", name="天狗风行", text="进入战斗区时，投射：造成 1 点伤害（移动简化）。",
             hooks=[dict(id="move-burn", event="unit-entered-front", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="yatiangou-move-awakened", name="英雄之翼", text="进入战斗区时，投射：造成 2 点伤害。",
             hooks=[dict(id="move-burn-a", event="unit-entered-front", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    146: (
        dict(id="tiaomei-fury", name="顽童怒火", text="完成交战后，获得 1 点力量（额外消耗简化为成长）。",
             hooks=[dict(id="fury", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="tiaomei-fury-awakened", name="番茄本相", text="完成交战后，获得 2 点力量。",
             hooks=[dict(id="fury-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    163: (
        dict(id="xiaolunan-charge", name="森之充能", text="受到伤害时，获得 1 点护甲。",
             hooks=[dict(id="wood-charge", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="xiaolunan-charge-awakened", name="生生充能", text="回合开始时获得 2 点护甲；受到伤害再获得 1 点。",
             hooks=[
                 dict(id="wood-charge-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="wood-charge-a2", event="unit-damaged", effect="passive-shield-self", params={"amount": 1}),
             ]),
    ),
    164: (
        dict(id="yanyan-smoke", name="烟霞", text="使用法术牌时，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="smoke", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 1})]),
        dict(id="yanyan-smoke-awakened", name="无孔烟霞", text="使用法术牌时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="smoke-a", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 2})]),
    ),
    166: (
        dict(id="rihe-sun", name="晴阳", text="恢复生命时，获得 1 点护甲（过量治疗转甲简化）。",
             hooks=[dict(id="sun", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 1})]),
        dict(id="rihe-sun-awakened", name="普照", text="己方回合开始时，为所有己方式神恢复 2 点生命。",
             hooks=[dict(id="sun-a", event="turn-started", effect="passive-heal-all-allies", params={"amount": 2})]),
    ),
    133: (
        dict(id="lianyou-trio", name="三太郎", text="完成交战后，对敌方牌手造成 1 点伤害（得能量简化）。",
             hooks=[dict(id="trio", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="lianyou-trio-awakened", name="合力", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="trio-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    180: (
        dict(id="lingyu-break", name="破甲之伤", text="造成战斗伤害时，使目标获得 1 点破甲。",
             hooks=[dict(id="break-hit", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="lingyu-break-awakened", name="海国霸主", text="造成战斗伤害时，使目标获得 2 点破甲。",
             hooks=[dict(id="break-hit-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
}
# 167 不知火在 UNITS 中，被动需齐全
PASSIVES[167] = (
    dict(id="buzhinhuo-encourage", name="鼓舞", text="己方回合开始时，不知火获得 1 点力量。",
         hooks=[dict(id="encourage", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
    dict(id="buzhinhuo-encourage-awakened", name="不夜华彩", text="己方回合开始时，其他己方式神获得 1 点力量，不知火获得 2 点力量。",
         hooks=[
             dict(id="encourage-a", event="turn-started", effect="passive-buff-self", params={"attack": 2}),
             dict(id="encourage-a2", event="turn-started", effect="passive-buff-other-allies", params={"attack": 1}),
         ]),
)


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
    by_unit: dict[int, list[tuple[int, dict]]] = {}
    for oid, meta in CARD_MAP.items():
        by_unit.setdefault(oid // 100, []).append((oid, meta))
    for role, items in by_unit.items():
        items_sorted = sorted(items, key=lambda kv: (-(kv[1].get("starter") or 0), kv[0]))
        total = sum((m.get("starter") or 0) for _, m in items_sorted)
        for oid, meta in items_sorted:
            if total <= 8:
                break
            cut = min(total - 8, meta.get("starter") or 0)
            meta["starter"] = (meta.get("starter") or 0) - cut
            total -= cut
        ssr_starters = [(oid, m) for oid, m in items_sorted if m.get("rarity") == "SSR" and (m.get("starter") or 0) > 0]
        if len(ssr_starters) > 1:
            for oid, meta in ssr_starters[1:]:
                cut = meta.get("starter") or 0
                meta["starter"] = 0
                total -= cut
            need = 8 - total
            for oid, meta in items_sorted:
                if need <= 0:
                    break
                if meta.get("rarity") == "SSR" or meta.get("type") == "awakening":
                    continue
                room = min(need, (meta.get("deck_limit") or 2) - (meta.get("starter") or 0))
                if room > 0:
                    meta["starter"] = (meta.get("starter") or 0) + room
                    need -= room
                    total += room
        if total < 8:
            for oid, meta in items_sorted:
                if total >= 8:
                    break
                if meta.get("type") == "awakening" or meta.get("rarity") == "SSR":
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
        # 去重：同 id 只保留第一条非 SKIN / 非空
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
    lines.append(" * 妖狐·怪谈·不夜之火（wave2，9 式神）内容 — 由 scripts/gen-wave2-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE2_PACK_ID = 'wave2';")
    lines.append("export const WAVE2_PACK_NAME = '妖狐·怪谈·不夜之火';")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE2_UNIT_DEFINITIONS = Object.freeze([")

    for uid, role, name, title, archetype, color, strategy in UNITS:
        shik = shiks[name]
        pw, lf = int(shik["power"]), int(shik["life"])
        pid, aid = PASSIVES[role]
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
        lines.append(f"    art: {js_str(f'assets/wave2/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave2/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave2')},")
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
    lines.append("function wave2Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave2',")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE2_CARD_DEFINITIONS = Object.freeze([")

    used_ids = set()
    for official_id, meta in sorted(CARD_MAP.items(), key=lambda kv: (kv[1].get("id") or f"c{kv[0]}", kv[0])):
        role = official_id // 100
        unit_id = next(u[0] for u in UNITS if u[1] == role)
        gid = meta.get("id") or f"c{official_id}"
        if gid in used_ids:
            continue
        used_ids.add(gid)
        src = by_id.get(official_id, {})
        meta = dict(meta)
        meta["id"] = gid
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
        effs = meta.get("effects") or []
        eff_s = ",\n".join(
            "      [%s, %s, %s, %s]" % (
                js_str(c), js_str(a), js_str(t),
                json.dumps(v, ensure_ascii=False) if v is not None else "null",
            ) for c, a, t, v in effs
        )
        if eff_s:
            body.append("effects: [\n" + eff_s + ",\n    ]")
        lines.append(f"  wave2Card({official_id}, {js_str(unit_id)}, {{")
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
        lines.append(f"  wave2Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave2UnitIds() {")
    lines.append("  return WAVE2_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
