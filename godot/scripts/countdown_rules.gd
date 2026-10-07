class_name CountdownRules
extends RefCounted
## Ability countdowns are not card casts. Each effect uses the same resolution
## stack, so a triggered teammate finishes before the next written instruction.

static func initialize(unit: Dictionary, definition: Dictionary) -> void:
	var cfg: Dictionary = definition.get("countdownAbility", {})
	if cfg.is_empty(): return
	unit.abilityCountdown = {"remaining": int(cfg.turns), "reset": int(cfg.turns), "mode": cfg.initial}
	unit.abilityHistory = []

static func timer(unit: Dictionary) -> Dictionary:
	return unit.get("formCountdown", unit.get("abilityCountdown", unit.get("spellCountdown", {})))

static func mode(unit: Dictionary, key: String = "") -> Dictionary:
	var cfg: Dictionary = ContentLoader.unit_def(str(unit.id)).get("countdownAbility", {})
	var value: Dictionary = cfg.get("modes", {}).get(key if key != "" else str(unit.get("abilityCountdown", {}).get("mode", "")), {})
	if cfg.get("poisonHistory", false) and not value.is_empty():
		value = value.duplicate(true)
		var history := int(unit.get("poisonTriggers", 0))
		var next := int(value.effects[0].value) + (history if value.effects[0].get("growsWithHistory", false) else 0)
		value.text += "\n下次产生%d破甲 · 已触发%d次" % [next, history]
	return value

static func presentation(unit: Dictionary) -> Dictionary:
	var value := mode(unit).duplicate(true)
	value.merge({"id": "ability-" + str(unit.id), "unitId": unit.id, "type": "ability", "typeLabel": "基础能力", "level": unit.level, "cost": 0, "verifiedRules": true}, true)
	return value

static func queue_ability(gs, p_idx: int, src: int, key: String, remember: bool = true) -> void:
	var unit: Dictionary = gs.player(p_idx).units[src]
	var ability := mode(unit, key)
	if ability.is_empty(): return
	var card := presentation(unit)
	card.merge(ability, true)
	var base := {"playerIndex": p_idx, "sourceIndex": src, "cardOverride": card, "mode": key, "remember": remember}
	for i in range(ability.effects.size() - 1, -1, -1):
		var frame := base.duplicate(true)
		frame.merge({"kind": "ability-effect", "effectIndex": i})
		gs.resolution_stack.append(frame)
	var start := base.duplicate(true)
	start.kind = "ability-start"
	gs.resolution_stack.append(start)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") == "countdown-grow":
		var ally: Dictionary = gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
		if frame.eligible and int(ally.hp) > 0: gs._grow_unit(ally, int(frame.attack), int(frame.hp))
		return true
	if not str(frame.get("kind", "")).begins_with("ability-"): return false
	var p_idx := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(p_idx).units[src]
	var card: Dictionary = frame.cardOverride
	if frame.kind == "ability-start":
		if frame.remember and not unit.abilityHistory.has(frame.mode): unit.abilityHistory.append(frame.mode)
		gs._log("%s 的%s生效。" % [unit.name, card.name], gs.TONE_CARD)
		gs.VerifiedRules.event(gs, "ability-trigger", {"player": p_idx, "uid": unit.uid, "card": card, "mode": frame.mode, "remember": frame.remember})
	else:
		gs._resolve_one_effect(p_idx, src, card, card.effects[int(frame.effectIndex)], null, {})
	return true

static func change(gs, p_idx: int, src: int, delta: int) -> void:
	var unit: Dictionary = gs.player(p_idx).units[src]
	if delta < 0:
		gs.VerifiedRules.reduce_countdown(gs, p_idx, src, -delta)
	elif delta > 0:
		if int(unit.hp) <= 0 and int(unit.knockout) > 0: unit.knockout = int(unit.knockout) + delta
		elif not timer(unit).is_empty(): timer(unit).remaining = int(timer(unit).remaining) + delta
		else: return
		gs._log("%s 的倒计时增加%d。" % [unit.name, delta], gs.TONE_CARD)
		gs.VerifiedRules.event(gs, "countdown-increased", {"uid": unit.uid, "amount": delta, "player": p_idx})

