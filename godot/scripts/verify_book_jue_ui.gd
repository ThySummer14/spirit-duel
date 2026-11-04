extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Rules := preload("res://scripts/book_jue_rules.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BOOK_JUE_UI_FAIL ", detail)
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
	for i in ids.size(): b.gs.player(owner).hand.append({"instanceId": "book-jue-ui-%d-%d" % [owner, i], "definitionId": ids[i], "revealed": shown})
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
		b.setup(["shuweng", "jue", "fenghuanghuo", "taohuayao"], ["jue", "shuweng", "xuenv", "fenghuanghuo"], 20261013)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear()
			p.energy = 40
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		root.add_child(b)
		await create_timer(0.5).timeout
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var enemy: Dictionary = gs.player(1)
		hand(b, ["c12008", "c11901", "xueqiu"], 1)
		hand(b, ["c12001"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0, "read enters target mode")
		var energy: int = p.energy
		await click(b._unit_widget(str(p.units[0].uid)))
		check(b._pending_target_card == 0 and p.energy == energy, "read rejects own unit without paying")
		await click(b._unit_widget(str(enemy.units[2].uid)))
		await settled(b)
		check(enemy.hand[2].revealed and not enemy.hand[0].revealed, "real mouse chooses token owner's dedicated reveal")
		check(b._enemy_hand.get_child(2).face_down == false and b._enemy_hand.get_child(0).face_down, "enemy hand shows only actually revealed instance")
		await capture("%d-01-revealed-hand" % physical.x)
		await click(b._enemy_hand.get_child(2))
		await create_timer(0.2).timeout
		check(texts(b).contains("雪球"), "revealed enemy card opens full inspector")
		escape()
		await create_timer(0.25).timeout
		hand(b, ["c11907", "c11908", "c12008"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(gs.pending_choice.get("type") == "book-dispatch" and is_instance_valid(b._choice_layer), "cloud travel real mouse opens dispatch UI")
		check(texts(b._choice_layer).contains("剩余3次"), "dispatch exposes remaining count")
		await capture("%d-02-cloud-choice" % physical.x)
		var original: String = p.hand[0].instanceId
		var tile := choice_face(b, "c11908")
		check(tile != null, "dispatch presents actual card")
		if tile != null: await click(tile)
		await settled(b)
		check(gs.pending_choice.get("remaining") == 2 and p.hand[0].instanceId != original, "real click replaces card and opens second choice")
		var finish := choice_face(b, Rules.FINISH)
		check(finish != null, "dispatch has explicit finish choice")
		if finish != null: await click(finish)
		await settled(b)
		check(gs.pending_choice.is_empty() and not is_instance_valid(b._choice_layer), "finish real mouse closes and resumes")
		hand(b, ["c12003"])
		hand(b, ["c11908", "c12008"], 1)
		enemy.hand[0].revealed = true
		b._last_view = {}
		b._refresh()
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(gs.pending_choice.get("zoneOwner") == 1 and choice_face(b, "c11908") != null and choice_face(b, "c12008") == null, "extortion UI shows revealed opponent card only")
		await capture("%d-03-extortion-choice" % physical.x)
		tile = choice_face(b, "c11908")
		if tile != null: await click(tile)
		await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.size() == 1 and not enemy.hand[0].get("revealed", false), "actual extortion returns card and draws after dispatch")
		hand(b, ["c11904"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		gs.VerifiedRules.BookJue.turn_draw(gs, 0)
		b._last_view = {}
		b._refresh()
		await settled(b)
		check(gs.pending_choice.get("type") == "book-mind" and faces(b._choice_layer).size() == 3, "mind presents exactly three choices")
		check(texts(b._choice_layer).contains("置入手牌"), "mind instruction is explicit")
		var selected: String = gs.pending_choice.instanceIds[0]
		await capture("%d-04-mind-choice" % physical.x)
		await click(choice_face(b))
		await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.any(func(i): return i.instanceId == selected), "mind real mouse obtains selected instance")
		check(gs.snapshot().pendingChoiceState.is_empty(), "choice snapshot updated after UI completion")
		hand(b, ["c12005"])
		gs._damage_unit(0, 0, 1, 1, 0)
		enemy.units[0].shield = 99
		enemy.units[0].barrier = true
		b._last_view = {}
		b._refresh()
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def) == [enemy.units[0].uid], "new grudge UI targets only enemy that dealt damage")
		energy = p.energy
		await click(b._unit_widget(str(enemy.units[1].uid)))
		check(b._pending_target_card == 0 and p.energy == energy, "grudge rejects enemy without damage history")
		await capture("%d-05-grudge-target" % physical.x)
		await click(b._unit_widget(str(enemy.units[0].uid)))
		await settled(b)
		check(enemy.units[0].hp == 0 and p.hand.is_empty(), "mouse grudge truly destroys through armor and barrier")
		b.queue_free()
		await process_frame
		await process_frame
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("BOOK_JUE_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
