class_name WindRaccoonRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return not u.get("windRaccoonClone",false) and Content.runtime_unit_def(u).get("windRaccoonRules",false)
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func clone(gs, owner: int, summoner: String = "") -> Dictionary:
	for u in gs.player(owner).units:
		if u.get("windRaccoonClone",false) and active(u) and int(u.front)==1 and (summoner.is_empty() or u.get("summonerUid")==summoner): return u
	return {}
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("windRaccoonClone",false) or u.get("windRaccoonRemoval",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	var idx: int=gs._unit_index_by_uid(owner,str(u.uid))
	if idx>=0: gs.VerifiedRules.Vine.remove_charm(gs,owner,idx,reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true; u.windRaccoonRemoval=true
	gs.VerifiedRules.event(gs,"wind-raccoon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("windRaccoonClone",false) and (int(u.hp)<=0 or int(u.front)==0): remove_summon(gs,owner,u)
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	remove_summon(gs,owner,u,"分身气绝")
static func damaged(gs, owner: int, idx: int, source_owner: int, source_index: int, taken: int, prior_armor_break: int = -1) -> bool:
	var u: Dictionary=gs.player(owner).units[idx]
	if taken<=0 or not u.get("windRaccoonClone",false) or not active(u): return false
	gs.VerifiedRules.event(gs,"wind-raccoon-self-destruct",{"player":owner,"uid":u.uid,"damage":taken})
	# Damage has already resolved. Self-destruction is a real knockout; the
	# ordinary lethal path has finished and cannot count the same death twice.
	gs._knockout_unit(u,source_owner,source_index,-1,prior_armor_break)
	return int(u.hp)<=0
static func summon(gs, owner: int, src: int, attack: int, hp: int) -> int:
	if hp<=0: return -1
	var p: Dictionary=gs.player(owner)
	var master: Dictionary=p.units[src]
	var old:=clone(gs,owner,str(master.uid))
	var old_uid:=str(old.get("uid",""))
	var body: Dictionary
	if not old.is_empty():
		body=old.duplicate(true)
		body.baseAttack=int(body.baseAttack)+attack; body.baseMaxHp=int(body.baseMaxHp)+hp
		body.erase("weaverGrave"); body.erase("weaverReviveReason")
		old.erase("vineCharm")
		old.hp=0; old.front=0; old.knockout=0; old.removed=true; old.windRaccoonFused=true; old.windRaccoonRemoval=true
	else:
		body={"id":"fengli-fenshen","name":"分身·风狸","title":"风狸召唤物","art":Content.unit_def("fengli").art,"color":"#5a9a7a","baseAttack":attack,"baseMaxHp":hp,"attack":attack,"maxHp":hp,"hp":hp,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formHooks":[],"formAbility":"融合。受到伤害后自毁。离开战斗区时移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"windRaccoonClone":true,"keywords":["fusion"],"swift":false}
	body.uid="%s:wind-raccoon-%d" % [p.id,gs.next_card_id]; gs.next_card_id+=1
	gs.VerifiedRules.Otakemaru.fused(old,body)
	body.summonerUid=master.uid; body.removed=false; body.windRaccoonRemoval=false; body.front=1
	body.erase("windRaccoonFused")
	gs.VerifiedRules.Weaver.leave_front(gs,owner)
	p.units.append(body)
	var idx: int=p.units.size()-1
	gs._recalc(body); gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"wind-raccoon-fused" if not old.is_empty() else "wind-raccoon-summoned",{"player":owner,"uid":body.uid,"previousUid":old_uid,"sourceUid":master.uid,"attack":body.attack,"hp":body.hp})
	gs._fire_hooks(owner,idx,"unit-entered-front",{}); gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",body.uid,{"kind":"response-complete"})
	return idx
static func fuse_revived(gs, owner: int, idx: int) -> int:
	var p: Dictionary=gs.player(owner); var incoming: Dictionary=p.units[idx]
	if not incoming.get("windRaccoonClone",false): return -1
	incoming.windRaccoonRemoval=false; incoming.erase("windRaccoonFused")
	gs._recalc(incoming)
	var old: Dictionary={}
	for i in p.units.size():
		var candidate: Dictionary=p.units[i]
		if i!=idx and candidate.get("windRaccoonClone",false) and active(candidate) and int(candidate.front)==1 and candidate.get("summonerUid")==incoming.get("summonerUid"):
			old=candidate; break
	if old.is_empty(): return -1
	var body:=old.duplicate(true)
	for key in ["baseAttack","baseMaxHp","attackBonus","maxHpBonus","cranePower","permanentAttack","temporaryAttack","judgeInkAttack","judgeInkHp","foxPillow","dreamPowerPenalty","insectCorrosion","windStoredPower"]:
		body[key]=int(old.get(key,0))+int(incoming.get(key,0))
	var aura: int=gs.VerifiedRules.Enma.mirror_count(gs,owner)
	var old_charm: Dictionary=old.get("vineCharm",{})
	var incoming_charm: Dictionary=incoming.get("vineCharm",{})
	if old_charm.is_empty() and not incoming_charm.is_empty(): body.vineCharm=incoming_charm.duplicate(true)
	var duplicate_charm:=int(incoming_charm.get("count",0)) if not old_charm.is_empty() else 0
	body.attack=int(old.attack)+int(incoming.attack)-aura-duplicate_charm
	body.maxHp=int(old.maxHp)+int(incoming.maxHp)-aura-duplicate_charm
	body.hp=int(old.hp)+int(incoming.hp)-aura-duplicate_charm
	body.shield=int(old.shield)+int(incoming.shield)
	for key in ["frozen","brittle","armorBreak"]: body[key]=maxi(int(old.get(key,0)),int(incoming.get(key,0)))
	for key in ["swift","inspired","barrier","unyielding","enraged"]: body[key]=bool(old.get(key,false)) or bool(incoming.get(key,false))
	for key in ["keywords","stunOwners"]:
		var values: Array=old.get(key,[]).duplicate(true)
		for value in incoming.get(key,[]):
			if not values.has(value): values.append(value)
		body[key]=values
	body.uid="%s:wind-raccoon-%d" % [p.id,gs.next_card_id]; gs.next_card_id+=1
	gs.VerifiedRules.Otakemaru.fused(old,body)
	gs.VerifiedRules.Otakemaru.fused(incoming,body)
	body.front=1; body.removed=false; body.windRaccoonRemoval=false
	body.erase("weaverGrave"); body.erase("weaverReviveReason"); body.erase("windRaccoonFused")
	for previous in [old,incoming]:
		previous.erase("vineCharm")
		previous.hp=0; previous.front=0; previous.knockout=0; previous.removed=true; previous.windRaccoonFused=true; previous.windRaccoonRemoval=true
	p.units.append(body)
	var fused: int=p.units.size()-1
	gs._recalc(body); gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"wind-raccoon-fused",{"player":owner,"uid":body.uid,"previousUid":old.uid,"incomingUid":incoming.uid,"revived":true,"attack":body.attack,"hp":body.hp})
	gs._fire_hooks(owner,fused,"unit-entered-front",{}); gs._run_form_hooks(owner,fused,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",body.uid,{"kind":"response-complete"})
	return fused
static func queue_summon(gs, owner: int, src: int, attack: int, hp: int, attack_after: bool, reason: String) -> void:
	var master: Dictionary=gs.player(owner).units[src]
	var frames: Array=[]
	var count:=2 if master.get("formRules",{}).get("windRaccoonSix",false) and active(master) else 1
	for i in count: frames.append({"kind":"wind-raccoon-summon","playerIndex":owner,"sourceIndex":src,"attack":attack,"hp":hp,"reason":reason,"ordinal":i+1})
	if attack_after: frames.append({"kind":"wind-raccoon-attack-current","playerIndex":owner,"sourceIndex":src,"summonerUid":str(master.uid)})
	frames.reverse(); gs.resolution_stack.append_array(frames)
static func avatar_damaged(gs, owner: int, src: int, victim: int, actual_loss: int) -> void:
	if owner<0 or src<0 or owner==victim or actual_loss<=0: return
	var u: Dictionary=gs.player(owner).units[src]
	if source(u) and active(u) and not u.awakened: queue_summon(gs,owner,src,2,3,true,"基础牌手伤害")
static func prepare_combat(gs, owner: int, src: int, options: Dictionary) -> Dictionary:
	var out:=options.duplicate(true)
	var u: Dictionary=gs.player(owner).units[src]
	if source(u) and active(u) and u.awakened and out.get("basicAttack",false): out.immuneCombat=true
	return out
static func combat_finished(gs, owner: int, src: int, _options: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if source(u) and active(u) and u.awakened: queue_summon(gs,owner,src,int(u.attack),int(u.hp),true,"觉醒攻击后")
static func targets(_gs, _owner: int, _card: Dictionary):
	return null
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("windRaccoonRules",false): return true
	if card.get("effect")=="wind-raccoon-token": return false
	var src: int=gs._source_index(owner,card)
	return src>=0 and not (card.get("effect")=="wind-raccoon-awaken" and gs.player(owner).units[src].awakened)
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("windRaccoonRules",false): return card
	var out:=card.duplicate(true)
	var front: Dictionary=gs.front_unit(owner)
	var enhanced: bool=not front.is_empty() and front.get("summoned",false)
	if card.get("combatOption",{}).get("windSubstitute",false) or card.get("combatOption",{}).get("windHide",false): out.windEnhanced=enhanced
	if card.get("combatOption",{}).get("windSubstitute",false): out.currentCardStats="增强：先令战斗区召唤物攻击" if enhanced else "增强未满足：没有战斗区召唤物"
	if card.get("combatOption",{}).get("windHide",false): out.currentCardStats="本次战斗+3护甲"+(" · 获得真实分身术" if enhanced else " · 增强未满足")
	if card.get("effect")=="wind-raccoon-summon":
		var src: int=gs._source_index(owner,card)
		if src>=0: out.currentCardStats="本次分身%d力量/%d生命" % [gs.player(owner).units[src].attack,gs.player(owner).units[src].hp]
	return out
static func assault(gs, owner: int, src: int, card: Dictionary, target_id = null) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u): return
	var options: Dictionary=card.get("combatOption",{}).duplicate(true); options.combatCard=card
	gs._grant_unit_armor(u,int(options.get("shield",0)))
	gs._record("assault",{"unit":src,"bonus":int(card.value),"target":target_id},owner)
	gs._resolve_combat(owner,src,int(card.value),card.keywords.has("pierce"),card.keywords.has("remote"),card.keywords.has("combo"),card.keywords.has("first-strike"),target_id,false,options)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id = null) -> bool:
	var u: Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"wind-raccoon-token": queue_summon(gs,owner,src,2,3,false,"派生召唤入口")
		"wind-raccoon-summon": queue_summon(gs,owner,src,int(u.attack),int(u.hp),false,"分身术")
		"wind-raccoon-awaken": gs._awaken(owner,src,card,effect.value); u.swift=true
		"wind-raccoon-combat":
			var options: Dictionary=card.get("combatOption",{})
			var front: Dictionary=gs.front_unit(owner)
			var enhanced: bool=not front.is_empty() and front.get("summoned",false)
			var depth: int=gs.resolution_stack.size()
			if options.get("windHide",false) and enhanced:
				gs.player(owner).hand.append({"instanceId":"wind-raccoon-card-%d" % gs.next_card_id,"definitionId":"c23203"}); gs.next_card_id+=1
				gs.VerifiedRules.event(gs,"wind-raccoon-generated",{"player":owner,"uid":u.uid,"cardId":"c23203"})
			gs.resolution_stack.append({"kind":"wind-raccoon-source-assault","playerIndex":owner,"sourceIndex":src,"card":card,"targetId":target_id})
			if options.get("windSubstitute",false) and enhanced:
				gs.resolution_stack.append({"kind":"wind-raccoon-extra-assault","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,str(front.uid))})
			if options.get("windBomb",false):
				# Its printed noncombat damage precedes the source's battle. Any
				# base ability summons resolve before the source-assault frame.
				gs._damage_avatar(1-owner,2,owner,src)
			gs.VerifiedRules.event(gs,"wind-raccoon-card-sequence",{"player":owner,"uid":u.uid,"card":card,"enhanced":enhanced,"depth":depth})
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if not str(frame.get("kind","")).begins_with("wind-raccoon-"): return false
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex)
	var u: Dictionary=gs.player(owner).units[src]
	match str(frame.kind):
		"wind-raccoon-summon": summon(gs,owner,src,int(frame.attack),int(frame.hp))
		"wind-raccoon-attack-current":
			var body:=clone(gs,owner,str(frame.summonerUid))
			if not body.is_empty(): gs._resolve_combat(owner,gs._unit_index_by_uid(owner,str(body.uid)),0,false,false,false,false,null,false,{"windRaccoonAttack":true})
		"wind-raccoon-extra-assault":
			if active(u): gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"windRaccoonExtra":true})
		"wind-raccoon-source-assault": assault(gs,owner,src,frame.card,frame.get("targetId"))
	return true
static func score_card(gs, owner: int, card: Dictionary, _target_id):
	if not card.get("windRaccoonRules",false): return null
	var src: int=gs._source_index(owner,card)
	if src<0: return -100
	if card.get("effect")=="wind-raccoon-awaken": return 72
	if card.get("effect")=="wind-raccoon-summon": return 45+int(gs.player(owner).units[src].attack)*2
	if card.get("type")=="form": return 60 if gs.player(owner).units[src].get("form",{}).get("cardId")!=card.id else -25
	if card.get("type")=="combat": return 48+(20 if card.get("windEnhanced",false) else 0)+(8 if card.keywords.has("direct") else 0)
	return -100
static func unit_view(u: Dictionary, view: Dictionary) -> Dictionary:
	if not u.get("windRaccoonClone",false): return view
	view.name="分身·风狸"; view.type="summon"; view.typeLabel="召唤物"; view.keywords=["fusion"]
	view.text="融合。受到伤害后自毁。离开战斗区时移除。\n本体能力与觉醒不会被复制给分身。"
	return view
