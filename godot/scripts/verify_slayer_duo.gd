extends "res://scripts/verify_serpent_ghost.gd"

const TEAM := ["tanjirou", "guishiheibai", "taohuayao", "bingyong"]
const FOE := ["bingyong", "shantong", "bailang", "hetong"]
const PRINTED := ["c18201", "c18202", "c18203", "c18204", "c18205", "c18206", "c18208", "c18209"]

func card_entries() -> void:
	for i in PRINTED.size():
		var id: String = PRINTED[i]
		var gs := game(TEAM)
		var body: Dictionary = gs.player(0).units[0]
		check(Content.card_def(id).get("verifiedRules", false) and ResourceLoader.exists("res://assets/official/cards/%s.png" % id), "原版牌和牌图 " + id)
		var legacy := Content.card_def("c1829%d" % (i+1))
		check(legacy.get("slayerSourceCard") == id and legacy.name == Content.card_def(id).name.replace("/", "／"), "旧 ID 读取同一原版牌 " + id)
		if id == "c18202": SG.switch_ghost(gs, 0, 0, true)
		play(gs, id)
	check(not Content.lineup_rule_error(["tanjirou", "nezuko", "bingyong", "bailang"]).is_empty(), "同一个原版式神位不能重复占位")
	var old_lineup := ["nezuko", "bingyong", "tanjirou", "bailang"]
	var repaired := Content.restore_legacy_lineup(old_lineup)
	check(Content.valid_lineup(repaired) and repaired[0] == "nezuko" and repaired[1] == "bingyong" and repaired[3] == "bailang" and old_lineup[2] == "tanjirou", "读旧双入口阵容时仅替换重复位")
	var two_pairs := ["nezuko", "maozhanggui-huanyan", "tanjirou", "maozhanggui"]
	var repaired_pairs := Content.restore_legacy_lineup(two_pairs)
	check(Content.valid_lineup(repaired_pairs) and repaired_pairs.slice(0, 2) == two_pairs.slice(0, 2), "旧阵容有两个冲突时同时保留两个靠前的式神")
	check(Content.valid_lineup(Content.recommended_lineup("wave10")), "联动秘卷快速推荐可直接开局")
	var old := game(["nezuko", "bingyong", "taohuayao", "shantong"])
	check(old.player(0).units[0].name == "炭治郎" and Content.starter_card_ids("nezuko").size() == 8, "旧阵容入口仍能读取八张牌并从炭治郎开局")
	play(old, "c18295")
	check(old.player(0).units[0].id == "nezuko" and old.player(0).units[0].name == "祢豆子", "旧卡实例走真实切换且保留存档式神 ID")

func dual_body() -> void:
	var gs := game(TEAM)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	var uid: String = u.uid
	var join := give(gs, "c18202")
	check(u.name == "炭治郎" and u.attack == 3 and u.maxHp == 4 and not gs.can_play_card(0, join).ok, "炭治郎基础 3/4 且不能用兄妹之绊")
	check(not AI._best_card(gs, 0).ok, "AI 不会尝试当前身份不可用的兄妹之绊")
	u.charge = 2
	gs._damage_unit(0, 0, 5, 1, 0)
	gs._resolve_resolution_stack()
	check(u.name == "祢豆子" and u.uid == uid and u.baseAttack == 2 and u.maxHp == 6 and u.charge == 0, "致死伤害消耗两点能量，原式神位切换为 2/6 祢豆子")
	check(not gs.VerifiedRules.SunSmoke.has_charge(u) and u.sgWhiteCountdown == 2, "祢豆子没有充能，倒计时为二")
	var pick := AI._best_card(gs, 0)
	check(pick.ok and pick.hand == join and gs.can_play_card(0, pick.hand, pick.target, pick.origin).ok, "AI 能在正确身份选择兄妹之绊")
	check(gs.play_card(0, join) and u.name == "炭治郎" and u.sgBlackSwitches == 1 and u.front == 1, "兄妹之绊切回并真实发起攻击")
	var foe: Dictionary = gs.player(1).units[0]
	tough(foe, 40, 0)
	foe.front = 1
	u.charge = 2
	var burst := give(gs, "c18201")
	check(gs.VerifiedRules.Movement.request_burst(gs, 0, burst) and gs.resolve_divination_choice(0, "burst:2"), "壹之型能选择两点爆能")
	foe.shield = 9
	var energy: int = p.energy
	check(gs.play_card(0, burst) and u.charge == 0 and p.energy == energy and foe.hp == 36, "壹之型实际扣能量、瞬发并穿刺护甲")

	gs = game(TEAM)
	p = gs.player(0)
	u = p.units[0]
	u.charge = 1
	gs._damage_unit(0, 0, 5, 1, 0)
	gs._resolve_resolution_stack()
	check(u.hp == 0 and u.knockout > 0 and u.name == "炭治郎", "能量不足则正常气绝")

