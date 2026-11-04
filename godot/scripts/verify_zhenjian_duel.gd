extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const ZD := preload("res://scripts/zhenjian_duel_rules.gd")
const CP := preload("res://scripts/charged_pair_rules.gd")
const AI := preload("res://scripts/game_ai.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("ZHENJIAN_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(["jicanghai", "wuchen", "rihefang", "taohuayao"], ["wuchen", "jicanghai", "baizangzhu", "taohuayao"], 264265)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.rule_events.clear(); return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "zd-test-%d" % gs.next_card_id})
	gs.next_card_id += 1; return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "actual card use " + id)

func charge(gs, id: String, target = null, owner: int = 0) -> void:
	var h := give(gs, id, owner); var fire := int(gs.player(owner).energy)
	check(CP.request_mode(gs, owner, h), "mode choice opens " + id)
	check(gs.resolve_divination_choice(owner, "charged-store"), "select actual charge " + id)
	check(gs.player(owner).energy == fire, "choice pays nothing " + id)
	check(CP.ready_hand(gs, owner) == h and gs.play_card(owner, h, target), "store actual card " + id)

func cycle(gs) -> void:
	check(gs.end_turn(0) and gs.end_turn(1), "actual full turn cycle")

func release_now(gs, owner: int, src: int) -> void:
	check(CP.release(gs, owner, src), "actual stored release")
	gs._resolve_resolution_stack()

func basic_cards() -> void:
	var gs := game(); var u: Dictionary = gs.player(0).units[0]
	check(u.attack == 2 and u.maxHp == 6 and gs.player(0).units[1].attack == 3 and gs.player(0).units[1].maxHp == 4, "printed base bodies replace old mappings")
	var used := int(gs.player(0).cardsPlayedThisTurn)
	charge(gs, "c26401")
	check(u.attack == 5 and u.has("lanternStored") and gs.player(0).energy == 39, "charging adds actual level3 power and pays once")
	check(gs.player(0).cardsPlayedThisTurn == used and gs.player(1).avatarHp == 30, "charging is not use and does not attack")
	var h := give(gs, "c26404"); check(not CP.request_mode(gs, 0, h), "existing charge cannot be overwritten by player")
	gs.player(0).hand.clear(); release_now(gs, 0, 0)
	check(not u.has("lanternStored") and u.attack == 2 and gs.player(1).avatarHp == 26, "charged smash extra1 plus printed1, charging aura removed before attack")
	gs = game(); play(gs, "c26401")
	check(gs.player(1).avatarHp == 27 and gs.player(0).units[0].shield == 1, "ordinary smash lacks charged1 and keeps printed armor")
	gs = game(); charge(gs, "c26501"); gs.player(1).units[1].front = 1; release_now(gs, 0, 1)
	check(gs.player(1).avatarHp == 26 and gs.player(1).units[1].hp == 6, "charged ghost slash direct hits avatar through real defender")
	gs = game(); gs.player(1).units[1].front = 1; play(gs, "c26501")
	check(gs.player(1).avatarHp == 30 and gs.player(1).units[1].hp == 2, "ordinary ghost slash hits actual front")
	gs = game(); charge(gs, "c26506"); release_now(gs, 0, 1)
	check(gs.player(1).avatarHp == 20, "charged triple ambush gives combo two5 hits")
	gs = game(); play(gs, "c26506"); check(gs.player(1).avatarHp == 25, "ordinary triple ambush has one hit")

