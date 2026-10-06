extends SceneTree
## 真实规则动作驱动的演出回归：已结算目标、响应时序、输入锁和节点生命周期。
const GameState := preload("res://scripts/game_state.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
const SpellEffect := preload("res://scripts/ui/battle_spell_effect.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
var checks := 0
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SPELL_EFFECT_FAIL ", message)

func _fixture(card_id: String) -> GameState:
	var card := ContentLoader.card_def(card_id)
	var gs := GameState.create([card.unitId], ["basalt", "lumen", "rime", "ink"], 80610)
	for p in gs.players:
		p.hand.clear()
		p.energy = 9
		p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	for unit in gs.player(1).units:
		unit.hp = 20
		unit.maxHp = 20
	gs.player(0).hand.append({"instanceId": "fx-" + card_id, "definitionId": card_id})
	return gs

func _snapshot(gs: GameState) -> Dictionary:
	var view := gs.snapshot().duplicate(true)
	view.presentationStack = gs.resolution_stack.duplicate(true)
	return view

func _cast(card_id: String, kind: String, style: String, target_mode := "enemy") -> void:
	var gs := _fixture(card_id)
	var target: Variant = null
	if target_mode == "enemy": target = gs.player(1).units[0].uid
	if target_mode == "ally":
		target = gs.player(0).units[0].uid
		gs.player(0).units[0].hp = 1
	var before := _snapshot(gs)
	_check(gs.play_card(0, 0, target), "legal fixture resolves: " + card_id)
	var after := _snapshot(gs)
	var stamp := JSON.stringify(after)
	var cues := Cues.build(before, after, gs.command_log)
	var relevant: Array = cues.filter(func(c): return c.kind == kind)
	_check(not relevant.is_empty() and relevant.all(func(c): return c.family == style), "%s uses %s after actual %s" % [card_id, style, kind])
	if target_mode in ["enemy", "ally"]:
		_check(relevant.any(func(c): return c.target == target), "resolved target retained for " + card_id)
	_check(JSON.stringify(after) == stamp, "planning does not alter state: " + card_id)
	_check(Cues.build(after, after, []).is_empty(), "layout-only refresh does not replay " + card_id)

func _run() -> void:
	var stores := VerifySupport.isolate_stores()
	root.size = Vector2i(1280, 800)
	root.theme = ThemeBuilder.build_theme()
	_cast("c12404", "damage", "fire")
	_cast("c10605", "damage", "ice")
	_cast("c10603", "freeze", "ice")
	_cast("spark-shot", "damage", "thunder")
	_cast("erode-script", "damage", "ink")
	_cast("erode-script", "seal", "seal")
	_cast("mend", "heal", "heal", "ally")
	_cast("c10801", "heal", "petal", "ally")
	_cast("brace", "shield", "shield", "ally")
	_cast("c10302", "form", "form", "auto")
	_cast("c10107", "awaken", "awaken", "auto")
	_cast("wardline", "realm", "realm", "auto")
	_cast("soul-tithe", "resource", "resource", "auto")
	# 群体伤害必须覆盖全部实际受伤目标；不能只给显式 target 放一个光团。
	var area := _fixture("c10503")
	var initial := _snapshot(area)
	_check(area.play_card(0, 0), "wind area spell resolves")
	var area_cues := Cues.build(initial, _snapshot(area), area.command_log)
	var hits: Array = area_cues.filter(func(c): return c.kind == "damage" and c.player == 1 and not str(c.target).is_empty())
	_check(hits.size() == 4 and hits.all(func(c): return c.family == "wind"), "four real opponents receive wind impacts")
	var blocked := _fixture("c12404")
	blocked.player(1).units[0].shield = 8
	initial = _snapshot(blocked)
	_check(blocked.play_card(0, 0, blocked.player(1).units[0].uid), "shield absorbs the fire spell")
	var guard := Cues.build(initial, _snapshot(blocked), blocked.command_log)
	var blocked_uid: String = blocked.player(1).units[0].uid
	_check(guard.any(func(c): return c.kind == "guard" and c.target == blocked_uid) and not guard.any(func(c): return c.kind == "damage" and c.target == blocked_uid), "absorbed damage shows a guard instead of claiming health loss")
	var form := _fixture("c10306")
	_check(form.play_card(0, 0), "higher-attack form resolves")
	form.player(0).hand = [{"instanceId": "lower-form", "definitionId": "c10302"}]
	initial = _snapshot(form)
	var form_count := form.command_log.size()
	_check(form.play_card(0, 0), "lower-attack form legally replaces the previous one")
	var replaced := Cues.build(initial, _snapshot(form), form.command_log.slice(form_count))
	_check(replaced.any(func(c): return c.kind == "form") and not replaced.any(func(c): return c.kind in ["seal", "damage", "heal"]), "switching forms uses the transformation motif rather than claiming a curse or a hit")
	_verify_response()
	await _verify_native_lifecycle()
	# 每个绘制分支在场景中运行并自动释放，不停留常驻 _process。
	for style in Cues.PALETTES:
		var fx := SpellEffect.new()
		fx.family = style
		fx.origin = Vector2(100, 100)
		fx.destination = Vector2(200, 150)
		root.add_child(fx)
		var ref: WeakRef = weakref(fx)
		await create_timer(0.72).timeout
		_check(ref.get_ref() == null, "effect releases after its tail: " + style)
	VerifySupport.cleanup_stores(stores)
	print("SPELL_EFFECTS checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("SPELL_EFFECTS_OK")
	quit(0 if failures == 0 else 1)

func _verify_response() -> void:
	var gs := GameState.create(["fenghuanghuo"], ["rime"], 80611)
	for p in gs.players:
		p.levelUpUsed = true
		p.energy = 4
		p.units[0].level = 3
	gs.player(0).hand = [{"instanceId": "response-fire", "definitionId": "c12404"}]
	gs.player(1).hand = [{"instanceId": "response-ice", "definitionId": "hoar-barrier"}]
	var before := _snapshot(gs)
	_check(gs.play_card(0, 0, gs.player(1).units[0].uid) and not gs.response_window.is_empty(), "fire waits for a real shield response")
	var waiting := _snapshot(gs)
	_check(not Cues.build(before, waiting, gs.command_log).any(func(c): return c.kind == "damage"), "no impact while an effect is waiting for response")
	var count := gs.command_log.size()
	_check(gs.pass_response(1) and gs.pass_response(0), "both players pass through the actual response window")
	var resolved := Cues.build(waiting, _snapshot(gs), gs.command_log.slice(count))
	_check(resolved.any(func(c): return c.kind == "damage" and c.family == "fire" and c.source == gs.player(0).units[0].uid), "delayed impact keeps the original caster and fire motif")
	# 真正打出响应牌也可能直接恢复原结算；两个来源不能都染成响应者的冰色。
	gs = GameState.create(["fenghuanghuo"], ["rime"], 80614)
	for p in gs.players:
		p.levelUpUsed = true
		p.energy = 4
		p.units[0].level = 3
	gs.player(1).units[0].hp = 20
	gs.player(1).units[0].maxHp = 20
	gs.player(0).hand = [{"instanceId": "responded-fire", "definitionId": "c12404"}]
	gs.player(1).hand = [{"instanceId": "responded-ice", "definitionId": "hoar-barrier"}]
	_check(gs.play_card(0, 0, gs.player(1).units[0].uid), "response-chain fire is legal")
	waiting = _snapshot(gs)
	count = gs.command_log.size()
	_check(gs.play_card(1, 0, gs.player(1).units[0].uid), "response shield is played through the real stack")
	resolved = Cues.build(waiting, _snapshot(gs), gs.command_log.slice(count))
	_check(resolved.any(func(c): return c.kind == "damage" and c.family == "fire" and c.source == gs.player(0).units[0].uid), "a played shield does not replace the original fire caster")

func _click(face: Control) -> void:
	var pos := face.get_global_transform_with_canvas() * (face.size * 0.5)
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = pos
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		root.push_input(input, true)

func _effects(battle: BattleScreen) -> Array:
	return battle._effects.get_children().filter(func(n): return n.get_meta("spell_effect", false))

func _verify_native_lifecycle() -> void:
	var battle := BattleScreen.new()
	battle.setup(["fenghuanghuo", "xuenv", "yingcao", "taohuayao"], ["basalt", "lumen", "rime", "ink"], 80612)
	battle._ai_thinking = true
	root.add_child(battle)
	for p in battle.gs.players:
		p.hand.clear()
		p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	battle.gs.player(0).energy = 9
	battle.gs.player(0).hand = [{"instanceId": "native-fire", "definitionId": "c12404"}]
	battle._last_view = {}
	battle._refresh()
	await create_timer(0.12).timeout
	_click(battle._hand_row.get_child(0))
	_click(battle._unit_widget(str(battle.gs.player(1).units[0].uid)))
	await create_timer(0.32).timeout
	var effects := _effects(battle)
	_check(battle.gs.command_log.size() == 1 and effects.any(func(f): return f.family == "fire"), "viewport card and target clicks start a real fire spell")
	_check(battle._input_locked() and effects.all(func(f): return f.mouse_filter == Control.MOUSE_FILTER_IGNORE), "spell effects preserve the presentation lock and never intercept pointers")
	var ref: WeakRef = weakref(battle.gs)
	battle.setup(["ember", "basalt", "lumen", "rime"], ["storm", "kongo", "frostblade", "ink"], 80613)
	battle._ai_thinking = true
	await create_timer(0.85).timeout
	_check(ref.get_ref() == null and _effects(battle).is_empty() and battle.gs.command_log.is_empty(), "restart releases the old state and prevents delayed effects in the new battle")
	# AI 侧仍展示牌面，然后在命中时刻播放技能，下一步等尾迹结束。
	battle.gs.current_player = 1
	battle.gs.player(1).levelUpUsed = true
	battle.gs.player(1).energy = 9
	for p in battle.gs.players:
		p.hand.clear()
		for unit in p.units: unit.level = 3
	battle.gs.player(1).hand = [{"instanceId": "enemy-spark", "definitionId": "spark-shot"}]
	battle._last_view = {}
	battle._refresh()
	await process_frame
	_check(battle.gs.play_card(1, 0, battle.gs.player(0).units[0].uid), "enemy thunder spell legally resolves")
	await create_timer(0.38).timeout
	_check(_effects(battle).is_empty(), "enemy card is readable before its impact")
	await create_timer(0.4).timeout
	_check(_effects(battle).any(func(f): return f.family == "thunder") and battle._input_locked(), "enemy effect lands during its protected showcase beat")
	await create_timer(0.6).timeout
	_check(_effects(battle).is_empty() and not battle._input_locked(), "enemy tail cleans up before controls resume")
	battle.queue_free()
	await process_frame
