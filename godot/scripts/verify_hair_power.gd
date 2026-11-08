extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const HP:=preload("res://scripts/hair_power_rules.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
func check(ok:bool,detail:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("HAIR_FAIL ",detail)
func game()->GS:
 var gs:=GS.create(["shifagui","shantong","bingyong","yaohu"],["bingyong","bailang","hetong","yaodaoji"],609)
 for p in gs.players:
  p.hand.clear();p.energy=80;p.levelUpUsed=true
  for u in p.units:u.level=3
 return gs
func give(gs,id:String)->int:
 gs.player(0).hand.append({"definitionId":id,"instanceId":"hair-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(0).hand.size()-1
func play(gs,id:String,target=null)->void:check(gs.play_card(0,give(gs,id),target),"actual play "+id)
func turn(gs,owner:int)->void:check(gs.end_turn(owner),"actual end turn "+str(owner));gs.player(1-owner).levelUpUsed=true
func strong(gs,u:Dictionary,hp:int,attack:int=0)->void:
 u.baseMaxHp=hp;u.maxHpBonus=0;u.baseAttack=attack;u.attackBonus=0;gs._recalc(u);u.hp=hp
func rules()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];var foe:Dictionary=gs.player(1)
 check(u.attack==1 and u.maxHp==6 and HP.amount(u)==2,"base1/6 with distinct starting2 battle power")
 var hp:int=foe.avatarHp;var fire:int=p.energy
 check(gs.basic_attack(0,0),"actual basic with battle power")
 check(foe.avatarHp==hp-3 and u.attack==1 and HP.amount(u)==0 and p.energy==fire-1,"battle damage bonus clears without changing printed attack")
 HP.give(gs,0,1,5);turn(gs,0);turn(gs,1)
 check(HP.amount(p.units[1])==0 and HP.amount(u)==2,"unused power expires before new own-turn passive")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[0].front=1;strong(gs,foe.units[0],20,5)
 HP.give(gs,0,0,-4);check(u.attack==1 and HP.amount(u)==-2,"fatigue is not attack debuff")
 var before:int=foe.units[0].hp;check(gs.basic_attack(0,0),"fatigued actual battle")
 check(foe.units[0].hp==before and u.hp==1 and HP.amount(u)==0,"negative battle modifier floors0 then expires")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];p.energy=0
 var handidx:=give(gs,"c60901");var card:Dictionary=gs.hand_card_def(0,handidx)
 check(gs.card_payment(0,card).get("usesSwift",false) and gs.can_play_card(0,handidx).ok,"swift card read-only quote permits zero fire")
 check(not p.attackUsed and HP.amount(u)==2,"quote does not spend deployment or power")
 check(gs.play_card(0,handidx),"actual swift-card fire replacement")
 check(p.energy==0 and p.attackUsed and foe.avatarHp==27 and HP.amount(u)==0,"swift consumes ordinary deployment not instant allowance")
 check(gs.instant_available(0),"swift does not consume instant")
 handidx=give(gs,"c60901");check(not gs.can_play_card(0,handidx).ok,"no fire and no deployment rejects swift")
 p.energy=1;check(gs.play_card(0,handidx) and p.energy==0,"swift falls back to fire when deployment spent")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 handidx=give(gs,"c60901");p.hand[handidx].handCharm={"kind":"ward","effects":["instant"]}
 check(gs.card_payment(0,gs.hand_card_def(0,handidx)).usesInstant and not gs.card_payment(0,gs.hand_card_def(0,handidx)).get("usesSwift",false),"instant precedes swift")
 check(gs.play_card(0,handidx) and not p.attackUsed and not gs.instant_available(0),"actual instant precedence preserves deployment")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[0].front=1;strong(gs,foe.units[0],20,0);foe.units[0].shield=20;foe.units[0].barrier=true
 play(gs,"c60901");check(foe.units[0].shield==0 and not foe.units[0].barrier and foe.units[0].hp==17,"printed penetration strips armor and barrier before actual3damage")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[0].front=1;strong(gs,foe.units[0],20,4)
 play(gs,"c60902");check(u.hp==4 and foe.units[0].hp==17 and u.shield==0,"hair wrap exact power-based2armor before attack, no invented attack bonus")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];var target:Dictionary=p.units[1]
 play(gs,"c60903",target.uid);check(HP.amount(target)==3 and target.attack==3 and p.realms[0].hp==5,"fear entry grants selected real3power not permanent growth")
 foe.units[0].front=1;strong(gs,foe.units[0],2,0);var avatar:int=foe.avatarHp
 check(gs.basic_attack(0,1),"power-bearing ally actual attack with fear realm")
 check(foe.avatarHp==avatar-4 and HP.amount(target)==0,"fear grants pierce only attack into enemy frontline")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];foe.units[0].front=1;strong(gs,foe.units[0],3,4)
 play(gs,"c60905",foe.units[0].uid)
 check(foe.units[0].hp==0 and u.hp==4 and HP.amount(u)==2 and u.attack==1,"whip gives2power/2fatigue before battle and returns half actual own4power after kill")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 play(gs,"c60904",foe.units[1].uid)
 check(u.awakened and u.attack==2 and u.maxHp==7 and HP.amount(u)==4 and HP.amount(foe.units[1])==-2,"awakening exact1/1 and separate resource gains")
 var idx:=give(gs,"c60904");check(not gs.can_play_card(0,idx,foe.units[1].uid).ok,"duplicate awakening illegal")
 turn(gs,0);turn(gs,1);check(HP.amount(u)==2 and int(u.hairAwakeTurns)==1,"first awakening turn gives2 then grows future value")
 gs._knockout_unit(u);turn(gs,0);turn(gs,1)
 check(u.hp==0 and int(u.hairAwakeTurns)==2 and HP.amount(u)==0,"awakening counter grows while knocked out without giving absent body power")
 turn(gs,0);turn(gs,1);check(u.hp>0 and HP.amount(u)==4 and int(u.hairAwakeTurns)==3,"natural revive receives correct grown war value")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 for enemy in foe.units:strong(gs,enemy,10,0)
 foe.units[0].shield=1;foe.units[1].barrier=true
 play(gs,"c60906")
 check(u.attack==5 and u.maxHp==8 and HP.amount(u)==4,"true face exact5/8 and only two actual damage grant2power")
 check(foe.units[0].hp==10 and foe.units[1].hp==10 and foe.units[2].hp==9 and foe.units[3].hp==9,"form entry actual all-unit damage respects armor/barrier")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0]
 play(gs,"c60907");check(p.realms[0].hp==5 and HP.amount(u)==5 and HP.amount(p.units[1])==3,"fearless instant realm gives all allies3power")
 foe.units[0].front=1;strong(gs,foe.units[0],1,0);play(gs,"c60901")
 check(not p.attackUsed and foe.units[0].hp==0,"enemy front actual knockout resets deployment consumed by swift")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];gs._knockout_unit(u)
 play(gs,"c60908");check(u.hp==7 and u.attack==2 and HP.amount(u)==2 and u.form.cardId=="c60908","joy actually revives into printed2/7 and2battle power")
 turn(gs,0);check(HP.amount(u)==5,"joy gains3 on enemy turn without own expiry")
 for n in range(1,9):
  gs=game();p=gs.player(0);foe=gs.player(1);var id:="c609%02d"%n;var h:=give(gs,id);var c:Dictionary=gs.hand_card_def(0,h)
  check(ResourceLoader.exists("res://assets/official/cards/%s.png"%id),"original texture "+id)
  var targets:Array=[null] if c.target=="auto" else gs.valid_targets(0,c)
  check(not targets.is_empty() and gs.can_play_card(0,h,targets[0]).ok and AI._score_card(gs,0,c,targets[0])>0 and gs.play_card(0,h,targets[0]),"AI legal source/target/payment and actual execution "+id)
