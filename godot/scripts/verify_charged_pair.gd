extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const CP := preload("res://scripts/charged_pair_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("CHARGED_PAIR_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(["wannianzhu", "shuzhu", "rihefang", "taohuayao"], ["bingyong", "yaodaoji", "fenghuanghuo", "baizangzhu"], 268269)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.rule_events.clear(); return gs

func give(gs, id: String) -> int:
	gs.player(0).hand.append({"definitionId": id, "instanceId": "charged-test-%d" % gs.next_card_id})
	gs.next_card_id += 1; return gs.player(0).hand.size() - 1

func play(gs, id: String, target = null) -> void:
	var h := give(gs, id)
	check(gs.play_card(0, h, target), "actual use " + id)

func charge(gs, id: String, target = null) -> void:
	var h := give(gs, id); var fire: int = gs.player(0).energy
	check(CP.request_mode(gs, 0, h) and gs.pending_choice.type == "charged-mode", "actual mode choice " + id)
	check(gs.resolve_divination_choice(0, "charged-store"), "select charging " + id)
	check(gs.player(0).energy == fire and gs.player(0).hand.size() > h, "mode selection alone pays nothing " + id)
	check(CP.ready_hand(gs, 0) == h and gs.play_card(0, h, target), "actual store with selected target " + id)

func cycle(gs) -> void:
	check(gs.end_turn(0) and gs.end_turn(1), "actual complete turn cycle")

func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)

func storage_and_release() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[1]
	check(p.units[0].attack == 2 and p.units[0].maxHp == 5 and u.attack == 2 and u.maxHp == 5, "both printed2/5 replace old mappings")
	var cards_used: int = p.cardsPlayedThisTurn
	charge(gs, "c26902")
	check(u.attack == 3 and u.maxHp == 6 and u.has("lanternStored") and p.energy == 39, "charging gives real nonpermanent bead growth and pays once")
	check(p.cardsPlayedThisTurn == cards_used and events(gs, "charged-release").is_empty(), "storage is not card use or immediate attack")
	check(not CP.request_mode(gs, 0, give(gs, "c26904")), "only one stored card per unit")
	p.hand.clear(); cycle(gs)
	check(not u.has("lanternStored") and u.attack == 4 and u.maxHp == 6, "actual delayed release gets bamboo attack growth")
	check(gs.player(1).avatarHp == 26 and p.hand.any(func(i): return i.definitionId == "c26902"), "released staff actually attacks and gives fresh staff")
	check(events(gs, "charged-release").size() == 1 and p.energy == 2, "delayed use spends no extra fire")
	gs = game(); p = gs.player(0); u = p.units[1]; charge(gs, "c26902")
	check(gs.end_turn(0), "enter enemy turn for stun")
	gs.VerifiedRules.Stun.apply(gs, 0, 1, 1, 1)
	check(gs.end_turn(1) and u.has("lanternStored") and events(gs, "charged-release").is_empty(), "stunned own turn preserves but cannot release charging")
	cycle(gs)
	check(not u.has("lanternStored") and events(gs, "charged-release").size() == 1, "later unstunned turn releases exactly once")
	gs = game(); p = gs.player(0); u = p.units[1]; charge(gs, "c26902")
	gs._knockout_unit(u, 1, 0); gs._resolve_resolution_stack()
	check(not u.has("lanternStored") and u.attack == 2 and u.maxHp == 5, "actual knockout removes record and ordinary charging growth")
	gs = game(); p = gs.player(0); u = p.units[1]
	play(gs, "c26907"); charge(gs, "c26902")
	check(u.awakened and u.attack == 4 and u.maxHp == 7, "awakened charging is actual permanent growth")
	play(gs, "c16606", u.uid)
	check(u.attack == 4 and u.maxHp == 7 and u.has("lanternStored"), "sun numerical reset preserves permanent growth and charging buff")
	gs._knockout_unit(u, 1, 0); gs._resolve_resolution_stack(); gs.VerifiedRules.Peach.revive(gs, 0, 3, u, false, false)
	check(u.attack == 4 and u.maxHp == 7 and not u.has("lanternStored"), "permanent charging growth survives actual knockout and revival")
	gs = game(); u = gs.player(0).units[1]; charge(gs, "c26902"); play(gs, "c16606", u.uid)
	check(u.attack == 2 and u.maxHp == 5 and not u.has("chargedGrowth"), "sun reset erases ordinary charging rollback ledger")
	gs._knockout_unit(u, 1, 0); gs._resolve_resolution_stack(); gs.VerifiedRules.Peach.revive(gs, 0, 3, u, false, false)
	check(u.attack == 2 and u.maxHp == 5, "subsequent knockout cannot subtract reset growth twice")

