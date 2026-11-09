extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choices := preload("res://scripts/restored_card_choices.gd")
const WIND := "chulingshanfeng"
const BIRD := "daixiaoguhuoniao"
const BLOOD := "xixueji-xiyi"
const KARUTA := "geluoduo"
const SAKURA := "yinghuayao-lijing"
const PHOENIX := "fenghuanghuo-jingyu"
const MOON := "yinfanhuiyeji"
const HANA := ["hf-hana-moon", "hf-hana-crane", "hf-hana-cherry", "hf-hana-wind", "hf-hana-phoenix", "hf-hana-cup"]
const SPARK := "hf-spark"
const RABBIT_OPTIONS := ["hf-rabbit-damage", "hf-rabbit-heal"]
const PRAY := ["c66602", "c66603", "c66604", "c66605", "c66607"]

static func source(gs, owner: int, id: String) -> int:
	return gs.player(owner).units.find_custom(func(unit): return unit.id == id and not unit.get("removed", false))

static func active(u: Dictionary) -> bool:
	return not u.is_empty() and int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func realm_cards(gs, owner: int, kind: String) -> Array:
	return gs.player(owner).realms.filter(func(realm): return realm.get("nativeRealm") == kind and int(realm.hp) > 0)

static func ally_indices(gs, owner: int) -> Array:
	return range(gs.player(owner).units.size()).filter(func(i): return active(gs.player(owner).units[i]) and gs.VerifiedRules.OwlInsect.shikigami(gs.player(owner).units[i]))

static func living_indices(gs, owner: int) -> Array:
	return range(gs.player(owner).units.size()).filter(func(i):
		var u: Dictionary = gs.player(owner).units[i]
		return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))

static func target_location(gs, uid) -> Dictionary:
	if uid == null: return {}
	for owner in 2:
		var idx: int = gs._unit_index_by_uid(owner, str(uid))
		if idx >= 0: return {"owner": owner, "index": idx, "unit": gs.player(owner).units[idx]}
	return {}

static func set_temporary_trait(u: Dictionary, keyword: String) -> void:
	var traits: Array = u.get("hfTempTraits", [])
	if not traits.has(keyword): traits.append(keyword)
	u.hfTempTraits = traits

static func add_temporary_power(gs, u: Dictionary, amount: int) -> void:
	u.hfTempPower = int(u.get("hfTempPower", 0)) + amount
	gs._recalc(u)

static func spend_count(gs, u: Dictionary) -> int:
	return int(u.get("hfChargeCount", 0)) if int(u.get("hfChargeTurn", -1)) == gs.turn_counter else 0

static func enter_count(gs, u: Dictionary) -> int:
	return int(u.get("hfEntryCount", 0)) if int(u.get("hfEntryTurn", -1)) == gs.turn_counter else 0

static func once(gs, object: Dictionary, key: String) -> bool:
	if int(object.get(key, -1)) == gs.turn_counter: return false
	object[key] = gs.turn_counter
	return true

static func queue(gs, owner: int, kind: String, extra: Dictionary = {}) -> void:
	gs.resolution_stack.append({"kind": "hf-" + kind, "playerIndex": owner}.merged(extra))

static func attack(gs, owner: int, idx: int, options: Dictionary = {}) -> void:
	if idx < 0 or gs.player(owner).units[idx].get("removed", false): return
	Choices.attack(gs, owner, idx, null, options)

static func give(gs, owner: int, id: String, flags: Dictionary = {}) -> void:
	if Content.card_def(id).is_empty(): return
	var inst: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, id)
	inst.merge(flags, true)
	gs.VerifiedRules.Baize.put_hand(gs, owner, inst)

static func random_item(gs, pool: Array):
	return null if pool.is_empty() else pool[int(gs.next_random() % pool.size())]

static func dedicated(unit_id: String, filter: Callable) -> Array:
	return Content.cards_for_unit(unit_id).filter(filter).map(func(card): return str(card.id))

static func combat(gs, owner: int, src: int, card: Dictionary, target_id, bonus: int, options: Dictionary = {}) -> void:
	var view := card.duplicate(true)
	view.combatOption.merge(options, true)
	gs._resolve_action(owner, src, view, {"action": "assault", "value": bonus}, target_id, {})

static func shared(u: Dictionary) -> bool:
	return bool(u.get("formRules", {}).get("hfBloodShared", false))

static func unyielding(u: Dictionary) -> bool:
	return bool(u.get("formRules", {}).get("hfBloodUnyielding", false)) or (shared(u) and bool(u.get("unyielding", false)))

static func consume_unyielding(u: Dictionary) -> void:
	if shared(u): u.formRules.erase("hfBloodUnyielding")

