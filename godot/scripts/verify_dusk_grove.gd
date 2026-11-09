extends "res://scripts/verify_insight.gd"

const DUSK_TEAM := ["kongquemingwang", "ji", "panguan-xuanmo", "yaodaoji"]
const GROVE_TEAM := ["yanling", "guniao-yuxiang", "taohua-luoying", "yaodaoji"]
const RIVAL_TEAM := ["bingyong", "fenghuanghuo", "xuenv", "yaodaoji"]

func fixture(team: Array, rivals: Array = RIVAL_TEAM) -> GS:
	var gs := GS.create(team, rivals, 604605)
	prepare(gs)
	if not gs.pending_choice.is_empty(): AI.take_action(gs, 0)
	gs.turn_counter = 15
	return gs

func action_ok(gs: GS, id: String, target = null, mode = false) -> bool:
	return gs.play_card(0, give(gs, id), target, mode)

func choose_word(gs: GS, id: String) -> void:
	check(gs.pending_choice.get("type") == "grove-word", "private choice exists")
	check(not gs.resolve_divination_choice(1, id) and not gs.resolve_divination_choice(0, "word-invalid"), "private choice rejects other side and unknown mode")
	check(gs.resolve_divination_choice(0, id), "owner picks " + id)

func cards() -> void:
	for code in [605,604,601,614,610,612]:
		for n in range(1,9):
			var gs := fixture(DUSK_TEAM if code in [605,604,601] else GROVE_TEAM)
			var id := "c%d" % (code*100+n)
			var p := gs.player(0)
			var e := gs.player(1)
			var target = null
			if id in ["c60506","c60507","c60101","c61401","c61404","c61006"]: target = e.units[0].uid
			if id in ["c60104","c61201","c61202","c61205","c61207"]: target = p.units[3].uid
			if id == "c60507": e.units[0].armorBreak = 3
			if id == "c60108":
				gs._knockout_unit(p.units[3])
				gs._resolve_resolution_stack()
				target = p.units[3].uid
			var hand_index := give(gs, id)
			check(Content.card_def(id).get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "verified native definition and original PNG " + id)
			if id == "c61403":
				check(not gs.can_play_card(0, hand_index).ok, "诳默仅响应可用")
				continue
			var verdict := gs.can_play_card(0, hand_index, target)
			check(verdict.ok, "legal base %s · %s" % [id,verdict.get("reason","")])
			var pick := AI._best_card(gs, 0)
			check(pick.ok and gs.can_play_card(0, pick.hand, pick.target, pick.origin).ok, "AI proposes a legal play " + id)
			check(gs.play_card(0, hand_index, target), "real primary card " + id)
			if not gs.pending_choice.is_empty():
				check(AI.take_action(gs,0) and gs.pending_choice.is_empty(), "AI completes " + id)

