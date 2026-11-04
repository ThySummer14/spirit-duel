class_name SeaButterflyRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const SPIRIT_TEXT := "海灵 · 不能叠加 · 被敌方式神攻击时随机眩晕、2破甲或本次战斗-2力量，触发后移除"

static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("seaButterflyRules",false)
static func marked(u: Dictionary) -> bool:
	return not u.get("seaSpirit",{}).is_empty()
static func heart(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r):return int(r.hp)>0 and r.get("nativeRealm")=="sea-heart")
static func entered(gs, owner: int, idx: int) -> void:
	var u: Dictionary=gs.player(owner).units[idx]
	if int(u.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(u):return
	for i in gs.player(owner).units.size():
		var caster: Dictionary=gs.player(owner).units[i]
		if source(caster) and active(caster) and (caster.awakened or i==idx):attach(gs,owner,i,u)
static func attach(gs, owner: int, src: int, target: Dictionary) -> void:
	if target.is_empty() or int(target.hp)<=0 or target.get("removed",false):return
	var repeated:=marked(target)
	target.seaSpirit={"sourceOwner":owner,"sourceUid":gs.player(owner).units[src].uid}
	gs.VerifiedRules.event(gs,"sea-spirit-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":target.uid,"repeated":repeated})
	if not repeated:return
	for i in gs.player(owner).units.size():
		var caster: Dictionary=gs.player(owner).units[i]
		if not source(caster) or not active(caster) or not caster.awakened:continue
		var context: Dictionary=gs._card_effect_context;gs._card_effect_context={}
		var fi: int=gs.front_index(1-owner)
		var dealt: int=gs.VerifiedRules.base_damage_avatar(gs,owner,i,1-owner,2) if fi<0 else int(gs.VerifiedRules.base_damage_unit(gs,owner,i,1-owner,fi,2).get("damage",0))
		gs._card_effect_context=context
		gs.VerifiedRules.event(gs,"sea-repeat-projectile",{"player":owner,"uid":caster.uid,"target":"" if fi<0 else gs.player(1-owner).units[fi].uid,"victimPlayer":1-owner,"amount":dealt})

