extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Garuda := preload("res://scripts/garuda_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("GARUDA_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["jialouluo","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],277)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true; p.avatarArmor = 0
		for u in p.units:
			u.level = 3
			if u.has("abilityCountdown"): u.abilityCountdown.remaining = 2
	gs.rule_events.clear()
	return gs
func instance(gs, id: String) -> Dictionary:
	var inst := {"definitionId": id, "instanceId": "garuda-fixture-%d" % gs.next_card_id}; gs.next_card_id += 1; return inst
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(instance(gs,id)); return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actualuse "+id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)
func reduce(gs, amount: int = 1) -> void:
	gs.VerifiedRules.reduce_countdown(gs,0,0,amount,0); gs._resolve_resolution_stack()
func knock(gs, owner: int, idx: int) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0); gs._resolve_resolution_stack()
func wings_and_awakening() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	check(u.attack == 2 and u.maxHp == 4 and u.passive_hooks.is_empty(),"base2/4 and oldturngrowthremoved")
	check(u.abilityCountdown.remaining == 2 and u.abilityCountdown.reset == 2,"realabilitycountdown2initializes")
	reduce(gs); check(u.abilityCountdown.remaining == 1 and not u.get("swift",false) and not u.get("inspired",false),"firstreductionnotfakewings")
	reduce(gs); check(u.abilityCountdown.remaining == 2 and u.swift and u.inspired and u.attack == 2,"timerzeroresets2andgrantsrealkeywordswithoutgrowth")
	p.energy = 0; p.attackUsed = true; check(gs.can_basic_attack(0,0).ok and gs.basic_attack(0,0),"wingspermitrealzeroenergyextraordinarydeployment")
	check(not u.swift and not u.has("inspired") and p.attackUsed and p.energy == 0,"deploymentconsumeswingsbutdoesnotresetordinarycount")
	check(not gs.can_basic_attack(0,0).ok,"spentwingscannotbeusedagain")
	u.abilityCountdown.remaining = 1; p.energy = 40; play(gs,"c27706")
	check(u.awakened and u.attack == 3 and u.maxHp == 5 and u.abilityCountdown.remaining == 1 and u.abilityCountdown.mode == "awakened","awakeningexact+1/+1replacesmodewithoutfabricatingreset")
	check(events(gs,"garuda-feather-attached").size() == 1,"awakeningrandomlymarksoneactualenemy")
	reduce(gs); check(events(gs,"garuda-feather-attached").size() == 2 and u.swift and u.inspired,"awaketimergrantsbothkeywordsandactualrandommark")
	check(not gs.can_play_card(0,give(gs,"c27706")).ok,"awakeningcannotrepeat")
	knock(gs,0,0); check(u.hp == 0 and u.knockout == 2 and u.abilityCountdown.remaining == 2,"realdeathseparatesKOtimerandabilityreset")
	gs.VerifiedRules.Peach.revive(gs,0,1,u,false,false); gs._resolve_resolution_stack(); reduce(gs,2)
	check(u.hp > 0 and u.awakened and u.abilityCountdown.mode == "awakened" and u.swift and u.inspired,"revivedawakeusesactualawakeability")
	gs = game(); p = gs.player(0); u = p.units[0]; u.level = 0; reduce(gs,2)
	check(u.abilityCountdown.remaining == 2 and not u.get("inspired",false),"inactiveabilitydoesnottickorgrantkeywords")
	u.level = 3; u.frozen = 1; reduce(gs,2)
	check(u.swift and u.inspired and not gs.can_basic_attack(0,0).ok,"passivetimercangrantkeywordsbutneverbypassstun")
func feather_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var target: Dictionary = foe.units[1]
	play(gs,"c27702",target.uid); check(target.has("garudaFeather") and p.units[0].abilityCountdown.remaining == 1,"wingbladeinstantrealcharmthenreducescountdown")
	var serial: int = target.garudaFeather.serial; play(gs,"c27702",target.uid)
	check(target.garudaFeather.serial != serial and p.units[0].swift and p.units[0].inspired,"reapplyreplacesonecharmandsecondreductiontriggerswings")
	var hp: int = target.hp; var face: int = foe.avatarHp; p.units[0].spellPower = 7; var fire: int = p.energy
	check(gs.basic_attack(0,0) and target.hp == hp-2 and not target.has("garudaFeather") and foe.avatarHp == face-2,"commandeddeploymentfiresfixed2thenordinaryattack")
	check(events(gs,"garuda-feather-hit").size() == 1 and p.energy == fire,"nonstackingcharmhitsonceandwingsfreebasic")
	check(not p.attackUsed,"realinspiredpreservesordinarycount")
	gs = game(); p = gs.player(0); foe = gs.player(1); target = foe.units[1]; Garuda.attach(gs,0,0,target); hp = target.hp
	gs.basic_attack_ex(0,0,0,false); gs._resolve_resolution_stack()
	check(target.hp == hp and target.has("garudaFeather"),"forcedattackisnotcommandeddeployment")
	play(gs,"c27708"); check(target.hp == hp and target.has("garudaFeather"),"manualcombatcarddoesnotfirefeather")
	p.units[0].inspired = true; check(gs.basic_attack(0,0) and target.hp == hp-2 and not target.has("garudaFeather"),"skilldeploymentstillfiresfeatherbeforecard")
	gs = game(); foe = gs.player(1); target = foe.units[1]; target.barrier = true; Garuda.attach(gs,0,0,target); hp = target.hp
	gs.basic_attack(0,0); check(target.hp == hp and not target.barrier and not target.has("garudaFeather"),"barrierabsorbs2buthitstillremovescharm")
	gs = game(); foe = gs.player(1); target = foe.units[1]; target.hp = 2; Garuda.attach(gs,0,0,target); gs.basic_attack(0,0)
	check(target.hp == 0 and target.knockout == 2 and not target.has("garudaFeather"),"featherreallykillsandKOclearscharm")
	gs = game(); foe = gs.player(1)
	for idx in [0,1,2]: Garuda.attach(gs,0,0,foe.units[idx])
	var hps: Array = foe.units.map(func(u): return int(u.hp)); gs.basic_attack(0,0)
	for idx in [0,1,2]: check(foe.units[idx].hp == hps[idx]-2 and not Garuda.marked(foe.units[idx]),"allactualmarkedhostshitonce "+str(idx))
	check(foe.units[3].hp == hps[3] and events(gs,"garuda-feather-hit").size() == 3,"unmarkedhostnotinventedtarget")
	gs = game(); foe = gs.player(1); Garuda.attach(gs,0,0,foe.units[0]); gs.current_player = 1
	gs.VerifiedRules.PipeFox.cleanse(gs,1,3); check(not Garuda.marked(foe.units[0]),"whitefoxcanactuallycleanseenemyfeather")
	Garuda.attach(gs,0,0,foe.units[1]); gs.VerifiedRules.Moon.full_moon(gs,foe.units[1]); check(not Garuda.marked(foe.units[1]),"fullmoonactualallcharmremovalincludesfeather")
func skill_combats() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]; foe.units[0].front = 1
	var hp: int = foe.units[0].hp; var face: int = foe.avatarHp; play(gs,"c27701",foe.units[1].uid)
	check(foe.avatarHp == face-2 and foe.units[0].hp == hp and Garuda.marked(foe.units[1]),"directhandcardmarkschosenreserveandgenuinelybypassesfront")
	check(not p.attackUsed and u.battleSkillId == "c27701","manualcombatinstallsabilitywithoutordinarycount")
	check(gs.basic_attack_targets(0,0) == ["avatar-1"] and not gs.VerifiedRules.BattleSkill.requires_target(gs,0,0),"storedhandonlymarkdoesnotrequireanewseal-targetanddirecthighlightsface")
	face = foe.avatarHp; hp = foe.units[1].hp; var fire: int = p.energy
	check(not gs.basic_attack(0,0,p.units[1].uid) and p.energy == fire,"storedskillrejectsillegalfriendtargetwithoutpayment")
	gs._apply_encourage(0,3,2)
	check(gs.basic_attack(0,0,"avatar-1") and foe.avatarHp == face-5 and foe.units[1].hp == hp-2,"storedcombatgetsrealencourageandpredeploymentfeather")
	check(not Garuda.marked(foe.units[1]) and events(gs,"garuda-feather-attached").size() == 1,"abilitycastneverrepeatsfromhandonlyattachment")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; foe.units[0].front = 1; hp = foe.units[0].hp
	play(gs,"c27704"); check(foe.units[0].hp == hp-4 and u.hp == 4,"halberdexact+2andimmunecombatbeforeenhancement")
	var idx := give(gs,"c27704"); check(gs.hand_card_def(0,idx).target == "auto","no-featherhalberdhasnoinventedpursuit")
	Garuda.attach(gs,0,0,foe.units[1]); var view := gs.hand_card_def(0,idx)
	check(view.target == "enemy-unit" and view.combatOption.pursuit and view.keywords.has("pursuit"),"featherdynamicallyenhancesrealpursuit")
	hp = foe.units[2].hp; check(gs.play_card(0,idx,foe.units[2].uid) and foe.units[2].hp == hp-4 and u.hp == 4,"enhancedhalberdselectsreserveactualtargetandstaysimmune")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; play(gs,"c27704"); Garuda.attach(gs,0,0,foe.units[0]); hp = foe.units[2].hp
	check(gs.basic_attack(0,0,foe.units[2].uid) and foe.units[2].hp == hp-4,"skillfreezeslegalenhancementbeforefeatherconsumesitscondition")
	check(not Garuda.marked(foe.units[0]),"precombatfeatherdoesnotpersisttofakeenhancement")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; foe.units[0].front = 1; hps_reset(gs)
	var allhp: Array = foe.units.map(func(enemy): return int(enemy.hp)); var ownhp: int = u.hp; play(gs,"c27705")
	for i in foe.units.size(): check(foe.units[i].hp == allhp[i]-(3 if i == 0 else 1),"breathallactualenemy1thenremotecombatfront "+str(i))
	check(u.front == 0 and u.hp == ownhp,"breathremoteneverentersfrontortakescounterdamage")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; u.abilityCountdown.remaining = 1; face = foe.avatarHp
	play(gs,"c27708"); check(foe.avatarHp == face-4 and u.shield == 1 and u.swift and u.inspired and u.abilityCountdown.remaining == 2,"sprintreal+2/+1andtimerresolutiongrantskeywords")
	u.abilityCountdown.remaining = 1; p.attackUsed = true; p.energy = 0; face = foe.avatarHp
	check(gs.basic_attack(0,0) and foe.avatarHp == face-4 and u.swift and u.inspired,"sprintskillspendsoldwingsanditsrealreductiongrantsnewones")
	face = foe.avatarHp; check(gs.basic_attack(0,0) and foe.avatarHp == face-2 and events(gs,"battle-skill-used").size() == 1,"same-turnnextwingsareordinaryattacknotrepeatedskillbug")
