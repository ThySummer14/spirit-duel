extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Oni := preload("res://scripts/onikiri_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("ONIKIRI_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["guiqie","yaodaoji","taohuayao","shantu"],["fenghuanghuo","bingyong","xuenv","baizangzhu"],191)
	if not gs.pending_choice.is_empty():gs.resolve_divination_choice(0,"onikiri-hige")
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true;p.avatarArmor=0
		for u in p.units:u.level=3
	Oni.remove_charms(gs.player(0).units[0]);gs.rule_events.clear()
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"onikiri-fixture-%d"%gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actualhandplay "+id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func enemy_turn(gs) -> void:
	check(gs.end_turn(0),"realownturnend")
	gs.player(1).levelUpUsed=true;gs.player(1).energy=40
func choice_and_body() -> void:
	var gs:=GS.create(["guiqie","yaodaoji","taohuayao","shantu"],["fenghuanghuo","bingyong","xuenv","baizangzhu"],191)
	var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
	check(gs.pending_choice.get("type")=="onikiri-charm" and gs.pending_choice.instanceIds==Oni.CHARMS,"naturalstartpausehas3distinctrealcharms")
	check(p.hand.size()==int(gs.rules.openingHandSize)-1 and gs.resolution_stack.any(func(f):return f.kind=="turn-retreat-draw"),"choicepausesbeforenormaldrawwithcontinuationpreserved")
	check(not gs.end_turn(0) and not gs.resolve_divination_choice(1,"onikiri-hige") and not gs.resolve_divination_choice(0,"c19101"),"unfinishedchoiceblocksactions,rejectswrongownerandinvalidid")
	check(gs.resolve_divination_choice(0,"onikiri-hige") and p.hand.size()==int(gs.rules.openingHandSize) and u.front==0 and Oni.charms(u)==["onikiri-hige"],"actualchoiceattachesandresumesexactnormaldraw")
	gs=game();p=gs.player(0);u=p.units[0];var deck: int=p.deck.size()
	check(u.attack==2 and u.maxHp==4 and u.passive_hooks.is_empty(),"baseexact2/4withoutoldgrowth")
	Oni.attach(gs,0,0,"onikiri-hige");play(gs,"c19102")
	check(u.front==1 and u.shield==0 and gs.pending_choice.type=="onikiri-charm" and not gs.pending_choice.instanceIds.has("onikiri-hige") and p.deck.size()==deck,"flashrealmove,onlyunattachedoptions,beforedraw")
	check(gs.resolve_divination_choice(0,"onikiri-tomo") and p.deck.size()==deck-1 and Oni.charms(u).size()==2,"flashchoiceactuallyattachesdistinctanddrawsone")
	Oni.attach(gs,0,0,"onikiri-lion");play(gs,"c19102");check(gs.pending_choice.is_empty() and p.deck.size()==deck-2 and Oni.charms(u).size()==3,"fullthreecharmsflashstilldrawswithoutinventedchoice")
	gs.VerifiedRules.Moon.full_moon(gs,u);check(Oni.charms(u).is_empty(),"realmoonremovesall3ghostcharms")
	play(gs,"c19104");check(u.attack==2 and u.maxHp==6 and u.shield==0,"scattertrue2/6noinventedarmor")
	enemy_turn(gs);check(u.attack==5,"enemyturncontinuousactual+3power")
	check(gs.end_turn(1),"realenemyturnend")
	if not gs.pending_choice.is_empty():gs.resolve_divination_choice(0,"onikiri-hige")
	check(u.attack==2,"scatterownturncorrectlylosesonlyconditional3")
