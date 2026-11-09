class_name EssenceFeastRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Food := preload("res://scripts/cooking_rules.gd")

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("essenceFeastRole", ""))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func _frame(gs, kind: String, owner: int, src: int, extra: Dictionary = {}) -> void:
	var f:Dictionary={"kind":kind,"playerIndex":owner,"sourceIndex":src};f.merge(extra,true);gs.resolution_stack.append(f)
static func _once(gs, value: Dictionary, key: String) -> bool:
	if int(value.get(key,-1))==gs.turn_counter:return false
	value[key]=gs.turn_counter;return true
static func _projectile(gs, owner: int, src: int, amount: int) -> void:
	if gs.winner>=0:return
	var fi:int=gs.front_index(1-owner)
	if fi<0:gs.VerifiedRules.base_damage_avatar(gs,owner,src,1-owner,amount)
	else:gs.VerifiedRules.base_damage_unit(gs,owner,src,1-owner,fi,amount)
static func gain_essence(gs, owner: int, count: int = 1) -> void:
	var p:Dictionary=gs.player(owner)
	for _n in count:
		var found:Dictionary={}
		for inst in p.hand:
			if inst.get("definitionId","")=="shengmingjinghua" and int(inst.get("efStacks",1))<10:found=inst;break
		if not found.is_empty():found.efStacks=int(found.get("efStacks",1))+1;continue
		if p.hand.size()>=int(gs.rules.maxHandSize):continue
		p.hand.append({"definitionId":"shengmingjinghua","instanceId":"ef-essence-%d"%gs.next_card_id,"efStacks":1});gs.next_card_id+=1
	gs.VerifiedRules.event(gs,"essence-gained",{"player":owner,"count":count})
static func essence_card(gs, owner: int, inst: Dictionary) -> Dictionary:
	var c:Dictionary=Content.card_def("shengmingjinghua").duplicate(true);var n:=clampi(int(inst.get("efStacks",1)),1,10)
	c.neutralEssence=true;c.unitId="";c.level=0;c.cost=1;c.keywords=["instant"];c.efStacks=n;c.value=n;c.text="瞬发。堆叠（最大10）。为一个角色恢复%d生命。"%n;c.currentCardStats="生命精华 · 堆叠%d／10"%n
	return gs.VerifiedRules.HandBlessing.describe_card(gs,owner,inst,c)
static func essence_targets(gs, owner: int) -> Array:
	var ids:Array=["avatar-%d"%owner]
	if not gs.VerifiedRules.PipeFox.avatar_veil(gs,1-owner):ids.append("avatar-%d"%(1-owner))
	for side in [owner,1-owner]:
		for u in gs.player(side).units:
			if int(u.hp)>0 and not u.get("removed",false) and (side==owner or not gs.VerifiedRules.Combat.has(u,"veil")):ids.append(str(u.uid))
	return ids
static func can_play_essence(gs, owner: int, hand: int, target) -> Dictionary:
	var card:Dictionary=gs.hand_card_def(owner,hand)
	if int(gs.player(owner).energy)<int(gs.card_payment(owner,card).cost):return {"ok":false,"reason":"鬼火不足。"}
	if not essence_targets(gs,owner).has(str(target)):return {"ok":false,"reason":"请选择合法角色。"}
	return {"ok":true,"card":card,"source_index":-1,"reason":""}