static func card_completed(gs, p_idx: int, src: int, card: Dictionary) -> void:
	var unit: Dictionary = gs.player(p_idx).units[src]
	if int(unit.hp) > 0 and card.get("awakening", false):
		var amount := int(mode(unit).get("onAwakeningPlayed", 0))
		if amount > 0: gs.VerifiedRules.reduce_countdown(gs, p_idx, src, amount)

static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var unit: Dictionary = gs.player(p_idx).units[src]
	match str(effect.get("action", "")):
		"heal-characters":
			gs._heal_avatar(p_idx, int(effect.value))
			for ally in gs.player(p_idx).units: gs._heal_unit(ally, int(effect.value))
		"countdown-change":
			var et := str(effect.target)
			if et == "source": change(gs, p_idx, src, int(effect.value))
			elif et == "living-other-allies":
				# Push individual changes to preserve formation order, including chains.
				for i in range(gs.player(p_idx).units.size() - 1, -1, -1):
					if i != src and int(gs.player(p_idx).units[i].hp) > 0:
						gs.resolution_stack.append({"kind": "countdown-change", "playerIndex": p_idx, "sourceIndex": i, "delta": int(effect.value)})
			elif not target.is_empty():
				for owner in 2:
					var idx: int = gs._unit_index_by_uid(owner, target.uid)
					if idx >= 0: change(gs, owner, idx, int(effect.value))
		"awaken-countdown":
			if int(unit.hp) <= 0: return true
			unit.awakened = true
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
			unit.abilityCountdown.mode = str(effect.value.mode)
			unit.passive_hooks = []
			gs._log("%s 觉醒为%s。" % [unit.name, mode(unit).name], gs.TONE_SUCCESS)
			gs.VerifiedRules.event(gs, "ability-changed", {"player": p_idx, "uid": unit.uid, "mode": effect.value.mode})
		"countdown-team-growth":
			for i in range(gs.player(p_idx).units.size() - 1, -1, -1):
				if i == src: continue
				var ally: Dictionary = gs.player(p_idx).units[i]
				# Death countdown can revive, but that unit does not gain the living
				# stat bonus from this same effect. Snapshot eligibility before reduction.
				gs.resolution_stack.append({"kind": "countdown-grow", "playerIndex": p_idx, "sourceIndex": i, "eligible": int(ally.hp) > 0, "attack": int(effect.value.attack), "hp": int(effect.value.hp)})
				gs.resolution_stack.append({"kind": "countdown-change", "playerIndex": p_idx, "sourceIndex": i, "delta": -int(effect.value.countdown)})
		"repeat-countdown-history":
			var history: Array = unit.get("abilityHistory", []).duplicate()
			for i in range(history.size() - 1, -1, -1): queue_ability(gs, p_idx, src, str(history[i]), false)
		_: return false
	return true

static func describe_card(card: Dictionary, unit: Dictionary) -> Dictionary:
	if card.has("spellEnhancement"): return preload("res://scripts/spell_replay_rules.gd").prepare_hand_card(card, unit)
	if card.get("dynamicPoisonHistory", false):
		var view := card.duplicate(true)
		view.text += "\n基础能力已触发%d次。" % int(unit.get("poisonTriggers", 0))
		return view
	if not card.get("dynamicCountdownHistory", false): return card
	var view := card.duplicate(true)
	var lines: Array[String] = []
	for key in unit.get("abilityHistory", []):
		var ability := mode(unit, str(key))
		# The awakening-play listener is not part of the countdown's effect.
		lines.append(str(ability.text).split("当你使用")[0])
	view.text = "瞬发。" + ("尚无已生效的基础能力。" if lines.is_empty() else "\n".join(lines))
	return view
