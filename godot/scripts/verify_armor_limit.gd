extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
const LIMIT := 65535
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ARMOR_LIMIT_FAIL ", detail)
func fixture() -> GS:
	var gs := GS.create(["jiuciliang","haifangzhu","qingshe","bingyong"],["yaodaoji","yingcao","fenghuanghuo","shantong"],20261015)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs: GS, id: String) -> int:
	gs.player(0).hand.append({"instanceId":"armor-limit-%d" % gs.next_card_id,"definitionId":id})
	gs.next_card_id += 1
	return gs.player(0).hand.size()-1
func _initialize() -> void:
	_armor()
	_break()
	_cards()
	print("ARMOR_LIMIT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _armor() -> void:
	for idx in [-1,0]:
		var gs := fixture()
		var p: Dictionary = gs.player(0)
		var u: Dictionary = p.units[0]
		for initial in [0,LIMIT-1,LIMIT]:
			if idx < 0: p.avatarArmor = initial
			else: u.shield = initial; u.shieldExpires = 0
			var actual := gs._grant_avatar_armor(0,2) if idx < 0 else gs._grant_unit_armor(u,2)
			var value: int = p.avatarArmor if idx < 0 else u.shield
			check(value == mini(LIMIT,initial+2),"armor cap target%d initial%d" % [idx,initial])
			check(actual == mini(2,LIMIT-initial),"armor reports actual gain target%d initial%d" % [idx,initial])
			if idx >= 0: check(u.shieldExpires == actual,"temporary armor records only actual gain")
		if idx < 0:
			p.avatarArmor = 0; p.avatarArmorBreak = 4
			check(gs._grant_avatar_armor(0,LIMIT+7) == LIMIT and p.avatarArmor == LIMIT and p.avatarArmorBreak == 0,"avatar cancellation precedes cap")
		else:
			u.shield = 0; u.shieldExpires = 0; u.armorBreak = 4
			check(gs._grant_unit_armor(u,LIMIT+7) == LIMIT and u.shield == LIMIT and u.armorBreak == 0 and u.shieldExpires == LIMIT,"unit cancellation precedes cap")
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	check(gs._grant_unit_armor(u,LIMIT-1,false) == LIMIT-1,"permanent armor fixture")
	check(gs._grant_unit_armor(u,50) == 1 and u.shieldExpires == 1,"overflow cannot become expiring armor")
	gs._begin_turn(0)
	check(u.shield == LIMIT-1 and u.shieldExpires == 0,"next own turn retains original permanent armor")
	u.hp = 0
	check(gs._grant_unit_armor(u,3) == 0 and u.shield == LIMIT-1,"dead target receives no armor")
	u.hp = 1
	check(gs._grant_unit_armor(u,-1) == 0 and u.shield == LIMIT-1,"negative grant changes nothing")
	check(gs._grant_unit_armor(u,9223372036854775807) == 1 and u.shield == LIMIT,"huge request cannot overflow before capping")
	gs = fixture()
	u = gs.player(0).units[3]
	u.shield = LIMIT-1
	gs.VerifiedRules.Bingyong.gain_armor(gs,0,u,10)
	var events: Array = gs.rule_events.filter(func(e):return e.kind == "armor-gained")
	check(events.size() == 1 and events[0].amount == 1,"bingyong emits only actual acquired armor")
	gs.rule_events.clear()
	gs.VerifiedRules.Bingyong.gain_armor(gs,0,u,10)
	check(not gs.rule_events.any(func(e):return e.kind == "armor-gained"),"full armor cannot fabricate gain trigger")
	gs.player(0).units[1].awakened = true
	var power := int(u.attack)
	gs.rule_events.clear()
	gs.VerifiedRules.Tide.heal(gs,0,1,0,3,20)
	check(u.shield == LIMIT and u.attack == power+20,"overheal armor cap does not incorrectly cap independent power growth")
	var healing: Array = gs.rule_events.filter(func(e):return e.kind == "tide-overheal")
	check(healing.size() == 1 and healing[0].armor == 0 and healing[0].attack == 20,"overheal event separates zero acquired armor from full power growth")
func _break() -> void:
	for idx in [-1,0]:
		var gs := fixture()
		var p: Dictionary = gs.player(1)
		var u: Dictionary = p.units[0]
		for initial in [0,LIMIT-1,LIMIT]:
			if idx < 0: p.avatarArmorBreak = initial
			else:
				u.armorBreak = initial
				u.erase("armorBreakGainedTurn")
			gs.rule_events.clear()
			gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,idx,2)
			check(gs.VerifiedRules.ArmorBreak.amount(gs,1,idx) == mini(LIMIT,initial+2),"break cap target%d initial%d" % [idx,initial])
			var events: Array = gs.rule_events.filter(func(e):return e.kind == "armor-break-gained")
			check(events.size() == (0 if initial == LIMIT else 1),"no acquired-break event at cap")
			if not events.is_empty(): check(events[0].amount == mini(2,LIMIT-initial),"event records actual break gain")
			if idx >= 0: check(u.has("armorBreakGainedTurn") == (initial < LIMIT),"overflow cannot mark first gain")
		if idx < 0: p.avatarArmor = 4; p.avatarArmorBreak = 0
		else: u.shield = 4; u.shieldExpires = 4; u.armorBreak = 0; u.barrier = true
		gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,idx,LIMIT+7)
		check(gs.VerifiedRules.ArmorBreak.amount(gs,1,idx) == LIMIT,"break cancels armor then caps remainder")
		check(p.avatarArmor == 0 if idx < 0 else u.shield == 0 and u.shieldExpires == 0 and u.barrier,"armor cancellation never consumes barrier")
		check(gs.VerifiedRules.ArmorBreak.consume(gs,1,idx) == LIMIT and gs.VerifiedRules.ArmorBreak.amount(gs,1,idx) == 0,"damage consumes capped status once")
	var gs := fixture()
	var source: Dictionary = gs.player(0).units[3]
	source.formRules = {"armorBreakToDamage":true}
	var u: Dictionary = gs.player(1).units[0]
	u.hp = 200000; u.maxHp = 200000
	var hit: Dictionary = gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,0,LIMIT+10)
	check(hit.dealt == LIMIT+10 and u.hp == 200000-LIMIT-10 and u.armorBreak == 0,"replacement damage is not limited as acquired armor break")
	gs = fixture()
	u = gs.player(1).units[0]
	u.armorBreak = LIMIT
	gs.player(0).units[3].formRules = {"firstEnemyArmorBreakCountdown":1}
	gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,0,10)
	check(gs.resolution_stack.is_empty(),"overflow cannot trigger first-gain countdown observer")
	gs._grant_unit_armor(u,1)
	gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,0,10)
	check(gs.resolution_stack.size() == 1 and gs.resolution_stack[0].kind == "countdown-change","first actual gain still triggers observer after earlier overflow")
	gs.resolution_stack.clear()
	u.hp = 200000; u.maxHp = 200000; u.barrier = true
	gs._damage_unit(1,0,2,0,3)
	check(u.hp == 200000 and u.armorBreak == LIMIT and not u.barrier,"barrier prevents damage without consuming capped break")
	gs._damage_unit(1,0,2,0,3)
	check(u.hp == 200000-LIMIT-2 and u.armorBreak == 0,"actual hit consumes capped break and deals full augmented damage")
	gs = fixture()
	gs.player(0).units[3].formRules = {"armorBreakToDamage":true}
	gs.player(1).avatarHp = 200000; gs.player(1).maxAvatarHp = 200000
	gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,-1,LIMIT+10)
	check(gs.player(1).avatarHp == 200000-LIMIT-10 and gs.player(1).avatarArmorBreak == 0,"avatar replacement damage also remains uncapped")
	gs = fixture()
	gs._damage_unit(1,0,LIMIT+10,0,2)
	check(gs.player(1).units[0].hp == gs.player(1).units[0].maxHp and gs.player(1).units[0].armorBreak == LIMIT,"snake damage conversion caps status without creating actual damage")
	gs.rule_events.clear()
	gs.player(1).units[0].hp = 0
	gs.VerifiedRules.ArmorBreak.give(gs,0,3,1,0,2)
	check(gs.rule_events.is_empty(),"dead character gains neither break nor acquired event")
