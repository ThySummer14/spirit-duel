extends SceneTree
const GS := preload("res://scripts/game_state.gd")
var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("NIGHT_TRIO_FAIL ",detail)

func game(ghost: bool = false) -> GS:
	var gs:=GS.create(["rurineque","wushizhiling" if ghost else "shouwu","yecha","gunvhongye"],["rurineque","yecha","xingxiongtongzi","duyanxiaoseng"],257260262)
	for owner in 2:
		var p: Dictionary=gs.player(owner)
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.night=0; p.realms.clear()
		for u in p.units:
			u.level=3
			u.yakshaStrengthTurn=-1
	gs.rule_events.clear()
	return gs

func play(gs, id: String, target = null, owner: int = 0) -> void:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"night-trio-%d" % gs.next_card_id}); gs.next_card_id+=1
	check(gs.play_card(owner,gs.player(owner).hand.size()-1,target),"actual card "+id)

func kinds(gs) -> Array:
	return gs.rule_events.filter(func(e):return e.kind in ["night-triggered","yaksha-night-strength"]).map(func(e):return str(e.kind)+str(e.get("threshold","")))

func night_order() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[2]
	var power: int=u.attack
	gs.VerifiedRules.Maple.gain_night(gs,0,1); gs._resolve_resolution_stack()
	check(p.night==1 and u.attack==power,"direct resource gain is not an entry effect")
	check(not gs.VerifiedRules.Maple.nightfall(gs,0,3),"failed threshold reports failure")
	gs._resolve_resolution_stack()
	check(p.night==2 and u.attack==power+1,"failed entry gains resource and triggers yaksha")
	p.night=3
	check(gs.VerifiedRules.Maple.nightfall(gs,0,3),"successful threshold reports success")
	gs._resolve_resolution_stack()
	check(p.night==3 and u.attack==power+1,"successful entry does not spend resource or repeat basic quota")
	play(gs,"c26204"); play(gs,"c25706"); p.night=7
	var before: int=u.attack; var sparrow: Dictionary=p.units[0]; var growth: int=sparrow.get("sparrowPermanentHp",0)
	gs.rule_events.clear(); gs.VerifiedRules.Sparrow.turn_start(gs,0); gs._resolve_resolution_stack()
	check(kinds(gs)==["night-triggered3","yaksha-night-strength","night-triggered7","yaksha-night-strength"],"awakened sparrow stages each effect and yaksha before next entry")
	check(u.attack==before+2 and sparrow.get("sparrowPermanentHp",0)==growth+1 and sparrow.shield>=2,"both successful entry effects and separate yaksha growth resolve")

func substitute_and_death() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var enemy: Dictionary=gs.player(1)
	gs.current_player=1; play(gs,"c26203",null,1); gs.current_player=0
	p.night=5; play(gs,"c25707")
	var hp: int=enemy.avatarHp; var hand_count: int=enemy.hand.size()
	var hit: Dictionary=gs.VerifiedRules.Combat.strike(gs,1,1,0,0,99,{"yakshaKillEffect":"draw"})
	gs._resolve_resolution_stack()
	check(not hit.knocked and p.units[0].hp==6,"substitute restores body and is not a combat kill")
	check(enemy.night==0 and enemy.hand.size()==hand_count and enemy.avatarHp==hp,"substitute cannot trigger sea entry or kill draw reward")
	check(not gs.rule_events.any(func(e):return e.kind=="yaksha-sea-extended" or e.kind=="yaksha-kill-reward"),"substitute produces no phantom death reward events")
	enemy.night=7; var power: int=enemy.units[1].attack
	hit=gs.VerifiedRules.Combat.strike(gs,1,1,0,0,99,{"yakshaKillEffect":"draw"}); gs._resolve_resolution_stack()
	check(hit.knocked and p.units[0].hp==0 and p.units[0].knockout==3,"real knockout triggers sea extension once")
	check(enemy.hand.size()==hand_count+2 and enemy.units[1].attack==power+1,"real kill draws two and basic yaksha shares one quota across entries")

func revival() -> void:
	var gs:=game(true); var p: Dictionary=gs.player(0)
	play(gs,"c19308")
	gs._knockout_unit(p.units[2]); gs._resolve_resolution_stack()
	p.night=10; var power: int=p.units[2].attack
	play(gs,"c25708")
	check(p.units[1].hp==0 and p.units[1].samuraiCannotRevive,"nest cannot revive permanently knocked-out ghost")
	check(p.units[2].hp==p.units[2].maxHp and p.units[2].attack==power+1,"nest revives valid yaksha before entry and strength trigger")
	check(p.realms.any(func(r):return r.nativeRealm=="sparrow-nest"),"actual nest remains in realm zone")

func response_power() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var enemy: Dictionary=gs.player(1)
	gs.current_player=1; play(gs,"c25704",null,1); gs.current_player=0
	gs.VerifiedRules.Movement.move_to(gs,1,0,1); gs._resolve_resolution_stack(); enemy.night=5
	play(gs,"c26003")
	check(enemy.units[0].hp==7 and enemy.avatarHp==30,"court reduction makes this actual split attack zero with no echo")
	check(p.units[1].hp==1 and p.units[1].attack==1,"counterhit consumes actual unyielding while court power remains this turn")
	check(gs.end_turn(0),"actual turn completes")
	check(p.units[1].attack==3 and not p.units[1].has("sparrowCourtPenalty"),"court removes only its penalty at turn boundary")

func entry_child_effects() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[2]
	gs.current_player=1; play(gs,"c25108",u.uid,1); gs.current_player=0
	u.hp=1; var power: int=u.attack
	gs.rule_events.clear()
	check(not gs.VerifiedRules.Maple.nightfall(gs,0,3),"failed entry creates real resource-triggered maple projectile")
	gs._resolve_resolution_stack()
	check(u.hp==0 and u.attack==power and u.yakshaStrengthTurn==-1,"entry child damage resolves before yaksha life and quota check")
	check(not gs.rule_events.any(func(e):return e.kind=="yaksha-night-strength"),"death inside entry effect cannot leave a phantom strength event")

func _initialize() -> void:
	night_order(); substitute_and_death(); revival(); response_power(); entry_child_effects()
	print("NIGHT_TRIO checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
