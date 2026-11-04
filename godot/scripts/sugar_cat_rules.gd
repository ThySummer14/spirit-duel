class_name SugarCatRules
extends RefCounted
## 猫掌柜与饴细工：真实食物、三猫实体、糖人融合及离场生命周期。
const Content := preload("res://scripts/content_loader.gd")
const Cooking := preload("res://scripts/cooking_rules.gd")
const CAT_NAMES := {"one": "一条", "four": "四饼", "two": "二瞳"}
const CAT_CARDS := {"one": "c24602", "four": "c24603", "two": "c24605"}
const CAT_TEXT := {"one": "当你对一条使用食材时，抽一张牌。", "four": "当你对四饼使用食材时，本局游戏中猫掌柜的所有召唤物永久获得1力量。", "two": "当你对二瞳使用食材时，对一个随机敌方式神造成3点伤害。"}

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("sugarCatRole", ""))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp", 0)) > 0 and int(u.get("level", 0)) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)
static func _source(gs, owner: int, uid: String) -> int:
	return gs._unit_index_by_uid(owner, uid)
static func _frame(gs, kind: String, owner: int, src: int, extra: Dictionary = {}) -> void:
	var f := {"kind": kind, "playerIndex": owner, "sourceIndex": src}
	f.merge(extra, true); gs.resolution_stack.append(f)
static func _foods(gs, owner: int) -> int:
	return Cooking.hand_food_count(gs, owner, "ingredient") + Cooking.hand_food_count(gs, owner, "feast")
static func _cat_history(gs, owner: int) -> Array:
	return gs.player(owner).get("scCatHistory", []).duplicate()
static func _house_count(gs, owner: int) -> int:
	var n := 0
	for u in gs.player(owner).units:
		if active(u) and u.get("formRules", {}).get("scHouse", false): n += 1
	return n

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex); var caster := int(frame.sourceIndex)
	if card.get("neutralFood", false) or not Content.is_spell(card) or caster < 0 or caster >= gs.player(owner).units.size(): return
	if not gs.VerifiedRules.OwlInsect.shikigami(gs.player(owner).units[caster]): return
	for src in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[src]
		if role(u) != "sugar" or not active(u) or (not u.awakened and src != caster) or int(u.get("scCookTurn", -1)) == gs.turn_counter: continue
		u.scCookTurn = gs.turn_counter
		_frame(gs, "sc-cook", owner, src)

static func rule_event(gs, kind: String, details: Dictionary) -> void:
	var owner := int(details.get("player", -1))
	if owner < 0 or owner > 1: return
	if kind == "unit-moved" and int(details.get("front", 1)) == 0:
		var idx := _source(gs, owner, str(details.get("uid", "")))
		if idx >= 0: remove_summon(gs, owner, gs.player(owner).units[idx])
	elif kind == "summon-created" or kind == "summon-revived":
		var idx := _source(gs, owner, str(details.get("uid", "")))
		if idx < 0: return
		var entered: Dictionary = gs.player(owner).units[idx]
		for src in gs.player(owner).units.size():
			var cat: Dictionary = gs.player(owner).units[src]
			if role(cat) == "cat" and active(cat) and (cat.awakened or (entered.has("scCatType") and str(entered.get("summonerUid", "")) == str(cat.uid))):
				_frame(gs, "sc-feed", owner, src, {"targetUid": str(entered.uid)})
	elif kind == "food-used":
		var food_kind := str(details.get("kind", ""))
		var target_owner := int(details.get("targetOwner", owner))
		var idx := _source(gs, target_owner, str(details.get("targetUid", "")))
		if idx >= 0 and food_kind in ["ingredient", "unknown"]:
			var target: Dictionary = gs.player(target_owner).units[idx]
			if target.has("scCatType") and active(target):
				for _i in 1 + _house_count(gs, target_owner):
					_frame(gs, "sc-cat-base", target_owner, idx, {"catType": str(target.scCatType), "targetUid": str(target.uid)})
		if details.get("fromHand", false) and food_kind in ["feast", "dark"]:
			for src in gs.player(owner).units.size():
				var sugar: Dictionary = gs.player(owner).units[src]
				if active(sugar) and sugar.get("formRules", {}).get("sugarMaster", false): _frame(gs, "sc-candy", owner, src, {"big": true})

