extends SceneTree
## Conventional battles must not inherit card changes restricted to arena mode.
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MODE_SCOPE_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["qingfangzhu", "zuofutongzi", "yaodaoji", "yingcao"], ["yaodaoji", "fenghuanghuo", "guniao", "bingyong"], 20261013)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "mode-scope-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func _initialize() -> void:
	var awakening := Content.card_def("c13005")
	check(int(awakening.level) == 3, "normal zashiki awakening remains level three")
	check(int(awakening.value.attack) == 1 and int(awakening.value.hp) == 3, "normal awakening remains +1/+3")
	var gs := fixture()
	gs.player(0).units[1].level = 2
	check(not gs.can_play_card(0, give(gs, "c13005")).ok, "normal two-level source cannot awaken")
	gs.player(0).units[1].level = 3
	check(gs.play_card(0, 0), "three-level source may awaken")
	check(gs.player(0).units[1].maxHp == 8, "printed life gain applied")
	gs = fixture()
	var p: Dictionary = gs.player(0)
	p.avatarHp = 10
	gs._damage_avatar(0, 1, 1, 1)
	gs._damage_avatar(0, 1, 0, 0)
	check(int(p.get("enemyAvatarAttacks", 0)) == 0, "spell and self damage never count as attacks")
	gs.current_player = 1
	p.avatarArmor = 100
	check(gs.basic_attack(1, 0), "actual armored avatar attack")
	check(p.avatarHp == 8 and int(p.get("enemyAvatarAttacks", 0)) == 1, "fully absorbed attack counts once")
	gs.player(1).units[0].formRules = {"combatKeywords": ["combo"]}
	check(gs.play_card(1, give(gs, "c10101", 1)), "combo attacks avatar")
	check(int(p.get("enemyAvatarAttacks", 0)) == 2, "combo damage strikes share one attack history entry")
	p.monkImmuneTurn = gs.turn_counter
	check(gs.play_card(1, give(gs, "c10101", 1)), "attack against sacrifice immunity")
	check(int(p.get("enemyAvatarAttacks", 0)) == 3 and p.avatarHp == 8, "immune avatar still was attacked")
	p.units[2].front = 1
	p.units[2].hp = 100
	check(gs.play_card(1, give(gs, "c10101", 1)), "attack a defending unit")
	check(int(p.get("enemyAvatarAttacks", 0)) == 3, "unit combat is not an avatar attack")
	p.units[2].front = 0
	gs.player(1).units[0].attack = 0
	gs.player(1).units[0].formRules = {"zeroPowerEnemyTurn": true}
	gs.current_player = 0
	gs._resolve_combat(1, 0, 0, false, false, false, false)
	check(p.avatarHp == 8, "zero-power avatar combat causes no damage")
	check(int(p.get("enemyAvatarAttacks", 0)) == 4, "zero-power attack counts without fabricating damage")
	p.erase("monkImmuneTurn")
	gs.current_player = 0
	p.avatarHp = 10
	check(gs.VerifiedRules.Light.score_card(gs, 0, Content.card_def("c12508"), null) == 24, "AI recovery score uses the same four attack events")
	check(gs.play_card(0, give(gs, "c12508")), "normal rebirth uses attack history")
	check(p.avatarHp == 14, "normal rebirth ignores spell events and repeated damage strikes")
	check(not gs.rule_events.any(func(e): return e.kind == "monk-heal-trigger"), "setting life never triggers recovery ability")
	gs.players = JSON.parse_string(JSON.stringify(gs.players))
	check(int(gs.player(0).get("enemyAvatarAttacks", 0)) == 4, "attack history survives JSON roundtrip")
	print("MODE_SCOPE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
