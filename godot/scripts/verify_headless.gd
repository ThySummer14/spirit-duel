extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Headless := preload("res://scripts/headless_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("HEADLESS_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["shouwu","yaodaoji","taohuayao","shantu"],["yaodaoji","bingyong","xuenv","baizangzhu"],260)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.avatarArmor=0
		for u in p.units: u.level=3
	return gs
func give(gs, id: String, owner: int = 0, generated: bool = false) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"headless-fixture-%d"%gs.next_card_id,"headlessGenerated":generated});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual handplay "+id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func sum_hp(gs, owner: int) -> int:
	var total:=0
	for u in gs.player(owner).units: total+=int(u.hp)
	return total
func base_and_fly() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0]
	check(u.attack==3 and u.maxHp==4 and u.passive_hooks.is_empty(),"base exact3/4 without old artificial aftercombat damage")
	var total:=sum_hp(gs,1);gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack()
	check(p.night==1 and sum_hp(gs,1)==total,"base failednight grants1, no fake randomdamage")
	gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack();check(p.night==1 and sum_hp(gs,1)==total,"base onceperrealturn includes failed threshold")
	gs.turn_counter+=1;p.night=3;foe.units[2].keywords=["veil"];gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack()
	check(p.night==3 and sum_hp(gs,1)==total-2 and events(gs,"headless-random-hit").size()==1,"base successful3 doesnotconsume, randomlive shikigami exact2")
	gs.turn_counter+=1;total=sum_hp(gs,1);gs._damage_avatar(0,1,0,0);gs._damage_avatar(1,1,0,1);gs._resolve_resolution_stack()
	check(sum_hp(gs,1)==total and events(gs,"headless-random-hit").size()==1,"self avatar andother source do not trigger")
	gs._knockout_unit(u);gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack();check(events(gs,"headless-random-hit").size()==1,"knocked source cannot triggerbase")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.baseRulesSuppressed=true;p.night=10;total=sum_hp(gs,1);gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack();check(sum_hp(gs,1)==total,"suppressed base cannot trigger")
	gs=game();p=gs.player(0);foe=gs.player(1);p.night=0;foe.units[1].front=1;var hp: int=foe.units[1].hp;var deck: int=p.deck.size();var fire: int=p.energy
	play(gs,"c26002");check(foe.units[1].hp==hp-1 and p.night==1 and p.deck.size()==deck and p.energy==fire,"fly actualbase1 projectile plus failednight3; firstinstantfree")
	p.night=3;play(gs,"c26002");check(foe.units[1].hp==hp-2 and p.deck.size()==deck-1 and p.energy==fire-1,"fly success draws exactly1, repeatedinstant actual1fire")
	gs=game();p=gs.player(0);p.night=2;deck=p.deck.size();play(gs,"c26002")
	check(p.night==3 and p.deck.size()==deck-1,"emptyfront projectile basefailed3 gainsnight then card threshold3 sees newlyreached3")
