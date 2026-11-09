extends "res://scripts/verify_insight.gd"

const Core := ["yimulian-linglai", "shantu-zuofu", "maochuan", "youning"]
const Sage := ["shenqilou", "maochuan", "youning", "yimulian-linglai"]
const Masks := ["mianqiling-xinsu", "maochuan", "youning", "shantong"]
const Opponent := ["bingyong", "bailang", "yaohu", "hetong"]

func fixture(lineup: Array = Core) -> GS:
	var gs := GS.create(lineup, Opponent, 296139)
	prepare(gs)
	for side in gs.players:
		for u in side.units: u.front = 0
	return gs

func index_for(gs, side: int, id: String) -> int:
	return gs.player(side).hand.find_custom(func(inst): return inst.definitionId == id)

func finish_choices(gs) -> void:
	for step in 12:
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, int(gs.pending_choice.playerIndex)), "AI resolves native choice")
		elif not gs.response_window.is_empty():
			check(gs.pass_response(int(gs.response_window.playerIndex)), "response continuation")
		else: break
	check(gs.pending_choice.is_empty() and gs.response_window.is_empty(), "resolution fully settled")

func ordinary_summon(gs: GS, owner: int, in_front: bool = false) -> Dictionary:
	var p := gs.player(owner)
	var token := gs._make_unit(str(p.id), "yingcao")
	token.uid = "%s:ordinary-summon" % p.id
	token.summoned = true
	token.level = 1
	token.front = int(in_front)
	p.units.append(token)
	return token

func catalog() -> void:
	for role in [298, 613, 616, 629, 639, 640]:
		for i in range(1, 9):
			var id := "c%d" % (role*100+i)
			var gs := fixture(Sage if role == 298 else Masks if role == 629 else Core)
			var c := Content.card_def(id)
			check(c.get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "source and native data "+id)
			var h := give(gs, id)
			var foe := gs.player(1)
			if role == 613 and i in [1, 3, 6, 8]: foe.units[0].front = 1
			if role == 298 and i == 7:
				check(not gs.can_play_card(0, h).ok, "万阵破不能手动使用")
				turn(gs, 0)
				check(gs.play_card(1, give(gs, "c10301", 1)) and gs.rule_events.any(func(e): return e.kind == "card-nullified" and e.card.id == "c10301"), "万阵破实际反制手牌")
				continue
			var view := gs.hand_card_def(0, h)
			var chosen = null
			if view.target != "auto":
				var possible := gs.valid_targets(0, view)
				check(not possible.is_empty(), "legal original target "+id)
				if possible.is_empty(): continue
				chosen = possible[0]
			var legal := gs.can_play_card(0, h, chosen)
			check(legal.ok, "normal action "+id+" "+str(legal.get("reason", "")))
			if legal.ok: check(gs.play_card(0, h, chosen), "plays real instance "+id)
			finish_choices(gs)

func wind_and_dice() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var wind: Dictionary = p.units[0]
	var target: Dictionary = foe.units[0]
	target.hp = 9
	target.front = 1
	play(gs, "c61301")
	check(target.frozen > 0 and wind.form.get("cardId") == "fengfushou" and wind.maxHp == 6, "风止实际战伤眩晕触发守形态")
	play(gs, "c61305")
	check(wind.awakened and gs.VerifiedRules.HairPower.guard_count(gs, 0) > 0, "替换已有形态时获得真实坚守")
	play(gs, "c61307")
	check(wind.formRules.get("substitute", false) and wind.formRules.get("windGuardCrit", false), "风神之佑永久强化守")
	gs._knockout_unit(wind)
	gs._resolve_resolution_stack()
	check(wind.hp > 0 and wind.form.is_empty(), "守替身按原生替身离场")

	gs = fixture()
	p = gs.player(0)
	foe = gs.player(1)
	var duo: Dictionary = p.units[1]
	for n in 4: gs.VerifiedRules.Light.roll(gs, 0, 1)
	var h := index_for(gs, 0, "ruyishaizi")
	check(h >= 0, "四次实际运势获得骰子")
	var die: Dictionary = p.hand[h]
	die.duoFace = 6
	check(gs.play_card(0, h, duo.uid) and duo.duoFixedRoll == 6, "实际骰子结附指定点数")
	gs.VerifiedRules.Light.roll(gs, 0, 1, 6, 1)
	check(int(gs.kw_usage(0, "fortune").last.roll) == 6 and not duo.has("duoFixedRoll"), "骰子改写对应角色的下一次成功结果")
	p.duoFixedRoll = 5
	var before: int = p.hand.size()
	play(gs, "c61608")
	check(p.realms[0].hp == 6 and p.hand.size() >= before+2, "六曜五点实际得火和抽牌，另生成骰子")
	check(not gs.can_play_card(0, give(gs, "c61608")).ok, "六曜唯一")
	duo.level = 1
	h = give(gs, "c61602")
	check(gs.hand_card_def(0, h).effect == "duo-die" and gs.play_card(0, h, "avatar-0") and int(p.duoFixedRoll) == 0, "圆月之时低勾使用零点戏法")
	duo.level = 3
	duo.front = 1
	foe.units[0].duoFixedRoll = 0
	play(gs, "c61604", foe.units[0].uid)
	check(duo.front == 1, "鼠鼠绳令已在战斗区的式神留在原处")

