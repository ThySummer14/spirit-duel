extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Grove := preload("res://scripts/tree_sakura_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("TREE_SAKURA_FAIL ",detail)

func game() -> GS:
	var gs := GS.create(["renmianshu","yinghuayao","hetong","duyanxiaoseng"],["bingyong","yaodaoji","shantong","bailang"],181184)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"tree-sakura-%d" % gs.next_card_id}); gs.next_card_id += 1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)

func turn(gs, owner: int) -> void:
	check(gs.end_turn(owner),"real turn end %d" % owner)
	gs.player(1-owner).levelUpUsed = true

func tree_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(p.units[0].attack == 1 and p.units[0].maxHp == 6,"tree actual base1/6")
	p.units[0].hp = 1; turn(gs,0)
	check(p.units[0].hp == 6,"enemy start full recovery works in reserve")
	p.units[0].hp = 2; turn(gs,1)
	check(p.units[0].hp == 2,"own start does not repeat enemy-start recovery")
	gs = game(); p = gs.player(0); p.units[0].level = 0; p.units[0].hp = 1; turn(gs,0)
	check(p.units[0].hp == 1,"inactive tree cannot heal at enemy start")
	gs = game(); p = gs.player(0); play(gs,"c18101")
	check(p.units[0].attack == 2 and p.units[0].maxHp == 7 and p.units[0].shield == 0,"root exact2/7, no invented armor")
	check(gs.basic_attack(0,0),"root ordinary attack"); turn(gs,0); turn(gs,1)
	check(p.units[0].front == 1 and p.units[0].shield == 0,"root skips actual turn-start retreat")
	check(gs.basic_attack(0,2),"another ally can still replace anchored tree")
	check(p.units[0].front == 0 and p.units[2].front == 1,"root does not lock replacement")
	gs = game(); p = gs.player(0); play(gs,"c18103"); p.energy = 3
	check(p.units[0].attack == 2 and p.units[0].maxHp == 6,"nutrients exact2/6")
	turn(gs,0); check(p.units[0].maxHp == 6,"nutrients does not trigger at own end")
	turn(gs,1); check(p.units[0].maxHp == 9 and p.units[0].hp == 9,"enemy end grants own3 remaining fire as permanent3health")
	p.energy = 30; play(gs,"c18106")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 15,"permanent nutrients survive form replacement")
	gs._knockout_unit(p.units[0]); check(p.units[0].maxHp == 9,"nutrients survive knockout on underlying body")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18108"); check(p.units[0].attack == 8 and p.units[0].maxHp == 8,"tree awakening exact0/2 and power8")
	gs._damage_unit(0,0,3,1,0); check(p.units[0].hp == 5 and p.units[0].attack == 5,"wounded awakening immediately updates power")
	gs._heal_unit(p.units[0],2); check(p.units[0].attack == 7,"recovery immediately updates power")
	play(gs,"c18106"); check(p.units[0].maxHp == 14 and p.units[0].attack == 14,"form full recovery updates awakened power")
	gs._knockout_unit(p.units[0]); gs.VerifiedRules.reduce_countdown(gs,0,0,2)
	check(p.units[0].attack == 8 and p.units[0].hp == 8,"natural countdown revival restores awakened hp-dependent power")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	var h := give(gs,"c18104"); var energy: int = p.energy
	check(not gs.can_play_card(0,h,p.units[0].uid).ok and not gs.play_card(0,h,p.units[0].uid) and p.energy == energy,"blessing rejects its source before paying")
	check(gs.play_card(0,h,p.units[1].uid),"bless low-power high-life ally")
	check(p.units[1].attack == 2 and p.units[1].get("treeHealthCombat",false),"blessing retains2 power panel")
	foe.units[0].front = 1; foe.units[0].shield = 1
	check(gs.basic_attack(0,1),"health combat actual attack")
	check(foe.units[0].hp == 2 and p.units[1].hp == 4,"combat uses5health through armor, defender still counters")
	gs._knockout_unit(p.units[1]); check(not p.units[1].get("treeHealthCombat",false),"nonpermanent blessing leaves on knockout")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.units[0].hp = 1; play(gs,"c18104",foe.units[0].uid)
	check(foe.units[0].get("treeHealthCombat",false),"blessing may also target enemy low-health unit")
	var options := {"combo":true}; p.units[2].hp = 4; p.units[2].treeHealthCombat = true; foe.units[0].hp = 6; foe.units[0].front = 1
	gs._resolve_combat(0,2,10,false,false,true,false,null,false,options); gs._resolve_resolution_stack()
	check(foe.units[0].hp == 0,"health replacement ignores printed power and combat bonus")

