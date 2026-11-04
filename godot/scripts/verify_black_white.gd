extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const BW:=preload("res://scripts/black_white_rules.gd")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("BLACK_WHITE_FAIL ",message)
func game() -> GS:
	var gs:=GS.create(["heitongzi","baitongzi","shuweng","taohuayao"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],240241)
	for p in gs.players:
		p.hand.clear();p.deck.clear();p.energy=30;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func instance(gs,id: String,linked: bool=false) -> Dictionary:
	var result:Dictionary={"instanceId":"black-white-test-%d"%gs.next_card_id,"definitionId":id,"linkedUse":linked};gs.next_card_id+=1;return result
func give(gs,id: String,owner: int=0,linked: bool=false) -> int:
	gs.player(owner).hand.append(instance(gs,id,linked));return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,linked: bool=false) -> void:
	var idx:=give(gs,id,0,linked);check(gs.play_card(0,idx,target),"actual play "+id)
func knock(gs,owner: int,idx: int) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0);gs._resolve_resolution_stack()
func ev(gs,kind: String) -> Array:return gs.rule_events.filter(func(e):return e.kind==kind)
func resolve_all(gs) -> void:
	for i in 20:
		if not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,gs.action_player()),"AI resolves pending "+str(gs.pending_choice.get("type")))
		elif not gs.response_window.is_empty():check(gs.pass_response(gs.action_player()),"pass actual response")
		else:return
func base_keywords() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var e:Dictionary=gs.player(1)
	check(p.units[0].attack==3 and p.units[0].maxHp==4 and p.units[1].attack==2 and p.units[1].maxHp==6,"original paired3/4 and2/6 bodies")
	check(p.units[0].passive_hooks.is_empty() and p.units[1].passive_hooks.is_empty(),"legacy buff passive hooks cleared")
	e.units[0].hp=2;e.units[0].front=1;gs._grow_unit(e.units[0],2,0);play(gs,"c24001")
	check(e.units[0].hp==0 and e.avatarHp==28,"black punishment actual4 combat and2 pierce overflow")
	check(p.units[0].hp==2 and p.units[0].shield==0 and not p.attackUsed,"printed1armor absorbs1 counter without deployment consumption")
	gs=game();p=gs.player(0);e=gs.player(1);p.avatarHp=20;play(gs,"c24101")
	check(e.avatarHp==27 and p.avatarHp==23 and p.units[1].shield==1,"white punishment3 combat lifesteals3 and armor1")
	check(not p.units[1].unyielding,"basic card grants lifesteal, no invented unyielding")
func moving_revival() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var e:Dictionary=gs.player(1)
	p.deck.append(instance(gs,"c24001"));p.units[1].front=1
	var idx:=give(gs,"c24002");var c:Dictionary=gs.hand_card_def(0,idx);var opts:Array=gs.valid_targets(0,c)
	check(opts.has(p.units[0].uid) and opts.has(p.units[1].uid) and not opts.has(e.units[0].uid),"replace targets own living shikigami")
	gs.VerifiedRules.Fortune.transform(gs,0,2,false);opts=gs.valid_targets(0,c)
	check(opts.has(p.units[2].uid),"transformed allied shikigami remains a valid movement target")
	gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack()
	check(not gs.valid_targets(0,c).has(p.units[2].uid),"knocked-out ally cannot be selected for movement")
	gs.VerifiedRules.Peach.revive(gs,0,0,p.units[2],false,false)
	# Remove deck after candidate inspection to isolate the movement card's draw.
	p.deck.clear();p.deck.append(instance(gs,"c12001"))
	check(gs.play_card(0,idx,p.units[1].uid),"replace white actual selected use")
	check(p.units[1].front==0 and p.hand.size()==1 and p.hand[0].definitionId=="c12001" and p.energy==30,"white movement draws1, first instantfree")
	p.hand.clear();play(gs,"c24002",p.units[2].uid)
	check(p.units[2].front==1 and p.hand.is_empty() and p.energy==29,"other ally movement no draw, spent instantcost1")
	gs=game();p=gs.player(0);idx=give(gs,"c24102");c=gs.hand_card_def(0,idx)
	check(gs.valid_targets(0,c).is_empty() and not gs.can_play_card(0,idx,p.units[0].uid).ok,"summon soul cannot target living")
	knock(gs,0,2);check(gs.play_card(0,idx,p.units[2].uid),"soul otherKO actual play")
	check(p.units[2].knockout==1 and p.units[2].hp==0,"otherKO onlycountdown minus1")
	play(gs,"c24102",p.units[2].uid);check(p.units[2].hp==p.units[2].maxHp and p.units[2].knockout==0,"countdownzero actualrevival")
	knock(gs,0,0);play(gs,"c24102",p.units[0].uid)
	check(p.units[0].hp==4 and p.units[0].knockout==0,"black actualrevive evencountdown2")
	knock(gs,0,0);p.units[0].samuraiCannotRevive=true;idx=give(gs,"c24102")
	check(not gs.valid_targets(0,gs.hand_card_def(0,idx)).has(p.units[0].uid),"cannotrevive excluded before payment")
