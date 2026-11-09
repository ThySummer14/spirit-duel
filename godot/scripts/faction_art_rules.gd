extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const TOWER := "shenqilou"
const MASK := "mianqiling-xinsu"
const FACTIONS := ["红莲", "紫岩", "青岚", "苍叶"]
const ROTATION := ["红莲", "苍叶", "青岚", "紫岩"]
const CYCLE := ["青岚", "紫岩", "红莲", "苍叶"]
const SAGES := ["tower-red", "tower-purple", "tower-blue", "tower-green"]
const POWERS := ["tower-power-red", "tower-power-purple", "tower-power-blue", "tower-power-green"]
const TOWER_ASH := "tower-shadow"
const SPENDS := {
	"c29801": [0, 2], "c29802": [1, 3], "c29804": [0, 3],
	"c29805": [0, 1], "c29806": [3, 2], "c29807": [1, 2]
}

static func source(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})

static func mask(gs, owner: int) -> Dictionary:
	var idx := source(gs, owner, MASK)
	if idx < 0: return {}
	var u: Dictionary = gs.player(owner).units[idx]
	return u if gs.VerifiedRules.OwlInsect.active(u) else {}

static func card_faction(gs, owner: int, card: Dictionary) -> String:
	var idx: int = gs._source_index(owner, card)
	return Factions.get_faction(gs.player(owner).units[idx]) if idx >= 0 else ""

static func resolute(u: Dictionary, damage: int) -> int:
	return maxi(0, damage-1) if "resolute" in u.get("formRules", {}).get("combatKeywords", []) else damage

static func ready(gs, owner: int, index: int) -> bool:
	return gs.player(owner).hand.any(func(inst): return inst.definitionId == SAGES[index])

static func count(gs, owner: int, index: int, discarded: bool = false) -> int:
	return int(gs.player(owner).get("towerDiscarded" if discarded else "towerSageCount", {}).get(str(index), 0))

static func tally(gs, owner: int, index: int, discarded: bool = false) -> void:
	var p: Dictionary = gs.player(owner)
	var key := "towerDiscarded" if discarded else "towerSageCount"
	if not p.has(key): p[key] = {}
	p[key][str(index)] = int(p[key].get(str(index), 0)) + 1

static func spend(gs, owner: int, card: Dictionary) -> Array:
	var spent: Array = []
	for index in SPENDS.get(card.id, []):
		var hand: Array = gs.player(owner).hand
		var i := hand.find_custom(func(inst): return inst.definitionId == SAGES[index])
		if i < 0: continue
		gs.discard_hand_card(owner, i)
		tally(gs, owner, index, true)
		tally(gs, owner, index)
		spent.append(index)
	return spent

static func give(gs, owner: int, faction: String) -> void:
	var index := FACTIONS.find(faction)
	if index >= 0: Choice.give(gs, owner, SAGES[index])

static func upgraded(gs, owner: int, idx: int) -> void:
	var src := source(gs, owner, TOWER)
	if src < 0 or src == idx or gs.player(owner).units[src].get("baseRulesSuppressed", false): return
	give(gs, owner, Factions.get_faction(gs.player(owner).units[idx]))

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var out := card
	if card.get("id") == "c62904":
		out = card.duplicate(true)
		var origin := Content.card_def("c20805").duplicate(true)
		origin.unitId = MASK
		out.originCard = origin
	if card.get("id") == "c29803":
		out = card.duplicate(true)
		var extra := 0
		for i in FACTIONS.size():
			if count(gs, owner, i, true) > 0: extra += 1
		var src := source(gs, owner, TOWER)
		if src >= 0: extra += int(gs.player(owner).units[src].get("spellPower", 0))
		out.value = 3+extra
		out.effects[0].value = 3+extra
	if card.get("id") == "c29804" and ready(gs, owner, 3) and not Choice.live_units(gs, 1-owner).is_empty():
		out = card.duplicate(true)
		out.target = "enemy-unit"
	var body := mask(gs, owner)
	var faction := card_faction(gs, owner, card)
	var p: Dictionary = gs.player(owner)
	var instant: bool = int(inst.get("maskInstantTurn", -1)) == gs.turn_counter or int(p.get("towerInstantTurn", -1)) == gs.turn_counter
	if not faction.is_empty() and not body.is_empty():
		instant = instant or faction == body.get("formRules", {}).get("maskFacing", "")
		var next_turn: bool = int(inst.get("maskMirrorFreeTurn", -1)) == gs.turn_counter
		if next_turn:
			out = out.duplicate(true)
			out.cost = 0
	if instant and "instant" not in out.get("keywords", []):
		out = out.duplicate(true)
		out.keywords.append("instant")
	return out

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id") == POWERS[0]:
		return gs.player(owner).units.filter(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)).map(func(u): return str(u.uid))
	if card.get("id") in ["c29803", "c62901", "c62902", "c62907"]:
		var targets := Choice.live_units(gs, owner)
		if card.id != "c62901":
			targets.append_array(Choice.live_units(gs, 1-owner).filter(func(u):
				return not gs.VerifiedRules.Combat.has(u, "veil") and not gs.VerifiedRules.Movement.has_veil(u)))
		return targets.map(func(u): return str(u.uid))
	return null