func curse_disaster_forest() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	var h := give(gs,"c18102")
	check(gs.valid_targets(0,gs.hand_card_def(0,h)).is_empty(),"curse requires a real attached form")
	gs._apply_form(1,0,{"id":"test-form","name":"测试形态","value":{"attack":9,"hp":12,"setBase":true},"formRules":{"combatKeywords":["veil"]},"formHooks":[],"formAbility":"帷幕"})
	check(not gs.can_play_card(0,h,foe.units[0].uid).ok,"enemy veil blocks form curse")
	foe.units[0].formRules = {"combatKeywords":["combo"],"fortuneEntryExitFire":true}; foe.units[0].awakened = true
	var energy: int = p.energy; var enemy_energy: int = foe.energy
	check(gs.play_card(0,h,foe.units[0].uid),"curse actual selected enemy form")
	check(foe.units[0].attack == 1 and foe.units[0].maxHp == 6 and foe.units[0].form.name == "诅咒之木" and foe.units[0].formRules.is_empty(),"curse transforms to real1/6 blank form")
	check(p.energy == energy-1 and foe.energy == enemy_energy,"curse transformation does not invent old form exit rewards")
	check(foe.units[0].awakened and not foe.units[0].get("baseRulesSuppressed",false) and not gs.VerifiedRules.Combat.has(foe.units[0],"combo"),"curse preserves base/awakening but removes old form traits")
	play(gs,"c18101"); play(gs,"c18102",p.units[0].uid)
	check(p.units[0].form.name == "诅咒之木" and not p.units[0].formRules.get("treeRoot",false),"curse also targets own attached form")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18105",foe.units[0].uid)
	check(foe.units[0].hp == 6,"disaster does no immediate damage")
	turn(gs,0); foe.units[0].shield = 2; turn(gs,1)
	check(foe.units[0].hp == 2 and foe.units[0].shield == 0,"disaster uses current6health, self damage honors2 armor")
	check(foe.units[0].treeDisasters.is_empty(),"disaster resolves only once")
	gs = game(); p = gs.player(0)
	play(gs,"c18105",p.units[2].uid); var hp: int = p.units[2].hp
	turn(gs,0); check(p.units[2].hp == hp,"friendly disaster waits for next own turn end")
	turn(gs,1); p.units[2].barrier = true; turn(gs,0)
	check(p.units[2].hp == hp and not p.units[2].barrier,"delayed self damage respects shield at exact next own end")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18105",foe.units[1].uid); gs._knockout_unit(foe.units[1]); check(not foe.units[1].has("treeDisasters"),"disaster grant removed by knockout")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18107"); check(p.realms[0].hp == 20 and p.energy == 29,"forest printed20durability costs1")
	foe.avatarHp = 9; foe.units[0].hp = 5; foe.units[1].hp = 1; foe.units[2].shield = 2
	turn(gs,0)
	check(foe.avatarHp == 5 and foe.units[0].hp == 3 and foe.units[1].hp == 1,"forest hits active avatar/units, floors half and deals0at1health")
	check(p.avatarHp == 30 and p.units[0].hp == 6,"forest does not damage inactive side")
	turn(gs,1); check(p.avatarHp == 15 and p.units[0].hp == 3,"forest triggers on owner's own start too")
	gs = game(); p = gs.player(0); play(gs,"c18107"); p.realms[0].hp = 1
	turn(gs,0); turn(gs,1)
	check(p.realms.is_empty() and p.units[0].hp == 3,"earned forest group finishes after its own avatar damage breaks realm")

