extends "res://scripts/verify_insight.gd"

const ABYSS := preload("res://scripts/dragon_abyss_rules.gd")
const PARTY := ["yatiangou-qiuye", "shuweng-zhixing", "huojinshen", "sibing", "dayueling-yuxin", "chili"]
const ENEMIES := ["bingyong", "fenghuanghuo", "yaohu", "xuenv"]

func ready(role: int) -> GS:
	var units: Array = [PARTY[role-642], "yingcao", "bailang", "yaodaoji"]
	var gs := GS.create(units, ENEMIES, 6420647)
	prepare(gs)
	return gs

func complete(gs) -> void:
	for i in 20:
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, int(gs.pending_choice.playerIndex)), "AI completes %s" % gs.pending_choice.get("type", "choice"))
		elif not gs.response_window.is_empty():
			check(gs.pass_response(int(gs.response_window.playerIndex)), "response passes")
		else:
			return
	check(false, "stack does not stall")

func catalog() -> void:
	for role in range(642, 648):
		for n in range(1,9):
			var id := "c%d" % (role*100+n)
			var gs := ready(role)
			var own: Dictionary = gs.player(0).units[0]
			var enemy: Dictionary = gs.player(1).units[0]
			if id == "c64208": ABYSS.Aki.give(gs, 0, own, "water")
			if id == "c64406":
				gs._knockout_unit(gs.player(0).units[1])
				gs._resolve_resolution_stack()
			if id == "c64603":
				ABYSS.Jade.give(gs, 0, 1, enemy)
				gs._resolve_resolution_stack()
			if id in ["c64701","c64702","c64705","c64706","c64708"]: give(gs, "c64703")
			var h := give(gs, id)
			var card := gs.hand_card_def(0, h)
			var targets: Array = [null] if card.target == "auto" else gs.valid_targets(0, card)
			check(Content.card_def(id).get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "牌面 " + id)
			check(not targets.is_empty(), "合法目标 " + id)
			if targets.is_empty(): continue
			var candidate := AI._best_card(gs, 0)
			check(candidate.ok and gs.can_play_card(0, candidate.hand, candidate.target, candidate.origin).ok, "AI合法选牌 " + id)
			var target = targets[0]
			if id == "c64505": target = enemy.uid
			var legal := gs.can_play_card(0, h, target)
			check(legal.ok, "实际用牌 %s %s" % [id, legal.get("reason", "")])
			if legal.ok:
				check(gs.play_card(0, h, target), "结算 " + id)
				complete(gs)

func akiba() -> void:
	var gs := ready(642)
	var u: Dictionary = gs.player(0).units[0]
	check(gs.player(0).get("turnsTaken", 0) == 1 and not gs.player(0).get("akibaExtra", false), "首回合")
	var h := give(gs, ABYSS.Aki.PRACTICE)
	check(gs.play_card(0, h) and not gs.resolve_divination_choice(1, "sword"), "神通只接受己方有效选择")
	check(gs.resolve_divination_choice(0, "sword") and ABYSS.Aki.charms(u) == ["sword"], "剑神通真实附着")
	check("instant" in gs.hand_card_def(0, give(gs, "c64202")).keywords, "剑神通使火伏瞬发")
	play(gs, "c64206")
	var fox := gs.front_unit(0)
	check(fox.get("id") == "akiba-fox" and fox.hp == 2 and ABYSS.Aki.charms(fox) == ["sword"], "白狐继承神通")
	check(gs.player(1).avatarHp < 27, "剑神通投射和战斗先后实际生效")
	gs = ready(642)
	var rival: Dictionary = gs.player(1).units[0]
	rival.movementVeil = true
	h = give(gs, "c64201")
	check(not gs.can_play_card(0, h, rival.uid).ok, "驭风不能选中移动能力施加帷幕的敌方式神")
	rival.movementVeil = false
	check(gs.play_card(0, h, rival.uid) and int(rival.front) == 1, "帷幕解除后，驭风通过出牌入口移动准备区目标")