func forms_and_growth() -> void:
	var gs:=game();var p:Dictionary=gs.player(0)
	play(gs,"c24003");check(p.units[0].attack==5 and p.units[0].hp==4 and p.units[1].attack==3 and p.units[1].hp==6,"blackbond installs both originalforms")
	check(ev(gs,"automatic-card").size()==1 and p.cardsPlayedThisTurn==1 and p.energy==29,"one generated partner form, no recursion or extra fire/handuse")
	check(p.deck.is_empty() and p.hand.is_empty(),"bond creates automaticform without requiringdeckcopy")
	gs=game();p=gs.player(0);play(gs,"c24103");check(p.units[0].attack==5 and p.units[1].attack==3 and ev(gs,"automatic-card").size()==1,"whitebond symmetric automaticblackform")
	gs=game();p=gs.player(0);knock(gs,0,1);play(gs,"c24003");check(p.units[1].hp==0 and p.units[1].form.is_empty() and ev(gs,"automatic-card").is_empty(),"bond doesnot resurrectKOpartner")
	gs=game();p=gs.player(0);play(gs,"c24004");play(gs,"c24104")
	check(p.units[0].attack==4 and p.units[0].maxHp==8 and p.units[1].attack==4 and p.units[1].maxHp==8,"guard/sacrifice exact4/8")
	gs._damage_unit(0,0,2,1,0)
	check(p.units[0].hp==6 and p.units[0].attack==5 and p.units[1].hp==9 and p.units[1].maxHp==9,"blackhurt triggers blackpower and whitelife exactlyonce")
	gs._damage_unit(0,1,2,1,0)
	check(p.units[0].attack==6 and p.units[1].hp==8 and p.units[1].maxHp==10,"whitehurt triggers both, growscurrentandmaxhp")
	gs._grant_unit_armor(p.units[1],5);gs._damage_unit(0,1,1,1,0)
	check(p.units[0].attack==6 and p.units[1].maxHp==10,"armor-onlyhit doesnot countlifehurt")
	gs._damage_unit(0,2,1,1,0)
	check(p.units[0].attack==6 and p.units[1].maxHp==10,"otherfriendlyhurt cannottrigger pairforms")
	play(gs,"c24007");play(gs,"c24107")
	check(p.units[0].attack==8 and p.units[1].maxHp==8,"nonpermanentgrowth persistsacrossformreplace")
	check(gs.VerifiedRules.Combat.has(p.units[0],"pierce") and gs.VerifiedRules.Combat.has(p.units[1],"lifesteal"),"double-shadows retain exactkeywords")
	check(not p.units[0].get("swift",false) and not p.units[1].get("inspired",false),"unlinked shadowsno enhancedtrait")
	knock(gs,0,0);knock(gs,0,1)
	check(p.units[0].attackBonus==0 and p.units[1].maxHpBonus==0,"alltemporarypairgrowth removedonKO")
	gs=game();p=gs.player(0);play(gs,"c24104");gs._damage_unit(0,1,8,1,0)
	check(p.units[1].hp==0 and p.units[1].knockout==2,"lethalwhitehurt cannotselfhealoutofKO")
