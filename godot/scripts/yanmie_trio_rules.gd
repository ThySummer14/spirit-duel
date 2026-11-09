class_name YanmieTrioRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const SEEDS := {"c63002": "c10702", "c63004": "c10703", "c63008": "c10705"}
const WISDOM := "yanmie-wisdom"
const FEATHER := "yanmie-feather"

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and int(unit.get("level", 0)) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func role(unit: Dictionary, key: String) -> bool:
	return Content.runtime_unit_def(unit).get("yanmieRole") == key

static func shikigami(unit: Dictionary) -> bool:
	return not unit.is_empty() and not unit.get("summoned", false) and not unit.get("removed", false)

static func can_revive(gs, owner: int, unit: Dictionary) -> bool:
	if not shikigami(unit) or int(unit.hp) > 0 or not gs.VerifiedRules.Rebirth.can_revive(unit): return false
	return int(unit.knockout) == 0 or not gs.player(1-owner).units.any(func(u): return active(u) and u.get("formRules", {}).get("yanmieLamp", false))

static func revive(gs, owner: int, idx: int) -> bool:
	if idx < 0: return false
	return gs.VerifiedRules.Peach.revive(gs, owner, -1, gs.player(owner).units[idx], false, false)

static func position(gs, uid) -> Vector2i:
	var owner: int = 0
	var idx: int = gs._unit_index_by_uid(owner, uid)
	if idx < 0:
		owner = 1
		idx = gs._unit_index_by_uid(owner, uid)
	return Vector2i(owner, idx)

static func realm_list(gs, owner: int, kind: String) -> Array:
	return gs.player(owner).realms.filter(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == kind)

static func attack(gs, owner: int, src: int, immune: bool = false, extra: Dictionary = {}) -> void:
	if src < 0 or int(gs.player(owner).units[src].hp) <= 0: return
	var options := extra.duplicate(true)
	options.immuneCombat = immune
	gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, options)

static func add_card(gs, owner: int, id: String, tag: String = "") -> void:
	var p: Dictionary = gs.player(owner)
	if p.hand.size() >= int(gs.rules.maxHandSize): return
	var inst := {"definitionId": id, "instanceId": "%s-yanmie-%d" % [p.id, gs.next_card_id]}
	gs.next_card_id += 1
	if not tag.is_empty(): inst[tag] = gs.turn_counter
	p.hand.append(inst)
	gs.VerifiedRules.event(gs, "yanmie-card-gained", {"player": owner, "cardId": id, "instanceId": inst.instanceId})

static func targets(gs, owner: int, card: Dictionary):
	var mode := str(card.get("target", ""))
	if not mode.begins_with("yanmie-"): return null
	var ids: Array = []
	for side in 2:
		for u in gs.player(side).units:
			if u.get("removed", false): continue
			if side != owner and (gs.VerifiedRules.Combat.has(u, "veil") or gs.VerifiedRules.Movement.has_veil(u)): continue
			match mode:
				"yanmie-recent":
					if shikigami(u) and int(u.hp) > 0 and int(u.get("yanmieRevivedTurn", -99)) >= gs.turn_counter-1: ids.append(u.uid)
				"yanmie-dead", "yanmie-lamp":
					if (mode != "yanmie-lamp" or owner == side) and can_revive(gs, side, u): ids.append(u.uid)
				"yanmie-form":
					if int(u.hp) > 0 and not u.get("form", {}).get("cardInstance", {}).is_empty(): ids.append(u.uid)
				"yanmie-live":
					if int(u.hp) > 0 and shikigami(u): ids.append(u.uid)
	return ids

static func white_random_hit(gs, owner: int, src: int, amount: int) -> void:
	var candidates: Array = [-1]
	for idx in gs.player(1-owner).units.size():
		if int(gs.player(1-owner).units[idx].hp) > 0: candidates.append(idx)
	var idx: int = candidates[int(gs.randf01() * candidates.size())]
	if idx < 0: gs.VerifiedRules.base_damage_avatar(gs, owner, src, 1-owner, amount)
	else: gs.VerifiedRules.base_damage_unit(gs, owner, src, 1-owner, idx, amount)

