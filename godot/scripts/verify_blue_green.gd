extends "res://scripts/verify_book_jue_ui.gd"

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const BG := preload("res://scripts/blue_green_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BLUE_GREEN_FAIL ", detail)

func game(own: Array = ["yingxueji", "jingliuliqian", "mianqiling", "taohuayao"]) -> GS:
	var gs := GS.create(own, ["bingyong", "fenghuanghuo", "yaodaoji", "baizangzhu"], 206207)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3; u.charge = 0
	gs.rule_events.clear()
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "bg-test-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	var h := give(gs, id, owner)
	var legal: Dictionary = gs.can_play_card(owner, h, target)
	check(gs.play_card(owner, h, target), "actual use " + id + " " + str(legal.get("reason", "")))

func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)

func faction(gs, wanted: String, owner: int = 0) -> void:
	for u in gs.player(owner).units: u.factionOverride = wanted
	BG.refresh(gs)

func deck(gs, ids: Array) -> void:
	gs.player(0).deck.clear()
	for id in ids:
		gs.player(0).deck.append({"definitionId": str(id), "instanceId": "bg-deck-%d" % gs.next_card_id})
		gs.next_card_id += 1

func finish(gs) -> void:
	var guard := 0
	while not gs.pending_choice.is_empty() and guard < 30:
		guard += 1
		check(AI._resolve_choice(gs, 0), "actual AI completes " + str(gs.pending_choice.get("type", "")))
	check(guard < 30, "choices terminate")

func definitions_and_targets() -> void:
	var gs := game()
	check(gs.player(0).units[0].attack == 2 and gs.player(0).units[0].maxHp == 5 and gs.player(0).units[1].attack == 2 and gs.player(0).units[1].maxHp == 5, "printed blue and green 2/5 bodies")
	check(gs.player(0).units[0].passive_hooks.is_empty() and gs.player(0).units[1].passive_hooks.is_empty(), "old numeric passive mappings removed")
	for role in [206, 207]:
		for number in range(1, 9):
			var id := "c%d%02d" % [role, number]
			var card := Content.card_def(id)
			check(card.get("blueGreenRules", false) and not card.get("effects", []).is_empty(), "real card dispatcher " + id)
			check(FileAccess.file_exists("res://assets/official/cards/%s.png" % id) and not card.get("verificationPending", []).is_empty(), "original PNG and client pending boundary " + id)
	check(not Content.card_def("c20602").get("verifiedRules", true) and Content.card_def("c20602").get("bgMingchePool", []).is_empty(), "unresolved Mingche pool is explicit and cannot count as restored")
	check(Content.card_def("julijialuo-wan").effects[0].action == "bg-kurikara" and Content.card_def("julijialuo-wan").keywords.has("instant"), "derived card uses actual stunned-enemy area rule")
	var h := give(gs, "c20701")
	var foe: Dictionary = gs.player(1)
	foe.units[1].keywords = ["veil"]
	var ids := gs.valid_targets(0, gs.hand_card_def(0, h))
	check(ids.has(foe.units[0].uid) and ids.has(gs.player(0).units[0].uid) and not ids.has(foe.units[1].uid) and not ids.has("avatar-1"), "intent targets either side's shikigami and respects enemy veil")
	check(not gs.play_card(0, h, foe.units[1].uid) and gs.player(0).energy == 40 and gs.player(0).hand.size() == 1, "illegal veil target costs no fire or card")

