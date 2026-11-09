extends "res://scripts/verify_serpent_ghost.gd"

const TEAM := ["tiaotiaogege", "tiaotiaodidi", "tiaotiaomeimei", "bingyong"]
const FOE := ["bailang", "xuenv", "shantong", "hetong"]

func delay_and_countdown() -> void:
	var gs := game(TEAM)
	var owner := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = owner.units[0]
	var hp: int = foe.avatarHp
	gs._apply_encourage(0, 2, 1)
	check(gs.basic_attack(0, 0) and u.jumpSlow.remaining == 2 and foe.avatarHp == hp and u.front == 0, "普通出击先结附迟钝，保留战斗参数")
	check(not gs.can_play_card(0, give(gs, "c18302")).ok and gs.VerifiedRules.Stun.count(gs, 0) == 1, "迟钝期间是实际眩晕")
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 1)
	gs._resolve_resolution_stack()
	check(u.jumpSlow.remaining == 1 and foe.avatarHp == hp, "倒计时一仍无攻击")
	gs.VerifiedRules.reduce_countdown(gs, 0, 0, 1)
	gs._resolve_resolution_stack()
	check(not u.has("jumpSlow") and u.front == 1 and foe.avatarHp == hp-6 and u.shield == 1, "迟钝到零后结算真实攻击及原鼓舞")

	gs = game(TEAM)
	owner = gs.player(0)
	foe = gs.player(1)
	u = owner.units[0]
	play(gs, "c18302")
	play(gs, "c18301")
	check(u.jumpSlow.coffinStrike and u.attack == 5, "棺击在真实迟钝窗口留下成长触发")
	gs._knockout_unit(foe.units[0], 0, 1)
	gs._resolve_resolution_stack()
	check(u.attack == 6 and u.maxHp == 8 and u.jumpSlow.remaining == 1, "其他式神气绝，棺击成长与集煞阵减时共同生效")
	gs._knockout_unit(owner.units[1], 1, 1)
	gs._resolve_resolution_stack()
	check(u.attack == 7 and not u.has("jumpSlow") and foe.avatarHp == 23, "另一侧式神气绝也会推倒计时并攻击")
	play(gs, "c18308")
	check(u.awakened and u.attack == 17 and u.maxHp == 19, "觉醒实际增加十力量十生命")

func transformations() -> void:
	var gs := game(TEAM)
	var owner := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = owner.units[0]
	var ally: Dictionary = owner.units[1]
	var uid: String = ally.uid
	var i := give(gs, "c18304")
	check(not gs.can_play_card(0, i).ok, "死而复生拒绝空候选")
	play(gs, "c18303", ally.uid)
	gs._knockout_unit(ally, 1, 0)
	gs._resolve_resolution_stack()
	check(ally.uid == uid and ally.hp == 3 and ally.name == "棺材" and not gs.can_basic_attack(0, 1).ok, "不弃同回合气绝后真变为不能攻击的 0/3 棺材")
	gs.VerifiedRules.reduce_countdown(gs, 0, 1, 1)
	gs._resolve_resolution_stack()
	check(not ally.has("jumpCoffin") and ally.uid == uid and ally.hp == ally.maxHp and ally.front == 1, "倒计时复活原弟弟并发起攻击")
	gs._knockout_unit(owner.units[2], 1, 0)
	gs._knockout_unit(u, 1, 0)
	gs._resolve_resolution_stack()
	check(gs.play_card(0, i) and u.name == "棺材" and owner.units[2].name == "棺材", "哥哥气绝仍可将所有气绝己方式神化为棺材")
	gs._damage_unit(0, 2, 4, 1, 1)
	gs._resolve_resolution_stack()
	check(owner.units[2].name == "跳跳妹妹" and owner.units[2].hp == 0 and owner.units[2].knockout == 3, "棺材被打碎后回到原角色的三回合气绝")

	gs = game(TEAM)
	owner = gs.player(0)
	foe = gs.player(1)
	u = owner.units[0]
	play(gs, "c18306", foe.units[0].uid)
	check(foe.units[0].name == "棺材" and foe.units[0].hp == 3, "棺封消灭对方非召唤式神并置换")
	play(gs, "c18305")
	gs._knockout_unit(u, 1, 1)
	gs._resolve_resolution_stack()
	check(u.name == "棺材", "罡身阵在真实气绝时触发")

	gs = game(TEAM)
	owner = gs.player(0)
	u = owner.units[0]
	gs.current_player = 1
	give(gs, "c18303")
	gs._damage_unit(0, 0, 20, 1, 0)
	gs._resolve_resolution_stack()
	check(u.name == "棺材" and owner.hand.is_empty() and owner.energy == 39, "致死伤害前实际响应不弃并支付鬼火")

func aura_and_catalog() -> void:
	var gs := game(TEAM)
	var foe := gs.player(1)
	for n in range(1,9):
		var id := "c1830%d" % n
		var card := Content.card_def(id)
		check(card.get("verifiedRules", false) and ResourceLoader.exists("res://assets/official/cards/%s.png" % id), "核对国服主牌 %s" % id)
	play(gs, "c18307")
	var i := give(gs, "c18301")
	var pick := AI._best_card(gs, 0)
	check(pick.ok and gs.can_play_card(0, pick.hand, pick.target, pick.origin).ok and gs.play_card(0, i), "AI 能从真实合法牌和费用产生决策")
	var face_hp: int = foe.avatarHp
	var unit_hp: int = foe.units[2].hp
	turn(gs)
	check(foe.avatarHp == face_hp-1 and foe.units[2].hp == unit_hp-1, "敌方回合开始，释煞阵仍打到所有敌方角色")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for size in [Vector2i(1280,800), Vector2i(1600,740)]:
		root.size = size
		var board := Battle.new()
		board.setup(TEAM, FOE, 183)
		board._ai_thinking = true
		var gs := board.gs
		for side in gs.players:
			side.hand.clear()
			side.energy = 10
			side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(board)
		await create_timer(0.4).timeout
		hand(board, ["c18306"])
		await settled(board)
		await click(board._hand_row.get_child(0))
		check(board._pending_target_card == 0, "点击棺封进入真实目标界面")
		var target: Dictionary = gs.player(1).units[1]
		await click(board._unit_widget(str(target.uid)))
		await settled(board)
		check(target.name == "棺材" and board._unit_widget(str(target.uid)) != null, "点击敌方目标后战场更新棺材身份")
		board.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	delay_and_countdown()
	transformations()
	aura_and_catalog()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("COFFIN checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
