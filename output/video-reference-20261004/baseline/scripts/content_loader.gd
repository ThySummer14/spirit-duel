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
	var by_id := {}
	for unit in units:
		if unit is Dictionary and unit.has("id"):
			by_unit[unit.id] = unit
			by_id[unit.id] = unit
	var cards_by_unit := {}
	for card in cards:
		if not (card is Dictionary) or not card.has("id") or not card.has("unitId"):
			continue
		if not cards_by_unit.has(card.unitId):
			cards_by_unit[card.unitId] = []
		cards_by_unit[card.unitId].append(card)
		by_id[card.id] = card
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
		"by_id": by_id,
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
	return load_content().get("by_id", {}).get(card_id, {})

static func unit_def(unit_id: String) -> Dictionary:
	return load_content().get("by_id", {}).get(unit_id, {})

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
