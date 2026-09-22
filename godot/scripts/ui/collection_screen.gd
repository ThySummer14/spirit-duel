class_name CollectionScreen
extends Control
## 秘闻阁：御札、开包、按角色浏览收藏。

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")

signal back_requested

var _balance_l: Label
var _stats_l: Label
var _reveal_box: HBoxContainer
var _card_box: VBoxContainer
var _unit_list: OptionButton
var _units: Array = []
var _pack_seed := 0


func _ready() -> void:
	theme = ThemeBuilder.build_washi_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.WASHI_BG
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
	header.add_child(ThemeBuilder.washi_title("秘闻阁", 34))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	_balance_l = ThemeBuilder.label("御札 0", 16, ThemeBuilder.GOLD_BRIGHT)
	header.add_child(_balance_l)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	_stats_l = ThemeBuilder.dim_label("", 12)
	root.add_child(_stats_l)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var open := ThemeBuilder.rounded_rect_button("开启秘闻卷（100）", Vector2(220, 44))
	open.pressed.connect(_on_open_pack)
	actions.add_child(open)
	_unit_list = OptionButton.new()
	_unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_unit_list)

	_reveal_box = HBoxContainer.new()
	_reveal_box.add_theme_constant_override("separation", 8)
	root.add_child(_reveal_box)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ThemeBuilder.washi_panel(12, false))
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 4)
	_card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_card_box)

	_units = ContentLoader.playable_units()
	for u in _units:
		_unit_list.add_item(str(u.get("name", u.id)))
	_unit_list.item_selected.connect(func(_i): _rebuild_cards())
	if not _units.is_empty():
		_unit_list.select(0)
	_rebuild_cards()
	_refresh_header()


func _refresh_header() -> void:
	var data := CollectionStore.load_collection()
	_balance_l.text = "御札 %d" % int(data.get("balance", 0))
	_stats_l.text = "开包 %d · 胜 %d / 负 %d · 收藏统计见下表" % [
		int(data.get("packsOpened", 0)), int(data.get("wins", 0)), int(data.get("losses", 0)),
	]


func _on_open_pack() -> void:
	_pack_seed = (Time.get_ticks_msec() as int) & 0x7fffffff
	var result := CollectionStore.open_pack(_pack_seed)
	_refresh_header()
	for c in _reveal_box.get_children():
		c.queue_free()
	if not result.get("ok", false):
		_reveal_box.add_child(ThemeBuilder.label(str(result.get("error", "")), 13, ThemeBuilder.DANGER_SOFT))
		return
	for item in result.get("cards", []):
		var rarity := ThemeBuilder.rarity_color_of(str(item.get("rarity", "common")))
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color("1a2133"), rarity, 8, 1))
		tile.custom_minimum_size = Vector2(140, 72)
		var v := VBoxContainer.new()
		tile.add_child(v)
		v.add_child(ThemeBuilder.label(str(item.get("name", "?")), 13, rarity))
		v.add_child(ThemeBuilder.dim_label(str(item.get("rarity", "")), 11))
		if int(item.get("gained", 0)) == 1:
			v.add_child(ThemeBuilder.chip("新入", ThemeBuilder.GOLD_BRIGHT))
		else:
			v.add_child(ThemeBuilder.chip("重复→御札", ThemeBuilder.TEXT_FAINT))
		_reveal_box.add_child(tile)
	_rebuild_cards()


func _rebuild_cards() -> void:
	for c in _card_box.get_children():
		c.queue_free()
	if _units.is_empty():
		return
	var idx := _unit_list.selected
	if idx < 0 or idx >= _units.size():
		idx = 0
	var unit: Dictionary = _units[idx]
	var data := CollectionStore.load_collection()
	var owned: Dictionary = data.get("owned", {})
	var cards := ContentLoader.cards_for_unit(str(unit.get("id", "")))
	cards = cards.filter(func(card): return not bool(card.get("token", false)))
	cards.sort_custom(func(a, b):
		return int(a.get("level", 1)) < int(b.get("level", 1))
	)
	for card in cards:
		var cid: String = str(card.get("id", ""))
		var have := int(owned.get(cid, 0))
		var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(ThemeBuilder.chip("%d/2" % have, ThemeBuilder.GOLD if have > 0 else ThemeBuilder.TEXT_FAINT))
		var nm := str(card.get("name", "?"))
		if bool(card.get("skin", false)):
			nm += "·皮肤"
		row.add_child(ThemeBuilder.label(nm, 13, rarity))
		row.add_child(ThemeBuilder.dim_label(str(card.get("typeLabel", "")), 11))
		var craft := Button.new()
		craft.text = "合成 %d" % int(CollectionStore.RULES.craftCost.get(str(card.get("rarity", "common")), 40))
		craft.disabled = have >= 2
		craft.pressed.connect(func():
			var r := CollectionStore.craft_card(cid)
			_refresh_header()
			_rebuild_cards()
			if not r.get("ok", false):
				_reveal_box.add_child(ThemeBuilder.label(str(r.get("error", "")), 12, ThemeBuilder.DANGER_SOFT))
		)
		row.add_child(craft)
		_card_box.add_child(row)
