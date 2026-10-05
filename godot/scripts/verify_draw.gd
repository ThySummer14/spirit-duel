extends SceneTree
## Keep existing cards and burn only new overflow, matching JS drawCards.
const GameState := preload("res://scripts/game_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	for hand_size in [11, 12]:
		for count in [1, 3]:
			var gs := GameState.create(["basalt"], ["basalt"], 9031)
			var p := gs.player(0)
			p.hand.clear()
			for i in hand_size:
				p.hand.append({"instanceId": "held-%d" % i, "definitionId": "stone-wall"})
			var original: Array = p.hand.duplicate(true)
			var top: Dictionary = p.deck.back().duplicate()
			var deck_size: int = p.deck.size()
			gs._draw(0, count)
			_check(p.hand.size() == 12, "hand cap respected")
			_check(p.deck.size() == deck_size - count, "overflow consumes drawn cards")
			for i in hand_size:
				_check(p.hand[i] == original[i], "held card %d retained at size %d draw %d" % [i, hand_size, count])
			if hand_size == 11:
				_check(p.hand[11] == top, "first drawn card fills last free slot")
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		quit(1)
		return
	print("DRAW_REGRESSION_OK cases=4")
	quit(0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
