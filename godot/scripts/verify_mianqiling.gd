extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Mian := preload("res://scripts/mianqiling_rules.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("MIANQILING_FAIL ",detail)

func hover_unit(face: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
	root.push_input(motion,true)
	await process_frame
	await create_timer(0.25).timeout

func game(own: Array = ["mianqiling","rihefang","rurineque","taohuayao"], enemy: Array = ["bingyong","fenghuanghuo","yaodaoji","baizangzhu"]) -> GS:
	var gs := GS.create(own,enemy,208)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.rule_events.clear(); return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"mian-test-%d" % gs.next_card_id})
	gs.next_card_id += 1; return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	var h := give(gs,id,owner)
	var legal: Dictionary = gs.can_play_card(owner,h,target)
	check(gs.play_card(owner,h,target),"actual use " + id + " " + str(legal.get("reason","")))

func choose(gs, faction: String, owner: int = 0) -> void:
	check(gs.resolve_divination_choice(owner,faction),"actual faction choice " + faction)

func change(gs, faction: String, target = null) -> void:
	play(gs,"c20801",gs.player(0).units[0].uid if target == null else target)
	choose(gs,faction)

func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)

func factions_and_cards() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	check(u.attack == 2 and u.maxHp == 5 and u.passive_hooks.is_empty(),"original2/5 has no old gain or draw passive")
	check(Factions.printed(u) == "青岚" and Factions.printed(p.units[1]) == "红莲" and Factions.printed(p.units[2]) == "紫岩","printed independent four-faction identities")
	var known: Dictionary = Factions.data().units
	var unverified: Dictionary = Factions.data().unverified
	check(Content.playable_units().all(func(definition):
		var id := str(definition.id)
		return known.has(id) != unverified.has(id) and (not known.has(id) or Factions.printed(definition) in Factions.VALUES)),
		"每位可选式神均有唯一的已核派系或明确待核条目")
	check(not Factions.known({"id":"ember"}) and not Factions.same({"id":"ember"},{"id":"ember"}) and not Factions.different({"id":"ember"},u),"unknown identities never become guessed factions")
	check(not Factions.known({"id":"mianqiling","susanooOriginal":u.duplicate(true)}),"unverified replacement tomb does not borrow the original unit's faction")
	for n in range(20801,20809):
		var c := Content.card_def("c%d" % n)
		check(c.get("verifiedRules",false) and c.get("mianqilingRules",false) and c.cost == 1,"eight actual card rules " + c.id)
		check(FileAccess.file_exists("res://assets/official/cards/" + c.id + ".png") and not c.get("verificationPending",[]).is_empty(),"original art and explicit unresolved boundaries " + c.id)
	check(not Content.card_def("c20802").get("autoResponse",false) and Content.card_def("c20802").get("responseModifiesCombat","") == "","seven faces does not invent a defense response")
	check(Factions.distinct(p.units).size() == 3 and Factions.distinct(gs._all_units()).size() == 4,"counts unique living factions, not unit count")
	var fake := u.duplicate(true); fake.uid = "mian-summon"; fake.summoned = true; fake.factionOverride = "苍叶"; p.units.append(fake)
	check(Factions.distinct(p.units).size() == 3,"nonshikigami summon is not an extra faction")
	fake.countsAsShikigami = true; check(Factions.distinct(p.units).size() == 4,"genuine summoned shikigami participates")
	fake.hp = 0; check(Factions.distinct(p.units).size() == 3,"knocked shikigami excluded")

