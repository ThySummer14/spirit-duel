extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
const Native := preload("res://scripts/poison_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("POISON_PAIR_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["tiaotiaodidi", "qingshe", "qingfangzhu", "zuofutongzi"], ["tiaotiaodidi", "qingshe", "qingfangzhu", "zuofutongzi"], 114115)
	gs.phase = "main"
	for p in gs.players:
		p.hand.clear()
		p.energy = 30
		p.levelUpUsed = true
		p.avatarArmor = 0
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "poison-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "play " + id)
func _initialize() -> void:
	_conversion()
	_jumper()
	_snake_cards()
	_turns()
	_response()
	_legality()
	_fox_bonuses()
	_ai()
	print("POISON_PAIR checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _conversion() -> void:
	var gs := fixture()
	var t: Dictionary = gs.player(1).units[2]
	var hp := int(t.hp)
	gs._damage_unit(1, 2, 3, 0, 1)
	check(t.hp == hp and t.armorBreak == 3, "unmarked snake damage becomes exact armor break")
	gs._damage_unit(1, 2, 1, 0, 1)
	check(t.hp == hp - 4 and t.armorBreak == 0, "marked target receives damage plus consumed armor break")
	gs._damage_avatar(1, 4, 0, 1)
	check(gs.player(1).avatarHp == 30 and gs.player(1).avatarArmorBreak == 4, "conversion includes avatar")
	gs._damage_avatar(1, 1, 0, 1)
	check(gs.player(1).avatarHp == 25 and gs.player(1).avatarArmorBreak == 0, "marked avatar is hit normally")
	gs = fixture()
	t = gs.player(1).units[2]
	t.barrier = true
	t.shield = 2
	t.shieldExpires = 2
	hp = int(t.hp)
	gs._damage_unit(1, 2, 4, 0, 1)
	check(t.hp == hp and t.barrier and t.shield == 0 and t.armorBreak == 2, "conversion applies armor cancellation and leaves barrier")
	gs._damage_unit(1, 2, 1, 0, 1)
	check(t.hp == hp and not t.barrier and t.armorBreak == 2, "real second damage consumes barrier but retains break")
	gs = fixture()
	t = gs.player(1).units[2]
	gs.player(0).units[1].hp = 0
	gs._damage_unit(1, 2, 1, 0, 1)
	check(t.hp == t.maxHp - 1 and t.armorBreak == 0, "inactive snake has no conversion")
	gs = fixture()
	var jumper: Dictionary = gs.player(0).units[0]
	gs._damage_unit(0, 0, 2, 0, 1)
	check(jumper.hp == 9 and jumper.armorBreak == 2, "friendly snake damage also converts")
	check(not gs.rule_events.any(func(e): return e.kind == "jumper-health-growth"), "conversion does not fabricate received damage")
	gs.player(0).avatarHp = 20
	gs.player(0).avatarArmorBreak = 5
	gs._heal_avatar(0, 4)
	check(gs.player(0).avatarHp == 24 and gs.player(0).avatarArmorBreak == 5, "armor break permits monk healing; distinct from toxic poison")
func _jumper() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	gs._damage_unit(0, 0, 3, 1, 2)
	check(u.hp == 6 and u.armorBreak == 3, "jumper gains actual damage value")
	gs._damage_unit(0, 0, 1, 1, 2)
	check(u.hp == 2 and u.armorBreak == 4, "next damage uses prior break and replaces with total event damage")
	gs = fixture()
	u = gs.player(0).units[0]
	u.shield = 4
	gs._damage_unit(0, 0, 3, 1, 2)
	check(u.armorBreak == 0 and u.hp == 9, "fully shielded damage doesn't trigger jumper")
	play(gs, "c11408")
	var hp := int(u.hp)
	var mx := int(u.maxHp)
	gs._damage_unit(0, 0, 2, 1, 2)
	check(u.maxHp == mx + 1 and u.hp == hp and u.armorBreak == 1, "awake grows once by damage event after shield")
	gs = fixture()
	play(gs, "c11402")
	u = gs.player(0).units[0]
	check(u.attack == 3 and u.maxHp == 9, "modern plague body is3/9")
	gs._damage_unit(0, 0, 1, 1, 2, false)
	check(gs.player(1).units[2].armorBreak == 0, "plague excludes spell damage")
	gs._damage_unit(0, 0, 1, 1, 2, true)
	check(gs.player(1).units[2].armorBreak == 3, "plague reacts to real combat damage")
	gs = fixture()
	var foe: Dictionary = gs.player(1).units[2]
	foe.front = 1
	foe.hp = 20
	foe.maxHp = 20
	foe.baseMaxHp = 20
	foe.attack = 1
	gs.player(0).units[0].armorBreak = 4
	play(gs, "c11401")
	check(foe.hp == 12, "punch adds2 self break then transfers6 before2-power combat")
	check(gs.player(0).units[0].hp == 8 and gs.player(0).units[0].armorBreak == 1, "transfer removes original break before incoming counter")
	gs = fixture()
	play(gs, "c11401")
	check(gs.player(1).avatarHp == 28 and gs.player(0).units[0].armorBreak == 2, "punch does not transfer break to avatar")
	gs = fixture()
	gs.player(0).units[0].armorBreak = 6
	play(gs, "c11403")
	check(gs.player(0).units[0].armorBreak == 0, "fountain transfers rather than copies")
	check(gs.player(1).units.all(func(e): return e.armorBreak == 6), "fountain grants all living enemy units exact break")
	check(gs.player(1).avatarArmorBreak == 0, "fountain excludes avatar")
	gs = fixture()
	play(gs, "c11404")
	u = gs.player(0).units[0]
	check(u.attack == 4 and u.maxHp == 16 and u.armorBreak == 2, "2021 swollen body and entry break")
	gs._begin_turn(0)
	check(u.armorBreak == 2, "swollen retains self break at owner start")
	gs = fixture()
	play(gs, "c11405")
	u = gs.player(0).units[0]
	gs._damage_unit(0, 0, 5, 1, 2)
	check(gs.player(1).avatarArmorBreak == 0, "corpse below6 no trigger")
	gs._damage_unit(0, 0, 1, 1, 2)
	check(gs.player(1).avatarArmorBreak == 3, "corpse exact6 triggers after current self break")
	gs = fixture()
	play(gs, "c11405")
	gs._damage_unit(0, 0, 15, 1, 2)
	check(gs.player(0).units[0].hp == 0 and gs.player(1).avatarArmorBreak == 13, "lethal15 triggers both corpse thresholds")
	gs = fixture()
	gs.player(0).units[0].armorBreak = 7
	play(gs, "c11406")
	check(gs.player(1).avatarHp == 21 and gs.player(0).units[0].attack == 2, "stiff uses current7 bonus for one combat only")
func _snake_cards() -> void:
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[2]
	play(gs, "c11501", enemy.uid)
	check(gs.player(0).hand.size() == 1 and enemy.armorBreak == 2, "2020 strike converts two damage and returns even unmarked")
	var identity: String = gs.player(0).hand[0].instanceId
	check(gs.player(0).hand[0].snakeReturned, "returned instance loses ability")
	check(gs.hand_card_def(0, 0).value == 2 and not gs.hand_card_def(0, 0).snakeReturns, "returned face retains2 damage and shows no second return")
	check(gs.play_card(0, 0, enemy.uid), "returned strike can be used again")
	check(gs.player(0).hand.is_empty(), "same instance cannot return twice")
	give(gs, "c11501")
	check(gs.hand_card_def(0, 0).value == 2 and gs.hand_card_def(0, 0).snakeReturns, "other copy retains its own return ability")
	gs = fixture()
	enemy = gs.player(1).units[2]
	enemy.barrier = true
	enemy.armorBreak = 2
	play(gs, "c11501", enemy.uid)
	check(not enemy.barrier and gs.player(0).hand.size() == 1, "shielded damage still returns once after real card effect")
	gs = fixture()
	for u in gs.player(1).units:
		u.hp = 20
		u.maxHp = 20
		u.baseMaxHp = 20
	gs.player(1).units[2].armorBreak = 3
	play(gs, "c11502")
	check(gs.player(1).units[2].hp == 15 and gs.player(1).units[3].hp == 20 and gs.player(1).units[3].armorBreak == 2, "toxin independently hits marked and converts unmarked")
	check(gs.player(1).avatarHp == 30 and gs.player(1).avatarArmorBreak == 2, "toxin includes enemy avatar")
	gs = fixture()
	play(gs, "c11504")
	check(gs.player(1).avatarArmorBreak == 4, "unmarked projectile converts against avatar")
	gs = fixture()
	enemy = gs.player(1).units[2]
	enemy.hp = 10
	enemy.maxHp = 10
	enemy.baseMaxHp = 10
	gs.player(1).units[3].armorBreak = 1
	var unmarked_hp := int(gs.player(1).units[1].hp)
	play(gs, "c11505", enemy.uid)
	check(enemy.hp == 5 and enemy.armorBreak == 0, "scorch grants2 then deals3 plus2")
	check(gs.player(1).units[3].hp == maxi(0, int(gs.player(1).units[3].maxHp) - 4), "scorch includes previously marked target")
	check(gs.player(1).units[1].hp == unmarked_hp and gs.player(1).units[1].armorBreak == 0, "scorch excludes other unmarked units")
	gs = fixture()
	play(gs, "c11505", "avatar-1")
	check(gs.player(1).avatarHp == 25, "scorch supports selected avatar")
	gs = fixture()
	play(gs, "c11505", gs.player(0).units[2].uid)
	check(gs.player(0).units[2].armorBreak == 2 and gs.player(1).avatarHp == 30, "scorch permits friendly role, then only marked foes")
	gs = fixture()
	play(gs, "c11507", gs.player(0).units[2].uid)
	var ally: Dictionary = gs.player(0).units[2]
	check(ally.shield == 2 and ally.poisonShieldTurn == gs.turn_counter, "shield grants armor and one-turn ability")
	var foe: Dictionary = gs.player(1).units[2]
	foe.front = 1
	gs._resolve_combat(0, 2, 0, false, false, false, false)
	check(foe.armorBreak == 3, "shield applies after real outgoing combat damage")
	Native.end_turn(gs, 0)
	check(not ally.has("poisonShieldTurn"), "shield grant expires at actual end")
func _turns() -> void:
	var gs := fixture()
	play(gs, "c11503")
	gs.player(1).units[2].front = 1
	Native.end_turn(gs, 0)
	check(gs.player(1).units[2].armorBreak == 0, "mist doesn't fire at own end")
	Native.end_turn(gs, 1)
	check(gs.player(1).units[2].armorBreak == 2, "mist fires at enemy end")
	gs = fixture()
	play(gs, "c11508")
	var target: Dictionary = gs.player(1).units[2]
	var base := int(target.attack)
	check(target.armorBreak == 0, "firekiss no fabricated entry break")
	gs.current_player = 1
	gs._begin_turn(1)
	check(target.armorBreak == 1 and target.attack == base - 1 and gs.player(1).avatarArmorBreak == 1, "firekiss fires after start clear and weakens live power")
	gs.VerifiedRules.ArmorBreak.give(gs, 0, 0, 1, 2, 3)
	check(target.attack == base - 4, "power reduction follows current break")
	gs._grant_unit_armor(target, 4)
	check(target.attack == base and target.armorBreak == 0, "armor cancellation restores live power")
	gs.VerifiedRules.ArmorBreak.give(gs, 0, 0, 1, 2, 3)
	gs._damage_unit(0, 1, 99, 1, 2)
	check(target.attack == base, "source death removes aura")
	gs = fixture()
	play(gs, "c11506")
	gs.player(1).avatarArmorBreak = 5
	gs.player(1).units[2].armorBreak = 6
	gs._begin_turn(1)
	check(gs.player(1).avatarArmorBreak == 5 and gs.player(1).units[2].armorBreak == 6, "awake retains all enemy roles")
	gs.player(0).units[1].hp = 0
	gs._begin_turn(1)
	check(gs.player(1).avatarArmorBreak == 0 and gs.player(1).units[2].armorBreak == 0, "knocked awake source doesn't retain enemy break")
	gs = fixture()
	gs.player(0).units[2].front = 1
	give(gs, "c11403")
	gs._begin_turn(0)
	check(gs._kw(gs.hand_card_def(0, 0), "instant"), "front at start enhances held fountain")
	give(gs, "c11403")
	check(not gs._kw(gs.hand_card_def(0, 1), "instant"), "new copy does not retroactively enhance")
func _response() -> void:
	var gs := fixture()
	give(gs, "c11409", 1)
	check(gs.basic_attack(0, 2), "avatar attack initiates")
	check(gs.player(1).avatarHp == 30 and gs.player(1).units[0].front == 1, "sweet redirects avatar combat to jumper")
	check(int(gs.player(1).get("enemyAvatarAttacks",0)) == 0, "successful guard excludes avatar attack history")
	check(gs.player(0).units[2].hp == maxi(0, int(gs.player(0).units[2].maxHp) - 5), "sweet adds3 defender power without extra attack")
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 30, "sweet uses defender turn instant")
	gs = fixture()
	give(gs, "c11409", 1)
	gs.player(1).units[2].front = 1
	gs.basic_attack(0, 2)
	check(gs.player(1).hand.size() == 1 and gs.player(1).units[0].front == 0, "unit attack isn't avatar response")
	gs = fixture()
	give(gs, "c11409", 1)
	gs.player(1).units[0].frozen = 1
	gs.basic_attack(0, 2)
	check(gs.player(1).hand.size() == 1 and gs.player(1).avatarHp < 30, "stunned jumper cannot intercept")
	gs = fixture()
	give(gs, "c11507", 1)
	gs.player(1).units[2].front = 1
	gs.basic_attack(0, 2)
	check(gs.player(1).hand.is_empty() and gs.player(1).units[2].poisonShieldTurn == gs.turn_counter, "shield auto targets attacked front")
	gs = fixture()
	give(gs, "c11507", 1)
	gs._damage_unit(1, 2, 1, 0, 2)
	check(gs.player(1).hand.size() == 1, "shield excludes non-attack damage")
	gs = fixture()
	give(gs, "c11409", 1)
	gs.player(1).nullifyNextCardTurn = gs.turn_counter
	gs.basic_attack(0, 2)
	check(gs.player(1).avatarHp == 29 and gs.player(1).units[0].front == 0, "countered sweet leaves original avatar attack intact")
	check(int(gs.player(1).get("enemyAvatarAttacks",0)) == 1, "countered guard resumes avatar attack count exactly once")
	gs = fixture()
	give(gs, "c11409", 1)
	give(gs, "c11507", 1)
	gs.basic_attack(0, 2)
	check(gs.player(1).hand.is_empty() and gs.player(1).units[0].poisonShieldTurn == gs.turn_counter, "redirect then new front shield responds in same combat")
	check(gs.player(1).avatarHp == 30 and gs.player(1).units[0].hp == 9, "chain shield protects redirected target before damage")
	gs = fixture()
	give(gs, "c11409", 1)
	gs.player(1).units[2].front = 1
	gs._resolve_combat(0, 2, 0, false, false, false, false, null, false, {"directAvatar":true})
	gs._resolve_resolution_stack()
	check(gs.player(1).avatarHp == 30 and gs.player(1).units[2].front == 0 and gs.player(1).units[0].front == 1, "sweet redirects direct attack even when another ally occupies front")
	gs = fixture()
	give(gs, "c11409", 1)
	gs.player(1).energy = 0
	gs.kw_usage(1,"instant").used = true
	gs.basic_attack(0, 2)
	check(gs.player(1).hand.size() == 1 and gs.player(1).avatarHp == 29, "sweet needs fire after instant quota already used")
	check(int(gs.player(1).get("enemyAvatarAttacks",0)) == 1, "unaffordable response allows one avatar attack history event")