func _cards() -> void:
	var gs := fixture()
	var whale: Dictionary = gs.player(0).units[0]
	whale.awakened = true
	gs._grant_unit_armor(whale,LIMIT-1,false)
	var target: Dictionary = gs.player(0).units[1]
	target.shield = LIMIT-1; target.shieldExpires = 0
	check(gs.play_card(0,give(gs,"c17903"),target.uid),"real white bone target card remains legal near cap")
	check(target.shield == LIMIT and target.shieldExpires == 1,"white bone follows shared cap")
	gs._grant_unit_armor(whale,5)
	check(whale.shield == LIMIT and whale.attack == 2+LIMIT,"whale derived power uses capped armor")
	var armor_before := int(whale.shield)
	gs.VerifiedRules.ArmorBreak.give(gs,0,3,0,0,3)
	check(whale.shield == armor_before-3 and whale.attack == 2+armor_before-3,"armor cancellation refreshes derived power immediately")
	gs = fixture()
	gs.player(0).avatarArmor = LIMIT-1
	gs.VerifiedRules.TomatoFire.swan(gs,0,0,18)
	check(gs.player(0).avatarArmor == LIMIT,"swan avatar armor routes through shared cap")
	gs.player(0).avatarArmor = 0; gs.player(0).avatarArmorBreak = 3
	gs.VerifiedRules.TomatoFire.swan(gs,0,0,18)
	check(gs.player(0).avatarArmor == 5 and gs.player(0).avatarArmorBreak == 0,"swan avatar armor also cancels existing break")
	gs = fixture()
	target = gs.player(0).units[1]
	target.shield = LIMIT-1
	var hand_index := give(gs,"c11703")
	check(gs.hand_card_def(0,hand_index).text.contains("预计65535"),"water cyclone preview respects armor cap")
	gs.player(1).units[0].hp = 200000; gs.player(1).units[0].maxHp = 200000
	check(AI._score_card(gs,0,gs.hand_card_def(0,hand_index),gs.player(1).units[0].uid) > 0,"AI can legally use real armor-derived damage card at cap")
	check(gs.play_card(0,hand_index,gs.player(1).units[0].uid),"real cyclone card accepts enemy target")
	check(target.shield == LIMIT and gs.player(1).units[0].hp == 200000-LIMIT,"cyclone deals actual capped armor rather than requested armor")
	gs = fixture()
	gs.player(0).units[1].shield = LIMIT-1
	for foe in gs.player(1).units: foe.hp = 200000; foe.maxHp = 200000
	give(gs,"c11703")
	check(AI.take_action(gs,0),"AI actually plays armor-derived damage at cap")
	var total := 0
	for foe in gs.player(1).units: total += int(foe.hp)
	check(total == 800000-LIMIT and gs.player(0).units[1].shield == LIMIT and gs.player(0).hand.is_empty(),"AI uses legal target and actual capped armor value")
