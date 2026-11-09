extends "res://scripts/verify_insight.gd"

const TimeRules := preload("res://scripts/time_rewind_rules.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const PARTY := [TimeRules.ROLE, "bailang", "taohuayao", "shantong"]

func game() -> GS:
	var gs := GS.create(PARTY, FOE, 93108)
	prepare(gs)
	return gs

func catalog() -> void:
	var initial := GS.create(PARTY, FOE, 20)
	check(initial.player(0).hand.filter(func(inst): return inst.definitionId == TimeRules.INSCRIBE).size() == 1, "开局将一张铭刻置入手牌")
	for n in range(1, 9):
		var gs := game()
		var p := gs.player(0)
		var id := "w13-shiyao-longyechaji-9310%d" % n
		check(Content.card_def(id).get("verifiedRules", false), "主体牌有独立原版效果 " + id)
		if id == "w13-shiyao-longyechaji-93105":
			gs._knockout_unit(p.units[0])
			gs._resolve_resolution_stack()
		var idx := give(gs, id)
		check(gs.can_play_card(0, idx).ok, "原生卡可合法使用 " + id)
		var pick := AI._best_card(gs, 0)
		check(pick.ok and gs.can_play_card(0, pick.hand, pick.target, pick.origin).ok, "AI 提交合法操作 " + id)
		check(gs.play_card(0, idx), "主体牌经过真实手牌入口 " + id)
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, 0) and gs.pending_choice.is_empty(), "AI 合法完成命运抉择")

func rewind() -> void:
	var gs := game()
	var p := gs.player(0)
	var unit: Dictionary = p.units[0]
	play(gs, "w13-shiyao-longyechaji-93104")
	unit.hp = 2
	unit.shield = 3
	unit.armorBreak = 2
	unit.battlePower = 4
	var first := give(gs, "w13-shiyao-longyechaji-93101")
	var old: Dictionary = p.hand[first]
	old.rewindCheck = true
	give(gs, "w13-shiyao-longyechaji-93106")
	give(gs, "w13-shiyao-longyechaji-93106")
	give(gs, "c10101")
	play(gs, TimeRules.INSCRIBE)
	var rewind_instance: Dictionary = p.deck.front()
	check(rewind_instance.definitionId == TimeRules.REWIND and rewind_instance.timeRecord.unit.hp == 2, "铭刻在真实牌库底生成带快照的溯时")
	check(rewind_instance.timeRecord.played.is_empty(), "铭刻之前未使用的手牌不进入回取记录")
	gs.player(1).avatarHp = 60
	check(gs.play_card(0, 0), "铭刻后使用已记录标记的原卡")
	check(gs.play_card(0, 0), "铭刻后实际使用长守")
	check(gs.play_card(0, 0), "铭刻后实际使用长守")
	check(rewind_instance.timeRecord.played.size() == 2, "按真实使用记录同类异名牌，同名牌只记录一张")
	play(gs, "w13-shiyao-longyechaji-93107")
	unit.armorBreak = 0
	unit.battlePower = 0
	if p.deck.has(rewind_instance): gs._draw(0, 1, -1, {"bottomDraw": true})
	var idx := int(p.hand.find_custom(func(i): return i.instanceId == rewind_instance.instanceId))
	check(idx >= 0 and gs.play_card(0, idx), "真实牌库底抽出的溯时可以使用")
	check(unit.form.cardId == "w13-shiyao-longyechaji-93104" and unit.hp == 2 and unit.shield == 3 and unit.armorBreak == 2 and unit.battlePower == 4, "恢复牌图形态、生命、护甲、战力和破甲")
	check(p.hand.any(func(i): return i.instanceId == old.instanceId and i.rewindCheck) and p.hand.filter(func(i): return i.definitionId == "w13-shiyao-longyechaji-93106").size() == 1, "复原原实例并去除同名重复")
	check(p.hand.any(func(i): return i.definitionId == TimeRules.INSCRIBE) and p.hand.any(func(i): return i.definitionId == "c10101"), "复原生成铭刻并保留其他式神手牌")