static func sync_shared(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var idx := source(gs, owner, BLOOD)
	if idx < 0 or not shared(p.units[idx]): return
	var u: Dictionary = p.units[idx]
	u.maxHp = int(p.maxAvatarHp)
	u.hp = int(p.avatarHp)

static func reduce_shared(gs, owner: int, unit: Dictionary, amount: int) -> void:
	if not shared(unit) or amount <= 0: return
	gs.player(owner).avatarHp = int(unit.hp)
	gs._check_winner()

static func heal_shared(gs, unit: Dictionary, amount: int) -> bool:
	if not shared(unit): return false
	var loc := target_location(gs, unit.uid)
	if not loc.is_empty(): gs._heal_avatar(loc.owner, amount)
	return true

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var id := str(card.get("id", ""))
	var role := str(card.get("hanafudaRules", ""))
	if role.is_empty(): return card
	var src := source(gs, owner, str(card.unitId))
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	var view := card.duplicate(true)
	if role == "phoenix" and Content.is_spell(view) and u.awakened: view.allowKnockedSource = true
	if id == SPARK:
		view.hfSparkLayers = int(inst.get("hfSparkLayers", 1))
		view.currentCardStats = "火种 %d / 2 层" % view.hfSparkLayers
	if view.has("hfPray"):
		var remaining := int(inst.get("hfPray", view.hfPray))
		view.hfPrayed = remaining <= 0
		view.currentCardStats = "已祈愿" if view.hfPrayed else "祈愿剩余 %d" % remaining
		if view.hfPrayed and u.awakened and not view.keywords.has("instant"): view.keywords.append("instant")
	if id == "c66602":
		view.hfBounce = not inst.get("hfBounced", false)
		if not view.hfBounce: view.keywords.erase("bounce")
	if inst.get("hfInstant", false) and not view.keywords.has("instant"): view.keywords.append("instant")
	if id in ["c66703", "c66705", "c66708"]:
		var spent := spend_count(gs, u)
		if id == "c66703": view.currentCardStats = "+%d 力量 · 追猎" % (2 + int(spent > 0))
		if id == "c66705" and spent > 0: view.keywords.append("instant")
		if id == "c66708": view.currentCardStats = "+2 力量 / +2 护甲 · 投射 %d" % (2 + spent * 2)
	if role == "karuta" and id == "c66107":
		view.currentCardStats = "已用五光：%s" % ", ".join(u.get("hfLights", []).map(func(light): return Content.card_def(light).name))
	if id == "c66208": view.currentCardStats = "+%d 力量 / +4 护甲 · 贯通" % enter_count(gs, u)
	if role == "blood":
		view.currentCardStats = "入夜 %d / 10" % gs.VerifiedRules.Maple.night_value(gs, owner)
		if shared(u) and Content.is_spell(view) and not view.keywords.has("lifesteal"): view.keywords.append("lifesteal")
		if id == "c66307": view.currentCardStats += " · 共享生命 %d" % gs.player(owner).avatarHp
	return view

static func enters(gs, owner: int, idx: int, from_realm: bool = false, from_awakened: bool = false) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if not active(u): return
	var base_wind: bool = u.id == WIND
	var granted := int(u.get("hfEntryPower", 0))
	var form: Dictionary = u.get("formRules", {})
	if not base_wind and granted == 0 and not form.get("hfBloodEntry", false) and not form.get("hfBloodShared", false): return
	if base_wind:
		u.hfEntryCount = enter_count(gs, u) + 1
		u.hfEntryTurn = gs.turn_counter
		if u.awakened: add_temporary_power(gs, u, 1)
		else: gs.VerifiedRules.HairPower.give(gs, owner, idx, 1)
	if granted > 0: gs.VerifiedRules.HairPower.give(gs, owner, idx, granted)
	if form.get("hfBloodEntry", false): gs.VerifiedRules.base_damage_projectile(gs, owner, idx, 3, "血夜咏叹")
	if form.get("hfBloodShared", false):
		var pool := dedicated(BLOOD, func(card): return not card.get("awakeningCard", false) and (Content.is_spell(card) or card.type == "combat"))
		if not pool.is_empty(): give(gs, owner, str(random_item(gs, pool)), {"hfInstant": true})
	gs.VerifiedRules.event(gs, "hanafuda-entry", {"player": owner, "uid": u.uid})
	var bird := source(gs, owner, BIRD)
	if bird >= 0 and bird != idx:
		var bird_unit: Dictionary = gs.player(owner).units[bird]
		if active(bird_unit) and bird_unit.get("formRules", {}).get("hfBirdEntry", false) and once(gs, bird_unit, "hfBirdEntryTurn"):
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, bird, 2)
			gs.VerifiedRules.HairPower.give(gs, owner, bird, 1)
	if gs.current_player == owner and not from_realm:
		for hunt in realm_cards(gs, owner, "hf-hunt"):
			var uses: Dictionary = hunt.get("hfHuntUses", {})
			if once(gs, uses, str(u.uid)):
				hunt.hfHuntUses = uses
				enters(gs, owner, idx, true, from_awakened)
	if not base_wind and not from_awakened:
		var wind := source(gs, owner, WIND)
		if wind >= 0 and gs.player(owner).units[wind].awakened:
			enters(gs, owner, wind, false, true)

static func event(gs, kind: String, details: Dictionary) -> void:
	var owner := int(details.get("player", -1))
	if owner < 0: return
	match kind:
		"unit-moved":
			var idx: int = gs._unit_index_by_uid(owner, str(details.uid))
			if idx < 0: return
			var u: Dictionary = gs.player(owner).units[idx]
			if int(details.front) == 1: enters(gs, owner, idx)
			elif active(u) and u.get("formRules", {}).get("hfWindSwift", false):
				add_temporary_power(gs, u, 1)
				if not u.get("swift", false):
					u.swift = true
					u.hfScopedSwift = true
		"charge-paid":
			var idx := source(gs, owner, BIRD)
			if idx < 0: return
			var u: Dictionary = gs.player(owner).units[idx]
			if u.uid != details.uid or int(details.quote.get("charge", 0)) + int(details.quote.get("borrowed", 0)) <= 0: return
			u.hfChargeCount = spend_count(gs, u) + 1
			u.hfChargeTurn = gs.turn_counter
		"combat-damage-resolved":
			if int(details.amount) <= 0: return
			var card: Dictionary = details.get("card", {})
			var loc := target_location(gs, details.get("target"))
			var uid := str(details.get("uid", ""))
			var idx: int = gs._unit_index_by_uid(owner, uid)
			if idx < 0: return
			if card.get("id") == "c66103" and str(details.get("target", "")).is_empty():
				hana_countdown(gs, owner, idx, 2)
			if card.get("id") == "c66206" and not loc.is_empty() and loc.owner != owner and gs.VerifiedRules.OwlInsect.shikigami(loc.unit):
				queue(gs, owner, "wind-move", {"uid": loc.unit.uid})

static func attack_started(gs, owner: int, idx: int) -> void:
	var bird := source(gs, owner, BIRD)
	if bird < 0 or bird == idx: return
	var u: Dictionary = gs.player(owner).units[idx]
	if not gs.VerifiedRules.OwlInsect.shikigami(u): return
	var bird_unit: Dictionary = gs.player(owner).units[bird]
	if active(bird_unit) and int(bird_unit.get("hfBirdBonusTurn", -1)) == gs.turn_counter and once(gs, u, "hfBirdAttackCharge"):
		gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, bird, 3)

