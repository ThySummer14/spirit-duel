extends SceneTree
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
var checks:=0
var failures:=0
func check(ok:bool,detail:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("COMPLETION_AI_FAIL ",detail)
func _initialize()->void:
 for role in [609,256,263]:
  for n in range(1,9):
   var gs:=GS.create(["shifagui","jinnaluo","lingyanji","bingyong"],["shantong","bailang","hetong","yaodaoji"],role*100+n)
   for side in gs.players:
    side.hand.clear();side.energy=40;side.levelUpUsed=true
    for u in side.units:u.level=3
   gs.player(0).night=10
   var id:="c%d%02d"%[role,n]
   gs.player(0).hand.append({"definitionId":id,"instanceId":"completion-ai-"+id})
   var best:Dictionary=AI._best_card(gs,0)
   check(best.ok and best.card_id==id and gs.can_play_card(0,int(best.hand),best.target,bool(best.get("origin",false))).ok,"AI actual candidate and legal chosen target "+id)
   check(AI.take_action(gs,0) and gs.command_log.any(func(c):return c.c=="play_card" and c.a.get("card","")==id),"AI actually executes requested card "+id)
   var safety:=0
   while (not gs.pending_choice.is_empty() or not gs.response_window.is_empty()) and safety<20:
    safety+=1
    if not AI.take_action(gs,gs.action_player()):break
   check(gs.pending_choice.is_empty() and gs.response_window.is_empty() and gs.resolution_stack.is_empty(),"AI drains follow-up choice/response "+id)
 print("COMPLETION_AI checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
