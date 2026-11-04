class_name RedPurpleRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const Glossary := preload("res://scripts/ui/keyword_glossary.gd")
const TRAITS := ["swift", "pierce", "combo", "remote", "first-strike", "direct", "pursuit", "penetration", "unyielding", "crit", "lethal", "lifesteal", "veil", "inspired"]
const FOX_HEAL := "rp-fox-heal"
const FOX_REALM := "rp-fox-realm"

static func role(unit: Dictionary) -> String:
	return str(Content.runtime_unit_def(unit).get("redPurpleRole", ""))

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and int(unit.get("level", 0)) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func shikigami(unit: Dictionary) -> bool:
	return bool(unit.get("countsAsShikigami", not unit.get("summoned", false)))

static func faction_units(gs, owner: int, faction: String, living: bool = false, other_uid: String = "") -> Array:
	return gs.player(owner).units.filter(func(u): return shikigami(u) and not u.get("removed", false) and str(u.uid) != other_uid and Factions.get_faction(u) == faction and (not living or int(u.hp) > 0))

static func all_faction(gs, owner: int, faction: String) -> bool:
	var units: Array = gs.player(owner).units.filter(func(u): return shikigami(u) and not u.get("removed", false))
	return not units.is_empty() and units.all(func(u): return Factions.get_faction(u) == faction)

static func aura_bonus(gs, unit: Dictionary, _stat: String) -> int:
	if unit.get("removed", false) or not shikigami(unit): return 0
	for owner in gs.players.size():
		if not gs.player(owner).units.has(unit): continue
		var amount := 0
		for source in gs.player(owner).units:
			if str(source.uid) == str(unit.uid) or not active(source) or not source.awakened: continue
			var faction := "红莲" if role(source) == "red" else "紫岩" if role(source) == "purple" else ""
			if faction != "" and Factions.get_faction(unit) == faction: amount += 1
		return amount
	return 0

static func power_bonus(gs, unit: Dictionary) -> int:
	if not active(unit) or not unit.get("formRules", {}).get("rpMighty", false): return 0
	for owner in gs.players.size():
		if gs.player(owner).units.has(unit):
			return 3 if gs.player(owner).units.any(func(u): return str(u.uid) != str(unit.uid) and int(u.hp) > 0 and not u.get("removed", false) and shikigami(u) and int(u.attack) >= 6) else 0
	return 0

static func refresh(gs) -> void:
	# Recompute only changed contributions; unrelated units keep their current
	# derived state when another unit changes faction or leaves play.
	for p in gs.players:
		for u in p.units:
			if not u.get("formRules", {}).get("rpMighty", false) and _contribution_changed(gs, u): gs._recalc(u)
	for p in gs.players:
		for u in p.units:
			if u.get("formRules", {}).get("rpMighty", false) and _contribution_changed(gs, u): gs._recalc(u)

static func _contribution_changed(gs, unit: Dictionary) -> bool:
	var aura := aura_bonus(gs, unit, "attack") + int(gs.VerifiedRules.BlueGreen.aura_bonus(gs, unit, "attack"))
	return aura != int(unit.get("factionAuraApplied", 0)) or power_bonus(gs, unit) != int(unit.get("rpMightyApplied", 0))

static func _grow(gs, unit: Dictionary, attack: int, health: int, permanent: bool = false) -> void:
	if permanent:
		gs.VerifiedRules.Glutton.record_permanent(unit, attack, health)
		gs.VerifiedRules.SunSmoke.remember_permanent(unit, attack, health)
	else:
		unit.rpGrowthAttack = int(unit.get("rpGrowthAttack", 0)) + attack
		unit.rpGrowthHp = int(unit.get("rpGrowthHp", 0)) + health
	gs._grow_unit(unit, attack, health)

