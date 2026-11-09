extends "res://scripts/verify_insight.gd"

const ZEN_TEAM := ["chanxinyunwaijing","pinfashen","yaodaoji","shantong"]
const FOOD_TEAM := ["maozhanggui-huanyan","jintianyuzaoqian","yaodaoji","shantong"]
const UI_TEAM := ["fengyangjun","maozhanggui-huanyan","pinfashen","shantong"]

func fixture(team: Array) -> GS:
	var gs := GS.create(team, FOE, 656658)
	prepare(gs)
	gs.turn_counter = 13
	var deck: Array = gs.player(0).deck
	deck.clear()
	for _i in 12: deck.append(Insight.instance(gs,0,"c10301"))
	for side in gs.players:
		for u in side.units: u.front = 0
	return gs

func catalog() -> void:
	for role in [656,657,658,660]:
		for i in range(1,9):
			var gs := fixture(ZEN_TEAM if role in [656,657] else FOOD_TEAM)
			var id := "c%d" % (role*100+i)
			var idx := give(gs, id)
			if id == "c65808": gs._deploy_realm(0,Content.card_def("blueprint-remodel-1"))
			var card := gs.hand_card_def(0,idx)
			check(card.get("verifiedRules",false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "真实牌面 "+id)
			var targets := [null] if card.target == "auto" else gs.valid_targets(0, card)
			check(not targets.is_empty(), "存在合法目标 "+id)
			if targets.is_empty(): continue
			var legal := gs.can_play_card(0,idx,targets[0])
			check(legal.ok, "标准合法使用 "+id+" "+str(legal.get("reason","")))
			check(gs.play_card(0,idx,targets[0]), "使用原实例 "+id)
			if not gs.pending_choice.is_empty(): check(AI.take_action(gs,0) and gs.pending_choice.is_empty(), "AI 完成选择 "+id)

func mirror_and_fate() -> void:
	var gs := fixture(ZEN_TEAM)
	var p := gs.player(0)
	var foe := gs.player(1)
	var zen: Dictionary = p.units[0]
	var poor: Dictionary = p.units[1]
	var link := Insight.instance(gs,0,"c65603")
	p.deck.append(link)
	var i := give(gs,"c65602")
	var iid := str(p.hand[i].instanceId)
	check(gs.play_card(0,i,zen.uid) and gs.pending_choice.type=="native-link" and link.instanceId in gs.pending_choice.instanceIds, "连引实物在牌库时展示双方选择")
	check(not gs.resolve_divination_choice(1,iid) and gs.resolve_divination_choice(0,iid) and gs.play_card(0,i,zen.uid), "保留原手牌实物使用")
	check(zen.get("cosmosBlessing",false) and zen.temporaryAttack == 1 and p.deck.any(func(inst): return inst.get("zenOrigin",false)), "连引无垢无净同时结算阴阳并洗起源")
	p.deck = p.deck.filter(func(c): return not c.get("zenOrigin",false) and not str(c.definitionId).begins_with("c656"))
	play(gs,"c65607")
	var initial_hp := int(zen.hp)
	var initial_max := int(zen.maxHp)
	gs._damage_unit(0,0,5,1,0)
	check(zen.hp == initial_hp+1 and zen.maxHp == initial_max+1 and not zen.has("cosmosBlessing"), "庇佑抵挡法术且神镜永久成长")
	play(gs,"c65604")
	check(zen.get("barrier",false), "心净明真实屏障")
	var formed_max := int(zen.maxHp)
	gs._damage_unit(0,0,5,1,0,true)
	check(not zen.get("barrier",false) and int(zen.maxHp)==formed_max+1, "屏障战伤消耗")
	play(gs,"c65706")
	foe.units[0].front = 1
	var dest := str(foe.units[0].uid)
	var a := int(poor.attack)
	check(gs.basic_attack(0,1), "贫乏发动正常出击")
	check(int(gs.kw_usage(0,"fortune").last.firstRoll)==1 and int(poor.get("misfortune",0))==2 and int(poor.attack)>=a+2, "穷神附体骰面及双方不幸触发")
	check(gs.rule_events.any(func(e): return e.kind=="cosmos-wrong-target" and e.target!=dest), "运势失败替换实际攻击目标")
	var energy := int(p.energy)
	var hand := give(gs,"c65701")
	check(gs.can_play_card(0,hand,null,"misfortune-draw").ok and gs.play_card(0,hand,null,"misfortune-draw"), "都听我号令独立瞬发分支")
	check(p.energy==energy and int(poor.get("misfortune",0))>=3, "瞬发分支无鬼火并追加不幸")

	gs = fixture(ZEN_TEAM)
	p = gs.player(0)
	zen = p.units[0]
	zen.cannotAttack = true
	zen.shield = 0
	play(gs, "c65707")
	check(gs.rule_events.any(func(e): return e.kind == "cosmos-misfortune" and e.uid == zen.uid), "禁止出击的同伴仍被贫乏神结附不幸")
	check(zen.shield == 0 and gs.VerifiedRules.HairPower.amount(zen) == 0, "无法发起攻击的同伴不会凭空取得本次攻击加成")

func blueprints_and_tails() -> void:
	var gs := fixture(FOOD_TEAM)
	var p := gs.player(0)
	var cat: Dictionary = p.units[0]
	var fox: Dictionary = p.units[1]
	var board := Content.card_def("blueprint-remodel-1")
	gs._deploy_realm(0,board)
	var installed: Dictionary = p.realms.back()
	check(int(installed.hp)==3, "店面焕新真实耐久")
	play(gs,"c65808",installed.uid)
	check(int(installed.hp)==3 and p.realms.has(installed) and gs.VerifiedRules.HairPower.guard_count(gs,0)>0, "临时加班只触发蓝图效果")
	gs.VerifiedRules.Huang.gain(gs,0,installed,3)
	check(not p.realms.has(installed) and int(p.blueprintCompleted)==1, "自然蓝图完成离场并记录")
	var h := give(gs,"c65804")
	check(gs.hand_card_def(0,h).value==5, "己方幻境实际离场增强")
	var wounded: Dictionary = gs.player(1).units[0]
	wounded.hp = 2
	check(gs.play_card(0,h,wounded.uid) and wounded.hp==0, "猫合战扣当前生命及上限并真实气绝")
	play(gs,"c65806")
	check(cat.awakened and not p.realms.is_empty(), "蓝图愿景觉醒且召唤独立蓝图")
	play(gs,"c65802")
	check(gs.pending_choice.instanceIds.size()==5 and gs.resolve_divination_choice(0,"blueprint-server-3"), "猫侍应五张真实派生选择")
	play(gs,"c65802")
	check(not "blueprint-server-3" in gs.pending_choice.instanceIds and AI.take_action(gs,0), "同一猫侍应一局不能重复")

	fox.level=0
	gs.raise_unit_level(0,1)
	check(int(fox.nineTails)==1 and fox.attack==3, "实际升级增加首尾")
	gs._knockout_unit(fox)
	gs.raise_unit_level(0,1)
	check(int(fox.ninePending)==1 and int(fox.nineTails)==1, "气绝时升级仅排队")
	check(gs.VerifiedRules.Peach.revive(gs,0,-1,fox,false,false) and int(fox.nineTails)==2, "复活兑现待处理层")
	gs.raise_unit_level(0,1)
	var focus := give(gs,"c66003")
	check("instant" in gs.hand_card_def(0,focus).keywords, "三尾令专注法术获得瞬发")
	for _n in 4: gs.VerifiedRules.NineTails.gain(gs,0,1)
	var hp := int(fox.hp)
	gs.kw_usage(0,"instant").count = 0
	var old_energy := int(p.energy)
	var target: Dictionary = gs.player(1).units[1]
	check(gs.can_play_card(0,focus,target.uid).ok and gs.play_card(0,focus,target.uid) and int(fox.hp)==hp-2 and int(p.energy)==old_energy, "七尾实付生命而非额外鬼火")
	play(gs,"c66006")
	var events_before := gs.rule_events.size()
	play(gs,"c66005")
	check(gs.rule_events.slice(events_before).any(func(e): return e.kind=="automatic-card" and str(e.get("card",{}).get("id","")).begins_with("c221")), "觉醒后结附随机实际使用起源法术")

func blueprint_feasts() -> void:
	var gs := fixture(FOOD_TEAM)
	var cooking = gs.VerifiedRules.Cooking
	var p := gs.player(0)
	var older: Dictionary = cooking.gain_feast(gs, 0, 0, [{"hp": 1}])
	var ingredient: Dictionary = cooking.gain_ingredient(gs, 0, 0, "mountain")
	play(gs, "c65805")
	var meal: Dictionary = p.realms.back()
	var entering: Dictionary = p.units[2]
	check(gs.basic_attack(0, 2), "膳食精进下正常发起出击")
	check(p.hand.has(ingredient) and gs.rule_events.any(func(e): return e.kind == "food-used" and e.targetUid == entering.uid and not e.fromHand), "入战斗区自动使用随机食材并保留原有手牌食材")
	gs.VerifiedRules.Huang.gain(gs, 0, meal, 4)
	check(cooking.feast_count(gs, 0) == 1 and p.realms.has(meal), "膳食精进未达10耐久不发佳肴")
	gs.VerifiedRules.Huang.gain(gs, 0, meal, 1)
	gs._resolve_resolution_stack()
	var generated: Dictionary = p.hand.back()
	check(not p.realms.has(meal) and cooking.feast_count(gs, 0) == 2 and p.hand.has(ingredient), "蓝图自然完成直接获得佳肴且保留食材")
	check(generated.get("foodData", {}).get("parts", []).size() == 3, "蓝图生成可使用的三段普通佳肴")
	check("instant" in gs.hand_card_def(0, p.hand.find(older)).keywords and "instant" in gs.hand_card_def(0, p.hand.find(generated)).keywords, "原有和新获得的手牌佳肴都取得瞬发")
	check("instant" not in gs.hand_card_def(0, p.hand.find(ingredient)).keywords, "瞬发不影响当时手牌食材")
	var later: Dictionary = cooking.gain_feast(gs, 0, 0, [{"attack": 1}])
	check("instant" not in gs.hand_card_def(0, p.hand.find(later)).keywords, "蓝图完成后获得的佳肴不继承瞬发")

	gs = fixture(FOOD_TEAM)
	p = gs.player(0)
	p.realms.clear()
	play(gs, "c65807")
	var festival: Dictionary = p.realms.back()
	var ally: Dictionary = p.units[1]
	gs._knockout_unit(ally)
	var overtime := give(gs, "c65808")
	check(not gs.can_play_card(0, overtime, ally.uid).ok, "临时加班拒绝式神作为目标")
	check(AI.take_action(gs, 0) and not p.hand.any(func(i): return i.definitionId == "c65808"), "AI 通过合法蓝图目标使用临时加班")
	var meals := gs.rule_events.filter(func(e): return e.kind == "food-used" and cooking.food_kind(e.card) == "feast")
	check(ally.hp > 0 and meals.size() == p.units.size(), "新生祭典先复活，再逐位使用佳肴")
	check(meals.any(func(e): return e.targetUid == ally.uid), "刚复活的式神也实际使用佳肴")
	if not meals.is_empty():
		var recipe: Array = meals[0].card.foodData.parts
		check(recipe.size() == 3 and meals.all(func(e): return e.automatic and not e.fromHand and e.card.foodData.parts == recipe), "祭典以同一道随机佳肴触发所有式神的用牌事件")
	check(p.realms.has(festival) and int(festival.hp) == 4 and int(p.get("blueprintCompleted", 0)) == 0, "临时加班保留祭典的耐久和自然完成历史")

func character_scopes_and_healing() -> void:
	var gs := fixture(["chanxinyunwaijing", "fengyangjun", "longjue", "jintianyuzaoqian"])
	var p := gs.player(0)
	var foe := gs.player(1)
	var summon := gs._make_unit(str(foe.id), "shantong")
	summon.summoned = true
	foe.units.append(summon)
	foe.units[0].front = 1
	var summon_hp := int(summon.hp)
	p.maxAvatarHp = 35
	p.avatarHp = 34
	p.avatarArmor = 0
	play(gs, "c65601", "avatar-0")
	check(p.avatarHp == 35 and p.avatarArmor == 1, "和合的溢疗护甲以牌手当前生命上限计算")
	play(gs, "c65606")
	check(summon.hp == summon_hp, "全体敌方式神的伤害排除普通召唤物")
	play(gs, "c65508")
	check(summon.hp == summon_hp - 1, "封阳君的全体敌方角色伤害包括召唤物")
	check(summon.uid in gs.VerifiedRules.DragonFlow.random_enemy(gs, 0, true), "龙珏与烬天玉藻前的随机角色池接受普通召唤物")
	for u in foe.units:
		if u.uid != summon.uid: gs._knockout_unit(u)
	var fox: Dictionary = p.units[3]
	fox.nineTails = 6
	play(gs, "c66007")
	check(summon.hp < summon_hp - 1, "烬天玉藻前的随机伤害实际打到召唤物")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280,800), Vector2i(1600,740)]:
		root.size = viewport
		var b := Battle.new()
		b.setup(UI_TEAM,FOE, 658654)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b,["flow-switch"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var stance := choice_face(b,"c65501")
		check(stance!=null,"鼠标可见易势霁雪流 "+str(viewport))
		if stance!=null: await click(stance)
		await settled(b)
		check(gs.player(0).units[0].form.get("cardId","")=="flow-winter","鼠标点选流派后实际形态 "+str(viewport))
		hand(b,["c65802"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var servant := choice_face(b,"blueprint-server-4")
		check(servant!=null,"鼠标可见猫侍应四饼 "+str(viewport))
		if servant!=null: await click(servant)
		await settled(b)
		check(gs.player(0).hand.any(func(i): return i.definitionId=="blueprint-server-4"),"鼠标点选后真实获得派生 "+str(viewport))
		hand(b, ["c65805"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var base_face: Control
		for face in faces(b._origin_choice_layer):
			if face.get_meta("origin_option", true) == false: base_face = face
		check(base_face != null, "鼠标可选膳食精进幻境本体 " + str(viewport))
		if base_face == null:
			b.queue_free()
			await process_frame
			continue
		await click(base_face)
		await settled(b)
		var meal: Dictionary = gs.player(0).realms.back()
		hand(b, ["c65808"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var chip := b._ally_realms.get_children().filter(func(n): return n.get_meta("realm_uid") == meal.uid)[0] as Control
		await click(chip.get_child(chip.get_child_count() - 1))
		await settled(b)
		check(gs.player(0).hand.size() == 1 and gs.hand_card_def(0, 0).id == "jia-yao" and "instant" in gs.hand_card_def(0, 0).keywords, "鼠标选择膳食精进蓝图后获得瞬发佳肴 " + str(viewport))
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	catalog()
	mirror_and_fate()
	blueprints_and_tails()
	blueprint_feasts()
	character_scopes_and_healing()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("COSMOS_NATIVE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
