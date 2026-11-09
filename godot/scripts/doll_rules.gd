class_name DollRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const KINDS := ["resent","curse","substitute"]
const NAMES := {"resent":"怨缚草人","curse":"诅咒草人","substitute":"替身草人"}
const IDS := {"resent":"doll-resent","curse":"doll-curse","substitute":"doll-substitute"}
static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("dollRules",false))
static func living(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false)
static func active(u: Dictionary) -> bool:
	return living(u) and not u.get("baseRulesSuppressed",false)
static func bound_enemies(gs, owner: int, selected: bool = false) -> Array:
	return gs.player(1-owner).units.filter(func(u):return living(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and (not selected or not gs.VerifiedRules.Combat.has(u,"veil")))
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("dollSummon",false) or u.get("removed",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true; u.dollDepartureRecorded=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("dollSummon",false) and int(u.front)==0 and int(u.hp)>0: remove_summon(gs,owner,u)
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	if not u.get("dollSummon",false): return
	u.hp=0; u.front=0; u.knockout=0; u.removed=true; u.dollDepartureRecorded=true
	gs.VerifiedRules.event(gs,"doll-summon-died",{"player":owner,"uid":u.uid})
static func revived(gs, owner: int, idx: int) -> void:
	var u: Dictionary=gs.player(owner).units[idx]
	if u.get("dollSummon",false):
		u.erase("dollDepartureRecorded")
		# Revival restores this physical summon, not a new summon-entry ability.
static func unbind_knocked_out(gs, _owner: int, u: Dictionary) -> void:
	for p in gs.players:
		for doll in p.units:
			if not doll.get("dollSummon",false): continue
			var changed:=false
			# A real summon corpse is a snapshot of the same physical binding.
			# Unbinding must update it too, or powder would restore a stale link.
			for record in [doll,doll.get("weaverGrave",{})]:
				var ids: Array=record.get("dollTargets",[])
				if str(u.uid) not in ids: continue
				ids.erase(str(u.uid)); record.dollTargets=ids; changed=true
			if changed: gs.VerifiedRules.event(gs,"doll-binding-removed",{"uid":doll.uid,"targetUid":u.uid,"reason":"绑定式神气绝"})
static func summon(gs, owner: int, src: int, kind: String, target_uid: String) -> int:
	if kind not in KINDS: return -1
	var ti: int=gs._unit_index_by_uid(1-owner,target_uid)
	if ti<0 or not living(gs.player(1-owner).units[ti]): return -1
	gs.VerifiedRules.Weaver.leave_front(gs,owner)
	# leave_front may invoke source-specific removal or replacement reactions.
	clear_summons(gs,owner)
	var p: Dictionary=gs.player(owner)
	var u: Dictionary={"uid":"%s:doll-%d" % [p.id,gs.next_card_id],"id":IDS[kind],"name":NAMES[kind],"title":"丑时之女召唤物","art":"assets/official/cards/%s.png" % IDS[kind],"color":"#c0a090","baseAttack":0,"baseMaxHp":4,"attack":0,"maxHp":4,"hp":4,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"受到伤害时触发草人效果。离开战斗区时移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"dollSummon":true,"dollKind":kind,"dollTargets":[target_uid],"removed":false,"summonerUid":str(p.units[src].uid)}
	gs.next_card_id+=1; p.units.append(u)
	var idx: int=p.units.size()-1
	var history: Array=p.get("dollHistory",[])
	if kind not in history: history.append(kind)
	p.dollHistory=history
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":u.summonerUid,"summonKind":kind,"targetUid":target_uid})
	gs._fire_hooks(owner,idx,"unit-entered-front",{}); gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.resolution_stack.append({"kind":"doll-entry-response","playerIndex":owner,"unitUid":u.uid})
	gs.resolution_stack.append({"kind":"doll-entry","playerIndex":owner,"sourceIndex":src,"unitUid":u.uid})
	return idx
static func random_summon(gs, owner: int, src: int, history_only: bool = false, target_uid: String = "") -> void:
	var enemies:=bound_enemies(gs,owner)
	if enemies.is_empty(): return
	var kinds: Array=gs.player(owner).get("dollHistory",[]) if history_only else KINDS
	if kinds.is_empty(): return
	var kind: String=str(kinds[int(floor(gs.randf01()*kinds.size()))])
	var selected: String=target_uid if target_uid!="" else str(enemies[int(floor(gs.randf01()*enemies.size()))].uid)
	summon(gs,owner,src,kind,selected)
static func damaged(gs, owner: int, idx: int, amount: int, _source_owner: int, _source_index: int) -> void:
	if amount<=0 or idx<0: return
	var u: Dictionary=gs.player(owner).units[idx]
	if not u.get("dollSummon",false) or u.get("dollDeparted",false): return
	# The lethal hit still triggers; capture the original bindings before cleanup.
	for uid in u.get("dollTargets",[]).duplicate():
		gs.resolution_stack.append({"kind":"doll-reaction","playerIndex":owner,"sourceIndex":idx,"unitUid":u.uid,"targetUid":str(uid),"amount":amount,"dollKind":str(u.dollKind)})
	gs.VerifiedRules.event(gs,"doll-damaged",{"player":owner,"uid":u.uid,"amount":amount,"bindings":u.get("dollTargets",[]).duplicate()})
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("dollRandom",false): gs.resolution_stack.append({"kind":"doll-random","playerIndex":owner,"sourceIndex":src})
static func turn_start(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[src]
		if active(u) and u.get("formRules",{}).get("dollRandom",false): gs.resolution_stack.append({"kind":"doll-random","playerIndex":owner,"sourceIndex":src})
static func turn_end(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[src]
		if active(u) and u.get("formRules",{}).get("dollGrowth",false): gs.resolution_stack.append({"kind":"doll-growth","playerIndex":owner,"sourceIndex":src})
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("dollRules",false): return null
	if card.get("effect") in ["doll-summon","doll-awaken"]: return bound_enemies(gs,owner,true).map(func(u):return str(u.uid))
	if card.get("effect")=="doll-nail":
		var opts: Array=[]
		for side in [owner,1-owner]:
			for u in gs.player(side).units:
				if living(u) and u.get("summoned",false) and (side==owner or not gs.VerifiedRules.Combat.has(u,"veil")): opts.append(str(u.uid))
		return opts
	return null
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("dollRules",false): return true
	if card.get("effect")=="doll-token": return false
	if card.get("effect")=="doll-awaken":
		var src: int=gs._source_index(owner,card)
		return src>=0 and not gs.player(owner).units[src].awakened and not gs.player(owner).get("dollHistory",[]).is_empty()
	return true
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("dollRules",false): return card
	var out:=card.duplicate(true)
	out.currentCardStats="入夜%d/10 · 已召唤草人%d种" % [gs.VerifiedRules.Maple.night_value(gs,owner),gs.player(owner).get("dollHistory",[]).size()]
	return out
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id = null) -> bool:
	match str(effect.get("action","")):
		"doll-summon": summon(gs,owner,src,str(effect.value),str(target_id))
		"doll-nail":
			var damage_depth: int=gs.resolution_stack.size()
			for side in 2:
				var idx: int=gs._unit_index_by_uid(side,target_id)
				if idx>=0: gs._damage_unit(side,idx,3,owner,src)
			gs.resolution_stack.insert(damage_depth,{"kind":"doll-nail-draw","playerIndex":owner,"sourceIndex":src})
		"doll-fire":
			# Snapshot identities so summons created by a reaction are not retroactive targets.
			var frames: Array=[]
			var front: int=gs.front_index(owner)
			if front>=0: frames.append({"kind":"doll-hit","playerIndex":owner,"sourceIndex":src,"victimPlayer":owner,"targetUid":str(gs.player(owner).units[front].uid),"amount":3})
			for u in gs.player(1-owner).units:
				if living(u) and gs.VerifiedRules.OwlInsect.shikigami(u): frames.append({"kind":"doll-hit","playerIndex":owner,"sourceIndex":src,"victimPlayer":1-owner,"targetUid":str(u.uid),"amount":3})
			frames.reverse(); gs.resolution_stack.append_array(frames)
		"doll-awaken":
			gs._awaken(owner,src,card,{"attack":1,"hp":1})
			random_summon(gs,owner,src,true,str(target_id))
		"doll-token": pass
		_: return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind: String=str(f.get("kind",""))
	if not kind.begins_with("doll-"): return false
	var owner: int=int(f.playerIndex)
	var src: int=int(f.get("sourceIndex",-1))
	match kind:
		"doll-entry":
			var idx: int=gs._unit_index_by_uid(owner,str(f.unitUid))
			if idx<0 or not living(gs.player(owner).units[idx]) or src<0: return true
			var master: Dictionary=gs.player(owner).units[src]
			if not active(master): return true
			var u: Dictionary=gs.player(owner).units[idx]
			var night_depth: int=gs.resolution_stack.size()
			if source(master):
				if master.awakened:
					gs._grow_unit(u,gs.VerifiedRules.Maple.night_value(gs,owner),0)
					if gs.VerifiedRules.Maple.nightfall(gs,owner,10):
						var extra:=bound_enemies(gs,owner).filter(func(t):return str(t.uid) not in u.dollTargets)
						if not extra.is_empty(): u.dollTargets.append(str(extra[int(floor(gs.randf01()*extra.size()))].uid))
				elif gs.VerifiedRules.Maple.nightfall(gs,owner,3): gs._grow_unit(u,3,0)
			if master.get("formRules",{}).get("dollRandom",false): gs.resolution_stack.insert(night_depth,{"kind":"doll-entry-damage","playerIndex":owner,"sourceIndex":src,"unitUid":u.uid})
		"doll-entry-damage":
			var idx: int=gs._unit_index_by_uid(owner,str(f.unitUid))
			if idx>=0 and living(gs.player(owner).units[idx]): gs._damage_unit(owner,idx,1,owner,src)
		"doll-entry-response":
			var idx: int=gs._unit_index_by_uid(owner,str(f.unitUid))
			if idx>=0 and living(gs.player(owner).units[idx]): gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",str(f.unitUid),{"kind":"response-complete"})
		"doll-random":
			if src>=0 and active(gs.player(owner).units[src]) and gs.player(owner).units[src].get("formRules",{}).get("dollRandom",false):
				var night_depth: int=gs.resolution_stack.size()
				if gs.VerifiedRules.Maple.nightfall(gs,owner,7): gs.resolution_stack.insert(night_depth,{"kind":"doll-random-summon","playerIndex":owner,"sourceIndex":src})
		"doll-random-summon":
			if src>=0 and active(gs.player(owner).units[src]): random_summon(gs,owner,src)
		"doll-growth":
			if src>=0 and active(gs.player(owner).units[src]) and gs.player(owner).units[src].get("formRules",{}).get("dollGrowth",false):
				for u in gs.player(owner).units:
					if living(u) and u.get("summoned",false): gs._grow_unit(u,0,2)
		"doll-nail-draw":
			if gs.VerifiedRules.Maple.nightfall(gs,owner,3): gs._draw(owner,1)
		"doll-hit":
			var side: int=int(f.victimPlayer); var idx: int=gs._unit_index_by_uid(side,str(f.targetUid))
			if idx>=0 and living(gs.player(side).units[idx]): gs._damage_unit(side,idx,int(f.amount),owner,src)
		"doll-reaction":
			var idx: int=gs._unit_index_by_uid(1-owner,str(f.targetUid))
			if idx<0 or not living(gs.player(1-owner).units[idx]): return true
			var original: Dictionary=gs.player(owner).units[src]
			if str(f.targetUid) not in original.get("dollTargets",[]): return true
			match str(f.dollKind):
				"resent": gs.VerifiedRules.Stun.apply(gs,1-owner,idx,1,owner)
				"curse":
					var p: Dictionary=gs.player(1-owner); var target: Dictionary=p.units[idx]
					var cards: Array=p.hand.filter(func(c):return str(target.id) in Content.card_unit_ids(Content.card_def(str(c.definitionId))))
					if not cards.is_empty():
						var selected: Dictionary=cards[int(floor(gs.randf01()*cards.size()))]
						gs.discard_hand_card(1-owner, p.hand.find(selected))
						gs.VerifiedRules.event(gs,"card-discarded",{"player":1-owner,"uid":target.uid,"card":Content.card_def(str(selected.definitionId)),"instanceId":str(selected.instanceId)})
				"substitute": gs._damage_unit(1-owner,idx,int(f.amount),owner,src)
			gs.VerifiedRules.event(gs,"doll-reaction",{"player":owner,"uid":original.uid,"targetUid":str(f.targetUid),"dollKind":str(f.dollKind),"amount":int(f.amount)})
		_: return false
	return true
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]; var out: Array=[]
	if source(u): out.append("入夜%d/10 · 草人进场%s" % [gs.VerifiedRules.Maple.night_value(gs,owner),"获得当前入夜力量" if u.awakened else "入夜3获得3力量"])
	if u.get("dollSummon",false):
		var names: Array=[]
		for uid in u.get("dollTargets",[]):
			var at: int=gs._unit_index_by_uid(1-owner,str(uid))
			if at>=0: names.append(str(gs.player(1-owner).units[at].name))
		out.append("绑定："+("已失效" if names.is_empty() else "、".join(names)))
		out.append({"resent":"受伤眩晕绑定者","curse":"受伤随机弃绑定者专属牌","substitute":"受伤令绑定者受等量伤害"}.get(str(u.dollKind),""))
	return out
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("dollRules",false): return null
	match str(card.get("effect","")):
		"doll-awaken": return 85
		"doll-summon":
			var idx: int=gs._unit_index_by_uid(1-owner,target_id)
			return 40+(int(gs.player(1-owner).units[idx].attack)*2 if idx>=0 else 0)+gs.VerifiedRules.Maple.night_value(gs,owner)
		"doll-nail":
			var idx: int=gs._unit_index_by_uid(owner,target_id)
			return 52 if idx>=0 and gs.player(owner).units[idx].get("dollSummon",false) and not gs.player(owner).units[idx].get("dollTargets",[]).is_empty() else 20
		"doll-fire": return 40+bound_enemies(gs,owner).size()*6
	return 42
