extends SceneTree
const GS:=preload("res://scripts/game_state.gd")
const AI:=preload("res://scripts/game_ai.gd")
const Content:=preload("res://scripts/content_loader.gd")
var gs
func scan(tag:String)->bool:
 for side in 2:
  for i in gs.player(side).units.size():
   var u=gs.player(side).units[i]
   if not u is Dictionary:
    print("CORRUPT after ",tag," side=",side," idx=",i," value=",u)
    return true
 return false
func _initialize()->void:
 var ids:Array=Content.playable_units().map(func(u):return u.id)
 var ally:Array=[]
 for i in 4:ally.append(ids[(176+i)%ids.size()])
 gs=GS.create(ally,Content.opponent_lineup(ally,20261005+176),20261005+176)
 var steps:=0
 while gs.winner<0 and steps<2000:
  var p_idx:int=gs.action_player()
  if not gs.pending_choice.is_empty():
   if AI._resolve_choice(gs,p_idx):
    if scan("choice"):quit(1);return
    continue
   break
  if not gs.response_window.is_empty():
   if AI._try_response(gs,p_idx,[]):
    if scan("response"):quit(1);return
    continue
   if gs.pass_response(p_idx):continue
   break
  if gs.is_upgrade_pending(p_idx):
   var uidx:int=AI._best_level_up(gs,p_idx)
   if uidx>=0 and gs.level_up(p_idx,uidx):
    if scan("level_up"):quit(1);return
    continue
   break
  var released:=false
  for idx in gs.player(p_idx).units.size():
   if gs.VerifiedRules.Zhenjian.can_manual_release(gs,p_idx,idx) and gs.release_charge(p_idx,idx):
    released=true;break
  if released:
   if scan("release"):quit(1);return
   continue
  var play:Dictionary=AI._best_card(gs,p_idx)
  if play.ok:
   if gs.play_card(p_idx,play.hand,play.target,bool(play.get("origin",false))):
    if scan("play_card "+str(play.card_id)+" target="+str(play.target)):quit(1);return
    continue
  var atk:Dictionary=AI._best_attack(gs,p_idx)
  if atk.ok:
   if gs.basic_attack(p_idx,atk.unit,atk.target):
    if scan("basic_attack"):quit(1);return
    continue
  if gs.action_player()==p_idx and gs.pending_choice.is_empty() and gs.response_window.is_empty():
   if gs.end_turn(p_idx):
    if scan("end_turn"):quit(1);return
  steps+=1
 print("NO_CORRUPTION winner=",gs.winner," steps=",steps)
 quit(0)