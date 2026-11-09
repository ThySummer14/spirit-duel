extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const WORD := "yanling"
const WING := "guniao-yuxiang"
const PETAL := "taohua-luoying"
const WIND := "fallpetal-wind"
const BLOOM := "fallpetal-bloom"
const WORD_MODES := ["术", "形", "战"]

static func active(gs, owner: int, role: String) -> int:
	return gs.VerifiedRules.DuskCycle.active(gs, owner, role)

static func _allies(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp)>0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func gain_card(gs, owner: int, id: String) -> void:
	gs.VerifiedRules.DuskCycle.put_hand(gs, owner, id)

static func _pick(gs, pool: Array):
	return gs.VerifiedRules.DuskCycle.choose_from(gs, pool)

static func _offer_word(gs, owner: int, effect: String) -> void:
	var ids := WORD_MODES.map(func(mode): return effect+"-"+mode)
	gs.pending_choice = {"type":"grove-word", "playerIndex":owner, "instanceIds":ids,
		"heading":"选择%s" % ("语罪" if effect == "sin" else "言现"), "hint":"此灵咒只有你能看见。"}
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	var c: Dictionary = gs.pending_choice
	if c.get("type") != "grove-word" or int(c.playerIndex) != owner or iid not in c.instanceIds: return null
	var sin := iid.begins_with("sin-")
	var mode := iid.right(1)
	var cond: String = {"术":"法术牌", "形":"形态或法术牌", "战":"战斗牌或没有消耗鬼火的专属牌"}[mode]
	var action := "对用牌式神造成2点伤害" if sin else "投射10点贯通伤害"
	return {"id":iid,"unitId":WORD,"name":("语罪·" if sin else "言现·")+mode,"type":"spell","text":"敌方回合首张手牌若为敌方式神的%s，%s，然后移除此灵咒。" % [cond,action]}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	if choice_card(gs, owner, iid) == null: return false
	var p: Dictionary = gs.player(owner)
	var key := "wordSin" if iid.begins_with("sin-") else "wordReveal"
	p[key] = iid.right(1)
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId":iid,"choice":"grove-word"}, owner)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "grove-word": return null
	var c: Dictionary = gs.pending_choice
	var prefix := str(c.instanceIds[0]).left(-1)
	var revealed: Array = gs.player(1-owner).hand.filter(func(inst): return inst.get("revealed",false))
	var seen_combat := revealed.filter(func(inst): return Content.card_def(str(inst.definitionId)).get("type") == "combat").size()
	return resolve_choice(gs, owner, prefix + ("战" if seen_combat > 0 else "形"))

static func _matches(mode: String, card: Dictionary, paid: int) -> bool:
	if mode == "术": return Content.is_spell(card)
	if mode == "形": return card.type == "form" or Content.is_spell(card)
	if mode == "战": return card.type == "combat" or paid == 0
	return false

static func card_used(gs, frame: Dictionary, card: Dictionary) -> void:
	var user := int(frame.playerIndex)
	var owner := 1-user
	if user != gs.current_player: return
	var src := int(frame.sourceIndex)
	var p: Dictionary = gs.player(user)
	if src >= 0:
		var u: Dictionary = p.units[src]
		u.wordLastUse = gs.turn_counter
	if not frame.get("usedFromHand", frame.get("fromHand", false)) or int(p.get("wordFirstHand", -1)) == gs.turn_counter: return
	p.wordFirstHand = gs.turn_counter
	var judge := active(gs, owner, WORD)
	if src < 0 or judge < 0: return
	var observer: Dictionary = gs.player(owner)
	var paid := int(frame.get("paidFire", -1))
	var curse := _matches(str(observer.get("wordSin", "")), card, paid)
	var omen := _matches(str(observer.get("wordReveal", "")), card, paid)
	if not curse and not omen: return
	if omen:
		observer.erase("wordReveal")
		gs.resolution_stack.append({"kind":"grove-word-reveal","playerIndex":owner,"sourceIndex":judge})
	if curse:
		observer.erase("wordSin")
		observer.wordTriggers = int(observer.get("wordTriggers",0))+1
		p.units[src].wordSinTurn = gs.turn_counter
		var awakened: bool = observer.units[judge].awakened
		var original := frame.duplicate(true)
		original.cardOverride = card
		gs.resolution_stack.append({"kind":"grove-word-trigger","playerIndex":owner,"sourceIndex":judge,"original":original,"awakened":awakened})
		if not awakened and int(observer.units[judge].level) >= 3:
			var inst: Dictionary = gs.VerifiedRules.DuskCycle.take_named(gs, owner, "c61408")
			if not inst.is_empty(): gs.VerifiedRules.DuskCycle.cast(gs, owner, judge, inst)