func faction_choices() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	var h := give(gs,"c20801"); foe.units[1].keywords = ["veil"]
	var legal := gs.valid_targets(0,gs.hand_card_def(0,h))
	check(legal.has(u.uid) and legal.has(foe.units[0].uid) and not legal.has(foe.units[1].uid) and not legal.has("avatar-1"),"new faces targets any actual shikigami and excludes hostile veil/avatar")
	check(not gs.play_card(0,h,foe.units[1].uid) and p.energy == 40,"veil illegal use rejects before fire or hand loss")
	var deck_size: int = p.deck.size()
	check(gs.play_card(0,h,foe.units[0].uid) and gs.phase == "choice" and gs.pending_choice.type == "mian-faction","actual target opens explicit faction choice")
	check(p.hand.is_empty() and p.energy == 40 and p.deck.size() == deck_size,"first instant faction spell has no fabricated draw")
	check(not gs.resolve_divination_choice(1,"苍叶") and not gs.resolve_divination_choice(0,"invented"),"foreign and invented faction choice cannot commit")
	check(gs.pending_choice.instanceIds.size() == 4 and Mian.choice_card(gs,0,"苍叶").name == "苍叶","choice exposes all four named identities")
	choose(gs,"苍叶"); check(Factions.get_faction(foe.units[0]) == "苍叶" and gs.pending_choice.is_empty() and gs.phase == "main","selected faction applies to the actual enemy and resumes")
	gs._knockout_unit(foe.units[0],0,0); gs._resolve_resolution_stack()
	check(Factions.get_faction(foe.units[0]) == "紫岩" and not foe.units[0].has("factionOverride"),"normal faction change expires exactly on knockout")
	gs = game(); u = gs.player(0).units[0]
	play(gs,"c20803"); check(u.attack == 3 and u.maxHp == 6 and gs.pending_choice.type == "mian-faction","illusion installs exact3/6 and then asks faction")
	choose(gs,"红莲"); check(Factions.get_faction(u) == "红莲","illusion uses actual player selected faction")
	play(gs,"c20807"); check(not u.awakened,"awakening pauses before irreversible faction choice and awakening")
	choose(gs,"紫岩"); check(u.awakened and u.attack == 5 and u.maxHp == 8 and Factions.get_faction(u) == "紫岩" and u.factionPermanent == "紫岩","awakening grants exact2/2 and permanent chosen faction")
	check(not gs.can_play_card(0,give(gs,"c20807")).ok,"already awakened cannot use second awakening")
	change(gs,"苍叶"); check(Factions.get_faction(u) == "苍叶","normal change can temporarily supersede permanent faction")
	gs._knockout_unit(u,1,0); gs._resolve_resolution_stack()
	check(Factions.get_faction(u) == "紫岩" and u.factionPermanent == "紫岩","KO restores chosen permanent faction, not printed blue")

