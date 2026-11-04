class_name SpellReplayRules
extends RefCounted
## Per-cast identity, affected targets and hand-only enhancement survive replay.

static func prepare_hand_card(card: Dictionary, unit: Dictionary) -> Dictionary:
	if not card.has("spellEnhancement"): return card
	var view := card.duplicate(true)
	var cfg: Dictionary = card.spellEnhancement
	var count := int(unit.get("spellsUsed", 0))
	view.enhanced = count >= int(cfg.threshold)
	if view.enhanced:
		view.effect = cfg.action
		view.value = null
		view.effects = [{"condition": "always", "action": cfg.action, "target": "auto", "value": null}]
		view.text = cfg.text
	else:
		view.text = str(card.text) + "\n已使用法术 %d/%d" % [count, int(cfg.threshold)]
	return view

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	if not ContentLoader.is_spell(card): return
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[src]
	var cfg: Dictionary = ContentLoader.runtime_unit_def(unit).get("spellCountdown", {})
	if cfg.get("on") == "spell":
		unit.spellsUsed = int(unit.get("spellsUsed", 0)) + 1
		if int(unit.hp) > 0 and not card.get("excludeSpellReplay", false):
			var count := int(cfg.awakenedTurns if unit.awakened else cfg.turns)
			unit.spellCountdown = {"remaining": count, "reset": count, "card": card.duplicate(true), "persistKnockout": bool(cfg.get("persistKnockout", false))}
			gs.VerifiedRules.event(gs, "countdown-set", {"uid": unit.uid, "remaining": count, "player": owner})
	if int(unit.hp) <= 0: return
	var extra := int(unit.get("formRules", {}).get("afterSpellAffectedDamage", 0))
	if extra <= 0: return
	for uid in frame.get("affectedUnits", []):
		var idx: int = gs._unit_index_by_uid(1 - owner, uid)
		if idx >= 0 and int(gs.player(1 - owner).units[idx].hp) > 0:
			gs._damage_unit(1 - owner, idx, extra, owner)
			gs.VerifiedRules.event(gs, "form-followup", {"uid": unit.uid, "target": uid, "amount": extra, "player": owner})

static func random_target(gs, owner: int, card: Dictionary):
	if card.get("target", "auto") == "auto": return null
	var targets: Array = gs.valid_targets(owner, card)
	return null if targets.is_empty() else targets[int(floor(gs.randf01() * targets.size()))]

static func generation_pool(unit: Dictionary, card: Dictionary) -> Array:
	return ContentLoader.cards_for_unit(str(unit.id)).filter(func(c): return ContentLoader.is_spell(c) and int(c.level) <= int(unit.level) and c.id != card.id and not c.get("skin", false) and not c.get("token", false))

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"awaken-spell-replay":
			# Set the new reset period before reducing the old, retained spell.
			unit.awakened = true
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
			if unit.has("spellCountdown"):
				unit.spellCountdown.reset = int(ContentLoader.runtime_unit_def(unit).spellCountdown.awakenedTurns)
			gs.VerifiedRules.reduce_countdown(gs, owner, src, int(effect.value.countdown), owner)
		"generate-own-spell":
			var pool := generation_pool(unit, card)
			if pool.is_empty(): return true
			var selected: Dictionary = pool[int(floor(gs.randf01() * pool.size()))]
			var p: Dictionary = gs.player(owner)
			if p.hand.size() >= int(gs.rules.get("maxHandSize", 12)):
				gs._log("手牌已满，获得的「%s」被烧毁。" % selected.name, gs.TONE_DANGER)
				return true
			p.hand.append({"instanceId": "%s-c%d" % [p.id, gs.next_card_id], "definitionId": selected.id})
			gs.next_card_id += 1
			gs._log("%s 获得「%s」。" % [p.name, selected.name], gs.TONE_CARD)
			gs.VerifiedRules.event(gs, "card-generated", {"player": owner, "uid": unit.uid, "card": selected})
		"destroy-enemy-units":
			for idx in gs.player(1 - owner).units.size():
				var victim: Dictionary = gs.player(1 - owner).units[idx]
				if int(victim.hp) > 0:
					gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1-owner, idx, card)
		"shield-next-turn":
			if target.is_empty() or int(target.hp) <= 0: return true
			var amount := int(effect.value)
			var gained: int = gs._grant_unit_armor(target, amount)
			if not target.has("pendingShields"): target.pendingShields = []
			target.pendingShields.append({"turn": gs.turn_counter + 1, "amount": amount})
			gs.VerifiedRules.event(gs, "shield-granted", {"player": owner, "uid": unit.uid, "target": target.uid, "amount": gained})
		_: return false
	return true

static func begin_turn(gs) -> void:
	# 'Next turn' includes the opponent's turn. Bind to the original unit;
	# knockout removes these effects, so a later revival cannot inherit them.
	for owner in 2:
		for unit in gs.player(owner).units:
			for pending in unit.get("pendingShields", []).duplicate():
				if int(pending.turn) > gs.turn_counter: continue
				unit.pendingShields.erase(pending)
				if int(unit.hp) <= 0: continue
				var gained: int = gs._grant_unit_armor(unit, int(pending.amount))
				gs._log("%s 获得上回合暴风之盾的%d护甲。" % [unit.name, gained], gs.TONE_SUCCESS)
				gs.VerifiedRules.event(gs, "delayed-shield", {"player": owner, "uid": unit.uid, "amount": gained})