static func announced(gs, frame: Dictionary, _card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	if src < 0: return
	var p: Dictionary = gs.player(owner)
	var source: Dictionary = p.units[src]
	if int(p.get("rpRedCountTurn", -1)) != gs.turn_counter:
		p.rpRedCountTurn = gs.turn_counter
		p.rpRedCards = 0
	var faction := Factions.get_faction(source)
	if faction == "红莲": p.rpRedCards = int(p.get("rpRedCards", 0)) + 1
	for u in p.units:
		if not active(u): continue
		if role(u) == "red" and faction == "红莲" and int(p.rpRedCards) == 2 and (not u.awakened or int(u.get("rpAwakenRedTurn", -1)) == gs.turn_counter):
			_grow(gs, u, 1, 1)
			gs.VerifiedRules.event(gs, "rp-red-second", {"player": owner, "uid": u.uid, "sourceUid": source.uid})
		elif role(u) == "purple" and faction == "紫岩" and str(u.uid) != str(source.uid):
			_grow(gs, u, 0, 1)
			gs.VerifiedRules.event(gs, "rp-purple-used", {"player": owner, "uid": u.uid, "sourceUid": source.uid})
	refresh(gs)

static func knocked_out(unit: Dictionary) -> void:
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("rpGrowthAttack", 0)) - int(unit.get("rpRenxiaAttack", 0))
	unit.maxHpBonus = int(unit.maxHpBonus) - int(unit.get("rpGrowthHp", 0))
	for key in ["rpGrowthAttack", "rpGrowthHp", "rpRenxiaAttack", "rpRenxiaTurn", "rpPursuit", "rpAwakenRedTurn"]: unit.erase(key)

static func end_turn(gs, owner: int) -> void:
	var stacks := int(gs.player(owner).get("rpJourneyStacks", 0))
	if stacks > 0:
		for u in faction_units(gs, owner, "紫岩"):
			_grow(gs, u, stacks, stacks, true)
			gs.VerifiedRules.event(gs, "rp-journey-growth", {"player": owner, "uid": u.uid, "stacks": stacks, "knocked": int(u.hp) <= 0})
	for p in gs.players:
		for u in p.units:
			if int(u.get("rpRenxiaTurn", -1)) == gs.turn_counter:
				u.attackBonus = int(u.attackBonus) - int(u.get("rpRenxiaAttack", 0))
				for key in ["rpRenxiaAttack", "rpRenxiaTurn", "rpPursuit"]: u.erase(key)
	refresh(gs)

static func has_pursuit(unit: Dictionary) -> bool:
	return active(unit) and bool(unit.get("rpPursuit", false))

static func _swift(gs, owner: int, u: Dictionary) -> bool:
	return bool(u.get("swift", false)) or gs.VerifiedRules.Glutton.has(u, "swift") or gs.VerifiedRules.Bailang.swift(u) or gs.VerifiedRules.IronMouse.swift(gs, u) or gs.VerifiedRules.TreeSakura.floating(u) or gs.VerifiedRules.Rebirth.swift(u) or gs.VerifiedRules.Samurai.swift(u) or gs.VerifiedRules.Yitiao.swift(u) or gs.VerifiedRules.Mianqiling.swift(u)

static func _unyielding(gs, u: Dictionary) -> bool:
	return bool(u.get("unyielding", false)) or bool(u.get("combatUnyielding", false)) or bool(u.get("futakuchiUnyielding", false)) or bool(u.get("owlUnyielding", false)) or gs.VerifiedRules.Glutton.has(u, "unyielding") or gs.VerifiedRules.Enma.has(u, "unyielding") or gs.VerifiedRules.Shuten.has_unyielding(u) or gs.VerifiedRules.Bailang.unyielding(u) or gs.VerifiedRules.Mianqiling.unyielding(u) or bool(u.get("formRules", {}).get("riverUnyielding", false))

