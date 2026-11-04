extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Yuj:=preload("res://scripts/yujiazhu_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("YUJIAZHU_FAIL ",detail)
func game(own: Array=["yujiazhu","xiaolunan","huajing","rihefang"]) -> GS:
	var gs:=GS.create(own,["bingyong","yaodaoji","fenghuanghuo","baizangzhu"],189)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3;u.charge=0
	gs.rule_events.clear();return gs
func give(gs,id: String,burst: int=0,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"yuj-test-%d"%gs.next_card_id,"definitionId":id,"movementBurst":burst});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,burst: int=0) -> void:
	var index:=give(gs,id,burst);var q:Dictionary=gs.can_play_card(0,index,target)
	check(gs.play_card(0,index,target),"actual use "+id+" burst%d "%burst+str(q.get("reason","")))
func events(gs,kind: String) -> Array:return gs.rule_events.filter(func(e):return e.kind==kind)
func knock(gs,owner: int,idx: int) -> void:gs._knockout_unit(gs.player(owner).units[idx],1-owner,0);gs._resolve_resolution_stack()
func formed(gs,idx: int=0) -> void:gs._apply_form(1,idx,Content.card_def("c10302"));gs._resolve_resolution_stack()
func charge_and_arrows() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0]
	check(u.attack==3 and u.maxHp==4 and u.passive_hooks.is_empty() and gs.VerifiedRules.SunSmoke.has_charge(u),"original3/4 and native charge without legacy ghost fire mapping")
	u.charge=9;check(gs.end_turn(0) and gs.end_turn(1),"real next ownturn");check(u.charge==10,"native ownturn charging cap10")
	for id in Yuj.TALISMANS:
		gs=game();p=gs.player(0);u=p.units[0];var foe:Dictionary=gs.player(1);u.charge=3
		gs._grow_unit(foe.units[1],0,20);foe.units[0].front=1
		var hp:int=foe.units[1].hp;var h:=give(gs,id,3);var c:Dictionary=gs.hand_card_def(0,h)
		check(c.type=="combat" and not Content.is_spell(c) and c.value==1 and c.combatOption.shield==1 and c.combatOption.pursuit,"actual arrow conversion "+id)
		check(c.target=="enemy-unit" and gs.valid_targets(0,c).has(foe.units[1].uid) and not gs.valid_targets(0,c).has("avatar-1"),"arrow can choose reserve but cannot bypass front to avatar "+id)
		check(Content.card_def(id).type=="spell","query does not mutate original spell "+id)
		check(gs.play_card(0,h,foe.units[1].uid),"converted arrow actually attacks selected reserve "+id)
		check(foe.units[1].hp==hp-(8 if id=="c18907" else 4),"retained spell and printed+1 combat damage "+id)
		check(u.charge==0 and p.energy==39 and events(gs,"burst-used").size()==1 and p.whaleBursts==1,"exact fire and one nominal burst3 "+id)
		if id=="c18904":check(foe.units[1].frozen==1 and foe.units[1].attack==0 and u.hp==4,"seal arrow stuns and zeros before counter")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=2;var h:=give(gs,"c18904",3)
	check(not gs.can_play_card(0,h,gs.player(1).units[0].uid).ok and p.energy==40 and p.hand.size()==1,"insufficient burst rejects before payment")
	gs=game();p=gs.player(0);u=p.units[0];play(gs,"c18905");check(u.awakened and u.attack==4 and u.maxHp==5,"awakening exact1/1")
	check(not gs.can_play_card(0,give(gs,"c18905")).ok,"cannot repeat awakening")
	u.charge=3;gs._grow_unit(gs.player(1).units[1],20,20);var hp:int=u.hp;play(gs,"c18907",gs.player(1).units[1].uid,3)
	check(u.hp==hp and gs.player(1).units[1].hp>0,"awakened arrow retains true combat immunity against surviving highpower foe")