func guard_rules()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var u:Dictionary=p.units[1]
 HP.grant_guard(gs,0);p.energy=0;p.attackUsed=true;var before:int=foe.avatarHp
 check(HP.guard_count(gs,0)==1 and gs.can_basic_attack(0,1).ok,"guard special deployment exists independently of ordinary deployment and fire")
 gs._apply_encourage(0,2,3)
 check(gs.basic_attack_targets(0,1)==[u.uid] and not gs.basic_attack(0,1,foe.units[0].uid),"guard targets own unit and rejects enemy as an attack target")
 check(gs.basic_attack(0,1,u.uid),"actual guard deploy at zero fire")
 check(u.front==1 and HP.amount(u)==2 and u.attack==3 and u.shield==3 and foe.avatarHp==before and p.energy==0 and p.attackUsed,"guard moves without attacking and converts encouragement to battle power")
 check(HP.guard_count(gs,0)==0 and not gs.can_basic_attack(0,1).ok,"guard consumes only special deployment once")
 HP.grant_guard(gs,0);p.attackUsed=false;var h:=give(gs,"c60901")
 check(gs.card_payment(0,gs.hand_card_def(0,h)).get("usesGuard",false),"swift prefers guard credit to ordinary deployment")
 check(gs.play_card(0,h) and HP.guard_count(gs,0)==0 and not p.attackUsed,"swift using guard still performs card's real attack without spending ordinary deployment")
 HP.grant_guard(gs,0);turn(gs,0);turn(gs,1);check(HP.guard_count(gs,0)==0,"unused guard expires at next own start")
 gs=game();u=gs.player(0).units[1];u.baseRulesSuppressed=true;u.level=0
 HP.give(gs,0,1,3);check(HP.amount(u)==3,"battle power can target a living suppressed or unlevelled body independently of its passive")
 u.removed=true;HP.give(gs,0,1,2);check(HP.amount(u)==3,"removed body cannot gain battle power")
 u.removed=false;u.hp=0;HP.clear(u);HP.give(gs,0,1,2);check(HP.amount(u)==0,"knocked-out body cannot gain battle power")
