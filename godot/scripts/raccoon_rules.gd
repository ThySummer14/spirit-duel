class_name RaccoonRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("raccoonStun",false)

static func feast(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r):return int(r.hp)>0 and r.get("nativeRealm")=="raccoon-feast")

static func ignores(gs, owner: int, u: Dictionary) -> bool:
	return (active(u) and source(u) and u.awakened) or feast(gs,owner)

static func instant(gs, owner: int, card: Dictionary) -> bool:
	var src: int=gs._source_index(owner,card)
	return src>=0 and int(gs.player(owner).units[src].frozen)>0 and feast(gs,owner)

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not instant(gs,owner,card): return card
	var out:=card.duplicate(true)
	if not out.keywords.has("instant"): out.keywords.append("instant")
	out.text+="\n饮啖醉饱：所属式神处于眩晕，本牌获得瞬发。"
	return out

static func wine(gs, owner: int, count: int) -> void:
	for i in count:
		if gs.player(owner).hand.size()>=int(gs.rules.get("maxHandSize",12)):
			gs._log("手牌已满，妖酒被移除。",gs.TONE_NEUTRAL); continue
		gs.player(owner).hand.append({"definitionId":"yaojiu","instanceId":"wine-%d" % gs.next_card_id}); gs.next_card_id+=1
		gs.VerifiedRules.event(gs,"raccoon-wine-created",{"player":owner,"card":Content.card_def("yaojiu")})

static func stunned(gs, owner: int, idx: int) -> void:
	if idx<0: return
	var u: Dictionary=gs.player(owner).units[idx]
	if not active(u) or not source(u): return
	gs._heal_unit(u,int(u.maxHp) if u.awakened else 3)
	gs._grow_unit(u,2,0)
	gs.VerifiedRules.event(gs,"raccoon-stun-reaction",{"player":owner,"uid":u.uid,"awakened":bool(u.awakened)})
	if u.get("formRules",{}).get("raccoonDrunk",false):
		gs.resolution_stack.append({"kind":"raccoon-drunk-attack","playerIndex":owner,"sourceIndex":idx})

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("raccoonAnyUnit",false): return null
	var out: Array=[]
	for side in [owner,1-owner]:
		for u in gs.player(side).units:
			if int(u.hp)>0 and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side==owner or not gs.VerifiedRules.Combat.has(u,"veil")): out.append(str(u.uid))
	return out

static func end_turn(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if active(u) and int(u.front)==1 and u.get("formRules",{}).get("raccoonExpert",false): wine(gs,owner,1)

static func turn_start(gs, owner: int) -> void:
	if not feast(gs,1-owner): return
	for i in range(gs.player(owner).units.size()-1,-1,-1):
		if int(gs.player(owner).units[i].hp)>0 and int(gs.player(owner).units[i].frozen)>0:
			gs.resolution_stack.append({"kind":"raccoon-discard","playerIndex":owner,"sourceIndex":i})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""))
	if not kind.begins_with("raccoon-"): return false
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex)
	var u: Dictionary=gs.player(owner).units[src]
	var context: Dictionary=gs._card_effect_context
	if kind=="raccoon-fire-wave": gs._card_effect_context=frame.get("context",{})
	match kind:
		"raccoon-drunk-attack":
			if int(u.hp)>0: gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"immuneCombat":true})
		"raccoon-fire-wave":
			var only_stunned: bool=frame.get("stunnedOnly",false)
			var victim:=1-owner
			if not only_stunned or int(gs.player(victim).get("avatarFrozen",0))>0: gs._damage_avatar(victim,3,owner,src)
			for idx in gs.player(victim).units.size():
				var target: Dictionary=gs.player(victim).units[idx]
				if int(target.hp)>0 and (not only_stunned or int(target.frozen)>0): gs._damage_unit(victim,idx,3,owner,src)
		"raccoon-discard":
			if not feast(gs,1-owner) or int(u.hp)<=0 or int(u.frozen)<=0: return true
			var ids: Array=gs.player(owner).hand.filter(func(inst):return Content.card_def(str(inst.definitionId)).get("unitId")==u.id).map(func(inst):return str(inst.instanceId))
			if not ids.is_empty():
				gs.pending_choice={"type":"raccoon-discard","playerIndex":owner,"zone":"hand","sourceIndex":src,"instanceIds":ids,"heading":"饮 啖 醉 饱","hint":"%s处于眩晕：选择弃掉一张其专属手牌，完成后继续回合开始。" % u.name}
				gs.phase="choice"
	gs._card_effect_context=context
	return true

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary=gs.pending_choice
	if c.get("type")!="raccoon-discard" or int(c.playerIndex)!=owner or not c.instanceIds.has(iid): return false
	var idx: int=gs.player(owner).hand.find_custom(func(inst):return str(inst.instanceId)==iid)
	if idx<0: return false
	var inst: Dictionary=gs.player(owner).hand.pop_at(idx)
	gs._record("resolve_divination_choice",{"choice":"raccoon-discard","instanceId":iid,"card":inst.definitionId},owner)
	gs._log("饮啖醉饱：弃掉「%s」。" % Content.card_def(str(inst.definitionId)).name,gs.TONE_CARD)
	gs.VerifiedRules.event(gs,"raccoon-discarded",{"player":owner,"instance":inst})
	gs.pending_choice={}; gs.phase="main"; gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action","")):
		"raccoon-wine": wine(gs,owner,int(effect.value))
		"raccoon-stun":
			for side in [owner,1-owner]:
				var idx: int=gs._unit_index_by_uid(side,str(target.get("uid","")))
				if idx>=0: gs.VerifiedRules.Stun.apply(gs,side,idx,1,owner); break
		"raccoon-damage":
			for side in [owner,1-owner]:
				var idx: int=gs._unit_index_by_uid(side,str(target.get("uid","")))
				if idx>=0: gs._damage_unit(side,idx,3,owner,src); break
		"raccoon-awaken": gs._awaken(owner,src,card,card.value); wine(gs,owner,1)
		"raccoon-fire":
			gs.resolution_stack.append({"kind":"raccoon-fire-wave","playerIndex":owner,"sourceIndex":src,"stunnedOnly":true,"context":gs._card_effect_context})
			gs.resolution_stack.append({"kind":"raccoon-fire-wave","playerIndex":owner,"sourceIndex":src,"stunnedOnly":false,"context":gs._card_effect_context})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("raccoonRules",false): return null
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.get("effect")=="raccoon-stun":
		var own: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(target_id))
		if not own.is_empty():
			if not source(own): return -100
			return 90 if own.get("formRules",{}).get("raccoonDrunk",false) else (72 if own.awakened or int(own.hp)<=int(own.maxHp)-3 else 10)
		var enemy: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return -50 if enemy.is_empty() or int(enemy.frozen)>0 or ignores(gs,1-owner,enemy) else 55+int(enemy.attack)*2
	if card.get("effect")=="raccoon-damage":
		var enemy: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return -100 if enemy.is_empty() else 48+(30 if int(enemy.hp)+int(enemy.shield)<=3 else 0)
	if card.type=="awakening": return -100 if u.awakened else 80
	if card.type=="form": return -40 if u.get("form",{}).get("cardId")==card.id else 50
	if card.type=="realm": return -40 if feast(gs,owner) else 65
	if card.get("effect")=="raccoon-fire": return 45+10*gs.VerifiedRules.Stun.count(gs,1-owner)
	return 45