func transformations_and_combat() -> void:
	var gs := game(TEAM)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	play(gs, "c18204")
	var second := give(gs, "c18204")
	check(u.swift and gs.hand_card_def(0, second).id == "sg-slayer-awaken" and not gs.can_play_card(0, second).ok, "觉醒更新同名牌投影，炭治郎获得迅捷，不能施放祢豆子派生")
	check(not p.get("sgGhostAwakeningChanged", false) and not p.units[1].awakened, "同队鬼使黑的觉醒状态独立")
	SG.switch_ghost(gs, 0, 0, true)
	check(gs.play_card(0, second) and u.unyielding and u.sgWhiteCountdown == 1, "派生觉醒真实赋予不屈和倒计时一")
	var foe: Dictionary = gs.player(1).units[0]
	tough(foe, 50, 0)
	foe.front = 1
	gs._damage_unit(0, 0, 2, 1, 0)
	gs._resolve_resolution_stack()
	check(foe.hp == 48, "受到两点伤害后爆血投射等量伤害")
	gs._damage_unit(0, 0, 1, 1, 0)
	gs._resolve_resolution_stack()
	check(foe.hp == 48, "同回合爆血只能自动触发一次")
	turn(gs)
	turn(gs)
	check(u.name == "炭治郎" and u.swift and u.sgBlackSwitches == 1, "下次己方回合切回炭治郎并重新获得迅捷")

	gs = game(TEAM)
	p = gs.player(0)
	u = p.units[0]
	foe = gs.player(1).units[0]
	tough(foe, 50, 0)
	u.front = 1
	give(gs, "c18205")
	gs.current_player = 1
	check(gs.basic_attack(1, 0) and u.name == "祢豆子" and u.attack == 5 and u.maxHp == 7 and u.sgWhiteCountdown == 1 and p.hand.is_empty(), "敌方真实攻击自动响应破箱而出")

	gs = game(TEAM)
	p = gs.player(0)
	u = p.units[0]
	for i in 2:
		SG.switch_ghost(gs, 0, 0, true)
		play(gs, "c18202")
	var hp: int = gs.player(1).avatarHp
	play(gs, "c18206")
	check(gs.player(1).avatarHp == hp-12 and gs.resolution_stack.is_empty(), "生生流转按两次回归复制，三段攻击依次 3、4、5")
	play(gs, "c18208")
	u.charge = 3
	turn(gs)
	check(u.name == "祢豆子" and u.shield == 3, "火之神神乐在回合结束切换并按能量授予护甲")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for size in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = size
		var board := Battle.new()
		board.setup(TEAM, FOE, 182)
		board._ai_thinking = true
		var gs := board.gs
		for side in gs.players:
			side.hand.clear()
			side.energy = 10
			side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(board)
		await create_timer(0.4).timeout
		hand(board, ["c18205"])
		await settled(board)
		await click(board._hand_row.get_child(0))
		await settled(board)
		check(gs.player(0).units[0].name == "祢豆子", "点击破箱而出更新真实战场身份")
		hand(board, ["c18202"])
		await settled(board)
		await click(board._hand_row.get_child(0))
		await settled(board)
		check(gs.player(0).units[0].name == "炭治郎", "点击兄妹之绊切回同一个式神位")
		board.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	card_entries()
	dual_body()
	transformations_and_combat()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("SLAYER_DUO checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
