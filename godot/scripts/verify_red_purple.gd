extends "res://scripts/verify_book_jue_ui.gd"

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const RP := preload("res://scripts/red_purple_rules.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const IDS := ["c20401","c20402","c20403","c20404","c20405","c20406","c20407","c20408","c20501","c20502","c20503","c20504","c20505","c20506","c20508","c20509"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("RED_PURPLE_FAIL ",detail)

func game(own: Array = ["huoqumo","yuanjiulanghu","rihefang","taohuayao"]) -> GS:
	var gs := GS.create(own,["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],204205)
	for side in gs.players:
		side.hand.clear(); side.energy = 40; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	gs.rule_events.clear()
	return gs

func give(gs, id: String) -> int:
	gs.player(0).hand.append({"definitionId":id,"instanceId":"rp-test-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(0).hand.size()-1

func play(gs, id: String, target = null) -> void:
	var h := give(gs,id)
	var legal: Dictionary = gs.can_play_card(0,h,target)
	check(gs.play_card(0,h,target),"actual use "+id+" "+str(legal.get("reason","")))

func choose(gs, id: String) -> void:
	check(gs.resolve_divination_choice(0,id),"actual fox choice "+id)

func finish(gs) -> void:
	var guard := 0
	while not gs.pending_choice.is_empty() and guard < 30:
		guard += 1
		check(AI._resolve_choice(gs,0),"real AI completes "+str(gs.pending_choice.get("type","")))
	check(guard < 30 and gs.pending_choice.is_empty(),"choice sequence terminates")

func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)

func faction_fixture(gs, faction: String) -> void:
	for unit in gs.player(0).units: unit.factionOverride = faction
	RP.refresh(gs)

func knock(gs, owner: int, index: int) -> void:
	gs._knockout_unit(gs.player(owner).units[index],1-owner,0)
	gs._resolve_resolution_stack()

func content_and_passives() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var red: Dictionary = p.units[0]
	check(red.attack == 2 and red.maxHp == 5 and red.passive_hooks.is_empty(),"printed red2/5 without historical numeric passive")
	check(p.units[1].attack == 2 and p.units[1].maxHp == 5,"printed purple2/5")
	for id in IDS:
		var c: Dictionary = Content.card_def(id)
		check(c.get("verifiedRules",false) and c.get("redPurpleRules",false) and not c.effects.is_empty(),"executable original card "+id)
		check(not c.get("verificationPending",[]).is_empty() and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"source and original art remain explicit "+id)
	play(gs,"c20407"); check(red.attack == 2 and red.maxHp == 5,"first red card cannot trigger second-card growth")
	play(gs,"c20403",p.units[2].uid); check(red.attack == 3 and red.maxHp == 6 and events(gs,"rp-red-second").size() == 1,"actual second red card grants exactly1/1")
	play(gs,"c20407"); check(red.attack == 3 and red.maxHp == 6,"third red card does not repeat growth")
	check(gs.end_turn(0) and gs.end_turn(1),"real turn cycle resets color counter")
	play(gs,"c20407"); play(gs,"c20407")
	check(red.attack == 4 and red.maxHp == 7 and events(gs,"rp-red-second").size() == 2,"a new own turn has its own second-card trigger")
	knock(gs,0,0); gs.VerifiedRules.Peach.revive(gs,0,3,red,false,false)
	check(red.attack == 2 and red.maxHp == 5,"ordinary red growth is removed on knockout")
	gs = game(["huoqumo","yuanjiulanghu","bingyong","rihefang"]); p = gs.player(0); var fox: Dictionary = p.units[1]
	play(gs,"c20501"); check(fox.maxHp == 5 and events(gs,"rp-purple-used").is_empty(),"purple does not react to its own card")
	play(gs,"c10303"); check(fox.maxHp == 6 and fox.hp == 6 and events(gs,"rp-purple-used").size() == 1,"another actual purple card grants1 life")
	play(gs,"c10303"); check(fox.maxHp == 7 and events(gs,"rp-purple-used").size() == 2,"every other purple card may trigger, not once per turn")
	for state in ["unleveled","suppressed","knocked"]:
		gs = game(); p = gs.player(0); red = p.units[0]
		if state == "unleveled": red.level = 0
		elif state == "suppressed": red.baseRulesSuppressed = true
		else: knock(gs,0,0)
		play(gs,"c16606",gs.player(1).units[0].uid); play(gs,"c16606",gs.player(1).units[1].uid)
		check(not red.has("rpGrowthAttack"),"inactive red source cannot gain second-card growth "+state)

func awakening_auras() -> void:
	var gs := game(["huoqumo","yuanjiulanghu","rihefang","bingyong"])
	var p: Dictionary = gs.player(0); var red: Dictionary = p.units[0]; var fox: Dictionary = p.units[1]
	var sun: Dictionary = p.units[2]; var soldier: Dictionary = p.units[3]
	var sun_attack := int(sun.attack); var sun_hp := int(sun.maxHp); var soldier_attack := int(soldier.attack); var soldier_hp := int(soldier.maxHp)
	play(gs,"c20406")
	check(red.awakened and red.attack == 3 and red.maxHp == 6,"red awakening grants its own printed1/1")
	check(sun.attack == sun_attack+1 and sun.maxHp == sun_hp+1 and fox.attack == 2 and soldier.attack == soldier_attack,"red aura only affects other same-faction allies")
	sun.hp -= 2; var injured := int(sun.hp)
	play(gs,"c20406")
	check(sun.hp == injured and sun.maxHp == sun_hp+1,"repeated awakening never stacks aura or heals an already affected ally")
	check(red.attack == 5 and red.maxHp == 8,"repeated printed1/1 and actual second-red trigger are distinct")
	play(gs,"c20503")
	check(fox.awakened and fox.attack == 3 and fox.maxHp == 6,"purple awakening has its own1/1")
	check(soldier.attack == soldier_attack+1 and soldier.maxHp == soldier_hp+1,"purple aura reaches other purple ally")
	soldier.hp -= 2; injured = int(soldier.hp); play(gs,"c20503")
	check(soldier.hp == injured and soldier.maxHp == soldier_hp+1,"repeat purple awakening does not refresh ally injury")
	check(fox.attack == 4 and fox.maxHp == 7,"repeated purple print is permanent while aura remains one source")
	knock(gs,0,0)
	check(sun.attack == sun_attack and sun.maxHp == sun_hp,"red aura is removed when its actual source is knocked out")
	gs.VerifiedRules.Peach.revive(gs,0,1,red,false,false)
	check(sun.attack == sun_attack+1 and sun.maxHp == sun_hp+1,"source revival restores the live aura")
	knock(gs,0,1)
	check(soldier.attack == soldier_attack and soldier.maxHp == soldier_hp,"purple aura also requires a living source")
	gs = game(["huoqumo","mianqiling","rihefang","taohuayao"]); p = gs.player(0)
	play(gs,"c20406"); var mask: Dictionary = p.units[1]; var mask_hp := int(mask.maxHp)
	play(gs,"c20801",mask.uid); choose(gs,"红莲")
	check(mask.maxHp == mask_hp+1 and mask.attack == 3,"real faction choice gains existing same-color aura immediately")
	play(gs,"c20801",mask.uid); choose(gs,"青岚")
	check(mask.maxHp == mask_hp and mask.attack == 2,"real change away loses aura immediately")
	gs = game(); p = gs.player(0); red = p.units[0]
	play(gs,"c20406"); var red_attack := int(red.attack); var red_hp := int(red.maxHp)
	check(gs.end_turn(0) and gs.end_turn(1),"awakened red enters later own turn")
	play(gs,"c20407"); play(gs,"c20407")
	check(red.attack == red_attack and red.maxHp == red_hp,"printed awakened red second-card clause is limited to awakening turn")

func red_forms_and_encourage() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var source: Dictionary = p.units[0]
	play(gs,"c20402"); check(source.attack == 3 and source.maxHp == 6 and gs.VerifiedRules.Combat.has(source,"pierce"),"mighty form exact3/6 and real pierce without qualified ally")
	gs._grow_unit(p.units[1],4,0); check(source.attack == 6,"another ally reaching6 activates dynamic3 power")
	gs._grow_unit(p.units[1],-4,0); check(source.attack == 3,"falling below6 removes conditional power")
	gs._grow_unit(gs.player(1).units[0],20,0); check(source.attack == 3,"strong enemy does not satisfy friendly condition")
	gs._grow_unit(p.units[1],4,0); knock(gs,0,1); check(source.attack == 3,"knocked qualifying ally ceases conditional contribution")
	gs = game(); p = gs.player(0); source = p.units[0]
	play(gs,"c20405"); check(source.attack == 6 and source.maxHp == 6,"leaf form snapshots two other living red allies")
	knock(gs,0,2); check(source.attack == 6 and source.maxHp == 6,"leaf enhancement is fixed on use, not an ongoing count aura")
	gs = game(); p = gs.player(0); source = p.units[0]; knock(gs,0,2)
	play(gs,"c20405"); check(source.attack == 5 and source.maxHp == 5,"knocked ally excluded from leaf enhancement")
	gs = game(); p = gs.player(0); source = p.units[0]
	var h := give(gs,"c20401"); check(not gs.hand_card_def(0,h).keywords.has("instant"),"night raid without deployment bonus is not instant")
	p.hand.clear(); gs._apply_encourage(0,3,2)
	h = give(gs,"c20401"); var card: Dictionary = gs.hand_card_def(0,h); var fire := int(p.energy)
	check(card.keywords.has("instant") and card.enhanced,"real encourage makes night raid instant")
	check(gs.play_card(0,h),"night raid actually consumes deployment bonus")
	check(gs.player(1).avatarHp == 24 and source.shield == 3,"night raid receives exactly3 attack plus its own1 and encourage2 armor plus printed1")
	check(p.energy == fire and gs.kw_usage(0,"instant").used and not gs.kw_usage(0,"encourage").get("traits",{}).size(),"night raid uses real instant and shared encourage ledger")
	check(gs.kw_usage(0,"encourage").attack == 0 and gs.kw_usage(0,"encourage").shield == 0,"encourage is consumed rather than copied")
	gs = game(); p = gs.player(0); source = p.units[0]
	play(gs,"c20403",p.units[1].uid)
	check(gs.VerifiedRules.Combat.has(p.units[1],"pursuit") and p.units[1].attack == 2,"mixed faction renxia grants real pursuit without unearned3 power")
	gs.player(1).units[0].front = 1
	check(gs.basic_attack_targets(0,1).has(gs.player(1).units[1].uid),"renxia changes actual basic attack target options")
	check(gs.end_turn(0) and not gs.VerifiedRules.Combat.has(p.units[1],"pursuit"),"renxia pursuit expires at actual turn boundary")
	gs = game(); p = gs.player(0); faction_fixture(gs,"红莲"); var before := int(p.units[1].attack)
	play(gs,"c20403",p.units[1].uid)
	check(p.units[1].attack == before+3 and gs.VerifiedRules.Combat.has(p.units[1],"pursuit"),"all red renxia grants both specified effects")
	check(gs.end_turn(0) and p.units[1].attack == before,"temporary renxia power is removed exactly once")
	gs = game(); p = gs.player(0); knock(gs,0,2)
	play(gs,"c20407")
	check(gs.kw_usage(0,"encourage").attack == 4 and gs.kw_usage(0,"encourage").shield == 4,"alliance counts living red only and grants shared4/4 encourage")

func sword_keywords() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var source: Dictionary = p.units[0]; var donor: Dictionary = p.units[2]
	donor.keywords = ["combo","remote","first-strike","direct","pursuit","penetration","crit","lethal","lifesteal","veil","pierce"]
	donor.swift = true; donor.unyielding = true; donor.inspired = true; donor.barrier = true
	var card: Dictionary = gs.hand_card_def(0,give(gs,"c20408")); var expected_attack := int(card.value.attack); var expected_hp := int(card.value.hp); var donor_attack := int(donor.attack); var donor_hp := int(donor.hp)
	check(card.formRules.gluttonKeywords.size() == 14 and card.formRules.rpCopiedCharge,"sword previews all14 supported actual keywords and native charge")
	check(gs.play_card(0,p.hand.size()-1),"sword installs actual inherited abilities")
	check(source.attack == expected_attack and source.maxHp == expected_hp and donor.attack == donor_attack and donor.hp == donor_hp,"sword copies snapshot body without stealing ally stats")
	for keyword in RP.TRAITS: check(gs.VerifiedRules.Combat.has(source,keyword) or (keyword == "swift" and gs.VerifiedRules.Glutton.has(source,"swift")),"inherited live keyword "+keyword)
	check(source.barrier and gs.VerifiedRules.SunSmoke.has_charge(source),"barrier and charge are genuine mechanisms")
	gs = game(); p = gs.player(0); source = p.units[0]; donor = p.units[2]
	donor.keywords = ["pursuit","veil"]; donor.swift = true; donor.unyielding = true; donor.inspired = true
	play(gs,"c20408"); gs.player(1).units[0].front = 1; gs._grow_unit(gs.player(1).units[1],0,30)
	var fire := int(p.energy); var target: Dictionary = gs.player(1).units[1]; var before := int(target.hp)
	check(gs.basic_attack_targets(0,0).has(target.uid) and gs.basic_attack(0,0,target.uid),"copied pursuit allows a real reserve attack")
	check(target.hp < before and p.energy == fire and not p.attackUsed,"copied swift waives fire and inspired preserves deployment count")
	check(not gs.VerifiedRules.Glutton.has(source,"swift") and not gs.VerifiedRules.Glutton.has(source,"inspired"),"copied one-use traits are actually consumed")
	source.charge = 0
	check(gs.end_turn(0) and gs.end_turn(1) and source.charge == 1,"copied charge really accumulates at next own turn")
	knock(gs,0,0); check(not gs.VerifiedRules.Combat.has(source,"pursuit") and not source.get("formRules",{}).get("rpCopiedCharge",false),"inherited form abilities leave with the form while stored energy has its own lifetime")

func fox_choice_and_heal() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var fox: Dictionary = p.units[1]
	play(gs,"c20502"); check(gs.pending_choice.type == "rp-fox-mode" and gs.pending_choice.instanceIds == [RP.FOX_HEAL],"without a realm only meaningful fox mode is offered")
	check(not gs.resolve_divination_choice(1,RP.FOX_HEAL) and not gs.resolve_divination_choice(0,"invalid"),"foreign and fabricated mode choices cannot commit")
	choose(gs,RP.FOX_HEAL); check(gs.pending_choice.type == "rp-fox-target" and "avatar-0" in gs.pending_choice.instanceIds and "avatar-1" in gs.pending_choice.instanceIds,"healing mode exposes both actual avatars")
	choose(gs,"avatar-0"); check(p.avatarHp == 30 and p.avatarArmor == 3 and gs.pending_choice.is_empty(),"full health avatar gets exactly3 overflow armor")
	gs = game(); p = gs.player(0); p.units[0].hp -= 2; var before := int(p.units[0].hp)
	play(gs,"c20502"); choose(gs,RP.FOX_HEAL); choose(gs,p.units[0].uid)
	check(p.units[0].hp == before+2 and p.units[0].shield == 1,"actual partial heal converts only true excess to1 armor")
	gs = game(); p = gs.player(0); fox = p.units[1]; gs.player(1).units[1].keywords = ["veil"]; gs.player(1).foxAvatarVeil = true
	play(gs,"c20502"); choose(gs,RP.FOX_HEAL)
	check(not gs.pending_choice.instanceIds.has(gs.player(1).units[1].uid) and not gs.pending_choice.instanceIds.has("avatar-1"),"fox second-stage choice respects unit and avatar veil")
	check(not gs.resolve_divination_choice(0,gs.player(1).units[1].uid),"hidden target remains illegal at choice commit")
	choose(gs,"avatar-0")
	gs = game(); p = gs.player(0); p.units[0].toxicPoisoned = true; var hp := int(p.units[0].hp)
	play(gs,"c20502"); choose(gs,RP.FOX_HEAL); choose(gs,p.units[0].uid)
	check(p.units[0].hp == hp and p.units[0].shield == 0,"prevented healing is not fabricated into overflow armor")
	gs = game(); p = gs.player(0); gs._grow_unit(p.units[2],10,0); play(gs,"c20404"); var realm: Dictionary = p.realms[0]
	play(gs,"c20502"); check(RP.FOX_REALM in gs.pending_choice.instanceIds,"existing realm enables distinct durability mode")
	choose(gs,RP.FOX_REALM); check(realm.uid in gs.pending_choice.instanceIds,"durability stage targets the real installed realm")
	choose(gs,realm.uid); check(realm.hp == 9 and gs.pending_choice.is_empty(),"durability choice modifies exact realm by3")
	gs = game(); p = gs.player(0); fox = p.units[1]
	play(gs,"c20501"); check(fox.attack == 4 and fox.hp == 5,"full-health fox hand converts2 overflow to real power before combat")
	gs = game(); p = gs.player(0); fox = p.units[1]; fox.hp = 2
	play(gs,"c20501"); check(fox.attack == 2 and fox.hp == 4,"unfilled healing has no overflow power")
	gs = game(); p = gs.player(0); fox = p.units[1]; fox.toxicPoisoned = true
	play(gs,"c20501"); check(fox.attack == 2 and fox.hp == 5,"blocked fox healing does not invent power")

func fox_guard_revival_and_journey() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var fox: Dictionary = p.units[1]
	play(gs,"c20504"); check(fox.attack == 3 and fox.maxHp == 7,"guard form follows PNG3/7 rather than old4/7")
	gs.player(1).units[0].front = 1; gs._grow_unit(gs.player(1).units[0],0,20)
	check(gs.basic_attack(0,1),"guard actually attacks a surviving front")
	check(gs.player(1).units[0].armorBreak == 3 and fox.shield == 2 and fox.hp == 7,"actual own-turn damage applies break3 and armor3 before one-power counter consumes1 armor")
	gs = game(); p = gs.player(0); fox = p.units[1]; play(gs,"c20504"); gs.player(1).units[0].front = 1; gs.player(1).units[0].shield = 99
	check(gs.basic_attack(0,1),"guard attacks armored enemy")
	check(gs.player(1).units[0].armorBreak == 0 and fox.shield == 0,"zero real damage cannot trigger guard")
	gs = game(); p = gs.player(0); fox = p.units[1]; play(gs,"c20504"); fox.front = 1; gs.current_player = 1
	gs.basic_attack(1,1)
	check(gs.player(1).units[1].armorBreak == 0 and fox.shield == 0,"enemy-turn counter damage is outside own-turn guard condition")
	gs = game(); p = gs.player(0); var target: Dictionary = p.units[2]; var base_attack := int(target.attack); var base_hp := int(target.maxHp)
	knock(gs,0,2); var h := give(gs,"c20505"); var legal := gs.valid_targets(0,gs.hand_card_def(0,h))
	check(legal.has(target.uid) and not legal.has(p.units[0].uid),"revival uses actual knocked-only target set")
	check(gs.play_card(0,h,target.uid),"mixed-faction drum actually revives")
	check(target.hp > 0 and target.attack == base_attack+1 and target.maxHp == base_hp+1 and target.shield == 1 and target.front == 0,"basic drum gives1/1/1 but does not move a mixed team")
	gs = game(["yuanjiulanghu","bingyong","baitongzi","xiazhongshaonv"]); p = gs.player(0); target = p.units[2]; knock(gs,0,2)
	play(gs,"c20505",target.uid)
	check(target.hp > 0 and target.front == 1 and gs.front_index(0) == 2 and target.shield == 1,"all-purple enhancement additionally moves real revived unit")
	gs = game(["yuanjiulanghu","bingyong","baitongzi","rihefang"]); p = gs.player(0); fox = p.units[0]
	play(gs,"c20508"); check(fox.attack == 10 and fox.maxHp == 10 and gs.VerifiedRules.Glutton.has(fox,"unyielding"),"heir has3/3 per other living purple and actual unyielding")
	gs._damage_unit(0,0,30,1,0); check(fox.hp == 1 and not gs.VerifiedRules.Glutton.has(fox,"unyielding"),"heir one-use unyielding prevents lethal once")
	gs._damage_unit(0,0,1,1,0); check(fox.hp == 0,"one-life heir has no fake permanent immunity")
	gs = game(["yuanjiulanghu","bingyong","baitongzi","xiazhongshaonv"]); p = gs.player(0); target = p.units[2]; var target_attack := int(target.attack); var target_hp := int(target.maxHp)
	play(gs,"c20509"); play(gs,"c20509"); knock(gs,0,2)
	check(gs.end_turn(0),"journey resolves at actual own turn end")
	check(target.hp == 0 and target.attack == target_attack+2 and target.maxHp == target_hp+2,"two journey stacks permanently grow a knocked purple without reviving it")
	check(gs.player(0).units[0].attack == 4 and gs.player(0).units[0].maxHp == 7,"living purple also gets both permanent stacks")
	knock(gs,0,0)
	check(gs.end_turn(1) and gs.end_turn(0),"persistent journey continues through source KO into another end turn")
	check(target.attack == target_attack+4 and target.maxHp == target_hp+4,"journey does not require its original source alive")

func max_realms_resets_and_ai() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var deck := int(p.deck.size())
	gs._grow_unit(gs.player(1).units[0],8,0); play(gs,"c20404")
	check(p.deck.size() == deck,"red maximum realm does not draw when only enemy is strongest")
	gs._grow_unit(p.units[2],20,0); check(gs.end_turn(0) and gs.end_turn(1),"maximum realm enters actual new own turn")
	check(events(gs,"rp-maximum-draw").size() == 1,"red realm draws on own start when friend becomes strongest")
	gs = game(); p = gs.player(0); deck = int(p.deck.size()); gs._grow_unit(p.units[2],10,0)
	play(gs,"c20404"); check(p.deck.size() == deck-1 and events(gs,"rp-maximum-draw").size() == 1,"red realm checks and draws at actual entry")
	gs = game(); p = gs.player(0); deck = int(p.deck.size()); gs._grow_unit(p.units[2],0,20)
	play(gs,"c20506"); check(p.deck.size() == deck-1 and events(gs,"rp-maximum-draw").size() == 1,"purple maximum compares current life and draws at entry")
	gs = game(); p = gs.player(0); deck = int(p.deck.size()); gs._grow_unit(p.units[2],0,20); p.units[2].hp = 1; gs._grow_unit(gs.player(1).units[0],0,30)
	play(gs,"c20506"); check(p.deck.size() == deck,"large max life without current life does not satisfy purple maximum")
	gs = game(); p = gs.player(0); play(gs,"c20407"); play(gs,"c20407"); var red: Dictionary = p.units[0]
	play(gs,"c16606",red.uid); check(red.attack == 2 and red.maxHp == 5 and not red.has("rpGrowthAttack") and not red.has("rpGrowthHp"),"sun reset clears ordinary color growth and its rollback ledger")
	knock(gs,0,0); gs.VerifiedRules.Peach.revive(gs,0,3,red,false,false)
	check(red.attack == 2 and red.maxHp == 5,"later knockout cannot deduct already reset red growth twice")
	gs = game(); p = gs.player(0); faction_fixture(gs,"紫岩"); play(gs,"c20509"); check(gs.end_turn(0) and gs.end_turn(1),"permanent journey precedes reset fixture")
	var fox: Dictionary = p.units[1]; var power := int(fox.attack); var health := int(fox.maxHp)
	play(gs,"c16606",fox.uid)
	check(fox.attack == power and fox.maxHp == health,"sun reset preserves permanent journey while clearing newly triggered ordinary growth")
	for id in IDS:
		gs = game(); p = gs.player(0)
		if id == "c20505": knock(gs,0,2)
		give(gs,id)
		var best: Dictionary = AI._best_card(gs,0)
		check(best.ok and best.card_id == id and gs.can_play_card(0,int(best.hand),best.target).ok,"AI chooses a legal original card "+id)
		check(gs.play_card(0,int(best.hand),best.target),"AI actually uses original card "+id)
		finish(gs)
	var marks := Status.unit_marks(Status.unit_view(gs,0,0,0),gs.turn_counter)
	check(marks.any(func(m): return str(m.id) == "red-purple"),"live faction capability is exposed in actual status projection")

func textures() -> void:
	for id in IDS:
		var tile := preload("res://scripts/ui/card_face.gd").new()
		tile.data = Content.card_def(id); tile.refresh_art()
		check(tile._original_card != null and tile._original_card.resource_path == "res://assets/official/cards/"+id+".png","actual texture loads original "+id)
		tile.free()

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["huoqumo","yuanjiulanghu","rihefang","taohuayao"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],204205)
		b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var p: Dictionary = b.gs.player(0)
		hand(b,["c20502"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.pending_choice.get("type") == "rp-fox-mode" and choice_face(b,RP.FOX_HEAL) != null,"native fox mode is a real selectable option")
		await capture("%d-01-fox-mode" % physical.x)
		if choice_face(b,RP.FOX_HEAL) != null: await click(choice_face(b,RP.FOX_HEAL)); await settled(b)
		check(b.gs.pending_choice.get("type") == "rp-fox-target" and choice_face(b,"avatar-0") != null,"native target stage exposes actual avatar")
		if choice_face(b,"avatar-0") != null: await click(choice_face(b,"avatar-0")); await settled(b)
		check(p.avatarArmor == 3 and b.gs.pending_choice.is_empty(),"native full-health avatar gains true overflow armor")
		b.gs._grow_unit(p.units[0],10,0); hand(b,["c20404"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size() == 1 and p.realms[0].hp == 6,"native red realm actually installs")
		hand(b,["c20502"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		if choice_face(b,RP.FOX_REALM) != null: await click(choice_face(b,RP.FOX_REALM)); await settled(b)
		check(b.gs.pending_choice.get("type") == "rp-fox-target" and choice_face(b,p.realms[0].uid) != null,"native durability selection shows actual installed realm")
		await capture("%d-02-realm-choice" % physical.x)
		if choice_face(b,p.realms[0].uid) != null: await click(choice_face(b,p.realms[0].uid)); await settled(b)
		check(p.realms[0].hp == 9,"native realm selection changes its true durability")
		var target: Dictionary = p.units[2]; var base_attack := int(target.attack); var base_hp := int(target.maxHp)
		knock(b.gs,0,2); hand(b,["c20505"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(target.uid).selected,"native drum highlights knocked legal target")
		await capture("%d-03-revival-target" % physical.x)
		await click(b._unit_widget(target.uid)); await settled(b)
		check(target.hp > 0 and target.attack == base_attack+1 and target.maxHp == base_hp+1 and target.shield == 1 and target.front == 0,"native mixed-team revival resolves all basic bonuses without wrong movement")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	content_and_passives(); awakening_auras(); red_forms_and_encourage(); sword_keywords(); fox_choice_and_heal(); fox_guard_revival_and_journey(); max_realms_resets_and_ai()
	if not only: textures(); await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("RED_PURPLE_OK checks=%d failures=%d rules_only=%s" % [checks,failures,only])
	quit(0 if failures == 0 else 1)
