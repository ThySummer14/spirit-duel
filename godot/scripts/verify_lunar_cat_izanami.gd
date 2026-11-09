extends "res://scripts/verify_insight.gd"

const OWN := ["yuedu", "wushi-maoshi", "yixienamei", "yaodaoji"]
const RIVALS := ["bingyong", "bailang", "shantong", "yaohu"]
const LUNAR := preload("res://scripts/lunar_trick_rules.gd")
const CAT := preload("res://scripts/cat_samurai_rules.gd")
const IZANAMI := preload("res://scripts/izanami_rules.gd")

func game() -> GS:
	var gs := GS.create(OWN, RIVALS, 625)
	prepare(gs)
	return gs

func hand_index(gs, owner: int, id: String) -> int:
	return gs.player(owner).hand.find_custom(func(inst): return inst.definitionId == id)

func lunar() -> void:
	var gs := game()
	var foe := gs.player(1)
	for id in ["c10301", "c11002", "c11301", "c13402"]: give(gs, id, 1)
	check(gs.basic_attack(0, 0) and gs.pending_choice.get("type") == "lunar-seize", "月读出击展示并暂停")
	check(gs.pending_choice.instanceIds.size() == 3 and gs.pending_choice.zoneOwner == 1 and foe.avatarHp == 30, "仅展示三张真实敌方手牌，攻击待结算")
	var chosen: String = gs.pending_choice.instanceIds[0]
	check(not gs.resolve_divination_choice(1, chosen) and not gs.resolve_divination_choice(0, "missing"), "拒绝错误玩家和未展示实例")
	check(gs.resolve_divination_choice(0, chosen) and Insight.zone(gs, 1).any(func(c): return c.instanceId == chosen) and LUNAR.false_index(gs, 1) >= 0, "移动同一实例并给虚假之月")
	check(foe.avatarHp == 28, "选择后恢复实际战斗")

	gs = game()
	foe = gs.player(1)
	play(gs, "c62204")
	give(gs, "c10301", 1)
	check(gs.basic_attack(0, 0) and AI.take_action(gs, 0), "AI 处理觉醒后展示")
	var shadow := gs.front_unit(0)
	check(shadow.get("id") == LUNAR.SHADOW and shadow.hp == Content.unit_def("bingyong").maxHp, "觉醒召虚影取被移走牌所属式神基础身材")
	var token := LUNAR.false_index(gs, 1)
	check(token >= 0 and "instant" not in gs.hand_card_def(1, token).keywords, "敌方虚假之月在觉醒时失去瞬发")
	play(gs, "c62205") # 留下一张作响应，先补回敌方触发条件。
	give(gs, LUNAR.FALSE_MOON, 1)
	give(gs, "c62205")
	turn(gs, 0)
	var c := give(gs, "c10301", 1)
	var foe_body: Dictionary = foe.units[0]
	var prior_hp: int = gs.player(0).avatarHp
	check(gs.play_card(1, c) and LUNAR.false_index(gs, 1) < 0 and gs.player(0).avatarHp == prior_hp, "虚诞月落丢敌方手牌并反制原牌")
	check(gs.rule_events.any(func(e): return e.kind == "card-nullified" and e.card.id == "c10301"), "记录原牌实际被反制")


	gs = game()
	give(gs, "c62205")
	turn(gs, 0)
	gs.VerifiedRules.Insight.enter(gs, 1)
	check(gs.play_card(1, 0, "avatar-0") and hand_index(gs, 0, "c62205") >= 0, "基础牌文的虚诞月落不响应中立牌")
	check(LUNAR.false_index(gs, 1) < 0 and gs.play_card(1, give(gs, "c10301", 1)), "没有虚假之月仍可触发针对敌方式神牌的响应")
	check(gs.rule_events.any(func(e): return e.kind == "card-nullified" and e.card.id == "c10301"), "弃牌找不到时，独立的反制结算仍生效")

	gs = game()
	foe = gs.player(1)
	foe_body = foe.units[0]
	gs._apply_form(1, 0, Content.card_def("c10302"), {"attack": 3, "hp": 5, "setBase": true})
	play(gs, "c62201", foe_body.uid)
	check(foe_body.form.is_empty() and Insight.zone(gs, 1).any(func(inst): return inst.definitionId == "c10302"), "谎言移动场上形态至启悟区")
	foe_body.hp = 9
	foe_body.front = 1
	play(gs, "c62202")
	check(foe_body.hp == 0, "空亡仅消灭实际受投射且启悟区有牌的式神")

	gs = game()
	foe = gs.player(1)
	foe_body = foe.units[0]
	foe_body.baseMaxHp = 9
	gs._recalc(foe_body)
	foe_body.frozen = 1
	foe_body.starBowlSerial = 1
	Insight.place(gs, 1, Insight.instance(gs, 1, "c10301"))
	foe_body.barrier = true
	play(gs, "c62202")
	check(foe_body.hp == 9 and not foe_body.barrier and foe.avatarHp == 30, "空亡转到有屏障的式神时未造成伤害，不消灭")
	play(gs, "c62202")
	check(foe_body.hp == 0 and foe.avatarHp == 30, "空亡原本投射牌手但发生转伤，消灭实际受伤且有启悟牌的式神")

	gs = game()
	foe = gs.player(1)
	play(gs, "c62203")
	turn(gs, 0)
	Insight.enter(gs, 1)
	check(not gs.can_play_card(1, 0, "avatar-0").ok, "月烬天极阻止敌方启悟区中立牌")
	Insight.place(gs, 1, Insight.instance(gs, 1, "c10301"))
	var own_cards: int = gs.player(0).hand.size()
	check(gs.play_card(1, 3) and gs.player(0).hand.size() == own_cards + 1, "敌方式神用启悟牌时实际抽牌")
	Insight.enter(gs, 1)
	Insight.place(gs, 1, Insight.instance(gs, 1, "c10301"))
	check(gs.play_card(1, 3) and gs.player(0).hand.size() == own_cards + 1, "同一回合只抽一张")

	gs = game()
	foe = gs.player(1)
	give(gs, "c10301", 1)
	give(gs, "c11002", 1)
	play(gs, "c62206", foe.units[0].uid)
	check(gs.pending_choice.instanceIds.size() == 1 and AI.take_action(gs, 0) and foe.units[0].frozen > 0 and hand_index(gs, 1, "c11002") >= 0, "月烬宵宴只展示选中式神的手牌，移动后眩晕所属式神")
	var before: int = foe.units[1].hp
	play(gs, "c62207", foe.units[1].uid)
	check(foe.units[1].hp == before and AI.take_action(gs, 0) and foe.units[1].hp == before-2, "惑星选择后才对敌方式神造成伤害")
	play(gs, "c62208")
	check(foe.realms.is_empty() and gs.player(0).realms[0].maxHp == 5, "无光月海实装五耐久")
	gs.player(0).avatarHp = 20
	turn(gs, 0)
	var fake := LUNAR.false_index(gs, 1)
	check(fake >= 0 and gs.play_card(1, fake) and foe.avatarHp == 26 and gs.player(0).avatarHp == 24 and Insight.active(gs, 1), "无光月海把虚假之月伤害和治疗改为四，并保留启悟")