func beard_and_echo() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-hige")
	var hp: int=foe.units[1].hp
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack()
	check(foe.units[1].hp==hp and Oni.charms(u).has("onikiri-hige"),"ownturnenemyentrycannottriggerenemyturncharm")
	foe.units[1].front=0;enemy_turn(gs);hp=foe.units[1].hp
	check(gs.basic_attack(1,1),"actualenemybasicattackentersfront")
	check(foe.units[1].hp==hp-2 and foe.units[1].shield==0 and u.hp==3 and not Oni.charms(u).has("onikiri-hige"),"beardrealextra2consumesenemyarmor2thenoriginalcombatcounter2,consumescharm")
	check(events(gs,"onikiri-extra-attack").size()==1,"beardexactonefreeextraattack")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-hige");give(gs,"c19101");enemy_turn(gs);var fire: int=p.energy;gs._grow_unit(foe.units[1],30,20)
	check(gs.basic_attack(1,1),"actualenemyentryagainstresponsebeard")
	check(foe.units[1].hp==0 and u.hp==4 and p.energy==fire-1 and p.hand.is_empty(),"paidbeardresponse+2/+1truelethal,immuneandkillsbeforeoriginalattack")
	check(events(gs,"onikiri-hand-response").size()==1 and events(gs,"combat-complete").size()==1,"responsemodifiesghostbattleinsteadofextraunrelatedcombat")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-hige");give(gs,"c19101");p.energy=0;enemy_turn(gs);hp=foe.units[1].hp
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack()
	check(foe.units[1].hp==hp and foe.units[1].shield==0 and p.hand.size()==1 and events(gs,"onikiri-hand-response").is_empty(),"zerofireunawakenedresponsecannotpaybutbaseghoststillworks")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c19103");u.front=1;Oni.attach(gs,0,0,"onikiri-hige");enemy_turn(gs);gs._grow_unit(foe.units[1],30,20);hp=foe.units[1].hp
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack()
	check(foe.units[1].hp==hp-4 and foe.units[1].shield==0 and u.hp==8 and events(gs,"onikiri-extra-attack").size()==2,"bladeechocopiesghostonce,eachtrue3absorbsrealarmor2andfullcombatimmunity")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c19103");u.front=1;Oni.attach(gs,0,0,"onikiri-hige");enemy_turn(gs);foe.units[1].hp=1;var avatar: int=foe.avatarHp
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack();check(foe.units[1].hp==0 and events(gs,"onikiri-extra-attack").size()==1 and foe.avatarHp==avatar,"deadechotargetskipssecondattackwithoutretargetingavatar")
	var monk_gs:=GS.create(["guiqie","yaodaoji","taohuayao","shantu"],["duyanxiaoseng","bingyong","xuenv","baizangzhu"],191)
	if not monk_gs.pending_choice.is_empty():monk_gs.resolve_divination_choice(0,"onikiri-hige")
	for side in monk_gs.players:
		side.levelUpUsed=true;side.hand.clear()
		for unit in side.units:unit.level=3
	monk_gs.player(0).units[0].front=1;enemy_turn(monk_gs);var monk_hp: int=monk_gs.player(0).units[0].hp
	monk_gs.VerifiedRules.Movement.move_to(monk_gs,1,0,1);monk_gs._resolve_resolution_stack()
	check(monk_gs.player(0).units[0].hp==monk_hp and monk_gs.player(1).units[0].hp==4,"ghostbattleimmuneincludesrealmonknoncombatretaliation")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c19106");Oni.attach(gs,0,0,"onikiri-hige");enemy_turn(gs);hp=foe.units[1].hp
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack();check(u.front==1 and foe.units[1].hp==hp and foe.units[1].shield==0 and events(gs,"onikiri-extra-attack").size()==1,"revengeactualbackrowtriggerentersfrontandattacks")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];Oni.attach(gs,0,0,"onikiri-hige");enemy_turn(gs);hp=foe.units[1].hp
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack();check(u.front==0 and foe.units[1].hp==hp and Oni.charms(u).has("onikiri-hige"),"plainbackrowsourcenoteligiblewithoutrevenge")
func response_constraints() -> void:
	var gs:=GS.create(["guiqie","yaodaoji","taohuayao","shantu"],["fenghuanghuo","bingyong","xuenv","xingxiongtongzi"],191)
	gs.resolve_divination_choice(0,"onikiri-hige")
	for side in gs.players:
		side.hand.clear();side.energy=40;side.levelUpUsed=true
		for unit in side.units:unit.level=3
	var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];var foe: Dictionary=gs.player(1)
	u.front=1;give(gs,"c19101");enemy_turn(gs);play(gs,"c25107",null,1)
	gs.VerifiedRules.MonkCleaner.enrage(gs,0,0)
	check(gs.VerifiedRules.StarBear.locked(gs,0,u),"realstarformlocksactualenragedOnikiri")
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack()
	check(p.hand.size()==1 and events(gs,"onikiri-hand-response").is_empty() and events(gs,"onikiri-extra-attack").size()==1,"starhandlockblocksresponsecardbutfreeghoststilltriggers")
	gs=game();p=gs.player(0);u=p.units[0];foe=gs.player(1);u.front=1;Oni.attach(gs,0,0,"onikiri-hige");give(gs,"c19101");enemy_turn(gs)
	p.nullifyNextCardTurn=gs.turn_counter
	var hp: int=foe.units[1].hp;var fire: int=p.energy
	gs.VerifiedRules.Movement.move_to(gs,1,1,1);gs._resolve_resolution_stack()
	check(p.hand.is_empty() and p.energy==fire-1 and events(gs,"card-nullified").size()==1,"responseisrealpaidannouncedcardandcanbeCountered")
	check(foe.units[1].hp==hp and foe.units[1].shield==0 and events(gs,"onikiri-extra-attack").size()==1,"counteredtwocutdoesnotgrantbufforlethalbutoriginalghoststillcompletes")
