class_name MonkCleanerRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func role(unit: Dictionary) -> String:
	return str(Content.runtime_unit_def(unit).get("monkCleanerRole", ""))

static func owner_of(gs, unit: Dictionary) -> int:
	for owner in gs.players.size():
		if gs._unit_index_by_uid(owner, str(unit.uid)) >= 0: return owner
	return -1

static func bath(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == "cleaner-bath")

static func aura_power(gs, unit: Dictionary) -> int:
	if unit.get("summoned",false) and not unit.get("countsAsShikigami",false): return 0
	var owner := owner_of(gs, unit)
	return 1 if owner >= 0 and int(unit.hp) > 0 and int(unit.shield) > 0 and bath(gs, owner) else 0

static func armor_changed(gs, unit: Dictionary) -> void:
	var amount := aura_power(gs, unit)
	var before := int(unit.get("cleanerAuraPower", 0))
	unit.cleanerAuraPower = amount
	unit.cleanerVeil = amount > 0
	if before != amount: gs._recalc(unit)

static func refresh(gs) -> void:
	for p in gs.players:
		for unit in p.units: armor_changed(gs, unit)

static func armor_gained(gs, unit: Dictionary, amount: int) -> void:
	if amount <= 0 or not active(unit) or role(unit) != "cleaner" or int(unit.frozen) > 0 or not unit.get("form", {}).is_empty(): return
	var owner := owner_of(gs, unit)
	if owner < 0: return
	if gs.player(owner).hand.any(func(i): return Content.card_def(str(i.definitionId)).get("cleanerSnow", false)):
		gs.resolution_stack.append({"kind":"shell-snow-auto", "playerIndex":owner,"sourceUid":unit.uid})

static func enrage(gs, owner: int, idx: int) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if int(unit.hp) <= 0: return
	unit.enraged = true
	gs.VerifiedRules.event(gs,"enrage-gained",{"player":owner,"uid":unit.uid})

static func dealt(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> void:
	if amount <= 0 or src < 0 or owner < 0 or idx < 0 or owner == victim: return
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.get("monkEnrageTurn",-1)) == gs.turn_counter: enrage(gs,victim,idx)

static func reduced(unit: Dictionary, amount: int) -> int:
	return maxi(0,amount - int(unit.get("formRules",{}).get("monkReduction",0)))

static func redirect(gs, victim: int, idx: int, amount: int, owner: int, src: int, combat: bool, critical: bool = false):
	if amount <= 0 or gs.winner >= 0: return null
	var original := "avatar-%d" % victim if idx < 0 else str(gs.player(victim).units[idx].uid)
	for i in gs.player(victim).units.size():
		var unit: Dictionary = gs.player(victim).units[i]
		var mode := str(unit.get("formRules",{}).get("monkCover",""))
		if i == idx or not active(unit) or str(unit.uid) in gs._shell_redirect_chain: continue
		if mode != "all" and not (mode == "avatar-combat" and idx < 0 and combat): continue
		var old: Array = gs._shell_redirect_chain
		gs._shell_redirect_chain = old.duplicate(); gs._shell_redirect_chain.append(original); gs._shell_redirect_chain.append(str(unit.uid))
		var result: Dictionary = gs._damage_unit(victim,i,amount,owner,src,combat,-1,false,critical,true)
		gs._shell_redirect_chain = old
		result = result.duplicate(true)
		result.redirected = true; result.redirectedIndex = int(result.get("redirectedIndex",i)); result.redirectedTarget = str(gs.player(victim).units[result.redirectedIndex].uid)
		gs.VerifiedRules.event(gs,"monk-damage-redirected",{"player":victim,"uid":unit.uid,"target":original,"amount":amount,"combat":combat})
		return result
	return null

static func special_damage(gs, victim: int, idx: int, amount: int, owner: int, src: int, combat: bool):
	if amount <= 0 or combat or owner < 0 or src < 0: return null
	var unit: Dictionary = gs.player(owner).units[src]
	var bonus := int(unit.get("formRules",{}).get("monkNoncombatBonus",0))
	if bonus <= 0: return null
	return projectile_hit(gs,owner,src,victim,idx,amount+bonus,true)

