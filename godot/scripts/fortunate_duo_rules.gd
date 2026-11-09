extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const ID := "shantu-zuofu"
const DIE := "ruyishaizi"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func new_die(gs, owner: int) -> void:
	Choice.give(gs, owner, DIE, {"duoFace": 1+int(gs.next_random() % 6)})

static func refresh(gs, owner: int) -> void:
	for inst in gs.player(owner).hand:
		if inst.definitionId == DIE: inst.duoFace = 1+int(gs.next_random() % 6)

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	refresh(gs, owner)
	var u: Dictionary = gs.player(owner).units[src]
	if u.awakened and not u.get("baseRulesSuppressed", false): new_die(gs, owner)

static func rolled(gs, owner: int, source_idx: int, result: int, success: bool) -> int:
	var src := source(gs, owner)
	if src >= 0:
		var p: Dictionary = gs.player(owner)
		var duo: Dictionary = p.units[src]
		if not duo.get("baseRulesSuppressed", false):
			p.duoRollCount = int(p.get("duoRollCount", 0))+1
			var threshold := 3 if duo.awakened else 4
			if int(p.duoRollCount) % threshold == 0: new_die(gs, owner)
	if success:
		var roller: Dictionary = gs.player(owner) if source_idx < 0 else gs.player(owner).units[source_idx]
		if roller.has("duoFixedRoll"):
			var selected := int(roller.duoFixedRoll)
			roller.erase("duoFixedRoll")
			return selected
	return result

static func die_view(gs, owner: int, card: Dictionary, value: int) -> Dictionary:
	var out := card.duplicate(true)
	var src := source(gs, owner)
	out.value = value
	out.effects[0].value = value
	out.currentCardStats = "指定点数：%d" % value
	if src >= 0 and gs.player(owner).units[src].awakened: out.cost = 0
	return out

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var src := source(gs, owner)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	if card.id == DIE: return die_view(gs, owner, card, int(inst.get("duoFace", 1)))
	if card.id == "c61602" and int(u.level) < 3:
		var trick := die_view(gs, owner, Content.card_def(DIE), 0)
		trick.id = card.id
		trick.name = card.name
		trick.currentCardStats = "戏法 · 0点如意骰子"
		return trick
	if card.id == "c61601" and int(gs.player(owner).get("duoDieTurn", -1)) == gs.turn_counter:
		var out := card.duplicate(true)
		out.keywords.append("lethal")
		out.combatOption.lethal = true
		return out
	if card.id == "c61604":
		var out := card.duplicate(true)
		var origin := Content.card_def("c12711").duplicate(true)
		origin.unitId = ID
		out.originCard = origin
		return out
	return card

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.id == "c61608":
		return not gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "duo-golden" and int(r.hp) > 0)
	return true

static func before_attack(gs, frame: Dictionary) -> void:
	if frame.get("duoOffered", false): return
	frame.duoOffered = true
	var attacking := int(frame.playerIndex)
	var attacker: Dictionary = gs.player(attacking).units[int(frame.sourceIndex)]
	if attacker.id == ID and attacker.get("formRules", {}).get("duoFast", false): refresh(gs, attacking)
	if not gs.VerifiedRules.OwlInsect.shikigami(attacker): return
	for owner in [attacking, 1-attacking]:
		var src := source(gs, owner)
		if src < 0: continue
		var u: Dictionary = gs.player(owner).units[src]
		if not gs.VerifiedRules.OwlInsect.active(u) or not u.get("formRules", {}).get("duoPeace", false): continue
		var key := "duoPeaceAllyTurn" if owner == attacking else "duoPeaceEnemyTurn"
		if int(u.get(key, -1)) == gs.turn_counter: continue
		u[key] = gs.turn_counter
		var success: bool = gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src)
		if owner == attacking and success: attacker.barrier = true
		if owner != attacking and not success:
			attacker.duoZeroTurn = gs.turn_counter
			frame.options.lightZeroAttack = true

