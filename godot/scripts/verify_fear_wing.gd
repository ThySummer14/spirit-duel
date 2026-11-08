extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const FW:=preload("res://scripts/fear_wing_rules.gd")
const HP:=preload("res://scripts/hair_power_rules.gd")
const Content:=preload("res://scripts/content_loader.gd")
const AI:=preload("res://scripts/game_ai.gd")
func check(ok:bool,detail:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FEAR_WING_FAIL ",detail)
func game(own:Array=["tiannimei","shantong","bingyong","yaohu"])->GS:
 var gs:=GS.create(own,["yaodaoji","bailang","hetong","shantong"],611)
 for p in gs.players:
  p.hand.clear();p.energy=40;p.levelUpUsed=true
  for u in p.units:u.level=3
 gs.rule_events.clear();return gs
func give(gs,id:String,stacks:int=1)->int:
 gs.player(0).hand.append({"definitionId":id,"instanceId":"fear-test-%d"%gs.next_card_id,"fearStacks":stacks});gs.next_card_id+=1;return gs.player(0).hand.size()-1
func play(gs,id:String,target=null)->void:check(gs.play_card(0,give(gs,id),target),"actual play "+id)
func strong(gs,u:Dictionary,hp:int,attack:int=0)->void:
 u.baseMaxHp=hp;u.maxHpBonus=0;u.baseAttack=attack;u.attackBonus=0;gs._recalc(u);u.hp=hp
func layers(p:Dictionary)->int:
 var n:int=0
 for i in p.hand:
  if i.definitionId=="juyi":n+=int(i.get("fearStacks",1))
 return n
func choices(gs)->void:
 var n:int=0
 while not gs.pending_choice.is_empty() and n<10:
  n+=1;check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"actual AI choice continuation")
 check(gs.resolution_stack.is_empty() and n<10,"all real continuations drained")