func passive_damage() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]; var target: Dictionary = foe.units[0]
	gs._grow_unit(target,0,30); var hp: int = target.hp
	var hit := gs._damage_unit(1,0,2,0,0)
	check(hit.dealt == 3 and target.hp == hp-3,"different-faction actual spell damage gains1")
	change(gs,"紫岩"); hp = target.hp; hit = gs._damage_unit(1,0,2,0,0)
	check(hit.dealt == 2 and target.hp == hp-2,"same-faction output has no bonus")
	var before: int = u.hp; hit = gs._damage_unit(0,0,2,1,0)
	check(hit.dealt == 1 and u.hp == before-1,"same-faction incoming damage reduced by1")
	foe.units[1].factionOverride = "青岚"; before = u.hp; hit = gs._damage_unit(0,0,1,1,1)
	check(hit.dealt == 1 and u.hp == before-1,"different incoming has no reduction")
	gs = game(); u = gs.player(0).units[0]; target = gs.player(1).units[0]; gs._grow_unit(target,0,30)
	target.shield = 2; hp = target.hp; hit = gs._damage_unit(1,0,3,0,0,false,-1,false,true)
	check(hit.dealt == 3 and target.hp == hp-3 and target.shield == 0,"armor then critical then faction: (3-2)*2+1")
	target.shield = 99; hp = target.hp; hit = gs._damage_unit(1,0,3,0,0)
	check(hit.dealt == 1 and target.hp == hp-1 and target.shield == 96,"passive adds1 after armor has reduced underlying damage to0")
	target.barrier = true; hp = target.hp; hit = gs._damage_unit(1,0,0,0,0)
	check(hit.damage == 0 and target.hp == hp and not target.barrier,"raw zero different-faction damage can break barrier through true passive")
	target.shield = 0; hp = target.hp; hit = gs.VerifiedRules.Combat.strike(gs,0,0,1,0,0,{})
	check(hit.dealt == 1 and target.hp == hp-1,"zero combat power goes through passive instead of early cancellation")
	target.shield = 4; target.barrier = true; hp = target.hp
	hit = gs._damage_unit(1,0,-1,0,0)
	check(hit.get("dealt",0) == 0 and target.hp == hp and target.shield == 4 and target.barrier,"negative spell damage remains invalid and cannot gain armor through the zero channel")
	target.shield = 4; target.barrier = true; hp = target.hp
	hit = gs.VerifiedRules.Combat.strike(gs,0,0,1,0,-1,{})
	check(hit.get("dealt",0) == 0 and target.hp == hp and target.shield == 4 and target.barrier,"negative combat power remains invalid and cannot consume armor or barrier")
	target.shield = 0
	gs.player(0).units[1].attack = 0; target.barrier = true; hp = target.hp
	hit = gs.VerifiedRules.Combat.strike(gs,0,1,1,0,0,{})
	check(hit.dealt == 0 and target.hp == hp and target.barrier,"ordinary zero power cannot invent damage or consume barrier")
	for status in ["suppressed","unleveled","removed"]:
		gs = game(); u = gs.player(0).units[0]; target = gs.player(1).units[0]; hp = target.hp
		if status == "suppressed": u.baseRulesSuppressed = true
		elif status == "unleveled": u.level = 0
		else: u.removed = true
		hit = gs._damage_unit(1,0,1,0,0)
		check(hit.dealt == 1 and target.hp == hp-1,"inactive damage source does not apply faction passive " + status)
	gs = game(); u = gs.player(0).units[0]; u.frozen = 1
	hit = gs._damage_unit(1,0,1,0,0); check(hit.dealt == 2,"stun does not suppress ordinary passive")
	var avatar_hp: int = gs.player(1).avatarHp; gs._damage_avatar(1,2,0,0)
	check(gs.player(1).avatarHp == avatar_hp-2,"faction passive never adds damage to avatar")
	gs = game(); u = gs.player(0).units[0]; target = gs.player(1).units[0]; gs._grow_unit(target,0,30)
	play(gs,"c20807"); choose(gs,"紫岩"); u.shield = 1; before = u.hp
	hit = gs._damage_unit(0,0,5,1,0); check(hit.dealt == 2 and u.hp == before-2,"awakened same-faction even residual damage halves after armor")
	change(gs,"青岚"); target.shield = 1; hp = target.hp; hit = gs._damage_unit(1,0,4,0,0,false,-1,false,true)
	check(hit.dealt == 12 and target.hp == hp-12,"awakened different damage doubles after armor and critical")
	gs = game(["mianqiling","rihefang","rurineque","taohuayao"],["mianqiling","fenghuanghuo","yaodaoji","baizangzhu"])
	u = gs.player(0).units[0]; target = gs.player(1).units[0]; target.factionOverride = "红莲"; target.hp = 1; target.front = 1
	check(gs.basic_attack(0,0),"real simultaneous exchange kills enemy face")
	check(target.hp == 0 and u.hp == 2 and not target.has("factionOverride"),"dead counterstrike retains pre-exchange faction/passive despite KO clearing override")

