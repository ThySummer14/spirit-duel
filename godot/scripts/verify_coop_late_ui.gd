extends "res://scripts/verify_book_jue_ui.gd"


func find_option(b, mode: String) -> Control:
	if not is_instance_valid(b._origin_choice_layer): return null
	for face in faces(b._origin_choice_layer):
		if face.get_meta("origin_option", "") == mode: return face
	return null


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
		b.setup(["hetong", "liyujing", "quanshen", "yingcao"], ["bingyong", "bailang", "taohuayao", "shantong"], 1142165)
		b._ai_thinking = true
		var gs := b.gs
		var p := gs.player(0)
		for side in gs.players:
			side.hand.clear()
			side.levelUpUsed = true
			for unit in side.units: unit.level = 2
		p.energy = 10
		p.units[0].level = 1
		gs.phase = "main"
		root.add_child(b)
		hand(b, ["c213282"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		var koi := find_option(b, "c213282:liyujing")
		var kappa := find_option(b, "c213282:hetong")
		check(koi != null and kappa != null, "共用手牌打开真实双面菜单")
		if koi == null or kappa == null:
			b.queue_free()
			continue
		check(koi.data.name == "潮汐共舞" and kappa.data.name == "碧波连弹" and kappa.modulate.a < 0.5, "分支身份和勾玉不足反馈各自显示")
		await capture("%d-01-cooperation-faces" % physical.x)
		await click(kappa)
		check(p.hand.size() == 1 and p.energy == 10 and is_instance_valid(b._origin_choice_layer), "点击不可使用的河童分支保留手牌和选择")
		await click(koi)
		check(b._pending_target_card == 0 and b._pending_target_card_def.coopFaceId == "c213282:liyujing", "鲤鱼精分支打开自己的合法目标模式")
		await click(b._unit_widget(str(p.units[1].uid)))
		check(b._pending_target_card == 0 and p.hand.size() == 1 and p.energy == 10, "真实鼠标拒绝鲤鱼精本人作为攻击者")
		await capture("%d-02-cooperation-targets" % physical.x)
		var hp := int(gs.player(1).avatarHp)
		var attacker: Dictionary = p.units[2]
		var power := int(attacker.attack)
		await click(b._unit_widget(str(attacker.uid)))
		await settled(b)
		check(p.hand.is_empty() and p.energy == 9 and int(gs.player(1).avatarHp) == hp - power - 1, "合法同伴点击消耗一张共用牌并发起真实攻击")
		b.queue_free()
		await process_frame
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("COOP_LATE_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
