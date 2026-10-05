extends SceneTree
## Exercise real UI signals and interruption ownership, beyond rule-only smoke tests.

const ContentLoader := preload("res://scripts/content_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const MainScene := preload("res://scenes/main_menu.tscn")
const VerifySupport := preload("res://scripts/verify_support.gd")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const SaveStore := preload("res://scripts/save_store.gd")

const ALLY := ["ember", "basalt", "lumen", "rime"]
const FOE := ["yaodaoji", "storm", "ink", "taohuayao"]

var _checks := 0
var _failures: Array = []


func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(description)
		printerr("INTERACTION_FAIL ", description)


func _game(lineup: Array = ALLY) -> GameState:
	var gs := GameState.create(lineup, FOE, 777001)
	for p in gs.players:
		p.hand.clear()
		p.energy = 2
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
	return gs


func _inject(gs: GameState, player_index: int, card_id: String) -> int:
	var p := gs.player(player_index)
	p.hand.append({"instanceId": "%s-test%d" % [p.id, gs.next_card_id], "definitionId": card_id})
	gs.next_card_id += 1
	return p.hand.size() - 1


func _battle(gs: GameState) -> BattleScreen:
	var battle := BattleScreen.new()
	battle.gs = gs
	gs.state_changed.connect(battle._refresh)
	root.add_child(battle)
	return battle


func _click_unit(battle: BattleScreen, uid: String) -> void:
	for panel in battle._ally_reserve.get_children():
		if panel.get_meta("unit_uid", "") == uid:
			for child in panel.get_children():
				if child is Button:
					child.pressed.emit()
					return


func _click_hand(battle: BattleScreen, index: int) -> void:
	for child in battle._hand_row.get_child(index).get_children():
		if child is Button:
			_check(not child.disabled, "legal response hand button is enabled")
			if not child.disabled:
				child.pressed.emit()
			return


func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
	var gs := _game()
	gs.player(0).levelUpUsed = false
	gs.player(0).units[1].level = 0
	var battle := _battle(gs)
	_click_unit(battle, str(gs.player(0).units[1].uid))
	_check(int(gs.player(0).units[1].level) == 1, "unit button performs level-up")
	battle.free()

	gs = _game()
	_inject(gs, 0, "hoar-barrier")
	var attack := _inject(gs, 1, "c10101")
	gs.current_player = 1
	_check(gs.play_card(1, attack), "opponent attack is legal")
	_check(not gs.response_window.is_empty(), "targeted response opens a window")
	battle = _battle(gs)
	_click_hand(battle, 0)
	_check(battle._pending_target_card == 0, "human can select a response during the AI turn")
	var command_count := gs.command_log.size()
	var window := gs.response_window.duplicate(true)
	GameAI.take_turn(gs, 1)
	_check(gs.response_window == window and gs.command_log.size() == command_count, "AI waits for the human response")
	_click_unit(battle, str(gs.player(0).units[0].uid))
	_check(gs.player(0).hand.is_empty() and gs.command_log.any(func(command): return command.c == "play_card" and int(command.p) == 0), "human plays a targeted response through unit buttons")
	battle.free()

	gs = _game()
	_inject(gs, 1, "c10102")
	attack = _inject(gs, 0, "flash-thrust")
	_check(gs.play_card(0, attack), "human attack is legal")
	battle = _battle(gs)
	battle._check_auto_ai()
	_check(battle._ai_thinking, "AI is scheduled for its response during the human turn")
	await create_timer(0.5).timeout
	_check(gs.command_log.any(func(command): return command.c == "play_card" and int(command.p) == 1), "scheduled AI response actually executes")
	battle.free()

	gs = _game(["ink", "ember", "basalt", "lumen"])
	_inject(gs, 0, "index-page")
	_check(gs.play_card(0, 0), "divination starts")
	var choice := gs.pending_choice.duplicate(true)
	command_count = gs.command_log.size()
	GameAI.take_turn(gs, 1)
	_check(gs.pending_choice == choice and gs.command_log.size() == command_count, "AI leaves the human divination choice pending")
	if not gs.pending_choice.is_empty():
		var iid := str(gs.pending_choice.instanceIds[0])
		_check(gs.resolve_divination_choice(0, iid), "human resolves divination")
		_check(gs.command_log.size() == command_count + 1, "divination choice is recorded")

	gs = _game()
	_inject(gs, 0, "mend")
	battle = _battle(gs)
	battle._on_hand_clicked(0, ContentLoader.card_def("mend"))
	_check(battle._pending_target_card == 0, "targeted spell enters selection")
	gs.end_turn(0)
	_check(battle._pending_target_card == -1, "turn transition clears stale target selection")
	battle.free()

	gs = _game()
	gs.player(0).levelUpUsed = false
	gs.player(0).units[1].level = 0
	battle = _battle(gs)
	_check(not battle._end_btn.disabled, "UI allows ending a turn without upgrading, as rules do")
	battle.free()

	gs = _game()
	_inject(gs, 1, "c10102")
	_inject(gs, 0, "flash-thrust")
	gs.play_card(0, 0)
	gs.pass_response(1)
	_check(int(gs.command_log.back().p) == 1, "response log records the acting player")
	for i in 405:
		gs._log("entry-%d" % i)
	_check(gs.log.size() == 400 and gs.log.back().text == "entry-404", "bounded battle log keeps the latest entries")

	gs = _game()
	for i in gs.player(0).units.size():
		gs.player(0).units[i].hp = int(gs.player(0).units[i].maxHp) - 4
	var rng_before := gs.rng_state
	gs._run_passive_effect(0, 0, "passive-heal-ally-if-front-or-any", {"amount": 1}, {})
	_check(gs.rng_state != rng_before, "random passive consumes the seeded RNG")
	gs = _game()
	var twin := _game()
	for i in 12:
		for game in [gs, twin]:
			for unit in game.player(0).units:
				unit.hp = int(unit.maxHp) - 4
		seed(i)
		gs._run_passive_effect(0, 0, "passive-heal-ally-if-front-or-any", {"amount": 1}, {})
		gs._run_passive_effect(0, 0, "passive-damage-random-enemy", {"amount": 1}, {})
		seed(i + 100)
		twin._run_passive_effect(0, 0, "passive-heal-ally-if-front-or-any", {"amount": 1}, {})
		twin._run_passive_effect(0, 0, "passive-damage-random-enemy", {"amount": 1}, {})
	_check(gs.players == twin.players and gs.rng_state == twin.rng_state, "identical seeded passive chains ignore unrelated global randomness")

	var main: Control = MainScene.instantiate()
	root.add_child(main)
	main._show_formation()
	var draft := ["storm", "ink", "rime"]
	main._current.set_preselect(draft)
	main._current.edit_deck.emit("storm")
	main._current.back_requested.emit()
	_check(main._current._selected == draft, "formation draft survives a deck-builder round trip")
	main._current.edit_deck.emit("storm")
	main._current.deck_confirmed.emit("storm", ContentLoader.starter_card_ids("storm"))
	_check(main._current._selected == draft, "saving a deck also preserves the formation draft")
	var custom := ContentLoader.starter_card_ids("ember")
	var extra: Dictionary = ContentLoader.cards_for_unit("ember").filter(func(card): return int(card.get("starterCopies", 0)) == 0)[0]
	custom[0] = extra.id
	SaveStore.set_deck("ember", custom)
	main._quick = true
	main._start_battle()
	await process_frame
	await process_frame
	_check(main._current.size == main.size and main._current.position == Vector2.ZERO, "routed battle fills its parent viewport")
	var cards: Array = main._current.gs.player(0).deck.duplicate()
	cards.append_array(main._current.gs.player(0).hand)
	_check(not cards.any(func(card): return card.definitionId == extra.id), "quick matches use starter decks despite saved custom decks")
	main._lineup = ALLY.duplicate()
	main._quick = false
	main._start_battle()
	cards = main._current.gs.player(0).deck.duplicate()
	cards.append_array(main._current.gs.player(0).hand)
	_check(cards.any(func(card): return card.definitionId == extra.id), "formation matches still use the saved custom deck")
	main.free()
	await process_frame
	await _verify_layout()
	VerifySupport.cleanup_stores(fixture)
	print("INTERACTIONS checks=%d failures=%d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("INTERACTIONS_OK")
	quit(0 if _failures.is_empty() else 1)


func _verify_layout() -> void:
	root.size = Vector2i(1280, 800)
	var gs := _game()
	_inject(gs, 0, "mend")
	var battle := _battle(gs)
	await process_frame
	await process_frame
	_check(battle._hand_scroll.get_global_rect().end.y <= 800, "opening hand stays inside the viewport")
	for p in gs.players:
		p.units[0].front = 1
		for unit in p.units:
			unit.shield = 2
			unit.frozen = 1
			unit.brittle = 1
			unit.unyielding = true
			unit.charge = 3
	gs.state_changed.emit()
	await process_frame
	await process_frame
	_check(battle._hand_scroll.get_global_rect().end.y <= 800, "both front lines leave the hand reachable")
	_check(battle._hand_scroll.get_global_rect().end.x <= 1280, "stacked status badges do not widen the battle beyond the viewport")
	battle.free()
	var formation := FormationScreen.new()
	root.add_child(formation)
	await process_frame
	await process_frame
	_check(formation._detail_box.size.x <= formation._detail_box.get_parent().size.x, "long formation passives stay within their column")
	formation.free()
