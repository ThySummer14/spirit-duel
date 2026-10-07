extends SceneTree
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
var checks := 0
var failures := 0
var out := ""

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FIREFLY_UI_FAIL ",message)

func move(at: Vector2) -> void:
	var input := InputEventMouseMotion.new()
	input.position = at
	root.push_input(input,true)

func click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	move(at)
	for down in [true,false]:
		var input := InputEventMouseButton.new()
		input.position = at
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		root.push_input(input,true)

func settled(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.08).timeout
	await process_frame

func capture(name: String) -> void:
	if out.is_empty(): return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name+".png"))

func hand(battle, ids: Array, count: int = 0) -> void:
	battle.gs.player(0).hand.clear()
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId":"firefly-ui-%d" % i,"definitionId":ids[i],"enhanceCount":count})
	battle._last_view = {}
	battle._refresh()

func _run() -> void:
	var stores := VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty():
			DisplayServer.window_set_size(physical)
			DisplayServer.window_move_to_foreground()
		var battle := BattleScreen.new()
		battle.setup(["yingcao","yimulian","basalt","yaodaoji"],["yingcao","yimulian","basalt","yaodaoji"],10709)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for unit in p.units:
				unit.level = 3
				unit.passive_hooks = []
		root.add_child(battle)
		var p := battle.gs.player(0)
		var foe := battle.gs.player(1)
		var source: Dictionary = p.units[0]
		hand(battle,["c10708"],3)
		await create_timer(0.3).timeout
		check("已增强3次" in battle._hand_row.get_child(0).data.text, "hand face shows per-instance enhancement")
		click(battle._hand_row.get_child(0))
		check(battle._pending_target_card == 0,"point enters target selection")
		var ally := battle._unit_widget(str(p.units[2].uid))
		move(ally.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		check(battle._aim.valid,"point aim accepts ally")
		capture("%d-01-ally-point" % physical.x)
		var maximum: int = p.units[2].maxHp
		click(ally)
		check(p.units[2].maxHp == maximum+4,"ally click grants exact maximum HP")
		check(Cues.played_card(battle.gs.command_log.back().a).value == 4,"played-card presentation preserves enhanced amount")
		check(battle._input_locked(),"target play locks duplicate input")
		await settled(battle)
		check(not battle._input_locked(),"point presentation releases input")
		hand(battle,["c10708"],3)
		await create_timer(0.25).timeout
		click(battle._hand_row.get_child(0))
		var enemy := battle._unit_widget(str(foe.units[2].uid))
		move(enemy.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		check(battle._aim.valid,"point aim accepts enemy")
		capture("%d-02-enemy-point" % physical.x)
		var hp: int = foe.units[2].hp
		click(enemy)
		check(foe.units[2].hp == hp-4,"enemy click deals enhanced damage")
		check("已增强3次" in Cues.played_card(battle.gs.command_log.back().a).text,"played-card presentation preserves enhancement history")
		await settled(battle)
		hand(battle,["c10706"])
		await create_timer(0.25).timeout
		var deck: int = p.deck.size()
		click(battle._hand_row.get_child(0))
		check(p.hand.map(func(c):return c.definitionId) == ["c10702","c10703","c10705"],"rainbow click generates all actual forms")
		await settled(battle)
		check(p.deck.size() == deck,"rainbow does not draw forms from deck")
		check(battle._hand_row.get_child_count() == 3,"all generated forms displayed")
		check("鼓舞" in battle._hand_row.get_child(1).data.text and "鬼火" in battle._hand_row.get_child(2).data.text,"generated forms retain distinct effect text")
		capture("%d-03-rainbow-forms" % physical.x)
		click(battle._hand_row.get_child(1))
		check(source.attack == 3 and source.maxHp == 5,"form click installs printed stats")
		check(int(battle.gs.kw_usage(0,"encourage").get("attack",0)) == 2,"courage click stores team encouragement")
		await settled(battle)
		check(p.deck.size() == deck-1,"generated form triggers exactly one aura draw")
		hand(battle,["c10707","c11801"])
		await create_timer(0.25).timeout
		click(battle._hand_row.get_child(0))
		await settled(battle)
		check(source.awakened and source.attack == 5 and source.maxHp == 7,"awakening keeps form and applies real increment")
		check(battle.gs._kw(battle._hand_row.get_child(0).data,"instant"),"teammate face gains instant after awakening")
		deck = p.deck.size()
		click(battle._hand_row.get_child(0))
		await settled(battle)
		check(p.deck.size() == deck-1,"ally form click uses awakened aura")
		capture("%d-04-awakened-aura" % physical.x)
		hand(battle,["c10704"])
		p.units[2].front = 1
		battle.gs.current_player = 1
		foe.energy = 20
		foe.attackUsed = false
		battle._last_view = battle.gs.snapshot().duplicate(true)
		var before: Dictionary = battle._last_view.duplicate(true)
		var start: int = battle.gs.command_log.size()
		hp = int(p.units[2].hp)
		check(battle.gs.basic_attack(1,2),"opponent enters battle with real command")
		check(p.units[2].hp == hp and foe.units[2].attack == 0,"flash responds before original combat damage")
		var timeline: Array = Cues.timeline(before,battle.gs.snapshot().duplicate(true),battle.gs.command_log.slice(start))
		check(not timeline.is_empty() and timeline[0].c == "response_card","response presentation precedes incoming attack")
		battle._refresh()
		await process_frame
		check(battle._input_locked(),"response sequence locks input")
		await create_timer(0.45).timeout
		capture("%d-05-flash-response" % physical.x)
		await settled(battle)
		check(not battle._input_locked(),"response sequence completes")
		check(battle.gs.end_turn(1),"opponent turn may finish after response")
		check(foe.units[2].attack == 1,"flash effect expires at actual turn end")
		battle._refresh()
		await settled(battle)
		battle.queue_free()
		await process_frame
	VerifySupport.cleanup_stores(stores)
	print("FIREFLY_UI checks=%d failures=%d" % [checks,failures])
	if failures == 0: print("FIREFLY_UI_OK")
	quit(0 if failures == 0 else 1)
