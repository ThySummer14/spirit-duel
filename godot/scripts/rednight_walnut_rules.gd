class_name RednightWalnutRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const OFFENSE := ["rw-flame", "rw-bees", "rw-wheel"]
const SUPPORT := ["rw-armor", "rw-weapon", "rw-rebirth"]
const ITEM_NAMES := {"rw-flame":"喷火筒", "rw-bees":"一窝蜂", "rw-wheel":"万刃轮", "rw-armor":"护甲", "rw-weapon":"武器", "rw-rebirth":"返魂符"}

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("rednightWalnutRole", ""))
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func shikigami(gs, u: Dictionary) -> bool:
	return not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u)
static func can_deploy(u: Dictionary) -> bool:
	return int(u.get("rwDeployBlocked",0))<=0
static func end_turn(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if u.has("rwDeployBlocked"):
			u.rwDeployBlocked=maxi(0,int(u.rwDeployBlocked)-1)
			if int(u.rwDeployBlocked)==0:u.erase("rwDeployBlocked")
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("rednightWalnutRules",false) or card.get("target","auto")=="auto": return null
	var ids: Array=[]
	for side in [owner] if str(card.id)=="c26701" else [1-owner] if str(card.id) in ["c26605","c26608"] else [owner,1-owner]:
		for u in gs.player(side).units:
			if not shikigami(gs,u) or (int(u.hp)<=0 and str(card.id)!="c26701"):continue
			if side!=owner and gs.VerifiedRules.Combat.has(u,"veil"):continue
			ids.append(str(u.uid))
	return ids
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if str(card.get("id",""))=="c26607":return not gs.player(owner).units[gs._source_index(owner,card)].awakened
	if str(card.get("id",""))=="c26707":return not gs.player(owner).units[gs._source_index(owner,card)].awakened
	return true
static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("rednightWalnutRules",false):return card
	var c:=card.duplicate(true)
	if c.id in ["c26704","c26708"]:
		var turns:=int(gs.player(owner).get("turnsTaken",0))
		c.enhanced=turns>=(5 if c.id=="c26704" else 10)
		c.currentCardStats="己方第%d回合 · %s"%[turns,"物品效果翻倍" if c.enhanced else "物品基础效果"]
	return c
static func _queue_projectile(gs, owner: int, src: int, amount: int, stun: bool=false, base_ability: bool=false) -> void:
	gs.resolution_stack.append({"kind":"rw-projectile","playerIndex":owner,"sourceIndex":src,"amount":amount,"stun":stun,"baseAbility":base_ability,"context":gs._card_effect_context.duplicate(true)})
static func rule_event(gs, kind: String, details: Dictionary) -> void:
	if kind not in ["charged-stored","lantern-stored"]:return
	var owner:=int(details.get("player",-1))
	if owner<0:return
	for i in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[i]
		if active(u) and role(u)=="rednight" and u.awakened:_queue_projectile(gs,owner,i,2,true,true)
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("chargedReleased",false) and not card.get("lanternReleased",false):return
	var owner:=int(frame.playerIndex)
	for i in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[i]
		if active(u) and role(u)=="rednight":_queue_projectile(gs,owner,i,2 if u.awakened else 1,u.awakened,true)
static func damage_dealt(gs, owner: int, src: int, victim: int, idx: int, amount: int, combat: bool) -> void:
	if combat or amount<=0 or owner<0 or src<0 or idx<0 or owner==victim:return
	var u:Dictionary=gs.player(owner).units[src];var target:Dictionary=gs.player(victim).units[idx]
	if not active(u) or not u.get("formRules",{}).get("rwLock",false) or not shikigami(gs,target) or int(target.hp)<=0:return
	target.rwDeployBlocked=maxi(int(target.get("rwDeployBlocked",0)),1+int(victim==gs.current_player))
	gs.VerifiedRules.event(gs,"rw-deployment-locked",{"player":victim,"uid":target.uid,"remaining":target.rwDeployBlocked})
static func replace_basic(gs, owner: int, src: int, _target_id) -> bool:
	var u:Dictionary=gs.player(owner).units[src]
	if not active(u) or not u.get("formRules",{}).get("rwPhoenix",false) or u.has("lanternStored"):return false
	var card:=Content.card_def("rednight-sword-aura").duplicate(true)
	return gs.VerifiedRules.ChargedPair.store_copy(gs,owner,src,card,null)
static func before_attack(gs, frame: Dictionary) -> bool:
	if frame.get("rwAttackPrepared",false):return false
	frame.rwAttackPrepared=true
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var u:Dictionary=gs.player(owner).units[src]
	if role(u)!="walnut" or not active(u):return false
	var down: Array=gs.player(owner).units.filter(func(t):return int(t.hp)<=0 and shikigami(gs,t))
	if down.is_empty() or (not u.awakened and not frame.options.get("basicAttack",false)):return false
	if not u.awakened:frame.options.rwNoDamage=true
	var resume:=frame.duplicate(true);resume.kind="rw-attack-ready";gs.resolution_stack.append(resume)
	for i in range(down.size()-1,-1,-1):gs.resolution_stack.append({"kind":"rw-revive-one","playerIndex":owner,"sourceIndex":src,"targetUid":down[i].uid,"awakened":bool(u.awakened)})
	return true
static func _parry(gs, owner: int, src: int, victim: int, idx: int) -> void:
	var u:Dictionary=gs.player(owner).units[src];var target:Dictionary=gs.player(victim).units[idx]
	if not active(u) or not u.get("formRules",{}).get("rwParry",false) or int(target.hp)<=0:return
	if not gs.VerifiedRules.Light.roll(gs,owner,4,6,src):return
	for copy in gs.VerifiedRules.Fortune.last_repeats(gs,owner):
		if int(target.hp)<=0:break
		if target.has("lanternStored"):gs.VerifiedRules.Panguan.destroy(gs,owner,src,victim,idx,{})
		else:_form_hit(gs,owner,src,victim,idx,3)
static func _form_hit(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> void:
	var old: Dictionary=gs._card_effect_context
	var form_id: String=str(gs.player(owner).units[src].get("form",{}).get("cardId",""))
	gs._card_effect_context={"playerIndex":owner,"sourceIndex":src,"cardOverride":Content.card_def(form_id),"affectedUnits":[]}
	gs._damage_unit(victim,idx,amount,owner,src)
	gs._card_effect_context=old

static func before_hit(gs, frame: Dictionary, fi: int) -> bool:
	if frame.get("rwParryPrepared",false) or fi<0:return false
	frame.rwParryPrepared=true
	var owner:=int(frame.playerIndex);var victim:=int(frame.options.get("combatVictim",1-owner));var src:=int(frame.sourceIndex)
	var attacker:Dictionary=gs.player(owner).units[src];var defender:Dictionary=gs.player(victim).units[fi]
	if not attacker.get("formRules",{}).get("rwParry",false) and not defender.get("formRules",{}).get("rwParry",false):return false
	var resume:=frame.duplicate(true);resume.kind="rw-hit-ready";gs.resolution_stack.append(resume)
	gs.resolution_stack.append({"kind":"rw-parry","playerIndex":victim,"sourceIndex":fi,"victim":owner,"targetIndex":src})
	gs.resolution_stack.append({"kind":"rw-parry","playerIndex":owner,"sourceIndex":src,"victim":victim,"targetIndex":fi})
	return true
static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if str(options.get("combatCard",{}).get("id",""))=="rednight-sword-aura":_queue_projectile(gs,owner,src,3)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var u:Dictionary=gs.player(owner).units[src]
	if str(card.id)=="c26601" and card.get("chargedReleased",false):
		var pool:Array=gs.player(1-owner).units.filter(func(t):return int(t.hp)>0 and shikigami(gs,t))
		if not pool.is_empty():_form_hit(gs,owner,src,1-owner,gs._unit_index_by_uid(1-owner,str(pool[int(gs.next_random()%pool.size())].uid)),3)
	if str(card.id)=="c26606":u.swift=true
	if str(card.id)=="c26701":
		u.rwProtectedUid=str(card.get("rwProtectedUid",""));_protect(gs,owner,src)
static func turn_start(gs, owner: int, src: int) -> void:
	if active(gs.player(owner).units[src]) and gs.player(owner).units[src].get("formRules",{}).get("rwProtect",false):_protect(gs,owner,src)
static func _protect(gs, owner: int, src: int) -> void:
	var u:Dictionary=gs.player(owner).units[src];var idx:int=gs._unit_index_by_uid(owner,str(u.get("rwProtectedUid","")))
	if idx<0:return
	var t:Dictionary=gs.player(owner).units[idx]
	if int(t.hp)>0:gs._heal_unit(t,3)
	else:gs.VerifiedRules.reduce_countdown(gs,owner,idx,1)
static func death_frames(gs, owner: int, u: Dictionary) -> Array:
	if owner<0:return []
	var result:Array=[]
	for marker in u.get("rwBounties",[]):result.append({"kind":"rw-bounty-draw","playerIndex":int(marker),"sourceIndex":0})
	u.erase("rwBounties");u.erase("rwDeployBlocked");u.erase("rwProtectedUid")
	return result
static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if not str(realm.get("nativeRealm","")).begins_with("rw-"):return false
	if int(realm.hp)>0:gs.resolution_stack.append({"kind":"rw-realm","playerIndex":owner,"sourceIndex":gs._source_index(owner,{"unitId":"tayumenhutao"}),"realmUid":realm.uid})
	return true
static func _permanent(gs, u: Dictionary, attack: int, hp: int) -> void:
	gs.VerifiedRules.Glutton.record_permanent(u,attack,hp,true);gs.VerifiedRules.SunSmoke.remember_permanent(u,attack,hp);gs._grow_unit(u,attack,hp)
static func _realm(gs, owner: int, src: int, realm: Dictionary) -> void:
	if int(realm.hp)<=0:return
	var pool:Array=gs.player(owner).units.filter(func(t):return int(t.hp)>0 and shikigami(gs,t))
	match str(realm.nativeRealm):
		"rw-loot":
			var item:=int(gs.next_random()%5);var scale:=2 if int(gs.player(owner).get("turnsTaken",0))>=5 else 1
			gs.VerifiedRules.event(gs,"rw-loot-item",{"player":owner,"item":item,"multiplier":scale,"realmUid":realm.uid})
			match item:
				0,1:
					if not pool.is_empty():gs._grow_unit(pool[int(gs.next_random()%pool.size())],scale if item==0 else 0,scale if item==1 else 0)
				2:gs._heal_avatar(owner,2*scale)
				3:
					for t in pool:gs._grant_unit_armor(t,scale)
					gs._grant_avatar_armor(owner,scale)
				4:gs.VerifiedRules.Divination.start(gs,owner,scale)
		"rw-pure":
			if int(realm.hp)>=4:
				for t in pool:
					var missing:=maxi(0,int(t.maxHp)-int(t.hp));gs._heal_unit(t,2)
					if not t.get("toxicPoisoned",false):gs._grant_unit_armor(t,maxi(0,2-missing))
			else:
				gs.VerifiedRules.Huang.destroy(gs,owner,realm,"净天地自毁")
				for side in 2:
					for target in gs.player(side).units.duplicate():
						if int(target.hp)>0 and shikigami(gs,target):gs.resolution_stack.append({"kind":"rw-area-hit","playerIndex":owner,"sourceIndex":src,"targetUid":target.uid,"amount":2,"context":gs._card_effect_context.duplicate(true)})
		"rw-earth":
			var enemies:Array=gs.player(1-owner).units.filter(func(t):return shikigami(gs,t))
			if not enemies.is_empty():
				var target:Dictionary=enemies[int(gs.next_random()%enemies.size())]
				if int(target.hp)>0:gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,str(target.uid)),4,owner,src)
