extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const MF := preload("res://scripts/music_fire_rules.gd")
func check(ok: bool,detail: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("MUSIC_FIRE_FAIL ",detail)
func game(enemy: Array=["bingyong","shantong","bailang","hetong"]) -> GS:
 var gs:=GS.create(["jinnaluo","lingyanji","bingyong","shantong"],enemy,256263)
 for side in gs.players:
  side.hand.clear();side.energy=40;side.levelUpUsed=true
  for u in side.units:u.level=3
 gs.rule_events.clear();return gs
func give(gs,id: String,owner: int=0) -> int:
 gs.player(owner).hand.append({"definitionId":id,"instanceId":"music-fire-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,owner: int=0) -> void:
 check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)
func finish(gs) -> void:
 var n:=0
 while not gs.pending_choice.is_empty() and n<20:
  n+=1;check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"actual divination continuation")
 check(n<20 and gs.resolution_stack.is_empty(),"choice stack drains")
func strong(u: Dictionary,hp: int=100,attack: int=0) -> void:
 u.baseMaxHp=hp;u.maxHp=hp;u.hp=hp;u.baseAttack=attack;u.attack=attack;u.attackBonus=0;u.maxHpBonus=0
func total(gs,side: int) -> int:
 var amount:int=gs.player(side).avatarHp
 for u in gs.player(side).units:amount+=int(u.hp)
 return amount
func to_fire(gs,owner: int=0,idx: int=1) -> Dictionary:
 var u:Dictionary=gs.player(owner).units[idx];gs._knockout_unit(u,1-owner,0);gs._resolve_resolution_stack();return u
func music_cards() -> void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
 check(p.units[0].attack==2 and p.units[0].maxHp==5,"jinna base2/5")
 var deck:int=p.deck.size();play(gs,"c25601")
 check(p.night==1 and gs.pending_choice.get("type","")=="native-divination","zero-night enhanced first gainsnight then actual1divination")
 finish(gs);check(p.deck.size()==deck-1 and p.energy==40,"zero-night second instance draws once and uses instant")
 deck=p.deck.size();play(gs,"c25601");finish(gs);check(p.deck.size()==deck-1 and p.energy==39,"nonzero night only one draw, instant allowance consumed")
 gs=game();p=gs.player(0);foe=gs.player(1)
 for u in foe.units:strong(u)
 foe.units[0].front=1;p.night=0;gs.rng_state=1
 var hp:int=total(gs,1);play(gs,"c25603")
 check(foe.units[0].hp==96 and total(gs,1)==hp-4 and p.night==1,"front4 then failedfortune base raises night without fabricated randomhit")
 check(int(gs.kw_usage(0,"fortune").last.threshold)==6,"local printed threshold6 at night0")
 gs=game();p=gs.player(0);foe=gs.player(1)
 for u in foe.units:strong(u)
 foe.units[0].front=1;p.night=10;hp=total(gs,1);play(gs,"c25603")
 check(total(gs,1)==hp-9,"front4 plus successfulavatar4 plus base random1")
 check(gs.kw_usage(0,"fortune").last.threshold==1,"night10 threshold clamps1")
 gs=game();p=gs.player(0);foe=gs.player(1);p.night=10;p.units[0].spellPower=2
 for u in foe.units:strong(u)
 foe.units[0].front=1;var marked:int=give(gs,"c25603");p.hand[marked].handCharm={"kind":"ward","effects":["spell+1"]};hp=total(gs,1)
 check(gs.play_card(0,marked),"actualmarked musicspell")
 check(total(gs,1)==hp-15,"source+2 andactualspellcharm+1 apply toboth4spellhits, baseability1 unchanged")
 check(gs.rule_events.filter(func(e):return e.kind=="damage-resolved" and e.get("card",{}).get("id","")=="c25603").size()==2,"delayedfortune reward retains originalspellcontext")
 gs=game();p=gs.player(0);foe=gs.player(1);p.night=10
 for u in foe.units:strong(u)
 hp=total(gs,1);play(gs,"c25604",foe.units[2].uid)
 check(total(gs,1)==hp-11,"target5 then allfivecharacters1 plus independentbase1")
 gs=game();p=gs.player(0);foe=gs.player(1);p.night=10
 for u in foe.units:strong(u)
 play(gs,"c25605");var doll:Dictionary=gs.front_unit(0)
 check(p.units[0].attack==4 and p.units[0].maxHp==5 and doll.get("mfDoll",false),"exact4/5 form summons actualdoll")
 check((doll.baseAttack==2 and doll.baseMaxHp==4 and gs.VerifiedRules.Combat.has(doll,"lifesteal")) or (doll.baseAttack==4 and doll.baseMaxHp==2 and doll.swift),"officialexclusive2/4lifesteal or4/2swift body")
 var uid:String=doll.uid;gs.VerifiedRules.Movement.move_to(gs,0,gs.front_index(0),0)
 check(doll.get("removed",false) and doll.hp==0,"forcedreserve move immediately removes realdoll")
 var d:int=p.deck.size();play(gs,"c25606")
 check(p.units[0].attack==4 and p.units[0].maxHp==5 and p.deck.size()==d-1,"feather exact4/5 and actualentryfortune draw")
 var count:int=p.hand.size();var before:int=total(gs,1);var energy:int=p.energy;play(gs,"c25607")
 check(p.units[0].awakened and p.units[0].attack==5 and p.units[0].maxHp==6,"music awaken actual1/1")
 check(p.hand.size()==count+2 and p.hand.all(func(i):return i.definitionId!="c25607"),"actual two generated othercards excludes own awakening")
 check(total(gs,1)==before-1 and p.energy==energy-1,"awakening ownfortune observed old base before install")
 before=total(gs,1);energy=p.energy;MF._roll(gs,0,0,"draw");gs._resolve_resolution_stack()
 check(total(gs,1)==before-3 and p.energy==mini(4,energy+1),"awake fortune independent3damage then night10 actualfire gain")
 var h:=give(gs,"c25607");var old_attack:int=p.units[0].attack;var old_max:int=p.units[0].maxHp
 check(gs.can_play_card(0,h).ok and gs.play_card(0,h),"repeat music awaken retains realfortune generationeffect")
 check(p.units[0].attack==old_attack and p.units[0].maxHp==old_max,"repeat awakening neverduplicates1/1 bodygain")
 gs=game();p=gs.player(0);foe=gs.player(1);p.night=10
 play(gs,"c25602");strong(foe.units[0],30,4);gs.current_player=1;gs._resolve_combat(1,0,0,false,false,false,false);gs._resolve_resolution_stack()
 check(p.units[0].get("mfPalaceTurn",-1)==gs.turn_counter and foe.units[0].attack==3,"palace enemyactualattack fortune reduces realpower once")
 var penalties:int=foe.units[0].get("mfPowerPenalty",0);gs._resolve_combat(1,0,0,false,false,false,false);gs._resolve_resolution_stack()
 check(foe.units[0].get("mfPowerPenalty",0)==penalties,"palace onceperglobalturn even multipleattacks")
 MF.end_turn(gs,1);check(foe.units[0].attack==4,"palace printedtemporary reduction expires")
 gs=game();p=gs.player(0);foe=gs.player(1);p.night=3;strong(foe.units[0],20,2);strong(foe.units[1],20,6);foe.units[1].hp=3
 var card:Dictionary=Content.card_def("c25608");var targets:Array=gs.valid_targets(0,card)
 check(targets.has(foe.units[0].uid) and targets.has(foe.units[1].uid) and not targets.has("avatar-1"),"finale attackORlife predicate never treats avatar as0power")
 foe.units[1].keywords=["veil"];check(not gs.valid_targets(0,card).has(foe.units[1].uid),"finale enemyveil filtered")
 play(gs,"c25608",foe.units[0].uid);check(foe.units[0].hp==0 and p.night==4,"lowpower targetdestroyed and night10 failure advancesnight")
 gs=game();p=gs.player(0);foe=gs.player(1);p.night=10;play(gs,"c25608",foe.units[0].uid)
 check(foe.units[0].hp==0 and foe.units[0].knockout==4,"night10 adds2 to actualdeadcountdown")
 gs=game();gs.player(0).night=10;gs.player(1).avatarHp=8;play(gs,"c25608","avatar-1");check(gs.winner==0,"finale actuallowHPavatar directdestroy")
func fire_lifecycle() -> void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[1];var uid:String=u.uid
 check(u.attack==3 and u.maxHp==4,"lingyan exact3/4")
 u.frozen=2;u.enraged=true;u.pipeMarks=[{"owner":1,"sourceUid":foe.units[0].uid}];u.shield=7;u.armorBreak=5
 gs._knockout_unit(u,1,0)
 check(u.hp==0 and u.get("mfSwitchPending",false) and not MF.fire(u),"death reserves switch until damagegroup returns")
 gs._resolve_resolution_stack()
 check(MF.fire(u) and u.hp==1 and u.maxHp==4 and u.attack==0 and u.front==0 and u.knockout==0,"actual0/4fire at1HP instead of artificialsummon")
 check(u.uid==uid and u.id=="lingyanji" and u.frozen==2 and u.enraged and u.pipeMarks.size()==1,"switch retains originalsource identity, stun,enrage and charm")
 check(u.shield==0 and u.armorBreak==0,"switch clears armor andarmorbreak")
 for target in foe.units:strong(target,20)
 u.frozen=0;gs._heal_unit(u,3)
 check(MF.fire(u) and u.get("mfFullPending",false),"fullheal queues switch without interrupting healinggroup")
 gs._resolve_resolution_stack()
 check(not MF.fire(u) and u.hp==4 and u.attack==3 and u.uid==uid,"full actualbody restored")
 check(foe.units.all(func(t):return t.hp==19) and foe.avatarHp==30,"normalfire switch1AOE units only")
 u=to_fire(gs);gs._damage_unit(0,1,1,1,0);gs._resolve_resolution_stack()
 check(not MF.fire(u) and u.hp==0 and u.knockout==2 and u.name=="铃彦姬","fire actualdeath restores knockedout human no infiniteflip")
 gs=game();u=gs.player(0).units[1];gs._grow_unit(u,2,3);u.charge=5;uid=u.uid;u=to_fire(gs)
 check(u.hp==1 and u.maxHp==7 and u.attack==2 and u.charge==5,"enduringbody buffs andcharge retained on switch")
 gs._heal_unit(u,6);gs._resolve_resolution_stack();check(not MF.fire(u) and u.hp==7 and u.attack==5,"enhancedfire compares actualmaxHP notprinted4")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[1];u.hp=1;u.front=1;strong(foe.units[0],30,1)
 gs._resolve_combat(1,0,0,false,false,true,false);gs._resolve_resolution_stack()
 check(u.hp==0 and u.knockout==2 and not MF.fire(u),"combo secondhit hits switchedfire and can knock itout")
 gs=game();u=to_fire(gs);gs.player(0).avatarHp=10;play(gs,"c26305")
 check(u.awakened and u.get("mfFireAwakened",false) and u.hp==1 and u.attack==2,"Chinese awakening permanent2 and extra actualfireawakening without foreignheal3")
 check(gs.rule_events.any(func(e):return e.kind=="automatic-card" and e.card.id=="mf-fire-awakening"),"fireawakening traverses actualadditionalcard pipeline")
 for target in gs.player(1).units:strong(target,20)
 gs._heal_unit(u,3);gs._resolve_resolution_stack()
 check(gs.player(1).units.all(func(t):return t.hp==17),"awakefire AOE equals actuallevel3")
 var before:int=u.attack;play(gs,"c26305");check(u.attack==before+2,"repeat printedpermanent2 gain remains real without duplicateawakening1/1")
func fire_cards() -> void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:=to_fire(gs)
 play(gs,"c26301");check(not MF.fire(u) and u.hp==4,"bell actualattack then selfheal3 switchesbody")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[1];u.hp=2;p.avatarHp=20;strong(foe.units[0],30,6);foe.units[0].front=1
 play(gs,"c26306")
 check(u.hp==4 and p.avatarHp==26 and foe.units[0].hp==27,"bath actual3attack incoming6 replaced by6heal to selfandavatar")
 check(not u.get("mfBathCombat",false),"bath applies only that combat")
 gs=game();p=gs.player(0);foe=gs.player(1);u=to_fire(gs);p.avatarHp=20;give(gs,"c26306");strong(foe.units[0],30,3);gs.current_player=1
 gs._resolve_combat(1,0,0,false,false,false,false);gs._resolve_resolution_stack()
 check(p.avatarHp==23 and p.energy==39 and p.hand.is_empty(),"actualavatarresponse consumes onephysicalcard/onefire and converts3 toheal")
 check(not MF.fire(u) and u.front==1 and u.hp==4 and foe.units[0].hp==29,"response redirectsactualtarget tofire then fullswitch realAOE")
 gs=game();p=gs.player(0);u=to_fire(gs);p.avatarHp=20;p.units[2].hp=1;play(gs,"c26302")
 check(MF.fire(u) and u.hp==3 and p.avatarHp==21 and p.units[2].hp==2,"healingfield entry allcharacters1 and fireadditional1")
 var realm:Dictionary=p.realms.back();MF.trigger_realm(gs,0,realm);gs._resolve_resolution_stack()
 check(not MF.fire(u) and u.hp==4,"healingfield realpulse completes fullfire return")
 gs=game();p=gs.player(0);foe=gs.player(1);strong(foe.units[1],30);play(gs,"c26304",foe.units[1].uid);u=p.units[1]
 check(MF.fire(u) and u.hp==1 and foe.units[1].hp==26,"flame entry exacttwo4damage then deferredhumanfire")
 var result:Dictionary=gs._damage_unit(0,1,3,1,0);gs._resolve_resolution_stack()
 check(result.get("convertedToHealing",false) and not MF.fire(u) and u.hp==4,"ownturn flame replaces realnoncombatdamage with healing")
 gs=game();p=gs.player(0);foe=gs.player(1);strong(foe.units[0],30);foe.units[0].front=1;u=to_fire(gs)
 play(gs,"c26308")
 check(not MF.fire(u) and u.hp==4 and foe.units[0].hp==26,"eternal fireactual3attack thenfullheal andhuman1AOE")
 u=to_fire(gs);check(u.attack==3 and MF.combat_immune(gs,0,1),"eternal ownturncontinuous3 andimmune outside itsforcedattack")
 gs.current_player=1;gs._recalc(u);check(u.attack==0 and not MF.combat_immune(gs,0,1),"eternal aura absent on enemyturn")
 gs=game();p=gs.player(0);u=p.units[1];u.hp=1;var h:=give(gs,"c26307");var original:String=p.hand[h].instanceId
 check(gs.play_card(0,h,u.uid),"actualinstantbounceheal first")
 check(u.hp==4 and p.energy==40 and p.hand.size()==1 and p.hand[0].instanceId==original,"heals5 then returns samephysicalinstance once")
 check(not gs.hand_card_def(0,0).keywords.has("bounce") and gs.play_card(0,0,u.uid) and p.hand.is_empty() and p.energy==39,"spentbounce absent and secondplaydoesnotreturn")
func metadata_ai() -> void:
 for role_id in [256,263]:
  for n in range(1,9):
   var id:String="c%d%02d"%[role_id,n];var c:Dictionary=Content.card_def(id)
   check(c.get("verifiedRules",false) and not c.get("verificationPending",[]).is_empty(),"native fullmetadata "+id)
   check(ResourceLoader.exists("res://assets/official/cards/%s.png"%id),"realoriginaltexture "+id)
 for id in ["mf-fire","mf-fire-awakened","mf-doll-blood","mf-doll-swift"]:check(not Content.unit_def(id).is_empty() and not Content.playable_units().any(func(u):return u.id==id),"derivedidentity neverinventedconstructibleentry "+id)
 var gs:=game();gs.player(0).night=10
 for role_id in [256,263]:
  for n in range(1,9):
   var id:String="c%d%02d"%[role_id,n];var h:=give(gs,id);var card:Dictionary=gs.hand_card_def(0,h)
   var targets:Array=[null] if card.get("target","auto")=="auto" else gs.valid_targets(0,card)
   check(not targets.is_empty() and targets.any(func(t):return gs.can_play_card(0,h,t).ok and AI._score_card(gs,0,card,t)>0),"AI actuallegalcandidate "+id)
   gs.player(0).hand.clear()
func ui_checks() -> void:
 root.theme=ThemeBuilder.build_theme()
 for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
  root.size=physical
  if not out.is_empty():DisplayServer.window_set_size(physical)
  var b:=Battle.new();b.setup(["jinnaluo","lingyanji","bingyong","shantong"],["bingyong","shantong","bailang","hetong"],256263);b._ai_thinking=true
  for side in b.gs.players:
   side.hand.clear();side.energy=40;side.levelUpUsed=true
   for u in side.units:u.level=3
  root.add_child(b);await create_timer(0.4).timeout
  var gs=b.gs;var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);p.night=3;strong(foe.units[0],20,2);strong(foe.units[1],20,6);foe.units[1].hp=3
  hand(b,["c25608"]);await settled(b);await click(b._hand_row.get_child(0))
  check(b._pending_target_card==0 and not gs.valid_targets(0,b._pending_target_card_def).has("avatar-1"),"native finaletarget mode realORpredicate "+str(physical))
  var energy:int=p.energy;await click(b._enemy_plate);check(b._pending_target_card==0 and p.energy==energy,"native invalidavatar doesnotpay")
  await capture("%d-01-finale-target"%physical.x)
  await click(b._unit_widget(str(foe.units[1].uid)));await settled(b);check(foe.units[1].hp==0,"native selectedlowHP reserve actuallydestroyed")
  var fire_body:=to_fire(gs);hand(b,["c26307"]);await settled(b)
  check(b._unit_widget(str(fire_body.uid)).data.name=="神火铃焰","native actualfirebody portrait/identity")
  await capture("%d-02-real-fire"%physical.x)
  await click(b._hand_row.get_child(0));await click(b._unit_widget(str(fire_body.uid)));await settled(b)
  check(not MF.fire(fire_body) and fire_body.hp==4 and p.hand.size()==1,"native actualheal switchesandbounces samecard")
  await capture("%d-03-heal-switch-bounce"%physical.x)
  hand(b,["c25601"]);p.night=0;await settled(b);await click(b._hand_row.get_child(0));await settled(b)
  check(gs.pending_choice.get("type","")=="native-divination" and is_instance_valid(b._choice_layer),"native zero-night enhances into actualdivination")
  var tile:=choice_face(b)
  if tile!=null:await click(tile);await settled(b)
  tile=choice_face(b,"divination-place-top")
  if tile!=null:await click(tile);await settled(b)
  check(gs.pending_choice.is_empty(),"native divination click resumes once")
  b.queue_free();await process_frame;await process_frame
func run() -> void:
 var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args()
 if not args.is_empty() and args[0]!="--rules-only":out=args[0];DirAccess.make_dir_recursive_absolute(out)
 music_cards();fire_lifecycle();fire_cards();metadata_ai()
 if not args.has("--rules-only"):await ui_checks()
 Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
 print("MUSIC_FIRE checks=%d failures=%d rules_only=%s"%[checks,failures,str(args.has("--rules-only"))]);quit(0 if failures==0 else 1)
