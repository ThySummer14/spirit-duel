class_name BoxMaidenRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Charge := preload("res://scripts/sun_smoke_rules.gd")
static func source(u: Dictionary) -> bool:return bool(Content.runtime_unit_def(u).get("boxMaidenRules",false))
static func active(u: Dictionary) -> bool:return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func die_rolled(gs, owner: int, value: int) -> void:
	for idx in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[idx]
		if not source(u) or not active(u) or (not u.awakened and int(u.get("boxDieTurn",-1))==gs.turn_counter):continue
		u.boxDieTurn=gs.turn_counter;Charge.gain_charge(gs,owner,idx,value)
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("boxMaidenRules",false):return true
	var src:int=gs._source_index(owner,card)
	return src>=0 and (card.id!="c24304" or not gs.player(owner).units[src].awakened)
static func describe_card(_gs, _owner: int, card: Dictionary) -> Dictionary:
	if not card.get("boxMaidenRules",false):return card
	var c:=card.duplicate(true);var burst:=int(c.get("movementBurst",0))==10
	if not c.get("movementBurstOptions",[]).is_empty():c.currentCardStats="爆能10 · "+str(c.get("boxBurstText","")) if burst else "普通使用 · 可选择爆能10"
	if c.id=="c24305":
		c.value.hp=10 if burst else 5;c.effects[0].value=c.value.duplicate(true)
	return c
static func targets(gs, owner: int, card: Dictionary):
	if card.get("id","")!="c24307":return null
	return gs.player(owner).units.filter(func(u):return not u.get("summoned",false) and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u)).map(func(u):return u.uid)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("boxTreasure",false):
		if gs.VerifiedRules.Light.roll(gs,owner,4,6,src):
			for copy in gs.VerifiedRules.Fortune.last_repeats(gs,owner):gs.resolution_stack.append({"kind":"box-divination","playerIndex":owner,"sourceIndex":src})
	elif card.get("formRules",{}).get("boxBrilliant",false):form_turn_start(gs,owner,src)
static func form_turn_start(gs, owner: int, src: int) -> void:
	var u:Dictionary=gs.player(owner).units[src]
	if active(u) and u.get("formRules",{}).get("boxBrilliant",false) and gs.VerifiedRules.Light.roll(gs,owner,4,6,src):
		for copy in gs.VerifiedRules.Fortune.last_repeats(gs,owner):gs.VerifiedRules.Light.gain_fire(gs,owner,1)
static func end_turn(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u:Dictionary=gs.player(owner).units[src]
		if not active(u):continue
		var mode:="draw" if u.get("formRules",{}).get("boxTreasure",false) else "projectile" if u.get("formRules",{}).get("boxBrilliant",false) else ""
		if mode!="":gs.resolution_stack.append({"kind":"box-end","playerIndex":owner,"sourceIndex":src,"mode":mode})
static func combat_bonus(gs, owner: int, src: int) -> int:
	var u:Dictionary=gs.player(owner).units[src]
	if not active(u) or not u.get("boxSummon",false):return 0
	# 运势X always succeeds, but is still an actual die roll and fortune event.
	gs.VerifiedRules.Light.roll(gs,owner,1,6,src)
	var amount:int=int(gs.kw_usage(owner,"fortune").last.roll)*gs.VerifiedRules.Fortune.last_repeats(gs,owner)
	gs.VerifiedRules.event(gs,"box-combat-fortune",{"player":owner,"uid":u.uid,"amount":amount})
	return amount
static func remove_summon(gs, owner: int, u: Dictionary, reason: String="离开战斗区") -> void:
	if not u.get("boxSummon",false) or u.get("removed",false):return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,u.uid),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,u.uid),reason,false)
	u.hp=0;u.front=0;u.knockout=0;u.removed=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units:remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if int(u.front)==0:remove_summon(gs,owner,u)
static func summoned_knockout(_gs, _owner: int, u: Dictionary) -> void:
	if u.get("boxSummon",false):u.hp=0;u.front=0;u.knockout=0;u.removed=true
