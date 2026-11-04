class_name MountainRealmRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("mountainBasic",false)

static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)

static func own_realms(gs, owner: int) -> Array:
	return gs.player(owner).realms.filter(func(r):return int(r.hp)>0 and str(r.sourceUnit)=="bujianyue")

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("effect")!="mountain-seek" or not own_realms(gs,owner).is_empty()

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("mountainRules",false) or card.get("target")!="selected-enemy": return null
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))

static func _grant_travel(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u): u.unyielding=true
	gs.VerifiedRules.event(gs,"mountain-unyielding",{"player":owner})

static func entered(gs, owner: int, card: Dictionary, target_id) -> void:
	var src: int=gs._source_index(owner,card)
	match str(card.get("realm",{}).get("nativeRealm","")):
		"mountain-cloud":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target_id))
			if idx>=0 and int(gs.player(1-owner).units[idx].hp)>0: gs._damage_unit(1-owner,idx,3,owner,src)
		"mountain-color": gs._apply_encourage(owner,2,2)
		"mountain-ridge":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target_id))
			if idx>=0 and int(gs.player(1-owner).units[idx].hp)>0: gs.VerifiedRules.ArmorBreak.give(gs,owner,src,1-owner,idx,4)
		"mountain-god":
			for u in gs.player(owner).units:
				if int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u): gs._grow_unit(u,0,1)
		"mountain-travel": _grant_travel(gs,owner)
	gs.VerifiedRules.event(gs,"mountain-realm-entered",{"player":owner,"card":card,"target":target_id})

static func god_form() -> Dictionary:
	var card:=Content.card_def("c28005").duplicate(true)
	card.type="form"; card.typeLabel="形态牌"; card.effect="form"; card.target="auto"
	card.erase("realm"); card.value={"attack":6,"hp":6,"setBase":true}
	card.effects=[{"condition":"always","action":"form","target":"source","value":card.value.duplicate()}]
	card.text="6力量/6生命。"; card.formAbility=""; card.formRules={"mountainGod":true}
	return card

