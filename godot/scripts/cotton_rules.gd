class_name CottonRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(unit: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(unit).get("cottonRules", false))

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and int(unit.get("level", 0)) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func night(gs, owner: int) -> int:
	return gs.VerifiedRules.Maple.night_value(gs, owner)

static func knockout_snapshot(gs, owner: int, dying: Dictionary) -> Array:
	var frames: Array = []
	if owner < 0 or not gs.VerifiedRules.OwlInsect.shikigami(dying): return frames
	for src in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[src]
		if not source(unit) or int(unit.level) < 1 or unit.get("baseRulesSuppressed", false) or (not active(unit) and unit.uid != dying.uid): continue
		if unit.awakened or unit.uid == dying.uid:
			frames.append({"kind": "cotton-death-night", "playerIndex": owner, "sourceIndex": src, "awakened": bool(unit.awakened)})
	if dying.get("formRules", {}).get("cottonSnow", false):
		frames.append({"kind": "cotton-snow", "playerIndex": owner, "sourceIndex": gs._unit_index_by_uid(owner, str(dying.uid)), "uid": dying.uid})
	frames.reverse()
	return frames

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var view := card.duplicate(true)
	if int(inst.get("cottonInstantTurn", -1)) == gs.turn_counter:
		if "instant" not in view.get("keywords", []): view.keywords.append("instant")
		view.text += "\n悄言絮语：本回合获得瞬发。"
	if not view.get("cottonRules", false): return view
	view.currentCardStats = "入夜%d/10" % night(gs, owner)
	if view.get("cottonBounce", false):
		view.cottonInstance = inst.duplicate(true)
		view.cottonReturn = not inst.get("cottonBounceSpent", false)
		if not view.cottonReturn:
			view.keywords = view.keywords.filter(func(k): return k != "bounce")
			view.text = view.text.replace("，弹回", "").replace("弹回。\n", "") + "\n此副本已失去弹回。"
	if view.get("effect") == "cotton-heal": view.currentCardStats += " · 当前恢复%d生命" % night(gs, owner)
	return view

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("cottonRules", false): return true
	var src: int = gs._source_index(owner, card)
	return src >= 0 and not (card.get("type") == "awakening" and gs.player(owner).units[src].awakened)

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("cottonRules", false): return null
	if card.get("effect") != "cotton-revive": return null
	return gs.player(owner).units.filter(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)).map(func(u): return str(u.uid))

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("cottonReturn", false) or frame.get("automatic", false): return
	for i in gs.resolution_stack.size():
		if gs.resolution_stack[i].get("kind") == "card-complete" and gs.resolution_stack[i].get("resolutionId") == frame.resolutionId:
			gs.resolution_stack.insert(i, {"kind": "cotton-bounce", "playerIndex": int(frame.playerIndex), "instance": card.cottonInstance.duplicate(true)})
			return

static func before_hit(gs, owner: int, victim: int, idx: int, options: Dictionary) -> void:
	if not options.get("cottonStun", false) or options.get("cottonStunDone", false): return
	options.cottonStunDone = true
	if gs.VerifiedRules.Maple.nightfall(gs, owner, 3) and idx >= 0:
		gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)

static func before_attacked(gs, frame: Dictionary) -> bool:
	if frame.get("cottonFearOffered", false): return false
	frame.cottonFearOffered = true
	var owner := int(frame.options.get("combatVictim",1-int(frame.playerIndex)))
	if owner==int(frame.playerIndex):return false
	var defender: Dictionary = gs.player(owner).units[int(frame.defenderIndex)]
	if not source(defender): return false
	var frames: Array = []
	for field in gs.player(owner).realms:
		if field.get("nativeRealm") != "cotton-fear" or int(field.hp) <= 0 or int(field.get("cottonUsedTurn", -1)) == gs.turn_counter: continue
		field.cottonUsedTurn = gs.turn_counter
		frames.append({"kind": "cotton-fear", "playerIndex": owner, "attackerOwner": int(frame.playerIndex), "attackerIndex": int(frame.sourceIndex), "realmUid": str(field.uid)})
	if frames.is_empty(): return false
	gs.resolution_stack.append({"kind": "cotton-defense-ready", "playerIndex": owner, "combat": frame.duplicate(true)})
	frames.reverse(); gs.resolution_stack.append_array(frames)
	return true

