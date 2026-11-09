extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "wushi-maoshi"
const MEDITATE := "c62402"
const MUSASHI := "c62408"
const HEART := "maoshi-heart"
const GRUDGE := "maoshi-grudge"
const SEVER := "maoshi-sever"
const REVIVE := "cat-oath-revive"
const SACRIFICE := "cat-oath-sacrifice"

static func bodyless(gs, unit: Dictionary) -> bool:
	return unit.id == ID and gs.VerifiedRules.Samurai.ghost(unit)

static func describe(gs, owner: int, card: Dictionary, from_zone: bool) -> Dictionary:
	if not card.get("catRules", false): return card
	var out := card.duplicate(true)
	var src: int = gs._source_index(owner, card)
	if src < 0: return out
	var u: Dictionary = gs.player(owner).units[src]
	var ghost: bool = gs.VerifiedRules.Samurai.ghost(u)
	out.allowKnockedSource = ghost and (from_zone or card.id in [MEDITATE, "c62404", "c62407"])
	if card.id == HEART and ghost: out.keywords.append("instant")
	if card.id == SEVER and ghost:
		out.value = int(out.value) + 1
		out.keywords.append("pursuit")
		out.combatOption.pursuit = true
		out.target = "enemy-unit"
	if card.id == GRUDGE:
		out.value = int(out.value) + gs.player(owner).units.filter(func(ally): return int(ally.hp) <= 0 and gs.VerifiedRules.OwlInsect.shikigami(ally)).size()
	if card.id == "c62405":
		out.combatOption.shield = gs.player(1-owner).units.filter(func(enemy): return int(enemy.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(enemy)).size()
	if out.type == "combat":
		out.effects[0].value = out.value
		out.currentCardStats = "+%d力量/+%d护甲%s" % [int(out.value), int(out.combatOption.get("shield", 0)), " · 武魂%d力量" % gs.VerifiedRules.Samurai.power(u) if ghost else ""]
	return out

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("catRules", false): return true
	var src: int = gs._source_index(owner, card)
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	if card.id == MEDITATE: return gs.VerifiedRules.Samurai.ghost(u)
	if card.id == "c62404" and u.awakened: return false
	if card.id == "c62407" and int(u.hp) <= 0: return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)
	return true

static func knocked_out(gs, owner: int, u: Dictionary, eligible: bool) -> void:
	if not eligible or u.id != ID or not gs.VerifiedRules.Samurai.ghost(u): return
	gs.VerifiedRules.Baize.put_hand(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, MEDITATE))
	if u.awakened: gs.resolution_stack.append({"kind": "cat-draw-insight", "playerIndex": owner})

static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int, combat: bool) -> void:
	if not combat or amount <= 0 or owner < 0 or victim == owner or src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if u.id != ID: return
	for realm in gs.player(owner).realms.duplicate():
		if realm.get("nativeRealm") != "cat-ferry" or int(realm.hp) <= 0: continue
		if int(u.hp) > 0:
			var pool: Array = gs.player(victim).units.filter(func(enemy): return int(enemy.hp) > 0 and not enemy.get("form", {}).is_empty())
			if not pool.is_empty():
				var idx: int = gs._unit_index_by_uid(victim, pool[int(gs.next_random() % pool.size())].uid)
				gs.VerifiedRules.Forms.remove(gs, victim, idx, "被五条渡口消灭")
		else:
			var pool: Array = gs.player(victim).realms.filter(func(r): return int(r.hp) > 0)
			if not pool.is_empty(): gs.VerifiedRules.Huang.destroy(gs, victim, pool[int(gs.next_random() % pool.size())], "被五条渡口消灭")

static func oath(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	var ids: Array = []
	if int(u.hp) > 0: ids.append(SACRIFICE)
	elif gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u): ids.append(REVIVE)
	if ids.is_empty(): return
	var p: Dictionary = gs.player(owner)
	if not p.has("catOaths"): p.catOaths = []
	var inst: Dictionary = card.get("playedInstance", {})
	if not inst.is_empty(): p.catOaths.append(inst)
	gs.pending_choice = {"type": "cat-oath", "playerIndex": owner, "sourceIndex": src,
		"instanceIds": ids, "heading": "忠义无双", "hint": "根据猫侍当前状态选择结算。"}
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "cat-oath" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return null
	if iid == REVIVE: return {"id": iid, "name": "复活", "type": "spell", "text": "复活猫侍并使他获得迅捷、昂扬。"}
	return {"id": iid, "name": "化作武魂", "type": "spell", "text": "使猫侍气绝，启悟并永久获得2力量。"}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	if choice_card(gs, owner, iid) == null: return false
	var src := int(gs.pending_choice.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("cat-oath", {"mode": iid}, owner)
	if iid == REVIVE:
		if gs.VerifiedRules.Peach.revive(gs, owner, src, u, true, false): u.inspired = true
	else:
		var depth: int = gs.resolution_stack.size()
		var prior_deaths := int(u.get("rebirthDeaths", 0))
		gs._knockout_unit(u, owner, src)
		if int(u.get("rebirthDeaths", 0)) > prior_deaths:
			gs.resolution_stack.insert(depth, {"kind": "cat-oath-sacrifice", "playerIndex": owner, "sourceIndex": src})
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "cat-oath": return null
	return resolve_choice(gs, owner, str(gs.pending_choice.instanceIds[0]))

static func end_turn(gs, owner: int) -> void:
	for inst in gs.player(owner).get("catOaths", []):
		gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
	gs.player(owner).erase("catOaths")

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.action):
		"cat-meditate": gs.VerifiedRules.Insight.enter(gs, owner)
		"cat-ferry": gs._deploy_realm(owner, card)
		"cat-oath": oath(gs, owner, src, card)
		"cat-assault":
			if card.id == "c62404": gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			var token := str(card.get("catGenerates", ""))
			if not token.is_empty() and not gs.VerifiedRules.Insight.active(gs, owner):
				gs.VerifiedRules.Insight.place(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, token))
			gs._resolve_action(owner, src, card, {"action": "assault", "value": effect.value}, target_id, {})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	match frame.get("kind"):
		"cat-draw-insight": gs._draw(int(frame.playerIndex), 1, -1, {"intoInsight": true})
		"cat-oath-sacrifice":
			var owner := int(frame.playerIndex)
			var u: Dictionary = gs.player(owner).units[int(frame.sourceIndex)]
			gs.VerifiedRules.Insight.enter(gs, owner)
			gs.VerifiedRules.Glutton.record_permanent(u, 2, 0)
			u.permanentAttack = int(u.get("permanentAttack", 0)) + 2
			gs._recalc(u)
		_: return false
	return true