static func play_essence(gs, owner: int, hand: int, target) -> bool:
	var check:Dictionary=gs.can_play_card(owner,hand,target)
	if not check.ok:return false
	var c:Dictionary=check.card;var q:Dictionary=gs.card_payment(owner,c);c.playedInstance=gs.take_card_instance(owner,hand);c.usedFromHand=not c.get("insightFromZone",false)
	gs.VerifiedRules.Wave7Reworks.pay_lamp(gs, owner, c, q)
	gs._set_fire(owner,int(gs.player(owner).energy)-int(q.cost),true)
	if q.usesInstant:gs.consume_instant(owner)
	gs.player(owner).cardsPlayedThisTurn=int(gs.player(owner).cardsPlayedThisTurn)+1
	var args := {"hand":hand,"card":c.id,"target":target,"cardView":c.duplicate(true),"payment":q}
	if not c.usedFromHand: args.merge({"sourceZone":"insight","instanceId":c.playedInstance.instanceId})
	gs._record("play_card",args,owner)
	_push_essence(gs,owner,c,target,false);gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func _push_essence(gs, owner: int, card: Dictionary, target, automatic: bool) -> void:
	var rid:int=gs.next_resolution_id;gs.next_resolution_id+=1
	for kind in ["card-complete","card-effect","card-announce"]:
		gs.resolution_stack.append({"kind":kind,"playerIndex":owner,"sourceIndex":-1,"resolutionId":rid,"definitionId":"shengmingjinghua","cardOverride":card.duplicate(true),"targetId":target,"automatic":automatic,"fromHand":not automatic and not card.get("insightFromZone",false),"effectIndex":0,"affectedUnits":[]})
static func healed(gs, owner: int, idx: int, requested: int, restored: int, excess: int) -> void:
	if requested<=0 or gs.winner>=0:return
	var p:Dictionary=gs.player(owner);var target:Dictionary={} if idx<0 else p.units[idx]
	if idx<0 and restored>=5:
		for src in p.units.size():
			var u:Dictionary=p.units[src]
			if role(u)=="pearl" and active(u) and u.awakened:gs._draw(owner,1)
	if idx<0 or role(target)=="powder":
		for src in p.units.size():
			var u:Dictionary=p.units[src]
			if not active(u) or role(u)!="powder" or (idx>=0 and str(target.uid)!=str(u.uid)):continue
			if idx<0 and restored>=5 and not u.awakened and int(u.level)>=3 and not u.get("efAwakeQueued",false):
				for zone in ["hand","deck"]:
					if p[zone].any(func(i):return i.definitionId=="c60308"):
						u.efAwakeQueued=true;_frame(gs,"ef-auto-awake",owner,src);break
			if excess<=0:continue
			if (not u.awakened or idx<0) and _once(gs,u,"efPowderBaseTurn"):_frame(gs,"ef-powder-hit",owner,src,{"amount":excess if u.awakened else 2,"randomUnit":false})
			if u.get("formRules",{}).get("efPaint",false) and _once(gs,u,"efPaintTurn"):_frame(gs,"ef-powder-hit",owner,src,{"amount":2,"randomUnit":true})
			if u.get("formRules",{}).get("efPowderBox",false) and _once(gs,u,"efBoxTurn"):_frame(gs,"ef-box",owner,src)
			if u.awakened and idx>=0 and str(target.uid)==str(u.uid) and gs.current_player==owner and _once(gs,u,"efAwakeAttackTurn"):_frame(gs,"ef-attack",owner,src,{"immune":true})
	if excess>0 and idx>=0:
		for realm in p.realms:
			if realm.get("nativeRealm","")=="ef-grudge" and int(realm.hp)>0 and _once(gs,realm,"efGrudgeTurn"):gs._set_fire(owner,int(p.energy)+1)
static func avatar_damaged(gs, owner: int, amount: int) -> void:
	if amount<=0:return
	var p:Dictionary=gs.player(owner);p.efDamagePackets=int(p.get("efDamagePackets",0))+1
	for src in p.units.size():
		var u:Dictionary=p.units[src]
		if not active(u) or role(u)!="pearl":continue
		if _once(gs,u,"efPearlBaseTurn"):gain_essence(gs,owner,maxi(1,int(ceil(amount/2.0))) if u.awakened else 1)
		if u.get("formRules",{}).get("efTorrent",false) and _once(gs,u,"efTorrentTurn"):_frame(gs,"ef-projectile",owner,src,{"amount":1})
	for realm in p.realms:
		if realm.get("nativeRealm","")!="ef-moist" or int(realm.hp)<=0 or not _once(gs,realm,"efMoistTurn"):continue
		for u in p.units:
			if u.get("summoned",false) or u.get("removed",false):continue
			if int(u.hp)>0:gs._grow_unit(u,1,0)
			elif int(u.knockout)>0:u.knockout=maxi(0,int(u.knockout)-1);if u.knockout==0:gs.VerifiedRules.Peach.revive(gs,owner,-1,u,false,false)
