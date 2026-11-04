class_name BattleSkillRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

# A skill is an ability on the unit, never a synthetic card in its hand.
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("battleSkill", false) or card.get("battleSkillTriggered", false): return
	var unit: Dictionary = gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
	if int(unit.hp) <= 0: return
	unit.battleSkillId = str(card.id)
	gs.VerifiedRules.event(gs, "battle-skill-installed", {"player": int(frame.playerIndex), "uid": unit.uid, "card": Content.card_def(str(card.id))})

static func ready(gs, owner: int, src: int) -> Dictionary:
	var unit: Dictionary = gs.player(owner).units[src]
	if owner != gs.current_player or int(unit.hp) <= 0 or unit.get("baseRulesSuppressed", false) or int(unit.get("battleSkillAttackTurn", -1)) == gs.turn_counter: return {}
	var card: Dictionary = Content.card_def(str(unit.get("battleSkillId", "")))
	if card.is_empty() or int(unit.level) < int(card.level) or gs.VerifiedRules.Stun.blocks(gs, owner, unit, card): return {}
	card = gs.VerifiedRules.Yitiao.describe_card(gs, owner, {}, card, true)
	card = gs.VerifiedRules.Garuda.describe_card(gs, owner, {}, card, false)
	card = gs.VerifiedRules.Butterfly.describe_card(gs, owner, {}, card)
	if not gs.VerifiedRules.Butterfly.can_use(gs, owner, card): return {}
	if card.get("target", "auto") != "auto" and gs.valid_targets(owner, card).is_empty(): return {}
	return card

static func requires_target(gs, owner: int, src: int) -> bool:
	return ready(gs, owner, src).get("target", "auto") != "auto"

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("battle-skill-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[src]
	match kind:
		"battle-skill-begin":
			var commit := frame.duplicate(true); commit.kind = "battle-skill-commit"
			gs.resolution_stack.append(commit)
			gs.VerifiedRules.Butterfly.before_basic(gs, owner, src)
			gs.VerifiedRules.Garuda.before_basic(gs, owner, src)
			gs.VerifiedRules.Baize.before_basic(gs,owner,src)
			gs.VerifiedRules.Crocodile.before_basic(gs,owner,src)
			gs.VerifiedRules.Whale.before_basic(gs,owner,src)
		"battle-skill-commit":
			if not gs.VerifiedRules.Samurai.available(unit) or gs.winner >= 0: return true
			gs.resolution_stack.append({"kind": "battle-skill-finish", "playerIndex": owner, "sourceIndex": src})
			var card: Dictionary = frame.skill.duplicate(true)
			if card.is_empty():
				gs._resolve_combat(owner, src, 0, false, false, false, false, frame.targetId, bool(gs.VerifiedRules.Yitiao.basic_traits(unit).get("critical",false)), {"basicAttack": true}.merged(gs.VerifiedRules.Yitiao.basic_traits(unit)))
			else:
				card.yitiaoDeploymentTraits = gs.VerifiedRules.Yitiao.basic_traits(unit)
				card.battleSkillTriggered = true
				card.sourceZone = "ability"
				if card.type != "combat": gs._prepare_encourage(owner)
				gs.player(owner).cardsPlayedThisTurn += 1
				gs._push_card_frames(owner, str(card.id), null if card.target == "auto" else frame.targetId, card, src, 0)
				gs._log("%s 战技出击，使用「%s」。" % [unit.name, card.name], gs.TONE_CARD)
				gs.VerifiedRules.event(gs, "battle-skill-used", {"player": owner, "uid": unit.uid, "card": card, "target": frame.targetId})
		"battle-skill-finish":
			unit.erase("enraged")
			gs.VerifiedRules.Butterfly.after_basic(gs, owner, src)
	return true

static func unit_marks(gs, owner: int, src: int) -> Array:
	var unit: Dictionary = gs.player(owner).units[src]
	var card := Content.card_def(str(unit.get("battleSkillId", "")))
	if card.is_empty(): return []
	return ["战技 · %s · %s" % [card.name, "首次出击可用" if not ready(gs, owner, src).is_empty() else "本次普通出击"]]
