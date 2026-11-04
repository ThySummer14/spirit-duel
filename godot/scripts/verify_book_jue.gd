extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Rules := preload("res://scripts/book_jue_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BOOK_JUE_FAIL ", detail)
func fixture() -> GS:
	var gs := GS.create(["shuweng", "jue", "fenghuanghuo", "taohuayao"], ["jue", "shuweng", "xuenv", "fenghuanghuo"], 20261013)
	for p in gs.players:
		p.hand.clear()
		p.energy = 20
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs, id: String, owner: int = 0, shown: bool = false) -> int:
	gs.player(owner).hand.append({"instanceId": "book-jue-%d" % gs.next_card_id, "definitionId": id, "revealed": shown})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func deck(gs, ids: Array, owner: int = 0) -> void:
	gs.player(owner).deck.clear()
	for id in ids:
		gs.player(owner).deck.append({"instanceId": "book-jue-deck-%d" % gs.next_card_id, "definitionId": id})
		gs.next_card_id += 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "legal play " + id)
func _initialize() -> void:
	_book()
	_reveal()
	_dispatch()
	_mind()
	_grudge()
	_ai()
	_turn_flow()
	_matches()
	print("BOOK_JUE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _book() -> void:
	var opening := GS.create(["jue", "shuweng", "fenghuanghuo", "taohuayao"], ["jue", "xuenv", "fenghuanghuo", "taohuayao"], 20261013)
	check(opening.player(0).hand.size() == 6 and opening.player(1).hand.size() == 4, "opening bonus applies before book activation")
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var enemy: Dictionary = gs.player(1)
	var n: int = p.deck.size()
	play(gs, "c11901")
	check(p.hand.size() == 2 and p.deck.size() == n - 2, "open book draws exactly two")
	p.hand.clear()
	play(gs, "c11902")
	check(p.units[0].attack == 2 and p.units[0].maxHp == 5 and p.units[0].swift, "travel is printed 2/5 and next attack swift")
	check(p.hand.is_empty(), "travel no artificial entry draw")
	p.energy = 0
	check(gs.basic_attack(0, 0), "swift can basic attack at zero fire")
	check(p.hand.size() == 1 and not p.units[0].swift, "actual avatar hit draws and consumes swift")
	gs.player(1).avatarArmor = 9
	var before: int = p.hand.size()
	gs._damage_avatar(1, 2, 0, 0)
	check(p.hand.size() == before, "armor-only avatar hit does not draw")
	gs._damage_avatar(1, 1, 0, 1)
	check(p.hand.size() == before, "teammate avatar hit does not draw")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	for i in 4: give(gs, "c11907")
	deck(gs, ["c11901"])
	var hp: int = int(enemy.units[0].hp)
	play(gs, "c11903", enemy.units[0].uid)
	check(p.hand.size() == 5 and int(enemy.units[0].hp) == hp - 2, "ink draws first and floors 5/2")
	check(gs.valid_targets(0, gs.hand_card_def(0, 0)).is_empty(), "auto unrelated card has no targets")
	gs = fixture()
	p = gs.player(0)
	for i in 7: give(gs, "c11907")
	var h := give(gs, "c11905")
	check(gs.hand_card_def(0, h).value.attack == 8, "world hand view counts seven other cards")
	check(gs.play_card(0, h), "world form played")
	check(p.units[0].attack == 8 and p.units[0].maxHp == 8, "world body set 8/8")
	p.hand.clear()
	check(p.units[0].attack == 8, "installed body retains played card snapshot")
	gs = fixture()
	p = gs.player(0)
	var depth: int = p.deck.size()
	play(gs, "c11906")
	check(p.hand.size() == 3 and p.deck.size() == depth, "universe generates one per three other teammates without drawing")
	var ids: Array = p.hand.map(func(i): return ContentLoader.card_def(str(i.definitionId)).unitId)
	check(ids.has("jue") and ids.has("fenghuanghuo") and ids.has("taohuayao") and not ids.has("shuweng"), "universe owners exactly other teammates")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c11908")
	check(p.units[0].awakened and p.units[0].attack == 3 and p.units[0].maxHp == 7, "book awakening +2/+2")
	gs._knockout_unit(p.units[0])
	p.deck.clear()
	var avatar: int = int(gs.player(1).avatarHp)
	gs._draw(0, 2)
	check(gs.player(1).avatarHp == avatar - 10 and gs.winner < 0 and p.avatarHp == 30, "empty draw batch deals ten once across knockout")
	gs._draw(0, 2)
	check(gs.player(1).avatarHp == avatar - 20, "separate draw action deals another ten")
	gs = fixture()
	gs.player(0).deck.clear()
	gs._draw(0, 1)
	check(gs.winner == 1, "unawakened empty draw loses normally")
func _reveal() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var enemy: Dictionary = gs.player(1)
	give(gs, "c12008", 1)
	give(gs, "c11901", 1)
	Rules.turn_start(gs, 0, 1)
	check(enemy.hand.filter(func(i): return i.get("revealed", false)).size() == 1, "basic reveal exactly one")
	p.units[1].level = 0
	Rules.turn_start(gs, 0, 1)
	check(enemy.hand.filter(func(i): return i.get("revealed", false)).size() == 1, "inactive reveal cannot run")
	p.units[1].level = 3
	p.units[1].hp = 0
	Rules.turn_start(gs, 0, 1)
	check(enemy.hand.filter(func(i): return i.get("revealed", false)).size() == 1, "knocked out reveal cannot run")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	give(gs, "c12008", 1)
	give(gs, "c11901", 1)
	play(gs, "c12007")
	check(enemy.hand.all(func(i): return i.revealed) and p.units[1].attack == 3 and p.units[1].maxHp == 6, "awake immediate full reveal with printed growth only")
	give(gs, "c12001", 1)
	check(not enemy.hand.back().revealed, "new cards stay hidden between own starts")
	Rules.turn_start(gs, 0, 1)
	check(enemy.hand.back().revealed, "awake turn start reveals newly arrived card")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	give(gs, "c12008", 1)
	give(gs, "xueqiu", 1)
	give(gs, "c11901", 1)
	enemy.units[2].hp = 0
	var h := give(gs, "c12001")
	check(gs.valid_targets(0, gs.hand_card_def(0, h)).has(enemy.units[2].uid), "read can choose knocked out enemy ownership")
	check(gs.play_card(0, h, enemy.units[2].uid), "read selects dead enemy unit")
	check(enemy.hand[1].revealed and not enemy.hand[0].revealed and not enemy.hand[2].revealed, "read reveals only selected owner's token")
	check(p.hand.is_empty(), "read no invented draw")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	give(gs, "c12008", 1, true)
	give(gs, "c12001", 1, true)
	give(gs, "c11901", 1, true)
	var bomb := give(gs, "c12002")
	check(gs.valid_targets(0, gs.hand_card_def(0, bomb)).has(p.units[0].uid), "bomb allows friendly living unit")
	check(gs.play_card(0, bomb, enemy.units[0].uid), "bomb real enemy target")
	check(enemy.units[0].hp == 0, "bomb two shown matching dedicated cards gives six")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	give(gs, "c12001", 1, true)
	give(gs, "c12007", 1, true)
	give(gs, "c12004", 1, true)
	give(gs, "c11902", 1, false)
	var mimic := give(gs, "c12008")
	var view := gs.hand_card_def(0, mimic)
	check(view.value == 1 and view.combatOption.shield == 2, "mimic spells including awakening give armor, other shown gives attack")
	var avatar: int = enemy.avatarHp
	check(gs.play_card(0, mimic), "mimic real combat")
	check(p.units[1].shield == 2 and enemy.avatarHp == avatar - 3, "mimic uses actual one bonus attack and two armor")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	give(gs, "c11901", 1, true)
	var maze := give(gs, "c12006")
	check(gs.hand_card_def(0, maze).keywords.has("instant") and gs.card_payment(0, gs.hand_card_def(0, maze)).cost == 0, "all shown maze instant")
	check(gs.play_card(0, maze), "maze installed")
	var shown := gs.hand_card_def(1, 0)
	check(shown.cost == 2 and gs.card_payment(1, shown).cost == 2, "revealed noninstant costs exactly two")
	var fresh := give(gs, "c11901", 1)
	check(gs.hand_card_def(1, fresh).cost == 1, "hidden duplicate retains one fire")
	var free := give(gs, "c12001", 1, true)
	check(gs.card_payment(1, gs.hand_card_def(1, free)).cost == 0, "first instant remains free under tax")
	gs.kw_usage(1, "instant").used = true
	check(gs.card_payment(1, gs.hand_card_def(1, free)).cost == 2, "spent instant costs taxed two")
	p.units[1].hp = 0
	check(gs.hand_card_def(1, 0).cost == 1, "knocked out maze does not tax")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	play(gs, "c12004")
	p.avatarHp = 20
	gs.current_player = 1
	var idx := give(gs, "c11901", 1, true)
	check(gs.play_card(1, idx), "opponent plays shown card")
	check(enemy.avatarHp == 28 and p.avatarHp == 22, "spirit sight actual damage and healing")
	var power: int = p.units[1].attack
	idx = give(gs, "c11901", 1)
	check(gs.play_card(1, idx) and enemy.avatarHp == 28 and p.avatarHp == 22 and p.units[1].attack == power, "hidden card no spirit sight or old awakening growth")
func _dispatch() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	give(gs, "c11908")
	give(gs, "c12008")
	deck(gs, ["c11901", "c12001", "c12004", "c11902"])
	var rejected: String = p.hand[0].instanceId
	play(gs, "c11907")
	check(gs.pending_choice.type == "book-dispatch" and gs.pending_choice.remaining == 3 and p.hand.size() == 2, "cloud trip is three real exchanges")
	check(not gs.resolve_divination_choice(1, rejected), "opponent cannot operate cloud choice")
	check(not gs.resolve_divination_choice(0, "hidden"), "unknown choice cannot replace")
	check(not gs.end_turn(0), "dispatch blocks ending turn")
	check(gs.resolve_divination_choice(0, rejected), "first actual exchange")
	check(p.hand[0].definitionId == "c11902" and gs.pending_choice.returned[0].instanceId == rejected, "replacement comes from deck and rejected stays aside")
	var state = JSON.parse_string(JSON.stringify(gs.snapshot()))
	check(state.pendingChoiceState.type == "book-dispatch" and state.pendingChoiceState.returned.size() == 1, "snapshot serializes returned card and count")
	var restored := fixture()
	restored.players = state.players
	restored.pending_choice = state.pendingChoiceState
	restored.phase = "choice"
	check(restored.resolve_divination_choice(0, Rules.FINISH), "JSON restored pending choice resolves")
	check(restored.player(0).deck.any(func(i): return i.instanceId == rejected), "restored finish returns held card to deck")
	check(gs.resolve_divination_choice(0, Rules.FINISH), "human can preserve remaining choices")
	check(gs.pending_choice.is_empty() and p.deck.any(func(i): return i.instanceId == rejected), "finish returns rejected card and unblocks")
	gs = fixture()
	p = gs.player(0)
	give(gs, "c11908", 1, true)
	give(gs, "c12008", 1, false)
	deck(gs, ["c12001", "c11902"], 1)
	play(gs, "c12003")
	check(gs.pending_choice.zoneOwner == 1 and gs.pending_choice.instanceIds.size() == 2, "extortion only shows revealed instance and finish")
	check(not gs.resolve_divination_choice(0, str(gs.player(1).hand[1].instanceId)), "extortion rejects hidden opponent card")
	var iid: String = gs.player(1).hand[0].instanceId
	check(gs.resolve_divination_choice(0, iid), "extortion replaces shown enemy card")
	check(gs.player(1).hand[0].definitionId == "c11902" and not gs.player(1).hand[0].get("revealed", false), "new opponent card remains hidden")
	check(gs.pending_choice.is_empty() and p.hand.size() == 1, "no further shown card finishes and then draws exactly one")
func _mind() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	play(gs, "c11904")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5, "mind printed 4/5")
	deck(gs, ["c11908", "c11901", "c12001", "c12004"])
	check(Rules.turn_draw(gs, 0), "mind replaces turn draw")
	check(gs.pending_choice.instanceIds.size() == 3 and not gs.pending_choice.instanceIds.has(p.deck[0].instanceId), "mind exactly deck top three")
	var chosen: String = p.deck[1].instanceId
	check(gs.resolve_divination_choice(0, chosen), "mind actual choice")
	check(p.hand.size() == 1 and p.hand[0].instanceId == chosen and p.deck.size() == 3, "mind puts selected in hand without double draw")
	check(p.deck[0].definitionId == "c11908" and p.deck.back().definitionId == "c12004", "unchosen cards retain order")
	p.deck.clear()
	p.bookEmptyDraw = true
	p.bookEmptyDrawSource = p.units[0].uid
	var hp: int = gs.player(1).avatarHp
	check(Rules.turn_draw(gs, 0) and gs.winner < 0 and gs.player(1).avatarHp == hp, "empty mind neither loses nor triggers book awakening")
	p.units[0].hp = 0
	check(not Rules.turn_draw(gs, 0), "knocked out mind cannot replace")