static func begin_turn(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size() - 1, -1, -1):
		var u: Dictionary = gs.player(owner).units[src]
		if not active(u): continue
		if u.get("formRules", {}).get("sugarReviveFood", false): _frame(gs, "sc-cook", owner, src)
		if u.get("formRules", {}).get("scHouse", false): _frame(gs, "sc-house", owner, src)
		if role(u) == "cat" and u.awakened: _frame(gs, "sc-gain", owner, src)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules", {}).get("sugarMaster", false): _frame(gs, "sc-candy", owner, src, {"big": false})
	if card.get("formRules", {}).get("scHouse", false): _frame(gs, "sc-house", owner, src)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("sugarCatRules", false): return card
	var c := card.duplicate(true)
	if c.id == "c24601":
		c.scInstance = inst.duplicate(true)
		if inst.get("scBounceSpent", false): c.keywords.erase("bounce")
	if c.id == "c24902":
		c.enhanced = Cooking.feast_count(gs, owner) >= 3
		if c.enhanced and not c.keywords.has("instant"): c.keywords.append("instant")
		c.currentCardStats = "本局已获得佳肴%d／3" % Cooking.feast_count(gs, owner)
	if c.id == "c24901": c.currentCardStats = "手牌食材及佳肴%d · 恢复%d生命" % [_foods(gs, owner), _foods(gs, owner)]
	if c.id == "c24904": c.currentCardStats = "当前伤害%d" % (4 + _foods(gs, owner))
	if c.id == "c24907": c.currentCardStats = "小糖人%d · 大糖人%d" % [Cooking.hand_food_count(gs, owner, "ingredient"), Cooking.hand_food_count(gs, owner, "feast")]
	if c.id == "c24908": c.currentCardStats = "本局已获得佳肴%d／6；特殊佳肴定义待核验" % Cooking.feast_count(gs, owner)
	return c
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("sugarCatRules", false) or card.id not in ["c24901", "c24904"]: return null
	var ids: Array = []
	for side in [owner, 1 - owner]:
		if card.id == "c24901": ids.append("avatar-%d" % side)
		for u in gs.player(side).units:
			if int(u.hp) <= 0 or int(u.level) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
			if side != owner and gs.VerifiedRules.Combat.has(u, "veil"): continue
			ids.append(str(u.uid))
	return ids
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("sugarCatRules", false) and card.id in ["c24604", "c24906"]:
		var src: int = gs._source_index(owner, card)
		return src >= 0 and not gs.player(owner).units[src].awakened
	return true