func cat() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = p.units[1]
	check(not gs.can_play_card(0, give(gs, CAT.MEDITATE)).ok, "默想活着不可用")
	play(gs, "c62401")
	check(zone_index(gs, CAT.HEART) >= 0 and foe.avatarHp == 26, "初心战斗并生成武士之心")
	play(gs, "c62405")
	check(zone_index(gs, CAT.GRUDGE) >= 0 and u.shield > 0, "生灵斩生成怨灵斩并按存活敌方获得护甲")
	play(gs, "c62406")
	check(zone_index(gs, CAT.SEVER) >= 0, "诛心生成真实灭魂实例")
	play(gs, "c62403")
	gs._deploy_realm(1, Content.card_def("c60808"))
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()
	check(u.hp == 0 and gs.VerifiedRules.Samurai.power(u) == 3 and not gs.can_basic_attack(0, 1).ok, "武魂3力且不能普通出击")
	check(not gs.can_play_card(0, give(gs, "c62401")).ok, "武魂拒绝从手牌用初心")
	check(gs.play_card(0, hand_index(gs, 0, CAT.MEDITATE)) and Insight.active(gs, 0), "武魂可瞬发默想启悟")
	var h := zone_index(gs, CAT.HEART)
	check(gs.play_card(0, h) and foe.realms.is_empty() and u.hp == 0 and u.front == 0, "武魂能用启悟区战斗牌，打脸后五条渡口消灭幻境")

	gs = game()
	p = gs.player(0)
	u = p.units[1]
	play(gs, "c62404")
	var next: Dictionary = p.deck.back()
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()
	check(u.awakened and Insight.zone(gs, 0).has(next), "武士之魂觉醒后实际抽牌进启悟区")
	play(gs, "c62407")
	check(gs.pending_choice.instanceIds == [CAT.REVIVE] and AI.take_action(gs, 0) and u.hp > 0 and u.swift and u.inspired, "忠义无双复活分支，迅捷和昂扬")
	turn(gs, 0)
	check(hand_index(gs, 0, "c62407") >= 0, "忠义无双返回原手牌")
	turn(gs, 1)
	var old: int = u.attack
	check(gs.play_card(0, hand_index(gs, 0, "c62407")) and gs.resolve_divination_choice(0, CAT.SACRIFICE) and u.hp == 0 and u.attack == old + 2 and Insight.active(gs, 0), "忠义无双气绝启悟并永久加力")
	Insight.leave_action(gs, 0)
	p.deck.append(Insight.instance(gs, 0, CAT.MUSASHI))
	var hand_size: int = p.hand.size()
	gs._draw(0, 1)
	gs._resolve_resolution_stack()
	check(zone_index(gs, CAT.MUSASHI) >= 0 and p.hand.size() == hand_size+1, "武藏抽到即入启悟区并补抽")

	gs = game()
	p = gs.player(0)
	u = p.units[1]
	var substitute := Content.card_def("c25707")
	gs._install_form(0, 1, substitute, {"attack": 2, "hp": 5, "setBase": true})
	play(gs, "c62407")
	check(gs.resolve_divination_choice(0, CAT.SACRIFICE) and u.hp > 0 and int(u.get("permanentAttack", 0)) == 0 and not Insight.active(gs, 0), "忠义无双气绝被替身替代后不启悟也不获得永久力量")
	var ally: Dictionary = p.units[0]
	gs._knockout_unit(ally)
	ally.knockout = 0
	var grudge := give(gs, CAT.GRUDGE)
	check(int(gs.hand_card_def(0, grudge).value) == int(Content.card_def(CAT.GRUDGE).value) + 1, "怨灵斩仍计入倒计时已归零的气绝式神")


	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	u = p.units[1]
	gs._knockout_unit(u)
	p.units[0].front = 1
	foe.units[0].front = 1
	foe.units[0].formRules = {"lockEnemyFrontReplacement": true}
	foe.units[0].hp = 9
	put(gs, CAT.HEART)
	put(gs, CAT.MUSASHI)
	Insight.enter(gs, 0)
	check(gs.play_card(0, zone_index(gs, CAT.HEART)) and foe.units[0].hp < 9 and foe.avatarHp == 30 and p.units[0].front == 1, "武魂不换前排也不自带直击，普通战斗仍打到敌前排")
	Insight.enter(gs, 0)
	check(gs.play_card(0, zone_index(gs, CAT.MUSASHI)) and foe.avatarHp == 24 and p.units[0].front == 1, "武藏直击越过敌方战斗区，同时不替换己方前排")

	gs = game()
	p = gs.player(0)
	var solar_musashi := Insight.instance(gs, 0, CAT.MUSASHI)
	var other := Insight.instance(gs, 0, "c62401")
	p.deck.assign([other, solar_musashi])
	gs.VerifiedRules.Solar.draw(gs, 0, 1)
	gs._resolve_resolution_stack()
	check(Insight.zone(gs, 0).has(solar_musashi) and int(solar_musashi.get("sunlight", 0)) == 1 and p.hand.has(other), "天照实际抽到武藏时先入区结附，再补抽到手")

