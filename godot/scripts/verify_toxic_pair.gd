extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Toxic:=preload("res://scripts/toxic_rules.gd")
func check(ok: bool,detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("TOXIC_PAIR_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["chongshi","xieenv","liyujing","shuweng"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],283284)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"toxic-test-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null) -> void:
	var idx:=give(gs,id);var why:Dictionary=gs.can_play_card(0,idx,target);check(gs.play_card(0,idx,target),"actualplay "+id+" "+str(why))
func finish(gs) -> void:
	var guard:=0
	while not gs.pending_choice.is_empty() and guard<30:
		check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"AIactualchoice");guard+=1
	check(guard<30,"finitechoicecontinuation")
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func poisoned(gs,owner: int=1,idx: int=0) -> void:Toxic.apply(gs,1-owner,0,owner,idx)
func mechanics() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var target:Dictionary=foe.units[0];gs._grow_unit(target,0,10);var hp:int=target.hp;var attack:int=target.attack
	check(p.units[0].passive_hooks.is_empty() and p.units[1].passive_hooks.is_empty(),"bothlegacyarmorbreakpassivesremoved")
	play(gs,"c28303",target.uid);check(target.hp==hp-3 and target.toxicPoisoned and target.attack==attack-1,"real3toxicandcontinuousbugaura")
	hp=target.hp;gs._heal_unit(target,50);check(target.hp==hp,"originalpoisonblocksactualhealing");gs._grow_unit(target,0,3);check(target.hp==hp,"originalpoisonblocksmaxHPgrowthhealing")
	var shape:Dictionary=Content.card_def("c28203");gs._install_form(1,0,shape,shape.value);gs.resolution_stack.clear();check(target.hp==hp and target.toxicPoisoned,"originalpoisonblocksformentryreset")
	gs.VerifiedRules.Forms.remove(gs,1,0,"专项移除");check(target.hp==hp and target.toxicPoisoned,"originalpoisonblocksformleavereset")
	target.unyielding=true;target.hp=10;var saved_fire:int=p.energy;play(gs,"c28303",target.uid)
	check(target.hp==0 and target.knockout==2 and not target.has("toxicPoisoned") and events(gs,"toxic-execution").size()==1,"secondtoxicactualdirectKObypassesunyieldingandclearsonKO")
	check(p.energy==saved_fire-1 and not p.units[0].awakened,"directKOnofakefireorawakening")
	gs=game();foe=gs.player(1);target=foe.units[0];target.barrier=true;play(gs,"c28303",target.uid)
	check(target.hp==target.maxHp and not target.has("toxicPoisoned") and not target.barrier,"barrierpreventsdamageandpoison")
	gs=game();target=gs.player(1).units[0];target.shield=20;play(gs,"c28303",target.uid);check(not target.has("toxicPoisoned") and target.hp==target.maxHp,"fullarmorpreventsfirstpoison")
	poisoned(gs);target.shield=20;play(gs,"c28303",target.uid);check(target.hp>0 and target.toxicPoisoned,"fullarmorpreventsalreadytoxicexecution")
	gs=game();target=gs.player(1).units[0];poisoned(gs);target.barrier=true;play(gs,"c28303",target.uid);check(target.hp>0 and target.toxicPoisoned,"barrierpreventsalreadytoxicexecution")
	gs=game();var koi:Dictionary=gs.player(0).units[2];var koi_shape:Dictionary=Content.card_def("c28208");gs._install_form(0,2,koi_shape,koi_shape.value);gs.resolution_stack.clear();koi.hp=6;Toxic.apply(gs,1,0,0,2)
	koi_shape=Content.card_def("c28203");gs._install_form(0,2,koi_shape,koi_shape.value);gs.resolution_stack.clear();check(koi.hp==6 and koi.maxHp==5,"poisonformentrypreservescurrentHPwhennewformmaxislower")
	gs.VerifiedRules.Forms.remove(gs,0,2,"专项移除");check(koi.hp==6,"poisonformleavepreservesHPacrossbasebodyandaurarefresh")
	gs=game();target=gs.player(1).units[0];target.hp=2;play(gs,"c28303",target.uid);check(target.hp==0 and not target.has("toxicPoisoned"),"firstlethaltoxicdoesnotinventlivingpoisonstatus")
	gs=game();target=gs.player(1).units[0];gs._grow_unit(target,0,10);poisoned(gs);hp=target.hp;gs._damage_unit(1,0,1,0,3);check(target.hp==hp-1 and target.toxicPoisoned,"ordinarydamagecannotexecuteorremoveactualpoison")
	gs._knockout_unit(gs.player(0).units[0],1,0);check(target.attack==attack,"poisonedtargetpowerrestoredwhenbugauraKO")
