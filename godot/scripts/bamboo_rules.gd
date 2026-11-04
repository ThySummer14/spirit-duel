class_name BambooRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp)>0 and int(unit.level)>0 and not unit.get("baseRulesSuppressed",false)

static func cards() -> Array:
	return Content.unit_def("huiyeji").get("bambooRealmCards",[])

static func field(gs, owner: int) -> Dictionary:
	for realm in gs.player(owner).realms:
		if int(realm.hp)>0 and realm.get("nativeRealm")=="bamboo": return realm
	return {}

static func source_index(gs, owner: int) -> int:
	return gs._source_index(owner,{"unitId":"huiyeji"})

static func deploy(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("bambooRealm",false) or card.get("bambooRaw",false): return false
	var src := source_index(gs,owner)
	if src<0: return false
	var unit: Dictionary = gs.player(owner).units[src]
	var realm := field(gs,owner)
	var amount := int(card.realm.hp)
	var history: Array = gs.player(owner).get("bambooHistory",[])
	if str(card.id) not in history: history.append(str(card.id))
	gs.player(owner).bambooHistory = history
	if realm.is_empty():
		var raw := card.duplicate(true); raw.bambooRaw=true
		gs._deploy_realm(owner,raw)
		realm = gs.player(owner).realms.back()
		realm.bambooAbilities=[str(card.id)]
	else:
		realm.hp = int(realm.hp)+amount
		realm.bambooAbilities = realm.get("bambooAbilities",[])+[str(card.id)] if unit.awakened else [str(card.id)]
		realm.cardId=card.id
		realm.cardInstance=card.get("playedInstance",{}).duplicate(true)
		gs.VerifiedRules.event(gs,"bamboo-merged",{"player":owner,"realm":realm.uid,"amount":amount,"abilities":realm.bambooAbilities.duplicate()})
	realm.name = "竹取·"+"/".join(realm.bambooAbilities.map(func(id):return str(Content.card_def(str(id)).name)))
	gs.VerifiedRules.Night.refresh(gs)
	return true

static func options(gs, owner: int) -> Array:
	return gs.player(owner).deck.filter(func(i):return str(i.definitionId) in cards()).map(func(i):return str(i.instanceId))

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("bambooRules",false): return card
	var out := card.duplicate(true)
	if card.get("bambooRealm",false): out.realm.hp = int(card.realm.hp)+int(inst.get("bambooDurabilityBonus",0))
	if card.effect=="bamboo-search":
		var names: Array = []
		for entry in gs.player(owner).deck:
			if str(entry.definitionId) in cards() and str(entry.definitionId) not in names: names.append(str(entry.definitionId))
		if names.size()==cards().size(): out.keywords.append("instant"); out.enhanced=true
	if card.effect=="bamboo-awaken": out.enhanced=gs.player(owner).get("bambooHistory",[]).size()>=cards().size()
	return out

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("effect")!="bamboo-search" or not options(gs,owner).is_empty()

static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type")!="bamboo-deck": return null
	for inst in gs.player(owner).deck:
		if str(inst.instanceId)==iid: return describe_card(gs,owner,inst,Content.card_def(str(inst.definitionId)))
	return {}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	if gs.pending_choice.get("type")!="bamboo-deck" or int(gs.pending_choice.playerIndex)!=owner or iid not in gs.pending_choice.instanceIds: return false
	var idx: int = gs.player(owner).deck.find_custom(func(i):return str(i.instanceId)==iid)
	if idx<0: return false
	var inst: Dictionary = gs.player(owner).deck.pop_at(idx)
	gs.pending_choice={}; gs.phase="main"
	gs.VerifiedRules.BondDream.fetched(gs,inst)
	inst.bambooDurabilityBonus=int(inst.get("bambooDurabilityBonus",0))+5
	if gs.player(owner).hand.size()<int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
	else: gs._log("手牌已满，五道难题取得的幻境被烧毁。",gs.TONE_DANGER)
	gs._record("resolve_divination_choice",{"choice":"bamboo-deck","instanceId":iid,"card":inst.definitionId},owner)
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="bamboo-deck": return null
	var best := str(gs.pending_choice.instanceIds[0]); var score := -999
	for iid in gs.pending_choice.instanceIds:
		var card: Dictionary = choice_card(gs,owner,str(iid))
		var value := int(card.get("level",1))
		if card.get("bambooAbility")=="stone" and gs.front_index(owner)<0: value+=5
		if value>score: best=str(iid); score=value
	return resolve_choice(gs,owner,best)

static func summon_stone(gs, owner: int, power: int) -> void:
	if gs.front_index(owner)>=0: return
	var cfg: Dictionary = Content.unit_def("huiyeji").get("bambooStone",{})
	var hp := int(cfg.get("hp",5))
	var stone := {"uid":"%s:stone-%d" % [gs.player(owner).id,gs.next_card_id],"id":"bamboo-stone","name":"石钵","title":"佛前石钵召唤物","art":Content.unit_def("huiyeji").art,"color":"#adc9b3","baseAttack":power,"baseMaxHp":hp,"attack":power,"maxHp":hp,"hp":hp,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"离开战斗区时移除。","charge":0,"passive_hooks":[],"summoned":true,"countsAsShikigami":true,"bambooStone":true,"swift":false}
	gs.next_card_id+=1; gs.player(owner).units.append(stone)
	gs.VerifiedRules.Enma.remove_departed(gs)
	gs.VerifiedRules.Weaver.remove_departed(gs)
	gs.VerifiedRules.Vine.remove_departed(gs)
	gs.VerifiedRules.WindRaccoon.remove_departed(gs)
	gs.VerifiedRules.House.remove_departed(gs)
	gs.VerifiedRules.Doll.remove_departed(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"bamboo-stone-summoned",{"player":owner,"uid":stone.uid,"power":power})
	var idx: int=gs.player(owner).units.size()-1
	gs._fire_hooks(owner,idx,"unit-entered-front",{})
	gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",stone.uid,{"kind":"response-complete"})

static func remove_departed(gs) -> void:
	for p in gs.players:
		for unit in p.units.duplicate():
			if unit.get("bambooStone",false) and (int(unit.hp)<=0 or int(unit.front)==0):
				var owner: int=gs.players.find(p)
				gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(unit.uid)),"石钵离场",false)
				gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(unit.uid)),"石钵离场")
				unit.hp=0; unit.front=0; unit.knockout=0; unit.removed=true

