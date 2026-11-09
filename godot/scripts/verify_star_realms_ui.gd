extends SceneTree

const Battle := preload("res://scripts/ui/battle_screen.gd")
const Builder := preload("res://scripts/ui/theme_builder.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("STAR_REALMS_UI_FAIL ", detail)

func click(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
	root.push_input(motion, true)
	await process_frame
	await create_timer(0.15).timeout
	var at := control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func settle(battle) -> void:
	await process_frame
	await process_frame
	await create_timer(battle._presentation_remaining() + 0.18).timeout
	await process_frame

func cards(node: Node) -> Array:
	var found: Array = []
	if node is Control and "data" in node and node.data is Dictionary and node.data.has("id"): found.append(node)
	for child in node.get_children(): found.append_array(cards(child))
	return found

func pick(battle, predicate: Callable) -> Control:
	if not is_instance_valid(battle._choice_layer): return null
	for c in cards(battle._choice_layer):
		if predicate.call(c.data): return c
	return null

func set_hand(battle, ids: Array) -> void:
	var gs = battle.gs
	gs.player(0).hand.clear()
	for id in ids: gs.player(0).hand.append(gs.VerifiedRules.GiftEnergy.fresh_instance(gs, 0, id))
	battle._last_view = {}
	battle._refresh()

func run() -> void:
	var stores := Support.isolate_stores()
	root.theme = Builder.build_theme()
	for dimensions in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = dimensions
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(dimensions)
		var battle := Battle.new()
		battle.setup(["jieshen-suiyuan","baizangzhu-lixin","xiaolunan-qianshou","longche"], ["bingyong","fenghuanghuo","yaohu","xuenv"], 6490)
		battle._ai_thinking = true
		root.add_child(battle)
		var gs = battle.gs
		for p in gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		var shop = gs.VerifiedRules.BattleShop
		shop.gain_bounty(gs, 0, 12)
		battle._last_view = {}
		battle._refresh()
		await settle(battle)
		var button := battle.find_child("BattleShopButton", true, false) as Button
		check(button != null and "赏金12" in button.text, "商店入口显示真实赏金 %s" % dimensions)
		if button != null: await click(button)
		await settle(battle)
		check(gs.pending_choice.get("type") == "stars-shop", "鼠标进入商店")
		var item := pick(battle, func(c): return str(c.id).begins_with("stars-shop-") or c.id == "shengmingjinghua")
		check(item != null and "赏金" in item.data.name and "库存" in item.data.text, "商品显示价格和余量")
		if item != null: await click(item)
		await settle(battle)
		check(int(gs.player(0).hand.size()) == 1 and int(gs.player(0).energy) == 20, "鼠标真实购买且不扣鬼火")
		var close := pick(battle, func(c): return c.id == "shop-close")
		check(close != null, "可以关闭商店")
		if close != null: await click(close)
		await settle(battle)
		check(gs.pending_choice.is_empty(), "鼠标关闭商店并返回战场")
		set_hand(battle, ["c64804"])
		await settle(battle)
		await click(battle._hand_row.get_child(0))
		await settle(battle)
		var discount := pick(battle, func(c): return c.id == "discount")
		check(discount != null, "天降良缘实际打开两项选择")
		if discount != null: await click(discount)
		await settle(battle)
		check(gs.player(0).get("starsBondDiscount", false), "鼠标选择保留降价能力")
		var enemy: Dictionary = gs.player(1).units[0]
		enemy.level = 0
		var summon: Dictionary = gs.player(1).units[1]
		summon.summoned = true
		set_hand(battle, ["c65101"])
		await settle(battle)
		await click(battle._hand_row.get_child(0))
		await settle(battle)
		check(battle._pending_target_card == 0 and gs.valid_targets(0,battle._pending_target_card_def).has(enemy.uid) and not gs.valid_targets(0,battle._pending_target_card_def).has(summon.uid), "守护之道列出零勾式神而不列普通召唤物")
		await click(battle._unit_widget(str(enemy.uid)))
		await settle(battle)
		var marks := Status.unit_marks(enemy)
		check(marks.any(func(m): return m.id == "fox-flame-blue"), "鼠标选靶后狐焰状态可见")
		set_hand(battle, ["c65306"])
		await settle(battle)
		await click(battle._hand_row.get_child(0))
		await settle(battle)
		var frog := pick(battle, func(c): return c.id == "stars-frog-wind")
		check(frog != null, "呱太降临显示可选召唤")
		if frog != null: await click(frog)
		await settle(battle)
		check(gs.front_unit(0).get("starsFrog") == "stars-frog-wind", "鼠标召唤所选呱太")
		set_hand(battle, ["c64801"])
		await settle(battle)
		await click(battle._hand_row.get_child(0))
		await settle(battle)
		var bond: Dictionary = gs.player(0).units[0]
		gs.VerifiedRules.Movement.move_to(gs, 0, gs.front_index(0), 0)
		var house: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, 0, 0, "stars-bond-house", "缘之屋", 6, 6, {"countsAsShikigami":false})
		house.hp = 1
		battle._last_view = {}
		battle._refresh()
		await settle(battle)
		await click(battle._unit_widget(str(bond.uid)))
		check(battle._selected_attacker == 0 and gs.basic_attack_targets(0, 0).has(house.uid), "缘之书普通出击显示己方非式神召唤物")
		await click(battle._unit_widget(str(house.uid)))
		await settle(battle)
		check(int(house.hp) == 1 + int(bond.attack) and gs.front_unit(0).uid == house.uid, "真实鼠标选中缘之屋后改为治疗")
		var deer: Dictionary = gs.player(0).units[2]
		gs._knockout_unit(deer)
		gs._resolve_resolution_stack()
		set_hand(battle, ["stars-deer-strength"])
		await settle(battle)
		check(deer.name == "森之灵" and Status.unit_marks(deer).any(func(m): return m.id == "forest-spirit"), "森之灵及其能量显示")
		await click(battle._hand_row.get_child(0))
		await settle(battle)
		check(gs.pending_choice.get("type") == "movement-burst" and "burst:2" in gs.pending_choice.instanceIds, "森之力从普通手牌入口打开爆能选择")
		battle.queue_free()
		await process_frame
	Support.cleanup_audio()
	Support.cleanup_stores(stores)
	print("STAR_REALMS_UI checks=%d failures=%d" % [checks,failures])
	quit(1 if failures > 0 else 0)
