extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const URGENT := ["sanmu-urgent-1", "sanmu-urgent-2", "sanmu-urgent-3", "sanmu-urgent-4"]
const CLUES := ["sanmu-clue-talk", "sanmu-clue-ask", "sanmu-clue-rest", "sanmu-clue-study", "sanmu-clue-solve"]
const DAILY := [7, 1, 2, 3, 4, 5, 6]

static func urgent(id: String) -> bool:
	return id in URGENT or id == "jinji-weituo"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": "sanmu"})

static func body(gs, owner: int) -> Dictionary:
	var idx := source(gs, owner)
	return gs.player(owner).units[idx] if idx >= 0 else {}

static func dealt_card(gs, id: String) -> Dictionary:
	if id == "c18502": id = "sanmu-daily-%d" % DAILY[int(gs.commission_day)]
	return Content.card_def(id)

static func give_urgent(gs, owner: int) -> void:
	Choice.give(gs, owner, URGENT[int(gs.next_random() % URGENT.size())])

static func opening(gs) -> void:
	if source(gs, 0) < 0 and source(gs, 1) < 0: return
	gs._record("commission-calendar", {"weekday": gs.commission_day}, -1)
	for owner in 2:
		if source(gs, owner) >= 0: give_urgent(gs, owner)

static func progress(gs, actor: int, kind: String, amount: int = 1) -> void:
	if actor < 0 or amount <= 0: return
	for owner in 2:
		var u := body(gs, owner)
		if u.is_empty(): continue
		if actor != owner and not (int(u.hp) > 0 and u.get("formRules", {}).get("commissionShared", false)): continue
		var p: Dictionary = gs.player(owner)
		for inst in p.hand + gs.VerifiedRules.Insight.zone(gs, owner) + p.deck:
			var id := str(inst.definitionId)
			if id != "c18502" and not urgent(id) and not id.begins_with("sanmu-daily-"): continue
			var card := dealt_card(gs, id)
			if card.get("commissionEvent", "") != kind: continue
			if urgent(id) and p.deck.has(inst): continue
			inst.commissionProgress = mini(int(card.commissionCount), int(inst.get("commissionProgress", 0))+amount)

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("commissionRules", false): return card
	var out := dealt_card(gs, "c18502").duplicate(true) if card.id == "c18502" else card.duplicate(true)
	if not out.get("commissionEvent", "").is_empty():
		var remaining := maxi(0, int(out.commissionCount)-int(inst.get("commissionProgress", 0)))
		out.commissionRemaining = remaining
		out.currentCardStats = "条件已达成" if remaining == 0 else "尚需 %d · %s" % [remaining, out.commissionLabel]
	if out.get("commissionOrder", false):
		var u := body(gs, owner)
		if u.get("awakened", false) and not u.get("baseRulesSuppressed", false): out.cost = 0
	return out

static func urgent_candidates(gs, owner: int) -> Array:
	return gs.player(owner).hand.filter(func(inst): return urgent(str(inst.definitionId)))

static func targets(gs, owner: int, card: Dictionary):
	match str(card.get("id", "")):
		"sanmu-daily-3": return Choice.live_units(gs, owner).map(func(u): return u.uid)
		"sanmu-daily-5":
			return (Choice.targetable_shikigami(gs, owner, owner) + Choice.targetable_shikigami(gs, owner, 1-owner)).map(func(u): return u.uid)
		"sanmu-daily-6": return gs.player(owner).units.filter(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)).map(func(u): return u.uid)
	return null

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("commissionRules", false): return true
	if int(card.get("commissionRemaining", 0)) > 0: return false
	if card.id == "c18508" and body(gs, owner).get("awakened", false): return not clue_choices(gs, owner).is_empty()
	return card.id != "c18501" or not urgent_candidates(gs, owner).is_empty()

static func force_ready(gs, inst: Dictionary) -> void:
	inst.commissionProgress = int(dealt_card(gs, str(inst.definitionId)).get("commissionCount", 0))

