extends SceneTree
## 全角色迁入验收：肖像、默认卡组、资料包入口、真实选角和覆盖全池的对局。

const ContentLoader := preload("res://scripts/content_loader.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const MainScene := preload("res://scenes/main_menu.tscn")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")

var _checks := 0
var _failures: Array = []

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(description)
		printerr("ROSTER_FAIL ", description)

func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
	var units := ContentLoader.playable_units()
	var ids: Array = []
	for unit in units:
		ids.append(unit.id)
		_check(ContentLoader.unit_def(unit.id) == unit, "%s lookup preserves the unit even when a card has the same ID" % unit.id)
		var starters := ContentLoader.starter_card_ids(unit.id)
		_check(starters.size() == 8, "%s has eight starter cards" % unit.id)
		var counts := {}
		for cid in starters:
			counts[cid] = int(counts.get(cid, 0)) + 1
			var card := ContentLoader.card_def(cid)
			_check(card.get("unitId") == unit.id and not card.get("token", false) and not card.get("skin", false), "%s is a constructible card for %s" % [cid, unit.id])
		for cid in counts:
			_check(counts[cid] <= int(ContentLoader.card_def(cid).get("deckLimit", 2)), "%s respects its deck limit" % cid)
		for field in ["art", "awakenedArt"]:
			var path := "res://" + str(unit.get(field, ""))
			_check(ResourceLoader.exists(path) and load(path) is Texture2D, "%s %s imports as a texture" % [unit.id, field])
		var face := UIWidgets.make_unit_panel(unit, Callable(), true)
		root.add_child(face)
		_check(face._texture != null, "%s renders its own portrait" % unit.id)
		face.free()

	var form := FormationScreen.new()
	root.add_child(form)
	await process_frame
	await process_frame
	_check(form._unit_list.get_child_count() == units.size(), "all migrated units are reachable in the formation roster")
	_check(form._unit_list.get_child(0).data.id == "yaodaoji", "the initial roster exposes migrated classic units before original demo units")
	_check(form._roster_count.text.begins_with("%d / %d" % [units.size(), units.size()]), "formation displays the full roster count")
	var shown := {}
	for face in form._unit_list.get_children(): shown[face.data.id] = true
	_check(ids.all(func(uid): return shown.has(uid)), "roster controls cover every content unit")
	for pack in ContentLoader.pack_ids():
		form._pack_picker.select(ContentLoader.pack_ids().find(pack))
		form._pack_picker.item_selected.emit(form._pack_picker.selected)
		_check(form._filtered_units().size() == ContentLoader.units_in_pack(pack).size(), "%s filter exposes all of its units" % pack)
	form._pack_picker.select(ContentLoader.pack_ids().find("classic"))
	form._pack_picker.item_selected.emit(form._pack_picker.selected)
	form._search.text = "妖刀姬"
	form._rebuild_unit_list()
	_check(form._filtered_units().size() == 1, "pack plus name search finds a migrated classic unit")
	form.set_preselect([])
	var first: Control = form._unit_list.get_child(0)
	(first.get_child(0) as Button).pressed.emit()
	_check(form.selected_units() == ["yaodaoji"] and form._focused == "yaodaoji", "real portrait click selects a classic unit and opens its cards")
	form.free()
	await process_frame

	var main := MainScene.instantiate()
	root.add_child(main)
	_check(main._lineup == ContentLoader.recommended_lineup("classic"), "fresh installs open with a classic lineup")
	var menu = main._current
	for i in range(1, menu._preset_picker.item_count):
		var pack := str(menu._preset_picker.get_item_metadata(i))
		menu._preset_picker.select(i)
		menu._preset_picker.item_selected.emit(i)
		_check(ContentLoader.valid_lineup(main._lineup), "%s preset supplies four distinct units with legal decks" % pack)
		_check(main._lineup == menu.lineup and SaveStore.get_lineup() == main._lineup, "%s selection reaches the router and persists" % pack)
		var count := mini(4, ContentLoader.units_in_pack(pack).size())
		_check(main._lineup.slice(0, count).all(func(uid): return str(ContentLoader.unit_def(uid).get("pack", "origin")) == pack), "%s preset actually uses its migrated units" % pack)
	await process_frame
	await process_frame
	_check(menu._lineup_faces.get_global_rect().end.x <= 1280 and menu._lineup_faces.get_global_rect().end.y <= 800, "main-menu lineup preview stays inside the viewport")
	var selected: Array = main._lineup.duplicate()
	var start_buttons: Array = menu.find_children("*", "Button", true, false).filter(func(button): return button.text == "开 始 对 弈")
	start_buttons[0].pressed.emit()
	main._current._ai_thinking = true
	_check(main._current.gs.player(0).units.map(func(unit): return unit.id) == selected, "main-menu start uses the selected expansion lineup")
	_check(main._current.gs.player(0).deck.size() + main._current.gs.player(0).hand.size() == 32, "routed expansion battle receives a complete 32-card deck")
	main._current.back_requested.emit()
	_check(main._current.lineup == selected, "returning to menu preserves the expansion lineup")
	main.free()
	await process_frame

	var opponents := {}
	for match_seed in range(101, 141):
		var ally := ContentLoader.recommended_lineup()
		var enemy := ContentLoader.opponent_lineup(ally, match_seed)
		_check(ContentLoader.valid_lineup(enemy) and not enemy.any(func(uid): return ally.has(uid)), "opponents are distinct from the player for seed %d" % match_seed)
		_check(enemy == ContentLoader.opponent_lineup(ally, match_seed), "same seed repeats the same opponent lineup")
		for uid in enemy: opponents[uid] = true
	_check(opponents.size() > 40, "opponents draw from the full pool, beyond the original eight")

	var covered := {}
	var completed := 0
	for offset in range(0, ids.size(), 4):
		var ally: Array = []
		for i in 4: ally.append(ids[(offset + i) % ids.size()])
		var match_seed := 20261005 + offset
		var gs := GameState.create(ally, ContentLoader.opponent_lineup(ally, match_seed), match_seed)
		# 回合开始被动可能额外抽牌/生成 token，因此只统计原始牌实例。
		var initial_ids := {}
		for instance in gs.player(0).deck + gs.player(0).hand:
			if str(instance.instanceId).begins_with("player-c"): initial_ids[instance.instanceId] = true
		_check(gs.player(0).units.size() == 4 and initial_ids.size() == 32, "full migrated lineup initializes at offset %d" % offset)
		var steps := 0
		while gs.winner < 0 and steps < 500:
			GameAI.take_turn(gs, gs.action_player())
			steps += 1
		_check(gs.winner >= 0, "migrated lineup completes a match at offset %d" % offset)
		if gs.winner >= 0: completed += 1
		for uid in ally: covered[uid] = true
	_check(covered.size() == units.size(), "every migrated unit has participated in a completed match")
	print("ROSTER checks=%d failures=%d units=%d portraits=%d matches=%d covered=%d opponents=%d" % [_checks, _failures.size(), units.size(), units.size() * 2, completed, covered.size(), opponents.size()])
	VerifySupport.cleanup_stores(fixture)
	if _failures.is_empty(): print("ROSTER_OK")
	quit(0 if _failures.is_empty() else 1)
