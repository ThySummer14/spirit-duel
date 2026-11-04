extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const AS := preload("res://scripts/ape_sleeve_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1; printerr("APE_SLEEVE_FAIL ", detail)

func game(own: Array = ["chuanyuan", "xiaoxiuzhishou", "fenghuanghuo", "taohuayao"]) -> GS:
	var gs := GS.create(own, ["bingyong", "fenghuanghuo", "yaodaoji", "baizangzhu"], 294296)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	for side in 2:
		for u in gs.player(side).units:
			if AS.role(u)=="ape": AS.set_stats(gs,side,u,2,5)
	gs.rule_events.clear(); return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "as-test-%d" % gs.next_card_id}); gs.next_card_id += 1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null) -> void:
	var h := give(gs, id); var legal: Dictionary = gs.can_play_card(0, h, target)
	check(gs.play_card(0, h, target), "actual card use " + id + " " + str(legal.get("reason", "")))

func clone(gs) -> GS:
	var copy := GS.new()
	for prop in gs.get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = gs.get(str(prop.name))
			copy.set(str(prop.name), JSON.parse_string(JSON.stringify(value)) if value is Array or value is Dictionary else value)
	return copy

func definitions() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	check(p.units[0].attack == 2 and p.units[0].maxHp == 5 and p.units[1].attack == 2 and p.units[1].maxHp == 4, "printed base2/5 and2/4")
	check(p.units[0].passive_hooks.is_empty() and p.units[1].passive_hooks.is_empty(), "historical numeric passive mapping removed")
	for role in [294, 296]:
		for n in range(1,9):
			var c := Content.card_def("c%d%02d" % [role,n])
			check(c.get("apeSleeveRules",false) and not c.effects.is_empty(), "native dispatcher " + str(c.id))
			check(FileAccess.file_exists("res://assets/official/cards/%s.png" % c.id), "complete original card texture " + str(c.id))
			check(not c.get("verificationPending",[]).is_empty(), "client verification boundary " + str(c.id))
	check(Content.card_def("c29606").verifiedRules and not Content.card_def("c29606").verificationPending.is_empty(), "Jieméi has executable rules and explicit cross-client verification boundary")

func ape_swap_and_generate() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	u.hp = 3; var deck := int(p.deck.size()); play(gs, "c29401")
	check(u.attack == 3 and u.hp == 2 and u.maxHp == 2, "swap uses actual wounded life3, not maximum5")
	check(p.deck.size() == deck-1 and gs.kw_usage(0,"instant").used, "instant swaps then draws a real card")
	check(gs.end_turn(0) and gs.end_turn(1), "actual turn cycle")
	check(u.attack == 2 and u.hp == 3, "own turn base ability exchanges actual stats")
	gs = game(); p = gs.player(0); u = p.units[0]
	play(gs,"c29406"); var attack := int(u.attack); var life := int(u.hp)
	gs.end_turn(0); gs.end_turn(1)
	check(u.awakened and u.attack == attack and u.hp == life, "awakening replaces base swap")
	var generated := -1
	for i in p.hand.size():
		if p.hand[i].get("apeFree",false): generated = i
	check(generated >= 0 and gs.hand_card_def(0,generated).cost == 0, "awakening creates one real zero-fire Bianhuan instance")
	if generated >= 0:
		p.levelUpUsed = true; p.energy = 0
		check(gs.play_card(0,generated), "generated card can be played at zero fire")
		check(u.attack == life and u.hp == attack and p.energy == 0, "generated zero-fire card retains actual swap")
	var save := gs.snapshot(); var restored := clone(gs)
	check(JSON.parse_string(JSON.stringify(restored.snapshot())) == JSON.parse_string(JSON.stringify(save)), "swapped stats and generated instance round trip")
	gs = game(); u = gs.player(0).units[0]; gs._grow_unit(u,-2,0); play(gs,"c29401")
	check(u.hp == 0 and u.knockout > 0, "swapping zero power causes actual knockout instead of clamping to one")