func whirl_and_awake() -> void:
	var gs := game(); var u: Dictionary = gs.player(0).units[0]; var enemy: Dictionary = gs.player(1).units[1]
	gs._grow_unit(enemy, 0, 15); enemy.front = 1
	charge(gs, "c26402"); release_now(gs, 0, 0)
	check(gs.pending_choice.get("type") == "zd-whirl" and int(gs.pending_choice.amount) == 2, "charged whirl creates actual half-damage target choice")
	check(enemy.uid not in gs.pending_choice.instanceIds and "avatar-1" in gs.pending_choice.instanceIds and gs.player(1).units[2].uid in gs.pending_choice.instanceIds, "choice excludes original target, allows another unit or avatar")
	var energy := int(gs.player(0).energy)
	check(not gs.resolve_divination_choice(0, enemy.uid) and gs.player(0).energy == energy, "illegal repeated target cannot resolve or pay")
	check(gs.resolve_divination_choice(0, "avatar-1") and gs.player(1).avatarHp == 28, "chosen other avatar receives actual2")
	gs = game(); play(gs, "c26402"); check(gs.pending_choice.is_empty() and gs.player(1).avatarHp == 26, "uncharged whirl does not invent secondary hit")
	gs = game(); u = gs.player(0).units[0]; play(gs, "c26406"); charge(gs, "c26401")
	check(u.awakened and u.attack == 6 and u.maxHp == 7, "awakening retains level-based charging power")
	gs.player(0).hand.clear(); cycle(gs)
	check(u.has("lanternStored") and gs.player(1).avatarHp == 30, "awake canghai no longer auto releases on turn start")
	check(gs.release_charge(0, 0), "public manual-release command")
	check(not u.has("lanternStored") and u.attack == 3 and gs.player(1).avatarHp == 24, "double charge effect adds2 without doubling normal whole card attack")
	check(not gs.release_charge(0, 0), "empty manual release is illegal")
	gs = game(); u = gs.player(0).units[0]; play(gs, "c26406"); charge(gs, "c26402")
	check(gs.release_charge(0, 0), "manual charged whirl")
	check(gs.pending_choice.get("type") == "zd-whirl", "awake whirl first secondary choice")
	check(gs.resolve_divination_choice(0, str(gs.player(1).units[1].uid)), "awake first secondary target")
	check(gs.pending_choice.get("type") == "zd-whirl", "awake whirl second independent secondary choice")
	check(gs.resolve_divination_choice(0, str(gs.player(1).units[2].uid)), "awake second secondary target")

func defensive_cards() -> void:
	var gs := game(); var u: Dictionary = gs.player(0).units[0]
	charge(gs, "c26403"); u.front = 1; check(gs.end_turn(0), "enemy turn for stored flame")
	var enemy: Dictionary = gs.player(1).units[0]
	check(gs.basic_attack(1, 0), "actual enemy attack triggers flame")
	check(not u.has("lanternStored") and u.hp == 6 and not u.get("barrier", false), "flame releases automatically, its actual barrier absorbs original attack")
	check(gs.rule_events.any(func(e): return e.kind == "damage-resolved" and e.get("card", {}).get("id") == "c26403" and int(e.amount) == 2) and enemy.hp == 0 and gs.player(1).avatarHp == 30, "flame projectiles current-power2 before original battle counterstrike2")
	gs = game(); u = gs.player(0).units[0]; charge(gs, "c26404"); u.front = 1; check(gs.end_turn(0), "enemy turn for counter")
	charge(gs, "c26501", null, 1)
	var old_deck: int = gs.player(0).deck.size()
	check(gs.basic_attack(1, 0), "charging attacker actually attempts attack")
	check(gs.player(1).units[0].hp == 0 and u.hp == 6 and not u.has("lanternStored"), "charged counter destroys original charging attacker before impact")
	check(gs.player(0).deck.size() == old_deck-1, "counter charged clause actually draws1")
	gs = game(); u = gs.player(0).units[0]; charge(gs, "c26404"); u.front = 1; check(gs.end_turn(0), "negative branch enemy turn")
	check(gs.basic_attack(1, 0), "uncharged attacker attempts attack")
	check(u.has("lanternStored") and u.hp == 3, "counter stays stored against uncharged attacker")
	gs = game(); u = gs.player(0).units[0]; play(gs, "c26405")
	check(u.attack == 4 and u.maxHp == 7, "rock exact4/7")
	var hit: Dictionary = gs._damage_unit(0, 0, 3, 1, 0, true)
	check(hit.damage == 2 and u.hp == 5, "rock subtracts1 from actual combat damage")
	gs._damage_unit(0, 0, 1, 1, 0)
	check(u.hp == 4, "rock does not reduce noncombat damage")
	gs.player(1).units[1].front = 1; check(gs.basic_attack(0, 0), "rock actual shikigami battle")
	check(u.has("lanternStored") and int(u.lanternStored.card.level) == 1, "rock charges a real random printed level1 card after shikigami battle")

