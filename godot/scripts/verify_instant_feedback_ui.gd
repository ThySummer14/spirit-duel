extends "res://scripts/verify_book_jue_ui.gd"
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const Content := preload("res://scripts/content_loader.gd")

func feedback(b) -> Array:
	return b._effects.get_children().filter(func(n): return n.get_meta("instant_feedback", false))

func prepare(b, ids: Array = []) -> void:
	b.setup(["yaodaoji", "yingcao", "taohuayao", "tiaotiaomeimei"], ["qingfangzhu", "yingcao", "bingyong", "taohuayao"], 10816)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear()
		p.energy = 4
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	hand(b, ids)
	await settled(b)

func tick() -> void:
	await process_frame
	await process_frame

func wait_feedback(b) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while feedback(b).is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	# Synthetic keyword fixture isolates the existing extra-cost contract. It
	# does not claim that the printed Sister card itself has instant.
	var fixture := Content.card_def("c14601").duplicate(true)
	fixture.id = "verify-instant-extra-cost"
	fixture.keywords.append("instant")
	Content.load_content().cards_by_id[fixture.id] = fixture
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(["yaodaoji"], ["qingfangzhu"], 10816)
		b._ai_thinking = true
		root.add_child(b)
		await prepare(b, ["c10702", "c10703"])
		var p: Dictionary = b.gs.player(0)
		p.energy = 0
		b._refresh()
		await tick()
		check(feedback(b).is_empty(), "mount and payment queries produce no feedback")
		await click(b._hand_row.get_child(0))
		await tick()
		check(p.keywordUsage.instant.used and p.energy == 0, "mouse play pays instant with zero fire")
		check(feedback(b).size() == 1 and feedback(b)[0].cost == 0, "one local cue reports actual zero payment")
		check("本次 0 鬼火" in texts(feedback(b)[0]), "visible cue states actual cost")
		check(b._instant_l.text == "瞬发 · 已用" and b._enemy_instant_l.text == "瞬发 · 可用", "owner and opponent allowances remain independent")
		var command: Dictionary = b.gs.command_log.back()
		var stamp := JSON.stringify(command)
		var played := Cues.played_card(command.a)
		check(played.payment.applied and "瞬发发动" in Status.payment_text(played), "played view describes completed payment")
		check(JSON.stringify(command) == stamp and not command.a.payment.has("applied"), "presentation marker never mutates stored command")
		b._refresh()
		b._refresh()
		await tick()
		check(feedback(b).size() == 1, "repeated refresh does not duplicate active cue")
		check(b._hand_row.get_child(0).data.payment.cost == 1 and not b._hand_row.get_child(0).data.payment.usesInstant, "remaining hand drops instant discount immediately")
		await create_timer(0.10).timeout
		await capture("%d-01-instant-payment" % physical.x)
		await settled(b)
		check(feedback(b).is_empty(), "cue releases itself after presentation")
		p.energy = 1
		b._refresh()
		await click(b._hand_row.get_child(0))
		await tick()
		check(p.energy == 0 and feedback(b).is_empty(), "second instant pays fire without a second allowance cue")
		await settled(b)
		b._refresh()
		await tick()
		check(feedback(b).is_empty(), "later layout refresh never replays consumed payment")
		await prepare(b, ["c10802"])
		p = b.gs.player(0)
		p.energy = 0
		b._refresh()
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and feedback(b).is_empty() and not p.keywordUsage.instant.used, "target selection is not payment")
		await click(b._unit_widget(str(b.gs.player(1).units[0].uid)))
		check(b._pending_target_card == 0 and feedback(b).is_empty() and not p.keywordUsage.instant.used, "invalid enemy target does not consume or animate")
		escape()
		check(b._pending_target_card == -1 and feedback(b).is_empty(), "cancel leaves no consumption feedback")
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(p.units[2].uid)))
		await tick()
		check(feedback(b).size() == 1 and p.keywordUsage.instant.used, "legal target click alone triggers payment feedback")
		await settled(b)
		await prepare(b, ["c10104", "c10104"])
		p = b.gs.player(0)
		p.energy = 0
		b._refresh()
		await click(b._hand_row.get_child(0))
		await tick()
		check(feedback(b).is_empty() and not p.keywordUsage.instant.used, "ordinary natural zero card has no instant cue")
		await settled(b)
		check(b._hand_row.get_child(0).data.payment.usesInstant, "actual avatar hit grants dynamic instant to second zero card")
		await click(b._hand_row.get_child(0))
		await tick()
		check(feedback(b).size() == 1 and p.keywordUsage.instant.used, "natural zero with actual instant consumes and animates once")
		await settled(b)
		await prepare(b, [fixture.id])
		p = b.gs.player(0)
		p.energy = 1
		b._refresh()
		var view: Dictionary = b._hand_row.get_child(0).data
		check(view.payment.usesInstant and view.payment.cost == 1 and "本次 1 鬼火" in Status.payment_text(view), "extra cost remains visible before instant use")
		await click(b._hand_row.get_child(0))
		await tick()
		check(feedback(b).size() == 1 and feedback(b)[0].cost == 1 and p.energy == 0, "cue reports actual extra fire payment")
		await create_timer(0.10).timeout
		await capture("%d-02-instant-extra-cost" % physical.x)
		await settled(b)
		await prepare(b)
		var enemy: Dictionary = b.gs.player(1)
		enemy.avatarHp = 1
		enemy.energy = 0
		hand(b, ["c12507"], 1)
		var before: Dictionary = b.gs.snapshot().duplicate(true)
		await click(b._unit_widget(str(b.gs.player(0).units[0].uid)))
		await click(b._enemy_target_btn)
		await tick()
		check(enemy.keywordUsage.instant.used and enemy.energy == 0 and enemy.units[0].hp == 0, "real lethal attack automatically pays instant and sacrifices monk")
		await wait_feedback(b)
		check(feedback(b).size() == 1 and int(feedback(b)[0].get_meta("player")) == 1, "automatic response animates opponent allowance")
		await tick()
		check(not feedback(b)[0]._caption.get_global_rect().intersects(b._unit_widget(str(enemy.units[0].uid)).get_global_rect()), "opponent payment caption leaves source card unobscured")
		check(b._enemy_instant_l.text == "瞬发 · 已用" and b._instant_l.text == "瞬发 · 可用", "opponent consumption does not dim local allowance")
		var after: Dictionary = b.gs.snapshot().duplicate(true)
		stamp = JSON.stringify(after)
		var response := Cues.timeline(before, after, b.gs.command_log.slice(int(before.commands))).filter(func(c): return c.c == "response_card")
		check(response.size() == 1 and response[0].a.card.payment.applied and response[0].a.card.payment.usesInstant, "automatic response keeps actual payment snapshot")
		check(JSON.stringify(after) == stamp and b.gs.rule_events.filter(func(e): return e.kind == "response-card").all(func(e): return not e.payment.has("applied")), "response presentation leaves rule events unchanged")
		await create_timer(0.10).timeout
		await capture("%d-03-opponent-instant-response" % physical.x)
		await settled(b)
		b.gs.end_turn(0)
		await settled(b)
		check(b._instant_l.text == "瞬发 · 可用" and b._enemy_instant_l.text == "瞬发 · 可用" and feedback(b).is_empty(), "enemy turn resets both allowances without consumption cue")
		# Reset while a cue is live must discard old effects and pending timers.
		await prepare(b, ["c10702"])
		await click(b._hand_row.get_child(0))
		await tick()
		check(feedback(b).size() == 1, "reset fixture starts with live cue")
		await prepare(b)
		check(feedback(b).is_empty() and b._instant_l.text == "瞬发 · 可用", "new match clears old cue and allowance")
		b.queue_free()
		await tick()
	Content.load_content().cards_by_id.erase(fixture.id)
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await tick()
	print("INSTANT_FEEDBACK_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
