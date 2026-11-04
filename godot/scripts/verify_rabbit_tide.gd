extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const RT := preload("res://scripts/rabbit_tide_rules.gd")
const Food := preload("res://scripts/cooking_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1; printerr("RABBIT_TIDE_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["qianji", "tuwan", "bingyong", "shantong"], ["bingyong", "shantong", "bailang", "hetong"], 247250)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "rabbit-tide-%d" % gs.next_card_id}); gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "actual play " + id)
func fortune(gs, src: int, success: bool) -> bool:
	gs.rng_state = 1000 if success else 1
	return gs._roll_fortune(0, {"fortuneSourceIndex": src, "fortune": {"sides": 6, "threshold": 4}})
func strong(u: Dictionary, hp: int = 16, attack: int = 0) -> void:
	u.baseMaxHp = hp; u.maxHp = hp; u.hp = hp; u.baseAttack = attack; u.attack = attack; u.attackBonus = 0; u.maxHpBonus = 0
func food_events(gs, food_kind: String) -> int:
	# rule_events.kind is the event name; food category is carried by card.foodData.
	return gs.rule_events.filter(func(e): return e.kind == "food-used" and e.get("card", {}).get("foodData", {}).get("kind", "") == food_kind).size()
func actual_turn(gs) -> void:
	gs.player(gs.current_player).levelUpUsed = true
	check(gs.end_turn(gs.current_player), "real turn transition")

func first_turn_positions() -> void:
	for slot in 4:
		var lineup: Array = ["bingyong", "tuwan", "shantong", "bailang"]; lineup[slot] = "qianji"
		var gs := GS.create(lineup, lineup, 247250 + slot)
		for side in gs.players: side.hand.clear(); side.levelUpUsed = true
		check(RT.live_spear(gs, 0) >= 0 and RT.live_spear(gs, 1) < 0, "first-player spear summons before activation in lineup slot%d" % slot)
		actual_turn(gs)
		check(RT.live_spear(gs, 1) >= 0, "second-player first own turn summons spear in slot%d" % slot)
		var counts: Array = [gs.player(0).units.size(), gs.player(1).units.size()]
		actual_turn(gs); actual_turn(gs)
		check(gs.player(0).units.size() == counts[0] and gs.player(1).units.size() == counts[1], "later own turns cannot repeat either first-turn summon in slot%d" % slot)
		for owner in 2: gs._knockout_unit(gs.player(owner).units[RT.live_spear(gs, owner)])
		gs._resolve_resolution_stack(); actual_turn(gs); actual_turn(gs)
		check(RT.live_spear(gs, 0) < 0 and RT.live_spear(gs, 1) < 0, "departed first-turn spears are not replenished by later turn in slot%d" % slot)
	for blocked in ["suppressed", "knocked"]:
		var gs := GS.create(["bingyong", "qianji", "shantong", "bailang"], ["bingyong", "qianji", "shantong", "bailang"], 247257)
		for side in gs.players: side.hand.clear(); side.levelUpUsed = true
		if blocked == "suppressed": gs.player(1).units[1].baseRulesSuppressed = true
		else: gs._knockout_unit(gs.player(1).units[1])
		actual_turn(gs); check(RT.live_spear(gs, 1) < 0, "first-turn %s qianji cannot summon" % blocked)
		gs.player(1).units[1].baseRulesSuppressed = false
		actual_turn(gs); actual_turn(gs)
		check(RT.live_spear(gs, 1) < 0, "missed %s first-turn trigger is not deferred to a later turn" % blocked)