static func projectile_hit(gs, owner: int, src: int, victim: int, idx: int, amount: int, pierce: bool) -> Dictionary:
	if idx < 0: return {"damage":gs._damage_avatar(victim,amount,owner,src,false,false,true),"overkill":0}
	var target: Dictionary = gs.player(victim).units[idx]
	var overflow := maxi(0,amount+int(target.armorBreak)-int(target.shield)-int(target.hp)) if pierce else 0
	var result: Dictionary = gs._damage_unit(victim,idx,amount,owner,src,false,-1,false,false,true)
	if overflow > 0 and not result.get("redirected",false) and gs.winner < 0:
		gs._damage_avatar(victim,overflow,owner,src,false,false,true)
	return result

static func damaged(gs, victim: int, idx: int, owner: int, src: int, amount: int, combat: bool) -> void:
	if amount <= 0: return
	var unit: Dictionary = gs.player(victim).units[idx]
	var kind := role(unit)
	if kind == "monk" and int(unit.level) > 0:
		unit.monkDamageTotal = int(unit.get("monkDamageTotal",0)) + amount
		if combat and owner >= 0 and owner != victim and src >= 0:
			var bonus := int(unit.get("formRules",{}).get("monkNoncombatBonus",0))
			var reaction := {"kind":"shell-projectile","playerIndex":victim,"sourceIndex":idx,"amount":(3 if unit.awakened else 2)+bonus,"pierce":bonus>0,"opponentUid":gs.player(owner).units[src].uid,"enrage":int(unit.get("monkEnrageTurn",-1)) == gs.turn_counter}
			if gs._shell_in_exchange: gs._shell_reactions.append(reaction)
			else: resolve_frame(gs,reaction)
	elif kind == "cleaner" and active(unit):
		var reaction := {"kind":"shell-armor","playerIndex":victim,"sourceUid":unit.uid,"amount":amount}
		if gs._shell_in_exchange: gs._shell_reactions.append(reaction)
		else: resolve_frame(gs,reaction)

static func begin_exchange(gs) -> void:
	gs._shell_reaction_stack.append({"reactions":gs._shell_reactions,"inExchange":gs._shell_in_exchange})
	gs._shell_reactions = []
	gs._shell_in_exchange = true

static func flush_exchange(gs) -> void:
	if gs._shell_reaction_stack.is_empty(): return
	gs._shell_in_exchange = false
	var reactions: Array = gs._shell_reactions
	var depth: int = gs.resolution_stack.size()
	gs._shell_reactions = []
	# 小僧投射在垢尝的受伤护甲之前；每次交战结束即结算，不推迟到连击末尾。
	var context: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	for kind in ["shell-projectile","shell-armor","bamboo-rat"]:
		for reaction in reactions:
			if reaction.kind == kind and gs.winner < 0:
				if kind=="bamboo-rat": gs.VerifiedRules.Bamboo.resolve_frame(gs,reaction)
				else: resolve_frame(gs,reaction)
	gs._resolve_inline_frames(depth)
	gs._card_effect_context = context
	var previous: Dictionary = gs._shell_reaction_stack.pop_back()
	gs._shell_reactions = previous.reactions
	gs._shell_in_exchange = bool(previous.inExchange)

