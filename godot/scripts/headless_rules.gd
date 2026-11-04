class_name HeadlessRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("headlessRules",false))
static func active(u: Dictionary) -> bool:
	return source(u) and int(u.hp)>0 and int(u.level)>0
static func eligible(inst: Dictionary) -> bool:
	return bool(Content.card_def(str(inst.get("definitionId",""))).get("headlessReturn",false))
static func track_zones(gs, owner: int) -> void:
	var p: Dictionary=gs.player(owner)
	if not p.has("headlessInstances"): p.headlessInstances={}
	for zone in ["hand","deck"]:
		for inst in p[zone]:
			if eligible(inst): p.headlessInstances[str(inst.instanceId)]=inst
static func initialize(gs) -> void:
	for owner in gs.players.size(): track_zones(gs,owner)
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("headlessRules",false): return card
	var out:=card.duplicate(true)
	if card.get("headlessReturn",false): out.headlessInstance=inst.duplicate(true)
	if card.get("headlessNightPower",false):
		out.value=int(gs.VerifiedRules.Maple.night_value(gs,owner)/2)
		out.effects[0].value=out.value
		out.currentCardStats="当前战斗 +%d力量 · 入夜%d/10" % [out.value,gs.VerifiedRules.Maple.night_value(gs,owner)]
	if card.get("type")=="form": out.currentCardStats="当前%d/%d" % [int(out.value.attack),int(out.value.hp)]
	return out
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner:=int(frame.playerIndex); var p: Dictionary=gs.player(owner)
	if card.get("type")=="combat":
		if not p.has("headlessCombatHistory"): p.headlessCombatHistory=[]
		# History contains actual announced uses, including countered cards. A
		# definition is a possible result once, independent of its use count.
		if not p.headlessCombatHistory.has(str(card.id)): p.headlessCombatHistory.append(str(card.id))
	var inst: Dictionary=card.get("headlessInstance",{})
	if not inst.is_empty() and eligible(inst):
		if not p.has("headlessInstances"): p.headlessInstances={}
		p.headlessInstances[str(inst.instanceId)]=inst.duplicate(true)
static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	# Keep the actual instance even after its hand play has left the stack.
	var inst: Dictionary=card.get("headlessInstance",{})
	if inst.is_empty() or not eligible(inst): return
	var p: Dictionary=gs.player(int(frame.playerIndex))
	if not p.has("headlessInstances"): p.headlessInstances={}
	p.headlessInstances[str(inst.instanceId)]=inst.duplicate(true)
static func turn_start(gs, owner: int) -> void:
	track_zones(gs,owner)
	if gs.VerifiedRules.Maple.night_value(gs,owner)!=10: return
	var p: Dictionary=gs.player(owner)
	for iid in p.get("headlessInstances",{}).keys():
		if p.hand.any(func(inst):return str(inst.instanceId)==str(iid)): continue
		var inst: Dictionary=p.headlessInstances[iid]
		for zone in ["deck"]:
			var idx: int=p[zone].find_custom(func(entry):return str(entry.instanceId)==str(iid))
			if idx>=0: inst=p[zone].pop_at(idx); break
		# Full hands retain the off-board instance for the next legal return.
		if p.hand.size()>=int(gs.rules.maxHandSize):
			gs.VerifiedRules.event(gs,"headless-return-blocked",{"player":owner,"instanceId":iid})
			continue
		p.hand.append(inst)
		gs.VerifiedRules.event(gs,"headless-card-returned",{"player":owner,"instanceId":iid,"card":Content.card_def(str(inst.definitionId))})
static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int) -> void:
	if amount<=0 or owner<0 or src<0 or victim==owner or src>=gs.player(owner).units.size(): return
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or int(u.get("headlessNightTurn",-1))==gs.turn_counter: return
	u.headlessNightTurn=gs.turn_counter
	gs.resolution_stack.append({"kind":"headless-base-night","playerIndex":owner,"sourceIndex":src,"threshold":3,"awakened":bool(u.awakened)})
