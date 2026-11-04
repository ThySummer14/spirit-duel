extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Rebirth := preload("res://scripts/rebirth_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("REBIRTH_FAIL ",detail)

func game() -> GS:
	var gs := GS.create(["jiumingmao","huangkulou","taohuayao","gitongwan"],["yaodaoji","bingyong","taohuayao","gitongwan"],201226)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs

func inst(gs, id: String) -> Dictionary:
	var entry := {"definitionId":id,"instanceId":"rebirth-%d" % gs.next_card_id}; gs.next_card_id+=1; return entry

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(inst(gs,id)); return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func hit(gs, idx: int, owner: int = 0) -> void:
	gs._damage_unit(owner,idx,100,1-owner,0); gs._resolve_resolution_stack()

func cat_lives() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var cat: Dictionary=p.units[0]
	check(cat.attack==3 and cat.maxHp==2,"cat exact3/2 baseline")
	for n in 4:
		hit(gs,0); check(cat.hp==2 and cat.knockout==0 and cat.catLives==n+1,"each real death revives full and attaches one life %d" % n)
	var survivor := inst(gs,"c20107"); survivor.retained=99
	p.hand=[inst(gs,"c20101"),survivor,inst(gs,"c10801")]; p.deck=[inst(gs,"c20108"),inst(gs,"c22602"),inst(gs,"c20107")]
	hit(gs,0)
	check(cat.hp==0 and cat.catLives==5 and cat.catCannotRevive,"fifth life genuinely prevents revival")
	check(p.hand.size()==2 and p.hand.has(survivor) and survivor.retained==99 and p.deck.size()==2,"only own ordinary cards removed, both survival instances and metadata retained")
	check(not gs.VerifiedRules.Peach.revive(gs,0,2,cat),"ordinary resurrection cannot bypass permanent knockout")
	var timer: int=cat.knockout; gs.VerifiedRules.reduce_countdown(gs,0,0,30)
	check(cat.hp==0 and cat.knockout==timer,"countdown reduction cannot bypass cannot-revive")
	gs._begin_turn(0); p.levelUpUsed=true
	check(cat.hp==0 and cat.knockout==timer,"real turn-start cannot naturally revive locked cat")
	check(gs.can_play_card(0,p.hand.find(survivor)).ok,"survival remains legal from permanently knocked source")
	check(gs.play_card(0,p.hand.find(survivor)),"actual survivor play")
	check(cat.hp==3 and cat.attack==4 and cat.catLives==2 and not cat.catCannotRevive and Rebirth.swift(cat),"survival permanent1/1 two lives and swift")
	check(p.hand.filter(func(i):return Content.card_def(i.definitionId).unitId=="jiumingmao").size()==2,"two real random own combat cards generated")
	p.energy=0; check(gs.can_basic_attack(0,0).ok and gs.basic_attack(0,0) and p.energy==0,"permanent swift really grants free ordinary attack")
	hit(gs,0); check(cat.attack==4 and cat.maxHp==3 and cat.catLives==3 and Rebirth.swift(cat),"permanent growth and swift survive subsequent death")
	gs=game(); check(not gs.can_play_card(0,give(gs,"c20107")).ok,"survival not legal before cannot-revive condition")
	gs=game(); p=gs.player(0); cat=p.units[0]; cat.level=0; hit(gs,0)
	check(cat.hp==0 and not cat.has("catLives"),"inactive cat cannot gain passive resurrection")
	gs=game(); p=gs.player(0); cat=p.units[0]; gs.VerifiedRules.Fortune.transform(gs,0,0,true); hit(gs,0)
	check(cat.hp==0 and not cat.has("catLives"),"paper transformation suppresses passive even when base restored by death")

func cat_cards() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var cat: Dictionary=p.units[0]
	play(gs,"c20101"); check(gs.player(1).avatarHp==26,"unconditional claw only+1")
	gs=game(); p=gs.player(0); cat=p.units[0]; cat.catLives=2; play(gs,"c20101"); check(gs.player(1).avatarHp==24,"two lives enhance actual claw+3")
	gs=game(); p=gs.player(0); cat=p.units[0]; cat.catLives=3; play(gs,"c20102")
	check(cat.attack==6 and cat.maxHp==4,"bell installs actual3+lives/4 body")
	play(gs,"c20103"); check(cat.attack==6 and cat.maxHp==4,"extend exact6/4")
	check(gs.end_turn(0) and cat.catLives==2,"extend removes one life at own end")
	check(gs.end_turn(1) and cat.catLives==1,"extend also removes one at enemy end")
	gs=game(); p=gs.player(0); cat=p.units[0]; play(gs,"c20104"); check(p.energy==40 and cat.attack==3 and cat.maxHp==3,"car real instant3/3")
	p.units[2].front=1; hit(gs,2)
	check(cat.catLives==1 and cat.front==1 and p.units[2].hp==p.units[2].maxHp and p.units[2].front==0,"car moves cat into front and actually resurrects other front shikigami")
	hit(gs,3); check(cat.catLives==1,"car does not trigger on reserve death")
	gs=game(); p=gs.player(0); cat=p.units[0]; play(gs,"c20108"); check(cat.attack==4 and cat.maxHp==3,"cat awake exact1/1")
	hit(gs,0); check(cat.hp==3 and cat.catLives==1 and gs.player(1).avatarHp==26,"awake cat resurrects then makes actual free attack")
	gs=game(); p=gs.player(0); cat=p.units[0]; var foe: Dictionary=gs.player(1)
	gs._grow_unit(foe.units[2],10,30); var before: int=foe.units[2].hp
	play(gs,"c20106",foe.units[2].uid)
	check(foe.units[2].hp==before-8 and cat.catLives==2 and cat.hp==2,"dance first+2 then ordinary attack, actual deaths do not stop second attack")
	check(gs.rule_events.filter(func(e):return e.kind=="combat-complete" and e.uid==cat.uid).size()==2,"dance is two real attacks, not one damage/combo mapping")
	gs=game(); p=gs.player(0); cat=p.units[0]; foe=gs.player(1); cat.catLives=4; gs._grow_unit(foe.units[2],10,30); before=foe.units[2].hp
	play(gs,"c20106",foe.units[2].uid); check(foe.units[2].hp==before-5 and cat.catCannotRevive,"cannot-revive actually cancels impossible second attack")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[2].hp=1
	play(gs,"c20106",foe.units[2].uid); check(foe.avatarHp==30,"dance does not invent a face target after original target killed")
	gs=game(); p=gs.player(0); foe=gs.player(1); cat=p.units[0]; gs._grow_unit(foe.units[0],8,30); foe.units[0].front=1; before=foe.units[0].hp
	play(gs,"c20105"); check(foe.units[0].hp==before-7 and cat.catLives==1 and cat.hp==2,"revenge real+1 battle then immune ordinary retaliation after death")
	gs=game(); p=gs.player(0); foe=gs.player(1); cat=p.units[0]; cat.front=1; give(gs,"c20105"); gs.current_player=1; gs._grow_unit(foe.units[0],8,30); before=foe.units[0].hp
	check(gs.basic_attack(1,0),"enemy actual ordinary attack triggers revenge response")
	check(p.hand.is_empty() and p.energy==39 and foe.units[0].hp==before-7 and cat.hp==2,"revenge response modifies defense and retaliates without extra hand attack")

func skeleton_cards() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[1]
	check(u.attack==2 and u.maxHp==5,"skeleton exact2/5 baseline")
	hit(gs,1); check(u.hp==0,"skeleton does not revive without form or spell")
	check(gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false) and u.front==1,"external revive uses real passive movement")
	gs=game(); p=gs.player(0); u=p.units[1]; play(gs,"c22603"); check(u.attack==4 and u.maxHp==6,"summon4/6 exact")
	hit(gs,1); check(u.hp==5 and u.front==1 and u.form.is_empty(),"departing form revives base body once, no form reattachment")
	hit(gs,1); check(u.hp==0,"consumed resurrection form not infinite")
	gs=game(); p=gs.player(0); u=p.units[1]; u.front=1; play(gs,"c22603"); check(p.energy==40,"front conditional instant costs zero")
	gs=game(); p=gs.player(0); u=p.units[1]; hit(gs,1); u.knockout=1; var foe: Dictionary=gs.player(1); var before: int=foe.units[2].hp
	play(gs,"c22602",foe.units[2].uid); check(foe.units[2].hp==before-3 and u.hp==5 and u.front==1,"question deals real3 then countdown reduction revives and moves")
	gs=game(); p=gs.player(0); u=p.units[1]; check(not gs.can_play_card(0,give(gs,"c22604")).ok,"loyalty illegal on living source")
	p.hand.clear(); hit(gs,1); play(gs,"c22604"); check(u.hp==5 and u.front==1 and u.shield==4,"loyalty real revive movement then4armor")
	gs=game(); p=gs.player(0); u=p.units[1]; hit(gs,1); give(gs,"c22604"); gs.current_player=1; before=p.avatarHp
	check(gs.basic_attack(1,0),"enemy attacks real empty front")
	check(p.avatarHp==before and u.hp==5 and u.shield==1 and p.hand.is_empty(),"dead source automatic loyalty intercepts avatar attack with real front and armor")
	gs=game(); p=gs.player(0); u=p.units[1]; hit(gs,1); u.knockout=3; foe=gs.player(1); foe.units[0].hp=1; foe.units[1].hp=1
	play(gs,"c22605"); check(u.knockout==1 and u.hp==0 and foe.units[0].hp==0 and foe.units[1].hp==0 and foe.avatarHp==30,"feast actual enemy-only2AOE, one countdown reduction per kill")
	gs=game(); p=gs.player(0); u=p.units[1]; play(gs,"c22606"); check(u.attack==4 and u.maxHp==7,"bones actual4/7")
	check(gs.end_turn(0) and u.hp==7,"bones survives own end")
	check(gs.end_turn(1) and u.hp==0,"bones genuinely knocks out at enemy end")
	gs=game(); p=gs.player(0); u=p.units[1]; u.front=1; foe=gs.player(1); play(gs,"c22601")
	check(foe.avatarHp==26 and foe.units[2].hp==foe.units[2].maxHp-1,"fog front enhancement real battle then1damage to all enemy characters")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c22601")
	check(foe.avatarHp==27 and foe.units[2].hp==foe.units[2].maxHp,"reserve fog has no enhanced AOE")
	gs=game(); p=gs.player(0); u=p.units[1]; foe=gs.player(1); foe.units[1].front=1; gs._grow_unit(u,0,30); gs._grow_unit(foe.units[1],0,30)
	play(gs,"c22607"); var targets: Array=gs.rule_events.filter(func(e):return e.kind=="combat-hit" and e.uid==u.uid)
	check(targets.size()==3 and targets[0].target==foe.units[1].uid and targets[1].target!="" and targets[1].target!=foe.units[1].uid and targets[2].target=="","flower really attacks front, random reserve then avatar")
	check(foe.avatarHp==25,"flower final forced avatar attack keeps original+3combat bonus")
	gs=game(); p=gs.player(0); u=p.units[1]; foe=gs.player(1); foe.units[0].front=1; gs._grow_unit(foe.units[0],20,30)
	play(gs,"c22607"); check(u.hp==0 and foe.avatarHp==30,"flower stops after source death")
	gs=game(); p=gs.player(0); u=p.units[1]; hit(gs,1); play(gs,"c22608")
	check(u.awakened and u.attack==4 and u.maxHp==7 and u.hp==0,"awake usable while dead, exact2/2 does not fake revive")
	gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false)
	check(u.attack==5 and u.maxHp==8 and u.hp==8 and u.front==1,"awake actual revive grants permanent1/1 then movement")
	hit(gs,1); gs.VerifiedRules.Peach.revive(gs,0,2,u,false,false)
	check(u.attack==6 and u.maxHp==9,"awake permanent revival growth stacks across deaths")