func hps_reset(gs) -> void:
	for u in gs.player(1).units: gs._grow_unit(u,0,8)
func forms_and_return() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs,"c27703"); check(u.attack == 2 and u.maxHp == 5 and not foe.units.any(func(enemy): return Garuda.marked(enemy)),"wingform2/5hasnoinventedentrymark")
	Garuda.form_turn_start(gs,0,0); check(events(gs,"garuda-feather-attached").size() == 1,"realformturnstartmarksoneactualenemy")
	gs = game(); p = gs.player(0); u = p.units[0]; var idx := give(gs,"c27707"); var iid: String = p.hand[idx].instanceId; var fire: int = p.energy
	check(gs.basic_attack(0,0) and u.form.cardId == "c27707" and u.attack == 5 and u.maxHp == 5 and p.hand.is_empty(),"nativeSSRauto-consumesactualheldinstancebeforeattack")
	check(p.energy == fire-1 and gs.VerifiedRules.Combat.has(u,"veil"),"automaticformfreebeyonddeploymentandgrantsrealveil")
	u.shield = 3; u.frozen = 1; u.armorBreak = 1; u.enraged = true; u.untilAttack = {"attack":8}; gs._recalc(u)
	var timer: int = u.abilityCountdown.remaining; knock(gs,0,0)
	check(u.hp == 4 and u.maxHp == 4 and u.attack == 2 and u.front == 1 and u.knockout == 0 and u.form.is_empty(),"substituterestoresoriginalbodywithoutrealKOorrevival")
	check(u.shield == 0 and u.armorBreak == 0 and u.frozen == 0 and not u.has("untilAttack") and not u.has("enraged"),"substituteremovestemporarybodyandstatuses")
	check(u.abilityCountdown.remaining == timer and events(gs,"garuda-form-returned").size() == 1,"substitutedoesnotresetabilitytimerbutdoesdepartform")
	check(p.hand.size() == 1 and p.hand[0].instanceId == iid,"leavingSSRreturnssamephysicalinstanceonce")
	knock(gs,0,0); check(u.hp == 0 and u.knockout == 2 and p.hand.size() == 1,"originalbodyseconddeathisrealKOwithoutanotherreturn")
	gs = game(); p = gs.player(0); u = p.units[0]; idx = give(gs,"c27707"); iid = p.hand[idx].instanceId; check(gs.play_card(0,idx),"manualSSRrealuse")
	play(gs,"c27703"); check(u.form.cardId == "c27703" and p.hand.size() == 1 and p.hand[0].instanceId == iid,"replacingSSRreturnsoriginalcardandinstallsnewform")
	gs = game(); p = gs.player(0); play(gs,"c27703"); give(gs,"c27707"); check(gs.basic_attack(0,0) and p.hand.size() == 1 and p.units[0].form.cardId == "c27703","existingformblocksSSRauto-usewithoutconsumingit")
	gs = game(); p = gs.player(0); p.units[0].level = 2; give(gs,"c27707"); check(gs.basic_attack(0,0) and p.hand.size() == 1 and p.units[0].form.is_empty(),"below3cannotauto-useSSR")
	gs = game(); p = gs.player(0); give(gs,"c27707"); p.units[0].frozen = 1; fire = p.energy
	check(not gs.basic_attack(0,0) and p.hand.size() == 1 and p.energy == fire,"stunnedrejecteddeploymentcannotconsumeSSR")
	gs = game(); p = gs.player(0); u = p.units[0]; play(gs,"c27706"); play(gs,"c27707"); knock(gs,0,0)
	check(u.hp == 5 and u.attack == 3 and u.awakened and u.abilityCountdown.mode == "awakened","substitutepreservesactualpermanentawakening")
	gs = game(); p = gs.player(0); play(gs,"c27707"); p.hand.clear()
	for n in int(gs.rules.maxHandSize): give(gs,"c11902")
	gs.VerifiedRules.Forms.remove(gs,0,0,"testfullhand"); gs._resolve_resolution_stack()
	check(p.hand.size() == int(gs.rules.maxHandSize) and events(gs,"garuda-form-returned").size() == 1,"fullhandburnsreturnwithoutduplicatingoroverflow")
