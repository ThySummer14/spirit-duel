class_name OtakemaruRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("otakemaruRules",false)
static func living(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false)
static func active(u: Dictionary) -> bool:
	return living(u) and not u.get("baseRulesSuppressed",false)
static func owner_of(gs, u: Dictionary) -> int:
	for owner in 2:
		if gs._unit_index_by_uid(owner,str(u.get("uid","")))>=0: return owner
	return -1
static func master(gs, owner: int) -> Dictionary:
	for u in gs.player(owner).units:
		if source(u) and active(u): return u
	return {}
static func magnitude(gs, owner: int) -> int:
	return 1+int(gs.player(owner).get("otakeJadeGrowth",0))
static func owned(gs, owner: int) -> Dictionary:
	for side in 2:
		for idx in gs.player(side).units.size():
			var u: Dictionary=gs.player(side).units[idx]
			if u.get("removed",false) or int(u.hp)<=0: continue
			if u.get("otakeJades",{}).has(str(owner)): return {"player":side,"index":idx,"unit":u,"charm":u.otakeJades[str(owner)]}
	return {}
static func friendly_holder(gs, owner: int) -> Dictionary:
	var held:=owned(gs,owner)
	return held if not held.is_empty() and int(held.player)==owner else {}
static func power(gs, u: Dictionary) -> int:
	if int(u.get("hp",0))<=0 or u.get("removed",false): return 0
	var total:=0
	for key in u.get("otakeJades",{}): total+=jade_power(gs,u,int(key))
	return total
static func jade_power(gs, u: Dictionary, jade_owner: int) -> int:
	var amount:=magnitude(gs,jade_owner)
	if source(u) and active(u): return amount*2 if u.awakened else amount+1
	return amount
