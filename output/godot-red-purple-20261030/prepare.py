from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
raw = {int(c["id"]): c for c in json.loads((root / "research-data/cards.json").read_text())}
pending = [
    "按20400–20408、20500–20509完整原PNG与基础牌文接入；初音鼓采用复活+1力量/+1生命/+1护甲，全紫时才移入战斗区，御先狐3/7。指定录像未逐牌核验。",
    "四相觉醒按在场光环处理，重复施法不重复治疗已获光环单位；重复觉醒自身印刷身材、自动使用牌的分类和多源结算完整顺序仍待原客户端核验。",
    "火取剑豪按当前其他红莲式神力量和生命及可观察关键词快照强化，不偷取队友；气绝单位、特殊派生关键词和复杂伤害替换组合仍待原客户端核验。",
]
sources = [
    {"id": "red-purple-original-20261030", "path": "art-reference-official/卡面-按版本/09_四相琉璃/", "evidence": "火取魔20400–20408与源九郎狐20500–20506/20508/20509完整原PNG，16张主体牌。"},
    {"id": "red-purple-fox-adjustment-20220414", "url": "https://www.taptap.cn/moment/263404919191503871", "evidence": "官方公告确认御先狐3/7、初音鼓复活+1力量/+1生命/+1护甲，全紫时移入战斗区，与原PNG一致。"},
    {"id": "red-purple-repeat-awaken-20210429", "url": "https://www.taptap.cn/moment/136561818402291925", "evidence": "官方修复已受四相觉醒光环加成的式神在再次施放觉醒时错误恢复生命；允许重复使用，光环重算不重复治疗。"},
    {"id": "red-purple-mechanism-community", "url": "https://www.taptap.cn/moment/341546240254673892", "evidence": "辅助机制记录说明四相觉醒需在场的光环及自动使用的来源分类；不视为完整原客户端验证。"},
]

def unit(role, text, awakened):
    return {"verifiedRules": True, "redPurpleRole": role, "attack": 2, "maxHp": 5,
            "passive": {"id": "rp-" + role, "name": "红莲之火" if role == "red" else "紫岩之愈", "text": text, "hooks": []},
            "awakenedPassive": {"id": "rp-" + role + "-awake", "name": "红莲之火" if role == "red" else "紫岩之愈", "text": awakened, "hooks": []},
            "formLifecycle": {}, "sources": [s["id"] for s in sources], "verificationPending": pending}

units = {
    "huoqumo": unit("red", "每回合当你使用第二张红莲式神的牌时，火取魔获得1力量和1生命。", "己方其他红莲式神获得1力量和1生命。"),
    "yuanjiulanghu": unit("purple", "当你使用其他紫岩式神的牌时，源九郎狐获得1生命。", "己方所有其他紫岩式神获得1力量和1生命。当你使用其他紫岩式神的牌时，源九郎狐获得1生命。"),
}
texts = {
    20401: "你的出击加成效果在使用此牌时也会生效。增强：若你有出击加成效果，此牌获得瞬发。",
    20402: "贯通。若你有其他力量≥6的式神，获得+3力量。",
    20403: "瞬发。使一个己方式神本回合获得追猎。增强：若己方式神都为红莲派系，该式神额外获得3力量。",
    20404: "进场和己方回合开始时，若己方任一式神的力量为场上最大或同为最大，抽一张牌。",
    20405: "贯通。增强：你每有一个其他未气绝的红莲式神，此牌便获得1力量和1生命。",
    20406: "觉醒：己方其他红莲式神获得1力量和1生命。本回合当你使用第二张红莲式神的牌时，火取魔获得1力量和1生命。",
    20407: "鼓舞：获得+X力量、+X护甲。X为己方存活的红莲式神数量的2倍。",
    20408: "增强：获得己方所有其他红莲式神的力量和生命，并获得他们的关键词能力。",
    20501: "为源九郎狐恢复2生命，此牌造成的过量治疗会转化为力量。",
    20502: "瞬发，选择一项：为一个角色恢复3生命，过量治疗会转化为护甲；使一个幻境获得3耐久。",
    20503: "觉醒：己方所有其他紫岩式神获得1力量和1生命。当你使用其他紫岩式神的牌时，源九郎狐获得1生命。",
    20504: "己方回合当源九郎狐对敌方角色造成战斗伤害时，使该角色获得3破甲，自己获得3护甲。",
    20505: "复活一个己方式神，并使该式神获得1力量、1生命和1护甲。增强：若己方式神都为紫岩派系，再将该式神移入战斗区。",
    20506: "进场和己方回合开始时，若己方任一式神的生命为场上最大或同为最大，抽一张牌。",
    20508: "不屈。增强：你每有一个其他未气绝的紫岩式神，此牌便获得3力量和3生命。",
    20509: "本局游戏每个己方回合结束时，己方所有紫岩式神永久获得+1力量和+1生命。（此效果可以叠加，对气绝式神有效。）",
}
forms = {20402: (3, 6, {"rpMighty": True, "combatKeywords": ["pierce"]}), 20405: (4, 4, {"combatKeywords": ["pierce"]}),
         20408: (3, 3, {}), 20504: (3, 7, {"rpFoxGuard": True}), 20508: (4, 4, {"gluttonKeywords": ["unyielding"]})}
