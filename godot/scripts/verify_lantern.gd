extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Lantern:=preload("res://scripts/lantern_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("LANTERN_FAIL ",detail)
func settled(b) -> void:
	for i in 3:await process_frame
	while b._input_locked():await create_timer(b._presentation_remaining()+0.05).timeout
	await create_timer(0.4).timeout
func game() -> GS:
	var gs:=GS.create(["gulonghuo","shuweng","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],293)
	for p in gs.players:
		p.hand.clear();p.energy=30;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"lantern-test-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,owner: int=0) -> void:
	var idx:=give(gs,id,owner);check(gs.play_card(owner,idx,target),"actual play "+id)
func events(gs,kind: String) -> Array:return gs.rule_events.filter(func(e):return e.kind==kind)
func knock(gs,owner: int=0,idx: int=0) -> void:gs._knockout_unit(gs.player(owner).units[idx],1-owner,0);gs._resolve_resolution_stack()
func fortune(gs,success: bool) -> void:
	for seed in range(1,10000):
		var next:=((seed*1664525+1013904223)&0xffffffff)
		if (int(float(next)/4294967296.0*6)+1>=4)==success:gs.rng_state=seed;return
func next_own(gs) -> void:
	check(gs.end_turn(0),"end own turn");check(gs.end_turn(1),"end enemy turn")
func lifecycle() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==5 and u.passive_hooks.is_empty(),"original2/5 with no fake passive")
	knock(gs);check(foe.avatarHp==28 and u.hp==0 and u.knockout==2,"first actual death projects2 and enters countdown2")
	play(gs,"c29301");check(u.hp==1 and u.knockout==0 and Lantern.history(u)==1 and p.energy==30,"instant self revival at1 records first revival")
	knock(gs);check(foe.avatarHp==25,"second death projects3")
	play(gs,"c29301");check(u.hp==1 and Lantern.history(u)==2 and p.energy==29,"second instant pays1; second revive increases permanent history")
	play(gs,"c29301");check(u.hp==1 and Lantern.history(u)==2,"living use sets life1 without fictitious revive")
	foe.units[0].front=1;var hp:int=foe.units[0].hp;knock(gs);check(foe.units[0].hp==hp-4 and foe.avatarHp==25,"death projection4 hits front, no face overflow")
	var history:int=Lantern.history(u);gs.VerifiedRules.reduce_countdown(gs,0,0,2);check(u.hp==5 and Lantern.history(u)==history+1,"real countdown revival counts once")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.level=0;knock(gs);check(foe.avatarHp==30,"unleveled death cannot use passive")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.baseRulesSuppressed=true;knock(gs);check(foe.avatarHp==30,"suppressed death cannot use passive")
	gs=game();p=gs.player(0);u=p.units[0];knock(gs);play(gs,"c29305");check(u.awakened and u.hp==6 and u.maxHp==6 and u.attack==3 and Lantern.history(u)==1,"KO awakening revives then printed1/1")
	var idx:=give(gs,"c29305");check(not gs.can_play_card(0,idx).ok,"repeated awakening rejected")
	knock(gs);fortune(gs,true);Lantern.turn_start(gs,0);check(u.knockout==1 and u.hp==0,"awakened successful fortune reduces actual KO countdown")
	fortune(gs,false);Lantern.turn_start(gs,0);check(u.knockout==1 and u.hp==0,"failed fortune does not reduce KO countdown")
	fortune(gs,true);Lantern.turn_start(gs,0);check(u.hp==6 and Lantern.history(u)==2,"fortune countdown zero really revives once")
func focus_combat() -> void:
	for fire in [0,1,2]:
		var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.energy=fire
		var idx:=give(gs,"c29302");var quote:Dictionary=gs.card_payment(0,gs.hand_card_def(0,idx));var snap:=JSON.stringify(gs.snapshot())
		check(quote.cost==(0 if fire==0 else 1) and quote.focusPaid==(fire>0),"instant focus compulsory only when residual fire "+str(fire))
		gs.hand_card_def(0,idx);gs.can_play_card(0,idx);check(snap==JSON.stringify(gs.snapshot()),"focus quote is read-only")
		check(gs.play_card(0,idx),"instant evil fire actual play");check(foe.avatarHp==(28 if fire==0 else 26),"focus adds exactly2 this combat")
		check(p.units[0].armorBreak==(0 if fire==0 else 2) and p.units[0].shield==0,"focus grants own2 armor break, not enemy debuff or shield")
		check(p.energy==(0 if fire==0 else fire-1) and p.units[0].attack==2,"focus pays1 and combat bonus does not persist")
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.energy=1;gs.kw_usage(0,"instant").used=true
	play(gs,"c29302");check(p.energy==0 and foe.avatarHp==28 and p.units[0].armorBreak==0,"spent instant uses last fire, focus inactive")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(p.units[0],0,20)
	for u in foe.units:u.attack=0;gs._grow_unit(u,0,20)
	foe.units[0].front=1;var before:Array=foe.units.map(func(u):return int(u.hp));var idx:=give(gs,"c29306")
	check(gs.valid_targets(0,gs.hand_card_def(0,idx)).has(foe.units[2].uid),"pursuit offers reserve target")
	check(gs.play_card(0,idx,foe.units[2].uid),"windwheel actual selected attack")
	check(foe.units[2].hp==before[2]-4,"first combat carries printed+2 strength")
	var damaged:=0;var total:=0
	for i in 4:
		if foe.units[i].hp<before[i]:damaged+=1;total+=before[i]-int(foe.units[i].hp)
	check(damaged==2 and total==6,"focus resolves distinct extra normal attack after first4 damage")
	check(p.energy==28 and not p.attackUsed,"combat card plus focus pays2, does not consume deployment")
	gs=game();p=gs.player(0);foe=gs.player(1);p.energy=1;gs._grow_unit(p.units[0],0,20);foe.units[0].front=1
	before=foe.units.map(func(u):return int(u.hp));play(gs,"c29306",foe.units[0].uid)
	check(foe.units[0].hp==before[0]-4 and foe.units[1].hp==before[1] and p.energy==0,"last-fire windwheel has no extra attack")
func burn_fortune_realm() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	var total:int=foe.units.reduce(func(a,b):return a+int(b.hp),0);play(gs,"c29303")
	check(u.hp==0 and u.knockout==1 and foe.avatarHp==28,"burn destroys source, projects2, reduces countdown1")
	check(foe.units.reduce(func(a,b):return a+int(b.hp),0)==total-5,"burn scatters five actual damage points to enemy units")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c29304");u=p.units[0]
	check(u.attack==3 and u.hp==9,"drifting form exact3/9")
	fortune(gs,true);gs._damage_unit(0,0,1,1,0);check(u.attack==4 and u.maxHp==8 and u.hp==7,"damage then successful fortune gains1 strength loses1 current/max life")
	fortune(gs,false);gs._damage_unit(0,0,1,1,0);check(u.attack==4 and u.maxHp==8 and u.hp==6,"failure gives no growth")
	var count:=events(gs,"fortune-result").size();u.shield=5;gs._damage_unit(0,0,2,1,0);check(events(gs,"fortune-result").size()==count,"fully shielded damage does not roll")
	u.shield=0;u.hp=2;fortune(gs,true);gs._damage_unit(0,0,1,1,0);gs._resolve_resolution_stack();check(u.hp==0 and u.knockout==2 and foe.avatarHp==28,"life loss from successful fortune may cause real knockout/projectile")
	gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false);check(u.attack==2 and u.maxHp==5,"drift growth and life loss are nonpermanent and clear on knockout")
	gs=game();p=gs.player(0);u=p.units[0];p.avatarHp=12;knock(gs);fortune(gs,true);play(gs,"c29307")
	check(p.realms.size()==1 and p.realms[0].hp==8 and u.hp==5 and Lantern.history(u)==1,"realm deploys8 then revives source")
	check(p.avatarHp==16 and p.energy==30,"own entry revival heals4 then successful fortune returns1 fire")
	knock(gs,0,1);fortune(gs,false);gs.VerifiedRules.Peach.revive(gs,0,2,p.units[1],false,false)
	check(p.avatarHp==20 and p.energy==30,"teammate revival heals4, failure gives no fire")
	knock(gs);p.avatarHp=10;fortune(gs,true);gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false);check(p.avatarHp==14 and p.energy==31,"realm works while source was KO")