func talisman_rules() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);formed(gs);var target:Dictionary=foe.units[0]
	var h:=give(gs,"c18901");var c:Dictionary=gs.hand_card_def(0,h)
	check(gs.valid_targets(0,c).has(target.uid) and not gs.valid_targets(0,c).has(foe.units[1].uid) and not gs.valid_targets(0,c).has(p.units[0].uid),"plain drive chooses only formed enemy shikigami")
	var hp:int=target.hp;check(gs.play_card(0,h,target.uid),"plain drive applies mark");check(target.hp==hp,"drive itself is not direct damage")
	target.shield=10;gs._damage_unit(1,0,1,0,1);check(target.hp==hp,"fully armored zero damage cannot drive knockout")
	target.shield=0;target.barrier=true;gs._damage_unit(1,0,1,0,1);check(target.hp==hp and not target.barrier,"barrier blocks drive trigger")
	gs._damage_unit(1,0,1,0,1);gs._resolve_resolution_stack();check(target.hp==0 and events(gs,"unit-knocked-out").size()>=0,"one real damage causes marked actual knockout")
	gs=game();formed(gs);target=gs.player(1).units[0];play(gs,"c18901",target.uid);check(gs.end_turn(0),"drive marked turn ends")
	gs._damage_unit(1,0,1,0,1);check(target.hp>0 and not target.has("yujDoomTurn"),"drive mark expires at actual turnend")
	gs=game();foe=gs.player(1);target=foe.units[1];hp=target.hp;var attack:int=target.attack
	play(gs,"c18904",target.uid);check(target.hp==hp and target.attack==0 and target.frozen==1,"seal changes stun and current attack without damage")
	gs.end_turn(0);check(target.attack==attack and target.frozen==1,"zero power is turn-only while stun follows target endturn")
	gs=game();p=gs.player(0);foe=gs.player(1);target=foe.units[1];gs._grow_unit(target,0,30);hp=target.hp
	play(gs,"c18907",target.uid);check(target.hp==hp,"break only marks target, no area damage")
	gs._grow_unit(p.units[1],0,30);var power:int=p.units[1].attack
	gs._resolve_combat(0,1,0,false,false,false,false,target.uid,false,{"pursuit":true});gs._resolve_resolution_stack()
	check(target.hp==hp-2*power,"any ally attacking marked enemy gains actual critical")
	check(not gs.VerifiedRules.Combat.has(p.units[1],"crit") and not gs.VerifiedRules.Combat.has(p.units[1],"pierce"),"break does not grant permanent keywords")
	gs=game();p=gs.player(0);foe=gs.player(1);target=foe.units[1];target.front=1;target.hp=1;target.attack=0
	play(gs,"c18902");play(gs,"c18907",target.uid);check(gs.basic_attack(0,0),"hunt attacks marked front")
	check(target.hp==0 and foe.avatarHp==22,"hunt first critical overflows5 then ordinary second strike3 to avatar")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c18902");check(gs.basic_attack(0,0) and foe.avatarHp==27,"hunt does not combo against avatar")
	gs=game();p=gs.player(0);var deck:int=p.deck.size();play(gs,"c18903")
	check(p.units[0].charge==3 and p.deck.size()==deck-1 and p.hand.size()==1 and p.energy==39,"PNG harvest gives3 charge and real draw1, no ghost fire gain")
