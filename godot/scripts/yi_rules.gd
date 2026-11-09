class_name YiRules
extends RefCounted
## Shuffling schedules a resumable ability; it never opens a choice reentrantly.
const Content := preload("res://scripts/content_loader.gd")
const USE_FIELDS := ["linkedUse", "linkOtherId", "linkRetrieve", "linkedByUid", "twoFacesFromDeck", "chargedMode", "chargedReleased", "chargedSelected"]

static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("yiRules", false))

static func active(u: Dictionary) -> bool:
	return int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func clean_instance(inst: Dictionary) -> Dictionary:
	var result := preload("res://scripts/mirror_song_rules.gd")._clean(inst,true)
	for key in USE_FIELDS: result.erase(key)
	result.erase("revealed")
	return result

static func prepare_instance(gs, owner: int, card: Dictionary, automatic: bool) -> Dictionary:
	if card.get("type") not in ["form", "realm"] or not card.get("playedInstance", {}).is_empty(): return card
	var view := card.duplicate(true)
	for key in ["puppetInstance", "oniHandInstance", "garudaReturnInstance", "lilyInstance"]:
		if card.get(key, {}) is Dictionary and not card.get(key, {}).is_empty():
			view.playedInstance = card[key].duplicate(true)
			return view
	if automatic:
		view.playedInstance = {"definitionId": str(card.id), "instanceId": "%s-ability-state-%d" % [gs.player(owner).id, gs.next_card_id], "generatedByAbility": true}
		gs.next_card_id += 1
	return view

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var view := card.duplicate(true)
	view.playedInstance = inst.duplicate(true)
	if not card.get("yiRules", false): return view
	if str(card.id) == "c23902":
		view.enhanced = int(gs.player(owner).get("yiShuffleSeenTurn", -1)) == gs.turn_counter
		view.combatOption = {"shield": 0, "immuneCombat": view.enhanced}
		view.currentCardStats = "本回合已洗牌 · 免疫战斗伤害" if view.enhanced else "本回合尚未洗牌"
	elif str(card.id) == "c23908":
		var amount := int(gs.player(owner).deck.size() / 2)
		view.value = {"attack": 1 + amount, "hp": 1 + amount, "setBase": true}
		view.effects[0].value = view.value.duplicate(true)
		view.enhanced = amount > 0
		view.currentCardStats = "牌库%d张 · 当前%d/%d" % [gs.player(owner).deck.size(), 1 + amount, 1 + amount]
	return view

static func form_installed(gs, owner: int, src: int, card: Dictionary) -> void:
	var form: Dictionary = gs.player(owner).units[src].form
	form.cardInstance = form.get("puppetInstance", card.get("playedInstance", {})).duplicate(true)

static func shuffled(gs, deck: Array) -> void:
	if gs.players.size() != 2 or gs.opening_deal or gs.phase == "opening": return
	var deck_owner := -1
	for side in 2:
		if is_same(deck, gs.player(side).deck): deck_owner = side; break
	if deck_owner < 0: return
	for p in gs.players: p.yiShuffleSeenTurn = gs.turn_counter
	var owner: int = gs.current_player
	if owner < 0 or owner > 1: return
	for src in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[src]
		if not source(u) or not active(u) or int(u.get("yiDivinationTurn", -1)) == gs.turn_counter: continue
		u.yiDivinationTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "yi-shuffle", "playerIndex": owner, "sourceIndex": src, "count": 2 if u.awakened else 1, "deckOwner": deck_owner})

static func _waiting(gs) -> Array:
	return gs.resolution_stack.filter(func(f): return f.get("kind") == "yi-shuffle")

static func promote(gs) -> void:
	var waiting := _waiting(gs)
	if waiting.is_empty(): return
	gs.resolution_stack = gs.resolution_stack.filter(func(f): return f.get("kind") != "yi-shuffle")
	gs.resolution_stack.append_array(waiting)

static func defer_draw(gs, owner: int, count: int, required_level: int = -1, draw_context: Dictionary = {}) -> bool:
	if count <= 0: return false
	var waiting := _waiting(gs)
	if waiting.is_empty(): return false
	gs.resolution_stack = gs.resolution_stack.filter(func(f): return f.get("kind") != "yi-shuffle")
	gs.resolution_stack.append({"kind": "yi-draw", "playerIndex": owner, "count": count, "requiredLevel": required_level, "drawContext": draw_context, "context": gs._card_effect_context.duplicate(true)})
	gs.resolution_stack.append_array(waiting)
	gs._resolve_resolution_stack()
	return true

