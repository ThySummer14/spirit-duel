extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Ark := preload("res://scripts/arakawa_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("ARAKAWA_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["huangchuanzhizhu","wannianzhu","taohuayao","shuzhu"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],271)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	return gs
func give(gs, id: String) -> int:
	gs.player(0).hand.append({"instanceId":"ark-test-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1
	return gs.player(0).hand.size()-1
func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actual use "+id)
func drain(gs) -> void:
	var guard := 0
	while not gs.pending_choice.is_empty() and guard<30:
		guard+=1;check(AI._resolve_choice(gs,gs.action_player()),"AI resolves actual divination")
func rules() -> void:
	for n in range(1,9):
		var tile := preload("res://scripts/ui/card_face.gd").new();var id := "c271%02d"%n
		tile.data=Content.card_def(id);tile.refresh_art()
		check(tile._original_card!=null and tile._original_card.resource_path=="res://assets/official/cards/%s.png"%id,"actual original card texture "+id);tile.free()
	var gs:=game();var u:Dictionary=gs.player(0).units[0];var e:Dictionary=gs.player(1)
	check(u.attack==2 and u.maxHp==5,"printed2/5")
	play(gs,"c27101");check(gs.player(0).energy==40 and u.lanternStored.card.id=="c27101","gain fire and store actual copy")
	e.units[0].attack=20
	var before:int=e.units[0].hp
	play(gs,"c27101");check(e.units[0].hp==before-1,"second card hits highest enemy attack")
	check(Ark.count(gs,0)==2 and gs.rule_events.filter(func(ev):return ev.kind=="charged-stored").size()==1,"exactly one charge and exact use count")
	play(gs,"c27101");check(e.units[0].hp==before-1,"third card does not repeat base trigger")
	gs.player(0).hand.clear();check(gs.end_turn(0) and gs.end_turn(1),"real turn cycle")
	check(Ark.count(gs,0)==1 and not u.has("lanternStored"),"automatic release counts once and cannot self-recharge")
	gs=game();u=gs.player(0).units[0];e=gs.player(1)
	play(gs,"c27103");check(gs.front_index(0)<0,"install form is first card, no fish yet")
	play(gs,"c27101");var fish:Dictionary=gs.player(0).units[gs.front_index(0)]
	check(fish.get("arkFish",false) and fish.attack==2 and fish.hp==2,"second card creates actual2/2 fish")
	check(gs.basic_attack(0,0),"real attacker replaces fish")
	check(fish.get("removed",false) and int(fish.knockout)==0,"fish leaves by removal without death countdown")
	gs=game();u=gs.player(0).units[0]
	play(gs,"c27101");play(gs,"c27103");check(gs.front_index(0)<0,"second-card installed form cannot retroactively summon")
	gs=game();u=gs.player(0).units[0];e=gs.player(1)
	var h:=give(gs,"c27104");check(gs.hand_card_def(0,h).value==4,"torrent before two cards stays4")
	check(not gs.valid_targets(0,gs.hand_card_def(0,h)).has("avatar-1"),"torrent excludes avatar")
	play(gs,"c27101");check(gs.hand_card_def(0,h).value==4,"one other card no enhance")
	play(gs,"c27101");check(gs.hand_card_def(0,h).value==6,"two other cards fixed+2")
	e.units[1].hp=20;e.units[1].maxHp=20
	check(gs.play_card(0,h,e.units[1].uid) and e.units[1].hp==14,"actual enhanced selected damage6")
	gs=game();e=gs.player(1);u=gs.player(0).units[0]
	e.units[0].attack=20
	play(gs,"c27105");play(gs,"c27101")
	check(e.avatarHp==29 and e.units[0].hp==int(e.units[0].maxHp)-2 and e.units[1].hp==int(e.units[1].maxHp)-1,"home second card hits every enemy character then base highest")
	var deck_before:int=gs.player(0).deck.size();play(gs,"c27101")
	check(gs.pending_choice.get("type")=="native-divination" and gs.pending_choice.count==2,"home third card actual divination2")
	check(gs.player(0).deck.size()==deck_before,"divination does not invent draw")
	drain(gs);gs.player(0).avatarHp=20;u.hp=2;play(gs,"c27101")
	check(gs.player(0).avatarHp==23 and u.hp==5,"home fourth card recovers units and avatar3")
	gs=game();u=gs.player(0).units[0]
	var n:int=gs.player(0).hand.size();var deck:int=gs.player(0).deck.size()
	play(gs,"c27106");check(gs.pending_choice.get("type")=="native-divination" and not u.has("lanternStored"),"divination pauses before draw and recharge")
	drain(gs);check(gs.player(0).hand.size()==n+1 and gs.player(0).deck.size()==deck-1 and u.lanternStored.card.id=="c27106","resume draws real card then recharges")
	gs=game();u=gs.player(0).units[0];e=gs.player(1);var target:Dictionary=e.units[1]
	play(gs,"c27107",target.uid)
	check(u.lanternStored.card.id=="arakawa-annihilate" and target.has("movementHolders") and target.frozen>0,"devour stores real annihilate and lasting stun")
	play(gs,"c27101");check(target.has("movementHolders") and u.has("lanternStored"),"other hand card cannot release devour stun while charging")
	check(not gs.can_play_card(0,give(gs,"c27107"),e.units[0].uid).ok,"cannot overwrite existing charge")
	gs.player(0).hand.clear();check(gs.end_turn(0),"target enemy turn")
	check(target.frozen>0 and gs.end_turn(1),"held through actual stunned target turn")
	check(target.hp==0 and not u.has("lanternStored") and not u.has("arkHeldTarget"),"actual next-turn annihilation destroys original target and clears hold")
	gs=game();u=gs.player(0).units[0];target=gs.player(1).units[1]
	play(gs,"c27107",target.uid);gs._knockout_unit(u,1,0);gs._resolve_resolution_stack()
	check(not target.has("movementHolders") and target.frozen==0,"source death releases only sustained stun")
	gs=game();u=gs.player(0).units[0];e=gs.player(1)
	play(gs,"c27108");play(gs,"c27101")
	check(e.avatarHp==28 and e.avatarFrozen>0 and u.attack==3 and u.maxHp==6,"awakening exact+1/+1 and second card avatar2/stun")
	check(not gs.can_basic_attack(1,0).ok,"avatar stun blocks actual basic attacks")
	for ncard in range(1,9):
		gs=game();var id:="c271%02d"%ncard
		give(gs,id);var best:Dictionary=AI._best_card(gs,0)
		check(best.ok and best.card_id==id,"AI selects "+id)
		if best.ok:check(gs.play_card(0,best.hand,best.target),"AI legal actual use "+id);drain(gs)
func ui_checks() -> void:
	root.theme=ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical;DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["huangchuanzhizhu","wannianzhu","taohuayao","shuzhu"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],271)
		b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.5).timeout
		hand(b,["c27107"]);await settled(b)
		await click(b._hand_row.get_child(0));check(b._pending_target_card==0,"real mouse enters devour target")
		await capture("%d-devour-target"%physical.x)
		var enemy:Dictionary=b.gs.player(1).units[1]
		await click(b._unit_widget(str(enemy.uid)));await settled(b)
		check(enemy.frozen>0 and b.gs.player(0).units[0].has("lanternStored"),"mouse devour stores selected target")
		await capture("%d-devour-stored"%physical.x)
		b.gs._knockout_unit(b.gs.player(0).units[0],1,0);b.gs._resolve_resolution_stack();b.gs.player(0).units[0].hp=5;b.gs.player(0).units[0].knockout=0
		hand(b,["c27106"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b.gs.pending_choice.get("type")=="native-divination","mouse opens printed divination1")
		await capture("%d-divination"%physical.x)
		await click(choice_face(b));await settled(b);await click(choice_face(b,"divination-place-top"));await settled(b)
		check(b.gs.pending_choice.is_empty() and b.gs.player(0).units[0].has("lanternStored"),"actual choice resumes draw/recharge")
		b.queue_free();await process_frame
func fish_ui_checks() -> void:
	root.theme=ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical;DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["huangchuanzhizhu","wannianzhu","taohuayao","shuzhu"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],271)
		b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.5).timeout
		hand(b,["c27103"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		hand(b,["c27101"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		var fish_idx: int=b.gs.front_index(0)
		check(fish_idx>=4,"real second-card click creates fifth unit")
		var fish: Dictionary=b.gs.player(0).units[fish_idx]
		check(b._unit_widget(str(fish.uid))!=null,"summoned fish has actual clickable unit widget")
		await capture("%d-fish"%physical.x)
		await click(b._unit_widget(str(b.gs.player(0).units[0].uid)));await click(b._enemy_target_btn);await settled(b)
		check(fish.get("removed",false) and b.gs.front_index(0)==0,"real mouse attack replaces fish and removes entity")
		b.queue_free();await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();rules()
	if not OS.get_cmdline_user_args().is_empty():
		out=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(out)
		if OS.get_cmdline_user_args().has("--fish-ui"):await fish_ui_checks()
		else:await ui_checks()
	Support.cleanup_audio();await process_frame;Support.cleanup_stores(stores)
	print("ARAKAWA_VERIFY ",JSON.stringify({"checks":checks,"failures":failures,"ui":not out.is_empty()}));quit(1 if failures else 0)
