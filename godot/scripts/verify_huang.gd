extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
const Rules := preload("res://scripts/huang_rules.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("HUANG_FAIL ", detail)
func fixture(seed: int = 17800) -> GS:
	var gs := GS.create(["huang","jiuciliang","xixueji","yingcao"],["shantong","bingyong","yaodaoji","qingshe"],seed)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId":"huang-test-%d" % gs.next_card_id,"definitionId":id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target: Variant = null, owner: int = 0) -> bool:
	return gs.play_card(owner,give(gs,id,owner),target)
func _initialize() -> void:
	Content.load_content(true)
	_data(); _growth(); _track(); _meteor(); _moon(); _sea(); _body(); _spiral(); _discard(); _conditions(); _ai()
	print("HUANG checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _data() -> void:
	for n in range(1,9):
		var c := Content.card_def("c178%02d" % n)
		check(c.get("huangRules", false) and c.verifiedRules and c.effects.size() == 1,"native card has executable rule " + c.id)
		check(c.cost == 1 and c.deckLimit == 2,"normal printed cost and construction limit " + c.id)
	check(Content.unit_def("huang").passive.hooks.is_empty(),"remove old armor substitute")
func _growth() -> void:
	var gs := fixture()
	check(play(gs,"c17801") and play(gs,"c17902") and play(gs,"c17806"),"install mixed-source realms")
	var p: Dictionary = gs.player(0)
	check(gs.basic_attack(0,0),"Huang deals real avatar combat damage")
	check(p.realms.map(func(r):return int(r.hp)) == [5,7,18],"one event adds1 to each realm, moon gain adds2")
	check(p.units[0].shield == 0,"no invented armor")
	gs._damage_avatar(1,1,0,0)
	check(p.realms[0].hp == 5,"noncombat damage does not grow realms")
	gs._grant_avatar_armor(1,20)
	gs._resolve_combat(0,0,0,false,false,false,false)
	check(p.realms[0].hp == 5,"fully absorbed combat damage does not trigger")
	gs.player(1).avatarArmor = 0
	gs._resolve_combat(0,0,0,false,false,true,false)
	check(p.realms[0].hp == 7,"each combo packet triggers separately")
	gs = fixture(); play(gs,"c17801")
	gs.player(0).units[0].front = 1
	check(gs.VerifiedRules.Combat.strike(gs,0,0,1,0,2,{}).damage == 2,"source unit combat hit")
	check(gs.player(0).realms[0].hp == 5,"unit hit grows durability")
	gs.VerifiedRules.Fortune.transform(gs,0,0,false)
	gs.VerifiedRules.Combat.strike(gs,0,0,1,-1,1,{})
	check(gs.player(0).realms[0].hp == 5,"paper suppresses base growth")
func _track() -> void:
	for front in [false,true]:
		var gs := fixture()
		play(gs,"c17801"); play(gs,"c17902")
		var p: Dictionary = gs.player(0)
		var e: Dictionary = gs.player(1)
		p.realms[0].hp = 9
		if front:
			e.units[0].front = 1; e.units[0].hp = 3; e.units[0].shield = 2
		gs._trigger_realms(0)
		check(e.avatarHp == (26 if front else 21),"track snapshots actual durability with exact projectile overflow")
		check(p.realms.size() == 1 and p.realms[0].cardId == "c17902","track self destroys without removing later realm")
		if front: check(e.units[0].hp == 0,"track actually knocks front out")
	var gs := fixture(); play(gs,"c17801")
	gs._knockout_unit(gs.player(0).units[0])
	gs._trigger_realms(0)
	check(gs.player(1).avatarHp == 26,"installed realm survives source knockout")
func _meteor() -> void:
	var gs := fixture(17804); play(gs,"c17804")
	for u in gs.player(1).units: u.level = 0
	gs.player(0).realms[0].hp = 6
	gs._trigger_realms(0)
	check(gs.player(1).avatarHp == 18,"six exact2 packets include avatar and exclude inactive units")
	check(gs.player(0).realms.is_empty(),"meteor self destroys after packets")
	for seed in range(10):
		gs = fixture(seed); play(gs,"c17804")
		for u in gs.player(1).units: u.hp = 1
		gs.player(0).realms[0].hp = 9
		gs._trigger_realms(0)
		var ids: Array = []
		var count := 0
		for ev in gs.rule_events:
			if ev.kind != "realm-random-hit": continue
			count += 1
			if str(ev.target) != "":
				check(not ids.has(ev.target),"random pool removes knocked-out target on following packet")
				ids.append(ev.target)
		check(count == 9,"meteor repeats initial durability, no arbitrary cap")
func _moon() -> void:
	var gs := fixture(); play(gs,"c17806")
	var p: Dictionary = gs.player(0)
	check(p.realms[0].hp == 15,"printed initial durability has no gained-durability bonus")
	gs._trigger_realms(0)
	check(p.realms[0].hp == 20 and gs.player(1).avatarHp == 30,"own turn gain3 amplified to5 below threshold")
	gs._trigger_realms(1)
	check(p.realms[0].hp == 20,"enemy turn does not advance moon")
	gs._trigger_realms(0)
	check(p.realms[0].hp == 25,"second own trigger")
	for u in gs.player(1).units: u.hp = 10; u.maxHp = 10; u.baseMaxHp = 10
	gs._trigger_realms(0)
	check(p.realms.is_empty() and gs.player(1).avatarHp == 20,"threshold30 commits destruction and avatar10")
	check(gs.player(1).units.all(func(u):return u.hp == 0),"moon deals10 to every enemy unit")
	gs = fixture(); play(gs,"c17806"); play(gs,"c17806")
	var first: Dictionary = gs.player(0).realms[0]
	first.hp = 29
	Rules.gain(gs,0,first,1)
	check(first.hp == 32,"gain over threshold does not detonate outside own start")
	gs._trigger_realms(0)
	check(gs.player(0).realms.size() == 1 and gs.player(0).realms[0].hp == 20,"destroying first does not skip second installed trigger")
func _sea() -> void:
	var gs := fixture(); var p: Dictionary = gs.player(0)
	var h := give(gs,"c17803"); var iid: String = p.hand[h].instanceId
	check(gs.play_card(0,h) and p.energy == 40,"first instant real cost0")
	play(gs,"c17902"); gs._damage_avatar(0,5,1,0)
	check(p.realms.size() == 1 and p.realms[0].hp == 6,"front realm alone bears packet, overflow does not spill")
	check(p.hand.size() == 1 and p.hand[0].instanceId == iid and p.hand[0].huangSeaReturned,"same sea instance returns once")
	check(gs.hand_card_def(0,0).text.contains("已失去"),"runtime hand exposes spent ability")
	gs.players = JSON.parse_string(JSON.stringify(gs.players))
	p = gs.player(0)
	check(p.hand[0].instanceId == iid,"returned instance roundtrip")
	check(gs.hand_card_def(0,0).realm.returnOnDestroy == false,"save preserves lost return ability")
	check(gs.play_card(0,0) and p.energy == 38,"second instant consumes1 after allowance used")
	Rules.destroy(gs,0,p.realms.back(),"测试消灭")
	check(p.hand.is_empty(),"second destruction cannot return this copy again")
	gs = fixture(); play(gs,"c17803")
	for i in 12: give(gs,"c11701")
	gs._damage_avatar(0,1,1,0)
	check(gs.player(0).hand.size() == 12 and not gs.player(0).hand.any(func(c):return c.definitionId == "c17803"),"return uses hand limit, no extra card")
func _body() -> void:
	for n in range(4):
		var gs := fixture()
		for i in n: play(gs,"c17902")
		var h := give(gs,"c17805")
		check(gs.hand_card_def(0,h).value.attack == 5+n,"live body hand preview reads current realms")
		check(gs.play_card(0,h),"body can be played")
		var u: Dictionary = gs.player(0).units[0]
		check(u.attack == 5+n and u.maxHp == 5+n and u.hp == 5+n,"form sets exact base5/5 plus realm count")
		play(gs,"c17902")
		check(u.attack == 5+n,"installed form does not dynamically grow from later realm")
		gs._knockout_unit(u)
		check(u.form.is_empty() and u.maxHp == 6 and u.attack == 2,"form and printed enhancement leave on knockout")
func _spiral() -> void:
	var gs := fixture(); var p: Dictionary = gs.player(0)
	check(play(gs,"c17808") and play(gs,"c17807"),"awake and spiral set up")
	var u: Dictionary = p.units[0]
	check(u.attack == 6 and u.maxHp == 9,"awake growth and exact spiral5/8 coexist")
	gs.player(1).units[0].front = 1
	gs.player(1).units[0].baseAttack = 20; gs.player(1).units[0].attack = 20
	play(gs,"c17902")
	check(u.hp == 9 and u.front == 1,"other unit realm triggers immune combat attack")
	check(u.swift and p.attackUsed == false and p.energy == 37,"realm use grants swift, triggered attack does not spend basic allowance")
	check(p.realms[0].hp == 6,"announced attack precedes new realm installation")
	var hp := int(gs.player(1).avatarHp)
	check(gs.basic_attack(0,0),"swift ordinary attack still available")
	check(p.energy == 37 and p.attackUsed and not u.swift and gs.player(1).avatarHp < hp,"basic consumes swift once and global allowance")
	gs = fixture(); play(gs,"c17807"); var before := int(gs.player(1).avatarHp)
	play(gs,"c17805")
	check(gs.player(1).avatarHp == before,"non-realm never triggers spiral")
func _discard() -> void:
	var gs := fixture(); var p: Dictionary = gs.player(0)
	var h := give(gs,"c17802")
	check(not gs.can_play_card(0,h).ok and not gs.play_card(0,h),"cannot pay missing realm discard")
	check(p.energy == 40 and p.hand.size() == 1,"illegal use pays nothing")
	give(gs,"c17902"); give(gs,"c17803"); give(gs,"c17805")
	p.deck = [{"instanceId":"draw-a","definitionId":"c17801"},{"instanceId":"draw-b","definitionId":"c17804"},{"instanceId":"draw-c","definitionId":"c17806"}]
	check(gs.play_card(0,0),"afterglow opens hand choice")
	check(gs.pending_choice.type == "huang-discard" and gs.pending_choice.instanceIds.size() == 2,"only realm cards offered including another source")
	var choice_iid: String = p.hand[0].instanceId
	check(not gs.resolve_divination_choice(1,choice_iid) and not gs.resolve_divination_choice(0,"invalid"),"foreign actor and invalid instance rejected")
	check(p.deck.size() == 3 and p.energy == 39,"choice pauses draw after one real payment")
	gs.players = JSON.parse_string(JSON.stringify(gs.players))
	gs.pending_choice = JSON.parse_string(JSON.stringify(gs.pending_choice))
	gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
	p = gs.player(0)
	check(gs.pending_choice.type == "huang-discard","pending discard survives JSON")
	check(gs.resolve_divination_choice(0,choice_iid),"selected foreign-source realm discarded")
	check(p.deck.is_empty() and p.hand.size() == 5 and p.hand[2].instanceId == "draw-c" and p.hand[4].instanceId == "draw-a","draw3 preserves actual instances and top order")
	check(gs.pending_choice.is_empty() and gs.resolution_stack.is_empty(),"choice resumes original card completion")
	gs = fixture(); give(gs,"c17802"); give(gs,"c17803"); gs.player(0).deck.clear()
	gs.play_card(0,0); gs.resolve_divination_choice(0,str(gs.player(0).hand[0].instanceId))
	check(gs.winner == 1,"afterglow uses actual empty-deck defeat")
func _ai() -> void:
	var gs := fixture(); give(gs,"c17802"); give(gs,"c17803"); give(gs,"c17902")
	check(gs.play_card(0,0) and AI.take_action(gs,0),"real AI resolves pending discard")
	check(gs.pending_choice.is_empty() and gs.command_log.back().c == "resolve_divination_choice","AI records legal specific choice")
	for seed in range(4):
		gs = GS.create(["huang","jiuciliang","xixueji","yingcao"],["shantong","bingyong","yaodaoji","qingshe"],seed)
		for step in 700:
			if gs.winner >= 0: break
			check(AI.take_action(gs,gs.action_player()),"mixed AI command legal")
		check(gs.winner >= 0,"mixed realm AI match terminates")

func _conditions() -> void:
	var gs := fixture(); play(gs,"c17801")
	gs.VerifiedRules.Combat.strike(gs,0,1,1,-1,2,{})
	check(gs.player(0).realms[0].hp == 4,"another source combat damage does not grow Huang realms")
	gs.player(0).units[0].front = 1
	gs._resolve_combat(1,0,0,false,false,false,false)
	check(gs.player(0).realms[0].hp == 5,"defensive counterhit grows realms on enemy turn")
	gs = fixture(); play(gs,"c17801")
	gs.player(1).units[0].bloodTransfer = true
	gs.player(1).units[0].shield = 1
	gs.VerifiedRules.Combat.strike(gs,0,0,1,0,2,{})
	check(gs.player(0).realms[0].hp == 5 and gs.player(1).avatarHp == 29,"actual transferred combat damage grows realms once")
	gs = fixture(); play(gs,"c17801")
	gs.player(1).units[0].hp = 2; gs.player(1).units[0].front = 1
	gs.player(1).units[0].bloodTransfer = true
	var before: Dictionary = gs.snapshot().duplicate(true)
	gs._trigger_realms(0)
	var cues: Array = Cues.damage_cues(before,gs.snapshot())
	check(cues.size() == 1 and cues[0].target == "" and cues[0].player == 1 and cues[0].amount == 4,"realm transfer visual targets real avatar and no extra overflow")
	check(gs.player(1).units[0].hp == 2 and gs.player(1).avatarHp == 26,"track transferred packet does not also damage unit")
	gs = fixture(); play(gs,"c17804")
	for u in gs.player(1).units: u.level = 0
	before = gs.snapshot().duplicate(true)
	gs._trigger_realms(0)
	cues = Cues.damage_cues(before,gs.snapshot())
	check(cues.size() == 4 and cues.all(func(c):return c.cardId == "c17804" and c.amount == 2),"meteor has one correctly attributed presentation event per actual packet")
	gs = fixture(); play(gs,"c17806")
	gs.player(0).realms[0].hp = 25
	gs.player(1).avatarHp = 10
	gs.player(0).deck.clear()
	gs._begin_turn(0)
	check(gs.winner == 0 and gs.player(0).avatarHp == 30,"start-of-turn moon wins before empty normal draw")
	gs = fixture(); play(gs,"c17808")
	gs.player(0).units[0].swift = false
	play(gs,"c17801"); play(gs,"c17803")
	check(gs.player(0).units[0].swift == true,"repeated realm use retains one swift rather than stacking")
	gs._knockout_unit(gs.player(0).units[0]); play(gs,"c17902")
	check(not gs.player(0).units[0].swift,"knocked-out Huang cannot gain swift from ally realm")
	gs = fixture(); play(gs,"c17807"); play(gs,"c17805")
	var hp := int(gs.player(1).avatarHp)
	play(gs,"c17902")
	check(gs.player(1).avatarHp == hp,"replacing spiral removes automatic attacks")
	gs = fixture(); play(gs,"c17807")
	gs.player(0).units[0].frozen = 1
	play(gs,"c17902")
	check(gs.player(1).avatarHp == 30 and gs.player(0).realms.size() == 1,"stunned Huang cannot attack but ally realm still installs")