func travel() -> void:
	var gs := ready(643)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	ABYSS.Travel.gain(gs, 0, 2)
	var h := give(gs, "c64301")
	var inst: Dictionary = p.hand[h]
	check(gs.play_card(0, h, p.units[1].uid) and p.hand.any(func(c): return c.instanceId == inst.instanceId and c.get("abyssReflectionUsed", false)), "两张游记使遐征取专属牌并原实例弹回")
	var foe: Dictionary = gs.player(1).units[0]
	var summon := gs._make_unit("mist-special", "fenghuanghuo")
	summon.summoned = true
	summon.countsAsShikigami = false
	gs.player(1).units.append(summon)
	var attack: int = foe.attack
	var max_hp: int = foe.maxHp
	var summon_attack := int(summon.attack)
	var summon_hp := int(summon.maxHp)
	play(gs, "c64305")
	check(foe.attack == attack-1 and foe.maxHp == max_hp-1, "夙雾盘岭静态力量和生命")
	check(summon.attack == summon_attack and summon.maxHp == summon_hp, "夙雾盘岭不改变非式神召唤物的身材")
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "专项")
	check(foe.attack == attack and foe.maxHp == max_hp, "离场撤销持续影响")
	ABYSS.Travel.gain(gs, 0, 2)
	play(gs, "c64306")
	check(u.awakened and ABYSS.Travel.turn_draw(gs, 0) and gs.pending_choice.instanceIds.size() == 3, "觉醒抽牌改为看顶三选一")
	check(AI.take_action(gs, 0) and gs.pending_choice.is_empty(), "牌库选择可由AI处理")
	ABYSS.Travel.gain(gs, 0)
	var notes := int(u.travelNotes)
	gs.VerifiedRules.Fortune.transform(gs, 0, 0, false)
	gs.turn_counter += 1
	gs._begin_turn(0)
	complete(gs)
	check(gs.pending_choice.is_empty() and int(u.travelNotes) == notes, "书翁变为纸人后走正常回合抽牌，未触发翰墨逸香或消耗游记")
	gs = ready(643)
	p = gs.player(0)
	u = p.units[0]
	u.level = 1
	var zero: Dictionary = p.units[1]
	zero.level = 0
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs,0,0,"travel-decoy","普通召唤物",0,9,{"countsAsShikigami":false})
	var spell := give(gs,"c64307")
	var power := int(zero.attack)
	var health := int(zero.maxHp)
	check(not gs.can_play_card(0,spell,decoy.uid).ok and gs.play_card(0,spell,zero.uid), "志行戏法指定式神，排除普通召唤物")
	check(int(zero.attack)==power+1 and int(zero.maxHp)==health+1 and int(u.travelNotes)==1, "志行戏法使零勾目标成长并结附游记")

func curse_cases() -> void:
	var gs := ready(644)
	var p := gs.player(0)
	var caster: Dictionary = p.units[0]
	check(int(caster.get("curseGauze", 0)) == 7, "第一升勾赋七张咒纱")
	var enemy: Dictionary = gs.player(1).units[0]
	var hp: int = enemy.hp
	play(gs, "c64405", enemy.uid)
	check(enemy.hp == hp-2, "低语逐张减伤")
	play(gs, "c64401")
	check(gs.VerifiedRules.HairPower.guard_count(gs, 0) == 1, "灾厄宴真实坚守")
	check(gs.basic_attack(0, 1, p.units[1].uid) and ABYSS.Curse.count(p.units[1]) == 1 and ABYSS.Curse.count(caster) == 6, "其他式神坚守移进战斗区，转移一张咒纱")
	var prior: int = gs.player(1).avatarHp
	gs._damage_unit(0, 1, 1, 1, 0)
	gs._resolve_resolution_stack()
	check(ABYSS.Curse.count(p.units[1]) == 0 and gs.player(1).avatarHp == prior-1, "第一次受敌伤消耗咒纱并投射")
	gs = GS.create([PARTY[2], PARTY[3], "yingcao", "bailang"], [PARTY[4], "fenghuanghuo", "yaohu", "xuenv"], 644)
	prepare(gs)
	p = gs.player(0)
	var protected: Dictionary = p.units[1]
	play(gs, "c64404")
	turn(gs, 0)
	gs.player(1).energy = 10
	var place := give(gs, "c64601", 1)
	check(gs.play_card(1, place, protected.uid) and ABYSS.Jade.has(protected, 1), "敌方以真实用牌将勾玉结附至己方目标")
	var fire := int(gs.player(1).energy)
	check(gs.play_card(1, give(gs, "c12404", 1), protected.uid) and int(gs.player(1).energy) == fire - 2, "藤原绫子识别由对手结附的勾玉并实际额外扣除鬼火")

