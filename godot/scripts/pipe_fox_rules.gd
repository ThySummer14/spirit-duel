class_name PipeFoxRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp",0))>0 and int(unit.get("level",0))>0 and not unit.get("baseRulesSuppressed",false)

static func role(unit: Dictionary) -> String:
	return str(Content.runtime_unit_def(unit).get("pipeFoxRole",""))

static func mark(gs, owner: int, src: int, victim: int, idx: int) -> void:
	if idx<0: return
	var unit: Dictionary=gs.player(victim).units[idx]
	if int(unit.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(unit): return
	if not unit.has("pipeMarks"): unit.pipeMarks=[]
	unit.pipeMarks.append({"owner":owner,"sourceUid":gs.player(owner).units[src].uid,"serial":gs.next_rule_event_id})
	gs.VerifiedRules.event(gs,"pipe-mark-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":unit.uid,"victimPlayer":victim,"count":unit.pipeMarks.size()})

static func mark_count(gs, owner: int) -> int:
	var count := 0
	for unit in gs.player(1-owner).units:
		if int(unit.hp)>0: count+=unit.get("pipeMarks",[]).filter(func(m):return int(m.owner)==owner).size()
	return count

static func countdown(gs, owner: int, src: int, mode: String, base_ability: bool = false) -> void:
	var frames: Array=[]; var victim := 1-owner
	if mode=="bomb":
		var count := mark_count(gs,owner)
		for unit in gs.player(victim).units: unit.pipeMarks=unit.get("pipeMarks",[]).filter(func(m):return int(m.owner)!=owner)
		for unit in gs.player(victim).units:
			if int(unit.hp)>0: frames.append({"kind":"pipe-hit","playerIndex":owner,"sourceIndex":src,"targetUid":unit.uid,"amount":10+2*count})
		frames.append({"kind":"pipe-hit","playerIndex":owner,"sourceIndex":src,"targetUid":"avatar-%d" % victim,"amount":10+2*count})
	else:
		var amount := 5 if mode=="bamboo" else 2
		var target := "avatar-%d" % victim if mode=="bamboo" else ""
		if mode=="random":
			var pool: Array=gs.player(victim).units.filter(func(u):return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u))
			if not pool.is_empty(): target=str(pool[int(floor(gs.randf01()*pool.size()))].uid)
		elif mode=="front":
			var idx: int=gs.front_index(victim)
			if idx>=0 and gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]): target=str(gs.player(victim).units[idx].uid)
		if target!="": frames.append({"kind":"pipe-hit","playerIndex":owner,"sourceIndex":src,"targetUid":target,"amount":amount,"baseAbility":base_ability and mode in ["random","front"]})
		for unit in gs.player(victim).units:
			if int(unit.hp)<=0: continue
			for entry in unit.get("pipeMarks",[]):
				if int(entry.owner)==owner: frames.append({"kind":"pipe-mark-hit","playerIndex":owner,"sourceIndex":src,"targetUid":unit.uid,"amount":amount,"serial":int(entry.serial)})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func form_removed(unit: Dictionary) -> void:
	if unit.get("formRules",{}).get("pipeMode")=="bomb": unit.pipeBombRemaining=int(unit.get("formCountdown",{}).get("remaining",9))

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var unit: Dictionary=gs.player(owner).units[src]
	if card.get("formRules",{}).get("pipeMode")=="bomb" and unit.has("pipeBombRemaining"): unit.formCountdown.remaining=int(unit.pipeBombRemaining)
	if card.get("formRules",{}).get("foxCleanse",false): cleanse(gs,owner,src)

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("pipeFoxRules",false): return card
	var out := card.duplicate(true)
	if card.get("effect")=="assault" and card.get("pipeMarkBonus",false):
		out.value=int(card.value)+2*mark_count(gs,owner); out.effects[0].value=out.value
		out.text+="\n当前狐怒印记%d个，本次额外力量+%d。" % [mark_count(gs,owner),out.value]
	if card.get("formRules",{}).get("pipeMode")=="bomb":
		var src: int=gs._source_index(owner,card)
		var unit: Dictionary=gs.player(owner).units[src]
		var remaining := int(unit.get("formCountdown",{}).get("remaining",9)) if unit.get("formRules",{}).get("pipeMode")=="bomb" else int(unit.get("pipeBombRemaining",9))
		out.text+="\n进场倒计时%d。" % remaining
	return out

