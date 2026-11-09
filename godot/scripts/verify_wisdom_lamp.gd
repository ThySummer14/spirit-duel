extends "res://scripts/verify_book_jue_ui.gd"
const GS:=preload("res://scripts/game_state.gd")
const WL:=preload("res://scripts/wisdom_lamp_rules.gd")
const HP:=preload("res://scripts/hair_power_rules.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
const Status:=preload("res://scripts/ui/battle_status.gd")
func check(ok:bool,detail:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("WISDOM_LAMP_FAIL ",detail)
func game()->GS:
 var gs:=GS.create(["huimingdeng","shifagui","shantong","yaohu"],["bingyong","bailang","hetong","yaodaoji"],608)
 for p in gs.players:
  p.hand.clear();p.energy=40;p.levelUpUsed=true
  for u in p.units:u.level=3
 return gs
func give(gs,id:String)->int:
 gs.player(0).hand.append({"definitionId":id,"instanceId":"wl-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(0).hand.size()-1
func play(gs,id:String,target=null)->void:check(gs.play_card(0,give(gs,id),target),"actual play "+id)
func turn(gs,owner:int)->void:
 check(gs.end_turn(owner),"actual end turn "+str(owner));gs.player(1-owner).levelUpUsed=true
func hurt_last(gs,idx:int=1)->void:
 turn(gs,0);gs._damage_avatar(0,1,1,idx,false,true);turn(gs,1);gs.player(0).energy=40
func rules()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];var foe:Dictionary=gs.player(1)
 check(u.attack==2 and u.maxHp==5 and HP.amount(u)==0 and u.front==0,"base2/5 no unearned passive")
 hurt_last(gs)
 check(u.front==1 and HP.amount(u)==1 and u.shield==0 and not p.attackUsed,"actual prior combat damage moves without attack/fire/guard and survives normal retreat")
 check(WL.last_sources(gs,0)==[str(foe.units[1].uid)],"real source identity recorded")
 var saved=JSON.parse_string(JSON.stringify(p.wlDamageHistory));check(saved==p.wlDamageHistory,"damage ledger survives JSON roundtrip")
 var h:=give(gs,"c60801");var card:Dictionary=gs.hand_card_def(0,h)
 check(gs.valid_targets(0,card)==[str(foe.units[1].uid)],"purify targets only actual last-turn source")
 gs._damage_avatar(0,1,1,2,false,true)
 check(gs.valid_targets(0,card)==[str(foe.units[1].uid)],"this-turn damage does not erase previous turn or add new target")
 foe.units[1].keywords=["veil"];check(gs.valid_targets(0,card).is_empty(),"veil excludes otherwise eligible target");foe.units[1].keywords=[]
 check(not gs.can_play_card(0,h,foe.units[0].uid).ok,"wrong source rejected before payment")
 foe.units[1].shield=20;foe.units[1].barrier=true;p.energy=0
 check(gs.play_card(0,h,foe.units[1].uid),"swift purify actually pays deployment at zero fire")
 check(foe.units[1].hp==0 and p.attackUsed and p.energy==0 and gs.instant_available(0),"destroy bypasses hp armor barrier; swift not instant")
 turn(gs,0);turn(gs,1)
 check(not WL.damaged_last_turn(gs,0) and gs.valid_targets(0,Content.card_def("c60801")).is_empty(),"previous eligible turn expires even without later damage")
 gs=game();p=gs.player(0);u=p.units[0];turn(gs,0);p.avatarArmor=3;gs._damage_avatar(0,2,1,1,false,true);turn(gs,1)
 check(u.front==0 and HP.amount(u)==0 and not WL.damaged_last_turn(gs,0),"fully armor-absorbed combat is not damage")
 gs=game();p=gs.player(0);u=p.units[0];turn(gs,0);gs._damage_avatar(0,2,1,1);turn(gs,1)
 check(u.front==0 and HP.amount(u)==0,"spell damage does not activate combat condition")
 gs=game();u=gs.player(0).units[0];u.baseRulesSuppressed=true;hurt_last(gs)
 check(u.front==0 and HP.amount(u)==0,"suppressed passive cannot move")
 gs=game();u=gs.player(0).units[0];turn(gs,0);gs._knockout_unit(u);gs._damage_avatar(0,1,1,1,false,true);turn(gs,1)
 check(u.hp==0 and u.front==0,"knocked out source cannot move")
 gs=game();p=gs.player(0);u=p.units[0];play(gs,"c60804")
 check(u.awakened and u.attack==3 and u.maxHp==6 and HP.guard_count(gs,0)==0,"printed awakening1/1 no instant guard")
 check(not gs.can_play_card(0,give(gs,"c60804")).ok,"duplicate awakening forbidden")
 p.hand.clear();hurt_last(gs)
 check(u.front==0 and HP.amount(u)==0 and HP.guard_count(gs,0)==1,"awakening replaces move with selectable guard")
 p.energy=0;p.attackUsed=true;var ally:Dictionary=p.units[2];var hp:int=gs.player(1).avatarHp
 check(gs.basic_attack(0,2,ally.uid),"awakened guard available to another ally")
 check(ally.front==1 and HP.amount(ally)==2 and ally.shield==2 and gs.player(1).avatarHp==hp and p.attackUsed,"real2power2armor without attack or ordinary deployment")
 gs=game();p=gs.player(0);foe=gs.player(1);u=p.units[0];play(gs,"c60802",foe.units[2].uid)
 check(foe.units[2].get("enraged",false) and foe.units[2].attack==2 and HP.amount(u)==0 and HP.guard_count(gs,0)==1,"enrage not attack debuff; guard not immediate power")
 check(gs.basic_attack(0,0,u.uid) and HP.amount(u)==2 and u.attack==2,"guard consumed by actual selected deployment")
 for front in [false,true]:
  gs=game();p=gs.player(0);u=p.units[0];foe=gs.player(1);u.front=1 if front else 0;u.hp=2;p.avatarHp=20
  foe.units[1].hp=2;foe.units[1].baseAttack=0;gs._recalc(foe.units[1])
  h=give(gs,"c60803");card=gs.hand_card_def(0,h)
  check(card.combatOption.wlHeal==front,"Buddha enhancement read before entry")
  check(gs.play_card(0,h,foe.units[1].uid),"actual pursuit into reserve")
  check(foe.units[1].hp==0 and p.avatarHp==(23 if front else 20) and u.hp==(5 if front else 2),"Buddha1power1armor and conditional3heal for both")
 gs=game();p=gs.player(0);u=p.units[0];play(gs,"c60805")
 check(u.attack==3 and u.maxHp==6 and HP.guard_count(gs,0)==1,"mindful exact3/6 with real guard")
 check(gs.basic_attack(0,0,u.uid),"mindful guard deployment");p.avatarHp=20;foe=gs.player(1);foe.units[0].front=1;foe.units[0].barrier=true
 turn(gs,0)
 check(p.avatarHp==22 and foe.units[0].hp==foe.units[0].maxHp and not foe.units[0].barrier and HP.amount(u)==2,"end-turn projectile uses actual war; heal same amount even if damage blocked; war not consumed")
 gs=game();p=gs.player(0);u=p.units[0];play(gs,"c60805");p.avatarHp=20;turn(gs,0)
 check(p.avatarHp==20 and gs.player(1).avatarHp==30,"no power means no invented projectile or healing")
 gs=game();p=gs.player(0);u=p.units[0];gs._knockout_unit(p.units[2]);play(gs,"c60806",p.units[2].uid)
 check(p.units[2].hp==p.units[2].maxHp and HP.guard_count(gs,0)==1 and u.shield==0,"revive full body and separate1/1guard")
 check(gs.basic_attack(0,2,p.units[2].uid) and HP.amount(p.units[2])==1 and p.units[2].shield==1,"revived ally consumes actual guard bonus")
 gs=game();gs._knockout_unit(gs.player(0).units[0]);gs._knockout_unit(gs.player(0).units[2]);h=give(gs,"c60806")
 check(not gs.can_play_card(0,h,gs.player(0).units[2].uid).ok,"revive card has no invented usable-while-knocked permission")
 gs=game();p=gs.player(0);foe=gs.player(1)
 foe.units[0].level=0;foe.units[1].summoned=true;h=give(gs,"c60802")
 check(not gs.can_play_card(0,h,foe.units[1].uid).ok,"enrage rejects a non-shikigami summon")
 check(gs.play_card(0,h,foe.units[0].uid) and foe.units[0].get("enraged",false),"enrage accepts a living zero-rank shikigami")
 gs._knockout_unit(p.units[1]);gs._knockout_unit(p.units[2]);p.units[1].catCannotRevive=true;p.units[2].level=0
 h=give(gs,"c60806")
 check(not gs.can_play_card(0,h,p.units[1].uid).ok and gs.play_card(0,h,p.units[2].uid) and p.units[2].hp>0,"revive respects the actual revive lock and accepts legal zero-rank target")
 gs=game();p=gs.player(0);u=p.units[0];play(gs,"c60807");play(gs,"c60802",gs.player(1).units[1].uid)
 check(u.attack==6 and u.maxHp==6,"karma exact6/6")
 check(gs.basic_attack(0,0,u.uid) and HP.amount(u)==4 and u.shield==2,"karma guard adds2war2armor only when this body deploys")
 gs=game();p=gs.player(0);u=p.units[0];play(gs,"c60807");var before:int=gs.player(1).avatarHp
 check(gs.basic_attack(0,0) and gs.player(1).avatarHp==before-6 and u.shield==0,"ordinary attack gets no invented karma bonus")
 realm_rules();ai_rules()
func realm_rules()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[1];var foe:Dictionary=gs.player(1)
 play(gs,"c60808")
 check(p.realms[0].hp==6 and HP.guard_count(gs,0)==1 and p.units.all(func(x):return x.shield==0),"realm exact6durability and entry guard, no blanket armor")
 u.shield=3;var hp:int=u.hp;var result:Dictionary=gs._damage_unit(0,1,20,1,0)
 check(u.hp==hp and u.shield==0 and int(result.get("dealt",0))==0,"realm cap before armor consumes3 and prevents health damage")
 gs._damage_unit(0,1,1,1,0);check(u.hp==hp-1,"zero armor immediately loses cap")
 u.shield=2;u.armorBreak=10;result=gs._damage_unit(0,1,1,1,0,true,-1,false,true)
 check(u.hp==hp-1 and u.shield==0 and u.armorBreak==0,"armorbreak and critical cannot bypass real cap")
 u.shield=3;check(not gs.VerifiedRules.Panguan.destroy(gs,1,0,0,1) and u.hp>0,"direct destruction blocked with armor")
 u.baseRulesSuppressed=true;check(WL.protected(gs,0,u),"realm protection is independent of recipient passive suppression");u.baseRulesSuppressed=false
 check(not WL.protected(gs,1,foe.units[1]),"realm does not protect enemy")
 var v:Dictionary=Status.unit_view(gs,0,1,0);check(v.wlMarks.any(func(s):return s.contains("免疫消灭")),"live realm protection visible in status")
 gs._knockout_unit(p.units[0]);check(WL.protected(gs,0,u),"realm continues while source is knocked out")
 turn(gs,0);turn(gs,1);check(HP.guard_count(gs,0)==1,"old guard expires and realm supplies one fresh guard")
 p.realms[0].hp=0;check(not WL.protected(gs,0,u) and gs.VerifiedRules.Panguan.destroy(gs,1,0,0,1),"removed realm restores destruction legality")
 gs=game();p=gs.player(0);u=p.units[1];play(gs,"c60808");u.shield=2;gs._knockout_unit(u)
 check(u.hp==0,"forced knockout is not incorrectly treated as direct destruction")
func ai_rules()->void:
 for n in range(1,9):
  var gs:=game();var p:Dictionary=gs.player(0);var id:="c608%02d"%n
  if n==1:hurt_last(gs)
  if n==6:gs._knockout_unit(p.units[2])
  p.hand.clear();var h:=give(gs,id);var c:Dictionary=gs.hand_card_def(0,h)
  var targets:Array=[null] if c.target=="auto" else gs.valid_targets(0,c)
  check(not targets.is_empty(),"AI has legal targets "+id)
  check(AI.take_action(gs,0) and gs.command_log.any(func(e):return e.c=="play_card" and e.a.get("card","")==id),"AI actual play "+id)
  var texture=load("res://assets/official/cards/%s.png"%id)
  check(texture is Texture2D and texture.get_width()>200,"original texture loads "+id)
  check(c.verifiedRules and not c.verificationPending.is_empty(),"native but explicitly pending original verification "+id)
func ui_checks()->void:
 root.theme=ThemeBuilder.build_theme()
 for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
  root.size=physical;DisplayServer.window_set_size(physical)
  var b:=Battle.new();b.setup(["huimingdeng","shifagui","shantong","yaohu"],["bingyong","bailang","hetong","yaodaoji"],608);b._ai_thinking=true
  for p in b.gs.players:
   p.hand.clear();p.energy=40;p.levelUpUsed=true
   for u in p.units:u.level=3
  root.add_child(b);await create_timer(.4).timeout
  var gs=b.gs;var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
  hurt_last(gs);hand(b,["c60801"]);await settled(b)
  await click(b._hand_row.get_child(0));await settled(b)
  check(b._pending_target_card==0 and gs.valid_targets(0,gs.hand_card_def(0,0))==[str(foe.units[1].uid)],"native purify legal source selection")
  await capture("%d-01-purify-target"%physical.x)
  await click(b._unit_widget(str(foe.units[2].uid)));await settled(b)
  check(p.hand.size()==1 and foe.units[2].hp>0,"native wrong source click cannot spend card")
  await click(b._unit_widget(str(foe.units[1].uid)));await settled(b)
  check(p.hand.is_empty() and foe.units[1].hp==0,"native legal source destroyed")
  hand(b,["c60802"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b);await click(b._unit_widget(str(foe.units[2].uid)));await settled(b)
  check(foe.units[2].get("enraged",false) and HP.guard_count(gs,0)==1,"native selected enrage produces guard")
  p.energy=0;p.attackUsed=true;b._refresh();await settled(b)
  await click(b._unit_widget(str(p.units[2].uid)));await settled(b)
  await capture("%d-02-guard-target"%physical.x)
  await click(b._unit_widget(str(p.units[2].uid)));await settled(b)
  check(p.units[2].front==1 and HP.amount(p.units[2])==2 and HP.guard_count(gs,0)==0,"native free guard chooses ally and gives2war")
  gs._knockout_unit(p.units[1]);p.energy=4;hand(b,["c60806"]);await settled(b)
  await click(b._hand_row.get_child(0));await settled(b)
  check(b._pending_target_card==0,"native revive prompts knocked-out ally")
  await capture("%d-03-revive-target"%physical.x)
  await click(b._unit_widget(str(p.units[1].uid)));await settled(b)
  check(p.units[1].hp==p.units[1].maxHp and HP.guard_count(gs,0)==1,"native revive and guard both settled")
  hand(b,["c60808"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
  p.units[2].shield=3;b._refresh();await settled(b)
  check(p.realms.size()==1 and Status.unit_view(gs,0,2,0).wlMarks.any(func(s):return s.contains("伤害上限3")),"native current realm protection data")
  await capture("%d-04-realm"%physical.x)
  b.queue_free();await process_frame;await process_frame
func run()->void:
 var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args()
 if not args.is_empty() and args[0]!="--rules-only":out=args[0];DirAccess.make_dir_recursive_absolute(out)
 rules()
 if not args.has("--rules-only"):await ui_checks()
 Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
 print("WISDOM_LAMP checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