func serving() -> void:
	var gs := ready(645)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	check(ABYSS.Serving.has(u) and u.attack == 4, "首回合折敷生效")
	var h := give(gs, "c64501")
	var inst: Dictionary = p.hand[h]
	check(gs.play_card(0, h) and p.hand.any(func(c): return c.instanceId == inst.instanceId and c.get("abyssReflectionUsed", false)), "接物之道原实例弹回")
	check(int(p.servingMealTurn) == gs.turn_counter and p.units.any(func(a): return a.get("servingMarked", false)), "本膳料理延迟标记")
	play(gs, "c64503", p.units[1].uid)
	check(ABYSS.Serving.has(p.units[1]) and not ABYSS.Serving.has(u), "折敷按上限替换")
	play(gs, "c64505", gs.player(1).units[0].uid)
	check(u.awakened and ABYSS.Serving.has(p.units[1]) and ABYSS.Serving.has(u), "觉醒增加折敷上限")
	for awake in [false, true]:
		gs = ready(645)
		p = gs.player(0)
		u = p.units[0]
		u.awakened = awake
		gs.rng_state = 0
		play(gs, "c64501")
		gs.rng_state = 1
		play(gs, "c64501")
		var marked := ABYSS.Serving.markers(gs, 0)
		check(marked.size() == (2 if awake else 1) and marked.back().uid == u.uid, "连续本膳料理在觉醒前只有一个唯一标记，觉醒后保留左右两个")
		turn(gs, 0)
		check(not ABYSS.Serving.markers(gs, 0).is_empty(), "对手回合开始不消耗己方料理标记")
		turn(gs, 1)
		check(ABYSS.Serving.markers(gs, 0).is_empty() and ABYSS.Serving.has(u), "标记在下个己方回合开始真实结附折敷")

func jade() -> void:
	var gs := ready(646)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	var foe: Dictionary = gs.player(1).units[0]
	play(gs, "c64601", foe.uid)
	check(ABYSS.Jade.has(foe, 0), "敌方携带实际勾玉")
	play(gs, "c64604")
	check(p.hand.any(func(c): return c.definitionId == ABYSS.Jade.OATH), "海国誓约真实生成")
	var hp: int = foe.hp
	check(gs.play_card(0, p.hand.find_custom(func(c): return c.definitionId == ABYSS.Jade.OATH), u.uid), "誓约可对己方使用")
	check(ABYSS.Jade.has(u, 0) and not ABYSS.Jade.has(foe, 0) and int(foe.hp) == hp-3, "勾玉唯一且实际移除造成伤害")
	foe.front = 1
	foe.hp = 10
	check(gs.basic_attack(0, 0) and (ABYSS.Jade.has(foe, 0) or foe.hp == 0), "交战将勾玉转移到另一个式神")
	gs = ready(646)
	p = gs.player(0)
	u = p.units[0]
	foe = gs.player(1).units[0]
	play(gs, "c64601", u.uid)
	foe.front = 1
	foe.hp = 1
	check(gs.basic_attack(0, 0) and foe.hp == 0 and ABYSS.Jade.has(u, 0) and not ABYSS.Jade.has(foe, 0), "交战勾玉先投射；对方被投射气绝时不能转移")

