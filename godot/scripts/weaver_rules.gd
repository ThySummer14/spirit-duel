class_name WeaverRules
extends RefCounted
## 入殓师：真实召唤物、融合新实例、死亡墓地与召唤物复活。
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("weaverRules",false))
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)
static func basic_blocked(gs, u: Dictionary) -> bool:
	return u.get("weaverSummon",false) and int(u.get("weaverEntryTurn",-1))==gs.turn_counter
static func live_snow(gs, owner: int) -> int:
	for i in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[i]
		if u.get("weaverSummon",false) and int(u.hp)>0 and int(u.front)==1 and not u.get("removed",false): return i
	return -1
static func grave_snapshot(gs, u: Dictionary, reason: String) -> void:
	var saved:=u.duplicate(true)
	saved.erase("weaverGrave"); saved.erase("weaverReviveReason")
	saved.weaverStoredAura=gs.VerifiedRules.Enma.aura(gs,u)
	u.weaverGrave=saved; u.weaverReviveReason=reason
static func knockout_snapshot(gs, owner: int, u: Dictionary) -> Array:
	var frames: Array=[]
	if owner<0 or u.get("removed",false): return frames
	if u.get("summoned",false): grave_snapshot(gs,u,"knockout")
	var idx: int=gs._unit_index_by_uid(owner,u.uid)
	if source(u) and int(u.level)>0: frames.append({"kind":"weaver-summon","playerIndex":owner,"sourceIndex":idx})
	if int(u.front)!=1 or u.get("summoned",false) or not gs.VerifiedRules.OwlInsect.shikigami(u): return frames
	for src in gs.player(owner).units.size():
		var observer: Dictionary=gs.player(owner).units[src]
		if int(observer.level)>0 and not observer.get("baseRulesSuppressed",false) and (int(observer.hp)>0 or observer.uid==u.uid) and observer.get("formRules",{}).get("weaverCoffinBearer",false):
			frames.append({"kind":"weaver-summon","playerIndex":owner,"sourceIndex":src})
	return frames
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	if not u.get("weaverSummon",false): return
	# Generic summon death already marks removed before this callback.
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	gs.VerifiedRules.event(gs,"weaver-died",{"player":owner,"uid":u.uid})
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("weaverSummon",false) or u.get("removed",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	# Forced movement/removal does not pretend to be a knockout.
	u.erase("weaverGrave"); u.erase("weaverReviveReason")
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("weaverSummon",false) and int(u.front)==0 and int(u.hp)>0: remove_summon(gs,owner,u)
static func leave_front(gs, owner: int, except_index: int = -1) -> void:
	var p: Dictionary=gs.player(owner)
	for i in p.units.size():
		if i==except_index: continue
		var old: Dictionary=p.units[i]
		if old.get("removed",false) or int(old.hp)<=0: continue
		if old.get("rtSpear",false): gs.VerifiedRules.RabbitTide.remove_spear(gs,owner,old,"战斗区被替换")
		if old.get("mfDoll",false): gs.VerifiedRules.MusicFire.remove_doll(gs,owner,old)
		if old.get("efPowderBoxSummon",false): gs.VerifiedRules.EssenceFeast.remove_box(gs,owner,old)
		if old.get("scSummon",false): gs.VerifiedRules.SugarCat.remove_summon(gs,owner,old,"战斗区被替换")
		if old.get("arkFish",false): gs.VerifiedRules.Arakawa.remove_fish(gs,owner,old)
		if old.get("boxSummon",false): gs.VerifiedRules.BoxMaiden.remove_summon(gs,owner,old,"战斗区被替换")
		if old.get("dollSummon",false): gs.VerifiedRules.Doll.remove_summon(gs,owner,old,"战斗区被替换")
		if old.get("houseSummon",false): gs.VerifiedRules.House.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("vineSummon",false): gs.VerifiedRules.Vine.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("windRaccoonClone",false): gs.VerifiedRules.WindRaccoon.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("weaverSummon",false): remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("whaleGuardian",false): gs.VerifiedRules.Whale.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("jorogumoSwarm",false): gs.VerifiedRules.Jorogumo.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("toxicSwarm",false): gs.VerifiedRules.Toxic.remove_swarm(gs,owner,old)
		elif old.get("enmaGhost",false): gs.VerifiedRules.Enma.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("pineSummon",false): gs.VerifiedRules.Pine.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("paintSummon",false): gs.VerifiedRules.Paint.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("tomatoFireSummon",false): gs.VerifiedRules.TomatoFire.remove_summon(gs,owner,old,"战斗区被替换")
		elif old.get("smokeClone",false): gs.VerifiedRules.SunSmoke.remove_clone(gs,owner,old,"战斗区被替换")
		elif old.get("iceWall",false): gs.VerifiedRules.Xuenv.remove_wall(gs,owner,old,"战斗区被替换")
		else:
			var before:=int(old.front); old.front=0
			gs.VerifiedRules.Movement.moved(gs,owner,i,before)
	gs.VerifiedRules.Bamboo.remove_departed(gs)
static func token(gs, owner: int, src: int, attack: int = 3, hp: int = 3) -> Dictionary:
	var p: Dictionary=gs.player(owner)
	var bonus:=int(p.get("weaverPermanent",0))
	var u: Dictionary={"uid":"%s:weaver-%d" % [p.id,gs.next_card_id],"id":"rulianshi-zhixue","name":"织雪","title":"入殓师召唤物","art":Content.unit_def("rulianshi").art,"color":"#af97cf","baseAttack":attack,"baseMaxHp":hp,"attack":attack+bonus,"maxHp":hp+bonus,"hp":hp+bonus,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":bonus,"maxHpBonus":bonus,"awakened":false,"form":{},"formRules":{},"formAbility":"融合。进场或融合的回合不能出击。离开战斗区移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"weaverSummon":true,"weaverFusionCount":0,"weaverEntryTurn":gs.turn_counter,"weaverAppliedBonus":bonus,"summonerUid":str(p.units[src].uid) if src>=0 and src<p.units.size() else "rulianshi"}
	gs.next_card_id+=1
	return u
static func combine(gs, owner: int, incoming: Dictionary, old_index: int, incoming_index: int = -1) -> int:
	var p: Dictionary=gs.player(owner); var old: Dictionary=p.units[old_index]
	var result:=old.duplicate(true)
	result.erase("weaverGrave"); result.erase("weaverReviveReason")
	result.uid="%s:weaver-fusion-%d" % [p.id,gs.next_card_id]; gs.next_card_id+=1
	gs.VerifiedRules.Otakemaru.fused(old,result)
	gs.VerifiedRules.Otakemaru.fused(incoming,result)
	# Keep the old instance's modifiers and add the incoming current body.
	var incoming_aura: int=gs.VerifiedRules.Enma.aura(gs,incoming)
	result.baseAttack=int(result.baseAttack)+int(incoming.attack)-incoming_aura
	result.baseMaxHp=int(result.baseMaxHp)+int(incoming.maxHp)-incoming_aura
	result.attack=int(old.attack)+int(incoming.attack)-incoming_aura
	result.maxHp=int(old.maxHp)+int(incoming.maxHp)-incoming_aura
	result.hp=int(old.hp)+int(incoming.hp)-incoming_aura
	result.weaverFusionCount=int(old.get("weaverFusionCount",0))+int(incoming.get("weaverFusionCount",0))+1
	result.weaverEntryTurn=gs.turn_counter; result.front=1; result.removed=false; result.knockout=0
	result.weaverAppliedBonus=int(p.get("weaverPermanent",0))
	for key in ["shield","armorBreak","brittle","charge"]: result[key]=int(old.get(key,0))+int(incoming.get(key,0))
	result.frozen=maxi(int(old.get("frozen",0)),int(incoming.get("frozen",0)))
	for key in ["swift","unyielding","inspired"]:
		if old.get(key,false) or incoming.get(key,false): result[key]=true
	var keywords: Array=old.get("keywords",[]).duplicate()
	for key in incoming.get("keywords",[]):
		if not keywords.has(key): keywords.append(key)
	result.keywords=keywords
	old.erase("vineCharm")
	grave_snapshot(gs,old,"fusion"); old.hp=0; old.front=0; old.knockout=0; old.removed=true
	if incoming_index>=0:
		grave_snapshot(gs,incoming,"fusion"); incoming.hp=0; incoming.front=0; incoming.knockout=0; incoming.removed=true
	p.units.append(result)
	var idx: int=p.units.size()-1
	gs.VerifiedRules.event(gs,"weaver-fused",{"player":owner,"uid":result.uid,"previousUid":old.uid,"incomingUid":incoming.uid,"count":result.weaverFusionCount})
	entered(gs,owner,idx)
	return idx
static func entered(gs, owner: int, idx: int) -> void:
	var u: Dictionary=gs.player(owner).units[idx]
	gs.VerifiedRules.Enma.refresh(gs)
	gs._fire_hooks(owner,idx,"unit-entered-front",{}); gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
static func summon(gs, owner: int, src: int, attack: int = 3, hp: int = 3) -> int:
	var u:=token(gs,owner,src,attack,hp); var old:=live_snow(gs,owner)
	if old>=0: return combine(gs,owner,u,old)
	leave_front(gs,owner)
	gs.player(owner).units.append(u)
	var idx: int=gs.player(owner).units.size()-1
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":u.summonerUid,"summonKind":"zhixue"})
	entered(gs,owner,idx)
	return idx
static func sync_permanent(gs, owner: int) -> void:
	var bonus:=int(gs.player(owner).get("weaverPermanent",0))
	for u in gs.player(owner).units:
		if not u.get("weaverSummon",false): continue
		var applied:=int(u.get("weaverAppliedBonus",0))
		if int(u.hp)>0 and not u.get("removed",false):
			gs._grow_unit(u,bonus-applied,bonus-applied); u.weaverAppliedBonus=bonus
		if u.has("weaverGrave"):
			var saved: Dictionary=u.weaverGrave; var delta:=bonus-int(saved.get("weaverAppliedBonus",0))
			saved.attackBonus=int(saved.attackBonus)+delta; saved.maxHpBonus=int(saved.maxHpBonus)+delta
			saved.attack=int(saved.attack)+delta; saved.maxHp=int(saved.maxHp)+delta; saved.hp=int(saved.hp)+delta; saved.weaverAppliedBonus=bonus
static func revive_candidates(gs, owner: int) -> Array:
	var pool: Array=[]; var highest: int=-2147483648
	for idx in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[idx]
		if int(u.hp)>0 or not u.get("summoned",false) or not u.has("weaverGrave") or u.get("weaverReviveReason","") not in ["knockout","fusion"]: continue
		var strength:=int(u.weaverGrave.attack)
		if strength>highest: highest=strength; pool.clear()
		if strength==highest: pool.append(idx)
	return pool
static func revive(gs, owner: int, idx: int) -> int:
	var u: Dictionary=gs.player(owner).units[idx]
	if not u.has("weaverGrave"): return -1
	var restored: Dictionary=u.weaverGrave.duplicate(true)
	var old:=live_snow(gs,owner) if restored.get("weaverSummon",false) else -1
	u.clear(); u.merge(restored,true)
	u.hp=int(u.maxHp); u.front=1; u.removed=false; u.knockout=0; u.shield=0; u.frozen=0; u.brittle=0; u.armorBreak=0
	u.erase("weaverGrave"); u.erase("weaverReviveReason")
	for key in ["enmaDeathRecorded","enmaRemovalRecorded","enmaMercyPresent","enmaFused","pineLeaveResolved","windRaccoonFused","windRaccoonRemoval"]: u.erase(key)
	gs._recalc(u); u.hp=int(u.maxHp)
	if u.get("weaverSummon",false): u.weaverEntryTurn=gs.turn_counter
	gs.VerifiedRules.event(gs,"summon-revived",{"player":owner,"uid":u.uid,"index":idx})
	if old>=0 and old!=idx: return combine(gs,owner,u,old,idx)
	if u.get("windRaccoonClone",false):
		var fused: int=gs.VerifiedRules.WindRaccoon.fuse_revived(gs,owner,idx)
		if fused>=0: return fused
	if u.get("enmaGhost",false):
		var fused: int=gs.VerifiedRules.Enma.fuse_revived(gs,owner,idx)
		if fused>=0: return fused
	if u.get("pineSummon",false):
		for other_idx in gs.player(owner).units.size():
			var other: Dictionary=gs.player(owner).units[other_idx]
			if other_idx!=idx and other.get("pineSummon",false) and int(other.hp)>0 and not other.get("removed",false): return revive_pine_fusion(gs,owner,idx,other_idx)
	if u.get("scCandy",false):
		var candy_fused: int=gs.VerifiedRules.SugarCat.fuse_revived(gs,owner,idx)
		if candy_fused>=0:return candy_fused
	var ef_fused:int=gs.VerifiedRules.EssenceFeast.fuse_revived(gs,owner,idx)
	if ef_fused>=0:return ef_fused
	gs.VerifiedRules.SugarCat.revived(gs,owner,idx)
	leave_front(gs,owner,idx)
	if u.get("pineSummon",false): u.erase("pineLeaveResolved")
	gs.VerifiedRules.Movement.revived(gs,owner,idx)
	entered(gs,owner,idx)
	return idx
static func revive_pine_fusion(gs, owner: int, idx: int, old_index: int) -> int:
	var p: Dictionary=gs.player(owner); var incoming: Dictionary=p.units[idx]; var old: Dictionary=p.units[old_index]
	var old_hp:=int(old.hp); var incoming_hp:=int(incoming.hp); var aura: int=gs.VerifiedRules.Enma.aura(gs,incoming)
	var attack:=int(incoming.attack)-aura; var max_hp:=int(incoming.maxHp)-aura
	var states:=incoming.duplicate(true)
	grave_snapshot(gs,incoming,"fusion"); incoming.hp=0; incoming.front=0; incoming.knockout=0; incoming.removed=true
	# Use Pine's established fusion entry, replacing its default 4/4 material
	# with the revived body's actual stats. Do not overwrite the living token.
	var master: int=gs._unit_index_by_uid(owner,str(incoming.get("summonerUid","")))
	if master<0: master=0
	var result: int=gs.VerifiedRules.Pine.summon(gs,owner,master)
	gs._grow_unit(old,attack-4,max_hp-4)
	old.hp=old_hp+incoming_hp-aura
	for key in ["shield","armorBreak","brittle","charge"]: old[key]=int(old.get(key,0))+int(states.get(key,0))
	old.frozen=maxi(int(old.frozen),int(states.get("frozen",0)))
	for key in ["swift","unyielding","inspired"]:
		if states.get(key,false): old[key]=true
	if not old.has("keywords"): old.keywords=[]
	for key in states.get("keywords",[]):
		if not old.keywords.has(key): old.keywords.append(key)
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"pine-revived-fused",{"player":owner,"uid":old.uid,"materialUid":incoming.uid,"attack":old.attack,"hp":old.hp})
	return result
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("weaverRules",false) or card.get("effect")!="weaver-exile": return null
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("weaverRules",false): return true
	if card.get("effect")=="weaver-mourn":
		var idx: int=gs.front_index(owner)
		return idx>=0 and gs.player(owner).units[idx].get("summoned",false) and not gs.player(owner).units[idx].get("cannotAttack",false) and not gs.VerifiedRules.Stun.blocks(gs,owner,gs.player(owner).units[idx])
	if card.get("effect")=="weaver-revive": return not revive_candidates(gs,owner).is_empty()
	return true
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("weaverRules",false): return card
	var out:=card.duplicate(true); var idx:=live_snow(gs,owner)
	if card.get("effect")=="weaver-funeral": out.text+="\n当前织雪已融合%d次；本次召唤后按实际融合次数结算。" % (int(gs.player(owner).units[idx].weaverFusionCount) if idx>=0 else 0)
	if card.get("effect")=="weaver-coffin": out.text+="\n当前牌手生命%d，永久强化+%d/+%d。" % [int(gs.player(owner).avatarHp),int(gs.player(owner).get("weaverPermanent",0)),int(gs.player(owner).get("weaverPermanent",0))]
	if card.get("effect")=="weaver-revive": out.text+="\n当前可复活的最高力量召唤物%d个。" % revive_candidates(gs,owner).size()
	return out
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, _target_id = null) -> bool:
	match str(effect.get("action","")):
		"weaver-summon": summon(gs,owner,src)
		"weaver-mourn":
			var idx: int=gs.front_index(owner)
			if idx>=0 and gs.player(owner).units[idx].get("summoned",false): gs._resolve_combat(owner,idx,1,false,false,false,false,null,false,{"immuneCombat":true})
		"weaver-revive":
			var pool:=revive_candidates(gs,owner)
			if not pool.is_empty(): revive(gs,owner,int(pool[gs.next_random()%pool.size()]))
		"weaver-awaken":
			gs.player(owner).units[src].awakened=true; gs.player(owner).units[src].passive_hooks=[]
			gs.resolution_stack.append({"kind":"weaver-permanent","playerIndex":owner})
			summon(gs,owner,src)
		"weaver-exile":
			var idx: int=gs._unit_index_by_uid(1-owner,target.get("uid",""))
			if idx>=0 and int(target.hp)>0:
				gs.resolution_stack.append({"kind":"weaver-exile-gift","playerIndex":1-owner,"sourceIndex":-1})
				gs.VerifiedRules.Panguan.destroy(gs,owner,src,1-owner,idx,card)
		"weaver-funeral":
			var depth: int=gs.resolution_stack.size()
			var idx:=summon(gs,owner,src)
			# Snapshot the current fused body now; entry responses resolve first.
			var frame: Dictionary={"kind":"weaver-funeral-wave","playerIndex":owner,"sourceIndex":src,"remaining":1+int(gs.player(owner).units[idx].get("weaverFusionCount",0))}
			gs.resolution_stack.insert(depth,frame)
		"weaver-coffin":
			var hp:=int(gs.player(owner).avatarHp); summon(gs,owner,src,hp,hp)
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner:=int(frame.get("playerIndex",0)); var src:=int(frame.get("sourceIndex",-1))
	match str(frame.get("kind","")):
		"weaver-summon": summon(gs,owner,src)
		"weaver-permanent":
			gs.player(owner).weaverPermanent=int(gs.player(owner).get("weaverPermanent",0))+1
			sync_permanent(gs,owner)
			gs.VerifiedRules.event(gs,"weaver-permanent-gained",{"player":owner,"amount":gs.player(owner).weaverPermanent})
		"weaver-exile-gift":
			gs.resolution_stack.append({"kind":"weaver-enemy-draw","playerIndex":owner})
			summon(gs,owner,src)
		"weaver-enemy-draw": gs._draw(owner,1)
		"weaver-funeral-wave":
			if gs.winner>=0: return true
			var remaining:=int(frame.remaining)
			if remaining>1:
				var next:=frame.duplicate(true); next.remaining=remaining-1; gs.resolution_stack.append(next)
			var targets: Array=gs.player(1-owner).units.map(func(u):return str(u.uid))
			gs.resolution_stack.append({"kind":"weaver-wave-avatar","playerIndex":owner,"sourceIndex":src})
			for i in range(targets.size()-1,-1,-1): gs.resolution_stack.append({"kind":"weaver-wave-unit","playerIndex":owner,"sourceIndex":src,"targetUid":targets[i]})
			gs.VerifiedRules.event(gs,"weaver-funeral-wave",{"player":owner,"remaining":remaining})
		"weaver-wave-unit":
			var idx: int=gs._unit_index_by_uid(1-owner,frame.targetUid)
			if idx>=0 and int(gs.player(1-owner).units[idx].hp)>0: gs._damage_unit(1-owner,idx,2,owner,src)
		"weaver-wave-avatar": gs._damage_avatar(1-owner,2,owner,src)
		_: return false
	return true
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]; var marks: Array=[]
	if source(u): marks.append("织雪永久强化 +%d/+%d" % [int(gs.player(owner).get("weaverPermanent",0)),int(gs.player(owner).get("weaverPermanent",0))])
	if u.get("weaverSummon",false):
		marks.append("织雪 · 已融合%d次" % int(u.get("weaverFusionCount",0)))
		if basic_blocked(gs,u) and int(u.hp)>0: marks.append("本回合进场或融合，不能普通出击；其他效果可以令其攻击")
	return marks
static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("weaverRules",false): return null
	match str(card.get("effect","")):
		"weaver-revive":
			var pool:=revive_candidates(gs,owner)
			return -100 if pool.is_empty() else 50+int(gs.player(owner).units[pool[0]].weaverGrave.attack)
		"weaver-mourn": return 70 if can_use(gs,owner,card) else -100
		"weaver-exile":
			var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,target_id)
			return -100 if target.is_empty() else 30+int(target.attack)*5+int(target.hp)*3
		"weaver-funeral": return 80
		"weaver-coffin": return 55+int(gs.player(owner).avatarHp)
		"weaver-awaken": return 65
		"form": return 60
	return 50
