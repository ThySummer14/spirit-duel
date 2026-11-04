extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Wind := preload("res://scripts/wind_rules.gd")
const Night := preload("res://scripts/night_realm_rules.gd")
const Divination := preload("res://scripts/native_divination_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WIND_NIGHT_MASK_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(["shanfeng", "longyechaji", "banruo", "yaoginshi"], ["bingyong", "longyechaji", "datiangou", "yingcao"], 175177215)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "wind-night-mask-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "actual play " + id)

func finish(gs) -> void:
	for i in 80:
		if gs.pending_choice.is_empty() and gs.response_window.is_empty(): return
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs, gs.action_player()), "AI resolves pending choice")
		else: gs.pass_response(gs.action_player())
	check(false, "choice continuation finishes")

func wind_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var wind: Dictionary = p.units[0]
	check(wind.abilityCountdown.remaining == 2 and wind.attack == 3, "initial active wind countdown3 ticks naturally")
	wind.abilityCountdown.remaining = 1
	gs.player(1).units[0].front = 1; gs.player(1).units[0].attack = 20
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 1); gs._resolve_resolution_stack()
	check(wind.hp == 1 and wind.abilityCountdown.remaining == 3 and not p.attackUsed, "timer launches real attack with one-combat unyielding")
	check(not wind.get("combatUnyielding", false), "timer unyielding expires after combat")
	gs = game(); p = gs.player(0); wind = p.units[0]
	play(gs, "c17501"); wind.abilityCountdown.remaining = 1
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 1); gs._resolve_resolution_stack()
	check(wind.attack == 4 and wind.maxHp == 5, "fierce form grows permanent1/1 on actual timer trigger")
	gs._knockout_unit(wind)
	check(wind.attack == 4 and wind.maxHp == 5, "fierce permanent growth survives knockout")
	gs = game(); p = gs.player(0); wind = p.units[0]
	play(gs, "c17503"); wind.abilityCountdown.remaining = 3
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 2)
	check(wind.attack == 5 and wind.windStoredPower == 2, "momentum stores actual reduction without attacking")
	check(gs.basic_attack(0, 0) and wind.attack == 3 and not wind.has("windStoredPower"), "next attack consumes stored power after completion")
	gs = game(); p = gs.player(0); wind = p.units[0]; play(gs, "c17504")
	check(wind.shield == 0 and wind.maxHp == 8, "hard form does not invent immediate armor")
	wind.abilityCountdown.remaining = 1; gs.VerifiedRules.reduce_countdown(gs, 0, 0, 1); gs._resolve_resolution_stack()
	check(wind.shield == 4, "hard grants4 armor on actual timer trigger")
	gs = game(); p = gs.player(0); wind = p.units[0]; play(gs, "c17505")
	gs.player(1).units[0].front = 1; gs.player(1).units[0].hp = 20; gs.player(1).units[0].maxHp = 20
	wind.abilityCountdown.remaining = 1; gs.VerifiedRules.reduce_countdown(gs, 0, 0, 1); gs._resolve_resolution_stack()
	check(gs.player(1).units[0].hp == 0, "slash timer gains lethal instead of combo")
	gs = game(); p = gs.player(0); wind = p.units[0]; wind.abilityCountdown.remaining = 3
	play(gs, "c17502")
	check(wind.abilityCountdown.remaining == 1 and gs.player(1).avatarHp == 30, "manual quick is one reduction2")
	gs = game(); p = gs.player(0); wind = p.units[0]; wind.front = 1; wind.abilityCountdown.remaining = 1
	give(gs, "c17502"); gs.current_player = 1
	check(gs.basic_attack(1, 0), "enemy attack triggers quick response")
	check(p.hand.is_empty() and wind.abilityCountdown.remaining == 1 and gs.rule_events.any(func(e): return e.kind == "response-card" and e.card.id == "c17502"), "quick response repeats reduction as separate events and resolves intervening attack")
	gs = game(); p = gs.player(0); wind = p.units[0]; wind.abilityCountdown.remaining = 1
	play(gs, "c17506")
	check(wind.attack == 5 and wind.shield == 2 and wind.maxHp == 4, "burst counts living other timer and converts overflow2 to power/armor only")
	gs._knockout_unit(wind); check(wind.attack == 3, "burst ordinary power clears on knockout")
	gs = game(); p = gs.player(0); wind = p.units[0]; play(gs, "c17508")
	wind.abilityCountdown.remaining = 1; gs.player(1).units[0].front = 1; gs.player(1).units[0].attack = 30
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 1); gs._resolve_resolution_stack()
	check(wind.hp == wind.maxHp, "awakened timer attack is immune instead of unyielding")
	gs = game(); p = gs.player(0); wind = p.units[0]; play(gs, "c17508")
	wind.abilityCountdown.remaining = 3; p.units[3].abilityCountdown.remaining = 3
	play(gs, "c12804", p.units[3].uid); finish(gs)
	check(wind.abilityCountdown.remaining == 1, "own card reduction on another living timer mirrors to awakened wind")
	gs._knockout_unit(wind); wind.knockout = 2; p.units[3].abilityCountdown.remaining = 3
	play(gs, "c12804", p.units[3].uid); finish(gs)
	check(wind.hp == wind.maxHp and wind.knockout == 0, "mirrored card reduction revives knocked awakened wind")
	gs = game(); p = gs.player(0); wind = p.units[0]; play(gs, "c17508"); wind.abilityCountdown.remaining = 3
	gs.VerifiedRules.reduce_countdown(gs, 0, 3, 1); gs._resolve_resolution_stack()
	check(wind.abilityCountdown.remaining == 3, "natural/ability reductions do not falsely mirror card effect")
	gs = game(); p = gs.player(0); wind = p.units[0]; wind.abilityCountdown.remaining = 3; p.units[3].abilityCountdown.remaining = 2
	var total := Wind.total_timers(gs, 0); play(gs, "c17507")
	check(total == 5 and wind.abilityCountdown.remaining == 3 and gs.rule_events.filter(func(e): return e.kind == "ability-trigger" and e.uid == wind.uid).size() == 2, "storm snapshots total and resolves every single reduction with intervening attacks")

