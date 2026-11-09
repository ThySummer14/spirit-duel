extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const Flow := preload("res://scripts/dragon_flow_rules.gd")
const ZEN := "chanxinyunwaijing"
const POOR := "pinfashen"
const ORIGINS := ["c24201","c24202","c24203","c24204","c24205","c24206","c24207","c24208"]
const YANG := ["c65601","c65603","c65606"]
const YIN := ["c65602","c65603","c65604","c65605","c65607","c65608"]
const TRAITS := ["swift-card","pierce","combo","remote","first-strike","direct","pursuit","penetration","unyielding","crit","lethal","life-steal","veil"]

static func attach_blessing(gs, owner: int, u: Dictionary) -> void:
	if int(u.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	u.cosmosBlessing = true
	gs.VerifiedRules.event(gs, "cosmos-blessing-gained", {"player":owner,"uid":u.uid})

static func protect(gs, owner: int, u: Dictionary, source_owner: int) -> bool:
	if source_owner < 0 or source_owner == owner or not u.get("cosmosBlessing", false): return false
	u.erase("cosmosBlessing")
	gs.VerifiedRules.event(gs, "cosmos-blessing-spent", {"player":owner,"uid":u.uid})
	ward_lost(gs, owner, u)
	return true

static func ward_lost(gs, owner: int, u: Dictionary) -> void:
	if int(u.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	for _r in gs.VerifiedRules.DuskCycle.realms(gs, owner, "zen-ward"):
		gs.VerifiedRules.Glutton.record_permanent(u, 1, 1)
		gs._grow_unit(u, 1, 1)

static func mirror_turn(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not u.get("formRules", {}).get("zenLight", false): return
	for ally in Choice.live_units(gs, owner):
		if ally.get("cosmosBlessing", false): gs.VerifiedRules.HairPower.give(gs, owner, gs._unit_index_by_uid(owner, ally.uid), 2)

static func turn_start(gs, owner: int) -> void:
	var src := Flow.active(gs, owner, ZEN)
	if src >= 0: mirror_turn(gs, owner, src)

static func origins(gs, owner: int, count: int) -> void:
	var p: Dictionary = gs.player(owner)
	for _i in count:
		var id: String = ORIGINS[int(gs.next_random()%ORIGINS.size())]
		var inst: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, id)
		inst.zenOrigin = true
		p.deck.append(inst)
	gs._shuffle(p.deck)

static func zen_card(inst: Dictionary) -> bool:
	return str(inst.definitionId).begins_with("c656") or bool(inst.get("zenOrigin", false))

static func zen_candidates(gs, owner: int, card: Dictionary) -> Array:
	if str(card.get("unitId", "")) != ZEN or card.get("zenLinked", false) or Flow.active(gs, owner, ZEN) < 0: return []
	var src := Flow.source(gs, owner, ZEN)
	var u: Dictionary = gs.player(owner).units[src]
	return gs.player(owner).deck.filter(func(i):
		return zen_card(i) and int(Content.card_def(str(i.definitionId)).level) <= int(u.level)
	)

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var out := card
	if inst.get("zenOrigin", false):
		out = card.duplicate(true)
		out.unitId = ZEN
		out.zenOrigin = true
	if inst.get("zenLinked", false):
		out = out.duplicate(true)
		out.zenLinked = true
		out.linkedUse = true
	if out.get("id") == "c65708":
		var src := Flow.source(gs, owner, POOR)
		if src < 0: return out
		var n := mini(13, int(gs.player(owner).units[src].get("misfortune", 0)))
		out = out.duplicate(true)
		out.attackBonus = n
		out.keywords.assign(TRAITS.slice(0,n))
		out.combatOption.merge({"unyielding":"unyielding" in out.keywords, "lifeSteal":"life-steal" in out.keywords}, true)
		out.currentCardStats = "不幸 %d · 灾厄强化 %d/13" % [int(gs.player(owner).units[src].get("misfortune", 0)), n]
	return out

static func links_resolved(gs, owner: int, src: int, linked: Array) -> void:
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	for inst in linked:
		var id := str(inst.definitionId)
		if id in YANG: attach_blessing(gs, owner, u)
		if id in YIN:
			u.temporaryAttack = int(u.get("temporaryAttack", 0))+1
			gs._recalc(u)
		if id == "c65603": origins(gs, owner, 1)

static func add_misfortune(gs, owner: int, idx: int, count: int, source_owner: int) -> void:
	if idx < 0 or count <= 0 or gs.winner >= 0: return
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(u) or protect(gs, owner, u, source_owner): return
	u.misfortune = int(u.get("misfortune", 0))+count
	if u.id == POOR:
		gs._recalc(u)
		if u.get("formRules", {}).get("poorAttack", false) and int(u.get("poorAttackTurn", -1)) != gs.turn_counter:
			u.poorAttackTurn = gs.turn_counter
			gs.resolution_stack.append({"kind":"cosmos-poor-attack","playerIndex":owner,"sourceIndex":idx})
	gs.VerifiedRules.event(gs, "cosmos-misfortune", {"player":owner,"uid":u.uid,"amount":count,"total":u.misfortune})
	gs.VerifiedRules.DragonFlow.curse_attached(gs, owner, idx)

static func power(u: Dictionary) -> int:
	return int(u.get("misfortune", 0)) if u.id == POOR else 0

static func transfer_all(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	var total := 0
	for side in 2:
		for target in gs.player(side).units:
			if target.uid == u.uid or not gs.VerifiedRules.OwlInsect.shikigami(target): continue
			total += int(target.get("misfortune", 0))
			target.erase("misfortune")
			if target.id == POOR: gs._recalc(target)
	add_misfortune(gs, owner, src, total, owner)

static func knocked(gs, owner: int, u: Dictionary) -> void:
	var n := int(u.get("misfortune", 0))
	u.erase("misfortune")
	u.erase("cosmosBlessing")
	if owner < 0 or u.id != POOR or not u.awakened or n <= 0: return
	for _i in n:
		var pool := Choice.sample(gs, Choice.live_units(gs, 1-owner), 1)
		if not pool.is_empty(): add_misfortune(gs, 1-owner, gs._unit_index_by_uid(1-owner, pool[0].uid), 1, owner)

static func first_die(gs, owner: int, src: int) -> bool:
	if src < 0 or not (Flow.has_realm(gs, owner, "poor-fate") or Flow.has_realm(gs, 1-owner, "poor-fate")): return false
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.get("poorDieTurn", -1)) == gs.turn_counter: return false
	u.poorDieTurn = gs.turn_counter
	return true

static func fortune_result(gs, owner: int, src: int, success: bool) -> void:
	if src < 0 or success: return
	for side in 2:
		for realm in gs.VerifiedRules.DuskCycle.realms(gs, side, "poor-fate"):
			if int(realm.get("poorFailTurn", -1)) == gs.turn_counter: continue
			realm.poorFailTurn = gs.turn_counter
			add_misfortune(gs, owner, src, 1, side)

static func wrong_enemy(gs, owner: int, options: Dictionary, selected):
	var victim := int(options.get("combatVictim", 1-owner))
	var default = selected
	if default == null:
		var front: Dictionary = gs.front_unit(victim)
		default = front.get("uid", "avatar-%d" % victim)
	var candidates := Choice.live_units(gs, victim).map(func(u): return str(u.uid))
	candidates.append("avatar-%d" % victim)
	candidates.erase(default)
	var pool := Choice.sample(gs, candidates, 1)
	return default if pool.is_empty() else pool[0]

static func attack_started(gs, frame: Dictionary) -> void:
	if frame.get("cosmosPoorStarted", false): return
	frame.cosmosPoorStarted = true
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0 or u.get("baseRulesSuppressed", false): return
	var old := int(u.get("misfortune", 0))
	var wrong := bool(frame.options.get("poorForce", false))
	if u.id == POOR:
		if u.awakened: add_misfortune(gs, owner, src, 1, owner)
		if not gs.VerifiedRules.Light.roll(gs, owner, 5 if u.awakened else 4, 6, src):
			wrong = true
			add_misfortune(gs, owner, src, 1, owner)
	if old > 0 and not gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src): wrong = true
	if wrong:
		frame.targetId = wrong_enemy(gs, owner, frame.options, frame.targetId)
		frame.options.pursuit = not str(frame.targetId).begins_with("avatar-")
		frame.options.directAvatar = str(frame.targetId).begins_with("avatar-")
		gs.VerifiedRules.event(gs, "cosmos-wrong-target", {"player":owner,"uid":u.uid,"target":frame.targetId})

static func counter(gs, frame: Dictionary, card: Dictionary) -> bool:
	if not Content.is_spell(card) or card.get("poorCopyUsed", false) or frame.targetId == null: return false
	var enemy := int(frame.playerIndex)
	var owner := 1-enemy
	var src := Flow.active(gs, owner, POOR)
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	if not u.get("formRules", {}).get("poorCopy", false) or str(frame.targetId) != str(u.uid): return false
	if not gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src): return false
	var rid := int(frame.resolutionId)
	if not gs.resolution_stack.any(func(f): return int(f.get("resolutionId",-1)) == rid and f.get("kind") == "card-effect"): return false
	gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId",-1)) != rid)
	gs.VerifiedRules.Insight.used(gs, enemy, card, card.get("playedInstance",{}), false)
	gs.VerifiedRules.event(gs, "card-nullified", {"player":enemy,"card":card,"resolutionId":rid})
	var copied := card.duplicate(true)
	copied.usedFromHand = false
	copied.poorCopyUsed = true
	copied.erase("playedInstance")
	var possible: Array = gs.valid_targets(owner, copied)
	possible.erase(frame.targetId)
	var targets := Choice.sample(gs, possible, 1)
	if not targets.is_empty(): gs._push_card_frames(owner, copied.id, targets[0], copied, src, 0, true)
	return true

