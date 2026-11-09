class_name XuenvRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")
## Snowball history belongs to the player; stun production belongs to each live Snow Woman.
static func source(unit: Dictionary) -> bool:
	return bool(ContentLoader.runtime_unit_def(unit).get("snowWoman", false))

static func token(gs, owner: int, count: int = 1) -> void:
	var p: Dictionary = gs.player(owner)
	for i in count:
		if p.hand.size() >= int(gs.rules.get("maxHandSize", 12)):
			gs._log("手牌已满，雪球被移除。", gs.TONE_NEUTRAL)
			continue
		p.hand.append({"instanceId": "%s-snow-%d" % [p.id, gs.next_card_id], "definitionId": "xueqiu"})
		gs.next_card_id += 1
		gs.VerifiedRules.event(gs, "snowball-created", {"player": owner, "card": ContentLoader.card_def("xueqiu")})

static func stunned(gs, victim: int, idx: int, new_stun: bool, owner: int = -1) -> void:
	if idx < 0 or not new_stun: return
	if owner < 0: owner = 1 - victim
	if owner == victim: return
	for unit in gs.player(owner).units:
		if not source(unit) or int(unit.hp) <= 0 or int(unit.level) < 1: continue
		if int(unit.get("snowballTurn", -1)) == gs.turn_counter: continue
		unit.snowballTurn = gs.turn_counter
		token(gs, owner)

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if frame.get("automatic", false) or not frame.get("usedFromHand", false) or not card.get("snowball", false): return
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	p.snowballsPlayed = int(p.get("snowballsPlayed", 0)) + 1
	gs.VerifiedRules.event(gs, "snowball-hand-use", {"player": owner, "count": int(p.snowballsPlayed), "card": card})

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.has("xuenvRule"): return card
	var view := card.duplicate(true)
	var p: Dictionary = gs.player(owner)
	if card.get("snowball", false):
		view.value = 1 + int(p.get("snowballBonus", 0))
		view.effects[0].value = view.value
		view.text = "瞬发。对一个敌方式神造成%d点伤害。" % int(view.value)
	elif card.xuenvRule == "flurry":
		view.text += "\n本局从手牌使用雪球：%d；本次使用%d张，每张%d伤害。" % [int(p.get("snowballsPlayed", 0)), 1 + int(p.get("snowballsPlayed", 0)), 1 + int(p.get("snowballBonus", 0))]
	return view

static func damage_dealt(gs, owner: int, src: int, victim: int, idx: int, damage: int, combat: bool) -> void:
	if damage <= 0 or src < 0 or owner < 0 or idx < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	var target: Dictionary = gs.player(victim).units[idx]
	# Call before knockout clears a destroyed wall's state. A lethal combat hit
	# still freezes its attacker, while a spell/armor-only hit never does.
	if combat and target.get("iceWall", false): gs.VerifiedRules.Stun.apply(gs, owner, src, 1, victim)
	if source(unit) and unit.awakened: gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)

static func combat_traits(gs, owner: int, src: int) -> Dictionary:
	var unit: Dictionary = gs.player(owner).units[src]
	return {"snowCombatStun": int(unit.get("snowCombatStunTurn", -1)) == gs.turn_counter}

static func combat_dealt(gs, owner: int, victim: int, idx: int, result: Dictionary, traits: Dictionary) -> void:
	if idx >= 0 and traits.get("snowCombatStun", false) and int(result.get("dealt", result.get("damage", 0))) > 0:
		gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)

static func after_attack(gs, owner: int, src: int) -> void:
	var victim := 1 - owner
	for i in gs.player(victim).units.size():
		var unit: Dictionary = gs.player(victim).units[i]
		if int(unit.hp) <= 0 or int(unit.level) < 1 or not unit.get("formRules", {}).get("snowstorm", false): continue
		var hit: Dictionary = gs._damage_unit(owner, src, 1, victim, i)
		if int(hit.get("dealt", hit.get("damage", 0))) > 0: gs.VerifiedRules.Stun.apply(gs, owner, src, 1, victim)
		gs.VerifiedRules.event(gs, "snowstorm-hit", {"player": victim, "uid": unit.uid, "victimPlayer": owner, "target": gs.player(owner).units[src].uid, "amount": int(hit.damage)})

static func end_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if int(unit.get("snowCombatStunTurn", -1)) <= gs.turn_counter: unit.erase("snowCombatStunTurn")

static func remove_wall(gs, owner: int, wall: Dictionary, reason: String = "离开战斗区") -> void:
	if not wall.get("iceWall", false) or int(wall.hp) <= 0: return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(wall.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(wall.uid)),reason,false)
	wall.hp = 0
	wall.front = 0
	wall.knockout = 0
	wall.removed = true
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": wall.uid, "reason": reason})

static func clear_wall(gs, owner: int) -> void:
	for unit in gs.player(owner).units:
		if unit.get("iceWall", false): remove_wall(gs, owner, unit)

static func remove_departed_walls(gs) -> void:
	for owner in 2:
		for unit in gs.player(owner).units:
			if unit.get("iceWall", false) and int(unit.front) == 0 and int(unit.hp) > 0: remove_wall(gs, owner, unit)

