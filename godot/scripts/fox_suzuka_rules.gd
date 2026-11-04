class_name FoxSuzukaRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")
const DAMAGE_ACTIONS := ["damage", "damage-character", "damage-enemy-front", "damage-enemy-avatar", "damage-all-enemies", "damage-all-enemy-units", "projectile-draw-on-kill", "projectile-displace", "random-damage", "shuten-self-damage", "xuenv-damage", "feather-hit", "fox-projectile", "fox-unbound", "fox-storm", "fox-repeat", "suzuka-random"]
static func role(unit: Dictionary) -> String:
	return str(ContentLoader.runtime_unit_def(unit).get("foxSuzukaRole", ""))
static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)
static func spell(card: Dictionary) -> bool:
	return ContentLoader.is_spell(card)
static func hand_bonus(gs, owner: int) -> int:
	var bonus := 0
	for unit in gs.player(owner).units:
		if active(unit): bonus += int(unit.get("formRules", {}).get("foxHandSpellBonus", 0))
	return bonus
static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	var out := card.duplicate(true)
	if spell(card):
		out.foxHandDamageBonus = hand_bonus(gs, owner)
		if int(out.foxHandDamageBonus) > 0: out.text += "\n爱意绵绵：此牌的法术伤害效果+%d。" % int(out.foxHandDamageBonus)
	var src: int = gs._source_index(owner, card)
	if src < 0: return out
	var unit: Dictionary = gs.player(owner).units[src]
	if card.get("foxRule") == "storm":
		out.foxHitCount = 10 if int(unit.get("foxDamageEvents", 0)) >= 25 else 5
		out.text += "\n本局妖狐造成伤害%d次：重复%d次。" % [int(unit.get("foxDamageEvents", 0)), out.foxHitCount]
	if card.get("suzukaRule") == "white":
		var marked := int(gs.player(1 - owner).get("avatarArmorBreak", 0)) >= 2
		for target in gs.player(1 - owner).units:
			if int(target.hp) > 0 and int(target.get("armorBreak", 0)) >= 2: marked = true
		if marked: out.keywords.append("instant")
	if card.get("suzukaRule") == "nowhere" and targets(gs, owner, out).is_empty(): out.target = "auto"
	return out
static func damage_effect(card: Dictionary, effect: Dictionary) -> Dictionary:
	var bonus := int(card.get("foxHandDamageBonus", 0))
	if bonus <= 0 or str(effect.get("action", "")) not in DAMAGE_ACTIONS or not (effect.get("value") is int or effect.get("value") is float): return effect
	var out := effect.duplicate(true)
	out.value = int(out.value) + bonus
	return out
static func targets(gs, owner: int, card: Dictionary) -> Variant:
	if card.get("suzukaRule") != "nowhere": return null
	var enemy := 1 - owner
	var out: Array = []
	for u in gs.player(enemy).units:
		if int(u.hp) > 0 and (int(u.front) == 1 or int(u.get("armorBreak", 0)) > 0): out.append(u.uid)
	if int(gs.player(enemy).get("avatarArmorBreak", 0)) > 0: out.append("avatar-%d" % enemy)
	return out
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not spell(card): return
	var owner := int(frame.playerIndex)
	var triggers: Array = []
	for idx in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[idx]
		if active(u) and role(u) == "fox" and (u.awakened or idx == int(frame.sourceIndex)):
			triggers.append({"sourceIndex": idx, "uid": u.uid, "luck": not u.awakened})
	if triggers.is_empty(): return
	var ability := {"kind": "fox-spell-used", "playerIndex": owner, "triggers": triggers}
	for i in gs.resolution_stack.size():
		var pending: Dictionary = gs.resolution_stack[i]
		if pending.get("kind") == "card-complete" and int(pending.get("resolutionId", -1)) == int(frame.resolutionId):
			gs.resolution_stack.insert(i, ability)
			return
static func fortune_success(gs, owner: int) -> void:
	for idx in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[idx]
		if active(u) and role(u) == "fox" and u.awakened:
			gs.resolution_stack.append({"kind": "fox-ability-hit", "playerIndex": owner, "sourceIndex": idx})