func night_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var night: Dictionary = p.units[1]
	var h := give(gs, "c17701")
	check(not gs._kw(gs.hand_card_def(0, h), "instant") and night.attack == 3, "no realm means no instant or passive power")
	play(gs, "c17703")
	check(night.attack == 4 and gs._kw(gs.hand_card_def(0, h), "instant"), "real realm immediately grants power and instant")
	check(gs._damage_unit(0, 1, 9, 1, 2).damage == 0 and night.hp == 4 and p.realms.is_empty() and night.attack == 3, "moon bears full spell packet and breaks without overflow to unit")
	play(gs, "c17704")
	check(gs._damage_unit(0, 1, 2, 1, 2).damage == 2 and p.realms.size() == 1, "sun does not absorb noncombat damage")
	check(gs._damage_unit(0, 1, 10, 1, 0, true).damage == 0 and p.realms.is_empty(), "sun absorbs combat damage only")
	gs = game(); p = gs.player(0); night = p.units[1]
	play(gs, "c177081")
	check(night.maxHp == 7 and night.attack == 4 and p.realms.size() == 2 and p.realms.all(func(r): return r.hp == 1), "cycle sets3/7 and summons both actual realms")
	gs.current_player = 1; gs.player(1).hand.clear()
	p.realms[0].hp = 10
	var hp_before: Array = p.units.map(func(u): return int(u.hp))
	check(gs.play_card(1, give(gs, "c10506", 1)), "real enemy area spell")
	check(p.units.map(func(u): return int(u.hp)) == hp_before and p.realms.size() == 2 and p.realms[0].hp == 7, "cycle absorbs simultaneous area group for whole team and avatar only costs3 durability once")
	gs = game(); p = gs.player(0); night = p.units[1]
	play(gs, "c17703"); play(gs, "c17704"); play(gs, "c17705")
	check(night.attack == 5 and night.maxHp == 5 and Night.first_strike(gs, night) and not gs.VerifiedRules.Combat.has(night, "first-strike"), "awakened power counts each realm and first strike is attacker-only")
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "检查销毁")
	check(night.attack == 4, "realm destruction immediately removes derived power")
	gs = game(); p = gs.player(0); night = p.units[1]
	play(gs, "c17702")
	check(gs.pending_choice.get("type") == "night-summon" and gs.player(1).avatarHp == 30, "sunset waits for actual realm choice before attack")
	check(not gs.resolve_divination_choice(1, "c17703") and not gs.resolve_divination_choice(0, "c17706"), "realm choice rejects wrong player and illegal selection")
	check(gs.resolve_divination_choice(0, "c17704") and p.realms.size() == 1 and p.realms[0].hp == 4 and gs.player(1).avatarHp == 25, "selected realm installed then real+1 attack grows owned realm3")
	gs = game(); p = gs.player(0)
	gs._deploy_realm(1, Content.card_def("c17703")); gs._deploy_realm(1, Content.card_def("c17704")); gs.player(1).realms[0].hp = 9; gs.player(1).realms[1].hp = 6
	play(gs, "c17706")
	check(gs.player(1).realms.size() == 1 and gs.player(1).realms[0].nativeRealm == "night-moon", "secret destroys highest durability enemy realm after actual avatar combat damage")
	gs = game(); p = gs.player(0); night = p.units[1]
	play(gs, "c17703"); play(gs, "c17704")
	play(gs, "c17707")
	check(p.realms.is_empty() and gs.player(1).avatarHp == 19, "moonless repeats once for each destroyed realm with live derived power4+4+3")
	check(gs.rule_events.filter(func(e): return e.kind == "realm-destroyed").size() == 2, "repeat destroys two actual realm instances")
	check(p.cardsPlayedThisTurn == 5, "repeated moonless uses count as real cards without additional fire payment")
	gs = game(); p = gs.player(0); play(gs, "c17704")
	gs.player(1).units[0].keywords = ["pierce"]; p.units[1].front = 1
	gs._resolve_combat(1, 0, 7, true, false, false, false)
	check(p.units[1].hp == 4 and p.avatarHp < 30, "realm prevents unit damage but independent pierce overflow still hits avatar")