static func combat_immunity(gs, owner: int, idx: int, enemy: Dictionary, attacking: bool) -> bool:
	var unit: Dictionary=gs.player(owner).units[idx]
	if role(unit)!="white" or not active(unit) or (not attacking and not unit.awakened) or int(unit.get("foxImmuneTurn",-1))==gs.turn_counter or int(enemy.attack)<=int(unit.attack): return false
	unit.foxImmuneTurn=gs.turn_counter
	gs.VerifiedRules.event(gs,"fox-combat-immunity",{"player":owner,"uid":unit.uid,"target":enemy.uid,"attacking":attacking})
	return true

static func protects_avatar(gs, owner: int, source: int, combat: bool) -> bool:
	return source>=0 and source!=owner and not combat and gs.player(owner).units.any(func(u):return active(u) and u.get("formRules",{}).get("foxAvatarGuard",false))

static func damage_amount(gs, owner: int, amount: int) -> int:
	if amount>=6 and gs.player(owner).units.any(func(u):return active(u) and u.get("formRules",{}).get("foxDamageLimit",false)): return 5
	return amount

static func give_veil(gs, owner: int) -> void:
	gs.player(owner).foxAvatarVeil=true
	for unit in gs.player(owner).units:
		if int(unit.hp)>0: unit.foxVeil=true

static func avatar_veil(gs, owner: int) -> bool:
	if gs.player(owner).get("randomTargetPreview",false):return false
	return bool(gs.player(owner).get("foxAvatarVeil",false)) or gs.VerifiedRules.BaizeYuanqi.avatar_veil(gs, owner)

static func single_target(gs, owner: int, frame: Dictionary, card: Dictionary) -> bool:
	if card.get("type")!="combat" and not Content.is_spell(card): return false
	var target := str(frame.get("targetId",""))
	return target=="avatar-%d" % owner or gs._unit_index_by_uid(owner,target)>=0

