class_name YijinRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")

static func used_this_turn(gs, owner: int) -> bool:
	return int(gs.player(owner).get("featherUsedTurn", -1)) == gs.turn_counter

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.has("featherRule"): return card
	var out := card.duplicate(true)
	var src: int = gs._source_index(owner, card)
	match str(card.featherRule):
		"feather":
			if src >= 0 and gs.player(owner).units[src].awakened: out.target = "enemy-character"
		"free-combat":
			if used_this_turn(gs, owner): out.cost = 0
		"dance":
			var n := int(gs.player(owner).get("feathersPlayed", 0))
			out.value = n
			out.effects[0].value = n
			out.combatOption.shield = n
			out.text += "\n本局黄金羽已用%d张：+%d力量/+%d护甲。" % [n, n, n]
	return out

static func immune(gs, owner: int, unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and unit.get("formRules", {}).get("featherImmunity", false) and used_this_turn(gs, owner)

static func announced(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("featherRule") != "feather": return
	var p: Dictionary = gs.player(owner)
	p.feathersPlayed = int(p.get("feathersPlayed", 0)) + 1
	p.featherUsedTurn = gs.turn_counter
	var unit: Dictionary = p.units[src]
	if int(unit.hp) > 0 and unit.get("formRules", {}).get("featherRandomHits", false):
		# Two independent random selections, each after the preceding hit and
		# its death/response effects. The same surviving enemy may be hit twice.
		for i in 2: gs.resolution_stack.append({"kind": "feather-random-hit", "playerIndex": owner, "sourceIndex": src, "card": ContentLoader.card_def(str(unit.form.cardId))})
	gs.VerifiedRules.event(gs, "feather-used", {"player": owner, "uid": unit.uid, "count": p.feathersPlayed, "card": card})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "feather-random-hit": return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var enemy := 1 - owner
	var pool: Array = []
	for i in gs.player(enemy).units.size():
		if int(gs.player(enemy).units[i].hp) > 0: pool.append(i)
	if pool.is_empty() or gs.winner >= 0: return true
	var idx := int(pool[int(floor(gs.randf01() * pool.size()))])
	var hit: Dictionary = gs._damage_unit(enemy, idx, 2, owner, src)
	gs.VerifiedRules.event(gs, "feather-random-hit", {"player": owner, "uid": gs.player(owner).units[src].uid, "victimPlayer": enemy, "target": gs.player(enemy).units[idx].uid, "amount": int(hit.damage), "blocked": int(hit.damage) == 0, "card": frame.card})
	return true

static func will_die(gs, owner: int, idx: int) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if int(unit.hp) <= 0 or unit.get("featherDeathResponse", false): return
	unit.featherDeathResponse = true
	var outer_stack: Array = gs.resolution_stack
	var outer_context: Dictionary = gs._card_effect_context
	gs.resolution_stack = []
	if gs.VerifiedRules.automatic_response(gs, owner, "source-lethal", unit.uid, {"kind": "response-complete"}, gs.MAX_RESPONSE_DEPTH):
		while not gs.resolution_stack.is_empty() and gs.winner < 0: gs._resolve_frame(gs.resolution_stack.pop_back())
	gs.resolution_stack = outer_stack
	gs._card_effect_context = outer_context
	unit.erase("featherDeathResponse")

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	match str(effect.get("action", "")):
		"feather-generate":
			for i in int(effect.value):
				if p.hand.size() >= int(gs.rules.get("maxHandSize", 12)): continue
				p.hand.append({"instanceId": "%s-feather-%d" % [p.id, gs.next_card_id], "definitionId": "huangjinyu"})
				gs.next_card_id += 1
				gs.VerifiedRules.event(gs, "feather-created", {"player": owner, "card": ContentLoader.card_def("huangjinyu")})
		"feather-hit":
			var enemy := 1 - owner
			if target_id == null or str(target_id) == "avatar-%d" % enemy: gs._damage_avatar(enemy, int(effect.value), owner, src)
			else:
				var idx: int = gs._unit_index_by_uid(enemy, target_id)
				if idx >= 0: gs._damage_unit(enemy, idx, int(effect.value), owner, src)
		"feather-awaken":
			var unit: Dictionary = p.units[src]
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, 1, 1)
			unit.abilityCountdown.reset = 1
			unit.abilityCountdown.remaining = mini(1, int(unit.abilityCountdown.remaining))
		"feather-replace-hand":
			var count := 0
			for i in range(p.hand.size() - 1, -1, -1):
				if ContentLoader.card_def(str(p.hand[i].definitionId)).get("unitId") == card.unitId:
					gs.discard_hand_card(owner, i)
					count += 1
			gs.VerifiedRules.event(gs, "feather-hand-discarded", {"player": owner, "count": count})
			gs._draw(owner, count)
		"feather-transform":
			if not used_this_turn(gs, owner): return true
			var ids: Array = []
			for inst in p.hand:
				if ContentLoader.card_def(str(inst.definitionId)).get("featherRule") == "feather": ids.append(inst.instanceId)
			if ids.is_empty(): return true
			gs.pending_choice = {"type": "feather-transform", "zone": "hand", "playerIndex": owner, "instanceIds": ids, "title": "千羽风之舞 · 选择一张黄金羽变为金风流羽", "heading": "千 羽 风 之 舞", "hint": "选择一张黄金羽变为金风流羽"}
			gs.phase = "choice"
		_: return false
	return true

static func resolve_choice(gs, owner: int, instance_id: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "feather-transform" or int(choice.playerIndex) != owner or instance_id not in choice.instanceIds: return false
	for inst in gs.player(owner).hand:
		if str(inst.instanceId) != instance_id: continue
		if ContentLoader.card_def(str(inst.definitionId)).get("featherRule") != "feather": return false
		inst.definitionId = "c12303"
		gs._record("resolve_divination_choice", {"instanceId": instance_id, "card": "c12303", "choice": "feather-transform"}, owner)
		gs.pending_choice = {}
		gs.phase = "main"
		gs._resolve_resolution_stack()
		gs.state_changed.emit()
		return true
	return false

static func score_card(gs, owner: int, card: Dictionary) -> Variant:
	if not card.has("featherRule"): return null
	var unit: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
	match str(card.featherRule):
		"feather": return 76
		"awaken": return -100 if unit.awakened else 85
		"feathers": return 65 if gs.player(owner).hand.size() <= 9 else 5
		"replace":
			var n: int = gs.player(owner).hand.filter(func(i): return ContentLoader.card_def(str(i.definitionId)).get("unitId") == card.unitId).size() - 1
			return 35 + n * 5 if n >= 2 else -100
		"immunity", "wander": return -100 if unit.get("form", {}).get("cardId") == card.id else 58
		_: return 48 + int(card.value) + (20 if gs.effective_card_cost(owner, card) == 0 else 0)
