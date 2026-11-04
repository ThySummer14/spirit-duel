extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Cotton := preload("res://scripts/cotton_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("COTTON_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["yifanmumian", "shuweng", "shantong", "taohuayao"], ["bingyong", "fenghuanghuo", "xuenv", "baizangzhu"], 261)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true; p.avatarArmor = 0
		for u in p.units: u.level = 3
	gs.rule_events.clear()
	return gs
func instance(gs, id: String) -> Dictionary:
	var inst := {"definitionId": id, "instanceId": "cotton-fixture-%d" % gs.next_card_id}; gs.next_card_id += 1; return inst
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(instance(gs,id)); return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target), "actual use " + id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)
func knock(gs, idx: int) -> void:
	gs._knockout_unit(gs.player(0).units[idx],1,0); gs._resolve_resolution_stack()
func base_and_awake() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	check(u.attack == 2 and u.maxHp == 5 and u.passive_hooks.is_empty(), "base2/5 and old heal-on-other-KO mapping removed")
	p.night = 4; knock(gs,1); check(p.night == 4 and p.units[1].knockout == 2, "nonawake ignores other ally knockout")
	knock(gs,0); check(p.night == 5 and p.units[0].knockout == 2 and p.units[1].knockout == 2, "failednight5 increases1 without fake timer reduction")
	gs = game(); p = gs.player(0); p.night = 5; knock(gs,1); knock(gs,0)
	check(p.units[0].knockout == 1 and p.units[1].knockout == 1 and p.night == 5, "successful selfKO reduces all actualKO timers including self once")
	check(events(gs,"night-triggered").size() == 1, "single base death produces one night event")
	gs = game(); p = gs.player(0); p.night = 5; p.units[1].hp = 0; p.units[1].knockout = 1; knock(gs,0)
	check(p.units[1].hp == p.units[1].maxHp and p.units[1].knockout == 0 and p.units[1].front == 0, "shared KO timer reaching0 really revives to reserve")
	gs = game(); p = gs.player(0); u = p.units[0]; p.night = 7; p.avatarHp = 8
	play(gs,"c26107"); check(p.avatarHp == 15 and u.awakened and u.attack == 4 and u.maxHp == 7, "PNG awakening restores night amount then exact permanent2/2")
	p.night = 4; var hp: int = p.avatarHp; knock(gs,1)
	check(p.night == 6 and p.avatarHp == hp and p.units[1].knockout == 2, "awake independent night5 and night10 failures each add1")
	var ns := events(gs,"night-triggered"); check(ns[-2].threshold == 5 and ns[-1].threshold == 10, "awake death order is5 then10")
	p.night = 10; p.avatarHp = 12; knock(gs,2)
	check(p.units[1].knockout == 1 and p.units[2].knockout == 1 and p.avatarHp == 17 and p.night == 10, "awake allyKO reduces actual timers and heals5 without spendingnight")
	knock(gs,0); check(p.units[0].knockout == 1 and p.units[1].hp > 0 and p.units[2].hp > 0 and p.avatarHp == 22, "awake selfKO snapshots ability before actualdeath and reduces/revives allies")
	gs._knockout_unit(p.units[0],1,0); gs._resolve_resolution_stack(); check(p.avatarHp == 22, "repeat KO command never fabricates another death trigger")
	check(not gs.can_play_card(0,give(gs,"c26107")).ok, "duplicate or KO awakening cannot be manually replayed")
func combat_heal_and_bounce() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]; p.night = 3
	foe.units[0].front = 1; var hp: int = foe.units[0].hp; var idx := give(gs,"c26101"); var iid: String = p.hand[idx].instanceId
	check(gs.play_card(0,idx) and foe.units[0].hp == hp - 3 and foe.units[0].frozen > 0, "choke actual+1attack, night3 stuns actualcombat target")
	check(u.hp == 5 and u.shield == 0, "printed+1armor absorbs actual counter1")
	check(p.hand.size() == 1 and p.hand[0].instanceId == iid and p.hand[0].cottonBounceSpent, "choke bounces same actual instance once")
	check(not gs.hand_card_def(0,0).keywords.has("bounce"), "returned choke loses only bounce")
	check(gs.play_card(0,0) and p.hand.is_empty(), "second choke consumed without repeatedbounce")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.night = 2; foe.units[0].front = 1
	play(gs,"c26101"); check(p.night == 3 and foe.units[0].frozen == 0, "failednight3 cannot stun merely because value becomes3")
	gs = game(); p = gs.player(0); p.night = 0; p.avatarHp = 10; idx = give(gs,"c26102")
	check(gs.hand_card_def(0,idx).currentCardStats.contains("恢复0"), "night0 dynamic heal really0")
	check(gs.play_card(0,idx,"avatar-0") and p.avatarHp == 10, "zeroheal has no invented minimum")
	p.night = 7; play(gs,"c26102","avatar-0"); check(p.avatarHp == 17, "night7 healsplayerexact7")
	foe = gs.player(1); foe.units[0].hp = 1; play(gs,"c26102",foe.units[0].uid)
	check(foe.units[0].hp == foe.units[0].maxHp, "residual warmth can really heal enemy character")
	gs = game(); p = gs.player(0); p.nullifyNextCardTurn = gs.turn_counter; idx = give(gs,"c26101"); iid = p.hand[idx].instanceId
	check(gs.play_card(0,idx) and p.hand.size() == 1 and p.hand[0].instanceId == iid and p.units[0].front == 0, "counter prevents combat but announced bounce remains")
