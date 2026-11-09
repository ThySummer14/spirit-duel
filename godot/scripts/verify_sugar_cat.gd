extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const SC := preload("res://scripts/sugar_cat_rules.gd")
const Food := preload("res://scripts/cooking_rules.gd")
const SPECIAL_TRAITS := {"swift":"迅捷","inspired":"昂扬","pursuit":"追猎","remote":"远程","lethal":"必杀","pierce":"贯通"}

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1; printerr("SUGAR_CAT_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["maozhanggui", "yixigong", "bingyong", "shantong"], ["bingyong", "shantong", "bailang", "hetong"], 246249)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "sugar-cat-%d" % gs.next_card_id}); gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "actual play " + id)
func strong(u: Dictionary, hp: int = 40, attack: int = 0) -> void:
	u.baseMaxHp = hp; u.maxHp = hp; u.hp = hp; u.baseAttack = attack; u.attack = attack; u.attackBonus = 0; u.maxHpBonus = 0
func front(gs, owner: int = 0) -> Dictionary:
	var idx: int = gs.front_index(owner)
	return gs.player(owner).units[idx] if idx >= 0 else {}
func used(gs, kind: String = "") -> Array:
	return gs.rule_events.filter(func(e): return e.kind == "food-used" and (kind.is_empty() or Food.food_kind(e.card) == kind))
func cook_count(gs) -> int:
	return gs.rule_events.filter(func(e): return e.kind == "cooking").size()
func feast(gs, owner: int = 0, src: int = 1) -> Dictionary:
	return Food.gain_feast(gs, owner, src, [{"attack": 1, "hp": 0}, {"attack": 0, "hp": 1}, {"keyword": "pierce"}])

func cat_cards() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(p.units[0].attack == 2 and p.units[0].maxHp == 5, "cat exact2/5")
	var energy: int = p.energy
	play(gs, "c24601")
	check(gs.pending_choice.get("type") == "sc-ingredient" and gs.pending_choice.instanceIds.size() == 3 and p.energy == energy, "ingredient purchase real3choice and instant payment")
	var pool: Array = gs.pending_choice.instanceIds
	for id in pool:
		var c: Dictionary = SC.choice_card(gs, 0, id)
		check(c.get("neutralFood", false) and c.foodData.quality == 3, "ingredient choice actual quality3 food " + id)
	check(not gs.resolve_divination_choice(1, "sc-food-mountain") and not gs.resolve_divination_choice(0, "bad"), "choice rejects wrong owner and invalid option")
	check(gs.resolve_divination_choice(0, "sc-food-mountain"), "actual selected mountain enters hand and resumes")
	var bounced: Array = p.hand.filter(func(i): return i.definitionId == "c24601")
	check(bounced.size() == 1 and bounced[0].get("scBounceSpent", false), "purchase returns same physical instance with bounce spent")
	var idx: int = p.hand.find(bounced[0]); check(not gs.hand_card_def(0, idx).keywords.has("bounce"), "spent bounce disappears in card projection")
	check(gs.play_card(0, idx), "actual second use of bounced purchase")
	gs.resolve_divination_choice(0, "sc-food-sea")
	check(not p.hand.any(func(i): return i.definitionId == "c24601"), "purchase cannot return a second time")
	p.hand.clear(); Food.gain_ingredient(gs, 0, 0, "mountain")
	strong(foe.units[0], 20, 12); foe.units[0].front = 1
	var deck: int = p.deck.size(); play(gs, "c24602")
	var one := front(gs)
	check(one.get("scCatType", "") == "one" and one.attack == 6 and one.maxHp == 4 and one.hp == 4, "actual one3/4 takes hand ingredient before attack and immune retaliation")
	check(p.deck.size() == deck - 1 and used(gs, "ingredient").size() == 1 and foe.units[0].hp == 14, "one food draws1 and actual6attack uses real buff")
	p.hand.clear(); Food.gain_ingredient(gs, 0, 0, "sea"); play(gs, "c24603")
	var four := front(gs)
	check(one.get("removed", false) and one.front == 0 and one.hp == 0, "cat replacement immediately removes previous entity")
	check(four.scCatType == "four" and four.attack == 4 and four.maxHp == 7 and four.hp == 7 and int(p.scCatPower) == 1, "four3/4 permanent+1power and actualsea+3hp")
	p.hand.clear(); Food.gain_ingredient(gs, 0, 0, "sea")
	var hp_sum: int = foe.units.reduce(func(acc, u): return acc + int(u.hp), 0); play(gs, "c24605")
	var two := front(gs)
	check(two.scCatType == "two" and two.attack == 4 and two.maxHp == 7 and two.hp == 7, "future cat retains four permanent power and attack immunity")
	check(foe.units.reduce(func(acc, u): return acc + int(u.hp), 0) == hp_sum - 7, "two ingredient base3 plus actual4attack, no avatar surrogate")
	p.hand.clear(); var hp: int = foe.avatarHp; play(gs, "c24606")
	check(gs.pending_choice.get("type") == "sc-cat" and gs.pending_choice.instanceIds.size() == 3, "cat battle real3summon choice")
	check(SC.choice_card(gs, 0, "sc-cat-one").text.contains("抽一张"), "summon option exposes actual base ability")
	check(gs.resolve_divination_choice(0, "sc-cat-one"), "actual cat choice resolves")
	check(front(gs).scCatType == "one" and foe.avatarHp == hp - 2, "chosen summon enters before exactly2avatar damage")
	p.hand.clear(); for u in foe.units: strong(u)
	var count: int = p.units.size(); hp_sum = foe.units.reduce(func(acc, u): return acc + int(u.hp), 0); hp = foe.avatarHp
	play(gs, "c24607")
	check(p.units.size() == count + 3 and foe.avatarHp == hp, "cat brawl summons recorded types and attacks shikigami rather than avatar")
	check(foe.units.reduce(func(acc, u): return acc + int(u.hp), 0) == hp_sum - 12, "brawl three real4power attacks without flat damage replacement")
	gs = game(); p = gs.player(0); play(gs, "c24607")
	check(p.units.size() == 4 and front(gs).is_empty(), "brawl with no prior summon does nothing")
	gs = game(); p = gs.player(0); play(gs, "c24604")
	check(p.units[0].awakened and p.units[0].attack == 3 and p.units[0].maxHp == 6 and Food.hand_food_count(gs, 0, "ingredient") == 1, "cat awakening exact1/1 and realrandom ingredient")
	p.hand.clear(); Food.gain_ingredient(gs, 0, 0, "mountain")
	SC.summon(gs, 0, 1, "", false); gs._resolve_resolution_stack()
	check(front(gs).get("scCandy", false) and front(gs).attack == 5 and Food.hand_food_count(gs, 0, "ingredient") == 0, "awakened cat feeds allied sugar summon from actual hand once")
	SC.begin_turn(gs, 1); gs._resolve_resolution_stack(); check(p.hand.is_empty(), "enemy turn does not grant cat ingredient")
	SC.begin_turn(gs, 0); gs._resolve_resolution_stack(); check(Food.hand_food_count(gs, 0, "ingredient") == 1, "own awakened start gains actual ingredient")
	p.hand.clear(); Food.gain_unknown(gs, 0, 0); SC.summon(gs, 0, 0, "one"); var unknown_deck: int = p.deck.size(); gs._resolve_resolution_stack()
	check(Food.hand_food_count(gs, 0, "ingredient") == 0 and used(gs, "unknown").size() == 1 and front(gs).armorBreak == 4 and p.deck.size() == unknown_deck - 1, "cat uses actualunknowningredient and triggersone base withoutfakebuff")
	var moving := front(gs); check(gs.VerifiedRules.Movement.move_to(gs, 0, gs.front_index(0), 0), "actual forced movement handles new cat token")
	check(moving.get("removed", false) and moving.hp == 0 and not moving.has("weaverGrave"), "forcedmove removescat immediately without fabricatedknockout")
	gs = game(); p = gs.player(0); p.units[0].hp = 0; p.units[0].knockout = 3; Food.gain_ingredient(gs, 0, 0, "mountain")
	SC.summon(gs, 0, 0, "one"); gs._resolve_resolution_stack()
	check(front(gs).attack == 3 and Food.hand_food_count(gs, 0, "ingredient") == 1, "KO cat does not feed its existing summon")
	gs = game(); p = gs.player(0); play(gs, "c24608")
	check(p.units[0].attack == 6 and p.units[0].maxHp == 6 and front(gs).has("scCatType") and used(gs).size() == 1, "house6/6 entry gains and actually feeds random cat")
	p.hand.clear(); Food.gain_ingredient(gs, 0, 0, "sea"); var before: int = int(p.get("scCatPower", 0))
	SC.summon(gs, 0, 0, "four"); gs._resolve_resolution_stack()
	check(int(p.scCatPower) == before + 2 and front(gs).attack == 3 + before + 2, "house repeats cat base once, never ingredient buff twice")
	check(front(gs).maxHp == 7, "house repeats base only, one actualsea ingredient+3hp")
	before = p.units.size(); SC.begin_turn(gs, 0); gs._resolve_resolution_stack()
	check(p.units.size() == before + 1 and front(gs).has("scCatType"), "house own start gains ingredient and new cat instance")

func sugar_cards() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(p.units[1].attack == 2 and p.units[1].maxHp == 5, "sugar exact2/5")
	p.avatarHp = 10; play(gs, "c24901", "avatar-1")
	check(cook_count(gs) == 1 and Food.hand_food_count(gs, 0, "ingredient") == 1 and p.avatarHp == 11 and foe.avatarHp == 27, "selfspell cooks before actual3damage and handcountheal1")
	play(gs, "c24902"); check(cook_count(gs) == 1, "base cook once per actual global turn")
	gs.turn_counter += 1; play(gs, "c24902"); check(cook_count(gs) == 2, "base cook resets on global turn")
	gs = game(); p = gs.player(0); play(gs, "c24601"); gs.resolve_divination_choice(0, "sc-food-mountain")
	check(cook_count(gs) == 0, "other shikigami spell cannot trigger unawakened sugar")
	gs = game(); p = gs.player(0); var h := give(gs, "c24902")
	check(not gs.hand_card_def(0, h).keywords.has("instant"), "rework not enhanced before3gainedfeast")
	feast(gs); feast(gs); check(not gs.hand_card_def(0, h).keywords.has("instant"), "twofeasts insufficient")
	feast(gs); check(gs.hand_card_def(0, h).keywords.has("instant"), "3feasts even before awake qualify")
	var energy: int = p.energy; var deck: int = p.deck.size(); check(gs.play_card(0, h), "actual enhanced rework use")
	check(p.energy == energy and p.deck.size() == deck - 2, "enhanced rework shared instantaneous payment and actualdraw2")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[1].scCookTurn = gs.turn_counter
	Food.gain_ingredient(gs, 0, 1, "sea"); feast(gs); strong(foe.units[1]); var hp: int = foe.units[1].hp
	play(gs, "c24904", foe.units[1].uid); check(foe.units[1].hp == hp - 6, "fusionfire exact4+twohandfood damages selected reserve shikigami")
	h = give(gs, "c24904"); var targets: Array = gs.valid_targets(0, gs.hand_card_def(0, h))
	check(not targets.has("avatar-1") and targets.has(str(p.units[0].uid)), "fusionfire targets anyshikigami, excludes avatars")
	foe.units[2].keywords = ["veil"]; targets = gs.valid_targets(0, gs.hand_card_def(0, h)); check(not targets.has(str(foe.units[2].uid)), "hostile manual target respects veil")
	gs = game(); p = gs.player(0); play(gs, "c24903")
	var candy := front(gs)
	check(Content.card_def("c24903").level == 1 and p.units[1].attack == 2 and p.units[1].maxHp == 6 and candy.attack == 2 and candy.hp == 2, "CNoriginal master1勾2/6 enters actual2/2smallcandy")
	candy.hp = 1; candy.keywords.append("pierce"); Food.gain_ingredient(gs, 0, 1, "sea")
	var f := feast(gs); h = p.hand.find(f); check(gs.play_card(0, h, p.units[0].uid), "manual neutral feast actualhanduse")
	var fused := front(gs)
	check(fused.uid != candy.uid and candy.get("removed", false) and candy.has("weaverGrave"), "fusion creates new entity and preserves consumed wounded entity grave")
	check(fused.attack == 6 and fused.maxHp == 6 and fused.hp == 5 and fused.unyielding and fused.keywords.has("pierce"), "actual2/1small+4/4big sums wounded body and transfers unyielding+keyword")
	check(not fused.get("weaverSummon", false) and not gs.VerifiedRules.Weaver.basic_blocked(gs, fused), "sugar fusion inherits no unrelated weaver attack prohibition")
	var uid := str(fused.uid)
	var generated: Dictionary = Food.describe_food(gs, 0, {"definitionId": "jia-yao", "foodData": {"kind": "feast", "quality": 3, "parts": [{"attack": 1}]}})
	Food._push_food(gs, 0, generated, p.units[0].uid, false, true); gs._resolve_resolution_stack()
	check(front(gs).uid == uid and used(gs, "feast").size() == 2, "actual newlygeneratedfeast does not summon bigcandy fromhand")
	f = feast(gs); Food.auto_use_from_hand(gs, 0, 1, p.units[0].uid, "feast"); gs._resolve_resolution_stack()
	check(front(gs).attack == 10 and front(gs).hp == 9 and front(gs).scFusionCount == 2, "automatic actualhandfeast does summon bigcandy and fuse")
	gs.VerifiedRules.Weaver.leave_front(gs, 0, 0); check(front(gs).is_empty() and p.units[-1].get("removed", false), "forced candy leaving removes without knockout revivalgrave")
	gs = game(); p = gs.player(0); play(gs, "c24903"); Food.gain_unknown(gs, 0, 1); Food.gain_unknown(gs, 0, 1); Food.cook(gs, 0, 1)
	var dark: Array = p.hand.filter(func(inst): return Food.food_kind(inst) == "dark")
	check(dark.size() == 1 and SC._foods(gs, 0) == 0 and Food.feast_count(gs, 0) == 0, "dark actualcooking is not ordinaryhandfeast or gainedfeasthistory")
	if not dark.is_empty():
		check(gs.play_card(0, p.hand.find(dark[0]), p.units[0].uid), "actual darkhanduse is legal neutralfood")
		check(front(gs).attack == 6 and front(gs).hp == 6 and front(gs).unyielding and used(gs, "dark").size() == 1, "darkhanduse countsfeast for master and summons realbigcandy")
	gs = game(); p = gs.player(0); play(gs, "c24905")
	check(p.units[1].attack == 3 and p.units[1].maxHp == 6, "oneheart exact3/6")
	p.units[0].hp = 0; p.units[0].knockout = 3; f = feast(gs); h = p.hand.find(f)
	check(gs.valid_targets(0, gs.hand_card_def(0, h)).has(str(p.units[0].uid)), "oneheart realfeast exposes KOally as legal target")
	check(gs.play_card(0, h, p.units[0].uid) and p.units[0].hp > 0 and p.units[0].knockout == 0, "neutral feast actually revives selected KOshikigami")
	var n := cook_count(gs); SC.begin_turn(gs, 1); gs._resolve_resolution_stack(); check(cook_count(gs) == n, "oneheart only ownstart cooks")
	SC.begin_turn(gs, 0); gs._resolve_resolution_stack(); check(cook_count(gs) == n + 1, "oneheart ownstart really cooks")
	gs = game(); p = gs.player(0); play(gs, "c24906")
	check(p.units[1].awakened and p.units[1].attack == 3 and p.units[1].maxHp == 6, "sugarawakening exact1/1")
	gs.turn_counter += 1; p.hand.clear(); play(gs, "c24601"); gs.resolve_divination_choice(0, "sc-food-sea")
	check(cook_count(gs) == 2, "awake otheralliedshikigami spell cooks once")
	n = cook_count(gs); f = feast(gs); h = p.hand.find(f); gs.turn_counter += 1
	check(gs.play_card(0, h, p.units[0].uid) and cook_count(gs) == n, "neutralfood has no invented source shikigami and cannot trigger awake cook")
	gs = game(); p = gs.player(0); p.units[1].scCookTurn = gs.turn_counter
	Food.gain_ingredient(gs, 0, 1, "mountain"); Food.gain_unknown(gs, 0, 1); feast(gs); feast(gs)
	play(gs, "c24907"); candy = front(gs)
	check(candy.attack == 12 and candy.hp == 12 and candy.unyielding and candy.scFusionCount == 3, "bitterandsweet actually2small then2big fuse into12/12unyielding")
	check(Food.hand_food_count(gs, 0, "ingredient") == 2 and Food.hand_food_count(gs, 0, "feast") == 2, "candycount does not consume handfood itself")
	var old := candy; gs._damage_unit(0, gs.front_index(0), 99, 1, 0); gs._resolve_resolution_stack()
	check(old.hp == 1 and not old.get("removed", false), "bigcandy fusion retains actual unyielding once")
	gs._damage_unit(0, gs.front_index(0), 99, 1, 0); gs._resolve_resolution_stack()
	check(old.hp == 0 and old.get("removed", false) and old.has("weaverGrave"), "second lethal causes actual summon death with grave")

func valid_special_feast(inst: Dictionary) -> bool:
	var food: Dictionary = inst.get("foodData", {})
	var parts: Array = food.get("parts", [])
	if Food.food_kind(inst) != "feast" or food.get("quality") != 3 or food.has("mergedFrom") or parts.size() != 3: return false
	var seen: Array = []
	for part in parts:
		var attack := int(part.get("attack", 0))
		var hp := int(part.get("hp", 0))
		var keyword := str(part.get("keyword", ""))
		if (1 if attack == 3 else 0) + (1 if hp == 3 else 0) + (1 if SPECIAL_TRAITS.has(keyword) else 0) != 1: return false
		if attack not in [0, 3] or hp not in [0, 3] or (not keyword.is_empty() and (not SPECIAL_TRAITS.has(keyword) or keyword in seen)): return false
		if not keyword.is_empty(): seen.append(keyword)
	return true

func special_feast() -> void:
	var card := Content.card_def("c24908")
	check(card.cookingSpecialFeastKeywords == SPECIAL_TRAITS.keys() and "instant" in card.keywords, "甘如暖阳采用国服佳肴六词条并保留瞬发")
	var gs := game()
	var p := gs.player(0)
	p.units[1].scCookTurn = gs.turn_counter
	p.cookingFeasts = 4
	p.avatarHp = 10
	var ingredient := Food.gain_ingredient(gs, 0, 1, "mountain")
	var other := Food.gain_ingredient(gs, 0, 1, "sea")
	play(gs, "c24908")
	var first: Dictionary = p.hand.back()
	check(valid_special_feast(first) and p.hand.has(ingredient) and p.hand.has(other) and cook_count(gs) == 0, "独立佳肴是三段三级效果，保留原食材")
	check(Food.feast_count(gs, 0) == 5 and p.avatarHp == 10 and p.units[0].attack == 2, "实际第五张佳肴还未触发六张奖励")

	p.units[2].hp = 0
	p.units[2].knockout = 2
	var body: Array = p.units.map(func(u): return [int(u.attack), int(u.maxHp)])
	var first_recipe: Dictionary = first.foodData.duplicate(true)
	play(gs, "c24908")
	var second: Dictionary = p.hand.back()
	check(valid_special_feast(second) and second.instanceId != first.instanceId and first.foodData == first_recipe, "各自真实佳肴实例保留各自已抽样的组合")
	check(Food.feast_count(gs, 0) == 6 and p.avatarHp == 20, "实际第六张佳肴先计数再为牌手恢复10点")
	for i in p.units.size():
		check(p.units[i].attack == body[i][0] + 5 and p.units[i].maxHp == body[i][1] + 5, "永久+5/+5覆盖全部初始式神 %d" % i)
	check(p.units[2].hp == 0 and p.units[2].knockout == 2, "六张佳肴奖励保留气绝状态")

	var target: Dictionary = p.units[0]
	var index: int = p.hand.find(second)
	var feast_card := gs.hand_card_def(0, index)
	var expected_attack: int = target.attack
	var expected_hp: int = target.maxHp
	var traits: Array = []
	for part in second.foodData.parts:
		expected_attack += int(part.get("attack", 0))
		expected_hp += int(part.get("hp", 0))
		if part.has("keyword"): traits.append(str(part.keyword))
	check(traits.all(func(keyword): return str(feast_card.text).contains(SPECIAL_TRAITS[keyword])) and gs.play_card(0, index, target.uid), "生成的中立佳肴显示抽样结果，可从手牌使用")
	check(int(target.attack) == expected_attack and int(target.maxHp) == expected_hp and traits.all(func(keyword):
		if keyword == "swift": return target.swift
		return gs.VerifiedRules.Combat.has(target, keyword)), "佳肴对实际目标结算抽到的数值与关键词")

	for count in [5, 6]:
		gs = game()
		p = gs.player(0)
		p.cookingFeasts = count
		p.avatarHp = 10
		var special_idx := give(gs, "c24908")
		for _i in range(int(gs.rules.maxHandSize) - 1): give(gs, "c24902")
		check(gs.play_card(0, special_idx) and cook_count(gs) == 1 and gs.rule_events.any(func(e): return e.kind == "food-burned"), "饴细工先烹饪填满手牌，直接生成的佳肴正常烧掉")
		check(Food.feast_count(gs, 0) == count and Food.hand_food_count(gs, 0, "feast") == 0 and p.avatarHp == (20 if count == 6 else 10), "烧牌不增加佳肴计数，已有六张仍结算奖励")

	gs = game()
	p = gs.player(0)
	p.units[1].scCookTurn = gs.turn_counter
	var saved_card := card.duplicate(true)
	saved_card.erase("cookingSpecialFeastKeywords")
	gs._push_card_frames(0, "c24908", null, saved_card, 1, 0)
	gs._resolve_resolution_stack()
	check(p.hand.size() == 1 and valid_special_feast(p.hand[0]), "旧存档中已排队的卡牌继续按当前牌定义生成")

	gs = game()
	p = gs.player(0)
	p.units[1].scCookTurn = gs.turn_counter
	var found: Dictionary = {}
	for _i in 32:
		p.hand.clear()
		p.energy = 40
		play(gs, "c24908")
		var sample: Dictionary = p.hand.back()
		check(valid_special_feast(sample), "多次真实结算的佳肴都符合三级三段")
		for part in sample.foodData.parts:
			if part.has("keyword"): found[part.keyword] = true
	check(SPECIAL_TRAITS.keys().all(func(keyword): return found.has(keyword)), "固定随机种子跑通全部六种佳肴词条")

func ai_and_metadata() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	for prefix in [246, 249]:
		for n in range(1, 9):
			var id := "c%d%02d" % [prefix, n]; var c: Dictionary = Content.card_def(id)
			check(c.get("sugarCatRules", false) and not c.effects.is_empty() and c.effects[0].action == "sc-card", "16cards use actualindependent executor " + id)
			check(ResourceLoader.exists("res://assets/official/cards/%s.png" % id), "actualoriginal PNG exists " + id)
			check(c.verifiedRules, "verified mainmechanism metadata " + id)
	var h := give(gs, "c24904"); check(SC.score_card(gs, 0, gs.hand_card_def(0, h), p.units[0].uid) < 0, "AI refuses ownunit damage")
	play(gs, "c24601"); check(AI._resolve_choice(gs, 0) and gs.pending_choice.is_empty(), "AI completes realingredient selection")
	play(gs, "c24606"); check(AI._resolve_choice(gs, 0) and gs.pending_choice.is_empty() and front(gs).has("scCatType"), "AI completes realcat selection")
	check(not SC.marks(gs, 0, p.units[0]).is_empty() and not SC.marks(gs, 0, p.units[1]).is_empty(), "nativeUI status includes summonhistory and onceperturn cooking")
	gs = game(); p = gs.player(0); p.cookingFeasts = 5
	give(gs, "c24908")
	check(AI.take_action(gs, 0) and Food.feast_count(gs, 0) == 6, "AI 真实打出甘如暖阳并获得第六张佳肴")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["maozhanggui", "yixigong", "bingyong", "shantong"], ["bingyong", "shantong", "bailang", "hetong"], 246249)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear(); p.energy = 40; p.levelUpUsed = true
			for u in p.units: u.level = 3
		root.add_child(b); await create_timer(0.4).timeout
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
		hand(b, ["c24601"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type", "") == "sc-ingredient" and faces(b._choice_layer).size() == 3, "mouse opens real3foodchoices %d" % physical.x)
		await capture("%d-01-food-choice" % physical.x)
		var tile := choice_face(b, "sc-food-mountain"); check(tile != null, "foodchoice has actualmountain tile")
		if tile != null: await click(tile)
		await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.any(func(i): return Food.food_kind(i) == "ingredient"), "mouse selectedfood really entershand")
		hand(b, ["c24606"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type", "") == "sc-cat" and faces(b._choice_layer).size() == 3 and texts(b._choice_layer).contains("召唤所选猫咪"), "mouse opens actualsummonchoice")
		await capture("%d-02-cat-choice" % physical.x)
		tile = choice_face(b, "sc-cat-four"); if tile != null: await click(tile)
		await settled(b)
		check(gs.pending_choice.is_empty() and front(gs).get("scCatType", "") == "four" and foe.avatarHp == 28, "mouse selectedfour enters with2avatardamage")
		hand(b, ["c24904"]); await settled(b); var energy: int = p.energy
		await click(b._hand_row.get_child(0)); check(b._pending_target_card == 0, "mouse enters actualfusionfiretargetmode")
		await click(b._enemy_plate)
		check(b._pending_target_card == 0 and p.energy == energy and not gs.valid_targets(0, b._pending_target_card_def).has("avatar-1"), "fusionfire UI rejectsavatars withoutpaying")
		await capture("%d-03-fusionfire-target" % physical.x)
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(p.energy == energy - 1 and foe.units[1].hp < foe.units[1].maxHp, "mouse selectedreserve receives actual spell damage")
		p.units[1].scCookTurn = gs.turn_counter
		hand(b, ["c24908"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.hand.size() == 1 and valid_special_feast(p.hand[0]), "鼠标打出甘如暖阳后手牌出现真实佳肴 %d" % physical.x)
		if p.hand.size() == 1 and Food.food_kind(p.hand[0]) == "feast":
			await click(b._hand_row.get_child(0)); await settled(b)
			check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).has(p.units[0].uid), "鼠标选佳肴后进入实际己方目标选择 %d" % physical.x)
			await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
			check(p.hand.is_empty() and used(gs, "feast").size() == 1, "鼠标选友方式神后佳肴消耗并结算 %d" % physical.x)
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty() and OS.get_cmdline_user_args()[0] != "--rules-only":
		out = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	cat_cards(); sugar_cards(); special_feast(); ai_and_metadata()
	if not OS.get_cmdline_user_args().has("--rules-only"): await ui_checks()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("SUGAR_CAT checks=%d failures=%d" % [checks, failures]); quit(0 if failures == 0 else 1)
