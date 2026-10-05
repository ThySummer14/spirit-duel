extends SceneTree
## Headless vertical-slice verify: content contract + rules loop + command log.

const ContentLoader := preload("res://scripts/content_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")


func _initialize() -> void:
	var code := _verify_content()
	if code != 0:
		quit(code)
		return
	code = _verify_match()
	if code != 0:
		quit(code)
		return
	print("GODOT_VERT_SLICE_OK")
	quit(0)


func _verify_content() -> int:
	var payload = JSON.parse_string(FileAccess.get_file_as_string("res://content/content.json"))
	if not (payload is Dictionary) or int(payload.get("schema", 0)) != 1:
		push_error("Invalid content contract")
		return 1
	var content: Dictionary = ContentLoader.load_content(true)
	if content.get("schema") != 1:
		push_error("ContentLoader failed")
		return 1
	var units: Array = content.playable_units
	var cards: Array = content.cards
	if units.size() < 2 or cards.size() < 10:
		push_error("Content too small")
		return 1
	var seen := {}
	for card in cards:
		if seen.has(card.id) or not content.by_id.has(card.unitId):
			push_error("Duplicate card or missing owner: " + str(card.id))
			return 1
		seen[card.id] = true
	print("GODOT_CONTENT_OK units=%d playable=%d cards=%d" % [content.units.size(), units.size(), cards.size()])
	return 0


func _verify_match() -> int:
	var content: Dictionary = ContentLoader.load_content()
	var playable: Array = content.playable_units
	var a: Array = []
	var b: Array = []
	for i in playable.size():
		if a.size() < 4:
			a.append(playable[i].id)
		elif b.size() < 4:
			b.append(playable[i].id)
	if a.size() < 2 or b.size() < 2:
		push_error("Not enough playable units")
		return 1
	var gs = GameState.create(a, b, 20260920)
	if gs.players.size() != 2:
		push_error("Expected 2 sides")
		return 1
	if gs.player(0).units.size() != a.size() or gs.player(1).units.size() != b.size():
		push_error("Lineup size mismatch")
		return 1
	var acted := 0
	for turn in 8:
		if gs.winner >= 0:
			break
		var p: int = gs.current_player
		if gs.is_upgrade_pending(p):
			for i in gs.player(p).units.size():
				if gs.level_up(p, i):
					acted += 1
					break
			continue
		for h in gs.player(p).hand.size():
			var card: Dictionary = ContentLoader.card_def(gs.player(p).hand[h].definitionId)
			var tgt = null
			if str(card.get("target", "auto")) != "auto":
				var opts: Array = gs.valid_targets(p, card)
				if opts.is_empty():
					continue
				tgt = opts[0]
			if gs.play_card(p, h, tgt):
				acted += 1
				break
		for i in gs.player(p).units.size():
			if gs.basic_attack(p, i, null):
				acted += 1
				break
		if p == 1:
			GameAI.take_turn(gs, 1)
			acted += 1
		if gs.current_player == p and gs.winner < 0:
			if not gs.end_turn(p):
				push_error("end_turn failed unexpectedly")
				return 1
			acted += 1
	if acted < 4:
		push_error("Too few commands simulated: %d" % acted)
		return 1
	if gs.command_log.is_empty():
		push_error("Command log empty")
		return 1
	var snap: Dictionary = gs.snapshot()
	print("GODOT_MATCH_OK commands=%d log=%d turn=%d winner=%d seed=%d" % [
		gs.command_log.size(), gs.log.size(), int(snap.turn), gs.winner, gs.seed
	])
	print("COMMAND_LOG " + String(gs.command_log_json()).left(240))
	return 0
