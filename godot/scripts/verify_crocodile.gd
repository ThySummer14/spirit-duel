extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Croc := preload("res://scripts/crocodile_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("CROCODILE_FAIL ",detail)
func game(own: Array=["yinge","shuweng","shantong","taohuayao"]) -> GS:
	var gs:=GS.create(own,["bingyong","fenghuanghuo","xuenv","baizangzhu"],279)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.rule_events.clear(); return gs
func give(gs,id: String) -> int:
	gs.player(0).hand.append({"instanceId":"croc-test-%d"%gs.next_card_id,"definitionId":id}); gs.next_card_id+=1
	return gs.player(0).hand.size()-1
func play(gs,id: String,target=null) -> void:
	var idx:=give(gs,id); var reason:Dictionary=gs.can_play_card(0,idx,target)
	check(gs.play_card(0,idx,target),"actualuse "+id+" "+str(reason))
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func knock(gs,owner: int,idx: int) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0); gs._resolve_resolution_stack()
func upgrades_and_growth() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]
	check(u.baseAttack==2 and u.maxHp==4 and u.attack==3 and Croc.attached(u),"openingfirstactualupgradeattaches1powercharmtobase2/4")
	check(u.passive_hooks.is_empty() and p.hand.is_empty(),"nolegacycombatresolvedgrowthorfakegeneratedcards")
	Croc.upgraded(gs,0,0); check(events(gs,"crocodile-attached").is_empty(),"firstupgradeonlyonce")
	var face:int=gs.player(1).avatarHp; check(gs.basic_attack(0,0),"actualshadowdeployment")
	check(u.attack==4 and gs.player(1).avatarHp==face-4 and Croc.stats(gs,0).attack==2,"deploymentenhancespermanentcharmeffectbeforeattack")
	u.inspired=true; face=gs.player(1).avatarHp; gs.basic_attack(0,0)
	check(u.attack==5 and Croc.stats(gs,0).attack==3 and gs.player(1).avatarHp==face-5,"originalbasehasnoinventedonceperturnrestriction")
	var a:Dictionary=p.units[1]; play(gs,"c27901",a.uid)
	check(not Croc.attached(u) and Croc.attached(a) and u.attack==2 and a.attack==4,"uniqueghostmovestoselectedallywithall3power")
	u.inspired=true; gs.basic_attack(0,0)
	check(u.attack==3 and Croc.stats(gs,0).attack==3,"uncharmedshadowgainsordinarybodypowernotsharedgrowth")
	var hp:int=a.hp; play(gs,"c27901",a.uid)
	check(Croc.stats(gs,0).attack==4 and Croc.stats(gs,0).hp==1 and a.attack==5 and a.hp==hp+1,"repeatednixienhancesactualexistingeffect1/1")
	check(p.units.filter(func(x):return Croc.attached(x)).size()==1,"uniqueeffectcannotstackormultiplycarriers")
	gs=game(["shuweng","yinge","shantong","taohuayao"]); p=gs.player(0); u=p.units[1]
	check(not Croc.attached(u),"inactivelevel0shadowhasnobootcharm")
	u.level=0; p.levelUpUsed=false; gs.turn_counter=2
	check(gs.level_up(0,1) and Croc.attached(u) and u.crocFirstUpgrade,"actualselectedfirstupgradealsoattachesghost")
	Croc.detach(gs,u); p.levelUpUsed=false; gs.turn_counter=4; gs.level_up(0,1)
	check(not Croc.attached(u),"laterupgradecannotregeneratefirstupgradeghost")