func ai_and_source_boundaries() -> void:
	for n in range(1,9):
		var gs := game(); var id := "c277%02d" % n; give(gs,id); var best := AI._best_card(gs,0)
		check(best.ok and best.card_id == id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualuse "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"fulloriginalPNG "+id)
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs,"c27701",foe.units[0].uid); var chosen := AI._best_attack(gs,0)
	check(chosen.ok and chosen.unit == 0 and chosen.target == "avatar-1" and gs.basic_attack(0,0,chosen.target),"AIactualdirectskillselectslegalface")
	gs = game(); p = gs.player(0); foe = gs.player(1); gs._deploy_realm(0,Content.card_def("c17007")); p.deck = [instance(gs,"c27701")]; var hp: int = p.avatarHp
	check(gs.hand_card_def(0,0).sourceZone == "deck" and gs.hand_card_def(0,0).target == "auto","decktopdirectcarddoesnotpretendfromhandmark")
	check(gs.play_card(0,0) and not foe.units.any(func(enemy): return Garuda.marked(enemy)) and p.avatarHp == hp-2,"actualvoyageusepaysdecktaxbutnofakehandattachment")
	gs = game(); p = gs.player(0); foe = gs.player(1); give(gs,"c27702"); var stamp := JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0); gs.VerifiedRules.BattleSkill.ready(gs,0,0)
	check(JSON.stringify(gs.snapshot()) == stamp,"cardandabilityqueriesarepure")
	var idx := give(gs,"c27702"); var fire: int = p.energy; check(not gs.play_card(0,idx,p.units[1].uid) and p.energy == fire and p.hand.size() == 2,"foreignmarktargetrejectedwithoutresources")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27701",foe.units[0].uid); p.nullifyNextCardTurn = gs.turn_counter; var face: int = foe.avatarHp
	check(gs.basic_attack(0,0) and foe.avatarHp == face and not Garuda.marked(foe.units[0]) and p.attackUsed,"counteredskillstillpermitsindependentpredeploymentcharmhitbutcancelscombat")
	check(events(gs,"card-nullified").size() == 1,"skillusesrealcounterwindow")
