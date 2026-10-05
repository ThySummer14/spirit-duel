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
	bg.dim = 0.08
	bg.motes = 14
	add_child(bg)
	Sfx.music("bgm_menu")
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.06, 0.18)
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
	brand.add_child(ThemeBuilder.outline(ThemeBuilder.title_label("灵 枢 战 线", 34)))
	brand.add_child(ThemeBuilder.outline(ThemeBuilder.dim_label("月汐港  /  灯火下的灵契对弈", 12)))
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
	quit_button.text = "退出"
	quit_button.pressed.connect(func(): quit_requested.emit())
	top.add_child(quit_button)
	_hotspot("阵", "灵契编组", "四式神 · 三十二张牌", Vector2(0.17, 0.47), open_formation)
	_hotspot("卷", "秘闻阁", "购入秘闻 · 揭晓新卡", Vector2(0.73, 0.39), open_collection)
	_hotspot("录", "式神录", "%d 位角色 · 全资料包" % ContentLoader.playable_units().size(), Vector2(0.77, 0.63), open_codex)
	_build_lineup_panel()
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -114
	footer.offset_bottom = -22
	footer.offset_left = 30
	footer.offset_right = -30
	footer.add_theme_stylebox_override("panel", ThemeBuilder.glass(0.86))
	add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	footer.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	copy.add_child(ThemeBuilder.label("灯火不息，灵契再续。", 22, ThemeBuilder.PAPER))
	copy.add_child(ThemeBuilder.dim_label("选择你的四位式神，在月汐之间展开一局对弈。", 13))
	var match_button := ThemeBuilder.primary(ThemeBuilder.rounded_rect_button("开 始 对 弈", Vector2(242, 64)), 22)
	match_button.pressed.connect(func():
		Sfx.play("ui_click")
		start_quick_match.emit()
	)
	row.add_child(match_button)


func _build_lineup_panel() -> void:
	if not ContentLoader.valid_lineup(lineup): lineup = ContentLoader.recommended_lineup()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = -236
	panel.offset_bottom = -128
	panel.add_theme_stylebox_override("panel", ThemeBuilder.glass(0.9))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 6)
	row.add_child(copy)
	copy.add_child(ThemeBuilder.label("当前出战阵容", 13, ThemeBuilder.GOLD))
	_lineup_names = ThemeBuilder.label("", 19)
	_lineup_names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_lineup_names)
	copy.add_child(ThemeBuilder.dim_label("快速对弈使用默认牌组；自选卡组从灵契编组出战。", 12))
	var presets := VBoxContainer.new()
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.custom_minimum_size.x = 202
	row.add_child(presets)
	presets.add_child(ThemeBuilder.dim_label("按资料包试用阵容", 12))
	_preset_picker = OptionButton.new()
	_preset_picker.add_item("当前阵容")
	_preset_picker.set_item_metadata(0, "")
	for pack in ContentLoader.pack_ids():
		if pack == "all": continue
		_preset_picker.add_item("%s · %d 位" % [ContentLoader.pack_label(pack), ContentLoader.units_in_pack(pack).size()])
		_preset_picker.set_item_metadata(_preset_picker.item_count - 1, pack)
	_preset_picker.item_selected.connect(_select_preset)
	presets.add_child(_preset_picker)
	_lineup_faces = HBoxContainer.new()
	_lineup_faces.add_theme_constant_override("separation", 8)
	row.add_child(_lineup_faces)
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
		var face := UIWidgets.make_unit_panel(unit, func(_unit): open_formation.emit(), true)
		face.custom_minimum_size = Vector2(58, 82)
		face.tooltip_text = str(unit.name) + " · 点击自选阵容"
		_lineup_faces.add_child(face)
	_lineup_names.text = " / ".join(names)

func _hotspot(glyph: String, title: String, hint: String, at: Vector2, action: Signal) -> void:
	var button := ThemeBuilder.rounded_rect_button("", Vector2(254, 82))
	button.tooltip_text = title + " · " + hint
	var normal := ThemeBuilder.glass(0.88, Color(ThemeBuilder.GOLD, 0.4), 10)
	var hover := ThemeBuilder.glass(0.96, ThemeBuilder.GOLD, 10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	add_child(button)
	button.anchor_left = at.x
	button.anchor_top = at.y
	button.anchor_right = at.x
	button.anchor_bottom = at.y
	button.offset_left = -127
	button.offset_right = 127
	button.offset_top = -41
	button.offset_bottom = 41
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 12)
	var mark := ThemeBuilder.title_label(glyph, 28)
	mark.custom_minimum_size = Vector2(40, 0)
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 5)
	row.add_child(copy)
	var title_l := ThemeBuilder.title_label(title, 20)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title_l)
	var hint_l := ThemeBuilder.dim_label(hint, 12)
	hint_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(hint_l)
	button.mouse_entered.connect(func(): Sfx.play("ui_hover", 0.4))
	button.pressed.connect(func():
		Sfx.play("ui_click", 0.7)
		action.emit()
	)
