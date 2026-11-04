extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Yaksha := preload("res://scripts/yaksha_rules.gd")
const Maple := preload("res://scripts/maple_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("YAKSHA_FAIL ",detail)

func game() -> GS:
	var gs:=GS.create(["yecha","gunvhongye","bingyong","taohuayao"],["bingyong","yaodaoji","xuenv","baizangzhu"],262)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	# This suite controls night separately; red-leaf stays inactive unless requested.
	gs.player(0).units[1].level=0
	return gs

func give(gs, id: String, owner: int = 0, zone: String = "hand") -> int:
	gs.player(owner)[zone].append({"definitionId":id,"instanceId":"yaksha-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner)[zone].size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()

func night_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==6 and u.passive_hooks.is_empty(),"exact2/6 and old postcombat growth removed")
	check(not Maple.nightfall(gs,0,3) and p.night==1,"failed night gain exact1")
	check(u.attack==2,"strength is deferred until corresponding night effect completes")
	gs._resolve_resolution_stack(); check(u.attack==3 and events(gs,"yaksha-night-strength")==1,"failure branch triggers once after actual night effect")
	Maple.nightfall(gs,0,3); gs._resolve_resolution_stack()
	check(u.attack==3 and p.night==2,"ordinary source once per real turn despite a second event")
	check(gs.end_turn(0),"real turn transition")
	Maple.nightfall(gs,0,3); gs._resolve_resolution_stack()
	check(u.attack==4 and p.night==3,"enemy turn grants a fresh once-per-turn quota")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=10
	check(Maple.nightfall(gs,0,3),"success branch at threshold10")
	gs._resolve_resolution_stack(); check(u.attack==3 and p.night==10,"success branch grows even without any resource gain")
	gs=game(); u=gs.player(0).units[0]; Maple.gain_night(gs,0,4); gs._resolve_resolution_stack()
	check(u.attack==2,"bare gain_night is not an 入夜X trigger")
	for state in ["dead","inactive","suppressed"]:
		gs=game(); u=gs.player(0).units[0]
		if state=="dead": gs._knockout_unit(u)
		elif state=="inactive": u.level=0
		else: u.baseRulesSuppressed=true
		Maple.nightfall(gs,0,3); gs._resolve_resolution_stack()
		check(u.attack==2 and not u.has("yakshaStrengthTurn"),"no growth or quota consumed while "+state)
	gs=game(); u=gs.player(0).units[0]; u.frozen=1; Maple.nightfall(gs,0,3); gs._resolve_resolution_stack()
	check(u.attack==3,"stun does not silence passive 入夜 effect")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=10
	Maple.nightfall(gs,0,3); gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(not u.has("yakshaStrengthTurn"),"lethal night effect before growth never spends the dead source quota")
	check(gs.VerifiedRules.Peach.revive(gs,0,3,u,false,false),"shared legal revival after blocked trigger")
	Maple.nightfall(gs,0,3); gs._resolve_resolution_stack(); check(u.attack==3,"same-turn legal revival may still use unspent quota")
	gs=game(); p=gs.player(0); u=p.units[0]; u.hp=3
	play(gs,"c26204"); check(u.awakened and u.attack==2 and u.maxHp==7 and u.hp==4,"awakening exact0/+1, no invented2attack or turn growth")
	for i in 3: Maple.nightfall(gs,0,3); gs._resolve_resolution_stack()
	check(u.attack==5 and events(gs,"yaksha-night-strength")==3,"awake removes quota and every actual nightX event grows")
	check(not gs.can_play_card(0,give(gs,"c26204")).ok,"awakening cannot be repeated")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=3; play(gs,"c26204"); check(gs.end_turn(0) and gs.end_turn(1),"awake crosses actual two turn starts")
	check(u.attack==2,"awake has no legacy turn-start growth without night event")

func form_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; var foe: Dictionary=gs.player(1)
	p.night=2; play(gs,"c26202")
	check(u.attack==3 and u.maxHp==6 and Maple.night_value(gs,0)==3,"shura exact2/6 plus real once-per-turn1 growth")
	check(gs.VerifiedRules.Combat.has(u,"pierce") and not gs.VerifiedRules.Combat.has(u,"pursuit"),"shura failed night3 increases to3 but never retroactively grants pursuit")
	gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1); p.night=3; play(gs,"c26202")
	check(gs.VerifiedRules.Combat.has(u,"pierce") and gs.VerifiedRules.Combat.has(u,"pursuit"),"shura successful night3 grants real form pursuit and piercing")
	foe.units[0].front=1; foe.units[1].keywords=["veil"]
	var targets:=gs.basic_attack_targets(0,0)
	check(targets.has(foe.units[2].uid) and not targets.has(foe.units[1].uid) and not targets.has("avatar-1"),"real pursuit reserves selectable; enemy veil and avatar excluded")
	check(not gs.basic_attack(0,0,"avatar-1") and not gs.basic_attack(0,0,foe.units[1].uid),"basic command cannot bypass pursuit target legality")
	var hp: int=foe.units[2].hp
	check(gs.basic_attack(0,0,foe.units[2].uid) and foe.units[2].hp==hp-int(u.attack),"real ordinary pursuit reaches chosen reserve")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=6; play(gs,"c26205")
	check(u.attack==7 and u.maxHp==6 and not u.get("barrier",false) and p.night==7 and u.shield==0,"evil true6/6, failed7 grants neither shield nor barrier")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=7; play(gs,"c26205")
	check(u.attack==7 and u.maxHp==6 and u.get("barrier",false) and u.shield==0,"evil successful7 grants actual barrier rather than armor")
	gs._damage_unit(0,0,20,1,0); check(u.hp==6 and not u.get("barrier",false),"barrier blocks full20 and is consumed")
	gs._damage_unit(0,0,1,1,0); check(u.hp==5,"next damage is no longer blocked")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=3; play(gs,"c26202"); play(gs,"c26205")
	check(not gs.VerifiedRules.Combat.has(u,"pursuit") and not gs.VerifiedRules.Combat.has(u,"pierce"),"replacing shura removes its own pursuit and pierce")
	gs._knockout_unit(u); check(u.form.is_empty() and u.maxHp==6 and u.hp==0,"form naturally leaves on knockout without healing dead source")

func combat_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; var foe: Dictionary=gs.player(1)
	for id in ["c26201","c26206","c26208"]:
		gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1)
		p.night=10; u.hp=2; var old_deck: int=p.deck.size(); var power:=int(Content.card_def(id).value)
		play(gs,id)
		check(foe.avatarHp==30-2-power and p.night==10 and u.attack==2,"combat card "+id+" exact bonus to avatar, no kill trigger")
		check(p.deck.size()==old_deck and u.hp==2 and p.energy==39,"avatar hit gives no heal/draw/fire reward "+id)
		gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1); p.night=10; u.hp=2
		gs._grow_unit(foe.units[0],0,30); foe.units[0].attack=0; foe.units[0].front=1; old_deck=p.deck.size()
		play(gs,id)
		check(u.hp==2 and u.attack==2 and p.night==10 and p.deck.size()==old_deck and events(gs,"yaksha-kill-reward")==0,"nonlethal unit hit gives no condition or reward "+id)
		for passed in [false,true]:
			gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1); u.hp=1
			var threshold:=int(Content.card_def(id).yakshaThreshold); p.night=threshold if passed else threshold-1
			foe.units[0].hp=1; foe.units[0].attack=0; foe.units[0].front=1; old_deck=p.deck.size()
			if id=="c26208": p.energy=2
			var before: int=p.energy; play(gs,id)
			check(foe.units[0].hp==0 and p.night==threshold and u.attack==3,"real kill triggers threshold then growth "+id+" pass="+str(passed))
			check(events(gs,"yaksha-kill-reward")==int(passed),"only pre-existing threshold passes "+id+" pass="+str(passed))
			if id=="c26201": check(u.hp==(6 if passed else 1),"slaughter heals every missing HP only on successful3")
			elif id=="c26206": check(p.deck.size()==old_deck-(2 if passed else 0),"plunder draws exactly two only on successful7")
			else: check(p.energy==before-1+(1 if passed else 0),"ghost grants exactly1 real fire only on successful10")
		gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1); p.night=10; foe.units[0].hp=1; foe.units[0].front=1; foe.units[0].barrier=true; foe.units[0].attack=0
		play(gs,id); check(foe.units[0].hp==1 and events(gs,"night-triggered")==0,"barrier prevented lethal gives no false kill "+id)
	gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1); p.night=10; foe.units[0].hp=1; foe.units[0].attack=0; foe.units[0].front=1; foe.units[0].summoned=true; foe.units[0].countsAsShikigami=false
	play(gs,"c26206"); check(events(gs,"yaksha-kill-reward")==0,"non-shikigami summon never grants shikigami kill reward")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=7; foe.units[0].hp=1; foe.units[0].attack=1; foe.units[0].front=1; p.units[0].hp=2
	play(gs,"c26206"); check(p.units[0].hp==2 and p.units[0].shield==0,"plunder exact1 armor prevents1 counterdamage")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=10; foe.units[0].hp=1; foe.units[0].attack=2; foe.units[0].front=1; p.units[0].hp=2
	play(gs,"c26208"); check(p.units[0].hp==2 and p.units[0].shield==0,"ghost exact2 armor prevents2 counterdamage")

