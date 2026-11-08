extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Support := preload("res://scripts/verify_support.gd")

func game(other: Array = ["basalt", "tiaotiaodidi", "yingcao", "shuweng"]):
	var gs := GS.create(["song", "yingcao", "taohuayao", "shuweng"], other, 77911)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs

func give(gs, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "victim-probe-%d" % gs.next_card_id}); gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func _initialize() -> void:
	var stores := Support.isolate_stores()
	var gs = game()
	gs.player(1).units[0].front = 1
	gs.player(0).units[1].yujBreakTurn = gs.turn_counter
	gs._grow_unit(gs.player(1).units[1], 0, 20)
	var initial: int = gs.player(1).units[1].hp
	var play: bool = gs.play_card(0, give(gs, 0, "c24405"), gs.player(1).units[1].uid)
	print("YUJ_SAME_VICTIM played=", play, " own-mark=", gs.player(0).units[1].yujBreakTurn, " victim-before=", initial, " victim-after=", gs.player(1).units[1].hp, " attacker-attack=", gs.player(1).units[0].attack, " face=", gs.player(1).avatarHp)
	gs = game()
	var defender: Dictionary = gs.player(1)
	print("GUARD_SOURCE id=", defender.units[1].id)
	defender.units[0].front = 1
	give(gs, 1, "c11409")
	var form: bool = gs.play_card(0, give(gs, 0, "c24406"))
	var attack: bool = gs.basic_attack(0, 0)
	print("PUPPET_GUARD form=", form, " attack=", attack, " enemy-hand=", defender.hand.size(), " enemy-face=", defender.avatarHp, " own-face=", gs.player(0).avatarHp, " response-events=", gs.rule_events.filter(func(e): return e.kind == "response-card"))
	gs = game(["basalt", "lianyou", "yingcao", "shuweng"])
	defender = gs.player(1)
	for p in gs.players:
		for u in p.units: gs._grow_unit(u, 0, 20)
	defender.units[0].front = 1
	give(gs, 1, "c13305")
	play = gs.play_card(0, give(gs, 0, "c24405"), defender.units[1].uid)
	print("WEASEL_COMMAND play=", play, " redirects=", gs.rule_events.filter(func(e): return e.kind == "movement-redirect"), " hits=", gs.rule_events.filter(func(e): return e.kind == "combat-damage-resolved"))
	gs = game(["basalt", "yujiazhu", "yingcao", "shuweng"])
	defender = gs.player(1)
	defender.units[0].front = 1
	give(gs, 1, "c18904")
	play = gs.play_card(0, give(gs, 0, "c24405"), defender.units[1].uid)
	print("YUJ_FRIENDLY_ATTACKER play=", play, " hand=", defender.hand.size(), " energy=", defender.energy, " attacker-frozen=", defender.units[0].frozen, " response-count=", gs.rule_events.filter(func(e): return e.kind == "response-card").size())
	Support.cleanup_stores(stores)
	quit()