func ui_checks()->void:
 root.theme=ThemeBuilder.build_theme()
 for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
  root.size=physical
  if not out.is_empty():DisplayServer.window_set_size(physical)
  var b:=Battle.new();b.setup(["shifagui","shantong","bingyong","yaohu"],["bingyong","bailang","hetong","yaodaoji"],609);b._ai_thinking=true
  for p in b.gs.players:
   p.hand.clear();p.energy=40;p.levelUpUsed=true
   for u in p.units:u.level=3
  root.add_child(b);await create_timer(.4).timeout
  var gs=b.gs;var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
  hand(b,["c60903"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
  check(b._pending_target_card==0,"native fear chooses actual ally")
  await capture("%d-01-power-target"%physical.x)
  await click(b._unit_widget(str(p.units[1].uid)));await settled(b)
  check(HP.amount(p.units[1])==3 and p.units[1].attack==3,"native selected ally gets resource without attack change")
  hand(b,["c60905"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
  check(b._pending_target_card==0,"native whip pursuit target mode")
  await capture("%d-02-pursuit"%physical.x)
  await click(b._unit_widget(str(foe.units[1].uid)));await settled(b)
  check(foe.units[1].hp==0 and HP.amount(p.units[0])==2,"native whip picks reserve and refunds consumed war")
  hand(b,["c60901"]);p.attackUsed=false;p.energy=0;b._refresh();await settled(b)
  check(b._hand_row.get_child(0).data.payment.get("usesSwift",false),"native hand shows swift exact payment")
  await click(b._hand_row.get_child(0));await settled(b)
  check(p.energy==0 and p.attackUsed,"native swift pays deployment at0fire")
  await capture("%d-03-swift"%physical.x)
  HP.grant_guard(gs,0);var old_hp:int=foe.avatarHp;b._refresh();await settled(b)
  await click(b._unit_widget(str(p.units[1].uid)));await settled(b)
  check(b._selected_attacker==1 and texts(b).contains("再次点击选中的己方式神移入战斗区"),"native zero-fire guard selects reserve ally and explains own-unit target")
  await capture("%d-04-guard-target"%physical.x)
  await click(b._unit_widget(str(p.units[1].uid)));await settled(b)
  check(p.units[1].front==1 and HP.guard_count(gs,0)==0 and foe.avatarHp==old_hp and p.energy==0 and p.attackUsed,"native guard click moves chosen ally without attack or fire")
  b.queue_free();await process_frame;await process_frame
func run()->void:
 var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args()
 if not args.is_empty() and args[0]!="--rules-only":out=args[0];DirAccess.make_dir_recursive_absolute(out)
 rules();guard_rules()
 if not args.has("--rules-only"):await ui_checks()
 Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
 print("HAIR_POWER checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
