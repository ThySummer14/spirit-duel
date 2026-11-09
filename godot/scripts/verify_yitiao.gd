extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Yitiao := preload("res://scripts/yitiao_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("YITIAO_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["yitiao","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],276)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true; p.avatarArmor = 0
		for u in p.units: u.level = 3
	gs.rule_events.clear()
	return gs
func instance(gs, id: String) -> Dictionary:
	var inst := {"definitionId": id, "instanceId": "yitiao-test-%d" % gs.next_card_id}; gs.next_card_id += 1; return inst
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(instance(gs,id)); return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actualuse "+id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)
func knock(gs, owner: int = 0, idx: int = 0) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0); gs._resolve_resolution_stack()
func upgrade_gifts() -> void:
	var fresh := GS.create(["yitiao","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],276)
	check(fresh.player(0).hand.filter(func(h): return h.definitionId == Yitiao.TRAINING).size() == 1,"initial0to1activationisrealupgradegift")
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	check(u.attack == 2 and u.maxHp == 5 and u.passive_hooks.is_empty(),"original2/5andnofakefrontturngrowth")
	check(not u.has("battleSkillId"),"unitdoesnotstartwithinventedwarskill")
	u.level = 1; p.levelUpUsed = false
	check(gs.level_up(0,0) and u.level == 2 and p.hand.size() == 1,"actualupgradecreatesonephysicaltraining")
	check(gs.hand_card_def(0,0).id == Yitiao.TRAINING and gs.hand_card_def(0,0).value == 0,"generated1levelcombat0/0isrealdefinition")
	gs.raise_unit_level(0,0); gs._resolve_resolution_stack()
	check(u.level == 3 and p.hand.size() == 2 and p.hand[0].instanceId != p.hand[1].instanceId,"eachactualupgradeuniqueinstance")
	gs.raise_unit_level(0,0); check(p.hand.size() == 2,"failedmaxupgradecannotfabricategift")
	knock(gs); u.level = 1; gs.raise_unit_level(0,0); gs._resolve_resolution_stack()
	check(u.hp == 0 and u.level == 2 and p.hand.size() == 3,"upgradegiftworkswhileKOwithoutreviving")
	p.hand.clear()
	for i in int(gs.rules.maxHandSize): give(gs,"c11902")
	Yitiao.upgraded(gs,0,0)
	check(p.hand.size() == int(gs.rules.maxHandSize) and events(gs,"yitiao-training-created").back().burned,"fullhandburnsgeneratedcardwithoutoverflow")
	gs = game()
	p = gs.player(0)
	u = p.units[0]
	u.level = 1
	gs.VerifiedRules.Fortune.transform(gs, 0, 0, false)
	gs.raise_unit_level(0, 0)
	gs._resolve_resolution_stack()
	check(u.level == 2 and p.hand.is_empty(), "一条在纸人变形时正常升级，但基础能力不产生勤勉修行")
func persistent_skill() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	var face: int = foe.avatarHp; play(gs,Yitiao.TRAINING)
	check(u.battleSkillId == Yitiao.TRAINING and u.yitiaoSkillBonus == 1 and u.yitiaoSkillUses == 1,"handtraininginstallsandgrowsledgeronce")
	check(u.attack == 2 and u.shield == 0 and foe.avatarHp == face-2,"handgrowthdoesnotbecomebodyorcurrentmanualarmor")
	var skill: Dictionary = gs.VerifiedRules.BattleSkill.ready(gs,0,0)
	check(skill.value == 1 and skill.combatOption.shield == 1,"realabilityviewcontainsledgerbonus")
	face = foe.avatarHp; var fire: int = p.energy
	check(gs.basic_attack(0,0) and foe.avatarHp == face-3 and u.shield == 1 and p.energy == fire-1,"firstdeploymentrealcombat+1/+1andonepayment")
	check(u.yitiaoSkillBonus == 1 and u.yitiaoSkillUses == 2 and events(gs,"battle-skill-installed").size() == 1,"abilitycountsactualusewithoutnewhandgrowthorreinstall")
	u.inspired = true; face = foe.avatarHp
	check(gs.basic_attack(0,0) and foe.avatarHp == face-2 and u.yitiaoSkillUses == 2,"subsequentdeploymentordinarynotanotherwarskill")
	knock(gs)
	check(u.hp == 0 and u.battleSkillId == Yitiao.TRAINING and u.yitiaoSkillBonus == 1 and u.yitiaoSkillUses == 2,"actualKOretainsabilityledgerandmatchcount")
	gs.VerifiedRules.Peach.revive(gs,0,3,u,false,false); gs.turn_counter += 2; p.attackUsed = false
	check(gs.VerifiedRules.BattleSkill.ready(gs,0,0).value == 1,"revivedunitstillhasoriginalrealwarskill")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; u.level = 2
	play(gs,"c27601"); check(u.yitiaoSkillBonus == 2 and u.attack == 2 and u.shield == 0,"SSRactuallevel2growthnotold+3/+3approximation")
	play(gs,Yitiao.TRAINING); check(u.yitiaoSkillBonus == 3 and u.battleSkillId == Yitiao.TRAINING,"switchingwarskillretainscumulativebonus")
	play(gs,"c27601"); check(u.yitiaoSkillBonus == 5 and u.battleSkillId == "c27601","switchbackSSRkeepsallpriorgrowth")
	face = foe.avatarHp; gs.basic_attack(0,0)
	check(foe.avatarHp == face-7 and u.shield == 5 and u.yitiaoSkillBonus == 5,"SSRskillappliesentire5/5withoutrepeatingfromhandgrowth")
func pursuit_and_forms() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs,"c27601"); gs._grow_unit(foe.units[1],0,8); foe.units[0].front = 1
	var idx := give(gs,"c27602"); var card: Dictionary = gs.hand_card_def(0,idx); var fire: int = p.energy; var hp: int = foe.units[1].hp
	check(card.value == 3 and card.combatOption.shield == 3 and gs.valid_targets(0,card).has(foe.units[1].uid),"pursuitdynamic3/3reserveactuallegalchoice")
	check(not gs.play_card(0,idx,p.units[1].uid) and p.energy == fire,"pursuitinvalidallycostsnothing")
	check(gs.play_card(0,idx,foe.units[1].uid) and foe.units[1].hp == hp-5 and u.battleSkillId == "c27601" and u.yitiaoSkillUses == 1,"pursuitactuallyhitsreservebutdoesnotreplace/countwarskill")
	gs = game(); p = gs.player(0); u = p.units[0]; play(gs,"c27603")
	check(u.attack == 2 and u.maxHp == 6 and p.hand.size() == 1,"guardreal2/6andentrytraining")
	play(gs,Yitiao.TRAINING); play(gs,Yitiao.TRAINING); var uses: int = u.yitiaoSkillUses
	check(u.attack == 2 and gs.end_turn(0),"guardhasnobonusonownturn")
	check(u.attack == 2+uses,"guardenemyturnpowerusesactualwarskillcount")
	gs.player(1).levelUpUsed = true; check(gs.end_turn(1) and u.attack == 2,"guardbonusendsatrealownturnboundary")
	p.levelUpUsed = true; p.energy = 40; play(gs,"c27604")
	check(u.attack == 4 and u.maxHp == 5 and p.hand.size() >= 1,"attackformreal4/5andentrytraining")
	idx = give(gs,Yitiao.TRAINING); fire = p.energy
	check(gs.hand_card_def(0,idx).keywords.has("instant") and gs.effective_card_cost(0,gs.hand_card_def(0,idx)) == 0,"attackformtraininginstantactualpaymentview")
	check(gs.play_card(0,idx) and p.energy == fire,"attackformfirstcombatcostszeroghost")
	idx = give(gs,"c27602"); check(gs.hand_card_def(0,idx).keywords.has("instant") and gs.effective_card_cost(0,gs.hand_card_def(0,idx)) == 1,"instantnotunlimitedsecondfreecard")
	play(gs,"c27603"); check(not gs.hand_card_def(0,idx-1).keywords.has("instant"),"leavingattackformremovesdynamicinstant")
func alone_and_stance() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs,"c27605"); check(u.attack == 4 and u.unyielding and gs.VerifiedRules.Combat.has(u,"pierce"),"aloneactual2powerunyieldingandpierce")
	foe.units[1].front = 1; foe.units[1].hp = 1; var face: int = foe.avatarHp
	check(gs.basic_attack(0,0) and foe.avatarHp == face-3,"alonepierceactualoverflowtoavatar")
	gs._damage_unit(0,0,100,1,0); check(u.hp == 1 and not u.unyielding,"aloneunyieldingsavesonce")
	knock(gs); check(u.attack == 2 and not gs.VerifiedRules.Combat.has(u,"pierce") and not u.unyielding,"KOclearsonlytemporaryalonebodyandkeywords")
	for chosen in Yitiao.CHOICES:
		gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; p.avatarHp = 12
		play(gs,"c27607"); check(u.attack == 2 and u.maxHp == 6 and gs.pending_choice.type == "yitiao-stance","iiaireal2/6opensmandatorytwochoices")
		var stamp := JSON.stringify(gs.snapshot()); check(not gs.resolve_divination_choice(1,chosen) and not gs.resolve_divination_choice(0,"foreign") and JSON.stringify(gs.snapshot()) == stamp,"foreignownerandforgedbranchrejectedpurely")
		check(gs.resolve_divination_choice(0,chosen) and gs.pending_choice.is_empty(),"selectedactualiiaibranch "+chosen)
		face = foe.avatarHp; check(gs.basic_attack(0,0),"iiaideployment")
		check(foe.avatarHp == face-(4 if chosen == Yitiao.CHOICES[1] else 2) and p.avatarHp == (14 if chosen == Yitiao.CHOICES[0] else 12),"chosenbranchrealcriticalorlifestealwithoutfakehealself")
		face = foe.avatarHp; var avatar: int = p.avatarHp; play(gs,Yitiao.TRAINING)
		check(foe.avatarHp == face-2 and p.avatarHp == avatar,"manualcombatdoesnotpretendcommandeddeployment")
		gs.turn_counter += 2; p.attackUsed = false; face = foe.avatarHp; avatar = p.avatarHp; gs.basic_attack(0,0)
		check(foe.avatarHp == face-(6 if chosen == Yitiao.CHOICES[1] else 3) and p.avatarHp == avatar+(3 if chosen == Yitiao.CHOICES[0] else 0),"chosenbranchalsoworksonactualwarskilldeployment")
func cover_response() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs,"c27601"); var bonus: int = u.yitiaoSkillBonus; var fire: int = p.energy; var face: int = foe.avatarHp
	play(gs,"c27606")
	check(p.energy == fire-1 and foe.avatarHp == face-2 and u.barrier,"manualcoverbarrierandactualfreeautomatic0/0trainingcombat")
	check(u.battleSkillId == Yitiao.TRAINING and u.yitiaoSkillBonus == bonus and u.yitiaoSkillUses == 2,"automatictrainingreplacesoldwarskillandcountsbutneverhandgrowth")
	check(p.hand.is_empty() and events(gs,"automatic-card").size() == 1,"automatictrainingnotfakephysicalgiftoradditionalfirepayment")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; p.units[1].front = 1; give(gs,"c27606"); gs.current_player = 1
	gs._grow_unit(foe.units[0],0,10); var attacker_hp: int = foe.units[0].hp; hp_setup(gs); fire = p.energy
	var ally_hp: int = p.units[1].hp; var own_hp: int = u.hp
	check(gs.basic_attack(1,0),"enemyactualbasictriggerscover")
	check(p.units[1].hp == ally_hp and u.front == 1 and p.units[1].front == 0,"pendingoriginalattackretargetsactualyitiaofrontnotoldally")
	check(foe.units[0].hp == attacker_hp-4 and u.hp == own_hp-int(foe.units[0].attack),"realautomatictrainingcombatthenoriginalcounterareseparate2hits")
	check(p.energy == fire-1 and p.hand.is_empty() and int(u.get("yitiaoSkillBonus",0)) == 0 and u.battleSkillId == Yitiao.TRAINING,"responseonefireconsumesphysicalspellnottraininggrowth")
	check(events(gs,"yitiao-cover").size() == 1 and events(gs,"combat-hit").size() == 2,"responsecontinuationexactlytwoactualcombats")
	for boundary in ["self","no-fire","stunned","below-level","KO","own-turn","locked"]:
		gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; give(gs,"c27606"); p.units[1].front = 1; gs.current_player = 1
		match boundary:
			"self": p.units[1].front = 0; u.front = 1
			"no-fire": p.energy = 0
			"stunned": u.frozen = 1
			"below-level": u.level = 1
			"KO": knock(gs)
			"own-turn": gs.current_player = 0
			"locked": foe.units[0].formRules = {"lockEnemyFrontReplacement":true}; foe.units[0].front = 1
		if boundary == "own-turn":
			check(not gs.VerifiedRules.automatic_response(gs,0,"unit-attacked",p.units[1].uid,{"kind":"response-complete"}),"ownturnnoautomaticcover")
		elif boundary == "locked":
			check(gs.VerifiedRules.Bingyong.replacement_blocked(gs,0,u) and not gs.VerifiedRules.automatic_response(gs,0,"unit-attacked",p.units[1].uid,{"kind":"response-complete"}),"actualdustarrayblockscoverbeforepayment")
		else: gs.basic_attack(1,0)
		check(events(gs,"yitiao-cover").is_empty() and p.hand.size() == 1,"covernegativeboundary "+boundary)