func bug_cards() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);play(gs,"c28301");check(p.units[0].attack==4 and p.units[0].maxHp==5,"printed4/5butterflyform")
	var count:int=p.hand.size();poisoned(gs);gs._knockout_unit(foe.units[0],0,1);gs._resolve_resolution_stack();check(p.hand.size()==count+1,"poisonedKOfirstdraw")
	poisoned(gs,1,1);gs._knockout_unit(foe.units[1],0,1);gs._resolve_resolution_stack();check(p.hand.size()==count+1,"poisonedKOdrawonceactualturn")
	gs.turn_counter+=1;poisoned(gs,1,2);gs._knockout_unit(foe.units[2],0,1);gs._resolve_resolution_stack();check(p.hand.size()==count+2,"poisonedKOdrawresetnextactualturn")
	gs=game();p=gs.player(0);play(gs,"c28302");var swarm:Dictionary=p.units.back();check(p.units.size()==5 and swarm.name=="展翅虫群" and swarm.attack==1 and swarm.hp==3 and swarm.swift and swarm.front==1,"actual1/3swifttoxicfrontsummon")
	var fire:int=p.energy;foe=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,10);check(gs.basic_attack(0,4),"actualsummonlegalattack")
	check(p.energy==fire and foe.units[0].toxicPoisoned and not swarm.swift,"summonrealtoxicandfreefirstswiftattack")
	gs.VerifiedRules.Weaver.leave_front(gs,0);check(swarm.removed and swarm.hp==0 and swarm.knockout==0,"summonreallyremovedwhenleavingfront")
	gs=game();p=gs.player(0);p.avatarHp=10;play(gs,"c28304");check(p.units[0].attack==2 and p.units[0].maxHp==5,"basePNG2/5withoutlaterentryward")
	foe=gs.player(1);gs._grow_unit(foe.units[0],0,10);foe.units[0].hp=7;poisoned(gs);play(gs,"c28303",foe.units[0].uid)
	check(p.avatarHp==17 and events(gs,"toxic-execution").size()==1,"poisonexecutionpreservescurrent7HPsnapshotforprintedheal")
	gs=game();p=gs.player(0);p.deck.clear()
	for id in ["c28303","c28306","c28201"]:p.deck.append({"instanceId":"deck-"+id,"definitionId":id})
	play(gs,"c28305");check(p.hand.size()==2 and p.deck.size()==1 and p.deck[0].definitionId=="c28201" and gs.phase=="choice","searchactualtwotoxicinstancesnotdrawtoptwoandwardafter")
	finish(gs);check(p.hand.filter(func(i):return i.get("handCharm",{}).get("kind")=="ward").size()==1,"searchwardattachesrealretrievedcard")
	gs=game();p=gs.player(0);gs._knockout_unit(p.units[1],1,0);foe=gs.player(1);for u in foe.units:gs._grow_unit(u,0,10)
	play(gs,"c28306",p.units[1].uid);check(p.units[1].hp==p.units[1].maxHp and foe.units.filter(func(u):return u.get("toxicPoisoned",false)).size()==1,"selectedrealrevivethenrandom2toxic")
	check(Toxic.searchable(Content.card_def("c28601")) and Toxic.searchable(Content.card_def("c28501")) and not Toxic.searchable(Content.card_def("c28606")),"searchusesactualoriginaltoxickeywordoutsidebatchwithoutshrinkingpool")
	var bad:=give(gs,"c28306");check(not gs.can_play_card(0,bad,p.units[1].uid).ok,"revivecannotselectlivingunit")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(foe.units[0],0,20);foe.units[0].front=1;play(gs,"c28307",foe.units[0].uid)
	check(p.realms.size()==1 and p.realms[0].hp==8 and foe.units[0].toxicPoisoned,"real8durrealmthenactualselected2toxic")
	gs.basic_attack(0,3);check(foe.units[0].hp==0,"ownturndreammakesordinarycombattoxic")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,20);play(gs,"c28307",foe.units[1].uid)
	gs.basic_attack(0,1);check(foe.units[0].hp==0 and not foe.units[0].has("toxicPoisoned"),"alreadytoxiccombatupgradedtoactuallethalonfreshenemy")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(foe.units[0],0,10);var atk:int=foe.units[0].attack;play(gs,"c28308",foe.units[0].uid)
	check(p.units[0].awakened and p.units[0].attack==4 and p.units[0].maxHp==7 and foe.units[0].hp==foe.units[0].maxHp-4 and foe.units[0].attack==atk-2,"printed4toxicthenpermanent2/2awakeaura2")
	var before:int=p.energy;gs._knockout_unit(foe.units[0],0,1);gs._resolve_resolution_stack();check(p.energy==before+1,"awakepoisonKOactualfire")
	poisoned(gs,1,1);before=p.energy;gs._knockout_unit(foe.units[1],0,1);gs._resolve_resolution_stack();check(p.energy==before,"awakefireonceperactualturn")
	var power:int=p.units[0].attack;var max_hp:int=p.units[0].maxHp;gs._grow_unit(foe.units[2],0,10);poisoned(gs,1,2);before=p.energy
	play(gs,"c28308",foe.units[2].uid);check(p.units[0].attack==power+2 and p.units[0].maxHp==max_hp+2,"reuseddamageawakeningretainsprintedpermanent2/2")
	check(p.energy==before-1,"reawakeningdamageoccursbeforeitsnewonceperturnability")
	poisoned(gs,1,3);before=p.energy;gs._knockout_unit(foe.units[3],0,1);gs._resolve_resolution_stack();check(p.energy==before+1,"reusedawakeningresetsnewabilityonceallowance")

