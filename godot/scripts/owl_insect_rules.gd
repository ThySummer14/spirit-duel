class_name OwlInsectRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func role(unit: Dictionary) -> String:
	return str(Content.runtime_unit_def(unit).get("owlInsectRole", ""))

static func shikigami(unit: Dictionary) -> bool:
	return not unit.get("removed", false) and (not unit.get("summoned", false) or unit.get("countsAsShikigami", false))

static func guarded(unit: Dictionary) -> bool:
	return int(unit.get("hp",0)) > 0 and not unit.get("owlGuard", {}).is_empty()

static func owner_of(gs, unit: Dictionary) -> int:
	for owner in gs.players.size():
		if gs._unit_index_by_uid(owner,str(unit.uid)) >= 0: return owner
	return -1

static func aura_sources(gs, owner: int, key: String) -> Array:
	return gs.player(owner).units.filter(func(u): return active(u) and u.get("formRules",{}).get(key,false))

static func power(gs, unit: Dictionary) -> int:
	var owner := owner_of(gs,unit)
	return aura_sources(gs,owner,"owlClaw").size()*2 if owner >= 0 and guarded(unit) else 0

static func refresh(gs) -> void:
	gs.VerifiedRules.RedPurple.refresh(gs)
	gs.VerifiedRules.ChargedPair.refresh(gs)
	for owner in gs.players.size():
		for unit in gs.player(owner).units:
			var bonus := power(gs,unit)
			var old := int(unit.get("owlPower",0))
			unit.owlPower = bonus
			unit.owlVeil = guarded(unit) and not aura_sources(gs,owner,"owlVeil").is_empty()
			var stamp := ""
			if guarded(unit):
				for source in aura_sources(gs,owner,"owlUnyielding"):
					stamp += "%s:%d:%d;" % [source.uid,int(source.get("formInstalledOrder",0)),int(unit.owlGuard.serial)]
			if stamp != str(unit.get("owlUnyieldingStamp","")):
				unit.owlUnyieldingStamp = stamp; unit.owlUnyielding = not stamp.is_empty()
			if bonus != old: gs._recalc(unit)

static func attach_guard(gs, owner: int, src: int, idx: int) -> void:
	if idx < 0 or idx >= gs.player(owner).units.size(): return
	var target: Dictionary = gs.player(owner).units[idx]
	if int(target.hp) <= 0 or not shikigami(target): return
	var all_units := bool(gs.player(owner).get("owlAll",false))
	if not all_units:
		for unit in gs.player(owner).units: unit.erase("owlGuard")
	for i in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[i]
		if (not all_units and i != idx) or int(unit.hp) <= 0 or not shikigami(unit): continue
		unit.owlGuard = {"owner":owner,"sourceUid":gs.player(owner).units[src].uid,"serial":gs.next_rule_event_id}
		gs.VerifiedRules.event(gs,"owl-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":unit.uid})
	refresh(gs)

static func reduced(unit: Dictionary, amount: int) -> int:
	return maxi(0,amount-(1 if guarded(unit) else 0))

static func prevents_damage(gs, target: Dictionary, owner: int, src: int) -> bool:
	return guarded(target) and owner >= 0 and src >= 0 and int(gs.player(owner).units[src].get("owlBlockedTurn",-1)) == gs.turn_counter

static func attack_started(gs, owner: int, src: int) -> void:
	var attacker: Dictionary = gs.player(owner).units[src]
	if not shikigami(attacker): return
	gs.player(owner).owlLastAttack = {"uid":attacker.uid,"turn":gs.turn_counter}
	for i in gs.player(owner).units.size():
		var source: Dictionary = gs.player(owner).units[i]
		if role(source) == "owl" and active(source) and source.awakened: attach_guard(gs,owner,i,src)

static func form_turn_start(gs, owner: int, idx: int) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if not active(unit) or not unit.get("formRules",{}).get("owlResolve",false): return
	for target in gs.player(owner).units:
		if guarded(target) and shikigami(target):
			target.owlResolveHp = int(target.get("owlResolveHp",0))+1
			gs._grow_unit(target,0,1)

