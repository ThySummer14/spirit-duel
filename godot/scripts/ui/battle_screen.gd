class_name BattleScreen
extends Control

const ContentLoader := preload("res://scripts/content_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")
const DropZone := preload("res://scripts/ui/battle_drop_zone.gd")
const CardFace := preload("res://scripts/ui/card_face.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const HandFan := preload("res://scripts/ui/hand_fan.gd")
const BattleAim := preload("res://scripts/ui/battle_aim.gd")
const EffectCues := preload("res://scripts/ui/battle_effect_cues.gd")
const SpellEffect := preload("res://scripts/ui/battle_spell_effect.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
## 对战界面：上下准备区、中央交战阵台、左侧双方牌手、右侧结束回合与牌库、底部扇形手牌。
## 所有操作经 GameState 合法性检查；表现层从相邻快照与命令日志推导动画。

signal match_over(winner: int, gs: Dictionary)
signal back_requested

const PLAYER := 0
const AI := 1
const UNIT_SIZE := Vector2(108, 146)
const FRONT_SIZE := Vector2(116, 156)

var gs: GameState
var _enemy_reserve: Container
var _enemy_front: Container
var _ally_front: Container
var _ally_reserve: Container
var _cmd_bar: HFlowContainer
var _prompt_l: Label
var _hand_scroll: Control
var _hand_row: Control
var _log_label: RichTextLabel
var _ally_core: Label
var _enemy_core: Label
var _energy_l: Label
var _turn_l: Label
var _end_btn: Button
var _tooltip: Control
var _pending_target_card := -1
var _pending_target_card_def: Dictionary = {}
var _tab_index := 0
var _ai_thinking := false
var _enemy_hand: HBoxContainer
var _log_panel: PanelContainer
var _last_view: Dictionary = {}
var _opening_layer: Control
var _opening_cards: HBoxContainer
var _opening_status: Label
var _mulligan_selected: Array = []
var _ai_delay := 0.35
var _board: Control
var _effects: Control
var _selected_attacker := -1
var _enemy_target_btn: Button

var _stage: Control
var _enemy_plate: PanelContainer
var _ally_plate: PanelContainer
var _enemy_info: Label
var _ally_info: Label
var _enemy_realms: HFlowContainer
var _ally_realms: HFlowContainer
var _energy_orbs: Control
var _enemy_bar: Control
var _ally_bar: Control
var _clash: Control
var _deck_l: Label
var _enemy_deck_l: Label
var _choice_layer: Control
var _hand_widgets: Dictionary = {}
var _hand_rects: Dictionary = {}
var _unit_widgets: Dictionary = {}
var _last_command_count := 0
var _banner: Control
var _drag_kind := ""
var _drag_payload: Dictionary = {}
var _aim: Control
var _presentation_until := 0
var _presentation_ticket := 0
var _motion_tweens: Dictionary = {}
var _aim_pointer_viewport := Vector2.ZERO
var _aim_pointer_known := false


func setup(lineup_a: Array, lineup_b: Array, p_seed: int, deck_a: Dictionary = {}, deck_b: Dictionary = {}, opening_choice: bool = false) -> void:
	if gs != null:
		if gs.log_emitted.is_connected(_on_log): gs.log_emitted.disconnect(_on_log)
		if gs.state_changed.is_connected(_refresh): gs.state_changed.disconnect(_refresh)
		if gs.match_finished.is_connected(_on_finished): gs.match_finished.disconnect(_on_finished)
	gs = GameState.create(lineup_a, lineup_b, p_seed, deck_a, deck_b, opening_choice)
	gs.log_emitted.connect(_on_log)
	gs.state_changed.connect(_refresh)
	gs.match_finished.connect(_on_finished)
	_ai_thinking = false
	_ai_delay = 0.35
	_reset_view_cache()
	# 节点已入树时必须立刻刷一次，否则战场上/手牌空白
	if is_node_ready():
		if _opening_layer != null:
			_opening_layer.queue_free()
			_opening_layer = null
		_refresh()


func _reset_view_cache() -> void:
	_invalidate_aim_pointer()
	_cancel_battle_timers()
	_presentation_until = 0
	_presentation_ticket += 1
	for tw in _motion_tweens.values():
		if is_instance_valid(tw): tw.kill()
	_motion_tweens.clear()
	_drag_payload.clear()
	_drag_kind = ""
	_selected_attacker = -1
	_pending_target_card = -1
	_pending_target_card_def.clear()
	if is_instance_valid(_aim): _aim.visible = false
	if _choice_layer != null and is_instance_valid(_choice_layer): _choice_layer.queue_free()
	_choice_layer = null
	if _banner != null and is_instance_valid(_banner): _banner.queue_free()
	_banner = null
	if _effects != null:
		for effect in _effects.get_children():
			_effects.remove_child(effect)
			effect.queue_free()
	if _hand_row != null: _hand_row.reset()
	for w in _hand_widgets.values():
		if is_instance_valid(w):
			if w.get_parent() != null: w.get_parent().remove_child(w)
			w.queue_free()
	_hand_widgets.clear()
	for w in _unit_widgets.values():
		if is_instance_valid(w):
			if w.get_parent() != null: w.get_parent().remove_child(w)
			w.queue_free()
	_unit_widgets.clear()
	_hand_rects.clear()
	_hide_tooltip()
	_mulligan_selected.clear()
	_last_view = {}
	_last_command_count = gs.command_log.size() if gs != null else 0


# ——————————————————————————— 构建 ———————————————————————————

func _ready() -> void:
	get_window().mouse_exited.connect(_invalidate_aim_pointer)
	get_window().focus_exited.connect(_invalidate_aim_pointer)
	resized.connect(_invalidate_aim_pointer)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "battle"
	bg.dim = 0.02
	bg.tint = Color.WHITE
	bg.vignette = 0.12
	bg.motes = 12
	bg.mote_color = Color(0.85, 0.95, 1.0)
	add_child(bg)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var header := _build_top_bar()
	_stage.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 170
	header.offset_right = -24
	header.offset_top = 8
	_stage.add_child(_build_left_column())
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.offset_left = 178
	_board.offset_right = -160
	_board.offset_top = 42
	_board.offset_bottom = -260
	_stage.add_child(_board)
	_enemy_reserve = _make_row("reserve", "对方准备区", ThemeBuilder.FOE, UNIT_SIZE.y)
	_place_zone(_enemy_reserve, Rect2(0, 0, 1, 0.38), true)
	_enemy_front = _make_row("front", "对方前线", ThemeBuilder.FOE, FRONT_SIZE.y)
	_place_zone(_enemy_front, Rect2(0.56, 0.32, 0.23, 0.34), true)
	_ally_front = _make_row("front", "己方前线", ThemeBuilder.ALLY, FRONT_SIZE.y)
	_place_zone(_ally_front, Rect2(0.25, 0.38, 0.23, 0.34), false)
	_ally_reserve = _make_row("reserve", "己方准备区", ThemeBuilder.ALLY, UNIT_SIZE.y)
	_place_zone(_ally_reserve, Rect2(0, 0.62, 1, 0.38), false)
	_clash = Control.new()
	_clash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_clash)
	_clash.visible = false
	var prompt := _build_prompt()
	_stage.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_left = 205
	prompt.offset_right = -205
	prompt.offset_top = -267
	prompt.offset_bottom = -239
	prompt.z_index = 12
	_stage.add_child(_build_right_column())
	_hand_scroll = Control.new()
	_hand_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_scroll.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hand_scroll.offset_top = -260
	_stage.add_child(_hand_scroll)
	_hand_row = HandFan.new()
	_hand_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand_row.offset_left = 180
	_hand_row.offset_right = -180
	_hand_scroll.add_child(_hand_row)
	_log_panel = _build_side_panel()
	_log_panel.visible = false
	add_child(_log_panel)
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_log_panel.offset_left = -360
	_log_panel.offset_right = -14
	_log_panel.offset_top = 56
	_log_panel.offset_bottom = -210
	_effects = Control.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_effects)
	_aim = BattleAim.new()
	_aim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aim.visible = false
	add_child(_aim)
	Sfx.music("bgm_battle")
	if gs != null:
		_last_command_count = gs.command_log.size()
		_refresh()
		for entry in gs.log: _on_log(str(entry.text), str(entry.tone))
		_check_auto_ai()


