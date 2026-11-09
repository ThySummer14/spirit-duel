extends "res://scripts/verify_insight.gd"

const DRAGON_TEAM := ["longjue", "fengyangjun", "yaodaoji", "shantong"]

func _initialize() -> void:
	for code in [654,655]:
		for n in range(1,9):
			var gs := GS.create(DRAGON_TEAM, FOE, 654655)
			prepare(gs)
			var id := "c%d" % (code*100+n)
			var h := give(gs, id)
			var card := gs.hand_card_def(0,h)
			var target = gs.player(1).units[0].uid if card.target != "auto" else null
			check(card.get("verifiedRules",false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "牌文及原版牌图 "+id)
			check(gs.can_play_card(0,h,target).ok, "可正常使用 "+id)
			check(gs.play_card(0,h,target), "实际使用 "+id)
			if not gs.pending_choice.is_empty(): check(AI.take_action(gs,0), "AI处理 "+id)
	var gs := GS.create(DRAGON_TEAM, FOE, 654655)
	prepare(gs)
	var p := gs.player(0)
	var foe := gs.player(1)
	var dragon: Dictionary = p.units[0]
	var wind: Dictionary = p.units[1]
	var target: Dictionary = foe.units[0]
	var h := give(gs,"c65404")
	dragon.level = 0
	gs.raise_unit_level(0,0)
	check(dragon.dragonWet and not dragon.get("dragonDry",false), "首勾结附坤")
	check(gs.play_card(0,give(gs,"c65401")) and dragon.dragonDry and not dragon.get("dragonWet",false), "战斗牌切换乾")
	check(int(foe.avatarArmorBreak)>0 or int(foe.avatarHp)<30, "龙息伤害进入实际破甲系统")
	gs.VerifiedRules.DragonFlow.switch_breath(gs,0,0)
	gs._resolve_resolution_stack()
	h = p.hand.find_custom(func(inst): return inst.definitionId=="c65404")
	check("instant" in gs.hand_card_def(0,h).keywords and gs.hand_card_def(0,h).attackBonus == 1, "乾增长力量且坤赋瞬发")
	gs.raise_unit_level(0,0)
	check(gs.play_card(0,give(gs,"c65406")) and dragon.awakened and dragon.dragonCoexists and dragon.dragonDry and dragon.dragonWet, "觉醒两息共存")
	h = give(gs,"flow-switch")
	check(gs.play_card(0,h) and gs.pending_choice.instanceIds == ["c65501","c65502"], "易势选择两张真实流派牌")
	check(not gs.resolve_divination_choice(1,"c65501") and gs.resolve_divination_choice(0,"c65501"), "易势由持有方选择")
	check(wind.form.cardId == "flow-winter", "霁雪流真实换形")
	target.hp = 20
	gs._damage_unit(1,0,1,0,1)
	check(target.get("flowIce","") == wind.uid, "初次伤害附加冰冻")
	gs._damage_unit(1,0,1,0,1)
	check(int(target.frozen)>0 and not target.has("flowIce"), "再次伤害消耗冰冻并眩晕")
	gs._damage_unit(1,0,1,0,1)
	check(gs.play_card(0,give(gs,"c65502")) and wind.form.cardId == "flow-summer" and not target.has("flowIce"), "换离霁雪流清理冰冻")
	target.hp = 20
	var before := int(target.hp)
	gs._damage_unit(1,0,1,0,1)
	check(target.hp == before-2, "晴空流实际伤害+1")
	var recover := give(gs,"c65507")
	var iid := str(p.hand[recover].instanceId)
	check(gs.play_card(0,recover,target.uid) and p.hand.find_custom(func(i): return i.instanceId == iid)<0, "龙韬豹略实际离开手牌")
	check(gs.play_card(0,give(gs,"c65502")) and p.hand.find_custom(func(i): return i.instanceId == iid)>=0, "使用流派取回同一张龙韬豹略")
	gs = GS.create(DRAGON_TEAM, FOE, 654655)
	prepare(gs)
	dragon = gs.player(0).units[0]
	foe = gs.player(1)
	play(gs, "c65406")
	if dragon.dragonLast != "dragonWet": play(gs, "c65401")
	var summon := gs._make_unit(str(foe.id), "shantong")
	summon.summoned = true
	foe.units.append(summon)
	var summon_hp := int(summon.hp)
	play(gs, "c65401")
	check(int(summon.armorBreak) > 0 or int(summon.hp) < summon_hp, "觉醒的乾伤害覆盖准备区召唤物")
	front_role_boundaries()
	if failures == 0: print("COSMOS_DRAGONS_OK cases=",checks)
	quit(1 if failures else 0)

func front_role_boundaries() -> void:
	for ordinary in [false, true]:
		var gs := GS.create(DRAGON_TEAM, FOE, 654655)
		prepare(gs)
		var defender: Dictionary = gs.player(1).units[1]
		defender.summoned = ordinary
		defender.front = 1
		defender.level = 0
		defender.hp = 20
		defender.attack = 0
		play(gs, "c65405")
		check(int(defender.armorBreak) == (0 if ordinary else 2), "千江映月 only breaks armor on an actual front shikigami")
		for id in ["c65504", "c65507"]:
			var hand := give(gs, id)
			check(gs.can_play_card(0, hand, defender.uid).ok != ordinary, id + " accepts a zero-level shikigami and rejects a summon")
		defender.armorBreak = 0
		play(gs, "c65503")
		var hits := gs.rule_events.filter(func(e): return e.kind == "combat-damage-resolved" and e.get("card", {}).get("id") == "c65503" and e.get("target") == defender.uid)
		check(hits.size() == (1 if ordinary else 2), "封阳刀法 only gains combo when the actual opponent is a shikigami")