func response_rules() -> void:
	for enough in [false,true]:
		var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.units[0].front=1;p.energy=1 if enough else 0
		give(gs,"c18904");gs.current_player=1;gs.basic_attack(1,1)
		check(p.hand.size()==(0 if enough else 1) and p.energy==0,"response consumes one actual card/fire iff payable")
		check(foe.units[1].attack==(0 if enough else 3) and p.units[0].hp==(4 if enough else 1),"response targets actual attacker before damage")
		check(events(gs,"response-card").size()==(1 if enough else 0),"one actual automatic response event")
	var gs:=game();var p:Dictionary=gs.player(0);p.units[0].front=1;give(gs,"c18904");gs._resolve_combat(1,1,0,false,false,false,false);gs._resolve_resolution_stack()
	check(p.hand.is_empty() and p.units[0].hp==4 and p.energy==39 and events(gs,"response-card").size()==1,"seal also automatically responds and pays when attacked during own turn")
	gs=GS.create(["yujiazhu","limao","huajing","rihefang"],["limao","yaodaoji","fenghuanghuo","baizangzhu"],1892)
	for side in gs.players:
		side.hand.clear();side.energy=40;side.levelUpUsed=true
		for unit in side.units:unit.level=3;unit.charge=0
	gs.current_player=1
	check(gs.play_card(1,give(gs,"c24806",0,1)),"enemy actually enters drunkard form")
	check(gs.end_turn(1) and gs.current_player==0,"reactive attack fixture enters real own turn")
	p=gs.player(0);p.units[0].front=1;p.hand.clear();p.energy=2;give(gs,"c18904")
	check(gs.play_card(0,give(gs,"yaojiu"),gs.player(1).units[0].uid),"actual wine triggers enemy drunkard attack during own turn")
	check(events(gs,"response-card").size()==1 and p.hand.is_empty() and p.energy==1,"ownturn reactive enemy attack consumes one actual seal and one fire")
	check(p.units[0].hp==4 and gs.player(1).units[0].attack==0 and gs.player(1).units[0].frozen>0,"ownturn seal interrupts actual reactive attack before damage")
	gs=game();p=gs.player(0);p.units[0].front=1;p.units[0].charge=3;give(gs,"c18904",3);gs.current_player=1;gs._grow_unit(gs.player(1).units[1],0,10);var hp:int=gs.player(1).units[1].hp
	gs.basic_attack(1,1)
	check(p.units[0].charge==0 and p.units[0].shield==1 and gs.player(1).units[1].hp==hp-4,"stored arrow response applies one defender bonus without extra assault")
	gs=GS.create(["yujiazhu","xiaolunan","huajing","rihefang"],["tengji","bingyong","fenghuanghuo","baizangzhu"],1891)
	for side in gs.players:
		side.hand.clear();side.energy=40;side.levelUpUsed=true
		for unit in side.units:unit.level=3;unit.charge=0
	p=gs.player(0);p.units[0].charge=3;give(gs,"c22801",0,1)
	var h:=give(gs,"c18904",3)
	check(gs.play_card(0,h,gs.player(1).units[1].uid) and gs.response_window.get("action")=="assault","converted combat card opens genuine assault response window")
	check(gs.can_play_card(1,0,gs.player(1).units[1].uid).ok and gs.play_card(1,0,gs.player(1).units[1].uid),"opponent actually responds to converted card with vine attachment")
	var guard:=0
	while not gs.response_window.is_empty() and guard<8:gs.pass_response(int(gs.response_window.playerIndex));guard+=1
	check(gs.response_window.is_empty() and p.units[0].charge==0 and gs.player(1).hand.is_empty(),"converted card resumes and pays after real manual response")
func history_and_prayer() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	play(gs,"c18904",foe.units[1].uid);play(gs,"c18904",foe.units[1].uid);check(Yuj.history(gs,0).size()==1,"repeat same talisman has one distinct history")
	play(gs,"c18908");check(u.attack==4 and u.maxHp==7,"prayer3/6 plus one previouslyused type")
	play(gs,"c18907",foe.units[1].uid);check(u.attack==5 and u.maxHp==8,"new talisman updates live prayer body")
	formed(gs);play(gs,"c18901",foe.units[0].uid);check(u.attack==6 and u.maxHp==9 and Yuj.history(gs,0).size()==3,"third distinct type updates live prayer once")
	knock(gs,0,0);gs.VerifiedRules.Peach.revive(gs,0,3,u,false,false);check(u.attack==3 and u.maxHp==4 and Yuj.history(gs,0).size()==3,"history survives KO but form growth does not")
	var c:Dictionary=gs.hand_card_def(0,give(gs,"c18908"));check(c.value.attack==6 and c.value.hp==9,"new prayer reads historical types after KO")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];gs._grow_unit(foe.units[1],0,30)
	play(gs,"c18904",foe.units[2].uid);play(gs,"c18907",foe.units[2].uid);formed(gs);play(gs,"c18901",foe.units[0].uid);play(gs,"c18908")
	var h:int=p.hand.size();var fire:int=p.energy;var charge:int=u.charge;var hp:int=foe.units[1].hp
	check(gs.basic_attack_targets(0,0).has(foe.units[1].uid),"prayer target permits unformed enemy despite drive history")
	check(gs.basic_attack(0,0,foe.units[1].uid),"prayer actual selected deployment")
	check(events(gs,"automatic-card").size()==3 and p.hand.size()==h and p.energy==fire-1 and u.charge==charge,"prayer auto uses each history exactly once without cards or burst payment")
	check(foe.units[1].frozen==1 and foe.units[1].attack==0 and foe.units[1].hp==hp-12 and u.hp==9,"prayer resolves seal and break before combat damage and counter")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c18908");u.charge=3;gs._grow_unit(foe.units[1],0,20)
	play(gs,"c18904",foe.units[1].uid,3);check(events(gs,"automatic-card").is_empty(),"combat card attack is not prayer deployment")
