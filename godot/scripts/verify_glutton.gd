extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Glutton := preload("res://scripts/glutton_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("GLUTTON_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["egui","fenghuanghuo","rulianshi","tianjingxia"],["fenghuanghuo","bingyong","yaodaoji","baizangzhu"],217)
	for p in gs.players:
		p.hand.clear();p.energy=80;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"glutton-test-%d" % gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actualcard "+id)
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func make_realm(gs, side: int, uid: String) -> void:
	gs.player(side).realms.append({"uid":uid,"hp":6,"name":"幻境验收","cardId":"c21703","sourceUnit":"egui","nativeRealm":"glutton-test","trigger":"none"})
func basics() -> void:
	var gs:=game();var u: Dictionary=gs.player(0).units[0]
	check(u.attack==1 and u.maxHp==6 and Content.unit_def("egui").passive.hooks.is_empty(),"original1/6 nofakeaftercombatheal")
	Glutton.attach(gs,0,0);check(u.attack==3 and u.gluttonSatiation.remaining==2,"realunique2powertimer2")
	Glutton.attach(gs,0,0);check(u.attack==3 and u.gluttonSatiation.remaining==2,"reattachrefresh no4powerstack")
	Glutton.turn_start(gs,1);check(u.attack==3 and u.gluttonSatiation.remaining==2,"enemybegin doesnotreduceowntimer")
	Glutton.turn_start(gs,0);check(u.attack==3 and u.gluttonSatiation.remaining==1,"firstownbegin countdown1")
	Glutton.turn_start(gs,0);check(u.attack==1 and not u.has("gluttonSatiation"),"secondownbegin actualremove notpersistentbuff")
	check(events(gs,"glutton-target-removed")==0,"expirationisnotnewconsumption reattachingforever")
	gs=game();u=gs.player(0).units[0];var defender: Dictionary=gs.player(1).units[1]
	defender.front=1;defender.shield=4;defender.shieldExpires=4
	play(gs,"c21701")
	check(defender.shield==0 and u.get("gluttonRemovedCount",0)==1,"rawremovesallarmor onceperset notperpoint")
	check(u.attack==3 and u.shield==3 and u.hp==6,"rawremoval actualattack%d shield%d hp%d" % [u.attack,u.shield,u.hp])
	check(defender.hp==2,"rawactual4powerattack1base1combat2charm")
	gs=game();u=gs.player(0).units[0];play(gs,"c21701")
	check(u.get("gluttonRemovedCount",0)==0 and not Glutton.satiated(u),"rawavatarhasnoarmorobject noremoval/nosatiety")
	gs=game();u=gs.player(0).units[0];Glutton.attach(gs,0,0)
	gs.VerifiedRules.Moon.full_moon(gs,u);check(not Glutton.satiated(u) and u.attack==1,"realmooncleanse removescharmbonus")
