extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Rules := preload("res://scripts/mengpo_rules.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_ability(); _cards(); _discard(); _names(); _bridge(); _ai()
	print("MENGPO checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("MENGPO_FAIL ", detail)
func game() -> GS:
	var gs := GS.create(["mengpo","yingcao","taohuayao","yaodaoji"],["bingyong","yingcao","yaodaoji","mengpo"],17116)
	for p in gs.players:
		p.hand.clear();p.energy = 40;p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func inst(gs, id: String) -> Dictionary:
	var out := {"definitionId":id,"instanceId":"mengpo-%d" % gs.next_card_id}
	gs.next_card_id += 1
	return out
func deck(gs, count: int, owner: int = 1, id: String = "c10701") -> void:
	gs.player(owner).deck.clear()
	for i in count: gs.player(owner).deck.append(inst(gs,id))
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(inst(gs,id));return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)
func roundtrip(gs) -> void:
	gs.players = JSON.parse_string(JSON.stringify(gs.players))
	gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
	gs.pending_choice = JSON.parse_string(JSON.stringify(gs.pending_choice))
func _ability() -> void:
	for n in [0,1,5]:
		var gs = game(); deck(gs,n)
		gs._damage_avatar(1,2,0,0)
		check(gs.player(1).deck.size()==maxi(0,n-1),"base ability removes bottom at most one")
		check(gs.player(1).avatarHp==28 and gs.winner<0,"removal never adds damage or loses on empty deck")
	var gs = game();deck(gs,5)
	var top: String = gs.player(1).deck.back().instanceId
	var bottom: String = gs.player(1).deck[0].instanceId
	check(gs.basic_attack(0,0),"real Mengpo basic attack")
	check(gs.player(1).deck.size()==4 and gs.player(1).deck.back().instanceId==top and gs.player(1).removedCards[0].instance.instanceId==bottom,"combat removes true bottom and retains top")
	for mode in ["armor","friendly","other-source","paper","knocked","zero-level","zero-damage"]:
		gs=game();deck(gs,5)
		match mode:
			"armor":gs.player(1).avatarArmor=5
			"paper":gs.player(0).units[0].baseRulesSuppressed=true
			"knocked":gs._knockout_unit(gs.player(0).units[0])
			"zero-level":gs.player(0).units[0].level=0
		gs._damage_avatar(0 if mode=="friendly" else 1,0 if mode=="zero-damage" else 2,0,1 if mode=="other-source" else 0)
		check(gs.player(1).deck.size()==5,"ability negative "+mode)
	gs=game();deck(gs,1);gs._damage_avatar(1,2,0,0)
	check(gs.winner<0,"last removed card does not draw black Seimei")
	gs._draw(1,1);check(gs.winner==0,"later genuine empty draw loses")
	gs=game();deck(gs,0);gs.player(1).bookEmptyDraw=true
	Rules.bottom(gs,0,0,1,5,"test")
	check(gs.player(0).avatarHp==30,"mill cannot activate Book empty-draw replacement")
	gs._draw(1,1);check(gs.player(0).avatarHp==20,"actual draw still activates Book")
func _cards() -> void:
	for n in [17,16,13,12]:
		var gs=game();deck(gs,n);give(gs,"c17102");give(gs,"c17104");give(gs,"c17105");give(gs,"c17107")
		var stamp:=JSON.stringify(gs.snapshot())
		var surprise: Dictionary=gs.hand_card_def(0,0)
		check(gs.card_payment(0,surprise).usesInstant==(n<=16) and int(surprise.cost)==1,"surprise has conditional instant and printed1")
		var form: Dictionary=gs.hand_card_def(0,1)
		check(form.value.attack==(8 if n<=16 else 5) and form.value.hp==(10 if n<=16 else 7),"body threshold and setBase stats")
		check(gs.hand_card_def(0,2).value==(8 if n<=16 else 4),"projectile threshold doubles actual damage")
		check(gs.hand_card_def(0,3).mengpoGrantSwift==(n<=12),"awakening exact <=12 boundary")
		check(JSON.stringify(gs.snapshot())==stamp,"queries preserve state and RNG")
		play(gs,"c17104");check(gs.player(0).units[0].attack==int(form.value.attack) and gs.player(0).units[0].maxHp==int(form.value.hp),"form installs printed base rather than adding body")
		check(gs.VerifiedRules.Combat.has(gs.player(0).units[0],"pierce"),"form grants actual pierce")
		gs=game();deck(gs,n);play(gs,"c17107")
		check(gs.player(0).units[0].attack==5 and gs.player(0).units[0].maxHp==6,"awake +2/+2 includes2020 revision")
		check(bool(gs.player(0).units[0].get("swift", false))==(n<=12),"2024 awakening condition grants actual swift")
		var old: int = gs.player(1).deck.size();gs._damage_avatar(1,1,0,0)
		check(gs.player(1).deck.size()==maxi(0,old-5),"awakened actual damage removes5 not base1 plus5")
	for front in [false,true]:
		for n in [17,16]:
			var gs=game();deck(gs,n)
			if front:gs.player(1).units[0].front=1;gs.player(1).units[0].hp=20;gs.player(1).units[0].maxHp=20
			play(gs,"c17105")
			var amount:=8 if n<=16 else 4
			check(gs.player(1).avatarHp==(30 if front else 30-amount),"projectile targets front else avatar")
			check(gs.player(1).deck.size()==n-(0 if front else 1),"only actual Mengpo avatar hit mills")
			if front:check(gs.player(1).units[0].hp==20-amount,"front takes exact projectile damage")
	var gs=game();deck(gs,8);var hp:int=gs.player(1).units[0].hp
	play(gs,"c17101",gs.player(1).units[0].uid)
	check(gs.player(1).units[0].hp==hp-3 and gs.player(1).deck.size()==5,"2022 soup causes targeted3 then mills3")
	check(gs.player(1).avatarHp==30,"soup never damages avatar or debuffs team")
	var energy:int=gs.player(0).energy
	check(not gs.play_card(0,give(gs,"c17101"),gs.player(0).units[0].uid) and gs.player(0).energy==energy,"soup rejects friendly target without paying")
	gs=game();deck(gs,16);play(gs,"c17104")
	gs.player(1).units[0].front=1;gs.player(1).units[0].hp=1
	check(gs.basic_attack(0,0),"enhanced pierce form makes actual attack")
	check(gs.player(1).avatarHp==23 and gs.player(1).deck.size()==15,"actual pierce overflow7 also triggers base mill1")
	gs=game();deck(gs,5,0);deck(gs,5);play(gs,"c17103")
	check(gs.player(0).units[0].attack==4 and gs.player(0).units[0].maxHp==5,"falling form real4/5")
	check(gs.end_turn(0),"real end-turn triggers falling form")
	check(gs.player(0).deck.size()==4 and gs.player(1).deck.size()==3,"owner end removes one each before enemy draw")
	check(gs.player(0).avatarHp==30 and gs.player(1).avatarHp==30,"falling form never substitutes damage")
	check(gs.end_turn(1),"enemy turn ends")
	check(gs.player(0).deck.size()==3 and gs.player(1).deck.size()==3,"enemy end does not trigger owner form")
func _discard() -> void:
	for serialized in [false,true]:
		var gs=game();deck(gs,17);deck(gs,2,0,"c17101")
		var kept:=give(gs,"c10702");var iid: String=gs.player(0).hand[kept].instanceId
		play(gs,"c17102")
		check(gs.player(0).energy==39 and not gs.player(0).keywordUsage.instant.used,"nonenhanced surprise pays actual1")
		check(gs.pending_choice.type=="mengpo-discard" and gs.player(0).hand.size()==3 and gs.player(0).deck.is_empty(),"draw2 precedes discard choice")
		if serialized:roundtrip(gs)
		check(not gs.resolve_divination_choice(1,iid) and not gs.resolve_divination_choice(0,"missing"),"discard rejects wrong owner and stale card")
		check(gs.resolve_divination_choice(0,iid),"choose old hand card after draw")
		check(gs.pending_choice.is_empty() and gs.phase=="main" and gs.player(0).hand.size()==2,"choice resumes resolution once")
		check(not gs.player(0).hand.any(func(i):return i.instanceId==iid),"selected instance really discarded")
	var gs=game();deck(gs,16);deck(gs,3,0);gs.player(0).energy=0
	play(gs,"c17102");check(gs.player(0).keywordUsage.instant.used,"enhanced surprise really consumes shared instant")
	var iid: String=gs.pending_choice.instanceIds.back()
	check(AI.take_action(gs,0) and gs.pending_choice.is_empty(),"AI completes mandatory discard")
	gs=game();deck(gs,1,0);play(gs,"c17102")
	check(gs.winner==1 and gs.pending_choice.is_empty(),"failed second draw loses before impossible discard")
func _names() -> void:
	var alias:=Content.card_def("c10301").duplicate(true);alias.id="verify-mengpo-same-name";Content.load_content().cards_by_id[alias.id]=alias
	for serialized in [false,true]:
		var gs=game();var enemy: Dictionary=gs.player(1)
		enemy.units[0].level=1;enemy.units[1].level=0
		enemy.hand=[inst(gs,"c10301"),inst(gs,alias.id),inst(gs,"c10703")]
		enemy.deck=[inst(gs,"c10701"),inst(gs,"c10301"),inst(gs,"c10702"),inst(gs,alias.id),inst(gs,"c10703")]
		give(gs,"c10301");gs.player(0).energy=0
		play(gs,"c17108")
		check(gs.pending_choice.type=="mengpo-name-unit" and not gs.pending_choice.instanceIds.has(enemy.units[1].uid),"first stage uses public enemy units with eligible levels")
		check(gs.player(0).keywordUsage.instant.used,"2024 melody uses real instant")
		if serialized:roundtrip(gs);enemy=gs.player(1)
		check(gs.resolve_divination_choice(0,str(enemy.units[0].uid)),"choose enemy unit")
		check(gs.pending_choice.type=="mengpo-name" and gs.pending_choice.instanceIds.has("c10301") and not gs.pending_choice.instanceIds.has("c10309"),"limits by chosen enemy level rather than caster level3")
		check(not gs.resolve_divination_choice(0,"c10309"),"reject higher level injected choice")
		if serialized:roundtrip(gs);enemy=gs.player(1)
		check(gs.resolve_divination_choice(0,"c10301"),"choose actual card name")
		check(enemy.hand.size()==1 and enemy.hand[0].definitionId=="c10703","removes same name across distinct definitions from hand")
		check(enemy.deck.size()==1 and enemy.deck[0].definitionId=="c10703","same names removed before extra bottom2; top survives")
		check(enemy.removedCards.size()==6 and gs.player(0).hand.size()==1,"exact instances exiled; own same name untouched")
		check(gs.pending_choice.is_empty() and gs.phase=="main","name choice resumes original frame")
	var gs=game();deck(gs,5);play(gs,"c17108")
	check(gs.resolve_divination_choice(0,str(gs.player(1).units[0].uid)),"choose public unit without matching hand/deck")
	check(gs.pending_choice.instanceIds.has("c10301") and gs.resolve_divination_choice(0,"c10301"),"absent name remains selectable without hidden-zone leak")
	check(gs.player(1).deck.size()==3,"absent chosen name still mills extra2")
	gs=game()
	for u in gs.player(1).units:u.level=0
	give(gs,"c17108");check(not gs.can_play_card(0,0).ok and not gs.player(0).keywordUsage.instant.used,"no eligible name rejected before payment")
	Content.load_content().cards_by_id.erase(alias.id)
func _bridge() -> void:
	for suppressed in [false,true]:
		var gs=game();play(gs,"c17106")
		check(gs.player(0).units[0].attack==4 and gs.player(0).units[0].maxHp==6,"bridge real4/6")
		gs.player(0).units[0].baseRulesSuppressed=suppressed
		deck(gs,4,0,"c10107");give(gs,"c10107");play(gs,"c10107")
		check(gs.player(0).deck.size()==(4 if suppressed else 0) and gs.player(0).hand.size()==(1 if suppressed else 0),"bridge active/suppressed same-name hand and deck removal")
		check(gs.player(0).units[3].awakened,"played card resolves even after remaining copies removed")
	var gs=game();play(gs,"c17106");deck(gs,4,0,"c10107");give(gs,"c10107")
	gs.player(0).nullifyNextCardTurn=gs.turn_counter
	play(gs,"c10107")
	check(gs.player(0).deck.is_empty() and not gs.player(0).units[3].awakened,"bridge is use trigger even when played card nullified")
	gs=game();play(gs,"c17106");deck(gs,4,1,"c10308");give(gs,"c10308",1);give(gs,"c10308",1)
	gs.player(1).units[0].front=1
	check(gs.basic_attack(0,0),"attack opens genuine automatic response")
	check(gs.player(1).hand.is_empty() and gs.player(1).deck.is_empty(),"bridge sees opponent automatic hand response and removes duplicates")
	check(gs.rule_events.filter(func(e):return e.kind=="response-card").size()==1,"removed second response cannot be used")
func _ai() -> void:
	for count in [0,12,16,17,24]:
		var gs=game();deck(gs,count);deck(gs,15,0);give(gs,"c17108");give(gs,"c17102")
		var guard:=0
		while gs.current_player==0 and gs.winner<0 and guard<25:
			guard+=1;check(AI.take_action(gs,0),"AI legal progress with choices")
		check(guard<25 and gs.pending_choice.is_empty(),"AI does not stall in two-stage names or discard")
