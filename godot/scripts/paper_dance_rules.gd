class_name PaperDanceRules
extends RefCounted

const UNIT := "zhiwu"
const NATIVE_CHARMS := {
	"陨星": "shenqiMeteors", "游记": "travelNotes", "咒纱": "curseGauze", "缠心咒纱": "curseGauze",
	"折敷": "servingTray", "八尺琼勾玉": "abyssJade",
	"剑神通": "sword", "火神通": "fire", "水神通": "water",
}

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": UNIT})

static func shikigami(gs, unit: Dictionary) -> bool:
	return gs.VerifiedRules.OwlInsect.shikigami(unit) and int(unit.get("hp", 0)) > 0

static func charms(owner: int, unit: Dictionary) -> int:
	var count := 0
	for key in ["paperFall", "owlGuard", "moonCharm", "waterLumen", "waterReturnLight", "seaSpirit", "whaleTooth", "whaleBody", "vineCharm", "gluttonSatiation", "goldfishAttached", "dragonDry", "dragonWet"]:
		if unit.has(key) and unit[key]: count += 1
	count += unit.get("onikiriCharms", []).size()
	count += unit.get("akibaCharms", []).size()
	if int(unit.get("curseGauze", 0)) > 0: count += 1
	if int(unit.get("travelNotes", 0)) > 0: count += 1
	if int(unit.get("shenqiMeteors", 0)) > 0: count += 1
	if unit.get("servingTray", false): count += 1
	if owner in unit.get("abyssJades", []): count += 1
	if unit.get("otakeJades", {}).has(str(owner)): count += 1
	if int(unit.get("crocCharm", {}).get("owner", -1)) == owner: count += 1
	if int(unit.get("garudaFeather", {}).get("sourceOwner", -1)) == owner: count += 1
	return count

static func power(unit: Dictionary) -> int:
	if not unit.get("paperFall", false): return 0
	return 3 if charms(int(unit.paperFallOwner), unit) >= 3 else 1

static func refresh(gs, owner: int) -> void:
	if source(gs, owner) < 0: return
	for unit in gs.player(owner).units:
		if unit.get("paperFall", false): gs._recalc(unit)

static func count_carriers(gs, owner: int) -> int:
	return gs.player(owner).units.filter(func(u): return shikigami(gs, u) and charms(owner, u) > 0).size()

static func _grant(gs, owner: int, unit: Dictionary) -> void:
	if not shikigami(gs, unit): return
	unit.paperFall = true
	unit.paperFallOwner = owner
	gs._recalc(unit)
	gs.VerifiedRules.event(gs, "paper-fall-attached", {"player": owner, "uid": unit.uid})

static func _source_for_event(gs, owner: int, details: Dictionary) -> int:
	return gs._unit_index_by_uid(owner, str(details.get("uid", "")))