func buff_awaken_enhancement() -> void:
	var gs:=game();var p:Dictionary=gs.player(0)
	play(gs,"c24105");check(p.units[0].attack==5 and p.units[0].hp==6 and p.units[1].attack==4 and p.units[1].hp==8,"prayer exact2/2toeachpair")
	check(p.units[2].attackBonus==0 and p.units[3].maxHpBonus==0,"prayer neverbuffsotherrole")
	knock(gs,0,0);check(p.units[0].attackBonus==0 and p.units[0].maxHpBonus==0,"prayernotpermanent")
	gs=game();p=gs.player(0);knock(gs,0,1);play(gs,"c24006")
	check(p.units[0].awakened and p.units[0].attack==4 and p.units[0].maxHp==5,"blackawakeprintedself1/1")
	check(p.units[1].attack==3 and p.units[1].hp==0,"blackawakepermanentpartnerpowerapplieswhileKOwithoutrevival")
	var repeat:=give(gs,"c24006");check(not gs.can_play_card(0,repeat).ok and p.units[1].attack==3 and p.units[0].attack==4,"awakened black cannot play a second awakening or stack partner buff");p.hand.remove_at(repeat)
	gs.VerifiedRules.Peach.revive(gs,0,0,p.units[1],false,false);play(gs,"c24106")
	check(p.units[0].maxHp==6 and p.units[1].awakened,"whiteawakeningpermanentblacklife")
	repeat=give(gs,"c24106");check(not gs.can_play_card(0,repeat).ok,"awakened white cannot play a second awakening");p.hand.remove_at(repeat)
	knock(gs,0,0);gs.VerifiedRules.Peach.revive(gs,0,1,p.units[0],false,false)
	check(p.units[0].maxHp==6 and p.units[0].attack==4,"awakeningandpartnerpermanentbodypersistsKO")
	gs=game();p=gs.player(0);play(gs,"c24007",null,true);play(gs,"c24107",null,true)
	check(p.units[0].swift and p.units[1].get("inspired",false),"linkedshadowsgrantactualswiftandinspired")
	p.energy=0;check(gs.basic_attack(0,0),"blacklinkedshadowdeploymentfree")
	check(not p.units[0].swift and p.attackUsed,"swiftconsumedbutnormaldeploymentused")
	p.energy=1;check(gs.basic_attack(0,1),"whiteinspiredallowsattackafterdeploymentused")
	check(not p.units[1].get("inspired",false) and p.energy==0,"inspiredconsumestraitandstillpaysfire")
func reset_interactions() -> void:
	var gs:=game();var p:Dictionary=gs.player(0)
	play(gs,"c24006");play(gs,"c24106");play(gs,"c24105")
	check(p.units[0].attack==6 and p.units[0].maxHp==8 and p.units[1].attack==6 and p.units[1].maxHp==9,"awakening and prayer apply both permanent and temporary growth")
	gs.VerifiedRules.SunSmoke.reset_character(gs,0,p.units[0],p.units[0].uid)
	gs.VerifiedRules.SunSmoke.reset_character(gs,0,p.units[1],p.units[1].uid)
	check(p.units[0].attack==4 and p.units[0].maxHp==6 and p.units[1].attack==4 and p.units[1].maxHp==7,"sun reset retains permanent partner and awakening bonuses")
	knock(gs,0,0);knock(gs,0,1)
	gs.VerifiedRules.Peach.revive(gs,0,2,p.units[0],false,false);gs.VerifiedRules.Peach.revive(gs,0,2,p.units[1],false,false)
	check(p.units[0].attack==4 and p.units[0].maxHp==6 and p.units[1].attack==4 and p.units[1].maxHp==7,"KO after reset does not subtract already-cleared temporary growth")