static func has_waiting(gs) -> bool:
	return not _waiting(gs).is_empty()

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var due := 0; var future: Array = []
	for entry in p.get("yiLongThinkDraws", []):
		if int(entry.turn) < gs.turn_counter: due += int(entry.count)
		else: future.append(entry)
	p.yiLongThinkDraws = future
	if due > 0: gs.resolution_stack.append({"kind": "yi-draw", "playerIndex": owner, "count": due, "context": {}})

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("yiRules", false): return null
	if str(card.id) == "c23903":
		return gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	if str(card.id) == "c23904":
		var src: int = gs._source_index(owner, card)
		return gs.player(owner).units.filter(func(u): return u != gs.player(owner).units[src] and not u.get("removed", false) and gs.player(owner).deck.any(func(i): return u.id in Content.card_unit_ids(Content.card_def(str(i.definitionId))))).map(func(u): return str(u.uid))
	return null

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("yiRules", false): return true
	if str(card.id) == "c23905": return not gs.player(owner).units[gs._source_index(owner, card)].awakened
	if str(card.id) == "c23904": return not targets(gs, owner, card).is_empty()
	if str(card.id) == "c23901":
		return gs.player(owner).hand.any(func(i): return str(i.instanceId) != str(card.get("sourceInstanceId", "")))
	return true

static func _start_hand(gs, owner: int) -> void:
	var ids: Array = gs.player(owner).hand.map(func(i): return str(i.instanceId))
	if ids.is_empty(): return
	gs.pending_choice = {"type": "yi-long-think", "playerIndex": owner, "zone": "hand", "instanceIds": ids, "heading": "长 考", "hint": "选择一张真实手牌洗回牌库；下个己方回合额外抽两张。"}
	gs.phase = "choice"

static func _start_search(gs, owner: int, target_id) -> void:
	var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, str(target_id))
	if target.is_empty(): return
	var ids: Array = gs.player(owner).deck.filter(func(i): return target.id in Content.card_unit_ids(Content.card_def(str(i.definitionId)))).map(func(i): return str(i.instanceId))
	if ids.is_empty(): return
	gs.pending_choice = {"type": "yi-search", "playerIndex": owner, "zone": "deck", "instanceIds": ids, "targetUid": target_id, "heading": "神 之 一 手", "hint": "选择%s牌库中的一张真实专属牌置入手牌。" % target.name}
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["yi-long-think", "yi-search"] or int(choice.playerIndex) != owner: return null
	for inst in gs.player(owner).get(str(choice.zone), []):
		if str(inst.instanceId) == iid:
			if choice.zone == "hand": return gs.hand_card_def(owner, gs.player(owner).hand.find(inst))
			return gs.describe_card_instance(owner, inst, false)
	return {}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["yi-long-think", "yi-search"] or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	var p: Dictionary = gs.player(owner); var zone: Array = p[str(choice.zone)]
	var idx: int = zone.find_custom(func(i): return str(i.instanceId) == iid)
	if idx < 0: return false
	var inst: Dictionary = zone.pop_at(idx)
	gs.pending_choice = {}; gs.phase = "main"
	if choice.type == "yi-long-think":
		p.deck.append(clean_instance(inst))
		if not p.has("yiLongThinkDraws"): p.yiLongThinkDraws = []
		p.yiLongThinkDraws.append({"turn": gs.turn_counter, "count": 2})
		gs._shuffle(p.deck)
	else:
		gs.VerifiedRules.BondDream.fetched(gs, inst)
		if p.hand.size() < int(gs.rules.maxHandSize): p.hand.append(inst)
	gs._record("resolve_divination_choice", {"choice": choice.type, "instanceId": iid, "card": inst.definitionId}, owner)
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true

static func _return(gs, owner: int, inst: Dictionary) -> bool:
	if inst.is_empty(): return false
	var entry := clean_instance(inst)
	for p in gs.players:
		if p.deck.any(func(i): return str(i.instanceId) == str(entry.instanceId)) or p.hand.any(func(i): return str(i.instanceId) == str(entry.instanceId)): return false
	gs.player(owner).deck.append(entry)
	return true

