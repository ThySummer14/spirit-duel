extends SceneTree
const Preferences := preload("res://scripts/ui/display_preferences.gd")
const Main := preload("res://scripts/ui/main.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var fixture := Support.isolate_stores()
	var previous_fps := Engine.max_fps
	var physics_rate := Engine.physics_ticks_per_second
	Preferences.storage_path = fixture.path_join("display.json")
	Preferences._values.clear()
	_check(Preferences.settings() == {"scale": 1.25, "fps": 0, "stats": false}, "default uses supersampling and display refresh without an artificial FPS cap")
	var main := Main.new()
	root.add_child(main)
	main._show_settings()
	await process_frame
	await process_frame
	var pickers := main.find_children("*", "OptionButton", true, false).filter(func(node): return node.get_meta("display_option", "") == "fps")
	_check(pickers.size() == 1, "frame-rate control is available in settings")
	pickers[0].item_selected.emit(2)
	_check(Engine.max_fps == 120, "choosing 120 FPS updates the actual renderer cap")
	Preferences.set_option("scale", 1.0)
	Preferences.set_option("stats", true)
	Preferences._values.clear()
	_check(Preferences.settings().fps == 120 and Preferences.settings().scale == 1.0 and Preferences.settings().stats, "display preferences survive reloading")
	for bad in [-1, 123, "120", null]: Preferences.set_option("fps", bad)
	for bad in [-1, 8, "1.25", NAN]: Preferences.set_option("scale", bad)
	_check(Preferences.settings().fps == 120 and Preferences.settings().scale == 1.0, "invalid frame rates and render scales cannot enter the settings")
	Preferences.set_option("fps", 0)
	_check(Engine.max_fps == 0, "automatic mode removes the optional frame cap")
	_check(Engine.physics_ticks_per_second == physics_rate, "display preferences never change the simulation tick rate")
	await create_timer(0.6).timeout
	_check(main._display_stats.visible and main._display_stats.text.contains("FPS"), "performance display reports actual renderer data")
	main.queue_free()
	Support.cleanup_audio()
	await process_frame
	DirAccess.remove_absolute(Preferences.storage_path)
	Preferences.storage_path = Preferences.PATH
	Preferences._values.clear()
	Engine.max_fps = previous_fps
	Support.cleanup_stores(fixture)
	print("DISPLAY_PREFERENCES checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
