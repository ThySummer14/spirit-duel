extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Fox := preload("res://scripts/fox_flame_rules.gd")
const Goat := preload("res://scripts/goat_heist_rules.gd")
const Car := preload("res://scripts/car_frog_rules.gd")
const Deer := preload("res://scripts/forest_spirit_rules.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")

static func choose(gs, owner: int, kind: String, ids: Array, src: int, title: String, context: Dictionary = {}) -> void:
	if ids.is_empty(): return
	gs.pending_choice = {"type":"stars-" + kind,"playerIndex":owner,"sourceIndex":src,"heading":title,"hint":"选择一项继续结算。","instanceIds":ids}.merged(context)
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("stars-") or int(c.playerIndex) != owner or iid not in c.instanceIds: return null
	if c.type == "stars-shop": return gs.VerifiedRules.BattleShop.choice_card(gs, owner, iid)
	if c.get("unitIds", false):
		var unit: Dictionary = gs._unit_by_uid(gs.player(owner).units, iid)
		return {"id":iid,"name":unit.name,"type":"unit","art":unit.get("art", ""),"text":"力量%d · 生命%d" % [unit.attack,unit.hp]}
	if iid in c.get("labels", {}): return {"id":iid,"name":c.labels[iid],"type":"spell","text":c.get("details", {}).get(iid, "")}
	if c.get("cardIds", false): return Content.card_def(iid)
	return null

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("stars-") or int(c.playerIndex) != owner or iid not in c.instanceIds: return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId":iid,"choice":c.type}, owner)
	if c.type == "stars-shop": gs.VerifiedRules.BattleShop.choice(gs, owner, iid)
	elif not Fox.choice(gs, owner, iid, c) and not Car.choice(gs, owner, iid, c): gs.VerifiedRules.StarShopCards.choice(gs, owner, iid, c)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("stars-"): return null
	var chosen: String = str(c.instanceIds[0])
	if c.type == "stars-shop": chosen = "shop-close"
	if c.type == "stars-bond-awaken": chosen = "awaken"
	if c.type == "stars-car-maintain":
		var src := int(c.sourceIndex)
		if int(gs.player(owner).units[src].hp) <= 3: chosen = "rest"
	return resolve_choice(gs, owner, chosen)

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var out := Deer.adjust_card(gs, owner, inst, card)
	out = gs.VerifiedRules.BattleShop.describe(gs, owner, inst, out)
	out = gs.VerifiedRules.StarShopCards.describe(gs, owner, out)
	if out.id == "c65303":
		out = out.duplicate(true)
		out.value = int(gs.player(owner).get("starsFrogsSummoned", 0))
	if out.id == "c65108":
		out = out.duplicate(true)
		out.originCard = {"id":"c65108","name":"狐烬烈焰·戏法","type":"spell","unitId":Fox.FOX,"level":2,"cost":1,"target":"enemy-unit","verifiedRules":true,"starsFoxTrick":true,"text":"戏法：对一个结附「狐焰」的敌方式神造成4点伤害。","effects":[{"action":"stars-fox-blaze-trick","target":"enemy-unit"}]}
	return out

static func targets(gs, owner: int, card: Dictionary):
	var shop_targets = gs.VerifiedRules.StarShopCards.targets(gs, owner, card)
	if shop_targets != null: return shop_targets
	if card.get("starsFoxTrick", false):
		return Fox.units(gs, 1 - owner, true).filter(func(u): return not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	if card.get("id") in ["c65101", "c65107", "c65201", "c65202", "c65205"]:
		return Choice.targetable_shikigami(gs, owner, 1 - owner).map(func(u): return u.uid)
	if card.get("giftKey", "") == "deer-funeral" and gs.front_index(1 - owner) >= 0: return []
	return null

static func turn_start(gs, owner: int) -> void:
	for side in 2:
		for u in gs.player(side).units:
			if u.has("starsGoatNoticePower"):
				u.erase("starsGoatNoticePower")
				gs._recalc(u)
	gs.VerifiedRules.StarShopCards.turn_start(gs, owner)
	Car.turn_start(gs, owner)
	Goat.turn_start(gs, owner)

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	Fox.completed(gs, owner, src)
	if src >= 0: Deer.finish_gift(gs, owner, src, card)
	gs.VerifiedRules.BattleShop.completed(gs, frame, card)
	gs.VerifiedRules.StarShopCards.stack_used(gs, frame, card)
	if frame.get("usedFromHand", false): Goat.after_action(gs, owner)

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if src < 0 or not (action.begins_with("stars-") or action.begins_with("abyss-stars-")): return false
	return (Deer.resolve(gs, owner, src, card, effect, target_id)
		or Fox.resolve(gs, owner, src, card, effect, target)
		or Goat.resolve(gs, owner, src, card, effect, target)
		or Car.resolve(gs, owner, src, card, effect, target_id)
		or gs.VerifiedRules.StarShopCards.resolve(gs, owner, src, card, effect, target, target_id))

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.kind == "stars-action-after":
		Goat.after_action(gs, int(frame.playerIndex))
		return true
	return Fox.resolve_frame(gs, frame) or Goat.resolve_frame(gs, frame) or Car.resolve_frame(gs, frame) or gs.VerifiedRules.StarShopCards.resolve_frame(gs, frame)
