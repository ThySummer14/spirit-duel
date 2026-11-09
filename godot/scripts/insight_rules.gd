class_name InsightRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const STAR := "insight-star"
const MOON := "insight-moon"
const SUN := "insight-sun"
const CAPACITY := 12

static func active(gs, owner: int) -> bool:
	return gs.player(owner).get("insightActive", false)

static func zone(gs, owner: int) -> Array:
	return gs.player(owner).get("insightZone", [])

static func instance(gs, owner: int, id: String) -> Dictionary:
	var out := {"instanceId": "%s-insight-%d" % [gs.player(owner).id, gs.next_card_id], "definitionId": id}
	gs.next_card_id += 1
	return out

static func initialize(gs) -> void:
	for owner in 2:
		gs.player(owner).insightZone = [instance(gs, owner, STAR), instance(gs, owner, MOON), instance(gs, owner, SUN)]

static func place(gs, owner: int, inst: Dictionary) -> bool:
	if inst.is_empty(): return false
	if zone(gs, owner).size() >= CAPACITY:
		gs._log("启悟区已满，「%s」被烧毁。" % Content.card_def(str(inst.definitionId)).get("name", "卡牌"), gs.TONE_DANGER)
		gs.VerifiedRules.event(gs, "insight-card-overflow", {"player": owner, "instanceId": inst.instanceId, "card": Content.card_def(str(inst.definitionId))})
		return false
	if not gs.player(owner).has("insightZone"): gs.player(owner).insightZone = []
	zone(gs, owner).append(inst)
	gs.VerifiedRules.WaterMoon.placed(gs, owner, inst)
	if inst.definitionId in gs.VerifiedRules.Chen.BLESSINGS: gs.VerifiedRules.Chen.refresh(gs, owner)
	gs.VerifiedRules.event(gs, "insight-card-placed", {"player": owner, "instanceId": inst.instanceId, "card": Content.card_def(str(inst.definitionId))})
	return true

static func remove(gs, owner: int, inst: Dictionary) -> void:
	zone(gs, owner).erase(inst)
	if inst.definitionId in gs.VerifiedRules.Chen.BLESSINGS: gs.VerifiedRules.Chen.refresh(gs, owner)

static func enter(gs, owner: int, only_unit: String = "") -> void:
	var p: Dictionary = gs.player(owner)
	# A new insight effect during card settlement keeps the zone open. The
	# serial prevents the prior card completion from closing the new state.
	p.insightActive = true
	p.insightOnlyUnit = only_unit
	p.insightSerial = int(p.get("insightSerial", 0)) + 1
	gs._log("%s 进入启悟。" % p.name, gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "insight-entered", {"player": owner, "serial": p.insightSerial, "onlyUnit": only_unit})
	gs.VerifiedRules.Astral.enter_extra(gs, owner)
	gs.VerifiedRules.Chen.entered(gs, owner)
	gs.VerifiedRules.Rain.entered(gs, owner)

static func leave(gs, owner: int) -> void:
	if not active(gs, owner): return
	gs.player(owner).insightActive = false
	gs.player(owner).erase("insightOnlyUnit")
	gs._log("%s 结束启悟，恢复手牌区。" % gs.player(owner).name, gs.TONE_NEUTRAL)
	gs.VerifiedRules.event(gs, "insight-ended", {"player": owner})
	gs.VerifiedRules.Solar.insight_ended(gs, owner)

static func leave_action(gs, owner: int) -> bool:
	if not active(gs, owner) or gs.current_player != owner or gs.phase != "main" or gs.winner >= 0 or gs.is_resolving or not gs.pending_choice.is_empty() or not gs.response_window.is_empty(): return false
	gs._record("end_insight", {}, owner)
	leave(gs, owner)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary, from_zone: bool) -> Dictionary:
	card = gs.VerifiedRules.CatSamurai.describe(gs, owner, card, from_zone)
	var buff: int = gs.VerifiedRules.Astral.bonus(gs, owner, str(card.get("id", "")))
	if not from_zone and int(inst.get("sunlight", 0)) <= 0 and buff == 0: return card
	var view := card.duplicate(true)
	if from_zone:
		view.insightFromZone = true
		view.sourceZone = "insight"
		view.insightSerial = int(gs.player(owner).get("insightSerial", 0))
	if buff > 0: view.currentCardStats = "当前伤害：%d" % (2 + buff)
	var light := int(inst.get("sunlight", 0))
	if light > 0:
		view.sunlight = light
		view.text += "\n天晖：当前%d层。" % light
		if gs.VerifiedRules.Solar.awake(gs, owner) and "instant" not in view.get("keywords", []):
			view.keywords = view.get("keywords", []).duplicate()
			view.keywords.append("instant")
	return gs.VerifiedRules.Rain.describe(gs, owner, view)

static func is_neutral(card: Dictionary) -> bool:
	return card.get("neutral", false) or card.get("neutralFood", false) or card.get("neutralEssence", false)

static func allowed(gs, owner: int, card: Dictionary) -> bool:
	return block_reason(gs, owner, card).is_empty()

static func block_reason(gs, owner: int, card: Dictionary) -> String:
	if not card.get("insightFromZone", false): return ""
	if is_neutral(card) and gs.VerifiedRules.LunarTrick.form(gs, 1-owner, "lunarLimit"):
		return "月烬天极：不能使用启悟区的中立牌。"
	var only_unit := str(gs.player(owner).get("insightOnlyUnit", ""))
	if only_unit.is_empty() or is_neutral(card) or str(card.get("unitId", "")) == only_unit: return ""
	return "本次启悟只能使用荒·启命的牌或中立牌。"