func chained_attacks() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var e:Dictionary=gs.player(1)
	play(gs,"c24005");check(e.avatarHp==25 and p.units[1].front==1 and p.units[0].front==0,"combinedattackblack3thenwhite2realattacks")
	check(not p.attackUsed and p.energy==29,"combinedattacksfreeofdeploymentandghostfire")
	gs=game();p=gs.player(0);e=gs.player(1);knock(gs,0,1);play(gs,"c24005")
	check(e.avatarHp==27,"KOpartnerneverattacks")
	gs=game();p=gs.player(0);e=gs.player(1);p.units[1].frozen=1;play(gs,"c24005")
	check(e.avatarHp==27,"stunnedpartnercannotstartforcedattack")
	gs=game();p=gs.player(0);e=gs.player(1);e.units[0].front=1;gs._grow_unit(e.units[0],2,20)
	play(gs,"c24008");check(gs.pending_choice.get("type")=="black-white-second" and e.units[0].hp==21 and p.units[0].hp==1,"firstslashprinted+2thenpausesforactualchoice")
	check(gs.pending_choice.instanceIds.has(e.units[2].uid) and gs.pending_choice.instanceIds.has("avatar-1") and not gs.pending_choice.instanceIds.has(p.units[1].uid),"secondslashoffersreserveandavataronly")
	var shown:Dictionary=BW.choice_card(gs,0,e.units[0].uid);var face_shown:Dictionary=BW.choice_card(gs,0,"avatar-1")
	check("力量 3" in shown.text and "生命 21/26" in shown.text and "护甲 0" in shown.text and "牌手生命 30" in face_shown.text,"second-target options expose current power health armor and avatar health")
	check(not gs.resolve_divination_choice(1,"avatar-1") and not gs.resolve_divination_choice(0,p.units[1].uid),"wrongownerandallychoicesrejected")
	check(gs.resolve_divination_choice(0,"avatar-1"),"secondslashactualfacechoice")
	check(e.avatarHp==27 and gs.pending_choice.is_empty() and not BW.combat_immune(p.units[0]),"secondordinary3hitsthroughfrontandnoresidualimmunity")
	gs=game();p=gs.player(0);e=gs.player(1);e.units[0].front=1;e.units[0].attack=20;gs._grow_unit(e.units[0],0,20)
	play(gs,"c24008",null,true)
	check(p.units[0].hp==4 and BW.combat_immune(p.units[0]) and gs.pending_choice.get("type")=="black-white-second","linkedslashsurvivesfirst20counter")
	gs._damage_unit(0,0,2,1,0);check(p.units[0].hp==2,"allcombatimmunitydoesnotpreventspellhit")
	p.units[0].frozen=1;e.units[2].foxVeil=true
	check(not BW._second_targets(gs,0).has(e.units[2].uid),"secondselectedattackexcludesveil")
	check(gs.resolve_divination_choice(0,e.units[0].uid),"secondslashstillresolvesaftermidcards stun")
	check(p.units[0].hp==2 and e.units[0].hp==18 and not BW.combat_immune(p.units[0]),"secondattackordinary3alsoprotectedthenimmunityends")
	gs._damage_unit(0,0,1,1,0,true);check(p.units[0].hp==1,"combatdamageaftercardnotimmune")
	gs=game();p=gs.player(0);e=gs.player(1);e.units[0].front=1;e.units[0].attack=20
	play(gs,"c24008");check(p.units[0].hp==0 and gs.pending_choice.is_empty(),"deadfirstslashsourcecannotsecondattack")