static func sword_snapshot(gs, owner: int, src: int) -> Dictionary:
	var source: Dictionary = gs.player(owner).units[src]
	var result := {"attack": 3, "hp": 3, "keywords": [], "barrier": false, "charge": false}
	for u in faction_units(gs, owner, "红莲", false, str(source.uid)):
		result.attack += maxi(0, int(u.attack))
		result.hp += maxi(0, int(u.hp))
		for keyword in TRAITS:
			var present: bool = gs.VerifiedRules.Combat.has(u, str(keyword))
			if keyword == "swift": present = present or (active(u) and _swift(gs, owner, u))
			elif keyword == "unyielding": present = present or (active(u) and _unyielding(gs, u))
			if present and keyword not in result.keywords: result.keywords.append(keyword)
		result.barrier = result.barrier or (active(u) and bool(u.get("barrier", false)))
		result.charge = result.charge or (active(u) and (Content.runtime_unit_def(u).get("nativeCharge", false) or gs.VerifiedRules.SunSmoke.role(u) in ["sun", "smoke"] or "charge" in u.get("keywords", [])))
	return result

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("redPurpleRules", false): return card
	var view := card.duplicate(true)
	var src: int = gs._source_index(owner, card)
	if src < 0: return view
	var unit: Dictionary = gs.player(owner).units[src]
	match str(card.id):
		"c20401":
			var usage: Dictionary = gs.kw_usage(owner, "encourage")
			view.rpNightRaid = true
			view.enhanced = int(usage.get("attack", 0)) != 0 or int(usage.get("shield", 0)) != 0 or not usage.get("traits", {}).is_empty()
			if view.enhanced and "instant" not in view.keywords: view.keywords.append("instant")
			view.currentCardStats = "共享出击加成 · " + ("瞬发" if view.enhanced else "无鼓舞")
		"c20405", "c20508":
			var red := str(card.id) == "c20405"
			var count := faction_units(gs, owner, "红莲" if red else "紫岩", true, str(unit.uid)).size()
			var bonus := count * (1 if red else 3)
			view.value = {"attack": 4 + bonus, "hp": 4 + bonus, "setBase": true}
			view.effects[0].value = view.value.duplicate(true)
			view.enhanced = count > 0
			view.currentCardStats = "其他同派存活%d个 · 当前%d/%d" % [count, 4 + bonus, 4 + bonus]
		"c20408":
			var snapshot := sword_snapshot(gs, owner, src)
			view.value = {"attack": int(snapshot.attack), "hp": int(snapshot.hp), "setBase": true}
			view.effects[0].value = view.value.duplicate(true)
			view.formRules.gluttonKeywords = snapshot.keywords.duplicate()
			view.formRules.rpCopiedCharge = bool(snapshot.charge)
			view.formRules.rpCopiedBarrier = bool(snapshot.barrier)
			view.currentCardStats = "当前%d/%d · 继承%s" % [int(snapshot.attack), int(snapshot.hp), "、".join(snapshot.keywords.map(func(k): return Glossary.label(k))) if not snapshot.keywords.is_empty() else "无关键词"]
		"c20403": view.enhanced = all_faction(gs, owner, "红莲")
		"c20407": view.currentCardStats = "当前鼓舞+%d/+%d" % [faction_units(gs, owner, "红莲", true).size() * 2, faction_units(gs, owner, "红莲", true).size() * 2]
		"c20505":
			view.enhanced = all_faction(gs, owner, "紫岩")
			view.currentCardStats = "复活+1/+1/+1甲" + (" · 额外移入战斗区" if view.enhanced else " · 留在准备区")
	return view

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules", {}).get("rpCopiedBarrier", false): gs.player(owner).units[src].barrier = true
	refresh(gs)

static func targets(gs, owner: int, card: Dictionary):
	if str(card.get("id", "")) == "c20403":
		return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and shikigami(u)).map(func(u): return str(u.uid))
	if str(card.get("id", "")) == "c20505":
		return gs.player(owner).units.filter(func(u): return int(u.hp) <= 0 and not u.get("removed", false) and not u.get("summoned", false) and gs.VerifiedRules.Rebirth.can_revive(u)).map(func(u): return str(u.uid))
	return null

static func _heal_overflow(gs, owner: int, target_id: String, amount: int) -> void:
	for side in 2:
		if target_id == "avatar-%d" % side:
			if gs.player(side).get("avatarToxicPoisoned", false): return
			var before := int(gs.player(side).avatarHp)
			gs._heal_avatar(side, amount)
			gs._grant_avatar_armor(side, maxi(0, amount - (int(gs.player(side).avatarHp) - before)))
			return
		var idx: int = gs._unit_index_by_uid(side, target_id)
		if idx < 0: continue
		var unit: Dictionary = gs.player(side).units[idx]
		if unit.get("toxicPoisoned", false): return
		var before := int(unit.hp)
		gs._heal_unit(unit, amount)
		gs._grant_unit_armor(unit, maxi(0, amount - (int(unit.hp) - before)))
		return

