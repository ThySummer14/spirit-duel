extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Futa:=preload("res://scripts/futakuchi_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FUTAKUCHI_FAIL ",detail)
func settled(b) -> void:
	for i in 3:await process_frame
	while b._input_locked():await create_timer(b._presentation_remaining()+0.05).timeout
	await create_timer(0.4).timeout
func game() -> GS:
	var gs:=GS.create(["erkounv","gulonghuo","rihefang","shuweng"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],295)
	for p in gs.players:
		p.hand.clear();p.energy=30;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"futa-test-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,owner: int=0) -> void:check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)
func events(gs,kind: String) -> Array:return gs.rule_events.filter(func(e):return e.kind==kind)
func knock(gs,owner: int=0,idx: int=0) -> void:gs._knockout_unit(gs.player(owner).units[idx],1-owner,0);gs._resolve_resolution_stack()
func pick(gs,size: int,index: int) -> void:
	for seed in range(1,10000):
		if int(((seed*1664525+1013904223)&0xffffffff)%size)==index:gs.rng_state=seed;return
func payments() -> void:
	for charge in [0,1,2,4]:
		for fire in [0,1,2]:
			var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];p.energy=fire;u.charge=charge;var idx:=give(gs,"c29501")
			var q:Dictionary=gs.card_payment(0,gs.hand_card_def(0,idx));var snap:=JSON.stringify(gs.snapshot());gs.hand_card_def(0,idx);gs.can_play_card(0,idx)
			check(snap==JSON.stringify(gs.snapshot()),"read-only quote charge%d/fire%d"%[charge,fire])
			check(gs.can_play_card(0,idx).ok==(fire>=1),"energy cannot replace base fire")
			if fire==0:continue
			var focused:bool=charge>=2 or fire>1;var deck:int=p.deck.size()
			check(q.focusPaid==focused and q.cost==(1 if charge>=2 or not focused else 2),"focus quote exact resources")
			check(gs.play_card(0,idx),"actual focus combat payment")
			check(u.charge==charge-(2 if charge>=2 else 0) and p.energy==fire-int(q.cost),"one resource paid, exactly once")
			check(p.deck.size()==deck-(1 if focused else 0) and gs.player(1).avatarHp==27,"draw iff focused, printed3 combat")
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];u.charge=2;p.energy=0
	play(gs,"c29505");check(u.awakened and u.charge==3 and u.attack==3 and u.maxHp==7 and gs.player(1).avatarHp==28,"zero-fire instant awakens, pays2 gains3 projects2, printed1/1")
	check(not gs.can_play_card(0,give(gs,"c29505")).ok,"cannot awaken twice")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=4;p.energy=0
	play(gs,"c29302");check(u.charge==4 and gs.player(1).avatarHp==28,"base ability cannot pay ally focus")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=4;u.awakened=true;p.energy=0
	play(gs,"c29302");check(u.charge==2 and p.energy==0 and gs.player(1).avatarHp==26 and p.units[1].armorBreak==2,"awakened pays ally focus with no fire")
	for state in ["knocked","suppressed","unleveled"]:
		gs=game();p=gs.player(0);u=p.units[0];u.charge=4;u.awakened=true;p.energy=0
		if state=="knocked":knock(gs)
		if state=="suppressed":u.baseRulesSuppressed=true
		if state=="unleveled":u.level=0
		play(gs,"c29302");check(gs.player(1).avatarHp==28,"inactive provider cannot pay ally "+state)
	gs=game();p=gs.player(0);u=p.units[0];u.charge=2;u.awakened=true;u.frozen=1;p.energy=0
	play(gs,"c29302");check(u.charge==0 and gs.player(1).avatarHp==26,"stunned provider retains passive")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=0;p.units[2].awakened=true;p.energy=1
	play(gs,"c29501");check(u.charge==0 and events(gs,"focus-energy-paid").size()==1 and p.sunFreeChargeTurn==gs.turn_counter,"sun free consumption applies once to focus")
	p.energy=1;var idx:=give(gs,"c29501");check(not gs.card_payment(0,gs.hand_card_def(0,idx)).focusPaid,"sun allowance is not reusable")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=4;p.energy=1;p.nullifyNextCardTurn=gs.turn_counter;var deck:int=p.deck.size()
	play(gs,"c29501");check(u.charge==2 and p.energy==0 and p.deck.size()==deck and gs.player(1).avatarHp==30,"nullified card still pays focus but no effect")