func burst_discounts() -> void:
	for fields in range(5):
		var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0]
		for i in fields:play(gs,"c18906")
		u.charge=maxi(0,3-fields);var snapshot:=JSON.stringify(gs.snapshot());var q:=Yuj.quote_burst(gs,0,0,3)
		check(q.amount==maxi(0,3-fields) and q.nominalAmount==3 and q.ok,"stacked real realm quote "+str(fields))
		check(snapshot==JSON.stringify(gs.snapshot()),"burst quote is read-only "+str(fields))
		check(Yuj.pay_burst(gs,0,0,3) and u.charge==0,"discounted exact payment "+str(fields))
	var gs:=game();var p:Dictionary=gs.player(0);play(gs,"c18906");p.units[0].charge=2
	check(Yuj.can_pay_burst(gs,0,0,3) and not gs.VerifiedRules.SunSmoke.can_pay_charge(gs,0,0,3),"only explicit burst gets discount, not ordinary charge or focus")
	knock(gs,0,0);p.units[2].charge=2
	check(Yuj.can_pay_burst(gs,0,2,3),"realm discount continues with source KO")
	p.realms[0].hp=0;check(not Yuj.can_pay_burst(gs,0,2,3),"departed realm no longer discounts")
	gs=game();p=gs.player(0);play(gs,"c18906");p.units[1].charge=1;play(gs,"c16302",null,2)
	check(p.units[1].charge==0 and events(gs,"burst-used").back().amount==2,"movement burst uses reduced cost but nominal effect/history")
	gs=game();p=gs.player(0);play(gs,"c18906");p.units[2].charge=2;play(gs,"c27801",p.units[1].uid,3)
	check(p.units[2].charge==0 and p.hand.size()==1 and p.hand[0].definitionId=="c27802" and p.whaleBursts==1,"whale burst discount still generates actual opposite card")
	gs=game(["yujiazhu","xiazhongshaonv","shuweng","rihefang"]);p=gs.player(0);play(gs,"c18906");p.units[1].charge=9;play(gs,"c24305",null,10)
	check(p.units[1].charge==0 and p.units[1].maxHp==10 and events(gs,"burst-used").back().amount==10,"box burst10 remains full effect at actual9 energy")
	gs=game(["yujiazhu","yanyanluo","shuweng","rihefang"]);p=gs.player(0);play(gs,"c18906");p.units[1].charge=4;gs._grow_unit(gs.player(1).units[1],0,20);var hp:int=gs.player(1).units[1].hp
	play(gs,"c16401",gs.player(1).units[1].uid);check(gs.pending_choice.get("type")=="smoke-burst","smoke still asks actual burst choice")
	check(gs.resolve_divination_choice(0,"smoke-burst"),"choose smoke full-energy burst")
	check(p.units[1].charge==1 and gs.player(1).units[1].hp==hp-6 and events(gs,"burst-used").back().amount==4,"smoke full4 effect pays3 and retains1")
	gs=game();p=gs.player(0);p.units[3].awakened=true;play(gs,"c18906");p.units[0].charge=0;play(gs,"c18904",gs.player(1).units[1].uid,3)
	check(p.units[0].charge==0 and p.sunFreeChargeTurn==gs.turn_counter,"sun allowance waives discounted burst once")
	check(not Yuj.can_pay_burst(gs,0,0,3),"sun free charge cannot be reused")