func izanami() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = p.units[2]
	var ally: Dictionary = p.units[0]
	var target: Dictionary = foe.units[0]
	play(gs, "c62502", ally.uid)
	check(ally.unyielding and p.realms[0].hp == 4, "虚无之海选择式神并给不屈")
	target.front = 1
	play(gs, "c62503")
	var snake := gs.front_unit(0)
	check(snake.get("id") == IZANAMI.SNAKE and snake.hp == 1 and snake.swift and snake.inspired and p.realms[0].hp == 2, "创造召唤2/1蛇群；敌前排有式神则迅捷昂扬，触发虚无之海")
	check(u.battleSkillId == "c62503" and gs.basic_attack(0, 2) and gs.front_unit(0).get("id") == IZANAMI.SNAKE and p.realms[0].hp == 2, "战技普通出击改为再次召唤，每回合幻境只触发一次")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	target = foe.units[0]
	play(gs, "c62504")
	check(p.units[2].awakened and foe.avatarHp == 29, "觉醒召蛇并同时伤害敌方牌手")
	play(gs, "c62505")
	check(foe.units.any(func(rival): return rival.hp == 1) and p.units.any(func(own): return not own.get("summoned", false) and own.hp == 1), "毁灭女神双方各取最大力量")
	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	target = foe.units[0]
	play(gs, "c62501")
	target.hp = 8
	target.front = 1
	gs.basic_attack(0, 3)
	check(target.hp == 1, "灭世之舞由己方实际攻击伤害设置生命为一")
	var blue: Dictionary = foe.units[1]
	blue.factionOverride = "青岚"
	blue.hp = 8
	play(gs, "c62506", blue.uid)
	check(blue.hp <= 5 and gs.front_unit(0).get("id") == IZANAMI.SNAKE, "破坏造成原版3伤并只在青岚分支召蛇")
	var summons: int = p.units.filter(func(own): return own.id == IZANAMI.SNAKE).size()
	var alive: int = IZANAMI.living(gs, 1).size()
	play(gs, "c62507")
	check(p.units.filter(func(own): return own.id == IZANAMI.SNAKE).size() == summons+alive and gs.rule_events.any(func(entry): return entry.kind == "combat-hit" and "izanami-snakes" in str(entry.uid)), "采撷逐个生成蛇群并实际战斗")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	play(gs, "c62508")
	snake = gs.front_unit(0)
	var idx := gs.front_index(0)
	check(gs.VerifiedRules.HairPower.amount(snake) == 4, "神赐之吻给真实战力")
	var hit := gs._damage_unit(0, idx, 4, 1)
	check(hit.damage == 0 and snake.hp == 1, "一血式神免非战斗伤害")
	foe.units[0].front = 1
	foe.units[0].hp = 3
	gs.basic_attack(0, idx)
	check(snake.hp == 1 and foe.avatarHp < 30, "一血式神攻击有贯通并免反击")

	gs = GS.create(OWN, ["xixueji-xiyi", "bailang", "shantong", "yaohu"], 625)
	prepare(gs)
	foe = gs.player(1)
	var blood: Dictionary = foe.units[0]
	gs.current_player = 1
	check(gs.play_card(1, give(gs, "c66307", 1)), "敌方真实结付共享生命的二重禁忌")
	blood.barrier = true
	blood.attack = 20
	gs.current_player = 0
	play(gs, "c62505")
	check(blood.hp == 1 and foe.avatarHp == 1, "毁灭女神令共享生命的式神与牌手一起变为1")

	gs = GS.create(OWN, ["yinghuayao-lijing", "bailang", "shantong", "yaohu"], 625)
	prepare(gs)
	foe = gs.player(1)
	var cherry: Dictionary = foe.units[0]
	cherry.factionOverride = "青岚"
	cherry.front = 1
	cherry.hp = 3
	play(gs, "c62506", cherry.uid)
	var summons_after: Array = gs.rule_events.filter(func(entry): return entry.kind == "summon-created")
	check(cherry.hp == 0 and summons_after.map(func(entry): return entry.summonKind) == ["hf-glass-cherry", IZANAMI.SNAKE], "破坏先完整结算青岚目标受伤引发的遗愿，再召唤蛇群")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(OWN, RIVALS, 625)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, ["c10301", "c11002"], 1)
		hand(b, ["c62207"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		var rival: Dictionary = gs.player(1).units[0]
		await click(b._unit_widget(str(rival.uid)))
		await settled(b)
		var tile := choice_face(b, "c10301")
		check(tile != null and choice_face(b, "c11002") == null, "惑星鼠标选择仅显示所选式神手牌")
		if tile != null: await click(tile)
		await settled(b)
		check(hand_index(gs, 1, "c10301") < 0 and rival.hp == rival.maxHp-2, "鼠标选牌后实际移入启悟并造成伤害")
		var cat_body: Dictionary = gs.player(0).units[1]
		gs._knockout_unit(cat_body)
		gs._resolve_resolution_stack()
		hand(b, ["c62407"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		tile = choice_face(b, CAT.REVIVE)
		check(tile != null, "忠义无双展示武魂可用选项")
		if tile != null: await click(tile)
		await settled(b)
		check(cat_body.hp > 0 and cat_body.inspired, "忠义无双通过真实鼠标完成复活")
		hand(b, ["c62502"])
		rival.level = 0
		await settled(b)
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(rival.uid)))
		await settled(b)
		check(rival.unyielding and gs.player(0).realms.any(func(realm): return realm.cardId == "c62502"), "鼠标可使0勾敌方式神获得虚无之海的不屈")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	lunar()
	cat()
	izanami()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("LUNAR_CAT_IZANAMI checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
