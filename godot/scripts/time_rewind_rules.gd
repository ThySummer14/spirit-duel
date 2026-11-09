extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const ROLE := "shiyao-longyechaji"
const INSCRIBE := "shiyao-inscribe"
const REWIND := "shiyao-rewind"
const REALM := "w13-shiyao-longyechaji-93108"
const ORIGINAL_DECK := ["w13-shiyao-longyechaji-93101", "w13-shiyao-longyechaji-93102", "w13-shiyao-longyechaji-93103", "w13-shiyao-longyechaji-93104", "w13-shiyao-longyechaji-93105", "w13-shiyao-longyechaji-93106", "w13-shiyao-longyechaji-93107"]
const RECORDED_STATS := [
	"baseAttack", "baseMaxHp", "attackBonus", "maxHpBonus", "hp", "shield", "shieldExpires",
	"armorBreak", "brittle", "frozen", "charge", "unyielding", "barrier", "swift", "inspired",
	"battlePower", "battlePowerTurn", "untilAttack", "poisoned", "toxicPoisoned", "poisonStacks",
	"hpBonusTurn", "attackPenalty", "attackPenaltyTurn", "permanentAttack",
	"gluttonPermanentAttack", "gluttonPermanentHp", "oniPermanentHp", "sparrowPermanentHp",
	"windPermanentHp", "blessingPermanentAttack", "blessingPermanentHp",
]
const RECORDED_FORM := ["form", "formAbility", "formRules", "formHooks", "formInstalledOrder", "formCountdown"]

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ROLE})

static func owned_card(card: Dictionary) -> bool:
	return card.get("unitId") == ROLE

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and not unit.get("baseRulesSuppressed", false) and unit.id == ROLE

static func opening(gs) -> void:
	for owner in 2:
		if source(gs, owner) >= 0: Choice.give(gs, owner, INSCRIBE)

static func capture(gs, owner: int, unit: Dictionary) -> void:
	var recorded := {"unit": unit.duplicate(true), "played": []}
	var p: Dictionary = gs.player(owner)
	p.timeRecord = recorded
	var instance: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, REWIND)
	instance.timeRecord = recorded
	p.deck.push_front(instance)

static func record_play(gs, owner: int, card: Dictionary, automatic: bool) -> void:
	if automatic or not owned_card(card) or card.id in [INSCRIBE, REWIND]: return
	var played: Dictionary = card.get("playedInstance", {})
	if played.is_empty(): return
	var p: Dictionary = gs.player(owner)
	for instance in p.hand + p.deck + gs.VerifiedRules.Insight.zone(gs, owner):
		if instance.definitionId != REWIND or not instance.has("timeRecord"): continue
		var entries: Array = instance.timeRecord.played
		if not entries.any(func(entry): return entry.definitionId == played.definitionId):
			entries.append(played.duplicate(true))

static func restore_body(gs, owner: int, src: int, recorded: Dictionary, with_form: bool) -> void:
	if recorded.is_empty(): return
	var unit: Dictionary = gs.player(owner).units[src]
	var old: Dictionary = recorded.unit
	var fields := RECORDED_STATS + RECORDED_FORM if with_form else RECORDED_STATS
	for field in fields:
		if not old.has(field):
			unit.erase(field)
			continue
		var value = old[field]
		unit[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	gs._recalc(unit)
	unit.hp = clampi(int(old.hp), 1, int(unit.maxHp))
	gs.VerifiedRules.event(gs, "time-rewound", {"player": owner, "uid": unit.uid, "form": with_form})

static func already_present(gs, owner: int, id: String) -> bool:
	var p: Dictionary = gs.player(owner)
	for instance in p.hand + p.deck + gs.VerifiedRules.Insight.zone(gs, owner):
		if instance.instanceId == id: return true
	return p.realms.any(func(realm): return realm.get("cardInstance", {}).get("instanceId") == id)

static func restore_hand(gs, owner: int, recorded: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	for instance in recorded.get("played", []):
		if p.hand.any(func(held): return held.instanceId == instance.instanceId): continue
		var recovered: Dictionary = instance.duplicate(true)
		if already_present(gs, owner, str(instance.instanceId)):
			recovered.instanceId = gs.VerifiedRules.Insight.instance(gs, owner, instance.definitionId).instanceId
		gs.VerifiedRules.Baize.put_hand(gs, owner, recovered)

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if not owned_card(card): return card
	var out := card
	if gs.player(owner).realms.any(func(realm): return realm.cardId == REALM and int(realm.hp) > 0):
		if "instant" not in card.get("keywords", []):
			out = card.duplicate(true)
			out.keywords.append("instant")
	return out

static func can_use(gs, owner: int, src: int, card: Dictionary) -> bool:
	if card.get("id") != "w13-shiyao-longyechaji-93105": return true
	if src < 0: return false
	var unit: Dictionary = gs.player(owner).units[src]
	return gs.player(owner).has("timeRecord") if int(unit.hp) > 0 else gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, unit)

static func score_card(gs, owner: int, card: Dictionary):
	if card.get("id") == "w13-shiyao-longyechaji-93102" and gs.player(owner).deck.is_empty(): return -50
	return null

static func permanent(gs, unit: Dictionary, power: int, health: int) -> void:
	gs.VerifiedRules.Glutton.record_permanent(unit, power, health)
	gs._grow_unit(unit, power, health)

static func before_attack(gs, attacker: Dictionary) -> bool:
	if not active(attacker) or not attacker.get("formRules", {}).get("timeMoonrise", false): return false
	permanent(gs, attacker, 1, 1)
	return true

static func avatar_hit(gs, victim: int, owner: int, src: int, amount: int) -> void:
	if owner < 0 or victim == owner or src < 0 or amount <= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit) or not unit.get("formRules", {}).get("timeBottomDraw", false): return
	if int(unit.get("timeBottomTurn", -1)) == gs.turn_counter: return
	unit.timeBottomTurn = gs.turn_counter
	queue(gs, owner, "shiyao-bottom-draw")

