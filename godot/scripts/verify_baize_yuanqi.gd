extends "res://scripts/verify_insight.gd"

const TEAM := ["baize-yuanqi", "bailang", "shantong", "hetong"]
const OTHER := ["yaohu", "yijin-zhentian", "tiaotiaodidi", "yaodaoji"]
const Y := preload("res://scripts/baize_yuanqi_rules.gd")
const F := preload("res://scripts/destiny_choice_rules.gd")
const D := preload("res://scripts/native_divination_rules.gd")

func id(n: int) -> String:
	return "w13-baize-yuanqi-%d" % (93108 + n)

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YUANQI_FAIL ", detail)

func fixture() -> GS:
	var gs := GS.create(TEAM, OTHER, 93109)
	prepare(gs)
	gs.phase = "main"
	gs.turn_counter = 13
	for side in gs.players:
		side.realms.clear()
		for u in side.units: u.front = 0
	return gs

func deck(gs, ids: Array) -> Array:
	return ids.map(func(card): return Insight.instance(gs, 0, card))

func put_deck(gs, ids: Array) -> Array:
	gs.player(0).deck = deck(gs, ids)
	return gs.player(0).deck.duplicate()

func choose_div(gs, inst: Dictionary, to: String) -> bool:
	return gs.resolve_divination_choice(0, inst.instanceId) and gs.resolve_divination_choice(0, to)

func catalog() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	check(u.attack == 2 and u.hp == 5 and gs.VerifiedRules.Factions.get_faction(u) == "青岚", "verified 2/5 and faction")
	check(Content.cards_for_unit(u.id).filter(func(c): return not c.token).size() == 8, "preserved eight collectible IDs")
	for n in range(1, 9):
		var card := Content.card_def(id(n))
		check(card.get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % card.id), "native card and original client image " + card.name)
	check(Content.card_def(Y.INSIGHT).token and Content.card_def(Y.CAUSAL).token and Y.CAUSAL not in Content.default_deck(TEAM).cardIds, "two derivatives outside deck builder")

func divination_and_blessing() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var instances := put_deck(gs, ["c10301", "c10301", id(2)])
	var other: Dictionary = p.units[1]
	var before: int = other.attack
	var hp: int = other.maxHp
	var idx := give(gs, Y.INSIGHT)
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 0 and gs.play_card(0, idx), "洞悉 uses shared instant and real divination")
	check(choose_div(gs, instances[2], D.BOTTOM) and choose_div(gs, instances[1], D.TOP), "actual chosen bottom and top placements")
	check(int(instances[2].get("yuanqiBottomStacks", 0)) == 1 and p.hand.size() == 2, "chosen owned card grows, owner gains one token and draws")
	check(p.deck.front().instanceId == instances[2].instanceId and p.hand.any(func(c): return c.instanceId == instances[1].instanceId), "physical instance stays bottom, arranged top drawn")
	D.start(gs, 0, 2)
	var shown: Dictionary = D.choice_card(gs, 0, instances[2].instanceId)
	check(int(shown.get("yuanqiBottomStacks", 0)) == 1 and D.choice_card(gs, 1, instances[2].instanceId) == null, "only the controller sees the exact instance's accumulated growth in divination")
	check(choose_div(gs, instances[0], D.TOP) and choose_div(gs, instances[2], D.TOP), "viewing an enhanced instance and placing it on top does not grow it")
	gs._draw(0, 1, -1, {"drawInstanceId": instances[2].instanceId})
	var bless_idx: int = p.hand.find_custom(func(c): return c.definitionId == id(2))
	check(gs.play_card(0, bless_idx, other.uid) and other.attack == before + 2 and other.maxHp == hp + 2, "only upgraded instance gives exact +2/+2")
	var clean := give(gs, id(2))
	check(gs.play_card(0, clean, other.uid) and other.attack == before + 3, "fresh instance receives only baseline +1")
	gs = fixture()
	p = gs.player(0)
	instances = put_deck(gs, ["c10301","c10301"])
	check(gs.play_card(0, give(gs, Y.INSIGHT)) and choose_div(gs, instances[1], D.TOP) and choose_div(gs, instances[0], D.BOTTOM), "divine with no owned card")
	check(p.hand.size() == 1 and p.hand[0].definitionId == Y.INSIGHT and p.deck.size() == 2, "no conditional draw and exactly one passive token")
	gs.VerifiedRules.Divination.start(gs, 0, 1)
	check(choose_div(gs, p.deck.back(), D.TOP) and p.hand.size() == 1, "shared once-per-turn passive applies to second divination")

