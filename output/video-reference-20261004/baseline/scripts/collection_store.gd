class_name CollectionStore
extends RefCounted
## 秘闻阁收藏：御札、开包、合成。持久化 user://spirit_duel/collection.json

const ContentLoader := preload("res://scripts/content_loader.gd")
const PATH := "user://spirit_duel/collection.json"
static var storage_path: String = PATH

const RULES := {
	"version": 2,
	"packSize": 5,
	"packCost": 100,
	"startingBalance": 300,
	"maxCopies": 2,
	"winReward": 300,
	"lossReward": 150,
	"pityLimit": 25,
	"ssrPityLimit": 40,
	"dupeValue": {"common": 5, "rare": 25, "epic": 100, "ssr": 400},
	"craftCost": {"common": 40, "rare": 120, "epic": 400, "ssr": 2400},
	"rarityWeights": {"common": 0.585, "rare": 0.33, "epic": 0.06, "ssr": 0.025},
}

static func _default() -> Dictionary:
	var owned := {}
	for card in ContentLoader.load_content().get("cards", []):
		if int(card.get("starterCopies", 0)) > 0 and not bool(card.get("token", false)):
			owned[str(card.id)] = int(mini(2, int(card.get("deckLimit", 2))))
	return {
		"version": int(RULES.version),
		"balance": int(RULES.startingBalance),
		"owned": owned,
		"packsOpened": 0,
		"pitySinceEpic": 0,
		"pitySinceSsr": 0,
		"wins": 0,
		"losses": 0,
	}


static func load_collection() -> Dictionary:
	if not FileAccess.file_exists(storage_path):
		var d := _default()
		save_collection(d)
		return d
	var text := FileAccess.get_file_as_string(storage_path)
	var data = JSON.parse_string(text)
	if data is Dictionary and data.has("owned"):
		if int(data.get("version", 1)) == 1:
			# v1 counted individual cards; completed packs since a hit are floor(n/5).
			data.pitySinceSsr = floori(float(data.get("pitySinceSsr", 0)) / float(RULES.packSize))
			data.pitySinceEpic = mini(floori(float(data.get("pitySinceEpic", 0)) / float(RULES.packSize)), int(data.pitySinceSsr))
			data.version = int(RULES.version)
			save_collection(data)
		return data
	return _default()


static func save_collection(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var f := FileAccess.open(storage_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func owned_copies(card_id: String) -> int:
	return int(load_collection().get("owned", {}).get(card_id, 0))


static func _roll_rarity(data: Dictionary, rng: RandomNumberGenerator) -> String:
	if int(data.get("pitySinceSsr", 0)) + 1 >= int(RULES.ssrPityLimit):
		return "ssr"
	if int(data.get("pitySinceEpic", 0)) + 1 >= int(RULES.pityLimit):
		return "epic"
	var roll := rng.randf()
	var w: Dictionary = RULES.rarityWeights
	var acc := 0.0
	for key in ["common", "rare", "epic", "ssr"]:
		acc += float(w[key])
		if roll <= acc:
			return key
	return "ssr"


static func _pool_by_rarity() -> Dictionary:
	var pools := {"common": [], "rare": [], "epic": [], "ssr": []}
	for card in ContentLoader.load_content().get("cards", []):
		if bool(card.get("token", false)):
			continue
		var r := str(card.get("rarity", "common"))
		if pools.has(r):
			pools[r].append(str(card.id))
	return pools


static func open_pack(seed_value: int = 0) -> Dictionary:
	var data := load_collection()
	if int(data.balance) < int(RULES.packCost):
		return {"ok": false, "error": "御札不足：开包需要 %d。" % int(RULES.packCost), "cards": []}
	data["balance"] = int(data.balance) - int(RULES.packCost)
	data["packsOpened"] = int(data.get("packsOpened", 0)) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else (Time.get_ticks_msec() as int)
	var pools := _pool_by_rarity()
	var results: Array = []
	var dust_gain := 0
	for i in int(RULES.packSize):
		var rarity := _roll_rarity(data, rng)
		var pool: Array = pools.get(rarity, pools["common"])
		if pool.is_empty():
			pool = pools["common"]
		var card_id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var have := int(data.owned.get(card_id, 0))
		var gained := 0
		if have < int(RULES.maxCopies):
			data.owned[card_id] = have + 1
			gained = 1
		else:
			var dust := int(RULES.dupeValue.get(rarity, 5))
			data["balance"] = int(data.balance) + dust
			dust_gain += dust
		results.append({"id": card_id, "rarity": rarity, "gained": gained, "name": ContentLoader.card_def(card_id).get("name", card_id)})
	# Pity counts packs, with the same due counters for all five rolls as JS.
	var hit_ssr := results.any(func(item): return item.rarity == "ssr")
	var hit_epic := hit_ssr or results.any(func(item): return item.rarity == "epic")
	data["pitySinceEpic"] = 0 if hit_epic else int(data.get("pitySinceEpic", 0)) + 1
	data["pitySinceSsr"] = 0 if hit_ssr else int(data.get("pitySinceSsr", 0)) + 1
	save_collection(data)
	return {"ok": true, "error": "", "cards": results, "dust": dust_gain, "balance": int(data.balance)}


static func craft_card(card_id: String) -> Dictionary:
	var data := load_collection()
	var card := ContentLoader.card_def(card_id)
	if card.is_empty():
		return {"ok": false, "error": "未知卡牌"}
	var have := int(data.owned.get(card_id, 0))
	if have >= int(RULES.maxCopies):
		return {"ok": false, "error": "「%s」已达上限。" % str(card.get("name", card_id))}
	var cost := int(RULES.craftCost.get(str(card.get("rarity", "common")), 40))
	if int(data.balance) < cost:
		return {"ok": false, "error": "御札不足：需要 %d。" % cost}
	data["balance"] = int(data.balance) - cost
	data.owned[card_id] = have + 1
	save_collection(data)
	return {"ok": true, "error": "", "balance": int(data.balance)}


static func grant_match_reward(won: bool) -> int:
	var data := load_collection()
	var reward := int(RULES.winReward if won else RULES.lossReward)
	data["balance"] = int(data.balance) + reward
	if won:
		data["wins"] = int(data.get("wins", 0)) + 1
	else:
		data["losses"] = int(data.get("losses", 0)) + 1
	save_collection(data)
	return reward
