class_name MapleRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("mapleNight",false)

static func night_value(gs, owner: int) -> int:
	return clampi(int(gs.player(owner).get("night",0)),0,10)

static func gain_night(gs, owner: int, amount: int = 1) -> int:
	var before:=night_value(gs,owner)
	gs.player(owner).night=clampi(before+maxi(0,amount),0,10)
	var gained:=night_value(gs,owner)-before
	if gained<=0: return 0
	gs.VerifiedRules.event(gs,"night-gained",{"player":owner,"amount":gained,"value":night_value(gs,owner)})
	for i in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[i]
		if source(u) and active(u): gs.resolution_stack.append({"kind":"maple-projectile","playerIndex":owner,"sourceIndex":i,"amount":3 if u.awakened else 1})
	return gained

static func nightfall(gs, owner: int, threshold: int) -> bool:
	var effect_depth: int=gs.resolution_stack.size()
	var passed:=night_value(gs,owner)>=threshold
	if not passed: gain_night(gs,owner,1)
	gs.VerifiedRules.event(gs,"night-triggered",{"player":owner,"threshold":threshold,"passed":passed,"value":night_value(gs,owner)})
	gs.VerifiedRules.Yaksha.night_triggered(gs,owner,effect_depth)
	return passed

static func damage_bonus(gs, owner: int, src: int, combat: bool) -> int:
	if combat or owner<0 or src<0 or src>=gs.player(owner).units.size(): return 0
	var u: Dictionary=gs.player(owner).units[src]
	return int(night_value(gs,owner)/5) if active(u) and u.get("formRules",{}).get("mapleDance",false) else 0

static func marked(u: Dictionary) -> bool:
	return not u.get("mapleDoll",{}).is_empty()

static func remove_doll(gs, u: Dictionary) -> void:
	if not marked(u): return
	u.erase("mapleDoll")
	gs.VerifiedRules.event(gs,"maple-doll-removed",{"uid":u.uid})

static func attach(gs, owner: int, src: int, u: Dictionary) -> void:
	if u.is_empty() or int(u.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	u.mapleDoll={"owner":owner,"sourceUid":gs.player(owner).units[src].uid}
	gs.VerifiedRules.event(gs,"maple-doll-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":u.uid})

static func projectile(gs, owner: int, src: int, amount: int) -> void:
	var idx: int=gs.front_index(1-owner)
	if idx<0: gs._damage_avatar(1-owner,amount,owner,src)
	else: gs._damage_unit(1-owner,idx,amount,owner,src)
	gs.VerifiedRules.event(gs,"maple-projectile",{"player":owner,"uid":gs.player(owner).units[src].uid,"amount":amount})

static func random_doll(gs, owner: int, src: int) -> void:
	var opts: Array=gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u))
	if not opts.is_empty(): attach(gs,owner,src,opts[int(floor(gs.randf01()*opts.size()))])

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("mapleBurst",false): random_doll(gs,owner,src)

