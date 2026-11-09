extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
const R := preload("res://scripts/tomato_fire_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("TOMATO_FIRE_FAIL ", message)
func fixture(own: Array = ["tiaotiaomeimei","buzhinhuo","bailang","shantong"], enemy: Array = ["tiaotiaomeimei","buzhinhuo","yaodaoji","bingyong"]) -> GS:
	var gs := GS.create(own, enemy, 146167)
	gs.phase = "main"
	for p in gs.players:
		p.hand.clear()
		p.energy = 30
		p.levelUpUsed = true
		p.avatarArmor = 0
		p.attackUsed = false
		for u in p.units:
			u.level = 3
			u.front = 0
		gs.kw_usage(gs.players.find(p), "encourage").clear()
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "tf-%d" % gs.next_card_id,"definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs,id,owner),target), "play "+id)
func wall(gs: GS, owner: int = 1, idx: int = 3) -> Dictionary:
	var u: Dictionary = gs.player(owner).units[idx]
	u.front = 1
	u.baseMaxHp = 50
	u.hp = 50
	u.maxHp = 50
	u.baseAttack = 1
	gs._recalc(u)
	return u
func _initialize() -> void:
	_costs()
	_summons()
	_shared_summon_lifecycle()
	_tomato_cards()
	_guards()
	_encourage()
	_fire_forms()
	_burn()
	_swan()
	_variants()
	_linked_damage()
	_ai()
	print("TOMATO_FIRE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _costs() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	p.energy = 1
	check(not gs.can_basic_attack(0,0).ok,"sister base attack needs two fire")
	var h := give(gs,"c14601")
	check(gs.card_payment(0,gs.hand_card_def(0,h)).cost == 2,"sister combat quote includes extra cost")
	check(not gs.can_play_card(0,h).ok,"one fire cannot combat")
	p.energy = 2
	check(gs.play_card(0,h),"two fire combat legal")
	check(p.energy == 0 and p.units[0].attack == 3,"combat exact payment no fabricated growth")
	gs = fixture();p=gs.player(0)
	p.units[0].swift = true
	p.energy = 0
	check(not gs.can_basic_attack(0,0).ok,"swift doesn't waive negative extra cost")
	p.energy = 1
	check(gs.basic_attack(0,0),"swift attack still pays extra fire")
	check(p.energy == 0,"swift pays one exact extra")
	gs = fixture();p=gs.player(0)
	gs._knockout_unit(p.units[0])
	p.energy = 1
	h = give(gs,"c14606")
	check(not gs.can_play_card(0,h).ok,"knocked source still pays negative cost")
	p.energy = 2
	check(gs.play_card(0,h),"revive with two fire")
	check(p.units[0].hp == p.units[0].maxHp and p.units[0].knockout == 0 and p.energy == 0,"revive then attack quote")
	gs = fixture();p=gs.player(0)
	p.units[0].awakened = true
	p.energy = 1
	check(gs.basic_attack(0,0) and p.energy == 0,"awake removes base extra cost")
	gs = fixture();p=gs.player(0)
	p.units[0].frozen = 1
	h = give(gs,"c14601")
	check(not gs.can_play_card(0,h).ok and not gs.can_basic_attack(0,0).ok,"frozen source forbidden")
func _summons() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var foe := wall(gs)
	play(gs,"c14602")
	var t: Dictionary = gs.front_unit(0)
	check(t.tomatoEntity and t.summoned and t.hp == 3 and foe.hp == 46,"summon entity performs actual attack and receives counter")
	check(p.hand.is_empty() and not p.attackUsed and p.energy == 29,"summon doesn't create token hand or spend basic action")
	var first: String = t.uid
	play(gs,"c14603")
	t = gs.front_unit(0)
	check(t.uid != first and t.hp == 4 and t.attack == 5,"sit replaces residual, resets HP, grants one permanent power")
	check(p.units.filter(func(u):return u.get("tomatoEntity",false) and int(u.hp)>0).size() == 1,"unique tomato")
	check(p.energy == 28 and p.units[0].attack == 3 and p.units[0].maxHp == 6,"modern sit no optional extra fire nor sister gain")
	gs._knockout_unit(t)
	check(t.knockout == 0 and t.removed,"summon is removed not timed knockout")
	play(gs,"c14603")
	t = gs.front_unit(0)
	check(t.attack == 6 and t.hp == 4,"player ledger applied to new tomato")
	check(not gs.valid_targets(0,Content.card_def("c16702")).has(first),"removed tombstone not targetable")
	check(gs.basic_attack(0,p.units.size()-1),"tomato selectable basic action")
	check(p.attackUsed and p.energy == 26,"tomato basic attack pays one")
	p.attackUsed = false
	check(gs.basic_attack(0,2),"other shikigami attacks")
	check(t.hp == 0 and t.removed and t.knockout == 0,"other front replacement removes tomato")
	play(gs,"c14603")
	t=gs.front_unit(0)
	gs.VerifiedRules.move_unit(gs,0,t)
	check(t.removed and t.hp == 0,"moving summon off front removes it")
func _shared_summon_lifecycle() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var old: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs,0,2,"legacy-front","其他召唤物",2,4)
	play(gs,"c14603")
	check(gs.front_unit(0).get("tomatoEntity",false),"坐下 actually places Tomato in front")
	check(old.get("removed",false) and old.hp == 0 and old.knockout == 0,"Tomato removes a displaced native summon instead of leaving it in reserve")
	check(not gs.valid_targets(0,Content.card_def("c16702")).has(old.uid),"displaced native summon cannot be chosen from reserve")
	var removed: int = gs.rule_events.find_custom(func(e): return e.kind == "summon-removed" and e.uid == old.uid)
	var entered: int = gs.rule_events.find_custom(func(e): return e.kind == "summon-created" and e.uid == gs.front_unit(0).uid)
	check(removed >= 0 and entered > removed,"old summon leaves before Tomato's entry triggers inspect the board")
	old = gs.VerifiedRules.NativeSummons.summon(gs,0,2,"legacy-front","其他召唤物",2,4)
	play(gs,"c16705")
	check(gs.front_unit(0).get("burnEntity",false),"烬染不夜 actually places the summon in front")
	check(old.get("removed",false) and old.hp == 0 and p.units[2].hp > 0,"Burning Night removes the displaced summon without knocking out its summoner")
	removed = gs.rule_events.find_custom(func(e): return e.kind == "summon-removed" and e.uid == old.uid)
	entered = gs.rule_events.find_custom(func(e): return e.kind == "summon-created" and e.uid == gs.front_unit(0).uid)
	check(removed >= 0 and entered > removed,"old summon leaves before Burning Night's entry triggers inspect the board")
func _tomato_cards() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	play(gs,"c14607")
	play(gs,"c14607")
	check(p.tomatoSplash == 2 and gs.front_unit(0).tomatoSplash == 2,"out permanent triggered ability stacks, no attack gain")
	play(gs,"c14603")
	check(gs.front_unit(0).tomatoSplash == 2 and gs.front_unit(0).attack == 5,"summoned copy gets both ledgers")
	give(gs,"c14603")
	give(gs,"c16703")
	var unrelated: Dictionary = p.hand.back().duplicate()
	p.deck = [{"instanceId":"sister-deck","definitionId":"c14607"},{"instanceId":"foreign-deck","definitionId":"c16705"},{"instanceId":"combat-deck","definitionId":"c14604"}]
	var hand_size: int = p.hand.size()
	play(gs,"c14608")
	var u: Dictionary = p.units[0]
	check(u.awakened and u.tomatoEntity and u.attack == 7 and u.maxHp == 9,"awake +3/+3, player permanent power, real tomato identity")
	check(u.tomatoSplash == 2 and p.hand.size() == hand_size+2,"awake adds two actual combat cards")
	check(p.hand.all(func(e):return Content.card_def(e.definitionId).unitId != "tiaotiaomeimei" or Content.card_def(e.definitionId).type == "combat"),"all own noncombat hand transformed")
	check(p.deck[0].definitionId in R.COMBAT_CARDS and p.deck[1].definitionId == "c16705" and p.deck[2].definitionId == "c14604","all own noncombat deck transformed without foreign cards")
	check(p.hand.any(func(e):return e.instanceId == unrelated.instanceId and e.definitionId == unrelated.definitionId),"foreign hand instance unaffected")
	var target := wall(gs)
	var count := gs.rule_events.filter(func(e):return e.kind == "tomato-splash").size()
	play(gs,"c14604")
	check(target.hp == 36 and u.hp == 8,"combo two hits before ordinary counter, no fabricated bonus")
	check(gs.rule_events.filter(func(e):return e.kind == "tomato-splash").size() == count+4,"each of two hits triggers each stack")
	gs._knockout_unit(u)
	play(gs,"c14606")
	check(u.awakened and u.tomatoEntity and u.hp == u.maxHp and u.shield == 1,"revival preserves awakened tomato and combat +2 armor")
	check(u.tomatoSplash == 2 and u.attack == 7,"revival keeps permanent ledgers but not permanent combat bonus")
	gs = fixture();p=gs.player(0)
	play(gs,"c14607")
	target=wall(gs)
	target.barrier=true
	var t: Dictionary=gs.front_unit(0)
	count=gs.rule_events.filter(func(e):return e.kind=="tomato-splash").size()
	check(gs.basic_attack(0,p.units.size()-1),"blocked tomato attack")
	check(gs.rule_events.filter(func(e):return e.kind=="tomato-splash").size()==count,"fully blocked attack causes no splash")
func _guards() -> void:
	for mode in 5:
		var gs:=fixture()
		var sister: Dictionary=gs.player(1).units[0]
		sister.front=1
		give(gs,"c14605",1)
		if mode == 1: sister.frozen=1
		if mode == 2:
			gs.kw_usage(1,"instant").used=true
			gs.player(1).energy=0
		if mode == 3: gs.player(1).nullifyNextCardTurn=gs.turn_counter
		var hp:=int(sister.hp)
		if mode == 4: gs.player(1).units[1].front=1;sister.front=0
		check(gs.basic_attack(0,2),"enemy attack with guard mode%d"%mode)
		var responders: Array=gs.rule_events.filter(func(e):return e.kind=="response-card" and e.card.id=="c14605")
		if mode == 0:
			check(sister.hp==hp and gs.player(1).hand.is_empty(),"source attacked response protects source")
			check(gs.rule_events.any(func(e):return e.kind=="tomato-guard"),"guard redirects continued combat to spawned tomato")
		elif mode in [1,2]: check(responders.is_empty() and gs.player(1).hand.size()==1,"inactive/no-fire no response")
		elif mode == 3: check(not responders.is_empty() and not gs.rule_events.any(func(e):return e.kind=="summon-created") and sister.hp<hp,"nullified response consumes card but fails guard")
		else: check(responders.is_empty() and sister.hp==hp,"other source attacked doesn't trigger")
func _encourage() -> void:
	var gs:=fixture()
	var p: Dictionary=gs.player(0)
	R.turn_start(gs,0)
	check(gs.kw_usage(0,"encourage").attack==1 and p.units[1].attack==2,"fire base creates player encourage, not growth")
	check(gs.kw_usage(1,"encourage").get("attack",0)==0,"base only owner turn")
	play(gs,"c16703")
	check(p.energy==30 and gs.kw_usage(0,"encourage").attack==2 and gs.kw_usage(0,"encourage").shield==1,"truth first instant no fire, encourage always")
	p.attackUsed=true
	play(gs,"c16703")
	check(not p.attackUsed and p.energy==29,"truth resets basic count and second instant pays one")
	play(gs,"c16708")
	check(p.units[1].attack==3 and p.units[1].maxHp==5,"awake printed +1/+1")
	check(gs.kw_usage(0,"encourage").traits.has("pierce"),"2023 awake adds this-turn encourage pierce")
	gs._apply_encourage(0,2,3)
	check(gs.kw_usage(0,"encourage").attack==6 and gs.kw_usage(0,"encourage").shield==6,"awake amplifies later encouragement once per effect")
	var u: Dictionary=p.units[1]
	gs._knockout_unit(u)
	gs._apply_encourage(0,2,3)
	check(gs.kw_usage(0,"encourage").attack==8 and gs.kw_usage(0,"encourage").shield==9,"knockout disables amplify")
	R.end_turn(gs)
	check(not gs.kw_usage(0,"encourage").traits.has("pierce"),"this-turn encouragement expires even unused")
	gs=fixture();p=gs.player(0)
	play(gs,"c16702",p.units[2].uid)
	check(p.units[2].swift and gs.kw_usage(0,"encourage").attack==2,"freedom actual chosen ally gets swift and latest +2/+2")
	R.end_turn(gs)
	check(not p.units[2].swift,"freedom swift ends this turn")
	gs=fixture();p=gs.player(0)
	give(gs,"c16702")
	check(not gs.can_play_card(0,0,"avatar-0").ok and not gs.can_play_card(0,0,gs.player(1).units[0].uid).ok,"freedom no avatar/enemy targets")
func _fire_forms() -> void:
	var gs:=fixture();var p: Dictionary=gs.player(0)
	play(gs,"c16701")
	check(p.units[1].attack==4 and p.units[1].maxHp==5,"first form sets4/5")
	gs._apply_encourage(0,2,3)
	var hp:=int(gs.player(1).avatarHp)
	play(gs,"c14601")
	check(gs.player(1).avatarHp==hp-8 and p.units[0].shield==3,"不夜 applies encourage to combat card")
	check(gs.kw_usage(0,"encourage").attack==0,"combat consumes encourage under不夜")
	gs=fixture();p=gs.player(0)
	gs._apply_encourage(0,2,3)
	play(gs,"c14601")
	check(gs.kw_usage(0,"encourage").attack==2 and p.units[0].shield==0,"combat doesn't consume or receive encourage without不夜")
	play(gs,"c16706")
	check(p.units[1].attack==5 and p.units[1].maxHp==5,"离殇 sets5/5")
	var held:=gs.kw_usage(0,"encourage").duplicate(true)
	check(gs.basic_attack(0,3),"basic consumes action under retain")
	check(gs.kw_usage(0,"encourage").attack==held.attack and gs.kw_usage(0,"encourage").shield==held.shield,"离殇 retains encourage")
	gs._knockout_unit(p.units[1]);p.attackUsed=false
	check(gs.basic_attack(0,2),"basic after retain source knocked")
	check(gs.kw_usage(0,"encourage").attack==0,"knockout disables continuous retain")
	gs=fixture();p=gs.player(0)
	play(gs,"c16704")
	check(p.units[1].attack==2 and p.units[1].maxHp==6 and gs.VerifiedRules.Combat.has(p.units[1],"remote"),"初会 sets2/6 remote")
	var n: int = p.hand.size()
	check(gs.basic_attack(0,1),"remote basic")
	check(p.hand.size()==n+1 and p.units[1].front==0,"basic face damage draw and remote stays reserve")
	p.attackUsed=false
	n=p.hand.size()
	play(gs,"c14601")
	check(p.hand.size()==n,"combat face damage never causes initial form draw")
	gs=fixture();p=gs.player(0)
	play(gs,"c16704");var target:=wall(gs);target.hp=1
	p.units[3].baseAttack=4;gs._recalc(p.units[3])
	n=p.hand.size()
	check(gs.basic_attack(0,3),"shantong basic pierce")
	check(p.hand.size()==n+1,"basic pierce avatar damage also draws")
	gs=fixture();p=gs.player(0)
	play(gs,"c16704");gs.player(1).avatarArmor=100
	n=p.hand.size()
	check(gs.basic_attack(0,1) and p.hand.size()==n,"fully armored avatar damage doesn't draw")
func _burn() -> void:
	var gs:=fixture();var p: Dictionary=gs.player(0)
	play(gs,"c16705")
	var u: Dictionary=gs.front_unit(0)
	check(u.burnEntity and u.attack==2 and u.hp==2 and u.swift,"latest burn2/2 swift entity")
	check(p.hand.is_empty() and p.energy==29,"spark no fabricated AOE or token hand")
	gs._apply_encourage(0,3,4)
	var idx: int = p.units.size()-1
	var fire: int = int(p.energy)
	check(gs.basic_attack(0,idx),"burn basic command")
	var hits:=gs.rule_events.filter(func(e):return e.kind=="burn-random-hit")
	check(hits.size()==2 and hits[0].target!=hits[1].target,"two actual randomly addressed characters")
	check(hits.all(func(e):return e.amount==5),"both damage events include encourage")
	check(p.energy==fire and p.attackUsed and u.shield==4,"burn swift costs0, action consumed, encourage armor")
	check(u.hp==2,"random attack avoids normal counter")
	check(gs.kw_usage(0,"encourage").attack==0,"burn consumes encourage once")
	gs._knockout_unit(u)
	check(u.removed and u.knockout==0,"burn removed with no revive timer")
	gs=fixture();p=gs.player(0)
	play(gs,"c16705");play(gs,"c16704")
	u=gs.front_unit(0)
	for e in gs.player(1).units: e.hp=0;e.knockout=2
	var n: int = p.hand.size()
	check(gs.basic_attack(0,p.units.size()-1),"burn when only avatar remains")
	check(gs.player(1).avatarHp==28 and p.hand.size()==n+1,"one remaining unique avatar gets one event and initial draws")
func _swan() -> void:
	for result in 19:
		var gs:=fixture();var p: Dictionary=gs.player(0)
		play(gs,"c16707")
		check(p.units[1].attack==7 and p.units[1].maxHp==7,"swan7/7")
		var t:=wall(gs)
		p.units[2].front=1
		if result==1: gs._knockout_unit(p.units[2])
		if result==4:p.avatarHp=10
		var before: Dictionary=gs.snapshot()
		R.swan(gs,0,1,result)
		check(gs.rule_events.any(func(e):return e.kind=="swan-effect" and e.result==result),"swan19 effect recorded%d"%result)
		match result:
			0: check(p.units[2].unyielding and gs.VerifiedRules.Combat.has(p.units[2],"curtain"),"temporary curtain and unyielding")
			1: check(p.units[2].hp>0 and p.units[2].knockout==0,"all knocked own revived")
			2: check(gs.player(1).avatarHp==26,"face4")
			3: check(t.hp==45,"projectile5 front")
			4: check(p.avatarHp==16,"heal6")
			5: check(t.hp==48 and gs.player(1).units[0].hp==4,"all enemy damage2")
			6: check(gs.kw_usage(0,"encourage").attack==2 and gs.kw_usage(0,"encourage").traits.size()==1,"encourage2 plus random combat trait")
			7: check(p.units[2].attack==4 and p.units[2].shield==1,"all own1/1/1")
			8: check(p.units[2].attack==5 and p.units[2].shield==2,"front2/2/2")
			9: check(p.units.filter(func(u):return u.attackBonus==1).size()==2,"two different permanent1/1")
			10:check(p.hand.size()==1,"draw1")
			11:check(p.energy==30,"gain1 fire after cost")
			12:check(gs.front_unit(0).get("burnEntity",false),"summon burn")
			13:check(t.armorBreak==3 and gs.player(1).units[0].armorBreak==3,"all enemy break3")
			14:check(gs.player(1).units.filter(func(u):return u.frozen>0).size()==1,"highest power stun selects one even ties")
			15:check(p.units[1].attack==9 and gs.VerifiedRules.Combat.has(p.units[1],"pierce"),"highest own power plus2 pierce")
			16:check(p.units.all(func(u):return u.swift),"all own swift")
			17:check(t.attack==-1 and gs.player(1).units[0].attack==1,"all enemy minus2")
			18:check(p.avatarArmor==8,"avatar armor8")
		R.end_turn(gs)
		if result==0: check(not p.units[2].unyielding and not gs.VerifiedRules.Combat.has(p.units[2],"curtain"),"one-turn protection expires")
		if result==9: check(p.units.filter(func(u):return u.attackBonus==1).size()==2,"permanent random bonuses survive boundary")
		if result==17: check(t.attack==1,"pending temporary debuff current implementation expires")
	var gs:=fixture()
	play(gs,"c16707")
	R.turn_start(gs,1)
	check(gs.rule_events.any(func(e):return e.kind=="swan-effect" and e.player==0),"swan triggers opponent turn")
	gs._knockout_unit(gs.player(0).units[1])
	var n:=gs.rule_events.filter(func(e):return e.kind=="swan-effect").size()
	R.turn_start(gs,0)
	check(gs.rule_events.filter(func(e):return e.kind=="swan-effect").size()==n,"inactive swan doesn't trigger")
func _variants() -> void:
	var gs:=fixture(["buzhinhuo","buzhinhuo","buzhinhuo","buzhinhuo"])
	for u in gs.player(0).units:u.awakened=true
	gs._apply_encourage(0,1,0)
	check(gs.kw_usage(0,"encourage").attack==5 and gs.kw_usage(0,"encourage").shield==4,"four active awakening modifiers")
	gs.kw_usage(0,"encourage").clear()
	R.turn_start(gs,0)
	check(gs.kw_usage(0,"encourage").attack==20 and gs.kw_usage(0,"encourage").shield==16,"four separate turn abilities with four modifiers each")
	gs=fixture(["tiaotiaomeimei","tiaotiaomeimei","tiaotiaomeimei","tiaotiaomeimei"])
	R.resolve_action(gs,0,2,Content.card_def("c14603"),{"action":"tomato-sit"},{},null)
	R.awaken_tomato(gs,0,1)
	check(gs.player(0).units[1].attack==7 and gs.player(0).units[0].attack==3,"ledger attaches transformed source only")
	check(gs.player(0).units.filter(func(u):return u.get("tomatoFireSummon",false) and u.hp>0).size()==1,"same role variants share unique front summoned entity")
func _linked_damage() -> void:
	# Official initial-dance guide: basic projectile/passive damage events draw.
	var gs:=fixture()
	play(gs,"c16704")
	var p: Dictionary=gs.player(0)
	var target:=wall(gs)
	var n: int=p.hand.size()
	check(gs.basic_attack(0,2),"white wolf basic command into front")
	check(target.hp==47 and p.hand.size()==n+1,"white wolf basic passive avatar damage draws before front combat ends")
	gs=fixture(["tiaotiaomeimei","buzhinhuo","yatiangou","shantong"])
	play(gs,"c16704")
	p=gs.player(0)
	n=p.hand.size()
	check(gs.basic_attack(0,2),"crow basic projectile into open face")
	check(p.hand.size()==n+2,"crow projectile and basic face are two initial-dance damage events")
	gs=fixture()
	play(gs,"c14607")
	var t: Dictionary=gs.front_unit(0)
	gs.VerifiedRules.Fortune.transform(gs,0,gs.player(0).units.size()-1,true)
	check(not R.tomato(t),"paper suppresses tomato triggered ability")
	gs=fixture()
	play(gs,"c16705")
	t=gs.front_unit(0)
	gs.VerifiedRules.Fortune.transform(gs,0,gs.player(0).units.size()-1,true)
	check(not R.burn(t),"paper suppresses random burn replacement")
	check(gs.basic_attack(0,gs.player(0).units.size()-1),"small paper basic attack legal")
	check(not gs.rule_events.any(func(e):return e.kind=="burn-random-hit"),"transformed burn performs ordinary attack only")
func _ai() -> void:
	var gs:=fixture()
	for id in ["c14601","c14602","c14603","c14604","c14605","c14606","c14607","c14608","c16701","c16702","c16703","c16704","c16705","c16706","c16707","c16708"]:
		gs.player(0).hand.clear()
		var h:=give(gs,id)
		var c:=gs.hand_card_def(0,h)
		var targets: Array=[null] if c.target=="auto" else gs.valid_targets(0,c)
		check(not targets.is_empty(),"AI targets "+id)
		for target in targets:
			check(gs.can_play_card(0,h,target).ok,"AI legal "+id)
			check(R.score_card(gs,0,c,target)!=null,"AI native score "+id)
	gs=fixture();gs.player(0).energy=1;give(gs,"c14601")
	check(not AI._best_card(gs,0).ok,"AI respects sister extra fire")
	for lineup in [["tiaotiaomeimei","buzhinhuo","bailang","shantong"],["tiaotiaomeimei","tiaotiaomeimei","tiaotiaomeimei","tiaotiaomeimei"],["buzhinhuo","buzhinhuo","buzhinhuo","buzhinhuo"],["fanqie","jinran-buye","buzhinhuo","tiaotiaomeimei"]]:
		gs=GS.create(lineup,lineup,20261014)
		for turn in 100:
			if gs.winner>=0:break
			check(AI.take_turn(gs,gs.current_player) is Array,"AI turn stable")
		check(gs.winner>=0,"AI match terminates for variants "+str(lineup))