func hp_setup(gs) -> void:
	gs._grow_unit(gs.player(0).units[0],0,10)
func awakening_and_sources() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs,Yitiao.TRAINING); var bonus: int = u.yitiaoSkillBonus; knock(gs); play(gs,"c27608")
	check(u.hp == 0 and u.awakened and u.attack == 6 and u.maxHp == 5,"awakeningwhileKOexact4/0doesnotrevivebyitself")
	var idx := give(gs,"c27602"); var view: Dictionary = gs.hand_card_def(0,idx); var face: int = foe.avatarHp; var fire: int = p.energy
	check(view.yitiaoReviveReplacement and view.target == "auto" and view.effects.size() == 1 and view.effect == "yitiao-revive","KOcombatfullyreplacedandnopupursuittargetUI")
	p.units[1].front = 1; check(gs.play_card(0,idx) and u.hp == 5 and u.knockout == 0 and u.front == 0,"KOcombatrealrevivewithoutmovingexistingfront")
	check(u.shield == 0 and u.yitiaoSkillBonus == bonus and foe.avatarHp == face and p.energy == fire-1,"replacementneveroriginalarmorcombatgrowthorfreepayment")
	knock(gs); p.units[1].front = 1; foe.units[0].front = 1; foe.units[0].formRules = {"lockEnemyFrontReplacement":true}; idx = give(gs,"c27602")
	check(gs.VerifiedRules.Bingyong.replacement_blocked(gs,0,u) and gs.can_play_card(0,idx).ok and gs.play_card(0,idx),"KOreplacementrevivenotblockedbydustarraymovementrestriction")
	check(u.front == 0 and p.units[1].front == 1,"reviveunderdustarrayneverreplacesfront"); foe.units[0].formRules = {}; foe.units[0].front = 0
	check(Yitiao.swift(u) and gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u) == 0,"awakepermanentrealzeroenergydeployment")
	p.energy = 0; check(gs.basic_attack(0,0) and foe.avatarHp == face-7,"revivedawakefirstdeploymentusesretainedwarskillandbonus")
	check(not gs.can_basic_attack(0,0).ok,"permanentswiftnotextraordinarycount")
	gs.turn_counter += 2; p.attackUsed = false; check(gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u) == 0 and gs.basic_attack(0,0),"permanentswiftisnotconsumedbyfirstattack")
	check(not gs.can_play_card(0,give(gs,"c27608")).ok,"cannotrepeatawakening")
	gs = game(); p = gs.player(0); u = p.units[0]; idx = give(gs,Yitiao.TRAINING); knock(gs)
	check(not gs.can_play_card(0,idx).ok,"unawakenedKOcannotusecombat")
	play(gs,"c27608"); p.energy = 40; var count: int = int(u.get("yitiaoSkillUses",0)); check(gs.play_card(0,idx) and not u.has("battleSkillId") and u.get("yitiaoSkillBonus",0) == 0 and u.yitiaoSkillUses == count+1,"KOwarcardkeepsidentitycountbutdoesnotinstallorinventhandbonus")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; gs._deploy_realm(0,Content.card_def("c17007")); p.deck = [instance(gs,"c27601")]; var hp: int = p.avatarHp
	check(gs.hand_card_def(0,0).sourceZone == "deck" and gs.play_card(0,0) and int(u.get("yitiaoSkillBonus",0)) == 0 and u.battleSkillId == "c27601" and p.avatarHp == hp-2,"voyagedecktopwarskillinstallsbutneverpretendshandgrowth")
	gs = game(); p = gs.player(0); give(gs,"c27602"); var stamp := JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0); gs.VerifiedRules.BattleSkill.ready(gs,0,0)
	check(JSON.stringify(gs.snapshot()) == stamp,"dynamiccardandabilityqueriespure")