func cut_and_realm() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var instances := put_deck(gs, ["c10301",id(5)])
	for u in foe.units:
		u.maxHp = 10
		u.hp = 10
	check(F.offer(gs,0,0) and gs.resolve_divination_choice(0,F.REVERSE), "shared destiny moves exact card to bottom")
	check(p.deck[0].instanceId == instances[1].instanceId and foe.units.reduce(func(total,u): return total + int(u.hp),0) == 38, "cut placed at bottom hits one random enemy for two")
	var idx := give(gs,id(5))
	var ally: Dictionary = p.units[1]
	check(gs.can_play_card(0,idx,ally.uid).ok and not gs.can_play_card(0,idx,"avatar-1").ok, "manual cut can select shikigami on either side but never avatar")
	var victim: Dictionary = foe.units[0]
	var prior: int = victim.hp
	check(gs.play_card(0,idx,victim.uid) and int(victim.hp) == prior-5, "targeted cut actual 5")
	gs = fixture()
	p = gs.player(0)
	var u: Dictionary = p.units[0]
	check(gs.play_card(0,give(gs,id(1))) and p.realms[0].hp == 5 and gs.VerifiedRules.PipeFox.avatar_veil(gs,0), "installed Penglai grants avatar veil")
	var saved: String = p.realms[0].uid
	p.destinyFollowed = 2
	p.destinyReversed = 2
	gs._knockout_unit(u)
	var count: int = int(u.knockout)
	gs._trigger_realms(0)
	check(p.hand.is_empty() and int(u.knockout) == count, "threshold two triggers neither effect")
	p.destinyFollowed = 3
	p.destinyReversed = 3
	gs._trigger_realms(0)
	check(p.hand.size() == 1 and int(u.knockout) == count-1, "thresholds grant draw and reduce random living countdown")
	gs._deploy_realm(0,Content.card_def(id(1)))
	check(p.realms.size() == 1 and p.realms[0].uid != saved, "new space-time replaces installed one")
	gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"专项")
	check(not gs.VerifiedRules.PipeFox.avatar_veil(gs,0), "veil disappears with realm")