func rabbit_failure_and_recipe() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	check(p.units[1].attack == 2 and p.units[1].maxHp == 6, "rabbit exact base2/6")
	check(not fortune(gs, 0, false) and p.hand.is_empty(), "other source fortune failure gives no unknown food")
	check(not fortune(gs, 1, false) and Food.hand_food_count(gs, 0, "unknown") == 1, "rabbit final failure generates actual4break ingredient")
	fortune(gs, 1, false); check(Food.hand_food_count(gs, 0, "unknown") == 1, "base once per global turn")
	gs.turn_counter += 1; fortune(gs, 1, false)
	check(Food.hand_food_count(gs, 0, "unknown") == 2, "base refreshes on opponent global turn too")
	play(gs, "c25004")
	fortune(gs, 1, false); fortune(gs, 1, false)
	check(Food.hand_food_count(gs, 0, "unknown") == 4 and p.units[1].attack == 3 and p.units[1].maxHp == 7, "awakening removes failure cap and exact1/1")
	var before: int = Food.hand_food_count(gs, 0, "unknown")
	gs.rng_state = 1; RT.begin_turn(gs, 0); gs._resolve_resolution_stack()
	check(Food.hand_food_count(gs, 0, "unknown") == before + 1 and not gs.rule_events.any(func(e): return e.kind == "cooking"), "awake failed start does not fake cooking")
	gs = game(); p = gs.player(0); play(gs, "c25004"); gs.rng_state = 1000; RT.begin_turn(gs, 0); gs._resolve_resolution_stack()
	check(gs.rule_events.any(func(e): return e.kind == "cooking") and Food.hand_food_count(gs, 0, "ingredient") == 1, "awake successful start really cooks and gains ingredient")
	gs = game(); p = gs.player(0); p.avatarHp = 10
	Food.gain_ingredient(gs, 0, 1, "mountain"); Food.gain_ingredient(gs, 0, 1, "sea"); Food.gain_ingredient(gs, 0, 1, "vegetable")
	var deck: int = p.deck.size(); var hp: int = gs.player(1).avatarHp; var energy: int = p.energy
	play(gs, "c25003")
	check(p.deck.size() == deck - 1 and p.energy == energy, "recipe actual draw and shared instant payment")
	check(gs.player(1).avatarHp == hp - 3 and p.avatarHp == 15 and gs.kw_usage(1, "encourage").attack == -3 and gs.kw_usage(1, "encourage").shield == -3, "three distinct ingredients unlock exact projectile/heal/suppress")
	gs = game(); p = gs.player(0); Food.gain_unknown(gs, 0, 1); deck = p.deck.size(); hp = gs.player(1).avatarHp
	play(gs, "c25003"); check(p.deck.size() == deck - 1 and gs.player(1).avatarHp == hp and p.get("cookingSeenKinds", []).is_empty(), "unknown is no invented fourth recipe ingredient")

