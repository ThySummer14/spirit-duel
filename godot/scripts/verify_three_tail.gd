extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Fox := preload("res://scripts/three_tail_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("THREE_TAIL_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["sanweihu","shuweng","jue","taohuayao"],["fenghuanghuo","bingyong","xuenv","baizangzhu"],272)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true;p.avatarArmor=0
		for u in p.units:u.level=3
	gs.rule_events.clear()
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"three-tail-fixture-%d"%gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actualhandplay "+id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func base_and_free() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==5 and u.passive_hooks.is_empty(),"base2/5withoutoldrandomdamage")
	for n in range(1,9):check(Content.card_def("c272%02d"%n).level==1,"alloriginalcardsonelevel")
	check(Fox.free_first(gs,0) and not p.get("threeTailFirstUsed",false),"onegamefirstcardinitiallyready")
	p.energy=0;p.avatarHp=20;var idx:=give(gs,"c27204");var card:=gs.hand_card_def(0,idx)
	check(gs.effective_card_cost(0,card)==0 and Content.card_def("c27204").cost==1,"readonlyfirstquotezero,definitioncostone")
	check(gs.play_card(0,idx) and p.energy==0 and p.avatarHp==24 and gs.player(1).avatarHp==26,"actualzerofirefirsttempt4damage4heal")
	check(not Fox.free_first(gs,0) and p.threeTailFirstUsed,"actualusepermanentlyconsumesfirst")
	idx=give(gs,"c27204");check(not gs.can_play_card(0,idx).ok and gs.effective_card_cost(0,gs.hand_card_def(0,idx))==1,"secondcardcostsone,noinventedfire")
	check(gs.end_turn(0) and gs.end_turn(1) and not Fox.free_first(gs,0),"freeallowancenotrestorednextturn")
	gs=game();p=gs.player(0);p.energy=0;p.nullifyNextCardTurn=gs.turn_counter
	play(gs,"c27204");check(gs.player(1).avatarHp==30 and p.threeTailFirstUsed and not Fox.free_first(gs,0),"counteredfirststillconsumesactualfirstuse")
	gs=game();p=gs.player(0);u=p.units[0];u.hp=0;u.knockout=2;p.energy=40
	play(gs,"c11902");u.hp=u.maxHp;u.knockout=0
	check(not Fox.free_first(gs,0),"firstcardwhilefoxKOcannotbeclaimedafterrevival")
	gs=game();p=gs.player(0);p.energy=0;idx=give(gs,"c10802")
	check(gs.play_card(0,idx,p.units[0].uid) and gs.kw_usage(0,"instant").used and p.threeTailFirstUsed,"naturalinstantfirstconsumesbothtrueallowances")
func levels_and_targets() -> void:
	for lev in [1,2,3]:
		var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var u: Dictionary=p.units[0];u.level=lev
		gs._grow_unit(foe.units[1],0,30);var hp: int=foe.units[1].hp;u.spellPower=1
		var idx:=give(gs,"c27201");var card:=gs.hand_card_def(0,idx)
		check(card.threeTailLevel==lev and card.currentCardStats.contains(str(lev*2+1)),"flamedynamicdisplaylevelandspellpower")
		check(not gs.valid_targets(0,card).has(u.uid) and not gs.can_play_card(0,idx,u.uid).ok,"flamerejectsfriendlytargetwithoutpayment")
		check(gs.play_card(0,idx,foe.units[1].uid) and foe.units[1].hp==hp-lev*2-1,"actuallevelscaledflameandspellpower")
		gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.level=lev;foe.units[1].front=1;gs._grow_unit(foe.units[1],0,30);hp=foe.units[1].hp
		play(gs,"c27202");check(foe.units[1].hp==hp-2-lev and u.shield==maxi(0,lev-int(foe.units[1].attack)),"tailactualcombatpowerarmorlevelscaled level%d hp%d expected%d shield%d"%[lev,foe.units[1].hp,hp-2-lev,u.shield])
		gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.level=lev;p.avatarHp=15;u.spellPower=1
		play(gs,"c27204");check(foe.avatarHp==30-lev-2 and p.avatarHp==15+lev+2,"temptdamagehealshareactuallevelandspellpower")
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);foe.units[1].formRules={"combatKeywords":["veil"]};var idx:=give(gs,"c27201")
	check(not gs.valid_targets(0,gs.hand_card_def(0,idx)).has(foe.units[1].uid),"flamerealveilnotselectable")
