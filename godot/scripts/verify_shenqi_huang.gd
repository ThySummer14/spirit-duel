extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
const Rules := preload("res://scripts/shenqi_huang_rules.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

const COMBAT := "w13-shenqi-huang-93117"
const FATE := "w13-shenqi-huang-93118"
const TRACK := "w13-shenqi-huang-93119"
const FALL := "w13-shenqi-huang-93120"
const BARRAGE := "w13-shenqi-huang-93121"
const CONSTELLATION := "w13-shenqi-huang-93122"
const PROPHECY := "w13-shenqi-huang-93123"
const HEART := "w13-shenqi-huang-93124"

var checks := 0
var failures := 0

func _initialize() -> void:
	_data()
	_meteor()
	_track_and_fate()
	_prophecy()
	_fall()
	_heart()
	_barrage()
	_constellation()
	_ai()
	print("SHENQI_HUANG checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SHENQI_HUANG_FAIL ", label)

func game() -> GS:
	var gs := GS.create(["shenqi-huang", "shantong", "bingyong", "yaodaoji"], ["jiuciliang", "huang", "shantong", "bingyong"], 93124)
	for p in gs.players:
		p.energy = 30
		p.levelUpUsed = true
		p.hand.clear()
		for u in p.units: u.level = 3
		p.units[0].erase("shenqiMeteors")
	gs.rule_events.clear()
	return gs

func instance(gs: GS, id: String) -> Dictionary:
	return gs.VerifiedRules.Insight.instance(gs, 0, id)

func deck(gs: GS, ids: Array) -> void:
	gs.player(0).deck = ids.map(func(id): return instance(gs, id))

func play(gs: GS, id: String) -> bool:
	gs.player(0).hand.append(instance(gs, id))
	return gs.play_card(0, gs.player(0).hand.size() - 1)

func events(gs: GS, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)

func hp_total(gs: GS, owner: int = 1) -> int:
	var total := int(gs.player(owner).avatarHp)
	for u in gs.player(owner).units: total += int(u.hp)
	return total

func _data() -> void:
	var unit := Content.unit_def(Rules.ID)
	check(unit.attack == 2 and unit.maxHp == 5 and unit.passive.hooks.is_empty(), "authentic body and simplified hooks removed")
	check(Content.cards_for_unit(Rules.ID).size() == 8, "all eight historical slots are playable")
	for id in [COMBAT, FATE, TRACK, FALL, BARRAGE, CONSTELLATION, PROPHECY, HEART]:
		var card := Content.card_def(id)
		check(card.get("verifiedRules", false) and card.deckLimit == 2 and card.cost == 1, "native card " + id)
	check(game().VerifiedRules.Factions.printed({"id": Rules.ID}) == "紫岩", "verified printed faction")

func _meteor() -> void:
	var gs := game()
	var unit: Dictionary = gs.player(0).units[0]
	unit.level = 0
	Rules.unit_turn_start(gs, 0, 0)
	check(Rules.meteors(unit) == 0, "unupgraded base inactive")
	unit.level = 1
	for i in 5: Rules.unit_turn_start(gs, 0, 0)
	check(Rules.meteors(unit) == 3 and events(gs, "charm-attached").size() == 3, "gain caps at three actual attached charms")
	check(gs.basic_attack(0, 0), "basic attack resolves")
	var shots := events(gs, "shenqi-meteor-projectile")
	check(shots.size() == 1 and shots[0].amount == 3 and gs.player(1).avatarHp == 25, "one aggregate projectile then two combat damage")
	var projections := events(gs, "three-tail-projectile")
	check(projections.size() == 1 and projections[0].reason == "陨星" and projections[0].target == "avatar-1", "陨星产生真实投射事件并指向空战斗区后的牌手")
	check(Rules.meteors(unit) == 3, "attack does not spend the charm")
	gs._knockout_unit(unit)
	Rules.unit_turn_start(gs, 0, 0)
	check(Rules.meteors(unit) == 0, "knockout clears and stops new charm")
	for has_meteor in [false, true]:
		gs = game()
		unit = gs.player(0).units[0]
		var defender: Dictionary = gs.player(1).units[0]
		defender.front = 1
		if has_meteor: Rules.attach(gs, 0, 0, 2)
		check(play(gs, COMBAT), "play star strength")
		check(unit.hp == (5 if has_meteor else 3), "combat immunity requires one actual meteor")
		check(Rules.meteors(unit) == (1 if has_meteor else 0), "spend exactly one before the attack")
		check(events(gs, "shenqi-meteor-projectile").size() == (1 if has_meteor else 0), "remaining meteor only")

func _track_and_fate() -> void:
	var gs := game()
	deck(gs, [BARRAGE, COMBAT, "c17801"])
	var p := gs.player(0)
	var original_top: String = p.deck.back().instanceId
	var original_bottom: String = p.deck.front().instanceId
	var hp := hp_total(gs)
	check(play(gs, TRACK), "install track")
	check(p.realms[0].hp == 4 and hp_total(gs) == hp - 2, "entry reveal deals two to a random enemy")
	check(p.hand.is_empty() and Rules.meteors(p.units[0]) == 0 and p.deck.back().instanceId == original_top, "foreign reveal neither draws nor adds meteor")
	check(play(gs, FATE), "free instant reveals actual destiny UI")
	check(gs.pending_choice.get("type") == Fate.KIND and p.energy == 29, "first instant paid zero")
	check(not gs.resolve_divination_choice(1, Fate.REVERSE) and not gs.resolve_divination_choice(0, "garbage"), "reject foreign or stale input")
	check(events(gs, "deck-revealed").size() == 1 and p.hand.is_empty(), "reveal and draw wait for chosen deck positions")
	check(gs.resolve_divination_choice(0, Fate.REVERSE), "reverse resolves original action")
	check(events(gs, "deck-revealed").back().instanceId == original_bottom, "swap is visible to shared reveal event")
	check(p.hand.size() == 2 and p.hand[0].instanceId == original_bottom and p.hand[1].definitionId == COMBAT, "track draws once then fate draws from actual top")
	check(Rules.meteors(p.units[0]) == 1 and int(p.destinyReversed) == 1 and p.deck[0].instanceId == original_top, "track star and reversed record use real deck")
	check(p.realms[0].hp == 4, "trigger does not spend track durability")
	gs = game()
	deck(gs, [COMBAT])
	check(play(gs, FATE) and gs.pending_choice.is_empty() and gs.player(0).hand.size() == 1, "single-card deck auto-continues")

func _prophecy() -> void:
	var gs := game()
	deck(gs, [COMBAT, "c17801"])
	var p := gs.player(0)
	var top: String = p.deck.back().instanceId
	check(play(gs, PROPHECY), "play prophecy")
	check(p.deck.size() == 4 and p.deck[0].definitionId == PROPHECY and p.deck[1].definitionId == PROPHECY, "copies enter actual bottom before choice")
	check(p.deck[0].instanceId != p.deck[1].instanceId and p.deck.back().instanceId == top, "copies have different IDs and old top preserved")
	check(Rules.meteors(p.units[0]) == 2 and events(gs, "deck-revealed").is_empty(), "attachment precedes choice")
	check(gs.resolve_divination_choice(0, Fate.FOLLOW), "confirm unchanged positions")
	check(events(gs, "deck-revealed").back().instanceId == top and p.hand.is_empty() and p.deck.size() == 4, "reveal alone never draws")
	check(play(gs, PROPHECY) and p.energy == 29, "second instant costs one fire")
	check(Rules.meteors(p.units[0]) == 3 and p.deck.size() == 6, "second prophecy only adds one capped meteor")
	check(gs.resolve_divination_choice(0, Fate.REVERSE) and p.deck.back().definitionId == PROPHECY, "newly created bottom can be chosen")

func _fall() -> void:
	var gs := game()
	var unit: Dictionary = gs.player(0).units[0]
	var empty_play := play(gs, FALL)
	check(empty_play and unit.attack == 4 and unit.maxHp == 4, "empty fall prints exact 4/4")
	gs = game()
	unit = gs.player(0).units[0]
	play(gs, HEART)
	Rules.attach(gs, 0, 0, 6)
	check(play(gs, FALL) and unit.attack == 7 and unit.maxHp == 7, "fall spends at most three for real stats")
	check(Rules.meteors(unit) == 3, "excess meteors remain attached")

func _heart() -> void:
	var gs := game()
	var p := gs.player(0)
	var unit: Dictionary = p.units[0]
	check(play(gs, HEART) and unit.awakened and p.realms[0].hp == 5, "heart deploys five durability and awakens")
	check(unit.attack == 2 and unit.maxHp == 5 and not Rules.swift(gs, unit), "no invented stats or swift before attachment")
	Rules.attach(gs, 0, 0, 5)
	check(Rules.meteors(unit) == 5 and Rules.swift(gs, unit), "awakened attachment uncapped and gives swift")
	var fire := int(p.energy)
	check(gs.basic_attack(0, 0) and p.energy == fire and not Rules.swift(gs, unit), "swift is consumed by a free basic attack")
	Rules.attach(gs, 0, 0, 1)
	check(not Rules.swift(gs, unit), "heart once per actual turn")
	gs.turn_counter += 1
	gs._begin_turn(0)
	check(Rules.meteors(unit) == 7 and Rules.swift(gs, unit), "native turn start attaches before ordinary draw")
	var view := Status.unit_view(gs, 0, 0, 0)
	check(Status.unit_marks(view, gs.turn_counter).any(func(mark): return mark.id == "shenqi-meteor" and mark.label.contains("7")), "real battle mark reads state")
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "测试")
	gs.turn_counter += 1
	Rules.unit_turn_start(gs, 0, 0)
	check(unit.awakened and Rules.meteors(unit) == 8 and not Rules.swift(gs, unit), "realm removal preserves awakening and ends future swift grants")