func sakura_spells() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(p.units[1].attack == 2 and p.units[1].maxHp == 5,"sakura base2/5")
	gs._knockout_unit(p.units[2]); play(gs,"c18401",p.units[2].uid)
	check(p.units[2].hp == 0 and p.units[2].knockout == 1,"fall heals knocked ally by one countdown, not5")
	play(gs,"c18401",p.units[2].uid)
	check(p.units[2].hp == p.units[2].maxHp and p.units[2].knockout == 0,"second real healing revives at countdown0")
	p.units[0].hp = 1; var before: int = foe.units[0].hp; play(gs,"c18401",foe.units[0].uid)
	check(foe.units[0].hp == before-3 and p.units[0].hp == 1,"fall enemy branch does not also heal ally")
	play(gs,"c18401",p.units[0].uid); check(p.units[0].hp == 6,"fall friendly branch restores5")
	p.avatarHp = 20; play(gs,"c18401","avatar-0"); check(p.avatarHp == 25,"fall can target own avatar")
	play(gs,"c18401","avatar-1"); check(foe.avatarHp == 27,"fall can target enemy avatar")
	gs._knockout_unit(foe.units[0]); var h := give(gs,"c18401")
	check(not gs.can_play_card(0,h,foe.units[0].uid).ok,"unawakened fall excludes dead enemy")
	play(gs,"c18405"); check(p.units[1].attack == 3 and p.units[1].maxHp == 6,"sakura awakening exact1/1")
	check(gs.play_card(0,h,foe.units[0].uid) and foe.units[0].knockout == 3,"awakened fall deals one countdown delay regardless3damage")
	gs._damage_unit(1,0,0,0,1); check(foe.units[0].knockout == 3,"zero damage cannot extend countdown")
	gs._damage_unit(1,0,7,0,0); check(foe.units[0].knockout == 3,"other source cannot borrow sakura dead damage")
	gs = game(); p = gs.player(0); gs._knockout_unit(p.units[0]); p.units[2].hp = 1
	play(gs,"c18403")
	check(p.units[0].hp == 6 and p.units[2].hp == p.units[2].maxHp,"bloom is two distinct3heal groups and revives2countdown")
	check(p.units[2].shield == 0,"healing does not invent old passive armor")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[1].spellPower = 1
	play(gs,"c18401","avatar-1"); check(foe.avatarHp == 26,"fall includes actual extra spell power")
	p.avatarHp = 20; play(gs,"c18401","avatar-0"); check(p.avatarHp == 26,"fall healing includes same spell power")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[1].spellPower = 1
	for target in foe.units: target.hp = 0; target.knockout = 2
	play(gs,"c18406"); check(foe.avatarHp == 16,"all seven cloud damage steps include spell power")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	for u in foe.units: u.hp = 0; u.knockout = 2
	play(gs,"c18406")
	check(foe.avatarHp == 23 and gs.rule_events.filter(func(e):return e.kind=="sakura-cloud-step").size()==7,"cloud total7steps, full allied health forces seven enemy hits")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18405"); p.units[1].spellPower = 1
	play(gs,"c18406")
	check(gs.rule_events.filter(func(e):return e.kind=="sakura-cloud-step").size()==7,"cloud does not become8 when printed repeated7times")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18405")
	foe.units[0].hp = 1; foe.units[1].hp = 3; foe.units[2].hp = 5
	gs._knockout_unit(p.units[0]); p.units[0].knockout = 1; gs._knockout_unit(p.units[2]); p.units[2].knockout = 2; p.units[3].hp = 1
	play(gs,"c18407")
	check(foe.units[0].hp == 0 and foe.units[0].knockout == 3 and foe.units[1].hp == 0 and foe.units[2].hp == 1,"blizzard enemy group repeats once on kill, newly dead target receives awakened delay")
	check(p.units[0].hp == 6 and p.units[2].hp == p.units[2].maxHp and p.units[3].hp == p.units[3].maxHp,"blizzard separate heal repeat follows an actual revival")
	check(foe.avatarHp == 30,"blizzard never damages avatars")
	gs = game(); p = gs.player(0); foe = gs.player(1); gs._knockout_unit(p.units[2]); p.units[2].knockout = 2
	play(gs,"c18407")
	check(p.units[2].hp == 0 and p.units[2].knockout == 1 and foe.units[0].hp == 4,"no kill/no revival does not repeat either blizzard stage")