static func counter(gs, owner: int, original: Dictionary) -> bool:
	var rid := int(original.resolutionId)
	if not gs.resolution_stack.any(func(f): return int(f.get("resolutionId", -1)) == rid and f.get("kind") == "card-effect"): return false
	gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId", -1)) != rid)
	var victim := int(original.playerIndex)
	var card: Dictionary = original.cardOverride
	gs.VerifiedRules.Insight.used(gs, victim, card, card.get("playedInstance", {}), false)
	gs.VerifiedRules.event(gs, "card-nullified", {"player":victim,"card":card,"resolutionId":rid})
	gs._log("「%s」被语罪反制。" % card.name, gs.TONE_CARD)
	return true

static func _sin(gs, frame: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var original: Dictionary = frame.original
	var victim := int(original.playerIndex)
	var victim_idx := int(original.sourceIndex)
	var law: Array = gs.VerifiedRules.DuskCycle.realms(gs, owner, "word-law")
	if not law.is_empty() and counter(gs, owner, original):
		if not law[0].has("wordReturns"): law[0].wordReturns = []
		law[0].wordReturns.append(str(original.cardOverride.id))
	elif law.is_empty():
		var check := original.duplicate()
		check.kind = "card-counter-check"
		gs.VerifiedRules.automatic_response(gs, owner, "word-sin", null, check)
	var u: Dictionary = gs.player(owner).units[src]
	if u.get("formRules", {}).get("wordDraw", false): gs._draw(owner, 1)
	if u.get("formRules", {}).get("wordStun", false): gs.VerifiedRules.Stun.apply(gs, victim, victim_idx, 1, owner)
	if frame.awakened:
		for v in gs.VerifiedRules.DuskCycle.foe_living(gs, owner):
			gs.VerifiedRules.base_damage_unit(gs, owner, src, victim, gs._unit_index_by_uid(victim, v.uid), 2)
	else:
		gs.VerifiedRules.base_damage_unit(gs, owner, src, victim, victim_idx, 2)

static func realm_left(gs, owner: int, realm: Dictionary) -> void:
	if realm.get("nativeRealm") != "word-law": return
	for id in realm.get("wordReturns", []): gain_card(gs, 1-owner, str(id))

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.id == "c61403": return false
	if card.id != "c60503": return true
	var src := active(gs, owner, "kongquemingwang")
	if src >= 0: return true
	src = gs.VerifiedRules.DuskCycle.index(gs, owner, "kongquemingwang")
	return src >= 0 and gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, gs.player(owner).units[src])

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.is_empty(): return card
	if card.id == "c61401":
		var out := card.duplicate(true)
		out.value = 3+int(gs.player(owner).get("wordTriggers", 0))
		out.effects[0].value = out.value
		out.currentCardStats = "当前伤害%d" % out.value
		return out
	if card.id == "c61201" and inst.get("petalBounced", false):
		var out := card.duplicate(true)
		out.keywords.erase("bounce")
		out.text = out.text.replace("，弹回","")
		return out
	return card

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id") in ["c61201", "c61202", "c61205", "c61207"]:
		return _allies(gs, owner).map(func(u): return u.uid)
	if card.get("target") == "word-execute":
		var last: int = gs.turn_counter-1
		return gs.VerifiedRules.DuskCycle.foe_living(gs, owner).filter(func(u):
			return not gs.VerifiedRules.Combat.has(u, "veil") and (int(u.get("wordLastUse", -1)) != last or int(u.get("wordSinTurn", -1)) == last)
		).map(func(u):return u.uid)
	if card.get("target") == "fallpetal-bloom":
		return gs.player(owner).units.filter(func(u):
			return gs.VerifiedRules.OwlInsect.shikigami(u) and not u.get("removed",false) and (int(u.hp)>0 or gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u))
		).map(func(u): return u.uid)
	return null

