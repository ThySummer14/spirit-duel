class_name FormationScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")
const PaperScroll := preload("res://scripts/ui/paper_scroll.gd")
const CardScroll := preload("res://scripts/ui/formation_card_scroll.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")

signal confirmed(unit_ids: Array)
signal lineup_saved(unit_ids: Array)
signal back_requested
signal edit_deck(unit_id: String)

const PICK_COUNT := 4
const DECK_COUNT := 8
var browse_only := false
var formation_slot := 0
var _selected: Array = []
var _focused := "ember"
var _unit_list: GridContainer
var _detail_box: VBoxContainer
var _card_box: HBoxContainer
var _card_scroll: ScrollContainer
var _selected_row: HBoxContainer
var _deck_row: HBoxContainer
var _confirm_btn: Button
var _save_btn: Button
var _status_l: Label
var _deck_hint: Label
var _search: LineEdit
var _roster_count: Label
var _pack_picker: OptionButton
var _pack_filter := "all"
var _slot_picker: OptionButton
var _drafts: Dictionary = {}
var _deck_drafts: Dictionary = {}
var _active_slot := -1
var _pending_card := ""
var _deck_title: Label
var _pool_count: Label
var _cancel_btn: Button
var _deck_paper: Control
var _selection_signature := ""
var _last_focus := ""
var _scroll_positions: Dictionary = {}
var _undo_decks: Array = []
var _undo_btn: Button

func _ready() -> void:
	theme = ThemeBuilder.build_night_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "table"
	bg.dim = 0.65
	bg.tint = Color(0.82, 0.90, 0.96)
	add_child(bg)
	Sfx.music("bgm_menu")
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)
	var back := ThemeBuilder.ghost(Button.new())
	back.text = "‹ 返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	header.add_child(ThemeBuilder.title_label("式神录" if browse_only else "阵容", 26))
	_status_l = ThemeBuilder.dim_label("", 13)
	_status_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_status_l)
	_slot_picker = OptionButton.new()
	for entry in SaveStore.get_formations(): _slot_picker.add_item(str(entry.name))
	_slot_picker.select(formation_slot)
	_slot_picker.item_selected.connect(_switch_slot)
	_slot_picker.visible = not browse_only
	header.add_child(_slot_picker)
	_save_btn = ThemeBuilder.ghost(Button.new())
	_save_btn.text = "保存阵容"
	_save_btn.visible = not browse_only
	_save_btn.pressed.connect(func():
		if _save_current(): _status_l.text = "阵容与卡组已保存"
	)
	header.add_child(_save_btn)
	_confirm_btn = ThemeBuilder.primary(ThemeBuilder.rounded_rect_button("出 战", Vector2(116, 42)))
	_confirm_btn.visible = not browse_only
	_confirm_btn.pressed.connect(_on_confirm)
	header.add_child(_confirm_btn)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 24)
	root.add_child(split)
	var rail := PanelContainer.new()
	rail.add_theme_stylebox_override("panel", _surface(Color("141d27"), 12))
	rail.custom_minimum_size.x = 132
	split.add_child(rail)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	rail.add_child(left)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索式神"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 13)
	_search.text_changed.connect(func(_t): _rebuild_unit_list())
	left.add_child(_search)
	_pack_picker = OptionButton.new()
	_pack_picker.fit_to_longest_item = false
	_pack_picker.add_theme_font_size_override("font_size", 12)
	for id in ContentLoader.pack_ids(): _pack_picker.add_item(ContentLoader.pack_label(id))
	_pack_picker.item_selected.connect(func(index):
		_pack_filter = ContentLoader.pack_ids()[index]
		_rebuild_unit_list()
	)
	left.add_child(_pack_picker)
	_roster_count = ThemeBuilder.dim_label("", 12)
	left.add_child(_roster_count)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(roster_scroll)
	_unit_list = GridContainer.new()
	_unit_list.columns = 1
	_unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unit_list.add_theme_constant_override("v_separation", 12)
	roster_scroll.add_child(_unit_list)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	split.add_child(mid)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 24)
	mid.add_child(identity)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(_detail_box)
	_selected_row = HBoxContainer.new()
	_selected_row.alignment = BoxContainer.ALIGNMENT_END
	_selected_row.add_theme_constant_override("separation", 12)
	_selected_row.visible = not browse_only
	identity.add_child(_selected_row)
	mid.add_child(ThemeBuilder.hline())
	var pool_header := HBoxContainer.new()
	pool_header.add_theme_constant_override("separation", 14)
	mid.add_child(pool_header)
	pool_header.add_child(ThemeBuilder.label("式神卡牌", 16, ThemeBuilder.PAPER))
	_pool_count = ThemeBuilder.dim_label("", 12)
	_pool_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_header.add_child(_pool_count)
	pool_header.add_child(ThemeBuilder.dim_label("双指滑动浏览 · 右键查看大图", 12))
	for direction in [-1, 1]:
		var arrow := ThemeBuilder.ghost(ThemeBuilder.rounded_rect_button("‹" if direction < 0 else "›", Vector2(36, 28)))
		arrow.pressed.connect(func(): _card_scroll.page_by(direction))
		pool_header.add_child(arrow)
	_card_scroll = CardScroll.new()
	_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(_card_scroll)
	_card_box = HBoxContainer.new()
	_card_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_box.add_theme_constant_override("separation", 24)
	_card_scroll.add_child(_card_box)
	_card_scroll.resized.connect(func(): _resize_cards.call_deferred())
	var deck_header := HBoxContainer.new()
	deck_header.add_theme_constant_override("separation", 12)
	mid.add_child(deck_header)
	_deck_title = ThemeBuilder.label("", 16, ThemeBuilder.PAPER)
	deck_header.add_child(_deck_title)
	_deck_hint = ThemeBuilder.dim_label("", 13)
	_deck_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	deck_header.add_child(_deck_hint)
	_cancel_btn = ThemeBuilder.ghost(Button.new())
	_cancel_btn.text = "取消替换"
	_cancel_btn.pressed.connect(_cancel_pending)
	deck_header.add_child(_cancel_btn)
	_undo_btn = ThemeBuilder.ghost(Button.new())
	_undo_btn.text = "撤销"
	_undo_btn.tooltip_text = "撤销上一次放牌、移出或替换"
	_undo_btn.pressed.connect(_undo_edit)
	deck_header.add_child(_undo_btn)
	_deck_paper = PaperScroll.new()
	_deck_paper.custom_minimum_size = Vector2(0, 172)
	mid.add_child(_deck_paper)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deck_paper.add_child(deck_scroll)
	for surface in [_deck_paper, deck_scroll]:
		surface.set_drag_forwarding(Callable(), _can_drop_card.bind(-1), _drop_card.bind(-1))
	_deck_row = HBoxContainer.new()
	_deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_row.add_theme_constant_override("separation", 4)
	deck_scroll.add_child(_deck_row)
	_deck_row.set_drag_forwarding(Callable(), _can_drop_card.bind(-1), _drop_card.bind(-1))
	for i in DECK_COUNT:
		var slot := CenterContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.set_drag_forwarding(Callable(), _can_drop_card.bind(i), _drop_card.bind(i))
		_deck_row.add_child(slot)
	_rebuild_unit_list()
	_show_unit(ContentLoader.unit_def(_focused))


