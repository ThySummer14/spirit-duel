extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Lily := preload("res://scripts/spider_lily_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("SPIDER_LILY_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["biyehua", "shuweng", "shantong", "taohuayao"], ["bingyong", "fenghuanghuo", "xuenv", "baizangzhu"], 170)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true; p.avatarArmor = 0
		for unit in p.units: unit.level = 3
	gs.rule_events.clear()
	return gs
func instance(gs, id: String) -> Dictionary:
	var inst := {"definitionId": id, "instanceId": "lily-fixture-%d" % gs.next_card_id}
	gs.next_card_id += 1
	return inst
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(instance(gs, id)); return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "actual use " + id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)
func install(gs, id: String, owner: int = 0) -> Dictionary:
	gs._deploy_realm(owner, Content.card_def(id)); return gs.player(owner).realms.back()
func finish_choices(gs, owner: int = 0) -> void:
	var guard := 0
	while not gs.pending_choice.is_empty() and guard < 20:
		guard += 1
		check(AI._resolve_choice(gs, owner), "actual choice resumes")
func base_and_history() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	check(u.attack == 3 and u.maxHp == 4 and u.passive_hooks.is_empty(), "base3/4 and no old unit-damage mapping")
	gs._damage_unit(0, 0, 1, 1, 1); gs._resolve_resolution_stack()
	check(foe.avatarHp == 30 and int(p.get("lilySelfDamageCount", 0)) == 0, "damage to flower is not damage to player")
	gs._damage_avatar(0, 5, 1, 1); gs._resolve_resolution_stack()
	check(foe.avatarHp == 30 and int(p.get("lilySelfDamageCount", 0)) == 0, "enemy damage is not self damage")
	gs._damage_avatar(0, 2, 0, 2); gs._resolve_resolution_stack()
	check(p.avatarHp == 23 and foe.avatarHp == 29 and p.lilySelfDamageCount == 1, "one actual self packet triggers one basic avatar hit")
	p.avatarArmor = 2; gs._damage_avatar(0, 2, 0, 2); gs._damage_avatar(0, 0, 0, 2); gs._resolve_resolution_stack()
	check(p.lilySelfDamageCount == 1 and foe.avatarHp == 29, "zero and fully armored packets do not trigger or enhance")
	gs._knockout_unit(u, 1, 1); gs._damage_avatar(0, 3, 0, 2); gs._resolve_resolution_stack()
	check(p.lilySelfDamageCount == 2 and foe.avatarHp == 29, "global lifetime history remains while flower is KO")
	gs.VerifiedRules.Peach.revive(gs, 0, 0, u, false, false)
	var idx := give(gs, "c17008"); var before: int = foe.units[0].hp
	check(gs.hand_card_def(0, idx).currentCardStats.contains("伤害4"), "death in newly drawn hand sees prior lifetime packets")
	check(not gs.can_play_card(0, idx, "avatar-1").ok, "death rejects player target")
	check(gs.play_card(0, idx, foe.units[0].uid) and foe.units[0].hp == before - 4, "death resolves two plus count, not fixed four")
	idx = give(gs, "c17008"); before = int(p.units[2].hp)
	check(gs.can_play_card(0, idx, p.units[2].uid).ok and gs.play_card(0, idx, p.units[2].uid), "death can legally target own living unit")
	check(p.units[2].hp == before - 4, "friendly death target receives actual damage")
