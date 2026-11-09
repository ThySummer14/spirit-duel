extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choices := preload("res://scripts/restored_card_choices.gd")
const PEACOCK := "kongquemingwang"
const SEASON := "ji"
const INK := "panguan-xuanmo"
const QUILL := "peacock-quill"
const QUILL_IDS := [QUILL, "kongqueling"]
const SNOW := "season-snowman"

static func index(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})

static func active(gs, owner: int, id: String) -> int:
	var src := index(gs, owner, id)
	return src if src >= 0 and gs.VerifiedRules.HairPower.active(gs.player(owner).units[src]) else -1

static func form(gs, owner: int, id: String, key: String) -> bool:
	var src := active(gs, owner, id)
	return src >= 0 and gs.player(owner).units[src].get("formRules", {}).get(key, false)

static func realms(gs, owner: int, key: String) -> Array:
	return gs.player(owner).realms.filter(func(r): return r.get("nativeRealm") == key and int(r.hp) > 0)

static func foe_living(gs, owner: int) -> Array:
	return gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func put_hand(gs, owner: int, id: String) -> void:
	gs.VerifiedRules.Baize.put_hand(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, id))

static func attack(gs, owner: int, src: int, target_id = null, options: Dictionary = {}) -> void:
	if src < 0 or int(gs.player(owner).units[src].hp) <= 0 or gs.VerifiedRules.Stun.blocks(gs, owner, gs.player(owner).units[src]): return
	gs._resolve_combat(owner, src, 0, false, false, false, false, target_id, false, options)

static func choose_from(gs, pool: Array):
	return pool[int(gs.next_random() % pool.size())]

static func quills(gs, owner: int, count: int) -> void:
	for _i in maxi(0, count):
		var hand: Array = gs.player(owner).hand
		var slot := hand.find_custom(func(inst): return inst.definitionId in QUILL_IDS and int(inst.get("quillStacks", 1)) < 3)
		if slot >= 0:
			hand[slot].quillStacks = int(hand[slot].get("quillStacks", 1))+1
		else:
			put_hand(gs, owner, QUILL)

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.get("id") == "c60108" and targets(gs, owner, card).is_empty():
		var view := card.duplicate(true)
		view.target = "auto"
		return view
	if card.has("nativeOrigin"):
		var original := Content.card_def(str(card.nativeOrigin)).duplicate(true)
		original.unitId = card.unitId
		var view := card.duplicate(true)
		view.originCard = original
		return view
	if card.id in QUILL_IDS:
		var view := card.duplicate(true)
		view.quillStacks = int(inst.get("quillStacks", 1))
		view.currentCardStats = "孔雀翎 · 堆叠%d／3" % view.quillStacks
		return view
	if not card.get("peacockRules", false) and not card.get("seasonRules", false) and not card.get("inkjudgeRules", false): return card
	var src := index(gs, owner, card.unitId)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	var out := card.duplicate(true)
	if u.awakened and card.unitId == SEASON and card.type == "form":
		if "instant" not in out.keywords: out.keywords.append("instant")
	if int(u.level) >= 1 and int(u.level) < int(card.level) and card.id in ["c60405", "c60506", "c60507", "c60508", "c60107"]:
		out.level = 1
		out.trick = true
		out.awakeningCard = false
		if out.id == "c60107": out.target = "peacock-foe-realm"
		if out.id == "c60506": out.target = "auto"
		if out.id == "c60507":
			out.target = "enemy-unit"
			out.keywords.append("pursuit")
			out.combatOption.pursuit = true
		out.currentCardStats = "戏法"
	return out