static func _area(gs, owner: int, src: int, amount: int) -> void:
	for target in gs.player(1-owner).units.duplicate():
		if int(target.hp)>0 and shikigami(gs,target):gs.resolution_stack.append({"kind":"rw-area-hit","playerIndex":owner,"sourceIndex":src,"targetUid":target.uid,"amount":amount,"context":gs._card_effect_context.duplicate(true)})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var action:=str(effect.get("action",""));var u:Dictionary=gs.player(owner).units[src]
	if action!="rw-card":return false
	var released:bool=card.get("chargedReleased",false)
	match str(card.id):
		"c26601","c26606":gs._install_form(owner,src,card)
		"c26602":
			if released:gs.resolution_stack.append({"kind":"rw-shot-hit","playerIndex":owner,"sourceIndex":src,"targetUid":target_id,"amount":2+int(u.get("spellPower",0)),"context":gs._card_effect_context.duplicate(true)})
			gs.resolution_stack.append({"kind":"rw-shot-hit","playerIndex":owner,"sourceIndex":src,"targetUid":target_id,"amount":3+int(u.get("spellPower",0)),"context":gs._card_effect_context.duplicate(true)})
		"c26603","rednight-sword-aura":
			if released and str(card.id)=="c26603":
				for t in gs.player(1-owner).units.duplicate():
					if int(t.hp)>0 and int(t.front)==0 and shikigami(gs,t):gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,str(t.uid)),1+int(u.get("spellPower",0)),owner,src)
			var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
			gs._grant_unit_armor(u,int(options.get("shield",0)))
			gs._resolve_combat(owner,src,int(card.value),false,bool(options.get("remote",false)),false,false,target_id,false,options)
		"c26604":
			for side in 2:
				var idx:int=gs._unit_index_by_uid(side,str(target_id))
				if idx>=0:
					gs.player(side).units[idx].erase("lanternStored");gs.VerifiedRules.Movement.clear_hold(gs,gs.player(side).units[idx]);gs.VerifiedRules.Stun.apply(gs,side,idx,1,owner)
			gs.VerifiedRules.ChargedPair.refresh(gs)
		"c26605":
			var pool:Array=gs.player(1-owner).units.filter(func(t):return int(t.hp)>0 and str(t.uid)!=str(target_id) and shikigami(gs,t))
			if not pool.is_empty():
				var other:Dictionary=pool[int(gs.next_random()%pool.size())];gs.resolution_stack.append({"kind":"rw-scatter-hit","playerIndex":owner,"sourceIndex":src,"targetUid":other.uid,"amount":(4 if released else 3)+int(u.get("spellPower",0)),"context":gs._card_effect_context.duplicate(true)})
			gs.resolution_stack.append({"kind":"rw-scatter-hit","playerIndex":owner,"sourceIndex":src,"targetUid":target_id,"amount":(4 if released else 3)+int(u.get("spellPower",0)),"context":gs._card_effect_context.duplicate(true)})
		"c26607","c26707":
			gs._awaken(owner,src,card,{"attack":2,"hp":2})
			if str(card.id)=="c26707":u.swift=true
		"c26608":
			for idx in gs.player(1-owner).units.size():
				var t:Dictionary=gs.player(1-owner).units[idx]
				if int(t.hp)>0 and shikigami(gs,t) and (released or str(t.uid)==str(target_id)):gs.VerifiedRules.Stun.apply(gs,1-owner,idx,1,owner)
		"c26701":
			var c:=card.duplicate(true);c.rwProtectedUid=str(target_id);gs._install_form(owner,src,c)
		"c26702":
			var pool:Array=gs.player(1-owner).units.filter(func(t):return int(t.hp)>0 and shikigami(gs,t))
			if not pool.is_empty():
				var t:Dictionary=pool[int(gs.next_random()%pool.size())]
				if not t.has("rwBounties"):t.rwBounties=[]
				t.rwBounties.append(owner);gs.VerifiedRules.event(gs,"rw-bounty-marked",{"player":owner,"uid":t.uid,"marks":t.rwBounties.size()})
		"c26703":gs._install_form(owner,src,card)
		"c26704","c26705","c26706":
			gs._deploy_realm(owner,card);trigger_realm(gs,owner,gs.player(owner).realms.back())
		"c26708":gs.resolution_stack.append({"kind":"rw-item-choice","playerIndex":owner,"sourceIndex":src,"stage":0,"multiplier":2 if int(gs.player(owner).get("turnsTaken",0))>=10 else 1,"context":gs._card_effect_context.duplicate(true)})
	return true