func realms_and_forms() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0]
	make_realm(gs,0,"keep-own");make_realm(gs,1,"remove-enemy")
	play(gs,"c21702")
	check(gs.pending_choice.get("type")=="glutton-realm" and foe.avatarHp==30,"realmselection pausesactualattack")
	check(Glutton.choice_card(gs,0,"keep-own")!=null and Glutton.choice_card(gs,0,"remove-enemy")!=null,"bothsidesrealm truechoiceobjects")
	check(not gs.resolve_divination_choice(0,"wrong") and gs.pending_choice.get("type")=="glutton-realm","rejectnonexistentrealm nofalseselection")
	check(gs.resolve_divination_choice(0,"remove-enemy"),"actualrealmchoicecommand")
	check(p.realms.size()==1 and foe.realms.is_empty() and foe.avatarHp==26,"removerealrealm then4powerattack")
	check(u.gluttonRemovedCount==1 and Glutton.satiated(u),"realmtrueoneevent satiety")
	gs=game();u=gs.player(0).units[0];play(gs,"c21702");check(gs.pending_choice.is_empty() and gs.player(1).avatarHp==28 and u.get("gluttonRemovedCount",0)==0,"norealmstillnormal2attack nophantomremoved")
	gs=game();u=gs.player(0).units[0];foe=gs.player(1)
	gs._apply_form(1,1,{"id":"fixture-form","name":"fixture","type":"form","verifiedRules":true,"value":{"attack":6,"hp":12,"setBase":true},"formRules":{}},{"attack":6,"hp":12,"setBase":true})
	play(gs,"c21704",foe.units[1].uid)
	check(foe.units[1].form.is_empty() and foe.units[1].maxHp==6 and foe.units[1].hp==2,"whale removesrealform restores6then4damage")
	check(u.gluttonRemovedCount==1 and u.attack==3,"whale actualremoved triggerssatiety")
	gs=game();u=gs.player(0).units[0];foe=gs.player(1);play(gs,"c21704",foe.units[1].uid)
	check(foe.units[1].hp==2 and u.get("gluttonRemovedCount",0)==0,"whale legalformless4damage nofakesatiety")
	gs=game();u=gs.player(0).units[0];play(gs,"c21703");check(u.attack==2 and u.maxHp==6 and not Glutton.has(u,"swift"),"gorgeexact2/6 andconditionalnotalwaysswift")
	Glutton.attach(gs,0,0);check(u.attack==4 and Glutton.has(u,"swift") and gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u)==0,"gorge realcontinuingswift")
	Glutton.remove_charm(gs,0,0,"test");check(not Glutton.has(u,"swift") and gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u)==1,"gorge losescharm losesfreeattack")
	gs=game();u=gs.player(0).units[0];give(gs,"c21705");Glutton.attach(gs,0,0);Glutton.remove_charm(gs,0,0,"testfreeze")
	check(gs.hand_card_def(0,0).gluttonEnhanced,"wine handenhancementremains aftersatietyexpires")
	check(gs.play_card(0,0),"actualenhancedwine")
	check(u.attack==4 and u.maxHp==8 and Glutton.has(u,"veil") and Glutton.has(u,"unyielding"),"wineactual4/8andkeywords not+4/+8")
	gs._damage_unit(0,0,50,1,0);check(u.hp==1 and not Glutton.has(u,"unyielding") and Glutton.has(u,"veil"),"trueunyielding savesoncekeepsveil")
	gs._damage_unit(0,0,2,1,0);check(u.hp==0 and not Glutton.has(u,"veil"),"secondhit trueKOclearsformkeywords")
	gs=game();u=gs.player(0).units[0];play(gs,"c21705");check(u.attack==4 and u.maxHp==8 and not Glutton.has(u,"unyielding") and not Glutton.has(u,"veil"),"wineunenhancednegative")