func incarnation_rules() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[1]
	hit(gs,1); play(gs,"c22608"); u.knockout=20; var before: int=p.energy; var hand_size: int=p.hand.size(); var deck: int=p.deck.size()
	var pool := Rebirth.incarnation_pool(gs,0,1)
	check(pool.size()==3 and pool.all(func(c):return c.type=="spell" and c.allowKnockedSource and c.type!="awakening"),"incarnation pool only question loyalty feast, never awakening or forms")
	for i in 5:
		if int(u.get("incarnationUsedTurn",-1))==gs.turn_counter: break
		Rebirth.incarnation(gs,0,true); gs._resolve_resolution_stack()
	check(gs.rule_events.any(func(e):return e.kind=="incarnation-card"),"accumulating20percent guaranteed within five eligible turn-start checks")
	check(p.energy==before and p.hand.size()==hand_size and p.deck.size()==deck,"incarnation generates and actually casts without consuming hand deck fire")
	var count: int=gs.rule_events.filter(func(e):return e.kind=="incarnation-card").size()
	for i in 15: Rebirth.incarnation(gs,0,false); gs._resolve_resolution_stack()
	check(gs.rule_events.filter(func(e):return e.kind=="incarnation-card").size()==count,"incarnation at most once per player turn, no recursive generated chain")
	gs=game(); p=gs.player(0); u=p.units[1]; play(gs,"c22608"); Rebirth.incarnation(gs,0,true)
	check(not u.has("incarnationChance"),"living skeleton cannot incarnate")
	hit(gs,1); u.frozen=1; Rebirth.incarnation(gs,0,true); check(not u.has("incarnationChance"),"stunned skeleton cannot incarnate")
	u.frozen=0; gs.current_player=1; Rebirth.incarnation(gs,0,true); check(not u.has("incarnationChance"),"opponent turn never rolls own incarnation")
	gs.current_player=0; u.incarnationChance=92; p.units[0].catCannotRevive=true
	play(gs,"c20101"); check(gs.rule_events.any(func(e):return e.kind=="incarnation-card"),"real hand card completion triggers8percent incarnation check")