func fierce_and_tide() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	play(gs, "c26407")
	check(u.has("lanternStored") and u.lanternStored.card.id == "c26407" and gs.player(1).avatarHp == 27, "tide hand use attacks then stores real same card")
	release_now(gs, 0, 0)
	check(gs.player(1).avatarHp == 21 and not u.has("lanternStored"), "charged tide attacks plus charged one more use, without hand-use loop")
	gs = game(); u = gs.player(0).units[0]; play(gs, "c26406"); charge(gs, "c26407")
	check(gs.release_charge(0, 0), "awake tide manual release")
	check(gs.player(1).avatarHp == 18 and not u.has("lanternStored"), "awake tide repeats charged effect twice but total3 attacks")
	gs = game(); p = gs.player(0); u = p.units[0]; play(gs, "c26401"); p.hand.clear(); play(gs, "c26408")
	check(u.attack == 4 and u.maxHp == 7 and p.hand.size() == 1 and p.hand[0].definitionId == "c26401", "fierce exact4/7 and entry draws a real used combat card")
	var h := give(gs, "c26403"); var c: Dictionary = gs.hand_card_def(0, h)
	check(c.keywords.has("instant") and gs.card_payment(0, c).cost == 0, "fierce grants actual shared instant to all canghai cards")
	var hp := int(u.hp); gs._damage_unit(0, 0, 5, 1, 0)
	check(u.hp == hp and not gs.VerifiedRules.Panguan.destroy(gs, 1, 0, 0, 0), "fierce prevents actual noncombat damage and direct destroy")
	var armor := int(u.shield)
	gs._damage_unit(0, 0, 2, 1, 0, true)
	check(u.hp == hp-maxi(0, 2-armor), "fierce still takes combat damage after existing printed armor")
	p.hand.clear(); cycle(gs)
	check(p.hand.any(func(i): return i.definitionId == "c26401"), "fierce own turn-start gives historical combat")
	gs = game(); u = gs.player(0).units[0]; play(gs, "c26408")
	check(gs.player(0).hand.is_empty(), "empty fierce history creates no invented combat card")

func wuchen_moves() -> void:
	var gs := game(); var u: Dictionary = gs.player(0).units[1]
	play(gs, "c26504")
	check(u.front == 0 and int(u.get("zdInstantTurn", -1)) == gs.turn_counter, "shift attacks then actually returns rear and arms next instant")
	var h := give(gs, "c26502"); var c: Dictionary = gs.hand_card_def(0, h)
	check(c.enhanced and gs.card_payment(0, c).cost == 0, "flash enhanced after actual attack is free")
	check(gs.play_card(0, h) and u.front == 1 and u.get("zdStepCounter", false), "flash actually moves, draws and arms charge counter")
	gs = game(); u = gs.player(0).units[1]; var target: Dictionary = gs.player(1).units[1]
	gs._grow_unit(target, 0, 15); target.front = 0
	play(gs, "c26503", target.uid)
	check(u.has("lanternStored") and u.lanternStored.card.id == "wuchen-followup" and u.lanternStored.zdFollowupTarget == target.uid, "grapple pursues and stores actual followup bound to selected entity")
	var old_hp := int(target.hp); release_now(gs, 0, 1)
	check(target.hp == old_hp-4, "followup attacks remembered living reserve target with printed+1")
	gs = game(); u = gs.player(0).units[1]; play(gs, "c26507")
	check(u.awakened and gs.player(0).hand.size() == 1 and Content.card_def(gs.player(0).hand[0].definitionId).type == "combat", "awake gets a real printed random wuchen combat")
	gs.player(0).hand.clear(); check(gs.VerifiedRules.Movement.move_to(gs, 0, 1, 1), "awake actual movement")
	check(int(u.get("zdFreeTurn", -1)) == gs.turn_counter, "awake first move grants next free charged clause")
	h = give(gs, "c26501"); c = gs.hand_card_def(0, h); gs.player(1).units[1].front = 1
	check(gs.card_payment(0, c).cost == 0 and gs.play_card(0, h), "awake next uncharged ghost actually free")
	check(gs.player(1).avatarHp == 25 and gs.player(1).units[1].hp == 6, "awake uncharged ghost gets actual direct charged clause")
	check(gs.VerifiedRules.Movement.move_to(gs, 0, 1, 0), "awake second actual movement")
	check(int(u.get("zdFreeTurn", -1)) != gs.turn_counter, "awake once-per-turn move cannot rearm on later move")
	gs = game(); u = gs.player(0).units[1]; play(gs, "c26505")
	check(u.attack == 4 and u.maxHp == 5 and u.front == 1, "discharge exact4/5 entry moves")
	var amount: Dictionary = gs._damage_unit(0, 1, 3, 1, 0)
	check(amount.damage == 0 and u.hp == 5 and u.front == 0, "discharge prevents first actual damage and moves")
	gs._damage_unit(0, 1, 3, 1, 0)
	check(u.hp == 2 and u.front == 0, "second damage same turn is not prevented")

