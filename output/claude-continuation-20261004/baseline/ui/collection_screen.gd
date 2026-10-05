class_name CollectionScreen
extends Control
## Buy sealed packs, then reveal exactly once; unfinished reveals survive re-entry.

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const CardFace := preload("res://scripts/ui/card_face.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")
signal back_requested

var _balance_l: Label
var _stats_l: Label
var _reveal_box: HBoxContainer
var _card_box: GridContainer
var _unit_list: OptionButton
var _units: Array = []
var _pack_id := "all"
var _quantity := 1
var _buy_btn: Button
var _open_btn: Button
var _pack_title: Label
var _pack_info: Label
var _probabilities: Label
var _reveal_layer: Control
var _reveal_status: Label
var _finish_btn: Button
var _tabs: TabContainer
var _reveal_busy := false
var _reveal_all_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "table"
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(ThemeBuilder.title_label("秘 闻 阁", 30))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	_balance_l = ThemeBuilder.label("", 20, ThemeBuilder.GOLD_BRIGHT)
	header.add_child(_balance_l)
	var back := Button.new()
	back.text = "‹ 返回"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	_stats_l = ThemeBuilder.dim_label("", 12)
	root.add_child(_stats_l)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color(0.06, 0.07, 0.12, 0.76), Color("71677d"), 4, 1))
	root.add_child(_tabs)
	_build_shop()
	_build_collection()
	_refresh_header()
	_rebuild_cards()
	if not CollectionStore.load_collection().get("pendingReveal", {}).is_empty(): _show_reveal()

func _build_shop() -> void:
	var shop := HBoxContainer.new()
	shop.name = "秘闻商店"
	shop.add_theme_constant_override("separation", 24)
	_tabs.add_child(shop)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(202, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for id in ContentLoader.pack_ids():
		var button := Button.new()
		button.text = ContentLoader.pack_label(id)
		button.custom_minimum_size = Vector2(182, 40)
		button.pressed.connect(func():
			_pack_id = id
			_refresh_header()
		)
		list.add_child(button)
	var display := VBoxContainer.new()
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.alignment = BoxContainer.ALIGNMENT_CENTER
	display.add_theme_constant_override("separation", 18)
	shop.add_child(display)
	_pack_title = ThemeBuilder.title_label("", 32)
	display.add_child(_pack_title)
	var pack := CardFace.new()
	pack.face_down = true
	pack.custom_minimum_size = Vector2(182, 290)
	pack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	display.add_child(pack)
	_pack_info = ThemeBuilder.dim_label("", 13)
	_pack_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display.add_child(_pack_info)
	var order := PanelContainer.new()
	order.custom_minimum_size = Vector2(320, 0)
	order.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color("ede7d7"), Color("a99b84"), 4, 1))
	shop.add_child(order)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	order.add_child(v)
	v.add_child(ThemeBuilder.label("封藏秘闻 · 五张一卷", 21, Color("3b3447")))
	_probabilities = ThemeBuilder.label("", 13, Color("65596d"))
	_probabilities.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_probabilities)
	var quantity := OptionButton.new()
	for n in [1, 5, 10]: quantity.add_item("%d 卷 · %d 御札" % [n, n * int(CollectionStore.RULES.packCost)])
	quantity.item_selected.connect(func(index):
		_quantity = [1, 5, 10][index]
		_refresh_header()
	)
	v.add_child(quantity)
	_buy_btn = ThemeBuilder.rounded_rect_button("", Vector2(270, 46))
	_buy_btn.set_meta("action", "purchase_pack")
	_buy_btn.pressed.connect(_on_purchase)
	v.add_child(_buy_btn)
	_open_btn = ThemeBuilder.rounded_rect_button("", Vector2(270, 46))
	_open_btn.set_meta("action", "open_owned_pack")
	_open_btn.pressed.connect(_on_open_pack)
	v.add_child(_open_btn)
	var hint := ThemeBuilder.label("购买后存入库存\n每次开启一卷 · 已拥有的重复牌自动折算御札", 12, Color("65596d"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)

func _build_collection() -> void:
	var vault := VBoxContainer.new()
	vault.name = "卡牌收藏"
	vault.add_theme_constant_override("separation", 10)
	_tabs.add_child(vault)
	_unit_list = OptionButton.new()
	_units = ContentLoader.playable_units()
	for unit in _units: _unit_list.add_item(str(unit.name))
	_unit_list.item_selected.connect(func(_i): _rebuild_cards())
	vault.add_child(_unit_list)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vault.add_child(scroll)
	_card_box = GridContainer.new()
	_card_box.columns = 6
	_card_box.add_theme_constant_override("h_separation", 14)
	_card_box.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_card_box)

