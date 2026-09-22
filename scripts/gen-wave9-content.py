#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave9.js（龙渊·星缘·斗转·花札，27 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id、式神卡。龙珏 4 勾映射到 level≤3。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave9.js"

# (uid, role, name, title, archetype, color, strategy, subpack)
UNITS = [
    # 龙渊秘境 longyuan
    ("yatiangou-qiuye", 642, "鸦天狗·秋叶", "秋叶", "神通 / 投射", "#d0c090", "结附神通触发弱点，驭风投射收割。", "longyuan"),
    ("shuweng-zhixing", 643, "书翁·志行", "游记", "占卜 / 过牌", "#a0b8d0", "游记叠层占卜过牌，翰墨觉醒扩手。", "longyuan"),
    ("huojinshen", 644, "祸津神", "咒纱", "咒纱 / 爆发", "#c08090", "咒纱护身削伤，除咒后高攻必杀。", "longyuan"),
    ("sibing", 645, "四饼", "折敷", "折敷 / 料理", "#e0b070", "折敷本膳循环，猫又屋团辅反击。", "longyuan"),
    ("dayueling-yuxin", 646, "大岳丸·渝心", "勾玉", "勾玉 / 麓鸣", "#70a0c0", "八尺琼勾玉切换攻防，麓鸣连打。", "longyuan"),
    ("chili", 647, "螭璃", "蟠息", "弃牌 / 蓄力", "#60b0a0", "弃牌蓄蟠息，龙骧龙啖贯通爆发。", "longyuan"),
    # 星缘百策 xingyuan
    ("jieshen-suiyuan", 648, "缘结神·遂愿", "福缘", "商店 / 福缘", "#f0a0c0", "福缘叠赏金，缘祝缘结万物续航。", "xingyuan"),
    ("tieshu-haojia", 649, "铁鼠·豪贾", "豪贾", "商店 / 成本", "#d0a040", "成本控制连打，孤注豪赌终结。", "xingyuan"),
    ("yijin-qianxun", 650, "以津真天·千寻", "风引", "商店 / 倒计时", "#a0d0e0", "风的指引叠赏金，千羽金羽爆发。", "xingyuan"),
    ("baizangzhu-lixin", 651, "白藏主·砺心", "狐焰", "狐焰 / 反打", "#c0d0a0", "狐焰标记压制，狐烬烈焰清场。", "xingyuan"),
    ("guijinyang", 652, "鬼金羊", "预告", "偷取 / 直击", "#b0a0e0", "预告信偷属性，长星锁直击压制。", "xingyuan"),
    ("longche", 653, "胧车", "呱太", "召唤 / 成长", "#80c090", "受伤召呱太，呱太军团铺场成长。", "xingyuan"),
    # 斗转万象 douzhuan
    ("pinfashen", 657, "贫乏神", "不幸", "运势 / 不幸", "#908060", "不幸转移厄运，灾厄降临叠关键字。", "douzhuan"),
    ("longjue", 654, "龙珏", "乾坤", "龙息 / 投射", "#50a0c0", "乾坤龙息切换，逆鳞飞龙投射爆。", "douzhuan"),
    ("fengyangjun", 655, "封阳君", "易势", "流派 / 切换", "#e0c060", "霁雪晴空易势，封阳刀法连击。", "douzhuan"),
    ("jintianyuzaoqian", 660, "烬天玉藻前", "九尾", "九尾 / 专注", "#e06050", "九尾之力叠层，焚天九尾随机爆。", "douzhuan"),
    ("chanxinyunwaijing", 656, "禅心云外镜", "连引", "庇佑 / 连引", "#c0c8e0", "阴阳连引庇佑，水无垠团辅。", "douzhuan"),
    ("zhaocaimao", 659, "招财猫", "御守", "商店 / 赏金", "#f0c070", "御守叠赏金，洒金成雨投射终结。", "douzhuan"),
    ("maozhanggui-huanyan", 658, "猫掌柜·焕宴", "蓝图", "蓝图 / 幻境", "#e09080", "店面焕新蓝图，新生祭典复活团辅。", "douzhuan"),
    # 花札祈梦 huazha（含蜃气楼）
    ("geluoduo", 661, "歌留多", "花札", "花札 / 连锁", "#f0b0a0", "花札连锁随机效果，花月乱舞收割。", "huazha"),
    ("yinfanhuiyeji", 666, "因幡辉夜姬", "遗愿", "遗愿 / 祈愿", "#d0c0f0", "遗愿叠团辅，愿满夜月光流照。", "huazha"),
    ("daixiaoguhuoniao", 667, "待宵姑获鸟", "羽念", "充能 / 投射", "#80a0c0", "充能投射支援，金羽流焰终结。", "huazha"),
    ("chulingshanfeng", 662, "初翎山风", "入阵", "入阵 / 移动", "#70b080", "入阵叠战力，啸火贯通收割。", "huazha"),
    ("fenghuanghuo-jingyu", 665, "凤凰火·净羽", "火种", "火种 / 遗愿", "#f08050", "火种遗愿叠层，夜火流空非战伤。", "huazha"),
    ("xixueji-xiyi", 663, "吸血姬·曦忆", "曦忆", "入夜 / 吸血", "#c05070", "入夜自伤叠力，二重禁忌吸血。", "huazha"),
    ("yinghuayao-lijing", 664, "樱花妖·璃景", "琉璃樱", "召唤 / 遗愿", "#f0a0b0", "琉璃樱遗愿铺场，樱时雨战力收割。", "huazha"),
    ("shenqilou", 298, "蜃气楼", "百识", "百识 / 弃牌", "#90a0b0", "百识弃牌增强，胧月夜四派系。", "huazha"),
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
# starter 合计=8，觉醒恰好 1 张且 starter=1，非觉醒 SSR starter=0，cost 0-2，level≤3。
CARD_MAP: dict[int, dict] = {
    # ---- 鸦天狗·秋叶 642 ----
    64201: C("驭风", "spell", 1, 0, "R", 1,
             "瞬发。对一个敌方式神造成 3 点伤害，并使其 -1 力量（弱点简化）。",
             [("always", "damage", "selected-enemy", 3), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "投射", "神通"]),
    64202: C("火伏", "combat", 1, 1, "R", 1,
             "出击 +2，并获得贯通（火神通简化并入）。",
             [("source-ready", "assault", "source", 2)],
             keywords=["PIERCE"], tags=["出击", "贯通", "神通"]),
    64203: C("秋叶大权现", "form", 2, 1, "SR", 1,
             "获得 +2/+4。己方回合开始时，获得 2 点护甲（水神通简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，获得 2 点护甲。",
             formHooks=[{"id": "form-yatiangou-authority", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "神通", "护甲"]),
    64204: C("百战百胜", "awakening", 2, 1, "SSR", 1,
             "对所有敌方式神造成 2 点伤害。觉醒：+2/+2，回合开始投射 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=1, tags=["觉醒", "神通", "投射"]),
    64205: C("正义授剑", "spell", 2, 1, "SR", 1,
             "使一个己方其他式神获得 +2/+2。",
             [("always", "buff-stats", "selected-ally", F(2, 2))],
             tags=["强化", "团辅", "神通"]),
    64206: C("英雄誓愿", "combat", 1, 1, "R", 1,
             "出击 +3。攻击后，对敌方前线造成 1 点伤害（白狐简化）。",
             [("source-ready", "assault", "source", 3), ("always", "damage-enemy-front", "auto", 1)],
             tags=["出击", "投射", "召唤"]),
    64207: C("鸦翎", "combat", 3, 1, "R", 2,
             "出击 +3，并获得 2 点护甲与迅捷。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
             keywords=["INSTANT"], tags=["出击", "迅捷", "护甲"]),
    64208: C("修验", "spell", 3, 2, "SR", 0,
             "对一个敌方式神造成 5 点伤害，并抽一张牌。",
             [("always", "damage", "selected-enemy", 5), ("always", "draw", "ally-player", 1)],
             tags=["伤害", "过牌", "神通"]),

    # ---- 书翁·志行 643 ----
    64301: C("遐征", "spell", 1, 1, "R", 1,
             "抽一张牌，并使一个己方式神获得 +1/+1（游记简化）。",
             [("always", "draw", "ally-player", 1), ("always", "buff-stats", "selected-ally", F(1, 1))],
             tags=["过牌", "游记", "强化"]),
    64302: C("札记·蜃", "spell", 1, 0, "R", 1,
             "瞬发。占卜 2，并抽一张牌。",
             [("always", "divination", "ally-player", 2), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "占卜", "过牌"]),
    64303: C("志行无量书", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "过牌", "游记"]),
    64304: C("提笔", "spell", 2, 1, "SR", 1,
             "抽两张牌，并为你恢复 3 点生命。",
             [("always", "draw", "ally-player", 2), ("always", "heal-avatar", "ally-avatar", 3)],
             tags=["过牌", "治疗", "游记"]),
    64305: C("夙雾盘岭", "realm", 2, 1, "R", 1,
             "幻境（耐久 4）：己方回合开始时，敌方所有式神 -1 力量。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "压制", "游记"]),
    64306: C("翰墨逸香", "awakening", 2, 1, "SR", 1,
             "抽两张牌。觉醒：+1/+3，回合开始占卜 1。",
             [("always", "awaken", "source", F(1, 3)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "游记", "过牌"]),
    64307: C("观书", "spell", 3, 1, "R", 1,
             "所有己方式神获得 +1/+1。",
             [("always", "buff-stats", "all-ally-units", F(1, 1))],
             tags=["团辅", "强化", "游记"]),
    64308: C("碧海苍梧", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，抽一张牌并为所有己方式神恢复 1 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "过牌", "终结"]),

    # ---- 祸津神 644 ----
    64401: C("远古灾厄之宴", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，所有己方式神获得 1 点护甲（咒纱转移简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "咒纱", "护甲"]),
    64402: C("祸咒", "combat", 1, 1, "R", 1,
             "出击 +2，并获得不屈（必杀简化并入战力）。",
             [("source-ready", "assault", "source", 2), ("always", "grant-unyielding", "source", 1)],
             keywords=["UNYIELDING"], tags=["出击", "不屈", "咒纱"]),
    64403: C("无瑕之花", "form", 1, 1, "R", 1,
             "获得 +3/+3，并获得贯通。",
             [("always", "form", "source", F(3, 3))],
             keywords=["PIERCE"], tags=["形态", "咒纱", "贯通"]),
    64404: C("藤原绫子", "form", 2, 1, "SR", 1,
             "获得 +3/+5。敌方使用牌后，对其牌手造成 1 点伤害（灵咒简化）。",
             [("always", "form", "source", F(3, 5))],
             formAbility="己方回合开始时，对敌方牌手造成 1 点伤害。",
             formHooks=[{"id": "form-huojin-fujiwara", "event": "turn-started", "effect": "passive-damage-enemy-front", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "咒纱", "压制"]),
    64405: C("低语", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 5 点伤害（咒纱削伤简化并入固定值）。",
             [("always", "damage", "selected-enemy", 5)],
             tags=["伤害", "咒纱"]),
    64406: C("鲜花盛开之地", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：进场复活一个己方式神，回合开始恢复你 2 点生命。",
             [("always", "revive", "knocked-ally", 1), ("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "复活", "治疗"]),
    64407: C("祷言", "spell", 3, 1, "SR", 1,
             "所有己方其他式神获得 +1/+1，并抽两张牌（转移攻击简化）。",
             [("always", "buff-stats", "all-other-allies", F(1, 1)), ("always", "draw", "ally-player", 2)],
             tags=["团辅", "咒纱", "过牌"]),
    64408: C("觉醒·祸津神", "awakening", 3, 1, "SSR", 1,
             "获得 4 点护甲。觉醒：+2/+3，受伤后获得 2 点护甲。",
             [("always", "awaken", "source", F(2, 3)), ("always", "shield", "source", 4)],
             deck_limit=1, tags=["觉醒", "咒纱", "护甲"]),

    # ---- 四饼 645 ----
    64501: C("接物之道", "spell", 1, 0, "R", 1,
             "瞬发。投射：造成 1 点伤害，并使四饼获得 +1/+0（折敷简化）。",
             [("always", "damage-enemy-front", "auto", 1), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射", "折敷"]),
    64502: C("旨味匠人", "form", 1, 1, "SSR", 0,
             "获得 +3/+4。己方回合开始时，随机对一个敌方造成 1 点伤害。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-sibing-chef", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "折敷", "料理"]),
    64503: C("忙碌猫又屋", "realm", 1, 1, "SR", 1,
             "幻境（耐久 4）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "折敷", "反击"]),
    64504: C("器用之美", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害，并为四饼恢复 2 点生命。",
             [("always", "damage", "selected-enemy", 4), ("always", "heal", "source", 2)],
             tags=["伤害", "治疗", "折敷"]),
    64505: C("觉醒·四饼", "awakening", 2, 1, "SR", 1,
             "出击 +1，并获得 1 点护甲。觉醒：+2/+2，回合开始获得 1 点护甲。",
             [("always", "awaken", "source", F(2, 2)), ("source-ready", "assault", "source", 1), ("always", "shield", "source", 1)],
             deck_limit=1, tags=["觉醒", "折敷", "护甲"]),
    64506: C("猫执事", "form", 2, 1, "R", 1,
             "获得 +3/+5。己方回合开始时，对所有敌方式神造成 1 点伤害。",
             [("always", "form", "source", F(3, 5))],
             formAbility="己方回合开始时，对敌方前线造成 1 点伤害。",
             formHooks=[{"id": "form-sibing-butler", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "折敷", "群伤"]),
    64507: C("精打细算", "combat", 3, 1, "R", 1,
             "出击 +3，并获得先攻。",
             [("source-ready", "assault", "source", 3)],
             keywords=["FIRST_STRIKE"], tags=["出击", "先攻", "折敷"]),
    64508: C("悠哉莲之间", "realm", 3, 2, "SR", 0,
             "幻境（耐久 6）：己方回合开始时，所有己方式神获得 1 点生命与 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "团辅", "折敷"]),

    # ---- 大岳丸·渝心 646 ----
    64601: C("铃鹿山之阵", "spell", 1, 1, "R", 1,
             "使一个己方式神获得 +1/+1，并使一个敌方式神 -1 力量。",
             [("always", "buff-stats", "selected-ally", F(1, 1)), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             tags=["勾玉", "强化", "压制"]),
    64602: C("挪移之术", "spell", 1, 0, "R", 1,
             "瞬发。对一个敌方式神造成 3 点伤害，并使其 -1 力量。",
             [("always", "damage", "selected-enemy", 3), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "勾玉", "伤害"]),
    64603: C("麓鸣·湮", "combat", 1, 1, "SR", 1,
             "出击 +3，并获得必杀（暴击简化）。",
             [("source-ready", "assault", "source", 3)],
             keywords=["CRIT"], tags=["出击", "必杀", "勾玉"]),
    64604: C("海国之愿", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "勾玉", "伤害"]),
    64605: C("铃鹿山少主", "form", 2, 1, "SR", 1,
             "获得 +3/+5，并获得 2 点护甲。",
             [("always", "form", "source", F(3, 5)), ("always", "shield", "source", 2)],
             tags=["形态", "勾玉", "护甲"]),
    64606: C("三明六通", "awakening", 2, 1, "SSR", 1,
             "随机对一个敌方造成 3 点伤害。觉醒：+2/+2，回合开始随机对敌方造成 1 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "selected-enemy", 3)],
             deck_limit=1, tags=["觉醒", "勾玉", "投射"]),
    64607: C("鬼神魔王", "form", 3, 2, "R", 0,
             "获得 +4/+5。己方回合开始时，眩晕敌方前线并造成 1 点伤害。",
             [("always", "form", "source", F(4, 5)), ("always", "freeze", "all-enemy-units", 1)],
             keywords=["STUN"],
             formAbility="己方回合开始时，对敌方前线造成 1 点伤害。",
             formHooks=[{"id": "form-dayue-demon", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "勾玉", "眩晕"]),
    64608: C("麓鸣·令", "combat", 3, 1, "SR", 0,
             "出击 +5，并获得 1 点护甲（免疫战伤简化）。",
             [("source-ready", "assault", "source", 5), ("always", "shield", "source", 1)],
             tags=["出击", "勾玉", "终结"]),

    # ---- 螭璃 647 ----
    64701: C("螭啸", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害，并使其 -1 力量。",
             [("always", "damage", "selected-enemy", 4), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             tags=["伤害", "弃牌", "蟠息"]),
    64702: C("岱舆仙瑶", "realm", 1, 1, "R", 1,
             "幻境（耐久 4）：己方回合开始时，所有己方式神获得 1 点护甲（弃牌反哺简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "蟠息", "护甲"]),
    64703: C("龙骧", "spell", 1, 1, "SR", 1,
             "对敌方前线造成等同于 4 点的伤害（力量投射简化）。",
             [("always", "damage-enemy-front", "auto", 4)],
             keywords=["PROJECTILE"], tags=["投射", "蟠息", "伤害"]),
    64704: C("袖里乾坤", "form", 2, 1, "R", 1,
             "获得 +3/+4，并获得迅捷。",
             [("always", "form", "source", F(3, 4))],
             keywords=["INSTANT"], tags=["形态", "弃牌", "迅捷"]),
    64705: C("龙啖", "spell", 2, 1, "R", 1,
             "贯通。对一个敌方式神造成 6 点伤害。",
             [("always", "damage", "selected-enemy", 6)],
             keywords=["PIERCE"], tags=["伤害", "贯通", "蟠息"]),
    64706: C("觉醒·螭璃", "awakening", 2, 1, "SR", 1,
             "抽一张牌。觉醒：+2/+2，回合开始抽一张牌。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "蟠息", "过牌"]),
    64707: C("龙宫秘宝", "spell", 3, 1, "SSR", 0,
             "抽两张牌，并使自身获得 +2/+2（秘宝简化）。",
             [("always", "draw", "ally-player", 2), ("always", "buff-stats", "source", F(2, 2))],
             deck_limit=2, tags=["过牌", "强化", "终结"]),
    64708: C("归墟", "spell", 3, 2, "SR", 0,
             "对所有敌方式神造成 3 点伤害，并抽两张牌。",
             [("always", "damage", "all-enemy-units", 3), ("always", "draw", "ally-player", 2)],
             tags=["群伤", "过牌", "蟠息"]),

    # ---- 缘结神·遂愿 648 ----
    64801: C("缘之书", "form", 1, 1, "R", 1,
             "获得 +1/+4。己方回合开始时，为你恢复 2 点生命并抽一张牌。",
             [("always", "form", "source", F(1, 4))],
             formAbility="己方回合开始时，为你恢复 1 点生命。",
             formHooks=[{"id": "form-jieshen-book", "event": "turn-started", "effect": "passive-heal-ally-if-front-or-any", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "福缘", "治疗"]),
    64802: C("姻缘线", "spell", 1, 0, "R", 1,
             "瞬发。抽一张牌，并使一个己方式神获得 +1/+1。",
             [("always", "draw", "ally-player", 1), ("always", "buff-stats", "selected-ally", F(1, 1))],
             keywords=["INSTANT"], tags=["瞬发", "福缘", "过牌"]),
    64803: C("缘定三生", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌（赏金简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "福缘", "过牌"]),
    64804: C("天降良缘", "awakening", 2, 1, "SR", 1,
             "抽一张牌。觉醒：+1/+3，回合开始随机对敌方造成 1 点伤害。",
             [("always", "awaken", "source", F(1, 3)), ("always", "draw", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "福缘", "过牌"]),
    64805: C("缘祝", "form", 2, 1, "SR", 1,
             "获得 +2/+4。己方回合开始时，为所有己方式神恢复 1 点生命。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
             formHooks=[{"id": "form-jieshen-bless", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "福缘", "治疗"]),
    64806: C("缘结神社", "spell", 2, 1, "R", 1,
             "使一个己方式神获得 +3/+3。",
             [("always", "buff-stats", "selected-ally", F(3, 3))],
             tags=["强化", "福缘", "团辅"]),
    64807: C("缘结万物", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 7）：己方回合开始时，所有己方式神 +1/+1。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 7, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "强化", "终结"]),
    64808: C("愿望委托", "spell", 3, 1, "R", 0,
             "复活一个己方式神，并使其获得 +2/+2。",
             [("always", "revive", "knocked-ally", 1), ("always", "buff-stats", "selected-ally", F(2, 2))],
             tags=["复活", "强化", "福缘"]),

    # ---- 铁鼠·豪贾 649 ----
    64901: C("钱即正义", "combat", 1, 1, "R", 1,
             "出击 +2。若本回合使用过商店牌（简化常驻），获得直击。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 2)],
             tags=["出击", "直击", "成本"]),
    64902: C("赌局", "form", 1, 1, "SR", 1,
             "获得 +3/+4。完成交战后，随机对一个敌方造成 1 点伤害。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-tieshu-gamble", "event": "combat-resolved", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "运势", "成本"]),
    64903: C("商亦有道", "combat", 1, 1, "R", 1,
             "出击 +3（商店叠力简化并入）。",
             [("source-ready", "assault", "source", 3)],
             tags=["出击", "成本", "商店"]),
    64904: C("秘宝云集", "combat", 2, 1, "R", 1,
             "出击 +2，抽两张牌，并获得 1 点护甲。",
             [("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 2), ("always", "shield", "source", 1)],
             tags=["出击", "过牌", "护甲"]),
    64905: C("孤注一掷", "awakening", 2, 1, "SR", 1,
             "对敌方前线造成 3 点伤害。觉醒：+2/+1，完成交战后对敌方牌手造成 1 点伤害。",
             [("always", "awaken", "source", F(2, 1)), ("always", "damage-enemy-front", "auto", 3)],
             deck_limit=1, tags=["觉醒", "成本", "投射"]),
    64906: C("万宝槌", "spell", 2, 1, "SSR", 0,
             "为你恢复 5 点生命，并抽两张牌。",
             [("always", "heal-avatar", "ally-avatar", 5), ("always", "draw", "ally-player", 2)],
             deck_limit=2, tags=["治疗", "过牌", "商店"]),
    64907: C("收买", "realm", 3, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "成本", "过牌"]),
    64908: C("豪赌", "spell", 3, 2, "SR", 0,
             "随机对两个敌方角色各造成 3 点伤害（重复投射简化）。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "damage", "enemy-avatar", 3)],
             tags=["伤害", "投射", "终结"]),

    # ---- 以津真天·千寻 650 ----
    65001: C("迁徙", "combat", 1, 1, "SR", 1,
             "出击 +2，并获得穿刺（贯通简化）。",
             [("source-ready", "assault", "source", 2)],
             keywords=["PIERCE"], tags=["出击", "贯通", "风引"]),
    65002: C("虚妄的价值", "spell", 1, 0, "R", 1,
             "瞬发。抽一张牌，并为你恢复 2 点生命。",
             [("always", "draw", "ally-player", 1), ("always", "heal-avatar", "ally-avatar", 2)],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "风引"]),
    65003: C("风的祝福", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌（倒计时简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "倒计时", "风引"]),
    65004: C("血羽", "combat", 1, 1, "R", 1,
             "出击 +3。",
             [("source-ready", "assault", "source", 3)],
             tags=["出击", "风引", "伤害"]),
    65005: C("终舞", "awakening", 2, 1, "SR", 1,
             "对一个敌方式神造成 3 点伤害。觉醒：+2/+2，回合开始抽一张牌。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "selected-enemy", 3)],
             deck_limit=1, tags=["觉醒", "风引", "过牌"]),
    65006: C("仇羽之刃", "form", 2, 1, "SR", 1,
             "获得 +3/+4，并获得迅捷与追猎（护甲简化）。",
             [("always", "form", "source", F(3, 4)), ("always", "shield", "source", 2)],
             keywords=["INSTANT"], tags=["形态", "迅捷", "风引"]),
    65007: C("金羽流光", "form", 3, 2, "SSR", 0,
             "获得 +4/+5。己方回合开始时，对敌方前线造成 3 点伤害。",
             [("always", "form", "source", F(4, 5))],
             formAbility="己方回合开始时，对敌方前线造成 3 点伤害。",
             formHooks=[{"id": "form-yijin-gold", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
             deck_limit=2, tags=["形态", "投射", "终结"]),
    65008: C("千羽庇佑", "combat", 3, 1, "R", 0,
             "出击 +4，并获得 2 点护甲。",
             [("source-ready", "assault", "source", 4), ("always", "shield", "source", 2)],
             tags=["出击", "护甲", "风引"]),

    # ---- 白藏主·砺心 651 ----
    65101: C("守护之道", "spell", 1, 0, "R", 1,
             "瞬发。对一个敌方式神造成 1 点伤害（狐焰简化），并抽一张牌。",
             [("always", "damage", "selected-enemy", 1), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "狐焰", "过牌"]),
    65102: C("狐诱之计", "form", 1, 1, "R", 1,
             "获得 +2/+4。己方回合开始时，对敌方前线造成 1 点伤害。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，对敌方前线造成 1 点伤害。",
             formHooks=[{"id": "form-baizang-lure", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "狐焰", "投射"]),
    65103: C("蜃楼狐影", "realm", 1, 1, "SR", 1,
             "幻境（耐久 4）：己方回合开始时，对敌方前线造成 1 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "狐焰", "投射"]),
    65104: C("处世之道", "spell", 2, 1, "SR", 1,
             "使一个敌方式神 -2 力量，并眩晕之（反制简化）。",
             [("always", "debuff-stats", "selected-enemy", F(2, 0)), ("always", "freeze", "selected-enemy", 1)],
             keywords=["STUN"], tags=["眩晕", "狐焰", "压制"]),
    65105: C("狐心双焰", "awakening", 2, 1, "SSR", 1,
             "对两个敌方式神各造成 2 点伤害。觉醒：+2/+2，回合开始对敌方前线造成 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 2)],
             deck_limit=1, tags=["觉醒", "狐焰", "投射"]),
    65106: C("狐啸", "form", 2, 1, "R", 1,
             "获得 +3/+5，并获得迅捷。",
             [("always", "form", "source", F(3, 5))],
             keywords=["INSTANT"], tags=["形态", "狐焰", "迅捷"]),
    65107: C("攻为守策", "form", 3, 1, "SR", 1,
             "获得 +3/+4。完成交战后，获得 2 点护甲。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，获得 2 点护甲。",
             formHooks=[{"id": "form-baizang-guard", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "狐焰", "护甲"]),
    65108: C("狐烬烈焰", "spell", 3, 2, "R", 0,
             "对所有敌方式神造成 3 点伤害。",
             [("always", "damage", "all-enemy-units", 3)],
             tags=["群伤", "狐焰", "终结"]),

    # ---- 鬼金羊 652 ----
    65201: C("侠盗", "combat", 1, 1, "R", 1,
             "出击 +2，并使目标 -1 力量（偷取简化）。",
             [("source-ready", "assault", "source", 2), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             tags=["出击", "偷取", "预告"]),
    65202: C("奇袭", "combat", 1, 1, "R", 1,
             "出击 +3。",
             [("source-ready", "assault", "source", 3)],
             tags=["出击", "偷取", "预告"]),
    65203: C("鬼星之主", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方牌手造成 1 点伤害（直击偷血简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "直击", "偷取"]),
    65204: C("无踪", "form", 2, 1, "R", 1,
             "获得 +2/+5，并获得迅捷。",
             [("always", "form", "source", F(2, 5))],
             keywords=["INSTANT"], tags=["形态", "迅捷", "预告"]),
    65205: C("觉醒·鬼金羊", "awakening", 2, 1, "SR", 1,
             "使一个敌方式神 -2 力量。觉醒：+2/+2，回合开始对敌方前线造成 1 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("always", "debuff-stats", "selected-enemy", F(2, 0))],
             deck_limit=1, tags=["觉醒", "偷取", "预告"]),
    65206: C("宿影暗度", "spell", 2, 1, "R", 1,
             "瞬发。抽一张牌，并获得 2 点护甲。",
             [("always", "draw", "ally-player", 1), ("always", "shield", "source", 2)],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "预告"]),
    65207: C("长星锁", "form", 3, 1, "SR", 1,
             "获得 +3/+5。完成交战后，对敌方牌手造成 2 点伤害。",
             [("always", "form", "source", F(3, 5))],
             formAbility="完成交战后，对敌方牌手造成 2 点伤害。",
             formHooks=[{"id": "form-guijin-lock", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "直击", "偷取"]),
    65208: C("鬼宿奇惊", "combat", 3, 2, "SSR", 0,
             "出击 +4，获得贯通与 2 点护甲。",
             [("source-ready", "assault", "source", 4), ("always", "shield", "source", 2)],
             keywords=["PIERCE"], deck_limit=2, tags=["出击", "贯通", "终结"]),

    # ---- 胧车 653 ----
    65301: C("群呱乱舞", "spell", 1, 1, "R", 1,
             "投射：造成 4 点伤害，并对自身造成 2 点伤害。",
             [("always", "damage-enemy-front", "auto", 4), ("always", "damage-self", "source", 2)],
             keywords=["PROJECTILE"], tags=["投射", "召唤", "自伤"]),
    65302: C("鼓舞呱心", "spell", 1, 1, "R", 1,
             "所有己方式神获得 +1/+1。",
             [("always", "buff-stats", "all-ally-units", F(1, 1))],
             tags=["团辅", "召唤", "成长"]),
    65303: C("呱海战术", "combat", 1, 1, "SR", 1,
             "出击 +2，并获得贯通。",
             [("source-ready", "assault", "source", 2)],
             keywords=["PIERCE"], tags=["出击", "贯通", "召唤"]),
    65304: C("保养时间", "awakening", 2, 1, "SR", 1,
             "为你和胧车恢复 3 点生命。觉醒：+1/+4，回合开始恢复 2 点生命。",
             [("always", "awaken", "source", F(1, 4)), ("always", "heal", "source", 3), ("always", "heal-avatar", "ally-avatar", 3)],
             deck_limit=1, tags=["觉醒", "治疗", "召唤"]),
    65305: C("呱太变身", "spell", 2, 1, "R", 1,
             "眩晕一个敌方式神，并对其造成 2 点伤害。",
             [("always", "freeze", "selected-enemy", 1), ("always", "damage", "selected-enemy", 2)],
             keywords=["STUN"], tags=["眩晕", "召唤"]),
    65306: C("呱太降临", "form", 2, 1, "R", 1,
             "获得 +3/+6。己方回合开始时，为所有己方式神恢复 1 点生命。",
             [("always", "form", "source", F(3, 6))],
             formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
             formHooks=[{"id": "form-longche-descent", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "召唤", "治疗"]),
    65307: C("呱太军团", "spell", 3, 2, "SSR", 0,
             "对所有敌方式神造成 2 点伤害，并使所有己方式神获得 +1/+1。",
             [("always", "damage", "all-enemy-units", 2), ("always", "buff-stats", "all-ally-units", F(1, 1))],
             deck_limit=2, tags=["群伤", "团辅", "终结"]),
    65308: C("呱之领域", "realm", 3, 1, "SR", 0,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "召唤", "伤害"]),

    # ---- 贫乏神 657 ----
    65701: C("都听我号令", "spell", 1, 0, "R", 1,
             "瞬发。抽一张牌，并使一个敌方式神 -1 力量。",
             [("always", "draw", "ally-player", 1), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "不幸", "压制"]),
    65702: C("不要靠近我", "form", 1, 1, "SR", 1,
             "获得 +2/+4。受到伤害后，使攻击者 -2 力量。",
             [("always", "form", "source", F(2, 4))],
             formAbility="受到伤害后，随机敌方 -2 力量。",
             formHooks=[{"id": "form-pinfashen-away", "event": "unit-damaged", "effect": "passive-armor-break-enemy-on-damage", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "不幸", "压制"]),
    65703: C("幸运大轮盘", "combat", 1, 1, "R", 1,
             "出击 +3（错乱攻击简化为直击自身风险：对敌方前线造成 1 点）。",
             [("source-ready", "assault", "source", 3), ("always", "damage-enemy-front", "auto", 1)],
             tags=["出击", "运势", "不幸"]),
    65704: C("恶作剧", "form", 2, 1, "R", 1,
             "获得 +3/+4。完成交战后，随机对一个敌方造成 2 点伤害。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，随机对一个敌方角色造成 2 点伤害。",
             formHooks=[{"id": "form-pinfashen-prank", "event": "combat-resolved", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "运势", "不幸"]),
    65705: C("觉醒·贫乏神", "awakening", 2, 1, "SR", 1,
             "对一个敌方式神造成 4 点伤害。觉醒：+3/+2，攻击后随机对敌方造成 1 点。",
             [("always", "awaken", "source", F(3, 2)), ("always", "damage", "selected-enemy", 4)],
             deck_limit=1, tags=["觉醒", "不幸", "伤害"]),
    65706: C("穷神附体", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 1 点伤害并 -1 力量。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "不幸", "压制"]),
    65707: C("霉运快快来", "spell", 3, 1, "SR", 1,
             "所有己方其他式神获得 +2/+2，并抽一张牌。",
             [("always", "buff-stats", "all-other-allies", F(2, 2)), ("always", "draw", "ally-player", 1)],
             tags=["团辅", "不幸", "过牌"]),
    65708: C("灾厄降临", "combat", 3, 2, "SSR", 0,
             "出击 +5（不幸叠层简化）。",
             [("source-ready", "assault", "source", 5)],
             deck_limit=2, tags=["出击", "不幸", "终结"]),

    # ---- 龙珏 654 ----
    65401: C("龙玄两仪", "combat", 1, 1, "R", 1,
             "出击 +2，并抽一张牌（切换简化）。",
             [("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
             tags=["出击", "龙息", "过牌"]),
    65402: C("逆鳞", "spell", 1, 0, "R", 1,
             "瞬发。移除自身破甲（简化为护甲），投射：造成 3 点伤害。",
             [("always", "shield", "source", 2), ("always", "damage-enemy-front", "auto", 3)],
             keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射", "龙息"]),
    65403: C("真龙脉息", "form", 1, 1, "SR", 1,
             "获得 +2/+4。完成交战后，对敌方前线造成 2 点伤害（乾息投射）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-longjue-breath", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "龙息", "投射"]),
    65404: C("空明八卦", "combat", 2, 1, "SR", 1,
             "出击 +3，并获得瞬发（本回合叠力简化）。",
             [("source-ready", "assault", "source", 3)],
             keywords=["INSTANT"], tags=["出击", "龙息", "迅捷"]),
    65405: C("千江映月", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "龙息", "投射"]),
    65406: C("觉醒·龙珏", "awakening", 2, 1, "SSR", 1,
             "对敌方所有角色造成 1 点伤害。觉醒：+2/+3，回合开始对敌方所有角色造成 1 点伤害。",
             [("always", "awaken", "source", F(2, 3)), ("always", "damage", "all-enemy-units", 1), ("always", "damage", "enemy-avatar", 1)],
             deck_limit=1, tags=["觉醒", "龙息", "群伤"]),
    65407: C("乾坤无相", "form", 3, 2, "SR", 0,
             "获得 +3/+5，并获得不屈与 2 点护甲。",
             [("always", "form", "source", F(3, 5)), ("always", "grant-unyielding", "source", 1), ("always", "shield", "source", 2)],
             keywords=["UNYIELDING"], tags=["形态", "龙息", "不屈"]),
    65408: C("飞龙行道", "combat", 3, 1, "R", 0,
             "出击 +3，并对敌方牌手造成 2 点伤害。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 2)],
             tags=["出击", "直击", "龙息"]),

    # ---- 封阳君 655 ----
    65501: C("流派·霁雪流", "combat", 1, 1, "R", 1,
             "出击 +2，并对一个敌方式神造成 1 点伤害。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "selected-enemy", 1)],
             tags=["出击", "流派", "易势"]),
    65502: C("流派·晴空流", "combat", 1, 1, "R", 1,
             "出击 +1，投射：造成 2 点伤害。",
             [("source-ready", "assault", "source", 1), ("always", "damage-enemy-front", "auto", 2)],
             keywords=["PROJECTILE"], tags=["出击", "投射", "流派"]),
    65503: C("封阳刀法", "combat", 2, 1, "SR", 1,
             "出击 +3，并对敌方牌手造成 2 点伤害（连击直击简化）。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 2)],
             tags=["出击", "直击", "流派"]),
    65504: C("雪影", "spell", 1, 0, "R", 1,
             "瞬发。对一个敌方式神造成 2 点伤害，并抽一张牌。",
             [("always", "damage", "selected-enemy", 2), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "流派", "过牌"]),
    65505: C("觉醒·封阳君", "awakening", 2, 1, "SSR", 1,
             "获得迅捷。觉醒：+2/+2，回合开始对敌方前线造成 2 点伤害。",
             [("always", "awaken", "source", F(2, 2))],
             keywords=["INSTANT"], deck_limit=1, tags=["觉醒", "流派", "易势"]),
    65506: C("艳阳", "realm", 2, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "流派", "伤害"]),
    65507: C("龙韬豹略", "spell", 3, 0, "SR", 1,
             "瞬发。对一个敌方式神造成 3 点伤害。",
             [("always", "damage", "selected-enemy", 3)],
             keywords=["INSTANT"], tags=["瞬发", "流派", "伤害"]),
    65508: C("望月星河", "combat", 3, 2, "R", 0,
             "对所有敌方式神造成 1 点伤害，然后出击 +4。",
             [("always", "damage", "all-enemy-units", 1), ("source-ready", "assault", "source", 4)],
             tags=["出击", "群伤", "流派"]),

    # ---- 烬天玉藻前 660 ----
    66001: C("噬魂", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害，并为自身恢复 1 点生命（九尾简化）。",
             [("always", "damage", "selected-enemy", 3), ("always", "heal", "source", 1)],
             tags=["伤害", "九尾", "专注"]),
    66002: C("灵冲", "combat", 2, 1, "R", 1,
             "出击 +2，并投射：造成 1 点伤害。",
             [("source-ready", "assault", "source", 2), ("always", "damage-enemy-front", "auto", 1)],
             keywords=["PROJECTILE"], tags=["出击", "投射", "九尾"]),
    66003: C("炼狱之渊", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害，并为你恢复 3 点生命。",
             [("always", "damage", "selected-enemy", 3), ("always", "heal-avatar", "ally-avatar", 3)],
             tags=["伤害", "治疗", "九尾"]),
    66004: C("灭世莲华", "spell", 2, 1, "R", 1,
             "对敌方前线造成 4 点伤害，并对敌方牌手造成 2 点伤害。",
             [("always", "damage-enemy-front", "auto", 4), ("always", "damage", "enemy-avatar", 2)],
             tags=["伤害", "投射", "九尾"]),
    66005: C("逢原之主", "spell", 1, 1, "SR", 1,
             "投射：造成 3 点伤害，并使自身 +1/+1。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "buff-stats", "source", F(1, 1))],
             keywords=["PROJECTILE"], tags=["投射", "强化", "九尾"]),
    66006: C("逢魔夜行", "awakening", 2, 1, "SR", 1,
             "对所有敌方式神造成 1 点伤害。觉醒：+3/+2，回合开始随机对敌方造成 2 点。",
             [("always", "awaken", "source", F(3, 2)), ("always", "damage", "all-enemy-units", 1)],
             deck_limit=1, tags=["觉醒", "九尾", "群伤"]),
    66007: C("焚天九尾", "spell", 3, 2, "SR", 1,
             "对所有敌方角色造成 3 点伤害。",
             [("always", "damage", "all-enemy-units", 3), ("always", "damage", "enemy-avatar", 3)],
             tags=["群伤", "九尾", "终结"]),
    66008: C("浮世悲歌", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。己方回合开始时，对敌方前线造成 3 点伤害并抽一张牌。",
             [("always", "form", "source", F(4, 4))],
             formAbility="己方回合开始时，对敌方前线造成 3 点伤害并抽一张牌。",
             formHooks=[{"id": "form-jintian-dirge", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
             deck_limit=2, tags=["形态", "九尾", "终结"]),

    # ---- 禅心云外镜 656 ----
    65601: C("空无我", "combat", 1, 1, "R", 1,
             "出击 +1，并为一个己方角色恢复 3 点生命。",
             [("source-ready", "assault", "source", 1), ("always", "heal", "selected-ally", 3)],
             tags=["出击", "治疗", "连引"]),
    65602: C("观自在", "spell", 1, 1, "R", 1,
             "使一个己方式神获得 +1/+2 与 2 点护甲（庇佑简化）。",
             [("always", "buff-stats", "selected-ally", F(1, 2)), ("always", "shield", "selected-ally", 2)],
             tags=["庇佑", "强化", "连引"]),
    65603: C("无垢无净", "awakening", 2, 1, "SSR", 1,
             "抽一张牌。觉醒：+2/+3，使用牌后抽一张牌（连引简化）。",
             [("always", "awaken", "source", F(2, 3)), ("always", "draw", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "连引", "庇佑"]),
    65604: C("心净明", "form", 2, 1, "SR", 1,
             "获得 +3/+4，并获得 2 点护甲。",
             [("always", "form", "source", F(3, 4)), ("always", "shield", "source", 2)],
             tags=["形态", "庇佑", "护甲"]),
    65605: C("无没识", "spell", 3, 1, "R", 1,
             "为所有己方式神恢复 4 点生命，并各获得 1 点护甲。",
             [("always", "heal", "all-ally-units", 4), ("always", "shield", "all-ally-units", 1)],
             tags=["团辅", "治疗", "庇佑"]),
    65606: C("水无垠", "combat", 3, 1, "R", 1,
             "对所有敌方式神造成 2 点伤害，并为所有己方式神恢复 2 点生命。",
             [("always", "damage", "all-enemy-units", 2), ("always", "heal", "all-ally-units", 2)],
             tags=["群伤", "团辅", "连引"]),
    65607: C("神镜庇佑", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，所有己方式神获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "庇佑", "护甲"]),
    65608: C("万法皆空", "spell", 1, 0, "SR", 1,
             "瞬发。抽两张牌，并使一个敌方式神 -1 力量。",
             [("always", "draw", "ally-player", 2), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "连引"]),

    # ---- 招财猫 659 ----
    65901: C("猫的报恩", "spell", 1, 1, "R", 1,
             "为你恢复 3 点生命，并抽一张牌。",
             [("always", "heal-avatar", "ally-avatar", 3), ("always", "draw", "ally-player", 1)],
             tags=["治疗", "过牌", "御守"]),
    65902: C("事业御守", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "御守", "伤害"]),
    65903: C("驱邪赈灾", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害，若消灭则自身 +1/+1（简化常驻 +1/+0）。",
             [("always", "damage", "selected-enemy", 3), ("always", "buff-stats", "source", F(1, 0))],
             tags=["伤害", "强化", "御守"]),
    65904: C("健康御守", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，为所有己方式神恢复 1 点生命。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "治疗", "御守"]),
    65905: C("觉醒·招财猫", "awakening", 2, 1, "SR", 1,
             "为你恢复 4 点生命。觉醒：+2/+3，回合开始抽一张牌。",
             [("always", "awaken", "source", F(2, 3)), ("always", "heal-avatar", "ally-avatar", 4)],
             deck_limit=1, tags=["觉醒", "御守", "过牌"]),
    65906: C("福气招来", "form", 2, 1, "SSR", 0,
             "获得 +3/+5。己方回合开始时，随机对一个敌方造成 2 点伤害。",
             [("always", "form", "source", F(3, 5))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
             formHooks=[{"id": "form-zhaocaimao-luck", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
             deck_limit=2, tags=["形态", "御守", "伤害"]),
    65907: C("金钱御守", "realm", 3, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，所有己方式神 +1/+1。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "强化", "御守"]),
    65908: C("洒金成雨", "spell", 3, 2, "SR", 0,
             "投射：造成 6 点伤害。",
             [("always", "damage-enemy-front", "auto", 6)],
             keywords=["PROJECTILE"], tags=["投射", "伤害", "终结"]),

    # ---- 猫掌柜·焕宴 658 ----
    65801: C("服务升级", "combat", 1, 1, "R", 1,
             "出击 +2，并获得先攻。",
             [("source-ready", "assault", "source", 2)],
             keywords=["FIRST_STRIKE"], tags=["出击", "先攻", "蓝图"]),
    65802: C("猫侍应招来", "spell", 1, 0, "R", 1,
             "瞬发。抽一张牌，并使一个己方式神获得 +1/+1。",
             [("always", "draw", "ally-player", 1), ("always", "buff-stats", "selected-ally", F(1, 1))],
             keywords=["INSTANT"], tags=["瞬发", "召唤", "蓝图"]),
    65803: C("回馈计划", "form", 1, 1, "SR", 1,
             "获得 +2/+4。完成交战后，对敌方前线造成 2 点伤害。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-maozhanggui-rebate", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "蓝图", "投射"]),
    65804: C("新生·猫合战", "spell", 2, 1, "R", 1,
             "使一个敌方式神获得 -3/-3。",
             [("always", "debuff-stats", "selected-enemy", F(3, 3))],
             tags=["压制", "蓝图"]),
    65805: C("膳食精进", "realm", 2, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，为所有己方式神恢复 1 点生命并 +1/+0。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "料理", "蓝图"]),
    65806: C("蓝图愿景", "awakening", 2, 1, "SR", 1,
             "抽一张牌。觉醒：+2/+2，幻境进场时获得 1 点耐久（简化为回合开始护盾）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "蓝图", "过牌"]),
    65807: C("新生祭典", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：进场投射 3 点伤害，回合开始为所有己方式神恢复 2 点生命。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "团辅", "终结"]),
    65808: C("临时加班", "spell", 3, 0, "R", 0,
             "瞬发。为你恢复 4 点生命，并抽一张牌。",
             [("always", "heal-avatar", "ally-avatar", 4), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "治疗", "蓝图"]),

    # ---- 歌留多 661 ----
    66101: C("花叠百景", "spell", 1, 1, "R", 1,
             "随机将两张花札牌置入手牌（简化为抽两张牌）。",
             [("always", "draw", "ally-player", 2)],
             keywords=["CHAIN"], tags=["花札", "过牌", "连锁"]),
    66102: C("猪鹿蝶", "form", 2, 1, "SR", 1,
             "获得 +3/+4。己方回合开始时，随机对一个敌方造成 1 点伤害。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-geluoduo-deer", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "花札", "连锁"]),
    66103: C("月见酒", "combat", 1, 1, "R", 1,
             "出击 +2。对牌手造成伤害时，抽一张牌（简化为附带直伤）。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 1)],
             tags=["出击", "花札", "直击"]),
    66104: C("花见酒", "spell", 1, 0, "R", 1,
             "瞬发。复活一个己方式神并恢复 3 点生命（临时复活简化）。",
             [("always", "revive", "knocked-ally", 1), ("always", "heal", "selected-ally", 3)],
             keywords=["INSTANT"], tags=["瞬发", "复活", "花札"]),
    66105: C("觉醒·歌留多", "awakening", 2, 1, "SR", 1,
             "抽两张牌。觉醒：+2/+2，回合开始抽一张牌。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "花札", "连锁"]),
    66106: C("雨四光", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害（花札叠伤简化）。",
             [("always", "damage", "selected-enemy", 4)],
             tags=["伤害", "花札", "连锁"]),
    66107: C("五光斩", "combat", 3, 1, "SR", 1,
             "出击 +4，并对敌方前线造成 2 点伤害。",
             [("source-ready", "assault", "source", 4), ("always", "damage-enemy-front", "auto", 2)],
             tags=["出击", "花札", "投射"]),
    66108: C("花月乱舞", "form", 3, 2, "SSR", 0,
             "获得 +4/+5。完成交战后，对随机敌方造成 3 点伤害。",
             [("always", "form", "source", F(4, 5))],
             formAbility="完成交战后，随机对一个敌方角色造成 3 点伤害。",
             formHooks=[{"id": "form-geluoduo-dance", "event": "combat-resolved", "effect": "passive-damage-random-enemy", "params": {"amount": 3}, "priority": 40}],
             deck_limit=2, tags=["形态", "花札", "终结"]),

    # ---- 因幡辉夜姬 666 ----
    66601: C("月之茧", "spell", 1, 1, "R", 1,
             "召唤因幡兔（简化为自身 +1/+2）并抽一张牌。",
             [("always", "buff-stats", "source", F(1, 2)), ("always", "draw", "ally-player", 1)],
             tags=["召唤", "遗愿", "过牌"]),
    66602: C("琉璃光", "spell", 1, 0, "R", 1,
             "瞬发。使一个己方式神获得 +1/+1，其他己方式神 +0/+1（祈愿简化）。",
             [("always", "buff-stats", "selected-ally", F(1, 1)), ("always", "buff-stats", "all-other-allies", F(0, 1))],
             keywords=["INSTANT"], tags=["瞬发", "团辅", "祈愿"]),
    66603: C("长明如愿", "spell", 1, 1, "R", 1,
             "使一个己方式神获得 +2 战力（+2/+0）与 2 点护甲。",
             [("always", "buff-stats", "selected-ally", F(2, 0)), ("always", "shield", "selected-ally", 2)],
             tags=["强化", "遗愿", "祈愿"]),
    66604: C("羽落银阙", "form", 2, 1, "SSR", 0,
             "获得 +3/+5。己方回合开始时，为所有己方式神恢复 1 点生命。",
             [("always", "form", "source", F(3, 5))],
             formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
             formHooks=[{"id": "form-kaguya-feather", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
             deck_limit=2, tags=["形态", "遗愿", "团辅"]),
    66605: C("寂光映月", "awakening", 2, 1, "SR", 1,
             "获得 2 点护甲。觉醒：+2/+2，回合开始获得 1 点护甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "shield", "source", 2)],
             deck_limit=1, tags=["觉醒", "遗愿", "护甲"]),
    66606: C("愿满夜", "realm", 2, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，对所有敌方式神造成 1 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "遗愿", "群伤"]),
    66607: C("月之洗礼", "spell", 3, 1, "R", 1,
             "对敌方前线造成 4 点伤害，并对所有敌方角色造成 1 点伤害。",
             [("always", "damage-enemy-front", "auto", 4), ("always", "damage", "all-enemy-units", 1), ("always", "damage", "enemy-avatar", 1)],
             tags=["伤害", "群伤", "遗愿"]),
    66608: C("月光流照", "form", 3, 2, "SR", 0,
             "获得 +4/+5。己方回合开始时，抽一张牌并为你恢复 3 点生命。",
             [("always", "form", "source", F(4, 5))],
             formAbility="己方回合开始时，抽一张牌并为你恢复 2 点生命。",
             formHooks=[{"id": "form-kaguya-moon", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             deck_limit=2, tags=["形态", "遗愿", "过牌"]),

    # ---- 待宵姑获鸟 667 ----
    66701: C("羽念", "spell", 1, 0, "R", 1,
             "瞬发。使一个己方式神 +1/+1，并获得 2 点护甲（充能简化）。",
             [("always", "buff-stats", "selected-ally", F(1, 1)), ("always", "shield", "source", 2)],
             keywords=["INSTANT"], tags=["瞬发", "充能", "强化"]),
    66702: C("鹤羽之佑", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，所有己方其他式神获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "充能", "护甲"]),
    66703: C("墨袭", "combat", 1, 1, "R", 1,
             "出击 +3（充能叠力简化）。",
             [("source-ready", "assault", "source", 3)],
             tags=["出击", "充能", "追猎"]),
    66704: C("千宵待尽", "awakening", 2, 1, "SR", 1,
             "投射：造成 3 点伤害。觉醒：+2/+2，己方其他式神攻击后投射 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3)],
             deck_limit=1, tags=["觉醒", "充能", "投射"]),
    66705: C("羽授", "combat", 2, 1, "R", 1,
             "出击 +2，并获得瞬发。",
             [("source-ready", "assault", "source", 2)],
             keywords=["INSTANT"], tags=["出击", "迅捷", "充能"]),
    66706: C("鹤佑之心", "form", 2, 1, "SR", 1,
             "获得 +3/+5。己方回合开始时，为所有己方其他式神 +1/+0。",
             [("always", "form", "source", F(3, 5))],
             formAbility="己方回合开始时，所有己方其他式神 +1 力量。",
             formHooks=[{"id": "form-daixiao-heart", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "充能", "团辅"]),
    66707: C("墨影剑光", "spell", 3, 1, "SSR", 0,
             "使自身 +1/+0 并出击 +3（远程简化为附带投射 2）。",
             [("always", "buff-stats", "source", F(1, 0)), ("source-ready", "assault", "source", 3), ("always", "damage-enemy-front", "auto", 2)],
             deck_limit=2, tags=["出击", "投射", "充能"]),
    66708: C("金羽流焰", "combat", 3, 2, "SR", 0,
             "出击 +2，投射：造成 4 点伤害。",
             [("source-ready", "assault", "source", 2), ("always", "damage-enemy-front", "auto", 4)],
             keywords=["PROJECTILE"], tags=["出击", "投射", "充能"]),

    # ---- 初翎山风 662 ----
    66201: C("林", "combat", 2, 1, "R", 1,
             "出击 +2，并获得贯通。",
             [("source-ready", "assault", "source", 2)],
             keywords=["PIERCE"], tags=["出击", "入阵", "贯通"]),
    66202: C("疾", "form", 1, 1, "SR", 1,
             "获得 +3/+5，并获得迅捷。",
             [("always", "form", "source", F(3, 5))],
             keywords=["INSTANT"], tags=["形态", "入阵", "迅捷"]),
    66203: C("破", "spell", 1, 0, "R", 1,
             "瞬发。重置出击次数（简化为获得迅捷），并对一个敌方式神造成 2 点伤害。",
             [("always", "damage", "selected-enemy", 2)],
             keywords=["INSTANT"], tags=["瞬发", "入阵", "伤害"]),
    66204: C("狩", "realm", 2, 1, "SSR", 0,
             "幻境（耐久 6）：己方回合开始时，所有己方式神 +1 战力。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             deck_limit=2, tags=["幻境", "入阵", "团辅"]),
    66205: C("山", "awakening", 2, 1, "SR", 1,
             "使所有己方式神获得 +1/+1。觉醒：+2/+2，入阵效果强化为回合开始 +1/+1。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "all-ally-units", F(1, 1))],
             deck_limit=1, tags=["觉醒", "入阵", "团辅"]),
    66206: C("风", "combat", 1, 1, "R", 1,
             "出击 +3，并使目标 -1 力量。",
             [("source-ready", "assault", "source", 3), ("always", "debuff-stats", "selected-enemy", F(1, 0))],
             tags=["出击", "入阵", "移动"]),
    66207: C("啸", "form", 3, 1, "SR", 1,
             "获得 +3/+5，并获得迅捷。完成交战后，随机对敌方造成 2 点伤害。",
             [("always", "form", "source", F(3, 5))],
             keywords=["INSTANT"],
             formAbility="完成交战后，随机对一个敌方角色造成 2 点伤害。",
             formHooks=[{"id": "form-shanfeng-roar", "event": "combat-resolved", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "入阵", "迅捷"]),
    66208: C("火", "combat", 3, 2, "R", 0,
             "出击 +5，并获得贯通。",
             [("source-ready", "assault", "source", 5)],
             keywords=["PIERCE"], tags=["出击", "贯通", "入阵"]),

    # ---- 凤凰火·净羽 665 ----
    66501: C("心火", "spell", 1, 1, "R", 1,
             "投射：造成 2 点伤害，并抽一张牌（火种简化）。",
             [("always", "damage-enemy-front", "auto", 2), ("always", "draw", "ally-player", 1)],
             keywords=["PROJECTILE"], tags=["投射", "火种", "过牌"]),
    66502: C("净化之火", "spell", 1, 1, "SR", 1,
             "对所有敌方式神造成 1 点伤害，并为自身恢复 2 点生命。",
             [("always", "damage", "all-enemy-units", 1), ("always", "heal", "source", 2)],
             tags=["群伤", "火种", "治疗"]),
    66503: C("凤凰业火", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害。",
             [("always", "damage", "selected-enemy", 4)],
             tags=["伤害", "火种"]),
    66504: C("薪火共鸣", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "火种", "投射"]),
    66505: C("炽翼翔空", "awakening", 2, 1, "SR", 1,
             "投射：造成 3 点伤害。觉醒：+2/+2，气绝倒计时 -1（简化为回合开始投射 1）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3)],
             deck_limit=1, tags=["觉醒", "火种", "投射"]),
    66506: C("烬羽", "spell", 2, 1, "R", 1,
             "对一个式神造成 6 点伤害，并对自身造成 2 点伤害。",
             [("always", "damage", "selected-enemy", 6), ("always", "damage-self", "source", 2)],
             tags=["伤害", "自伤", "火种"]),
    66507: C("夜火流空", "form", 3, 2, "SSR", 0,
             "获得 +4/+4，并获得迅捷。非战斗伤害 +2（简化为回合开始投射 2）。",
             [("always", "form", "source", F(4, 4))],
             keywords=["INSTANT"],
             formAbility="己方回合开始时，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-fenghuang-night", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
             deck_limit=2, tags=["形态", "火种", "投射"]),
    66508: C("凤啸", "spell", 3, 1, "SR", 0,
             "抽两张牌，并对所有敌方式神造成 1 点伤害。",
             [("always", "draw", "ally-player", 2), ("always", "damage", "all-enemy-units", 1)],
             tags=["过牌", "群伤", "火种"]),

    # ---- 吸血姬·曦忆 663 ----
    66301: C("血绽", "spell", 1, 1, "R", 1,
             "对你造成 2 点伤害，对一个式神造成 4 点伤害。",
             [("always", "damage-self", "source", 2), ("always", "damage", "selected-enemy", 4)],
             tags=["伤害", "自伤", "入夜"]),
    66302: C("血祭", "spell", 1, 1, "SR", 1,
             "气绝时可用：复活吸血姬·曦忆，并对你造成 3 点伤害。",
             [("always", "revive", "knocked-ally", 1), ("always", "damage-self", "source", 3)],
             tags=["复活", "自伤", "入夜"]),
    66303: C("永夜邀约", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对双方牌手造成 1 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "入夜", "直击"]),
    66304: C("血夜咏叹", "form", 2, 1, "SR", 1,
             "获得 +3/+5。入阵（简化为完成交战）后，投射：造成 3 点伤害。",
             [("always", "form", "source", F(3, 5))],
             formAbility="完成交战后，对敌方前线造成 3 点伤害。",
             formHooks=[{"id": "form-xixueji-aria", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 3}, "priority": 40}],
             tags=["形态", "入夜", "投射"]),
    66305: C("血之契约", "awakening", 2, 1, "SR", 1,
             "对你造成 1 点伤害，自身 +2/+2。觉醒：回合开始对你造成 1 点伤害并 +1 战力。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-self", "source", 1)],
             deck_limit=1, tags=["觉醒", "入夜", "自伤"]),
    66306: C("生命螺旋", "combat", 2, 1, "R", 1,
             "出击 +2，对双方牌手造成 2 点伤害，并恢复 2 点生命。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 2), ("always", "heal", "source", 2)],
             tags=["出击", "吸血", "入夜"]),
    66307: C("二重禁忌", "form", 3, 2, "SSR", 0,
             "获得 +4/+5，并获得不屈。己方回合具有吸血（简化为回合开始恢复 3 点生命）。",
             [("always", "form", "source", F(4, 5)), ("always", "grant-unyielding", "source", 1)],
             keywords=["UNYIELDING"],
             formAbility="己方回合开始时，恢复 3 点生命。",
             formHooks=[{"id": "form-xixueji-taboo", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 3}, "priority": 40}],
             deck_limit=2, tags=["形态", "吸血", "终结"]),
    66308: C("血月重现", "combat", 3, 1, "R", 0,
             "出击 +4，并对双方牌手造成 2 点伤害。",
             [("source-ready", "assault", "source", 4), ("always", "damage", "enemy-avatar", 2)],
             tags=["出击", "直击", "入夜"]),

    # ---- 樱花妖·璃景 664 ----
    66401: C("樱刃", "combat", 1, 1, "R", 1,
             "出击 +2。攻击后，对敌方前线造成 1 点伤害（琉璃樱简化）。",
             [("source-ready", "assault", "source", 2), ("always", "damage-enemy-front", "auto", 1)],
             tags=["出击", "召唤", "遗愿"]),
    66402: C("璃光花梦", "spell", 1, 1, "R", 1,
             "气绝时可用：复活樱花妖·璃景，并使其获得迅捷。",
             [("always", "revive", "knocked-ally", 1), ("always", "buff-stats", "source", F(1, 1))],
             keywords=["INSTANT"], tags=["复活", "迅捷", "遗愿"]),
    66403: C("镜花千重", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，为所有己方式神 +0/+1。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "遗愿", "召唤"]),
    66404: C("散华花歌", "awakening", 2, 1, "SR", 1,
             "使所有己方式神 +1/+1。觉醒：+2/+2，气绝/回合开始召唤感（简化为自身 +1/+1）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "all-ally-units", F(1, 1))],
             deck_limit=1, tags=["觉醒", "遗愿", "团辅"]),
    66405: C("花葬", "combat", 2, 1, "SR", 1,
             "出击 +4，并对自身造成 2 点伤害。",
             [("source-ready", "assault", "source", 4), ("always", "damage-self", "source", 2)],
             tags=["出击", "自伤", "遗愿"]),
    66406: C("花愿", "spell", 2, 1, "R", 1,
             "气绝时可用：复活，并对一个敌方式神造成 3 点伤害。",
             [("always", "revive", "knocked-ally", 1), ("always", "damage", "selected-enemy", 3)],
             tags=["复活", "伤害", "遗愿"]),
    66407: C("璃魄华舞", "form", 3, 2, "SSR", 0,
             "获得 +3/+6，并获得迅捷与远程。完成交战后，对敌方前线造成 2 点伤害。",
             [("always", "form", "source", F(3, 6))],
             keywords=["INSTANT", "REMOTE"],
             formAbility="完成交战后，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-yinghuayao-dance", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
             deck_limit=2, tags=["形态", "遗愿", "投射"]),
    66408: C("樱时雨", "combat", 3, 1, "SR", 0,
             "出击 +3，并使所有己方其他式神 +1/+1（战力收割简化）。",
             [("source-ready", "assault", "source", 3), ("always", "buff-stats", "all-other-allies", F(1, 1))],
             tags=["出击", "团辅", "遗愿"]),

    # ---- 蜃气楼 298 ----
    29801: C("闪光压指", "combat", 1, 1, "R", 1,
             "出击 +2，并获得贯通（百识弃牌简化）。",
             [("source-ready", "assault", "source", 2)],
             keywords=["PIERCE"], tags=["出击", "百识", "贯通"]),
    29802: C("须臾蜃气", "form", 1, 1, "R", 1,
             "获得 +3/+5。完成交战后，对敌方前线造成 1 点伤害。",
             [("always", "form", "source", F(3, 5))],
             formAbility="完成交战后，对敌方前线造成 1 点伤害。",
             formHooks=[{"id": "form-shenqilou-mist", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "百识", "投射"]),
    29803: C("百识·印", "spell", 1, 1, "SR", 1,
             "对一个式神造成 4 点伤害，并抽一张牌。",
             [("always", "damage", "selected-enemy", 4), ("always", "draw", "ally-player", 1)],
             tags=["伤害", "百识", "过牌"]),
    29804: C("真伪莫辨", "combat", 2, 1, "SR", 1,
             "出击 +1，并对所有敌方式神造成 1 点伤害。",
             [("source-ready", "assault", "source", 1), ("always", "damage", "all-enemy-units", 1)],
             tags=["出击", "群伤", "百识"]),
    29805: C("蜃市万华", "form", 2, 1, "R", 1,
             "获得 +3/+5，并获得坚毅（不屈简化）。",
             [("always", "form", "source", F(3, 5)), ("always", "grant-unyielding", "source", 1)],
             keywords=["UNYIELDING"], tags=["形态", "百识", "不屈"]),
    29806: C("虚实难解", "spell", 2, 1, "R", 1,
             "抽两张牌，并对敌方前线造成 2 点伤害。",
             [("always", "draw", "ally-player", 2), ("always", "damage-enemy-front", "auto", 2)],
             tags=["过牌", "投射", "百识"]),
    29807: C("万阵破", "spell", 3, 1, "SR", 1,
             "只能响应使用。响应：自动使用并眩晕攻击者（反制简化）。",
             [("always", "damage", "selected-enemy", 4), ("always", "freeze", "all-enemy-units", 1)],
             keywords=["RESPONSE", "STUN"], timing="response", responseTo=["assault"],
             tags=["响应", "眩晕", "百识"]),
    29808: C("胧月夜", "awakening", 3, 2, "SSR", 1,
             "抽两张牌。觉醒：+2/+3，回合开始对敌方前线造成 2 点伤害。",
             [("always", "awaken", "source", F(2, 3)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "百识", "投射"]),
}

TOKENS: list = []
EXTRA_TOKENS: list = []

# 被动映射：uid -> (passive, awakenedPassive)；formHooks/被动仅用已注册 passive-*
PASSIVES = {
    "yatiangou-qiuye": (
        dict(id="yatiangou-art", name="神通修行", text="己方回合开始时，随机对一个敌方角色造成 1 点伤害（神通简化）。",
             hooks=[dict(id="art-practice", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="yatiangou-art-awakened", name="大权现", text="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
             hooks=[dict(id="art-practice-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 2})]),
    ),
    "shuweng-zhixing": (
        dict(id="shuweng-journal", name="游记", text="己方回合开始时，抽一张牌（游记简化）。",
             hooks=[dict(id="journal-draw", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="shuweng-journal-awakened", name="无量书", text="己方回合开始时，抽一张牌并恢复 1 点生命。",
             hooks=[
                 dict(id="journal-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
                 dict(id="journal-heal-a", event="turn-started", effect="passive-heal-ally-if-front-or-any", params={"amount": 1}),
             ]),
    ),
    "huojinshen": (
        dict(id="huojin-veil", name="咒纱", text="受到伤害后，获得 1 点护甲（咒纱减伤简化）。",
             hooks=[dict(id="veil-shield", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="huojin-veil-awakened", name="缠心咒纱", text="受到伤害后，获得 2 点护甲。",
             hooks=[dict(id="veil-shield-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "sibing": (
        dict(id="sibing-tray", name="折敷", text="己方回合开始时，获得 1 点护甲（折敷简化）。",
             hooks=[dict(id="tray-shield", event="turn-started", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="sibing-tray-awakened", name="本膳料理", text="己方回合开始时，获得 2 点护甲并恢复 1 点生命。",
             hooks=[
                 dict(id="tray-shield-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="tray-heal-a", event="turn-started", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "dayueling-yuxin": (
        dict(id="dayue-jewel", name="八尺琼勾玉", text="完成交战后，随机敌方 -1 力量（勾玉简化）。",
             hooks=[dict(id="jewel-break", event="combat-resolved", effect="passive-armor-break-enemy-on-damage", params={"amount": 1})]),
        dict(id="dayue-jewel-awakened", name="鬼神勾玉", text="完成交战后，随机敌方 -2 力量。",
             hooks=[dict(id="jewel-break-a", event="combat-resolved", effect="passive-armor-break-enemy-on-damage", params={"amount": 2})]),
    ),
    "chili": (
        dict(id="chili-breath", name="蟠息", text="己方回合开始时，获得 1 点护甲（蓄力蟠息简化）。",
             hooks=[dict(id="breath-shield", event="turn-started", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="chili-breath-awakened", name="行云蟠息", text="己方回合开始时，获得 2 点护甲并抽一张牌。",
             hooks=[
                 dict(id="breath-shield-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="breath-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "jieshen-suiyuan": (
        dict(id="jieshen-fortune", name="福缘", text="己方回合开始时，为你恢复 1 点生命（赏金简化）。",
             hooks=[dict(id="fortune-heal", event="turn-started", effect="passive-heal-avatar-on-own-card", params={"amount": 1})]),
        dict(id="jieshen-fortune-awakened", name="遂愿", text="己方回合开始时，为你恢复 2 点生命并抽一张牌。",
             hooks=[
                 dict(id="fortune-heal-a", event="turn-started", effect="passive-heal-avatar-on-own-card", params={"amount": 2}),
                 dict(id="fortune-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "tieshu-haojia": (
        dict(id="tieshu-cost", name="成本控制", text="完成交战后，对敌方牌手造成 1 点伤害。",
             hooks=[dict(id="cost-face", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="tieshu-cost-awakened", name="豪贾", text="完成交战后，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="cost-face-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    "yijin-qianxun": (
        dict(id="yijin-wind", name="风的指引", text="己方回合开始时，抽一张牌（倒计时简化）。",
             hooks=[dict(id="wind-draw", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="yijin-wind-awakened", name="千羽", text="己方回合开始时，抽一张牌并对敌方前线造成 1 点伤害。",
             hooks=[
                 dict(id="wind-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
                 dict(id="wind-dmg-a", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 1}),
             ]),
    ),
    "baizangzhu-lixin": (
        dict(id="baizang-foxfire", name="狐焰·青", text="敌方使用牌后简化：己方回合开始时，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="foxfire-dmg", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="baizang-foxfire-awakened", name="狐焰·赤", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="foxfire-dmg-a", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "guijinyang": (
        dict(id="guijin-notice", name="预告信", text="己方回合开始时，随机敌方 -1 力量（偷取简化）。",
             hooks=[dict(id="notice-break", event="turn-started", effect="passive-armor-break-enemy-front", params={"amount": 1})]),
        dict(id="guijin-notice-awakened", name="鬼宿", text="己方回合开始时，随机敌方 -2 力量。",
             hooks=[dict(id="notice-break-a", event="turn-started", effect="passive-armor-break-enemy-front", params={"amount": 2})]),
    ),
    "longche": (
        dict(id="longche-guata", name="呱太", text="受到伤害后，获得 1 点护甲（召呱简化）。",
             hooks=[dict(id="guata-shield", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="longche-guata-awakened", name="呱多势众", text="受到伤害后，获得 2 点护甲。",
             hooks=[dict(id="guata-shield-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "pinfashen": (
        dict(id="pinfashen-curse", name="不幸", text="完成交战后，随机对一个敌方造成 1 点伤害（厄运简化）。",
             hooks=[dict(id="curse-dmg", event="combat-resolved", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="pinfashen-curse-awakened", name="灾厄", text="完成交战后，随机对一个敌方造成 2 点伤害。",
             hooks=[dict(id="curse-dmg-a", event="combat-resolved", effect="passive-damage-random-enemy", params={"amount": 2})]),
    ),
    "longjue": (
        dict(id="longjue-dragon", name="龙息之力", text="己方回合开始时，对敌方前线造成 1 点伤害（乾息投射简化）。",
             hooks=[dict(id="dragon-dmg", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="longjue-dragon-awakened", name="乾坤无相", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="dragon-dmg-a", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "fengyangjun": (
        dict(id="fengyang-style", name="易势", text="己方回合开始时，若在战斗区，获得 1 点护甲。",
             hooks=[dict(id="style-shield", event="turn-started", effect="passive-shield-self-if-front", params={"amount": 1})]),
        dict(id="fengyang-style-awakened", name="封阳刀意", text="己方回合开始时，获得 2 点护甲。",
             hooks=[dict(id="style-shield-a", event="turn-started", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "jintianyuzaoqian": (
        dict(id="jintian-nine", name="九尾之力", text="己方回合开始时，随机对一个敌方造成 1 点伤害。",
             hooks=[dict(id="nine-dmg", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="jintian-nine-awakened", name="烬天九尾", text="己方回合开始时，随机对一个敌方造成 2 点伤害。",
             hooks=[dict(id="nine-dmg-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 2})]),
    ),
    "chanxinyunwaijing": (
        dict(id="chanxin-mirror", name="庇佑", text="己方回合开始时，获得 1 点护甲。",
             hooks=[dict(id="mirror-shield", event="turn-started", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="chanxin-mirror-awakened", name="万法皆空", text="己方回合开始时，获得 2 点护甲并抽一张牌。",
             hooks=[
                 dict(id="mirror-shield-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="mirror-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "zhaocaimao": (
        dict(id="zhaocaimao-luck", name="赏金", text="己方回合开始时，为你恢复 1 点生命。",
             hooks=[dict(id="luck-heal", event="turn-started", effect="passive-heal-avatar-on-own-card", params={"amount": 1})]),
        dict(id="zhaocaimao-luck-awakened", name="招财进宝", text="己方回合开始时，为你恢复 2 点生命。",
             hooks=[dict(id="luck-heal-a", event="turn-started", effect="passive-heal-avatar-on-own-card", params={"amount": 2})]),
    ),
    "maozhanggui-huanyan": (
        dict(id="maozhanggui-blueprint", name="店面焕新", text="己方回合开始时，获得 1 点护甲（蓝图简化）。",
             hooks=[dict(id="blueprint-shield", event="turn-started", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="maozhanggui-blueprint-awakened", name="新生祭典", text="己方回合开始时，获得 2 点护甲。",
             hooks=[dict(id="blueprint-shield-a", event="turn-started", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "geluoduo": (
        dict(id="geluoduo-hanafuda", name="花札", text="己方回合开始时，抽一张牌（花札获取简化）。",
             hooks=[dict(id="hana-draw", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="geluoduo-hanafuda-awakened", name="五光", text="己方回合开始时，抽一张牌并对敌方前线造成 1 点伤害。",
             hooks=[
                 dict(id="hana-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
                 dict(id="hana-dmg-a", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 1}),
             ]),
    ),
    "yinfanhuiyeji": (
        dict(id="kaguya-lastwish", name="遗愿", text="气绝时简化：受到伤害后，随机敌方 -1 力量。",
             hooks=[dict(id="wish-break", event="unit-damaged", effect="passive-armor-break-enemy-on-damage", params={"amount": 1})]),
        dict(id="kaguya-lastwish-awakened", name="月之遗愿", text="受到伤害后，随机敌方 -2 力量。",
             hooks=[dict(id="wish-break-a", event="unit-damaged", effect="passive-armor-break-enemy-on-damage", params={"amount": 2})]),
    ),
    "daixiaoguhuoniao": (
        dict(id="daixiao-charge", name="充能", text="己方回合开始时，获得 1 点护甲（能量简化）。",
             hooks=[dict(id="charge-shield", event="turn-started", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="daixiao-charge-awakened", name="鹤羽充能", text="己方回合开始时，获得 2 点护甲并对敌方前线造成 1 点伤害。",
             hooks=[
                 dict(id="charge-shield-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="charge-dmg-a", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 1}),
             ]),
    ),
    "chulingshanfeng": (
        dict(id="shanfeng-enter", name="入阵", text="进入/回合开始简化：己方回合开始时，+1 力量（本回合）。",
             hooks=[dict(id="enter-buff", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="shanfeng-enter-awakened", name="烈火入阵", text="己方回合开始时，+2 力量。",
             hooks=[dict(id="enter-buff-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "fenghuanghuo-jingyu": (
        dict(id="fenghuang-spark", name="火种", text="气绝/遗愿简化：受到伤害后，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="spark-dmg", event="unit-damaged", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="fenghuang-spark-awakened", name="不灭火种", text="受到伤害后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="spark-dmg-a", event="unit-damaged", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "xixueji-xiyi": (
        dict(id="xixueji-night", name="入夜", text="己方回合开始时，对你造成 1 点伤害并获得 1 点力量（战力简化）。",
             hooks=[
                 dict(id="night-self", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
        dict(id="xixueji-night-awakened", name="永夜曦忆", text="己方回合开始时，+2 力量并恢复 1 点生命。",
             hooks=[
                 dict(id="night-buff-a", event="turn-started", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="night-heal-a", event="turn-started", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "yinghuayao-lijing": (
        dict(id="yinghuayao-sakura", name="琉璃樱", text="气绝/遗愿简化：受到伤害后，获得 1 点护甲。",
             hooks=[dict(id="sakura-shield", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="yinghuayao-sakura-awakened", name="璃魄华樱", text="受到伤害后，获得 2 点护甲。",
             hooks=[dict(id="sakura-shield-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "shenqilou": (
        dict(id="shenqilou-hyakushiki", name="百识", text="己方回合开始时，抽一张牌（百识获取简化）。",
             hooks=[dict(id="hyaku-draw", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="shenqilou-hyakushiki-awakened", name="胧月百识", text="己方回合开始时，抽一张牌并对敌方前线造成 1 点伤害。",
             hooks=[
                 dict(id="hyaku-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1}),
                 dict(id="hyaku-dmg-a", event="turn-started", effect="passive-damage-enemy-front", params={"amount": 1}),
             ]),
    ),
}


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def clamp_level(level) -> int:
    try:
        lv = int(level)
    except Exception:
        return 1
    return max(1, min(3, lv))


def clamp_cost(cost) -> int:
    try:
        c = int(cost)
    except Exception:
        return 1
    return max(0, min(2, c))


def normalize_starters() -> None:
    """确保每式神 starter 合计=8：觉醒=1，非觉醒 SSR=0，其余分配剩余 7 份（单卡≤2）。"""
    by_unit: dict[str, list[tuple[int, dict]]] = {u[0]: [] for u in UNITS}
    for oid, meta in CARD_MAP.items():
        by_unit[unit_of(oid)].append((oid, meta))
    for uid, items in by_unit.items():
        items = sorted(items, key=lambda kv: kv[0])
        for _, m in items:
            if m["type"] == "awakening":
                m["starter"] = 1
            elif m.get("rarity") == "SSR":
                m["starter"] = 0
            else:
                m["starter"] = 0
        others = [m for _, m in items if m["type"] != "awakening" and m.get("rarity") != "SSR"]
        remaining = 7
        for m in others:
            if remaining <= 0:
                break
            m["starter"] = 1
            remaining -= 1
        for m in others:
            if remaining <= 0:
                break
            if m["starter"] < 2:
                m["starter"] += 1
                remaining -= 1
        assert remaining == 0, f"{uid} leftover starter={remaining}"


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

    shiks = {}
    for s in json.loads((DATA / "shikigami.json").read_text(encoding="utf-8")):
        # 优先精确名字匹配；同名旧式神用 role 过滤
        key = (str(s.get("role")), s["name"])
        shiks[key] = s
        shiks.setdefault(s["name"], s)

    normalize_starters()

    # 校验：27 式神、每人 8 张、starter 合计 8、觉醒 1、SSR starter≤1、cost/level 边界
    assert len(UNITS) == 27, f"units={len(UNITS)}"
    by_unit_cards: dict[str, list[tuple[int, dict]]] = {u[0]: [] for u in UNITS}
    for oid, meta in CARD_MAP.items():
        uid = unit_of(oid)
        by_unit_cards[uid].append((oid, meta))
    for uid, items in by_unit_cards.items():
        assert len(items) == 8, f"{uid} cards={len(items)}"
        starters = sum(int(m["starter"]) for _, m in items)
        assert starters == 8, f"{uid} starter_sum={starters}"
        awks = [m for _, m in items if m["type"] == "awakening"]
        assert len(awks) == 1, f"{uid} awakenings={len(awks)}"
        assert int(awks[0]["starter"]) == 1, f"{uid} awakening starter"
        ssr_started = [m for _, m in items if m["rarity"] == "SSR" and int(m["starter"]) > 0]
        assert len(ssr_started) <= 1, f"{uid} starter SSR={len(ssr_started)}"
        for oid, m in items:
            assert 0 <= int(m["cost"]) <= 2, f"{oid} cost"
            assert 1 <= int(m["level"]) <= 3, f"{oid} level"
        # 龙珏 4 勾映射：level 已 clamp 到 ≤3

    lines = []
    lines.append("/**")
    lines.append(" * 龙渊·星缘·斗转·花札（wave9，27 式神）内容 — 由 scripts/gen-wave9-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE9_PACK_ID = 'wave9';")
    lines.append("export const WAVE9_PACK_NAME = '龙渊·星缘·斗转·花札';")
    lines.append("export const WAVE9_SUBPACKS = Object.freeze({ longyuan: '龙渊秘境', xingyuan: '星缘百策', douzhuan: '斗转万象', huazha: '花札祈梦' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE9_UNIT_DEFINITIONS = Object.freeze([")

    for uid, role, name, title, archetype, color, strategy, subpack in UNITS:
        shik = shiks.get((str(role), name)) or shiks[name]
        pw, lf = int(shik["power"]), int(shik["life"])
        if lf <= 0:
            lf = 5
        if pw <= 0:
            pw = 2
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
        lines.append(f"    art: {js_str(f'assets/wave9/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave9/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave9')},")
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
    lines.append("function wave9Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave9',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE9_CARD_DEFINITIONS = Object.freeze([")

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
        meta["level"] = clamp_level(meta["level"])
        meta["cost"] = clamp_cost(meta.get("cost", 1))
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
        lines.append(f"  wave9Card({official_id}, {js_str(unit_id)}, {{")
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
        lines.append(f"  wave9Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave9UnitIds() {")
    lines.append("  return WAVE9_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