static func announce(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	if not frame.get("usedFromHand", false): return
	var u := mask(gs, owner)
	if u.is_empty(): return
	var src := source(gs, owner, MASK)
	var faction := card_faction(gs, owner, card)
	if faction.is_empty(): return
	if u.awakened:
		if int(u.get("maskAwakeTurn", -1)) != gs.turn_counter:
			u.maskAwakeTurn = gs.turn_counter
			u.maskTriggered = []
		if not u.has("maskCounts"): u.maskCounts = {}
		if faction not in u.maskTriggered:
			u.maskTriggered.append(faction)
			var amount := mini(4, int(u.maskCounts.get(faction, 0)) + 1)
			u.maskCounts[faction] = amount
			gs.resolution_stack.append({"kind": "mask-awake-effect", "playerIndex": owner, "sourceIndex": src, "faction": faction, "amount": amount})
	if u.get("formRules", {}).get("maskMirror", false) and int(u.get("maskMirrorTurn", -1)) != gs.turn_counter:
		u.maskMirrorTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "mask-mirror-effect", "playerIndex": owner, "faction": CYCLE[(CYCLE.find(faction)+1) % 4]})

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	if p.erase("towerInstantPending"): p.towerInstantTurn = gs.turn_counter
	var src := source(gs, owner, TOWER)
	if src >= 0:
		var u: Dictionary = gs.player(owner).units[src]
		if gs.player(owner).get("towerGreenPermanent", false):
			gs.resolution_stack.append({"kind": "tower-green", "playerIndex": owner, "sourceIndex": src})
		if u.awakened and not u.get("baseRulesSuppressed", false):
			gs.resolution_stack.append({"kind": "tower-awake-choice", "playerIndex": owner})
	var body := mask(gs, owner)
	var face := str(body.get("formRules", {}).get("maskFacing", ""))
	if face in ROTATION:
		body.formRules.maskFacing = ROTATION[(ROTATION.find(face)+1) % 4]
		body.formAbility = "%s派系的己方牌获得瞬发。" % body.formRules.maskFacing

static func play_sage(gs, owner: int, src: int, card: Dictionary, target_id, target: Dictionary) -> void:
	var idx := SAGES.find(str(card.id))
	tally(gs, owner, idx)
	var p: Dictionary = gs.player(owner)
	var power := 1
	if int(p.get("towerBoostTurn", -1)) != gs.turn_counter and p.realms.any(func(r): return r.get("nativeRealm") == "tower-moon" and int(r.hp) > 0):
		p.towerBoostTurn = gs.turn_counter
		power = 4
	match idx:
		0:
			if not target.is_empty():
				target.temporaryAttack = int(target.get("temporaryAttack", 0)) + power
				gs._recalc(target)
		1:
			if str(target_id).begins_with("avatar-"): gs._heal_avatar(int(str(target_id).get_slice("-", 1)), 2*power)
			elif not target.is_empty(): gs._heal_unit(target, 2*power)
		2: gs.VerifiedRules.Divination.start(gs, owner, power)
		3:
			for side in 2:
				var target_idx: int = gs._unit_index_by_uid(side, target_id)
				if target_idx >= 0:
					gs._damage_unit(side, target_idx, power, owner, src)
					break

