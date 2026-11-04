extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_payment()
	_statuses()
	if not failures.is_empty():
		for failure in failures: printerr("BATTLE_STATUS_FAIL ", failure)
	print("BATTLE_STATUS_%s checks=%d" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func game():
	var gs := GameState.create(["yaodaoji", "yingcao", "taohuayao", "jutun-tongzi"], ["yaodaoji", "yingcao", "taohuayao", "jutun-tongzi"], 81008)
	for p in gs.players:
		p.hand.clear()
		p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	return gs

func hand(gs, ids: Array, owner: int = 0) -> void:
	gs.player(owner).hand.clear()
	for i in ids.size(): gs.player(owner).hand.append({"instanceId": "status-%d-%d" % [owner, i], "definitionId": ids[i]})

func has(unit: Dictionary, id: String, turn: int = 1) -> bool:
	return Status.unit_marks(unit, turn).any(func(m): return m.id == id)

func _payment() -> void:
	var gs = game()
	hand(gs, ["c10104", "c10702", "c10703"])
	var natural := gs.hand_card_def(0, 0)
	check(gs.card_payment(0, natural).cost == 0 and not gs.card_payment(0, natural).usesInstant, "natural zero is independent of instant")
	check(gs.play_card(0, 0), "natural zero card resolves")
	check(not gs.player(0).keywordUsage.instant.used, "natural zero without keyword does not consume allowance")
	# First zero-cost slash hit the avatar, so the remaining combat cards now
	# acquire instant. An additional zero-cost slash must still consume it.
	hand(gs, ["c10104", "c10702"])
	check(gs.card_payment(0, gs.hand_card_def(0, 0)).usesInstant, "natural zero with dynamically granted instant consumes allowance")
	gs.player(0).energy = 0
	check(gs.play_card(0, 0), "dynamic zero instant plays at zero fire")
	check(gs.player(0).keywordUsage.instant.used, "dynamic zero instant spent team allowance")
	check(not gs.can_play_card(0, 0).ok, "another shikigami shares the used allowance")
	gs.end_turn(0)
	check(gs.instant_available(0), "new enemy turn resets owner instant allowance")
	gs.end_turn(1)
	check(gs.instant_available(0), "next owner turn resets allowance")
	check(not gs.player(1).keywordUsage.instant.used, "opponent allowance is independent")
	gs.player(0).levelUpUsed = true
	gs.player(0).energy = 0
	hand(gs, ["c10702", "c10703"])
	var before := JSON.stringify(gs.snapshot())
	for i in 4:
		var card := gs.hand_card_def(0, 0)
		var view := Status.card_view(gs, 0, card)
		check(view.payment.cost == 0 and int(view.cost) == 1, "display keeps printed and effective cost separately")
		check("瞬发可用" in Status.payment_text(view), "display explains free instant")
	check(JSON.stringify(gs.snapshot()) == before, "queries and display do not change state, RNG or allowance")
	check(not gs.play_card(0, 0, "not-a-target"), "invalid play rejected")
	check(not gs.player(0).keywordUsage.instant.used and gs.player(0).energy == 0, "rejection cannot consume resources")
	check(GameAI.take_action(gs, 0), "AI acts at zero fire")
	check(gs.player(0).keywordUsage.instant.used and gs.player(0).energy == 0, "AI spends exactly one shared instant")
	check(not gs.can_play_card(0, 0).ok, "second AI instant still costs printed fire")
	# Minimal legacy manual response fixture reproduces the former cost==0 bug.
	var fixture := {"id": "test-zero-instant-response", "unitId": "yaodaoji", "name": "测试响应", "type": "spell", "level": 1, "cost": 0, "timing": "response", "responseTo": ["spell"], "target": "auto", "keywords": ["instant"], "effect": "draw", "value": 1, "effects": [{"action": "draw", "target": "self", "value": 1}]}
	Content.load_content().cards_by_id[fixture.id] = fixture
	for own_turn in [true, false]:
		gs = game()
		gs.current_player = 0 if own_turn else 1
		gs.response_window = {"playerIndex": 0, "action": "spell", "resolutionId": -1}
		hand(gs, [fixture.id])
		check(gs.play_card(0, 0), "zero-cost manual response is legal")
		check(gs.player(0).keywordUsage.instant.used, "zero-cost instant response consumes this turn allowance")
	Content.load_content().cards_by_id.erase(fixture.id)
	gs = game()
	hand(gs, ["c10807"])
	check(gs.card_payment(0, gs.hand_card_def(0, 0)).usesInstant, "living peach condition grants instant")
	gs._knockout_unit(gs.player(0).units[2])
	check(not gs.card_payment(0, gs.hand_card_def(0, 0)).instant, "knocked peach condition removes instant in quote")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, 0)) == 1, "knocked peach pays normal cost")