func cards() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0];u.charge=4
	play(gs,"c29502");check(u.attack==4 and u.maxHp==7 and u.hp==7,"attached form3/6 plus permanent1/1")
	knock(gs);gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false);check(u.attack==3 and u.maxHp==7,"permanent focus growth survives KO and form loss")
	gs=game();p=gs.player(0);u=p.units[0];p.energy=1;play(gs,"c29502");check(u.attack==3 and u.maxHp==6,"unfocused form retains exact3/6")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=2;var attacks:Array=p.units.map(func(t):return int(t.attack));play(gs,"c29503")
	check(p.realms.size()==1 and p.realms[0].hp==5,"fear actual realm5")
	var recipients:Array=p.units.filter(func(t):return t.get("futakuchiFearGrowth",0)==1);check(recipients.size()==1 and recipients[0].swift,"fear gives exactly one random ally growth and swift")
	var idx:int=gs._unit_index_by_uid(0,recipients[0].uid);check(recipients[0].attack==attacks[idx]+1,"random recipient grows1")
	knock(gs,0,idx);gs.VerifiedRules.Peach.revive(gs,0,2,p.units[idx],false,false);check(p.units[idx].attack==attacks[idx] and not p.units[idx].get("swift",false),"fear nonpermanent growth removed at KO")
	u.charge=0;gs._resolve_combat(0,1,0,false,false,false,false);gs._resolve_resolution_stack();check(u.charge==1,"other friendly attack charges realm source")
	p.realms.clear();gs._resolve_combat(0,1,0,false,false,false,false);gs._resolve_resolution_stack();check(u.charge==1,"removed realm no longer charges")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.charge=2;foe.units[0].front=1;foe.units[2].attack=20
	play(gs,"c29504",foe.units[2].uid);check(foe.units[2].hp==0 and u.hp==1 and not u.get("futakuchiUnyielding",false),"pursuit hits chosen reserve5 and consumes unyielding to survive lethal")
	gs._damage_unit(0,0,1,1,0);check(u.hp==0,"unyielding consumed only once")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];p.energy=0;u.charge=2;var hp:Array=foe.units.map(func(t):return int(t.hp));play(gs,"c29507")
	check(foe.avatarHp==25 and p.energy==0 and u.charge==0,"instant apology deals2 face then printed3 combat")
	for i in 4:check(foe.units[i].hp==maxi(0,hp[i]-2),"apology damages each enemy unit "+str(i))
	check(p.units[1].hp==5 and p.avatarHp==30,"apology never damages allies")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.charge=2;gs._grow_unit(foe.units[0],0,5)
	play(gs,"c29508",foe.units[0].uid);check(foe.units[0].hp==0 and foe.units[1].hp==4,"six damage creates sole wounded candidate, then destroys it")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.charge=2;foe.units[1].hp=1;foe.units[1].veil=true
	play(gs,"c29508",foe.units[0].uid);check(foe.units[0].hp==0 and foe.units[1].hp==0,"six lethal removes first target; random wounded destroy ignores target veil")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];p.energy=1;gs._grow_unit(foe.units[0],0,5)
	play(gs,"c29508",foe.units[0].uid);check(foe.units[0].hp==5,"unfocused devour only main6")
	var c:Dictionary=Content.card_def("c29508");check(not gs.valid_targets(0,c).has(p.units[0].uid) and not gs.valid_targets(0,c).has("avatar-1"),"devour enemy shikigami only")