func blood_bounce() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var idx := give(gs, "c17001"); var iid: String = p.hand[idx].instanceId; var deck: int = p.deck.size()
	check(Content.card_def("c17001").level == 1 and gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 0, "PNG blood is one-level true instant")
	check(gs.play_card(0, idx), "blood actual use")
	check(p.deck.size() == deck - 1 and p.avatarHp == 29 and gs.player(1).avatarHp == 29, "blood draws one then self hits player once")
	check(p.hand.size() == 2 and p.hand.back().instanceId == iid and p.hand.back().lilyBounceSpent, "same physical instance returns once after draw")
	check(not gs.hand_card_def(0, 1).keywords.has("bounce") and gs.effective_card_cost(0, gs.hand_card_def(0, 1)) == 1, "returned blood loses bounce and instant has actually been used")
	check(gs.play_card(0, 1) and not p.hand.any(func(i): return i.instanceId == iid), "second use does not return again")
	gs = game(); p = gs.player(0); p.nullifyNextCardTurn = gs.turn_counter; idx = give(gs, "c17001"); iid = p.hand[idx].instanceId; deck = p.deck.size()
	check(gs.play_card(0, idx) and p.deck.size() == deck and p.avatarHp == 30, "counter stops draw and intrinsic self damage")
	check(p.hand.size() == 1 and p.hand[0].instanceId == iid and p.hand[0].lilyBounceSpent, "announced bounce survives ordinary counter once")
	gs = game(); p = gs.player(0)
	for n in 12: give(gs, "c11902")
	idx = give(gs, "c17001"); check(gs.play_card(0, idx) and p.hand.size() == 12 and not p.hand.any(func(i): return i.get("lilyBounceSpent", false)), "full hand burns draw and bounce without extra slots")
func forms_and_awakening() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	play(gs, "c17002"); check(u.attack == 4 and u.maxHp == 5, "red form sets4/5 rather than adding4/5")
	check(gs.basic_attack(0, 2), "ally basic attack with red")
	check(p.avatarHp == 29 and foe.avatarHp == 26 and p.lilySelfDamageCount == 1, "red self hit and backlash happen before actual3attack")
	gs._resolve_combat(0, 2, 0, false, true, true, false); gs._resolve_resolution_stack()
	check(p.avatarHp == 29 and p.lilySelfDamageCount == 1, "second attack and combo do not bypass once per actual turn")
	check(gs.end_turn(0), "advance to foe turn")
	gs._resolve_combat(0, 2, 0, false, true, false, false); gs._resolve_resolution_stack()
	check(p.avatarHp == 28 and p.lilySelfDamageCount == 2, "own attack in enemy turn receives separate turn allowance")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]
	play(gs, "c17003"); check(u.attack == 7 and u.maxHp == 5 and u.swift, "bloom sets7/5 and grants real one-use swift")
	u.shield = 2; var before: int = p.avatarHp; gs._damage_unit(0, 0, 2, 1, 1); gs._resolve_resolution_stack()
	check(p.avatarHp == before and foe.avatarHp == 30, "fully blocked flower damage does not reflect")
	gs._damage_unit(0, 0, 2, 1, 1); gs._resolve_resolution_stack()
	check(u.hp == 3 and p.avatarHp == before - 2 and foe.avatarHp == 29, "bloom reflects real unshielded packet to own player")
	gs._damage_unit(0, 0, 9, 1, 1); gs._resolve_resolution_stack()
	check(u.hp == 0 and u.form.is_empty() and p.avatarHp == before - 11 and foe.avatarHp == 29, "lethal packet retains full bloom damage; KO flower no longer triggers base")
	gs = game(); p = gs.player(0); foe = gs.player(1); u = p.units[0]; foe.units[0].front = 1; var hp: int = foe.units[0].hp
	play(gs, "c17006")
	check(u.awakened and u.attack == 4 and u.maxHp == 4, "awakening grants exact+1attack, no invented+1health")
	check(p.avatarHp == 27 and foe.avatarHp == 26 and foe.units[0].hp == hp, "awakening active damage uses old ability before awakening")
	gs._damage_avatar(0, 2, 0, 1); gs._resolve_resolution_stack()
	check(foe.units[0].hp == hp - 1 and foe.avatarHp == 26, "awakened backlash really projects into enemy front")
	foe.units[0].front = 0; gs._damage_avatar(0, 1, 0, 1); gs._resolve_resolution_stack()
	check(foe.avatarHp == 25, "awakened projectile hits player on empty front")
	check(not gs.can_play_card(0, give(gs, "c17006")).ok, "manual duplicate awakening rejected")