func ai_and_status() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var cat: Dictionary=p.units[0]
	cat.catCannotRevive=true; cat.catLives=5; cat.hp=0; give(gs,"c20107")
	var chosen: Dictionary=AI._best_card(gs,0)
	check(chosen.ok and chosen.card_id=="c20107" and gs.can_play_card(0,chosen.hand,chosen.target).ok,"AI chooses legal survival from locked cat")
	var marks := Status.unit_marks(Status.unit_view(gs,0,0,0),gs.turn_counter)
	check(marks.any(func(m):return m.id=="cat-lives" and m.value==5) and marks.any(func(m):return m.id=="knockout" and "永久" in m.label),"live UI shows life count and cannot-revive rather than false normal countdown")
	gs=game(); p=gs.player(0); p.hand=[inst(gs,"c20106")]; var foe: Dictionary=gs.player(1)
	foe.units[2].keywords=["veil"]
	var targets: Array=gs.valid_targets(0,gs.hand_card_def(0,0))
	check(not targets.has("avatar-1") and not targets.has(foe.units[2].uid),"pursuit UI and AI share exact legal shikigami targets including veil")
	chosen=AI._best_card(gs,0); check(chosen.ok and targets.has(chosen.target) and gs.play_card(0,chosen.hand,chosen.target),"AI legally executes actual dance")
	for id in ["c20101","c20102","c20103","c20104","c20105","c20106","c20107","c20108","c22601","c22602","c22603","c22604","c22605","c22606","c22607","c22608"]:
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original full card art "+id)

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["jiumingmao","huangkulou","taohuayao","gitongwan"],["yaodaoji","bingyong","taohuayao","gitongwan"],201226); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		gs._grow_unit(foe.units[2],10,30); var hp: int=foe.units[2].hp
		hand(b,["c20106"]); await settled(b)
		check(b._hand_row.get_child(0).original_stat_changes()=="首击+2 · 续击+0","native current stats override differing printed art numbers")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[2].uid)).selected,"native pursuit shows actual reserve as legal target")
		if physical.x==1600: await capture("01-cat-dance-original-target")
		await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp==hp-8 and p.units[0].catLives==2 and gs.pending_choice.is_empty(),"native target click executes both attacks and resurrects after each death")
		for i in 3: hit(gs,0)
		hand(b,["c20107"]); await settled(b)
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(texts(b).contains("永久气绝") and texts(b).contains("5/5"),"native permanent knockout and actual nine-lives count visible")
		if physical.x==1280: await capture("02-cat-permanent-knockout-survival")
		escape(); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].hp==3 and p.units[0].catLives==2 and p.hand.size()==2,"native survival works from permanent knockout, actual generated cards shown")
		hit(gs,1); hand(b,["c22604"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[1].hp==5 and p.units[1].shield==4 and p.units[1].front==1,"native dead-source loyalty revives, moves, grants armor")
		if physical.x==1600: await capture("03-skeleton-real-revival-movement")
		hit(gs,1); p.units[1].knockout=1; p.energy=40; hand(b,["c22602"]); await settled(b)
		hp=foe.units[2].hp; await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[2].uid)).selected,"native dead-source question offers actual enemy character targets")
		await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp==hp-3 and p.units[1].hp==5 and p.units[1].front==1,"native question target deals3 and real countdown revival movement")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out=OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	cat_lives(); cat_cards(); skeleton_cards(); incarnation_rules(); ai_and_status(); await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("REBIRTH checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