static func used(gs, owner: int, card: Dictionary, inst: Dictionary, resolved: bool = true, target_id = null) -> void:
	if card.get("insightFromZone", false):
		if not card.get("insightKeeps", false) and int(card.insightSerial) == int(gs.player(owner).get("insightSerial", -1)): leave(gs, owner)
	if resolved and card.id == STAR: place(gs, owner, inst)
	if gs.winner < 0:
		gs.VerifiedRules.Solar.used(gs, owner, card)
		gs.VerifiedRules.Chen.used(gs, owner, card)
		if resolved:
			gs.VerifiedRules.Astral.completed(gs, owner, card, inst, target_id)
			gs.VerifiedRules.WaterMoon.completed(gs, owner, card, inst)

static func neutral_targets(gs, owner: int, card: Dictionary):
	if not card.get("insightNeutral", false): return null
	if card.id == gs.VerifiedRules.LunarTrick.FALSE_MOON: return []
	var enemy := 1-owner
	var targets: Array = []
	if card.id == MOON:
		if not gs.VerifiedRules.ArmorBlood.realm_veil(gs, enemy):
			for realm in gs.player(enemy).realms:
				if int(realm.hp) > 0: targets.append(str(realm.uid))
		return targets
	var is_burst: bool = card.id == gs.VerifiedRules.Astral.BURST
	for side in ([owner, enemy] if is_burst else [enemy]):
		for u in gs.player(side).units:
			if int(u.hp) <= 0 or u.get("removed", false) or (side == enemy and gs.VerifiedRules.Combat.has(u, "veil")): continue
			if card.id != SUN or gs.VerifiedRules.OwlInsect.shikigami(u): targets.append(str(u.uid))
		if card.id != SUN and (side == owner or not gs.VerifiedRules.PipeFox.avatar_veil(gs, side)): targets.append("avatar-%d" % side)
	return targets

static func can_use_neutral(gs, owner: int, card: Dictionary, target_id) -> Dictionary:
	var threshold := int(card.get("insightLevel", 0))
	if threshold > 0 and not gs.player(owner).units.any(func(u): return int(u.hp) > 0 and int(u.level) >= threshold and gs.VerifiedRules.OwlInsect.shikigami(u)):
		return {"ok": false, "reason": "需要一个未气绝、至少%d勾的己方式神。" % threshold}
	if card.target != "auto" and not neutral_targets(gs, owner, card).has(target_id): return {"ok": false, "reason": "请选择一个有效目标。"}
	if int(gs.player(owner).energy) < gs.effective_card_cost(owner, card): return {"ok": false, "reason": "鬼火不足。"}
	return {"ok": true, "card": card, "source_index": -1}

static func play_neutral(gs, owner: int, index: int, target_id, card: Dictionary) -> bool:
	var payment: Dictionary = gs.card_payment(owner, card)
	gs.VerifiedRules.Wave7Reworks.pay_lamp(gs, owner, card, payment)
	var inst: Dictionary = gs.take_card_instance(owner, index)
	card.playedInstance = inst
	card.usedFromHand = not card.get("insightFromZone", false)
	var rid: int = gs.next_resolution_id
	gs.next_resolution_id += 1
	gs._record("play_card", {"hand": index, "target": target_id, "card": card.id, "sourceZone": card.get("sourceZone", "hand"), "instanceId": inst.instanceId, "cardView": card.duplicate(true), "payment": payment}, owner)
	gs._set_fire(owner, int(gs.player(owner).energy) - int(payment.cost), true)
	if payment.usesInstant: gs.consume_instant(owner)
	gs.player(owner).cardsPlayedThisTurn += 1
	gs._log("%s 从%s使用「%s」。" % [gs.player(owner).name, "启悟区" if card.get("insightFromZone", false) else "手牌", card.name], gs.TONE_CARD)
	var frame := {"kind": "insight-neutral-effect", "resolutionId": rid, "playerIndex": owner, "sourceIndex": -1, "definitionId": card.id, "cardOverride": card, "targetId": target_id, "affectedUnits": [], "usedFromHand": card.usedFromHand}
	gs.resolution_stack.append(frame)
	var announce := frame.duplicate(true)
	announce.kind = "insight-neutral-announce"
	gs.resolution_stack.append(announce)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if kind not in ["insight-neutral-announce", "insight-neutral-effect"]: return false
	if kind == "insight-neutral-announce":
		gs.VerifiedRules.announce_neutral_food(gs, frame)
		return true
	var owner := int(frame.playerIndex)
	var enemy := 1-owner
	var card: Dictionary = frame.cardOverride
	var target_id = frame.targetId
	match str(card.id):
		"yuedu-false-moon": gs.VerifiedRules.LunarTrick.false_moon(gs, owner)
		STAR, "insight-starburst":
			var damage: int = 2 + gs.VerifiedRules.Astral.bonus(gs, owner, str(card.id))
			var old: Dictionary = gs._card_effect_context
			gs._card_effect_context = frame
			for side in 2:
				if str(target_id) == "avatar-%d" % side:
					gs._damage_avatar(side, damage, owner)
					break
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx >= 0:
					gs._damage_unit(side, idx, damage, owner)
					break
			gs._card_effect_context = old
		MOON:
			for realm in gs.player(enemy).realms.duplicate():
				if realm.uid == target_id:
					gs.VerifiedRules.Huang.destroy(gs, enemy, realm, "被月诫消灭")
					break
		SUN:
			var idx: int = gs._unit_index_by_uid(enemy, target_id)
			if idx >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, -1, enemy, idx, card)
			if gs.winner < 0: gs._draw(enemy, 1)
	used(gs, owner, card, card.playedInstance, true, target_id)
	return true
