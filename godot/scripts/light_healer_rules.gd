class_name LightHealerRules
extends RefCounted
## Source-backed classic lantern, monk and fortune rules. Hooks are shared by all
## healing/fortune/combat entry points so abilities do not depend on card IDs.
const ContentLoader := preload("res://scripts/content_loader.gd")

static func role(unit: Dictionary) -> String:
	return str(ContentLoader.runtime_unit_def(unit).get("lightRole", ""))

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0

static func gain_fire(gs, owner: int, amount: int) -> void:
	gs._set_fire(owner,mini(4,int(gs.player(owner).energy)+amount))

static func add_lantern(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	if p.hand.size() >= int(gs.rules.get("maxHandSize", 12)): return
	p.hand.append({"instanceId": "%s-c%d" % [p.id, gs.next_card_id], "definitionId": "mingdeng"})
	gs.next_card_id += 1
	gs.VerifiedRules.event(gs, "lantern-created", {"player": owner})

static func retains_fire(gs, owner: int) -> bool:
	return gs.player(owner).units.any(func(u): return active(u) and role(u) == "lantern" and u.awakened)

static func refresh_fire(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	gs._set_fire(owner,mini(4,int(p.energy)+int(p.maxEnergy)) if retains_fire(gs,owner) else int(p.maxEnergy))

static func turn_start(gs, owner: int) -> void:
	var opponent: Dictionary = gs.player(1 - owner)
	for unit in opponent.units:
		if active(unit) and role(unit) == "lantern" and int(opponent.energy) > 0: add_lantern(gs, 1 - owner)

static func end_turn(gs, owner: int) -> void:
	for unit in gs.player(owner).units:
		if active(unit) and unit.get("formRules", {}).get("lanternEndFire", false): gain_fire(gs, owner, 1)

static func roll(gs, owner: int, threshold: int, sides: int = 6, source: int = -1, force_success: bool = false) -> bool:
	var forced: int = gs.VerifiedRules.Fortune.forced_die(gs, owner, source)
	var die_bonus: int = gs.VerifiedRules.River.die_bonus(gs, owner)
	var first := mini(sides, (forced if forced > 0 else int(floor(gs.randf01() * sides)) + 1) + die_bonus)
	gs.VerifiedRules.Fortune.record_die(gs, owner, first)
	var result := first
	var rerolled := false
	for unit in gs.player(owner).units:
		if not active(unit) or role(unit) != "fortune": continue
		if (unit.awakened and first < threshold) or (not unit.awakened and first == 1):
			result = mini(sides, int(floor(gs.randf01() * sides)) + 1 + die_bonus)
			gs.VerifiedRules.Fortune.record_die(gs, owner, result)
			rerolled = true
			break
	var success := force_success or result >= threshold
	var copies: int = gs.VerifiedRules.Fortune.repeat_count(gs, owner) if success else 0
	gs.kw_usage(owner, "fortune").last = {"roll": result, "firstRoll": first, "sides": sides, "threshold": threshold, "success": success, "rerolled": rerolled, "effectRepeats": copies}
	if success: gs.player(owner).fortuneSuccesses = int(gs.player(owner).get("fortuneSuccesses", 0)) + 1
	if success:
		for copy in copies: gs.VerifiedRules.Fortune.success(gs, owner)
		gs.VerifiedRules.FoxSuzuka.fortune_success(gs, owner)
		gs.VerifiedRules.River.success(gs, owner)
	gs.VerifiedRules.event(gs, "fortune-result", {"player": owner, "sourceIndex": source, "roll": result, "firstRoll": first, "threshold": threshold, "success": success, "rerolled": rerolled, "effectRepeats": copies})
	gs._log("%s 运势%d：%d%s，%s。" % [gs.player(owner).name, threshold, first, " → %d（重投）" % result if rerolled else "", "成功" if success else "失败"], gs.TONE_CARD)
	return success

static func fortune_total(gs) -> int:
	return int(gs.player(0).get("fortuneSuccesses", 0)) + int(gs.player(1).get("fortuneSuccesses", 0))

static func form_turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	var mode := str(unit.get("formRules", {}).get("fortuneTurnStart", ""))
	if not active(unit) or mode == "": return
	for recipient in [owner, 1 - owner]:
		if gs.winner >= 0: break
		if roll(gs, recipient, 4, 6, src if recipient == owner else -1):
			for copy in gs.VerifiedRules.Fortune.last_repeats(gs, recipient):
				if mode == "draw": gs._draw(recipient, 1)
				elif mode == "heal": heal(gs, owner, src, recipient, -1, 3)

static func before_attack(gs, owner: int, src: int) -> bool:
	if gs.player(owner).units[src].get("formRules", {}).get("lanternAttackFire", false): add_lantern(gs, owner)
	var zero := false
	for side in gs.players:
		for unit in side.units:
			if active(unit) and unit.get("formRules", {}).get("fortuneZeroAttack", false):
				if not roll(gs, owner, 4, 6, src): zero = true
	return zero

static func after_attack(gs, owner: int, src: int) -> void:
	var attacker: Dictionary = gs.player(owner).units[src]
	if not active(attacker): return
	for side in gs.players:
		for unit in side.units:
			if active(unit) and unit.get("formRules", {}).get("fortuneStunAfterAttack", false):
				if not roll(gs, owner, 4, 6, src): gs.VerifiedRules.Stun.apply(gs, owner, src)

static func combat_dealt(_gs, _owner: int, _src: int, _victim: int, _idx: int, _result: Dictionary) -> void:
	pass

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules", {}).has("fortuneTurnStart"): form_turn_start(gs, owner, src)
	if card.get("formRules", {}).get("fortuneEntryExitFire", false):
		gain_fire(gs, owner, 1)
		gain_fire(gs, 1 - owner, 1)
	# Enhancement attaches to copies currently held when a form is attached;
	# drawing a fresh copy later does not inherit an old form-entry event.
	if role(gs.player(owner).units[src]) == "fortune":
		for inst in gs.player(owner).hand:
			if ContentLoader.card_def(str(inst.definitionId)).get("fortuneEnhanceOnForm", false): inst.fortuneFormEnhanced = true

static func form_removed(gs, owner: int, _src: int, old_rules: Dictionary) -> void:
	if old_rules.get("fortuneEntryExitFire", false):
		gain_fire(gs, owner, 1)
		gain_fire(gs, 1 - owner, 1)

static func knockout_snapshot(unit: Dictionary) -> Dictionary:
	if unit.get("formRules", {}).get("lanternImmortal", false):
		return {"cardId": unit.form.cardId, "front": int(unit.front)}
	return {}

static func after_knockout(gs, owner: int, src: int, saved: Dictionary) -> void:
	if saved.is_empty() or int(gs.player(owner).energy) < 1 or gs.winner >= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	gs._set_fire(owner,int(gs.player(owner).energy)-1,true)
	unit.knockout = 0
	unit.hp = int(unit.maxHp)
	unit.front = int(saved.get("front", 0))
	gs._install_form(owner, src, ContentLoader.card_def(str(saved.cardId)))
	gs.VerifiedRules.event(gs, "lantern-returned", {"player": owner, "uid": unit.uid})

static func convert_heal(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> bool:
	if owner < 0 or owner == victim or amount <= 0: return false
	for unit in gs.player(owner).units:
		if active(unit) and unit.get("formRules", {}).get("enemyHealingIsDamage", false):
			if idx < 0: gs._damage_avatar(victim, amount, owner, src)
			else: gs._damage_unit(victim, idx, amount, owner, src)
			return true
	return false

static func heal(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> void:
	if convert_heal(gs, owner, src, victim, idx, amount): return
	if idx < 0: gs._heal_avatar(victim, amount)
	else: gs._heal_unit(gs.player(victim).units[idx], amount)

static func avatar_healed(gs, owner: int, amount: int, source_index: int = -1) -> void:
	if amount <= 0 or gs.winner >= 0: return
	for src in gs.player(owner).units.size():
		if source_index >= 0 and source_index != src: continue
		var monk: Dictionary = gs.player(owner).units[src]
		if not active(monk) or role(monk) != "monk": continue
		var enemy := 1 - owner
		var pool: Array = [-1]
		for i in gs.player(enemy).units.size():
			if int(gs.player(enemy).units[i].hp) > 0: pool.append(i)
		var targets: Array = []
		var count: int = pool.size() if monk.awakened else mini(2, pool.size())
		for _i in count:
			targets.append(pool.pop_at(int(floor(gs.randf01() * pool.size()))))
		for idx in targets:
			if gs.winner >= 0: break
			if idx < 0: gs.VerifiedRules.base_damage_avatar(gs, owner, src, enemy, 1)
			else: gs.VerifiedRules.base_damage_unit(gs, owner, src, enemy, idx, 1)
		if monk.get("formRules", {}).get("monkHealDraw", false) and int(monk.get("monkHealDrawTurn", -1)) != gs.turn_counter:
			monk.monkHealDrawTurn = gs.turn_counter
			if gs.winner < 0: gs._draw(owner, 1)
		gs.VerifiedRules.event(gs, "monk-heal-trigger", {"player": owner, "uid": monk.uid, "targets": targets, "awakened": monk.awakened})

static func avatar_attacked(gs, owner: int, source_owner: int) -> void:
	if source_owner < 0 or source_owner == owner: return
	var p: Dictionary = gs.player(owner)
	p.enemyAvatarAttacks = int(p.get("enemyAvatarAttacks", 0)) + 1
	gs.VerifiedRules.event(gs, "avatar-attacked", {"player": owner, "attackerPlayer": source_owner, "count": p.enemyAvatarAttacks})

static func prevents_avatar_damage(gs, owner: int, amount: int) -> bool:
	var p: Dictionary = gs.player(owner)
	if int(p.get("monkImmuneTurn", -1)) == gs.turn_counter: return true
	if owner == gs.current_player or amount < int(p.avatarHp): return false
	var outer_stack: Array = gs.resolution_stack
	var outer_context: Dictionary = gs._card_effect_context
	gs.resolution_stack = []
	if gs.VerifiedRules.automatic_response(gs, owner, "avatar-lethal", null, {"kind": "response-complete"}, gs.MAX_RESPONSE_DEPTH):
		while not gs.resolution_stack.is_empty() and gs.winner < 0: gs._resolve_frame(gs.resolution_stack.pop_back())
	gs.resolution_stack = outer_stack
	gs._card_effect_context = outer_context
	return int(p.get("monkImmuneTurn", -1)) == gs.turn_counter

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("effect") == "lantern-level":
		return gs.player(owner).hand.any(func(i): return ContentLoader.card_def(str(i.definitionId)).get("lightLantern", false))
	return true

static func targets(gs, owner: int, card: Dictionary) -> Variant:
	if card.get("target") != "lowest-ally-unit": return null
	var level: int = gs.min_level(owner)
	return gs.player(owner).units.filter(func(u): return int(u.level) == level).map(func(u): return u.uid)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var out := card.duplicate(true)
	if card.get("fortuneEnhanceOnForm", false) and inst.get("fortuneFormEnhanced", false):
		out.keywords = ["instant"]
		out.fortuneEnhanced = true
		out.text += "\n已增强：瞬发，使用时抽一张牌。"
	if card.get("effect") == "monk-rebirth": out.text += "\n当前生命设为%d（牌手已被对手攻击%d次）。" % [mini(int(gs.player(owner).maxAvatarHp), 10 + int(gs.player(owner).get("enemyAvatarAttacks", 0))), int(gs.player(owner).get("enemyAvatarAttacks", 0))]
	if card.get("effect") == "fortune-reset": out.text += "\n双方成功运势：%d/12。" % fortune_total(gs)
	if card.get("effect") in ["lantern-choice", "lantern-drain"]: out.text += "\n按当前鬼火，支付后共结算%d次。" % maxi(1, 1 + int(gs.player(owner).energy) - gs.effective_card_cost(owner, card))
	return out

static func card_started(gs, owner: int, card: Dictionary) -> void:
	if card.get("fortuneEnhanced", false): gs._draw(owner, 1)

static func start_choice(gs, owner: int, remaining: int) -> void:
	var p: Dictionary = gs.player(owner)
	if remaining <= 0 or p.deck.is_empty():
		gs._set_fire(owner,0,true)
		return
	gs.start_divination(owner, {"id": "c12902", "divination": {"count": 3}}, {})
	gs.pending_choice.type = "lantern-choice"
	gs.pending_choice.remaining = remaining
	gs.pending_choice.title = "青灯夜谈 · 选择一张置入手牌"

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "lantern-choice" or int(choice.playerIndex) != owner: return false
	if not choice.instanceIds.has(iid): return false
	var p: Dictionary = gs.player(owner)
	var idx := -1
	for i in p.deck.size():
		if p.deck[i].instanceId == iid: idx = i
	if idx < 0: return false
	var selected: Dictionary = p.deck.pop_at(idx)
	gs.VerifiedRules.BondDream.fetched(gs, selected)
	if p.hand.size() < int(gs.rules.get("maxHandSize", 12)): p.hand.append(selected)
	gs._record("resolve_divination_choice", {"instanceId": iid, "card": selected.definitionId, "choice": "lantern-choice"}, owner)
	var remaining := int(choice.remaining) - 1
	gs.pending_choice = {}
	gs.phase = "main"
	start_choice(gs, owner, remaining)
	if gs.pending_choice.is_empty(): gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[src]
	match str(effect.get("action", "")):
		"light-fire": gain_fire(gs, owner, int(effect.value))
		"light-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"lantern-choice": start_choice(gs, owner, 1 + int(p.energy))
		"lantern-drain":
			var repeats := 1 + int(p.energy)
			for _i in repeats:
				if gs.winner >= 0: break
				var idx: int = gs.front_index(1 - owner)
				if idx < 0: gs._damage_avatar(1 - owner, 5 + int(card.get("foxHandDamageBonus", 0)), owner, src)
				else: gs._damage_unit(1 - owner, idx, 5 + int(card.get("foxHandDamageBonus", 0)), owner, src)
			gs._set_fire(owner,0,true)
		"lantern-level":
			if target.is_empty() or not targets(gs, owner, card).has(target.uid): return true
			for i in p.hand.size():
				if ContentLoader.card_def(str(p.hand[i].definitionId)).get("lightLantern", false):
					p.hand.remove_at(i)
					if int(target.level) >= 3: gs._draw(owner, 1)
					else: gs.raise_unit_level(owner, gs._unit_index_by_uid(owner, target.uid))
					break
		"monk-seal":
			heal(gs, owner, src, owner, -1, 4)
			if gs.winner < 0: heal(gs, owner, src, 1 - owner, -1, 4)
		"monk-light":
			var recipient := -1
			var idx := -1
			for side in 2:
				if str(target_id) == "avatar-%d" % side: recipient = side
				elif not target.is_empty():
					var found: int = gs._unit_index_by_uid(side, target.uid)
					if found >= 0:
						recipient = side
						idx = found
			if recipient < 0: return true
			heal(gs, owner, src, recipient, idx, 3)
			if gs.winner >= 0: return true
			heal(gs, owner, src, recipient, -1, 3)
			for i in gs.player(recipient).units.size():
				if gs.winner >= 0: break
				heal(gs, owner, src, recipient, i, 3)
		"monk-awaken":
			heal(gs, owner, src, owner, -1, 8)
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, 0, 2)
		"monk-sacrifice":
			gs._knockout_unit(unit, owner, src)
			p.monkImmuneTurn = gs.turn_counter
			gs.VerifiedRules.event(gs, "monk-immunity", {"player": owner, "untilTurn": gs.turn_counter})
		"monk-rebirth": p.avatarHp = mini(int(p.maxAvatarHp), 10 + int(p.get("enemyAvatarAttacks", 0)))
		"fortune-fire":
			gs.resolution_stack.append({"kind": "charm-fortune-fire", "playerIndex": owner, "sourceIndex": src})
			gs._draw(owner, 1)
		"fortune-reset":
			if fortune_total(gs) >= 12:
				for side in [1 - owner, owner]:
					gs.resolution_stack.append({"kind": "charm-fortune-reset", "playerIndex": side})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0 or role(gs.player(owner).units[src]) == "": return null
	var missing := int(gs.player(owner).maxAvatarHp) - int(gs.player(owner).avatarHp)
	match str(card.get("effect", "")):
		"monk-sacrifice": return -100
		"monk-seal": return 25 + mini(4, missing) * 6
		"monk-awaken": return 55 + mini(8, missing) * 6
		"monk-rebirth": return (mini(int(gs.player(owner).maxAvatarHp), 10 + int(gs.player(owner).get("enemyAvatarAttacks", 0))) - int(gs.player(owner).avatarHp)) * 6
		"monk-light":
			if str(target_id) == "avatar-%d" % owner: return 45 + mini(6, missing) * 6
			var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
			if not ally.is_empty(): return 30 + (int(ally.maxHp) - int(ally.hp)) * 4
			return 60 if gs.player(owner).units.any(func(u): return active(u) and u.get("formRules", {}).get("enemyHealingIsDamage", false)) else -100
		"light-fire": return 45 if int(gs.player(owner).energy) < 4 else -100
		"lantern-choice": return 45 if gs.player(owner).hand.size() < 8 else -100
		"lantern-drain": return 65
		"lantern-level": return 85
		"fortune-fire": return 70
		"fortune-reset": return 85 + missing * 3 if fortune_total(gs) >= 12 else -100
		"light-awaken": return 70
		"form": return 40 if gs.player(owner).units[src].get("form", {}).get("cardId") != card.id else -100
	return null