func seven_faces() -> void:
	var gs := game(); var u: Dictionary = gs.player(0).units[0]; var foe: Dictionary = gs.player(1); var target: Dictionary = foe.units[0]
	change(gs,"紫岩"); gs._grow_unit(target,0,20); target.attack = 0; target.front = 1
	play(gs,"c20802"); check(target.hp == 0 and events(gs,"mian-seven-faces")[0].lethal,"same actual combat faction grants lethal despite large enemy health")
	gs = game(); u = gs.player(0).units[0]; target = gs.player(1).units[0]
	gs._grow_unit(target,20,20); target.front = 1; var hp: int = target.hp
	play(gs,"c20802"); check(u.hp == 1 and target.hp == hp-4,"different faction gets unyielding and printed+1 attack plus passive, not immunity")
	check(not u.get("combatUnyielding",false),"temporary seven-faces unyielding ends with battle")
	gs._damage_unit(0,0,1,1,0); check(u.hp == 0,"seven faces cannot prevent next unrelated lethal damage")
	gs = game(); u = gs.player(0).units[0]; target = gs.player(1).units[0]
	change(gs,"紫岩"); gs._grow_unit(target,0,20); target.front = 1; target.shield = 99; var before: int = target.hp
	play(gs,"c20802"); check(target.hp == before,"same-faction lethal requires positive actual damage")
	gs = game(); u = gs.player(0).units[0]; u.hp = 1; target = gs.player(1).units[0]; target.front = 1; gs._grow_unit(target,20,20)
	play(gs,"c20802"); check(u.hp == 0,"unyielding at1hp does not save")
	gs = game(); play(gs,"c20802"); check(gs.player(1).avatarHp == 27,"avatar has no faction and receives only printed3 combat power")

func self_deceit_and_draw() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var target: Dictionary = foe.units[0]
	gs._grow_unit(target,0,20); var hp: int = target.hp; var h := give(gs,"c20804")
	check(gs.hand_card_def(0,h).currentCardStats.contains("当前伤害6"),"four actual live factions preview6, not8")
	check(gs.play_card(0,h,target.uid) and target.hp == hp-7,"self deceit uses fourfactions+2 plus actual different-faction passive")
	gs = game(); target = gs.player(1).units[0]; gs._grow_unit(target,0,20)
	for body in gs._all_units(): body.factionOverride = "青岚"
	hp = target.hp; play(gs,"c20804",target.uid); check(target.hp == hp-3,"one living faction uses1+2 without output bonus")
	gs = game(); p = gs.player(0); var deck_size: int = p.deck.size()
	play(gs,"c20805"); check(p.hand.size() == 3 and p.deck.size() == deck_size-3,"forbidden face draws one actual card per own live faction")
	gs = game(); p = gs.player(0); p.units[2].hp = 0; deck_size = p.deck.size()
	play(gs,"c20805"); check(p.hand.size() == 2 and p.deck.size() == deck_size-2,"knocked own only-faction unit no longer supplies draw")

