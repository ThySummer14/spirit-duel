extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Charms := preload("res://scripts/owl_insect_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("OWL_INSECT_FAIL ",detail)

func game() -> GS:
	var gs := GS.create(["xun","wuguishi","renmianshu","yaodaoji"],["bingyong","shantong","bailang","hetong"],186192)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"owl-insect-%d" % gs.next_card_id}); gs.next_card_id += 1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)

func turn(gs, owner: int) -> void:
	check(gs.end_turn(owner),"actual turn end %d" % owner); gs.player(1-owner).levelUpUsed = true

func attack(gs, owner: int, idx: int, bonus: int = 0) -> void:
	gs._resolve_combat(owner,idx,bonus,false,false,false,false); gs._resolve_resolution_stack()

func guard_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(p.units[0].attack == 2 and p.units[0].maxHp == 4,"owl source exact2/4")
	var deck: int = p.deck.size(); play(gs,"c18602",p.units[2].uid)
	check(Charms.guarded(p.units[2]) and p.units[2].shield == 0 and p.energy == 30 and p.deck.size() == deck-1,"instant guard really attaches then draws without inventing armor")
	gs._damage_unit(0,2,1,1,0); check(p.units[2].hp == 6,"guard reduces each1damage to0")
	gs._damage_unit(0,2,3,1,0); check(p.units[2].hp == 4,"guard reduces3damage to2")
	p.units[2].shield = 2; gs._damage_unit(0,2,4,1,0,false,-1,false,true)
	check(p.units[2].hp == 1 and p.units[2].shield == 0,"armor then critical then guard yields3damage")
	var energy: int = p.energy; play(gs,"c18602",p.units[3].uid)
	check(not Charms.guarded(p.units[2]) and Charms.guarded(p.units[3]) and p.energy == energy-1,"second guard moves unique attachment and shared instant is spent")
	gs._knockout_unit(p.units[0]); gs._damage_unit(0,3,1,1,0)
	check(Charms.guarded(p.units[3]) and p.units[3].hp == 4,"guard persists and still reduces after owl source knockout")
	gs._knockout_unit(p.units[3]); check(not Charms.guarded(p.units[3]),"target knockout clears guard")
	gs = game(); p = gs.player(0)
	turn(gs,0); check(not p.units.any(func(u):return Charms.guarded(u)),"no own attack means no base guard")
	gs = game(); p = gs.player(0); attack(gs,0,2); attack(gs,0,3); turn(gs,0)
	check(Charms.guarded(p.units[3]) and not Charms.guarded(p.units[2]),"base guards actual last attacker, not source or first attacker")
	gs = game(); p = gs.player(0); attack(gs,0,2); attack(gs,0,3); gs._knockout_unit(p.units[3]); turn(gs,0)
	check(not p.units.any(func(u):return Charms.guarded(u)),"dead last attacker does not fall back to earlier living attacker")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18606"); foe.units[0].front = 1
	check(p.units[0].attack == 3 and p.units[0].maxHp == 5,"owl awakening exact1/1")
	check(gs.basic_attack(0,3) and Charms.guarded(p.units[3]) and p.units[3].hp == 4,"awakened guard is attached before enemy counter damage")
	turn(gs,0); check(Charms.guarded(p.units[3]),"awakened guard persists across turn")
	gs = game(); p = gs.player(0); attack(gs,0,3); play(gs,"c18606"); turn(gs,0)
	check(not Charms.guarded(p.units[3]),"awakening after attack removes old end trigger and does not attach retroactively")
	gs = game(); p = gs.player(0); p.units[0].level = 0; attack(gs,0,3); turn(gs,0)
	check(not Charms.guarded(p.units[3]),"inactive source cannot trigger base guard")
	gs = game(); p = gs.player(0); play(gs,"c18607")
	check(p.get("owlAll",false) and p.energy == 29 and not p.units.any(func(u):return Charms.guarded(u)),"wings costs1 and changes future attachments without inventing immediate guards")
	play(gs,"c18602",p.units[2].uid)
	check(p.units.all(func(u):return Charms.guarded(u)),"wings expands actual next attachment to all friendly shikigami")
	Charms.attach_guard(gs,0,0,2); var hp: int = p.units[2].hp; gs._damage_unit(0,2,2,1,0)
	check(p.units[2].hp == hp-1,"repeated all-guard does not stack damage reduction")