func _legality() -> void:
	var gs := fixture()
	for id in ["c11401", "c11406", "c11501", "c11505", "c11507"]:
		var frame := {"playerIndex":0,"definitionId":id,"effectIndex":0,"resolutionId":1,"responseDepth":0}
		var window: Dictionary = gs._create_response_window(frame)
		var expected := "assault" if id in ["c11401","c11406"] else ("shield" if id == "c11507" else "damage")
		check(window.action == expected,"native action preserves existing response class " + id)
	for id in ["c11501", "c11505", "c11507"]:
		var h := give(gs, id)
		var card: Dictionary = gs.hand_card_def(0, h)
		var targets: Array = gs.valid_targets(0, card)
		check(not targets.is_empty(), "real target list " + id)
		for uid in targets: check(gs.can_play_card(0, h, uid).ok, "legal target " + id + str(uid))
		check(not gs.can_play_card(0, h, "fake-unit").ok, "invalid target rejected " + id)
		if id == "c11501": check(not targets.has("avatar-1"), "strike cannot target avatar")
		if id == "c11505": check(targets.has("avatar-0") and targets.has("avatar-1"), "scorch offers both avatars")
	gs = fixture()
	for id in ["c11401","c11402","c11403","c11404","c11405","c11406","c11408","c11409","c11501","c11502","c11503","c11504","c11505","c11506","c11507","c11508"]:
		var card := Content.card_def(id)
		check(card.verifiedRules and card.poisonRules, "native definition " + id)
		check("简化" not in str(card.text), "native card text " + id)
		check(card.sources.size() >= 1, "source trace " + id)