func ape_copy_paper_and_all() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	u.hp = 3; e.units[1].keywords = ["veil"]
	var h := give(gs,"c29402"); var ids := gs.valid_targets(0,gs.hand_card_def(0,h)); var fire := int(p.energy)
	check(ids.has(p.units[2].uid) and ids.has(e.units[0].uid) and not ids.has(e.units[1].uid), "copy either side with enemy veil restriction")
	check(not gs.play_card(0,h,e.units[1].uid) and p.energy == fire, "illegal copy preserves hand and energy")
	check(gs.play_card(0,h,e.units[0].uid) and e.units[0].attack == 2 and e.units[0].hp == 3, "copy uses current3 life without changing source")
	gs = game(); p = gs.player(0); e = gs.player(1); u = p.units[0]
	p.avatarHp = 20; u.hp = 4; e.units[0].barrier = true
	play(gs,"c29404",e.units[0].uid)
	check(e.units[0].hp == e.units[0].maxHp and not e.units[0].barrier and p.avatarHp == 24, "paper damage can be blocked while independent snapshot4 healing still occurs")
	gs = game(); p = gs.player(0); u = p.units[0]
	gs._grow_unit(p.units[2],6,6); p.units[2].hp = 7
	gs._knockout_unit(p.units[3],1,0); gs._resolve_resolution_stack()
	play(gs,"c29405",p.units[2].uid)
	check(p.units[0].attack == p.units[2].attack and p.units[0].hp == 7 and p.units[1].hp == 7, "all copies one original snapshot to all living allies")
	check(p.units[3].hp == 0, "all-copy never revives defeated allies")
	gs._knockout_unit(u,1,0); gs._resolve_resolution_stack(); gs.VerifiedRules.Peach.revive(gs,0,3,u,false,false)
	check(u.attack == 2 and u.maxHp == 5 and not u.has("apeStatAttack"), "ordinary copied stats clear at real death and revival")