static func finish_combat(gs, owner: int, idx: int, options: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[idx]
	finish_sakura(gs, owner, idx, options)
	var bird := source(gs, owner, BIRD)
	if u.id == WIND and active(u) and u.get("formRules", {}).get("hfWindPartner", false) and once(gs, u, "hfPartnerTurn"):
		var loc := target_location(gs, u.get("hfWindPartnerUid"))
		if not loc.is_empty() and int(loc.unit.hp) > 0 and not loc.unit.get("removed", false):
			gs.VerifiedRules.HairPower.give(gs, owner, int(loc.index), 2)
			queue(gs, owner, "attack", {"uid": loc.unit.uid})
	if bird < 0 or bird == idx or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	for realm in realm_cards(gs, owner, "hf-bird"):
		if not once(gs, realm, "hfBirdRealmTurn"): continue
		p.attackUsed = false
		gs._apply_encourage(owner, 0, 0, 1)
		gs.VerifiedRules.Night.lose(gs, owner, realm, 2)
	var bird_unit: Dictionary = p.units[bird]
	if active(bird_unit) and gs.VerifiedRules.SunSmoke.pay_charge(gs, owner, bird, 3):
		queue(gs, owner, "bird-follow", {"uid": bird_unit.uid, "remote": bool(bird_unit.awakened)})

static func turn_start(gs, owner: int) -> void:
	var karuta := source(gs, owner, KARUTA)
	if karuta >= 0 and active(gs.player(owner).units[karuta]) and gs.player(owner).units[karuta].get("formRules", {}).get("hfPigDeer", false):
		hana_countdown(gs, owner, karuta, 1)
	phoenix_turn_start(gs, owner)
	var idx := source(gs, owner, BLOOD)
	if idx < 0: return
	for _realm in realm_cards(gs, owner, "hf-blood"): hurt_both(gs, owner, idx, 1)
	var u: Dictionary = gs.player(owner).units[idx]
	if not active(u) or gs.winner >= 0: return
	if gs.VerifiedRules.Maple.nightfall(gs, owner, 3):
		gs._damage_avatar(owner, 1, owner, idx)
		gs.VerifiedRules.HairPower.give(gs, owner, idx, 2)
	if u.awakened and gs.winner < 0 and gs.VerifiedRules.Maple.nightfall(gs, owner, 7): set_temporary_trait(u, "lifesteal")

static func end_turn(gs, owner: int) -> void:
	for side in 2: phoenix_expire(gs, side)
	var blossom_owner := 1 - owner
	var blossom_src := blossom_index(gs, blossom_owner)
	if blossom_src >= 0:
		var token: Dictionary = gs.player(blossom_owner).units[blossom_src]
		gs.VerifiedRules.base_damage_projectile(gs, blossom_owner, blossom_src, int(token.attack), "琉璃樱")
		if int(token.hp) > 0: gs._knockout_unit(token, blossom_owner, blossom_src)
	for unit in gs.player(1 - owner).units:
		if not unit.has("hfTemporaryRevive"): continue
		var counter := int(unit.hfTemporaryRevive)
		unit.erase("hfTemporaryRevive")
		if int(unit.hp) > 0:
			gs._knockout_unit(unit)
			unit.knockout = counter
	gs.player(owner).erase("hfChain")
	var karuta := source(gs, owner, KARUTA)
	if karuta >= 0:
		var unit: Dictionary = gs.player(owner).units[karuta]
		if unit.erase("hfHanaSwift"): unit.swift = false
	for p in gs.players:
		for u in p.units:
			if u.erase("hfTempPower"): gs._recalc(u)
			u.erase("hfTempTraits")
			if u.erase("hfScopedSwift"): u.swift = false

static func hurt_both(gs, owner: int, src: int, amount: int) -> int:
	var total: int = gs._damage_avatar(owner, amount, owner, src)
	if gs.winner < 0: total += gs._damage_avatar(1 - owner, amount, owner, src)
	return total

static func revive(gs, owner: int, src: int) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	return gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("hf-"): return false
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var loc := target_location(gs, target_id)
	var foe := 1 - owner
	match action:
		"hf-countdown":
			give(gs, owner, str(random_item(gs, HANA)))
			gs.VerifiedRules.event(gs, "hanafuda-countdown", {"player": owner, "uid": u.uid})
		"hf-66101":
			for i in 2: give(gs, owner, str(random_item(gs, HANA)))
		"hf-66102":
			gs._install_form(owner, src, card, effect.value)
			hana_countdown(gs, owner, src, 1)
		"hf-66103":
			hana_countdown(gs, owner, src, 1)
			combat(gs, owner, src, card, target_id, 1)
		"hf-66104":
			if not loc.is_empty():
				var counter := int(loc.unit.knockout)
				if revive(gs, owner, loc.index): loc.unit.hfTemporaryRevive = counter
		"hf-66105":
			gs._awaken(owner, src, card, effect.value)
			choose(gs, owner, "hana", HANA, "选择一张花札牌")
		"hf-66106":
			if not loc.is_empty():
				var hits := hana_played(gs, p)
				if hits > 0:
					queue(gs, owner, "rain-hit", {"uid": target_id, "sourceIndex": src, "remaining": hits, "spellContext": gs._card_effect_context})
				gs._damage_unit(loc.owner, loc.index, 4, owner, src)
		"hf-66107":
			queue(gs, owner, "late-combat", {"uid": u.uid, "card": card, "bonus": 2})
			var lights: Array = u.get("hfLights", [])
			for i in range(lights.size() - 1, -1, -1):
				queue(gs, owner, "five-light", {"uid": u.uid, "light": lights[i], "target": target_id})
		"hf-66108": gs._install_form(owner, src, card, effect.value)
		"hf-hana-moon", "hf-hana-crane", "hf-hana-cherry", "hf-hana-wind", "hf-hana-phoenix", "hf-hana-cup":
			hana_spell(gs, owner, src, action, target_id)
		"hf-66201":
			var depth: int = gs.resolution_stack.size()
			var moved: bool = gs.VerifiedRules.Movement.move_to(gs, owner, src, 1 - int(u.front))
			if moved and int(u.front) == 0:
				gs.VerifiedRules.HairPower.give(gs, owner, src, 2)
				set_temporary_trait(u, "pierce")
			gs.resolution_stack.insert(depth, {"kind": "hf-late-combat", "playerIndex": owner, "uid": u.uid, "card": card, "target": target_id, "bonus": 0})
		"hf-66202": gs._install_form(owner, src, card, effect.value)
		"hf-66203":
			p.attackUsed = false
			gs.VerifiedRules.Movement.move_to(gs, owner, src, 1 - int(u.front))
			set_temporary_trait(u, "first-strike")
		"hf-66204":
			gs._deploy_realm(owner, card)
			if not loc.is_empty(): enters(gs, owner, int(loc.index))
		"hf-66205":
			if not target.is_empty(): target.hfEntryPower = int(target.get("hfEntryPower", 0)) + 1
			gs._awaken(owner, src, card, effect.value)
		"hf-66206": combat(gs, owner, src, card, target_id, 0)
		"hf-66207":
			gs._install_form(owner, src, card, effect.value)
			u.hfWindPartnerUid = target_id
			u.swift = true
		"hf-66208":
			var cfg := card.duplicate(true)
			cfg.combatOption.hfWindFire = true
			combat(gs, owner, src, cfg, target_id, 0)
		"hf-66701":
			if not loc.is_empty(): gs.VerifiedRules.HairPower.give(gs, owner, int(loc.index), 1)
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 3)
		"hf-66702":
			gs._deploy_realm(owner, card)
			if not target.is_empty(): target.swift = true
		"hf-66703": combat(gs, owner, src, card, target_id, 2 + int(spend_count(gs, u) > 0))
		"hf-66704":
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 3)
			gs._awaken(owner, src, card, effect.value)
		"hf-66705": combat(gs, owner, src, card, target_id, 2)
		"hf-66706": gs._install_form(owner, src, card, effect.value)
		"hf-66707":
			gs._grow_unit(u, 1, 0)
			attack(gs, owner, src, {"remote": true})
			u.hfBirdBonusTurn = gs.turn_counter
		"hf-66708":
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2 + spend_count(gs, u) * 2, card.name)
			combat(gs, owner, src, card, target_id, 2)
		"hf-66301":
			gs._damage_avatar(owner, 2, owner, src)
			if gs.winner < 0 and not loc.is_empty(): gs._damage_unit(loc.owner, loc.index, 4, owner, src)
			if gs.winner < 0 and gs.VerifiedRules.Maple.nightfall(gs, owner, 3): gs._grow_unit(u, 1, 1)
		"hf-66302":
			revive(gs, owner, src)
			gs._damage_avatar(owner, 3, owner, src)
			if gs.winner < 0 and gs.VerifiedRules.Maple.nightfall(gs, owner, 3):
				gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
				gs._grant_unit_armor(u, 1)
				attack(gs, owner, src, {"lifeSteal": true})
		"hf-66303":
			gs._deploy_realm(owner, card)
			hurt_both(gs, owner, src, 1)
			if gs.winner < 0 and gs.VerifiedRules.Maple.nightfall(gs, owner, 5): set_temporary_trait(u, "lifesteal")
		"hf-66304":
			var cfg := card.duplicate(true)
			if gs.VerifiedRules.Maple.nightfall(gs, owner, 5): cfg.formRules.combatKeywords = ["lifesteal"]
			gs._install_form(owner, src, cfg, effect.value)
		"hf-66305": gs._awaken(owner, src, card, effect.value)
		"hf-66306":
			gs._heal_unit(u, hurt_both(gs, owner, src, 2))
			var night: bool = gs.winner < 0 and gs.VerifiedRules.Maple.nightfall(gs, owner, 5)
			combat(gs, owner, src, card, target_id, 2 + int(night), {"immuneCombat": night})
		"hf-66307":
			var cfg := card.duplicate(true)
			cfg.formRules.hfBloodUnyielding = true
			gs._install_form(owner, src, cfg, effect.value)
			sync_shared(gs, owner)
		"hf-66308":
			hurt_both(gs, owner, src, 2)
			if gs.winner < 0 and gs.VerifiedRules.Maple.nightfall(gs, owner, 10):
				gs._grow_unit(u, 3, 0)
				u.hfBloodPierce = true
			combat(gs, owner, src, card, target_id, 3)
		_:
			return death_card(gs, owner, src, card, effect, target, target_id)
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("hf-"): return false
	var owner := int(frame.playerIndex)
	var loc := target_location(gs, frame.get("uid"))
	match kind:
		"hf-rain-hit":
			if not loc.is_empty() and int(loc.unit.hp) > 0 and not loc.unit.get("removed", false):
				if int(frame.remaining) > 1:
					frame.remaining = int(frame.remaining) - 1
					gs.resolution_stack.append(frame)
				var context: Dictionary = gs._card_effect_context
				gs._card_effect_context = frame.get("spellContext", {})
				gs._damage_unit(loc.owner, loc.index, 2, owner, int(frame.sourceIndex))
				gs._card_effect_context = context
		"hf-five-light":
			if not loc.is_empty(): hana_spell(gs, owner, loc.index, str(frame.light), frame.get("target"))
		"hf-late-combat":
			if not loc.is_empty() and active(loc.unit): combat(gs, owner, loc.index, frame.card, frame.get("target"), int(frame.bonus))
		"hf-wind-move":
			if not loc.is_empty() and int(loc.unit.hp) > 0 and not loc.unit.get("removed", false):
				gs.VerifiedRules.Movement.move_to(gs, loc.owner, loc.index, 1 - int(loc.unit.front))
		"hf-attack":
			if not loc.is_empty(): attack(gs, owner, loc.index, frame.get("options", {}))
		"hf-bird-follow":
			if not loc.is_empty() and active(loc.unit):
				if frame.remote: attack(gs, owner, loc.index, {"remote": true})
				else: gs.VerifiedRules.base_damage_projectile(gs, owner, loc.index, 2, "待宵姑获鸟")
		"hf-blossom": blossom(gs, owner, int(frame.sourceIndex), int(frame.size))
		"hf-phoenix-kindling":
			if not loc.is_empty():
				queue(gs, owner, "phoenix-kindling-pay", {"uid": loc.unit.uid})
				var victim := target_location(gs, frame.get("target"))
				if not victim.is_empty() and int(victim.unit.hp) > 0:
					var context: Dictionary = gs._card_effect_context
					gs._card_effect_context = frame.get("spellContext", {})
					gs._damage_unit(victim.owner, victim.index, 6, owner, loc.index)
					gs._card_effect_context = context
		"hf-phoenix-kindling-pay":
			if not loc.is_empty() and discard_sparks(gs, owner, 3):
				queue(gs, owner, "phoenix-attack", {"uid": loc.unit.uid})
		"hf-will":
			if not loc.is_empty(): do_will(gs, owner, loc.index, frame.will)
		"hf-phoenix-attack":
			if not loc.is_empty() and active(loc.unit):
				gs._grant_unit_armor(loc.unit, 2)
				attack(gs, owner, loc.index)
		"hf-phoenix-return":
			if not loc.is_empty() and discard_sparks(gs, owner, 4) and active(loc.unit):
				var card := Content.card_def("c66507")
				gs._install_form(owner, loc.index, card, card.value)
				loc.unit.swift = true
		"hf-sakura-combat":
			if not loc.is_empty() and active(loc.unit):
				var blossom := blossom_index(gs, owner)
				if blossom >= 0:
					var u: Dictionary = gs.player(owner).units[blossom]
					gs.VerifiedRules.HairPower.give(gs, owner, loc.index, maxi(0, int(u.attack)))
					gs._knockout_unit(u, owner, loc.index)
				combat(gs, owner, loc.index, frame.card, null, 0)
		_: return false
	return true