func _build_top_bar() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 36)
	header.add_theme_constant_override("separation", 8)
	var back := ThemeBuilder.ghost(Button.new())
	back.text = "‹ 主城"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(mid)
	var pill := PanelContainer.new()
	var sb := ThemeBuilder.glass(0.7, Color(0.82, 0.68, 0.4, 0.35), 18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	pill.add_theme_stylebox_override("panel", sb)
	mid.add_child(pill)
	_turn_l = ThemeBuilder.label("", 15, ThemeBuilder.PAPER)
	_turn_l.add_theme_font_override("font", ThemeBuilder.display_font())
	pill.add_child(_turn_l)
	var log_button := ThemeBuilder.ghost(Button.new())
	log_button.text = "战报"
	log_button.pressed.connect(func():
		_log_panel.visible = not _log_panel.visible
		Sfx.play("ui_click", 0.6)
	)
	header.add_child(log_button)
	var commands := ThemeBuilder.ghost(Button.new())
	commands.text = "命令"
	commands.pressed.connect(_show_command_log)
	header.add_child(commands)
	return header


func _plate(accent: Color) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	plate.set_meta("accent", accent)
	return plate


func _crest(accent: Color, glyph: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(46, 46)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := ThemeBuilder.display_font()
	c.draw.connect(func():
		var center := c.size * 0.5
		c.draw_circle(center, 23, Color(0.03, 0.04, 0.07, 0.9))
		c.draw_circle(center, 19, accent.darkened(0.55))
		c.draw_arc(center, 22, 0, TAU, 40, accent, 2.0, true)
		c.draw_arc(center, 17, 0, TAU, 40, Color(accent, 0.4), 1.0, true)
		c.draw_string(font, Vector2(0, center.y + 8), glyph, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 22, accent.lightened(0.4))
	)
	return c


func _hp_bar(accent: Color) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_meta("ratio", 1.0)
	bar.draw.connect(func():
		var ratio := float(bar.get_meta("ratio", 1.0))
		var r := Rect2(Vector2.ZERO, bar.size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.08)
		bg.set_corner_radius_all(3)
		bar.draw_style_box(bg, r)
		var fg := StyleBoxFlat.new()
		fg.bg_color = accent if ratio > 0.34 else ThemeBuilder.DANGER
		fg.set_corner_radius_all(3)
		if ratio > 0.0: bar.draw_style_box(fg, Rect2(Vector2.ZERO, Vector2(bar.size.x * ratio, bar.size.y)))
	)
	return bar


func _build_left_column() -> Control:
	var col := Control.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_plate = _plate(ThemeBuilder.FOE)
	_ally_plate = _plate(ThemeBuilder.ALLY)
	for pair in [[_enemy_plate, AI], [_ally_plate, PLAYER]]:
		var plate: PanelContainer = pair[0]
		var enemy: bool = pair[1] == AI
		col.add_child(plate)
		plate.position = Vector2(10, 8)
		plate.size = Vector2(146, 142)
		if not enemy:
			plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
			plate.offset_top = -168
			plate.offset_bottom = -26
			plate.offset_left = 10
			plate.offset_right = 156
		var area := Control.new()
		area.custom_minimum_size = Vector2(146, 142)
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(area)
		var units: Array = gs.player(AI if enemy else PLAYER).units if gs != null else []
		var unit: Dictionary = units[0] if not units.is_empty() else ContentLoader.unit_def("ember")
		var portrait := UIWidgets.unit_token(unit, Callable(), Vector2(104, 104), "circle")
		area.add_child(portrait)
		portrait.position = Vector2(5, 8)
		portrait.size = Vector2(104, 104)
		var halo := Control.new()
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.size = Vector2(118, 118)
		area.add_child(halo)
		halo.draw.connect(func():
			halo.draw_arc(Vector2(58, 60), 54, -2.8, 2.5, 48, Color("b0a9d8"), 4, true)
			halo.draw_arc(Vector2(58, 60), 59, -1.4, 1.7, 40, Color(0.68, 0.83, 0.92, 0.6), 2, true)
		)
		var hp := ThemeBuilder.bold_label("30", 38, Color("bd353a"))
		ThemeBuilder.outline(hp, 3, Color("f1edd5"))
		hp.position = Vector2(86, 76)
		area.add_child(hp)
		var info := ThemeBuilder.label("", 11, ThemeBuilder.PAPER)
		info.visible = false
		area.add_child(info)
		var bar := _hp_bar(ThemeBuilder.FOE if enemy else ThemeBuilder.ALLY)
		bar.visible = false
		area.add_child(bar)
		var realms := HFlowContainer.new()
		realms.position = Vector2(3, 145)
		realms.size = Vector2(158, 0)
		realms.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(realms)
		if enemy:
			_enemy_core = hp
			_enemy_bar = bar
			_enemy_info = info
			_enemy_realms = realms
		else:
			_ally_core = hp
			_ally_bar = bar
			_ally_info = info
			_ally_realms = realms
	var target := Button.new()
	_enemy_target_btn = target
	target.flat = true
	target.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		target.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	target.pressed.connect(_on_core_clicked)
	target.set_drag_forwarding(Callable(), func(_pos, payload): return _can_drop_command(payload, "ai-avatar"), func(_pos, payload): _drop_command(payload, "ai-avatar"))
	_enemy_plate.add_child(target)
	_energy_orbs = Control.new()
	_energy_orbs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_energy_orbs.offset_left = 143
	_energy_orbs.offset_right = 249
	_energy_orbs.offset_top = -106
	_energy_orbs.offset_bottom = -74
	_energy_orbs.set_meta("energy", 0)
	_energy_orbs.set_meta("max", 2)
	_energy_orbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_orbs.draw.connect(_draw_energy)
	col.add_child(_energy_orbs)
	_energy_l = ThemeBuilder.label("", 11, Color("eeeac1"))
	ThemeBuilder.outline(_energy_l, 2, Color("45657a"))
	_energy_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_energy_l.offset_left = 146
	_energy_l.offset_right = 252
	_energy_l.offset_top = -66
	_energy_l.offset_bottom = -47
	col.add_child(_energy_l)
	return col


func _build_right_column() -> Control:
	var col := Control.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_hand = HBoxContainer.new()
	_enemy_hand.add_theme_constant_override("separation", -21)
	_enemy_hand.anchor_left = 0.70
	_enemy_hand.anchor_right = 0.70
	_enemy_hand.offset_top = 10
	col.add_child(_enemy_hand)
	_enemy_deck_l = ThemeBuilder.label("", 10, Color("ddeae7"))
	ThemeBuilder.outline(_enemy_deck_l, 2, Color("426478"))
	_enemy_deck_l.anchor_left = 0.70
	_enemy_deck_l.offset_top = 87
	col.add_child(_enemy_deck_l)
	_end_btn = Button.new()
	_end_btn.text = "结束
回合"
	_end_btn.custom_minimum_size = Vector2(102, 102)
	_end_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_end_btn.offset_left = -121
	_end_btn.offset_right = -19
	_end_btn.offset_top = -58
	_end_btn.offset_bottom = 44
	_end_btn.focus_mode = Control.FOCUS_NONE
	_end_btn.add_theme_font_override("font", ThemeBuilder.heavy_display_font())
	_end_btn.add_theme_font_size_override("font_size", 22)
	_style_seal(false)
	_end_btn.pressed.connect(_on_end_turn)
	col.add_child(_end_btn)
	for enemy in [true, false]:
		var pile := Control.new()
		pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pile.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		pile.offset_left = -92
		pile.offset_right = -8
		pile.offset_top = -235 if enemy else 108
		pile.offset_bottom = -103 if enemy else 240
		col.add_child(pile)
		for i in 3:
			var back := CardFace.new()
			back.face_down = true
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			back.size = Vector2(62, 91)
			back.position = Vector2(12 + i * 9, i * 10)
			back.pivot_offset = back.size * 0.5
			back.rotation = deg_to_rad(-22 + i * 10)
			pile.add_child(back)
	_deck_l = ThemeBuilder.label("", 11, Color("eff0dd"))
	ThemeBuilder.outline(_deck_l, 2, Color("385467"))
	_deck_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_deck_l.offset_left = -94
	_deck_l.offset_top = 231
	_deck_l.offset_right = -10
	col.add_child(_deck_l)
	return col


func _style_seal(active: bool, urge: bool = false) -> void:
	var fill := Color("7860a7") if active else Color(0.31, 0.35, 0.46, 0.82)
	var rim := Color("c4b5e3") if active else Color("8d9cbd")
	var normal := ThemeBuilder.panel(fill, rim, 54, 3)
	normal.shadow_color = Color(0.7, 0.67, 1.0, 0.45) if urge else Color(0, 0, 0, 0.45)
	normal.shadow_size = 22 if urge else 10
	var hover := normal.duplicate()
	hover.bg_color = fill.lightened(0.12)
	hover.shadow_color = Color(0.75, 0.71, 1.0, 0.55)
	hover.shadow_size = 20
	var pressed := normal.duplicate()
	pressed.bg_color = fill.darkened(0.2)
	var disabled := ThemeBuilder.panel(Color(0.1, 0.11, 0.15, 0.82), Color(0.35, 0.37, 0.45, 0.5), 54, 2)
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["hover_pressed", pressed]]:
		_end_btn.add_theme_stylebox_override(pair[0], pair[1])
	_end_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_end_btn.add_theme_color_override(key, Color("fff1d2"))
	_end_btn.add_theme_color_override("font_disabled_color", ThemeBuilder.TEXT_FAINT)


func _build_prompt() -> Control:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.custom_minimum_size = Vector2(0, 28)
	var pill := PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 18
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", sb)
	wrap.add_child(pill)
	_cmd_bar = HFlowContainer.new()
	_cmd_bar.add_theme_constant_override("h_separation", 10)
	_cmd_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	pill.add_child(_cmd_bar)
	return wrap


func _make_row(style: String, title: String, accent: Color, _height: float) -> Container:
	var row := DropZone.new()
	row.style = style
	row.title = title
	row.accent = accent
	row.set_meta("title", title)
	var is_front := style == "front"
	row.can_drop = func(payload): return is_front and _can_drop_command(payload, null)
	row.on_drop = func(payload): _drop_command(payload, null)
	return row


func _place_zone(zone: Control, area: Rect2, enemy: bool) -> void:
	_board.add_child(zone)
	zone.anchor_left = area.position.x
	zone.anchor_top = area.position.y
	zone.anchor_right = area.end.x
	zone.anchor_bottom = area.end.y
	zone.set_meta("enemy", enemy)


func _build_side_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := ThemeBuilder.glass(0.94, Color(0.82, 0.68, 0.4, 0.45), 12)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := ThemeBuilder.title_label("对局战报", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := ThemeBuilder.ghost(Button.new(), 12)
	close.text = "收起"
	close.pressed.connect(func(): panel.visible = false)
	head.add_child(close)
	v.add_child(ThemeBuilder.hline())
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", 13)
	_log_label.add_theme_constant_override("line_separation", 5)
	v.add_child(_log_label)
	return panel


func _draw_clash() -> void:
	var c := _clash.size * 0.5
	var both := gs != null and gs.front_index(PLAYER) >= 0 and gs.front_index(AI) >= 0
	var col := Color(1, 0.86, 0.6, 0.85 if both else 0.35)
	_clash.draw_circle(c, 34, Color(0.03, 0.04, 0.08, 0.55))
	_clash.draw_arc(c, 34, 0, TAU, 48, col, 1.5, true)
	_clash.draw_arc(c, 28, 0, TAU, 48, Color(col, col.a * 0.4), 1.0, true)
	_clash.draw_line(c + Vector2(-20, -20), c + Vector2(20, 20), col, 3.0, true)
	_clash.draw_line(c + Vector2(20, -20), c + Vector2(-20, 20), col, 3.0, true)
	var font := ThemeBuilder.display_font()
	_clash.draw_string(font, Vector2(0, c.y + 56), "交 战", HORIZONTAL_ALIGNMENT_CENTER, _clash.size.x, 13, Color(col, 0.8))


func _draw_energy() -> void:
	var e := int(_energy_orbs.get_meta("energy", 0))
	var m := int(_energy_orbs.get_meta("max", 2))
	for i in m:
		var c := Vector2(12 + i * 26, 15)
		var lit := i < e
		var flame := PackedVector2Array([c + Vector2(-8, -1), c + Vector2(-3, -13), c + Vector2(0, -7), c + Vector2(4, -14), c + Vector2(8, -1)])
		if lit:
			_energy_orbs.draw_circle(c, 13, Color(1.0, 0.92, 0.5, 0.22))
			_energy_orbs.draw_colored_polygon(flame, Color("c5bd59"))
			_energy_orbs.draw_circle(c, 8, Color("fff6a5"))
			_energy_orbs.draw_circle(c + Vector2(-2, -2), 3, Color(1, 1, 1, 0.6))
		else:
			_energy_orbs.draw_circle(c, 8, Color(0.1, 0.12, 0.18, 0.9))
			_energy_orbs.draw_arc(c, 8, 0, TAU, 24, Color(0.5, 0.7, 0.9, 0.4), 1.0, true)


# ——————————————————————————— 刷新 ———————————————————————————

func _on_log(text: String, tone: String) -> void:
	if _log_label == null: return
	var color := ThemeBuilder.TEXT_DIM
	match tone:
		"danger":
			color = ThemeBuilder.DANGER_SOFT
		"success":
			color = ThemeBuilder.OK
		"card":
			color = ThemeBuilder.GOLD
		"turn":
			color = ThemeBuilder.INFO
	_log_label.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


func _clear_box(box: Container) -> void:
	if box == null or not is_instance_valid(box):
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _refresh() -> void:
	if gs == null or _stage == null:
		return
	_cancel_target_selection()
	_selected_attacker = -1
	var p := gs.player(PLAYER)
	var e := gs.player(AI)
	_ally_core.text = "%d" % int(p.avatarHp)
	_enemy_core.text = "%d" % int(e.avatarHp)
	_ally_bar.set_meta("ratio", clampf(float(p.avatarHp) / maxf(1.0, float(p.get("maxAvatarHp", 30))), 0.0, 1.0))
	_enemy_bar.set_meta("ratio", clampf(float(e.avatarHp) / maxf(1.0, float(e.get("maxAvatarHp", 30))), 0.0, 1.0))
	_ally_bar.queue_redraw()
	_enemy_bar.queue_redraw()
	_energy_l.text = "鬼火 %d/%d" % [int(p.energy), int(p.maxEnergy)]
	_energy_orbs.set_meta("energy", int(p.energy))
	_energy_orbs.set_meta("max", int(p.maxEnergy))
	_energy_orbs.queue_redraw()
	var my_turn := gs.current_player == PLAYER
	_turn_l.text = "第 %d 轮 · %s" % [gs.get_round(), "你的回合" if my_turn else "对手回合"]
	_turn_l.add_theme_color_override("font_color", ThemeBuilder.GOLD_BRIGHT if my_turn else ThemeBuilder.FOE.lightened(0.35))
	_ally_info.text = "手牌 %d · 牌库 %d" % [p.hand.size(), p.deck.size()]
	_enemy_info.text = "手牌 %d · 牌库 %d" % [e.hand.size(), e.deck.size()]
	_deck_l.text = "牌库\n%d" % p.deck.size()
	_enemy_deck_l.text = "对手手牌 %d · 牌库 %d" % [e.hand.size(), e.deck.size()]
	_fill_realms(_ally_realms, p)
	_fill_realms(_enemy_realms, e)

	var previous := _last_view
	_last_view = gs.snapshot().duplicate(true)
	# 表现层保存等待中的帧，响应或占卜结束时仍可识别真正施法者。
	_last_view["presentationStack"] = gs.resolution_stack.duplicate(true)
	var commands: Array = gs.command_log.slice(_last_command_count)
	_last_command_count = gs.command_log.size()
	if not previous.is_empty():
		_hold_presentation(_presentation_duration(previous, _last_view, commands))
	_fill_units(_enemy_reserve, AI, false)
	_fill_units(_enemy_front, AI, true)
	_fill_units(_ally_front, PLAYER, true)
	_fill_units(_ally_reserve, PLAYER, false)
	_fill_hand()
	_fill_command_bar()
	_fill_enemy_hand(e.hand.size())
	_clash.queue_redraw()
	if gs.phase == "opening":
		if _opening_layer == null: _show_opening()
	elif _opening_layer != null:
		var layer := _opening_layer
		_opening_layer = null
		var tw := layer.create_tween()
		tw.tween_property(layer, "modulate:a", 0.0, 0.25)
		tw.tween_callback(layer.queue_free)
		_show_turn_banner(gs.current_player == PLAYER)
	if not previous.is_empty(): _present_changes.call_deferred(previous, _last_view, commands, gs)


func _fill_realms(box: HFlowContainer, p: Dictionary) -> void:
	_clear_box(box)
	for realm in p.get("realms", []):
		var chip := ThemeBuilder.chip("幻境 · %s %d" % [realm.get("name", "?"), int(realm.get("hp", 0))], ThemeBuilder.TYPE_REALM)
		chip.tooltip_text = "幻境耐久 %d%s" % [int(realm.get("hp", 0)), ("，倒计时 %d" % int(realm.countdown)) if int(realm.get("countdown", 0)) > 0 else ""]
		box.add_child(chip)


func _fill_enemy_hand(count: int) -> void:
	var shown := mini(count, 8)
	while _enemy_hand.get_child_count() > shown:
		var last := _enemy_hand.get_child(_enemy_hand.get_child_count() - 1)
		_enemy_hand.remove_child(last)
		last.queue_free()
	while _enemy_hand.get_child_count() < shown:
		var back := CardFace.new()
		back.face_down = true
		back.custom_minimum_size = Vector2(43, 70)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_hand.add_child(back)
	var n := _enemy_hand.get_child_count()
	for i in n:
		var back: Control = _enemy_hand.get_child(i)
		back.pivot_offset = Vector2(18, 54)
		back.rotation = deg_to_rad((i - (n - 1) * 0.5) * 5.0)


func _fill_units(box: Container, p_idx: int, front_only: bool) -> void:
	if box == null or gs == null:
		return
	var p := gs.player(p_idx)
	var wanted: Array = []
	for i in p.units.size():
		var u: Dictionary = p.units[i]
		if (int(u.get("front", 0)) == 1) == front_only:
			wanted.append(i)
	# 移除不再属于本行的旧节点（式神移动时会在另一行复用）
	for child in box.get_children():
		if child is Label:
			box.remove_child(child)
			child.queue_free()
		elif not wanted.has(int(child.get_meta("unit_index", -1))) or int(child.get_meta("player", -1)) != p_idx:
			child.set_meta("flip_from", child.global_position)
			box.remove_child(child)
	for order in wanted.size():
		var i: int = wanted[order]
		var u: Dictionary = p.units[i]
		var uid := str(u.uid)
		var panel: Control = _unit_widgets.get(uid)
		if panel == null or not is_instance_valid(panel):
			panel = UIWidgets.make_unit_panel(u, _on_unit_clicked.bind(p_idx, i), true, false)
			panel.side = p_idx
			panel.set_meta("player", p_idx)
			panel.set_meta("unit_index", i)
			panel.hover_changed.connect(func(on): _on_unit_hover(on, p_idx, i))
			_unit_widgets[uid] = panel
		panel.data = u
		panel.refresh_art()
		if panel.get_parent() != box:
			if panel.get_parent() != null:
				panel.set_meta("flip_from", panel.global_position)
				panel.get_parent().remove_child(panel)
			elif panel.is_inside_tree() == false and panel.has_meta("flip_from"):
				pass
			box.add_child(panel)
		box.move_child(panel, order)
		panel.custom_minimum_size = FRONT_SIZE if front_only else UNIT_SIZE
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.drag_payload = {"kind": "unit", "unit": i} if not _input_locked() and p_idx == PLAYER and gs.can_basic_attack(PLAYER, i).ok and gs.pending_choice.is_empty() and gs.response_window.is_empty() else {}
		var highlight := not _input_locked() and p_idx == PLAYER and gs.current_player == PLAYER and gs.is_upgrade_pending(PLAYER) and gs.can_level_up(PLAYER, i) and gs.response_window.is_empty() and gs.pending_choice.is_empty()
		panel.selected = highlight
		panel.set_playable(not highlight and not panel.drag_payload.is_empty())
		panel.drop_check = func(payload): return _can_drop_command(payload, str(u.uid))
		panel.drop_action = func(payload): _drop_command(payload, str(u.uid))
		panel.queue_redraw()
	if wanted.is_empty() and box.get("style") == "reserve":
		var empty := ThemeBuilder.label("—", 12, Color(1, 1, 1, 0.25))
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(empty)


func _fill_hand() -> void:
	if gs == null or _hand_row == null:
		return
	var p := gs.player(PLAYER)
	# 记录旧位置，用于打出牌的飞出动画
	for key in _hand_widgets:
		var w: Control = _hand_widgets[key]
		if is_instance_valid(w) and w.is_inside_tree():
			_hand_rects[key] = Rect2(w.global_position, w.size)
	var keep := {}
	for i in p.hand.size():
		var inst: Dictionary = p.hand[i]
		var key := "%s|%s" % [inst.instanceId, inst.definitionId]
		keep[key] = true
		var card := ContentLoader.card_def(inst.definitionId)
		var check := _hand_playability(i)
		var block_reason := "" if check.ok else _short_reason(str(check.get("reason", "")))
		var widget: Control = _hand_widgets.get(key)
		if widget == null or not is_instance_valid(widget):
			var iid := str(inst.instanceId)
			widget = UIWidgets.make_hand_card(card, check.ok, func(_i, c): _on_hand_clicked(_hand_index_of(iid), c), i, block_reason)
			widget.hover_changed.connect(func(on): _on_hand_hover(on, widget))
			var from = null
			if not _last_view.is_empty() and gs.phase != "opening":
				from = _deck_l.global_position + Vector2(-30, -40)
				Sfx.play("card_draw", 0.7)
			_hand_row.add_card(widget, i, from)
			_hand_widgets[key] = widget
		else:
			_hand_row.move_child(widget, i)
		widget.enabled = check.ok
		widget.set_playable(check.ok)
		widget.set_meta("block_reason", block_reason)
		widget.set_meta("hand_index", i)
		widget.drag_payload = {"kind": "card", "hand": i} if check.ok else {}
		for child in widget.get_children():
			if child is Button: child.disabled = not check.ok
		widget.queue_redraw()
	for key in _hand_widgets.keys():
		if not keep.has(key):
			var gone: Control = _hand_widgets[key]
			_hand_widgets.erase(key)
			if is_instance_valid(gone):
				if gone.hovered: _hide_tooltip()
				_hand_row.remove_child(gone)
				gone.queue_free()
	_hand_row.relayout()


func _hand_index_of(instance_id: String) -> int:
	var hand: Array = gs.player(PLAYER).hand
	for i in hand.size():
		if str(hand[i].instanceId) == instance_id: return i
	return -1


func _short_reason(reason: String) -> String:
	if reason.contains("升级阶段") or reason.contains("升勾"): return "需先完成本回合升勾"
	if reason.contains("勾玉不足"): return "所属式神勾玉不足"
	if reason.contains("完成行动") or reason.contains("回合"): return "现在是对手的回合"
	if reason.contains("鬼火不足"): return "鬼火不足"
	if reason.contains("气绝"): return "所属式神已气绝"
	return reason


func _hand_playability(index: int) -> Dictionary:
	if _input_locked(): return {"ok": false, "reason": "动作结算中"}
	var card := gs.hand_card_def(PLAYER, index)
	var targets: Array = [null] if card.get("target", "auto") == "auto" else gs.valid_targets(PLAYER, card)
	for target in targets:
		var check := gs.can_play_card(PLAYER, index, target)
		if check.ok:
			return check
	return gs.can_play_card(PLAYER, index, null)


func _cancel_target_selection() -> void:
	_pending_target_card = -1
	_pending_target_card_def = {}
	if is_node_ready(): _update_selection_highlights()


func _update_selection_highlights() -> void:
	if gs == null or _enemy_reserve == null: return
	var targets: Array = gs.valid_targets(PLAYER, _pending_target_card_def) if _pending_target_card >= 0 else []
	if _selected_attacker >= 0 and _pending_target_card < 0:
		var front := gs.front_unit(AI)
		if not front.is_empty() and _can_drop_command({"kind": "unit", "unit": _selected_attacker}, str(front.uid)):
			targets.append(str(front.uid))
	var upgrade_mode := _pending_target_card < 0 and _selected_attacker < 0 and gs.is_upgrade_pending(PLAYER) and gs.response_window.is_empty() and gs.pending_choice.is_empty()
	for box in [_enemy_reserve, _enemy_front, _ally_front, _ally_reserve]:
		for face in box.get_children():
			if not face is CardFace: continue
			var idx := int(face.get_meta("unit_index", -1))
			var is_upgrade := int(face.get_meta("player", -1)) == PLAYER and gs.can_level_up(PLAYER, idx)
			face.selected = not _input_locked() and (targets.has(str(face.get_meta("unit_uid", ""))) or (upgrade_mode and is_upgrade) or (int(face.get_meta("player", -1)) == PLAYER and idx == _selected_attacker))
			face.set_process(face.selected or face.playable)
			face.queue_redraw()
	if _enemy_target_btn != null:
		var core_selected := _selected_attacker >= 0 and _can_drop_command({"kind": "unit", "unit": _selected_attacker}, "ai-avatar")
		_set_plate_glow(_enemy_plate, core_selected)
	for face in _hand_widgets.values():
		if is_instance_valid(face):
			face.selected = _pending_target_card >= 0 and int(face.get_meta("hand_index", -1)) == _pending_target_card
			face.set_process(face.selected or face.playable)
			face.queue_redraw()


func _set_plate_glow(plate: PanelContainer, on: bool) -> void:
	if not on:
		plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	var sb := ThemeBuilder.panel(Color(0.65, 0.9, 0.87, 0.04), Color("e0edb9"), 70, 2)
	sb.shadow_color = Color(0.7, 0.85, 1.0, 0.35)
	sb.shadow_size = 12
	plate.add_theme_stylebox_override("panel", sb)


func _prompt(text: String, color: Color = ThemeBuilder.PAPER) -> void:
	_prompt_l = ThemeBuilder.label(text, 12, color)
	ThemeBuilder.outline(_prompt_l, 2, Color("405d73"))
	_prompt_l.add_theme_font_override("font", ThemeBuilder.medium_font())
	_prompt_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cmd_bar.add_child(_prompt_l)


func _small_button(text: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	if primary: ThemeBuilder.primary(b, 14)
	else: ThemeBuilder.ghost(b, 13)
	b.pressed.connect(action)
	_cmd_bar.add_child(b)
	return b


func _fill_command_bar() -> void:
	if _cmd_bar == null:
		return
	_clear_box(_cmd_bar)
	if gs == null:
		return
	var my_turn := gs.current_player == PLAYER
	_end_btn.disabled = _input_locked() or not my_turn or gs.winner >= 0 or gs.phase == "opening" or not gs.pending_choice.is_empty() or not gs.response_window.is_empty()
	_end_btn.text = "结束\n回合" if my_turn else "对手\n回合"
	_style_seal(not _end_btn.disabled, not _end_btn.disabled and not _has_any_action())
	_update_choice_layer()
	if gs.winner >= 0:
		_prompt("对局结束", ThemeBuilder.GOLD_BRIGHT)
		return
	if gs.phase == "opening":
		_prompt("起手抉择中…", ThemeBuilder.TEXT_DIM)
		return
	if _input_locked():
		_prompt("动作结算中…", ThemeBuilder.TEXT_DIM)
		return
	if not gs.pending_choice.is_empty():
		if int(gs.pending_choice.get("playerIndex", -1)) == PLAYER:
			_prompt("占卜：选择一张牌置于牌库顶", ThemeBuilder.GOLD_BRIGHT)
		else:
			_prompt("对手正在占卜…", ThemeBuilder.TEXT_DIM)
		return
	if not gs.response_window.is_empty():
		var mine := int(gs.response_window.get("playerIndex", -1)) == PLAYER
		if mine:
			if _pending_target_card >= 0:
				_prompt("选择「%s」的目标 · Esc 取消" % _pending_target_card_def.get("name", ""), ThemeBuilder.WARN)
				_small_button("取消", _cancel_and_refresh_bar)
			else:
				_prompt("响应时机 · 可打出发光的响应牌", ThemeBuilder.WARN)
			var pass_btn := _small_button("放弃响应 (P)", _on_pass_response, true)
			pass_btn.disabled = false
		else:
			_prompt("等待对手响应…", ThemeBuilder.TEXT_DIM)
		return
	if not my_turn:
		_prompt("对手行动中…", ThemeBuilder.FOE.lightened(0.4))
		return
	if _pending_target_card >= 0:
		_prompt("选择「%s」的目标 · Esc 取消" % _pending_target_card_def.get("name", ""), ThemeBuilder.WARN)
		_small_button("取消", _cancel_and_refresh_bar)
		return
	if _selected_attacker >= 0:
		_prompt("点击敌方前线或敌方核心出击", ThemeBuilder.WARN)
		_small_button("取消", _cancel_and_refresh_bar)
		return
	if gs.is_upgrade_pending(PLAYER):
		var names: PackedStringArray = PackedStringArray()
		for i in gs.player(PLAYER).units.size():
			if gs.can_level_up(PLAYER, i):
				names.append(str(gs.player(PLAYER).units[i].get("name", "?")))
		_prompt("点选发光式神，提升 1 勾玉", ThemeBuilder.GOLD_BRIGHT)
		return
	if _has_any_action():
		_prompt("打出发光手牌，或拖动式神到交战区出击", ThemeBuilder.PAPER)
	else:
		_prompt("已无可用行动 · 结束回合", ThemeBuilder.GOLD_BRIGHT)


func _cancel_and_refresh_bar() -> void:
	_cancel_target_selection()
	_selected_attacker = -1
	_update_selection_highlights()
	_fill_command_bar()
	Sfx.play("ui_click", 0.5)


func _has_any_action() -> bool:
	if gs == null or gs.current_player != PLAYER: return false
	for i in gs.player(PLAYER).hand.size():
		if _hand_playability(i).ok: return true
	for i in gs.player(PLAYER).units.size():
		if gs.can_basic_attack(PLAYER, i).ok: return true
	return false


## 占卜选择：居中展示候选牌，点选其一
func _update_choice_layer() -> void:
	var need := not _input_locked() and not gs.pending_choice.is_empty() and int(gs.pending_choice.get("playerIndex", -1)) == PLAYER
	if not need:
		if _choice_layer != null:
			_choice_layer.queue_free()
			_choice_layer = null
		return
	if _choice_layer != null: return
	_choice_layer = Control.new()
	_choice_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_choice_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.035, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	v.add_child(ThemeBuilder.title_label("占 卜", 30))
	var hint := ThemeBuilder.dim_label("选择一张置于牌库顶，下回合即可抽到", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for iid in gs.pending_choice.get("instanceIds", []):
		var def_id := ""
		for card in gs.player(PLAYER).deck:
			if str(card.get("instanceId", "")) == str(iid):
				def_id = str(card.get("definitionId", ""))
				break
		var def := ContentLoader.card_def(def_id) if def_id != "" else {}
		var tile := UIWidgets.make_card_tile(def, func():
			if gs.resolve_divination_choice(PLAYER, str(iid)):
				Sfx.play("reveal")
				_refresh()
				_check_auto_ai()
		, Vector2(168, 262))
		tile.hover_lift = 10.0
		row.add_child(tile)
	_choice_layer.modulate.a = 0.0
	_choice_layer.create_tween().tween_property(_choice_layer, "modulate:a", 1.0, 0.2)


# ——————————————————————————— 检视 ———————————————————————————

func _show_tooltip(node: Control) -> void:
	_hide_tooltip()
	_tooltip = node
	_tooltip.set_meta("kind", str(node.get_meta("kind", "panel")))
	add_child(_tooltip)
	_tooltip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_tooltip.position = Vector2(14, 52)
	_tooltip.size = Vector2(_tooltip.get_combined_minimum_size().x, 0)
	_tooltip.modulate.a = 0.0
	_tooltip.position.x -= 12
	var tw := _tooltip.create_tween().set_parallel(true)
	tw.tween_property(_tooltip, "modulate:a", 1.0, 0.12)
	tw.tween_property(_tooltip, "position:x", 14.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hide_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null


func _on_hand_hover(on: bool, widget: Control) -> void:
	if _pending_target_card >= 0 or _selected_attacker >= 0 or _drag_kind != "": return
	if on:
		if _tooltip != null and is_instance_valid(_tooltip) and _tooltip.get_meta("kind", "") == "unit": return
		Sfx.play("card_hover", 0.5)
		var tip := UIWidgets.make_tooltip(widget.data, str(widget.get_meta("block_reason", "")))
		_show_tooltip(tip)
	elif _tooltip != null and is_instance_valid(_tooltip) and _tooltip.get_meta("kind", "") == "card":
		_hide_tooltip()


func _on_unit_hover(on: bool, p_idx: int, unit_index: int) -> void:
	if gs == null: return
	if _pending_target_card >= 0 or _selected_attacker >= 0 or _drag_kind != "": return
	if on:
		if _tooltip != null and is_instance_valid(_tooltip) and _tooltip.get_meta("kind", "") == "unit": return
		var wrap := PanelContainer.new()
		var sb := ThemeBuilder.glass(0.92, Color(ThemeBuilder.ALLY if p_idx == PLAYER else ThemeBuilder.FOE, 0.6), 14)
		sb.set_content_margin_all(14)
		wrap.add_theme_stylebox_override("panel", sb)
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(UIWidgets.make_unit_popover(gs.player(p_idx).units[unit_index]))
		wrap.set_meta("kind", "unit-hover")
		_show_tooltip(wrap)
	elif _tooltip != null and is_instance_valid(_tooltip) and _tooltip.get_meta("kind", "") == "unit-hover":
		_hide_tooltip()


func _on_unit_clicked(unit: Dictionary, p_idx: int, unit_index: int) -> void:
	if gs == null or gs.winner >= 0 or gs.phase == "opening" or _input_locked():
		return
	if _pending_target_card >= 0 and not _pending_target_card_def.is_empty():
		var opts: Array = gs.valid_targets(PLAYER, _pending_target_card_def)
		if opts.has(unit.get("uid")):
			var hi := _pending_target_card
			_pending_target_card = -1
			_pending_target_card_def = {}
			_hide_tooltip()
			gs.play_card(PLAYER, hi, unit.get("uid"))
			_refresh()
			_check_auto_ai()
			return
		_reject_target("请选择发光的目标", _unit_widget(str(unit.get("uid", ""))))
		return
	if p_idx == AI and _selected_attacker >= 0 and not _can_drop_command({"kind": "unit", "unit": _selected_attacker}, str(unit.uid)):
		_reject_target("需先攻击敌方前线", _unit_widget(str(unit.uid)))
		return
	if p_idx == AI and _selected_attacker >= 0 and _can_drop_command({"kind": "unit", "unit": _selected_attacker}, str(unit.uid)):
		_drop_command({"kind": "unit", "unit": _selected_attacker}, str(unit.uid))
		return
	if p_idx == PLAYER and gs.current_player == PLAYER and gs.is_upgrade_pending(PLAYER) and gs.can_level_up(PLAYER, unit_index):
		if gs.level_up(PLAYER, unit_index):
			_refresh()
			return
	if p_idx == PLAYER and gs.can_basic_attack(PLAYER, unit_index).ok and gs.response_window.is_empty() and gs.pending_choice.is_empty():
		_selected_attacker = -1 if _selected_attacker == unit_index else unit_index
		Sfx.play("ui_click", 0.7)
	else:
		_selected_attacker = -1
	_update_selection_highlights()
	_fill_command_bar()
	if _selected_attacker >= 0:
		_hide_tooltip()
	else:
		_show_unit_popover(unit, p_idx, unit_index)


func _show_unit_popover(unit: Dictionary, p_idx: int, unit_index: int) -> void:
	_hide_tooltip()
	var wrap := PanelContainer.new()
	var sb := ThemeBuilder.glass(0.94, Color(ThemeBuilder.ALLY if p_idx == PLAYER else ThemeBuilder.FOE, 0.7), 14)
	sb.set_content_margin_all(14)
	wrap.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	wrap.add_child(v)
	v.add_child(UIWidgets.make_unit_popover(unit))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	if p_idx == PLAYER and gs.current_player == PLAYER:
		var atk_btn := ThemeBuilder.primary(Button.new(), 15)
		atk_btn.text = "出击"
		atk_btn.disabled = not gs.can_basic_attack(PLAYER, unit_index).ok
		atk_btn.pressed.connect(func():
			_hide_tooltip()
			_drop_command({"kind": "unit", "unit": unit_index}, null)
		)
		h.add_child(atk_btn)
		var lv_btn := Button.new()
		lv_btn.text = "升勾"
		lv_btn.disabled = not gs.can_level_up(PLAYER, unit_index)
		lv_btn.pressed.connect(func():
			if _input_locked(): return
			gs.level_up(PLAYER, unit_index)
			_hide_tooltip()
			_refresh()
		)
		h.add_child(lv_btn)
	var close := ThemeBuilder.ghost(Button.new())
	close.text = "关闭"
	close.pressed.connect(func():
		_hide_tooltip()
		_selected_attacker = -1
		_update_selection_highlights()
		_fill_command_bar()
	)
	h.add_child(close)
	wrap.set_meta("kind", "unit")
	_show_tooltip(wrap)


# ——————————————————————————— 操作 ———————————————————————————

func _on_hand_clicked(index: int, card: Dictionary) -> void:
	if gs == null or gs.winner >= 0 or index < 0 or _input_locked():
		return
	if not _hand_playability(index).ok:
		Sfx.play("error", 0.6)
		return
	_cancel_target_selection()
	var t: String = str(card.get("target", "auto"))
	if t == "auto":
		_hide_tooltip()
		gs.play_card(PLAYER, index, null)
		_refresh()
		_check_auto_ai()
	else:
		_pending_target_card = index
		_pending_target_card_def = card
		_selected_attacker = -1
		_hide_tooltip()
		Sfx.play("ui_click", 0.8)
		_update_selection_highlights()
		_fill_command_bar()


func _on_end_turn() -> void:
	if gs == null or gs.winner >= 0 or _input_locked():
		return
	if gs.end_turn(PLAYER):
		Sfx.play("turn_end")
		_hide_tooltip()
		_refresh()
		_check_auto_ai()


func _on_pass_response() -> void:
	if gs == null or gs.winner >= 0 or _input_locked():
		return
	if gs.pass_response(PLAYER):
		Sfx.play("ui_click", 0.7)
		_refresh()
		_check_auto_ai()


func _check_auto_ai() -> void:
	if gs == null or gs.winner >= 0 or _ai_thinking:
		return
	if gs.action_player() != AI:
		return
	_ai_thinking = true
	_run_ai()


func _run_ai() -> void:
	var state_id := gs.get_instance_id()
	# Let deferred presentation work compute its duration before scheduling.
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion() or gs == null or gs.get_instance_id() != state_id:
		return
	_delay(maxf(_ai_delay, _presentation_remaining()), _step_ai.bind(state_id))


func _step_ai(state_id: int) -> void:
	if gs == null or gs.get_instance_id() != state_id:
		return
	if is_queued_for_deletion() or gs.action_player() != AI:
		_ai_thinking = false
		return
	GameAI.take_action(gs, AI)
	_ai_thinking = false
	_refresh()
	_check_auto_ai()


func _on_finished(winner: int) -> void:
	var state_id := gs.get_instance_id()
	Sfx.play("victory" if winner == PLAYER else "defeat")
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion() or gs == null or gs.get_instance_id() != state_id:
		return
	_delay(maxf(maxf(0.45, _ai_delay), _presentation_remaining()), _emit_match_over.bind(winner, state_id))


func _emit_match_over(winner: int, state_id: int) -> void:
	if gs != null and gs.get_instance_id() == state_id and not is_queued_for_deletion():
		match_over.emit(winner, gs.snapshot())


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_aim_pointer_viewport = event.position
		_aim_pointer_known = event.position.is_finite() and get_viewport_rect().has_point(event.position)
	if gs == null or gs.winner >= 0 or gs.phase == "opening":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _pending_target_card >= 0 or _selected_attacker >= 0 or _tooltip != null:
			_hide_tooltip()
			_cancel_and_refresh_bar()
			get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if gs == null or gs.winner >= 0 or gs.phase == "opening":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_P and not gs.response_window.is_empty():
			_on_pass_response()
			return
		if k.keycode == KEY_ESCAPE and (_pending_target_card >= 0 or _selected_attacker >= 0 or _tooltip != null):
			_hide_tooltip()
			_cancel_and_refresh_bar()
			return
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if gs.current_player == PLAYER:
				_on_end_turn()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_TAB and gs.player(PLAYER).units.size() > 0:
			_tab_index = (_tab_index + 1) % gs.player(PLAYER).units.size()
			_show_unit_popover(gs.player(PLAYER).units[_tab_index], PLAYER, _tab_index)
			get_viewport().set_input_as_handled()
		elif k.keycode >= KEY_1 and k.keycode <= KEY_9:
			var idx := int(k.keycode - KEY_1)
			if idx < gs.player(PLAYER).hand.size():
				_on_hand_clicked(idx, ContentLoader.card_def(gs.player(PLAYER).hand[idx].definitionId))
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready() or gs == null: return
	if what == NOTIFICATION_DRAG_BEGIN:
		var payload = get_viewport().gui_get_drag_data()
		if not (payload is Dictionary): return
		_hide_tooltip()
		_drag_kind = str(payload.get("kind", ""))
		_drag_payload = payload.duplicate()
		# 拖拽中高亮可放置的式神与核心
		for box in [_enemy_reserve, _enemy_front, _ally_front, _ally_reserve]:
			for face in box.get_children():
				if face is CardFace:
					face.selected = _can_drop_command(payload, str(face.get_meta("unit_uid", "")))
					face.set_process(face.selected or face.playable)
					face.queue_redraw()
		_set_plate_glow(_enemy_plate, _can_drop_command(payload, "ai-avatar"))
	elif what == NOTIFICATION_DRAG_END and _drag_kind != "":
		_drag_kind = ""
		_drag_payload.clear()
		if is_inside_tree(): _refresh.call_deferred()


func _show_command_log() -> void:
	if gs == null:
		return
	Sfx.play("ui_click", 0.6)
	var panel := PanelContainer.new()
	var sb := ThemeBuilder.glass(0.95, Color(0.82, 0.68, 0.4, 0.5), 14)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 460)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := ThemeBuilder.title_label("命令日志 · %d 条" % gs.command_log.size(), 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(title)
	v.add_child(ThemeBuilder.dim_label("种子 %d · 同一种子与命令序列可确定性重放" % gs.seed, 12))
	var rl := RichTextLabel.new()
	rl.bbcode_enabled = true
	rl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rl.add_theme_font_size_override("normal_font_size", 13)
	rl.add_theme_constant_override("line_separation", 4)
	var lines := PackedStringArray()
	for i in gs.command_log.size():
		lines.append(describe_command(gs.command_log[i], i))
	rl.text = "\n".join(lines)
	rl.scroll_following = true
	v.add_child(rl)
	UIWidgets.show_modal(self, panel)


static func describe_command(cmd: Dictionary, i: int) -> String:
	var who := "你" if int(cmd.get("p", 0)) == PLAYER else "对手"
	var color := ThemeBuilder.GOLD_BRIGHT if int(cmd.get("p", 0)) == PLAYER else ThemeBuilder.FOE.lightened(0.35)
	var a: Dictionary = cmd.get("a", {}) if cmd.get("a") is Dictionary else {}
	var what := str(cmd.get("c", "?"))
	match what:
		"play_card": what = "打出「%s」" % ContentLoader.card_def(str(a.get("card", ""))).get("name", a.get("card", "?"))
		"basic_attack": what = "式神出击"
		"assault": what = "战斗牌出击（+%d）" % int(a.get("bonus", 0))
		"level_up": what = "升勾"
		"end_turn": what = "结束回合"
		"pass_response": what = "放弃响应"
		"mulligan": what = "起手更换 %d 张" % (a.get("indices", []) as Array).size()
		"resolve_divination_choice": what = "占卜置顶「%s」" % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")
	return "[color=#6f7794]#%d · 回合 %d[/color]  [color=#%s]%s[/color] %s" % [i + 1, int(cmd.get("t", 0)), color.to_html(false), who, what]


func _can_drop_command(payload: Dictionary, target: Variant) -> bool:
	if gs == null or gs.winner >= 0 or gs.phase == "opening" or _input_locked(): return false
	if payload.get("kind") == "unit":
		if not gs.pending_choice.is_empty() or not gs.response_window.is_empty(): return false
		if not gs.can_basic_attack(PLAYER, int(payload.get("unit", -1))).ok: return false
		if target == null: return true
		var front := gs.front_unit(AI)
		return (str(target) == "ai-avatar" and front.is_empty()) or (not front.is_empty() and str(target) == str(front.uid))
	if payload.get("kind") == "card":
		var index := int(payload.get("hand", -1))
		return gs.can_play_card(PLAYER, index, target).ok
	return false


func _drop_command(payload: Dictionary, target: Variant) -> void:
	if not _can_drop_command(payload, target): return
	_hide_tooltip()
	_cancel_target_selection()
	if payload.kind == "unit":
		gs.basic_attack(PLAYER, int(payload.unit), null)
	else:
		gs.play_card(PLAYER, int(payload.hand), target)
	_refresh()
	_check_auto_ai()


func _on_core_clicked() -> void:
	if _selected_attacker >= 0:
		_drop_command({"kind": "unit", "unit": _selected_attacker}, "ai-avatar")


# ——————————————————————————— 起手 ———————————————————————————

func _show_opening() -> void:
	_opening_layer = Control.new()
	_opening_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_opening_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.045, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_opening_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_opening_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	center.add_child(v)
	v.add_child(ThemeBuilder.title_label("起 手 抉 择", 34))
	_opening_status = ThemeBuilder.dim_label("选择至多三张手牌更换，或直接保留", 14)
	_opening_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_opening_status)
	_opening_cards = HBoxContainer.new()
	_opening_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_opening_cards.add_theme_constant_override("separation", 16)
	v.add_child(_opening_cards)
	var confirm := ThemeBuilder.primary(ThemeBuilder.rounded_rect_button("确认起手", Vector2(240, 50)), 18)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm.pressed.connect(func():
		Sfx.play("ui_click")
		gs.confirm_opening(_mulligan_selected)
		_mulligan_selected.clear()
		_check_auto_ai()
	)
	v.add_child(confirm)
	_render_opening_cards()
	_opening_layer.modulate.a = 0.0
	_opening_layer.create_tween().tween_property(_opening_layer, "modulate:a", 1.0, 0.3)
	for i in _opening_cards.get_child_count():
		var tile: Control = _opening_cards.get_child(i)
		tile.visual_offset = Vector2(0, 40)
		tile.modulate.a = 0.0
		var tw := tile.create_tween().set_parallel(true)
		tw.tween_property(tile, "visual_offset", Vector2.ZERO, 0.35).set_delay(0.08 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "modulate:a", 1.0, 0.25).set_delay(0.08 * i)


func _render_opening_cards() -> void:
	_clear_box(_opening_cards)
	for i in gs.player(PLAYER).hand.size():
		var card := ContentLoader.card_def(gs.player(PLAYER).hand[i].definitionId)
		var chosen := _mulligan_selected.has(i)
		var tile := UIWidgets.make_card_tile(card, func():
			if _mulligan_selected.has(i): _mulligan_selected.erase(i)
			elif _mulligan_selected.size() < 3: _mulligan_selected.append(i)
			else:
				Sfx.play("error", 0.6)
				return
			Sfx.play("card_hover", 0.8)
			_render_opening_cards()
		, Vector2(168, 262), false, "更换" if chosen else "")
		tile.hover_lift = 12.0
		tile.enabled = not chosen
		_opening_cards.add_child(tile)
	_opening_status.text = "已选 %d / 3 张更换 · 换出的牌稍后洗回牌库" % _mulligan_selected.size()


# ——————————————————————————— 表现 ———————————————————————————

func _unit_widget(uid: String) -> Control:
	for box in [_enemy_reserve, _enemy_front, _ally_front, _ally_reserve]:
		for child in box.get_children():
			if child.get_meta("unit_uid", "") == uid: return child
	return null


func _center_of(node: Control) -> Vector2:
	return node.get_global_rect().get_center() - global_position


func _presentation_remaining() -> float:
	return maxf(0.0, (_presentation_until - Time.get_ticks_msec()) / 1000.0)


func _input_locked() -> bool:
	return _presentation_remaining() > 0.0


func _presentation_duration(before: Dictionary, after: Dictionary, commands: Array) -> float:
	var duration := 0.0
	for cmd in commands:
		match str(cmd.get("c", "")):
			"play_card": duration += 1.2 if int(cmd.get("p", 0)) == AI else 0.78
			"basic_attack", "assault": duration += 0.85
			"level_up": duration += 0.38
	if int(before.get("turn", 0)) != int(after.get("turn", 0)):
		duration = maxf(duration, 1.0)
	if not EffectCues.build(before, after, commands).is_empty():
		duration = maxf(duration, SpellEffect.TRAVEL + SpellEffect.TAIL + 0.05)
	return duration


func _hold_presentation(seconds: float) -> void:
	if seconds <= 0.0: return
	_presentation_until = maxi(_presentation_until, Time.get_ticks_msec() + int(ceil(seconds * 1000.0)))
	_presentation_ticket += 1
	var ticket := _presentation_ticket
	_delay(_presentation_remaining() + 0.015, func():
		if ticket != _presentation_ticket: return
		_presentation_until = 0
		_fill_units(_enemy_reserve, AI, false)
		_fill_units(_enemy_front, AI, true)
		_fill_units(_ally_front, PLAYER, true)
		_fill_units(_ally_reserve, PLAYER, false)
		_fill_hand()
		_fill_command_bar()
		_update_selection_highlights()
	)


func _invalidate_aim_pointer() -> void:
	_aim_pointer_known = false
	if is_instance_valid(_aim): _aim.hide()


func _process(_delta: float) -> void:
	if not is_instance_valid(_aim) or gs == null: return
	# InputEventMouse.position is viewport-local. Do not poll a desktop/global
	# cursor that may be stale after synthetic input, focus loss or window exit.
	var context: Dictionary = {}
	if _aim_pointer_known:
		var pointer := get_canvas_transform().affine_inverse() * _aim_pointer_viewport
		context = _aim_context(pointer)
	_aim.visible = not context.is_empty()
	if context.is_empty(): return
	_aim.origin = context.origin
	_aim.endpoint = context.endpoint
	_aim.valid = context.valid
	_aim.over_target = context.over_target
	_aim.queue_redraw()


func _aim_context(pointer: Vector2) -> Dictionary:
	if _input_locked() or gs == null or not pointer.is_finite(): return {}
	var local_pointer := get_global_transform().affine_inverse() * pointer
	if not Rect2(Vector2.ZERO, size).has_point(local_pointer): return {}
	# 浮在池面上的资源控件也不属于目标区。
	for hud in [_enemy_hand, _end_btn, _cmd_bar]:
		if is_instance_valid(hud) and hud.visible and hud.get_global_rect().has_point(pointer): return {}
	# Guide only over the battlefield, our hand, or the targetable enemy core.
	# Header buttons, opponent hand and end-turn controls are not targeting space.
	var in_play_area := false
	for area in [_board, _hand_row, _enemy_plate]:
		if is_instance_valid(area) and area.get_global_rect().has_point(pointer):
			in_play_area = true
			break
	if not in_play_area: return {}
	if is_instance_valid(_log_panel) and _log_panel.visible and _log_panel.get_global_rect().has_point(pointer): return {}
	var payload := _drag_payload.duplicate()
	if payload.is_empty():
		if _pending_target_card >= 0:
			payload = {"kind": "card", "hand": _pending_target_card}
		elif _selected_attacker >= 0:
			payload = {"kind": "unit", "unit": _selected_attacker}
		else: return {}
	var source: Control
	if payload.get("kind") == "unit":
		var idx := int(payload.get("unit", -1))
		if idx >= 0 and idx < gs.player(PLAYER).units.size():
			source = _unit_widget(str(gs.player(PLAYER).units[idx].uid))
	else:
		for face in _hand_row.get_children():
			if int(face.get_meta("hand_index", -1)) == int(payload.get("hand", -1)):
				source = face
				break
	if not is_instance_valid(source): return {}
	var target: Variant = null
	var over_target := false
	var endpoint := pointer - global_position
	for face in _unit_widgets.values():
		if is_instance_valid(face) and face.is_inside_tree() and face.get_global_rect().has_point(pointer):
			target = str(face.get_meta("unit_uid", ""))
			over_target = true
			endpoint = _center_of(face)
			break
	if not over_target and _enemy_plate.get_global_rect().has_point(pointer):
		target = "ai-avatar"
		over_target = true
		endpoint = _center_of(_enemy_plate)
	var ok := over_target and _can_drop_command(payload, target)
	if not over_target:
		for row in [_enemy_front, _ally_front]:
			if row.get_global_rect().has_point(pointer):
				over_target = true
				ok = _can_drop_command(payload, null)
	return {"origin": _center_of(source), "endpoint": endpoint, "valid": ok, "over_target": over_target, "target": target}


func _reject_target(text: String, widget: Control) -> void:
	Sfx.play("error", 0.6)
	if is_instance_valid(widget): _floating(text, _center_of(widget), ThemeBuilder.DANGER_SOFT, 16)


func _motion_tween(widget: Control) -> Tween:
	if _motion_tweens.has(widget) and is_instance_valid(_motion_tweens[widget]):
		_motion_tweens[widget].kill()
	var tw := widget.create_tween()
	_motion_tweens[widget] = tw
	tw.finished.connect(func():
		if _motion_tweens.get(widget) == tw: _motion_tweens.erase(widget)
	, CONNECT_ONE_SHOT)
	return tw


func _present_changes(before: Dictionary, after: Dictionary, commands: Array = [], state: GameState = null) -> void:
	if state != null and state != gs: return
	if not is_inside_tree() or _effects == null: return
	for face in _unit_widgets.values():
		if is_instance_valid(face) and face.has_meta("attack_impact_position"): face.remove_meta("attack_impact_position")
	# 出击者的入场、前冲与回位使用同一个 Tween，避免与移位互相覆盖。
	var attackers: Array = []
	for cmd in commands:
		if str(cmd.get("c", "")) in ["basic_attack", "assault"]:
			var p := int(cmd.get("p", 0))
			var idx := int(cmd.get("a", {}).get("unit", -1))
			if idx >= 0 and idx < after.players[p].units.size(): attackers.append(str(after.players[p].units[idx].uid))
	# 1. 位置变化：从旧位置平滑滑入新位置
	for uid in _unit_widgets:
		var w: Control = _unit_widgets[uid]
		if not is_instance_valid(w) or not w.has_meta("flip_from"): continue
		var from: Vector2 = w.get_meta("flip_from")
		w.remove_meta("flip_from")
		if not w.is_inside_tree(): continue
		w.visual_offset = from - w.global_position
		if not attackers.has(uid):
			_motion_tween(w).tween_property(w, "visual_offset", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 2. 命令驱动的动作：出牌展示、出击前冲
	var cues := EffectCues.build(before, after, commands)
	var impact := 0.18 if not cues.is_empty() else 0.05
	var beat := 0.0
	for cmd in commands:
		var p := int(cmd.get("p", 0))
		var a: Dictionary = cmd.get("a", {}) if cmd.get("a") is Dictionary else {}
		match str(cmd.get("c", "")):
			"play_card":
				Sfx.play("card_play")
				var card := ContentLoader.card_def(str(a.get("card", "")))
				if p == AI:
					_showcase_card(card, beat)
					impact = maxf(impact, beat + 0.7)
					beat += 0.95
				else:
					_fly_played_card(card, a)
					impact = maxf(impact, beat + 0.28)
					beat += 0.3
			"basic_attack", "assault":
				var t := maxf(beat, impact - 0.2)
				var hit := _lunge(p, int(a.get("unit", -1)), before, t)
				impact = maxf(impact, hit)
				beat = hit + 0.28
			"level_up":
				var lp := gs.player(p)
				var ui := int(a.get("unit", -1))
				if ui >= 0 and ui < lp.units.size():
					var w := _unit_widget(str(lp.units[ui].uid))
					if w != null: _ring_burst(_center_of(w), ThemeBuilder.GOLD_BRIGHT, beat)
				Sfx.play("level_up", 0.8)
	# 仅已发生的数值/状态变化产生命中特效。等待响应的法术不会提前命中。
	for cue in cues: _present_spell_cue(cue, impact)
	# 3. 数值变化：在冲击时刻呈现
	var shake := 0.0
	for p in [PLAYER, AI]:
		var old: Dictionary = before.players[p]
		var new: Dictionary = after.players[p]
		var core_delta := int(new.avatarHp) - int(old.avatarHp)
		if core_delta != 0:
			var plate := _ally_plate if p == PLAYER else _enemy_plate
			_floating("%+d" % core_delta, _center_of(plate), ThemeBuilder.DANGER_SOFT if core_delta < 0 else ThemeBuilder.OK, 34, impact)
			if core_delta < 0:
				shake = maxf(shake, clampf(-core_delta * 2.2, 4.0, 14.0))
				_delay(impact, func():
					Sfx.play("core_hit", clampf(0.5 + -core_delta * 0.1, 0.5, 1.0))
					_shake_node(plate, 6.0)
					_edge_flash(Color(0.9, 0.2, 0.15, 0.22) if p == PLAYER else Color(1, 0.8, 0.5, 0.12))
				)
		for i in new.units.size():
			var unit: Dictionary = new.units[i]
			var previous: Dictionary = old.units[i]
			var widget := _unit_widget(str(unit.uid))
			if widget == null: continue
			var at := _center_of(widget)
			var delta := int(unit.hp) - int(previous.hp)
			var shield_delta := int(unit.get("shield", 0)) - int(previous.get("shield", 0))
			if delta < 0:
				_floating_on_unit("%d" % delta, widget, Color("ffe397"), 42, impact)
				_delay(impact, func():
					if not is_instance_valid(widget): return
					Sfx.play("hit", clampf(0.45 + -delta * 0.12, 0.45, 1.0))
					widget.flash = 1.0
					widget.create_tween().tween_property(widget, "flash", 0.0, 0.3)
					if not attackers.has(str(unit.uid)): _jitter(widget, 7.0)
				)
			elif delta > 0 and int(previous.hp) > 0:
				_floating_on_unit("+%d" % delta, widget, ThemeBuilder.OK, 28, impact)
				_delay(impact, func(): Sfx.play("heal", 0.7))
			if shield_delta > 0:
				_floating_on_unit("+%d 盾" % shield_delta, widget, Color("9fd0ff"), 22, impact, Vector2(0, 24))
				_delay(impact, func(): Sfx.play("shield", 0.7))
			if int(unit.hp) <= 0 and int(previous.hp) > 0:
				_floating_on_unit("气绝", widget, ThemeBuilder.PAPER, 24, impact + 0.15, Vector2(0, 30))
				_delay(impact + 0.15, func(): Sfx.play("knockout", 0.8))
			elif int(unit.hp) > 0 and int(previous.hp) <= 0:
				_floating_on_unit("归队", widget, ThemeBuilder.OK, 24, impact)
			if int(unit.level) > int(previous.level) and not commands.any(func(c): return c.c == "level_up"):
				_ring_burst(at, ThemeBuilder.GOLD_BRIGHT, impact)
			if bool(unit.get("awakened", false)) and not bool(previous.get("awakened", false)):
				_floating_on_unit("觉醒", widget, ThemeBuilder.TYPE_AWAKEN, 30, impact)
	if shake > 0.0:
		_delay(impact, func(): _shake_node(_stage, shake))
	if int(before.turn) != int(after.turn) and int(after.winner) < 0:
		_delay(maxf(0.0, impact - 0.05), func(): _show_turn_banner(int(after.current) == PLAYER))
		impact += 0.8
	# AI 下一步等当前演出落地
	if not commands.is_empty() or int(before.turn) != int(after.turn):
		_ai_delay = clampf(impact + 0.45, 0.55, 2.0)


func _present_spell_cue(cue: Dictionary, impact: float) -> void:
	var target := _unit_widget(str(cue.target)) if not str(cue.target).is_empty() else null
	var saved_impact: Variant = target.get_meta("attack_impact_position") if is_instance_valid(target) and target.has_meta("attack_impact_position") and cue.kind == "damage" else null
	_delay(maxf(0.0, impact - SpellEffect.TRAVEL), func():
		var source := _unit_widget(str(cue.source)) if not str(cue.source).is_empty() else null
		var destination := Vector2.ZERO
		if is_instance_valid(target) and target.is_inside_tree():
			destination = saved_impact if saved_impact is Vector2 else _center_of(target) + target.visual_offset
		elif cue.area == "hand":
			destination = _center_of(_hand_row) + Vector2(0, -55) if int(cue.player) == PLAYER else _center_of(_enemy_hand)
		elif cue.area == "energy":
			destination = _center_of(_energy_orbs) if int(cue.player) == PLAYER else _center_of(_enemy_plate)
		else: destination = _center_of(_ally_plate if int(cue.player) == PLAYER else _enemy_plate)
		var effect := SpellEffect.new()
		effect.family = str(cue.family)
		effect.destination = destination
		effect.origin = _center_of(source) + source.visual_offset if is_instance_valid(source) else destination
		effect.travel = cue.kind in ["damage", "heal", "revive", "freeze", "seal"] and effect.origin.distance_to(destination) > 30.0
		effect.radius = (86.0 if cue.kind in ["heal", "revive"] else 62.0) if is_instance_valid(target) else 45.0
		effect.set_meta("target_uid", str(cue.target))
		effect.set_meta("kind", str(cue.kind))
		_effects.add_child(effect)
		_effects.move_child(effect, 0)
	)


func _cancel_battle_timers() -> void:
	for child in get_children():
		if child is Timer and child.get_meta("battle_delay", false):
			child.stop()
			child.queue_free()


func _exit_tree() -> void:
	_invalidate_aim_pointer()
	_cancel_battle_timers()


func _delay(seconds: float, action: Callable) -> void:
	if seconds <= 0.01:
		action.call()
		return
	# Child timers die with this screen. SceneTree timers outlive it and their
	# callbacks used to retain an old GameState until the delay elapsed.
	var state_id := gs.get_instance_id() if gs != null else 0
	var timer := Timer.new()
	timer.one_shot = true
	timer.set_meta("battle_delay", true)
	add_child(timer)
	timer.timeout.connect(func():
		timer.queue_free()
		if is_inside_tree() and not is_queued_for_deletion() and gs != null and gs.get_instance_id() == state_id:
			action.call()
	, CONNECT_ONE_SHOT)
	timer.start(seconds)


## 对手出牌：大卡从对手手牌处飞到场中央停留，再淡出
func _showcase_card(card: Dictionary, delay: float) -> void:
	if card.is_empty(): return
	var face := CardFace.new()
	face.data = card
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = Vector2(196, 304)
	face.pivot_offset = face.size * 0.5
	var start := _enemy_hand.get_global_rect().get_center() - global_position - face.size * 0.5
	var rest := Vector2(size.x * 0.5 - face.size.x * 0.5 + 40, size.y * 0.3 - face.size.y * 0.5 + 30)
	face.position = start
	face.scale = Vector2(0.25, 0.25)
	face.modulate.a = 0.0
	_effects.add_child(face)
	var tag := ThemeBuilder.outline(ThemeBuilder.label("对手打出", 14, ThemeBuilder.FOE.lightened(0.45)), 5)
	tag.add_theme_font_override("font", ThemeBuilder.medium_font())
	tag.position = Vector2(0, -26)
	tag.size = Vector2(face.size.x, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(tag)
	var tw := face.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(face, "position", rest, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "modulate:a", 1.0, 0.18)
	tw.set_parallel(false)
	tw.tween_interval(0.62)
	tw.set_parallel(true)
	tw.tween_property(face, "modulate:a", 0.0, 0.22)
	tw.tween_property(face, "scale", Vector2(0.85, 0.85), 0.22)
	tw.set_parallel(false)
	tw.tween_callback(face.queue_free)


## 己方出牌：从手牌原位飞向目标/场中央后消散
func _fly_played_card(card: Dictionary, args: Dictionary) -> void:
	var rect: Rect2 = Rect2()
	for key in _hand_rects:
		if str(key).ends_with("|" + str(args.get("card", ""))) and not _hand_widgets.has(key):
			rect = _hand_rects[key]
			_hand_rects.erase(key)
			break
	if rect.size == Vector2.ZERO or card.is_empty(): return
	var face := CardFace.new()
	face.data = card
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = rect.size
	face.pivot_offset = face.size * 0.5
	face.position = rect.position - global_position
	_effects.add_child(face)
	var dest := Vector2(size.x * 0.5, size.y * 0.42)
	var target = args.get("target")
	if target != null:
		var w := _unit_widget(str(target))
		if w != null: dest = _center_of(w)
	var tw := face.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(face, "position", dest - face.size * 0.5, 0.3)
	tw.tween_property(face, "scale", Vector2(0.55, 0.55), 0.3)
	tw.tween_property(face, "modulate:a", 0.0, 0.18).set_delay(0.16)
	tw.chain().tween_callback(face.queue_free)


## 出击：攻击者冲向敌方前线（或敌方核心）再弹回
func _lunge(p_idx: int, unit_index: int, before: Dictionary, delay: float) -> float:
	if unit_index < 0 or unit_index >= gs.player(p_idx).units.size(): return delay
	var unit: Dictionary = gs.player(p_idx).units[unit_index]
	var attacker := _unit_widget(str(unit.uid))
	if attacker == null: return delay
	var target_pos := Vector2.ZERO
	var e := 1 - p_idx
	for u in before.players[e].units:
		if int(u.get("front", 0)) == 1 and int(u.hp) > 0:
			var tw_widget := _unit_widget(str(u.uid))
			if tw_widget != null: target_pos = _center_of(tw_widget)
	if target_pos == Vector2.ZERO:
		target_pos = _center_of(_enemy_plate if p_idx == PLAYER else _ally_plate)
	var from := _center_of(attacker)
	var reach := (target_pos - from) * 0.55
	# 保存此次 Tween 的命中位置。慢帧可能跨过命中与回位，Timer 不能再读取回位后的偏移。
	attacker.set_meta("attack_impact_position", from + reach)
	var entry := 0.22 if attacker.visual_offset.length() > 2.0 else 0.0
	var tw := _motion_tween(attacker)
	tw.tween_interval(delay)
	if entry > 0.0:
		tw.tween_property(attacker, "visual_offset", Vector2.ZERO, entry).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		Sfx.play("attack", 0.8)
		attacker.z_index = 5
	)
	tw.tween_property(attacker, "visual_offset", reach * 0.12 - reach.normalized() * 10.0, 0.08)
	tw.tween_property(attacker, "visual_offset", reach, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.055)
	tw.tween_property(attacker, "visual_offset", Vector2.ZERO, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): attacker.z_index = 0)
	return delay + entry + 0.2


func _jitter(widget: Control, strength: float) -> void:
	if not "visual_offset" in widget: return
	var tw := _motion_tween(widget)
	for i in 4:
		var s := strength * (1.0 - i / 4.0)
		tw.tween_property(widget, "visual_offset", Vector2(randf_range(-s, s), randf_range(-s * 0.5, s * 0.5)), 0.04)
	tw.tween_property(widget, "visual_offset", Vector2.ZERO, 0.05)


func _shake_node(node: Control, strength: float) -> void:
	if node == null or not is_instance_valid(node): return
	var origin := node.position if node != _stage else Vector2.ZERO
	var tw := node.create_tween()
	for i in 6:
		var s := strength * (1.0 - i / 6.0)
		tw.tween_property(node, "position", origin + Vector2(randf_range(-s, s), randf_range(-s, s)), 0.035)
	tw.tween_property(node, "position", origin, 0.05)


func _edge_flash(color: Color) -> void:
	var cr := ColorRect.new()
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects.add_child(cr)
	var tw := cr.create_tween()
	tw.tween_property(cr, "color:a", 0.0, 0.45)
	tw.tween_callback(cr.queue_free)


func _ring_burst(at: Vector2, color: Color, delay: float = 0.0) -> void:
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = at
	ring.set_meta("t", 0.0)
	ring.draw.connect(func():
		var t := float(ring.get_meta("t", 0.0))
		var r := 18.0 + 62.0 * t
		ring.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, (1.0 - t) * 0.9), 3.0 * (1.0 - t) + 1.0, true)
		ring.draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 48, Color(color, (1.0 - t) * 0.45), 1.5, true)
		for k in 8:
			var ang := TAU * k / 8.0 + t
			ring.draw_circle(Vector2(cos(ang), sin(ang)) * r * 1.1, 2.5 * (1.0 - t), Color(color, 1.0 - t))
	)
	ring.visible = false
	_effects.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): ring.visible = true)
	tw.tween_method(func(v): ring.set_meta("t", v); ring.queue_redraw(), 0.0, 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(ring.queue_free)


func _floating_on_unit(text: String, widget: Control, color: Color, font_size: int, delay: float, offset: Vector2 = Vector2.ZERO) -> void:
	# 命中时再取绘制位置；出击者的反击伤害不能留在其回位后的空阵台。
	var attack_impact: Variant = widget.get_meta("attack_impact_position") if text.begins_with("-") and widget.has_meta("attack_impact_position") else null
	_delay(delay, func():
		if not is_instance_valid(widget) or not widget.is_inside_tree(): return
		var at: Vector2 = (attack_impact as Vector2) if attack_impact is Vector2 else _center_of(widget) + widget.visual_offset
		at += offset
		_floating(text, at, color, font_size)
	)


func _floating(text: String, at: Vector2, color: Color, font_size: int = 27, delay: float = 0.0) -> void:
	var is_damage := text.begins_with("-")
	var label := ThemeBuilder.label(text, maxi(font_size, 42) if is_damage else font_size, Color("ffe397") if is_damage else color)
	label.add_theme_font_override("font", ThemeBuilder.heavy_display_font())
	ThemeBuilder.outline(label, 8, Color("0b0d18"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, font_size + 12)
	label.pivot_offset = label.size * 0.5
	# 同一位置的多个数字错开，避免叠字
	var stack := 0
	for other in _effects.get_children():
		if other is Label and other.has_meta("anchor") and (other.get_meta("anchor") as Vector2).distance_to(at) < 30.0:
			stack += 1
	label.set_meta("anchor", at)
	label.position = at - label.size * 0.5 + Vector2(0, -stack * (font_size + 2))
	label.scale = Vector2(0.4, 0.4)
	label.modulate.a = 0.0
	_effects.add_child(label)
	if is_damage:
		var brush := Control.new()
		brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
		brush.show_behind_parent = true
		label.add_child(brush)
		brush.draw.connect(func():
			brush.draw_colored_polygon(PackedVector2Array([Vector2(20, 19), Vector2(138, 4), Vector2(126, 39), Vector2(34, 53), Vector2(48, 36)]), Color(0.21, 0.10, 0.23, 0.65))
		)
	var tw := label.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(label, "modulate:a", 1.0, 0.08)
	tw.tween_property(label, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_property(label, "scale", Vector2.ONE, 0.1)
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 42, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.set_parallel(false)
	tw.tween_callback(label.queue_free)


## 回合横幅：墨带从左划入，停留后淡出
func _show_turn_banner(mine: bool) -> void:
	if _banner != null and is_instance_valid(_banner): _banner.queue_free()
	Sfx.play("turn_start" if mine else "turn_end", 0.8 if mine else 0.6)
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	band.offset_top = -46
	band.offset_bottom = 46
	band.position.y -= 40
	var accent := Color("fff4e8")
	band.draw.connect(func():
		var w := band.size.x
		var h := band.size.y
		var ink := Color("a54652") if mine else Color("685483")
		var points := PackedVector2Array()
		for i in 24:
			points.append(Vector2(w * (0.23 + i * 0.024), h * (0.08 + 0.04 * sin(i * 7.1))))
		for i in range(23, -1, -1):
			points.append(Vector2(w * (0.23 + i * 0.024), h * (0.88 + 0.06 * cos(i * 8.3))))
		band.draw_colored_polygon(points, Color(ink, 0.85))
		for i in 12:
			band.draw_line(Vector2(w * 0.19 + i * 7, h * (0.18 + i * 0.045)), Vector2(w * 0.85 - i * 8, h * (0.15 + i * 0.05)), Color(ink, 0.28), 3, true)
	)
	add_child(band)
	var title := ThemeBuilder.label("你 的 回 合" if mine else "对 手 回 合", 38, accent)
	title.add_theme_font_override("font", ThemeBuilder.heavy_display_font())
	ThemeBuilder.outline(title, 8, Color(0, 0, 0, 0.6))
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(title)
	_banner = band
	band.modulate.a = 0.0
	title.position.x = -80
	var tw := band.create_tween()
	tw.set_parallel(true)
	tw.tween_property(band, "modulate:a", 1.0, 0.18)
	tw.tween_property(title, "position:x", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(0.55)
	tw.tween_property(band, "modulate:a", 0.0, 0.3)
	tw.tween_callback(band.queue_free)
