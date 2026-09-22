extends SceneTree
## 存档与自定义卡组冒烟。

const ContentLoader := preload("res://scripts/content_loader.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")

func _init() -> void:
	var units: Array = []
	for u in ContentLoader.playable_units():
		units.append(u.id)
		if units.size() >= 4:
			break
	SaveStore.set_lineup(units)
	var custom := ContentLoader.starter_card_ids(units[0])
	# 调换首尾，验证自定义卡组生效
	if custom.size() >= 2:
		var tmp = custom[0]
		custom[0] = custom[custom.size() - 1]
		custom[custom.size() - 1] = tmp
	SaveStore.set_deck(units[0], custom)
	var back: Array = SaveStore.get_deck(units[0])
	if back != custom:
		printerr("SAVE_FAIL deck roundtrip")
		quit(1)
		return
	if SaveStore.get_lineup() != units:
		printerr("SAVE_FAIL lineup roundtrip")
		quit(1)
		return
	var deck_a := SaveStore.deck_definition(units)
	var deck_b := SaveStore.deck_definition([units[1], units[2], units[3], units[0]])
	var gs := GameState.create(units, [units[1], units[2], units[3], units[0]], 42, deck_a, deck_b)
	var steps := 0
	while gs.winner < 0 and steps < 200:
		steps += 1
		GameAI.take_turn(gs, gs.current_player)
		if gs.current_player == 0 and gs.turn_counter > 20:
			break
	print("SAVE_OK lineup=%s deck0=%d steps=%d" % [str(units), back.size(), steps])
	quit(0)