func _grudge() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var enemy: Dictionary = gs.player(1)
	var h := give(gs, "c12005")
	check(gs.valid_targets(0, gs.hand_card_def(0, h)).is_empty(), "grudge requires damage dealt this turn")
	check(not gs.can_play_card(0, h, enemy.units[0].uid).ok, "non damaging enemy illegal")
	gs._damage_unit(0, 0, 1, 1, 0)
	check(gs.valid_targets(0, gs.hand_card_def(0, h)) == [enemy.units[0].uid], "unit damage records enemy this turn")
	check(p.hand.size() == 1, "damage to ally unit does not trigger avatar response")
	enemy.units[0].shield = 99
	enemy.units[0].barrier = true
	check(gs.play_card(0, h, enemy.units[0].uid), "manual grudge destroys qualified enemy")
	check(enemy.units[0].hp == 0 and enemy.units[0].knockout > 0, "direct destruction bypasses armor and barrier")
	check(p.units[1].shield == 0, "grudge has no old shield substitute")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	h = give(gs, "c12005")
	p.units[0].shield = 2
	gs._damage_unit(0, 0, 1, 1, 0)
	check(gs.valid_targets(0, gs.hand_card_def(0, h)).is_empty(), "armor-only attack creates no positive damage history")
	p.units[0].shield = 0
	gs._damage_unit(0, 0, 1, 1, 0)
	gs.turn_counter += 1
	check(gs.valid_targets(0, gs.hand_card_def(0, h)).is_empty(), "previous turn damage cannot qualify")
	gs = fixture()
	p = gs.player(0)
	enemy = gs.player(1)
	give(gs, "c12005")
	gs.current_player = 1
	var energy: int = p.energy
	check(gs.basic_attack(1, 0), "enemy real basic attacks avatar")
	check(p.avatarHp == 28, "original avatar damage completes before response")
	check(p.hand.is_empty() and p.energy == energy - 1 and enemy.units[0].hp == 0, "automatic grudge spends fire and destroys actual damaging enemy")
	check(gs.rule_events.any(func(e): return e.kind == "response-card" and e.get("trigger") == "enemy-unit-damaged-avatar"), "new response trigger recorded")
	check(not gs.rule_events.any(func(e): return e.kind == "jue-grudge-echo"), "no stale spell copying remains")
	gs = fixture()
	p = gs.player(0)
	give(gs, "c12005")
	p.avatarArmor = 8
	gs.current_player = 1
	check(gs.basic_attack(1, 0), "armor-only avatar combat")
	check(p.hand.size() == 1 and gs.player(1).units[0].hp > 0, "avatar armor blocks automatic grudge trigger")
	for blocked in ["frozen", "fire", "level", "knockout"]:
		gs = fixture()
		p = gs.player(0)
		give(gs, "c12005")
		if blocked == "frozen": p.units[1].frozen = 1
		if blocked == "fire": p.energy = 0
		if blocked == "level": p.units[1].level = 1
		if blocked == "knockout": p.units[1].hp = 0
		gs.current_player = 1
		check(gs.basic_attack(1, 0), "enemy attack under " + blocked)
		check(p.hand.size() == 1 and gs.player(1).units[0].hp > 0, "grudge respects " + blocked)
	gs = fixture()
	p = gs.player(0)
	give(gs, "c12005")
	gs.current_player = 1
	play(gs, "c10603", p.units[0].uid, 1)
	check(p.hand.size() == 1 and gs.player(1).units[2].hp == gs.player(1).units[2].maxHp, "targeted ally spell no longer copies to caster")