func blue_counter_and_derivative() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	foe.units[0].front = 1
	play(gs, "c20701", foe.units[1].uid)
	check(events(gs, "three-tail-projectile").is_empty() and int(foe.units[1].frozen) > 0 and p.hand.size() == 1 and p.hand[0].definitionId == "julijialuo-wan", "first blue card stuns and generates one real derivative without second-card projectile")
	var hp := int(foe.units[0].hp)
	play(gs, "c20701", foe.units[2].uid)
	check(events(gs, "three-tail-projectile").size() == 1 and foe.units[0].hp == hp - 2 and int(p.bgBlueCards) == 2, "second actual blue card projects exactly two damage")
	play(gs, "c20701", foe.units[3].uid)
	check(events(gs, "three-tail-projectile").size() == 1 and int(p.bgBlueCards) == 3, "third blue card cannot repeat second-card ability")
	check(gs.end_turn(0) and gs.end_turn(1), "real turn cycle resets per-turn counter")
	play(gs, "c20701", foe.units[1].uid)
	check(events(gs, "three-tail-projectile").size() == 1, "new turn's first card is not second")
	play(gs, "c20701", foe.units[2].uid)
	check(events(gs, "three-tail-projectile").size() == 2, "new turn's second card triggers once again")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c20701", foe.units[0].uid)
	foe.units[1].frozen = 1; foe.units[1].keywords = ["veil"]
	var before: Array = foe.units.map(func(u): return int(u.hp))
	var fire := int(p.energy)
	check(gs.play_card(0, 0), "use generated actual Kurikara")
	check(foe.units[0].hp == before[0] - 2 and foe.units[1].hp == before[1] - 2 and foe.units[2].hp == before[2] and foe.units[3].hp == before[3], "Kurikara hits all stunned enemies including veil, excludes unstunned and friendly targets")
	check(p.energy == fire and gs.kw_usage(0, "instant").used and int(p.bgBlueCards) == 2 and events(gs, "three-tail-projectile").size() == 1 and foe.avatarHp == 28, "actual blue-source derivative uses first instant and really triggers the second-card projectile")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c20701", foe.units[1].uid)
	gs._knockout_unit(p.units[0], 1, 0); gs._resolve_resolution_stack()
	play(gs, "c20801", p.units[2].uid); check(gs.resolve_divination_choice(0, "青岚"), "actual other blue source resolves faction choice")
	check(events(gs, "three-tail-projectile").is_empty(), "knocked blue source cannot fire its passive on another ally's card")

func blue_forms_and_realms() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs, "c20702")
	check(u.attack == 2 and u.maxHp == 5 and gs.VerifiedRules.SunSmoke.has_charge(u) and u.charge == 0, "eye form installs printed body and native charging")
	play(gs, "c20701", foe.units[1].uid)
	check(u.charge == 1, "eye charges from second blue card rather than every spell")
	play(gs, "c20701", foe.units[2].uid)
	check(u.charge == 1, "third blue spell grants no fabricated charge")
	u.charge = 4; foe.units[0].front = 1
	check(gs.end_turn(0), "real turn end pays eye ability")
	check(u.charge == 0 and int(foe.units[0].frozen) > 0 and events(gs, "bg-eye-stun").size() == 1, "eye spends exactly four and stuns actual projectile front")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]
	play(gs, "c20702"); u.charge = 3; var hp := int(foe.avatarHp)
	gs.end_turn(0)
	check(u.charge == 3 and int(foe.get("avatarFrozen", 0)) == 0 and foe.avatarHp == hp, "insufficient energy cannot stun or create damage")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]
	play(gs, "c20702"); u.charge = 4; gs.end_turn(0)
	check(u.charge == 0 and int(foe.avatarFrozen) > 0, "empty front makes eye projection stun the avatar")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	var count: int = p.deck.size(); play(gs, "c20705")
	check(p.deck.size() == count, "new red-sakura realm cannot draw retroactively for its own announcement")
	play(gs, "c20701", foe.units[0].uid)
	check(p.deck.size() == count - 1, "existing realm draws once after second blue card")
	play(gs, "c20701", foe.units[1].uid)
	check(p.deck.size() == count - 1, "realm does not draw again for third blue card")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]
	var h := give(gs, "c20704"); var c: Dictionary = gs.hand_card_def(0, h)
	check(c.value.attack == 4 and c.value.hp == 6 and c.enhanced, "painted-revival form counts only the other living blue teammate")
	check(gs.play_card(0, h) and gs.VerifiedRules.Combat.has(u, "remote"), "real form grants remote at installed body")
	foe.units[0].front = 1; gs._grow_unit(foe.units[0], 0, 20); var life := int(u.hp)
	check(gs.basic_attack(0, 0) and int(u.front) == 0 and u.hp == life, "remote actual attack leaves caster in reserve without counterdamage")