func transform_and_forms() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];var idx:=give(gs,"c27203");give(gs,"c27201")
	check(not gs.can_play_card(0,idx).ok,"transformrequiresactuallevel2handcard")
	give(gs,"c11908");var discard_iid: String=p.hand.back().instanceId
	check(gs.play_card(0,idx) and gs.pending_choice.type=="three-tail-transform" and gs.pending_choice.instanceIds==[discard_iid],"transformrealeligibleinstancechoiceonly")
	check(not gs.resolve_divination_choice(1,discard_iid) and not gs.resolve_divination_choice(0,p.hand[0].instanceId),"transformrejectswrongownerandonelevelcard")
	var previous: int=p.hand.size();check(gs.resolve_divination_choice(0,discard_iid) and p.hand.size()==previous-1+4,"transformdiscardsoneandgeneratesfouractualcards")
	check(events(gs,"three-tail-discard").any(func(i):return i.instanceId==discard_iid) and events(gs,"three-tail-generated").size()==4,"discardrealobjectandnewindependentinstances")
	for entry in p.hand:
		check(Content.card_def(entry.definitionId).level==1 and ["sanweihu","shuweng","jue","taohuayao"].has(Content.card_def(entry.definitionId).unitId),"generatedtrueonelevelownlineupcard")
	gs=game();p=gs.player(0);u=p.units[0];play(gs,"c27207")
	check(u.attack==4 and u.maxHp==5 and u.hp==5 and Fox.level(u)==4 and gs.pending_choice.is_empty(),"redreal4/5extraeffectlevelcanexceedthree,nodiscardnofakegain")
	var idx2:=give(gs,"c27201");check(gs.hand_card_def(0,idx2).currentCardStats.contains("伤害8"),"redchangesactualhanddynamicdamage")
	gs._grow_unit(gs.player(1).units[1],0,30);var hp: int=gs.player(1).units[1].hp
	check(gs.play_card(0,idx2,gs.player(1).units[1].uid) and gs.player(1).units[1].hp==hp-8,"redextraactualresolutionlevel")
	var before: int=events(gs,"three-tail-random-hit").size();play(gs,"c27205")
	check(u.form.cardId=="c27205" and u.attack==4 and u.maxHp==5 and Fox.level(u)==3,"formreplacementlosesredlevelandkeepsabsolute4/5")
	check(events(gs,"three-tail-random-hit").size()==before+3,"randomformthreeindependententryhitsafterreplacement")
	gs=game();p=gs.player(0);u=p.units[0];give(gs,"c27201");give(gs,"c27205");play(gs,"c27207")
	check(gs.pending_choice.type=="three-tail-red" and gs.pending_choice.instanceIds.size()==1,"redentryonlybattleorspelldiscardnotform")
	discard_iid=gs.pending_choice.instanceIds[0]
	check(gs.resolve_divination_choice(0,discard_iid) and events(gs,"three-tail-discard").any(func(i):return i.instanceId==discard_iid),"redactualdiscard")
	check(events(gs,"three-tail-generated").size()==1 and p.hand.size()==2 and p.hand.back().instanceId!=discard_iid,"redoneindependentgeneratedcardnotdraw")
	var generated: Dictionary=Content.card_def(p.hand.back().definitionId)
	check(generated.unitId=="sanweihu" and (generated.type=="combat" or Content.is_spell(generated)),"redrandomfromtruefoxcombatspellpool")
	give(gs,"c11908");var deck: int=p.deck.size();check(gs.end_turn(0) and gs.end_turn(1),"actualnaturalturncycleforred")
	check(gs.pending_choice.type=="three-tail-red" and p.deck.size()==deck,"rednaturalchoicebeforeordinarydraw")
	check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty() and p.deck.size()==deck-1,"AIactualdiscardresumesnormaldrawexactlyonce")