func deck_and_permanent() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
	give(gs,"c21706");check(not gs.can_play_card(0,0).ok,"baseaftertaste conditionrejecthungry")
	p.hand.clear();Glutton.attach(gs,0,0);p.avatarHp=20
	p.deck=[{"definitionId":"c21705","instanceId":"drawn-last"},{"definitionId":"c12404","instanceId":"removed-spell"},{"definitionId":"c21703","instanceId":"removed-form"},{"definitionId":"c21701","instanceId":"removed-combat"}]
	play(gs,"c21706")
	check(p.deck.is_empty() and p.hand.size()==1 and p.hand[0].instanceId=="drawn-last","threeactualtoppersremoved andthirdbranchdrawsnextcard")
	check(u.gluttonRemovedCount==3 and events(gs,"glutton-target-removed")==3,"eachactualremovedtop countednotonecardwhole")
	check(p.avatarHp==24 and gs.kw_usage(0,"encourage").attack==2 and gs.kw_usage(0,"encourage").shield==2,"formheal4 andcombatencourage2/2 distinctbranches")
	check(u.gluttonSatiation.remaining==2 and Glutton.satiated(u),"eachremovedtoprefreshesrealcharm")
	gs=game();u=gs.player(0).units[0];u.gluttonRemovedCount=14;play(gs,"c21707")
	check(u.attack==19 and u.maxHp==19 and u.formRules.gluttonKeywords.size()==14,"skyreal5/5+14 andcomplete14keywordpool")
	for key in Glutton.TRAITS:check(Glutton.has(u,key),"nativekeyword "+key)
	gs=game();u=gs.player(0).units[0];var target: Dictionary=gs.player(1).units[0]
	gs._grow_unit(target,5,6);target.temporaryAttack=7;gs._recalc(target)
	var before_attack: int=target.attack;var before_max: int=target.maxHp
	check(Glutton.permanent_stats(target).attack==0 and Glutton.permanent_stats(target).hp==0,"ordinary/temporarybonuses arenotwhitepermanentledger")
	gs._awaken(1,0,{"name":"fixture-awaken","id":"fixture-awaken"},{"attack":3,"hp":2})
	check(Glutton.permanent_stats(target).attack==3 and Glutton.permanent_stats(target).hp==2,"actualawakening whitegrowthrecorded")
	play(gs,"c21708",target.uid)
	check(target.awakened and target.attack==before_attack and target.maxHp==before_max,"absorbwhitestats preservesawakenability/body/temporaryandordinarygrowth")
	check(u.awakened and u.attack==7 and u.maxHp==9 and Glutton.permanent_stats(u).attack==4 and Glutton.permanent_stats(u).hp==3,"awakeown1/1+stolen3/2+2charm exactbody")
	check(u.gluttonRemovedCount==1 and Glutton.awakened_hp(target)==0,"oneactualpermanenttarget andnoawakenhprebuild")
	gs._knockout_unit(u,1,0);check(not Glutton.satiated(u) and Glutton.permanent_stats(u).attack==4 and Glutton.permanent_stats(u).hp==3,"whitegainpersistsKO onlycharmremoved")
func timers_and_ledgers() -> void:
	var gs:=game();var u: Dictionary=gs.player(0).units[0]
	Glutton.attach(gs,0,0)
	check(gs.VerifiedRules.has_countdown(u),"satiationisrealexternalcountdowntarget")
	gs.VerifiedRules.reduce_countdown(gs,0,0,1)
	check(u.gluttonSatiation.remaining==1,"externalreduceaffectsactualcharm")
	check(Glutton.reduce_timer(gs,0,0,-2) and u.gluttonSatiation.remaining==3,"externalincreasepreservesrealcharmtimer")
	gs.VerifiedRules.reduce_countdown(gs,0,0,3)
	check(not Glutton.satiated(u) and u.attack==1,"externaltimerzeroactuallyremovespower")
	Glutton.attach(gs,0,0);gs._begin_turn(0)
	check(u.gluttonSatiation.remaining==1,"naturalbeginonlyonetick")
	gs=game();var target: Dictionary=gs.player(1).units[1]
	target.permanentAttack=2;target.windPermanentHp=4;target.blessingPermanentAttack=5;target.blessingPermanentHp=5
	gs._grow_unit(target,5,9);gs._recalc(target)
	var stats:=Glutton.permanent_stats(target)
	check(stats.attack==7 and stats.hp==9,"knownindependentwhiteledgersexactnotdouble")
	stats=Glutton.take_permanent(gs,target)
	check(stats.attack==7 and stats.hp==9 and target.attack==target.baseAttack and target.maxHp==target.baseMaxHp,"knownledgersremovedfromactualbody")
	check(target.windPermanentHp==0 and target.blessingPermanentAttack==0 and target.blessingPermanentHp==0 and target.permanentAttack==0,"absorbedsourceledgerszeronorebuild")
	gs=game();u=gs.player(0).units[0];Glutton.attach(gs,0,0)
	gs.player(0).deck.append({"definitionId":"c21705","instanceId":"wine-drawn-while-full"});gs._draw(0,1)
	gs.VerifiedRules.Moon.full_moon(gs,u)
	check(gs.hand_card_def(0,0).gluttonEnhanced,"wineactuallydrawnwhilefull stickywithoutreadingquote")
	gs=game();u=gs.player(0).units[0];u.gluttonRemovedCount=14;play(gs,"c21707")
	gs.player(1).avatarHp=200;gs.player(1).maxAvatarHp=200;gs.player(1).units[1].front=1
	check(gs.basic_attack_targets(0,0)==["avatar-1"],"skyactualdirecttargetbypassesblockingfront")
	check(gs.basic_attack(0,0,"avatar-1"),"skyactualbasicwithalltraits")
	check(gs.player(1).units[1].hp==6 and gs.player(1).avatarHp<200,"skyrealfacehit notblockedbyunit")
	check(not Glutton.has(u,"swift") and not Glutton.has(u,"inspired") and not gs.player(0).attackUsed,"skyactualonceonlyswift/inspiredconsumption")
