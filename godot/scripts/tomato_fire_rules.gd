class_name TomatoFireRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const COMBAT_CARDS := ["c14601", "c14604", "c14606"]
const SWAN_TRAITS := ["remote", "pierce", "unyielding", "lethal", "combo", "lifeSteal"]

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("tomatoFireRole", ""))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp", 0)) > 0 and int(u.get("level", 0)) > 0
static func tomato(u: Dictionary) -> bool:
	return not u.get("baseRulesSuppressed", false) and (u.get("tomatoEntity", false) or (role(u) == "sister" and u.get("awakened", false)))
static func burn(u: Dictionary) -> bool:
	return not u.get("baseRulesSuppressed", false) and (u.get("burnEntity", false) or role(u) == "burn")
static func form_active(gs, owner: int, key: String) -> bool:
	for u in gs.player(owner).units:
		if active(u) and u.get("formRules", {}).get(key, false): return true
	return false
static func extra_cost(gs, owner: int, card: Dictionary) -> int:
	if card.get("type") != "combat": return 0
	var src: int = gs._source_index(owner, card)
	if src < 0: return 0
	var u: Dictionary = gs.player(owner).units[src]
	# The official March 27 bug fix confirms this cost on knocked-out revival.
	return 1 if role(u) == "sister" and not u.awakened else 0
static func basic_cost(gs, owner: int, u: Dictionary) -> int:
	var cost := 0 if gs.VerifiedRules.Mianqiling.swift(u) or gs.VerifiedRules.Glutton.has(u,"swift") or u.get("swift", false) or gs.VerifiedRules.Yaodao.permanent_swift(u) or gs.VerifiedRules.Bailang.swift(u) or gs.VerifiedRules.IronMouse.swift(gs, u) or gs.VerifiedRules.TreeSakura.floating(u) or gs.VerifiedRules.Rebirth.swift(u) or gs.VerifiedRules.Samurai.swift(u) or gs.VerifiedRules.Yitiao.swift(u) else 1
	return cost + (1 if role(u) == "sister" and not u.awakened else 0) + gs.VerifiedRules.Jorogumo.tax(gs,owner,u)
static func amplify(gs, owner: int, attack: int, shield: int) -> Dictionary:
	var n := 0
	for u in gs.player(owner).units:
		if role(u) == "fire" and active(u) and u.awakened: n += 1
	return {"attack": attack + n, "shield": shield + n}
static func prepare_encourage(gs, owner: int) -> Dictionary:
	var usage: Dictionary = gs.kw_usage(owner, "encourage")
	var kw: Dictionary = usage.get("traits", {}).duplicate(true)
	var result := {"attack": int(usage.get("attack", 0)), "shield": int(usage.get("shield", 0)), "traits": kw, "active": int(usage.get("attack", 0)) != 0 or int(usage.get("shield", 0)) != 0 or not kw.is_empty()}
	if not form_active(gs, owner, "retainEncourage"):
		usage.attack = 0
		usage.shield = 0
		usage.traits = {}
	return result
static func attack_encourage(gs, owner: int, options: Dictionary) -> Dictionary:
	return gs._prepare_encourage(owner) if options.get("basicAttack", false) or options.get("rpNightRaid", false) or options.get("combatCard",{}).get("battleSkillTriggered",false) or options.get("butterflyEncourageCombat", false) or (options.has("combatCard") and form_active(gs, owner, "encourageCombat")) else {}
static func encourage_trait(gs, owner: int, key: String, expires: bool = false) -> void:
	# An encouragement that grants only a keyword is still amplified by awakening.
	gs._apply_encourage(owner, 0, 0)
	var use: Dictionary = gs.kw_usage(owner, "encourage")
	if not use.has("traits"): use.traits = {}
	use.traits[key] = gs.turn_counter if expires else -1
static func merge_traits(options: Dictionary, enc: Dictionary) -> Dictionary:
	var result := options.duplicate(true)
	for key in enc.get("traits", {}): result[key] = true
	return result
