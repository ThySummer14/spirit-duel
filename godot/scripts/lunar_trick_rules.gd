extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "yuedu"
const FALSE_MOON := "yuedu-false-moon"
const SHADOW := "yuedu-shadow"

static func source(gs, owner: int) -> Dictionary:
	var idx: int = gs._source_index(owner, {"unitId": ID})
	return gs.player(owner).units[idx] if idx >= 0 else {}

static func form(gs, owner: int, key: String) -> bool:
	var u := source(gs, owner)
	return not u.is_empty() and int(u.hp) > 0 and u.get("formRules", {}).get(key, false)

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("id") != FALSE_MOON: return card
	var view := card.duplicate(true)
	var moon := source(gs, 1-owner)
	if not moon.is_empty() and gs.VerifiedRules.OwlInsect.active(moon) and moon.awakened:
		view.keywords.erase("instant")
	var amount := false_moon_amount(gs)
	view.currentCardStats = "当前伤害与治疗均为%d" % amount
	return view

static func false_moon_amount(gs) -> int:
	for owner in 2:
		if gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "lunar-sea" and int(r.hp) > 0): return 4
	return 2

static func false_moon(gs, owner: int) -> void:
	var amount := false_moon_amount(gs)
	gs._damage_avatar(owner, amount, owner)
	if gs.winner >= 0: return
	gs._heal_avatar(1-owner, amount)
	gs.VerifiedRules.Insight.enter(gs, owner)

static func grant(gs, owner: int) -> void:
	gs.VerifiedRules.Baize.put_hand(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, FALSE_MOON))

static func targets(gs, owner: int, card: Dictionary):
	match str(card.get("effect", "")):
		"lunar-lie": return gs.VerifiedRules.WaterMoon.board_targets(gs, owner)
		"lunar-feast", "lunar-planet":
			return gs.player(1-owner).units.filter(func(u):
				return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil")
			).map(func(u): return str(u.uid))
	return null

static func hand_pool(gs, owner: int, unit_id: String = "") -> Array:
	return gs.player(1-owner).hand.filter(func(inst):
		return unit_id.is_empty() or Content.card_def(str(inst.definitionId)).get("unitId") == unit_id
	)

static func choose(gs, owner: int, src: int, pool: Array, limit: int, shadow: bool = false) -> bool:
	if pool.is_empty(): return false
	var ids: Array = []
	var random_sample := pool.size() > limit
	while not pool.is_empty() and ids.size() < limit:
		var inst: Dictionary = pool.pop_at(int(gs.next_random() % pool.size())) if random_sample else pool.pop_front()
		ids.append(str(inst.instanceId))
	gs.pending_choice = {"type": "lunar-seize", "playerIndex": owner, "sourceIndex": src, "instanceIds": ids,
		"zoneOwner": 1-owner, "zone": "hand", "shadow": shadow, "heading": "月读 · 展示手牌",
		"hint": "选择一张置入敌方启悟区。"}
	gs.phase = "choice"
	return true

static func before_attack(gs, frame: Dictionary) -> bool:
	if frame.get("lunarOffered", false): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if u.id != ID or not gs.VerifiedRules.OwlInsect.active(u) or frame.options.get("hairGuard", false): return false
	if not u.awakened and owner != gs.current_player: return false
	if int(u.get("lunarAttackTurn", -1)) == gs.turn_counter: return false
	var pool := hand_pool(gs, owner)
	if pool.is_empty(): return false
	u.lunarAttackTurn = gs.turn_counter
	frame.lunarOffered = true
	gs.resolution_stack.append(frame)
	return choose(gs, owner, src, pool, 3, u.awakened)

static func moved(gs, owner: int, inst: Dictionary) -> void:
	if not form(gs, owner, "lunarFeast"): return
	var u := source(gs, owner)
	if int(u.get("lunarStunTurn", -1)) == gs.turn_counter: return
	var idx: int = gs._source_index(1-owner, Content.card_def(str(inst.definitionId)))
	if idx < 0 or int(gs.player(1-owner).units[idx].hp) <= 0: return
	u.lunarStunTurn = gs.turn_counter
	gs.VerifiedRules.Stun.apply(gs, 1-owner, idx, 1, owner)

static func transfer(gs, owner: int, src: int, inst: Dictionary, shadow: bool = false, overflow_grants: bool = false) -> void:
	var enemy := 1-owner
	gs.player(enemy).hand.erase(inst)
	gs.VerifiedRules.Glutton.mark_hand(gs, enemy)
	var placed: bool = gs.VerifiedRules.Insight.place(gs, enemy, inst)
	if placed or overflow_grants: grant(gs, enemy)
	if placed:
		moved(gs, owner, inst)
		if shadow:
			var unit: Dictionary = Content.unit_def(str(Content.card_def(str(inst.definitionId)).get("unitId", "")))
			gs.VerifiedRules.NativeSummons.summon(gs, owner, src, SHADOW, "虚影", int(unit.get("attack", 0)), maxi(1, int(unit.get("maxHp", 1))))

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "lunar-seize" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	var inst: Dictionary = gs.VerifiedRules.WaterMoon.hand_instance(gs, 1-owner, iid)
	if inst.is_empty(): return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("lunar-seize", {"instanceId": iid}, owner)
	transfer(gs, owner, int(choice.sourceIndex), inst, choice.shadow)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "lunar-seize": return null
	var best := ""
	var score := -100
	for iid in gs.pending_choice.instanceIds:
		var inst: Dictionary = gs.VerifiedRules.WaterMoon.hand_instance(gs, 1-owner, str(iid))
		var card := Content.card_def(str(inst.get("definitionId", "")))
		var candidate := int(card.get("level", 0)) * 2
		if card.get("id") == FALSE_MOON: candidate -= 9
		if candidate > score:
			best = str(iid)
			score = candidate
	return resolve_choice(gs, owner, best)

