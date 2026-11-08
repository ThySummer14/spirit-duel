extends SceneTree
const Content:=preload("res://scripts/content_loader.gd")
const GS:=preload("res://scripts/game_state.gd")
const HP:=preload("res://scripts/hair_power_rules.gd")
const MF:=preload("res://scripts/music_fire_rules.gd")
const SG:=preload("res://scripts/serpent_ghost_rules.gd")
const EF:=preload("res://scripts/essence_feast_rules.gd")
const FW:=preload("res://scripts/fear_wing_rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,detail:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("PACKAGE_FAIL ",detail)
func give(gs,id:String,owner:int=0)->int:
 gs.player(owner).hand.append({"definitionId":id,"instanceId":"package-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func game()->GS:
 var gs:=GS.create(["shifagui","tiannimei","jiao","fansi"],["lingyanji","jinnaluo","bayiqidashe","guishiheibai"],1105)
 for p in gs.players:
  p.hand.clear();p.energy=40;p.levelUpUsed=true
  for u in p.units:u.level=3
 return gs
func _initialize()->void:
 for role in [609,256,263,220,194,603,606,638,611]:
  for n in ([1,2,3,4,5,6,8,9] if role==194 else range(1,9)):
   var id:="c%d%02d"%[role,n];var c:=Content.card_def(id)
   check(not c.is_empty() and c.get("verifiedRules",false) and not c.get("verificationPending",[]).is_empty(),"packed native and pending main "+id)
   var texture=load("res://assets/official/cards/%s.png"%id)
   check(texture is Texture2D and texture.get_width()>200 and texture.get_height()>200,"packed original texture actually loads "+id)
 for id in ["mf-fire","mf-fire-awakened","mf-doll-blood","mf-doll-swift","sg-snake","sg-ghost-white","ef-powder-box"]:
  var u:=Content.unit_def(id)
  check(not u.is_empty() and u.get("token",false) and not Content.playable_units().any(func(v):return v.id==id),"packed derivative excluded from deck builder "+id)
 for id in ["shengmingjinghua","juyi","fear-wing-charm","mf-fire-awakening","sg-white-awaken","sg-white-soul"]:
  var c:=Content.card_def(id)
  check(c.get("verifiedRules",false) and int(c.get("deckLimit",0))==0 and not c.get("verificationPending",[]).is_empty(),"packed nonconstructible derivative "+id)
 for id in ["juyi","fear-wing-charm","sg-white-awaken","sg-white-soul"]:
  check(load("res://assets/official/cards/%s.png"%id) is Texture2D,"packed derived texture actually loads "+id)
 var gs:=game();var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
 var original:int=p.units[0].attack;var hp:int=foe.avatarHp
 check(HP.amount(p.units[0])==2 and gs.basic_attack(0,0),"packed initial war and actual basic attack")
 check(foe.avatarHp==hp-original-2 and HP.amount(p.units[0])==0 and p.units[0].attack==original,"packed war is damage resource not permanent attack")
 HP.grant_guard(gs,0);p.energy=0;p.attackUsed=true;hp=foe.avatarHp
 check(gs.basic_attack(0,3,p.units[3].uid) and p.units[3].front==1 and p.attackUsed and foe.avatarHp==hp and HP.guard_count(gs,0)==0,"packed free guard standing without attack")
 p.energy=40;var target:Dictionary=foe.units[1];target.baseMaxHp=20;gs._recalc(target);target.hp=20
 check(FW.attach(gs,0,1,str(target.uid)),"packed true fear attachment")
 HP.give(gs,0,1,2);gs._resolve_resolution_stack()
 check(target.hp==18 and HP.amount(p.units[1])==2,"packed fear observes shared war gain")
 FW.gain(gs,0,3);check(p.hand.size()==2 and int(p.hand[0].fearStacks)==2 and int(p.hand[1].fearStacks)==1,"packed fear wings stack max2")
 p.hand.clear();EF.gain_essence(gs,0,3);p.avatarHp=24
 check(gs.play_card(0,0,"avatar-0") and p.avatarHp==27 and p.hand.is_empty(),"packed neutral stacked essence actual play")
 check(gs.play_card(0,give(gs,"c60603")),"packed spring form actual installation")
 var avatar:int=p.avatarHp;var body:int=p.units[2].hp
 gs._damage_unit(0,2,3,1,1);gs._resolve_resolution_stack()
 check(p.avatarHp==avatar-1 and p.units[2].hp==body-2,"packed spring transfers only1 and keeps remaining damage")
 gs._damage_unit(1,0,50,0,0);gs._resolve_resolution_stack()
 check(MF.fire(foe.units[0]) and not foe.units[0].get("sgSnake",false),"packed own fire replacement precedes Orochi")
 foe.units[3].charge=2;gs._damage_unit(1,3,50,0,0);gs._resolve_resolution_stack()
 check(foe.units[3].get("sgWhite",false) and not foe.units[3].get("sgSnake",false),"packed own ghost replacement precedes Orochi")
 gs._damage_unit(1,1,50,0,0);gs._resolve_resolution_stack()
 check(foe.units[1].get("sgSnake",false) and foe.units[1].id=="jinnaluo","packed snake transforms effective body preserving deck identity")
 check(gs.resolution_stack.is_empty(),"packed mixed match drains effects")
 print("COMPLETION_DRIVE_PACKAGE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