static func revived(gs, owner: int, idx: int, early: bool) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if not shikigami(unit): return
	unit.yanmieRevivedTurn = gs.turn_counter
	var lineup: Array = gs.player(owner).units
	for src in range(lineup.size() - 1, -1, -1):
		var white: Dictionary = lineup[src]
		if not active(white) or not role(white, "white"): continue
		var form: Dictionary = white.get("formRules", {})
		if form.get("yanmieYoung", false): unit.yanmieInstantTurn = gs.turn_counter
		if form.get("yanmieLamp", false) and early and gs.current_player == owner:
			var last: Dictionary = unit.get("yanmieLastForm", {})
			if not last.is_empty():
				gs.resolution_stack.append({"kind": "yanmie-last-form", "playerIndex": owner, "sourceIndex": idx, "card": last})
		var amount := 2 if white.awakened else 1
		gs.VerifiedRules.HairPower.give(gs, owner, idx, amount)
		gs.resolution_stack.append({"kind": "yanmie-white-hit", "playerIndex": owner, "sourceIndex": src, "amount": amount})

static func knocked_out(gs, owner: int, unit: Dictionary) -> void:
	if owner < 0 or not shikigami(unit): return
	if realm_list(gs, owner, "yanmie-father").is_empty(): return
	gs.resolution_stack.append({"kind": "yanmie-father-revive", "playerIndex": owner, "target": unit.uid})

static func remember_form(unit: Dictionary) -> void:
	var form: Dictionary = unit.get("form", {})
	if form.get("cardInstance", {}).is_empty() or form.get("cardView", {}).is_empty(): return
	unit.yanmieLastForm = form.cardView.duplicate(true)

static func origin_card(card: Dictionary, inst: Dictionary) -> Dictionary:
	var form_id := str(card.id)
	var origin: Dictionary = Content.card_def(SEEDS[form_id]).duplicate(true)
	origin.unitId = "yingcao-pupu"
	origin.keywords = ["instant"]
	origin.yanmieOriginOf = form_id
	origin.playedInstance = inst.duplicate(true)
	return origin

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var id := str(card.get("id", ""))
	var result := card
	if SEEDS.has(id):
		result = card.duplicate(true)
		result.originCard = origin_card(card, inst)
	if id == "c62706" and targets(gs, owner, card).is_empty():
		result = result.duplicate(true)
		result.target = "auto"
	if id == "c63007":
		var idx: int = gs._source_index(owner, card)
		if idx >= 0 and int(gs.player(owner).units[idx].level) < int(card.level):
			result = result.duplicate(true)
			result.level = 1
			result.realm.nativeRealm = "yanmie-clover-trick"
			result.currentCardStats = "戏法 · 蒲蒲形态进场投射2"
	if id == "c63202" and inst.get("yanmieBounceSpent", false):
		result = result.duplicate(true)
		result.keywords = result.get("keywords", []).filter(func(k): return str(k).to_lower() != "bounce")
		result.currentCardStats = "此牌已弹回一次"
	var idx: int = gs._source_index(owner, result)
	if idx >= 0 and int(gs.player(owner).units[idx].get("yanmieInstantTurn", -1)) == gs.turn_counter and not gs._kw(result, "instant"):
		result = result.duplicate(true)
		result.keywords.append("instant")
	if int(inst.get("yanmieFreeTurn", -1)) == gs.turn_counter:
		result = result.duplicate(true)
		result.yanmieFree = true
	return result

