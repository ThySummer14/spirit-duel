extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const DEER := "xiaolunan-qianshou"
const STAGES := ["c63502", "stars-deer-2", "stars-deer-3", "stars-deer-4"]
const POWER := "stars-deer-strength"
const BLESSING := "stars-deer-blessing"

static func spirit(unit: Dictionary) -> bool:
	return unit.id == DEER and unit.get("forestSpirit", false) and not unit.get("removed", false)

static func use_charge(unit: Dictionary) -> bool:
	return unit.id == DEER and (unit.awakened or spirit(unit))

static func free_cast(gs, owner: int, card: Dictionary) -> bool:
	if card.get("unitId", "") != DEER or not (card.get("giftEnergyMode", false) or card.id in [POWER, BLESSING]): return false
	var src: int = gs._source_index(owner, card)
	return src >= 0 and spirit(gs.player(owner).units[src]) and int(gs.player(owner).get("forestFreeTurn", -1)) != gs.turn_counter and has_realm(gs, owner, "stars-deer-statue")

static func has_realm(gs, owner: int, key: String) -> bool:
	return gs.player(owner).realms.any(func(r): return int(r.hp) > 0 and r.nativeRealm == key)

static func adjust_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.get("unitId", "") != DEER: return card
	var src: int = gs._source_index(owner, card)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	var out := card.duplicate(true)
	if out.id == "c63507":
		out.forestBattlePower = maxi(0, int(u.attackBonus) + int(u.get("permanentAttack", 0)))
		out.combatOption.shield = maxi(0, int(u.maxHpBonus))
		out.currentCardStats = "战力 +%d · 护甲 +%d" % [out.forestBattlePower, out.combatOption.shield]
	if inst.get("forestReturned", false): out.forestReturned = true
	return out

static func gift(gs, owner: int, src: int, key: String, target) -> bool:
	if not key.begins_with("deer-"): return false
	var u: Dictionary = gs.player(owner).units[src]
	match key:
		"deer-pursuit":
			gs._grow_unit(u, 1, 0)
			u.forestPursuit = true
		"deer-swift":
			gs._grow_unit(u, 1, 0)
			u.forestSwift = true
			if int(u.hp) > 0: u.swift = true
		"deer-evolve":
			u.forestStage = mini(STAGES.size() - 1, int(u.get("forestStage", 0)) + 1)
			if int(u.hp) > 0 and u.get("form", {}).is_empty(): base_form(gs, owner, src)
		"deer-spirit-haste": u.forestHaste = true
		"deer-resolute": u.forestResolute = true
		"deer-spell-immune": u.forestSpellImmune = true
		"deer-growth": gs._grow_unit(u, 1, 1)
		"deer-funeral":
			if gs.front_index(1 - owner) < 0:
				var idx: int = gs._unit_index_by_uid(1 - owner, target)
				if idx >= 0 and int(gs.player(1 - owner).units[idx].hp) > 0:
					gs.VerifiedRules.move_unit(gs, 1 - owner, gs.player(1 - owner).units[idx])
	return true

static func base_form(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	var rank := int(u.get("forestStage", 0))
	if rank == 0: return
	var form := Content.card_def(STAGES[rank]).duplicate(true)
	form.forestBase = true
	gs._apply_form(owner, src, form, form.value)
	u.forestBaseForm = true
	u.swift = true

static func knocked(gs, owner: int, u: Dictionary) -> void:
	if owner < 0 or u.id != DEER or u.get("baseRulesSuppressed", false): return
	var f: Dictionary = u.get("form", {})
	if STAGES.slice(0, 3).has(f.get("cardId", "")) and not u.get("forestBaseForm", false) and not u.get("forestFormReturned", false):
		var item: Dictionary = gs.VerifiedRules.GiftEnergy.fresh_instance(gs, owner, str(f.cardId))
		item.forestReturned = true
		gs.VerifiedRules.Baize.put_hand(gs, owner, item)
	u.erase("forestBaseForm")
	u.erase("forestFormReturned")
	u.forestSpirit = true
	u.forestOriginalName = u.name
	u.name = "森之灵"
	u.charge = 3 if u.awakened else 2
	if u.awakened: gs._grow_unit(u, 1, 0)

static func revived(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not spirit(u): return
	var spirit_energy := int(u.charge)
	u.erase("forestSpirit")
	u.name = u.get("forestOriginalName", u.name)
	u.erase("forestOriginalName")
	u.charge = spirit_energy if u.awakened else 0
	base_form(gs, owner, src)
	if u.get("forestSwift", false): u.swift = true
	for realm in gs.player(owner).realms.duplicate():
		if realm.nativeRealm == "stars-deer-stream" and int(realm.hp) > 0:
			gs.VerifiedRules.base_damage_projectile(gs, owner, src, spirit_energy, "七角溪畔")

static func finish_gift(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("giftEnergyMode", false): return
	var u: Dictionary = gs.player(owner).units[src]
	if not spirit(u) or not u.get("forestHaste", false): return
	u.knockout = maxi(0, int(u.knockout) - 1)
	if int(u.knockout) == 0 and gs.VerifiedRules.Rebirth.can_revive(u):
		gs._resolve_action(owner, src, {}, {"action":"revive","target":"source","value":0}, null, {})

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	var burst := int(card.get("movementBurst", 0))
	if card.id in [POWER, BLESSING] and burst > 0:
		if not gs.VerifiedRules.Yujiazhu.pay_burst(gs, owner, src, burst): return true
		gs.VerifiedRules.Whale.burst(gs, owner, src, burst)
	match str(effect.action):
		"stars-deer-form":
			gs._apply_form(owner, src, card, effect.value)
			u.forestBaseForm = false
			u.forestFormReturned = card.get("forestReturned", false)
			if card.id != "c63502" and card.id != "c63505": u.swift = true
		"stars-deer-awake": gs._awaken(owner, src, card, effect.value)
		"stars-deer-battle":
			var opts: Dictionary = card.get("combatOption", {}).duplicate(true)
			opts.lethal = card.id == "c63508"
			if card.id == "c63507" and int(card.get("forestBattlePower", 0)) > 0:
				gs.VerifiedRules.HairPower.give(gs, owner, src, int(card.forestBattlePower))
			gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, target_id, opts)
		"abyss-stars-deer-stream":
			gs._deploy_realm(owner, card)
			if spirit(u): gs._resolve_action(owner, src, card, {"action":"revive","target":"source","value":0}, null, {})
		"abyss-stars-deer-statue":
			gs._deploy_realm(owner, card)
			gs.VerifiedRules.DragonAbyss.put(gs, owner, POWER)
			gs.VerifiedRules.DragonAbyss.put(gs, owner, BLESSING)
		"stars-deer-strength":
			var side := owner if gs._unit_index_by_uid(owner, target_id) >= 0 else 1 - owner
			var idx: int = gs._unit_index_by_uid(side, target_id)
			if idx >= 0:
				gs.VerifiedRules.Stun.apply(gs, side, idx, 1, owner, src)
				gs._damage_unit(side, idx, 4, owner, src)
		"stars-deer-blessing":
			for friend in gs.player(owner).units:
				if int(friend.hp) <= 0 or (burst == 0 and str(friend.uid) != str(target_id)): continue
				gs._grow_unit(friend, 1, 1)
				gs._grant_unit_armor(friend, 1)
		_: return false
	return true

static func combat_options(u: Dictionary, options: Dictionary) -> void:
	if u.id != DEER: return
	var stage: int = STAGES.find(u.get("form", {}).get("cardId", ""))
	if stage >= 1: options.lifeSteal = true
	if stage >= 2: options.immuneCombat = true