func realms_and_road() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	play(gs, "c17004"); var field: Dictionary = p.realms[0]
	check(p.avatarHp == 29 and int(field.hp) == 3, "yellow entry self damage lowers its real first-position durability")
	check(gs.kw_usage(0, "encourage").attack == 2 and gs.kw_usage(0, "encourage").shield == 2, "one durability reduction grants one actual encourage+2/2")
	gs._damage_avatar(0, 2, 1, 1); gs._resolve_resolution_stack()
	check(field.hp == 1 and gs.kw_usage(0, "encourage").attack == 4, "two-point packet counts once, not twice")
	gs._damage_avatar(0, 4, 1, 1); gs._resolve_resolution_stack()
	check(p.realms.is_empty() and gs.kw_usage(0, "encourage").attack == 6, "final real durability decrease rewards before destruction")
	check(gs.basic_attack(0, 2) and p.units[2].shield == 6 and gs.kw_usage(0, "encourage").attack == 0, "encourage consumed by next actual basic attack")
	gs = game(); p = gs.player(0); install(gs, "c17005"); field = install(gs, "c17004"); gs._damage_avatar(0, 1, 1, 1); gs._resolve_resolution_stack()
	check(field.hp == 4 and int(gs.kw_usage(0, "encourage").get("attack", 0)) == 0, "later yellow field never reacts to first field losing durability")
	gs = game(); p = gs.player(0); play(gs, "c17005"); var idx := give(gs, "c11902"); var view := gs.hand_card_def(0, idx)
	check(gs.card_payment(0, view).usesInstant and view.lilyRoadDamage == 1, "road makes actual1levelhandcard instant with distinct use harm")
	var stamp := JSON.stringify(gs.snapshot()); gs.hand_card_def(0, idx); gs.can_play_card(0, idx)
	check(JSON.stringify(gs.snapshot()) == stamp, "card view and legality do not trigger self harm")
	check(gs.play_card(0, idx) and p.avatarHp == 29 and p.energy == 39, "road free hand use only pays realm deployment, self hits on use")
	idx = give(gs, "c11902"); p.nullifyNextCardTurn = gs.turn_counter
	check(gs.play_card(0, idx) and p.avatarHp == 28, "countered1levelcard still triggers road use harm")
	p.realms.clear(); idx = give(gs, "c11902")
	check(not gs.hand_card_def(0, idx).get("lilyRoadDamage", false) and not gs.card_payment(0, gs.hand_card_def(0, idx)).instant, "removing road immediately removes aura, no sticky fake hand mutation")
