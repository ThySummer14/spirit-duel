extends "res://scripts/verify_armor_blood_ui.gd"
const Glossary := preload("res://scripts/ui/keyword_glossary.gd")
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
		b.setup(["shantu","haifangzhu","jiuciliang","bingyong"],["qingshe","yaodaoji","yingcao","shantong"],20261015)
		b._ai_thinking = true
		b.gs.turn_counter = 20
		for p in b.gs.players:
			p.hand.clear(); p.energy = 40; p.levelUpUsed = true
			for u in p.units: u.level = 3
		root.add_child(b)
		await create_timer(0.3).timeout
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var e: Dictionary = gs.player(1)
		for count in [2,3]:
			p.fortuneSixes = count
			p.deck = [{"instanceId":"blessing-ui-bottom","definitionId":"c11701"},{"instanceId":"blessing-ui-top","definitionId":"c11702"}]
			hand(b,["c12702"])
			await settled(b)
			check(gs.hand_card_def(0,0).text.contains("抽一张牌"),"actual hand shows draw before and after enhancement")
			await click(b._hand_row.get_child(0))
			check(b._pending_target_card == 0,"blessing opens real target selection")
			var fire: int = p.energy
			await click(b._unit_widget(str(e.units[1].uid)))
			check(b._pending_target_card == 0 and p.deck.size() == 2 and p.energy == fire,"enemy click cannot draw or pay")
			escape()
			check(b._pending_target_card < 0 and p.deck.size() == 2 and p.hand.size() == 1,"cancel leaves draw pending")
			await click(b._hand_row.get_child(0))
			var target: Dictionary = p.units[2]
			var power := int(target.attack)
			var health := int(target.maxHp)
			await click(b._unit_widget(str(target.uid)))
			await settled(b)
			check(target.attack == power+(3 if count == 3 else 1) and target.maxHp == health+(3 if count == 3 else 1),"mouse ally gets exact enhanced or base growth")
			check(target.get("swift",false) == (count == 3),"mouse ally gets swift only at third six")
			check(p.hand.size() == 1 and p.hand[0].instanceId == "blessing-ui-top" and p.deck.size() == 1 and p.energy == fire-1,"mouse card draws original top card exactly once")
			check(b._hand_row.get_child_count() == 1,"drawn card is visible in real hand")
			await capture("%d-01-blessing-%d" % [physical.x,count])
		var sea: Dictionary = p.units[1]
		sea.shield = 65534; sea.shieldExpires = 0
		hand(b,["c17903"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(sea.uid)))
		await settled(b)
		check(sea.shield == 65535 and sea.shieldExpires == 1,"real white bone click uses capped armor and actual temporary portion")
		var face = b._unit_widget(str(sea.uid))
		var stat_r := clampf(face.size.x * 0.12,9,19)
		var armor_width := stat_r * 0.78 * 3
		var armor_font: int = face._number_font("65535",int(stat_r * 0.78 * 1.25),armor_width)
		check(ThemeBuilder.bold_font().get_string_size("65535",HORIZONTAL_ALIGNMENT_LEFT,-1,armor_font).x <= armor_width-2,"all five armor digits fit actual card badge")
		var break_font: int = face._number_font("65535",10,22)
		check(ThemeBuilder.bold_font().get_string_size("65535",HORIZONTAL_ALIGNMENT_LEFT,-1,break_font).x <= 20,"all five break digits fit actual status badge")
		b._show_unit_popover(sea,0,1)
		check(texts(b._tooltip).contains("65535"),"unit inspector exposes full armor value")
		await capture("%d-02-armor-inspector" % physical.x)
		b._hide_tooltip()
		hand(b,["c11703"])
		await settled(b)
		check(gs.hand_card_def(0,0).text.contains("预计65535"),"live cyclone hand preview caps gained armor")
		e.units[1].baseMaxHp = 200000; e.units[1].maxHp = 200000; e.units[1].hp = 200000
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(e.units[1].uid)))
		await settled(b)
		check(e.units[1].hp == 134465 and sea.shield == 65535,"real cyclone target receives exact capped armor damage")
		gs._grant_avatar_armor(0,70000)
		gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,-1,70000)
		gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,1,70000)
		b._last_view = {}; b._refresh()
		await settled(b)
		check(b._ally_armor.text == "甲 65535" and b._enemy_poison.text == "破 65535","avatar labels display actual capped statuses")
		check(Glossary.detail("armor").contains("上限65535") and Glossary.detail("armor-break").contains("上限65535"),"keyword help explains both limits")
		b._show_unit_popover(e.units[1],1,1)
		check(texts(b._tooltip).contains("破甲 65535"),"enemy inspector displays full armor break value")
		await capture("%d-03-break-inspector" % physical.x)
		b._hide_tooltip()
		b.queue_free()
		await process_frame
	Support.cleanup_audio()
	Support.cleanup_stores(stores)
	await process_frame
	print("ARMOR_LIMIT_UI checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