func wheel_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); var u: Dictionary = p.units[0]
	for target in foe.units: gs._grow_unit(target,0,10)
	play(gs,"c20806"); check(u.attack == 5 and u.maxHp == 5 and Factions.get_faction(u) == "青岚" and gs.VerifiedRules.Combat.has(u,"veil"),"5/5 wheel installs existing blue veil without changing faction or immediate trigger")
	check(events(gs,"mian-reincarnation").is_empty(),"wheel deployment alone does not fabricate colorchange trigger")
	var powers: Array = p.units.map(func(v): return int(v.attack))
	change(gs,"红莲"); check(gs.VerifiedRules.Combat.has(u,"pierce") and not gs.VerifiedRules.Combat.has(u,"veil"),"red state replaces dynamic veil with pierce")
	for i in p.units.size(): check(p.units[i].attack == powers[i]+1 and p.units[i].mianRedGrowth == 1,"red trigger grows all living friendly shikigami %d" % i)
	var count: int = events(gs,"mian-reincarnation").size(); change(gs,"红莲")
	check(events(gs,"mian-reincarnation").size() == count and u.attack == 6,"setting already current faction does not retrigger change effect")
	u.hp = 1; p.avatarHp = 20; change(gs,"紫岩")
	check(u.hp == 4 and p.avatarHp == 23 and Mian.unyielding(u),"purple real change heals self and avatar3 and gives unyielding")
	gs._damage_unit(0,0,20,1,1); check(u.hp == 1 and not Mian.unyielding(u),"purple unyielding saves one hit and is consumed")
	var before_total := 0
	for target in foe.units: before_total += int(target.hp)
	change(gs,"苍叶"); var after_total := 0
	for target in foe.units: after_total += int(target.hp)
	check(before_total-after_total in [2,3] and Mian.swift(u),"green trigger damages exactly one random enemy for2 plus legal faction passive")
	var fire: int = p.energy; var avatar: int = foe.avatarHp
	check(gs.basic_attack(0,0) and p.energy == fire and foe.avatarHp == avatar-6 and not Mian.swift(u),"green swift is actually free once and preserves printed attack")
	var hps: Array = foe.units.map(func(v): return int(v.hp)); change(gs,"青岚")
	for i in foe.units.size(): check(foe.units[i].hp == hps[i]-(1 if Factions.get_faction(foe.units[i]) == "青岚" else 2),"blue change damages all enemy shikigami without hitting avatar %d" % i)
	check(foe.avatarHp == avatar-6 and gs.VerifiedRules.Combat.has(u,"veil"),"blue effect excludes avatar and restores only its own veil")
	count = events(gs,"mian-reincarnation").size()
	check(gs.end_turn(0) and gs.end_turn(1),"real full turn cycle triggers wheel")
	check(Factions.get_faction(u) != "青岚" and events(gs,"mian-reincarnation").size() == count+1,"own turn start randomly chooses another faction exactly once")
	gs = game(); u = gs.player(0).units[0]; play(gs,"c20806"); change(gs,"红莲")
	var target: Dictionary = gs.player(1).units[0]; target.hp = 2; target.attack = 0; target.shield = 1; target.front = 1
	var face: int = gs.player(1).avatarHp; check(gs.basic_attack(0,0),"red actual pierce attacks guarded unit")
	check(target.hp == 0 and gs.player(1).avatarHp == face-4,"pierce follows6power minus1armor plus1different-faction bonus minus2hp")
	gs = game(); u = gs.player(0).units[0]; play(gs,"c20806"); change(gs,"红莲"); target = gs.player(1).units[0]
	target.hp = 2; target.attack = 0; target.shield = 1; target.front = 1; u.keywords = ["crit"]; face = gs.player(1).avatarHp
	check(gs.basic_attack(0,0),"red actual critical pierce")
	check(gs.player(1).avatarHp == face-9,"pierce computes armor then crit then +1, matching HP damage")

func reset_growth() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	play(gs,"c20806"); change(gs,"红莲"); play(gs,"c16606",u.uid)
	check(u.attack == 5 and not u.has("mianRedGrowth") and Factions.get_faction(u) == "红莲","actual sunlight reset removes red stat growth but keeps faction and form ability")
	gs._knockout_unit(u,1,0); gs._resolve_resolution_stack(); check(u.attack == 2,"knockout after sunlight does not subtract cleared red ledger again")
	gs = game(); p = gs.player(0); u = p.units[2]; p.night = 8
	play(gs,"c25707"); play(gs,"c20806"); change(gs,"红莲")
	check(u.attack == 9 and int(u.mianRedGrowth) == 1,"red affects actual enhanced substitute body")
	gs._damage_unit(0,2,100,1,0); gs._resolve_resolution_stack()
	check(u.hp == 6 and u.attack == 2 and not u.has("mianRedGrowth"),"actual sparrow substitute resets growth and rollback ledger")
	gs._knockout_unit(u,1,0); gs._resolve_resolution_stack(); check(u.attack == 2,"later knockout cannot double-remove red growth after substitute")

func jealousy_rules() -> void:
	var gs := game(); var foe: Dictionary = gs.player(1); var u: Dictionary = gs.player(0).units[0]
	for target in gs._all_units(): target.factionOverride = "青岚"
	for target in foe.units: gs._grow_unit(target,0,30)
	foe.units[0].front = 1; var hp: int = foe.units[0].hp
	play(gs,"c20808")
	var hits := events(gs,"three-tail-projectile").filter(func(e): return e.reason == "妒心")
	check(hits.size() == 3 and hits[0].amount == 8 and hits[1].amount == 1 and hits[2].amount == 1,"three real projectile segments recompute matching living faction count")
	check(foe.units[0].hp == hp-12 and foe.avatarHp == 30,"each segment follows current faction passive and front targeting")
	check(events(gs,"faction-changed").size() == 3,"randomly changes to another faction after every segment including the last")
	gs = game(); foe = gs.player(1); u = gs.player(0).units[0]
	for target in gs._all_units(): target.factionOverride = "青岚"
	foe.units[0].front = 1; foe.units[0].hp = 1
	play(gs,"c20808"); hits = events(gs,"three-tail-projectile").filter(func(e): return e.reason == "妒心")
	check(hits.size() == 3 and str(hits[0].target) != "avatar-1" and hits[1].target == "avatar-1" and hits[2].target == "avatar-1","after front KO, later projectiles legally hit avatar")
	check(foe.avatarHp == 28,"avatar damage ignores shikigami passive bonus")

