extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("POISON_PAIR_UI_FAIL ", text)
func click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	await process_frame
	await create_timer(0.14).timeout
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e, true)
func escape() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	root.push_input(e, true)
func texts(n: Node) -> String:
	var value := str(n.text) + "\n" if n is Label or n is RichTextLabel else ""
	for child in n.get_children(): value += texts(child)
	return value
func faces(n: Node) -> Array:
	var result: Array = []
	if n is Control and n.get("data") is Dictionary and n.get("data").has("unitId"): result.append(n)
	for child in n.get_children(): result.append_array(faces(child))
	return result
func hand(b, ids: Array) -> void:
	b.gs.player(0).hand.clear()
	for i in ids.size(): b.gs.player(0).hand.append({"instanceId": "poison-ui-%d" % i, "definitionId": ids[i]})
	b._last_view = {}
	b._refresh()
func settled(b) -> void:
	for i in 3: await process_frame
	await create_timer(b._presentation_remaining() + 0.18).timeout
	await process_frame
func capture(name: String) -> void:
	if out.is_empty(): return
	await create_timer(0.15).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(["tiaotiaodidi","qingshe","qingfangzhu","zuofutongzi"],["tiaotiaodidi","qingshe","qingfangzhu","zuofutongzi"],20261013)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			p.avatarArmor = 0
			for unit in p.units: unit.level = 3
		root.add_child(b)
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var foe: Dictionary = gs.player(1)
		hand(b,["c11501"])
		await create_timer(0.25).timeout
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0, "strike real click opens target picker")
		check(gs.valid_targets(0,b._pending_target_card_def).has(p.units[2].uid), "strike includes friendly living unit")
		check(not gs.valid_targets(0,b._pending_target_card_def).has("avatar-1"), "strike excludes avatar")
		escape()
		check(p.hand.size() == 1 and p.energy == 20, "escape cancel no spent card or energy")
		foe.units[2].armorBreak = 2
		b._last_view = {}
		b._refresh()
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(foe.units[2].uid)))
		await settled(b)
		check(p.hand.size() == 1 and p.hand[0].instanceId == "poison-ui-0", "actual target click returns same strike")
		check(b._hand_row.get_child(0).data.value == 2, "returned strike face retains two damage")
		check(not b._hand_row.get_child(0).data.has("autoResponse"), "ordinary strike face has no fabricated response badge")
		b._on_hand_hover(true,b._hand_row.get_child(0))
		check(faces(b._tooltip).any(func(f): return "此牌已失去回手能力" in str(f.data.text)), "hover inspector shows return consumed")
		await capture("%d-01-snake-return" % physical.x)
		b._hide_tooltip()
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(p.units[2].uid)))
		await settled(b)
		check(p.hand.is_empty(), "second actual mouse use does not return")
		hand(b,["c11505"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		check(gs.valid_targets(0,b._pending_target_card_def).has("avatar-0") and gs.valid_targets(0,b._pending_target_card_def).has("avatar-1"), "scorch exposes both avatar targets")
		await click(b._enemy_target_btn)
		await settled(b)
		check(foe.avatarHp == 25 and foe.avatarArmorBreak == 0, "enemy avatar mouse choice grants2 then hits5")
		check(b._pending_target_card == -1 and p.hand.is_empty(), "scorch closes picker after use")
		hand(b,["c11507"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		check(gs.valid_targets(0,b._pending_target_card_def).size() == 4, "shield highlights only four allies")
		await click(b._unit_widget(str(p.units[2].uid)))
		await settled(b)
		# The preceding friendly snake strike leaves two armor break: real armor
		# cancels that break before any shield remains; the granted ability stays.
		check(p.units[2].shield == 0 and p.units[2].armorBreak == 0 and p.units[2].poisonShieldTurn == gs.turn_counter, "shield cancels snake break and grants temporary ability")
		b._show_unit_popover(p.units[2],0,2)
		check("剧毒之盾 · 战斗伤害后3破甲" in texts(b._tooltip), "shield rule visible in unit inspector")
		await capture("%d-02-toxic-shield" % physical.x)
		b._hide_tooltip()
		hand(b,["c11507"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(p.units[3].uid)))
		await settled(b)
		check(p.units[3].shield == 2 and p.units[3].armorBreak == 0 and p.units[3].poisonShieldTurn == gs.turn_counter, "unmarked ally gains full two armor and temporary ability")

		hand(b,["c11404","c11406","c11403"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(p.units[0].attack == 4 and p.units[0].maxHp == 16 and p.units[0].armorBreak == 2, "swollen real card click applies modern4/16")
		check(b._hand_row.get_child(0).data.value == 2, "stiff face uses live self break")
		b._show_unit_popover(p.units[0],0,0)
		check("破甲保留" in texts(b._tooltip), "retained break status visible")
		await capture("%d-03-retained-break" % physical.x)
		b._hide_tooltip()
		gs._begin_turn(0)
		p.levelUpUsed = true
		b._last_view = {}
		b._refresh()
		check(gs._kw(b._hand_row.get_child(1).data,"instant") == (gs.front_index(0) >= 0), "fountain instant uses actual front-at-start enhancement")
		root.remove_child(b)
		b.free()
		await process_frame
	Support.cleanup_audio()
	await process_frame
	await process_frame
	Support.cleanup_stores(stores)
	print("POISON_PAIR_UI checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
