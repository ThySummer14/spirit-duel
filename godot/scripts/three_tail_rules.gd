class_name ThreeTailRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("threeTailRules",false))
static func active(u: Dictionary) -> bool:
	return source(u) and int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func level(u: Dictionary) -> int:
	return int(u.get("level",0))+(1 if u.get("formRules",{}).get("threeTailExtraLevel",false) else 0)
static func free_first(gs, owner: int) -> bool:
	return not gs.player(owner).get("threeTailFirstUsed",false) and gs.player(owner).units.any(func(u):return active(u))
static func card_used(gs, owner: int, _src: int, _card: Dictionary, _automatic: bool) -> void:
	# This is one use in the whole game, not one use each turn or each revival.
	gs.player(owner).threeTailFirstUsed=true
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if int(card.get("level",0))!=1:return
	var owner:=int(frame.playerIndex)
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[src]
		if active(u) and u.awakened:gs.resolution_stack.append({"kind":"three-tail-projectile","playerIndex":owner,"sourceIndex":src,"amount":1,"reason":"觉醒使用一勾牌"})
static func projectile(gs, owner: int, src: int, amount: int, reason: String = "投射") -> void:
	var idx: int=gs.front_index(1-owner)
	if idx<0:gs._damage_avatar(1-owner,amount,owner,src)
	else:gs._damage_unit(1-owner,idx,amount,owner,src)
	gs.VerifiedRules.event(gs,"three-tail-projectile",{"player":owner,"uid":gs.player(owner).units[src].uid,"amount":amount,"target":"avatar-%d"%(1-owner) if idx<0 else gs.player(1-owner).units[idx].uid,"reason":reason})
static func _instance(gs, owner: int, id: String) -> void:
	var inst: Dictionary={"instanceId":"three-tail-%d"%gs.next_card_id,"definitionId":id}
	gs.next_card_id+=1
	if gs.player(owner).hand.size()<int(gs.rules.maxHandSize):gs.player(owner).hand.append(inst)
	gs.VerifiedRules.event(gs,"three-tail-generated",{"player":owner,"card":Content.card_def(id),"instanceId":inst.instanceId})
static func _pool(gs, owner: int, mode: String) -> Array:
	var owned: Array=[]
	for u in gs.player(owner).units:
		if not u.get("summoned",false) and not owned.has(str(u.id)):owned.append(str(u.id))
	return Content.load_content().cards.filter(func(c):return not c.get("token",false) and int(c.get("deckLimit",2))>0 and ((c.unitId=="sanweihu" and (c.type=="combat" or Content.is_spell(c))) if mode=="red" else (owned.has(str(c.unitId)) and int(c.get("level",0))==1)))
static func _draw_random(gs, owner: int, mode: String, count: int) -> void:
	var pool:=_pool(gs,owner,mode)
	for n in count:
		if pool.is_empty():return
		_instance(gs,owner,str(pool[mini(pool.size()-1,int(gs.randf01()*pool.size()))].id))
static func _discards(gs, owner: int, mode: String) -> Array:
	var out: Array=[]
	for idx in gs.player(owner).hand.size():
		var c: Dictionary=gs.hand_card_def(owner,idx)
		if (int(c.get("level",0))>=2 if mode=="transform" else (c.get("type")=="combat" or Content.is_spell(c))):out.append(str(gs.player(owner).hand[idx].instanceId))
	return out
static func _choice(gs, owner: int, src: int, mode: String, count: int = 1) -> void:
	var ids:=_discards(gs,owner,mode)
	if ids.is_empty():return
	gs.pending_choice={"type":"three-tail-"+mode,"playerIndex":owner,"sourceIndex":src,"instanceIds":ids,"zone":"hand","count":count,"heading":"化 形" if mode=="transform" else "红颜怒发","title":"选择弃掉一张等级≥2的牌" if mode=="transform" else "选择弃掉一张战斗牌或法术牌","hint":"弃掉实际手牌后，随机获得%d张己方式神的1勾牌。"%count if mode=="transform" else "弃掉实际手牌后，随机获得一张三尾狐战斗牌或法术牌。"}
	gs.phase="choice"
static func choice_card(gs, owner: int, iid: String):
	if not str(gs.pending_choice.get("type","")).begins_with("three-tail-") or int(gs.pending_choice.get("playerIndex",-1))!=owner:return null
	for idx in gs.player(owner).hand.size():
		if str(gs.player(owner).hand[idx].instanceId)==iid and gs.pending_choice.instanceIds.has(iid):return gs.hand_card_def(owner,idx)
	return null
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary=gs.pending_choice
	if not str(c.get("type","")).begins_with("three-tail-") or int(c.get("playerIndex",-1))!=owner or not c.get("instanceIds",[]).has(iid):return false
	var mode: String="transform" if c.type=="three-tail-transform" else "red"
	if not _discards(gs,owner,mode).has(iid):return false
	var p: Dictionary=gs.player(owner)
	for idx in p.hand.size():
		if str(p.hand[idx].instanceId)==iid:
			var inst: Dictionary=p.hand.pop_at(idx)
			gs.VerifiedRules.event(gs,"three-tail-discard",{"player":owner,"uid":p.units[int(c.sourceIndex)].uid,"card":Content.card_def(str(inst.definitionId)),"instanceId":iid})
			break
	gs.pending_choice={};gs.phase="main"
	_draw_random(gs,owner,mode,int(c.count))
	gs._record("resolve_divination_choice",{"instanceId":iid,"choice":c.type},owner)
	gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
	var c: Dictionary=gs.pending_choice
	if not str(c.get("type","")).begins_with("three-tail-"):return null
	if int(c.playerIndex)!=owner:return false
	var best:=str(c.instanceIds[0]);var cost:=-1
	for iid in c.instanceIds:
		var card: Dictionary=choice_card(gs,owner,str(iid))
		if int(card.get("level",0))>cost:cost=int(card.get("level",0));best=str(iid)
	return resolve_choice(gs,owner,best)