func rabbit_forms_and_combat() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs, "c25002"); check(p.units[1].attack == 3 and p.units[1].maxHp == 6, "lonely rabbit exact3/6")
	gs.rng_state = 1000; Food.cook(gs, 0, 0); gs._resolve_resolution_stack()
	check(food_events(gs, "ingredient") == 1 and int(p.units[1].get("rtLonelyTurn", -1)) == gs.turn_counter, "friendly cooking rolls once and really uses generated ingredient on rabbit")
	Food.cook(gs, 0, 0); gs._resolve_resolution_stack(); check(food_events(gs, "ingredient") == 1, "second cooking same turn cannot repeat lonely trigger")
	gs = game(); p = gs.player(0); play(gs, "c25002"); gs.rng_state = 1000; Food.cook(gs, 1, 0); gs._resolve_resolution_stack()
	check(food_events(gs, "ingredient") == 0 and not p.units[1].has("rtLonelyTurn"), "enemy cooking cannot trigger lonely rabbit")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs, "c25005"); strong(foe.units[0]); foe.units[0].front = 1; gs.rng_state = 1000
	gs._resolve_combat(0, 1, 0, false, false, false, false); gs._resolve_resolution_stack()
	check(p.units[1].attack == 4 and p.units[1].maxHp == 7 and foe.units[0].hp == 8 and food_events(gs, "unknown") == 1, "taste attack gives4break before actual4combat damage")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs, "c25005"); strong(foe.units[0]); p.units[1].front = 1; gs.rng_state = 1000
	gs._resolve_combat(1, 0, 0, false, false, false, false); gs._resolve_resolution_stack()
	check(foe.units[0].hp == 8 and food_events(gs, "unknown") == 1, "taste defending uses unknown on real attacker before retaliation")
	gs = game(); p = gs.player(0); foe = gs.player(1); strong(foe.units[0]); foe.units[0].front = 1
	play(gs, "c25008")
	check(foe.units[0].hp == 8 and food_events(gs, "unknown") == 1, "contest uses actual4break before4power, never direct surrogate damage")
	gs = game(); p = gs.player(0); play(gs, "c25008")
	check(food_events(gs, "unknown") == 0, "contest does not use unknown on avatar")
	gs = game(); p = gs.player(0); foe = gs.player(1); strong(foe.units[0]); strong(foe.units[1], 16, 7); foe.units[0].front = 1
	var h := give(gs, "c25006"); check(not gs.hand_card_def(0, h).get("combatOption", {}).get("pursuit", false), "cute has no pursuit without actual enemy-food history")
	Food.auto_use_generated(gs, 0, 1, p.units[1].uid, "unknown"); gs._resolve_resolution_stack()
	check(not gs.hand_card_def(0, h).get("combatOption", {}).get("pursuit", false), "own unknown use does not enhance cute")
	Food.auto_use_generated(gs, 0, 1, foe.units[1].uid, "unknown"); gs._resolve_resolution_stack()
	check(gs.hand_card_def(0, h).combatOption.pursuit, "enemy unknown use dynamically grants pursuit")
	var own_hp: int = p.units[1].hp; check(gs.play_card(0, h, foe.units[1].uid), "actual cute selects reserve target")
	check(p.units[1].hp == own_hp and foe.units[0].hp == 16 and foe.units[1].hp == 8, "cute hunts selected reserve and immune to all combat damage")
	gs.turn_counter += 1; h = give(gs, "c25006"); check(not gs.hand_card_def(0, h).combatOption.get("pursuit", false), "cute enemy-food history expires with global turn")
	gs = game(); p = gs.player(0); foe = gs.player(1); strong(foe.units[0]); play(gs, "c25007", foe.units[0].uid)
	check(p.units[1].attack == 6 and p.units[1].maxHp == 6 and foe.units[0].hp == 9, "soul6/6 entry unknown4break then real3damage consumes break for7")
	Food.auto_use_generated(gs, 0, 1, p.units[1].uid, "unknown"); gs._resolve_resolution_stack()
	check(p.units[1].hp == 6 and foe.units[0].hp == 9, "soul excludes own food use")
	Food.gain_unknown(gs, 0, 1); Food.gain_unknown(gs, 0, 1); Food.cook(gs, 0, 1); gs._resolve_resolution_stack()
	var dark: Array = p.hand.filter(func(i): return Food.food_kind(i) == "dark")
	check(dark.size() == 1, "two actual unknown ingredients cook into dark cuisine")
	if not dark.is_empty():
		var dark_hand: int = p.hand.find(dark[0]); check(gs.hand_card_def(0, dark_hand).keywords.has("instant") and gs.play_card(0, dark_hand, foe.units[1].uid), "dark actual instant6break food legal enemy use")
		check(foe.units[1].hp == 0 and food_events(gs, "dark") == 1 and int(p.rtEnemyFoodTurn) == gs.turn_counter, "dark triggers soul3 and enemy-food enhancement")
	gs = game(); p = gs.player(0); var deck: int = p.deck.size(); gs.rng_state = 1000; play(gs, "c25001")
	check(p.deck.size() == deck - 1 and not gs.rule_events.any(func(e): return e.kind == "cooking"), "forage fortune succeeds draws without cooking substitute")

