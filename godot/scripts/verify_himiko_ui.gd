extends "res://scripts/verify_book_jue_ui.gd"

const Himiko := preload("res://scripts/himiko_rules.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const SUNDIAL := "w13-himiko-93153"
const GAP := "w13-himiko-93154"
const AWAKEN := "w13-himiko-93156"
const KNOCKOUT := "w13-himiko-93158"

func choice(b, fragment: String) -> Control:
	if not is_instance_valid(b._choice_layer): return null
	for face in faces(b._choice_layer):
		if str(face.data.name).contains(fragment): return face
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
		b.setup([Himiko.ID, "fenghuanghuo", "shenqi-huang", "bingyong"], ["shantong", "yaodaoji", "yingcao", "huang"], 93158)
		b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear()
			side.energy = 20
			side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(b)
		await create_timer(0.3).timeout
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var foe: Dictionary = gs.player(1)
		p.deck = [
			{"instanceId": "himiko-ui-own-bottom", "definitionId": "w13-shenqi-huang-93118"},
			{"instanceId": "himiko-ui-own-top", "definitionId": "c12403"},
		]
		foe.deck = [
			{"instanceId": "himiko-ui-foe-bottom", "definitionId": "c17802"},
			{"instanceId": "himiko-ui-foe-top", "definitionId": "c11301"},
		]
		gs._knockout_unit(p.units[2])
		hand(b, [GAP]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0, "real mouse opens time gap target mode")
		await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		check(b._pending_target_card == 0 and p.energy == 20, "unavailable target leaves action pending and costs nothing")
		await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(p.realms.size() == 1 and p.realms[0].himikoTarget == p.units[1].uid and p.realms[0].hp == 4, "target click installs selected realm")
		await click(b._ally_realms.get_child(0)); await settled(b)
		check(texts(b).contains("已选择「凤凰火」") and texts(b).contains("当前耐久4"), "realm inspector names linked unit and durability")
		await capture("%d-01-gap" % physical.x)
		escape(); await process_frame
		b._hide_tooltip()

		hand(b, [AWAKEN]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].awakened and b._instant_l.text.contains("1/2") and p.energy == 19, "first slot already used and awakening exposes the second")
		check(p.hand.size() == 1 and p.hand[0].definitionId == Himiko.ECLIPSE, "actual awakening generates eclipse hand tile")
		await capture("%d-02-awaken" % physical.x)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].get("himikoEclipseBonus", 0) == 1 and p.energy == 19 and b._instant_l.text.contains("1/2"), "eclipse boosts real damage without spending fire or instant slot")
		check(p.realms.size() == 1 and p.realms[0].hp == 2 and p.units[1].shield == 1, "zero-fire eclipse empowers selected target and spends realm durability")

		hand(b, [SUNDIAL]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type") == Fate.KIND and p.units[2].hp == 0 and p.energy == 19 and b._instant_l.text.contains("0/2"), "second real instant opens choice without early revival")
		var reverse := choice(b, "牌库底")
		check(reverse != null and reverse.data.id == "w13-shenqi-huang-93118", "choice shows actual defeated unit's bottom card")
		check(texts(b._choice_layer).contains("顺应 · 保留牌库顶") and texts(b._choice_layer).contains("逆天 · 交换到牌库顶"), "choice directions remain visible when original art includes printed text")
		await capture("%d-03-revive" % physical.x)
		if reverse != null: await click(reverse)
		await settled(b)
		check(gs.pending_choice.is_empty() and p.units[2].hp > 0 and p.deck.back().instanceId == "himiko-ui-own-bottom", "mouse swap revives exact card owner and retains actual deck card")
		check(p.realms.is_empty(), "second qualifying hand play expires time gap")

		hand(b, [KNOCKOUT]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type") == Fate.KIND and gs.pending_choice.deckOwner == 1 and p.attackUsed and p.energy == 19, "swift-card spends deployment and displays enemy deck")
		reverse = choice(b, "牌库底")
		if reverse != null: await click(reverse)
		await settled(b)
		check(foe.units[3].hp == 0 and foe.units[3].knockout == 2 and foe.units[0].hp > 0, "enemy swap knocks only revealed card's owner to two")
		b.queue_free()
		await process_frame
	Support.cleanup_audio()
	Support.cleanup_stores(stores)
	await process_frame
	print("HIMIKO_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
