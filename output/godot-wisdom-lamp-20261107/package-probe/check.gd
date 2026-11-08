extends SceneTree
const Content:=preload("res://scripts/content_loader.gd")
const GS:=preload("res://scripts/game_state.gd")
const WL:=preload("res://scripts/wisdom_lamp_rules.gd")
const HP:=preload("res://scripts/hair_power_rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,detail:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("PACKAGE_FAIL ",detail)
func give(gs,id:String,owner:int=0)->int:
 gs.player(owner).hand.append({"definitionId":id,"instanceId":"package-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func game()->GS:
 var gs:=GS.create(["huimingdeng","shifagui","jinnaluo","tiannimei"],["bingyong","lingyanji","fansi","jiao"],1107)
 for p in gs.players:
  p.hand.clear();p.energy=40;p.levelUpUsed=true
  for u in p.units:u.level=3
 return gs
func turn(gs,owner:int)->void:
 check(gs.end_turn(owner),"packed actual end turn "+str(owner));gs.player(1-owner).levelUpUsed=true
func _initialize()->void:
 for n in range(1,9):
  var id:="c608%02d"%n;var c:=Content.card_def(id)
  check(not c.is_empty() and c.get("verifiedRules",false) and not c.get("verificationPending",[]).is_empty(),"packed native and pending main "+id)
  var texture=load("res://assets/official/cards/%s.png"%id)
  check(texture is Texture2D and texture.get_width()>200 and texture.get_height()>200,"packed original texture actually loads "+id)
 var unit:=Content.unit_def("huimingdeng")
 check(unit.get("wisdomLampRules",false) and Content.playable_units().any(func(v):return v.id=="huimingdeng"),"packed wisdom lamp playable with native passive")
 var gs:=game();var p:Dictionary=gs.player(0);var u:Dictionary=p.units[0];var foe:Dictionary=gs.player(1)
 check(u.attack==2 and u.maxHp==5 and HP.amount(u)==0,"packed base2/5 without unearned war")
 turn(gs,0);gs._damage_avatar(0,1,1,0,false,true);turn(gs,1);p.energy=40
 check(u.front==1 and HP.amount(u)==1 and not p.attackUsed,"packed prior combat damage moves and grants war without attack")
 var h:=give(gs,"c60801");var card:Dictionary=gs.hand_card_def(0,h)
 check(gs.valid_targets(0,card)==[str(foe.units[0].uid)],"packed purify targets only actual source")
 check(gs.play_card(0,h,foe.units[0].uid) and foe.units[0].hp==0,"packed purify destroys through stats")
 gs=game();p=gs.player(0);u=p.units[0];foe=gs.player(1)
 check(gs.play_card(0,give(gs,"c60802"),foe.units[2].uid) and foe.units[2].get("enraged",false) and HP.guard_count(gs,0)==1,"packed enrage grants selectable guard")
 p.attackUsed=true
 check(gs.basic_attack(0,1,p.units[1].uid) and HP.amount(p.units[1])==2 and HP.guard_count(gs,0)==0,"packed guard deploys food-hair ally with real war")
 gs=game();p=gs.player(0);u=p.units[0];foe=gs.player(1)
 check(gs.play_card(0,give(gs,"c60805")) and u.attack==3 and u.maxHp==6,"packed mindful form exact3/6")
 check(gs.basic_attack(0,0,u.uid),"packed mindful guard deployment")
 p.avatarHp=20;foe.units[0].front=1;foe.units[0].barrier=true
 turn(gs,0)
 check(p.avatarHp==22 and foe.units[0].hp==foe.units[0].maxHp and not foe.units[0].barrier and HP.amount(u)==2,"packed end-turn projectile heals through blocked damage")
 gs=game();p=gs.player(0);u=p.units[1]
 check(gs.play_card(0,give(gs,"c60808")) and p.realms[0].hp==6,"packed realm exact6 durability")
 u.shield=3;var hp:int=u.hp;var result:Dictionary=gs._damage_unit(0,1,20,1,0)
 check(u.hp==hp and u.shield==0 and int(result.get("dealt",0))==0,"packed realm cap consumes armor before health")
 check(WL.protected(gs,0,u)==false or u.shield>0,"packed protection tracks remaining armor")
 gs=game();p=gs.player(0);gs._knockout_unit(p.units[2])
 check(gs.play_card(0,give(gs,"c60806"),p.units[2].uid) and p.units[2].hp==p.units[2].maxHp and HP.guard_count(gs,0)==1,"packed revive full body with separate guard")
 print("WISDOM_LAMP_PACKAGE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)