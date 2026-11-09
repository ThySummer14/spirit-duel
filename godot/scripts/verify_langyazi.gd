extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const LY := preload("res://scripts/langyazi_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const ALLY := ["langyazi", "shifagui", "shantong", "yaohu"]
const ENEMY := ["bingyong", "bailang", "hetong", "yaodaoji"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("LANGYA_FAIL ", detail)

func prepare(gs) -> void:
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3

func game() -> GS:
	var gs := GS.create(ALLY, ENEMY, 608)
	prepare(gs)
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	var cards: Array = gs.player(owner).hand
	cards.append({"definitionId": id, "instanceId": "ly-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return cards.size() - 1

func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "actual play " + id)

func turn(gs, owner: int) -> void:
	check(gs.end_turn(owner), "actual end turn " + str(owner))
	gs.player(1-owner).levelUpUsed = true

func curse(gs, kind: String) -> Dictionary:
	for realm in gs.player(1).realms:
		if realm.get("curseKind", "") == kind: return realm
	return {}

func passive_and_targets() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = p.units[0]
	var target: Dictionary = foe.units[0]
	check(u.attack == 2 and u.maxHp == 5 and not u.awakened, "base 2/5")
	var idx := give(gs, "c61503")
	var attack: int = target.attack
	check(not gs.can_play_card(0, idx, u.uid).ok, "ally cannot be selected by 镇诀")
	target.keywords = ["veil"]
	check(not gs.can_play_card(0, idx, target.uid).ok and foe.realms.is_empty(), "veiled enemy is rejected without curse or payment")
	target.keywords = []
	check(gs.play_card(0, idx, target.uid), "select legal enemy")
	check(foe.realms.map(func(r): return r.curseKind) == ["zhenzhou", "meizhou"], "镇咒 enters in front of passive 寐咒")
	check(target.attack == attack - 2 and target.shield == 0, "signed debuff without invented armor")
	check(not gs.can_play_card(0, give(gs, "c61503"), target.uid).ok, "unique curse blocks replay")
	var next: Dictionary = foe.units[1]
	var health: int = next.hp
	play(gs, "c61504", next.uid)
	check(foe.realms.size() == 3 and health - next.hp == 3, "灭咒 counts installed realms including itself, no second passive")
	gs._knockout_unit(foe.units[2])
	var count: int = foe.units[2].knockout
	gs.VerifiedRules.Huang.destroy(gs, 1, curse(gs, "miezhou"), "专项")
	check(foe.units[2].knockout == count + 1, "灭咒 extends an actually knocked-out target on departure")
	gs.VerifiedRules.Huang.destroy(gs, 1, curse(gs, "zhenzhou"), "专项")
	check(p.realms.size() == 1 and p.realms[0].name == "蜃境", "镇咒 departure creates separate 蜃境")
	check(gs.basic_attack(0, 2) and gs.VerifiedRules.HairPower.guard_count(gs, 0) == 1, "friendly attack grants one real guard")
	p.attackUsed = false
	check(gs.basic_attack(0, 2, p.units[2].uid) and gs.VerifiedRules.HairPower.guard_count(gs, 0) == 0, "guard can be consumed on a real unit")
	check(p.units[2].shield == 1 and gs.VerifiedRules.HairPower.amount(p.units[2]) == 1, "guard grants exact power and armor")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	foe.units[0].front = 1
	foe.units[0].attack = 20
	check(gs.basic_attack(0, 0), "琅琊子 makes an ordinary attack")
	check(p.units[0].hp == 0 and LY.has_curse(gs, 1, "meizhou"), "寐咒 was created before fatal counterattack")

	gs = game()
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	foe = gs.player(1)
	play(gs, "c61503", foe.units[0].uid)
	check(LY.has_curse(gs, 1, "meizhou") and not LY.has_curse(gs, 1, "zhenzhou"), "nullified card still counts as a use while its own effect is stopped")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	play(gs, "c61506")
	u = p.units[0]
	check(u.awakened and u.attack == 3 and u.maxHp == 6, "awakened exact +1/+1")
	check(not gs.can_play_card(0, give(gs, "c61506")).ok, "duplicate awakening rejected")
	u.lyPassiveTurn = -1
	LY.summon_curse(gs, 1, "hunzhou", "", 0)
	var total: int = foe.units.reduce(func(sum, unit): return sum + int(unit.hp), 0)
	var damage: int = foe.realms.size() + 1
	play(gs, "c61507")
	check(foe.units.reduce(func(sum, unit): return sum + int(unit.hp), 0) <= total - damage, "awakened use applies actual seeded damage")
	check(p.realms.size() == 1 and foe.realms.all(func(r): return int(r.curseLevel) <= 2), "桃源洞天 installs realm and selects from eligible curses")

func realm_lifecycle() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var target: Dictionary = foe.units[1]
	var card_id: String = Content.cards_for_unit("bailang")[0].id
	give(gs, card_id, 1)
	give(gs, Content.cards_for_unit("bingyong")[0].id, 1)
	var safe: String = foe.hand[1].instanceId
	play(gs, "c61502", target.uid)
	check(target.frozen > 0 and foe.hand.size() == 1 and foe.hand[0].instanceId == safe, "忘咒 only discards a real card owned by the chosen target")
	check(p.hand.is_empty(), "忘咒 does not draw on entry")
	gs.VerifiedRules.Huang.destroy(gs, 1, curse(gs, "wangzhou"), "专项")
	check(p.hand.size() == 1, "忘咒 draws exactly once on departure")

	gs = GS.create(ALLY, ["yijin-zhentian", "zhen", "bingyong", "hetong"], 608)
	prepare(gs)
	foe = gs.player(1)
	var coop := give(gs, "c116123", 1)
	var coop_iid := str(foe.hand[coop].instanceId)
	check("zhen" in Content.card_unit_ids(gs.hand_card_def(1, coop)), "root cooperation card belongs to its second partner before face selection")
	give(gs, Content.cards_for_unit("bingyong")[0].id, 1)
	safe = str(foe.hand[1].instanceId)
	play(gs, "c61502", foe.units[1].uid)
	check(foe.hand.size() == 1 and foe.hand[0].instanceId == safe and gs.rule_events.any(func(e): return e.get("kind") == "card-discarded" and e.get("instanceId") == coop_iid), "忘咒 discards the actual cooperation instance of its second partner")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	check(gs.valid_targets(0, Content.card_def("c61501")).is_empty(), "钱眼 needs an existing enemy realm")
	var original: Dictionary = LY.summon_curse(gs, 1, "meizhou", "", 0)
	p.energy = 0
	play(gs, "c61501", original.uid)
	check(not foe.realms.has(original) and foe.realms.size() == 1, "钱眼 destroys selected instance, even when passive adds same-name curse")
	check(p.hand.size() == 1 and p.attackUsed and p.energy == 0 and gs.instant_available(0), "钱眼 draws and spends deployment rather than instant")
	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	gs._deploy_realm(1, Content.card_def("c60808"))
	foe.units[0].formRules = {"whaleRealmVeil": true}
	check(gs.valid_targets(0, Content.card_def("c61501")).is_empty(), "钱眼 respects realm veil")
	foe.units[0].formRules = {}
	play(gs, "c61501", foe.realms[0].uid)
	check(p.hand.is_empty(), "钱眼 gives no draw for ordinary realm")

	gs = game()
	foe = gs.player(1)
	var behind: Dictionary = LY.summon_curse(gs, 1, "zhenzhou", foe.units[0].uid, 0)
	original = LY.summon_curse(gs, 1, "meizhou", "", 0)
	var sleep_curse := Content.card_def("meizhou")
	check(original.cardId == "meizhou" and sleep_curse.type == "realm" and sleep_curse.realm.hp == original.hp, "寐咒场上实例使用原版幻境牌定义")
	check(not gs.can_play_card(0, give(gs, "meizhou")).ok, "旧寐咒牌 ID 不能绕过原版召唤入口从手牌施放")
	gs.player(0).hand.clear()
	turn(gs, 0)
	check(foe.avatarHp == 29 and not foe.realms.has(original) and behind.hp == 5, "寐咒 deals 1 to owner and removes exactly 2 durability from first realm")
	turn(gs, 1)
	check(foe.avatarHp == 29, "寐咒 only triggers on owning side's turn")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	gs._deploy_realm(0, Content.card_def("c61507"))
	gs._deploy_realm(1, Content.card_def("c60808"))
	p.avatarHp = 17
	foe.realms[0].hp = 1
	gs.VerifiedRules.Huang.destroy(gs, 1, foe.realms[0], "专项")
	check(p.avatarHp == 23, "桃源洞天 heals printed initial durability rather than remaining durability")
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "专项")
	check(p.avatarHp == 23, "own realm departure gives no heal")

func summons_and_substitute() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	foe.units[0].front = 1
	play(gs, "c61505")
	var bound: Dictionary = foe.units.back()
	check(bound.id == "fu-soul" and bound.attack == 0 and bound.hp == 1 and bound.front == 0 and gs.front_index(1) == 0, "缚魂 is a real 0/1 nonblocking summon")
	check(not gs.VerifiedRules.Movement.move_to(gs, 1, foe.units.size() - 1, 1), "缚魂 cannot be moved into the battle zone")
	gs.VerifiedRules.Huang.destroy(gs, 1, curse(gs, "hunzhou"), "专项")
	var soul: Dictionary = p.units.back()
	check(soul.id == "shu-soul" and soul.attack == 5 and soul.hp == 6 and soul.front == 1, "魂咒 departure creates real 5/6 束魂 in battle zone")
	gs._damage_unit(0, p.units.size() - 1, 1, 1, 0)
	check(soul.hp == 6, "坚毅 prevents a one-point damage packet")
	gs._damage_unit(0, p.units.size() - 1, 3, 1, 0, true)
	check(soul.hp == 4, "坚毅 subtracts exactly one from combat damage")
	check(gs.basic_attack(0, 2) and soul.removed, "束魂 departs when a friendly attacker replaces it")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	var u: Dictionary = p.units[0]
	play(gs, "c61508")
	check(foe.units.filter(func(x): return int(x.hp) > 0).size() == 3, "永生咒 directly destroys exactly one enemy")
	gs._knockout_unit(u)
	gs.VerifiedRules.Huang.destroy(gs, 1, curse(gs, "yongshengzhou"), "专项")
	check(u.hp == 6 and u.attack == 6 and u.knockout == 0 and u.form.cardId == "ly-changshengdan", "永生咒 departure attaches 6/6 substitute and revives")
	u.hp = 2
	u.shield = 1
	gs._damage_unit(0, 0, 2, 1, 0)
	check(u.hp == 1 and u.form.cardId == "ly-changshengdan", "nonlethal damage after armor leaves substitute intact")
	gs._damage_unit(0, 0, 10, 1, 0)
	check(u.hp == 6 and u.form.is_empty(), "lethal packet is prevented and sets life to 6")
	check(LY.has_curse(gs, 1, "yongshengzhou") and foe.units.filter(func(x): return int(x.hp) > 0).size() == 2, "substitute departure re-summons 永生咒 and resolves its entry")

func ai_rules() -> void:
	for n in range(1, 9):
		var gs := game()
		var id := "c615%02d" % n
		if n == 1: LY.summon_curse(gs, 1, "meizhou", "", 0)
		var h := give(gs, id)
		var card := gs.hand_card_def(0, h)
		var targets := [null] if card.target == "auto" else gs.valid_targets(0, card)
		check(not targets.is_empty(), "AI has legal targets " + id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI actually plays " + id)
		var texture := load("res://assets/official/cards/%s.png" % id)
		check(texture is Texture2D and texture.get_width() > 200, "original texture loads " + id)
		check(card.verifiedRules and not card.verificationPending.is_empty(), "rules carry original-client verification status " + id)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(ALLY, ENEMY, 608)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		var foe := gs.player(1)
		hand(b, ["c61503"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._pending_target_card == 0, "native 镇诀 opens unit target mode")
		await click(b._unit_widget(gs.player(0).units[0].uid))
		await settled(b)
		check(gs.player(0).hand.size() == 1 and foe.realms.is_empty(), "native ally click cannot cast 镇诀")
		await click(b._unit_widget(foe.units[0].uid))
		await settled(b)
		check(gs.player(0).hand.is_empty() and foe.realms.size() == 2, "native enemy click places 镇咒 and 寐咒")
		var original := curse(gs, "zhenzhou")
		hand(b, ["c61501"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._pending_target_card == 0 and b._enemy_realms.get_child_count() == 2, "native 钱眼 shows actual realm targets")
		var chip := b._enemy_realms.get_child(0) as Control
		check(chip.get_meta("realm_uid") == original.uid, "first realm chip identifies 镇咒")
		await click(chip)
		await settled(b)
		check(gs.player(0).hand.size() == 1 and not foe.realms.has(original) and gs.player(0).realms[0].name == "蜃境", "native click removes chosen realm, draws and resolves departure")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	passive_and_targets()
	realm_lifecycle()
	summons_and_substitute()
	ai_rules()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("LANGYA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
