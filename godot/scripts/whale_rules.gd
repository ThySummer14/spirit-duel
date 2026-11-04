class_name WhaleRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Charge := preload("res://scripts/sun_smoke_rules.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("whaleRules",false)
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func charm(u: Dictionary, kind: String) -> bool:
	return not u.get("whale"+kind,{}).is_empty()
static func attach(gs, owner: int, src: int, u: Dictionary, kind: String, permanent: bool=false) -> void:
	if u.is_empty() or int(u.hp)<=0 or u.get("removed",false): return
	var key := "whale"+kind
	if charm(u,kind) and not permanent: return
	u[key]={"sourceOwner":owner,"sourceUid":gs.player(owner).units[src].uid,"permanent":permanent or u.get(key,{}).get("permanent",false)}
	gs.VerifiedRules.event(gs,"whale-charm-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":u.uid,"charm":kind,"permanent":bool(u[key].permanent)})
static func remove_charms(u: Dictionary, include_permanent: bool=true) -> void:
	for key in ["whaleTooth","whaleBody"]:
		if include_permanent or not u.get(key,{}).get("permanent",false): u.erase(key)
static func knocked_out(u: Dictionary) -> void:
	remove_charms(u,false)
	u.erase("whaleTemporary")

static func trigger_charms(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if int(u.hp)<=0: return
	# Charms belong to the carrier. They remain functional if 化鲸 is KO.
	if charm(u,"Tooth"):
		var victim := 1-owner
		var idx: int=gs.front_index(victim)
		var context: Dictionary=gs._card_effect_context; gs._card_effect_context={}
		var amount: int=gs._damage_avatar(victim,2,owner,src) if idx<0 else int(gs._damage_unit(victim,idx,2,owner,src).get("damage",0))
		gs._card_effect_context=context
		gs.VerifiedRules.event(gs,"whale-tooth-hit",{"player":owner,"uid":u.uid,"target":"" if idx<0 else gs.player(victim).units[idx].uid,"victimPlayer":victim,"amount":amount,"blocked":amount==0,"card":{"id":"whale-tooth","unitId":"huajing","type":"ability","name":"齿甲"}})
	if charm(u,"Body") and int(u.hp)>0:
		var missing := maxi(0,int(u.maxHp)-int(u.hp))
		gs._heal_unit(u,2)
		gs._heal_avatar(owner,maxi(0,2-missing))
		gs.VerifiedRules.event(gs,"whale-body-heal",{"player":owner,"uid":u.uid,"amount":mini(2,missing),"overflow":maxi(0,2-missing)})
static func before_basic(gs, owner: int, src: int) -> void:
	var attacker: Dictionary=gs.player(owner).units[src]
	# The guardian sacrifices before any combat/skill replaces the deployment.
	if not attacker.get("summoned",false) and not attacker.get("summon",false):
		for old in gs.player(owner).units:
			if old.get("whaleGuardian",false) and int(old.hp)>0 and int(old.front)==1 and not old.get("removed",false):
				remove_summon(gs,owner,old,"母亲的守护：出击赋予障壁")
				attacker.barrier=true
				gs.VerifiedRules.event(gs,"barrier-gained",{"player":owner,"uid":attacker.uid})
	var frames: Array=[]
	if charm(attacker,"Tooth") or charm(attacker,"Body"): frames.append({"kind":"whale-charms","playerIndex":owner,"sourceIndex":src})
	if gs.VerifiedRules.OwlInsect.shikigami(attacker):
		for i in gs.player(owner).units.size():
			var u: Dictionary=gs.player(owner).units[i]
			if source(u) and active(u) and int(u.get("whaleChargeTurn",-1))!=gs.turn_counter:
				u.whaleChargeTurn=gs.turn_counter
				Charge.gain_charge(gs,owner,i,1)
				if u.awakened: frames.append({"kind":"whale-charms","playerIndex":owner,"sourceIndex":i})
	for i in range(frames.size()-1,-1,-1): gs.resolution_stack.append(frames[i])

static func burst(gs, owner: int, src: int, amount: int) -> void:
	# Explicit 爆能 only; paying charge for movement/abilities is not a burst.
	var p: Dictionary=gs.player(owner)
	p.whaleBursts=int(p.get("whaleBursts",0))+1
	gs.VerifiedRules.event(gs,"burst-used",{"player":owner,"uid":p.units[src].uid,"amount":amount,"count":int(p.whaleBursts)})
	for field in p.realms:
		if int(field.hp)>0 and field.get("nativeRealm")=="whale-sea" and gs.front_index(owner)<0: summon(gs,owner,src)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("whaleRules",false): return card
	var out := card.duplicate(true)
	out.movementBurst=int(inst.get("movementBurst",0))
	if not out.get("movementBurstOptions",[]).is_empty(): out.currentCardStats="普通使用" if int(out.movementBurst)==0 else "爆能%d"%int(out.movementBurst)
	if out.id=="c27807":
		var n := int(gs.player(owner).get("whaleBursts",0))
		out.value={"attack":3+2*n,"hp":3+2*n,"setBase":true}
		out.effects[0].value=out.value.duplicate()
		out.currentCardStats="本局爆能%d次 · 当前%d/%d"%[n,3+2*n,3+2*n]
	return out
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("whaleRules",false): return true
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	if card.id=="c27806" and gs.player(owner).units[src].awakened: return false
	var n := int(card.get("movementBurst",0))
	return n==0 or (card.get("movementBurstOptions",[]).any(func(v):return int(v)==n) and gs.VerifiedRules.Yujiazhu.can_pay_burst(gs,owner,src,n))
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("whaleRules",false) or card.get("target","auto")=="auto": return null
	var ids: Array=[]
	for side in [owner,1-owner] if card.id=="c27803" else [owner]:
		for u in gs.player(side).units:
			if int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u) and (side==owner or not gs.VerifiedRules.Combat.has(u,"veil")): ids.append(u.uid)
	return ids