func immortal() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var e:Dictionary=gs.player(1)
	e.units[0].front=1;gs._grow_unit(e.units[0],2,20);play(gs,"c24108")
	check(p.units[1].shield==7 and e.units[0].hp==24 and BW.veil(p.units[1]),"immortalactual10armor+veilwithoutlethal")
	var c:Dictionary={"id":"test","type":"spell","target":"enemy-unit"}
	check(not gs.valid_targets(1,c).has(p.units[1].uid),"actualenemytargetlegalityrespectsveil")
	BW.turn_start(gs,1);check(BW.veil(p.units[1]),"opponentstartdoesnotexpireveil")
	BW.turn_start(gs,0);check(not BW.veil(p.units[1]) and gs.valid_targets(1,c).has(p.units[1].uid),"ownstartexpiresveil")
	gs=game();p=gs.player(0);e=gs.player(1);e.units[0].front=1;gs._grow_unit(e.units[0],0,20);play(gs,"c24108",null,true)
	check(e.units[0].hp==0 and BW.veil(p.units[1]),"linkedimmortallethalkillshealthydefender")
	knock(gs,0,1);check(not BW.veil(p.units[1]),"veilclearedonKO")
func link_candidates() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var c:Dictionary=Content.card_def("c24001")
	for id in ["c24101","c24104","c24107","c24001"]:p.deck.append(instance(gs,id))
	p.units[1].level=2
	check(BW.link_candidates(gs,0,c).map(func(x):return x.definitionId)==["c24104"],"blackonlylinkswhitecurrentlevelnotplayedcardlevel")
	knock(gs,0,1);check(BW.link_candidates(gs,0,c).size()==1,"KOpartnerremainslinkcandidate")
	p.units[1].frozen=1;check(BW.link_candidates(gs,0,c).size()==1,"stunnedpartnerremainslinkcandidate")
	p.units[1].removed=true;check(BW.link_candidates(gs,0,c).is_empty(),"removedpartnernotinplay")
	p.units[1].removed=false;p.units[0].baseRulesSuppressed=true;check(BW.link_candidates(gs,0,c).is_empty(),"suppressedinitiatorcannotlink")
	p.units[0].baseRulesSuppressed=false;p.units[0].awakened=true;check(BW.link_retrieve(gs,0,0) and not BW.link_retrieve(gs,0,1),"recoverybelongsinitiatingawakenedsource")
