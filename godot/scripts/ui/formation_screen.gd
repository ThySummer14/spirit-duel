class_name FormationScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
## Pick 4 units from content, review passives and card list, confirm.

signal confirmed(unit_ids: Array)
signal back_requested

const PICK_COUNT := 4

var _selected: Array = []
var _unit_list: GridContainer
var _detail_box: VBoxContainer
var _card_box: VBoxContainer
var _confirm_btn: Button
var _status_l: Label
var _search: LineEdit
var _pack_filter := "all"
var _pack_buttons: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.INK_1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 12
	root.offset_right = -20
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(ThemeBuilder.title_label("编成", 28))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	root.add_child(tools)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索式者 / 定位…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _rebuild_unit_list())
	tools.add_child(_search)
	for pack_id in ["all", "origin", "classic", "wave2", "wave3", "wave4", "wave5", "wave6", "wave7", "wave8", "wave9", "wave10", "wave11", "wave12", "wave13"]:
		var b := Button.new()
		b.text = _pack_label(pack_id)
		b.toggle_mode = true
		b.button_group = _pack_buttons
		b.button_pressed = pack_id == "all"
		b.set_meta("pack", pack_id)
		b.pressed.connect(func():
			_pack_filter = pack_id
			_rebuild_unit_list()
		)
		tools.add_child(b)

	_status_l = ThemeBuilder.dim_label("已选 0/%d · 请选择四名角色" % PICK_COUNT)
	root.add_child(_status_l)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	root.add_child(split)

	# left: unit grid
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.35
	left_panel.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	split.add_child(left_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)
	_unit_list = GridContainer.new()
	_unit_list.columns = 3
	_unit_list.add_theme_constant_override("h_separation", 8)
	_unit_list.add_theme_constant_override("v_separation", 8)
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
	right.size_flags_stretch_ratio = 1.25
	right.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 12, 1))
	split.add_child(right)
	var r_v := VBoxContainer.new()
	r_v.add_theme_constant_override("separation", 6)
	right.add_child(r_v)
	r_v.add_child(ThemeBuilder.label("卡牌一览（不含衍生）", 16, ThemeBuilder.GOLD))
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


func _pack_label(pack_id: String) -> String:
	match pack_id:
		"origin":
			return "灵枢原创"
		"classic":
			return "经典包"
		"wave2":
			return "不夜之火"
		"wave3":
			return "月夜沧海"
		"wave4":
			return "吉运善恶"
		"wave5":
			return "繁花喧哗"
		"wave6":
			return "空弦鸣雷"
		"wave7":
			return "燃灯桃源"
		"wave8":
			return "祝星千录"
		"wave9":
			return "龙渊花札"
		"wave10":
			return "鬼灭联动"
		"wave11":
			return "衍生式神"
		"wave12":
			return "灵枢二弹"
		"wave13":
			return "命运抉择"
		_:
			return "全部"


func _filtered_units() -> Array:
	var q := _search.text.strip_edges().to_lower()
	var out: Array = []
	for unit in ContentLoader.playable_units():
		var pack := str(unit.get("pack", "origin"))
		if _pack_filter != "all" and pack != _pack_filter:
			continue
		if q != "":
			var hay := ("%s %s %s %s" % [
				str(unit.get("name", "")), str(unit.get("title", "")),
				str(unit.get("role", "")), str(unit.get("strategy", "")),
			]).to_lower()
			if not hay.contains(q):
				continue
		out.append(unit)
	return out


func _rebuild_unit_list() -> void:
	for c in _unit_list.get_children():
		c.queue_free()
	var units := _filtered_units()
	for unit in units:
		var picked: bool = _selected.has(unit.get("id", ""))
		var accent := ThemeBuilder.unit_color_of(unit)
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 88)
		card.clip_text = true
		var pack_tag := _pack_label(str(unit.get("pack", "origin")))
		card.text = "%s\n%s · %s" % [str(unit.get("name", "?")), pack_tag, str(unit.get("title", ""))]
		if picked:
			card.text = "★ " + card.text
		var sb := ThemeBuilder.panel(
			Color("2c2413") if picked else Color("161d2c"),
			ThemeBuilder.GOLD if picked else accent.lerp(ThemeBuilder.RULE, 0.4),
			10, 1
		)
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("hover", ThemeBuilder.panel(Color("243044"), ThemeBuilder.GOLD_BRIGHT, 10, 1))
		card.add_theme_stylebox_override("pressed", ThemeBuilder.panel(Color("3a3018"), ThemeBuilder.GOLD, 10, 1))
		card.pressed.connect(func():
			_show_unit(unit)
			_toggle(unit)
		)
		_unit_list.add_child(card)
	if units.is_empty():
		_unit_list.add_child(ThemeBuilder.dim_label("没有匹配的角色", 13))
	_status_l.text = "已选 %d/%d · 显示 %d 名 · 请点选角色" % [_selected.size(), PICK_COUNT, units.size()]
	_confirm_btn.disabled = _selected.size() != PICK_COUNT


func _toggle(unit: Dictionary) -> void:
	var uid: String = unit.get("id", "")
	if _selected.has(uid):
		_selected.erase(uid)
	else:
		if _selected.size() >= PICK_COUNT:
			_status_l.text = "已满 4 人，先移出再选新角色"
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
	_detail_box.add_child(ThemeBuilder.chip(_pack_label(str(unit.get("pack", "origin"))), ThemeBuilder.GOLD))
	_detail_box.add_child(ThemeBuilder.dim_label(str(unit.get("role", "")) + " · " + str(unit.get("strategy", "")), 12))
	_detail_box.add_child(ThemeBuilder.label("生命 %d　攻击 %d" % [int(unit.get("maxHp", 0)), int(unit.get("attack", 0))], 14, ThemeBuilder.TEXT))
	_detail_box.add_child(ThemeBuilder.label("被动 · " + ContentLoader.passive_text(unit), 13, ThemeBuilder.GOLD))
	_detail_box.add_child(ThemeBuilder.label("觉醒 · " + ContentLoader.passive_text(unit, true), 13, ThemeBuilder.GOLD_BRIGHT))
	var official := str(unit.get("officialAbility", unit.get("officialText", "")))
	if official != "":
		_detail_box.add_child(ThemeBuilder.dim_label("原案：" + official, 11))

	for c in _card_box.get_children():
		c.queue_free()
	var cards := ContentLoader.cards_for_unit(str(unit.get("id", "")))
	cards = cards.filter(func(card): return not bool(card.get("token", false)))
	cards.sort_custom(func(a, b):
		var ra := _rarity_rank(str(a.get("rarity", "")))
		var rb := _rarity_rank(str(b.get("rarity", "")))
		if ra != rb:
			return ra > rb
		return int(a.get("level", 0)) < int(b.get("level", 0))
	)
	for card in cards:
		var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		row.add_child(head)
		head.add_child(ThemeBuilder.chip(str(card.get("rarity", "")), rarity))
		head.add_child(ThemeBuilder.label(str(card.get("name", "?")), 13, rarity))
		head.add_child(ThemeBuilder.dim_label(str(card.get("typeLabel", "")) + " Lv" + str(int(card.get("level", 1))) + " 费" + str(int(card.get("cost", 0))), 11))
		var tip := ThemeBuilder.label(str(card.get("text", "")), 12, ThemeBuilder.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tip)
		var official_c := str(card.get("officialText", ""))
		if official_c != "" and official_c != str(card.get("text", "")):
			var o := ThemeBuilder.dim_label("原案：" + official_c, 10)
			o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(o)
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
