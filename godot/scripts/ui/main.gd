extends Control

const ContentLoader := preload("res://scripts/content_loader.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const MainMenuScreen := preload("res://scripts/ui/main_menu.gd")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ResultScreen := preload("res://scripts/ui/result_screen.gd")
const CodexScreen := preload("res://scripts/ui/codex_screen.gd")
const DeckBuilderScreen := preload("res://scripts/ui/deck_builder.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const CollectionScreen := preload("res://scripts/ui/collection_screen.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")
## Screen router: menu ↔ formation ↔ battle ↔ result

const DEFAULT_PLAYER := ["ember", "basalt", "lumen", "rime"]
const DEFAULT_ENEMY := ["storm", "basalt", "lumen", "ink"]
const FEATURED_PLAYER := ["ember", "lumen"]
const FEATURED_ENEMY := ["storm", "basalt"]

var _current: Control
var _lineup: Array = []
var _seed: int = 0
var _quick := false


func _ready() -> void:
	self.theme = ThemeBuilder.build_theme()
	var saved_lineup: Array = SaveStore.get_lineup()
	if saved_lineup.size() >= 4:
		_lineup = saved_lineup.slice(0, 4)
	else:
		_lineup = _default_lineup()
	_show_menu()


func _clear() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null


func _swap(node: Control) -> void:
	_clear()
	_current = node
	add_child(_current)


func _default_lineup() -> Array:
	var ids: Array = []
	for u in ContentLoader.playable_units():
		ids.append(u.id)
		if ids.size() >= 4:
			break
	if ids.size() < 4:
		ids = DEFAULT_PLAYER.duplicate()
	return ids


func _show_menu() -> void:
	var menu := MainMenuScreen.new()
	menu.start_quick_match.connect(func():
		_quick = true
		_start_battle()
	)
	menu.open_formation.connect(_show_formation)
	menu.open_codex.connect(_show_codex)
	menu.open_collection.connect(_show_collection)
	menu.open_settings.connect(_show_settings)
	menu.quit_requested.connect(func(): get_tree().quit())
	_swap(menu)


func _show_formation() -> void:
	var form := FormationScreen.new()
	form.back_requested.connect(_show_menu)
	form.edit_deck.connect(_show_deck_builder)
	form.confirmed.connect(func(unit_ids: Array):
		_lineup = unit_ids
		SaveStore.set_lineup(unit_ids)
		_quick = false
		_start_battle()
	)
	_swap(form)
	form.set_preselect(_lineup)


func _show_collection() -> void:
	var col := CollectionScreen.new()
	col.back_requested.connect(_show_menu)
	_swap(col)


func _show_codex() -> void:
	var codex := CodexScreen.new()
	codex.back_requested.connect(_show_menu)
	_swap(codex)


func _show_deck_builder(unit_id: String) -> void:
	var deck := DeckBuilderScreen.new()
	deck.setup(unit_id)
	deck.back_requested.connect(_show_formation)
	deck.deck_confirmed.connect(func(uid: String, card_ids: Array):
		SaveStore.set_deck(uid, card_ids)
		_show_formation()
	)
	_swap(deck)


func _show_settings() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.INK_1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(ThemeBuilder.title_label("设置", 24))
	v.add_child(ThemeBuilder.dim_label("主题：墨夜和风（深墨底 / 暖纸 / 金与朱）", 13))
	v.add_child(ThemeBuilder.dim_label("分辨率 1280×800 · GL Compatibility", 13))
	v.add_child(ThemeBuilder.dim_label("键盘：Enter 结束回合 · 1-9 出牌 · Tab 查看角色", 13))
	v.add_child(ThemeBuilder.dim_label("内容：content/content.json（编成 4 · 核心 30 · 鬼火 2）", 13))
	var back := ThemeBuilder.rounded_rect_button("返回", Vector2(200, 44))
	back.pressed.connect(_show_menu)
	v.add_child(back)
	center.add_child(card)
	_swap(holder)


func _start_battle() -> void:
	_seed = int(Time.get_ticks_msec()) & 0x7fffffff
	var lineup_a: Array
	var lineup_b: Array
	if _quick:
		lineup_a = FEATURED_PLAYER.duplicate()
		lineup_b = FEATURED_ENEMY.duplicate()
		# fall back if content lacks featured ids
		var have := {}
		for u in ContentLoader.playable_units():
			have[u.id] = true
		if not have.has("ember") or not have.has("lumen"):
			lineup_a = [_default_lineup()[0], _default_lineup()[1]]
		if not have.has("storm") or not have.has("basalt"):
			lineup_b = _enemy_lineup(lineup_a).slice(0, 2)
	else:
		lineup_a = _lineup.duplicate()
		lineup_b = _enemy_lineup(lineup_a)
	var battle := BattleScreen.new()
	var deck_a := SaveStore.deck_definition(lineup_a)
	var deck_b := SaveStore.deck_definition(lineup_b)
	battle.setup(lineup_a, lineup_b, _seed, deck_a, deck_b)
	battle.match_over.connect(_on_match_over)
	_swap(battle)


func _enemy_lineup(ally: Array) -> Array:
	var ids: Array = []
	for u in ContentLoader.playable_units():
		if not ally.has(u.id):
			ids.append(u.id)
		if ids.size() >= 4:
			break
	if ids.size() < 4:
		for u in ContentLoader.playable_units():
			if not ids.has(u.id):
				ids.append(u.id)
			if ids.size() >= 4:
				break
	if ids.size() < 2:
		ids = DEFAULT_ENEMY.duplicate()
	return ids


func _on_match_over(winner: int, snapshot: Dictionary) -> void:
	var victory := winner == 0
	var summary := "种子 %d · 回合 %d · 命令日志 %d 条" % [
		int(snapshot.get("seed", 0)),
		int(snapshot.get("turn", 0)),
		int(snapshot.get("commands", 0)),
	]
	if _quick:
		summary += " · 快速对战（精选 2 名/侧）"
	else:
		summary += " · 完整四对四编成"
	var reward := CollectionStore.grant_match_reward(victory)
	summary += " · 获得 %d 御札" % reward
	var result := ResultScreen.new()
	result.setup(victory, summary, snapshot.get("commandLog", []) if snapshot.get("commandLog") is Array else [])
	result.rematch.connect(_start_battle)
	result.back_to_menu.connect(_show_menu)
	_swap(result)
