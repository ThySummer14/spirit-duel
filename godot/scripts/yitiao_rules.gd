class_name YitiaoRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const TRAINING := "yitiao-training"
const CHOICES := ["yitiao-lifesteal", "yitiao-critical"]

static func source(unit: Dictionary) -> bool:
	return Content.runtime_unit_def(unit).get("yitiaoRules", false)
static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)
static func swift(unit: Dictionary) -> bool:
	return source(unit) and active(unit) and unit.awakened

static func training(gs, owner: int, src: int, reason: String) -> void:
	var p: Dictionary = gs.player(owner)
	var inst := {"instanceId": "%s-training-%d" % [p.id, gs.next_card_id], "definitionId": TRAINING}
	gs.next_card_id += 1
	p.hand.append(inst)
	var burned: bool = p.hand.size() > int(gs.rules.maxHandSize)
	if burned: p.hand.pop_back()
	gs.VerifiedRules.event(gs, "yitiao-training-created", {"player": owner, "uid": p.units[src].uid, "card": Content.card_def(TRAINING), "instanceId": inst.instanceId, "burned": burned, "reason": reason})

static func upgraded(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if source(unit) and not unit.get("removed", false): training(gs, owner, src, "升级")

static func guard_power(gs, unit: Dictionary) -> int:
	if not active(unit) or not unit.get("formRules", {}).get("yitiaoGuard", false): return 0
	for owner in gs.players.size():
		if owner != gs.current_player and gs.player(owner).units.has(unit): return int(unit.get("yitiaoSkillUses", 0))
	return 0

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary, ability: bool = false) -> Dictionary:
	if not card.get("yitiaoRules", false): return card
	var src: int = gs._source_index(owner, card)
	if src < 0: return card
	var unit: Dictionary = gs.player(owner).units[src]
	var view := card.duplicate(true)
	var bonus := int(unit.get("yitiaoSkillBonus", 0))
	view.currentCardStats = "战技 +%d/+%d · %d次" % [bonus, bonus, int(unit.get("yitiaoSkillUses", 0))]
	if view.type == "combat" and unit.get("formRules", {}).get("yitiaoCombatInstant", false) and not view.keywords.has("instant"): view.keywords.append("instant")
	if view.type == "combat" and unit.awakened and int(unit.hp) <= 0:
		# Preserve the physical card's identity and payment, replace its whole
		# instruction. No movement, pursuit, armor, growth or combat survives.
		view.allowKnockedSource = true
		view.yitiaoReviveReplacement = true
		view.target = "auto"
		view.value = 0
		view.effect = "yitiao-revive"
		view.effects = [{"action": "yitiao-revive", "target": "source", "value": 0}]
		view.combatOption = {}
		view.keywords = view.keywords.filter(func(k): return k not in ["pursuit", "battle-skill"])
		view.text = "觉醒·一条：本次效果改为复活自己。"
		view.currentCardStats = "气绝可用 · 复活自己"
		view.effectReplacementText = ["觉醒·一条", "复活自己"]
		return view
	if view.type == "combat":
		view.value = bonus if ability or view.id == "c27602" else 0
		view.combatOption.shield = view.value
		view.text += "\n本次战斗牌加成：+%d力量/+%d护甲。" % [int(view.value), int(view.value)]
	return view

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("yitiaoRules", false): return true
	var src: int = gs._source_index(owner, card)
	if src < 0: return false
	var unit: Dictionary = gs.player(owner).units[src]
	if card.get("yitiaoReviveReplacement", false): return gs.VerifiedRules.Rebirth.can_revive(unit)
	return not (card.type == "awakening" and unit.awakened)

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("yitiaoRules", false) or not card.get("battleSkill", false): return
	var unit: Dictionary = gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
	unit.yitiaoSkillUses = int(unit.get("yitiaoSkillUses", 0)) + 1
	gs._recalc(unit)
	gs.VerifiedRules.event(gs, "yitiao-skill-counted", {"player": int(frame.playerIndex), "uid": unit.uid, "card": card, "count": unit.yitiaoSkillUses})

static func basic_traits(unit: Dictionary) -> Dictionary:
	if not active(unit): return {}
	match str(unit.get("formRules", {}).get("yitiaoDeployment", "")):
		"lifeSteal": return {"lifeSteal": true}
		"critical": return {"critical": true}
	return {}