func blue_draw_and_freehand() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	faction(gs, "青岚"); deck(gs, ["c11901", "c11902", "c11903", "c11904"])
	play(gs, "c20703")
	check(gs.pending_choice.get("type") == "native-divination" and gs.pending_choice.count == 2 and p.deck.size() == 4 and p.hand.is_empty(), "pure-blue outline pauses at real divination2 before drawing")
	var bottom := str(gs.pending_choice.instanceIds[0])
	check(gs.resolve_divination_choice(0, bottom) and gs.resolve_divination_choice(0, gs.VerifiedRules.Divination.BOTTOM), "player actually bottoms the inspected card")
	finish(gs)
	check(p.hand.size() == 2 and p.deck.size() == 2 and not p.hand.any(func(i): return str(i.instanceId) == bottom), "outline subsequent actual draws respect player's changed deck order")
	gs = game(); p = gs.player(0); deck(gs, ["c11901", "c11902", "c11903"])
	play(gs, "c20703")
	check(gs.pending_choice.is_empty() and p.hand.size() == 2, "mixed-team outline draws two without fabricated divination")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	p.units[3].frozen = 1; foe.units[2].frozen = 1; var avatar_hp := int(foe.avatarHp)
	play(gs, "c20707")
	check(p.units[3].hp == 0 and foe.units[2].hp == 0 and foe.units.filter(func(u): return int(u.hp) == 0).size() >= 1, "freehand really destroys all stunned shikigami on both sides after its random stun")
	check(foe.avatarHp == avatar_hp and p.units[0].hp > 0, "freehand is destruction, not avatar damage or allied blanket knockout")

func faction_auras() -> void:
	for entry in [["yingxueji", "c20706", "青岚"], ["jingliuliqian", "c20606", "苍叶"]]:
		var gs := game([entry[0], "shantu", "mianqiling", "taohuayao"])
		var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]; var ally: Dictionary = p.units[1]
		ally.factionOverride = entry[2]; BG.refresh(gs)
		var attack := int(ally.attack); var hp := int(ally.maxHp)
		play(gs, str(entry[1]))
		check(u.awakened and u.attack == 3 and u.maxHp == 6 and ally.attack == attack + 1 and ally.maxHp == hp + 1, "awakening gives printed caster stats and one ongoing same-faction aura " + str(entry[0]))
		ally.hp -= 1; var current := int(ally.hp); BG.refresh(gs); BG.refresh(gs)
		check(ally.hp == current, "repeated aura refresh cannot heal existing damage " + str(entry[0]))
		play(gs, str(entry[1]))
		check(u.attack == 4 and u.maxHp == 7 and ally.attack == attack + 1 and ally.maxHp == hp + 1 and ally.hp == current, "recasting awakening adds printed self bonus without stacking aura or healing ally " + str(entry[0]))
		play(gs, "c20801", ally.uid)
		check(gs.resolve_divination_choice(0, "紫岩"), "actual faction spell changes aura target")
		check(ally.attack == attack and ally.maxHp == hp, "changing away removes the live aura " + str(entry[0]))
		gs._knockout_unit(u, 1, 0); gs._resolve_resolution_stack()
		gs.VerifiedRules.Peach.revive(gs, 0, 3, u, false, false); BG.refresh(gs)
		check(u.awakened and ally.attack == attack and ally.maxHp == hp, "revival keeps awakening but does not buff an off-faction target " + str(entry[0]))
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs, "c20706"); play(gs, "c20701", foe.units[1].uid)
	check(events(gs, "three-tail-projectile").size() == 1, "blue awakening retains second-card projectile during its own printed turn")
	gs.end_turn(0); gs.end_turn(1); play(gs, "c20701", foe.units[1].uid); play(gs, "c20701", foe.units[2].uid)
	check(events(gs, "three-tail-projectile").size() == 1, "blue awakened next turn does not retain the removed ordinary passive")

func green_growth_and_forms() -> void:
	var gs := game(["jingliuliqian", "shantu", "mianqiling", "taohuayao"])
	var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	p.units[1].factionOverride = "苍叶"
	play(gs, "c12702", p.units[1].uid)
	check(u.attack == 3 and int(u.get("bgGreenTemporary", 0)) == 1, "actual other green card grants one temporary power")
	play(gs, "c20607")
	check(u.attack == 3, "green caster's own card cannot grow itself")
	check(gs.end_turn(0), "green growth fixture ends actual turn")
	check(u.attack == 2 and not u.has("bgGreenTemporary"), "temporary green power expires once at the turn boundary")
	gs = game(["jingliuliqian", "shantu", "mianqiling", "taohuayao"]); p = gs.player(0); u = p.units[0]
	p.units[1].factionOverride = "苍叶"; p.units[2].factionOverride = "苍叶"
	var c: Dictionary = gs.hand_card_def(0, give(gs, "c20601"))
	check(c.value.attack == 4 and c.value.hp == 5, "purity uses PNG2/5 plus two living other green sources")
	gs._knockout_unit(p.units[2], 1, 0); gs._resolve_resolution_stack()
	c = gs.hand_card_def(0, 0)
	check(c.value.attack == 3, "defeated teammate is excluded from entry enhancement")
	check(gs.play_card(0, 0) and u.attack == 3 and gs.can_basic_attack(0, 0).ok, "purity real body can actually make a swift basic attack")
	var fire := int(p.energy)
	check(gs.basic_attack(0, 0) and p.energy == fire and not u.swift, "purity consumes its first free swift actual attack")

