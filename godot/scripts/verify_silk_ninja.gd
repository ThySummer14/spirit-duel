extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Toxic:=preload("res://scripts/toxic_rules.gd")
func check(ok: bool,detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("SILK_NINJA_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["yujuchong","hainren","chongshi","shuweng"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],285286)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"silk-test-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null) -> void:
	var idx:=give(gs,id);var why:Dictionary=gs.can_play_card(0,idx,target);check(gs.play_card(0,idx,target),"actualplay "+id+" "+str(why))
func finish(gs) -> void:
	var guard:=0
	while not gs.pending_choice.is_empty() and guard<30:
		check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"AIactualchoice");guard+=1
	check(guard<30,"finitechoicecontinuation")
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func poisoned(gs,owner: int=1,idx: int=0) -> void:Toxic.apply(gs,1-owner,0,owner,idx)
func silk_cards() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,20)
	check(p.units[0].attack==3 and p.units[0].maxHp==4 and p.units[0].passive_hooks.is_empty() and p.units[1].passive_hooks.is_empty(),"originalbodiesandoldfakepassivesremoved")
	var i:=give(gs,"c28501");var iid:String=p.hand[i].instanceId;var hp:int=foe.units[0].hp
	check(gs.play_card(0,i),"silkfirstactualplay");check(foe.units[0].hp==hp-1 and foe.units[0].toxicPoisoned,"toxicprojectile1ratherthanfake2debuff")
	check(p.hand.size()==1 and p.hand[0].instanceId==iid and p.hand[0].silkBounceSpent and "bounce" not in gs.hand_card_def(0,0).keywords,"bounceoriginalinstanceonceandvisiblekeywordremoved")
	check(gs.play_card(0,0),"silksecondactualplay");check(foe.units[0].hp==0 and p.hand.is_empty() and p.toxicEnemyDeaths==1,"secondtoxicKOandnorepeatbounce")
	gs=game();p=gs.player(0);foe=gs.player(1);p.avatarHp=10;poisoned(gs);gs._knockout_unit(foe.units[0],0,1);gs._resolve_resolution_stack()
	check(p.avatarHp==11 and foe.avatarHp==29 and p.toxicEnemyDeaths==1,"basepoisonKOrealavatar1andheal1")
	gs._knockout_unit(foe.units[1],0,1);gs._resolve_resolution_stack();check(p.avatarHp==11 and p.toxicEnemyDeaths==1,"ordinaryKOdoesnotgrantpoisonreward")
	play(gs,"c28506");check(p.units[0].attack==4 and p.units[0].maxHp==5 and p.units[0].awakened,"printedawake1/1withoutlaterprojectile")
	poisoned(gs,1,2);gs._knockout_unit(foe.units[2],0,1);gs._resolve_resolution_stack();check(p.avatarHp==13 and foe.avatarHp==27,"awakepoisonKO2damageandheal2")
	check(not gs.can_play_card(0,give(gs,"c28506")).ok,"awakeningrepeatrejected")
	gs._knockout_unit(p.units[0],1,3);poisoned(gs,1,3);gs._knockout_unit(foe.units[3],0,1);gs._resolve_resolution_stack();check(p.toxicEnemyDeaths==3 and p.avatarHp==13,"wholegamehistorywhilecasterKOwithoutinactivepassive")
	var c:Dictionary=gs.hand_card_def(0,give(gs,"c28508"));check(c.value==8 and c.effects[0].value==8 and c.enhanced,"SSRrealhistory5plus3")
	gs.turn_counter+=1;check(gs.hand_card_def(0,p.hand.size()-1).value==8,"historydoesnotexpireturn")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28503");check(p.units[0].attack==3 and p.units[0].maxHp==4 and p.units[0].formCountdown.remaining==1,"nymph3/4entrytimer2minus1")
	var played:int=p.cardsPlayedThisTurn;var energy:int=p.energy;gs.VerifiedRules.reduce_countdown(gs,0,0,1);gs._resolve_resolution_stack()
	check(p.units[0].formCountdown.remaining==2 and foe.units.filter(func(u):return u.get("toxicPoisoned",false)).size()==1,"countdowntoxicrandomoneandreset2")
	check(p.energy==energy and p.cardsPlayedThisTurn==played,"countdownabilitynotphantomhandplay")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,10);hp=foe.units[0].hp;play(gs,"c28504")
	check(p.units[0].attack==4 and p.units[0].hp==5 and foe.units[0].hp==hp-2 and foe.units[0].toxicPoisoned,"night4/5entryprojectile2toxic")
	gs._knockout_unit(foe.units[0],0,1);gs._resolve_resolution_stack();check(foe.units[0].knockout==3,"nightactualpoisonKOcountdownplus1")
	gs._knockout_unit(foe.units[1],0,1);check(foe.units[1].knockout==2,"nightnotordinaryKO")
	poisoned(gs,0,1);gs._knockout_unit(p.units[1],1,2);check(p.units[1].knockout==2,"nightnotownpoisonKO")
	gs._knockout_unit(p.units[0],1,2);poisoned(gs,1,2);gs._knockout_unit(foe.units[2],0,3);check(foe.units[2].knockout==2,"nightinactiveauraoff")
	gs=game();p=gs.player(0);foe=gs.player(1);give(gs,"c28501",1);play(gs,"c28502");check(p.realms.size()==1 and p.realms[0].hp==4 and foe.units.filter(func(u):return u.get("toxicPoisoned",false)).size()==1,"4durrealmactualentryrandom1toxic")
	var unit:Dictionary=foe.units.filter(func(u):return u.get("toxicPoisoned",false))[0];gs._knockout_unit(unit,0,1);gs._resolve_resolution_stack()
	check(gs.pending_choice.get("which")=="erosion","ownturnduskKOrealerosionchoice");finish(gs);check(foe.hand[0].get("handCharm",{}).get("kind")=="erosion","duskmarksrealenemyinstance")
	gs=game();p=gs.player(0);foe=gs.player(1);give(gs,"c28501",1);play(gs,"c28502");poisoned(gs,1,1);gs.current_player=1;gs._knockout_unit(foe.units[1],0,1);gs._resolve_resolution_stack()
	check(gs.pending_choice.is_empty() and not foe.hand[0].has("handCharm"),"dusknotopponentturn")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(foe.units[0],0,10);gs._grow_unit(foe.units[1],0,10);poisoned(gs);hp=foe.units[1].hp;var face:int=foe.avatarHp
	var decoy: Dictionary=gs.VerifiedRules.NativeSummons.summon(gs,1,0,"silk-daydream-decoy","普通召唤物",0,9,{"countsAsShikigami":false})
	play(gs,"c28507")
	check(foe.units[0].hp==0 and foe.units[1].hp==hp-2 and not foe.units[1].has("toxicPoisoned"),"daydreampoisonedtoxicbutordinaryothers")
	check(foe.avatarHp==face-1,"daydreamnodirectavatar2onlyactualpoisonKOability")
	check(decoy.hp==9,"群攻只伤式神，普通召唤物不受伤")
	gs=game();foe=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,10);foe.units[0].hp=3;poisoned(gs);face=foe.avatarHp;play(gs,"c28508")
	check(foe.units[0].hp==0 and foe.avatarHp==face-3,"SSRconditionalpierce2excessandbase1notfakehugetoxicoverflow")
	gs=game();foe=gs.player(1);foe.units[0].front=1;foe.units[0].hp=2;face=foe.avatarHp;play(gs,"c28508")
	check(foe.units[0].hp==0 and foe.avatarHp==face,"SSRnofrontpoisonnopierce")
	gs=game();foe=gs.player(1);face=foe.avatarHp;play(gs,"c28501");check(foe.avatarHp==face-1 and not foe.get("avatarToxicPoisoned",false),"projectileemptyfrontrealavatar1withoutavatarpoison")
