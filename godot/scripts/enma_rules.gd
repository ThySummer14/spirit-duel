class_name EnmaRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const FORM_FLAGS := {"c23002":"enmaEye","c23004":"enmaJudge","c23007":"enmaMercy"}

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("enmaBasic",false)
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("baseRulesSuppressed",false) and not u.get("removed",false)
static func ghost(gs, owner: int) -> Dictionary:
	for u in gs.player(owner).units:
		if u.get("enmaGhost",false) and active(u) and int(u.front)==1: return u
	return {}
static func mirror_count(gs, owner: int) -> int:
	return gs.player(owner).realms.filter(func(r):return r.get("nativeRealm")=="enma-mirror" and int(r.hp)>0).size()
static func aura(gs, u: Dictionary) -> int:
	if not u.get("summoned",false) or u.get("removed",false): return 0
	for owner in 2:
		if gs.player(owner).units.has(u): return mirror_count(gs,owner)
	return 0
static func flag(gs, owner: int, key: String) -> bool:
	return gs.player(owner).units.any(func(u):return source(u) and active(u) and u.get("formRules",{}).get(key,false))
static func refresh(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units.duplicate():
			if not u.get("summoned",false) or u.get("removed",false): continue
			if u.get("enmaGhost",false):
				u.enmaVeil=flag(gs,owner,"enmaEye")
				u.enmaPierce=flag(gs,owner,"enmaMercy")
				var mercy:=flag(gs,owner,"enmaMercy")
				if mercy and not u.get("enmaMercyPresent",false): u.enmaUnyielding=true
				if not mercy: u.enmaUnyielding=false
				u.enmaMercyPresent=mercy
			gs._recalc(u)
			if int(u.hp)<=0: gs._knockout_unit(u)
static func has(u: Dictionary, keyword: String) -> bool:
	if not u.get("enmaGhost",false) or not active(u): return false
	return (keyword=="veil" and u.get("enmaVeil",false)) or (keyword=="pierce" and u.get("enmaPierce",false)) or (keyword=="unyielding" and u.get("enmaUnyielding",false))
static func consume_unyielding(u: Dictionary) -> void:
	u.enmaUnyielding=false
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("enmaGhost",false) or u.get("enmaRemovalRecorded",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true; u.enmaRemovalRecorded=true
	gs.VerifiedRules.event(gs,"enma-ghost-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("enmaGhost",false) and (int(u.hp)<=0 or int(u.front)==0): remove_summon(gs,owner,u)
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	remove_summon(gs,owner,u,"魂鬼气绝")
static func knockout_snapshot(gs, owner: int, u: Dictionary) -> Array:
	if owner<0 or not u.get("enmaGhost",false) or u.get("enmaDeathRecorded",false) or u.get("enmaRemovalRecorded",false): return []
	u.enmaDeathRecorded=true
	var frames: Array=[]
	for master in gs.player(owner).units:
		if source(master) and active(master) and master.get("formRules",{}).get("enmaLord",false):
			frames.append({"kind":"enma-lord-growth","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,str(master.uid)),"amount":maxi(0,int(int(u.attack)/2)),"ghostUid":u.uid})
	return frames
static func summon_ghost(gs, owner: int, src: int) -> int:
	var p: Dictionary=gs.player(owner)
	var master: Dictionary=p.units[src]
	var power:=maxi(1,int(master.attack))
	var life:=power if master.awakened else 1
	var old:=ghost(gs,owner)
	var old_uid:=str(old.get("uid",""))
	var u: Dictionary
	if not old.is_empty():
		# Fusion creates a new instance; old is neither killed nor removed by an
		# effect. Preserve the old body's wounds, all attached states and grants.
		u=old.duplicate(true)
		old.erase("vineCharm")
		u.baseAttack=int(u.baseAttack)+power
		u.baseMaxHp=int(u.baseMaxHp)+life
		old.hp=0; old.front=0; old.knockout=0; old.removed=true; old.enmaRemovalRecorded=true; old.enmaFused=true
	else:
		u={"id":"enma-ghost","name":"魂鬼","title":"阎魔召唤物","art":Content.unit_def("yanmo").art,"color":"#6a3a5a","baseAttack":power,"baseMaxHp":life,"attack":power,"maxHp":life,"hp":life,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"融合。离开战斗区时移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"enmaGhost":true,"keywords":["fusion"],"swift":false}
	u.uid="%s:enma-ghost-%d" % [p.id,gs.next_card_id]; gs.next_card_id+=1
	gs.VerifiedRules.Otakemaru.fused(old,u)
	u.summonerUid=master.uid; u.removed=false; u.front=1
	u.enmaRemovalRecorded=false; u.enmaDeathRecorded=false; u.enmaMercyPresent=false
	u.erase("enmaFused")
	var movement_old: Array=p.units.map(func(other):return int(other.front))
	# Other summoned bodies leave the combat area; the old fused instance has
	# already ceased to exist and must never emit a death/removal trigger.
	gs.VerifiedRules.TomatoFire.clear_summons(gs,owner); gs.VerifiedRules.Xuenv.clear_wall(gs,owner)
	gs.VerifiedRules.Paint.clear_summons(gs,owner); gs.VerifiedRules.Pine.clear_summons(gs,owner)
	gs.VerifiedRules.Weaver.clear_summons(gs,owner)
	for other in p.units: other.front=0
	p.units.append(u)
	var idx: int=p.units.size()-1
	refresh(gs)
	if flag(gs,owner,"enmaJudge"): gs._grant_unit_armor(u,2)
	for i in movement_old.size(): gs.VerifiedRules.Movement.moved(gs,owner,i,int(movement_old[i]))
	gs.VerifiedRules.Bamboo.remove_departed(gs)
	gs.VerifiedRules.Weaver.remove_departed(gs)
	gs.VerifiedRules.Vine.remove_departed(gs)
	gs.VerifiedRules.WindRaccoon.remove_departed(gs)
	gs.VerifiedRules.House.remove_departed(gs)
	gs.VerifiedRules.Doll.remove_departed(gs)
	gs.VerifiedRules.SunSmoke.remove_departed(gs)
	gs.VerifiedRules.event(gs,"enma-ghost-fused" if not old.is_empty() else "enma-ghost-summoned",{"player":owner,"uid":u.uid,"previousUid":old_uid,"sourceUid":master.uid,"attack":u.attack,"hp":u.hp})
	gs._fire_hooks(owner,idx,"unit-entered-front",{}); gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
	return idx
static func fuse_revived(gs, owner: int, idx: int) -> int:
	var p: Dictionary=gs.player(owner)
	var incoming: Dictionary=p.units[idx]
	if not incoming.get("enmaGhost",false): return -1
	gs._recalc(incoming)
	var old: Dictionary={}
	for i in p.units.size():
		if i!=idx and p.units[i].get("enmaGhost",false) and active(p.units[i]) and int(p.units[i].front)==1 and p.units[i].get("summonerUid")==incoming.get("summonerUid"):
			old=p.units[i]; break
	if old.is_empty():
		refresh(gs)
		if flag(gs,owner,"enmaJudge"): gs._grant_unit_armor(incoming,2)
		return -1
	var result:=old.duplicate(true)
	for key in ["baseAttack","baseMaxHp","attackBonus","maxHpBonus","cranePower","permanentAttack","temporaryAttack","judgeInkAttack","judgeInkHp","foxPillow","dreamPowerPenalty","insectCorrosion","windStoredPower"]:
		result[key]=int(old.get(key,0))+int(incoming.get(key,0))
	var current_aura:=mirror_count(gs,owner)
	result.attack=int(old.attack)+int(incoming.attack)-current_aura
	result.maxHp=int(old.maxHp)+int(incoming.maxHp)-current_aura
	result.hp=int(old.hp)+int(incoming.hp)-current_aura
	result.shield=int(old.shield)+int(incoming.shield)
	for key in ["frozen","brittle","armorBreak"]: result[key]=maxi(int(old.get(key,0)),int(incoming.get(key,0)))
	for key in ["swift","inspired","barrier","unyielding","enraged"]: result[key]=bool(old.get(key,false)) or bool(incoming.get(key,false))
	for key in ["keywords","stunOwners"]:
		var merged: Array=old.get(key,[]).duplicate(true)
		for value in incoming.get(key,[]):
			if not merged.has(value): merged.append(value)
		result[key]=merged
	for key in ["untilAttack","swanKeywords"]:
		var merged: Dictionary=old.get(key,{}).duplicate(true)
		for k in incoming.get(key,{}):
			if k=="keywords":
				var traits: Array=merged.get(k,[]).duplicate(true)
				for entry_keyword in incoming[key][k]:
					if not traits.has(entry_keyword): traits.append(entry_keyword)
				merged[k]=traits
			elif incoming[key][k] is int: merged[k]=int(merged.get(k,0))+int(incoming[key][k])
			else: merged[k]=incoming[key][k]
		result[key]=merged
	result.uid="%s:enma-ghost-%d" % [p.id,gs.next_card_id]; gs.next_card_id+=1
	gs.VerifiedRules.Otakemaru.fused(old,result)
	gs.VerifiedRules.Otakemaru.fused(incoming,result)
	result.front=1; result.removed=false; result.enmaRemovalRecorded=false; result.enmaDeathRecorded=false; result.enmaMercyPresent=false
	result.erase("weaverGrave"); result.erase("weaverReviveReason"); result.erase("enmaFused")
	for consumed in [old,incoming]:
		consumed.erase("vineCharm")
		consumed.hp=0; consumed.front=0; consumed.knockout=0; consumed.removed=true; consumed.enmaFused=true; consumed.enmaRemovalRecorded=true
	p.units.append(result)
	var fused_idx: int=p.units.size()-1
	refresh(gs)
	if flag(gs,owner,"enmaJudge"): gs._grant_unit_armor(result,2)
	gs.VerifiedRules.event(gs,"enma-ghost-fused",{"player":owner,"uid":result.uid,"previousUid":old.uid,"incomingUid":incoming.uid,"revived":true,"attack":result.attack,"hp":result.hp})
	gs._fire_hooks(owner,fused_idx,"unit-entered-front",{}); gs._run_form_hooks(owner,fused_idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",result.uid,{"kind":"response-complete"})
	return fused_idx
static func replace_basic(gs, owner: int, src: int, target_id = null) -> bool:
	var master: Dictionary=gs.player(owner).units[src]
	if not source(master) or not active(master): return false
	master.enraged=false
	var depth: int=gs.resolution_stack.size()
	var idx:=summon_ghost(gs,owner,src)
	gs.resolution_stack.insert(depth,{"kind":"enma-attack","playerIndex":owner,"sourceIndex":idx,"targetId":target_id,"options":{"basicAttack":true,"enmaReplacement":true}})
	gs.VerifiedRules.event(gs,"enma-basic-replaced",{"player":owner,"uid":master.uid,"ghostUid":gs.player(owner).units[idx].uid})
	return true
static func card_announced(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("enmaRules",false) or card.get("type")!="form" or card.id=="c23008": return
	var u: Dictionary=gs.player(owner).units[src]
	if not u.has("enmaForms"): u.enmaForms=[]
	if not u.enmaForms.has(card.id): u.enmaForms.append(card.id)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.id=="c23008": gs.player(owner).units[src].swift=true
	refresh(gs)
static func turn_start(gs, owner: int) -> void:
	if mirror_count(gs,owner)<=0: return
	refresh(gs)
	for idx in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[idx]
		if u.get("summoned",false) and active(u):
			u.swift=true
			gs.VerifiedRules.Combat.grant_inspired(gs,owner,idx)
static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") not in ["enma-steal","enma-pressure"]: return null
	return gs.player(1-owner).units.filter(func(u):return active(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("enmaRules",false): return true
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	if card.get("effect")=="enma-token": return false
	if card.get("effect")=="enma-awaken": return not gs.player(owner).units[src].awakened
	return card.get("effect")!="enma-pressure" or not ghost(gs,owner).is_empty()
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("enmaRules",false): return card
	var out:=card.duplicate(true)
	var src: int=gs._source_index(owner,card)
	if src<0: return out
	if card.id=="c23008":
		for id in gs.player(owner).units[src].get("enmaForms",[]):
			if FORM_FLAGS.has(id): out.formRules[FORM_FLAGS[id]]=true
		out.currentCardStats="已使用其他形态%d种 · 形态5/5" % gs.player(owner).units[src].get("enmaForms",[]).size()
	if card.get("effect")=="enma-pressure":
		var body:=ghost(gs,owner)
		out.currentCardStats="当前无魂鬼" if body.is_empty() else "魂鬼%d力量/%d生命" % [body.attack,body.hp]
	return out
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	match str(effect.get("action","")):
		"enma-token": summon_ghost(gs,owner,src)
		"enma-steal":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid","")))
			if idx>=0:
				var hit: Dictionary=gs._damage_unit(1-owner,idx,3,owner,src)
				if hit.get("knocked",false) and active(gs.player(owner).units[src]): gs.player(owner).units[src].swift=true
		"enma-pressure":
			var body:=ghost(gs,owner)
			if not body.is_empty():
				var idx: int=gs._unit_index_by_uid(owner,str(body.uid))
				gs.resolution_stack.append({"kind":"enma-attack","playerIndex":owner,"sourceIndex":idx,"targetId":target_id,"options":{"pursuit":true,"combatCard":card,"enmaPressure":true}})
		"enma-awaken":
			gs._awaken(owner,src,card,effect.value)
			gs.VerifiedRules.Combat.grant_inspired(gs,owner,src)
		"enma-mirror": gs._deploy_realm(owner,card); refresh(gs)
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if not str(frame.get("kind","")).begins_with("enma-"): return false
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex)
	var u: Dictionary=gs.player(owner).units[src]
	match str(frame.kind):
		"enma-attack":
			if active(u): gs._resolve_combat(owner,src,0,false,false,false,false,frame.get("targetId"),false,frame.options)
		"enma-lord-growth":
			if active(u):
				gs._grow_unit(u,int(frame.amount),0)
				gs.VerifiedRules.event(gs,"enma-lord-growth",{"player":owner,"uid":u.uid,"ghostUid":frame.ghostUid,"amount":int(frame.amount)})
	return true
static func combat_finished(gs, owner: int, _src: int, options: Dictionary, kills: int) -> void:
	if options.get("enmaPressure",false) and kills>0: gs._draw(owner,1)
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("enmaRules",false): return null
	var src: int=gs._source_index(owner,card)
	if src<0: return -100
	if card.get("effect")=="enma-pressure":
		var u:=ghost(gs,owner); var victim: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return -100 if u.is_empty() or victim.is_empty() else 50+20*int(int(u.attack)>=int(victim.hp)+int(victim.shield))
	if card.get("effect")=="enma-steal":
		var victim: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return -100 if victim.is_empty() else 40+25*int(int(victim.hp)+int(victim.shield)<=3)
	if card.get("effect")=="enma-awaken": return 68
	if card.get("effect")=="enma-mirror": return 52
	if card.get("type")=="form": return 57 if gs.player(owner).units[src].get("form",{}).get("cardId")!=card.id else -30
	return -100
static func unit_view(u: Dictionary, view: Dictionary) -> Dictionary:
	if not u.get("enmaGhost",false): return view
	view.type="summon"; view.typeLabel="召唤物"; view.name="魂鬼"; view.keywords=["fusion"]
	for k in ["veil","pierce","unyielding"]:
		if has(u,k): view.keywords.append(k)
	view.text="融合。离开战斗区时移除。\n由阎魔替代出击召唤；融合保留原魂鬼状态。"
	return view