func sea_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c26203"); check(p.realms.size()==1 and p.realms[0].hp==5 and p.realms[0].nativeRealm=="yaksha-sea","yellow sea actual5 durability realm")
	p.night=4; gs._knockout_unit(foe.units[0]); gs._resolve_resolution_stack()
	check(foe.units[0].knockout==2 and p.night==5,"yellow sea failed5 grows night but does not extend same death")
	gs._knockout_unit(foe.units[1]); gs._resolve_resolution_stack()
	check(foe.units[1].knockout==3 and p.night==5,"yellow sea successful5 extends actual enemy knockout by1")
	gs._knockout_unit(p.units[2]); gs._resolve_resolution_stack()
	check(p.units[2].knockout==2 and events(gs,"yaksha-sea-extended")==1,"own death does not trigger friendly yellow sea")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=5; play(gs,"c26203"); gs._knockout_unit(p.units[0]); gs._resolve_resolution_stack()
	gs._knockout_unit(foe.units[0]); gs._resolve_resolution_stack()
	check(foe.units[0].knockout==3,"deployed realm continues independently of knocked-out source")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=5; play(gs,"c26203"); var enemy_hp: int=foe.avatarHp
	check(gs.end_turn(0) and gs.end_turn(1) and foe.avatarHp==enemy_hp and foe.units[0].hp==foe.units[0].maxHp,"ordinary realm turn has no legacy2 damage")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=5; play(gs,"c26203"); gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"test")
	gs._knockout_unit(foe.units[0]); gs._resolve_resolution_stack(); check(foe.units[0].knockout==2,"destroyed realm cannot create future KO trigger")