func revelation_and_glass() -> void:
	var gs := game(["jingliuliqian", "shantu", "mianqiling", "taohuayao"]); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	faction(gs, "苍叶"); foe.units[0].hp = 1; foe.units[0].barrier = true
	play(gs, "c20603", foe.units[0].uid)
	check(foe.units[0].hp == 1 and not foe.units[0].barrier and foe.avatarHp == 27, "pure-green revelation pierces excess beyond one HP despite unit barrier")
	gs = game(["jingliuliqian", "shantu", "mianqiling", "taohuayao"]); p = gs.player(0); foe = gs.player(1)
	var hp := int(foe.units[0].hp); play(gs, "c20603", foe.units[0].uid)
	check(foe.units[0].hp == hp - 3 and foe.avatarHp == 30, "mixed-team revelation remains three damage without pierce")
	gs = game(["jingliuliqian", "shantu", "mianqiling", "taohuayao"]); p = gs.player(0); foe = gs.player(1)
	faction(gs, "苍叶"); p.units[3].factionOverride = "紫岩"; gs._knockout_unit(p.units[3], 1, 0); gs._resolve_resolution_stack()
	var h := give(gs, "c20603")
	check(not gs.hand_card_def(0, h).enhanced, "a defeated off-faction basic teammate still prevents all-green deck condition")
	gs = game(["jingliuliqian", "shantu", "mianqiling", "taohuayao"]); p = gs.player(0); foe = gs.player(1)
	play(gs, "c20604"); var amount := int(foe.avatarHp)
	gs._damage_avatar(1, 2, 0, 0)
	check(foe.avatarHp == amount - 3, "glass realm adds one to actual green-source avatar damage")
	amount = int(foe.avatarHp); gs._damage_avatar(1, 2, 0, 3)
	check(foe.avatarHp == amount - 2, "off-faction source receives no glass damage bonus")
	gs._knockout_unit(p.units[0], 1, 0); gs._resolve_resolution_stack(); amount = int(foe.avatarHp)
	gs._damage_avatar(1, 2, 0, 1)
	check(foe.avatarHp == amount - 3, "existing realm remains active while its owner source is knocked out")