func chili() -> void:
	var gs := ready(647)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	var foe: Dictionary = gs.player(1).units[0]
	give(gs, "c64703")
	var hp: int = foe.hp
	foe.front = 1
	play(gs, "c64701", foe.uid)
	check(gs.pending_choice.instanceIds.size() == 1 and AI.take_action(gs, 0), "螭啸真实弃牌选择")
	check(ABYSS.Discard.count(gs, 0) == 1 and u.has("lanternStored"), "弃龙骧立刻登记并蓄力对应派系蟠息")
	check(foe.hp < hp and p.hand.size() == 1, "被弃龙骧补抽且结算伤害")
	p.chiliDiscards = 3
	play(gs, "c64707")
	check(p.hand.filter(func(c): return c.definitionId in ABYSS.Discard.TREASURES).size() == 3, "三次弃牌之后获得三件不同秘宝")
	play(gs, "c64708")
	check(p.chiliVoid and p.hand.size() >= 2, "归墟弃真实手牌并生成专属牌")
	gs = ready(647)
	p = gs.player(0)
	foe = gs.player(1).units[0]
	foe.front = 1
	foe.hp = 12
	var filler := give(gs, "c10702")
	var filler_inst: Dictionary = p.hand[filler]
	give(gs, "c64703")
	play(gs, "c64701", foe.uid)
	var deck_size := int(p.deck.size())
	check(AI.take_action(gs, 0) and p.hand.has(filler_inst) and p.deck.size() == deck_size - 1 and int(foe.hp) == 5, "AI 从多张手牌选龙骧，真实弃置、补抽并命中战斗区")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup([PARTY[0], "yingcao-pupu", "tongnantongnv", PARTY[5]], ENEMIES, 647)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, [ABYSS.Aki.PRACTICE])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var tile := choice_face(b, "sword")
		check(tile != null and choice_face(b, "water") != null, "神通真实面板显示选项")
		if tile != null: await click(tile)
		await settled(b)
		check("sword" in ABYSS.Aki.charms(gs.player(0).units[0]), "鼠标选神通后状态改变")
		b._show_unit_popover(gs.player(0).units[0], 0, 0)
		check(texts(b._tooltip).contains("剑神通"), "秋叶详情展示真实结附的剑神通")
		b._hide_tooltip()
		hand(b, ["c64701","c64703"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		var victim: Dictionary = gs.player(1).units[0]
		await click(b._unit_widget(str(victim.uid)))
		await settled(b)
		tile = choice_face(b, "c64703")
		check(tile != null, "螭啸选目标后显示真实手牌")
		if tile != null: await click(tile)
		await settled(b)
		check(gs.player(0).units[3].has("lanternStored") and ABYSS.Discard.count(gs, 0) == 1, "鼠标弃牌后蓄力")
		var chili_unit: Dictionary = gs.player(0).units[3]
		b._show_unit_popover(chili_unit, 0, 3)
		var detail := texts(b._tooltip)
		check(detail.contains(str(chili_unit.lanternStored.card.name)) and not detail.contains("歧路笼火") and detail.contains("本局弃牌 1 次"), "螭璃详情显示实际蓄力牌和弃牌计数")
		b._hide_tooltip()
		var unprotected: Dictionary = gs.player(1).units[1]
		for enemy in [victim, unprotected]:
			var pos := gs._unit_index_by_uid(1, enemy.uid)
			gs._apply_form(1, pos, Content.card_def("c10702"))
			enemy.form.cardInstance = Insight.instance(gs, 1, "c10702")
		victim.movementVeil = true
		hand(b, ["c63001"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def) == [unprotected.uid], "蒲蒲鼠标出牌仅高亮无帷幕的实体形态")
		await click(b._unit_widget(str(unprotected.uid)))
		await settled(b)
		check(unprotected.form.is_empty() and not victim.form.is_empty(), "蒲蒲鼠标只回收所选合法形态")
		hand(b, ["c63202"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		tile = choice_face(b, "armor")
		check(tile != null, "童羽歌以鼠标打开护甲分支")
		if tile != null: await click(tile)
		await settled(b)
		var twins: Dictionary = gs.player(0).units[2]
		tile = choice_face(b, str(twins.uid))
		check(tile != null, "童羽歌真实己方式神选项可点击")
		if tile != null: await click(tile)
		await settled(b)
		check(int(twins.shield) == 1 and gs.pending_choice.is_empty(), "童羽歌鼠标目标获实际护甲")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	catalog()
	akiba()
	travel()
	curse_cases()
	serving()
	jade()
	chili()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("DRAGON_ABYSS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