static func trigger(gs, owner: int, idx: int, enemy: int, other: int, frame: Dictionary, attacking: bool) -> void:
	var host: Dictionary=gs.player(owner).units[idx]
	var opponent: Dictionary=gs.player(enemy).units[other]
	if not marked(host) or int(host.hp)<=0 or int(opponent.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(opponent):return
	var persistent:=heart(gs,owner)
	var count:=3 if persistent else 2 if host.get("formRules",{}).get("seaDouble",false) else 1
	var pool: Array=["stun","armor-break","power"]
	var chosen: Array=[]
	for n in count:
		var pick:=0 if persistent else int(gs.next_random()%pool.size())
		chosen.append(pool.pop_at(pick))
	# One activation counts once even when it resolves two or three effects.
	gs.player(owner).seaSpiritTriggers=int(gs.player(owner).get("seaSpiritTriggers",0))+1
	if not persistent:host.erase("seaSpirit")
	for item in chosen:
		match item:
			"stun":gs.VerifiedRules.Stun.apply(gs,enemy,other,1,owner)
			"armor-break":gs.VerifiedRules.ArmorBreak.give(gs,owner,idx,enemy,other,2,false)
			"power":
				var key: String="seaDefenderPenalty" if attacking else "seaAttackPenalty"
				frame.options[key]=int(frame.options.get(key,0))+2
	gs.VerifiedRules.event(gs,"sea-spirit-triggered",{"player":owner,"uid":host.uid,"target":opponent.uid,"effects":chosen,"persistent":persistent,"count":int(gs.player(owner).seaSpiritTriggers)})
static func before_responses(gs, frame: Dictionary) -> void:
	if frame.get("seaSpiritChecked",false):return
	frame.seaSpiritChecked=true
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var enemy:=int(frame.options.get("combatVictim",1-owner));var idx:=int(frame.defenderIndex)
	var attacker: Dictionary=gs.player(owner).units[src]
	if attacker.get("formRules",{}).get("seaAttackTrigger",false):trigger(gs,owner,src,enemy,idx,frame,true)
	if enemy!=owner:trigger(gs,enemy,idx,owner,src,frame,false)

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("seaButterflyRules",false) or card.get("target","auto")=="auto":return null
	var ids: Array=[]
	for side in ([1-owner] if card.id=="c28701" else [owner,1-owner] if card.id=="c28707" else [owner]):
		for u in gs.player(side).units:
			if u.get("removed",false) or not gs.VerifiedRules.OwlInsect.shikigami(u):continue
			if int(u.hp)<=0 and not (card.id=="c28705" and not u.get("summoned",false) and gs.VerifiedRules.Rebirth.can_revive(u)):continue
			if side!=owner and gs.VerifiedRules.Combat.has(u,"veil"):continue
			ids.append(u.uid)
	return ids
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("effect")!="sea-awaken" or not gs.player(owner).units[gs._source_index(owner,card)].awakened
static func describe_card(gs, owner: int, _inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("seaButterflyRules",false):return card
	var view:=card.duplicate(true)
	if card.id=="c28707":
		var count:=int(gs.player(owner).get("seaSpiritTriggers",0));var src: int=gs._source_index(owner,card)
		view.value=3+count
		view.currentCardStats="海灵已触发%d次 · 伤害%d / 恢复%d"%[count,3+count+(int(gs.player(owner).units[src].get("spellPower",0)) if src>=0 else 0),3+count]
		view.enhanced=count>0
	return view
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action","")):
		"sea-enter":gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
		"sea-enrage":
			if not target.is_empty():gs.VerifiedRules.MonkCleaner.enrage(gs,1-owner,gs._unit_index_by_uid(1-owner,target.uid))
		"sea-attach":attach(gs,owner,src,target)
		"sea-divination":gs.VerifiedRules.Divination.start(gs,owner,int(effect.value))
		"sea-awaken":gs._awaken(owner,src,card,effect.value)
		"sea-move":gs.VerifiedRules.move_unit(gs,owner,target)
		"sea-revive":gs.VerifiedRules.Peach.revive(gs,owner,src,target,false,false)
		"sea-coral":
			var amount:=3+int(gs.player(owner).get("seaSpiritTriggers",0))
			var side: int=owner if gs._unit_index_by_uid(owner,target.uid)>=0 else 1-owner
			gs._damage_unit(side,gs._unit_index_by_uid(side,target.uid),amount+int(gs.player(owner).units[src].get("spellPower",0)),owner,src)
			gs._heal_avatar(owner,amount)
		"sea-realm":gs._deploy_realm(owner,card)
		"sea-attack":
			if not target.is_empty() and int(target.hp)>0:
				gs._resolve_combat(owner,gs._unit_index_by_uid(owner,target.uid),0,false,false,false,false,null,false,{"immuneCombat":true})
		_:return false
	return true
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx];var marks: Array=[]
	if marked(u):marks.append("海灵 · 三项同时触发且保留" if heart(gs,owner) else "海灵 · 随机两项不同效果 · 触发后移除" if u.get("formRules",{}).get("seaDouble",false) else SPIRIT_TEXT)
	if source(u):marks.append("本局海灵触发%d次 · 月珊瑚%d点"%[int(gs.player(owner).get("seaSpiritTriggers",0)),3+int(gs.player(owner).get("seaSpiritTriggers",0))])
	return marks
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("seaButterflyRules",false):return null
	var target: Dictionary=gs._unit_by_uid(gs._all_units(),target_id)
	if card.id=="c28705":return 25+int(target.get("level",0))*3 if int(target.get("hp",1))<=0 else 9
	if card.id=="c28707":return 2 if gs._unit_index_by_uid(owner,target_id)>=0 else 16+int(card.value)+(8 if int(target.get("hp",99))<=int(card.value) else 0)
	if card.id=="c28708":return 30+int(target.get("attack",0))
	if card.id=="c28702":return 14+(5 if int(target.get("front",0))==1 else 0)
	return 19
