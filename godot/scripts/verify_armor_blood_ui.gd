extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ARMOR_BLOOD_UI_FAIL ", detail)
func click(face: Control) -> void:
	if face == null:
		check(false,"click target exists")
		return
	var motion := InputEventMouseMotion.new()
	motion.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
	root.push_input(motion, true)
	await process_frame
	await create_timer(0.14).timeout
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event,true)
func settled(b) -> void:
	for _i in 3: await process_frame
	await create_timer(b._presentation_remaining() + 0.2).timeout
	await process_frame
func hand(b, ids: Array) -> void:
	b.gs.player(0).hand.clear()
	for i in ids.size(): b.gs.player(0).hand.append({"instanceId":"armor-blood-ui-%d" % i,"definitionId":ids[i]})
	b._last_view = {}; b._refresh()
func texts(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label or node is RichTextLabel else ""
	for child in node.get_children(): result += texts(child)
	return result
func capture(name: String) -> void:
	if out.is_empty(): return
	await create_timer(0.2).timeout
	await process_frame
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
		b.setup(["jiuciliang","xixueji","qingfangzhu","fenghuanghuo"],["yaodaoji","bingyong","yingcao","shantong"],20261015)
		b._ai_thinking = true
		b.gs.turn_counter = 20
		for p in b.gs.players:
			p.hand.clear(); p.energy = 40; p.levelUpUsed = true
			for u in p.units: u.level = 3
		b.gs.player(0).units[2].level = 0
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var e: Dictionary = gs.player(1)
		hand(b,["c17903"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0,"white bone enters real target mode")
		var fire: int = p.energy
		await click(b._unit_widget(str(p.units[0].uid)))
		check(b._pending_target_card == 0 and p.energy == fire and p.hand.size() == 1,"caster click rejected without payment")
		await click(b._unit_widget(str(e.units[0].uid)))
		check(b._pending_target_card == 0 and p.energy == fire,"enemy click rejected without consuming white bone")
		await click(b._unit_widget(str(p.units[1].uid)))
		await settled(b)
		check(p.hand.is_empty() and p.units[1].attack == 4 and p.units[1].shield == 4,"mouse ally receives armor4 and one temporary power")
		b._show_unit_popover(p.units[1],0,1)
		check(texts(b._tooltip).contains("白骨之盾 · 本回合有甲+1力量"),"inspector shows true ability lifetime")
		await capture("%d-01-bone-shield" % physical.x)
		b._hide_tooltip()
		gs.VerifiedRules.end_turn(gs,0)
		check(p.units[1].attack == 3 and p.units[1].shield == 4,"temporary power expires independently of remaining armor")
		hand(b,["c17902","c17906"])
		await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size() == 1 and p.realms[0].hp == 6,"mouse realm deploys exact6 durability")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].maxHp == 8 and p.units[0].shield == 3 and p.units[1].shield == 7,"square gives exact conditional team armor")
		check(texts(b._ally_realms).contains("帷幕"),"realm chips expose actual veil")
		check(not gs.valid_targets(1,gs.ContentLoader.card_def("c17302")).has(p.units[0].uid),"enemy UI uses shared veil target restriction")
		e.units[0].front = 1
		hand(b,["c17302"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(gs.valid_targets(0,b._pending_target_card_def).has(e.units[0].uid),"blood shield exposes enemy front as legal target")
		var before_fire: int = p.energy
		await click(b._ally_realms.get_child(0))
		check(b._pending_target_card == 0 and p.energy == before_fire,"illegal realm target preserves active card and payment")
		await click(b._unit_widget(str(e.units[0].uid))); await settled(b)
		check(e.units[0].get("bloodTransfer",false),"actual enemy click attaches one-shot replacement")
		b._show_unit_popover(e.units[0],1,0)
		check(texts(b._tooltip).contains("血蝠之盾 · 下次伤害转移"),"enemy inspector distinguishes transfer from unyielding")
		await capture("%d-02-blood-transfer" % physical.x)
		b._hide_tooltip()
		await click(b._unit_widget(str(p.units[0].uid)))
		check(b._selected_attacker == 0,"mouse selects armored whale for attack")
		await click(b._unit_widget(str(e.units[0].uid))); await settled(b)
		check(e.units[0].hp == 4 and e.avatarHp == 24 and not e.units[0].get("bloodTransfer",false),"mouse combat transfers6 to avatar and consumes replacement")
		check(gs.rule_events.any(func(event):return event.kind == "combat-damage-resolved" and event.get("transferred",false) and event.target == "" and event.amount == 6),"combat visual event points to actual avatar damage recipient")
		hand(b,["c17308","c17303"])
		p.avatarHp = 20
		await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[1].maxHp == 8 and p.avatarHp == 20,"moon mouse entry has no invented healing")
		gs._heal_avatar(1,2)
		b._refresh(); await settled(b)
		check(b._hand_row.get_child(0).data.value == 2,"held rage updates after opponent recovery event")
		await click(b._hand_row.get_child(0))
		check(gs.valid_targets(0,b._pending_target_card_def).has("avatar-1") and gs.valid_targets(0,b._pending_target_card_def).has("avatar-0"),"rage exposes both avatars")
		await click(b._enemy_target_btn); await settled(b)
		check(e.avatarHp == 24 and p.avatarHp == 22,"actual avatar target deals2 and lifesteals2 once")
		b._show_unit_popover(p.units[1],0,1)
		check(texts(b._tooltip).contains("猩红之月 · 己方法术吸血"),"inspector shows spell aura and recovery growth")
		await capture("%d-03-moon-recovery" % physical.x)
		b._hide_tooltip()
		hand(b,["c17908"])
		await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size() == 2 and p.realms[1].hp == 10,"treasure is real10 durability realm")
		p.avatarHp = 2
		gs._damage_avatar(0,8,1,0)
		b._refresh(); await settled(b)
		check(p.avatarHp == 1 and p.realms.size() == 1 and p.realms[0].hp == 10,"front guardian breaks and rear treasure prevents lethal packet")
		check(texts(b._ally_realms).contains("1 · 铃鹿山的秘宝 10 · 帷幕"),"ordered realm chip updates durability and veil")
		var chip: Control = b._ally_realms.get_child(0)
		check(chip.get_global_rect().end.x <= b.size.x and chip.get_global_rect().end.y <= b.size.y,"realm detail target fits viewport")
		await click(chip); await settled(b)
		check(texts(b).contains("当前耐久10 · 第1个幻境 · 帷幕"),"realm click opens actual current-state inspector")
		await capture("%d-04-realm-inspector" % physical.x)
		escape(); await process_frame
		hand(b,["c17306"])
		p.avatarHp = 30; b._refresh(); await settled(b)
		check(b._hand_row.get_child(0).data.combatOption.get("immuneCombat",false),"scent card at30 quotes official immunity")
		check(not "combo" in b._hand_row.get_child(0).data.keywords,"stale combo not shown")
		p.avatarHp = 29; b._refresh(); await settled(b)
		check(not b._hand_row.get_child(0).data.combatOption.get("immuneCombat",false),"scent quote removes immunity when condition is false")
		root.remove_child(b); b.free(); await process_frame
	Support.cleanup_audio()
	await process_frame
	await process_frame
	Support.cleanup_stores(stores)
	print("ARMOR_BLOOD_UI checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