func sword_and_ai() -> void:
	var gs := game(); var u: Dictionary = gs.player(0).units[1]; var enemy: Dictionary = gs.player(1).units[1]
	for idx in [0, 2, 3]: gs.player(1).units[idx].hp = 0; gs.player(1).units[idx].knockout = 2
	gs._grow_unit(enemy, 0, 15)
	check(CP.store_copy(gs, 1, 1, Content.card_def("c26401"), null), "actual enemy charge for sword target")
	play(gs, "c26508")
	check(u.attack == 4 and u.maxHp == 7 and u.swift and u.get("formRules", {}).get("substitute", false), "sword exact4/7 swift and real generic substitute")
	var hp := int(enemy.hp)
	charge(gs, "c26501")
	check(enemy.hp == hp-10 and gs.player(1).avatarHp == 30, "sword charge event prioritizes actual charging enemy10")
	gs._damage_unit(0, 1, 20, 1, 1)
	check(u.hp == 4 and u.form.is_empty() and u.knockout == 0, "sword real substitute removes form and restores base body without knockout")
	gs = game(); u = gs.player(0).units[1]
	for target in gs.player(1).units: target.hp = 0; target.knockout = 2
	play(gs, "c26508"); check(gs.VerifiedRules.Movement.move_to(gs, 0, 1, 1), "sword actual movement without charged target")
	gs._resolve_resolution_stack()
	check(gs.player(1).avatarHp == 26, "sword without charged enemy deals printed4 to actual remaining avatar")
	gs = game(); give(gs, "c26501"); check(AI.take_action(gs, 0), "AI takes legal charged ghost action")
	check(gs.player(0).units[1].has("lanternStored"), "AI uses genuine charge alternative")
	gs = game(); play(gs, "c26406"); charge(gs, "c26401"); gs.player(0).hand.clear()
	check(AI.take_action(gs, 0) and not gs.player(0).units[0].has("lanternStored"), "AI can issue awake manual release")
	gs = game(); charge(gs, "c26402"); release_now(gs, 0, 0)
	check(AI.take_action(gs, 0) and gs.pending_choice.is_empty(), "AI resolves legal other-target choice")
	gs = game(); charge(gs, "c26501"); var stored: Dictionary = JSON.parse_string(JSON.stringify(gs.player(0).units[1].lanternStored))
	check(stored.card.id == "c26501" and stored.instance.definitionId == "c26501" and stored.chargedPair, "charge actual identity and data survive JSON roundtrip")