func peacock() -> void:
	var gs := fixture(DUSK_TEAM)
	var p := gs.player(0)
	var e := gs.player(1)
	var enemy: Dictionary = e.units[0]
	var legacy_slot := give(gs, "kongqueling")
	p.hand[legacy_slot].quillStacks = 2
	check(gs.play_card(0, legacy_slot, enemy.uid) and enemy.armorBreak == 2, "旧孔雀翎 ID 保留真实堆叠效果")

	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	enemy = e.units[0]
	check(action_ok(gs,"c60501") and p.hand.any(func(c): return c.definitionId == "peacock-quill" and c.get("quillStacks",1)==3), "羽化获得堆叠三的孔雀翎")
	check(action_ok(gs,"c60504"), "迷离之境进场")
	var slot: int = p.hand.find_custom(func(c): return c.definitionId == "peacock-quill")
	enemy.hp = 30
	enemy.baseMaxHp = 30
	enemy.maxHp = 30
	enemy.front = 1
	var old: int = enemy.attack
	check(gs.play_card(0,slot,enemy.uid) and enemy.armorBreak==3 and enemy.attack==old-3, "堆叠逐点取得破甲，迷离领域随破甲实时减力")
	check(action_ok(gs,"c60505"), "祈神之舞设置条件")
	gs.VerifiedRules.ArmorBreak.give(gs,0,0,1,0,1)
	gs._resolve_resolution_stack()
	check(enemy.hp<30 and p.units[0].hp==p.units[0].maxHp and p.units[0].peacockDanceTurn==gs.turn_counter, "阈值追加一次免伤攻击")
	gs.VerifiedRules.ArmorBreak.give(gs,0,0,1,0,3)
	gs._resolve_resolution_stack()
	var rest: int = enemy.hp
	check(enemy.armorBreak==3 and enemy.hp==rest, "同回合第二次叠破甲不再追击")

	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	enemy = e.units[0]
	enemy.front = 1
	enemy.armorBreak = 3
	var awakening := Insight.instance(gs,0,"c60508")
	p.deck.append(awakening)
	check(gs.basic_attack(0,0) and p.units[0].awakened and not p.deck.has(awakening), "攻击三层破甲对象前，从实际牌库自动使用觉醒")
	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	p.units[0].level = 1
	var trick := give(gs,"c60508")
	var old_inst: Dictionary = p.hand[trick]
	var legal := gs.can_play_card(0,trick)
	var played := gs.play_card(0,trick)
	check(played and not p.units[0].awakened and p.units[0].attack==4 and p.deck.has(old_inst), "未足勾只走戏法，加力量并洗回原实例 · %s · %s · %s" % [legal.get("reason",""),p.units[0].attack,p.deck.has(old_inst)])

	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	e.units[0].hp = 12
	e.units[0].front = 1
	e.units[1].hp = 12
	e.units[1].armorBreak = 2
	check(action_ok(gs,"c60507",e.units[1].uid) and e.units[0].hp==8 and e.units[1].hp==7, "荆棘舞先与原战斗区交战，随后对选定破甲式神发动第二次攻击")
	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	p.units[0].level = 1
	e.units[0].level = 0
	var pursuit := give(gs, "c60507")
	check(gs.can_play_card(0, pursuit, e.units[0].uid).ok and gs.can_play_card(0, pursuit, "avatar-1").ok, "荆棘舞戏法追猎可点0勾式神，无前排时也可点牌手")
	e.units[0].front = 1
	check(not gs.can_play_card(0, pursuit, "avatar-1").ok, "有前排时追猎不能越过其直接指定牌手")
	e.units[0].front = 0
	check(gs.play_card(0, pursuit, "avatar-1") and e.avatarHp == 26 and not p.units[0].get("barrier", false), "戏法实际追猎牌手，无正式分支屏障")
	gs = fixture(DUSK_TEAM)
	e = gs.player(1)
	e.units[0].keywords = ["veil"]
	e.units[1].level = 0
	var marked := give(gs,"c60506")
	check(not gs.can_play_card(0,marked,e.units[0].uid).ok and gs.play_card(0,marked,e.units[1].uid) and e.units[1].armorBreak == 3, "孔雀减力破甲遵守帷幕，合法零勾式神实际受破甲")

