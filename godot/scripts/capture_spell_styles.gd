extends SceneTree
## 原生卡面输入与真实结算录制；支持 Godot --write-movie，不改玩家存档。
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const CASES := [
	["01-fire", "c12404", "enemy"], ["02-ice", "c10605", "enemy"],
	["03-freeze", "c10603", "enemy"], ["04-wind", "c10503", "auto"],
	["05-thunder", "spark-shot", "enemy"], ["06-ink-seal", "erode-script", "enemy"],
	["07-petal-heal", "c10801", "ally"], ["08-heal", "mend", "ally"],
	["09-shield", "brace", "ally"], ["10-form", "c10302", "auto"],
	["11-awaken", "c10107", "auto"], ["12-realm", "wardline", "auto"],
	["13-resource", "soul-tithe", "auto"], ["14-slash", "c10103", "auto"],
	["15-guard", "c12404", "guard"], ["16-arcane", "c10701", "enemy"],
]
var _stage: Control
var _out := "user://spell-shots"
var _stores := ""

func _initialize() -> void: _run.call_deferred()

func _click(face: Control) -> void:
	var pos := face.get_global_transform_with_canvas() * (face.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = pos
	root.push_input(move, true)
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = pos
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		root.push_input(input, true)

func _run() -> void:
	_stores = VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	var physical := Vector2i(1600, 740)
	if args.size() > 1 and args[1] == "normal": physical = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(physical)
	DisplayServer.window_move_to_foreground()
	root.size = physical
	root.theme = ThemeBuilder.build_theme()
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_stage)
	root.gui_disable_input = true
	var results: Array = []
	for sample in CASES:
		var owner: String = ContentLoader.card_def(sample[1]).unitId
		var lineup: Array = [owner]
		for uid in ["yaodaoji", "bingyong", "yingcao", "taohuayao", "lumen", "ink"]:
			if lineup.size() < 4 and uid != owner: lineup.append(uid)
		var battle := BattleScreen.new()
		battle.setup(lineup, ["basalt", "lumen", "rime", "ink"], 80620)
		battle._ai_thinking = true
		_stage.add_child(battle)
		for p in battle.gs.players:
			p.hand.clear()
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		for unit in battle.gs.player(1).units:
			unit.shield = 0
		battle.gs.player(0).energy = 2
		battle.gs.player(0).hand = [{"instanceId": "record-" + str(sample[1]), "definitionId": sample[1]}]
		# 保留完整五张手牌，让演出截图也能检验战场与扇形手牌之间的位置关系。
		for i in 4:
			var pool: Array = ContentLoader.cards_for_unit(lineup[1 + i % 3]).filter(func(c): return c.get("timing", "main") == "main" and not c.get("token", false))
			battle.gs.player(0).hand.append({"instanceId": "record-extra-%d" % i, "definitionId": pool[i % pool.size()].id})
		if sample[2] == "ally" or sample[0] == "10-form": battle.gs.player(0).units[0].hp = 1
		if sample[0] == "14-slash": battle.gs.player(1).units[0].front = 1
		if sample[2] == "guard": battle.gs.player(1).units[0].shield = 8
		battle._last_view = {}
		battle._refresh()
		for i in 7: await process_frame
		for face in battle._unit_widgets.values():
			if face.has_meta("flip_from"): face.remove_meta("flip_from")
		root.gui_disable_input = false
		_click(battle._hand_row.get_child(0))
		if sample[2] in ["enemy", "guard"]: _click(battle._unit_widget(str(battle.gs.player(1).units[0].uid)))
		elif sample[2] == "ally": _click(battle._unit_widget(str(battle.gs.player(0).units[0].uid)))
		root.gui_disable_input = true
		if battle.gs.command_log.is_empty() or battle.gs.command_log[0].c != "play_card":
			push_error("Native spell input failed: " + str(sample[0]))
			VerifySupport.cleanup_stores(_stores)
			quit(1)
			return
		var seen: Array = []
		for i in 34:
			await process_frame
			for effect in battle._effects.get_children():
				if effect.get_meta("spell_effect", false) and not seen.has(effect.family): seen.append(effect.family)
			if i in [5, 11, 17]:
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png(_out.path_join("%s-%02d.png" % [sample[0], i]))
		results.append({"case": sample[0], "card": sample[1], "families": seen, "commands": battle.gs.command_log.duplicate(true)})
		print("SPELL_CAPTURE ", sample[0], " families=", seen)
		_stage.remove_child(battle)
		battle.queue_free()
		await process_frame
	var record := FileAccess.open(_out.path_join("native-results.json"), FileAccess.WRITE)
	record.store_string(JSON.stringify(results, "\t"))
	record.close()
	_stage.queue_free()
	await process_frame
	# MovieWriter 仍在混音时不能直接销毁播放节点，先停止流并等待音频帧清理。
	if is_instance_valid(Sfx._music):
		Sfx._music.stop()
		Sfx._music.stream = null
	for voice in Sfx._voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	await process_frame
	await process_frame
	VerifySupport.cleanup_stores(_stores)
	print("SPELL_CAPTURE_OK cases=", results.size())
	quit(0)
