class_name GrudgeRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const UNIT := "yuyuan-banruo"
const AVENGE := "fate-banruo-avenge"

static func attach(gs, owner: int, src: int, amount: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	u.grudge = int(u.get("grudge", 0)) + amount
	gs.VerifiedRules.event(gs, "charm-attached", {"player": owner, "uid": u.uid, "charm": "怨恨", "amount": amount})
	while int(u.grudge) >= 4:
		Choice.give(gs, owner, AVENGE)
		u.grudge = int(u.grudge) - 4
		gs.VerifiedRules.event(gs, "charm-removed", {"player": owner, "uid": u.uid, "charm": "怨恨", "amount": 4})

static func damaged(gs, owner: int, src: int, enemy: int, amount: int) -> void:
	if enemy != 1 - owner or amount <= 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if u.id == UNIT and int(u.hp) > 0 and int(u.level) > 0 and not u.get("baseRulesSuppressed", false):
		attach(gs, owner, src, 2 if u.awakened else 1)

static func describe(gs, owner: int, card: Dictionary, from_hand: bool = true) -> Dictionary:
	if not card.get("grudgeRules", false): return card
	var src: int = gs._source_index(owner, card)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	var result := card.duplicate(true)
	var enhanced := false
	match str(card.id):
		"w13-yuyuan-banruo-93133":
			var enemy: Dictionary = gs.front_unit(1 - owner)
			enhanced = int(enemy.get("attack", 0)) > int(u.attack) and not enemy.is_empty()
		"w13-yuyuan-banruo-93134":
			@warning_ignore("integer_division")
			var tokens := (int(u.get("grudge", 0)) + 2) / 4
			var hand_after := mini(gs.player(owner).hand.size() - int(from_hand) + tokens, int(gs.rules.maxHandSize))
			enhanced = hand_after < gs.player(1 - owner).hand.size()
		"w13-yuyuan-banruo-93135":
			enhanced = owner == 1
			if enhanced:
				result.attackBonus = 2
				result.combatOption = {"shield": 2}
		"w13-yuyuan-banruo-93137":
			enhanced = int(gs.player(owner).avatarHp) <= int(gs.player(1 - owner).avatarHp)
			if enhanced: result.combatOption = {"directAvatar": true, "lifeSteal": true}
		"w13-yuyuan-banruo-93138":
			enhanced = gs.player(owner).deck.size() <= gs.player(1 - owner).deck.size()
		"w13-yuyuan-banruo-93140":
			enhanced = gs.player(1 - owner).units.any(func(enemy): return enemy.get("awakened", false) and not enemy.get("removed", false))
		AVENGE:
			enhanced = bool(u.awakened)
			if enhanced: result.text = "永久瞬发。主动使用：本回合消灭与御怨般若战斗的敌方式神。响应：敌方式神攻击御怨般若时自动使用，敌方牌手受到等量反伤。"
	if (str(card.id) in ["w13-yuyuan-banruo-93135", "w13-yuyuan-banruo-93140"] and enhanced) or (str(card.id) == AVENGE and (enhanced or owner != gs.current_player)):
		if "instant" not in result.keywords: result.keywords.append("instant")
	result.enhanced = enhanced
	return result

static func targetable(gs, u: Dictionary) -> bool:
	return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil") and not gs.VerifiedRules.Movement.has_veil(u)

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") != "grudge-oath": return null
	var result: Array = gs.player(1 - owner).units.filter(func(u): return targetable(gs, u)).map(func(u): return str(u.uid))
	return gs.VerifiedRules.TomatoFire.targets(gs, owner, result)

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	if src < 0 or not str(effect.get("action", "")).begins_with("grudge-"): return false
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.action):
		"grudge-copy-power":
			var enemy: Dictionary = gs.front_unit(1 - owner)
			if not enemy.is_empty() and int(enemy.attack) > int(u.attack):
				gs._grow_unit(u, int(enemy.attack) - int(u.attack), 0)
				attach(gs, owner, src, 1)
			gs._grant_unit_armor(u, 1)
			gs._resolve_combat(owner, src, 0, false, false, false, false)
		"grudge-draw":
			attach(gs, owner, src, 2)
			if gs.player(owner).hand.size() < gs.player(1 - owner).hand.size(): gs._draw(owner, 2)
		"grudge-second":
			var second := owner == 1
			if second:
				attach(gs, owner, src, 1)
				gs._grant_unit_armor(u, 2)
			gs._resolve_combat(owner, src, 2 if second else 0, false, false, false, false)
		"grudge-blood":
			var enhanced := int(gs.player(owner).avatarHp) <= int(gs.player(1 - owner).avatarHp)
			attach(gs, owner, src, 1)
			gs._resolve_combat(owner, src, 2, false, false, false, false, null, false, {"directAvatar": enhanced, "lifeSteal": enhanced})
		"grudge-oath":
			if target.is_empty() or not targetable(gs, target): return true
			var idx: int = gs._unit_index_by_uid(1 - owner, target.uid)
			if idx < 0: return true
			gs._grow_unit(target, 3, 0)
			if not gs.VerifiedRules.Stun.blocks(gs, 1 - owner, target):
				gs._resolve_combat(1 - owner, idx, 0, false, false, false, false, null, false, {"grudgeOathUid": str(u.uid)})
		"grudge-avenge":
			var options := {}
			if u.awakened: u.grudgeVowTurn = gs.turn_counter
			else: options.grudgeReflectUid = str(u.uid)
			gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, options)
		_: return false
	return true

