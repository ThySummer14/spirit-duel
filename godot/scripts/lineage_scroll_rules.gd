extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const CAT := "maochuan"
const POET := "youning"
const PRICES := ["maochuan-cooperate", "maochuan-advance", "maochuan-invest", "maochuan-contract", "maochuan-inflate", "maochuan-monopoly"]
const POEM := "youning-six-meanings"
const VERSES := {
	"fire": ["节火", "本回合下一张牌不消耗鬼火。"],
	"all": ["群响", "对所有敌方角色造成2点伤害。"],
	"front": ["破阵", "对敌方战斗区式神造成5点伤害。"],
	"realm": ["破境", "消灭敌方耐久最高的幻境。"],
	"draw": ["新篇", "抽两张牌。"],
}

static func source(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})

static func living(gs, owner: int, id: String) -> Dictionary:
	var src := source(gs, owner, id)
	if src < 0: return {}
	var u: Dictionary = gs.player(owner).units[src]
	return u if gs.VerifiedRules.OwlInsect.active(u) else {}

static func fresh(gs, owner: int, card: Dictionary) -> bool:
	return str(card.get("name", "")) not in gs.player(owner).get("initialDeckNames", [])

static func history(gs, owner: int, name: String) -> bool:
	return name in gs.player(owner).get("lineageHandUsed", [])

static func reversed_prices(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == "lineage-river")

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var out := card
	if inst.get("poetGenerated", false):
		out = out.duplicate(true)
		out.poetGenerated = true
	if card.get("id") == "c63907":
		var cat := source(gs, owner, CAT)
		if cat >= 0 and int(gs.player(owner).units[cat].level) < 3: out = Content.card_def(PRICES[5])
	if out.get("catPrice", false):
		out = out.duplicate(true)
		out.priceOwner = 1-owner if reversed_prices(gs, owner) else owner
		out.allowKnockedSource = out.priceOwner != owner
		if out.priceOwner != owner: out.currentCardStats = "猫川长河 · 效果改为敌方"
	if inst.get("poetFreeTurn", -1) == gs.turn_counter:
		out = out.duplicate(true)
		out.poetFree = true
		out.cost = 0
	if out.get("id") == "c64005" and fresh(gs, owner, out):
		out = out.duplicate(true)
		out.value = 7
		out.effects[0].value = 7
		out.currentCardStats = "牌名不在初始牌库 · 7点伤害"
	return out

static func targets(gs, owner: int, card: Dictionary):
	var action := str(card.get("effect", ""))
	if action == "lineage-price" and int(card.get("value", -1)) in [0, 2, 3, 4]:
		var side := int(card.get("priceOwner", owner))
		return Choice.live_units(gs, side).filter(func(u):
			return (int(card.value) != 3 or u.awakened) and (side == owner or not gs.VerifiedRules.Combat.has(u, "veil"))
		).map(func(u): return str(u.uid))
	if action in ["lineage-invest", "poet-transform", "poet-combat"]:
		var src := source(gs, owner, POET)
		return Choice.live_units(gs, owner).filter(func(u):
			if action == "lineage-invest": return int(u.get("lineageAttackedTurn", -1)) != gs.turn_counter
			return action != "poet-transform" or u != gs.player(owner).units[src]
		).map(func(u): return str(u.uid))
	return null

static func made_attack(gs, owner: int, src: int) -> void:
	gs.player(owner).units[src].lineageAttackedTurn = gs.turn_counter