static func _item_choice(gs, owner: int, src: int, stage: int, scale: int, context: Dictionary = {}) -> void:
	gs.pending_choice={"type":"rw-items","playerIndex":owner,"sourceIndex":src,"context":context.duplicate(true),"instanceIds":OFFENSE.duplicate() if stage==0 else SUPPORT.duplicate(),"stage":stage,"multiplier":scale,"heading":"飓 风 客 · %d/2"%[stage+1],"hint":"选择并立即结算一个物品效果；%s。"%("效果翻倍" if scale==2 else "基础效果")};gs.phase="choice"
static func choice_card(gs, owner: int, id: String):
	var q:Dictionary=gs.pending_choice
	if q.get("type")!="rw-items" or int(q.playerIndex)!=owner or id not in q.instanceIds:return null
	var scale:=int(q.multiplier)
	var descriptions:Dictionary={"rw-flame":"对所有敌方式神造成%d点伤害。"%[2*scale],"rw-bees":"投射：造成1点伤害，重复%d次。"%[5*scale],"rw-wheel":"土御门胡桃获得%d力量并发起一次免疫战斗伤害的攻击。"%[2*scale],"rw-armor":"所有己方式神永久获得%d生命。"%[3*scale],"rw-weapon":"所有己方式神永久获得%d力量。"%[2*scale],"rw-rebirth":"为己方牌手恢复%d生命。"%[6*scale]}
	return {"id":id,"name":ITEM_NAMES[id],"unitId":"tayumenhutao","type":"spell","typeLabel":"飓风客物品","level":0,"cost":0,"text":descriptions[id]}