func actual_link() -> void:
	for awakened in [false,true]:
		for choose_original in [false,true]:
			var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
			p.units[0].awakened=awakened
			var original:=instance(gs,"c24001");var candidate:=instance(gs,"c24107")
			p.hand.append(original);p.deck.append(candidate)
			check(gs.play_card(0,0),"playing original opens actual link")
			check(gs.pending_choice.get("type")=="native-link" and p.energy==30 and p.hand.size()==1 and p.deck.size()==1,"link reveal defers payment and zone mutations")
			check(gs.pending_choice.get("instanceIds",[]).has(original.instanceId) and gs.pending_choice.get("instanceIds",[]).has(candidate.instanceId),"link offers exact source and eligible candidate instances")
			var selected:Dictionary=original if choose_original else candidate;var other:Dictionary=candidate if choose_original else original
			check(not gs.resolve_divination_choice(1,str(selected.instanceId)),"opponent cannot choose link")
			check(gs.resolve_divination_choice(0,str(selected.instanceId)),"actual link selection")
			var preview:Dictionary=gs.hand_card_def(0,0)
			check(preview.id==selected.definitionId and preview.get("linkedUse",false),"selected card has actual linked view")
			check(gs.play_card(0,0),"actual selected link payment/use")
			check(p.energy==29 and p.cardsPlayedThisTurn==1 and gs.pending_choice.is_empty(),"one fire and one use after link")
			check((p.hand.size()==1 and p.hand[0].instanceId==other.instanceId and p.deck.is_empty()) if awakened else (p.hand.is_empty() and p.deck.size()==1 and p.deck[0].instanceId==other.instanceId),"unselected card is shuffled or retrieved after awaken")
			if choose_original:check(foe.avatarHp==26,"chosen black card deals printed 4")
			else:check(p.units[1].get("inspired",false) and p.units[1].form.cardId=="c24107","chosen linked white form applies real enhancement")
	var gs:=game();var p:Dictionary=gs.player(0);knock(gs,0,1)
	p.deck.append(instance(gs,"c24107"));p.hand.append(instance(gs,"c24001"))
	check(gs.play_card(0,0) and gs.pending_choice.get("type")=="native-link","knocked-out partner still enables source link")
	var candidate_id:String=gs.pending_choice.candidate.instanceId
	check(not gs.VerifiedRules.Link.option_check(gs,0,candidate_id).ok and not gs.resolve_divination_choice(0,candidate_id),"cannot choose card whose own source is knocked out")
	check(AI._resolve_choice(gs,0) and gs.play_card(0,0),"AI selects and uses available alternative")
	gs=game();p=gs.player(0);p.units[0].awakened=true;p.units[1].level=1
	var original:=instance(gs,"c24002");var candidate:=instance(gs,"c24101");p.hand.append(original);p.deck.append(candidate)
	check(gs.play_card(0,0),"instant link starts")
	check(gs.resolve_divination_choice(0,str(original.instanceId)) and gs.play_card(0,0,p.units[1].uid),"chosen original moves partner and draws")
	check(p.hand.size()==1 and p.hand[0].instanceId==candidate.instanceId and p.deck.is_empty() and ev(gs,"link-retrieved").is_empty(),"card naturally drawn during resolution is not duplicated by awake retrieval")
	gs=game();p=gs.player(0);p.units[1].level=1;p.deck.append(instance(gs,"c24101"));p.hand.append(instance(gs,"c24001"))
	var began:=AI.take_action(gs,0);var chose:=AI.take_action(gs,0);var used:=AI.take_action(gs,0)
	check(began and chose and used and gs.pending_choice.is_empty() and gs.VerifiedRules.Link.ready_hand(gs,0)<0 and p.cardsPlayedThisTurn==1,"AI completes the whole actual link and play")
func ai_cards() -> void:
	for role_id in [240,241]:
		for number in range(1,9):
			var id:="c%d"%(role_id*100+number);var gs:=game();var p:Dictionary=gs.player(0)
			if id=="c24102":knock(gs,0,0)
			var idx:=give(gs,id);var best:Dictionary=AI._best_card(gs,0)
			check(best.ok and best.hand==idx,"AIselectslegal "+id)
			if best.ok:check(gs.play_card(0,int(best.hand),best.target),"AIactualplay "+id);resolve_all(gs)
			check(p.hand.is_empty() and gs.pending_choice.is_empty(),"AIcompletesactualcard "+id)
func settled(b) -> void:
	for i in 3:await process_frame
	while b._input_locked():await create_timer(b._presentation_remaining()+0.05).timeout
	await create_timer(0.40).timeout
	await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	base_keywords();moving_revival();forms_and_growth();buff_awaken_enhancement();reset_interactions();chained_attacks();immortal();link_candidates();actual_link();ai_cards()
	if not only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("BLACK_WHITE_OK checks=%d failures=%d rules_only=%s"%[checks,failures,only]);quit(0 if failures==0 else 1)
