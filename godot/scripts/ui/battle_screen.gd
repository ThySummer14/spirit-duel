class_name BattleScreen
extends Control

const ContentLoader := preload("res://scripts/content_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
## 5-row duel board: 敌方准备 / 敌方前线 / 指令条 / 己方前线 / 己方准备 + hand + log

signal match_over(winner: int, gs: Dictionary)

const PLAYER := 0
const AI := 1

var gs: GameState
var _enemy_reserve: HBoxContainer
var _enemy_front: HBoxContainer
var _ally_front: HBoxContainer
var _ally_reserve: HBoxContainer
var _cmd_bar: HBoxContainer
var _hand_scroll: ScrollContainer
var _hand_row: HBoxContainer
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


func setup(lineup_a: Array, lineup_b: Array, p_seed: int, deck_a: Dictionary = {}, deck_b: Dictionary = {}) -> void:
	gs = GameState.create(lineup_a, lineup_b, p_seed, deck_a, deck_b)
	gs.log_emitted.connect(_on_log)
	gs.state_changed.connect(_refresh)
	gs.match_finished.connect(_on_finished)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.INK_0
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 10
	root.offset_right = -12
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(_build_core_panel())

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	root.add_child(mid)

	# 5 rows + command in middle
	mid.add_child(_row_panel("敌方准备", ThemeBuilder.FOE))
	mid.add_child(_row_panel("敌方前线", ThemeBuilder.FOE))
	mid.add_child(_build_command_bar())
	mid.add_child(_row_panel("己方前线", ThemeBuilder.ALLY))
	mid.add_child(_row_panel("己方准备", ThemeBuilder.ALLY))
	mid.add_child(_build_hand())

	root.add_child(_build_side_panel())

	_tooltip = null
	if gs != null:
		_refresh()
		_check_auto_ai()


func _row_panel(title: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color("12182a"), color.lerp(ThemeBuilder.RULE, 0.45), 10, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(ThemeBuilder.chip(title, color))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	# assign by reference via setter object
	match title:
		"敌方准备":
			_enemy_reserve = row
		"敌方前线":
			_enemy_front = row
		"己方前线":
			_ally_front = row
		"己方准备":
			_ally_reserve = row
	return p


func _build_core_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(170, 0)
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(ThemeBuilder.label("界碑核心", 14, ThemeBuilder.GOLD))
	v.add_child(ThemeBuilder.label("己方", 12, ThemeBuilder.ALLY))
	_ally_core = ThemeBuilder.label("30 / 30", 22, ThemeBuilder.GOLD_BRIGHT)
	v.add_child(_ally_core)
	v.add_child(ThemeBuilder.hline())
	v.add_child(ThemeBuilder.label("敌方", 12, ThemeBuilder.FOE))
	_enemy_core = ThemeBuilder.label("30 / 30", 22, ThemeBuilder.DANGER_SOFT)
	v.add_child(_enemy_core)
	v.add_child(ThemeBuilder.hline())
	_energy_l = ThemeBuilder.label("鬼火 0/2", 15, ThemeBuilder.INFO)
	v.add_child(_energy_l)
	_turn_l = ThemeBuilder.dim_label("回合 1 · 轮 1", 13)
	v.add_child(_turn_l)
	v.add_child(ThemeBuilder.dim_label("升勾齐头并进\n0勾未激活\n气绝2回合复归\n击破额外伤核心1", 11))
	return p


func _build_command_bar() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 52)
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color("171208"), ThemeBuilder.GOLD_DEEP, 10, 1))
	_cmd_bar = HBoxContainer.new()
	_cmd_bar.add_theme_constant_override("separation", 10)
	p.add_child(_cmd_bar)
	return p


func _build_hand() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 210)
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(ThemeBuilder.label("手牌", 14, ThemeBuilder.GOLD))
	var hint := ThemeBuilder.dim_label("悬停全文 · 点击出牌 · 1-9 出牌 · Enter 结束 · Tab 看角色", 11)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(hint)
	_hand_scroll = ScrollContainer.new()
	_hand_scroll.custom_minimum_size = Vector2(0, 170)
	_hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_hand_scroll)
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	_hand_scroll.add_child(_hand_row)
	return p


