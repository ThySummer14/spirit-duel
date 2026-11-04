extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Box:=preload("res://scripts/box_maiden_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("BOX_MAIDEN_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["xiazhongshaonv","shuweng","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],243)
	for p in gs.players:
		p.hand.clear();p.energy=30;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs,id: String,burst: int=0,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"box-test-%d"%gs.next_card_id,"definitionId":id,"movementBurst":burst});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,burst: int=0) -> void:
	check(gs.play_card(0,give(gs,id,burst),target),"actual play "+id)
func events(gs,kind: String) -> Array:return gs.rule_events.filter(func(e):return e.kind==kind)
func die(gs,value: int) -> void:
	for seed in range(1,100000):
		var next:=((seed*1664525+1013904223)&0xffffffff)
		if int(float(next)/4294967296.0*6)+1==value:gs.rng_state=seed;return
func knock(gs,owner: int,idx: int) -> void:gs._knockout_unit(gs.player(owner).units[idx],1-owner,0);gs._resolve_resolution_stack()
func settle_choices(gs) -> void:
	var count:=0
	while not gs.pending_choice.is_empty() and count<30:
		var choice_type:=str(gs.pending_choice.get("type",""))
		check(AI.take_action(gs,int(gs.pending_choice.playerIndex)),"AI resolves actual pending "+choice_type);count+=1
	check(gs.pending_choice.is_empty(),"choices complete without stuck stack")
func charge_rules() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0]
	check(u.attack==3 and u.maxHp==4 and u.passive_hooks.is_empty(),"original3/4 has no legacy surrogate passive")
	u.charge=0;die(gs,4);check(gs.VerifiedRules.Light.roll(gs,0,4,6,1),"actual ally fortune4 succeeds")
	check(u.charge==4,"die result supplies matching4 charge")
	die(gs,6);gs.VerifiedRules.Light.roll(gs,0,4,6,1);check(u.charge==4,"base once per globalturn")
	gs.turn_counter+=1;die(gs,3);gs.VerifiedRules.Light.roll(gs,0,4,6,1);check(u.charge==7,"failed fortune still gains dice3 on next globalturn")
	die(gs,6);gs.VerifiedRules.Light.roll(gs,1,4,6,0);check(u.charge==7,"enemy dice do not charge our box")
	u.charge=0;u.awakened=true
	for v in [2,3,6]:die(gs,v);gs.VerifiedRules.Light.roll(gs,0,6,6,1)
	check(u.charge==10,"awakened everyroll capped10")
	u.charge=0;u.baseRulesSuppressed=true;die(gs,4);gs.VerifiedRules.Light.roll(gs,0,1,6,1);check(u.charge==0,"suppressed base no dice charge")
	u.erase("baseRulesSuppressed");u.level=0;die(gs,4);gs.VerifiedRules.Light.roll(gs,0,1,6,1);check(u.charge==0,"unleveled base no charge")
	u.level=3;knock(gs,0,0);die(gs,4);gs.VerifiedRules.Light.roll(gs,0,1,6,1);check(u.charge==0,"KO base cannot gain charge")
	gs=game();p=gs.player(0);u=p.units[0];u.charge=9;gs.VerifiedRules.SunSmoke.begin_turn_charge(gs,0);check(u.charge==10,"native charging ownturn uses cap10")
	play(gs,"c24304");check(u.awakened and u.attack==4 and u.maxHp==5 and u.charge==10,"awakening printed1/1 andgain10")
	check(not gs.can_play_card(0,give(gs,"c24304")).ok,"duplicate awakening invalid")
