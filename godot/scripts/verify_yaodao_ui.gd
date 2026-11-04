extends SceneTree
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
var checks := 0
var failures := 0
var out := ""
var completed := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YAODAO_UI_FAIL ", message)

func move(at: Vector2) -> void:
	var input := InputEventMouseMotion.new()
	input.position = at
	root.push_input(input, true)

func click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	move(at)
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = at
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		root.push_input(input, true)

func settled(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.08).timeout
	await process_frame

func capture(name: String) -> void:
	if out.is_empty(): return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func hand(battle, ids: Array) -> void:
	battle.gs.player(0).hand.clear()
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId": "yaodao-ui-%d" % i, "definitionId": ids[i]})
	battle._last_view = {}
	battle._refresh()

func _run() -> void:
	var stores := VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty():
			DisplayServer.window_set_size(physical)
			DisplayServer.window_move_to_foreground()
		var battle := BattleScreen.new()
		battle.setup(["yaodaoji", "yingcao", "basalt", "yaoginshi"], ["yaodaoji", "yingcao", "basalt", "yaoginshi"], 10109)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for unit in p.units:
				unit.level = 3
				unit.passive_hooks = []
		root.add_child(battle)
		var p := battle.gs.player(0)
		var foe := battle.gs.player(1)
		var source: Dictionary = p.units[0]
		hand(battle, ["c10105"])
		await create_timer(0.25).timeout
		click(battle._hand_row.get_child(0))
		check(source.attack == 3 and source.maxHp == 8, "form click uses three/eight body")
		check(source.formRules.get("extraFirstHit", false), "form installs extra-first-hit combat rule")
		check(battle._input_locked(), "form presentation prevents duplicate input")
		await settled(battle)
		check(not battle._input_locked(), "form presentation releases input")
		capture("%d-01-myriad-form" % physical.x)
		hand(battle, ["c10107", "c10103"])
		await create_timer(0.25).timeout
		var energy: int = p.energy
		click(battle._hand_row.get_child(0))
		check(source.awakened and source.attack == 4 and source.maxHp == 9, "awakening click applies real spell and body")
		check(p.energy == energy - 1, "awakening UI has no false instant discount")
		await settled(battle)
		p.energy = 0
		battle._last_view = {}
		battle._refresh()
		await process_frame
		click(battle._unit_widget(str(source.uid)))
		check(battle._selected_attacker == 0, "zero-fire awakened source can be selected to attack")
		await process_frame
		var attack_before: Dictionary = battle.gs.snapshot().duplicate(true)
		click(battle._enemy_target_btn)
		check(foe.avatarHp == 22 and p.energy == 0, "mouse attack resolves both four-point hits with permanent swift")
		check(p.attackUsed, "mouse swift attack spends team attack allowance")
		var direct_hits: Array = Cues.damage_cues(attack_before, battle.gs.snapshot().duplicate(true))
		check(direct_hits.size() == 2, "myriad open-front presentation has two distinct damage cues")
		for i in direct_hits.size():
			var hit: Dictionary = direct_hits[i]
			check(hit.kind == "damage" and hit.amount == 4, "myriad avatar cue retains individual four-point hit")
			check(hit.source == str(source.uid) and hit.target == "" and hit.player == 1, "myriad avatar cue retains actual source and victim")
			check(hit.get("combatStep", -1) == i, "myriad avatar cues preserve first-hit then ordinary-hit order")
		await settled(battle)
		check(battle._hand_row.get_child_count() == 1, "remaining battle card retained")
		check(battle._hand_row.get_child(0).data.cost == 0, "hand displays awakened free-combat cost")
		check("不消耗鬼火" in battle._hand_row.get_child(0).data.text, "hand displays actual temporary discount")
		capture("%d-02-awakened-free-combat" % physical.x)
		attack_before = battle.gs.snapshot().duplicate(true)
		click(battle._hand_row.get_child(0))
		check(foe.avatarHp == 10 and p.energy == 0, "free battle-intent click resolves two six-point hits")
		check(source.attack == 4 and source.shield == 2, "battle bonus ends while unused armor persists")
		direct_hits = Cues.damage_cues(attack_before, battle.gs.snapshot().duplicate(true))
		check(direct_hits.size() == 2, "battle-intent presentation does not merge myriad into one hit")
		for i in direct_hits.size():
			var hit: Dictionary = direct_hits[i]
			check(hit.kind == "damage" and hit.amount == 6 and hit.source == str(source.uid) and hit.player == 1 and hit.target == "", "battle-intent cue preserves six-point amount and actual source")
			check(hit.cardId == "c10103", "battle-intent cues retain originating combat card identity")
			check(hit.get("combatStep", -1) == i, "battle-intent two cues preserve original resolution order")
		await settled(battle)

		p.energy = 20
		hand(battle, ["c10106"])
		await create_timer(0.25).timeout
		var deck: int = p.deck.size()
		click(battle._hand_row.get_child(0))
		check(p.hand.size() == 3 and p.deck.size() == deck, "kill-intent click generates three real cards")
		await settled(battle)
		check(battle._hand_row.get_child_count() == 3, "all generated combat faces are visible")
		for face in battle._hand_row.get_children():
			check(face.data.id in ["c10101", "c10102", "c10103", "c10104", "c10108"], "generated card is from full canonical pool")
			check(face.data.cost == 0, "newly generated combat card inherits current free-combat effect")
		capture("%d-03-generated-combat" % physical.x)

		foe.avatarHp = 30
		foe.units[2].front = 1
		foe.units[2].hp = 3
		hand(battle, ["c10101", "c10108"])
		await create_timer(0.25).timeout
		deck = p.deck.size()
		click(battle._hand_row.get_child(0))
		check(foe.units[2].hp == 0 and foe.avatarHp == 30, "myriad first-hit kill ends battle without spill to avatar")
		check(p.deck.size() == deck - 1, "kill-draw is visible through actual card use")
		await settled(battle)
		check(battle._hand_row.get_child(0).data.value == 2, "imprisoned blade face updates from real source kill")
		check("已消灭1个式神" in battle._hand_row.get_child(0).data.text, "enhanced card face explains actual history")
		capture("%d-04-kill-enhancement" % physical.x)

		# Opponent issues a real command; the UI must show sight-cut before the
		# original combat resumes, without manufacturing another assault.
		hand(battle, ["c10102"])
		p.energy = 1
		for unit in p.units: unit.front = 0
		source.front = 1
		check(battle.gs.end_turn(0), "real turn advance expires previous free-combat effect")
		await settled(battle)
		foe.energy = 20
		foe.attackUsed = false
		foe.levelUpUsed = true
		foe.units[2].hp = 12
		foe.units[2].knockout = 0
		battle._last_view = battle.gs.snapshot().duplicate(true)
		var before: Dictionary = battle._last_view.duplicate(true)
		var start: int = battle.gs.command_log.size()
		var hp: int = source.hp
		check(battle.gs.basic_attack(1, 2), "opponent attack invokes actual automatic response")
		check(source.hp == hp and p.energy == 0 and p.hand.is_empty(), "sight-cut response blocks damage and spends card/fire")
		check(foe.units[2].hp == 2, "defending myriad combines response bonus across both hits")
		var defense_hits: Array = Cues.damage_cues(before, battle.gs.snapshot().duplicate(true))
		check(defense_hits.size() == 3, "defensive myriad presents first hit, blocked assault, and ordinary counter")
		if defense_hits.size() == 3:
			for i in [0, 2]:
				var hit: Dictionary = defense_hits[i]
				check(hit.kind == "damage" and hit.amount == 5, "defensive myriad retains both five-point hits")
				check(hit.source == str(source.uid) and hit.target == str(foe.units[2].uid) and hit.player == 1, "defensive cue attributes damage to defender rather than attacker")
				check(hit.cardId == "c10102", "defensive counter cues retain sight-cut response card identity")
			var blocked: Dictionary = defense_hits[1]
			check(blocked.kind == "guard" and blocked.amount == 0, "sight-cut immunity presents a blocked hit rather than lost HP")
			check(blocked.source == str(foe.units[2].uid) and blocked.target == str(source.uid) and blocked.player == 0, "blocked attack cue preserves incoming source and immune victim")
			check(defense_hits[0].get("combatStep", -1) == 0 and defense_hits[1].get("combatStep", -1) == 1 and defense_hits[2].get("combatStep", -1) == 1, "defensive first hit precedes ordinary simultaneous exchange")
		var timeline: Array = Cues.timeline(before, battle.gs.snapshot().duplicate(true), battle.gs.command_log.slice(start))
		check(not timeline.is_empty() and timeline[0].c == "response_card", "response presentation precedes attack presentation")
		battle._refresh()
		await process_frame
		check(battle._input_locked(), "response timeline locks duplicate input")
		await create_timer(0.45).timeout
		capture("%d-05-sight-cut-response" % physical.x)
		await settled(battle)
		check(not battle._input_locked() and battle.gs.resolution_stack.is_empty(), "response timeline ends with no pending combat")
		battle.queue_free()
		await process_frame
		completed += 1
	if is_instance_valid(Sfx._hub):
		Sfx._music_name = ""
		if is_instance_valid(Sfx._music_tween): Sfx._music_tween.kill()
		Sfx._music_tween = null
		for player in Sfx._hub.get_children():
			if player is AudioStreamPlayer:
				player.stop()
				player.stream = null
		Sfx._streams.clear()
		Sfx._voices.clear()
		Sfx._hub.queue_free()
		Sfx._music = null
		Sfx._hub = null
		await process_frame
		await create_timer(0.25).timeout
	VerifySupport.cleanup_stores(stores)
	check(completed == 2, "both viewport scenarios completed")
	print("YAODAO_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("YAODAO_UI_OK")
	quit(0 if failures == 0 else 1)