static func activate_seed(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or not role(u, "pupu") or int(u.get("yanmieSeedTurn", -1)) == gs.turn_counter: return
	u.yanmieSeedTurn = gs.turn_counter
	if not u.form.is_empty():
		seed_entry(gs, owner, src, u.formRules, int(u.get("yanmieWisdomOption", 0)), false)
	elif u.awakened:
		var pool: Array = SEEDS.keys().filter(func(id): return int(Content.card_def(id).level) <= int(u.level))
		if not pool.is_empty(): add_card(gs, owner, pool[int(gs.randf01() * pool.size())])
	else: add_card(gs, owner, WISDOM)

static func announced(gs, owner: int, src: int) -> void:
	activate_seed(gs, owner, src)

static func seed_entry(gs, owner: int, src: int, cfg: Dictionary, wisdom: int, initial: bool) -> void:
	var light := str(cfg.get("fireflyLight", ""))
	if not light.is_empty():
		if not initial: gs.VerifiedRules.Firefly.light_effect(gs, owner, src, light)
		return
	match str(cfg.get("yanmieSeed", "")):
		"insight":
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2)
		"power":
			var idx: int = gs.front_index(1-owner)
			if idx < 0: return
			var result: Dictionary = gs._damage_unit(1-owner, idx, 2, owner, src)
			if not result.get("knocked", false):
				gs.VerifiedRules.HairPower.give(gs, 1-owner, idx, -2)
		"waking":
			var living: Array = gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0)
			if not living.is_empty():
				var u: Dictionary = living[int(gs.randf01() * living.size())]
				gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, u.uid), 3, owner, src)
			if gs.winner < 0: gs._damage_avatar(1-owner, 3, owner, src)
		"wisdom":
			var amount: int = int(gs.player(owner).units[src].level)
			if wisdom == 1: gs._damage_avatar(1-owner, amount, owner, src)
			elif wisdom == 2: gs._heal_avatar(owner, amount)

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if card.get("paperTransform", false) or u.form.get("cardId") != card.get("id"): return
	if role(u, "pupu") or gs.player(owner).units.any(func(ally): return ally.get("id") == "guishibai"):
		u.form.cardView = card.duplicate(true)
	var cfg: Dictionary = u.formRules
	if cfg.get("yanmieYoung", false): revive(gs, owner, src)
	var target := position(gs, card.get("yanmieEntryTarget"))
	if cfg.get("yanmieLamp", false) and target.x == owner: revive(gs, owner, target.y)
	if cfg.get("yanmieSoul", false) and target.x == owner and target.y >= 0: gs._grant_unit_armor(gs.player(owner).units[target.y], 3)
	if cfg.get("yanmieTop", false): add_card(gs, owner, "c63202")
	if cfg.get("yanmieSeed") == "wisdom":
		u.yanmieWisdomOption = int(card.get("yanmieWisdomOption", 0))
	seed_entry(gs, owner, src, cfg, int(u.get("yanmieWisdomOption", 0)), true)
	if int(u.hp) <= 0: return
	gs.resolution_stack.append({"kind": "yanmie-form-entry", "playerIndex": owner, "sourceIndex": src, "faction": Factions.get_faction(u), "pupu": role(u, "pupu")})

static func form_reactions(gs, owner: int, src: int, faction: String, pupu: bool) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	for realm in realm_list(gs, owner, "yanmie-wind"):
		if faction in ["苍叶", "青岚"] and int(realm.get("yanmieUsedTurn", -1)) != gs.turn_counter:
			realm.yanmieUsedTurn = gs.turn_counter
			gs._draw(owner, 1)
	for realm in realm_list(gs, owner, "yanmie-clover-trick"):
		if pupu and int(realm.get("yanmieUsedTurn", -1)) != gs.turn_counter:
			realm.yanmieUsedTurn = gs.turn_counter
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2)
	if not realm_list(gs, owner, "yanmie-clover").is_empty() and int(u.get("yanmieCloverTurn", -1)) != gs.turn_counter:
		u.yanmieCloverTurn = gs.turn_counter
		attack(gs, owner, src, true)