func charged() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	var played:int=p.cardsPlayedThisTurn;var idx:=give(gs,"c29308");var iid:String=p.hand[idx].instanceId
	check(gs.play_card(0,idx),"stage charge-only card")
	check(u.has("lanternStored") and u.lanternStored.instance.instanceId==iid and p.hand.is_empty() and p.energy==29,"charge spends1, removes exact hand instance and records it")
	check(p.cardsPlayedThisTurn==played and foe.avatarHp==30 and gs.resolution_stack.is_empty(),"staging is not spell use and no immediate damage")
	idx=give(gs,"c29308");check(not gs.can_play_card(0,idx).ok,"cannot stack second charged card on same source")
	check("蓄力" in str(Lantern.marks(gs,0,0)),"pending charge visible in unit status")
	var allies:Array=p.units.map(func(t):return int(t.hp));var enemies:Array=foe.units.map(func(t):return int(t.hp))
	next_own(gs)
	check(not u.has("lanternStored") and foe.avatarHp==26 and u.hp==1,"next own start casts4 to enemy avatar and own source")
	for i in 4:
		check(p.units[i].hp==maxi(0,int(allies[i])-4) and foe.units[i].hp==maxi(0,int(enemies[i])-4+(2 if i==0 else 0)),"area hits both sides "+str(i)+" actual="+str([p.units[i].hp,foe.units[i].hp,foe.units[i].shield])+" before="+str([allies[i],enemies[i]]))
	check(p.avatarHp==30,"own avatar excluded from area")
	check(events(gs,"automatic-card").any(func(e):return e.card.id=="c29308"),"charged resolution is actual automatic spell")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];knock(gs);play(gs,"c29301");gs._heal_unit(u,9);foe.avatarHp=30
	play(gs,"c29308");var h:=give(gs,"c29308");check("6" in gs.hand_card_def(0,h).currentCardStats,"history changes displayed charged damage to6")
	next_own(gs);check(foe.avatarHp==21 and u.hp==0,"enhanced6 area plus source death projectile3")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c29308");knock(gs);check(not u.has("lanternStored"),"KO removes pending charge")
	gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false);foe.avatarHp=30;next_own(gs);check(foe.avatarHp==30,"revival does not restore removed charge")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c29308");gs.VerifiedRules.Stun.apply(gs,0,0,2,1);next_own(gs)
	check(u.has("lanternStored") and foe.avatarHp==30,"stunned source cannot release charged spell")
