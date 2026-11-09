extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const DRAGON := "longjue"
const FLOW := "fengyangjun"
const WINTER := "flow-winter"
const SUMMER := "flow-summer"
const CHANGE := "flow-switch"
const STYLES := ["c65501", "c65502"]

static func source(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})

static func active(gs, owner: int, id: String) -> int:
	var idx := source(gs, owner, id)
	return idx if idx >= 0 and gs.VerifiedRules.OwlInsect.active(gs.player(owner).units[idx]) else -1

static func has_realm(gs, owner: int, id: String) -> bool:
	return not gs.VerifiedRules.DuskCycle.realms(gs, owner, id).is_empty()

static func stance(u: Dictionary) -> String:
	return str(u.get("formRules", {}).get("flowStance", ""))

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id") not in ["c65504", "c65507"]: return null
	return Choice.targetable_shikigami(gs, owner, 1 - owner).map(func(u): return u.uid)

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("breathRules", false) and not card.get("flowRules", false): return card
	var src := source(gs, owner, str(card.unitId))
	if src < 0: return card
	var out := card.duplicate(true)
	var u: Dictionary = gs.player(owner).units[src]
	var dry := int(inst.get("dragonDryCount", 0)) if int(inst.get("dragonDryTurn", -1)) == gs.turn_counter else 0
	match out.id:
		"c65404":
			out.attackBonus = dry
			if int(inst.get("dragonWetTurn", -1)) == gs.turn_counter: out.keywords.append("instant")
			out.currentCardStats = "本回合乾：%d · 坤：%s" % [dry, "已结附" if "instant" in out.keywords else "未结附"]
		"c65408":
			out.breathDamage = 2+dry
			out.breathTargets = 1+int(inst.get("dragonWetCount",0))
			out.currentCardStats = "随机伤害%d · 目标%d" % [out.breathDamage,out.breathTargets]
		"c65501", "c65502":
			if has_realm(gs, owner, "flow-sun"): out.keywords.append("instant")
		"c65504":
			if stance(u) == WINTER: out.keywords.append("instant")
	return out

static func attach(gs, owner: int, src: int, mode: String, coexist: bool = false) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0: return
	if not coexist and not u.get("dragonCoexists", false):
		u.erase("dragonDry")
		u.erase("dragonWet")
	u.dragonLast = mode
	u[mode] = true
	gs.VerifiedRules.event(gs, "dragon-breath-attached", {"player": owner, "uid": u.uid, "mode": mode})
	for inst in gs.player(owner).hand:
		if inst.definitionId not in ["c65404","c65408"]: continue
		var turn_key := mode+"Turn"
		var count_key := mode+"Count"
		if mode == "dragonDry" and int(inst.get(turn_key,-1)) != gs.turn_counter: inst[count_key] = 0
		inst[turn_key] = gs.turn_counter
		inst[count_key] = int(inst.get(count_key,0))+1
	if mode == "dragonDry":
		gs.resolution_stack.append({"kind": "cosmos-breath-dry", "playerIndex": owner, "sourceIndex": src, "awakened": bool(u.awakened)})
	curse_attached(gs, owner, src)

