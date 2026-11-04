class_name GarudaRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(unit: Dictionary) -> bool:
	return Content.runtime_unit_def(unit).get("garudaRules", false)
static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)
static func enemies(gs, owner: int) -> Array:
	return gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))
static func marked(unit: Dictionary) -> bool:
	return not unit.get("garudaFeather", {}).is_empty()

static func attach(gs, owner: int, src: int, target: Dictionary) -> void:
	if target.is_empty() or int(target.hp) <= 0 or target.get("removed", false): return
	# Non-stacking charm: replacing it changes identity, never adds a second hit.
	target.garudaFeather = {"sourceOwner": owner, "sourceUid": gs.player(owner).units[src].uid, "serial": gs.next_card_id}
	gs.next_card_id += 1
	gs.VerifiedRules.event(gs, "garuda-feather-attached", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": target.uid, "serial": target.garudaFeather.serial})

static func random_mark(gs, owner: int, src: int) -> void:
	var pool := enemies(gs, owner)
	if not pool.is_empty(): attach(gs, owner, src, pool[mini(pool.size() - 1, int(gs.randf01() * pool.size()))])

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary, from_hand: bool = true) -> Dictionary:
	if not card.get("garudaRules", false): return card
	var view := card.duplicate(true)
	if view.id == "c27701":
		view.target = "enemy-unit" if from_hand and not enemies(gs, owner).is_empty() else "auto"
		view.garudaFromHand = from_hand
	if view.id == "c27704":
		var enhanced: bool = enemies(gs, owner).any(func(u): return marked(u))
		view.target = "enemy-unit" if enhanced else "auto"
		view.combatOption.pursuit = enhanced
		if enhanced:
			if not view.keywords.has("pursuit"): view.keywords.append("pursuit")
			view.text += "\n增强已满足：本次可选择追猎目标。"
	if view.id == "c27707": view.formRules.garudaReturnInstance = inst.duplicate(true)
	var src: int = gs._source_index(owner, view)
	if src >= 0:
		var timer: Dictionary = gs.VerifiedRules.Countdown.timer(gs.player(owner).units[src])
		view.currentCardStats = "倒计时%d/2" % int(timer.get("remaining", 2))
	return view

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("garudaRules", false): return true
	var src: int = gs._source_index(owner, card)
	return src >= 0 and not (card.type == "awakening" and gs.player(owner).units[src].awakened)