func awake_and_combat() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0]
	var avatar: int=foe.avatarHp;play(gs,"c26006");check(u.awakened and u.attack==4 and u.hp==5 and foe.avatarHp==avatar,"awake exact+1/+1 no fabricated facehit")
	check(not gs.can_play_card(0,give(gs,"c26006")).ok,"duplicate awake actualblocked")
	p.night=2;var total:=sum_hp(gs,1);gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack()
	var nights:=events(gs,"night-triggered")
	check(p.night==4 and total==sum_hp(gs,1) and nights.size()==2 and nights[0].threshold==3 and nights[1].threshold==7,"awake independent ordered3then7 fails gain2 total")
	gs.turn_counter+=1;p.night=7;total=sum_hp(gs,1);gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack()
	check(sum_hp(gs,1)==total-4 and p.night==7 and events(gs,"headless-random-hit").size()==2,"awake threshold3and7 separate randomexact2")
	gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack();check(events(gs,"headless-random-hit").size()==2,"awake wholebase remains onceperturn")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[1].front=1;gs._grow_unit(foe.units[1],0,20);var hp: int=foe.units[1].hp;p.night=4
	play(gs,"c26001");check(foe.units[1].hp==hp-4 and p.night==5 and u.shield==0 and u.hp==4,"failednight5 no crit even reaches5; true+1 attack/+1armor")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[1].front=1;gs._grow_unit(foe.units[1],0,20);hp=foe.units[1].hp;p.night=5
	play(gs,"c26001");check(foe.units[1].hp==hp-8 and p.night==5,"successful5 actualdouble crit onlyversusunit")
	gs=game();p=gs.player(0);foe=gs.player(1);p.night=5;avatar=foe.avatarHp;play(gs,"c26001");check(foe.avatarHp==avatar-4,"same crit doesnotdouble avatar")
	gs=game();p=gs.player(0);foe=gs.player(1);p.night=5;var idx:=give(gs,"c26004");check(gs.hand_card_def(0,idx).value==2,"nightfloor5/2 realhand+2")
	p.night=10;check(gs.hand_card_def(0,idx).value==5,"nightenhancement dynamichand+5 without fake extra5")
	foe.units[1].front=1;gs._grow_unit(foe.units[1],0,20);hp=foe.units[1].hp;check(gs.play_card(0,idx) and foe.units[1].hp==hp-8,"scare exact3+floor10/2 combat")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[1].front=1;hp=foe.units[1].hp;avatar=foe.avatarHp
	play(gs,"c26005");check(u.attack==3 and u.maxHp==6 and u.swift and p.energy==39,"form exact3/6, one swift, costs1 andnoartificialinstant")
	var fire: int=p.energy;check(gs.basic_attack(0,0) and foe.avatarHp==avatar-3 and foe.units[1].hp==hp and u.hp==6 and p.energy==fire,"form actualfirstbasicfree straighttoface blockedfrontunhurt")
	check(not u.swift and not gs.VerifiedRules.Combat.has(u,"direct"),"form direct scopedtooutgoingbasic notpermanentallcombat")
	p.attackUsed=false;check(gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u)==1,"swiftconsumed subsequentbasicpay1")
	gs._heal_unit(u,10);hp=foe.units[1].hp;avatar=foe.avatarHp;play(gs,"c26004");check(foe.units[1].hp==hp-3 and foe.avatarHp==avatar,"combatcard doesnotinheritbasicdirect")
func split_response() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0]
	foe.units[0].front=1;gs._grow_unit(foe.units[0],6,20);var hp: int=foe.units[0].hp;var avatar: int=foe.avatarHp
	play(gs,"c26003");check(foe.units[0].hp==hp-2 and foe.avatarHp==avatar-2 and u.hp==1,"active split actual-1attack, firstdamageecho2, lethaluncounterleaves1")
	check(not u.has("headlessSplitCombatId") and not u.get("combatUnyielding",false),"split lifetime cleanup afteractualcombat")
	gs._damage_unit(0,0,1,1,0);check(u.hp==0,"split doesnotgrantpersistentunyielding")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[1].front=1;foe.units[1].barrier=true;avatar=foe.avatarHp
	play(gs,"c26003");check(foe.avatarHp==avatar and events(gs,"headless-split-damage").is_empty(),"blockedfirstcombatdamage createsnoecho")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.front=1;give(gs,"c26003");gs.current_player=1;gs._grow_unit(foe.units[0],7,20);hp=foe.units[0].hp;avatar=foe.avatarHp;var fire: int=p.energy
	check(gs.basic_attack(1,0),"enemyactualbasic attack intoheadless")
	check(p.hand.is_empty() and p.energy==fire-1 and u.hp==1 and foe.units[0].hp==hp-2 and foe.avatarHp==avatar-2,"automaticresponse modifiescurrentdefence withreal-1counter, nosecondattack")
	check(events(gs,"headless-split-response").size()==1 and events(gs,"headless-split-damage").size()==1,"response exactlyonce actualfirstcounterecho")
	check(not u.has("headlessSplitCombatId"),"responsecleanup ondefender")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];p.units[1].front=1;give(gs,"c26003");gs.current_player=1;check(gs.basic_attack(1,0) and p.hand.size()==1,"otherallyattacked cannottriggerheadlessresponse")
	gs=game();p=gs.player(0);u=p.units[0];u.front=1;u.frozen=1;give(gs,"c26003");gs.current_player=1;gs.basic_attack(1,0);check(p.hand.size()==1,"actualstunblocksresponse")
	gs=game();p=gs.player(0);u=p.units[0];u.front=1;p.energy=0;give(gs,"c26003");gs.current_player=1;gs.basic_attack(1,0);check(p.hand.size()==1,"nofireblocksresponse")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.keywords=["combo"];foe.units[1].front=1;gs._grow_unit(foe.units[1],0,30);avatar=foe.avatarHp;play(gs,"c26003")
	check(events(gs,"headless-split-damage").size()==1 and foe.avatarHp==avatar-2,"doublehitfirstactualdamageecho oncepercombat")
