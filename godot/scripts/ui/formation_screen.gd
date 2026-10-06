class_name FormationScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")
const PaperScroll := preload("res://scripts/ui/paper_scroll.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")

signal confirmed(unit_ids: Array)
signal back_requested
signal edit_deck(unit_id: String)

const PICK_COUNT := 4
var browse_only := false
var formation_slot := 0
var _selected: Array = []
var _focused := "ember"
var _unit_list: GridContainer
var _detail_box: VBoxContainer
var _card_box: HBoxContainer
var _selected_row: HBoxContainer
var _deck_row: HBoxContainer
var _confirm_btn: Button
var _status_l: Label
var _search: LineEdit
var _roster_count: Label
var _pack_picker: OptionButton
var _pack_filter := "all"
var _slot_picker: OptionButton
var _drafts: Dictionary = {}

func _ready() -> void:
	theme = ThemeBuilder.build_night_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "table"
	bg.dim = 0.1
	bg.tint = Color(0.92, 0.91, 1.0)
	add_child(bg)
	Sfx.music("bgm_menu")
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var back := ThemeBuilder.ghost(Button.new())
	back.text = "‹ 返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	header.add_child(ThemeBuilder.title_label("式神录" if browse_only else "阵 容", 28))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	_slot_picker = OptionButton.new()
	for entry in SaveStore.get_formations(): _slot_picker.add_item(str(entry.name))
	_slot_picker.select(formation_slot)
	_slot_picker.item_selected.connect(_switch_slot)
	_slot_picker.visible = not browse_only
	header.add_child(_slot_picker)
	var save := ThemeBuilder.ghost(Button.new())
	save.text = "保存阵容"
	save.visible = not browse_only
	save.pressed.connect(func():
		_status_l.text = "阵容已保存" if SaveStore.save_formation(formation_slot, _selected) else "请先选满四名不同式神"
	)
	header.add_child(save)
	_confirm_btn = ThemeBuilder.primary(ThemeBuilder.rounded_rect_button("出 战", Vector2(124, 40)))
	_confirm_btn.visible = not browse_only
	_confirm_btn.pressed.connect(_on_confirm)
	header.add_child(_confirm_btn)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	root.add_child(split)
	# 原视频左侧的小头像竖栏；搜索和资料包筛选继续可用。
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(112, 0)
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索式神"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 12)
	_search.text_changed.connect(func(_t): _rebuild_unit_list())
	left.add_child(_search)
	_pack_picker = OptionButton.new()
	_pack_picker.fit_to_longest_item = false
	_pack_picker.add_theme_font_size_override("font_size", 11)
	for id in ContentLoader.pack_ids(): _pack_picker.add_item(ContentLoader.pack_label(id))
	_pack_picker.item_selected.connect(func(index):
		_pack_filter = ContentLoader.pack_ids()[index]
		_rebuild_unit_list()
	)
	left.add_child(_pack_picker)
	_roster_count = ThemeBuilder.dim_label("", 11)
	left.add_child(_roster_count)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(roster_scroll)
	_unit_list = GridContainer.new()
	_unit_list.columns = 1
	_unit_list.add_theme_constant_override("v_separation", 12)
	roster_scroll.add_child(_unit_list)
	# 轻量式神竖签，牌池得到主要横向空间。
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(148, 0)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.custom_minimum_size = Vector2(140, 0)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(_detail_box)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	split.add_child(mid)
	_status_l = ThemeBuilder.dim_label("", 12)
	mid.add_child(_status_l)
	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(card_scroll)
	_card_box = HBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 14)
	card_scroll.add_child(_card_box)
	mid.add_child(ThemeBuilder.dim_label("八张构筑 · 点击纸卷中的卡牌调整", 12))
	var scroll_paper := PaperScroll.new()
	scroll_paper.custom_minimum_size = Vector2(0, 182)
	mid.add_child(scroll_paper)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_paper.add_child(deck_scroll)
	_deck_row = HBoxContainer.new()
	_deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_row.add_theme_constant_override("separation", 0)
	deck_scroll.add_child(_deck_row)
	_selected_row = HBoxContainer.new()
	_selected_row.alignment = BoxContainer.ALIGNMENT_END
	_selected_row.add_theme_constant_override("separation", 22)
	_selected_row.visible = not browse_only
	mid.add_child(_selected_row)
	_rebuild_unit_list()
	_show_unit(ContentLoader.unit_def(_focused))

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
		var face := UIWidgets.make_unit_panel(unit, func(u):
			if not browse_only: _toggle(u)
			_show_unit(u)
		, true, _selected.has(unit.id) if not browse_only else unit.id == _focused)
		face.portrait_only = true
		face.custom_minimum_size = Vector2(82, 92)
		face.tooltip_text = str(unit.name)
		_unit_list.add_child(face)
	if units.is_empty(): _unit_list.add_child(ThemeBuilder.dim_label("没有匹配的式神"))
	_confirm_btn.disabled = _selected.size() != PICK_COUNT
	_status_l.text = "式神录 · %d 名" % units.size() if browse_only else "已选 %d / 4 · 每位八张，共三十二张牌" % _selected.size()
	_clear(_selected_row)
	for i in PICK_COUNT:
		if i < _selected.size():
			var unit := ContentLoader.unit_def(_selected[i])
			var face := UIWidgets.unit_token(unit, func(): _show_unit(unit), Vector2(62, 62), "diamond", str(unit.id) == _focused)
			face.custom_minimum_size = Vector2(62, 62)
			_selected_row.add_child(face)
		else:
			var empty := ThemeBuilder.rounded_rect_button("＋", Vector2(62, 62))
			empty.disabled = true
			_selected_row.add_child(empty)