func _refresh_header() -> void:
	var data := CollectionStore.load_collection()
	var held := int(data.get("packInventory", {}).get(_pack_id, 0))
	_balance_l.text = "御札  %d" % int(data.balance)
	_stats_l.text = "已开启 %d 卷 · 史诗保底 %d / 25 · SSR保底 %d / 40" % [int(data.get("packsOpened", 0)), int(data.get("pitySinceEpic", 0)), int(data.get("pitySinceSsr", 0))]
	_pack_title.text = ContentLoader.pack_label(_pack_id)
	_pack_info.text = "秘闻卷 · 库存 %d\n所选资料包的角色专属卡牌" % held
	_buy_btn.text = "购买 %d 卷 · %d 御札" % [_quantity, _quantity * int(CollectionStore.RULES.packCost)]
	_buy_btn.disabled = int(data.balance) < _quantity * int(CollectionStore.RULES.packCost)
	_open_btn.text = "开启一卷 · 持有 %d" % held
	_open_btn.disabled = held <= 0
	var rates := CollectionStore.pack_probabilities(_pack_id)
	_probabilities.text = "常见 %.1f%%　稀有 %.1f%%\n史诗 %.1f%%　SSR %.1f%%\n\n第25卷必得史诗或SSR\n第40卷必得SSR\n保底由所有秘闻卷共同累计" % [float(rates.common) * 100, float(rates.rare) * 100, float(rates.epic) * 100, float(rates.ssr) * 100]

func _on_purchase() -> void:
	var result := CollectionStore.purchase_packs(_pack_id, _quantity)
	_refresh_header()
	_stats_l.text = "已购入 %d 卷，前往开启即可翻牌" % _quantity if result.ok else str(result.error)

func _on_open_pack() -> void:
	var result := CollectionStore.open_owned_pack(_pack_id, int(Time.get_ticks_msec()) & 0x7fffffff)
	_refresh_header()
	if result.ok: _show_reveal()
	else: _stats_l.text = str(result.error)

func _show_reveal() -> void:
	if _reveal_layer != null: _reveal_layer.queue_free()
	_reveal_layer = Control.new()
	_reveal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_reveal_layer)
	var bg := Backdrop.new()
	bg.scene = "summon"
	_reveal_layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reveal_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	center.add_child(v)
	v.add_child(ThemeBuilder.title_label("秘 闻 显 现", 34))
	_reveal_status = ThemeBuilder.dim_label("点击卡背逐张揭晓", 14)
	_reveal_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_reveal_status)
	_reveal_box = HBoxContainer.new()
	_reveal_box.add_theme_constant_override("separation", 18)
	v.add_child(_reveal_box)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	v.add_child(actions)
	_reveal_all_btn = Button.new()
	_reveal_all_btn.text = "全部翻开"
	_reveal_all_btn.pressed.connect(_reveal_all)
	actions.add_child(_reveal_all_btn)
	_finish_btn = ThemeBuilder.rounded_rect_button("收下秘闻", Vector2(220, 46))
	_finish_btn.pressed.connect(func():
		if CollectionStore.finish_reveal():
			_reveal_layer.queue_free()
			_reveal_layer = null
			_refresh_header()
			_rebuild_cards()
	)
	actions.add_child(_finish_btn)
	var leave := Button.new()
	leave.text = "稍后继续"
	leave.pressed.connect(func(): back_requested.emit())
	actions.add_child(leave)
	_render_reveal()

