extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const CP := preload("res://scripts/charged_pair_rules.gd")

var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("OCTET_CROSS_FAIL ", detail)

func game(team: Array, other: Array = ["bingyong", "yaodaoji", "fenghuanghuo", "baizangzhu"]) -> GS:
	var gs := GS.create(team, other, 204269)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.rule_events.clear()
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "octet-cross-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "actual use " + id)

func charge_at(gs, hand: int, target = null) -> void:
	check(CP.request_mode(gs, 0, hand), "open real charging choice")
	check(gs.resolve_divination_choice(0, "charged-store"), "choose charging")
	check(CP.ready_hand(gs, 0) == hand and gs.play_card(0, hand, target), "store selected physical instance")

func charge(gs, id: String, target = null) -> void:
	charge_at(gs, give(gs, id), target)

func blue_release() -> void:
	var gs := game(["yingxueji", "wannianzhu", "shuzhu", "mianqiling"])
	var p: Dictionary = gs.player(0)
	check(gs.VerifiedRules.Mianqiling.set_faction(gs, 0, 2, "青岚"), "real faction API turns beads blue")
	play(gs, "c20705")
	check(int(p.bgBlueCards) == 1, "realm use is first blue card")
	charge(gs, "c26902")
	check(int(p.bgBlueCards) == 1 and p.cardsPlayedThisTurn == 1, "charging cannot announce a second faction card")
	var deck_size: int = p.deck.size()
	var avatar: int = gs.player(1).avatarHp
	play(gs, "c26806", p.units[2].uid)
	check(int(p.bgBlueCards) == 2 and not p.units[2].has("lanternStored"), "early release actually announces the second blue card")
	check(p.deck.size() == deck_size - 1 and p.hand.size() == 2, "existing blue realm draws once and released staff gives one real card")
	check(gs.player(1).avatarHp == avatar - 6, "second-blue projectile2 and bamboo-enhanced real staff attack4 both settle")
	check(gs.rule_events.filter(func(e): return e.kind == "charged-release").size() == 1, "one record causes one release")

func green_release() -> void:
	var gs := game(["jingliuliqian", "wannianzhu", "shuzhu", "huoqumo"])
	var p: Dictionary = gs.player(0)
	var green: Dictionary = p.units[0]
	charge(gs, "c26801", p.units[2].uid)
	check(green.attack == 2 and not green.has("bgGreenTemporary"), "storage does not grant green same-faction use growth")
	play(gs, "c26806", p.units[1].uid)
	check(green.attack == 4 and int(green.bgGreenTemporary) == 2, "breeze and actual released green spell each grant one temporary growth")
	check(p.units[2].attack == 4, "released targeted words uses its stored real target")
	check(gs.end_turn(0), "end the real green turn")
	check(green.attack == 2 and not green.has("bgGreenTemporary"), "both release-related temporary gains expire together")

func purple_aura() -> void:
	var gs := game(["yuanjiulanghu", "wannianzhu", "shuzhu", "rihefang"])
	var p: Dictionary = gs.player(0)
	var fox: Dictionary = p.units[0]
	var beads: Dictionary = p.units[2]
	play(gs, "c20503")
	check(fox.maxHp == 6 and beads.maxHp == 6, "real awakening applies self value and separate purple aura")
	charge(gs, "c26902")
	check(fox.maxHp == 6 and beads.maxHp == 7, "charging growth and faction card growth have separate triggers")
	play(gs, "c26806", beads.uid)
	check(fox.maxHp == 7 and beads.attack == 5 and beads.maxHp == 7, "actual purple release grows fox once alongside bamboo and charge growth")
	gs._knockout_unit(fox, 1, 0); gs._resolve_resolution_stack()
	check(beads.attack == 4 and beads.maxHp == 6, "source knockout removes aura without erasing charging ledger")
	gs._knockout_unit(beads, 1, 0); gs._resolve_resolution_stack()
	gs.VerifiedRules.Peach.revive(gs, 0, 3, beads, false, false)
	check(beads.attack == 2 and beads.maxHp == 5, "later real knockout removes charge growth once after aura removal")

