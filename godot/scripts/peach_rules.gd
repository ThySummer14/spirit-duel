class_name PeachRules
extends RefCounted
## Healing has an explicit source. A different healer must not activate Peach.

static func prepare_hand_card(card: Dictionary, source: Dictionary) -> Dictionary:
	if not card.get("aliveSourceInstant", false): return card
	var result := card.duplicate(true)
	result.keywords = result.get("keywords", []).filter(func(k): return str(k).to_lower() != "instant")
	if int(source.hp) > 0: result.keywords.append("INSTANT")
	return result

static func knocked_out(unit: Dictionary) -> void:
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("peachTemporaryAttack", 0))
	unit.peachTemporaryAttack = 0
	unit.swift = false

static func _grow_after_restore(gs, owner: int, src: int, target: Dictionary) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	if int(source.hp) <= 0 or not ContentLoader.unit_def(str(source.id)).has("peachRestoration"): return
	if int(source.level) < 1 or gs._unit_index_by_uid(owner, target.uid) < 0: return
	var awakened := bool(source.awakened)
	var attack := 2 if awakened else 1
	var health := 2 if awakened else 0
	gs._grow_unit(target, attack, health)
	if not awakened: target.peachTemporaryAttack = int(target.get("peachTemporaryAttack", 0)) + attack
	gs._log("%s 获得%s+%d力量/+%d生命。" % [target.name, "永久" if awakened else "", attack, health], gs.TONE_SUCCESS)
	gs.VerifiedRules.event(gs, "peach-growth", {"player": owner, "uid": source.uid, "target": target.uid, "attack": attack, "hp": health, "permanent": awakened})

