extends SceneTree
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const Shuten := preload("res://scripts/shuten_rules.gd")
var checks := 0
var failures := 0
var out := ""

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SHUTEN_UI_FAIL ", message)
func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	root.push_input(event, true)
func _click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	_move(at)
	# Native hover changes the hand fan geometry on the next layout frame.
	# Re-read the actual center after that movement before clicking.
	await process_frame
	await create_timer(0.12).timeout
	at = face.get_global_transform_with_canvas() * (face.size * 0.5)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
func _wait(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.2).timeout
	await process_frame
func _capture(name: String) -> void:
	if out.is_empty(): return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func _hand(battle, cards: Array) -> void:
	battle.gs.player(0).hand.clear()
	for i in cards.size(): battle.gs.player(0).hand.append({"instanceId": "shuten-ui-%d" % i, "definitionId": cards[i]})
	battle._last_view = {}
	battle._refresh()
func _labels(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children(): result += "\n" + _labels(child)
	return result

func _run() -> void:
	var stores := VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	var completed := 0
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty():
			DisplayServer.window_set_size(physical)
			DisplayServer.window_move_to_foreground()
		var battle := BattleScreen.new()
		battle.setup(["jutun-tongzi","fenghuanghuo","yingcao","basalt"],["jutun-tongzi","fenghuanghuo","yaoginshi","basalt"],10209)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 40
			p.levelUpUsed = true
			for u in p.units:
				u.level = 3
				u.passive_hooks = []
		root.add_child(battle)
		var p: Dictionary = battle.gs.player(0)
		var e: Dictionary = battle.gs.player(1)
		var source: Dictionary = p.units[0]
		_hand(battle,["c10201","c10208","c10206"])
		await create_timer(0.3).timeout
		await _click(battle._hand_row.get_child(0))
		_check(source.hp == 4 and source.attack == 3 and p.energy == 40, "native instant draws and self-damages with real rage")
		_check(battle._input_locked(), "self damage chain locks repeat input")
		await create_timer(0.7).timeout
		_capture("%d-00-live-rage" % physical.x)
		await _wait(battle)
		_check(battle._hand_row.get_child(0).data.value == 4, "fury visible card refreshes after friendly damage")
		_check("1点伤害" in battle._hand_row.get_child(1).data.text, "night parade visible X refreshes")
		_capture("%d-01-drunken-history" % physical.x)
		await _click(battle._hand_row.get_child(0))
		_check(e.avatarHp == 23 and source.attack == 3, "native fury uses 3 plus temporary 4, not permanent growth")
		await _wait(battle)
		_hand(battle,["c10204","c10203","c10205","c10206"])
		await create_timer(0.3).timeout
		await _click(battle._hand_row.get_child(0))
		_check(source.attack == 7 and source.hp == 6 and source.maxHp == 10, "ghost king native printed panel and self damage")
		await _wait(battle)
		_capture("%d-02-ghost-king" % physical.x)
		await _click(battle._hand_row.get_child(0))
		_check(source.attack == 8 and source.hp == 8 and Shuten.has_unyielding(source), "native god form replaces previous form and preserves growth")
		await _wait(battle)
		var popover := UIWidgets.make_unit_popover(source)
		_check("不屈" in _labels(popover), "inspector exposes real form survival keyword")
		popover.free()
		_move(battle._unit_widget(str(source.uid)).get_global_rect().get_center())
		await create_timer(0.25).timeout
		_check(is_instance_valid(battle._tooltip) and "本回合受到 5 伤害" in _labels(battle._tooltip), "native hover exposes correct turn history")
		if is_instance_valid(battle._tooltip):
			_check(battle._tooltip.get_global_rect().end.y <= root.size.y and battle._tooltip.get_global_rect().end.x <= root.size.x, "native detailed tooltip remains inside viewport")
		_capture("%d-02b-god-inspector" % physical.x)
		await _click(battle._hand_row.get_child(0))
		_check(source.awakened and source.attack == 9 and source.hp == 11, "native awakening permanently adds printed body")
		await _wait(battle)
		_capture("%d-03-god-awakening" % physical.x)
		battle.gs._damage_unit(0,0,10,0)
		battle._last_view = {}
		battle._refresh()
		await process_frame
		_check(source.hp == 1 and source.attack == 19, "awakened damage grows by amount")
		_check("15点伤害" in battle._hand_row.get_child(0).data.text, "parade UI includes all turn damage")
		_capture("%d-04-night-parade-preview" % physical.x)
		await _click(battle._hand_row.get_child(0))
		_check(e.units[0].hp == 0 and e.units[3].hp == 0 and p.units[3].hp == 0, "native area card damages both teams")
		_check(source.hp == 1 and e.avatarHp == 23 and p.avatarHp == 30, "native parade excludes source and avatars")
		await _wait(battle)
		_check(not battle._input_locked(), "area/death chain releases input")
		_capture("%d-05-night-parade-result" % physical.x)
		battle.queue_free()
		await process_frame

		battle = BattleScreen.new()
		battle.setup(["jutun-tongzi","fenghuanghuo","yingcao","basalt"],["jutun-tongzi","fenghuanghuo","yaoginshi","basalt"],10210)
		battle._ai_thinking = true
		for side in battle.gs.players:
			side.hand.clear(); side.energy = 30; side.levelUpUsed = true
			for u in side.units: u.level = 3; u.passive_hooks = []
		root.add_child(battle)
		p = battle.gs.player(0); e = battle.gs.player(1); source = p.units[0]
		e.units[0].hp = 2
		e.hand.append({"instanceId":"howl-native-response","definitionId":"c10207"})
		_hand(battle,["c12404","c10207","c10202"])
		await create_timer(0.3).timeout
		await _click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "real targeted enemy spell opens aim before response")
		var target := battle._unit_widget(str(e.units[0].uid))
		await _click(target)
		_check(e.units[0].hp == 1 and e.hand.is_empty() and e.energy == 29, "native target damage triggers paid howl before lethal spell")
		_check(Shuten.minimum_hp(battle.gs,e.units[0]) == 1, "native response activates whole-turn floor")
		await create_timer(0.9).timeout
		_capture("%d-05b-live-response" % physical.x)
		await _wait(battle)
		_check(not battle._input_locked(), "response chain releases input")
		_capture("%d-06-howl-response" % physical.x)
		await _click(battle._hand_row.get_child(0))
		_check(Shuten.minimum_hp(battle.gs,source) == 1, "howl may be actively played in own turn")
		await _wait(battle)
		e.units[3].front = 1; e.units[3].attack = 20
		battle._last_view = {}; battle._refresh()
		await process_frame
		await _click(battle._hand_row.get_child(0))
		_check(source.hp == 1, "native attack with howl survives lethal retaliation")
		await _wait(battle)
		_capture("%d-07-howl-combat" % physical.x)
		completed += 1
		battle.queue_free()
		await process_frame
	if is_instance_valid(Sfx._hub):
		Sfx._music_name = ""
		if is_instance_valid(Sfx._music_tween): Sfx._music_tween.kill()
		Sfx._music_tween = null
		for player in Sfx._hub.get_children():
			if player is AudioStreamPlayer: player.stop(); player.stream = null
		Sfx._streams.clear(); Sfx._voices.clear()
		Sfx._hub.queue_free(); Sfx._music = null; Sfx._hub = null
		await process_frame
		await create_timer(0.25).timeout
	VerifySupport.cleanup_stores(stores)
	_check(completed == 2, "both viewport scenarios completed")
	print("SHUTEN_UI checks=%d failures=%d" % [checks,failures])
	if failures == 0: print("SHUTEN_UI_OK")
	quit(0 if failures == 0 else 1)
