extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CLASSIC_CORE_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["yaodaoji", "jutun-tongzi", "bingyong", "datiangou"], ["yaodaoji", "jutun-tongzi", "bingyong", "datiangou"], 20261007)
	for p in gs.players:
		p.hand.clear()
		p.energy = 30
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
	return gs
func give(gs: GS, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"instanceId":"classic-%d" % gs.next_card_id, "definitionId":id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, owner: int, id: String) -> void:
	check(gs.play_card(owner, give(gs, owner, id)), "legal play " + id)
func _initialize() -> void:
	_multi_hit_rage()
	_serialized_response()
	_nested_damage_response()
	_armor_gateways()
	print("CLASSIC_CORE checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("CLASSIC_CORE_OK")
	quit(0 if failures == 0 else 1)
func _multi_hit_rage() -> void:
	var gs := fixture()
	play(gs, 0, "c10105")
	var attacker: Dictionary = gs.player(0).units[0]
	var defender: Dictionary = gs.player(1).units[1]
	defender.front = 1
	gs._grow_unit(defender, 0, 20)
	var before := gs.snapshot().duplicate(true)
	check(gs.basic_attack(0, 0), "myriad attacks rage source")
	check(defender.hp == 19 and defender.attack == 4, "two hits trigger two separate base rage events")
	check(attacker.hp == 5, "ordinary counter snapshots power after first hit but before normal simultaneous hit")
	var hits := Cues.damage_cues(before, gs.snapshot())
	check(hits.size() == 3 and hits[0].amount == 3 and hits[1].amount == 3 and hits[2].amount == 3, "separate first hit, ordinary hit and retaliation have actual amounts")
	check(hits[0].combatStep == 0 and hits[1].combatStep == 1 and hits[2].combatStep == 1, "preparatory hit precedes ordinary simultaneous pair")
	gs = fixture()
	# Defensive first hit also increases the attacking Shuten's ordinary power.
	gs.current_player = 1
	play(gs, 1, "c10105")
	gs.current_player = 0
	defender = gs.player(1).units[0]
	defender.front = 1
	attacker = gs.player(0).units[1]
	gs._grow_unit(attacker, 0, 10)
	check(gs.basic_attack(0, 1), "rage attacks defensive myriad")
	check(defender.hp == 5 and attacker.hp == 9 and attacker.attack == 4, "defensive first strike changes attacker's ensuing ordinary strike but not earlier hit")
func _serialized_response() -> void:
	var gs := fixture()
	gs.current_player = 1
	play(gs, 1, "c10105")
	gs.current_player = 0
	var defender: Dictionary = gs.player(1).units[0]
	defender.front = 1
	var attacker: Dictionary = gs.player(0).units[1]
	gs._grow_unit(attacker, 0, 20)
	give(gs, 1, "c10102")
	var before := gs.snapshot().duplicate(true)
	gs._resolve_combat(0, 1, 0, false, false, false, false)
	check(gs.resolution_stack.any(func(f): return f.kind == "combat-hit"), "response suspends one genuine combat continuation")
	gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
	gs._resolve_resolution_stack()
	check(defender.hp == 8 and attacker.hp == 17 and attacker.attack == 4, "serialized see-through prevents current combat and gives two defensive hits")
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 28, "form and response each paid exactly once")
	check(gs.resolution_stack.is_empty() and gs.response_window.is_empty(), "response consumes continuation without leaving a second battle")
	var hits := Cues.damage_cues(before, gs.snapshot())
	check(hits.size() == 3 and hits[0].cardId == "c10102" and hits[2].cardId == "c10102", "serialized defensive damage retains response card identity")
	check(hits[1].kind == "guard" and hits[1].source == str(attacker.uid), "prevented attack retains actual opposing source")
	gs._damage_unit(1, 0, 1, 0, 1)
	check(defender.hp == 7, "response immunity does not leak to later spells")
func _nested_damage_response() -> void:
	var gs := fixture()
	var victim: Dictionary = gs.player(1).units[1]
	victim.front = 1
	give(gs, 1, "c10207")
	# Queue a real spell and a later real effect. Howl must resolve before the
	# first hit without dropping the caller's card-complete or later effect.
	var card := ContentLoader.card_def("c10206").duplicate(true)
	card.effects = [{"action":"damage", "target":"enemy-unit", "value":20}, {"action":"draw", "target":"self-player", "value":1}]
	var deck: int = gs.player(0).deck.size()
	gs._push_card_frames(0, "c10206", victim.uid, card, 1, 0, true)
	gs._resolve_resolution_stack()
	check(victim.hp == 1 and gs.player(1).energy == 29 and gs.player(1).hand.is_empty(), "nested howl uses hand and fire before lethal spell damage")
	check(gs.player(0).deck.size() == deck - 1 and gs.resolution_stack.is_empty(), "outer second effect and completion survive nested automatic response")
	check(gs.VerifiedRules.Shuten.damage_this_turn(gs, victim) == 20 and not gs.VerifiedRules.Shuten.friendly_damage_this_turn(gs, victim), "outer damage source survives nested response context")
	var damaged := gs.rule_events.filter(func(e): return e.kind == "damage-resolved")
	check(damaged.size() == 1 and damaged[0].player == 0 and damaged[0].uid == gs.player(0).units[1].uid, "damage presentation retains original spell caster after response")
func _armor_gateways() -> void:
	var gs := fixture()
	var unit: Dictionary = gs.player(0).units[0]
	unit.armorBreak = 4
	play(gs, 0, "c10103")
	check(unit.shield == 0 and unit.armorBreak == 2, "printed battle armor cancels existing armor break immediately")
	gs._apply_encourage(0, 0, 3)
	check(gs.basic_attack(0, 0), "encouraged basic attack is legal")
	check(unit.shield == 1 and unit.armorBreak == 0 and unit.shieldExpires == 1, "encourage gateway retains only net armor and matching expiry")
	gs.player(0).avatarArmorBreak = 5
	check(gs._grant_avatar_armor(0, 3) == 0 and gs.player(0).avatarArmorBreak == 2, "avatar armor first cancels existing status")
	check(gs._grant_avatar_armor(0, 4) == 2 and gs.player(0).avatarArmor == 2, "avatar armor retains only positive remainder")
	gs.VerifiedRules.ArmorBreak.give(gs, 1, 0, 0, -1, 3)
	check(gs.player(0).avatarArmor == 0 and gs.player(0).avatarArmorBreak == 1, "avatar poison removes armor at application")
	gs = fixture()
	unit = gs.player(0).units[2]
	unit.armorBreak = 5
	gs._resolve_one_effect(0, 3, {}, {"action":"shield-next-turn", "value":4}, unit.uid, unit)
	check(unit.shield == 0 and unit.armorBreak == 1, "delayed shield's immediate half uses common cancellation")
	gs.turn_counter += 1
	gs.VerifiedRules.SpellReplay.begin_turn(gs)
	check(unit.shield == 3 and unit.armorBreak == 0 and unit.shieldExpires == 3, "next-turn half cancels residual poison once and grants real remaining armor")