func fortune_and_team_attacks() -> void:
	var gs := game(["jingliuliqian", "shantu", "mianqiling", "taohuayao"]); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs, "c20605"); foe.units[0].front = 1; var hp := int(foe.units[0].hp)
	check(int(gs.VerifiedRules.Countdown.timer(u).remaining) == 3, "twin form installs real countdown3")
	check(not gs.VerifiedRules.Light.roll(gs, 0, 7, 6, 0), "actual failed fortune event")
	check(int(gs.VerifiedRules.Countdown.timer(u).remaining) == 3, "failed fortune cannot reduce countdown")
	for i in 3:
		check(gs.VerifiedRules.Light.roll(gs, 0, 1, 6, 0), "actual successful fortune event")
		gs._resolve_resolution_stack()
	check(foe.avatarHp == 24 and foe.units[0].hp == hp and int(gs.VerifiedRules.Countdown.timer(u).remaining) == 3, "three successes trigger a real direct attack then reset countdown")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c20708"); foe.units[0].front = 1; gs._grow_unit(foe.units[0], 0, 20)
	var life := int(p.units[0].hp); hp = int(foe.units[0].hp)
	check(gs.basic_attack(0, 0), "blue ally actually attacks under snow realm")
	check(p.units[0].hp == life and foe.units[0].hp == hp - 2 and int(foe.units[0].frozen) > 0, "own-turn snow realm prevents counterdamage and stuns a positively damaged target")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c20708"); p.units[0].front = 1; gs.current_player = 1; life = int(p.units[0].hp)
	check(gs.basic_attack(1, 2) and p.units[0].hp == life - 3, "snow realm provides no off-turn combat immunity")
	gs = game(["jingliuliqian", "bingyong", "yaodaoji", "taohuayao"]); p = gs.player(0); foe = gs.player(1)
	for i in 3: p.units[i].factionOverride = "苍叶"
	foe.units[0].front = 1; gs._grow_unit(foe.units[0], 30, 80)
	var before: Array = p.units.map(func(t): return int(t.hp)); hp = int(foe.units[0].hp)
	var expected := int(p.units[0].attack) + int(p.units[1].attack) + int(p.units[2].attack)
	play(gs, "c20608")
	var order: Array = events(gs, "bg-team-attack-order")[0].order
	check(order.size() == 3 and order.has(p.units[0].uid) and not order.has(p.units[3].uid), "team attack random pool includes each living green ally once only")
	check(events(gs, "bg-team-attacked").size() == 3 and foe.units[0].hp == hp - expected, "three real attacks each settle against current front")
	check(p.units.map(func(t): return int(t.hp)) == before, "team attack grants true combat immunity to all eligible allies")
	gs.end_turn(0)
	check(p.units.all(func(t): return not t.has("bgGreenImmuneTurn")), "team combat immunity expires at actual turn end")
	gs = game(["jingliuliqian", "bingyong", "yaodaoji", "taohuayao"]); p = gs.player(0); foe = gs.player(1)
	foe.units[0].front = 1; hp = int(foe.units[0].hp)
	play(gs, "c20607"); check(gs.basic_attack(0, 0), "dark feather actually allows a direct basic attack")
	check(foe.avatarHp == 28 and foe.units[0].hp == hp, "dark feather bypasses front instead of dealing synthetic damage")
	gs._knockout_unit(p.units[0], 1, 0); gs._resolve_resolution_stack()
	check(not p.units[0].has("bgDirect"), "dark feather nonpermanent keyword disappears on knockout")

func ai_and_status() -> void:
	for role in [206, 207]:
		for number in range(1, 9):
			var id := "c%d%02d" % [role, number]; var gs := game(); var p: Dictionary = gs.player(0)
			give(gs, id)
			var best: Dictionary = AI._best_card(gs, 0)
			check(best.ok and best.card_id == id and gs.can_play_card(0, int(best.hand), best.target).ok, "AI finds real legal card " + id)
			if best.ok:
				check(gs.play_card(0, int(best.hand), best.target), "AI actually uses " + id)
				finish(gs)
	var gs := game(); play(gs, "c20702")
	var view: Dictionary = Status.unit_view(gs, 0, 0, 0)
	check(view.blueGreenMarks.any(func(m): return str(m).contains("窥秘之瞳")), "actual status projection shows charging eye mechanics")

func fortune_and_damage_boundaries() -> void:
	var gs := game(["jingliuliqian", "qingwa-ciqi", "shantu", "mianqiling"])
	var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	give(gs, "c20602"); give(gs, "c20602"); play(gs, "c12606")
	check(not gs.VerifiedRules.Light.roll(gs, 0, 7, 6, 2) and gs.hand_card_def(0, 0).value == 1, "failed fortune cannot enhance actual hand Mingche")
	check(gs.VerifiedRules.Light.roll(gs, 0, 1, 6, 2) and gs.VerifiedRules.Fortune.last_repeats(gs, 0) == 2, "real awakened frog doubles fortune effects")
	check(gs.hand_card_def(0, 0).value == 2 and gs.hand_card_def(0, 1).value == 2, "one success enhances each actual hand copy once despite frog repetition")
	give(gs, "c20602")
	check(gs.hand_card_def(0, 2).value == 1, "newly obtained Mingche cannot inherit earlier fortune success")
	check(gs.VerifiedRules.Light.roll(gs, 0, 1, 6, 2), "second actual success enhances hand copies")
	check(gs.hand_card_def(0, 0).value == 3 and gs.hand_card_def(0, 1).value == 3 and gs.hand_card_def(0, 2).value == 2, "enhancement belongs to actual hand instances rather than a global card-name counter")
	var attack := int(p.units[0].attack)
	check(gs.play_card(0, 0) and foe.avatarHp == 30 - attack - 3 and p.units[0].shield == 1, "partial Mingche actually attacks with its enhanced power and grants one printed armor")
	gs.end_turn(0)
	check(gs.hand_card_def(0, 0).value == 1 and gs.hand_card_def(0, 1).value == 1, "per-turn Mingche power does not survive the actual turn boundary")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c20708"); var life := int(p.units[0].hp)
	gs._damage_unit(0, 0, 2, 1, 0)
	check(p.units[0].hp == life - 2, "snow realm does not fabricate immunity to noncombat damage")
	foe.units[0].front = 1; foe.units[0].barrier = true; life = int(p.units[0].hp)
	check(gs.basic_attack(0, 0) and int(foe.units[0].frozen) == 0 and not foe.units[0].barrier and p.units[0].hp == life, "barrier prevents positive combat damage and snow stun while true counterdamage immunity still applies")
	gs = game(); foe = gs.player(1)
	play(gs, "c20708")
	check(gs.basic_attack(0, 0) and foe.avatarHp == 28 and int(foe.get("avatarFrozen", 0)) > 0, "snow actual avatar combat damage stuns the avatar")