static func respond(gs, owner: int, src: int, combat_id: int) -> void:
	for frame in gs.resolution_stack:
		if frame.get("kind") != "combat-hit" or int(frame.get("combatId", -1)) != combat_id: continue
		frame.options.grudgeReflectUid = str(gs.player(owner).units[src].uid)
		return

static func realm_tick(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "grudge-spread": return false
	var src: int = gs._source_index(owner, {"unitId": UNIT})
	if src < 0: return true
	attach(gs, owner, src, 1)
	if gs.player(owner).deck.size() <= gs.player(1 - owner).deck.size():
		gs.VerifiedRules.Mengpo.bottom(gs, owner, src, 1 - owner, 1, "仇恨蔓延")
		gs._heal_avatar(owner, 3)
	return true

static func death_frame(gs, owner: int, unit: Dictionary) -> Dictionary:
	if owner < 0 or int(unit.front) != 1 or not unit.get("formRules", {}).get("grudgeBurden", false): return {}
	return {"kind": "grudge-last-wish", "playerIndex": owner, "sourceIndex": gs._unit_index_by_uid(owner, unit.uid)}

static func knocked_count(gs, units: Array) -> int:
	return units.filter(func(u): return int(u.get("knockout", 0)) > 0 and int(u.hp) <= 0 and gs.VerifiedRules.OwlInsect.shikigami(u)).size()

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if kind != "grudge-last-wish" and kind != "grudge-last-wish-destroy": return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var enemy := 1 - owner
	if kind == "grudge-last-wish":
		gs.resolution_stack.append({"kind": "grudge-last-wish-destroy", "playerIndex": owner, "sourceIndex": src})
		gs.VerifiedRules.base_damage_projectile(gs, owner, src, 3, "积重难返遗愿")
	elif knocked_count(gs, gs.player(owner).units) > knocked_count(gs, gs.player(enemy).units):
		var candidates: Array = gs.player(enemy).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))
		if not candidates.is_empty():
			var choice: Dictionary = candidates[int(gs.next_random() % candidates.size())]
			gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, gs._unit_index_by_uid(enemy, choice.uid))
	return true

static func strike(gs, owner: int, victim: int, idx: int, hit: Dictionary, options: Dictionary) -> void:
	if idx < 0 or int(hit.get("damage", 0)) <= 0: return
	var u: Dictionary = gs.player(victim).units[idx]
	var uid := str(u.uid)
	if options.get("grudgeOathUid", "") == uid: options.grudgeOathHurt = true
	if options.get("grudgeReflectUid", "") != uid or gs.winner >= 0: return
	gs.VerifiedRules.base_damage_avatar(gs, victim, idx, owner, int(hit.damage))

static func finish(gs, owner: int, src: int, defender: Dictionary, options: Dictionary) -> int:
	var u: Dictionary = gs.player(owner).units[src]
	var victim := int(options.get("combatVictim", 1 - owner))
	if options.get("grudgeOathHurt", false) and gs.winner < 0:
		var banruo: int = gs._unit_index_by_uid(victim, str(options.grudgeOathUid))
		if banruo >= 0:
			var ally: Dictionary = gs.player(victim).units[banruo]
			if int(ally.hp) > 0:
				gs._heal_unit(ally, int(ally.maxHp))
				var pool := Content.cards_for_unit(UNIT).filter(func(card): return not card.get("token", false) and card.get("type") != "awakening")
				if not pool.is_empty(): Choice.give(gs, victim, str(pool[int(gs.next_random() % pool.size())].id))
	if not options.get("grudgeDuelStarted", false) or defender.is_empty() or victim == owner: return 0
	var idx: int = gs._unit_index_by_uid(victim, defender.uid)
	var destroyed := 0
	if int(u.get("grudgeVowTurn", -1)) == gs.turn_counter:
		destroyed = int(gs.VerifiedRules.Panguan.destroy(gs, owner, src, victim, idx))
	if int(defender.get("grudgeVowTurn", -1)) == gs.turn_counter:
		gs.VerifiedRules.Panguan.destroy(gs, victim, idx, owner, src)
	return destroyed

static func score(gs, owner: int, card: Dictionary, uid):
	if not card.get("grudgeRules", false): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return null
	var u: Dictionary = gs.player(owner).units[src]
	var enhanced := bool(card.get("enhanced", false))
	match str(card.id):
		"w13-yuyuan-banruo-93134": return 63 if enhanced else 34
		"w13-yuyuan-banruo-93135": return 64 if enhanced else 28
		"w13-yuyuan-banruo-93136": return 66 if int(u.hp) < int(u.maxHp) else 49
		"w13-yuyuan-banruo-93137": return 72 if enhanced else 43
		"w13-yuyuan-banruo-93138": return 65 if enhanced else 40
		"w13-yuyuan-banruo-93139":
			var enemy: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, uid)
			var damage := int(enemy.get("attack", 0)) + 3 - int(u.shield)
			return 66 if int(u.front) == 1 and damage > 0 and damage < int(u.hp) and not gs.VerifiedRules.Stun.blocks(gs, 1 - owner, enemy) else -15
		"w13-yuyuan-banruo-93140": return 77
		AVENGE: return 74 if enhanced and gs.front_index(1 - owner) >= 0 else 40
	return 60 if enhanced else 30