func response_cards() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.units[1].front=1;poisoned(gs);give(gs,"c28505");gs.current_player=1
	var hp:int=p.units[1].hp;var fire:int=p.energy;check(gs.basic_attack(1,0),"poisonedenemyactualattack")
	check(foe.units[0].hp==0 and p.units[1].hp==hp and p.hand.is_empty() and p.energy==fire-1,"dawnresponsekillsactualpoisonedattackerbeforecombat")
	check(events(gs,"response-card").size()==1 and events(gs,"response-card")[0].trigger=="toxic-enemy-attacking","nativeautomaticresponseevent")
	gs=game();p=gs.player(0);p.units[1].front=1;give(gs,"c28505");gs.current_player=1;gs.basic_attack(1,0);check(p.hand.size()==1 and events(gs,"response-card").is_empty(),"unpoisonedattackcannottriggerdawn")
	gs=game();p=gs.player(0);poisoned(gs);give(gs,"c28505");p.energy=0;gs.current_player=1;gs.basic_attack(1,0);check(p.hand.size()==1 and events(gs,"response-card").is_empty(),"responseactualfirecostrequired")
	gs=game();p=gs.player(0);poisoned(gs);give(gs,"c28505");gs._knockout_unit(p.units[0],1,0);gs.resolution_stack.clear();gs.current_player=1;gs.basic_attack(1,0);check(p.hand.size()==1,"KOcastercannotrespond")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(foe.units[0],0,10);hp=foe.units[0].hp;play(gs,"c28505",foe.units[0].uid);check(foe.units[0].hp==hp-4 and foe.units[0].toxicPoisoned,"dawnmainphase4toxicallowedunpoisoned")
