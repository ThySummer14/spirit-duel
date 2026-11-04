class_name FactionRules
extends RefCounted
## Printed faction identities are independent of passive abilities and forms.
const DATA_PATH := "res://content/factions.json"
const VALUES := ["红莲", "紫岩", "苍叶", "青岚"]
const COLORS := {"红莲":"dc6a66", "紫岩":"ad91d3", "苍叶":"91bd88", "青岚":"81b8de"}
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary and int(parsed.get("schema",0)) == 1: _data = parsed
	return _data

static func printed(unit: Dictionary) -> String:
	# The replacement body has no independently verified faction icon yet.
	if unit.has("susanooOriginal"): return ""
	return str(data().get("units",{}).get(str(unit.get("id","")),{}).get("faction",""))

static func get_faction(unit: Dictionary) -> String:
	return str(unit.get("factionOverride",unit.get("factionPermanent",printed(unit))))

static func known(unit: Dictionary) -> bool:
	return get_faction(unit) in VALUES

static func same(a: Dictionary, b: Dictionary) -> bool:
	return known(a) and known(b) and get_faction(a) == get_faction(b)

static func different(a: Dictionary, b: Dictionary) -> bool:
	return known(a) and known(b) and get_faction(a) != get_faction(b)

static func distinct(units: Array) -> Array:
	var result: Array = []
	for unit in units:
		if int(unit.get("hp",0)) <= 0 or unit.get("removed",false) or not unit.get("countsAsShikigami",not unit.get("summoned",false)): continue
		var faction := get_faction(unit)
		if faction in VALUES and faction not in result: result.append(faction)
	return result

static func knocked_out(unit: Dictionary) -> void:
	unit.erase("factionOverride")