func _render_reveal() -> void:
	for child in _reveal_box.get_children():
		_reveal_box.remove_child(child)
		child.queue_free()
	var pending: Dictionary = CollectionStore.load_collection().get("pendingReveal", {})
	var revealed: Array = pending.get("revealed", [])
	var cards: Array = pending.get("cards", [])
	for i in cards.size():
		var item: Dictionary = cards[i]
		var tile := CardFace.new()
		tile.data = ContentLoader.card_def(str(item.id))
		tile.face_down = not revealed.has(i)
		tile.note = "新入收藏" if int(item.gained) > 0 else "重复 → %d御札" % int(CollectionStore.RULES.dupeValue.get(item.rarity, 5))
		tile.custom_minimum_size = Vector2(164, 272)
		_reveal_box.add_child(tile)
		UIWidgets.attach_click(tile, func(): _flip_reveal(i), revealed.has(i))
	_finish_btn.disabled = revealed.size() != cards.size()
	_reveal_all_btn.disabled = revealed.size() == cards.size() or _reveal_busy
	_reveal_status.text = "%s · 已揭晓 %d / %d · 重复折算 %d 御札" % [ContentLoader.pack_label(str(pending.get("pack", "all"))), revealed.size(), cards.size(), int(pending.get("dust", 0))]

func _flip_reveal(index: int) -> void:
	if _reveal_busy: return
	_reveal_busy = true
	_reveal_all_btn.disabled = true
	var tile := _reveal_box.get_child(index) as Control
	for child in tile.get_children():
		if child is Button: child.disabled = true
	tile.pivot_offset = tile.size / 2
	var tween := create_tween()
	tween.tween_property(tile, "scale:x", 0.02, 0.16)
	tween.tween_callback(func():
		if CollectionStore.reveal_card(index):
			tile.face_down = false
			tile.queue_redraw()
	)
	tween.tween_property(tile, "scale:x", 1.0, 0.2)
	tween.tween_callback(func():
		_reveal_busy = false
		if is_instance_valid(_reveal_box): _render_reveal()
	)

func _reveal_all() -> void:
	if _reveal_busy: return
	for i in 5: CollectionStore.reveal_card(i)
	_render_reveal()

func _rebuild_cards() -> void:
	for child in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()
	if _units.is_empty(): return
	var unit: Dictionary = _units[maxi(0, _unit_list.selected)]
	var data := CollectionStore.load_collection()
	for card in ContentLoader.cards_for_unit(str(unit.id)):
		if card.get("token", false) or card.get("skin", false): continue
		var owned := int(data.owned.get(card.id, 0))
		var v := VBoxContainer.new()
		_card_box.add_child(v)
		v.add_child(UIWidgets.make_card_tile(card, func():
			var dialog := AcceptDialog.new()
			dialog.title = str(card.name)
			dialog.dialog_text = str(card.get("text", ""))
			dialog.min_size = Vector2(500, 190)
			add_child(dialog)
			dialog.confirmed.connect(dialog.queue_free)
			dialog.canceled.connect(dialog.queue_free)
			dialog.popup_centered()
		, Vector2(174, 252), false, "持有 %d / 2" % owned))
		var cost := int(CollectionStore.RULES.craftCost.get(str(card.get("rarity", "common")), 40))
		var craft := Button.new()
		craft.text = "合成 · %d 御札" % cost
		craft.disabled = owned >= 2 or int(data.balance) < cost
		craft.pressed.connect(func():
			var result := CollectionStore.craft_card(str(card.id))
			_refresh_header()
			_rebuild_cards()
			if not result.ok: _stats_l.text = str(result.error)
		)
		v.add_child(craft)
