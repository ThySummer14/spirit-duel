class_name SaveStore
extends RefCounted
## 本地存档：阵容、每角色 8 张卡组、种子。路径 user://spirit_duel/save.json

const PATH := "user://spirit_duel/save.json"
const ContentLoader := preload("res://scripts/content_loader.gd")
static var storage_path: String = PATH


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(storage_path):
		return {}
	var text := FileAccess.get_file_as_string(storage_path)
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


static func save_data(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var f := FileAccess.open(storage_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func get_lineup() -> Array:
	return ContentLoader.restore_legacy_lineup(load_data().get("lineup", []))


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


static func deck_card_limit(card: Dictionary, owner: String, picked: Array, lineup: Array, drafts: Dictionary = {}) -> int:
	if card.get("type") == "awakening": return 1
	if card.get("type") != "coop": return int(card.get("deckLimit", 2))
	if picked.any(func(id): return id != card.id and ContentLoader.card_def(str(id)).get("type") == "coop"):
		return 0
	var used := 0
	for partner in ContentLoader.card_unit_ids(card):
		if partner != owner and partner in lineup:
			var other_deck: Array = drafts[partner] if drafts.has(partner) else get_deck(partner)
			used += other_deck.count(card.id)
	return maxi(0, 2 - used)


static func deck_definition(unit_ids: Array, drafts: Dictionary = {}) -> Dictionary:
	## 组装 GameState.create 所需 deck：unitIds + cardIds（缺省用 starter）
	var card_ids: Array = []
	var slot_owners: Array = []
	for uid in unit_ids:
		var custom: Array = drafts[uid] if drafts.has(uid) else get_deck(uid)
		var cards := custom if custom.size() == 8 else ContentLoader.starter_card_ids(uid)
		for id in cards:
			card_ids.append(id)
			slot_owners.append(uid)
	return {"unitIds": unit_ids.duplicate(), "cardIds": card_ids, "slotOwners": slot_owners}


static func get_formations(restore_legacy: bool = true) -> Array:
	var stored: Array = load_data().get("formations", [])
	var out: Array = []
	for i in 5:
		var slot: Dictionary = stored[i] if i < stored.size() and stored[i] is Dictionary else {"name": "阵容" + ["一", "二", "三", "四", "五"][i], "lineup": []}
		if restore_legacy: slot.lineup = ContentLoader.restore_legacy_lineup(slot.get("lineup", []))
		out.append(slot)
	return out


static func save_formation(slot: int, lineup: Array, drafts: Dictionary = {}, activate := false) -> bool:
	if slot < 0 or slot >= 5 or not ContentLoader.valid_lineup(lineup):
		return false
	var unique := {}
	for uid in lineup:
		if ContentLoader.unit_def(str(uid)).is_empty() or unique.has(uid):
			return false
		unique[uid] = true
	var data := load_data()
	var formations := get_formations(false)
	formations[slot].lineup = lineup.duplicate()
	data.formations = formations
	if activate: data.lineup = lineup.duplicate()
	if not drafts.is_empty():
		var decks: Dictionary = data.get("decks", {}) if data.get("decks") is Dictionary else {}
		for uid in lineup:
			if not drafts.has(uid): continue
			if drafts[uid].size() != 8: return false
			decks[uid] = drafts[uid].duplicate()
		data.decks = decks
	return save_data(data)
