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
const Sfx := preload("res://scripts/ui/sfx.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")
## Screen router: menu ↔ formation ↔ battle ↔ result

var _current: Control
var _lineup: Array = []
var _seed: int = 0
var _quick := false
var _formation_slot := 0
var _deck_return_codex := false


func _ready() -> void:
	get_window().min_size = Vector2i(1280, 800)
	self.theme = ThemeBuilder.build_theme()
	var saved_lineup: Array = SaveStore.get_lineup()
	if ContentLoader.valid_lineup(saved_lineup):
		_lineup = saved_lineup.duplicate()
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
	_current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _default_lineup() -> Array:
	return ContentLoader.recommended_lineup("classic")


func _show_menu() -> void:
	var menu := MainMenuScreen.new()
	menu.lineup = _lineup.duplicate()
	menu.lineup_selected.connect(func(ids: Array):
		_lineup = ids.duplicate()
		SaveStore.set_lineup(ids)
	)
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
	_deck_return_codex = false
	var form := FormationScreen.new()
	form.formation_slot = _formation_slot
	form.back_requested.connect(_show_menu)
	form.edit_deck.connect(func(unit_id: String):
		_lineup = form.selected_units()
		_formation_slot = form.formation_slot
		_show_deck_builder(unit_id)
	)
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
	_deck_return_codex = true
	var codex := CodexScreen.new()
	codex.back_requested.connect(_show_menu)
	codex.edit_deck.connect(_show_deck_builder)
	_swap(codex)


func _show_deck_builder(unit_id: String) -> void:
	var deck := DeckBuilderScreen.new()
	deck.setup(unit_id)
	deck.back_requested.connect(_return_from_deck)
	deck.deck_confirmed.connect(func(uid: String, card_ids: Array):
		SaveStore.set_deck(uid, card_ids)
		_return_from_deck()
	)
	_swap(deck)


func _return_from_deck() -> void:
	if _deck_return_codex: _show_codex()
	else: _show_formation()


func _show_settings() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "port"
	bg.dim = 0.55
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_stylebox_override("panel", ThemeBuilder.glass(0.94))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(ThemeBuilder.title_label("设置", 24))
	v.add_child(ThemeBuilder.section_label("音量"))
	v.add_child(_volume_control("music", "背景音乐"))
	v.add_child(_volume_control("sfx", "操作与战斗音效"))
	v.add_child(ThemeBuilder.hline())
	v.add_child(ThemeBuilder.section_label("操作提示"))
	v.add_child(ThemeBuilder.dim_label("Enter 结束回合 · 1–9 出牌 · Tab 查看角色", 13))
	v.add_child(ThemeBuilder.dim_label("P 放弃响应 · Esc 取消目标或关闭检视", 13))
	v.add_child(ThemeBuilder.dim_label("悬停查看完整牌文，拖动手牌或式神执行行动。", 13))
	var back := ThemeBuilder.rounded_rect_button("返回", Vector2(200, 44))
	back.pressed.connect(_show_menu)
	v.add_child(back)
	center.add_child(card)
	_swap(holder)
	Sfx.music("bgm_menu")


func _volume_control(channel: String, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := ThemeBuilder.label(title, 14)
	label.custom_minimum_size.x = 144
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = float(Sfx.settings()[channel]) * 100
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(210, 34)
	slider.set_meta("channel", channel)
	row.add_child(slider)
	var value := ThemeBuilder.label("%d%%" % int(slider.value), 14, ThemeBuilder.GOLD_BRIGHT)
	value.custom_minimum_size.x = 45
	row.add_child(value)
	slider.value_changed.connect(func(amount):
		Sfx.set_volume(channel, amount / 100.0)
		value.text = "%d%%" % int(amount)
	)
	return row


func _start_battle() -> void:
	_seed = int(Time.get_ticks_msec()) & 0x7fffffff
	var lineup_a: Array
	lineup_a = _lineup.duplicate() if ContentLoader.valid_lineup(_lineup) else _default_lineup()
	var lineup_b := _enemy_lineup(lineup_a)
	var battle := BattleScreen.new()
	var deck_a := ContentLoader.default_deck(lineup_a) if _quick else SaveStore.deck_definition(lineup_a)
	var deck_b := ContentLoader.default_deck(lineup_b)
	battle.setup(lineup_a, lineup_b, _seed, deck_a, deck_b, true)
	battle.back_requested.connect(_show_menu)
	battle.match_over.connect(_on_match_over)
	_swap(battle)


func _enemy_lineup(ally: Array) -> Array:
	return ContentLoader.opponent_lineup(ally, _seed)


func _on_match_over(winner: int, snapshot: Dictionary) -> void:
	var victory := winner == 0
	var summary := "种子 %d · 回合 %d · 命令日志 %d 条" % [
		int(snapshot.get("seed", 0)),
		int(snapshot.get("turn", 0)),
		int(snapshot.get("commands", 0)),
	]
	if _quick:
		summary += " · 快速对战（完整四式神阵容）"
	else:
		summary += " · 完整四对四编成"
	var reward := CollectionStore.grant_match_reward(victory)
	summary += " · 获得 %d 御札" % reward
	var result := ResultScreen.new()
	result.setup(victory, summary, snapshot.get("commandLog", []) if snapshot.get("commandLog") is Array else [])
	result.rematch.connect(_start_battle)
	result.back_to_menu.connect(_show_menu)
	_swap(result)