static func announce(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	if not frame.get("automatic", false) and p.get("poetNextFreeTurn", -1) == gs.turn_counter:
		p.erase("poetNextFreeTurn")
	if int(frame.sourceIndex) < 0 or not frame.get("usedFromHand", false) or card.get("poetReplay", false): return
	var first := not history(gs, owner, str(card.name))
	if first:
		if not p.has("lineageHandUsed"): p.lineageHandUsed = []
		p.lineageHandUsed.append(str(card.name))
		var cat := living(gs, owner, CAT)
		if not cat.is_empty():
			var src := source(gs, owner, CAT)
			if cat.awakened or int(frame.sourceIndex) == src:
				gs.resolution_stack.append({"kind": "lineage-shot", "playerIndex": owner, "sourceIndex": src, "amount": 1+int(cat.get("catContract", false))})
			if cat.get("formRules", {}).get("lineageMerchant", false) and fresh(gs, owner, card):
				gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": owner, "count": 1})
	if card.get("catPrice", false):
		if not p.has("lineagePrices"): p.lineagePrices = []
		if card.id not in p.lineagePrices: p.lineagePrices.append(card.id)
	var poet := living(gs, owner, POET)
	if poet.is_empty() or (not poet.awakened and not fresh(gs, owner, card)): return
	if int(poet.get("poetEffectTurn", -1)) != gs.turn_counter:
		poet.poetEffectTurn = gs.turn_counter
		poet.poetEffects = []
	var unused: Array = ([0, 1, 2, 3] if poet.awakened else [0, 1]).filter(func(i): return i not in poet.poetEffects)
	var picked := Choice.sample(gs, unused, 2 if poet.awakened and fresh(gs, owner, card) else 1)
	for mode in picked:
		poet.poetEffects.append(mode)
		gs.resolution_stack.append({"kind": "poet-trigger", "playerIndex": owner, "sourceIndex": source(gs, owner, POET),
			"mode": mode, "amount": 3 if poet.awakened else 1})

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	if not frame.get("usedFromHand", false) or card.get("poetReplay", false): return
	var owner := int(frame.playerIndex)
	var poet := living(gs, owner, POET)
	if poet.is_empty() or not poet.get("formRules", {}).get("poetClassic", false) or not fresh(gs, owner, card): return
	var copy_spell: bool = Content.is_spell(card) and not card.get("awakeningCard", false) and card.get("poetGenerated", false)
	var key := "poetCopyTurn" if copy_spell else "poetDrawTurn"
	if int(poet.get(key, -1)) == gs.turn_counter: return
	poet[key] = gs.turn_counter
	if copy_spell:
		var copy := card.duplicate(true)
		copy.poetReplay = true
		copy.usedFromHand = false
		copy.erase("playedInstance")
		gs._push_card_frames(owner, str(card.id), frame.targetId, copy, int(frame.sourceIndex), 0, true)
	else: gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": owner, "count": 1})

static func pool(gs, owner: int, id: String, typ: String = "", level: int = -1, at_most: bool = false) -> Array:
	return Content.cards_for_unit(id).filter(func(c):
		if c.get("token", false) or int(c.get("deckLimit", 2)) == 0 or not fresh(gs, owner, c): return false
		if not typ.is_empty() and c.type != typ: return false
		return level < 0 or int(c.level) == level or at_most and int(c.level) < level
	).map(func(c): return str(c.id))

static func add_poem_card(gs, owner: int, id: String, fields: Dictionary = {}) -> void:
	var mark := {"poetGenerated": true}
	mark.merge(fields)
	Choice.give(gs, owner, id, mark)

static func upgraded(gs, owner: int, idx: int) -> void:
	var poet := living(gs, owner, POET)
	if poet.is_empty() or not poet.get("formRules", {}).get("poetThought", false) or int(poet.get("poetUpgradeTurn", -1)) == gs.turn_counter: return
	var u: Dictionary = gs.player(owner).units[idx]
	var picked := Choice.sample(gs, pool(gs, owner, str(u.id), "", int(u.level)), 1)
	if not picked.is_empty():
		poet.poetUpgradeTurn = gs.turn_counter
		add_poem_card(gs, owner, picked[0], {"poetDiscardTurn": gs.turn_counter})

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner, CAT)
	if src < 0: return
	var side := 1-owner if reversed_prices(gs, owner) else owner
	for inst in gs.player(owner).hand.duplicate():
		if inst.definitionId == PRICES[3]:
			for u in Choice.live_units(gs, side): gs.VerifiedRules.HairPower.give(gs, side, gs._unit_index_by_uid(side, u.uid), -1)

