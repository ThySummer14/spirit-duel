class_name MoonRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp",0))>0 and int(unit.get("level",0))>0 and not unit.get("baseRulesSuppressed",false)

static func master(gs, owner: int) -> Dictionary:
	for unit in gs.player(owner).units:
		if active(unit) and Content.runtime_unit_def(unit).get("moonMaster",false): return unit
	return {}

static func attach(gs, owner: int, idx: int) -> void:
	if idx<0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	if not active(unit): return
	unit.moonCharm = {"serial":gs.next_rule_event_id}
	gs.VerifiedRules.event(gs,"moon-attached",{"player":owner,"uid":unit.uid})

static func consume_card(gs, card: Dictionary) -> void:
	if not card.has("moonCharmUid"): return
	for p in gs.players:
		for unit in p.units:
			if str(unit.uid)==str(card.moonCharmUid) and int(unit.get("moonCharm",{}).get("serial",-1))==int(card.moonCharmSerial):
				unit.erase("moonCharm")

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	var unit := master(gs,owner)
	if unit.is_empty() or unit.get("moonCharm",{}).is_empty() or gs._source_index(owner,card)<0: return card
	if not unit.awakened and (int(gs.player(owner).energy)!=0 or card.get("unitId")!=unit.id): return card
	var out := card.duplicate(true)
	if "instant" not in out.keywords: out.keywords.append("instant")
	out.moonCharmUid = unit.uid; out.moonCharmSerial = unit.moonCharm.serial
	out.text += "\n宵月：获得瞬发，使用后移除此灵咒。"
	return out

static func drawn(gs, owner: int, inst: Dictionary) -> void:
	if Content.card_def(str(inst.definitionId)).get("moonRules",false):
		gs.resolution_stack.append({"kind":"moon-drawn","playerIndex":owner})

static func extra_attack(gs, owner: int) -> bool:
	var unit := master(gs,owner)
	return gs.player(owner).attackUsed and not unit.is_empty() and unit.get("formRules",{}).get("moonExtraAttack",false) and not unit.get("moonCharm",{}).is_empty()

static func pay_extra(gs, owner: int) -> bool:
	if not extra_attack(gs,owner): return false
	master(gs,owner).erase("moonCharm")
	gs.VerifiedRules.event(gs,"moon-extra-attack",{"player":owner})
	return true

static func locked_fire(gs) -> bool:
	for p in gs.players:
		if p.realms.any(func(r):return int(r.hp)>0 and r.get("nativeRealm")=="moon-lock"): return true
	return false

static func change_fire(gs, owner: int, value: int, spent: bool = false) -> void:
	var p: Dictionary = gs.player(owner)
	var before := int(p.energy)
	p.energy = maxi(0,value)
	if spent and int(p.energy)<before and locked_fire(gs):
		p.energy = 0
		gs.VerifiedRules.event(gs,"moon-fire-cleared",{"player":owner,"spent":before-maxi(0,value)})
	if before!=int(p.energy) and int(p.energy)==1 and owner==gs.current_player:
		if gs.player(1-owner).hand.any(func(i):return Content.card_def(str(i.definitionId)).get("autoResponse")=="enemy-fire-one"):
			gs.resolution_stack.append({"kind":"moon-fire-check","playerIndex":owner})

static func card_frames(gs, owner: int) -> Array:
	var out: Array = []
	while not gs.resolution_stack.is_empty() and gs.resolution_stack.back().get("kind")=="moon-fire-check" and int(gs.resolution_stack.back().playerIndex)==owner:
		out.push_front(gs.resolution_stack.pop_back())
	return out

static func begin_snapshot(gs) -> void:
	gs.moon_previous_start = gs.moon_current_start.duplicate(true)
	gs.moon_current_start = {}
	for p in gs.players:
		for unit in p.units:
			if gs.VerifiedRules.OwlInsect.shikigami(unit): gs.moon_current_start[str(unit.uid)] = int(unit.hp)<=0

static func turn_start(gs, owner: int) -> void:
	if not gs.player(owner).realms.any(func(r):return int(r.hp)>0 and r.get("nativeRealm")=="moon-lock"): return
	var unit := master(gs,owner)
	if not unit.is_empty(): attach(gs,owner,gs._unit_index_by_uid(owner,str(unit.uid)))