func scorpion_cards() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,20)
	gs.basic_attack(0,1);check(foe.units[0].toxicPoisoned,"baseattackactuallytoxic");check(foe.units[0].armorBreak==0,"basecannotalsoapplyoldfakearmorbreak");gs._knockout_unit(p.units[1],1,0);give(gs,"c28403");play(gs,"c28401")
	check(p.units[1].hp==6 and gs.phase=="choice" and p.units[1].shield==0,"actualKOrevivebeforewardwithoutfakearmor");finish(gs)
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,20);give(gs,"c28403");var hp:int=foe.units[0].hp
	play(gs,"c28402");check(gs.phase=="choice" and foe.units[0].hp==hp,"combatclawwaitswardbeforeattack");finish(gs)
	check(foe.units[0].toxicPoisoned and p.units[1].shield==0,"clawactualcombatandzeroarmorprinted")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28403");gs._grow_unit(foe.units[0],0,10);gs._damage_unit(0,1,99,1,0);gs._resolve_resolution_stack()
	check(foe.units[0].toxicPoisoned and foe.units[0].hp==foe.units[0].maxHp-2,"hiddenstingactualkillerretaliation2toxic")
	gs=game();p=gs.player(0);play(gs,"c28403");var hp0:int=p.units[0].hp;gs._damage_unit(0,1,99,0,0);gs._resolve_resolution_stack();check(p.units[0].hp==hp0 and not p.units[0].has("toxicPoisoned"),"friendlykillcannottriggerenemyretaliation")
	gs=game();p=gs.player(0);give(gs,"c28403");play(gs,"c28404");check(not p.units[1].awakened and gs.phase=="choice","wardbeforeawakening");finish(gs)
	check(p.units[1].awakened and p.units[1].maxHp==7 and not gs.can_play_card(0,give(gs,"c28404")).ok,"printedawake1/1andrepeatillegal")
	foe=gs.player(1);hp=foe.units[0].hp;gs._damage_unit(1,0,1,0,1);check(foe.units[0].get("toxicPoisoned",false) and foe.units[0].hp==hp-1,"awakeallactualsourceharmtoxicincludingnoncombat")
	gs=game();p=gs.player(0);play(gs,"c28405");check(p.units[1].front==1 and p.units[1].attack==4 and p.units[1].hp==6,"4/6entryactualmovement")
	poisoned(gs);check(p.units[1].shield==2,"eachnewenemyunitpoisonactual2armor");poisoned(gs);check(p.units[1].shield==2,"duplicatepoisonnotnewapplication")
	var i:=give(gs,"c28406");var c:Dictionary=gs.hand_card_def(0,i);check(c.value==2 and c.combatOption.shield==2 and c.enhanced,"realturnonepoisonbuffsclaw1/1to2/2")
	var stamp:=JSON.stringify(gs.snapshot());gs.hand_card_def(0,i);gs.can_play_card(0,i);check(JSON.stringify(gs.snapshot())==stamp,"dynamicclawquerypure")
	gs.turn_counter+=1;c=gs.hand_card_def(0,i);check(c.value==1 and c.combatOption.shield==1 and not c.enhanced,"enhancementexpiresactualturn")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(foe.units[0],0,20);play(gs,"c28407",foe.units[0].uid)
	check(p.realms.size()==1 and p.realms[0].hp==6 and foe.units[0].toxicPoisoned,"6durdenactualentryselectedtoxic")
	gs._damage_avatar(0,1,1,0);gs._resolve_resolution_stack();check(foe.units[0].hp==0,"denactualpoisoncounteronunitavatardamage")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28408");check(p.units[1].attack==3 and p.units[1].hp==9 and p.units[1].unyielding,"SSRfullPNG3/9andactualunyielding")
	gs.basic_attack(0,1);check(foe.get("avatarToxicPoisoned",false),"SSRactuallypoisonsenemyavatar")
	var face:int=foe.avatarHp;gs._heal_avatar(1,5);check(foe.avatarHp==face,"originalavatarpoisonblocksheal")
	p.units[1].inspired=true;check(gs.basic_attack(0,1) and gs.winner==0 and foe.avatarHp==0,"secondactualtoxicavatarhitreallywinsnotfakeadditionaldamage")