func resurrection_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	p.deck.clear(); p.night=9; gs._knockout_unit(u); play(gs,"c26207")
	check(u.hp==7 and u.maxHp==7 and u.attack==8 and u.knockout==0 and u.front==0 and p.night==10,"manual dead form revives real unit, exact7/7 then insufficient10 only grows night/strength")
	check(u.shield==0 and not u.get("barrier",false),"resurrection does not invent armor or barrier")
	gs=game(); p=gs.player(0); u=p.units[0]; p.deck.clear(); p.night=10; gs._knockout_unit(u); p.units[2].front=1; play(gs,"c26207")
	check(u.hp==7 and u.knockout==0 and u.front==1 and p.units[2].front==0,"manual dead form successful10 truly revives and replaces own front")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=10; p.deck.clear(); u.hp=2; play(gs,"c26207")
	check(u.hp==7 and u.maxHp==7 and u.front==1,"form usable while living and true set7/7/full-health entry")
	for zone in ["hand","deck"]:
		gs=game(); p=gs.player(0); u=p.units[0]; p.deck.clear(); p.hand.clear(); p.night=10; p.energy=0
		give(gs,"c26207",0,zone); var iid: String=p[zone][0].instanceId; gs._knockout_unit(u); gs._resolve_resolution_stack()
		check(u.hp==7 and u.maxHp==7 and u.knockout==0 and u.front==1,"auto form actually revives from "+zone)
		check(not p[zone].any(func(i):return i.instanceId==iid) and p.energy==0 and events(gs,"yaksha-auto-form")==1,"auto consumes one real "+zone+" instance without fire")
		check(events(gs,"automatic-card")==1 and events(gs,"form-installed")==1,"auto uses complete common card lifecycle from "+zone)
		gs._knockout_unit(u); gs._resolve_resolution_stack()
		check(u.hp==0 and events(gs,"yaksha-auto-form")==1,"spent form never generates a phantom reuse from "+zone)
	for blocked in ["night9","catCannotRevive","samuraiCannotRevive","removed","suppressed"]:
		gs=game(); p=gs.player(0); u=p.units[0]; p.deck.clear(); p.night=10; give(gs,"c26207",0,"deck")
		if blocked=="night9": p.night=9
		elif blocked=="suppressed": u.baseRulesSuppressed=true
		else: u[blocked]=true
		gs._knockout_unit(u); gs._resolve_resolution_stack()
		check(u.hp==0 and p.deck.size()==1 and events(gs,"yaksha-auto-form")==0,"auto respects real blocker "+blocked)
	gs=game(); p=gs.player(0); u=p.units[0]; p.deck.clear(); p.night=10; u.level=2; give(gs,"c26207",0,"deck"); gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(u.hp==7 and u.level==2 and events(gs,"yaksha-auto-form")==1,"automatic form ignores hand-play level restriction")
	gs=game(); p=gs.player(0); u=p.units[0]; p.deck.clear(); u.level=2; gs._knockout_unit(u)
	check(not gs.can_play_card(0,give(gs,"c26207")).ok,"manual resurrection still requires actual3 level")
	for flag in ["catCannotRevive","samuraiCannotRevive","removed"]:
		gs=game(); p=gs.player(0); u=p.units[0]; p.deck.clear(); gs._knockout_unit(u); u[flag]=true
		check(not gs.can_play_card(0,give(gs,"c26207")).ok,"manual dead form respects shared cannot-revive "+flag)
	gs=game(); p=gs.player(0); u=p.units[0]; p.deck.clear(); p.night=10; give(gs,"c26207",0,"deck"); give(gs,"c26207",0,"deck"); gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(u.hp==7 and p.deck.size()==1 and events(gs,"yaksha-auto-form")==1,"one KO consumes one form when two copies available")
	gs._knockout_unit(u); gs._resolve_resolution_stack(); check(u.hp==7 and p.deck.is_empty() and events(gs,"yaksha-auto-form")==2,"later real KO can consume the second remaining copy")