static func event(gs, kind: String, details: Dictionary) -> void:
	var owner := int(details.get("player", -1))
	if owner < 0 or owner >= gs.players.size(): return
	var src := source(gs, owner)
	if src < 0: return
	if kind in ["otake-jade-removed", "vine-removed", "crocodile-detached", "glutton-satiation-removed", "shenqi-meteor-removed"]:
		refresh(gs, owner)
		return
	var target_uid := str(details.get("target", details.get("uid", "")))
	var idx: int = gs._unit_index_by_uid(owner, target_uid)
	if idx < 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	if not shikigami(gs, unit): return
	if kind == "unit-moved" and int(details.get("front", 0)) == 1:
		for realm in gs.player(owner).realms:
			if int(realm.hp) > 0 and realm.get("nativeRealm") == "paper-lodge": _grant(gs, owner, unit)
		return
	var key := ""
	var info := {"kind": kind, "sourceIndex": _source_for_event(gs, owner, details), "details": details.duplicate(true)}
	match kind:
		"paper-fall-attached": key = "paperFall"
		"charm-attached":
			if int(details.get("sourcePlayer", owner)) == owner: key = str(NATIVE_CHARMS.get(details.get("charm", ""), ""))
		"dragon-breath-attached": key = str(details.get("mode", ""))
		"owl-attached": key = "owlGuard"
		"moon-attached": key = "moonCharm"
		"sea-spirit-attached": key = "seaSpirit"
		"water-spirit-charm": key = str(details.charm)
		"whale-charm-attached": key = str(details.charm)
		"onikiri-charm-attached": key = str(details.charm)
		"otake-jade-attached":
			if int(details.carrierPlayer) == owner: key = "jade"
		"vine-attached": key = "vine"
		"crocodile-attached": key = "crocCharm"
		"garuda-feather-attached": key = "garudaFeather"
		"glutton-satiated": key = "gluttonSatiation"
		"goldfish-attached": key = "goldfishAttached"
	if key.is_empty(): return
	var history: Dictionary = unit.get("paperCharmHistory", {})
	if key != "paperFall":
		history[key] = info
		unit.paperCharmHistory = history
	refresh(gs, owner)
	var master: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.BondDream.active(master): return
	var form: Dictionary = master.get("formRules", {})
	if key == "paperFall" and form.get("paperReplay", false):
		var replay: Array = history.values().duplicate(true)
		replay.reverse()
		for entry in replay:
			gs.resolution_stack.append({"kind": "paper-replay", "playerIndex": owner, "uid": unit.uid, "entry": entry})
	if idx == src and gs.current_player == owner and form.get("paperCounter", false) and int(unit.get("paperAttackTurn", -1)) != gs.turn_counter:
		unit.paperAttackTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "paper-attack", "playerIndex": owner, "uid": unit.uid})
	var projector: Dictionary = unit if master.awakened else master
	if (master.awakened or idx == src or key == "paperFall") and int(projector.get("paperProjectileTurn", -1)) != gs.turn_counter:
		projector.paperProjectileTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "paper-projectile", "playerIndex": owner, "uid": projector.uid})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.kind)
	if not kind.begins_with("paper-"): return false
	var owner := int(frame.playerIndex)
	var idx: int = gs._unit_index_by_uid(owner, str(frame.uid))
	if idx < 0: return true
	var unit: Dictionary = gs.player(owner).units[idx]
	if not shikigami(gs, unit): return true
	match kind:
		"paper-grant":
			_grant(gs, owner, unit)
		"paper-projectile":
			gs.VerifiedRules.base_damage_projectile(gs, owner, idx, 1)
		"paper-attack":
			gs._resolve_combat(owner, idx, 0, false, false, false, false, null, false, {"immuneCombat": true, "paperLethalRed": frame.get("lethal", false)})
		"paper-replay":
			var entry: Dictionary = frame.entry
			var src := int(entry.sourceIndex)
			var details: Dictionary = entry.details
			match str(entry.kind):
				"owl-attached":
					if src >= 0: gs.VerifiedRules.OwlInsect.attach_guard(gs, owner, src, idx)
				"moon-attached": gs.VerifiedRules.Moon.attach(gs, owner, idx)
				"charm-attached":
					var charm := str(details.get("charm", ""))
					var abyss = gs.VerifiedRules.DragonAbyss
					match charm:
						"陨星": gs.VerifiedRules.ShenqiHuang.attach(gs, owner, idx, 1)
						"游记": abyss.Travel.gain(gs, owner)
						"咒纱", "缠心咒纱": abyss.Curse.give(gs, owner, unit, 1, charm == "缠心咒纱")
						"折敷": abyss.Serving.give(gs, owner, unit)
						"八尺琼勾玉": abyss.Jade.give(gs, owner, owner, unit)
						"剑神通", "火神通", "水神通": abyss.Aki.give(gs, owner, unit, str(NATIVE_CHARMS[charm]))
				"dragon-breath-attached": gs.VerifiedRules.DragonFlow.attach(gs, owner, idx, str(details.mode))
				"sea-spirit-attached":
					if src >= 0: gs.VerifiedRules.SeaButterfly.attach(gs, owner, src, unit)
				"water-spirit-charm":
					gs.VerifiedRules.WaterMoon.grant(gs, owner, unit, "waterLumen" if details.charm == "流明" else "waterReturnLight", str(details.charm))
				"whale-charm-attached":
					if src >= 0: gs.VerifiedRules.Whale.attach(gs, owner, src, unit, str(details.charm), bool(details.permanent))
				"onikiri-charm-attached": gs.VerifiedRules.Onikiri.attach(gs, owner, idx, str(details.charm))
				"otake-jade-attached":
					var wielder: Dictionary = gs.VerifiedRules.Otakemaru.master(gs, owner)
					if not wielder.is_empty(): gs.VerifiedRules.Otakemaru.attach(gs, owner, gs._unit_index_by_uid(owner, wielder.uid), owner, idx)
				"vine-attached": gs.VerifiedRules.Vine.attach(gs, owner, idx)
				"crocodile-attached":
					if src >= 0: gs.VerifiedRules.Crocodile.attach(gs, owner, src, unit)
				"garuda-feather-attached":
					if src >= 0: gs.VerifiedRules.Garuda.attach(gs, owner, src, unit)
				"glutton-satiated": gs.VerifiedRules.Glutton.attach(gs, owner, idx)
				"goldfish-attached": gs.VerifiedRules.Goldfish.attach(gs, owner, idx)
	return true

