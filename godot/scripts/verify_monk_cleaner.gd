extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Shell := preload("res://scripts/monk_cleaner_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MONK_CLEANER_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(["duyanxiaoseng","gouchang","hetong","baimugui"],["bingyong","yaodaoji","shantong","bailang"],188211)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"monk-cleaner-%d" % gs.next_card_id}); gs.next_card_id += 1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play " + id)

func finish(gs) -> void:
	for i in 100:
		if gs.winner >= 0 or (gs.pending_choice.is_empty() and gs.response_window.is_empty()): return
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs,gs.action_player()),"AI completes actual pending choice")
		else: check(gs.pass_response(gs.action_player()),"pass actual response window")
	check(false,"choice continuation terminates")

func monk_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(p.units[0].attack == 0 and p.units[0].maxHp == 6 and p.units[1].attack == 3 and p.units[1].maxHp == 4,"source base bodies0/6 and3/4")
	p.units[0].front = 1; gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(p.units[0].hp == 5 and foe.units[0].hp == 4 and p.units[0].monkDamageTotal == 1,"enemy combat damage triggers actual2 projectile")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	gs._damage_unit(0,0,2,1,0); gs._resolve_resolution_stack()
	check(p.units[0].hp == 4 and foe.units[0].hp == 6 and not p.units[0].get("enraged",false),"noncombat hurt records damage but does not invent reflection")
	p.units[0].shield = 2; p.units[0].front = 1
	gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(p.units[0].monkDamageTotal == 2 and foe.units[0].hp == 6,"fully absorbed combat cannot trigger monk")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[0].hp = 1; p.units[0].front = 1
	gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(p.units[0].hp == 0 and foe.units[0].hp == 4,"lethal combat still resolves earned projectile after knockout")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18805"); check(p.units[0].attack == 2 and p.units[0].maxHp == 7,"monk awakening exact2/1")
	foe.units[0].hp = 2; foe.units[0].front = 1
	check(gs.basic_attack(0,0),"awakened monk actual attack")
	check(foe.units[0].hp == 0 and foe.avatarHp == 27,"monk's own combat kill permits awakened3 projectile to avatar")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18802"); p.units[0].hp = 1
	check(gs.end_turn(0) and p.units[0].hp == 7,"heart sutra sets0/7 and fully heals at owner end")
	p.units[0].hp = 2
	check(gs.end_turn(1) and p.units[0].hp == 7,"heart sutra also heals at enemy end")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18804"); p.avatarArmor = 4
	gs._resolve_combat(1,0,2,false,false,false,false); gs._resolve_resolution_stack()
	check(p.avatarHp == 30 and p.avatarArmor == 4 and p.units[0].hp == 6 and foe.units[0].hp == 4,"diamond redirects actual3 combat before avatar armor then reduces1 and projects2")
	gs._damage_avatar(0,3,1,0)
	check(p.avatarArmor == 1 and p.units[0].hp == 6,"diamond does not redirect noncombat avatar damage")
	var hp: int = p.units[2].hp; gs._damage_unit(0,2,1,1,0)
	check(p.units[2].hp == hp-1 and p.units[0].hp == 6,"diamond only protects avatar combat, not other allies")
	gs._damage_unit(0,0,1,1,0)
	check(p.units[0].hp == 6,"diamond reduction applies to incoming noncombat too")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18807"); p.units[2].barrier = true; p.units[2].shield = 9; hp = p.units[2].hp
	gs._damage_unit(0,2,3,1,0)
	check(p.units[2].hp == hp and p.units[2].barrier and p.units[2].shield == 9 and p.units[0].hp == 9,"all-cover substitutes damage before protected ally barrier and armor")
	gs._damage_avatar(0,2,1,0)
	check(p.avatarHp == 30 and p.units[0].hp == 7,"all-cover protects avatar noncombat as well")
	gs._damage_unit(0,0,20,1,0)
	check(p.units[0].hp == 1 and not p.units[0].monkFormUnyielding,"form unyielding saves once and is consumed")
	gs._damage_unit(0,0,1,1,0)
	check(p.units[0].hp == 0 and not p.units[0].get("formRules",{}).has("monkCover"),"one-health monk dies and loses cover")
	gs._damage_unit(0,2,1,1,0)
	check(not p.units[2].barrier and p.units[2].hp == hp,"original ally barrier works after covering monk is gone")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18807"); p.units[2].front = 1; p.units[2].hp = 1
	gs._resolve_combat(1,2,7,true,false,false,false); gs._resolve_resolution_stack()
	check(p.avatarHp == 30 and p.units[2].hp == 1 and p.units[0].hp == 2,"covered combat receives whole packet without false overflow at original1hp target")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	p.units[0].monkDamageTotal = 19
	var h := give(gs,"c18808"); check(gs.hand_card_def(0,h).formRules.monkNoncombatBonus == 2,"fury below20 keeps printed2 boost")
	gs._damage_unit(0,0,1,1,0)
	check(gs.hand_card_def(0,h).formRules.monkNoncombatBonus == 6,"actual20th damage enhances held fury to6")
	check(gs.play_card(0,h) and p.units[0].attack == 6 and p.units[0].maxHp == 10,"fury sets6/10 at1 fire")
	foe.units[0].front = 1; foe.units[0].hp = 2
	gs._damage_unit(1,0,1,0,0)
	check(foe.units[0].hp == 0 and foe.avatarHp == 25,"enhanced noncombat1 becomes7 and pierces excess5 exactly once")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18808"); p.units[0].monkDamageTotal = 30; foe.units[0].front = 1
	gs._damage_unit(1,0,1,0,0)
	check(foe.units[0].hp == 3,"already installed unenhanced fury does not acquire held-card enhancement later")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18808"); foe.units[0].hp = 1; foe.units[0].barrier = true
	gs._damage_unit(1,0,2,0,0)
	check(foe.units[0].hp == 1 and not foe.units[0].barrier and foe.avatarHp == 27,"noncombat pierce overflow is independent of the unit barrier")