func symbiotic() -> void:
	check(Futa.pool(1)==["c29501","c29502","c29503"] and Futa.pool(2).size()==5 and Futa.pool(3).size()==7,"level-bound focus pool excludes symbiosis itself")
	for i in 7:
		var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];var foe:Dictionary=gs.player(1);u.charge=2;foe.units[1].hp=1
		var deck:int=p.deck.size();pick(gs,7,i);play(gs,"c29506")
		check(events(gs,"futakuchi-symbiosis").size()==1 and events(gs,"futakuchi-symbiosis")[0].cardId==Futa.FOCUS_POOL[i],"actual form entry random effect "+str(i))
		check(p.cardsPlayedThisTurn==1 and u.form.cardId=="c29506" and p.energy==29,"random effect neither plays card nor changes form nor extra fire")
		check(u.charge==(3 if i==4 else 0),"symbiosis pays2 before effect, recharge only selected focus")
		match i:
			0:check(p.deck.size()==deck-1,"symbiosis draw")
			1:check(u.attack==5 and u.maxHp==8,"symbiosis permanent growth")
			2:check(p.units.any(func(t):return t.get("swift",false)),"symbiosis random swift")
			3:check(u.get("futakuchiUnyielding",false),"symbiosis unyielding")
			4:check(foe.avatarHp==28 and not u.awakened,"symbiosis projection without awakening")
			5:check(foe.avatarHp==28 and foe.units[0].hp==4,"symbiosis area without combat")
			6:check(foe.units[1].hp==0 and foe.units[0].hp==6,"symbiosis destroy without main6")
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];u.charge=1;var seed:int=gs.rng_state;play(gs,"c29506")
	check(u.attack==4 and u.maxHp==7 and u.charge==1 and gs.rng_state==seed,"insufficient charge installs form but does not roll or spend")
	u.charge=2;pick(gs,7,1);check(gs.basic_attack(0,0),"actual basic attack triggers symbiosis")
	check(u.attack==5 and gs.player(1).avatarHp==25 and u.charge==0,"growth resolves before combat power read, exactly once")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=0;play(gs,"c29506");p.realms.append({"uid":"test-realm","hp":5,"cardId":"c29503","nativeRealm":"futakuchi-fear"});u.charge=1;pick(gs,7,0)
	gs._resolve_combat(0,0,0,false,false,false,false);gs._resolve_resolution_stack();check(u.charge==0 and events(gs,"futakuchi-symbiosis").size()==1,"realm attack gain then symbiosis consumes2")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=9;check(gs.end_turn(0) and gs.end_turn(1),"next own turn")
	check(u.charge==10,"native charge own turn gain1 cap10")
	knock(gs);check(not u.has("futakuchiUnyielding") and not u.get("formRules",{}).get("futakuchiSymbiosis",false),"KO removes form and granted unyielding")
func ai_rules() -> void:
	for n in range(1,9):
		var gs:=game();var id:String="c295%02d"%n;gs.player(0).units[0].charge=4;give(gs,id)
		var best:Dictionary=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AI legal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AI actual "+id)
		check(not Content.card_def(id).verificationPending.is_empty(),"keep client pending "+id)