func ui_rules() -> void:
	for role in [206, 207]:
		for number in range(1, 9):
			var id := "c%d%02d" % [role, number]
			var face := preload("res://scripts/ui/card_face.gd").new(); face.data = Content.card_def(id); face.refresh_art()
			check(face._original_card != null and face._original_card.resource_path == "res://assets/official/cards/%s.png" % id, "native actual original texture " + id)
			face.free()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["yingxueji", "jingliuliqian", "shuweng", "taohuayao"], ["bingyong", "fenghuanghuo", "yaodaoji", "baizangzhu"], 206207); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for unit in side.units: unit.level = 3; unit.charge = 0
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var p: Dictionary = b.gs.player(0); var foe: Dictionary = b.gs.player(1)
		foe.units[0].front = 1
		hand(b, ["c20701"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(foe.units[1].uid).selected and b._unit_widget(p.units[0].uid).selected, "native intent exposes actual friendly and enemy shikigami targets")
		await capture("%d-01-intent-target" % physical.x)
		await click(b._unit_widget(foe.units[1].uid)); await settled(b)
		check(int(foe.units[1].frozen) > 0 and p.hand.size() == 1 and p.hand[0].definitionId == "julijialuo-wan", "native chosen target stunned and actual derivative generated")
		foe.units[0].frozen = 1; var hp0 := int(foe.units[0].hp); var hp1 := int(foe.units[1].hp)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(foe.units[0].hp == hp0 - 4 and foe.units[1].hp == hp1 - 2 and p.hand.is_empty(), "native derivative damages every stunned enemy and second blue card projects two more into front")
		faction(b.gs, "青岚"); deck(b.gs, ["c11901", "c11902", "c11903", "c11904"])
		hand(b, ["c20703"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.pending_choice.get("type") == "native-divination" and p.hand.is_empty(), "native pure-blue outline waits for divination before draw")
		await capture("%d-02-outline-divination" % physical.x)
		var guard := 0
		while not b.gs.pending_choice.is_empty() and guard < 10:
			guard += 1; await click(choice_face(b)); await settled(b)
		check(guard < 10 and p.hand.size() == 2, "native actual divination choices finish and resume draw2")
		faction(b.gs, "苍叶"); hand(b, ["c20601"]); await settled(b)
		check(b._hand_row.get_child(0).data.value.attack == 5, "native purity card presents all three real living green teammate bonuses")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[1].attack == 5 and p.units[1].maxHp == 5 and p.units[1].swift, "native purity installs enhanced body and swift")
		hand(b, ["c20607"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		var avatar := int(foe.avatarHp); var front_hp := int(foe.units[0].hp)
		await click(b._unit_widget(p.units[1].uid)); await settled(b)
		await capture("%d-03-direct-attack" % physical.x)
		await click(b._enemy_plate); await settled(b)
		check(foe.avatarHp == avatar - 5 and foe.units[0].hp == front_hp, "native dark-feather selection directs the real attack past front")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	definitions_and_targets(); blue_counter_and_derivative(); blue_forms_and_realms(); blue_draw_and_freehand(); faction_auras(); green_growth_and_forms(); revelation_and_glass(); fortune_and_team_attacks(); fortune_and_damage_boundaries(); ai_and_status()
	if not only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("BLUE_GREEN_OK checks=%d failures=%d rules_only=%s" % [checks, failures, only])
	quit(0 if failures == 0 else 1)