func enrage_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c18803",p.units[2].uid)
	check(p.units[2].get("enraged",false) and gs.can_basic_attack(0,2).ok and not gs.can_basic_attack(0,1).ok,"stone can legally enrage friendly unit and constrain basic attacker")
	var energy: int = p.energy
	check(not gs.basic_attack(0,1) and p.energy == energy,"illegal non-enraged attacker rejected before payment")
	p.units[2].frozen = 1
	check(gs.can_basic_attack(0,1).ok,"frozen enraged unit does not constrain usable attackers")
	p.units[2].frozen = 0; check(gs.basic_attack(0,2) and not p.units[2].get("enraged",false),"actual attack consumes enrage")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.units[0].front = 1; play(gs,"c18806")
	check(foe.units[0].get("enraged",false),"statue actual combat and reflection enrage damaged enemy this turn")
	gs._damage_unit(1,1,1,0,0)
	check(foe.units[1].get("enraged",false),"statue covers later actual monk damage in same turn")
	Shell.expire_turn(gs); foe.units[1].erase("enraged"); gs._damage_unit(1,1,1,0,0)
	check(not foe.units[1].get("enraged",false),"statue damage-enrage grant expires at turn end")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.units[1].hp = 6; foe.units[1].maxHp = 6; foe.units[1].baseMaxHp = 6
	var original_energy: int = foe.energy; var original_action: bool = foe.attackUsed
	play(gs,"c18801",foe.units[1].uid)
	check(p.units[0].front == 1 and foe.units[1].front == 1 and p.units[0].hp < 6 and foe.units[1].hp == 4,"alms moves monk and selected reserve actually attacks, then receives projectile")
	check(foe.energy == original_energy and foe.attackUsed == original_action and p.energy == 30,"forced attack consumes neither opponent fire nor ordinary action; alms uses shared instant")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.units[0].formRules = {"combatKeywords":["veil"]}
	var h := give(gs,"c18801")
	check(not gs.can_play_card(0,h,foe.units[0].uid).ok and not gs.can_play_card(0,h,p.units[0].uid).ok,"alms excludes veil and friendly targets")
	for i in [0,2,3]: p.units[i].frozen = 1
	Shell.enrage(gs,0,1)
	var attack: Dictionary = AI._best_attack(gs,0)
	check(attack.ok and attack.unit == 1,"AI chooses legal enraged attacker")
	gs = game(); p = gs.player(0); p.energy = 0; Shell.enrage(gs,0,0); p.units[1].swift = true
	check(gs.can_basic_attack(0,1).ok,"enraged unit unable to pay for basic attack does not block another swift unit")