static func hana_countdown(gs, owner: int, src: int, amount: int) -> void:
	gs.VerifiedRules.reduce_countdown(gs, owner, src, amount, owner)

static func hana_spell(gs, owner: int, src: int, id: String, target_id) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	match id:
		"hf-hana-moon":
			gs._heal_avatar(owner, 2)
			gs._heal_unit(u, 2)
		"hf-hana-crane":
			hana_countdown(gs, owner, src, 1)
			gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
		"hf-hana-cherry": gs._draw(owner, 1)
		"hf-hana-wind":
			gs._apply_encourage(owner, 0, 1, 1)
			if not u.get("swift", false):
				u.swift = true
				u.hfHanaSwift = true
		"hf-hana-phoenix":
			var loc := target_location(gs, target_id)
			if not loc.is_empty(): gs._damage_unit(loc.owner, loc.index, 2, owner, src)
		"hf-hana-cup": gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2, "菊上杯")

static func hana_played(gs, p: Dictionary) -> int:
	return int(p.get("hfHanaPlayed", 0)) if int(p.get("hfHanaPlayedTurn", -1)) == gs.turn_counter else 0

static func chain_filter(card: Dictionary, wide: bool) -> Array:
	if wide: return ["any"]
	match str(card.id):
		"c66101", "c66106", "c66107": return HANA.duplicate()
		"c66103": return [HANA[0], HANA[5]]
		"c66104": return [HANA[2], HANA[5]]
		_:
			if card.id in HANA: return HANA.filter(func(id): return id != card.id)
	return []

