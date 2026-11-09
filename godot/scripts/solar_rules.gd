class_name SolarRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": "tianzhao"})

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func awake(gs, owner: int) -> bool:
	var src := source(gs, owner)
	return src >= 0 and bool(gs.player(owner).units[src].awakened)

static func attach(gs, owner: int, inst: Dictionary) -> void:
	inst.sunlight = int(inst.get("sunlight", 0)) + 1
	var card: Dictionary = Content.card_def(str(inst.definitionId))
	gs.VerifiedRules.event(gs, "sunlight-attached", {"player": owner, "instanceId": inst.instanceId, "card": card, "level": inst.sunlight})
	var idx: int = gs._source_index(owner, card)
	if idx < 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	for realm in gs.player(owner).realms.duplicate():
		if realm.get("nativeRealm") != "solar-palace" or int(realm.hp) <= 0: continue
		if int(unit.hp) <= 0:
			gs.VerifiedRules.Peach.revive(gs, owner, idx, unit, false, false)
		else:
			gs.VerifiedRules.HairPower.give(gs, owner, idx, 2)
			gs._grant_unit_armor(unit, 2)

static func draw(gs, owner: int, count: int) -> void:
	gs._draw(owner, count, -1, {"intoInsight": true, "attachSunlight": true})

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit): return
	draw(gs, owner, 1)
	var marked: Array = gs.VerifiedRules.Insight.zone(gs, owner).filter(func(inst): return int(inst.get("sunlight", 0)) > 0)
	if marked.size() >= 3 and gs.winner < 0: gs.VerifiedRules.Insight.enter(gs, owner)
	if unit.get("formRules", {}).get("solarGoddess", false): draw(gs, owner, 1)

static func insight_ended(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var marked: Array = gs.VerifiedRules.Insight.zone(gs, owner).filter(func(inst): return int(inst.get("sunlight", 0)) > 0)
	if marked.is_empty(): return
	var src := source(gs, owner)
	var unit: Dictionary = p.units[src] if src >= 0 else {}
	var projectile: bool = unit.get("formRules", {}).get("solarJudgment", false) and active(unit)
	var bonus := int(p.get("solarLightBonus", 0))
	for inst in marked:
		gs.VerifiedRules.Insight.remove(gs, owner, inst)
		p.deck.append(inst)
	gs._shuffle(p.deck)
	for inst in marked:
		if gs.winner >= 0: return
		var damage := int(inst.sunlight) + bonus
		if projectile:
			var front: int = gs.front_index(1-owner)
			if front < 0: gs._damage_avatar(1-owner, damage, owner, src)
			else: gs._damage_unit(1-owner, front, damage * 2, owner, src)
		else:
			var pool: Array = gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))
			if pool.is_empty(): continue
			var target: Dictionary = pool[int(gs.next_random() % pool.size())]
			gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, target.uid), damage, owner, src)

static func used(gs, owner: int, card: Dictionary) -> void:
	if int(card.get("sunlight", 0)) <= 0: return
	for realm in gs.player(owner).realms.duplicate():
		if realm.get("nativeRealm") == "solar-judgment-site" and int(realm.hp) > 0:
			draw(gs, owner, 1)
			if gs.winner < 0: gs.VerifiedRules.Insight.enter(gs, owner)

static func _choice(gs, owner: int, src: int, card: Dictionary) -> void:
	var ids: Array = []
	if int(gs.player(owner).get("solarLightBonus", 0)) == 0: ids.append("solar-damage")
	if not awake(gs, owner): ids.append("solar-awaken")
	if ids.is_empty(): return
	gs.pending_choice = {"type": "solar-awaken", "playerIndex": owner, "sourceIndex": src, "instanceIds": ids, "card": card, "heading": "觉醒·天照", "title": "选择天晖强化或觉醒", "hint": "天晖强化与觉醒分别生效。"}
	gs.phase = "choice"

static func choice_card(gs, owner: int, id: String):
	if gs.pending_choice.get("type") != "solar-awaken" or int(gs.pending_choice.playerIndex) != owner or id not in gs.pending_choice.instanceIds: return null
	var damage := id == "solar-damage"
	return {"id": id, "unitId": "tianzhao", "name": "强化天晖" if damage else "觉醒", "type": "spell", "typeLabel": "觉醒选项", "text": "本局天晖伤害+1，不能叠加。" if damage else "+1力量/+1生命，结附天晖的牌获得瞬发。"}

static func resolve_choice(gs, owner: int, id: String) -> bool:
	var c: Dictionary = gs.pending_choice
	if c.get("type") != "solar-awaken" or int(c.playerIndex) != owner or id not in c.instanceIds: return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId": id, "choice": "solar-awaken", "card": c.card.id}, owner)
	if id == "solar-damage": gs.player(owner).solarLightBonus = 1
	else: gs._awaken(owner, int(c.sourceIndex), c.card, {"attack": 1, "hp": 1})
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") != "solar-strike": return null
	return (Choice.targetable_shikigami(gs, owner, owner) + Choice.targetable_shikigami(gs, owner, 1-owner)).map(func(u): return u.uid)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not card.get("solarRules", false): return false
	match str(effect.get("action", "")):
		"solar-light":
			gs.VerifiedRules.Insight.enter(gs, owner)
			draw(gs, owner, int(effect.value))
		"solar-form":
			gs._apply_form(owner, src, card)
			if card.id == "c62306": gs.VerifiedRules.Insight.enter(gs, owner)
			draw(gs, owner, 2 if card.id == "c62306" else 1)
		"solar-realm":
			gs._deploy_realm(owner, card)
			if card.id == "c62303": gs.VerifiedRules.Insight.enter(gs, owner)
			else: draw(gs, owner, 1)
		"solar-strike":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx >= 0:
					gs._damage_unit(side, idx, 5, owner, src)
					break
			draw(gs, owner, 1)
		"solar-awaken": _choice(gs, owner, src, card)
		_: return false
	return true
