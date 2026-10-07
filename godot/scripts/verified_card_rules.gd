class_name VerifiedCardRules
extends RefCounted
const Countdown := preload("res://scripts/countdown_rules.gd")
const Forms := preload("res://scripts/form_countdown_rules.gd")
const SpellReplay := preload("res://scripts/spell_replay_rules.gd")
const ArmorBreak := preload("res://scripts/armor_break_rules.gd")
const Phoenix := preload("res://scripts/phoenix_rules.gd")
const Peach := preload("res://scripts/peach_rules.gd")
const Firefly := preload("res://scripts/firefly_rules.gd")
## Data-driven native rules verified against the reference recording/card sources.
## No card or character IDs in the executor; all capabilities live in content.

static func event(gs, kind: String, details: Dictionary) -> void:
	var entry := details.duplicate(true)
	entry.kind = kind
	entry.id = gs.next_rule_event_id
	entry.commandIndex = gs.command_log.size()
	gs.next_rule_event_id += 1
	gs.rule_events.append(entry)
	if gs.rule_events.size() > 128: gs.rule_events.pop_front()

static func card_announced(gs, p_idx: int, src: int, card: Dictionary) -> void:
	Firefly.card_announced(gs, p_idx, src, card)
	var unit: Dictionary = gs.player(p_idx).units[src]
	var cfg: Dictionary = ContentLoader.unit_def(str(unit.id)).get("spellCountdown", {})
	# This 'when used' ability still attaches when the combat card is nullified.
	if card.get("type") == cfg.get("on", "") and card.get("originCard") is Dictionary:
		var count := int(cfg.get("awakenedTurns", 1) if unit.awakened else cfg.get("turns", 2))
		unit.spellCountdown = {"remaining": count, "reset": count, "card": card.originCard.duplicate(true), "persistKnockout": bool(cfg.get("persistKnockout", false))}
		gs._log("%s 倒计时%d：%s。" % [unit.name, count, card.originCard.name], gs.TONE_CARD)
		event(gs, "countdown-set", {"uid": unit.uid, "remaining": count, "player": p_idx})

static func card_started(gs, p_idx: int, src: int, card: Dictionary, automatic: bool) -> void:
	var unit: Dictionary = gs.player(p_idx).units[src]
	var form: Dictionary = unit.get("formRules", {}) if int(unit.hp) > 0 else {}
	if card.get("type") == "spell" and form.get("barrierOnSpell", false):
		unit.barrier = true
		gs._log("%s 获得屏障。" % unit.name, gs.TONE_SUCCESS)
		event(gs, "barrier-gained", {"uid": unit.uid, "player": p_idx})
	if card.get("type") == "combat" and int(form.get("countdownOnCombat", 0)) > 0:
		reduce_countdown(gs, p_idx, src, int(form.countdownOnCombat))
	if automatic: return
	# One use per realm, per actual turn (not per unit). Automated origin casts
	# are not hand plays and cannot spend this trigger or create an infinite loop.
	for realm in gs.player(p_idx).realms.duplicate():
		if int(realm.get("handCountdown", 0)) <= 0 or int(realm.get("usedTurn", -1)) == gs.turn_counter: continue
		realm.usedTurn = gs.turn_counter
		reduce_countdown(gs, p_idx, src, int(realm.handCountdown))

static func has_countdown(unit: Dictionary) -> bool:
	return int(unit.get("knockout", 0)) > 0 if int(unit.hp) <= 0 else not Countdown.timer(unit).is_empty()

static func reduce_countdown(gs, p_idx: int, src: int, amount: int) -> void:
	if amount <= 0 or gs.winner >= 0: return
	var unit: Dictionary = gs.player(p_idx).units[src]
	if int(unit.hp) <= 0:
		if int(unit.knockout) <= 0: return
		unit.knockout = maxi(0, int(unit.knockout) - amount)
		if int(unit.knockout) == 0:
			unit.hp = int(unit.maxHp)
			unit.shield = 0
			gs._log("%s 气绝倒计时结束，恢复全部生命。" % unit.name, gs.TONE_SUCCESS)
		return
	if int(unit.level) < 1: return
	var timer: Dictionary = Countdown.timer(unit)
	if timer.is_empty(): return
	timer.remaining = maxi(0, int(timer.remaining) - amount)
	gs._log("%s 的倒计时降至%d。" % [unit.name, int(timer.remaining)], gs.TONE_CARD)
	event(gs, "countdown-tick", {"uid": unit.uid, "remaining": int(timer.remaining), "player": p_idx})
	if int(timer.remaining) > 0: return
	# Overflow is discarded. Reset before queuing the cast; reductions that
	# occur later are separate effects and see the reset countdown.
	timer.remaining = int(timer.reset)
	if timer.get("form", false):
		Forms.queue_trigger(gs, p_idx, src, timer, "倒计时结束")
		return
	if timer.has("mode"):
		Countdown.queue_ability(gs, p_idx, src, str(timer.mode))
		return
	var card: Dictionary = timer.card
	var target = SpellReplay.random_target(gs, p_idx, card)
	if card.get("target", "auto") != "auto" and target == null: return
	gs._push_card_frames(p_idx, str(card.id), target, card, src, 0, true)