func ai_and_views() -> void:
	for id in ["c21701","c21702","c21703","c21704","c21705","c21706","c21707","c21708"]:
		var gs:=game();var p: Dictionary=gs.player(0)
		if id=="c21706":Glutton.attach(gs,0,0)
		if id=="c21708":gs._awaken(1,0,{"name":"fixture-awake","id":"fixture"},{"attack":1,"hp":1})
		give(gs,id);var best:=AI._best_card(gs,0)
		check(best.ok and best.hand==0,"AIlegallychooses "+id)
		if best.ok:
			check(gs.play_card(0,best.hand,best.target),"AIactualexecutes "+id)
			while not gs.pending_choice.is_empty():
				if not AI._resolve_choice(gs,0):break
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png") and Content.card_def(id).verifiedRules,"nativecardandoriginalart "+id)
	var gs:=game();Glutton.attach(gs,0,0);var snap:=JSON.stringify(gs.snapshot())
	var marks:=Glutton.unit_marks(gs,0,0);give(gs,"c21705");snap=JSON.stringify(gs.snapshot());gs.hand_card_def(0,0);Glutton.unit_marks(gs,0,0)
	check(marks.size()==2 and snap==JSON.stringify(gs.snapshot()),"descriptionandmarks readonly")
func native_ui() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["egui","fenghuanghuo","rulianshi","tianjingxia"],["fenghuanghuo","bingyong","yaodaoji","baizangzhu"],217);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=80;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.4).timeout
		var gs=b.gs;var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1)
		make_realm(gs,0,"own-ui-realm");make_realm(gs,1,"enemy-ui-realm");hand(b,["c21702"]);await settled(b)
		await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.get("type")=="glutton-realm" and choice_face(b,"enemy-ui-realm")!=null and choice_face(b,"own-ui-realm")!=null,"nativerealmbothsideschoice")
		if physical.x==1280:await capture("01-glutton-realm-choice")
		await click(choice_face(b,"enemy-ui-realm"));await settled(b)
		check(foe.realms.is_empty() and p.realms.size()==1 and p.units[0].gluttonRemovedCount==1 and foe.avatarHp==26,"nativechoseenemyrealm thenrealattack")
		hand(b,["c21704"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0,"nativewhaleactualtargetmode")
		await click(b._unit_widget(str(foe.units[1].uid)));await settled(b)
		check(foe.units[1].hp==2 and p.units[0].gluttonRemovedCount==1,"nativeformless4damage notfakesatiety")
		gs._awaken(1,0,{"name":"fixture-awake","id":"fixture"},{"attack":2,"hp":2});hand(b,["c21708"]);await settled(b)
		await click(b._hand_row.get_child(0));await settled(b)
		var fire: int=p.energy;await click(b._unit_widget(str(p.units[1].uid)));await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"nativeawake rejectnonpermanenttargetwithoutpay")
		await click(b._unit_widget(str(foe.units[0].uid)));await settled(b)
		check(p.units[0].awakened and Glutton.permanent_stats(foe.units[0]).attack==0,"nativeawake actualwhitegaintransfer")
		await click(b._unit_widget(str(p.units[0].uid)));await settled(b)
		if b._selected_attacker>=0:await click(b._unit_widget(str(p.units[0].uid)));await settled(b)
		check(texts(b).contains("饱腹") and texts(b).contains("本局移除"),"nativesatiationinspector readablecurrentrule")
		if physical.x==1600:await capture("02-glutton-satiation-inspector")
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	basics();realms_and_forms();deck_and_permanent();timers_and_ledgers();ai_and_views()
	if not rules_only:await native_ui()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("GLUTTON checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