static func form_installed(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.id == "c61005" or card.id == "c61206":
		gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1)
		if card.id == "c61206": bloom_hand(gs, owner)
	if card.id == "c61402":
		var hand: Array = gs.player(1-owner).hand
		if not hand.is_empty():
			var inst: Dictionary = _pick(gs, hand)
			inst.revealed = true

static func bloom_hand(gs, owner: int) -> void:
	if not gs.player(owner).hand.any(func(inst): return inst.definitionId == BLOOM):
		gain_card(gs, owner, BLOOM)

static func turn_start(gs, owner: int) -> void:
	var src := active(gs, owner, WORD)
	if src >= 0: gs.resolution_stack.append({"kind":"grove-word-offer","playerIndex":owner})
	src = active(gs, owner, WING)
	if src >= 0 and gs.player(owner).units[src].get("formRules",{}).get("wingguardKeep",false):
		gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1)
	src = active(gs, owner, PETAL)
	if src >= 0 and gs.player(owner).units[src].get("formRules",{}).get("fallpetalBloom",false):
		bloom_hand(gs, owner)
	var enemy := 1-owner
	src = active(gs, enemy, PETAL)
	if src >= 0 and gs.player(enemy).units[src].get("formRules",{}).get("fallpetalMoon",false):
		gs.VerifiedRules.HairPower.give(gs, enemy, gs.front_index(enemy), 1)

