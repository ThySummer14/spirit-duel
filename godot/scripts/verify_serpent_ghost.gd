extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const SG := preload("res://scripts/serpent_ghost_rules.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("SERPENT_GHOST_FAIL ",detail)
func game(ids:Array=["guishiheibai","bayiqidashe","bingyong","shantong"]) -> GS:
	var gs:=GS.create(ids,["bingyong","shantong","bailang","hetong"],194220)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	return gs
func give(gs,id:String,owner:int=0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"serpent-ghost-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id:String,target=null,owner:int=0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)
func tough(u:Dictionary,hp:int=40,atk:int=0) -> void:
	u.baseMaxHp=hp;u.maxHp=hp;u.hp=hp;u.baseAttack=atk;u.attack=atk;u.attackBonus=0;u.maxHpBonus=0
func turn(gs) -> void:
	gs.player(gs.current_player).levelUpUsed=true;check(gs.end_turn(gs.current_player),"actual end turn")
func ghost_switches() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var g:Dictionary=p.units[0];var uid:String=g.uid
	check(g.attack==3 and g.maxHp==4 and SG.role(g)=="ghost","printed black3/4 native identity")
	g.charge=3;g.frozen=2;g.judgeInkAttack=2;g.testCharm=[{"source":"probe"}];g.enraged=true;g.shield=4;g.armorBreak=3
	gs._knockout_unit(g,1,0)
	check(g.hp==0 and g.front==0 and g.get("sgSwitchPending",false) and not g.get("sgSnake",false),"pending switch leaves front during grouped damage and precedes serpent")
	gs._resolve_resolution_stack()
	check(g.get("sgWhite",false) and g.id=="guishiheibai" and g.uid==uid and g.name=="鬼使白","real white body preserves original UID/card owner")
	check(g.baseAttack==2 and g.baseMaxHp==6 and g.hp==g.maxHp and g.charge==1,"white2/6 and exact2energy consumed")
	check(g.shield==0 and g.armorBreak==0 and g.frozen==2 and g.enraged and g.testCharm.size()==1 and g.judgeInkAttack==2,"switch removes armor/break while retaining stun/charms/ink/enrage")
	check(not gs.VerifiedRules.SunSmoke.has_charge(g),"white identity does not gain black passive charge")
	g.frozen=0;turn(gs);turn(gs)
	check(g.get("sgWhite",false) and g.sgWhiteCountdown==1 and g.charge==1,"first white own turn ticks2to1 without charge")
	turn(gs);turn(gs)
	check(not g.sgWhite and g.sgBlackSwitches==1 and g.baseAttack==3 and g.baseMaxHp==4,"second white own turn returns black exactly once")
	var before:int=g.charge;turn(gs);turn(gs)
	check(g.sgBlackSwitches==1 and g.charge==before+1,"black turn charges normally and no repeated white expiry")
	gs=game(["guishiheibai","taohuayao","bingyong","shantong"]);p=gs.player(0);g=p.units[0]
	SG.switch_ghost(gs,0,0,true);g.charge=5;gs._knockout_unit(g,1,0);gs._resolve_resolution_stack()
	check(g.hp==0 and g.knockout>0 and not g.sgWhite and g.get("sgBlackSwitches",0)==0,"white actual knockout restores black identity but does not count a switch")
	gs=game();g=gs.player(0).units[0];g.charge=1;gs._knockout_unit(g,1,0);gs._resolve_resolution_stack()
	check(g.get("sgSnake",false) and not g.get("sgWhite",false),"black with insufficient energy can become ally serpent snake")
func grouped_and_combo() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var g:Dictionary=p.units[0]
	g.charge=2
	gs._damage_unit(0,0,99,1,0)
	check(g.hp==0 and g.get("sgSwitchPending",false) and not g.get("sgWhite",false),"real damage packet queues switch until group finishes")
	gs._damage_unit(0,2,99,1,0)
	check(g.hp==0 and not g.get("sgWhite",false) and p.units[2].hp==0,"remaining group packets settle before white/snake bodies appear")
	gs._resolve_resolution_stack()
	check(g.get("sgWhite",false) and g.hp==6 and p.units[2].get("sgSnake",false) and p.units[2].hp==3,"group then yields actual white and ally snake")
	gs=game(["guishiheibai","taohuayao","bingyong","shantong"]);p=gs.player(0);g=p.units[0]
	g.charge=2;g.front=1;tough(gs.player(1).units[0],30,4)
	gs._resolve_combat(1,0,0,false,false,true,false)
	gs._resolve_resolution_stack()
	check(g.get("sgWhite",false) and g.hp==2 and g.charge==0,"combo next strike hits already switched white body")
	check(gs.player(1).units[0].hp==28,"attacker-only combo has no black extra counter then white counters2")
	check(gs.resolution_stack.is_empty(),"inter-exchange switch continuation drains without extra attacks")
	gs=game(["guishiheibai","taohuayao","bingyong","shantong"]);p=gs.player(0);g=p.units[0]
	g.charge=2;g.front=1;g.keywords=["combo"];tough(gs.player(1).units[0],30,4)
	gs._resolve_combat(1,0,0,false,false,true,false);gs._resolve_resolution_stack()
	check(gs.player(1).units[0].hp==25 and g.get("sgWhite",false) and g.hp==2,"both combo exchanges retain simultaneous black3 then switched white2 counter")
	check(gs.resolution_stack.is_empty(),"both combo continuation drains without phantom third exchange")
	gs=game(["guishiheibai","taohuayao","bingyong","shantong"]);p=gs.player(0);g=p.units[0]
	g.charge=2;g.front=1;g.keywords=["combo"];tough(gs.player(1).units[0],30,4)
	gs._resolve_combat(1,0,0,false,false,false,false);gs._resolve_resolution_stack()
	check(gs.player(1).units[0].hp==24 and g.get("sgWhite",false) and g.hp==6,"defender-only combo counters black3 twice before ordinary exchange switches white")
	check(gs.resolution_stack.is_empty(),"defender-only combo never grants switched white an extra counter")
func ghost_cards() -> void:
	var gs:=game(["guishiheibai","taohuayao","bingyong","shantong"]);var p:Dictionary=gs.player(0);var g:Dictionary=p.units[0];var foe:Dictionary=gs.player(1)
	var i:int=give(gs,"c19402");check(not gs.can_play_card(0,i).ok,"brothers rejects black identity");p.hand.clear()
	g.charge=4;i=give(gs,"c19401");check(gs.VerifiedRules.Movement.request_burst(gs,0,i),"actual burst UI opens")
	check(gs.resolve_divination_choice(0,"burst:2"),"actual burst choice selects2")
	check(gs.hand_card_def(0,i).keywords.has("instant") and gs.effective_card_cost(0,gs.hand_card_def(0,i))==0,"sickle burst2 projects true instant")
	foe.units[0].front=1;tough(foe.units[0],30,0);foe.units[0].shield=20;foe.units[0].barrier=true
	check(gs.play_card(0,i),"actual charged sickle play")
	check(g.charge==2 and p.energy==40 and foe.units[0].hp==26 and foe.units[0].shield==0 and not foe.units[0].barrier,"penetration strips real shield/barrier; +1attack and instant payment")
	i=give(gs,"c19403");check(gs.VerifiedRules.Movement.request_burst(gs,0,i) and gs.resolve_divination_choice(0,"burst:2"),"punishment actual burst2 choice")
	var target:String=foe.units[1].uid;tough(foe.units[1],20,0)
	check(gs.valid_targets(0,gs.hand_card_def(0,i)).has(target),"burst pursuit includes real reserve")
	check(gs.play_card(0,i,target) and foe.units[1].hp==15 and g.charge==0,"actual pursuit hits chosen reserve for3+2")
	SG.switch_ghost(gs,0,0,true);var hp:int=g.hp
	play(gs,"c19402")
	check(not g.sgWhite and g.sgBlackSwitches==1 and g.hp==g.maxHp,"brothers switches black then actual attack with damage immunity")
	play(gs,"c19404");check(g.awakened and g.sgBlackAwakened and g.swift,"black awakening preserves actual swift")
	i=give(gs,"c19404");check(gs.hand_card_def(0,i).id=="sg-white-awaken" and gs.hand_card_def(0,i).level==3,"remaining same-name awakening projects real white derivative")
	check(not gs.can_play_card(0,i).ok,"white awakening cannot be used by black")
	SG.switch_ghost(gs,0,0,true)
	check(gs.play_card(0,i),"actual derived white awakening")
	check(g.sgWhiteAwakened and g.unyielding and g.sgWhiteCountdown==1 and g.maxHp==9,"white+2/+2 plus preservedblack+1/+1 and countdown1")
	var enemy_hp:int=foe.avatarHp;tough(foe.units[0],30,0);foe.units[0].front=1;var front_hp:int=foe.units[0].hp
	gs._damage_unit(0,0,2,1,1);gs._resolve_resolution_stack()
	check(foe.units[0].hp==front_hp-2 and foe.avatarHp==enemy_hp,"white actual received2 auto-soul projects2 at actual front")
	front_hp=foe.units[0].hp;gs._damage_unit(0,0,1,1,1);gs._resolve_resolution_stack()
	check(foe.units[0].hp==front_hp,"white soul limited once per actual turn")
	gs=game(["guishiheibai","taohuayao","bingyong","shantong"]);p=gs.player(0);g=p.units[0];foe=gs.player(1);tough(foe.units[0],60,0);g.front=1
	give(gs,"c19405");gs.current_player=1
	check(gs.basic_attack(1,0),"enemy real basic attack invokes impermanence response")
	check(g.sgWhite and g.attack==5 and g.maxHp==7 and g.sgWhiteCountdown==1,"response switches white gives3/1 and correctonecount")
	check(foe.units[0].hp==50 and p.hand.is_empty() and p.energy==39,"response performs actual5attack plus incoming combat counter then consumes realcardfire")
	gs=game(["guishiheibai","taohuayao","bingyong","shantong"]);p=gs.player(0);g=p.units[0];foe=gs.player(1);foe.avatarHp=100;foe.maxAvatarHp=100
	SG.switch_ghost(gs,0,0,true);play(gs,"c19402");SG.switch_ghost(gs,0,0,true);play(gs,"c19402");var avatar:int=foe.avatarHp
	play(gs,"c19406")
	check(g.sgBlackSwitches==2 and foe.avatarHp==avatar-12,"reap copies twice and actual chainbonuses0/1/2 produce3+4+5")
	check(gs.resolution_stack.is_empty(),"reap chain finishes without recursive extra copies")
	play(gs,"c19408");check(g.attack==6 and g.maxHp==5 and gs.VerifiedRules.Combat.has(g,"lethal") and gs.VerifiedRules.Combat.has(g,"first-strike"),"verdict true6/5 lethalfirst form")
	g.charge=4;turn(gs);check(g.sgWhite and g.shield==4,"verdict end turn switches then grants armor perenergy")
	gs=game(["guishiheibai","taohuayao","bingyong","shantong"]);p=gs.player(0);g=p.units[0];tough(gs.player(1).units[0],40,0);gs.player(1).units[0].front=1
	play(gs,"c19409");var charge:int=g.charge;check(gs.basic_attack(0,0),"livingdead actual basic attack")
	check(g.charge==charge+1,"livingdead gains onecharge per actualdamage event")
func snake_lifecycle() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[2];var uid:String=u.uid
	gs._knockout_unit(u,1,0);check(u.hp==0 and not u.get("sgSnake",false),"normal death completes before snake replacement")
	gs._resolve_resolution_stack()
	check(u.sgSnake and u.uid==uid and u.id=="bingyong" and u.attack==3 and u.hp==3 and u.swift,"actual3/3 swift snake replaces original body but preservesUID")
	var id:String=Content.cards_for_unit("bingyong")[0].id;var i:int=give(gs,id)
	check(not gs.can_play_card(0,i).ok,"normal snake cannot manually use original owner cards");p.hand.clear()
	gs._knockout_unit(u,1,0);gs._resolve_resolution_stack()
	check(not u.get("sgSnake",false) and u.id=="bingyong" and u.hp==0 and u.knockout>0 and u.baseMaxHp==6,"snake death returns original real knockout body and countdown")
	check(gs.resolution_stack.is_empty(),"snake death does not recursively create another snake")
	gs=game();p=gs.player(0);p.units[1].baseRulesSuppressed=true;gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack()
	check(not p.units[2].get("sgSnake",false),"suppressed serpent has no death transformation")
	gs=game();p=gs.player(0);p.units[2].summoned=true;gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack()
	check(not p.units[2].get("sgSnake",false),"summon is not an initial shikigami")
	gs=game();p=gs.player(0);p.units[2].baseRulesSuppressed=true;gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack()
	check(not p.units[2].get("sgSnake",false),"transformed shikigami is not an eligible initial body")
func serpent_cards() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var o:Dictionary=p.units[1];var foe:Dictionary=gs.player(1)
	check(o.attack==2 and o.maxHp==5,"printed serpent2/5")
	gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack();var snake:Dictionary=p.units[2]
	play(gs,"c22002");check(o.attack==3 and o.maxHp==6 and snake.inspired and snake.attack==4,"shadow form grants snake power1 and actual entry inspired")
	tough(foe.units[0],50,0);foe.units[0].front=1
	play(gs,"c22001",snake.uid)
	check(snake.attack==6 and snake.hp==3 and foe.units[0].hp==44,"impure applies real+2 alongside live form aura then attacks without destroying snake")
	play(gs,"c22001",p.units[3].uid)
	check(p.units[3].get("sgSnake",false),"impure non-snake attack then actual destruction then transforms")
	p.attackUsed=true;var deck:int=p.deck.size();play(gs,"c22003",p.units[3].uid)
	check(not p.attackUsed and p.deck.size()==deck-1 and p.units[3].hp==0 and not p.units[3].get("sgSnake",false),"sacrifice actual snake resetsaction draws1 and restoresoriginalKO")
	play(gs,"c22004");var hp:int=o.hp;gs._damage_unit(0,1,99,1,0);gs._resolve_resolution_stack()
	check(o.hp==hp and snake.hp==0 and not snake.get("sgSnake",false),"shadow substitutes random existing snake for actual lethal packet")
	gs._damage_unit(0,1,99,1,0);gs._resolve_resolution_stack();check(o.hp==0,"no snake means lethal packet is not cancelled")
	gs=game();p=gs.player(0);o=p.units[1];foe=gs.player(1)
	play(gs,"c22006",foe.units[1].uid)
	check(foe.units[1].sgSnake and foe.units[1].baseAttack==3 and foe.units[1].baseMaxHp==3,"good/evil actually transforms selected enemy body")
	gs._knockout_unit(p.units[2],1,0);gs._knockout_unit(p.units[3],1,0);gs._resolve_resolution_stack()
	foe.avatarHp=100;foe.maxAvatarHp=100;var avatar:int=foe.avatarHp;play(gs,"c22005")
	check(foe.avatarHp==avatar-6 and p.units[2].sgSnakeCombatImmune and p.units[3].sgSnakeCombatImmune,"each snake actually attacks in turn and receives named immunity")
	play(gs,"c22007");var before:int=foe.avatarHp+foe.units.reduce(func(acc,t):return acc+int(t.hp),0)
	turn(gs);var after:int=foe.avatarHp+foe.units.reduce(func(acc,t):return acc+int(t.hp),0)
	check(before-after==9,"either turn start wandering uses actualmaster plus2snakes as3sources")
func serpent_aura() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var source:Dictionary=p.units[1]
	gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack();var snake:Dictionary=p.units[2]
	play(gs,"c22002")
	check(snake.attack==4 and p.units[0].attack==3 and p.units[3].attack==3 and source.attack==3,"form aura affects only friendly actual snakes")
	snake.inspired=false;turn(gs)
	check(not snake.inspired and snake.attack==4,"enemy turn does not grant inspired or remove persistent aura")
	turn(gs);check(snake.inspired and snake.attack==4,"own turn renews inspired without stacking printed power aura")
	gs._knockout_unit(p.units[3],1,0);gs._resolve_resolution_stack()
	check(p.units[3].get("sgSnake",false) and p.units[3].attack==4,"snake born after form entry receives current power aura")
	source.baseRulesSuppressed=true;SG.refresh(gs)
	check(snake.attack==3 and p.units[3].attack==3,"suppressed source immediately stops snake power aura")
	source.baseRulesSuppressed=false;SG.refresh(gs)
	check(snake.attack==4 and p.units[3].attack==4,"restored source restores aura exactly once")
	play(gs,"c22004");check(snake.attack==3 and p.units[3].attack==3,"replacing actual source form removes its snake power aura")
	play(gs,"c22002");gs._knockout_unit(source,1,0);gs._resolve_resolution_stack()
	check(source.hp==0 and snake.attack==3 and p.units[3].attack==3,"source knockout removes aura from surviving snake bodies")
	gs=game();p=gs.player(0);source=p.units[1];play(gs,"c22002");play(gs,"c22008")
	gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack();snake=p.units[2]
	check(snake.get("sgSnakeCopy",false) and source.attack==8 and snake.attack==10,"copied form supplies its own aura and stacks with original source")
	source.baseRulesSuppressed=true;SG.refresh(gs)
	check(snake.attack==9,"suppressing one of two sources preserves only copied source aura")
func chaos_and_metadata() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var o:Dictionary=p.units[1]
	play(gs,"c22007");give(gs,"c22001");give(gs,"c22003");play(gs,"c22008")
	check(o.awakened and o.sgChaos and o.attack==9 and o.maxHp==13,"chaos preserves current4/8form and awakens+5/5")
	check(not p.hand.any(func(i):return Content.card_def(i.definitionId).unitId=="bayiqidashe") and not p.deck.any(func(i):return Content.card_def(i.definitionId).unitId=="bayiqidashe"),"chaos removes actual own hand/deck dedicated cards")
	check(not gs.can_basic_attack(0,1).ok,"chaos cannot manually basicattack")
	var i:int=give(gs,"c22001");check(not gs.can_play_card(0,i,p.units[3].uid).ok,"newlyobtained serpent card remains unplayable during chaos");p.hand.clear()
	gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack();var copy:Dictionary=p.units[2]
	check(copy.sgSnakeCopy and copy.sgChaos and copy.attack==o.attack and copy.maxHp==o.maxHp and copy.formRules.sgWandering,"new awakened snake really copies serpent body/form and chaos")
	check(not gs.can_basic_attack(0,2).ok and gs.VerifiedRules.Incarnation.has_source(gs,0),"copied snake is not manuallycontrollable and is an incarnation source")
	var pool:Array=SG.incarnation_pool(gs,0,2)
	check(pool.size()==4 and pool.all(func(c):return c.type=="spell" and c.sgCasterUid==copy.uid),"chaos uses all4 actual normalspells at correctcopied source")
	var impure:Dictionary=pool.filter(func(c):return c.id=="c22001")[0]
	check(not SG.targets(gs,0,impure).has(o.uid),"chaos snake never sacrifices its real serpent master with impure")
	var cfg:Dictionary=gs.VerifiedRules.Incarnation.config(copy,gs,0)
	check(cfg.start==25 and cfg.action==15 and cfg.limit==1,"chaos real cumulative25/15 onceperturn config")
	copy.frozen=1;check(gs.VerifiedRules.Incarnation.config(copy,gs,0).is_empty(),"stun blocks copiedchaos");copy.frozen=0
	for roleid in [194,220]:
		for c in Content.cards_for_unit("guishiheibai" if roleid==194 else "bayiqidashe"):
			if c.get("token",false):continue
			check(c.verifiedRules and c.serpentGhostRules and ResourceLoader.exists("res://assets/official/cards/%s.png"%c.id),"main metadata and originaltexture "+c.id)
	for id in ["sg-ghost-white","sg-snake"]:check(not Content.playable_units().any(func(def):return def.id==id),"derived identity not constructible "+id)
	check(SG.score_card(gs,0,Content.card_def("c22008"))>0 and not SG.marks(gs,0,copy).is_empty(),"AI and live status use exactrules")
func ui_checks() -> void:
	root.theme=ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["guishiheibai","bayiqidashe","bingyong","shantong"],["bingyong","shantong","bailang","hetong"],194220);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.4).timeout
		var gs=b.gs;var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
		hand(b,["c22006"]);await settled(b);await click(b._hand_row.get_child(0));check(b._pending_target_card==0,"mouse selects actualenemytransform target")
		await capture("%d-01-serpent-target"%physical.x)
		await click(b._unit_widget(str(foe.units[2].uid)));await settled(b)
		check(foe.units[2].get("sgSnake",false) and foe.units[2].attack==3 and b._unit_widget(str(foe.units[2].uid))!=null,"mouse selectedenemy becomes real3/3snake widget")
		hand(b,["c19405"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(p.units[0].get("sgWhite",false) and p.units[0].maxHp==7,"mouse plays actualwhite switch +3/+1 attack")
		await capture("%d-02-white-body"%physical.x)
		hand(b,["c19402"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(not p.units[0].sgWhite and p.units[0].sgBlackSwitches==1,"mouse brothers switches backblack and completes attack")
		p.units[0].charge=2;hand(b,["c19401"]);await settled(b)
		# The existing card menu owns burst choice; open it through its public control.
		check(gs.VerifiedRules.Movement.request_burst(gs,0,0),"native realburst choice opens");b._last_view={};b._refresh();await settled(b)
		var instance:Dictionary=gs.card_instance(0,0)
		var tile:Control=null
		for face in faces(b._choice_layer):
			if face.data.get("currentCardStats","")=="爆能2":tile=face
		check(tile!=null,"native burst2actualoption visible")
		await capture("%d-03-burst-choice"%physical.x)
		if tile!=null:await click(tile)
		await settled(b);check(instance.get("movementBurst",0)==2 and p.units[0].charge==0 and p.hand.is_empty(),"native burst2 actualselection pays2 and plays selectedinstance")
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args()
	if not args.is_empty() and args[0]!="--rules-only":out=args[0];DirAccess.make_dir_recursive_absolute(out)
	ghost_switches();grouped_and_combo();ghost_cards();snake_lifecycle();serpent_cards();serpent_aura();chaos_and_metadata()
	if not args.has("--rules-only"):await ui_checks()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("SERPENT_GHOST checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