static func before_basic(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not source(unit) or not active(unit): return
	gs.resolution_stack.append({"kind": "garuda-feathers", "playerIndex": owner, "sourceIndex": src})
	if not unit.get("form", {}).is_empty() or int(unit.level) < 3 or gs.VerifiedRules.Stun.blocks(gs, owner, unit): return
	for i in gs.player(owner).hand.size():
		var card: Dictionary = gs.hand_card_def(owner, i)
		if card.id != "c27707": continue
		gs.take_card_instance(owner, i)
		gs._push_card_frames(owner, str(card.id), null, card, src, 0, true)
		gs.VerifiedRules.event(gs, "garuda-auto-form", {"player": owner, "uid": unit.uid, "card": card})
		return

static func form_removed(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not unit.get("formRules", {}).get("garudaReturn", false): return
	gs.resolution_stack.append({"kind": "garuda-return", "playerIndex": owner, "sourceIndex": src, "instance": unit.formRules.get("garudaReturnInstance", {}).duplicate(true)})

static func form_turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if active(unit) and unit.get("formRules", {}).get("garudaRandomMark", false): random_mark(gs, owner, src)

static func assault(gs, owner: int, src: int, card: Dictionary, target_id) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit): return
	var options: Dictionary = card.get("combatOption", {}).duplicate(true)
	options.combatCard = card.duplicate(true)
	gs._grant_unit_armor(unit, int(options.get("shield", 0)))
	var bonus := int(card.value)
	gs._record("assault", {"unit": src, "bonus": bonus, "target": target_id}, owner)
	gs._resolve_combat(owner, src, bonus, false, bool(options.get("remote", false)), false, false, target_id if options.get("pursuit", false) else null, false, options)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"garuda-wings":
			if not active(unit): return true
			unit.swift = true
			gs.VerifiedRules.Combat.grant_inspired(gs, owner, src)
			if unit.awakened: random_mark(gs, owner, src)
			gs.VerifiedRules.event(gs, "garuda-wings", {"player": owner, "uid": unit.uid, "awakened": bool(unit.awakened)})
		"garuda-mark": attach(gs, owner, src, target)
		"garuda-mark-hand":
			if card.get("garudaFromHand", false) and card.get("sourceZone", "hand") == "hand" and not card.get("battleSkillTriggered", false): attach(gs, owner, src, target)
		"garuda-combat": assault(gs, owner, src, card, target_id)
		"garuda-aoe":
			# One card instruction damages the original living enemy group. Death
			# continuations finish before its separate combat instruction starts.
			var targets: Array = enemies(gs, owner).map(func(u): return str(u.uid))
			for uid in targets:
				if gs.winner >= 0: break
				var idx: int = gs._unit_index_by_uid(1 - owner, uid)
				if idx >= 0:
					var hit: Dictionary = gs._damage_unit(1 - owner, idx, 1, owner, src)
					gs.VerifiedRules.event(gs, "garuda-card-hit", {"player": owner, "uid": unit.uid, "target": uid, "victimPlayer": 1-owner, "card": card, "amount": int(hit.get("damage",0)), "blocked": int(hit.get("damage",0)) == 0})
		"garuda-awaken":
			random_mark(gs, owner, src)
			gs._awaken(owner, src, card, effect.value)
			unit.abilityCountdown.mode = "awakened"
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("garuda-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	match kind:
		"garuda-feathers":
			var uid: String = gs.player(owner).units[src].uid
			var hits: Array = []
			for target in enemies(gs, owner):
				var charm: Dictionary = target.get("garudaFeather", {})
				if charm.get("sourceUid", "") == uid:
					hits.append({"kind": "garuda-feather-hit", "playerIndex": owner, "sourceIndex": src, "targetUid": target.uid, "serial": int(charm.serial)})
			hits.reverse(); gs.resolution_stack.append_array(hits)
		"garuda-feather-hit":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(frame.targetUid))
			if idx < 0: return true
			var target: Dictionary = gs.player(1 - owner).units[idx]
			if int(target.hp) <= 0 or int(target.get("garudaFeather", {}).get("serial", -1)) != int(frame.serial): return true
			gs.resolution_stack.append({"kind": "garuda-feather-remove", "playerIndex": owner, "sourceIndex": src, "targetUid": target.uid, "serial": int(frame.serial)})
			var context: Dictionary = gs._card_effect_context
			gs._card_effect_context = {}
			var hit: Dictionary = gs._damage_unit(1 - owner, idx, 2, owner, src)
			gs._card_effect_context = context
			var ability := {"id": "garuda-feather", "unitId": "jialouluo", "name": "惜羽", "type": "ability", "typeLabel": "灵咒", "effects": [{"action": "damage", "value": 2}]}
			gs.VerifiedRules.event(gs, "garuda-feather-hit", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": target.uid, "victimPlayer": 1-owner, "card": ability, "amount": int(hit.get("damage",0)), "blocked": int(hit.get("damage",0)) == 0})
		"garuda-feather-remove":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(frame.targetUid))
			if idx >= 0:
				var target: Dictionary = gs.player(1 - owner).units[idx]
				if int(target.get("garudaFeather", {}).get("serial", -1)) == int(frame.serial): target.erase("garudaFeather")
		"garuda-return":
			var inst: Dictionary = frame.instance.duplicate(true)
			if inst.is_empty():
				inst = {"definitionId": "c27707", "instanceId": "garuda-return-%d" % gs.next_card_id}
				gs.next_card_id += 1
			if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
			else: gs._log("手牌已满，离场的龙巢魔主被烧毁。", gs.TONE_DANGER)
			gs.VerifiedRules.event(gs, "garuda-form-returned", {"player": owner, "uid": gs.player(owner).units[src].uid, "instanceId": inst.instanceId})
	return true

static func attack_score(gs, owner: int, src: int, card: Dictionary, target):
	if not card.get("garudaRules", false): return null
	var unit: Dictionary = gs.player(owner).units[src]
	var power: int = gs.VerifiedRules.Combat.power(gs, owner, unit, int(card.value))
	var score := power * 10
	var victim: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, target)
	if str(target) == "avatar-%d" % (1-owner): score += 80
	elif not victim.is_empty() and power >= int(victim.hp) + int(victim.shield): score += 40
	for enemy in enemies(gs, owner):
		if enemy.get("garudaFeather",{}).get("sourceUid","") == unit.uid: score += 20
	if card.id == "c27705": score += enemies(gs, owner).size() * 10
	if card.id == "c27708": score += 20
	return score

static func score_card(gs, owner: int, card: Dictionary, target):
	if not card.get("garudaRules", false): return null
	var unit: Dictionary = gs._unit_by_uid(gs._all_units(), target)
	match str(card.id):
		"c27701": return 65 + (15 if not unit.is_empty() and not marked(unit) else 0)
		"c27702": return 65 + (20 if not unit.is_empty() and not marked(unit) else 0)
		"c27703": return 50
		"c27704": return 70 + int(unit.get("attack", 0)) * 5
		"c27705": return 65 + enemies(gs, owner).size() * 8
		"c27706": return 95
		"c27707": return 85
		"c27708": return 85
	return 30