func ninja_cards() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[0],5,30);poisoned(gs);var hp:int=p.units[1].hp
	check(gs.basic_attack(0,1),"ninjaactualbasicattack");check(p.units[1].hp==hp and p.units[1].shield==0 and not foe.units[0].get("armorBreak",0),"basepoisonattackimmunitywithoutfakearmor")
	p.units[1].inspired=true;gs.basic_attack(0,1);check(p.units[1].hp==0,"baseonceactualturnnotpercombat")
	gs=game();p=gs.player(0);foe=gs.player(1);p.units[1].front=1;gs._grow_unit(foe.units[0],3,10);poisoned(gs);gs.current_player=1;gs.basic_attack(1,0);check(p.units[1].hp<4 and events(gs,"ninja-immunity").is_empty(),"unawakeneddefendernoimmunity")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;foe.units[0].shield=20;foe.units[0].barrier=true;gs._grow_unit(foe.units[0],0,10);hp=foe.units[0].hp;play(gs,"c28601")
	check(foe.units[0].shield==0 and not foe.units[0].barrier and foe.units[0].hp==hp-4 and foe.units[0].toxicPoisoned,"1attacktoxicpenetrationremovesarmorbarrier")
	check(not gs.VerifiedRules.Combat.has(p.units[1],"toxic") and not gs.VerifiedRules.Combat.has(p.units[1],"penetration"),"combatcardtraitsnotpermanentunitgrants")
	gs=game();p=gs.player(0);foe=gs.player(1);var fire:int=p.energy;play(gs,"c28602",foe.units[0].uid);check(p.energy==fire and foe.units[0].toxicPoisoned,"firstinstantfreebutrealpoison")
	play(gs,"c28602",foe.units[1].uid);check(p.energy==fire-1,"secondinstantnormal1cost")
	var bad:=give(gs,"c28602");check(not gs.can_play_card(0,bad,foe.units[0].uid).ok and not gs.play_card(0,bad,foe.units[0].uid),"latentcannotretargetalreadytoxic")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28604",foe.units[0].uid);check(p.units[1].awakened and p.units[1].attack==4 and p.units[1].maxHp==5 and foe.units[0].toxicPoisoned,"ninjaawake1toxicthen1/1")
	p.units[1].front=1;gs._grow_unit(foe.units[0],3,20);gs.current_player=1;hp=p.units[1].hp;gs.basic_attack(1,0);check(p.units[1].hp==hp,"awakeactualdefensepoisonimmunity")
	foe.units[0].inspired=true;gs.basic_attack(1,0);check(p.units[1].hp<hp,"awakedefenseonlyonceactualturn")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28604",foe.units[1].uid);foe.units[0].front=1;gs._grow_unit(foe.units[0],0,20);hp=p.units[1].hp;play(gs,"c28601");check(p.units[1].hp==hp,"awakecanimmunecounterfromnewlypoisonedenemyinthesamecombat")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;give(gs,"c28501",1);hp=foe.units[0].hp;play(gs,"c28603");check(gs.phase=="choice" and foe.units[0].hp==hp,"ninjacombatwaitserosionchoicebeforeattack");finish(gs)
	check(foe.hand[0].get("handCharm",{}).get("kind")=="erosion" and p.units[1].front==1,"ninjacombatresumesactualattackaftererosion")
	gs=game();p=gs.player(0);foe=gs.player(1);var idx:=give(gs,"c28603");check("instant" not in gs.hand_card_def(0,idx).keywords,"ninjacombatnotinstantearly")
	poisoned(gs);gs._knockout_unit(foe.units[0],0,2);gs._resolve_resolution_stack();check("instant" in gs.hand_card_def(0,idx).keywords and gs.hand_card_def(0,idx).enhanced,"actualpoisonKOgrantsinstantthisturn")
	gs.turn_counter+=1;check("instant" not in gs.hand_card_def(0,idx).keywords,"instantbonusendsactualturn")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;gs._grow_unit(foe.units[2],0,15);hp=foe.units[2].hp;play(gs,"c28605",foe.units[2].uid)
	check(foe.units[2].hp==hp-4 and foe.units[2].toxicPoisoned and p.units[1].shield==0,"pursuitrealreserveattack1attack1armorconsumedbycounter")
	gs=game();p=gs.player(0);foe=gs.player(1);gs._grow_unit(p.units[2],0,10);hp=p.units[2].hp;var face:int=foe.avatarHp;play(gs,"c28607",p.units[2].uid)
	check(p.units[2].hp==hp-3 and p.units[2].toxicPoisoned and foe.avatarHp==face-5 and p.units[1].shield==2,"grudgeallowsfriendly3toxicbefore2/2combat")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;play(gs,"c28606");hp=p.units[1].hp;poisoned(gs);var fire0:int=p.energy;gs._knockout_unit(foe.units[0],0,2);gs._resolve_resolution_stack()
	check(p.units[1].attack==4 and p.units[1].permanentAttack==1 and p.units[1].front==1 and p.units[1].hp==hp and p.energy==fire0,"lonepoisonKOpermanent1andrealfreeimmuneattack")
	check(foe.avatarHp==25,"loneattackactual4plusbase1avatarreward")
	gs._knockout_unit(p.units[1],1,1);gs.VerifiedRules.Peach.revive(gs,0,0,p.units[1],false,false);check(p.units[1].attack==4 and p.units[1].form.is_empty(),"lonepermanentattackpersistsKOandformloss")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28608");check(p.units[1].attack==3 and p.units[1].hp==6 and p.hand.size()==1 and p.hand[0].definitionId=="c28602","shadow3/6entryrealgeneratedlatentnotdraw")
	var deck:int=p.deck.size();var count:int=p.hand.size();gs.VerifiedRules.SilkNinja.turn_start(gs,0);check(p.hand.size()==count+1 and p.deck.size()==deck,"ownturnshadowgeneratesactualcardwithoutdeckdraw")
	var face0:int=foe.avatarHp;gs.basic_attack(0,1);check(foe.avatarHp==face0-6,"attackonlyformcomboactualdouble3avatar")