static func _damage_target(gs, id: String, amount: int, source_owner: int, src: int, combat: bool) -> int:
	for side in 2:
		if id=="avatar-%d"%side:return gs._damage_avatar(side,amount,source_owner,src,false,combat,true)
		var i:int=gs._unit_index_by_uid(side,id)
		if i>=0:return int(gs._damage_unit(side,i,amount,source_owner,src,combat,-1,false,false,true).get("dealt",0))
	return 0
static func replace_unit_damage(gs, victim: int, idx: int, amount: int, owner: int, src: int, combat: bool):
	if amount<=0 or int(gs.player(victim).get("efDamageRedirectDepth",0))>0:return null
	var p:Dictionary=gs.player(victim);var u:Dictionary=p.units[idx]
	if not active(u):return null
	var split:bool=u.get("formRules",{}).get("efPearlSplit",false) and int(u.get("efPearlSplitTurn",-1))!=gs.turn_counter
	var borrow:=combat and not str(u.get("efBorrowTarget","")).is_empty()
	var spring:bool=u.get("formRules",{}).get("efSpring",false)
	if not split and not borrow and not spring:return null
	p.efDamageRedirectDepth=int(p.get("efDamageRedirectDepth",0))+1
	var dealt:=0;var remaining:=amount
	if borrow:
		remaining=0;dealt=_damage_target(gs,str(u.efBorrowTarget),amount,owner,src,combat)
	elif split:
		u.efPearlSplitTurn=gs.turn_counter;remaining=0
		var recipients:Array=["avatar-%d"%victim]
		for enemy in gs.player(1-victim).units:
			if int(enemy.hp)>0 and not enemy.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(enemy):recipients.append(str(enemy.uid))
		var allocations:Dictionary={}
		for _n in amount:
			var target:=str(recipients[int(gs.next_random()%recipients.size())]);allocations[target]=int(allocations.get(target,0))+1
		for target in allocations:dealt+=_damage_target(gs,str(target),int(allocations[target]),owner,src,combat)
	else:
		dealt=gs._damage_avatar(victim,1,owner,src,false,combat,true)
		remaining=amount-1
	p.efDamageRedirectDepth=int(p.efDamageRedirectDepth)-1
	gs.VerifiedRules.event(gs,"ef-damage-redirected",{"player":victim,"uid":u.uid,"amount":amount,"dealt":dealt,"mode":"borrow" if borrow else "split" if split else "spring"})
	return {"remaining":remaining,"damage":0,"dealt":0,"transferredDealt":dealt,"knocked":int(u.hp)<=0,"overkill":0}