func travel_and_attacks() -> void:
	var gs := game()
	var p := gs.player(0)
	var unit: Dictionary = p.units[0]
	var a := Insight.instance(gs, 0, "w13-shiyao-longyechaji-93101")
	var b := Insight.instance(gs, 0, "c10101")
	p.deck.assign([a, b])
	unit.hp = 1
	play(gs, "w13-shiyao-longyechaji-93102")
	check(unit.hp == unit.maxHp and unit.battlePower == 2 and unit.shield == 2 and p.hand.is_empty(), "时空之旅先恢复属性后等待抉择")
	check(gs.resolve_divination_choice(0, Fate.REVERSE) and p.hand[0] == a, "逆天换顶后真实抽到所选的底牌")

	gs = game()
	p = gs.player(0)
	play(gs, "w13-shiyao-longyechaji-93104")
	a = Insight.instance(gs, 0, "w13-shiyao-longyechaji-93102")
	b = Insight.instance(gs, 0, "c10101")
	p.deck.assign([a, b])
	check(gs.basic_attack(0, 0) and p.hand.any(func(i): return i.instanceId == a.instanceId), "时海曜月打中牌手抽牌库底")
	check(p.deck == [b], "未错误地抽牌库顶")
	TimeRules.avatar_hit(gs, 1, 0, 0, 1)
	gs._resolve_resolution_stack()
	check(p.deck == [b], "同一回合第二次伤害不再抽")
	var target_hp: int = gs.player(1).units[0].hp
	p.deck.push_front(a)
	play(gs, "w13-shiyao-longyechaji-93103")
	check(gs.player(1).units[0].hp == target_hp-1 and p.deck == [b], "揭示同名式神牌，群伤并从原位置抽指定实例")
	p.hand.clear()
	play(gs, "w13-shiyao-longyechaji-93103")
	check(gs.player(1).units[0].hp == target_hp-1 and p.deck == [b], "揭示其他式神的牌不会造成群伤或抽牌")
	gs = game()
	p = gs.player(0)
	unit = p.units[0]
	play(gs, "w13-shiyao-longyechaji-93107")
	var old_power: int = unit.attack
	var old_hp: int = unit.maxHp
	var enemy: Dictionary = gs.player(1).units[0]
	enemy.front = 1
	enemy.hp = 1
	var own_hp: int = unit.hp
	var fire: int = p.energy
	check(gs.basic_attack(0, 0) and unit.attack == old_power+1 and unit.maxHp == old_hp+1 and unit.hp >= own_hp and enemy.hp == 0, "永夜月虹攻击成长并先击杀避免反击")
	check(p.energy == fire and not p.attackUsed and not unit.swift and not gs.VerifiedRules.Combat.has(unit, "inspired"), "迅捷与昂扬各消费一次")
	check(gs.basic_attack(0, 0) and p.energy == fire-1 and p.attackUsed and not gs.can_basic_attack(0, 0).ok, "追加普通攻击正常耗火并占用出击次数")

func ai_empty_deck() -> void:
	var gs := game()
	var p := gs.player(0)
	p.deck.clear()
	var idx := give(gs, "w13-shiyao-longyechaji-93102")
	check(gs.can_play_card(0, idx).ok and not AI._best_card(gs, 0).ok, "牌库为空仍允许手动使用时空之旅，AI 避免强制抽牌而立即败北")
	p.deck.append(Insight.instance(gs, 0, "c10101"))
	check(AI._best_card(gs, 0).ok and AI.take_action(gs, 0) and p.hand.size() == 1 and p.hand[0].definitionId == "c10101", "有可抽实牌时 AI 正常使用时空之旅")

func eternal() -> void:
	var gs := game()
	var p := gs.player(0)
	var unit: Dictionary = p.units[0]
	var old := Insight.instance(gs, 0, "c10101")
	p.deck.assign([old])
	play(gs, "w13-shiyao-longyechaji-93108")
	check(unit.awakened and p.realms[0].hp == 10 and p.deck.size() == 42 and not p.deck.has(old), "月曜永恒部署幻境，觉醒并替换整副牌库")
	check(TimeRules.ORIGINAL_DECK.all(func(id): return p.deck.filter(func(i): return i.definitionId == id).size() == 6), "42张时曜牌库包含七种各六张")
	var card_index := give(gs, "w13-shiyao-longyechaji-93101")
	check("instant" in gs.hand_card_def(0, card_index).keywords, "幻境存在时牌得到实际瞬发")
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "专项验证")
	check("instant" not in gs.hand_card_def(0, card_index).keywords and unit.awakened, "失去幻境的瞬发并保留觉醒")
	var attack: int = unit.attack
	var hp: int = unit.maxHp
	var hand: int = p.hand.size()
	TimeRules.turn_start(gs, 0)
	gs._resolve_resolution_stack()
	check(unit.attack == attack+1 and unit.maxHp == hp+1 and p.hand.size() == hand+2, "觉醒在回合开始实际永久成长和抽专属牌")

func _initialize() -> void:
	catalog()
	rewind()
	travel_and_attacks()
	ai_empty_deck()
	eternal()
	print("TIME_REWIND checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