func rules()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
 check(u.attack==3 and u.maxHp==4 and HP.amount(u)==0,"base exact3/4, no energy substitution")
 FW.gain(gs,0,5);check(p.hand.size()==3 and layers(p)==5 and p.hand[0].fearStacks==2 and p.hand[2].fearStacks==1,"real max2 stacks allocate2/2/1 instances")
 var card:Dictionary=gs.hand_card_def(0,0)
 check(card.fearStacks==2 and card.cost==1 and card.keywords.has("instant") and card.currentCardStats.contains("2／2"),"instance describes true2layers and1costinstant")
 var fire:int=p.energy
 check(gs.play_card(0,0,u.uid),"actual instant stackedwing play")
 check(HP.amount(u)==2 and u.attack==3 and p.energy==fire and not gs.instant_available(0),"two layers grant2power, no printedattack; instant consumes allowance")
 check(gs.play_card(0,0,u.uid) and p.energy==fire-1 and HP.amount(u)==4,"second wing uses actual1fire")
 check(gs.valid_targets(0,Content.card_def("juyi"))==[u.uid],"withoutnight wing selftarget only")
 var h:int=give(gs,"juyi");check(not gs.can_play_card(0,h,p.units[1].uid).ok and not gs.can_play_card(0,h,foe.units[0].uid).ok,"wing rejects otherally and enemy withoutnight")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 for enemy in foe.units:strong(gs,enemy,20)
 play(gs,"c61102",foe.units[0].uid)
 check(foe.units[0].hp==19 and HP.amount(u)==1 and u.attack==3 and layers(p)==2,"tremble attaches then real1power triggers1damage and generates2winglayers")
 check(not foe.units[0].fearCharm.is_empty() and foe.units[0].attack==0,"fear is attachedcharm and never attackdebuff")
 h=give(gs,"c61102");check(not gs.can_play_card(0,h,foe.units[0].uid).ok,"cannot retarget existing fear")
 foe.units[1].keywords=["veil"]
 check(not gs.valid_targets(0,gs.hand_card_def(0,h)).has(foe.units[1].uid),"targeted fear excludes enemyveil")
 u.spellPower=4;HP.give(gs,0,0,2);gs._resolve_resolution_stack()
 check(foe.units[0].hp==17,"fear packet uses exactresource gain and is outside spellpower")
 HP.give(gs,0,0,-2);gs._resolve_resolution_stack();check(foe.units[0].hp==17,"negative resource never triggers fear damage")
 HP.give(gs,0,1,3);gs._resolve_resolution_stack();check(foe.units[0].hp==17,"otherally power does not trigger source-linkedcharm")
 check(not FW.attach(gs,0,0,foe.units[0].uid),"fear cannot stack")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 play(gs,"c61103",foe.units[0].uid)
 check(u.awakened and u.attack==3 and u.maxHp==5 and foe.units[0].hp>0 and layers(p)==0,"awake exact0/1 and attach withoutinvented instant/damage")
 h=give(gs,"c61103");check(not gs.can_play_card(0,h,foe.units[1].uid).ok,"alreadyawake rejected withoutpaying")
 p.hand.clear();gs._knockout_unit(foe.units[2],0,1);gs._resolve_resolution_stack()
 check(layers(p)==1,"awakened observes any actual enemyshikigami death")
 gs._knockout_unit(p.units[1],1,0);gs._resolve_resolution_stack();check(layers(p)==1,"ownside death neverawake wing")
 check(gs.end_turn(0),"actual turntoenemy");foe.levelUpUsed=true
 check(gs.end_turn(1),"actual turnback");p.levelUpUsed=true
 check(layers(p)==2,"awake replaces base and gainsone, nottwo, on ownbegin")
 gs._knockout_unit(u,1,0);gs._resolve_resolution_stack();check(foe.units[0].get("fearCharm",{}).is_empty(),"sourced fear allremoved onsource knockout")
 var n:int=layers(p);gs._knockout_unit(foe.units[1],0,1);gs._resolve_resolution_stack();check(layers(p)==n,"knocked source cannot gain awakenedwing")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 play(gs,"c61105")
 check(u.attack==4 and u.maxHp==5 and gs.pending_choice.get("type","")=="fw-fear-target","printed4/5form enters then asks trueenemyfear choice")
 check(not gs.resolve_divination_choice(0,p.units[1].uid),"formchoice rejects ownunit")
 check(gs.resolve_divination_choice(0,foe.units[0].uid),"formchoice actualselect enemy")
 FW.attach(gs,0,0,foe.units[1].uid);gs._knockout_unit(foe.units[0],0,1);gs._resolve_resolution_stack()
 check(p.hand.size()==1 and p.hand[0].definitionId=="c61101","fearedenemy death yields actualshadowcard")
 gs._knockout_unit(foe.units[1],0,1);gs._resolve_resolution_stack();check(p.hand.size()==1,"formonceperglobalturn")
 gs.turn_counter+=1;FW.attach(gs,0,0,foe.units[2].uid);gs._knockout_unit(foe.units[2],0,1);gs._resolve_resolution_stack();check(p.hand.size()==2,"newglobalturn replenishesformonce")
 gs=game();p=gs.player(0);foe=gs.player(1)
 for enemy in foe.units:FW.attach(gs,0,0,enemy.uid)
 play(gs,"c61105");check(gs.pending_choice.is_empty() and p.units[0].attack==4,"form stilllegal whenno eligiblefear target")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 strong(gs,foe.units[0],4,10);foe.units[0].front=1;HP.give(gs,0,0,1)
 h=give(gs,"c61101");check(gs.hand_card_def(0,h).keywords.has("first-strike"),"shadow enhancedfirststrike withrealpower")
 fire=p.energy;check(gs.play_card(0,h),"shadowactualenhanced combat")
 check(foe.units[0].hp==0 and u.hp==4 and HP.amount(u)==0 and p.energy==fire-1 and not p.attackUsed,"shadow0bonus truefirststrike kill, no invented swift")
 check(foe.units.filter(func(t):return not t.get("fearCharm",{}).is_empty()).size()==1,"shadowrealcombatkill randomlyfear eligibleenemy")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 h=give(gs,"c61101");check(not gs.hand_card_def(0,h).keywords.has("first-strike"),"shadow nofirststrike withoutpower")
 strong(gs,foe.units[0],4,10);foe.units[0].front=1;check(gs.play_card(0,h),"shadowactualunenhancedcombat")
 check(u.hp==0 and foe.units[0].hp==1 and foe.units.filter(func(t):return not t.get("fearCharm",{}).is_empty()).is_empty(),"unenhancedshadow simultaneous lethal no fakekillfear")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 strong(gs,foe.units[0],2);foe.units[0].front=1;FW.attach(gs,0,0,foe.units[0].uid);HP.give(gs,0,0,2);gs.resolution_stack.clear();foe.units[0].hp=2
 play(gs,"c61106")
 check(foe.units[0].hp==0 and foe.avatarHp==22 and HP.amount(u)==0 and u.shield==1,"wind doublesreal2to4, resolves fear2beforetargetselection, attacksface8, printedarmor1")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];HP.give(gs,0,0,2)
 play(gs,"c61106");check(foe.avatarHp==24,"wind intoavatar neverdoublespower")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 for enemy in foe.units:strong(gs,enemy,30)
 foe.units[2].keywords=["veil"];gs._knockout_unit(foe.units[3],0,1)
 play(gs,"c61107");check(foe.units.filter(func(t):return not t.get("fearCharm",{}).is_empty()).size()==3 and layers(p)==2,"allfear includesveil andexcludes dead, generatesexact2layers")
 HP.give(gs,0,0,2);gs._resolve_resolution_stack();check(foe.units[0].hp==28 and foe.units[1].hp==28 and foe.units[2].hp==28,"eachattachedcharm exact2damage includingveil")
 FW.reset_character(gs,u);check(foe.units.all(func(t):return t.get("fearCharm",{}).is_empty()),"actualreset cleanup removes sourcecharms")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 play(gs,"c61104");check(p.realms[0].hp==5 and layers(p)==1 and foe.units.filter(func(t):return not t.get("fearCharm",{}).is_empty()).size()==1,"night actualentry5durability randomfear andonewing")
 check(gs.valid_targets(0,Content.card_def("juyi")).size()==4,"night wing targets allfourlivingallies")
 gs._knockout_unit(u,1,0);gs._resolve_resolution_stack();h=give(gs,"juyi",2)
 check(gs.hand_card_def(0,h).allowKnockedSource and gs.can_play_card(0,h,p.units[1].uid).ok,"night allowsknockedsource wing onotherally")
 check(gs.play_card(0,h,p.units[1].uid) and HP.amount(p.units[1])==2,"night actualwing allygrantwhilecasterdead")
 p.realms[0].hp=0;h=give(gs,"juyi");check(not gs.can_play_card(0,h,p.units[1].uid).ok,"destroyednight immediatelyloses knockedpermission")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];strong(gs,foe.units[0],100,20);foe.units[0].front=1
 give(gs,"juyi",1);give(gs,"juyi",2);give(gs,"juyi",2);fire=p.energy
 play(gs,"c61108");check(gs.pending_choice.get("type","")=="fw-spread" and p.attackUsed and p.energy==fire,"spread uses swiftordinarydeployment thenasksrealwinginstance")
 check(not gs.resolve_divination_choice(1,str(p.hand[0].instanceId)) and not gs.resolve_divination_choice(0,"nonexistent"),"spread rejects wrongowner ormissinginstance")
 choices(gs)
 check(foe.units[0].hp==92 and u.hp==4 and u.shield==0 and HP.amount(u)==0,"spread usesstrongest2+2 realstacks, printed1combat, immunitynotarmor")
 check(p.hand.size()==1 and layers(p)==1 and p.energy==fire and gs.instant_available(0),"automaticwings consumeexact2cards, nofireorinstantcost")
 check(gs.rule_events.filter(func(e):return e.kind=="fear-wing-auto-used").size()==2,"two actual automaticwinguses announced")
 check(gs.rule_events.filter(func(e):return e.kind=="automatic-card" and e.get("card",{}).get("id","")=="juyi").size()==2,"automaticwingusestillrealcardannouncements")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 play(gs,"c61108");check(foe.avatarHp==26 and gs.pending_choice.is_empty(),"spread withzerowings stillprinted1combat andneverfabricateswing")
 gs=game();p=gs.player(0);foe=gs.player(1);p.hand.clear();give(gs,"c61102");foe.units[0].keywords=["veil"]
 var best:Dictionary=AI._best_card(gs,0)
 check(best.ok and best.target!=foe.units[0].uid and gs.valid_targets(0,gs.hand_card_def(0,best.hand)).has(best.target),"AI selects actuallegal unfearedvisibleenemy")
 check(gs.play_card(0,best.hand,best.target) and not gs._unit_by_uid(foe.units,str(best.target)).get("fearCharm",{}).is_empty(),"AI selectedactualtremble resolves")