func bamboo_cards() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]; var bead: Dictionary = p.units[1]
	var attack: int = bead.attack; var deck_size: int = p.deck.size()
	play(gs, "c26801", bead.uid)
	check(bead.attack == attack + 2 and p.deck.size() == deck_size - 1 and bead.shield == 0, "bamboo words actual gain and draw with no invented armor")
	charge(gs, "c26902"); play(gs, "c26801", bead.uid)
	check(bead.shield == 2, "words gives armor only to actually charging target")
	var h := give(gs, "c26802"); var c: Dictionary = gs.hand_card_def(0, h)
	check(c.type == "combat" and c.value == 2 and c.combatOption.firstStrike, "sword is printed combat with live charging count")
	check(gs.play_card(0, h), "actual first-strike sword")
	gs = game(); p = gs.player(0); u = p.units[0]; bead = p.units[1]
	play(gs, "c26803"); check(u.attack == 4 and u.maxHp == 6, "secret form exact4/6 and3勾")
	play(gs, "c26801", bead.uid)
	check(u.has("lanternStored") and u.lanternStored.card.id == "c26801" and u.lanternStored.targetId == bead.uid, "secret copies real used card with same selected target")
	check(events(gs, "charged-stored").size() == 1, "secret first copy happens exactly once")
	play(gs, "c26806", u.uid)
	check(not u.has("lanternStored") and events(gs, "charged-release").size() == 1 and events(gs, "charged-stored").size() == 1, "early release does not recursively re-copy the release spell or stored card")
	check(bead.attack == 6, "stored words actually affects its original target again")
	gs = game(); p = gs.player(0); u = p.units[0]; bead = p.units[1]
	play(gs, "c26804"); charge(gs, "c26902"); var avatar: int = gs.player(1).avatarHp
	gs._knockout_unit(bead, 1, 0); gs._resolve_resolution_stack()
	check(gs.player(1).avatarHp == avatar - 4, "guardian death of real charging ally causes actual projectile4")
	gs = game(); p = gs.player(0); bead = p.units[1]
	play(gs, "c26805"); charge(gs, "c26902")
	check(gs.VerifiedRules.Combat.has(bead, "veil") and not gs.VerifiedRules.Combat.has(p.units[0], "veil"), "forest grants veil only to charging allies")
	p.realms[0].hp = 0; CP.refresh(gs)
	check(not gs.VerifiedRules.Combat.has(bead, "veil"), "destroyed realm immediately removes charging veil")
	gs = game(); p = gs.player(0); bead = p.units[1]
	play(gs, "c26808"); charge(gs, "c26902"); var before: int = p.hand.size(); var deck_before: int = p.deck.size()
	play(gs, "c26806", bead.uid)
	check(p.units[0].awakened and p.hand.size() == before + 2 and p.deck.size() == deck_before - 1, "awakened bamboo draw and staff gift both occur on early charged use")
	gs = game(); p = gs.player(0); bead = p.units[1]
	play(gs, "c26801", bead.uid); play(gs, "c26902"); play(gs, "c26807")
	check(p.units[0].has("lanternStored") and bead.has("lanternStored"), "history spell actually charges both eligible previous card users")
	check(not p.units[2].has("lanternStored") and not p.units[3].has("lanternStored"), "history cannot invent cards for never-used allies")
	check(p.hand.any(func(i): return i.definitionId == "c26806"), "history puts an actual breeze into hand")
	gs = game(); p = gs.player(0); gs.player(1).units[0].keywords = ["veil"]
	c = Content.card_def("c26801"); var snapshot := JSON.stringify(gs.snapshot())
	check(not gs.valid_targets(0, c).has(gs.player(1).units[0].uid) and CP.random_targets(gs, 0, c).has(gs.player(1).units[0].uid), "random history targeting does not inherit manual veil restriction")
	check(JSON.stringify(gs.snapshot()) == snapshot, "random target query cannot mutate live battle or add preview flags")
	var fake: Dictionary = p.units[1].duplicate(true); fake.uid = "non-shikigami"; fake.summoned = true; fake.countsAsShikigami = false; p.units.append(fake)
	check(not gs.valid_targets(0,c).has(fake.uid) and not gs.valid_targets(0,c).has("avatar-1"), "words excludes nonshikigami summons and avatars")
	var hand_index := give(gs,"c26801")
	check(CP.request_mode(gs,0,hand_index) and gs.resolve_divination_choice(0,"charged-store"), "begin a real targeted charging selection")
	CP.ready_hand(gs,0)
	check(CP.request_mode(gs,0,hand_index) and gs.resolve_divination_choice(0,"charged-cancel"), "cancel a later mode choice without payment")
	check(not gs.hand_card_def(0,hand_index).chargedSelected, "cancelling cannot leave an invisible previous charge selection")