static func end_turn(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	for i in range(p.hand.size()-1, -1, -1):
		if p.hand[i].get("poetDiscardTurn", -1) == gs.turn_counter: gs.discard_hand_card(owner, i)
	var src := source(gs, owner, CAT)
	if src < 0: return
	var side := 1-owner if reversed_prices(gs, owner) else owner
	for inst in p.hand.duplicate():
		if gs.winner >= 0: break
		var mode := PRICES.find(str(inst.definitionId))
		if inst.definitionId == "c63907" and int(p.units[src].level) < 3: mode = 5
		match mode:
			0:
				var units := Choice.sample(gs, Choice.live_units(gs, side), 1)
				if not units.is_empty(): gs._damage_unit(side, gs._unit_index_by_uid(side, units[0].uid), 2, owner, src)
			1:
				for i in mini(2, gs.player(side).deck.size()): gs.player(side).deck.pop_back()
			2: gs._damage_avatar(side, 4, owner, src)
			4:
				var cue: Dictionary = gs.kw_usage(side, "encourage")
				cue.battlePower = int(cue.get("battlePower", 0))-2
				gs.VerifiedRules.ArmorBreak.give(gs, owner, src, side, -1, 2, false)
			5: gs._damage_avatar(side, 1, owner, src)

static func price(gs, owner: int, src: int, card: Dictionary, target: Dictionary) -> void:
	var side := int(card.get("priceOwner", owner))
	var idx: int = gs._unit_index_by_uid(side, target.get("uid"))
	match int(card.value):
		0:
			if idx >= 0: gs._damage_unit(side, idx, 4, owner, src)
		1:
			var hand: Array = gs.player(side).hand
			if not hand.is_empty(): gs.discard_hand_card(side, int(gs.next_random() % hand.size()))
		2:
			if idx >= 0: gs.VerifiedRules.Stun.apply(gs, side, idx, 1, owner)
		3:
			if idx >= 0:
				target.awakened = false
				target.passive_hooks = Content.runtime_unit_def(target).get("passive", {}).get("hooks", []).duplicate(true)
				target.erase("catContract")
		4:
			if idx >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, side, idx, card)
		5:
			gs._damage_avatar(side, 3, owner, src)
			if gs.winner >= 0: return
			var inst: Dictionary = gs.VerifiedRules.Yi.clean_instance(card.get("playedInstance", {}))
			if not inst.is_empty():
				gs.resolution_stack.append({"kind": "lineage-reshuffle", "playerIndex": owner, "instance": inst})
			gs._draw(side, 1)