func scrolls() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var cat: Dictionary = p.units[2]
	var their_health: int = foe.avatarHp
	var other: Dictionary = p.units[0]
	p.initialDeckNames = [Content.card_def("c63901").name]
	play(gs, "c63901")
	check(foe.avatarHp == their_health - 5 and index_for(gs, 0, "maochuan-cooperate") >= 0, "真实先攻战斗、首用投射、代价实例")
	play(gs, "c63901")
	check(foe.avatarHp == their_health-9, "同名二次使用无首用投射")
	check(gs.play_card(0, give(gs, "c63904"), other.uid) and not gs.can_play_card(0, give(gs, "c63904"), other.uid).ok, "投资只可选本回合尚未攻击的单位")
	play(gs, "c63905")
	check(gs.pending_choice.get("type") == "lineage-contract" and gs.resolve_divination_choice(0, "contract") and cat.awakened and cat.catContract, "明确契约选项并保存觉醒")
	cat.level = 2
	var h := give(gs, "c63907")
	check(gs.hand_card_def(0, h).id == "maochuan-monopoly", "低勾垄断显示实际代价")
	cat.level = 3
	check(gs.hand_card_def(0, h).id == "c63907", "三勾恢复原牌")
	gs = fixture()
	p = gs.player(0)
	cat = p.units[2]
	give(gs, "maochuan-inflate")
	turn(gs, 0)
	check(p.avatarArmorBreak == 2 and int(cat.armorBreak) == 0 and gs.kw_usage(0, "encourage").battlePower == -2, "留手惩罚对牌手施加两点脆弱与力不足")

	gs = fixture()
	p = gs.player(0)
	foe = gs.player(1)
	var poet: Dictionary = p.units[3]
	p.initialDeckNames = [Content.card_def("c64005").name]
	var target: Dictionary = foe.units[0]
	h = give(gs, "c64005")
	check(int(gs.hand_card_def(0, h).value) == 5, "同名初始卡用原始伤害")
	p.initialDeckNames = []
	check(int(gs.hand_card_def(0, h).value) == 7, "牌名未在初始牌库用增强")
	play(gs, "c64002", p.units[0].uid)
	var old_uid: String = p.units[0].uid
	var picked: String = gs.pending_choice.instanceIds[0]
	check(gs.resolve_divination_choice(0, picked) and p.units[0].id == picked and p.units[0].uid == old_uid, "换将修改真实身份而保留位置")
	p.hand.clear()
	h = give(gs, "youning-six-meanings")
	check(gs.play_card(0, h) and gs.resolve_divination_choice(0, "fire"), "诗六义第一次选择")
	check(not gs.resolve_divination_choice(0, "fire") and gs.resolve_divination_choice(0, "all"), "诗六义选项不能重复")
	check(gs.resolve_divination_choice(0, "draw") and gs.pending_choice.is_empty(), "诗六义共三次选择")
	check(poet.id == "youning" and target.hp <= int(target.maxHp)-2, "诗六义对实际单位造成伤害")
	p.energy = 0
	Insight.enter(gs, 0)
	check(gs.play_card(0, zone_index(gs, Insight.STAR), "avatar-1") and not p.has("poetNextFreeTurn"), "诗六义节火被下一张启悟牌真实消费")
	gs = fixture()
	p = gs.player(0)
	gs._apply_form(0, 0, Content.card_def("fengfushou"), {"attack": 3, "hp": 6, "setBase": true})
	p.poetNextFreeTurn = gs.turn_counter
	p.energy = 0
	h = give(gs, "c61304")
	check(gs.play_card(0, h, null, true) and not p.has("poetNextFreeTurn"), "诗六义节火同样可用于起源选择")