static func combat_ready(gs, owner: int, src: int, victim: int, idx: int, options: Dictionary) -> void:
	if not options.get("maskDuet", false): return
	var u: Dictionary = gs.player(owner).units[src]
	if idx >= 0 and Factions.same(u, gs.player(victim).units[idx]):
		options.lethal = true
		gs._grant_unit_armor(u, 1)
	else:
		u.combatUnyielding = true
		gs.VerifiedRules.HairPower.give(gs, owner, src, 1)

static func can_counter(frame: Dictionary, card: Dictionary) -> bool:
	return int(frame.sourceIndex) >= 0 and frame.get("usedFromHand", false)

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if src < 0 or not (action.begins_with("tower-") or action.begins_with("mask-")): return false
	var enemy := 1-owner
	var u: Dictionary = gs.player(owner).units[src]
	match action:
		"tower-assault":
			var discarded := spend(gs, owner, card)
			var view := card.duplicate(true)
			var bonus := 1
			var strike_target = null
			if card.id == "c29801":
				if 0 in discarded: bonus += 2; view.combatOption.pierce = true
				if 2 in discarded: view.combatOption.towerStun = true
			else:
				if 0 in discarded:
					var damage := 1+int(u.get("spellPower", 0))
					for opponent in Choice.live_units(gs, enemy): gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, opponent.uid), damage, owner, src)
				if 3 in discarded:
					var idx: int = gs._unit_index_by_uid(enemy, target_id)
					if idx >= 0: gs.VerifiedRules.Movement.move_to(gs, enemy, idx, 1-int(target.front))
					bonus += 1
			gs._resolve_action(owner, src, view, {"action": "assault", "value": bonus}, strike_target, {})
		"tower-form":
			var discarded := spend(gs, owner, card)
			var view := card.duplicate(true)
			if card.id == "c29802":
				if 1 in discarded: view.formRules.towerAttackLethal = true
				if 3 in discarded: u.towerPermanentSwift = true
			if card.id == "c29805":
				if 0 in discarded:
					gs.VerifiedRules.Glutton.record_permanent(u, 2, 0)
					gs._grow_unit(u, 2, 0)
				if 1 in discarded: view.formRules.combatKeywords = ["resolute"]
			gs._apply_form(owner, src, view, effect.value)
			if card.id == "c29805" and 1 in discarded: gs.VerifiedRules.Movement.move_to(gs, owner, src, 1)
		"tower-seal", "mask-damage":
			if target.is_empty(): return true
			var faction := Factions.get_faction(target)
			var amount := int(effect.value)
			if effect.action == "mask-damage":
				amount = Factions.distinct(Choice.live_units(gs, 0)+Choice.live_units(gs, 1)).size()
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx >= 0: gs._damage_unit(side, idx, amount, owner, src)
			if effect.action == "tower-seal": give(gs, owner, faction)
		"tower-draw":
			var discarded := spend(gs, owner, card)
			gs.resolution_stack.append({"kind": "tower-after-draw", "playerIndex": owner, "sourceIndex": src, "spent": discarded})
			gs._draw(owner, 2)
		"tower-counter":
			var original: Dictionary = card.get("restoredCounter", {})
			if original.is_empty(): return true
			var discarded := spend(gs, owner, card)
			var rid := int(original.resolutionId)
			var cancelled: Dictionary = original.get("cardOverride", Content.card_def(str(original.definitionId)))
			gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId", -1)) != rid)
			gs.VerifiedRules.event(gs, "card-nullified", {"player": enemy, "card": cancelled, "resolutionId": rid})
			gs.VerifiedRules.Insight.used(gs, enemy, cancelled, cancelled.get("playedInstance", {}), false)
			if 1 in discarded: gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, int(original.sourceIndex), card)
			if 2 in discarded: gs.player(owner).towerInstantPending = true
		"tower-moon":
			gs._deploy_realm(owner, card)
			if not u.awakened: gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
		"tower-sage": play_sage(gs, owner, src, card, target_id, target)
		"tower-power":
			match POWERS.find(str(card.id)):
				0:
					if gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false):
						gs.VerifiedRules.Glutton.record_permanent(target, 5, 5)
						gs._grow_unit(target, 5, 5)
						target.unyielding = true
						target.keywords = target.get("keywords", []).duplicate()
						target.keywords.append("pierce")
				1: gs._heal_avatar(owner, 30)
				2: gs.player(owner).towerExtraTurns = int(gs.player(owner).get("towerExtraTurns", 0)) + 1
				3:
					gs.player(owner).towerGreenPermanent = true
					gs.resolution_stack.append({"kind": "tower-green", "playerIndex": owner, "sourceIndex": src})
		"mask-duet":
			Choice.attack(gs, owner, gs._unit_index_by_uid(owner, target_id), null, {"maskDuet": true})
		"mask-faces":
			Choice.offer(gs, owner, "mask-faces", FACTIONS, "面观四相", {"sourceIndex": src, "card": card})
		"mask-knowledge":
			var p: Dictionary = gs.player(owner)
			var top: Array = []
			for i in mini(5, p.deck.size()): top.append(p.deck.pop_back())
			for faction in FACTIONS:
				var eligible := top.filter(func(inst): return card_faction(gs, owner, Content.card_def(str(inst.definitionId))) == faction)
				var chosen := Choice.sample(gs, eligible, 1)
				if not chosen.is_empty():
					top.erase(chosen[0])
					gs.VerifiedRules.Baize.put_hand(gs, owner, chosen[0])
			p.deck.append_array(top)
			gs._shuffle(p.deck)
		"mask-ignorance":
			var own := Choice.live_units(gs, owner)
			own.reverse()
			for ally in own:
				gs.resolution_stack.append({"kind": "mask-chain", "playerIndex": owner, "uid": ally.uid})
		"mask-awakening":
			var hand: Array = gs.player(owner).hand
			for faction in FACTIONS:
				var pool := hand.filter(func(inst): return card_faction(gs, owner, Content.card_def(str(inst.definitionId))) == faction)
				var chosen := Choice.sample(gs, pool, 1)
				if not chosen.is_empty(): chosen[0].maskInstantTurn = gs.turn_counter
			gs._awaken(owner, src, card, effect.value)
		"mask-dream":
			var faction := Factions.get_faction(target)
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, side, idx, card)
			for other in FACTIONS:
				if faction == other: continue
				var possible: Array = []
				for side in 2:
					for candidate in gs.player(side).units:
						if Factions.get_faction(candidate) == other and gs.VerifiedRules.YanmieTrio.can_revive(gs, side, candidate):
							possible.append({"side": side, "unit": candidate})
				var picked := Choice.sample(gs, possible, 1)
				if not picked.is_empty(): gs.VerifiedRules.Peach.revive(gs, int(picked[0].side), -1, picked[0].unit, false, false)
		"mask-mirror": gs._apply_form(owner, src, card, effect.value)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	match frame.get("kind"):
		"tower-after-draw":
			var src := int(frame.sourceIndex)
			var drawn := int(gs.player(owner).get("restoredDrawCount", 0))
			if 3 in frame.spent:
				gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, drawn, "虚实难解")
			if 2 in frame.spent:
				var size := 1+drawn
				gs.VerifiedRules.NativeSummons.summon(gs, owner, src, TOWER_ASH, "影", size, size, {"keywords": ["veil"], "art": "assets/official/cards/tower-shadow.png"})
		"tower-green":
			var src := int(frame.sourceIndex)
			var pool := Choice.sample(gs, Choice.live_units(gs, 1-owner), 1)
			if not pool.is_empty(): gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, pool[0].uid), 5, owner, src)
			gs._damage_avatar(1-owner, 5, owner, src)
		"tower-awake-choice":
			var ids: Array = []
			for idx in FACTIONS.size():
				var claimed: bool = POWERS[idx] in gs.player(owner).get("towerClaimed", [])
				ids.append(POWERS[idx] if not claimed and count(gs, owner, idx) >= 4 else SAGES[idx])
			Choice.offer(gs, owner, "tower-sage-choice", ids, "胧月夜")
		"mask-awake-effect":
			var src := int(frame.sourceIndex)
			var amount := int(frame.amount)
			match frame.faction:
				"红莲":
					for ally in Choice.live_units(gs, owner): gs.VerifiedRules.HairPower.give(gs, owner, gs._unit_index_by_uid(owner, ally.uid), amount)
				"苍叶": gs.VerifiedRules.base_damage_projectile(gs, owner, src, amount, "面由心生")
				"青岚": gs.VerifiedRules.Divination.start(gs, owner, amount)
				"紫岩": gs._heal_avatar(owner, amount)
		"mask-mirror-effect":
			var p: Dictionary = gs.player(owner)
			for ally in p.units:
				if Factions.get_faction(ally) == frame.faction: gs.VerifiedRules.Peach.revive(gs, owner, -1, ally, false, false)
			var choices: Array = p.deck.filter(func(inst): return card_faction(gs, owner, Content.card_def(str(inst.definitionId))) == frame.faction)
			var picked := Choice.sample(gs, choices, 1)
			if not picked.is_empty():
				p.deck.erase(picked[0])
				picked[0].maskMirrorFreeTurn = gs.turn_counter
				gs.VerifiedRules.Baize.put_hand(gs, owner, picked[0])
		"mask-chain":
			var u: Dictionary = gs._unit_by_uid(gs.player(owner).units, frame.uid)
			if u.is_empty() or int(u.hp) <= 0: return true
			var choices := Choice.live_units(gs, 1-owner).filter(func(foe): return Factions.same(u, foe))
			var picked := Choice.sample(gs, choices, 1)
			if not picked.is_empty():
				gs.resolution_stack.append({"kind": "mask-chain-heal", "playerIndex": owner, "uid": u.uid})
				Choice.attack(gs, owner, gs._unit_index_by_uid(owner, u.uid), picked[0].uid, {"pursuit": true})
		"mask-chain-heal":
			var u: Dictionary = gs._unit_by_uid(gs.player(owner).units, frame.uid)
			if int(u.hp) <= 0: gs.VerifiedRules.Peach.revive(gs, owner, -1, u, false, false)
			else: gs._heal_unit(u, int(u.maxHp))
		_: return false
	return true

