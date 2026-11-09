class_name WaterMoonRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "zhuiyueshen-shuiyue"
const FINISH := "water-finish"
const SINGLE := "water-single"
const ALL := "water-all"
const AWAKEN := "c61807"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func placed(gs, owner: int, inst: Dictionary) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.OwlInsect.active(u): return
	var def: Dictionary = Content.card_def(inst.definitionId)
	if u.awakened:
		var idx: int = gs._source_index(owner, def)
		if idx >= 0 and int(gs.player(owner).units[idx].hp) > 0:
			grant(gs, owner, gs.player(owner).units[idx], "waterReturnLight", "溯光")
	elif def.get("unitId") == ID:
		grant(gs, owner, u, "waterLumen", "流明")

static func grant(gs, owner: int, u: Dictionary, key: String, label: String) -> void:
	if u.get(key, false): return
	u[key] = true
	gs.VerifiedRules.event(gs, "water-spirit-charm", {"player": owner, "uid": u.uid, "charm": label})

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	var src: int = gs._source_index(owner, card)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	var lumen: bool = u.get("waterLumen", false) and int(gs.player(owner).energy) == 0
	var returning: bool = u.get("waterReturnLight", false)
	if not lumen and not returning: return card
	var view := card.duplicate(true)
	view.waterConsumedLumen = lumen
	view.waterConsumedReturnLight = returning
	if "instant" not in view.get("keywords", []): view.keywords.append("instant")
	view.text += "\n%s：获得瞬发，使用后移除灵咒。" % ("流明" if lumen else "溯光")
	return view

static func announced(gs, owner: int, src: int, card: Dictionary) -> void:
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	# A card can spend fire before its announcement. Read the projected state
	# captured for that use, instead of the post-payment fire count.
	if card.get("waterConsumedLumen", false): u.erase("waterLumen")
	if card.get("waterConsumedReturnLight", false): u.erase("waterReturnLight")

static func completed(gs, owner: int, card: Dictionary, inst: Dictionary) -> void:
	if not card.get("waterFirstUse", false) or inst.is_empty() or inst.get("waterUsed", false): return
	inst.waterUsed = true
	gs.VerifiedRules.Insight.place(gs, owner, inst)

static func choice(gs, owner: int, kind: String, ids: Array, src: int, heading: String, hint: String) -> void:
	gs.pending_choice = {"type": kind, "playerIndex": owner, "sourceIndex": src, "instanceIds": ids, "heading": heading, "hint": hint}
	gs.phase = "choice"

static func hand_instance(gs, owner: int, iid: String) -> Dictionary:
	for inst in gs.player(owner).hand:
		if str(inst.instanceId) == iid: return inst
	return {}

static func living_targets(gs, owner: int) -> Array:
	var ids: Array = []
	for side in [1-owner, owner]:
		for u in gs.player(side).units:
			if int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side == owner or not gs.VerifiedRules.Combat.has(u, "veil")):
				ids.append(str(u.uid))
	return ids

static func choice_card(gs, owner: int, iid: String):
	var c: Dictionary = gs.pending_choice
	if c.get("type") not in ["water-mulligan", "water-mode", "water-target"] or int(c.playerIndex) != owner or iid not in c.instanceIds: return null
	match iid:
		FINISH: return {"id": iid, "name": "完成调度", "type": "spell", "text": "抽取所选张数的牌，然后启悟。"}
		SINGLE: return {"id": iid, "name": "指定式神", "type": "spell", "text": "选择一个式神，造成5点伤害。"}
		ALL: return {"id": iid, "name": "敌方全体", "type": "spell", "text": "对所有敌方式神造成2点伤害。"}
	if c.type == "water-mulligan": return gs.describe_card_instance(owner, hand_instance(gs, owner, iid))
	var u: Dictionary = gs._unit_by_uid(gs._all_units(), iid)
	if u.is_empty(): return {}
	return {"id": iid, "unitId": u.id, "name": u.name, "type": "form", "text": ("己方" if gs._unit_index_by_uid(owner, iid) >= 0 else "敌方") + "式神 · 当前%d力量/%d生命" % [u.attack, u.hp]}

static func mulligan(gs, owner: int, src: int) -> void:
	var ids: Array = gs.player(owner).hand.map(func(i): return str(i.instanceId))
	if ids.is_empty():
		gs.VerifiedRules.Insight.enter(gs, owner)
		return
	ids.push_front(FINISH)
	choice(gs, owner, "water-mulligan", ids, src, "携 月", "选择至多三张手牌调度到启悟区，抽取相同数量。")
	gs.pending_choice.selected = []