func ui_rules() -> void:
	for role_id in [240,241]:
		for number in range(1,9):
			var id:="c%d"%(role_id*100+number);var face:=preload("res://scripts/ui/card_face.gd").new();face.data=Content.card_def(id);face.refresh_art()
			check(face._original_card!=null and face._original_card.resource_path=="res://assets/official/cards/"+id+".png","original native artwork "+id);face.free()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["heitongzi","baitongzi","shuweng","taohuayao"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],240241);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.deck.clear();side.energy=40;side.levelUpUsed=true
			for u in side.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var gs=b.gs;var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
		p.deck.append(instance(gs,"c24107"));hand(b,["c24001"]);await settled(b)
		await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.get("type")=="native-link" and is_instance_valid(b._choice_layer),"native black card opens real two-card link")
		check(choice_face(b,"c24001")!=null and choice_face(b,"c24107")!=null and p.energy==40 and p.hand.size()==1 and p.deck.size()==1,"native link offers both original images without cost before choosing")
		await capture("%d-01-link-choice"%physical.x)
		var tile:=choice_face(b,"c24107")
		if tile!=null:await click(tile)
		await settled(b)
		check(gs.pending_choice.is_empty() and p.units[1].get("inspired",false) and p.units[1].form.get("cardId")=="c24107","native mouse chooses white linked form and receives real enhanced inspired")
		check(p.energy==39 and p.hand.is_empty() and p.deck.size()==1 and p.deck[0].definitionId=="c24001","native selection pays once and swaps original into deck")
		gs.VerifiedRules.Forms.remove(gs,0,1,"test reset");p.units[1].erase("inspired");gs._awaken(0,0,Content.card_def("c24006"),{"attack":1,"hp":1});p.deck.clear();p.deck.append(instance(gs,"c24107"));foe.units[0].front=1;gs._grow_unit(foe.units[0],0,25)
		hand(b,["c24008"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		tile=choice_face(b,"c24008");check(tile!=null,"native link offers original double slash")
		if tile!=null:await click(tile)
		await settled(b)
		check(gs.pending_choice.get("type")=="black-white-second" and BW.combat_immune(p.units[0]),"native original linked slash pauses for actual second target with combat immunity")
		check(choice_face(b,"avatar-1")!=null and choice_face(b,str(foe.units[2].uid))!=null,"native slash offers enemy player and reserve units")
		var target_tile:=choice_face(b,str(foe.units[2].uid));var face_tile:=choice_face(b,"avatar-1")
		check(target_tile!=null and "力量 3" in target_tile.data.text and "生命 4/4" in target_tile.data.text and "护甲 0" in target_tile.data.text and face_tile!=null and "牌手生命 30" in face_tile.data.text,"native second-target cards show actual current health power and armor")
		await capture("%d-02-second-attack"%physical.x)
		var hp:int=foe.units[2].hp;tile=choice_face(b,str(foe.units[2].uid))
		if tile!=null:await click(tile)
		await settled(b)
		check(gs.pending_choice.is_empty() and foe.units[2].hp==hp-4 and not BW.combat_immune(p.units[0]),"native selected second attack uses awakened source power then ends immunity")
		check(p.hand.size()==1 and p.hand[0].definitionId=="c24107" and p.deck.is_empty(),"native awakened link retrieves unused card after attack sequence")
		p.deck.clear();p.deck.append(instance(gs,"c12001"));hand(b,["c24002"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(p.units[1].uid).selected and not b._unit_widget(foe.units[1].uid).selected,"native replace highlights own shikigami only")
		await click(b._unit_widget(p.units[1].uid));await settled(b)
		check(p.units[1].front==1 and p.hand.size()==1 and p.hand[0].definitionId=="c12001","native replace really moves white partner and draws one")
		gs._knockout_unit(p.units[0],1,0);gs._resolve_resolution_stack();p.deck.clear();hand(b,["c24102"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(p.units[0].uid).selected and not b._unit_widget(p.units[1].uid).selected,"native soul shows only knocked-out allies")
		await click(b._unit_widget(p.units[0].uid));await settled(b)
		check(p.units[0].hp==p.units[0].maxHp and p.units[0].knockout==0 and p.hand.is_empty(),"native soul really revives chosen black partner")
		b.queue_free();await process_frame;await process_frame
