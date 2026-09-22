class_name FormationScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
## Pick 4 units from content, review passives and card list, confirm.

signal confirmed(unit_ids: Array)
signal back_requested

const PICK_COUNT := 4

var _selected: Array = []
var _unit_list: VBoxContainer
var _detail_box: VBoxContainer
var _card_box: VBoxContainer
var _confirm_btn: Button
var _status_l: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.INK_1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 16
	root.offset_right = -24
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(ThemeBuilder.title_label("编成", 30))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	_status_l = ThemeBuilder.dim_label("已选 0/%d · 请选择四名角色" % PICK_COUNT)
	root.add_child(_status_l)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root.add_child(split)

	# left: unit grid
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.2
	left_panel.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	split.add_child(left_panel)
	var scroll := ScrollContainer.new()
	left_panel.add_child(scroll)
	_unit_list = VBoxContainer.new()
	_unit_list.add_theme_constant_override("separation", 8)
	_unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_unit_list)

	# middle: detail
	var mid := PanelContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_stretch_ratio = 1.0
	mid.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	split.add_child(mid)
	var mid_v := VBoxContainer.new()
	mid_v.add_theme_constant_override("separation", 6)
	mid.add_child(mid_v)
	mid_v.add_child(ThemeBuilder.label("角色详情", 16, ThemeBuilder.GOLD))
	var dscroll := ScrollContainer.new()
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_v.add_child(dscroll)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 6)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_detail_box)

	# right: cards
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.3
	right.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	split.add_child(right)
	var r_v := VBoxContainer.new()
	r_v.add_theme_constant_override("separation", 6)
	right.add_child(r_v)
	r_v.add_child(ThemeBuilder.label("卡牌一览（按稀有度着色）", 16, ThemeBuilder.GOLD))
	var cscroll := ScrollContainer.new()
	cscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r_v.add_child(cscroll)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 4)
	_card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cscroll.add_child(_card_box)

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(sp2)
	_confirm_btn = ThemeBuilder.rounded_rect_button("确认出战", Vector2(220, 48))
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	footer.add_child(_confirm_btn)

	_rebuild_unit_list()
	_show_unit(ContentLoader.playable_units()[0] if not ContentLoader.playable_units().is_empty() else {})


func _rebuild_unit_list() -> void:
	for c in _unit_list.get_children():
		c.queue_free()
	for unit in ContentLoader.playable_units():
		var row := PanelContainer.new()
		var accent := ThemeBuilder.unit_color_of(unit)
		var picked: bool = _selected.has(unit.id)
		var sb := ThemeBuilder.panel(Color("161d2c") if not picked else Color("2c2413"), ThemeBuilder.GOLD if picked else ThemeBuilder.RULE, 8, 1)
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		h.add_child(ThemeBuilder.chip("选" if picked else "　", ThemeBuilder.GOLD if picked else ThemeBuilder.TEXT_FAINT))
		var name_l := ThemeBuilder.label(str(unit.get("name", "?")), 15, ThemeBuilder.PAPER)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		h.add_child(ThemeBuilder.dim_label(str(unit.get("title", "")), 12))
		h.add_child(ThemeBuilder.chip(str(unit.get("role", "")), accent))
		var info := Button.new()
		info.text = "详情"
		info.pressed.connect(func(): _show_unit(unit))
		h.add_child(info)
		var pick := Button.new()
		pick.text = "选用" if not picked else "移出"
		pick.pressed.connect(func(): _toggle(unit))
		h.add_child(pick)
		_unit_list.add_child(row)
	_status_l.text = "已选 %d/%d · 请点选角色" % [_selected.size(), PICK_COUNT]
	_confirm_btn.disabled = _selected.size() != PICK_COUNT


func _toggle(unit: Dictionary) -> void:
	var uid: String = unit.get("id", "")
	if _selected.has(uid):
		_selected.erase(uid)
	else:
		if _selected.size() >= PICK_COUNT:
			return
		_selected.append(uid)
	_rebuild_unit_list()
	_show_unit(unit)


func _show_unit(unit: Dictionary) -> void:
	if unit.is_empty():
		return
	for c in _detail_box.get_children():
		c.queue_free()
	_detail_box.add_child(ThemeBuilder.label("%s · %s" % [unit.get("name", "?"), unit.get("title", "")], 18, ThemeBuilder.PAPER))
	_detail_box.add_child(ThemeBuilder.dim_label(str(unit.get("role", "")) + " · " + str(unit.get("strategy", "")), 12))
	_detail_box.add_child(ThemeBuilder.label("生命 %d　攻击 %d" % [int(unit.get("maxHp", 0)), int(unit.get("attack", 0))], 14, ThemeBuilder.TEXT))
	_detail_box.add_child(ThemeBuilder.label(ContentLoader.passive_text(unit), 13, ThemeBuilder.GOLD))
	_detail_box.add_child(ThemeBuilder.label(ContentLoader.passive_text(unit, true), 13, ThemeBuilder.GOLD_BRIGHT))
	_detail_box.add_child(ThemeBuilder.dim_label("色标 %s" % str(unit.get("color", "")), 11))

	for c in _card_box.get_children():
		c.queue_free()
	var cards := ContentLoader.cards_for_unit(str(unit.get("id", "")))
	cards.sort_custom(func(a, b):
		var ra := _rarity_rank(str(a.get("rarity", "")))
		var rb := _rarity_rank(str(b.get("rarity", "")))
		if ra != rb:
			return ra > rb
		return int(a.get("level", 0)) < int(b.get("level", 0))
	)
	for card in cards:
		var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var rar := ThemeBuilder.chip(str(card.get("rarity", "")), rarity)
		row.add_child(rar)
		row.add_child(ThemeBuilder.label(str(card.get("name", "?")), 13, rarity))
		row.add_child(ThemeBuilder.dim_label(str(card.get("typeLabel", "")) + " Lv" + str(int(card.get("level", 1))) + " 费" + str(int(card.get("cost", 0))), 11))
		var tip := ThemeBuilder.label(str(card.get("text", "")), 12, ThemeBuilder.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tip)
		_card_box.add_child(row)


func _rarity_rank(r: String) -> int:
	match r:
		"ssr", "legendary":
			return 4
		"epic":
			return 3
		"rare":
			return 2
		_:
			return 1


func _on_confirm() -> void:
	if _selected.size() == PICK_COUNT:
		confirmed.emit(_selected.duplicate())


func set_preselect(unit_ids: Array) -> void:
	_selected = unit_ids.duplicate()
	_rebuild_unit_list()