func forms_and_interference() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c18602",p.units[2].uid); play(gs,"c18601")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 6 and p.units[2].attack == 3,"claw3/6 grants2 only to guarded ally")
	play(gs,"c18605")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5 and p.units[2].attack == 1 and gs.VerifiedRules.Combat.has(p.units[2],"veil"),"veil4/5 replaces power aura and grants real veil")
	check(not gs.valid_targets(1,Content.card_def("c19201")).has(p.units[2].uid),"enemy targeted spell cannot choose owl veil")
	play(gs,"c18602",p.units[3].uid)
	check(not gs.VerifiedRules.Combat.has(p.units[2],"veil") and gs.VerifiedRules.Combat.has(p.units[3],"veil"),"veil follows unique guard immediately")
	gs._knockout_unit(p.units[0]); check(not gs.VerifiedRules.Combat.has(p.units[3],"veil") and Charms.guarded(p.units[3]),"aura ends on source knockout, charm remains")
	gs = game(); p = gs.player(0); play(gs,"c18603"); play(gs,"c18602",p.units[3].uid)
	turn(gs,0); check(p.units[3].maxHp == 4,"resolve does not grow at enemy start")
	turn(gs,1); check(p.units[3].maxHp == 5 and p.units[3].hp == 5 and p.units[0].maxHp == 4,"own start grows guarded unit health only")
	gs._knockout_unit(p.units[3]); check(p.units[3].maxHp == 4,"ordinary resolve health gain clears on knockout")
	gs = game(); p = gs.player(0); var h := give(gs,"c18608")
	check(not gs.can_play_card(0,h,null).ok,"protection form requires real attachment target")
	check(gs.play_card(0,h,p.units[3].uid) and p.units[0].attack == 5 and p.units[0].maxHp == 8 and p.units[3].get("owlUnyielding",false),"protection5/8 installs and grants target unyielding")
	gs._damage_unit(0,3,100,1,0); Charms.refresh(gs)
	check(p.units[3].hp == 1 and not p.units[3].get("owlUnyielding",false),"unyielding saves once and refresh does not regenerate it")
	play(gs,"c18602",p.units[3].uid); check(p.units[3].get("owlUnyielding",false),"real fresh guard attachment can grant a new unyielding")
	gs._damage_unit(0,3,2,1,0); check(p.units[3].hp == 0,"1health unyielding cannot prevent death")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18602",p.units[2].uid); foe.units[0].barrier = true; play(gs,"c18604",foe.units[0].uid)
	check(not foe.units[0].barrier and foe.units[0].frozen == 0,"interference is not stun and real1damage consumes barrier")
	var hp: int = p.units[2].hp; gs._damage_unit(0,2,8,1,0)
	check(p.units[2].hp == hp,"interference blocks guarded damage despite spell hit being absorbed")
	hp = p.units[3].hp; gs._damage_unit(0,3,1,1,0)
	check(p.units[3].hp == hp-1,"interference does not stop damage to unguarded ally")
	turn(gs,0); hp = p.units[2].hp; gs._damage_unit(0,2,2,1,0)
	check(p.units[2].hp == hp-1,"interference expires at actual turn boundary")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18602",p.units[2].uid); p.units[2].front = 1
	give(gs,"c18604"); turn(gs,0); p.energy = 1; foe.units[0].shield = 1
	hp = p.units[2].hp; var before: int = foe.units[0].hp
	check(gs.basic_attack(1,0),"enemy really attacks guard to trigger response")
	check(not p.hand.any(func(i):return i.definitionId=="c18604") and p.energy == 0,"automatic interference consumes real hand card and1fire")
	check(int(foe.units[0].get("owlBlockedTurn",-1)) == gs.turn_counter and foe.units[0].frozen == 0 and p.units[2].hp == hp,"response targets attacker, not guarded defender, and prevents its combat damage")
	check(foe.units[0].hp <= before and not gs.resolution_stack.size(),"response continuation finishes actual combat without pending frames")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18602",p.units[2].uid); p.units[2].front = 1; give(gs,"c18604"); turn(gs,0); p.energy = 0
	check(gs.basic_attack(1,0) and p.hand.any(func(i):return i.definitionId=="c18604"),"unaffordable response remains in hand")