func _toggle(unit: Dictionary) -> void:
	Sfx.play("ui_click", 0.7)
	var uid := str(unit.id)
	if _selected.has(uid): _selected.erase(uid)
	elif _selected.size() < PICK_COUNT: _selected.append(uid)
	else:
		_status_l.text = "阵容已满 · 点选已选式神可移出"
		return
	_rebuild_unit_list()

func _show_unit(unit: Dictionary) -> void:
	if unit.is_empty(): return
	_focused = str(unit.id)
	_clear(_detail_box)
	var portrait := UIWidgets.unit_token(unit, Callable(), Vector2(96, 96), "diamond")
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_box.add_child(portrait)
	_detail_box.add_child(ThemeBuilder.title_label(str(unit.get("name", "")), 24))
	_detail_box.add_child(ThemeBuilder.dim_label(str(unit.get("role", "")), 12))
	_detail_box.add_child(ThemeBuilder.dim_label(ContentLoader.pack_label(str(unit.get("pack", "origin"))), 12))
	for pair in [["被动", ContentLoader.passive_text(unit)], ["觉醒", ContentLoader.passive_text(unit, true)], ["策略", str(unit.get("strategy", ""))]]:
		var label := ThemeBuilder.label(pair[0] + " · " + pair[1], 12, ThemeBuilder.GOLD if pair[0] == "觉醒" else ThemeBuilder.PAPER_DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(label)
	var deck := Button.new()
	deck.text = "构筑卡组（8 张）"
	deck.pressed.connect(func(): edit_deck.emit(_focused))
	_detail_box.add_child(deck)
	_clear(_card_box)
	var cards := ContentLoader.cards_for_unit(_focused).filter(func(card): return not card.get("token", false) and not card.get("skin", false))
	cards.sort_custom(func(a, b): return int(a.get("level", 1)) < int(b.get("level", 1)))
	for card in cards:
		var face := UIWidgets.make_card_tile(card, func(): _inspect_card(card), Vector2(174, 318))
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_card_box.add_child(face)
	_clear(_deck_row)
	var deck_ids := SaveStore.get_deck(_focused)
	if deck_ids.size() != 8: deck_ids = ContentLoader.starter_card_ids(_focused)
	for id in deck_ids:
		var slot := CenterContainer.new()
		slot.custom_minimum_size.x = 92
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_child(UIWidgets.make_card_tile(ContentLoader.card_def(id), func(): edit_deck.emit(_focused), Vector2(82, 136)))
		_deck_row.add_child(slot)

func _inspect_card(card: Dictionary) -> void:
	Sfx.play("ui_click", 0.7)
	UIWidgets.show_card_modal(self, card)

func _switch_slot(slot: int) -> void:
	_drafts[formation_slot] = _selected.duplicate()
	formation_slot = slot
	_selected = _drafts.get(slot, SaveStore.get_formations()[slot].lineup).duplicate()
	_rebuild_unit_list()
	if not _selected.is_empty(): _show_unit(ContentLoader.unit_def(_selected[0]))

func _on_confirm() -> void:
	if _selected.size() == PICK_COUNT and SaveStore.save_formation(formation_slot, _selected):
		confirmed.emit(_selected.duplicate())

func set_preselect(unit_ids: Array) -> void:
	_selected = unit_ids.duplicate()
	_rebuild_unit_list()
	if not _selected.is_empty(): _show_unit(ContentLoader.unit_def(_selected[0]))

func selected_units() -> Array:
	return _selected.duplicate()