static func candidates(gs, owner: int) -> Array:
	var out: Array=[]
	for idx in gs.player(owner).units.size():
		var unit: Dictionary=gs.player(owner).units[idx]
		if int(unit.hp)<=0: continue
		var base := {"zone":"unit","uid":unit.uid}
		if gs.VerifiedRules.FoxLotus.marked(unit) and int(unit.lotusCharm.owner)!=owner: var e:=base.duplicate(); e.key="lotusCharm"; out.append(e)
		if gs.VerifiedRules.Maple.marked(unit) and int(unit.mapleDoll.owner)!=owner: var e:=base.duplicate(); e.key="mapleDoll"; out.append(e)
		for jade_owner in unit.get("otakeJades",{}):
			if int(jade_owner)!=owner: var e:=base.duplicate(); e.key="otakeJades"; e.jadeOwner=int(jade_owner); out.append(e)
		var enemy_stun := int(unit.get("stunOwners",{}).get(str(1-owner),0))>0
		if int(unit.frozen)>0 and (enemy_stun or not unit.has("stunOwners")): var e:=base.duplicate(); e.key="stun"; out.append(e)
		for mark_entry in unit.get("pipeMarks",[]):
			if int(mark_entry.owner)!=owner: var e:=base.duplicate(); e.key="pipeMarks"; e.serial=int(mark_entry.serial); out.append(e)
		if not unit.get("crocCharm",{}).is_empty() and int(unit.crocCharm.owner)!=owner:
			var e:=base.duplicate(); e.key="crocCharm"; out.append(e)
		for kind in ["Tooth","Body"]:
			var key: String = "whale"+kind
			if not unit.get(key,{}).is_empty() and int(unit[key].sourceOwner)!=owner:
				var e:=base.duplicate(); e.key=key; out.append(e)
		if not unit.get("seaSpirit",{}).is_empty() and int(unit.seaSpirit.sourceOwner)!=owner: var e:=base.duplicate(); e.key="seaSpirit"; out.append(e)
		if not unit.get("sleeveThread",{}).is_empty() and int(unit.sleeveThread.owner)!=owner: var e:=base.duplicate(); e.key="sleeveThread"; out.append(e)
		if not unit.get("spiderMark",{}).is_empty() and int(unit.spiderMark.sourceOwner)!=owner: var e:=base.duplicate(); e.key="spiderMark"; out.append(e)
		if not unit.get("garudaFeather",{}).is_empty() and int(unit.garudaFeather.sourceOwner)!=owner: var e:=base.duplicate(); e.key="garudaFeather"; out.append(e)
		var guard: Dictionary=unit.get("owlGuard",{})
		if not guard.is_empty() and int(guard.owner)!=owner: var e:=base.duplicate(); e.key="owlGuard"; out.append(e)
		var count := int(unit.get("insectCorrosionOwners",{}).get(str(1-owner),unit.get("insectCorrosion",0) if not unit.has("insectCorrosionOwners") else 0))
		for i in count: var e:=base.duplicate(); e.key="insectCorrosion"; out.append(e)
	var p: Dictionary=gs.player(owner)
	if int(p.get("avatarFrozen",0))>0 and (int(p.get("stunOwners",{}).get(str(1-owner),0))>0 or not p.has("stunOwners")): out.append({"zone":"avatar","key":"stun"})
	for zone in ["deck","hand"]:
		for inst in p[zone]:
			for key in ["bondMarks","nightmareMarks"]:
				for i in inst.get(key,[]).size():
					if int(inst[key][i].owner)!=owner: out.append({"zone":zone,"instanceId":inst.instanceId,"key":key,"index":i})
			for i in int(inst.get("eyeCurses",0)): out.append({"zone":zone,"instanceId":inst.instanceId,"key":"eyeCurses"})
	return out