func order_and_destiny() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = p.units[0]
	var instances := put_deck(gs, ["c10301","c10302","c10303","c10304"])
	check(gs.play_card(0,give(gs,id(4))) and u.attack == 3 and u.hp == 6, "form body 3/6")
	gs._draw(0,1)
	check(p.deck.back().instanceId == instances[0].instanceId, "first own draw moves exact bottom instance to top")
	gs._draw(0,1)
	check(p.deck.back().instanceId == instances[2].instanceId, "second draw does not repeat bottom transfer")
	check(F.offer(gs,0,0) and gs.resolve_divination_choice(0,F.FOLLOW) and foe.avatarHp == 28, "first destiny triggers form projectile")
	check(F.offer(gs,0,0) and gs.resolve_divination_choice(0,F.FOLLOW) and foe.avatarHp == 28, "second destiny does not repeat projectile")

	gs = fixture()
	p = gs.player(0)
	instances = put_deck(gs, ["c10301", "c10302"])
	check(gs.play_card(0,give(gs,id(4))), "form can resolve before a draw leaving a one-card deck")
	gs._draw(0,1)
	check(p.deck == [instances[0]], "a single remaining card is both the original bottom and the new top")
	var later := deck(gs, ["c10303", "c10304"])
	p.deck.append_array(later)
	gs._draw(0,1)
	check(p.deck == [instances[0], later[0]], "the single-card placement still consumes the turn's first trigger")

	gs = fixture()
	p = gs.player(0)
	instances = put_deck(gs, [id(8), "c10301", id(2)])
	var i := give(gs,id(6))
	var card := gs.hand_card_def(0,i)
	check(card.get("originCard",{}).get("id") == "c27307" and gs.can_play_card(0,i,null,true).ok, "SSR exposes legal original alternate")
	check(gs.play_card(0,i) and gs.pending_choice.type == F.KIND and gs.resolve_divination_choice(0,F.REVERSE), "actual SSR fate choice")
	check(p.hand.size() == 2 and p.hand.any(func(c): return c.definitionId == id(2) and c.instanceId != instances[2].instanceId and int(c.get("yuanqiBottomStacks",0)) == 1), "copy retains enhanced data, not physical identity")
	check(p.deck.size() == 3 and p.deck[0].instanceId == instances[2].instanceId, "SSR copies do not remove source cards")

	gs = fixture()
	p = gs.player(0)
	instances = put_deck(gs, ["c10301", "c10302"])
	i = give(gs,id(3))
	check(not gs.can_play_card(0,i).ok, "决因果 requires another hand card")
	var hand_idx := give(gs,id(2))
	var hand_id: String = p.hand[hand_idx].instanceId
	check(gs.play_card(0,i) and gs.pending_choice.type == Y.HAND and not gs.resolve_divination_choice(1,hand_id), "决因果 private hand selection")
	check(gs.resolve_divination_choice(0,hand_id) and p.deck.back().instanceId == hand_id, "real instance first goes to top")
	check(gs.resolve_divination_choice(0,F.REVERSE) and gs.resolve_divination_choice(0,F.FOLLOW) and gs.resolve_divination_choice(0,F.REVERSE), "exact three consecutive destiny choices")
	check(gs.pending_choice.is_empty() and p.destinyReversed == 2 and p.destinyFollowed == 1 and p.deck.back().instanceId == hand_id, "three choices settle, physical instance participates in each")

func awakening_and_battle() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var instances := put_deck(gs, ["c10301",Y.INSIGHT,id(7)])
	var token := give(gs,Y.INSIGHT)
	var prior: String = p.hand[token].instanceId
	check(gs.play_card(0,give(gs,id(8))) and p.units[0].awakened and p.units[0].attack == 3 and p.units[0].maxHp == 6, "观天命 exact awakened body")
	check(p.hand[0].instanceId == prior and p.hand[0].definitionId == Y.CAUSAL and instances[1].definitionId == Y.CAUSAL, "awakening transforms real hand and deck token identities")
	check(gs.can_play_card(0,0).ok, "觉醒替换后的实物派生可正常使用")
	check(F.offer(gs,0,0) and gs.resolve_divination_choice(0,F.REVERSE), "awakened destiny uses actual rule")
	check(int(instances[2].get("yuanqiBottomStacks",0)) == 1 and p.hand.size() == 2 and p.hand[1].definitionId == Y.CAUSAL, "shake gets physical +1 and awakened passive gives derivative")
	D.start(gs,0,1)
	check(choose_div(gs,p.deck.back(),D.TOP) and p.hand.size() == 2, "awakening's destiny and divination share the same cap")
	gs._draw(0,1,-1,{"drawInstanceId":instances[2].instanceId})
	foe.units[0].front = 1
	foe.units[0].hp = 2
	foe.units[0].attack = 0
	var attack_idx: int = p.hand.find_custom(func(c): return c.definitionId == id(7))
	check(gs.play_card(0,attack_idx) and foe.units[0].hp == 0 and foe.avatarHp == 28 and int(foe.avatarFrozen) > 0, "boosted Pierce stuns actually hit avatar")