func realm_and_return() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0]
	play(gs,"c26007");check(p.realms.size()==1 and p.realms[0].hp==8 and p.realms[0].nativeRealm=="headless-fire","true8durability realm withnofake3damage")
	p.night=9;var attack: int=p.units[1].attack;var avatar: int=foe.avatarHp;check(gs.basic_attack(0,1),"otherallyactualattack invokesrealm")
	check(p.night==10 and p.units[1].attack==attack and foe.avatarHp==avatar-attack,"failed10 reaches10 withoutpremature+2")
	p.attackUsed=false;avatar=foe.avatarHp;check(gs.basic_attack(0,1) and p.units[1].attack==attack+2 and foe.avatarHp==avatar-attack-2,"successful10 growsactualotherattacker beforepowersnapshot")
	var durability: int=p.realms[0].hp;gs._damage_avatar(0,2,1,0);check(p.realms[0].hp==durability-2,"realmtrueavatarlinkdurability")
	p.hand.clear();Headless.end_turn(gs,0);gs._resolve_resolution_stack();check(p.hand.is_empty(),"realmnohistory producesnocards")
	play(gs,"c26004");p.hand.clear();Headless.end_turn(gs,0);gs._resolve_resolution_stack()
	check(p.hand.size()==1 and p.hand[0].definitionId=="c26004" and p.hand[0].headlessGenerated,"realmactualhistory returnsnewgeneratedcopy onlyusedcombat")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];p.night=10;p.energy=0;foe.units[1].front=1;gs._grow_unit(foe.units[1],8,20);var hp: int=foe.units[1].hp
	var idx:=give(gs,"c26008");var iid: String=p.hand[idx].instanceId;var card:=gs.hand_card_def(0,idx);var before:=JSON.stringify(gs.snapshot());Headless.describe_card(gs,0,p.hand[idx],card);check(JSON.stringify(gs.snapshot())==before,"dynamicfreecarddescriptionreadonly")
	check(gs.valid_targets(0,card).has("avatar-1") and gs.valid_targets(0,card).has(foe.units[2].uid),"realanyenemy targetincludesfront,reserve,avatar")
	foe.units[2].keywords=["veil"];card=gs.hand_card_def(0,idx);check(not gs.valid_targets(0,card).has(foe.units[2].uid) and not gs.can_play_card(0,idx,p.units[1].uid).ok,"anyenemycard stillrejectsallyandveil")
	check(gs.play_card(0,idx,foe.units[1].uid) and p.energy==0 and foe.units[1].hp==hp-4 and u.hp==4 and u.shield==1,"truefree chosenenemycombat +1attack/+1armor andnight10immune")
	check(not u.get("immuneCombat",false),"night10immunityscopedtothisbattle")
	Headless.turn_start(gs,0);check(p.hand.any(func(inst):return inst.instanceId==iid),"usedactualinstance returnswithsameid")
	Headless.turn_start(gs,0);check(p.hand.filter(func(inst):return inst.instanceId==iid).size()==1,"alreadypresentinstance neverduplicated")
	p.hand.clear();p.night=9;Headless.turn_start(gs,0);check(p.hand.is_empty(),"night9neverreturnsusedcard")
	p.night=10;Headless.turn_start(gs,0);check(p.hand.any(func(inst):return inst.instanceId==iid),"nextnight10 returnsalreadyusedinstance again")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];p.energy=0;p.night=0;foe.units[1].front=1;gs._grow_unit(foe.units[1],6,20);play(gs,"c26008",foe.units[1].uid)
	check(u.hp==0 and p.night==1,"failed10noimmune evenfreecard, normallethalcounter")
	gs=game();p=gs.player(0);foe=gs.player(1);p.night=10;p.energy=0;foe.units[1].front=1;avatar=foe.avatarHp;hp=sum_hp(gs,1);play(gs,"c26008","avatar-1")
	check(foe.avatarHp==avatar-4 and sum_hp(gs,1)==hp-2 and events(gs,"headless-random-hit").size()==1,"actualchosenavatar bypassesfrontthenbasehitsrandomunitexact2")
	gs=game();p=gs.player(0);var original: Dictionary={"definitionId":"c26008","instanceId":"known-original-removed","customModifier":"preserved"};p.deck.append(original);Headless.track_zones(gs,0);p.deck.erase(original);p.night=10;Headless.turn_start(gs,0)
	check(p.hand.any(func(inst):return inst.instanceId==original.instanceId and inst.customModifier=="preserved"),"removedknownoriginal movesback asrealinstancewithmetadata")
	var deck_inst: Dictionary={"definitionId":"c26008","instanceId":"known-original-deck"};p.deck.append(deck_inst);Headless.turn_start(gs,0)
	check(p.hand.any(func(inst):return inst.instanceId==deck_inst.instanceId) and not p.deck.any(func(inst):return inst.instanceId==deck_inst.instanceId),"deckreturn removesactualdeckinstance")
	gs=game();p=gs.player(0);p.night=10;p.energy=0;idx=give(gs,"c26008",0,true);iid=p.hand[idx].instanceId;check(gs.play_card(0,idx,"avatar-1"),"generatedsamecard reallyplayablefree")
	Headless.turn_start(gs,0);check(p.hand.filter(func(inst):return inst.instanceId==iid).size()==1,"realgeneratedinstance also returnssameidwithnocopy")
	gs=game();p=gs.player(0);p.night=10;p.energy=0;idx=give(gs,"c26008");iid=p.hand[idx].instanceId;check(gs.play_card(0,idx,"avatar-1"),"returnfixture actualfreecard")
	check(gs.end_turn(0) and gs.end_turn(1),"realalternatingturnsfinishwithstartcallback")
	check(p.hand.filter(func(inst):return inst.instanceId==iid).size()==1,"naturalownturnstart returnsactualusedinstance once")
	gs=game();p=gs.player(0);p.night=10;p.energy=0;idx=give(gs,"c26008");iid=p.hand[idx].instanceId;p.nullifyNextCardTurn=gs.turn_counter;var hp_avatar: int=gs.player(1).avatarHp
	check(gs.play_card(0,idx,"avatar-1") and gs.player(1).avatarHp==hp_avatar,"realnullifiedfreecard causesnobattle")
	Headless.turn_start(gs,0);check(p.hand.filter(func(inst):return inst.instanceId==iid).size()==1,"counteredannouncedinstance notlost fromoffboardregistry")
	gs=game();p=gs.player(0);p.night=10;play(gs,"c26007");play(gs,"c26008","avatar-1");p.hand.clear();Headless.end_turn(gs,0);gs._resolve_resolution_stack()
	idx=p.hand.find_custom(func(inst):return inst.definitionId=="c26008" and inst.get("headlessGenerated",false));check(idx>=0,"actualrealmhistory generatesrealSSRinstance")
	if idx>=0:
		iid=p.hand[idx].instanceId;check(gs.play_card(0,idx,"avatar-1"),"actualrealmSSR instance plays")
		Headless.turn_start(gs,0);check(p.hand.filter(func(inst):return inst.instanceId==iid).size()==1,"actualrealmSSR usedinstance returnsoncewithsameid")
	gs=game();p=gs.player(0);p.night=10;p.energy=0;idx=give(gs,"c26008");iid=p.hand[idx].instanceId;check(gs.play_card(0,idx,"avatar-1"),"fullhandregistryfixture")
	for i in int(gs.rules.maxHandSize): give(gs,"c26004")
	Headless.turn_start(gs,0);check(p.hand.size()==int(gs.rules.maxHandSize) and not p.hand.any(func(inst):return inst.instanceId==iid),"fullhandreturndoesnotexceedrealcapacityorcopyinstance")
	p.hand.pop_back();gs._knockout_unit(p.units[0]);p.units[0].level=0;Headless.turn_start(gs,0)
	check(p.hand.filter(func(inst):return inst.instanceId==iid).size()==1,"offboardreturn independentofsourceknockoutandactivation")