func charm_awake_and_ai() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
	play(gs,"c27206");check(gs.kw_usage(0,"encourage").attack==3 and gs.kw_usage(0,"encourage").shield==3 and gs.kw_usage(1,"encourage").attack==-3 and gs.kw_usage(1,"encourage").shield==-3,"trueencourageandopponentsuppressionledgers")
	check(gs.basic_attack(0,0) and gs.player(1).avatarHp==25 and u.shield==3 and gs.kw_usage(0,"encourage").attack==0,"actualbasicattackconsumesencouragementonce")
	gs=game();p=gs.player(0);u=p.units[0];gs.player(1).units[1].front=1;var foe: Dictionary=gs.player(1);var hp: int=foe.units[1].hp
	play(gs,"c27208");check(u.awakened and u.attack==2 and u.maxHp==5 and foe.units[1].hp==hp-4,"awakenactuallevelprojectileplusownoneleveltrigger,nostatbuff")
	var n: int=events(gs,"three-tail-projectile").size();play(gs,"c11902")
	check(events(gs,"three-tail-projectile").size()==n+1,"allyonelevelformtriggersoldversionawaken")
	n=events(gs,"three-tail-projectile").size();play(gs,"c11904")
	check(events(gs,"three-tail-projectile").size()==n,"twolevelcarddoesnottrigger")
	n=events(gs,"three-tail-projectile").size();gs._push_card_frames(0,"c11902",null,Content.card_def("c11902"),1,0,true);gs._resolve_resolution_stack()
	check(events(gs,"three-tail-projectile").size()==n+1,"PNGpre2023realautomaticonelevelalsotriggers")
	p.nullifyNextCardTurn=gs.turn_counter;n=events(gs,"three-tail-projectile").size();play(gs,"c27204")
	check(events(gs,"three-tail-projectile").size()==n+1 and events(gs,"card-nullified").size()==1,"oneleveluseabilitysurvivesoriginalcardnullification")
	check(not gs.can_play_card(0,give(gs,"c27208")).ok,"cannotmanualreawaken")
	for index in range(1,9):
		gs=game();p=gs.player(0);u=p.units[0];u.level=1;var id: String="c272%02d"%index
		if index==3:p.units[1].hp=0;p.units[1].knockout=2;give(gs,"c11908")
		give(gs,id);var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegalatonelevel "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualuse "+id)
		if not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty(),"AIactualpendingdiscard "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalPNG "+id)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["sanweihu","shuweng","jue","taohuayao"],["fenghuanghuo","bingyong","xuenv","baizangzhu"],272);b._ai_thinking=true
		for side in b.gs.players:
			side.energy=40;side.levelUpUsed=true;side.hand.clear()
			for unit in side.units:unit.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var gs=b.gs;var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1)
		hand(b,["c27203","c11908","c27201"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.get("type")=="three-tail-transform" and faces(b._choice_layer).size()==1,"nativetransformshowsoneactualeligiblecard")
		check(choice_face(b,"c27201")==null and choice_face(b,"c11908")!=null,"nativeonelevelrejectedfromdiscardchoice")
		if physical.x==1280:await capture("01-three-tail-transform-discard")
		await click(choice_face(b,"c11908"));await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.size()==5 and events(gs,"three-tail-generated").size()==4,"nativeclickrealdiscardandfourrealgeneratedcards")
		hand(b,["c27207","c27201","c27205"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.get("type")=="three-tail-red" and faces(b._choice_layer).size()==1 and choice_face(b,"c27201")!=null,"nativeredformactualspellonlychoice")
		check(p.units[0].attack==4 and p.units[0].maxHp==5 and choice_face(b,"c27201").data.currentCardStats.contains("伤害8"),"nativered4/5andactualchoicelevel4damage")
		if physical.x==1600:await capture("02-three-tail-red-form-level-four")
		await click(choice_face(b,"c27201"));await settled(b);check(gs.pending_choice.is_empty(),"nativeredchoicefinishes")
		hand(b,["c27201"]);gs._grow_unit(foe.units[1],0,30);var hp: int=foe.units[1].hp;var fire: int=p.energy;await settled(b)
		await click(b._hand_row.get_child(0));await settled(b);await click(b._unit_widget(str(p.units[0].uid)));await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"nativeflamerejectsfriendwithoutpayment")
		await click(b._unit_widget(str(foe.units[1].uid)));await settled(b);check(foe.units[1].hp==hp-8 and p.hand.is_empty(),"nativeenemyflameactuallevel4damage8")
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	base_and_free();levels_and_targets();transform_and_forms();charm_awake_and_ai()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("THREE_TAIL checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
