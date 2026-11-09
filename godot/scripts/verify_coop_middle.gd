extends "res://scripts/verify_insight.gd"

const MIDDLE_FOE := ["bingyong", "shuweng", "haifangzhu", "yaodaoji"]
const MIDDLE_PAIRS := {
	"c116123": ["yijin-zhentian", "zhen"],
	"c118128": ["yimulian", "yaoginshi"],
	"c124129": ["fenghuanghuo", "qingxingdeng"],
	"c127130": ["shantu", "zuofutongzi"],
	"c164166": ["yanyanluo", "rihefang"],
	"c170226": ["biyehua", "huangkulou"],
}

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("COOP_MIDDLE_FAIL ", detail)


func fixture(team: Array) -> GS:
	var gs := GS.create(team, MIDDLE_FOE, 116123)
	prepare(gs)
	for p in gs.players:
		for u in p.units: u.front = 0
	return gs


func cast_face(gs: GS, root: String, unit: String, target = null) -> void:
	var index := give(gs, root)
	check(gs.play_card(0, index, target, root + ":" + unit), root + ":" + unit + " plays by actual hand index")
	for i in 12:
		if gs.pending_choice.is_empty(): break
		check(AI.take_action(gs, gs.action_player()), "AI resolves generated choice")


func named_cards(gs: GS, kind: String, name: String) -> Array:
	return gs.rule_events.filter(func(event): return event.kind == kind and event.get("card", {}).get("name") == name)


func modes_and_ai() -> void:
	for id in MIDDLE_PAIRS:
		var pair: Array = MIDDLE_PAIRS[id]
		for i in 2:
			var gs := fixture(pair + ["shantong", "bailang"])
			var p := gs.player(0)
			p.units[1-i].level = 0
			var index := give(gs, id)
			var expected := str(id) + ":" + str(pair[i])
			check(gs.card_play_modes(0, index).size() == 2, str(id) + " exposes both faces")
			var action := AI._best_card(gs, 0)
			check(action.ok and action.get("origin") == expected and gs.can_play_card(0, index, action.target, expected).ok, expected + " legally selected by AI without the underlevel partner")
			var face := gs.playable_card(0, index, expected)
			check(not face.coopBond, expected + " below-level partner cannot activate the bond")


func feathers() -> void:
	var gs := fixture(["yijin-zhentian", "zhen", "shantong", "bailang"])
	var p := gs.player(0)
	var foe := gs.player(1)
	give(gs, "huangjinyu")
	var fire: int = p.energy
	cast_face(gs, "c116123", "yijin-zhentian")
	var enhanced: Dictionary = gs.hand_card_def(0, 0)
	check(p.energy == fire and enhanced.allowKnockedSource and enhanced.effects[0].value == 3, "zero fire enhances current physical feather")
	var later := give(gs, "huangjinyu")
	check(not gs.hand_card_def(0, later).get("allowKnockedSource", false), "later feather is unaffected")
	gs._knockout_unit(p.units[0])
	gs._knockout_unit(p.units[1])
	var first: int = p.units[0].knockout
	var second: int = p.units[1].knockout
	var hp: int = foe.avatarHp
	check(gs.play_card(0, 0), "enhanced feather is usable while source is knocked out")
	check(p.units[0].knockout == first-1 and p.units[1].knockout == second-1 and foe.avatarHp == hp-5, "feather hits for 3 plus existing 2 vulnerability, then accelerates both death timers")

	gs = fixture(["yijin-zhentian", "zhen", "shantong", "bailang"])
	p = gs.player(0)
	foe = gs.player(1)
	foe.avatarArmorBreak = 2
	cast_face(gs, "c116123", "zhen")
	check(foe.avatarArmorBreak == 2 and foe.avatarHp < 30 and p.units[1].shield == 2, "real combat consumes then restores target vulnerability and grants armor")
	check(p.hand.any(func(inst): return inst.definitionId == "huangjinyu"), "living partner countdown reached zero")