func _build_side_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(250, 0)
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var log_head := HBoxContainer.new()
	log_head.add_theme_constant_override("separation", 8)
	v.add_child(log_head)
	var log_title := ThemeBuilder.label("对局日志", 14, ThemeBuilder.GOLD)
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_head.add_child(log_title)
	var cmd_btn := Button.new()
	cmd_btn.text = "命令"
	cmd_btn.pressed.connect(_show_command_log)
	log_head.add_child(cmd_btn)
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", 12)
	v.add_child(_log_label)
	v.add_child(ThemeBuilder.hline())
	v.add_child(ThemeBuilder.dim_label("确定性命令日志（种子 RNG）\n可导出用于回放", 11))
	return p


func _on_log(text: String, tone: String) -> void:
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
		c.queue_free()


func _refresh() -> void:
	if gs == null:
		return
	var p := gs.player(PLAYER)
	var e := gs.player(AI)
	_ally_core.text = "%d / %d" % [int(p.avatarHp), int(p.maxAvatarHp)]
	_enemy_core.text = "%d / %d" % [int(e.avatarHp), int(e.maxAvatarHp)]
	_energy_l.text = "鬼火 %d/%d%s" % [int(p.energy), int(p.maxEnergy), " · 出击已用" if p.attackUsed else ""]
	_turn_l.text = "回合 %d · 轮 %d · %s" % [gs.turn_counter, gs.get_round(), "你的行动" if gs.current_player == PLAYER else "对手行动"]

	_fill_units(_enemy_reserve, AI, false)
	_fill_units(_enemy_front, AI, true)
	_fill_units(_ally_front, PLAYER, true)
	_fill_units(_ally_reserve, PLAYER, false)
	_fill_hand()
	_fill_command_bar()


func _fill_units(box: HBoxContainer, p_idx: int, front_only: bool) -> void:
	_clear_box(box)
	if box == null:
		return
	var p := gs.player(p_idx)
	for i in p.units.size():
		var u: Dictionary = p.units[i]
		var is_front := int(u.get("front", 0)) == 1
		if front_only != is_front:
			continue
		var highlight := false
		if p_idx == PLAYER and gs.current_player == PLAYER and gs.is_upgrade_pending(PLAYER) and gs.can_level_up(PLAYER, i):
			highlight = true
		var panel := UIWidgets.make_unit_panel(u, _on_unit_clicked.bind(p_idx, i), true, highlight)
		panel.custom_minimum_size = Vector2(138, 132)
		if p_idx == AI:
			panel.self_modulate = Color(0.94, 0.9, 1.0)
		box.add_child(panel)


func _fill_hand() -> void:
	_clear_box(_hand_row)
	if gs == null:
		return
	var p := gs.player(PLAYER)
	for i in p.hand.size():
		var card := ContentLoader.card_def(p.hand[i].definitionId)
		var playable: bool = gs.current_player == PLAYER and not gs.is_upgrade_pending(PLAYER) and gs.can_play_card(PLAYER, i, null).ok
		# soft-afford: show cost dim when not enough energy even if other gates pass
		var affordable: bool = playable or (
			gs.current_player == PLAYER
			and not gs.is_upgrade_pending(PLAYER)
			and int(p.energy) >= int(card.get("cost", 0))
		)
		var block_reason := ""
		if gs.current_player == PLAYER and gs.is_upgrade_pending(PLAYER):
			block_reason = "先升勾"
		elif gs.current_player != PLAYER:
			block_reason = "对手回合"
		elif not gs.response_window.is_empty():
			block_reason = "响应中"
		elif not gs.pending_choice.is_empty():
			block_reason = "占卜中"
		else:
			var chk := gs.can_play_card(PLAYER, i, null)
			if not chk.ok:
				block_reason = str(chk.get("reason", "")).left(18)
		var widget := UIWidgets.make_hand_card(card, affordable, _on_hand_clicked, i, block_reason)
		widget.mouse_entered.connect(func(): _show_tooltip(UIWidgets.make_tooltip(card)))
		widget.mouse_exited.connect(func():
			if _tooltip != null and _tooltip.get_meta("kind", "") == "card":
				_hide_tooltip()
		)
		widget.set_meta("kind", "card")
		_hand_row.add_child(widget)