func snow_and_revive() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]; p.night = 5
	play(gs,"c26106"); check(u.attack == 2 and u.maxHp == 5 and u.formRules.cottonSnow, "snow form exactly2/5 and realKO revival ability")
	u.front = 1; knock(gs,0)
	check(u.hp == 5 and u.front == 1 and u.knockout == 0 and u.form.is_empty(), "snow trueKO reduces timer then revives full originalbody into front without restoring deadform")
	check(events(gs,"night-triggered").size() == 1 and events(gs,"peach-revive").size() == 1, "snow emits one realKO night and one realrevival")
	knock(gs,0); check(u.hp == 0 and u.knockout == 1, "removed snow form cannot revive again")
	gs = game(); p = gs.player(0); u = p.units[0]; p.night = 7; var foe: Dictionary = gs.player(1); foe.units[0].front = 1; knock(gs,0)
	var idx := give(gs,"c26104"); var iid: String = p.hand[idx].instanceId
	check(gs.can_play_card(0,idx,u.uid).ok, "snow weave usable while owner KO and can target self")
	check(gs.play_card(0,idx,u.uid) and u.hp == 5 and u.front == 1 and foe.units[0].frozen > 0, "snowweave actualselfrevive and frontmove then night7 stunsenemyfront")
	check(p.hand.size() == 1 and p.hand[0].instanceId == iid and p.hand[0].cottonBounceSpent, "snowweave genuine onebounce retainsphysicalidentity")
	check(not gs.can_play_card(0,0,u.uid).ok, "snowweave cannot revive livingtarget")
	gs = game(); p = gs.player(0); p.night = 6; knock(gs,1); gs.player(1).units[0].front = 1; play(gs,"c26104",p.units[1].uid)
	check(p.units[1].hp > 0 and p.units[1].front == 1 and p.night == 7 and gs.player(1).units[0].frozen == 0, "failednight7 stillrevives and moves but doesnotstun")
	gs = game(); p = gs.player(0); var count: int = p.units.size(); var token := gs.VerifiedRules.Weaver.token(gs,0,0); token.hp = 0; token.knockout = 2; p.units.append(token); idx = give(gs,"c26104")
	check(not gs.valid_targets(0,gs.hand_card_def(0,idx)).has(token.uid), "snowweave excludes realsummoncorpse")
	check(not gs.can_play_card(0,idx,gs.player(1).units[0].uid).ok and p.units.size() == count + 1, "foreign target rejectedwithout touchingunits")
func realm_and_search() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c26103"); var field: Dictionary = p.realms[0]; p.units[0].front = 1; p.night = 4; gs.current_player = 1; gs._grow_unit(foe.units[0],0,20)
	check(gs.basic_attack(1,0) and p.night == 5 and foe.units[0].frozen == 0, "fear first failednight5 gains1 but cannotstun")
	gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(p.night == 5 and foe.units[0].frozen == 0 and int(field.cottonUsedTurn) == gs.turn_counter, "fear onceperturn used even when thresholdfailed")
	gs.turn_counter += 2; gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(foe.units[0].frozen > 0 and p.night == 5, "fear lateractualturnstuns attacker before livecombat night%d frozen%d cottonhp%d front%d used%d turn%d" % [p.night,foe.units[0].frozen,p.units[0].hp,p.units[0].front,field.cottonUsedTurn,gs.turn_counter])
	gs = game(); p = gs.player(0); play(gs,"c26103"); p.night = 5; p.units[1].front = 1; gs.current_player = 1
	check(gs.basic_attack(1,0) and gs.player(1).units[0].frozen == 0 and not p.realms[0].has("cottonUsedTurn"), "PNG fear triggers onlyattack on cotton, nototherally")
	gs = game(); p = gs.player(0); p.night = 5; var a := instance(gs,"c26101"); var b := instance(gs,"c26108"); var unrelated := instance(gs,"c11902"); var reference_only := instance(gs,"c26102"); p.deck = [a,unrelated,b,reference_only]
	play(gs,"c26105"); check(p.deck.size() == 2 and p.deck.any(func(i): return i.instanceId == unrelated.instanceId) and p.hand.size() == 2, "search removes exactlyactualtwo nightcards from realdeck")
	check(p.deck.any(func(i): return i.instanceId == reference_only.instanceId), "referencingnightvalue alone is not a realnightfallability")
	check(p.hand.any(func(i): return i.instanceId == b.instanceId) and p.hand.any(func(i): return i.instanceId == a.instanceId), "search preserves bothphysicalidentities")
	for i in p.hand.size(): check(gs.hand_card_def(0,i).keywords.has("instant"), "searchedcopies gain actualthisturninstant")
	var stamp := JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0); check(JSON.stringify(gs.snapshot()) == stamp, "temporaryinstantviewsarepure")
	gs.turn_counter += 1
	for i in p.hand.size(): check(not gs.hand_card_def(0,i).keywords.has("instant"), "searchinstant expiresatactualturnboundary")
	gs = game(); p = gs.player(0); p.night = 4; p.deck = [instance(gs,"c26101")]; play(gs,"c26105")
	check(p.hand.size() == 1 and p.deck.is_empty() and p.night == 5 and not gs.hand_card_def(0,0).keywords.has("instant"), "less-than2retrieval doesnotequal draw and failed5 grantsnoinstant")
	gs = game(); p = gs.player(0); p.deck.clear(); play(gs,"c26105")
	check(gs.winner == -1 and p.hand.is_empty() and p.get("night",0) == 1, "emptysearch nevermanufacturesdrawordeckout and checksnightonce")