static func substitute(gs, owner: int, uid: String, replacement: String) -> void:
	var p: Dictionary = gs.player(owner)
	var idx: int = gs._unit_index_by_uid(owner, uid)
	if idx < 0: return
	var old: Dictionary = p.units[idx]
	var card_pool: Array = Content.cards_for_unit(replacement).filter(func(c): return not c.get("token", false) and int(c.get("deckLimit", 2)) > 0)
	if card_pool.is_empty(): return
	gs.VerifiedRules.Forms.remove(gs, owner, idx, "捷思奏雅")
	var next: Dictionary = gs._make_unit(p.id, replacement)
	next.uid = uid
	next.level = old.level
	next.front = old.front
	p.units[idx] = next
	for zone in [p.hand, p.deck, gs.VerifiedRules.Insight.zone(gs, owner)]:
		for i in zone.size():
			if Content.card_def(str(zone[i].definitionId)).get("unitId") != old.id: continue
			zone[i] = {"instanceId": zone[i].instanceId, "definitionId": card_pool[int(gs.next_random() % card_pool.size())].id, "poetGenerated": true}
	var eligible: Array = p.deck.filter(func(inst): return Content.card_def(str(inst.definitionId)).get("unitId") == replacement)
	var picked := Choice.sample(gs, eligible, 1)
	if not picked.is_empty():
		p.deck.erase(picked[0])
		p.deck.append(picked[0])
		gs._draw(owner, 1)
	gs.VerifiedRules.event(gs, "poet-unit-replaced", {"player": owner, "uid": uid, "from": old.id, "to": replacement})

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if src < 0 or not (action.begins_with("lineage-") or action.begins_with("poet-")): return false
	var u: Dictionary = gs.player(owner).units[src]
	match action:
		"lineage-combat":
			Choice.give(gs, owner, PRICES[int(effect.value)])
			var combat := card.duplicate(true)
			if int(effect.value) == 4: combat.combatOption.lineageFrontCombo = true
			gs._resolve_action(owner, src, combat, {"action": "assault", "value": int(card.get("attackBonus", 0))}, target_id, target)
		"lineage-merchant", "poet-form": gs._apply_form(owner, src, card, effect.value)
		"lineage-advance":
			gs.resolution_stack.append({"kind": "lineage-price-give", "playerIndex": owner, "index": 1})
			gs._draw(owner, 2)
		"lineage-invest":
			gs.resolution_stack.append({"kind": "lineage-price-give", "playerIndex": owner, "index": 2})
			Choice.attack(gs, owner, gs._unit_index_by_uid(owner, target_id))
		"lineage-awake":
			if not u.awakened:
				gs._awaken(owner, src, card, effect.value)
				Choice.offer(gs, owner, "lineage-contract", ["contract", "ordinary"], "觉醒·猫川", {"sourceIndex": src})
		"lineage-monopoly":
			gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, target_id), 6, owner, src)
			gs._damage_avatar(1-owner, 6, owner, src)
		"lineage-river":
			gs._deploy_realm(owner, card)
			for id in gs.player(owner).get("lineagePrices", []): Choice.give(gs, owner, id)
		"lineage-price": price(gs, owner, src, card, target)
		"poet-song":
			var choices: Array = []
			for ally in gs.player(owner).units:
				if not ally.get("summoned", false) and not ally.get("removed", false): choices.append_array(pool(gs, owner, str(ally.id)))
			Choice.offer(gs, owner, "poet-song", Choice.sample(gs, choices, 4), "无邪颂歌")
		"poet-transform":
			var own_ids: Array = gs.player(owner).units.map(func(ally): return ally.id)
			var candidates := Content.playable_units().filter(func(ally): return ally.id not in own_ids and Factions.known(ally)).map(func(ally): return str(ally.id))
			Choice.offer(gs, owner, "poet-transform", Choice.sample(gs, candidates, 3), "捷思奏雅", {"targetId": target_id})
		"poet-combat":
			if target.is_empty(): return true
			var picked := Choice.sample(gs, pool(gs, owner, str(target.id), "combat", int(target.level), true), 1)
			if not picked.is_empty(): add_poem_card(gs, owner, picked[0], {"poetFreeTurn": gs.turn_counter})
			else: Choice.attack(gs, owner, gs._unit_index_by_uid(owner, target_id), null, {"immuneCombat": true})
		"poet-damage":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx >= 0: gs._damage_unit(side, idx, int(effect.value), owner, src)
		"poet-awake": gs._awaken(owner, src, card, effect.value)
		"poet-teach":
			var missing := false
			for ally in gs.player(owner).units:
				if ally == u or ally.get("summoned", false) or ally.get("removed", false): continue
				var picked := Choice.sample(gs, pool(gs, owner, str(ally.id)), 1)
				if picked.is_empty(): missing = true
				else: add_poem_card(gs, owner, picked[0])
			if missing: add_poem_card(gs, owner, POEM)
		"poet-verse": Choice.offer(gs, owner, "poet-verse", VERSES.keys(), "诗六义", {"remaining": 3, "sourceIndex": src})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	match frame.get("kind"):
		"lineage-shot":
			gs.VerifiedRules.base_damage_projectile(gs, owner, int(frame.sourceIndex), int(frame.amount), "猫川首用")
		"lineage-price-give": Choice.give(gs, owner, PRICES[int(frame.index)])
		"poet-next-verse":
			var c: Dictionary = frame.choice
			Choice.offer(gs, owner, "poet-verse", c.instanceIds, "诗六义", {"remaining": c.remaining, "sourceIndex": c.sourceIndex})
		"lineage-reshuffle":
			gs.player(owner).deck.append(frame.instance)
			gs._shuffle(gs.player(owner).deck)
		"poet-trigger":
			match int(frame.mode):
				0: gs._apply_encourage(owner, 0, 0, int(frame.amount))
				1:
					var units := Choice.sample(gs, Choice.live_units(gs, 1-owner), 1)
					if not units.is_empty(): gs.VerifiedRules.base_damage_unit(gs, owner, int(frame.sourceIndex), 1-owner, gs._unit_index_by_uid(1-owner, units[0].uid), int(frame.amount))
				2: gs.VerifiedRules.base_damage_avatar(gs, owner, int(frame.sourceIndex), 1-owner, int(frame.amount))
				3:
					var units := Choice.sample(gs, Choice.live_units(gs, owner), 1)
					if not units.is_empty(): units[0].swift = true
		_: return false
	return true

