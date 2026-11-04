extends "res://scripts/verify_book_jue_ui.gd"
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
		b.setup(["huang","jiuciliang","xixueji","yingcao"],["shantong","bingyong","yaodaoji","qingshe"],17800)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear(); p.energy = 40; p.levelUpUsed = true
			for u in p.units: u.level = 3
		root.add_child(b)
		await create_timer(0.3).timeout
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		hand(b,["c17803"])
		await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size() == 1 and p.energy == 40,"sea clicked from hand with real instant payment")
		check(b._ally_realms.get_child_count() == 1,"new realm has actual inspector entry")
		await click(b._ally_realms.get_child(0)); await settled(b)
		check(texts(b).contains("回手") and texts(b).contains("当前耐久1"),"realm inspector shows current durability and return ability")
		await capture("%d-01-sea-inspector" % physical.x)
		escape(); await process_frame
		b._hide_tooltip()
		gs._damage_avatar(0,1,1,0)
		b._last_view = {}; b._refresh(); await settled(b)
		check(p.hand.size() == 1 and gs.hand_card_def(0,0).text.contains("已失去"),"returned copy displays lost ability in real hand")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size() == 1 and not p.realms[0].returnOnDestroy and p.energy == 39,"returned sea clicked for cost1 cannot bounce twice")
		gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"测试消灭")
		check(p.hand.is_empty(),"second sea destruction has no returned card")
		hand(b,["c17802","c17805","c17902","c17803"])
		p.deck = [{"instanceId":"huang-ui-bottom","definitionId":"c17801"},{"instanceId":"huang-ui-middle","definitionId":"c17804"},{"instanceId":"huang-ui-top","definitionId":"c17806"}]
		await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.type == "huang-discard" and b._choice_layer != null,"real afterglow mouse opens choice")
		check(faces(b._choice_layer).size() == 2 and choice_face(b,"c17805") == null,"choice contains only eligible realm hand instances")
		check(texts(b._choice_layer).contains("弃一张幻境"),"choice tells discard then draw order")
		check(p.deck.size() == 3,"no draw before choice")
		await capture("%d-02-afterglow-choice" % physical.x)
		await click(choice_face(b,"c17902")); await settled(b)
		check(gs.pending_choice.is_empty() and b._choice_layer == null,"mouse selection resumes original resolution")
		check(p.hand.size() == 5 and p.deck.is_empty() and p.hand[2].instanceId == "huang-ui-top","foreign-source realm discarded and original top3 drawn")
		check(b._hand_row.get_child_count() == 5,"real hand refresh renders five remaining cards")
		# Every remaining subject card is used through the real hand widgets.
		for id in ["c17801","c17804","c17806"]:
			hand(b,[id]); await settled(b)
			await click(b._hand_row.get_child(0)); await settled(b)
			check(p.realms.back().cardId == id,"mouse deploys exact realm " + id)
		hand(b,["c17805"]); await settled(b)
		check(gs.hand_card_def(0,0).value.attack == 8 and gs.hand_card_def(0,0).text.contains("当前幻境3"),"body preview responds to actual realm count")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].attack == 8 and p.units[0].maxHp == 8,"mouse body installs exact8/8")
		hand(b,["c17808"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].awakened and p.units[0].attack == 9,"mouse awakening keeps printed1/1")
		hand(b,["c17807"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].attack == 6 and p.units[0].maxHp == 9,"mouse spiral replaces form with exact5/8 and awakening")
		hand(b,["c17803"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.player(1).avatarHp == 24 and p.units[0].swift and p.units[0].front == 1,"mouse realm use causes actual spiral attack and grants swift")
		check(p.realms.map(func(r):return int(r.hp)) == [5,5,18,1],"existing realms gain once, moon gets3, new sea installed afterward")
		check(b._ally_realms.get_child_count() == 4,"all installed realms remain visible in order")
		await click(b._ally_realms.get_child(2)); await settled(b)
		check(texts(b).contains("当前耐久18") and texts(b).contains("30"),"moon inspector shows real progress and detonation threshold")
		await capture("%d-03-moon-durability" % physical.x)
		escape(); await process_frame
		b._hide_tooltip()
		b._show_unit_popover(p.units[0],0,0)
		check(texts(b._tooltip).contains("迅捷") and texts(b._tooltip).contains("幻境"),"source inspector exposes swift and actual form ability")
		await capture("%d-04-spiral-swift" % physical.x)
		b._hide_tooltip()
		b.queue_free(); await process_frame
	Support.cleanup_audio(); Support.cleanup_stores(stores)
	await process_frame
	print("HUANG_UI checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
