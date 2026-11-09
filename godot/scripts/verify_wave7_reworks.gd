extends "res://scripts/verify_insight.gd"

const Rework := preload("res://scripts/wave7_rework_rules.gd")
const LAMPS := ["quanshen-lizhan", "yaodaoji-zhuren", "qingxingdeng-huihuo", "shantong"]
const REBIRTH := ["jutun-wangkong", "caitong-lvli", "qingfangzhu-fanchen", "shantong"]
const ENEMIES := ["bingyong", "bailang", "yaohu", "xuenv"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WAVE7_REWORK_FAIL ", detail)

func fixture(team: Array = LAMPS) -> GS:
	var gs := GS.create(team, ENEMIES, 292607)
	prepare(gs)
	for p in gs.players:
		p.realms.clear()
		p.deck.clear()
		p.avatarHp = 30
		for u in p.units:
			u.front = 0
		for i in 8:
			p.deck.append(Insight.instance(gs, 0, "c11301"))
	return gs

func settle_rules(gs: GS) -> void:
	var attempts := 0
	while attempts < 24 and (not gs.pending_choice.is_empty() or not gs.response_window.is_empty()):
		attempts += 1
		var owner := gs.action_player()
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, owner), "AI settles %s" % gs.pending_choice.get("type", "choice"))
		elif not gs.response_window.is_empty(): gs.pass_response(owner)
	check(gs.pending_choice.is_empty() and gs.response_window.is_empty(), "resolution completes")

func ready_all() -> void:
	for role_number in [289, 291, 292, 299, 602, 607]:
		for i in range(1, 9):
			var gs := fixture(LAMPS if role_number in [289, 291, 292] else REBIRTH)
			var p := gs.player(0)
			var foe := gs.player(1)
			var id := "c%d" % (role_number * 100 + i)
			var card := Content.card_def(id)
			check(card.get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "native definition and source PNG " + id)
			var target = null
			var src := gs._source_index(0, card)
			match card.target:
				"other-ally-unit", "ally-unit": target = p.units[3].uid
				"enemy-unit", "any-unit", "enemy-reserve-unit": target = foe.units[0].uid
			match id:
				"c28901", "c29203", "c60204", "c60708": gs._knockout_unit(p.units[src])
				"c60701", "c60703", "c60707": Rework.summon_hand(gs, 0, src)
			gs._resolve_resolution_stack()
			if id == "c28907":
				p.deck.append(Insight.instance(gs, 0, "c28902"))
				p.deck.append(Insight.instance(gs, 0, "c28903"))
			if id == "c29106":
				foe.units[0].front = 1
				foe.units[0].hp = 1
			if id == "c60205": p.units[src].waveOneTurn = gs.turn_counter
			if id == "c29905": Rework.overheal(gs, 0, src, 2)
			var idx := give(gs, id)
			var candidate := AI._best_card(gs, 0)
			check(candidate.ok and gs.can_play_card(0, candidate.hand, candidate.target, candidate.origin).ok, id + " AI uses actual legal mode/target")
			var check_result := gs.can_play_card(0, idx, target)
			check(check_result.ok, id + " legal " + str(check_result.get("reason", "")))
			check(gs.play_card(0, idx, target), id + " actually plays")
			settle_rules(gs)
			check(gs.rule_events.any(func(e): return e.kind == "card-announced" and e.card.id == id) or gs.command_log.any(func(entry): return entry.c == "play_card" and entry.a.card == id), id + " uses normal resolution")

