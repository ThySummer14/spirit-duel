extends "res://scripts/verify_serpent_ghost.gd"

const TEAM := ["sanmu", "taohuayao", "yaodaoji", "hetong"]
const FOE := ["bingyong", "taohuayao", "shantong", "bailang"]
const Commission := preload("res://scripts/commission_rules.gd")

func fixture(weekday: int = 3, opening: bool = false) -> GS:
	var gs := GS.create(TEAM, FOE, 185, {}, {}, opening, weekday)
	for side in gs.players:
		side.energy = 30
		side.levelUpUsed = true
		for u in side.units: u.level = 3
	return gs

func commissions() -> void:
	var gs := fixture(3, true)
	check(Commission.urgent_candidates(gs,0).is_empty() and gs.confirm_opening([]) and Commission.urgent_candidates(gs,0).size()==1, "确认起手后发放一次真实随机紧急委托")
	check(gs.snapshot().commissionDay == 3 and gs.command_log.back().c == "commission-calendar", "记录星期使对局选定后保持稳定")
	var p := gs.player(0)
	var foe := gs.player(1)
	var sanmu: Dictionary = p.units[0]
	p.hand.clear()
	var urgent := give(gs,"sanmu-urgent-3")
	var ticket: Dictionary = p.hand[urgent]
	check(not gs.can_play_card(0,urgent).ok and gs.hand_card_def(0,urgent).commissionRemaining==4, "紧急委托的原实例按实际进度锁定")
	play(gs,"c18503")
	check(ticket.commissionProgress==1, "己方实际用牌增加进度")
	gs.current_player=1
	play(gs,"c10302",null,1)
	check(ticket.commissionProgress==2, "多事多忙使敌方实际用牌推进条件")
	gs.current_player=0
	give(gs,"sanmu-urgent-4")
	play(gs,"c18501")
	check(gs.pending_choice.get("type")=="commission-ready" and not gs.resolve_divination_choice(1,ticket.instanceId), "真实手牌选择仅对己方开放")
	check(gs.resolve_divination_choice(0,ticket.instanceId) and ticket.commissionProgress==4, "委托整理指定并完成原实例条件")
	var before: int=sanmu.attack
	check(gs.play_card(0,p.hand.find(ticket)) and sanmu.attack==before+1 and int(p.commissionsUsed)==1 and Commission.urgent_candidates(gs,0).size()==2, "紧急委托永久成长、使用计数并生成下一张")

	gs=fixture()
	p=gs.player(0)
	p.hand.clear()
	var order := gs.VerifiedRules.Insight.instance(gs,0,"c18502")
	p.deck.append(order)
	for n in 5: play(gs,"c18503")
	check(order.commissionProgress==5,"日常委托在实际牌库中累计形态用牌")
	gs._draw(0,1)
	var selected := gs.hand_card_def(0,p.hand.find(order))
	var target: Dictionary=p.units[1]
	before=target.attack
	check(selected.id=="sanmu-daily-3" and gs.play_card(0,p.hand.find(order),target.uid) and target.attack==before+4,"周三投影并执行国服基础 +4/+4")
	for weekday in 7:
		gs=fixture(weekday)
		var h := give(gs,"c18502")
		var card := gs.hand_card_def(0,h)
		check(card.id=="sanmu-daily-%d" % Commission.DAILY[weekday] and not gs.can_play_card(0,h).ok,"星期 %d 映射实际独立条件" % weekday)

func daily_resolutions() -> void:
	for weekday in [1,2,4,5,6,0]:
		var gs:=fixture(weekday)
		var p:=gs.player(0)
		var foe:=gs.player(1)
		p.hand.clear()
		var h:=give(gs,"c18502")
		Commission.force_ready(gs,p.hand[h])
		var target=null
		if weekday==4: target="avatar-1"
		if weekday in [1,5]: foe.units[3].summoned = true
		if weekday==5:
			foe.units[0].level = 0
			target = foe.units[0].uid
			check(not gs.can_play_card(0, h, foe.units[3].uid).ok, "周五委托排除普通召唤物")
		if weekday==6:
			target=p.units[1].uid
			gs._knockout_unit(p.units[1],1,0)
			gs._resolve_resolution_stack()
			check(not gs.can_play_card(0,h,foe.units[0].uid).ok,"周六委托排除未气绝的敌方式神")
		var hp: int=foe.avatarHp
		check(gs.play_card(0,h,target),"星期 %d 的委托真实执行" % weekday)
		match weekday:
			1:
				check(foe.avatarHp==hp-3 and foe.units[2].hp==foe.units[2].maxHp-3,"周一全体非战斗伤害")
				check(foe.units[3].hp == foe.units[3].maxHp-3, "周一委托的敌方角色范围包含普通召唤物")
			2: check(foe.avatarHp==hp-5 and p.units[0].shield==3,"周二战斗牌 +3 力量和护甲")
			4: check(foe.avatarHp==hp-6,"周四实际目标受伤")
			5: check(foe.units[0].hp==0,"周五实际消灭式神")
			6: check(p.units[1].hp>0 and p.units[1].swift,"周六真实复活并获得迅捷")
			0: check(p.hand.size()==2,"周日抽两张真实牌")

