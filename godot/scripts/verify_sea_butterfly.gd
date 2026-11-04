extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Sea:=preload("res://scripts/sea_butterfly_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("SEA_BUTTERFLY_FAIL ",detail)
func settled(b) -> void:
	for i in 3:await process_frame
	while b._input_locked():await create_timer(b._presentation_remaining()+0.05).timeout
	# Presentation completion schedules a final hand relayout (0.26s tween).
	await create_timer(0.40).timeout
	await process_frame
func game() -> GS:
	var gs:=GS.create(["linghaidie","shuweng","huajing","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],287)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"sea-test-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,owner: int=0) -> void:
	var idx:=give(gs,id,owner);var legal:Dictionary=gs.can_play_card(owner,idx,target);check(gs.play_card(owner,idx,target),"actual play "+id+" "+str(legal))
func finish(gs) -> void:
	var guard:=0
	while not gs.pending_choice.is_empty() and guard<30:
		check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"AI resolves actual choice");guard+=1
	check(guard<30,"choices terminate")
func events(gs,kind: String) -> Array:return gs.rule_events.filter(func(e):return e.kind==kind)
func force_roll(gs,which: int) -> void:
	for seed in 12:
		if ((seed*1664525+1013904223)&0xffffffff)%3==which:gs.rng_state=seed;return
func card_rules() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
	check(p.units[0].attack==2 and p.units[0].maxHp==5 and p.units[0].passive_hooks.is_empty(),"2/5 original body without fake armor passive")
	play(gs,"c28701",foe.units[1].uid)
	check(p.units[0].front==1 and Sea.marked(p.units[0]) and foe.units[1].get("enraged",false),"wave actually enters front, attaches sea spirit and enrages selected enemy")
	check(p.units[0].shield==0,"sea spirit is not substituted with armor")
	gs.current_player=1;check(not gs.can_basic_attack(1,0).ok and gs.can_basic_attack(1,1).ok,"enrage imposes real deployment restriction");gs.current_player=0
	var count:=events(gs,"sea-spirit-attached").size();play(gs,"c28701",foe.units[2].uid)
	check(events(gs,"sea-spirit-attached").size()==count,"already in front does not manufacture a movement")
	var fire:int=p.energy;var deck:int=p.deck.size();play(gs,"c28702",p.units[1].uid)
	check(p.energy==fire and Sea.marked(p.units[1]) and gs.pending_choice.get("type")=="native-divination" and gs.pending_choice.count==2,"instant attaches before opening real divination2")
	var before:Dictionary=gs.snapshot();check(not gs.end_turn(0),"choice blocks turn advance")
	finish(gs);check(p.deck.size()==deck and p.hand.is_empty(),"divination reorders real deck without draw substitution")
	play(gs,"c28702",p.units[2].uid);finish(gs);check(p.energy==fire-1,"second instant pays normal fire")
	play(gs,"c28703");check(p.units[0].attack==2 and p.units[0].maxHp==6 and p.units[0].formRules.seaDouble,"formal 2/6 body not preview 2/7")
	play(gs,"c28704",p.units[0].uid);check(p.units[0].front==0 and p.units[0].awakened and p.units[0].attack==3 and p.units[0].maxHp==7,"awakening moves then grants printed1/1")
	var idx:=give(gs,"c28704");check(not gs.can_play_card(0,idx,p.units[0].uid).ok,"duplicate awakening blocked")
	gs.VerifiedRules.Movement.move_to(gs,0,1,1);check(Sea.marked(p.units[1]),"awakened source attaches to teammate entering front")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._knockout_unit(p.units[0],1,0);gs._knockout_unit(p.units[1],1,0);gs.resolution_stack.clear()
	play(gs,"c28705",p.units[1].uid);check(p.units[0].hp==0 and p.units[1].hp==p.units[1].maxHp and p.units[1].front==1 and not Sea.marked(p.units[1]),"KO source can revive and move chosen ally without inactive passive")
	play(gs,"c28705",p.units[0].uid);check(p.units[0].hp==5 and p.units[0].front==1 and Sea.marked(p.units[0]),"self revival then actual movement triggers active base")
	play(gs,"c28706");check(p.units[0].attack==5 and p.units[0].maxHp==7 and gs.VerifiedRules.Combat.has(p.units[0],"pursuit"),"5/7 form has actual pursuit")
	gs=game();p=gs.player(0);foe=gs.player(1);p.avatarHp=10;gs._grow_unit(foe.units[1],0,20);p.seaSpiritTriggers=4
	idx=give(gs,"c28707");check(gs.hand_card_def(0,idx).value==7 and "7" in gs.hand_card_def(0,idx).currentCardStats,"coral visible match-history enhancement")
	var hp:int=foe.units[1].hp;check(gs.play_card(0,idx,foe.units[1].uid),"enhanced coral actual use");check(foe.units[1].hp==hp-7 and p.avatarHp==17,"coral actual7 damage and7 heal")
	hp=p.units[2].hp;play(gs,"c28707",p.units[2].uid);check(p.units[2].hp==0 and p.avatarHp==24,"coral can target friendly shikigami and heal independently")
func spirit_rules() -> void:
	for which in 3:
		var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
		gs._grow_unit(p.units[1],0,20);gs._grow_unit(foe.units[1],2,20);p.units[1].front=1;Sea.attach(gs,0,0,p.units[1]);force_roll(gs,which);gs.current_player=1
		var hp:int=p.units[1].hp;var other:int=foe.units[1].hp;var power:int=foe.units[1].attack
		check(gs.basic_attack(1,1),"real attack on sea spirit "+str(which))
		var evs:=events(gs,"sea-spirit-triggered");check(evs.size()==1 and evs[0].effects==[["stun"],["armor-break"],["power"]][which],"deterministic single random effect")
		check(not Sea.marked(p.units[1]) and int(p.seaSpiritTriggers)==1,"one activation consumes attachment and records match counter")
		check(p.units[1].hp==hp-(power-2 if which==2 else power),"combat damage reflects combat-only -2")
		check(foe.units[1].hp==other-int(p.units[1].attack)-(2 if which==1 else 0),"2 armor break joins actual counterstrike")
		check(foe.units[1].attack==power and int(foe.units[1].frozen)==(2 if which==0 else 0),"no permanent attack loss; own-turn stun lasts through next turn")
		if which==2:
			hp=p.units[1].hp;foe.units[1].inspired=true;check(gs.basic_attack(1,1),"next attack allowed");check(p.units[1].hp==hp-power,"power penalty expires after first combat")
		if which==0:
			gs.VerifiedRules.Stun.end_turn(gs,1);check(foe.units[1].frozen==1,"stun survives current turn end");gs.VerifiedRules.Stun.end_turn(gs,1);check(foe.units[1].frozen==0,"stun ends after next own turn")
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.units[0].front=1;play(gs,"c28703");gs._grow_unit(p.units[0],0,20);Sea.attach(gs,0,0,p.units[0]);gs.current_player=1;gs.basic_attack(1,1)
	var evs:=events(gs,"sea-spirit-triggered");check(evs.size()==1 and evs[0].effects.size()==2 and evs[0].effects[0]!=evs[0].effects[1] and p.seaSpiritTriggers==1,"double form chooses two different outcomes but only one activation")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(foe.units[1],0,30);foe.units[1].front=1;play(gs,"c28708",p.units[1].uid)
	check(p.realms.size()==1 and p.realms[0].hp==10 and p.units[1].front==1 and p.units[1].hp==p.units[1].maxHp and Sea.marked(p.units[1]),"realm10 attaches and orders actual immune attack by selected teammate")
	check(foe.units[1].hp==foe.units[1].maxHp-p.units[1].attack and not p.get("attackUsed",false),"forced attack deals real damage without spending deployment")
	gs.current_player=1;gs.basic_attack(1,1);evs=events(gs,"sea-spirit-triggered")
	check(evs.size()==1 and evs[0].effects.size()==3 and Sea.marked(p.units[1]) and p.seaSpiritTriggers==1,"realm resolves all three and retains attachment")
	foe.units[1].frozen=0;foe.units[1].inspired=true;gs.basic_attack(1,1);check(p.seaSpiritTriggers==2 and Sea.marked(p.units[1]),"persistent spirit triggers on distinct subsequent attack")
	p.realms.clear();foe.units[1].frozen=0;foe.units[1].inspired=true;gs.basic_attack(1,1);check(not Sea.marked(p.units[1]),"removing realm restores normal one-use lifetime")
func cross_rules() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
	play(gs,"c28704",p.units[0].uid);Sea.attach(gs,0,0,p.units[1]);var face:int=foe.avatarHp;Sea.attach(gs,0,0,p.units[1]);check(foe.avatarHp==face-2 and events(gs,"sea-repeat-projectile").size()==1,"repeat awake attachment projects actual2 to empty front")
	foe.units[0].front=1;var hp:int=foe.units[0].hp;Sea.attach(gs,0,0,p.units[1]);check(foe.units[0].hp==hp-2 and foe.avatarHp==face-2,"repeat projectile respects occupied front")
	gs._knockout_unit(p.units[0],1,0);gs.resolution_stack.clear();hp=foe.units[0].hp;Sea.attach(gs,0,0,p.units[1]);check(foe.units[0].hp==hp,"inactive awakened caster cannot project")
	gs._knockout_unit(p.units[1],1,0);gs.resolution_stack.clear();check(not Sea.marked(p.units[1]),"real KO clears nonpermanent spirit")
	gs=game();p=gs.player(0);play(gs,"c28704",p.units[0].uid);gs.VerifiedRules.Whale.summon(gs,0,2);check(Sea.marked(p.units[-1]) and p.units[-1].countsAsShikigami,"actual summoned shikigami entry also attaches")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28706");gs._grow_unit(foe.units[1],3,20);foe.units[0].front=1;force_roll(gs,2);hp=p.units[0].hp;var enemy_hp:int=foe.units[1].hp
	check(gs.basic_attack(0,0,foe.units[1].uid),"pursuit attacks actual reserve target");var evs:=events(gs,"sea-spirit-triggered")
	check(evs.size()==1 and evs[0].target==foe.units[1].uid and evs[0].effects==["power"],"attack form activates own sea spirit on chosen enemy")
	check(foe.units[1].hp==enemy_hp-5 and p.units[0].hp==hp-maxi(0,int(foe.units[1].attack)-2),"offensive sea spirit lowers defender counterstrike only")
	gs=game();p=gs.player(0);play(gs,"c28706");play(gs,"c28708",p.units[0].uid);check(Sea.marked(p.units[0]) and events(gs,"sea-spirit-triggered").is_empty(),"attack avatar does not consume offensive sea spirit")
	gs=game();p=gs.player(0);foe=gs.player(1);p.units[1].front=1;gs._grow_unit(p.units[1],0,30);gs._grow_unit(foe.units[1],3,30);foe.units[1].keywords=["combo"];Sea.attach(gs,0,0,p.units[1]);force_roll(gs,2);hp=p.units[1].hp;gs.current_player=1;gs.basic_attack(1,1)
	check(events(gs,"sea-spirit-triggered").size()==1 and p.units[1].hp==hp-2*(int(foe.units[1].attack)-2),"combo is one activation; penalty covers each strike")
	gs=game();p=gs.player(0);p.nullifyNextCardTurn=gs.turn_counter;play(gs,"c28708",p.units[1].uid);check(p.realms.is_empty() and not Sea.marked(p.units[1]) and p.units[1].front==0,"nullify cancels whole realm including entry attack")
func response_boundaries() -> void:
	for roll in [0,2]:
		var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
		play(gs,"c28706");gs._grow_unit(foe.units[2],0,20);give(gs,"c10102",1);force_roll(gs,roll)
		var hp:int=foe.units[2].hp;check(gs.basic_attack(0,0,foe.units[2].uid),"actual pursuit into response defender")
		check(events(gs,"sea-spirit-triggered").size()==1 and p.seaSpiritTriggers==1,"response continuation never replays spirit")
		if roll==0:
			check(foe.units[2].frozen==1 and foe.hand.size()==1 and foe.units[2].hp==hp-5,"offensive spirit stuns before response card eligibility")
		else:
			check(foe.hand.is_empty() and foe.units[2].hp==hp and events(gs,"response-card").size()==1,"nonstun spirit permits genuine defensive response")
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
	p.units[1].front=1;gs._grow_unit(p.units[1],0,20);Sea.attach(gs,0,0,p.units[1]);gs._knockout_unit(p.units[0],1,0);gs.resolution_stack.clear();gs.current_player=1;gs.basic_attack(1,1)
	check(p.get("seaSpiritTriggers",0)==1 and not Sea.marked(p.units[1]),"attached spirit works after original caster KO")
	gs.current_player=0;play(gs,"c28705",p.units[0].uid);var i:=give(gs,"c28707");check(gs.hand_card_def(0,i).value==4,"match spirit history persists caster KO and revival")
	gs=game();p=gs.player(0);foe=gs.player(1);gs.VerifiedRules.Movement.move_to(gs,0,1,1)
	check(not Sea.marked(p.units[1]),"unawakened base does not attach to teammate")
	gs=game();p=gs.player(0);foe=gs.player(1);p.units[1].front=1;Sea.attach(gs,0,0,p.units[1]);gs._damage_unit(0,1,1,1,1)
	check(Sea.marked(p.units[1]) and events(gs,"sea-spirit-triggered").is_empty(),"spell damage does not trigger attack-only spirit")
	gs=game();p=gs.player(0);play(gs,"c28704",p.units[0].uid);var hp:int=p.units[0].hp;gs.VerifiedRules.Movement.move_to(gs,0,0,1)
	check(p.units[0].hp==hp and events(gs,"sea-repeat-projectile").is_empty(),"same-position move cannot repeat attachment or projection")
func automatic_coral() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.avatarHp=10;p.seaSpiritTriggers=4;gs._grow_unit(foe.units[0],0,20)
	var hp:int=foe.units[0].hp
	gs._push_card_frames(0,"c28707",foe.units[0].uid,Content.card_def("c28707"),0,0,true);gs._resolve_resolution_stack()
	check(foe.units[0].hp==hp-7 and p.avatarHp==17,"automatic coral uses same match history as hand cast")
func health_replacement() -> void:
	for offensive in [false,true]:
		var gs:=GS.create(["linghaidie","shuweng","huajing","xuenv"],["renmianshu","fenghuanghuo","yaodaoji","baizangzhu"],287)
		for player0 in gs.players:
			player0.hand.clear();player0.energy=40;player0.levelUpUsed=true
			for u in player0.units:u.level=3
		var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
		gs.current_player=1;play(gs,"c18104",foe.units[1].uid,1);gs.current_player=0
		if offensive:play(gs,"c28706")
		gs._grow_unit(p.units[0],0,20);gs.VerifiedRules.Movement.move_to(gs,0,0,1);var hp:int=p.units[0].hp;var amount:int=foe.units[1].hp;force_roll(gs,2)
		if offensive:check(gs.basic_attack(0,0,foe.units[1].uid),"health-based defender is pursued")
		else:gs.current_player=1;check(gs.basic_attack(1,1),"health-based attacker attacks spirit")
		check(p.units[0].hp==hp-amount,"sea reduces strength, not health-replacement damage "+str(offensive))
func legality_ai() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);foe.units[1].foxVeil=true;gs._knockout_unit(foe.units[2],0,0);gs.resolution_stack.clear();var idx:=give(gs,"c28707");var ts:Array=gs.valid_targets(0,gs.hand_card_def(0,idx))
	check(p.units[1].uid in ts and foe.units[0].uid in ts and foe.units[1].uid not in ts and foe.units[2].uid not in ts and "avatar-1" not in ts,"coral targets any live shikigami excluding enemy veil and avatar")
	var snapshot:=JSON.stringify(gs.snapshot());gs.hand_card_def(0,idx);gs.can_play_card(0,idx,foe.units[0].uid);check(snapshot==JSON.stringify(gs.snapshot()),"query/UI paths do not advance RNG, counters or attachments")
	for n in range(1,9):
		gs=game();var id:String="c287%02d"%n
		if n==5:gs._knockout_unit(gs.player(0).units[1],1,0);gs.resolution_stack.clear()
		give(gs,id);var best:=AI._best_card(gs,0);check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AI legal target "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AI actually plays "+id);finish(gs)
		check(Content.card_def(id).cost==1 and not Content.card_def(id).verificationPending.is_empty() and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"source art, cost, pending retained "+id)
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme();card_rules();spirit_rules();cross_rules();response_boundaries();automatic_coral();health_replacement();legality_ai()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("SEA_BUTTERFLY_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]);quit(0 if failures==0 else 1)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["linghaidie","shuweng","huajing","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],287);b._ai_thinking=true
		for p0 in b.gs.players:
			p0.hand.clear();p0.energy=40;p0.levelUpUsed=true
			for u in p0.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var p:Dictionary=b.gs.player(0);var foe:Dictionary=b.gs.player(1)
		hand(b,["c28701"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(foe.units[1].uid).selected and not b._unit_widget(p.units[1].uid).selected,"native wave enemy-only target highlights")
		await click(b._unit_widget(foe.units[1].uid));await settled(b);check(p.units[0].front==1 and Sea.marked(p.units[0]) and foe.units[1].get("enraged",false),"native wave moves and enrages actual selected target")
		hand(b,["c28702"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);await click(b._unit_widget(p.units[1].uid));await settled(b)
		check(b.gs.pending_choice.get("type")=="native-divination" and Sea.marked(p.units[1]),"native spirit attachment opens divination")
		await capture("%d-01-divination"%physical.x)
		var remaining:=0
		while not b.gs.pending_choice.is_empty() and remaining<4:
			await click(choice_face(b));await settled(b);await click(choice_face(b,"divination-place-bottom" if remaining==0 else "divination-place-top"));await settled(b);remaining+=1
		check(b.gs.pending_choice.is_empty() and remaining==2,"native places both actual cards into top/bottom")
		b.gs._knockout_unit(p.units[2],1,0);b.gs.resolution_stack.clear();hand(b,["c28705"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);check(b._pending_target_card==0,"native revive enters target mode "+str(physical));await click(b._unit_widget(p.units[2].uid));await settled(b)
		check(p.units[2].hp==p.units[2].maxHp and p.units[2].front==1,"native chosen KO teammate revives and enters front")
		b.gs._grow_unit(foe.units[0],4,30);foe.units[0].front=1;hand(b,["c28708"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);check(b._pending_target_card==0,"native realm enters target mode "+str(physical));await click(b._unit_widget(p.units[1].uid));await settled(b)
		check(p.realms.size()==1 and p.realms[0].hp==10 and p.units[1].front==1 and Sea.marked(p.units[1]),"native realm orders chosen teammate attack")
		b.gs.current_player=1;check(b.gs.basic_attack(1,1),"native enraged enemy actually attacks");b._last_view={};b._refresh();await settled(b)
		check(p.get("seaSpiritTriggers",0)==1 and Sea.marked(p.units[1]),"native battle persists spirit and displays real trigger history")
		await capture("%d-02-persistent-spirit"%physical.x)
		b.gs.current_player=0;hand(b,["c28707"]);await settled(b);check(b.gs.hand_card_def(0,0).value==4,"native enhanced coral current value")
		await click(b._hand_row.get_child(0));await settled(b);check(b._unit_widget(p.units[2].uid).selected and b._unit_widget(foe.units[1].uid).selected,"native coral allows both sides")
		var hp:int=foe.units[0].hp;await click(b._unit_widget(foe.units[0].uid));await settled(b);check(foe.units[0].hp==hp-4,"native enhanced coral resolves selected4 damage")
		b.queue_free();await process_frame;await process_frame