func dog_and_blade() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var dog: Dictionary = p.units[0]
	var ally: Dictionary = p.units[3]
	ally.level = 1
	var power: int = ally.attack
	gs.raise_unit_level(0, 3)
	check(ally.attack == power+1 and ally.level == 2, "历战监听真实升级")
	var old := int(dog.attack)
	dog.level = 2
	gs.raise_unit_level(0, 0)
	check(dog.attack == old, "历战每回合一次")
	var enemy: Dictionary = foe.units[0]
	enemy.baseMaxHp = 9
	gs._recalc(enemy)
	enemy.front = 1
	play(gs, "c29204", enemy.uid)
	check(enemy.hp == 7 and enemy.frozen > 0 and enemy.attack == 0 and dog.hp == 5, "无心斩的追猎、眩晕和零力量在真实反击前落实")
	play(gs, "c29205")
	enemy.front = 0
	dog.front = 0
	ally.front = 1
	turn(gs, 0)
	var dog_health: int = dog.hp
	check(gs.basic_attack(1, 2) and dog.front == 1 and ally.front == 0 and ally.hp == ally.maxHp and dog.hp <= dog_health, "固守之誓真正改战斗目标")
	turn(gs, 1)
	p.energy = 12
	play(gs, "c29208")
	check(dog.awakened and p.hand.any(func(inst): return inst.definitionId == "c29201"), "往昔之日生成心剑并保留觉醒")
	gs._knockout_unit(dog)
	var attack_before: int = dog.attack
	turn(gs, 0)
	check(dog.hp > 0 and dog.attack > attack_before, "觉醒回合结束后真实复活和永久成长")

	gs = fixture()
	p = gs.player(0)
	foe = gs.player(1)
	var blade: Dictionary = p.units[1]
	var found := Insight.instance(gs, 0, "c28903")
	p.deck.push_front(found)
	check(gs.basic_attack(0, 1) and p.hand.has(found), "未觉醒的呪刃通过真正打脸抽所属牌")
	turn(gs, 0)
	turn(gs, 1)
	p.energy = 12
	var still_in_deck := Insight.instance(gs, 0, "c28904")
	p.deck.push_front(still_in_deck)
	play(gs, "c28902")
	check(p.deck.has(still_in_deck) and blade.name == "妖刀·噬" and blade.attack == 3, "觉醒的呪刃切换为噬并保留牌库原实例")
	play(gs, "c28904")
	check(blade.name == "妖刀·疾" and blade.maxHp == 7 and gs.VerifiedRules.Combat.has(blade, "pierce"), "疾切换独立身材和贯通")
	play(gs, "c28908")
	var pick := "w7-blade-1"
	check(gs.pending_choice.instanceIds.has(pick) and not gs.pending_choice.instanceIds.has("w7-blade-2"), "无尽刃狱展示不同于当前妖刀的选项")
	check(gs.resolve_divination_choice(0, pick), "无尽刃狱玩家选择")
	check(blade.name == "妖刀·御" and gs.rule_events.any(func(e): return e.kind == "automatic-card" and e.card.id == "c10102"), "无尽刃狱使用对应实际起源牌")

	gs = fixture()
	p = gs.player(0)
	ally = p.units[3]
	ally.level = 0
	var before: int = gs.player(1).avatarHp
	var gained_attack: int = ally.attack + 2
	play(gs, "c29207", ally.uid)
	check(ally.level == 0 and ally.attack == gained_attack and gs.player(1).avatarHp == before - gained_attack, "免许皆传零勾目标实际成长并攻击")