func combat_cards() -> void:
	for carries in [false,true]:
		var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; var foe:Dictionary=gs.player(1)
		if not carries: Croc.detach(gs,u)
		foe.units[0].front=1; foe.units[0].hp=1; var face:int=foe.avatarHp; var power:int=u.attack
		play(gs,"c27902")
		check(foe.units[0].hp==0 and foe.avatarHp==face-power,"printed+1combatpierceswithoutfakegrowth "+str(carries))
		check(bool(Croc.stats(gs,0).pierce)==carries and u.attack==power,"onlycharmedsourcepermanentlyenhancespierce "+str(carries))
		gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1)
		if not carries: Croc.detach(gs,u)
		gs._grow_unit(foe.units[1],20,0); foe.units[1].hp=2; foe.units[0].front=1; var hp:int=u.hp
		play(gs,"c27905",foe.units[1].uid)
		check(foe.units[1].hp==0 and u.hp==hp and foe.units[0].hp>0,"printed+2firststrikerealpursuitkillreservebeforecounter "+str(carries))
		check(bool(Croc.stats(gs,0).attackFirst)==carries,"onlycharmedsourcekeepsattackfirst "+str(carries))
		gs=game(); p=gs.player(0); u=p.units[0]
		if not carries: Croc.detach(gs,u)
		power=u.attack; hp=u.hp; play(gs,"c27908")
		check(u.attack==power+(2 if carries else 0) and u.maxHp==hp+(2 if carries else 0) and u.shield==1,"devourprinted+1/+1andconditionalpermanent2/2 "+str(carries))
		check(Croc.stats(gs,0).attack==(3 if carries else 1),"uncharmeddevourcannotinvent2/2 "+str(carries))
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]
	play(gs,"c27902"); play(gs,"c27905","avatar-1"); Croc.attach(gs,0,0,p.units[2]); var a:Dictionary=p.units[2]
	check(gs.VerifiedRules.Combat.has(a,"pierce") and not gs.VerifiedRules.Combat.has(a,"first-strike") and Croc.attack_first(a),"migratedpierceandattackonlyfirststrikeareseparatefromdefensivefirststrike")
	gs._grow_unit(foe.units[1],20,0); foe.units[1].hp=1; foe.units[1].front=1; var hp:int=a.hp; gs.basic_attack(0,2)
	check(foe.units[1].hp==0 and a.hp==hp,"migratedcharmrealoffensivefirststrikepreventscounter")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; Croc.enhance(gs,0,0,0,"attackFirst"); u.front=1; foe.units[1].hp=2; var power:int=foe.units[1].attack; hp=u.hp; gs.current_player=1
	gs.basic_attack(1,1)
	check(u.hp==hp-power,"attackonlyfirststrikedoesnotgrantdefenderpreemptivekill")
func realm_awakening_form() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; var a:Dictionary=p.units[1]; var fire:int=p.energy
	play(gs,"c27903",a.uid)
	check(p.energy==fire-1 and p.realms.size()==1 and p.realms[0].hp==5 and a.swift and not Croc.attached(u),"original5durrealmdeploysthenattachesandgrantsswift")
	a.swift=false; play(gs,"c27901",a.uid)
	check(not a.swift and p.realms[0].hp==5,"repeatedenhancementisnotreattachmentanddoesnotinventswiftordurabilityloss")
	Croc.attach(gs,0,0,p.units[2]); check(p.units[2].swift,"newcarrierattachmentactuallygrantsswift")
	gs.end_turn(0); check(p.units[2].swift,"realmswifthasnoturnexpiry")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c27904")
	check(u.awakened and u.attack==4 and u.maxHp==5 and p.crocNixiWhileKnocked,"awakeningreal1/1andgamewidenixipermission")
	check(not gs.can_play_card(0,give(gs,"c27904")).ok,"awakeningcannotrepeat")
	p.hand.clear(); var before:int=p.units[1].attack; gs.basic_attack(0,1)
	check(p.units[1].attack==before+1 and Croc.stats(gs,0).attack==1,"awakeotheruncharmedallygainsbody1notghostgrowth")
	play(gs,"c27901",p.units[2].uid); p.units[2].inspired=true; before=p.units[2].attack; gs.basic_attack(0,2)
	check(p.units[2].attack==before+1 and Croc.stats(gs,0).attack==2,"awakecharmedallyenhancesghost")
	knock(gs,0,0); before=p.units[2].attack; p.units[2].inspired=true; gs.basic_attack(0,2)
	check(p.units[2].attack==before+1 and u.hp==0,"awakenedabilityexplicitlyworkswhilehostKO")
	var idx:=give(gs,"c27901"); fire=p.energy
	check(gs.hand_card_def(0,idx).allowKnockedSource and gs.play_card(0,idx,p.units[1].uid) and u.hp==0 and p.energy==fire-1,"actualnixifromKOdoesnotrevivesource")
	gs=game(); p=gs.player(0); u=p.units[0]; knock(gs,0,0); idx=give(gs,"c27901")
	check(not gs.can_play_card(0,idx,p.units[1].uid).ok,"nonawakeKOnixiremainsillegal")
	gs=game(); p=gs.player(0); u=p.units[0]; idx=give(gs,"c27907"); var stamp:=JSON.stringify(gs.snapshot()); var card:Dictionary=gs.hand_card_def(0,idx)
	check(card.enhanced and card.keywords.has("instant") and JSON.stringify(gs.snapshot())==stamp,"formenhancementqueriespureandinstantonlywhenattached")
	check(gs.play_card(0,idx) and u.attack==6 and u.maxHp==6,"originalform5/6plusghostnotfake4/4growth")
	var a2:Dictionary=p.units[2]; var hp:int=a2.hp; var face:int=gs.player(1).avatarHp
	gs.basic_attack(0,2)
	check(Croc.attached(a2) and not Croc.attached(u) and u.attack==5 and a2.hp==hp and gs.player(1).avatarHp==face-a2.attack,"formdeploymentreallymovesghostbeforeattackingwithoutfakeHPgrowth")
	gs=game(); p=gs.player(0); u=p.units[0]; Croc.detach(gs,u); idx=give(gs,"c27907"); check(not gs.hand_card_def(0,idx).keywords.has("instant"),"uncharmedformcannotbeinstant")
