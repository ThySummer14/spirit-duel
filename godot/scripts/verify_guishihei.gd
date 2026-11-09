extends "res://scripts/verify_langyazi.gd"

const GH := preload("res://scripts/guishihei_rules.gd")
const GHOST_ALLY := ["guishihei", "bailang", "shantong", "yaohu"]
const GHOST_ENEMY := ["bingyong", "xuenv", "hetong", "yaodaoji"]

func game() -> GS:
	var gs := GS.create(GHOST_ALLY, GHOST_ENEMY, 628)
	prepare(gs)
	return gs

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GUISHIHEI_FAIL ", detail)

func revival_and_forms() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = p.units[0]
	var green: Dictionary = p.units[1]
	green.factionPermanent = "苍叶"
	p.units[2].factionPermanent = "紫岩"
	gs._knockout_unit(u)
	gs._knockout_unit(green)
	gs._knockout_unit(p.units[2])
	play(gs, "c62801")
	check(u.hp == 4 and green.hp == green.maxHp and p.units[2].hp == 0, "返魄回体 revives self and only knocked-out 苍叶 teammate")
	check(gs.front_index(0) < 0 and foe.avatarHp == 30, "返魄回体 is a spell with no invented attack")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	u = p.units[0]
	var marked: Dictionary = foe.units[1]
	foe.units[0].front = 1
	marked.attack = 12
	play(gs, "c62802", marked.uid)
	check(u.hp == 4 and u.attack == 4 and u.front == 0, "少时黑羽 installs printed 4/4 and does not make an immediate attack")
	check(gs.basic_attack_targets(0, 0) == [foe.units[0].uid, marked.uid], "索魂 exposes front and the marked reserve only")
	check(not gs.basic_attack(0, 0, foe.units[2].uid) and not p.attackUsed, "unmarked reserve is rejected before consuming deployment")
	check(gs.basic_attack(0, 0, marked.uid) and u.hp == 4, "marked enemy cannot return battle damage to 少时黑羽")
	gs._knockout_unit(marked)
	check(not GH.marked(marked, 0), "索魂 is removed on knockout")

	for qualifies in [false, true]:
		gs = game()
		p = gs.player(0)
		foe = gs.player(1)
		for enemy in foe.units: enemy.factionPermanent = "红莲"
		if qualifies: foe.units[1].factionPermanent = "青岚"
		play(gs, "c62808")
		u = p.units[0]
		check(u.attack == 6 and u.hp == 8 and gs.VerifiedRules.Combat.has(u, "pierce"), "天下太平 sets printed 6/8 with pierce")
		check(gs.VerifiedRules.Combat.has(u, "veil") == qualifies, "天下太平 enhancement requires a living 青岚 enemy")
		p.energy = 0
		check(gs.basic_attack(0, 0), "天下太平 swift sortie works without fire")