static func targets(gs, owner: int, card: Dictionary):
	match card.get("id"):
		"c60104":
			return Choices.live_units(gs, owner).map(func(u): return u.uid)
		"c60506":
			if not card.get("trick", false):
				return foe_living(gs, owner).filter(func(u): return not (gs.VerifiedRules.Combat.has(u, "veil") or gs.VerifiedRules.Movement.has_veil(u))).map(func(u): return u.uid)
		"c60507":
			if card.get("trick", false):
				var pursuit_targets := foe_living(gs, owner).map(func(u): return u.uid)
				if gs.front_index(1-owner) < 0: pursuit_targets.append("avatar-%d" % (1-owner))
				return pursuit_targets
	match card.get("target"):
		"peacock-marked":
			return foe_living(gs, owner).filter(func(u): return int(u.armorBreak) > 0 and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return u.uid)
		"peacock-foe-realm":
			if gs.VerifiedRules.ArmorBlood.realm_veil(gs, 1-owner): return []
			return gs.player(1-owner).realms.filter(func(r): return int(r.hp) > 0).map(func(r): return r.uid)
		"inkjudge-revive":
			return gs.player(owner).units.filter(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)).map(func(u): return u.uid)
	return null

static func turn_start(gs, owner: int) -> void:
	var src := active(gs, owner, PEACOCK)
	if src >= 0:
		var u: Dictionary = gs.player(owner).units[src]
		quills(gs, owner, int(u.attack) if u.awakened else 1)
	var other := 1-owner
	src = active(gs, other, SEASON)
	if src < 0 or int(gs.player(other).energy) <= 0: return
	var season: Dictionary = gs.player(other).units[src]
	if season.get("seasonAutoUsed", false) and not season.awakened: return
	if cast_season(gs, other, src, 0, true):
		season.seasonAutoUsed = true

static func turn_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") == "peacock-mist":
		quills(gs, owner, 2)
		return true
	return str(realm.get("nativeRealm", "")).begins_with("inkjudge-") or realm.get("nativeRealm") == "season-sky"

static func armor_acquired(gs, victim: int, idx: int) -> void:
	if idx < 0: return
	var owner := 1-victim
	var u: Dictionary = gs.player(victim).units[idx]
	if gs.current_player != owner or int(u.front) != 1 or int(u.armorBreak) < 3 or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	var src := active(gs, owner, PEACOCK)
	if src < 0: return
	var bird: Dictionary = gs.player(owner).units[src]
	if not bird.get("formRules", {}).get("peacockDance", false) or int(bird.get("peacockDanceTurn", -1)) == gs.turn_counter: return
	bird.peacockDanceTurn = gs.turn_counter
	gs.resolution_stack.append({"kind":"dusk-attack","playerIndex":owner,"sourceIndex":src,"options":{"immuneCombat":true}})

static func mist_power(gs, u: Dictionary) -> int:
	if int(u.get("armorBreak", 0)) <= 0: return 0
	for owner in gs.players.size():
		if gs.player(owner).units.has(u):
			return int(u.armorBreak) * realms(gs, 1-owner, "peacock-mist").size()
	return 0

static func refresh_mist(gs, owner: int) -> void:
	for u in gs.player(1-owner).units:
		if int(u.get("armorBreak", 0)) > 0: gs._recalc(u)

static func before_ready(gs, frame: Dictionary) -> bool:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if u.id != PEACOCK or u.awakened or int(u.level) < 3 or frame.get("peacockOffered", false): return false
	var victim := int(frame.options.get("combatVictim", 1-owner))
	var idx: int = gs.front_index(victim)
	if frame.options.get("directAvatar", false): return false
	if frame.options.get("pursuit", false) or frame.options.get("reserveTarget", false):
		idx = gs._unit_index_by_uid(victim, frame.targetId)
	if idx < 0 or int(gs.player(victim).units[idx].armorBreak) < 3: return false
	var inst := take_named(gs, owner, "c60508")
	if inst.is_empty(): return false
	frame.peacockOffered = true
	frame.kind = "river-combat-ready"
	gs.resolution_stack.append(frame)
	cast(gs, owner, src, inst)
	return true

static func take_named(gs, owner: int, id: String) -> Dictionary:
	for zone in [gs.player(owner).hand, gs.player(owner).deck]:
		var idx: int = zone.find_custom(func(c): return c.definitionId == id)
		if idx >= 0: return zone.pop_at(idx)
	return {}

static func cast(gs, owner: int, src: int, inst: Dictionary) -> void:
	var card := Content.card_def(str(inst.definitionId)).duplicate(true)
	card.playedInstance = inst
	gs._push_card_frames(owner, str(card.id), null, card, src, 0, true)

static func season_num(id: String) -> int:
	return int(id.right(1)) if id in ["c60401","c60402","c60403","c60404"] else 0