func _fill_command_bar() -> void:
	if _cmd_bar == null:
		return
	for c in _cmd_bar.get_children():
		c.queue_free()
	if gs == null:
		return
	if gs.is_upgrade_pending(PLAYER) and gs.current_player == PLAYER:
		var names: PackedStringArray = PackedStringArray()
		for i in gs.player(PLAYER).units.size():
			if gs.can_level_up(PLAYER, i):
				names.append(str(gs.player(PLAYER).units[i].get("name", "?")))
		var prompt := "升勾阶段：请提升勾玉（齐头并进）"
		if names.size() > 0:
			prompt = "升勾阶段：点金色角色（%s）· 齐头并进" % "、".join(names)
		_cmd_bar.add_child(ThemeBuilder.label(prompt, 14, ThemeBuilder.GOLD_BRIGHT))
	else:
		_cmd_bar.add_child(ThemeBuilder.label("指令条 · 鬼火 %d · 回合 %d · %s" % [
			int(gs.player(PLAYER).energy), gs.turn_counter,
			"我方" if gs.current_player == PLAYER else "敌方"
		], 14, ThemeBuilder.GOLD_BRIGHT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cmd_bar.add_child(sp)
	if _pending_target_card >= 0:
		_cmd_bar.add_child(ThemeBuilder.label("请选择目标…", 13, ThemeBuilder.WARN))
		var cancel := Button.new()
		cancel.text = "取消"
		cancel.pressed.connect(func():
			_pending_target_card = -1
			_pending_target_card_def = {}
			_fill_command_bar()
		)
		_cmd_bar.add_child(cancel)
	if not gs.pending_choice.is_empty() and int(gs.pending_choice.get("playerIndex", -1)) == PLAYER:
		_cmd_bar.add_child(ThemeBuilder.label("占卜：选择一张置于牌库顶", 13, ThemeBuilder.GOLD_BRIGHT))
		var ids: Array = gs.pending_choice.get("instanceIds", [])
		for iid in ids:
			var def_id := ""
			for card in gs.player(PLAYER).deck:
				if str(card.get("instanceId", "")) == str(iid):
					def_id = str(card.get("definitionId", ""))
					break
			var def := ContentLoader.card_def(def_id) if def_id != "" else {}
			var pick := Button.new()
			pick.text = str(def.get("name", def_id))
			pick.pressed.connect(func():
				if gs.resolve_divination_choice(PLAYER, str(iid)):
					_refresh()
					_check_auto_ai()
			)
			_cmd_bar.add_child(pick)
		_end_btn = Button.new()
		_end_btn.text = "结束回合 (Enter)"
		_end_btn.disabled = true
		_cmd_bar.add_child(_end_btn)
		return
	if not gs.response_window.is_empty():
		_cmd_bar.add_child(ThemeBuilder.label("响应窗口 · 等待 %s" % [
			"我方" if int(gs.response_window.get("playerIndex", -1)) == PLAYER else "敌方"
		], 13, ThemeBuilder.WARN))
		var pass_btn := Button.new()
		pass_btn.text = "放弃响应 (P)"
		pass_btn.disabled = int(gs.response_window.get("playerIndex", -1)) != PLAYER
		pass_btn.pressed.connect(_on_pass_response)
		_cmd_bar.add_child(pass_btn)
		_end_btn = Button.new()
		_end_btn.text = "结束回合 (Enter)"
		_end_btn.disabled = true
		_cmd_bar.add_child(_end_btn)
		return
	_end_btn = Button.new()
	_end_btn.text = "结束回合 (Enter)"
	_end_btn.disabled = gs.current_player != PLAYER or gs.winner >= 0 or gs.is_upgrade_pending(PLAYER)
	_end_btn.pressed.connect(_on_end_turn)
	_cmd_bar.add_child(_end_btn)


func _show_tooltip(node: Control) -> void:
	_hide_tooltip()
	_tooltip = node
	_tooltip.set_meta("kind", str(node.get_meta("kind", "panel")))
	_tooltip.offset_left = -380
	_tooltip.offset_top = 48
	_tooltip.offset_right = -16
	_tooltip.offset_bottom = 360
	_tooltip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tooltip.offset_left = -380
	_tooltip.offset_top = 48
	_tooltip.offset_right = -16
	add_child(_tooltip)


func _hide_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null


func _on_unit_clicked(unit: Dictionary, p_idx: int, unit_index: int) -> void:
	if gs == null or gs.winner >= 0:
		return
	if _pending_target_card >= 0 and not _pending_target_card_def.is_empty():
		var opts: Array = gs.valid_targets(PLAYER, _pending_target_card_def)
		if opts.has(unit.get("uid")):
			var hi := _pending_target_card
			_pending_target_card = -1
			_pending_target_card_def = {}
			if gs.play_card(PLAYER, hi, unit.get("uid")):
				_tween_flash(Color(1, 0.85, 0.4, 0.22))
			_refresh()
			_check_auto_ai()
			return
	if p_idx == PLAYER and gs.current_player == PLAYER and gs.is_upgrade_pending(PLAYER) and gs.can_level_up(PLAYER, unit_index):
		if gs.level_up(PLAYER, unit_index):
			_refresh()
			return
	_show_unit_popover(unit, p_idx, unit_index)


func _show_unit_popover(unit: Dictionary, p_idx: int, unit_index: int) -> void:
	_hide_tooltip()
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color("0c101a"), ThemeBuilder.RULE_STRONG, 12, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	wrap.add_child(v)
	v.add_child(UIWidgets.make_unit_popover(unit))
	var h := HBoxContainer.new()
	v.add_child(h)
	if p_idx == PLAYER and gs.current_player == PLAYER and not gs.is_upgrade_pending(PLAYER):
		var atk_btn := Button.new()
		atk_btn.text = "出击"
		atk_btn.disabled = not gs.can_basic_attack(PLAYER, unit_index).ok
		atk_btn.pressed.connect(func():
			if gs.basic_attack(PLAYER, unit_index, null):
				_tween_lunge()
				_tween_flash(Color(1, 0.4, 0.2, 0.18))
			_hide_tooltip()
			_refresh()
			_check_auto_ai()
		)
		h.add_child(atk_btn)
		var lv_btn := Button.new()
		lv_btn.text = "升勾"
		lv_btn.disabled = not gs.can_level_up(PLAYER, unit_index)
		lv_btn.pressed.connect(func():
			gs.level_up(PLAYER, unit_index)
			_hide_tooltip()
			_refresh()
		)
		h.add_child(lv_btn)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(_hide_tooltip)
	h.add_child(close)
	wrap.custom_minimum_size = Vector2(400, 0)
	wrap.set_meta("kind", "unit")
	_show_tooltip(wrap)


func _on_hand_clicked(index: int, card: Dictionary) -> void:
	if gs == null or gs.winner >= 0 or gs.current_player != PLAYER:
		return
	if gs.is_upgrade_pending(PLAYER):
		return
	var t: String = str(card.get("target", "auto"))
	if t == "auto":
		if gs.play_card(PLAYER, index, null):
			_tween_flash(Color(0.5, 0.7, 1, 0.14))
		_refresh()
		_check_auto_ai()
	else:
		_pending_target_card = index
		_pending_target_card_def = card
		_fill_command_bar()


func _on_end_turn() -> void:
	if gs == null or gs.winner >= 0:
		return
	if gs.end_turn(PLAYER):
		_refresh()
		_check_auto_ai()


func _on_pass_response() -> void:
	if gs == null or gs.winner >= 0:
		return
	if gs.pass_response(PLAYER):
		_refresh()
		_check_auto_ai()


func _check_auto_ai() -> void:
	if gs == null or gs.winner >= 0 or _ai_thinking:
		return
	if gs.current_player != AI:
		return
	_ai_thinking = true
	_run_ai()


func _run_ai() -> void:
	await get_tree().create_timer(0.4).timeout
	if gs == null:
		_ai_thinking = false
		return
	GameAI.take_turn(gs, AI)
	_ai_thinking = false
	_refresh()
	if gs.winner < 0 and gs.current_player == AI:
		_check_auto_ai()


func _on_finished(winner: int) -> void:
	await get_tree().create_timer(0.45).timeout
	match_over.emit(winner, gs.snapshot())


func _unhandled_input(event: InputEvent) -> void:
	if gs == null or gs.winner >= 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_P and not gs.response_window.is_empty():
			_on_pass_response()
			return
		if k.keycode == KEY_ESCAPE and _pending_target_card >= 0:
			_pending_target_card = -1
			_pending_target_card_def = {}
			_fill_command_bar()
			return
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if gs.current_player == PLAYER and not gs.is_upgrade_pending(PLAYER):
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


func _tween_flash(color: Color) -> void:
	var cr := ColorRect.new()
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cr)
	var tw := create_tween()
	tw.tween_property(cr, "color:a", 0.0, 0.3)
	tw.tween_callback(cr.queue_free)


func _tween_lunge() -> void:
	_tween_flash(Color(1, 0.5, 0.3, 0.1))


func _show_command_log() -> void:
	if gs == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "命令日志"
	dialog.dialog_text = JSON.stringify(gs.command_log)
	dialog.min_size = Vector2(640, 400)
	add_child(dialog)
	dialog.popup_centered()
