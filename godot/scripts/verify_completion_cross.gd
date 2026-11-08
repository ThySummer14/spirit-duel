extends SceneTree
const GS:=preload("res://scripts/game_state.gd")
const Food:=preload("res://scripts/cooking_rules.gd")
const EF:=preload("res://scripts/essence_feast_rules.gd")
const MF:=preload("res://scripts/music_fire_rules.gd")
const SG:=preload("res://scripts/serpent_ghost_rules.gd")
const HP:=preload("res://scripts/hair_power_rules.gd")
const FW:=preload("res://scripts/fear_wing_rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("COMPLETION_CROSS_FAIL ",msg)
func game()->GS:
 var gs:=GS.create(["lingyanji","fenpopo","jiao","fansi"],["bayiqidashe","guishiheibai","jinnaluo","shifagui"],1105)
 for p in gs.players:
  p.hand.clear();p.energy=50;p.levelUpUsed=true
  for u in p.units:u.level=3
 return gs
func give(gs,id:String,owner:int=0)->int:
 gs.player(owner).hand.append({"definitionId":id,"instanceId":"completion-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id:String,target=null,owner:int=0)->void:check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)
func food_and_essence()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var target:Dictionary=p.units[3];var atk:int=target.attack
 Food.gain_ingredient(gs,0,2,"mountain");gs._knockout_unit(p.units[2]);gs._resolve_resolution_stack()
 check(gs.play_card(0,0,target.uid),"food from knocked-out generator actually targets Fansi")
 check(int(target.efSatiety)==2 and target.attack==atk+5 and int(p.efFansiTargetCount)==1,"neutral hand food gives2satiety plus actual3ingredient power")
 var before:int=gs.player(1).avatarHp
 check(gs.basic_attack(0,3),"actual fed Fansi attack")
 check(gs.player(1).avatarHp==before-atk-5 and int(target.get("efSatiety",0))==0 and target.attack==atk+3,"actual damage uses nutrition then removes only nutrition")
 EF.gain_essence(gs,0,3);var idx:int=p.hand.size()-1;var fire:int=p.energy;target.hp-=1
 var c:Dictionary=gs.hand_card_def(0,idx)
 check(c.get("neutralEssence",false) and c.unitId=="" and c.efStacks==3 and gs.card_payment(0,c).usesInstant,"stacked essence has its own neutral actor and instant quote")
 check(gs.play_card(0,idx,target.uid),"actual stacked essence use")
 check(p.energy==fire and int(target.efSatiety)==2 and target.hp==target.maxHp,"essence heals exactstack and gives2satiety without food category")
 check(not p.hand.any(func(i):return i.definitionId=="shengmingjinghua"),"actual stacked instance consumed once")
 check(gs.rule_events.any(func(e):return e.kind=="neutral-card-announced" and e.sourceIndex==-1),"essence declaration source is player")
 # The counter uses its real shikigami owner in an independent fixture.
 gs=GS.create(["fansi","fenpopo","jiao","shifagui"],["yaoginshi","bingyong","yaohu","shantong"],1110)
 for side in gs.players:
  side.hand.clear();side.energy=40;side.levelUpUsed=true
  for u in side.units:u.level=3
 p=gs.player(0);EF.gain_essence(gs,0,2);give(gs,"c12807",1);p.avatarHp=20
 check(gs.play_card(0,0,"avatar-0"),"neutral essence actual counter declaration")
 check(p.avatarHp==20 and gs.player(1).hand.is_empty() and gs.rule_events.any(func(e):return e.kind=="card-nullified" and e.uid=="avatar-0"),"counter cancels entire stacked healing without wrong shikigami source")
func full_heal_and_transfer()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var before:int=foe.avatarHp
 gs._heal_avatar(0,2);gs._resolve_resolution_stack()
 check(foe.avatarHp==before-2,"full-life healing still creates real powder over-heal projectile")
 gs._heal_avatar(0,5);gs._resolve_resolution_stack();check(foe.avatarHp==before-2,"powder actual once-turn cap")
 gs=game();p=gs.player(0);foe=gs.player(1);p.avatarToxicPoisoned=true;before=foe.avatarHp
 gs._heal_avatar(0,5);gs._resolve_resolution_stack();check(foe.avatarHp==before,"poison-blocked healing cannot fabricate over-heal")
 gs=game();p=gs.player(0);play(gs,"c60603");var target:Dictionary=p.units[2];var hp:int=target.hp;var avatar:int=p.avatarHp
 target.formRules.monkReduction=1
 var result:Dictionary=gs._damage_unit(0,2,4,1,0);gs._resolve_resolution_stack()
 check(target.hp==hp-2 and p.avatarHp==avatar-1 and result.dealt==2,"spring transfer does not apply original flat reduction twice")
 check(int(p.efDamagePackets)==1 and p.hand.any(func(i):return i.definitionId=="shengmingjinghua"),"redirected actual avatar packet generates true essence")
 gs=game();p=gs.player(0);play(gs,"c60603");target=p.units[2];hp=target.hp;avatar=p.avatarHp;target.formRules.damageCap=3;target.shield=2
 result=gs._damage_unit(0,2,10,1,0);gs._resolve_resolution_stack()
 check(target.hp==hp-2 and p.avatarHp==avatar-1 and target.shield==0,"spring works on final capped packet after consuming original armor once")
func fire_and_snakes()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var fire:Dictionary=p.units[0];play(gs,"c26304",gs.player(1).units[0].uid)
 gs._heal_unit(fire,3);gs._resolve_resolution_stack();fire.frozen=1;fire.bondMarks=[{"owner":0}]
 gs._damage_unit(0,0,30,1,0);gs._resolve_resolution_stack()
 check(MF.fire(fire) and fire.hp==1 and fire.frozen==1 and fire.get("bondMarks",[]).size()==1,"real fire switch preserves stun and attached charm")
 var hp:int=fire.hp;gs._damage_unit(0,0,2,1,0);gs._resolve_resolution_stack()
 check(fire.hp==hp+2 and MF.fire(fire),"noncombat damage converts to real fire healing")
 gs._damage_unit(0,0,2,1,0);gs._resolve_resolution_stack()
 check(not MF.fire(fire) and fire.hp==fire.maxHp and fire.frozen==1,"full fire returns human after converted healing, preserving state")
 gs=GS.create(["bayiqidashe","lingyanji","guishiheibai","shifagui"],["bingyong","shantong","yaohu","hetong"],220263)
 for side in gs.players:
  side.hand.clear();side.energy=50;side.levelUpUsed=true
  for u in side.units:u.level=3
 p=gs.player(0);var white:Dictionary=p.units[2];white.charge=2;HP.give(gs,0,2,4)
 gs._damage_unit(0,1,50,1,0);gs._damage_unit(0,2,50,1,0);gs._resolve_resolution_stack()
 check(MF.fire(p.units[1]) and not p.units[1].get("sgSnake",false),"own fire death replacement precedes allied snake transformation")
 check(white.get("sgWhite",false) and not white.get("sgSnake",false) and white.charge==0,"own charged ghost switch precedes allied snake transformation")
 var old_id:String=str(p.units[3].id);var old_uid:String=str(p.units[3].uid)
 gs._damage_unit(0,3,50,1,0);gs._resolve_resolution_stack()
 check(p.units[3].get("sgSnake",false) and p.units[3].id==old_id and p.units[3].uid==old_uid and p.units[3].attack==3,"ordinary ally actually transforms while preserving deck and runtime identity")
 check(not HP.source(p.units[3]) and gs.VerifiedRules.SunSmoke.has_charge(white)==false,"effective body suppresses original role without deleting base identity")
 gs._damage_unit(0,3,50,1,0);gs._resolve_resolution_stack()
 check(not p.units[3].get("sgSnake",false) and p.units[3].id==old_id and int(p.units[3].hp)==0,"snake death restores original knocked-out body")
 check(gs.resolution_stack.is_empty(),"mixed transformation continuations drain")
func guard_integration()->void:
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1);var fire:int=p.energy
 play(gs,"c63802");check(HP.guard_count(gs,0)==1,"real Fansi form grants shared guard credit")
 var hp:int=foe.avatarHp;p.energy=0;p.attackUsed=true
 check(gs.basic_attack(0,3,p.units[3].uid) and p.units[3].front==1 and foe.avatarHp==hp and p.energy==0,"shared guard stands without attacking at zero fire")
 check(p.attackUsed and HP.guard_count(gs,0)==0,"guard does not reset or spend ordinary deployment")
 check(gs.resolution_stack.is_empty(),"guard and meal-form triggers finish")
func fear_and_power()->void:
 var gs:=GS.create(["shifagui","tiannimei","fansi","jiao"],["lingyanji","guishiheibai","bayiqidashe","jinnaluo"],609611)
 for side in gs.players:
  side.hand.clear();side.energy=40;side.levelUpUsed=true
  for u in side.units:u.level=3
 var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
 foe.units[0].hp=3;foe.units[1].hp=3;foe.units[1].charge=2
 check(FW.attach(gs,0,1,foe.units[0].uid) and FW.attach(gs,0,1,foe.units[1].uid),"actual mixed fear attachments")
 play(gs,"c60903",p.units[1].uid)
 check(HP.amount(p.units[1])==3 and p.units[1].attack==3,"hair ally-target grants real fear-source power")
 check(MF.fire(foe.units[0]) and not foe.units[0].get("sgSnake",false) and foe.units[0].get("fearCharm",{}).is_empty(),"fear death damage drains into own fire switch before serpent and clears dead-body charm")
 check(foe.units[1].get("sgWhite",false) and not foe.units[1].get("sgSnake",false) and foe.units[1].get("fearCharm",{}).is_empty(),"same power event independently resolves charged ghost switch")
 var hp:int=foe.avatarHp
 check(gs.basic_attack(0,1) and foe.avatarHp==hp-6 and HP.amount(p.units[1])==0,"fear packets do not consume war before its actual battle")
 check(gs.resolution_stack.is_empty(),"fear and two identity replacements drain once")
func _initialize()->void:
 food_and_essence();full_heal_and_transfer();fire_and_snakes();guard_integration();fear_and_power()
 if failures==0:print("COMPLETION_CROSS_OK checks=",checks)
 else:printerr("COMPLETION_CROSS_FAILED checks=",checks," failures=",failures)
 quit(1 if failures else 0)
