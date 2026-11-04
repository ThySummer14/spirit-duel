from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
sources = [
    {"id": "arakawa-original-20261102", "path": "art-reference-official/卡面-按版本/15_振剑归川/271_荒川之主/", "evidence": "9张完整原PNG；激流固定条件增强+2、逐流法术占卜1，优先于旧卡库。"},
    {"id": "arakawa-preview-20220929", "url": "https://note.com/vongole8940/n/nf13350009383", "evidence": "同期完整原卡介绍译注：游鱼2/2无额外能力；湮灭消灭吞噬指定式神。"},
]
pending = ["按完整原PNG和基础牌文实现主要机制，指定录像未逐牌核验。自动用牌计数、形态生效与用牌后触发顺序、多源蓄力和死亡/复活的完整全序仍待实机核验。", "游鱼和湮灭无独立本地原PNG，沿用同期介绍的基础规则，不追逐后续季节平衡。游鱼派系暂无独立原图证据，保留未知。"]
texts = {
    1: "获得1点鬼火。从手牌使用后再次蓄力归流。",
    2: "投射：造成2点伤害。从手牌使用后再次蓄力聚流。",
    3: "当你本回合使用第二张牌后，召唤一个「游鱼」。",
    4: "对一个式神造成4点伤害。增强：本回合若你使用过两张或以上其他牌，此牌伤害+2。",
    5: "当你使用牌时，若是本回合使用的第二张则对所有敌方角色造成1点伤害；若是第三张则占卜2；若是第四张则为所有己方角色恢复3生命。",
    6: "占卜1，抽一张牌。从手牌使用后再次蓄力逐流。",
    7: "选择一个式神，蓄力一张「湮灭」。于荒川之主蓄力期间，该式神保持眩晕。",
    8: "觉醒：每回合当你使用第二张牌后，对敌方牌手造成2点伤害并将其眩晕。",
}
unit = {"verifiedRules": True, "arakawaRules": True, "attack": 2, "maxHp": 5, "formLifecycle": {}, "passive": {"id": "arakawa-second", "name": "川流", "text": "每回合当你使用第二张牌后，对一个力量最大的敌方式神造成1点伤害。", "hooks": []}, "awakenedPassive": {"id": "arakawa-second-awake", "name": "川流", "text": texts[8].removeprefix("觉醒："), "hooks": []}, "sources": [s["id"] for s in sources], "verificationPending": pending}
cards = {}
for n in range(1, 9):
    action = {1: "ark-fire", 2: "ark-projectile", 3: "form", 4: "ark-torrent", 5: "form", 6: "ark-divine-draw", 7: "ark-devour", 8: "ark-awaken"}[n]
    value = {"attack": 2, "hp": 5, "setBase": True} if n == 3 else {"attack": 5, "hp": 5, "setBase": True} if n == 5 else {"attack": 1, "hp": 1} if n == 8 else 4 if n == 4 else 0
    c = {"verifiedRules": True, "arakawaRules": True, "type": "form" if n in [3, 5] else "awakening" if n == 8 else "spell", "typeLabel": "形态牌" if n in [3, 5] else "觉醒牌" if n == 8 else "法术牌", "level": [1, 1, 1, 2, 2, 2, 3, 2][n-1], "cost": 1, "copies": 2, "deckLimit": 2, "target": "any-unit" if n in [4, 7] else "auto", "text": texts[n], "officialText": texts[n], "keywords": [], "tags": [], "timing": "main", "responseTo": [], "formRules": {"arkFish": True} if n == 3 else {"arkHome": True} if n == 5 else {}, "formHooks": [], "formAbility": texts[n] if n in [3, 5] else "", "effect": action, "value": value, "effects": [{"action": action, "target": "selected" if n in [4, 7] else "source", "value": value}], "sources": [s["id"] for s in sources], "verificationPending": pending}
    if n in [2, 4]: c["responseAction"] = "damage"
    if n == 7: c["responseAction"] = "freeze"
    cards[f"c271{n:02d}"] = c
derivative = {"id": "arakawa-annihilate", "unitId": "huangchuanzhizhu", "name": "湮灭", "type": "spell", "typeLabel": "法术牌", "level": 3, "cost": 0, "copies": 0, "deckLimit": 0, "token": True, "text": "消灭吞噬所选择的式神。", "officialText": "消灭吞噬所选择的式神。", "target": "any-unit", "keywords": [], "effect": "ark-annihilate", "value": 0, "effects": [{"action": "ark-annihilate", "target": "selected", "value": 0}], "verifiedRules": True, "arakawaRules": True, "timing": "main", "responseTo": [], "sources": [s["id"] for s in sources], "verificationPending": pending}
cards[derivative["id"]] = derivative
(out / "overlay.json").write_text(json.dumps({"sources": sources, "units": {"huangchuanzhizhu": unit}, "cards": cards}, ensure_ascii=False, indent=2) + "\n")
(out / "new_definitions.json").write_text(json.dumps({"units": [], "cards": [derivative]}, ensure_ascii=False, indent=2) + "\n")
raw = json.loads((root / "research-data/cards.json").read_text())
(out / "official-source-evidence.json").write_text(json.dumps([r for r in raw if r.get("role") == 271], ensure_ascii=False, indent=2) + "\n")
manifest = []
for n in range(1, 9):
    source = next((root / "art-reference-official/卡面-按版本/15_振剑归川/271_荒川之主").glob(f"271{n:02d}_*.png"))
    target = root / f"godot/assets/official/cards/c271{n:02d}.png"
    shutil.copy2(source, target)
    manifest.append({"source": str(source.relative_to(root)), "target": str(target.relative_to(root)), "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
(out / "card-art-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print("ARAKAWA_PREPARED main_cards=8 derivative=1")