func mask_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var mask: Dictionary = p.units[2]
	gs.player(1).units[0].front = 1; gs.player(1).units[0].attack = 20
	p.deck.append({"instanceId":"top-ghost", "definitionId":"c21501"}); p.energy = 0
	gs._resolve_combat(0, 2, 0, false, false, false, false); gs._resolve_resolution_stack()
	check(mask.hp == 4 and gs.player(1).units[0].hp == 2 and p.energy == 0 and not p.deck.any(func(i): return i.instanceId == "top-ghost"), "top ghost adds1 to current attack, grants true immunity and is consumed without fire")
	gs = game(); p = gs.player(0); mask = p.units[2]; mask.front = 1; p.energy = 0
	gs.current_player = 1
	p.deck.append({"instanceId":"defend-ghost", "definitionId":"c21501"})
	gs.basic_attack(1, 0)
	check(mask.hp == 4 and gs.player(1).units[0].hp == 2 and p.energy == 0, "defensive top ghost strengthens existing counterattack rather than launching another attack")
	gs = game(); p = gs.player(0); mask = p.units[2]
	p.deck = [{"instanceId":"trick-one", "definitionId":"c21505"},{"instanceId":"trick-two", "definitionId":"c21505"}]
	gs.basic_attack(0, 2); finish(gs)
	check(gs.player(1).avatarHp == 21 and p.deck.is_empty() and p.energy == 29, "two real top tricks extend attack chain without fire or fake bonus power")
	check(gs.rule_events.filter(func(e): return e.kind == "automatic-card" and e.card.id == "c21505").size() == 2, "both original trick instances actually used")
	gs = game(); p = gs.player(0); mask = p.units[2]; p.deck = [{"instanceId":"draw-ghost", "definitionId":"c21501"}]
	play(gs, "c21502")
	check(gs.pending_choice.get("type") == "mask-hand-top" and p.hand[0].instanceId == "draw-ghost" and gs.player(1).avatarHp == 30, "swap draws true card and pauses before battle for hand choice")
	check(not gs.resolve_divination_choice(0, "not-held"), "swap rejects invalid hand instance")
	check(gs.resolve_divination_choice(0, "draw-ghost"), "chosen original instance goes to top")
	finish(gs)
	check(gs.player(1).avatarHp == 25 and p.hand.is_empty() and p.deck.is_empty(), "placed ghost triggers before swap attack and adds exactly1 to its printed1")
	gs = game(); p = gs.player(0)
	var h := give(gs, "c21503"); check(not gs._kw(gs.hand_card_def(0, h), "instant"), "resent without divination is not instant")
	gs.VerifiedRules.Divination.start(gs, 0, 1); finish(gs)
	check(gs._kw(gs.hand_card_def(0, h), "instant"), "completed real divination enables instant")
	gs = game(); p = gs.player(0); mask = p.units[2]; p.deck = [{"instanceId":"safe-bottom", "definitionId":"c17501"}]
	var hate := give(gs, "c21504"); var iid := str(p.hand[hate].instanceId)
	check(gs.play_card(0, hate), "hatred attack"); finish(gs)
	check(mask.attack == 3 and p.maskHatredGrowth == 2 and p.deck.any(func(i): return i.instanceId == iid), "hatred returns original to deck and strengthens same-name cards rather than shikigami")
	check(gs.hand_card_def(0, give(gs, "c21504")).value == 4, "new same-name copy inherits match-wide hatred growth")
	gs = game(); p = gs.player(0); p.deck.clear()
	play(gs, "c21506"); finish(gs)
	check(gs.player(1).avatarHp == 10 and p.deck.is_empty() and p.energy == 29, "five tricks are real shuffled cards used as five later attacks")
	gs = game(); p = gs.player(0); mask = p.units[2]
	play(gs, "c21507"); gs.player(1).avatarArmor = 2
	check(gs.basic_attack(0, 2), "critical form real attack"); finish(gs)
	check(gs.player(1).avatarHp == 28 and mask.attack == 3, "critical doubles damage after2 armor, not attack before armor")
	gs = game(); p = gs.player(0); mask = p.units[2]; play(gs, "c21507")
	gs.player(1).units[0].front = 1; gs.player(1).units[0].shield = 2; gs.player(1).units[0].formRules = {"damageCap": 1}
	gs.basic_attack(0, 2); finish(gs)
	check(gs.player(1).units[0].hp == 5, "critical resolves after armor and before final damage cap")
	gs = game(); p = gs.player(0); mask = p.units[2]; play(gs, "c21508")
	check(mask.swift and mask.attack == 4 and mask.maxHp == 5, "awakening gives actual1/1 and swift without immediate fake divination")
	p.energy = 0; check(gs.basic_attack(0, 2), "awakened swift allows zero-fire basic attack"); finish(gs)
	check(not mask.swift, "basic attack consumes swift")
	gs._knockout_unit(mask); mask.knockout = 1
	gs.VerifiedRules.reduce_countdown(gs, 0, 2, 1)
	check(mask.hp == mask.maxHp and mask.swift, "awakening swift returns on actual revival")
	for id in ["c17506", "c17702", "c21502"]:
		gs = game(); give(gs, id)
		var chosen: Dictionary = AI._best_card(gs, 0)
		check(chosen.ok and gs.can_play_card(0, chosen.hand, chosen.target).ok and gs.play_card(0, chosen.hand, chosen.target), "AI chooses and legally uses " + id)
		finish(gs)

