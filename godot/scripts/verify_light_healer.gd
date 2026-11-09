extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Light := preload("res://scripts/light_healer_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("LIGHT_HEALER_FAIL ", text)
func fixture(rivals: Array = ["qingxingdeng", "qingfangzhu", "zuofutongzi", "haifangzhu"]) -> GS:
	var gs := GS.create(["qingxingdeng", "qingfangzhu", "zuofutongzi", "haifangzhu"], rivals, 20261010)
	for p in gs.players:
		p.hand.clear()
		p.energy = 4
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "light-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "play " + id)
func force_dice(gs, first: int, second: int = 0) -> void:
	for seed in 100000:
		var a := (seed * 1664525 + 1013904223) & 0xffffffff
		var b := (a * 1664525 + 1013904223) & 0xffffffff
		if 1 + int(floor(float(a) / 4294967296.0 * 6)) == first and (second == 0 or 1 + int(floor(float(b) / 4294967296.0 * 6)) == second):
			gs.rng_state = seed
			return
	check(false, "dice fixture exists")
func _initialize() -> void:
	_lantern()
	_monk()
	_fortune()
	_interactions()
	_ai()
	print("LIGHT_HEALER checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _lantern() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	p.energy = 0
	play(gs, "c12901")
	check(p.energy == 1 and gs.kw_usage(0, "instant").used, "first lantern grants one free fire")
	play(gs, "mingdeng")
	check(p.energy == 1, "second token pays one fire then gains one")
	p.energy = 0
	check(not gs.can_play_card(0, give(gs, "mingdeng")).ok, "spent instant token not freely usable at zero fire")
	gs = fixture()
	p = gs.player(0)
	p.energy = 2
	play(gs, "c12902")
	check(gs.pending_choice.get("type") == "lantern-choice" and gs.pending_choice.remaining == 2, "night talk repeats once per remaining fire")
	check(not gs.resolve_divination_choice(1, str(gs.pending_choice.instanceIds[0])), "opponent cannot choose")
	check(not gs.resolve_divination_choice(0, "missing"), "hidden card cannot be chosen")
	check(not gs.end_turn(0), "choice blocks ending turn")
	var chosen: String = gs.pending_choice.instanceIds[0]
	check(gs.resolve_divination_choice(0, chosen), "first choice")
	check(p.hand.any(func(i): return i.instanceId == chosen), "chosen moves to hand not top")
	check(gs.pending_choice.remaining == 1, "second choice pending")
	check(gs.resolve_divination_choice(0, str(gs.pending_choice.instanceIds.back())), "second choice")
	check(gs.pending_choice.is_empty() and p.energy == 0 and p.hand.size() == 2, "choice drains fire after all repeats")
	gs = fixture()
	p = gs.player(0)
	var idx := give(gs, "c12903")
	check(not gs.can_play_card(0, idx, p.units[3].uid).ok, "level requires lantern discard")
	give(gs, "mingdeng")
	p.units[3].level = 1
	check(gs.valid_targets(0, gs.hand_card_def(0, idx)) == [p.units[3].uid], "lowest target only")
	check(not gs.can_play_card(0, idx, p.units[0].uid).ok, "cannot raise higher unit")
	check(gs.play_card(0, idx, p.units[3].uid), "lowest levels up")
	check(p.units[3].level == 2 and p.hand.is_empty(), "level consumes exactly the extra lantern")
	give(gs, "mingdeng")
	for u in p.units: u.level = 3
	play(gs, "c12903", p.units[2].uid)
	check(p.hand.size() == 1, "level-three replacement draws one")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c12905")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5, "form has printed body not additive body")
	gs.basic_attack(0, 0)
	check(p.hand.size() == 1 and p.hand[0].definitionId == "mingdeng", "face combat damage creates token")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c12906")
	p.units[0].front = 1
	gs._damage_unit(0, 0, 100, 1, 3)
	check(p.units[0].hp == 5 and p.units[0].knockout == 0 and p.units[0].front == 1 and p.energy == 2, "immortal pays one and returns in original area")
	check(p.units[0].form.cardId == "c12906", "immortal retains form")
	p.energy = 0
	gs._damage_unit(0, 0, 100, 1, 3)
	check(p.units[0].hp == 0, "no fire cannot return")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c12908")
	p.energy = 0
	gs.end_turn(0)
	check(p.energy == 1 and p.hand.any(func(i): return i.definitionId == "mingdeng"), "end fire precedes opponent-start token")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c12909")
	p.energy = 1
	Light.refresh_fire(gs, 0)
	check(p.energy == 3, "awake fire accumulates")
	Light.refresh_fire(gs, 0)
	check(p.energy == 4, "fire storage capped four")
	gs._knockout_unit(p.units[0])
	Light.refresh_fire(gs, 0)
	check(p.energy == 2, "dead lantern cannot preserve fire")
	gs = fixture()
	p = gs.player(0)
	p.energy = 3
	gs.player(1).units[3].front = 1
	gs.player(1).units[3].hp = 3
	play(gs, "c12907")
	check(gs.player(1).units[3].hp == 0 and gs.player(1).avatarHp == 20 and p.energy == 0, "three projections re-evaluate front and clear fire")
func _monk() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	p.avatarHp = 20
	e.avatarHp = 20
	play(gs, "c12501")
	check(p.avatarHp >= 23 and e.avatarHp >= 23, "seal heals both players and opposing monks can react")
	check(gs.rule_events.filter(func(x): return x.kind == "monk-heal-trigger").size() == 2, "each recipient's monk reacts exactly once")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c12502")
	p.units[0].hp = 1
	gs._heal_unit(p.units[0], 2)
	check(p.hand.is_empty(), "unit healing not monk draw trigger")
	gs._heal_avatar(0, 2)
	check(p.hand.is_empty(), "full-health avatar no trigger")
	p.avatarHp = 15
	gs._heal_avatar(0, 2)
	gs._heal_avatar(0, 2)
	check(p.hand.size() == 1, "one draw across two avatar heals same turn")
	gs.turn_counter += 1
	gs._heal_avatar(0, 2)
	check(p.hand.size() == 2, "draw refreshes on each actual turn")
	gs = fixture()
	p = gs.player(0)
	p.avatarHp = 10
	for u in p.units: u.hp = 1
	play(gs, "c12503", "avatar-0")
	check(p.avatarHp == 16, "light target avatar healed twice")
	check(p.units.all(func(u): return int(u.hp) == mini(4, int(u.maxHp))), "light includes all own living units")
	gs = fixture()
	play(gs, "c12505")
	gs.player(1).avatarHp = 20
	play(gs, "c12503", "avatar-1")
	check(gs.player(1).avatarHp == 14, "law converts both enemy avatar heals to damage")
	check(gs.player(1).units.all(func(u): return u.hp == u.maxHp - 3), "law converts enemy team recovery")
	check(gs.rule_events.all(func(x): return x.kind != "monk-heal-trigger"), "converted healing never triggers enemy monk")
	gs = fixture()
	p = gs.player(0)
	p.avatarHp = 20
	play(gs, "c12506")
	check(p.avatarHp == 28 and p.units[1].awakened and p.units[1].maxHp == 8, "awakening heals player and adds printed stats")
	gs.rule_events.clear()
	gs._heal_avatar(0, 1)
	check(gs.rule_events.filter(func(x): return x.kind == "monk-heal-trigger")[0].targets.size() == 5, "awakened healing damages all five enemies")
	gs = fixture()
	p = gs.player(0)
	p.avatarHp = 10
	gs._damage_avatar(0, 1, 1, 0)
	gs._damage_avatar(0, 1, 1, 0)
	gs._damage_avatar(0, 1, 0, 0)
	p.avatarArmor = 4
	gs._damage_avatar(0, 1, 1, 0)
	check(int(p.get("enemyAvatarAttacks", 0)) == 0, "normal rebirth ignores spell, self and blocked damage")
	gs._resolve_combat(1, 0, 0, false, false, false, false)
	check(int(p.get("enemyAvatarAttacks", 0)) == 1, "normal rebirth counts actual avatar combat")
	play(gs, "c12508")
	check(p.avatarHp == 11, "rebirth sets health from actual attack history")
	check(not gs.rule_events.any(func(x): return x.kind == "monk-heal-trigger"), "health setting isn't healing")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c12507")
	check(p.units[1].hp == 0 and p.units[1].knockout > 0, "sacrifice truly knocks out monk")
	check(gs._damage_avatar(0, 100, 1, 0) == 0 and p.avatarHp == 30, "sacrifice immune on same turn")
	gs.turn_counter += 1
	check(gs._damage_avatar(0, 1, 1, 0) == 1, "immunity expires at turn boundary")
	gs = fixture()
	gs.current_player = 1
	p = gs.player(0)
	p.avatarHp = 2
	p.energy = 0
	give(gs, "c12507")
	check(gs._damage_avatar(0, 2, 1, 0) == 0 and p.avatarHp == 2 and p.hand.is_empty(), "lethal response consumes free instant and prevents hit")
	check(p.units[1].hp == 0 and gs.kw_usage(0, "instant").used, "response sacrifices and spends shared allowance")
	gs = fixture()
	gs.current_player = 1
	p = gs.player(0)
	p.energy = 0
	p.avatarHp = 2
	gs.kw_usage(0, "instant").used = true
	give(gs, "c12507")
	gs._damage_avatar(0, 2, 1, 0)
	check(gs.winner == 1 and p.hand.size() == 1, "unpayable response cannot save avatar")
func _fortune() -> void:
	var gs := fixture()
	force_dice(gs, 1, 6)
	check(Light.roll(gs, 0, 4) and gs.kw_usage(0, "fortune").last.rerolled, "base one rerolls to success")
	force_dice(gs, 2, 6)
	check(not Light.roll(gs, 0, 4) and not gs.kw_usage(0, "fortune").last.rerolled, "base failed two never rerolls")
	play(gs, "c13005")
	check(gs.player(0).units[2].attack == 3 and gs.player(0).units[2].maxHp == 8, "normal awakening +1/+3")
	force_dice(gs, 2, 6)
	check(Light.roll(gs, 0, 4), "awake failed two rerolls")
	force_dice(gs, 1, 1)
	check(not Light.roll(gs, 0, 4), "failed reroll never loops")
	check(Light.fortune_total(gs) == 2, "ledger counts only final successful judgments")
	gs._knockout_unit(gs.player(0).units[2])
	force_dice(gs, 1, 6)
	check(not Light.roll(gs, 0, 4), "dead source cannot reroll")
	gs = fixture()
	var p: Dictionary = gs.player(0)
	force_dice(gs, 2, 2)
	play(gs, "c13001")
	check(p.hand.is_empty(), "failed entry judgments draw nothing")
	force_dice(gs, 6, 6)
	Light.form_turn_start(gs, 0, 2)
	check(p.hand.size() == 1 and gs.player(1).hand.size() == 1, "gold rolls independently for both players")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c13002")
	p.avatarHp = 10
	gs.player(1).avatarHp = 10
	force_dice(gs, 6, 6)
	# Monk passive damage uses RNG between the two players, so disable monks here.
	p.units[1].level = 0
	gs.player(1).units[1].level = 0
	Light.form_turn_start(gs, 0, 2)
	check(p.avatarHp == 13 and gs.player(1).avatarHp == 13, "harvest restores player health not entire team")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c13003")
	force_dice(gs, 2)
	gs.basic_attack(0, 0)
	check(p.units[0].frozen == 2, "safety applies to friendly attackers and through next own turn")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c13006")
	force_dice(gs, 2)
	gs.basic_attack(0, 0)
	check(gs.player(1).avatarHp == 30 and p.units[0].attack == 2, "harmony changes combat power only")
	gs = fixture()
	p = gs.player(0)
	p.energy = 1
	force_dice(gs, 2)
	play(gs, "c13004")
	check(p.hand.size() == 1 and p.energy == 0, "fortune spell draws but failed roll grants no fire")
	gs = fixture()
	p = gs.player(0)
	p.energy = 1
	force_dice(gs, 6)
	play(gs, "c13004")
	check(p.hand.size() == 1 and p.energy == 2, "fortune success grants exactly two")
	gs = fixture()
	p = gs.player(0)
	give(gs, "c13007")
	force_dice(gs, 2, 2)
	play(gs, "c13001")
	check(gs.hand_card_def(0, 0).fortuneEnhanced, "form attachment enhances held copy")
	give(gs, "c13007")
	check(not gs.hand_card_def(0, 1).get("fortuneEnhanced", false), "later fresh copy not enhanced retroactively")
	p.energy = 0
	gs.player(1).energy = 0
	check(gs.play_card(0, 0), "enhanced form uses instant at zero fire")
	check(p.energy == 1 and gs.player(1).energy == 1 and p.hand.size() == 2, "entry fire both players and enhanced draw")
	p.energy = 4
	gs.player(1).energy = 0
	play(gs, "c13002")
	check(gs.player(1).energy == 1, "replacing prosperity grants exit fire")
	gs = fixture()
	p = gs.player(0)
	p.avatarHp = 8
	p.fortuneSuccesses = 11
	play(gs, "c13008")
	check(p.avatarHp == 8 and p.hand.is_empty(), "reset has no effect below twelve")
	p.fortuneSuccesses = 12
	p.energy = 1
	gs.player(1).energy = 0
	play(gs, "c13008")
	check(p.avatarHp == 30 and p.hand.size() == 10 and gs.player(1).hand.size() == 10, "reset sets both lives and draws both to ten")
	check(p.energy == 3 and gs.player(1).energy == 3, "reset grants both three fire")
	gs = fixture(["xieenv", "qingfangzhu", "zuofutongzi", "haifangzhu"])
	p = gs.player(0)
	var foe := gs.player(1)
	gs.current_player = 1
	play(gs, "c28408", null, 1)
	check(gs.basic_attack(1, 0) and p.get("avatarToxicPoisoned", false), "scorpion attack actually poisons the defending avatar")
	gs.current_player = 0
	var poisoned_life: int = p.avatarHp
	play(gs, "c12508")
	check(p.avatarHp == poisoned_life, "monk life setting respects the same poisoned avatar")
	p.fortuneSuccesses = 12
	p.energy = 1
	foe.energy = 0
	foe.avatarHp = 12
	play(gs, "c13008")
	check(p.avatarHp == poisoned_life and foe.avatarHp == 30, "fortune reset preserves poisoned avatar life and sets the unpoisoned opponent")
	check(p.hand.size() == 10 and foe.hand.size() == 10 and p.energy == 3 and foe.energy == 3, "both sides still draw to ten and gain three fire")
func _interactions() -> void:
	var gs := fixture()
	play(gs, "c12505")
	gs.VerifiedRules.Tide.heal(gs, 0, 3, 1, -1, 3)
	check(gs.player(1).avatarHp == 27, "law applies to other friendly healers")
	gs = fixture()
	gs.current_player = 1
	gs.player(0).avatarHp = 1
	gs.player(0).energy = 0
	gs.player(0).units[1].frozen = 1
	give(gs, "c12507")
	gs._damage_avatar(0, 1, 1, 0)
	check(gs.winner == 1, "stunned monk cannot respond")
	gs = fixture()
	play(gs, "c12504", gs.player(0).units[0].uid)
	gs._damage_unit(0, 0, 20, 1, 0)
	check(gs.player(0).units[0].hp == 1, "mercy grants actual unyielding")
	gs = fixture()
	play(gs, "c12906")
	gs.player(0).units[0].hp = 1
	gs.VerifiedRules.Combat.strike(gs, 1, 0, 0, 0, 1, {"lethal": true})
	check(gs.player(0).energy == 2 and gs.player(0).units[0].hp == 5, "one lethal strike never kills freshly resurrected unit twice")
	gs = fixture()
	gs.current_player = 1
	gs.player(0).avatarHp = 2
	gs.player(0).avatarArmor = 10
	gs.player(1).units[0].keywords = ["penetration"]
	give(gs, "c12507")
	gs._damage_avatar(0, 2, 1, 0)
	check(gs.winner < 0 and gs.player(0).avatarHp == 2 and gs.player(0).hand.is_empty(), "lethal response accounts for piercing armor removal")
func _ai() -> void:
	var gs := fixture()
	give(gs, "c13008")
	check(not AI._best_card(gs, 0).ok, "AI retains unenhanced reset")
	give(gs, "c12902")
	check(gs.play_card(0, 1), "AI choice fixture")
	var choices := 0
	while not gs.pending_choice.is_empty() and choices < 5:
		check(AI.take_action(gs, 0), "AI resolves repeated choice")
		choices += 1
	check(gs.pending_choice.is_empty(), "AI never stalls in night talk")
	for seed in range(4):
		gs = GS.create(["qingxingdeng", "qingfangzhu", "zuofutongzi", "haifangzhu"], ["qingxingdeng", "qingfangzhu", "zuofutongzi", "yaodaoji"], 13000 + seed)
		for step in 240:
			if gs.winner >= 0: break
			check(AI.take_action(gs, gs.action_player()), "AI legal action")
		check(gs.winner >= 0, "AI match finishes")