func night_order() -> void:
	var gs:=GS.create(["shouwu","yecha","taohuayao","shantu"],["yaodaoji","bingyong","xuenv","baizangzhu"],260)
	for side in gs.players:
		side.hand.clear();side.energy=40;side.levelUpUsed=true
		for unit in side.units: unit.level=3
	var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);p.night=3;foe.units[1].front=1
	var attack: int=p.units[1].attack;var deck: int=p.deck.size();play(gs,"c26002")
	var ordered: Array=gs.rule_events.filter(func(e):return e.kind in ["headless-night-draw","yaksha-night-strength"])
	check(p.deck.size()==deck-1 and p.units[1].attack==attack+1 and ordered.size()==2,"coexistingyaksha trueflydrawandnightgrowth")
	check(ordered.size()==2 and ordered[0].kind=="headless-night-draw" and ordered[1].kind=="yaksha-night-strength","night3drawfullyresolvesbeforeyakshaaftereffectgrowth")
	p.units[0].headlessNightTurn=-1;p.units[0].awakened=true;p.units[1].awakened=true;p.night=7;var old_events: int=gs.rule_events.size()
	gs._damage_avatar(1,1,0,0);gs._resolve_resolution_stack()
	ordered=gs.rule_events.slice(old_events).filter(func(e):return e.kind in ["night-triggered","headless-random-hit","yaksha-night-strength"])
	check(ordered.size()==6 and ordered[0].kind=="night-triggered" and ordered[0].threshold==3 and ordered[1].kind=="headless-random-hit" and ordered[2].kind=="yaksha-night-strength" and ordered[3].kind=="night-triggered" and ordered[3].threshold==7 and ordered[4].kind=="headless-random-hit" and ordered[5].kind=="yaksha-night-strength","awakenedbase3effectthenyaksha then7effectthenyaksha")