static func end_turn(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	for i in range(p.hand.size()-1,-1,-1):
		if p.hand[i].definitionId == WIND: gs.discard_hand_card(owner, i)
	var src := active(gs, 1-owner, WING)
	if src >= 0 and gs.VerifiedRules.HairPower.amount(gs.player(1-owner).units[src]) > 0:
		gs.VerifiedRules.automatic_response(gs, 1-owner, "wingguard-end", null, {"kind":"response-complete"})

static func wing_crane(gs, owner: int, src: int) -> void:
	var bird := active(gs, owner, WING)
	if bird < 0 or bird == src: return
	if gs.player(owner).units[bird].get("formRules",{}).get("wingguardCrane",false):
		gs.VerifiedRules.HairPower.grant_guard(gs, owner, 2)

static func combat_cancel(gs, frame: Dictionary) -> bool:
	var owner := int(frame.playerIndex)
	var victim := int(frame.options.get("combatVictim",1-owner))
	var idx := int(frame.defenderIndex)
	var u: Dictionary = gs.player(victim).units[idx]
	if u.id != WING or not gs.VerifiedRules.HairPower.active(u) or (int(u.front) != 1 and not u.awakened): return false
	gs._log("%s 取消本次攻击并移回准备区。" % u.name, gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "wingguard-evade", {"player":victim,"uid":u.uid,"attacker":gs.player(owner).units[int(frame.sourceIndex)].uid})
	gs.VerifiedRules.Movement.move_to(gs, victim, idx, 0)
	gs.VerifiedRules.TomatoFire.finish_attack(gs, owner, int(frame.sourceIndex))
	gs.VerifiedRules.OniAsura.combat_finished(gs, owner, int(frame.sourceIndex), frame.options)
	if frame.options.get("basicAttack", false): wing_crane(gs, owner, int(frame.sourceIndex))
	return true

static func moved(gs, owner: int, idx: int, u: Dictionary) -> void:
	if u.id != WING or not u.awakened: return
	var power: int = gs.VerifiedRules.HairPower.amount(u)
	if power > 0: gs.resolution_stack.append({"kind":"grove-wing-projectile","playerIndex":owner,"sourceIndex":idx,"value":power})

static func guard_attack(gs, owner: int, src: int, depth: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not u.get("formRules",{}).get("wingguardKeep",false) or int(u.get("wingguardAttackTurn",-1)) == gs.turn_counter: return
	u.wingguardAttackTurn = gs.turn_counter
	gs.resolution_stack.insert(depth, {"kind":"grove-wing-attack","playerIndex":owner,"sourceIndex":src,"options":{"wingguardKeepPower":true}})

static func combat_finished(gs, owner: int, src: int, options: Dictionary, kills: int) -> void:
	if options.get("wingguardKill",false) and kills > 0:
		gs.VerifiedRules.HairPower.give(gs, owner, src, 2)
	for realm in gs.VerifiedRules.DuskCycle.realms(gs, owner, "wingguard-home"):
		if int(realm.get("wingguardHomeTurn",-1)) == gs.turn_counter: continue
		realm.wingguardHomeTurn = gs.turn_counter
		gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
		if int(gs.player(owner).units[src].hp) > 0: gs._grant_unit_armor(gs.player(owner).units[src],1)
	if options.get("basicAttack",false): wing_crane(gs, owner, src)

static func petal_protects(gs, owner: int, u: Dictionary) -> bool:
	if int(u.get("front",0)) != 1 or gs.VerifiedRules.HairPower.amount(u) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(u): return false
	var src := active(gs, owner, PETAL)
	return src >= 0 and gs.player(owner).units[src].awakened

static func reduce_damage(gs, owner: int, u: Dictionary, amount: int) -> int:
	if amount <= 0 or gs.VerifiedRules.HairPower.amount(u) <= 0 or active(gs, owner, PETAL) < 0 or not gs.VerifiedRules.OwlInsect.shikigami(u): return amount
	return maxi(0, amount-1)

static func battle_power(gs, owner: int, target: Dictionary, amount: int) -> void:
	if not target.is_empty(): gs.VerifiedRules.HairPower.give(gs, owner, gs._unit_index_by_uid(owner, target.uid), amount)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.action)
	if not action.begins_with("word-") and not action.begins_with("wingguard-") and not action.begins_with("fallpetal-"): return false
	var enemy := 1-owner
	match action:
		"word-1":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx >= 0: gs._damage_unit(side, idx, int(effect.value), owner, src)
		"word-2", "word-6", "wingguard-5", "wingguard-7", "fallpetal-2", "fallpetal-6":
			gs._apply_form(owner, src, card, effect.value)
			if action == "fallpetal-2": battle_power(gs, owner, target, 2)
		"word-3":
			if card.has("wordOriginal"): counter(gs, owner, card.wordOriginal)
		"word-4": gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, gs._unit_index_by_uid(enemy, target_id), card)
		"word-5", "wingguard-2": gs._deploy_realm(owner, card)
		"word-7": _offer_word(gs, owner, "reveal")
		"word-8": gs._awaken(owner, src, card, effect.value)
		"wingguard-1", "wingguard-4", "wingguard-6":
			if action == "wingguard-1": gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1)
			gs._resolve_action(owner, src, card, {"action":"assault","value":int(effect.value)+(2 if card.get("wingguardResponse", false) else 0)}, target_id, target)
		"wingguard-3":
			gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1)
			gs._draw(owner, 1)
		"wingguard-8":
			gs.VerifiedRules.HairPower.grant_guard(gs, owner, 2)
			gs._awaken(owner, src, card, effect.value)
		"fallpetal-1":
			battle_power(gs, owner, target, 1)
			var inst: Dictionary = card.get("playedInstance", {})
			if not inst.is_empty() and not inst.get("petalBounced",false):
				inst.petalBounced = true
				gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
		"fallpetal-3":
			for u in _allies(gs, owner): battle_power(gs, owner, u, 2)
			for u in _allies(gs, owner):
				if gs.VerifiedRules.HairPower.amount(u) < 4: continue
				u.inspired = true
				gs.VerifiedRules.event(gs, "inspired-gained", {"player": owner, "uid": u.uid})
		"fallpetal-4": gs.VerifiedRules.HairPower.grant_guard(gs, owner, 2, 1)
		"fallpetal-5":
			battle_power(gs, owner, target, 3)
			gain_card(gs, owner, WIND)
		"fallpetal-7":
			battle_power(gs, owner, target, 5)
			if not target.is_empty() and gs.VerifiedRules.HairPower.amount(target)>0:
				gs.resolution_stack.append({"kind":"grove-petal-damage","playerIndex":owner,"sourceIndex":src,"value":gs.VerifiedRules.HairPower.amount(target),"context":gs._card_effect_context.duplicate(true)})
		"fallpetal-8":
			gs.VerifiedRules.HairPower.grant_guard(gs, owner, 3)
			gs._awaken(owner, src, card, effect.value)
		"fallpetal-wind":
			var pool := _allies(gs, owner)
			pool.sort_custom(func(a,b):return gs.VerifiedRules.HairPower.amount(a)>gs.VerifiedRules.HairPower.amount(b))
			var idx: int = gs._unit_index_by_uid(enemy, target_id)
			if idx >= 0 and not pool.is_empty(): gs._damage_unit(enemy, idx, maxi(0,int(pool[0].attack)), owner, src)
		"fallpetal-bloom":
			if target.is_empty(): return true
			var idx: int = gs._unit_index_by_uid(owner, target_id)
			if int(target.hp) <= 0:
				if not gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false): return true
			else: battle_power(gs, owner, target, 2)
			var list: Array = gs.player(owner).get("guardDeployments", [])
			if not list.is_empty():
				var g: Dictionary = list.pop_front()
				battle_power(gs, owner, target, int(g.power))
				gs._grant_unit_armor(target, int(g.armor))
			gs.resolution_stack.append({"kind":"grove-wing-attack","playerIndex":owner,"sourceIndex":idx,"options":{"butterflyEncourageCombat":true}})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if not kind.begins_with("grove-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex",-1))
	var enemy := 1-owner
	match kind:
		"grove-word-offer": _offer_word(gs, owner, "sin")
		"grove-word-trigger": _sin(gs, frame)
		"grove-word-reveal":
			var idx: int = gs.front_index(enemy)
			var context: Dictionary = gs._card_effect_context
			gs._card_effect_context = {}
			if idx < 0: gs._damage_avatar(enemy, 10, owner, src)
			else:
				var hit: Dictionary = gs._damage_unit(enemy, idx, 10, owner, src)
				if int(hit.get("overkill",0))>0: gs._damage_avatar(enemy, int(hit.overkill), owner, src, false, false, true)
			gs._card_effect_context = context
		"grove-wing-attack": gs.VerifiedRules.DuskCycle.attack(gs, owner, src, null, frame.options)
		"grove-wing-projectile": gs.VerifiedRules.base_damage_projectile(gs, owner, src, int(frame.value), "回天之翼")
		"grove-petal-damage":
			if int(frame.value) > 1:
				var next := frame.duplicate()
				next.value = int(frame.value)-1
				gs.resolution_stack.append(next)
			var candidates: Array = [-1]
			for u in gs.player(enemy).units:
				if int(u.hp)>0 and not u.get("removed",false): candidates.append(gs._unit_index_by_uid(enemy,u.uid))
			var idx: int = _pick(gs, candidates)
			var old: Dictionary = gs._card_effect_context
			gs._card_effect_context = frame.context
			if idx < 0: gs._damage_avatar(enemy, 1, owner, src)
			else: gs._damage_unit(enemy, idx, 1, owner, src)
			gs._card_effect_context = old
		_: return false
	return true