func seasons() -> void:
	var gs := fixture(DUSK_TEAM)
	var p := gs.player(0)
	var e := gs.player(1)
	e.units[0].front = 1
	p.units[3].front = 1
	p.avatarHp = 22
	p.units[3].hp = 1
	check(action_ok(gs,"c60401") and p.avatarHp==24 and p.units[3].hp==3, "春治疗牌手及己方战斗区")
	check(action_ok(gs,"c60407"), "弥天叶唳可用")
	var summer_idx := give(gs,"c60402")
	var spring_iid: String = p.units[1].form.cardInstance.instanceId
	var fire: int = p.energy
	var hand_count: int = p.hand.size()
	check(gs.play_card(0,summer_idx) and p.deck.any(func(c):return c.instanceId==spring_iid), "季节离场洗回同一形态实例")
	check(p.energy==fire and p.hand.size()==hand_count and e.units[0].armorBreak==0, "首次手用夏抽牌返火，且先结算春破甲再投射消费")
	check(action_ok(gs,"c60404") and gs.front_unit(0).id=="season-snowman" and p.units[3].attack==p.units[3].baseAttack+1, "夏退场全员加力，冬进场真实雪人")
	var old_foe: int = e.avatarHp
	check(action_ok(gs,"c60404") and gs.front_unit(0).attack==3 and gs.front_unit(0).shield==2 and e.avatarHp==old_foe-2, "冬离场2伤，后续雪人增长、融合与护甲")
	var attack_before: int = p.units[1].attack
	check(action_ok(gs,"c60408") and p.units[1].awakened and p.units[1].attack==attack_before+1, "季觉醒洗四季并真实检索形态")
	var idx := give(gs,"c60401")
	check("instant" in gs.hand_card_def(0,idx).keywords, "觉醒使四时获得瞬发")

	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	p.deck.assign([Insight.instance(gs,0,"c60403"),Insight.instance(gs,0,"c60402"),Insight.instance(gs,0,"c60404"),Insight.instance(gs,0,"c60401")])
	check(action_ok(gs,"c60405") and p.deck.is_empty() and p.units[1].form.cardId=="c60404", "华落四时生按春夏秋冬逐张使用真实牌库实例")
	check(p.seasonLeft=={"1":1,"2":1,"3":1}, "每个季节都经历完整离场而非模拟数值")
	check(action_ok(gs,"c60407"), "弥天叶唳可在自动季节用牌之后进入场上")
	var fire_after: int = p.energy
	check(action_ok(gs,"c60404") and p.energy==fire_after-1, "本回合从牌库已使用同名季节牌时，手牌重用不会返火")
	p.deck.assign([Insight.instance(gs,0,"c60402"),Insight.instance(gs,0,"c60401")])
	check(gs.end_turn(0) and p.units[1].form.cardId=="c60401" and p.units[1].seasonAutoUsed, "敌方回合开始优先使用下一季节，记录整局一次")

	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	e.units[0].front = 1
	check(action_ok(gs,"c60407") and action_ok(gs,"c60401"), "季节转移前已有四时形态与幻境")
	spring_iid = p.units[1].form.cardInstance.instanceId
	var transferred: Dictionary = gs.VerifiedRules.WaterMoon.move_board(gs,1,p.units[1].uid,"映月")
	gs._resolve_resolution_stack()
	check(transferred.get("instanceId") == spring_iid and Insight.zone(gs,0).has(transferred) and not p.deck.any(func(c): return c.instanceId == spring_iid), "映月保留启悟区内的原实例，幻境不复制它")
	check(p.units[1].form.is_empty() and p.seasonLeft == {"1":1} and e.units[0].armorBreak == 2, "转移形态仍结算四时离场破甲和计数")

	gs = fixture(["kongquemingwang", "ji", "panguan-xuanmo", "xiaoxiuzhishou"])
	p = gs.player(0)
	e = gs.player(1)
	p.units[3].awakened = true
	check(action_ok(gs, "c60404") and action_ok(gs, "c60401") and e.avatarHp == 28, "四时·冬离场是形态牌固定2点伤害，不继承基础能力增伤")