func _surface(color: Color, padding: int) -> StyleBoxFlat:
	var style := ThemeBuilder.panel(color, Color("34424b"), 5)
	style.set_content_margin_all(padding)
	return style


func _resize_cards() -> void:
	if not is_instance_valid(_card_scroll): return
	var height := clampf(_card_scroll.size.y - 32, 210, 330)
	for face in _card_box.get_children():
		face.custom_minimum_size = Vector2(height / 1.65, height)


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _filtered_units() -> Array:
	var q := _search.text.strip_edges().to_lower()
	# 全部名录优先展示迁入的经典与资料片角色，原创试验角色放在末尾。
	var packs := ContentLoader.pack_ids()
	packs.erase("all")
	packs.erase("origin")
	packs.append("origin")
	var catalogue: Array = []
	for pack in packs: catalogue.append_array(ContentLoader.units_in_pack(pack))
	return catalogue.filter(func(unit):
		if _pack_filter != "all" and str(unit.get("pack", "origin")) != _pack_filter: return false
		var hay := "%s %s %s %s" % [unit.get("name", ""), unit.get("title", ""), unit.get("role", ""), unit.get("strategy", "")]
		return q == "" or hay.to_lower().contains(q)
	)

func _rebuild_unit_list() -> void:
	_clear(_unit_list)
	var units := _filtered_units()
	_roster_count.text = "%d / %d" % [units.size(), ContentLoader.playable_units().size()]
	for unit in units:
		var face := UIWidgets.make_unit_panel(unit, _show_unit, true)
		face.portrait_only = true
		face.custom_minimum_size = Vector2(90, 100)
		face.tooltip_text = str(unit.name)
		_unit_list.add_child(face)
	if units.is_empty(): _unit_list.add_child(ThemeBuilder.dim_label("没有匹配的式神"))
	_refresh_selection()


