#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""命运抉择（wave13）6 位式神 + 4 张 SKIN 变体卡。"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game-content-wave13.js"

UNITS = [
    dict(id="shiyao-longyechaji", name="时曜泷夜叉姬", title="时曜", role="时序 / 爆发", strategy="时曜回响，叉影连斩。",
         hp=5, atk=3, color="#7a8ab8",
         passive=("shiyao-tide", "时曜", "使用战斗牌后，对敌方前线造成 1 点伤害。",
                  [("tide-zap", "card-played", "passive-damage-enemy-front-on-spell", {"amount": 1})]),
         awakened=("shiyao-tide-a", "永恒时曜", "使用战斗牌后，对敌方前线造成 2 点伤害。",
                   [("tide-zap-a", "card-played", "passive-damage-enemy-front-on-spell", {"amount": 2})]),
         official="命运抉择·时曜泷夜叉姬（卡库快照后式神，按公开设定简化）。"),
    dict(id="baize-yuanqi", name="白泽·缘起", title="缘起", role="占卜 / 支援", strategy="缘起星轨，白泽渡厄。",
         hp=6, atk=2, color="#a0c8b0",
         passive=("baize-seed", "缘起", "己方回合开始时，抽一张牌。",
                  [("seed-draw", "turn-started", "passive-draw-self", {"amount": 1})]),
         awakened=("baize-seed-a", "万缘归一", "己方回合开始时，抽一张牌并恢复 1 点生命。",
                   [("seed-draw-a", "turn-started", "passive-draw-self", {"amount": 1}),
                    ("seed-heal-a", "turn-started", "passive-heal-self-if-front", {"amount": 1})]),
         official="命运抉择·白泽·缘起（白泽重制位，按公开设定简化）。"),
    dict(id="shenqi-huang", name="神启荒", title="神启", role="星辰 / 法术", strategy="神启星陨，荒原裁决。",
         hp=5, atk=2, color="#8898c8",
         passive=("shenqi-star", "神启", "使用法术牌后，对敌方前线造成 1 点伤害。",
                  [("star-burn", "card-played", "passive-damage-enemy-front-on-spell", {"amount": 1})]),
         awakened=("shenqi-star-a", "星神再临", "使用法术牌后，对敌方前线造成 2 点伤害。",
                   [("star-burn-a", "card-played", "passive-damage-enemy-front-on-spell", {"amount": 2})]),
         official="命运抉择·神启荒（荒变体，按公开设定简化）。"),
    dict(id="xuan", name="璇", title="璇玑", role="平衡 / 光暗", strategy="璇玑双衡，光暗相济。",
         hp=6, atk=2, color="#c8b8d8",
         passive=("xuan-balance", "璇玑", "己方回合开始时，随机为一个己方受伤式神恢复 2 点生命。",
                  [("bal-heal", "turn-started", "passive-heal-ally-if-front-or-any", {"amount": 2})]),
         awakened=("xuan-balance-a", "天璇", "己方回合开始时，为所有己方恢复 2 点生命。",
                   [("bal-heal-a", "turn-started", "passive-heal-all-allies", {"amount": 2})]),
         official="命运抉择·璇（卡库快照后式神，按公开设定简化）。"),
    dict(id="yuyuan-banruo", name="御怨般若", title="御怨", role="怨念 / 破甲", strategy="御怨蚀心，般若笑面。",
         hp=5, atk=3, color="#c06070",
         passive=("yuyuan-grudge", "御怨", "对敌方式神造成战斗伤害后，使其获得 1 破甲。",
                  [("grudge-break", "combat-resolved", "passive-armor-break-defender", {"amount": 1})]),
         awakened=("yuyuan-grudge-a", "百怨般若", "对敌方式神造成战斗伤害后，使其获得 2 破甲。",
                   [("grudge-break-a", "combat-resolved", "passive-armor-break-defender", {"amount": 2})]),
         official="命运抉择·御怨般若（般若重制位，按公开设定简化）。"),
    dict(id="luohou", name="罗睺", title="蚀日", role="暗蚀 / 压制", strategy="蚀日吞光，罗睺压境。",
         hp=7, atk=2, color="#6a5060",
         passive=("luohou-eclipse", "蚀日", "己方回合开始时，随机对一个敌方式神造成 1 点伤害。",
                  [("eclipse-zap", "turn-started", "passive-damage-random-enemy", {"amount": 1})]),
         awakened=("luohou-eclipse-a", "吞日", "己方回合开始时，随机对一个敌方式神造成 2 点伤害。",
                   [("eclipse-zap-a", "turn-started", "passive-damage-random-enemy", {"amount": 2})]),
         official="命运抉择·罗睺（卡库快照后式神，按公开设定简化）。"),
]