func negative_and_ai() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.units[1].front=1;gs.current_player=1;gs._grow_unit(foe.units[0],0,15)
	gs.basic_attack(1,0);check(not foe.units[0].get("toxicPoisoned",false),"unawakeneddefendercounterdoesnotinheritattackonlytoxic")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28307",foe.units[1].uid);foe.units[0].front=1;p.units[3].front=1;gs.current_player=1;gs._grow_unit(foe.units[0],0,10);gs.basic_attack(1,0)
	check(not foe.units[0].get("toxicPoisoned",false),"dreamdoesnotgranttoxicduringenemyturn")
	gs=game();foe=gs.player(1);foe.units[0].foxVeil=true;var i:=give(gs,"c28303");var ts:Array=gs.valid_targets(0,gs.hand_card_def(0,i));check(foe.units[0].uid not in ts and "avatar-1" not in ts and not gs.play_card(0,i,foe.units[0].uid),"toxicmanualspellrejectsveilavatarandnopayment")
	gs=game();p=gs.player(0);p.nullifyNextCardTurn=gs.turn_counter;play(gs,"c28302");check(p.units.size()==4,"counteredwormspellcannotspawnfakeunit")
	for prefix in ["c283","c284"]:
		for n in range(1,9):
			gs=game();var id:String=prefix+"%02d"%n
			if id=="c28306":gs._knockout_unit(gs.player(0).units[3],1,0)
			if id=="c28401":gs._knockout_unit(gs.player(0).units[1],1,0)
			give(gs,id);var best:=AI._best_card(gs,0)
			check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegal "+id)
			check(best.ok and gs.play_card(0,best.hand,best.target),"AIactual "+id);finish(gs)
			check(Content.card_def(id).cost==1 and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalcostandfullPNG "+id)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["chongshi","xieenv","liyujing","shuweng"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],283284);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var foe:Dictionary=b.gs.player(1);b.gs._grow_unit(foe.units[0],0,10);hand(b,["c28303"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(foe.units[0].uid).selected,"nativetoxicmanualtargethighlight")
		await click(b._unit_widget(foe.units[0].uid));await settled(b);check(foe.units[0].get("toxicPoisoned",false),"nativeactualselectedpoison")
		var status:Dictionary=gs_status(b.gs,1,0);check(str(status).contains("中毒"),"nativepoisonstatusdetail");await capture("%d-01-actual-poison"%physical.x)
		hand(b,["c28302"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);var swarm:Dictionary=b.gs.player(0).units.back()
		check(swarm.get("toxicSwarm",false) and swarm.hp==3 and b._unit_widget(swarm.uid)!=null,"nativereal1/3swarmwidget");await capture("%d-02-winged-swarm"%physical.x)
		b.gs._knockout_unit(b.gs.player(0).units[2],1,0);hand(b,["c28306"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(b.gs.player(0).units[2].uid).selected and not b._unit_widget(b.gs.player(0).units[1].uid).selected,"nativeKOonlyrevivetarget")
		await click(b._unit_widget(b.gs.player(0).units[2].uid));await settled(b);check(b.gs.player(0).units[2].hp>0,"nativeactualselectedrevivethenrandomtoxic")
		hand(b,["c28402","c28403"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);check(b.gs.pending_choice.get("which")=="ward","nativeclawopensactualwardbeforecombat")
		await click(choice_face(b));await settled(b);check(b.gs.pending_choice.is_empty() and b.gs.player(0).units[1].front==1,"nativeclawresumescombatafterselection")
		for u in foe.units:u.front=0
		hand(b,["c28408"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);check(b.gs.player(0).units[1].form.cardId=="c28408" and b.gs.player(0).units[1].maxHp==9,"nativeprintedSSR3/9")
		b.gs.player(0).units[1].inspired=true;b.gs.basic_attack(0,1);b._last_view={};b._refresh();await settled(b)
		check(foe.get("avatarToxicPoisoned",false) and b._enemy_poison.visible and b._enemy_poison.text.contains("中毒"),"nativeavatarpoisonvisiblewarning");await capture("%d-03-avatar-poison"%physical.x)

		var detached:Array=[]
		for cache in [b._unit_widgets,b._hand_widgets]:
			for widget in cache.values():
				if is_instance_valid(widget) and widget.get_parent()==null:detached.append(weakref(widget))

		b.queue_free();await process_frame;await process_frame
		check(detached.all(func(w):return w.get_ref()==null),"closingbattlereleasesdetachedcachedfaces")
func gs_status(gs,owner: int,idx: int) -> Dictionary:
	return preload("res://scripts/ui/battle_status.gd").unit_view(gs,owner,idx,0)
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme();mechanics();bug_cards();scorpion_cards();negative_and_ai()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("TOXIC_PAIR_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]);quit(0 if failures==0 else 1)