static func random_hit(gs, owner: int, src: int) -> void:
	var pool: Array=[]
	for idx in gs.player(1-owner).units.size():
		var u: Dictionary=gs.player(1-owner).units[idx]
		if int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u): pool.append(idx)
	if pool.is_empty(): return
	var idx: int=pool[gs.next_random()%pool.size()]
	gs.VerifiedRules.base_damage_unit(gs,owner,src,1-owner,idx,2)
	gs.VerifiedRules.event(gs,"headless-random-hit",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":gs.player(1-owner).units[idx].uid,"amount":2})
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("headlessDirect",false): gs.player(owner).units[src].swift=true
static func prepare_combat(gs, owner: int, src: int, options: Dictionary) -> Dictionary:
	var out:=options.duplicate(true)
	var u: Dictionary=gs.player(owner).units[src]
	if active(u) and u.get("formRules",{}).get("headlessDirect",false) and out.get("basicAttack",false): out.directAvatar=true
	return out
static func attack_started(gs, frame: Dictionary) -> bool:
	if frame.get("headlessFireChecked",false): return false
	frame.headlessFireChecked=true
	var owner:=int(frame.playerIndex); var realms: Array=gs.player(owner).realms.filter(func(r):return r.get("nativeRealm")=="headless-fire")
	if realms.is_empty(): return false
	gs.resolution_stack.append(frame)
	for i in range(realms.size()-1,-1,-1):
		gs.resolution_stack.append({"kind":"headless-fire-attack","playerIndex":owner,"sourceIndex":int(frame.sourceIndex),"realmUid":realms[i].uid})
	return true
static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
	if not card.get("headlessSplit",false): return false
	for frame in gs.resolution_stack:
		if int(frame.get("combatId",-1))!=combat_id: continue
		frame.defenderBonus=int(frame.get("defenderBonus",0))+int(card.value)
		frame.defenderCombatCard=card.duplicate(true)
		var u: Dictionary=gs.player(owner).units[src]
		u.combatUnyielding=true; u.headlessSplitCombatId=combat_id; u.headlessSplitSpent=false
		gs.VerifiedRules.event(gs,"headless-split-response",{"player":owner,"uid":u.uid,"combatId":combat_id})
		break
	return true
static func combat_dealt(gs, owner: int, src: int, _victim: int, _idx: int, result: Dictionary, _options: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	var amount:=int(result.get("transferredDealt",result.get("dealt",result.get("damage",0))))
	if not u.has("headlessSplitCombatId") or u.get("headlessSplitSpent",false) or amount<=0: return
	u.headlessSplitSpent=true
	gs._damage_avatar(1-owner,amount,owner,src)
	gs.VerifiedRules.event(gs,"headless-split-damage",{"player":owner,"uid":u.uid,"amount":amount,"combatId":u.headlessSplitCombatId})
static func combat_finished(gs, owner: int, src: int, defender: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	for unit in [u,defender]:
		if unit.is_empty(): continue
		for key in ["headlessSplitCombatId","headlessSplitSpent"]: unit.erase(key)
		unit.erase("combatUnyielding")
static func end_turn(gs, owner: int) -> void:
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm")=="headless-fire": gs.resolution_stack.append({"kind":"headless-fire-card","playerIndex":owner,"realmUid":realm.uid})
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("headlessReturn",false): return null
	var result: Array=["avatar-%d" % (1-owner)]
	for u in gs.player(1-owner).units:
		if int(u.hp)>0 and not gs.VerifiedRules.Combat.has(u,"veil"): result.append(str(u.uid))
	return result
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("headlessRules",false): return true
	var src: int=gs._source_index(owner,card)
	return src>=0 and not (card.get("type")=="awakening" and gs.player(owner).units[src].awakened)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id = null) -> bool:
	match str(effect.get("action","")):
		"headless-projectile":
			var depth: int=gs.resolution_stack.size()
			gs.VerifiedRules.Maple.projectile(gs,owner,src,1)
			gs.resolution_stack.insert(depth,{"kind":"headless-projectile-night","playerIndex":owner,"sourceIndex":src})
		"assault":
			if not card.get("headlessRules",false): return false
			var options: Dictionary=card.get("combatOption",{}).duplicate(true)
			options.combatCard=card.duplicate(true)
			var depth: int=gs.resolution_stack.size()
			if card.get("headlessNightCrit",false): options.headlessUnitCrit=gs.VerifiedRules.Maple.nightfall(gs,owner,5)
			if card.get("headlessReturn",false):
				options.immuneCombat=gs.VerifiedRules.Maple.nightfall(gs,owner,10)
				if str(target_id)=="avatar-%d"%(1-owner): options.directAvatar=true
				else: options.pursuit=true
			if card.get("headlessSplit",false):
				gs.player(owner).units[src].headlessSplitCombatId=gs.next_resolution_id
				gs.player(owner).units[src].headlessSplitSpent=false
			gs._grant_unit_armor(gs.player(owner).units[src],int(options.get("shield",0)))
			gs.resolution_stack.insert(depth,{"kind":"headless-combat-ready","playerIndex":owner,"sourceIndex":src,"targetId":target_id,"value":int(effect.value),"options":options})
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind","")); var owner:=int(frame.get("playerIndex",0)); var src:=int(frame.get("sourceIndex",-1))
	match kind:
		"headless-base-night":
			var depth: int=gs.resolution_stack.size()
			if int(frame.threshold)==3 and frame.awakened:
				gs.resolution_stack.insert(depth,{"kind":"headless-base-night","playerIndex":owner,"sourceIndex":src,"threshold":7,"awakened":true})
			if gs.VerifiedRules.Maple.nightfall(gs,owner,int(frame.threshold)):
				gs.resolution_stack.append({"kind":"headless-random-hit","playerIndex":owner,"sourceIndex":src})
		"headless-random-hit": random_hit(gs,owner,src)
		"headless-projectile-night":
			if gs.VerifiedRules.Maple.nightfall(gs,owner,3): gs.resolution_stack.append({"kind":"headless-draw","playerIndex":owner})
		"headless-draw":
			var before: int=gs.player(owner).deck.size()
			gs._draw(owner,1)
			if before>0: gs.VerifiedRules.event(gs,"headless-night-draw",{"player":owner,"amount":1})
		"headless-combat-ready": gs._resolve_combat(owner,src,int(frame.value),false,false,false,false,frame.targetId,false,frame.options)
		"headless-fire-attack":
			if not gs.player(owner).realms.any(func(r):return str(r.uid)==str(frame.realmUid)): return true
			if gs.VerifiedRules.Maple.nightfall(gs,owner,10) and int(gs.player(owner).units[src].hp)>0:
				gs._grow_unit(gs.player(owner).units[src],2,0)
				gs.VerifiedRules.event(gs,"headless-fire-growth",{"player":owner,"uid":gs.player(owner).units[src].uid,"realm":frame.realmUid})
		"headless-fire-card":
			var p: Dictionary=gs.player(owner)
			if not p.realms.any(func(r):return str(r.uid)==str(frame.realmUid)): return true
			var history: Array=p.get("headlessCombatHistory",[])
			if history.is_empty() or p.hand.size()>=int(gs.rules.maxHandSize): return true
			var id:=str(history[gs.next_random()%history.size()])
			var inst: Dictionary={"instanceId":"%s-headless-generated-%d" % [p.id,gs.next_card_id],"definitionId":id,"headlessGenerated":true}
			gs.next_card_id+=1; p.hand.append(inst)
			if eligible(inst):
				if not p.has("headlessInstances"): p.headlessInstances={}
				p.headlessInstances[str(inst.instanceId)]=inst
			gs.VerifiedRules.event(gs,"headless-fire-card",{"player":owner,"instanceId":inst.instanceId,"card":Content.card_def(id)})
		_: return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("headlessRules",false): return null
	var src: int=gs._source_index(owner,card); var u: Dictionary=gs.player(owner).units[src]
	if card.get("type")=="awakening": return 70 if not u.awakened else -100
	if card.get("type")=="form": return 65 if u.get("form",{}).get("cardId")!=card.id else -30
	if card.get("type")=="realm": return 60+gs.VerifiedRules.Maple.night_value(gs,owner)*2
	if card.get("effect")=="headless-projectile": return 45
	var power:=int(u.attack)+int(card.value)
	if str(target_id)=="avatar-%d"%(1-owner): return 200 if int(gs.player(1-owner).avatarHp)<=power else 50+power*3
	var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
	if not target.is_empty(): return 45+power*2+(25 if int(target.hp)+int(target.shield)<=power else 0)
	return 40+power*2
static func unit_marks(gs, owner: int, src: int) -> Array:
	var u: Dictionary=gs.player(owner).units[src]
	if not source(u): return []
	return ["入夜%d/10" % gs.VerifiedRules.Maple.night_value(gs,owner),"飞颅补刀：本回合已触发" if int(u.get("headlessNightTurn",-1))==gs.turn_counter else "飞颅补刀：本回合未触发"]