func ai_rules() -> void:
	for n in range(1,9):
		var gs:=game();var id:String="c293%02d"%n
		if n==1:knock(gs)
		give(gs,id);var best:Dictionary=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AI legal use "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AI executes "+id)
		check(Content.card_def(id).cost==1 and not Content.card_def(id).verificationPending.is_empty() and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original asset and pending source "+id)
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme();lifecycle();focus_combat();burn_fortune_realm();charged();boundaries();ai_rules()
	if not only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("LANTERN_OK checks=%d failures=%d rules_only=%s"%[checks,failures,only]);quit(0 if failures==0 else 1)
func ui_rules() -> void:
	for n in range(1,9):
		var face:=preload("res://scripts/ui/card_face.gd").new();face.data=Content.card_def("c293%02d"%n);face.refresh_art()
		check(face._original_card!=null and face._original_card.resource_path=="res://assets/official/cards/c293%02d.png"%n,"native original texture actually loaded "+str(n))
		face.free()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["gulonghuo","shuweng","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],293);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.energy=30;side.levelUpUsed=true
			for u in side.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var p:Dictionary=b.gs.player(0);var foe:Dictionary=b.gs.player(1);var u:Dictionary=p.units[0]
		knock(b.gs);hand(b,["c29301"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(u.hp==1 and Lantern.history(u)==1,"native KO-source instant revival actually restores1")
		b.gs._grow_unit(u,0,25)
		for enemy in foe.units:b.gs._grow_unit(enemy,0,25)
		foe.units[0].front=1;p.energy=2;hand(b,["c29306"]);await settled(b)
		check(b.gs.effective_card_cost(0,b.gs.hand_card_def(0,0))==2,"native focus payment quotes total2")
		await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(foe.units[2].uid).selected and not b._unit_widget(p.units[1].uid).selected,"native pursuit highlights reserve enemies only")
		await capture("%d-01-focus-target"%physical.x)
		var hp:int=foe.units[2].hp;await click(b._unit_widget(foe.units[2].uid));await settled(b)
		check(foe.units[2].hp==hp-4 and p.energy==0 and b._pending_target_card<0,"native selected pursuit damage and extra fire payment")
		p.energy=3;hand(b,["c29308","c29308"]);await settled(b);var face:int=foe.avatarHp
		await click(b._hand_row.get_child(0));await settled(b)
		check(u.has("lanternStored") and p.hand.size()==1 and p.energy==2 and foe.avatarHp==face,"native charge removes one instance without immediate damage")
		check(not b.gs.can_play_card(0,0).ok,"native remaining second copy cannot be charged")
		check("蓄力" in str(b.gs.VerifiedRules.Lantern.marks(b.gs,0,0)),"native persistent charging mark")
		await capture("%d-02-charged"%physical.x)
		await click(b._end_btn);await settled(b);check(b.gs.current_player==1,"native end-turn button advances to opponent")
		check(b.gs.end_turn(1),"actual opposing turn ends");b._last_view={};b._refresh();await settled(b)
		check(not u.has("lanternStored") and foe.avatarHp==face-6,"native next own turn releases enhanced6 automatically")
		b.queue_free();await process_frame;await process_frame

func boundaries() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	p.nullifyNextCardTurn=gs.turn_counter;play(gs,"c29308")
	check(u.has("lanternStored") and p.has("nullifyNextCardTurn"),"staging does not announce a spell or consume counter")
	var a:int=foe.avatarHp;next_own(gs);check(foe.avatarHp==a-4,"automatic charged use completes")
	gs=game();p=gs.player(0);foe=gs.player(1);p.energy=2;p.nullifyNextCardTurn=gs.turn_counter;play(gs,"c29306",foe.units[0].uid)
	check(p.energy==0 and foe.units[0].hp==6 and p.units[0].front==0,"nullified focus card pays both fire but does not attack")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.level=2;var idx:=give(gs,"c29308");check(not gs.can_play_card(0,idx).ok,"charge still requires printed level3")
	u.level=3;p.energy=0;check(not gs.can_play_card(0,idx).ok,"charge requires normal fire")
	p.energy=3;u.frozen=1;check(not gs.can_play_card(0,idx).ok,"stunned source cannot stage charge");u.frozen=0
	knock(gs);check(not gs.can_play_card(0,idx).ok,"KO source cannot stage charge")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c29308");var before:int=p.energy
	idx=give(gs,"c29308");check(not gs.play_card(0,idx) and p.energy==before and p.hand.size()==1,"second charge rejected before payment and hand removal")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[0].attack=10;foe.units[0].front=1
	var enemy_before:Array=foe.units.map(func(t):return int(t.hp));play(gs,"c29306",foe.units[0].uid)
	check(u.hp==0 and foe.units[1].hp==enemy_before[1] and foe.units[2].hp==enemy_before[2],"death during first combat stops extra attack")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];gs._grow_unit(u,0,15)
	for i in [1,2,3]:knock(gs,1,i)
	foe.units[0].front=1;var hp:int=foe.units[0].hp;play(gs,"c29306",foe.units[0].uid)
	check(foe.units[0].hp==hp-4,"single enemy cannot be attacked again as other target")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];knock(gs);u.samuraiCannotRevive=true;idx=give(gs,"c29301")
	check(not gs.can_play_card(0,idx).ok,"revival prohibition rejects revival card")
	gs=game();p=gs.player(0);u=p.units[0];knock(gs);p.avatarHp=15;fortune(gs,false);play(gs,"c29307");check(p.avatarHp==19 and p.energy==29,"realm failed fortune still heals entry revival")
	p.realms.clear();knock(gs,0,1);var fire:int=p.energy;gs.VerifiedRules.Peach.revive(gs,0,2,p.units[1],false,false)
	check(p.avatarHp==19 and p.energy==fire,"destroyed realm no longer rewards revival")