static func realm_destroyed(gs, owner: int, realm: Dictionary, reason: String) -> void:
	# A match history, not a discard pile. Re-entry never removes this record.
	var history: Array=gs.player(owner).get("mountainDestroyedRealms",[])
	history.append({"cardId":str(realm.cardId),"uid":str(realm.uid),"realm":realm.duplicate(true)})
	gs.player(owner).mountainDestroyedRealms=history
	var mode:=str(realm.get("nativeRealm",""))
	if not mode.begins_with("mountain-"): return
	var src: int=gs._source_index(owner,{"unitId":str(realm.sourceUnit)})
	var context: Dictionary=gs._card_effect_context
	gs._card_effect_context={}
	match mode:
		"mountain-cloud": gs._heal_avatar(owner,3)
		"mountain-color":
			var pool: Array=[]; var largest: int=-1
			for u in gs.player(owner).units:
				if int(u.hp)>0 or u.get("summoned",false) or not gs.VerifiedRules.Rebirth.can_revive(u): continue
				if int(u.knockout)>largest: largest=int(u.knockout); pool.clear()
				if int(u.knockout)==largest: pool.append(u)
			if not pool.is_empty():
				var u: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
				u.hp=int(u.maxHp); u.knockout=0; u.shield=0; u.shieldExpires=0; u.front=0
				gs.VerifiedRules.Movement.revived(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)))
				gs.VerifiedRules.event(gs,"mountain-revived",{"player":owner,"target":u.uid,"countdown":largest})
		"mountain-ridge":
			for idx in gs.player(1-owner).units.size():
				if int(gs.player(1-owner).units[idx].hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(gs.player(1-owner).units[idx]): gs._damage_unit(1-owner,idx,1,owner,src)
		"mountain-god":
			if src>=0 and int(gs.player(owner).units[src].hp)>0:
				# Conversion belongs to the departure itself, before the sortie hits.
				# Unlike playing a replacement form, it cannot defer behind combat.
				if not gs.player(owner).units[src].get("form",{}).is_empty(): gs.VerifiedRules.Forms.remove(gs,owner,src,"古山之神转形态替换")
				gs._install_form(owner,src,god_form(),god_form().value)
		"mountain-travel":
			gs._heal_avatar(owner,6)
			for u in gs.player(owner).units:
				if gs.VerifiedRules.OwlInsect.shikigami(u): gs._heal_unit(u,6)
	gs._card_effect_context=context
	gs.VerifiedRules.event(gs,"mountain-realm-destroyed",{"player":owner,"realm":realm.uid,"card":Content.card_def(str(realm.cardId)),"reason":reason})

static func before_basic_attack(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not source(u) or not active(u): return
	gs._grow_unit(u,1 if u.awakened else 0,1)
	var realms:=own_realms(gs,owner)
	for realm in realms: gs.VerifiedRules.Huang.destroy(gs,owner,realm,"不见岳出击时被消灭")
	if u.awakened and not realms.is_empty(): gs._set_fire(owner,mini(4,int(gs.player(owner).energy)+1))
	gs.VerifiedRules.event(gs,"mountain-basic",{"player":owner,"uid":u.uid,"destroyed":realms.size(),"awakened":bool(u.awakened)})

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if not str(realm.get("nativeRealm","")).begins_with("mountain-"): return false
	if realm.get("nativeRealm")=="mountain-travel": _grant_travel(gs,owner)
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id) -> bool:
	match str(effect.get("action","")):
		"mountain-deploy": gs._deploy_realm(owner,card); entered(gs,owner,card,target_id)
		"mountain-seek":
			var ids: Array=own_realms(gs,owner).map(func(r):return str(r.uid))
			if not ids.is_empty():
				gs.pending_choice={"type":"mountain-realm","playerIndex":owner,"instanceIds":ids,"heading":"寻 径","hint":"消灭一个不见岳的幻境，然后抽两张牌。"}; gs.phase="choice"
		"mountain-awaken":
			var ids: Array=[]
			for i in gs.player(owner).deck.size():
				if Content.card_def(str(gs.player(owner).deck[i].definitionId)).get("type")=="realm": ids.append(i)
			if not ids.is_empty():
				var inst: Dictionary=gs.player(owner).deck.pop_at(int(ids[int(floor(gs.randf01()*ids.size()))]))
				if gs.player(owner).hand.size()<int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
				gs.VerifiedRules.event(gs,"mountain-realm-drawn",{"player":owner,"instance":inst})
			gs._awaken(owner,src,card,effect.value)
		"mountain-replay":
			var history: Array=gs.player(owner).get("mountainDestroyedRealms",[]).duplicate(true)
			var chosen: Array=[]
			for i in mini(2,history.size()): chosen.append(history.pop_at(int(floor(gs.randf01()*history.size()))))
			for i in range(chosen.size()-1,-1,-1): gs.resolution_stack.append({"kind":"mountain-replay","playerIndex":owner,"cardId":str(chosen[i].cardId)})
		_: return false
	return true

static func _place_replay(gs, owner: int, card: Dictionary, target_id) -> void:
	var src: int=gs._source_index(owner,card)
	if src<0: return
	var context: Dictionary=gs._card_effect_context
	gs._card_effect_context={}
	var target: Dictionary={}
	for side in [owner,1-owner]:
		var idx: int=gs._unit_index_by_uid(side,str(target_id))
		if idx>=0: target=gs.player(side).units[idx]; break
	# Put into play: actual entry effects, without announcing/playing a card.
	gs._resolve_card_effects(owner,src,card,target_id,target)
	gs._card_effect_context=context
	gs.VerifiedRules.event(gs,"mountain-realm-replayed",{"player":owner,"card":card,"target":target_id})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="mountain-replay": return false
	var owner:=int(frame.playerIndex); var card:=Content.card_def(str(frame.cardId))
	if card.get("type")!="realm": return true
	if card.get("target","auto")!="auto":
		var ids: Array=gs.valid_targets(owner,card)
		if ids.is_empty():
			# Entry target unavailable: the realm still enters and keeps durability.
			gs._deploy_realm(owner,card)
			gs.VerifiedRules.event(gs,"mountain-realm-replayed",{"player":owner,"card":card,"target":null})
		else:
			gs.pending_choice={"type":"mountain-target","playerIndex":owner,"cardId":str(card.id),"instanceIds":ids,"heading":"峰 回 路 转","hint":"%s进场：选择其效果的目标。" % card.name}; gs.phase="choice"
	else: _place_replay(gs,owner,card,null)
	return true

static func choice_card(gs, owner: int, iid: String):
	var choice: Dictionary=gs.pending_choice
	if not str(choice.get("type","")).begins_with("mountain-"): return null
	if choice.get("type")=="mountain-realm":
		for realm in own_realms(gs,owner):
			if str(realm.uid)==iid:
				var card:=Content.card_def(str(realm.cardId)).duplicate(true)
				card.text+="\n场上耐久%d。选择后消灭并触发被消灭效果。" % int(realm.hp)
				return card
	else:
		for side in [owner,1-owner]:
			var idx: int=gs._unit_index_by_uid(side,iid)
			if idx<0: continue
			var u: Dictionary=gs.player(side).units[idx]
			return {"id":iid,"unitId":str(u.id),"name":str(u.name),"type":"spell","typeLabel":"式神目标","level":int(u.level),"cost":0,"keywords":[],"text":"选择%s：%d力量，%d/%d生命，%d护甲。" % [u.name,int(u.attack),int(u.hp),int(u.maxHp),int(u.shield)]}
	return {}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary=gs.pending_choice
	if not str(choice.get("type","")).begins_with("mountain-") or int(choice.playerIndex)!=owner or iid not in choice.instanceIds: return false
	if choice.type=="mountain-realm":
		var selected: Dictionary={}
		for realm in own_realms(gs,owner):
			if str(realm.uid)==iid: selected=realm; break
		if selected.is_empty(): return false
		gs.pending_choice={}; gs.phase="main"
		gs.VerifiedRules.Huang.destroy(gs,owner,selected,"寻径消灭")
		gs._draw(owner,2)
	else:
		var card:=Content.card_def(str(choice.cardId))
		if iid not in gs.valid_targets(owner,card): return false
		gs.pending_choice={}; gs.phase="main"; _place_replay(gs,owner,card,iid)
	gs._record("resolve_divination_choice",{"choice":str(choice.type),"instanceId":iid},owner)
	gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if not str(gs.pending_choice.get("type","")).begins_with("mountain-"): return null
	var ids: Array=gs.pending_choice.get("instanceIds",[])
	if ids.is_empty(): return false
	var best: String=str(ids[0]); var top: float=-INF
	for iid in ids:
		var score: float=0
		if gs.pending_choice.type=="mountain-realm":
			for realm in own_realms(gs,owner):
				if str(realm.uid)!=str(iid): continue
				score=10-int(realm.hp)
				if realm.get("nativeRealm")=="mountain-color" and gs.player(owner).units.any(func(u):return int(u.hp)<=0): score+=40
				if realm.get("nativeRealm")=="mountain-god": score+=30
		else: score=float(score_card(gs,owner,Content.card_def(str(gs.pending_choice.cardId)),iid))
		if score>top: top=score; best=str(iid)
	return gs.resolve_divination_choice(owner,best)

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("mountainRules",false): return null
	var src: int=gs._source_index(owner,card)
	if src<0: return -100
	if card.effect=="mountain-seek": return -100 if own_realms(gs,owner).is_empty() else 65
	if card.effect=="mountain-replay": return -100 if gs.player(owner).get("mountainDestroyedRealms",[]).is_empty() else 85
	if card.effect=="mountain-awaken": return -100 if gs.player(owner).units[src].awakened else 80
	if card.get("target")=="selected-enemy":
		var idx: int=gs._unit_index_by_uid(1-owner,str(target_id))
		if idx<0: return -100
		var u: Dictionary=gs.player(1-owner).units[idx]
		return 45+int(u.attack)*2+(30 if card.get("realm",{}).get("nativeRealm")=="mountain-cloud" and int(u.hp)+int(u.shield)<=3 else 0)
	return 60
