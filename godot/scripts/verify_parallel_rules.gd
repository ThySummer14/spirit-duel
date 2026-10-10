extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PARALLEL_FAIL ", message)

func fixture() -> GS:
	var gs := GS.create(["fenghuanghuo", "taohuayao", "yingcao", "basalt"], ["fenghuanghuo", "taohuayao", "yingcao", "basalt"], 20261007)
	for p in gs.players:
		p.hand.clear()
		p.energy = 20
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
	return gs

func give(gs: GS, owner: int, card: String) -> int:
	gs.player(owner).hand.append({"instanceId": "parallel-%d" % gs.next_card_id, "definitionId": card})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func _initialize() -> void:
	_serialized_entry()
	_response_types()
	_mixed_lifecycle()
	_card_snapshot()
	_mixed_damage_sources()
	_enhanced_hand_snapshot()
	print("PARALLEL_RULES checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("PARALLEL_RULES_OK")
	quit(0 if failures == 0 else 1)

func _serialized_entry() -> void:
	for guarded in [false, true]:
		var gs := fixture()
		var source: Dictionary = gs.player(0).units[0]
		var defender: Dictionary = gs.player(1).units[3]
		defender.front = 1 if guarded else 0
		give(gs, 1, "c10704")
		gs._apply_encourage(0, 2, 2)
		var before := gs.snapshot()
		gs._record("basic_attack", {"unit": 0}, 0)
		gs._resolve_combat(0, 0, 3, false, false, false, false, null, false, {"basicAttack": true})
		check(gs.resolution_stack.any(func(f): return f.kind == "combat-entered"), "entry response suspends original combat")
		gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
		gs._resolve_resolution_stack()
		check(source.attack == 0, "serialized entry applies flash")
		check(gs.player(1).avatarHp == 30 and defender.hp == defender.maxHp, "response zeros current bonus and encouragement before damage")
		check(int(source.get("phoenixAvatarHits", 0)) == 0, "prevented attack never enhances phoenix dance")
		check(gs.kw_usage(0, "encourage").attack == 0 and gs.kw_usage(0, "encourage").shield == 0, "encouragement consumed only once")
		check(gs.player(1).energy == 19 and gs.player(1).hand.is_empty(), "one flash response paid once")
		var timeline := Cues.timeline(before, gs.snapshot(), gs.command_log.slice(int(before.commands)))
		check(timeline.size() == 2 and timeline[0].c == "response_card" and timeline[1].c == "basic_attack", "response precedes original attack for unit and avatar")
		gs.end_turn(0)
		check(source.attack == source.baseAttack, "temporary zero cleared when attacking turn ends")

func _response_types() -> void:
	var gs := fixture()
	for id in ["c12407", "c10701", "c10708"]:
		var card := ContentLoader.card_def(id)
		var frame := {"cardOverride": card, "definitionId": id, "effectIndex": 0, "playerIndex": 0, "targetId": gs.player(1).units[3].uid}
		check(gs._create_response_window(frame).action == "damage", "custom enemy damage retains response category " + id)
		if id == "c10708":
			frame.targetId = gs.player(0).units[3].uid
			check(gs._create_response_window(frame).action == "buff-stats", "friendly light is growth not damage")

func _mixed_lifecycle() -> void:
	var gs := fixture()
	var ally: Dictionary = gs.player(0).units[3]
	check(gs.play_card(0, give(gs, 0, "c10809")), "peach awakening")
	ally.hp = 4
	check(gs.play_card(0, give(gs, 0, "c10801"), ally.uid), "permanent peach restoration")
	check(gs.play_card(0, give(gs, 0, "c10708"), ally.uid), "temporary firefly health")
	check(ally.maxHp == 15 and ally.attack == 3, "temporary and permanent growth combine")
	gs._knockout_unit(ally)
	check(ally.maxHp == 14 and ally.attack == 3 and ally.hp == 0, "knockout drops only temporary light growth")
	check(gs.play_card(0, give(gs, 0, "c10808"), ally.uid), "revive with permanent growth and swift")
	check(ally.maxHp == 16 and ally.hp == 16 and ally.attack == 5 and ally.swift, "permanent restoration and swift coexist")
	gs.player(0).energy = 0
	check(gs.basic_attack(0, 3) and not ally.swift and gs.player(0).energy == 0, "real zero-fire ordinary attack consumes swift")

func _card_snapshot() -> void:
	var gs := fixture()
	var source: Dictionary = gs.player(0).units[0]
	source.phoenixAvatarHits = 2
	check(gs.play_card(0, give(gs, 0, "c12405")), "enhanced dance plays")
	var command: Dictionary = gs.command_log.back()
	var display := Cues.played_card(command.a)
	check(int(display.value) == 7, "played-card display records pre-cast enhancement")
	check(int(source.phoenixAvatarHits) == 4, "spell and passive damage keep independent history")
	check(int(display.value) == 7 and int(ContentLoader.card_def("c12405").value) == 5, "animation and catalogue don't absorb later live history")

func _mixed_damage_sources() -> void:
	var gs := fixture()
	gs.player(0).units[0].awakened = true
	var before := gs.snapshot().duplicate(true)
	check(gs.play_card(0, give(gs, 0, "c10701"), gs.player(1).units[3].uid), "teammate spell triggers independent phoenix damage")
	var hits := Cues.build(before, gs.snapshot(), gs.command_log).filter(func(c): return c.kind == "damage")
	check(hits.size() == 2, "two actual damage instances keep separate cues")
	check(hits[0].source == gs.player(0).units[2].uid and hits[0].target == gs.player(1).units[3].uid and hits[0].amount == 2 and hits[0].family != "fire", "teammate spell retains its own source and target")
	check(hits[1].source == gs.player(0).units[0].uid and hits[1].target == "" and hits[1].amount == 1 and hits[1].family == "fire", "later projectile belongs only to phoenix")
	gs = fixture()
	before = gs.snapshot().duplicate(true)
	check(gs.play_card(0, give(gs, 0, "c12401")), "same-target consecutive spell and ability")
	hits = Cues.build(before, gs.snapshot(), gs.command_log).filter(func(c): return c.kind == "damage")
	check(hits.size() == 2 and hits[0].amount == 2 and hits[1].amount == 1, "same avatar receives distinct two then one, not fabricated combined damage")

func _enhanced_hand_snapshot() -> void:
	var gs := GS.create(["datiangou"], ["basalt"], 10508)
	gs.player(0).hand.clear()
	gs.player(0).energy = 3
	gs.player(0).levelUpUsed = true
	gs.player(0).units[0].level = 3
	gs.player(0).units[0].spellsUsed = 10
	var hand := give(gs, 0, "c10508")
	check(gs.hand_card_def(0, hand).effect == "destroy-enemy-units", "hand and hover use the enhanced execution view")
	check(gs.play_card(0, hand), "enhanced storm cast")
	check(Cues.played_card(gs.command_log.back().a).effect == "destroy-enemy-units", "played animation keeps enhanced card snapshot")
