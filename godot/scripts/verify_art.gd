extends SceneTree
## 真实卡面控件验收：重绘导入、窄肖像/横向牌图裁切、觉醒和缺图回退。

const ContentLoader := preload("res://scripts/content_loader.gd")
const PortraitLibrary := preload("res://scripts/ui/portrait_library.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")

var _checks := 0
var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("ART_FAIL ", message)

func _run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(PortraitLibrary.MANIFEST_PATH))
	_check(manifest is Dictionary and int(manifest.get("schema", 0)) == 1, "art manifest loads")
	var entries: Dictionary = manifest.get("units", {})
	var classic := ContentLoader.units_in_pack("classic")
	_check(classic.size() == 29, "classic content contains all 29 units")
	_check(classic.all(func(unit): return entries.has(unit.id)), "every classic unit has a redrawn portrait")
	var expected_rosters := {
		"wave2": 9, "wave3": 19, "wave4": 26,
		"wave5": 24, "wave6": 32, "wave7": 25, "wave8": 25,
		"wave9": 27, "wave10": 2, "wave11": 10, "wave12": 8, "wave13": 6, "origin": 8,
	}
	for pack in expected_rosters:
		var units := ContentLoader.units_in_pack(pack)
		_check(units.size() == expected_rosters[pack], "%s contains its expected complete roster" % pack)
		_check(units.all(func(unit): return entries.has(unit.id)), "every %s unit has a redrawn portrait" % pack)
	_check(entries.size() == 250, "all 250 playable units have a redrawn portrait")
	var seen := {}
	for uid in entries:
		var unit := ContentLoader.unit_def(uid)
		_check(not unit.is_empty(), "%s maps to a real playable unit" % uid)
		var face := UIWidgets.make_unit_panel(unit, Callable())
		root.add_child(face)
		var expected := "res://" + str(entries[uid].path)
		_check(face._texture != null and face._texture_path == expected, "%s uses the redrawn PNG in a live unit control" % uid)
		if face._texture == null:
			face.free()
			continue
		var source: Vector2 = face._texture.get_size()
		_check(source.x >= 1024 and source.y >= 1536 and source.y > source.x, "%s imports its full resolution portrait" % uid)
		_check(not seen.has(expected), "%s has an independent character image" % uid)
		seen[expected] = true
		var focus: Vector2 = face._art_focus * source
		for target in [Vector2(96, 140), Vector2(160, 232), Vector2(118, 96), Vector2(226, 182), Vector2(56, 48)]:
			var crop: Rect2 = face.art_source_rect(target)
			_check(Rect2(Vector2.ZERO, source).encloses(crop), "%s crop stays inside its texture" % uid)
			_check(crop.has_point(focus), "%s face focus survives both portrait and card crops" % uid)
			_check(is_equal_approx(crop.size.x / crop.size.y, target.x / target.y), "%s art keeps its proportions" % uid)
		var normal_texture: Texture2D = face._texture
		face.data = unit.duplicate(true)
		face.data.awakened = true
		face.refresh_art()
		_check(face._texture == normal_texture, "%s awakening retains the matching character art" % uid)
		var card: Dictionary = ContentLoader.cards_for_unit(uid)[0]
		var tile := UIWidgets.make_card_tile(card, Callable())
		root.add_child(tile)
		_check(tile._texture == normal_texture, "%s skill card shares the correct owner's redraw" % uid)
		tile.free()
		face.free()
	# 内容导出继续保留原路径；无映射和资源缺失的回退仍可使用。
	var unmapped := ContentLoader.unit_def("ember")
	var unmapped_entry: Dictionary = PortraitLibrary._units.ember
	PortraitLibrary._units.erase("ember")
	_check(PortraitLibrary.artwork(unmapped).path == "res://" + str(unmapped.art), "unmapped units retain existing art")
	_check(PortraitLibrary.artwork(unmapped, true).path == "res://" + str(unmapped.awakenedArt), "unmapped awakening retains its original variant")
	PortraitLibrary._units.ember = unmapped_entry
	var unit := ContentLoader.unit_def("yaodaoji")
	var entry: Dictionary = PortraitLibrary._units.yaodaoji
	PortraitLibrary._units.yaodaoji = {"path": "assets/redrawn/missing-test.png"}
	var fallback := UIWidgets.make_unit_panel(unit, Callable())
	root.add_child(fallback)
	_check(fallback._texture != null and fallback._texture_path == "res://" + str(unit.art), "a missing redraw cannot blank a playable character")
	fallback.free()
	PortraitLibrary._units.yaodaoji = entry
	print("ART checks=%d failures=%d redrawn_units=%d" % [_checks, _failures, entries.size()])
	if _failures == 0: print("ART_OK")
	quit(0 if _failures == 0 else 1)