func lamp() -> void:
	var gs := fixture()
	var legacy_fire := give(gs, "huidengzhihuo")
	check(gs.play_card(0, legacy_fire) and Rework.realms(gs, 0, "w7-lamp-fire").size() == 1, "旧辉灯之火 ID 进入真实幻境区")

	gs = fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var lamp_body: Dictionary = p.units[2]
	play(gs, "c29101", foe.units[0].uid)
	check(int(foe.units[0].hp) == int(foe.units[0].maxHp) - 4, "夜火辉耀真实专注付费并增伤")
	play(gs, "c29201")
	play(gs, "c29202", p.units[3].uid)
	check(Rework.realms(gs, 0, "w7-lamp-fire").size() == 1, "战斗、法术、其他三类合成唯一火")
	p.energy = 0
	var index := give(gs, "c29201")
	check(gs.can_play_card(0, index).ok and gs.play_card(0, index), "零鬼火使用手牌时真实代付")
	check(Rework.realms(gs, 0, "w7-lamp-fire").is_empty() and lamp_body.get("waveLampKinds", []).is_empty(), "代付消耗幻境且不计类别")
	p.energy = 10
	play(gs, "c29103")
	check(gs.pending_choice.instanceIds.size() == 3 and gs.resolve_divination_choice(0, "w7-story-2"), "入场选择三个见闻之一")
	var uid: String = Rework.realms(gs, 0, "w7-lamp-story")[0].uid
	turn(gs, 0)
	check(Rework.realms(gs, 1, "w7-lamp-story")[0].uid == uid and gs.pending_choice.instanceIds.size() == 2, "回合结束转移同一幻境，敌方只选未用见闻")
	check(gs.resolve_divination_choice(1, "w7-story-1"), "敌方选择并执行投射")
	turn(gs, 1)
	check(gs.pending_choice.instanceIds == ["w7-story-0"] and gs.resolve_divination_choice(0, "w7-story-0") and Rework.realms(gs, 0, "w7-lamp-story").is_empty(), "第三个见闻结算后自毁")

	gs = fixture()
	foe = gs.player(1)
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, 1, 0, "wave7-test-decoy", "召唤物", 1, 8, {"countsAsShikigami": false})
	foe.units[0].level = 0
	var damage := give(gs, "c29101")
	check(not gs.can_play_card(0, damage, decoy.uid).ok and gs.can_play_card(0, damage, foe.units[0].uid).ok, "夜火辉耀只允许式神，包括零勾式神")
	play(gs, "c29103")
	check(gs.resolve_divination_choice(0, "w7-story-0") and decoy.hp == 7 and foe.avatarHp == 29, "叙话成书见闻一覆盖非式神召唤物和牌手")