static func sole_target(gs, owner: int, frame: Dictionary, card: Dictionary) -> String:
	var t:=str(card.get("target","auto"));var target:=str(frame.get("targetId",""))
	var src:=int(frame.get("sourceIndex",-1));var caster:=str(gs.player(owner).units[src].uid) if src>=0 else ""
	# Pursuit selects an attack recipient, not the logical target of its card buffs.
	if card.get("type","")=="combat":
		# These cards additionally affect a separately selected character.
		if card.get("id","")=="c60608" and not card.get("efTrickActive",false):return ""
		if card.get("id","")=="c63807" and target!=caster:return ""
		return caster
	if card.get("type","") in ["form","awakening"] or card.get("efSoleSource",false):return caster
	if t!="auto":return target if gs._unit_index_by_uid(owner,target)>=0 else ""
	return ""

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner:=int(frame.playerIndex);var p:Dictionary=gs.player(owner);var target:=sole_target(gs,owner,frame,card)
	var caster:=int(frame.get("sourceIndex",-1))
	if caster>=0 and int(p.units[caster].get("efHeartbroken",0))>0:gain_essence(gs,1-owner,int(p.units[caster].efHeartbroken))
	# Snapshot earlier cards before recording this declaration itself.
	for pending in gs.resolution_stack:
		if pending.get("kind","")=="card-effect" and int(pending.get("resolutionId",-1))==int(frame.resolutionId):pending.efPriorTargets=p.get("efTargetsTurn",[]).duplicate() if int(p.get("efTargetsTurnId",-1))==gs.turn_counter else []
	if not frame.get("automatic",false) or card.get("usedFromHand",false):
		if not target.is_empty():
			var i:int=gs._unit_index_by_uid(owner,target);var u:Dictionary=p.units[i]
			if active(u):
				for observer in p.units:
					if role(observer)=="feast" and active(observer) and observer.awakened:
						gs._grow_unit(u,2,2);u.efFeastGrowth=int(u.get("efFeastGrowth",0))+2
				if role(u)=="feast":
					if u.awakened and _once(gs,u,"efAwakeFireTurn"):gs._set_fire(owner,int(p.energy)+1)
					p.efFansiTargetCount=int(p.get("efFansiTargetCount",0))+1
					gain_satiety(gs,owner,i,2 if card.get("neutralFood",false) or card.get("neutralEssence",false) or str(card.get("unitId",""))=="" else 1)
					if u.get("formRules",{}).get("efDivine",false):gs.VerifiedRules.Whale.grant_turn(gs,owner,u,false)
	if not target.is_empty():
		if int(p.get("efTargetsTurnId",-1))!=gs.turn_counter:p.efTargetsTurn=[];p.efTargetsTurnId=gs.turn_counter
		if not p.efTargetsTurn.has(target):p.efTargetsTurn.append(target)
	if card.get("efMealCopy",false):return
	if card.get("type","")!="spell" or card.get("typeLabel","")=="觉醒牌" or card.get("id","") in ["c60308","c60605","c63808"] or target.is_empty():return
	for realm in p.realms:
		if realm.get("nativeRealm","")=="ef-divine-meal" and int(realm.hp)>0 and _once(gs,realm,"efMealTurn"):
			var followup:Dictionary={"kind":"ef-meal-copy","playerIndex":owner,"sourceIndex":caster,"card":card.duplicate(true),"originalTarget":target}
			for n in gs.resolution_stack.size():
				var pending:Dictionary=gs.resolution_stack[n]
				if pending.get("kind","")=="card-complete" and int(pending.get("resolutionId",-1))==int(frame.resolutionId):
					gs.resolution_stack.insert(n,followup);break
static func gain_satiety(gs, owner: int, idx: int, amount: int) -> void:
	var u:Dictionary=gs.player(owner).units[idx];var old:=int(u.get("efSatiety",0));var n:=mini(5,old+amount);u.efSatiety=n
	u.attackBonus=int(u.attackBonus)+n-old;u.efSatietyApplied=int(u.get("efSatietyApplied",0))+n-old;gs._recalc(u)
	gs.VerifiedRules.event(gs,"satiety-attached",{"player":owner,"uid":u.uid,"count":n})
static func clear_satiety(gs, u: Dictionary) -> void:
	u.attackBonus=int(u.attackBonus)-int(u.get("efSatietyApplied",0));u.erase("efSatiety");u.erase("efSatietyApplied");gs._recalc(u)
static func combat_dealt(gs, owner: int, src: int, result: Dictionary) -> void:
	if owner<0 or src<0 or int(result.get("dealt",result.get("damage",0)))<=0:return
	var u:Dictionary=gs.player(owner).units[src]
	if role(u)!="feast":return
	if int(u.get("efSatiety",0))>0:clear_satiety(gs,u)
