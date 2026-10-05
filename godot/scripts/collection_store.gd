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
		# JSON numeric values load as floats; array membership is type-sensitive.
		var pending: Dictionary = data.get("pendingReveal", {})
		if not pending.is_empty():
			pending.revealed = pending.get("revealed", []).map(func(index): return int(index))
			data.pendingReveal = pending
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


static func _pool_by_rarity(pack_id: String = "all") -> Dictionary:
	var pools := {"common": [], "rare": [], "epic": [], "ssr": []}
	for card in ContentLoader.load_content().get("cards", []):
		if bool(card.get("token", false)):
			continue
		if pack_id != "all" and str(ContentLoader.unit_def(str(card.unitId)).get("pack", "origin")) != pack_id:
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
	var result := _draw_pack(data, seed_value, "all")
	if not save_collection(data):
		return {"ok": false, "error": "收藏存档写入失败。", "cards": []}
	return result


static func _draw_pack(data: Dictionary, seed_value: int, pack_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else (Time.get_ticks_msec() as int)
	var pools := _pool_by_rarity(pack_id)
	var results: Array = []
	var dust_gain := 0
	for i in int(RULES.packSize):
		var rarity := _roll_rarity(data, rng)
		rarity = _available_rarity(rarity, pools)
		var pool: Array = pools[rarity]
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
	return {"ok": true, "error": "", "cards": results, "dust": dust_gain, "balance": int(data.balance)}


static func _available_rarity(rarity: String, pools: Dictionary) -> String:
	if not pools[rarity].is_empty(): return rarity
	# Missing epic tiers upgrade to SSR, including due pity; never silently downgrade.
	for fallback in ["ssr", "epic", "rare", "common"]:
		if not pools[fallback].is_empty(): return fallback
	return "common"


static func pack_probabilities(pack_id: String) -> Dictionary:
	var pools := _pool_by_rarity(pack_id)
	var rates := {"common": 0.0, "rare": 0.0, "epic": 0.0, "ssr": 0.0}
	for rarity in RULES.rarityWeights:
		rates[_available_rarity(rarity, pools)] += float(RULES.rarityWeights[rarity])
	return rates


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


static func purchase_packs(pack_id: String, quantity: int) -> Dictionary:
	if pack_id not in ContentLoader.pack_ids() or quantity not in [1, 5, 10]:
		return {"ok": false, "error": "请选择有效秘闻卷和数量。"}
	var data := load_collection()
	var cost := quantity * int(RULES.packCost)
	if int(data.balance) < cost:
		return {"ok": false, "error": "御札不足：需要 %d。" % cost}
	var inventory: Dictionary = data.get("packInventory", {}).duplicate()
	inventory[pack_id] = int(inventory.get(pack_id, 0)) + quantity
	data.packInventory = inventory
	data.balance = int(data.balance) - cost
	if not save_collection(data):
		return {"ok": false, "error": "购买未保存，请重试。"}
	return {"ok": true, "quantity": quantity, "cost": cost}


static func open_owned_pack(pack_id: String, seed_value: int) -> Dictionary:
	if pack_id not in ContentLoader.pack_ids():
		return {"ok": false, "error": "未知秘闻卷。"}
	var data := load_collection()
	if not data.get("pendingReveal", {}).is_empty():
		return {"ok": false, "error": "请先完成上一包的翻牌。"}
	var inventory: Dictionary = data.get("packInventory", {}).duplicate()
	if int(inventory.get(pack_id, 0)) <= 0:
		return {"ok": false, "error": "尚未持有该秘闻卷，请先购买。"}
	inventory[pack_id] = int(inventory[pack_id]) - 1
	data.packInventory = inventory
	data.packsOpened = int(data.get("packsOpened", 0)) + 1
	var result := _draw_pack(data, seed_value, pack_id)
	data.pendingReveal = {"pack": pack_id, "cards": result.cards, "revealed": [], "dust": result.dust}
	if not save_collection(data):
		return {"ok": false, "error": "开包未保存，请重试。"}
	return result


static func reveal_card(index: int) -> bool:
	var data := load_collection()
	var pending: Dictionary = data.get("pendingReveal", {})
	if pending.is_empty() or index < 0 or index >= pending.get("cards", []).size():
		return false
	var revealed: Array = pending.get("revealed", []).duplicate()
	if not revealed.has(index): revealed.append(index)
	pending.revealed = revealed
	data.pendingReveal = pending
	return save_collection(data)


static func finish_reveal() -> bool:
	var data := load_collection()
	var pending: Dictionary = data.get("pendingReveal", {})
	if pending.is_empty() or pending.get("revealed", []).size() != pending.get("cards", []).size():
		return false
	data.pendingReveal = {}
	return save_collection(data)
