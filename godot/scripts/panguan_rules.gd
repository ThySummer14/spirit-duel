class_name PanguanRules
extends RefCounted
## Destruction is a lifecycle event with an owner, not an arbitrary damage amount.

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("judgeLedger", false)

static func extra_knockout(gs, victim: int) -> int:
	var extra: int = gs.VerifiedRules.DuskCycle.ink_knockout_extra(gs, victim)
	for observer in gs.player(1 - victim).units:
		if int(observer.hp) > 0 and int(observer.level) > 0:
			extra += int(observer.get("formRules", {}).get("enemyKnockoutExtra", 0))
	return extra

static func destroyed(gs, owner: int, src: int, victim: int, target: Dictionary) -> void:
	if owner < 0: return
	gs.VerifiedRules.Otakemaru.unit_killed(gs,owner,src,victim,target)
	var p: Dictionary = gs.player(owner)
	p.destroyedUnits = int(p.get("destroyedUnits", 0)) + 1
	gs.VerifiedRules.event(gs, "kill-recorded", {"player": owner, "sourceIndex": src, "target": target.uid, "victimPlayer": victim, "count": p.destroyedUnits})
	for i in p.units.size():
		var judge: Dictionary = p.units[i]
		if not is_source(judge) or int(judge.hp) <= 0 or int(judge.level) < 1: continue
		if not judge.awakened and i != src: continue
		if gs.winner >= 0: break
		# The ability is its own source, even when a teammate made the kill.
		var context: Dictionary = gs._card_effect_context
		gs._card_effect_context = {}
		gs.VerifiedRules.base_damage_avatar(gs,owner,i,1-owner,1)
		if gs.winner < 0: gs._heal_avatar(owner, 1)
		gs._card_effect_context = context
		gs.VerifiedRules.event(gs, "judge-ledger", {"player": owner, "uid": judge.uid, "target": target.uid})

static func destroy(gs, owner: int, src: int, victim: int, idx: int, card: Dictionary = {}, extra: int = -1) -> bool:
	if idx < 0 or idx >= gs.player(victim).units.size() or gs.winner >= 0: return false
	var target: Dictionary = gs.player(victim).units[idx]
	if int(target.hp) <= 0 or gs.VerifiedRules.Zhenjian.prevent_destroy(target) or gs.VerifiedRules.WisdomLamp.protected(gs,victim,target): return false
	if gs.VerifiedRules.PeachGrove.petal_protects(gs, victim, target): return false
	if gs.VerifiedRules.Chen.ward(gs, victim, idx): return false
	gs._knockout_unit(target, owner, src, extra)
	if int(target.hp)>0: return false
	gs.VerifiedRules.Yaodao.unit_killed(gs, owner, src, victim, idx)
	gs.VerifiedRules.DragonFlow.unit_killed(gs, owner, src, victim, idx)
	gs.VerifiedRules.event(gs, "unit-destroyed", {"player": owner, "uid": "" if src < 0 else gs.player(owner).units[src].uid, "target": target.uid, "card": card})
	return true

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("judgeEnhance", false): return card
	var view := card.duplicate(true)
	var count := int(gs.player(owner).get("destroyedUnits", 0))
	view.enhanceCount = count
	if card.type == "form":
		view.value.attack = 4 + count
		view.effects[0].value.attack = view.value.attack
		view.text = "本局游戏你每消灭一个式神，此牌+1力量。已消灭%d个式神，当前形态%d力量/8生命。" % [count, 4 + count]
	else:
		view.combatOption.lethalAvatar = count >= 13
		view.text = ("消灭受到判官本次战斗伤害的角色。" if count >= 13 else "必杀。增强：本局游戏消灭13个式神后，可消灭受到本次战斗伤害的牌手。") + "进度 %d/13。" % count
	return view

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return not card.get("requiresBothFronts", false) or (gs.front_index(owner) >= 0 and gs.front_index(1 - owner) >= 0)

static func knocked_out(unit: Dictionary) -> void:
	unit.erase("judgeInkAttack")
	unit.erase("judgeInkHp")

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"judge-ink":
			if target.is_empty() or int(target.hp) <= 0: return true
			target.judgeInkAttack = int(target.get("judgeInkAttack", 0)) + 2
			target.judgeInkHp = int(target.get("judgeInkHp", 0)) + 1
			target.hp = maxi(0, int(target.hp) - 1)
			gs._recalc(target)
			if int(target.hp) <= 0:
				gs._knockout_unit(target, owner, src)
				gs.VerifiedRules.event(gs, "unit-destroyed", {"player": owner, "uid": unit.uid, "target": target.uid, "card": card})
		"judge-destroy":
			if target.is_empty() or int(target.hp) <= 0: return true
			if card.has("targetMaxAttack") and int(target.attack) > int(card.targetMaxAttack): return true
			for victim in 2:
				var idx: int = gs._unit_index_by_uid(victim, target.uid)
				if idx >= 0: destroy(gs, owner, src, victim, idx, card)
		"judge-exchange":
			var own: int = gs.front_index(owner)
			var enemy: int = gs.front_index(1 - owner)
			if own < 0 or enemy < 0: return true
			# Capture the aura for this exchange before its owner is destroyed.
			var own_extra := extra_knockout(gs, owner)
			var enemy_extra := extra_knockout(gs, 1 - owner)
			destroy(gs, owner, src, owner, own, card, own_extra)
			if gs.winner < 0: destroy(gs, owner, src, 1 - owner, enemy, card, enemy_extra)
		"judge-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0 or not is_source(gs.player(owner).units[src]): return null
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
	match str(card.get("effect", "")):
		"judge-ink": return 30 + int(enemy.get("attack", 0)) * 4 if not enemy.is_empty() else -100
		"judge-destroy": return 65 + int(enemy.get("attack", 0)) * 4 + int(enemy.get("hp", 0)) if not enemy.is_empty() else -100
		"judge-exchange":
			var own: Dictionary = gs.front_unit(owner)
			var foe: Dictionary = gs.front_unit(1 - owner)
			if own.is_empty() or foe.is_empty(): return -100
			return 35 + (int(foe.hp) + int(foe.attack) - int(own.hp) - int(own.attack)) * 5
		"judge-awaken": return 58 if not gs.player(owner).units[src].awakened else 8
		"form": return 55 if gs.player(owner).units[src].get("form", {}).get("cardId") != card.id else -100
		"assault":
			if card.get("combatOption", {}).get("lethalAvatar", false) and gs.front_index(1 - owner) < 0: return 500
			return 72 if gs.front_index(1 - owner) >= 0 else 8
	return null