func ai_and_art() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	p.deck.clear(); p.night=10; gs._knockout_unit(u); give(gs,"c26207"); var best:=AI._best_card(gs,0)
	check(best.ok and best.card_id=="c26207" and gs.play_card(0,best.hand,best.target) and u.hp==7 and u.front==1,"AI chooses and executes real legal dead-source resurrection")
	gs=game(); p=gs.player(0); var foe: Dictionary=gs.player(1); p.night=7; foe.units[0].hp=1; foe.units[0].attack=0; foe.units[0].front=1; give(gs,"c26206"); best=AI._best_card(gs,0)
	check(best.ok and best.card_id=="c26206" and gs.play_card(0,best.hand,best.target) and foe.units[0].hp==0 and events(gs,"yaksha-kill-reward")==1,"AI executes legal killing combat and true reward")
	for n in range(1,9): check(FileAccess.file_exists("res://assets/official/cards/c%d.png" % (26200+n)),"original art c%d" % (26200+n))

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["yecha","gunvhongye","bingyong","taohuayao"],["bingyong","yaodaoji","xuenv","baizangzhu"],262); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for unit in side.units: unit.level=3
		b.gs.player(0).units[1].level=0
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
		p.night=3; foe.units[0].front=1; foe.units[1].keywords=["veil"]; hand(b,["c26202"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.VerifiedRules.Combat.has(u,"pursuit") and gs.VerifiedRules.Combat.has(u,"pierce"),"native actual click installs shura and successful night3")
		await click(b._unit_widget(str(u.uid))); await settled(b)
		check(b._selected_attacker==0 and b._unit_widget(str(foe.units[2].uid)).selected and not b._unit_widget(str(foe.units[1].uid)).selected,"native pursuit highlights legal reserve and rejects veil")
		if physical.x==1600: await capture("01-yaksha-shura-real-pursuit")
		var hp: int=foe.units[2].hp; await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp==hp-3,"native reserve click resolves real pursuit damage")
		p.night=10; p.deck.clear(); gs._knockout_unit(u); gs._resolve_resolution_stack(); hand(b,["c26207"]); await settled(b)
		check(b._hand_row.get_child(0).playable,"native knocked-out source resurrection card enabled")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(u.hp==7 and u.knockout==0 and u.front==1 and u.form.cardId=="c26207","native dead-source card revives and truly enters frontline")
		await click(b._unit_widget(str(u.uid))); await settled(b)
		if b._selected_attacker==0: await click(b._unit_widget(str(u.uid))); await settled(b)
		check(texts(b).contains("比良坂之刹") and texts(b).contains("复活夜叉"),"native actual inspector exposes complete resurrection rule")
		if physical.x==1280: await capture("02-yaksha-resurrection-live-inspector")
		escape(); await settled(b); p.night=7; hand(b,["c26205"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(u.get("barrier",false) and u.shield==0,"native evil form actual barrier rather than invented armor")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores()
	var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	night_rules(); form_rules(); combat_rules(); sea_rules(); resurrection_rules(); ai_and_art()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("YAKSHA checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
