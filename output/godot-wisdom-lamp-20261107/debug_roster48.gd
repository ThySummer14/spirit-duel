extends SceneTree
const GS:=preload("res://scripts/game_state.gd")
const Content:=preload("res://scripts/content_loader.gd")
func _initialize()->void:
 var ids:Array=Content.playable_units().map(func(u):return u.id)
 var ally:Array=[]
 for i in 4:ally.append(ids[(48+i)%ids.size()])
 var gs=GS.create(ally,Content.opponent_lineup(ally,20261005+48),20261005+48)
 print("LINEUP ",ally)
 print("UNITS ",gs.player(0).units.size()," ",gs.player(0).units.map(func(u):return u.id))
 var initial_ids:={}
 for instance in gs.player(0).deck+gs.player(0).hand:
  if str(instance.instanceId).begins_with("player-c"):initial_ids[instance.instanceId]=true
 print("INITIAL_IDS ",initial_ids.size()," deck=",gs.player(0).deck.size()," hand=",gs.player(0).hand.size())
 quit(0)