static func assault(gs, owner: int, src: int, card: Dictionary, target_id) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit): return
	var options: Dictionary = card.get("combatOption", {}).duplicate(true)
	options.merge(card.get("yitiaoDeploymentTraits", {}), true)
	options.combatCard = card.duplicate(true)
	gs._grant_unit_armor(unit, int(options.get("shield", 0)))
	gs._record("assault", {"unit": src, "bonus": int(card.value), "target": target_id}, owner)
	gs._resolve_combat(owner, src, int(card.value), false, false, false, false, target_id if options.get("pursuit", false) else null, bool(options.get("critical", false)), options)

static func cover(gs, owner: int, src: int, combat_id: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit): return
	unit.barrier = true
	# This is a separate combat card use, never an extra defender bonus.
	gs.resolution_stack.append({"kind": "yitiao-auto-training", "playerIndex": owner, "sourceIndex": src})
	if combat_id < 0: return
	for frame in gs.resolution_stack:
		if frame.get("kind") != "combat-hit" or int(frame.get("combatId", -1)) != combat_id: continue
		frame.defenderIndex = src
		frame.defenderBonus = 0
		frame.defenderImmuneCombat = false
		frame.defenderRiverLifeSteal = false
		frame.defenderPierce = false
		frame.erase("defenderCombatCard")
		gs.VerifiedRules.Movement.move_to(gs, owner, src, 1)
		gs.VerifiedRules.event(gs, "yitiao-cover", {"player": owner, "uid": unit.uid, "combatId": combat_id})
		return

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"yitiao-skill-grow":
			if active(unit) and not card.get("battleSkillTriggered", false) and not card.get("yitiaoAutomaticTraining", false) and card.get("sourceZone", "hand") == "hand":
				var amount := int(unit.level) if card.id == "c27601" else 1
				unit.yitiaoSkillBonus = int(unit.get("yitiaoSkillBonus", 0)) + amount
				gs.VerifiedRules.event(gs, "yitiao-skill-grown", {"player": owner, "uid": unit.uid, "card": card, "amount": amount, "total": unit.yitiaoSkillBonus})
		"yitiao-combat": assault(gs, owner, src, card, target_id)
		"yitiao-training":
			if active(unit): training(gs, owner, src, "形态进场")
		"yitiao-alone":
			if active(unit):
				unit.yitiaoBodyAttack = int(unit.get("yitiaoBodyAttack", 0)) + 2
				unit.unyielding = true
				unit.yitiaoPierce = true
				gs._grow_unit(unit, 2, 0)
		"yitiao-cover": cover(gs, owner, src, int(gs._card_effect_context.get("combatResponseId", -1)))
		"yitiao-stance":
			if not active(unit) or unit.get("form", {}).get("cardId") != "c27607": return true
			gs.pending_choice = {"type": "yitiao-stance", "playerIndex": owner, "sourceIndex": src, "instanceIds": CHOICES.duplicate(), "heading": "架势·居合", "hint": "选择一条出击时获得的效果"}
			gs.phase = "choice"
		"yitiao-awaken": gs._awaken(owner, src, card, effect.value)
		"yitiao-revive": gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "yitiao-auto-training": return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	if not active(gs.player(owner).units[src]) or gs.VerifiedRules.Stun.blocks(gs, owner, gs.player(owner).units[src], Content.card_def(TRAINING)): return true
	var card := describe_card(gs, owner, {}, Content.card_def(TRAINING))
	card.yitiaoAutomaticTraining = true
	card.sourceZone = "effect"
	gs.player(owner).cardsPlayedThisTurn += 1
	gs._push_card_frames(owner, TRAINING, null, card, src, 0, true)
	return true

static func choice_card(gs, owner: int, id: String):
	if gs.pending_choice.get("type") != "yitiao-stance" or int(gs.pending_choice.playerIndex) != owner or id not in CHOICES: return null
	var card := Content.card_def("c27607").duplicate(true)
	card.id = id
	card.name = "出击时获得吸血" if id == CHOICES[0] else "出击时获得暴击"
	card.text = "本形态下，一条出击时获得%s。" % ("吸血" if id == CHOICES[0] else "暴击")
	card.keywords = ["lifesteal" if id == CHOICES[0] else "crit"]
	card.typeLabel = "居合选择"
	return card

