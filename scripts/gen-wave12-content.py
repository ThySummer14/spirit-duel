#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""灵枢原创·二弹（wave12，8 式神）内容生成器。"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game-content-wave12.js"

# id, name, title, role, strategy, hp, atk, color, passive, awakenedPassive, official
UNITS = [
    dict(id="yueying", name="月隐", title="匿影", role="潜行 / 连击", strategy="匿影避锋，月蚀连斩。",
         hp=4, atk=3, color="#8a9bc0",
         passive=("yueying-shadow", "匿影", "完成交战后退回准备区，并获得 1 点护甲。",
                  [("shadow-retreat", "combat-resolved", "passive-return-to-reserve", {"shield": 1})]),
         awakened=("yueying-shadow-a", "月蚀", "完成交战后退回准备区，获得 2 点护甲并抽一张牌。",
                   [("shadow-retreat-a", "combat-resolved", "passive-return-to-reserve", {"shield": 2}),
                    ("shadow-draw-a", "combat-resolved", "passive-draw-self", {"amount": 1})]),
         official="原创·月隐：月下潜行的剑客。"),
    dict(id="shizhu", name="石主", title="山骨", role="壁垒 / 反打", strategy="叠甲站场，震地反伤。",
         hp=9, atk=1, color="#a89870",
         passive=("shizhu-bone", "山骨", "己方回合开始时，获得 2 点护甲。",
                  [("bone-shield", "turn-started", "passive-shield-self", {"amount": 2})]),
         awakened=("shizhu-bone-a", "不坏岩心", "己方回合开始时，获得 2 点护甲并恢复 1 点生命。",
                   [("bone-shield-a", "turn-started", "passive-shield-self", {"amount": 2}),
                    ("bone-heal-a", "turn-started", "passive-heal-self-if-front", {"amount": 1})]),
         official="原创·石主：镇守山骨的岩灵。"),
    dict(id="yanling-huo", name="焰铃", title="摇火", role="法术 / 投射", strategy="摇火投射，铃音灼敌。",
         hp=5, atk=2, color="#e07040",
         passive=("yanling-ring", "摇火", "使用法术牌后，对敌方前线造成 1 点伤害。",
                  [("ring-burn", "card-played", "passive-damage-enemy-front-on-spell", {"amount": 1})]),
         awakened=("yanling-ring-a", "焚铃", "使用法术牌后，对敌方前线造成 2 点伤害。",
                   [("ring-burn-a", "card-played", "passive-damage-enemy-front-on-spell", {"amount": 2})]),
         official="原创·焰铃：摇火成术的铃使。"),
    dict(id="shuimo", name="水沫", title="潮语", role="治疗 / 转甲", strategy="潮语续命，过疗化甲。",
         hp=6, atk=1, color="#5a9aaa",
         passive=("shuimo-tide", "潮语", "恢复生命时，获得 1 点护甲。",
                  [("tide-shield", "unit-healed", "passive-shield-on-overheal", {"amount": 1})]),
         awakened=("shuimo-tide-a", "海沫之心", "恢复生命时，获得 1 点护甲与 1 点力量。",
                   [("tide-shield-a", "unit-healed", "passive-shield-on-overheal", {"amount": 1, "attack": 1})]),
         official="原创·水沫：潮声化沫的医者。"),
    dict(id="leiyin", name="雷音", title="震弦", role="眩晕 / 充能", strategy="震弦控场，雷怒充能。",
         hp=5, atk=3, color="#c0a0e0",
         passive=("leiyin-boom", "震弦", "己方回合开始时，随机对一个敌方式神造成 1 点伤害。",
                  [("boom-zap", "turn-started", "passive-damage-random-enemy", {"amount": 1})]),
         awakened=("leiyin-boom-a", "天雷弦", "己方回合开始时，随机对一个敌方式神造成 2 点伤害。",
                   [("boom-zap-a", "turn-started", "passive-damage-random-enemy", {"amount": 2})]),
         official="原创·雷音：拨弦引雷的乐师。"),
    dict(id="xingchen", name="星尘", title="尘轨", role="运势 / 占卜", strategy="星轨卜算，尘光过牌。",
         hp=5, atk=2, color="#d0c080",
         passive=("xingchen-orbit", "尘轨", "己方回合开始时，抽一张牌。",
                  [("orbit-draw", "turn-started", "passive-draw-self", {"amount": 1})]),
         awakened=("xingchen-orbit-a", "星轨全开", "己方回合开始时，抽两张牌。",
                   [("orbit-draw-a", "turn-started", "passive-draw-self", {"amount": 2})]),
         official="原创·星尘：循星尘轨迹的占者。"),
    dict(id="momo", name="墨貘", title="梦蚀", role="破甲 / 压制", strategy="蚀梦灌甲，墨香困敌。",
         hp=6, atk=2, color="#6a5a80",
         passive=("momo-dream", "梦蚀", "对敌方式神造成战斗伤害后，使其获得 1 破甲。",
                  [("dream-break", "combat-resolved", "passive-armor-break-defender", {"amount": 1})]),
         awakened=("momo-dream-a", "蚀梦", "对敌方式神造成战斗伤害后，使其获得 2 破甲。",
                   [("dream-break-a", "combat-resolved", "passive-armor-break-defender", {"amount": 2})]),
         official="原创·墨貘：食梦吐墨的兽灵。"),
    dict(id="jinguang", name="金光", title="辉印", role="鼓舞 / 觉醒", strategy="辉印鼓舞，金身开悟。",
         hp=6, atk=2, color="#e0c060",
         passive=("jinguang-seal", "辉印", "己方回合开始时，鼓舞：获得 1 力量。",
                  [("seal-encourage", "turn-started", "passive-buff-other-allies", {"attack": 1})]),
         awakened=("jinguang-seal-a", "大辉印", "己方回合开始时，其他友方获得 2 力量。",
                   [("seal-encourage-a", "turn-started", "passive-buff-other-allies", {"attack": 2})]),
         official="原创·金光：结印扬辉的祭官。"),
]