func destroy_entry_points() -> void:
	var gs := GS.create(["jicanghai", "wuchen", "rihefang", "taohuayao"], ["baimugui", "erkounv", "datiangou", "shimengmo"], 264888)
	for side in gs.players:
		side.hand.clear(); side.energy = 40; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	play(gs, "c26408"); var u: Dictionary = gs.player(0).units[0]
	for i in [1, 2, 3]: gs.player(0).units[i].hp = 0; gs.player(0).units[i].knockout = 2
	u.hp = 6; gs.current_player = 1
	gs.player(0).deck = [{"definitionId":"c26401", "instanceId":"zd-destroy-top"}]
	play(gs, "c19607", null, 1)
	for i in 8:
		if gs.pending_choice.is_empty(): break
		check(AI._resolve_choice(gs, gs.action_player()), "actual enemy divination for all-knowing eye")
	check(u.hp == 6 and not u.form.is_empty(), "Eye actual top-card destroy respects fierce immunity")
	gs.player(1).units[1].charge = 2
	play(gs, "c29508", u.uid, 1)
	check(u.hp == 6 and not u.form.is_empty(), "Futakuchi actual focused wounded-destroy respects fierce immunity")
	gs.player(1).units[2].spellsUsed = 10
	play(gs, "c10508", null, 1)
	check(u.hp == 6 and not u.form.is_empty(), "enhanced actual justice area-destroy respects fierce immunity")
	play(gs, "c18706", null, 1)
	gs.current_player = 0
	gs.player(0).deck = [{"definitionId":"c26401", "instanceId":"zd-nightmare", "nightmareMarks":[{"owner":1,"sourceUid":str(gs.player(1).units[3].uid)}]}]
	gs._draw(0, 1); gs._resolve_resolution_stack()
	check(u.hp == 6 and not u.form.is_empty(), "actual nightmare draw and eternal-sleep destroy respect fierce immunity")
	gs.player(0).deck = [{"definitionId":"c26401", "instanceId":"zd-eye-curse-actual", "eyeCurses":1}]
	gs._draw(0,1);gs._resolve_resolution_stack()
	check(gs.pending_choice.get("type")=="eye-curse", "actual cursed card draw opens curse selection")
	check(gs.resolve_divination_choice(0,"eye-curse-units"), "actual choose two-shikigami destruction curse")
	check(u.hp==6 and not u.form.is_empty(), "actual two-shikigami curse destruction respects fierce immunity")
	gs.player(1).units[0].toxicSwarm = true; u.toxicPoisoned = true
	gs._damage_unit(0, 0, 1, 1, 0, true)
	check(u.hp == 0 and u.knockout > 0, "combat toxic force-knockout is not accidentally blocked by global destroy guard")

func button_named(n: Node, label: String):
	if n is Button and n.text == label: return n
	for child in n.get_children():
		var found = button_named(child, label)
		if found != null: return found
	return null

func edge_cases() -> void:
	var gs := game(); var enemy: Dictionary = gs.player(1).units[0]
	enemy.front = 1; enemy.hp = 2
	charge(gs, "c26401"); release_now(gs, 0, 0)
	check(enemy.hp == 0 and gs.player(1).avatarHp == 28, "charged smash actually pierces overflow2 through real front")
	gs = game(); enemy = gs.player(1).units[0]; enemy.front = 1; enemy.hp = 2
	play(gs, "c26401")
	check(enemy.hp == 0 and gs.player(1).avatarHp == 30, "ordinary smash has no invented pierce")
	gs = game(); enemy = gs.player(1).units[1]; enemy.front = 1; gs._grow_unit(enemy, 15, 20)
	charge(gs, "c26504"); release_now(gs, 0, 1)
	check(gs.player(0).units[1].hp == 4 and gs.player(0).units[1].front == 0, "charged shift survives actual huge counterstrike through immune-combat then retreats")
	gs = game(); var u: Dictionary = gs.player(0).units[0]; play(gs, "c26406"); charge(gs, "c26404"); u.front = 1
	check(gs.end_turn(0), "awake counter enters enemy turn")
	charge(gs, "c26501", null, 1); var deck_size: int = gs.player(0).deck.size()
	check(gs.basic_attack(1, 0), "awake counter faces real charging attacker")
	check(gs.player(1).units[0].hp == 0 and gs.player(0).deck.size() == deck_size-2 and u.hp == 7, "awake automatic counter still fires and charged draw triggers twice")
	gs = game(); u = gs.player(0).units[1]; play(gs, "c26502")
	check(gs.end_turn(0), "step enters enemy turn")
	charge(gs, "c26401", null, 1)
	check(gs.basic_attack(1, 1), "step faces real charging attacker")
	check(gs.player(1).units[1].hp == 0 and u.hp == 4, "step active counter destroys attacker without spending wuchen stored card")
	check(gs.end_turn(1), "step expires at next own begin")
	check(not u.get("zdStepCounter", false), "step actual next-turn boundary clears protection")
	gs = game(); u = gs.player(0).units[1]; play(gs, "c26505"); u.shield = 2; u.armorBreak = 1
	var prevented: Dictionary = gs._damage_unit(0, 1, 10, 1, 0)
	check(prevented.damage == 0 and u.shield == 2 and u.armorBreak == 1, "discharge prevention preserves actual armor and break before consumption")
	gs._damage_unit(0, 1, 2, 1, 0)
	check(u.hp == 4 and u.shield == 0 and u.armorBreak == 0, "later packet consumes actual armor/break then damages1")
	gs = game(); play(gs, "c26406"); charge(gs, "c26401"); u = gs.player(0).units[0]
	gs.VerifiedRules.Stun.apply(gs, 0, 0, 1, 1)
	check(not gs.release_charge(0, 0) and u.has("lanternStored"), "stunned awake unit cannot manually release")