static func _fox_targets(gs, owner: int, mode: String) -> Array:
	var ids: Array = []
	for side in [owner, 1 - owner]:
		if mode == FOX_REALM:
			if side != owner and gs.VerifiedRules.ArmorBlood.realm_veil(gs, side): continue
			for realm in gs.player(side).realms:
				if int(realm.hp) > 0: ids.append(str(realm.uid))
		else:
			if side == owner or not gs.VerifiedRules.PipeFox.avatar_veil(gs, side): ids.append("avatar-%d" % side)
			for unit in gs.player(side).units:
				if int(unit.hp) > 0 and not unit.get("removed", false) and (side == owner or not (gs.VerifiedRules.Combat.has(unit, "veil") or gs.VerifiedRules.Movement.has_veil(unit))): ids.append(str(unit.uid))
	return ids

static func _start_fox(gs, owner: int, src: int) -> void:
	var ids: Array = [FOX_HEAL]
	if not _fox_targets(gs, owner, FOX_REALM).is_empty(): ids.append(FOX_REALM)
	gs.pending_choice = {"type": "rp-fox-mode", "playerIndex": owner, "sourceIndex": src, "instanceIds": ids, "heading": "狐 辞", "hint": "选择治疗角色并将过量治疗转为护甲，或增加一个幻境的耐久。"}
	gs.phase = "choice"

static func choice_card(gs, owner: int, id: String):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["rp-fox-mode", "rp-fox-target"] or int(choice.playerIndex) != owner or id not in choice.instanceIds: return null
	if choice.type == "rp-fox-mode":
		return {"id": id, "unitId": "yuanjiulanghu", "name": "治疗角色" if id == FOX_HEAL else "增加耐久", "type": "spell", "typeLabel": "狐辞选择", "level": 0, "cost": 0, "keywords": [], "text": "为一个角色恢复3生命，实际过量治疗转为护甲。" if id == FOX_HEAL else "选择一个真实在场幻境，增加3耐久。"}
	for side in 2:
		if id == "avatar-%d" % side:
			return {"id": id, "unitId": "yuanjiulanghu", "name": "己方牌手" if side == owner else "敌方牌手", "type": "spell", "typeLabel": "角色目标", "level": 0, "cost": 0, "text": "当前%d/%d生命，%d护甲。" % [int(gs.player(side).avatarHp), int(gs.player(side).maxAvatarHp), int(gs.player(side).avatarArmor)]}
		var idx: int = gs._unit_index_by_uid(side, id)
		if idx >= 0:
			var unit: Dictionary = gs.player(side).units[idx]
			return {"id": id, "unitId": str(unit.id), "name": str(unit.name), "type": "spell", "typeLabel": "角色目标", "level": int(unit.level), "cost": 0, "text": "当前%d/%d生命，%d护甲。治疗3，实际过量转为护甲。" % [int(unit.hp), int(unit.maxHp), int(unit.shield)]}
		for realm in gs.player(side).realms:
			if str(realm.uid) == id:
				var view: Dictionary = Content.card_def(str(realm.cardId)).duplicate(true)
				view.id = id; view.name = ("己方·" if side == owner else "敌方·") + str(realm.name)
				view.text = "当前耐久%d，选择后增加3耐久。" % int(realm.hp)
				return view
	return {}

