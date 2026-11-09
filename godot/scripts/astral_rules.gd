class_name AstralRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const BURST := "insight-starburst"
const ID := "huang-qiming"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func realms(gs, owner: int, kind: String) -> int:
	return gs.player(owner).realms.filter(func(r): return r.get("nativeRealm") == kind and int(r.hp) > 0).size()

static func bonus(gs, owner: int, id: String) -> int:
	if id == BURST: return realms(gs, owner, "astral-gift")
	if id == gs.VerifiedRules.Insight.STAR: return realms(gs, owner, "astral-river")
	return 0

static func neutral_free(gs, owner: int, card: Dictionary) -> bool:
	return gs.VerifiedRules.Insight.is_neutral(card) and card.get("insightFromZone", false) and realms(gs, owner, "astral-hole") > 0

static func enter_extra(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.awakened and active(unit): add_burst(gs, owner, 1)

static func add_burst(gs, owner: int, count: int) -> void:
	for i in count: gs.VerifiedRules.Insight.place(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, BURST))

static func combat_damage(gs, owner: int, src: int, victim: int, amount: int) -> void:
	if amount <= 0 or gs.current_player != owner or owner == victim or gs.winner >= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not Content.runtime_unit_def(unit).get("astralRules", false) or int(unit.level) < 1: return
	if not unit.awakened:
		if int(unit.get("astralDamageTurn", -1)) == gs.turn_counter: return
		unit.astralDamageTurn = gs.turn_counter
	gs.VerifiedRules.Insight.enter(gs, owner, "" if unit.awakened else ID)

static func announced(gs, owner: int, card: Dictionary) -> void:
	if not card.get("insightFromZone", false): return
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if active(unit) and unit.get("formRules", {}).get("astralTraveler", false):
		gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
		gs._grant_unit_armor(unit, 1)

static func completed(gs, owner: int, card: Dictionary, inst: Dictionary, target_id) -> void:
	if card.get("astralReturn", false) and not card.get("insightFromZone", false):
		gs.VerifiedRules.Insight.place(gs, owner, inst)
	if not Content.is_spell(card) or target_id == null: return
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit) or not unit.get("formRules", {}).get("astralGuardian", false) or int(unit.get("astralGuardianTurn", -1)) == gs.turn_counter: return
	var idx: int = gs._unit_index_by_uid(1-owner, target_id)
	if idx < 0: return
	var target: Dictionary = gs.player(1-owner).units[idx]
	if int(target.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(target): return
	unit.astralGuardianTurn = gs.turn_counter
	gs.resolution_stack.append({"kind": "astral-attack", "playerIndex": owner, "sourceIndex": src, "targetId": target_id})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "astral-attack": return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var idx: int = gs._unit_index_by_uid(1-owner, frame.targetId)
	if idx < 0: return true
	var target: Dictionary = gs.player(1-owner).units[idx]
	if int(target.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(target): return true
	if active(gs.player(owner).units[src]):
		gs._resolve_combat(owner, src, 0, false, false, false, false, frame.targetId, false, {"pursuit": true, "immuneCombat": true})
	return true

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("astralRules", false): return card
	var id := str(card.id)
	if id not in ["c61706", "c61707"]: return card
	var out := card.duplicate(true)
	var origin: Dictionary = Content.card_def("c17805" if id == "c61706" else "c17807").duplicate(true)
	origin.unitId = ID
	out.originCard = gs.VerifiedRules.Huang.describe_card(gs, owner, {}, origin)
	return out

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	if not card.get("astralRules", false): return false
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"astral-river":
			gs._deploy_realm(owner, card)
			unit.swift = true
		"astral-gift":
			gs._deploy_realm(owner, card)
			gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
		"astral-call":
			gs.VerifiedRules.Insight.enter(gs, owner)
			add_burst(gs, owner, 2)
		"astral-guard":
			gs._apply_form(owner, src, card)
			gs.VerifiedRules.Insight.enter(gs, owner)
		"astral-hole":
			gs._deploy_realm(owner, card)
			gs.VerifiedRules.Insight.enter(gs, owner)
			var pool: Array = gs.VerifiedRules.Insight.zone(gs, owner).filter(func(i): return not gs.VerifiedRules.Insight.is_neutral(gs.describe_card_instance(owner, i, false)))
			for i in mini(4, pool.size()):
				var inst: Dictionary = pool.pop_at(int(gs.next_random() % pool.size()))
				var was_blessing: bool = inst.definitionId in gs.VerifiedRules.Chen.BLESSINGS
				inst.definitionId = BURST
				if was_blessing: gs.VerifiedRules.Chen.refresh(gs, owner)
				gs.VerifiedRules.event(gs, "insight-card-transformed", {"player": owner, "instanceId": inst.instanceId, "card": Content.card_def(BURST)})
		_: return false
	return true