func automatic_hand_play() -> void:
	var gs := GS.create(["sanmu", "xuan", "yaodaoji", "hetong"], FOE, 185, {}, {}, false, 3)
	var p := gs.player(0)
	p.hand.clear()
	p.energy = 12
	p.levelUpUsed = true
	p.units[0].level = 3
	p.units[1].level = 2
	play(gs, "w13-xuan-93130")
	var fire := int(p.energy)
	var urgent := give(gs, "sanmu-urgent-3")
	var ticket: Dictionary = p.hand[urgent]
	var star := give(gs, "xuan-star-might")
	var star_instance: Dictionary = p.hand[star]
	play(gs, "w13-xuan-93126")
	check(not p.hand.has(star_instance) and int(p.energy) == fire - 1, "星坠从真实手牌免费使用极星，只支付本牌费用")
	check(int(ticket.get("commissionProgress", 0)) == 2, "紧急委托分别计算星坠与实体极星，单独重复其效果不额外推进")

func clues_and_combat() -> void:
	var gs:=fixture()
	var p:=gs.player(0)
	var foe:=gs.player(1)
	var u: Dictionary=p.units[0]
	p.hand.clear()
	play(gs,"c18508")
	check(gs.pending_choice.instanceIds==["sanmu-clue-talk"] and gs.resolve_divination_choice(0,"sanmu-clue-talk"),"零委托只可选茶话")
	var clue: int=p.hand.find_custom(func(inst):return inst.definitionId=="sanmu-clue-talk")
	check(gs.play_card(0,clue),"茶话是实际独立手牌")
	p.avatarHp=25
	var order:=give(gs,"sanmu-urgent-2")
	Commission.force_ready(gs,p.hand[order])
	check(gs.hand_card_def(0,order).cost==0 and gs.play_card(0,order) and p.avatarHp==28,"觉醒免去委托鬼火，茶话按用牌治疗")
	p.commissionsUsed=10
	play(gs,"c18508")
	check("sanmu-clue-talk" not in gs.pending_choice.instanceIds and AI.take_action(gs,0) and gs.pending_choice.is_empty(),"再次觉醒排除已选线索，AI 合法选择判明")
	clue=p.hand.find_custom(func(inst):return inst.definitionId=="sanmu-clue-solve")
	check(gs.play_card(0,clue) and foe.avatarHp==0,"判明实际对敌方牌手造成30点伤害")

	gs=fixture()
	p=gs.player(0)
	foe=gs.player(1)
	u=p.units[0]
	tough(foe.units[0],30,40)
	foe.units[0].front=1
	play(gs,"c18504")
	check(foe.units[0].hp==25 and u.hp==5 and gs.resolution_stack.is_empty(),"五次实际攻击各一点并免除全部反击")
	play(gs,"c18506")
	gs._knockout_unit(u,1,0)
	gs._resolve_resolution_stack()
	check(u.hp==5 and u.form.is_empty(),"平和猫又屋在实际气绝后复活且形态消失")
	var target: Dictionary=p.units[1]
	play(gs,"c18505",target.uid)
	check(target.hp==1 and not target.unyielding,"扫除时间先赋不屈再造成10点真实伤害")
	p.commissionsUsed=5
	var before: int=u.attack
	play(gs,"c18507")
	check(u.attack==before+5,"蜃楼观光依据委托使用次数增强全队")

func ui_checks() -> void:
	root.theme=ThemeBuilder.build_theme()
	for size in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=size
		DisplayServer.window_set_size(size)
		var board:=Battle.new()
		board.setup(TEAM,FOE,185)
		board._ai_thinking=true
		var gs:=board.gs
		for side in gs.players:
			side.energy=10
			side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(board)
		await create_timer(0.4).timeout
		hand(board,["c18508"])
		await settled(board)
		await click(board._hand_row.get_child(0))
		await settled(board)
		var tile:=choice_face(board,"sanmu-clue-talk")
		check(tile!=null,"鼠标出牌打开线索的真实选项")
		if tile!=null: await click(tile)
		await settled(board)
		check(gs.player(0).hand.any(func(inst): return inst.definitionId=="sanmu-clue-talk"),"鼠标选中线索放入真实手牌")
		board.queue_free()
		await process_frame

func run() -> void:
	var stores:=Support.isolate_stores()
	commissions()
	daily_resolutions()
	automatic_hand_play()
	clues_and_combat()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("COMMISSION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