func tide_entities_and_cards() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var idx := RT.live_spear(gs, 0)
	check(idx >= 0 and p.units[idx].attack == 0 and p.units[idx].maxHp == 2 and p.units[idx].front == 1, "first own turn creates real0/2 front spear")
	var count: int = p.units.size(); p.turnsTaken = 2; RT.begin_turn(gs, 0); gs._resolve_resolution_stack()
	check(p.units.size() == count, "later own turn does not repeat first-turn summon")
	var old_uid: String = p.units[idx].uid; gs._knockout_unit(p.units[idx]); gs._resolve_resolution_stack()
	check(RT.live_spear(gs, 0) < 0 and p.hand.any(func(i): return i.definitionId == "qianji-song"), "knockout departure generates song")
	var h: int = p.hand.find(p.hand.filter(func(i): return i.definitionId == "qianji-song")[0]); check(not gs.hand_card_def(0, h).keywords.has("instant"), "unawakened unenhanced song costs ordinary fire")
	play(gs, "c24703"); check(gs.hand_card_def(0, h).keywords.has("instant"), "using qianji card grants existing song instance instant")
	check(gs.play_card(0, h), "actual song resummons spear")
	idx = RT.live_spear(gs, 0); check(idx >= 0 and p.units[idx].uid != old_uid and gs.kw_usage(1, "encourage").attack == -2 and p.units[0].attack == 3 and p.units[0].maxHp == 6, "new spear instance and deepsea exact3/6 suppress2")
	RT.remove_spear(gs, 0, p.units[idx]); RT.summon_spear(gs, 0, 0); idx = RT.live_spear(gs, 0); RT.remove_spear(gs, 0, p.units[idx]); gs._resolve_resolution_stack()
	check(p.hand.filter(func(i): return i.definitionId == "qianji-song").size() == 1, "repeated departure cannot duplicate song in hand")
	gs = game(); p = gs.player(0); foe = gs.player(1); idx = RT.live_spear(gs, 0); play(gs, "c24705")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5 and p.units[idx].attack == 4, "tide awake exact1/1 and existing spear4power")
	RT.remove_spear(gs, 0, p.units[idx]); gs._resolve_resolution_stack(); h = p.hand.find(p.hand.filter(func(i): return i.definitionId == "qianji-song")[0]); check(gs.hand_card_def(0, h).keywords.has("instant"), "newly obtained song has awakened instant")
	check(gs.play_card(0, h), "awakened song real play"); idx = RT.live_spear(gs, 0); check(p.units[idx].attack == 4, "future spear receives awake4once")
	strong(foe.units[0], 16, 9); foe.units[0].front = 1; play(gs, "c24701")
	check(p.units[idx].attack == 8 and p.units[idx].hp == 2 and foe.units[0].hp == 8, "thousand-tides permanent4 and actual spear immune attack")
	strong(foe.units[1], 16, 9); play(gs, "c24707", foe.units[1].uid)
	check(p.units[idx].attack == 13 and p.units[idx].hp == 2 and foe.units[1].hp == 3, "dream-tide permanent5 attacks chosen reserve with combat immunity")
	RT.remove_spear(gs, 0, p.units[idx]); gs._resolve_resolution_stack(); h = give(gs, "c24701")
	check(not gs.can_play_card(0, h).ok, "spear spell rejects no spear before payment")
	gs = game(); p = gs.player(0); foe = gs.player(1); strong(foe.units[0]); var hp: int = foe.avatarHp; play(gs, "c24702", foe.units[0].uid)
	check(foe.units[0].hp == 13 and foe.avatarHp == hp - 3, "tide dream targeted3 then conditional projection3")
	idx = RT.live_spear(gs, 0); RT.remove_spear(gs, 0, p.units[idx]); gs._resolve_resolution_stack(); hp = foe.avatarHp; play(gs, "c24702", foe.units[0].uid)
	check(foe.units[0].hp == 10 and foe.avatarHp == hp, "no spear dream omits projection")
	gs = game(); p = gs.player(0); foe = gs.player(1); var deck: int = p.deck.size(); play(gs, "c24704", foe.units[1].uid)
	check(foe.units[1].frozen > 0 and gs.kw_usage(1, "encourage").attack == -2 and p.deck.size() == deck - 1, "calltide real stun+suppression+conditionaldraw")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs, "c24706"); idx = RT.live_spear(gs, 0); RT.remove_spear(gs, 0, p.units[idx]); hp = foe.avatarHp; RT.summon_spear(gs, 0, 0); gs._resolve_resolution_stack()
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5 and p.units[0].front == 0 and foe.avatarHp == hp - 4 and RT.live_spear(gs, 0) >= 0, "shaper4/5 remote actual master attack preserves spear front")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs, "c24708"); idx = RT.live_spear(gs, 0)
	check(gs.VerifiedRules.Combat.has(p.units[0], "veil") and not gs.valid_targets(1, Content.card_def("c24702")).has(p.units[0].uid), "eternal6/6 existing spear grants real enemy-targeting veil")
	hp = foe.avatarHp; var unit_hp: int = foe.units[0].hp; RT.remove_spear(gs, 0, p.units[idx]); gs._resolve_resolution_stack()
	check(not gs.VerifiedRules.Combat.has(p.units[0], "veil") and foe.avatarHp == hp - 2 and foe.units[0].hp == unit_hp - 2, "departure removes veil and deals2all enemycharacters")
	RT.summon_spear(gs, 0, 0); gs._resolve_resolution_stack()
	check(foe.units.filter(func(u): return int(u.frozen) > 0).size() == 1 and gs.VerifiedRules.Combat.has(p.units[0], "veil"), "eternal new entry randomstuns exactly1 and restoresveil")
	var frozen: int = foe.units.filter(func(u): return int(u.frozen) > 0).size(); RT.refresh(gs)
	check(foe.units.filter(func(u): return int(u.frozen) > 0).size() == frozen, "continuous refresh cannot retrigger entry stun")
	idx = RT.live_spear(gs, 0); gs._knockout_unit(p.units[idx]); gs._resolve_resolution_stack()
	for enemy in foe.units: enemy.frozen = 0
	gs.VerifiedRules.Weaver.revive(gs, 0, idx); gs._resolve_resolution_stack()
	check(RT.live_spear(gs, 0) == idx and foe.units.filter(func(u): return int(u.frozen) > 0).size() == 1, "real summon revival is an eternal entry and retriggers one random stun")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs, "c24703"); idx = RT.live_spear(gs, 0); gs._knockout_unit(p.units[idx]); gs._resolve_resolution_stack()
	gs.VerifiedRules.Weaver.revive(gs, 0, idx); gs._resolve_resolution_stack()
	check(int(gs.kw_usage(1, "encourage").get("attack", 0)) == 0, "revival entry is not a new summon for deepsea suppression")