static func curse_attached(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if u.get("formRules", {}).get("breathKill", false) and u.get("dragonDry", false):
		u.dragonSwiftTurn = gs.turn_counter

static func switch_breath(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	attach(gs, owner, src, "dragonDry" if u.get("dragonLast", "") == "dragonWet" else "dragonWet")

static func attach_missing(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not u.get("dragonWet", false): attach(gs, owner, src, "dragonWet", true)
	if not u.get("dragonDry", false): attach(gs, owner, src, "dragonDry", true)

static func upgraded(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if u.id == DRAGON and int(u.level) == 1 and not u.get("baseRulesSuppressed", false): attach(gs, owner, idx, "dragonWet")

static func revived(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if u.id == DRAGON and int(u.level) >= 1: attach(gs, owner, idx, "dragonWet")

static func knocked(u: Dictionary) -> void:
	u.erase("dragonDry")
	u.erase("dragonWet")
	u.erase("dragonLast")
	u.erase("dragonSwiftTurn")
	u.erase("flowIce")

static func turn_start(gs, owner: int) -> void:
	var d := active(gs, owner, DRAGON)
	if d >= 0 and not gs.player(owner).units[d].get("dragonLast", "").is_empty():
		switch_breath(gs, owner, d)
	var src := active(gs, owner, FLOW)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if u.awakened:
		gs.resolution_stack.append({"kind": "cosmos-flow-awake", "playerIndex": owner, "sourceIndex": src})
	elif u.form.is_empty() and not gs.player(owner).hand.any(func(i): return i.definitionId == CHANGE):
		Choice.give(gs, owner, CHANGE)

static func break_gained(gs, owner: int, idx: int) -> void:
	if gs.player(owner).units[idx].id == DRAGON and has_realm(gs, owner, "breath-moon"):
		switch_breath(gs, owner, idx)

static func converts_damage(gs, source_owner: int, src: int, victim: int, idx: int) -> bool:
	var d: Dictionary = {}
	if source_owner >= 0 and src >= 0: d = gs.player(source_owner).units[src]
	var incoming: Dictionary = gs.player(victim).units[idx] if idx >= 0 else {}
	var breath := bool(d.get("dragonDry", false) or d.get("dragonWet", false) or incoming.get("dragonDry", false) or incoming.get("dragonWet", false))
	return breath and gs.VerifiedRules.ArmorBreak.amount(gs, victim, idx) <= 0

static func unit_killed(gs, owner: int, src: int, victim: int, idx: int) -> void:
	if owner < 0 or src < 0 or owner != gs.current_player or owner == victim: return
	if not gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]): return
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0 or not u.get("formRules", {}).get("breathKill", false) or int(u.get("breathKillTurn", -1)) == gs.turn_counter: return
	u.breathKillTurn = gs.turn_counter
	switch_breath(gs, owner, src)

static func attack_started(gs, frame: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if not frame.get("cosmosDragonAttack", false) and u.get("formRules", {}).get("breathAttack", false):
		frame.cosmosDragonAttack = true
		switch_breath(gs, owner, src)

static func attack_combo(gs, frame: Dictionary, victim: int, idx: int) -> bool:
	return idx >= 0 and frame.options.get("combatCard", {}).get("id", "") == "c65503" and gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx])

static func attack_damage(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if owner != victim and idx >= 0 and int(result.get("dealt", 0)) > 0 and options.get("combatCard", {}).get("id", "") == "c65503" and gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]):
		gs._damage_avatar(victim, 2, owner, src)

static func noncombat_bonus(gs, owner: int, src: int, combat: bool) -> int:
	if combat or owner < 0 or src < 0: return 0
	if stance(gs.player(owner).units[src]) != SUMMER: return 0
	return 1+int(has_realm(gs, owner, "flow-sun"))

static func damage_dealt(gs, owner: int, src: int, victim: int, idx: int, dealt: int) -> void:
	if owner < 0 or src < 0 or owner == victim or dealt <= 0 or idx < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	var target: Dictionary = gs.player(victim).units[idx]
	if stance(u) != WINTER or int(target.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(target): return
	if target.get("flowIce", "") == u.uid:
		target.erase("flowIce")
		gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner, src)
	else:
		if gs.VerifiedRules.ZenMisfortune.protect(gs, victim, target, owner): return
		target.flowIce = u.uid
		gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
		gs._grant_unit_armor(u, 1)

static func stunned(gs, victim: int, idx: int) -> void:
	if idx < 0 or not gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]): return
	var owner := 1-victim
	var src := active(gs, owner, FLOW)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if stance(u) == WINTER:
		gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
		gs._grant_unit_armor(u, 1)