func original_card_faces() -> void:
	var gallery := HBoxContainer.new()
	gallery.position = Vector2(120, 165)
	gallery.add_theme_constant_override("separation", 35)
	root.add_child(gallery)
	var samples: Array = []
	for id in ["c21501", "c17703", "c17502", "c17501", "c21504", "c21307"]:
		var sample := preload("res://scripts/ui/card_face.gd").new()
		sample.data = Content.card_def(id).duplicate(true)
		if id == "c21504": sample.data.value = 6
		sample.custom_minimum_size = Vector2(180, 320)
		gallery.add_child(sample)
		samples.append(sample)
	await process_frame
	check(samples.all(func(f): return f._original_card != null), "battle, realm, spell and form cards load actual original full faces")
	check(samples.all(func(f): return is_equal_approx(f.original_card_rect().size.aspect(), f._original_card.get_size().aspect())), "original silhouettes retain source aspect without cropping")
	check(samples[4].original_stat_changes() == "当前力量 +6", "enhanced same-name card exposes live power over original face")
	var tooltip := preload("res://scripts/ui/ui_widgets.gd").make_tooltip(samples[4].data)
	check(texts(tooltip).contains("当前效果：") and texts(tooltip).contains(str(samples[4].data.text)), "inspector retains full live rule text beside printed face")
	tooltip.free()
	await capture("00-original-card-types")
	gallery.queue_free()
	await process_frame