static func cover(gs, owner: int, idx: int, amount: int) -> bool:
	var unit: Dictionary = gs.player(owner).units[idx]
	var realm := field(gs,owner)
	if amount<=0 or not active(unit) or not unit.get("formRules",{}).get("bambooCover",false) or int(realm.get("hp",0))<20: return false
	gs.VerifiedRules.Night.lose(gs,owner,realm,mini(5,amount))
	gs.VerifiedRules.event(gs,"bamboo-damage-replaced",{"player":owner,"uid":unit.uid,"amount":amount})
	return true

static func retaliation(gs, owner: int, idx: int) -> Array:
	var realm := field(gs,owner)
	if realm.is_empty() or (idx>=0 and int(realm.hp)<10): return []
	var frames: Array = []
	for id in realm.get("bambooAbilities",[]):
		if Content.card_def(str(id)).get("bambooAbility")=="rat": frames.append({"kind":"bamboo-rat","playerIndex":owner,"sourceIndex":source_index(gs,owner),"amount":2 if idx<0 else 1})
	return frames

static func combat_dealt(gs, attacker: int, src: int, owner: int, result: Dictionary, reactions: Array) -> void:
	if attacker==owner or int(result.get("dealt",result.get("damage",0)))<=0: return
	for frame in reactions:
		frame.targetOwner=attacker; frame.targetUid=gs.player(attacker).units[src].uid
		if gs._shell_in_exchange: gs._shell_reactions.append(frame)
		else: resolve_frame(gs,frame)