static func cleanse(gs, owner: int, src: int) -> void:
	var pool := candidates(gs,owner)
	if pool.is_empty(): return
	var selected: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
	var target: Dictionary=gs.player(owner)
	if selected.zone=="unit": target=gs._unit_by_uid(gs.player(owner).units,str(selected.uid))
	elif selected.zone in ["deck","hand"]:
		for entry in gs.player(owner)[selected.zone]:
			if str(entry.instanceId)==str(selected.instanceId): target=entry; break
	var key := str(selected.key)
	match key:
		"stun":
			var owners: Dictionary=target.get("stunOwners",{}); owners.erase(str(1-owner)); target.stunOwners=owners
			var remain := 0
			for value in owners.values(): remain=maxi(remain,int(value))
			if target.has("movementHolders"):
				target.movementHolders=target.movementHolders.filter(func(m):return int(m.sourceOwner)==owner)
				if target.movementHolders.is_empty(): target.erase("movementHolders"); target.erase("movementBaseFrozen")
			target["avatarFrozen" if selected.zone=="avatar" else "frozen"]=remain
		"pipeMarks": target.pipeMarks=target.pipeMarks.filter(func(m):return int(m.serial)!=int(selected.serial))
		"insectCorrosion":
			target.insectCorrosion=maxi(0,int(target.get("insectCorrosion",0))-1)
			if target.has("insectCorrosionOwners"): target.insectCorrosionOwners[str(1-owner)]=maxi(0,int(target.insectCorrosionOwners.get(str(1-owner),0))-1)
			gs._recalc(target)
		"otakeJades": gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(target.uid)),"白藏主：移除敌方灵咒",int(selected.jadeOwner))
		"lotusCharm": gs.VerifiedRules.FoxLotus.remove_charm(gs,target)
		"mapleDoll": gs.VerifiedRules.Maple.remove_doll(gs,target)
		"crocCharm": gs.VerifiedRules.Crocodile.detach(gs,target,"白藏主：移除敌方灵咒")
		"sleeveThread": gs.VerifiedRules.ApeSleeve.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(target.uid)))
		"whaleTooth", "whaleBody", "spiderMark", "garudaFeather", "seaSpirit": target.erase(key)
		"owlGuard": target.erase(key); gs.VerifiedRules.OwlInsect.refresh(gs)
		"eyeCurses": target.eyeCurses=maxi(0,int(target.eyeCurses)-1)
		_: target[key].remove_at(int(selected.index))
	gs.VerifiedRules.Otakemaru.sync_stun(target)
	gs.VerifiedRules.BondDream.refresh(gs)
	gs.VerifiedRules.event(gs,"fox-cleansed",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":target.get("uid",target.get("instanceId","")),"effect":key})

static func turn_start(gs, current: int) -> void:
	gs.player(current).erase("foxAvatarVeil")
	for unit in gs.player(current).units: unit.erase("foxVeil")
	var frames: Array=[]
	for owner in [current,1-current]:
		for idx in gs.player(owner).units.size():
			var unit: Dictionary=gs.player(owner).units[idx]
			if active(unit) and unit.get("formRules",{}).get("foxCleanse",false): frames.append({"kind":"fox-cleanse","playerIndex":owner,"sourceIndex":idx})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func end_turn(gs, current: int) -> void:
	for idx in gs.player(current).units.size():
		var unit: Dictionary=gs.player(current).units[idx]
		if not active(unit) or role(unit)!="pipe" or not unit.awakened: continue
		var pool: Array=gs.player(1-current).units.filter(func(u):return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u))
		if not pool.is_empty(): mark(gs,current,idx,1-current,gs._unit_index_by_uid(1-current,str(pool[int(floor(gs.randf01()*pool.size()))].uid)))

static func expire_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if int(unit.get("foxPillow",0))>0: unit.erase("foxPillow"); gs._recalc(unit)

static func knocked_out(unit: Dictionary) -> void:
	for key in ["foxPillow","foxVeil","pipeMarks","stunOwners"]: unit.erase(key)

