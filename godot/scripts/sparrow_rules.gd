class_name SparrowRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("sparrowNight",false))

static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)

static func automatic_identity(u: Dictionary) -> bool:
	# This is a card moving itself from hand/deck, not an active unit ability.
	return bool(Content.unit_def(str(u.get("id",""))).get("sparrowNight",false)) and not u.get("removed",false)

static func living_enemies(gs, owner: int, excluded: String = "", reserve: bool = false) -> Array:
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and str(u.uid)!=excluded and (not reserve or int(u.front)==0))

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect")!="sparrow-peck": return null
	return living_enemies(gs,owner).filter(func(u):return not (gs.VerifiedRules.Combat.has(u,"veil") or gs.VerifiedRules.Movement.has_veil(u))).map(func(u):return str(u.uid))

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("sparrowRules",false): return true
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	var u: Dictionary=gs.player(owner).units[src]
	if card.get("effect")=="sparrow-awaken": return not u.awakened
	if card.get("effect")=="sparrow-dawn" and int(u.hp)<=0: return gs.VerifiedRules.YanmieTrio.can_revive(gs,owner,u)
	return true

static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("sparrowRules",false): return card
	var out:=card.duplicate(true)
	var night: int=gs.VerifiedRules.Maple.night_value(gs,owner)
	if card.get("formRules",{}).get("sparrowSubstitute",false):
		out.value={"attack":night,"hp":night,"setBase":true}
		out.effects[0].value=out.value.duplicate(true)
		out.currentCardStats="当前形态%d/%d · 入夜%d/10" % [night,night,night]
	elif card.get("effect")=="sparrow-dawn": out.currentCardStats="复活 · 获得%d护甲 · 入夜%d/10" % [int(night/2),night]
	elif card.get("type")=="form": out.currentCardStats="当前形态%d/%d · 入夜%d/10" % [int(out.value.attack),int(out.value.hp),night]
	else: out.currentCardStats="入夜%d/10" % night
	return out