func reversal() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var instances := put_deck(gs, ["c10301", "c10302", "c10303"])
	var index := give(gs, Y.CAUSAL)
	var card := gs.hand_card_def(0, index)
	check(card.type == "spell" and card.level == 1 and card.token and card.cost == 1 and "instant" in card.keywords and FileAccess.file_exists("res://assets/official/cards/fate-baize-reversal.png"), "因果逆转为有实机原图的一勾瞬发派生法术")
	p.units[0].level = 0
	check(not gs.can_play_card(0, index).ok, "白泽未升勾时无法打出因果逆转")
	p.units[0].level = 1
	p.energy = 0
	check(gs.valid_targets(0, card).is_empty() and gs.effective_card_cost(0, card) == 0 and gs.play_card(0, index), "无施放目标，瞬发可在零鬼火打出")
	check(gs.pending_choice.type == F.KIND and gs.pending_choice.deckOwner == 0 and p.deck == instances and p.hand.is_empty(), "先打开己方牌库抉择，选择之前不交换也不抽牌")
	check(not gs.resolve_divination_choice(1, F.REVERSE) and gs.resolve_divination_choice(0, F.FOLLOW), "仅当前玩家可完成抉择")
	check(p.deck == instances and p.hand.is_empty() and int(p.destinyFollowed) == 1 and gs.instant_count(0) == 1, "顺应保留牌库、不抽牌，并消费瞬发")

	gs = fixture()
	p = gs.player(0)
	var foe := gs.player(1)
	p.units[0].awakened = true
	instances = put_deck(gs, ["c10301", "c10302", id(5)])
	var enemy_health: int = foe.units.reduce(func(total, unit): return total + int(unit.hp), 0)
	index = give(gs, Y.CAUSAL)
	gs.consume_instant(0)
	p.energy = 1
	check(gs.effective_card_cost(0, gs.hand_card_def(0, index)) == 1 and gs.play_card(0, index) and int(p.energy) == 0, "瞬发已用后按普通一鬼火付款")
	check(F.choice_card(gs, 0, F.REVERSE).choiceExplanation.contains("抽一张牌") and gs.resolve_divination_choice(0, F.REVERSE), "逆天预览说明抽牌并可实际提交")
	check(p.deck == [instances[2], instances[1]] and p.hand.size() == 2 and p.hand[0].definitionId == Y.CAUSAL and p.hand[1].instanceId == instances[0].instanceId, "觉醒被动先发派生，再抽取原来位于底部的实物")
	check(int(p.destinyReversed) == 1 and foe.units.reduce(func(total, unit): return total + int(unit.hp), 0) == enemy_health - 2, "逆天置底继续触发以戈止戈")

	gs = fixture()
	p = gs.player(0)
	instances = put_deck(gs, ["c10301"])
	check(gs.play_card(0, give(gs, Y.CAUSAL)) and gs.pending_choice.is_empty() and p.deck == instances and p.hand.is_empty() and int(p.destinyFollowed) == 1, "只有一张牌沿用顺应规则，不抽牌")

	gs = fixture()
	p = gs.player(0)
	p.units[0].awakened = true
	instances = put_deck(gs, ["c10301", "c10302"])
	index = give(gs, Y.CAUSAL)
	for _i in range(int(gs.rules.maxHandSize) - 1): give(gs, "c10303")
	check(gs.play_card(0, index) and gs.resolve_divination_choice(0, F.REVERSE), "满手牌也可使用因果逆转")
	check(p.deck == [instances[1]] and p.hand.size() == int(gs.rules.maxHandSize) and p.hand.back().definitionId == Y.CAUSAL and not p.hand.has(instances[0]), "觉醒补满手牌后正常烧掉逆天抽到的实物")

