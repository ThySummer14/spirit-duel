extends SceneTree
## 截图各主界面，便于视觉验收。用法: Godot --path godot --script res://scripts/capture_ui.gd

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const MainMenuScreen := preload("res://scripts/ui/main_menu.gd")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const CodexScreen := preload("res://scripts/ui/codex_screen.gd")
const CollectionScreen := preload("res://scripts/ui/collection_screen.gd")
const DeckBuilderScreen := preload("res://scripts/ui/deck_builder.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ResultScreen := preload("res://scripts/ui/result_screen.gd")

var _root: Control
var _shot_dir := "user://shots"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	root.size = Vector2i(1280, 800)
	_root = Control.new()
	_root.theme = ThemeBuilder.build_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.custom_minimum_size = Vector2(1280, 800)
	root.add_child(_root)
	_capture_all.call_deferred()


func _clear() -> void:
	for c in _root.get_children():
		_root.remove_child(c)
		c.free()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_shot_dir, name]
	img.save_png(path)
	print("SHOT ", path)


func _capture_all() -> void:
	await process_frame
	# 1 menu
	_clear()
	var menu := MainMenuScreen.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(menu)
	await _shot("01-menu")

	# 2 formation
	_clear()
	var form := FormationScreen.new()
	form.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(form)
	form.set_preselect(["ember", "basalt", "lumen", "rime"])
	await _shot("02-formation")

	# 3 deck builder
	_clear()
	var deck := DeckBuilderScreen.new()
	deck.setup("ember")
	deck.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(deck)
	await _shot("03-deck")

	# 4 codex
	_clear()
	var codex := CodexScreen.new()
	codex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(codex)
	await _shot("04-codex")

	# 5 collection
	_clear()
	var col := CollectionScreen.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(col)
	await _shot("05-collection")

	# 6 battle
	_clear()
	var battle := BattleScreen.new()
	battle.setup(["ember", "basalt", "lumen", "rime"], ["storm", "kongo", "frostblade", "ink"], 20260922)
	battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(battle)
	await _shot("06-battle")

	# 7 result
	_clear()
	var result := ResultScreen.new()
	result.setup(true, "种子 20260922 · 回合 12 · 获得 300 御札", [{"c": "play_card", "p": 0}, {"c": "assault", "p": 0}, {"c": "end_turn", "p": 0}])
	result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(result)
	await _shot("07-result")

	print("CAPTURE_DONE")
	quit(0)