func corrosion_and_return() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(p.units[1].attack == 1 and p.units[1].maxHp == 4,"insect source exact1/4")
	foe.units[0].front = 1; attack(gs,0,1)
	check(foe.units[0].hp == 4 and foe.units[0].maxHp == 5 and foe.units[0].attack == 0 and foe.units[0].get("insectCorrosion",0)==1,"base combat1 plus real corrosion-1/-1")
	gs._heal_unit(foe.units[0],20); check(foe.units[0].hp == 5,"healing cannot erase reduced maximum health")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	gs._damage_unit(1,0,1,0,1); check(foe.units[0].get("insectCorrosion",0)==0,"noncombat damage does not trigger base corrosion")
	var h := give(gs,"c19201"); p.hand[h].memo = "preserve-original"; var iid := str(p.hand[h].instanceId)
	check(gs.play_card(0,h,foe.units[0].uid),"real seed use")
	check(p.hand.size()==1 and p.hand[0].instanceId==iid and p.hand[0].memo=="preserve-original" and p.hand[0].insectReturned,"seed returns same instance with metadata exactly once")
	check(foe.units[0].get("insectCorrosion",0)==1 and foe.units[0].maxHp==5 and foe.units[0].hp==4,"seed reduces injured current health as well as max")
	check(gs.play_card(0,0,foe.units[1].uid) and p.hand.is_empty(),"second actual use of same seed does not return")
	check(foe.units[1].get("insectCorrosion",0)==1,"returned seed can choose a different target")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19207")
	check(p.units[1].attack == 2 and p.units[1].maxHp==5,"insect awakening exact1/1")
	play(gs,"c19201",foe.units[0].uid); check(foe.units[0].insectCorrosion==2,"awakened seed attaches one plus one")
	play(gs,"c19203",foe.units[1].uid)
	check(foe.units[1].insectCorrosion==3 and foe.units[0].insectCorrosion==4 and foe.units[2].get("insectCorrosion",0)==0,"breed chosen2+1 and other already-marked1+1, not all enemies")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19201",foe.units[0].uid)
	var charm_count: int = foe.units[0].insectCorrosion
	gs._apply_form(1,0,{"id":"test-corrosion-form","verifiedRules":true,"name":"测试形态","value":{"attack":4,"hp":8,"setBase":true},"formRules":{},"formHooks":[]})
	check(foe.units[0].insectCorrosion==charm_count and foe.units[0].attack==3 and foe.units[0].maxHp==7,"form replacement retains attached corrosion")
	gs._knockout_unit(foe.units[0]); check(not foe.units[0].has("insectCorrosion") and foe.units[0].maxHp==6,"knockout clears corrosion, not permanent underlying stats")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19202"); foe.units[0].hp = 1
	var deck: int = p.deck.size(); play(gs,"c19201",foe.units[0].uid)
	check(foe.units[0].hp==0 and p.deck.size()==deck-1 and p.units[1].attack==1 and p.units[1].maxHp==6,"lethal stat reduction triggers death-draw, exact1/6 form")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19204"); p.avatarHp = 10
	Charms.corrode(gs,0,1,1,0,2); gs._resolve_resolution_stack(); play(gs,"c19205",foe.units[0].uid)
	check(p.avatarHp==14 and p.units[1].attack==3 and p.units[1].maxHp==7,"death-heal reads two pre-clear marks for4avatar health, exact3/7 form")
	var h2 := give(gs,"c19205"); check(not gs.can_play_card(0,h2,foe.units[1].uid).ok,"devour excludes unmarked target before payment")
	Charms.corrode(gs,0,1,0,3,1); check(gs.can_play_card(0,h2,p.units[3].uid).ok,"devour may select a friendly marked shikigami")