static func queue(gs, owner: int, src: int, kind: String, amount: int = 0) -> void:
	gs.resolution_stack.append({"kind": kind, "playerIndex": owner, "sourceIndex": src, "amount": amount})

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if frame.get("automatic", false) and not (card.get("xuanAutomatic", false) and frame.get("usedFromHand", false)): return
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	progress(gs, owner, "play")
	if card.get("type") == "form": progress(gs, owner, "form")
	var original := Content.card_def(str(card.get("playedInstance", {}).get("definitionId", card.id)))
	if str(original.get("name", card.name)) not in gs.player(owner).initialDeckNames: progress(gs, owner, "outside")
	if src < 0 or gs.player(owner).units[src].get("summoned", false): return
	var p: Dictionary = gs.player(owner)
	var clues: Array = p.get("commissionClues", [])
	if "sanmu-clue-study" in clues: queue(gs, owner, src, "commission-study")
	if not card.get("commissionOrder", false) or src != source(gs, owner): return
	p.commissionsUsed = int(p.get("commissionsUsed", 0))+1
	if "sanmu-clue-talk" in clues: queue(gs, owner, src, "commission-heal")
	if "sanmu-clue-ask" in clues: queue(gs, owner, src, "commission-draw")
	if urgent(str(card.id)) and not gs.player(owner).units[src].get("baseRulesSuppressed", false): give_urgent(gs, owner)

static func end_turn(gs, owner: int) -> void:
	if "sanmu-clue-rest" not in gs.player(owner).get("commissionClues", []): return
	var idx := source(gs, owner)
	if idx >= 0: gs.VerifiedRules.Peach.revive(gs, owner, idx, gs.player(owner).units[idx], false, false)
	var available := urgent_candidates(gs, owner).filter(func(inst): return int(inst.get("commissionProgress", 0)) < int(dealt_card(gs, str(inst.definitionId)).get("commissionCount", 0)))
	if not available.is_empty(): force_ready(gs, available[int(gs.next_random() % available.size())])

static func knockouts(gs, source_owner: int, victim: int, u: Dictionary) -> void:
	if source_owner >= 0 and victim >= 0 and source_owner != victim and gs.VerifiedRules.OwlInsect.shikigami(u):
		progress(gs, source_owner, "knockout")

static func damage(gs, owner: int, victim: int, amount: int, combat: bool) -> void:
	if owner < 0 or owner == victim: return
	progress(gs, owner, "damage", amount)
	if not combat: progress(gs, owner, "spell-damage", amount)

static func clue_choices(gs, owner: int) -> Array:
	var p: Dictionary = gs.player(owner)
	return CLUES.filter(func(id): return id not in p.get("commissionCluesSeen", []) and int(p.get("commissionsUsed", 0)) >= int(Content.card_def(id).clueMinimum))

static func choice_card(gs, owner: int, iid: String):
	if not Choice.matches(gs, owner, iid, "commission-"): return null
	if gs.pending_choice.type == "commission-clue": return Content.card_def(iid)
	for inst in urgent_candidates(gs, owner):
		if inst.instanceId == iid: return describe(gs, owner, inst, dealt_card(gs, str(inst.definitionId)))
	return null

static func choose(gs, owner: int, iid: String) -> bool:
	if choice_card(gs, owner, iid) == null: return false
	var c := Choice.accept(gs, owner, iid)
	var p: Dictionary = gs.player(owner)
	if c.type == "commission-clue":
		if not p.has("commissionCluesSeen"): p.commissionCluesSeen = []
		p.commissionCluesSeen.append(iid)
		Choice.give(gs, owner, iid)
	else:
		for inst in urgent_candidates(gs, owner):
			if inst.instanceId == iid: force_ready(gs, inst); break
	Choice.finish(gs)
	return true

