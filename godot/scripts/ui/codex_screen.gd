class_name CodexScreen
extends Control
## 图鉴：浏览全部式神与卡表（按资料包筛选/搜索）。

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")

signal back_requested

var _unit_list: VBoxContainer
var _detail: VBoxContainer
var _card_box: VBoxContainer
var _search: LineEdit
var _pack := "all"
var _pack_btns: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.INK_1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 10
	root.offset_right = -16
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(ThemeBuilder.title_label("图鉴", 28))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	root.add_child(tools)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索式神 / 卡牌…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _rebuild_units())
	tools.add_child(_search)
	for pack_id in ["all", "origin", "classic", "wave2", "wave3", "wave4", "wave5", "wave6", "wave7", "wave8", "wave9", "wave10", "wave11", "wave12", "wave13"]:
		var b := Button.new()
		b.text = _pack_label(pack_id)
		b.toggle_mode = true
		b.button_group = _pack_btns
		b.button_pressed = pack_id == "all"
		b.pressed.connect(func():
			_pack = pack_id
			_rebuild_units()
		)
		tools.add_child(b)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	root.add_child(split)

	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(240, 0)
	lp.size_flags_stretch_ratio = 0.9
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 8, 1))
	split.add_child(lp)
	var ls := ScrollContainer.new()
	lp.add_child(ls)
	_unit_list = VBoxContainer.new()
	_unit_list.add_theme_constant_override("separation", 4)
	_unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_unit_list)

	var mp := PanelContainer.new()
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp.size_flags_stretch_ratio = 1.1
	mp.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 8, 1))
	split.add_child(mp)
	var ms := ScrollContainer.new()
	mp.add_child(ms)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 6)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ms.add_child(mv)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	mv.add_child(_detail)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 4)
	mv.add_child(_card_box)

	_rebuild_units()
	_show_unit(ContentLoader.playable_units()[0] if not ContentLoader.playable_units().is_empty() else {})


func _pack_label(pack_id: String) -> String:
	match pack_id:
		"origin": return "原创"
		"classic": return "经典"
		"wave2": return "不夜"
		"wave3": return "月沧"
		"wave4": return "吉善"
		"wave5": return "繁喧"
		"wave6": return "空鸣"
		"wave7": return "燃桃"
		"wave8": return "祝千"
		"wave9": return "龙花"
		"wave10": return "鬼灭"
		"wave11": return "衍生"
		"wave12": return "二弹"
		"wave13": return "命运"
		_: return "全部"


func _filtered_units() -> Array:
	var q := _search.text.strip_edges().to_lower()
	var out: Array = []
	for unit in ContentLoader.playable_units():
		var pack := str(unit.get("pack", "origin"))
		if _pack != "all" and pack != _pack:
			continue
		if q != "":
			var hay := ("%s %s %s" % [str(unit.get("name", "")), str(unit.get("title", "")), str(unit.get("role", ""))]).to_lower()
			var hit := hay.contains(q)
			if not hit:
				for card in ContentLoader.cards_for_unit(unit.id):
					if str(card.get("name", "")).to_lower().contains(q):
						hit = true
						break
			if not hit:
				continue
		out.append(unit)
	return out


func _rebuild_units() -> void:
	for c in _unit_list.get_children():
		c.queue_free()
	var units := _filtered_units()
	for unit in units:
		var b := Button.new()
		b.text = str(unit.get("name", "?"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _show_unit(unit))
		_unit_list.add_child(b)
	if units.is_empty():
		_unit_list.add_child(ThemeBuilder.dim_label("无匹配", 12))


func _show_unit(unit: Dictionary) -> void:
	if unit.is_empty():
		return
	for c in _detail.get_children():
		c.queue_free()
	for c in _card_box.get_children():
		c.queue_free()
	_detail.add_child(ThemeBuilder.label("%s · %s" % [unit.get("name", "?"), unit.get("title", "")], 18, ThemeBuilder.PAPER))
	_detail.add_child(ThemeBuilder.dim_label("%s · %s" % [_pack_label(str(unit.get("pack", "origin"))), str(unit.get("role", ""))], 12))
	_detail.add_child(ThemeBuilder.label("攻 %d　命 %d" % [int(unit.get("attack", 0)), int(unit.get("maxHp", 0))], 13, ThemeBuilder.TEXT))
	var pt := ThemeBuilder.label("被动 · " + ContentLoader.passive_text(unit), 12, ThemeBuilder.GOLD)
	pt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(pt)
	var at := ThemeBuilder.label("觉醒 · " + ContentLoader.passive_text(unit, true), 12, ThemeBuilder.GOLD_BRIGHT)
	at.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(at)

	var cards := ContentLoader.cards_for_unit(str(unit.get("id", "")))
	cards.sort_custom(func(a, b):
		var la := int(a.get("level", 1))
		var lb := int(b.get("level", 1))
		if la != lb:
			return la < lb
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for card in cards:
		if bool(card.get("token", false)):
			continue
		var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
		var row := VBoxContainer.new()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		row.add_child(head)
		head.add_child(ThemeBuilder.chip(str(card.get("rarity", "")), rarity))
		var nm := str(card.get("name", "?"))
		if bool(card.get("skin", false)):
			nm += "（皮肤）"
		head.add_child(ThemeBuilder.label(nm, 13, rarity))
		head.add_child(ThemeBuilder.dim_label("%s Lv%d 费%d" % [str(card.get("typeLabel", "")), int(card.get("level", 1)), int(card.get("cost", 0))], 11))
		var tip := ThemeBuilder.label(str(card.get("text", "")), 12, ThemeBuilder.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(tip)
		_card_box.add_child(row)