func _formation_error() -> String:
	if _selected.size() != PICK_COUNT: return "请先选满四名式神"
	var error := ContentLoader.lineup_rule_error(_selected)
	if not error.is_empty(): return error
	for uid in _selected:
		var unit := ContentLoader.unit_def(uid)
		if unit.is_empty(): return "阵容中有不可用的式神，请替换"
		if _cards_in_deck(uid).size() != DECK_COUNT:
			return "%s的牌卷需要放满八张" % unit.name
	var deck := SaveStore.deck_definition(_selected, _deck_drafts)
	return ContentLoader.cooperation_deck_error(deck.cardIds, deck.slotOwners)


func _refresh_selection() -> void:
	for face in _unit_list.get_children():
		if not "data" in face: continue
		var focused: bool = str(face.data.id) == _focused
		if face.selected != focused:
			face.selected = focused
			face.queue_redraw()
		face.tooltip_text = str(face.data.name) + (" · 已入队" if _selected.has(face.data.id) else "")
	var error := _formation_error()
	_confirm_btn.disabled = not error.is_empty()
	_save_btn.disabled = _confirm_btn.disabled
	_status_l.text = "已选 %d / 4 位式神" % _selected.size()
	if browse_only: _status_l.text = "式神录"
	elif _selected.size() == PICK_COUNT and not error.is_empty(): _status_l.text = error
	var signature := str(_selected) + str(_active_slot)
	if signature == _selection_signature: return
	_selection_signature = signature
	_clear(_selected_row)
	for i in PICK_COUNT:
		if i < _selected.size():
			var unit := ContentLoader.unit_def(_selected[i])
			var face := UIWidgets.unit_token(unit, func(): _show_unit(unit), Vector2(58, 64), "diamond", i == _active_slot)
			_selected_row.add_child(face)
		else:
			var empty := ThemeBuilder.rounded_rect_button("＋", Vector2(62, 62))
			empty.tooltip_text = "加入正在查看的式神"
			empty.disabled = _selected.has(_focused)
			empty.pressed.connect(_add_focused)
			_selected_row.add_child(empty)


func _add_focused() -> void:
	if browse_only or _selected.has(_focused): return
	if _selected.size() < PICK_COUNT: _selected.append(_focused)
	elif _active_slot >= 0: _selected[_active_slot] = _focused
	else: return
	Sfx.play("ui_click", 0.7)
	_show_unit(ContentLoader.unit_def(_focused))


func _remove_focused() -> void:
	_selected.erase(_focused)
	_active_slot = -1
	_show_unit(ContentLoader.unit_def(_focused))

func _show_unit(unit: Dictionary) -> void:
	if unit.is_empty(): return
	_focused = str(unit.id)
	_pending_card = ""
	var slot := _selected.find(_focused)
	if slot >= 0: _active_slot = slot
	if not _last_focus.is_empty(): _scroll_positions[_last_focus] = _card_scroll.scroll_horizontal
	var changed := _last_focus != _focused
	_last_focus = _focused
	_clear(_detail_box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	_detail_box.add_child(heading)
	var portrait := UIWidgets.unit_token(unit, Callable(), Vector2(64, 68), "diamond")
	heading.add_child(portrait)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 4)
	heading.add_child(names)
	var name_label := ThemeBuilder.title_label(str(unit.get("name", "")), 27)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(name_label)
	names.add_child(ThemeBuilder.dim_label(str(unit.get("role", "")), 13))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	heading.add_child(actions)
	var details := ThemeBuilder.ghost(Button.new())
	details.text = "式神详情"
	details.add_theme_font_size_override("font_size", 12)
	details.pressed.connect(func():
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _surface(Color("17212b"), 24))
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 12)
		panel.add_child(body)
		body.add_child(UIWidgets.make_unit_popover(unit))
		body.add_child(ThemeBuilder.dim_label(ContentLoader.pack_label(str(unit.get("pack", "origin"))), 13))
		var strategy := ThemeBuilder.dim_label(str(unit.get("strategy", "")), 13)
		strategy.custom_minimum_size.x = 340
		strategy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(strategy)
		var modal := UIWidgets.show_modal(self, panel)
		modal.add_to_group("formation_inspector")
	)
	actions.add_child(details)
	if not browse_only:
		var action := ThemeBuilder.ghost(Button.new())
		action.add_theme_font_size_override("font_size", 12)
		if slot >= 0:
			action.text = "移出阵容"
			action.pressed.connect(_remove_focused)
		else:
			action.text = "加入阵容" if _selected.size() < PICK_COUNT else "换入第 %d 位" % (_active_slot + 1)
			action.disabled = _selected.size() == PICK_COUNT and _active_slot < 0
			action.pressed.connect(_add_focused)
		actions.add_child(action)
	if changed or _card_box.get_child_count() == 0:
		_clear(_card_box)
		var cards := ContentLoader.cards_for_unit(_focused).filter(func(card): return not card.get("token", false) and not card.get("skin", false))
		cards.sort_custom(func(a, b): return int(a.get("level", 1)) < int(b.get("level", 1)))
		for card in cards:
			var face := _card_tile(card, func(): _select_pool_card(card), Vector2(140, 231))
			face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			face.hover_lift = 5.0
			var count := ThemeBuilder.label("", 12, ThemeBuilder.PAPER)
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count.add_theme_stylebox_override("normal", _surface(Color("283b3e"), 5))
			face.add_child(count)
			count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			count.offset_left = -39
			count.offset_top = 2
			count.offset_right = -1
			face.set_meta("copy_label", count)
			_card_box.add_child(face)
		_pool_count.text = "%d 张可选" % cards.size()
		_card_scroll.set_deferred("scroll_horizontal", int(_scroll_positions.get(_focused, 0)))
		_resize_cards.call_deferred()
	_refresh_deck()
	_refresh_selection()


