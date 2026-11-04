extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Butterfly := preload("res://scripts/butterfly_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("BUTTERFLY_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["hudiejing","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],274)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true; p.avatarArmor = 0
		for u in p.units: u.level = 3
	gs.rule_events.clear()
	return gs
func instance(gs, id: String) -> Dictionary:
	var inst := {"definitionId": id, "instanceId": "butterfly-fixture-%d" % gs.next_card_id}; gs.next_card_id += 1; return inst
func give(gs, id: String) -> int:
	gs.player(0).hand.append(instance(gs,id)); return gs.player(0).hand.size() - 1
func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actualuse " + id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)
func basic_and_skills() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]; var foe: Dictionary = gs.player(1)
	check(u.attack == 2 and u.maxHp == 5 and u.passive_hooks.is_empty(),"base2/5 oldhealonspellremoved")
	play(gs,"c27401"); check(u.battleSkillId == "c27401" and p.keywordUsage.encourage.attack == 2 and p.keywordUsage.encourage.shield == 1,"drunkspring exactencourage and storesrealability")
	var fire: int = p.energy; var hp: int = foe.avatarHp
	check(gs.basic_attack(0,0) and p.energy == fire-1 and p.attackUsed,"firstskillusesbasicresourcesonce")
	check(u.front == 0 and foe.avatarHp == hp and events(gs,"combat-complete").is_empty(),"spellskillreplacesattack withoutinventedcombatormovement")
	check(p.hand.is_empty() and events(gs,"battle-skill-used").size() == 1 and p.cardsPlayedThisTurn == 2,"skillnotaphysicalhandcard but iscarduse")
	check(p.keywordUsage.encourage.attack == 2 and u.battleSkillId == "c27401","oldencourageconsumedbeforefreshencourage andreplayneverreinstalls")
	u.inspired = true
	check(gs.basic_attack(0,0) and foe.avatarHp == hp-4 and u.front == 1,"same-turnextraordinaryattack consumesnewencourage anddoesnotreplayskill")
	check(events(gs,"battle-skill-used").size() == 1,"inspiredcannotresetfirstdeployment")
	gs = game(); p = gs.player(0); u = p.units[0]; foe = gs.player(1)
	play(gs,"c27402",foe.units[0].uid); check(foe.units[0].hp == foe.units[0].maxHp-2 and foe.units[0].enraged,"goldsong exactdamage2andenrage")
	var target: String = foe.units[1].uid; hp = foe.units[1].hp; fire = p.energy
	check(gs.basic_attack_targets(0,0).has(target) and not gs.basic_attack_targets(0,0).has("avatar-1"),"storedspelltargetsreserveenemywithoutavatar")
	check(not gs.basic_attack(0,0) and p.energy == fire,"targetedskillrejectsnullwithoutpayment")
	check(not gs.basic_attack(0,0,p.units[1].uid) and p.energy == fire,"targetedskillrejectsallywithoutpayment")
	check(gs.basic_attack(0,0,target) and foe.units[1].hp == hp-2 and foe.units[1].enraged and u.front == 0,"skillresolvesselectedenemyexactly")
	gs.turn_counter += 2; p.attackUsed = false
	check(gs.basic_attack(0,0,foe.units[2].uid) and events(gs,"battle-skill-used").size() == 2,"laterownturnskillrefresheswithoutreinstall")
	gs._knockout_unit(u,1,0); gs._resolve_resolution_stack(); check(not u.has("battleSkillId"),"realKOclearsbattleskill")
	gs = game(); p = gs.player(0); check(gs.basic_attack(0,0),"normalfirstdeploymentbeforeanyskill")
	play(gs,"c27401"); p.units[0].inspired = true; hp = gs.player(1).avatarHp
	check(gs.basic_attack(0,0) and gs.player(1).avatarHp == hp-4 and events(gs,"battle-skill-used").is_empty(),"learningafterfirstbasicdoesnotreopenfirstdeployment")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27401"); play(gs,"c27402",foe.units[0].uid)
	check(p.units[0].battleSkillId == "c27402","latestskillreplacespreviousability")
	# No legal target: ordinary deployment remains legal, with ordinary targets.
	for enemy in foe.units: enemy.hp = 0; enemy.knockout = 2
	hp = foe.avatarHp
	check(gs.basic_attack_targets(0,0) == ["avatar-1"] and gs.basic_attack(0,0) and foe.avatarHp == hp-4,"unusableskillfallsbacktogenuineordinaryattack")
func dream_and_move() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var target: Dictionary = p.units[1]; var hp: int = foe.avatarHp
	play(gs,"c27404",target.uid); check(foe.avatarHp == hp-int(target.attack) and target.front == 1 and not p.attackUsed,"dreamlivingallyactualcombatwithoutbasicresources")
	check(events(gs,"butterfly-after-basic").is_empty(),"forcedattackisnotplayercommandeddeployment")
	gs._knockout_unit(target,1,0); gs._resolve_resolution_stack(); var fire: int = p.energy
	check(gs.basic_attack(0,0,target.uid) and target.hp == target.maxHp and target.front == 0 and p.energy == fire-1,"dreamskillrevivessamecorpsewithoutattacking")
	check(not gs.valid_targets(0,Content.card_def("c27404")).has(p.units[0].uid),"dreamneverselectsitself")
	target.frozen = 1; check(not gs.valid_targets(0,Content.card_def("c27404")).has(target.uid),"dreamcannotmakeastunnedlivingallyattack")
	p.units[2].level = 0; check(not gs.valid_targets(0,Content.card_def("c27404")).has(p.units[2].uid),"dreamlivinginactiveallycannotattack")
	gs = game(); p = gs.player(0); foe = gs.player(1); foe.units[0].front = 1
	play(gs,"c27405",foe.units[1].uid)
	check(foe.units[0].front == 0 and foe.units[1].front == 1 and foe.units[1].attack == 0,"butterflymovesactualtargetandsetswholepowerzero")
	gs._grow_unit(foe.units[1],4,0); check(foe.units[1].attack == 0 and gs.VerifiedRules.Combat.power(gs,1,foe.units[1],9) == 0,"zeropowerdominatesgrowthandcombatbonuses")
	check(gs.basic_attack(0,0,foe.units[2].uid) and foe.units[2].front == 1 and foe.units[2].attack == 0,"moveskillreplayactualselectedreserve")
	gs.turn_counter += 1; gs._recalc(foe.units[1]); check(foe.units[1].attack > 0,"zeropowerexpiresatturnboundary")
	gs = game(); foe = gs.player(1); foe.units[0].hp = 1; play(gs,"c27402",foe.units[0].uid)
	check(foe.units[0].hp == 0 and not foe.units[0].get("enraged",false),"killingdamagecannotenragecorpse")
func enhance_and_awakening() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	var a := give(gs,"c27402"); give(gs,"c27402"); give(gs,"c27406"); give(gs,"c11902"); p.deck = [instance(gs,"c11902"),instance(gs,"c11902")]
	var id: String = p.hand[a].instanceId
	check(gs.basic_attack(0,0) and p.hand[0].instanceId == id,"normalbasicpreservesactualhandidentities")
	for i in [0,1]: check(gs.hand_card_def(0,i).keywords.has("instant") and gs.hand_card_def(0,i).butterflyHandDraw,"heldskillenhancedafteractualdeployment")
	check(not gs.hand_card_def(0,2).keywords.has("instant") and not gs.hand_card_def(0,3).keywords.has("instant"),"awakeningandforeigncardsnotenhanced")
	var stamp := JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0); gs.basic_attack_targets(0,0); check(JSON.stringify(gs.snapshot()) == stamp,"descriptorandtargetqueriesarepure")
	var fire: int = p.energy; var decks: int = p.deck.size()
	check(gs.play_card(0,0,foe.units[0].uid) and p.energy == fire and p.deck.size() == decks-1,"firstenhancedskillfreeanddrawsexactlyoneactualcard")
	fire = p.energy; decks = p.deck.size()
	check(gs.play_card(0,0,foe.units[1].uid) and p.energy == fire-1 and p.deck.size() == decks-1,"secondenhancedskillpaysexactcostbutstilldraws")
	gs = game(); p = gs.player(0); foe = gs.player(1); give(gs,"c27402"); gs.basic_attack(0,0); gs.turn_counter += 1
	check(not gs.hand_card_def(0,0).get("butterflyHandDraw",false) and not gs.hand_card_def(0,0).keywords.has("instant"),"enhancementexpiresonrealturnboundary")
	gs = game(); p = gs.player(0); u = p.units[0]; foe = gs.player(1); play(gs,"c27406")
	check(u.awakened and u.attack == 3 and u.maxHp == 6 and gs.VerifiedRules.Combat.has(u,"remote"),"awakeningexact+1/+1andremotekeyword")
	check(not gs.can_play_card(0,give(gs,"c27406")).ok,"awakeningcannotrepeat")
	for card_id in Butterfly.SKILLS:
		var idx := give(gs,card_id); var card := gs.hand_card_def(0,idx)
		check(card.type == "combat" and card.typeLabel == "战斗牌" and not Content.is_spell(card) and card.effects[-1].action == "butterfly-combat","allnonawakeningbutterflyspellsconvert "+card_id)
	p.hand.clear(); var hp: int = foe.avatarHp; play(gs,"c27401")
	check(foe.avatarHp == hp-5 and u.front == 0 and u.hp == 6 and p.keywordUsage.encourage.attack == 0,"converteddrunkspringeffectthenrealremotecombatwithencourage")
	check(not p.attackUsed and events(gs,"butterfly-after-basic").is_empty(),"convertedcombatneverconsumesbasiccountortriggerspostdeployment")
	hp = foe.avatarHp; fire = p.energy
	check(gs.basic_attack(0,0) and foe.avatarHp == hp-5 and p.energy == fire-1 and p.attackUsed,"awakefirstskillreplayscombatnotoldspelltype")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27402",foe.units[0].uid); play(gs,"c27406"); hp = foe.avatarHp
	check(gs.basic_attack(0,0,foe.units[1].uid) and foe.units[1].hp == foe.units[1].maxHp-2 and foe.avatarHp == hp-3,"storedspelladaptsafterawakeningwithoutreinstall")
