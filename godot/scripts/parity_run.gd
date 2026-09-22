extends SceneTree
## 双实现对拍 · Godot 侧
## 用法: Godot --headless --path godot --script res://scripts/parity_run.gd -- res://../scripts/parity/sample-origin.json res://../scripts/parity/out/godot-snapshot.json
## 实际路径由 scripts/godot-parity.sh 传入绝对路径。

const GameState := preload("res://scripts/game_state.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: parity_run.gd <sample.json> <out.json>")
		quit(2)
		return
	var sample_path := args[0]
	var out_path := args[1]
	if not sample_path.begins_with("/"):
		sample_path = ProjectSettings.globalize_path("res://").path_join(sample_path)
	if not out_path.begins_with("/"):
		out_path = ProjectSettings.globalize_path("res://").path_join(out_path)
	# shell 传入的是相对仓库根的路径；globalize 到 res:// 下不存在时回退 CWD
	if not FileAccess.file_exists(sample_path):
		sample_path = args[0]
	if not FileAccess.file_exists(sample_path) and sample_path.is_relative_path():
		var env := OS.get_environment("PARITY_SAMPLE_ABS")
		if env != "":
			sample_path = env
	var sample_text := FileAccess.get_file_as_string(sample_path)
	var sample = JSON.parse_string(sample_text)
	if not (sample is Dictionary):
		printerr("invalid sample json")
		quit(2)
		return
	var seed := int(sample.get("seed", 20260920))
	var lineup_a: Array = sample.get("lineupA", [])
	var lineup_b: Array = sample.get("lineupB", [])
	var deck_a := ContentLoader.default_deck(lineup_a)
	var deck_b := ContentLoader.default_deck(lineup_b)
	var gs := GameState.create(lineup_a, lineup_b, seed, deck_a, deck_b)
	var inject: Array = sample.get("injectHand", []) if sample.get("injectHand") is Array else []
	for item in inject:
		if not (item is Dictionary):
			continue
		var ip := int(item.get("player", 0))
		var ic := str(item.get("card", ""))
		if ip >= 0 and ip < gs.players.size() and ic != "":
			gs.player(ip).hand.append({"instanceId": "%s-inj%d" % [gs.player(ip).id, gs.next_card_id], "definitionId": ic})
			gs.next_card_id += 1
	var inject_top: Array = sample.get("injectDeckTop", []) if sample.get("injectDeckTop") is Array else []
	for item in inject_top:
		if not (item is Dictionary):
			continue
		var tp := int(item.get("player", 0))
		if tp >= 0 and tp < gs.players.size():
			gs.player(tp).deck.append({"instanceId": "%s-top%d" % [gs.player(tp).id, gs.next_card_id], "definitionId": str(item.get("card", ""))})
			gs.next_card_id += 1
	var inject_lv: Array = sample.get("injectLevels", []) if sample.get("injectLevels") is Array else []
	for item in inject_lv:
		if not (item is Dictionary):
			continue
		var lp := int(item.get("player", 0))
		var lu := int(item.get("unit", 0))
		if lp >= 0 and lp < gs.players.size() and lu >= 0 and lu < gs.player(lp).units.size():
			gs.player(lp).units[lu].level = int(item.get("level", 1))
	var inject_e: Array = sample.get("injectEnergy", []) if sample.get("injectEnergy") is Array else []
	for item in inject_e:
		if not (item is Dictionary):
			continue
		var ep := int(item.get("player", 0))
		if ep >= 0 and ep < gs.players.size():
			gs.player(ep).energy = int(gs.player(ep).energy) + int(item.get("amount", 0))
	var steps: Array = []
	var commands: Array = sample.get("commands", [])
	for cmd in commands:
		var ok := _apply_neutral(gs, cmd)
		steps.append({
			"seq": int(cmd.get("seq", 0)),
			"type": str(cmd.get("type", "")),
			"ok": ok,
			"after": _snapshot(gs) if ok else {},
		})
	var payload := {
		"side": "godot",
		"sample": str(sample.get("name", "")),
		"seed": seed,
		"snapshot": _snapshot(gs),
		"steps": steps,
	}
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		printerr("cannot write %s" % out_path)
		quit(2)
		return
	out.store_string(JSON.stringify(payload, "\t") + "\n")
	out.close()
	var ok_count := 0
	for s in steps:
		if s.get("ok", false):
			ok_count += 1
	print("GODOT_PARITY_OK steps=%d ok=%d → %s" % [steps.size(), ok_count, out_path])
	quit(0)


func _apply_neutral(gs, cmd: Dictionary) -> bool:
	var p := int(cmd.get("player", 0))
	var t := str(cmd.get("type", ""))
	match t:
		"level-up":
			return gs.level_up(p, int(cmd.get("unit", 0)))
		"play-card":
			var card_id := str(cmd.get("card", ""))
			var hand_index := -1
			var hand: Array = gs.player(p).hand
			for i in hand.size():
				if str(hand[i].get("definitionId", "")) == card_id:
					hand_index = i
					break
			if hand_index < 0:
				return false
			return gs.play_card(p, hand_index, cmd.get("target"))
		"attack":
			return gs.basic_attack(p, int(cmd.get("unit", 0)), cmd.get("target"))
		"end-turn":
			return gs.end_turn(p)
		"pass-response":
			return gs.pass_response(p)
		"divination-choice":
			return gs.resolve_divination_choice(p, str(cmd.get("card", "")))
	return false


func _snapshot(gs) -> Dictionary:
	var players_out: Array = []
	for pi in gs.players.size():
		var p: Dictionary = gs.player(pi)
		var units_out: Array = []
		for u in p.units:
			units_out.append({
				"id": u.get("id"),
				"hp": int(u.get("hp", 0)),
				"maxHp": int(u.get("maxHp", 0)),
				"attack": int(u.get("attack", 0)),
				"shield": int(u.get("shield", 0)),
				"knockout": int(u.get("knockout", 0)),
				"frozen": int(u.get("frozen", 0)),
				"level": int(u.get("level", 0)),
				"awakened": bool(u.get("awakened", false)),
				"formId": u.get("form", {}).get("cardId") if u.get("form") is Dictionary else null,
				"front": int(u.get("front", 0)) == 1,
			})
		players_out.append({
			"avatarHp": int(p.get("avatarHp", 0)),
			"energy": int(p.get("energy", 0)),
			"handCount": p.hand.size(),
			"deckCount": p.deck.size(),
			"attackUsed": bool(p.get("attackUsed", false)),
			"levelUpUsed": bool(p.get("levelUpUsed", false)),
			"frontUnitId": _front_uid(p),
			"units": units_out,
		})
	return {
		"turn": gs.turn_counter,
		"current": gs.current_player,
		"winner": gs.winner,
		"phase": gs.phase,
		"responseWindow": (not gs.response_window.is_empty()),
		"stackDepth": gs.resolution_stack.size(),
		"pendingChoice": (not gs.pending_choice.is_empty()),
		"encourage": {
			"attack": int(gs.kw_usage(0, "encourage").get("attack", 0)),
			"shield": int(gs.kw_usage(0, "encourage").get("shield", 0)),
		},
		"players": players_out,
	}


func _front_uid(p: Dictionary) -> Variant:
	for u in p.units:
		if int(u.get("front", 0)) == 1:
			return u.get("uid")
	return null