static func begin_attack(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.get("basicAttack", false): return
	var p: Dictionary = gs.player(owner)
	if not p.has("basicDamageSources"): p.basicDamageSources = []
	p.basicDamageSources.append(p.units[src].uid)
static func finish_attack(gs, owner: int, src: int) -> void:
	var list: Array = gs.player(owner).get("basicDamageSources", [])
	list.erase(gs.player(owner).units[src].uid)
static func avatar_damaged(gs, owner: int, src: int, victim: int, damage: int) -> void:
	if owner < 0 or src < 0 or damage <= 0 or owner == victim: return
	var p: Dictionary = gs.player(owner)
	if not p.get("basicDamageSources", []).has(p.units[src].uid): return
	# Each damage event from the commanded basic attack counts, including its
	# projectile/passive/pierce. A combat card or unrelated spell never counts.
	for u in p.units:
		if active(u) and u.get("formRules", {}).get("drawBasicAvatarDamage", false):
			gs._draw(owner, 1)
			gs.VerifiedRules.event(gs, "first-dance-draw", {"player": owner, "uid": u.uid, "attackUid": p.units[src].uid})
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("tomatoFireSummon", false) or int(u.hp) <= 0: return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason,false)
	u.hp = 0
	u.front = 0
	u.knockout = 0
	u.removed = true
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": u.uid, "reason": reason})
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("tomatoFireSummon", false) and int(u.front) == 0: remove_summon(gs, owner, u)
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs, owner, u, "战斗区被替换")
static func sync_tomatoes(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var amount := int(p.get("tomatoPower", 0))
	for u in p.units:
		if not tomato(u) or u.get("removed", false): continue
		u.permanentAttack = int(u.get("permanentAttack", 0)) + amount - int(u.get("tomatoAppliedPower", 0))
		u.tomatoAppliedPower = amount
		u.tomatoSplash = int(p.get("tomatoSplash", 0))
		gs._recalc(u)
static func summon(gs, owner: int, src: int, kind: String, after: Dictionary = {}) -> int:
	var p: Dictionary = gs.player(owner)
	var movement_old: Array = p.units.map(func(u): return int(u.front))
	gs.VerifiedRules.SunSmoke.remove_departed(gs)
	clear_summons(gs, owner)
	gs.VerifiedRules.Xuenv.clear_wall(gs, owner)
	for other in p.units:
		if other.get("smokeClone", false): gs.VerifiedRules.SunSmoke.remove_clone(gs, owner, other, "战斗区被替换")
		other.front = 0
	var is_tomato := kind == "tomato"
	var cfg: Dictionary = Content.unit_def("tiaotiaomeimei" if is_tomato else "buzhinhuo").get("summonStats", {})
	var atk := int(cfg.get("attack", 4 if is_tomato else 2))
	var hp := int(cfg.get("hp", 4 if is_tomato else 2))
	var id := "fanqie" if is_tomato else "jinran-buye"
	var u := {"uid": "%s:%s-%d" % [p.id, id, gs.next_card_id], "id": id, "name": "番茄" if is_tomato else "烬染不夜", "title": "跳跳妹妹召唤物" if is_tomato else "不知火召唤物", "art": "assets/wave11/%s.svg" % id, "color": "#e06040", "baseAttack": atk, "baseMaxHp": hp, "attack": atk, "maxHp": hp, "hp": hp, "shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0, "unyielding": false, "level": 1, "front": 1, "attackBonus": 0, "maxHpBonus": 0, "awakened": false, "form": {}, "formRules": {}, "formAbility": "唯一。离开战斗区移除。" if is_tomato else "迅捷。攻击改为对两个随机敌方角色各造成等同于力量的伤害。", "charge": 0, "passive_hooks": [], "summoned": true, "summon": true, "countsAsShikigami": true, "tomatoFireSummon": true, "tomatoEntity": is_tomato, "burnEntity": not is_tomato, "swift": not is_tomato, "summonerUid": p.units[src].uid}
	gs.next_card_id += 1
	p.units.append(u)
	gs.VerifiedRules.Enma.remove_departed(gs)
	gs.VerifiedRules.Weaver.remove_departed(gs)
	gs.VerifiedRules.Vine.remove_departed(gs)
	gs.VerifiedRules.WindRaccoon.remove_departed(gs)
	gs.VerifiedRules.House.remove_departed(gs)
	gs.VerifiedRules.Doll.remove_departed(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	for i in movement_old.size(): gs.VerifiedRules.Movement.moved(gs, owner, i, int(movement_old[i]))
	var idx: int = p.units.size() - 1
	sync_tomatoes(gs, owner)
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": u.uid, "sourceUid": p.units[src].uid, "summonKind": kind})
	var continuation := after.duplicate(true)
	if continuation.is_empty(): continuation = {"kind": "response-complete"}
	else: continuation.summonIndex = idx
	if not gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-entered-front", u.uid, continuation):
		if continuation.kind != "response-complete": gs.resolution_stack.append(continuation)
	return idx
static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if src < 0 or int(result.get("dealt", result.get("damage", 0))) <= 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not tomato(u): return
	for i in int(u.get("tomatoSplash", 0)):
		if gs.winner >= 0: break
		var pool: Array = [-1] if idx >= 0 else []
		for j in gs.player(victim).units.size():
			if j != idx and int(gs.player(victim).units[j].hp) > 0: pool.append(j)
		if pool.is_empty(): break
		var at: int = pool[gs.next_random() % pool.size()]
		if at < 0: gs._damage_avatar(victim, 3, owner, src)
		else: gs._damage_unit(victim, at, 3, owner, src)
		gs.VerifiedRules.event(gs, "tomato-splash", {"player": owner, "uid": u.uid, "victimPlayer": victim, "target": "" if at < 0 else gs.player(victim).units[at].uid, "amount": 3})
static func burn_attack(gs, frame: Dictionary, power: int, options: Dictionary) -> bool:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if not burn(u): return false
	# Replacement happens before the ordinary defender is picked. It is one
	# attack, two damage events, with no ordinary counterstrike or chosen target.
	var pool: Array = [-1]
	for idx in gs.player(1 - owner).units.size():
		if int(gs.player(1 - owner).units[idx].hp) > 0: pool.append(idx)
	var targets: Array = []
	for i in mini(2, pool.size()): targets.append(pool.pop_at(gs.next_random() % pool.size()))
	gs.resolution_stack.append({"kind": "burn-complete", "playerIndex": owner, "sourceIndex": src, "options": options, "fromReserve": frame.fromReserve})
	for i in range(targets.size() - 1, -1, -1):
		gs.resolution_stack.append({"kind": "burn-response", "playerIndex": owner, "sourceIndex": src, "targetIndex": targets[i], "power": power, "options": options})
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	match str(frame.get("kind", "")):
		"tomato-after-entry":
			var owner := int(frame.playerIndex)
			var idx := int(frame.summonIndex)
			var u: Dictionary = gs.player(owner).units[idx]
			if frame.get("attack", false) and int(u.hp) > 0:
				gs._resolve_combat(owner, idx, 0, false, false, false, false)
			var combat_id := int(frame.get("combatResponseId", -1))
			if combat_id >= 0 and int(u.hp) > 0:
				for pending in gs.resolution_stack:
					if pending.get("kind") == "combat-hit" and int(pending.get("combatId", -2)) == combat_id and not pending.options.get("reserveTarget", false) and not pending.options.get("pursuit", false):
						pending.defenderIndex = idx
						gs.VerifiedRules.event(gs, "tomato-guard", {"player": owner, "uid": u.uid})
		"burn-response":
			var owner := int(frame.playerIndex)
			var idx := int(frame.targetIndex)
			var hit := frame.duplicate(true)
			hit.kind = "burn-hit"
			if idx >= 0:
				if int(gs.player(1 - owner).units[idx].hp) <= 0: return true
				if gs.VerifiedRules.automatic_response(gs, 1 - owner, "unit-attacked", gs.player(1 - owner).units[idx].uid, hit): return true
			resolve_frame(gs, hit)
		"burn-hit":
			var owner := int(frame.playerIndex)
			var src := int(frame.sourceIndex)
			var idx := int(frame.targetIndex)
			if gs.winner >= 0 or int(gs.player(owner).units[src].hp) <= 0: return true
			if idx >= 0 and int(gs.player(1 - owner).units[idx].hp) <= 0: return true
			# The official guide explicitly says 見切 triggers but cannot immune
			# this randomly addressed replacement damage. It is not combat damage.
			if idx < 0: gs._damage_avatar(1 - owner, int(frame.power), owner, src)
			else: gs._damage_unit(1 - owner, idx, int(frame.power), owner, src)
			gs.VerifiedRules.event(gs, "burn-random-hit", {"player": owner, "uid": gs.player(owner).units[src].uid, "victimPlayer": 1 - owner, "target": "" if idx < 0 else gs.player(1 - owner).units[idx].uid, "amount": int(frame.power)})
		"burn-complete": gs._finish_combat(int(frame.playerIndex), int(frame.sourceIndex), {}, bool(frame.fromReserve), frame.options, 0)
		_: return false
	return true
static func grant_card(gs, owner: int, id: String) -> void:
	var p: Dictionary = gs.player(owner)
	if p.hand.size() >= int(gs.rules.get("maxHandSize", 12)): return
	p.hand.append({"instanceId": "%s-tomato-%d" % [p.id, gs.next_card_id], "definitionId": id})
	gs.next_card_id += 1
static func awaken_tomato(gs, owner: int, src: int) -> void:
	var p: Dictionary = gs.player(owner)
	for i in 2: grant_card(gs, owner, COMBAT_CARDS[gs.next_random() % COMBAT_CARDS.size()])
	var u: Dictionary = p.units[src]
	u.awakened = true
	u.tomatoEntity = true
	u.passive_hooks = []
	u.presentationId = "fanqie"
	gs._grow_unit(u, 3, 3)
	sync_tomatoes(gs, owner)
	for entries in [p.hand, p.deck]:
		for entry in entries:
			var card: Dictionary = Content.card_def(str(entry.definitionId))
			if card.get("unitId") == u.id and card.get("type") != "combat":
				entry.definitionId = COMBAT_CARDS[gs.next_random() % COMBAT_CARDS.size()]
				entry.erase("originCard")
	gs.VerifiedRules.event(gs, "tomato-awakened", {"player": owner, "uid": u.uid, "randomCombatCards": 2})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	match str(effect.get("action", "")):
		"tomato-summon":
			var continuation := {"kind": "tomato-after-entry", "playerIndex": owner, "attack": bool(effect.get("attack", false)), "combatResponseId": int(gs._card_effect_context.get("combatResponseId", -1))}
			summon(gs, owner, src, "tomato", continuation)
		"tomato-sit":
			# Grant once even if an entry response immediately destroys the summon.
			p.tomatoPower = int(p.get("tomatoPower", 0)) + 1
			summon(gs, owner, src, "tomato")
			sync_tomatoes(gs, owner)
		"tomato-out":
			p.tomatoSplash = int(p.get("tomatoSplash", 0)) + 1
			summon(gs, owner, src, "tomato")
			sync_tomatoes(gs, owner)
		"tomato-revive":
			var u: Dictionary = p.units[src]
			if int(u.hp) <= 0:
				u.hp = int(u.maxHp)
				u.knockout = 0
				u.shield = 0
		"tomato-awaken": awaken_tomato(gs, owner, src)
		"fire-freedom":
			if not target.is_empty() and int(target.hp) > 0:
				target.swift = true
				target.tomatoSwiftTurn = gs.turn_counter
			gs._apply_encourage(owner, 2, 2)
		"fire-truth":
			gs._apply_encourage(owner, 1, 1)
			p.attackUsed = false
		"fire-spark": summon(gs, owner, src, "burn")
		"fire-awaken":
			encourage_trait(gs, owner, "pierce", true)
			var u: Dictionary = p.units[src]
			u.awakened = true
			u.passive_hooks = []
			gs._grow_unit(u, 1, 1)
		_: return false
	return true
static func turn_start(gs, current: int) -> void:
	# Natural revival has completed. All 19-effect forms trigger on both turns,
	# in installation order. Base encouragement triggers only on the owner turn.
	for owner in 2:
		var p: Dictionary = gs.player(owner)
		if owner == current:
			for u in p.units:
				if role(u) == "fire" and active(u): gs._apply_encourage(owner, 1, 0)
		var forms: Array = []
		for i in p.units.size():
			if active(p.units[i]) and p.units[i].get("formRules", {}).get("swanRandom", false): forms.append(i)
		forms.sort_custom(func(a, b): return int(p.units[a].get("formInstalledOrder", 0)) < int(p.units[b].get("formInstalledOrder", 0)))
		for src in forms:
			if gs.winner >= 0: return
			if active(p.units[src]): swan(gs, owner, src, gs.next_random() % 19)
			gs._resolve_resolution_stack()
static func temp_stats(gs, u: Dictionary, attack: int, hp: int = 0) -> void:
	if not u.has("swanStats"): u.swanStats = []
	u.swanStats.append({"turn": gs.turn_counter, "attack": attack, "hp": hp})
	gs._grow_unit(u, attack, hp)
static func temp_keyword(gs, u: Dictionary, key: String) -> void:
	if not u.has("swanKeywords"): u.swanKeywords = {}
	u.swanKeywords[key] = gs.turn_counter
static func swan(gs, owner: int, src: int, result: int) -> void:
	var p: Dictionary = gs.player(owner)
	var enemy: Dictionary = gs.player(1 - owner)
	var own: Array = p.units.filter(func(u): return active(u))
	var foes: Array = enemy.units.filter(func(u): return active(u))
	gs.VerifiedRules.event(gs, "swan-effect", {"player": owner, "uid": p.units[src].uid, "result": result})
	match result:
		0:
			for u in own:
				u.unyielding = true
				u.swanUnyieldingTurn = gs.turn_counter
				temp_keyword(gs, u, "curtain")
		1:
			for u in p.units:
				if int(u.hp) <= 0 and not u.get("summoned", false) and not u.get("removed", false):
					u.hp = u.maxHp
					u.knockout = 0
		2: gs._damage_avatar(1 - owner, 4, owner, src)
		3:
			var idx: int = gs.front_index(1 - owner)
			if idx < 0: gs._damage_avatar(1 - owner, 5, owner, src)
			else: gs._damage_unit(1 - owner, idx, 5, owner, src)
		4: gs._heal_avatar(owner, 6)
		5:
			for u in foes: gs._damage_unit(1 - owner, gs._unit_index_by_uid(1 - owner, u.uid), 2, owner, src)
		6:
			gs._apply_encourage(owner, 2, 2)
			var key: String = SWAN_TRAITS[gs.next_random() % SWAN_TRAITS.size()]
			var use: Dictionary = gs.kw_usage(owner, "encourage")
			if not use.has("traits"): use.traits = {}
			use.traits[key] = -1
		7:
			for u in own:
				temp_stats(gs, u, 1, 1)
				gs._grant_unit_armor(u, 1)
		8:
			var u: Dictionary = gs.front_unit(owner)
			if not u.is_empty():
				temp_stats(gs, u, 2, 2)
				gs._grant_unit_armor(u, 2)
		9:
			var pool: Array = own.duplicate()
			for i in mini(2, pool.size()): gs._grow_unit(pool.pop_at(gs.next_random() % pool.size()), 1, 1)
		10: gs._draw(owner, 1)
		11: gs._set_fire(owner,int(p.energy)+1)
		12: summon(gs, owner, src, "burn")
		13:
			for u in foes: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, 1 - owner, gs._unit_index_by_uid(1 - owner, u.uid), 3)
		14:
			var best: Array = []
			var atk := -999
			for u in foes:
				if int(u.attack) > atk: atk = int(u.attack); best = [u]
				elif int(u.attack) == atk: best.append(u)
			if not best.is_empty(): gs.VerifiedRules.Stun.apply(gs, 1 - owner, gs._unit_index_by_uid(1 - owner, best[gs.next_random() % best.size()].uid), 1, owner)
		15:
			var best: Array = []
			var atk := -999
			for u in own:
				if int(u.attack) > atk: atk = int(u.attack); best = [u]
				elif int(u.attack) == atk: best.append(u)
			if not best.is_empty():
				var u: Dictionary = best[gs.next_random() % best.size()]
				temp_stats(gs, u, 2)
				temp_keyword(gs, u, "pierce")
		16:
			for u in own:
				u.swift = true
				u.tomatoSwiftTurn = gs.turn_counter
		17:
			for u in foes: temp_stats(gs, u, -2)
		18: gs._grant_avatar_armor(owner, 8)
static func end_turn(gs) -> void:
	for p in gs.players:
		var use: Dictionary = gs.kw_usage(gs.players.find(p), "encourage")
		var traits: Dictionary = use.get("traits", {})
		for key in traits.keys():
			if int(traits[key]) >= 0 and int(traits[key]) <= gs.turn_counter: traits.erase(key)
		for u in p.units:
			if int(u.get("tomatoSwiftTurn", -1)) == gs.turn_counter:
				u.swift = false
				u.erase("tomatoSwiftTurn")
			if int(u.get("swanUnyieldingTurn", -1)) == gs.turn_counter:
				u.unyielding = false
				u.erase("swanUnyieldingTurn")
			for entry in u.get("swanStats", []).duplicate():
				if int(entry.turn) <= gs.turn_counter:
					u.attackBonus = int(u.attackBonus) - int(entry.attack)
					u.maxHpBonus = int(u.maxHpBonus) - int(entry.hp)
					u.swanStats.erase(entry)
			for key in u.get("swanKeywords", {}).keys():
				if int(u.swanKeywords[key]) <= gs.turn_counter: u.swanKeywords.erase(key)
			gs._recalc(u)
static func targets(gs, owner: int, targets_in: Array) -> Array:
	return targets_in.filter(func(uid): return not gs.VerifiedRules.Combat.has(gs._unit_by_uid(gs.player(1 - owner).units, uid), "curtain"))
static func unit_view(gs, owner: int, idx: int, view: Dictionary) -> Dictionary:
	var u: Dictionary = gs.player(owner).units[idx]
	if tomato(u):
		view.presentationId = "fanqie"
		view.art = Content.unit_def("fanqie").art
		view.awakenedArt = view.art
		view.tomatoPower = int(gs.player(owner).get("tomatoPower", 0))
		view.tomatoSplash = int(gs.player(owner).get("tomatoSplash", 0))
	view.extraAttackCost = basic_cost(gs, owner, u)
	return view
static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.has("tomatoFireRule"): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	var u: Dictionary = gs.player(owner).units[src]
	match str(card.tomatoFireRule):
		"sit", "out": return 75
		"awaken-tomato": return 100 if not u.awakened else -20
		"summon-attack": return 60
		"guard": return 10
		"revive": return 100 if int(u.hp) <= 0 else 35
		"truth": return 80 if gs.player(owner).attackUsed else 25
		"freedom": return -100 if gs._unit_by_uid(gs.player(owner).units, target_id).is_empty() else 55
		"spark": return 70
		"awaken-fire": return 90 if not u.awakened else -20
		"form": return -20 if u.get("form", {}).get("cardId") == card.id else 50
		"combat": return 50
	return 0
