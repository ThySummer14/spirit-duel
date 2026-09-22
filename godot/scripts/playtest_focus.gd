extends SceneTree
## 固定阵容压测：优先覆盖响应/占卜/鼓舞/充能等中断与资源路径。
## 用法: Godot --headless --path godot --script res://scripts/playtest_focus.gd -- 16

const ContentLoader := preload("res://scripts/content_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameAI := preload("res://scripts/game_ai.gd")

const LINEUPS := [
	["yaodaoji", "bingyong", "xuenv", "taohuayao"],
	["ink", "lumen", "ember", "rime"],
	["storm", "frostblade", "kongo", "basalt"],
	["jutun-tongzi", "qingshe", "zhen", "tiaotiaodidi"],
	["qingwa-ciqi", "shantu", "zuofutongzi", "yaoginshi"],
	["yimulian", "shuweng", "jue", "quanshen"],
	["xiaolunan", "yanyanluo", "rihefang", "lianyou"],
	["datiangou", "panguan", "bailang", "guniao"],
]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rounds := 16
	if args.size() > 0:
		rounds = int(args[0])
	var completed := 0
	var stalls := 0
	var wins := [0, 0]
	var notes: Array = []
	var response_hits := 0
	var choice_hits := 0
	for i in rounds:
		var a: Array = LINEUPS[i % LINEUPS.size()]
		var b: Array = LINEUPS[(i + 3) % LINEUPS.size()]
		var gs := GameState.create(a, b, 31337 + i * 101)
		# 强制注入响应/占卜/鼓舞牌，保证中断窗口被走到
		_inject(gs, 0, "flash-thrust")
		_inject(gs, 0, "hoar-barrier")
		_inject(gs, 0, "index-page")
		_inject(gs, 0, "war-howl")
		_inject(gs, 1, "c10102")
		_inject(gs, 1, "flash-thrust")
		_inject(gs, 1, "hoar-barrier")
		_inject(gs, 1, "dawn-needle")
		# 双方常备鬼火，确保响应牌在窗口内可打出
		gs.player(0).energy = 2
		gs.player(1).energy = 2
		var steps := 0
		var saw_response := false
		var saw_choice := false
		while gs.winner < 0 and steps < 500:
			steps += 1
			if not gs.response_window.is_empty():
				saw_response = true
			if not gs.pending_choice.is_empty():
				saw_choice = true
			var p := gs.current_player
			gs.player(0).energy = maxi(int(gs.player(0).energy), 2)
			gs.player(1).energy = maxi(int(gs.player(1).energy), 2)
			var before := [gs.turn_counter, gs.resolution_stack.size(), gs.players[0].hand.size(), gs.players[1].hand.size()]
			GameAI.take_turn(gs, p)
			var after := [gs.turn_counter, gs.resolution_stack.size(), gs.players[0].hand.size(), gs.players[1].hand.size()]
			if gs.winner < 0 and gs.current_player == p and before == after and gs.pending_choice.is_empty() and gs.response_window.is_empty():
				if not gs.end_turn(p):
					stalls += 1
					notes.append("focus %d stall turn=%d" % [i, gs.turn_counter])
					break
		# take_turn 会在内部清掉窗口，因此以战报/命令日志判断是否走到过
		for entry in gs.log:
			var txt := str(entry.get("text", ""))
			if "响应窗口" in txt:
				saw_response = true
			if "占卜" in txt:
				saw_choice = true
		for cmd in gs.command_log:
			if str(cmd.get("c", "")) in ["pass_response", "resolve_divination_choice", "divination-choice"]:
				if str(cmd.get("c", "")) == "pass_response":
					saw_response = true
				else:
					saw_choice = true
		if saw_response:
			response_hits += 1
		if saw_choice:
			choice_hits += 1
		if gs.winner < 0:
			stalls += 1
			notes.append("focus %d no-winner" % i)
			continue
		completed += 1
		wins[gs.winner] += 1
	print("FOCUS rounds=%d completed=%d wins=%s stalls=%d response_games=%d choice_games=%d" % [
		rounds, completed, str(wins), stalls, response_hits, choice_hits,
	])
	for n in notes.slice(0, 10):
		print("FOCUS_NOTE ", n)
	if stalls > rounds / 4:
		printerr("FOCUS_FAIL stalls ", stalls)
		quit(1)
		return
	print("FOCUS_OK")
	quit(0)


func _inject(gs: GameState, p_idx: int, card_id: String) -> void:
	if ContentLoader.card_def(card_id).is_empty():
		return
	var p = gs.player(p_idx)
	p.hand.append({"instanceId": "%s-inj%d" % [p.id, gs.next_card_id], "definitionId": card_id})
	gs.next_card_id += 1
