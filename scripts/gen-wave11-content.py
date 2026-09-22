#!/usr/bin/env python3
"""生成 game-content-wave11.js（衍生式神，10 个独立可玩式神）。

单位灵感来自 research-data/token-derivatives.md 的召唤/衍生 token，
但为独立可玩式神（非 token 卡条目）。效果仅映射规则层已有动作。
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game-content-wave11.js"

# (uid, name, title, role, strategy, atk, hp, color, officialAbility, passive, awakenedPassive)
# passive/awakened: (id, name, text, hooks[(id, event, effect, params)])
UNITS = [
    ("fanqie", "番茄", "忠犬", "忠犬 / 守护",
     "忠犬护主叠甲，赤诚撕咬反打。",
     3, 5, "#e06040",
     "跳跳妹妹召唤的忠犬「番茄」，以身护主、噬敌不退。",
     ("fanqie-loyal", "忠犬护主", "受到伤害后，获得 1 点护甲（忠犬护主简化）。",
      [("loyal-shield", "unit-damaged", "passive-shield-self", {"amount": 1})]),
     ("fanqie-loyal-a", "赤诚之心", "受到伤害后，获得 2 点护甲并恢复 1 点生命。",
      [("loyal-shield-a", "unit-damaged", "passive-shield-self", {"amount": 2}),
       ("loyal-heal-a", "unit-damaged", "passive-heal-self-if-front", {"amount": 1})])),
    ("bingqiang", "冰墙", "雪壁", "冰墙 / 壁垒",
     "冰壁叠甲站场，霜棱冻结控线。",
     2, 8, "#90c8e8",
     "雪女召唤的冰墙守护者，坚壁不融、寒气逼人。",
     ("bingqiang-wall", "冰壁", "己方回合开始时，获得 1 点护甲（冰壁简化）。",
      [("wall-shield", "turn-started", "passive-shield-self", {"amount": 1})]),
     ("bingqiang-wall-a", "不融之壁", "己方回合开始时，获得 2 点护甲并恢复 1 点生命。",
      [("wall-shield-a", "turn-started", "passive-shield-self", {"amount": 2}),
       ("wall-heal-a", "turn-started", "passive-heal-self-if-front", {"amount": 1})])),
    ("zhiren", "纸人", "戏谑", "纸人 / 运势",
     "戏谑套索扰敌，纸刃连击压制。",
     2, 4, "#e8c888",
     "山兔戏谑套索变成的纸人，捣乱成性、笑声不断。",
     ("zhiren-trick", "戏谑套索", "完成交战后，随机对一个敌方角色造成 1 点伤害（戏谑简化）。",
      [("trick-dmg", "combat-resolved", "passive-damage-random-enemy", {"amount": 1})]),
     ("zhiren-trick-a", "小纸人咒", "完成交战后，随机对一个敌方角色造成 2 点伤害。",
      [("trick-dmg-a", "combat-resolved", "passive-damage-random-enemy", {"amount": 2})])),
    ("yanyanluo-fenshen", "烟烟罗分身", "烟雾", "分身 / 烟雾",
     "烟雾分身闪避，蚀骨烟瘴削弱。",
     2, 5, "#b0a0c8",
     "烟烟罗的烟雾分身，形散神聚、瘴烟蚀骨。",
     ("fenshen-smoke", "烟散影留", "受到伤害后，使攻击者获得 1 点破甲（烟蚀简化）。",
      [("smoke-break", "unit-damaged", "passive-armor-break-enemy-on-damage", {"amount": 1})]),
     ("fenshen-smoke-a", "浮缈真形", "受到伤害后，使攻击者获得 2 点破甲。",
      [("smoke-break-a", "unit-damaged", "passive-armor-break-enemy-on-damage", {"amount": 2})])),
    ("jinran-buye", "烬染不夜", "星火", "烬染 / 火焰",
     "烬染余火打脸，不夜星火收割。",
     3, 4, "#f08850",
     "不知火召唤的烬染不夜，星火不灭、夜舞余烬。",
     ("jinran-ember", "烬染余火", "完成交战后，对敌方牌手造成 1 点伤害（烬染简化）。",
      [("ember-face", "combat-resolved", "passive-damage-avatar-after-reserve-combat", {"amount": 1})]),
     ("jinran-ember-a", "不夜星火", "完成交战后，对敌方牌手造成 2 点伤害。",
      [("ember-face-a", "combat-resolved", "passive-damage-avatar-after-reserve-combat", {"amount": 2})])),
    ("xueqiu-jingling", "雪球精灵", "雪球", "雪球 / 成长",
     "雪球叠力成长，暴雪压境终结。",
     2, 6, "#c8e0f0",
     "雪球集合而成的精灵，越滚越大、寒意逼人。",
     ("xueqiu-grow", "雪球叠身", "己方回合开始时，获得 1 点力量（雪球集合简化）。",
      [("ball-buff", "turn-started", "passive-buff-self", {"attack": 1})]),
     ("xueqiu-grow-a", "暴雪之心", "己方回合开始时，获得 1 点力量与 1 点护甲。",
      [("ball-buff-a", "turn-started", "passive-buff-self", {"attack": 1}),
       ("ball-shield-a", "turn-started", "passive-shield-self", {"amount": 1})])),
    ("huangjinyu-ling", "黄金羽灵", "黄金羽", "黄金羽 / 投射",
     "黄金羽落投射，金羽天翔压制。",
     3, 4, "#e8c050",
     "以津真天黄金羽所化的羽灵，振翅洒金、羽刃破空。",
     ("yu-ling-feather", "黄金羽落", "己方回合开始时，随机对一个敌方角色造成 1 点伤害（黄金羽简化）。",
      [("feather-dmg", "turn-started", "passive-damage-random-enemy", {"amount": 1})]),
     ("yu-ling-feather-a", "金羽天翔", "己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
      [("feather-dmg-a", "turn-started", "passive-damage-random-enemy", {"amount": 2})])),
    ("mingdeng-shou", "明灯使", "明灯", "明灯 / 过牌",
     "明灯引路过牌，灯火长明续航。",
     2, 5, "#f0d890",
     "青行灯明灯所化的灯灵，照幽引路、灯火不熄。",
     ("mingdeng-lamp", "引魂明灯", "己方回合开始时，抽一张牌（明灯简化）。",
      [("lamp-draw", "turn-started", "passive-draw-self", {"count": 1})]),
     ("mingdeng-lamp-a", "灯火长明", "己方回合开始时，抽一张牌并获得 1 点护甲。",
      [("lamp-draw-a", "turn-started", "passive-draw-self", {"count": 1}),
       ("lamp-shield-a", "turn-started", "passive-shield-self", {"amount": 1})])),
    ("xinmo", "心魔", "心魔", "心魔 / 削攻",
     "心魔蚀甲削弱，般若真容爆发。",
     3, 5, "#c07090",
     "觉与般若执念所化的心魔，蚀心削志、梦魇缠身。",
     ("xinmo-veil", "心魔缠缚", "完成交战后，使交战目标获得 1 点破甲（心魔蚀甲简化）。",
      [("mind-break", "combat-resolved", "passive-armor-break-defender", {"amount": 1})]),
     ("xinmo-veil-a", "般若真容", "完成交战后，使交战目标获得 2 点破甲。",
      [("mind-break-a", "combat-resolved", "passive-armor-break-defender", {"amount": 2})])),
    ("shouhu-ling", "守护灵", "守护", "守护 / 壁垒",
     "守护灵叠甲回血，永世护主站场。",
     2, 7, "#90b0c0",
     "犬神与兵俑守护信念所化的守护灵，以身作盾、不退半步。",
     ("shouhu-guard", "犬神兵俑", "受到伤害后，获得 1 点护甲并恢复 1 点生命（守护简化）。",
      [("guard-shield", "unit-damaged", "passive-shield-self", {"amount": 1}),
       ("guard-heal", "unit-damaged", "passive-heal-self-if-front", {"amount": 1})]),
     ("shouhu-guard-a", "永世守护", "受到伤害后，获得 2 点护甲并恢复 2 点生命。",
      [("guard-shield-a", "unit-damaged", "passive-shield-self", {"amount": 2}),
       ("guard-heal-a", "unit-damaged", "passive-heal-self-if-front", {"amount": 2})])),
]

SUBPACK = "derived"


def C(name, type, level, cost, rarity, starter, text, effects, **kw):
    d = dict(name=name, type=type, level=level, cost=cost, rarity=rarity,
             starter=starter, text=text, effects=effects, deck_limit=kw.pop("deck_limit", 2))
    d.update(kw)
    return d


def F(atk, hp):
    return {"attack": atk, "hp": hp}


# 每人 8 张：starter 合计=8，觉醒恰好 1 张 starter=1
CARD_MAP: dict[str, list] = {
    "fanqie": [
        C("忠犬噬咬", "combat", 1, 1, "R", 2,
          "出击 +3。完成交战后，番茄获得 1 点护甲。",
          [("source-ready", "assault", "source", 3), ("always", "shield", "source", 1)],
          officialText="召唤的忠犬「番茄」向敌人猛扑。",
          tags=["出击", "守护", "衍生"]),
        C("摇尾示好", "spell", 1, 0, "R", 1,
          "瞬发。为番茄恢复 3 点生命，并抽一张牌。",
          [("always", "heal", "source", 3), ("always", "draw", "ally-player", 1)],
          officialText="番茄摇着尾巴讨好主人。",
          keywords=["INSTANT"], tags=["瞬发", "治疗", "衍生"]),
        C("护主之姿", "form", 1, 1, "R", 1,
          "获得 +2/+3。受到伤害后，获得 1 点护甲。",
          [("always", "form", "source", F(2, 3))],
          officialText="忠犬以身护主，寸步不离。",
          formAbility="受到伤害后，获得 1 点护甲。",
          formHooks=[{"id": "form-fanqie-guard", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "守护", "衍生"]),
        C("飞扑撕咬", "combat", 2, 1, "R", 1,
          "出击 +4。对敌方牌手造成 2 点伤害（直击简化）。",
          [("source-ready", "assault", "source", 4), ("always", "damage", "enemy-avatar", 2)],
          officialText="番茄飞扑而上，狠狠咬住敌人。",
          tags=["出击", "直击", "衍生"]),
        C("番茄怒吼", "form", 2, 1, "SR", 1,
          "获得 +3/+3。完成交战后，对敌方前线造成 2 点伤害。",
          [("always", "form", "source", F(3, 3))],
          officialText="忠犬怒吼震敌。",
          formAbility="完成交战后，对敌方前线造成 2 点伤害。",
          formHooks=[{"id": "form-fanqie-roar", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
          tags=["形态", "伤害", "衍生"]),
        C("人犬同心", "spell", 2, 1, "SR", 1,
          "使番茄获得 +2/+2，并为你恢复 3 点生命。",
          [("always", "buff-stats", "source", F(2, 2)), ("always", "heal-avatar", "ally-avatar", 3)],
          officialText="跳跳妹妹与番茄心意相通。",
          tags=["强化", "治疗", "衍生"]),
        C("赤诚之心", "form", 3, 2, "SSR", 0,
          "获得 +4/+4。受到伤害后，获得 2 点护甲并恢复 1 点生命。",
          [("always", "form", "source", F(4, 4))],
          officialText="番茄的赤诚之心永不熄灭。",
          formAbility="受到伤害后，获得 2 点护甲并恢复 1 点生命。",
          formHooks=[{"id": "form-fanqie-heart", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40},
                     {"id": "form-fanqie-heart-h", "event": "unit-damaged", "effect": "passive-heal-self-if-front", "params": {"amount": 1}, "priority": 40}],
          deck_limit=2, tags=["形态", "守护", "终结"]),
        C("觉醒·番茄", "awakening", 3, 1, "SR", 1,
          "对敌方前线造成 4 点伤害。觉醒：+2/+2，受伤后叠甲回血。",
          [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 4)],
          officialText="觉醒：忠犬护主，赤诚不灭。",
          deck_limit=1, tags=["觉醒", "守护", "衍生"]),
    ],
    "bingqiang": [
        C("霜棱", "spell", 1, 1, "R", 2,
          "对一个敌方式神造成 3 点伤害，并使其 -1 力量。",
          [("always", "damage", "selected-enemy", 3), ("always", "debuff-stats", "selected-enemy", {"attack": 1, "hp": 0})],
          officialText="冰墙寒气凝作霜棱刺出。",
          tags=["伤害", "冰墙", "衍生"]),
        C("寒气弥漫", "spell", 1, 0, "R", 1,
          "瞬发。对敌方前线造成 2 点伤害，冰墙获得 1 点护甲。",
          [("always", "damage-enemy-front", "auto", 2), ("always", "shield", "source", 1)],
          officialText="冰墙寒气弥漫全场。",
          keywords=["INSTANT"], tags=["瞬发", "护甲", "衍生"]),
        C("雪壁矗立", "form", 1, 1, "R", 1,
          "获得 +1/+4。己方回合开始时，获得 1 点护甲。",
          [("always", "form", "source", F(1, 4))],
          officialText="雪女召唤的冰墙巍然矗立。",
          formAbility="己方回合开始时，获得 1 点护甲。",
          formHooks=[{"id": "form-bing-wall", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "壁垒", "衍生"]),
        C("冰锥冲击", "combat", 2, 1, "R", 1,
          "出击 +2。眩晕被攻击的式神。",
          [("source-ready", "assault", "source", 2), ("always", "freeze", "selected-enemy", 1)],
          officialText="冰墙射出冰锥，冻住来敌。",
          keywords=["STUN"], tags=["出击", "眩晕", "衍生"]),
        C("极寒领域", "realm", 2, 1, "SR", 1,
          "幻境（耐久 6）：己方回合开始时，对敌方前线造成 2 点伤害。",
          [("always", "realm", "ally-player", None)],
          officialText="冰墙展开极寒领域。",
          realm={"hp": 6, "trigger": "owner-turn-start", "triggerEffect": "damage-enemy-front", "triggerValue": 2},
          tags=["幻境", "冰墙", "衍生"]),
        C("碎冰重生", "spell", 2, 1, "SR", 1,
          "为冰墙恢复 5 点生命，并获得 3 点护甲。",
          [("always", "heal", "source", 5), ("always", "shield", "source", 3)],
          officialText="碎冰重凝，壁垒再起。",
          tags=["治疗", "护甲", "衍生"]),
        C("不融之壁", "form", 3, 2, "SSR", 0,
          "获得 +2/+6。己方回合开始时，获得 2 点护甲并恢复 1 点生命。",
          [("always", "form", "source", F(2, 6))],
          officialText="千古不融的绝对壁垒。",
          formAbility="己方回合开始时，获得 2 点护甲并恢复 1 点生命。",
          formHooks=[{"id": "form-bing-eternal", "event": "turn-started", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40},
                     {"id": "form-bing-eternal-h", "event": "turn-started", "effect": "passive-heal-self-if-front", "params": {"amount": 1}, "priority": 40}],
          deck_limit=2, tags=["形态", "壁垒", "终结"]),
        C("觉醒·冰墙", "awakening", 3, 1, "SR", 1,
          "眩晕所有敌方式神。觉醒：+2/+4，回合开始叠甲回血。",
          [("always", "awaken", "source", F(2, 4)), ("always", "freeze", "all-enemy-units", 1)],
          officialText="觉醒：冰壁不融，极寒永驻。",
          keywords=["STUN"], deck_limit=1, tags=["觉醒", "壁垒", "衍生"]),
    ],
    "zhiren": [
        C("纸刃飞掷", "spell", 1, 1, "R", 2,
          "对一个敌方式神造成 3 点伤害，并对敌方牌手造成 1 点伤害。",
          [("always", "damage", "selected-enemy", 3), ("always", "damage", "enemy-avatar", 1)],
          officialText="纸人掷出纸刃，笑声咯咯。",
          tags=["伤害", "纸人", "衍生"]),
        C("戏谑套索", "spell", 1, 0, "R", 1,
          "瞬发。眩晕一个敌方式神，并抽一张牌。",
          [("always", "freeze", "selected-enemy", 1), ("always", "draw", "ally-player", 1)],
          officialText="山兔戏谑套索，把敌人变成纸人。",
          keywords=["INSTANT", "STUN"], tags=["瞬发", "眩晕", "衍生"]),
        C("纸舞回旋", "form", 1, 1, "R", 1,
          "获得 +2/+3。完成交战后，随机对一个敌方角色造成 1 点伤害。",
          [("always", "form", "source", F(2, 3))],
          officialText="纸人回旋起舞，纸屑纷飞。",
          formAbility="完成交战后，随机对一个敌方角色造成 1 点伤害。",
          formHooks=[{"id": "form-zhi-dance", "event": "combat-resolved", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "戏谑", "衍生"]),
        C("连环纸爆", "combat", 2, 1, "R", 1,
          "出击 +3。对敌方前线造成 2 点伤害。",
          [("source-ready", "assault", "source", 3), ("always", "damage-enemy-front", "auto", 2)],
          officialText="纸人连环爆炸，炸得敌人灰头土脸。",
          tags=["出击", "伤害", "衍生"]),
        C("小纸人狂欢", "form", 2, 1, "SR", 1,
          "获得 +3/+3。完成交战后，对敌方牌手造成 2 点伤害。",
          [("always", "form", "source", F(3, 3))],
          officialText="一群小纸人狂欢捣乱。",
          formAbility="完成交战后，对敌方牌手造成 2 点伤害。",
          formHooks=[{"id": "form-zhi-party", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 2}, "priority": 40}],
          tags=["形态", "直击", "衍生"]),
        C("命运骰子", "spell", 2, 1, "SR", 1,
          "占卜 2，并对随机一个敌方角色造成 3 点伤害（运势简化）。",
          [("always", "divination", "ally-player", 2), ("always", "damage", "selected-enemy", 3)],
          officialText="如意骰子一掷，听天由命。",
          tags=["运势", "占卜", "衍生"]),
        C("纸人降世", "form", 3, 2, "SSR", 0,
          "获得 +4/+4。完成交战后，随机对一个敌方角色造成 2 点伤害。",
          [("always", "form", "source", F(4, 4))],
          officialText="纸人真形降世，戏谑无双。",
          formAbility="完成交战后，随机对一个敌方角色造成 2 点伤害。",
          formHooks=[{"id": "form-zhi-descent", "event": "combat-resolved", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
          deck_limit=2, tags=["形态", "戏谑", "终结"]),
        C("觉醒·纸人", "awakening", 3, 1, "SR", 1,
          "对所有敌方式神造成 2 点伤害并各 -1 力量。觉醒：+2/+2，交战后扰敌。",
          [("always", "awaken", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 2), ("always", "debuff-stats", "all-enemy-units", {"attack": 1, "hp": 0})],
          officialText="觉醒：戏谑成真，纸舞漫天。",
          deck_limit=1, tags=["觉醒", "戏谑", "衍生"]),
    ],
    "yanyanluo-fenshen": [
        C("烟雾缭绕", "spell", 1, 1, "R", 2,
          "对一个敌方式神造成 3 点伤害，并使其获得 1 点破甲。",
          [("always", "damage", "selected-enemy", 3), ("always", "apply-armor-break", "selected-enemy", 1)],
          officialText="烟烟罗分身放出缭绕烟雾。",
          tags=["伤害", "烟雾", "衍生"]),
        C("散形", "spell", 1, 0, "R", 1,
          "瞬发。分身获得 3 点护甲，并抽一张牌。",
          [("always", "shield", "source", 3), ("always", "draw", "ally-player", 1)],
          officialText="分身散作烟雾，身形飘忽。",
          keywords=["INSTANT"], tags=["瞬发", "护甲", "衍生"]),
        C("瘴烟蚀骨", "form", 1, 1, "R", 1,
          "获得 +2/+4。受到伤害后，使攻击者获得 1 点破甲。",
          [("always", "form", "source", F(2, 4))],
          officialText="瘴烟侵骨，蚀人筋脉。",
          formAbility="受到伤害后，使攻击者获得 1 点破甲。",
          formHooks=[{"id": "form-yan-miasma", "event": "unit-damaged", "effect": "passive-armor-break-enemy-on-damage", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "烟雾", "衍生"]),
        C("烟刃斩", "combat", 2, 1, "R", 1,
          "出击 +3。使交战目标获得 1 点破甲。",
          [("source-ready", "assault", "source", 3), ("always", "apply-armor-break", "selected-enemy", 1)],
          officialText="烟雾凝成利刃斩出。",
          tags=["出击", "破甲", "衍生"]),
        C("浮缈身法", "form", 2, 1, "SR", 1,
          "获得 +3/+3。迅捷。完成交战后，获得 2 点护甲。",
          [("always", "form", "source", F(3, 3))],
          officialText="浮缈身法，来去无踪。",
          keywords=["INSTANT"],
          formAbility="完成交战后，获得 2 点护甲。",
          formHooks=[{"id": "form-yan-float", "event": "combat-resolved", "effect": "passive-shield-self-after-combat", "params": {"amount": 2}, "priority": 40}],
          tags=["形态", "迅捷", "衍生"]),
        C("分烟化影", "spell", 2, 1, "SR", 1,
          "对敌方前线造成 4 点伤害，并使所有敌方式神获得 1 点破甲。",
          [("always", "damage-enemy-front", "auto", 4), ("always", "apply-armor-break", "all-enemy-units", 1)],
          officialText="一分为烟，化影千重。",
          tags=["群伤", "破甲", "衍生"]),
        C("浮缈真形", "form", 3, 2, "SSR", 0,
          "获得 +4/+4。受到伤害后，使攻击者获得 2 点破甲。",
          [("always", "form", "source", F(4, 4))],
          officialText="烟雾散尽，真形显现。",
          formAbility="受到伤害后，使攻击者获得 2 点破甲。",
          formHooks=[{"id": "form-yan-true", "event": "unit-damaged", "effect": "passive-armor-break-enemy-on-damage", "params": {"amount": 2}, "priority": 40}],
          deck_limit=2, tags=["形态", "烟雾", "终结"]),
        C("觉醒·烟雾分身", "awakening", 3, 1, "SR", 1,
          "对所有敌方式神造成 3 点伤害并各获得 2 点破甲。觉醒：+2/+2，受伤蚀甲。",
          [("always", "awaken", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 3), ("always", "apply-armor-break", "all-enemy-units", 2)],
          officialText="觉醒：烟罗真形，瘴蚀天下。",
          deck_limit=1, tags=["觉醒", "烟雾", "衍生"]),
    ],
    "jinran-buye": [
        C("星火点点", "spell", 1, 1, "R", 2,
          "对一个敌方角色造成 3 点伤害（星火简化）。",
          [("always", "damage", "selected-enemy", 3)],
          officialText="烬染不夜洒落星火点点。",
          tags=["伤害", "烬染", "衍生"]),
        C("余烬回旋", "spell", 1, 0, "R", 1,
          "瞬发。对敌方前线造成 2 点伤害，为烬染不夜恢复 2 点生命。",
          [("always", "damage-enemy-front", "auto", 2), ("always", "heal", "source", 2)],
          officialText="余烬随舞回旋，灼热逼人。",
          keywords=["INSTANT"], tags=["瞬发", "伤害", "衍生"]),
        C("夜舞余烬", "form", 1, 1, "R", 1,
          "获得 +2/+3。完成交战后，对敌方牌手造成 1 点伤害。",
          [("always", "form", "source", F(2, 3))],
          officialText="不知火夜舞，烬染长空。",
          formAbility="完成交战后，对敌方牌手造成 1 点伤害。",
          formHooks=[{"id": "form-jin-dance", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "直击", "衍生"]),
        C("焰扇起舞", "combat", 2, 1, "R", 1,
          "出击 +4。对敌方牌手造成 2 点伤害。",
          [("source-ready", "assault", "source", 4), ("always", "damage", "enemy-avatar", 2)],
          officialText="焰扇一展，火舞翩跹。",
          tags=["出击", "直击", "衍生"]),
        C("烬染连击", "form", 2, 1, "SR", 1,
          "获得 +3/+3。完成交战后，对敌方前线造成 2 点伤害。",
          [("always", "form", "source", F(3, 3))],
          officialText="烬染连击，火势不绝。",
          formAbility="完成交战后，对敌方前线造成 2 点伤害。",
          formHooks=[{"id": "form-jin-combo", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
          tags=["形态", "伤害", "衍生"]),
        C("星火燎原", "spell", 2, 1, "SR", 1,
          "对所有敌方式神造成 2 点伤害，对敌方牌手造成 2 点伤害。",
          [("always", "damage", "all-enemy-units", 2), ("always", "damage", "enemy-avatar", 2)],
          officialText="星火燎原，烬染不夜。",
          tags=["群伤", "直击", "衍生"]),
        C("不夜星火", "form", 3, 2, "SSR", 0,
          "获得 +4/+3。完成交战后，对敌方牌手造成 2 点伤害。",
          [("always", "form", "source", F(4, 3))],
          officialText="星火不灭，长夜不终。",
          formAbility="完成交战后，对敌方牌手造成 2 点伤害。",
          formHooks=[{"id": "form-jin-eternal", "event": "combat-resolved", "effect": "passive-damage-avatar-after-reserve-combat", "params": {"amount": 2}, "priority": 40}],
          deck_limit=2, tags=["形态", "直击", "终结"]),
        C("觉醒·烬染不夜", "awakening", 3, 1, "SR", 1,
          "对敌方牌手造成 5 点伤害。觉醒：+2/+2，交战后灼脸。",
          [("always", "awaken", "source", F(2, 2)), ("always", "damage", "enemy-avatar", 5)],
          officialText="觉醒：烬染不夜，星火永燃。",
          deck_limit=1, tags=["觉醒", "直击", "衍生"]),
    ],
    "xueqiu-jingling": [
        C("雪球投掷", "spell", 1, 1, "R", 2,
          "对一个敌方式神造成 3 点伤害，并使其 -1 力量。",
          [("always", "damage", "selected-enemy", 3), ("always", "debuff-stats", "selected-enemy", {"attack": 1, "hp": 0})],
          officialText="雪球精灵掷出雪球。",
          tags=["伤害", "雪球", "衍生"]),
        C("滚雪球", "spell", 1, 0, "R", 1,
          "瞬发。雪球精灵获得 +1/+1，并抽一张牌。",
          [("always", "buff-stats", "source", F(1, 1)), ("always", "draw", "ally-player", 1)],
          officialText="雪球越滚越大。",
          keywords=["INSTANT"], tags=["瞬发", "成长", "衍生"]),
        C("雪球叠身", "form", 1, 1, "R", 1,
          "获得 +2/+4。己方回合开始时，获得 1 点力量。",
          [("always", "form", "source", F(2, 4))],
          officialText="雪球集合而成的精灵不断壮大。",
          formAbility="己方回合开始时，获得 1 点力量。",
          formHooks=[{"id": "form-xue-grow", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
          tags=["形态", "成长", "衍生"]),
        C("冰棱乱射", "combat", 2, 1, "R", 1,
          "出击 +2。对所有敌方式神造成 1 点伤害。",
          [("source-ready", "assault", "source", 2), ("always", "damage", "all-enemy-units", 1)],
          officialText="雪球炸开，冰棱乱射。",
          tags=["出击", "群伤", "衍生"]),
        C("暴雪压境", "form", 2, 1, "SR", 1,
          "获得 +3/+4。己方回合开始时，对敌方前线造成 2 点伤害。",
          [("always", "form", "source", F(3, 4))],
          officialText="暴雪压境，寒意彻骨。",
          formAbility="己方回合开始时，对敌方前线造成 2 点伤害。",
          formHooks=[{"id": "form-xue-storm", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
          tags=["形态", "伤害", "衍生"]),
        C("雪球连掷", "spell", 2, 1, "SR", 1,
          "对一个敌方式神造成 3 点伤害，再对敌方前线造成 3 点伤害。",
          [("always", "damage", "selected-enemy", 3), ("always", "damage-enemy-front", "auto", 3)],
          officialText="雪球连掷，铺天盖地。",
          tags=["伤害", "雪球", "衍生"]),
        C("极寒暴雪", "form", 3, 2, "SSR", 0,
          "获得 +4/+5。己方回合开始时，获得 1 点力量并对敌方前线造成 2 点伤害。",
          [("always", "form", "source", F(4, 5))],
          officialText="极寒暴雪，吞没一切。",
          formAbility="己方回合开始时，获得 1 点力量并对敌方前线造成 2 点伤害。",
          formHooks=[{"id": "form-xue-buff", "event": "turn-started", "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40},
                     {"id": "form-xue-dmg", "event": "turn-started", "effect": "passive-damage-enemy-front-on-form", "params": {"amount": 2}, "priority": 40}],
          deck_limit=2, tags=["形态", "成长", "终结"]),
        C("觉醒·雪球精灵", "awakening", 3, 1, "SR", 1,
          "对所有敌方式神造成 3 点伤害并各 -2 力量。觉醒：+2/+3，回合开始叠力。",
          [("always", "awaken", "source", F(2, 3)), ("always", "damage", "all-enemy-units", 3), ("always", "debuff-stats", "all-enemy-units", {"attack": 2, "hp": 0})],
          officialText="觉醒：暴雪之心，雪球无穷。",
          deck_limit=1, tags=["觉醒", "成长", "衍生"]),
    ],
    "huangjinyu-ling": [
        C("金羽刃", "spell", 1, 1, "R", 2,
          "对一个敌方式神造成 3 点伤害，并对敌方牌手造成 1 点伤害。",
          [("always", "damage", "selected-enemy", 3), ("always", "damage", "enemy-avatar", 1)],
          officialText="黄金羽化作利刃飞出。",
          keywords=["PROJECTILE"], tags=["投射", "黄金羽", "衍生"]),
        C("振翅洒金", "spell", 1, 0, "R", 1,
          "瞬发。随机对一个敌方角色造成 2 点伤害，并抽一张牌。",
          [("always", "damage", "selected-enemy", 2), ("always", "draw", "ally-player", 1)],
          officialText="羽灵振翅，洒落金光。",
          keywords=["INSTANT"], tags=["瞬发", "投射", "衍生"]),
        C("黄金羽落", "form", 1, 1, "R", 1,
          "获得 +2/+3。己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
          [("always", "form", "source", F(2, 3))],
          officialText="以津真天黄金羽所化的羽灵。",
          formAbility="己方回合开始时，随机对一个敌方角色造成 1 点伤害。",
          formHooks=[{"id": "form-yu-fall", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "投射", "衍生"]),
        C("羽衣突袭", "combat", 2, 1, "R", 1,
          "出击 +3。对敌方牌手造成 2 点伤害。",
          [("source-ready", "assault", "source", 3), ("always", "damage", "enemy-avatar", 2)],
          officialText="羽衣一振，疾袭而至。",
          tags=["出击", "直击", "衍生"]),
        C("金风流羽", "form", 2, 1, "SR", 1,
          "获得 +3/+3。完成交战后，对敌方前线造成 2 点伤害。",
          [("always", "form", "source", F(3, 3))],
          officialText="金风流羽，漫天飞舞。",
          formAbility="完成交战后，对敌方前线造成 2 点伤害。",
          formHooks=[{"id": "form-yu-gold", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
          tags=["形态", "投射", "衍生"]),
        C("不可饶恕", "spell", 2, 1, "SR", 1,
          "对一个敌方式神造成 5 点伤害，并眩晕。",
          [("always", "damage", "selected-enemy", 5), ("always", "freeze", "selected-enemy", 1)],
          officialText="黄金羽灵的怒火不可饶恕。",
          keywords=["STUN"], tags=["伤害", "眩晕", "衍生"]),
        C("金羽天翔", "form", 3, 2, "SSR", 0,
          "获得 +4/+3。己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
          [("always", "form", "source", F(4, 3))],
          officialText="金羽天翔，遮天蔽日。",
          formAbility="己方回合开始时，随机对一个敌方角色造成 2 点伤害。",
          formHooks=[{"id": "form-yu-sky", "event": "turn-started", "effect": "passive-damage-random-enemy", "params": {"amount": 2}, "priority": 40}],
          deck_limit=2, tags=["形态", "投射", "终结"]),
        C("觉醒·黄金羽灵", "awakening", 3, 1, "SR", 1,
          "投射：对敌方前线造成 5 点伤害。觉醒：+2/+2，回合开始金羽投射。",
          [("always", "awaken", "source", F(2, 2)), ("always", "damage-enemy-front", "auto", 5)],
          officialText="觉醒：金羽天翔，万里无云。",
          keywords=["PROJECTILE"], deck_limit=1, tags=["觉醒", "投射", "衍生"]),
    ],
    "mingdeng-shou": [
        C("灯影摇曳", "spell", 1, 1, "R", 2,
          "对一个敌方式神造成 2 点伤害，并抽一张牌。",
          [("always", "damage", "selected-enemy", 2), ("always", "draw", "ally-player", 1)],
          officialText="明灯摇曳，灯影幢幢。",
          tags=["伤害", "过牌", "衍生"]),
        C("引路之光", "spell", 1, 0, "R", 1,
          "瞬发。抽一张牌，并获得 1 点护甲。",
          [("always", "draw", "ally-player", 1), ("always", "shield", "source", 1)],
          officialText="明灯引路，照破幽暗。",
          keywords=["INSTANT"], tags=["瞬发", "过牌", "衍生"]),
        C("灯火引魂", "form", 1, 1, "R", 1,
          "获得 +2/+4。己方回合开始时，抽一张牌。",
          [("always", "form", "source", F(2, 4))],
          officialText="青行灯明灯所化的灯灵。",
          formAbility="己方回合开始时，抽一张牌。",
          formHooks=[{"id": "form-deng-draw", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40}],
          tags=["形态", "过牌", "衍生"]),
        C("灯火爆闪", "combat", 2, 1, "R", 1,
          "出击 +3。获得 1 点鬼火。",
          [("source-ready", "assault", "source", 3), ("always", "energy-gain", "ally-player", 1)],
          officialText="灯火爆闪，晃得人睁不开眼。",
          tags=["出击", "鬼火", "衍生"]),
        C("辉灯之火", "form", 2, 1, "SR", 1,
          "获得 +2/+4。己方回合开始时，获得 1 点鬼火。",
          [("always", "form", "source", F(2, 4))],
          officialText="辉灯之火，长明不灭。",
          formAbility="己方回合开始时，获得 1 点鬼火。",
          formHooks=[{"id": "form-deng-energy", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "鬼火", "衍生"]),
        C("离魂灯照", "spell", 2, 1, "SR", 1,
          "眩晕一个敌方式神，并为你恢复 3 点生命。",
          [("always", "freeze", "selected-enemy", 1), ("always", "heal-avatar", "ally-avatar", 3)],
          officialText="离魂灯一照，魂飞魄散。",
          keywords=["STUN"], tags=["眩晕", "治疗", "衍生"]),
        C("灯火长明", "form", 3, 2, "SSR", 0,
          "获得 +3/+5。己方回合开始时，抽一张牌并获得 1 点鬼火。",
          [("always", "form", "source", F(3, 5))],
          officialText="灯火长明，万古不熄。",
          formAbility="己方回合开始时，抽一张牌并获得 1 点鬼火。",
          formHooks=[{"id": "form-deng-eternal-d", "event": "turn-started", "effect": "passive-draw-self-on-form", "params": {"count": 1}, "priority": 40},
                     {"id": "form-deng-eternal-e", "event": "turn-started", "effect": "passive-gain-energy", "params": {"amount": 1}, "priority": 40}],
          deck_limit=2, tags=["形态", "过牌", "终结"]),
        C("觉醒·明灯使", "awakening", 3, 1, "SR", 1,
          "抽两张牌并获得 1 点鬼火。觉醒：+2/+2，引灯过牌叠甲。",
          [("always", "awaken", "source", F(2, 2)), ("always", "draw", "ally-player", 2), ("always", "energy-gain", "ally-player", 1)],
          officialText="觉醒：灯火长明，照彻幽冥。",
          deck_limit=1, tags=["觉醒", "过牌", "衍生"]),
    ],
    "xinmo": [
        C("心魔低语", "spell", 1, 1, "R", 2,
          "对一个敌方式神造成 3 点伤害，并使其 -1 力量。",
          [("always", "damage", "selected-enemy", 3), ("always", "debuff-stats", "selected-enemy", {"attack": 1, "hp": 0})],
          officialText="心魔在耳边低语，蛊惑人心。",
          tags=["伤害", "削攻", "衍生"]),
        C("梦魇缠身", "spell", 1, 0, "R", 1,
          "瞬发。使一个敌方式神获得 2 点破甲。",
          [("always", "apply-armor-break", "selected-enemy", 2)],
          officialText="梦魇缠身，挥之不去。",
          keywords=["INSTANT"], tags=["瞬发", "破甲", "衍生"]),
        C("蚀心之影", "form", 1, 1, "R", 1,
          "获得 +2/+4。完成交战后，使交战目标获得 1 点破甲。",
          [("always", "form", "source", F(2, 4))],
          officialText="觉与般若执念所化的心魔。",
          formAbility="完成交战后，使交战目标获得 1 点破甲。",
          formHooks=[{"id": "form-xin-erode", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "削攻", "衍生"]),
        C("恐惧冲击", "combat", 2, 1, "R", 1,
          "出击 +3。使交战目标 -2 力量。",
          [("source-ready", "assault", "source", 3), ("always", "debuff-stats", "selected-enemy", {"attack": 2, "hp": 0})],
          officialText="心魔冲击，令敌胆寒。",
          tags=["出击", "削攻", "衍生"]),
        C("般若假面", "form", 2, 1, "SR", 1,
          "获得 +3/+3。完成交战后，对敌方前线造成 2 点伤害。",
          [("always", "form", "source", F(3, 3))],
          officialText="般若假面之下，是无尽心魔。",
          formAbility="完成交战后，对敌方前线造成 2 点伤害。",
          formHooks=[{"id": "form-xin-mask", "event": "combat-resolved", "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
          tags=["形态", "伤害", "衍生"]),
        C("心身炼磨", "spell", 2, 1, "SR", 1,
          "心魔获得 +2/+2，并使一个敌方式神获得 2 点破甲。",
          [("always", "buff-stats", "source", F(2, 2)), ("always", "apply-armor-break", "selected-enemy", 2)],
          officialText="心身炼磨，执念成魔。",
          tags=["强化", "破甲", "衍生"]),
        C("般若真容", "form", 3, 2, "SSR", 0,
          "获得 +4/+4。完成交战后，使交战目标获得 2 点破甲并 -1 力量。",
          [("always", "form", "source", F(4, 4))],
          officialText="般若真容显现，心魔蚀骨。",
          formAbility="完成交战后，使交战目标获得 2 点破甲。",
          formHooks=[{"id": "form-xin-true", "event": "combat-resolved", "effect": "passive-armor-break-defender", "params": {"amount": 2}, "priority": 40}],
          deck_limit=2, tags=["形态", "削攻", "终结"]),
        C("觉醒·心魔", "awakening", 3, 1, "SR", 1,
          "对所有敌方式神造成 3 点伤害并各 -2 力量。觉醒：+2/+2，交战蚀甲。",
          [("always", "awaken", "source", F(2, 2)), ("always", "damage", "all-enemy-units", 3), ("always", "debuff-stats", "all-enemy-units", {"attack": 2, "hp": 0})],
          officialText="觉醒：心魔真形，蚀尽众生。",
          deck_limit=1, tags=["觉醒", "削攻", "衍生"]),
    ],
    "shouhu-ling": [
        C("盾击", "combat", 1, 1, "R", 2,
          "出击 +2。守护灵获得 2 点护甲。",
          [("source-ready", "assault", "source", 2), ("always", "shield", "source", 2)],
          officialText="守护灵举盾撞击。",
          tags=["出击", "护甲", "衍生"]),
        C("坚守", "spell", 1, 0, "R", 1,
          "瞬发。为一个己方式神获得 3 点护甲。",
          [("always", "shield", "selected-ally", 3)],
          officialText="犬神兵俑信念化作坚盾。",
          keywords=["INSTANT"], tags=["瞬发", "护甲", "衍生"]),
        C("犬神兵俑", "form", 1, 1, "R", 1,
          "获得 +1/+5。受到伤害后，获得 1 点护甲并恢复 1 点生命。",
          [("always", "form", "source", F(1, 5))],
          officialText="犬神与兵俑守护信念所化的守护灵。",
          formAbility="受到伤害后，获得 1 点护甲并恢复 1 点生命。",
          formHooks=[{"id": "form-shou-shield", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 1}, "priority": 40},
                     {"id": "form-shou-heal", "event": "unit-damaged", "effect": "passive-heal-self-if-front", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "壁垒", "衍生"]),
        C("守护冲锋", "combat", 2, 1, "R", 1,
          "出击 +3。为所有己方式神恢复 1 点生命。",
          [("source-ready", "assault", "source", 3), ("always", "heal", "all-ally-units", 1)],
          officialText="守护灵挺身冲锋，护佑同伴。",
          tags=["出击", "治疗", "衍生"]),
        C("永世护主", "form", 2, 1, "SR", 1,
          "获得 +2/+5。己方回合开始时，为所有己方式神恢复 1 点生命。",
          [("always", "form", "source", F(2, 5))],
          officialText="永世护主，至死不渝。",
          formAbility="己方回合开始时，为所有己方式神恢复 1 点生命。",
          formHooks=[{"id": "form-shou-party", "event": "turn-started", "effect": "passive-heal-all-allies", "params": {"amount": 1}, "priority": 40}],
          tags=["形态", "治疗", "衍生"]),
        C("壁垒回春", "spell", 2, 1, "SR", 1,
          "为守护灵恢复 5 点生命，并为所有己方式神获得 1 点护甲。",
          [("always", "heal", "source", 5), ("always", "shield", "all-ally-units", 1)],
          officialText="壁垒回春，众志成城。",
          tags=["治疗", "护甲", "衍生"]),
        C("永世守护", "form", 3, 2, "SSR", 0,
          "获得 +2/+6。受到伤害后，获得 2 点护甲并恢复 2 点生命。",
          [("always", "form", "source", F(2, 6))],
          officialText="永世守护，不退半步。",
          formAbility="受到伤害后，获得 2 点护甲并恢复 2 点生命。",
          formHooks=[{"id": "form-shou-eternal-s", "event": "unit-damaged", "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40},
                     {"id": "form-shou-eternal-h", "event": "unit-damaged", "effect": "passive-heal-self-if-front", "params": {"amount": 2}, "priority": 40}],
          deck_limit=2, tags=["形态", "壁垒", "终结"]),
        C("觉醒·守护灵", "awakening", 3, 1, "SR", 1,
          "为所有己方式神恢复 3 点生命并各获得 2 点护甲。觉醒：+2/+3，受伤叠甲回血。",
          [("always", "awaken", "source", F(2, 3)), ("always", "heal", "all-ally-units", 3), ("always", "shield", "all-ally-units", 2)],
          officialText="觉醒：永世守护，众灵庇佑。",
          deck_limit=1, tags=["觉醒", "壁垒", "衍生"]),
    ],
}


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def emit_hooks(hooks) -> str:
    parts = []
    for h_id, event, effect, params in hooks:
        parts.append(
            "      { id: %s, event: %s, effect: %s, params: %s }" % (
                js_str(h_id), js_str(event), js_str(effect),
                json.dumps(params, ensure_ascii=False),
            )
        )
    return ",\n".join(parts)


def self_check() -> list[str]:
    errors = []
    if len(UNITS) != 10:
        errors.append(f"units={len(UNITS)} expected 10")
    unit_ids = [u[0] for u in UNITS]
    if len(set(unit_ids)) != len(unit_ids):
        errors.append("duplicate unit ids")
    for uid, *_ in UNITS:
        cards = CARD_MAP.get(uid, [])
        starter = sum(c["starter"] for c in cards)
        awakenings = [c for c in cards if c["type"] == "awakening"]
        if starter != 8:
            errors.append(f"{uid}: starter={starter} expected 8")
        if len(awakenings) != 1:
            errors.append(f"{uid}: awakening={len(awakenings)} expected 1")
        elif awakenings[0]["starter"] != 1:
            errors.append(f"{uid}: awakening starter={awakenings[0]['starter']} expected 1")
        if len(cards) != 8:
            errors.append(f"{uid}: cards={len(cards)} expected 8")
        for c in cards:
            for _cond, act, tgt, val in c["effects"]:
                if act not in ALLOWED_ACTIONS:
                    errors.append(f"{uid}/{c['name']}: unknown action {act}")
                if tgt not in ALLOWED_TARGETS:
                    errors.append(f"{uid}/{c['name']}: unknown target {tgt}")
    return errors


ALLOWED_ACTIONS = {
    "assault", "awaken", "buff-stats", "damage", "damage-enemy-front", "debuff-stats",
    "divination", "draw", "energy-gain", "form", "freeze", "heal", "heal-avatar",
    "apply-armor-break", "realm", "revive", "revive-all", "shield",
}
ALLOWED_TARGETS = {
    "all-enemy-units", "all-ally-units", "auto", "ally-avatar", "ally-player",
    "enemy-avatar", "knocked-ally", "selected-ally", "selected-enemy", "source",
}
ALLOWED_PASSIVE_EFFECTS = {
    "passive-armor-break-defender", "passive-armor-break-enemy-on-damage",
    "passive-buff-self", "passive-damage-avatar-after-reserve-combat",
    "passive-damage-enemy-front", "passive-damage-enemy-front-on-form",
    "passive-damage-random-enemy", "passive-draw-self", "passive-draw-self-on-form",
    "passive-gain-energy", "passive-heal-all-allies", "passive-heal-self-if-front",
    "passive-shield-self", "passive-shield-self-after-combat",
}


def main() -> None:
    errors = self_check()
    if errors:
        for e in errors:
            print("FAIL", e)
        raise SystemExit(1)

    lines = []
    lines.append("/**")
    lines.append(" * 衍生式神（wave11，10 式神）内容 — 由 scripts/gen-wave11-content.py 生成。")
    lines.append(" * 灵感来自 token-derivatives 衍生/召唤物，改写为独立可玩式神。")
    lines.append(" * 效果仅映射已有动作；请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE11_PACK_ID = 'wave11';")
    lines.append("export const WAVE11_PACK_NAME = '衍生式神';")
    lines.append("export const WAVE11_SUBPACKS = Object.freeze({ derived: '衍生' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE11_UNIT_DEFINITIONS = Object.freeze([")

    for uid, name, title, role, strategy, atk, hp, color, official_ability, pid, aid in UNITS:
        lines.append("  {")
        lines.append(f"    id: {js_str(uid)},")
        lines.append(f"    name: {js_str(name)},")
        lines.append(f"    title: {js_str(title)},")
        lines.append(f"    role: {js_str(role)},")
        lines.append(f"    strategy: {js_str(strategy)},")
        lines.append(f"    maxHp: {hp},")
        lines.append(f"    attack: {atk},")
        lines.append(f"    art: {js_str(f'assets/wave11/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave11/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave11')},")
        lines.append(f"    subpack: {js_str(SUBPACK)},")
        lines.append(f"    officialRole: {js_str(uid)},")
        lines.append(f"    officialAbility: {js_str(official_ability)},")
        lines.append("    passive: passive(" + js_str(pid[0]) + ", " + js_str(pid[1]) + ", " + js_str(pid[2]) + ", [\n" + emit_hooks(pid[3]) + "\n    ]),")
        lines.append("    awakenedPassive: passive(" + js_str(aid[0]) + ", " + js_str(aid[1]) + ", " + js_str(aid[2]) + ", [\n" + emit_hooks(aid[3]) + "\n    ]),")
        lines.append("  },")

    lines.append("]);")
    lines.append("")
    lines.append("function eff(condition, action, target, value = null) {")
    lines.append("  return { condition, action, target, value };")
    lines.append("}")
    lines.append("")
    lines.append("function wave11Card(officialId, unitId, meta) {")
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
    lines.append("    pack: 'wave11',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.realm ? { realm: Object.freeze(meta.realm) } : {}),")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE11_CARD_DEFINITIONS = Object.freeze([")

    unit_ids = [u[0] for u in UNITS]
    used_ids = set()
    total_cards = 0
    for idx, uid in enumerate(unit_ids, start=1):
        for j, meta in enumerate(CARD_MAP[uid], start=1):
            oid = 91100 + idx * 10 + j
            gid = f"w11-{uid}-{j:02d}"
            if gid in used_ids:
                continue
            used_ids.add(gid)
            total_cards += 1
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
                f"officialText: {js_str(meta.get('officialText') or meta['text'])}",
                f"target: {js_str(meta.get('target', 'auto'))}",
            ]
            if meta.get("keywords"):
                body.append("keywords: [" + ", ".join(js_str(k) for k in meta["keywords"]) + "]")
            if meta.get("tags"):
                body.append("tags: [" + ", ".join(js_str(t) for t in meta["tags"]) + "]")
            if meta.get("formAbility"):
                body.append(f"formAbility: {js_str(meta['formAbility'])}")
            if meta.get("formHooks"):
                body.append("formHooks: " + json.dumps(meta["formHooks"], ensure_ascii=False))
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
            body.append(f"subpack: {js_str(SUBPACK)}")
            lines.append(f"  wave11Card({oid}, {js_str(uid)}, {{")
            lines.append("    " + ",\n    ".join(body) + ",")
            lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave11UnitIds() {")
    lines.append("  return WAVE11_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # 终检
    starter_sum = 0
    awk = 0
    for uid in unit_ids:
        cards = CARD_MAP[uid]
        starter_sum += sum(c["starter"] for c in cards)
        awk += sum(1 for c in cards if c["type"] == "awakening")
    print(f"Wrote {OUT}")
    print(f"units={len(UNITS)} cards={total_cards} starter_sum={starter_sum} awakening={awk}")
    for uid in unit_ids:
        cards = CARD_MAP[uid]
        s = sum(c["starter"] for c in cards)
        a = sum(1 for c in cards if c["type"] == "awakening")
        print(f"  {uid}: cards={len(cards)} starter={s} awakening={a}")


if __name__ == "__main__":
    main()
