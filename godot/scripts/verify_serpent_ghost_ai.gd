extends "res://scripts/verify_serpent_ghost.gd"

func run() -> void:
	var stores:=Support.isolate_stores()
	for unit_id in ["guishiheibai","bayiqidashe"]:
		for card in Content.cards_for_unit(unit_id):
			if card.get("token",false):continue
			var gs:=game();var p:Dictionary=gs.player(0);var id:String=card.id
			p.units[0].charge=4
			if id=="c19402":SG.switch_ghost(gs,0,0,true)
			if unit_id=="bayiqidashe":
				gs._knockout_unit(p.units[2],1,0);gs._resolve_resolution_stack()
			for foe in gs.player(1).units:tough(foe,60,0)
			give(gs,id)
			var best:Dictionary=AI._best_card(gs,0)
			check(best.ok and best.card_id==id and gs.can_play_card(0,int(best.hand),best.target,best.get("origin",false)).ok,"AI real legal candidate and target "+id)
			gs.command_log.clear()
			check(AI.take_action(gs,0),"AI takes actual action "+id)
			check(gs.command_log.any(func(c):return c.c=="play_card" and c.a.get("card","")==id and c.a.get("target")==best.target),"AI executes chosen card and target "+id)
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("SERPENT_GHOST_AI checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