static func golden(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "duo-golden": return false
	var src := source(gs, owner)
	if src < 0 or not gs.VerifiedRules.Light.roll(gs, owner, 1): return true
	var p: Dictionary = gs.player(owner)
	var enemy := 1-owner
	for i in gs.VerifiedRules.Fortune.last_repeats(gs, owner):
		match int(gs.kw_usage(owner, "fortune").last.roll):
			1:
				var damage := int(p.get("duoGoldenRed", 4))
				p.duoGoldenRed = mini(30, damage*2)
				gs._damage_avatar(enemy, damage, owner, src)
			2:
				var front: int = gs.front_index(enemy)
				if front >= 0: gs.VerifiedRules.HairPower.give(gs, enemy, front, -2)
				else:
					var cue: Dictionary = gs.kw_usage(enemy, "encourage")
					cue.battlePower = int(cue.get("battlePower", 0))-2
				gs.VerifiedRules.ArmorBreak.give(gs, enemy, front, owner, src, 1, false)
			3:
				for u in Choice.live_units(gs, enemy): gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, u.uid), 2, owner, src)
			4: gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1, 1)
			5:
				gs._set_fire(owner, int(p.energy)+1)
				gs._draw(owner, 1)
			6:
				var recovery := int(p.get("duoGoldenSafe", 4))
				p.duoGoldenSafe = mini(30, recovery*2)
				gs._heal_avatar(owner, recovery)
		if gs.winner >= 0: break
	return true

static func position(gs, target_id) -> Vector2i:
	if str(target_id).begins_with("avatar-"): return Vector2i(int(str(target_id).get_slice("-", 1)), -1)
	for side in 2:
		var idx: int = gs._unit_index_by_uid(side, target_id)
		if idx >= 0: return Vector2i(side, idx)
	return Vector2i(-1, -1)

static func use_die(gs, owner: int, src: int, points: int, target_id) -> void:
	var pos := position(gs, target_id)
	if pos.x < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	var victim: Dictionary = gs.player(pos.x) if pos.y < 0 else gs.player(pos.x).units[pos.y]
	victim.duoFixedRoll = points
	gs.player(owner).duoDieTurn = gs.turn_counter
	if pos.y >= 0 and u.get("formRules", {}).get("duoNewYear", false):
		var amount := 1 if owner == pos.x else -1
		gs._grow_unit(victim, amount, amount)
	if u.awakened and points > 0: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, points, "如意骰子")

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if src < 0 or not action.begins_with("duo-"): return false
	var u: Dictionary = gs.player(owner).units[src]
	match action:
		"duo-die": use_die(gs, owner, src, int(effect.value), target_id)
		"duo-awaken": gs._awaken(owner, src, card, effect.value)
		"duo-hit":
			var enemy := 1-owner
			var idx: int = gs._unit_index_by_uid(enemy, target_id)
			if idx < 0 or not gs.VerifiedRules.Light.roll(gs, owner, 1, 6, src): return true
			var number := int(gs.kw_usage(owner, "fortune").last.roll)
			for i in gs.VerifiedRules.Fortune.last_repeats(gs, owner):
				var hit: Dictionary = gs._damage_unit(enemy, idx, number, owner, src)
				if int(hit.get("damage", 0)) > 0 and number == int(target.attack) and int(target.hp) > 0:
					gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, idx, card)
		"duo-rope":
			new_die(gs, owner)
			gs.VerifiedRules.Movement.move_to(gs, owner, src, 1)
			var pos := position(gs, target_id)
			if pos.x < 0 or pos.y < 0 or int(target.hp) <= 0: return true
			if gs.VerifiedRules.Light.roll(gs, pos.x, 1, 6, pos.y):
				var number := int(gs.kw_usage(pos.x, "fortune").last.roll)
				if number <= 0: return true
				gs.VerifiedRules.Fortune.transform(gs, pos.x, pos.y, false, "fortune-duo-paper", "运势纸人", number)
				Choice.attack(gs, pos.x, pos.y)
		"duo-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.id == "c61605": u.swift = true; refresh(gs, owner)
			if card.id == "c61606": new_die(gs, owner)
		"duo-golden":
			gs._deploy_realm(owner, card)
			new_die(gs, owner)
			golden(gs, owner, gs.player(owner).realms.back())
		_: return false
	return true