static func turn_start(gs) -> void:
	var frames: Array = []
	for owner in [gs.current_player,1-gs.current_player]:
		var realm := field(gs,owner)
		for id in realm.get("bambooAbilities",[]):
			if Content.card_def(str(id)).get("bambooAbility")=="branch": frames.append({"kind":"bamboo-branch","playerIndex":owner,"remaining":2 if int(realm.hp)>=10 else 1})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func end_turn(gs, current: int) -> void:
	var frames: Array = []
	for owner in [current,1-current]:
		var realm := field(gs,owner)
		for id in realm.get("bambooAbilities",[]):
			var mode := str(Content.card_def(str(id)).get("bambooAbility",""))
			if mode=="shell" and (owner==current or int(realm.hp)>=10): frames.append({"kind":"bamboo-shell","playerIndex":owner,"realmUid":realm.uid})
			if mode=="stone" and owner==current: frames.append({"kind":"bamboo-stone","playerIndex":owner,"boost":int(realm.hp)>=10})
			if mode=="dragon": frames.append({"kind":"bamboo-dragon","playerIndex":owner,"boost":int(realm.hp)>=10})
		for src in gs.player(owner).units.size():
			var unit: Dictionary = gs.player(owner).units[src]
			if active(unit) and unit.get("formRules",{}).get("bambooRandomEnd",false): frames.append({"kind":"bamboo-random","playerIndex":owner})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if not kind.begins_with("bamboo-"): return false
	var owner := int(frame.playerIndex)
	var src := source_index(gs,owner)
	var context: Dictionary = gs._card_effect_context; gs._card_effect_context={}
	match kind:
		"bamboo-remove": remove_departed(gs)
		"bamboo-rat":
			var idx: int = gs._unit_index_by_uid(int(frame.targetOwner),str(frame.targetUid))
			if idx>=0: gs._damage_unit(int(frame.targetOwner),idx,int(frame.amount),owner,src)
		"bamboo-branch":
			if int(frame.remaining)>1: gs.resolution_stack.append({"kind":kind,"playerIndex":owner,"remaining":int(frame.remaining)-1})
			gs.resolution_stack.append({"kind":"bamboo-fire","playerIndex":owner})
			gs._draw(owner,1)
		"bamboo-fire": gs.VerifiedRules.Light.gain_fire(gs,owner,1)
		"bamboo-shell":
			gs._heal_avatar(owner,1)
			for unit in gs.player(owner).units:
				if int(unit.hp)>0: gs._heal_unit(unit,1)
			for realm in gs.player(owner).realms.duplicate():
				if str(realm.uid)!=str(frame.realmUid): gs.VerifiedRules.Huang.gain(gs,owner,realm,1)
		"bamboo-stone": summon_stone(gs,owner,4 if frame.boost else 0)
		"bamboo-dragon":
			var idx: int = gs.front_index(1-owner)
			if idx<0: gs._damage_avatar(1-owner,2,owner,src)
			else: gs._damage_unit(1-owner,idx,2,owner,src)
			if frame.boost:
				var pool: Array = gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.front)==0).map(func(u):return str(u.uid))
				for uid in pool: gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,uid),1,owner,src)
		"bamboo-random":
			var id := str(cards()[int(floor(gs.randf01()*cards().size()))])
			gs._deploy_realm(owner,Content.card_def(id))
		_: gs._card_effect_context=context; return false
	gs._card_effect_context=context
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	match str(effect.get("action","")):
		"bamboo-search":
			var ids := options(gs,owner)
			if not ids.is_empty(): gs.pending_choice={"type":"bamboo-deck","playerIndex":owner,"zone":"deck","instanceIds":ids,"heading":"五 道 难 题","title":"选择辉夜姬幻境，置入手牌并获得5耐久","hint":"选择牌库中的一张原牌置入手牌，并使其耐久增加5。"}; gs.phase="choice"
		"bamboo-awaken":
			gs._awaken(owner,src,card,effect.value)
			if card.get("enhanced",false):
				for id in cards():
					var realm_card: Dictionary = Content.card_def(str(id)).duplicate(true); realm_card.realm.hp=1
					gs._deploy_realm(owner,realm_card)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("bambooRules",false): return null
	if card.get("effect")=="bamboo-search": return 65 if not options(gs,owner).is_empty() else -100
	return 70 if card.get("enhanced",false) else 50