static func heal(gs, owner: int, src: int, target_owner: int, target: Dictionary, amount: int) -> int:
	if amount <= 0 or int(target.get("hp", 0)) <= 0: return 0
	var before := int(target.hp)
	gs._heal_unit(target, amount)
	var restored := int(target.hp) - before
	gs.VerifiedRules.event(gs, "peach-heal", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": target.uid, "victimPlayer": target_owner, "amount": restored})
	# Zero actual recovery is retained as a pending client boundary in content.
	if restored > 0 and target_owner == owner: _grow_after_restore(gs, owner, src, target)
	return restored

static func revive(gs, owner: int, src: int, target: Dictionary, swift: bool = false, grow: bool = true) -> bool:
	if target.is_empty() or int(target.hp) > 0: return false
	target.knockout = 0
	target.hp = int(target.maxHp)
	target.shield = 0
	target.shieldExpires = 0
	target.front = 0
	gs._log("%s 复活，恢复全部生命。" % target.name, gs.TONE_SUCCESS)
	gs.VerifiedRules.event(gs, "peach-revive", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": target.uid})
	if grow: _grow_after_restore(gs, owner, src, target)
	if swift:
		target.swift = true
		gs._log("%s 获得迅捷：下次出击不消耗鬼火。" % target.name, gs.TONE_SUCCESS)
		gs.VerifiedRules.event(gs, "swift-gained", {"player": owner, "uid": target.uid})
	return true

static func random_heal(gs, owner: int, src: int, amount: int, repeats: int) -> void:
	for i in repeats:
		if gs.winner >= 0 or int(gs.player(owner).units[src].hp) <= 0: return
		var injured: Array = gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and int(u.hp) < int(u.maxHp))
		if injured.is_empty(): return
		var chosen: Dictionary = injured[int(floor(gs.randf01() * injured.size()))]
		heal(gs, owner, src, owner, chosen, amount)
		# Each recovery and its growth complete before the next injured pool.

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var cfg: Dictionary = card.get("formRules", {}).get("peachRandomHeal", {})
	if cfg.is_empty(): return
	gs.VerifiedRules.event(gs, "peach-form-heal", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": card, "reason": "进场"})
	random_heal(gs, owner, src, int(cfg.amount), int(cfg.repeats))

static func turn_started(gs, owner: int, src: int) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	if int(source.hp) <= 0 or int(source.level) < 1: return
	var cfg: Dictionary = source.get("formRules", {}).get("peachRandomHeal", {})
	if cfg.is_empty(): return
	gs.VerifiedRules.event(gs, "peach-form-heal", {"player": owner, "uid": source.uid, "reason": "回合开始"})
	random_heal(gs, owner, src, int(cfg.amount), int(cfg.repeats))

static func search_deck(gs, owner: int, target: Dictionary) -> void:
	if target.is_empty(): return
	var player: Dictionary = gs.player(owner)
	var matches: Array = []
	for i in player.deck.size():
		if ContentLoader.card_def(str(player.deck[i].definitionId)).get("unitId") == target.id: matches.append(i)
	if matches.is_empty():
		gs._log("牌库中没有%s的牌。" % target.name, gs.TONE_NEUTRAL)
		return
	var idx := int(matches[int(floor(gs.randf01() * matches.size()))])
	var drawn: Dictionary = player.deck.pop_at(idx)
	player.hand.append(drawn)
	gs._log("花信风抽到%s的「%s」。" % [target.name, ContentLoader.card_def(str(drawn.definitionId)).name], gs.TONE_SUCCESS)
	gs.VerifiedRules.event(gs, "peach-search", {"player": owner, "target": target.uid, "cardId": drawn.definitionId})
	while player.hand.size() > int(gs.rules.get("maxHandSize", 12)):
		var burned: Dictionary = player.hand.pop_back()
		gs._log("手牌已满，「%s」被烧毁。" % ContentLoader.card_def(str(burned.definitionId)).name, gs.TONE_DANGER)

static func resolve_action(gs, owner: int, src: int, _card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	match str(effect.get("action", "")):
		"peach-heal":
			var target_owner := -1
			for p in 2:
				if str(target_id) == "avatar-%d" % p: target_owner = p
			if target_owner >= 0:
				var before := int(gs.player(target_owner).avatarHp)
				gs._heal_avatar(target_owner, int(effect.value))
				gs.VerifiedRules.event(gs, "peach-heal", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": str(target_id), "victimPlayer": target_owner, "amount": int(gs.player(target_owner).avatarHp) - before})
			elif not target.is_empty():
				target_owner = owner if gs._unit_index_by_uid(owner, target.uid) >= 0 else 1 - owner
				heal(gs, owner, src, target_owner, target, int(effect.value))
		"peach-search": search_deck(gs, owner, target)
		"peach-encourage": gs._apply_encourage(owner, int(effect.value.attack), int(effect.value.shield))
		"peach-revive": revive(gs, owner, src, target, true)
		"peach-revive-all":
			var dead: Array = gs.player(owner).units.filter(func(u): return int(u.hp) <= 0)
			# The resurrection group is simultaneous: all return before its
			# restoration triggers. No dependence on lineup position.
			for unit in dead: revive(gs, owner, src, unit, false, false)
			for unit in dead: _grow_after_restore(gs, owner, src, unit)
		"peach-awaken":
			var source: Dictionary = gs.player(owner).units[src]
			source.awakened = true
			source.passive_hooks = []
			gs._grow_unit(source, int(effect.value.attack), int(effect.value.hp))
			gs.VerifiedRules.event(gs, "peach-awaken", {"player": owner, "uid": source.uid})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var effects: Array = card.get("effects", [])
	if effects.is_empty(): return null
	var action := str(effects[0].get("action", ""))
	var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
	match action:
		"peach-heal":
			if str(target_id) == "avatar-%d" % owner:
				var missing := int(gs.player(owner).maxAvatarHp) - int(gs.player(owner).avatarHp)
				return 45 + mini(missing, 5) * 4 if missing > 0 else -100
			if target.is_empty(): return -100
			var missing := int(target.maxHp) - int(target.hp)
			return 45 + mini(missing, 5) * 4 + (8 if target.front else 0) if missing > 0 else -100
		"peach-search":
			if target.is_empty(): return -100
			for instance in gs.player(owner).deck:
				if ContentLoader.card_def(str(instance.definitionId)).get("unitId") == target.id: return 38 + int(target.attack)
			return -100
		"peach-revive": return 65 + int(target.attack) * 2 if not target.is_empty() and int(target.hp) <= 0 else -100
		"peach-revive-all":
			var dead: int = gs.player(owner).units.filter(func(u): return int(u.hp) <= 0).size()
			return 60 + dead * 20 if dead > 0 else -100
		"peach-awaken": return 55
	return null