static func chain_payment(gs, owner: int, card: Dictionary, payment: Dictionary) -> Dictionary:
	if gs.current_player != owner: return payment
	var idx := source(gs, owner, KARUTA)
	if idx < 0: return payment
	var p: Dictionary = gs.player(owner)
	var chain: Dictionary = p.get("hfChain", {})
	var u: Dictionary = p.units[idx]
	var wide: bool = active(u) and u.get("formRules", {}).get("hfDance", false)
	var spent := int(p.get("hfChainSpent", 0)) if int(p.get("hfChainTurn", -1)) == gs.turn_counter else 0
	if int(chain.get("turn", -1)) != gs.turn_counter or spent >= 1 + int(u.awakened) + (2 if wide else 0): return payment
	var pool: Array = chain.get("pool", [])
	if "any" not in pool and card.id not in pool: return payment
	payment.hfChain = true
	payment.usesInstant = false
	payment.usesSwift = false
	payment.usesGuard = false
	payment.cost = 0
	return payment

static func pay_chain(gs, owner: int, card: Dictionary, payment: Dictionary) -> void:
	if not payment.get("hfChain", false): return
	var p: Dictionary = gs.player(owner)
	if int(p.get("hfChainTurn", -1)) != gs.turn_counter: p.hfChainSpent = 0
	p.hfChainTurn = gs.turn_counter
	p.hfChainSpent = int(p.hfChainSpent) + 1
	p.erase("hfChain")
	card.hfChained = true

static func karuta_complete(gs, owner: int, card: Dictionary) -> void:
	var src := source(gs, owner, KARUTA)
	if src < 0 or str(card.unitId) != KARUTA: return
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var wide: bool = active(u) and u.get("formRules", {}).get("hfDance", false)
	var pool := chain_filter(card, wide)
	if not pool.is_empty() and gs.current_player == owner: p.hfChain = {"pool": pool, "turn": gs.turn_counter}
	if card.get("hfChained", false) and wide:
		var candidates: Array = []
		for side in 2:
			candidates.append({"owner": side, "idx": -1})
			var units: Array = gs.player(side).units
			for i in units.size():
				if int(units[i].hp) > 0 and not units[i].get("removed", false): candidates.append({"owner": side, "idx": i})
		var picked: Dictionary = random_item(gs, candidates)
		if int(picked.idx) < 0: gs._damage_avatar(picked.owner, 3, owner, src)
		else: gs._damage_unit(picked.owner, picked.idx, 3, owner, src)
	if card.id not in HANA: return
	p.hfHanaPlayed = hana_played(gs, p) + 1
	p.hfHanaPlayedTurn = gs.turn_counter
	if card.get("hfLight", false):
		var used: Array = u.get("hfLights", [])
		if not used.has(card.id): used.append(card.id)
		u.hfLights = used
	if not active(u) or not u.get("formRules", {}).get("hfPigDeer", false): return
	var used: Dictionary = u.get("hfAnimalUses", {})
	var animals: Array = ["pig", "deer", "butterfly"].filter(func(animal): return int(used.get(animal, -1)) != gs.turn_counter)
	if animals.is_empty(): return
	var animal: String = random_item(gs, animals)
	used[animal] = gs.turn_counter
	u.hfAnimalUses = used
	match animal:
		"pig": gs._damage_avatar(1 - owner, 2, owner, src)
		"deer":
			gs._grant_unit_armor(u, 1)
			attack(gs, owner, src)
		"butterfly":
			var idx: int = random_item(gs, ally_indices(gs, owner))
			gs.VerifiedRules.HairPower.give(gs, owner, idx, 1)
			gs._grant_unit_armor(p.units[idx], 1)

static func choose(gs, owner: int, key: String, ids: Array, label: String, extra: Dictionary = {}) -> void:
	if ids.is_empty(): return
	var hint := "选中的花札牌将置入手牌。" if key == "hana" else "选择召唤物在战斗区气绝时生效的遗愿。"
	gs.pending_choice = {"type": "hf-" + key, "playerIndex": owner, "instanceIds": ids, "heading": label, "hint": hint}.merged(extra)
	gs.phase = "choice"

static func choice_card(gs, owner: int, id: String):
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner or id not in choice.get("instanceIds", []) or not str(choice.get("type", "")).begins_with("hf-"): return null
	if choice.type == "hf-hana": return Content.card_def(id)
	if choice.type == "hf-rabbit":
		var result := Content.card_def("c66601").duplicate(true)
		result.id = id
		result.name = "因幡兔·%s" % ("月击" if id == RABBIT_OPTIONS[0] else "月愈")
		result.text = "召唤一个3/3因幡兔。因幡兔遗愿生效两次。\n遗愿：" + ("对随机敌方式神造成1点伤害。" if id == RABBIT_OPTIONS[0] else "为所有己方角色恢复1点生命。")
		return result
	return null

static func resolve_choice(gs, owner: int, id: String) -> bool:
	var c: Dictionary = gs.pending_choice
	if int(c.get("playerIndex", -1)) != owner or id not in c.get("instanceIds", []): return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId": id, "choice": c.type}, owner)
	if c.type == "hf-hana": give(gs, owner, id)
	if c.type == "hf-rabbit":
		var src := source(gs, owner, MOON)
		if src >= 0:
			var label := "遗愿：%s，生效两次。" % ("对随机敌方式神造成1点伤害" if id == RABBIT_OPTIONS[0] else "为所有己方角色恢复1点生命")
			var unit: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, owner, src, "hf-rabbit", "因幡兔", 3, 3, {"formAbility": label, "hfRabbit": true})
			attach_will(unit, {"kind": id})
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var c: Dictionary = gs.pending_choice
	if int(c.get("playerIndex", -1)) != owner or not str(c.get("type", "")).begins_with("hf-"): return null
	var ids: Array = c.get("instanceIds", [])
	if c.type == "hf-hana":
		if int(gs.player(owner).avatarHp) <= 12 and HANA[0] in ids: return HANA[0]
		if HANA[2] in ids: return HANA[2]
	if c.type == "hf-rabbit":
		var p: Dictionary = gs.player(owner)
		var wounds: Array = p.units.filter(func(u): return active(u) and int(u.hp) < int(u.maxHp))
		if wounds.size() >= 2 or int(p.avatarHp) <= 10: return RABBIT_OPTIONS[1]
	return ids.front() if not ids.is_empty() else null

