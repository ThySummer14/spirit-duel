extends SceneTree
## Load UI scripts to catch parse errors after QoL edits.

func _init() -> void:
	var paths := [
		"res://scripts/ui/theme_builder.gd",
		"res://scripts/ui/scene_backdrop.gd",
		"res://scripts/ui/card_face.gd",
		"res://scripts/ui/card_hit_area.gd",
		"res://scripts/ui/battle_drop_zone.gd",
		"res://scripts/ui/battle_aim.gd",
		"res://scripts/ui/hand_fan.gd",
		"res://scripts/ui/sfx.gd",
		"res://scripts/ui/keyword_glossary.gd",
		"res://scripts/ui/modal_layer.gd",
		"res://scripts/ui/ui_widgets.gd",
		"res://scripts/ui/formation_screen.gd",
		"res://scripts/ui/battle_screen.gd",
		"res://scripts/ui/main.gd",
		"res://scripts/ui/main_menu.gd",
		"res://scripts/ui/result_screen.gd",
		"res://scripts/ui/deck_builder.gd",
		"res://scripts/ui/codex_screen.gd",
		"res://scripts/save_store.gd",
		"res://scripts/collection_store.gd",
		"res://scripts/ui/collection_screen.gd",
	]
	for path in paths:
		var script = load(path)
		if script == null or not script.can_instantiate():
			printerr("UI_LOAD_FAIL ", path)
			quit(1)
			return
	print("UI_LOAD_OK %d" % paths.size())
	quit(0)