func _ai() -> void:
	var gs := fixture()
	give(gs, "c11908")
	give(gs, "c12008")
	play(gs, "c11907")
	for i in 4:
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs, 0), "AI dispatch legal choice")
	check(gs.pending_choice.is_empty(), "AI completes at most three dispatches")
	gs = fixture()
	give(gs, "c12001")
	give(gs, "c12008", 1)
	var best := AI._best_card(gs, 0)
	check(best.ok and best.target == gs.player(1).units[0].uid and gs.can_play_card(0, best.hand, best.target).ok, "AI read selects enemy with hidden matching card")
	gs = fixture()
	give(gs, "c12002")
	best = AI._best_card(gs, 0)
	check(best.ok and gs._unit_index_by_uid(1, best.target) >= 0, "AI bomb never attacks friendly")
	gs = fixture()
	play(gs, "c11904")
	Rules.turn_draw(gs, 0)
	check(AI._resolve_choice(gs, 0) and gs.pending_choice.is_empty(), "AI mind chooses legal inspected top card")

	gs = fixture()
	give(gs, "c12005")
	gs._damage_unit(0, 0, 1, 1, 0)
	best = AI._best_card(gs, 0)
	check(best.ok and best.target == gs.player(1).units[0].uid and gs.can_play_card(0, best.hand, best.target).ok, "AI destroys only qualified damaging enemy")

