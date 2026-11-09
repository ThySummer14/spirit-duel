extends SceneTree

const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
const Gift := preload("res://scripts/gift_energy_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GIFT_UI_FAIL ", detail)

func click(face: Control) -> void:
	if face == null: return
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

func option(node: Node, mode: Variant) -> Control:
	if node == null: return null
	if node is Control and node.has_meta("origin_option") and str(node.get_meta("origin_option")) == str(mode): return node
	for child in node.get_children():
		var found := option(child, mode)
		if found != null: return found
	return null

func settled(b: Battle) -> void:
	await create_timer(b._presentation_remaining() + 0.2).timeout
	await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	root.theme = ThemeBuilder.build_theme()
	root.size = Vector2i(1280, 800)
	var b := Battle.new()
	b.setup(["longzi", "yanyanluo-fumiao", "rihefang-qingyang", "shantong"], ["taohuayao", "xuenv", "bingyong", "yanyanluo"], 20261109)
	b._ai_thinking = true
	var gs := b.gs
	gs.turn_counter = 21
	for p in gs.players:
		p.hand.clear()
		p.energy = 8
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.charge = 0
	var p := gs.player(0)
	var e := gs.player(1)
	p.units[1].charge = 4
	var instance := Gift.fresh_instance(gs, 0, "c63601")
	p.hand.append(instance)
	root.add_child(b)
	await settled(b)

	await click(b._hand_row.get_child(0))
	check(is_instance_valid(b._origin_choice_layer), "mouse opens base and gift panel")
	var gift := option(b._origin_choice_layer, "gift:0")
	check(gift != null and option(b._origin_choice_layer, false) != null, "both playable paths represented")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	check(not is_instance_valid(b._origin_choice_layer) and p.units[1].charge == 4 and not instance.get("giftSpent", false), "Esc cancels without payment")
	await click(b._hand_row.get_child(0))
	gift = option(b._origin_choice_layer, "gift:0")
	await click(gift)
	check(b._pending_target_card == 0 and b._pending_use_origin == "gift:0", "gift goes to real target selector")
	var ally := b._unit_widget(str(p.units[0].uid))
	await click(ally)
	check(b._pending_target_card == 0 and p.units[1].charge == 4, "ally not eligible for enemy stun")
	var enemy := b._unit_widget(str(e.units[0].uid))
	await click(enemy)
	await settled(b)
	check(int(e.units[0].frozen) > 0 and p.hand.size() == 1 and p.hand[0].instanceId == instance.instanceId and p.hand[0].giftSpent, "click resolves stun and original instance returns")

	b.queue_free()
	await process_frame
	Support.cleanup_audio()
	Support.cleanup_stores(stores)
	await process_frame
	print("GIFT_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
