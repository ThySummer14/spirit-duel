extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Aki := preload("res://scripts/akiba_rules.gd")
const Travel := preload("res://scripts/travel_book_rules.gd")
const Curse := preload("res://scripts/curse_gauze_rules.gd")
const Serving := preload("res://scripts/serving_tray_rules.gd")
const Jade := preload("res://scripts/abyss_jade_rules.gd")
const Discard := preload("res://scripts/dragon_discard_rules.gd")

static func source(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})

static func living(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return gs.VerifiedRules.PaperDance.shikigami(gs, u))

static func units(gs, owner: int, sides: Array, include_knocked: bool = false) -> Array:
	var result: Array = []
	for side in sides:
		for u in gs.player(side).units:
			if u.get("removed", false) or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
			if int(u.hp) <= 0 and not include_knocked: continue
			if side != owner and (gs.VerifiedRules.Combat.has(u, "veil") or gs.VerifiedRules.Movement.has_veil(u)): continue
			result.append(str(u.uid))
	return result

static func put(gs, owner: int, id: String) -> void:
	gs.VerifiedRules.Baize.put_hand(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, id))

static func exclusive(unit: Dictionary) -> Array:
	return Content.cards_for_unit(str(unit.id)).filter(func(c): return not c.get("token", false) and int(c.get("deckLimit", 0)) > 0)

static func attack(gs, owner: int, src: int, target_id = null, options: Dictionary = {}, bonus: int = 0) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0 or u.get("removed", false): return
	gs._resolve_combat(owner, src, bonus, bool(options.get("pierce", false)), false, bool(options.get("combo", false)), bool(options.get("firstStrike", false)), target_id, false, options)

static func combat(gs, owner: int, src: int, card: Dictionary, target_id, extra: Dictionary = {}) -> void:
	var options: Dictionary = card.get("combatOption", {}).duplicate(true)
	options.merge(extra, true)
	options.combatCard = card
	gs._grant_unit_armor(gs.player(owner).units[src], int(options.get("shield", 0)))
	attack(gs, owner, src, target_id, options, int(card.get("value", 0)))

static func choose(gs, owner: int, kind: String, ids: Array, source_idx: int, heading: String, context: Dictionary = {}) -> void:
	if ids.is_empty(): return
	gs.pending_choice = {"type": "abyss-" + kind, "playerIndex": owner, "sourceIndex": source_idx, "heading": heading,
		"hint": "选择一个可用选项继续结算。", "instanceIds": ids}.merged(context)
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("abyss-") or int(c.playerIndex) != owner or iid not in c.instanceIds: return null
	if iid in c.get("labels", {}): return {"id": iid, "name": c.labels[iid], "type": "spell", "text": str(c.get("details", {}).get(iid, ""))}
	if c.get("useCardIds", false): return Content.card_def(iid)
	return null

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("abyss-") or int(c.playerIndex) != owner or iid not in c.instanceIds: return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId": iid, "choice": c.type}, owner)
	if not Aki.choice(gs, owner, iid, c) and not Travel.choice(gs, owner, iid, c): Discard.choice(gs, owner, iid, c)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("abyss-"): return null
	if int(c.playerIndex) != owner: return false
	if c.type == "abyss-chili-discard":
		var p: Dictionary = gs.player(owner)
		var want_jump: bool = not p.deck.is_empty()
		for inst in p.hand:
			if (inst.definitionId == "c64703") == want_jump and inst.instanceId in c.instanceIds:
				return resolve_choice(gs, owner, str(inst.instanceId))
	return resolve_choice(gs, owner, str(c.instanceIds[0]))

static func reflect_card(gs, owner: int, card: Dictionary) -> void:
	var inst: Dictionary = card.get("playedInstance", {})
	if inst.is_empty() or inst.get("abyssReflectionUsed", false): return
	inst.abyssReflectionUsed = true
	gs.VerifiedRules.Baize.put_hand(gs, owner, inst)

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var view := Aki.describe(gs, owner, card)
	view = Travel.described(gs, owner, inst, view)
	view = Curse.described(gs, owner, view)
	view = Serving.described(gs, owner, inst, view)
	view = Jade.describe(gs, owner, view)
	view = Discard.describe(gs, owner, view)
	if inst.get("travelInstant", false):
		view = view.duplicate(true)
		if not "instant" in view.get("keywords", []): view.keywords.append("instant")
	if view.get("id") not in ["c64307", "c64407"]: return view
	var src := source(gs, owner, str(view.unitId))
	if src < 0 or int(gs.player(owner).units[src].level) >= int(view.level): return view
	view.level = 1
	view.target = "ally-unit"
	view.trickMode = true
	view.currentCardStats = "戏法"
	return view