func inkjudge() -> void:
	var gs := fixture(DUSK_TEAM)
	var p := gs.player(0)
	var e := gs.player(1)
	var enemy: Dictionary = e.units[0]
	var old_hp: int = p.avatarHp
	check(action_ok(gs,"c60103") and action_ok(gs,"c60102"), "黄泉岸和摄魂进入各自区域")
	var quote := int(enemy.attack)+int(enemy.hp)
	check(action_ok(gs,"c60101",enemy.uid) and enemy.hp==0 and p.avatarHp==old_hp-quote, "死契真实消灭并对己方牌手结算快照伤害")
	var ess: int = p.hand.find_custom(func(c): return c.definitionId=="shengmingjinghua")
	check(ess>=0 and p.hand[ess].efStacks==1+int(enemy.maxHp) and p.units[2].formCountdown.remaining==3, "黄泉岸直接消灭读生命，基础精华和气绝减倒计时")
	check(action_ok(gs,"c60105"), "罚恶赏善可用")
	gs._knockout_unit(p.units[3])
	gs._resolve_resolution_stack()
	check(p.units[3].knockout==1, "己方新气绝时少1倒计时")
	var before: int = e.units.filter(func(u):return u.hp==0).size()
	check(action_ok(gs,"c60108",p.units[3].uid) and p.units[3].hp>0 and e.units.filter(func(u):return u.hp==0).size()==before+1, "生死狭间指定复活并随机消灭敌方式神")

	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	var origin := give(gs,"c60101")
	enemy = e.units[0]
	check(gs.play_card(0,origin,enemy.uid,true) and enemy.hp==0 and p.avatarHp==30, "死之宣告确实走经典起源，不结算死契自伤")
	gs._deploy_realm(0,Content.card_def("c60103"))
	gs._deploy_realm(1,Content.card_def("c60103"))
	check(action_ok(gs,"c60107") and p.realms.is_empty() and e.realms.is_empty(), "荒寂消灭双方实际幻境")

	gs = fixture(DUSK_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	p.units[3].level = 0
	e.units[0].front = 1
	e.units[0].hp = 14
	var command := give(gs, "c60104")
	check(not gs.can_play_card(0, command, e.units[0].uid).ok and gs.can_play_card(0, command, p.units[3].uid).ok, "鬼使勒令接受0勾友方，拒绝敌方")
	check(gs.play_card(0, command, p.units[3].uid) and p.units[3].front == 1 and e.units[0].hp == 0, "鬼使勒令的额外攻击和必杀实际生效")

func words() -> void:
	var gs := fixture(GROVE_TEAM)
	var p := gs.player(0)
	var e := gs.player(1)
	gs.VerifiedRules.PeachGrove.turn_start(gs,0)
	gs._resolve_resolution_stack()
	choose_word(gs,"sin-形")
	check(action_ok(gs,"c61402") and action_ok(gs,"c61405"), "育言与真言道进场")
	gs.current_player = 1
	gs.turn_counter += 1
	var enemy: Dictionary = e.units[1]
	var hp: int = enemy.hp
	var p_hand: int = p.hand.size()
	check(gs.play_card(1,give(gs,"c12403",1)) and enemy.form.is_empty() and enemy.hp==hp-2, "形语罪命中敌手首张形态，反制且对使用者伤害")
	check(p.hand.size()==p_hand+1 and p.wordTriggers==1 and e.units[1].wordSinTurn==gs.turn_counter, "育言抽牌、整局次数、触发者回合均记录")
	gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"专项离场")
	check(e.hand.any(func(c):return c.definitionId=="c12403"), "真言道离场回给敌方同名牌")
	gs.current_player = 0
	gs.turn_counter += 1
	var use := give(gs,"c61401")
	check(gs.hand_card_def(0,use).value==4 and gs.valid_targets(0,Content.card_def("c61404")).has(enemy.uid), "言动增强与诳灭目标读取真实语罪记录")

	gs = fixture(GROVE_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	gs.VerifiedRules.PeachGrove.turn_start(gs,0)
	gs._resolve_resolution_stack()
	choose_word(gs,"sin-术")
	give(gs,"c61403")
	gs.current_player = 1
	gs.turn_counter += 1
	check(gs.play_card(1,give(gs,"c10301",1)) and gs.play_card(1,give(gs,"c12401",1)) and not p.has("wordTriggers"), "首张战斗牌不匹配，后续法术不能补触发")
	gs.turn_counter += 2
	check(gs.play_card(1,give(gs,"c12401",1)) and p.wordTriggers==1 and not p.hand.any(func(c):return c.definitionId=="c61403"), "下一回合首法术触发独立的诳默响应")

	gs = fixture(["yanling", "guniao-yuxiang", "taohua-luoying", "xiaoxiuzhishou"])
	p = gs.player(0)
	e = gs.player(1)
	p.units[3].awakened = true
	check(action_ok(gs,"c61407"), "言归进入独立言现选择")
	choose_word(gs,"reveal-术")
	gs.current_player = 1
	gs.turn_counter += 1
	e.units[0].front = 1
	e.units[0].hp = 4
	check(gs.play_card(1,give(gs,"c12401",1)) and e.units[0].hp==0 and e.avatarHp==24 and not p.has("wordReveal"), "言现仅投射10点，贯通剩余6点，独立移除灵咒且不重复基础能力增伤")

func wings_petals() -> void:
	var gs := fixture(GROVE_TEAM)
	var p := gs.player(0)
	var e := gs.player(1)
	var bird: Dictionary = p.units[1]
	bird.front = 1
	gs.current_player = 1
	var hp: int = bird.hp
	check(gs.basic_attack(1,0) and bird.hp==hp and bird.front==0 and p.avatarHp==30, "基础玉响回准备区并取消攻击，不转打牌手")
	gs.current_player = 0
	p.attackUsed = false
	gs.turn_counter += 1
	e.units[0].front = 0
	check(action_ok(gs,"c61005") and gs.VerifiedRules.HairPower.guard_count(gs,0)>0, "送子歌实际生成坚守")
	var old: int = e.avatarHp
	check(gs.basic_attack(0,1,bird.uid) and e.avatarHp<old and gs.VerifiedRules.HairPower.amount(bird)>0, "送子歌坚守出击打脸并保留战力")
	give(gs,"c61004")
	gs.current_player = 1
	gs.turn_counter += 1
	old = e.avatarHp
	check(gs.end_turn(1) and e.avatarHp==old-7 and p.hand.all(func(c):return c.definitionId!="c61004"), "敌方回合结束后，战力存在才实际响应燕返并获得+2力量")

	gs = fixture(GROVE_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	var ally: Dictionary = p.units[3]
	var idx := give(gs,"c61201")
	var inst: Dictionary = p.hand[idx]
	var cast := gs.play_card(0,idx,ally.uid)
	var returned: int = p.hand.find_custom(func(c):return c.instanceId==inst.instanceId)
	check(cast and returned>=0 and p.hand[returned].get("petalBounced",false), "廿四风首次用后同一实例弹回")
	check(gs.play_card(0,returned,ally.uid) and p.hand.all(func(c):return c.instanceId!=inst.instanceId) and ally.battlePower==2, "第二次用后不会无限弹回")
	var hp_before: int = ally.hp
	gs._damage_unit(0,3,1,1)
	check(ally.hp==hp_before, "有战力时坚毅减免单次伤害")
	check(action_ok(gs,"c61203") and ally.get("inspired",false) and ally.get("battlePower",0)==4, "桃花雨对全体加战力，阈值单位昂扬")
	check(action_ok(gs,"c61208"), "落英觉醒")
	ally.front = 1
	gs._damage_unit(0,3,12,1)
	check(ally.hp==hp_before and not gs.VerifiedRules.Panguan.destroy(gs,1,0,0,3), "觉醒战斗区有战力时免伤及直接消灭")
	ally.front = 0
	check(gs.VerifiedRules.Panguan.destroy(gs,1,0,0,3), "同一式神回到准备区失去免消灭")
	check(action_ok(gs,"c61206") and p.hand.any(func(c):return c.definitionId=="fallpetal-bloom"), "归风灼华加入实际灼华")
	var bloom: int = p.hand.find_custom(func(c):return c.definitionId=="fallpetal-bloom")
	check(gs.play_card(0,bloom,ally.uid) and ally.hp>0 and ally.front==1, "灼华选择气绝目标实际复活后出击")

	gs = fixture(GROVE_TEAM)
	p = gs.player(0)
	e = gs.player(1)
	ally = p.units[3]
	ally.level = 0
	check(action_ok(gs, "c61205", ally.uid) and ally.battlePower == 3, "桃利舞可以给0勾友方积累实际战力")
	check(action_ok(gs, "c61203") and ally.get("inspired", false) and ally.battlePower == 5 and not p.units[1].get("inspired", false), "桃花雨先统一给战力，再给达到阈值的式神昂扬")
	ally.level = 1
	check(gs.VerifiedRules.Combat.has(ally, "inspired"), "0勾取得的昂扬在激活后可正常使用")

	gs = fixture(GROVE_TEAM, ["guniao-yuxiang", "bingyong", "xuenv", "yaodaoji"])
	p = gs.player(0)
	e = gs.player(1)
	e.units[0].front = 1
	var crane := give(gs, "c61007")
	var legal := gs.can_play_card(0, crane)
	check(legal.ok and gs.play_card(0, crane), "鹤守上场 · " + str(legal.get("reason", "")))
	check(gs.basic_attack(0, 3) and e.units[0].front == 0 and gs.VerifiedRules.HairPower.guard_count(gs, 0) == 1, "盟友出击被玉响取消攻击，鹤守仍监听已完成的出击")
	var baseline: int = gs.rule_events.size()
	check(action_ok(gs, "c10101"), "使用其他己方式神战斗牌")
	var combat_at := -1
	var guard_at := -1
	for i in range(baseline, gs.rule_events.size()):
		var event: Dictionary = gs.rule_events[i]
		if event.kind == "combat-hit": combat_at = i
		if event.kind == "guard-gained": guard_at = i
	check(combat_at >= 0 and guard_at > combat_at and gs.VerifiedRules.HairPower.guard_count(gs, 0) == 2, "鹤守坚守在战斗牌实际结算后，只生成一次")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = viewport
		var b := Battle.new()
		b.setup(GROVE_TEAM, RIVAL_TEAM, 614)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		if not gs.pending_choice.is_empty():
			var opening := choice_face(b,"sin-形")
			if opening != null: await click(opening)
			await settled(b)
		hand(b,["c61407"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var tile := choice_face(b,"reveal-术")
		check(tile!=null,"实际鼠标打开三项言现卡片")
		if tile!=null: await click(tile)
		await settled(b)
		check(gs.player(0).get("wordReveal")=="术" and gs.pending_choice.is_empty(),"真实鼠标确认己方隐藏灵咒")
		var ally: Dictionary = gs.player(0).units[3]
		ally.level = 0
		hand(b, ["c61205"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).has(ally.uid), "真实鼠标可用桃利舞选取0勾友方式神")
		await click(b._unit_widget(str(ally.uid)))
		await settled(b)
		check(ally.get("battlePower", 0) == 3 and gs.player(0).hand.any(func(i): return i.definitionId == "fallpetal-wind"), "点击合法目标后得到实际战力和归风")
		b.queue_free()
		await process_frame

		b = Battle.new()
		b.setup(["kongquemingwang", "ji", "panguan-xuanmo", "guishibai"], RIVAL_TEAM, 60507)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		gs = b.gs
		prepare(gs)
		var p := gs.player(0)
		var foe := gs.player(1)
		p.units[0].level = 1
		for u in foe.units: u.front = 0
		hand(b, ["c60507"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).has("avatar-1"), "鼠标选择荆棘舞戏法时显示空战线牌手目标")
		var hp: int = foe.avatarHp
		await click(b._enemy_target_btn)
		await settled(b)
		check(foe.avatarHp == hp - 4 and b._pending_target_card == -1, "鼠标点击敌方牌手完成戏法追猎")
		p.units[0].level = 3
		foe.units[0].movementVeil = true
		var rival: Dictionary = foe.units[1]
		rival.level = 0
		hand(b, ["c60506"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and not gs.valid_targets(0,b._pending_target_card_def).has(foe.units[0].uid) and gs.valid_targets(0,b._pending_target_card_def).has(rival.uid), "鼠标目标范围排除移动帷幕并保留零勾式神")
		await click(b._unit_widget(str(rival.uid)))
		await settled(b)
		check(rival.armorBreak == 3 and int(foe.units[0].armorBreak) == 0, "真实点击后减力与破甲仅作用所选式神")
		var corpse: Dictionary = p.units[1]
		gs._knockout_unit(corpse)
		gs._resolve_resolution_stack()
		hand(b, ["c62706"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def) == [corpse.uid], "鼠标点灯人仅可选择能复活的气绝友方")
		await click(b._unit_widget(str(corpse.uid)))
		await settled(b)
		check(corpse.hp > 0 and p.units[3].form.get("cardId") == "c62706", "鼠标选择真实目标后点灯人完成复活")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	cards()
	peacock()
	seasons()
	inkjudge()
	words()
	wings_petals()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("DUSK_GROVE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