func cleaner_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	gs._damage_unit(0,1,3,1,0)
	check(p.units[1].hp == 1 and p.units[1].shield == 3,"cleaner gains full actual3 armor after nonlethal hit")
	gs._damage_unit(0,1,2,1,0)
	check(p.units[1].hp == 1 and p.units[1].shield == 1,"fully absorbed hit does not generate new armor")
	gs = game(); p = gs.player(0); play(gs,"c21106")
	check(p.units[1].attack == 4 and p.units[1].maxHp == 4 and p.units[1].unyielding,"cleaner awakening exact1/0 and actual unyielding")
	gs._damage_unit(0,1,9,1,0)
	check(p.units[1].hp == 1 and p.units[1].shield == 9 and not p.units[1].unyielding,"unyielding prevention still earns full9 armor rather than only3 lostHP")
	gs = game(); p = gs.player(0); var h := give(gs,"c21101")
	check(not gs._kw(gs.hand_card_def(0,h),"instant"),"bubble not instant without armor")
	check(gs.play_card(0,h) and p.units[1].shield == 0 and p.energy == 29,"bubble grants attack1 without invented armor")
	gs = game(); p = gs.player(0); gs._grant_unit_armor(p.units[1],1); h = give(gs,"c21101")
	check(gs._kw(gs.hand_card_def(0,h),"instant") and gs.play_card(0,h) and p.energy == 30,"armored bubble is actual shared instant")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c21102")
	check(p.hand.size() == 1 and p.avatarArmor == 1 and foe.avatarArmor == 1 and p.units.all(func(u):return u.shield == 1) and foe.units.all(func(u):return u.shield == 1),"shine gives every living character and both avatars armor1 then draws1")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	h = give(gs,"c21103"); var card: Dictionary = gs.hand_card_def(0,h)
	check(card.combatOption.pursuit and not card.combatOption.get("lethal",false) and gs.valid_targets(0,card).has(foe.units[2].uid),"bath is real reserve pursuit without false lethal at zero armor")
	gs._grant_unit_armor(p.units[1],1); foe.units[2].baseMaxHp = 40; foe.units[2].hp = 40; foe.units[2].maxHp = 40
	check(gs.hand_card_def(0,h).combatOption.lethal and gs.play_card(0,h,foe.units[2].uid) and foe.units[2].hp == 0,"armored pursuit really kills selected40hp reserve after actual damage")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	gs._grant_unit_armor(p.units[1],1); foe.units[2].barrier = true
	play(gs,"c21103",foe.units[2].uid)
	check(foe.units[2].hp > 0 and not foe.units[2].barrier,"barrier prevents lethal because no actual damage")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c21104"); gs._grant_unit_armor(p.units[1],7)
	check(p.units[1].attack == 4 and p.units[1].maxHp == 8 and gs.VerifiedRules.Combat.has(p.units[1],"pierce"),"research sets4/8 with actual combat pierce")
	check(gs.end_turn(0) and p.units[1].shield == 2 and foe.avatarHp == 25,"owner end removes max5 real armor and projects exact5")
	var avatar_hp: int = foe.avatarHp
	check(gs.end_turn(1) and p.units[1].shield == 0 and foe.avatarHp == avatar_hp-2,"enemy end also projects remaining armor2")
	gs = game(); p = gs.player(0); play(gs,"c21105")
	check(p.units[1].attack == 3 and not gs.VerifiedRules.Combat.has(p.units[1],"veil"),"bath aura does nothing without armor")
	p.units[2].level = 0; var base_power: int = p.units[2].attack
	gs._grant_unit_armor(p.units[2],1)
	check(p.units[2].attack == base_power+1 and gs.VerifiedRules.Combat.has(p.units[2],"veil"),"bath also protects armored unactivated shikigami without adding an activation condition")
	p.units[2].summoned = true; p.units[2].countsAsShikigami = false; Shell.refresh(gs)
	check(p.units[2].attack == base_power and not gs.VerifiedRules.Combat.has(p.units[2],"veil"),"bath does not silently extend shikigami scope to non-shikigami summons")
	p.units[2].erase("summoned"); p.units[2].erase("countsAsShikigami"); p.units[2].level = 3; Shell.refresh(gs)
	gs._grant_unit_armor(p.units[1],1)
	check(p.units[1].attack == 4 and gs.VerifiedRules.Combat.has(p.units[1],"veil"),"bath instantly grants1 power and veil to armored unit")
	gs._damage_unit(0,1,1,1,0)
	check(p.units[1].attack == 3 and not gs.VerifiedRules.Combat.has(p.units[1],"veil"),"last armor loss immediately removes both aura benefits")
	gs._grant_unit_armor(p.units[2],2); var power: int = p.units[2].attack
	gs._damage_avatar(0,8,1,0)
	check(p.realms.is_empty() and p.units[2].attack == power-1 and not gs.VerifiedRules.Combat.has(p.units[2],"veil"),"bath durability destruction immediately removes team aura")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	p.avatarArmor = 3; p.units[0].shield = 1; p.units[1].shield = 3; p.units[3].shield = 2
	h = give(gs,"c21107"); check(gs.hand_card_def(0,h).currentCardStats == "当前攻击加成 +7","basket preview counts actual capped2 from each ally including avatar")
	check(gs.play_card(0,h) and foe.avatarHp == 20 and p.avatarArmor == 1 and p.units[1].shield == 1 and p.units[0].shield == 0 and p.units[3].shield == 0,"basket consumes exact7 armor before real3+7 attack")
	check(p.units[1].attack == 3,"basket bonus lasts only that attack")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[1].front = 1
	give(gs,"c21108")
	gs._resolve_combat(1,0,2,false,false,true,false); gs._resolve_resolution_stack(); finish(gs)
	check(p.units[1].form.get("cardId") == "c21108" and foe.units[0].hp == 0 and p.units[1].hp == 5,"earned armor auto-installs snow between combo exchanges before the next retaliation")