static func _hit(gs, owner: int, src: int, victim: int, idx: int, amount: int, card: Dictionary) -> Dictionary:
	var result := {"damage": 0, "knocked": false}
	var previous: Dictionary = gs._card_effect_context
	if card.get("type") == "ability": gs._card_effect_context = {}
	if str(card.get("id", "")) == "fox-ability":
		if idx < 0: result.damage = gs.VerifiedRules.base_damage_avatar(gs,owner,src,victim,amount)
		else: result = gs.VerifiedRules.base_damage_unit(gs,owner,src,victim,idx,amount)
	elif idx < 0: result.damage = gs._damage_avatar(victim, amount, owner, src)
	else: result = gs._damage_unit(victim, idx, amount, owner, src)
	gs._card_effect_context = previous
	gs.VerifiedRules.event(gs, "fox-suzuka-hit", {"player": owner, "uid": gs.player(owner).units[src].uid, "victimPlayer": victim, "target": "" if idx < 0 else gs.player(victim).units[idx].uid, "amount": int(result.damage), "blocked": int(result.damage) == 0, "card": card})
	return result
static func _random_hit(gs, owner: int, src: int, amount: int, card: Dictionary, other_units: bool = false) -> Dictionary:
	var pool: Array = []
	for victim in ([owner, 1 - owner] if other_units else [1 - owner]):
		for idx in gs.player(victim).units.size():
			if int(gs.player(victim).units[idx].hp) > 0 and not (victim == owner and idx == src): pool.append([victim, idx])
		if not other_units: pool.append([victim, -1])
	if pool.is_empty() or gs.winner >= 0: return {"damage": 0, "knocked": false, "empty": true}
	var pick: Array = pool[int(floor(gs.randf01() * pool.size()))]
	return _hit(gs, owner, src, int(pick[0]), int(pick[1]), amount, card)
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	var owner := int(frame.get("playerIndex", 0))
	if kind == "fox-spell-used":
		for trigger in frame.triggers:
			var idx := int(trigger.sourceIndex)
			if trigger.get("luck", false):
				if not gs.VerifiedRules.Light.roll(gs, owner, 4, 6, idx): continue
				for copy in gs.VerifiedRules.Fortune.last_repeats(gs, owner): gs.resolution_stack.append({"kind": "fox-ability-hit", "playerIndex": owner, "sourceIndex": idx})
			else: gs.resolution_stack.append({"kind": "fox-ability-hit", "playerIndex": owner, "sourceIndex": idx})
		return true
	if kind == "fox-ability-hit":
		var src := int(frame.sourceIndex)
		var u: Dictionary = gs.player(owner).units[src]
		var card := {"id": "fox-ability", "unitId": u.id, "type": "ability", "name": "风弹", "text": "随机对一个敌方角色造成伤害。"}
		_random_hit(gs, owner, src, 2 + int(u.get("foxAbilityBonus", 0)), card)
		return true
	if kind in ["fox-unbound-hit", "fox-storm-hit", "suzuka-random-hit"]:
		var src := int(frame.sourceIndex)
		var card: Dictionary = frame.card
		var previous: Dictionary = gs._card_effect_context
		gs._card_effect_context = frame.get("effectContext", {})
		var base: int = gs.resolution_stack.size()
		var hit: Dictionary
		if kind == "suzuka-random-hit":
			var pool: Array = []
			for i in gs.player(1 - owner).units.size():
				if int(gs.player(1 - owner).units[i].hp) > 0: pool.append(i)
			if pool.is_empty(): return true
			hit = _hit(gs, owner, src, 1 - owner, int(pool[int(floor(gs.randf01() * pool.size()))]), 1, card)
		else: hit = _random_hit(gs, owner, src, int(frame.amount), card, kind == "fox-unbound-hit")
		gs._card_effect_context = previous
		var remaining := int(frame.remaining) - 1
		if remaining > 0 and gs.winner < 0 and not hit.get("empty", false) and not (kind == "fox-unbound-hit" and hit.knocked):
			var next := frame.duplicate(true)
			next.remaining = remaining
			gs.resolution_stack.insert(base, next)
		return true
	return false
static func projectile(gs, owner: int, src: int, amount: int, card: Dictionary) -> void:
	_hit(gs, owner, src, 1 - owner, gs.front_index(1 - owner), amount, card)
static func damage_dealt(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> void:
	if amount <= 0 or owner < 0 or src < 0 or src >= gs.player(owner).units.size(): return
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) == "fox": u.foxDamageEvents = int(u.get("foxDamageEvents", 0)) + 1
	if role(u) == "suzuka" and (idx < 0 or int(gs.player(victim).units[idx].hp) > 0):
		gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, mini(3, amount) if u.awakened else 1)
