extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FOX_SUZUKA_UI_FAIL ", text)
func click(face: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
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
	for i in ids.size(): b.gs.player(0).hand.append({"instanceId":"fox-ui-%d" % i,"definitionId":ids[i]})
	b._last_view = {}
	b._refresh()
func settled(b) -> void:
	for i in 3: await process_frame
	await create_timer(b._presentation_remaining()+0.18).timeout
	await process_frame
func capture(name: String) -> void:
	if out.is_empty(): return
	await create_timer(0.15).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
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
		b.setup(["yaohu","lingyuyuqian","fenghuanghuo","qingwa-ciqi"],["yaodaoji","yingcao","bingyong","guniao"],20261014)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for u in p.units: u.level = 3
		root.add_child(b)
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var foe: Dictionary = gs.player(1)
		p.units[0].awakened = true
		p.units[3].level = 0
		for u in foe.units:
			u.hp = 100
			u.maxHp = 100
			u.passive_hooks = []
		hand(b,["c13407"])
		await create_timer(0.25).timeout
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0, "slash mouse opens target picker")
		check(gs.valid_targets(0,b._pending_target_card_def).has(p.units[1].uid), "slash can select friendly unit")
		check(not gs.valid_targets(0,b._pending_target_card_def).has("avatar-1"), "slash excludes avatar")
		escape()
		check(p.hand.size() == 1 and p.energy == 20, "escape cancels without payment")
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(foe.units[0].uid)))
		await settled(b)
		check(p.hand.is_empty() and p.energy == 19, "mouse enemy target uses repeat with one fire")
		check(gs.rule_events.filter(func(e):return e.kind == "fox-suzuka-hit" and e.card.id == "c13407").size() == 2, "actual click gives two separate slash damage events")
		hand(b,["c13408","c13401"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._hand_row.get_child(0).data.foxHandDamageBonus == 1, "remaining hand spell quote receives aura")
		b._on_hand_hover(true,b._hand_row.get_child(0))
		check(faces(b._tooltip).any(func(f): return "爱意绵绵：此牌的法术伤害效果+1" in str(f.data.text)), "hover explains live spell damage bonus")
		await capture("%d-01-love-spell" % physical.x)
		b._hide_tooltip()
		p.units[0].foxDamageEvents = 24
		b._show_unit_popover(p.units[0],0,0)
		check("伤害 24/25次" in texts(b._tooltip), "inspector displays actual fox damage history")
		b._hide_tooltip()
		p.units[0].level = 0
		foe.units[0].front = 1
		foe.units[2].armorBreak = 1
		hand(b,["c18006"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		var opts: Array = gs.valid_targets(0,b._pending_target_card_def)
		check(opts.has(foe.units[0].uid) and opts.has(foe.units[2].uid), "nowhere highlights front and marked reserve")
		check(not opts.has(foe.units[1].uid) and not opts.has(p.units[0].uid), "nowhere excludes unmarked reserve and allies")
		await capture("%d-02-nowhere-targets" % physical.x)
		var reserve_hp := int(foe.units[2].hp)
		await click(b._unit_widget(str(foe.units[2].uid)))
		await settled(b)
		check(foe.units[2].hp == reserve_hp - 3 and foe.units[2].front == 0, "reserve selected damage does not move chosen unit to front")
		check(p.units[1].front == 1 and foe.units[0].hp < 100, "combat then attacks actual front")
		foe.units[2].armorBreak = 2
		hand(b,["c18001"])
		await create_timer(0.2).timeout
		check(gs.effective_card_cost(0,b._hand_row.get_child(0).data) == 0, "white dynamic instant displayed at correct payment")
		b._on_hand_hover(true,b._hand_row.get_child(0))
		check("瞬发可用" in texts(b._tooltip), "white hover payment has instant explanation")
		b._hide_tooltip()
		hand(b,["c18002"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		await settled(b)
		b._show_unit_popover(p.units[1],0,1)
		check("霸主 · 免疫带破甲式神伤害" in texts(b._tooltip), "boss live immunity inspector")
		await capture("%d-03-boss-state" % physical.x)
		b._hide_tooltip()
		root.remove_child(b)
		b.free()
		await process_frame
	Support.cleanup_audio()
	await process_frame
	await process_frame
	Support.cleanup_stores(stores)
	print("FOX_SUZUKA_UI checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
