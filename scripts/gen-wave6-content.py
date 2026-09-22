#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-wave6.js（空弦·振剑·远山·鸣雷，32 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
跳过 SKIN 重复、空协战、重复 id、式神卡。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave6.js"

# (uid, role, name, title, archetype, color, strategy, subpack)
UNITS = [
    # 空弦绮话 kongxian
    ("jinnaluo", 256, "紧那罗", "箜篌", "运势 / 入夜", "#c0a0e0", "入夜叠运势，弦音随机投射收割。", "kongxian"),
    ("lingyanji", 263, "铃彦姬", "神火铃", "转生 / 火焰", "#f0a060", "气绝转神火铃焰，满血回身爆发。", "kongxian"),
    ("rurineque", 257, "入内雀", "雀巢", "入夜 / 护甲", "#80c0a0", "入夜叠甲，雀影反打与复活续航。", "kongxian"),
    ("shouwu", 260, "首无", "飞颅", "直击 / 入夜", "#e08090", "打脸触发随机补刀，提首直击终结。", "kongxian"),
    ("gunvhongye", 259, "鬼女红叶", "红枫", "娃娃 / 投射", "#f09080", "红枫娃娃标记，入夜投射连环爆。", "kongxian"),
    ("choushizhinv", 258, "丑时之女", "草人", "召唤 / 咒缚", "#c0a090", "草人召唤叠入夜，咒锥咒火清场。", "kongxian"),
    ("yifanmumian", 261, "一反木绵", "白绵", "复活 / 眩晕", "#a0b8e0", "气绝倒计时压缩，缠击眩晕控场。", "kongxian"),
    ("yecha", 262, "夜叉", "黄泉", "成长 / 击杀", "#c080e0", "入夜叠力量，击杀回血抽牌爆能。", "kongxian"),
    # 振剑归川 zhenjian
    ("huangchuanzhizhu", 271, "荒川之主", "归流", "连打 / 投射", "#70c0d0", "连出牌触发川浪，溯水归乡团辅。", "zhenjian"),
    ("wannianzhu", 268, "万年竹", "竹剑", "蓄力 / 成长", "#80c090", "蓄力牌叠力量，清风徐来连动。", "zhenjian"),
    ("shuzhu", 269, "数珠", "念珠", "蓄力 / 不屈", "#e0c080", "蓄力叠身材，心如磐石屏障反打。", "zhenjian"),
    ("sanweihu", 272, "三尾狐", "红焰", "成长 / 法强", "#f080b0", "等级增伤增攻，化形诱惑续航。", "zhenjian"),
    ("jicanghai", 264, "季沧海", "崩山", "蓄力 / 爆发", "#f0a050", "蓄力叠力量贯通，迅烈如火收割。", "zhenjian"),
    ("wuchen", 265, "无尘", "振刀", "蓄力 / 位移", "#90a0e0", "移动回备瞬发，两仪剑阵点杀。", "zhenjian"),
    ("ninghongye", 266, "宁红夜", "赤练", "蓄力 / 眩晕", "#e070a0", "蓄力牌投射眩晕，赤练无明控场。", "zhenjian"),
    ("tayumenhutao", 267, "土御门胡桃", "阴阳", "复活 / 运势", "#a0a0e0", "气绝倒计时压缩，净天地团辅。", "zhenjian"),
    # 远山遥泽 yuanshan
    ("baize", 273, "白泽", "达知", "占卜 / 过牌", "#a0d0b0", "达知洗库占卜，溯世命复活调度。", "yuanshan"),
    ("hudiejing", 274, "蝴蝶精", "蝶舞", "战技 / 迅捷", "#e0a0f0", "战技瞬发连打，一夜梦复活突击。", "yuanshan"),
    ("luoxinfu", 275, "络新妇", "蛛网", "印记 / 消灭", "#d080c0", "蜘蛛印记压制，诛灭点杀。", "yuanshan"),
    ("yitiao", 276, "一条", "勤勉", "战技 / 叠层", "#d0b880", "勤勉修行叠层，架势切换攻守。", "yuanshan"),
    ("jialouluo", 277, "迦楼罗", "化生", "倒计时 / 追猎", "#f0d060", "倒计时迅捷昂扬，惜羽追猎压制。", "yuanshan"),
    ("huajing", 278, "化鲸", "齿甲", "充能 / 爆能", "#80c0e0", "齿甲体甲结附，爆能召唤守护。", "yuanshan"),
    ("yinge", 279, "影鳄", "鬼鳄", "结附 / 成长", "#70b090", "鬼鳄永久成长，伏猎啖噬强化。", "yuanshan"),
    ("bujianyue", 280, "不见岳", "古山", "幻境 / 消灭", "#a0b0c0", "幻境进场自灭触发，峰回路转复场。", "yuanshan"),
    # 鸣雷启蛰 minglei
    ("xuzuozhinan", 281, "须佐之男", "天雷", "贯通 / 雷冢", "#d0a0f0", "击杀变雷冢，天雷万象自动攻。", "minglei"),
    ("liyujing", 282, "鲤鱼精", "泡泡", "加护 / 团辅", "#80d0e0", "加护叠手牌资源，水镜红锦循环。", "minglei"),
    ("chongshi", 283, "虫师", "虫群", "剧毒 / 削攻", "#a0c060", "中毒削力，剧毒斩杀回复。", "minglei"),
    ("xieenv", 284, "蝎女", "剧毒", "剧毒 / 护甲", "#e07080", "攻击叠剧毒，生杀予夺转甲。", "minglei"),
    ("xunxiangxing", 288, "寻香行", "蚀印", "蚀印 / 投射", "#e0b080", "蚀印压制手牌，缚梦明香锁场。", "minglei"),
    ("linghaidie", 287, "灵海蝶", "海灵", "结附 / 移动", "#80c0f0", "海灵结附触发，海心落团辅。", "minglei"),
    ("yujuchong", 285, "於菊虫", "毒丝", "剧毒 / 倒计时", "#e0c060", "中毒气绝打脸，破茧投射收割。", "minglei"),
    ("hainren", 286, "海忍", "潜影", "剧毒 / 免伤", "#8090c0", "毒目标免战伤，影逝花杀连击。", "minglei"),
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
# 简化原则同 wave3；officialText 保留原文。starter 合计=8，SSR starter=0，觉醒恰好 1 张。
CARD_MAP: dict[int, dict] = {
    # ---- 紧那罗 256 ----
    25601: C("序·无月夜", "spell", 1, 0, "R", 1,
             "瞬发。入夜 1，占卜 1 并抽一张牌（增强简化）。",
             [("always", "divination", "ally-player", 1), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "入夜", "占卜"]),
    25602: C("宫·寂庭", "form", 1, 1, "R", 1,
             "获得 +2/+3。敌方攻击后，降低其 1 点力量（运势简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="完成交战后，随机敌方 -1 力量（运势简化）。",
             formHooks=[{"id": "form-jinnaluo-court", "event": "combat-resolved", "effect": "passive-armor-break-enemy-on-damage", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "运势", "入夜"]),
    25603: C("商·渺影", "spell", 1, 1, "SR", 1,
             "投射：造成 3 点伤害，并对敌方牌手造成 2 点伤害（运势合并）。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "damage", "enemy-avatar", 2)],
             tags=["投射", "伤害", "运势"]),
    25604: C("角·骤声", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 5 点伤害，并对敌方前线造成 1 点伤害。",
             [("always", "damage", "selected-enemy", 5), ("always", "damage-enemy-front", "auto", 1)],
             tags=["伤害", "运势"]),
    25605: C("徽·诡间", "form", 2, 1, "SR", 1,
             "获得 +3/+3。己方回合开始时，对敌方前线造成 2 点伤害（召唤缚偶简化）。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，投射：造成 2 点伤害。",
             formHooks=[{"id": "form-jinnaluo-sigil", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "运势", "入夜"]),
    25606: C("羽·幽所", "form", 2, 1, "R", 2,
             "获得 +2/+4。己方回合开始时，抽一张牌（运势简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-jinnaluo-wing", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "过牌", "运势"]),
    25607: C("觉醒·紧那罗", "awakening", 3, 1, "SR", 1,
             "抽两张牌。觉醒：+1/+2，运势入夜改为随机造成 3 点伤害。",
             [("always", "awaken", "source", F(1, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "运势", "入夜"]),
    25608: C("终·不归途", "spell", 3, 2, "SSR", 0,
             "消灭一个敌方式神（力量或生命≤入夜值简化），并使其气绝倒计时 +1。",
             [("always", "damage", "selected-enemy", 8)],
             deck_limit=2, tags=["消灭", "入夜", "终结"]),

    # ---- 入内雀 257 ----
    25701: C("雀啄", "spell", 1, 1, "R", 2,
             "对一个敌方式神造成 3 点伤害，并为入内雀恢复 3 点生命。",
             [("always", "damage", "selected-enemy", 3), ("always", "heal", "source", 3)],
             tags=["伤害", "治疗", "入夜"]),
    25702: C("雀群无声", "form", 1, 1, "R", 1,
             "获得 +2/+4。气绝时，投射：造成 3 点伤害（入夜值简化）。",
             [("always", "form", "source", F(2, 4)), ("always", "damage-enemy-front", "auto", 3)],
             tags=["形态", "投射", "入夜"]),
    25703: C("朝雀鸣晨", "combat", 2, 1, "SR", 1,
             "出击 +2。气绝时可用：复活入内雀并获得 2 点护甲。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
             tags=["出击", "复活", "入夜"]),
    25704: C("庭院幽寂", "form", 2, 1, "SR", 1,
             "获得 +3/+5。受到伤害后，攻击者 -2 力量（入夜简化）。",
             [("always", "form", "source", F(3, 5))],
             formAbility="受到伤害后，随机敌方 -2 力量。",
             formHooks=[{"id": "form-rurineque-court", "event": "unit-damaged", "effect": "passive-armor-break-enemy-on-damage", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "入夜", "压制"]),
    25705: C("收割", "combat", 2, 1, "R", 1,
             "出击 +3。入夜 7 简化：对敌方所有式神造成 1 点伤害。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "all-enemy-units", 1)],
             tags=["出击", "群伤", "入夜"]),
    25706: C("觉醒·入内雀", "awakening", 2, 1, "SR", 1,
             "入夜 5 简化：获得 3 点护甲。觉醒：+1/+3，回合开始获得 2 点护甲。",
             [("always", "awaken", "source", F(1, 3)), ("always", "shield", "source", 3)],
             deck_limit=1, tags=["觉醒", "入夜", "护甲"]),
    25707: C("腐化之羽", "form", 3, 1, "R", 1,
             "获得 +4/+4（替身增强简化并入面板）。",
             [("always", "form", "source", F(4, 4))],
             tags=["形态", "入夜", "替身"]),
    25708: C("夜雀长栖", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，为所有己方式神恢复 2 点生命并获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "入夜", "团辅"]),

    # ---- 丑时之女 258 ----
    25801: C("怨缚草人", "spell", 1, 1, "R", 2,
             "对一个敌方式神造成 3 点伤害，并召唤怨缚草人（简化为伤害+自身强化）。",
             [("always", "damage", "selected-enemy", 3), ("always", "buff-stats", "source", F(1, 1))],
             tags=["召唤", "咒缚", "入夜"]),
    25802: C("咒锥", "spell", 1, 0, "R", 1,
             "瞬发。对敌方前线造成 3 点伤害，抽一张牌。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT"], tags=["瞬发", "伤害", "入夜"]),
    25803: C("制偶之女", "form", 1, 1, "SR", 1,
             "获得 +2/+4。己方回合结束时，所有己方式神获得 1 点生命（召唤物简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
             formHooks=[{"id": "form-choushi-doll", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "召唤", "治疗"]),
    25804: C("咒火", "spell", 3, 2, "R", 0,
             "对己方战斗区和所有敌方式神各造成 3 点伤害。",
             [("always", "damage", "source", 3), ("always", "damage", "all-enemy-units", 3)],
             tags=["群伤", "自伤", "入夜"]),
    25805: C("缚偶之师", "form", 2, 1, "SR", 1,
             "获得 +3/+3。己方回合开始时，对敌方前线造成 2 点伤害（召唤草人简化）。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-choushi-master", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "召唤", "入夜"]),
    25806: C("诅咒草人", "spell", 2, 1, "SR", 1,
             "对一个敌方式神造成 4 点伤害，并使其获得 2 点破甲。",
             [("always", "damage", "selected-enemy", 4), ("always", "apply-armor-break", "selected-enemy", 2)],
             tags=["召唤", "破甲", "入夜"]),
    25807: C("替身草人", "spell", 2, 1, "R", 1,
             "使一个己方其他式神获得 3 点护甲，并恢复 3 点生命。",
             [("always", "shield", "selected-ally", 3), ("always", "heal", "selected-ally", 3)],
             tags=["召唤", "护甲", "入夜"]),
    25808: C("觉醒·丑时之女", "awakening", 3, 1, "SR", 1,
             "对一个敌方式神造成 5 点伤害。觉醒：+2/+2，召唤进场改为对敌方前线 3 点伤害。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "selected-enemy", 5)],
             deck_limit=1, tags=["觉醒", "召唤", "入夜"]),

    # ---- 鬼女红叶 259 ----
    25901: C("爆炸之符", "spell", 1, 1, "R", 2,
             "对一个式神造成 3 点伤害，并为其结附红枫娃娃（简化为破甲）。",
             [("always", "damage", "selected-enemy", 3), ("always", "apply-armor-break", "selected-enemy", 1)],
             tags=["伤害", "娃娃", "入夜"]),
    25902: C("爆炸之咒", "spell", 1, 1, "R", 1,
             "对一个式神造成 4 点伤害（入夜值X简化）。",
             [("always", "damage", "selected-enemy", 4)],
             tags=["伤害", "娃娃", "入夜"]),
    25903: C("血枫之姬", "form", 1, 1, "SR", 1,
             "获得 +1/+5。完成交战后，使目标获得 1 点破甲（娃娃简化）。",
             [("always", "form", "source", F(1, 5))],
             formAbility="完成交战后，使交战目标获得 1 点破甲。",
             formHooks=[{"id": "form-gunv-blood", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "娃娃", "入夜"]),
    25904: C("跹舞之姿", "form", 2, 1, "R", 1,
             "获得 +3/+4。己方回合开始时，随机对敌方造成 1 点伤害（入夜增伤简化）。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-gunv-dance", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "入夜", "投射"]),
    25905: C("散逸之枫", "spell", 2, 0, "SR", 1,
             "瞬发。对一个式神造成 3 点伤害，并对敌方所有角色造成 1 点伤害。",
             [("always", "damage", "selected-enemy", 3), ("always", "damage", "enemy-avatar", 1), ("always", "damage", "all-enemy-units", 1)],
             keywords=["INSTANT"], tags=["瞬发", "娃娃", "群伤"]),
    25906: C("死亡之舞", "spell", 3, 1, "R", 1,
             "瞬发。对所有敌方式神造成 2 点伤害并各获得 1 点破甲。",
             [("always", "damage", "all-enemy-units", 2), ("always", "apply-armor-break", "all-enemy-units", 1)],
             keywords=["INSTANT"], tags=["瞬发", "娃娃", "群伤"]),
    25907: C("枫飞舞裂", "form", 2, 1, "SSR", 0,
             "获得 +3/+5。己方回合开始时，对敌方牌手造成 2 点伤害（娃娃爆发简化）。",
             [("always", "form", "source", F(3, 5))],
             formAbility="己方回合开始时，对敌方牌手造成 2 点伤害。",
             formHooks=[{"id": "form-gunv-burst", "event": "turn-started", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 2}, "priority": 40}],
             deck_limit=2, tags=["形态", "娃娃", "终结"]),
    25908: C("觉醒·鬼女红叶", "awakening", 3, 1, "R", 1,
             "对敌方前线造成 5 点伤害。觉醒：+2/+2，回合结束投射 3 点（入夜10简化）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 5)],
             deck_limit=1, tags=["觉醒", "娃娃", "入夜"]),

    # ---- 首无 260 ----
    26001: C("迅影强袭", "combat", 1, 1, "R", 1,
             "出击 +3。若目标生命≤2，本次攻击获得暴击（入夜简化）。",
             [("source-ready", "assault", "source", 3)],
             keywords=["CRIT"], tags=["出击", "暴击", "入夜"]),
    26002: C("飞颅谑戏", "spell", 1, 0, "R", 2,
             "瞬发。投射：造成 1 点伤害，并抽一张牌。",
             [("always", "damage-enemy-front", "auto", 1), ("always", "draw", "ally-player", 1)],
             keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射", "过牌", "入夜"]),
    26003: C("身首分离", "combat", 1, 1, "SR", 1,
             "出击 +2，并对敌方牌手造成 2 点伤害。响应：被攻击时自动使用。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "enemy-avatar", 2)],
             keywords=["RESPONSE", "UNYIELDING"], timing="response", responseTo=["assault"],
             tags=["响应", "不屈", "直击", "入夜"]),
    26004: C("恐吓重击", "combat", 2, 1, "R", 1,
             "出击 +4（入夜增强简化并入卡面）。",
             [("source-ready", "assault", "source", 4)],
             tags=["出击", "增强", "入夜"]),
    26005: C("提首行骸", "form", 2, 1, "SR", 1,
             "获得 +2/+5。迅捷。完成交战后，对敌方牌手造成 1 点伤害（直击简化）。",
             [("always", "form", "source", F(2, 5))],
             keywords=["INSTANT"],
             formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
             formHooks=[{"id": "form-shouwu-carry", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "迅捷", "直击", "入夜"]),
    26006: C("觉醒·首无", "awakening", 2, 1, "SR", 1,
             "对敌方牌手造成 3 点伤害。觉醒：+2/+1，打脸后随机对式神造成 2 点伤害。",
             [("always", "awaken", "source", F(2, 1)), ("always", "damage", "enemy-avatar", 3)],
             deck_limit=1, tags=["觉醒", "入夜", "直击"]),
    26007: C("虚无冥火", "realm", 3, 1, "R", 1,
             "幻境（耐久 6）：己方回合开始时，随机对一个敌方式神造成 2 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "入夜", "伤害"]),
    26008: C("神出鬼没", "combat", 3, 2, "SSR", 0,
             "出击 +5，并获得 1 点护甲（不耗火与任意目标简化）。",
             [("source-ready", "assault", "source", 5), ("always", "shield", "source", 1)],
             deck_limit=2, tags=["出击", "入夜", "终结"]),

    # ---- 一反木绵 261 ----
    26101: C("缠击", "combat", 1, 1, "R", 1,
             "出击 +2。眩晕被攻击的式神（入夜简化）。",
             [("source-ready", "assault", "source", 2), ("always", "freeze", "selected-enemy", 1)],
             keywords=["STUN"], tags=["出击", "眩晕", "入夜"]),
    26102: C("残温", "spell", 1, 1, "R", 2,
             "为一个角色恢复 5 点生命（入夜值X简化）。",
             [("always", "heal", "selected-ally", 5)],
             tags=["治疗", "入夜"]),
    26103: C("幽缠惘惧", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，随机眩晕一个敌方式神（入夜简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             keywords=["STUN"], tags=["幻境", "眩晕", "入夜"]),
    26104: C("雪织", "spell", 2, 1, "SR", 1,
             "复活一个己方式神。气绝时可用。眩晕敌方战斗区式神（入夜简化）。",
             [("always", "revive", "knocked-ally", 1), ("always", "freeze", "all-enemy-units", 1)],
             keywords=["STUN", "RESPONSE"], timing="response", responseTo=["damage"],
             tags=["复活", "眩晕", "入夜"]),
    26105: C("悄言絮语", "spell", 2, 1, "R", 1,
             "抽两张牌，并获得 1 点鬼火（入夜检索简化）。",
             [("always", "draw", "ally-player", 2), ("always", "energy-gain", "ally-player", 1)],
             tags=["过牌", "入夜", "瞬发"]),
    26106: C("雪夜亡魂", "form", 2, 1, "R", 1,
             "获得 +2/+4。气绝时可用：复活一反木绵（简化并入形态）。",
             [("always", "form", "source", F(2, 4)), ("always", "revive", "source", 1)],
             tags=["形态", "复活", "入夜"]),
    26107: C("觉醒·一反木绵", "awakening", 3, 1, "SR", 1,
             "为你恢复 5 点生命。觉醒：+2/+3，气绝时己方倒计时 -1（入夜简化）。",
             [("always", "awaken", "source", F(2, 3)), ("always", "heal-avatar", "ally-avatar", 5)],
             deck_limit=1, tags=["觉醒", "复活", "入夜"]),
    26108: C("绯夜散华", "combat", 3, 2, "SSR", 0,
             "出击 +4。眩晕一个敌方式神，并获得 1 点护甲。",
             [("source-ready", "assault", "source", 4), ("always", "freeze", "selected-enemy", 1), ("always", "shield", "source", 1)],
             keywords=["STUN"], deck_limit=2, tags=["出击", "眩晕", "入夜"]),

    # ---- 夜叉 262 ----
    26201: C("屠戮", "combat", 1, 1, "R", 2,
             "出击 +3。击杀后，为夜叉恢复 3 点生命（入夜简化）。",
             [("source-ready", "assault", "source", 3), ("always", "heal", "source", 3)],
             tags=["出击", "击杀", "入夜"]),
    26202: C("修罗", "form", 1, 1, "R", 1,
             "获得 +3/+4。贯通。进场获得 1 点力量（追猎简化）。",
             [("always", "form", "source", F(3, 4)), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["PIERCE"], tags=["形态", "贯通", "入夜"]),
    26203: C("黄泉之海", "realm", 1, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害（倒计时+1简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "入夜", "控制"]),
    26204: C("觉醒·夜叉", "awakening", 2, 1, "SR", 1,
             "获得 2 点力量。觉醒：+1/+2，入夜时叠力量（简化为回合开始叠力量）。",
             [("always", "awaken", "source", F(1, 2)), ("always", "buff-stats", "source", F(2, 0))],
             deck_limit=1, tags=["觉醒", "成长", "入夜"]),
    26205: C("恶鬼", "form", 2, 1, "R", 1,
             "获得 +3/+5。进场获得 3 点护甲（屏障简化）。",
             [("always", "form", "source", F(3, 5)), ("always", "shield", "source", 3)],
             tags=["形态", "护甲", "入夜"]),
    26206: C("劫掠", "combat", 2, 1, "R", 1,
             "出击 +2。击杀后，抽两张牌（入夜简化）。",
             [("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 2)],
             tags=["出击", "过牌", "入夜"]),
    26207: C("比良坂之刹", "form", 3, 2, "SSR", 0,
             "获得 +4/+5。气绝时可用：复活夜叉。进场获得 3 点护甲。",
             [("always", "form", "source", F(4, 5)), ("always", "shield", "source", 3), ("always", "revive", "source", 1)],
             deck_limit=2, tags=["形态", "复活", "入夜"]),
    26208: C("鬼魅", "combat", 3, 1, "R", 1,
             "出击 +4。击杀后，获得 1 点鬼火（入夜简化）。",
             [("source-ready", "assault", "source", 4), ("always", "energy-gain", "ally-player", 1)],
             tags=["出击", "鬼火", "入夜"]),

    # ---- 铃彦姬 263 ----
    26301: C("振铃", "combat", 1, 1, "SR", 1,
             "出击 +2。攻击后，为自己恢复 3 点生命。",
             [("source-ready", "assault", "source", 2), ("always", "heal", "source", 3)],
             tags=["出击", "治疗", "神火"]),
    26302: C("摇曳星火", "realm", 1, 1, "R", 2,
             "幻境（耐久 5）：己方回合开始时，为所有己方角色恢复 1 点生命（护甲简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "治疗", "神火"]),
    26303: C("舞刃", "combat", 1, 0, "R", 1,
             "瞬发，追猎。出击 +1。",
             [("source-ready", "assault", "source", 1)],
             keywords=["INSTANT"], tags=["瞬发", "追猎", "神火"]),
    26304: C("炽火燎原", "realm", 2, 1, "SR", 1,
             "幻境（耐久 5）：进场对敌方前线造成 4 点伤害，铃彦姬也受到 4 点伤害（进场简化为持续压血）。",
             [("always", "damage", "source", 4), ("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 3},
             tags=["幻境", "自伤", "神火"]),
    26305: C("觉醒·铃彦姬", "awakening", 2, 1, "SR", 1,
             "永久 +2 力量，并为自己恢复 3 点生命。觉醒：+1/+3，气绝转神火铃焰（简化为不屈反击）。",
             [("always", "awaken", "source", F(1, 3)), ("always", "buff-stats", "source", F(2, 0)), ("always", "heal", "source", 3)],
             deck_limit=1, tags=["觉醒", "神火", "转生"]),
    26306: C("浴火重生", "combat", 2, 1, "R", 1,
             "出击 +2。本次战斗伤害转为恢复（简化为获得 4 点护甲）。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 4)],
             keywords=["RESPONSE"], tags=["出击", "回复", "神火"]),
    26307: C("余焰尤燃", "spell", 3, 0, "R", 1,
             "瞬发。恢复一个角色 5 点生命。",
             [("always", "heal", "selected-ally", 5)],
             keywords=["INSTANT"], tags=["瞬发", "治疗", "神火"]),
    26308: C("不灭之焰", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，为所有己方式神恢复 2 点生命（神火攻击简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "神火", "终结"]),

    # ---- 季沧海 264 ----
    26401: C("崩山斩", "combat", 1, 1, "R", 2,
             "出击 +2。蓄力简化：获得 1 点力量与贯通。",
             [("source-ready", "assault", "source", 2), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["PIERCE", "CHARGED"], tags=["出击", "蓄力", "贯通"]),
    26402: C("旋风斩", "combat", 2, 1, "R", 1,
             "出击 +3。造成伤害后，对敌方牌手再造成 2 点伤害（一半伤害简化）。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 2)],
             tags=["出击", "蓄力", "连击"]),
    26403: C("燎原劲", "spell", 1, 1, "SR", 1,
             "投射：造成等同于自身力量的伤害（简化 4 点），并获得 3 点护甲。",
             [("always", "damage-enemy-front", "auto", 4), ("always", "shield", "source", 3)],
             keywords=["PROJECTILE", "RESPONSE", "CHARGED"], timing="response", responseTo=["assault"],
             tags=["响应", "蓄力", "护甲"]),
    26404: C("蓄力·振刀", "combat", 1, 0, "R", 1,
             "出击 +1。蓄力简化：抽一张牌。",
             [("source-ready", "assault", "source", 1), ("always", "draw", "ally-player", 1)],
             keywords=["CHARGED"], tags=["出击", "蓄力", "过牌"]),
    26405: C("磐石架势", "form", 2, 1, "R", 1,
             "获得 +3/+5。完成交战后，获得 2 点护甲（减伤简化）。",
             [("always", "form", "source", F(3, 5))],
             formAbility="完成交战后，季沧海获得 2 点护甲。",
             formHooks=[{"id": "form-jicanghai-rock", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "蓄力", "护甲"]),
    26406: C("觉醒·季沧海", "awakening", 2, 1, "SR", 1,
             "获得 3 点力量。觉醒：+1/+2，蓄力力量加成翻倍（简化为面板）。",
             [("always", "awaken", "source", F(1, 2)), ("always", "buff-stats", "source", F(3, 0))],
             deck_limit=1, tags=["觉醒", "蓄力", "成长"]),
    26407: C("狂潮", "combat", 3, 1, "R", 1,
             "出击 +3，并获得 2 点护甲（免疫与连用简化）。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
             tags=["出击", "蓄力", "连击"]),
    26408: C("迅烈如火", "form", 3, 2, "SSR", 0,
             "获得 +4/+5。迅捷。己方回合开始时，获得 1 点力量。",
             [("always", "form", "source", F(4, 5))],
             keywords=["INSTANT"],
             formAbility="己方回合开始时，季沧海获得 1 点力量。",
             formHooks=[{"id": "form-jicanghai-fire", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             deck_limit=2, tags=["形态", "蓄力", "终结"]),

    # ---- 无尘 265 ----
    26501: C("鬼返断", "combat", 1, 1, "R", 1,
             "出击 +3。蓄力简化：直击（对牌手额外 1 点）。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 1)],
             keywords=["CHARGED"], tags=["出击", "蓄力", "直击"]),
    26502: C("闪步·振刀", "spell", 1, 1, "SR", 1,
             "抽一张牌。移动无尘简化：获得 1 点护甲，并使敌方前线 -2 力量。",
             [("always", "draw", "ally-player", 1), ("always", "shield", "source", 1), ("always", "debuff-stats", "auto", {"attack": 2, "hp": 0})],
             tags=["移动", "蓄力", "过牌"]),
    26503: C("飞索突袭", "combat", 1, 0, "R", 2,
             "出击 +1。追猎。蓄力简化：抽一张牌。",
             [("source-ready", "assault", "source", 1), ("always", "draw", "ally-player", 1)],
             tags=["出击", "追猎", "蓄力"]),
    26504: C("斗转星移", "combat", 2, 1, "R", 1,
             "出击 +2。攻击后回到准备区简化：获得 3 点护甲。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 3)],
             tags=["出击", "移动", "蓄力"]),
    26505: C("卸劲", "form", 2, 1, "R", 1,
             "获得 +3/+3。受到伤害后，获得 2 点护甲（防伤移动简化）。",
             [("always", "form", "source", F(3, 3))],
             formAbility="受到伤害后，获得 2 点护甲。",
             formHooks=[{"id": "form-wuchen-soft", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "移动", "蓄力"]),
    26506: C("豫让三伏", "combat", 2, 1, "SR", 1,
             "出击 +3。连击。蓄力简化：获得 1 点力量。",
             [("source-ready", "assault", "source", 3), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["COMBO"], tags=["出击", "连击", "蓄力"]),
    26507: C("觉醒·无尘", "awakening", 2, 1, "SR", 1,
             "抽两张牌。觉醒：+2/+2，移动后下一张牌瞬发（简化为立即过牌）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "移动", "蓄力"]),
    26508: C("两仪剑阵", "form", 3, 2, "SSR", 0,
             "获得 +4/+5。迅捷。己方回合开始时，对敌方前线造成 3 点伤害（剑阵简化）。",
             [("always", "form", "source", F(4, 5))],
             keywords=["INSTANT"],
             formAbility="己方回合开始时，对敌方前线造成 3 点伤害。",
             formHooks=[{"id": "form-wuchen-array", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
             deck_limit=2, tags=["形态", "蓄力", "终结"]),

    # ---- 宁红夜 266 ----
    26601: C("锁羚羊", "form", 1, 1, "R", 1,
             "获得 +2/+4。非战斗伤害后，目标下回合不能出击简化为 -2 力量。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，随机敌方 -1 力量。",
             formHooks=[{"id": "form-ning-lock", "event": "turn-started", "effect": "passive-armor-break-enemy-front", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "蓄力", "压制"]),
    26602: C("蓄力射击", "spell", 1, 1, "R", 2,
             "对一个式神造成 5 点伤害（蓄力+2 简化并入）。",
             [("always", "damage", "selected-enemy", 5)],
             keywords=["CHARGED"], tags=["伤害", "蓄力"]),
    26603: C("爆裂箭", "combat", 1, 1, "R", 1,
             "出击 +1。远程。对敌方所有准备区式神造成 1 点伤害简化为全体 1 点。",
             [("source-ready", "assault", "source", 1), ("always", "damage", "all-enemy-units", 1)],
             keywords=["REMOTE", "CHARGED"], tags=["出击", "远程", "蓄力"]),
    26604: C("昆仑决", "spell", 2, 0, "SR", 1,
             "瞬发。眩晕一个式神，并使其 -3 力量（移除蓄力简化）。",
             [("always", "freeze", "selected-enemy", 1), ("always", "debuff-stats", "selected-enemy", {"attack": 3, "hp": 0})],
             keywords=["INSTANT", "STUN"], tags=["瞬发", "眩晕", "蓄力"]),
    26605: C("散射", "spell", 2, 1, "R", 1,
             "对一个式神和敌方前线各造成 4 点伤害。",
             [("always", "damage", "selected-enemy", 4), ("always", "damage-enemy-front", "auto", 4)],
             keywords=["CHARGED"], tags=["伤害", "蓄力", "散射"]),
    26606: C("凤凰羽", "form", 2, 1, "SR", 1,
             "获得 +2/+4。迅捷。完成交战后，对敌方牌手造成 1 点伤害。",
             [("always", "form", "source", F(2, 4))],
             keywords=["INSTANT"],
             formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
             formHooks=[{"id": "form-ning-phoenix", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "迅捷", "蓄力"]),
    26607: C("觉醒·宁红夜", "awakening", 2, 1, "SR", 1,
             "对敌方前线造成 3 点伤害并眩晕。觉醒：+2/+2，蓄力使用牌投射 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3), ("always", "freeze", "all-enemy-units", 1)],
             keywords=["STUN"], deck_limit=1, tags=["觉醒", "蓄力", "眩晕"]),
    26608: C("赤练无明", "spell", 3, 2, "SSR", 0,
             "眩晕所有敌方式神，并对每个造成 2 点伤害。",
             [("always", "freeze", "all-enemy-units", 1), ("always", "damage", "all-enemy-units", 2)],
             keywords=["STUN", "CHARGED"], deck_limit=2, tags=["眩晕", "蓄力", "终结"]),

    # ---- 土御门胡桃 267 ----
    26701: C("庇护", "form", 1, 1, "R", 1,
             "获得 +2/+5。己方回合开始时，为一个己方其他式神恢复 3 点生命。",
             [("always", "form", "source", F(2, 5))],
             formAbility="己方回合开始时，为随机己方其他式神恢复 3 点生命。",
             formHooks=[{"id": "form-tayu-protect", "event": "turn-started", "effect": "passive-heal-ally-if-front-or-any", "params": {"amount": 3}, "priority": 40}],
             tags=["形态", "治疗", "气绝"]),
    26702: C("任务·追击", "spell", 1, 1, "R", 2,
             "抽两张牌，并获得 1 点护甲（标记简化）。",
             [("always", "draw", "ally-player", 2), ("always", "shield", "source", 1)],
             tags=["过牌", "任务", "气绝"]),
    26703: C("身势·振刀", "form", 2, 1, "SR", 1,
             "获得 +3/+5。完成交战后，对敌方前线造成 3 点伤害（运势简化）。",
             [("always", "form", "source", F(3, 5))],
             formAbility="完成交战后，对敌方前线造成 3 点伤害。",
             formHooks=[{"id": "form-tayu-stance", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 3}, "priority": 40}],
             tags=["形态", "运势", "蓄力"]),
    26704: C("落物堆", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，抽一张牌（落物简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "过牌", "落物"]),
    26705: C("净天地", "realm", 2, 1, "SR", 1,
             "幻境（耐久 8）：己方回合开始时，所有己方式神获得 2 点护甲（过量治疗转甲简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             tags=["幻境", "团辅", "气绝"]),
    26706: C("地煞符", "realm", 2, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 4 点伤害。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 4},
             tags=["幻境", "伤害", "气绝"]),
    26707: C("觉醒·土御门胡桃", "awakening", 2, 1, "SR", 1,
             "复活一个己方气绝式神。觉醒：+2/+3，攻击时若有人气绝则全体复活（简化为立即复活）。",
             [("always", "awaken", "source", F(2, 3)), ("always", "revive-all", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "复活", "气绝"]),
    26708: C("飓风客", "spell", 3, 2, "SSR", 0,
             "为所有己方式神恢复 3 点生命，并各获得 2 点护甲（飓风物品简化）。",
             [("always", "heal", "all-ally-units", 3), ("always", "shield", "all-ally-units", 2)],
             deck_limit=2, tags=["团辅", "落物", "终结"]),

    # ---- 万年竹 268 ----
    26801: C("竹语", "spell", 1, 1, "R", 1,
             "使一个式神获得 2 点力量，并抽一张牌。",
             [("always", "buff-stats", "selected-ally", F(2, 0)), ("always", "draw", "ally-player", 1)],
             tags=["强化", "蓄力", "过牌"]),
    26802: C("笛中剑", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害（每蓄力+1 简化）。",
             [("always", "damage", "selected-enemy", 3)],
             keywords=["FIRST_STRIKE", "CHARGED"], tags=["伤害", "蓄力", "先攻"]),
    26803: C("林中秘宝", "form", 2, 1, "SR", 1,
             "获得 +3/+4。己方回合开始时，将一张「清风徐来」简化为抽一张牌。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-wannian-grove", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "蓄力", "复制"]),
    26804: C("竹叶守护", "form", 2, 1, "R", 1,
             "获得 +2/+5。己方其他式神气绝时，对敌方前线造成 4 点伤害。",
             [("always", "form", "source", F(2, 5))],
             formAbility="其他式神气绝时，对敌方前线造成 4 点伤害。",
             formHooks=[{"id": "form-wannian-leaf", "event": "unit-knocked-out", "effect": "passive-damage-enemy-front", "params": {"amount": 4}, "priority": 40}],
             tags=["形态", "蓄力", "守护"]),
    26805: C("茂林深篁", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：进场为所有己方式神恢复 2 点生命；回合开始获得 1 点护甲。",
             [("always", "heal", "all-ally-units", 2), ("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "蓄力", "团辅"]),
    26806: C("清风徐来", "spell", 2, 0, "R", 1,
             "瞬发。使一个己方式神获得 1 点力量与 1 点护甲（打出蓄力牌简化）。",
             [("always", "buff-stats", "selected-ally", F(1, 1))],
             keywords=["INSTANT"], tags=["瞬发", "蓄力", "连动"]),
    26807: C("万变竹影", "spell", 3, 1, "SR", 1,
             "所有己方式神获得 +1/+1，并抽一张牌（蓄力复制简化）。",
             [("always", "buff-stats", "all-ally-units", F(1, 1)), ("always", "draw", "ally-player", 1)],
             tags=["团辅", "蓄力", "过牌"]),
    26808: C("觉醒·万年竹", "awakening", 2, 1, "R", 1,
             "抽两张牌。觉醒：+2/+2，使用已蓄力牌获得力量并抽牌（简化为回合开始叠力量）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2)],
             deck_limit=1, tags=["觉醒", "蓄力", "成长"]),

    # ---- 数珠 269 ----
    26901: C("坐禅", "spell", 1, 1, "R", 2,
             "为数珠和你恢复 3 点生命。",
             [("always", "heal", "source", 3), ("always", "heal-avatar", "ally-avatar", 3)],
             tags=["治疗", "蓄力"]),
    26902: C("降魔杖", "combat", 1, 0, "R", 1,
             "出击 +2。蓄力简化：抽一张「降魔杖」——改为抽一张牌。",
             [("source-ready", "assault", "source", 2), ("always", "draw", "ally-player", 1)],
             keywords=["CHARGED"], tags=["出击", "蓄力", "过牌"]),
    26903: C("伏虎之姿", "form", 1, 1, "R", 1,
             "获得 +2/+4。蓄力简化：追猎——出击后获得 1 点力量。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，数珠获得 1 点力量。",
             formHooks=[{"id": "form-shuzhu-tiger", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "蓄力", "追猎"]),
    26904: C("心如磐石", "combat", 1, 1, "SR", 1,
             "出击 +1。获得 3 点护甲。响应：被攻击时自动使用。",
             [("source-ready", "assault", "source", 1), ("always", "shield", "source", 3)],
             keywords=["RESPONSE", "CHARGED"], timing="response", responseTo=["assault"],
             tags=["响应", "蓄力", "屏障"]),
    26905: C("不二法门", "combat", 2, 1, "R", 1,
             "出击 +4。蓄力简化：消灭敌方战斗区式神——造成 6 点伤害。",
             [("source-ready", "assault", "source", 4), ("always", "damage-enemy-front", "auto", 6)],
             tags=["出击", "蓄力", "消灭"]),
    26906: C("降龙之势", "form", 3, 1, "SR", 1,
             "获得 +4/+4。迅捷。完成交战后获得 2 点护甲（昂扬简化）。",
             [("always", "form", "source", F(4, 4))],
             keywords=["INSTANT"],
             formAbility="完成交战后，获得 2 点护甲。",
             formHooks=[{"id": "form-shuzhu-dragon", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "蓄力", "昂扬"]),
    26907: C("觉醒·数珠", "awakening", 2, 1, "SR", 1,
             "获得 +2/+2 与 2 点护甲。气绝时可用：复活数珠。",
             [("always", "awaken", "source", F(2, 2)), ("always", "shield", "source", 2)],
             deck_limit=1, tags=["觉醒", "蓄力", "复活"]),
    26908: C("诸法空相", "form", 3, 2, "SSR", 0,
             "获得 +5/+5。气绝时可用：复活。完成交战后，恢复 4 点生命。",
             [("always", "form", "source", F(5, 5)), ("always", "revive", "source", 1)],
             formAbility="完成交战后，恢复 4 点生命。",
             formHooks=[{"id": "form-shuzhu-void", "event": "combat-resolved", "effect": "passive-heal-self-if-front", "params": {"amount": 4}, "priority": 40}],
             deck_limit=2, tags=["形态", "蓄力", "终结"]),

    # ---- 荒川之主 271 ----
    27101: C("归流", "spell", 1, 0, "R", 1,
             "获得 1 点鬼火。",
             [("always", "energy-gain", "ally-player", 1)],
             tags=["鬼火", "连打", "蓄力"]),
    27102: C("聚流", "spell", 1, 1, "R", 1,
             "投射：造成 2 点伤害。",
             [("always", "damage-enemy-front", "auto", 2)],
             keywords=["PROJECTILE", "CHARGED"], tags=["投射", "连打", "蓄力"]),
    27103: C("泱泱之川", "form", 1, 1, "R", 1,
             "获得 +2/+4。连出第二张牌后，召唤游鱼简化为对敌方前线 1 点伤害。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，对敌方前线造成 1 点伤害。",
             formHooks=[{"id": "form-huangchuan-flow", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "连打", "召唤"]),
    27104: C("激流", "spell", 2, 1, "R", 1,
             "对一个式神造成 5 点伤害（增强简化并入）。",
             [("always", "damage", "selected-enemy", 5)],
             tags=["伤害", "连打", "增强"]),
    27105: C("溯水归乡", "form", 2, 1, "SR", 1,
             "获得 +4/+3。己方回合开始时，为所有己方角色恢复 2 点生命。",
             [("always", "form", "source", F(4, 3))],
             formAbility="己方回合开始时，为所有己方式神恢复 2 点生命。",
             formHooks=[{"id": "form-huangchuan-home", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "连打", "团辅"]),
    27106: C("逐流", "form", 2, 1, "R", 1,
             "获得 +1/+3。占卜 2 并抽一张牌。",
             [("always", "form", "source", F(1, 3)), ("always", "divination", "ally-player", 2), ("always", "draw", "ally-player", 1)],
             tags=["形态", "连打", "占卜"]),
    27107: C("吞噬", "spell", 3, 1, "SR", 1,
             "眩晕一个敌方式神，并造成 5 点伤害（蓄力湮灭简化）。",
             [("always", "freeze", "selected-enemy", 1), ("always", "damage", "selected-enemy", 5)],
             keywords=["STUN", "CHARGED"], tags=["眩晕", "连打", "蓄力"]),
    27108: C("觉醒·荒川之主", "awakening", 2, 1, "SR", 1,
             "对敌方牌手造成 3 点伤害并眩晕。觉醒：+2/+2，第二张牌后打脸 2 点。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "enemy-avatar", 3), ("always", "freeze", "all-enemy-units", 1)],
             keywords=["STUN"], deck_limit=1, tags=["觉醒", "连打", "眩晕"]),

    # ---- 三尾狐 272 ----
    27201: C("红焰", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害（法强与等级简化）。",
             [("always", "damage", "selected-enemy", 4)],
             tags=["伤害", "成长"]),
    27202: C("尾袭", "combat", 1, 0, "R", 2,
             "出击 +2，并获得 1 点护甲。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 1)],
             tags=["出击", "成长", "增强"]),
    27203: C("化形", "spell", 1, 1, "R", 1,
             "抽一张牌，并获得 1 点鬼火（弃牌换牌简化）。",
             [("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
             tags=["过牌", "成长", "化形"]),
    27204: C("诱惑", "spell", 2, 1, "SR", 1,
             "对敌方牌手造成 3 点伤害，并为你恢复 3 点生命。",
             [("always", "damage", "enemy-avatar", 3), ("always", "heal-avatar", "ally-avatar", 3)],
             tags=["直击", "治疗", "成长"]),
    27205: C("溯水归乡", "form", 2, 1, "R", 1,
             "获得 +3/+4。己方回合开始时，随机对敌方造成 1 点伤害。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-sanwei-home", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "成长", "投射"]),
    27206: C("妩媚", "spell", 2, 1, "R", 1,
             "使己方所有式神获得 +1/+1（鼓舞/压制简化）。",
             [("always", "buff-stats", "all-ally-units", F(1, 1))],
             tags=["团辅", "成长", "鼓舞"]),
    27207: C("红颜怒发", "form", 3, 1, "SR", 1,
             "获得 +3/+4。己方回合开始时，抽一张牌并获得 1 点力量。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，抽一张牌并获得 1 点力量。",
             formHooks=[
                 {"id": "form-sanwei-anger-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-sanwei-anger-buff", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
             ],
             tags=["形态", "成长", "过牌"]),
    27208: C("觉醒·三尾狐", "awakening", 2, 1, "SSR", 0,
             "获得 3 点力量。觉醒：+2/+2，使用等级 1 牌投射 1 点（简化为回合开始投射）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "buff-stats", "source", F(3, 0))],
             deck_limit=2, tags=["觉醒", "成长", "投射"]),

    # ---- 白泽 273 ----
    27301: C("观史通今", "form", 1, 1, "R", 1,
             "获得 +2/+4。占卜时抽一张牌（达知简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-baize-history", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "占卜", "达知"]),
    27302: C("溯世命", "spell", 1, 1, "SR", 1,
             "复活一个己方式神，并占卜 2。气绝时可用。",
             [("always", "revive", "knocked-ally", 1), ("always", "divination", "ally-player", 2)],
             tags=["复活", "占卜", "达知"]),
    27303: C("晓万物", "spell", 2, 1, "R", 1,
             "对所有敌方式神造成 2 点伤害，并占卜 2。",
             [("always", "damage", "all-enemy-units", 2), ("always", "divination", "ally-player", 2)],
             tags=["群伤", "占卜", "达知"]),
    27304: C("驱邪祸", "spell", 1, 1, "R", 2,
             "投射：造成 3 点伤害并眩晕。战技简化。",
             [("always", "damage-enemy-front", "auto", 3), ("always", "freeze", "selected-enemy", 1)],
             keywords=["PROJECTILE", "STUN"], tags=["投射", "眩晕", "战技"]),
    27305: C("造化时流", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 5 点伤害。",
             [("always", "damage", "selected-enemy", 5)],
             tags=["伤害", "占卜", "达知"]),
    27306: C("觉醒·白泽", "awakening", 2, 1, "SR", 1,
             "占卜 3 并抽一张牌。觉醒：+2/+2，回合开始占卜 1。",
             [("always", "awaken", "source", F(2, 2)), ("always", "divination", "ally-player", 3), ("always", "draw", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "占卜", "达知"]),
    27307: C("迢迢尘间", "spell", 3, 2, "SSR", 0,
             "占卜 4，为你恢复 4 点生命，并抽两张牌。",
             [("always", "divination", "ally-player", 4), ("always", "heal-avatar", "ally-avatar", 4), ("always", "draw", "ally-player", 2)],
             deck_limit=2, tags=["占卜", "达知", "终结"]),
    27308: C("承因续果", "form", 3, 1, "SR", 1,
             "获得 +3/+4。占卜中出现式神牌简化：回合开始随机己方 +1/+1。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，随机己方其他式神 +1/+1。",
             formHooks=[{"id": "form-baize-cause", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 1, "hp": 1}, "priority": 40}],
             tags=["形态", "占卜", "达知"]),

    # ---- 蝴蝶精 274 ----
    27401: C("醉春风", "spell", 1, 1, "R", 2,
             "战技。使己方所有式神获得 +1 力量与 1 点护甲（鼓舞简化）。",
             [("always", "buff-stats", "all-ally-units", F(1, 0)), ("always", "shield", "all-ally-units", 1)],
             tags=["战技", "鼓舞", "团辅"]),
    27402: C("金缕歌", "spell", 1, 1, "R", 1,
             "战技。对一个敌方式神造成 2 点伤害，并使其 -2 力量（激怒简化）。",
             [("always", "damage", "selected-enemy", 2), ("always", "debuff-stats", "selected-enemy", {"attack": 2, "hp": 0})],
             tags=["战技", "伤害", "压制"]),
    27403: C("看花回", "form", 1, 1, "SR", 1,
             "获得 +2/+3。迅捷。完成交战后抽一张牌。",
             [("always", "form", "source", F(2, 3))],
             keywords=["INSTANT"],
             formAbility="完成交战后，抽一张牌。",
             formHooks=[{"id": "form-hudie-flower", "event": "combat-resolved", "effect": "passive-draw-self", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "迅捷", "战技"]),
    27404: C("一夜梦", "spell", 2, 1, "SR", 1,
             "战技。复活一个己方其他式神，并使其获得 +2 力量。",
             [("always", "revive", "knocked-ally", 1), ("always", "buff-stats", "all-other-allies", F(2, 0))],
             tags=["战技", "复活", "突击"]),
    27405: C("蝶恋花", "spell", 2, 1, "R", 1,
             "战技。将敌方前线移出战斗区简化：对其造成 4 点伤害并 -3 力量。",
             [("always", "damage-enemy-front", "auto", 4), ("always", "debuff-stats", "auto", {"attack": 3, "hp": 0})],
             tags=["战技", "移动", "压制"]),
    27406: C("觉醒·蝴蝶精", "awakening", 2, 1, "SR", 1,
             "抽两张牌。觉醒：+2/+2，出击后战技瞬发（简化为立即过牌）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2)],
             keywords=["REMOTE"], deck_limit=1, tags=["觉醒", "战技", "瞬发"]),
    27407: C("玲珑蝶影", "form", 3, 2, "SSR", 0,
             "获得 +3/+5。己方回合开始时，抽一张牌并获得 1 点力量。",
             [("always", "form", "source", F(3, 5))],
             formAbility="己方回合开始时，抽一张牌并获得 1 点力量。",
             formHooks=[
                 {"id": "form-hudie-ling-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                 {"id": "form-hudie-ling-buff", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "战技", "终结"]),
    27408: C("引驾行", "realm", 3, 1, "R", 1,
             "幻境（耐久 6）：己方回合开始时，抽一张牌（出击不耗火简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "战技", "过牌"]),

    # ---- 络新妇 275 ----
    27501: C("噬心食髓", "realm", 1, 2, "SSR", 0,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 3 点伤害（印记叠层简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 3},
             deck_limit=2, tags=["幻境", "印记", "终结"]),
    27502: C("毒针", "spell", 1, 0, "R", 2,
             "瞬发，战技。对一个敌方式神造成 1 点伤害，并使其获得 1 点破甲。",
             [("always", "damage", "selected-enemy", 1), ("always", "apply-armor-break", "selected-enemy", 1)],
             keywords=["INSTANT"], tags=["瞬发", "战技", "印记"]),
    27503: C("猎杀", "combat", 1, 1, "R", 1,
             "出击 +2。追猎。若目标已破甲，获得 2 点护甲（免疫简化）。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
             tags=["出击", "追猎", "印记"]),
    27504: C("御蛛鬼姬", "form", 2, 1, "SR", 1,
             "获得 +3/+4。完成交战后，使目标获得 1 点破甲。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，使交战目标获得 1 点破甲。",
             formHooks=[{"id": "form-luoxin-queen", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "印记", "蛛群"]),
    27505: C("觉醒·络新妇", "awakening", 2, 1, "SR", 1,
             "对一个敌方式神造成 3 点伤害并 2 点破甲。觉醒：+2/+2，攻击后叠破甲。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "selected-enemy", 3), ("always", "apply-armor-break", "selected-enemy", 2)],
             deck_limit=1, tags=["觉醒", "印记", "破甲"]),
    27506: C("寻丝", "combat", 2, 1, "R", 1,
             "出击 +3。追猎。吸血简化：为自己恢复 2 点生命。",
             [("source-ready", "assault", "source", 3), ("always", "heal", "source", 2)],
             tags=["出击", "追猎", "吸血"]),
    27507: C("罗网缠织", "form", 3, 1, "SR", 1,
             "获得 +3/+4。敌方回合开始时，使其前线 -2 力量（额外耗火简化）。",
             [("always", "form", "source", F(3, 4))],
             formAbility="己方回合开始时，敌方前线 -2 力量。",
             formHooks=[{"id": "form-luoxin-web", "event": "turn-started", "effect": "passive-armor-break-enemy-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "印记", "压制"]),
    27508: C("诛灭", "spell", 3, 1, "R", 1,
             "对一个式神造成 5 点伤害，抽一张牌（已印记改为消灭简化为高额伤害）。",
             [("always", "damage", "selected-enemy", 5), ("always", "draw", "ally-player", 1)],
             tags=["消灭", "印记", "过牌"]),

    # ---- 一条 276 ----
    27601: C("此心安处", "combat", 1, 2, "SSR", 0,
             "出击 +3，并获得 3 点护甲（战技叠层简化）。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 3)],
             deck_limit=2, tags=["战技", "勤勉", "出击"]),
    27602: C("卫戍", "combat", 1, 1, "R", 2,
             "出击 +2。追猎。获得 1 点护甲。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 1)],
             tags=["出击", "追猎", "勤勉"]),
    27603: C("架势·守", "form", 1, 1, "SR", 1,
             "获得 +1/+5。敌方回合开始时简化：己方回合开始获得 2 点护甲。",
             [("always", "form", "source", F(1, 5))],
             formAbility="己方回合开始时，获得 2 点护甲。",
             formHooks=[{"id": "form-yitiao-guard", "event": "turn-started", "effect": "passive-shield-self-if-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "勤勉", "守护"]),
    27604: C("架势·攻", "form", 2, 1, "SR", 1,
             "获得 +4/+3。完成交战后，获得 1 点力量。",
             [("always", "form", "source", F(4, 3))],
             formAbility="完成交战后，一条获得 1 点力量。",
             formHooks=[{"id": "form-yitiao-blade", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "勤勉", "进攻"]),
    27605: C("孤斗", "spell", 2, 1, "R", 1,
             "一条获得 2 点力量、不屈和贯通。",
             [("always", "buff-stats", "source", F(2, 0)), ("always", "grant-unyielding", "source", 1)],
             keywords=["PIERCE", "UNYIELDING"], tags=["不屈", "贯通", "勤勉"]),
    27606: C("重任在肩", "spell", 2, 1, "R", 1,
             "一条获得 3 点护甲。响应：其他式神被攻击时自动使用。",
             [("always", "shield", "source", 3)],
             keywords=["RESPONSE"], timing="response", responseTo=["assault"],
             tags=["响应", "屏障", "勤勉"]),
    27607: C("架势·居合", "form", 3, 1, "R", 1,
             "获得 +4/+4。完成交战后，为自己恢复 3 点生命（吸血/暴击简化）。",
             [("always", "form", "source", F(4, 4))],
             formAbility="完成交战后，恢复 3 点生命。",
             formHooks=[{"id": "form-yitiao-iiai", "event": "combat-resolved", "effect": "passive-heal-self-if-front", "params": {"amount": 3}, "priority": 40}],
             tags=["形态", "勤勉", "吸血"]),
    27608: C("觉醒·一条", "awakening", 3, 1, "SR", 1,
             "获得 +3/+3。气绝时可用：复活一条。觉醒：战技效果不移除（简化为面板）。",
             [("always", "awaken", "source", F(3, 3)), ("always", "revive", "source", 1)],
             deck_limit=1, tags=["觉醒", "勤勉", "复活"]),

    # ---- 迦楼罗 277 ----
    27701: C("摧枯拉朽", "combat", 1, 1, "R", 1,
             "出击 +3。战技，直击简化：对敌方牌手额外 1 点。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 1)],
             tags=["战技", "直击", "惜羽"]),
    27702: C("翼刃浮金", "spell", 1, 0, "R", 2,
             "瞬发。对一个敌方式神造成 1 点伤害，并获得 1 点力量（倒计时-1简化）。",
             [("always", "damage", "selected-enemy", 1), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["INSTANT"], tags=["瞬发", "惜羽", "倒计时"]),
    27703: C("天衣妙翅", "form", 1, 1, "SR", 1,
             "获得 +2/+3。己方回合开始时，随机敌方 -1 力量（惜羽简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，随机敌方 -1 力量。",
             formHooks=[{"id": "form-jialou-robes", "event": "turn-started", "effect": "passive-armor-break-enemy-front", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "惜羽", "倒计时"]),
    27704: C("化生戟", "combat", 2, 1, "R", 1,
             "出击 +3。追猎。获得 2 点护甲（免疫简化）。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 2)],
             tags=["战技", "追猎", "惜羽"]),
    27705: C("龙息炽羽", "combat", 2, 1, "SR", 1,
             "出击 +2。远程。对所有敌方式神造成 1 点伤害。",
             [("source-ready", "assault", "source", 2), ("always", "damage", "all-enemy-units", 1)],
             keywords=["REMOTE"], tags=["战技", "远程", "惜羽"]),
    27706: C("觉醒·迦楼罗", "awakening", 2, 1, "SR", 1,
             "获得 2 点力量与迅捷。觉醒：+1/+2，倒计时获得迅捷与力量。",
             [("always", "awaken", "source", F(1, 2)), ("always", "buff-stats", "source", F(2, 0))],
             keywords=["INSTANT"], deck_limit=1, tags=["觉醒", "倒计时", "惜羽"]),
    27707: C("龙巢魔主", "form", 3, 2, "SSR", 0,
             "获得 +4/+3。替身，帷幕简化为获得 4 点护甲。",
             [("always", "form", "source", F(4, 3)), ("always", "shield", "source", 4)],
             deck_limit=2, tags=["形态", "惜羽", "终结"]),
    27708: C("飒踏疾驰", "combat", 3, 1, "R", 1,
             "出击 +4。战技。获得 1 点力量（倒计时-1简化）。",
             [("source-ready", "assault", "source", 4), ("always", "buff-stats", "source", F(1, 0))],
             tags=["战技", "倒计时", "惜羽"]),

    # ---- 化鲸 278 ----
    27801: C("齿甲", "spell", 1, 0, "R", 2,
             "瞬发。使一个己方式神获得 2 点力量（齿甲简化）。",
             [("always", "buff-stats", "selected-ally", F(2, 0))],
             keywords=["INSTANT", "BESTOW", "BURST"], tags=["瞬发", "齿甲", "爆能"]),
    27802: C("体甲", "spell", 1, 0, "R", 1,
             "瞬发。使一个己方式神获得 3 点护甲（体甲简化）。",
             [("always", "shield", "selected-ally", 3)],
             keywords=["INSTANT", "BESTOW", "BURST"], tags=["瞬发", "体甲", "爆能"]),
    27803: C("水袭", "spell", 1, 1, "SR", 1,
             "对一个式神造成 3 点伤害，并使所有己方式神获得 1 点力量。",
             [("always", "damage", "selected-enemy", 3), ("always", "buff-stats", "all-ally-units", F(1, 0))],
             tags=["伤害", "齿甲", "体甲"]),
    27804: C("泣海", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，所有己方式神获得 1 点护甲（母亲守护简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "爆能", "守护"]),
    27805: C("遥候", "combat", 2, 1, "R", 1,
             "出击 +3。攻击后，召唤母亲守护简化为获得 3 点护甲。",
             [("source-ready", "assault", "source", 3), ("always", "shield", "source", 3)],
             tags=["战技", "守护", "爆能"]),
    27806: C("觉醒·化鲸", "awakening", 2, 1, "SR", 1,
             "使化鲸获得 2 点力量与 2 点护甲。觉醒：+1/+3，出击时叠能量（简化为回合开始能量）。",
             [("always", "awaken", "source", F(1, 3)), ("always", "buff-stats", "source", F(2, 2))],
             deck_limit=1, tags=["觉醒", "齿甲", "体甲"]),
    27807: C("孤鲸", "form", 3, 1, "R", 1,
             "获得 +3/+3。己方回合开始时，获得 1 点力量与 1 点生命（爆能成长简化）。",
             [("always", "form", "source", F(3, 3))],
             formAbility="己方回合开始时，获得 1 点力量与 1 点生命。",
             formHooks=[{"id": "form-huajing-lone", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1, "hp": 1}, "priority": 40}],
             tags=["形态", "爆能", "成长"]),
    27808: C("虚妄之忆", "spell", 3, 2, "SSR", 0,
             "使所有己方式神获得 +2/+2 与 2 点护甲（齿甲体甲爆能简化）。",
             [("always", "buff-stats", "all-ally-units", F(2, 2)), ("always", "shield", "all-ally-units", 2)],
             deck_limit=2, tags=["团辅", "爆能", "终结"]),

    # ---- 影鳄 279 ----
    27901: C("匿息", "spell", 1, 1, "R", 2,
             "使一个己方式神获得 +1/+1（鬼鳄结附简化）。",
             [("always", "buff-stats", "selected-ally", F(1, 1))],
             tags=["鬼鳄", "强化", "成长"]),
    27902: C("出蛰", "combat", 1, 1, "R", 1,
             "出击 +3。贯通。获得 1 点力量。",
             [("source-ready", "assault", "source", 3), ("always", "buff-stats", "source", F(1, 0))],
             keywords=["PIERCE", "CHARGED"], tags=["出击", "贯通", "鬼鳄"]),
    27903: C("如影随形", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，所有己方式神获得 1 点力量（迅捷鬼鳄简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "鬼鳄", "迅捷"]),
    27904: C("觉醒·影鳄", "awakening", 2, 2, "SSR", 0,
             "影鳄获得 +2/+2。觉醒：出击叠力量（简化为面板）。",
             [("always", "awaken", "source", F(2, 2))],
             deck_limit=2, tags=["觉醒", "鬼鳄", "成长"]),
    27905: C("幕影盖地", "combat", 2, 1, "SR", 1,
             "出击 +4。先攻，追猎。获得 1 点力量。",
             [("source-ready", "assault", "source", 4), ("always", "buff-stats", "source", F(1, 0))],
             tags=["出击", "先攻", "鬼鳄"]),
    27906: C("伏猎", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害，并使影鳄获得 +1/+1。",
             [("always", "damage", "selected-enemy", 4), ("always", "buff-stats", "source", F(1, 1))],
             tags=["伤害", "鬼鳄", "伏猎"]),
    27907: C("诡影重重", "form", 3, 1, "R", 1,
             "获得 +4/+4。完成交战后，获得 1 点力量。",
             [("always", "form", "source", F(4, 4))],
             formAbility="完成交战后，获得 1 点力量。",
             formHooks=[{"id": "form-yinge-clone", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "鬼鳄", "增强"]),
    27908: C("啖噬", "combat", 3, 1, "SR", 1,
             "出击 +5，并获得 +2/+2（鬼鳄强化简化）。",
             [("source-ready", "assault", "source", 5), ("always", "buff-stats", "source", F(2, 2))],
             tags=["出击", "鬼鳄", "强化"]),

    # ---- 不见岳 280 ----
    28001: C("云衣", "realm", 1, 1, "R", 2,
             "幻境（耐久 4）：进场对一个敌方式神造成 3 点伤害；被消灭时恢复你 3 点生命（回合开始治疗）。",
             [("always", "damage", "selected-enemy", 3), ("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 0},
             tags=["幻境", "伤害", "被灭"]),
    28002: C("山色", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：鼓舞 +2/+2 简化为进场所有己方 +1/+1；被灭复活简化为回合开始抽牌。",
             [("always", "buff-stats", "all-ally-units", F(1, 1)), ("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "draw", "triggerValue": 1},
             tags=["幻境", "鼓舞", "被灭"]),
    28003: C("寻径", "spell", 1, 0, "R", 1,
             "瞬发。抽两张牌（消灭幻境简化）。",
             [("always", "draw", "ally-player", 2)],
             keywords=["INSTANT"], tags=["瞬发", "过牌", "幻境"]),
    28004: C("重峦", "realm", 2, 1, "R", 1,
             "幻境（耐久 4）：进场使敌方前线获得 3 点破甲；回合开始对敌方前线 1 点伤害。",
             [("always", "apply-armor-break", "auto", 3), ("always", "realm", "ally-player", None)],
             realm={"hp": 4, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "破甲", "被灭"]),
    28005: C("古山之神", "realm", 2, 2, "SSR", 0,
             "幻境（耐久 6）：进场所有己方 +1 生命；回合开始所有己方获得 2 点护甲。",
             [("always", "buff-stats", "all-ally-units", F(0, 1)), ("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "古山", "终结"]),
    28006: C("觉醒·不见岳", "awakening", 2, 1, "SR", 1,
             "抽一张牌。觉醒：+2/+2，出击获得力量生命并消灭幻境得鬼火（简化为面板+能量）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
             deck_limit=1, tags=["觉醒", "幻境", "被灭"]),
    28007: C("峰回路转", "spell", 3, 1, "R", 1,
             "抽两张牌，并为所有己方式神恢复 2 点生命（复场幻境简化）。",
             [("always", "draw", "ally-player", 2), ("always", "heal", "all-ally-units", 2)],
             tags=["幻境", "复场", "过牌"]),
    28008: C("水宿山行", "realm", 3, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，所有己方式神获得 2 点生命与 1 点护甲（不屈简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "不屈", "团辅"]),

    # ---- 须佐之男 281 ----
    28101: C("雷霆万钧", "combat", 1, 0, "R", 1,
             "瞬发，追猎。只能攻击生命为 1 的式神简化为出击 +3。",
             [("source-ready", "assault", "source", 3)],
             keywords=["INSTANT"], tags=["瞬发", "追猎", "雷冢"]),
    28102: C("天威", "combat", 1, 1, "R", 2,
             "出击 +3。追猎。击杀变雷冢简化为造成 2 点额外伤害。",
             [("source-ready", "assault", "source", 3), ("always", "damage-enemy-front", "auto", 2)],
             tags=["出击", "追猎", "雷冢"]),
    28103: C("神之领域", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：鼓舞 +1/+1 与护甲；回合开始所有己方获得 1 点护甲。",
             [("always", "buff-stats", "all-ally-units", F(1, 1)), ("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "鼓舞", "雷冢"]),
    28104: C("雷奔云谲", "combat", 2, 1, "SR", 1,
             "出击 +5。必杀简化为对敌方前线额外 3 点伤害。",
             [("source-ready", "assault", "source", 5), ("always", "damage-enemy-front", "auto", 3)],
             tags=["出击", "必杀", "雷冢"]),
    28105: C("神明之护", "form", 2, 1, "R", 1,
             "获得 +3/+5。气绝时可用：复活须佐之男。",
             [("always", "form", "source", F(3, 5)), ("always", "revive", "source", 1)],
             tags=["形态", "增强", "雷冢"]),
    28106: C("觉醒·须佐之男", "awakening", 2, 1, "SR", 1,
             "将一张「雷霆万钧」简化为获得 2 点力量。觉醒：贯通，攻击式神 +1 力量。",
             [("always", "awaken", "source", F(1, 1)), ("always", "buff-stats", "source", F(2, 0))],
             keywords=["PIERCE"], deck_limit=1, tags=["觉醒", "贯通", "雷冢"]),
    28107: C("雷切", "combat", 3, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害，再对敌方前线造成 3 点伤害。",
             [("always", "damage", "selected-enemy", 3), ("always", "damage-enemy-front", "auto", 3)],
             tags=["出击", "雷冢", "群伤"]),
    28108: C("天雷万象", "form", 3, 2, "SSR", 0,
             "获得 +4/+5。不屈。己方回合开始时，对敌方前线造成 3 点伤害。",
             [("always", "form", "source", F(4, 5)), ("always", "grant-unyielding", "source", 1)],
             formAbility="己方回合开始时，对敌方前线造成 3 点伤害。",
             formHooks=[{"id": "form-susanoo-storm", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 3}, "priority": 40}],
             deck_limit=2, tags=["形态", "不屈", "终结"]),

    # ---- 鲤鱼精 282 ----
    28201: C("泡泡之护", "spell", 1, 1, "R", 2,
             "战技。使一个己方其他式神获得 3 点护甲（加护简化）。",
             [("always", "shield", "selected-ally", 3)],
             tags=["战技", "加护", "护甲"]),
    28202: C("泡泡之愈", "spell", 1, 1, "R", 1,
             "为你恢复 3 点生命，并抽一张牌（加护叠层简化）。",
             [("always", "heal-avatar", "ally-avatar", 3), ("always", "draw", "ally-player", 1)],
             tags=["加护", "治疗", "过牌"]),
    28203: C("赤鲤跃波", "form", 1, 1, "SR", 1,
             "获得 +2/+3。进场抽一张牌（加护简化）。",
             [("always", "form", "source", F(2, 3)), ("always", "draw", "ally-player", 1)],
             tags=["形态", "加护", "过牌"]),
    28204: C("溪流欢歌", "realm", 2, 1, "SR", 1,
             "幻境（耐久 6）：己方回合开始时，所有己方式神获得 1 点护甲。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 1},
             tags=["幻境", "加护", "团辅"]),
    28205: C("尾鞭", "spell", 2, 1, "R", 1,
             "对一个式神造成 4 点伤害，并为鲤鱼精恢复 2 点生命。",
             [("always", "damage", "selected-enemy", 4), ("always", "heal", "source", 2)],
             tags=["伤害", "加护", "治疗"]),
    28206: C("觉醒·鲤鱼精", "awakening", 2, 1, "SR", 1,
             "为所有己方其他式神恢复 2 点生命。觉醒：+1/+2，加护改为 +1/+1。",
             [("always", "awaken", "source", F(1, 2)), ("always", "heal", "all-other-allies", 2)],
             deck_limit=1, tags=["觉醒", "加护", "倒计时"]),
    28207: C("嬉游", "spell", 3, 1, "R", 1,
             "抽两张牌，并为所有己方式神获得 1 点护甲。",
             [("always", "draw", "ally-player", 2), ("always", "shield", "all-ally-units", 1)],
             tags=["加护", "过牌", "团辅"]),
    28208: C("水镜红锦", "form", 3, 2, "SSR", 0,
             "获得 +3/+5。进场抽一张牌。己方回合开始时，抽一张牌。",
             [("always", "form", "source", F(3, 5)), ("always", "draw", "ally-player", 1)],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-liyu-mirror", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             deck_limit=2, tags=["形态", "加护", "终结"]),

    # ---- 虫师 283 ----
    28301: C("跹跹虫舞", "form", 1, 1, "SR", 1,
             "获得 +3/+3。中毒敌方气绝时抽一张牌简化：完成交战后抽一张牌。",
             [("always", "form", "source", F(3, 3))],
             formAbility="完成交战后，抽一张牌。",
             formHooks=[{"id": "form-chong-dance", "event": "combat-resolved", "effect": "passive-draw-self", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "中毒", "过牌"]),
    28302: C("虫之声", "spell", 1, 1, "R", 2,
             "召唤展翅虫群简化：对敌方前线造成 2 点伤害，并获得 1 点力量。",
             [("always", "damage-enemy-front", "auto", 2), ("always", "buff-stats", "source", F(1, 0))],
             tags=["召唤", "中毒", "虫群"]),
    28303: C("虫之忆", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害并使其 -2 力量（剧毒简化）。",
             [("always", "damage", "selected-enemy", 3), ("always", "debuff-stats", "selected-enemy", {"attack": 2, "hp": 0})],
             tags=["剧毒", "伤害", "中毒"]),
    28304: C("簌簌虫痕", "form", 2, 1, "SR", 1,
             "获得 +2/+3。恢复生命时获得 1 点力量（毒绝回血简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="恢复生命时，虫师获得 1 点力量。",
             formHooks=[{"id": "form-chong-trace", "event": "unit-healed", "effect": "passive-buff-healed-attack", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "中毒", "治疗"]),
    28305: C("虫之途", "spell", 2, 1, "R", 1,
             "抽两张牌，并使一个己方式神获得 2 点护甲。",
             [("always", "draw", "ally-player", 2), ("always", "shield", "selected-ally", 2)],
             tags=["剧毒", "加护", "过牌"]),
    28306: C("虫之眠", "spell", 2, 1, "SR", 1,
             "复活一个己方式神，并对敌方前线造成 2 点伤害。",
             [("always", "revive", "knocked-ally", 1), ("always", "damage-enemy-front", "auto", 2)],
             tags=["剧毒", "复活", "中毒"]),
    28307: C("虫之梦", "realm", 3, 1, "R", 1,
             "幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害（剧毒必杀简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "剧毒", "必杀"]),
    28308: C("觉醒·虫师", "awakening", 3, 1, "SSR", 0,
             "对一个敌方式神造成 4 点伤害并 -2 力量。觉醒：中毒削力翻倍（简化为面板）。",
             [("always", "awaken", "source", F(1, 2)), ("always", "damage", "selected-enemy", 4), ("always", "debuff-stats", "selected-enemy", {"attack": 2, "hp": 0})],
             deck_limit=2, tags=["觉醒", "剧毒", "中毒"]),

    # ---- 蝎女 284 ----
    28401: C("以毒攻毒", "spell", 1, 1, "SR", 1,
             "复活蝎女，并获得 2 点护甲。气绝时可用。",
             [("always", "revive", "source", 1), ("always", "shield", "source", 2)],
             tags=["加护", "复活", "剧毒"]),
    28402: C("螯击", "combat", 1, 0, "R", 2,
             "出击 +2。加护简化：获得 1 点护甲。",
             [("source-ready", "assault", "source", 2), ("always", "shield", "source", 1)],
             tags=["出击", "加护", "剧毒"]),
    28403: C("隐秘之刺", "form", 1, 1, "R", 1,
             "获得 +1/+5。气绝反击简化：受到伤害后，对敌方前线造成 2 点伤害。",
             [("always", "form", "source", F(1, 5))],
             formAbility="受到伤害后，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-xie-sting", "event": "unit-damaged", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "剧毒", "反击"]),
    28404: C("觉醒·蝎女", "awakening", 2, 1, "SR", 1,
             "获得 2 点力量与 2 点护甲。觉醒：剧毒（简化为攻击叠破甲）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "shield", "source", 2)],
             deck_limit=1, tags=["觉醒", "加护", "剧毒"]),
    28405: C("生杀予夺", "form", 2, 1, "SR", 1,
             "获得 +3/+4。完成交战后，获得 2 点护甲（中毒转甲简化）。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，获得 2 点护甲。",
             formHooks=[{"id": "form-xie-judge", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "中毒", "护甲"]),
    28406: C("噬毒", "combat", 2, 1, "R", 1,
             "出击 +4，并获得 1 点护甲（增强简化）。",
             [("source-ready", "assault", "source", 4), ("always", "shield", "source", 1)],
             tags=["出击", "增强", "中毒"]),
    28407: C("蝎窟", "realm", 3, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 2 点伤害（剧毒反伤简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
             tags=["幻境", "剧毒", "反击"]),
    28408: C("百蝎之毒", "form", 3, 2, "SSR", 0,
             "获得 +3/+5。不屈。完成交战后，对敌方牌手造成 2 点伤害。",
             [("always", "form", "source", F(3, 5)), ("always", "grant-unyielding", "source", 1)],
             formAbility="完成交战后，对敌方牌手造成 2 点伤害。",
             formHooks=[{"id": "form-xie-hundred", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 2}, "priority": 40}],
             deck_limit=2, tags=["形态", "不屈", "终结"]),

    # ---- 於菊虫 285 ----
    28501: C("毒丝", "spell", 1, 1, "R", 2,
             "投射：造成 2 点伤害，并使其 -1 力量（剧毒简化）。",
             [("always", "damage-enemy-front", "auto", 2), ("always", "debuff-stats", "selected-enemy", {"attack": 1, "hp": 0})],
             keywords=["PROJECTILE"], tags=["投射", "剧毒", "中毒"]),
    28502: C("暮啼", "realm", 1, 1, "SR", 1,
             "幻境（耐久 5）：己方回合开始时，对敌方前线造成 1 点伤害（蚀印简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "剧毒", "蚀印"]),
    28503: C("若虫", "form", 1, 1, "R", 1,
             "获得 +2/+3。己方回合开始时，随机对敌方造成 1 点伤害（倒计时毒简化）。",
             [("always", "form", "source", F(2, 3))],
             formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             formHooks=[{"id": "form-yuju-nymph", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "倒计时", "剧毒"]),
    28504: C("夜噬", "form", 2, 1, "SR", 1,
             "获得 +3/+3。进场投射 2 点；气绝倒计时+1简化为回合开始敌方前线 2 点。",
             [("always", "form", "source", F(3, 3)), ("always", "damage-enemy-front", "auto", 2)],
             formAbility="己方回合开始时，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-yuju-night", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "投射", "剧毒"]),
    28505: C("朝鸣", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 4 点伤害。响应：敌方攻击时自动使用。",
             [("always", "damage", "selected-enemy", 4)],
             keywords=["RESPONSE"], timing="response", responseTo=["assault"],
             tags=["响应", "剧毒", "中毒"]),
    28506: C("觉醒·於菊虫", "awakening", 2, 1, "SR", 1,
             "对敌方牌手造成 2 点伤害并恢复 2 点生命。觉醒：毒绝打脸 2 点（简化为面板）。",
             [("always", "awaken", "source", F(1, 1)), ("always", "damage", "enemy-avatar", 2), ("always", "heal-avatar", "ally-avatar", 2)],
             deck_limit=1, tags=["觉醒", "中毒", "剧毒"]),
    28507: C("昼梦", "spell", 3, 1, "R", 1,
             "对所有敌方式神造成 2 点伤害，并对敌方牌手造成 2 点伤害。",
             [("always", "damage", "all-enemy-units", 2), ("always", "damage", "enemy-avatar", 2)],
             tags=["剧毒", "群伤", "中毒"]),
    28508: C("破茧", "spell", 3, 2, "SSR", 0,
             "投射：造成 5 点伤害，并对敌方前线再造成 3 点（贯通增强简化）。",
             [("always", "damage-enemy-front", "auto", 5), ("always", "damage-enemy-front", "auto", 3)],
             keywords=["PROJECTILE", "PIERCE"], deck_limit=2, tags=["投射", "剧毒", "终结"]),

    # ---- 海忍 286 ----
    28601: C("千刃", "combat", 1, 1, "R", 1,
             "出击 +3。剧毒穿刺简化：获得 1 点力量。",
             [("source-ready", "assault", "source", 3), ("always", "buff-stats", "source", F(1, 0))],
             tags=["出击", "剧毒", "穿刺"]),
    28602: C("潜影", "spell", 1, 0, "R", 2,
             "瞬发。对一个敌方式神造成 1 点伤害并 -1 力量（未中毒剧毒简化）。",
             [("always", "damage", "selected-enemy", 1), ("always", "debuff-stats", "selected-enemy", {"attack": 1, "hp": 0})],
             keywords=["INSTANT"], tags=["瞬发", "中毒", "剧毒"]),
    28603: C("忍杀", "combat", 1, 1, "SR", 1,
             "出击 +2。蚀印简化：使目标获得 1 点破甲。",
             [("source-ready", "assault", "source", 2), ("always", "apply-armor-break", "selected-enemy", 1)],
             tags=["出击", "蚀印", "剧毒"]),
    28604: C("觉醒·海忍", "awakening", 2, 1, "SR", 1,
             "对一个敌方式神造成 3 点伤害。觉醒：+2/+2，攻击毒目标免伤（简化为获得护甲）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage", "selected-enemy", 3), ("always", "shield", "source", 2)],
             deck_limit=1, tags=["觉醒", "中毒", "免伤"]),
    28605: C("影出", "combat", 2, 1, "R", 1,
             "出击 +4。追猎。剧毒简化：使其 -2 力量。",
             [("source-ready", "assault", "source", 4), ("always", "debuff-stats", "selected-enemy", {"attack": 2, "hp": 0})],
             tags=["出击", "追猎", "剧毒"]),
    28606: C("沧海孤忍", "form", 2, 2, "SSR", 0,
             "获得 +3/+4。完成交战后，获得 1 点力量并恢复 2 点生命。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，获得 1 点力量并恢复 2 点生命。",
             formHooks=[
                 {"id": "form-hain-lone-buff", "event": "combat-resolved", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
                 {"id": "form-hain-lone-heal", "event": "combat-resolved", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "中毒", "终结"]),
    28607: C("宿怨", "combat", 3, 1, "SR", 1,
             "出击 +3。对一个式神造成 3 点伤害（剧毒简化）。",
             [("source-ready", "assault", "source", 3), ("always", "damage", "selected-enemy", 3)],
             tags=["出击", "剧毒", "宿怨"]),
    28608: C("影逝花杀", "form", 3, 1, "R", 1,
             "获得 +4/+3。连击。进场和回合开始将「潜影」简化为抽一张牌。",
             [("always", "form", "source", F(4, 3))],
             keywords=["COMBO"],
             formAbility="己方回合开始时，抽一张牌。",
             formHooks=[{"id": "form-hain-shadow", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
             tags=["形态", "连击", "剧毒"]),

    # ---- 灵海蝶 287 ----
    28701: C("波缀", "spell", 1, 1, "R", 2,
             "将灵海蝶移入战斗区简化：获得 2 点力量，并使一个敌方 -2 力量。",
             [("always", "buff-stats", "source", F(2, 0)), ("always", "debuff-stats", "selected-enemy", {"attack": 2, "hp": 0})],
             tags=["移动", "激怒", "海灵"]),
    28702: C("灵巡", "spell", 1, 0, "R", 1,
             "瞬发。使一个己方式神获得 2 点护甲，并占卜 2（海灵简化）。",
             [("always", "shield", "selected-ally", 2), ("always", "divination", "ally-player", 2)],
             keywords=["INSTANT"], tags=["瞬发", "海灵", "占卜"]),
    28703: C("碧海之蝶", "form", 1, 1, "SR", 1,
             "获得 +2/+4。己方回合开始时，随机己方 +1 生命（海灵双效果简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="己方回合开始时，随机己方式神 +1 生命。",
             formHooks=[{"id": "form-ling-blue", "event": "turn-started", "effect": "passive-buff-other-allies", "params": {"attack": 0, "hp": 1}, "priority": 40}],
             tags=["形态", "海灵", "团辅"]),
    28704: C("觉醒·灵海蝶", "awakening", 2, 1, "SR", 1,
             "移动一个己方式神简化为全体 +1 护甲。觉醒：+1/+2，入战斗区结海灵（投射 2 简化）。",
             [("always", "awaken", "source", F(1, 2)), ("always", "shield", "all-ally-units", 1)],
             deck_limit=1, tags=["觉醒", "移动", "海灵"]),
    28705: C("迁溯", "spell", 2, 1, "R", 1,
             "复活一个己方式神。气绝时可用。",
             [("always", "revive", "knocked-ally", 1)],
             tags=["海灵", "移动", "复活"]),
    28706: C("幽波之灵", "form", 2, 1, "SR", 1,
             "获得 +3/+4。追猎。完成交战后，对敌方前线造成 2 点伤害（触发海灵简化）。",
             [("always", "form", "source", F(3, 4))],
             formAbility="完成交战后，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-ling-wave", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
             tags=["形态", "追猎", "海灵"]),
    28707: C("月珊瑚", "spell", 3, 1, "R", 1,
             "对一个式神造成 3 点伤害，恢复你 3 点生命。",
             [("always", "damage", "selected-enemy", 3), ("always", "heal-avatar", "ally-avatar", 3)],
             tags=["海灵", "伤害", "治疗"]),
    28708: C("海心落", "realm", 3, 2, "SSR", 0,
             "幻境（耐久 8）：己方回合开始时，所有己方式神获得 2 点护甲（海灵全触发简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 8, "trigger": "owner-turn-start", "triggerEffect": "shield-all-allies", "triggerValue": 2},
             deck_limit=2, tags=["幻境", "海灵", "终结"]),

    # ---- 寻香行 288 ----
    28801: C("燃香", "spell", 1, 1, "SR", 1,
             "眩晕一个式神，并使其获得 1 点破甲（蚀印简化）。",
             [("always", "freeze", "selected-enemy", 1), ("always", "apply-armor-break", "selected-enemy", 1)],
             keywords=["STUN"], tags=["蚀印", "眩晕", "压制"]),
    28802: C("承愿寻香", "form", 1, 1, "R", 1,
             "获得 +2/+3。远程。完成交战后，蚀印简化为对敌方牌手 1 点伤害。",
             [("always", "form", "source", F(2, 3))],
             keywords=["REMOTE"],
             formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
             formHooks=[{"id": "form-xun-wish", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
             tags=["形态", "远程", "蚀印"]),
    28803: C("明香境", "realm", 1, 1, "R", 1,
             "幻境（耐久 5）：己方回合开始时，敌方前线 -1 力量并获得 1 点破甲（压制简化）。",
             [("always", "realm", "ally-player", None)],
             realm={"hp": 5, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 1},
             tags=["幻境", "蚀印", "压制"]),
    28804: C("缚魂香", "spell", 2, 1, "R", 2,
             "对一个敌方式神造成 4 点伤害，并使其获得 1 点破甲。",
             [("always", "damage", "selected-enemy", 4), ("always", "apply-armor-break", "selected-enemy", 1)],
             tags=["蚀印", "伤害", "束缚"]),
    28805: C("觉醒·寻香行", "awakening", 2, 1, "SR", 1,
             "对敌方前线造成 3 点伤害。觉醒：+2/+2，蚀印时投射 2 点（简化为面板）。",
             [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 3)],
             deck_limit=1, tags=["觉醒", "蚀印", "投射"]),
    28806: C("菩提愿", "spell", 2, 1, "SR", 1,
             "抽两张牌，并使敌方前线 -2 力量（弃牌蚀印简化）。",
             [("always", "draw", "ally-player", 2), ("always", "debuff-stats", "auto", {"attack": 2, "hp": 0})],
             tags=["蚀印", "过牌", "压制"]),
    28807: C("御香引", "spell", 3, 1, "R", 1,
             "对所有敌方式神造成 3 点伤害，并各获得 1 点破甲。",
             [("always", "damage", "all-enemy-units", 3), ("always", "apply-armor-break", "all-enemy-units", 1)],
             tags=["蚀印", "群伤", "破甲"]),
    28808: C("缚梦明香", "form", 3, 2, "SSR", 0,
             "获得 +4/+4。己方回合开始时，对敌方前线造成 2 点伤害并 -1 力量。",
             [("always", "form", "source", F(4, 4))],
             formAbility="己方回合开始时，对敌方前线造成 2 点伤害并 -1 力量。",
             formHooks=[
                 {"id": "form-xun-dream-dmg", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40},
                 {"id": "form-xun-dream-break", "event": "turn-started", "effect": "passive-armor-break-enemy-front", "params": {"amount": 1}, "priority": 40},
             ],
             deck_limit=2, tags=["形态", "蚀印", "终结"]),
}

# 无额外 token；如需可在此追加
TOKENS: list = []
EXTRA_TOKENS: list = []

# 被动映射：uid -> (passive, awakenedPassive)；formHooks/被动仅用已注册 passive-*
PASSIVES = {
    "jinnaluo": (
        dict(id="jinnaluo-fortune", name="弦音入夜", text="己方回合开始时，随机对一个敌方角色造成 1 点伤害（运势入夜简化）。",
             hooks=[dict(id="string-night", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="jinnaluo-fortune-awakened", name="终焉弦音", text="己方回合开始时，随机对一个敌方角色造成 3 点伤害并抽一张牌。",
             hooks=[
                 dict(id="string-night-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 3}),
                 dict(id="string-night-a2", event="turn-started", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "lingyanji": (
        dict(id="lingyanji-bell", name="神火铃焰", text="气绝时简化：受到伤害后获得 1 点护甲（转生缓冲）。",
             hooks=[dict(id="bell-flame", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="lingyanji-bell-awakened", name="不灭铃焰", text="受到伤害后获得 2 点护甲。",
             hooks=[dict(id="bell-flame-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "rurineque": (
        dict(id="rurineque-night", name="入夜护巢", text="己方回合开始时，若在战斗区，获得 2 点护甲。",
             hooks=[dict(id="nest-shield", event="turn-started", effect="passive-shield-self-if-front", params={"amount": 2})]),
        dict(id="rurineque-night-awakened", name="幽雀叠甲", text="己方回合开始时，获得 2 点护甲与 1 点生命。",
             hooks=[
                 dict(id="nest-shield-a", event="turn-started", effect="passive-shield-self", params={"amount": 2}),
                 dict(id="nest-shield-a2", event="turn-started", effect="passive-buff-self", params={"hp": 1}),
             ]),
    ),
    "shouwu": (
        dict(id="shouwu-head", name="飞颅补刀", text="完成交战后，对敌方牌手造成 1 点伤害。",
             hooks=[dict(id="head-bop", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="shouwu-head-awakened", name="提首连击", text="完成交战后，对敌方牌手造成 2 点伤害并随机对敌方造成 1 点。",
             hooks=[
                 dict(id="head-bop-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2}),
                 dict(id="head-bop-a2", event="combat-resolved", effect="passive-damage-random-enemy", params={"amount": 1}),
             ]),
    ),
    "gunvhongye": (
        dict(id="gunvhongye-maple", name="红枫投射", text="己方回合开始时，随机对一个敌方角色造成 1 点伤害（入夜投射简化）。",
             hooks=[dict(id="maple-shot", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="gunvhongye-maple-awakened", name="枫火连爆", text="己方回合开始时，随机对一个敌方角色造成 3 点伤害。",
             hooks=[dict(id="maple-shot-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 3})]),
    ),
    "choushizhinv": (
        dict(id="choushizhinv-doll", name="草人咒缚", text="完成交战后，使交战目标获得 1 点破甲。",
             hooks=[dict(id="doll-curse", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="choushizhinv-doll-awakened", name="丑时百鬼", text="完成交战后，使交战目标获得 2 点破甲。",
             hooks=[dict(id="doll-curse-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "yifanmumian": (
        dict(id="yifanmumian-cloth", name="白绵回生", text="气绝时简化：其他式神气绝时，为所有己方恢复 1 点生命。",
             hooks=[dict(id="cloth-revive", event="unit-knocked-out", effect="passive-heal-all-allies", params={"amount": 1})]),
        dict(id="yifanmumian-cloth-awakened", name="绯夜绵魂", text="其他式神气绝时，为所有己方恢复 2 点生命。",
             hooks=[dict(id="cloth-revive-a", event="unit-knocked-out", effect="passive-heal-all-allies", params={"amount": 2})]),
    ),
    "yecha": (
        dict(id="yecha-onslaught", name="黄泉屠戮", text="完成交战后，夜叉获得 1 点力量。",
             hooks=[dict(id="yasha-fang", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="yecha-onslaught-awakened", name="修罗夜行", text="完成交战后，夜叉获得 2 点力量并恢复 1 点生命。",
             hooks=[
                 dict(id="yasha-fang-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="yasha-fang-a2", event="combat-resolved", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "huangchuanzhizhu": (
        dict(id="huangchuan-current", name="归流川压", text="己方回合开始时，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="stream-press", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="huangchuan-current-awakened", name="荒川怒涛", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="stream-press-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "wannianzhu": (
        dict(id="wannianzhu-charge", name="竹剑蓄力", text="完成交战后，万年竹获得 1 点力量。",
             hooks=[dict(id="bamboo-charge", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="wannianzhu-charge-awakened", name="万叶生风", text="完成交战后，万年竹获得 2 点力量。",
             hooks=[dict(id="bamboo-charge-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "shuzhu": (
        dict(id="shuzhu-beads", name="念珠禅定", text="受到伤害后，获得 1 点护甲。",
             hooks=[dict(id="bead-calm", event="unit-damaged", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="shuzhu-beads-awakened", name="金刚念珠", text="受到伤害后，获得 2 点护甲。",
             hooks=[dict(id="bead-calm-a", event="unit-damaged", effect="passive-shield-self", params={"amount": 2})]),
    ),
    "sanweihu": (
        dict(id="sanweihu-flame", name="红焰媚火", text="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
             hooks=[dict(id="fox-flame", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="sanweihu-flame-awakened", name="三尾焚天", text="己方回合开始时，随机对一个敌方角色造成 2 点伤害并获得 1 点力量。",
             hooks=[
                 dict(id="fox-flame-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 2}),
                 dict(id="fox-flame-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "jicanghai": (
        dict(id="jicanghai-charge", name="蓄力崩山", text="完成交战后，季沧海获得 1 点力量。",
             hooks=[dict(id="charge-mountain", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="jicanghai-charge-awakened", name="迅烈蓄势", text="完成交战后，季沧海获得 2 点力量与 1 点护甲。",
             hooks=[
                 dict(id="charge-mountain-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2}),
                 dict(id="charge-mountain-a2", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1}),
             ]),
    ),
    "wuchen": (
        dict(id="wuchen-step", name="闪步回备", text="完成交战后，无尘获得 1 点护甲（移动简化）。",
             hooks=[dict(id="void-step", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1})]),
        dict(id="wuchen-step-awakened", name="两仪身法", text="完成交战后，无尘获得 2 点护甲并抽一张牌。",
             hooks=[
                 dict(id="void-step-a", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 2}),
                 dict(id="void-step-a2", event="combat-resolved", effect="passive-draw-self", params={"count": 1}),
             ]),
    ),
    "ninghongye": (
        dict(id="ninghongye-arrow", name="蓄力投射", text="己方回合开始时，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="ning-shot", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="ninghongye-arrow-awakened", name="赤练箭雨", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="ning-shot-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "tayumenhutao": (
        dict(id="tayumenhutao-ward", name="桔梗庇护", text="己方回合开始时，若在战斗区，恢复 3 点生命。",
             hooks=[dict(id="kikyo-ward", event="turn-started", effect="passive-heal-self-if-front", params={"amount": 3})]),
        dict(id="tayumenhutao-ward-awakened", name="净天地", text="己方回合开始时，恢复 3 点生命并获得 1 点护甲。",
             hooks=[dict(id="kikyo-ward-a", event="turn-started", effect="passive-heal-shield-self-if-front", params={"amount": 3, "shield": 1})]),
    ),
    "baize": (
        dict(id="baize-lore", name="达知洗库", text="己方回合开始时，抽一张牌（达知洗库简化）。",
             hooks=[dict(id="lore-draw", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
        dict(id="baize-lore-awakened", name="通晓万物", text="己方回合开始时，抽一张牌并占卜 1。",
             hooks=[dict(id="lore-draw-a", event="turn-started", effect="passive-draw-self", params={"count": 1})]),
    ),
    "hudiejing": (
        dict(id="hudiejing-skill", name="战技飞花", text="完成交战后，抽一张牌。",
             hooks=[dict(id="skill-petal", event="combat-resolved", effect="passive-draw-self", params={"count": 1})]),
        dict(id="hudiejing-skill-awakened", name="玲珑蝶梦", text="完成交战后，抽一张牌并获得 1 点力量。",
             hooks=[
                 dict(id="skill-petal-a", event="combat-resolved", effect="passive-draw-self", params={"count": 1}),
                 dict(id="skill-petal-a2", event="combat-resolved", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "luoxinfu": (
        dict(id="luoxinfu-mark", name="蜘蛛印记", text="完成交战后，使交战目标获得 1 点破甲。",
             hooks=[dict(id="spider-mark", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="luoxinfu-mark-awakened", name="罗网缠杀", text="完成交战后，使交战目标获得 2 点破甲。",
             hooks=[dict(id="spider-mark-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "yitiao": (
        dict(id="yitiao-diligence", name="勤勉修行", text="己方回合开始时，若在战斗区，获得 1 点力量。",
             hooks=[dict(id="diligence", event="turn-started", effect="passive-buff-self-if-front", params={"attack": 1})]),
        dict(id="yitiao-diligence-awakened", name="重任在肩", text="己方回合开始时，获得 1 点力量与 1 点护甲。",
             hooks=[
                 dict(id="diligence-a", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
                 dict(id="diligence-a2", event="turn-started", effect="passive-shield-self", params={"amount": 1}),
             ]),
    ),
    "jialouluo": (
        dict(id="jialouluo-countdown", name="倒计时翼", text="己方回合开始时，迦楼罗获得 1 点力量（迅捷昂扬简化）。",
             hooks=[dict(id="wing-count", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="jialouluo-countdown-awakened", name="化生金翼", text="己方回合开始时，获得 2 点力量。",
             hooks=[dict(id="wing-count-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "huajing": (
        dict(id="huajing-charge", name="充能齿甲", text="己方回合开始时，你获得 1 点能量（充能简化）。",
             hooks=[dict(id="whale-charge", event="turn-started", effect="passive-gain-energy", params={"amount": 1})]),
        dict(id="huajing-charge-awakened", name="母亲守护", text="己方回合开始时，你获得 1 点能量，化鲸获得 1 点力量。",
             hooks=[
                 dict(id="whale-charge-a", event="turn-started", effect="passive-gain-energy", params={"amount": 1}),
                 dict(id="whale-charge-a2", event="turn-started", effect="passive-buff-self", params={"attack": 1}),
             ]),
    ),
    "yinge": (
        dict(id="yinge-oni", name="鬼鳄成长", text="完成交战后，影鳄获得 1 点力量。",
             hooks=[dict(id="oni-scale", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="yinge-oni-awakened", name="影鳄啖噬", text="完成交战后，影鳄获得 2 点力量。",
             hooks=[dict(id="oni-scale-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 2})]),
    ),
    "bujianyue": (
        dict(id="bujianyue-realm", name="古山幻灭", text="部署幻境时，己方前线获得 1 点护甲（被灭触发简化）。",
             hooks=[dict(id="mountain-fade", event="realm-deployed", effect="passive-shield-front-on-realm", params={"amount": 1})]),
        dict(id="bujianyue-realm-awakened", name="不见岳神", text="部署幻境时，己方前线获得 2 点护甲。",
             hooks=[dict(id="mountain-fade-a", event="realm-deployed", effect="passive-shield-front-on-realm", params={"amount": 2})]),
    ),
    "xuzuozhinan": (
        dict(id="xuzuozhinan-thunder", name="天雷贯击", text="完成交战后，对敌方前线造成 1 点伤害（攻击成长简化）。",
             hooks=[dict(id="thunder-strike", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 1})]),
        dict(id="xuzuozhinan-thunder-awakened", name="万象神雷", text="完成交战后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="thunder-strike-a", event="combat-resolved", effect="passive-damage-enemy-front", params={"amount": 2})]),
    ),
    "liyujing": (
        dict(id="liyujing-bubble", name="泡泡加护", text="恢复生命时，目标获得 1 点护甲。",
             hooks=[dict(id="bubble-bestow", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 1})]),
        dict(id="liyujing-bubble-awakened", name="水镜红锦", text="恢复生命时，目标获得 2 点护甲。",
             hooks=[dict(id="bubble-bestow-a", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 2})]),
    ),
    "chongshi": (
        dict(id="chongshi-poison", name="中毒削力", text="完成交战后，使交战目标获得 1 点破甲（中毒削力简化）。",
             hooks=[dict(id="poison-weaken", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="chongshi-poison-awakened", name="剧毒蚀骨", text="完成交战后，使交战目标获得 2 点破甲。",
             hooks=[dict(id="poison-weaken-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "xieenv": (
        dict(id="xieenv-venom", name="剧毒螯针", text="完成交战后，使交战目标获得 1 点破甲。",
             hooks=[dict(id="venom-sting", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 1})]),
        dict(id="xieenv-venom-awakened", name="百蝎噬心", text="完成交战后，使交战目标获得 2 点破甲。",
             hooks=[dict(id="venom-sting-a", event="combat-resolved", effect="passive-armor-break-defender", params={"amount": 2})]),
    ),
    "xunxiangxing": (
        dict(id="xunxiangxing-erode", name="蚀印投射", text="己方回合开始时，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="erode-shot", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="xunxiangxing-erode-awakened", name="缚梦明香", text="己方回合开始时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="erode-shot-a", event="turn-started", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    "linghaidie": (
        dict(id="linghaidie-sea", name="海灵结附", text="移入战斗区简化：完成交战后，获得 1 点护甲。",
             hooks=[dict(id="sea-spirit", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1})]),
        dict(id="linghaidie-sea-awakened", name="海心共鸣", text="完成交战后，获得 2 点护甲。",
             hooks=[dict(id="sea-spirit-a", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 2})]),
    ),
    "yujuchong": (
        dict(id="yujuchong-poison", name="毒丝打脸", text="完成交战后，对敌方牌手造成 1 点伤害（毒绝简化）。",
             hooks=[dict(id="silk-venom", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="yujuchong-poison-awakened", name="破茧毒梦", text="完成交战后，对敌方牌手造成 2 点伤害并恢复 1 点生命。",
             hooks=[
                 dict(id="silk-venom-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2}),
                 dict(id="silk-venom-a2", event="combat-resolved", effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
    ),
    "hainren": (
        dict(id="hainren-venom", name="毒影免伤", text="完成交战后，获得 1 点护甲（毒目标免伤简化）。",
             hooks=[dict(id="ninja-veil", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 1})]),
        dict(id="hainren-venom-awakened", name="宿怨潜杀", text="完成交战后，获得 2 点护甲并获得 1 点力量。",
             hooks=[
                 dict(id="ninja-veil-a", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 2}),
                 dict(id="ninja-veil-a2", event="combat-resolved", effect="passive-buff-self", params={"attack": 1}),
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

    lines = []
    lines.append("/**")
    lines.append(" * 空弦·振剑·远山·鸣雷（wave6，32 式神）内容 — 由 scripts/gen-wave6-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE6_PACK_ID = 'wave6';")
    lines.append("export const WAVE6_PACK_NAME = '空弦·振剑·远山·鸣雷';")
    lines.append("export const WAVE6_SUBPACKS = Object.freeze({ kongxian: '空弦绮话', zhenjian: '振剑归川', yuanshan: '远山遥泽', minglei: '鸣雷启蛰' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE6_UNIT_DEFINITIONS = Object.freeze([")

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
        lines.append(f"    art: {js_str(f'assets/wave6/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave6/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave6')},")
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
    lines.append("function wave6Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave6',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE6_CARD_DEFINITIONS = Object.freeze([")

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
        lines.append(f"  wave6Card({official_id}, {js_str(unit_id)}, {{")
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
        lines.append(f"  wave6Card(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave6UnitIds() {")
    lines.append("  return WAVE6_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