static func grant_turn(gs, owner: int, u: Dictionary, inspired: bool) -> void:
	if int(u.hp)<=0: return
	if not u.has("whaleTemporary"): u.whaleTemporary={"turn":gs.turn_counter,"swift":bool(u.get("swift",false)),"inspired":bool(u.get("inspired",false)),"grantsInspired":false}
	u.swift=true
	gs.VerifiedRules.event(gs,"swift-gained",{"player":owner,"uid":u.uid})
	if inspired:
		u.whaleTemporary.grantsInspired=true
		u.inspired=true
		gs.VerifiedRules.event(gs,"inspired-gained",{"player":owner,"uid":u.uid})
static func end_turn(gs) -> void:
	for p in gs.players:
		for u in p.units:
			var temp: Dictionary=u.get("whaleTemporary",{})
			if temp.is_empty() or int(temp.turn)>gs.turn_counter: continue
			if not temp.swift: u.swift=false
			if temp.grantsInspired and not temp.inspired: u.erase("inspired")
			u.erase("whaleTemporary")
static func memory(gs, owner: int, src: int, u: Dictionary) -> void:
	attach(gs,owner,src,u,"Tooth"); attach(gs,owner,src,u,"Body"); grant_turn(gs,owner,u,true)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	if effect.get("action")!="whale-card": return false
	var u: Dictionary=gs.player(owner).units[src]
	var amount := int(card.get("movementBurst",0))
	if amount>0:
		if not gs.VerifiedRules.Yujiazhu.pay_burst(gs,owner,src,amount): return true
		burst(gs,owner,src,amount)
	match str(card.id):
		"c27801","c27802":
			attach(gs,owner,src,target,"Tooth" if card.id=="c27801" else "Body")
			if amount>0:
				gs.player(owner).hand.append({"instanceId":"%s-whale-%d"%[gs.player(owner).id,gs.next_card_id],"definitionId":"c27802" if card.id=="c27801" else "c27801"})
				gs.next_card_id+=1
				if gs.player(owner).hand.size()>int(gs.rules.maxHandSize): gs.player(owner).hand.pop_back()
				gs.VerifiedRules.event(gs,"whale-card-created",{"player":owner,"uid":u.uid,"cardId":"c27802" if card.id=="c27801" else "c27801"})
		"c27803":
			for side in [owner,1-owner]:
				var idx: int=gs._unit_index_by_uid(side,target_id)
				if idx>=0: gs._damage_unit(side,idx,3+int(u.get("spellPower",0)),owner,src)
			for ally in gs.player(owner).units:
				if charm(ally,"Tooth") or charm(ally,"Body"): grant_turn(gs,owner,ally,false)
		"c27804":
			gs._deploy_realm(owner,card)
			if amount>0:
				summon(gs,owner,src)
		"c27805":
			gs._grant_unit_armor(u,1)
			var options: Dictionary={"whaleGuardAfter":true,"combatCard":card.duplicate(true)}
			gs._resolve_combat(owner,src,1,false,false,false,false,target_id,false,options)
		"c27806":
			gs.pending_choice={"type":"whale-awaken","playerIndex":owner,"sourceIndex":src,"card":card,"instanceIds":["whale-tooth","whale-body"],"heading":"觉 醒 · 化 鲸","title":"选择永久结附的灵咒","hint":"只选择一种；已有另一种灵咒会保留。"}
			gs.phase="choice"
		"c27807": gs._install_form(owner,src,card,card.value)
		"c27808":
			memory(gs,owner,src,target)
			if amount>0:
				var pool: Array=targets(gs,owner,card).filter(func(uid):return uid!=target.uid)
				for i in mini(2 if amount==10 else 1,pool.size()):
					var at := int(floor(gs.randf01()*pool.size()))
					var uid=pool.pop_at(at)
					memory(gs,owner,src,gs._unit_by_uid(gs.player(owner).units,uid))
	return true