static func form_entered(gs, owner: int, idx: int, card: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if card.get("cleanerSnow",false):
		var inst: Dictionary = card.get("cleanerInstance",{}).duplicate(true)
		if inst.is_empty():
			inst = {"definitionId":card.id,"instanceId":"shell-form-%d" % gs.next_card_id}; gs.next_card_id += 1
		unit.snowInstance = inst
	unit.monkFormUnyielding = bool(unit.get("formRules",{}).get("monkUnyielding",false))
	refresh(gs)

static func knockout_snapshot(unit: Dictionary) -> Dictionary:
	return unit.get("snowInstance",{}).duplicate(true) if role(unit) == "cleaner" and unit.get("formRules",{}).get("cleanerSnowReturn",false) and not unit.get("baseRulesSuppressed",false) else {}

static func after_knockout(gs, owner: int, idx: int, saved: Dictionary) -> void:
	if saved.is_empty() or gs.winner >= 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	gs.VerifiedRules.Peach.revive(gs, owner, idx, unit, false, false)
	saved.snowPower = int(saved.get("snowPower",0)) + 2
	if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(saved)
	else: gs._log("手牌已满，回手的阶前雪被烧毁。",gs.TONE_DANGER)
	gs.VerifiedRules.event(gs,"cleaner-snow-return",{"player":owner,"uid":unit.uid,"instanceId":saved.instanceId,"power":saved.snowPower})
	refresh(gs)

static func end_turn(gs, _owner: int) -> void:
	var frames: Array = []
	for owner in gs.players.size():
		for idx in gs.player(owner).units.size():
			var unit: Dictionary = gs.player(owner).units[idx]
			if not active(unit): continue
			if unit.get("formRules",{}).get("monkFullHealEnd",false): frames.append({"kind":"shell-end-heal","playerIndex":owner,"sourceUid":unit.uid})
			if unit.get("formRules",{}).get("cleanerArmorShot",false): frames.append({"kind":"shell-end-armor-shot","playerIndex":owner,"sourceUid":unit.uid})
	frames.reverse()
	gs.resolution_stack.append_array(frames)

static func expire_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if int(unit.get("monkEnrageTurn",-1)) == gs.turn_counter: unit.erase("monkEnrageTurn")

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("monkCleanerRules",false): return card
	var out := card.duplicate(true)
	var idx: int = gs._source_index(owner,card)
	if idx < 0: return out
	var unit: Dictionary = gs.player(owner).units[idx]
	if card.get("cleanerArmorInstant",false) and int(unit.shield) > 0: out.keywords.append("instant"); out.enhanced = true
	if card.get("cleanerArmorLethal",false) and int(unit.shield) > 0: out.combatOption.lethal = true; out.enhanced = true
	if card.get("monkFury",false):
		var count := int(unit.get("monkDamageTotal",0))
		var bonus := 6 if count >= 20 else 2
		out.formRules.monkNoncombatBonus = bonus
		out.currentCardStats = "已受伤 %d/20 · 非战斗伤害+%d" % [count,bonus]
		out.enhanced = count >= 20
	if card.get("cleanerSnow",false):
		out.cleanerInstance = inst.duplicate(true)
		out.value.attack = 6 + int(inst.get("snowPower",0)); out.effects[0].value = out.value.duplicate(true)
		out.currentCardStats = "当前面板 %d/5" % out.value.attack
	if card.effect == "cleaner-basket":
		var total := mini(2,int(gs.player(owner).avatarArmor))
		for ally in gs.player(owner).units:
			if int(ally.hp) > 0: total += mini(2,int(ally.shield))
		out.currentCardStats = "当前攻击加成 +%d" % total
	return out

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.effect != "monk-alms": return true
	var idx: int = gs._source_index(owner,card)
	return idx >= 0 and not gs.VerifiedRules.Combat.has(gs.player(owner).units[idx],"remote") and not gs.VerifiedRules.Bingyong.replacement_blocked(gs,owner,gs.player(owner).units[idx])

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action","")):
		"monk-alms":
			if target.is_empty(): return true
			gs.resolution_stack.append({"kind":"shell-forced-attack","playerIndex":1-owner,"sourceUid":target.uid})
			gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
		"monk-stone":
			if not target.is_empty():
				var victim := owner_of(gs,target)
				var idx: int = gs._unit_index_by_uid(victim,target.uid)
				gs._damage_unit(victim,idx,1,owner,src)
				enrage(gs,victim,idx)
		"monk-statue":
			gs.player(owner).units[src].monkEnrageTurn = gs.turn_counter
			gs._resolve_combat(owner,src,1,false,false,false,false)
		"shell-awaken":
			gs._awaken(owner,src,card,effect.value)
			if role(gs.player(owner).units[src]) == "cleaner": gs.player(owner).units[src].unyielding = true
		"cleaner-shine":
			var depth: int = gs.resolution_stack.size()
			for side in gs.players.size():
				gs._grant_avatar_armor(side,1)
				for unit in gs.player(side).units: gs._grant_unit_armor(unit,1)
			# 先完成获得护甲的自动使用，再结算抽牌。
			gs.resolution_stack.insert(depth,{"kind":"charm-extra-draw","playerIndex":owner,"count":1})
		"cleaner-basket":
			var p: Dictionary = gs.player(owner)
			var bonus := mini(2,int(p.avatarArmor)); p.avatarArmor = int(p.avatarArmor)-bonus
			for unit in p.units:
				if int(unit.hp) <= 0: continue
				var removed := mini(2,int(unit.shield)); unit.shield = int(unit.shield)-removed
				unit.shieldExpires = maxi(0,int(unit.get("shieldExpires",0))-removed)
				bonus += removed; gs.VerifiedRules.ArmorBlood.armor_changed(gs,unit)
			gs._resolve_combat(owner,src,bonus,false,false,false,false)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex",0))
	match str(frame.get("kind","")):
		"shell-forced-attack":
			var idx: int = gs._unit_index_by_uid(owner,str(frame.sourceUid))
			if idx >= 0: gs._resolve_combat(owner,idx,0,false,false,false,false)
		"shell-projectile":
			var enemy := 1-owner
			var idx: int = gs.front_index(enemy)
			var foe: int = gs._unit_index_by_uid(enemy,str(frame.opponentUid))
			if idx < 0 and (foe < 0 or int(gs.player(enemy).units[foe].hp) > 0): return true
			var card := {"id":"monk-projection","unitId":gs.player(owner).units[int(frame.sourceIndex)].id,"name":"独眼小僧·投射","type":"ability","text":"投射：造成%d点伤害。" % int(frame.amount)}
			gs.VerifiedRules.event(gs,"ability-trigger",{"player":owner,"uid":gs.player(owner).units[int(frame.sourceIndex)].uid,"card":card,"amount":int(frame.amount)})
			var old_context: Dictionary=gs._card_effect_context; gs._card_effect_context={}
			projectile_hit(gs,owner,int(frame.sourceIndex),enemy,idx,int(frame.amount)+gs.VerifiedRules.ApeSleeve.base_damage_bonus(gs,owner),bool(frame.pierce))
			gs._card_effect_context=old_context
			if frame.enrage and idx >= 0: enrage(gs,enemy,idx)
		"shell-armor":
			var idx: int = gs._unit_index_by_uid(owner,str(frame.sourceUid))
			if idx >= 0 and active(gs.player(owner).units[idx]): gs._grant_unit_armor(gs.player(owner).units[idx],int(frame.amount))
		"shell-end-heal", "shell-end-armor-shot":
			var idx: int = gs._unit_index_by_uid(owner,str(frame.sourceUid))
			if idx < 0 or not active(gs.player(owner).units[idx]): return true
			var unit: Dictionary = gs.player(owner).units[idx]
			if frame.kind == "shell-end-heal": gs._heal_unit(unit,int(unit.maxHp))
			else:
				var amount := mini(5,int(unit.shield)); unit.shield = int(unit.shield)-amount
				unit.shieldExpires = maxi(0,int(unit.get("shieldExpires",0))-amount)
				gs.VerifiedRules.ArmorBlood.armor_changed(gs,unit)
				if amount > 0: projectile_hit(gs,owner,idx,1-owner,gs.front_index(1-owner),amount,false)
		"shell-snow-auto":
			var idx: int = gs._unit_index_by_uid(owner,str(frame.sourceUid))
			if idx < 0: return true
			var unit: Dictionary = gs.player(owner).units[idx]
			if not active(unit) or role(unit) != "cleaner" or int(unit.frozen) > 0 or int(unit.level) < 3 or not unit.get("form",{}).is_empty(): return true
			var hand: Array = gs.player(owner).hand
			for i in hand.size():
				if not Content.card_def(str(hand[i].definitionId)).get("cleanerSnow",false): continue
				var card: Dictionary = gs.hand_card_def(owner,i)
				hand.remove_at(i); gs.player(owner).cardsPlayedThisTurn = int(gs.player(owner).cardsPlayedThisTurn)+1
				gs._push_card_frames(owner,str(card.id),null,card,idx,gs.MAX_RESPONSE_DEPTH)
				gs.VerifiedRules.event(gs,"cleaner-snow-auto",{"player":owner,"uid":unit.uid,"card":card})
				break
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("monkCleanerRules",false): return null
	var src: int = gs._source_index(owner,card)
	var unit: Dictionary = gs.player(owner).units[src]
	if card.get("awakening",false): return -100 if unit.awakened else 80
	if card.type == "form": return -100 if unit.get("form",{}).get("cardId") == card.id else 75
	if card.effect == "monk-stone": return 45 if not gs._unit_by_uid(gs.player(1-owner).units,target_id).is_empty() else -100
	if card.effect == "monk-alms": return 65 if not gs._unit_by_uid(gs.player(1-owner).units,target_id).is_empty() else -100
	return 65