func edges()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
 strong(gs,foe.units[0],30);foe.units[0].baseRulesSuppressed=true;foe.units[0].level=0
 var h:int=give(gs,"c61102")
 check(gs.valid_targets(0,gs.hand_card_def(0,h)).has(foe.units[0].uid),"fear targets living suppressedlevel0shikigami")
 check(gs.play_card(0,h,foe.units[0].uid) and foe.units[0].hp==29,"suppressedtarget stillreceives attachedfeardamage")
 u.baseRulesSuppressed=true;HP.give(gs,0,0,2);gs._resolve_resolution_stack()
 check(foe.units[0].hp==29,"suppressedsource ability producesno fearpacket")
 gs._knockout_unit(u,1,1);gs._resolve_resolution_stack();check(foe.units[0].get("fearCharm",{}).is_empty(),"sourceknockout removespreviouscharms evenwhensource suppressed")
 gs=game(["tiannimei","xiaoxiuzhishou","bingyong","yaohu"]);p=gs.player(0);foe=gs.player(1)
 for enemy in foe.units:strong(gs,enemy,50)
 play(gs,"c29608");FW.attach(gs,0,0,foe.units[0].uid);var old:int=foe.units[0].hp
 HP.give(gs,0,0,2);gs._resolve_resolution_stack()
 check(foe.units[0].hp==old-2,"fear is independentcharm damage, neverreceives basics-only awakenedSleevebonus")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 for i in int(gs.rules.maxHandSize):give(gs,"c61101")
 var count:int=p.hand.size();FW.gain(gs,0,3);check(p.hand.size()==count and layers(p)==0,"fullhand neveroverfills fornew winginstance")
 p.hand.pop_back();give(gs,"juyi",1);FW.gain(gs,0,3)
 check(p.hand.size()==count and layers(p)==2,"fullhand canfill existingstack butdoesnotcreate excessinstances")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];FW.gain(gs,0,1)
 play(gs,"c61108");check(foe.avatarHp==25 and layers(p)==0 and gs.pending_choice.is_empty(),"spread usesavailableoneactualwing withoutfabricating second")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 play(gs,"c61104");p.hand.clear();gs._knockout_unit(u,1,0);gs._resolve_resolution_stack()
 gs.player(0).units[1].baseRulesSuppressed=true
 h=give(gs,"juyi",2)
 check(gs.can_play_card(0,h,p.units[1].uid).ok and gs.play_card(0,h,p.units[1].uid),"night wing maytarget suppressedlivingally")
 check(HP.amount(p.units[1])==2,"suppression neverblocks externalwarresource grant")
