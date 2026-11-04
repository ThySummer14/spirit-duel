extends SceneTree
const Content:=preload("res://scripts/content_loader.gd")
const GS:=preload("res://scripts/game_state.gd")
const Food:=preload("res://scripts/cooking_rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,detail:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("PACKAGE_FAIL ",detail)
func _initialize() -> void:
 for role in [246,247,249,250,252,253]:
  for n in range(1,9):
   var id:="c%d%02d"%[role,n];var c:=Content.card_def(id)
   check(not c.is_empty() and (c.get("verifiedRules",false) if id!="c24908" else not c.get("verifiedRules",true)),"packed exact reviewed status "+id)
   check(ResourceLoader.exists("res://assets/official/cards/%s.png"%id),"packed complete original PNG "+id)
 for id in ["cooking-mountain","cooking-sea","cooking-vegetable","cooking-dark","shi-cai","jia-yao"]:
  check(Content.card_def(id).unitId=="" and Content.card_def(id).get("neutralFood",false),"packed neutral derivative "+id)
 check(Content.unit_def("qianji-spear").maxHp==2 and not Content.playable_units().any(func(u):return u.id=="qianji-spear"),"packed derived spear definition")
 for id in ["qianji-spear","cat-one","cat-four","cat-two","sugar-small","sugar-big"]:
  var u:Dictionary=Content.unit_def(id)
  check(u.get("token",false) and not u.get("verificationPending",[]).is_empty(),"packed derivative pending "+id)
  check(ResourceLoader.exists("res://"+str(u.art)),"packed actual derivative art "+id)
 var gs:=GS.create(["wuwu","shiling","maozhanggui","yixigong"],["tuwan","qianji","bingyong","shantong"],20261103)
 for p in gs.players:
  p.hand.clear();p.energy=40;p.levelUpUsed=true
  for u in p.units:u.level=3
 check(gs.player(0).units.size()==4 and gs.player(1).units.size()>=4,"actual mixed six-character package match")
 Food.gain_ingredient(gs,0,0,"mountain");gs._knockout_unit(gs.player(0).units[0]);var target:Dictionary=gs.player(0).units[1];var attack:int=target.attack
 check(gs.play_card(0,0,target.uid) and target.attack==attack+3,"packed neutral source-less food actual play")
 gs.current_player=1;gs.player(1).hand.append({"definitionId":"qianji-song","instanceId":"packed-song"})
 check(gs.play_card(1,0) and gs.front_unit(1).get("rtSpear",false),"packed spear actual summon")
 gs.current_player=0;gs.player(0).hand.append({"definitionId":"c24903","instanceId":"packed-master"})
 check(gs.play_card(0,0) and gs.front_unit(0).get("scCandy",false),"packed candy actual entry")
 check(Food.gain_feast(gs,0,1).is_empty() and gs.rule_events.any(func(e):return e.kind=="food-definition-unverified"),"packed missing direct-feast pool stays explicit")
 print("COOKING_SIX_PACKAGE_CHECK ",JSON.stringify({"checks":checks,"failures":failures}));quit(1 if failures else 0)