static func search(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var selected: Array = []
	var ability := RegEx.create_from_string("入夜\\s*(?:[0-9]+|X|Ｘ)\\s*[:：]")
	for n in 2:
		var indices: Array = []
		for i in p.deck.size():
			var def: Dictionary = Content.card_def(str(p.deck[i].definitionId))
			if ability.search(str(def.get("officialText", def.get("text", "")))) != null: indices.append(i)
		if indices.is_empty(): break
		var chosen: int = indices[mini(indices.size() - 1, int(gs.randf01() * indices.size()))]
		var inst: Dictionary = p.deck.pop_at(chosen)
		selected.append(inst)
		if p.hand.size() < int(gs.rules.maxHandSize): p.hand.append(inst)
		else: gs._log("手牌已满，悄言絮语检索的牌被烧毁。", gs.TONE_DANGER)
	var enhanced: bool = gs.VerifiedRules.Maple.nightfall(gs, owner, 5)
	if enhanced:
		for inst in selected: inst.cottonInstantTurn = gs.turn_counter
	gs.VerifiedRules.event(gs, "cotton-search", {"player": owner, "instanceIds": selected.map(func(i): return str(i.instanceId)), "instant": enhanced})

static func assault(gs, owner: int, src: int, card: Dictionary, bonus: int, target = null, options: Dictionary = {}) -> void:
	options.combatCard = card.duplicate(true)
	gs._record("assault", {"unit": src, "bonus": bonus, "target": target}, owner)
	gs._resolve_combat(owner, src, bonus, false, false, false, false, target, false, options)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	match str(effect.get("action", "")):
		"cotton-combat":
			gs._grant_unit_armor(gs.player(owner).units[src], 1)
			assault(gs, owner, src, card, int(effect.value), null, {"cottonStun": true})
		"cotton-heal":
			var amount := night(gs, owner)
			if str(target_id).begins_with("avatar-"): gs.VerifiedRules.Tide.heal(gs, owner, src, int(str(target_id).trim_prefix("avatar-")), -1, amount)
			else:
				for side in 2:
					var idx: int = gs._unit_index_by_uid(side, str(target.get("uid", "")))
					if idx >= 0: gs.VerifiedRules.Tide.heal(gs, owner, src, side, idx, amount)
		"cotton-revive":
			if gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false):
				gs.resolution_stack.append({"kind": "cotton-snow-after", "playerIndex": owner})
				gs.VerifiedRules.Movement.move_to(gs, owner, gs._unit_index_by_uid(owner, str(target.uid)), 1)
		"cotton-search": search(gs, owner)
		"cotton-heal-avatar": gs.VerifiedRules.Tide.heal(gs, owner, src, owner, -1, night(gs, owner))
		"cotton-awaken": gs._awaken(owner, src, card, effect.value)
		"cotton-flurry":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(target.get("uid", "")))
			if idx < 0 or int(target.hp) <= 0: return true
			gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx, 1, owner)
			gs.resolution_stack.append({"kind": "cotton-flurry-start", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true)})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("cotton-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex", -1))
	match kind:
		"cotton-bounce":
			var inst: Dictionary = frame.instance.duplicate(true); inst.cottonBounceSpent = true
			if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
			else: gs._log("手牌已满，弹回的一反木绵牌被烧毁。", gs.TONE_DANGER)
		"cotton-death-night":
			if frame.awakened: gs.resolution_stack.append({"kind": "cotton-death-heal", "playerIndex": owner, "sourceIndex": src})
			if gs.VerifiedRules.Maple.nightfall(gs, owner, 5):
				# A revived unit must not receive an extra reduction later in this batch.
				var knocked: Array = []
				for i in gs.player(owner).units.size():
					if int(gs.player(owner).units[i].hp) <= 0 and int(gs.player(owner).units[i].knockout) > 0: knocked.append(i)
				for i in range(knocked.size() - 1, -1, -1): gs.resolution_stack.append({"kind": "cotton-reduce-knockout", "playerIndex": owner, "sourceIndex": int(knocked[i])})
		"cotton-reduce-knockout":
			var unit: Dictionary = gs.player(owner).units[src]
			if int(unit.hp) <= 0: gs.VerifiedRules.reduce_countdown(gs, owner, src, 1)
		"cotton-death-heal":
			if gs.VerifiedRules.Maple.nightfall(gs, owner, 10): gs.VerifiedRules.ArmorBlood.heal(gs, owner, 5)
		"cotton-snow":
			var unit: Dictionary = gs.player(owner).units[src]
			if unit.uid == frame.uid:
				gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
				if int(unit.hp) > 0: gs.VerifiedRules.Movement.move_to(gs, owner, src, 1)
		"cotton-snow-after":
			if gs.VerifiedRules.Maple.nightfall(gs, owner, 7):
				var idx: int = gs.front_index(1 - owner)
				if idx >= 0: gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx, 1, owner)
		"cotton-fear":
			if gs.VerifiedRules.Maple.nightfall(gs, owner, 5): gs.VerifiedRules.Stun.apply(gs, int(frame.attackerOwner), int(frame.attackerIndex), 1, owner)
		"cotton-defense-ready": gs._offer_attack_responses(frame.combat)
		"cotton-hit-ready": gs._resolve_combat_hit(frame.combat)
		"cotton-flurry-start":
			var bonus := 2
			if gs.VerifiedRules.Maple.nightfall(gs, owner, 5): bonus += 2
			gs.resolution_stack.append({"kind": "cotton-flurry-lifesteal", "playerIndex": owner, "sourceIndex": src, "card": frame.card, "bonus": bonus})
		"cotton-flurry-lifesteal":
			var lifesteal: bool = gs.VerifiedRules.Maple.nightfall(gs, owner, 10)
			var ids: Array = gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and int(u.frozen) > 0 and not u.get("removed", false)).map(func(u): return str(u.uid))
			gs._shuffle(ids)
			gs.resolution_stack.append({"kind": "cotton-flurry-next", "playerIndex": owner, "sourceIndex": src, "card": frame.card, "bonus": int(frame.bonus), "lifesteal": lifesteal, "targets": ids})
		"cotton-flurry-next":
			var unit: Dictionary = gs.player(owner).units[src]
			if not active(unit) or gs.VerifiedRules.Stun.blocks(gs, owner, unit): return true
			var ids: Array = frame.targets.duplicate()
			while not ids.is_empty():
				var uid: String = ids.pop_front()
				var idx: int = gs._unit_index_by_uid(1 - owner, uid)
				if idx < 0 or int(gs.player(1 - owner).units[idx].hp) <= 0: continue
				var next := frame.duplicate(true); next.targets = ids; gs.resolution_stack.append(next)
				assault(gs, owner, src, frame.card, int(frame.bonus), uid, {"immuneCombat": true, "lifeSteal": bool(frame.lifesteal), "pursuit": true})
				break
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("cottonRules", false): return null
	var src: int = gs._source_index(owner, card)
	var unit: Dictionary = gs.player(owner).units[src]
	match str(card.get("effect", "")):
		"cotton-heal":
			if str(target_id) == "avatar-%d" % owner: return 10 + mini(night(gs, owner), int(gs.player(owner).maxAvatarHp) - int(gs.player(owner).avatarHp)) * 7
			var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units, str(target_id))
			return 10 + mini(night(gs, owner), int(ally.get("maxHp", 0)) - int(ally.get("hp", 0))) * 6 if not ally.is_empty() else -100
		"cotton-revive": return 65 + int(gs._unit_by_uid(gs.player(owner).units, str(target_id)).get("attack", 0)) * 3
		"cotton-search": return 42 if gs.player(owner).hand.size() < int(gs.rules.maxHandSize) else -100
		"cotton-heal-avatar": return 80
		"cotton-flurry": return 70 + gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and int(u.frozen) > 0).size() * 10
		"form": return 50 if unit.get("form", {}).get("cardId") != card.id else -10
		"realm": return 45
	return 45

static func unit_marks(gs, owner: int, idx: int) -> Array:
	var unit: Dictionary = gs.player(owner).units[idx]
	if not source(unit): return []
	var marks: Array = ["入夜%d/10 · %s气绝时检查入夜5" % [night(gs, owner), "己方式神" if unit.awakened else "自身"]]
	if unit.awakened: marks.append("气绝事件追加入夜10：回复牌手5生命")
	if active(unit) and unit.get("formRules", {}).get("cottonSnow", false): marks.append("雪夜亡魂 · 气绝后复活并移入战斗区")
	return marks