func _cards_in_deck(uid: String) -> Array:
	if _deck_drafts.has(uid): return _deck_drafts[uid]
	var saved := SaveStore.get_deck(uid)
	return saved if saved.size() == DECK_COUNT else ContentLoader.starter_card_ids(uid)


func _card_tile(card: Dictionary, action: Callable, extent: Vector2) -> Control:
	var face := UIWidgets.make_card_tile(card, Callable(), extent)
	var button := UIWidgets.attach_click(face, func():
		if _card_scroll.suppress_click: return
		var started := int(face.get_meta("pressed_at", -1))
		face.remove_meta("pressed_at")
		if started >= 0 and Time.get_ticks_msec() - started >= 450:
			_inspect_card(card)
		else:
			action.call()
	)
	button.button_down.connect(func(): face.set_meta("pressed_at", Time.get_ticks_msec()))
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_inspect_card(card)
			button.accept_event()
	)
	return face


func _can_insert(card: Dictionary, index := -1) -> bool:
	if browse_only or not _selected.has(_focused) or card.is_empty(): return false
	if not ContentLoader.card_unit_ids(card).has(_focused): return false
	var picked := _cards_in_deck(_focused).duplicate()
	if index >= 0 and index < picked.size():
		if picked[index] == card.id: return false
		picked.remove_at(index)
	return picked.size() < DECK_COUNT and picked.count(card.id) < SaveStore.deck_card_limit(card, _focused, picked, _selected, _deck_drafts)


func _can_select(card: Dictionary, picked: Array) -> bool:
	if _can_insert(card): return true
	return range(picked.size()).any(func(i): return _can_insert(card, i))


func _select_pool_card(card: Dictionary) -> void:
	if browse_only or not _selected.has(_focused):
		_inspect_card(card)
		return
	if _can_insert(card):
		_insert_card(card)
	elif _can_select(card, _cards_in_deck(_focused)):
		_pending_card = "" if _pending_card == str(card.id) else str(card.id)
		_refresh_deck()
	else:
		_deck_hint.text = "「%s」已达上限或与现有卡牌冲突" % card.name


func _insert_card(card: Dictionary, index := -1) -> void:
	if not _can_insert(card, index): return
	var picked := _cards_in_deck(_focused).duplicate()
	if index >= 0 and index < picked.size(): picked[index] = card.id
	else: picked.append(card.id)
	_store_deck(picked)


func _pick_slot(index: int) -> void:
	var picked := _cards_in_deck(_focused).duplicate()
	if not _pending_card.is_empty():
		_insert_card(ContentLoader.card_def(_pending_card), index)
	elif _selected.has(_focused) and not browse_only and index < picked.size():
		picked.remove_at(index)
		_store_deck(picked)


func _store_deck(picked: Array) -> void:
	_undo_decks.append({"unit": _focused, "cards": _cards_in_deck(_focused).duplicate()})
	if _undo_decks.size() > 30: _undo_decks.pop_front()
	_deck_drafts[_focused] = picked
	_pending_card = ""
	Sfx.play("card_play", 0.55)
	_refresh_deck()
	_refresh_selection()


func _can_drop_card(_position: Vector2, payload: Variant, index: int) -> bool:
	return payload is Dictionary and payload.get("kind") == "formation-card" and payload.get("unit") == _focused and _can_insert(ContentLoader.card_def(str(payload.get("card", ""))), index)