func friend_counter() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-tomo");give(gs,"c19105");enemy_turn(gs);var hp: int=p.units[3].hp;var fire: int=p.energy
	play(gs,"c12404",p.units[3].uid,1)
	check(foe.units[0].hp==0 and p.units[3].hp==hp and p.energy==fire-1 and p.hand.is_empty(),"friendresponsekillsactualcasterbeforefirstspelleffectandpaysone")
	check(events(gs,"onikiri-spell-countered").size()==1 and not Oni.charms(u).has("onikiri-tomo"),"rochengwholeoriginalspellcounteredonlyaftertruekill")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-tomo");give(gs,"c19105");enemy_turn(gs);gs._grow_unit(foe.units[0],0,20);hp=foe.units[0].hp
	play(gs,"c12404",p.units[3].uid,1)
	check(foe.units[0].hp==hp-4 and p.units[3].hp==0 and events(gs,"onikiri-spell-countered").is_empty(),"survivingcasterspellstillresolvesallnormaldamage,nofakecounter")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-tomo");enemy_turn(gs);foe.units[0].hp=2
	play(gs,"c12404",p.units[3].uid,1)
	check(foe.units[0].hp==0 and p.units[3].hp==0 and events(gs,"onikiri-spell-countered").is_empty(),"barefriendkillingcasterdoesnotcounteralreadyannouncedspell")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-tomo");enemy_turn(gs);hp=foe.units[0].hp
	var card: Dictionary=Content.card_def("c12404");gs._push_card_frames(1,"c12404",p.units[3].uid,card,0,0,true);gs._resolve_resolution_stack()
	check(foe.units[0].hp==hp and Oni.charms(u).has("onikiri-tomo") and p.units[3].hp==0,"pureautomaticgeneratedspellcannottriggerfriend")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-tomo");enemy_turn(gs)
	play(gs,"c10604",null,1);check(Oni.charms(u).has("onikiri-tomo") and events(gs,"onikiri-extra-attack").is_empty(),"enemyformisnotspellanddoesnotconsumeFriend")