static func summoned_knockout(unit: Dictionary) -> void:
	if not unit.get("summoned", false) or unit.get("nativeFieldSummon", false): return
	unit.knockout = 0
	unit.removed = true

static func summon_wall(gs, owner: int, src: int) -> void:
	var p: Dictionary = gs.player(owner)
	# Slots are never removed/reused during a match: queued source indices and
	# snapshots stay valid. Inactive tombstones cannot be targeted/revived.
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	var wall := {"uid": "%s:ice-wall-%d" % [p.id, gs.next_card_id], "id": "xuenv-ice-wall", "name": "冰墙", "title": "雪女召唤物", "art": "assets/wave11/bingqiang.svg", "color": "#9bb8d4", "baseAttack": 0, "baseMaxHp": 4, "attack": 0, "maxHp": 4, "hp": 4, "shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0, "unyielding": false, "level": 1, "front": 1, "attackBonus": 0, "maxHpBonus": 0, "awakened": false, "form": {}, "formRules": {}, "formAbility": "不能攻击。眩晕对其造成战斗伤害的式神。离开战斗区时移除。", "charge": 0, "passive_hooks": [], "summoned": true, "summon": true, "countsAsShikigami": true, "iceWall": true, "cannotAttack": true, "summonerUid": p.units[src].uid}
	gs.next_card_id += 1
	p.units.append(wall)
	gs.VerifiedRules.Enma.refresh(gs)
	gs._log("雪女在战斗区召唤了0/4冰墙。", gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": wall.uid, "sourceUid": p.units[src].uid})
	gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-entered-front", wall.uid, {"kind": "response-complete"})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	match str(effect.get("action", "")):
		"xuenv-shield":
			if target.is_empty() or int(target.hp) <= 0: return true
			gs._grant_unit_armor(target, 2)
			target.snowCombatStunTurn = gs.turn_counter
		"xuenv-collapse":
			if target.is_empty() or int(target.hp) <= 0: return true
			for victim in 2:
				var idx: int = gs._unit_index_by_uid(victim, target.uid)
				if idx < 0: continue
				if int(target.frozen) > 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, victim, idx, card)
				else: gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)
		"xuenv-damage":
			for victim in 2:
				if str(target_id) == "avatar-%d" % victim: gs._damage_avatar(victim, int(effect.value), owner, src)
				elif not target.is_empty():
					var idx: int = gs._unit_index_by_uid(victim, target.uid)
					if idx >= 0: gs._damage_unit(victim, idx, int(effect.value), owner, src)
		"xuenv-token": token(gs, owner, int(effect.value))
		"xuenv-heart":
			p.snowballBonus = int(p.get("snowballBonus", 0)) + 1
			token(gs, owner, 2)
		"xuenv-wall": summon_wall(gs, owner, src)
		"xuenv-flurry":
			var count := 1 + int(p.get("snowballsPlayed", 0))
			var snowball: Dictionary = describe_card(gs, owner, ContentLoader.card_def("xueqiu"))
			# These are actual automatic spell uses, do not consume hand/fire or
			# shared instant, and cannot increase the hand-use history themselves.
			gs.resolution_stack.append({"kind": "xuenv-flurry-next", "playerIndex": owner, "sourceIndex": src, "targetId": target_id, "card": snowball, "remaining": count})
		"xuenv-awaken":
			var unit: Dictionary = p.units[src]
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "xuenv-flurry-next": return false
	var remaining := int(frame.remaining)
	if remaining <= 0 or gs.winner >= 0: return true
	# Keep stack use constant even after a long game with dozens of hand casts.
	var next := frame.duplicate(true)
	next.remaining = remaining - 1
	gs.resolution_stack.append(next)
	var card: Dictionary = frame.card
	gs._push_card_frames(int(frame.playerIndex), str(card.id), frame.targetId, card, int(frame.sourceIndex), 0, true)
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.has("xuenvRule"): return null
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
	var src: int = gs._source_index(owner, card)
	var unit: Dictionary = gs.player(owner).units[src]
	match str(card.xuenvRule):
		"collapse": return -100 if enemy.is_empty() else 50 + int(enemy.attack) * 4 + (30 if int(enemy.frozen) > 0 else 0)
		"shield": return 45 if not gs._unit_by_uid(gs.player(owner).units, target_id).is_empty() else -100
		"wall": return -30 if gs.front_unit(owner).get("iceWall", false) else 45
		"heart": return 65
		"awaken": return 75 if not unit.awakened else 5
		"storm": return -100 if unit.get("formRules", {}).get("snowstorm", false) else 65
		"flurry", "damage", "snowball":
			var amount := int(card.value) if card.value is int or card.value is float else 0
			if card.xuenvRule == "flurry": amount = (1 + int(gs.player(owner).get("snowballsPlayed", 0))) * (1 + int(gs.player(owner).get("snowballBonus", 0)))
			if str(target_id) == "avatar-%d" % (1 - owner): return 1000 if amount >= int(gs.player(1 - owner).avatarHp) + int(gs.player(1 - owner).avatarArmor) else 30 + amount
			if enemy.is_empty(): return -100
			return 35 + amount * 3 + (30 if amount >= int(enemy.hp) + int(enemy.shield) else 0) + (20 if unit.awakened and int(enemy.frozen) == 0 else 0)
	return 0
