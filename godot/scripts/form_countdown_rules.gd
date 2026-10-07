class_name FormCountdownRules
extends RefCounted
## Form abilities are attached effects, not spells or additional hand plays.
## Keep the departing timer alive in a frame after the form itself is gone.

static func attach(gs, owner: int, src: int, card: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	unit.erase("formCountdown")
	unit.erase("formExpiresTurn")
	var cfg: Dictionary = card.get("formRules", {})
	if cfg.has("countdown"):
		unit.formCountdown = {"form": true, "remaining": int(cfg.countdown), "reset": int(cfg.countdown), "triggers": 0, "card": card.duplicate(true)}
		if unit.awakened and ContentLoader.unit_def(unit.id).get("formLifecycle", {}).get("awakenedEntry", false):
			queue_trigger(gs, owner, src, unit.formCountdown, "进场")
	if cfg.get("destroyAtTurnEnd", false): unit.formExpiresTurn = gs.turn_counter

static func remove(gs, owner: int, src: int, reason: String) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.get("form", {}).is_empty(): return
	var old: Dictionary = unit.get("formCountdown", {})
	var name := str(unit.form.get("name", "形态"))
	unit.form = {}
	unit.formRules = {}
	unit.formHooks = []
	unit.formAbility = ""
	unit.erase("formCountdown")
	unit.erase("formExpiresTurn")
	gs._recalc(unit)
	# Removing a form restores the living shikigami's underlying full health.
	# Death never revives the source, but its departing ability still resolves.
	if int(unit.hp) > 0: unit.hp = int(unit.maxHp)
	gs._log("%s 的「%s」%s，移除形态。" % [unit.name, name, reason], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "form-removed", {"player": owner, "uid": unit.uid, "name": name, "reason": reason})
	if not old.is_empty() and ContentLoader.unit_def(unit.id).get("formLifecycle", {}).get("destroyed", false):
		queue_trigger(gs, owner, src, old, reason)

static func queue_trigger(gs, owner: int, src: int, timer: Dictionary, reason: String) -> void:
	timer.triggers = int(timer.get("triggers", 0)) + 1
	gs.resolution_stack.append({"kind": "form-trigger", "playerIndex": owner, "sourceIndex": src, "card": timer.card.duplicate(true), "count": int(timer.triggers), "reason": reason})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") == "form-install":
		var unit: Dictionary = gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
		if int(unit.hp) > 0: gs._install_form(int(frame.playerIndex), int(frame.sourceIndex), frame.card, frame.value)
		return true
	if frame.get("kind") != "form-trigger": return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var card: Dictionary = frame.card
	var unit: Dictionary = gs.player(owner).units[src]
	gs._log("「%s」%s，触发倒计时能力。" % [card.name, frame.reason], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "form-trigger", {"player": owner, "uid": unit.uid, "card": card, "reason": frame.reason, "count": frame.count})
	for effect in card.formRules.get("countdownEffects", []):
		if effect.action == "expanding-random-damage":
			var enemy: int = 1 - owner
			var pool: Array = [-1]
			for i in gs.player(enemy).units.size():
				if int(gs.player(enemy).units[i].hp) > 0: pool.append(i)
			var targets: Array = []
			for i in mini(int(frame.count), pool.size()):
				var pos := int(floor(gs.randf01() * pool.size()))
				targets.append(pool.pop_at(pos))
			# Choose distinct targets before the damage group; death triggers wait
			# on the stack until every selected target has received this effect.
			for idx in targets:
				if gs.winner >= 0: break
				if idx < 0: gs._damage_avatar(enemy, int(effect.value), owner)
				else: gs._damage_unit(enemy, idx, int(effect.value), owner)
				gs.VerifiedRules.event(gs, "random-hit", {"player": owner, "uid": unit.uid, "card": card, "target": "" if idx < 0 else gs.player(enemy).units[idx].uid, "victimPlayer": enemy})
		else:
			gs._resolve_one_effect(owner, src, card, effect, null, {})
	return true

static func end_turn(gs) -> void:
	for owner in 2:
		for i in gs.player(owner).units.size():
			var unit: Dictionary = gs.player(owner).units[i]
			if int(unit.get("formExpiresTurn", -1)) == gs.turn_counter:
				remove(gs, owner, i, "自毁")
				gs._resolve_resolution_stack()

static func resolve_action(gs, owner: int, src: int, _card: Dictionary, effect: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"destroy-own-form": remove(gs, owner, src, "被%s消灭" % _card.name)
		"awaken-form-lifecycle":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"avatar-armor":
			gs.player(owner).avatarArmor = int(gs.player(owner).get("avatarArmor", 0)) + int(effect.value)
			gs._log("%s 的牌手获得%d护甲。" % [unit.name, int(effect.value)], gs.TONE_SUCCESS)
		"destroy-enemy-front":
			var enemy := 1 - owner
			var idx: int = gs.front_index(enemy)
			if idx >= 0:
				var target: Dictionary = gs.player(enemy).units[idx]
				gs._knockout_unit(target)
				gs.VerifiedRules.event(gs, "unit-destroyed", {"player": owner, "uid": unit.uid, "target": target.uid, "card": _card})
		_: return false
	return true