static func targets(gs, owner: int, card: Dictionary):
	match str(card.get("id", "")):
		"c66104":
			return gs.player(owner).units.filter(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)).map(func(u): return u.uid)
		"c66107":
			var idx := source(gs, owner, KARUTA)
			if idx >= 0 and HANA[4] in gs.player(owner).units[idx].get("hfLights", []):
				return gs.valid_targets(owner, Content.card_def(HANA[4]))
		"c66106", "c66406", "c66503":
			return Choices.live_units(gs, 1 - owner).filter(func(u):
				return not gs.VerifiedRules.Combat.has(u, "veil") and not gs.VerifiedRules.Movement.has_veil(u)).map(func(u): return u.uid)
		"c66301", "c66506", "c66602", "c66702":
			var units := Choices.targetable_shikigami(gs, owner, owner)
			units.append_array(Choices.targetable_shikigami(gs, owner, 1 - owner))
			return units.map(func(u): return u.uid)
		"c66204", "c66205", "c66603", "c66606", "c66607", "c66701":
			return Choices.live_units(gs, owner).map(func(u): return u.uid)
		"c66207":
			return Choices.live_units(gs, owner).filter(func(u): return u.id != WIND).map(func(u): return u.uid)
		"c66403":
			return Choices.live_units(gs, owner).filter(func(u): return not u.get("summoned", false)).map(func(u): return u.uid)
		"c66604":
			if not card.get("hfPrayed", false): return null
			var out: Array = []
			for side in 2:
				for u in gs.player(side).units:
					if gs.VerifiedRules.YanmieTrio.can_revive(gs, side, u): out.append(u.uid)
			return out if not out.is_empty() else null
	return null

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.has("hanafudaRules"): return true
	var idx := source(gs, owner, str(card.unitId))
	if idx < 0: return false
	var u: Dictionary = gs.player(owner).units[idx]
	return not (card.get("requiresKnockedSource", false) and int(u.hp) > 0) and not (card.get("awakeningCard", false) and u.awakened)

static func aim_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("id") not in ["c66107", "c66604"]: return card
	var choices = targets(gs, owner, card)
	if choices != null and not choices.is_empty(): card.target = "any-unit"
	return card

static func attached_wills(unit: Dictionary) -> Array:
	var out: Array = unit.get("hfWills", []).duplicate(true)
	if unit.get("baseRulesSuppressed", false) or int(unit.level) <= 0: return out
	match str(unit.id):
		SAKURA: out.push_front({"kind": "blossom", "size": 2 if unit.awakened else 1})
		PHOENIX: out.push_front({"kind": "spark", "count": 2 if unit.awakened else 1})
	return out

static func attach_will(unit: Dictionary, will: Dictionary) -> void:
	var wills: Array = unit.get("hfWills", [])
	wills.append(will)
	unit.hfWills = wills

static func death_snapshot(unit: Dictionary) -> Dictionary:
	if int(unit.front) != 1 and not unit.get("formRules", {}).get("hfPhoenixForm", false): return {}
	return {"wills": attached_wills(unit) if int(unit.front) == 1 else [], "phoenix": unit.get("formRules", {}).get("hfPhoenixForm", false)}

static func died(gs, owner: int, unit: Dictionary, snapshot: Dictionary) -> void:
	if owner < 0: return
	unit.erase("hfWills")
	unit.erase("hfTemporaryRevive")
	if snapshot.is_empty(): return
	if snapshot.phoenix: queue(gs, owner, "phoenix-return", {"uid": unit.uid})
	queue_wills(gs, owner, unit, snapshot.wills)

static func queue_wills(gs, owner: int, unit: Dictionary, wills: Array) -> void:
	var moon := source(gs, owner, MOON)
	var times := 2 if unit.get("hfRabbit", false) else 1
	if moon >= 0:
		var u: Dictionary = gs.player(owner).units[moon]
		if active(u) and u.get("formRules", {}).get("hfMoonDoubles", false): times += 1
	for repeat in times:
		for i in range(wills.size() - 1, -1, -1): queue(gs, owner, "will", {"uid": unit.uid, "will": wills[i]})

static func do_will(gs, owner: int, idx: int, will: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	match str(will.kind):
		"blossom":
			var src := source(gs, owner, SAKURA)
			if src >= 0: blossom(gs, owner, src, int(will.size))
		"spark": gain_sparks(gs, owner, int(will.count))
		"revive": gs.VerifiedRules.reduce_countdown(gs, owner, idx, 1)
		"hf-rabbit-damage":
			var foes := living_indices(gs, 1 - owner)
			if not foes.is_empty(): gs._damage_unit(1 - owner, int(random_item(gs, foes)), 1, owner, idx)
		"hf-rabbit-heal":
			gs._heal_avatar(owner, 1)
			for ally in living_indices(gs, owner): gs._heal_unit(gs.player(owner).units[ally], 1)
		"blessing":
			gs.VerifiedRules.base_damage_projectile(gs, owner, idx, 4, "月之洗礼")
			area(gs, owner, idx, 1, true)
		_: return
	gs.VerifiedRules.event(gs, "hanafuda-will", {"player": owner, "uid": unit.uid, "will": will})
	for zone in [gs.player(owner).hand, gs.VerifiedRules.Insight.zone(gs, owner)]:
		for inst in zone:
			var threshold := int(Content.card_def(inst.definitionId).get("hfPray", 0))
			if threshold > 0: inst.hfPray = maxi(0, int(inst.get("hfPray", threshold)) - 1)
	wish_area(gs, owner, "hfLastWillTurn")

static func area(gs, owner: int, src: int, amount: int, avatars: bool = false) -> void:
	for idx in living_indices(gs, 1 - owner):
		if gs.winner >= 0: break
		gs._damage_unit(1 - owner, idx, amount, owner, src)
	if avatars and gs.winner < 0: gs._damage_avatar(1 - owner, amount, owner, src)

static func wish_area(gs, owner: int, key: String) -> void:
	var moon := source(gs, owner, MOON)
	if moon < 0: return
	for realm in realm_cards(gs, owner, "hf-wish"):
		if once(gs, realm, key): area(gs, owner, moon, 1)

static func moon_announce(gs, owner: int, card: Dictionary, target_id) -> void:
	if str(card.unitId) != MOON: return
	var moon := source(gs, owner, MOON)
	if moon < 0 or not active(gs.player(owner).units[moon]): return
	var loc := target_location(gs, target_id)
	if not loc.is_empty() and loc.owner == owner and gs.VerifiedRules.OwlInsect.shikigami(loc.unit):
		attach_will(loc.unit, {"kind": "revive"})

static func moon_complete(gs, owner: int, card: Dictionary) -> void:
	var moon := source(gs, owner, MOON)
	if moon < 0: return
	var u: Dictionary = gs.player(owner).units[moon]
	if card.get("hfBounce", false):
		var inst: Dictionary = card.get("playedInstance", {}).duplicate(true)
		if not inst.is_empty():
			inst.hfBounced = true
			gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
	if not card.get("hfPrayed", false): return
	wish_area(gs, owner, "hfPrayedTurn")
	if active(u) and u.get("formRules", {}).get("hfMoonlight", false) and once(gs, u, "hfMoonlightTurn"):
		gs._draw(owner, 1)
		gs._heal_avatar(owner, 3)
		gs._set_fire(owner, int(gs.player(owner).energy) + 1)
		gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1, 1)