static func review(gs, owner: int) -> void:
	var returned := [false, false]
	for side in 2:
		for src in gs.player(side).units.size():
			var u: Dictionary = gs.player(side).units[src]
			if u.get("form", {}).is_empty(): continue
			var inst: Dictionary = u.form.get("puppetInstance", u.form.get("cardInstance", {})).duplicate(true)
			gs.VerifiedRules.Forms.remove(gs, side, src, "被复盘洗回牌库", true)
			returned[side] = _return(gs, side, inst) or returned[side]
			gs.VerifiedRules.event(gs, "yi-form-returned", {"player": side, "uid": u.uid, "instanceId": inst.get("instanceId", ""), "tracked": not inst.is_empty()})
		for realm in gs.player(side).realms.duplicate():
			var inst: Dictionary = realm.get("cardInstance", {}).duplicate(true)
			if inst.is_empty(): inst = realm.get("returnInstance", {}).duplicate(true)
			gs.player(side).realms.erase(realm)
			gs.VerifiedRules.TwinSight.realm_left(gs, side, realm)
			returned[side] = _return(gs, side, inst) or returned[side]
			gs.VerifiedRules.event(gs, "yi-realm-returned", {"player": side, "realm": realm.uid, "instanceId": inst.get("instanceId", ""), "tracked": not inst.is_empty()})
	gs.VerifiedRules.Night.refresh(gs); gs.VerifiedRules.MonkCleaner.refresh(gs); gs.VerifiedRules.Enma.refresh(gs); gs.VerifiedRules.OwlInsect.refresh(gs)
	for side in 2:
		if returned[side]: gs._shuffle(gs.player(side).deck)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"yi-long-think": _start_hand(gs, owner)
		"yi-combat":
			var options: Dictionary = card.get("combatOption", {}).duplicate(true); options.combatCard = card.duplicate(true)
			gs._record("assault", {"unit": src, "bonus": 2, "target": target_id}, owner)
			gs._resolve_combat(owner, src, 2, false, false, false, false, target_id, false, options)
		"yi-damage":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(target_id))
			if idx >= 0:
				gs.resolution_stack.append({"kind": "yi-damage-follow", "playerIndex": owner, "sourceIndex": src, "targetId": target_id})
				gs._damage_unit(1 - owner, idx, 3 + int(u.get("spellPower", 0)), owner, src)
		"yi-search": _start_search(gs, owner, target_id)
		"yi-awaken":
			gs.resolution_stack.append({"kind": "yi-awaken-complete", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true)})
			gs.VerifiedRules.BookJue.start_dispatch(gs, owner, owner, false, false)
			gs.pending_choice.heading = "觉 醒 · 弈"
		"yi-heal-draw":
			gs._heal_avatar(owner, 3)
			gs.resolution_stack.append({"kind": "yi-return-current", "playerIndex": owner, "instance": card.get("playedInstance", {}).duplicate(true)})
			gs._draw(owner, 1)
		"yi-review": review(gs, owner)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("yi-"): return false
	var owner := int(frame.playerIndex)
	match kind:
		"yi-shuffle":
			gs.VerifiedRules.event(gs, "yi-shuffle-divination", {"player": owner, "uid": gs.player(owner).units[int(frame.sourceIndex)].uid, "count": int(frame.count), "deckOwner": int(frame.deckOwner)})
			gs.VerifiedRules.Divination.start(gs, owner, int(frame.count))
		"yi-draw":
			var context: Dictionary = gs._card_effect_context; gs._card_effect_context = frame.get("context", {})
			gs._draw(owner, int(frame.count), int(frame.get("requiredLevel", -1)), frame.get("drawContext", {})); gs._card_effect_context = context
		"yi-awaken-complete": gs._awaken(owner, int(frame.sourceIndex), frame.card, {"attack": 1, "hp": 1})
		"yi-damage-follow":
			var enemy := 1 - owner; var idx: int = gs._unit_index_by_uid(enemy, str(frame.targetId))
			if idx < 0 or int(gs.player(enemy).units[idx].hp) <= 0: return true
			var target: Dictionary = gs.player(enemy).units[idx]
			var pool: Array = gs.player(enemy).hand.filter(func(i): return target.id in Content.card_unit_ids(Content.card_def(str(i.definitionId))))
			if not pool.is_empty():
				var inst: Dictionary = pool[int(gs.next_random() % pool.size())]
				gs.player(enemy).hand.erase(inst); gs.player(enemy).deck.append(clean_instance(inst)); gs._shuffle(gs.player(enemy).deck)
				gs.VerifiedRules.event(gs, "yi-enemy-hand-returned", {"player": enemy, "uid": target.uid, "instanceId": inst.instanceId})
		"yi-return-current":
			if _return(gs, owner, frame.instance): gs._shuffle(gs.player(owner).deck)
		"yi-mask-top":
			if gs.VerifiedRules.Mask.can_top_use(gs, owner, int(frame.sourceIndex), "trick"): gs.VerifiedRules.Mask.use_top(gs, owner, int(frame.sourceIndex))
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") not in ["yi-long-think", "yi-search"]: return null
	if int(gs.pending_choice.playerIndex) != owner: return false
	var best := ""; var best_score := -99999
	for iid in gs.pending_choice.instanceIds:
		var card: Dictionary = choice_card(gs, owner, str(iid)); var src: int = gs._source_index(owner, card)
		var usable: bool = src >= 0 and int(gs.player(owner).units[src].hp) > 0 and int(gs.player(owner).units[src].level) >= int(card.get("level", 1))
		var score := int(card.get("level", 1)) * 4
		if gs.pending_choice.type == "yi-search": score += 30 if usable else 0
		else: score += 30 if not usable else 0
		if score > best_score: best = str(iid); best_score = score
	return resolve_choice(gs, owner, best) if best != "" else false

static func score_card(gs, owner: int, card: Dictionary, _target):
	if not card.get("yiRules", false): return null
	match str(card.id):
		"c23901": return 24
		"c23902": return 45 if card.get("enhanced", false) else 25
		"c23904": return 52
		"c23905": return 60
		"c23906": return 20 + maxi(0, int(gs.player(owner).maxAvatarHp) - int(gs.player(owner).avatarHp)) * 3
		"c23907": return 30 + gs.player(1 - owner).realms.size() * 6
		"c23908": return int(card.value.attack) * 4
	return 40

static func marks(gs, owner: int, src: int) -> Array:
	var u: Dictionary = gs.player(owner).units[src]
	if not source(u): return []
	return ["己方回合首次洗牌 · 占卜%d%s" % [2 if u.awakened else 1, " · 本回合已触发" if int(u.get("yiDivinationTurn", -1)) == gs.turn_counter else ""]]
