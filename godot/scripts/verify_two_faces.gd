extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Link:=preload("res://scripts/link_rules.gd")
const Two:=preload("res://scripts/two_faces_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("TWO_FACES_FAIL ",detail)
func settled(b) -> void:
	for i in 3:await process_frame
	while b._input_locked():await create_timer(b._presentation_remaining()+0.05).timeout
	await create_timer(0.4).timeout
func game() -> GS:
	var gs:=GS.create(["liangmianfo","shuweng","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],238)
	for p in gs.players:
		p.hand.clear();p.deck.clear();p.energy=30;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func inst(gs,id: String) -> Dictionary:
	gs.next_card_id+=1;return {"instanceId":"two-test-%d"%gs.next_card_id,"definitionId":id}
func give(gs,id: String,owner: int=0) -> int:gs.player(owner).hand.append(inst(gs,id));return gs.player(owner).hand.size()-1
func deck(gs,ids: Array,owner: int=0) -> void:
	gs.player(owner).deck.clear()
	for id in ids:gs.player(owner).deck.append(inst(gs,str(id)))
func play(gs,id: String,target=null,owner: int=0) -> void:
	var idx:=give(gs,id,owner);check(gs.play_card(owner,idx,target),"actual play "+id)
func choose(gs,id: String,owner: int=0) -> void:
	var options:Array=gs.pending_choice.get("options",[])
	for option in options:
		if option.definitionId==id:
			check(gs.resolve_divination_choice(owner,str(option.instanceId)),"choose actual linked "+id);return
	check(false,"missing linked option "+id)
func finish(gs,target=null,owner: int=0) -> void:
	var h:=Link.ready_hand(gs,owner);check(h>=0 and gs.play_card(owner,h,target),"finish selected linked card")
func events(gs,kind: String) -> Array:return gs.rule_events.filter(func(e):return e.kind==kind)
func link_lifecycle() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
	check(p.units[0].attack==3 and p.units[0].maxHp==4 and p.units[0].passive_hooks.is_empty(),"original3/4 without fake passive")
	deck(gs,["c23802"]);var h:=give(gs,"c23801");var original:String=p.hand[h].instanceId;var candidate:String=p.deck[0].instanceId
	var snap:=JSON.stringify(gs.snapshot());var view:Dictionary=gs.hand_card_def(0,h)
	check(view.linkedUse and view.twoFacesEnhanced and view.linkAvailable,"read-only original previews linked enhancement")
	gs.hand_card_def(0,h);gs.can_play_card(0,h);check(snap==JSON.stringify(gs.snapshot()),"preview does not roll,draw,pay or reorder")
	var cards:int=p.cardsPlayedThisTurn;check(gs.play_card(0,h),"initiating use opens real link")
	check(gs.pending_choice.type=="native-link" and p.energy==30 and p.cardsPlayedThisTurn==cards and p.hand.size()==1 and p.deck.size()==1,"pre-use selection changes no zones, fire or use count")
	check(not gs.resolve_divination_choice(1,candidate) and not gs.resolve_divination_choice(0,"bad-id"),"foreign and invented selection rejected")
	choose(gs,"c23802");check(p.hand[0].instanceId==original and p.deck[0].instanceId==candidate,"choosing still leaves actual zones intact until target committed")
	check(gs.hand_card_def(0,0).id=="c23802" and Link.ready_hand(gs,0)==0,"virtual selected spell appears in original hand slot")
	var extra:=give(gs,"c23801");check(not gs.can_play_card(0,extra).ok and not gs.can_basic_attack(0,1).ok and not gs.end_turn(0),"pending selected card locks other uses, attack and turn end")
	check(not gs.play_card(0,0,"avatar-1") and Link.ready_hand(gs,0)==0 and p.energy==30,"illegal target cannot commit or pay")
	finish(gs,foe.units[0].uid)
	check(foe.units[0].hp==3 and foe.units[0].front==1,"linked sound damages3 then actually moves reserve forward")
	check(p.energy==29 and p.cardsPlayedThisTurn==cards+1 and p.hand.size()==1 and p.hand[0].instanceId!=original,"only selected spell consumes one use and ghost fire")
	check(p.deck.size()==1 and p.deck[0].instanceId==original and Link.ready_hand(gs,0)<0,"unselected actual original shuffled into deck, candidate used")
	check(events(gs,"link-used").size()==1,"one completed link event")
	gs=game();p=gs.player(0);foe=gs.player(1);deck(gs,["c23802"]);h=give(gs,"c23801");original=p.hand[h].instanceId;candidate=p.deck[0].instanceId
	check(gs.play_card(0,h),"open original selection");choose(gs,"c23801");finish(gs)
	check(foe.avatarHp==26 and foe.units[0].hp==5,"choosing original also enhanced: area1 then3 combat")
	check(p.deck.size()==1 and p.deck[0].instanceId==candidate and p.hand.is_empty(),"unselected candidate stays deck instead of drawn")
	gs=game();p=gs.player(0);p.units[0].level=1;deck(gs,["c23807","c23801"])
	check(Two.link_candidates(gs,0,Content.card_def("c23801")).is_empty(),"candidate rejects higherlevel wind and same-affinity thunder")
	h=give(gs,"c23801");check(not gs.hand_card_def(0,h).twoFacesEnhanced,"no candidate no fictional enhancement")
	check(gs.play_card(0,h) and gs.pending_choice.is_empty() and gs.player(1).avatarHp==27,"empty legal pool plays normal card immediately")
	gs=game();p=gs.player(0);p.energy=0;deck(gs,["c23802"]);h=give(gs,"c23806")
	check(gs.can_play_card(0,h).ok and gs.card_payment(0,gs.hand_card_def(0,h)).cost==0,"linked thunderclap previews actual instant at zero fire")
	check(gs.play_card(0,h),"zero-fire linked thunderclap opens choice");check(not Link.option_check(gs,0,str(p.deck[0].instanceId)).ok,"expensive alternative is disabled rather than free")
	choose(gs,"c23806");finish(gs);check(gs.player(1).avatarHp==24 and p.energy==0,"instant combo deals two real3 combat hits")
func card_effects() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	play(gs,"c23803");check(u.awakened and u.attack==4 and u.maxHp==5,"awakening exact1/1, passive enhanced all cards")
	var i:=give(gs,"c23803");check(not gs.can_play_card(0,i).ok,"repeated awakening rejected")
	play(gs,"c23801");check(foe.avatarHp==25 and foe.units[0].hp==5,"awakening enables area1 without available link")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[0].front=1
	play(gs,"c23802",foe.units[0].uid);check(foe.units[0].hp==3 and foe.units[0].front==1,"unenhanced sound damages3 without movement")
	u.awakened=true;var ally_hp:int=p.units[1].hp;play(gs,"c23802",p.units[1].uid);check(p.units[1].hp==ally_hp-3 and p.units[1].front==1,"enhanced sound can damage/move own shikigami hp=%d front=%d"%[p.units[1].hp,p.units[1].front])
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.awakened=true;foe.units[0].front=1;foe.units[0].hp=2
	deck(gs,["c23804"]);play(gs,"c23804");check(foe.units[0].hp==0 and foe.avatarHp==28,"original PNG thunder anger uses pierce overflow2, does not bypass front")
	check(p.hand.size()==1 and p.hand[0].definitionId=="c23804","positive overflow damage draws exactly one real card")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.avatarArmor=10;deck(gs,["c23804"]);play(gs,"c23804")
	check(p.hand.is_empty() and foe.avatarHp==30 and foe.avatarArmor==6,"armor-only hit does not draw")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.awakened=true;play(gs,"c23805")
	check(u.attack==6 and u.shield==3 and u.swift and gs.VerifiedRules.Combat.has(u,"pursuit"),"wind gives3 attack3armor turn pursuit and enhanced lasting swift")
	check(gs.basic_attack_targets(0,0).has(foe.units[2].uid),"wind pursuit exposes reserve enemies")
	check(gs.basic_attack(0,0,foe.units[2].uid) and not u.swift,"real swift deployment selects reserve and consumes swift")
	check(gs.end_turn(0),"wind turn ends");check(u.attack==3 and u.shield==0 and not gs.VerifiedRules.Combat.has(u,"pursuit"),"turn end removes only temporary3 attack3armor and pursuit")
	gs=game();p=gs.player(0);u=p.units[0];play(gs,"c23805");gs._knockout_unit(u,1,0);check(int(u.get("twoFacesWind",0))==0 and u.attack==3,"wind temporary attack/pursuit cannot survive KO")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.awakened=true;gs._grow_unit(foe.units[0],0,10);var before:int=foe.units[0].hp;var other_hp:int=foe.units[1].hp
	play(gs,"c23807",foe.units[0].uid);check(foe.units[0].hp==before-6 and foe.avatarHp==28 and foe.units[1].hp==other_hp-2,"enhanced gale selected4 then allenemycharacters2 selected=%d original=%d avatar=%d unit1=%d"%[foe.units[0].hp,before,foe.avatarHp,foe.units[1].hp])
	check(p.avatarHp==30 and u.hp==4,"gale excludes friendly characters")
	gs=game();foe=gs.player(1);play(gs,"c23807","avatar-1");check(foe.avatarHp==26 and foe.units[0].hp==6,"unenhanced gale can target avatar exactly4 without area")
	gs=game();foe=gs.player(1);play(gs,"c23808");check(gs.player(0).units[0].attack==4 and gs.player(0).units[0].maxHp==7,"original4/7 form")
func pursuit_card_targets() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
	play(gs,"c23805");foe.units[1].formRules={"combatKeywords":["veil"]};var h:=give(gs,"c23801")
	var view:Dictionary=gs.hand_card_def(0,h);var targets:Array=gs.valid_targets(0,view)
	check(view.combatOption.pursuit and "avatar-1" in targets and foe.units[2].uid in targets and foe.units[1].uid not in targets,"pursuit combat has legal avatar with empty front and excludes veiled unit")
	var energy:int=p.energy;check(not gs.play_card(0,h,foe.units[1].uid) and p.energy==energy,"pursuit rejects veiled target without paying")
	check(gs.play_card(0,h,"avatar-1") and foe.avatarHp==24,"pursuit card actually attacks undefended avatar with temporary 3 power")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c23805");foe.units[0].front=1;foe.units[1].formRules={"combatKeywords":["veil"]};h=give(gs,"c23801");targets=gs.valid_targets(0,gs.hand_card_def(0,h))
	check("avatar-1" not in targets and foe.units[2].uid in targets and foe.units[1].uid not in targets,"pursuit combat cannot bypass occupied front or target veil")
	energy=p.energy;check(not gs.play_card(0,h,"avatar-1") and p.energy==energy,"occupied-front avatar rejected without paying")
	var hp:int=foe.units[2].hp;check(gs.play_card(0,h,foe.units[2].uid) and foe.units[2].hp< hp,"pursuit card actually attacks chosen reserve behind front")
func wind_reset() -> void:
	for cast_again in [false,true]:
		var gs:=GS.create(["liangmianfo","rihefang","shuweng","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],238)
		for side in gs.players:
			side.hand.clear();side.deck.clear();side.energy=30;side.levelUpUsed=true
			for body in side.units:body.level=3
		var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0]
		play(gs,"c23805");check(u.attack==6 and u.shield==3 and gs.VerifiedRules.Combat.has(u,"pursuit"),"wind buffs attack armor and pursuit before sunlight reset")
		play(gs,"c16606",u.uid);check(u.attack==3 and u.shield==0 and gs.VerifiedRules.Combat.has(u,"pursuit") and int(u.twoFacesWindAttack)==0,"sunlight reset removes stats but preserves wind pursuit")
		check("本回合追猎" in Two.marks(gs,0,0) and not "本回合追猎 · 力量+3" in Two.marks(gs,0,0),"status shows pursuit without removed strength")
		if cast_again:
			play(gs,"c23805");check(u.attack==6 and int(u.twoFacesWindAttack)==3,"wind recast after reset records only newly gained strength")
		check(gs.end_turn(0),"end actual turn after sunlight reset")
		check(u.attack==3 and not gs.VerifiedRules.Combat.has(u,"pursuit") and not u.has("twoFacesWindAttack"),"turn expiry removes only remaining strength and pursuit")
	var gs:=game();var u:Dictionary=gs.player(0).units[0];u.twoFacesWind=3;u.attackBonus+=3;gs._recalc(u)
	Two.expire(gs);check(u.attack==3 and not gs.VerifiedRules.Combat.has(u,"pursuit"),"legacy wind state expires with its original strength")
	gs=GS.create(["liangmianfo","rihefang","shuweng","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],238)
	for side in gs.players:
		side.hand.clear();side.deck.clear();side.energy=30;side.levelUpUsed=true
		for body in side.units:body.level=3
	u=gs.player(0).units[0];play(gs,"c23805");play(gs,"c16606",u.uid);gs._knockout_unit(u,1,0)
	check(u.attack==3 and not u.has("twoFacesWind") and not u.has("twoFacesWindAttack"),"knockout after reset does not subtract removed strength again")
func deck_access() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
	play(gs,"c23808");deck(gs,["c23802"]);var h:=give(gs,"c23801");check(gs.play_card(0,h),"form link opens");choose(gs,"c23801");finish(gs)
	check(p.hand.is_empty() and p.deck.size()==1 and gs.playable_card_count(0)==1,"form exposes unselected actual deck card as extra play slot")
	var view:Dictionary=gs.hand_card_def(0,0);check(view.id=="c23802" and view.twoFacesFromDeck and view.twoFacesDeckFree and not view.get("lilyFromDeck",false),"deck slot clearly identifies wind form, not lily tax")
	var energy:int=p.energy;var hp:int=p.avatarHp;check(gs.play_card(0,0,foe.units[0].uid),"actually play available deck spell")
	check(p.deck.is_empty() and p.hand.is_empty() and p.energy==energy and p.avatarHp==hp and gs.pending_choice.is_empty(),"first deck use free, no selfdamage, no new link and no invented hand card")
	deck(gs,["c23802"]);h=give(gs,"c23801");check(gs.play_card(0,h),"second link");choose(gs,"c23801");finish(gs)
	view=gs.hand_card_def(0,0);check(not view.twoFacesDeckFree and gs.effective_card_cost(0,view)==1,"second deck use same turn pays normal fire")
	check(gs.end_turn(0),"end deck permission turn");check(gs.playable_card_count(0)==0 and not p.deck.is_empty(),"unused deck permission expires but original card remains deck")
	gs=game();p=gs.player(0);deck(gs,["c23802"]);h=give(gs,"c23801");p.nullifyNextCardTurn=gs.turn_counter
	check(gs.play_card(0,h),"countered link selection");choose(gs,"c23801");finish(gs);check(p.energy==29 and gs.player(1).avatarHp==30 and p.deck.size()==1,"counter stops effects after completed choice, retains actual payment and unselected deck")
func ai_cards() -> void:
	for n in range(23801,23809):
		var gs:=game();var p:Dictionary=gs.player(0);var id:="c%d"%n;give(gs,id)
		var best:Dictionary=AI._best_card(gs,0);check(best.ok and best.card_id==id,"AI finds legal "+id)
		check(gs.play_card(0,int(best.hand),best.target),"AI actually uses "+id)
	gs_loop_ai()
func gs_loop_ai() -> void:
	var gs:=game();deck(gs,["c23802"]);give(gs,"c23801")
	check(AI.take_action(gs,0) and gs.pending_choice.get("type")=="native-link","AI starts real choice")
	check(AI.take_action(gs,0) and Link.ready_hand(gs,0)>=0,"AI resolves only legal linked option")
	check(AI.take_action(gs,0) and Link.ready_hand(gs,0)<0 and gs.player(0).hand.is_empty(),"AI finishes selected card with legal target")
func native_ui() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["liangmianfo","shuweng","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],238);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.deck.clear();side.energy=30;side.levelUpUsed=true
			for u in side.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var p:Dictionary=b.gs.player(0);var foe:Dictionary=b.gs.player(1)
		hand(b,["c23808"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(p.units[0].get("form",{}).get("cardId")=="c23808","native form4/7 installed")
		deck(b.gs,["c23802"]);hand(b,["c23801"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b.gs.pending_choice.get("type")=="native-link" and faces(b._choice_layer).size()==2,"native actual click shows original+random candidate")
		check(p.hand.size()==1 and p.deck.size()==1 and p.energy==29,"native choice consumes nothing yet")
		await capture("%d-01-link-choice"%physical.x)
		await click(choice_face(b,"c23802"));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(foe.units[0].uid).selected and b._unit_widget(p.units[1].uid).selected,"selected sound opens real bothsides shikigami target UI")
		await click(b._unit_widget(foe.units[0].uid));await settled(b)
		check(foe.units[0].hp==3 and foe.units[0].front==1 and p.hand.is_empty(),"native selected spell deals3 and moves reserve")
		check(b._hand_row.get_child_count()==1 and b.gs.hand_card_def(0,0).id=="c23801" and b.gs.hand_card_def(0,0).twoFacesFromDeck,"native actual deck original is available in hand bar")
		await capture("%d-02-deck-access"%physical.x)
		var energy:int=p.energy;await click(b._hand_row.get_child(0));await settled(b)
		check(p.energy==energy and p.deck.is_empty() and b.gs.pending_choice.is_empty(),"native first deck play really free without recursive link")
		p.energy=30;p.attackUsed=false;p.units[0].hp=p.units[0].maxHp;p.units[0].knockout=0
		for enemy in foe.units:enemy.front=0
		foe.units[1].front=1;foe.units[2].formRules={"combatKeywords":["veil"]}
		hand(b,["c23805"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b.gs.VerifiedRules.Combat.has(p.units[0],"pursuit"),"native wind grants real pursuit")
		hand(b,["c23801"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(foe.units[3].uid).selected and not b._unit_widget(foe.units[2].uid).selected and "avatar-1" not in b.gs.valid_targets(0,b._pending_target_card_def),"native pursuit highlights reserve, excludes veil and blocked avatar")
		await capture("%d-03-pursuit-target"%physical.x)
		energy=p.energy;await click(b._unit_widget(foe.units[2].uid));await settled(b)
		check(b._pending_target_card==0 and p.energy==energy,"native veil click rejected without payment")
		var prior_hp:int=foe.units[3].hp;await click(b._unit_widget(foe.units[3].uid));await settled(b)
		check(foe.units[3].hp<prior_hp and p.hand.is_empty(),"native pursuit card strikes selected reserve")
		b.queue_free();await process_frame;await process_frame
func textures() -> void:
	for n in range(23801,23809):
		var card:=preload("res://scripts/ui/card_face.gd").new();card.data=Content.card_def("c%d"%n);root.add_child(card);await process_frame
		check(card._original_card!=null and card._original_card.resource_path=="res://assets/official/cards/c%d.png"%n,"actual original texture "+str(n));card.queue_free();await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:="--rules-only" in args
	if not args.is_empty() and not rules_only:out=args[0];DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	link_lifecycle();card_effects();pursuit_card_targets();wind_reset();deck_access();ai_cards()
	if not rules_only:await textures();await native_ui()
	Support.cleanup_stores(stores);Support.cleanup_audio()
	print("TWO_FACES_OK checks=%d failures=%d"%[checks,failures]);quit(1 if failures>0 else 0)
