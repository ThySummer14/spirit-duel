class_name SaveStore
extends RefCounted
## 本地存档：阵容、每角色 8 张卡组、种子。路径 user://spirit_duel/save.json

const PATH := "user://spirit_duel/save.json"
const ContentLoader := preload("res://scripts/content_loader.gd")


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var text := FileAccess.get_file_as_string(PATH)
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


static func save_data(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute("user://spirit_duel")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func get_lineup() -> Array:
	return load_data().get("lineup", [])


static func set_lineup(unit_ids: Array) -> void:
	var data := load_data()
	data["lineup"] = unit_ids.duplicate()
	save_data(data)


static func get_deck(unit_id: String) -> Array:
	var data := load_data()
	var decks = data.get("decks", {})
	if decks is Dictionary and decks.has(unit_id):
		return decks[unit_id]
	return []


static func set_deck(unit_id: String, card_ids: Array) -> void:
	var data := load_data()
	if not (data.get("decks") is Dictionary):
		data["decks"] = {}
	data["decks"][unit_id] = card_ids.duplicate()
	save_data(data)


static func get_seed() -> int:
	return int(load_data().get("seed", 0))


static func set_seed(value: int) -> void:
	var data := load_data()
	data["seed"] = value
	save_data(data)


static func deck_definition(unit_ids: Array) -> Dictionary:
	## 组装 GameState.create 所需 deck：unitIds + cardIds（缺省用 starter）
	var card_ids: Array = []
	for uid in unit_ids:
		var custom := get_deck(uid)
		if custom.size() == 8:
			card_ids.append_array(custom)
		else:
			card_ids.append_array(ContentLoader.starter_card_ids(uid))
	return {"unitIds": unit_ids.duplicate(), "cardIds": card_ids}