static func turn_start(gs, owner: int) -> void:
	var idx := source(gs, owner)
	if idx < 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	if active(unit) and unit.awakened:
		permanent(gs, unit, 1, 1)
		gs._draw(owner, 2, -1, {"waveDrawUnit": ROLE})

static func queue(gs, owner: int, kind: String, data: Dictionary = {}) -> void:
	gs.resolution_stack.append({"kind": kind, "playerIndex": owner}.merged(data))

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("shiyao-"): return false
	var owner := int(frame.playerIndex)
	match kind:
		"shiyao-travel-draw": gs._draw(owner, 1)
		"shiyao-bottom-draw": gs._draw(owner, 1, -1, {"bottomDraw": true})
		"shiyao-slash-revealed":
			var src := int(frame.sourceIndex)
			for unit in Choice.live_units(gs, 1 - owner):
				gs._damage_unit(1 - owner, gs._unit_index_by_uid(1 - owner, unit.uid), 1, owner, src)
			gs._draw(owner, 1, -1, {"drawInstanceId": frame.cardInstanceId})
		_: return false
	return true

static func combat(gs, owner: int, src: int, card: Dictionary, target, power: int, armor: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if armor > 0: gs._grant_unit_armor(unit, armor)
	gs._resolve_combat(owner, src, power, false, false, false, false, target, false, {"combatCard": card})

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("shiyao-") or src < 0: return false
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[src]
	match action:
		"shiyao-inscribe": capture(gs, owner, unit)
		"shiyao-rewind":
			var recorded: Dictionary = card.get("playedInstance", {}).get("timeRecord", {})
			restore_body(gs, owner, src, recorded, true)
			restore_hand(gs, owner, recorded)
			Choice.give(gs, owner, INSCRIBE)
		"shiyao-trace":
			permanent(gs, unit, 1, 0)
			combat(gs, owner, src, card, target_id, 0, 2)
		"shiyao-guard":
			permanent(gs, unit, 0, 1)
			combat(gs, owner, src, card, target_id, 2, 0)
		"shiyao-form":
			gs._apply_form(owner, src, card, effect.value)
			unit.swift = true
			if unit.get("formRules", {}).get("timeMoonrise", false):
				gs.VerifiedRules.Combat.grant_inspired(gs, owner, src)
		"shiyao-travel":
			gs.VerifiedRules.HairPower.give(gs, owner, src, 2)
			gs._grant_unit_armor(unit, 2)
			gs._heal_unit(unit, int(unit.maxHp))
			Fate.offer(gs, owner, owner, {"kind": "shiyao-travel-draw", "playerIndex": owner})
		"shiyao-slash":
			combat(gs, owner, src, card, target_id, 1, 1)
			var bottom := Fate.reveal_bottom(gs, owner, owner)
			if not bottom.is_empty() and owned_card(Content.card_def(str(bottom.definitionId))):
				queue(gs, owner, "shiyao-slash-revealed", {"sourceIndex": src, "cardInstanceId": bottom.instanceId})
		"shiyao-revive":
			if int(unit.hp) > 0 or gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false):
				restore_body(gs, owner, src, p.get("timeRecord", {}), false)
		"shiyao-eternal":
			gs._deploy_realm(owner, card)
			p.deck.clear()
			for id in ORIGINAL_DECK:
				for i in 6: p.deck.append(gs.VerifiedRules.Insight.instance(gs, owner, id))
			gs._shuffle(p.deck)
			gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			gs.VerifiedRules.event(gs, "time-deck-replaced", {"player": owner, "count": p.deck.size()})
		_: return false
	return true
