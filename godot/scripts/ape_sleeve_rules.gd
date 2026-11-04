class_name ApeSleeveRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const CHOICE := "ape-mimic"

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("apeSleeveRole", ""))

static func active(u: Dictionary) -> bool:
	return int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func living(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func base_damage_bonus(gs, owner: int) -> int:
	if owner < 0 or owner >= gs.players.size(): return 0
	return gs.player(owner).units.filter(func(u): return active(u) and role(u) == "sleeve" and u.awakened).size()

# Store only the modifier introduced here. Current life is the printed “生命”
# value used by these cards; a wounded unit must not copy its maximum life.
static func set_stats(gs, owner: int, u: Dictionary, attack: int, life: int) -> void:
	if int(u.hp) <= 0 or u.get("removed", false): return
	var da := attack - int(u.attack); var dh := life - int(u.maxHp)
	u.attackBonus = int(u.attackBonus) + da; u.maxHpBonus = int(u.maxHpBonus) + dh
	u.apeStatAttack = int(u.get("apeStatAttack", 0)) + da; u.apeStatHp = int(u.get("apeStatHp", 0)) + dh
	gs._recalc(u); u.hp = maxi(0, life)
	gs.VerifiedRules.event(gs, "ape-stats-set", {"player": owner, "target": u.uid, "attack": attack, "hp": life})
	if int(u.hp) <= 0: gs._knockout_unit(u, owner)

static func swap(gs, owner: int, u: Dictionary) -> void:
	var attack := int(u.attack); var life := int(u.hp)
	set_stats(gs, owner, u, life, attack)

static func maxima(gs, sides: Array) -> Dictionary:
	var a := 0; var h := 0
	for side in sides:
		for u in living(gs, int(side)):
			a = maxi(a, int(u.attack)); h = maxi(h, int(u.hp))
	return {"attack": a, "hp": h}

static func turn_start(gs, owner: int) -> void:
	for side in 2:
		for u in gs.player(side).units:
			if not active(u) or role(u) != "ape": continue
			if side == owner:
				if u.awakened:
					var iid := "ape-free-%d" % gs.next_card_id; gs.next_card_id += 1
					if gs.player(side).hand.size() < int(gs.rules.maxHandSize): gs.player(side).hand.append({"definitionId": "c29401", "instanceId": iid, "apeFree": true})
					gs.VerifiedRules.event(gs, "ape-free-card", {"player": side, "uid": u.uid, "instanceId": iid})
				else: swap(gs, side, u)
			if active(u) and u.get("formRules", {}).get("apeMoon", false):
				var m := maxima(gs, [0, 1]); set_stats(gs, side, u, int(m.attack), int(m.hp))

static func describe(_gs, _owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not inst.get("apeFree", false): return card
	var c := card.duplicate(true); c.cost = 0; c.currentCardStats = "觉醒·川猿生成 · 不消耗鬼火"; return c

static func targets(gs, owner: int, card: Dictionary):
	var id := str(card.get("id", ""))
	if id == "c29402":
		var result: Array = []
		for side in [owner, 1-owner]:
			for u in living(gs, side):
				if side == owner or not gs.VerifiedRules.Combat.has(u, "veil"): result.append(str(u.uid))
		return result
	if id == "c29405": return living(gs, owner).map(func(u): return str(u.uid))
	if id in ["c29404", "c29601", "c29602", "c29604", "c29606", "c29607"]:
		return living(gs, 1-owner).filter(func(u): return not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	return null

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if str(card.id) == "c29408":
		var m := maxima(gs, [0, 1]); set_stats(gs, owner, u, int(m.attack), int(m.hp))
	if str(card.id) == "c29605": queue_random(gs, owner, src, "丝缕相连")

static func _spell_hit(gs, owner: int, src: int, target_id, amount: int) -> void:
	var idx: int = gs._unit_index_by_uid(1-owner, str(target_id))
	if idx >= 0 and int(gs.player(1-owner).units[idx].hp) > 0: gs._damage_unit(1-owner, idx, amount + int(gs.player(owner).units[src].get("spellPower", 0)) + int(gs._card_effect_context.get("cardOverride", {}).get("foxHandDamageBonus", 0)), owner, src)

static func queue_random(gs, owner: int, src: int, reason: String) -> void:
	gs.resolution_stack.append({"kind": "sleeve-random", "playerIndex": owner, "sourceIndex": src, "reason": reason})

static func attack_started(gs, frame: Dictionary) -> bool:
	if frame.get("sleeveObserved", false): return false
	frame.sleeveObserved = true
	var owner := int(frame.playerIndex); var observers: Array = []
	for idx in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[idx]
		if active(u) and u.get("formRules", {}).get("sleeveAttack", false): observers.append(idx)
	if observers.is_empty(): return false
	gs.resolution_stack.append(frame)
	for idx in observers: queue_random(gs, owner, int(idx), "丝缕相连")
	return true

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	if not Content.is_spell(card): return
	var owner := int(frame.playerIndex)
	var target_id = frame.get("targetId")
	if target_id == null or gs._unit_index_by_uid(1-owner, str(target_id)) < 0: return
	# Only spells with a single selected enemy shikigami, never an AOE/automatic
	# random effect or an avatar target, satisfy the printed form condition.
	if card.get("target", "auto") == "auto": return
	for idx in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[idx]
		if active(u) and u.get("formRules", {}).get("sleeveSpell", false): queue_random(gs, owner, idx, "补缀添香")

static func damage_dealt(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> void:
	if amount <= 0 or owner < 0 or src < 0 or owner == victim: return
	var source: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]): return
	# The attack may have knocked its own source out simultaneously; the source
	# which dealt this damage still owns the already-triggered base ability.
	if role(source) == "sleeve" and int(source.level) > 0:
		gs.resolution_stack.append({"kind": "sleeve-passive", "playerIndex": owner, "sourceIndex": src})
		for target in living(gs, victim):
			var charm: Dictionary = target.get("sleeveThread", {})
			if charm.is_empty() or int(charm.owner) != owner or str(charm.get("sourceUid", "")) != str(source.uid) or int(charm.get("usedTurn", -1)) == gs.turn_counter: continue
			charm.usedTurn = gs.turn_counter
			if target.has("sleeveThreadPermanent"): target.sleeveThreadPermanent.usedTurn = gs.turn_counter
			gs.resolution_stack.append({"kind": "sleeve-thread-hit", "playerIndex": owner, "sourceIndex": src, "target": str(target.uid)})

static func death_frames(gs, victim: int, dead: Dictionary) -> Array:
	var result: Array = []
	if victim < 0 or not gs.VerifiedRules.OwlInsect.shikigami(dead): return result
	for u in living(gs, victim):
		if u.uid == dead.uid: continue
		var marks: Array = u.get("sleeveMend", []).duplicate(true)
		u.erase("sleeveMend")
		for mark in marks: result.append({"kind": "sleeve-mend", "playerIndex": int(mark.owner), "sourceIndex": int(mark.src), "target": str(u.uid)})
	return result

static func _awaken(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not u.awakened: gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
	else:
		gs.VerifiedRules.Glutton.record_permanent(u, 1, 1, true); gs.VerifiedRules.SunSmoke.remember_permanent(u, 1, 1); gs._grow_unit(u, 1, 1)

static func _combat(gs, owner: int, src: int, card: Dictionary, target_id, options: Dictionary = {}) -> void:
	options.combatCard = card.duplicate(true)
	gs._record("assault", {"unit": src, "bonus": 0, "target": target_id}, owner)
	gs._resolve_combat(owner, src, 0, false, false, false, false, target_id, false, options)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	var target: Dictionary = gs._unit_by_uid(gs._all_units(), str(target_id))
	match str(effect.get("action", "")):
		"ape-swap": swap(gs, owner, u); gs._draw(owner, 1)
		"ape-copy": set_stats(gs, owner, target, int(u.attack), int(u.hp))
		"ape-all":
			if target.is_empty() or int(target.hp) <= 0: return true
			var a := int(target.attack); var h := int(target.hp)
			for ally in living(gs, owner): set_stats(gs, owner, ally, a, h)
		"ape-paper":
			var attack := int(u.attack); var life := int(u.hp)
			_spell_hit(gs, owner, src, target_id, attack); gs._heal_avatar(owner, life)
		"ape-awaken": _awaken(gs, owner, src, card)
		"ape-mimic":
			gs.pending_choice = {"type": CHOICE, "playerIndex": owner, "sourceIndex": src, "targetId": target_id, "card": card.duplicate(true), "instanceIds": ["ape-attack", "ape-life"], "heading": "仿 模", "hint": "选择本次战斗要变为己方式神最大值的属性；战斗结束后移除该次变更。"}; gs.phase = "choice"
		"ape-seamless":
			if not target.is_empty() and int(target.hp) > 0:
				var a := int(target.attack); var h := int(target.hp)
				gs._grow_unit(u, a, h); u.apeTurnAttack = int(u.get("apeTurnAttack", 0)) + a; u.apeTurnHp = int(u.get("apeTurnHp", 0)) + h
			_combat(gs, owner, src, card, target_id, {"pursuit": true})
		"sleeve-needle":
			if card.get("focusPaid", false): gs.resolution_stack.append({"kind": "sleeve-extra", "playerIndex": owner, "sourceIndex": src, "excluded": str(target_id), "card": card.duplicate(true), "context": gs._card_effect_context.duplicate(true)})
			_spell_hit(gs, owner, src, target_id, 2)
		"sleeve-mend":
			if not target.is_empty() and int(target.hp) > 0:
				if not target.has("sleeveMend"): target.sleeveMend = []
				target.sleeveMend.append({"owner": owner, "src": src})
		"sleeve-reset":
			if not target.is_empty() and int(target.hp) > 0:
				gs.VerifiedRules.SunSmoke.reset_character(gs, owner, target, target_id)
				reset_ledger(target)
				_spell_hit(gs, owner, src, target_id, 4)
		"sleeve-thread":
			if not target.is_empty() and int(target.hp) > 0:
				for side in gs.players:
					for old in side.units:
						if str(old.get("sleeveThreadPermanent", old.get("sleeveThread", {})).get("sourceUid", "")) == str(u.uid):
							old.erase("sleeveThread"); old.erase("sleeveThreadPermanent")
				target.sleeveThread = {"owner": owner, "src": src, "sourceUid": str(u.uid), "usedTurn": -1}
				target.sleeveThreadPermanent = target.sleeveThread.duplicate(true)
				if card.get("focusPaid", false): _spell_hit(gs, owner, src, target_id, 2)
		"sleeve-thousand":
			for n in range(4, -1, -1): gs.resolution_stack.append({"kind": "sleeve-thousand", "playerIndex": owner, "sourceIndex": src, "target": str(target_id), "card": card.duplicate(true), "context": gs._card_effect_context.duplicate(true), "number": n})
		"sleeve-awaken":
			gs.resolution_stack.append({"kind": "sleeve-awaken-complete", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true)})
			var pool := living(gs, 1-owner).duplicate()
			for n in mini(2, pool.size()):
				var chosen: Dictionary = pool.pop_at(int(gs.next_random() % pool.size()))
				gs.resolution_stack.append({"kind": "sleeve-awaken-hit", "playerIndex": owner, "sourceIndex": src, "target": str(chosen.uid), "card": card.duplicate(true), "context": gs._card_effect_context.duplicate(true)})
		_: return false
	return true

static func choice_card(gs, owner: int, iid: String):
	var q: Dictionary = gs.pending_choice
	if q.get("type") != CHOICE or int(q.playerIndex) != owner or iid not in q.instanceIds: return null
	var m := maxima(gs, [owner])
	return {"id": iid, "unitId": "chuanyuan", "art": Content.unit_def("chuanyuan").art, "name": "仿模·力量" if iid == "ape-attack" else "仿模·生命", "type": "spell", "cost": 0, "level": 1, "text": "本次战斗，力量变为%d。" % int(m.attack) if iid == "ape-attack" else "本次战斗，生命变为%d。" % int(m.hp)}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var q: Dictionary = gs.pending_choice
	if q.get("type") != CHOICE or int(q.playerIndex) != owner or iid not in q.instanceIds: return false
	var src := int(q.sourceIndex); var u: Dictionary = gs.player(owner).units[src]; var m := maxima(gs, [owner])
	var da := int(m.attack) - int(u.attack) if iid == "ape-attack" else 0
	var dh := int(m.hp) - int(u.maxHp) if iid == "ape-life" else 0
	var life_delta := int(m.hp)-int(u.hp) if iid == "ape-life" else 0
	u.attackBonus = int(u.attackBonus) + da; u.maxHpBonus = int(u.maxHpBonus) + dh; gs._recalc(u)
	if iid == "ape-life": u.hp = int(m.hp)
	u.apeCombatAttack = int(u.get("apeCombatAttack", 0)) + da; u.apeCombatHp = int(u.get("apeCombatHp", 0)) + dh
	u.apeCombatLife = life_delta
	gs.pending_choice = {}; gs.phase = "main"
	gs._record("resolve_divination_choice", {"choice": CHOICE, "instanceId": iid}, owner)
	_combat(gs, owner, src, q.card, q.get("targetId"), {"apeMimic": true})
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != CHOICE: return null
	var src := int(gs.pending_choice.sourceIndex); var u: Dictionary = gs.player(owner).units[src]; var m := maxima(gs, [owner])
	return resolve_choice(gs, owner, "ape-attack" if int(m.attack)-int(u.attack) >= int(m.hp)-int(u.hp) else "ape-life")

static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.get("apeMimic", false): return
	var u: Dictionary = gs.player(owner).units[src]
	var was_alive := int(u.hp)>0; var remaining := int(u.hp)-int(u.get("apeCombatLife",0))
	u.attackBonus = int(u.attackBonus) - int(u.get("apeCombatAttack", 0)); u.maxHpBonus = int(u.maxHpBonus) - int(u.get("apeCombatHp", 0))
	u.erase("apeCombatAttack"); u.erase("apeCombatHp"); u.erase("apeCombatLife"); gs._recalc(u)
	if was_alive:
		u.hp = maxi(0,mini(int(u.maxHp),remaining))
		if int(u.hp)<=0: gs._knockout_unit(u,owner)

static func end_turn(gs, _owner: int) -> void:
	for p in gs.players:
		for u in p.units:
			if not u.has("apeTurnAttack"): continue
			u.attackBonus = int(u.attackBonus) - int(u.apeTurnAttack); u.maxHpBonus = int(u.maxHpBonus) - int(u.get("apeTurnHp", 0))
			u.erase("apeTurnAttack"); u.erase("apeTurnHp"); gs._recalc(u)

static func reset_ledger(u: Dictionary) -> void:
	for k in ["apeStatAttack", "apeStatHp", "apeTurnAttack", "apeTurnHp", "apeCombatAttack", "apeCombatHp", "apeCombatLife"]: u.erase(k)

static func knocked_out(u: Dictionary) -> void:
	u.attackBonus = int(u.attackBonus) - int(u.get("apeStatAttack", 0)) - int(u.get("apeTurnAttack", 0)) - int(u.get("apeCombatAttack", 0))
	u.maxHpBonus = int(u.maxHpBonus) - int(u.get("apeStatHp", 0)) - int(u.get("apeTurnHp", 0)) - int(u.get("apeCombatHp", 0))
	reset_ledger(u); u.erase("sleeveMend"); u.erase("sleeveThread")

static func revived(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.hp)>0 and u.has("sleeveThreadPermanent"): u.sleeveThread = u.sleeveThreadPermanent.duplicate(true)

static func remove_charm(gs, owner: int, idx: int) -> void:
	gs.player(owner).units[idx].erase("sleeveThread")
	gs.VerifiedRules.event(gs,"sleeve-thread-removed",{"player":owner,"target":gs.player(owner).units[idx].uid})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("sleeve-"): return false
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex)
	var old_context: Dictionary = gs._card_effect_context; gs._card_effect_context = frame.get("context", {})
	match kind:
		"sleeve-passive": gs.VerifiedRules.base_damage_avatar(gs, owner, src, 1-owner, 1)
		"sleeve-awaken-complete": _awaken(gs, owner, src, frame.card)
		"sleeve-random":
			if not active(gs.player(owner).units[src]):
				gs._card_effect_context = old_context; return true
			var pool := living(gs, 1-owner)
			if not pool.is_empty():
				var chosen: Dictionary = pool[int(gs.next_random() % pool.size())]
				var old: Dictionary = gs._card_effect_context; gs._card_effect_context = {}
				gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, chosen.uid), 1, owner, src); gs._card_effect_context = old
		"sleeve-extra":
			var pool := living(gs, 1-owner).filter(func(t): return str(t.uid) != str(frame.excluded))
			if not pool.is_empty(): _spell_hit(gs, owner, src, pool[int(gs.next_random() % pool.size())].uid, 2)
		"sleeve-mend":
			var idx: int = gs._unit_index_by_uid(1-owner, str(frame.target))
			if idx >= 0 and int(gs.player(1-owner).units[idx].hp) > 0: gs._damage_unit(1-owner, idx, 4, 1-owner, idx)
		"sleeve-thread-hit":
			var idx: int = gs._unit_index_by_uid(1-owner, str(frame.target))
			if idx >= 0 and int(gs.player(1-owner).units[idx].hp) > 0: gs._damage_unit(1-owner, idx, 3, owner, src)
		"sleeve-thousand": _spell_hit(gs, owner, src, frame.target, 3)
		"sleeve-awaken-hit": _spell_hit(gs, owner, src, frame.target, 2)
	gs._card_effect_context = old_context
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("apeSleeveRules", false): return null
	var src: int = gs._source_index(owner, card); var u: Dictionary = gs.player(owner).units[src]
	if card.id == "c29402":
		var target: Dictionary = gs._unit_by_uid(gs._all_units(), str(target_id))
		var diff := int(u.attack) + int(u.hp) - int(target.attack) - int(target.hp)
		return 15 + diff * (3 if gs._unit_index_by_uid(owner, str(target_id)) >= 0 else -3)
	if card.id == "c29405":
		var target: Dictionary = gs._unit_by_uid(gs._all_units(), str(target_id)); return int(target.attack) + int(target.hp)
	return 65 if card.get("type") == "awakening" and not u.awakened else 35

static func marks(_gs, _owner: int, u: Dictionary) -> Array:
	var result: Array = []
	if u.has("sleeveMend"): result.append("缝补%d层 · 其他己方式神气绝时受4伤并移除" % u.sleeveMend.size())
	if u.has("sleeveThread"): result.append("结袂 · 唯一/永久 · 每回合一次小袖伤敌后受3伤")
	if u.has("apeTurnAttack"): result.append("天衣无缝 · 本回合+%d力量/+%d生命" % [int(u.apeTurnAttack), int(u.get("apeTurnHp", 0))])
	if role(u) == "sleeve" and u.awakened: result.append("觉醒 · 己方基础/觉醒能力非战斗伤害+1")
	return result
