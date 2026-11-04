class_name SpiderLilyRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(unit: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(unit).get("spiderLilyRules", false))

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and int(unit.get("level", 0)) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func realm(gs, owner: int, kind: String) -> Dictionary:
	for field in gs.player(owner).realms:
		if int(field.hp) > 0 and field.get("nativeRealm") == "lily-" + kind: return field
	return {}

static func top_available(gs, owner: int) -> bool:
	return gs.phase != "opening" and not gs.player(owner).deck.is_empty() and not realm(gs, owner, "voyage").is_empty()

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary, from_deck: bool, other_deck_source: bool = false) -> Dictionary:
	var view := card.duplicate(true)
	view.sourceInstanceId = str(inst.instanceId)
	var deck_source := from_deck or other_deck_source
	view.sourceZone = "deck" if deck_source else "hand"
	if from_deck:
		view.lilyFromDeck = true
		view.lilyDeckFree = int(view.get("level", 1)) == 1
		view.text += "\n彼岸归航：从牌库顶使用，使用时你受到2点伤害。"
		view.currentCardStats = "牌库顶 · 彼岸归航 · 使用自伤2"
	elif not deck_source and int(view.get("level", 1)) == 1 and not realm(gs, owner, "road").is_empty():
		view.lilyRoadDamage = 1
		if "instant" not in view.get("keywords", []): view.keywords.append("instant")
		view.text += "\n火照之路：瞬发，使用时你受到1点伤害。"
	if view.get("lilyBounce", false):
		view.lilyInstance = inst.duplicate(true)
		view.lilyReturn = not inst.get("lilyBounceSpent", false)
		if not view.lilyReturn:
			view.keywords = view.keywords.filter(func(k): return k != "bounce")
			view.text = view.text.replace("，弹回", "") + "\n此副本已失去弹回。"
	if view.get("effect") == "lily-death":
		var src: int = gs._source_index(owner, view)
		var amount := death_damage(gs, owner, src)
		view.currentCardStats = ("牌库顶 · " if from_deck else "") + "伤害%d · 本局己方伤害%d次" % [amount, int(gs.player(owner).get("lilySelfDamageCount", 0))]
		view.text += "\n当前伤害%d。" % amount
	return view

static func death_damage(gs, owner: int, src: int) -> int:
	return 2 + int(gs.player(owner).get("lilySelfDamageCount", 0)) + (int(gs.player(owner).units[src].get("spellPower", 0)) if src >= 0 else 0)

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("spiderLilyRules", false) or card.get("type") != "awakening": return true
	var src: int = gs._source_index(owner, card)
	return src >= 0 and not gs.player(owner).units[src].awakened

static func avatar_damaged(gs, owner: int, damage_owner: int, amount: int) -> void:
	if amount <= 0 or owner != damage_owner: return
	var p: Dictionary = gs.player(owner)
	p.lilySelfDamageCount = int(p.get("lilySelfDamageCount", 0)) + 1
	# The history is global to the player, even while the flower is knocked out.
	for src in range(p.units.size() - 1, -1, -1):
		var unit: Dictionary = p.units[src]
		if source(unit) and active(unit):
			gs.resolution_stack.append({"kind": "lily-backlash", "playerIndex": owner, "sourceIndex": src, "projectile": bool(unit.awakened)})

static func unit_damaged(gs, owner: int, idx: int, amount: int) -> void:
	if amount <= 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	# Capture the form before lethal damage removes it. A lethal packet still counts.
	if unit.get("formRules", {}).get("lilyBloom", false):
		gs.resolution_stack.append({"kind": "lily-self-hit", "playerIndex": owner, "sourceIndex": idx, "amount": amount, "reason": "花开彼岸"})

static func realm_lost(gs, details: Dictionary) -> void:
	if int(details.get("amount", 0)) <= 0: return
	var owner := int(details.get("player", -1))
	if owner < 0: return
	for field in gs.player(owner).realms:
		if field.get("nativeRealm") == "lily-yellow" and str(field.get("uid", "")) == str(details.get("realm", "")):
			gs._apply_encourage(owner, 2, 2)
			return