func dances() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c18402"); check(p.units[1].attack == 2 and p.units[1].maxHp == 6,"spring exact2/6")
	p.units[2].hp = 1; foe.units[0].front = 1
	check(gs.basic_attack(0,2),"ally attack with spring"); check(p.units[2].hp == 0 and p.units[2].knockout == 1,"spring heals actual knocked attacker through base countdown")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18402"); p.units[2].hp = int(p.units[2].maxHp)-3
	check(gs.basic_attack(0,2) and p.units[2].hp == p.units[2].maxHp,"spring heals only actual attacker after attack")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18405"); play(gs,"c18404")
	check(p.units[1].attack == 4 and p.units[1].maxHp == 8 and foe.units[0].hp == 6,"radiant3/7 plus awakening1/1, no entry projectile")
	foe.units[0].hp = 1; p.units[0].front = 1
	gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(foe.units[0].hp == 0 and foe.units[0].knockout == 3,"radiant delayed2damage hits actual dead attacker and adds1countdown")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18404"); foe.units[0].hp = 1; p.units[0].front = 1
	gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(foe.units[0].knockout == 2,"unawakened radiant cannot extend already dead attacker")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18408")
	check(p.units[1].attack == 3 and p.units[1].maxHp == 7 and gs.effective_card_cost(0,Content.card_def("c18408"))==1,"floating exact3/7 at1fire")
	p.energy = 0; var energy: int = p.energy
	check(gs.can_basic_attack(0,1).ok and not gs.basic_attack(0,1),"permanent swift is free but requires real target")
	check(p.energy == energy and not p.attackUsed,"missing floating target rejected before payment/action")
	foe.units[0].front = 1; var own_hp: int = p.units[1].hp
	check(gs.basic_attack(0,1,foe.units[1].uid),"free remote attack actually targets reserve")
	check(foe.units[1].hp == 0 and foe.units[0].hp == 6 and p.units[1].hp == own_hp and p.units[1].front == 0,"conditional combo hits chosen shikigami, remote no counter/move")
	check(p.attackUsed and not gs.can_basic_attack(0,1).ok,"swift still consumes ordinary action")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18408"); foe.units[0].front = 1
	check(gs.basic_attack(0,1,"avatar-1") and foe.avatarHp == 27,"floating bypasses front to avatar with only one strike")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18405"); play(gs,"c18408")
	gs._knockout_unit(foe.units[0]); gs._knockout_unit(p.units[2])
	check(not gs.basic_attack_targets(0,1).has(p.units[1].uid) and gs.basic_attack_targets(0,1).has(foe.units[0].uid),"floating excludes self but includes awakened dead enemy")
	check(gs.basic_attack(0,1,foe.units[0].uid) and foe.units[0].knockout == 4,"two strikes against dead enemy delay twice")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18405"); play(gs,"c18408"); foe.units[0].hp = 1
	check(gs.basic_attack(0,1,foe.units[0].uid) and foe.units[0].knockout == 3,"kill on first hit still delays dead enemy on second hit")
	gs = game(); p = gs.player(0); play(gs,"c18408"); gs._knockout_unit(p.units[2])
	check(gs.basic_attack(0,1,p.units[2].uid) and p.units[2].hp == p.units[2].maxHp,"friendly dead shikigami is healed twice and revives")
	gs = game(); p = gs.player(0); play(gs,"c18408"); p.units[0].hp = 1
	check(gs.basic_attack(0,1,p.units[0].uid) and p.units[0].hp == 6,"friendly living shikigami gets double healing without retaliation")
	gs = game(); p = gs.player(0); play(gs,"c18408"); p.avatarHp = 20
	check(gs.basic_attack(0,1,"avatar-0") and p.avatarHp == 23,"friendly avatar receives one healing strike")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18408"); foe.units[2].formRules = {"combatKeywords":["veil"]}
	check(not gs.basic_attack_targets(0,1).has(foe.units[2].uid),"floating respects enemy veil")
	p.energy = 0; p.units[1].frozen = 1; check(not gs.can_basic_attack(0,1).ok,"frozen floating cannot use swift")