static func cast_season(gs, owner: int, src: int, requested: int = 0, next_first: bool = false) -> bool:
	if not gs.VerifiedRules.HairPower.active(gs.player(owner).units[src]): return false
	var deck: Array = gs.player(owner).deck
	var choices := deck.filter(func(c): return season_num(str(c.definitionId)) > 0)
	var chosen: Dictionary = {}
	if requested > 0:
		var pos := choices.find_custom(func(c): return season_num(str(c.definitionId)) == requested)
		if pos >= 0: chosen = choices[pos]
	elif next_first:
		var current := int(gs.player(owner).units[src].get("formRules", {}).get("season", 0))
		if current > 0:
			var next := current % 4 + 1
			var pos := choices.find_custom(func(c): return season_num(str(c.definitionId)) == next)
			if pos >= 0: chosen = choices[pos]
	if chosen.is_empty():
		if choices.is_empty() or requested > 0: return false
		chosen = choose_from(gs, choices)
	deck.erase(chosen)
	cast(gs, owner, src, chosen)
	return true

static func mix_seasons(gs, owner: int) -> void:
	var deck: Array = gs.player(owner).deck
	for i in range(1,5):
		deck.append(gs.VerifiedRules.Insight.instance(gs, owner, "c6040%d" % i))
	gs._shuffle(deck)

static func season_enter(gs, owner: int, src: int, card: Dictionary) -> void:
	var n := season_num(str(card.id))
	if n <= 0: return
	var u: Dictionary = gs.player(owner).units[src]
	var prior := season_departures(gs, owner, n)
	var front: int = gs.front_index(owner)
	match n:
		1:
			gs._heal_avatar(owner, 2+prior)
			if front >= 0: gs._heal_unit(gs.player(owner).units[front], 2+prior)
		2: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2+prior, card.name)
		3:
			var pool := foe_living(gs, owner).filter(func(v): return int(v.front) == 0)
			if not pool.is_empty():
				var target: Dictionary = choose_from(gs, pool)
				gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, target.uid), maxi(0,int(u.attack)), owner, src)
		4:
			var existing: Dictionary = gs.front_unit(owner)
			var value := 1+prior
			if existing.get("id") == SNOW:
				gs._grow_unit(existing, value, value)
				var idx: int = gs.front_index(owner)
				gs.VerifiedRules.HairPower.give(gs, owner, idx, 1)
				gs._grant_unit_armor(existing, 2)
			else:
				gs.VerifiedRules.NativeSummons.summon(gs, owner, src, SNOW, "雪人", value, value)

static func season_departures(gs, owner: int, n: int) -> int:
	return int(gs.player(owner).get("seasonLeft", {}).get(str(n), 0))

static func form_removed(gs, owner: int, src: int, old_form: Dictionary, already_moved: bool) -> void:
	var n := season_num(str(old_form.get("cardId", "")))
	if n <= 0: return
	gs.resolution_stack.append({"kind":"dusk-season-leave","playerIndex":owner,"sourceIndex":src,"season":n,"cardInstance":old_form.get("cardInstance", {}).duplicate(true),"alreadyMoved":already_moved})

static func season_leave(gs, owner: int, src: int, n: int, inst: Dictionary, already_moved: bool) -> void:
	var p: Dictionary = gs.player(owner)
	var prior := season_departures(gs, owner, n)
	if not p.has("seasonLeft"): p.seasonLeft = {}
	p.seasonLeft[str(n)] = prior+1
	if not already_moved and not realms(gs, owner, "season-sky").is_empty():
		p.deck.append(inst if not inst.is_empty() else gs.VerifiedRules.Insight.instance(gs, owner, "c6040%d" % n))
		gs._shuffle(p.deck)
	match n:
		1:
			var front: int = gs.front_index(1-owner)
			if front >= 0: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, 1-owner, front, 2+prior)
		2:
			for u in p.units:
				if not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u): gs._grow_unit(u, 1, 0)
		3: gs._apply_encourage(owner, 0, 1+prior, 1+prior)
		4:
			var context: Dictionary = gs._card_effect_context
			gs._card_effect_context = {}
			gs._damage_avatar(1-owner, 2, owner, src)
			gs._card_effect_context = context

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	if season_num(str(card.id)) <= 0: return
	var p: Dictionary = gs.player(owner)
	if not p.has("seasonUses"): p.seasonUses = {}
	if int(p.seasonUses.get(card.id, -1)) == gs.turn_counter: return
	p.seasonUses[card.id] = gs.turn_counter
	if frame.get("usedFromHand", false) and not realms(gs, owner, "season-sky").is_empty():
		gs.resolution_stack.append({"kind":"dusk-season-gain","playerIndex":owner})

