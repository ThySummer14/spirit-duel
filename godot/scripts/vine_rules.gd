class_name VineRules
extends RefCounted
## 藤色是一个可融合、可迁移的灵咒永久物；数值来自灵咒而非永久成长。
const Content := preload("res://scripts/content_loader.gd")
static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("vineRules",false))
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false)
static func bonus(u: Dictionary) -> int:
	return int(u.get("vineCharm",{}).get("count",0))
static func master(gs, owner: int) -> int:
	for i in gs.player(owner).units.size():
		if source(gs.player(owner).units[i]) and active(gs.player(owner).units[i]): return i
	return -1
static func realm_count(gs, owner: int) -> int:
	return gs.player(owner).realms.filter(func(r):return r.get("nativeRealm")=="vine-millennium" and int(r.hp)>0).size()
static func detach(gs, owner: int, idx: int) -> Dictionary:
	var u: Dictionary=gs.player(owner).units[idx]
	var charm: Dictionary=u.get("vineCharm",{})
	if charm.is_empty(): return {}
	u.erase("vineCharm")
	# Removing the bonus keeps current HP up to the remaining maximum. It
	# does not subtract the health bonus a second time or transfer wounds.
	gs._recalc(u)
	return charm
static func attach(gs, owner: int, idx: int, count: int = 1, original: Dictionary = {}) -> void:
	if idx<0 or count<=0: return
	var p: Dictionary=gs.player(owner); var target: Dictionary=p.units[idx]
	if not active(target) and not target.get("vineConstructing",false): return
	var charm: Dictionary=original.duplicate(true)
	if charm.is_empty():
		charm={"uid":"vine-%s-%d" % [p.id,gs.next_card_id],"count":count,"owner":owner}
		gs.next_card_id+=1
	else: charm.count=count
	var old_units: Array=[]
	for old_idx in p.units.size():
		var old: Dictionary=p.units[old_idx]
		if old.get("removed",false) or old.get("vineCharm",{}).is_empty(): continue
		var old_charm: Dictionary
		if old_idx==idx:
			# Same-host fusion grows the existing carrier without an intermediate
			# health-cap drop; preserve wounds and add only the new layer.
			old_charm=old.vineCharm
			old.erase("vineCharm")
		else: old_charm=detach(gs,owner,old_idx)
		charm.count=int(charm.count)+int(old_charm.count)
		old_units.append(old_idx)
		gs.VerifiedRules.event(gs,"vine-fused",{"player":owner,"uid":charm.uid,"previousUid":old_charm.uid,"fromUid":old.uid,"toUid":target.uid,"count":charm.count})
	target.vineCharm=charm
	gs._recalc(target)
	if target.get("vineConstructing",false): target.hp=int(target.maxHp)
	gs.VerifiedRules.event(gs,"vine-attached",{"player":owner,"uid":target.uid,"charmUid":charm.uid,"count":charm.count,"fusionCount":int(charm.count)-1})
	for old_idx in old_units:
		if old_idx!=idx and int(p.units[old_idx].hp)<=0 and not p.units[old_idx].get("removed",false): gs._knockout_unit(p.units[old_idx])
static func remove_charm(gs, owner: int, idx: int, reason: String = "灵咒被移除", finish_unit: bool = true) -> Dictionary:
	var u: Dictionary=gs.player(owner).units[idx]
	if u.get("vineCharm",{}).is_empty(): return {}
	var src:=master(gs,owner)
	var can_return:=false
	if src>=0 and idx!=src:
		var m: Dictionary=gs.player(owner).units[src]
		can_return=(u.get("vineSummon",false) and m.get("formRules",{}).get("vineGarden",false)) or realm_count(gs,owner)>0
	var charm:=detach(gs,owner,idx)
	gs.VerifiedRules.event(gs,"vine-removed",{"player":owner,"uid":u.uid,"charmUid":charm.uid,"count":charm.count,"reason":reason})
	# A removed physical charm can be returned once, even if garden and
	# millennium both observe its removal. The transfer completes before the
	# next summon/effect attaches a fresh charm.
	if can_return and src>=0 and active(gs.player(owner).units[src]):
		attach(gs,owner,src,int(charm.count),charm)
		gs.VerifiedRules.event(gs,"vine-returned",{"player":owner,"fromUid":u.uid,"toUid":gs.player(owner).units[src].uid,"charmUid":charm.uid,"count":charm.count})
	if finish_unit and int(u.hp)<=0 and not u.get("removed",false): gs._knockout_unit(u)
	return charm