static func summon(gs, owner: int, src: int) -> int:
	gs.VerifiedRules.Weaver.leave_front(gs,owner)
	var p:Dictionary=gs.player(owner)
	var u:Dictionary={"uid":"%s:box-%d"%[p.id,gs.next_card_id],"id":"xiazhongshaonv-xiwu","name":"惜物","title":"匣中少女召唤物","art":Content.unit_def("xiazhongshaonv").art,"color":"#af97cf","baseAttack":0,"baseMaxHp":4,"attack":0,"maxHp":4,"hp":4,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"攻击或被攻击时，运势X：本次战斗获得X力量。离开战斗区移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"boxSummon":true,"summonerUid":p.units[src].uid}
	gs.next_card_id+=1;p.units.append(u);var idx:int=p.units.size()-1
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":u.summonerUid,"summonKind":"xiwu"})
	gs._fire_hooks(owner,idx,"unit-entered-front",{});gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
	return idx
static func add_card(gs, owner: int, id: String) -> void:
	var iid:="box-pack-%d"%gs.next_card_id;gs.next_card_id+=1
	var kept:bool=gs.player(owner).hand.size()<int(gs.rules.maxHandSize)
	if kept:gs.player(owner).hand.append({"instanceId":iid,"definitionId":id})
	gs.VerifiedRules.event(gs,"box-pack-card",{"player":owner,"card":Content.card_def(id),"instanceId":iid,"kept":kept})
static func open_pack(gs, owner: int, target_id, all_cards: bool) -> void:
	var idx:int=gs._unit_index_by_uid(owner,target_id)
	if idx<0 or gs.player(owner).units[idx].get("summoned",false):return
	var unit:Dictionary=gs.player(owner).units[idx]
	var pool:Array=Content.cards_for_unit(str(unit.id)).filter(func(c):return not c.get("token",false) and int(c.get("deckLimit",2))>0)
	if pool.is_empty():return
	var ids:Array=[];var cards:Dictionary={}
	for n in 5:
		var id:=str(pool[int(gs.next_random()%pool.size())].id);var key:="box-pack-slot-%d"%n
		ids.append(key);cards[key]=id
	gs.VerifiedRules.event(gs,"box-pack-opened",{"player":owner,"uid":unit.uid,"cards":cards.values(),"all":all_cards})
	if all_cards:
		for key in ids:add_card(gs,owner,str(cards[key]))
	else:
		gs.pending_choice={"type":"box-pack","playerIndex":owner,"instanceIds":ids,"cards":cards,"heading":"溢 彩 · 开 包","title":"选择一张牌置入手牌","hint":"%s的五张卡牌 · 选择一张置入手牌"%unit.name};gs.phase="choice"
static func choice_card(gs, owner: int, iid: String):
	var c:Dictionary=gs.pending_choice
	if c.get("type")!="box-pack" or int(c.playerIndex)!=owner or iid not in c.instanceIds:return null
	var card:Dictionary=Content.card_def(str(c.cards[iid])).duplicate(true);card.choiceSlot=iid;return card
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c:Dictionary=gs.pending_choice
	if c.get("type")!="box-pack" or int(c.playerIndex)!=owner or iid not in c.instanceIds:return false
	gs.pending_choice={};gs.phase="main";add_card(gs,owner,str(c.cards[iid]))
	gs._record("resolve_divination_choice",{"choice":"box-pack","instanceId":iid,"card":c.cards[iid]},owner)
	gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="box-pack" or int(gs.pending_choice.playerIndex)!=owner:return null
	var best:="";var score:=-999
	for iid in gs.pending_choice.instanceIds:
		var c:Dictionary=Content.card_def(str(gs.pending_choice.cards[iid]));var src:int=gs._source_index(owner,c)
		var v:=int(c.level)*3+(20 if src>=0 and int(c.level)<=int(gs.player(owner).units[src].level) else 0)
		if v>score:score=v;best=str(iid)
	return resolve_choice(gs,owner,best)
static func pay_card(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("boxMaidenRules",false) or int(card.get("movementBurst",0))!=10:return
	card.boxBurstPaid=gs.VerifiedRules.Yujiazhu.pay_burst(gs,owner,src,10)
	if card.boxBurstPaid:gs.VerifiedRules.Whale.burst(gs,owner,src,10)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not str(effect.get("action","")).begins_with("box-"):return false
	var u:Dictionary=gs.player(owner).units[src];var burst:bool=card.get("boxBurstPaid",false)
	match str(effect.action):
		"box-light":
			for victim in 2:
				var idx:int=gs._unit_index_by_uid(victim,target_id)
				if idx>=0:gs._damage_unit(victim,idx,(10 if burst else 3)+int(u.get("spellPower",0)),owner,src)
		"box-form":gs._apply_form(owner,src,card,card.value)
		"box-summon":summon(gs,owner,src)
		"box-awaken":Charge.gain_charge(gs,owner,src,10);gs._awaken(owner,src,card,effect.value)
		"box-revive":
			for target in gs.player(owner).units.duplicate():
				if gs.VerifiedRules.OwlInsect.shikigami(target) and not target.get("removed",false):gs.VerifiedRules.Peach.revive(gs,owner,src,target,false,false)
			if burst:gs._heal_avatar(owner,10)
		"box-pack":open_pack(gs,owner,target_id,burst)
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	if f.get("kind") not in ["box-divination","box-end"]:return false
	var owner:=int(f.playerIndex);var src:=int(f.sourceIndex)
	if f.kind=="box-divination":gs.VerifiedRules.Divination.start(gs,owner,3)
	else:
		var u:Dictionary=gs.player(owner).units[src]
		if not active(u) or not Charge.pay_charge(gs,owner,src,10):return true
		if f.mode=="draw":gs._draw(owner,1)
		else:
			var prior:Dictionary=gs._card_effect_context;gs._card_effect_context={}
			gs.VerifiedRules.ThreeTail.projectile(gs,owner,src,10,"璀璨之匣");gs._card_effect_context=prior
	return true
static func marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx];var out:Array=[]
	if source(u):out.append("投骰充能 · "+("每次" if u.awakened else "本回合已触发" if int(u.get("boxDieTurn",-1))==gs.turn_counter else "本回合可触发"))
	if u.get("boxSummon",false):out.append("惜物 · 攻击或被攻击投骰 · 本战斗+点数力量")
	return out
static func score_card(gs, owner: int, card: Dictionary, target):
	if not card.get("boxMaidenRules",false):return null
	if card.id=="c24301":return -100 if gs._unit_index_by_uid(owner,target)>=0 else 50
	if card.id=="c24306":return 25+15*gs.player(owner).units.filter(func(u):return int(u.hp)<=0 and not u.get("removed",false)).size()
	return 35