func mode_face(b, label: String):
	for face in faces(b._choice_layer):
		if face.data.get("currentCardStats", "") == label: return face
	return null

func ui_rules() -> void:
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical; DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["jicanghai", "wuchen", "rihefang", "taohuayao"], ["wuchen", "jicanghai", "baizangzhu", "taohuayao"], 264265)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear(); p.energy = 40; p.levelUpUsed = true
			for u in p.units: u.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var p: Dictionary = b.gs.player(0); var u: Dictionary = p.units[0]
		hand(b, ["c26402"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.pending_choice.get("type") == "charged-mode", "native printed card opens real charge/use alternatives")
		await capture("%d-01-mode" % physical.x)
		await click(mode_face(b, "蓄力使用")); await settled(b)
		check(u.has("lanternStored") and u.attack == 5 and p.energy == 39, "native charge pays once and updates actual body")
		check(CP.release(b.gs, 0, 0), "native fixture releases genuine stored whirl"); b.gs._resolve_resolution_stack(); b.gs.state_changed.emit(); await settled(b)
		var target_id := str(b.gs.player(1).units[1].uid)
		check(b.gs.pending_choice.get("type") == "zd-whirl" and choice_face(b, target_id) != null, "native whirl displays actual other-character candidates")
		await capture("%d-02-whirl-target" % physical.x)
		await click(choice_face(b, target_id)); await settled(b)
		check(b.gs.pending_choice.is_empty() and b.gs.player(1).units[1].hp == 4, "native mouse selected another enemy shikigami for half2")
		hand(b, ["c26503"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(target_id).selected, "native grapple exposes real reserve pursuit target")
		await click(b._unit_widget(target_id)); await settled(b)
		check(p.units[1].has("lanternStored") and p.units[1].lanternStored.zdFollowupTarget == target_id, "native pursuit remembers entity for followup")
		await capture("%d-03-followup" % physical.x)
		p.hand.clear(); play(b.gs, "c26406"); charge(b.gs, "c26401"); b._refresh(); await settled(b)
		var manual_button = button_named(b._cmd_bar, "释放蓄力 · 季沧海")
		check(manual_button != null, "native awake charge exposes active manual-release button")
		await capture("%d-04-manual-release" % physical.x)
		var avatar := int(b.gs.player(1).avatarHp)
		if manual_button != null: await click(manual_button); await settled(b)
		check(not u.has("lanternStored") and b.gs.player(1).avatarHp == avatar-6, "native mouse issues manual-release command and charged effect twice")
		b.queue_free(); await process_frame; await process_frame
	for role_id in [264, 265]:
		for n in range(1, 9):
			var face = preload("res://scripts/ui/card_face.gd").new(); var id := "c%d%02d" % [role_id, n]
			face.data = Content.card_def(id); face.refresh_art()
			check(face._original_card != null and face._original_card.resource_path == "res://assets/official/cards/%s.png" % id, "actual original PNG " + id); face.free()

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	if not args.has("--ui-only"):
		basic_cards(); whirl_and_awake(); defensive_cards(); fierce_and_tide(); wuchen_moves(); sword_and_ai(); edge_cases(); destroy_entry_points()
	if not only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("ZHENJIAN_OK checks=%d failures=%d rules_only=%s" % [checks, failures, only])
	quit(0 if failures == 0 else 1)