static func misfortune_assault(gs, owner: int, src: int, card: Dictionary) -> void:
	var out := card.duplicate(true)
	if "swift-card" in out.keywords: gs.player(owner).units[src].swift = true
	if "veil" in out.keywords: gs.player(owner).units[src].movementVeil = true
	if "direct" in out.keywords: out.combatOption.directAvatar = true
	Flow.assault(gs, owner, src, out)

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	match effect.action:
		"zen-1":
			var amount := 2
			if str(target_id).begins_with("avatar-"):
				var p: Dictionary = gs.player(owner)
				var excess := maxi(0, int(p.avatarHp) + amount - int(p.maxAvatarHp))
				gs._heal_avatar(owner, amount)
				gs._grant_avatar_armor(owner, excess)
			elif not target.is_empty():
				var excess := maxi(0, int(target.hp) + amount - int(target.maxHp))
				gs._heal_unit(target, amount)
				gs._grant_unit_armor(target, excess)
			Flow.assault(gs, owner, src, card)
		"zen-2":
			if not target.is_empty():
				attach_blessing(gs, owner, target)
				gs.VerifiedRules.Glutton.record_permanent(target, 1, 2)
				gs._grow_unit(target, 1, 2)
		"zen-3":
			gs._awaken(owner, src, card, {"attack":0,"hp":0})
			Flow.assault(gs, owner, src, card)
		"zen-4":
			gs._apply_form(owner, src, card, effect.value)
			u.barrier = true
			mirror_turn(gs, owner, src)
		"zen-5":
			for ally in Choice.live_units(gs, owner):
				var excess := maxi(0, int(ally.hp)+4-int(ally.maxHp)) if not ally.get("toxicPoisoned", false) else 0
				gs._heal_unit(ally, 4)
				attach_blessing(gs, owner, ally)
				if excess > 0:
					ally.swift = true
					gs.VerifiedRules.HairPower.give(gs, owner, gs._unit_index_by_uid(owner, ally.uid), excess)
		"zen-6":
			Flow.all_damage(gs, owner, src, 2, false)
			for ally in Choice.live_units(gs, owner): gs._heal_unit(ally, 2)
			Flow.assault(gs, owner, src, card)
		"zen-7":
			gs._deploy_realm(owner, card)
			for ally in Choice.live_units(gs, owner): attach_blessing(gs, owner, ally)
		"zen-8":
			origins(gs, owner, 2)
			gs._draw(owner, 1)
		"misfortune-1": transfer_all(gs, owner, src)
		"misfortune-draw":
			add_misfortune(gs, owner, src, 1, owner)
			gs._draw(owner, 1)
		"misfortune-2", "misfortune-4": gs._apply_form(owner, src, card, effect.value)
		"misfortune-3", "misfortune-8": misfortune_assault(gs, owner, src, card)
		"misfortune-5":
			gs._awaken(owner, src, card, {"attack":0,"hp":0})
			misfortune_assault(gs, owner, src, card)
		"misfortune-6": gs._deploy_realm(owner, card)
		"misfortune-7":
			gs.resolution_stack.append({"kind":"cosmos-poor-gather","playerIndex":owner,"sourceIndex":src})
			var allies := Choice.live_units(gs, owner)
			allies.reverse()
			for ally in allies:
				if ally.uid != u.uid:
					gs.resolution_stack.append({"kind":"cosmos-poor-ally","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner, ally.uid)})
		_: return false
	return true

static func mode(card: Dictionary, option: String) -> Dictionary:
	if card.get("id") != "c65701" or option != "misfortune-draw": return {}
	var out := card.duplicate(true)
	out.keywords.append("instant")
	out.effect = option
	out.effects[0].action = option
	out.nativePlayModeLabel = "结附不幸 · 抽一张牌"
	return out

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	var src := int(frame.get("sourceIndex", -1))
	match frame.get("kind", ""):
		"cosmos-poor-attack": Choice.attack(gs, owner, src)
		"cosmos-poor-gather": transfer_all(gs, owner, src)
		"cosmos-poor-ally":
			add_misfortune(gs, owner, src, 1, owner)
			var u: Dictionary = gs.player(owner).units[src]
			if gs.VerifiedRules.Samurai.available(u) and not u.get("cannotAttack", false) and gs.VerifiedRules.Langya.can_front(u):
				gs._grant_unit_armor(u, 2)
				gs.VerifiedRules.HairPower.give(gs, owner, src, 2)
				Choice.attack(gs, owner, src)
		_: return false
	return true

static func source_for_link(gs, owner: int) -> int:
	return Flow.source(gs, owner, ZEN)

static func sample_links(gs, owner: int, src: int, pool: Array) -> Array:
	return Choice.sample(gs, pool, 2 if gs.player(owner).units[src].awakened else 1)
