extends SceneTree
## Load UI scripts to catch parse errors after QoL edits.

func _init() -> void:
	var paths := [
		"res://scripts/ui/theme_builder.gd",
		"res://scripts/ui/ui_widgets.gd",
		"res://scripts/ui/formation_screen.gd",
		"res://scripts/ui/battle_screen.gd",
		"res://scripts/ui/main.gd",
		"res://scripts/ui/main_menu.gd",
		"res://scripts/ui/result_screen.gd",
	]
	for path in paths:
		var script = load(path)
		if script == null:
			printerr("UI_LOAD_FAIL ", path)
			quit(1)
			return
	print("UI_LOAD_OK %d" % paths.size())
	quit(0)