static func targets(gs, owner: int, card: Dictionary):
	var target = Aki.targets(gs, owner, card)
	if target != null: return target
	match str(card.get("effect", "")):
		"abyss-travel-read":
			if card.get("trickMode", false): return units(gs, owner, [owner])
		"abyss-jade-combat":
			if card.get("id") == "c64603": return units(gs, owner, [1-owner]).filter(func(uid): return Jade.has(gs._unit_by_uid(gs.player(1-owner).units, uid), owner))
		"abyss-curse-prayer":
			if card.get("trickMode", false):
				var src: int = gs._source_index(owner, card)
				return units(gs, owner, [owner]).filter(func(uid): return uid != gs.player(owner).units[src].uid)
		"abyss-curse-flowers":
			return units(gs, owner, [owner], true).filter(func(uid): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, gs._unit_by_uid(gs.player(owner).units, uid)))
	return null

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("dragonAbyss", false): return true
	if card.id == "c64305" and not Travel.realm(gs, owner, "travel-mist").is_empty(): return false
	return Aki.can_use(gs, owner, card) and Curse.can_use(gs, owner, card)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, e: Dictionary, target: Dictionary, target_id) -> bool:
	if not card.get("dragonAbyss", false): return false
	var action := str(e.action)
	if action.begins_with("abyss-akiba-"): return Aki.resolve_action(gs, owner, src, card, e, target)
	if action.begins_with("abyss-travel-"): return Travel.resolve_action(gs, owner, src, card, e, target)
	if action.begins_with("abyss-curse-"): return Curse.resolve_action(gs, owner, src, card, e, target, target_id)
	if action.begins_with("abyss-serving-"): return Serving.resolve_action(gs, owner, src, card, e, target, target_id)
	if action.begins_with("abyss-jade-"): return Jade.resolve_action(gs, owner, src, card, e, target, target_id)
	if action.begins_with("abyss-chili-"): return Discard.resolve_action(gs, owner, src, card, e, target, target_id)
	return false

static func resolve_frame(gs, f: Dictionary) -> bool:
	return Aki.resolve_frame(gs, f) or Travel.resolve_frame(gs, f) or Curse.resolve_frame(gs, f) or Serving.resolve_frame(gs, f) or Jade.resolve_frame(gs, f) or Discard.resolve_frame(gs, f)

static func event(gs, kind: String, details: Dictionary) -> void:
	if kind == "summon-removed" and details.get("summonKind") == "travel-ink":
		gs.resolution_stack.append({"kind": "travel-ink-left", "playerIndex": 1-int(details.player)})

static func power(gs, u: Dictionary) -> int:
	return Travel.units_aura(gs, u) + Curse.power(u) + Jade.power(gs, u) + int(Serving.has(u)) + int(u.get("akibaMoveBonus", 0)) + int(u.get("akibaFireBonus", 0)) - int(u.get("abyssJadeDebuff", 0))

static func marks(gs, owner: int, unit: Dictionary) -> Array:
	var result: Array = []
	for key in Aki.charms(unit):
		if key in Aki.NAMES: result.append(Aki.NAMES[key])
	var weakness := str(unit.get("akibaWeakness", ""))
	if weakness in Aki.NAMES: result.append("%s弱点" % str(Aki.NAMES[weakness]).trim_suffix("神通"))
	var notes := int(unit.get("travelNotes", 0))
	if notes > 0: result.append("游记 ×%d" % notes)
	var gauze := Curse.count(unit)
	if gauze > 0: result.append("%s ×%d" % ["缠心咒纱" if unit.get("curseGauzeAwake", false) else "咒纱", gauze])
	if Serving.has(unit): result.append("折敷 · +1力量")
	if unit.get("servingMarked", false): result.append("本膳料理 · 下个己方回合开始结附折敷")
	for source_owner in unit.get("abyssJades", []):
		result.append("八尺琼勾玉 · %s结附" % ("己方" if int(source_owner) == owner else "敌方"))
	if unit.get("id") == Discard.ID: result.append("本局弃牌 %d 次" % Discard.count(gs, owner))
	return result