func link_then_charge() -> void:
	var gs := game(["song", "wannianzhu", "yunwaijing", "shuzhu"])
	var p: Dictionary = gs.player(0)
	play(gs, "c24402")
	p.hand.clear()
	p.deck = [
		{"definitionId": "c26801", "instanceId": "octet-bamboo"},
		{"definitionId": "c24202", "instanceId": "octet-floating"},
		{"definitionId": "c26902", "instanceId": "octet-staff"}
	]
	var hand := give(gs, "c24403")
	check(gs.VerifiedRules.Link.start(gs, 0, hand) and gs.pending_choice.instanceIds.size() == 4, "awakened song links all three other real deck owners")
	check(gs.resolve_divination_choice(0, "octet-bamboo"), "choose actual bamboo deck instance")
	charge_at(gs, hand, p.units[3].uid)
	check(p.units[1].lanternStored.instance.instanceId == "octet-bamboo" and p.hand.is_empty(), "linked virtual hand stores the chosen original instance")
	check(p.deck.size() == 3 and not p.deck.any(func(i): return str(i.instanceId) == "octet-bamboo"), "other link choices shuffle back exactly once during storage")
	var floating: Array = p.deck.filter(func(i): return str(i.instanceId) == "octet-floating")
	check(floating.size() == 1 and int(floating[0].get("msLinkPower", 0)) == 1, "unselected floating instance keeps its permanent link enhancement")
	check(p.units[3].attack == 2, "stored linked spell cannot apply its target effect early")
	play(gs, "c26806", p.units[1].uid)
	check(p.units[3].attack == 4 and not p.units[1].has("lanternStored"), "linked charged spell really resolves its target on release")
	check(p.hand.size() == 1 and p.deck.size() == 2 and gs.pending_choice.is_empty(), "release draws once and cannot restart link selection")

func actual_victim_marks() -> void:
	for marked_target in [false, true]:
		var gs := game(["song", "yingcao", "taohuayao", "shuweng"], ["basalt", "yingcao", "taohuayao", "shuweng"])
		var foe: Dictionary = gs.player(1)
		foe.units[0].front = 1
		gs._grow_unit(foe.units[0], 3, 0)
		foe.units[1].hp = 1
		gs.player(0).units[1].yujBreakTurn = gs.turn_counter
		if marked_target: foe.units[1].yujBreakTurn = gs.turn_counter
		play(gs, "c24405", foe.units[1].uid)
		check(foe.avatarHp == 30 - (3 if marked_target else 0), "forced attack reads only actual victim's break mark: " + str(marked_target))
		check(gs.player(0).avatarHp == 30, "same-side mark check cannot spill damage to the other player")
	var gs := game(["song"], ["basalt", "yingcao", "taohuayao", "shuweng", "yujiazhu"])
	gs.player(1).units[0].front = 1
	var target: Dictionary = gs.player(1).units[4]
	gs._grow_unit(target, 0, 20)
	var hp: int = target.hp
	play(gs, "c24405", target.uid)
	check(target.hp == hp - 1 and gs.player(0).units.size() == 1, "actual target index4 never reads unrelated shorter opponent array")