func burst_cards() -> void:
	for burst in [0,10]:
		var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0];u.charge=10;gs._grow_unit(foe.units[1],0,20)
		var hp:int=foe.units[1].hp;var idx:=give(gs,"c24301",burst);var c:Dictionary=gs.hand_card_def(0,idx)
		check(gs.valid_targets(0,c).has(u.uid) and gs.valid_targets(0,c).has(foe.units[1].uid) and not gs.valid_targets(0,c).has("avatar-1"),"light targets bothside shikigami excludes avatar")
		check(gs.play_card(0,idx,foe.units[1].uid),"actual optional light burst")
		check(foe.units[1].hp==hp-(10 if burst==10 else 3),"light replaces3with10 exactly")
		check(u.charge==(0 if burst==10 else 10) and p.energy==29,"only explicitburst consumes10energy")
		check(events(gs,"burst-used").size()==(1 if burst==10 else 0),"onlyexplicitburst fires burstused event")
		gs=game();p=gs.player(0);u=p.units[0];u.charge=10;play(gs,"c24305",null,burst)
		check(u.attack==6 and u.hp==(10 if burst==10 else 5),"splendid original6/5 or6/10")
		check(u.charge==(0 if burst==10 else 10),"formburst consumes exactly10")
		knock(gs,0,0);gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false);check(u.attack==3 and u.maxHp==4,"burstformlife notpermanent after KO")
		gs=game();p=gs.player(0);u=p.units[0];u.charge=10;p.avatarHp=10;knock(gs,0,1);knock(gs,0,2);p.units[3].hp=1
		play(gs,"c24306",null,burst)
		check(p.units[1].hp==p.units[1].maxHp and p.units[2].hp==p.units[2].maxHp and p.units[3].hp==1,"reviveall revivesdead withouthealinglive")
		check(p.avatarHp==(20 if burst==10 else 10),"burstrevive restores onlyfriendlyavatar10")
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];u.charge=9;var idx:=give(gs,"c24301",10)
	check(not gs.can_play_card(0,idx,gs.player(1).units[0].uid).ok,"insufficientburst rejectedbeforepayment")
	u.charge=10;p.nullifyNextCardTurn=gs.turn_counter;var hp:int=gs.player(1).units[0].hp
	check(gs.play_card(0,idx,gs.player(1).units[0].uid),"nullified burst still legal play")
	check(u.charge==0 and p.energy==29 and gs.player(1).units[0].hp==hp,"nullified burst pays charge/fire but effectcountered")
	gs=game();u=gs.player(0).units[0];u.charge=10;var c:Dictionary=Content.card_def("c24301").duplicate(true);c.movementBurst=10
	Box.pay_card(gs,0,0,c);u.charge=0;gs._grow_unit(gs.player(1).units[1],0,20);hp=gs.player(1).units[1].hp
	check(c.boxBurstPaid,"burst payment frozen on actualcard")
	Box.resolve_action(gs,0,0,c,c.effects[0],gs.player(1).units[1].uid);check(gs.player(1).units[1].hp==hp-10,"later lackenergy never cancels already paidburst")
	gs=game();u=gs.player(0).units[0];knock(gs,0,2);gs.player(0).units[2].samuraiCannotRevive=true;play(gs,"c24306")
	check(gs.player(0).units[2].hp==0,"revival prohibition honored")