func direct_combat()->void:
 var gs:=game();var foe:Dictionary=gs.player(1);var u:Dictionary=gs.player(0).units[0]
 strong(gs,foe.units[0],100);foe.units[0].front=1;HP.give(gs,0,0,2)
 gs._resolve_combat(0,0,1,false,false,false,false,null,false,{"fearDouble":true,"directAvatar":true,"combatCard":Content.card_def("c61106")});gs._resolve_resolution_stack()
 check(foe.avatarHp==24 and foe.units[0].hp==100 and HP.amount(u)==0,"winddirectavatar ignoresenemyfront andnever doubles")
func ai_cards()->void:
 for n in range(1,9):
  var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var cid:String="c611%02d"%n
  for enemy in foe.units:strong(gs,enemy,100)
  foe.units[0].front=1
  give(gs,cid)
  if n==8:FW.gain(gs,0,4)
  var best:Dictionary=AI._best_card(gs,0)
  check(best.ok and best.card_id==cid and gs.can_play_card(0,best.hand,best.target).ok,"actual AI chooseslegal "+cid)
  if best.ok:check(gs.play_card(0,best.hand,best.target),"AI actual play "+cid)
  choices(gs)
  check(gs.response_window.is_empty() and gs.pending_choice.is_empty(),"AI final legal stack "+cid)
func stacked_choice(b, count:int)->Control:
 for face in faces(b._choice_layer):
  if face.data.get("id","")=="juyi" and int(face.data.get("fearStacks",1))==count:return face
 return null