static func ink_knockout_extra(gs, owner: int) -> int:
	return -1 if form(gs, owner, INK, "inkjudgeShort") else 0

static func knockout(gs, victim: int, unit: Dictionary, prior_hp: int) -> void:
	if victim < 0 or not gs.VerifiedRules.OwlInsect.shikigami(unit): return
	var owner := 1-victim
	var src := active(gs, owner, INK)
	if src >= 0:
		gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 2 if gs.player(owner).units[src].awakened else 1)
	for realm in realms(gs, owner, "inkjudge-shore"):
		if prior_hp > 0: gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, prior_hp)
	for side in 2:
		src = active(gs, side, INK)
		if src < 0: continue
		var judge: Dictionary = gs.player(side).units[src]
		if judge.get("form", {}).get("cardId") == "c60102" and judge.has("formCountdown"):
			gs.VerifiedRules.reduce_countdown(gs, side, src, 1)
		if side == victim and judge.awakened:
			gs.resolution_stack.append({"kind":"dusk-ink-retaliate","playerIndex":side,"sourceIndex":src})

static func revived(gs, owner: int) -> void:
	for realm in realms(gs, owner, "inkjudge-edge"):
		if int(realm.get("inkjudgeRevivedTurn", -1)) == gs.turn_counter: continue
		realm.inkjudgeRevivedTurn = gs.turn_counter
		gs.resolution_stack.append({"kind":"dusk-ink-destroy","playerIndex":owner,"sourceIndex":index(gs, owner, INK)})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.action)
	if not action.begins_with("peacock-") and not action.begins_with("season-") and not action.begins_with("inkjudge-"): return false
	var u: Dictionary = gs.player(owner).units[src]
	match action:
		"peacock-quill":
			var side := owner
			var idx: int = gs._unit_index_by_uid(owner, target_id)
			if str(target_id) == "avatar-%d" % (1-owner) or (idx < 0 and not target.is_empty()):
				side = 1-owner
				idx = gs._unit_index_by_uid(side, target_id)
			gs.VerifiedRules.ArmorBreak.give(gs, owner, src, side, idx, int(card.get("quillStacks", 1)))
		"peacock-1":
			quills(gs, owner, 3)
			gs._draw(owner, 1)
		"peacock-2", "peacock-5", "inkjudge-2", "inkjudge-5", "season-1", "season-2", "season-3", "season-4":
			gs._apply_form(owner, src, card, effect.value)
			if action == "peacock-2": u.swift = true
		"peacock-3":
			if int(u.hp) <= 0: gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
			quills(gs, owner, 3)
		"peacock-4":
			gs._deploy_realm(owner, card)
			refresh_mist(gs, owner)
			quills(gs, owner, 2)
		"peacock-6", "peacock-7":
			var follow = target_id if action == "peacock-7" and not card.get("trick", false) else null
			var options: Dictionary = card.combatOption.duplicate(true)
			var initial_target = target_id if action == "peacock-7" and card.get("trick", false) else null
			if follow != null: options.peacockFollow = follow
			if initial_target != null: options.pursuit = true
			if action == "peacock-7" and not card.get("trick", false): u.barrier = true
			gs.resolution_stack.append({"kind":"dusk-assault","playerIndex":owner,"sourceIndex":src,"card":card,"options":options,"targetId":initial_target,"bonus":int(effect.value)})
			if action == "peacock-6" and not card.get("trick", false) and not target.is_empty() and int(target.hp) > 0:
				gs._grow_unit(target, -3, 0)
				gs.VerifiedRules.ArmorBreak.give(gs, owner, src, 1-owner, gs._unit_index_by_uid(1-owner, target.uid), 3)
		"peacock-8":
			if card.get("trick", false):
				gs._grow_unit(u, 1, 0)
				var inst: Dictionary = card.get("playedInstance", {})
				gs.player(owner).deck.append(inst if not inst.is_empty() else gs.VerifiedRules.Insight.instance(gs, owner, card.id))
				gs._shuffle(gs.player(owner).deck)
			else: gs._awaken(owner, src, card, effect.value)
		"season-5":
			if card.get("trick", false):
				mix_seasons(gs, owner)
				gs._draw(owner, 1)
			else:
				for n in [4,3,2,1]: gs.resolution_stack.append({"kind":"dusk-season-cast","playerIndex":owner,"sourceIndex":src,"season":n})
		"season-6":
			gs._resolve_action(owner, src, card, {"action":"assault","value":effect.value}, null, {})
		"season-7": gs._deploy_realm(owner, card)
		"season-8":
			mix_seasons(gs, owner)
			var deck: Array = gs.player(owner).deck
			var choices := deck.filter(func(c): return Content.card_def(str(c.definitionId)).get("type") == "form")
			if not choices.is_empty():
				var inst: Dictionary = choose_from(gs, choices)
				deck.erase(inst)
				gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
			gs._awaken(owner, src, card, effect.value)
		"inkjudge-1":
			if target.is_empty(): return true
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target.uid)
				if idx < 0: continue
				var price := int(target.hp)+int(target.attack)
				if gs.VerifiedRules.Panguan.destroy(gs, owner, src, side, idx, card): gs._damage_avatar(owner, maxi(0,price), owner, src)
				break
		"inkjudge-3":
			gs._deploy_realm(owner, card)
			gs._draw(owner, 1)
		"inkjudge-4":
			attack(gs, owner, gs._unit_index_by_uid(owner, target_id), null, {"lethal":true})
		"inkjudge-6": gs._awaken(owner, src, card, effect.value)
		"inkjudge-7":
			for side in 2:
				for realm in gs.player(side).realms.duplicate():
					if not card.get("trick", false) or side == 1-owner and realm.uid == target_id:
						gs.VerifiedRules.Huang.destroy(gs, side, realm, card.name)
		"inkjudge-8":
			gs._deploy_realm(owner, card)
			if not target.is_empty(): gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("dusk-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex", -1))
	match kind:
		"dusk-attack": attack(gs, owner, src, frame.get("targetId"), frame.get("options", {}))
		"dusk-assault":
			if not gs.VerifiedRules.Samurai.available(gs.player(owner).units[src]): return true
			var options: Dictionary = frame.options
			options.combatCard = frame.card
			gs._grant_unit_armor(gs.player(owner).units[src], int(options.get("shield", 0)))
			gs._resolve_combat(owner, src, int(frame.bonus), false, false, false, false, frame.targetId, false, options)
		"dusk-season-cast": cast_season(gs, owner, src, int(frame.season))
		"dusk-season-leave": season_leave(gs, owner, src, int(frame.season), frame.cardInstance, bool(frame.alreadyMoved))
		"dusk-season-gain":
			gs._set_fire(owner, int(gs.player(owner).energy)+1)
			gs._draw(owner, 1)
		"dusk-ink-retaliate", "dusk-ink-destroy":
			var pool := foe_living(gs, owner)
			if not pool.is_empty():
				var idx: int = gs._unit_index_by_uid(1-owner, choose_from(gs, pool).uid)
				if kind == "dusk-ink-destroy": gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1-owner, idx)
				else: gs.VerifiedRules.base_damage_unit(gs, owner, src, 1-owner, idx, 2)
		_: return false
	return true

static func combat_finished(gs, owner: int, src: int, options: Dictionary, kills: int) -> void:
	if options.get("seasonKill", false) and kills > 0: cast_season(gs, owner, src)
	if options.has("peacockFollow"):
		var target: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, options.peacockFollow)
		if not target.is_empty() and int(target.hp) > 0:
			gs.resolution_stack.append({"kind":"dusk-attack","playerIndex":owner,"sourceIndex":src,"targetId":target.uid,"options":{"pursuit":true}})