static func resolve_choice(gs, owner: int, id: String) -> bool:
	if choice_card(gs, owner, id) == null: return false
	var src := int(gs.pending_choice.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[src]
	unit.formRules.yitiaoDeployment = "lifeSteal" if id == CHOICES[0] else "critical"
	gs.VerifiedRules.event(gs, "yitiao-stance-chosen", {"player": owner, "uid": unit.uid, "trait": unit.formRules.yitiaoDeployment})
	gs.pending_choice = {}; gs.phase = "main"
	gs._resolve_resolution_stack(); gs._check_winner(); gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "yitiao-stance": return null
	if int(gs.pending_choice.playerIndex) != owner: return false
	return gs.resolve_divination_choice(owner, CHOICES[0] if int(gs.player(owner).avatarHp) <= 18 else CHOICES[1])

static func knocked_out(unit: Dictionary) -> void:
	if not Content.unit_def(str(unit.id)).get("yitiaoRules", false): return
	unit.unyielding = false
	unit.barrier = false
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("yitiaoBodyAttack", 0))
	unit.erase("yitiaoBodyAttack")
	unit.erase("yitiaoPierce")

static func unit_marks(gs, owner: int, src: int) -> Array:
	var unit: Dictionary = gs.player(owner).units[src]
	if not source(unit): return []
	var bonus := int(unit.get("yitiaoSkillBonus", 0))
	var result: Array = ["战技累计+%d力量/+%d护甲 · 已用%d次 · 气绝保留" % [bonus, bonus, int(unit.get("yitiaoSkillUses", 0))]]
	if unit.awakened: result.append("觉醒 · 永久迅捷 · 气绝时战斗牌改为复活自己")
	if unit.get("formRules", {}).get("yitiaoGuard", false): result.append("架势·守 · 敌方回合+%d力量" % int(unit.get("yitiaoSkillUses", 0)))
	if unit.get("formRules", {}).get("yitiaoCombatInstant", false): result.append("架势·攻 · 战斗牌获得瞬发")
	var stance_trait := str(unit.get("formRules", {}).get("yitiaoDeployment", ""))
	if not stance_trait.is_empty(): result.append("架势·居合 · 出击获得" + ("吸血" if stance_trait == "lifeSteal" else "暴击"))
	return result

static func score_card(gs, owner: int, card: Dictionary, target):
	if not card.get("yitiaoRules", false): return null
	var unit: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
	if card.get("yitiaoReviveReplacement", false): return 130
	match str(card.type):
		"awakening": return 120 if int(unit.hp) <= 0 else 82
		"form": return -100 if unit.get("form", {}).get("cardId") == card.id else (90 if card.id == "c27607" else 60)
		"combat": return combat_score(gs, owner, unit, card, target)
	if card.id == "c27605": return 70 if not unit.get("yitiaoPierce", false) else 35
	if card.id == "c27606": return 65
	return 45

static func combat_score(gs, owner: int, unit: Dictionary, card: Dictionary, target) -> int:
	var defender: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, target) if target != null else gs.front_unit(1-owner)
	var power: int = gs.VerifiedRules.Combat.power(gs, owner, unit, int(card.value))
	if card.get("yitiaoDeploymentTraits", {}).get("critical", false): power *= 2
	var score: int = 42 + power * 3 + int(card.combatOption.get("shield", 0)) * 2
	if defender.is_empty(): return 1000 if power >= int(gs.player(1-owner).avatarHp) else score + power * 3
	if power >= int(defender.hp) + int(defender.shield): score += 35
	if int(unit.hp) + int(unit.shield) + int(card.combatOption.get("shield", 0)) <= int(defender.attack) and not unit.unyielding: score -= 45
	return score

static func attack_score(gs, owner: int, src: int, card: Dictionary, target):
	var unit: Dictionary = gs.player(owner).units[src]
	if not source(unit): return null
	var view := card.duplicate(true)
	view.yitiaoDeploymentTraits = basic_traits(unit)
	var power: int = gs.VerifiedRules.Combat.power(gs, owner, unit, int(view.get("value",0)))
	if view.yitiaoDeploymentTraits.get("critical",false): power *= 2
	var defender: Dictionary = gs._unit_by_uid(gs.player(1-owner).units,target)
	if defender.is_empty(): return 1000 if power >= int(gs.player(1-owner).avatarHp) else 80 + power*10
	return power*10 + (40 if power >= int(defender.hp)+int(defender.shield) else 0) + int(view.get("combatOption",{}).get("shield",0))*2
