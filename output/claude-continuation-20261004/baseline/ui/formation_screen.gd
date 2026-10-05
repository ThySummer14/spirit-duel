class_name FormationScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")

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
var _pack_filter := "all"
var _slot_picker: OptionButton
var _drafts: Dictionary = {}

func _ready() -> void:
	theme = ThemeBuilder.build_night_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "table"
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 22
	root.offset_right = -22
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var back := Button.new()
	back.text = "‹ 返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	header.add_child(ThemeBuilder.title_label("式神录" if browse_only else "灵契编组", 28))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	_slot_picker = OptionButton.new()
	for entry in SaveStore.get_formations(): _slot_picker.add_item(str(entry.name))
	_slot_picker.select(formation_slot)
	_slot_picker.item_selected.connect(_switch_slot)
	_slot_picker.visible = not browse_only
	header.add_child(_slot_picker)
	var save := Button.new()
	save.text = "保存阵容"
	save.visible = not browse_only
	save.pressed.connect(func():
		_status_l.text = "阵容已保存" if SaveStore.save_formation(formation_slot, _selected) else "请先选满四名不同式神"
	)
	header.add_child(save)
	_confirm_btn = ThemeBuilder.rounded_rect_button("出 战", Vector2(136, 44))
	_confirm_btn.visible = not browse_only
	_confirm_btn.pressed.connect(_on_confirm)
	header.add_child(_confirm_btn)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(206, 0)
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索式神 / 定位"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): _rebuild_unit_list())
	left.add_child(_search)
	var pack := OptionButton.new()
	for id in ContentLoader.pack_ids(): pack.add_item(ContentLoader.pack_label(id))
	pack.item_selected.connect(func(index):
		_pack_filter = ContentLoader.pack_ids()[index]
		_rebuild_unit_list()
	)
	left.add_child(pack)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(roster_scroll)
	_unit_list = GridContainer.new()
	_unit_list.columns = 2
	_unit_list.add_theme_constant_override("h_separation", 10)
	_unit_list.add_theme_constant_override("v_separation", 10)
	roster_scroll.add_child(_unit_list)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	split.add_child(mid)
	_status_l = ThemeBuilder.dim_label("", 13)
	mid.add_child(_status_l)
	_selected_row = HBoxContainer.new()
	_selected_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_selected_row.add_theme_constant_override("separation", 14)
	_selected_row.visible = not browse_only
	mid.add_child(_selected_row)
	mid.add_child(ThemeBuilder.label("专属卡牌 · 点击检视完整牌文", 14, ThemeBuilder.PAPER))
	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(card_scroll)
	_card_box = HBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 12)
	card_scroll.add_child(_card_box)
	mid.add_child(ThemeBuilder.dim_label("当前式神的八张构筑 · 点击下方卡牌进入构筑", 12))
	var deck_scroll := ScrollContainer.new()
	deck_scroll.custom_minimum_size = Vector2(0, 104)
	deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(deck_scroll)
	_deck_row = HBoxContainer.new()
	_deck_row.add_theme_constant_override("separation", 7)
	deck_scroll.add_child(_deck_row)
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(244, 0)
	right.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color(0.08, 0.085, 0.14, 0.92), Color("71677d"), 4, 1))
	split.add_child(right)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.custom_minimum_size = Vector2(218, 0)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(_detail_box)
	_rebuild_unit_list()
	_show_unit(ContentLoader.unit_def(_focused))

func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _filtered_units() -> Array:
	var q := _search.text.strip_edges().to_lower()
	return ContentLoader.playable_units().filter(func(unit):
		if _pack_filter != "all" and str(unit.get("pack", "origin")) != _pack_filter: return false
		var hay := "%s %s %s %s" % [unit.get("name", ""), unit.get("title", ""), unit.get("role", ""), unit.get("strategy", "")]
		return q == "" or hay.to_lower().contains(q)
	)

func _rebuild_unit_list() -> void:
	_clear(_unit_list)
	var units := _filtered_units()
	for unit in units:
		var face := UIWidgets.make_unit_panel(unit, func(u):
			if not browse_only: _toggle(u)
			_show_unit(u)
		, true, _selected.has(unit.id) if not browse_only else unit.id == _focused)
		face.custom_minimum_size = Vector2(92, 136)
		_unit_list.add_child(face)
	if units.is_empty(): _unit_list.add_child(ThemeBuilder.dim_label("没有匹配的式神"))
	_confirm_btn.disabled = _selected.size() != PICK_COUNT
	_status_l.text = "式神录 · %d 名" % units.size() if browse_only else "已选 %d / 4 · 每位八张，共三十二张牌" % _selected.size()
	_clear(_selected_row)
	for i in PICK_COUNT:
		if i < _selected.size():
			var unit := ContentLoader.unit_def(_selected[i])
			var face := UIWidgets.make_unit_panel(unit, func(u): _show_unit(u), false, str(unit.id) == _focused)
			face.custom_minimum_size = Vector2(116, 176)
			_selected_row.add_child(face)
		else:
			var empty := ThemeBuilder.rounded_rect_button("＋\n选择式神", Vector2(116, 176))
			empty.disabled = true
			_selected_row.add_child(empty)

func _toggle(unit: Dictionary) -> void:
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
	var portrait := UIWidgets.portrait(unit, Vector2(174, 245))
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_box.add_child(portrait)
	_detail_box.add_child(ThemeBuilder.title_label(str(unit.get("title", "")), 20))
	_detail_box.add_child(ThemeBuilder.dim_label(str(unit.get("role", "")), 12))
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
		var face := UIWidgets.make_card_tile(card, func(): _inspect_card(card), Vector2(164, 256))
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_card_box.add_child(face)
	_clear(_deck_row)
	var deck_ids := SaveStore.get_deck(_focused)
	if deck_ids.size() != 8: deck_ids = ContentLoader.starter_card_ids(_focused)
	for id in deck_ids:
		_deck_row.add_child(UIWidgets.make_card_tile(ContentLoader.card_def(id), func(): edit_deck.emit(_focused), Vector2(62, 92)))

func _inspect_card(card: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = str(card.name)
	dialog.dialog_text = "%s · %d勾 · %d鬼火\n\n%s" % [str(card.get("typeLabel", "")), int(card.get("level", 1)), int(card.get("cost", 0)), str(card.get("text", ""))]
	dialog.min_size = Vector2(520, 200)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

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