static func turn_start(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[src]
		if not source(u) or not active(u): continue
		if u.awakened: gs.resolution_stack.append({"kind":"sparrow-start-growth","playerIndex":owner,"sourceIndex":src})
		gs.resolution_stack.append({"kind":"sparrow-start-armor","playerIndex":owner,"sourceIndex":src})

static func end_turn(gs, owner: int) -> void:
	# This modifier is additive to temporaryAttack. Remove only our own portion.
	for side in gs.players:
		for u in side.units:
			if int(u.get("sparrowCourtPenalty",0))<=0: continue
			u.temporaryAttack=int(u.get("temporaryAttack",0))+int(u.sparrowCourtPenalty)
			u.erase("sparrowCourtPenalty")
			gs._recalc(u)
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[src]
		if automatic_identity(u): gs.resolution_stack.append({"kind":"sparrow-auto-nest","playerIndex":owner,"sourceIndex":src})

static func before_attacked(gs, frame: Dictionary) -> void:
	var victim:=int(frame.options.get("combatVictim",1-int(frame.playerIndex)))
	if victim==int(frame.playerIndex):return
	var defender: Dictionary=gs.player(victim).units[int(frame.defenderIndex)]
	if not active(defender) or not defender.get("formRules",{}).get("sparrowCourt",false): return
	if not gs.VerifiedRules.Maple.nightfall(gs,victim,5): return
	var attacker: Dictionary=gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
	attacker.temporaryAttack=int(attacker.get("temporaryAttack",0))-2
	attacker.sparrowCourtPenalty=int(attacker.get("sparrowCourtPenalty",0))+2
	gs._recalc(attacker)
	gs.VerifiedRules.event(gs,"sparrow-court",{"player":victim,"uid":defender.uid,"target":attacker.uid,"amount":2})

static func knockout_snapshot(gs, owner: int, u: Dictionary) -> Array:
	# The regular knockout path erases temporaryAttack. Do not later refund a
	# penalty whose entire temporary modifier was already removed on death.
	u.erase("sparrowCourtPenalty")
	if owner<0 or int(u.level)<1 or u.get("baseRulesSuppressed",false) or not u.get("formRules",{}).get("sparrowDeath",false): return []
	return [{"kind":"sparrow-death","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,str(u.uid)),"amount":gs.VerifiedRules.Maple.night_value(gs,owner)}]

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("sparrowSubstitute",false) and int(gs.player(owner).units[src].hp)<=0:
		absorb_knockout(gs,owner,gs.player(owner).units[src])

static func absorb_knockout(gs, owner: int, u: Dictionary) -> bool:
	if owner<0 or u.get("baseRulesSuppressed",false) or not (u.get("formRules",{}).get("sparrowSubstitute",false) or u.get("formRules",{}).get("substitute",false)): return false
	var src: int=gs._unit_index_by_uid(owner,str(u.uid))
	# Substitute replaces entering knockout; it never runs death or revival hooks.
	# Form departure and charm removal remain their own observable events.
	gs.VerifiedRules.Forms.remove(gs,owner,src,"替身生效")
	gs.VerifiedRules.FoxLotus.remove_charm(gs,u)
	gs.VerifiedRules.Maple.remove_doll(gs,u)
	gs.VerifiedRules.Movement.clear_hold(gs,u)
	gs.VerifiedRules.Pine.knocked_out(u)
	gs.VerifiedRules.Crocodile.detach(gs,u,"替身",false)
	gs.VerifiedRules.Whale.remove_charms(u,false)
	for key in ["spiderMark","garudaFeather","moonCharm","pipeMarks","owlGuard","owlUnyielding","insectCorrosion","insectCorrosionOwners","foxPillow","foxPillowTurn","lotusPillow","lotusPillowTurn","judgeInkAttack","judgeInkHp","temporaryAttack","sparrowCourtPenalty","untilAttack","cranePower","combatUnyielding","inspired","enraged","stunOwners","movementHolders","movementBaseFrozen","movementZeroTurn","movementVeil","bondMoonPursuit","dreamPowerPenalty","dreamPenaltyTurn","treeHealthCombat","treeDisasters","pendingShields","monkFormUnyielding","monkEnrageTurn","foxVeil","foxVeilTurn","foxFormImmuneTurn","swanKeywords","blackWhiteGrowthAttack","blackWhiteGrowthHp","futakuchiFearGrowth","mianRedGrowth","msSwapDeltas", "rpGrowthAttack", "rpGrowthHp", "rpRenxiaAttack","bgGreenTemporary","chargedGrowth","chargedBambooGrowth","lanternStored","chargedVeil","twoFacesWind","twoFacesWindAttack"]: u.erase(key)
	# Own awakening and explicitly permanent growth belong to the underlying body.
	u.attackBonus=maxi(gs.VerifiedRules.Glutton.awakened_attack(u),int(u.get("gluttonPermanentAttack",0)))+int(u.get("blessingPermanentAttack",0))
	u.maxHpBonus=maxi(gs.VerifiedRules.Glutton.awakened_hp(u),int(u.get("gluttonPermanentHp",0)))+int(u.get("sparrowPermanentHp",0))+int(u.get("oniPermanentHp",0))+int(u.get("windPermanentHp",0))+int(u.get("blessingPermanentHp",0))
	u.shield=0; u.shieldExpires=0; u.frozen=0; u.brittle=0; u.armorBreak=0; u.barrier=false; u.unyielding=false
	u.knockout=0
	gs._recalc(u)
	u.hp=int(u.maxHp)
	gs.VerifiedRules.OwlInsect.refresh(gs)
	gs.VerifiedRules.Poison.refresh_all(gs)
	gs.VerifiedRules.event(gs,"sparrow-substitute",{"player":owner,"uid":u.uid,"hp":u.hp,"attack":u.attack})
	return true

static func nest_present(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r):return r.get("nativeRealm")=="sparrow-nest")

static func nest_entry(gs, owner: int, src: int) -> void:
	gs.resolution_stack.append({"kind":"sparrow-nest-night","playerIndex":owner,"sourceIndex":src})
	var pool: Array=gs.player(owner).units.filter(func(u):return gs.VerifiedRules.YanmieTrio.can_revive(gs,owner,u))
	if not pool.is_empty():
		var chosen: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
		gs.VerifiedRules.Peach.revive(gs,owner,src,chosen,false,false)

static func deploy_nest(gs, owner: int, src: int, card: Dictionary) -> void:
	gs._deploy_realm(owner,card)
	nest_entry(gs,owner,src)

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm")!="sparrow-nest": return false
	var src: int=gs._source_index(owner,{"unitId":realm.sourceUnit})
	if src>=0: gs.resolution_stack.append({"kind":"sparrow-nest-trigger","playerIndex":owner,"sourceIndex":src,"realmUid":realm.uid})
	return true

static func assault(gs, owner: int, src: int, card: Dictionary, target_id) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if int(u.hp)<=0: return
	var options: Dictionary=card.get("combatOption",{}).duplicate(true)
	options.combatCard=card.duplicate(true)
	var bonus:=int(card.get("value",0))
	gs._grant_unit_armor(u,int(options.get("shield",0)))
	gs._record("assault",{"unit":src,"target":target_id,"bonus":bonus},owner)
	gs._resolve_combat(owner,src,bonus,gs._kw(card,"pierce"),gs._kw(card,"remote"),gs._kw(card,"combo"),gs._kw(card,"first-strike"),target_id,gs._kw(card,"crit"),options)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	var u: Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"sparrow-peck":
			gs.resolution_stack.append({"kind":"sparrow-peck-night","playerIndex":owner,"sourceIndex":src,"excludedUid":str(target.get("uid","")),"context":gs._card_effect_context.duplicate(true)})
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid","")))
			if idx>=0:
				var hit: Dictionary=gs._damage_unit(1-owner,idx,3,owner,src)
				gs.VerifiedRules.Peach.heal(gs,owner,src,owner,u,int(hit.get("transferredDealt",hit.get("dealt",hit.get("damage",0)))))
		"sparrow-dawn":
			if int(u.hp)<=0 and not gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false): return true
			gs._grant_unit_armor(u,int(gs.VerifiedRules.Maple.night_value(gs,owner)/2))
			gs.resolution_stack.append({"kind":"sparrow-assault","playerIndex":owner,"sourceIndex":src,"card":card,"targetId":target_id})
		"sparrow-harvest":
			gs.resolution_stack.append({"kind":"sparrow-assault","playerIndex":owner,"sourceIndex":src,"card":card,"targetId":target_id})
			if gs.VerifiedRules.Maple.nightfall(gs,owner,7):
				for victim in living_enemies(gs,owner,"",true): gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,str(victim.uid)),2,owner,src)
		"sparrow-awaken":
			gs.resolution_stack.append({"kind":"sparrow-awaken-complete","playerIndex":owner,"sourceIndex":src,"card":card,"value":effect.value})
			if gs.VerifiedRules.Maple.nightfall(gs,owner,5): gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
		"sparrow-nest": deploy_nest(gs,owner,src,card)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""))
	if not kind.begins_with("sparrow-"): return false
	var owner:=int(frame.playerIndex)
	var src:=int(frame.get("sourceIndex",-1))
	var u: Dictionary=gs.player(owner).units[src] if src>=0 else {}
	var previous: Dictionary=gs._card_effect_context
	gs._card_effect_context=frame.get("context",{})
	match kind:
		"sparrow-awaken-complete": gs._awaken(owner,src,frame.card,frame.value)
		"sparrow-start-armor":
			if source(u) and active(u) and gs.VerifiedRules.Maple.nightfall(gs,owner,3): gs._grant_unit_armor(u,2)
		"sparrow-start-growth":
			if source(u) and active(u) and u.awakened and gs.VerifiedRules.Maple.nightfall(gs,owner,7):
				u.permanentAttack=int(u.get("permanentAttack",0))+1
				u.sparrowPermanentHp=int(u.get("sparrowPermanentHp",0))+1
				gs._grow_unit(u,0,1); gs._recalc(u)
		"sparrow-peck-night":
			if gs.VerifiedRules.Maple.nightfall(gs,owner,3):
				var pool:=living_enemies(gs,owner,str(frame.excludedUid))
				if not pool.is_empty():
					var victim: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
					var hit: Dictionary=gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,str(victim.uid)),3,owner,src)
					if int(u.hp)>0: gs._grant_unit_armor(u,int(hit.get("transferredDealt",hit.get("dealt",hit.get("damage",0)))))
		"sparrow-death": gs.VerifiedRules.Maple.projectile(gs,owner,src,int(frame.amount))
		"sparrow-assault": assault(gs,owner,src,frame.card,frame.get("targetId"))
		"sparrow-nest-trigger":
			if gs.player(owner).realms.any(func(r):return str(r.uid)==str(frame.realmUid)): nest_entry(gs,owner,src)
		"sparrow-nest-night":
			if gs.VerifiedRules.Maple.nightfall(gs,owner,10):
				var pool:=living_enemies(gs,owner)
				if not pool.is_empty():
					var victim: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
					gs.VerifiedRules.Panguan.destroy(gs,owner,src,1-owner,gs._unit_index_by_uid(1-owner,str(victim.uid)),Content.card_def("c25708"))
		"sparrow-auto-nest":
			if automatic_identity(u) and gs.VerifiedRules.Maple.night_value(gs,owner)==10 and not nest_present(gs,owner):
				for zone in ["hand","deck"]:
					var idx: int=gs.player(owner)[zone].find_custom(func(e):return str(e.definitionId)=="c25708")
					if idx<0: continue
					var inst: Dictionary=gs.player(owner)[zone].pop_at(idx)
					gs.VerifiedRules.event(gs,"sparrow-nest-moved",{"player":owner,"uid":u.uid,"zone":zone,"instanceId":inst.instanceId,"card":Content.card_def("c25708")})
					deploy_nest(gs,owner,src,Content.card_def("c25708"))
					break
	gs._card_effect_context=previous
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("sparrowRules",false): return null
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	var night: int=gs.VerifiedRules.Maple.night_value(gs,owner)
	if card.get("effect")=="sparrow-peck":
		var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return -100 if target.is_empty() else 42+mini(3,int(target.hp))*3+(20 if int(target.hp)+int(target.shield)<=3 else 0)+mini(3,int(u.maxHp)-int(u.hp))*3+(10 if night>=3 and living_enemies(gs,owner,str(target_id)).size()>0 else 0)
	if card.type=="awakening": return -100 if u.awakened else 64
	if card.type=="form": return -30 if u.get("form",{}).get("cardId")==card.id else 45+(night*2 if card.get("formRules",{}).get("sparrowSubstitute",false) else 0)
	if card.get("effect")=="sparrow-dawn": return 95 if int(u.hp)<=0 else 42+int(night/2)*2
	if card.get("effect")=="sparrow-harvest": return 50+(12*living_enemies(gs,owner,"",true).size() if night>=7 else 0)
	return 45+20*gs.player(owner).units.filter(func(t):return int(t.hp)<=0 and gs.VerifiedRules.Rebirth.can_revive(t)).size()