static func finish_mulligan(gs, owner: int, ids: Array) -> void:
	var hand: Array = gs.player(owner).hand
	for iid in ids:
		var inst := hand_instance(gs, owner, str(iid))
		if inst.is_empty(): continue
		hand.erase(inst)
		gs.VerifiedRules.Insight.place(gs, owner, inst)
	gs.VerifiedRules.Glutton.mark_hand(gs, owner)
	gs.resolution_stack.append({"kind": "water-enter", "playerIndex": owner})
	gs._draw(owner, ids.size())

static func damage(gs, owner: int, src: int, ids: Array, amount: int, context: Dictionary) -> void:
	var old: Dictionary = gs._card_effect_context
	gs._card_effect_context = context
	for iid in ids:
		if gs.winner >= 0: break
		for side in 2:
			var idx: int = gs._unit_index_by_uid(side, iid)
			if idx >= 0 and int(gs.player(side).units[idx].hp) > 0: gs._damage_unit(side, idx, amount, owner, src)
	gs._card_effect_context = old

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary = gs.pending_choice
	if c.get("type") not in ["water-mulligan", "water-mode", "water-target"] or int(c.playerIndex) != owner or iid not in c.instanceIds: return false
	var src := int(c.sourceIndex)
	gs._record("resolve_divination_choice", {"instanceId": iid, "choice": c.type}, owner)
	if c.type == "water-mulligan" and iid != FINISH:
		if hand_instance(gs, owner, iid).is_empty(): return false
		c.selected.append(iid)
		c.instanceIds.erase(iid)
		c.hint = "已选择%d / 3 张 · 可以继续调度或完成。" % c.selected.size()
		if c.selected.size() < 3 and c.instanceIds.size() > 1:
			gs.state_changed.emit()
			return true
	if c.type == "water-mode" and iid == SINGLE:
		c.type = "water-target"
		c.instanceIds = living_targets(gs, owner)
		c.hint = "选择受到5点伤害的式神。"
		gs.state_changed.emit()
		return true
	gs.pending_choice = {}
	gs.phase = "main"
	match str(c.type):
		"water-mulligan": finish_mulligan(gs, owner, c.selected)
		"water-mode":
			var ids: Array = gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u)).map(func(u): return u.uid)
			damage(gs, owner, src, ids, 2, c.context)
		"water-target": damage(gs, owner, src, [iid], 5, c.context)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var c: Dictionary = gs.pending_choice
	if c.get("type") not in ["water-mulligan", "water-mode", "water-target"]: return null
	var best := str(c.instanceIds[0])
	var best_score := 0
	if c.type == "water-mode":
		var rivals: Array = gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))
		best = SINGLE if SINGLE in c.instanceIds and rivals.any(func(u): return int(u.hp) + int(u.shield) in [3, 4, 5] and not gs.VerifiedRules.Combat.has(u, "veil")) else ALL
	else:
		for iid in c.instanceIds:
			var score := -100
			if c.type == "water-mulligan" and iid != FINISH:
				var card: Dictionary = Content.card_def(hand_instance(gs, owner, iid).get("definitionId", ""))
				var src: int = gs._source_index(owner, card)
				if src >= 0: score = int(card.level) - int(gs.player(owner).units[src].level)
			elif c.type == "water-target" and gs._unit_index_by_uid(1-owner, iid) >= 0:
				var u: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, iid)
				score = 8 + int(u.attack) + (10 if int(u.hp) + int(u.shield) <= 5 else 0)
			if score > best_score:
				best = str(iid)
				best_score = score
	return resolve_choice(gs, owner, best)

static func transfer_instance(gs, owner: int, state: Dictionary) -> Dictionary:
	var inst: Dictionary = state.get("cardInstance", {}).duplicate(true)
	if inst.is_empty(): inst = state.get("returnInstance", {}).duplicate(true)
	if inst.is_empty():
		var id := str(state.get("cardId", ""))
		if Content.card_def(id).is_empty(): return {}
		inst = gs.VerifiedRules.Insight.instance(gs, owner, id)
	return inst

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") != "water-reflect": return null
	return board_targets(gs, owner)

static func board_targets(gs, owner: int) -> Array:
	var ids: Array = []
	for u in gs.player(1-owner).units:
		if int(u.hp) > 0 and not u.get("form", {}).is_empty() and not gs.VerifiedRules.Combat.has(u, "veil"): ids.append(u.uid)
	if not gs.VerifiedRules.ArmorBlood.realm_veil(gs, 1-owner):
		for realm in gs.player(1-owner).realms:
			if int(realm.hp) > 0 and not Content.card_def(str(realm.cardId)).is_empty(): ids.append(realm.uid)
	return ids

static func reflect(gs, owner: int, target_id) -> void:
	move_board(gs, owner, target_id, "映月")