func ai_art() -> void:
	for n in range(1,9):
		var gs:=game();var id: String="c260%02d"%n;give(gs,id);var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegallychooses "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactuallyexecutes "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalcardface "+id)
	var gs:=game();var p: Dictionary=gs.player(0);p.night=10;p.energy=0;gs.player(1).avatarHp=4;gs.player(1).units[1].front=1;give(gs,"c26008");var best:=AI._best_card(gs,0)
	check(best.ok and best.target=="avatar-1" and gs.play_card(0,best.hand,best.target) and gs.winner==0,"AI truezerofire directsfree lethalthroughblockedfront")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["shouwu","yaodaoji","taohuayao","shantu"],["yaodaoji","bingyong","xuenv","baizangzhu"],260);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.energy=40;side.levelUpUsed=true
			for unit in side.units: unit.level=3
		root.add_child(b);await create_timer(0.4).timeout
		var gs=b.gs;var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0];p.night=10;p.energy=0;foe.units[1].front=1;gs._grow_unit(foe.units[1],7,20)
		hand(b,["c26008"]);await settled(b);check(b._hand_row.get_child(0).playable,"nativezerofirecardenable")
		var iid: String=p.hand[0].instanceId;await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[2].uid)).selected,"nativeactualfreecombatpresentsallreservetargets")
		var fire: int=p.energy;await click(b._unit_widget(str(p.units[1].uid)));await settled(b);check(b._pending_target_card==0 and p.energy==fire,"nativeillegalallyspendsnothing")
		if physical.x==1600: await capture("01-headless-free-any-enemy-targets")
		var hp: int=foe.units[1].hp;await click(b._unit_widget(str(foe.units[1].uid)));await settled(b)
		check(foe.units[1].hp==hp-4 and u.hp==4 and p.energy==0,"nativerealclickfreebattle exact4andimmunity")
		Headless.turn_start(gs,0);b._refresh();await settled(b);check(p.hand.any(func(inst):return inst.instanceId==iid),"nativerealusedinstancehandreturn")
		p.hand.clear();p.energy=40;hand(b,["c26005"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(u.maxHp==6 and u.swift,"nativeformactual3/6swift")
		await click(b._unit_widget(str(u.uid)));await settled(b)
		if b._selected_attacker==0: await click(b._unit_widget(str(u.uid)));await settled(b)
		check(texts(b).contains("入夜10/10") and texts(b).contains("提首行骸"),"nativeinspectorreadonlynightandform")
		if physical.x==1280: await capture("02-headless-night-form-inspector")
		escape();await settled(b);b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	base_and_fly();awake_and_combat();split_response();realm_and_return();night_order();ai_art()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("HEADLESS checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
