extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Rules := preload("res://scripts/sun_smoke_rules.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SUN_SMOKE_UI_FAIL ", detail)
func click(face: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
	root.push_input(motion, true)
	await process_frame
	await create_timer(0.14).timeout
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
func settled(b) -> void:
	for i in 3: await process_frame
	await create_timer(b._presentation_remaining() + 0.20).timeout
	await process_frame
func hand(b, ids: Array, owner: int = 0, shown: bool = false) -> void:
	b.gs.player(owner).hand.clear()
	for i in ids.size(): b.gs.player(owner).hand.append({"instanceId": "sun-smoke-ui-%d-%d" % [owner, i], "definitionId": ids[i], "revealed": shown})
	b._last_view = {}
	b._refresh()
func faces(n: Node) -> Array:
	var result: Array = []
	if n is Control and n.get("data") is Dictionary and n.get("data").has("id"): result.append(n)
	for child in n.get_children(): result.append_array(faces(child))
	return result
func choice_face(b, id: String = "") -> Control:
	for face in faces(b._choice_layer):
		if id == "" or str(face.data.id) == id: return face
	return null
func texts(n: Node) -> String:
	var value := str(n.text) + "\n" if n is Label or n is RichTextLabel else ""
	for child in n.get_children(): value += texts(child)
	return value
func capture(name: String) -> void:
	if out.is_empty(): return
	await create_timer(0.25).timeout
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(["rihefang", "yanyanluo", "taohuayao", "shantong"], ["yanyanluo", "rihefang", "xuenv", "jutun-tongzi"], 20261014)
		b._ai_thinking = true
		b.gs.turn_counter = 20
		for p in b.gs.players:
			p.hand.clear()
			p.energy = 40
			p.levelUpUsed = true
			for unit in p.units:
				unit.level = 3
				unit.charge = 0
		root.add_child(b)
		await create_timer(0.5).timeout
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var e: Dictionary = gs.player(1)
		e.units[0].baseMaxHp = 30; e.units[0].maxHp = 30; e.units[0].hp = 30
		p.units[1].charge = 3
		hand(b, ["c16401"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0, "targeted smoke enters mouse target mode")
		var fire: int = p.energy
		await click(b._unit_widget(str(p.units[0].uid)))
		check(b._pending_target_card == 0 and p.energy == fire, "wrong friendly smoke target keeps hand and ghost fire")
		await click(b._unit_widget(str(e.units[0].uid)))
		await settled(b)
		check(gs.pending_choice.get("type") == "smoke-burst" and choice_face(b, "smoke-plain") != null and choice_face(b, "smoke-burst") != null, "actual target click opens both burst choices")
		check(texts(b._choice_layer).contains("3能量") and e.units[0].hp == 30, "choice UI exposes exact pending resource and delays hit")
		await capture("%d-01-burst-choices" % physical.x)
		await click(choice_face(b, "smoke-plain"))
		await settled(b)
		check(gs.pending_choice.is_empty() and p.units[1].charge == 3 and e.units[0].hp == 28, "mouse decline preserves energy and resolves base2")
		hand(b, ["c16401"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(e.units[0].uid)))
		await settled(b)
		await click(choice_face(b, "smoke-burst"))
		await settled(b)
		check(gs.pending_choice.is_empty() and p.units[1].charge == 0 and e.units[0].hp == 23, "mouse burst pays3 and resolves exactly5")
		hand(b, ["c16407"])
		p.units[1].charge = 6
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(gs.pending_choice.get("type") == "smoke-pick" and faces(b._choice_layer).size() == 3, "latest form has three actual burst-card candidates")
		check(choice_face(b, "c16408") != null and choice_face(b, "c16408").data.value == 4 and texts(b._choice_layer).contains("爆能牌"), "choice displays actual2024 damage and clear obtain instruction")
		check(gs.front_index(0) < 0, "printed generated choice precedes clone summon")
		await capture("%d-02-generated-burst" % physical.x)
		await click(choice_face(b, "c16408"))
		await settled(b)
		var clone: Dictionary = gs.front_unit(0)
		check(gs.pending_choice.is_empty() and p.hand[0].definitionId == "c16408" and clone.get("smokeClone", false), "mouse chooses generated card and resumes clone creation")
		var clone_widget := b._unit_widget(str(clone.uid))
		check(clone_widget != null and clone.attack == 3 and clone.maxHp == 6 and clone.charge == 3, "real front UI renders3/6 half-charge clone")
		await capture("%d-03-clone-front" % physical.x)
		e.units[0].front = 1
		b._last_view = {}; b._refresh()
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(gs.pending_choice.get("type") == "smoke-burst", "generated hand card is really playable")
		await click(choice_face(b, "smoke-burst"))
		await settled(b)
		check(p.units[1].charge == 0 and clone.charge == 0 and e.units[0].hp == 6, "generated burst copied uses6+3 energy separately")
		check(gs.rule_events.any(func(ev): return ev.kind == "smoke-spell-copy"), "UI play registers actual clone copy")
		hand(b, ["c16602"])
		e.units[1].barrier = true
		b._last_view = {}; b._refresh()
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0, "heat mouse enters chosen unit targeting")
		await click(b._unit_widget(str(e.units[1].uid)))
		await settled(b)
		check(e.units[1].hp == 6 and e.units[1].frozen == 1 and not e.units[1].barrier, "mouse heat stuns even shielded damage")
		await capture("%d-04-heat-stun" % physical.x)
		gs._grow_unit(p.units[0], 3, 3)
		p.units[0].shield = 3; p.units[0].armorBreak = 2; p.units[0].hp = 1
		hand(b, ["c16606"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(p.units[0].uid)))
		await settled(b)
		check(p.units[0].attack == 1 and p.units[0].maxHp == 6 and p.units[0].hp == 6 and p.units[0].shield == 0 and p.units[0].armorBreak == 0, "mouse reset restores actual body and removes armor/break")
		await capture("%d-05-reset-body" % physical.x)
		b.queue_free()
		await process_frame
		await process_frame
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("SUN_SMOKE_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