static func turn_start(gs, owner: int) -> void:
	for side in 2:
		for u in gs.player(side).units:
			if int(u.get("yanmieHideOwner", -1)) == owner:
				u.attackBonus = int(u.attackBonus) + int(u.yanmieHideAmount)
				u.erase("yanmieHideOwner")
				u.erase("yanmieHideAmount")
				gs._recalc(u)
	for idx in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[idx]
		if not active(u) or not role(u, "pupu") or not u.awakened: continue
		var id := str(u.form.get("cardId", ""))
		var view: Dictionary = u.form.get("cardView", {})
		var inst: Dictionary = u.form.get("cardInstance", {})
		if SEEDS.has(id):
			var origin := origin_card(view, inst)
			gs._push_card_frames(owner, str(inst.get("definitionId", id)), null, origin, idx, 0, true)
		elif view.has("yanmieOriginOf"):
			var card: Dictionary = Content.card_def(str(view.yanmieOriginOf)).duplicate(true)
			card.playedInstance = inst
			gs._push_card_frames(owner, str(inst.get("definitionId", card.id)), null, card, idx, 0, true)
		elif id == WISDOM:
			view = view.duplicate(true)
			view.yanmieWisdomOption = 3-int(u.get("yanmieWisdomOption", 1))
			gs._push_card_frames(owner, id, null, view, idx, 0, true)

static func end_turn(gs, _owner: int) -> void:
	for side in 2:
		var hand: Array = gs.player(side).hand
		for i in range(hand.size() - 1, -1, -1):
			if hand[i].definitionId == FEATHER: gs.discard_hand_card(side, i)

static func twins_form(gs, owner: int, key: String) -> int:
	var units: Array = gs.player(owner).units
	return units.find_custom(func(u): return active(u) and u.get("formRules", {}).get(key, false))

static func armor_gained(gs, unit: Dictionary, amount: int) -> void:
	if amount <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(unit): return
	var pos := position(gs, unit.uid)
	if pos.y < 0: return
	var units: Array = gs.player(pos.x).units
	var idx := units.find_custom(func(u): return active(u) and role(u, "twins"))
	if idx < 0: return
	var twins: Dictionary = units[idx]
	var first: bool = int(unit.get("yanmieArmorTurn", -1)) != gs.turn_counter
	if not twins.awakened:
		if first:
			unit.yanmieArmorTurn = gs.turn_counter
			gs.VerifiedRules.HairPower.give(gs, pos.x, pos.y, 1)
		return
	gs.VerifiedRules.HairPower.give(gs, pos.x, pos.y, amount)
	if amount >= 3 and first:
		unit.yanmieArmorTurn = gs.turn_counter
		unit.swift = true
		if amount >= 6:
			unit.untilAttack = unit.get("untilAttack", {})
			var keywords: Array = unit.untilAttack.get("keywords", [])
			if "pierce" not in keywords: keywords.append("pierce")
			unit.untilAttack.keywords = keywords

static func armor_removed(gs, owner: int, idx: int, amount: int) -> void:
	if amount <= 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	if int(unit.front) != 1 or int(unit.shield) != 0: return
	for realm in realm_list(gs, owner, "yanmie-shrine"):
		var src: int = gs._source_index(owner, {"unitId": realm.sourceUnit})
		if src >= 0: gs.resolution_stack.append({"kind":"yanmie-shrine-shot", "playerIndex":owner, "sourceIndex":src})

static func top_visible(gs, owner: int) -> bool:
	return gs.phase != "opening" and not gs.player(owner).deck.is_empty() and twins_form(gs, owner, "yanmieTop") >= 0

static func top_available(gs, owner: int) -> bool:
	if not top_visible(gs, owner) or int(gs.player(owner).get("yanmieTopUsedTurn", -1)) == gs.turn_counter: return false
	var p: Dictionary = gs.player(owner)
	var src: int = gs._source_index(owner, Content.card_def(str(p.deck.back().definitionId)))
	return src >= 0 and int(p.units[src].shield) >= 3

static func top_card(card: Dictionary) -> Dictionary:
	var out := card.duplicate(true)
	out.yanmieFromDeck = true
	out.yanmieFree = true
	out.sourceZone = "deck"
	out.currentCardStats = "牌库顶 · 千纸千烛 · 不耗鬼火"
	return out

static func combat_ready(gs, owner: int, src: int, options: Dictionary) -> void:
	var attacker: Dictionary = gs.player(owner).units[src]
	options.yanmieSoul = twins_form(gs, owner, "yanmieSoul") >= 0
	options.yanmieDamageBefore = int(attacker.get("yanmieDamageTaken", 0))