static func form_removed(gs, owner: int, src: int, old_rules: Dictionary) -> void:
	if old_rules.get("breathAttack",false): gs.player(owner).units[src].erase("dragonUnyielding")
	if old_rules.get("flowStance", "") != WINTER: return
	var u: Dictionary = gs.player(owner).units[src]
	for target in gs.player(1-owner).units:
		if target.get("flowIce", "") == u.uid: target.erase("flowIce")

static func attach_stance(gs, owner: int, src: int, id: String) -> void:
	var c := Content.card_def(id).duplicate(true)
	gs._push_card_frames(owner, id, null, c, src, 0, true)

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.id not in STYLES: return
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	var saved: Array = p.get("flowRecoverable", [])
	if saved.is_empty(): return
	p.flowRecoverable = []
	for inst in saved: gs.VerifiedRules.Baize.put_hand(gs, owner, inst)

static func random_enemy(gs, owner: int, all_characters: bool = false) -> Array:
	var enemy := 1 - owner
	var units: Array = gs.player(enemy).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false)) if all_characters else Choice.live_units(gs, enemy)
	var foes := units.map(func(u): return str(u.uid))
	if all_characters: foes.append("avatar-%d" % enemy)
	return foes

static func all_damage(gs, owner: int, src: int, amount: int, all_characters: bool = true) -> void:
	for id in random_enemy(gs, owner, all_characters): hit(gs, owner, src, id, amount)

static func hit(gs, owner: int, src: int, target, amount: int) -> Dictionary:
	if str(target).begins_with("avatar-"):
		var dealt: int = gs._damage_avatar(1-owner, amount, owner, src)
		return {"damage": dealt, "dealt": dealt, "knocked": false}
	var idx: int = gs._unit_index_by_uid(1-owner, target)
	return gs._damage_unit(1-owner, idx, amount, owner, src)