static func continuously_stunned(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and not u.get("removed",false) and u.get("otakeJades",{}).values().any(func(c):return c.get("prison",false))
static func _independent_stun(u: Dictionary) -> int:
	var remaining:=int(u.get("otakePrisonBaseFrozen",0))
	for value in u.get("stunOwners",{}).values(): remaining=maxi(remaining,int(value))
	if u.has("movementHolders"): remaining=maxi(remaining,maxi(1,int(u.get("movementBaseFrozen",0))))
	return remaining
static func sync_stun(u: Dictionary) -> void:
	if continuously_stunned(u):
		u.frozen=maxi(1,int(u.get("frozen",0)))
	elif u.has("otakePrisonBaseFrozen"):
		u.frozen=_independent_stun(u)
		u.erase("otakePrisonBaseFrozen")
static func stun_ended_turn(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if u.has("otakePrisonBaseFrozen"): u.otakePrisonBaseFrozen=maxi(0,int(u.otakePrisonBaseFrozen)-1)
		sync_stun(u)
static func refresh(gs) -> void:
	for p in gs.players:
		for u in p.units:
			sync_stun(u)
			gs._recalc(u)
static func remove_charm(gs, side: int, idx: int, reason: String = "灵咒被移除", jade_owner: int = -1) -> void:
	if side<0 or idx<0: return
	var u: Dictionary=gs.player(side).units[idx]
	var jades: Dictionary=u.get("otakeJades",{})
	for key in jades.keys().duplicate():
		if jade_owner>=0 and int(key)!=jade_owner: continue
		var charm: Dictionary=jades[key]
		jades.erase(key)
		gs.VerifiedRules.event(gs,"otake-jade-removed",{"player":int(charm.owner),"carrierPlayer":side,"uid":u.uid,"charmUid":charm.uid,"reason":reason})
	if jades.is_empty(): u.erase("otakeJades")
	sync_stun(u); gs._recalc(u)
static func attach(gs, owner: int, src: int, side: int, idx: int, prison: bool = false) -> void:
	if idx<0 or not living(gs.player(side).units[idx]): return
	var old:=owned(gs,owner)
	if not old.is_empty(): remove_charm(gs,int(old.player),int(old.index),"重新结附",owner)
	var u: Dictionary=gs.player(side).units[idx]
	if not u.has("otakeJades"): u.otakeJades={}
	var charm: Dictionary={"uid":"otake-jade-%d-%d" % [owner,gs.next_card_id],"owner":owner,"sourceUid":str(gs.player(owner).units[src].uid),"carrierUid":str(u.uid),"prison":prison and side!=owner}
	gs.next_card_id+=1
	if charm.prison:
		var before: int=u.frozen
		var owners: Dictionary=u.get("stunOwners",{}).duplicate(true)
		# Notify the real stun observers once, but keep the perpetual charm's
		# contribution separate from all finite, independently owned stuns.
		gs.VerifiedRules.Stun.apply(gs,side,idx,1,owner)
		u.stunOwners=owners
		u.otakePrisonBaseFrozen=before
		u.frozen=maxi(1,before)
	u.otakeJades[str(owner)]=charm
	gs._recalc(u); sync_stun(u)
	gs.VerifiedRules.event(gs,"otake-jade-attached",{"player":owner,"carrierPlayer":side,"uid":u.uid,"charmUid":charm.uid,"amount":power(gs,u),"prison":charm.prison})
static func fused(old: Dictionary, incoming: Dictionary) -> void:
	if old.get("otakeJades",{}).is_empty(): return
	if not incoming.has("otakeJades"): incoming.otakeJades={}
	for key in old.otakeJades:
		incoming.otakeJades[key]=old.otakeJades[key].duplicate(true)
		incoming.otakeJades[key].carrierUid=incoming.uid
	if old.has("otakePrisonBaseFrozen"): incoming.otakePrisonBaseFrozen=int(old.otakePrisonBaseFrozen)
	old.erase("otakeJades"); old.erase("otakePrisonBaseFrozen")
static func knocked_out(gs, side: int, u: Dictionary) -> void:
	if side>=0: remove_charm(gs,side,gs._unit_index_by_uid(side,str(u.uid)),"气绝")
	u.erase("otakeCover")
static func damage_prevent(gs, side: int, idx: int, amount: int) -> bool:
	if idx<0 or amount<=0: return false
	var u: Dictionary=gs.player(side).units[idx]
	if not u.get("otakeCover",false): return false
	u.erase("otakeCover")
	gs.VerifiedRules.event(gs,"otake-cover-consumed",{"player":side,"uid":u.uid,"amount":amount})
	return true
static func unit_killed(gs, owner: int, src: int, victim: int, target: Dictionary) -> void:
	if owner<0 or src<0 or owner==victim: return
	var holder: Dictionary=gs.player(owner).units[src]
	if not holder.get("otakeJades",{}).has(str(owner)): return
	var leader:=master(gs,owner)
	if leader.is_empty() or not leader.awakened: return
	gs.player(owner).otakeJadeGrowth=int(gs.player(owner).get("otakeJadeGrowth",0))+1
	refresh(gs)
	gs.VerifiedRules.event(gs,"otake-jade-grown",{"player":owner,"uid":holder.uid,"target":target.uid,"magnitude":magnitude(gs,owner)})
static func generate(gs, owner: int, src: int) -> void:
	var inst: Dictionary={"instanceId":"otake-relocate-%d" % gs.next_card_id,"definitionId":"nuoyi"}
	gs.next_card_id+=1; gs.player(owner).hand.append(inst)
	gs.VerifiedRules.event(gs,"otake-relocate-generated",{"player":owner,"uid":gs.player(owner).units[src].uid,"instanceId":inst.instanceId,"cardId":"nuoyi"})
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("otakeMountain",false): generate(gs,owner,src)
static func turn_start(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if source(u) and active(u) and u.get("formRules",{}).get("otakeMountain",false): generate(gs,owner,src)
static func _living(gs, side: int, hostile: bool = false) -> Array:
	return gs.player(side).units.filter(func(u):return living(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and (not hostile or not gs.VerifiedRules.Combat.has(u,"veil"))).map(func(u):return str(u.uid))
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("otakemaruRules",false): return null
	if card.get("target")=="ally-unit": return _living(gs,owner)
	if card.get("target")=="enemy-unit": return _living(gs,1-owner,true)
	return null
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("otakemaruRules",false): return true
	if card.get("effect")=="otake-jade-token": return false
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	if card.get("effect")=="otake-awaken": return not gs.player(owner).units[src].awakened
	if card.get("effect")=="otake-extinguish": return not friendly_holder(gs,owner).is_empty()
	return true
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("otakemaruRules",false): return card
	var out:=card.duplicate(true)
	var jade:=owned(gs,owner)
	out.currentCardStats="玉基础效果%d力量 · %s" % [magnitude(gs,owner),"未结附" if jade.is_empty() else "结附于"+str(jade.unit.name)]
	if card.get("combatOption",{}).get("otakeAssault",false):
		out.otakeEnhanced=not jade.is_empty()
		out.currentCardStats+=" · 本次免疫战斗伤害" if out.otakeEnhanced else " · 增强未满足"
	return out
static func _assault(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u): return
	var options: Dictionary=card.get("combatOption",{}).duplicate(true)
	options.combatCard=card
	if options.get("otakeAssault",false): options.immuneCombat=bool(card.get("otakeEnhanced",false))
	gs._grant_unit_armor(u,int(options.get("shield",0)))
	gs._record("assault",{"unit":src,"bonus":int(card.value)},owner)
	gs._resolve_combat(owner,src,int(card.value),card.keywords.has("pierce"),card.keywords.has("remote"),card.keywords.has("combo"),card.keywords.has("first-strike"),null,false,options)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	var idx: int=gs._unit_index_by_uid(owner,str(target.get("uid","")))
	match str(effect.get("action","")):
		"otake-relocate", "otake-jade-token": attach(gs,owner,src,owner,idx)
		"otake-cover":
			attach(gs,owner,src,owner,idx)
			if idx>=0: gs.player(owner).units[idx].otakeCover=true
		"otake-prison": attach(gs,owner,src,1-owner,gs._unit_index_by_uid(1-owner,str(target.get("uid",""))),true)
		"otake-awaken":
			attach(gs,owner,src,owner,idx)
			gs._awaken(owner,src,card,effect.value); refresh(gs)
		"otake-extinguish":
			var held:=friendly_holder(gs,owner)
			if not held.is_empty():
				gs._grant_unit_armor(held.unit,2)
				gs.resolution_stack.append({"kind":"otake-held-assault","playerIndex":owner,"sourceIndex":int(held.index),"targetId":target_id,"card":card})
		"otake-combat":
			var played:=card.duplicate(true)
			if card.get("combatOption",{}).get("otakeAssault",false): played.otakeEnhanced=bool(card.get("otakeEnhanced",not owned(gs,owner).is_empty()))
			if card.get("combatOption",{}).get("otakeBoom",false): gs.resolution_stack.append({"kind":"otake-boom-followup","playerIndex":owner,"sourceIndex":src,"targetId":target_id})
			gs.resolution_stack.append({"kind":"otake-source-assault","playerIndex":owner,"sourceIndex":src,"card":played})
			if card.get("combatOption",{}).get("otakeAttachSelf",false): attach(gs,owner,src,owner,src)
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if not str(frame.get("kind","")).begins_with("otake-"): return false
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex)
	match str(frame.kind):
		"otake-source-assault": _assault(gs,owner,src,frame.card)
		"otake-held-assault":
			var u: Dictionary=gs.player(owner).units[src]
			if living(u): gs._resolve_combat(owner,src,0,false,false,false,false,frame.targetId,false,{"pursuit":true,"combatCard":frame.card,"otakeExtinguish":true})
		"otake-boom-followup":
			var idx: int=gs._unit_index_by_uid(owner,str(frame.get("targetId","")))
			if idx>=0 and living(gs.player(owner).units[idx]):
				attach(gs,owner,src,owner,idx)
				gs._resolve_combat(owner,idx,0,false,false,false,false,null,false,{"otakeBoomFollowup":true})
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("otakemaruRules",false): return null
	var ally: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(target_id))
	var enemy: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
	match str(card.get("effect","")):
		"otake-cover": return -100 if ally.is_empty() else 45+int(ally.attack)*2+10*int(int(ally.front)==1)
		"otake-prison": return -100 if enemy.is_empty() else 50+int(enemy.attack)*3+int(enemy.level)*4
		"otake-extinguish":
			var held:=friendly_holder(gs,owner)
			return -100 if held.is_empty() or enemy.is_empty() else 50+20*int(int(held.unit.attack)>=int(enemy.hp)+int(enemy.shield))
		"otake-awaken": return 66+(10 if not ally.is_empty() and source(ally) else 0)
		"otake-combat": return 50+int(ally.get("attack",0))*3+(15 if card.get("otakeEnhanced",false) else 0)
		"otake-relocate": return -100 if ally.is_empty() else 35+int(ally.attack)*2
		"form": return 55
	return -100
static func unit_marks(gs, side: int, idx: int) -> Array:
	var u: Dictionary=gs.player(side).units[idx]
	var marks: Array=[]
	for key in u.get("otakeJades",{}):
		var c: Dictionary=u.otakeJades[key]
		marks.append("八尺琼曲玉 · +%d力量%s" % [jade_power(gs,u,int(c.owner))," · 持续眩晕" if c.get("prison",false) else ""])
	if u.get("otakeCover",false): marks.append("覆土之术 · 免疫下一次伤害")
	return marks
