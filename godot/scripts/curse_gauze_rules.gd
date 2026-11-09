extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "huojinshen"

static func source(gs, owner: int) -> int:
	return gs.VerifiedRules.DragonAbyss.source(gs, owner, ID)

static func count(u: Dictionary) -> int:
	return int(u.get("curseGauze", 0))

static func give(gs, owner: int, u: Dictionary, amount: int = 1, awakened: bool = false) -> void:
	u.curseGauze = count(u) + amount
	if awakened: u.curseGauzeAwake = true
	gs._recalc(u)
	gs.VerifiedRules.event(gs, "charm-attached", {"player": owner, "uid": u.uid, "charm": "缠心咒纱" if awakened else "咒纱", "amount": amount})

static func leveled(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if u.id != ID or u.get("curseFirstLevel", false): return
	u.curseFirstLevel = true
	give(gs, owner, u, 7, u.awakened)

static func spend(gs, owner: int, u: Dictionary) -> bool:
	if count(u) == 0: return false
	u.curseGauze = count(u)-1
	gs._recalc(u)
	if count(u) != 0 or u.id != ID or gs.player(owner).get("curseAwakeningFound", false): return true
	var deck: Array = gs.player(owner).deck
	var i := deck.find_custom(func(inst): return inst.definitionId == "c64408")
	if i >= 0:
		gs.player(owner).curseAwakeningFound = true
		gs.VerifiedRules.Baize.put_hand(gs, owner, deck.pop_at(i))
	return true

static func transfer(gs, owner: int, u: Dictionary) -> bool:
	var src := source(gs, owner)
	if src < 0 or int(u.hp) <= 0: return false
	var caster: Dictionary = gs.player(owner).units[src]
	if not spend(gs, owner, caster): return false
	give(gs, owner, u, 1, caster.awakened)
	return true

static func damaged(gs, owner: int, idx: int, attacker: int, attacker_idx: int, amount: int) -> void:
	if attacker != 1-owner or amount <= 0: return
	var u: Dictionary = gs.player(owner).units[idx]
	if not gs.VerifiedRules.OwlInsect.shikigami(u): return
	var src := source(gs, owner)
	var awake: bool = src >= 0 and gs.VerifiedRules.OwlInsect.active(gs.player(owner).units[src]) and bool(gs.player(owner).units[src].awakened)
	if count(u) == 0:
		if awake: give(gs, owner, u, 1, true)
		return
	if int(u.get("curseDamageTurn", -1)) == gs.turn_counter: return
	u.curseDamageTurn = gs.turn_counter
	var upgraded: bool = u.get("curseGauzeAwake", false)
	spend(gs, owner, u)
	gs.resolution_stack.append({"kind": "curse-gauze-retaliate", "playerIndex": owner, "sourceIndex": idx, "attackerIndex": attacker_idx, "awakened": upgraded})

static func moved(gs, owner: int, idx: int, previous: int) -> void:
	var src := source(gs, owner)
	if src < 0 or src == idx or previous == 1: return
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.front) != 1 or not gs.VerifiedRules.PaperDance.shikigami(gs, u): return
	for r in gs.player(owner).realms:
		if r.get("nativeRealm") != "curse-banquet" or int(r.hp) <= 0 or int(r.get("curseMoveTurn", -1)) == gs.turn_counter: continue
		r.curseMoveTurn = gs.turn_counter
		if not transfer(gs, owner, u):
			gs.VerifiedRules.Glutton.record_permanent(u, 1, 1)
			gs._grow_unit(u, 1, 1)

static func revived(gs, owner: int, idx: int) -> void:
	var src := source(gs, owner)
	if src < 0 or src == idx or owner != gs.current_player: return
	for r in gs.player(owner).realms:
		if r.get("nativeRealm") != "curse-flowers" or int(r.hp) <= 0 or int(r.get("curseReviveTurn", -1)) == gs.turn_counter: continue
		r.curseReviveTurn = gs.turn_counter
		if transfer(gs, owner, gs.player(owner).units[idx]):
			gs.VerifiedRules.move_unit(gs, owner, gs.player(owner).units[idx])
		else: gs._heal_avatar(owner, 5)