static func _form_trigger(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u):return
	if u.get("formRules",{}).get("threeTailRandom",false):
		for n in level(u):gs.resolution_stack.append({"kind":"three-tail-random-hit","playerIndex":owner,"sourceIndex":src})
	if u.get("formRules",{}).get("threeTailExtraLevel",false):gs.resolution_stack.append({"kind":"three-tail-red-choice","playerIndex":owner,"sourceIndex":src})
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("threeTailRules",false):_form_trigger(gs,owner,src)
static func turn_start(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size()-1,-1,-1):_form_trigger(gs,owner,src)
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("threeTailRules",false):return card
	var out:=card.duplicate(true);var src: int=gs._source_index(owner,card)
	if src<0:return out
	var u: Dictionary=gs.player(owner).units[src];var lev:=level(u);var bonus:=int(u.get("spellPower",0))
	out.threeTailLevel=lev
	match str(card.id):
		"c27201":out.currentCardStats="结算等级%d · 伤害%d"%[lev,lev*2+bonus]
		"c27202":out.value=lev;out.combatOption={"shield":lev};out.currentCardStats="结算等级%d · +%d力量/+%d护甲"%[lev,lev,lev]
		"c27203":out.currentCardStats="结算等级%d · 随机获得%d张1勾牌"%[lev,lev+1]
		"c27204":out.currentCardStats="结算等级%d · 伤害/治疗各%d"%[lev,lev+1+bonus]
		"c27206":out.currentCardStats="结算等级%d · 鼓舞+%d/+%d，压制-%d/-%d"%[lev,lev,lev,lev,lev]
		"c27208":out.currentCardStats="结算等级%d · 投射%d伤害"%[lev,lev]
		_:out.currentCardStats="形态4/5 · 结算等级%d"%lev
	return out
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("threeTailRules",false) or card.id!="c27201":return null
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("threeTailRules",false):return true
	var src: int=gs._source_index(owner,card)
	if src<0:return false
	if card.id=="c27203":return not _discards(gs,owner,"transform").is_empty()
	if card.id=="c27208":return not gs.player(owner).units[src].awakened
	return true
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, _target_id) -> bool:
	var u: Dictionary=gs.player(owner).units[src];var lev:=level(u);var bonus:=int(u.get("spellPower",0))
	match str(effect.get("action","")):
		"three-tail-flame":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid","")))
			if idx>=0:gs._damage_unit(1-owner,idx,2*lev+bonus,owner,src)
		"three-tail-assault":
			gs._grant_unit_armor(u,lev);gs._resolve_combat(owner,src,lev,false,false,false,false,null,false,{"combatCard":card})
		"three-tail-transform":_choice(gs,owner,src,"transform",lev+1)
		"three-tail-tempt":gs._damage_avatar(1-owner,lev+1+bonus,owner,src);gs._heal_avatar(owner,lev+1+bonus)
		"three-tail-charm":gs._apply_encourage(owner,lev,lev);gs.VerifiedRules.StarBear.suppress(gs,owner,lev,lev)
		"three-tail-awaken":
			var was_awake: bool=u.awakened
			projectile(gs,owner,src,lev,"觉醒主动效果")
			gs._awaken(owner,src,card,{"attack":0,"hp":0})
			if not was_awake:gs.resolution_stack.append({"kind":"three-tail-projectile","playerIndex":owner,"sourceIndex":src,"amount":1,"reason":"觉醒本身为一勾牌"})
		_:return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner:=int(frame.get("playerIndex",0));var src:=int(frame.get("sourceIndex",-1))
	match str(frame.get("kind","")):
		"three-tail-projectile":gs.VerifiedRules.base_damage_projectile(gs,owner,src,int(frame.amount),str(frame.get("reason","投射")))
		"three-tail-red-choice":
			if active(gs.player(owner).units[src]):_choice(gs,owner,src,"red")
		"three-tail-random-hit":
			var pool: Array=gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and not u.get("removed",false)).map(func(u):return str(u.uid))
			pool.append("avatar-%d"%(1-owner))
			var chosen: String=pool[mini(pool.size()-1,int(gs.randf01()*pool.size()))]
			if chosen.begins_with("avatar-"):gs._damage_avatar(1-owner,1,owner,src)
			else:gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,chosen),1,owner,src)
			gs.VerifiedRules.event(gs,"three-tail-random-hit",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":chosen,"amount":1})
		_:return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("threeTailRules",false):return null
	var src: int=gs._source_index(owner,card);var u: Dictionary=gs.player(owner).units[src]
	if card.id=="c27201":
		var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return 60+int(target.get("attack",0))*2-int(target.get("hp",0))
	if card.id=="c27203":return 45 if can_use(gs,owner,card) else -100
	if card.id=="c27208":return 90
	if card.type=="form":return 65 if str(u.get("form",{}).get("cardId",""))!=str(card.id) else -20
	return 45
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]
	if not source(u):return []
	return ["本局首张使用/蓄力免费："+("已用" if gs.player(owner).get("threeTailFirstUsed",false) else "可用"),"卡牌结算等级%d（实际%d勾）"%[level(u),int(u.level)]]