func flurry_and_ai() -> void:
	for n in [0,5,10]:
		var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]; p.night = n; p.avatarHp = 5
		for i in [0,1,2]: gs._grow_unit(foe.units[i],0,20)
		foe.units[1].frozen = 1; foe.units[2].frozen = 1
		var hps: Array = [foe.units[0].hp,foe.units[1].hp,foe.units[2].hp,foe.units[3].hp]; var fire: int = p.energy
		play(gs,"c26108",foe.units[0].uid)
		var amount := 4 if n < 5 else 6
		check(foe.units[0].hp == hps[0]-amount and foe.units[1].hp == hps[1]-amount and foe.units[2].hp == hps[2]-amount and foe.units[3].hp == hps[3], "flurry hits everyinitialstunnedtargetonce and no otherunit night%d" % n)
		check(u.hp == 5 and p.energy == fire-1 and not p.attackUsed, "flurry realimmunecombat and singlecardpayment withoutbasicattackuse")
		check(events(gs,"combat-complete").size() == 3, "threeindependentcombatcontinuations finish")
		check(p.avatarHp == (23 if n == 10 else 5), "night10 reallifesteal eachunshieldedcombatpacket")
		check(p.night == (2 if n == 0 else 6 if n == 5 else 10), "flurry separate5then10checks preserveexactnight")
	for n in range(1,9):
		var gs := game(); var p: Dictionary = gs.player(0); var id := "c261%02d" % n; p.night = 7
		if n == 2: p.avatarHp = 10
		if n == 4: p.units[1].hp = 0; p.units[1].knockout = 2
		give(gs,id); var best := AI._best_card(gs,0)
		check(best.ok and best.card_id == id and gs.can_play_card(0,best.hand,best.target).ok, "AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target), "AIactualuse "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"), "originalPNG "+id)
	var gs := game(); var p: Dictionary = gs.player(0); p.night = 7; p.avatarHp = 2; p.hand.clear()
	gs._deploy_realm(0,Content.card_def("c17007")); p.deck = [instance(gs,"c26102")]
	check(not AI._best_card(gs,0).ok, "AI respects voyage lethal use damage before cotton healing can resolve")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["yifanmumian","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],261); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for u in side.units: u.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); p.night = 7; foe.units[0].front = 1
		knock(gs,1); hand(b,["c26104"]); await settled(b); var fire: int = p.energy
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(b._pending_target_card == 0 and p.energy == fire and p.units[1].hp == 0, "nativesnow rejectsforeignlivingtargetwithoutcost")
		escape(); await process_frame; check(b._pending_target_card == -1 and p.energy == fire, "nativeEscape cancelsreviveselectionwithoutcost")
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(p.units[1].hp > 0 and p.units[1].front == 1 and foe.units[0].frozen > 0, "nativemouseactualrevivesselectedcorpse andmovestofront,stunsenemyfront")
		check(p.hand.size() == 1 and p.hand[0].cottonBounceSpent and not b._hand_row.get_child(0).data.keywords.has("bounce"), "nativebouncedsnowcardlosesbounce")
		await capture("%d-01-snow-revival-bounce" % physical.x)
		p.night = 10; p.avatarHp = 5
		for unit in foe.units: unit.front = 0
		for i in [0,1]: gs._grow_unit(foe.units[i],0,20)
		foe.units[1].frozen = 1; var a: int = foe.units[0].hp; var c: int = foe.units[1].hp
		hand(b,["c26108"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(foe.units[0].hp == a-6 and foe.units[1].hp == c-6 and p.avatarHp == 17 and p.hand.is_empty(), "nativeflurryselectedstun thenrealsequential6damage and12lifesteal")
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(texts(b).contains("入夜10/10"), "nativeinspectordisplaysactualnightstate")
		await capture("%d-02-flurry-real-combats" % physical.x)
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var rules_only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	base_and_awake(); combat_heal_and_bounce(); snow_and_revive(); realm_and_search(); flurry_and_ai()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("COTTON checks=%d failures=%d" % [checks,failures]); quit(0 if failures == 0 else 1)
