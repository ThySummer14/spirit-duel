extends "res://scripts/verify_book_jue_ui.gd"

const Fate := preload("res://scripts/destiny_choice_rules.gd")
const Shenqi := preload("res://scripts/shenqi_huang_rules.gd")
const COMBAT := "w13-shenqi-huang-93117"
const FATE := "w13-shenqi-huang-93118"
const TRACK := "w13-shenqi-huang-93119"
const FALL := "w13-shenqi-huang-93120"
const BARRAGE := "w13-shenqi-huang-93121"
const CONSTELLATION := "w13-shenqi-huang-93122"
const PROPHECY := "w13-shenqi-huang-93123"
const HEART := "w13-shenqi-huang-93124"

func option(b, title: String) -> Control:
	if not is_instance_valid(b._choice_layer): return null
	for face in faces(b._choice_layer):
		if str(face.data.name).contains(title): return face
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
		b.setup([Shenqi.ID, "shantong", "bingyong", "yaodaoji"], ["jiuciliang", "huang", "shantong", "bingyong"], 93124)
		b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear()
			side.energy = 40
			side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(b)
		await create_timer(0.3).timeout
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		var unit: Dictionary = p.units[0]
		unit.erase("shenqiMeteors")
		p.deck = [
			{"instanceId": "shenqi-ui-bottom", "definitionId": COMBAT},
			{"instanceId": "shenqi-ui-middle", "definitionId": "c17805"},
			{"instanceId": "shenqi-ui-top", "definitionId": "c17808"},
		]
		hand(b, [TRACK]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size() == 1 and b._ally_realms.get_child_count() == 1, "mouse deploys exact track realm")
		await click(b._ally_realms.get_child(0)); await settled(b)
		check(texts(b).contains("当前耐久4") and texts(b).contains("随机敌方角色"), "track inspector has real durability and trigger")
		escape(); await process_frame
		b._hide_tooltip()
		hand(b, [FATE]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type") == Fate.KIND and is_instance_valid(b._choice_layer), "mouse opens actual destiny choice")
		var follow := option(b, "牌库顶")
		var reverse := option(b, "牌库底")
		check(follow != null and reverse != null and follow.data.id == "c17808" and reverse.data.id == COMBAT, "choice displays actual top and bottom cards")
		check(p.hand.is_empty() and p.deck.size() == 3, "displaying choice does not reveal, draw, or reorder")
		await capture("%d-01-fate" % physical.x)
		if reverse != null: await click(reverse)
		await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.size() == 2 and p.hand[0].instanceId == "shenqi-ui-bottom", "mouse reverse reveals former bottom and resumes both draws")
		check(Shenqi.meteors(unit) == 1, "track creates actual meteor after reverse")
		hand(b, [HEART]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(unit.awakened and b._ally_realms.get_child_count() == 2, "mouse deploys awakening realm")
		hand(b, [PROPHECY]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		follow = option(b, "牌库顶")
		reverse = option(b, "牌库底")
		check(reverse != null and reverse.data.id == PROPHECY, "mouse sees generated bottom copy")
		check(Shenqi.meteors(unit) == 3 and Shenqi.swift(gs, unit), "prechoice attachment creates a real swift status")
		if follow != null: await click(follow)
		await settled(b)
		check(gs.pending_choice.is_empty() and p.deck[0].definitionId == PROPHECY and p.deck.back().instanceId == "shenqi-ui-top", "follow click preserves actual endpoints")
		b._show_unit_popover(unit, 0, 0)
		check(texts(b._tooltip).contains("陨星 ×3") and texts(b._tooltip).contains("迅捷"), "inspector displays meteor count and swift")
		await capture("%d-02-meteors" % physical.x)
		b._hide_tooltip()
		hand(b, [FALL]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(unit.attack == 7 and unit.maxHp == 7 and Shenqi.meteors(unit) == 0, "mouse fall spends stars and changes form stats")
		hand(b, [COMBAT]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(unit.front == 1 and gs.player(1).avatarHp < 30, "mouse plays combat card using legal automatic target")
		hand(b, [CONSTELLATION]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(unit.form.cardId == CONSTELLATION and unit.get("shenqiCritTurn", -1) == gs.turn_counter, "mouse constellation reveals top and applies spell branch")
		var hp: int = gs.player(1).avatarHp
		hand(b, [BARRAGE]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.rule_events.any(func(e): return e.kind == "damage-resolved" and e.get("card", {}).get("id") == BARRAGE) and gs.player(1).avatarHp <= hp, "mouse barrage runs source-attributed random damage")
		b.queue_free()
		await process_frame
	Support.cleanup_audio()
	Support.cleanup_stores(stores)
	await process_frame
	print("SHENQI_HUANG_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