func wind_music() -> void:
	var gs := fixture(["yimulian", "yaoginshi", "shantong", "bailang"])
	var p := gs.player(0)
	play(gs, "c11802")
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 2)
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 2)
	gs._resolve_resolution_stack()
	var armor: int = p.avatarArmor
	cast_face(gs, "c118128", "yimulian")
	var repeat := named_cards(gs, "form-trigger", "风符·护").filter(func(event): return event.reason == "风韵雅乐")
	check(repeat.size() == 1 and p.avatarArmor == armor+5 and p.units[0].front == 1, "replay deduplicates prior countdown effect and performs battle")
	check(p.hand.any(func(inst): return Content.card_def(inst.definitionId).get("awakening", false) and Content.card_def(inst.definitionId).unitId == "yaoginshi"), "wind bond generates an actual musician awakening")

	gs = fixture(["yimulian", "yaoginshi", "shantong", "bailang"])
	p = gs.player(0)
	gs._knockout_unit(p.units[2])
	p.units[2].knockout = 4
	cast_face(gs, "c118128", "yaoginshi")
	check(int(p.units[2].knockout) == 4 and int(p.get("coopMiddleMusic", 0)) == 1, "music waits until next own turn")
	check(p.hand.any(func(inst): return Content.card_def(inst.definitionId).get("type") == "form" and Content.card_def(inst.definitionId).unitId == "yimulian"), "music bond generates a real wind form")
	turn(gs, 0)
	check(int(p.units[2].knockout) == 4, "enemy turn cannot consume delayed effect")
	turn(gs, 1)
	check(int(p.units[2].knockout) == 1 and not p.has("coopMiddleMusic"), "natural timer -1 plus delayed -2 applied once")


func phoenix_lamp() -> void:
	var gs := fixture(["fenghuanghuo", "qingxingdeng", "shantong", "bailang"])
	var p := gs.player(0)
	cast_face(gs, "c124129", "fenghuanghuo")
	check(p.hand.any(func(inst): return inst.definitionId == "mingdeng"), "phoenix bond generates lamp")
	play(gs, "c12901")
	play(gs, "c12901")
	var used: Array = gs.rule_events.filter(func(event): return event.kind == "automatic-card" and event.card.unitId == "fenghuanghuo")
	check(used.size() == 1 and int(used[0].card.level) <= 1, "two identical ally spells trigger one real non-awakening spell within the level limit")

	gs = fixture(["fenghuanghuo", "qingxingdeng", "shantong", "bailang"])
	p = gs.player(0)
	gs._knockout_unit(p.units[1])
	cast_face(gs, "c124129", "qingxingdeng")
	check(p.realms.size() == 1 and p.realms[0].hp == 5 and p.units[1].hp == 0, "realm is usable while knocked out and starts at durability 5")
	check(p.hand.any(func(inst): return inst.definitionId == "c12404"), "realm entry bond gives actual 凤火")
	cast_face(gs, "c124129", "qingxingdeng")
	check(p.realms.size() == 1, "unique realm replaces previous physical realm")
	play(gs, "c12401")
	check(p.units[1].hp > 0 and gs.VerifiedRules.CoopMiddle.noncombat_bonus(gs, 0, 0, false) == 1, "completed hand spell revives lamp and marks only its caster")
	check(gs.VerifiedRules.CoopMiddle.noncombat_bonus(gs, 0, 1, false) == 0 and gs.VerifiedRules.CoopMiddle.noncombat_bonus(gs, 0, 0, true) == 0, "bonus excludes other units and combat damage")
	gs._knockout_unit(p.units[1])
	play(gs, "c12401")
	check(p.units[1].hp == 0, "same caster cannot revive lamp twice in one turn")


func fortune() -> void:
	var gs := fixture(["shantu", "zuofutongzi", "shantong", "bailang"])
	var p := gs.player(0)
	var foe := gs.player(1)
	p.fortuneSixes = 3
	p.units[1].formRules = {"alwaysSix": true}
	cast_face(gs, "c127130", "shantu")
	check(foe.units.all(func(u): return int(u.attack) == 0), "successful partner roll sets all enemy attack to zero")
	check(gs.VerifiedRules.CoopMiddle.extra_cost(gs, 1) == 0, "tax waits until the enemy turn")
	turn(gs, 0)
	check(gs.VerifiedRules.CoopMiddle.extra_cost(gs, 1) == 1 and foe.units.all(func(u): return int(u.attack) == 0), "enemy turn applies both tax and zero attack")
	check(int(gs.card_payment(1, Content.card_def("c10301")).cost) == 2, "actual enemy card quote charges one extra fire")
	turn(gs, 1)
	check(gs.VerifiedRules.CoopMiddle.extra_cost(gs, 1) == 0 and int(foe.units[0].attack) > 0, "ending enemy turn clears both statuses")

	gs = fixture(["shantu", "zuofutongzi", "shantong", "bailang"])
	p = gs.player(0)
	p.units[1].formRules = {"alwaysSix": true}
	gs._knockout_unit(p.units[0])
	gs._knockout_unit(p.units[2])
	cast_face(gs, "c127130", "zuofutongzi")
	check(p.units[0].hp > 0 and p.units[2].hp > 0, "successful roll revives allies before assigning their forms")
	check(p.units[1].form.get("cardId", "").begins_with("c130") and p.units[2].form.get("cardId", "").begins_with("c113"), "different living allies use their own real forms")


