class_name MaskRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and ContentLoader.runtime_unit_def(unit).get("maskDivination", false) and not unit.get("baseRulesSuppressed", false)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.has("maskRule"): return card
	var out := card.duplicate(true)
	out.maskInstance = inst.duplicate(true)
	if card.maskRule == "divined-instant" and int(gs.player(owner).get("divinationTurn", -1)) == gs.turn_counter:
		out.keywords.append("instant")
		out.text += "\n本回合已占卜：瞬发。"
	if card.maskRule == "hatred":
		out.value = 2 + int(gs.player(owner).get("maskHatredGrowth", 0))
		out.effects[0].value = out.value
		out.text += "\n本局同名牌已额外获得%d力量。" % int(gs.player(owner).get("maskHatredGrowth", 0))
	return out

static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int) -> void:
	if amount <= 0 or owner < 0 or src < 0 or owner == victim or owner != gs.current_player: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit) or int(unit.get("maskDivinationTurn", -1)) == gs.turn_counter: return
	unit.maskDivinationTurn = gs.turn_counter
	gs.resolution_stack.append({"kind": "mask-divination", "playerIndex": owner})

static func can_top_use(gs, owner: int, src: int, rule: String) -> bool:
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[src]
	if not active(unit) or int(unit.frozen) > 0 or p.deck.is_empty(): return false
	var card: Dictionary = ContentLoader.card_def(str(p.deck.back().definitionId))
	return card.get("maskRule") == rule and int(unit.level) >= int(card.level)

static func use_top(gs, owner: int, src: int, combat_id: int = -1) -> void:
	var p: Dictionary = gs.player(owner)
	var inst: Dictionary = p.deck.pop_back()
	var card := describe_card(gs, owner, inst, ContentLoader.card_def(str(inst.definitionId)))
	p.cardsPlayedThisTurn = int(p.cardsPlayedThisTurn) + 1
	gs.VerifiedRules.event(gs, "automatic-card", {"player": owner, "uid": p.units[src].uid, "card": card, "reason": "展示并使用牌库顶"})
	gs._push_card_frames(owner, str(card.id), null, card, src, gs.MAX_RESPONSE_DEPTH, false, combat_id)

static func attack_started(gs, frame: Dictionary) -> bool:
	if frame.get("maskGhostChecked", false): return false
	frame.maskGhostChecked = true
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	if not can_top_use(gs, owner, src, "ghost"): return false
	frame.combatId = gs.next_resolution_id
	gs.next_resolution_id += 1
	gs.resolution_stack.append(frame)
	use_top(gs, owner, src, int(frame.combatId))
	return true

