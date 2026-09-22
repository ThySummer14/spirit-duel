class_name DeckBuilderScreen
extends Control
## 为一名角色挑选 8 张牌（衍生牌不可选；同名上限 2；觉醒限 1）。

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const SaveStore := preload("res://scripts/save_store.gd")

signal deck_confirmed(unit_id: String, card_ids: Array)
signal back_requested

const PICK_COUNT := 8

var _unit_id := ""
var _picked: Array = []
var _pool_box: VBoxContainer
var _status: Label
var _list_scroll: ScrollContainer
var _confirm_btn: Button


func setup(unit_id: String) -> void:
	_unit_id = unit_id
	var saved := SaveStore.get_deck(unit_id)
	if saved.size() == PICK_COUNT:
		_picked = saved.duplicate()
	else:
		_picked = ContentLoader.starter_card_ids(unit_id)


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

	var unit := ContentLoader.unit_def(_unit_id)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(ThemeBuilder.title_label("构筑 · %s" % str(unit.get("name", _unit_id)), 26))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	var reset := Button.new()
	reset.text = "重置为默认"
	reset.pressed.connect(func():
		_picked = ContentLoader.starter_card_ids(_unit_id)
		_rebuild()
	)
	header.add_child(reset)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	_status = ThemeBuilder.dim_label("", 13)
	root.add_child(_status)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	root.add_child(split)

	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 10, 1))
	split.add_child(left)
	_list_scroll = ScrollContainer.new()
	left.add_child(_list_scroll)
	_pool_box = VBoxContainer.new()
	_pool_box.add_theme_constant_override("separation", 6)
	_pool_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_pool_box)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 10, 1))
	split.add_child(side)
	var side_v := VBoxContainer.new()
	side_v.add_theme_constant_override("separation", 8)
	side.add_child(side_v)
	side_v.add_child(ThemeBuilder.label("角色档案", 15, ThemeBuilder.GOLD))
	var tip := ThemeBuilder.label(ContentLoader.passive_text(unit), 12, ThemeBuilder.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_v.add_child(tip)
	_confirm_btn = ThemeBuilder.rounded_rect_button("确认卡组", Vector2(220, 44))
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(func():
		if _picked.size() == PICK_COUNT:
			deck_confirmed.emit(_unit_id, _picked.duplicate())
	)
	side_v.add_child(_confirm_btn)

	_rebuild()


func _count_of(card_id: String) -> int:
	var n := 0
	for id in _picked:
		if id == card_id:
			n += 1
	return n


func _limit_of(card: Dictionary) -> int:
	if card.get("type") == "awakening":
		return 1
	return int(card.get("deckLimit", 2))


func _rebuild() -> void:
	for c in _pool_box.get_children():
		c.queue_free()
	var unit := ContentLoader.unit_def(_unit_id)
	var cards := ContentLoader.cards_for_unit(_unit_id)
	cards = cards.filter(func(card): return not bool(card.get("token", false)) and not bool(card.get("skin", false)))
	cards.sort_custom(func(a, b):
		var la := int(a.get("level", 1))
		var lb := int(b.get("level", 1))
		if la != lb:
			return la < lb
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for card in cards:
		var cid: String = str(card.get("id", ""))
		var have := _count_of(cid)
		var limit := _limit_of(card)
		var row := PanelContainer.new()
		var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
		row.add_theme_stylebox_override("panel", ThemeBuilder.panel(
			Color("2c2413") if have > 0 else Color("161d2c"), rarity, 8, 1))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		h.add_child(ThemeBuilder.chip("%d×" % have, ThemeBuilder.GOLD if have > 0 else ThemeBuilder.TEXT_FAINT))
		var name_l := ThemeBuilder.label(str(card.get("name", "?")), 14, rarity)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		h.add_child(ThemeBuilder.dim_label("Lv%d 费%d /%d" % [int(card.get("level", 1)), int(card.get("cost", 0)), limit], 11))
		var minus := Button.new()
		minus.text = "−"
		minus.disabled = have <= 0
		minus.pressed.connect(func():
			var idx := _picked.find(cid)
			if idx >= 0:
				_picked.remove_at(idx)
				_rebuild()
		)
		h.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.disabled = have >= limit or _picked.size() >= PICK_COUNT
		plus.pressed.connect(func():
			if _picked.size() < PICK_COUNT and have < limit:
				_picked.append(cid)
				_rebuild()
		)
		h.add_child(plus)
		_pool_box.add_child(row)

	_status.text = "%s · 已选 %d/%d" % [str(unit.get("name", _unit_id)), _picked.size(), PICK_COUNT]
	_confirm_btn.disabled = _picked.size() != PICK_COUNT