static func resolve_choice(gs, owner: int, id: String) -> bool:
	var q:Dictionary=gs.pending_choice
	if q.get("type")!="rw-items" or int(q.playerIndex)!=owner or id not in q.instanceIds:return false
	gs.pending_choice={};gs.phase="main"
	gs._record("resolve_divination_choice",{"choice":"rw-items","instanceId":id,"stage":q.stage},owner)
	if int(q.stage)==0:gs.resolution_stack.append({"kind":"rw-item-choice","playerIndex":owner,"sourceIndex":int(q.sourceIndex),"stage":1,"multiplier":int(q.multiplier),"context":q.get("context",{}).duplicate(true)})
	gs.resolution_stack.append({"kind":"rw-item","playerIndex":owner,"sourceIndex":int(q.sourceIndex),"item":id,"multiplier":int(q.multiplier),"context":q.get("context",{}).duplicate(true)})
	gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="rw-items":return null
	var id: String="rw-bees" if int(gs.pending_choice.stage)==0 else "rw-rebirth" if int(gs.player(owner).avatarHp)<15 else "rw-weapon"
	return resolve_choice(gs,owner,id)
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""))
	if not kind.begins_with("rw-"):return false
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex)
	match kind:
		"rw-attack-ready":gs._resolve_combat_ready(frame)
		"rw-hit-ready":gs._offer_attack_responses(frame)
		"rw-parry":_parry(gs,owner,src,int(frame.victim),int(frame.targetIndex))
		"rw-revive-one":
			var idx:int=gs._unit_index_by_uid(owner,str(frame.targetUid))
			if idx>=0:
				if frame.awakened:gs.VerifiedRules.Peach.revive(gs,owner,src,gs.player(owner).units[idx],false,false)
				else:gs.VerifiedRules.reduce_countdown(gs,owner,idx,1)
		"rw-bounty-draw":gs._draw(owner,2)
		"rw-projectile":
			var victim:=1-owner;var idx:int=gs.front_index(victim);var amount:=int(frame.amount)
			var old:Dictionary=gs._card_effect_context;gs._card_effect_context=frame.get("context",{}).duplicate(true)
			var taken:int
			if frame.get("baseAbility",false): taken=gs.VerifiedRules.base_damage_avatar(gs,owner,src,victim,amount) if idx<0 else int(gs.VerifiedRules.base_damage_unit(gs,owner,src,victim,idx,amount).get("damage",0))
			else: taken=gs._damage_avatar(victim,amount,owner,src) if idx<0 else int(gs._damage_unit(victim,idx,amount,owner,src).get("damage",0))
			gs._card_effect_context=old
			if frame.stun and taken>0:gs.VerifiedRules.Stun.apply(gs,victim,idx,1,owner)
		"rw-area-hit","rw-scatter-hit","rw-shot-hit":
			var old:Dictionary=gs._card_effect_context;gs._card_effect_context=frame.context.duplicate(true)
			for side in 2:
				var idx:int=gs._unit_index_by_uid(side,str(frame.targetUid))
				if idx>=0:gs._damage_unit(side,idx,int(frame.amount),owner,src)
			gs._card_effect_context=old
		"rw-realm":
			for r in gs.player(owner).realms:
				if str(r.uid)==str(frame.realmUid):_realm(gs,owner,src,r);break
		"rw-item-choice":_item_choice(gs,owner,src,int(frame.stage),int(frame.multiplier),frame.get("context",{}))
		"rw-item":
			var old:Dictionary=gs._card_effect_context;gs._card_effect_context=frame.get("context",{}).duplicate(true)
			var amount:=int(frame.multiplier);var u:Dictionary=gs.player(owner).units[src]
			match str(frame.item):
				"rw-flame":_area(gs,owner,src,2*amount)
				"rw-bees":
					for i in 5*amount:_queue_projectile(gs,owner,src,1+int(u.get("spellPower",0)))
				"rw-wheel":
					if int(u.hp)>0:gs._grow_unit(u,2*amount,0);gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"immuneCombat":true})
				"rw-armor","rw-weapon":
					for t in gs.player(owner).units:
						if int(t.hp)>0 and shikigami(gs,t):_permanent(gs,t,2*amount if frame.item=="rw-weapon" else 0,3*amount if frame.item=="rw-armor" else 0)
				"rw-rebirth":gs._heal_avatar(owner,6*amount)
			gs._card_effect_context=old
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("rednightWalnutRules",false):return null
	if card.id in ["c26602","c26605","c26604"] and gs._unit_index_by_uid(owner,str(target_id))>=0:return -100
	if card.id=="c26708":return 90
	if card.id=="c26701":
		var t:Dictionary=gs._unit_by_uid(gs.player(owner).units,str(target_id));return 45+int(t.get("knockout",0))*5+int(t.get("maxHp",0))-int(t.get("hp",0))
	if card.id in ["c26607","c26707"]:return 70
	return 40
static func marks(_gs, _owner: int, u: Dictionary) -> Array:
	var result:Array=[]
	if int(u.get("rwDeployBlocked",0))>0:result.append("锁羚羊 · 下个己方回合不能出击")
	if u.has("rwProtectedUid") and u.get("formRules",{}).get("rwProtect",false):result.append("庇护 · 绑定%s"%str(u.rwProtectedUid))
	if not u.get("rwBounties",[]).is_empty():result.append("追击标记×%d · 气绝时对方抽牌"%u.rwBounties.size())
	return result
