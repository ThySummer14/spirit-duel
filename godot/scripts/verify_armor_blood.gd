extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
const Rules := preload("res://scripts/armor_blood_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ARMOR_BLOOD_FAIL ", detail)
func fixture() -> GS:
	var gs := GS.create(["jiuciliang","xixueji","qingfangzhu","fenghuanghuo"],["yaodaoji","bingyong","yingcao","shantong"],20261015)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.player(0).units[2].level = 0
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId":"armor-blood-%d" % gs.next_card_id,"definitionId":id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size()-1
func play(gs: GS, id: String, target: Variant = null, owner: int = 0) -> bool:
	return gs.play_card(owner,give(gs,id,owner),target)
func _initialize() -> void:
	Content.load_content(true)
	_data()
	_armor()
	_realms()
	_healing()
	_transfer()
	_leech()
	_response()
	_ai()
	print("ARMOR_BLOOD checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _data() -> void:
	for role in ["173","179"]:
		for i in range(1,9):
			var c := Content.card_def("c%s%02d" % [role,i])
			check(c.verifiedRules and c.effects.size() == 1, "one reviewed execution without legacy substitutes " + c.id)
			check(int(c.cost) == 1 and int(c.deckLimit) == 2, "printed cost and normal two-copy limit " + c.id)
	check(Content.card_def("c17305").value.hp == 6, "release snapshot thirst3/6 overrides preview3/7")
	check(not "combo" in Content.card_def("c17306").keywords, "blood scent follows official20200928 rather than stale combo snapshot")
func _armor() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	gs._grant_unit_armor(u,2)
	check(u.attack == 3, "base whale armor grants exactly one power")
	gs._damage_unit(0,0,1,1,0)
	check(u.shield == 1 and u.attack == 3 and u.hp == 6, "nonzero remaining armor retains one power")
	gs._damage_unit(0,0,2,1,0)
	check(u.shield == 0 and u.attack == 2 and u.hp == 5, "last armor lost recalculates immediately")
	check(play(gs,"c17907"), "whale awakens")
	gs._grant_unit_armor(u,4)
	check(u.attack == 7 and u.maxHp == 8, "awakening replaces one-power with current armor")
	gs.VerifiedRules.ArmorBreak.give(gs,1,0,0,0,3)
	check(u.shield == 1 and u.attack == 4, "armor-break cancellation lowers power immediately")
	gs.VerifiedRules.Combat.strip_protection(gs,0,0,true)
	check(u.attack == 3 and u.shield == 0, "penetration lowers derived power immediately")
	gs._grant_unit_armor(u,3)
	gs._begin_turn(0)
	check(u.shield == 0 and u.attack == 3, "natural armor expiry removes derived power")
	gs = fixture(); u = gs.player(0).units[0]
	check(play(gs,"c17901"), "whale stand combat")
	check(gs.player(1).avatarHp == 27 and u.shield == 2 and u.attack == 3, "stand adds armor before attack power is read")
	gs = fixture(); u = gs.player(0).units[0]
	check(play(gs,"c17904"), "fish form without realm")
	check(u.attack == 4 and u.maxHp == 6 and u.shield == 0, "fish exact4/6 with no invented unconditional armor")
	check(play(gs,"c17902") and play(gs,"c17904"), "fish with realm")
	check(u.shield == 2 and u.attack == 5, "fish entry checks realm and grants two armor")
	check(play(gs,"c17907"), "awake before turn")
	gs._begin_turn(0)
	check(u.shield == 3 and u.attack == 8, "awakening one realm plus fish two armor after expiry")
	var quoted: Dictionary = gs.hand_card_def(0,give(gs,"c17905"))
	check(quoted.value == 2 and quoted.combatOption.shield == 2, "open base1/1 plus real realm count")
	gs.player(0).hand.clear()
	gs.player(0).levelUpUsed = true
	check(play(gs,"c17905"), "enhanced whale open")
	check(u.shield == 5 and u.attack == 10, "combat armor persists and attack bonus is not permanent")
	gs = fixture(); u = gs.player(0).units[0]
	var idx := give(gs,"c17903")
	var fire: int = gs.player(0).energy
	check(not gs.valid_targets(0,gs.hand_card_def(0,idx)).has(u.uid), "white bone excludes caster in same target list")
	check(not gs.play_card(0,idx,u.uid) and gs.player(0).energy == fire, "illegal self target never pays or consumes")
	var ally: Dictionary = gs.player(0).units[1]
	check(gs.play_card(0,idx,ally.uid) and ally.attack == 4 and ally.shield == 4, "white bone grants four armor and transient base ability")
	gs.VerifiedRules.end_turn(gs,0)
	check(ally.attack == 3 and ally.shield == 4, "turn-scoped ability ends independently from armor")
func _realms() -> void:
	var gs := fixture()
	check(play(gs,"c17902"), "guard realm deploys")
	var p: Dictionary = gs.player(0)
	var guardian: Dictionary = p.realms[0]
	gs._damage_unit(0,1,1,1,0)
	check(p.units[1].hp == 3 and p.units[1].shield == 1, "guard grants after actual damage to damaged ally")
	gs._damage_unit(0,1,1,1,0)
	check(p.units[1].hp == 3 and p.units[1].shield == 0, "fully absorbed packet does not trigger guard")
	gs._damage_unit(0,1,1,1,0)
	check(p.units[1].hp == 2 and p.units[1].shield == 1, "subsequent unblocked packet triggers independently")
	gs._knockout_unit(p.units[0],1,0)
	gs._damage_unit(0,1,2,1,0)
	check(p.units[1].hp == 1 and p.units[1].shield == 1, "realm continues after owner shikigami knockout")
	check(guardian.hp == 6, "unit damage does not reduce realm durability")
	p.units[0].hp = p.units[0].maxHp; p.units[0].knockout = 0
	check(play(gs,"c17908"), "treasure deploys")
	var treasure_uid := str(p.realms[1].uid)
	p.avatarHp = 2
	p.avatarArmor = 3
	gs._damage_avatar(0,3,1,0)
	check(p.avatarHp == 2 and guardian.hp == 6, "avatar armor absorbs before realm durability")
	gs._damage_avatar(0,8,1,0)
	check(p.avatarHp == 1 and p.realms.size() == 1 and p.realms[0].hp == 10, "only first realm destroyed with no excess spill; rear treasure protects")
	gs._damage_avatar(0,12,1,0)
	check(p.avatarHp == 1 and p.realms.is_empty() and gs.winner < 0, "treasure protects breaking packet and loses full incoming durability")
	check(play(gs,"c17902"), "new realm after removal")
	check(p.realms[0].uid != treasure_uid, "realm UID never reused after removal")
	gs._damage_avatar(0,1,1,0)
	check(gs.winner == 1, "next packet can kill after treasure breaks")
	gs = fixture(); p = gs.player(0)
	check(play(gs,"c17906"), "square form without realm")
	check(p.units[0].attack == 5 and p.units[0].maxHp == 8 and p.units[1].shield == 0, "square exact body with realm condition")
	check(gs.VerifiedRules.Combat.has(p.units[0],"veil") and Rules.realm_veil(gs,0), "square supplies real unit and realm veil")
	var realm_probe := {"type":"spell","target":"enemy-realm"}
	check(gs.valid_targets(1,realm_probe).is_empty(), "realm veil filters actual realm target query")
	check(not gs.valid_targets(1,Content.card_def("c17302")).has(p.units[0].uid), "enemy spells cannot target veiled whale")
	check(play(gs,"c17902") and play(gs,"c17906"), "square with realm")
	check(p.units.all(func(u):return int(u.shield) == 3), "square entry grants three armor to every living ally")
	gs._begin_turn(0)
	check(p.units.all(func(u):return int(u.shield) == 3), "square repeats on own turn after armor cleanup")
	gs._knockout_unit(p.units[0],1,0)
	check(not Rules.realm_veil(gs,0), "square veil ends when form leaves")
	check(gs.valid_targets(1,realm_probe) == [p.realms[0].uid], "realm target becomes legal after veil source leaves")
func _healing() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var u: Dictionary = p.units[1]
	give(gs,"c17303"); give(gs,"c17303",1)
	u.hp = 2
	gs._heal_unit(u,2)
	check(u.attack == 3 and u.shield == 0, "unit healing never triggers avatar healing ability")
	p.avatarHp = 20
	gs._heal_avatar(0,3)
	check(u.attack == 4 and u.shield == 1, "base grows once per actual healing event rather than per point")
	check(gs.hand_card_def(0,0).value == 2 and gs.hand_card_def(1,0).value == 2, "both hands enhance after either avatar heals")
	gs.player(1).avatarHp = 29
	gs._heal_avatar(1,8)
	check(gs.hand_card_def(0,0).value == 3 and u.attack == 4, "opponent healing enhances blood rage but never friendly growth")
	give(gs,"c17303")
	check(gs.hand_card_def(0,1).value == 1, "later drawn copy never inherits old enhancement")
	gs._heal_avatar(1,1)
	check(gs.hand_card_def(0,0).value == 3, "full-health heal does not create enhancement event")
	check(play(gs,"c17307"), "vampire awakens")
	p.avatarHp = 28
	gs._heal_avatar(0,50)
	check(u.attack == 7 and u.shield == 3 and u.maxHp == 5, "awake growth uses actual2, preserves printed1/1")
	p.avatarHp = 10
	gs._heal_avatar(0,8)
	check(u.attack == 12 and u.shield == 8, "awake growth capped at five per event")
	gs._knockout_unit(u,1,0)
	check(u.attack == 4 and u.shield == 0 and u.awakened, "knockout clears ordinary recovery growth and retains awakening")
	var n := gs.rule_events.filter(func(e):return e.kind == "blood-growth").size()
	gs._heal_avatar(0,2)
	check(gs.rule_events.filter(func(e):return e.kind == "blood-growth").size() == n, "knocked vampire cannot grow")
	gs.players = JSON.parse_string(JSON.stringify(gs.players))
	check(gs.hand_card_def(0,0).value == 6, "per-copy blood enhancement survives JSON")
func _transfer() -> void:
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[0]
	check(play(gs,"c17302",enemy.uid), "blood shield accepts enemy unit")
	gs._grant_unit_armor(enemy,2)
	gs.player(1).avatarArmor = 1
	var hit: Dictionary = gs.VerifiedRules.Combat.strike(gs,0,1,1,0,6,{"lifeSteal":true},true)
	check(enemy.hp == 4 and enemy.shield == 0 and not enemy.has("bloodTransfer"), "shield consumes before damage and preserves unit after its armor is spent")
	check(gs.player(1).avatarHp == 27 and hit.damage == 0 and hit.transferredDealt == 3, "transfer applies own avatar armor once and suppresses duplicate piercing")
	check(gs.rule_events.any(func(e):return e.kind == "blood-transfer" and e.amount == 4), "event records post-armor transfer amount")
	gs._damage_unit(1,0,1,0,1)
	check(enemy.hp == 3, "replacement is one damage event only")
	gs = fixture(); enemy = gs.player(1).units[0]
	play(gs,"c17302",enemy.uid)
	var immune_hit: Dictionary = gs.VerifiedRules.Combat.strike(gs,0,1,1,0,3,{},false,true)
	check(enemy.hp == 4 and gs.player(1).avatarHp == 27 and immune_hit.get("transferredDealt",0) == 3,"post-armor transfer precedes unit combat immunity per original ordering")
	gs = fixture(); enemy = gs.player(1).units[0]
	play(gs,"c17302",enemy.uid)
	enemy.armorBreak = 3
	gs._damage_unit(1,0,1,0,1)
	check(enemy.hp == 4 and enemy.armorBreak == 0 and gs.player(1).avatarHp == 26, "target armor break increases transferred packet")
	gs = fixture(); enemy = gs.player(1).units[0]
	play(gs,"c17302",enemy.uid)
	enemy.barrier = true
	gs._damage_unit(1,0,1,0,1)
	check(not enemy.get("bloodTransfer",false) and not enemy.barrier and gs.player(1).avatarHp == 30, "barrier stops damage while consumed replacement does not carry over")
	gs = GS.create(["qingshe","xixueji","jiuciliang","yaodaoji"],["yaodaoji","bingyong","yingcao","shantong"],17)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	enemy = gs.player(1).units[0]
	play(gs,"c17302",enemy.uid)
	gs.VerifiedRules.Combat.strike(gs,0,0,1,0,2,{})
	check(enemy.armorBreak == 2 and not enemy.get("bloodTransfer",false) and gs.player(1).avatarHp == 30, "poison conversion consumes blood flag without fabricated avatar hit")
func _leech() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	p.avatarHp = 20
	e.units[0].front = 1; e.units[0].hp = 1
	check(play(gs,"c17301"), "blood attack")
	check(p.avatarHp == 23 and p.units[1].attack == 4, "blood attack heals avatar by full dealt3 including overkill, then grows once")
	check(p.units[1].hp == 2, "new armor participates in ordinary counterattack")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	check(play(gs,"c17305"), "thirst form")
	check(p.units[1].attack == 3 and p.units[1].maxHp == 6 and p.avatarHp == 30, "thirst body only, no invented entry healing")
	p.avatarHp = 20
	gs.basic_attack(0,1)
	check(p.avatarHp == 23 and p.units[1].attack == 4, "form makes ordinary combat lifesteal")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	e.units[0].front = 1; e.units[0].hp = 100; e.units[0].maxHp = 100
	check(play(gs,"c17306"), "blood scent at30")
	check(e.units[0].hp == 95 and p.units[1].hp == 4, "at30 scent grants combat immunity with one five-power hit")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.avatarHp = 29; e.units[0].front = 1; e.units[0].hp = 100
	check(play(gs,"c17306") and p.units[1].hp == 2, "at29 scent has no immunity; one printed armor absorbs counter")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.avatarHp = 20
	check(play(gs,"c17304",p.units[0].uid), "embrace accepts friendly whale")
	check(p.units[0].hp == 5 and p.avatarHp == 20, "embrace causes printed damage and no instant fixed heal")
	gs.basic_attack(0,0)
	check(p.avatarHp == 22, "embrace heals its casting avatar on combat damage")
	gs.VerifiedRules.end_turn(gs,0)
	p.attackUsed = false
	gs.basic_attack(0,0)
	check(p.avatarHp == 22, "embrace expires on actual turn end")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.avatarHp = 20
	check(play(gs,"c17308"), "moon form")
	check(p.units[1].attack == 5 and p.units[1].maxHp == 8 and p.avatarHp == 20, "moon exact5/8 and no fabricated entry recovery")
	check(play(gs,"c17303","avatar-1"), "rage targets avatar")
	check(e.avatarHp == 29 and p.avatarHp == 21 and p.units[1].attack == 6, "rage direct damage lifesteals once even under moon")
	var old: int = p.avatarHp
	check(play(gs,"c12401"), "allied phoenix spell under moon")
	check(p.avatarHp == old + 2, "moon grants allied spell lifesteal but excludes triggered projectile")
	p.units[2].level = 3
	check(play(gs,"c12501"), "healing spell under moon")
	check(p.avatarHp <= 30 and gs.rule_events.size() < 128, "healing-triggered monk damage cannot inherit lifesteal recursively")
	gs = fixture(); p = gs.player(0)
	p.avatarHp = 1
	check(play(gs,"c17303","avatar-0") and gs.winner == 1, "lethal self damage loses before lifesteal can recover")
func _response() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	p.units[1].front = 1
	give(gs,"c17302")
	gs.current_player = 1
	check(gs.basic_attack(1,0), "attack starts automatic shield")
	check(p.hand.is_empty() and p.energy == 39 and p.units[1].hp == 4 and p.avatarHp == 27, "automatic blood shield pays once and redirects original attack")
	gs = fixture(); p = gs.player(0)
	p.units[1].front = 1
	give(gs,"c17903")
	gs.current_player = 1
	check(gs.basic_attack(1,0), "attack starts automatic white bone")
	check(p.hand.is_empty() and p.units[1].hp == 4 and p.units[1].shield == 1 and p.units[1].attack == 4, "automatic other-ally shield grants armor and true temporary ability")
	gs = fixture(); p = gs.player(0)
	p.units[0].front = 1
	give(gs,"c17903")
	gs.current_player = 1
	gs.basic_attack(1,0)
	check(p.hand.size() == 1 and p.energy == 40, "white bone never responds to its own caster attacked")
func _ai() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	p.avatarHp = 20
	give(gs,"c17903"); give(gs,"c17304"); give(gs,"c17303")
	var selected := AI._best_card(gs,0)
	check(selected.ok and (selected.target == null or gs.valid_targets(0,gs.hand_card_def(0,selected.hand)).has(selected.target)), "AI uses authoritative target list")
	check(Rules.score_card(gs,0,Content.card_def("c17304"),gs.player(1).units[0].uid) < 0, "AI avoids gifting enemy healing window")
	for id in ["c17301","c17302","c17303","c17304","c17305","c17306","c17307","c17308","c17901","c17902","c17903","c17904","c17905","c17906","c17907","c17908"]:
		gs = fixture()
		gs.player(0).avatarHp = 20
		give(gs,id)
		var action := AI._best_card(gs,0)
		check(action.ok and action.card_id == id and gs.play_card(0,action.hand,action.target),"AI legally uses actual reviewed card " + id)
	for seed in 8:
		gs = GS.create(["jiuciliang","xixueji","qingfangzhu","fenghuanghuo"],["jiuciliang","xixueji","haifangzhu","yaodaoji"],20261015+seed)
		var steps := 0
		while gs.winner < 0 and steps < 180:
			AI.take_turn(gs,gs.action_player())
			steps += 1
		check(gs.winner >= 0 and steps < 180, "mixed AI completes without stalled choice seed%d" % seed)