func ui_checks()->void:
 root.theme=ThemeBuilder.build_theme()
 for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
  root.size=physical
  if not out.is_empty():DisplayServer.window_set_size(physical)
  var b:=Battle.new();b.setup(["tiannimei","shantong","bingyong","yaohu"],["yaodaoji","bailang","hetong","shantong"],611);b._ai_thinking=true
  for side in b.gs.players:
   side.hand.clear();side.energy=40;side.levelUpUsed=true
   for unit in side.units:unit.level=3
  root.add_child(b);await create_timer(.4).timeout
  var gs=b.gs;var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[0]
  for enemy in foe.units:strong(gs,enemy,20)
  hand(b,["c61102"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
  check(b._pending_target_card==0,"native tremble trueenemy target mode")
  await capture("%d-01-unfeared-target"%physical.x)
  await click(b._unit_widget(str(p.units[1].uid)));await settled(b)
  check(b._pending_target_card==0 and p.energy==40,"native rejects friendlyfear withoutpayment")
  await click(b._unit_widget(str(foe.units[1].uid)));await settled(b)
  check(foe.units[1].hp==19 and HP.amount(u)==1 and layers(p)==2,"native tremble exactfear andonepower, generatedreal2stack")
  check(b._hand_row.get_child(0).data.fearStacks==2 and not b._unit_widget(str(foe.units[1].uid)).data.get("fearWingMarks",[]).is_empty(),"native displays truewingstack andattachedmark")
  await capture("%d-02-stacked-wing-and-fear"%physical.x)
  hand(b,["c61105"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
  check(gs.pending_choice.get("type","")=="fw-fear-target" and is_instance_valid(b._choice_layer),"native4/5form actualenemychoice layer")
  await capture("%d-03-form-fear-choice"%physical.x)
  var target_face:Control=choice_face(b,str(foe.units[2].uid));check(target_face!=null,"native form exposes realtargetUID")
  if target_face!=null:await click(target_face);await settled(b)
  check(gs.pending_choice.is_empty() and not foe.units[2].get("fearCharm",{}).is_empty() and u.attack==4 and u.maxHp==5,"native selection attachesactualcharm onprinted4/5form")
  strong(gs,foe.units[0],100,20);foe.units[0].front=1
  hand(b,["c61108","juyi","juyi","juyi"]);p.hand[1].fearStacks=2;p.hand[2].fearStacks=1;p.hand[3].fearStacks=2;p.attackUsed=false;b._refresh();await settled(b)
  var fire:int=p.energy;await click(b._hand_row.get_child(0));await settled(b)
  check(gs.pending_choice.get("type","")=="fw-spread" and is_instance_valid(b._choice_layer),"native spread selectsactualstackinstances")
  check(stacked_choice(b,2)!=null and stacked_choice(b,1)!=null,"native selection showsdistinctstackvalues")
  await capture("%d-04-spread-stack-choice"%physical.x)
  var chosen:Control=stacked_choice(b,2);check(chosen!=null,"native stack2choice exists")
  if chosen!=null:await click(chosen);await settled(b)
  chosen=stacked_choice(b,2);check(chosen!=null,"native secondrealstack2choice exists")
  if chosen!=null:await click(chosen);await settled(b)
  check(gs.pending_choice.is_empty() and foe.units[0].hp==90 and u.hp==5 and u.shield==0,"native two chosenstack2cards resolvebefore actualimmune10combat")
  check(p.hand.size()==1 and layers(p)==1 and p.attackUsed and p.energy==fire,"native spread consumesonlyselected2instances andactualswiftpayment")
  await capture("%d-05-spread-resolved"%physical.x)
  hand(b,["c61104"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
  gs._knockout_unit(u,1,0);gs._resolve_resolution_stack();hand(b,["juyi"]);p.hand[0].fearStacks=2;b._refresh();await settled(b)
  await click(b._hand_row.get_child(0));await settled(b)
  check(b._pending_target_card==0,"native nightallows wingtarget whilecasterknocked")
  await capture("%d-06-night-knocked-target"%physical.x)
  await click(b._unit_widget(str(p.units[1].uid)));await settled(b)
  check(u.hp==0 and HP.amount(p.units[1])==2,"native knockedcaster actual2power tootherally")
  b.queue_free();await process_frame;await process_frame
func run()->void:
 var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args()
 if not args.is_empty() and args[0]!="--rules-only":out=args[0];DirAccess.make_dir_recursive_absolute(out)
 rules();edges();direct_combat();ai_cards()
 if not args.has("--rules-only"):await ui_checks()
 Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
 print("FEAR_WING checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