static func resolve_choice(gs, owner: int, id: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["rp-fox-mode", "rp-fox-target"] or int(choice.playerIndex) != owner or id not in choice.instanceIds: return false
	if choice.type == "rp-fox-mode":
		var ids := _fox_targets(gs, owner, id)
		if ids.is_empty(): return false
		gs.pending_choice = {"type": "rp-fox-target", "playerIndex": owner, "sourceIndex": int(choice.sourceIndex), "mode": id, "instanceIds": ids, "heading": "狐 辞 · 选择目标", "hint": "选择一个真实在场幻境增加3耐久。" if id == FOX_REALM else "选择一个存活角色，恢复3生命并将实际过量转为护甲。"}
	else:
		if id not in _fox_targets(gs, owner, str(choice.mode)): return false
		gs.pending_choice = {}; gs.phase = "main"
		if choice.mode == FOX_HEAL: _heal_overflow(gs, owner, id, 3)
		else:
			for p in gs.players:
				for realm in p.realms:
					if str(realm.uid) == id: realm.hp = int(realm.hp) + 3
	gs._record("resolve_divination_choice", {"choice": choice.type, "instanceId": id}, owner)
	gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("rp-"): return false
	var source: Dictionary = gs.player(owner).units[src]
	match action:
		"rp-night-raid", "rp-fox-hand":
			if action == "rp-fox-hand":
				if not source.get("toxicPoisoned", false):
					var before := int(source.hp)
					gs._heal_unit(source, 2)
					_grow(gs, source, maxi(0, 2 - (int(source.hp) - before)), 0)
			var options: Dictionary = card.get("combatOption", {}).duplicate(true)
			options.combatCard = card.duplicate(true)
			if action == "rp-night-raid": options.rpNightRaid = true
			gs._grant_unit_armor(source, int(options.get("shield", 0)))
			gs._record("assault", {"unit": src, "bonus": int(card.value), "target": target_id}, owner)
			gs._resolve_combat(owner, src, int(card.value), false, false, false, false, target_id, false, options)
		"rp-renxia":
			var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, str(target_id))
			if not target.is_empty() and int(target.hp) > 0:
				target.rpPursuit = true; target.rpRenxiaTurn = gs.turn_counter
				if all_faction(gs, owner, "红莲"):
					target.rpRenxiaAttack = int(target.get("rpRenxiaAttack", 0)) + 3
					gs._grow_unit(target, 3, 0)
		"rp-alliance":
			var amount := faction_units(gs, owner, "红莲", true).size() * 2
			gs._apply_encourage(owner, amount, amount)
		"rp-fox-choice": _start_fox(gs, owner, src)
		"rp-revive":
			var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, str(target_id))
			if gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false):
				_grow(gs, target, 1, 1)
				gs._grant_unit_armor(target, 1)
				if all_faction(gs, owner, "紫岩"): gs.VerifiedRules.Movement.move_to(gs, owner, gs._unit_index_by_uid(owner, str(target.uid)), 1)
		"rp-journey": gs.player(owner).rpJourneyStacks = int(gs.player(owner).get("rpJourneyStacks", 0)) + 1
		"rp-awaken":
			source.awakened = true; source.passive_hooks = []
			_grow(gs, source, 1, 1, true)
			if role(source) == "red": source.rpAwakenRedTurn = gs.turn_counter
			refresh(gs)
			gs.VerifiedRules.event(gs, "rp-awaken", {"player": owner, "uid": source.uid, "faction": "红莲" if role(source) == "red" else "紫岩"})
	return true

static func _maximum(gs, owner: int, stat: String) -> bool:
	var ours: Array = gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and shikigami(u))
	if ours.is_empty(): return false
	var maximum := -2147483648
	for unit in gs._all_units():
		if int(unit.hp) > 0 and not unit.get("removed", false) and shikigami(unit): maximum = maxi(maximum, int(unit[stat]))
	return ours.any(func(u): return int(u[stat]) >= maximum)

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	var kind := str(realm.get("nativeRealm", ""))
	if kind not in ["rp-red-maximum", "rp-purple-maximum"]: return false
	if int(realm.hp) > 0 and _maximum(gs, owner, "attack" if kind == "rp-red-maximum" else "hp"):
		gs._draw(owner, 1)
		gs.VerifiedRules.event(gs, "rp-maximum-draw", {"player": owner, "realmUid": realm.uid, "stat": "attack" if kind == "rp-red-maximum" else "hp"})
	return true