func factions() -> void:
	var gs := fixture(Sage)
	var p := gs.player(0)
	var foe := gs.player(1)
	var ally: Dictionary = p.units[1]
	ally.level = 2
	gs.raise_unit_level(0, 1)
	check(index_for(gs, 0, "tower-green") >= 0, "实际升勾按派系生成百识")
	p.hand.clear()
	give(gs, "tower-red")
	give(gs, "tower-blue")
	foe.units[0].hp = 9
	foe.units[0].front = 1
	play(gs, "c29801")
	check(index_for(gs, 0, "tower-red") < 0 and index_for(gs, 0, "tower-blue") < 0 and foe.units[0].frozen > 0 and foe.units[0].hp == 4, "弃置两张真实百识分别强化战斗")
	var h := give(gs, "c29803")
	check(int(gs.hand_card_def(0, h).value) == 5, "印按已弃百识种类计数")
	p.units[0].spellPower = 2
	check(int(gs.hand_card_def(0, h).value) == 7, "印的伤害预览包含法强")
	var untouched: Dictionary = foe.units[1]
	untouched.hp = 12
	give(gs, "tower-red")
	play(gs, "c29804")
	check(untouched.hp == 9, "真伪莫辨的红莲全体伤害包含法强")
	p.units[0].front = 1
	give(gs, "tower-purple")
	play(gs, "c29805")
	check(p.units[0].front == 1, "已有战斗区位置时百识形态不撤回准备区")
	play(gs, "c29808")
	var before: int = ally.attack
	check(gs.play_card(0, give(gs, "tower-red"), ally.uid) and int(ally.attack) == before+4, "胧月夜实际四倍")
	check(gs.play_card(0, give(gs, "tower-red"), ally.uid) and int(ally.attack) == before+5, "同回合第二张百识正常")
	play(gs, "tower-power-blue")
	turn(gs, 0)
	check(gs.current_player == 0 and gs.pending_choice.get("type") == "tower-sage-choice", "青岚之力给真实额外回合和觉醒选择")
	finish_choices(gs)
	gs = fixture(Sage)
	p = gs.player(0)
	p.restoredDrawCount = 0
	gs._draw(0, 3)
	give(gs, "tower-blue")
	play(gs, "c29806")
	check(gs.front_unit(0).get("id") == "tower-shadow" and gs.front_unit(0).attack == 6, "影按本回合实际五次抽牌增加身材")
	var own: Dictionary = p.units[1]
	var hp: int = own.hp
	h = give(gs, "tower-green")
	check(not gs.can_play_card(0, h, "avatar-1").ok and gs.play_card(0, h, own.uid) and own.hp == hp-1, "百识苍叶可指定己方式神且拒绝牌手")

	gs = fixture(Masks)
	p = gs.player(0)
	play(gs, "c62903")
	check(gs.resolve_divination_choice(0, "苍叶") and p.units[0].formRules.maskFacing == "苍叶", "四相选择真实形态能力")
	h = give(gs, "c63901")
	check(gs._kw(gs.hand_card_def(0, h), "instant"), "苍叶面实际提供瞬发")
	turn(gs, 0)
	turn(gs, 1)
	check(p.units[0].formRules.maskFacing == "青岚", "四相正确轮换")
	check(not Content.lineup_rule_error(["mianqiling-xinsu", "shenqilou", "bailang", "yaohu"]).is_empty(), "心宿不能与无相同队")

