#!/usr/bin/env python3
"""从 research-data 官方卡表生成 game-content-classic.js（经典基础包 29 式神）。

效果尽量映射到规则层已有动作；复杂机制做可玩化简化，并在 officialText 保留卡面原文。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-classic.js"

# 与 assets/classic/ 命名一致
UNITS = [
    ("yaodaoji", 101, "妖刀姬", "呪刃", "爆发 / 连击", "#d64545", "战斗牌连打，打脸触发瞬发连锁。"),
    ("jutun-tongzi", 102, "酒吞童子", "鬼王", "成长 / 狂战", "#c45c26", "承伤叠力量，形态开大压场。"),
    ("bingyong", 103, "兵俑", "壁垒", "护甲 / 站场", "#8a7a5a", "回合叠甲，甲转力量，前排要塞。"),
    ("datiangou", 105, "大天狗", "风神", "法术 / 复读", "#5b7c99", "法术倒计时复读，风暴清场。"),
    ("xuenv", 106, "雪女", "冰华", "控制 / 眩晕", "#9bb8d4", "眩晕控场，雪球灌伤害。"),
    ("yingcao", 107, "萤草", "蒲公英", "形态 / 支援", "#7cbc6e", "形态瞬发过牌，全队续航。"),
    ("taohuayao", 108, "桃花妖", "花信", "治疗 / 复活", "#e891a8", "治疗复活叠力量，团辅核心。"),
    ("guniao", 109, "姑获鸟", "慈乌", "机动 / 突袭", "#6a8f7a", "攻击后回撤，直击与偷袭。"),
    ("bailang", 110, "白狼", "神射", "远程 / 打脸", "#b08968", "战斗伤转核心，远程点杀。"),
    ("caitongzi", 111, "茨木童子", "罗生门", "力量 / 爆发", "#a63d4a", "回合叠力，击杀连锁。"),
    ("xuetongzi", 112, "雪童子", "雪国", "眩晕 / 免伤", "#89a7c0", "与眩晕目标交战免伤。"),
    ("shantong", 113, "山童", "怪力", "贯通 / 蛮力", "#8b6914", "永久叠力，贯通溢出。"),
    ("tiaotiaodidi", 114, "跳跳弟弟", "腐毒", "破甲 / 坦度", "#6b8e23", "承伤叠破甲，再把破甲灌给对手。"),
    ("qingshe", 115, "清姬", "蛇姬", "破甲 / 转化", "#5f9e6e", "伤害转破甲，破甲爆发。"),
    ("zhen", 116, "鸩", "碧羽", "破甲 / 倒计时", "#7d5a8c", "倒计时叠破甲，毒蚀反打。"),
    ("haifangzhu", 117, "海坊主", "蹈海", "治疗 / 护甲", "#3d8fad", "过量治疗转甲，水系攻防。"),
    ("yimulian", 118, "一目连", "风符", "形态 / 倒计时", "#6f9e8f", "风符倒计时炸场，罡风循环。"),
    ("shuweng", 119, "书翁", "纪行", "过牌 / 手牌", "#7a6b8a", "手牌资源转化伤害与检索。"),
    ("jue", 120, "觉", "读心", "展示 / 压制", "#8b5e83", "展示手牌，惩罚已展示牌。"),
    ("quanshen", 121, "犬神", "心剑", "复活 / 成长", "#c9a227", "升级送心身炼磨，终盘站场。"),
    ("panguan", 122, "判官", "勾诀", "消灭 / 处决", "#4a5568", "消灭式神打核心，勾诀点杀。"),
    ("yijin-zhentian", 123, "以津真天", "金羽", "token / 灵活", "#d4a017", "黄金羽积累，风之舞清场。"),
    ("fenghuanghuo", 124, "凤凰火", "凤火", "法术 / 投射", "#e85d04", "法术触发投射，炎舞终结。"),
    ("qingfangzhu", 125, "青坊主", "佛印", "治疗 / 反伤", "#4a7c59", "治疗触发随机伤害，舍生保核。"),
    ("qingwa-ciqi", 126, "青蛙瓷器", "岭上", "运势 / 赌狗", "#55a86a", "运势判定成长，骰子炸弹。"),
    ("shantu", 127, "山兔", "萌即", "运势 / 倒计时", "#e07a5f", "运势6全队强化，戏谑套索。"),
    ("yaoginshi", 128, "妖琴师", "三歌", "倒计时 / 全能", "#9b6b9e", "三觉醒切换倒计时曲目。"),
    ("qingxingdeng", 129, "青行灯", "明灯", "鬼火 / 资源", "#2f6fed", "明灯存火，吸魂灯灌伤。"),
    ("zuofutongzi", 130, "座敷童子", "福运", "运势 / 重投", "#e9c46a", "失败重投，福运形态。"),
]

# 官方卡 id → 游戏内简化定义
# fields: name, type, level, cost, rarity, text, target, effects, keywords, timing, responseTo, starterCopies, tags, formStats, formAbility, official
# effects: list of (condition, action, target, value)

RARITY = {"R": "common", "SR": "rare", "SSR": "ssr", None: "common", "": "common", "N": "common", "SKIN": "common"}
TYPE = {"战斗": "combat", "法术": "spell", "形态": "form", "式神": None, "结界": "realm", "觉醒": "awakening", "衍生": "spell", "协战": None}


def slug(text: str) -> str:
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "card"


# 手写映射：只收录可构筑的专属牌（跳过式神卡、SKIN 重复、空描述协战）
# 简化原则见 README 附录；officialText 保留原文。
CARD_MAP: dict[int, dict] = {
    # ---- 妖刀姬 101 ----
    10101: dict(name="不祥之刃", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="妖刀姬出击。对敌方牌手造成伤害时，抽一张牌（简化为出击后抽 1 张）。",
                target="auto", effects=[("source-ready", "assault", "source", 0), ("always", "draw", "ally-player", 1)],
                tags=["出击", "过牌"]),
    10102: dict(name="见切", type="combat", level=1, cost=1, rarity="SR", starter=1, deck_limit=2,
                text="免疫本次战斗伤害。响应：当妖刀姬被攻击时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"],
                combatOption={"immuneCombatDamage": True}, tags=["响应", "防御"]),
    10103: dict(name="战意", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="妖刀姬出击，本次攻击 +2/+2。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    10104: dict(name="一闪", type="combat", level=2, cost=0, rarity="R", starter=1,
                text="不消耗鬼火。妖刀姬出击。",
                target="auto", effects=[("source-ready", "assault", "source", 0)],
                tags=["免费", "出击"]),
    10105: dict(name="妖刀万华", type="form", level=3, cost=1, rarity="R", starter=1,
                text="妖刀姬获得 +3/+8。形态：战斗时额外先击中对手一次（连击）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8})],
                keywords=["COMBO"], tags=["形态", "连击"],
                formAbility="战斗时额外先击中对手一次。"),
    10106: dict(name="杀念", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="随机将三张妖刀姬的战斗牌置入手牌。",
                target="auto", effects=[("always", "token-to-hand", "ally-player", {"tokens": ["yingdao-jianqie", "yingdao-zhanyi", "yingdao-yishan"], "count": 3})],
                tags=["补牌"]),
    10107: dict(name="觉醒·妖刀姬", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：迅捷。被动升级——对敌方牌手造成伤害时，她的战斗牌本回合不消耗鬼火。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                keywords=["INSTANT"], tags=["觉醒"]),
    10108: dict(name="禁锢之刀", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="增强：本局每消灭一个式神 +2 力量（简化为出击 +0，击杀成长见被动）。",
                target="auto", effects=[("source-ready", "assault", "source", 0)],
                tags=["成长"]),

    # ---- 酒吞童子 102 ----
    10201: dict(name="醉里乾坤", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。酒吞童子对自己造成 1 点伤害，抽一张牌。",
                target="auto", effects=[("always", "damage-self", "source", 1), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "过牌"]),
    10202: dict(name="狂气", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="本次战斗获得不屈。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("always", "grant-unyielding", "source", 1)],
                tags=["出击"]),
    10203: dict(name="神子", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="瞬发。酒吞童子获得 +6/+8 与不屈。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 8}), ("always", "grant-unyielding", "source", 1)],
                keywords=["INSTANT"], tags=["形态", "不屈"]),
    10204: dict(name="鬼王", type="form", level=2, cost=1, rarity="R", starter=1,
                text="进场时对酒吞童子造成 4 点伤害。获得 +5/+10。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 10}), ("always", "damage-self", "source", 4)],
                tags=["形态", "自伤"]),
    10205: dict(name="觉醒·酒吞童子", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：受到伤害时每受 1 点获得 1 力量。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 3})],
                tags=["觉醒"]),
    10206: dict(name="百鬼夜行", type="spell", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="瞬发。对其他所有式神各造成 3 点伤害（简化固定值；原文为本回合承伤总和）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 3)],
                keywords=["INSTANT"], tags=["瞬发", "清场"]),
    10207: dict(name="狂啸", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="本回合酒吞童子生命不会降到 1 以下。响应：将受到伤害时自动使用。",
                target="auto", effects=[("always", "grant-unyielding", "source", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["damage"], tags=["响应"]),
    10208: dict(name="无尽愤怒", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="若本回合酒吞童子受到过伤害，+2 力量。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["反击"]),

    # ---- 兵俑 103 ----
    10301: dict(name="尘刀", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击。每有 1 点护甲获得 1 点力量（简化 +2）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    10302: dict(name="不动如山", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +1/+10。形态：己方回合开始时若在战斗区获得 3 力量。",
                target="auto", effects=[("always", "form", "source", {"attack": 1, "hp": 10})],
                formAbility="己方回合开始时若在战斗区，获得 3 力量。",
                formHooks=[{"id": "form-bingyong-still", "event": "turn-started", "effect": "passive-buff-self-if-front", "params": {"attack": 3}, "priority": 40}],
                tags=["形态", "成长"]),
    10303: dict(name="冲撞", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2/+2。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    10305: dict(name="森罗之阵", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+7。形态：有护甲时至多受到等于护甲的伤害（简化：进场获得 4 护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 7}), ("always", "shield", "source", 4)],
                tags=["形态", "护甲"]),
    10306: dict(name="古尘之壁", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="进场时每有 1 点护甲，其他己方式神 +1 生命（简化：全体 +2 生命上限）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 10}), ("always", "buff-stats", "all-other-allies", {"attack": 0, "hp": 2})],
                tags=["形态", "团辅"]),
    10307: dict(name="觉醒·兵俑", type="awakening", level=2, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="获得 3 护甲。觉醒：回合开始叠 2 护甲且不移除。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 0, "hp": 0}), ("always", "shield", "source", 3)],
                tags=["觉醒"]),
    10308: dict(name="古尘之盾", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="使一个己方式神获得 5 护甲。响应：兵俑被攻击时自动对自己使用。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 5)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "护甲"]),
    10309: dict(name="尘缚之阵", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +5/+9。形态：在战斗区时敌方无法替换战斗区式神（简化：获得 3 护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 9}), ("always", "shield", "source", 3)],
                tags=["形态"]),

    # ---- 大天狗 105 ----
    10501: dict(name="黑羽之刃", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。投射：造成 2 点伤害。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 2)],
                keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射"]),
    10502: dict(name="暴风之主", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+6。形态：使用法术后对受影响敌方式神造成 1 伤（简化：法术 +1 伤已并入卡面）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                tags=["形态"]),
    10503: dict(name="天狗风乱", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="造成 6 点伤害，随机分配给所有敌方角色（简化：全体式神各 2 伤）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["清场"]),
    10504: dict(name="风神一扇", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="投射：造成 2 点伤害，目标移回准备区。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2), ("target-alive", "bounce-to-reserve", "selected-enemy", None)],
                keywords=["PROJECTILE"], tags=["投射", "控制"]),
    10506: dict(name="羽刃暴风", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对所有敌方式神造成 3 点伤害。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 3)],
                tags=["清场"]),
    10507: dict(name="觉醒·大天狗", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：使用法术后倒计时 1 再次使用该法术（简化为 +1/+1 与法术复读标记）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),
    10508: dict(name="吾即正义", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="增强：使用 10 次法术则消灭所有敌方式神（简化：对全体敌方式神造成 4 点伤害）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 4)],
                tags=["终结"]),
    10509: dict(name="暴风之盾", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="使一个己方式神获得 2 护甲。响应：战斗区式神被攻击时自动使用。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),

    # ---- 雪女 106 ----
    10605: dict(name="吹雪", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="造成 3 点伤害，将一张「雪球」置入手牌。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "token-to-hand", "ally-player", {"tokens": ["xueqiu"], "count": 1})],
                tags=["伤害", "雪球"]),
    10602: dict(name="寒冰之盾", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="使一个己方式神获得 2 护甲。响应：战斗区被攻击时自动使用。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),
    10603: dict(name="崩雪", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="眩晕一个未眩晕的式神；若已眩晕则改为造成 3 点伤害（简化）。",
                target="enemy-unit", effects=[("always", "freeze", "selected-enemy", 1)],
                tags=["控制"]),
    10604: dict(name="冰风暴", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +2/+4。形态：敌方攻击后对其造成 1 伤并眩晕。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 4})],
                formAbility="敌方式神攻击后，对其造成 1 点伤害并眩晕。",
                formHooks=[{"id": "form-xuenv-storm", "event": "combat-resolved", "effect": "passive-damage-freeze-defender", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "控制"]),
    10606: dict(name="觉醒·雪女", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：眩晕受到雪女伤害的式神。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 1})],
                tags=["觉醒"]),
    10607: dict(name="流霰", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="瞬发。对手牌中每有一张雪球造成 1 点伤害（简化：造成 3 点伤害并送 1 雪球）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3), ("always", "token-to-hand", "ally-player", {"tokens": ["xueqiu"], "count": 1})],
                keywords=["INSTANT"], tags=["瞬发"]),
    10609: dict(name="冰墙", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="在战斗区召唤冰墙（简化：获得 5 护甲并进入前线）。",
                target="auto", effects=[("always", "fortify", "source", 5)],
                tags=["护甲"]),
    10610: dict(name="寒冬之心", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="将两张雪球置入手牌。本局雪球伤害 +1。",
                target="auto", effects=[("always", "token-to-hand", "ally-player", {"tokens": ["xueqiu"], "count": 2})],
                tags=["雪球"]),

    # ---- 萤草 107 ----
    10701: dict(name="吸取", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="造成 2 点伤害，鼓舞：获得 +2 护甲。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2)],
                keywords=["ENCOURAGE"], tags=["伤害", "鼓舞"],
                encourage={"attack": 0, "shield": 2}),
    10702: dict(name="治愈之光", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+5。入场与己方回合开始时，为所有己方式神恢复 2 点生命。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 5}), ("always", "heal", "all-ally-units", 2)],
                formAbility="己方回合开始时，为所有己方式神恢复 2 点生命。",
                formHooks=[{"id": "form-yingcao-heal", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "治疗"]),
    10703: dict(name="勇气之光", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+5。入场与回合开始时鼓舞 +2 力量。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5}), ("always", "buff-stats", "source", {"attack": 2, "hp": 0})],
                formAbility="己方回合开始时，鼓舞：获得 +2 力量。",
                formHooks=[{"id": "form-yingcao-courage", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 2}, "priority": 40}],
                tags=["形态", "成长"]),
    10704: dict(name="闪烁", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="敌方战斗区式神本回合力量变为 0。响应：敌方进入战斗区时自动使用。",
                target="enemy-unit", effects=[("always", "set-attack-zero-this-turn", "selected-enemy", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "控制"]),
    10705: dict(name="安魂之光", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。入场与回合开始时你获得 1 点鬼火。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "energy-gain", "ally-player", 1)],
                formAbility="己方回合开始时，你获得 1 点鬼火。",
                formHooks=[{"id": "form-yingcao-energy", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "鬼火"]),
    10706: dict(name="虹彩", type="spell", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="将萤草的三种形态牌置入手牌。",
                target="auto", effects=[("always", "token-to-hand", "ally-player", {"tokens": ["yingcao-zhiyu", "yingcao-yongqi", "yingcao-anhun"], "count": 3})],
                tags=["补牌"]),
    10707: dict(name="觉醒·萤草", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：己方式神形态牌获得瞬发且使用时抽一张牌。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒"]),
    10708: dict(name="萤火点点", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="使一个己方式神 +1 生命或对敌方造成 1 伤（简化：己方 +2 生命并抽 1 张）。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 0, "hp": 2}), ("always", "draw", "ally-player", 1)],
                tags=["支援"]),

    # ---- 桃花妖 108 ----
    10801: dict(name="桃之馨息", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="为一个角色恢复 5 点生命。",
                target="ally-unit", effects=[("always", "heal", "selected-ally", 5)],
                tags=["治疗"]),
    10802: dict(name="花信风", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="瞬发。选择一个己方式神，随机抽一张该式神的牌。",
                target="ally-unit", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "过牌"]),
    10803: dict(name="桃之夭夭", type="spell", level=2, cost=0, rarity="SR", starter=1,
                text="不消耗鬼火。鼓舞：+2 力量与 +2 护甲。",
                target="auto", effects=[],
                keywords=["ENCOURAGE"], tags=["鼓舞"], encourage={"attack": 2, "shield": 2}),
    10804: dict(name="丰实", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+7。入场与回合开始时随机为一个受伤友方恢复 3 点生命。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7})],
                formAbility="己方回合开始时，随机为一个己方受伤式神恢复 3 点生命。",
                formHooks=[{"id": "form-taohua-rich", "event": "turn-started", "effect": "passive-heal-ally-if-front-or-any", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "治疗"]),
    10805: dict(name="盛开", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+9。入场与回合开始时治疗友军 2 点，重复 2 次。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 9}), ("always", "heal", "all-ally-units", 2)],
                formAbility="己方回合开始时，随机为己方受伤式神恢复 2 点生命，重复 2 次。",
                formHooks=[{"id": "form-taohua-bloom", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "治疗"]),
    10807: dict(name="桃华灼灼", type="spell", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="复活所有己方式神。",
                target="auto", effects=[("always", "revive-all", "all-ally-units", None)],
                tags=["复活", "团辅"]),
    10808: dict(name="桃语春风", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="复活一个己方式神并使其获得迅捷。",
                target="knocked-ally", effects=[("always", "revive", "selected-ally", 4), ("target-alive", "apply-keyword", "selected-ally", {"keywordId": "instant"})],
                tags=["复活"]),
    10809: dict(name="觉醒·桃花妖", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：治疗或复活己方式神时，使其永久获得 2 力量与 2 生命。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 1})],
                tags=["觉醒"]),

    # ---- 姑获鸟 109 ----
    10901: dict(name="伞剑", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +1。其他己方攻击后本牌获得瞬发。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                tags=["出击"]),
    10902: dict(name="影翼", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +4/+4。形态：每次攻击前获得 1 力量。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 4})],
                formAbility="攻击前获得 1 点力量。",
                formHooks=[{"id": "form-guniao-shadow", "event": "combat-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态", "成长"]),
    10903: dict(name="丛云鹤舞", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="直接攻击敌方牌手。",
                target="auto", effects=[("always", "damage", "enemy-avatar", 5)],
                tags=["打脸"]),
    10904: dict(name="金鸾", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+4。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 4})],
                tags=["形态"]),
    10905: dict(name="天翔鹤斩", type="combat", level=2, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="贯通。本次战斗改为攻击一个敌方准备区式神。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["PIERCE"], tags=["贯通", "突袭"]),
    10906: dict(name="慈乌稚子", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +8/+4。",
                target="auto", effects=[("always", "form", "source", {"attack": 8, "hp": 4})],
                tags=["形态"]),
    10907: dict(name="偷袭", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +3。响应：敌方战斗区式神气绝时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["RESPONSE"], timing="response", responseTo=["damage"], tags=["响应"]),
    10908: dict(name="觉醒·姑获鸟", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：远程。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 0})],
                keywords=["REMOTE"], tags=["觉醒"]),

    # ---- 白狼 110 ----
    11001: dict(name="起弓", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。白狼获得远程直到下一次攻击后。",
                target="auto", effects=[("always", "apply-keyword", "source", {"keywordId": "remote"})],
                keywords=["INSTANT", "REMOTE"], tags=["瞬发", "远程"]),
    11002: dict(name="离", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。白狼 +3 力量直到下一次攻击后。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 3, "hp": 0})],
                keywords=["INSTANT"], tags=["瞬发", "爆发"]),
    11003: dict(name="文射", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 -2/+2，并额外先击中目标一次。",
                target="auto", effects=[("source-ready", "assault", "source", -2)],
                keywords=["COMBO"], tags=["出击", "连击"]),
    11004: dict(name="残心", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5})],
                tags=["形态"]),
    11005: dict(name="觉醒·白狼", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：对敌方式神造成战斗伤害时，对牌手造成 4 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒"]),
    11006: dict(name="无我", type="spell", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="瞬发。白狼 +3 力量、不屈、贯通、迅捷直到下一次攻击后。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 3, "hp": 0}), ("always", "grant-unyielding", "source", 1), ("always", "apply-keyword", "source", {"keywordId": "pierce"})],
                keywords=["INSTANT"], tags=["瞬发", "爆发"]),
    11007: dict(name="会", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="下回合开始时对敌方牌手造成 8 点伤害（简化为立即造成 5 点）。",
                target="auto", effects=[("always", "damage", "enemy-avatar", 5)],
                tags=["打脸"]),
    11008: dict(name="援护", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="对敌方战斗区式神造成等同于白狼力量的伤害（简化 4 点）。响应：其他式神被攻击时自动使用。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 4)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),

    # ---- 茨木童子 111 ----
    11101: dict(name="黑焰之手", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="远程出击。",
                target="auto", effects=[("source-ready", "assault", "source", 0)],
                keywords=["REMOTE"], tags=["远程"]),
    11102: dict(name="鬼之手", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="若敌方战斗区没有式神，将一个敌方式神移入战斗区（简化：出击 +2）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    11103: dict(name="豪拳", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="茨木童子永久获得 3 点力量。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 3, "hp": 0})],
                tags=["成长"]),
    11104: dict(name="迁怒", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+7。形态：击杀战斗区式神时对准备区各造成 2 伤。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7})],
                formAbility="击杀敌方战斗区式神时，对敌方准备区式神各造成 2 点伤害。",
                formHooks=[{"id": "form-cai-rage", "event": "combat-resolved", "effect": "passive-damage-reserve-on-kill", "params": {"amount": 2}, "priority": 40}],
                tags=["形态"]),
    11105: dict(name="地狱之手", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="出击 +4。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                tags=["出击", "爆发"]),
    11106: dict(name="觉醒·茨木童子", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：己方回合开始时力量翻倍（简化：+3 力量）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 3, "hp": 1})],
                tags=["觉醒"]),
    11107: dict(name="断臂", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="力量变为本局最大值（简化：+4 力量）。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 4, "hp": 0})],
                tags=["爆发"]),
    11108: dict(name="罗生门之鬼", type="form", level=1, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="获得 +3/+4。击杀成长。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 4})],
                formAbility="击杀式神后获得 +1 力量。",
                formHooks=[{"id": "form-cai-gate", "event": "combat-resolved", "effect": "passive-growth-attack-on-kill", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "成长"]),

    # ---- 雪童子 112 ----
    11201: dict(name="雪走", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="眩晕战斗区敌方式神。响应：被攻击时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("target-alive", "freeze", "selected-enemy", 1)],
                keywords=["RESPONSE", "STUN"], timing="response", responseTo=["assault"], tags=["响应", "眩晕"]),
    11202: dict(name="霜舞", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +2。若有眩晕敌人则瞬发。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    11203: dict(name="雪国之子", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+5。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                tags=["形态"]),
    11204: dict(name="胧月雪华斩", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，并对其他眩晕敌人造成等量伤害（简化 +2 出击）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    11205: dict(name="霜天之织", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="增强：每有一个眩晕敌人 +1 力量（简化 +2）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    11206: dict(name="雪融之时", type="form", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="获得 +5/+7。至多受到 3 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 7})],
                tags=["形态", "减伤"]),
    11207: dict(name="霜风", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +1。若敌方战斗区无人则眩晕敌方牌手（简化：额外 1 点核心伤害）。",
                target="auto", effects=[("source-ready", "assault", "source", 1), ("match-active", "damage", "enemy-avatar", 1)],
                tags=["出击"]),
    11208: dict(name="觉醒·雪童子", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：攻击眩晕角色不受战斗伤害，并额外先击中一次。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 2})],
                tags=["觉醒"]),

    # ---- 山童 113 ----
    11301: dict(name="鲁莽", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+5。回合开始自动攻击（简化为回合开始 +1 力量）。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 5})],
                formAbility="己方回合开始时，山童获得 1 力量。",
                formHooks=[{"id": "form-shantong-reckless", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
                tags=["形态"]),
    11302: dict(name="怪力", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="山童永久获得 1 力量，然后出击。",
                target="auto", effects=[("always", "buff-stats", "source", {"attack": 1, "hp": 0}), ("source-ready", "assault", "source", 0)],
                tags=["成长", "出击"]),
    11303: dict(name="怒吼", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="所有己方式神 +1 力量。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 1, "hp": 0})],
                tags=["团辅"]),
    11304: dict(name="笨拙", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+9。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 9})],
                tags=["形态"]),
    11305: dict(name="碎岩", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2，并移除目标护甲。",
                target="auto", effects=[("source-ready", "assault", "source", 2), ("target-alive", "remove-shield", "selected-enemy", 99)],
                tags=["破甲"]),
    11306: dict(name="崩山", type="spell", level=3, cost=1, rarity="R", starter=1,
                text="对战斗区 4 伤、准备区 1 伤（简化：对全体敌方 2 伤）。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["清场"]),
    11307: dict(name="觉醒·山童", type="awakening", level=2, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：贯通。免疫敌方非战斗伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 0})],
                keywords=["PIERCE"], tags=["觉醒"]),
    11308: dict(name="伺机", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +2。响应：被攻击时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),

    # ---- 跳跳弟弟 114 ----
    11401: dict(name="腐坏直拳", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 -2。将自己的破甲转移到目标（简化：施加 2 破甲）。",
                target="auto", effects=[("source-ready", "assault", "source", -2), ("target-alive", "apply-armor-break", "selected-enemy", 2)],
                tags=["破甲"]),
    11402: dict(name="瘴疠体质", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +2/+9。对跳跳弟弟造成战斗伤害的式神获得 3 破甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 9})],
                formAbility="对跳跳弟弟造成战斗伤害的式神获得 3 破甲。",
                formHooks=[{"id": "form-tiao-plague", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 3}, "priority": 40}],
                tags=["形态", "破甲"]),
    11403: dict(name="毒气喷泉", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="所有敌方式神获得等同于跳跳弟弟破甲的破甲（简化：全体 2 破甲）。",
                target="auto", effects=[("always", "apply-armor-break", "all-enemy-units", 2)],
                tags=["破甲"]),
    11404: dict(name="肿胀体质", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+14。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 14})],
                tags=["形态", "坦度"]),
    11405: dict(name="尸毒体质", type="form", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="获得 +5/+14。承伤时反施破甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 14})],
                formAbility="受到 ≥3 伤害时，所有敌方角色获得 2 破甲。",
                formHooks=[{"id": "form-tiao-corpse", "event": "unit-damaged", "effect": "passive-armor-break-enemies-on-damaged", "params": {"threshold": 3, "amount": 2}, "priority": 40}],
                tags=["形态", "破甲"]),
    11406: dict(name="僵硬扑击", type="combat", level=3, cost=1, rarity="R", starter=1,
                text="瞬发，贯通。获得等同于自己破甲的力量（简化 +3）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["INSTANT", "PIERCE"], tags=["瞬发", "贯通"]),
    11408: dict(name="觉醒·跳跳弟弟", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：承伤得等量破甲并永久 +1 生命。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),
    11409: dict(name="甜蜜的负担", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。出击 +3。响应：被攻击时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                keywords=["INSTANT", "RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),

    # ---- 清姬 115 ----
    11501: dict(name="蛇行击", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。对一个式神造成 1 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 1)],
                keywords=["INSTANT"], tags=["瞬发"]),
    11502: dict(name="淬毒", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对所有敌方角色造成 2 点伤害。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2)],
                tags=["群伤"]),
    11503: dict(name="氤氲蛇姬", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+6。敌方回合结束时战斗区式神获得 2 破甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                formAbility="敌方回合结束时，敌方战斗区式神获得 2 破甲。",
                formHooks=[{"id": "form-qinghe-mist", "event": "turn-started", "effect": "passive-armor-break-enemy-front", "params": {"amount": 2}, "priority": 30}],
                tags=["形态", "破甲"]),
    11504: dict(name="无名之毒", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。投射：造成 4 点伤害。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 4)],
                keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射"]),
    11505: dict(name="焚身之火", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="使一个角色获得 2 破甲，然后对所有有破甲的敌人造成 3 点伤害（简化：目标 2 破甲 + 全体 2 伤）。",
                target="enemy-unit", effects=[("always", "apply-armor-break", "selected-enemy", 2), ("always", "damage", "all-enemy-units", 2)],
                tags=["破甲", "爆发"]),
    11506: dict(name="觉醒·清姬", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：无破甲目标受伤转破甲；破甲不清除。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒"]),
    11507: dict(name="剧毒之盾", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="使一个己方式神获得 2 护甲。响应：战斗区被攻击时自动使用。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),
    11508: dict(name="火吻之蛇", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +4/+9。敌方全体获得 1 破甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 9}), ("always", "apply-armor-break", "all-enemy-units", 1)],
                tags=["形态", "破甲"]),

    # ---- 鸩 116 ----
    11601: dict(name="鸩羽", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +2。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    11602: dict(name="鸩羽苏生", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使鸩的倒计时 -2，抽一张牌（简化：抽 1 并施加 1 破甲）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "apply-armor-break", "enemy-avatar", 1)],
                tags=["过牌", "破甲"]),
    11603: dict(name="寂寥心象", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                tags=["形态"]),
    11604: dict(name="毒蚀", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击 +4。响应：被攻击时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),
    11605: dict(name="觉醒·鸩", type="awakening", level=2, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：倒计时 2：敌方牌手获得 2 破甲。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 0}), ("always", "apply-armor-break", "enemy-avatar", 2)],
                tags=["觉醒", "破甲"]),
    11606: dict(name="碧羽散华", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +5/+7。破甲转伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 7}), ("always", "apply-armor-break", "all-enemy-units", 2)],
                tags=["形态", "破甲"]),
    11607: dict(name="毒之华", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="出击 +3，并施加 3 破甲。",
                target="auto", effects=[("source-ready", "assault", "source", 3), ("target-alive", "apply-armor-break", "selected-enemy", 3)],
                tags=["破甲"]),
    11608: dict(name="致命诱惑", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +2。吸血。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击", "吸血"]),

    # ---- 海坊主 117 ----
    11701: dict(name="治愈之水", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。为一个角色恢复 3 点生命。",
                target="ally-unit", effects=[("always", "heal", "selected-ally", 3)],
                keywords=["INSTANT"], tags=["瞬发", "治疗"]),
    11702: dict(name="灵能", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+6。为牌手恢复生命时自己也恢复。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6})],
                tags=["形态"]),
    11703: dict(name="水龙卷", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="对一个式神造成 3 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)],
                tags=["伤害"]),
    11704: dict(name="祝福之水", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。为所有己方角色恢复 3 点生命。",
                target="auto", effects=[("always", "heal", "all-ally-units", 3), ("match-active", "heal-avatar", "ally-avatar", 3)],
                keywords=["INSTANT"], tags=["瞬发", "群疗"]),
    11705: dict(name="蹈海", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +4/+9。造成战斗伤害时为其他友方恢复等量生命。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 9})],
                formAbility="造成战斗伤害时，为己方其他角色恢复等量生命。",
                formHooks=[{"id": "form-hai-tread", "event": "combat-resolved", "effect": "passive-heal-allies-on-combat", "params": {"amount": 2}, "priority": 40}],
                tags=["形态", "治疗"]),
    11706: dict(name="巨浪", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="对所有敌方式神造成 2 点伤害，自己恢复 2 点。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 2), ("always", "heal", "source", 2)],
                tags=["清场"]),
    11707: dict(name="沧海之盾", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="使一个己方式神获得 2 护甲。响应：战斗区被攻击时自动使用。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 2)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),
    11708: dict(name="觉醒·海坊主", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：过量治疗转化为力量和护甲。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 3})],
                tags=["觉醒"]),

    # ---- 一目连 118 ----
    11801: dict(name="风符·破", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。倒计时 2：投射造成 3 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "damage-enemy-front", "auto", 3)],
                formAbility="倒计时 2：投射造成 3 点伤害。",
                tags=["形态", "投射"]),
    11802: dict(name="风符·护", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+7。倒计时 2：你获得 5 护甲。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7}), ("always", "shield-self-player", "ally-player", 5)],
                tags=["形态", "护甲"]),
    11803: dict(name="罡风", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="抽两张牌。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                keywords=["INSTANT"], tags=["过牌"]),
    11804: dict(name="风符·势", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +3/+8。倒计时 2：鼓舞 +3/+3。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 8}), ("always", "buff-stats", "source", {"attack": 3, "hp": 0}), ("always", "shield", "source", 3)],
                tags=["形态", "鼓舞"]),
    11805: dict(name="风符·湮", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +4/+6。倒计时 2：消灭敌方战斗区式神（简化：对其造成 5 点伤害）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6}), ("always", "damage-enemy-front", "auto", 5)],
                tags=["形态", "解场"]),
    11806: dict(name="觉醒·一目连", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：形态进场或被消灭时触发倒计时效果。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 0})],
                tags=["觉醒"]),
    11807: dict(name="风符·龙", type="form", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="获得 +5/+8。倒计时 2：随机对敌方造成 5 点伤害。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 8}), ("always", "damage-enemy-front", "auto", 5)],
                tags=["形态", "爆发"]),
    11808: dict(name="风符·瞬", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +6/+9。响应：被攻击时自动使用。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 9})],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["形态", "响应"]),

    # ---- 书翁 119 ----
    11901: dict(name="开卷", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="抽两张牌。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                tags=["过牌"]),
    11902: dict(name="纪行", type="form", level=1, cost=1, rarity="R", starter=1,
                text="迅捷。获得 +2/+5。对牌手造成伤害时抽牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 5}), ("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["形态", "过牌"]),
    11903: dict(name="墨染", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="对一个式神造成等同于手牌一半的伤害（简化 4 点）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["伤害"]),
    11904: dict(name="明心", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+5。回合开始抽牌改为占卜（简化：多抽 1 张）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5})],
                formAbility="己方回合开始时额外抽 1 张牌。",
                formHooks=[{"id": "form-shu-mind", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "过牌"]),
    11905: dict(name="闻世", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +1/+1。每有一张其他手牌 +1/+1（简化 +4/+4）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 4})],
                tags=["形态"]),
    11906: dict(name="万象之书", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="瞬发。随机将其他己方式神的各一张牌置入手牌（简化抽 2）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                keywords=["INSTANT"], tags=["瞬发", "过牌"]),
    11907: dict(name="云游", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="瞬发。调度手牌（简化：抽 1 张）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "过牌"]),
    11908: dict(name="觉醒·书翁", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：牌库空时抽牌改为对敌方牌手造成 10 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒"]),

    # ---- 觉 120 ----
    12001: dict(name="读心", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。抽一张牌并造成 1 点伤害（展示机制简化）。",
                target="enemy-unit", effects=[("always", "draw", "ally-player", 1), ("always", "damage", "selected-enemy", 1)],
                keywords=["INSTANT"], tags=["瞬发"]),
    12002: dict(name="棒球炸弹", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对一个式神造成 2 点伤害（每有一张已展示牌 +2，简化固定 4）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["伤害"]),
    12003: dict(name="强索", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="瞬发。抽一张牌。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发"]),
    12004: dict(name="灵视", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +5/+5。对手使用已展示手牌时受伤并治疗你（简化形态数值）。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                tags=["形态"]),
    12005: dict(name="记仇", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="响应：反制伤害（简化：给己方 3 护甲）。",
                target="ally-unit", effects=[("always", "shield", "selected-ally", 3)],
                keywords=["RESPONSE"], timing="response", responseTo=["damage"], tags=["响应"]),
    12006: dict(name="心灵迷宫", type="form", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="获得 +5/+5。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 5})],
                tags=["形态"]),
    12007: dict(name="觉醒·觉", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：展示敌方所有手牌；使用已展示牌时觉 +1/+1。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),
    12008: dict(name="模仿", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +2/+2。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),

    # ---- 犬神 121 ----
    12101: dict(name="羁绊的价值", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="恢复犬神所有生命。",
                target="auto", effects=[("always", "heal", "source", 99)],
                tags=["治疗"]),
    12102: dict(name="心斩", type="combat", level=1, cost=1, rarity="R", starter=1,
                text="出击 +0/+2。",
                target="auto", effects=[("source-ready", "assault", "source", 0)],
                tags=["出击"]),
    12103: dict(name="心即归处", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="复活犬神。",
                target="knocked-ally", effects=[("always", "revive", "selected-ally", 4)],
                tags=["复活"]),
    12104: dict(name="恶·即·斩", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="出击 +4。",
                target="auto", effects=[("source-ready", "assault", "source", 4)],
                tags=["出击"]),
    12105: dict(name="心剑乱舞", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +4/+9。犬神的牌获得瞬发。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 9})],
                tags=["形态"]),
    12106: dict(name="觉醒·犬神", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：回合结束复活并永久 +1/+1。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 0, "hp": 0})],
                tags=["觉醒"]),
    12108: dict(name="心技一体", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+9。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 9})],
                tags=["形态"]),
    12109: dict(name="守护", type="combat", level=2, cost=1, rarity="SR", starter=1,
                text="出击并 +4 护盾。响应：其他式神被攻击时自动使用。",
                target="auto", effects=[("source-ready", "assault", "source", 0), ("always", "shield", "source", 4)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应", "守护"]),

    # ---- 判官 122 ----
    12201: dict(name="墨笔夺魂", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个敌方式神 -2 力量 -1 生命。",
                target="enemy-unit", effects=[("always", "debuff-stats", "selected-enemy", {"attack": -2, "hp": -1})],
                tags=["削弱"]),
    12202: dict(name="勾诀", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="消灭一个力量 ≤2 的敌方式神（简化：造成 4 点伤害）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 4)],
                tags=["解场"]),
    12203: dict(name="生死无常", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="响应：消灭双方战斗区式神（简化：对敌方战斗区造成 5 点伤害）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 5)],
                keywords=["RESPONSE"], timing="response", responseTo=["assault"], tags=["响应"]),
    12204: dict(name="无情", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。敌方气绝倒计时 +1。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5})],
                tags=["形态", "压制"]),
    12205: dict(name="死之宣告", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="消灭一个式神（简化：造成 7 点伤害）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 7)],
                tags=["解场"]),
    12206: dict(name="断罪", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+8。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                tags=["形态"]),
    12207: dict(name="觉醒·判官", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：消灭式神时对牌手 1 伤并恢复 1 生命。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),
    12208: dict(name="夺命", type="combat", level=2, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="必杀。出击 +3。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                tags=["出击", "必杀"]),

    # ---- 以津真天 123 ----
    12302: dict(name="金羽焕生", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="将两张「黄金羽」置入手牌。",
                target="auto", effects=[("always", "token-to-hand", "ally-player", {"tokens": ["huangjinyu"], "count": 2})],
                tags=["token"]),
    12303: dict(name="金风流羽", type="combat", level=2, cost=1, rarity="R", starter=1,
                text="本回合若使用过黄金羽则不消耗鬼火（简化：出击 +2）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),
    12304: dict(name="不可饶恕", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                tags=["形态"]),
    12305: dict(name="千羽风之舞", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="出击 +3/+3。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                tags=["出击"]),
    12306: dict(name="流浪之羽", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+8。使用黄金羽时对全体敌方 2 伤。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 8})],
                formAbility="使用「黄金羽」时，对所有敌方式神造成 2 点伤害。",
                tags=["形态"]),
    12307: dict(name="射怪鸟事", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="弃掉所有专属牌抽等量（简化：抽 2 张）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                keywords=["INSTANT"], tags=["过牌"]),
    12308: dict(name="觉醒·以津真天", type="awakening", level=2, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：黄金羽可指定敌方式神。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "token-to-hand", "ally-player", {"tokens": ["huangjinyu"], "count": 1})],
                tags=["觉醒"]),
    12309: dict(name="风之舞", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +1/+1，每用过黄金羽 +1（简化 +2）。",
                target="auto", effects=[("source-ready", "assault", "source", 2)],
                tags=["出击"]),

    # ---- 凤凰火 124 ----
    12401: dict(name="凤鸣", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。对敌方牌手造成 3 点伤害。",
                target="auto", effects=[("always", "damage", "enemy-avatar", 3)],
                keywords=["INSTANT"], tags=["瞬发", "打脸"]),
    12402: dict(name="瑞翔", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="对所有敌方式神造成 1 点伤害。",
                target="auto", effects=[("always", "damage", "all-enemy-units", 1)],
                tags=["群伤"]),
    12403: dict(name="焚羽", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +4/+6。非战斗伤害 +1。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 6})],
                tags=["形态"]),
    12404: dict(name="凤火", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="对一个式神造成 5 点伤害。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 5)],
                tags=["伤害"]),
    12405: dict(name="炎舞", type="spell", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="贯通。投射造成 5 点伤害。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 5)],
                keywords=["PROJECTILE", "PIERCE"], tags=["终结"]),
    12406: dict(name="出云", type="form", level=3, cost=1, rarity="SR", starter=1,
                text="获得 +5/+6。使用法术后运势 4 送凤火。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 6})],
                tags=["形态"]),
    12407: dict(name="引燃", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="对一个式神造成 2 点伤害，击杀则再对牌手 2 伤。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2), ("always", "damage", "enemy-avatar", 2)],
                tags=["伤害"]),
    12408: dict(name="觉醒·凤凰火", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：己方式神使用法术时投射造成 1 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),

    # ---- 青坊主 125 ----
    12501: dict(name="佛印", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。为双方牌手恢复 4 点生命。",
                target="auto", effects=[("always", "heal-avatar", "ally-avatar", 4)],
                keywords=["INSTANT"], tags=["瞬发", "治疗"]),
    12502: dict(name="禅心", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +1/+6。恢复生命时抽牌（简化：回合开始抽 1）。",
                target="auto", effects=[("always", "form", "source", {"attack": 1, "hp": 6})],
                formAbility="己方回合开始时，抽一张牌。",
                formHooks=[{"id": "form-qing-chan", "event": "turn-started", "effect": "passive-draw-self", "params": {"amount": 1}, "priority": 40}],
                tags=["形态", "过牌"]),
    12503: dict(name="佛光", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="为一个角色恢复 3 点，然后其操控者全体恢复 3 点。",
                target="ally-unit", effects=[("always", "heal", "selected-ally", 3), ("always", "heal", "all-ally-units", 3)],
                tags=["治疗"]),
    12504: dict(name="慈悲", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="使一个己方式神获得不屈。",
                target="ally-unit", effects=[("always", "grant-unyielding", "selected-ally", 1)],
                tags=["保护"]),
    12505: dict(name="法界唯心", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +5/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 5, "hp": 6})],
                tags=["形态"]),
    12506: dict(name="觉醒·青坊主", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="恢复 8 点生命。觉醒：恢复生命时对所有敌人造成 1 点伤害。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 0, "hp": 2}), ("always", "heal", "source", 8)],
                tags=["觉醒"]),
    12507: dict(name="舍生", type="spell", level=2, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="瞬发。牺牲青坊主，本回合免疫所有伤害（简化：青坊主获得不屈并全体 3 护甲）。",
                target="auto", effects=[("always", "grant-unyielding", "source", 1), ("always", "shield", "all-ally-units", 3)],
                keywords=["INSTANT"], tags=["瞬发", "保护"]),
    12508: dict(name="轮回", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="你的生命变为 10（简化：恢复 6 点生命）。",
                target="auto", effects=[("always", "heal-avatar", "ally-avatar", 6)],
                tags=["治疗"]),

    # ---- 青蛙瓷器 126 ----
    12601: dict(name="出千", type="combat", level=1, cost=1, rarity="R", starter=2,
                text="出击 +0/+1。运势 4：将一张出千置入手牌。",
                target="auto", effects=[("source-ready", "assault", "source", 0)],
                keywords=["FORTUNE"], tags=["出击", "运势"]),
    12602: dict(name="门前清", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +2/+9。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 9})],
                tags=["形态"]),
    12603: dict(name="岭上开花", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+7。运势成功时 +1 力量。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7})],
                tags=["形态", "成长"]),
    12604: dict(name="骰子炸弹", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="运势 1：对一个敌人造成等同骰子点数的伤害（简化：造成 3 点伤害）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)],
                keywords=["FORTUNE"], tags=["伤害", "运势"]),
    12605: dict(name="转运", type="combat", level=3, cost=1, rarity="SR", starter=1,
                text="攻击后运势 4：再次使用此牌（简化：出击 +3）。",
                target="auto", effects=[("source-ready", "assault", "source", 3)],
                tags=["出击"]),
    12606: dict(name="觉醒·青蛙瓷器", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：运势成功回合获得 2 力量。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 2, "hp": 2})],
                tags=["觉醒"]),
    12608: dict(name="九莲宝灯", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +3/+3。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 3})],
                tags=["形态"]),
    12609: dict(name="立直", type="combat", level=1, cost=1, rarity="SR", starter=1,
                text="出击 +1。响应：运势 4 免疫战斗伤害。",
                target="auto", effects=[("source-ready", "assault", "source", 1)],
                keywords=["RESPONSE", "FORTUNE"], timing="response", responseTo=["assault"], tags=["响应"]),

    # ---- 山兔 127 ----
    12701: dict(name="谁还不听话", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。投射造成 2 点伤害。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 2)],
                keywords=["INSTANT", "PROJECTILE"], tags=["瞬发", "投射"]),
    12702: dict(name="送祝福", type="spell", level=1, cost=1, rarity="SR", starter=1,
                text="使一个式神 +1/+1。",
                target="ally-unit", effects=[("always", "buff-stats", "selected-ally", {"attack": 1, "hp": 1})],
                tags=["团辅"]),
    12706: dict(name="快来保护我", type="form", level=2, cost=1, rarity="R", starter=1,
                text="获得 +6/+6。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6})],
                tags=["形态"]),
    12707: dict(name="觉醒·山兔", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：回合开始运势 6：其他式神倒计时 -1 并 +2 力量。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),
    12708: dict(name="萌即正义", type="form", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="获得 +6/+6。你投骰子总是 6（简化：全体 +1/+1）。",
                target="auto", effects=[("always", "form", "source", {"attack": 6, "hp": 6}), ("always", "buff-stats", "all-other-allies", {"attack": 1, "hp": 1})],
                tags=["形态", "运势"]),
    12710: dict(name="这把算我赢", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="增强：投出十次 6 则获胜（简化：对敌方核心造成 6 点伤害）。",
                target="auto", effects=[("always", "damage", "enemy-avatar", 6)],
                tags=["终结"]),
    12711: dict(name="戏谑套索", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="眩晕敌方战斗区式神。响应：被攻击时自动使用。",
                target="auto", effects=[("always", "freeze", "selected-enemy", 1)],
                keywords=["RESPONSE", "STUN"], timing="response", responseTo=["assault"], tags=["控制"]),
    12712: dict(name="来打我呀", type="spell", level=2, cost=1, rarity="R", starter=1,
                text="使一个敌方式神立刻发动攻击（简化：对其造成 3 点伤害）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 3)],
                tags=["伤害"]),

    # ---- 妖琴师 128 ----
    12801: dict(name="觉醒·入阵歌", type="awakening", level=1, cost=1, rarity="R", starter=1, deck_limit=1,
                text="觉醒：倒计时 3：造成 4 点伤害随机分配（简化：对全体敌方 1 伤）。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 0, "hp": 1}), ("always", "damage", "all-enemy-units", 1)],
                tags=["觉醒", "曲目"]),
    12802: dict(name="觉醒·神乐歌", type="awakening", level=2, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：倒计时 3：其他式神倒计时 -1 并 +1/+1。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 0}), ("always", "buff-stats", "all-other-allies", {"attack": 1, "hp": 1})],
                tags=["觉醒", "曲目"]),
    12803: dict(name="觉醒·镇魂歌", type="awakening", level=3, cost=1, rarity="SSR", starter=1, deck_limit=1,
                text="觉醒：倒计时 3：抽一张牌，获得 1 点鬼火。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1}), ("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 1)],
                tags=["觉醒", "曲目"]),
    12804: dict(name="惊弦", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="使一个式神的倒计时 -2（简化：造成 2 点伤害或治疗 2 点）。",
                target="enemy-unit", effects=[("always", "damage", "selected-enemy", 2)],
                tags=["伤害"]),
    12805: dict(name="疯魔琴心", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="重置所有敌方角色倒计时（简化：全体敌方眩晕 1 回合）。",
                target="auto", effects=[("always", "freeze", "all-enemy-units", 1)],
                tags=["控制"]),
    12806: dict(name="余音", type="spell", level=3, cost=1, rarity="SR", starter=1,
                text="其他友方倒计时 -1（简化：全体友方 +1/+1）。",
                target="auto", effects=[("always", "buff-stats", "all-other-allies", {"attack": 1, "hp": 1})],
                tags=["团辅"]),
    12807: dict(name="魔音扰心", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="敌方下一张牌无效（简化：抽 1 并眩晕敌方前线）。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "freeze", "selected-enemy", 1)],
                keywords=["RESPONSE"], timing="response", responseTo=["damage"], tags=["响应"]),
    12808: dict(name="大合奏", type="spell", level=1, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="增强：视基础能力生效种类追加效果（简化：全体 +2/+2 并抽 1）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 2}), ("always", "draw", "ally-player", 1)],
                tags=["团辅", "终结"]),

    # ---- 青行灯 129 ----
    12901: dict(name="明灯", type="spell", level=1, cost=1, rarity="R", starter=2,
                text="瞬发。你获得 1 点鬼火。",
                target="auto", effects=[("always", "energy-gain", "ally-player", 1)],
                keywords=["INSTANT"], tags=["瞬发", "鬼火"]),
    12902: dict(name="青灯夜谈", type="spell", level=1, cost=1, rarity="R", starter=1,
                text="检视牌库顶三张选一（简化：抽 2 张牌）。",
                target="auto", effects=[("always", "draw", "ally-player", 2)],
                tags=["过牌"]),
    12903: dict(name="百闻一得", type="spell", level=2, cost=1, rarity="SR", starter=1,
                text="弃一张明灯，最低等级式神 +1 级（简化：抽 1 张）。",
                target="auto", effects=[("always", "draw", "ally-player", 1)],
                tags=["升勾"]),
    12905: dict(name="幽光之火", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +4/+5。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5})],
                tags=["形态"]),
    12906: dict(name="不灭之火", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +4/+5。被消灭时消耗 1 鬼火返回（简化：获得 2 护甲）。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "shield", "source", 2)],
                tags=["形态"]),
    12907: dict(name="吸魂灯", type="spell", level=3, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="投射造成 4 点伤害，每有 1 鬼火重复一次，然后清空鬼火（简化：造成 6 点）。",
                target="auto", effects=[("always", "damage-enemy-front", "auto", 6)],
                keywords=["PROJECTILE"], tags=["终结"]),
    12908: dict(name="百物语之火", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。回合结束获得 1 鬼火。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5})],
                formAbility="己方回合结束时，你获得 1 点鬼火。",
                tags=["形态", "鬼火"]),
    12909: dict(name="觉醒·青行灯", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：对手回合开始若有剩余鬼火则获得明灯；鬼火可存至 4。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 1})],
                tags=["觉醒"]),

    # ---- 座敷童子 130 ----
    13001: dict(name="金运大吉", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +3/+6。回合开始双方运势 4：抽牌。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 6}), ("always", "draw", "ally-player", 1)],
                tags=["形态", "过牌"]),
    13002: dict(name="五谷丰壤", type="form", level=1, cost=1, rarity="R", starter=1,
                text="获得 +2/+7。回合开始双方运势 4：恢复 3 点生命。",
                target="auto", effects=[("always", "form", "source", {"attack": 2, "hp": 7}), ("always", "heal", "all-ally-units", 3)],
                tags=["形态", "治疗"]),
    13003: dict(name="家内安全", type="form", level=2, cost=1, rarity="SR", starter=1,
                text="获得 +3/+7。攻击后运势 4 失败则眩晕。",
                target="auto", effects=[("always", "form", "source", {"attack": 3, "hp": 7})],
                formAbility="敌方攻击后运势 4：失败则眩晕其。",
                tags=["形态", "控制"]),
    13004: dict(name="福运昌隆", type="spell", level=2, cost=1, rarity="R", starter=2,
                text="抽一张牌。运势 4：获得 2 点鬼火。",
                target="auto", effects=[("always", "draw", "ally-player", 1), ("always", "energy-gain", "ally-player", 2)],
                tags=["过牌", "鬼火"]),
    13005: dict(name="觉醒·座敷童子", type="awakening", level=3, cost=1, rarity="SR", starter=1, deck_limit=1,
                text="觉醒：运势失败时重投一次。",
                target="auto", effects=[("always", "awaken", "source", {"attack": 1, "hp": 3})],
                tags=["觉醒"]),
    13006: dict(name="和气满满", type="form", level=3, cost=1, rarity="R", starter=1,
                text="获得 +0/+7。",
                target="auto", effects=[("always", "form", "source", {"attack": 0, "hp": 7})],
                tags=["形态"]),
    13007: dict(name="福寿双全", type="form", level=1, cost=1, rarity="SR", starter=1,
                text="获得 +4/+5。进场双方各获得 1 点鬼火。",
                target="auto", effects=[("always", "form", "source", {"attack": 4, "hp": 5}), ("always", "energy-gain", "ally-player", 1)],
                tags=["形态", "鬼火"]),
    13008: dict(name="福满乾坤", type="spell", level=1, cost=1, rarity="SSR", starter=1, deck_limit=2,
                text="增强：双方运势成功 15 次则重置（简化：己方全体 +2/+2 并恢复 5 点核心生命）。",
                target="auto", effects=[("always", "buff-stats", "all-ally-units", {"attack": 2, "hp": 2}), ("always", "heal-avatar", "ally-avatar", 5)],
                tags=["终结"]),
}

# 共享 token 牌（不进构筑，token-to-hand 生成）
TOKENS = [
    dict(id="xueqiu", unitId="xuenv", name="雪球", type="spell", level=1, cost=0, rarity="common",
         text="造成 1 点伤害。", target="enemy-unit",
         effects=[("always", "damage", "selected-enemy", 1)], token=True, tags=["token"]),
    dict(id="huangjinyu", unitId="yijin-zhentian", name="黄金羽", type="spell", level=1, cost=0, rarity="common",
         text="造成 2 点伤害。", target="enemy-unit",
         effects=[("always", "damage", "selected-enemy", 2)], token=True, tags=["token"]),
    dict(id="mingdeng", unitId="qingxingdeng", name="明灯", type="spell", level=1, cost=0, rarity="common",
         text="瞬发。你获得 1 点鬼火。", target="auto",
         effects=[("always", "energy-gain", "ally-player", 1)], token=True, keywords=["INSTANT"], tags=["token"]),
    dict(id="yingdao-jianqie", unitId="yaodaoji", name="不祥之刃", type="combat", level=1, cost=1, rarity="common",
         text="出击。", target="auto",
         effects=[("source-ready", "assault", "source", 0)], token=True, tags=["token", "战斗"]),
    dict(id="yingdao-zhanyi", unitId="yaodaoji", name="战意", type="combat", level=2, cost=1, rarity="common",
         text="出击 +2。", target="auto",
         effects=[("source-ready", "assault", "source", 2)], token=True, tags=["token", "战斗"]),
    dict(id="yingdao-yishan", unitId="yaodaoji", name="一闪", type="combat", level=2, cost=0, rarity="common",
         text="不消耗鬼火。出击。", target="auto",
         effects=[("source-ready", "assault", "source", 0)], token=True, tags=["token", "战斗"]),
    dict(id="yingcao-zhiyu", unitId="yingcao", name="治愈之光", type="form", level=1, cost=1, rarity="common",
         text="获得 +2/+5。", target="auto",
         effects=[("always", "form", "source", {"attack": 2, "hp": 5})], token=True, tags=["token", "形态"]),
    dict(id="yingcao-yongqi", unitId="yingcao", name="勇气之光", type="form", level=2, cost=1, rarity="common",
         text="获得 +3/+5。", target="auto",
         effects=[("always", "form", "source", {"attack": 3, "hp": 5})], token=True, tags=["token", "形态"]),
    dict(id="yingcao-anhun", unitId="yingcao", name="安魂之光", type="form", level=3, cost=1, rarity="common",
         text="获得 +4/+5。", target="auto",
         effects=[("always", "form", "source", {"attack": 4, "hp": 5})], token=True, tags=["token", "形态"]),
]

# 被动映射：role -> (passive, awakenedPassive)
PASSIVES = {
    101: (
        dict(id="yaodaoji-flurry", name="呪刃连袭", text="对敌方牌手造成伤害时，她的战斗牌本回合获得瞬发。",
             hooks=[dict(id="flurry", event="avatar-damaged", effect="passive-buff-self", params={"attack": 0})]),
        dict(id="yaodaoji-flurry-awakened", name="万华一意", text="对敌方牌手造成伤害时，战斗牌本回合不消耗鬼火。",
             hooks=[dict(id="flurry-a", event="avatar-damaged", effect="passive-buff-self", params={"attack": 1})]),
    ),
    102: (
        dict(id="jutun-rage", name="鬼王之怒", text="受到伤害时，获得 1 点力量。",
             hooks=[dict(id="rage", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 1})]),
        dict(id="jutun-rage-awakened", name="无尽愤怒", text="受到伤害时，每受 1 点伤害获得 1 点力量。",
             hooks=[dict(id="rage-a", event="unit-damaged", effect="passive-buff-self-on-damaged", params={"attack": 1, "perDamage": True})]),
    ),
    103: (
        dict(id="bingyong-armor", name="岩壁", text="己方回合开始时，获得 2 点护甲。",
             hooks=[dict(id="armor", event="turn-started", effect="passive-shield-self", params={"amount": 2})]),
        dict(id="bingyong-armor-awakened", name="山岳壁垒", text="己方回合开始时获得 2 点护甲，且护甲不清除。",
             hooks=[dict(id="armor-a", event="turn-started", effect="passive-shield-self", params={"amount": 2})]),
    ),
    105: (
        dict(id="datiangou-echo", name="风暴复读", text="使用法术后，对敌方前线造成 1 点伤害（倒计时复读简化）。",
             hooks=[dict(id="echo", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 1})]),
        dict(id="datiangou-echo-awakened", name="吾即风暴", text="使用法术后，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="echo-a", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 2})]),
    ),
    106: (
        dict(id="xuenv-snowball", name="雪华", text="眩晕敌方式神时，将一张雪球置入手牌。",
             hooks=[dict(id="snowball", event="passive-triggered", effect="passive-buff-self", params={"attack": 0})]),
        dict(id="xuenv-snowball-awakened", name="绝对零度", text="眩晕受到雪女伤害的式神。",
             hooks=[dict(id="zero", event="unit-damaged", effect="passive-freeze-brittle-combat-defender", params={"amount": 0})]),
    ),
    107: (
        dict(id="yingcao-light", name="蒲公英之光", text="形态牌获得瞬发，且使用时抽一张牌。",
             hooks=[dict(id="light", event="card-played", effect="passive-draw-self-on-form", params={"amount": 1})]),
        dict(id="yingcao-light-awakened", name="虹光普照", text="己方式神形态牌获得瞬发且使用时抽一张牌。",
             hooks=[dict(id="light-a", event="card-played", effect="passive-draw-self-on-form", params={"amount": 1})]),
    ),
    108: (
        dict(id="taohua-bloom", name="花信", text="治疗或复活己方式神时，使该式神获得 1 点力量。",
             hooks=[dict(id="bloom", event="unit-healed", effect="passive-buff-healed-attack", params={"amount": 1})]),
        dict(id="taohua-bloom-awakened", name="灼灼其华", text="治疗或复活己方式神时，使其永久获得 2 力量与 2 生命。",
             hooks=[dict(id="bloom-a", event="unit-healed", effect="passive-buff-healed-attack", params={"amount": 2, "hp": 2})]),
    ),
    109: (
        dict(id="guniao-retreat", name="慈乌回风", text="攻击后，退回准备区。",
             hooks=[dict(id="retreat", event="combat-resolved", effect="passive-return-to-reserve", params={})]),
        dict(id="guniao-retreat-awakened", name="天翔", text="攻击后退回准备区，并获得远程。",
             hooks=[dict(id="retreat-a", event="combat-resolved", effect="passive-return-to-reserve", params={"shield": 1})]),
    ),
    110: (
        dict(id="bailang-snipe", name="贯心", text="己方回合对敌方式神造成战斗伤害时，对敌方牌手造成 2 点伤害。",
             hooks=[dict(id="snipe", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
        dict(id="bailang-snipe-awakened", name="无我之箭", text="对敌方式神造成伤害时，对牌手造成 4 点伤害。",
             hooks=[dict(id="snipe-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 4})]),
    ),
    111: (
        dict(id="cai-grow", name="罗生门之力", text="己方回合开始时，获得 1 点力量。",
             hooks=[dict(id="grow", event="turn-started", effect="passive-buff-self", params={"attack": 1})]),
        dict(id="cai-grow-awakened", name="地狱之握", text="己方回合开始时，获得 2 点力量。",
             hooks=[dict(id="grow-a", event="turn-started", effect="passive-buff-self", params={"attack": 2})]),
    ),
    112: (
        dict(id="xuetong-cold", name="雪国之子", text="与眩晕单位交战时不受战斗伤害。",
             hooks=[dict(id="cold", event="combat-resolved", effect="passive-shield-self-after-combat", params={"amount": 0})]),
        dict(id="xuetong-cold-awakened", name="胧月", text="攻击眩晕角色时不受战斗伤害，并额外先击中一次。",
             hooks=[dict(id="cold-a", event="combat-resolved", effect="passive-buff-self", params={"attack": 1})]),
    ),
    113: (
        dict(id="shantong-pierce", name="怪力贯通", text="贯通：过量伤害转移给敌方牌手。",
             hooks=[dict(id="pierce", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="shantong-pierce-awakened", name="崩山", text="贯通，且免疫敌方非战斗伤害。",
             hooks=[dict(id="pierce-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    114: (
        dict(id="tiao-break", name="腐毒之体", text="受到伤害时，获得等量的破甲。",
             hooks=[dict(id="break", event="unit-damaged", effect="passive-armor-break-self-on-damaged", params={})]),
        dict(id="tiao-break-awakened", name="尸毒觉醒", text="受到伤害时获得等量破甲并永久 +1 生命。",
             hooks=[dict(id="break-a", event="unit-damaged", effect="passive-armor-break-self-on-damaged", params={"hp": 1})]),
    ),
    115: (
        dict(id="qinghe-convert", name="蛇毒转化", text="对无破甲角色造成的伤害转化为等量破甲。",
             hooks=[dict(id="convert", event="unit-damaged", effect="passive-armor-break-enemy-on-damage", params={"amount": 1})]),
        dict(id="qinghe-convert-awakened", name="焚身之毒", text="伤害转破甲，且破甲不清除。",
             hooks=[dict(id="convert-a", event="unit-damaged", effect="passive-armor-break-enemy-on-damage", params={"amount": 2})]),
    ),
    116: (
        dict(id="zhen-countdown", name="碧羽之毒", text="回合开始时，使敌方牌手获得 2 破甲。",
             hooks=[dict(id="count", event="turn-started", effect="passive-armor-break-enemy-avatar", params={"amount": 2})]),
        dict(id="zhen-countdown-awakened", name="剧毒蚀心", text="回合开始时，使敌方牌手获得 3 破甲。",
             hooks=[dict(id="count-a", event="turn-started", effect="passive-armor-break-enemy-avatar", params={"amount": 3})]),
    ),
    117: (
        dict(id="hai-overflow", name="蹈海之愈", text="对己方造成的过量治疗转化为护甲。",
         hooks=[dict(id="overflow", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 1})]),
        dict(id="hai-overflow-awakened", name="沧海之力", text="过量治疗转化为力量和护甲。",
             hooks=[dict(id="overflow-a", event="unit-healed", effect="passive-shield-on-overheal", params={"amount": 1, "attack": 1})]),
    ),
    118: (
        dict(id="yimu-wind", name="风符", text="使用形态牌时，对敌方前线造成 1 点伤害。",
             hooks=[dict(id="wind", event="card-played", effect="passive-damage-enemy-front-on-form", params={"amount": 1})]),
        dict(id="yimu-wind-awakened", name="风神", text="使用形态牌时，对敌方前线造成 2 点伤害。",
             hooks=[dict(id="wind-a", event="card-played", effect="passive-damage-enemy-front-on-form", params={"amount": 2})]),
    ),
    119: (
        dict(id="shu-archive", name="纪行", text="起始手牌 +1；对牌手造成伤害时抽一张牌。",
             hooks=[dict(id="archive", event="avatar-damaged", effect="passive-draw-self", params={"amount": 1})]),
        dict(id="shu-archive-awakened", name="万象之书", text="对牌手造成伤害时抽一张牌，手牌上限 +2。",
             hooks=[dict(id="archive-a", event="avatar-damaged", effect="passive-draw-self", params={"amount": 1})]),
    ),
    120: (
        dict(id="jue-gaze", name="读心", text="己方回合开始时，随机对一个敌方式神造成 1 点伤害（展示简化）。",
             hooks=[dict(id="gaze", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="jue-gaze-awakened", name="心灵迷宫", text="己方回合开始时，随机对一个敌方式神造成 2 点伤害。",
             hooks=[dict(id="gaze-a", event="turn-started", effect="passive-damage-random-enemy", params={"amount": 2})]),
    ),
    121: (
        dict(id="quanshen-heart", name="心身炼磨", text="升级时，将一张「心身炼磨」置入手牌。",
             hooks=[dict(id="heart", event="unit-leveled", effect="passive-token-to-hand", params={"tokens": ["xinshen-lianmo"], "count": 1})]),
        dict(id="quanshen-heart-awakened", name="心即归处", text="回合结束时若气绝则复活并 +1/+1。",
             hooks=[dict(id="heart-a", event="turn-started", effect="passive-buff-self", params={"attack": 1, "hp": 1})]),
    ),
    122: (
        dict(id="panguan-ledger", name="勾决生死", text="消灭式神时，对敌方牌手造成 1 点伤害并恢复 1 点生命。",
             hooks=[dict(id="ledger", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 1})]),
        dict(id="panguan-ledger-awakened", name="无情", text="消灭式神时，对敌方牌手造成 2 点伤害并恢复 2 点生命。",
             hooks=[dict(id="ledger-a", event="combat-resolved", effect="passive-damage-avatar-after-reserve-combat", params={"amount": 2})]),
    ),
    123: (
        dict(id="yijin-feather", name="黄金羽", text="回合开始时，将一张「黄金羽」置入手牌。",
             hooks=[dict(id="feather", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["huangjinyu"], "count": 1})]),
        dict(id="yijin-feather-awakened", name="千羽", text="回合开始时，将两张「黄金羽」置入手牌。",
             hooks=[dict(id="feather-a", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["huangjinyu"], "count": 2})]),
    ),
    124: (
        dict(id="fenghuang-projectile", name="凤火投射", text="使用法术牌时，投射：造成 1 点伤害。",
             hooks=[dict(id="proj", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 1})]),
        dict(id="fenghuang-projectile-awakened", name="涅槃", text="己方式神使用法术牌时，投射：造成 1 点伤害。",
             hooks=[dict(id="proj-a", event="card-played", effect="passive-damage-enemy-front-on-spell", params={"amount": 1})]),
    ),
    125: (
        dict(id="qing-retaliate", name="佛音反照", text="恢复生命时，随机对两个敌方角色造成 1 点伤害。",
             hooks=[dict(id="retri", event="unit-healed", effect="passive-damage-random-enemy", params={"amount": 1})]),
        dict(id="qing-retaliate-awakened", name="法界唯心", text="恢复生命时，对所有敌人造成 1 点伤害。",
             hooks=[dict(id="retri-a", event="unit-healed", effect="passive-damage-random-enemy", params={"amount": 1, "all": True})]),
    ),
    126: (
        dict(id="qingwa-luck", name="岭上开花", text="运势判定成功过的回合，获得 2 点力量。",
             hooks=[dict(id="luck", event="fortune-rolled", effect="passive-buff-self", params={"attack": 2})]),
        dict(id="qingwa-luck-awakened", name="九莲宝灯", text="运势成功后效果触发两次。",
             hooks=[dict(id="luck-a", event="fortune-rolled", effect="passive-buff-self", params={"attack": 2})]),
    ),
    127: (
        dict(id="shantu-luck", name="萌即正义", text="己方回合开始时，运势 6：其他己方式神倒计时 -1 并获得 1 力量。",
             hooks=[dict(id="luck", event="turn-started", effect="passive-buff-other-allies", params={"attack": 1})]),
        dict(id="shantu-luck-awakened", name="这把算我赢", text="己方回合开始时，其他己方式神获得 2 力量。",
             hooks=[dict(id="luck-a", event="turn-started", effect="passive-buff-other-allies", params={"attack": 2})]),
    ),
    128: (
        dict(id="yaoqin-song", name="三重曲", text="回合开始时，为所有己方角色恢复 2 点生命。",
             hooks=[dict(id="song", event="turn-started", effect="passive-heal-all-allies", params={"amount": 2})]),
        dict(id="yaoqin-song-awakened", name="大合奏", text="回合开始时，为所有己方角色恢复 3 点生命并抽一张牌。",
             hooks=[dict(id="song-a", event="turn-started", effect="passive-heal-all-allies", params={"amount": 3})]),
    ),
    129: (
        dict(id="qingteng-lantern", name="明灯", text="对手回合开始时若你有剩余鬼火，获得一张「明灯」。",
             hooks=[dict(id="lantern", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["mingdeng"], "count": 1})]),
        dict(id="qingteng-lantern-awakened", name="百物语", text="获得一张「明灯」并恢复 1 点生命。",
             hooks=[dict(id="lantern-a", event="turn-started", effect="passive-token-to-hand", params={"tokens": ["mingdeng"], "count": 1})]),
    ),
    130: (
        dict(id="zuofu-reroll", name="福运重投", text="运势失败时重投一次（简化：回合开始获得 1 护甲）。",
             hooks=[dict(id="reroll", event="turn-started", effect="passive-shield-self", params={"amount": 1})]),
        dict(id="zuofu-reroll-awakened", name="福寿双全", text="运势失败时重投，并获得 2 护甲。",
             hooks=[dict(id="reroll-a", event="turn-started", effect="passive-shield-self", params={"amount": 2})]),
    ),
}

EXTRA_TOKENS = [
    dict(id="xinshen-lianmo", unitId="quanshen", name="心身炼磨", type="spell", level=1, cost=0, rarity="common",
         text="使犬神永久获得 +1/+1。", target="auto",
         effects=[("always", "buff-stats", "source", {"attack": 1, "hp": 1})], token=True, tags=["token"]),
]


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
                # map INSTANT -> instant etc
                mapping = {"instant": "instant", "remote": "remote", "pierce": "pierce", "combo": "combo"}
                step[3]["keywordId"] = mapping.get(step[3]["keywordId"], step[3]["keywordId"])


def normalize_starters() -> None:
    """每名式神起始构筑恰好 8 张；妖琴师仅保留 1 张觉醒类型。"""
    # 妖琴师三首曲目：只留镇魂歌为觉醒，其余改为法术（仍保留觉醒效果文本）
    for oid, t in ((12801, "spell"), (12802, "spell")):
        if CARD_MAP.get(oid, {}).get("type") == "awakening":
            CARD_MAP[oid]["type"] = t
            CARD_MAP[oid]["name"] = CARD_MAP[oid]["name"].replace("觉醒·", "")

    by_unit: dict[int, list[tuple[int, dict]]] = {}
    for oid, meta in CARD_MAP.items():
        by_unit.setdefault(oid // 100, []).append((oid, meta))
    for role, items in by_unit.items():
        # 按 starter 降序、官方 id 升序裁剪到 8
        items_sorted = sorted(items, key=lambda kv: (-(kv[1].get("starter") or 0), kv[0]))
        total = sum((m.get("starter") or 0) for _, m in items_sorted)
        for oid, meta in items_sorted:
            if total <= 8:
                break
            cut = min(total - 8, meta.get("starter") or 0)
            meta["starter"] = (meta.get("starter") or 0) - cut
            total -= cut
        # 经典包默认构筑最多 1 张 SSR（其余 SSR 走收藏/全卡试用）
        ssr_starters = [(oid, m) for oid, m in items_sorted if m.get('rarity') == 'SSR' and (m.get('starter') or 0) > 0]
        if len(ssr_starters) > 1:
            for oid, meta in ssr_starters[1:]:
                cut = meta.get('starter') or 0
                meta['starter'] = 0
                total -= cut
            # 把额度还给非 SSR
            need = 8 - total
            for oid, meta in items_sorted:
                if need <= 0:
                    break
                if meta.get('rarity') == 'SSR' or meta.get('type') == 'awakening':
                    continue
                room = min(need, (meta.get('deck_limit') or 2) - (meta.get('starter') or 0))
                if room > 0:
                    meta['starter'] = (meta.get('starter') or 0) + room
                    need -= room
                    total += room
        # 不足 8 时优先补觉醒/高稀有
        if total < 8:
            for oid, meta in items_sorted:
                if total >= 8:
                    break
                if meta.get("type") == "awakening" or meta.get("rarity") == "SSR":
                    room = min(8 - total, (meta.get("deck_limit") or 2) - (meta.get("starter") or 0))
                    if room > 0:
                        meta["starter"] = (meta.get("starter") or 0) + room
                        total += room


def main() -> None:
    normalize_keywords()
    normalize_starters()
    cards = json.loads((DATA / "cards.json").read_text(encoding="utf-8"))
    shiks = {s["name"]: s for s in json.loads((DATA / "shikigami.json").read_text(encoding="utf-8"))}
    by_id = {int(c["id"]): c for c in cards}

    lines = []
    lines.append("/**")
    lines.append(" * 经典基础包（29 式神）内容 — 由 scripts/gen-classic-content.py 生成。")
    lines.append(" * 卡面原文见 officialText；效果为可玩化映射，复杂机制已在 text 中标注简化。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const CLASSIC_PACK_ID = 'classic';")
    lines.append("export const CLASSIC_PACK_NAME = '经典（基础包）';")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const CLASSIC_UNIT_DEFINITIONS = Object.freeze([")

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
        lines.append(f"    art: {js_str(f'assets/classic/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/classic/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('classic')},")
        lines.append(f"    officialRole: {js_str(str(role))},")
        lines.append(f"    officialAbility: {js_str(shik.get('ability') or '')},")
        lines.append("    passive: passive(" + js_str(pid["id"]) + ", " + js_str(pid["name"]) + ", " + js_str(pid["text"]) + ", [\n" + pid_h + "\n    ]),")
        lines.append("    awakenedPassive: passive(" + js_str(aid["id"]) + ", " + js_str(aid["name"]) + ", " + js_str(aid["text"]) + ", [\n" + aid_h + "\n    ]),")
        lines.append("  },")

    lines.append("]);")
    lines.append("")

    # cards
    lines.append("function eff(condition, action, target, value = null) {")
    lines.append("  return { condition, action, target, value };")
    lines.append("}")
    lines.append("")
    lines.append("function classicCard(officialId, unitId, meta) {")
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
    lines.append("    pack: 'classic',")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("    ...(meta.combatOption ? { combatOption: Object.freeze(meta.combatOption) } : {}),")
    lines.append("    ...(meta.encourage ? { encourage: Object.freeze(meta.encourage) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const CLASSIC_CARD_DEFINITIONS = Object.freeze([")

    used_ids = set()
    for official_id, meta in sorted(CARD_MAP.items(), key=lambda kv: (kv[1].get("id") or f"c{kv[0]}", kv[0])):
        unit_id = next((u[0] for u in UNITS if u[1] == int(str(official_id)[:3])), None)
        # find unit by role prefix
        role = int(str(official_id)[:3]) if official_id >= 10000 else int(str(official_id)[:3])
        # actually ids like 10101 -> role 101
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
        # normalize meta into classicCard call
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
        # effects as tuples
        effs = meta.get("effects") or []
        eff_s = ",\n".join(
            "      [%s, %s, %s, %s]" % (
                js_str(c), js_str(a), js_str(t),
                json.dumps(v, ensure_ascii=False) if v is not None else "null",
            ) for c, a, t, v in effs
        )
        if eff_s:
            body.append("effects: [\n" + eff_s + ",\n    ]")
        lines.append(f"  classicCard({official_id}, {js_str(unit_id)}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    # tokens + extra
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
        lines.append(f"  classicCard(0, {js_str(tok['unitId'])}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getClassicUnitIds() {")
    lines.append("  return CLASSIC_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} mapped_cards={len(CARD_MAP)} tokens={len(TOKENS)+len(EXTRA_TOKENS)}")


if __name__ == "__main__":
    main()
