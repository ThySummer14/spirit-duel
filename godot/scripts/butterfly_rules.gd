class_name ButterflyRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const SKILLS := ["c27401", "c27402", "c27404", "c27405"]

static func source(unit: Dictionary) -> bool:
	return Content.runtime_unit_def(unit).get("butterflyRules", false)
static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary, from_hand: bool = true) -> Dictionary:
	if not card.get("butterflyRules", false): return card
	var view := card.duplicate(true)
	var src: int = gs._source_index(owner, card)
	if src >= 0 and gs.player(owner).units[src].awakened and view.type == "spell":
		view.type = "combat"
		view.typeLabel = "战斗牌"
		view.butterflyCombat = true
		view.effects.append({"action": "butterfly-combat", "target": "self", "value": 0})
		view.text += "\n觉醒：此牌变为战斗牌，结算效果后蝴蝶精发起攻击。"
	if from_hand and int(inst.get("butterflyInstantTurn", -1)) == gs.turn_counter:
		if not view.keywords.has("instant"): view.keywords.append("instant")
		view.butterflyHandDraw = true
		view.text += "\n本回合瞬发，使用时抽一张牌。"
	if from_hand and int(inst.get("butterflyFreeTurn", -1)) == gs.turn_counter:
		view.cost = 0
		view.text += "\n玲珑蝶影：本回合不消耗鬼火。"
	return view

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("butterflyRules", false) or card.get("effect") != "butterfly-dream": return null
	var src: int = gs._source_index(owner, card)
	var targets: Array = []
	for i in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[i]
		if i == src or unit.get("removed", false) or not gs.VerifiedRules.OwlInsect.shikigami(unit): continue
		if int(unit.hp) <= 0:
			if gs.VerifiedRules.Rebirth.can_revive(unit): targets.append(unit.uid)
		elif gs.VerifiedRules.Samurai.available(unit) and not unit.get("cannotAttack", false) and not gs.VerifiedRules.Stun.blocks(gs, owner, unit) and int(unit.level) > 0:
			if gs.VerifiedRules.Combat.has(unit, "remote") or not gs.VerifiedRules.Bingyong.replacement_blocked(gs, owner, unit): targets.append(unit.uid)
	return targets

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("butterflyRules", false): return true
	var src: int = gs._source_index(owner, card)
	return src >= 0 and not (card.type == "awakening" and gs.player(owner).units[src].awakened)

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.get("butterflyHandDraw", false) and card.get("sourceZone", "hand") == "hand" and not frame.get("automatic", false) and not card.get("battleSkillTriggered", false):
		gs._draw(int(frame.playerIndex), 1)
		gs.VerifiedRules.event(gs, "butterfly-hand-draw", {"player": int(frame.playerIndex), "card": card})