static func corrode(gs, owner: int, src: int, victim: int, idx: int, amount: int, bonus: bool = true, earned: bool = false) -> void:
	if idx < 0 or idx >= gs.player(victim).units.size() or gs.winner >= 0: return
	var unit: Dictionary = gs.player(victim).units[idx]
	if int(unit.hp) <= 0 or not shikigami(unit): return
	var source: Dictionary = gs.player(owner).units[src]
	if bonus and (active(source) or earned) and role(source) == "insect" and source.awakened: amount += 1
	if amount <= 0: return
	if not unit.has("insectCorrosionOwners"): unit.insectCorrosionOwners={}
	unit.insectCorrosionOwners[str(owner)]=int(unit.insectCorrosionOwners.get(str(owner),0))+amount
	unit.insectCorrosion = int(unit.get("insectCorrosion",0))+amount
	unit.hp = maxi(0,int(unit.hp)-amount)
	gs._recalc(unit)
	gs.VerifiedRules.event(gs,"insect-attached",{"player":owner,"uid":source.uid,"target":unit.uid,"victimPlayer":victim,"amount":amount,"total":unit.insectCorrosion})
	if int(unit.hp) <= 0: gs._knockout_unit(unit,owner,src)

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary) -> void:
	if idx < 0 or int(result.get("dealt",0)) <= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if role(unit) == "insect" and int(unit.level) > 0 and not unit.get("baseRulesSuppressed",false): corrode(gs,owner,src,victim,idx,1,true,true)

static func prison_source(gs) -> Dictionary:
	# Current player has priority when both players own a prison.
	for owner in [gs.current_player,1-gs.current_player]:
		for realm in gs.player(owner).realms:
			if int(realm.hp) <= 0 or realm.get("nativeRealm") != "insect-prison": continue
			var idx: int = gs._source_index(owner,Content.card_def(str(realm.cardId)))
			if idx >= 0: return {"owner":owner,"src":idx}
	return {}

static func replace_damage(gs, victim: int, idx: int, amount: int) -> bool:
	if not shikigami(gs.player(victim).units[idx]): return false
	var source := prison_source(gs)
	if source.is_empty(): return false
	var cap := int(gs.player(victim).units[idx].get("formRules",{}).get("damageCap",0))
	if cap>0: amount = mini(amount,cap)
	corrode(gs,int(source.owner),int(source.src),victim,idx,amount)
	gs.VerifiedRules.event(gs,"insect-damage-replaced",{"player":source.owner,"victimPlayer":victim,"target":gs.player(victim).units[idx].uid,"amount":amount})
	return true

static func knockout_snapshot(gs, victim: int, unit: Dictionary) -> Dictionary:
	var count := int(unit.get("insectCorrosion",0))
	var frames: Array = []
	if count > 0:
		for idx in gs.player(1-victim).units.size():
			var source: Dictionary = gs.player(1-victim).units[idx]
			if not active(source): continue
			if source.get("formRules",{}).get("insectDeathDraw",false): frames.append({"kind":"owl-insect-death-draw","playerIndex":1-victim,"sourceIndex":idx})
			if source.get("formRules",{}).get("insectDeathHeal",false): frames.append({"kind":"owl-insect-death-heal","playerIndex":1-victim,"sourceIndex":idx,"amount":count*2})
		for bomb in unit.get("insectBombs",[]):
			if int(bomb.turn) != gs.turn_counter: continue
			frames.append({"kind":"owl-insect-transfer","playerIndex":int(bomb.owner),"sourceUid":bomb.sourceUid,"victim":victim,"count":count,"excluded":unit.uid})
	return {"frames":frames}

static func knocked_out(unit: Dictionary) -> void:
	unit.maxHpBonus = int(unit.maxHpBonus)-int(unit.get("owlResolveHp",0))
	unit.erase("owlResolveHp")
	for key in ["owlGuard","owlBlockedTurn","owlUnyielding","owlUnyieldingStamp","owlVeil","insectCorrosion","insectCorrosionOwners","insectBombs"]: unit.erase(key)