func boundaries_and_live_turns() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs,"c27703")
	check(gs.end_turn(0),"actualturnendtoopponent")
	gs.player(1).levelUpUsed = true; check(gs.end_turn(1),"actualopponentendbacktoowner")
	check(u.abilityCountdown.remaining == 1 and events(gs,"garuda-feather-attached").size() == 1,"realownerturnstarttickstimerandformmark")
	p.levelUpUsed = true; check(gs.end_turn(0),"actualsecondopponentturn")
	gs.player(1).levelUpUsed = true; check(gs.end_turn(1),"actualsecondownerturn")
	check(u.abilityCountdown.remaining == 2 and u.swift and u.inspired and events(gs,"garuda-wings").size() == 1,"secondrealownerturntriggersexactcountdown2")
	check(events(gs,"garuda-feather-attached").size() == 2,"formactuallytriggersateachownerstart")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	for target in foe.units: target.hp = 0; target.knockout = 2
	var idx := give(gs,"c27701"); var view := gs.hand_card_def(0,idx)
	check(view.target == "auto" and gs.play_card(0,idx) and foe.avatarHp == 28,"handdirectcombatstillusablewhennoenemyshikigamitomark")
	gs = game(); p = gs.player(0); foe = gs.player(1); give(gs,"c27707"); p.energy = 1
	check(gs.basic_attack(0,0) and p.units[0].form.cardId == "c27707" and p.energy == 0,"onlyoneghostsufficesforactualautomaticSSR")
	var Status := preload("res://scripts/ui/battle_status.gd")
	var view_unit: Dictionary = Status.unit_view(gs,0,0,0)
	check(Status.unit_marks(view_unit,gs.turn_counter).any(func(m): return m.label.contains("替身")),"genericformsubstitutestatusisvisible")
	gs = game(); p = gs.player(0); foe = gs.player(1); gs._deploy_realm(0,Content.card_def("c17007")); p.deck = [instance(gs,"c27707")]
	check(gs.basic_attack(0,0) and p.units[0].form.is_empty() and p.deck.size() == 1,"SSRautomatictriggerconsumesrealhandonlynevervoyagedecktop")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]
	play(gs,"c27704"); Garuda.attach(gs,0,0,foe.units[1]); foe.units[1].hp = 2; var face: int = foe.avatarHp
	check(gs.basic_attack(0,0,foe.units[1].uid) and foe.units[1].hp == 0 and foe.avatarHp == face,"predeploymentfeatherkillsselectedpursuittargetwithoutinventingfacefallback")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	Garuda.attach(gs,0,0,foe.units[1]); var before: Dictionary = gs.snapshot(); gs.basic_attack(0,0)
	var Cues := preload("res://scripts/ui/battle_effect_cues.gd")
	var cues: Array = Cues.damage_cues(before,gs.snapshot())
	check(cues.any(func(c): return c.cardId == "garuda-feather" and c.target == foe.units[1].uid and c.amount == 2),"UIusesactualseparatefeatherdamagepacket")
	gs = game(); foe = gs.player(1); foe.units[1].barrier = true; Garuda.attach(gs,0,0,foe.units[1]); before = gs.snapshot(); gs.basic_attack(0,0)
	cues = Cues.damage_cues(before,gs.snapshot())
	check(cues.any(func(c): return c.cardId == "garuda-feather" and c.target == foe.units[1].uid and c.amount == 0 and c.kind == "guard"),"blockedfeatherpacketneverpretends2actualHPdamage")
	gs = game(); p = gs.player(0); foe = gs.player(1); hps_reset(gs); foe.units[0].front = 1; before = gs.snapshot(); play(gs,"c27705")
	cues = Cues.damage_cues(before,gs.snapshot())
	check(cues.filter(func(c): return c.cardId == "c27705" and c.amount == 1).size() == 4,"UIkeepsall4actualbreathAOEpacketsseparatefromcombat")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["jialouluo","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],277); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for u in side.units:
				u.level = 3
				if u.has("abilityCountdown"): u.abilityCountdown.remaining = 2
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
		hps_reset(gs)
		hand(b,["c27702","c27704"]); await settled(b); var fire: int = p.energy
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._pending_target_card == 0 and p.energy == fire,"nativewingbladerejectsallywithoutpayment")
		escape(); await process_frame; check(b._pending_target_card == -1,"nativeEscapecancelsmarkselection")
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(Garuda.marked(foe.units[0]) and u.abilityCountdown.remaining == 1 and p.energy == fire,"nativewingbladeactualmarkandinstantandcountdown")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and gs.hand_card_def(0,0).combatOption.pursuit,"nativehalberdcurrentenhancementopensrealpursuittargetUI")
		await capture("%d-01-feather-pursuit-target" % physical.x)
		var hp: int = foe.units[1].hp
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(foe.units[1].hp == hp-4 and u.hp == 4 and u.battleSkillId == "c27704","nativeselectedreservecombatreallyhitsandimmune")
		gs._heal_unit(foe.units[1],foe.units[1].maxHp); hand(b,["c27707"]); await settled(b); var iid: String = p.hand[0].instanceId; fire = p.energy
		await click(b._unit_widget(str(u.uid))); await settled(b); await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(u.form.cardId == "c27707" and p.hand.is_empty() and p.energy == fire-1,"nativeskilldeploymentauto-usesactualSSRbeforecombat")
		knock(gs,0,0); b._refresh(); await settled(b)
		check(u.hp == 4 and u.front == 1 and u.knockout == 0 and u.form.is_empty() and p.hand.size() == 1 and p.hand[0].instanceId == iid,"nativeactualsubstituteandoriginalcardreturnvisible")
		check(b._hand_row.get_child(0).data.id == "c27707","nativereturnedSSRactualhandwidget")
		await capture("%d-02-substitute-original-return" % physical.x)
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var rules_only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	wings_and_awakening(); feather_rules(); skill_combats(); forms_and_return(); ai_and_source_boundaries(); boundaries_and_live_turns()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("GARUDA_OK checks=%d failures=%d rules_only=%s" % [checks,failures,rules_only]); quit(0 if failures == 0 else 1)