static func before_attack(gs, frame: Dictionary) -> bool:
	if frame.get("yanmieSeedChecked", false) or gs.winner >= 0: return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[src]
	if not unit.awakened or not role(unit, "pupu") or not gs.VerifiedRules.Samurai.combat_available(unit, frame.options): return false
	frame.yanmieSeedChecked = true
	var depth: int = gs.resolution_stack.size()
	activate_seed(gs, owner, src)
	if gs.resolution_stack.size() <= depth: return false
	gs.resolution_stack.insert(depth, frame)
	return true

static func combat_finished(gs, owner: int, src: int, defender: Dictionary, options: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if options.get("yanmieSoul", false) and int(unit.get("yanmieDamageTaken", 0)) == int(options.get("yanmieDamageBefore", -1)):
		if int(defender.get("hp", 0)) > 0:
			var pos := position(gs, defender.uid)
			if pos.x != owner: gs.VerifiedRules.Panguan.destroy(gs, owner, src, pos.x, pos.y)
	if options.get("yanmieGuardRewards", false) and int(unit.hp) > 0:
		if int(unit.shield) >= 3: gs._draw(owner, 1)
		if int(unit.shield) >= 6: gs._set_fire(owner, int(gs.player(owner).energy) + 1)
	var follow: int = gs._unit_index_by_uid(owner, options.get("yanmieHideTarget"))
	if follow >= 0 and int(gs.player(owner).units[follow].hp) > 0:
		gs._grant_unit_armor(gs.player(owner).units[follow], 2)
		attack(gs, owner, follow)

static func realm_entered(gs, owner: int, card: Dictionary) -> void:
	match card.get("realm", {}).get("nativeRealm", ""):
		"yanmie-father": gs._apply_encourage(owner, 0, 1, 1)
		"yanmie-shrine": gs.VerifiedRules.HairPower.grant_guard(gs, owner, 0, 2)

static func complete(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.id != "c63202": return
	var inst: Dictionary = card.get("playedInstance", {}).duplicate(true)
	if inst.is_empty() or inst.get("yanmieBounceSpent", false): return
	var p: Dictionary = gs.player(int(frame.playerIndex))
	inst.yanmieBounceSpent = true
	if p.hand.size() < int(gs.rules.maxHandSize): p.hand.append(inst)

static func choose(gs, owner: int, kind: String, ids: Array, src: int, card: Dictionary, heading: String) -> void:
	gs.pending_choice = {"type": "yanmie-" + kind, "instanceIds": ids, "playerIndex": owner, "sourceIndex": src, "card": card, "heading": heading, "hint": "选择一项"}
	gs.phase = "choice"

static func living_ids(gs, owner: int, faction: String = "") -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (faction.is_empty() or Factions.get_faction(u) == faction)).map(func(u): return str(u.uid))

static func hide_attack(gs, owner: int, src: int, card: Dictionary, follow = null) -> void:
	gs._grant_unit_armor(gs.player(owner).units[src], 2)
	gs._resolve_combat(owner, src, 2, false, false, false, false, null, false, {"combatCard":card, "yanmieHideTarget":follow})

static func resolve_choice(gs, owner: int, id: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner or id not in choice.get("instanceIds", []): return false
	var kind := str(choice.type)
	var card: Dictionary = choice.card
	var src := int(choice.sourceIndex)
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"choice": kind, "instanceId": id}, owner)
	match kind:
		"yanmie-song":
			if id == "armor": choose(gs, owner, "song-target", living_ids(gs, owner), src, card, "童羽歌 · 选择己方式神")
			else: gs.start_divination(owner, {"id": card.id, "divination":{"count":2}}, {})
		"yanmie-song-target":
			var idx: int = gs._unit_index_by_uid(owner, id)
			if idx >= 0: gs._grant_unit_armor(gs.player(owner).units[idx], 1)
		"yanmie-hide":
			if id == "attack": choose(gs, owner, "hide-target", living_ids(gs, owner, "红莲"), src, card, "隐身术 · 选择红莲式神")
			else:
				for enemy in gs.player(1-owner).units:
					if int(enemy.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(enemy) or Factions.get_faction(enemy) != "苍叶": continue
					enemy.attackBonus = int(enemy.attackBonus) - 4
					enemy.yanmieHideOwner = owner
					enemy.yanmieHideAmount = int(enemy.get("yanmieHideAmount", 0)) + 4
					gs._recalc(enemy)
				hide_attack(gs, owner, src, card)
		"yanmie-hide-target": hide_attack(gs, owner, src, card, id)
		"yanmie-wisdom":
			card.yanmieWisdomOption = 1 if id == "damage" else 2
			gs._apply_form(owner, src, card)
		_: return false
	gs._resolve_resolution_stack()
	gs._check_winner()
	gs.state_changed.emit()
	return true

static func choice_card(gs, owner: int, id: String):
	var pending: Dictionary = gs.pending_choice
	if not str(pending.get("type", "")).begins_with("yanmie-") or int(pending.playerIndex) != owner: return null
	var labels := {"armor":"护甲", "divine":"占卜", "attack":"红莲追击", "weaken":"削弱苍叶", "damage":"伤害", "heal":"恢复"}
	var details := {"armor":"使一个己方式神+1护甲。", "divine":"占卜2。", "attack":"战斗后使一个己方红莲式神+2护甲并发起一次攻击。", "weaken":"所有敌方苍叶式神-4力量，直到你的下个回合开始。", "damage":"对敌方牌手造成等于蒲蒲等级的伤害。", "heal":"恢复己方牌手等于蒲蒲等级的生命。"}
	var unit: Dictionary = gs._unit_by_uid(gs.player(owner).units, id)
	var label := str(unit.get("name", labels.get(id, id)))
	var text := str(details.get(id, label))
	if pending.type == "yanmie-song-target": text = "%s 获得1护甲。" % label
	if pending.type == "yanmie-hide-target": text = "战斗后 %s 获得2护甲并发起一次攻击。" % label
	return {"id": id, "name": label, "type": "spell", "typeLabel": "选择", "text": text, "level": 1, "cost": 0, "rarity": "common", "unitId": pending.card.unitId}

static func ai_choice(gs, owner: int):
	var pending: Dictionary = gs.pending_choice
	if not str(pending.get("type", "")).begins_with("yanmie-") or int(pending.playerIndex) != owner: return null
	var ids: Array = pending.instanceIds
	if ids.is_empty(): return null
	match pending.type:
		"yanmie-song": return "armor" if int(gs.front_unit(owner).get("shield", 0)) == 2 else "divine"
		"yanmie-wisdom": return "heal" if int(gs.player(owner).avatarHp) <= 5 and int(gs.player(1-owner).avatarHp) > 3 else "damage"
		"yanmie-hide": return "attack" if ids.has("attack") else "weaken"
		"yanmie-song-target", "yanmie-hide-target":
			var best := str(ids[0])
			var score := -1
			for id in ids:
				var unit: Dictionary = gs._unit_by_uid(gs.player(owner).units, id)
				var value := int(unit.attack) + int(unit.shield) + (4 if int(unit.front) == 1 else 0)
				if value > score:
					best = id
					score = value
			return best
	return ids[0]

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	var id := str(card.get("id", ""))
	if not action.begins_with("yanmie-") and (action != "form" or id not in ["c62706", "c63203", WISDOM]): return false
	var pos := position(gs, target_id)
	var unit: Dictionary = gs.player(owner).units[src]
	if action == "form" and id in ["c62706", "c63203", WISDOM]:
		if id == WISDOM and not card.has("yanmieWisdomOption"):
			choose(gs, owner, "wisdom", ["damage", "heal"], src, card, "智慧之种")
		else:
			var form_card := card.duplicate(true)
			form_card.yanmieEntryTarget = target_id
			gs._apply_form(owner, src, form_card, effect.value if effect.get("value") is Dictionary else {})
		return true
	match action:
		"yanmie-royal":
			if pos.y < 0 or int(target.hp) <= 0: return true
			if pos.x == owner: gs.VerifiedRules.HairPower.give(gs, owner, pos.y, 2)
			else: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, pos.x, pos.y, 3, false)
			attack(gs, pos.x, pos.y)
		"yanmie-return":
			var depth: int = gs.resolution_stack.size()
			if revive(gs, pos.x, pos.y):
				gs.resolution_stack.insert(depth, {"kind":"yanmie-return-faction", "playerIndex":pos.x, "target":target.uid, "faction":Factions.get_faction(target)})
		"yanmie-cycle", "yanmie-borrow":
			if pos.y < 0: return true
			var depth: int = gs.resolution_stack.size()
			var frame := {"kind": action, "playerIndex": owner, "target": target.uid, "destroyed": false}
			gs.resolution_stack.insert(depth, frame)
			frame.destroyed = gs.VerifiedRules.Panguan.destroy(gs, owner, src, pos.x, pos.y, card)
		"yanmie-recall":
			if pos.y < 0 or target.get("form", {}).is_empty(): return true
			var inst: Dictionary = target.form.get("cardInstance", {}).duplicate(true)
			if inst.is_empty(): return true
			gs.VerifiedRules.Forms.remove(gs, pos.x, pos.y, "回到拥有者手牌", true)
			inst.yanmieFreeTurn = gs.turn_counter
			if gs.player(pos.x).hand.size() < int(gs.rules.maxHandSize):
				gs.player(pos.x).hand.append(inst)
		"yanmie-wish":
			if pos.y < 0 or int(target.hp) <= 0: return true
			var depth: int = gs.resolution_stack.size()
			gs.resolution_stack.insert(depth, {"kind":"yanmie-wish-hit", "playerIndex":owner, "sourceIndex":src, "target":target.uid, "context":gs._card_effect_context.duplicate(true)})
			if Factions.get_faction(target) == "紫岩":
				gs.VerifiedRules.Forms.remove(gs, pos.x, pos.y, "心愿达成")
		"yanmie-guard":
			if pos.y < 0 or int(target.hp) <= 0: return true
			gs._grant_unit_armor(target, 1)
			attack(gs, owner, pos.y, false, {"yanmieGuardRewards": true})
		"yanmie-song":
			choose(gs, owner, "song", ["armor", "divine"], src, card, "童羽歌")
		"yanmie-coat":
			gs._grant_unit_armor(target, 3)
			add_card(gs, owner, FEATHER)
		"yanmie-hide":
			var ids: Array = ["weaken"]
			if not living_ids(gs, owner, "红莲").is_empty(): ids.push_front("attack")
			choose(gs, owner, "hide", ids, src, card, "隐身术")
		"yanmie-moon":
			gs._grant_unit_armor(target, 3)
			gs._awaken(owner, src, card, effect.value)
		"yanmie-blade":
			var highest := 0
			for ally in gs.player(owner).units:
				if int(ally.hp) > 0: highest = maxi(highest, int(ally.shield))
			if pos.y >= 0: gs._damage_unit(pos.x, pos.y, highest + int(unit.get("spellPower", 0)), owner, src)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("yanmie-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex", -1))
	match kind:
		"yanmie-white-hit": white_random_hit(gs, owner, src, int(frame.amount))
		"yanmie-last-form":
			var card: Dictionary = frame.card.duplicate(true)
			var u: Dictionary = gs.player(owner).units[src]
			if int(u.hp) > 0:
				# The same departure can only supply one automatic play.
				u.erase("yanmieLastForm")
				var inst: Dictionary = card.get("playedInstance", {})
				if not inst.is_empty():
					var iid := str(inst.instanceId)
					for zone in [gs.player(owner).hand, gs.player(owner).deck]:
						for i in range(zone.size() - 1, -1, -1):
							if str(zone[i].instanceId) == iid: zone.remove_at(i)
					for copy in gs.VerifiedRules.Insight.zone(gs, owner).duplicate():
						if str(copy.instanceId) == iid: gs.VerifiedRules.Insight.remove(gs, owner, copy)
				for key in ["usedFromHand", "paidFire", "sourceZone", "insightFromZone", "insightSerial"]:
					card.erase(key)
				var target = card.get("yanmieEntryTarget")
				if card.get("target") != "auto":
					var candidates: Array = gs.valid_targets(owner, card)
					if not candidates.is_empty() and target not in candidates:
						target = candidates[int(gs.randf01() * candidates.size())]
				gs._push_card_frames(owner, str(card.id), target, card, src, 0, true)
		"yanmie-father-revive":
			var idx: int = gs._unit_index_by_uid(owner, frame.target)
			var fields := realm_list(gs, owner, "yanmie-father")
			if idx >= 0 and not fields.is_empty() and int(gs.player(owner).units[idx].hp) <= 0:
				gs.VerifiedRules.Huang.destroy(gs, owner, fields[0], "别父日")
				revive(gs, owner, idx)
		"yanmie-cycle":
			var pos := position(gs, frame.target)
			if frame.destroyed:
				revive(gs, pos.x, pos.y)
				if pos.x == owner: gs._draw(owner, 2)
		"yanmie-borrow":
			for side in [owner, 1-owner]:
				var candidates: Array = gs.player(side).units.filter(func(u): return u.uid != frame.target and can_revive(gs, side, u))
				if not candidates.is_empty():
					var target: Dictionary = candidates[int(gs.randf01() * candidates.size())]
					revive(gs, side, gs._unit_index_by_uid(side, target.uid))
		"yanmie-form-entry": form_reactions(gs, owner, src, str(frame.faction), bool(frame.pupu))
		"yanmie-shrine-shot": gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2)
		"yanmie-wish-hit":
			var pos := position(gs, frame.target)
			if pos.y >= 0:
				gs.VerifiedRules.Combat.strip_protection(gs, pos.x, pos.y, true)
				var unit: Dictionary = gs.player(owner).units[src]
				var previous: Dictionary = gs._card_effect_context
				gs._card_effect_context = frame.get("context", {})
				gs._damage_unit(pos.x, pos.y, 5 + int(unit.get("spellPower", 0)), owner, src)
				gs._card_effect_context = previous
		"yanmie-return-faction":
			var idx: int = gs._unit_index_by_uid(owner, frame.target)
			if idx < 0: return true
			var unit: Dictionary = gs.player(owner).units[idx]
			if int(unit.hp) <= 0: return true
			match str(frame.faction):
				"红莲":
					gs.VerifiedRules.HairPower.give(gs, owner, idx, 1)
					gs._grant_unit_armor(unit, 1)
					attack(gs, owner, idx)
				"苍叶": gs.VerifiedRules.Fortune.transform(gs, owner, idx, false, "yanmie-small-ghost", "白色小鬼")
		_: return false
	return true

