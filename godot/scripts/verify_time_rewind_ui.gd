extends "res://scripts/verify_time_rewind.gd"

func _initialize() -> void:
	run.call_deferred()

func settle(battle: Control) -> void:
	await process_frame
	await process_frame
	await create_timer(battle._presentation_remaining() + 0.18).timeout
	await process_frame

func choice(node: Node, name_part: String) -> Control:
	if node is Control and "data" in node and node.data is Dictionary and name_part in str(node.data.get("name", "")):
		return node
	for child in node.get_children():
		var found := choice(child, name_part)
		if found != null: return found
	return null

func run() -> void:
	var stores := Support.isolate_stores()
	root.theme = ThemeBuilder.build_theme()
	for dims in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = dims
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(dims)
		var battle := Battle.new()
		battle.setup(PARTY, FOE, 93108)
		battle._ai_thinking = true
		root.add_child(battle)
		var gs := battle.gs
		prepare(gs)
		if gs.phase == "opening": gs.confirm_opening([])
		gs.player(0).hand.clear()
		var bottom := Insight.instance(gs, 0, "w13-shiyao-longyechaji-93101")
		var top := Insight.instance(gs, 0, "c10101")
		gs.player(0).deck.assign([bottom, top])
		give(gs, "w13-shiyao-longyechaji-93102")
		battle._last_view = {}
		battle._refresh()
		await settle(battle)
		var hand := battle._hand_row.get_child(0) as Control
		check(hand != null, "主战场显示时空之旅")
		if hand != null: await click(hand)
		await settle(battle)
		check(gs.pending_choice.get("type") == Fate.KIND, "点击时空之旅打开真实抉择")
		if not is_instance_valid(battle._choice_layer):
			check(false, "缺少抉择层")
			battle.queue_free()
			continue
		var keep := choice(battle._choice_layer, "顺应")
		var swap := choice(battle._choice_layer, "逆天")
		check(keep != null and swap != null, "两种选择都可见")
		if swap != null: await click(swap)
		await settle(battle)
		check(gs.pending_choice.is_empty() and gs.player(0).hand.size() == 1 and gs.player(0).hand[0] == bottom, "鼠标选择逆天后从真实牌库抽到原底牌")
		battle.queue_free()
		await process_frame
	Support.cleanup_audio()
	Support.cleanup_stores(stores)
	print("TIME_REWIND_UI checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