func bomb_and_prison() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	for idx in [2,3]: gs._knockout_unit(foe.units[idx])
	foe.units[0].hp = 3; foe.units[1].baseMaxHp=10; foe.units[1].maxHp=10; foe.units[1].hp=10
	play(gs,"c19206",foe.units[0].uid)
	check(foe.units[0].hp==0 and foe.units[1].get("insectCorrosion",0)==3 and foe.units[1].hp==7,"bomb arms before applying3 and transfers all marks on immediate stat knockout")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19206",foe.units[0].uid)
	check(foe.units[0].hp==3 and foe.units[0].insectCorrosion==3,"bomb is actual three attachments, not area damage")
	turn(gs,0); gs._knockout_unit(foe.units[0]); gs._resolve_resolution_stack()
	check(foe.units.slice(1).all(func(u):return int(u.get("insectCorrosion",0))==0),"bomb transfer permission expires after its original turn")
	gs = game(); p = gs.player(0); foe = gs.player(1); Charms.corrode(gs,0,1,1,0,1)
	play(gs,"c19208"); check(p.realms[0].hp==10 and p.energy==29 and foe.units[0].insectCorrosion==2,"prison installs10durability for1 then entry damage is already converted")
	check(foe.units[1].get("insectCorrosion",0)==0,"prison entry only hits already-marked enemies")
	var hp: int = p.units[2].hp; gs._damage_unit(0,2,2,1,0)
	check(p.units[2].hp==hp-2 and p.units[2].insectCorrosion==2 and p.units[2].maxHp==4,"prison converts enemy damage to friendly stat loss")
	var amount: int = foe.avatarHp; gs._damage_avatar(1,2,0,1)
	check(foe.avatarHp==amount-2,"prison leaves avatar damage as real damage")
	gs = game(); p = gs.player(0); play(gs,"c18602",p.units[2].uid); play(gs,"c19208"); p.units[2].shield=2
	gs._damage_unit(0,2,5,1,0,false,-1,false,true)
	check(p.units[2].hp==1 and p.units[2].maxHp==1 and p.units[2].insectCorrosion==5,"prison reads armor-critical-guard result5, not raw5 or total10")
	gs = game(); p = gs.player(0); play(gs,"c19207"); play(gs,"c19208"); p.units[2].shield=1
	gs._damage_unit(0,2,1,1,0)
	check(p.units[2].insectCorrosion==1 and p.units[2].hp==5,"fully absorbed damage still permits prison's awakened zero-plus-one attachment")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19208")
	p.units[0].attackBonus=-2; gs._recalc(p.units[0]); Charms.corrode(gs,0,1,1,0,1)
	turn(gs,0)
	check(p.units[0].hp==0 and foe.units[0].hp==0,"prison end destroys zero-power shikigami on both sides")
	gs = game(); p = gs.player(0); play(gs,"c19208"); gs._damage_avatar(0,10,1,0)
	check(p.realms.is_empty(),"ordinary avatar damage can break prison")
	hp = p.units[2].hp; gs._damage_unit(0,2,1,1,0)
	check(p.units[2].hp==hp-1 and not p.units[2].has("insectCorrosion"),"prison conversion ceases immediately after destruction")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c18602",p.units[2].uid); p.units[2].hp=5; p.units[2].front=1
	gs._resolve_combat(1,0,5,true,false,false,false); gs._resolve_resolution_stack()
	check(p.units[2].hp==0 and p.avatarHp==30,"guard reduces pierce before overflow allocation, no false1health or extra avatar damage")

func boundary_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c19202"); foe.units[0].hp=1
	for i in 11: give(gs,"c19201")
	var h := give(gs,"c19201"); var iid := str(p.hand[h].instanceId)
	check(gs.play_card(0,h,foe.units[0].uid),"seed at full hand resolves real lethal attachment")
	check(p.hand.size()==12 and not p.hand.any(func(i):return str(i.instanceId)==iid),"death draw fills hand before original seed return, so return burns")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19207")
	for idx in [2,3]: gs._knockout_unit(foe.units[idx])
	foe.units[0].hp=4; foe.units[1].baseMaxHp=12; foe.units[1].maxHp=12; foe.units[1].hp=12
	play(gs,"c19206",foe.units[0].uid)
	check(foe.units[1].get("insectCorrosion",0)==4 and foe.units[1].hp==8,"moving four existing marks does not apply awakening a second time")
	gs = game(); p = gs.player(0); play(gs,"c19208"); p.units[2].formRules={"damageCap":1}
	gs._damage_unit(0,2,5,1,0)
	check(p.units[2].insectCorrosion==1 and p.units[2].hp==5,"prison uses capped final damage amount")
	gs = game(); p = gs.player(0); play(gs,"c18602",p.units[2].uid); play(gs,"c18601"); p.units[2].level=0; Charms.refresh(gs)
	check(p.units[2].attack==3 and Charms.guarded(p.units[2]),"guard aura benefits living inactive shikigami")
	play(gs,"c18605"); check(gs.VerifiedRules.Combat.has(p.units[2],"veil"),"guard veil also applies before target activation")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs,"c19207"); p.units[1].hp=1; p.units[1].front=1
	attack(gs,1,0)
	check(p.units[1].hp==0 and foe.units[0].get("insectCorrosion",0)==2 and foe.units[0].hp==2,"earned simultaneous retaliation retains awakened extra attachment after source knockout")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	gs._apply_form(1,0,{"id":"test-native-empty","verifiedRules":true,"name":"无能力形态","value":{"attack":4,"hp":8,"setBase":true},"formRules":{},"formHooks":[]})
	gs._knockout_unit(foe.units[0])
	check(foe.units[0].form.is_empty() and foe.units[0].maxHp==6,"native empty-ability form is removed on knockout without requiring old unit lifecycle metadata")

