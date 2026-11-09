extends RefCounted
## 画质与帧率偏好。渲染倍率仅调整网页画布，不改变逻辑尺寸或规则时钟。

const PATH := "user://spirit_duel/display.json"
const SCALES := [0.75, 1.0, 1.25]
const FPS_LIMITS := [0, 60, 120, 144]
static var storage_path := PATH
static var _values: Dictionary = {}


static func settings() -> Dictionary:
	if _values.is_empty():
		_values = {"scale": 1.25, "fps": 0, "stats": false}
		if FileAccess.file_exists(storage_path):
			var saved = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
			if saved is Dictionary:
				var scale_value = saved.get("scale")
				var fps_value = saved.get("fps")
				if (scale_value is float or scale_value is int) and float(scale_value) in SCALES:
					_values.scale = float(scale_value)
				# JSON numbers reload as floats; validate before converting to an enum.
				if (fps_value is float or fps_value is int) and is_finite(float(fps_value)) and float(fps_value) in [0.0, 60.0, 120.0, 144.0]:
					_values.fps = int(fps_value)
				if saved.get("stats") is bool: _values.stats = saved.stats
	return _values


static func set_option(key: String, value: Variant) -> void:
	if key == "scale" and value not in SCALES: return
	if key == "fps" and value not in FPS_LIMITS: return
	if key == "stats" and not value is bool: return
	if key not in ["scale", "fps", "stats"]: return
	settings()[key] = value
	DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(_values))
	apply()


static func apply() -> void:
	Engine.max_fps = int(settings().fps)
	if OS.has_feature("web"):
		var bridge := JavaScriptBridge.get_interface("duelDisplay")
		if bridge != null: bridge.setScale(float(settings().scale))


static func status() -> String:
	var extent := DisplayServer.window_get_size()
	return "%d × %d · %d FPS" % [extent.x, extent.y, Engine.get_frames_per_second()]