static func choice_card(gs, owner: int, iid: String):
	var kind := str(gs.pending_choice.get("type", ""))
	if not Choice.matches(gs, owner, iid, "poet-") and not Choice.matches(gs, owner, iid, "lineage-"): return null
	match kind:
		"lineage-contract":
			return Choice.face(iid, "签订契约" if iid == "contract" else "直接觉醒", "额外获得契约的代价，觉醒投射提高1点。" if iid == "contract" else "保持基础觉醒效果。")
		"poet-song": return Content.card_def(iid)
		"poet-transform":
			var u := Content.unit_def(iid)
			return Choice.face(iid, str(u.name), "成为此式神并替换所持专属牌。", str(u.get("art", "")))
		"poet-verse": return Choice.face(iid, VERSES[iid][0], VERSES[iid][1])
	return null

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	if choice_card(gs, owner, iid) == null: return false
	var c := Choice.accept(gs, owner, iid)
	match c.type:
		"lineage-contract":
			if iid == "contract":
				gs.player(owner).units[int(c.sourceIndex)].catContract = true
				Choice.give(gs, owner, PRICES[3])
		"poet-song": add_poem_card(gs, owner, iid)
		"poet-transform": substitute(gs, owner, str(c.targetId), iid)
		"poet-verse":
			var enemy := 1-owner
			match iid:
				"fire": gs.player(owner).poetNextFreeTurn = gs.turn_counter
				"all":
					gs.VerifiedRules.DragonFlow.all_damage(gs, owner, int(c.sourceIndex), 2)
				"front":
					var idx: int = gs.front_index(enemy)
					if idx >= 0 and gs.VerifiedRules.OwlInsect.shikigami(gs.player(enemy).units[idx]):
						gs._damage_unit(enemy, idx, 5, owner, int(c.sourceIndex))
				"realm":
					var realms: Array = gs.player(enemy).realms.duplicate()
					realms.sort_custom(func(a, b): return int(a.hp) > int(b.hp))
					if not realms.is_empty(): gs.VerifiedRules.Huang.destroy(gs, enemy, realms[0], "诗六义")
				"draw": gs._draw(owner, 2)
			c.instanceIds.erase(iid)
			c.remaining -= 1
			if int(c.remaining) > 0 and gs.winner < 0:
				gs.resolution_stack.append({"kind": "poet-next-verse", "playerIndex": owner, "choice": c})
	Choice.finish(gs)
	return true

static func ai_choice(gs, owner: int):
	var c: Dictionary = gs.pending_choice
	var ids: Array = c.get("instanceIds", [])
	if ids.is_empty() or choice_card(gs, owner, str(ids[0])) == null: return null
	var best := str(ids[0])
	if c.type == "lineage-contract" and int(gs.player(owner).avatarHp) < 8: best = "ordinary"
	return resolve_choice(gs, owner, best)