static func power(u: Dictionary) -> int:
	return 5 if count(u) == 0 and u.get("formRules", {}).get("curseFlower", false) else 0

static func has_trait(u: Dictionary, key: String) -> bool:
	if count(u) != 0: return false
	if key == "pierce": return u.get("formRules", {}).get("curseFlower", false)
	if key in ["veil", "resolute"]: return u.get("formRules", {}).get("curseAyako", false)
	return false

static func described(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("unitId") != ID: return card
	var src := source(gs, owner)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	var c := card.duplicate(true)
	match str(c.id):
		"c64402":
			if count(u) == 0:
				c.keywords.append("lethal")
				c.combatOption.lethal = true
		"c64405":
			c.value = maxi(0, 9-count(u))
			c.effects[0].value = c.value
			c.currentCardStats = "当前伤害 %d" % c.value
	return c

static func target_has_charm(gs, owner: int, uid) -> bool:
	if uid == null: return false
	var u: Dictionary = gs._unit_by_uid(gs.player(owner).units, uid)
	return not u.is_empty() and gs.VerifiedRules.OwlInsect.shikigami(u) and (gs.VerifiedRules.PaperDance.charms(owner, u) > 0 or gs.VerifiedRules.PaperDance.charms(1-owner, u) > 0)

static func announced(gs, f: Dictionary, card: Dictionary) -> void:
	var owner := 1-int(f.playerIndex)
	var src := source(gs, owner)
	if src < 0 or not target_has_charm(gs, owner, f.get("targetId")) or str(card.get("unitId", "")).is_empty(): return
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0 or not u.get("formRules", {}).get("curseAyako", false): return
	gs.resolution_stack.append({"kind": "curse-gauze-tax", "playerIndex": owner, "sourceIndex": src})

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("id") != "c64401": return true
	return not gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "curse-banquet" and int(r.hp) > 0)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, e: Dictionary, target: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	var enemy := 1-owner
	match str(e.action):
		"abyss-curse-banquet":
			gs._deploy_realm(owner, card)
			gs.VerifiedRules.HairPower.grant_guard(gs, owner)
		"abyss-curse-combat": gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, target_id)
		"abyss-curse-form":
			gs._apply_form(owner, src, card, e.value)
			if not target.is_empty(): target.enraged = true
		"abyss-curse-whisper":
			if not target.is_empty(): gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, target.uid), int(e.value), owner, src)
		"abyss-curse-flowers":
			gs._deploy_realm(owner, card)
			if not target.is_empty(): gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false)
		"abyss-curse-prayer":
			for idx in range(gs.player(owner).units.size()-1, -1, -1):
				var ally: Dictionary = gs.player(owner).units[idx]
				if ally == u or ally.get("summoned", false) or (target_id != null and ally.uid != target_id): continue
				gs.resolution_stack.append({"kind": "curse-gauze-prayer", "playerIndex": owner, "sourceIndex": idx})
		"abyss-curse-awake":
			gs._awaken(owner, src, card, e.value)
			for ally in gs.player(owner).units:
				if count(ally) > 0: ally.curseGauzeAwake = true
		_: return false
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var owner := int(f.get("playerIndex", -1))
	var src := int(f.get("sourceIndex", -1))
	match f.get("kind"):
		"curse-gauze-retaliate":
			if not f.awakened:
				gs.VerifiedRules.base_damage_projectile(gs, owner, src, 1, "咒纱")
			else:
				var enemy := 1-owner
				var attacker := int(f.attackerIndex)
				gs._damage_avatar(enemy, 3 if attacker < 0 else 1, owner, src)
				for idx in gs.player(enemy).units.size():
					if int(gs.player(enemy).units[idx].hp) > 0: gs._damage_unit(enemy, idx, 3 if idx == attacker else 1, owner, src)
		"curse-gauze-prayer":
			if transfer(gs, owner, gs.player(owner).units[src]): gs.VerifiedRules.DragonAbyss.attack(gs, owner, src)
			else: gs._draw(owner, 1)
		"curse-gauze-tax":
			var enemy := 1-owner
			if int(gs.player(enemy).energy) > 0: gs._set_fire(enemy, int(gs.player(enemy).energy)-1, true)
			else: gs._damage_avatar(enemy, 3, owner, src)
		_: return false
	return true