func _barrage() -> void:
	for meteors in [0, 3, 7]:
		var gs := game()
		var unit: Dictionary = gs.player(0).units[0]
		if meteors > 3: play(gs, HEART)
		if meteors > 0: Rules.attach(gs, 0, 0, meteors)
		for u in gs.player(1).units: u.hp = 0
		check(play(gs, BARRAGE), "play barrage")
		var expected := 6 + 2 * mini(5, meteors)
		var packets := events(gs, "damage-resolved").filter(func(e): return e.get("card", {}).get("id") == BARRAGE)
		check(gs.player(1).avatarHp == 30 - expected and packets.size() == expected and packets.all(func(e): return int(e.amount) == 1), "independent one-point spell packets, including avatar")
		check(Rules.meteors(unit) == maxi(0, meteors - 5), "remove up to five")

func _constellation() -> void:
	var gs := game()
	var unit: Dictionary = gs.player(0).units[0]
	deck(gs, [TRACK, COMBAT, FATE])
	check(play(gs, CONSTELLATION) and unit.attack == 5 and unit.maxHp == 8, "install constellation 5/8")
	check(events(gs, "shenqi-constellation").map(func(e): return e.category) == ["spell"], "entry reveal triggers spell branch")
	Rules.attach(gs, 0, 0, 2)
	var hp := hp_total(gs)
	check(gs.basic_attack(0, 0) and hp_total(gs) == hp - 9, "spell branch only doubles the two-point meteor, not the five-power attack")
	Fate.reveal_top(gs, 0, 0)
	gs._resolve_resolution_stack()
	check(events(gs, "shenqi-constellation").size() == 1, "repeat spell category blocked")
	gs.player(0).deck.pop_back()
	var defender: Dictionary = gs.player(1).units[0]
	defender.hp = 25
	defender.maxHp = 25
	defender.baseMaxHp = 25
	defender.front = 1
	Fate.reveal_top(gs, 0, 0)
	gs._resolve_resolution_stack()
	check(unit.hp == 8 and defender.hp == 16, "combat reveal fires one immune attack with current meteor crit")
	gs.player(0).deck.pop_back()
	Fate.reveal_top(gs, 0, 0)
	gs._resolve_resolution_stack()
	check(Rules.meteors(unit) == 3 and events(gs, "shenqi-constellation").map(func(e): return e.category) == ["spell", "combat", "other"], "remaining category independently attaches stars")
	gs.current_player = 1
	gs.turn_counter += 1
	Fate.reveal_top(gs, 0, 0)
	gs._resolve_resolution_stack()
	check(events(gs, "shenqi-constellation").size() == 3, "enemy-turn reveal does not fire form")
	gs.current_player = 0
	gs.turn_counter += 1
	deck(gs, [COMBAT, FATE])
	gs._begin_turn(0)
	check(events(gs, "shenqi-constellation").size() == 4 and events(gs, "deck-revealed").back().card.id == FATE, "next own turn reveals before normal draw and refreshes categories")

func _ai() -> void:
	var gs := game()
	deck(gs, [FATE, "c17808"])
	var p := gs.player(0)
	p.hand.append(instance(gs, FATE))
	check(AI.take_action(gs, 0) and gs.pending_choice.get("type") == Fate.KIND, "AI uses legal hand entry")
	check(AI.take_action(gs, 0) and gs.pending_choice.is_empty() and p.hand[0].definitionId == FATE and int(p.destinyReversed) == 1, "AI legally reverses and resumes actual draw")