func avatar_guards() -> void:
	var gs := game(["song", "tiaotiaodidi", "taohuayao", "shuweng"], ["basalt", "tiaotiaodidi", "yingcao", "shuweng"])
	var foe: Dictionary = gs.player(1)
	foe.units[0].front = 1
	give(gs, "c11409", 1)
	give(gs, "c11409", 0)
	play(gs, "c24406")
	check(gs.basic_attack(0, 0), "puppet form launches actual attack with nested same-side avatar combat")
	var responses: Array = gs.rule_events.filter(func(e): return e.kind == "response-card" and e.card.id == "c11409")
	check(responses.size() == 1 and responses[0].player == 1 and responses[0].target == "avatar-1", "only actual victim player's avatar guard responds")
	check(foe.hand.is_empty() and gs.player(0).hand.size() == 1 and foe.avatarHp == 30 and gs.player(0).avatarHp == 30, "actual guard blocks nested attack without using other side's card")
	gs = game(["song", "tiaotiaodidi", "taohuayao", "shuweng"], ["basalt", "yingcao", "taohuayao", "shuweng"])
	foe = gs.player(1); foe.units[0].front = 1
	give(gs, "c11409", 0)
	play(gs, "c24406")
	check(gs.basic_attack(0, 0) and gs.player(0).hand.size() == 1 and foe.avatarHp == 29, "other player's guard cannot protect an unguarded same-side target avatar")

func redirected_counter_and_invalid_response() -> void:
	var gs := game(["song", "yingcao", "taohuayao", "shuweng"], ["basalt", "lianyou", "yingcao", "shuweng"])
	for p in gs.players:
		for u in p.units: gs._grow_unit(u, 0, 20)
	var foe: Dictionary = gs.player(1)
	foe.units[0].front = 1
	var hp: int = foe.units[1].hp
	give(gs, "c13305", 1)
	play(gs, "c24405", foe.units[1].uid)
	var counters: Array = gs.rule_events.filter(func(e): return e.kind == "combat-damage-resolved" and e.uid == foe.units[1].uid)
	check(foe.hand.is_empty() and counters.size() == 1 and counters[0].victimPlayer == 0 and counters[0].amount == 5, "weasel response counter uses its actual enemy side after friendly attack")
	check(foe.units[1].hp == hp, "redirecting weasel cannot strike itself due to a coincident target index")
	gs = game(["song", "yingcao", "taohuayao", "shuweng"], ["basalt", "yujiazhu", "yingcao", "shuweng"])
	foe = gs.player(1); foe.units[0].front = 1
	give(gs, "c18904", 1)
	play(gs, "c24405", foe.units[1].uid)
	check(foe.hand.size() == 1 and foe.energy == 40 and gs.rule_events.filter(func(e): return e.kind == "response-card" and e.card.id == "c18904").is_empty(), "enemy-only talisman cannot consume itself on a friendly attacker")

func charged_defence_continues() -> void:
	var gs := game(["wannianzhu", "shuzhu", "song", "taohuayao"], ["basalt", "yingcao", "shuweng", "taohuayao"])
	var p: Dictionary = gs.player(0)
	var foe: Dictionary = gs.player(1)
	p.units[1].front = 1
	for u in foe.units: gs._grow_unit(u, 0, 20)
	charge(gs, "c26904")
	give(gs, "c24404")
	gs.current_player = 1
	check(gs.basic_attack(1, 0), "actual enemy basic attack reaches stored beads defence")
	check(not p.units[1].has("lanternStored") and p.units[1].get("barrier", false), "charged defence first releases and grants real barrier")
	check(gs.pending_choice.get("type") == "ms-beauty" and p.hand.is_empty(), "released defence resumes later legal song response")
	check(gs.pending_choice.get("instanceIds", []).has(foe.units[1].uid) and not gs.pending_choice.get("instanceIds", []).has(foe.units[0].uid), "beauty response preserves actual attacker exclusion")
	var hp: int = foe.units[1].hp
	check(gs.resolve_divination_choice(0, foe.units[1].uid), "real receiver selection completes the continued defence")
	check(gs.pending_choice.is_empty() and p.units[1].get("barrier", false) and p.units[2].front == 1 and foe.units[1].hp == hp - 1, "barrier remains on beads while song transfers real incoming damage")

func _initialize() -> void:
	blue_release()
	green_release()
	purple_aura()
	link_then_charge()
	actual_victim_marks()
	avatar_guards()
	redirected_counter_and_invalid_response()
	charged_defence_continues()
	print("OCTET_CROSS_OK checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