static func realm_entered(gs, owner: int, card: Dictionary) -> void:
	if str(card.get("id", "")) in ["c20404", "c20506"] and not gs.player(owner).realms.is_empty(): trigger_realm(gs, owner, gs.player(owner).realms.back())

static func snapshot_exchange(gs, owner: int, src: int, victim: int, idx: int, attack: Dictionary, counter: Dictionary) -> void:
	attack.rpFoxGuard = gs.player(owner).units[src].get("formRules", {}).get("rpFoxGuard", false)
	counter.rpFoxGuard = gs.player(victim).units[idx].get("formRules", {}).get("rpFoxGuard", false)

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if src < 0 or owner != gs.current_player or victim == owner or int(result.get("dealt", result.get("damage", 0))) <= 0: return
	var source: Dictionary = gs.player(owner).units[src]
	if not options.get("rpFoxGuard", source.get("formRules", {}).get("rpFoxGuard", false)): return
	gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, 3)
	if int(source.hp) > 0: gs._grant_unit_armor(source, 3)
	gs.VerifiedRules.event(gs, "rp-guard-break", {"player": owner, "uid": source.uid, "target": "avatar-%d" % victim if idx < 0 else gs.player(victim).units[idx].uid})

static func marks(gs, owner: int, idx: int) -> Array:
	var unit: Dictionary = gs.player(owner).units[idx]
	var marks: Array = []
	if role(unit) == "red":
		marks.append("觉醒红莲光环 · 其他红莲+1/+1" if unit.awakened else "本回合已用%d张红莲牌" % (int(gs.player(owner).get("rpRedCards", 0)) if int(gs.player(owner).get("rpRedCountTurn", -1)) == gs.turn_counter else 0))
	elif role(unit) == "purple": marks.append("觉醒紫岩光环 · 其他紫岩+1/+1" if unit.awakened else "使用其他紫岩牌 · 自身+1生命")
	if unit.get("rpPursuit", false): marks.append("任侠 · 本回合追猎")
	if unit.get("formRules", {}).get("rpMighty", false): marks.append("蛮勇 · 条件力量+%d" % power_bonus(gs, unit))
	if int(gs.player(owner).get("rpJourneyStacks", 0)) > 0 and Factions.get_faction(unit) == "紫岩": marks.append("道行初音旅 · 回合结束永久+%d/+%d" % [int(gs.player(owner).rpJourneyStacks), int(gs.player(owner).rpJourneyStacks)])
	return marks

static func ai_choice(gs, owner: int):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["rp-fox-mode", "rp-fox-target"]: return null
	if int(choice.playerIndex) != owner: return false
	if choice.type == "rp-fox-mode": return resolve_choice(gs, owner, FOX_HEAL)
	var selected := str(choice.instanceIds[0]); var best := -99999
	for id in choice.instanceIds:
		var score := -1000
		if id == "avatar-%d" % owner: score = 20 + mini(3, int(gs.player(owner).maxAvatarHp) - int(gs.player(owner).avatarHp)) * 10
		var idx: int = gs._unit_index_by_uid(owner, str(id))
		if idx >= 0:
			var unit: Dictionary = gs.player(owner).units[idx]
			score = 30 + mini(3, int(unit.maxHp) - int(unit.hp)) * 10 + (5 if int(unit.front) == 1 else 0)
		for realm in gs.player(owner).realms:
			if str(realm.uid) == str(id): score = 50 - int(realm.hp)
		if score > best: selected = str(id); best = score
	return resolve_choice(gs, owner, selected)

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("redPurpleRules", false): return null
	if str(card.id) == "c20403":
		var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, str(target_id))
		return 30 + int(target.get("attack", 0)) * 2
	if str(card.id) == "c20505":
		var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, str(target_id))
		return 70 + int(target.get("attack", 0)) * 2
	if str(card.id) in ["c20406", "c20503"]: return 20 if gs.player(owner).units[gs._source_index(owner, card)].awakened else 60
	if str(card.id) in ["c20405", "c20408", "c20508"]: return int(card.value.attack) * 4 + int(card.value.hp) * 2
	if str(card.id) == "c20509": return 65
	return 40