func ai_rules() -> void:
	for n in range(1,9):
		var gs := game(); var id := "c276%02d" % n; give(gs,id); var best := AI._best_card(gs,0)
		check(best.ok and best.card_id == id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualoriginal "+id)
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty(),"AIresolvesrealstancechoice")
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalfullPNG "+id)
	var gs := game(); play(gs,"c27608"); knock(gs); give(gs,"c27602"); var best := AI._best_card(gs,0)
	check(best.ok and best.target == null and gs.play_card(0,best.hand,best.target) and gs.player(0).units[0].hp > 0,"AIusesrealKOcombatrevivalwithouttarget")
	gs = game(); play(gs,"c27601"); best = AI._best_attack(gs,0)
	check(best.ok and best.unit == 0 and gs.basic_attack(0,best.unit,best.target),"AIuseslegalactualstrengthenedwarskill")
	gs = game(); gs.player(0).avatarHp = 10; play(gs,"c27607"); AI._resolve_choice(gs,0)
	check(gs.player(0).units[0].formRules.yitiaoDeployment == "lifeSteal","AIinjuredavatarselectslifesteal")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["yitiao","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],276); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for unit in side.units: unit.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
		hand(b,["c27607"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type") == "yitiao-stance" and choice_face(b,"yitiao-critical") != null,"nativeactualiiaitwochoiceUI")
		check(choice_face(b,"yitiao-critical").data.name.contains("暴击") and choice_face(b,"yitiao-lifesteal").data.name.contains("吸血"),"nativechoicesstateactualeffects")
		await capture("%d-01-iiai-choice" % physical.x)
		await click(choice_face(b,"yitiao-critical")); await settled(b)
		check(gs.pending_choice.is_empty() and u.formRules.yitiaoDeployment == "critical","nativeclickrealcriticalbranchcontinuesstack")
		var face: int = foe.avatarHp; await click(b._unit_widget(str(u.uid))); await settled(b); await click(b._enemy_plate); await settled(b)
		check(foe.avatarHp == face-4,"nativeselectedcriticalactuallydoublesdeploymentdamage")
		play(gs,"c27608"); knock(gs); hand(b,["c27602"]); await settled(b)
		check(b._hand_row.get_child(0).data.get("yitiaoReviveReplacement",false),"nativeKOcombatvisibleasactualrevivalcard")
		await capture("%d-02-awake-KO-revive" % physical.x)
		face = foe.avatarHp; await click(b._hand_row.get_child(0)); await settled(b)
		check(u.hp == 5 and u.front == 0 and foe.avatarHp == face and b._pending_target_card == -1,"nativeKOcardclickreviveswithoutpursuitorextracombat")
		hand(b,["c27601","c27602"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b); check(b._pending_target_card == 0,"nativepursuitrealchoiceopens")
		var fire: int = p.energy; await click(b._unit_widget(str(p.units[1].uid))); await settled(b); check(p.energy == fire and b._pending_target_card == 0,"nativepursuitwrongallycostsnothing")
		escape(); await process_frame; check(b._pending_target_card == -1,"nativeEscapecancelsrealpursuitchoice")
		gs._grow_unit(foe.units[1],0,10); var hp: int = foe.units[1].hp; await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(foe.units[1].hp == hp-9,"nativepursuitactualledger3/3plusawakebody6")
		gs._grow_unit(u,0,10); gs._grow_unit(foe.units[0],0,30); u.front = 0; p.units[1].front = 1
		hand(b,["c27606"]); await settled(b); gs.current_player = 1; var ally_hp: int = p.units[1].hp; hp = foe.units[0].hp
		check(gs.basic_attack(1,0),"nativeenemycommandtriggersautomaticcover"); await settled(b)
		check(p.hand.is_empty() and u.front == 1 and p.units[1].hp == ally_hp and foe.units[0].hp == hp-12,"nativeautomaticcoverprotectsactualallyandshows2separatecombats")
		await capture("%d-03-cover-response" % physical.x)
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var rules_only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	upgrade_gifts(); persistent_skill(); pursuit_and_forms(); alone_and_stance(); cover_response(); awakening_and_sources(); ai_rules()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("YITIAO_OK checks=%d failures=%d rules_only=%s" % [checks,failures,rules_only]); quit(0 if failures == 0 else 1)
