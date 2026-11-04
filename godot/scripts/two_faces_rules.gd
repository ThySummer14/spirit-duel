class_name TwoFacesRules
extends RefCounted
const Content:=preload("res://scripts/content_loader.gd")
static func source(u: Dictionary) -> bool:return Content.runtime_unit_def(u).get("twoFacesRules",false)
static func active(u: Dictionary) -> bool:return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func link_candidates(gs, owner: int, card: Dictionary) -> Array:
	if not card.get("twoFacesRules",false):return []
	var src:int=gs._source_index(owner,card)
	if src<0 or not active(gs.player(owner).units[src]):return []
	var affinity:=str(card.get("twoFacesAffinity",""))
	if affinity=="" and card.id!="c23803":return []
	return gs.player(owner).deck.filter(func(i):
		var c:Dictionary=Content.card_def(str(i.definitionId))
		return c.get("unitId")==card.unitId and int(c.level)<=int(gs.player(owner).units[src].level) and (card.id=="c23803" or (str(c.get("twoFacesAffinity",""))!="" and c.twoFacesAffinity!=affinity)))
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("twoFacesRules",false):return card
	var c:=card.duplicate(true);var src:int=gs._source_index(owner,c)
	if src<0:return c
	var u:Dictionary=gs.player(owner).units[src]
	c.twoFacesEnhanced=c.get("linkedUse",false) or inst.get("linkedUse",false) or (active(u) and u.awakened)
	if c.twoFacesEnhanced:
		c.enhanced=true
		if c.id=="c23804":c.combatOption.pierce=true
		if c.id=="c23806" and "instant" not in c.keywords:c.keywords.append("instant")
	if c.type=="combat" and gs.VerifiedRules.Combat.has(u,"pursuit"):
		c.target="enemy-unit";c.combatOption=c.get("combatOption",{}).duplicate(true);c.combatOption.pursuit=true
	if not c.get("twoFacesFromDeck",false):c.currentCardStats=("雷牌" if c.get("twoFacesAffinity")=="thunder" else "风牌" if c.get("twoFacesAffinity")=="wind" else "两面佛")+" · "+("增强已生效" if c.twoFacesEnhanced else "未连引 · 基础效果")
	return c
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("id")!="c23803" or not gs.player(owner).units[gs._source_index(owner,card)].awakened
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("twoFacesRules",false):return null
	if card.type=="combat" and card.get("combatOption",{}).get("pursuit",false):
		var foes:Array=gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
		if gs.front_index(1-owner)<0:foes.append("avatar-%d"%(1-owner))
		return foes
	if card.id not in ["c23802","c23807"]:return null
	var out:Array=[]
	for side in ([owner,1-owner] if card.id=="c23802" else [1-owner]):
		for u in gs.player(side).units:
			if int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u) and (side==owner or not gs.VerifiedRules.Combat.has(u,"veil")):out.append(str(u.uid))
	if card.id=="c23807" and not gs.VerifiedRules.PipeFox.avatar_veil(gs,1-owner):out.append("avatar-%d"%(1-owner))
	return out
