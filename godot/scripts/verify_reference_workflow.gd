extends SceneTree
## Regression evidence for the recording-inspired loop. All storage is isolated.
const ContentLoader := preload("res://scripts/content_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const CollectionScreen := preload("res://scripts/ui/collection_screen.gd")
const DeckBuilder := preload("res://scripts/ui/deck_builder.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const MainScene := preload("res://scenes/main_menu.tscn")
const ResultScreen := preload("res://scripts/ui/result_screen.gd")
const MainMenuScreen := preload("res://scripts/ui/main_menu.gd")
const ALLY := ["ember", "basalt", "lumen", "rime"]
const FOE := ["storm", "kongo", "frostblade", "ink"]
var checks := 0
var failures := 0

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	root.theme = ThemeBuilder.build_theme()
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("REFERENCE_FAIL ", message)

func _click(control: Control) -> void:
	for child in control.get_children():
		if child is Button:
			child.pressed.emit()
			return

func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
	_verify_opening()
	_verify_pack_transactions()
	_check(SaveStore.save_formation(3, ALLY), "formation saves to a named slot")
	_check(SaveStore.get_formations()[3].lineup == ALLY, "formation survives reload")
	_check(not SaveStore.save_formation(3, ["ember", "ember", "lumen", "rime"]), "duplicate lineup is rejected")
	_check(SaveStore.get_formations()[3].lineup == ALLY, "invalid lineup cannot overwrite saved formation")
	await _verify_ui_loop()
	await _verify_duel()
	VerifySupport.cleanup_stores(fixture)
	print("REFERENCE_WORKFLOW checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("REFERENCE_WORKFLOW_OK")
	quit(0 if failures == 0 else 1)

func _verify_opening() -> void:
	var gs := GameState.create(ALLY, FOE, 777, {}, {}, true)
	var twin := GameState.create(ALLY, FOE, 777, {}, {}, true)
	var before := gs.players.duplicate(true)
	var rng_before := gs.rng_state
	_check(gs.phase == "opening" and gs.action_player() == -1, "opening holds both action owners")
	_check(not gs.can_level_up(0, 1) and not gs.can_basic_attack(0, 0).ok and not gs.can_play_card(0, 0).ok and not gs.end_turn(0), "opening blocks all live commands")
	_check(not gs.confirm_opening([0, 0]) and not gs.confirm_opening([0, 1, 2, 3]) and not gs.confirm_opening([-1]), "invalid mulligans fail")
	_check(gs.players == before and gs.rng_state == rng_before and gs.command_log.is_empty(), "invalid mulligan changes no cards or RNG")
	var rejected := [before[0].hand[0].instanceId, before[0].hand[2].instanceId]
	_check(gs.confirm_opening([0, 2]), "two selected opening cards are replaced")
	_check(gs.player(0).hand.size() == before[0].hand.size() and gs.player(0).deck.size() == before[0].deck.size(), "mulligan conserves hand and deck counts")
	_check(not gs.player(0).hand.any(func(card): return rejected.has(card.instanceId)), "rejected instances cannot be drawn as replacements")
	_check(gs.player(0).hand[1] == before[0].hand[1], "unselected card stays in place")
	twin.confirm_opening([0, 2])
	_check(gs.players == twin.players and gs.rng_state == twin.rng_state, "mulligan is deterministic for seed and command")
	_check(gs.command_log.back().c == "mulligan" and not gs.confirm_opening([]), "mulligan is logged and cannot repeat")

func _verify_pack_transactions() -> void:
	var data := CollectionStore._default()
	data.balance = 10000
	CollectionStore.save_collection(data)
	_check(not CollectionStore.purchase_packs("bad", 1).ok and not CollectionStore.purchase_packs("all", -1).ok, "invalid pack purchases are rejected")
	_check(CollectionStore.purchase_packs("classic", 5).ok, "five sealed packs can be purchased")
	data = CollectionStore.load_collection()
	_check(int(data.balance) == 9500 and int(data.packInventory.classic) == 5 and int(data.packsOpened) == 0, "buying deducts once and stores unopened inventory")
	data.balance = 0
	CollectionStore.save_collection(data)
	var unchanged := CollectionStore.load_collection().duplicate(true)
	_check(not CollectionStore.purchase_packs("all", 1).ok and CollectionStore.load_collection() == unchanged, "insufficient purchase leaves storage unchanged")
	var result := CollectionStore.open_owned_pack("classic", 12345)
	_check(result.ok and result.cards.size() == 5, "owned pack opens without another purchase charge")
	_check(result.cards.all(func(item): return ContentLoader.unit_def(str(ContentLoader.card_def(item.id).unitId)).get("pack") == "classic"), "selected pack never draws other expansions")
	data = CollectionStore.load_collection()
	_check(int(data.packInventory.classic) == 4 and int(data.packsOpened) == 1, "opening consumes one inventory pack")
	var credited: Dictionary = data.owned.duplicate()
	var pending: Dictionary = data.pendingReveal.duplicate(true)
	_check(not CollectionStore.open_owned_pack("classic", 7654).ok and not CollectionStore.finish_reveal(), "unfinished reveal prevents reroll or premature completion")
	CollectionStore.reveal_card(0)
	CollectionStore.reveal_card(0)
	_check(CollectionStore.load_collection().pendingReveal.revealed == [0], "repeated flips are idempotent")
	_check(CollectionStore.load_collection().pendingReveal.cards == pending.cards and CollectionStore.load_collection().owned == credited, "revealing never rerolls or grants cards twice")
	for i in 5: CollectionStore.reveal_card(i)
	_check(CollectionStore.finish_reveal() and CollectionStore.load_collection().pendingReveal.is_empty(), "all five flips finish the persisted reveal")
	var rates := CollectionStore.pack_probabilities("classic")
	_check(is_equal_approx(float(rates.epic), 0.0) and is_equal_approx(float(rates.ssr), 0.085), "probabilities account for unavailable epic tier")
	data = CollectionStore.load_collection()
	data.pitySinceEpic = 24
	CollectionStore.save_collection(data)
	result = CollectionStore.open_owned_pack("classic", 2)
	_check(result.cards.all(func(item): return item.rarity == "ssr"), "missing epic tier upgrades due pity to SSR")
	for i in 5: CollectionStore.reveal_card(i)
	CollectionStore.finish_reveal()

func _verify_ui_loop() -> void:
	var data := CollectionStore._default()
	CollectionStore.save_collection(data)
	var collection := CollectionScreen.new()
	root.add_child(collection)
	collection._buy_btn.pressed.emit()
	_check(int(CollectionStore.load_collection().packInventory.all) == 1, "shop button buys a sealed pack")
	collection._open_btn.pressed.emit()
	_check(collection._reveal_box.get_child_count() == 5 and collection._finish_btn.disabled, "open button presents five sealed cards")
	collection._flip_reveal(0)
	collection._flip_reveal(1)
	await create_timer(0.45).timeout
	_check(CollectionStore.load_collection().pendingReveal.revealed == [0], "overlapping flip input cannot destroy active animation")
	collection.free()
	collection = CollectionScreen.new()
	root.add_child(collection)
	_check(not collection._reveal_box.get_child(0).face_down and collection._reveal_box.get_child(1).face_down, "re-entering resumes the same reveal")
	collection._reveal_all_btn.pressed.emit()
	_check(not collection._finish_btn.disabled, "reveal-all enables completion")
	collection._finish_btn.pressed.emit()
	_check(CollectionStore.load_collection().pendingReveal.is_empty(), "receive button completes without additional draw")
	collection.free()
	# The dummy display resets its window to 64px after deferred startup.
	# Set the intended viewport immediately before checking the battle layout.
	root.size = Vector2i(1280, 800)
	var battle := BattleScreen.new()
	battle.setup(ALLY, FOE, 20261004, {}, {}, true)
	root.add_child(battle)
	_click(battle._opening_cards.get_child(0))
	_check(battle._mulligan_selected == [0], "opening card button selects a replacement")
	battle.gs.confirm_opening(battle._mulligan_selected)
	battle.gs.level_up(0, 1)
	await create_timer(battle._presentation_remaining() + 0.05).timeout
	_check(battle._can_drop_command({"kind": "unit", "unit": 0}, null), "legal unit drag enables combat drop zone")
	_check(not battle._ally_reserve.can_drop.call({"kind": "unit", "unit": 0}) and battle._enemy_front.can_drop.call({"kind": "unit", "unit": 0}), "only combat rows accept an automatic attack drop")
	battle._drop_command({"kind": "unit", "unit": 0}, null)
	_check(battle.gs.front_index(0) == 0 and int(battle.gs.player(1).avatarHp) < 30, "unit drop performs a real core attack")
	_check(not battle._can_drop_command({"kind": "unit", "unit": 0}, null), "used attack cannot be dragged again")
	await create_timer(battle._presentation_remaining() + 0.05).timeout
	var hand_index: int = battle.gs.player(0).hand.size()
	battle.gs.player(0).hand.append({"instanceId": "reference-brace", "definitionId": "brace"})
	battle._refresh()
	battle._on_hand_clicked(hand_index, ContentLoader.card_def("brace"))
	_check(battle._pending_target_card == hand_index and battle._unit_widget(str(battle.gs.player(0).units[0].uid)).selected, "targeted card highlights legal portrait targets")
	battle._cancel_target_selection()
	_check(not battle._unit_widget(str(battle.gs.player(0).units[0].uid)).selected, "cancelling a card clears its target highlights")
	await process_frame
	await process_frame
	_check(battle.size == Vector2(1280, 800), "layout checks use the game's intended viewport")
	_check(battle._hand_scroll.get_global_rect().end.y <= 800, "complete battlefield keeps the hand inside the window: %s" % battle._hand_scroll.get_global_rect())
	battle.free()
	var deck := DeckBuilder.new()
	deck.setup("ember")
	root.add_child(deck)
	var minus := deck.find_children("*", "Button", true, false).filter(func(button): return button.has_meta("remove_card") and not button.disabled)
	minus[0].pressed.emit()
	_check(deck._picked.size() == 7 and deck._confirm_btn.disabled, "deck minus button removes a real card and gates confirmation")
	var plus := deck.find_children("*", "Button", true, false).filter(func(button): return button.has_meta("add_card") and not button.disabled)
	plus[0].pressed.emit()
	_check(deck._picked.size() == 8 and not deck._confirm_btn.disabled, "deck plus button restores a legal eight-card deck")
	deck.free()
	await process_frame

func _verify_duel() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	main._quick = true
	main._start_battle()
	var battle: BattleScreen = main._current
	battle.setup(ALLY, FOE, 20261005, {}, {}, true)
	_check(battle._unit_widgets.size() == 8 and _portrait_count(battle) == 8, "restarting a mounted battle replaces exactly eight portraits without orphaning old callbacks")
	var opening_buttons := battle._opening_layer.find_children("*", "Button", true, false).filter(func(button): return button.text == "确认起手")
	opening_buttons[0].pressed.emit()
	_check(battle.gs.phase == "main", "routed match leaves opening through its actual confirmation button")
	var balance_before := int(CollectionStore.load_collection().balance)
	var steps := 0
	while battle.gs.winner < 0 and steps < 500:
		var before := battle.gs.command_log.size()
		GameAI.take_action(battle.gs, battle.gs.action_player())
		var decisions := battle.gs.command_log.slice(before).filter(func(command): return command.c != "assault")
		_check(decisions.size() == 1, "AI presentation beat performs one decision, including nested assault effects")
		steps += 1
		await process_frame
	_check(battle.gs.winner >= 0, "four-versus-four duel reaches a result with stepwise AI")
	_check(battle.gs.command_log.any(func(command): return command.c == "basic_attack" or command.c == "play_card"), "full duel uses actual combat and cards")
	var expected_reward := 300 if battle.gs.winner == 0 else 150
	var expected_commands := battle.gs.command_log.size()
	# 结果页等待最后一次交战/出牌的演出结束，而非固定半秒切走。
	await create_timer(2.5).timeout
	_check(main._current is ResultScreen and main._current._commands.size() == expected_commands, "completed match routes to result with the full command log")
	_check(int(CollectionStore.load_collection().balance) == balance_before + expected_reward, "completed match grants its reward once")
	main._current.back_to_menu.emit()
	_check(main._current is MainMenuScreen, "result returns to the real main menu")
	main.free()
	await process_frame

func _portrait_count(battle: BattleScreen) -> int:
	var count := 0
	for box in [battle._enemy_reserve, battle._enemy_front, battle._ally_front, battle._ally_reserve]:
		count += box.get_children().filter(func(child): return child.has_meta("unit_uid")).size()
	return count