func beads_cards() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[1]
	u.hp = 2; p.avatarHp = 20; play(gs, "c26901")
	check(u.hp == 6 and p.avatarHp == 23 and u.has("lanternStored") and u.lanternStored.card.id == "c26901", "zazen heals both then self-charges with one growth")
	var count := events(gs, "charged-stored").size(); cycle(gs)
	check(not u.has("lanternStored") and events(gs, "charged-stored").size() == count, "automatic zazen is not from hand and cannot recharge itself")
	gs = game(); p = gs.player(0); u = p.units[1]
	charge(gs, "c26903"); play(gs, "c26806", u.uid)
	check(u.form.cardId == "c26903" and gs.VerifiedRules.Combat.has(u, "pursuit") and gs.basic_attack_targets(0, 1).has(gs.player(1).units[2].uid), "charged tiger form grants actual selectable pursuit")
	gs = game(); p = gs.player(0); u = p.units[1]; u.front = 1
	charge(gs, "c26904"); var hp: int = u.hp; var fire: int = p.energy
	gs._grow_unit(gs.player(1).units[1], 0, 20); var enemy_hp: int = gs.player(1).units[1].hp
	gs.current_player = 1; check(gs.basic_attack(1, 1), "enemy actually attacks a stored rock guard")
	check(not u.has("lanternStored") and u.hp == hp and not u.barrier and u.shield == 1, "stored guard releases before damage, barrier blocks and armor remains")
	check(p.energy == fire and gs.player(1).units[1].hp == enemy_hp - 5, "charged defense uses no extra fire and applies exactly one real counter bonus")
	gs = game(); p = gs.player(0); u = p.units[1]; gs.player(1).units[0].front = 1
	gs._grow_unit(gs.player(1).units[0], 0, 30); charge(gs, "c26905"); play(gs, "c26806", u.uid)
	check(gs.player(1).units[0].hp == 0 and gs.player(1).avatarHp == 24, "charged nonduality destroys current front then actually attacks avatar")
	gs = game(); p = gs.player(0); u = p.units[1]
	charge(gs, "c26906"); play(gs, "c26806", u.uid)
	check(u.form.cardId == "c26906" and u.inspired and u.swift, "charged dragon form grants both real inspired and swift")
	var cost: int = p.energy
	check(gs.basic_attack(0, 1) and p.energy == cost and not p.attackUsed and not u.get("swift",false) and not u.get("inspired",false), "swift and inspired are both consumed by actual free non-counting deployment")
	gs = game(); p = gs.player(0); u = p.units[1]
	gs._knockout_unit(u, 1, 0); gs._resolve_resolution_stack(); play(gs, "c26907")
	check(u.hp == u.maxHp and u.hp > 0 and u.awakened, "knocked source may truly revive and awaken")
	gs = game(); p = gs.player(0); u = p.units[1]
	play(gs, "c26908"); gs._knockout_unit(u, 1, 0); gs._resolve_resolution_stack()
	check(u.hp > 0 and u.form.is_empty() and u.has("lanternStored") and u.lanternStored.card.id == "c26908", "empty form actually revives and charges the removed form")
	gs.player(1).units[0].front = 1; gs._grow_unit(gs.player(1).units[0], 20, 30); hp = u.hp
	play(gs, "c26806", u.uid)
	check(u.form.cardId == "c26908" and u.hp == u.maxHp and u.hp > hp and gs.player(1).units[0].hp < gs.player(1).units[0].maxHp, "charged empty form enters and really attacks with combat immunity")

