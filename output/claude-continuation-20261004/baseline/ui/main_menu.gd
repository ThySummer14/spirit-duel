class_name MainMenuScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Backdrop := preload("res://scripts/ui/scene_backdrop.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")
signal start_quick_match
signal open_formation
signal open_codex
signal open_collection
signal open_settings
signal quit_requested

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.scene = "port"
	add_child(bg)
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
	top.add_child(ThemeBuilder.title_label("灵 枢 战 线", 36))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(space)
	var balance := ThemeBuilder.label("御札 %d" % int(CollectionStore.load_collection().balance), 16, ThemeBuilder.GOLD_BRIGHT)
	top.add_child(balance)
	var settings := Button.new()
	settings.text = "设置"
	settings.pressed.connect(func(): open_settings.emit())
	top.add_child(settings)
	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.pressed.connect(func(): quit_requested.emit())
	top.add_child(quit_button)
	_hotspot("灵契编组", "四式神 · 三十二张牌", Vector2(0.16, 0.47), open_formation)
	_hotspot("秘闻阁", "购入秘闻 · 揭晓新卡", Vector2(0.72, 0.39), open_collection)
	_hotspot("式神录", "角色档案 · 专属卡牌", Vector2(0.77, 0.63), open_codex)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -114
	footer.offset_bottom = -22
	footer.offset_left = 30
	footer.offset_right = -30
	footer.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color(0.04, 0.07, 0.12, 0.9), Color("6b6661"), 4, 1))
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
	var match_button := ThemeBuilder.rounded_rect_button("开 始 对 弈", Vector2(242, 64))
	match_button.pressed.connect(func(): start_quick_match.emit())
	row.add_child(match_button)

func _hotspot(title: String, hint: String, at: Vector2, action: Signal) -> void:
	var button := ThemeBuilder.rounded_rect_button(title + "\n" + hint, Vector2(218, 76))
	button.add_theme_font_override("font", ThemeBuilder.display_font())
	button.add_theme_font_size_override("font_size", 20)
	add_child(button)
	button.anchor_left = at.x
	button.anchor_top = at.y
	button.anchor_right = at.x
	button.anchor_bottom = at.y
	button.offset_left = -109
	button.offset_right = 109
	button.offset_top = -38
	button.offset_bottom = 38
	button.pressed.connect(func(): action.emit())