func response_and_charge_boundaries() -> void:
	# An actual automatic response, not merely a preset nullification flag.
	var gs:=GS.create(["xiazhongshaonv","shuweng","taohuayao","xuenv"],["yaoginshi","fenghuanghuo","yaodaoji","baizangzhu"],243)
	for side in gs.players:
		side.hand.clear();side.energy=20;side.levelUpUsed=true
		for unit in side.units:unit.level=3
	var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	u.charge=10;give(gs,"c12807",0,1);var target:Dictionary=foe.units[1];var hp:int=target.hp
	play(gs,"c24301",target.uid,10)
	check(foe.hand.is_empty() and events(gs,"response-card").size()==1,"counter is a genuinely used enemy response")
	check(target.hp==hp and u.charge==0 and p.energy==19 and events(gs,"card-nullified").size()==1,"selected burst pays on announcement, counter blocks actual damage")
	check(gs.resolution_stack.is_empty() and gs.response_window.is_empty(),"response leaves no stuck burst frame")
	# 日和坊's shared first-payment waiver must make a burst legal without charge.
	gs=GS.create(["xiazhongshaonv","shuweng","rihefang","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],243)
	for side in gs.players:
		side.hand.clear();side.energy=20;side.levelUpUsed=true
		for unit in side.units:unit.level=3
	p=gs.player(0);foe=gs.player(1);u=p.units[0];p.units[2].awakened=true;u.charge=0
	gs._grow_unit(foe.units[1],0,20);hp=foe.units[1].hp;var idx:=give(gs,"c24301",10)
	check(gs.can_play_card(0,idx,foe.units[1].uid).ok,"sun waiver allows burst with no stored charge")
	check(gs.play_card(0,idx,foe.units[1].uid),"sun waiver actual burst")
	check(foe.units[1].hp==hp-10 and u.charge==0 and int(p.get("sunFreeChargeTurn",-1))==gs.turn_counter,"waived burst resolves ten damage and uses one waiver")
	idx=give(gs,"c24301",10);check(not gs.can_play_card(0,idx,foe.units[1].uid).ok,"second burst cannot reuse the waiver")
	# Both physical throws in a reroll count for awakened charging; the base triggers only on the first.
	for awakened in [false,true]:
		gs=GS.create(["xiazhongshaonv","zuofutongzi","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],243)
		for unit in gs.player(0).units:unit.level=3
		p=gs.player(0);u=p.units[0];u.awakened=awakened;u.charge=0;die(gs,1)
		gs.VerifiedRules.Light.roll(gs,0,4,6,1)
		var record:Dictionary=gs.kw_usage(0,"fortune").last
		check(record.rerolled and record.firstRoll==1,"seat base rerolls an actual first roll of one")
		check(u.charge==mini(10,1+(int(record.roll) if awakened else 0)),"each actual die follows base or awakened charging limit")
	gs=GS.create(["xiazhongshaonv","qingwa-ciqi","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],243)
	for side in gs.players:
		side.hand.clear();side.energy=20;side.levelUpUsed=true
		for unit in side.units:unit.level=3
	p=gs.player(0);u=p.units[0];u.charge=0;p.units[1].awakened=true;play(gs,"c24303");var token_index:int=gs.front_index(0)
	die(gs,4);check(gs.basic_attack(0,token_index),"summon attacks with awakened frog on field")
	check(gs.player(1).avatarHp==22 and u.charge==4,"doubled fortune adds the dice power twice without rolling twice")
func turn_boundaries() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0]
	die(gs,3);play(gs,"c24302");u.charge=10;var hand_size:int=p.hand.size()
	check(gs.end_turn(0),"actual end turn with treasure")
	check(u.charge==0 and p.hand.size()==hand_size+1 and gs.current_player==1,"treasure consumes energy and draws before turn changes")
	gs=game();p=gs.player(0);u=p.units[0];die(gs,3);play(gs,"c24308");u.charge=10
	var hp:int=gs.player(1).avatarHp
	check(gs.end_turn(0),"actual end turn with brilliant")
	check(u.charge==0 and gs.player(1).avatarHp==hp-10 and gs.current_player==1,"brilliant pays and projects before turn changes")
func forms_and_summon() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
	die(gs,3);play(gs,"c24302");check(u.attack==3 and u.hp==6 and gs.pending_choice.is_empty() and u.charge>=3,"treasure failedentry no scry butdicecharge")
	die(gs,4);play(gs,"c24302");check(gs.pending_choice.get("type")=="native-divination" and gs.pending_choice.count==3,"successful treasure creates real scry3")
	var size:int=p.deck.size();settle_choices(gs);check(p.deck.size()==size,"scry rearranges real deck no fictitiousdraw")
	u.charge=9;var hand_size:int=p.hand.size();Box.end_turn(gs,0);gs._resolve_resolution_stack();check(p.hand.size()==hand_size and u.charge==9,"treasure cannot pay9")
	u.charge=10;Box.end_turn(gs,0);gs._resolve_resolution_stack();check(p.hand.size()==hand_size+1 and u.charge==0,"treasure consumes10 drawsone")
	check(events(gs,"burst-used").is_empty(),"form automaticenergy payment isnotburst")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];p.energy=1;die(gs,4);play(gs,"c24308")
	check(u.attack==7 and u.hp==7 and p.energy==1 and gs.VerifiedRules.Combat.has(u,"penetration"),"brilliant7/7 entryfortune gainfire and penetration")
	var fire:int=p.energy;die(gs,2);Box.form_turn_start(gs,0,0);check(p.energy==fire,"failedturnstart nofire")
	die(gs,5);Box.form_turn_start(gs,0,0);check(p.energy==fire+1,"successfulturnstart gives1fire")
	p.energy=4;die(gs,5);Box.form_turn_start(gs,0,0);check(p.energy==4,"fortune fire honors shared maximum")
	u.charge=10;foe.units[0].front=1;foe.units[0].shield=20;foe.units[0].barrier=true;Box.end_turn(gs,0);gs._resolve_resolution_stack()
	check(foe.units[0].hp==0 and foe.avatarHp==30 and u.charge==0,"brilliant end10projectile penetration destroysfront nooverflow")
	u.charge=10;Box.end_turn(gs,0);gs._resolve_resolution_stack();check(foe.avatarHp==20,"unblockedprojectile hits enemyavatar10")
	gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];u.charge=0;play(gs,"c24303");var idx:int=gs.front_index(0);var token:Dictionary=p.units[idx]
	check(idx==4 and token.name=="惜物" and token.attack==0 and token.hp==4 and token.boxSummon,"opens actual0/4summon front")
	check(p.units.slice(0,4).all(func(x):return x.front==0),"summon replaces front without nativeunit deletion")
	die(gs,4);check(gs.basic_attack(0,idx),"summon actualbasicattack")
	check(foe.avatarHp==26 and token.attack==0 and u.charge==4,"summon rolls4 gets combatonlypower andfeeds ownercharge")
	gs.current_player=1;gs.turn_counter+=1;foe.energy=30;foe.attackUsed=false;foe.units[0].level=3;foe.units[0].attack=1
	die(gs,5);check(gs.basic_attack(1,0),"enemy actualattack summon")
	check(foe.units[0].hp==1 and token.hp==3 and token.attack==0 and u.charge==9,"summon defensivefortune5 counters5 onlythiscombat")
	check(events(gs,"box-combat-fortune").size()==2,"exactlyonefortune perattack ordefense")
	gs.VerifiedRules.Movement.move_to(gs,0,idx,0);check(token.removed and token.hp==0 and token.knockout==0,"forcedretreat removes actualsummon noKOcountdown")
	gs=game();p=gs.player(0);play(gs,"c24303");token=p.units[4];play(gs,"c24303");check(token.removed and gs.front_index(0)==5,"newboxreplaces oldsummon")
	knock(gs,0,5);check(p.units[5].removed and p.units[5].knockout==0,"summondeath removed no future revival")
func pack_and_ai() -> void:
	for burst in [0,10]:
		var gs:=game();var p:Dictionary=gs.player(0);p.units[0].charge=10;knock(gs,0,1);var idx:=give(gs,"c24307",burst);var c:Dictionary=gs.hand_card_def(0,idx)
		check(gs.valid_targets(0,c).has(p.units[1].uid) and not gs.valid_targets(0,c).has(gs.player(1).units[0].uid),"packcanchoose KO ally excludesenemy")
		var deck:int=p.deck.size();check(gs.play_card(0,idx,p.units[1].uid),"pack actual target ownbook")
		check(p.energy==30,"packinstant first free")
		if burst==0:
			check(gs.pending_choice.get("type")=="box-pack" and gs.pending_choice.instanceIds.size()==5 and p.hand.is_empty(),"normalpack presents five before chooseone")
			var choice:Dictionary=gs.pending_choice;var first:=str(choice.instanceIds[0]);var wanted:=str(choice.cards[first])
			check(not gs.resolve_divination_choice(1,first) and not gs.resolve_divination_choice(0,"foreign"),"pack ownership andcandidate validation")
			check(gs.resolve_divination_choice(0,first) and p.hand.size()==1 and p.hand[0].definitionId==wanted,"chooses actual candidate intohand")
		else:check(gs.pending_choice.is_empty() and p.hand.size()==5 and p.units[0].charge==0,"burstpack takesall5 withoutpickdialog")
		check(p.hand.all(func(i):return Content.card_def(i.definitionId).unitId=="shuweng") and p.deck.size()==deck,"packcreates selectedunitcards notdeckdraw")
	var gs:=game();var p:Dictionary=gs.player(0)
	for n in 11:give(gs,"c24303")
	p.units[0].charge=10;play(gs,"c24307",p.units[0].uid,10);check(p.hand.size()==12 and events(gs,"box-pack-card").filter(func(e):return e.kept).size()==1,"all5pack respects handlimit andburns extras")
	gs=game();p=gs.player(0);play(gs,"c24303");var idx:=give(gs,"c24307");check(not gs.valid_targets(0,gs.hand_card_def(0,idx)).has(p.units[4].uid),"cannotopen summoncardpack")
	for number in range(24301,24309):
		gs=game();p=gs.player(0);p.units[0].charge=10;p.avatarHp=10;knock(gs,0,1);var id:="c%d"%number;give(gs,id)
		var best:Dictionary=AI._best_card(gs,0);check(best.ok and best.card_id==id,"AI seeslegal "+id)
		if best.ok:check(gs.play_card(0,best.hand,best.target),"AI chosen actualplay "+id);settle_choices(gs)
func named_face(b,name: String) -> Control:
	for face in faces(b._choice_layer):
		if face.data.get("name")==name:return face
	return null
func settled(b) -> void:
	for i in 3:await process_frame
	while b._input_locked():await create_timer(b._presentation_remaining()+0.05).timeout
	await create_timer(0.4).timeout
func native_ui() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["xiazhongshaonv","shuweng","taohuayao","xuenv"],["bingyong","fenghuanghuo","yaodaoji","baizangzhu"],243);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.energy=30;side.levelUpUsed=true
			for u in side.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var p:Dictionary=b.gs.player(0);var foe:Dictionary=b.gs.player(1);p.units[0].charge=10;b.gs._grow_unit(foe.units[1],0,20)
		hand(b,["c24301"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b.gs.pending_choice.get("type")=="movement-burst" and named_face(b,"爆能10")!=null,"native burst10 alternative shown")
		check(p.energy==30 and p.units[0].charge==10,"native selection modal no prematurecharge")
		await capture("%d-01-burst-choice"%physical.x);await click(named_face(b,"爆能10"));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(foe.units[1].uid).selected,"native burstthen actualtarget highlight")
		var hp:int=foe.units[1].hp;await click(b._unit_widget(foe.units[1].uid));await settled(b)
		check(foe.units[1].hp==hp-10 and p.units[0].charge==0 and p.energy==29,"native selectedenemy fullburst10")
		hand(b,["c24307"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);await click(named_face(b,"普通使用"));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(p.units[1].uid).selected and not b._unit_widget(foe.units[0].uid).selected,"native packtargets onlyfriendly")
		await click(b._unit_widget(p.units[1].uid));await settled(b)
		check(b.gs.pending_choice.get("type")=="box-pack" and faces(b._choice_layer).size()==5,"native fivepack actualtiles")
		await capture("%d-02-pack-choice"%physical.x);var wanted:String=b.gs.pending_choice.cards[b.gs.pending_choice.instanceIds[0]];await click(faces(b._choice_layer)[0]);await settled(b)
		check(p.hand.size()==1 and p.hand[0].definitionId==wanted and b.gs.pending_choice.is_empty(),"native selectedactualpackcard")
		hand(b,["c24303"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);var fi:int=b.gs.front_index(0)
		check(fi>=4 and p.units[fi].boxSummon and b._unit_widget(p.units[fi].uid)!=null,"native realxiwu unitwidget front")
		await capture("%d-03-xiwu"%physical.x)
		b.queue_free();await process_frame;await process_frame
func textures() -> void:
	for n in range(24301,24309):
		var tile=preload("res://scripts/ui/card_face.gd").new();tile.data=Content.card_def("c%d"%n);tile.refresh_art()
		check(tile._original_card!=null and tile._original_card.resource_path=="res://assets/official/cards/c%d.png"%n,"actualtexture originalcard "+str(n));tile.free()
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	if not args.is_empty() and not rules_only:out=args[0];DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	charge_rules();burst_cards();response_and_charge_boundaries();turn_boundaries();forms_and_summon();pack_and_ai()
	if not rules_only:textures();await native_ui()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("BOX_MAIDEN_OK checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