static func choice_card(gs, _owner: int, iid: String):
	if gs.pending_choice.get("type")!="whale-awaken": return null
	var tooth := iid=="whale-tooth"
	return {"id":iid,"unitId":"huajing","type":"spell","level":2,"cost":0,"name":"永久齿甲" if tooth else "永久体甲","text":"出击时，投射：造成2点伤害。\n永久结附，气绝保留。" if tooth else "出击时，恢复自身2生命；过量部分恢复牌手生命。\n永久结附，气绝保留。"}
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary=gs.pending_choice
	if c.get("type")!="whale-awaken" or int(c.playerIndex)!=owner or not c.instanceIds.has(iid): return false
	var src := int(c.sourceIndex)
	attach(gs,owner,src,gs.player(owner).units[src],"Tooth" if iid=="whale-tooth" else "Body",true)
	gs._awaken(owner,src,c.card,{"attack":0,"hp":0})
	gs.pending_choice={}; gs.phase="main"
	gs._record("resolve_divination_choice",{"instanceId":iid,"choice":"whale-awaken"},owner)
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true
static func ai_prepare(gs, owner: int) -> void:
	for i in gs.playable_card_count(owner):
		var inst: Dictionary=gs.card_instance(owner,i)
		var card: Dictionary=Content.card_def(str(inst.definitionId))
		if not card.get("whaleRules",false): continue
		var src: int=gs._source_index(owner,card)
		if src<0: continue
		inst.movementBurst=0
		for n in card.get("movementBurstOptions",[]):
			if gs.VerifiedRules.Yujiazhu.can_pay_burst(gs,owner,src,int(n)): inst.movementBurst=int(n)
static func ai_choice(gs, owner: int) -> bool:
	var u: Dictionary=gs.player(owner).units[int(gs.pending_choice.sourceIndex)]
	return resolve_choice(gs,owner,"whale-body" if charm(u,"Tooth") and not charm(u,"Body") else "whale-tooth")
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("whaleRules",false): return null
	var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,target_id)
	if card.id=="c27803": return -100 if not u.is_empty() else 65
	if card.id in ["c27801","c27802"]: return -20 if charm(u,"Tooth" if card.id=="c27801" else "Body") else 60+int(u.get("attack",0))
	if card.id=="c27806": return 90
	if card.id=="c27807": return -50 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 65+int(gs.player(owner).get("whaleBursts",0))*4
	if card.id=="c27808": return 65+int(card.get("movementBurst",0))*2
	return 60

static func remove_summon(gs, owner: int, u: Dictionary, reason: String="离开战斗区") -> void:
	if not u.get("whaleGuardian",false) or u.get("removed",false): return
	var idx: int=gs._unit_index_by_uid(owner,u.uid)
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,idx,reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,idx,reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("whaleGuardian",false) and int(u.hp)>0 and int(u.front)==0: remove_summon(gs,owner,u)
static func summon(gs, owner: int, src: int) -> void:
	gs.VerifiedRules.Weaver.leave_front(gs,owner)
	var p: Dictionary=gs.player(owner)
	var u: Dictionary={"id":"whale-guardian","name":"母亲的守护","title":"化鲸召唤物","color":"#80c0e0","shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"charge":0,"removed":false,"baseAttack":3,"baseMaxHp":3,"attack":3,"maxHp":3,"hp":3,"level":1,"front":1,"summoned":true,"summon":true,"countsAsShikigami":true,"whaleGuardian":true,"barrier":false,"passive_hooks":[]}
	u.uid="%s:guardian-%d"%[p.id,gs.next_card_id]; gs.next_card_id+=1
	u.art=Content.unit_def("huajing").art; u.awakenedArt=u.art
	u.summonerUid=p.units[src].uid; u.formAbility="非召唤物己方式神出击时，消失并使其获得障壁。"
	p.units.append(u)
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":u.summonerUid,"summonKind":"母亲的守护"})
	gs._fire_hooks(owner,p.units.size()-1,"unit-entered-front",{}); gs._run_form_hooks(owner,p.units.size()-1,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if options.get("whaleGuardAfter",false) and options.get("whaleAttackStarted",false) and int(gs.player(owner).units[src].hp)>0: summon(gs,owner,src)
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="whale-charms": return false
	trigger_charms(gs,int(frame.playerIndex),int(frame.sourceIndex)); return true
static func unit_marks(gs, owner: int, src: int) -> Array:
	var u: Dictionary=gs.player(owner).units[src]; var result: Array=[]
	if charm(u,"Tooth"): result.append("齿甲 · 出击投射2"+(" · 永久" if u.whaleTooth.permanent else ""))
	if charm(u,"Body"): result.append("体甲 · 出击自疗2，溢出治疗牌手"+(" · 永久" if u.whaleBody.permanent else ""))
	if source(u): result.append("出击充能 · "+("本回合已触发" if int(u.get("whaleChargeTurn",-1))==gs.turn_counter else "本回合可触发")+" · 本局爆能%d次"%int(gs.player(owner).get("whaleBursts",0)))
	if u.get("whaleGuardian",false): result.append("母亲的守护 · 非召唤物己方式神出击时消失并赋予障壁")
	return result