func _statuses() -> void:
	var gs = game()
	var u: Dictionary = gs.player(0).units[0]
	u.merge({"barrier": true, "swift": true, "charge": 3, "armorBreak": 2, "brittle": 2, "frozen": 1, "unyielding": true, "awakened": true}, true)
	for id in ["barrier", "swift", "charge", "armor-break", "brittle", "stun", "unyielding", "awakened"]:
		check(has(u, id), "active status represented: " + id)
	var before := JSON.stringify(u)
	var marks := Status.unit_marks(u, gs.turn_counter)
	for size in [Vector2(108, 146), Vector2(116, 156), Vector2(84, 112)]:
		var badges := Status.badge_layout(marks, size)
		check(badges.size() == 6 and badges.back().mark.id == "overflow" and badges.back().mark.value == 2, "overflow explicitly counts omitted marks")
		for i in badges.size():
			check(Rect2(Vector2.ZERO, size).encloses(badges[i].rect), "status icon stays within unit hit area")
			for j in range(i): check(not badges[i].rect.intersects(badges[j].rect), "status icons do not overlap")
	check(JSON.stringify(u) == before, "status queries do not mutate rule state")
	u.shutenHowlTurn = gs.turn_counter
	u.yaodaoInstantTurn = gs.turn_counter
	u.yaodaoFreeCombatTurn = gs.turn_counter
	for id in ["howl", "instant", "free"]:
		check(has(u, id, gs.turn_counter), "current-turn mark shown: " + id)
		check(not has(u, id, gs.turn_counter + 1), "stale mark absent: " + id)
	gs._knockout_unit(u)
	check(has(u, "knockout") and has(u, "awakened"), "knockout keeps only persistent awakening")
	for id in ["barrier", "swift", "charge", "armor-break", "stun", "unyielding", "howl", "instant", "free"]: check(not has(u, id), "inactive knocked status hidden: " + id)
	var peach: Dictionary = gs.player(0).units[2]
	peach.swift = true
	check(has(peach, "swift"), "single-use swift shown")
	gs.player(0).energy = 0
	check(gs.basic_attack(0, 2), "swift grants legal zero-fire attack")
	check(not has(peach, "swift"), "swift mark disappears immediately after consumption")
	var target: Dictionary = gs.player(1).units[1]
	target.barrier = true
	gs._damage_unit(1, 1, 2, 0)
	check(not has(target, "barrier"), "barrier mark clears when real damage consumes it")
	target.unyielding = true
	target.hp = 3
	gs._damage_unit(1, 1, 10, 0)
	check(target.hp == 1 and not has(target, "unyielding"), "one-shot unyielding clears after actual lethal damage")
	var special: Dictionary = gs.player(0).units[3]
	special.merge({"formRules": {"lockEnemyFrontReplacement": true}, "front": 1, "flashAttackReduction": 4, "flashAppliedTurn": gs.turn_counter, "formExpiresTurn": gs.turn_counter, "pendingShields": [{"turn": gs.turn_counter + 1, "amount": 2}]}, true)
	for id in ["lock", "weaken", "expire", "pending-armor"]: check(has(special, id, gs.turn_counter), "special lifecycle marker: " + id)
	special.front = 0
	check(not has(special, "lock", gs.turn_counter), "front lock mark requires actual front presence")
	for id in ["weaken", "expire"]: check(not has(special, id, gs.turn_counter + 1), "expired special marker hidden: " + id)
	var timer_game := GameState.create(["yaoginshi", "bingyong", "yingcao", "yaodaoji"], ["yaoginshi", "bingyong", "yingcao", "yaodaoji"], 10807)
	var timer_source: Dictionary = timer_game.player(0).units[0]
	timer_source.level = 3
	check(has(timer_source, "countdown"), "active ability timer exposed")
	timer_game._knockout_unit(timer_source)
	var timer_marks := Status.unit_marks(timer_source, timer_game.turn_counter)
	check(timer_marks.any(func(m): return m.id == "countdown" and not m.active and "气绝暂停" in m.label), "retained timer is explicitly paused while knocked")
	check(timer_marks.any(func(m): return m.id == "knockout"), "paused timer and revival timer remain separate")
	var soldier: Dictionary = timer_game.player(0).units[1]
	soldier.level = 3
	soldier.awakened = true
	check(has(soldier, "retain-armor"), "awake armor retention marker")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.player(0).units[0]))
	check(Status.unit_marks(saved, gs.turn_counter) == Status.unit_marks(gs.player(0).units[0], gs.turn_counter), "JSON roundtrip preserves status projection")