static func blossom_index(gs, owner: int) -> int:
	return gs.player(owner).units.find_custom(func(u): return u.id == "hf-glass-cherry" and active(u) and int(u.front) == 1)

static func blossom(gs, owner: int, src: int, size: int) -> Dictionary:
	var p: Dictionary = gs.player(owner)
	var bonus := int(p.get("hfBlossomBonus", 0))
	var old := blossom_index(gs, owner)
	if old < 0:
		return gs.VerifiedRules.NativeSummons.summon(gs, owner, src, "hf-glass-cherry", "琉璃樱", size + bonus, size + bonus, {"inspired": true, "formAbility": "融合，昂扬。敌方回合结束时，投射：造成等同于自身力量的伤害，然后自毁。"})
	var u: Dictionary = p.units[old]
	gs._grow_unit(u, size, size)
	u.inspired = true
	gs.VerifiedRules.event(gs, "hanafuda-blossom-fused", {"player": owner, "uid": u.uid})
	for realm in realm_cards(gs, owner, "hf-cherry"):
		if once(gs, realm, "hfCherryFusionTurn"): queue(gs, owner, "attack", {"uid": u.uid, "options": {"immuneCombat": true}})
	return u

static func finish_sakura(gs, owner: int, idx: int, options: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if str(u.id) != SAKURA: return
	var id: String = options.get("combatCard", {}).get("id", "")
	if id == "c66401": blossom(gs, owner, idx, 1)
	if id == "c66405":
		var depth: int = gs.resolution_stack.size()
		if int(u.hp) > 0: gs._knockout_unit(u, owner, idx)
		gs.resolution_stack.insert(depth, {"kind": "hf-blossom", "playerIndex": owner, "sourceIndex": idx, "size": 3})
	if active(u) and u.get("formRules", {}).get("hfCherryDance", false):
		queue_wills(gs, owner, u, attached_wills(u))

static func gain_sparks(gs, owner: int, count: int, flags: Dictionary = {}) -> void:
	var hand: Array = gs.player(owner).hand
	for i in count:
		var idx := hand.find_custom(func(inst): return inst.definitionId == SPARK and int(inst.get("hfSparkLayers", 1)) < 2 and int(inst.get("hfExpires", -1)) == int(flags.get("hfExpires", -1)))
		if idx < 0: give(gs, owner, SPARK, {"hfSparkLayers": 1}.merged(flags, true))
		else: hand[idx].hfSparkLayers = int(hand[idx].get("hfSparkLayers", 1)) + 1

static func spark_count(gs, owner: int) -> int:
	var total := 0
	for inst in gs.player(owner).hand:
		if inst.definitionId == SPARK: total += int(inst.get("hfSparkLayers", 1))
	return total

static func discard_sparks(gs, owner: int, count: int) -> bool:
	if spark_count(gs, owner) < count: return false
	var hand: Array = gs.player(owner).hand
	var remaining := count
	while remaining > 0:
		var idx := hand.find_custom(func(inst): return inst.definitionId == SPARK)
		var inst: Dictionary = hand[idx]
		var layers := int(inst.get("hfSparkLayers", 1))
		if layers <= remaining:
			gs.discard_hand_card(owner, idx)
			remaining -= layers
		else:
			inst.hfSparkLayers = layers - remaining
			phoenix_spark(gs, owner, remaining)
			phoenix_spell(gs, owner, Content.card_def(SPARK))
			remaining = 0
	return true

static func phoenix_spark(gs, owner: int, count: int) -> void:
	var src := source(gs, owner, PHOENIX)
	if src < 0: return
	for i in count:
		gs.VerifiedRules.reduce_countdown(gs, owner, src, 1)
		if gs.winner < 0: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 1, "火种")

static func phoenix_spell(gs, owner: int, card: Dictionary) -> void:
	if str(card.unitId) != PHOENIX or not Content.is_spell(card): return
	var src := source(gs, owner, PHOENIX)
	if src < 0: return
	for realm in realm_cards(gs, owner, "hf-embers"):
		if gs.winner >= 0: return
		gs.VerifiedRules.base_damage_projectile(gs, owner, src, 1, str(realm.name))

static func discard(gs, owner: int, inst: Dictionary) -> void:
	if inst.definitionId == SPARK: phoenix_spark(gs, owner, int(inst.get("hfSparkLayers", 1)))
	var card := Content.card_def(str(inst.definitionId))
	if not card.is_empty(): phoenix_spell(gs, owner, card)

static func phoenix_turn_start(gs, owner: int) -> void:
	var src := source(gs, owner, PHOENIX)
	if src < 0: return
	var p: Dictionary = gs.player(owner)
	var repeats := int(p.get("hfPhoenixPurify", 0))
	p.erase("hfPhoenixPurify")
	for i in repeats: area(gs, owner, src, 1)

static func phoenix_expire(gs, owner: int) -> void:
	var hand: Array = gs.player(owner).hand
	for i in range(hand.size() - 1, -1, -1):
		var stamp := int(hand[i].get("hfExpires", -1))
		if stamp >= 0 and stamp <= gs.turn_counter: gs.discard_hand_card(owner, i)

static func noncombat_bonus(gs, owner: int, src: int, is_combat: bool) -> int:
	if is_combat or owner < 0 or src < 0 or src >= gs.player(owner).units.size(): return 0
	var u: Dictionary = gs.player(owner).units[src]
	return 2 if active(u) and u.get("formRules", {}).get("hfPhoenixForm", false) else 0