static func area(gs, owner: int, src: int, amount: int) -> void:
	var hits:Array=[-1]
	for i in gs.player(1-owner).units.size():
		if int(gs.player(1-owner).units[i].hp)>0:hits.append(i)
	for i in range(hits.size()-1,-1,-1):gs.resolution_stack.append({"kind":"two-faces-hit","playerIndex":owner,"sourceIndex":src,"idx":hits[i],"amount":amount,"context":gs._card_effect_context.duplicate(true)})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u:Dictionary=gs.player(owner).units[src];var enhanced:bool=card.get("twoFacesEnhanced",false)
	match str(effect.get("action","")):
		"two-faces-combat":
			var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
			gs.resolution_stack.append({"kind":"two-faces-combat-ready","playerIndex":owner,"sourceIndex":src,"card":card.duplicate(true),"targetId":target_id,"options":options})
			if card.id=="c23801" and enhanced:area(gs,owner,src,1)
		"two-faces-sound":
			for side in 2:
				var idx:int=gs._unit_index_by_uid(side,str(target_id))
				if idx>=0:
					if enhanced:gs.resolution_stack.append({"kind":"two-faces-move","playerIndex":owner,"sourceIndex":src,"victim":side,"idx":idx})
					gs._damage_unit(side,idx,3+int(u.get("spellPower",0)),owner,src)
		"two-faces-wind":
			var old_wind:=int(u.get("twoFacesWind",0))
			u.twoFacesWindAttack=int(u.get("twoFacesWindAttack",old_wind))+3;u.twoFacesWind=old_wind+3;u.attackBonus=int(u.attackBonus)+3
			gs._grant_unit_armor(u,3);gs._recalc(u)
			if enhanced:u.swift=true
		"two-faces-gale":
			if enhanced:area(gs,owner,src,2+int(u.get("spellPower",0)))
			if str(target_id)=="avatar-%d"%(1-owner):gs._damage_avatar(1-owner,4+int(u.get("spellPower",0)),owner,src)
			else:
				var idx:int=gs._unit_index_by_uid(1-owner,str(target_id))
				if idx>=0:gs._damage_unit(1-owner,idx,4+int(u.get("spellPower",0)),owner,src)
		_:return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind:=str(f.get("kind",""))
	if not kind.begins_with("two-faces-"):return false
	var owner:=int(f.playerIndex);var src:=int(f.sourceIndex)
	match kind:
		"two-faces-hit":
			var old:Dictionary=gs._card_effect_context;gs._card_effect_context=f.context
			if int(f.idx)<0:gs._damage_avatar(1-owner,int(f.amount),owner,src)
			else:gs._damage_unit(1-owner,int(f.idx),int(f.amount),owner,src)
			gs._card_effect_context=old
		"two-faces-move":
			var u:Dictionary=gs.player(int(f.victim)).units[int(f.idx)]
			if int(u.hp)>0:gs.VerifiedRules.Movement.move_to(gs,int(f.victim),int(f.idx),1-int(u.front))
		"two-faces-combat-ready":
			if int(gs.player(owner).units[src].hp)>0:
				gs._grant_unit_armor(gs.player(owner).units[src],int(f.options.get("shield",0)))
				gs._record("assault",{"unit":src,"target":f.targetId,"bonus":int(f.card.value)},owner)
				gs._resolve_combat(owner,src,int(f.card.value),false,false,f.card.id=="c23806",false,f.targetId,false,f.options)
		_:return false
	return true
static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if owner!=victim and idx<0 and int(result.get("dealt",0))>0 and options.get("combatCard",{}).get("id")=="c23804":gs._draw(owner,1)
static func expire(gs) -> void:
	for p in gs.players:
		for u in p.units:
			if u.has("twoFacesWind") or u.has("twoFacesWindAttack"):
				u.attackBonus=int(u.attackBonus)-int(u.get("twoFacesWindAttack",u.get("twoFacesWind",0)))
				u.erase("twoFacesWind");u.erase("twoFacesWindAttack");gs._recalc(u)
static func knocked_out(u: Dictionary) -> void:
	u.attackBonus=int(u.attackBonus)-int(u.get("twoFacesWindAttack",u.get("twoFacesWind",0)))
	u.erase("twoFacesWind");u.erase("twoFacesWindAttack")
static func link_completed(gs, owner: int, iid: String) -> void:
	var p:Dictionary=gs.player(owner)
	if not p.units.any(func(u):return active(u) and u.get("formRules",{}).get("twoFacesDeck",false)):return
	if not p.deck.any(func(i):return str(i.instanceId)==iid):return
	if not p.has("twoFacesDeckAccess"):p.twoFacesDeckAccess=[]
	p.twoFacesDeckAccess.append({"id":iid,"turn":gs.turn_counter})
	gs.VerifiedRules.event(gs,"two-faces-deck-ready",{"player":owner,"instanceId":iid})
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("twoFacesRules",false):return null
	if card.id=="c23802" and gs._unit_index_by_uid(owner,str(target_id))>=0:return -30
	return 45 if card.get("twoFacesFromDeck",false) and card.get("twoFacesDeckFree",false) else 30
static func marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx];var out:Array=[]
	if source(u):out.append("风雷连引 · "+("所有牌增强生效" if u.awakened else "连引使用获得增强"))
	if int(u.get("twoFacesWind",0))>0:
		var wind_attack:=int(u.get("twoFacesWindAttack",u.twoFacesWind))
		out.append("本回合追猎"+(" · 力量+%d"%wind_attack if wind_attack>0 else ""))
	if u.get("formRules",{}).get("twoFacesDeck",false):out.append("风雷万象 · 连引另一张可从牌库使用 · 每回合首张免费")
	return out