func negative_and_ai() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);foe.units[0].foxVeil=true;poisoned(gs,1,1);gs._knockout_unit(foe.units[2],0,3);gs.resolution_stack.clear()
	var idx:=give(gs,"c28602");var ts:Array=gs.valid_targets(0,gs.hand_card_def(0,idx));check(foe.units[0].uid not in ts and foe.units[1].uid not in ts and foe.units[2].uid not in ts and "avatar-1" not in ts and foe.units[3].uid in ts,"latenttargetfiltersveilpoisonKOavatar")
	var snap:=JSON.stringify(gs.snapshot());gs.hand_card_def(0,idx);gs.can_play_card(0,idx,foe.units[3].uid);check(JSON.stringify(gs.snapshot())==snap,"queriespuredonotconsumeimmunityrnghistory")
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs,1,0,"silk-decoy","普通召唤物",0,9,{"countsAsShikigami":false})
	foe.units[3].level=0
	check(not gs.can_play_card(0,idx,decoy.uid).ok and gs.play_card(0,idx,foe.units[3].uid) and foe.units[3].toxicPoisoned,"潜伏只对实际零勾式神附毒，不允许非式神召唤物")
	check(not gs.can_play_card(0,give(gs,"c28505"),decoy.uid).ok,"於菊虫的指定剧毒同样拒绝普通召唤物")
	gs=game();p=gs.player(0);p.nullifyNextCardTurn=gs.turn_counter;play(gs,"c28608");check(p.units[1].form.is_empty() and p.hand.is_empty(),"counteredshadowdoesnotgenerateorinstall")
	for prefix in ["c285","c286"]:
		for n in range(1,9):
			gs=game();var id:String=prefix+"%02d"%n;give(gs,id);give(gs,"c28501",1)
			var best:=AI._best_card(gs,0);check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegal "+id)
			check(best.ok and gs.play_card(0,best.hand,best.target),"AIactual "+id);finish(gs)
			check(Content.card_def(id).cost==1 and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalcostandPNG "+id)
func boundaries() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
	for u in foe.units:gs._knockout_unit(u,0,3)
	gs.resolution_stack.clear();var idx:=give(gs,"c28605");var targets:Array=gs.valid_targets(0,gs.hand_card_def(0,idx))
	check(targets==["avatar-1"] and gs.play_card(0,idx,"avatar-1") and foe.avatarHp==26,"pursuitcombatcanhitavatarwhenallopponentsKO")
	gs=game();p=gs.player(0);foe=gs.player(1);foe.units[0].front=1;idx=give(gs,"c28605");check("avatar-1" not in gs.valid_targets(0,gs.hand_card_def(0,idx)),"pursuitcannotbypassoccupiedfronttoavatar")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28608");p.units[1].front=1;gs._grow_unit(foe.units[0],0,20);var enemy_hp:int=foe.units[0].hp;gs.current_player=1;gs.basic_attack(1,0);check(foe.units[0].hp==enemy_hp-3,"shadowattackonlycombonodefensiveextrahit")
	gs=game();p=gs.player(0);foe=gs.player(1);poisoned(gs);gs._knockout_unit(foe.units[0],0,2);gs._resolve_resolution_stack();idx=give(gs,"c28603");check("instant" not in gs.hand_card_def(0,idx).keywords,"ninjainstanteventdoesnotretroactivelyenhancenewhandinstance")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28604",foe.units[1].uid);p.units[1].front=1;gs._grow_unit(foe.units[0],2,20);foe.units[0].keywords=["combo"];poisoned(gs);gs.current_player=1
	var hp:int=p.units[1].hp;gs.basic_attack(1,0);check(p.units[1].hp==hp and events(gs,"ninja-immunity").size()==1,"awakeimmunitycoversbothrealcombohitsonecombat")
	foe.units[0].inspired=true;gs.basic_attack(1,0);check(p.units[1].hp<hp,"sameactualturnnextcombatnotimmuneaftercombo")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28606");foe.units[0].front=1;gs._grow_unit(foe.units[0],5,20);poisoned(gs,1,1);gs._knockout_unit(foe.units[1],0,2);gs._resolve_resolution_stack()
	check(p.units[1].hp==4 and p.units[1].attack==4 and p.units[1].front==1 and foe.units[0].hp==foe.units[0].maxHp-4,"loneactualforcedattackimmunecounterwithoutfakeheal")
	gs._knockout_unit(p.units[1],1,0);gs.resolution_stack.clear();poisoned(gs,1,2);var face:int=foe.avatarHp;gs._knockout_unit(foe.units[2],0,2);gs._resolve_resolution_stack();check(p.units[1].hp==0 and p.units[1].permanentAttack==1 and foe.avatarHp==face-1,"inactiveformenocopyattackorgrowth")
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28502");gs._knockout_unit(p.units[0],1,0);gs.resolution_stack.clear();give(gs,"c28501",1);poisoned(gs,1,1);gs._knockout_unit(foe.units[1],0,1);gs._resolve_resolution_stack();check(gs.pending_choice.get("which")=="erosion","duskpersistscasterKO");finish(gs)
	gs=game();p=gs.player(0);foe=gs.player(1);play(gs,"c28503");var count:int=p.cardsPlayedThisTurn;gs._begin_turn(0);check(p.units[0].formCountdown.remaining==2 and foe.units.filter(func(u):return u.get("toxicPoisoned",false)).size()==1 and p.cardsPlayedThisTurn==0,"actualturnstartcountdownfiresandresets")
	gs=game();p=gs.player(0);play(gs,"c28608");count=events(gs,"silk-shadow-created").size();gs._begin_turn(0);check(events(gs,"silk-shadow-created").size()==count+1,"actualturnstartshadowgeneration")
	gs=game();p=gs.player(0);foe=gs.player(1);gs.current_player=1;p.units[1].front=1;poisoned(gs);give(gs,"c28505");gs.basic_attack(1,0);check(foe.units[0].hp==0 and events(gs,"combat-hit").is_empty(),"responsecancelsdeadattackerbeforeanyhitorexchange")
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme();silk_cards();response_cards();ninja_cards();negative_and_ai();boundaries()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("SILK_NINJA_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]);quit(0 if failures==0 else 1)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["yujuchong","hainren","chongshi","shuweng"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],285286);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		var p:Dictionary=b.gs.player(0);var foe:Dictionary=b.gs.player(1)
		for u in foe.units:b.gs._grow_unit(u,0,15)
		Toxic.apply(b.gs,0,0,1,0);hand(b,["c28602"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and not b._unit_widget(foe.units[0].uid).selected and b._unit_widget(foe.units[1].uid).selected,"nativeonlyunpoisonedenemytargethighlight")
		await click(b._unit_widget(foe.units[1].uid));await settled(b);check(foe.units[1].get("toxicPoisoned",false),"nativeactualselectedlatenttoxic");await capture("%d-01-unpoisoned-target"%physical.x)
		foe.units[2].front=1;hand(b,["c28501"]);await settled(b);var iid:String=p.hand[0].instanceId;await click(b._hand_row.get_child(0));await settled(b)
		check(p.hand.size()==1 and p.hand[0].instanceId==iid and p.hand[0].get("silkBounceSpent",false),"nativeactualsameinstancebouncesonce")
		b.gs._grow_unit(p.units[2],0,10);var hp:int=p.units[2].hp;hand(b,["c28607"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(p.units[2].uid).selected and b._unit_widget(foe.units[3].uid).selected,"nativegrudgeallowsfriendlyandenemyunitselection")
		await click(b._unit_widget(p.units[2].uid));await settled(b);check(p.units[2].hp==hp-3 and p.units[2].get("toxicPoisoned",false) and p.units[1].front==1,"nativefriendly3toxicthenactualcombat");await capture("%d-02-friendly-grudge"%physical.x)
		foe.hand=[{"instanceId":"native-erosion-card","definitionId":"c28501"}];hand(b,["c28603"]);await settled(b);var face:int=foe.avatarHp;await click(b._hand_row.get_child(0));await settled(b)
		check(b.gs.pending_choice.get("which")=="erosion" and foe.avatarHp==face,"nativeninjaslashopensrealerosionbeforecombat")
		await capture("%d-03-erosion-before-combat"%physical.x);await click(choice_face(b));await settled(b)
		check(b.gs.pending_choice.is_empty() and foe.hand[0].get("handCharm",{}).get("kind")=="erosion" and foe.avatarHp<face,"nativeerosionselectionresumesactualattack")
		hand(b,["c28503"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);check(p.units[0].get("formCountdown",{}).get("remaining")==1,"nativeactualnymphcountdown1")
		hand(b,["c28608"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);check(p.units[1].maxHp==6 and p.hand.size()==1 and p.hand[0].definitionId=="c28602" and b._hand_row.get_child_count()==1,"nativeoriginal3/6andrealgeneratedlatentface")
		Toxic.apply(b.gs,0,0,1,3);hand(b,["c28505"]);await settled(b);b.gs.current_player=1;b.gs.basic_attack(1,3);b._last_view={};b._refresh();await settled(b)
		check(foe.units[3].hp==0 and p.hand.is_empty() and b.gs.response_window.is_empty(),"nativebattleactualdawnresponsecompletes")
		var detached:Array=[]
		for cache in [b._unit_widgets,b._hand_widgets]:
			for widget in cache.values():
				if is_instance_valid(widget) and widget.get_parent()==null:detached.append(weakref(widget))
		b.queue_free();await process_frame;await process_frame
		check(detached.all(func(w):return w.get_ref()==null),"nativebattlefreesdetachedcardfaces")