func _turn_flow() -> void:
	var gs := fixture()
	give(gs, "c12008", 1)
	give(gs, "c11901", 1)
	gs._begin_turn(0)
	check(gs.player(1).hand.filter(func(i): return i.revealed).size() == 1, "full turn flow invokes base reveal")
	gs = fixture()
	play(gs, "c12007")
	give(gs, "c12008", 1)
	give(gs, "c11901", 1)
	gs.player(0).units[1].hp = 0
	gs.player(0).units[1].knockout = 1
	gs._begin_turn(0)
	check(gs.player(0).units[1].hp > 0 and gs.player(1).hand.all(func(i): return i.revealed), "natural revival then awake turn reveal")
	gs = fixture()
	play(gs, "c11904")
	var depth: int = gs.player(0).deck.size()
	gs._begin_turn(0)
	check(gs.pending_choice.get("type") == "book-mind" and gs.player(0).hand.is_empty() and gs.player(0).deck.size() == depth, "normal turn draw replaced by pending mind choice")
	gs = fixture()
	play(gs, "c11908")
	gs.player(0).deck.clear()
	var hp: int = gs.player(1).avatarHp
	gs._begin_turn(0)
	check(gs.player(1).avatarHp == hp - 10 and gs.winner < 0, "normal turn empty draw invokes global replacement")
func _matches() -> void:
	for seed in [20261013, 20261014, 20261015]:
		var gs := GS.create(["shuweng", "jue", "fenghuanghuo", "taohuayao"], ["jue", "shuweng", "xuenv", "fenghuanghuo"], seed)
		var steps := 0
		while gs.winner < 0 and steps < 300:
			AI.take_turn(gs, gs.action_player())
			steps += 1
		check(gs.winner >= 0, "AI complete book/jue match " + str(seed))
		check(gs.pending_choice.is_empty(), "AI match leaves no pending choice " + str(seed))