func ape_combat_and_moon() -> void:
	for choice in ["ape-attack","ape-life"]:
		var gs := game(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
		gs._grow_unit(p.units[2],7,8); e.units[0].front = 1; gs._grow_unit(e.units[0],-2,20)
		var attack := int(u.attack); var life := int(u.hp); var enemy_hp := int(e.units[0].hp)
		play(gs,"c29403",e.units[0].uid)
		check(gs.pending_choice.get("type") == AS.CHOICE and gs.phase == "choice", "mimic pauses for real player choice")
		check(not gs.resolve_divination_choice(0,"illegal") and not gs.pending_choice.is_empty(), "mimic rejects an unoffered mode")
		var restored := clone(gs)
		check(restored.pending_choice.instanceIds == ["ape-attack","ape-life"], "mimic continuation serializes both real choices")
		check(gs.resolve_divination_choice(0,choice), "actual chosen mimic branch " + choice)
		check(u.attack == attack and u.maxHp == life and not u.has("apeCombatAttack"), "mimic ends with original stats " + choice)
		check(e.units[0].hp == enemy_hp - (9 if choice == "ape-attack" else 2), "mimic attack uses chosen corresponding maximum " + choice)
	var gs := game(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	gs._grow_unit(e.units[1],1,8); e.units[1].front = 0; var attack := int(u.attack); var hp := int(u.maxHp); var target_hp := int(e.units[1].hp)
	play(gs,"c29407",e.units[1].uid)
	check(u.attack == attack+3 and u.maxHp == hp+target_hp and u.has("apeTurnAttack"), "seamless gains selected reserve snapshot before pursuit battle")
	gs.end_turn(0)
	check(u.attack == attack and u.maxHp == hp and not u.has("apeTurnAttack"), "seamless expires at actual turn end")
	gs = game(); p = gs.player(0); e = gs.player(1); u = p.units[0]
	gs._grow_unit(e.units[2],9,15); e.units[2].hp = 8
	play(gs,"c29408")
	check(u.attack == 12 and u.hp == 8, "moon entry takes independent field maxima of current power/life")
	gs._grow_unit(e.units[1],15,20); var maximum := AS.maxima(gs,[0,1]); gs.end_turn(0)
	check(u.attack == maximum.attack and u.hp == maximum.hp, "moon repeats on enemy turn start")

func sleeve_damage_and_focus() -> void:
	for focus in [false,true]:
		var gs := game(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
		p.energy = 1 if focus else 0
		var before: Array = e.units.map(func(u): return int(u.hp)); play(gs,"c29601",e.units[0].uid)
		var changed := 0
		for i in e.units.size():
			if int(e.units[i].hp) < int(before[i]): changed += 1
		check(changed == (2 if focus else 1) and e.units[0].hp == before[0]-2, "needle focus damages a distinct actual enemy " + str(focus))
		check(e.avatarHp == (28 if focus else 29) and p.energy == 0, "one base ability hit per real damaged shikigami " + str(focus))
	var gs := game(); var e: Dictionary = gs.player(1); e.units[0].barrier = true; gs.player(0).energy = 0
	play(gs,"c29601",e.units[0].uid)
	check(e.avatarHp == 30 and not e.units[0].barrier, "fully prevented damage cannot trigger sleeve passive")
	gs = game(); e = gs.player(1); gs._grow_unit(e.units[0],0,30); var hp := int(e.units[0].hp)
	play(gs,"c29607",e.units[0].uid)
	check(e.units[0].hp == hp-15 and e.avatarHp == 25, "thousand is 3damage then four repetitions with five real passive triggers")
	gs = game(); e = gs.player(1); play(gs,"c29608")
	check(gs.player(0).units[1].awakened and e.avatarHp == 28, "awakening printed random2x2 resolves before enabling new ability aura")
	for u in e.units: gs._grow_unit(u,0,10)
	var face := int(e.avatarHp); gs.player(0).energy = 0; play(gs,"c29601",e.units[0].uid)
	check(e.avatarHp == face-2 and AS.base_damage_bonus(gs,0) == 1, "awakened sleeve amplifies her own base damage only")

func sleeve_marks_forms_reset() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
	gs._grow_unit(e.units[0],0,12); play(gs,"c29602",e.units[0].uid); var hp := int(e.units[0].hp)
	gs._knockout_unit(e.units[1],0,2); gs._resolve_resolution_stack()
	check(e.units[0].hp == hp-4 and not e.units[0].has("sleeveMend"), "other ally knockout really consumes mend and deals4")
	gs._knockout_unit(e.units[2],0,2); gs._resolve_resolution_stack()
	check(e.units[0].hp == hp-4, "consumed mend cannot trigger a second time")
	gs = game(); p = gs.player(0); e = gs.player(1)
	play(gs,"c29603"); var face := int(e.avatarHp); p.energy = 0; play(gs,"c29601",e.units[0].uid)
	check(e.avatarHp == face-2, "single selected enemy spell triggers one random form hit and one base hit each")
	gs = game(); p = gs.player(0); e = gs.player(1); play(gs,"c29605"); face = int(e.avatarHp)
	check(face == 29, "attack form has real entry random hit")
	check(gs.basic_attack(0,0), "ally makes actual basic attack")
	check(e.avatarHp == face-3, "ally attack triggers form before direct2 combat damage")
	gs = game(); e = gs.player(1); gs._grow_unit(e.units[0],8,10); e.units[0].barrier = true
	play(gs,"c29604",e.units[0].uid)
	check(e.units[0].attack == e.units[0].baseAttack and e.units[0].hp == e.units[0].baseMaxHp and not e.units[0].barrier, "needle reset restores base stats before independently blocked4 damage")
	gs = game(); e = gs.player(1); gs.player(0).energy = 0; play(gs,"c29606",e.units[0].uid)
	check(e.units[0].has("sleeveThread"), "thread card has real persistent attachment")
	gs._knockout_unit(e.units[0],0,2); gs._resolve_resolution_stack(); gs.VerifiedRules.Peach.revive(gs,1,3,e.units[0],false,false)
	check(e.units[0].has("sleeveThread"), "permanent attachment survives knockout and revival")

func sleeve_thread_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
	for u in e.units: gs._grow_unit(u,0,20)
	p.energy = 0; play(gs,"c29606",e.units[0].uid)
	var first := int(e.units[0].hp); var other := int(e.units[1].hp); var face := int(e.avatarHp)
	p.energy = 1; play(gs,"c29601",e.units[1].uid)
	check(e.units[0].hp == first-3 and e.units[1].hp == other-2 and e.avatarHp == face-2, "thread actual3 hit follows sleeve damage and owns another base passive trigger")
	p.energy = 1; play(gs,"c29601",e.units[1].uid)
	check(e.units[0].hp == first-3, "thread is once per real turn and cannot recursively trigger itself")
	gs.end_turn(0); gs.end_turn(1); e.hand.clear(); p.levelUpUsed = true; p.energy = 0; first = int(e.units[0].hp)
	e.units[0].shield = 0; e.units[0].shieldExpires = 0
	play(gs,"c29601",e.units[1].uid)
	check(e.units[0].hp == first-3, "thread regains trigger on next actual own turn")
	p.energy = 1; play(gs,"c29606",e.units[2].uid)
	check(not e.units[0].has("sleeveThreadPermanent") and e.units[2].has("sleeveThreadPermanent"), "unique thread relocates and removes old permanent reattachment")
	AS.remove_charm(gs,1,2)
	check(not e.units[2].has("sleeveThread") and e.units[2].has("sleeveThreadPermanent"), "dispel removes active charm while permanent future reattachment remains")
	gs._knockout_unit(e.units[2],0,2); gs._resolve_resolution_stack(); gs.VerifiedRules.Peach.revive(gs,1,3,e.units[2],false,false)
	check(e.units[2].has("sleeveThread"), "real revival reattaches previously dispelled permanent thread")
	gs = game(); p = gs.player(0); e = gs.player(1); gs._grow_unit(e.units[0],0,20)
	play(gs,"c29602",e.units[0].uid); face = int(e.avatarHp)
	gs._knockout_unit(e.units[1],0,2); gs._resolve_resolution_stack()
	check(e.avatarHp == face, "mend is attached enemy's self damage and cannot falsely trigger sleeve passive")

func ai_and_base_ability_cross() -> void:
	var opening := GS.create(["chuanyuan","xiaoxiuzhishou","fenghuanghuo","taohuayao"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],294296)
	check(opening.player(0).units[0].attack == 5 and opening.player(0).units[0].hp == 2, "first actual own turn already triggers printed base swap")
	var gs := game(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
	for u in e.units: gs._grow_unit(u,0,20)
	play(gs,"c29608"); e.units[0].front = 1
	var hp := int(e.units[0].hp); var face := int(e.avatarHp)
	play(gs,"c12401")
	check(e.units[0].hp == hp-2 and e.avatarHp == face-2, "actual Phoenix base projectile gains1 while printed spell remains2")
	gs._knockout_unit(p.units[1],1,0); gs._resolve_resolution_stack(); hp = int(e.units[0].hp)
	play(gs,"c12401")
	check(e.units[0].hp == hp-1 and AS.base_damage_bonus(gs,0) == 0, "defeated sleeve disables ongoing ally base ability aura")
	gs = game(); p = gs.player(0); e = gs.player(1)
	e.units[0].front = 1; gs._grow_unit(e.units[0],-2,20); gs._grow_unit(p.units[2],6,0)
	play(gs,"c29403",e.units[0].uid)
	check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty(), "actual AI resolves legal mimic choice to completed combat")
	gs = game(); p = gs.player(0); e = gs.player(1)
	give(gs,"c29601"); var best: Dictionary = AI._best_card(gs,0)
	check(best.ok and gs.valid_targets(0,gs.hand_card_def(0,int(best.hand))).has(best.target), "actual AI selects legal enemy-only sleeve target")
	check(AI.take_action(gs,0) and p.hand.is_empty(), "actual AI executes sleeve spell and focused branch")

func ai_full_card_set() -> void:
	for role in [294,296]:
		for n in range(1,9):
			var gs := game(); var id := "c%d%02d"%[role,n]
			give(gs,id); var best: Dictionary=AI._best_card(gs,0)
			check(best.ok and best.card_id==id,"AI selects printed subject "+id)
			if not best.ok:continue
			check(gs.play_card(0,int(best.hand),best.target,bool(best.get("origin",false))),"AI executes actual legal use "+id)
			var guard := 0
			while not gs.pending_choice.is_empty() and guard<8:
				guard+=1;check(AI._resolve_choice(gs,0),"AI resolves real followup choice "+id)
			check(gs.pending_choice.is_empty() and gs.resolution_stack.is_empty(),"AI finishes subject resolution "+id)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical; DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["chuanyuan","xiaoxiuzhishou","fenghuanghuo","taohuayao"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],294296)
		b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.levelUpUsed = true; side.energy = 40
			for unit in side.units: unit.level = 3
		root.add_child(b); await create_timer(0.4).timeout
		var gs = b.gs; var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
		e.units[0].front = 1; gs._grow_unit(e.units[0],-2,12); gs._grow_unit(p.units[2],7,0)
		hand(b,["c29403"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		if b._pending_target_card >= 0: await click(b._unit_widget(e.units[0].uid)); await settled(b)
		check(gs.pending_choice.get("type") == AS.CHOICE, "native real mimic opens mode choice " + str(physical))
		var tile := choice_face(b,"ape-attack"); check(tile != null and str(tile.data.name).contains("力量") and choice_face(b,"ape-life") != null, "native mimic exposes readable modes")
		await capture("%d-ape-mimic" % physical.x)
		if tile != null: await click(tile); await settled(b)
		check(gs.pending_choice.is_empty() and not p.units[0].has("apeCombatAttack"), "native choice completes actual battle and removes temporary modifier")
		hand(b,["c29602"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		var fire := int(p.energy); await click(b._unit_widget(p.units[0].uid))
		check(p.energy == fire and not p.units[0].has("sleeveMend"), "native enemy-only spell rejects own unit without payment")
		await click(b._unit_widget(e.units[1].uid)); await settled(b)
		check(e.units[1].has("sleeveMend") and gs.player(0).hand.is_empty(), "native real enemy target installs mend")
		await capture("%d-sleeve-mend" % physical.x)
		for role in [294,296]:
			for n in range(1,9): check(FileAccess.file_exists("res://assets/official/cards/c%d%02d.png" % [role,n]), "actual original textures supplied")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	definitions(); ape_swap_and_generate(); ape_copy_paper_and_all(); ape_combat_and_moon(); sleeve_damage_and_focus(); sleeve_marks_forms_reset(); sleeve_thread_rules(); ai_and_base_ability_cross(); ai_full_card_set()
	var args := OS.get_cmdline_user_args()
	if args.has("ui"):
		for arg in args:
			if arg != "ui": out = arg
		if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
		await ui_checks()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("APE_SLEEVE_VERIFY checks=%d failures=%d" % [checks,failures]); quit(1 if failures > 0 else 0)