func ai_choices() -> void:
	var gs := fixture()
	var p := gs.player(0)
	put_deck(gs, ["c10301", "c10302"])
	give(gs,id(3))
	give(gs,id(2))
	check(AI.take_action(gs,0) and gs.pending_choice.type == Y.HAND, "AI uses legal decision card")
	for _i in 4:
		if not gs.pending_choice.is_empty(): check(AI.take_action(gs,0), "AI resolves required live choice")
	check(gs.pending_choice.is_empty() and int(p.get("destinyFollowed",0)) + int(p.get("destinyReversed",0)) == 3, "AI completes physical selection and three fate choices")

	gs = fixture()
	p = gs.player(0)
	var instances := put_deck(gs, ["c10108", "c10101"])
	give(gs, Y.CAUSAL)
	check(AI.take_action(gs, 0) and gs.pending_choice.get("drawOnReverse", false), "AI 可使用因果逆转并打开真实抉择")
	check(AI.take_action(gs, 0) and p.hand.has(instances[0]) and int(p.destinyReversed) == 1, "AI 为额外抽牌完成逆天改命")

	gs = fixture()
	p = gs.player(0)
	var foe := gs.player(1)
	var armored: Dictionary = foe.units[0]
	var vulnerable: Dictionary = foe.units[1]
	vulnerable.level = 0
	foe.units[2].summoned = true
	p.units[2].summoned = true
	p.units[3].level = 0
	armored.hp = 4
	armored.shield = 3
	vulnerable.hp = 6
	p.units[0].spellPower = 1
	var idx := give(gs, Y.CUT)
	check(gs.can_play_card(0, idx, armored.uid).ok and gs.can_play_card(0, idx, vulnerable.uid).ok, "以戈止戈的两个敌方目标均合法")
	check(not gs.can_play_card(0, idx, foe.units[2].uid).ok, "以戈止戈排除普通召唤物")
	check(AI.take_action(gs, 0) and vulnerable.hp == 0 and armored.hp == 4 and armored.shield == 3, "AI 按实际法强与护甲选择可以斩杀的目标")
	idx = give(gs, id(2))
	check(not gs.can_play_card(0, idx, p.units[2].uid).ok, "缘起的成长牌排除普通召唤物")
	var power: int = p.units[3].attack
	check(gs.play_card(0, idx, p.units[3].uid) and p.units[3].attack == power + 1, "缘起的成长牌命中零勾式神")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(TEAM,OTHER,93111)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		gs.phase = "main"
		var p := gs.player(0)
		put_deck(gs,["c10301","c10302","c10303"])
		hand(b,[id(3),id(2)])
		var selected_id: String = p.hand[1].instanceId
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var face := choice_face(b,id(2))
		check(face != null and gs.pending_choice.type == Y.HAND, "mouse reveals selectable hand face " + str(physical))
		if face != null: await click(face)
		await settled(b)
		check(p.deck.back().instanceId == selected_id and gs.pending_choice.type == F.KIND, "mouse selected exact card then enters real destiny " + str(physical))
		for _i in 3:
			var options := faces(b._choice_layer)
			if options.size() > 0: await click(options[0])
			await settled(b)
		check(gs.pending_choice.is_empty() and int(p.get("destinyFollowed",0)) + int(p.get("destinyReversed",0)) == 3, "mouse settles all three choices " + str(physical))
		var instances := put_deck(gs, ["c10301", "c10302"])
		hand(b, [Y.CAUSAL])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var reversal_options := faces(b._choice_layer)
		check(reversal_options.size() == 2 and gs.pending_choice.get("drawOnReverse", false) and texts(b._choice_layer).contains("并抽一张"), "鼠标打出因果逆转，显示两个可选牌库端点和抽牌说明 " + str(physical))
		if reversal_options.size() == 2: await click(reversal_options[1])
		await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.has(instances[0]) and p.deck == [instances[1]], "鼠标选择逆天后抽原底牌 " + str(physical))
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	catalog()
	divination_and_blessing()
	cut_and_realm()
	order_and_destiny()
	awakening_and_battle()
	reversal()
	ai_choices()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("YUANQI checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