cards = {}
for cid, text in texts.items():
    typ = "form" if cid in forms else "realm" if cid in [20404, 20506] else "combat" if cid in [20401, 20501] else "spell"
    action = {20401: "rp-night-raid", 20403: "rp-renxia", 20406: "rp-awaken", 20407: "rp-alliance", 20501: "rp-fox-hand", 20502: "rp-fox-choice", 20503: "rp-awaken", 20505: "rp-revive", 20509: "rp-journey"}.get(cid, typ)
    value = 1 if cid == 20401 else 0
    target = "ally-unit" if cid == 20403 else "ally-knocked-unit" if cid == 20505 else "auto"
    c = {"verifiedRules": True, "redPurpleRules": True, "type": typ, "typeLabel": {"form": "形态牌", "realm": "幻境牌", "combat": "战斗牌", "spell": "法术牌"}[typ],
         "level": int(raw[cid]["stage"]), "cost": 1, "copies": 2, "deckLimit": 2, "target": target, "text": text, "officialText": text,
         "keywords": ["instant"] if cid in [20403, 20502] else [], "tags": [], "timing": "main", "responseTo": [],
         "formRules": {}, "formHooks": [], "formAbility": "", "sources": [s["id"] for s in sources], "verificationPending": pending}
    if cid in forms:
        a, h, rules = forms[cid]
        value = {"attack": a, "hp": h, "setBase": True}
        c.update(formRules=rules, formAbility=text)
    if cid in [20404, 20506]:
        c["realm"] = {"hp": 6, "nativeRealm": "rp-red-maximum" if cid == 20404 else "rp-purple-maximum", "trigger": "native-continuous", "triggerEffect": ""}
    if cid in [20401, 20501]:
        c["combatOption"] = {"shield": 1 if cid == 20401 else 0}
        c["responseAction"] = "assault"
    if cid in [20406, 20503]: value = {"attack": 1, "hp": 1}
    c.update(effect=action, value=value, effects=[{"action": action, "target": "selected" if target != "auto" else "source", "value": value}])
    cards[f"c{cid}"] = c
overlay = {"units": units, "cards": cards, "sources": sources}
(out / "overlay.json").write_text(json.dumps(overlay, ensure_ascii=False, indent=2) + "\n")
(out / "official-source-evidence.json").write_text(json.dumps({str(cid): raw[cid] for cid in [20400, *range(20401, 20409), 20500, *range(20501, 20507), 20508, 20509]}, ensure_ascii=False, indent=2) + "\n")
manifest = []
for cid in texts:
    source = next((root / "art-reference-official/卡面-按版本/09_四相琉璃").glob(f"{cid // 100}_*/{cid}_*.png"))
    target = root / f"godot/assets/official/cards/c{cid}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    manifest.append({"source": str(source.relative_to(root)), "target": str(target.relative_to(root)), "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
(out / "card-art-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print("RED_PURPLE_OVERLAY_READY", len(cards))