def C(name, type_, level, cost, rarity, starter, text, target, effects, **extra):
    return dict(name=name, type=type_, level=level, cost=cost, rarity=rarity, starter=starter,
                text=text, target=target, effects=effects, **extra)


CARDS = {
"shiyao-longyechaji": [
    C("时斩", "combat", 1, 1, "R", 2, "出击 +2。", "auto", [("source-ready","assault","source",2)]),
    C("曜光", "spell", 1, 0, "R", 1, "抽一张牌。", "auto", [("always","draw","ally-player",1)], keywords=["INSTANT"]),
    C("叉影", "combat", 2, 1, "SR", 1, "出击 +3。", "auto", [("source-ready","assault","source",3)]),
    C("时序之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("时停", "spell", 2, 1, "R", 1, "眩晕一个敌方式神。", "enemy-unit", [("always","freeze","selected-enemy",1)], keywords=["STUN"]),
    C("永恒一击", "combat", 3, 1, "SR", 1, "出击 +4。", "auto", [("source-ready","assault","source",4)]),
    C("曜盾", "spell", 1, 1, "R", 1, "获得 3 点护甲。", "auto", [("always","shield","source",3)], keywords=["RESPONSE"], timing="response", responseTo=["assault"]),
    C("觉醒·时曜泷夜叉姬", "awakening", 3, 1, "SSR", 1, "觉醒：时曜升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"baize-yuanqi": [
    C("缘起", "spell", 1, 0, "R", 2, "抽一张牌。", "auto", [("always","draw","ally-player",1)], keywords=["INSTANT"]),
    C("白泽佑", "spell", 1, 1, "R", 1, "恢复 4 点生命。", "ally-unit", [("always","heal","selected-ally",4)]),
    C("渡厄", "spell", 1, 1, "R", 1, "一名友方角色获得 3 点护甲。", "ally-unit", [("always","shield","selected-ally",3)]),
    C("缘起之相", "form", 2, 1, "R", 1, "获得 +2/+5。", "auto", [("always","form","source",{"attack":2,"hp":5})]),
    C("卜缘", "spell", 2, 1, "SR", 1, "占卜 3，然后抽一张牌。", "auto", [("always","divination","ally-player",3),("always","draw","ally-player",1)], keywords=["DIVINATION"], divination={"count": 3}),
    C("万缘", "spell", 2, 1, "R", 1, "为所有己方式神恢复 2 点生命。", "auto", [("always","heal","all-ally-units",2)]),
    C("缘灭", "spell", 3, 1, "SR", 1, "对敌方前线造成 4 点伤害。", "auto", [("always","damage-enemy-front","auto",4)]),
    C("觉醒·白泽·缘起", "awakening", 2, 1, "SSR", 1, "觉醒：缘起升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"shenqi-huang": [
    C("星陨", "spell", 1, 1, "R", 2, "对一个式神造成 2 点伤害。", "enemy-unit", [("always","damage","selected-enemy",2)]),
    C("神启", "spell", 1, 0, "R", 1, "抽一张牌。", "auto", [("always","draw","ally-player",1)], keywords=["INSTANT"]),
    C("荒原裁决", "spell", 2, 1, "SR", 1, "对敌方前线造成 3 点伤害。", "auto", [("always","damage-enemy-front","auto",3)]),
    C("神启之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("星辰海", "spell", 3, 1, "SR", 1, "对所有敌方式神造成 2 点伤害。", "auto", [("always","damage","all-enemy-units",2)]),
    C("星盾", "spell", 1, 1, "R", 1, "获得 3 点护甲。", "auto", [("always","shield","source",3)]),
    C("启明", "spell", 2, 1, "R", 1, "所有友方 +1 力量。", "auto", [("always","buff-stats","all-ally-units",{"attack":1,"hp":0})]),
    C("觉醒·神启荒", "awakening", 2, 1, "SSR", 1, "觉醒：神启升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"xuan": [
    C("璇光", "spell", 1, 1, "R", 2, "恢复 4 点生命。", "ally-unit", [("always","heal","selected-ally",4)]),
    C("玑衡", "spell", 1, 1, "R", 1, "一名友方角色获得 +1/+1。", "ally-unit", [("always","buff-stats","selected-ally",{"attack":1,"hp":1})]),
    C("双衡", "spell", 1, 0, "R", 1, "获得 2 点护甲。", "auto", [("always","shield","source",2)], keywords=["INSTANT"]),
    C("璇玑之相", "form", 2, 1, "R", 1, "获得 +2/+5。", "auto", [("always","form","source",{"attack":2,"hp":5})]),
    C("光暗", "spell", 2, 1, "SR", 1, "对一个式神造成 3 点伤害并恢复 3 点生命。", "enemy-unit", [("always","damage","selected-enemy",3),("always","heal","source",3)]),
    C("天衡", "spell", 2, 1, "R", 1, "为所有己方式神恢复 2 点生命。", "auto", [("always","heal","all-ally-units",2)]),
    C("归一", "spell", 3, 1, "SR", 1, "复活一个己方式神。", "knocked-ally", [("always","revive","selected-ally",4)]),
    C("觉醒·璇", "awakening", 2, 1, "SSR", 1, "觉醒：璇玑升级，获得 +1/+2。", "auto", [("always","awaken","source",{"attack":1,"hp":2})], deckLimit=1),
],
"yuyuan-banruo": [
    C("怨爪", "combat", 1, 1, "R", 2, "出击 +2，并施加 1 破甲。", "auto", [("source-ready","assault","source",2),("target-alive","apply-armor-break","selected-enemy",1)]),
    C("御怨", "spell", 1, 1, "R", 1, "使一个敌方角色获得 2 破甲。", "enemy-unit", [("always","apply-armor-break","selected-enemy",2)]),
    C("笑面", "spell", 1, 0, "R", 1, "获得 2 点护甲。", "auto", [("always","shield","source",2)], keywords=["INSTANT"]),
    C("般若之相", "form", 2, 1, "R", 1, "获得 +2/+4。", "auto", [("always","form","source",{"attack":2,"hp":4})]),
    C("百怨蚀心", "spell", 2, 1, "SR", 1, "对一个式神造成 3 点伤害并施加 2 破甲。", "enemy-unit", [("always","damage","selected-enemy",3),("target-alive","apply-armor-break","selected-enemy",2)]),
    C("怨缚", "spell", 2, 1, "R", 1, "眩晕一个敌方式神。", "enemy-unit", [("always","freeze","selected-enemy",1)], keywords=["STUN"]),
    C("御怨斩", "combat", 3, 1, "SR", 1, "出击 +3。", "auto", [("source-ready","assault","source",3)]),
    C("觉醒·御怨般若", "awakening", 2, 1, "SSR", 1, "觉醒：御怨升级，获得 +1/+1。", "auto", [("always","awaken","source",{"attack":1,"hp":1})], deckLimit=1),
],
"luohou": [
    C("蚀日爪", "combat", 1, 1, "R", 2, "出击 +2。", "auto", [("source-ready","assault","source",2)]),
    C("吞光", "spell", 1, 1, "R", 1, "对一个式神造成 2 点伤害。", "enemy-unit", [("always","damage","selected-enemy",2)]),
    C("暗蚀", "spell", 1, 0, "R", 1, "使一个敌方角色获得 1 破甲。", "enemy-unit", [("always","apply-armor-break","selected-enemy",1)], keywords=["INSTANT"]),
    C("罗睺之相", "form", 2, 1, "R", 1, "获得 +2/+5。", "auto", [("always","form","source",{"attack":2,"hp":5})]),
    C("蚀界", "spell", 2, 1, "SR", 1, "对敌方前线造成 3 点伤害。", "auto", [("always","damage-enemy-front","auto",3)]),
    C("黑日", "spell", 3, 1, "SR", 1, "对所有敌方式神造成 2 点伤害。", "auto", [("always","damage","all-enemy-units",2)]),
    C("蚀盾", "spell", 1, 1, "R", 1, "获得 3 点护甲并施加 1 破甲给敌方前线。", "auto", [("always","shield","source",3),("always","apply-armor-break","selected-enemy",1)]),
    C("觉醒·罗睺", "awakening", 2, 1, "SSR", 1, "觉醒：蚀日升级，获得 +1/+2。", "auto", [("always","awaken","source",{"attack":1,"hp":2})], deckLimit=1),
],
}

# SKIN 变体卡：挂在既有角色，starter=0，不进默认构筑
SKIN_CARDS = [
    dict(unit="yaodaoji", name="妖刀万华·幻", type="form", level=3, cost=1, rarity="R", starter=0, deckLimit=2,
         text="妖刀姬获得 +3/+8。形态：战斗时额外先击中对手一次。（皮肤变体）",
         target="auto", effects=[("always","form","source",{"attack":3,"hp":8})], keywords=["COMBO"], skin=True),
    dict(unit="datiangou", name="天狗风乱·幻", type="spell", level=2, cost=1, rarity="R", starter=0, deckLimit=2,
         text="对所有敌方式神造成 2 点伤害。（皮肤变体）",
         target="auto", effects=[("always","damage","all-enemy-units",2)], skin=True),
    dict(unit="yijin-zhentian", name="流浪之羽·幻", type="form", level=3, cost=1, rarity="R", starter=0, deckLimit=2,
         text="获得 +4/+8。（皮肤变体）",
         target="auto", effects=[("always","form","source",{"attack":4,"hp":8})], skin=True),
    dict(unit="yaohu", name="聚气·幻", type="spell", level=1, cost=0, rarity="R", starter=0, deckLimit=2,
         text="抽一张牌。（皮肤变体）",
         target="auto", effects=[("always","draw","ally-player",1)], keywords=["INSTANT"], skin=True),
]

for uid, cards in CARDS.items():
    for c in cards:
        if c["type"] == "awakening":
            c["starter"] = 1
    total = sum(c["starter"] for c in cards)
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


def js_effects(effects):
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
    lines = []
    lines.append(r'''/**
 * 命运抉择（wave13）6 位式神 + SKIN 变体卡 — 由 scripts/gen-wave13-content.py 生成。
 * 命运抉择式神晚于卡库快照，效果按公开设定可玩化简化。
 */
import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';

export const WAVE13_PACK_ID = 'wave13';
export const WAVE13_PACK_NAME = '命运抉择';

function passive(id, name, text, hooks) {
  return Object.freeze({
    id, name, text,
    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),
  });
}

function eff(condition, action, target, value = null) {
  return { condition, action, target, value };
}

function wave13Card(officialId, unitId, meta) {
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
    pack: 'wave13',
    token: false,
    skin: meta.skin === true,
    ...(meta.divination ? { divination: Object.freeze(meta.divination) } : {}),
  });
}

export const WAVE13_UNIT_DEFINITIONS = Object.freeze([
''')
    for u in UNITS:
        pid, pname, ptext, phooks = u["passive"]
        aid, aname, atext, ahooks = u["awakened"]

        def hooks_js(hooks):
            out = []
            for hid, ev, effn, params in hooks:
                out.append(f'      {{ id: "{hid}", event: "{ev}", effect: "{effn}", params: {json.dumps(params, ensure_ascii=False)} }}')
            return ",\n".join(out)

        lines.append(f'''  {{
    id: "{u['id']}",
    name: "{u['name']}",
    title: "{u['title']}",
    role: "{u['role']}",
    strategy: "{u['strategy']}",
    maxHp: {u['hp']},
    attack: {u['atk']},
    art: "assets/wave13/{u['id']}.svg",
    awakenedArt: "assets/wave13/{u['id']}-awakened.svg",
    color: "{u['color']}",
    pack: "wave13",
    officialRole: "destiny-{u['id']}",
    officialAbility: "{u['official']}",
    passive: passive("{pid}", "{pname}", "{ptext}", [
{hooks_js(phooks)}
    ]),
    awakenedPassive: passive("{aid}", "{aname}", "{atext}", [
{hooks_js(ahooks)}
    ]),
  }},''')
    lines.append(''']);

export const WAVE13_CARD_DEFINITIONS = Object.freeze([
''')
    oid = 93100
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
            lines.append(f'''  wave13Card({oid}, "{u['id']}", {{
    id: "w13-{u['id']}-{oid}",
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
    tags: ["命运", "{c['type']}"],{extra}
    effects: [
{js_effects(c['effects'])}
    ],
  }}),''')
    for c in SKIN_CARDS:
        oid += 1
        extra = ""
        if c.get("keywords"):
            extra += f'\n    keywords: [{", ".join(chr(34)+k+chr(34) for k in c["keywords"])}],'
        lines.append(f'''  wave13Card({oid}, "{c['unit']}", {{
    id: "skin-{c['unit']}-{oid}",
    name: "{c['name']}",
    type: "{c['type']}",
    level: {c['level']},
    cost: {c['cost']},
    rarity: "{c['rarity']}",
    starter: 0,
    deckLimit: {c.get('deckLimit', 2)},
    text: "{c['text']}",
    officialText: "{c['text']}",
    target: "{c['target']}",
    tags: ["皮肤", "变体"],
    skin: true,{extra}
    effects: [
{js_effects(c['effects'])}
    ],
  }}),''')
    lines.append(''']);

export function getWave13UnitIds() {
  return WAVE13_UNIT_DEFINITIONS.map((unit) => unit.id);
}
''')
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} units={len(UNITS)} cards={sum(len(v) for v in CARDS.values())} skins={len(SKIN_CARDS)}")
    for u in UNITS:
        st = sum(c["starter"] for c in CARDS[u["id"]])
        aw = sum(1 for c in CARDS[u["id"]] if c["type"] == "awakening")
        print(u["id"], "starter", st, "awaken", aw)


if __name__ == "__main__":
    main()