static func ai_choice(gs, owner: int):
	if not str(gs.pending_choice.get("type", "")).begins_with("commission-"): return null
	if int(gs.pending_choice.playerIndex) != owner: return false
	var ids: Array = gs.pending_choice.instanceIds
	if gs.pending_choice.type == "commission-clue": return choose(gs, owner, str(ids.back()))
	var hardest: String = str(ids[0])
	for id in ids:
		if int(choice_card(gs, owner, id).commissionRemaining) > int(choice_card(gs, owner, hardest).commissionRemaining): hardest = id
	return choose(gs, owner, hardest)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.action)
	if src < 0 or not action.begins_with("commission-"): return false
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	match action:
		"commission-complete":
			var pool := urgent_candidates(gs, owner)
			if pool.size() == 1: force_ready(gs, pool[0])
			elif pool.size() > 1: Choice.offer(gs, owner, "commission-ready", pool.map(func(inst): return inst.instanceId), "委托整理", {"hint": "选择手牌里一张紧急委托，完成其条件。"})
		"commission-form": gs._apply_form(owner, src, card, effect.value)
		"commission-brooms": queue(gs, owner, src, "commission-broom-attack", 5)
		"commission-clean":
			if target.is_empty(): return true
			target.unyielding = true
			damage_target(gs, owner, src, target_id, 10)
		"commission-tour":
			var bonus := 5 if int(p.get("commissionsUsed", 0)) >= 5 else 2
			for ally in Choice.live_units(gs, owner): gs._grow_unit(ally, bonus, bonus)
		"commission-awaken":
			gs._awaken(owner, src, card, effect.value)
			Choice.offer(gs, owner, "commission-clue", clue_choices(gs, owner), "选择线索", {"hint": "已达成条件且本局尚未选过的线索。"})
		"commission-urgent":
			gs.VerifiedRules.Glutton.record_permanent(u, 1, 1)
			gs._grow_unit(u, 1, 1)
		"commission-clue":
			if card.id == "sanmu-clue-solve": gs._damage_avatar(1-owner, 30, owner, src)
			else:
				if not p.has("commissionClues"): p.commissionClues = []
				if card.id not in p.commissionClues: p.commissionClues.append(card.id)
		"commission-daily":
			match int(effect.value):
				1: gs.VerifiedRules.DragonFlow.all_damage(gs, owner, src, 3)
				2:
					gs._grant_unit_armor(u, 3)
					gs._resolve_combat(owner, src, 3, false, false, false, false, null, false, {"combatCard": card})
				3:
					if not target.is_empty(): gs._grow_unit(target, 4, 4)
				4: damage_target(gs, owner, src, target_id, 6)
				5:
					for side in 2:
						var idx: int = gs._unit_index_by_uid(side, target_id)
						if idx >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, side, idx, card); break
				6:
					if not target.is_empty(): gs.VerifiedRules.Peach.revive(gs, owner, src, target, true, false)
				7: gs._draw(owner, 2)
		_: return false
	return true

static func damage_target(gs, owner: int, src: int, target, amount: int) -> void:
	for side in 2:
		if str(target) == "avatar-%d" % side:
			gs._damage_avatar(side, amount, owner, src)
			return
		var idx: int = gs._unit_index_by_uid(side, target)
		if idx >= 0:
			gs._damage_unit(side, idx, amount, owner, src)
			return

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("commission-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	match kind:
		"commission-revive": gs.VerifiedRules.Peach.revive(gs, owner, src, gs.player(owner).units[src], false, false)
		"commission-broom-attack":
			var u: Dictionary = gs.player(owner).units[src]
			if int(u.hp) <= 0 or gs.winner >= 0: return true
			var remaining := int(frame.amount)
			if remaining > 1: queue(gs, owner, src, kind, remaining-1)
			gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"crabImmuneAll": true, "commissionFixedDamage": true, "combatCard": Content.card_def("c18504")})
		"commission-study": gs._damage_avatar(1-owner, 3, owner, src)
		"commission-heal": gs._heal_avatar(owner, 3)
		"commission-draw": gs._draw(owner, 2)
	return true
