extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Shuten := preload("res://scripts/shuten_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SHUTEN_FAIL ", message)

func fixture() -> GS:
	var gs := GS.create(["jutun-tongzi", "fenghuanghuo", "yingcao", "basalt"], ["jutun-tongzi", "fenghuanghuo", "yaoginshi", "basalt"], 10209)
	for owner in 2:
		var p := gs.player(owner)
		p.hand.clear()
		p.deck.clear()
		for i in 90: p.deck.append({"instanceId": "deck-%d-%d" % [owner, i], "definitionId": "c10201"})
		p.energy = 30
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
	return gs

func give(gs: GS, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"instanceId": "shuten-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs: GS, owner: int, id: String, target = null) -> void:
	check(gs.play_card(owner, give(gs, owner, id), target), "legal play " + id)

func _initialize() -> void:
	var gs := fixture()
	for i in range(10201,10209): check(ContentLoader.card_def("c%d" % i).get("verifiedRules", false), "verified card %d" % i)
	if not ContentLoader.card_def("c10206").get("verifiedRules", false):
		var before: int = gs.player(0).units[0].attack
		gs._damage_unit(0,0,1,0)
		print("SHUTEN_BASELINE self_damage_attack_before=%d after=%d" % [before, gs.player(0).units[0].attack])
		gs.play_card(0,give(gs,0,"c10206"))
		print("SHUTEN_BASELINE night_parade_ally_hp=%d enemy_hp=%d (received 1 damage; old spell fixed enemy-only 3)" % [gs.player(0).units[1].hp,gs.player(1).units[0].hp])
		quit(1)
		return
	var p := gs.player(0)
	var s: Dictionary = p.units[0]
	check(s.attack == 2 and s.hp == 5, "printed base 2/5")
	p.energy = 0
	play(gs,0,"c10201")
	check(p.energy == 0 and p.deck.size() == 89 and p.hand.size() == 1, "first instant pays no fire and draws once")
	check(s.hp == 4 and s.attack == 3 and Shuten.damage_this_turn(gs,s) == 1, "drunken self damage triggers real base ability")
	check(Shuten.friendly_damage_this_turn(gs,s), "self damage belongs to source player")
	var h := give(gs,0,"c10201")
	check(not gs.can_play_card(0,h).ok and gs.effective_card_cost(0,gs.hand_card_def(0,h)) == 1, "second instant shares quota")
	p.energy = 30
	play(gs,0,"c10204")
	check(s.attack == 7 and s.hp == 6 and s.maxHp == 10, "ghost king installs 5/10 then self-damages four, preserves rage")
	check(Shuten.damage_this_turn(gs,s) == 5, "separate self damage events add actual amounts")
	play(gs,0,"c10203")
	check(s.attack == 8 and s.hp == 8 and s.maxHp == 8 and Shuten.has_unyielding(s), "god form replaces printed body without adding old shape")
	gs._damage_unit(0,0,20,1)
	check(s.hp == 1 and s.attack == 9 and not Shuten.has_unyielding(s), "god survives once and base gains one per event")
	check(Shuten.damage_this_turn(gs,s) == 25, "unyielding still records full 20 damage")
	gs._heal_unit(s,4)
	gs._damage_unit(0,0,20,1)
	check(s.hp == 0 and s.attack == 2 and s.maxHp == 5, "healing cannot restore spent unyielding; knockout clears ordinary rage and form")
	check(Shuten.damage_this_turn(gs,s) == 45, "knockout does not erase this-turn damage history")
	gs.turn_counter += 1
	check(Shuten.damage_this_turn(gs,s) == 0 and not Shuten.friendly_damage_this_turn(gs,s), "any new turn clears history by turn identity")

	gs = fixture(); p = gs.player(0); s = p.units[0]
	s.shield = 4
	gs._damage_unit(0,0,3,1)
	check(s.attack == 2 and s.hp == 5 and Shuten.damage_this_turn(gs,s) == 0, "fully absorbed hit does not trigger rage or history")
	gs._damage_unit(0,0,3,1)
	check(s.attack == 3 and s.hp == 3 and Shuten.damage_this_turn(gs,s) == 2, "only unshielded amount contributes")
	s.barrier = true
	gs._damage_unit(0,0,99,1)
	check(s.attack == 3 and s.hp == 3 and Shuten.damage_this_turn(gs,s) == 2, "barrier blocks event entirely")
	gs._damage_unit(0,0,0,0)
	check(not Shuten.friendly_damage_this_turn(gs,s), "zero self damage does not enable friendly enhancement")
	var c := gs.hand_card_def(0,give(gs,0,"c10208"))
	check(c.value == 2 and c.effects[0].value == 2, "enemy damage never enables fury")
	gs._damage_unit(0,0,1,0)
	c = gs.hand_card_def(0,0)
	check(c.value == 4 and c.effects[0].value == 4, "actual friendly damage enables +4 combat")
	check(ContentLoader.card_def("c10208").value == 2, "dynamic hand enhancement never mutates catalogue")
	var avatar := int(gs.player(1).avatarHp)
	check(gs.play_card(0,0), "enhanced fury legal")
	check(gs.player(1).avatarHp == avatar - 8 and s.attack == 4, "fury is temporary combat bonus added to actual rage")

	gs = fixture(); p = gs.player(0); s = p.units[0]
	play(gs,0,"c10205")
	check(s.awakened and s.attack == 3 and s.hp == 8 and s.maxHp == 8, "awakening prints permanent +1/+3")
	check(ContentLoader.card_def("c10205").type == "spell" and ContentLoader.card_def("c10205").deckLimit == 2, "awakening is two-copy spell")
	play(gs,0,"c10203")
	check(s.attack == 7 and s.hp == 11, "shape preserves permanent awakening body")
	gs._damage_unit(0,0,20,1)
	check(s.hp == 1 and s.attack == 27, "awakened rage includes damage prevented by unyielding")
	play(gs,0,"c10205")
	check(s.attack == 28 and s.hp == 4 and s.maxHp == 14, "second awakening applies printed permanent stats")
	gs._knockout_unit(s)
	check(s.awakened and s.attack == 4 and s.maxHp == 11, "knockout clears rage/form but preserves both awakening bodies")
	s.hp = s.maxHp; s.knockout = 0
	gs._damage_unit(0,0,2,1)
	check(s.attack == 6, "revived source retains awakened replacement ability")

	gs = fixture(); p = gs.player(0); s = p.units[0]
	gs.player(1).units[3].front = 1
	gs.player(1).units[3].attack = 20
	play(gs,0,"c10202")
	check(s.hp == 1 and s.attack == 3, "combat unyielding applies before retaliation and leaves actual rage")
	check(not s.unyielding and not Shuten.has_unyielding(s), "combat keyword expires immediately after battle")
	gs._heal_unit(s,4)
	gs._damage_unit(0,0,20,1)
	check(s.hp == 0, "combat unyielding cannot protect a later spell")

	gs = fixture(); p = gs.player(0); s = p.units[0]
	play(gs,0,"c10203")
	play(gs,0,"c10204")
	check(not Shuten.has_unyielding(s) and s.hp == 6, "changing away from god loses form unyielding")
	play(gs,0,"c10203")
	check(Shuten.has_unyielding(s), "new god form grants new unyielding")
	gs._damage_unit(0,0,1,1)
	check(Shuten.has_unyielding(s), "nonlethal hit does not consume keyword")

	gs = fixture(); p = gs.player(0); s = p.units[0]
	play(gs,0,"c10207")
	gs._damage_unit(0,0,20,1)
	gs._damage_unit(0,0,20,1)
	check(s.hp == 1 and s.attack == 4, "howl survives repeated damage even starting at one HP")
	check(Shuten.damage_this_turn(gs,s) == 40, "howl counts full damage rather than one actual HP loss")
	check(Shuten.minimum_hp(gs,s) == 1 and not s.unyielding, "howl is turn-bound life floor separate from unyielding")
	gs.end_turn(0)
	check(Shuten.minimum_hp(gs,s) == 0 and Shuten.damage_this_turn(gs,s) == 0, "howl and damage total expire before opponent turn")
	gs._damage_unit(0,0,1,1)
	check(s.hp == 0, "damage lethal after howl expiry")
	gs = fixture(); s = gs.player(0).units[0]
	play(gs,0,"c10207")
	gs._knockout_unit(s)
	check(s.hp == 0, "howl does not prevent direct destruction")

	# Opponent-turn automatic response is a real paid spell, before damage.
	gs = fixture(); s = gs.player(1).units[0]
	var e := gs.player(1)
	e.energy = 1
	give(gs,1,"c10207")
	gs._damage_unit(1,0,20,0)
	check(s.hp == 1 and e.energy == 0 and e.hand.is_empty(), "automatic howl pays a fire and consumes card before damage")
	check(Shuten.minimum_hp(gs,s) == 1, "automatic howl stores current opponent turn")
	check(gs.rule_events.any(func(v): return v.kind == "response-card" and v.card.id == "c10207"), "automatic howl follows response event pipeline")
	gs._damage_unit(1,0,20,0)
	check(s.hp == 1 and Shuten.damage_this_turn(gs,s) == 40, "single response protects subsequent events same turn")
	for reason in ["fire", "level", "stun"]:
		gs = fixture(); e = gs.player(1); s = e.units[0]
		give(gs,1,"c10207")
		if reason == "fire": e.energy = 0
		if reason == "level": s.level = 2
		if reason == "stun": s.frozen = 1
		gs._damage_unit(1,0,20,0)
		check(s.hp == 0 and e.hand.size() == 1, "illegal automatic response stays in hand: " + reason)
	gs = fixture(); e = gs.player(1); s = e.units[0]
	give(gs,1,"c10207")
	gs._damage_unit(1,3,20,0)
	check(e.hand.size() == 1 and Shuten.minimum_hp(gs,s) == 0, "damage to teammate cannot trigger source response")

	gs = fixture(); p = gs.player(0); s = p.units[0]
	s.hp = 1
	play(gs,0,"c10201")
	check(s.hp == 0 and p.deck.size() == 89 and p.hand.size() == 1, "self-lethal drunken still finishes its draw effect")
	check(s.attack == 2, "self-lethal rage does not survive knockout")
	gs = fixture(); p = gs.player(0); s = p.units[0]
	s.barrier = true
	play(gs,0,"c10201")
	check(s.hp == 5 and s.attack == 2 and p.deck.size() == 89, "blocked self damage still draws without invented rage")
	check(not Shuten.friendly_damage_this_turn(gs,s), "blocked self damage does not enable fury")
	gs = fixture(); p = gs.player(0); s = p.units[0]
	give(gs,0,"c10207")
	gs._damage_unit(0,0,1,0)
	check(p.hand.size() == 1 and Shuten.minimum_hp(gs,s) == 0, "own turn self damage cannot automatically use howl")
	gs = fixture(); e = gs.player(1); s = e.units[0]
	give(gs,1,"c10207")
	e.nullifyNextCardTurn = gs.turn_counter
	gs._damage_unit(1,0,20,0)
	check(s.hp == 0 and e.hand.is_empty() and e.energy == 29, "countered response still pays and consumes card but grants no floor")
	check(gs.rule_events.any(func(v): return v.kind == "card-nullified" and v.card.id == "c10207"), "response is subject to real card counter pipeline")
	gs = fixture(); e = gs.player(1); s = e.units[0]
	give(gs,1,"c10207"); give(gs,1,"c10207")
	gs._damage_unit(1,0,20,0)
	check(s.hp == 1 and e.hand.size() == 1 and e.energy == 29, "one damage event uses one response without consuming duplicate")

	gs = fixture(); p = gs.player(0); s = p.units[0]; e = gs.player(1)
	play(gs,0,"c10207")
	gs._damage_unit(0,0,10,0)
	var live := gs.hand_card_def(0,give(gs,0,"c10206"))
	check(live.value == 10 and "10点伤害" in live.text, "night parade hand exposes X from actual damage events")
	e.units[2].hp = 0; e.units[2].knockout = 2
	p.units[3].shield = 4
	check(gs.play_card(0,p.hand.size()-1), "night parade with damage legal")
	check(s.hp == 1 and s.attack == 3, "night parade excludes source")
	check(p.units[1].hp == 0 and p.units[2].hp == 0 and p.units[3].hp == 6, "night parade damages every other allied living unit using defenses: %s" % str(p.units.map(func(u): return u.hp)))
	check(e.units[0].hp == 0 and e.units[1].hp == 0 and e.units[3].hp == 2 and e.units[2].knockout == 2, "night parade includes enemy front/reserve and skips dead: %s" % str(e.units.map(func(u): return u.hp)))
	check(p.avatarHp == 30 and e.avatarHp == 30, "night parade never damages either avatar")
	gs = fixture(); p = gs.player(0)
	play(gs,0,"c10206")
	check(p.units[1].hp == 4 and gs.player(1).units[0].hp == 5, "zero damage parade is legal and never substitutes fixed damage")
	check(Shuten.score_card(gs,0,ContentLoader.card_def("c10206"),null) == -100, "AI rejects empty parade")
	p.units[0].hp = 1
	check(Shuten.score_card(gs,0,ContentLoader.card_def("c10201"),null) == -100, "AI avoids self-lethal draw")
	gs = fixture(); p = gs.player(0); s = p.units[0]
	give(gs,0,"c10201")
	check(AI._best_card(gs,0).card_id == "c10201", "AI chooses legal safe self-damage draw")
	s.hp = 1
	check(not AI._best_card(gs,0).ok, "AI integration declines self-lethal draw")
	gs = fixture(); p = gs.player(0); s = p.units[0]
	s.shutenDamageTurn = gs.turn_counter; s.shutenTurnDamage = 10
	for idx in range(1,4): p.units[idx].hp = 0
	give(gs,0,"c10206")
	check(AI._best_card(gs,0).card_id == "c10206", "AI chooses real high-value two-sided area when allies absent")
	for idx in range(1,4): p.units[idx].hp = 1
	for unit in gs.player(1).units: unit.barrier = true
	check(not AI._best_card(gs,0).ok, "AI rejects area that only kills friendly units through enemy barriers")
	gs = fixture(); p = gs.player(0); s = p.units[0]
	give(gs,0,"c10207")
	check(not AI._best_card(gs,0).ok, "AI holds response when source safe in reserve")
	s.hp = 2; s.front = 1
	check(AI._best_card(gs,0).card_id == "c10207", "AI can actively protect an endangered source")
	check(gs.rule_events.size() <= 128, "event log remains bounded")
	print("SHUTEN_RULES checks=%d failures=%d" % [checks,failures])
	if failures == 0: print("SHUTEN_RULES_OK")
	quit(0 if failures == 0 else 1)