static func _token(gs, owner: int, src: int, cat_type: String = "", big: bool = false) -> Dictionary:
	var p: Dictionary = gs.player(owner); var master: Dictionary = p.units[src]
	var candy := cat_type.is_empty(); var attack := (4 if big else 2) if candy else 3
	var hp := attack if candy else 4; var bonus := 0 if candy else int(p.get("scCatPower", 0))
	var name := ("大糖人" if big else "小糖人") if candy else str(CAT_NAMES[cat_type])
	var id := ("sugar-big" if big else "sugar-small") if candy else "cat-" + cat_type
	var file := ("big.png" if big else "small.png") if candy else ("four.jpg" if cat_type == "four" else cat_type + ".png")
	var u: Dictionary = {"uid": "%s:sc-summon-%d" % [p.id, gs.next_card_id], "id": id, "name": name, "title": "饴细工召唤物" if candy else "猫掌柜召唤物", "art": "assets/official/summons/" + file, "color": "#e0b070", "baseAttack": attack, "baseMaxHp": hp, "attack": attack + bonus, "maxHp": hp, "hp": hp, "shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0, "unyielding": big, "level": 1, "front": 1, "attackBonus": bonus, "maxHpBonus": 0, "awakened": false, "form": {}, "formRules": {}, "charge": 0, "passive_hooks": [], "summoned": true, "summon": true, "countsAsShikigami": true, "scSummon": true, "summonerUid": str(master.uid), "keywords": ["unyielding"] if big else []}
	u.formAbility = ("融合。不屈。离开战斗区移除。" if big else "融合。离开战斗区移除。") if candy else str(CAT_TEXT[cat_type]) + "离开战斗区移除。"
	if candy: u.scCandy = true; u.scBigCandy = big; u.scFusionCount = 0
	else: u.scCatType = cat_type; u.scCatApplied = bonus
	gs.next_card_id += 1
	return u
static func live_candy(gs, owner: int, except_index: int = -1) -> int:
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if i != except_index and u.get("scCandy", false) and int(u.hp) > 0 and int(u.front) == 1 and not u.get("removed", false): return i
	return -1
static func _fuse(gs, owner: int, incoming: Dictionary, old_index: int, incoming_index: int = -1) -> int:
	# Weaver's generic fusion preserves actual wounded bodies, auras, keywords,
	# charms and separate grave snapshots; neither material is a stat surrogate.
	var old: Dictionary = gs.player(owner).units[old_index]
	var count := int(old.get("scFusionCount", 0)) + int(incoming.get("scFusionCount", 0)) + 1
	var idx: int = gs.VerifiedRules.Weaver.combine(gs, owner, incoming, old_index, incoming_index)
	var fused: Dictionary = gs.player(owner).units[idx]
	fused.scCandy = true; fused.scSummon = true; fused.scFusionCount = count
	fused.scBigCandy = old.get("scBigCandy", false) or incoming.get("scBigCandy", false)
	fused.id = "sugar-big" if fused.scBigCandy else "sugar-small"
	fused.art = "assets/official/summons/" + ("big.png" if fused.scBigCandy else "small.png")
	fused.name = "糖人"; fused.formAbility = ("融合。不屈。" if fused.unyielding else "融合。") + "离开战斗区移除。"
	gs.VerifiedRules.event(gs, "sugar-fused", {"player": owner, "uid": fused.uid, "previousUid": old.uid, "incomingUid": incoming.uid, "count": count})
	return idx
static func summon(gs, owner: int, src: int, cat_type: String = "", big: bool = false, attack_mode: String = "") -> int:
	var p: Dictionary = gs.player(owner); var u := _token(gs, owner, src, cat_type, big)
	if cat_type.is_empty():
		var old := live_candy(gs, owner)
		if old >= 0: return _fuse(gs, owner, u, old)
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	p.units.append(u); var idx: int = p.units.size() - 1
	if not cat_type.is_empty():
		var history := _cat_history(gs, owner)
		if not history.has(cat_type): history.append(cat_type)
		p.scCatHistory = history
	if not attack_mode.is_empty(): _frame(gs, "sc-cat-attack", owner, idx, {"targetUid": str(u.uid), "mode": attack_mode})
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": u.uid, "sourceUid": u.summonerUid, "summonKind": "candy" if cat_type.is_empty() else "cat-" + cat_type})
	gs.VerifiedRules.Weaver.entered(gs, owner, idx)
	return idx
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("scSummon", false) or u.get("removed", false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs, owner, _source(gs, owner, str(u.uid)), reason)
	gs.VerifiedRules.Vine.remove_charm(gs, owner, _source(gs, owner, str(u.uid)), reason, false)
	u.hp = 0; u.front = 0; u.knockout = 0; u.removed = true
	u.erase("weaverGrave"); u.erase("weaverReviveReason")
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": u.uid, "reason": reason})
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	if not u.get("scSummon", false): return
	u.hp = 0; u.front = 0; u.knockout = 0; u.removed = true
	gs.VerifiedRules.event(gs, "sugar-cat-summon-died", {"player": owner, "uid": u.uid})
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("scSummon", false) and int(u.front) == 0 and int(u.hp) > 0: remove_summon(gs, owner, u)
static func _sync_cat_power(gs, owner: int) -> void:
	var bonus := int(gs.player(owner).get("scCatPower", 0))
	for u in gs.player(owner).units:
		if not u.has("scCatType"): continue
		var delta := bonus - int(u.get("scCatApplied", 0))
		if int(u.hp) > 0 and not u.get("removed", false): gs._grow_unit(u, delta, 0); u.scCatApplied = bonus
		if u.has("weaverGrave"):
			var saved: Dictionary = u.weaverGrave; var grave_delta := bonus - int(saved.get("scCatApplied", 0))
			saved.attackBonus = int(saved.attackBonus) + grave_delta; saved.attack = int(saved.attack) + grave_delta; saved.scCatApplied = bonus
static func revived(gs, owner: int, _idx: int) -> void:
	_sync_cat_power(gs, owner)
static func fuse_revived(gs, owner: int, idx: int) -> int:
	if not gs.player(owner).units[idx].get("scCandy", false): return -1
	var old := live_candy(gs, owner, idx)
	return _fuse(gs, owner, gs.player(owner).units[idx], old, idx) if old >= 0 else -1

static func _choice(gs, owner: int, src: int, mode: String) -> void:
	var options: Dictionary = {}; var ids: Array = []
	if mode == "sc-ingredient":
		for inst in Cooking.ingredient_options(gs, owner, src):
			var id := "sc-food-" + str(inst.foodData.ingredientKind)
			options[id] = inst; ids.append(id)
	else:
		for cat_type in CAT_NAMES:
			var id := "sc-cat-" + str(cat_type); options[id] = str(cat_type); ids.append(id)
	gs.pending_choice = {"type": mode, "playerIndex": owner, "sourceIndex": src, "zone": "sc-choice", "instanceIds": ids, "options": options, "heading": "食 材 购 入" if mode == "sc-ingredient" else "猫 合 战", "title": "选择一张食材置入手牌" if mode == "sc-ingredient" else "选择召唤物", "hint": "所选食材按猫掌柜当前等级生成。" if mode == "sc-ingredient" else "召唤所选猫咪，然后对敌方牌手造成2点伤害。"}
	gs.phase = "choice"
static func choice_card(gs, owner: int, iid: String):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type", "") not in ["sc-ingredient", "sc-cat"]: return null
	if int(choice.playerIndex) != owner or not choice.options.has(iid): return {}
	if choice.type == "sc-ingredient":
		var c := Cooking.describe_food(gs, owner, choice.options[iid]); c.id = iid; return c
	var cat_type := str(choice.options[iid]); var c := Content.card_def(str(CAT_CARDS[cat_type])).duplicate(true)
	c.id = iid; c.unitId = "cat-" + cat_type; c.name = str(CAT_NAMES[cat_type]); c.typeLabel = "召唤物选择"; c.text = "3力量／4生命。" + str(CAT_TEXT[cat_type]); c.currentCardStats = "%d／4" % (3 + int(gs.player(owner).get("scCatPower", 0)))
	return c
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type", "") not in ["sc-ingredient", "sc-cat"] or int(choice.playerIndex) != owner or not choice.options.has(iid): return false
	var src := int(choice.sourceIndex); var picked = choice.options[iid]; var kind := str(choice.type)
	gs._record("resolve_divination_choice", {"instanceId": iid, "choice": kind, "card": ""}, owner)
	gs.pending_choice = {}; gs.phase = "main"
	if kind == "sc-ingredient": Cooking.gain_ingredient(gs, owner, src, str(picked.foodData.ingredientKind))
	else:
		_frame(gs, "sc-avatar-hit", owner, src, {"amount": 2})
		summon(gs, owner, src, str(picked))
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true
static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type", "") not in ["sc-ingredient", "sc-cat"]: return null
	var ids: Array = gs.pending_choice.instanceIds
	return resolve_choice(gs, owner, str(ids[int(gs.next_random() % ids.size())]))

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if str(effect.get("action", "")) != "sc-card": return false
	match str(card.id):
		"c24601": _choice(gs, owner, src, "sc-ingredient")
		"c24602": summon(gs, owner, src, "one", false, "immune")
		"c24603": summon(gs, owner, src, "four", false, "immune")
		"c24605": summon(gs, owner, src, "two", false, "immune")
		"c24604": gs._awaken(owner, src, card, {"attack": 1, "hp": 1}); Cooking.gain_ingredient(gs, owner, src)
		"c24606": _choice(gs, owner, src, "sc-cat")
		"c24607":
			var history := _cat_history(gs, owner)
			for i in range(history.size() - 1, -1, -1): _frame(gs, "sc-summon-cat", owner, src, {"catType": str(history[i]), "mode": "random"})
		"c24608", "c24903", "c24905": gs._apply_form(owner, src, card, card.value)
		"c24901":
			_frame(gs, "sc-heal", owner, src, {"amount": _foods(gs, owner)})
			gs.VerifiedRules.Eye.damage(gs, owner, src, target_id, 3 + int(card.get("foxHandDamageBonus", 0)))
		"c24902": gs._draw(owner, 2)
		"c24904": gs.VerifiedRules.Eye.damage(gs, owner, src, target_id, 4 + _foods(gs, owner) + int(card.get("foxHandDamageBonus", 0)))
		"c24906": gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
		"c24907":
			var small := Cooking.hand_food_count(gs, owner, "ingredient"); var big := Cooking.hand_food_count(gs, owner, "feast")
			for _i in big: _frame(gs, "sc-candy", owner, src, {"big": true})
			for _i in small: _frame(gs, "sc-candy", owner, src, {"big": false})
		"c24908":
			var gained := Cooking.gain_feast(gs, owner, src)
			if not gained.is_empty() and Cooking.feast_count(gs, owner) >= 6:
				for u in gs.player(owner).units:
					if gs.VerifiedRules.OwlInsect.shikigami(u): gs._grow_unit(u, 5, 5)
				gs._heal_avatar(owner, 10)
		_: return false
	return true
static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	if str(card.get("id", "")) != "c24601" or not card.get("usedFromHand", false): return
	var inst: Dictionary = card.get("scInstance", {}).duplicate(true)
	if inst.is_empty() or inst.get("scBounceSpent", false): return
	inst.scBounceSpent = true
	var owner := int(frame.playerIndex)
	if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
	else: gs._log("手牌已满，弹回的食材购入被烧毁。", gs.TONE_DANGER)
	gs.VerifiedRules.event(gs, "sugar-cat-card-returned", {"player": owner, "instanceId": str(inst.instanceId), "card": card})
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", 0)); var src := int(frame.get("sourceIndex", -1))
	match str(frame.get("kind", "")):
		"sc-cook": Cooking.cook(gs, owner, src)
		"sc-gain":
			if active(gs.player(owner).units[src]): Cooking.gain_ingredient(gs, owner, src)
		"sc-house":
			if active(gs.player(owner).units[src]) and gs.player(owner).units[src].get("formRules", {}).get("scHouse", false):
				_frame(gs, "sc-summon-cat", owner, src, {"catType": ["one", "four", "two"][int(gs.next_random() % 3)], "mode": ""})
				Cooking.gain_ingredient(gs, owner, src)
		"sc-feed":
			var idx := _source(gs, owner, str(frame.targetUid))
			if idx >= 0 and active(gs.player(owner).units[src]) and int(gs.player(owner).units[idx].hp) > 0 and not gs.player(owner).units[idx].get("removed", false): Cooking.auto_use_from_hand(gs, owner, src, str(frame.targetUid), "ingredient")
		"sc-cat-base":
			var idx := _source(gs, owner, str(frame.targetUid))
			if idx < 0: return true
			match str(frame.catType):
				"one": gs._draw(owner, 1)
				"four": gs.player(owner).scCatPower = int(gs.player(owner).get("scCatPower", 0)) + 1; _sync_cat_power(gs, owner)
				"two":
					var pool: Array = gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and int(u.level) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))
					if not pool.is_empty(): gs.VerifiedRules.base_damage_unit(gs, owner, idx, 1 - owner, _source(gs, 1 - owner, str(pool[int(gs.next_random() % pool.size())].uid)), 3)
		"sc-candy": summon(gs, owner, src, "", bool(frame.big))
		"sc-summon-cat": summon(gs, owner, src, str(frame.catType), false, str(frame.get("mode", "")))
		"sc-cat-attack":
			var idx := _source(gs, owner, str(frame.targetUid))
			if idx < 0 or not active(gs.player(owner).units[idx]): return true
			var target = null; var options := {"scAutomatic": true, "immuneCombat": str(frame.mode) == "immune"}
			if str(frame.mode) == "random":
				var pool: Array = gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and int(u.level) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))
				if pool.is_empty(): return true
				target = str(pool[int(gs.next_random() % pool.size())].uid); options.pursuit = true
			gs._resolve_combat(owner, idx, 0, false, false, false, false, target, false, options)
		"sc-avatar-hit": gs._damage_avatar(1 - owner, int(frame.amount), owner, src)
		"sc-heal": gs._heal_avatar(owner, int(frame.amount))
		_: return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("sugarCatRules", false): return null
	if not can_use(gs, owner, card): return -100
	if card.id in ["c24901", "c24904"] and (str(target_id) == "avatar-%d" % owner or _source(gs, owner, str(target_id)) >= 0): return -100
	if card.id == "c24908": return -100 if card.get("cookingDirectFeastPool", []).is_empty() else 85
	if card.type == "form":
		var src: int = gs._source_index(owner, card); var u: Dictionary = gs.player(owner).units[src]
		return 75 if u.get("form", {}).get("cardId", "") != card.id or int(u.hp) < int(u.maxHp) else -10
	if card.id in ["c24604", "c24906"]: return 80
	if card.id == "c24607": return 20 + 25 * _cat_history(gs, owner).size()
	if card.id == "c24907": return 12 + 12 * _foods(gs, owner)
	return 50
static func marks(gs, owner: int, u: Dictionary) -> Array:
	var result: Array = []
	if role(u) == "cat": result.append("已召唤：" + "、".join(_cat_history(gs, owner).map(func(t): return str(CAT_NAMES[t]))))
	if role(u) == "sugar":
		result.append("本局获得佳肴%d · 手牌食物%d" % [Cooking.feast_count(gs, owner), _foods(gs, owner)])
		result.append("法术烹饪：" + ("本回合已触发" if int(u.get("scCookTurn", -1)) == gs.turn_counter else "本回合可触发"))
	if u.has("scCatType"): result.append("本局永久力量+%d" % int(gs.player(owner).get("scCatPower", 0)))
	if u.get("scCandy", false): result.append("融合%d次" % int(u.get("scFusionCount", 0)))
	return result