static func choice_card(gs, owner: int, iid: String):
	if Choice.matches(gs, owner, iid, "tower-"): return Content.card_def(iid)
	if gs.pending_choice.get("type") == "mask-faces" and Choice.matches(gs, owner, iid, "mask-faces"): return Choice.face(iid, iid, "%s派系的己方牌获得瞬发。己方回合开始时轮换。" % iid)
	return null

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	if choice_card(gs, owner, iid) == null: return false
	var c := Choice.accept(gs, owner, iid)
	if c.type == "tower-sage-choice":
		var p: Dictionary = gs.player(owner)
		if iid in POWERS:
			if not p.has("towerClaimed"): p.towerClaimed = []
			p.towerClaimed.append(iid)
		Choice.give(gs, owner, iid)
	elif c.type == "mask-faces":
		var card: Dictionary = c.card
		card.formRules.maskFacing = iid
		card.formAbility = "%s派系的己方牌获得瞬发。" % iid
		gs._apply_form(owner, int(c.sourceIndex), card, card.value)
	Choice.finish(gs)
	return true

static func ai_choice(gs, owner: int):
	var ids: Array = gs.pending_choice.get("instanceIds", [])
	if ids.is_empty() or choice_card(gs, owner, str(ids[0])) == null: return null
	var id := str(ids[0])
	for candidate in ids:
		if candidate in POWERS: id = str(candidate); break
	return resolve_choice(gs, owner, id)