# 8 cards per unit: (name, type, level, cost, rarity, starter, text, target, effects, extra)
def C(name, type_, level, cost, rarity, starter, text, target, effects, **extra):
    return dict(name=name, type=type_, level=level, cost=cost, rarity=rarity, starter=starter,
                text=text, target=target, effects=effects, **extra)

CARDS = {
"yueying": [
    C("影斩", "combat", 1, 1, "R", 2, "出击 +2。", "auto", [("source-ready","assault","source",2)]),
    C("月隐步", "spell", 1, 0, "R", 1, "获得 2 点护甲。", "auto", [("always","shield","source",2)]),
    C("双影", "combat", 2, 1, "SR", 1, "出击 +1，并抽一张牌。", "auto", [("source-ready","assault","source",1),("always","draw","ally-player",1)]),
    C("蚀月", "spell", 2, 1, "R", 1, "对敌方前线造成 3 点伤害。", "auto", [("always","damage-enemy-front","auto",3)]),
    C("匿影之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("月蚀连斩", "combat", 3, 1, "SR", 1, "出击 +3。", "auto", [("source-ready","assault","source",3)]),
    C("无光", "spell", 3, 1, "R", 1, "眩晕敌方前线。", "auto", [("always","freeze","selected-enemy",1)], keywords=["STUN"]),
    C("觉醒·月隐", "awakening", 3, 1, "SSR", 1, "觉醒：获得 +1/+1，匿影升级。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"shizhu": [
    C("岩拳", "combat", 1, 1, "R", 2, "出击 +1。", "auto", [("source-ready","assault","source",1)]),
    C("固阵", "spell", 1, 1, "R", 1, "一名友方角色获得 3 点护甲。", "ally-unit", [("always","shield","selected-ally",3)]),
    C("山门之相", "form", 2, 1, "R", 1, "获得 +1/+5。", "auto", [("always","form","source",{"attack":1,"hp":5})]),
    C("镇守", "combat", 1, 1, "SR", 1, "进入前线并获得 3 点护甲。", "auto", [("always","fortify","source",3)]),
    C("碎岩", "combat", 2, 1, "SR", 1, "出击 +2，并移除目标护甲。", "auto", [("source-ready","assault","source",2),("target-alive","remove-shield","selected-enemy",99)]),
    C("崩山", "spell", 3, 1, "R", 1, "对所有敌方式神造成 2 点伤害。", "auto", [("always","damage","all-enemy-units",2)]),
    C("不坏金身", "spell", 2, 1, "R", 1, "获得不屈与 2 点护甲。", "auto", [("always","grant-unyielding","source",1),("always","shield","source",2)], keywords=["UNYIELDING"]),
    C("觉醒·石主", "awakening", 2, 1, "SSR", 1, "觉醒：山骨升级，获得 +0/+2。", "auto", [("always","awaken","source",{"attack":0,"hp":2})], deckLimit=1),
],
"yanling-huo": [
    C("铃火", "spell", 1, 1, "R", 2, "投射：造成 2 点伤害。", "auto", [("always","damage-enemy-front","auto",2)], keywords=["PROJECTILE"]),
    C("摇铃", "spell", 1, 0, "R", 1, "抽一张牌。", "auto", [("always","draw","ally-player",1)], keywords=["INSTANT"]),
    C("焰径", "spell", 2, 1, "SR", 1, "对敌方前线造成 3 点伤害。", "auto", [("always","damage-enemy-front","auto",3)]),
    C("焚心", "spell", 2, 1, "R", 1, "对一个式神造成 3 点伤害。", "enemy-unit", [("always","damage","selected-enemy",3)]),
    C("摇火之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("炎舞", "spell", 3, 1, "SR", 1, "对所有敌方式神造成 2 点伤害。", "auto", [("always","damage","all-enemy-units",2)]),
    C("铃音护身", "spell", 1, 1, "R", 1, "获得 3 点护甲。", "auto", [("always","shield","source",3)], keywords=["RESPONSE"], timing="response", responseTo=["assault"]),
    C("觉醒·焰铃", "awakening", 2, 1, "SSR", 1, "觉醒：摇火升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"shuimo": [
    C("沫浴", "spell", 1, 1, "R", 2, "恢复 4 点生命。", "ally-unit", [("always","heal","selected-ally",4)]),
    C("潮护", "spell", 1, 1, "R", 1, "一名友方角色获得 3 点护甲。", "ally-unit", [("always","shield","selected-ally",3)]),
    C("回澜", "spell", 1, 0, "R", 1, "恢复己方核心 2 点生命。", "auto", [("always","heal-avatar","ally-avatar",2)], keywords=["INSTANT"]),
    C("潮语之相", "form", 2, 1, "R", 1, "获得 +1/+5。", "auto", [("always","form","source",{"attack":1,"hp":5})]),
    C("碧波", "spell", 2, 1, "SR", 1, "为所有己方式神恢复 3 点生命。", "auto", [("always","heal","all-ally-units",3)]),
    C("海沫", "spell", 2, 1, "R", 1, "恢复 5 点生命并获得 2 点护甲。", "ally-unit", [("always","heal","selected-ally",5),("always","shield","selected-ally",2)]),
    C("怒潮", "spell", 3, 1, "SR", 1, "对所有敌方式神造成 2 点伤害。", "auto", [("always","damage","all-enemy-units",2)]),
    C("觉醒·水沫", "awakening", 2, 1, "SSR", 1, "觉醒：潮语升级，获得 +0/+2。", "auto", [("always","awaken","source",{"attack":0,"hp":2})], deckLimit=1),
],
"leiyin": [
    C("雷矢", "spell", 1, 1, "R", 2, "对一个式神造成 2 点伤害。", "enemy-unit", [("always","damage","selected-enemy",2)]),
    C("震弦", "spell", 1, 1, "R", 1, "眩晕一个敌方式神。", "enemy-unit", [("always","freeze","selected-enemy",1)], keywords=["STUN"]),
    C("雷走", "combat", 1, 1, "R", 1, "出击 +1。", "auto", [("source-ready","assault","source",1)]),
    C("弦怒之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("爆雷", "spell", 2, 1, "SR", 1, "对敌方前线造成 4 点伤害。", "auto", [("always","damage-enemy-front","auto",4)]),
    C("连环雷", "spell", 2, 1, "R", 1, "对两个随机敌方角色造成 2 点伤害（简化为全体 1 伤）。", "auto", [("always","damage","all-enemy-units",1)]),
    C("雷盾", "spell", 1, 1, "R", 1, "获得 3 点护甲。", "auto", [("always","shield","source",3)], keywords=["RESPONSE"], timing="response", responseTo=["assault"]),
    C("觉醒·雷音", "awakening", 2, 1, "SSR", 1, "觉醒：震弦升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"xingchen": [
    C("星屑", "spell", 1, 0, "R", 2, "抽一张牌。", "auto", [("always","draw","ally-player",1)], keywords=["INSTANT"]),
    C("尘光", "spell", 1, 1, "R", 1, "对一个式神造成 2 点伤害。", "enemy-unit", [("always","damage","selected-enemy",2)]),
    C("卜算", "spell", 1, 1, "SR", 1, "占卜 3，然后抽一张牌。", "auto", [("always","divination","ally-player",3),("always","draw","ally-player",1)], keywords=["DIVINATION"], divination={"count": 3}),
    C("星轨之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("陨星", "spell", 2, 1, "SR", 1, "对敌方前线造成 3 点伤害。", "auto", [("always","damage-enemy-front","auto",3)]),
    C("尘护", "spell", 1, 1, "R", 1, "一名友方角色获得 3 点护甲。", "ally-unit", [("always","shield","selected-ally",3)]),
    C("星爆", "spell", 3, 1, "SR", 1, "对所有敌方式神造成 2 点伤害。", "auto", [("always","damage","all-enemy-units",2)]),
    C("觉醒·星尘", "awakening", 2, 1, "SSR", 1, "觉醒：尘轨升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"momo": [
    C("墨爪", "combat", 1, 1, "R", 2, "出击 +2，并施加 1 破甲。", "auto", [("source-ready","assault","source",2),("target-alive","apply-armor-break","selected-enemy",1)]),
    C("梦蚀", "spell", 1, 1, "R", 1, "使一个敌方角色获得 2 破甲。", "enemy-unit", [("always","apply-armor-break","selected-enemy",2)]),
    C("墨雾", "spell", 1, 0, "R", 1, "获得 2 点护甲。", "auto", [("always","shield","source",2)], keywords=["INSTANT"]),
    C("蚀梦之相", "form", 2, 1, "R", 1, "获得 +2/+5。", "auto", [("always","form","source",{"attack":2,"hp":5})]),
    C("噬心", "spell", 2, 1, "SR", 1, "对一个式神造成 3 点伤害并施加 2 破甲。", "enemy-unit", [("always","damage","selected-enemy",3),("target-alive","apply-armor-break","selected-enemy",2)]),
    C("墨牢", "spell", 2, 1, "R", 1, "眩晕敌方前线。", "auto", [("always","freeze","selected-enemy",1)], keywords=["STUN"]),
    C("吞梦", "combat", 3, 1, "SR", 1, "出击 +3。", "auto", [("source-ready","assault","source",3)]),
    C("觉醒·墨貘", "awakening", 2, 1, "SSR", 1, "觉醒：梦蚀升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"jinguang": [
    C("辉印", "spell", 1, 1, "R", 2, "鼓舞：+2 力量与 +2 护甲。", "auto", [("always","apply-keyword","ally-player",{"keywordId":"encourage","attack":2,"shield":2})], keywords=["ENCOURAGE"]),
    C("金身", "spell", 1, 1, "R", 1, "获得不屈。", "auto", [("always","grant-unyielding","source",1)], keywords=["UNYIELDING"]),
    C("光矢", "combat", 1, 1, "R", 1, "出击 +1。", "auto", [("source-ready","assault","source",1)]),
    C("辉印之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("扬辉", "spell", 2, 1, "SR", 1, "所有友方 +1 力量。", "auto", [("always","buff-stats","all-ally-units",{"attack":1,"hp":0})]),
    C("印缚", "spell", 2, 1, "R", 1, "眩晕一个敌方式神。", "enemy-unit", [("always","freeze","selected-enemy",1)], keywords=["STUN"]),
    C("大辉印", "spell", 3, 1, "SR", 1, "鼓舞：+3 力量与 +3 护甲。", "auto", [("always","apply-keyword","ally-player",{"keywordId":"encourage","attack":3,"shield":3})], keywords=["ENCOURAGE"]),
    C("觉醒·金光", "awakening", 2, 1, "SSR", 1, "觉醒：辉印升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
}

# starter normalization: awakening starter=1, sum to 8, max 1 SSR starter
for uid, cards in CARDS.items():
    for c in cards:
        if c["type"] == "awakening":
            c["starter"] = 1
    total = sum(c["starter"] for c in cards)
    # cut extras from largest non-awakening
    if total > 8:
        for c in sorted([x for x in cards if x["type"] != "awakening"], key=lambda x: -x["starter"]):
            if total <= 8:
                break
            cut = min(total - 8, c["starter"])
            c["starter"] -= cut
            total -= cut
    elif total < 8:
        for c in sorted([x for x in cards if x["type"] != "awakening"], key=lambda x: -x["starter"]):
            if total >= 8:
                break
            room = min(8 - total, 2 - c["starter"])
            if room > 0:
                c["starter"] += room
                total += room
    # at most 1 SSR in starter
    ssr = [c for c in cards if c.get("rarity") == "SSR" and c["starter"] > 0 and c["type"] != "awakening"]
    if len(ssr) > 1:
        for c in ssr[1:]:
            c["starter"] = 0
        # rebalance
        total = sum(c["starter"] for c in cards)
        for c in sorted([x for x in cards if x["type"] != "awakening" and x.get("rarity") != "SSR"], key=lambda x: -x["starter"]):
            if total >= 8:
                break
            room = min(8 - total, 2 - c["starter"])
            if room > 0:
                c["starter"] += room
                total += room


def js_effects(effects):
    import json
    rows = []
    for cond, action, target, value in effects:
        if value is None:
            val = "null"
        elif isinstance(value, dict):
            val = json.dumps(value, ensure_ascii=False)
        elif isinstance(value, str):
            val = json.dumps(value, ensure_ascii=False)
        else:
            val = str(value)
        rows.append(f'      ["{cond}", "{action}", "{target}", {val}],')
    return "\n".join(rows)


def main():
    import json
    lines = []
    lines.append("""/**
 * 灵枢原创·二弹（wave12，8 式神）内容 — 由 scripts/gen-wave12-content.py 生成。
 * 原创墨夜和风设定，与网易 IP 无关。效果仅映射已有动作。
 */
import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';

export const WAVE12_PACK_ID = 'wave12';
export const WAVE12_PACK_NAME = '灵枢原创·二弹';

function passive(id, name, text, hooks) {
  return Object.freeze({
    id, name, text,
    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),
  });
}

function eff(condition, action, target, value = null) {
  return { condition, action, target, value };
}

function wave12Card(officialId, unitId, meta) {
  const effects = Object.freeze((meta.effects ?? []).map((step) => Object.freeze(eff(step[0], step[1], step[2], step[3] ?? null))));
  return Object.freeze({
    id: meta.id ?? `c${officialId}`,
    unitId,
    name: meta.name,
    type: meta.type,
    typeLabel: ({ combat: '战斗牌', spell: '法术牌', form: '形态牌', realm: '幻境牌', awakening: '觉醒牌' })[meta.type] ?? '牌',
    level: meta.level,
    cost: meta.cost ?? 1,
    copies: meta.deckLimit ?? 2,
    deckLimit: meta.deckLimit ?? 2,
    starterCopies: meta.starter ?? 0,
    rarity: ({ R: 'common', SR: 'rare', SSR: 'ssr', common: 'common', rare: 'rare', ssr: 'ssr' })[meta.rarity] ?? 'common',
    tags: Object.freeze(meta.tags ?? []),
    keywords: Object.freeze((meta.keywords ?? []).map((key) => CARD_KEYWORDS[key]).filter(Boolean)),
    timing: meta.timing ?? 'main',
    responseTo: Object.freeze(meta.responseTo ?? []),
    text: meta.text,
    officialText: meta.officialText ?? meta.text,
    target: meta.target ?? 'auto',
    effect: effects[0]?.action ?? 'noop',
    value: effects[0]?.value ?? null,
    effects,
    pack: 'wave12',
    subpack: 'origin2',
    token: false,
    ...(meta.divination ? { divination: Object.freeze(meta.divination) } : {}),
  });
}

export const WAVE12_UNIT_DEFINITIONS = Object.freeze([""")
    for u in UNITS:
        pid, pname, ptext, phooks = u["passive"]
        aid, aname, atext, ahooks = u["awakened"]
        def hooks_js(hooks):
            out = []
            for hid, ev, eff, params in hooks:
                out.append(f'      {{ id: "{hid}", event: "{ev}", effect: "{eff}", params: {json.dumps(params, ensure_ascii=False)} }}')
            return ",\n".join(out)
        lines.append(f'''  {{
    id: "{u['id']}",
    name: "{u['name']}",
    title: "{u['title']}",
    role: "{u['role']}",
    strategy: "{u['strategy']}",
    maxHp: {u['hp']},
    attack: {u['atk']},
    art: "assets/wave12/{u['id']}.svg",
    awakenedArt: "assets/wave12/{u['id']}-awakened.svg",
    color: "{u['color']}",
    pack: "wave12",
    subpack: "origin2",
    officialRole: "origin2-{u['id']}",
    officialAbility: "{u['official']}",
    passive: passive("{pid}", "{pname}", "{ptext}", [
{hooks_js(phooks)}
    ]),
    awakenedPassive: passive("{aid}", "{aname}", "{atext}", [
{hooks_js(ahooks)}
    ]),
  }},''')
    lines.append("""]);

export const WAVE12_CARD_DEFINITIONS = Object.freeze([""")
    oid = 92100
    for u in UNITS:
        for c in CARDS[u["id"]]:
            oid += 1
            extra = ""
            if c.get("keywords"):
                extra += f'\n    keywords: [{", ".join(chr(34)+k+chr(34) for k in c["keywords"])}],'
            if c.get("timing") == "response":
                extra += f'\n    timing: "response",\n    responseTo: [{", ".join(chr(34)+x+chr(34) for x in c.get("responseTo", []))}],'
            if c.get("deckLimit"):
                extra += f'\n    deckLimit: {c["deckLimit"]},'
            if c.get("divination"):
                extra += f'\n    divination: {json.dumps(c["divination"], ensure_ascii=False)},'
            tags = ["原创", c["type"]]
            lines.append(f'''  wave12Card({oid}, "{u['id']}", {{
    id: "w12-{u['id']}-{oid}",
    name: "{c['name']}",
    type: "{c['type']}",
    level: {c['level']},
    cost: {c['cost']},
    rarity: "{c['rarity']}",
    starter: {c['starter']},
    deckLimit: {c.get('deckLimit', 2)},
    text: "{c['text']}",
    officialText: "{c['text']}",
    target: "{c['target']}",
    tags: {json.dumps(tags, ensure_ascii=False)},{extra}
    effects: [
{js_effects(c['effects'])}
    ],
  }}),''')
    lines.append("""]);

export function getWave12UnitIds() {
  return WAVE12_UNIT_DEFINITIONS.map((unit) => unit.id);
}
""")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    total = sum(len(v) for v in CARDS.values())
    print(f"Wrote {OUT} units={len(UNITS)} cards={total}")
    for u in UNITS:
        st = sum(c["starter"] for c in CARDS[u["id"]])
        aw = sum(1 for c in CARDS[u["id"]] if c["type"] == "awakening")
        print(u["id"], "starter", st, "awaken", aw)


if __name__ == "__main__":
    main()