func run() -> void:
	wind_rules(); night_rules(); mask_rules()
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme(); root.size = Vector2i(1600, 740)
	await original_card_faces()
	var b := Battle.new()
	b.setup(["shanfeng", "longyechaji", "banruo", "yaoginshi"], ["bingyong", "longyechaji", "fenghuanghuo", "yingcao"], 175177215)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
	root.add_child(b); await create_timer(0.5).timeout
	hand(b, ["c17702"]); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	check(b.gs.pending_choice.get("type") == "night-summon" and choice_face(b, "c17703") != null and choice_face(b, "c17704") != null, "mouse presents both real realm choices")
	await capture("01-night-realm-choice")
	var face := choice_face(b, "c17704")
	if face != null: await click(face)
	await settled(b)
	check(b.gs.pending_choice.is_empty() and b.gs.player(0).realms.size() == 1 and b.gs.player(0).realms[0].hp == 4, "mouse realm choice resumes actual attack and durability growth")
	check(b.gs.VerifiedRules.Night.power(b.gs, b.gs.player(0).units[1]) == 1 and preload("res://scripts/ui/battle_status.gd").unit_view(b.gs, 0, 1, 0).nightRealmPower == 1, "derived realm power agrees in rules and read-only status view")
	b.gs.player(0).deck = [{"instanceId":"ui-ghost","definitionId":"c21501"}]
	hand(b, ["c21502"]); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	check(b.gs.pending_choice.get("type") == "mask-hand-top" and choice_face(b, "c21501") != null, "mouse swap shows actual held instance for topdeck placement")
	await capture("02-mask-hand-to-top")
	face = choice_face(b, "c21501")
	if face != null: await click(face)
	await settled(b)
	check(b.gs.player(0).hand.is_empty() and b.gs.player(0).deck.is_empty() and b.gs.pending_choice.is_empty(), "mouse placed ghost is automatically used in resumed combat")
	hand(b, ["c17503", "c17502"]); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	b.gs.player(0).units[0].abilityCountdown.remaining = 3
	await click(b._hand_row.get_child(0)); await settled(b)
	check(b.gs.player(0).units[0].abilityCountdown.remaining == 1 and b.gs.player(0).units[0].windStoredPower == 2, "mouse quick updates actual countdown and stored momentum")
	await capture("03-wind-countdown-momentum")
	b.queue_free(); Support.cleanup_audio(); await process_frame; Support.cleanup_stores(stores)
	print("WIND_NIGHT_MASK checks=%d failures=%d" % [checks, failures]); quit(0 if failures == 0 else 1)