func ai_rules() -> void:
	for n in range(1,9):
		var gs:=game();formed(gs);var id:="c189%02d"%n;gs.player(0).units[0].charge=3;give(gs,id)
		var best:Dictionary=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,int(best.hand),best.target).ok,"AI legal card and mode "+id)
		check(gs.play_card(0,int(best.hand),best.target),"AI actual card use "+id)
		check(not Content.card_def(id).verificationPending.is_empty(),"source uncertainty remains explicit "+id)
func settled(b) -> void:
	for i in 3:await process_frame
	while b._input_locked():await create_timer(b._presentation_remaining()+0.05).timeout
	await create_timer(0.3).timeout
func burst_face(b, name: String) -> Control:
	for f in faces(b._choice_layer):
		if f.data.get("name")==name:return f
	return null
func ui_rules() -> void:
	for n in range(18901,18909):
		var c:=preload("res://scripts/ui/card_face.gd").new();c.data=Content.card_def("c%d"%n);c.refresh_art()
		check(c._original_card!=null and c._original_card.resource_path=="res://assets/official/cards/c%d.png"%n,"actual original texture "+str(n));c.free()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["yujiazhu","xiaolunan","huajing","rihefang"],["bingyong","yaodaoji","fenghuanghuo","baizangzhu"],189);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.energy=40;side.levelUpUsed=true
			for u in side.units:u.level=3;u.charge=0
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var p:Dictionary=b.gs.player(0);var foe:Dictionary=b.gs.player(1);var u:Dictionary=p.units[0]
		for t in foe.units:b.gs._grow_unit(t,0,30)
		foe.units[0].front=1;u.charge=3;hand(b,["c18901"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b.gs.pending_choice.get("type")=="movement-burst" and p.energy==40 and u.charge==3,"native conversion choice does not pay yet")
		await capture("%d-01-arrow-choice"%physical.x)
		await click(burst_face(b,"爆能3"));await settled(b)
		check(b._pending_target_card==0 and b._pending_target_card_def.type=="combat" and b._unit_widget(foe.units[1].uid).selected,"native chosen arrow exposes real reserve targets")
		var hp:int=foe.units[1].hp;await click(b._unit_widget(foe.units[1].uid));await settled(b)
		check(u.charge==0 and foe.units[1].hp==hp-4 and p.hand.is_empty(),"native arrow selected combat pays once")
		hand(b,["c18906"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);u.charge=2
		hand(b,["c18904"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		var discounted:=burst_face(b,"爆能3")
		check(discounted!=null and discounted.data.currentCardStats=="爆能3 · 支付2能量","native discounted burst badge shows actual energy")
		await capture("%d-02-discounted-choice"%physical.x)
		await click(burst_face(b,"爆能3"));await settled(b);await click(b._unit_widget(foe.units[1].uid));await settled(b)
		check(u.charge==0 and foe.units[1].frozen==1 and foe.units[1].attack==0,"native seal arrow retains spell before battle")
		play(b.gs,"c18907",foe.units[2].uid);hand(b,["c18908"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(u.attack==6 and u.maxHp==9,"native prayer form reflects three actual talisman types")
		await click(b._unit_widget(u.uid));await settled(b)
		check(b._selected_attacker==0 and b._unit_widget(foe.units[2].uid).selected,"native prayer deployment exposes chosen enemy")
		await capture("%d-03-prayer-target"%physical.x)
		var count:int=events(b.gs,"automatic-card").size();await click(b._unit_widget(foe.units[2].uid));await settled(b)
		check(events(b.gs,"automatic-card").size()==count+3 and foe.units[2].frozen==1,"native deployment really reuses all three spells")
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme();charge_and_arrows();talisman_rules();response_rules();history_and_prayer();burst_discounts();ai_rules()
	if not only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("YUJIAZHU_OK checks=%d failures=%d rules_only=%s"%[checks,failures,only]);quit(0 if failures==0 else 1)