func hunt_and_lifecycles() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var a:Dictionary=p.units[2]; var u:Dictionary=p.units[0]; foe.units[0].front=1; gs._grow_unit(foe.units[0],20,20); var hp:int=a.hp; var ehp:int=foe.units[0].hp; var fire:int=p.energy; u.spellPower=50
	play(gs,"c27906",a.uid)
	check(Croc.attached(a) and a.front==1 and u.front==0 and a.hp==hp,"huntcommandsactualselectedallywithcombatimmunity")
	check(foe.units[0].hp==ehp-a.attack and p.energy==fire-1 and not p.attackUsed,"commandedattackisactualcombatnotspelldamageoradditionaldeploymentpayment")
	check(Croc.stats(gs,0).attack==1,"commandedattackdoesnottriggerdeploymentgrowth")
	check(gs.basic_attack(0,2),"huntdoesnotconsumeordinarydeploymentaction")
	var idx:=give(gs,"c27906"); a.frozen=1; var ts:Array=gs.valid_targets(0,gs.hand_card_def(0,idx)); check(not ts.has(a.uid),"huntcannotcommandstunnedally")
	p.units[1].level=0; check(not gs.valid_targets(0,gs.hand_card_def(0,idx)).has(p.units[1].uid),"huntcannotcommandinactiveally")
	check(not gs.play_card(0,idx,foe.units[1].uid),"huntrejectsenemytarget")
	gs=game(); p=gs.player(0); u=p.units[0]; Croc.enhance(gs,0,3,2,"pierce"); Croc.enhance(gs,0,0,0,"attackFirst"); Croc.attach(gs,0,0,p.units[1]); a=p.units[1]; hp=a.hp; knock(gs,0,1)
	check(not Croc.attached(a) and a.hp==0 and a.attack==int(Content.unit_def(a.id).attack),"actualKOclearsghostandborrowedstatswithoutrevival")
	check(Croc.stats(gs,0).attack==4 and Croc.stats(gs,0).hp==2 and Croc.stats(gs,0).pierce,"permanenteffectledgerisnotthecarrierbodyandpersistsKO")
	play(gs,"c27901",p.units[2].uid)
	check(p.units[2].attack==7 and p.units[2].maxHp==6 and Croc.attack_first(p.units[2]),"freshattachmentafterKOretainsfullgrownbodyandtraits")
	gs.VerifiedRules.Moon.full_moon(gs,p.units[2]); check(not Croc.attached(p.units[2]) and p.units[2].maxHp==4,"fullmoonremovesactualghoststatbonus")
	gs=game(); p=gs.player(0); Croc.attach(gs,1,3,p.units[2]); gs.VerifiedRules.PipeFox.cleanse(gs,0,0)
	check(not Croc.attached(p.units[2]),"whitefoxremovesenemyownedghost")
	gs=game(); p=gs.player(0); u=p.units[0]; gs._install_form(0,0,{"id":"substitute-test","name":"替身","value":{"attack":2,"hp":4},"formRules":{"substitute":true}}, {"attack":2,"hp":4,"setBase":true}); knock(gs,0,0)
	check(u.hp==4 and u.knockout==0 and not Croc.attached(u),"substituteclearsghostwithoutfakedeath")
