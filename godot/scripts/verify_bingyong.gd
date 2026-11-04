extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Rules := preload("res://scripts/bingyong_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BINGYONG_FAIL ", message)
func fixture(enemy_first: String = "bingyong") -> GS:
	var gs := GS.create(["bingyong", "yingcao", "yimulian", "basalt"], [enemy_first, "yingcao", "yimulian", "basalt"], 10307)
	for owner in 2:
		var p := gs.player(owner)
		p.hand.clear()
		p.deck.clear()
		for i in 60: p.deck.append({"instanceId":"d%d-%d" % [owner,i],"definitionId":"c10301"})
		p.energy = 20
		p.levelUpUsed = true
		for unit in p.units:
			unit.shield = 0
			unit.shieldExpires = 0
			unit.level = 3
			unit.passive_hooks = []
	return gs
func give(gs: GS, owner: int, id: String, enhanced: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId":"bingyong%d" % gs.next_card_id,"definitionId":id,"enhanceCount":enhanced})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, owner: int, id: String, target = null, enhanced: int = 0) -> void:
	check(gs.play_card(owner,give(gs,owner,id,enhanced),target),"legal play "+id)
func _initialize() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	u.shield = 7
	var hp: int = gs.player(1).avatarHp
	play(gs,0,"c10301")
	check(gs.player(1).avatarHp == hp - 8,"dust blade uses all seven actual armor")
	gs = fixture("yaodaoji")
	gs.current_player = 1
	play(gs,1,"c10105")
	gs.player(1).units[0].front = 1
	gs.current_player = 0
	gs.player(0).units[0].shield = 7
	play(gs,0,"c10301")
	var strikes: Array = gs.rule_events.filter(func(entry): return entry.kind == "combat-damage-resolved" and int(entry.player) == 0)
	check(strikes.size() == 1 and strikes[0].card.get("id", "") == "c10301","dust blade keeps card identity when opposing myriad creates separate strikes")
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10302")
	check(u.attack == 1 and u.maxHp == 9,"still mountain sets printed 1/9")
	check(u.front == 1,"still mountain enters battle area")
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10305")
	check(u.attack == 4 and u.maxHp == 7 and u.shield == 2,"forest printed 4/7 plus entry armor two")
	gs._damage_unit(0,0,20,1)
	check(u.hp == 7 and u.shield == 0,"forest caps damage by existing armor")
	# Base ability, armor lifetime, awakening persistence and knockout reset.
	for id in ["c10301","c10302","c10303","c10305","c10306","c10307","c10308","c10309"]:
		check(ContentLoader.card_def(id).get("verifiedRules",false),"verified "+id)
	gs = fixture()
	u = gs.player(0).units[0]
	u.shield = 11
	u.shieldExpires = 11
	gs._begin_turn(0)
	check(u.shield == 2,"unawakened armor expires before baseline two")
	gs._begin_turn(0)
	check(u.shield == 2,"baseline armor does not grow without awakening")
	u.level = 0
	gs._begin_turn(0)
	check(u.shield == 0,"inactive source never gains baseline armor")
	u.level = 3
	gs.player(0).energy = 20
	gs.player(0).levelUpUsed = true
	play(gs,0,"c10307")
	check(u.awakened and u.shield == 3 and u.attack == 1 and u.maxHp == 6,"awakening actual armor with no invented stats")
	gs._begin_turn(0)
	check(u.shield == 5,"awakened source keeps old armor then gains two")
	gs.player(0).energy = 20
	gs.player(0).levelUpUsed = true
	play(gs,0,"c10307")
	check(u.shield == 8,"repeat awakening still grants printed three armor")
	gs._knockout_unit(u)
	check(u.shield == 0 and u.awakened,"knockout loses armor but retains awakening")
	u.knockout = 2
	gs._begin_turn(0)
	check(u.shield == 0,"dead source does not gain armor")
	gs._begin_turn(0)
	check(u.hp == 6 and u.shield == 2,"natural revival restores armor ability")

	# Enhanced cards are separate hand instances; deck and enemy turn do not count.
	gs = fixture()
	u = gs.player(0).units[0]
	u.front = 1
	give(gs,0,"c10303")
	give(gs,0,"c10303",2)
	gs.player(0).deck[-1].definitionId = "c10303"
	gs._begin_turn(0)
	check(gs.player(0).hand[0].enhanceCount == 1 and gs.player(0).hand[1].enhanceCount == 3,"each held crash grows once from its own count")
	var card: Dictionary = gs.hand_card_def(0,0)
	check(card.value == 3 and card.combatOption.shield == 3 and "增强1次" in card.text,"hand view exposes actual enhanced combat stats")
	check(not gs.player(0).hand[2].has("enhanceCount"),"newly drawn crash cannot receive past enhancement")
	check(u.front == 0,"turn start growth resolves before ordinary retreat")
	gs._begin_turn(1)
	check(gs.player(0).hand[0].enhanceCount == 1,"enemy turn cannot enhance own crash")
	gs._begin_turn(0)
	check(gs.player(0).hand[0].enhanceCount == 1,"reserve source cannot enhance crash")
	u.front = 1
	gs._knockout_unit(u)
	u.front = 1
	gs._begin_turn(0)
	check(gs.player(0).hand[0].enhanceCount == 1,"dead source cannot enhance crash")
	gs = fixture()
	u = gs.player(0).units[0]
	var before: int = gs.player(1).avatarHp
	play(gs,0,"c10303",null,3)
	check(gs.player(1).avatarHp == before - 6 and u.shield == 5,"enhanced crash grants actual five armor and five battle-only power")
	check(u.attack == 1,"crash does not permanently add combat power")
	before = gs.player(1).avatarHp
	play(gs,0,"c10301")
	check(gs.player(1).avatarHp == before - 6,"crash armor feeds subsequent dust blade")
	check(u.attack == 1,"dust blade combat power never remains on body")

	# Modern forms replace printed body and keep unrelated increments.
	gs = fixture()
	u = gs.player(0).units[0]
	gs._grow_unit(u,2,1)
	play(gs,0,"c10302")
	check(u.attack == 3 and u.hp == 10 and u.front == 1,"mountain adds existing growth to printed body")
	check(not gs.player(0).attackUsed and gs.player(1).avatarHp == 30,"mountain movement is not an attack")
	gs._begin_turn(0)
	check(u.attack == 6 and u.front == 0,"mountain grows once then retreats normally")
	gs.player(0).levelUpUsed = true
	gs.player(0).energy = 20
	play(gs,0,"c10305")
	check(u.attack == 9 and u.hp == 8,"changing form keeps earlier growth and replaces base stats")
	gs._knockout_unit(u)
	check(u.attack == 3 and u.maxHp == 7,"knockout clears mountain growth and form but keeps unrelated permanent stats")
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10302")
	u.front = 0
	gs._begin_turn(0)
	check(u.attack == 1,"reserve mountain cannot grow")

	# Forest damage cap applies to every damage packet, not a fake armor grant.
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10305")
	gs._damage_unit(0,0,1,1)
	check(u.hp == 7 and u.shield == 1,"small first packet consumes only actual damage")
	gs._damage_unit(0,0,99,1)
	check(u.hp == 7 and u.shield == 0,"last armor absorbs arbitrary next packet")
	gs._damage_unit(0,0,3,1)
	check(u.hp == 4,"no remaining armor means no damage cap")
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10305")
	u.barrier = true
	gs._damage_unit(0,0,99,1)
	check(u.hp == 7 and u.shield == 2 and not u.barrier,"barrier resolves before armor damage cap")
	play(gs,0,"c10309")
	gs._damage_unit(0,0,5,1)
	check(u.hp == 6 and u.shield == 0,"form replacement removes forest cap")

	# Armor and armor break offset on application, before damage-cap eligibility.
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10305")
	gs.VerifiedRules.ArmorBreak.give(gs,1,0,0,0,1)
	check(u.shield == 1 and u.armorBreak == 0,"armor break immediately consumes one of forest's two armor")
	gs._damage_unit(0,0,50,1)
	check(u.hp == 7 and u.shield == 0,"forest retains cap while net armor remains")
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10305")
	gs.VerifiedRules.ArmorBreak.give(gs,1,0,0,0,3)
	check(u.shield == 0 and u.armorBreak == 1,"excess armor break removes forest's armor and persists only its remainder")
	gs._damage_unit(0,0,3,1)
	check(u.hp == 3 and u.armorBreak == 0,"forest loses cap immediately when armor is fully offset")
	gs = fixture()
	u = gs.player(0).units[0]
	gs.VerifiedRules.ArmorBreak.give(gs,1,0,0,0,5)
	play(gs,0,"c10305")
	check(u.shield == 0 and u.armorBreak == 3,"forest entry armor offsets existing armor break")
	play(gs,0,"c10308",u.uid)
	check(u.shield == 2 and u.armorBreak == 0,"shield card removes residual armor break before retaining net armor")
	var net_health: int = gs.player(0).units[3].maxHp
	play(gs,0,"c10306")
	check(gs.player(0).units[3].maxHp == net_health + 2,"wall grants health only from net remaining armor")

	# Ancient wall uses present armor, does not consume it, excludes source/dead.
	gs = fixture()
	u = gs.player(0).units[0]
	u.shield = 7
	u.shieldExpires = 7
	var ally: Dictionary = gs.player(0).units[3]
	var max_before: int = ally.maxHp
	var inactive_max: int = gs.player(0).units[2].maxHp
	ally.hp -= 3
	gs.player(0).units[2].level = 0
	gs._knockout_unit(gs.player(0).units[1])
	play(gs,0,"c10306")
	check(u.attack == 5 and u.maxHp == 10 and u.shield == 7,"wall replaces body without consuming or granting armor")
	check(ally.maxHp == max_before + 7 and ally.hp == max_before + 4,"wall increases current and maximum hp once without healing old injury")
	check(gs.player(0).units[1].maxHp == 5 and gs.player(0).units[1].hp == 0,"wall does not resurrect or grow knocked ally")
	check(gs.player(0).units[2].maxHp == inactive_max + 7,"wall includes living inactive ally")
	play(gs,0,"c10309")
	check(ally.maxHp == max_before + 7,"wall benefit survives source form replacement")
	gs._grow_unit(ally,0,2)
	gs._knockout_unit(ally)
	check(ally.maxHp == max_before + 2,"wall temporary health clears independently from permanent growth")
	gs = fixture()
	max_before = gs.player(0).units[3].maxHp
	play(gs,0,"c10306")
	check(gs.player(0).units[3].maxHp == max_before,"zero armor wall grants zero health")

	# Source-attacked automatic shield, legal targets and resource gates.
	gs = fixture()
	u = gs.player(0).units[0]
	play(gs,0,"c10308",gs.player(0).units[3].uid)
	check(gs.player(0).units[3].shield == 5 and u.shield == 0,"manual shield affects only selected living ally")
	var h := give(gs,0,"c10308")
	check(not gs.can_play_card(0,h,gs.player(1).units[0].uid).ok,"shield rejects enemy target")
	gs._knockout_unit(gs.player(0).units[3])
	check(not gs.can_play_card(0,h,gs.player(0).units[3].uid).ok,"shield rejects dead ally")
	for gate in ["allowed","no-fire","stunned","inactive","different-target"]:
		gs = fixture()
		gs.current_player = 1
		gs.player(1).units[3].attack = 3
		u = gs.player(0).units[0]
		u.front = 1
		gs.player(0).energy = 1
		give(gs,0,"c10308")
		if gate == "no-fire": gs.player(0).energy = 0
		if gate == "stunned": u.frozen = 1
		if gate == "inactive": u.level = 0
		if gate == "different-target":
			u.front = 0
			gs.player(0).units[3].front = 1
		check(gs.basic_attack(1,3),"opponent legal attack "+gate)
		check(gs.player(0).hand.size() == (0 if gate == "allowed" else 1),"response gate "+gate)
		if gate == "allowed": check(u.hp == 6 and u.shield == 2 and gs.player(0).energy == 0,"shield resolves before original damage and pays one fire")

	# Dust-bind prevents replacing occupied enemy front, never an empty front.
	gs = fixture()
	gs.current_player = 1
	play(gs,1,"c10309")
	gs.player(1).units[0].front = 1
	gs.current_player = 0
	gs.player(0).units[3].front = 1
	u = gs.player(0).units[0]
	var energy_before: int = gs.player(0).energy
	check(not gs.can_basic_attack(0,0).ok,"dust bind forbids ordinary replacement attack")
	check(not gs.basic_attack(0,0) and gs.player(0).energy == energy_before,"illegal replacement spends no resources")
	h = give(gs,0,"c10301")
	check(not gs.can_play_card(0,h).ok,"dust bind forbids combat-card replacement")
	check(not AI._best_card(gs,0).ok,"AI rejects its only combat card when dust bind forbids replacement")
	check(gs.can_basic_attack(0,3).ok,"existing front may attack under dust bind")
	play(gs,0,"c10302")
	check(u.maxHp == 9 and u.front == 0 and gs.player(0).units[3].front == 1,"mountain form installs while prohibited entry leaves existing front unchanged")
	gs.player(0).units[3].front = 0
	check(gs.can_basic_attack(0,0).ok,"empty front may accept incoming attacker")
	gs.player(0).units[3].front = 1
	gs.player(1).units[0].front = 0
	check(gs.can_basic_attack(0,0).ok,"reserve dust binder exerts no lock")
	gs.player(1).units[0].front = 1
	gs._knockout_unit(gs.player(1).units[0])
	check(gs.can_basic_attack(0,0).ok,"dead dust binder exerts no lock")
	gs = fixture()
	gs.current_player = 1
	play(gs,1,"c10309")
	gs.player(1).units[0].front = 1
	gs.current_player = 0
	u = gs.player(0).units[0]
	u.front = 1
	play(gs,0,"c10301")
	check(gs.player(1).units[0].hp == 8 and u.hp == 1 and u.front == 1,"existing front can actually resolve combat card under dust bind")
	gs = fixture()
	give(gs,0,"c10303",2)
	var ai: Dictionary = AI._best_card(gs,0)
	check(ai.ok and gs.can_play_card(0,int(ai.hand),ai.target).ok,"AI returns legal action with enhanced combat card")
	print("BINGYONG_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