static func move_board(gs, owner: int, target_id, name: String) -> Dictionary:
	var enemy := 1-owner
	var inst: Dictionary = {}
	var idx: int = gs._unit_index_by_uid(enemy, target_id)
	if idx >= 0:
		var u: Dictionary = gs.player(enemy).units[idx]
		if int(u.hp) <= 0 or u.get("form", {}).is_empty(): return {}
		inst = transfer_instance(gs, enemy, u.form)
		gs.VerifiedRules.Forms.remove(gs, enemy, idx, "被%s置入启悟区" % name, true)
	else:
		for realm in gs.player(enemy).realms.duplicate():
			if realm.uid != target_id: continue
			inst = transfer_instance(gs, enemy, realm)
			gs.VerifiedRules.Huang.destroy(gs, enemy, realm, "被%s置入启悟区" % name, true)
			break
	return inst if gs.VerifiedRules.Insight.place(gs, enemy, inst) else {}

static func form_trigger(gs, owner: int, u: Dictionary) -> void:
	if u.get("formRules", {}).get("waterDance", false):
		var zone: Array = gs.VerifiedRules.Insight.zone(gs, owner)
		if zone.size() >= 6: gs.VerifiedRules.Insight.enter(gs, owner)
		elif not gs.player(owner).deck.is_empty(): gs.VerifiedRules.Insight.place(gs, owner, gs.player(owner).deck.pop_back())
	elif u.get("formRules", {}).get("waterSwap", false):
		var p: Dictionary = gs.player(owner)
		var hand: Array = p.hand
		p.hand = gs.VerifiedRules.Insight.zone(gs, owner)
		p.insightZone = []
		gs.VerifiedRules.Chen.refresh(gs, owner)
		for inst in hand: gs.VerifiedRules.Insight.place(gs, owner, inst)
		gs.VerifiedRules.Glutton.mark_hand(gs, owner)
		gs.VerifiedRules.BondDream.refresh(gs)
		gs.VerifiedRules.event(gs, "water-zones-swapped", {"player": owner, "handCount": p.hand.size(), "insightCount": p.insightZone.size()})

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.OwlInsect.active(u) or int(u.level) < 3 or u.awakened: return
	for inst in gs.VerifiedRules.Insight.zone(gs, owner):
		if inst.definitionId != AWAKEN: continue
		var card: Dictionary = gs.describe_card_instance(owner, inst, false)
		if gs.VerifiedRules.UpgradeBlessing.card_blocked(gs, u, card) or gs.VerifiedRules.Stun.blocks(gs, owner, u, card): return
		card = gs.VerifiedRules.Insight.describe(gs, owner, inst, card, true)
		gs.VerifiedRules.Insight.remove(gs, owner, inst)
		var depth: int = gs.resolution_stack.size()
		gs._push_card_frames(owner, AWAKEN, null, card, src, 0, true)
		gs._resolve_inline_frames(depth)
		break

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not card.get("waterRules", false): return false
	match str(effect.action):
		"water-mulligan": mulligan(gs, owner, src)
		"water-reflect": reflect(gs, owner, target_id)
		"water-form":
			gs._apply_form(owner, src, card)
			form_trigger(gs, owner, gs.player(owner).units[src])
		"water-lament":
			var ids := [ALL] if living_targets(gs, owner).is_empty() else [SINGLE, ALL]
			choice(gs, owner, "water-mode", ids, src, "罪 月", "选择单体伤害或敌方全体伤害。")
			gs.pending_choice.context = gs._card_effect_context
		"water-fill":
			gs.VerifiedRules.Insight.enter(gs, owner)
			var slots: int = gs.VerifiedRules.Insight.CAPACITY - gs.VerifiedRules.Insight.zone(gs, owner).size()
			gs._draw(owner, maxi(0, slots), -1, {"intoInsight": true, "allowShortDeck": true})
		"water-awaken":
			gs._awaken(owner, src, card, effect.value)
			gs.player(owner).units[src].erase("waterLumen")
		"water-draw":
			if card.get("insightFromZone", false):
				gs.resolution_stack.append({"kind": "water-fire", "playerIndex": owner})
			gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": owner, "count": 1})
			gs.VerifiedRules.Divination.start(gs, owner, 1)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	match str(frame.kind):
		"water-enter": gs.VerifiedRules.Insight.enter(gs, int(frame.playerIndex))
		"water-fire": gs._set_fire(int(frame.playerIndex), int(gs.player(int(frame.playerIndex)).energy) + 1)
		_: return false
	return true

static func score(gs, owner: int, card: Dictionary) -> Variant:
	if not card.get("waterRules", false): return null
	match str(card.id):
		"c61805": return 63 if gs.VerifiedRules.Insight.zone(gs, owner).size() < gs.VerifiedRules.Insight.CAPACITY else -100
		"c61807": return 77 if card.get("insightFromZone", false) else 62
		_: return 64