func sunny_smoke() -> void:
	var gs := fixture(["yanyanluo", "rihefang", "shantong", "bailang"])
	var p := gs.player(0)
	var foe := gs.player(1)
	var smoke: Dictionary = p.units[0]
	smoke.charge = 1
	var card := gs.VerifiedRules.Cooperation.face(gs, 0, Content.card_def("c164166"), "c164166:rihefang")
	var targets := gs.valid_targets(0, card)
	check(smoke.uid in targets and p.units[1].uid not in targets and foe.units[0].uid not in targets, "sun doll target is other friendly shikigami")
	cast_face(gs, "c164166", "rihefang", smoke.uid)
	cast_face(gs, "c164166", "rihefang", smoke.uid)
	var old_hp: int = smoke.hp
	gs._damage_unit(0, 0, 2, 1, 0, true)
	check(smoke.hp == old_hp, "sunny bond prevents real combat damage")
	play(gs, "c16405")
	check(smoke.charge == 6, "doll grants 2 only once despite two attachments")
	play(gs, "c16405")
	check(smoke.charge == 9, "second spell same turn does not trigger doll")

	gs = fixture(["yanyanluo", "rihefang", "shantong", "bailang"])
	p = gs.player(0)
	foe = gs.player(1)
	p.units[0].charge = 8
	foe.units[2].front = 1
	foe.units[2].hp = 24
	cast_face(gs, "c164166", "yanyanluo")
	var clone: Dictionary = p.units.back()
	check(clone.get("smokeClone", false) and clone.front == 1 and foe.units[2].hp == 16, "level-three clone independently casts its 4+4 projectile")
	check(clone.charge == 1 and p.units[0].charge == 9 and p.units[1].charge == 1 and p.units[2].charge == 0, "native burst spends clone energy only, then bond charges appropriate units")


func bone() -> void:
	var gs := fixture(["biyehua", "huangkulou", "shantong", "yanyanluo"])
	var p := gs.player(0)
	var foe := gs.player(1)
	p.deck = [Insight.instance(gs, 0, "c17007"), Insight.instance(gs, 0, "c16403")]
	var hp: int = p.avatarHp
	var enemy_hp: int = foe.avatarHp
	cast_face(gs, "c170226", "biyehua", p.units[2].uid)
	check(p.avatarHp == hp-4 and foe.avatarHp <= enemy_hp-4 and p.deck.size() == 6, "yellow damages both players and shuffles four actual cards")
	var added: Array = p.deck.filter(func(inst): return Content.card_def(inst.definitionId).get("level") == 1)
	check(added.size() == 4 and added.all(func(inst): return Content.card_def(inst.definitionId).unitId == "shantong"), "generated cards match selected base shikigami and level")
	enemy_hp = foe.avatarHp
	cast_face(gs, "c170226", "huangkulou")
	check(p.units[1].hp == 0 and p.units[1].knockout == 1 and foe.avatarHp == enemy_hp-3, "bone self-destroys, damages opposing characters, and sets countdown")
	check(p.hand.any(func(inst): return inst.definitionId == "c17007"), "bone bond adds actual 彼岸归航")
	check(p.deck.slice(2).all(func(inst): return Content.card_def(inst.definitionId).get("level") == 1), "yellow bond rearranges level-one cards on real bone knockout")


func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = viewport
		DisplayServer.window_set_size(viewport)
		var b := Battle.new()
		b.setup(["yanyanluo", "rihefang", "shantong", "bailang"], MIDDLE_FOE, 164166)
		b._ai_thinking = true
		root.add_child(b)
		await process_frame
		var gs := b.gs
		prepare(gs)
		hand(b, ["c164166"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		var sunny: Control
		if is_instance_valid(b._origin_choice_layer):
			for option in faces(b._origin_choice_layer):
				if option.get_meta("origin_option", "") == "c164166:rihefang": sunny = option
		check(sunny != null and sunny.data.name == "煦日", "hand click opens named Sun form")
		if sunny != null:
			await click(sunny)
			var p := gs.player(0)
			await click(b._unit_widget(str(p.units[1].uid)))
			check(p.hand.size() == 1 and b._pending_target_card == 0, "mouse rejects caster as sunny target")
			await click(b._unit_widget(str(p.units[0].uid)))
			await settled(b)
			var marks := BattleStatus.unit_marks(BattleStatus.unit_view(gs, 0, 0, 0), gs.turn_counter)
			check(p.hand.is_empty() and marks.any(func(mark): return mark.id == "coop-sunny-doll") and marks.any(func(mark): return mark.id == "coop-sunny-immunity"), "mouse attachment shows real doll and immunity")
		b.queue_free()
		await process_frame


func run() -> void:
	var stores := Support.isolate_stores()
	modes_and_ai()
	feathers()
	wind_music()
	phoenix_lamp()
	fortune()
	sunny_smoke()
	bone()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("COOP_MIDDLE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
