extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var gs := GameState.create(["qingxingdeng", "basalt", "lumen", "rime"], ["storm", "frostblade", "kongo", "ember"], 424242)
	_check(not gs.player(0).hand.any(func(c): return c.definitionId == "mingdeng"), "opening own turn does not create opponent-start token")
	var top: String = gs.player(0).deck.back().definitionId
	var before: int = gs.player(0).hand.size()
	_check(gs.end_turn(0) and gs.end_turn(1), "turn cycle succeeds")
	_check(gs.player(0).hand[before].definitionId == "mingdeng", "token gained at opponent start remains before next own draw")
	_check(gs.player(0).hand[before + 1].definitionId == top, "normal draw follows turn-start effects")
	gs = GameState.create(["basalt", "caitongzi", "lumen", "rime"], ["qingxingdeng", "frostblade", "kongo", "ember"], 424242)
	gs.player(1).units[0].level = 1
	gs.player(1).energy = 1
	var opponent_before: int = gs.player(1).hand.size()
	gs.player(0).deck.clear()
	gs.player(0).units[0].front = 1
	before = gs.player(0).hand.size()
	gs._begin_turn(0)
	_check(gs.winner == 1, "empty deck loses in draw phase")
	_check(gs.player(0).hand.size() == before, "active player receives no artificial lantern before deck loss")
	_check(gs.player(1).hand.size() == opponent_before + 1 and gs.player(1).hand.back().definitionId == "mingdeng", "opponent lantern with leftover fire resolves before active empty-deck defeat")
	_check(gs.player(0).units[0].front == 0, "retreat also precedes draw-phase defeat")
	# The same timing with no leftover fire, an inactive source, or a knocked-out
	# source must not produce the historical unconditional turn-start token.
	for condition in ["empty-fire", "inactive", "knocked"]:
		gs = GameState.create(["qingxingdeng", "basalt", "lumen", "rime"], ["storm", "frostblade", "kongo", "ember"], 424242)
		gs.player(0).energy = 1
		if condition == "empty-fire": gs.player(0).energy = 0
		elif condition == "inactive": gs.player(0).units[0].level = 0
		else: gs._knockout_unit(gs.player(0).units[0])
		before = gs.player(0).hand.size()
		_check(gs.end_turn(0), "negative fixture enters opponent turn: " + condition)
		_check(gs.player(0).hand.size() == before, "lantern condition prevents token: " + condition)
	# A genuine installed countdown form can decide the game before normal draw.
	gs = GameState.create(["yimulian", "bingyong", "yingcao", "basalt"], ["storm", "frostblade", "kongo", "ember"], 424242)
	for unit in gs.player(0).units: unit.level = 3
	gs.player(0).hand = [{"instanceId":"turn-wind", "definitionId":"c11801"}]
	_check(gs.play_card(0, 0), "countdown form installs through a legal card play")
	gs.player(0).deck.clear()
	gs.player(1).avatarHp = 1
	gs.player(0).units[0].formCountdown.remaining = 1
	gs._begin_turn(0)
	_check(gs.winner == 0, "lethal turn-start countdown wins before empty-deck draw")
	_check(gs.player(0).deck.is_empty(), "winning countdown never fabricates cards to avoid deck loss")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("TURN_ORDER_OK checks=%d" % checks)
	quit(0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