static func immune(gs, victim: int, idx: int, owner: int, src: int) -> bool:
	return owner >= 0 and src >= 0 and owner != victim and active(gs.player(victim).units[idx]) and gs.player(victim).units[idx].get("formRules", {}).get("suzukaImmuneMarked", false) and int(gs.player(owner).units[src].get("armorBreak", 0)) > 0
static func strike_power(gs, owner: int, victim: int, idx: int, amount: int, options: Dictionary) -> int:
	if idx < 0 or not options.get("suzukaDoubleMarked", false): return amount
	var marked := int(gs.player(victim).units[idx].get("armorBreak", 0))
	return amount * 2 + marked if marked > 0 and not options.get("convertCombatToArmorBreak", false) else amount
static func combat_dealt(options: Dictionary, result: Dictionary) -> void:
	if options.get("suzukaLight", false): options.suzukaDamage = int(options.get("suzukaDamage", 0)) + int(result.get("dealt", result.get("damage", 0)))
static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.get("suzukaLight", false) or int(options.get("suzukaDamage", 0)) < 6: return
	gs.resolution_stack.append({"kind": "charm-heal-avatar", "playerIndex": owner, "amount": floori(float(options.suzukaDamage) / 2.0)})
	gs._draw(owner, 1)
static func before_attack(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if active(u) and u.get("formRules", {}).get("suzukaHomeProjectile", false): projectile(gs, owner, src, 3, {"type": "ability", "id": "suzuka-home", "unitId": u.id})
static func turn_start(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if active(u) and u.get("formRules", {}).get("foxTurnBlade", false):
		if gs.player(owner).hand.size() < int(gs.rules.maxHandSize):
			gs.player(owner).hand.append({"instanceId": "fox-blade-%d" % gs.next_card_id, "definitionId": "fengren"})
			gs.next_card_id += 1
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"fox-focus": u.foxAbilityBonus = int(u.get("foxAbilityBonus", 0)) + 1
		"fox-awaken", "suzuka-awaken":
			u.awakened = true
			u.passive_hooks = []
			gs._grow_unit(u, int(effect.value.attack), int(effect.value.hp))
			if effect.action == "suzuka-awaken": projectile(gs, owner, src, 1 + int(card.get("foxHandDamageBonus", 0)), card)
		"fox-projectile": projectile(gs, owner, src, int(effect.value), card)
		"fox-unbound", "fox-storm", "suzuka-random":
			var kind: String = {"fox-unbound": "fox-unbound-hit", "fox-storm": "fox-storm-hit", "suzuka-random": "suzuka-random-hit"}[str(effect.action)]
			var count := int(effect.value) if effect.action == "suzuka-random" else (int(card.get("foxHitCount", 5)) if effect.action == "fox-storm" else 10)
			gs.resolution_stack.append({"kind": kind, "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true), "remaining": count, "amount": int(effect.value), "effectContext": gs._card_effect_context})
		"fox-repeat":
			var victim := owner if gs._unit_index_by_uid(owner, target.get("uid", "")) >= 0 else 1 - owner
			var idx: int = gs._unit_index_by_uid(victim, target.get("uid", ""))
			if idx >= 0 and int(target.hp) > 0: _hit(gs, owner, src, victim, idx, int(effect.value), card)
			if not card.get("foxRepeated", false) and idx >= 0 and int(target.hp) > 0:
				var repeated := card.duplicate(true)
				repeated.foxRepeated = true
				gs._push_card_frames(owner, str(card.id), target_id, repeated, src, 0, true)
		"suzuka-nowhere":
			var enemy := 1 - owner
			if target_id == "avatar-%d" % enemy: _hit(gs, owner, src, enemy, -1, 2, card)
			elif not target.is_empty() and int(target.hp) > 0: _hit(gs, owner, src, enemy, gs._unit_index_by_uid(enemy, target.uid), 2, card)
		_: return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.has("foxRule") and not card.has("suzukaRule"): return null
	var src: int = gs._source_index(owner, card)
	var u: Dictionary = gs.player(owner).units[src]
	if card.get("foxRule") == "awaken" or card.get("suzukaRule") == "awaken": return -100 if u.awakened else 90
	if card.get("foxRule") == "focus": return 85
	if card.get("foxRule") == "unbound": return 25 if gs.player(owner).units.filter(func(t): return t.hp > 0 and t.hp <= 2).is_empty() else -100
	if card.get("target") == "any-living-unit" and gs._unit_index_by_uid(owner, target_id) >= 0: return -100
	return 60
