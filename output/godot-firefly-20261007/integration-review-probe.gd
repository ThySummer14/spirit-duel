extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Battle := preload("res://scripts/ui/battle_screen.gd")
const Theme := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")

func _initialize() -> void: run.call_deferred()
func ready_state(gs):
	for p in gs.players:
		p.hand.clear()
		p.energy = 20
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
func give(gs, owner: int, id: String):
	gs.player(owner).hand.append({"instanceId":"review-%d" % gs.next_card_id,"definitionId":id})
	gs.next_card_id += 1
func click(face):
	var point: Vector2 = face.get_global_transform_with_canvas() * (face.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = point
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		root.push_input(input, true)
func run():
	var stores: String = Support.isolate_stores()
	var gs := GS.create(["yingcao","taohuayao","datiangou","basalt"],["yingcao","taohuayao","datiangou","basalt"], 1999)
	ready_state(gs)
	gs.player(0).units[2].spellsUsed = 10
	give(gs,0,"c10508")
	print("DYNAMIC_HAND ", gs.hand_card_def(0,0).effect, " ACTUAL ", gs.playable_card(0,0).effect)
	gs.play_card(0,0)
	print("DYNAMIC_USED ", Cues.played_card(gs.command_log.back().a).effect)
	gs = GS.create(["yingcao","taohuayao","datiangou","basalt"],["yingcao","taohuayao","datiangou","basalt"], 1999)
	ready_state(gs)
	gs.player(0).units[3].swift = true
	gs.player(0).energy = 0
	give(gs,1,"c10704")
	var done: bool = gs.basic_attack(0,3)
	print("SWIFT_FLASH ", done, " fire=", gs.player(0).energy, " swift=", gs.player(0).units[3].swift, " attack=", gs.player(0).units[3].attack, " foe_hp=",gs.player(1).avatarHp," responses=",gs.rule_events.filter(func(e):return e.kind=="response-card").size(), " stacks=",gs.resolution_stack.size())
	root.theme = Theme.build_theme()
	root.size = Vector2i(1280,800)
	for owner in [0,1]:
		var battle := Battle.new()
		battle.setup(["yingcao","taohuayao","datiangou","basalt"],["yingcao","taohuayao","datiangou","basalt"], 1999)
		battle._ai_thinking = true
		ready_state(battle.gs)
		give(battle.gs,0,"c10701")
		root.add_child(battle)
		await create_timer(0.4).timeout
		click(battle._hand_row.get_child(0))
		click(battle._ally_target_btn if owner==0 else battle._enemy_target_btn)
		print("AVATAR_CLICK ", owner," hp0=",battle.gs.player(0).avatarHp," hp1=",battle.gs.player(1).avatarHp," hand=",battle.gs.player(0).hand.size()," pending=",battle._pending_target_card)
		for i in 3: await process_frame
		await create_timer(battle._presentation_remaining()+0.1).timeout
		battle.queue_free()
		await process_frame
	Support.cleanup_stores(stores)
	quit()
