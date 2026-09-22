extends SceneTree
## Godot 内反复游玩压测：多局 AI vs AI，检测卡死/异常终局。
## 用法: Godot --headless --path godot --script res://scripts/playtest_burst.gd -- 30

const ContentLoader := preload("res://scripts/content_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var matches := 24
	if args.size() > 0:
		matches = int(args[0])
	var content := ContentLoader.load_content(true)
	var pool: Array = []
	for u in content.playable_units:
		pool.append(u.id)
	if pool.size() < 8:
		printerr("PLAYTEST_FAIL too few units ", pool.size())
		quit(2)
		return
	var wins := [0, 0]
	var stalls := 0
	var errors: Array = []
	var turn_sum := 0
	var completed := 0
	for m in matches:
		var seed := 20260920 + m * 17
		var lineup_a := _pick(pool, seed)
		var lineup_b := _pick(pool, seed + 99)
		var gs := GameState.create(lineup_a, lineup_b, seed)
		var steps := 0
		var max_steps := 400
		while gs.winner < 0 and steps < max_steps:
			steps += 1
			var p := gs.current_player
			# 窗口优先
			if not gs.pending_choice.is_empty():
				GameAI.take_turn(gs, p)
				continue
			if not gs.response_window.is_empty():
				GameAI.take_turn(gs, p)
				continue
			var before_turn := gs.turn_counter
			var before_stack := gs.resolution_stack.size()
			GameAI.take_turn(gs, p)
			if gs.winner < 0 and gs.current_player == p and gs.turn_counter == before_turn and gs.resolution_stack.size() == before_stack and gs.pending_choice.is_empty() and gs.response_window.is_empty():
				# 同一玩家连续无进展：强制结束回合防止锁死
				if not gs.end_turn(p):
					stalls += 1
					errors.append("match %d stall turn=%d" % [m, gs.turn_counter])
					break
		if gs.winner < 0:
			stalls += 1
			errors.append("match %d no-winner steps=%d turn=%d" % [m, steps, gs.turn_counter])
			continue
		completed += 1
		wins[gs.winner] += 1
		turn_sum += gs.turn_counter
	var avg_turn := 0.0
	if completed > 0:
		avg_turn = float(turn_sum) / float(completed)
	print("PLAYTEST matches=%d completed=%d wins=%s stalls=%d avg_turn=%.1f" % [
		matches, completed, str(wins), stalls, avg_turn,
	])
	for e in errors.slice(0, 12):
		print("PLAYTEST_NOTE ", e)
	if completed + stalls < matches:
		printerr("PLAYTEST_FAIL missing results")
		quit(1)
		return
	if stalls > matches / 3:
		printerr("PLAYTEST_FAIL too many stalls ", stalls)
		quit(1)
		return
	print("PLAYTEST_OK")
	quit(0)


func _pick(pool: Array, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var copy := pool.duplicate()
	copy.shuffle()
	# 确定性：用 rng 洗牌
	var out: Array = []
	var idx: Array = []
	for i in copy.size():
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	for k in 4:
		out.append(copy[idx[k]])
	return out