static func false_index(gs, owner: int) -> int:
	var hand: Array = gs.player(owner).hand
	for i in hand.size():
		if hand[i].definitionId == FALSE_MOON: return i
	return -1

static func announced(gs, owner: int, card: Dictionary) -> void:
	var enemy := 1-owner
	if not card.get("insightFromZone", false) or not form(gs, enemy, "lunarLimit"): return
	var u := source(gs, enemy)
	if int(u.get("lunarDrawTurn", -1)) == gs.turn_counter: return
	u.lunarDrawTurn = gs.turn_counter
	gs.resolution_stack.append({"kind": "lunar-draw", "playerIndex": enemy})

static func counter(gs, frame: Dictionary, card: Dictionary) -> bool:
	var owner := 1-int(frame.playerIndex)
	if int(frame.sourceIndex) < 0: return false
	if not frame.get("usedFromHand", false) and not card.get("insightFromZone", false): return false
	var continuation := frame.duplicate(true)
	continuation.kind = "card-counter-check"
	return gs.VerifiedRules.automatic_response(gs, owner, "lunar-counter", null, continuation)

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "lunar-sea": return false
	var pool := hand_pool(gs, owner)
	if not pool.is_empty():
		transfer(gs, owner, -1, pool[int(gs.next_random() % pool.size())], false, true)
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var enemy := 1-owner
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.action):
		"lunar-lie":
			var inst: Dictionary = gs.VerifiedRules.WaterMoon.move_board(gs, owner, target_id, card.name)
			if not inst.is_empty():
				moved(gs, owner, inst)
				grant(gs, enemy)
			gs._draw(owner, 1)
		"lunar-void":
			var event_start := int(gs.next_rule_event_id)
			var resolution_id := int(gs._card_effect_context.get("resolutionId", -1))
			var amount := int(effect.value)
			var idx: int = gs.front_index(enemy)
			if idx < 0: gs._damage_avatar(enemy, amount, owner, src)
			else: gs._damage_unit(enemy, idx, amount, owner, src)
			for hit in gs.rule_events.duplicate():
				if hit.id < event_start or hit.kind != "damage-resolved" or int(hit.get("resolutionId", -2)) != resolution_id or int(hit.amount) <= 0: continue
				var victim := int(hit.victimPlayer)
				var hit_idx: int = gs._unit_index_by_uid(victim, hit.target)
				if hit_idx < 0: continue
				var target: Dictionary = gs.player(victim).units[hit_idx]
				if int(target.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(target) and gs.VerifiedRules.Insight.zone(gs, victim).any(func(inst): return Content.card_def(str(inst.definitionId)).get("unitId") == target.id):
					gs.VerifiedRules.Panguan.destroy(gs, owner, src, victim, hit_idx, card)
		"lunar-form":
			gs._apply_form(owner, src, card, effect.value)
			u.swift = true
		"lunar-awake":
			gs._awaken(owner, src, card, effect.value)
			u.swift = true
		"lunar-counter":
			var idx := false_index(gs, enemy)
			if idx >= 0: gs.discard_hand_card(enemy, idx)
			if card.has("lunarCounter"):
				var original: Dictionary = card.lunarCounter
				var canceled: Dictionary = original.get("cardOverride", Content.card_def(str(original.definitionId)))
				gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId", -1)) != int(original.resolutionId))
				gs._log("「%s」被虚诞月落反制。" % canceled.name, gs.TONE_DANGER)
				gs.VerifiedRules.event(gs, "card-nullified", {"player": enemy, "card": canceled, "resolutionId": original.resolutionId})
				gs.VerifiedRules.Insight.used(gs, enemy, canceled, canceled.get("playedInstance", {}), false)
		"lunar-feast", "lunar-planet":
			if effect.action == "lunar-feast": gs._apply_form(owner, src, card, effect.value)
			else: gs.resolution_stack.append({"kind": "lunar-planet-damage", "playerIndex": owner, "sourceIndex": src, "cardContext": gs._card_effect_context.duplicate(true)})
			var target: Dictionary = gs._unit_by_uid(gs.player(enemy).units, target_id)
			if not target.is_empty() and int(target.hp) > 0: choose(gs, owner, src, hand_pool(gs, owner, str(target.id)), 999)
		"lunar-sea":
			gs._deploy_realm(owner, card)
			trigger_realm(gs, owner, gs.player(owner).realms.back())
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	match frame.get("kind"):
		"lunar-draw": gs._draw(owner, 1)
		"lunar-planet-damage":
			var prior: Dictionary = gs._card_effect_context
			gs._card_effect_context = frame.cardContext
			for idx in gs.player(1-owner).units.size():
				var u: Dictionary = gs.player(1-owner).units[idx]
				if int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u): gs._damage_unit(1-owner, idx, 2, owner, int(frame.sourceIndex))
			gs._card_effect_context = prior
		_: return false
	return true