func rebirth_trio() -> void:
	var gs := fixture(REBIRTH)
	var p := gs.player(0)
	var foe := gs.player(1)
	var shuten: Dictionary = p.units[0]
	play(gs, "c60202")
	check(shuten.hp == 1 and shuten.attack == 3, "千丈岳造成基于自身生命伤害并触发1生命永久成长")
	var ally: Dictionary = p.units[3]
	ally.hp = 1
	gs._damage_unit(0, 3, 1, 1)
	gs._resolve_resolution_stack()
	check(ally.hp == ally.maxHp and Rework.realms(gs, 0, "w7-peak")[0].hp == 1, "千丈岳复活此前1血的单位并扣3耐久")
	play(gs, "c60206")
	gs._damage_unit(0, 3, 99, 1)
	gs._damage_avatar(0, 99, 1)
	check(ally.hp == 1 and p.avatarHp == 1 and gs.winner < 0, "何渡鬼道保护己方角色和牌手")
	turn(gs, 0)
	gs._damage_avatar(0, 3, 1)
	check(p.avatarHp == 1, "何渡鬼道跨敌方回合")
	turn(gs, 1)
	check(Rework.minimum_hp(gs, 0) == 0, "何渡鬼道于下一己方回合失效")

	gs = fixture(REBIRTH)
	p = gs.player(0)
	foe = gs.player(1)
	shuten = p.units[0]
	shuten.level = 1
	foe.units[1].level = 0
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, 1, 0, "wave7-test-decoy", "召唤物", 1, 12, {"countsAsShikigami": false})
	var trick := give(gs, "c60208")
	check(not gs.can_play_card(0, trick, decoy.uid).ok and gs.can_play_card(0, trick, foe.units[1].uid).ok, "灭道殉神戏法只选一个敌方式神，接受零勾")
	check(gs.play_card(0, trick, foe.units[1].uid) and foe.units[1].hp == 1 and foe.units[0].hp == foe.units[0].maxHp, "实际戏法先降指定目标血量，其他准备区式神不受伤")

	gs = fixture(REBIRTH)
	p = gs.player(0)
	foe = gs.player(1)
	var ibaraki: Dictionary = p.units[1]
	var hand_def := Content.card_def("guishizhishou")
	check(hand_def.type == "summon" and hand_def.nonHandDerivative and hand_def.value.attack == 0 and hand_def.value.hp == 1, "鬼蚀之手 uses its source-backed 0/1 summon definition")
	var old_token := give(gs, "guishizhishou")
	check(not gs.play_card(0, old_token) and p.hand.size() == 1 and Rework.hand(gs, 0).is_empty(), "historical combat instance cannot create an extra attack")
	p.hand.clear()
	play(gs, "c60702")
	var claw := Rework.hand(gs, 0)
	check(claw.hp == claw.attack and claw.attack == 1 and claw.baseAttack == 0 and claw.permanentAttack == 1, "伊吹山召唤真实1/1鬼蚀之手")
	check(claw.summonRulesText.contains("永久获得1点力量") and p.hand.is_empty(), "field summon carries its real rules without creating a combat card")
	var target: Dictionary = foe.units[1]
	play(gs, "c60701", target.uid)
	check(target.hp == 0 and ibaraki.front == 1 and Rework.hand(gs, 0).is_empty(), "鬼之焰让召唤物追击准备区并按退场移动茨木")
	play(gs, "c60705")
	claw = Rework.hand(gs, 0)
	check(claw.swift and claw.attack == 2 and claw.hp == 2, "登程使真实入场召唤物获得迅捷，并累计手的力量")
	Rework.summon_hand(gs, 0, 1)
	gs._resolve_resolution_stack()
	var new_claw := Rework.hand(gs, 0)
	check(claw.get("removed", false) and new_claw.uid != claw.uid and new_claw.hp == 3 and new_claw.attack == 3, "连续召唤用真实新实例并处理旧手离场")
	gs._knockout_unit(ibaraki)
	play(gs, "c60708")
	check(ibaraki.has("waveGhostEnabled") and ibaraki.hp == 0 and ibaraki.name == "茨木童子·鬼蚀", "豪气解放启用气绝鬼蚀并减少倒计时")
	check(gs.VerifiedRules.Samurai.power(ibaraki) == new_claw.attack, "变为鬼蚀时实际力量来自在场鬼蚀之手")
	gs._grow_unit(new_claw, 2, 0)
	check(gs.VerifiedRules.Samurai.power(ibaraki) == new_claw.attack, "鬼蚀之手变更力量立即同步到鬼蚀")
	var locked: Dictionary = foe.units[0]
	locked.front = 1
	locked.formRules = {"lockEnemyFrontReplacement": true}
	var origin := give(gs, "c60701")
	check(not gs.can_play_card(0, origin).ok and gs.can_play_card(0, origin, null, true).ok, "鬼蚀仅能用起源，起源战斗牌不受敌方禁止替换战斗区的限制")
	check(gs.play_card(0, origin, null, true) and gs.front_unit(0).uid == new_claw.uid, "鬼蚀实际使用起源战斗牌仍保留己方鬼蚀之手")
	gs._knockout_unit(new_claw)
	gs._resolve_resolution_stack()
	check(gs.VerifiedRules.Samurai.power(ibaraki) == 0, "鬼蚀之手消灭后鬼蚀不再沿用旧力量")

	gs = fixture(REBIRTH)
	p = gs.player(0)
	var monk: Dictionary = p.units[2]
	gs._damage_unit(0, 2, 2, 1)
	check(p.hand.size() == 1 and p.hand[0].efStacks == 1, "凡尘真实受伤产生生命精华")
	play(gs, "c29902")
	check(p.hand[0].efStacks == 2 and monk.hp == 6, "佛心只为实际溢疗目标增加精华")
	play(gs, "c29907")
	check(p.hand[0].efStacks == 6, "万法皆识进场增加4层精华")
	play(gs, "c29904")
	check(p.hand[0].efStacks == 10 and monk.attack == 7, "覆盖形态触发万法皆识离场，满血归凡入世+3")
	gs._damage_unit(0, 2, 1, 1)
	check(monk.attack == 4, "归凡入世只在未受伤时加攻")
	play(gs, "c29908", p.units[3].uid)
	p.avatarHp = 10
	for _i in 3:
		var inst := Insight.instance(gs, 0, "shengmingjinghua")
		inst.efStacks = 10
		p.hand.append(inst)
	check(gs.end_turn(0) and gs.winner == 0 and p.hand.filter(func(inst): return inst.definitionId == "shengmingjinghua" and int(inst.efStacks) == 10).size() == 1, "垢去明存弃掉三张实际满层精华并造成30伤害")

	gs = fixture(REBIRTH)
	p = gs.player(0)
	foe = gs.player(1)
	monk = p.units[2]
	ally = p.units[3]
	ally.level = 0
	decoy = gs.VerifiedRules.NativeSummons.summon(gs, 0, 2, "wave7-test-decoy", "召唤物", 1, 8, {"countsAsShikigami": false})
	var awakening := give(gs, "c29908")
	check(not gs.can_play_card(0, awakening, decoy.uid).ok and gs.can_play_card(0, awakening, ally.uid).ok, "垢去明存只选式神，接受零勾友方")
	var ai_option := AI._best_card(gs, 0)
	check(ai_option.ok and ai_option.target != decoy.uid and gs.can_play_card(0, ai_option.hand, ai_option.target, ai_option.origin).ok, "AI 不会让非式神召唤物成为垢去明存目标")
	check(gs.play_card(0, awakening, ally.uid) and foe.avatarHp == 30 - ally.attack, "垢去明存的零勾友方真实攻击")
	monk.baseRulesSuppressed = true
	gs._damage_unit(0, 3, 1, 1)
	check(p.hand.is_empty(), "基础规则被压制时不再生成生命精华")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = viewport
		DisplayServer.window_set_size(viewport)
		var b := Battle.new()
		b.setup(LAMPS, ENEMIES, 29103)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		var p := gs.player(0)
		prepare(gs)
		p.avatarHp = 20
		hand(b, ["c29202"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).size() == 3, "传业授道可用实际鼠标指定其他己方式神")
		var other: Dictionary = p.units[3]
		var health: int = other.maxHp
		await click(b._unit_widget(str(other.uid)))
		await settled(b)
		check(other.maxHp == health+1 and p.units[0].form.cardId == "c29202", "点击目标后安装形态并给另一式神成长")
		hand(b, ["c29103"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var story_tile := choice_face(b, "w7-story-2")
		check(story_tile != null, "叙话成书显示原版见闻选项")
		if story_tile != null: await click(story_tile)
		await settled(b)
		check(p.avatarHp == 25 and gs.pending_choice.is_empty(), "点击见闻只结算对应恢复")
		hand(b, ["c28908"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var blade_tile := choice_face(b, "w7-blade-1")
		check(blade_tile != null, "无尽刃狱显示可选妖刀")
		if blade_tile != null: await click(blade_tile)
		await settled(b)
		check(p.units[1].name == "妖刀·御" and gs.pending_choice.is_empty(), "点击妖刀执行切换")
		b.queue_free()
		await process_frame

		b = Battle.new()
		b.setup(REBIRTH, ENEMIES, 60702)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		gs = b.gs
		prepare(gs)
		hand(b, ["c60702"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var claw := Rework.hand(gs, 0)
		var widget: Control = b._unit_widget(str(claw.get("uid", "")))
		check(widget != null, "实际鼠标打出伊吹山，战斗区显示召唤物")
		if widget != null:
			await click(widget)
			if b._selected_attacker >= 0: await click(widget)
			await settled(b)
			check(texts(b).contains("召唤物能力") and texts(b).contains("永久获得1点力量"), "点开真实召唤物时展示进场和消灭能力")
		gs.player(0).units[0].level = 1
		var rival: Dictionary = gs.player(1).units[1]
		rival.level = 0
		hand(b, ["c60208"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).has(rival.uid), "戏法卡在鼠标交互中可选择零勾式神")
		await click(b._unit_widget(str(rival.uid)))
		await settled(b)
		check(int(rival.hp) == 1, "鼠标选择后真正结算灭道殉神戏法")
		var ibaraki: Dictionary = gs.player(0).units[1]
		gs._knockout_unit(ibaraki)
		Rework.summon_hand(gs, 0, 1)
		gs._resolve_resolution_stack()
		claw = Rework.hand(gs, 0)
		hand(b, ["c60708"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var ghost_widget := b._unit_widget(str(ibaraki.uid))
		var ghost_data: Dictionary = ghost_widget.get("data") if ghost_widget != null else {}
		check(ghost_data.get("name") == "茨木童子·鬼蚀" and int(ghost_data.get("attack", -1)) == int(claw.get("attack", -2)), "鬼蚀头像显示鬼蚀之手实际力量")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	ready_all()
	dog_and_blade()
	lamp()
	rebirth_trio()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("WAVE7_REWORK checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
