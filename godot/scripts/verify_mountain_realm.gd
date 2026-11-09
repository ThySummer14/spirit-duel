extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Mountain := preload("res://scripts/mountain_realm_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("MOUNTAIN_FAIL ",detail)

func game() -> GS:
	var gs:=GS.create(["bujianyue","huang","taohuayao","yaodaoji"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],280)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs

func give(gs, id: String, owner: int=0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"mountain-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target=null, owner: int=0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func destroy(gs, idx: int=0, owner: int=0) -> void:
	gs.VerifiedRules.Huang.destroy(gs,owner,gs.player(owner).realms[idx],"专项验证消灭"); gs._resolve_resolution_stack()

func entries_and_destruction() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	check(p.units[0].attack==2 and p.units[0].hp==5,"base exact2/5")
	var u: Dictionary=foe.units[0]; var hp: int=u.hp; p.avatarHp=20
	play(gs,"c28001",u.uid)
	check(u.hp==hp-3 and p.realms.size()==1 and p.realms[0].hp==3,"cloud real chosen3damage and3durability")
	check(gs.end_turn(0) and gs.end_turn(1) and p.avatarHp==20,"cloud has no invented owner-start healing")
	destroy(gs); check(p.avatarHp==23 and p.realms.is_empty(),"cloud heals avatar3 only when actually destroyed")
	check(p.mountainDestroyedRealms.size()==1,"actual destroyed realm added to match history")
	var before: int=p.avatarHp; gs.VerifiedRules.Huang.destroy(gs,0,{"uid":"fake"},"不存在")
	check(p.avatarHp==before and p.mountainDestroyedRealms.size()==1,"missing/duplicate destruction cannot re-trigger or add history")
	gs=game(); p=gs.player(0); foe=gs.player(1)
	u=foe.units[0]; u.level=0
	var cloud := give(gs,"c28001")
	check(gs.play_card(0,cloud,u.uid) and u.hp==u.maxHp-3,"山云入场可实际指定存活的零勾式神")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c28001",foe.units[0].uid); p.avatarHp=20
	check(gs._damage_avatar(0,2,1,0)==2 and p.avatarHp==18 and p.realms[0].hp==1,"real avatar damage reduces front realm durability without premature departure")
	check(gs._damage_avatar(0,3,1,0)==3 and p.avatarHp==18 and p.realms.is_empty(),"real durability knockout destroys cloud and heals3 after actual avatar loss")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c28002")
	check(gs.kw_usage(0,"encourage").attack==2 and gs.kw_usage(0,"encourage").shield==2 and p.units[0].attack==2,"mountain color grants actual shared encourage2/2 without fake permanent growth")
	gs._knockout_unit(p.units[2]); p.units[2].knockout=2; gs._knockout_unit(p.units[3]); p.units[3].knockout=4
	destroy(gs)
	check(p.units[2].hp==0 and p.units[3].hp==p.units[3].maxHp and p.units[3].knockout==0 and p.units[3].front==0,"color revives exact maximum countdown unit full in reserve")
	gs=game(); p=gs.player(0); play(gs,"c28002"); gs._knockout_unit(p.units[2]); p.units[2].knockout=8; p.units[2].catCannotRevive=true; gs._knockout_unit(p.units[3]); p.units[3].knockout=2; destroy(gs)
	check(p.units[2].hp==0 and p.units[3].hp>0,"cannot-revive unit excluded without blocking eligible revival")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[2].shield=2
	play(gs,"c28004",foe.units[2].uid)
	check(foe.units[2].shield==0 and foe.units[2].armorBreak==2 and foe.units[1].armorBreak==0,"ridge applies selected actual4armor-break canceling armor")
	var hps: Array=foe.units.map(func(v):return int(v.hp)); destroy(gs)
	check(foe.units[0].hp==hps[0]-1 and foe.units[1].hp==hps[1]-1 and foe.units[2].hp==hps[2]-3 and foe.units[3].hp==hps[3]-1 and foe.avatarHp==30,"ridge destruction actual enemy shikigamiAOE1 with real armor-break, no avatar damage")
	gs=game(); p=gs.player(0); var maxes: Array=p.units.map(func(v):return int(v.maxHp)); p.units[2].hp=2
	play(gs,"c28005")
	check(p.realms[0].hp==3 and p.energy==39 and p.units[0].maxHp==6 and p.units[2].hp==3,"god exact3durability onefire and actual+1maximum health without full healing")
	check(p.units[0].form.is_empty(),"god is a real realm before destruction")
	destroy(gs)
	check(p.units[0].form.cardId=="c28005" and p.units[0].attack==6 and p.units[0].maxHp==7 and p.units[0].formRules.get("mountainGod",false),"god converts to actual6/6 form preserving previous+1hp, no fake armor")
	check(p.realms.is_empty(),"converted god no longer occupies realm field")
	gs._knockout_unit(p.units[0]); check(p.units[0].form.is_empty() and p.units[0].hp==0,"god real form departs on actual knockout")
	gs=game(); p=gs.player(0); play(gs,"c28005"); gs._knockout_unit(p.units[0]); destroy(gs)
	check(p.units[0].hp==0 and p.units[0].form.is_empty(),"god cannot implicitly revive knocked-out caster")

func basic_and_awaken() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(gs.basic_attack(0,0) and u.attack==2 and u.maxHp==6,"unawakened ordinary attack gains1hp only")
	check(gs.player(1).avatarHp==28,"ordinary attack keeps actual2power")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c28002"); gs._deploy_realm(0,Content.card_def("c17803")); play(gs,"c28001",gs.player(1).units[0].uid); p.avatarHp=20
	check(gs.basic_attack(0,0) and p.realms.size()==1 and p.realms[0].sourceUnit=="huang" and p.avatarHp==23,"basic destroys every own mountain realm and triggers all departures, preserves other shikigami realms")
	check(u.attack==2 and u.maxHp==6 and u.shield==2 and gs.player(1).avatarHp==26,"color real encourage is consumed by same4power basic with2armor")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c28005"); play(gs,"c28005")
	check(gs.basic_attack(0,0) and u.attack==6 and u.maxHp==9 and gs.player(1).avatarHp==24 and p.realms.is_empty(),"multiple god destructions install final real form before same sortie damage")
	check(not gs.resolution_stack.any(func(f):return f.get("kind")=="form-install"),"god conversion never leaves a deferred replacement behind already-resolved sortie")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c28002")
	gs._resolve_combat(0,0,0,false,false,false,false,null,false,{"immuneCombat":true}); gs._resolve_resolution_stack()
	check(p.realms.size()==1 and u.maxHp==5,"triggered non-basic attack never substitutes for explicit sortie condition")
	gs=game(); p=gs.player(0); u=p.units[0]; p.deck=[{"definitionId":"c10101","instanceId":"spell"},{"definitionId":"c17803","instanceId":"realm-exact"},{"definitionId":"c10801","instanceId":"peach"}]
	play(gs,"c28006")
	check(u.awakened and u.attack==3 and u.maxHp==6 and p.hand.size()==1 and p.hand[0].instanceId=="realm-exact" and p.deck.size()==2,"awake exact1/1 searches actual random realm instance rather than ordinary draw")
	check(p.energy==39,"awakening never grants premature fake fire")
	p.energy=2; check(gs.basic_attack(0,0) and p.energy==1 and u.attack==4 and u.maxHp==7,"awake basic grows exact1/1 but no realm means no refund")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c28006"); play(gs,"c28002"); play(gs,"c28001",gs.player(1).units[0].uid); p.energy=2
	check(gs.basic_attack(0,0) and p.energy==2 and p.realms.is_empty(),"awake destroys multiple own realms and grants exactly one actual fire")
	gs=game(); p=gs.player(0); u=p.units[0]; u.level=0; Mountain.before_basic_attack(gs,0,0)
	check(u.maxHp==5,"inactive source cannot gain native sortie growth")
	u.level=3; u.baseRulesSuppressed=true; Mountain.before_basic_attack(gs,0,0)
	check(u.maxHp==5,"paper-suppressed source cannot trigger native sortie")
	gs=game(); p=gs.player(0); p.deck=[{"definitionId":"c10101","instanceId":"spell"}]; play(gs,"c28006")
	check(p.deck.size()==1 and p.hand.is_empty() and p.units[0].awakened,"no realm in deck still awakens, never draws unrelated spell")

func seek_and_travel() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	var h:=give(gs,"c28003"); check(not gs.can_play_card(0,h).ok,"seek illegal without own mountain realm")
	gs._deploy_realm(0,Content.card_def("c17803")); check(not gs.can_play_card(0,h).ok,"seek cannot sacrifice unrelated ally realm")
	play(gs,"c28001",foe.units[0].uid); play(gs,"c28002"); var energy: int=p.energy; var deck: int=p.deck.size(); var first: String=p.realms[1].uid; var other: String=p.realms[0].uid; p.avatarHp=20
	check(gs.play_card(0,h) and gs.pending_choice.type=="mountain-realm" and p.deck.size()==deck,"seek actual instant opens sacrifice choice before draw")
	check(p.energy==energy and gs.pending_choice.instanceIds.size()==2 and not gs.pending_choice.instanceIds.has(other),"seek first instant is free and choices contain only own mountain realms")
	check(not gs.resolve_divination_choice(1,first) and not gs.resolve_divination_choice(0,other),"seek rejects wrong player and unrelated realm UID")
	check(gs.resolve_divination_choice(0,first) and p.avatarHp==23 and p.deck.size()==deck-2 and p.realms.size()==2,"chosen cloud actually destroys and heals before exact2draw")
	gs=game(); p=gs.player(0); play(gs,"c28008"); check(p.realms[0].hp==3 and p.units.all(func(u):return bool(u.unyielding)),"travel exact3durability grants real unyielding at entry")
	gs._damage_unit(0,2,100,1,0); check(p.units[2].hp==1 and not p.units[2].unyielding,"travel real unyielding saves once then is consumed")
	check(gs.end_turn(0) and not p.units[2].unyielding and gs.end_turn(1) and p.units[2].unyielding,"travel only grants again at actual own start")
	p.avatarHp=15; for u in p.units: u.hp=1
	destroy(gs); check(p.avatarHp==21 and p.units.all(func(u):return int(u.hp)==int(u.maxHp)),"travel destruction heals all friendly characters6 including avatar")
	gs=game(); p=gs.player(0)
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, 0, 0, "mountain-scope-decoy", "普通召唤物", 0, 9, {"countsAsShikigami": false})
	decoy.hp=1
	play(gs,"c28008"); destroy(gs)
	check(decoy.hp==7 and not decoy.unyielding,"水行之旅离场治疗普通召唤物，入场不屈仍只给式神")
	gs=game(); p=gs.player(0); play(gs,"c28008"); gs._knockout_unit(p.units[0]); p.units[2].unyielding=false; p.units[2].hp=2
	check(gs.end_turn(0) and gs.end_turn(1) and p.units[2].unyielding,"travel remains independent of knocked-out caster")
	destroy(gs); check(p.units[0].hp==0,"travel healing never revives a dead unit")

func replay_and_ai() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	var deck: int=p.deck.size(); play(gs,"c28007"); check(p.realms.is_empty() and p.deck.size()==deck,"no destroyed realms gives no invented draw or heal")
	play(gs,"c28002"); play(gs,"c28008"); destroy(gs); destroy(gs)
	var history: int=p.mountainDestroyedRealms.size(); var energy: int=p.energy; var used: int=p.cardsPlayedThisTurn
	for u in p.units: u.unyielding=false
	play(gs,"c28007")
	check(p.realms.size()==2 and p.realms.all(func(r):return int(r.hp)==3) and p.units.all(func(u):return bool(u.unyielding)),"replay places two actual destroyed realms full durability and reruns entry effects")
	check(gs.kw_usage(0,"encourage").attack==4 and gs.kw_usage(0,"encourage").shield==4 and p.energy==energy-1 and p.cardsPlayedThisTurn==used+1,"replayed realms grant actual encourage and do not count as two extra uses or extra fire")
	check(p.mountainDestroyedRealms.size()==history,"replay does not consume persistent match destruction history")
	play(gs,"c28007"); check(p.realms.size()==4,"same match history can be replayed again without fake discard pile consumption")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[0].hp=5; play(gs,"c28001",foe.units[0].uid); destroy(gs); var hp: int=foe.units[1].hp
	play(gs,"c28007"); check(gs.pending_choice.type=="mountain-target" and p.realms.is_empty(),"replayed targeted entry pauses for actual player target choice")
	check(not gs.resolve_divination_choice(1,str(foe.units[1].uid)) and not gs.resolve_divination_choice(0,str(p.units[0].uid)),"replay target cannot be bypassed by wrong player or friendly UID")
	check(gs.resolve_divination_choice(0,str(foe.units[1].uid)) and foe.units[1].hp==hp-3 and p.realms.size()==1,"replay resolves chosen real target then places actual cloud")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c28001",foe.units[0].uid); destroy(gs); for u in foe.units: gs._knockout_unit(u)
	play(gs,"c28007"); check(gs.pending_choice.is_empty() and p.realms.size()==1,"targeted realm still enters when every legal target absent")
	gs=game(); p=gs.player(0); play(gs,"c17803"); destroy(gs); var handcount: int=p.hand.size(); play(gs,"c28007")
	check(p.realms.size()==1 and p.realms[0].sourceUnit=="huang" and p.hand.size()==handcount,"replay includes teammate destroyed realms and does not announce another played card")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c28001",foe.units[0].uid); destroy(gs); play(gs,"c28007")
	check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty() and p.realms.size()==1,"AI resolves legal actual replay target")
	play(gs,"c28003"); check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty() and p.realms.is_empty(),"AI resolves legal actual seek sacrifice")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c28001"); foe.units[2].hp=3; gs._grow_unit(foe.units[3],0,10)
	var best: Dictionary=AI._best_card(gs,0)
	check(best.ok and best.target==foe.units[2].uid and gs.play_card(0,best.hand,best.target) and foe.units[2].hp==0,"AI chooses real legal cloud lethal target")
	foe.units[3].keywords=["veil"]; var opts: Array=gs.valid_targets(0,Content.card_def("c28004"))
	check(not opts.has(foe.units[3].uid) and not opts.has("avatar-1") and not opts.has(p.units[0].uid),"mountain target UI/API respects hostile veil and shikigami-only range")
	for id in ["c28001","c28002","c28003","c28004","c28005","c28006","c28007","c28008"]: check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"full original art "+id)

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["bujianyue","huang","taohuayao","yaodaoji"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],280); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		for u in foe.units: gs._grow_unit(u,0,20)
		hand(b,["c28001"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[2].uid)).selected,"native cloud shows actual enemy targets")
		var hp: int=foe.units[2].hp; await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp==hp-3 and p.realms.size()==1 and p.realms[0].hp==3,"native cloud actual target3damage and3durability")
		hand(b,["c28005"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size()==2 and p.units[0].form.is_empty(),"native god stays realm before sacrifice")
		hand(b,["c28003"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type")=="mountain-realm" and choice_face(b,"c28001")!=null and choice_face(b,"c28005")!=null,"native seek opens exact installed realm choices")
		if physical.x==1280: await capture("01-seek-installed-realm-choices")
		var tile:=choice_face(b,"c28005"); if tile!=null: await click(tile)
		await settled(b)
		check(gs.pending_choice.is_empty() and p.units[0].form.get("cardId")=="c28005" and p.units[0].attack==6 and p.units[0].maxHp==7,"native god sacrifice installs actual6/6 form plus prior health")
		if physical.x==1600: await capture("02-god-real-form-after-sacrifice")
		hand(b,["c28007"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.realms.size()==2 and p.units[0].maxHp==8,"native replay reruns god entry actual+1hp")
		gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"验证重放目标"); gs._resolve_resolution_stack(); hand(b,["c28007"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type")=="mountain-target" and faces(b._choice_layer).size()==4,"native replayed cloud exposes actual four shikigami target choices")
		if physical.x==1280: await capture("03-replayed-cloud-actual-target-choice")
		hp=foe.units[1].hp; tile=choice_face(b,str(foe.units[1].uid)); if tile!=null: await click(tile)
		await settled(b)
		check(gs.pending_choice.is_empty() and foe.units[1].hp==hp-3,"native replay target mouse click resumes placement once")
		hand(b,["c28008"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units.all(func(u):return bool(u.unyielding)),"native water-travel grants actual unyielding state")
		if physical.x==1600: await capture("04-travel-actual-unyielding-original-card")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg!="--rules-only": out=arg; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	entries_and_destruction(); basic_and_awaken(); seek_and_travel(); replay_and_ai()
	if not args.has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("MOUNTAIN checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
