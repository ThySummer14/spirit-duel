class_name ContentLoader
extends RefCounted
## Loads shared content.json and exposes playable subsets that tolerate growth.

const CONTENT_PATH := "res://content/content.json"

const RULE_DEFAULTS := {
	"lineupSize": 4,
	"cardsPerUnit": 8,
	"startingAvatarHp": 30,
	"maxEnergy": 2,
	"openingHandSize": 5,
	"maxHandSize": 12,
	"knockoutCountdown": 2,
	"maxUnitLevel": 3,
	"bonusUpgradeTurn": 7,
}

static var _cache: Dictionary = {}

static func load_content(force: bool = false) -> Dictionary:
	if not force and not _cache.is_empty():
		return _cache
	var text := FileAccess.get_file_as_string(CONTENT_PATH)
	var payload = JSON.parse_string(text)
	if not (payload is Dictionary) or int(payload.get("schema", 0)) != 1:
		push_error("Invalid content contract at %s" % CONTENT_PATH)
		_cache = {"schema": 0, "units": [], "cards": [], "rules": RULE_DEFAULTS.duplicate(), "error": "invalid"}
		return _cache
	var units: Array = payload.get("units", [])
	var cards: Array = payload.get("cards", [])
	var rules: Dictionary = RULE_DEFAULTS.duplicate()
	var raw_rules = payload.get("rules")
	if raw_rules is Dictionary:
		for key in raw_rules:
			rules[key] = raw_rules[key]
	var by_unit := {}
	var by_card := {}
	for unit in units:
		if unit is Dictionary and unit.has("id"):
			by_unit[unit.id] = unit
	var cards_by_unit := {}
	for card in cards:
		if not (card is Dictionary) or not card.has("id") or not card.has("unitId"):
			continue
		if not cards_by_unit.has(card.unitId):
			cards_by_unit[card.unitId] = []
		cards_by_unit[card.unitId].append(card)
		by_card[card.id] = card
	# Playable subset: units that own at least one card. Extra packs can grow freely.
	var playable: Array = []
	for unit in units:
		var uid: String = unit.get("id", "")
		if cards_by_unit.has(uid) and (cards_by_unit[uid] as Array).size() > 0:
			playable.append(unit)
	_cache = {
		"schema": 1,
		"units": units,
		"playable_units": playable,
		"cards": cards,
		"cards_by_unit": cards_by_unit,
		"units_by_id": by_unit,
		"cards_by_id": by_card,
		"rules": rules,
	}
	return _cache

static func rules() -> Dictionary:
	return load_content().get("rules", RULE_DEFAULTS)

static func playable_units() -> Array:
	return load_content().get("playable_units", [])

static func all_units() -> Array:
	return load_content().get("units", [])

static func cards_for_unit(unit_id: String) -> Array:
	return load_content().get("cards_by_unit", {}).get(unit_id, [])

static func card_def(card_id: String) -> Dictionary:
	return load_content().get("cards_by_id", {}).get(card_id, {})

static func unit_def(unit_id: String) -> Dictionary:
	return load_content().get("units_by_id", {}).get(unit_id, {})

static func starter_card_ids(unit_id: String) -> Array:
	var out: Array = []
	for card in cards_for_unit(unit_id):
		var n := int(card.get("starterCopies", 0))
		for _i in n:
			out.append(card.get("id"))
	return out

static func default_deck(unit_ids: Array) -> Dictionary:
	var card_ids: Array = []
	for uid in unit_ids:
		card_ids.append_array(starter_card_ids(uid))
	return {"unitIds": unit_ids.duplicate(), "cardIds": card_ids}

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color("8b93b8")
		"rare":
			return Color("5fa8d6")
		"epic":
			return Color("c98fe8")
		"ssr", "legendary":
			return Color("f0c869")
		_:
			return Color("8b93b8")

static func type_color(card_type: String) -> Color:
	match card_type:
		"combat":
			return Color("dd6a48")
		"spell":
			return Color("64aed8")
		"form":
			return Color("c9a45e")
		"realm":
			return Color("9d82d4")
		"awakening":
			return Color("e8c76a")
		_:
			return Color("8b93b8")

static func unit_color(unit: Dictionary) -> Color:
	var html: String = unit.get("color", "#8b93b8")
	return Color(html) if html.begins_with("#") else Color("8b93b8")

static func passive_text(unit: Dictionary, awakened: bool = false) -> String:
	var key := "awakenedPassive" if awakened else "passive"
	var passive = unit.get(key, {})
	if passive is Dictionary:
		return "%s｜%s" % [passive.get("name", "被动"), passive.get("text", "")]
	return ""


static func pack_label(pack_id: String) -> String:
	return str({"all": "全部秘闻", "origin": "灵枢原创", "classic": "经典基础", "wave2": "不夜之火", "wave3": "月夜沧海", "wave4": "吉运善恶", "wave5": "繁花喧哗", "wave6": "空弦鸣雷", "wave7": "燃灯桃源", "wave8": "祝星千录", "wave9": "龙渊花札", "wave10": "鬼灭联动", "wave11": "衍生式神", "wave12": "灵枢二弹", "wave13": "命运抉择"}.get(pack_id, pack_id))


static func pack_ids() -> Array:
	var ids: Array = ["all"]
	for pack in ["origin", "classic", "wave2", "wave3", "wave4", "wave5", "wave6", "wave7", "wave8", "wave9", "wave10", "wave11", "wave12", "wave13"]:
		if not units_in_pack(pack).is_empty(): ids.append(pack)
	# 新资料包随内容自动进入入口，不需要再改三个界面的筛选器。
	for unit in playable_units():
		var pack := str(unit.get("pack", "origin"))
		if not ids.has(pack): ids.append(pack)
	return ids


static func units_in_pack(pack_id: String) -> Array:
	return playable_units().filter(func(unit): return pack_id == "all" or str(unit.get("pack", "origin")) == pack_id)


static func valid_lineup(unit_ids: Array) -> bool:
	if unit_ids.size() != int(rules().get("lineupSize", 4)): return false
	var seen := {}
	for uid in unit_ids:
		if seen.has(uid) or unit_def(str(uid)).is_empty(): return false
		if starter_card_ids(str(uid)).size() != int(rules().get("cardsPerUnit", 8)): return false
		seen[uid] = true
	return true


static func recommended_lineup(pack_id: String = "classic") -> Array:
	var ids: Array = []
	var candidates := units_in_pack(pack_id)
	# 鬼灭联动只有两名角色，其余位置由经典式神补齐。
	candidates.append_array(units_in_pack("classic"))
	candidates.append_array(playable_units())
	for unit in candidates:
		var uid := str(unit.id)
		if not ids.has(uid) and starter_card_ids(uid).size() == int(rules().get("cardsPerUnit", 8)):
			ids.append(uid)
		if ids.size() == int(rules().get("lineupSize", 4)): break
	return ids


static func opponent_lineup(ally: Array, match_seed: int) -> Array:
	var pool: Array = []
	for unit in playable_units():
		if not ally.has(unit.id): pool.append(unit.id)
	if pool.size() < int(rules().get("lineupSize", 4)):
		for unit in playable_units():
			if not pool.has(unit.id): pool.append(unit.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous = pool[i]
		pool[i] = pool[j]
		pool[j] = previous
	return pool.slice(0, int(rules().get("lineupSize", 4)))
