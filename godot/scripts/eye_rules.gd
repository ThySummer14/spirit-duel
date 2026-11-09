class_name EyeRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const CURSES := {
	"eye-curse-life": ["生命上限变为8", "将你的生命上限变为8；当前生命超过8时降至8。"],
	"eye-curse-hand": ["弃掉一半手牌", "随机弃掉你一半的手牌。"],
	"eye-curse-units": ["随机消灭两个式神", "随机消灭己方两个未气绝的式神。"],
	"eye-curse-lose": ["输掉本局游戏", "你立即输掉本局游戏。"],
}

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func bonus(gs, owner: int) -> int:
	var total := 0
	for unit in gs.player(owner).units:
		if active(unit): total += int(unit.get("formRules", {}).get("eyeDivinationBonus", 0))
	return total

static func divined(gs, owner: int, count: int) -> void:
	for idx in range(gs.player(owner).units.size() - 1, -1, -1):
		var unit: Dictionary = gs.player(owner).units[idx]
		if active(unit) and Content.runtime_unit_def(unit).get("eyeDivination", false):
			gs.resolution_stack.append({"kind": "eye-projectile", "playerIndex": owner, "sourceIndex": idx, "amount": count if unit.awakened else 1})

static func curse_deck(gs, owner: int, count: int) -> void:
	var pool: Array = gs.player(1 - owner).deck.duplicate()
	gs._shuffle(pool)
	for i in mini(count, pool.size()):
		pool[i].eyeCurses = int(pool[i].get("eyeCurses", 0)) + 1
		gs.VerifiedRules.event(gs, "eye-curse-attached", {"player": owner, "victimPlayer": 1 - owner, "instanceId": pool[i].instanceId, "count": pool[i].eyeCurses})

static func drawn(gs, owner: int, inst: Dictionary) -> void:
	if owner != gs.current_player: return
	for i in int(inst.get("eyeCurses", 0)):
		gs.resolution_stack.append({"kind": "eye-curse", "playerIndex": owner})

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("eyeRules", false) and int(inst.get("eyeCurses", 0)) == 0: return card
	var out := card.duplicate(true)
	if int(inst.get("eyeCurses", 0)) > 0: out.text += "\n结附诅咒×%d：己方回合抽到时选择未选过的诅咒。" % int(inst.eyeCurses)
	if card.get("effect") == "eye-flame":
		out.value = 2 + int(gs.player(owner).get("eyeFlameGrowth", 0))
		out.effects[0].value = out.value
		out.text += "\n当前伤害%d。" % int(out.value)
		if int(out.value) > 2: out.enhanced = true; out.currentCardStats = "当前伤害 %d" % int(out.value)
		out.eyeInstance = inst.duplicate(true)
	return out

static func form_entered(gs, owner: int, _idx: int, card: Dictionary) -> void:
	if card.get("formRules", {}).get("eyeCurse", false): curse_deck(gs, owner, 4)

static func turn_start(gs, owner: int, idx: int) -> void:
	if active(gs.player(owner).units[idx]) and gs.player(owner).units[idx].get("formRules", {}).get("eyeCurse", false):
		gs.resolution_stack.append({"kind": "eye-enemy-divination", "playerIndex": owner, "count": 1})

static func choice_card(gs, _owner: int, iid: String):
	if gs.pending_choice.get("type") != "eye-curse": return null
	if not CURSES.has(iid): return {}
	return {"id": iid, "name": CURSES[iid][0], "typeLabel": "诅咒选择", "text": CURSES[iid][1]}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "eye-curse" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	var p: Dictionary = gs.player(owner)
	var used: Array = p.get("eyeCursesChosen", [])
	used.append(iid); p.eyeCursesChosen = used
	gs._record("resolve_divination_choice", {"instanceId": iid, "choice": "eye-curse", "card": ""}, owner)
	gs.pending_choice = {}; gs.phase = "main"
	match iid:
		"eye-curse-life": p.maxAvatarHp = 8; p.avatarHp = mini(8, int(p.avatarHp))
		"eye-curse-hand":
			var count := int(p.hand.size() / 2)
			var eligible: Array = p.hand.duplicate()
			for i in count:
				var selected: Dictionary = eligible.pop_at(int(floor(gs.randf01() * eligible.size())))
				gs.discard_hand_card(owner, p.hand.find(selected))
		"eye-curse-units":
			var pool: Array = p.units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))
			gs._shuffle(pool)
			for i in mini(2, pool.size()): gs.VerifiedRules.Panguan.destroy(gs, 1-owner, gs._source_index(1-owner, {"unitId":"baimugui"}), owner, gs._unit_index_by_uid(owner, str(pool[i].uid)))
		"eye-curse-lose": p.avatarHp = 0; gs._check_winner()
	gs.VerifiedRules.event(gs, "eye-curse-chosen", {"player": owner, "choice": iid, "used": used.duplicate()})
	gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "eye-curse": return null
	var options: Array = gs.pending_choice.instanceIds
	for id in ["eye-curse-hand", "eye-curse-life", "eye-curse-units", "eye-curse-lose"]:
		if id in options: return resolve_choice(gs, owner, id)
	return false

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", 0))
	match str(frame.get("kind", "")):
		"eye-projectile":
			var unit: Dictionary = gs.player(owner).units[int(frame.sourceIndex)]
			var ability := {"id": "eye-projection", "unitId": unit.id, "name": "占卜投射", "type": "ability", "typeLabel": "基础能力", "text": "投射：造成%d点伤害。" % int(frame.amount), "effects": [{"action": "damage-enemy-front", "value": int(frame.amount)}]}
			gs.VerifiedRules.event(gs, "ability-trigger", {"player": owner, "uid": unit.uid, "card": ability, "reason": "占卜投射", "amount": int(frame.amount)})
			var idx: int = gs.front_index(1 - owner)
			if idx < 0: gs.VerifiedRules.base_damage_avatar(gs,owner,int(frame.sourceIndex),1-owner,int(frame.amount))
			else: gs.VerifiedRules.base_damage_unit(gs,owner,int(frame.sourceIndex),1-owner,idx,int(frame.amount))
		"eye-enemy-divination": gs.VerifiedRules.Divination.start(gs, 1 - owner, int(frame.count), owner)
		"eye-curse":
			var ids: Array = CURSES.keys().filter(func(id): return id not in gs.player(owner).get("eyeCursesChosen", []))
			if ids.is_empty(): return true
			gs.pending_choice = {"type": "eye-curse", "playerIndex": owner, "instanceIds": ids, "heading": "诅 咒", "title": "选择一个未生效过的诅咒", "hint": "本局每种诅咒只能选择一次。"}
			gs.phase = "choice"
		"eye-flame-return":
			gs.player(owner).eyeFlameGrowth = int(gs.player(owner).get("eyeFlameGrowth", 0)) + 2
			gs.player(owner).deck.append(frame.instance.duplicate(true)); gs._shuffle(gs.player(owner).deck)
		"eye-gaze-hit": damage(gs, owner, int(frame.sourceIndex), frame.targetId, int(frame.amount))
		_: return false
	return true