func forms_and_realm() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]; play(gs,"c27403")
	check(u.attack == 2 and u.maxHp == 5 and u.swift,"lookflowers2/5entryswift")
	p.energy = 0; check(gs.basic_attack(0,0) and not u.swift and p.attackUsed,"swiftreallyfreebasicbutconsumescount")
	Butterfly.form_turn_start(gs,0,0); check(u.swift,"actualformturnstarthookrefreshesswift")
	gs = game(); p = gs.player(0); u = p.units[0]; var hp: int = gs.player(1).avatarHp; give(gs,"c27407"); var fire: int = p.energy
	check(gs.basic_attack(0,0) and u.form.cardId == "c27407" and u.attack == 4 and u.maxHp == 7,"noformbasicreallyconsumesheldSSRbeforeattack")
	check(p.energy == fire-1 and gs.player(1).avatarHp == hp-4,"automaticSSRusesabilitywithoutsecondghostpayment")
	check(events(gs,"butterfly-auto-form").size() == 1 and events(gs,"butterfly-generated").size() == 2 and p.hand.size() == 2,"SSRentryanddeploymentgenerateindependently")
	for i in p.hand.size(): check(gs.hand_card_def(0,i).cost == 0 and gs.hand_card_def(0,i).keywords.has("instant") and gs.hand_card_def(0,i).butterflyHandDraw,"generatedphysicalskillsfreeandthenpostbasicenhanced")
	check(p.hand[0].instanceId != p.hand[1].instanceId,"generatedcopieshaveuniquephysicalidentities")
	gs.turn_counter += 1
	for i in p.hand.size(): check(gs.hand_card_def(0,i).cost == 1 and not gs.hand_card_def(0,i).keywords.has("instant"),"generatedfreeandinstantbothreallyexpire")
	gs = game(); p = gs.player(0); u = p.units[0]; play(gs,"c27403"); give(gs,"c27407"); check(gs.basic_attack(0,0) and u.form.cardId == "c27403" and p.hand.size() == 1,"existingformblocksautomaticSSRwithoutconsumingit")
	gs = game(); p = gs.player(0); p.units[0].level = 2; give(gs,"c27407"); check(gs.basic_attack(0,0) and p.units[0].form.is_empty() and p.hand.size() == 1,"lowlevelblocksautomaticSSR")
	gs = game(); p = gs.player(0); play(gs,"c27408"); var field: Dictionary = p.realms[0]; check(field.hp == 8 and field.nativeRealm == "butterfly-march","marchrealmexact8durability")
	p.energy = 0; check(gs.can_basic_attack(0,1).ok and gs.basic_attack(0,1) and p.energy == 0 and not p.attackUsed,"realmfreeanyallyfirstbasicandpreservescount")
	check(not gs.can_basic_attack(0,2).ok,"realmfreeonceonlyandcannotbypassnextghostcost")
	p.energy = 1; check(gs.basic_attack(0,2) and p.energy == 0 and p.attackUsed,"afterrealmregularattackstillavailableonce")
	gs.turn_counter += 2; p.attackUsed = true
	check(gs.can_basic_attack(0,3).ok and gs.basic_attack(0,3) and p.attackUsed,"nextturnfreeabilitypermitsdeploymentwhencountalreadyspentwithoutresettingcount")
	field.hp = 0; gs.turn_counter += 2; check(not gs.can_basic_attack(0,0).ok,"destroyedrealmprovidesnofreeattack")