static func form_entered(gs, owner: int, idx: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("moonExtraAttack",false): attach(gs,owner,idx)

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect")!="moon-full": return null
	var out: Array = []
	for side in [owner,1-owner]:
		for unit in gs.player(side).units:
			if int(unit.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(unit): continue
			if side!=owner and (gs.VerifiedRules.Combat.has(unit,"veil") or gs.VerifiedRules.Movement.has_veil(unit)): continue
			out.append(str(unit.uid))
	return out

static func full_moon(gs, unit: Dictionary) -> void:
	for owner in 2:
		var idx: int=gs._unit_index_by_uid(owner,str(unit.uid))
		if idx>=0:
			gs.VerifiedRules.Glutton.remove_charm(gs,owner,idx,"望月：移除灵咒")
			gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,idx,"望月：移除灵咒")
			gs.VerifiedRules.Vine.remove_charm(gs,owner,idx,"望月：移除灵咒")
	gs.VerifiedRules.Crocodile.detach(gs,unit,"望月：移除灵咒",false)
	gs.VerifiedRules.Whale.remove_charms(unit)
	gs.VerifiedRules.Onikiri.remove_charms(unit)
	gs.VerifiedRules.Goldfish.remove_charm(unit)
	for key in ["spiderMark","garudaFeather","moonCharm","owlGuard","insectCorrosion","insectCorrosionOwners","pipeMarks"]: unit.erase(key)
	gs._recalc(unit)
	gs.VerifiedRules.OwlInsect.refresh(gs)
	gs._heal_unit(unit,int(unit.maxHp))

static func start_hand_choice(gs, owner: int) -> void:
	var ids: Array = gs.player(owner).hand.map(func(i):return str(i.instanceId))
	if ids.is_empty(): return
	gs.pending_choice = {"type":"moon-hand-top","playerIndex":owner,"zone":"hand","instanceIds":ids,"heading":"邀 月","title":"选择一张手牌置于牌库顶","hint":"移动所选原牌；不弃牌，不洗牌。"}
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type")!="moon-hand-top": return null
	for i in gs.player(owner).hand.size():
		if str(gs.player(owner).hand[i].instanceId)==iid: return gs.hand_card_def(owner,i)
	return {}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	if gs.pending_choice.get("type")!="moon-hand-top" or int(gs.pending_choice.playerIndex)!=owner or iid not in gs.pending_choice.instanceIds: return false
	var idx: int = gs.player(owner).hand.find_custom(func(i):return str(i.instanceId)==iid)
	if idx<0: return false
	var inst: Dictionary = gs.player(owner).hand.pop_at(idx)
	gs.player(owner).deck.append(inst)
	gs._record("resolve_divination_choice",{"choice":"moon-hand-top","instanceId":iid,"card":inst.definitionId},owner)
	gs.pending_choice={}; gs.phase="main"; gs.VerifiedRules.BondDream.refresh(gs)
	gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="moon-hand-top": return null
	var best := str(gs.pending_choice.instanceIds[0]); var score := -999
	for iid in gs.pending_choice.instanceIds:
		var card: Dictionary = choice_card(gs,owner,str(iid))
		var value := int(card.get("level",1))+(5 if card.get("moonRules",false) else 0)
		if value>score: score=value; best=str(iid)
	return resolve_choice(gs,owner,best)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action","")):
		"moon-tide":
			gs.resolution_stack.append({"kind":"moon-tide-fire","playerIndex":owner})
			gs.VerifiedRules.Divination.start(gs,owner,2)
		"moon-full": full_moon(gs,target)
		"moon-invite":
			gs.resolution_stack.append({"kind":"moon-hand-choice","playerIndex":owner})
			gs._draw(owner,2)
		"moon-rewind":
			var frames: Array = []
			for dead in [true,false]:
				for side in [owner,1-owner]:
					for unit in gs.player(side).units:
						if gs.moon_previous_start.get(str(unit.uid))==dead: frames.append({"kind":"moon-rewind-unit","playerIndex":owner,"sourceIndex":src,"victim":side,"uid":unit.uid,"destroy":dead})
			frames.reverse(); gs.resolution_stack.append_array(frames)
		"moon-eclipse": gs._set_fire(1-owner,int(gs.player(1-owner).energy)-1)
		"moon-awaken": gs._awaken(owner,src,card,effect.value)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if not kind.begins_with("moon-"): return false
	var owner := int(frame.playerIndex)
	match kind:
		"moon-tide-fire": gs.VerifiedRules.Light.gain_fire(gs,owner,1)
		"moon-drawn":
			var unit := master(gs,owner)
			if not unit.is_empty(): attach(gs,owner,gs._unit_index_by_uid(owner,str(unit.uid)))
		"moon-hand-choice": start_hand_choice(gs,owner)
		"moon-fire-check":
			if int(gs.player(owner).energy)==1: gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-fire-one",null,{"kind":"response-complete"})
		"moon-basic": gs._resolve_combat(owner,int(frame.sourceIndex),0,false,false,false,false,frame.get("targetId"),false,{"basicAttack":true})
		"moon-rewind-unit":
			var side := int(frame.victim)
			var idx: int = gs._unit_index_by_uid(side,str(frame.uid))
			if idx<0: return true
			var unit: Dictionary = gs.player(side).units[idx]
			if frame.destroy:
				if int(unit.hp)>0: gs.VerifiedRules.Panguan.destroy(gs,owner,int(frame.sourceIndex),side,idx)
			elif int(unit.hp)<=0 and gs.VerifiedRules.Rebirth.can_revive(unit):
				unit.knockout=0; unit.hp=int(unit.maxHp); unit.shield=0; unit.shieldExpires=0; unit.front=0
				gs.VerifiedRules.Movement.revived(gs,side,idx)
				gs.VerifiedRules.event(gs,"moon-revived",{"player":owner,"victimPlayer":side,"target":unit.uid})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("moonRules",false): return null
	match str(card.effect):
		"moon-full":
			var unit: Dictionary = gs._unit_by_uid(gs.player(owner).units,target_id)
			return 55 if not unit.is_empty() and (int(unit.hp)<int(unit.maxHp) or int(unit.get("insectCorrosion",0))>0) else -100
		"moon-eclipse": return 60 if int(gs.player(1-owner).energy)>0 else -100
		"moon-rewind":
			var score := 0
			for side in [owner,1-owner]:
				for unit in gs.player(side).units:
					if not gs.moon_previous_start.has(str(unit.uid)): continue
					var dead: bool = gs.moon_previous_start[str(unit.uid)]
					if dead and int(unit.hp)>0: score += 30 if side!=owner else -30
					if not dead and int(unit.hp)<=0: score += 30 if side==owner else -30
			return 50+score if score>0 else -100
		_: return 50