static func generate(gs, owner: int, src: int) -> void:
	var id: String = SKILLS[mini(SKILLS.size() - 1, int(gs.randf01() * SKILLS.size()))]
	var inst := {"definitionId": id, "instanceId": "butterfly-%d" % gs.next_card_id, "butterflyFreeTurn": gs.turn_counter}
	gs.next_card_id += 1
	if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
	else: gs._log("手牌已满，玲珑蝶影生成的战技牌被烧毁。", gs.TONE_DANGER)
	gs.VerifiedRules.event(gs, "butterfly-generated", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": Content.card_def(id), "instanceId": inst.instanceId})

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules", {}).get("butterflySwift", false): gs.player(owner).units[src].swift = true
	if card.get("formRules", {}).get("butterflyGenerate", false): generate(gs, owner, src)

static func form_turn_start(gs, owner: int, src: int) -> void:
	if gs.player(owner).units[src].get("formRules", {}).get("butterflySwift", false): gs.player(owner).units[src].swift = true

static func before_basic(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not source(unit) or not active(unit): return
	gs.resolution_stack.append({"kind": "butterfly-generate-basic", "playerIndex": owner, "sourceIndex": src})
	if not unit.get("form", {}).is_empty() or int(unit.level) < 3 or gs.VerifiedRules.Stun.blocks(gs, owner, unit): return
	for i in gs.player(owner).hand.size():
		var card: Dictionary = gs.hand_card_def(owner, i)
		if card.id != "c27407": continue
		gs.take_card_instance(owner, i)
		gs._push_card_frames(owner, str(card.id), null, card, src, 0, true)
		gs.VerifiedRules.event(gs, "butterfly-auto-form", {"player": owner, "uid": unit.uid, "card": card})
		return

static func after_basic(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not source(unit) or not active(unit): return
	for inst in gs.player(owner).hand:
		if str(inst.definitionId) in SKILLS: inst.butterflyInstantTurn = gs.turn_counter
	gs.VerifiedRules.event(gs, "butterfly-after-basic", {"player": owner, "uid": unit.uid})

static func free_realm(gs, owner: int) -> Dictionary:
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm") == "butterfly-march" and int(realm.hp) > 0 and int(realm.get("butterflyUsedTurn", -1)) != gs.turn_counter: return realm
	return {}

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"butterfly-encourage": gs._apply_encourage(owner, 2, 1)
		"butterfly-enrage":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(target.get("uid", "")))
			if idx >= 0:
				gs.resolution_stack.append({"kind": "butterfly-enrage-after", "playerIndex": owner, "targetUid": target.uid})
				gs._damage_unit(1 - owner, idx, 2 + (int(gs.player(owner).units[src].get("spellPower",0)) if Content.is_spell(card) else 0), owner, src)
		"butterfly-dream":
			var idx: int = gs._unit_index_by_uid(owner, str(target.get("uid", "")))
			if idx >= 0:
				if int(target.hp) <= 0: gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false)
				elif str(target.uid) in targets(gs, owner, card): gs.basic_attack_ex(owner, idx, 0, false)
		"butterfly-move":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(target.get("uid", "")))
			if idx >= 0 and int(target.hp) > 0:
				gs.resolution_stack.append({"kind": "butterfly-zero-after", "playerIndex": owner, "targetUid": target.uid})
				gs.VerifiedRules.Movement.move_to(gs, 1 - owner, idx, 1)
		"butterfly-combat":
			gs._record("assault", {"unit": src, "bonus": 0, "target": null}, owner)
			gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"combatCard": card.duplicate(true), "butterflyEncourageCombat": true})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	match str(frame.get("kind", "")):
		"butterfly-generate-basic":
			var unit: Dictionary = gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
			if active(unit) and unit.get("formRules", {}).get("butterflyGenerate", false): generate(gs, int(frame.playerIndex), int(frame.sourceIndex))
		"butterfly-enrage-after":
			var idx: int = gs._unit_index_by_uid(1 - int(frame.playerIndex), str(frame.targetUid))
			if idx >= 0: gs.VerifiedRules.MonkCleaner.enrage(gs, 1 - int(frame.playerIndex), idx)
		"butterfly-zero-after":
			var owner := 1 - int(frame.playerIndex)
			var idx: int = gs._unit_index_by_uid(owner, str(frame.targetUid))
			if idx >= 0 and int(gs.player(owner).units[idx].hp) > 0:
				gs.player(owner).units[idx].movementZeroTurn = gs.turn_counter
				gs._recalc(gs.player(owner).units[idx])
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target):
	if not card.get("butterflyRules", false): return null
	var unit: Dictionary = gs._unit_by_uid(gs._all_units(), target)
	match str(card.get("effect", "")):
		"butterfly-encourage": return 45
		"butterfly-enrage": return 65 + (45 if not unit.is_empty() and int(unit.hp) <= 2 else 0)
		"butterfly-dream": return (100 + int(unit.maxHp)) if not unit.is_empty() and int(unit.hp) <= 0 else 45 + int(unit.get("attack", 0)) * 10
		"butterfly-move": return 50 + int(unit.get("attack", 0)) * 5
		"form": return 70 if card.id == "c27407" else 55
		"awakening": return 95
		"realm": return 80
	return 30
