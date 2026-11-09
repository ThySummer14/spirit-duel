extends RefCounted

const Content := preload("res://scripts/content_loader.gd")


static func modes(card: Dictionary) -> Array:
	return card.get("coopFaces", []).map(func(face): return str(face.coopFaceId))


static func printed_face(card: Dictionary, mode: String) -> Dictionary:
	for variant in card.get("coopFaces", []):
		if str(variant.coopFaceId) == mode: return variant
	return {}


static func partner(gs, owner: int, card: Dictionary) -> Dictionary:
	for id in card.get("coopPartners", []):
		if id == card.get("unitId"): continue
		var index: int = gs._source_index(owner, {"unitId": id})
		if index >= 0:
			var unit: Dictionary = gs.player(owner).units[index]
			if not unit.get("removed", false): return unit
	return {}


static func face(gs, owner: int, card: Dictionary, mode: String) -> Dictionary:
	var selected := printed_face(card, mode).duplicate(true)
	if selected.is_empty(): return selected
	selected.coopPartners = card.coopPartners
	selected.verifiedRules = true
	if card.has("playedInstance"): selected.playedInstance = card.playedInstance
	selected.nativePlayModeLabel = Content.unit_def(str(selected.unitId)).get("name", "") + " · " + str(selected.get("typeLabel", "牌"))
	var other := partner(gs, owner, selected)
	selected.coopBond = int(other.get("hp", 0)) > 0 and int(other.get("level", 0)) > 0
	selected.w7PayFromHand = card.get("w7PayFromHand", false)
	if selected.coopBond and selected.get("coopBondEffects") is Array:
		selected.effects.append_array(selected.coopBondEffects)
	gs.VerifiedRules.CoopLate.describe_face(gs, owner, selected)
	return gs.VerifiedRules.CoopFirst.prepare_face(gs, owner, selected)