static func _grant_card(gs, owner: int) -> void:
	var inst := {"instanceId": "%s-o%d" % [gs.player(owner).id, gs.next_card_id], "definitionId": "c63301"}
	gs.next_card_id += 1
	inst.paperInstant = true
	gs.VerifiedRules.SandBook.obtain(gs, owner, inst)

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if gs.VerifiedRules.BondDream.active(unit) and unit.get("formRules", {}).get("paperReplay", false): _grant_card(gs, owner)

static func realm_turn(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "paper-sun": return false
	gs.VerifiedRules.Divination.start(gs, owner, count_carriers(gs, owner))
	return true

static func describe(gs, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not inst.get("paperInstant", false): return card
	var view := card.duplicate(true)
	if not gs._kw(view, "instant"): view.keywords.append("instant")
	return view

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id", "") not in ["c63301", "c63304", "c63305"]: return null
	var side := 1-owner if card.id == "c63305" else owner
	return gs.player(side).units.filter(func(u):
		return shikigami(gs, u) and (card.id != "c63304" or u.id != UNIT) and (side == owner or not gs.VerifiedRules.Combat.has(u, "veil"))).map(func(u): return str(u.uid))

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	if not str(effect.action).begins_with("paper-"): return false
	var master: Dictionary = gs.player(owner).units[src]
	match str(effect.action):
		"paper-blade":
			_grant(gs, owner, target)
			if shikigami(gs, target):
				gs._grant_unit_armor(target, 1)
				if gs.VerifiedRules.Factions.get_faction(target) in ["青岚", "紫岩"]: target.swift = true
		"paper-awake":
			gs._awaken(owner, src, card, effect.value)
			if not target.is_empty(): gs.resolution_stack.append({"kind": "paper-grant", "playerIndex": owner, "uid": target.uid})
			_grant(gs, owner, master)
		"paper-realm":
			gs._deploy_realm(owner, card)
			if card.id == "c63302":
				gs.VerifiedRules.Divination.start(gs, owner, count_carriers(gs, owner))
			else:
				gs.VerifiedRules.HairPower.grant_guard(gs, owner, 0, 2)
		"paper-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.id == "c63308": _grant_card(gs, owner)
		"paper-swallow", "paper-strike":
			var allies: Array = [master]
			allies.append_array(gs.player(owner).units.filter(func(u): return u.uid != master.uid and shikigami(gs, u) and charms(owner, u) > 0))
			if effect.action == "paper-strike":
				allies.reverse()
				for unit in allies:
					gs.resolution_stack.append({"kind": "paper-attack", "playerIndex": owner, "uid": unit.uid, "lethal": true})
			else:
				var target_idx: int = gs._unit_index_by_uid(1-owner, str(target.get("uid", "")))
				if target_idx < 0: return true
				gs._damage_unit(1-owner, target_idx, 4 + count_carriers(gs, owner), owner, src)
	return true

static func score(gs, owner: int, card: Dictionary, target_id):
	if not str(card.get("effect", "")).begins_with("paper-"): return null
	var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, target_id)
	match str(card.id):
		"c63301": return 36 + (12 if not ally.get("paperFall", false) else 0) + (8 if gs.VerifiedRules.Factions.get_faction(ally) in ["青岚", "紫岩"] and not ally.get("swift", false) else 0)
		"c63302": return 20 + 9 * count_carriers(gs, owner)
		"c63305": return 56 + (20 if int(enemy.get("hp", 99)) + int(enemy.get("shield", 0)) <= 4 + count_carriers(gs, owner) else 0)
		"c63307": return 42 + 13 * count_carriers(gs, owner)
	return 52