func ai_cards() -> void:
	for role_id in [268, 269]:
		for n in range(1, 9):
			var gs := game(); var p: Dictionary = gs.player(0); var id := "c%d%02d" % [role_id, n]
			if id == "c26806": charge(gs, "c26902"); p.hand.clear()
			give(gs, id)
			var best: Dictionary = AI._best_card(gs, 0)
			check(best.ok and gs.can_play_card(0, best.hand, best.target).ok, "real AI identifies legal card and target " + id)
			check(best.ok and gs.play_card(0, best.hand, best.target), "real AI executes " + id)

func mode_face(b, label: String):
	for face in faces(b._choice_layer):
		if face.data.get("currentCardStats", "") == label: return face
	return null

func ui_rules() -> void:
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical; DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["wannianzhu", "shuzhu", "rihefang", "taohuayao"], ["bingyong", "yaodaoji", "fenghuanghuo", "baizangzhu"], 268269)
		b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var p: Dictionary = b.gs.player(0); var bead: Dictionary = p.units[1]; var bamboo: Dictionary = p.units[0]
		hand(b, ["c26902"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.pending_choice.get("type") == "charged-mode" and mode_face(b, "蓄力使用") != null and mode_face(b, "普通使用") != null, "native shows genuine use/store alternatives")
		await capture("%d-01-charge-mode" % physical.x)
		await click(mode_face(b, "蓄力使用")); await settled(b)
		check(bead.has("lanternStored") and bead.attack == 3 and p.energy == 39 and p.hand.is_empty(), "mouse actually stores staff and pays once")
		hand(b, ["c26801"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(mode_face(b, "蓄力使用")); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(bead.uid).selected, "stored targeted spell asks for actual remembered target")
		await capture("%d-02-stored-target" % physical.x)
		await click(b._unit_widget(bead.uid)); await settled(b)
		check(bamboo.has("lanternStored") and bamboo.lanternStored.targetId == bead.uid and p.energy == 38, "mouse stores exact targeted words without prematurely applying gain")
		hand(b, ["c26806"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(bead.uid).selected and b._unit_widget(bamboo.uid).selected, "breeze exposes both actually charging allies")
		await click(b._unit_widget(bead.uid)); await settled(b)
		check(not bead.has("lanternStored") and bamboo.has("lanternStored") and p.hand.any(func(i): return i.definitionId == "c26902"), "mouse early release consumes only selected ally's record and resolves original card")
		await capture("%d-03-early-release" % physical.x)
		b.queue_free(); await process_frame; await process_frame
	for role_id in [268, 269]:
		for n in range(1, 9):
			var tile = preload("res://scripts/ui/card_face.gd").new(); var id := "c%d%02d" % [role_id, n]
			tile.data = Content.card_def(id); tile.refresh_art()
			check(tile._original_card != null and tile._original_card.resource_path == "res://assets/official/cards/%s.png" % id, "actual original texture " + id); tile.free()

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	storage_and_release(); bamboo_cards(); beads_cards(); ai_cards()
	if not only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("CHARGED_PAIR_OK checks=%d failures=%d rules_only=%s" % [checks, failures, only])
	quit(0 if failures == 0 else 1)