static func turn_start(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if active(u) and u.get("formRules",{}).get("mapleBurst",false): random_doll(gs,owner,src)

static func damage_dealt(gs, owner: int, src: int, victim: int, idx: int, amount: int, combat: bool) -> void:
	if not combat or amount<=0 or owner<0 or owner==victim or src<0 or idx<0: return
	var u: Dictionary=gs.player(owner).units[src]
	if u.get("formRules",{}).get("mapleBlood",false): attach(gs,owner,src,gs.player(victim).units[idx])

static func knocked_out(gs, victim: int, u: Dictionary) -> void:
	if not marked(u): return
	for owner in gs.players.size():
		if owner==victim: continue
		for src in gs.player(owner).units.size():
			var observer: Dictionary=gs.player(owner).units[src]
			if active(observer) and observer.get("formRules",{}).get("mapleBurst",false): gs.resolution_stack.append({"kind":"maple-death-hit","playerIndex":owner,"sourceIndex":src})
	remove_doll(gs,u)

static func end_turn(gs, owner: int) -> void:
	# Queue each source independently so a gained point and its projectile fully
	# resolve before the next threshold check. A doll belongs to its host's turn.
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[src]
		if source(u) and active(u) and u.awakened and not u.get("mapleAwakenUsed",false):
			gs.resolution_stack.append({"kind":"maple-awaken-end","playerIndex":owner,"sourceIndex":src})
	for idx in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[idx]
		if int(u.hp)>0 and marked(u): gs.resolution_stack.append({"kind":"maple-doll-end","playerIndex":owner,"unitUid":u.uid,"doll":u.mapleDoll.duplicate(true)})

static func aoe(gs, owner: int, src: int, amount: int, excluded_uid: String = "") -> void:
	gs._damage_avatar(1-owner,amount,owner,src)
	for idx in gs.player(1-owner).units.size():
		var u: Dictionary=gs.player(1-owner).units[idx]
		if int(u.hp)>0 and str(u.uid)!=excluded_uid: gs._damage_unit(1-owner,idx,amount,owner,src)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""))
	if not kind.begins_with("maple-"): return false
	var owner:=int(frame.playerIndex)
	var src:=int(frame.get("sourceIndex",-1))
	var previous: Dictionary=gs._card_effect_context
	gs._card_effect_context=frame.get("context",{})
	match kind:
		"maple-projectile": projectile(gs,owner,src,int(frame.amount)+gs.VerifiedRules.ApeSleeve.base_damage_bonus(gs,owner))
		"maple-death-hit": gs._damage_avatar(1-owner,2,owner,src)
		"maple-awaken-end":
			var u: Dictionary=gs.player(owner).units[src]
			if active(u) and u.awakened and not u.get("mapleAwakenUsed",false) and nightfall(gs,owner,10):
				u.mapleAwakenUsed=true; projectile(gs,owner,src,10+gs.VerifiedRules.ApeSleeve.base_damage_bonus(gs,owner))
		"maple-doll-end":
			var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(frame.unitUid))
			if not u.is_empty() and int(u.hp)>0 and u.get("mapleDoll",{})==frame.doll:
				var caster:=int(frame.doll.owner)
				src=gs._unit_index_by_uid(caster,str(frame.doll.sourceUid))
				remove_doll(gs,u)
				if src>=0:
					gs._damage_unit(owner,gs._unit_index_by_uid(owner,str(u.uid)),2,caster,src)
					if nightfall(gs,caster,10): aoe(gs,caster,src,2,str(u.uid))
		"maple-aoe": aoe(gs,owner,src,int(frame.amount))
	gs._card_effect_context=previous
	return true

static func target_location(gs, uid: String) -> Array:
	for side in gs.players.size():
		var idx: int=gs._unit_index_by_uid(side,uid)
		if idx>=0: return [side,idx]
	return []

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("mapleAnyUnit",false): return null
	var result: Array=[]
	for side in [owner,1-owner]:
		for u in gs.player(side).units:
			if int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side==owner or not (gs.VerifiedRules.Combat.has(u,"veil") or gs.VerifiedRules.Movement.has_veil(u))): result.append(str(u.uid))
	return result

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("mapleRules",false): return card
	var result:=card.duplicate(true)
	var src: int=gs._source_index(owner,card)
	if card.get("effect")=="maple-night-damage":
		result.currentCardStats="当前伤害%d · 入夜%d/10" % [night_value(gs,owner)+damage_bonus(gs,owner,src,false),night_value(gs,owner)]
	elif card.get("type")=="form": result.currentCardStats="当前%d/%d" % [int(card.value.attack),int(card.value.hp)]
	return result

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action","")):
		"maple-symbol", "maple-night-damage", "maple-scatter":
			var where:=target_location(gs,str(target.get("uid","")))
			if where.is_empty(): return true
			var action:=str(effect.action)
			var amount:=night_value(gs,owner) if action=="maple-night-damage" else 3
			gs._damage_unit(int(where[0]),int(where[1]),amount,owner,src)
			if action=="maple-symbol": attach(gs,owner,src,target)
			elif action=="maple-scatter" and marked(target):
				remove_doll(gs,target)
				gs.resolution_stack.append({"kind":"maple-aoe","playerIndex":owner,"sourceIndex":src,"amount":2,"context":gs._card_effect_context})
		"maple-death-dance":
			for u in gs.player(1-owner).units: attach(gs,owner,src,u)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("mapleRules",false): return null
	var src: int=gs._source_index(owner,card)
	var u: Dictionary=gs.player(owner).units[src]
	if card.type=="awakening": return -100 if u.awakened else 75
	if card.type=="form": return -40 if u.get("form",{}).get("cardId")==card.id else 50+(12 if card.id=="c25907" else 0)
	if card.get("effect")=="maple-death-dance": return 20+12*gs.player(1-owner).units.filter(func(x):return int(x.hp)>0 and not marked(x)).size()
	var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
	if target.is_empty(): return -100
	var amount:=night_value(gs,owner) if card.get("effect")=="maple-night-damage" else 3
	amount+=damage_bonus(gs,owner,src,false)
	return 38+mini(amount,int(target.hp))*3+(25 if int(target.hp)+int(target.shield)<=amount else 0)+(25 if card.get("effect")=="maple-scatter" and marked(target) and int(target.hp)>amount else 0)