func reset_interactions() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0]
	u.charge=2;play(gs,"c29502")
	gs.VerifiedRules.SunSmoke.reset_character(gs,0,u,u.uid)
	check(u.attack==4 and u.maxHp==7,"sun reset preserves attached form's permanent focus growth")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=2;pick(gs,4,3)
	var ally:Dictionary=p.units[3];var attack:int=ally.attack;var max_hp:int=ally.maxHp
	play(gs,"c29503");check(ally.get("futakuchiFearGrowth",0)==1,"fear really grants selected ally temporary growth")
	gs.VerifiedRules.SunSmoke.reset_character(gs,0,ally,ally.uid)
	check(ally.attack==attack and ally.maxHp==max_hp and not ally.has("futakuchiFearGrowth"),"sun reset removes temporary fear growth and its rollback ledger")
	knock(gs,0,3);gs.VerifiedRules.Peach.revive(gs,0,2,ally,false,false)
	check(ally.attack==attack and ally.maxHp==max_hp,"later knockout does not subtract already reset fear growth twice")
	gs=GS.create(["erkounv","rurineque","rihefang","shuweng"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],296)
	for side in gs.players:
		side.hand.clear();side.energy=30;side.levelUpUsed=true
		for unit in side.units:unit.level=3
	p=gs.player(0);u=p.units[0];ally=p.units[1];p.night=5;u.charge=2
	play(gs,"c25707");pick(gs,4,1);play(gs,"c29503")
	check(ally.get("futakuchiFearGrowth",0)==1 and ally.formRules.get("sparrowSubstitute",false),"fear growth really reaches a substitute form")
	gs._damage_unit(0,1,99,1,0);gs._resolve_resolution_stack()
	check(ally.hp==6 and ally.attack==2 and not ally.has("futakuchiFearGrowth"),"substitute restores body and clears removed fear growth ledger")
	gs._damage_unit(0,1,99,1,0);gs._resolve_resolution_stack();gs.VerifiedRules.Peach.revive(gs,0,2,ally,false,false)
	check(ally.hp==6 and ally.attack==2 and ally.maxHp==6,"subsequent actual knockout cannot subtract the removed growth again")
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme();payments();cards();symbiotic();ai_rules();reset_interactions()
	if not only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("FUTAKUCHI_OK checks=%d failures=%d rules_only=%s"%[checks,failures,only]);quit(0 if failures==0 else 1)
func ui_rules() -> void:
	for n in range(1,9):
		var face:=preload("res://scripts/ui/card_face.gd").new();face.data=Content.card_def("c295%02d"%n);face.refresh_art()
		check(face._original_card!=null and face._original_card.resource_path=="res://assets/official/cards/c295%02d.png"%n,"native original texture "+str(n));face.free()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["erkounv","gulonghuo","rihefang","shuweng"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],295);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.energy=20;side.levelUpUsed=true
			for t in side.units:t.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var p:Dictionary=b.gs.player(0);var foe:Dictionary=b.gs.player(1);var u:Dictionary=p.units[0];u.charge=4;p.energy=1;foe.units[0].front=1
		for t in foe.units:b.gs._grow_unit(t,0,20)
		hand(b,["c29504"]);await settled(b)
		check("2能量" in str(b.gs.hand_card_def(0,0).currentCardStats) and b.gs.effective_card_cost(0,b.gs.hand_card_def(0,0))==1,"native quote shows energy replacement")
		await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(foe.units[2].uid).selected and not b._unit_widget(p.units[1].uid).selected,"native pursuit highlights enemies in reserve")
		await capture("%d-01-energy-target"%physical.x);var hp:int=foe.units[2].hp
		await click(b._unit_widget(foe.units[2].uid));await settled(b)
		check(foe.units[2].hp==hp-5 and u.charge==2 and p.energy==0,"native selected pursuit uses1fire2energy")
		p.energy=1;hand(b,["c29508"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and not b._unit_widget(p.units[0].uid).selected,"native spell only enemy target")
		await click(b._unit_widget(p.units[0].uid));await settled(b);check(p.energy==1 and p.hand.size()==1,"invalid friendly click leaves resources and hand")
		await click(b._unit_widget(foe.units[0].uid));await settled(b);check(p.energy==0 and u.charge==0 and p.hand.is_empty(),"native devour resolves selected6 then random injured destroy")
		p.energy=0;u.charge=2;hand(b,["c29505"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(u.awakened and u.charge==3,"native instant awakening uses charge with0fire")
		b.gs.kw_usage(0,"instant").used=false;hand(b,["c29302"]);await settled(b);check("2能量" in str(b.gs.hand_card_def(0,0).currentCardStats),"native ally displays correct focus payment")
		await capture("%d-02-awakened-focus"%physical.x);await click(b._hand_row.get_child(0));await settled(b)
		check(u.charge==1 and p.energy==0 and p.units[1].armorBreak==2,"native awakened replacement applies to ally")
		b.queue_free();await process_frame;await process_frame