static func damage(gs, owner: int, src: int, target_id, amount: int) -> Dictionary:
	for victim in gs.players.size():
		if str(target_id) == "avatar-%d" % victim: return {"damage": gs._damage_avatar(victim, amount, owner, src), "overkill": 0}
		var idx: int = gs._unit_index_by_uid(victim, target_id)
		if idx >= 0: return gs._damage_unit(victim, idx, amount, owner, src)
	return {"damage": 0, "overkill": 0}

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	match str(effect.get("action", "")):
		"eye-divination": gs.VerifiedRules.Divination.start(gs, owner, int(effect.value))
		"eye-awaken": gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
		"eye-flame":
			var inst: Dictionary = card.get("eyeInstance", {})
			if inst.is_empty():
				inst = {"instanceId": "%s-eye-%d" % [gs.player(owner).id, gs.next_card_id], "definitionId": card.id}; gs.next_card_id += 1
			gs.resolution_stack.append({"kind": "eye-flame-return", "playerIndex": owner, "instance": inst.duplicate(true)})
			if target.is_empty(): return true
			var amount := int(effect.value) + int(card.get("foxHandDamageBonus", 0))
			var barrier_excess := maxi(0, amount - int(target.hp) - int(target.shield)) if target.get("barrier", false) else 0
			var hit := damage(gs, owner, src, target_id, amount)
			var excess := maxi(barrier_excess, int(hit.get("overkill", 0)))
			if excess > 0: gs._damage_avatar(1 - owner, excess, owner, src)
		"eye-draw-gaze":
			var deck: Array = gs.player(owner).deck
			var level := 0 if deck.is_empty() else int(Content.card_def(str(deck.back().definitionId)).level)
			gs.resolution_stack.append({"kind": "eye-gaze-hit", "playerIndex": owner, "sourceIndex": src, "targetId": target_id, "amount": level * 2 + int(card.get("foxHandDamageBonus", 0))})
			gs._draw(owner, 1)
		"eye-all-knowing":
			var deck: Array = gs.player(1 - owner).deck
			if deck.is_empty(): return true
			var top: Dictionary = Content.card_def(str(deck.back().definitionId))
			gs.VerifiedRules.event(gs, "eye-top-revealed", {"player": owner, "victimPlayer": 1 - owner, "card": top})
			for unit_id in Content.card_unit_ids(top):
				var idx: int = gs._source_index(1 - owner, {"unitId": unit_id})
				if idx >= 0 and int(gs.player(1 - owner).units[idx].hp) > 0:
					gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1 - owner, idx, card)
		"eye-enemy-divination": gs.VerifiedRules.Divination.start(gs, 1 - owner, int(effect.value), owner)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("eyeRules", false): return null
	match str(card.effect):
		"eye-awaken": return -100 if gs.player(owner).units[gs._source_index(owner, card)].awakened else 85
		"eye-draw-gaze", "eye-flame":
			var raw=card.get("value",0)
			return 60 + (0 if raw==null else int(raw)) if str(target_id).begins_with("avatar-%d" % (1 - owner)) or gs._unit_index_by_uid(1 - owner, target_id) >= 0 else -100
		"move-unit":
			var idx: int = gs._unit_index_by_uid(1 - owner, target_id)
			return 70 if idx >= 0 and int(gs.player(1 - owner).units[idx].front) == 1 else 25
		"form": return -100 if gs.player(owner).units[gs._source_index(owner, card)].get("form", {}).get("cardId") == card.id else 65
	return 55