static func begin_turn(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[src]
		if active(u) and u.get("formRules",{}).get("efPowderBox",false):gain_essence(gs,owner,1)
static func attack_started(gs, owner: int, src: int) -> void:
	var u:Dictionary=gs.player(owner).units[src]
	if int(u.get("efHeartbroken",0))>0:gain_essence(gs,1-owner,int(u.efHeartbroken))
	if active(u) and u.get("formRules",{}).get("efChef",false):Food.gain_ingredient(gs,owner,src)
static func before_attacked(gs, owner: int, idx: int) -> void:
	var u:Dictionary=gs.player(owner).units[idx]
	if active(u) and u.get("formRules",{}).get("efChef",false):gain_essence(gs,owner,1)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var id:=str(card.id)
	if id=="c60304":gain_essence(gs,owner,1)
	if id=="c63802":gs.VerifiedRules.HairPower.grant_guard(gs,owner)
	if id=="c63806":Food.gain_ingredient(gs,owner,src);gain_essence(gs,owner,1)
	if id in ["c60604","c60607"]:gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
static func knocked_out(gs, owner: int, u: Dictionary) -> void:
	if int(u.get("efSatiety",0))>0:clear_satiety(gs,u)
	var growth:=int(u.get("efFeastGrowth",0));u.attackBonus=int(u.attackBonus)-growth;u.maxHpBonus=int(u.maxHpBonus)-growth
	for key in ["efBorrowTarget","efDebt","efBorrowImmune","efHeartbroken","efFeastGrowth"]:u.erase(key)
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("essenceFeastRules",false):return card
	var c:=card.duplicate(true);var src:int=gs._source_index(owner,c)
	if src<0:return c
	var u:Dictionary=gs.player(owner).units[src]
	if c.get("efTrick",false) and int(u.level)<int(c.level):
		c.printedLevel=c.level;c.level=1;c.efTrickActive=true;c.currentCardStats="戏法 · 式神勾玉不足，使用戏法效果"
		if c.id=="c63808":c.efSoleSource=false
	if c.id=="c60606":c.value=3 if c.get("efTrickActive",false) else int(gs.player(owner).get("efDamagePackets",0));c.currentCardStats="本局牌手受伤%d次"%int(gs.player(owner).get("efDamagePackets",0))
	if c.id=="c63803":
		c.value=mini(5,1+int(gs.player(owner).get("efFansiTargetCount",0)));c.currentCardStats="仅以饭笥为目标%d次 · 本次+%d力量"%[int(gs.player(owner).get("efFansiTargetCount",0)),int(c.value)]
	if c.id=="c63804":
		c.enhanced=int(gs.player(owner).get("efTargetsTurnId",-1))==gs.turn_counter and gs.player(owner).get("efTargetsTurn",[]).has(str(u.uid))
		if c.enhanced:c.keywords.append("pursuit");c.combatOption.pursuit=true;c.target="enemy-unit"
	if c.id=="c60608" and c.get("efTrickActive",false):c.target="auto";c.combatOption.immuneCombat=true
	return c
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("id","") in ["c60308","c60605","c63808"] and not card.get("efTrickActive",false):
		var src:int=gs._source_index(owner,card);return src>=0 and not gs.player(owner).units[src].awakened
	return true
static func targets(gs, owner: int, card: Dictionary):
	if card.get("neutralEssence",false):return essence_targets(gs,owner)
	if not card.get("essenceFeastRules",false):return null
	var t:=str(card.get("target","auto"));if t=="auto":return null
	var out:Array=[]
	if t=="enemy-character" and not gs.VerifiedRules.PipeFox.avatar_veil(gs,1-owner):out.append("avatar-%d"%(1-owner))
	for side in [owner] if t in ["ally-unit","ally-knocked"] else [1-owner] if t in ["enemy-unit","enemy-character"] else [owner,1-owner]:
		for u in gs.player(side).units:
			if u.get("removed",false) or (t!="enemy-character" and not gs.VerifiedRules.OwlInsect.shikigami(u)):continue
			if t=="ally-knocked":
				if int(u.hp)<=0 and not u.get("summoned",false) and gs.VerifiedRules.Rebirth.can_revive(u):out.append(str(u.uid))
			elif int(u.hp)>0 and (t=="enemy-character" or int(u.level)>0) and (side==owner or not gs.VerifiedRules.Combat.has(u,"veil")):
				if card.id=="c63807" and (int(gs.player(owner).get("efTargetsTurnId",-1))!=gs.turn_counter or not gs.player(owner).get("efTargetsTurn",[]).has(str(u.uid))):continue
				out.append(str(u.uid))
	return out
static func _install(gs, owner: int, src: int, card: Dictionary) -> void:
	gs._install_form(owner,src,card,card.value)
static func _attack(gs, owner: int, src: int, card: Dictionary, target, extra: Dictionary = {}) -> void:
	var opts:Dictionary=card.get("combatOption",{}).duplicate(true);opts.merge(extra,true);opts.combatCard=card.duplicate(true)
	gs._grant_unit_armor(gs.player(owner).units[src],int(opts.get("shield",0)))
	gs._resolve_combat(owner,src,int(card.get("value",0)),card.get("keywords",[]).has("pierce"),false,false,false,target,false,opts)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if effect.get("action","")!="ef-card":return false
	var p:Dictionary=gs.player(owner);var u:Dictionary=p.units[src];var t:Dictionary=gs._unit_by_uid(gs._all_units(),str(target_id));var id:=str(card.id)
	if id in ["c60302","c60304","c60601","c60603","c60607","c63802","c63806"]:_install(gs,owner,src,card)
	elif id in ["c60306","c60604","c63805"]:
		gs._deploy_realm(owner,card)
		if id=="c60604":gs.VerifiedRules.Movement.move_to(gs,owner,src,1);gain_essence(gs,owner,3)
	elif id=="c60301":
		if not t.is_empty():t.efHeartbroken=int(t.get("efHeartbroken",0))+1
	elif id in ["c60303","c60602"]:
		if not t.is_empty():
			gs.VerifiedRules.Peach.revive(gs,owner,src,t,false,false)
			if id=="c60303":gain_essence(gs,owner,2)
			else:gs._damage_avatar(owner,int(t.hp),owner,src)
	elif id=="c60305":
		var excess:=0
		for target in p.units:
			if int(target.hp)>0:excess+=maxi(0,2-(int(target.maxHp)-int(target.hp)));gs._heal_unit(target,2)
		gain_essence(gs,owner,excess)
	elif id=="c60307" or id=="c60606":
		if not t.is_empty():
			var amount:=2 if id=="c60307" and card.get("efTrickActive",false) else 6 if id=="c60307" else int(card.value)
			var side:=owner if gs._unit_index_by_uid(owner,str(t.uid))>=0 else 1-owner
			gs._damage_unit(side,gs._unit_index_by_uid(side,str(t.uid)),amount,owner,src)
			if id=="c60307":gain_essence(gs,owner,2 if card.get("efTrickActive",false) else 6)
	elif id in ["c60308","c60605","c63808"]:
		if id=="c63808" and card.get("efTrickActive",false):Food.gain_ingredient(gs,owner,src);gain_essence(gs,owner,1)
		else:gs._awaken(owner,src,card,card.value)
	elif id=="c60608":
		if card.get("efTrickActive",false):_attack(gs,owner,src,card,null,{"immuneCombat":true})
		else:u.efBorrowTarget=str(target_id);_attack(gs,owner,src,card,null)
	elif id=="c63801":
		var idx:int=gs._unit_index_by_uid(owner,str(target_id));var prior:Array=gs._card_effect_context.get("efPriorTargets",[])
		if idx>=0 and active(p.units[idx]):gs._resolve_combat(owner,idx,0,false,false,false,false,null,false,{"immuneCombat":prior.has(str(target_id))})
	elif id in ["c63803","c63804"]:_attack(gs,owner,src,card,target_id,{"penetration":id=="c63803"})
	elif id=="c63807":
		var idx:int=gs._unit_index_by_uid(owner,str(target_id));var prior:Array=gs._card_effect_context.get("efPriorTargets",[])
		if idx>=0 and active(p.units[idx]) and prior.has(str(target_id)):
			_frame(gs,"ef-attack-after",owner,idx,{"afterUid":str(u.uid),"afterCard":card.duplicate(true)});_attack(gs,owner,src,card,null)
	return true
static func combat_finished(gs, owner: int, src: int) -> void:
	gs.player(owner).units[src].erase("efBorrowTarget")
static func _box(gs, owner: int, src: int) -> int:
	var p:Dictionary=gs.player(owner);var master:Dictionary=p.units[src];var def:Dictionary=Content.unit_def("fenpopo")
	var body:Dictionary={"uid":"%s:powder-box-%d"%[p.id,gs.next_card_id],"id":"ef-powder-box","name":"粉盒","title":"粉婆婆召唤物","art":def.art,"color":def.color,"baseAttack":3,"baseMaxHp":3,"attack":3,"maxHp":3,"hp":3,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formHooks":[],"formAbility":"融合。离开战斗区时移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"efPowderBoxSummon":true,"summonerUid":master.uid}
	gs.next_card_id+=1
	for i in p.units.size():
		if p.units[i].get("efPowderBoxSummon",false) and active(p.units[i]) and int(p.units[i].front)==1:return gs.VerifiedRules.Weaver.combine(gs,owner,body,i)
	gs.VerifiedRules.Weaver.leave_front(gs,owner);p.units.append(body);var idx:int=p.units.size()-1
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":body.uid,"sourceUid":master.uid,"summonKind":"powder-box"});gs.VerifiedRules.Weaver.entered(gs,owner,idx);return idx
static func remove_box(gs, owner: int, unit: Dictionary) -> void:
	if not unit.get("efPowderBoxSummon",false) or unit.get("removed",false):return
	unit.hp=0;unit.front=0;unit.knockout=0;unit.removed=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":unit.uid,"reason":"粉盒离开战斗区"})
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("efPowderBoxSummon",false) and int(u.front)==0 and int(u.hp)>0:remove_box(gs,owner,u)
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""));var owner:=int(frame.get("playerIndex",0));var src:=int(frame.get("sourceIndex",-1))
	var card:Dictionary=frame.get("cardOverride",{})
	if card.get("neutralEssence",false):
		if kind=="card-announce":gs.VerifiedRules.announce_neutral_food(gs,frame);return true
		if kind=="card-effect":
			var target:=str(frame.targetId)
			for side in 2:
				if target=="avatar-%d"%side:gs._heal_avatar(side,int(card.get("efStacks",1)))
				else:
					var idx:int=gs._unit_index_by_uid(side,target)
					if idx>=0:gs._heal_unit(gs.player(side).units[idx],int(card.get("efStacks",1)))
			return true
		if kind=="card-complete":
			gs.VerifiedRules.Arakawa.completed(gs,frame,card);gs.VerifiedRules.HandBlessing.completed(gs,owner,-1,card)
			gs.VerifiedRules.Insight.used(gs, owner, card, card.get("playedInstance", {}), true, frame.targetId)
			return true
	if not kind.begins_with("ef-"):return false
	match kind:
		"ef-projectile":_projectile(gs,owner,src,int(frame.amount))
		"ef-powder-hit":
			if src>=0 and active(gs.player(owner).units[src]):
				if frame.randomUnit:
					var units:Array=gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u))
					if not units.is_empty():gs.VerifiedRules.base_damage_unit(gs,owner,src,1-owner,gs._unit_index_by_uid(1-owner,str(units[int(gs.next_random()%units.size())].uid)),int(frame.amount))
				else:_projectile(gs,owner,src,int(frame.amount))
		"ef-box":
			if active(gs.player(owner).units[src]):_box(gs,owner,src)
		"ef-attack":
			if active(gs.player(owner).units[src]):gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"immuneCombat":frame.get("immune",false)})
		"ef-attack-after":
			if active(gs.player(owner).units[src]):gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{})
		"ef-auto-awake":
			var u:Dictionary=gs.player(owner).units[src];u.erase("efAwakeQueued")
			if active(u) and not u.awakened and int(u.level)>=3:
				for zone in ["hand","deck"]:
					var pile:Array=gs.player(owner)[zone]
					for i in pile.size():
						if pile[i].definitionId!="c60308":continue
						var instance:Dictionary=pile.pop_at(i);var c:Dictionary=Content.card_def("c60308").duplicate(true);c.playedInstance=instance;c.usedFromHand=zone=="hand";gs._push_card_frames(owner,c.id,null,c,src,0,true);return true
		"ef-meal-copy":
			var c:Dictionary=frame.card.duplicate(true);c.efMealCopy=true;c.usedFromHand=false
			var pool:Array=gs.valid_targets(owner,c).filter(func(uid):return str(uid)!=str(frame.originalTarget) and gs._unit_index_by_uid(owner,str(uid))>=0)
			if not pool.is_empty():
				var target:=str(pool[int(gs.next_random()%pool.size())])
				if c.get("neutralEssence",false):_push_essence(gs,owner,c,target,true)
				elif c.get("neutralFood",false):Food._push_food(gs,owner,c,target,false,true)
				elif src>=0:gs._push_card_frames(owner,str(c.id),target,c,src,0,true)
	return true
