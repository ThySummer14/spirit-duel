class_name RiverRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func total(gs, owner: int) -> int:
	return int(gs.player(owner).get("fortuneRollTotal", 0))

static func die_bonus(gs, owner: int) -> int:
	return int(gs.player(owner).get("riverDieBonus", 0)) if int(gs.player(owner).get("riverDieTurn", -1)) == gs.turn_counter else 0

static func divined(gs, owner: int) -> void:
	gs.player(owner).divinationTurn = gs.turn_counter
	for unit in gs.player(owner).units:
		if active(unit) and unit.get("formRules", {}).get("riverDivinationBonus", false):
			gs.player(owner).riverDieBonus = die_bonus(gs, owner) + 1
			gs.player(owner).riverDieTurn = gs.turn_counter
	gs.VerifiedRules.event(gs, "river-divined", {"player": owner, "bonus": die_bonus(gs, owner)})

static func success(gs, owner: int) -> void:
	if owner != gs.current_player: return
	for idx in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[idx]
		if not active(unit) or not ContentLoader.runtime_unit_def(unit).get("riverFortune", false) or int(unit.get("riverRewardTurn", -1)) == gs.turn_counter: continue
		unit.riverRewardTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "river-fortune-reward", "playerIndex": owner, "sourceIndex": idx, "draw": bool(unit.awakened)})

static func summer(gs, owner: int, idx: int) -> bool:
	var unit: Dictionary = gs.player(owner).units[idx]
	return active(unit) and unit.get("formRules", {}).get("riverSummer", false) and gs.VerifiedRules.Light.roll(gs, owner, 4, 6, idx)

static func prepare_attack(gs, frame: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	if summer(gs, owner, src): frame.options.lifeSteal = true
	for side in gs.players:
		for realm in side.realms.duplicate():
			if realm.get("nativeRealm") != "river-turbulence" or int(realm.hp) <= 0: continue
			if gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src): continue
			var pool: Array = ["avatar-%d" % (1 - owner)]
			for unit in gs.player(1 - owner).units:
				if int(unit.hp) > 0: pool.append(str(unit.uid))
			frame.options.riverRedirect = str(pool[int(floor(gs.randf01() * pool.size()))])
			gs.VerifiedRules.event(gs, "river-redirect", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": frame.options.riverRedirect, "realm": realm.uid})

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("riverRules", false): return card
	var out := card.duplicate(true)
	if card.get("riverThresholdBody", false):
		var count := total(gs, owner)
		var growth := (4 if count >= 50 else 0) + (4 if count >= 100 else 0)
		out.value.attack = 8 + growth
		out.value.hp = 8 + growth
		out.effects[0].value = out.value.duplicate(true)
		out.formRules.combatKeywords = ["pierce"] if count >= 100 else []
		out.text += "\n当前累计%d点：%d力量/%d生命%s。" % [count, 8 + growth, 8 + growth, "，贯通" if count >= 100 else ""]
	if card.get("effect") == "river-song":
		var deck: Array = gs.player(owner).deck
		out.text += "\n当前顶牌：%s。" % ("空牌库" if deck.is_empty() else "%s（%d勾）" % [ContentLoader.card_def(str(deck.back().definitionId)).name, int(ContentLoader.card_def(str(deck.back().definitionId)).level)])
	return out

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"river-divination": gs.VerifiedRules.Divination.start(gs, owner, int(effect.value))
		"river-awaken":
			var unit: Dictionary = gs.player(owner).units[src]
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, 1, 1)
		"river-water":
			if target.is_empty(): return true
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target.uid)
				if idx < 0: continue
				gs.VerifiedRules.ArmorBreak.give(gs, owner, src, side, idx, 4)
				if gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src):
					for copy in gs.VerifiedRules.Fortune.last_repeats(gs, owner): gs._damage_unit(side, idx, 1 + int(card.get("foxHandDamageBonus", 0)), owner, src)
		"river-song":
			var deck: Array = gs.player(owner).deck
			if deck.is_empty(): return true
			var top: Dictionary = ContentLoader.card_def(str(deck.back().definitionId))
			gs.VerifiedRules.event(gs, "river-top-revealed", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": top})
			gs.VerifiedRules.event(gs, "ability-trigger", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": top, "reason": "大河之歌 · 展示牌库顶"})
			gs._log("大河之歌展示牌库顶「%s」（%d勾）。" % [top.name, int(top.level)], gs.TONE_CARD)
			for idx in gs.player(1 - owner).units.size():
				if gs.winner >= 0: break
				gs._damage_unit(1 - owner, idx, int(top.level) + int(card.get("foxHandDamageBonus", 0)), owner, src)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") == "river-reward-draw":
		gs._draw(int(frame.playerIndex), 1)
		return true
	if frame.get("kind") != "river-fortune-reward": return false
	var owner := int(frame.playerIndex)
	if frame.draw: gs.resolution_stack.append({"kind": "river-reward-draw", "playerIndex": owner})
	gs.VerifiedRules.Divination.start(gs, owner, 1)
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("riverRules", false): return null
	match str(card.effect):
		"river-water": return 65 if gs._unit_index_by_uid(1 - owner, target_id) >= 0 else -100
		"river-song": return 30 + gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0).size() * 9 if not gs.player(owner).deck.is_empty() else -100
		"river-awaken": return 70 if not gs.player(owner).units[gs._source_index(owner, card)].awakened else -100
		"river-divination": return 50
		"realm": return 40 if not gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "river-turbulence") else -100
		"form": return 55 if gs.player(owner).units[gs._source_index(owner, card)].get("form", {}).get("cardId") != card.id else -100
	return null
