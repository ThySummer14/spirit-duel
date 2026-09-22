#!/usr/bin/env python3
"""生成 game-content-wave10.js（鬼灭联动·炭治郎/祢豆子，双可选式神）。

效果仅用规则层已有动作；切换双形态简化为两张独立可选式神 + 文案标注。
officialText 保留卡面原文；祢豆子原型卡留空/标注式神位原型。
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research-data"
OUT = ROOT / "game-content-wave10.js"

# 允许的 effect action（与任务约束一致）
ALLOWED_ACTIONS = {
    "assault", "damage", "heal", "shield", "form", "awaken", "buff-stats",
    "apply-keyword", "grant-unyielding", "token-to-hand", "noop", "revive",
    "draw", "freeze",
}

# (uid, official_role, name, title, archetype, color, strategy, subpack, attack, life)
UNITS = [
    ("tanjirou", "182", "炭治郎", "鬼杀", "水之呼吸 / 兄妹", "#2a6f8e",
     "水型连斩成长，兄妹之绊切换祢豆子守护。", "guimie", 3, 5),
    ("nezuko", "182", "祢豆子", "妹", "血鬼术 / 守护", "#c45c78",
     "妹妹守护睡眠回血，牙踢爆血近身反打。", "guimie", 2, 6),
]

ROLE_TO_UID = {182: "tanjirou"}
# 祢豆子卡为双形态简化发明卡（182 位原型）
NEZUKO_OIDS = {18291, 18292, 18293, 18294, 18295, 18296, 18297, 18298}


def F(atk, hp):
    return {"attack": atk, "hp": hp}


def C(name, type, level, cost, rarity, starter, text, effects, **kw):
    d = dict(
        name=name, type=type, level=level, cost=cost, rarity=rarity,
        starter=starter, text=text, effects=effects,
        deck_limit=kw.pop("deck_limit", 2),
    )
    d.update(kw)
    return d


def unit_of(oid: int) -> str:
    if oid in NEZUKO_OIDS:
        return "nezuko"
    return ROLE_TO_UID[oid // 100]


# 炭治郎：research role 182 共 8 张可构筑牌
# 祢豆子：8 张发明卡（切换/守护/睡眠/血鬼术）
# starter 合计=8，觉醒 starter=1，starter SSR≤1，cost 0-2
CARD_MAP: dict[int, dict] = {
    # ---- 炭治郎 182 ----
    18201: C("壹之型·水面斩击", "combat", 1, 1, "R", 1,
             "出击 +2。穿刺（爆能瞬发简化并入）。",
             [("source-ready", "assault", "source", 2)],
             keywords=["PIERCE"], tags=["出击", "穿刺", "水之型"]),
    18202: C("兄妹之绊", "spell", 1, 1, "R", 1,
             "使炭治郎获得 +2/+1 与不屈。切换为祢豆子出击免疫伤害简化为守护强化（双式神可选）。",
             [("always", "buff-stats", "source", F(2, 1)), ("always", "grant-unyielding", "source", 1)],
             keywords=["UNYIELDING"], tags=["切换", "兄妹", "守护"]),
    18203: C("叁之型·流流舞", "combat", 2, 1, "R", 1,
             "出击 +3（爆能追猎简化为出击加成）。",
             [("source-ready", "assault", "source", 3)],
             tags=["出击", "流流舞", "水之型"]),
    18204: C("觉醒·炭治郎/祢豆子", "awakening", 2, 1, "SR", 1,
             "觉醒：+2/+1。切换为祢豆子简化：本包为独立可选式神（详见「兄妹之绊」）。",
             [("always", "awaken", "source", F(2, 1))],
             deck_limit=1, tags=["觉醒", "切换", "兄妹"]),
    18205: C("破箱而出", "spell", 2, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害，并获得 +2/+1（切换祢豆子攻击简化）。",
             [("always", "damage", "selected-enemy", 3), ("always", "buff-stats", "source", F(2, 1))],
             keywords=["RESPONSE"], timing="response", responseTo=["assault"],
             tags=["伤害", "切换", "响应"]),
    18206: C("拾之型·生生流转", "combat", 3, 2, "SR", 1,
             "出击 +3，并获得 +1/+1 与 2 点护甲（成长增强简化）。",
             [("source-ready", "assault", "source", 3), ("always", "buff-stats", "source", F(1, 1)),
              ("always", "shield", "source", 2)],
             tags=["出击", "成长", "水之型"]),
    18208: C("火之神神乐", "form", 3, 2, "SSR", 0,
             "获得 +3/+3。先攻。完成交战后，获得 2 点护甲（回合末切换祢豆子护甲简化）。",
             [("always", "form", "source", F(3, 3))],
             keywords=["FIRST_STRIKE"],
             formAbility="完成交战后，炭治郎获得 2 点护甲。",
             formHooks=[{"id": "form-tanjirou-kagura", "event": "combat-resolved",
                         "effect": "passive-shield-self-after-combat", "params": {"amount": 2}, "priority": 40}],
             deck_limit=2, tags=["形态", "火之神神乐", "切换"]),
    18209: C("最终试炼", "form", 1, 1, "SR", 2,
             "获得 +1/+4。完成交战后，炭治郎获得 1 点力量（造成伤害得能量简化）。",
             [("always", "form", "source", F(1, 4))],
             formAbility="完成交战后，炭治郎获得 1 点力量。",
             formHooks=[{"id": "form-tanjirou-trial", "event": "combat-resolved",
                         "effect": "passive-buff-self", "params": {"attack": 1}, "priority": 40}],
             tags=["形态", "试炼", "成长"]),

    # ---- 祢豆子（发明，182 位双形态原型）----
    18291: C("牙之型", "combat", 1, 1, "R", 1,
             "出击 +2。穿刺（切换为祢豆子出击简化）。",
             [("source-ready", "assault", "source", 2)],
             keywords=["PIERCE"], officialText="", tags=["出击", "穿刺", "牙"]),
    18292: C("爆血", "spell", 1, 1, "R", 1,
             "对一个敌方式神造成 3 点伤害（血鬼术爆血简化）。",
             [("always", "damage", "selected-enemy", 3)],
             officialText="", tags=["伤害", "爆血", "血鬼术"]),
    18293: C("竹筒", "spell", 1, 0, "R", 2,
             "瞬发。为祢豆子恢复 3 点生命，并获得 2 点护甲（竹筒抑制简化）。",
             [("always", "heal", "source", 3), ("always", "shield", "source", 2)],
             keywords=["INSTANT"], officialText="", tags=["治疗", "竹筒", "守护"]),
    18294: C("睡眠", "spell", 2, 1, "R", 1,
             "眩晕一个敌方式神，并为祢豆子恢复 2 点生命（睡眠恢复简化）。",
             [("always", "freeze", "selected-enemy", 1), ("always", "heal", "source", 2)],
             keywords=["STUN"], officialText="", tags=["眩晕", "睡眠", "治疗"]),
    18295: C("踢击", "combat", 2, 1, "R", 1,
             "出击 +3，并获得 +1/+0（近身反打简化）。",
             [("source-ready", "assault", "source", 3), ("always", "buff-stats", "source", F(1, 0))],
             officialText="", tags=["出击", "踢击", "血鬼术"]),
    18296: C("血鬼术·爆血", "form", 2, 1, "SR", 1,
             "获得 +2/+4。完成交战后，对敌方前线造成 2 点伤害（爆血灼烧简化）。",
             [("always", "form", "source", F(2, 4))],
             formAbility="完成交战后，对敌方前线造成 2 点伤害。",
             formHooks=[{"id": "form-nezuko-blood", "event": "combat-resolved",
                         "effect": "passive-damage-enemy-front", "params": {"amount": 2}, "priority": 40}],
             officialText="（式神位原型：182 炭治郎/祢豆子）",
             tags=["形态", "爆血", "血鬼术"]),
    18297: C("妹妹守护", "form", 3, 2, "SSR", 0,
             "获得 +2/+5。不屈。受到伤害后，获得 2 点护甲（妹妹守护简化）。",
             [("always", "form", "source", F(2, 5)), ("always", "grant-unyielding", "source", 1)],
             keywords=["UNYIELDING"],
             formAbility="受到伤害后，获得 2 点护甲。",
             formHooks=[{"id": "form-nezuko-guard", "event": "unit-damaged",
                         "effect": "passive-shield-self", "params": {"amount": 2}, "priority": 40}],
             officialText="（式神位原型：182 炭治郎/祢豆子）",
             deck_limit=2, tags=["形态", "守护", "妹妹"]),
    18298: C("觉醒·祢豆子", "awakening", 3, 1, "SR", 1,
             "觉醒：+1/+3。受到伤害后恢复 1 点生命（睡眠回血简化）。",
             [("always", "awaken", "source", F(1, 3))],
             deck_limit=1, officialText="（式神位原型：182 觉醒·炭治郎/祢豆子）",
             tags=["觉醒", "睡眠", "血鬼术"]),
}

TOKENS: list = []
EXTRA_TOKENS: list = []

PASSIVES = {
    "tanjirou": (
        dict(id="tanjirou-water", name="水之呼吸",
             text="完成交战后，炭治郎获得 1 点力量（生生流转简化）。",
             hooks=[dict(id="water-breath", event="combat-resolved",
                         effect="passive-buff-self", params={"attack": 1})]),
        dict(id="tanjirou-water-awakened", name="火之神神乐·连绵",
             text="完成交战后，获得 2 点力量与 1 点护甲。",
             hooks=[
                 dict(id="water-breath-a", event="combat-resolved",
                      effect="passive-buff-self", params={"attack": 2}),
                 dict(id="water-breath-a2", event="combat-resolved",
                      effect="passive-shield-self-after-combat", params={"amount": 1}),
             ]),
    ),
    "nezuko": (
        dict(id="nezuko-guard", name="妹妹守护",
             text="受到伤害后，祢豆子获得 1 点护甲；睡眠恢复简化为回合开始若在前线恢复 1 点生命。",
             hooks=[
                 dict(id="sister-guard", event="unit-damaged",
                      effect="passive-shield-self", params={"amount": 1}),
                 dict(id="sister-sleep", event="turn-started",
                      effect="passive-heal-self-if-front", params={"amount": 1}),
             ]),
        dict(id="nezuko-guard-awakened", name="血鬼觉醒·守护",
             text="受到伤害后获得 2 点护甲，并在前线恢复 2 点生命。",
             hooks=[
                 dict(id="sister-guard-a", event="unit-damaged",
                      effect="passive-shield-self", params={"amount": 2}),
                 dict(id="sister-sleep-a", event="turn-started",
                      effect="passive-heal-self-if-front", params={"amount": 2}),
             ]),
    ),
}


def js_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def self_check() -> dict:
    """2 units · starter==8 · awakening==1 each · starter SSR≤1 · cost 0-2 · actions 合法。"""
    errors = []
    by_unit: dict[str, list] = {u[0]: [] for u in UNITS}
    for oid, meta in CARD_MAP.items():
        by_unit[unit_of(oid)].append((oid, meta))
        for _c, a, _t, _v in meta.get("effects") or []:
            if a not in ALLOWED_ACTIONS:
                errors.append(f"{meta['name']} 非法 action {a}")
        if not (0 <= int(meta.get("cost", 1)) <= 2):
            errors.append(f"{meta['name']} cost 越界 {meta.get('cost')}")
        for hook in meta.get("formHooks") or []:
            if not str(hook.get("effect", "")).startswith("passive-"):
                errors.append(f"{meta['name']} formHooks 非 passive-*")

    counts = {}
    if len(UNITS) != 2:
        errors.append(f"units={len(UNITS)} != 2")
    for uid, _role, name, *_rest in UNITS:
        cards = by_unit.get(uid, [])
        starter = sum(int(m.get("starter", 0)) for _o, m in cards)
        awks = [m for _o, m in cards if m.get("type") == "awakening"]
        awk_starter = sum(int(m.get("starter", 0)) for m in awks)
        ssr_starter = sum(int(m.get("starter", 0)) for _o, m in cards if m.get("rarity") == "SSR")
        counts[uid] = {
            "cards": len(cards), "starter": starter,
            "awakening": len(awks), "awakening_starter": awk_starter,
            "ssr_starter": ssr_starter,
        }
        if starter != 8:
            errors.append(f"{name} starter={starter} != 8")
        if len(awks) != 1 or awk_starter != 1:
            errors.append(f"{name} awakening={len(awks)} starter={awk_starter}")
        if ssr_starter > 1:
            errors.append(f"{name} starter SSR={ssr_starter} > 1")
    return {"ok": not errors, "errors": errors, "counts": counts}


def main() -> None:
    cards_raw = json.loads((DATA / "cards.json").read_text(encoding="utf-8"))
    by_id = {}
    for c in cards_raw:
        try:
            oid = int(c["id"])
        except Exception:
            continue
        if oid not in by_id:
            by_id[oid] = c

    lines = []
    lines.append("/**")
    lines.append(" * 鬼灭之刃联动（wave10，炭治郎/祢豆子双可选式神）— 由 scripts/gen-wave10-content.py 生成。")
    lines.append(" * 官方双形态切换简化为独立可选式神；卡面原文见 officialText。")
    lines.append(" * 请勿把网易官方美术放入本仓库。")
    lines.append(" */")
    lines.append("import { CARD_KEYWORDS } from './game-keywords.js?v=9d3113fe';")
    lines.append("")
    lines.append("export const WAVE10_PACK_ID = 'wave10';")
    lines.append("export const WAVE10_PACK_NAME = '鬼灭之刃联动';")
    lines.append("export const WAVE10_SUBPACKS = Object.freeze({ guimie: '鬼灭之刃' });")
    lines.append("")
    lines.append("function passive(id, name, text, hooks) {")
    lines.append("  return Object.freeze({")
    lines.append("    id, name, text,")
    lines.append("    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook, params: Object.freeze(hook.params ?? {}) }))),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE10_UNIT_DEFINITIONS = Object.freeze([")

    unit_meta = {}
    for uid, role, name, title, archetype, color, strategy, subpack, atk, life in UNITS:
        pid, aid = PASSIVES[uid]
        shik = next((s for s in json.loads((DATA / "shikigami.json").read_text(encoding="utf-8"))
                     if s.get("name") == name), {})
        ability = shik.get("ability") or (
            "妹妹守护与睡眠。切换为炭治郎简化：本包为独立可选式神。" if uid == "nezuko" else ""
        )
        unit_meta[uid] = dict(subpack=subpack, name=name)

        def hooks_s(hs):
            return ",\n".join(
                "      { id: %s, event: %s, effect: %s, params: %s }" % (
                    js_str(h["id"]), js_str(h["event"]), js_str(h["effect"]),
                    json.dumps(h["params"], ensure_ascii=False),
                ) for h in hs
            )

        lines.append("  {")
        lines.append(f"    id: {js_str(uid)},")
        lines.append(f"    name: {js_str(name)},")
        lines.append(f"    title: {js_str(title)},")
        lines.append(f"    role: {js_str(archetype)},")
        lines.append(f"    strategy: {js_str(strategy)},")
        lines.append(f"    maxHp: {life},")
        lines.append(f"    attack: {atk},")
        lines.append(f"    art: {js_str(f'assets/wave10/{uid}.svg')},")
        lines.append(f"    awakenedArt: {js_str(f'assets/wave10/{uid}-awakened.svg')},")
        lines.append(f"    color: {js_str(color)},")
        lines.append(f"    pack: {js_str('wave10')},")
        lines.append(f"    subpack: {js_str(subpack)},")
        lines.append(f"    officialRole: {js_str(str(role))},")
        lines.append(f"    officialAbility: {js_str(ability)},")
        lines.append("    passive: passive(" + js_str(pid["id"]) + ", " + js_str(pid["name"]) + ", " + js_str(pid["text"]) + ", [\n" + hooks_s(pid["hooks"]) + "\n    ]),")
        lines.append("    awakenedPassive: passive(" + js_str(aid["id"]) + ", " + js_str(aid["name"]) + ", " + js_str(aid["text"]) + ", [\n" + hooks_s(aid["hooks"]) + "\n    ]),")
        lines.append("  },")

    lines.append("]);")
    lines.append("")
    lines.append("function eff(condition, action, target, value = null) {")
    lines.append("  return { condition, action, target, value };")
    lines.append("}")
    lines.append("")
    lines.append("function wave10Card(officialId, unitId, meta) {")
    lines.append("  const effects = Object.freeze((meta.effects ?? []).map((step) => Object.freeze(eff(step[0], step[1], step[2], step[3] ?? null))));")
    lines.append("  return Object.freeze({")
    lines.append("    id: meta.id ?? `c${officialId}`,")
    lines.append("    unitId,")
    lines.append("    name: meta.name,")
    lines.append("    type: meta.type,")
    lines.append("    typeLabel: ({ combat: '战斗牌', spell: '法术牌', form: '形态牌', awakening: '觉醒牌' })[meta.type] ?? '牌',")
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
    lines.append("    pack: 'wave10',")
    lines.append("    subpack: meta.subpack ?? null,")
    lines.append("    token: meta.token === true,")
    lines.append("    ...(meta.formAbility ? { formAbility: meta.formAbility, formHooks: Object.freeze((meta.formHooks ?? []).map((h) => Object.freeze({ priority: 40, ...h, params: Object.freeze(h.params ?? {}) }))) } : {}),")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("export const WAVE10_CARD_DEFINITIONS = Object.freeze([")

    for official_id, meta in sorted(CARD_MAP.items(), key=lambda kv: (unit_of(kv[0]), kv[0])):
        unit_id = unit_of(official_id)
        meta = dict(meta)
        meta["id"] = meta.get("id") or f"c{official_id}"
        meta["subpack"] = unit_meta[unit_id]["subpack"]
        if "officialText" not in meta or meta.get("officialText") is None:
            src = by_id.get(official_id, {})
            meta["officialText"] = (src.get("desc") or meta.get("text") or "").replace("#r", " ").replace("\n", " ")
        body = [
            f"id: {js_str(meta['id'])}",
            f"name: {js_str(meta['name'])}",
            f"type: {js_str(meta['type'])}",
            f"level: {int(meta['level'])}",
            f"cost: {int(meta.get('cost', 1))}",
            f"rarity: {js_str(meta.get('rarity', 'R'))}",
            f"starter: {int(meta.get('starter', 0))}",
            f"deckLimit: {int(meta.get('deck_limit', 2))}",
            f"text: {js_str(meta['text'])}",
            f"officialText: {js_str(meta['officialText'] or '')}",
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
        effs = meta.get("effects") or []
        eff_s = ",\n".join(
            "      [%s, %s, %s, %s]" % (
                js_str(c), js_str(a), js_str(t),
                json.dumps(v, ensure_ascii=False) if v is not None else "null",
            ) for c, a, t, v in effs
        )
        if eff_s:
            body.append("effects: [\n" + eff_s + ",\n    ]")
        body.append(f"subpack: {js_str(meta['subpack'])}")
        lines.append(f"  wave10Card({official_id}, {js_str(unit_id)}, {{")
        lines.append("    " + ",\n    ".join(body) + ",")
        lines.append("  }),")

    lines.append("]);")
    lines.append("")
    lines.append("export function getWave10UnitIds() {")
    lines.append("  return WAVE10_UNIT_DEFINITIONS.map((unit) => unit.id);")
    lines.append("}")
    lines.append("")

    check = self_check()
    if not check["ok"]:
        raise SystemExit("self-check failed: " + "; ".join(check["errors"]))

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    c = check["counts"]
    print(f"Wrote {OUT}")
    print(f"units=2 tanjirou_cards={c['tanjirou']['cards']} nezuko_cards={c['nezuko']['cards']} "
          f"starter={c['tanjirou']['starter']}+{c['nezuko']['starter']} "
          f"awakening={c['tanjirou']['awakening']}+{c['nezuko']['awakening']} ok")


if __name__ == "__main__":
    main()