static func targets(gs, owner: int, card: Dictionary):
	var action := str(card.get("effect", ""))
	if action not in ["pipe-attach", "pipe-stun", "fox-pillow", "fox-rage"]: return null
	var result: Array = []
	for side in ([owner, 1-owner] if action == "fox-pillow" else [1-owner]):
		for unit in gs.player(side).units:
			if int(unit.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(unit): continue
			if side != owner and (gs.VerifiedRules.Combat.has(unit, "veil") or gs.VerifiedRules.Movement.has_veil(unit)): continue
			result.append(str(unit.uid))
	return result

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var action := str(effect.get("action",""))
	match action:
		"pipe-countdown": countdown(gs,owner,src,str(effect.value),card.get("type")=="ability")
		"pipe-attach":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid","")))
			mark(gs,owner,src,1-owner,idx)
		"pipe-front-mark": mark(gs,owner,src,1-owner,gs.front_index(1-owner))
		"pipe-stun":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid",""))); mark(gs,owner,src,1-owner,idx)
			for i in gs.player(1-owner).units.size():
				var unit: Dictionary=gs.player(1-owner).units[i]
				if int(unit.hp)>0 and unit.get("pipeMarks",[]).any(func(m):return int(m.owner)==owner):
					gs.VerifiedRules.Stun.apply(gs,1-owner,i,1,owner)
					unit.pipeMarks=unit.pipeMarks.filter(func(m):return int(m.owner)!=owner)
		"pipe-all-marks":
			for idx in gs.player(1-owner).units.size(): mark(gs,owner,src,1-owner,idx)
		"pipe-awaken": gs._awaken(owner,src,card,effect.value); gs.player(owner).units[src].abilityCountdown.mode="awakened"
		"fox-pillow":
			if int(target.get("hp",0))<=0: return true
			target.foxPillow=int(target.get("foxPillow",0))+1; target.hp=maxi(0,int(target.hp)-2); gs._recalc(target)
			if int(target.hp)<=0: gs._knockout_unit(target,owner,src)
		"fox-veil":
			if card.has("foxCounterId"):
				var rid := int(card.foxCounterId)
				gs.resolution_stack=gs.resolution_stack.filter(func(f):return int(f.get("resolutionId",-1))!=rid)
				gs.VerifiedRules.event(gs,"card-nullified",{"player":1-owner,"resolutionId":rid,"byPlayer":owner,"byCard":card.id,"card":card.get("foxCounterCard",{}),"uid":card.get("foxCounterUid","")})
				gs._log("小白反制了「%s」。" % str(card.get("foxCounterCard",{}).get("name","目标牌")),gs.TONE_CARD)
			give_veil(gs,owner); gs._draw(owner,1)
		"fox-rage":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid","")))
			if idx>=0:
				var destroy := int(target.attack)>=6
				gs.VerifiedRules.Stun.apply(gs,1-owner,idx,1,owner)
				if destroy: gs.VerifiedRules.Panguan.destroy(gs,owner,src,1-owner,idx,card)
		"fox-burn":
			var frames: Array=[]
			for unit in gs.player(1-owner).units:
				if int(unit.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(unit): frames.append({"kind":"fox-burn-hit","playerIndex":owner,"sourceIndex":src,"targetUid":unit.uid,"context":gs._card_effect_context.duplicate(true)})
			frames.reverse(); gs.resolution_stack.append_array(frames)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if kind not in ["pipe-hit","pipe-mark-hit","fox-cleanse","fox-burn-hit"]: return false
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex)
	if kind=="fox-cleanse": cleanse(gs,owner,src); return true
	var old: Dictionary=gs._card_effect_context; gs._card_effect_context=frame.get("context",{})
	var victim := 1-owner; var target := str(frame.targetUid)
	var idx: int=gs._unit_index_by_uid(victim,target)
	if target=="avatar-%d" % victim:
		if frame.get("baseAbility",false): gs.VerifiedRules.base_damage_avatar(gs,owner,src,victim,int(frame.amount))
		else: gs._damage_avatar(victim,int(frame.amount),owner,src)
	elif idx>=0 and int(gs.player(victim).units[idx].hp)>0:
		var unit: Dictionary=gs.player(victim).units[idx]
		if kind!="pipe-mark-hit" or unit.get("pipeMarks",[]).any(func(m):return int(m.serial)==int(frame.serial)):
			if frame.get("baseAbility",false): gs.VerifiedRules.base_damage_unit(gs,owner,src,victim,idx,int(frame.amount))
			else: gs._damage_unit(victim,idx,maxi(0,int(unit.attack)) if kind=="fox-burn-hit" else int(frame.amount),owner,src)
			if kind=="pipe-mark-hit": unit.pipeMarks=unit.get("pipeMarks",[]).filter(func(m):return int(m.serial)!=int(frame.serial))
	gs._card_effect_context=old
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("pipeFoxRules",false): return null
	match str(card.get("effect","")):
		"fox-pillow":
			var enemy: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,target_id)
			return 70 if not enemy.is_empty() and int(enemy.hp)<=2 else (45 if not enemy.is_empty() else -50)
		"fox-rage":
			var unit: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,target_id)
			return 75 if int(unit.get("attack",0))>=6 else 45
		"fox-burn": return 65 if gs.player(1-owner).units.any(func(u):return int(u.hp)>0 and int(u.attack)>=int(u.hp)) else 20
		"fox-veil": return 30 if gs.player(owner).hand.size()<10 else -20
		_: return 50
