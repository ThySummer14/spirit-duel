extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const BLADE := "coop-first-snow-blade"
const MIASMA := "coop-first-miasma"
const BURIAL := "coop-first-burial"
const NIGHT := "每个己方回合一次，敌方式神气绝时，随机为一个己方式神恢复2点生命，重复该式神基础力量的次数，然后切换为落英缤纷。"
const FLAME_DETAILS := ["使被击杀式神气绝倒计时+1", "获得2点力量", "恢复3点生命或使自身气绝倒计时-1", "对敌方牌手造成3点伤害"]

static func source(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and int(unit.get("level", 0)) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func realms(gs, owner: int, kind: String) -> Array:
	return gs.player(owner).realms.filter(func(realm): return realm.get("nativeRealm") == kind and int(realm.hp) > 0)

static func frame(gs, owner: int, kind: String, data: Dictionary = {}) -> void:
	gs.resolution_stack.append({"kind": "coop-first-" + kind, "playerIndex": owner}.merged(data))

static func prepare_face(gs, owner: int, card: Dictionary) -> Dictionary:
	card = describe(gs, owner, card)
	if card.get("effect") != BLADE or not card.get("coopBond", false) or legal_enemies(gs, owner).is_empty(): return card
	var face := card.duplicate(true)
	face.target = "enemy-unit"
	return face

static func legal_enemies(gs, owner: int) -> Array:
	return Choice.live_units(gs, 1-owner).filter(func(unit): return not gs.VerifiedRules.Combat.has(unit, "veil") and not gs.VerifiedRules.Movement.has_veil(unit))

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") == "coop-first-ice-seal" or (card.get("effect") == BLADE and card.get("target") == "enemy-unit"):
		return legal_enemies(gs, owner).map(func(unit): return str(unit.uid))
	if card.get("effect") == "coop-first-draw-form":
		return gs.player(owner).units.filter(func(unit): return gs.VerifiedRules.OwlInsect.shikigami(unit) and not unit.get("removed", false)).map(func(unit): return unit.uid)
	return null

static func avatar_damaged(gs, owner: int, src: int, victim: int, damage: int) -> void:
	if owner < 0 or src < 0 or src >= gs.player(owner).units.size() or owner == victim or damage <= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if active(unit) and unit.get("coopFirstBlade", false): unit.coopFirstBladeTurn = gs.turn_counter

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("type") != "combat": return card
	var idx := source(gs, owner, str(card.get("unitId", "")))
	if idx < 0: return card
	var unit: Dictionary = gs.player(owner).units[idx]
	var blade: bool = int(unit.get("coopFirstBladeTurn", -1)) == gs.turn_counter
	var flame: Array = unit.get("coopFirstFlames", [])
	if not blade and flame.is_empty(): return card
	var result := card.duplicate(true)
	if blade and not gs._kw(result, "instant"): result.keywords.append("instant")
	if blade: result.text += "\n本回合获得瞬发及额外+1力量/+1护甲。"
	if not flame.is_empty():
		result.text += "\n豪焰：本次战斗额外+%d力量/+%d护甲。击杀式神后，%s。" % [flame.size(), flame.size(), flame_details(unit)]
	return result

static func flame_details(unit: Dictionary) -> String:
	var effects: Array = unit.get("coopFirstFlames", [])
	return "、".join(effects.map(func(index): return FLAME_DETAILS[int(index)]))

static func combat_stats(gs, owner: int, src: int, options: Dictionary) -> Dictionary:
	var unit: Dictionary = gs.player(owner).units[src]
	var card: Dictionary = options.get("combatCard", {})
	if card.is_empty() and not options.get("basicAttack", false) and int(gs._hand_combat_context.get("playerIndex", -1)) == owner and int(gs._hand_combat_context.get("sourceIndex", -1)) == src:
		card = gs._hand_combat_context.get("card", {})
	var result := {"attack":0,"armor":0}
	if card.is_empty(): return result
	if int(unit.get("coopFirstBladeTurn", -1)) == gs.turn_counter:
		result.attack += 1
		result.armor += 1
	var flames: Array = unit.get("coopFirstFlames", [])
	if not flames.is_empty():
		result.attack += flames.size()
		result.armor += flames.size()
		options.coopFirstFlames = flames.duplicate()
	return result

static func combat_finished(gs, owner: int, src: int, defender: Dictionary, options: Dictionary, kills: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.get("coopFirstCrane", false) and active(unit):
		var previous := int(unit.front)
		unit.front = 0
		gs.VerifiedRules.Movement.moved(gs, owner, src, previous)
		unit.cranePower = int(unit.get("cranePower", 0)) + 1
		gs._recalc(unit)
		gs._heal_unit(unit, int(unit.maxHp))
	if kills <= 0 or defender.is_empty() or gs._unit_index_by_uid(1-owner, defender.uid) < 0 or not gs.VerifiedRules.OwlInsect.shikigami(defender): return
	for flame in options.get("coopFirstFlames", []):
		match int(flame):
			0: gs.VerifiedRules.Countdown.change(gs, 1-owner, gs._unit_index_by_uid(1-owner, defender.uid), 1, owner)
			1:
				if int(unit.hp) > 0:
					unit.temporaryAttack = int(unit.get("temporaryAttack", 0)) + 2
					gs._recalc(unit)
			2:
				if int(unit.hp) > 0: gs._heal_unit(unit, 3)
				else: gs.VerifiedRules.Countdown.change(gs, owner, src, -1)
			3: gs.VerifiedRules.base_damage_avatar(gs, owner, src, 1-owner, 3)
	if not options.get("coopFirstLearnFlame", false): return
	var learned: Array = unit.get("coopFirstFlames", [])
	var pool: Array = [0,1,2,3].filter(func(i): return i not in learned)
	if not pool.is_empty():
		var next: int = pool[int(gs.next_random() % pool.size())]
		learned.append(next)
		unit.coopFirstFlames = learned
		gs.VerifiedRules.event(gs, "coop-flame-learned", {"player":owner,"uid":unit.uid,"effect":next})

static func prevents_lethal(gs, owner: int, idx: int, damage: int) -> bool:
	var unit: Dictionary = gs.player(owner).units[idx]
	if damage < int(unit.hp) or int(unit.front) != 0 or not gs.VerifiedRules.OwlInsect.shikigami(unit): return false
	var peach := source(gs, owner, "taohuayao")
	if peach < 0: return false
	var caster: Dictionary = gs.player(owner).units[peach]
	if not active(caster) or not caster.get("formRules", {}).get("coopFirstPeach", false): return false
	gs.VerifiedRules.Forms.remove(gs, owner, peach, "桃红簇簇抵消致命伤害")
	return true

static func power(gs, unit: Dictionary) -> int:
	var result := int(unit.get("coopFirstSnowPower", 0))
	if int(unit.get("armorBreak", 0)) > 0 and gs.VerifiedRules.OwlInsect.shikigami(unit): result -= miasma_count(gs, unit)
	return result

static func miasma_count(gs, unit: Dictionary) -> int:
	for owner in gs.players.size():
		if gs._unit_index_by_uid(owner, unit.uid) >= 0: return realms(gs, 1-owner, MIASMA).size()
	return 0

static func has_miasma(gs, unit: Dictionary) -> bool:
	return miasma_count(gs, unit) > 0

static func end_turn(gs) -> void:
	for owner in gs.players.size():
		var player: Dictionary = gs.player(owner)
		var idx := source(gs, owner, "xuetongzi")
		if idx < 0: continue
		var unit: Dictionary = player.units[idx]
		if unit.has("coopFirstSnowPower") or unit.has("coopFirstSnowPierce") or unit.has("coopFirstSnowSwift"):
			unit.erase("coopFirstSnowPower")
			unit.erase("coopFirstSnowPierce")
			unit.erase("coopFirstSnowSwift")
			gs._recalc(unit)

static func knocked_out(gs, owner: int, unit: Dictionary) -> void:
	if owner < 0 or unit.get("removed", false): return
	unit.erase("coopFirstBladeTurn")
	unit.erase("coopFirstSnowPower")
	unit.erase("coopFirstSnowPierce")
	unit.erase("coopFirstSnowSwift")
	petals(gs, 1-owner, unit, "night")
	if not gs.VerifiedRules.Coffin.can_transform(unit): return
	for realm in realms(gs, owner, BURIAL):
		if int(realm.get("coopFirstTurn", -1)) == gs.turn_counter: continue
		realm.coopFirstTurn = gs.turn_counter
		frame(gs, owner, "coffin", {"target":unit.uid,"realm":realm.uid})
		break

static func revived(gs, owner: int, idx: int) -> void:
	if idx >= 0: petals(gs, owner, gs.player(owner).units[idx], "day")

static func petals(gs, owner: int, cause: Dictionary, mode: String) -> void:
	if gs.current_player != owner or not gs.VerifiedRules.OwlInsect.shikigami(cause): return
	var idx := source(gs, owner, "yinghuayao")
	if idx < 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	var used := "coopFirstSakura-" + mode
	if not active(unit) or unit.get("formRules", {}).get("coopFirstSakura") != mode or int(unit.get(used, -1)) == gs.turn_counter: return
	unit[used] = gs.turn_counter
	frame(gs, owner, "petals", {"sourceIndex":idx,"mode":mode,"count":maxi(0,int(cause.get("baseAttack",0)))})

static func armor_event(gs, kind: String, details: Dictionary) -> void:
	var recipient := int(details.get("victimPlayer", -1) if kind == "armor-break-gained" else details.get("player", -1))
	if recipient < 0: return
	var target: int = gs._unit_index_by_uid(recipient, str(details.get("target", "")))
	if target >= 0 and not realms(gs, 1-recipient, MIASMA).is_empty(): gs._recalc(gs.player(recipient).units[target])
	if kind != "armor-break-gained": return
	for realm in realms(gs, recipient, MIASMA):
		if int(realm.get("coopFirstTurn", -1)) == gs.turn_counter: continue
		realm.coopFirstTurn = gs.turn_counter
		frame(gs, recipient, "miasma-wave")

static func event(gs, kind: String, details: Dictionary) -> void:
	match kind:
		"armor-break-gained", "armor-break-consumed": armor_event(gs, kind, details)
		"realm-destroyed", "realm-moved":
			if details.get("nativeRealm") == MIASMA:
				for unit in gs.player(1-int(details.player)).units: gs._recalc(unit)
		"stun-applied":
			if not details.get("newStun", false): return
			var owner := 1-int(details.player)
			var idx := source(gs, owner, "xuetongzi")
			if idx < 0: return
			var blades := realms(gs, owner, BLADE).size()
			if blades == 0: return
			var unit: Dictionary = gs.player(owner).units[idx]
			if not active(unit): return
			match gs.VerifiedRules.Stun.count(gs, 1-owner):
				1: unit.coopFirstSnowPower = int(unit.get("coopFirstSnowPower", 0)) + blades
				2: unit.coopFirstSnowSwift = gs.turn_counter
				_: unit.coopFirstSnowPierce = true
			gs._recalc(unit)
		"unit-moved":
			var owner := int(details.player)
			var idx := source(gs, owner, "taohuayao")
			var target: int = gs._unit_index_by_uid(owner, details.uid)
			if idx < 0 or target < 0: return
			var caster: Dictionary = gs.player(owner).units[idx]
			var unit: Dictionary = gs.player(owner).units[target]
			if active(caster) and caster.get("formRules", {}).get("coopFirstPeach", false) and gs.VerifiedRules.OwlInsect.shikigami(unit):
				gs.VerifiedRules.Peach.heal(gs, owner, idx, owner, unit, 2)

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("coop-first-"): return false
	var unit: Dictionary = gs.player(owner).units[src]
	var bond: bool = card.get("coopBond", false)
	match action:
		"coop-first-blade-awake", "coop-first-crane-awake":
			var blade := action == "coop-first-blade-awake"
			if unit.awakened:
				var stats: Dictionary = effect.value
				gs.VerifiedRules.Glutton.record_permanent(unit, int(stats.attack), int(stats.hp))
				gs._grow_unit(unit, int(stats.attack), int(stats.hp))
			else:
				gs._awaken(owner, src, card, effect.value)
			unit.passive_hooks = []
			unit["coopFirstBlade" if blade else "coopFirstCrane"] = true
			if blade:
				unit.erase("yaodaoFreeCombatTurn")
				unit.erase("yaodaoInstantTurn")
			if bond: Choice.attack(gs, owner, source(gs, owner, "guniao" if blade else "yaodaoji"))
		"coop-first-drink":
			unit.combatUnyielding = true
			var hit: Dictionary = gs._damage_unit(owner, src, 3, owner, src)
			gs._grant_unit_armor(unit, int(hit.get("damage", 0)))
			if bond:
				var other := source(gs, owner, "caitongzi")
				var level := int(gs.player(owner).units[other].level)
				var pool := Content.cards_for_unit("caitongzi").filter(func(c): return c.type == "combat" and int(c.level) == level and not c.get("skin", false))
				if not pool.is_empty(): Choice.give(gs, owner, pool[int(gs.next_random() % pool.size())].id)
			gs._resolve_combat(owner, src, 0, false, false, false, false, target_id, false, {"combatCard":card,"unyielding":true})
		"coop-first-flame":
			if bond:
				var other := source(gs, owner, "jutun-tongzi")
				gs._damage_unit(owner, other, 1, owner, other)
				gs._grant_unit_armor(unit, 2)
			gs._resolve_combat(owner, src, 0, false, false, false, false, target_id, false, {"combatCard":card,"coopFirstLearnFlame":true})
		"coop-first-ice-seal":
			var victim: int = gs._unit_index_by_uid(1-owner, target_id)
			if victim < 0: return true
			gs.VerifiedRules.Stun.apply(gs, 1-owner, victim, 1, owner, src)
			gs.VerifiedRules.Xuenv.token(gs, owner)
			if bond: Choice.attack(gs, owner, source(gs, owner, "xuetongzi"), target_id, {"pursuit":true})
		BLADE:
			gs._deploy_realm(owner, card)
			var victim: int = gs._unit_index_by_uid(1-owner, target_id)
			if bond and victim >= 0: gs.VerifiedRules.Stun.apply(gs, 1-owner, victim, 1, owner, source(gs, owner, "xuenv"))
		"coop-first-draw-form":
			if bond:
				var other := source(gs, owner, "bailang")
				gs.VerifiedRules.ZenMisfortune.attach_blessing(gs, owner, gs.player(owner).units[other])
			if not target.is_empty(): draw_form(gs, owner, target)
		"coop-first-arrow":
			var options := {"combatCard":card}
			if bond:
				var other := source(gs, owner, "yingcao")
				gs.VerifiedRules.Firefly.form_turn_start(gs, owner, other)
				options.butterflyEncourageCombat = true
			gs._grant_unit_armor(unit, 1)
			var power := 1 + int(unit.get("untilAttack", {}).get("attack", 0))
			gs._resolve_combat(owner, src, power, false, false, false, false, target_id, false, options)
		"coop-first-peach", "coop-first-sakura":
			if bond: frame(gs, owner, "form-bond", {"effect":action})
			gs._apply_form(owner, src, card, effect.value)
		MIASMA:
			gs._deploy_realm(owner, card)
			for enemy in gs.player(1-owner).units: gs._recalc(enemy)
			if bond: gs.VerifiedRules.Countdown.change(gs, owner, source(gs, owner, "tiaotiaogege"), -1)
		BURIAL:
			gs._deploy_realm(owner, card)
			var victim: int = gs.front_index(1-owner)
			if bond and victim >= 0:
				var other := source(gs, owner, "tiaotiaodidi")
				var amount: int = gs.VerifiedRules.ArmorBreak.consume(gs, owner, other)
				gs.VerifiedRules.ArmorBreak.give(gs, owner, other, 1-owner, victim, amount, false)
		_: return false
	return true

static func draw_form(gs, owner: int, target: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	var candidates: Array = p.deck.filter(func(inst):
		var card := Content.card_def(str(inst.definitionId))
		return card.get("unitId") == target.id and card.get("type") == "form" and int(card.level) <= int(target.level))
	if candidates.is_empty(): return
	var picked: Dictionary = candidates[int(gs.next_random() % candidates.size())]
	if int(target.hp) > 0 and int(target.attack) >= 6:
		p.deck.erase(picked)
		frame(gs, owner, "cast-form", {"instance":picked,"target":target.uid})
	else:
		gs._draw(owner, 1, -1, {"drawInstanceId":picked.instanceId})

static func resolve_frame(gs, item: Dictionary) -> bool:
	var kind := str(item.get("kind", ""))
	if not kind.begins_with("coop-first-"): return false
	var owner := int(item.playerIndex)
	var p: Dictionary = gs.player(owner)
	match kind:
		"coop-first-miasma-wave":
			var src := source(gs, owner, "tiaotiaodidi")
			gs.VerifiedRules.ArmorBreak.give(gs, owner, src, 1-owner, -1, 1)
			for idx in gs.player(1-owner).units.size():
				var enemy: Dictionary = gs.player(1-owner).units[idx]
				if int(enemy.hp) > 0 and not enemy.get("removed", false):
					gs.VerifiedRules.ArmorBreak.give(gs, owner, src, 1-owner, idx, 1)
		"coop-first-coffin":
			var idx: int = gs._unit_index_by_uid(owner, item.target)
			if idx < 0: return true
			var unit: Dictionary = p.units[idx]
			if int(unit.hp) > 0 or not gs.VerifiedRules.Coffin.can_transform(unit): return true
			var free := str(unit.id) in ["tiaotiaodidi", "tiaotiaomeimei"]
			if free:
				gs.VerifiedRules.Glutton.record_permanent(unit, 0, 1)
				gs._grow_unit(unit, 0, 1)
			gs.VerifiedRules.Coffin.make_coffin(gs, owner, idx)
			if free or not unit.has("jumpCoffin"): return true
			for realm in p.realms.duplicate():
				if realm.uid != item.realm: continue
				realm.hp = int(realm.hp)-2
				gs.VerifiedRules.event(gs, "realm-durability", {"player":owner,"realm":realm.uid,"amount":2,"remaining":maxi(0,int(realm.hp))})
				if int(realm.hp) <= 0: gs.VerifiedRules.Huang.destroy(gs, owner, realm, "棺葬耐久耗尽")
		"coop-first-cast-form":
			var idx: int = gs._unit_index_by_uid(owner, item.target)
			if idx < 0 or int(p.units[idx].hp) <= 0: return true
			var inst: Dictionary = item.instance
			var card := Content.card_def(str(inst.definitionId)).duplicate(true)
			card.playedInstance = inst
			gs._push_card_frames(owner, str(card.id), null, card, idx, 0, true)
		"coop-first-form-bond":
			if item.effect == "coop-first-peach":
				var src := source(gs, owner, "yinghuayao")
				if src >= 0:
					for target in p.units:
						if gs.VerifiedRules.OwlInsect.shikigami(target): gs.VerifiedRules.TreeSakura.recover(gs, owner, src, str(target.uid), 2)
			else:
				var src := source(gs, owner, "taohuayao")
				var injured: Array = p.units.filter(func(unit): return int(unit.hp) > 0 and int(unit.hp) < int(unit.maxHp) and not unit.get("removed", false))
				if int(p.avatarHp) < int(p.maxAvatarHp): injured.append({"avatar":true})
				if src >= 0 and not injured.is_empty():
					var picked: Dictionary = injured[int(gs.next_random() % injured.size())]
					if picked.get("avatar", false): gs._heal_avatar(owner, 3)
					else: gs.VerifiedRules.Peach.heal(gs, owner, src, owner, picked, 3)
		"coop-first-petals":
			var src := int(item.sourceIndex)
			var unit: Dictionary = p.units[src]
			var day: bool = item.mode == "day"
			if int(item.count) > 0 and gs.winner < 0:
				var targets: Array = Choice.live_units(gs, 1-owner) if day else p.units.filter(func(target): return gs.VerifiedRules.OwlInsect.shikigami(target) and not target.get("removed", false))
				if not targets.is_empty():
					var target: Dictionary = targets[int(gs.next_random() % targets.size())]
					item.count = int(item.count) - 1
					gs.resolution_stack.append(item)
					if day:
						gs.VerifiedRules.base_damage_unit(gs, owner, src, 1-owner, gs._unit_index_by_uid(1-owner, target.uid), 1)
					else:
						gs.VerifiedRules.TreeSakura.recover(gs, owner, src, str(target.uid), 2)
					return true
			if unit.get("formRules", {}).get("coopFirstSakura") != item.mode: return true
			unit.formRules.coopFirstSakura = "night" if day else "day"
			unit.form.name = "晚樱之意" if day else "落英缤纷"
			unit.form.coopFaceArt = "assets/official/cooperation/c108184-yinghuayao%s.png" % ("-night" if day else "")
			unit.formAbility = NIGHT if day else Content.card_def("c108184").coopFaces[1].text
		_: return false
	return true