func voyage_physical_sources() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	p.deck = [instance(gs, "c11902"), instance(gs, "c17008")]
	play(gs, "c17007")
	check(gs.pending_choice.get("type") == "native-divination" and p.realms.is_empty(), "voyage full2card divination pauses deployment")
	finish_choices(gs); check(p.realms.size() == 1 and p.energy == 39, "divination completes then deploys real10durability realm at1fire")
	var deck: int = p.deck.size(); var count: int = p.hand.size(); var inst: Dictionary = p.deck.back(); var idx := count
	check(gs.playable_card_count(0) == count + 1 and gs.card_instance(0, idx).instanceId == inst.instanceId, "top card exposed without drawing or copying")
	var view := gs.hand_card_def(0, idx); var stamp := JSON.stringify(gs.snapshot()); gs.hand_card_def(0, idx); gs.can_play_card(0, idx, foe.units[0].uid)
	check(JSON.stringify(gs.snapshot()) == stamp and p.deck.size() == deck and p.hand.size() == count, "top inspection and targeting are pure reads")
	var hp: int = foe.units[0].hp
	check(gs.play_card(0, idx, foe.units[0].uid) and p.deck.size() == deck - 1 and p.hand.size() == count, "actual play removes exact top from actual deck, never hand")
	check(p.avatarHp == 28 and foe.units[0].hp == hp - 3, "voyage use harm enhances death before its actual resolution")
	check(gs.command_log.back().a.sourceZone == "deck" and gs.command_log.back().a.instanceId == inst.instanceId, "command records physical deck source and identity")
	p.energy = 0; idx = p.hand.size(); view = gs.hand_card_def(0, idx)
	check(view.lilyDeckFree and gs.card_payment(0, view).cost == 0 and not gs.card_payment(0, view).usesInstant, "one-level top free independent of instant allowance")
	check(gs.play_card(0, idx) and p.deck.is_empty() and not Lily.top_available(gs, 0), "zero-fire top use exposes no phantom card after deck empty")
	check(p.avatarHp == 26 and not p.keywordUsage.get("instant", {}).get("used", false), "each real top use self2 and never pretends free use is instant")
	gs = game(); p = gs.player(0); install(gs, "c17007"); p.deck = [instance(gs, "c17008")]; p.energy = 0; idx = p.hand.size()
	check(not gs.can_play_card(0, idx, gs.player(1).units[0].uid).ok and p.deck.size() == 1, "two-level top cannot bypass normal fire")
	p.energy = 10; p.units[0].level = 1
	check(not gs.can_play_card(0, idx, gs.player(1).units[0].uid).ok and p.deck.size() == 1, "top cannot bypass level")
	p.units[0].level = 3; p.units[0].hp = 0
	check(not gs.can_play_card(0, idx, gs.player(1).units[0].uid).ok, "top cannot bypass KO source")
	p.realms.clear(); check(gs.hand_card_def(0, idx).is_empty(), "destroying last voyage removes top access immediately")
func ai_and_cross_role() -> void:
	for n in range(1, 9):
		var gs := game(); var id := "c170%02d" % n; give(gs, id)
		var best := AI._best_card(gs, 0)
		check(best.ok and best.card_id == id and gs.can_play_card(0, best.hand, best.target).ok, "AI legal original card " + id)
		check(best.ok and gs.play_card(0, best.hand, best.target), "AI actual original use " + id)
		finish_choices(gs)
		check(FileAccess.file_exists("res://assets/official/cards/" + id + ".png"), "original PNG exists " + id)
	var gs := game(); var p: Dictionary = gs.player(0); install(gs, "c17007"); p.deck = [instance(gs, "c17008")]; var best := AI._best_card(gs, 0)
	check(best.ok and best.hand == p.hand.size() and gs.play_card(0, best.hand, best.target), "AI chooses and physically plays deck top with no hand")
	gs = game(); p = gs.player(0); p.avatarHp = 1; give(gs, "c17001")
	check(not AI._best_card(gs, 0).ok, "AI avoids intrinsic suicidal self damage")
	gs = game(); p = gs.player(0); install(gs, "c17007"); p.deck = [instance(gs, "c11902")]; p.avatarHp = 2
	check(not AI._best_card(gs, 0).ok, "AI avoids deck source harm on another character's card")
	# Real automatic hand response under road, and real deck-top response.
	for from_deck in [false, true]:
		gs = game(); p = gs.player(0); var foe: Dictionary = gs.player(1); foe.units[3].level = 3
		gs._deploy_realm(1, Content.card_def("c17007" if from_deck else "c17005"))
		var entry := instance(gs, "c23303")
		if from_deck: foe.deck = [instance(gs, "c11902"), entry]
		else: foe.hand = [entry]
		var target_hp: int = foe.units[0].hp
		play(gs, "c17008", foe.units[0].uid)
		check(events(gs, "response-card").size() == 1 and foe.units[0].hp == target_hp, "automatic counter can read physical hand/top source")
		check(foe.avatarHp == 30 - (2 if from_deck else 1), "automatic response applies matching physical source harm")
		check(not (foe.deck if from_deck else foe.hand).any(func(i): return i.instanceId == entry.instanceId), "automatic response removes real physical source exactly once")