func scope_and_timing() -> void:
	var gs := fixture(Sage)
	var p := gs.player(0)
	give(gs, "tower-blue")
	give(gs, "c29807")
	turn(gs, 0)
	gs.player(1).towerExtraTurns = 1
	check(gs.play_card(1, give(gs, "c10301", 1)) and p.get("towerInstantPending", false), "万阵破的青岚增强等到下个实际己方回合")
	var mark := give(gs, "c29803")
	turn(gs, 1)
	check(gs.current_player == 1 and not gs._kw(gs.hand_card_def(0, mark), "instant"), "敌方获得额外回合时不会提前取得瞬发")
	turn(gs, 1)
	check(gs.current_player == 0 and gs._kw(gs.hand_card_def(0, mark), "instant"), "进入真正的己方回合才取得瞬发")

	gs = fixture()
	var summon := ordinary_summon(gs, 1, true)
	play(gs, "c61303")
	check(summon.frozen == 0 and gs.player(0).units[0].form.is_empty(), "风息之森进场不眩晕普通召唤物")
	play(gs, "c61607")
	var duo: Dictionary = gs.player(0).units[1]
	var attack_frame := {"playerIndex": 1, "sourceIndex": gs.player(1).units.find(summon), "options": {}}
	gs.VerifiedRules.FortunateDuo.before_attack(gs, attack_frame)
	check(not duo.has("duoPeaceEnemyTurn"), "出入平安不因普通召唤物的攻击消耗敌方次数")
	attack_frame = {"playerIndex": 1, "sourceIndex": 0, "options": {}}
	gs.VerifiedRules.FortunateDuo.before_attack(gs, attack_frame)
	check(duo.get("duoPeaceEnemyTurn", -1) == gs.turn_counter, "出入平安响应真实的敌方式神攻击")

	gs = fixture(Masks)
	summon = ordinary_summon(gs, 1)
	var foe: Dictionary = gs.player(1).units[0]
	foe.level = 0
	var destroy := give(gs, "c62907")
	check(not gs.can_play_card(0, destroy, summon.uid).ok and gs.can_play_card(0, destroy, foe.uid).ok, "母亲面具排除普通召唤物并接受零勾存活式神")
	check(gs.play_card(0, destroy, foe.uid) and foe.hp == 0 and summon.hp > 0, "母亲面具实际消灭所选式神")

	for position in ["reserve", "front", "summon"]:
		gs = fixture()
		foe = ordinary_summon(gs, 1, true) if position == "summon" else gs.player(1).units[0]
		foe.hp = 30
		foe.attack = 0
		foe.front = int(position != "reserve")
		play(gs, "c63906", foe.uid)
		var cat_uid: String = gs.player(0).units[2].uid
		var hits := gs.rule_events.filter(func(e): return e.kind == "combat-damage-resolved" and e.uid == cat_uid and e.target == foe.uid)
		check(hits.size() == (2 if position == "front" else 1), "膨胀卷轴只在实际交战的敌方式神位于战斗区时连击 " + position)

	gs = fixture()
	summon = ordinary_summon(gs, 1, true)
	var hp := int(summon.hp)
	play(gs, "youning-six-meanings")
	check(gs.resolve_divination_choice(0, "all") and summon.hp == hp-2, "诗六义的全体敌方角色伤害包括普通召唤物")
	check(gs.resolve_divination_choice(0, "front") and summon.hp == hp-2, "诗六义仅指定战斗区式神的伤害排除普通召唤物")
	finish_choices(gs)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = viewport
		var b := Battle.new()
		b.setup(Masks, Opponent, 629)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		prepare(b.gs)
		hand(b, ["c62903"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var face := choice_face(b, "苍叶")
		check(face != null, "实际鼠标打开四相选项")
		if face != null: await click(face)
		await settled(b)
		check(b.gs.player(0).units[0].get("formRules", {}).get("maskFacing") == "苍叶", "界面选择写入真实派系")
		var target: Dictionary = b.gs.player(1).units[0]
		target.level = 0
		hand(b, ["c62907"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		await click(b._unit_widget(target.uid))
		await settled(b)
		check(target.hp == 0, "母亲面具可用鼠标选中实际存活的零勾式神 " + str(viewport))
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	catalog()
	wind_and_dice()
	scrolls()
	factions()
	scope_and_timing()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("SCROLL_WIND_FACTION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