static func absorb_knockout(gs, owner: int, u: Dictionary) -> bool:
	if owner<0 or u.get("vineCharm",{}).is_empty() or u.get("removed",false): return false
	var idx: int=gs._unit_index_by_uid(owner,u.uid)
	remove_charm(gs,owner,idx,"替身",false)
	if int(u.maxHp)>0:
		u.hp=int(u.maxHp)
		gs.VerifiedRules.event(gs,"vine-substitute",{"player":owner,"uid":u.uid,"hp":u.hp})
		return true
	# A 0/0 phantom without any remaining HP support really leaves play.
	return false
static func knockout_snapshot(gs, owner: int, u: Dictionary) -> Array:
	if owner>=0 and not u.get("vineCharm",{}).is_empty(): remove_charm(gs,owner,gs._unit_index_by_uid(owner,u.uid),"随式神气绝",false)
	return []
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("vineSummon",false) or u.get("removed",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	remove_charm(gs,owner,gs._unit_index_by_uid(owner,u.uid),reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	if not u.get("vineSummon",false): return
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	gs.VerifiedRules.event(gs,"vine-phantom-died",{"player":owner,"uid":u.uid})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("vineSummon",false) and not u.get("vineConstructing",false) and int(u.front)==0 and not u.get("removed",false): remove_summon(gs,owner,u)
static func remove_front_summon(gs, owner: int, idx: int) -> void:
	var u: Dictionary=gs.player(owner).units[idx]
	# All callers reach the real token's own removal path. A cost/removal is
	# never a fake damage event and cannot be saved by substitute.
	if u.get("vineSummon",false): remove_summon(gs,owner,u,"作为解忧条件移除")
	else:
		remove_charm(gs,owner,idx,"召唤物被移除",false)
		if u.get("weaverSummon",false): gs.VerifiedRules.Weaver.remove_summon(gs,owner,u,"召唤物被移除")
		elif u.get("enmaGhost",false): gs.VerifiedRules.Enma.remove_summon(gs,owner,u,"召唤物被移除")
		elif u.get("pineSummon",false): gs.VerifiedRules.Pine.remove_summon(gs,owner,u,"召唤物被移除")
		elif u.get("paintSummon",false): gs.VerifiedRules.Paint.remove_summon(gs,owner,u,"召唤物被移除")
		elif u.get("tomatoFireSummon",false): gs.VerifiedRules.TomatoFire.remove_summon(gs,owner,u,"召唤物被移除")
		elif u.get("smokeClone",false): gs.VerifiedRules.SunSmoke.remove_clone(gs,owner,u,"召唤物被移除")
		elif u.get("iceWall",false): gs.VerifiedRules.Xuenv.remove_wall(gs,owner,u,"召唤物被移除")
		else: u.hp=0; u.front=0; u.knockout=0; u.removed=true
static func summon(gs, owner: int, src: int, count: int = 1, attack: int = 0, hp: int = 0) -> int:
	var p: Dictionary=gs.player(owner)
	# Replace the combat zone first. Returning the old phantom's charm then
	# precedes the fresh phantom's new fusion attachment.
	for i in p.units.size():
		var old: Dictionary=p.units[i]
		if int(old.front)!=1 or old.get("removed",false): continue
		if old.get("summoned",false): remove_front_summon(gs,owner,i)
		else:
			old.front=0; gs.VerifiedRules.Movement.moved(gs,owner,i,1)
	var u: Dictionary={"uid":"%s:vine-phantom-%d" % [p.id,gs.next_card_id],"id":"tengji-huanyi","name":"幻役","title":"藤姬召唤物","art":Content.unit_def("tengji").art,"color":"#a294c5","baseAttack":attack,"baseMaxHp":hp,"attack":attack,"maxHp":hp,"hp":hp,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"离开战斗区时移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"vineSummon":true,"removed":false,"vineConstructing":true,"summonerUid":p.units[src].uid}
	gs.next_card_id+=1; p.units.append(u)
	var idx: int=p.units.size()-1
	attach(gs,owner,idx,count)
	u.erase("vineConstructing")
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":u.summonerUid,"summonKind":"huanyi"})
	gs._fire_hooks(owner,idx,"unit-entered-front",{}); gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
	return idx
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("vineGarden",false): summon(gs,owner,src)
static func turn_start(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if not source(u) or not active(u): continue
		var target: int=src
		if u.awakened:
			var pool: Array=[]
			for idx in gs.player(owner).units.size():
				var t: Dictionary=gs.player(owner).units[idx]
				if active(t) and gs.VerifiedRules.OwlInsect.shikigami(t): pool.append(idx)
			if not pool.is_empty(): target=int(pool[gs.next_random()%pool.size()])
		attach(gs,owner,target)
static func before_attack(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.get("basicAttack",false): return
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or u.get("summoned",false): return
	for i in realm_count(gs,owner): attach(gs,owner,src)
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("vineRules",false) or card.get("effect") not in ["vine-attach","vine-relief","vine-night"]: return null
	var result: Array=[]
	for side in ([owner] if card.effect=="vine-attach" else [1-owner] if card.effect=="vine-night" else [owner,1-owner]):
		for u in gs.player(side).units:
			if not active(u) or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
			if card.effect=="vine-relief" and u.get("summoned",false): continue
			if side!=owner and (gs.VerifiedRules.Combat.has(u,"veil") or gs.VerifiedRules.Movement.has_veil(u)): continue
			result.append(str(u.uid))
	return result
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("vineRules",false): return true
	if card.get("effect")=="vine-relief":
		var idx: int=gs.front_index(owner)
		return idx>=0 and gs.player(owner).units[idx].get("summoned",false)
	if card.get("effect")=="vine-awaken":
		var src: int=gs._source_index(owner,card)
		return src>=0 and not gs.player(owner).units[src].awakened
	return true
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("vineRules",false): return card
	var out:=card.duplicate(true); var count:=0
	for u in gs.player(owner).units: count+=bonus(u)
	out.text+="\n场上藤色当前+%d/+%d；新结附会融合并转移原藤色。" % [count,count]
	return out
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, _target_id = null) -> bool:
	match str(effect.get("action","")):
		"vine-attach":
			var idx: int=gs._unit_index_by_uid(owner,target.get("uid",""))
			if idx>=0: attach(gs,owner,idx)
		"vine-phantom": summon(gs,owner,src)
		"vine-weave": summon(gs,owner,src,3)
		"vine-awaken":
			var u: Dictionary=gs.player(owner).units[src]
			u.awakened=true; u.passive_hooks=[]; attach(gs,owner,src)
		"vine-relief":
			var idx: int=gs.front_index(owner)
			if idx<0 or not gs.player(owner).units[idx].get("summoned",false): return true
			var victim: int=0 if gs._unit_index_by_uid(0,target.get("uid",""))>=0 else 1
			var t: int=gs._unit_index_by_uid(victim,target.get("uid",""))
			if t<0 or target.get("summoned",false): return true
			remove_front_summon(gs,owner,idx)
			gs.VerifiedRules.Panguan.destroy(gs,owner,src,victim,t,card)
		"vine-echo-destroy":
			# All three clauses remain valid without an enemy summon.
			gs.resolution_stack.append({"kind":"vine-echo-summon","playerIndex":owner,"sourceIndex":src})
			var all: Array=gs.player(1-owner).units.duplicate()
			for u in all:
				if u.get("summoned",false) and int(u.hp)>0: gs.VerifiedRules.Panguan.destroy(gs,owner,src,1-owner,gs._unit_index_by_uid(1-owner,u.uid),card)
		"vine-night":
			if not target.is_empty() and int(target.hp)>0: summon(gs,owner,src,1,int(target.attack),int(target.hp))
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner:=int(frame.get("playerIndex",0))
	match str(frame.get("kind","")):
		"vine-echo-summon":
			gs.resolution_stack.append({"kind":"vine-draw","playerIndex":owner})
			summon(gs,owner,int(frame.sourceIndex))
		"vine-draw": gs._draw(owner,1)
		_: return false
	return true
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]; var marks: Array=[]
	if bonus(u)>0: marks.append("藤色 +%d/+%d · 融合%d次 · 替身" % [bonus(u),bonus(u),bonus(u)-1])
	if u.get("vineSummon",false): marks.append("幻役 · 离开战斗区移除")
	return marks
static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("vineRules",false): return null
	var target: Dictionary={}
	for side in 2:
		var maybe: Dictionary=gs._unit_by_uid(gs.player(side).units,target_id)
		if not maybe.is_empty(): target=maybe
	match str(card.get("effect","")):
		"vine-relief": return -100 if target.is_empty() or gs._unit_index_by_uid(owner,target_id)>=0 or not can_use(gs,owner,card) else 65+int(target.attack)*4+int(target.hp)*2
		"vine-night": return -100 if target.is_empty() else 60+int(target.attack)*2+int(target.hp)*2
		"vine-attach": return 55 if not target.is_empty() and int(target.front)==1 else 35
		"vine-echo-destroy": return 70 if gs.player(1-owner).units.any(func(u):return u.get("summoned",false) and int(u.hp)>0) else 45
		"vine-awaken": return 65
		"realm": return 75
	return 55
