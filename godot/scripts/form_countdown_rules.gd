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

static func remove(gs, owner: int, src: int, reason: String, returning_to_deck: bool = false) -> void:
	var poison_hp:=int(gs.player(owner).units[src].hp) if gs.player(owner).units[src].get("toxicPoisoned",false) else -1
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.get("form", {}).is_empty(): return
	if not returning_to_deck:gs.VerifiedRules.Garuda.form_removed(gs,owner,src)
	gs.VerifiedRules.Puppet.form_removed(gs,owner,src,returning_to_deck)
	if not returning_to_deck:gs.VerifiedRules.OniAsura.form_removed(gs,owner,src)
	gs.VerifiedRules.PipeFox.form_removed(unit)
	var old: Dictionary = unit.get("formCountdown", {})
	var light_rules: Dictionary = unit.get("formRules", {}).duplicate(true)
	var name := str(unit.form.get("name", "形态"))
	unit.form = {}
	unit.formRules = {}
	unit.formHooks = []
	unit.formAbility = ""
	gs.VerifiedRules.OwlInsect.refresh(gs)
	gs.VerifiedRules.Poison.refresh_all(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.Light.form_removed(gs, owner, src, light_rules)
	unit.erase("formCountdown")
	unit.erase("formExpiresTurn")
	gs._recalc(unit)
	# Removing a form restores the living shikigami's underlying full health.
	# Death never revives the source, but its departing ability still resolves.
	if poison_hp>0: unit.hp=poison_hp
	elif int(unit.hp) > 0: unit.hp = int(unit.maxHp)
	gs._log("%s 的「%s」%s，移除形态。" % [unit.name, name, reason], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "form-removed", {"player": owner, "uid": unit.uid, "name": name, "reason": reason})
	if not returning_to_deck and not old.is_empty() and ContentLoader.unit_def(unit.id).get("formLifecycle", {}).get("destroyed", false):
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
				if idx < 0: gs._damage_avatar(enemy, int(effect.value), owner, src)
				else: gs._damage_unit(enemy, idx, int(effect.value), owner, src)
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
			var gained: int = gs._grant_avatar_armor(owner, int(effect.value))
			gs._log("%s 的牌手获得%d护甲。" % [unit.name, gained], gs.TONE_SUCCESS)
		"destroy-enemy-front":
			var enemy := 1 - owner
			var idx: int = gs.front_index(enemy)
			if idx >= 0:
				gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, idx, _card)
		_: return false
	return true