func lion_awake_manual() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-lion");enemy_turn(gs);var hp: int=foe.avatarHp
	check(gs.end_turn(1),"actualenemyturnendtriggerslion")
	check(foe.avatarHp==hp-4 and events(gs,"onikiri-extra-attack").size()==1 and not Oni.charms(u).has("onikiri-lion"),"liontrue2body+2temporaryattacksavatar,consumesone")
	if not gs.pending_choice.is_empty():gs.resolve_divination_choice(0,"onikiri-hige")
	check(u.attack==2,"liontemporary+2doesnotpersist")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-lion");give(gs,"c19108");enemy_turn(gs);hp=foe.avatarHp;var fire: int=p.energy
	gs.end_turn(1)
	check(foe.avatarHp==hp-14 and events(gs,"onikiri-hand-response").size()==1 and events(gs,"onikiri-hand-response")[0].cost==1 and events(gs,"onikiri-response-copied").size()==2,"lionresponsefirst+4then2truecopiedcards+2,total14withonepayment")
	check(events(gs,"automatic-card").filter(func(e):return e.card.id=="c19108").size()==2,"shadowcopiesareactualautomaticcardusesnotcomboormultiplier")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;Oni.attach(gs,0,0,"onikiri-lion");Oni.attach(gs,0,0,"onikiri-tomo");enemy_turn(gs);foe.units[1].front=1;hp=foe.avatarHp;gs.end_turn(1)
	check(foe.avatarHp==hp and not Oni.charms(u).has("onikiri-lion") and not Oni.charms(u).has("onikiri-tomo"),"blockedliondoesnotattackandendclearsallunawakenedcharms")
	gs=game();p=gs.player(0);u=p.units[0];Oni.attach(gs,0,0,"onikiri-hige");play(gs,"c19107");check(gs.pending_choice.type=="onikiri-battle" and gs.pending_choice.instanceIds==Oni.BATTLES,"awakechoosesrealcombatdefinitionnotfake2power")
	var deck: int=p.deck.size();check(gs.resolve_divination_choice(0,"c19105") and p.deck.size()==deck and p.hand[0].definitionId=="c19105" and u.attack==3 and u.maxHp==5,"awake1/1andchosennewrealcardwithoutdrawingdeck")
	check(gs.hand_card_def(0,0).keywords.has("instant") and not Content.card_def("c19107").keywords.has("instant"),"awakeonlycombatinstant,awakeningitselfnotinstant")
	u.front=1;p.energy=0;enemy_turn(gs);gs._grow_unit(gs.player(1).units[0],0,20);var idx:=give(gs,"c19101");gs.kw_usage(0,"instant").used=false
	gs.VerifiedRules.Movement.move_to(gs,1,0,1);gs._resolve_resolution_stack();check(p.energy==0 and gs.kw_usage(0,"instant").used and not p.hand.any(func(entry):return entry.definitionId=="c19101"),"awakezerofireactualresponseusesnativeinstantallowance")
	Oni.attach(gs,0,0,"onikiri-lion");gs.player(1).units[1].front=1;gs.end_turn(1)
	check(Oni.charms(u).has("onikiri-lion"),"awakeuntriggeredcharmsretainedoverenemyturnend")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[1].front=1;var enemyhp: int=foe.units[1].hp;hp=foe.avatarHp
	play(gs,"c19108");check(foe.avatarHp==hp-4 and foe.units[1].hp==enemyhp and events(gs,"onikiri-response-copied").is_empty(),"manualshadowtruebypassfrontoneattackwithoutresponsecopies")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[1].front=1;gs._grow_unit(foe.units[1],0,20);play(gs,"c19101");check(foe.units[1].hp>0,"manualtwocutdoesnotgainresponse-onlylethal")
func ai_and_art() -> void:
	for n in range(1,9):
		var gs:=game();var id: String="c191%02d"%n;give(gs,id);var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualplay "+id)
		if not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty(),"AIactualchoice "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalPNG "+id)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["guiqie","yaodaoji","taohuayao","shantu"],["fenghuanghuo","bingyong","xuenv","baizangzhu"],191);b._ai_thinking=true
		root.add_child(b);await create_timer(0.4).timeout;await settled(b)
		check(b.gs.pending_choice.get("type")=="onikiri-charm" and faces(b._choice_layer).size()==3,"nativenaturalturnstartthreecharmchoices")
		if physical.x==1280:await capture("01-onikiri-natural-start-choice")
		var face:=choice_face(b,"onikiri-hige");check(face!=null,"nativeactualbeardcharmcard")
		if face!=null:await click(face)
		await settled(b);var gs=b.gs;var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
		check(gs.pending_choice.is_empty() and Oni.charms(u).has("onikiri-hige") and p.hand.size()==int(gs.rules.openingHandSize),"nativemousechoiceunpausesnormaldraw")
		for side in gs.players:
			side.hand.clear();side.energy=40;side.levelUpUsed=true
			for unit in side.units:unit.level=3
		hand(b,["c19102"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(u.front==1 and faces(b._choice_layer).size()==2 and choice_face(b,"onikiri-hige")==null,"nativeflashonlytwoactuallyunattachedchoices")
		face=choice_face(b,"onikiri-tomo")
		if face!=null:await click(face)
		await settled(b);check(Oni.charms(u).has("onikiri-tomo"),"nativemouseattachesfriend")
		hand(b,["c19107"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.get("type")=="onikiri-battle" and faces(b._choice_layer).size()==3,"nativeawakerealcombatcardchoice")
		if physical.x==1600:await capture("02-onikiri-awake-combat-choice")
		face=choice_face(b,"c19105")
		if face!=null:await click(face)
		await settled(b);check(p.hand.any(func(entry):return entry.definitionId=="c19105") and gs.hand_card_def(0,0).keywords.has("instant"),"nativechosenactualbattleinstanceinstant")
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	choice_and_body();beard_and_echo();response_constraints();friend_counter();lion_awake_manual();ai_and_art()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("ONIKIRI checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