static func after_knockout(gs, saved: Dictionary) -> void:
	var frames: Array = saved.get("frames",[]); frames.reverse(); gs.resolution_stack.append_array(frames)
	refresh(gs)

static func end_turn(gs, current: int) -> void:
	var frames: Array = []
	for idx in gs.player(current).units.size():
		var source: Dictionary = gs.player(current).units[idx]
		if active(source) and role(source) == "owl" and not source.awakened:
			var last: Dictionary = gs.player(current).get("owlLastAttack",{})
			if int(last.get("turn",-1)) == gs.turn_counter: frames.append({"kind":"owl-insect-end-guard","playerIndex":current,"sourceIndex":idx,"target":str(last.uid)})
	for owner in [current,1-current]:
		for realm in gs.player(owner).realms:
			if int(realm.hp)>0 and realm.get("nativeRealm") == "insect-prison": frames.append({"kind":"owl-insect-prison-end","playerIndex":owner,"sourceIndex":gs._source_index(owner,Content.card_def(str(realm.cardId)))})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func expire_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			unit.erase("owlBlockedTurn")
			unit.erase("insectBombs")

static func describe_card(_gs, _owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("insectReturn",false): return card
	var out := card.duplicate(true)
	out.insectInstance = inst.duplicate(true)
	if not inst.get("insectReturned",false): out.text += "\n使用后原牌回手，此能力限一次。"
	else: out.text += "\n此原牌已回手过，不再回手。"
	return out

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("insectReturn",false) or card.get("insectInstance",{}).get("insectReturned",false): return
	var after := {"kind":"owl-insect-return","playerIndex":int(frame.playerIndex),"resolutionId":int(frame.resolutionId),"card":card.duplicate(true)}
	for i in gs.resolution_stack.size():
		var pending: Dictionary = gs.resolution_stack[i]
		if pending.get("kind") == "card-complete" and int(pending.get("resolutionId",-1))==int(frame.resolutionId):
			gs.resolution_stack.insert(i,after)
			return

static func targets(gs, owner: int, card: Dictionary):
	var rule := str(card.get("owlInsectRule",""))
	if rule not in ["guard","protection","interfere","seed","breed","devour","bomb"]: return null
	var out: Array = []
	var sides: Array = [owner] if rule in ["guard","protection"] else ([owner,1-owner] if rule in ["interfere","devour"] else [1-owner])
	for side in sides:
		for unit in gs.player(side).units:
			if int(unit.hp)<=0 or not shikigami(unit): continue
			if rule == "devour" and int(unit.get("insectCorrosion",0))<=0: continue
			if side != owner and (gs.VerifiedRules.Combat.has(unit,"veil") or gs.VerifiedRules.Movement.has_veil(unit)): continue
			out.append(str(unit.uid))
	return out

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if not kind.begins_with("owl-insect-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex",-1))
	var context: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	match kind:
		"owl-insect-return":
			var card: Dictionary = frame.card
			var inst: Dictionary = card.get("insectInstance",{}).duplicate(true)
			if inst.is_empty():
				inst = {"definitionId":card.id,"instanceId":"insect-return-%d" % gs.next_card_id}
				gs.next_card_id += 1
			inst.insectReturned = true
			if gs.player(owner).hand.size()<int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
			else: gs._log("手牌已满，回手的施蛊被烧毁。",gs.TONE_DANGER)
			gs.VerifiedRules.event(gs,"insect-card-returned",{"player":owner,"instanceId":inst.instanceId})
		"owl-insect-end-guard":
			if active(gs.player(owner).units[src]): attach_guard(gs,owner,src,gs._unit_index_by_uid(owner,str(frame.target)))
		"owl-insect-death-draw": gs._draw(owner,1)
		"owl-insect-death-heal": gs._heal_avatar(owner,int(frame.amount))
		"owl-insect-transfer":
			src = gs._unit_index_by_uid(owner,str(frame.sourceUid))
			var victim := int(frame.victim)
			var pool: Array = gs.player(victim).units.filter(func(u):return int(u.hp)>0 and shikigami(u) and str(u.uid)!=str(frame.excluded))
			if src >= 0 and not pool.is_empty():
				var unit: Dictionary = pool[int(floor(gs.randf01()*pool.size()))]
				corrode(gs,owner,src,victim,gs._unit_index_by_uid(victim,str(unit.uid)),int(frame.count),false)
		"owl-insect-prison-end":
			var victims: Array = []
			for side in [owner,1-owner]:
				for unit in gs.player(side).units:
					if int(unit.hp)>0 and shikigami(unit) and int(unit.attack)<=0: victims.append({"owner":side,"uid":unit.uid})
			for entry in victims:
				var idx: int = gs._unit_index_by_uid(int(entry.owner),str(entry.uid))
				if idx >= 0: gs.VerifiedRules.Panguan.destroy(gs,owner,src,int(entry.owner),idx)
		_: gs._card_effect_context = context; return false
	gs._card_effect_context = context
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var action := str(effect.get("action",""))
	if not action.begins_with("owl-insect-"): return false
	var side := owner if not target.is_empty() and gs._unit_index_by_uid(owner,str(target.uid)) >= 0 else 1-owner
	var idx: int = -1 if target.is_empty() else gs._unit_index_by_uid(side,str(target.uid))
	match action:
		"owl-insect-guard": attach_guard(gs,owner,src,idx)
		"owl-insect-interfere":
			if idx >= 0 and int(target.hp)>0:
				gs._damage_unit(side,idx,1,owner,src)
				if int(target.hp)>0: target.owlBlockedTurn = gs.turn_counter
		"owl-insect-wings": gs.player(owner).owlAll = true
		"owl-insect-awaken": gs._awaken(owner,src,card,effect.value); refresh(gs)
		"owl-insect-seed":
			if idx >= 0: corrode(gs,owner,src,side,idx,1)

		"owl-insect-breed":
			if idx >= 0:
				var others: Array = gs.player(side).units.filter(func(u):return str(u.uid)!=str(target.uid) and int(u.hp)>0 and int(u.get("insectCorrosion",0))>0).map(func(u):return str(u.uid))
				corrode(gs,owner,src,side,idx,2)
				for uid in others: corrode(gs,owner,src,side,gs._unit_index_by_uid(side,uid),1)
		"owl-insect-devour":
			if idx >= 0 and int(target.get("insectCorrosion",0))>0: gs.VerifiedRules.Panguan.destroy(gs,owner,src,side,idx,card)
		"owl-insect-bomb":
			if idx >= 0 and int(target.hp)>0:
				var bombs: Array = target.get("insectBombs",[])
				bombs.append({"turn":gs.turn_counter,"owner":owner,"sourceUid":gs.player(owner).units[src].uid}); target.insectBombs = bombs
				corrode(gs,owner,src,side,idx,3)
		"owl-insect-prison":
			gs._deploy_realm(owner,card)
			var pool: Array = gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.get("insectCorrosion",0))>0).map(func(u):return str(u.uid))
			for uid in pool:
				if gs.winner >= 0: break
				gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,uid),1,owner,src)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	var rule := str(card.get("owlInsectRule",""))
	if rule.is_empty(): return null
	var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units,target_id)
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1-owner).units,target_id)
	match rule:
		"guard": return 60+int(ally.attack)*2 if not ally.is_empty() and not guarded(ally) else -100
		"interfere": return 50+int(enemy.attack)*3 if not enemy.is_empty() else -100
		"wings": return 80 if not gs.player(owner).get("owlAll",false) else -100
		"seed", "breed", "bomb": return 65+int(enemy.attack)*2 if not enemy.is_empty() else -100
		"devour": return 85+int(enemy.attack)*3 if not enemy.is_empty() else -100
		"prison": return 65 if gs.player(1-owner).units.any(func(u):return int(u.get("insectCorrosion",0))>0) else 20
		_: return 45
