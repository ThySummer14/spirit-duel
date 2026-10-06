class_name MainMenuScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
signal start_quick_match
signal lineup_selected(unit_ids: Array)
signal open_formation
signal open_codex
signal open_collection
signal open_settings
signal quit_requested

var lineup: Array = []
var _lineup_names: Label
var _lineup_faces: HBoxContainer
var _preset_picker: OptionButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "port"
	bg.dim = 0.0
	bg.motes = 14
	add_child(bg)
	Sfx.music("bgm_menu")
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.06, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 30
	top.offset_right = -30
	top.offset_top = 22
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 2)
	top.add_child(brand)
	brand.add_child(ThemeBuilder.outline(ThemeBuilder.title_label("灵 枢 战 线", 28), 3))
	brand.add_child(ThemeBuilder.outline(ThemeBuilder.dim_label("月汐街 · 灯火下的灵契对弈", 11), 2))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(space)
	var balance := ThemeBuilder.label("御札 %d" % int(CollectionStore.load_collection().balance), 16, ThemeBuilder.GOLD_BRIGHT)
	top.add_child(balance)
	var settings := ThemeBuilder.ghost(Button.new())
	settings.text = "设置"
	settings.pressed.connect(func(): open_settings.emit())
	top.add_child(settings)
	var quit_button := ThemeBuilder.ghost(Button.new())
	quit_button.text = "返回旧版" if OS.has_feature("web") else "退出"
	quit_button.pressed.connect(func(): quit_requested.emit())
	top.add_child(quit_button)
	_hotspot("阵", "阵容", "四式神 · 三十二张牌", Vector2(0.20, 0.50), open_formation)
	_hotspot("卷", "秘闻阁", "购入秘闻 · 揭晓新卡", Vector2(0.75, 0.38), open_collection)
	_hotspot("录", "式神录", "%d 位角色 · 全资料包" % ContentLoader.playable_units().size(), Vector2(0.40, 0.39), open_codex)
	_build_lineup_panel()
	var match_button := ThemeBuilder.rounded_rect_button("对 弈", Vector2(132, 132))
	match_button.set_meta("action", "start_quick_match")
	match_button.add_theme_font_override("font", ThemeBuilder.heavy_display_font())
	match_button.add_theme_font_size_override("font_size", 29)
	for state in ["normal", "hover", "pressed"]:
		var plate := ThemeBuilder.panel(Color("bb4750") if state == "normal" else Color("cd6364"), Color("e3d8b3"), 68, 2)
		plate.shadow_color = Color(0.12, 0.06, 0.15, 0.28)
		plate.shadow_size = 8
		match_button.add_theme_stylebox_override(state, plate)
	match_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	match_button.offset_left = -222
	match_button.offset_right = -90
	match_button.offset_top = -178
	match_button.offset_bottom = -46
	match_button.pressed.connect(func():
		Sfx.play("ui_click")
		start_quick_match.emit()
	)
	add_child(match_button)


func _build_lineup_panel() -> void:
	if not ContentLoader.valid_lineup(lineup): lineup = ContentLoader.recommended_lineup()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 26
	panel.offset_right = 566
	panel.offset_top = -148
	panel.offset_bottom = -20
	var sb := ThemeBuilder.glass(0.43, Color(0.85, 0.77, 0.56, 0.20), 2)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_lineup_faces = HBoxContainer.new()
	_lineup_faces.add_theme_constant_override("separation", 8)
	row.add_child(_lineup_faces)
	var presets := VBoxContainer.new()
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(presets)
	presets.add_child(ThemeBuilder.label("出战阵容", 12, ThemeBuilder.PAPER))
	_preset_picker = OptionButton.new()
	_preset_picker.fit_to_longest_item = false
	_preset_picker.add_theme_font_size_override("font_size", 12)
	_preset_picker.add_item("当前阵容")
	_preset_picker.set_item_metadata(0, "")
	for pack in ContentLoader.pack_ids():
		if pack == "all": continue
		_preset_picker.add_item("%s · %d 位" % [ContentLoader.pack_label(pack), ContentLoader.units_in_pack(pack).size()])
		_preset_picker.set_item_metadata(_preset_picker.item_count - 1, pack)
	_preset_picker.item_selected.connect(_select_preset)
	presets.add_child(_preset_picker)
	_lineup_names = ThemeBuilder.label("", 12, ThemeBuilder.PAPER)
	_lineup_names.clip_text = true
	v.add_child(_lineup_names)
	_refresh_lineup()


func _select_preset(index: int) -> void:
	var pack := str(_preset_picker.get_item_metadata(index))
	if pack.is_empty(): return
	lineup = ContentLoader.recommended_lineup(pack)
	_refresh_lineup()
	lineup_selected.emit(lineup.duplicate())
	Sfx.play("ui_click", 0.7)


func _refresh_lineup() -> void:
	var names := PackedStringArray()
	for child in _lineup_faces.get_children():
		_lineup_faces.remove_child(child)
		child.queue_free()
	for uid in lineup:
		var unit := ContentLoader.unit_def(str(uid))
		names.append(str(unit.name))
		var face := UIWidgets.unit_token(unit, func(): open_formation.emit(), Vector2(58, 58), "diamond")
		face.custom_minimum_size = Vector2(58, 58)
		face.tooltip_text = str(unit.name) + " · 点击自选阵容"
		_lineup_faces.add_child(face)
	_lineup_names.text = " / ".join(names)

func _hotspot(glyph: String, title: String, hint: String, at: Vector2, action: Signal) -> void:
	var button := ThemeBuilder.rounded_rect_button("", Vector2(110, 136))
	button.tooltip_text = title + " · " + hint
	for state in ["normal", "pressed", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", ThemeBuilder.panel(Color(0.9, 0.82, 0.6, 0.08), Color.TRANSPARENT, 54, 0))
	add_child(button)
	button.anchor_left = at.x
	button.anchor_top = at.y
	button.anchor_right = at.x
	button.anchor_bottom = at.y
	button.offset_left = -55
	button.offset_right = 55
	button.offset_top = -68
	button.offset_bottom = 68
	var unit_id := "ember" if glyph == "阵" else ("lumen" if glyph == "卷" else "basalt")
	var token := UIWidgets.unit_token(ContentLoader.unit_def(unit_id), Callable(), Vector2(68, 68), "circle")
	token.position = Vector2(21, 8)
	token.size = Vector2(68, 68)
	button.add_child(token)
	var cord := Control.new()
	cord.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cord.size = Vector2(110, 100)
	cord.draw.connect(func():
		cord.draw_arc(Vector2(55, 42), 39, -2.8, 2.8, 40, Color("e3d4ae"), 1.5, true)
		cord.draw_line(Vector2(55, 76), Vector2(55, 83), Color("e5c38a"), 2, true)
	)
	button.add_child(cord)
	var title_l := ThemeBuilder.title_label(title, 22)
	ThemeBuilder.outline(title_l, 3, Color("342a2a"))
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.position = Vector2(0, 83)
	title_l.size = Vector2(110, 34)
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title_l)
	button.mouse_entered.connect(func(): Sfx.play("ui_hover", 0.4))
	button.pressed.connect(func():
		Sfx.play("ui_click", 0.7)
		action.emit()
	)