func source_boundaries() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	install(gs, "c17007"); install(gs, "c17005"); p.deck = [instance(gs, "c11902"), instance(gs, "c17001"), instance(gs, "c11902")]
	var stamp := JSON.stringify(gs.snapshot()); var index: int = p.hand.size()
	var view := gs.hand_card_def(0, index)
	check(not view.get("lilyRoadDamage", false), "physical top is not converted into actual hand by road aura")
	check(JSON.stringify(gs.snapshot()) == stamp, "source query never mutates deck through aura")
	check(gs.play_card(0, index) and p.avatarHp == 28 and p.lilySelfDamageCount == 1, "one-level noninstant top pays self2 once, no extra hand-road harm")
	view = gs.hand_card_def(0, p.hand.size())
	check(view.lilyDeckFree and gs.card_payment(0, view).usesInstant, "natural instant top retains shared instant consumption despite independent free cost")
	check(gs.play_card(0, p.hand.size()) and gs.kw_usage(0, "instant").used, "actual instant top consumes original instant allowance")
	var returned: int = p.hand.find_custom(func(i): return i.definitionId == "c17001" and i.get("lilyBounceSpent", false))
	check(p.hand.size() == 2 and returned >= 0 and gs.hand_card_def(0, returned).sourceZone == "hand" and not gs.hand_card_def(0, returned).get("lilyFromDeck", false), "top blood returns original instance to real hand without retaining old deck source")
	# Blood draws from the real next top, so give it a non-empty deck here.
	gs = game(); p = gs.player(0); install(gs, "c17007"); p.deck = [instance(gs, "c17008")]; p.nullifyNextCardTurn = gs.turn_counter
	var hp: int = gs.player(1).units[0].hp
	check(gs.play_card(0, p.hand.size(), gs.player(1).units[0].uid), "actual top card can be countered")
	check(p.deck.is_empty() and p.avatarHp == 28 and gs.player(1).units[0].hp == hp, "counter never returns physical deck card or cancels voyage use harm")
	gs = game(); p = gs.player(0); p.nullifyNextCardTurn = gs.turn_counter
	play(gs, "c17007")
	check(gs.pending_choice.get("type") == "native-divination", "voyage use-time divination survives ordinary nullify")
	finish_choices(gs)
	check(p.realms.is_empty(), "counter still prevents voyage deployment after use-time divination")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[0].spellPower = 2; p.lilySelfDamageCount = 3; gs._grow_unit(foe.units[0], 0, 15); hp = int(foe.units[0].hp)
	play(gs, "c17008", foe.units[0].uid)
	check(foe.units[0].hp == hp - 7, "death actual damage includes lifetime count and original spell power")
	# Top cards with a real pre-use mode keep their original source throughout.
	gs = GS.create(["biyehua", "xiaolunan", "shantong", "taohuayao"], ["bingyong", "fenghuanghuo", "xuenv", "baizangzhu"], 1704)
	for side in gs.players:
		side.hand.clear(); side.energy = 40; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	p = gs.player(0); install(gs, "c17007"); p.units[1].charge = 10
	var burst_id := ""
	for card in Content.cards_for_unit("xiaolunan"):
		if not card.get("movementBurstOptions", []).is_empty(): burst_id = str(card.id); break
	check(not burst_id.is_empty(), "fixture has actual deer burst card")
	if not burst_id.is_empty():
		p.deck = [instance(gs, burst_id)]; var iid: String = p.deck.back().instanceId
		check(gs.VerifiedRules.Movement.request_burst(gs, 0, p.hand.size()), "top card opens its original burst choice")
		check(gs.resolve_divination_choice(0, "cancel-burst") == false, "foreign choice id cannot select a burst")
		var choice: String = str(gs.pending_choice.instanceIds[0])
		check(gs.resolve_divination_choice(0, choice), "ordinary top burst mode resolves by physical instance id")
		var ready: int = gs.VerifiedRules.Movement.ready_hand(gs, 0)
		check(ready == p.hand.size() and p.deck.back().instanceId == iid and p.hand.is_empty(), "burst selection keeps top physical zone and identity")
	gs = GS.create(["biyehua", "datiangou-gangfeng", "shantong", "taohuayao"], ["bingyong", "fenghuanghuo", "xuenv", "baizangzhu"], 1705)
	for side in gs.players:
		side.hand.clear(); side.energy = 40; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	p = gs.player(0); install(gs, "c17007"); p.deck = [instance(gs, "c29001")]; p.energy = 0
	view = gs.playable_card(0, p.hand.size(), true)
	check(view.get("lilyFromDeck", false) and view.get("lilyDeckFree", false) and view.sourceZone == "deck", "origin choice preserves real deck source and one-level free use")
	check(gs.play_card(0, p.hand.size(), null, true) and p.deck.is_empty() and p.hand.is_empty() and p.avatarHp == 28, "actual origin uses same physical top and still pays voyage self2")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800), Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["biyehua", "shuweng", "shantong", "taohuayao"], ["bingyong", "fenghuanghuo", "xuenv", "baizangzhu"], 170); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for unit in side.units: unit.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
		p.deck = [instance(gs, "c11902"), instance(gs, "c17008")]
		hand(b, ["c17007"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type") == "native-divination" and faces(b._choice_layer).size() == 2, "native voyage presents both actual top cards")
		await click(choice_face(b, "c17008")); await settled(b); await click(choice_face(b, "divination-place-top")); await settled(b)
		await click(choice_face(b, "c11902")); await settled(b); await click(choice_face(b, "divination-place-top")); await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.is_empty() and p.deck.back().definitionId == "c17008", "native divination retains top identity then deploys")
		check(b._hand_row.get_child_count() == 1 and b._hand_row.get_child(0).data.sourceZone == "deck", "native hand row has separately marked deck source without hand inflation")
		await capture("%d-01-voyage-top-card" % physical.x)
		var hp: int = foe.units[0].hp; var iid: String = p.deck.back().instanceId; var fire: int = p.energy
		await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and p.deck.back().instanceId == iid and p.energy == fire, "native top targeting leaves resources and physical deck intact")
		escape(); await process_frame
		check(b._pending_target_card == -1 and p.deck.back().instanceId == iid and p.energy == fire, "native Escape cancels top selection without payment")
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(p.hand.is_empty() and p.deck.size() == 1 and foe.units[0].hp == hp - 3 and p.avatarHp == 28, "native enemy click really uses exact top, self2 then scaled3damage")
		check(b._hand_row.get_child_count() == 1 and b._hand_row.get_child(0).data.id == "c11902" and b._hand_row.get_child(0).data.sourceZone == "deck", "native next top immediately replaces old playable card")
		p.realms.clear(); hand(b, ["c17002", "c17001"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		if not gs.can_basic_attack(0, 2).ok: p.attackUsed = false
		check(gs.basic_attack(0, 2), "native fixture actual ally attack for red state"); await settled(b)
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(texts(b).contains("本回合已触发") and texts(b).contains("本局牌手受己方伤害"), "native inspector shows real history and per-turn red allowance")
		await capture("%d-02-red-history-inspector" % physical.x)
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var rules_only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	base_and_history(); blood_bounce(); forms_and_awakening(); realms_and_road(); voyage_physical_sources(); ai_and_cross_role(); source_boundaries()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("SPIDER_LILY checks=%d failures=%d" % [checks, failures]); quit(0 if failures == 0 else 1)
