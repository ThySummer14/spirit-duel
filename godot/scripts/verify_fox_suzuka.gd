extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FOX_SUZUKA_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["yaohu","lingyuyuqian","fenghuanghuo","qingwa-ciqi"],["yaodaoji","yingcao","bingyong","guniao"],20261014)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		p.avatarHp = 1000
		for u in p.units: u.level = 3
	return gs
func give(gs: GS, id: String) -> int:
	gs.player(0).hand.append({"instanceId":"fox-suzuka-%d" % gs.next_card_id,"definitionId":id})
	gs.next_card_id += 1
	return gs.player(0).hand.size()-1
func played(gs: GS, id: String, target: Variant = null) -> bool:
	return gs.play_card(0,give(gs,id),target)
func hits(gs: GS, id: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == "fox-suzuka-hit" and e.card.id == id)
func suppress_enemy(gs: GS, except: int = -1) -> void:
	for i in gs.player(1).units.size():
		gs.player(1).units[i].hp = 1000 if i == except else 0
		gs.player(1).units[i].maxHp = 1000 if i == except else 4
		gs.player(1).units[i].passive_hooks = []
func _initialize() -> void:
	Content.load_content(true)
	var gs := fixture()
	var fox: Dictionary = gs.player(0).units[0]
	suppress_enemy(gs)
	gs.player(0).units[3].level = 0
	fox.awakened = true
	check(played(gs,"c13402"), "focus plays")
	check(fox.attack == 2 and int(fox.foxAbilityBonus) == 1, "focus preserves attack and increases only ability")
	check(hits(gs,"fox-ability").size() == 1 and hits(gs,"fox-ability")[0].amount == 3, "focus modifies awakening ability after its own resolution")
	check(played(gs,"c13401"), "blade plays")
	check(hits(gs,"c13401")[0].amount == 2, "focus never modifies spell damage")
	check(gs.player(1).avatarHp == 992, "two abilities and projectile damage preserve source identity")
	check(played(gs,"skin-yaohu-93152"), "skin focus same rules")
	check(int(fox.foxAbilityBonus) == 2 and gs.player(0).hand.is_empty(), "skin increments permanent ability without fabricated draw")
	gs._knockout_unit(fox,1,0)
	check(int(fox.foxAbilityBonus) == 2 and int(fox.foxDamageEvents) > 0, "ability and damage ledger survive knockout")
	gs = fixture()
	fox = gs.player(0).units[0]
	suppress_enemy(gs)
	fox.awakened = true
	check(played(gs,"c13403"), "fate form")
	check(fox.attack == 4 and fox.maxHp == 5 and gs.player(0).hand.is_empty(), "form exact base and no immediate blade")
	gs._begin_turn(0)
	check(gs.player(0).hand.any(func(c):return c.definitionId == "fengren"), "own turn generates actual blade")
	check(int(Content.card_def("fengren").cost) == 1 and Content.card_def("fengren").effect == "fox-projectile", "generated and constructed blade have same printed rule")
	gs = fixture()
	fox = gs.player(0).units[0]
	fox.awakened = true
	gs.player(0).units[3].level = 0
	for u in gs._all_units():
		u.maxHp = 1000
		u.hp = 1000
		u.passive_hooks = []
	check(played(gs,"c13407",gs.player(1).units[0].uid), "repeated slash accepts enemy")
	check(hits(gs,"c13407").size() == 2 and hits(gs,"fox-ability").size() == 2, "repeat is two actual spell uses and two ability triggers")
	check(gs.player(1).units[0].hp <= 996 and gs.player(0).energy == 39, "repeat charges fire once and damages twice")
	check(played(gs,"c13407",gs.player(0).units[2].uid), "repeat accepts friendly living unit")
	check(gs.player(0).units[2].hp == 996, "friendly target receives both spell hits")
	gs = fixture()
	fox = gs.player(0).units[0]
	gs.player(0).units[3].level = 0
	for u in gs._all_units():
		u.hp = 1000
		u.maxHp = 1000
		u.passive_hooks = []
	check(played(gs,"c13404"), "unbound plays")
	check(hits(gs,"c13404").size() == 10, "unbound stops at ten without deaths")
	check(hits(gs,"c13404").all(func(e): return e.target != fox.uid and not e.target.is_empty()), "unbound excludes source and both avatars")
	gs = fixture()
	fox = gs.player(0).units[0]
	for p in gs.players:
		for i in p.units.size():
			p.units[i].hp = 0 if not (p.id == gs.player(0).id and i == 0) else 4
	gs.player(1).units[0].hp = 1
	gs.player(1).units[0].passive_hooks = []
	check(played(gs,"c13404"), "unbound lethal")
	check(hits(gs,"c13404").size() == 1 and gs.player(1).units[0].hp == 0, "unbound stops at first KO")
	gs = fixture()
	fox = gs.player(0).units[0]
	gs.player(0).units[3].level = 0
	suppress_enemy(gs)
	fox.awakened = true
	fox.foxDamageEvents = 24
	check(played(gs,"c13405"), "storm below threshold")
	check(hits(gs,"c13405").size() == 5, "enhancement snapshots twenty-four before damage")
	check(int(fox.foxDamageEvents) == 30, "five packets plus ability add six damage events")
	check(played(gs,"c13405"), "enhanced storm")
	check(hits(gs,"c13405").size() == 15, "enhanced next storm adds ten independent random hits")
	gs.player(1).avatarArmor = 100
	var count := int(fox.foxDamageEvents)
	gs._damage_avatar(1,1,0,0)
	check(int(fox.foxDamageEvents) == count, "fully absorbed damage not recorded")
	gs.players = JSON.parse_string(JSON.stringify(gs.players))
	check(int(gs.player(0).units[0].foxDamageEvents) == count, "history survives JSON")
	gs = fixture()
	fox = gs.player(0).units[0]
	fox.awakened = true
	suppress_enemy(gs)
	check(played(gs,"c13408"), "love form")
	check(fox.attack == 5 and fox.maxHp == 8, "love exact5/8 with no spell bonus added to stats")
	check(played(gs,"c13401"), "love blade")
	check(hits(gs,"c13401")[0].amount == 3 and hits(gs,"fox-ability")[0].amount == 2, "hand aura adds spell damage but excludes triggered ability")
	gs.player(0).units[2].awakened = true
	check(played(gs,"c12401"), "allied phoenix spell under aura")
	check(gs.rule_events.any(func(e):return e.kind == "ability-trigger" and e.card.id == "phoenix-projectile" and int(e.card.effects[0].value) == 1), "phoenix ability is excluded from hand spell aura")
	check(hits(gs,"fox-ability").all(func(e): return int(e.amount) == 2), "allied spell never adds hand aura to fox ability")
	gs = fixture()
	suppress_enemy(gs)
	gs.player(0).units[0].awakened = true
	gs.player(0).units[3].level = 0
	check(gs.VerifiedRules.Light.roll(gs,0,4,6,3,true), "successful allied fortune")
	gs._resolve_resolution_stack()
	check(hits(gs,"fox-ability").size() == 1, "awake fox reacts once to actual successful judgment")
	check(not gs.VerifiedRules.Light.roll(gs,0,7,6,3), "failed fortune")
	gs._resolve_resolution_stack()
	check(hits(gs,"fox-ability").size() == 1, "failed fortune does not trigger awake fox")
	gs.player(0).units[0].hp = 0
	gs.VerifiedRules.Light.roll(gs,0,4,6,3,true)
	gs._resolve_resolution_stack()
	check(hits(gs,"fox-ability").size() == 1, "knocked fox cannot trigger on fortune")
	gs = fixture()
	suppress_enemy(gs)
	gs.player(0).units[0].awakened = true
	gs.player(0).units[3].level = 0
	check(played(gs,"c12408"), "legacy awakening is a spell use")
	check(hits(gs,"fox-ability").size() == 1, "legacy awakening triggers allied awakened fox")
	gs = fixture()
	gs.player(0).units[0].awakened = true
	gs.player(0).units[3].level = 0
	gs.player(1).units[0].hp = 100
	gs.player(1).units[0].maxHp = 100
	check(played(gs,"c13408"), "love before repeated slash")
	check(played(gs,"c13407",gs.player(1).units[0].uid), "repeat under aura")
	check(hits(gs,"c13407").size() == 2 and hits(gs,"c13407").all(func(e):return int(e.amount) == 3), "automatic repeat retains one quote and no aura duplication")
	gs = fixture()
	suppress_enemy(gs,0)
	gs.player(0).units[0].level = 0
	var suzuka: Dictionary = gs.player(0).units[1]
	var enemy: Dictionary = gs.player(1).units[0]
	check(played(gs,"c18004"), "bow plays")
	check(enemy.hp == 993 and enemy.armorBreak == 1, "each random point consumes prior break then adds one:1+2+2+2")
	check(hits(gs,"c18004").size() == 4, "four independent bow packets")
	check(played(gs,"c18005"), "modern suzuka awakening")
	check(suzuka.awakened and suzuka.maxHp == 5 and suzuka.attack == 3, "awakening exact0/1")
	check(gs.player(1).avatarHp == 999 and gs.player(1).avatarArmorBreak == 1, "post2020 awakening projection one and its own break")
	gs._damage_unit(1,0,8,0,1)
	check(enemy.armorBreak == 3, "awake damage caps break at3")
	enemy.shield = 100
	gs._damage_unit(1,0,1,0,1)
	check(enemy.armorBreak == 0, "fully shielded hit consumes previous break without creating new break")
	gs = fixture()
	suppress_enemy(gs)
	gs.player(0).units[3].formRules = {"alwaysSix":true}
	check(played(gs,"c13401"), "unawakened fox spell resolves real fortune")
	check(gs.kw_usage(0,"fortune").last.success and hits(gs,"fox-ability").size() == 1, "normal fox fortune success creates one ability")
	check(not gs.player(0).units[0].awakened, "fortune does not fake awakening")
	gs = fixture()
	suppress_enemy(gs,0)
	gs.player(0).units[0].level = 0
	gs.player(0).units[0].formRules = {"foxHandSpellBonus":1}
	check(played(gs,"c18004"), "inactive love aura not applied")
	check(hits(gs,"c18004").size() == 4, "inactive fox cannot enhance bow")
	gs = fixture()
	suppress_enemy(gs,0)
	gs.player(0).units[0].awakened = true
	check(played(gs,"c13408"), "love before random total damage")
	check(played(gs,"c18004"), "bow under active love")
	check(hits(gs,"c18004").size() == 5, "hand damage aura increases total randomized points, not packet size")
	check(hits(gs,"c18004").all(func(e):return int(e.amount) <= 2), "single bow packet remains one plus existing break")
	gs = fixture()
	gs.player(0).units[0].level = 0
	var index := give(gs,"c18001")
	check(gs.effective_card_cost(0,gs.hand_card_def(0,index)) == 1, "white normal printed cost")
	gs.player(1).units[2].armorBreak = 2
	check(gs.effective_card_cost(0,gs.hand_card_def(0,index)) == 0, "white instant with any enemy marked>=2")
	gs.player(1).units[2].hp = 0
	check(gs.effective_card_cost(0,gs.hand_card_def(0,index)) == 1, "white excludes knocked marked enemy")
	gs.player(1).avatarArmorBreak = 2
	check(gs.effective_card_cost(0,gs.hand_card_def(0,index)) == 0, "white counts avatar break")
	check(gs.play_card(0,index), "white actual attack")
	check(gs.player(0).units[1].shield == 1 and gs.player(0).energy == 40, "white armor plus team instant payment")
	index = give(gs,"c18001")
	check(gs.effective_card_cost(0,gs.hand_card_def(0,index)) == 1, "second enhanced instant consumes ordinary fire")
	gs = fixture()
	gs.player(0).units[0].level = 0
	check(played(gs,"c18002"), "boss form")
	suzuka = gs.player(0).units[1]
	gs.player(1).units[0].armorBreak = 1
	var hit := gs._damage_unit(0,1,3,1,0)
	check(int(hit.damage) == 0 and suzuka.hp == 5 and suzuka.shield == 0, "boss immune marked source all damage, no substitute shield")
	gs.player(1).units[0].armorBreak = 0
	hit = gs._damage_unit(0,1,1,1,0)
	check(int(hit.damage) == 1, "unmarked damage works")
	gs = fixture()
	gs.player(0).units[0].level = 0
	check(played(gs,"c18007"), "home form")
	check(gs.player(1).avatarHp == 1000, "home no entry damage")
	gs.player(1).units[0].front = 1
	gs.player(1).units[0].hp = 2
	gs.player(1).units[0].attack = 0
	gs.player(1).units[0].passive_hooks = []
	check(gs.basic_attack(0,1), "home attacks")
	check(gs.player(1).units[0].hp == 0 and gs.player(1).avatarHp == 996, "pre-attack projection kills front then actual attack retargets avatar")
	gs = fixture()
	gs.player(0).units[0].level = 0
	suzuka = gs.player(0).units[1]
	suzuka.awakened = true
	enemy = gs.player(1).units[0]
	enemy.front = 1
	enemy.hp = 20
	enemy.maxHp = 20
	enemy.attack = 0
	enemy.passive_hooks = []
	check(played(gs,"c18006",enemy.uid), "nowhere selects current front")
	check(enemy.hp == 13 and enemy.armorBreak == 3, "nowhere two spell then3+2break combat gives seven")
	check(suzuka.shield == 2, "nowhere only grants printed armor")
	gs = fixture()
	gs.player(0).units[0].level = 0
	enemy = gs.player(1).units[0]
	enemy.front = 1
	enemy.attack = 0
	enemy.hp = 20
	enemy.maxHp = 20
	enemy.passive_hooks = []
	enemy.armorBreak = 2
	check(played(gs,"c18008"), "justice combat")
	check(enemy.hp == 6 and enemy.armorBreak == 1, "justice marked first hit(2+2)*2 then(2+1)*2 =14")
	gs = fixture()
	gs.player(0).units[0].level = 0
	enemy = gs.player(1).units[0]
	enemy.front = 1
	enemy.attack = 0
	enemy.hp = 1
	enemy.passive_hooks = []
	check(played(gs,"c18008"), "justice pierce lethal combo")
	check(gs.player(1).avatarHp == 996, "pierce overflow plus second avatar strike includes break created between hits")
	gs = fixture()
	gs.player(0).units[0].level = 0
	gs.player(0).avatarHp = 20
	gs.player(0).units[1].attackBonus = 3
	gs._recalc(gs.player(0).units[1])
	check(played(gs,"c18003"), "light seven damage")
	check(gs.player(0).avatarHp == 23 and gs.player(0).hand.size() == 1, "light threshold draws and heals avatar floor half actual battle damage")
	gs = fixture()
	gs.player(0).units[0].level = 0
	check(played(gs,"c18003"), "light below six")
	check(gs.player(0).hand.is_empty(), "light below threshold no draw")
	gs = fixture()
	give(gs,"c13407")
	check(int(AI._score_card(gs,0,gs.hand_card_def(0,0),gs.player(0).units[1].uid)) < 0, "AI rejects harmful friendly slash")
	check(int(AI._score_card(gs,0,gs.hand_card_def(0,0),gs.player(1).units[1].uid)) > 0, "AI values legal enemy slash")
	print("FOX_SUZUKA checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