static func assault(gs, owner: int, src: int, card: Dictionary, target_id = null) -> void:
	var out := card.duplicate(true)
	var u: Dictionary = gs.player(owner).units[src]
	var extra := 0
	if stance(u) == WINTER and has_realm(gs, owner, "flow-sun"):
		extra = Choice.live_units(gs, 1-owner).filter(func(t): return int(t.frozen) > 0 or t.get("flowIce", "") == u.uid).size()
		out.combatOption.shield = int(out.combatOption.shield)+extra
	gs._resolve_action(owner, src, out, {"action":"assault","value":int(card.get("attackBonus", 0))+extra}, target_id, {})

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id) -> bool:
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	var enemy := 1-owner
	match effect.action:
		"breath-1":
			gs.resolution_stack.append({"kind":"cosmos-assault","playerIndex":owner,"sourceIndex":src,"card":card})
			switch_breath(gs, owner, src)
		"breath-2":
			var amount: int = gs.VerifiedRules.ArmorBreak.consume(gs, owner, src)
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, amount, card.name)
		"breath-3": gs._apply_form(owner, src, card, effect.value)
		"breath-4": assault(gs, owner, src, card)
		"breath-5":
			gs._deploy_realm(owner, card)
			var front: int = gs.front_index(enemy)
			if front >= 0 and gs.VerifiedRules.OwlInsect.shikigami(gs.player(enemy).units[front]):
				gs.VerifiedRules.ArmorBreak.give(gs, owner, src, enemy, front, 2)
			gs.VerifiedRules.ArmorBreak.give(gs, owner, src, owner, src, 2)
		"breath-6":
			if not u.awakened:
				u.dragonCoexists = true
				attach_missing(gs, owner, src)
				gs._awaken(owner, src, card, effect.value)
		"breath-7":
			gs._apply_form(owner, src, card, effect.value)
			u.dragonUnyielding = true
			gs.VerifiedRules.ZenMisfortune.attach_blessing(gs,owner,u)
			attach_missing(gs, owner, src)
		"breath-8":
			gs.resolution_stack.append({"kind":"cosmos-assault","playerIndex":owner,"sourceIndex":src,"card":card})
			for id in Choice.sample(gs, random_enemy(gs, owner, true), int(card.get("breathTargets",1))):
				hit(gs, owner, src, id, int(card.get("breathDamage",2)))
		"flow-1", "flow-2":
			var winter: bool = effect.action == "flow-1"
			var id := WINTER if winter else SUMMER
			gs.resolution_stack.append({"kind":"cosmos-assault","playerIndex":owner,"sourceIndex":src,"card":card})
			if stance(u) != id: attach_stance(gs, owner, src, id)
			elif winter:
				var targets := Choice.sample(gs, random_enemy(gs, owner), 1)
				if not targets.is_empty(): hit(gs, owner, src, targets[0], 1)
			else: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 1, card.name)
		"flow-3": assault(gs, owner, src, card)
		"flow-4":
			hit(gs, owner, src, target_id, 2+int(u.get("spellPower", 0)))
			if stance(u) == SUMMER: gs._damage_avatar(enemy, 1+int(u.get("spellPower", 0)), owner, src)
			gs._draw(owner, 1)
		"flow-5":
			u.swift = true
			gs._awaken(owner, src, card, effect.value)
		"flow-6": gs._deploy_realm(owner, card)
		"flow-7":
			hit(gs, owner, src, target_id, 1+int(u.get("spellPower", 0)))
			var inst: Dictionary = gs.VerifiedRules.Yi.clean_instance(card.get("playedInstance", {}))
			if not inst.is_empty():
				var p: Dictionary = gs.player(owner)
				if not p.has("flowRecoverable"): p.flowRecoverable = []
				p.flowRecoverable.append(inst)
		"flow-8":
			gs.resolution_stack.append({"kind":"cosmos-assault","playerIndex":owner,"sourceIndex":src,"card":card})
			all_damage(gs, owner, src, 1)
		"flow-choice": Choice.offer(gs, owner, "cosmos-flow-card", STYLES, "易势", {"sourceIndex":src})
		"flow-form": gs._apply_form(owner, src, card, effect.value)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	match frame.get("kind", ""):
		"cosmos-assault":
			var src := int(frame.sourceIndex)
			if gs.winner < 0 and int(gs.player(owner).units[src].hp) > 0: assault(gs, owner, src, frame.card)
		"cosmos-breath-dry":
			var src := int(frame.sourceIndex)
			if frame.awakened: all_damage(gs, owner, src, 1)
			else: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2, "龙息之力·乾")
		"cosmos-flow-awake":
			Choice.offer(gs, owner, "cosmos-flow-awake", ["switch", "give"], "觉醒·封阳君", {"sourceIndex":int(frame.sourceIndex)})
		_: return false
	return true

static func choice_card(gs, owner: int, id: String):
	if not Choice.matches(gs, owner, id, "cosmos-flow"): return null
	if id in STYLES: return Content.card_def(id)
	if id == "switch": return Choice.face(id, "切换流派", "切换封阳君的形态，若没有形态则随机结附一项。")
	return Content.card_def(CHANGE)

static func resolve_choice(gs, owner: int, id: String) -> bool:
	if not Choice.matches(gs, owner, id, "cosmos-flow"): return false
	var choice := Choice.accept(gs, owner, id)
	var src := int(choice.sourceIndex)
	if choice.type == "cosmos-flow-card":
		var card: Dictionary = describe(gs, owner, {}, Content.card_def(id))
		gs._push_card_frames(owner, id, null, card, src, 0, true)
	elif id == "give": Choice.give(gs, owner, CHANGE)
	else:
		var current := stance(gs.player(owner).units[src])
		var next := SUMMER if current == WINTER else WINTER
		if current.is_empty() and gs.next_random() % 2 == 0: next = SUMMER
		attach_stance(gs, owner, src, next)
	Choice.finish(gs)
	return true
