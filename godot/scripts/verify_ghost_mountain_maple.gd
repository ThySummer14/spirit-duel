extends SceneTree
const GS := preload("res://scripts/game_state.gd")
var checks:=0
var failures:=0

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("GHOST_MOUNTAIN_MAPLE_FAIL ",detail)

func give(gs, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"cross-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1

func _initialize() -> void:
	var gs:=GS.create(["bujianyue","wushizhiling","gunvhongye","taohuayao"],["gunvhongye","bingyong","yaodaoji","baizangzhu"],193280259)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	var p: Dictionary=gs.player(0); var ghost: Dictionary=p.units[1]
	gs.VerifiedRules.Maple.attach(gs,1,0,ghost)
	gs._knockout_unit(ghost); gs._resolve_resolution_stack()
	check(ghost.hp==0 and gs.VerifiedRules.Samurai.ghost(ghost) and not gs.VerifiedRules.Maple.marked(ghost),"real knockout clears doll before becoming actual0HP ghost")
	check(gs.play_card(0,give(gs,0,"c28002")),"deploy actual mountain color")
	gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"cross-role verification"); gs._resolve_resolution_stack()
	check(ghost.hp==ghost.maxHp and not gs.VerifiedRules.Samurai.ghost(ghost),"mountain revival restores mortal body and clears ghost identity")
	check(gs.play_card(0,give(gs,0,"c19308")) and ghost.hp==0 and ghost.samuraiCannotRevive,"actual samurai awakening makes ghost unrevivable")
	gs._knockout_unit(p.units[3]); ghost.knockout=20
	check(gs.play_card(0,give(gs,0,"c28002")),"second actual mountain color")
	gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"cross-role verification"); gs._resolve_resolution_stack()
	check(ghost.hp==0 and p.units[3].hp==p.units[3].maxHp,"largest countdown does not bypass awakened ghost ban; valid next target revives")
	# Ordinary shikigami use the same hostile charm cleanup.
	var body: Dictionary=p.units[2]
	gs.VerifiedRules.Maple.attach(gs,1,0,body); gs._knockout_unit(body)
	check(not gs.VerifiedRules.Maple.marked(body),"shared knockout clears real enemy doll on ordinary shikigami")
	check(gs.VerifiedRules.Maple.gain_night(gs,0,1)==1 and int(p.night)==1,"dead maple source still preserves actual player night resource")
	gs._resolve_resolution_stack()
	check(not gs.rule_events.any(func(e):return e.kind=="maple-projectile"),"dead maple source does not gain a false night projectile")
	print("GHOST_MOUNTAIN_MAPLE checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