static func defend_started(gs, frame: Dictionary) -> bool:
	var owner := int(frame.options.get("combatVictim",1-int(frame.playerIndex)))
	var src := int(frame.defenderIndex)
	if not can_top_use(gs, owner, src, "ghost"): return false
	frame.kind = "mask-defence-ready"
	gs.resolution_stack.append(frame)
	use_top(gs, owner, src, int(frame.combatId))
	return true

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
	if card.get("maskRule") != "ghost": return false
	for frame in gs.resolution_stack:
		if int(frame.get("combatId", -1)) != combat_id: continue
		if int(frame.playerIndex) == owner and int(frame.sourceIndex) == src:
			frame.bonus = int(frame.bonus) + int(card.value)
			frame.options.immuneCombat = true
		else:
			frame.defenderBonus = int(frame.get("defenderBonus", 0)) + int(card.value)
			frame.defenderImmuneCombat = true
			frame.defenderCombatCard = card.duplicate(true)
		gs.VerifiedRules.event(gs, "combat-response-applied", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": card})
		break
	return true

static func after_attack(gs, owner: int, src: int, options: Dictionary) -> void:
	if not ContentLoader.runtime_unit_def(gs.player(owner).units[src]).get("maskDivination", false): return
	var at: int = gs.resolution_stack.size()
	for i in gs.resolution_stack.size():
		if gs.resolution_stack[i].get("kind") == "mask-divination": at = i; break
	gs.resolution_stack.insert(at, {"kind": "mask-after-attack", "playerIndex": owner, "sourceIndex": src, "options": options.duplicate(true)})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	match str(frame.get("kind", "")):
		"mask-defence-ready":
			frame.kind = "combat-hit"
			var victim := int(frame.options.get("combatVictim", 1 - int(frame.playerIndex)))
			var defender: Dictionary = gs.player(victim).units[int(frame.defenderIndex)]
			if not gs.VerifiedRules.automatic_response(gs, victim, "unit-attacked", defender.uid, frame): gs._resolve_combat_hit(frame)
		"mask-divination": gs.VerifiedRules.Divination.start(gs, int(frame.playerIndex), 2)
		"mask-after-attack":
			var owner := int(frame.playerIndex)
			var src := int(frame.sourceIndex)
			var p: Dictionary = gs.player(owner)
			var card: Dictionary = frame.options.get("combatCard", {})
			if card.get("maskRule") == "hatred":
				p.maskHatredGrowth = int(p.get("maskHatredGrowth", 0)) + 2
				p.deck.append(card.maskInstance.duplicate(true))
				gs._shuffle(p.deck)
				gs.VerifiedRules.event(gs, "mask-hatred-returned", {"player": owner, "uid": p.units[src].uid, "card": card, "bonus": p.maskHatredGrowth})
			if gs.VerifiedRules.Yi.has_waiting(gs):gs.resolution_stack.append({"kind":"yi-mask-top","playerIndex":owner,"sourceIndex":src})
			elif can_top_use(gs, owner, src, "trick"): use_top(gs, owner, src)
		_: return false
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"mask-hand-to-top":
			var ids: Array = gs.player(owner).hand.map(func(i): return str(i.instanceId))
			if not ids.is_empty():
				gs.pending_choice = {"type": "mask-hand-top", "playerIndex": owner, "zone": "hand", "instanceIds": ids, "heading": "换 面", "title": "选择一张手牌置于牌库顶", "hint": "使用刚抽到的牌或其他手牌均可；置顶结束后再开始战斗。"}
				gs.phase = "choice"
		"mask-five-tricks":
			var p: Dictionary = gs.player(owner)
			for i in 5:
				p.deck.append({"instanceId": "%s-mask-%d" % [p.id, gs.next_card_id], "definitionId": str(card.maskTrick)})
				gs.next_card_id += 1
			gs._shuffle(p.deck)
		"mask-awaken":
			gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
			gs.player(owner).units[src].swift = true
		_: return false
	return true

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "mask-hand-top" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	var p: Dictionary = gs.player(owner)
	var idx: int = p.hand.find_custom(func(i): return str(i.instanceId) == iid)
	if idx < 0: return false
	var inst: Dictionary = p.hand.pop_at(idx)
	inst.erase("revealed")
	p.deck.append(inst)
	gs._record("resolve_divination_choice", {"instanceId": iid, "card": inst.definitionId, "choice": "mask-hand-top"}, owner)
	gs.pending_choice = {}; gs.phase = "main"
	gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "mask-hand-top": return null
	var selected := str(gs.pending_choice.instanceIds[0])
	for inst in gs.player(owner).hand:
		if ContentLoader.card_def(str(inst.definitionId)).get("maskRule") == "ghost": selected = str(inst.instanceId); break
	return resolve_choice(gs, owner, selected)

static func score_card(gs, owner: int, card: Dictionary):
	if not card.has("maskRule"): return null
	var unit: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
	if card.effect == "mask-awaken": return 80 if not unit.awakened else -100
	if card.type == "form": return 85 if unit.get("form", {}).get("cardId") != card.id else -100
	return 55 + int(card.get("value", 0)) * 5