func ai_and_boundaries() -> void:
	for n in range(1,9):
		var gs:=game(); var id:="c279%02d"%n; give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualoriginal "+id)
		check(Content.card_def(id).cost==1 and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalcostandPNG "+id)
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; var fire:int=p.energy; var idx:=give(gs,"c27901"); var stamp:=JSON.stringify(gs.snapshot()); gs.hand_card_def(0,idx); gs.valid_targets(0,gs.hand_card_def(0,idx)); gs.can_play_card(0,idx,p.units[2].uid)
	check(JSON.stringify(gs.snapshot())==stamp,"allquerypathsleavecharmandledgeruntouched")
	check(not gs.play_card(0,idx,gs.player(1).units[0].uid) and p.energy==fire,"invalidallycostsnothing")
	p.nullifyNextCardTurn=gs.turn_counter; play(gs,"c27901",p.units[2].uid)
	check(Croc.attached(u) and not Croc.attached(p.units[2]) and Croc.stats(gs,0).attack==1,"counterednixicannotmoveorgrowghost")
	gs=game(); p=gs.player(0); play(gs,"c27904"); knock(gs,0,0); give(gs,"c27901"); var best:=AI._best_card(gs,0)
	check(best.ok and gs.play_card(0,best.hand,best.target),"AIlegallyusesrealnixifromKO")
	gs=game(["yinge","huajing","hudiejing","taohuayao"]); p=gs.player(0); p.units[1].level=3; p.units[2].level=3; play(gs,"c27904"); Croc.attach(gs,0,0,p.units[2]); gs.VerifiedRules.Whale.attach(gs,0,1,p.units[2],"Tooth"); gs._push_card_frames(0,"c27402",gs.player(1).units[0].uid,Content.card_def("c27402"),2,0); gs._resolve_resolution_stack(); var before:int=Croc.stats(gs,0).attack; var face:int=gs.player(1).avatarHp; var hp:int=gs.player(1).units[1].hp
	check(gs.basic_attack(0,2,gs.player(1).units[1].uid) and p.units[2].front==0 and Croc.stats(gs,0).attack==before+1 and p.units[1].charge==1,"realspellwarskillstilltriggersshadowgrowthandwhalechargewithoutinventedattack")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["yinge","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],279); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for x in side.units: x.level=3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs=b.gs; var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]
		hand(b,["c27903"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(p.units[2].uid)).selected,"nativerealmrequiresrealentryallytarget")
		await capture("%d-01-realm-entry-target"%physical.x)
		await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		check(Croc.attached(p.units[2]) and p.units[2].swift and p.realms.size()==1,"nativerealmattachesandgrantsactualswift")
		hand(b,["c27904"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(u.awakened and Croc.attached(u),"nativeprintedawakeningandghost")
		foe.units[0].front=1; foe.units[1].hp=2; b._refresh(); hand(b,["c27905"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._unit_widget(str(foe.units[1].uid)).selected,"nativepursuitselectsactualreserveenemy")
		await capture("%d-02-pursuit-target"%physical.x)
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(foe.units[1].hp==0 and Croc.stats(gs,0).attackFirst,"nativefirststrikepursuitkillandenhance")
		knock(gs,0,0); b._refresh(); hand(b,["c27901"]); await settled(b); var fire:int=p.energy
		check(b._hand_row.get_child(0).data.allowKnockedSource,"nativehandshowsrealKOpermission")
		await click(b._hand_row.get_child(0)); await settled(b); await capture("%d-03-knocked-nixi-target"%physical.x)
		await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		check(u.hp==0 and Croc.attached(p.units[2]) and p.energy==fire-1,"nativeactualnixipaymentwhilehoststaysKO")
		gs.VerifiedRules.Peach.revive(gs,0,3,u,false,false); foe.units[0].front=1; gs._grow_unit(foe.units[0],8,20); var hp:int=p.units[1].hp
		hand(b,["c27906"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(p.units[1].front==1 and p.units[1].hp==hp and Croc.attached(p.units[1]),"nativehuntcommandsactualfriendlyattackerwithimmunity")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	upgrades_and_growth(); combat_cards(); realm_awakening_form(); hunt_and_lifecycles(); ai_and_boundaries()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("CROCODILE_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]); quit(0 if failures==0 else 1)
