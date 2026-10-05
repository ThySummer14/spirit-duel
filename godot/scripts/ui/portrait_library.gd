extends RefCounted
## Godot 专用角色重绘映射，不改变同源角色数据或规则。

const MANIFEST_PATH := "res://assets/redrawn/portraits.json"
static var _loaded := false
static var _units: Dictionary = {}


static func artwork(unit: Dictionary, awakened: bool = false) -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(MANIFEST_PATH):
			var payload = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
			if payload is Dictionary and int(payload.get("schema", 0)) == 1 and payload.get("units") is Dictionary:
				_units = payload.units
	var entry = _units.get(str(unit.get("id", "")), {})
	if entry is Dictionary:
		var path := "res://" + str(entry.get("path", "")).trim_prefix("res://")
		if path != "res://" and ResourceLoader.exists(path):
			var focus = entry.get("focus", [0.5, 0.3])
			if not (focus is Array) or focus.size() != 2:
				focus = [0.5, 0.3]
			return {"path": path, "focus": Vector2(clampf(float(focus[0]), 0, 1), clampf(float(focus[1]), 0, 1))}
	return {"path": "res://" + str(unit.get("awakenedArt" if awakened else "art", "assets/ink.svg")).trim_prefix("res://"), "focus": Vector2(-1, -1)}