func ai_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	var h := give(gs,"c18608"); var best: Dictionary = AI._best_card(gs,0)
	check(best.ok and gs.valid_targets(0,gs.hand_card_def(0,h)).has(best.target),"AI chooses real protection form target")
	check(gs.play_card(0,best.hand,best.target),"AI chosen protection target executes")
	check(AI._score_card(gs,0,Content.card_def("c18604"),p.units[2].uid)<0,"AI does not interfere with friendly attacker")
	Charms.corrode(gs,0,1,1,0,1); h=give(gs,"c19205"); best=AI._best_card(gs,0)
	check(best.ok and gs.can_play_card(0,best.hand,best.target).ok,"AI selects legal corrosion-dependent destruction")
	var before: Dictionary = p.units[2].duplicate(true)
	preload("res://scripts/ui/battle_status.gd").unit_view(gs,0,2,0)
	check(before==p.units[2],"status presentation does not mutate charm state")

func ui_rules() -> void:
	root.size = Vector2i(1600,740)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	var b := Battle.new(); b.setup(["xun","wuguishi","renmianshu","yaodaoji"],["bingyong","shantong","bailang","hetong"],186192); b._ai_thinking = true
	for side in b.gs.players:
		side.hand.clear(); side.energy=30; side.levelUpUsed=true
		for unit in side.units: unit.level=3
	root.add_child(b); await create_timer(0.4).timeout
	var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	hand(b,["c18608","c18602","c19208"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b._pending_target_card==0 and b._unit_widget(str(p.units[2].uid)).selected,"native protection form asks for actual friendly target")
	await capture("01-original-protection-target")
	await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
	check(Charms.guarded(p.units[2]) and p.units[2].get("owlUnyielding",false) and p.units[0].maxHp==8,"native chosen guard and source form both resolve")
	foe.units[0].hp=1; hand(b,["c19201"]); var iid := str(p.hand[0].instanceId); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
	check(foe.units[0].hp==0 and p.hand.size()==1 and p.hand[0].instanceId==iid and p.hand[0].insectReturned,"native seed stat knockout and original card return")
	await capture("02-seed-return-corrosion-knockout")
	await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
	check(p.hand.is_empty() and foe.units[1].get("insectCorrosion",0)==1,"native returned seed chooses second target and is then consumed")
	hand(b,["c18604"]); p.units[2].front=1; turn(gs,0); p.energy=1; b._last_view={}; b._refresh(); await settled(b)
	var hp: int = p.units[2].hp
	check(gs.basic_attack(1,1),"real enemy attack triggers native response rendering"); b._last_view={}; b._refresh(); await settled(b)
	check(p.units[2].hp==hp and not p.hand.any(func(i):return i.definitionId=="c18604") and foe.units[1].get("owlBlockedTurn",-1)==gs.turn_counter,"native interference attacks actual enemy and protects chosen guard")
	await capture("03-interference-actual-attacker")
	b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out=OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	guard_rules(); forms_and_interference(); corrosion_and_return(); bomb_and_prison(); boundary_rules(); ai_rules()
	await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio()
	await process_frame; await process_frame
	print("OWL_INSECT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