static func move_unit(gs, p_idx: int, unit: Dictionary) -> void:
	if unit.is_empty() or int(unit.hp) <= 0: return
	var entering := int(unit.front) == 0
	if entering:
		for other in gs.player(p_idx).units: other.front = 0
	unit.front = 1 if entering else 0
	gs._log("%s 移入%s。" % [unit.name, "战斗区" if entering else "准备区"], gs.TONE_CARD)
	event(gs, "unit-moved", {"uid": unit.uid, "front": int(unit.front), "player": p_idx})
	if entering:
		var idx: int = gs._unit_index_by_uid(p_idx, unit.uid)
		gs._fire_hooks(p_idx, idx, "unit-entered-front", {})
		gs._run_form_hooks(p_idx, idx, "unit-entered-front", {})
		automatic_response(gs, 1 - p_idx, "enemy-entered-front", unit.uid, {"kind": "response-complete"})

static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	if Phoenix.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Peach.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Firefly.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if ArmorBreak.resolve_action(gs, p_idx, src, effect, target): return true
	if Forms.resolve_action(gs, p_idx, src, card, effect): return true
	if Countdown.resolve_action(gs, p_idx, src, card, effect, target): return true
	if SpellReplay.resolve_action(gs, p_idx, src, card, effect, target): return true
	var amount := int(effect.get("value", 0)) if effect.get("value") is float or effect.get("value") is int else 0
	var enemy: int = gs.enemy_index(p_idx)
	match str(effect.get("action", "")):
		"nullify-next-card":
			gs.player(enemy).nullifyNextCardTurn = gs.turn_counter
			gs._log("本回合敌方下一张牌不会生效。", gs.TONE_CARD)
		"projectile-draw-on-kill":
			var idx: int = gs.front_index(enemy)
			if idx < 0: gs._damage_avatar(enemy, amount, p_idx)
			else:
				var hit: Dictionary = gs._damage_unit(enemy, idx, amount, p_idx)
				if hit.knocked: gs._draw(p_idx, 1)
		"move-unit":
			move_unit(gs, p_idx, target)
		"reduce-countdown-or-draw":
			if target.is_empty() or int(target.hp) <= 0: return true
			if has_countdown(target): reduce_countdown(gs, p_idx, gs._unit_index_by_uid(p_idx, target.uid), amount)
			else: gs._draw(p_idx, 1)
		"projectile-displace":
			var idx: int = gs.front_index(enemy)
			if idx < 0: gs._damage_avatar(enemy, amount, p_idx)
			else:
				var hit: Dictionary = gs._damage_unit(enemy, idx, amount, p_idx)
				var unit: Dictionary = gs.player(enemy).units[idx]
				# The original text requires actual damage, not an armor hit.
				if int(hit.damage) > 0 and int(unit.hp) > 0: move_unit(gs, enemy, unit)
		"random-damage":
			# Six individual points; re-evaluate survivors after every hit.
			for i in amount:
				if gs.winner >= 0: break
				var targets: Array = [-1]
				for idx in gs.player(enemy).units.size():
					if int(gs.player(enemy).units[idx].hp) > 0: targets.append(idx)
				var idx: int = targets[int(floor(gs.randf01() * targets.size()))]
				if idx < 0: gs._damage_avatar(enemy, 1, p_idx)
				else: gs._damage_unit(enemy, idx, 1, p_idx)
				event(gs, "random-hit", {"player": p_idx, "uid": gs.player(p_idx).units[src].uid, "card": card, "target": "" if idx < 0 else gs.player(enemy).units[idx].uid, "victimPlayer": enemy})
		_: return false
	return true