func ai_rules() -> void:
	for n in range(20801,20809):
		var gs := game(); var id := "c%d" % n; give(gs,id)
		var best: Dictionary = AI._best_card(gs,0)
		check(best.ok and best.card_id == id and gs.can_play_card(0,int(best.hand),best.target).ok,"AI finds a legal real card " + id)
		if best.ok:
			check(gs.play_card(0,int(best.hand),best.target),"AI uses actual card " + id)
			if not gs.pending_choice.is_empty(): check(AI.take_action(gs,0) and gs.pending_choice.is_empty(),"AI completes actual faction choice " + id)
	var gs := game(); change(gs,"红莲"); play(gs,"c20806"); change(gs,"紫岩")
	var view: Dictionary = Status.unit_view(gs,0,0,0)
	check(view.get("unyielding",false) and view.mianMarks.has("派系 · 紫岩"),"projected UI describes actual faction and dynamic unyielding")

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["mianqiling","rihefang","rurineque","taohuayao"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],208)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear(); p.energy = 40; p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var p: Dictionary = b.gs.player(0); var foe: Dictionary = b.gs.player(1); var u: Dictionary = p.units[0]
		hand(b,["c20801"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(foe.units[0].uid).selected,"native actual faction spell exposes enemy and own targets")
		await click(b._unit_widget(foe.units[0].uid)); await settled(b)
		check(b.gs.pending_choice.get("type") == "mian-faction" and faces(b._choice_layer).size() == 4,"native target click opens four faction cards")
		check(texts(b._choice_layer).contains("选择派系") or texts(b._choice_layer).contains("选 择 派 系"),"native faction chooser has actual instruction")
		await capture("%d-01-faction-choice" % physical.x)
		await click(choice_face(b,"苍叶")); await settled(b)
		check(Factions.get_faction(foe.units[0]) == "苍叶" and b.gs.pending_choice.is_empty(),"native named faction click applies and resumes")
		hand(b,["c20806"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(u.attack == 5 and u.maxHp == 5 and b.gs.VerifiedRules.Combat.has(u,"veil"),"native installs actual wheel shape")
		hand(b,["c20801"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(u.uid)); await settled(b)
		await click(choice_face(b,"红莲")); await settled(b)
		check(u.attack == 6 and b.gs.VerifiedRules.Combat.has(u,"pierce") and not b.gs.VerifiedRules.Combat.has(u,"veil"),"native wheel choice really grows all allies and changes trait")
		await hover_unit(b._unit_widget(u.uid)); await settled(b)
		check(texts(b).contains("红莲") and texts(b).contains("贯通"),"native faction and state visible in actual unit UI")
		await capture("%d-02-red-wheel" % physical.x)
		escape(); await settled(b)
		hand(b,["c20807"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.pending_choice.get("mode") == "awaken","native awakening really requires permanent faction selection")
		await click(choice_face(b,"紫岩")); await settled(b)
		check(u.awakened and u.factionPermanent == "紫岩" and u.attack == 8 and u.maxHp == 7,"native awakening resolves chosen faction then exact permanent2/2")
		await capture("%d-03-purple-awakening" % physical.x)
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	factions_and_cards(); faction_choices(); passive_damage(); seven_faces(); self_deceit_and_draw(); wheel_rules(); reset_growth(); jealousy_rules(); ai_rules()
	if not only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("MIANQILING_OK checks=%d failures=%d rules_only=%s" % [checks,failures,only]); quit(0 if failures == 0 else 1)