static func score_card(gs, owner: int, card: Dictionary, target):
	if card.get("neutralEssence",false):
		if str(target)=="avatar-%d"%owner:return 25+mini(int(card.efStacks),int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp))*5
		var u:Dictionary=gs._unit_by_uid(gs.player(owner).units,str(target));return 30 if not u.is_empty() else -100
	if not card.get("essenceFeastRules",false):return null
	if card.id in ["c63801","c63807"]:
		var idx:int=gs._unit_index_by_uid(owner,str(target));return 55 if idx>=0 and active(gs.player(owner).units[idx]) else -100
	if card.id in ["c60307","c60606"]:return 50 if gs._unit_index_by_uid(1-owner,str(target))>=0 else -100
	if card.id in ["c60308","c60605","c63808"]:return 70 if not card.get("efTrickActive",false) else 35
	return 45
static func marks(gs, owner: int, u: Dictionary) -> Array:
	var out:Array=[]
	if int(u.get("efSatiety",0))>0:out.append("饱足%d／5 · 战伤后移除"%int(u.efSatiety))
	if int(u.get("efHeartbroken",0))>0:out.append("负心%d · 出击或使用牌时敌方获得生命精华"%int(u.efHeartbroken))
	if role(u)=="pearl":out.append("本局牌手受到伤害%d次"%int(gs.player(owner).get("efDamagePackets",0)))
	if role(u)=="feast":out.append("本局手牌仅以饭笥为目标%d次"%int(gs.player(owner).get("efFansiTargetCount",0)))
	return out
static func reset_ledger(u: Dictionary) -> void:
	u.erase("efSatietyApplied");u.erase("efFeastGrowth")
static func fuse_revived(gs, owner: int, idx: int) -> int:
	var u:Dictionary=gs.player(owner).units[idx]
	if not u.get("efPowderBoxSummon",false):return -1
	for i in gs.player(owner).units.size():
		var old:Dictionary=gs.player(owner).units[i]
		if i!=idx and old.get("efPowderBoxSummon",false) and active(old) and int(old.front)==1:return gs.VerifiedRules.Weaver.combine(gs,owner,u,i,idx)
	return -1
