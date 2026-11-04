class_name BaizeRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const DAZHI := "baize-dazhi"

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("baizeRules",false)
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func present(gs) -> bool:
	for p in gs.players:
		for u in p.units:
			if source(u): return true
	return false
static func new_dazhi(gs, owner: int) -> Dictionary:
	var inst := {"instanceId":"%s-dazhi-%d"%[gs.player(owner).id,gs.next_card_id],"definitionId":DAZHI}
	gs.next_card_id+=1
	return inst
static func turn_start(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not source(u) or not active(u): return
	var inst:=new_dazhi(gs,owner)
	# Official erratum: 置入, not reshuffling the existing deck.
	var deck: Array=gs.player(owner).deck
	deck.insert(int(floor(gs.randf01()*(deck.size()+1))),inst)
	gs.VerifiedRules.event(gs,"baize-dazhi-inserted",{"player":owner,"uid":u.uid,"instanceId":inst.instanceId})
static func before_basic(gs, owner: int, src: int) -> void:
	turn_start(gs,owner,src)
static func prepare_divination(gs, owner: int, count: int, controller: int) -> int:
	if owner!=controller: return count
	for u in gs.player(controller).units:
		if not active(u) or not u.get("formRules",{}).get("baizeHistory",false): continue
		var pool: Array=gs.player(owner).deck.filter(func(i): return Content.card_def(str(i.definitionId)).get("unitId")=="baize")
		if pool.is_empty(): continue
		var chosen: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
		gs.player(owner).deck.erase(chosen); gs.player(owner).deck.append(chosen)
		count+=1
		gs.VerifiedRules.event(gs,"baize-history-top",{"player":owner,"uid":u.uid,"instanceId":chosen.instanceId})
	return count
static func revealed(gs, owner: int, ids: Array, controller: int) -> void:
	var enabled: bool=gs.player(controller).units.any(func(u): return active(u) and u.get("formRules",{}).get("baizeCause",false))
	if not enabled: return
	for iid in ids:
		var inst: Dictionary=gs.VerifiedRules.Divination.instance(gs,owner,str(iid))
		var unit_id: String=Content.card_def(str(inst.definitionId)).get("unitId","")
		for u in gs.player(owner).units:
			if u.id!=unit_id or int(u.hp)<=0 or u.get("removed",false): continue
			gs._grow_unit(u,1,1)
			u.baizeTemporary=int(u.get("baizeTemporary",0))+1
			gs.VerifiedRules.event(gs,"baize-cause-growth",{"player":owner,"controller":controller,"uid":u.uid,"instanceId":iid,"amount":1})
static func clear_temporary(u: Dictionary) -> void:
	var n:=int(u.get("baizeTemporary",0))
	u.attackBonus=int(u.attackBonus)-n; u.maxHpBonus=int(u.maxHpBonus)-n
	u.erase("baizeTemporary")
static func end_turn(gs) -> void:
	for p in gs.players:
		for u in p.units:
			if int(u.get("baizeTemporary",0))==0: continue
			clear_temporary(u); gs._recalc(u)
static func completed(gs, choice: Dictionary) -> void:
	var owner:=int(choice.get("zoneOwner",choice.playerIndex)); var controller:=int(choice.playerIndex)
	var bottom: Array=[]
	for iid in choice.bottom:
		var inst: Dictionary=gs.VerifiedRules.Divination.instance(gs,owner,str(iid))
		if not inst.is_empty(): bottom.append(inst.duplicate(true))
	var own_cards:=0; var dazhi:=false
	for inst in bottom:
		var card:=Content.card_def(str(inst.definitionId))
		if card.get("unitId")=="baize": own_cards+=1
		if str(inst.definitionId)==DAZHI: dazhi=true
	# Stack is LIFO: awakening's one draw precedes the card-bottom effects and Eye.
	for n in range(bottom.size()-1,-1,-1):
		if Content.card_def(str(bottom[n].definitionId)).get("baizeRules",false):
			gs.resolution_stack.append({"kind":"baize-bottom","playerIndex":owner,"instance":bottom[n]})
	if int(choice.get("baizeHealPerCard",0))>0 and own_cards>0:
		gs.resolution_stack.append({"kind":"baize-heal","playerIndex":controller,"amount":own_cards*int(choice.baizeHealPerCard)})
	if owner==controller and dazhi and gs.player(owner).get("baizeAwakened",false):
		gs.resolution_stack.append({"kind":"baize-draw","awakened":true,"playerIndex":owner})
static func revive_pool(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp)<=0 and not u.get("summoned",false) and not u.get("removed",false) and gs.VerifiedRules.Rebirth.can_revive(u))
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("baizeRules",false): return null
	if card.id=="c27302": return revive_pool(gs,owner).map(func(u): return u.uid)
	if card.id!="c27305": return null
	return gs.player(1-owner).units.filter(func(u): return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil") and not gs.VerifiedRules.Movement.has_veil(u)).map(func(u): return u.uid)
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.id!="c27306": return true
	var src: int=gs._source_index(owner,card)
	return src>=0 and not gs.player(owner).units[src].awakened
static func put_hand(gs, owner: int, inst: Dictionary) -> void:
	var burned: bool=gs.player(owner).hand.size()>=int(gs.rules.maxHandSize)
	if not burned: gs.player(owner).hand.append(inst)
	gs.VerifiedRules.Glutton.mark_hand(gs,owner)
	gs.VerifiedRules.event(gs,"baize-card-to-hand",{"player":owner,"instanceId":inst.instanceId,"card":inst.definitionId,"burned":burned})
static func take_deck_instance(gs, owner: int, iid: String) -> Dictionary:
	var deck: Array=gs.player(owner).deck
	for i in deck.size():
		if str(deck[i].instanceId)==iid: return deck.pop_at(i)
	return {}
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""))
	if not kind.begins_with("baize-"): return false
	var owner:=int(frame.playerIndex)
	match kind:
		"baize-draw":
			gs._draw(owner,1)
			if frame.get("awakened",false): gs.VerifiedRules.event(gs,"baize-awake-draw",{"player":owner,"amount":1})
		"baize-heal": gs._heal_avatar(owner,int(frame.amount))
		"baize-bottom":
			var inst: Dictionary=frame.instance; var card:=Content.card_def(str(inst.definitionId))
			var src: int=gs._source_index(owner,card)
			if src<0: return true
			gs.VerifiedRules.event(gs,"baize-bottom-trigger",{"player":owner,"card":card.id,"instanceId":inst.instanceId})
			match str(card.id):
				"c27302":
					var pool:=revive_pool(gs,owner)
					if not pool.is_empty(): gs.VerifiedRules.Peach.revive(gs,owner,src,pool[int(floor(gs.randf01()*pool.size()))],false,false)
				"c27303":
					var actual:=take_deck_instance(gs,owner,str(inst.instanceId))
					if not actual.is_empty(): put_hand(gs,owner,actual)
				"c27304":
					var u: Dictionary=gs.player(owner).units[src]
					if not active(u) or int(u.level)<int(card.level) or gs.VerifiedRules.Stun.blocks(gs,owner,u): return true
					if take_deck_instance(gs,owner,str(inst.instanceId)).is_empty(): return true
					var automatic:=card.duplicate(true); automatic.sourceZone="deck"
					gs.player(owner).cardsPlayedThisTurn+=1
					gs._push_card_frames(owner,str(card.id),null,automatic,src,0,true)
				"c27305":
					var pool: Array=gs.player(1-owner).units.filter(func(u): return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u))
					if not pool.is_empty():
						var chosen: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
						gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,chosen.uid),2,owner,src)
				"c27307": put_hand(gs,owner,new_dazhi(gs,owner))
		_: return false
	return true
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, _target_id) -> bool:
	match str(effect.get("action","")):
		"baize-divination": gs.VerifiedRules.Divination.start(gs,owner,int(effect.value),owner,card.get("baizeDivination",{}))
		"baize-dazhi":
			# Draw resumes only after every top/bottom decision and its triggers.
			gs.resolution_stack.append({"kind":"baize-draw","playerIndex":owner})
			gs.VerifiedRules.Divination.start(gs,owner,2,owner,{"minimumBottom":1})
		"baize-revive": gs.VerifiedRules.Peach.revive(gs,owner,src,target,false,false)
		"baize-awaken":
			gs._awaken(owner,src,card,{"attack":1,"hp":1}); gs.player(owner).baizeAwakened=true
		"baize-projectile":
			var idx: int=gs.front_index(1-owner); var amount:=int(gs.player(owner).units[src].attack)
			if idx<0: gs._damage_avatar(1-owner,amount,owner,src)
			else:
				var result: Dictionary=gs._damage_unit(1-owner,idx,amount,owner,src)
				if int(result.get("damage",0))>0 and int(gs.player(1-owner).units[idx].hp)>0: gs.VerifiedRules.Stun.apply(gs,1-owner,idx,1,owner)
		_: return false
	return true
static func prefer_bottom(gs, owner: int, card: Dictionary) -> bool:
	match str(card.id):
		"c27302": return not revive_pool(gs,owner).is_empty()
		"c27303","c27304","c27305","c27307": return true
		DAZHI: return gs.player(owner).get("baizeAwakened",false)
	return false
static func unit_marks(gs, owner: int, src: int) -> Array:
	var u: Dictionary=gs.player(owner).units[src]; var result: Array=[]
	if source(u):
		result.append("回合开始 / 出击 · 随机置入达知")
		if gs.player(owner).get("baizeAwakened",false): result.append("本局觉醒 · 每次占卜置底达知抽一张，气绝有效")
	if int(u.get("baizeTemporary",0))>0: result.append("承因续果 · 本回合 +%d/+%d"%[int(u.baizeTemporary),int(u.baizeTemporary)])
	return result
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("baizeRules",false): return null
	if card.id=="c27302": return 90+int(gs._unit_by_uid(gs.player(owner).units,target_id).get("maxHp",0))
	if card.id=="c27307": return 70+mini(20,int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp))
	if card.type=="form": return -50 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 65
	return 80 if card.id=="c27306" else 60