func combat_growth() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = p.units[0]
	var marked: Dictionary = foe.units[1]
	marked.hp = 1
	marked.attack = 0
	play(gs, "c62804", marked.uid)
	var fire: int = p.energy
	check(gs.basic_attack(0, 0, marked.uid), "守夜人 attacks selected marked enemy")
	check(marked.hp == 0 and u.attack == 6 and u.hp == 7 and p.energy == fire and not p.attackUsed, "守夜人 kill grants real fire, resets deployment and triggers base permanent growth")
	marked = foe.units[2]
	marked.hp = 1
	GH.attach(gs, 0, marked)
	play(gs, "c62806", marked.uid)
	check(marked.hp == 0 and u.attack == 7 and u.maxHp == 8 and p.energy == fire - 1, "漆黑长刃 grows +1/+1 on its kill, base and 守夜人 are once per turn")
	gs._knockout_unit(u)
	check(u.attack == 5 and u.maxHp == 5, "both permanent gains survive knockout and loss of form")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	u = p.units[0]
	marked = foe.units[1]
	for round in 4:
		marked.hp = 1
		marked.attack = 0
		marked.knockout = 0
		GH.attach(gs, 0, marked)
		check(gs.basic_attack(0, 0, marked.uid) and marked.hp == 0, "real qualifying kill on own turn")
		check(u.attack == 3 + mini(3, round + 1), "base permanent growth stops after three turns with kills")
		turn(gs, 0)
		turn(gs, 1)

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	u = p.units[0]
	play(gs, "c62803")
	check(p.realms[0].hp == 4 and foe.units.filter(func(x): return GH.marked(x, 0)).size() == 1, "辞母时 enters with printed durability and a real mark")
	var victim: Dictionary = foe.units.filter(func(x): return GH.marked(x, 0))[0]
	victim.hp = 1
	victim.attack = 0
	play(gs, "c62805", victim.uid)
	check(u.awakened and u.attack == 3 and p.realms[1].hp == 6, "觉醒 is an actual realm without invented body growth")
	check(gs.basic_attack_targets(0, 2) == [victim.uid], "觉醒 realm grants targeted sortie to other allies")
	var hp: int = foe.avatarHp
	var ally_power: int = p.units[2].attack
	check(gs.basic_attack(0, 2, victim.uid), "ally attacks marked reserve")
	check(victim.hp == 0 and u.attack == 4 and foe.avatarHp == hp - ally_power, "ally kill grows awakened 鬼使黑 and 辞母时 adds 1 battle power with pierce")
	turn(gs, 0)
	turn(gs, 1)
	check(foe.units.filter(func(x): return GH.marked(x, 0)).size() == 1, "辞母时 applies another real mark on owner's next turn")
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[1], "专项")
	check(gs.basic_attack_targets(0, 2) == ["avatar-1"], "losing awakening realm ends teammates' targeting rule")
	check(gs.basic_attack_targets(0, 0) != ["avatar-1"] and u.awakened, "鬼使黑 retains his mark targeting and the awakening itself")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	play(gs, "c62803")
	var summon: Dictionary = foe.units[1]
	summon.summoned = true
	summon.hp = 20
	summon.attack = 0
	var source: Dictionary = p.units[2]
	gs._resolve_combat(0, 2, 0, false, false, false, false, summon.uid, false, {"pursuit": true})
	gs._resolve_resolution_stack()
	check(summon.hp == 20-source.attack and not gs.rule_events.any(func(e): return e.kind == "battle-power-changed" and e.uid == source.uid), "辞母时 does not grant reserve bonus against a non-shikigami summon")

func trick_and_ai() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	p.units[0].level = 2
	var target: Dictionary = foe.units[1]
	var hp: int = target.hp
	var attack: int = target.attack
	play(gs, "c62807", target.uid)
	check(GH.marked(target, 0) and target.attack == attack and target.hp == hp and foe.units.filter(func(x): return GH.marked(x, 0)).size() == 1, "underlevel 戏法 only marks the selected enemy")
	gs = game()
	foe = gs.player(1)
	play(gs, "c62807")
	check(foe.units.all(func(x): return GH.marked(x, 0) and x.attack == 0), "full spell marks and zeros living enemies")
	turn(gs, 0)
	check(foe.units.all(func(x): return GH.marked(x, 0) and not x.has("ghZeroTurn") and x.attack == x.baseAttack), "temporary zero expires, charm remains")
	for n in range(1, 9):
		gs = game()
		if n == 1: gs._knockout_unit(gs.player(0).units[0])
		var id := "c628%02d" % n
		give(gs, id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI actually plays " + id)
		var texture := load("res://assets/official/cards/%s.png" % id)
		check(texture is Texture2D and texture.get_width() > 200, "original texture loads " + id)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(GHOST_ALLY, GHOST_ENEMY, 628)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		var foe := gs.player(1)
		var ally := gs.player(0)
		var mark: Dictionary = foe.units[1]
		hand(b, ["c62802"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		await click(b._unit_widget(mark.uid))
		await settled(b)
		check(ally.hand.is_empty() and GH.marked(mark, 0), "native selects and marks enemy through 少时黑羽")
		var mark_hp: int = mark.hp
		await click(b._unit_widget(ally.units[0].uid))
		await settled(b)
		check(b._selected_attacker == 0 and gs.basic_attack_targets(0, 0) == [mark.uid], "native sortie highlights the marked reserve")
		await click(b._unit_widget(foe.units[2].uid))
		await settled(b)
		check(not ally.attackUsed and mark.hp == mark_hp, "native rejects an unmarked reserve")
		await click(b._unit_widget(mark.uid))
		await settled(b)
		check(ally.attackUsed and mark.hp < mark_hp, "native sortie hits marked reserve")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	revival_and_forms()
	combat_growth()
	trick_and_ai()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("GUISHIHEI checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