static func before_attack(gs, owner: int) -> bool:
	var triggered := false
	for src in range(gs.player(owner).units.size() - 1, -1, -1):
		var unit: Dictionary = gs.player(owner).units[src]
		if active(unit) and unit.get("formRules", {}).get("lilyRed", false) and int(unit.get("lilyRedTurn", -1)) != gs.turn_counter:
			unit.lilyRedTurn = gs.turn_counter
			gs.resolution_stack.append({"kind": "lily-self-hit", "playerIndex": owner, "sourceIndex": src, "amount": 1, "reason": "赤团华"})
			triggered = true
	return triggered

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	if card.get("lilyReturn", false) and not frame.get("automatic", false):
		for i in gs.resolution_stack.size():
			if gs.resolution_stack[i].get("kind") == "card-complete" and gs.resolution_stack[i].get("resolutionId") == frame.resolutionId:
				gs.resolution_stack.insert(i, {"kind": "lily-bounce", "playerIndex": owner, "instance": card.lilyInstance.duplicate(true)})
				break
	if int(card.get("lilyDivination", 0)) > 0:
		gs.resolution_stack.append({"kind": "lily-divination", "playerIndex": owner, "count": int(card.lilyDivination)})
	# These are use triggers. Countering the card does not undo their damage.
	# Automatic copies are not physical hand/deck uses and cannot inherit the tax.
	if frame.get("automatic", false): return
	var amount := 2 if card.get("lilyFromDeck", false) else int(card.get("lilyRoadDamage", 0))
	if amount > 0:
		gs.resolution_stack.append({"kind": "lily-self-hit", "playerIndex": owner, "sourceIndex": int(frame.sourceIndex), "amount": amount, "reason": "彼岸归航" if card.get("lilyFromDeck", false) else "火照之路"})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"lily-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.get("formRules", {}).get("lilyBloom", false) and int(gs.player(owner).units[src].hp) > 0: gs.player(owner).units[src].swift = true
		"lily-self-damage": gs._damage_avatar(owner, int(effect.value), owner, src)
		"lily-both-damage":
			# Both players receive the card's damage before the resulting defeat check.
			gs._deferred_winner_checks += 1
			gs._damage_avatar(owner, int(effect.value), owner, src)
			gs._damage_avatar(1 - owner, int(effect.value), owner, src)
			gs._deferred_winner_checks -= 1
			gs._check_winner()
		"lily-enemy-damage": gs._damage_avatar(1 - owner, int(effect.value), owner, src)
		"lily-awaken": gs._awaken(owner, src, card, {"attack": 1, "hp": 0})
		"lily-death":
			if target.is_empty() or int(target.hp) <= 0: return true
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, str(target.uid))
				if idx >= 0: gs._damage_unit(side, idx, death_damage(gs, owner, src), owner, src)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("lily-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex", -1))
	match kind:
		"lily-divination": gs.VerifiedRules.Divination.start(gs, owner, int(frame.count))
		"lily-self-hit":
			gs._damage_avatar(owner, int(frame.amount), owner, src)
			gs.VerifiedRules.event(gs, "lily-self-damage", {"player": owner, "uid": gs.player(owner).units[src].uid, "amount": int(frame.amount), "reason": str(frame.reason)})
		"lily-backlash":
			var idx: int = gs.front_index(1 - owner) if frame.projectile else -1
			if idx >= 0: gs.VerifiedRules.base_damage_unit(gs,owner,src,1-owner,idx,1)
			else: gs.VerifiedRules.base_damage_avatar(gs,owner,src,1-owner,1)
			gs.VerifiedRules.event(gs, "lily-backlash", {"player": owner, "uid": gs.player(owner).units[src].uid, "projectile": bool(frame.projectile)})
		"lily-bounce":
			var inst: Dictionary = frame.instance.duplicate(true)
			inst.lilyBounceSpent = true
			if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
			else: gs._log("手牌已满，弹回的血华散被烧毁。", gs.TONE_DANGER)
			gs.VerifiedRules.event(gs, "lily-card-returned", {"player": owner, "instanceId": inst.instanceId})
		"lily-attack-ready": gs._resolve_combat_entered(frame.combat)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	var harm := (2 if card.get("lilyFromDeck", false) else int(card.get("lilyRoadDamage", 0)))
	if card.get("spiderLilyRules", false):
		if card.id == "c17001": harm += 1
		if card.id == "c17004": harm += 1
		if card.id == "c17006": harm += 3
		if card.id == "c17007": harm += 2
	if harm > 0 and int(gs.player(owner).avatarHp) <= harm and not gs.VerifiedRules.ArmorBlood.protects_avatar(gs, owner): return -100
	if not card.get("spiderLilyRules", false): return null
	var src: int = gs._source_index(owner, card)
	if card.effect == "lily-death":
		var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, str(target_id))
		if target.is_empty(): return -100
		return 45 + int(target.attack) * 3 + (20 if death_damage(gs, owner, src) >= int(target.hp) + int(target.shield) else 0)
	if card.id == "c17001": return 36 if gs.player(owner).hand.size() < int(gs.rules.maxHandSize) else -100
	if card.type == "form": return 55 if gs.player(owner).units[src].get("form", {}).get("cardId") != card.id else -10
	if card.type == "realm": return 48 if realm(gs, owner, str(card.realm.nativeRealm).trim_prefix("lily-")).is_empty() else -10
	return 65

static func unit_marks(gs, owner: int, idx: int) -> Array:
	var unit: Dictionary = gs.player(owner).units[idx]
	if not source(unit): return []
	var marks: Array = ["本局牌手受己方伤害%d次 · 死亡之花基础伤害%d" % [int(gs.player(owner).get("lilySelfDamageCount", 0)), 2 + int(gs.player(owner).get("lilySelfDamageCount", 0))]]
	if active(unit) and unit.get("formRules", {}).get("lilyRed", false): marks.append("赤团华 · 本回合" + ("已触发" if int(unit.get("lilyRedTurn", -1)) == gs.turn_counter else "可触发一次"))
	if active(unit) and unit.get("formRules", {}).get("lilyBloom", false): marks.append("花开彼岸 · 受到伤害时令牌手受等量己方伤害")
	return marks