static func end_turn(gs, p_idx: int) -> void:
	Forms.end_turn(gs)
	Firefly.end_turn(gs, p_idx)
	for source in gs.player(p_idx).units:
		if int(source.hp) <= 0: continue
		var amount := int(source.get("formRules", {}).get("endTurnArmoredCountdown", 0))
		if amount <= 0: continue
		for idx in gs.player(p_idx).units.size():
			var unit: Dictionary = gs.player(p_idx).units[idx]
			if int(unit.hp) > 0 and int(unit.shield) > 0:
				reduce_countdown(gs, p_idx, idx, amount)
				gs._resolve_resolution_stack()

static func knocked_out(unit: Dictionary) -> void:
	unit.barrier = false
	unit.erase("pendingShields")
	if unit.has("abilityCountdown"): unit.abilityCountdown.remaining = int(unit.abilityCountdown.reset)
	if not unit.get("spellCountdown", {}).get("persistKnockout", false): unit.erase("spellCountdown")
	# Only corrected forms use this path; legacy rules retain their baseline.
	if not unit.get("formRules", {}).is_empty():
		unit.form = {}
		unit.formRules = {}
		unit.formHooks = []
		unit.formAbility = ""

static func cancel_pending_card(gs, frame: Dictionary) -> bool:
	# Countdown casts are ability-generated, not cards used by the opposing
	# player. They neither consume a seal nor solicit a hand response.
	if frame.get("automatic", false): return false
	var p_idx := int(frame.playerIndex)
	var p: Dictionary = gs.player(p_idx)
	if int(p.get("nullifyNextCardTurn", -1)) != gs.turn_counter: return false
	p.erase("nullifyNextCardTurn")
	var rid := int(frame.resolutionId)
	gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId", -1)) != rid)
	var card: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.definitionId)))
	gs._log("「%s」被魔音扰心阻止，整张牌不生效。" % card.name, gs.TONE_DANGER)
	event(gs, "card-nullified", {"player": p_idx, "uid": p.units[int(frame.sourceIndex)].uid, "card": card, "resolutionId": rid})
	return true

static func announce_card(gs, frame: Dictionary) -> void:
	var announced: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.definitionId)))
	Phoenix.card_announced(gs, frame, announced)
	card_announced(gs, int(frame.playerIndex), int(frame.sourceIndex), announced)
	if frame.get("automatic", false): return
	if cancel_pending_card(gs, frame): return
	var owner := 1 - int(frame.playerIndex)
	var check := frame.duplicate(true)
	check.kind = "card-counter-check"
	automatic_response(gs, owner, "opponent-card-used", null, check)

static func automatic_response(gs, owner: int, trigger: String, target_id, continuation: Dictionary) -> bool:
	# 响应在对手回合自动使用；主动打出仍能封住本回合对方的响应。
	if owner == gs.current_player: return false
	var p: Dictionary = gs.player(owner)
	for i in p.hand.size():
		var card: Dictionary = gs.hand_card_def(owner, i)
		var response := str(card.get("autoResponse", ""))
		if trigger == "unit-attacked":
			if response not in ["source-attacked", "front-attacked"]: continue
			var defender: Dictionary = gs._unit_by_uid(p.units, target_id)
			if defender.is_empty(): continue
			if response == "front-attacked" and int(defender.front) != 1: continue
		elif response != trigger: continue
		var src: int = gs._source_index(owner, card)
		if src < 0: continue
		var unit: Dictionary = p.units[src]
		if response == "source-attacked" and unit.uid != target_id: continue
		if int(unit.hp) <= 0 or int(unit.frozen) > 0 or int(unit.level) < int(card.level) or int(p.energy) < int(card.cost): continue
		p.energy = int(p.energy) - int(card.cost)
		p.hand.remove_at(i)
		p.cardsPlayedThisTurn = int(p.cardsPlayedThisTurn) + 1
		gs.resolution_stack.append(continuation)
		var combat_id := int(continuation.get("combatId", -1)) if card.get("responseModifiesCombat", false) else -1
		gs._push_card_frames(owner, str(card.id), null if card.get("target", "auto") == "auto" else target_id, card, src, 0, false, combat_id)
		gs._log("%s 响应，自动使用「%s」。" % [unit.name, card.name], gs.TONE_CARD)
		event(gs, "response-card", {"player": owner, "uid": unit.uid, "card": card, "target": target_id, "trigger": response})
		return true
	return false