func _drop_card(position: Vector2, payload: Variant, index: int) -> void:
	if _can_drop_card(position, payload, index): _insert_card(ContentLoader.card_def(payload.card), index)


func _refresh_deck() -> void:
	var deck_ids := _cards_in_deck(_focused)
	var editable := _selected.has(_focused) and not browse_only
	var pending := ContentLoader.card_def(_pending_card) if not _pending_card.is_empty() else {}
	_deck_title.text = "牌卷  %d / 8" % deck_ids.size()
	_deck_hint.text = "点上方卡牌放入或替换 · 点牌卷移出" if editable else "入队后可调整卡牌"
	if not pending.is_empty(): _deck_hint.text = "换入「%s」：选择下方一张卡牌" % pending.name
	_cancel_btn.visible = not pending.is_empty()
	_undo_btn.disabled = _undo_decks.is_empty()
	_undo_btn.visible = not browse_only
	for face in _card_box.get_children():
		var card: Dictionary = face.data
		var copies := deck_ids.count(card.id)
		var count: Label = face.get_meta("copy_label")
		count.text = "%d 张" % copies
		count.visible = copies > 0
		face.selected = card.id == _pending_card
		face.drag_payload = {"kind": "formation-card", "unit": _focused, "card": card.id} if editable and _can_select(card, deck_ids) else {}
		face.queue_redraw()
	for i in DECK_COUNT:
		var slot := _deck_row.get_child(i)
		var id: String = str(deck_ids[i]) if i < deck_ids.size() else ""
		if str(slot.get_meta("card_id", "unbuilt")) != id:
			_clear(slot)
			slot.set_meta("card_id", id)
			if not id.is_empty():
				var card := ContentLoader.card_def(id)
				var face := _card_tile(card, func():
					if _selected.has(_focused) and not browse_only: _pick_slot(i)
					else: _inspect_card(ContentLoader.card_def(str(_cards_in_deck(_focused)[i])))
				, Vector2(86, 142))
				face.hover_lift = 3.0
				face.drop_check = func(payload): return _can_drop_card(Vector2.ZERO, payload, i)
				face.drop_action = func(payload): _drop_card(Vector2.ZERO, payload, i)
				slot.add_child(face)
				face.visual_offset = Vector2(0, -8)
				face.modulate.a = 0.65
				var settle := face.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				settle.tween_property(face, "visual_offset", Vector2.ZERO, 0.16)
				settle.tween_property(face, "modulate:a", 1.0, 0.16)
			else:
				var empty := ThemeBuilder.label("＋", 24, Color("707d7a"))
				empty.custom_minimum_size = Vector2(86, 142)
				empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(empty)
		var tile := slot.get_child(0)
		if not id.is_empty():
			tile.selected = not pending.is_empty() and _can_insert(pending, i)
			tile.queue_redraw()


func _cancel_pending() -> void:
	_pending_card = ""
	_refresh_deck()


func _undo_edit() -> void:
	if _undo_decks.is_empty(): return
	var previous: Dictionary = _undo_decks.pop_back()
	_deck_drafts[previous.unit] = previous.cards
	_show_unit(ContentLoader.unit_def(previous.unit))


func _inspect_card(card: Dictionary) -> void:
	Sfx.play("ui_click", 0.7)
	UIWidgets.show_card_modal(self, card).add_to_group("formation_inspector")

func _switch_slot(slot: int) -> void:
	_drafts[formation_slot] = _selected.duplicate()
	formation_slot = slot
	_selected = _drafts.get(slot, SaveStore.get_formations()[slot].lineup).duplicate()
	_active_slot = -1
	_show_unit(ContentLoader.unit_def(_selected[0] if not _selected.is_empty() else _focused))

func _on_confirm() -> void:
	if _save_current():
		confirmed.emit(_selected.duplicate())

func _save_current() -> bool:
	var error := _formation_error()
	if not error.is_empty():
		_status_l.text = error
		return false
	if not SaveStore.save_formation(formation_slot, _selected, _deck_drafts, true):
		_status_l.text = "保存失败，请重试"
		return false
	lineup_saved.emit(_selected.duplicate())
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if not _pending_card.is_empty() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_pending()
		get_viewport().set_input_as_handled()

func set_preselect(unit_ids: Array) -> void:
	_selected = unit_ids.duplicate()
	_active_slot = -1
	_show_unit(ContentLoader.unit_def(_selected[0] if not _selected.is_empty() else _focused))

func selected_units() -> Array:
	return _selected.duplicate()