func snow_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	var h := give(gs,"c21108"); var iid := str(p.hand[h].instanceId); p.hand[h].testMarker = "preserved"
	p.energy = 0; gs._grant_unit_armor(p.units[1],1); gs._resolve_resolution_stack(); finish(gs)
	check(p.hand.is_empty() and p.units[1].attack == 6 and p.units[1].maxHp == 5 and p.energy == 0,"actual held snow auto-uses for free on acquired armor and sets6/5")
	gs._knockout_unit(p.units[1])
	check(p.units[1].hp == 4 and p.units[1].knockout == 0 and p.units[1].formRules.is_empty() and p.hand.size() == 1,"snow death really revives underlying3/4 body and returns original form")
	check(p.hand[0].instanceId == iid and p.hand[0].testMarker == "preserved" and gs.hand_card_def(0,0).value.attack == 8,"returned original identity retains metadata and permanent2 card power")
	gs._grant_unit_armor(p.units[1],1); gs._resolve_resolution_stack(); finish(gs)
	check(p.units[1].attack == 8 and p.units[1].maxHp == 5 and p.hand.is_empty(),"new actual armor event auto-uses enhanced8/5")
	gs._knockout_unit(p.units[1])
	check(gs.hand_card_def(0,0).value.attack == 10,"same returned instance permanently accumulates another2")
	gs = game(); p = gs.player(0); p.units[1].level = 2; give(gs,"c21108")
	gs._grant_unit_armor(p.units[1],1); gs._resolve_resolution_stack()
	check(p.hand.size() == 1 and p.units[1].form.is_empty(),"snow auto-use respects printed3勾")
	p.units[1].level = 3; p.units[1].frozen = 1
	gs._grant_unit_armor(p.units[1],1); gs._resolve_resolution_stack()
	check(p.hand.size() == 1,"snow cannot auto-use while frozen")
	p.units[1].frozen = 0; play(gs,"c21104")
	gs._grant_unit_armor(p.units[1],1); gs._resolve_resolution_stack()
	check(p.hand.size() == 1 and p.units[1].form.cardId == "c21104","snow does not overwrite an installed form")
	gs = game(); p = gs.player(0); give(gs,"c21108"); p.units[1].armorBreak = 2
	gs._grant_unit_armor(p.units[1],2); gs._resolve_resolution_stack()
	check(p.hand.size() == 1 and p.units[1].shield == 0,"armor entirely cancelled by armor break is not acquired armor event")
	gs = game(); p = gs.player(0); give(gs,"c21108"); p.units[1].baseRulesSuppressed = true
	gs._grant_unit_armor(p.units[1],1); gs._resolve_resolution_stack()
	check(p.hand.size() == 1 and p.units[1].form.is_empty(),"transformed cleaner cannot auto-use original snow")
	gs = game(); p = gs.player(0); play(gs,"c21108")
	for i in 12: give(gs,"c18803")
	gs._knockout_unit(p.units[1])
	check(p.units[1].hp == 4 and p.hand.size() == 12 and not p.hand.any(func(i):return i.definitionId == "c21108"),"full-hand burn does not cancel snow's actual resurrection")
	gs = game(); p = gs.player(0); var foe: Dictionary = gs.player(1)
	foe.units[0].hp = 2; p.units[0].front = 1
	gs._resolve_combat(0,1,0,false,false,false,false)
	check(gs._shell_reaction_stack.is_empty() and not gs._shell_in_exchange,"combat reactions clean up exchange context")