static func score(gs, owner: int, card: Dictionary, target_id):
	var id := str(card.get("id", ""))
	var target: Dictionary = gs._unit_by_uid(gs._all_units(), target_id)
	var pos := position(gs, target_id)
	match id:
		"c62701": return 56 + int(target.get("attack", 0)) if pos.x == owner else -45
		"c62702": return 46
		"c62703": return 58
		"c62704": return 60 + int(target.get("maxHp", 0)) if pos.x == owner else -85
		"c62705": return 51 + maxi(0, int(target.get("maxHp", 0))-int(target.get("hp", 0))) if pos.x == owner else -75
		"c62706": return 77 if target_id != null else 49
		"c62707": return 65
		"c62708": return 69 + int(target.get("attack", 0))
		"c63001": return 50 + int(target.get("attack", 0)) if pos.x != owner else (49 if Factions.get_faction(target) in ["苍叶", "青岚"] else 23)
		"c63002", "c63003", "c63004", "c63006", "c63007", "c63008", WISDOM: return 54
		"c63005": return 64 + (24 if int(target.get("hp", 0)) <= 5 else 0)
		"c63201": return 48 + int(target.get("attack", 0)) * 3 + mini(6, int(target.get("shield", 0))) * 3
		"c63202": return 54
		"c63203", "c63205", "c63208": return 57 + int(target.get("attack", 0)) + (8 if int(target.get("front", 0)) == 1 else 0)
		"c63204", "c63206", "c63207": return 58
		FEATHER: return 57 if gs.player(owner).units.any(func(u):return int(u.shield) >= int(target.get("hp", 0))) else 39
	return null