func counter_and_ai() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); play(gs,"c27402",foe.units[0].uid); var hp: int = foe.units[1].hp
	p.nullifyNextCardTurn = gs.turn_counter; check(gs.basic_attack(0,0,foe.units[1].uid) and foe.units[1].hp == hp and p.units[0].front == 0,"replacedskillisrealcounterablecarduse")
	check(events(gs,"card-nullified").size() == 1 and p.attackUsed,"nullifiedskillstillspendscommandeddeployment")
	gs = game(); p = gs.player(0); foe = gs.player(1); give(gs,"c27402"); gs.basic_attack(0,0); p.nullifyNextCardTurn = gs.turn_counter; var decks: int = p.deck.size()
	check(gs.play_card(0,0,foe.units[0].uid) and p.deck.size() == decks-1 and foe.units[0].hp == foe.units[0].maxHp,"enhancedhanddrawonuseevenwheneffectcountered")
	for n in range(1,9):
		gs = game(); p = gs.player(0); var id := "c274%02d" % n
		if n == 4: p.units[1].hp = 0; p.units[1].knockout = 2
		give(gs,id); var best := AI._best_card(gs,0)
		check(best.ok and best.card_id == id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualuse "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"fulloriginalPNG "+id)
	gs = game(); p = gs.player(0); play(gs,"c27404",p.units[1].uid); gs._knockout_unit(p.units[2],1,0); gs._resolve_resolution_stack(); var chosen := AI._best_attack(gs,0)
	check(chosen.ok and chosen.unit == 0 and chosen.target == p.units[2].uid and gs.basic_attack(0,chosen.unit,chosen.target),"AIscoresfriendlyrevivalskillinsteadofinventedenemyavatarattack")
	check(p.units[2].hp > 0,"AIactualstoredskillrevivesselectedally")
func shared_boundaries() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c27402",foe.units[0].uid); gs._deploy_realm(0,Content.card_def("c17005")); var hp: int = p.avatarHp
	gs._deploy_realm(0,Content.card_def("c17007")); p.deck = [instance(gs,"c27402"),instance(gs,"c11902")]
	check(gs.basic_attack(0,0,foe.units[1].uid) and p.avatarHp == hp and events(gs,"butterfly-hand-draw").is_empty(),"storedabilitydoesnotinheritphysicalhandroadtaxordeckvoyagetaxordraw")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	var idx := give(gs,"c27402"); gs.basic_attack(0,0)
	var enhanced: Dictionary = p.hand.pop_at(idx); enhanced.butterflyFreeTurn = gs.turn_counter
	p.deck = [enhanced]; gs._deploy_realm(0,Content.card_def("c17007"))
	var view := gs.hand_card_def(0,0)
	check(view.sourceZone == "deck" and not view.get("butterflyHandDraw",false) and not view.keywords.has("instant"),"hand-onlyenhancementcannotleaktorealvoyagedecktop")
	var decks: int = p.deck.size(); hp = p.avatarHp
	check(gs.play_card(0,0,foe.units[0].uid) and p.deck.size() == decks-1 and p.avatarHp == hp-2 and events(gs,"butterfly-hand-draw").is_empty(),"actualdecktopusehasvoyagetaxbutneverinventedhanddraw")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27402",foe.units[0].uid); p.units[0].enraged = true
	check(gs.basic_attack(0,0,foe.units[1].uid) and not p.units[0].get("enraged",false),"spellskillreallyclearsenrageafterdeployment")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27402",foe.units[0].uid); p.units[0].frozen = 1; var fire: int = p.energy
	check(not gs.can_basic_attack(0,0).ok and not gs.basic_attack(0,0,foe.units[1].uid) and p.energy == fire,"skillcannotbypasssourcestunorconsumerejectedcost")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27402",foe.units[0].uid); p.units[0].level = 0
	check(not gs.can_basic_attack(0,0).ok,"skillcannotbypassinactiveowner")
	gs = game(); p = gs.player(0); play(gs,"c27407"); var count: int = p.hand.size(); var hp_foe: int = gs.player(1).avatarHp
	play(gs,"c27404",p.units[1].uid)
	check(p.hand.size() == count and events(gs,"butterfly-after-basic").is_empty() and gs.player(1).avatarHp == hp_foe-p.units[1].attack,"forcedallyattackdoesnottriggerbutterflySSRorbase")
	gs = game(); p = gs.player(0); foe = gs.player(1); give(gs,"c27402"); gs.basic_attack(0,0); gs.turn_counter += 2; p.attackUsed = false
	# The enhanced physical card has expired, and the skill is not installed yet.
	check(not gs.hand_card_def(0,0).get("butterflyHandDraw",false),"expiredcopydoesnotretaindrawafterownnextturn")
	gs = game(); p = gs.player(0); give(gs,"c27407"); p.energy = 1
	check(gs.basic_attack(0,0) and p.energy == 0 and p.units[0].form.cardId == "c27407","automaticformcanresolvewithonlyordinarydeploymentghost")
	gs = game(); p = gs.player(0); play(gs,"c27407"); p.hand.clear()
	for n in int(gs.rules.maxHandSize): give(gs,"c11902")
	gs.basic_attack(0,0)
	check(p.hand.size() == int(gs.rules.maxHandSize) and events(gs,"butterfly-generated").size() == 2,"fullhandburnsgeneratedskillwithoutoverfloworgratuitousdraw")
func skill_target_boundaries() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c27401"); p.units[0].keywords = ["pursuit"]
	for unit in foe.units: unit.hp = 0; unit.knockout = 2
	check(gs.can_basic_attack(0,0).ok and gs.basic_attack(0,0),"noncombatskilldoesnotrequireapursuittarget")
	check(events(gs,"battle-skill-used").size() == 1 and foe.avatarHp == 30,"autotargetskilldoesnotfabricatefacecombat")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27404",p.units[1].uid)
	for i in [1,2,3]: p.units[i].frozen = 1
	check(gs.VerifiedRules.BattleSkill.ready(gs,0,0).is_empty(),"dreamskillwithnoattackablealliescannotbeused")
	var hp: int = foe.avatarHp
	check(gs.basic_attack(0,0) and foe.avatarHp == hp-2,"unusabledreamfallsbacktonormalcombatwithoutforcingillegalally")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c27401")
	p.units[0].frozen = 1
	var stamp := JSON.stringify(gs.snapshot()); var marks: Array = gs.VerifiedRules.BattleSkill.unit_marks(gs,0,0)
	check(marks[0].contains("本次普通出击") and JSON.stringify(gs.snapshot()) == stamp,"statusquerynevermarksstunnedskillavailableormutatesstate")
func real_response_and_damage() -> void:
	var gs := GS.create(["hudiejing","shuweng","shantong","taohuayao"],["rime","storm","bingyong","baizangzhu"],274)
	for side in gs.players:
		side.hand.clear(); side.energy = 40; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c27402",foe.units[0].uid)
	foe.hand.append(instance(gs,"hoar-barrier")); var hp: int = foe.units[0].hp
	check(gs.basic_attack(0,0,foe.units[0].uid) and not gs.response_window.is_empty() and gs.response_window.action == "damage" and foe.units[0].hp == hp,"actualskillpausesbeforedamageforlegalresponse")
	check(events(gs,"butterfly-after-basic").is_empty(),"postdeploymentcannotrunbeforepausedskillresumes")
	check(gs.play_card(1,0,foe.units[0].uid) and gs.response_window.is_empty() and gs.resolution_stack.is_empty(),"realphysicalresponseconsumedandoriginalskillcontinuationdrains")
	check(foe.units[0].hp == hp and foe.units[0].shield == 0 and foe.units[0].enraged,"actualresponsearmorabsorbs2thenenrageapplies")
	check(events(gs,"butterfly-after-basic").size() == 1 and p.attackUsed,"postdeploymentrunsjustonceafterresumedresponse")
	var frame := {"resolutionId":999,"playerIndex":0,"definitionId":"c27404","effectIndex":0,"responseDepth":0,"targetId":p.units[1].uid}
	check(gs._create_response_window(frame).action == "assault","dreamlivingallyexposesrealassaultresponseclass")
	p.units[1].hp = 0; p.units[1].knockout = 2
	check(gs._create_response_window(frame).action == "revive","dreamcorpseexposesrealrevivalresponseclass")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[0].spellPower = 2; hp = foe.units[0].hp
	play(gs,"c27402",foe.units[0].uid); check(foe.units[0].hp == hp-4,"goldsongkeepsrealspellpowerbeforeawakening")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[0].spellPower = 2; play(gs,"c27406"); hp = foe.units[0].hp
	play(gs,"c27402",foe.units[0].uid); check(foe.units[0].hp == hp-2,"convertedcombateffectisnotboostedasspelldamage")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["hudiejing","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],274); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
		hand(b,["c27404"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(p.units[0].get("battleSkillId") == "c27404" and p.units[1].front == 1,"nativecardselectsallyandinstallsdreamskill")
		gs._knockout_unit(p.units[2],1,0); gs._resolve_resolution_stack(); b._refresh(); await settled(b)
		var fire: int = p.energy
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(b._selected_attacker == 0 and texts(b).contains("战技") and gs.basic_attack_targets(0,0).has(p.units[2].uid),"nativeunitselectionshowsskillpromptandfriendlycorpsehighlight")
		await capture("%d-01-dream-skill-target" % physical.x)
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(p.energy == fire and p.units[2].hp == 0,"nativewrongenemytargetrejectswithoutpayment")
		escape(); await process_frame; check(b._selected_attacker == -1 and p.energy == fire,"nativeEscapeactuallycancelsskillselection")
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b); await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		check(p.units[2].hp > 0 and p.energy == fire-1 and p.attackUsed and p.units[0].front == 0,"nativerealdeployreplacesattackwithselectedallyrevival")
		p.attackUsed = false; gs.turn_counter += 2; hand(b,["c27406","c27405"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b); var hp: int = foe.units[1].hp; var converted: Dictionary = b._hand_row.get_child(0).data
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(p.units[0].awakened and converted.type == "combat" and converted.typeLabel == "战斗牌" and foe.units[1].front == 1 and foe.units[1].attack == 0 and foe.units[1].hp == hp-3,"nativeawakeningandconvertedcombatmoveszeroesthenremotehitsactualfront")
		check(p.units[0].front == 0 and not p.attackUsed,"nativeconvertedcombatkeepsremoteandbasiccount")
		await capture("%d-02-awake-combat-skill" % physical.x)
		b.queue_free(); await process_frame
func run() -> void:
	var stores := Support.isolate_stores()
	var args := OS.get_cmdline_user_args(); var rules_only := args.has("--rules-only")
	for arg in args:
		if not arg.begins_with("--"): out = arg; DirAccess.make_dir_recursive_absolute(out)
	basic_and_skills(); dream_and_move(); enhance_and_awakening(); forms_and_realm(); counter_and_ai(); shared_boundaries(); skill_target_boundaries(); real_response_and_damage()
	if not rules_only:
		root.theme = ThemeBuilder.build_theme(); await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("BUTTERFLY_OK checks=%d failures=%d rules_only=%s" % [checks,failures,rules_only])
	quit(1 if failures else 0)