func ai_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	play(gs,"c18408"); gs._knockout_unit(p.units[2]); p.energy = 0
	var attack: Dictionary = AI._best_attack(gs,0)
	check(attack.ok and attack.unit == 1 and gs.basic_attack_targets(0,1).has(attack.target),"AI enumerates legal floating targets at zero fire")
	check(gs.basic_attack(0,attack.unit,attack.target),"AI chosen target executes")
	gs = game(); p = gs.player(0); gs._knockout_unit(p.units[2]); var h := give(gs,"c18401")
	check(AI._score_card(gs,0,gs.hand_card_def(0,h),p.units[2].uid)>0,"AI values actual countdown healing")
	check(AI._score_card(gs,0,Content.card_def("c18105"),p.units[2].uid)<0,"AI does not cast disaster on friendly target")
	var unit_before: Dictionary = p.units[0].duplicate(true)
	var status := preload("res://scripts/ui/battle_status.gd").unit_view(gs,0,0,0)
	check(status.hp == p.units[0].hp and unit_before == p.units[0],"presentation remains read-only")

func ui_rules() -> void:
	root.size = Vector2i(1600,740)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	var b := Battle.new(); b.setup(["renmianshu","yinghuayao","hetong","duyanxiaoseng"],["bingyong","yaodaoji","shantong","bailang"],181184); b._ai_thinking = true
	for side in b.gs.players:
		side.hand.clear(); side.energy = 30; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	root.add_child(b); await create_timer(0.4).timeout
	var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	gs._knockout_unit(p.units[2]); hand(b,["c18401","c18107","c18408"]); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	check(b._pending_target_card == 0 and b._unit_widget(str(p.units[2].uid)).selected,"native fall highlights actual knocked ally")
	await capture("01-fall-knocked-target-original-faces")
	await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
	check(p.units[2].hp == 0 and p.units[2].knockout == 1,"native fall click reduces selected countdown")
	hand(b,["c18408"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	p.energy = 0; b._last_view = {}; b._refresh(); await settled(b)
	await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
	check(b._selected_attacker == 1 and b._unit_widget(str(p.units[2].uid)).selected,"floating native click highlights friendly dead target")
	await capture("02-floating-friendly-attack-targets")
	await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
	check(p.units[2].hp == p.units[2].maxHp and p.attackUsed and p.energy == 0,"native friendly attack heals twice without fire")
	# A separate new action scenario preserves the real per-turn attack limit.
	turn(gs,0); turn(gs,1); p.levelUpUsed = true; p.energy = 0; p.avatarHp = 20; b._last_view = {}; b._refresh(); await settled(b)
	await click(b._unit_widget(str(p.units[1].uid))); await settled(b); await click(b._ally_plate); await settled(b)
	check(p.avatarHp == 23 and p.attackUsed,"native own avatar click performs one recovery strike")
	turn(gs,0); turn(gs,1); p.levelUpUsed = true; p.energy = 30
	hand(b,["c18405"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	gs._knockout_unit(foe.units[0]); foe.units[1].front = 1; b._last_view = {}; b._refresh(); await settled(b)
	await click(b._unit_widget(str(p.units[1].uid))); await settled(b); await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
	check(foe.units[0].knockout == 4 and p.units[1].front == 0,"native awakened attack really delays chosen dead enemy twice")
	await capture("03-floating-dead-enemy-countdown")
	b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	tree_rules(); curse_disaster_forest(); sakura_spells(); dances(); ai_rules()
	await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio()
	await process_frame; await process_frame
	print("TREE_SAKURA checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