func ai_rules() -> void:
	var gs := game(); var foe: Dictionary = gs.player(1); give(gs, "c25007")
	var best: Dictionary = AI._best_card(gs, 0)
	check(best.ok and gs._unit_index_by_uid(1, str(best.target)) >= 0 and gs.can_play_card(0, best.hand, best.target).ok, "AI soul chooses legal enemy entry-food target")
	gs = game(); give(gs, "c24707"); best = AI._best_card(gs, 0)
	check(best.ok and gs.valid_targets(0, Content.card_def("c24707")).has(best.target), "AI spear hunt chooses actual legal shikigami")

func ui_rules() -> void:
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["qianji", "tuwan", "bingyong", "shantong"], ["bingyong", "shantong", "bailang", "hetong"], 247250); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(b); await create_timer(0.4).timeout
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
		hand(b, ["c25007"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(str(foe.units[1].uid)).selected, "native soul form opens real shikigami target at %s" % physical)
		await capture("%dx%d-01-soul-target" % [physical.x, physical.y]); await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(p.units[1].form.get("cardId", "") == "c25007" and foe.units[1].hp == 0, "native selected soul gives unknown then3damage at %s" % physical)
		strong(foe.units[2]); hand(b, ["c24707"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0, "native spear hunt target mode %s" % physical)
		await capture("%dx%d-02-spear-selected-target" % [physical.x, physical.y]); await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		var idx := RT.live_spear(gs, 0)
		check(idx >= 0 and p.units[idx].attack == 5 and p.units[idx].hp == 2 and foe.units[2].hp == 11, "native spear actual targeted immune attack %s" % physical)
		hand(b, ["c24708"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.VerifiedRules.Combat.has(p.units[0], "veil"), "native eternal veil after form %s" % physical)
		RT.remove_spear(gs, 0, p.units[idx]); gs._resolve_resolution_stack(); b._last_view = {}; b._refresh(); await settled(b)
		var song: int = p.hand.find(p.hand.filter(func(i): return i.definitionId == "qianji-song")[0]); await click(b._hand_row.get_child(song)); await settled(b)
		check(RT.live_spear(gs, 0) >= 0 and gs.VerifiedRules.Combat.has(p.units[0], "veil"), "native generated song plays and restores spear %s" % physical)
		await capture("%dx%d-03-song-resummon-veil" % [physical.x, physical.y]); b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if not str(arg).begins_with("--"): out = arg; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	first_turn_positions(); rabbit_failure_and_recipe(); rabbit_forms_and_combat(); tide_entities_and_cards(); ai_rules()
	if not args.has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("RABBIT_TIDE checks=%d failures=%d" % [checks, failures]); quit(0 if failures == 0 else 1)