func _fox_bonuses() -> void:
	var gs := GS.create(["tiaotiaodidi","qingshe","yaohu","zuofutongzi"],["tiaotiaodidi","qingshe","qingfangzhu","zuofutongzi"],20261014)
	for p in gs.players:
		p.hand.clear();p.energy=30;p.levelUpUsed=true;p.avatarArmor=0
		for u in p.units:u.level=3
	play(gs,"c13402")
	var h := give(gs,"c11501")
	var quote: Dictionary = gs.hand_card_def(0,h)
	check(quote.value==2 and int(quote.get("foxHandDamageBonus",0))==0,"聚气 cannot strengthen snake printed damage")
	check(gs.play_card(0,h,gs.player(1).units[2].uid),"snake alongside fox concentration")
	check(gs.player(1).units[2].armorBreak==2,"fox-only concentration does not change Qing conversion")
	play(gs,"c13408")
	h=give(gs,"c11501")
	quote=gs.hand_card_def(0,h)
	check(quote.value==2 and quote.foxHandDamageBonus==1,"love adds a separate damage quote, not card.value")
	check(gs.play_card(0,h,gs.player(1).units[3].uid),"love enhanced snake")
	check(gs.player(1).units[3].armorBreak==3,"love amplifies snake actual damage before conversion")
	gs.player(1).units[2].armorBreak=0
	gs.player(1).units[3].armorBreak=0
	play(gs,"c11505",gs.player(0).units[3].uid)
	check(gs.player(0).units[3].armorBreak==2,"love never increases explicitly granted armor break")
	check(gs.player(1).units[2].armorBreak==0,"scorch excludes unmarked enemy even when love aura active")
	play(gs,"c11502")
	check(gs.player(1).units[2].armorBreak==3,"love toxin explicit2+1 converts once")
	gs.player(0).units[0].armorBreak=4
	play(gs,"c11403")
	check(gs.player(1).units[2].armorBreak==7 and gs.player(0).units[0].armorBreak==0,"love doesn't increase transferred4 break")
func _ai() -> void:
	var gs := fixture()
	give(gs, "c11501")
	gs.player(1).units[2].armorBreak = 2
	var pick := AI._best_card(gs, 0)
	check(pick.ok and str(pick.target) == str(gs.player(1).units[2].uid), "AI prefers marked enemy strike target")
	check(gs.can_play_card(0, pick.hand, pick.target).ok, "AI uses same legal target contract")
	gs = fixture()
	give(gs, "c11403")
	check(not AI._best_card(gs, 0).ok, "AI avoids zero-break fountain")
	gs.player(0).units[0].armorBreak = 3
	check(AI._best_card(gs, 0).ok, "AI selects useful fountain")
	for seed in [114,115,114115,20261013]:
		gs = GS.create(["tiaotiaodidi","qingshe","zhen","qingfangzhu"],["tiaotiaodidi","qingshe","haifangzhu","zuofutongzi"],seed)
		gs.phase = "main"
		var steps := 0
		while gs.winner < 0 and steps < 2000:
			check(AI.take_action(gs, gs.action_player()), "AI match command legal seed%d step%d" % [seed,steps])
			steps += 1
		check(gs.winner >= 0, "AI match finishes seed%d" % seed)
