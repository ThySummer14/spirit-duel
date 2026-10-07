extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Peach := preload("res://scripts/peach_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PEACH_FAIL ", message)

func fixture() -> GS:
	var gs := GS.create(["taohuayao", "yimulian", "zhen", "basalt"], ["taohuayao", "yimulian", "zhen", "basalt"], 10809)
	for p in gs.players:
		p.hand.clear()
		p.energy = 20
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
	return gs

func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "peach-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs: GS, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "play " + id)

func _initialize() -> void:
	_healing()
	_search()
	_forms()
	_healer_order()
	_revival()
	_swift()
	_encourage()
	_boundaries()
	_ai()
	if checks == 0: failures += 1
	print("PEACH checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("PEACH_OK")
	quit(0 if failures == 0 else 1)

func _healing() -> void:
	var gs := fixture()
	var source: Dictionary = gs.player(0).units[0]
	var ally: Dictionary = gs.player(0).units[3]
	var enemy: Dictionary = gs.player(1).units[3]
	check(source.attack == 1 and source.maxHp == 6, "printed source body 1/6")
	check(source.passive_hooks.is_empty(), "old catch-all heal approximation removed")
	var legal := gs.valid_targets(0, ContentLoader.card_def("c10801"))
	check(legal.size() == 10 and legal.has("avatar-0") and legal.has("avatar-1"), "heal targets both sides and both players")
	ally.level = 0
	check(gs.valid_targets(0, ContentLoader.card_def("c10801")).has(ally.uid), "healing may target inactive living unit")
	ally.level = 3
	ally.hp = 3
	play(gs, "c10801", ally.uid)
	check(ally.hp == 8 and ally.attack == 2, "healing five triggers one source-attributed temporary attack")
	gs._heal_unit(ally, 1)
	check(ally.hp == 9 and ally.attack == 2, "other healing doesn't trigger Peach")
	gs._grow_unit(ally, 4, 2)
	gs._knockout_unit(ally)
	check(ally.attack == 5 and ally.maxHp == 14, "only temporary Peach attack removed on knockout")
	check(not gs.valid_targets(0, ContentLoader.card_def("c10801")).has(ally.uid), "healing cannot revive")
	play(gs, "c10809")
	check(source.awakened and source.attack == 3 and source.maxHp == 7, "awakening printed +2/+1 applied")
	play(gs, "c10809")
	check(source.attack == 5 and source.maxHp == 8, "second awakening preserves its printed bonus")
	ally.hp = ally.maxHp - 1
	ally.knockout = 0
	play(gs, "c10801", ally.uid)
	check(ally.hp == 16 and ally.maxHp == 16 and ally.attack == 7, "one real heal gains exactly permanent +2/+2")
	gs._knockout_unit(ally)
	check(ally.attack == 7 and ally.maxHp == 16, "awakened restoration survives knockout")
	gs._begin_turn(0)
	gs._begin_turn(0)
	gs.player(0).levelUpUsed = true
	gs.player(0).energy = 20
	check(ally.hp == 16, "natural revival retains permanent maxHP")
	var attack := int(ally.attack)
	play(gs, "c10801", ally.uid)
	check(ally.attack == attack, "pending boundary: zero actual healing gives no growth")
	check(not ContentLoader.card_def("c10801").get("verificationPending", []).is_empty(), "zero-heal client boundary remains audited")
	enemy.hp = 3
	play(gs, "c10801", enemy.uid)
	check(enemy.hp == 8 and enemy.attack == 1, "enemy can be healed without own growth")
	gs.player(0).avatarHp = 21
	gs.player(1).avatarHp = 20
	play(gs, "c10801", "avatar-0")
	check(gs.player(0).avatarHp == 26, "own player heals five")
	play(gs, "c10801", "avatar-1")
	check(gs.player(1).avatarHp == 25, "enemy player is a legal heal target")
	check(source.attack == 5, "player recovery doesn't buff source")

func _search() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var selected: Dictionary = p.units[2]
	selected.level = 0
	gs._knockout_unit(selected)
	check(gs.valid_targets(0, ContentLoader.card_def("c10802")).has(selected.uid), "search targets inactive knocked ally")
	check(gs.valid_targets(0, ContentLoader.card_def("c10802")).size() == 4, "search excludes all opponents and avatars")
	p.deck = [{"instanceId":"other-bottom","definitionId":"c10801"},{"instanceId":"selected-real","definitionId":"c11604"},{"instanceId":"other-top","definitionId":"c10805"}]
	p.energy = 1
	play(gs, "c10802", selected.uid)
	check(p.hand.size() == 1 and p.hand[0].instanceId == "selected-real", "search draws the actual selected-unit deck instance")
	check(p.deck.map(func(c): return c.instanceId) == ["other-bottom", "other-top"], "search leaves unrelated deck order intact")
	check(p.energy == 1 and gs.kw_usage(0, "instant").used, "first search is instant")
	play(gs, "c10802", selected.uid)
	check(p.energy == 0 and p.hand.size() == 1 and p.deck.size() == 2, "second search pays and doesn't draw unrelated replacement")
	p.deck.clear()
	Peach.search_deck(gs, 0, selected)
	check(gs.winner < 0, "no matching card isn't an ordinary empty-deck draw")
	var seen := {}
	for seed in range(1, 40):
		var sampled := fixture()
		sampled.rng_state = seed * 7919
		sampled.player(0).deck = [{"instanceId":"a","definitionId":"c11604"},{"instanceId":"b","definitionId":"c11605"}]
		Peach.search_deck(sampled, 0, sampled.player(0).units[2])
		seen[sampled.player(0).hand[0].instanceId] = true
	check(seen.size() == 2, "search randomly samples every matching instance")

func _forms() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var source: Dictionary = p.units[0]
	var ally: Dictionary = p.units[3]
	ally.hp = 1
	play(gs, "c10804")
	check(source.attack == 3 and source.hp == 7, "abundance sets 3/7 instead of adding 3/7")
	check(ally.hp == 4 and ally.attack == 2, "abundance has real on-entry random injured healing")
	gs._begin_turn(0)
	p.levelUpUsed = true
	check(ally.hp == 7 and ally.attack == 3, "abundance repeats on owner turn start")
	gs._begin_turn(1)
	check(ally.hp == 7, "enemy turn doesn't run owner form")
	gs.current_player = 0
	p.energy = 20
	play(gs, "c10805")
	check(source.attack == 4 and source.hp == 9, "bloom replaces abundance with 4/9")
	check(ally.hp == 12 and ally.attack == 6, "bloom repeats exact three two-point recoveries with per-heal growth")
	var events: int = gs.rule_events.filter(func(e): return e.kind == "peach-heal").size()
	Peach.turn_started(gs, 0, 0)
	check(gs.rule_events.filter(func(e): return e.kind == "peach-heal").size() == events, "no wounded targets means no fake full-team heal")
	ally.hp = 10
	p.units[1].hp = int(p.units[1].maxHp) - 2
	Peach.turn_started(gs, 0, 0)
	check(ally.hp == 12 and p.units[1].hp == p.units[1].maxHp, "each repeat refreshes injured pool and excludes healed target")
	check(gs.rule_events.filter(func(e): return e.kind == "peach-heal").size() == events + 2, "no third recovery when all injuries are gone")
	play(gs, "c10809")
	ally.hp = 1
	var prior_hp := int(ally.maxHp)
	var prior_attack := int(ally.attack)
	Peach.turn_started(gs, 0, 0)
	check(ally.hp == 13 and ally.maxHp == prior_hp + 6 and ally.attack == prior_attack + 6, "three awaken heals fully resolve separately before next selection")
	gs._knockout_unit(source)
	check(source.form.is_empty() and source.maxHp == 7, "form disappears at source knockout while awakening remains")
	var hp := int(ally.hp)
	Peach.turn_started(gs, 0, 0)
	check(ally.hp == hp, "dead form cannot heal")

func _revival() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var ally: Dictionary = p.units[3]
	gs._grow_unit(ally, 3, 4)
	gs._knockout_unit(ally)
	ally.level = 0
	check(gs.valid_targets(0, ContentLoader.card_def("c10808")).has(ally.uid), "spring can revive an inactive ally without activating it")
	play(gs, "c10808", ally.uid)
	check(ally.hp == 16 and ally.knockout == 0 and ally.attack == 5, "spring revives full current maxHP with one temporary growth")
	check(ally.level == 0 and not gs.can_basic_attack(0, 3).ok, "reviving inactive target doesn't grant a level or legal attack")
	ally.level = 3
	check(ally.get("swift", false) and not gs.kw_usage(0, "instant").get("used", false), "spring grants unit swift, not card instant")
	check(not gs.can_play_card(0, give(gs, "c10808"), ally.uid).ok, "spring rejects living targets")
	gs._knockout_unit(ally)
	p.energy = 0
	var hand := give(gs, "c10807")
	check(gs.can_play_card(0, hand).ok and gs.effective_card_cost(0, gs.playable_card(0, hand)) == 0, "alive-source mass revival gains first instant")
	check(gs.play_card(0, hand), "mass revival plays alive source without fire")
	check(ally.hp == 16 and not ally.get("swift", false), "mass revival has no obsolete group swift")
	check(not gs.can_play_card(0, give(gs, "c10807")).ok, "second alive-source mass revival pays ordinary fire")
	gs = fixture()
	p = gs.player(0)
	for u in p.units: gs._knockout_unit(u)
	var source: Dictionary = p.units[0]
	p.energy = 0
	hand = give(gs, "c10807")
	check(not gs.can_play_card(0, hand).ok, "dead-source mass revival cannot keep instant")
	p.energy = 1
	check(gs.can_play_card(0, hand).ok, "mass revival is legal with dead source")
	check(gs.play_card(0, hand), "dead source casts mass revival")
	check(p.energy == 0 and p.units.all(func(u): return int(u.hp) == int(u.maxHp)), "all allies including source return at full health")
	check(p.units.all(func(u): return not u.get("swift", false)), "mass revival grants nobody swift")
	check(source.attack == 2 and p.units[3].attack == 2, "pending boundary: simultaneous revival growth independent of lineup position")
	check(not ContentLoader.card_def("c10807").get("verificationPending", []).is_empty(), "self-revival growth remains audited")

func _healer_order() -> void:
	for grass_first in [true, false]:
		var gs := GS.create(["taohuayao", "yingcao", "zhen", "basalt"], ["taohuayao", "yimulian", "zhen", "basalt"], 10809)
		for p in gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for u in p.units:
				u.level = 3
				u.passive_hooks = []
		for id in (["c10702", "c10804"] if grass_first else ["c10804", "c10702"]): play(gs, id)
		var target: Dictionary = gs.player(0).units[3]
		target.hp = 10
		gs._begin_turn(0)
		check(target.hp == 12, "both source orders restore the same injury")
		check(target.attack == (1 if grass_first else 2), "form entry order, not lineup index, decides whether Peach has an injured target")

func _swift() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var ally: Dictionary = p.units[3]
	ally.swift = true
	p.energy = 0
	check(gs.can_basic_attack(0, 3).ok, "swift permits zero-fire basic attack")
	check(gs.basic_attack(0, 3), "swift uses real ordinary attack")
	check(p.energy == 0 and p.attackUsed and not ally.swift, "swift is consumed only by successful basic attack")
	ally.swift = true
	check(not gs.can_basic_attack(0, 3).ok and ally.swift, "swift doesn't create second attack quota")
	gs._begin_turn(0)
	p.levelUpUsed = true
	check(ally.swift, "unused swift survives owner turn start")
	gs._knockout_unit(ally)
	check(not ally.swift, "knockout removes granted swift")
	var source: Dictionary = p.units[2]
	source.swift = true
	p.energy = 2
	play(gs, "c11601")
	check(p.energy == 1 and source.swift, "combat card pays fire and preserves swift")
	source.frozen = 1
	check(not gs.can_basic_attack(0, 2).ok and source.swift, "swift doesn't bypass stun")

func _encourage() -> void:
	var gs := fixture()
	var p := gs.player(0)
	p.energy = 0
	play(gs, "c10803")
	check(p.energy == 0 and gs.kw_usage(0, "encourage").attack == 2 and gs.kw_usage(0, "encourage").shield == 2, "encourage gives exact +2/+2 without fire")
	check(not gs.kw_usage(0, "instant").get("used", false), "zero cost doesn't consume instant")
	p.energy = 2
	play(gs, "c11601")
	check(gs.kw_usage(0, "encourage").attack == 2, "combat cards don't consume encourage")
	var hp: int = gs.player(1).avatarHp
	check(gs.basic_attack(0, 3), "ordinary attack consumes encourage")
	check(gs.player(1).avatarHp == hp - 3 and p.units[3].shield == 2 and gs.kw_usage(0, "encourage").attack == 0, "encourage exact combat attack and armor")

func _ai() -> void:
	var gs := fixture()
	var ally: Dictionary = gs.player(0).units[3]
	ally.hp = 1
	give(gs, "c10801")
	var best := AI._best_card(gs, 0)
	check(best.ok and best.target == ally.uid and gs.can_play_card(0, best.hand, best.target).ok, "AI legally heals wounded ally rather than enemy/full avatar")
	gs.player(0).hand.clear()
	give(gs, "c10802")
	gs.player(0).deck = [{"instanceId":"match","definitionId":"c11604"}]
	best = AI._best_card(gs, 0)
	check(best.ok and best.target == gs.player(0).units[2].uid, "AI searches only unit with cards remaining")
	gs.player(0).hand.clear()
	give(gs, "c10807")
	check(not AI._best_card(gs, 0).ok, "AI doesn't spend mass revival on no casualties")
	gs._knockout_unit(ally)
	best = AI._best_card(gs, 0)
	check(best.ok and gs.can_play_card(0, best.hand).ok, "AI uses legal actual revive")
	gs.player(0).units[2].swift = true
	gs.player(0).energy = 0
	check(AI._best_attack(gs, 0).ok, "AI can use swift with zero fire")

func _boundaries() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var source: Dictionary = p.units[0]
	source.hp = 1
	play(gs, "c10801", source.uid)
	check(source.hp == 6 and source.attack == 2, "Peach can heal and grow herself")
	gs._knockout_unit(source)
	check(source.attack == 1, "self-growth is still temporary before awakening")
	check(not gs.can_play_card(0, give(gs, "c10801"), p.units[3].uid).ok, "ordinary healing cannot be cast while source knocked")
	source.level = 2
	check(not gs.can_play_card(0, give(gs, "c10807")).ok, "mass revive dead-source permission doesn't bypass level")
	source.level = 3
	source.hp = source.maxHp
	source.knockout = 0
	source.frozen = 1
	check(not gs.can_play_card(0, give(gs, "c10807")).ok, "alive stunned source cannot cast mass revive")
	source.frozen = 0
	play(gs, "c10804")
	source.frozen = 1
	p.units[3].hp = 1
	Peach.turn_started(gs, 0, 0)
	check(p.units[3].hp == 4, "stun doesn't disable passive form healing")
	gs = fixture()
	p = gs.player(0)
	p.deck = [{"instanceId":"chosen","definitionId":"c11601"}]
	for i in 12: give(gs, "c10803")
	Peach.search_deck(gs, 0, p.units[2])
	check(p.deck.is_empty() and p.hand.size() == 12, "full-hand search burns actual drawn card without generating a replacement")
	gs = fixture()
	p = gs.player(0)
	p.nullifyNextCardTurn = gs.turn_counter
	p.units[3].hp = 1
	play(gs, "c10801", p.units[3].uid)
	check(p.units[3].hp == 1 and p.units[3].attack == 1 and p.energy == 19, "nullified heal spends fire without recovery or growth")
	gs = fixture()
	p = gs.player(0)
	p.nullifyNextCardTurn = gs.turn_counter
	for u in p.units: gs._knockout_unit(u)
	play(gs, "c10807")
	check(p.units.all(func(u): return int(u.hp) == 0), "dead-source revival can still be nullified")
	check(gs.rule_events.all(func(e): return e.kind != "peach-revive"), "nullified resurrection emits no false revive events")
	gs = fixture()
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	play(gs, "c10803")
	check(int(gs.kw_usage(0, "encourage").get("attack", 0)) == 0, "nullified zero-cost encourage must not apply before resolution")