func cross_rules() -> void:
	var gs := GS.create(["gouchang","hetong","baimugui","xieji"],["duyanxiaoseng","yaodaoji","shantong","bailang"],211188)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
	var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	foe.units[0].attackBonus = 1; gs._recalc(foe.units[0]); foe.units[0].front = 1
	p.units[0].hp = 3
	gs._resolve_combat(0,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(p.units[0].hp == 0 and p.units[0].shield == 0,"monk projection resolves before cleaner can receive combat-earned armor")
	check(gs._shell_reactions.is_empty() and gs._shell_reaction_stack.is_empty(),"cross-character reactions leave no hidden pending batch")
	gs = GS.create(["duyanxiaoseng","qingfangzhu","gouchang","hetong"],["bingyong","yaodaoji","shantong","bailang"],188125)
	for side in gs.players:
		side.hand.clear(); side.energy = 0; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	p = gs.player(0); gs._install_form(0,0,Content.card_def("c18807")); give(gs,"c12507"); gs.current_player = 1; p.avatarHp = 1
	gs.VerifiedRules.Combat.strike(gs,1,0,0,-1,5,{})
	check(p.avatarHp == 1 and p.units[0].hp == 12 and p.units[1].hp == 0,"avatar lethal-response protection resolves before monk cover rather than bypassing舍生")
	gs = game(); p = gs.player(0); var snapshot := JSON.stringify(gs.snapshot())
	gs.hand_card_def(0,give(gs,"c18808")); snapshot = JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0)
	check(JSON.stringify(gs.snapshot()) == snapshot,"dynamic damage-history preview never mutates state")

func ui_rules() -> void:
	root.size = Vector2i(1600,740)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	var b := Battle.new(); b.setup(["duyanxiaoseng","gouchang","hetong","baimugui"],["bingyong","yaodaoji","shantong","bailang"],188211); b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
	root.add_child(b); await create_timer(0.4).timeout
	var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	foe.units[1].baseMaxHp = 6; foe.units[1].hp = 6; foe.units[1].maxHp = 6
	hand(b,["c18801"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b._pending_target_card == 0 and b._unit_widget(str(foe.units[1].uid)).selected,"native original alms enters selected enemy mode")
	await capture("01-alms-forced-combat-target")
	await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
	check(p.units[0].front == 1 and foe.units[1].front == 1 and foe.units[1].hp == 4,"native chosen reserve really attacks monk and receives projectile")
	gs._grant_unit_armor(p.units[1],1); foe.units[2].hp = 40; foe.units[2].baseMaxHp = 40; foe.units[2].maxHp = 40
	hand(b,["c21103"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b._pending_target_card == 0 and b._unit_widget(str(foe.units[2].uid)).selected,"native enhanced bath highlights actual reserve target")
	await capture("02-cleaner-pursuit-lethal")
	await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
	check(foe.units[2].hp == 0,"native pursuit actually kills selected40hp reserve")
	gs._knockout_unit(p.units[1]); p.units[1].knockout = 0; p.units[1].hp = p.units[1].maxHp
	hand(b,["c21108","c21102"]); p.energy = 0; gs.kw_usage(0,"instant").used = false; b._last_view = {}; b._refresh(); await settled(b)
	await click(b._hand_row.get_child(1)); await settled(b)
	check(p.units[1].form.get("cardId") == "c21108" and p.units[1].attack == 6 and p.energy == 0,"native shine triggers held snow automatically without added fire")
	gs._knockout_unit(p.units[1]); b._last_view = {}; b._refresh(); await settled(b)
	check(p.hand.any(func(i):return i.definitionId == "c21108") and p.units[1].hp == 4,"native view reflects actual snow resurrection and card return")
	var view: Dictionary = gs.hand_card_def(0,p.hand.find_custom(func(i):return i.definitionId == "c21108"))
	check(view.currentCardStats == "当前面板 8/5","returned original snow face displays accumulated8/5")
	await capture("03-snow-return-original-face")
	b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	monk_rules(); enrage_rules(); cleaner_rules(); snow_rules(); cross_rules()
	await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio()
	await process_frame; await process_frame
	print("MONK_CLEANER checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