static func death_card(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var loc := target_location(gs, target_id)
	match str(effect.get("action", "")):
		"hf-66401": combat(gs, owner, src, card, target_id, 1)
		"hf-66402":
			var token := blossom(gs, owner, src, 3)
			token.swift = true
		"hf-66403":
			gs._deploy_realm(owner, card)
			if not target.is_empty(): attach_will(target, {"kind": "blossom", "size": 2})
		"hf-66404":
			blossom(gs, owner, src, 2)
			p.hfBlossomBonus = int(p.get("hfBlossomBonus", 0)) + 1
			var idx := blossom_index(gs, owner)
			if idx >= 0: gs._grow_unit(p.units[idx], 1, 1)
			gs._awaken(owner, src, card, effect.value)
		"hf-66405": combat(gs, owner, src, card, target_id, 0)
		"hf-66406":
			blossom(gs, owner, src, 3)
			var front: Dictionary = gs.front_unit(owner)
			if not loc.is_empty() and not front.is_empty(): gs._damage_unit(loc.owner, loc.index, maxi(0, int(front.attack) - 1), owner, src)
		"hf-66407":
			if int(u.hp) <= 0 and not revive(gs, owner, src): return true
			gs._install_form(owner, src, card, effect.value)
			u.swift = true
		"hf-66408":
			var depth: int = gs.resolution_stack.size()
			var front: int = gs.front_index(owner)
			if front >= 0 and p.units[front].get("summoned", false): attack(gs, owner, front, {"immuneCombat": true})
			gs.resolution_stack.insert(depth, {"kind": "hf-sakura-combat", "playerIndex": owner, "uid": u.uid, "card": card})
		"hf-66501":
			gain_sparks(gs, owner, 2)
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2, str(card.name))
		"hf-66502":
			area(gs, owner, src, 1)
			if discard_sparks(gs, owner, 1): p.hfPhoenixPurify = int(p.get("hfPhoenixPurify", 0)) + 1
		"hf-66503":
			if not loc.is_empty(): gs._damage_unit(loc.owner, loc.index, 3 + 2 * int(u.front), owner, src)
			if discard_sparks(gs, owner, 1): gs._draw(owner, 1)
		"hf-66504":
			gs._deploy_realm(owner, card)
			gain_sparks(gs, owner, 2)
		"hf-66505":
			gain_sparks(gs, owner, 2)
			gs._awaken(owner, src, card, effect.value)
		"hf-66506":
			var depth: int = gs.resolution_stack.size()
			if int(u.hp) > 0: gs._knockout_unit(u, owner, src)
			gs.resolution_stack.insert(depth, {"kind": "hf-phoenix-kindling", "playerIndex": owner, "uid": u.uid, "target": target_id, "spellContext": gs._card_effect_context})
		"hf-66507":
			gs._install_form(owner, src, card, effect.value)
			u.swift = true
		"hf-66508":
			var flags := {"hfInstant": true, "hfExpires": gs.turn_counter + 2}
			var pool := dedicated(PHOENIX, func(other): return Content.is_spell(other) and not other.get("token", false))
			if not pool.is_empty():
				for i in 2: give(gs, owner, str(random_item(gs, pool)), flags)
			gain_sparks(gs, owner, 2, flags)
		"hf-spark": phoenix_spark(gs, owner, int(card.get("hfSparkLayers", 1)))
		"hf-66601": choose(gs, owner, "rabbit", RABBIT_OPTIONS, "选择因幡兔的遗愿")
		"hf-66602":
			if not loc.is_empty(): gs._grow_unit(loc.unit, 1, 1)
			if card.get("hfPrayed", false):
				for idx in living_indices(gs, owner):
					if p.units[idx] != target: gs._grow_unit(p.units[idx], 1, 1)
		"hf-66603":
			if not loc.is_empty():
				if card.get("hfPrayed", false):
					gs.VerifiedRules.HairPower.give(gs, owner, loc.index, 2)
					gs._grant_unit_armor(loc.unit, 4)
				attack(gs, owner, loc.index)
		"hf-66604":
			gs._install_form(owner, src, card, effect.value)
			if card.get("hfPrayed", false) and not loc.is_empty():
				revive(gs, loc.owner, loc.index)
				var pool := dedicated(loc.unit.id, func(other): return not other.get("token", false))
				if not pool.is_empty(): give(gs, owner, str(random_item(gs, pool)))
		"hf-66605":
			if card.get("hfPrayed", false): gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1, 1)
			gs._awaken(owner, src, card, effect.value)
		"hf-66606":
			gs._deploy_realm(owner, card)
			if not loc.is_empty(): queue_wills(gs, owner, loc.unit, attached_wills(loc.unit))
		"hf-66607":
			if not target.is_empty(): attach_will(target, {"kind": "blessing"})
			if card.get("hfPrayed", false):
				var front: Dictionary = gs.front_unit(1 - owner)
				if not front.is_empty() and gs.VerifiedRules.OwlInsect.shikigami(front): gs._knockout_unit(front, owner, src)
		"hf-66608":
			gs._install_form(owner, src, card, effect.value)
			for i in 2: give(gs, owner, str(random_item(gs, PRAY)), {"hfPray": 0})
		_: return false
	return true

static func score(gs, owner: int, card: Dictionary, target_id):
	if not card.has("hanafudaRules"): return null
	var loc := target_location(gs, target_id)
	var src := source(gs, owner, str(card.unitId))
	if src < 0: return null
	var id := str(card.id)
	if id in ["c66301", "c66406", "c66503", "c66506", "c66106", HANA[4]]:
		var damage := int(card.get("value", 0))
		if id == "c66106": damage += 2 * hana_played(gs, gs.player(owner))
		if id == "c66406": damage = 2
		if id == "c66503": damage += 2 * int(gs.player(owner).units[src].front)
		if id == HANA[4]: damage = 2
		if loc.is_empty(): return 20
		return 44 + damage * 3 + (30 if damage >= int(loc.unit.hp) + int(loc.unit.shield) else 0) - (80 if loc.owner == owner else 0)
	if id == "c66104": return 44 + int(loc.unit.get("knockout", 0)) * 7 if not loc.is_empty() else 0
	if id in ["c66602", "c66702"] and not loc.is_empty() and loc.owner != owner:
		return 20 if id == "c66602" and card.get("hfPrayed", false) else -20
	if id == "c66204": return 40 + (18 if not loc.is_empty() and (loc.unit.id == WIND or loc.unit.has("hfEntryPower")) else 0)
	if id == "c66604" and card.get("hfPrayed", false) and not loc.is_empty():
		return 56 + (int(loc.unit.knockout) * 5 if loc.owner == owner else -20)
	if id == "c66606": return 35 + (attached_wills(loc.unit).size() * 10 if not loc.is_empty() else 0)
	if id == "c66603": return 32 + (int(loc.unit.attack) * 3 if not loc.is_empty() else 0)
	if card.get("hfPrayed", false): return 56
	if card.get("type") == "combat": return 43 + int(card.get("value", 0)) * 3
	if card.get("awakeningCard", false): return 57
	return 45
