extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FOX_GLUTTON_DOLL_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["sanweihu","egui","choushizhinv","rulianshi"],["bingyong","fenghuanghuo","rurineque","tengji"],217258272)
	for p in gs.players:
		p.hand.clear();p.energy=80;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear()
	return gs
func give(gs,id: String,owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"fox-glutton-doll-%d"%gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs,id: String,target = null,owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)
	while not gs.pending_choice.is_empty():
		if not AI._resolve_choice(gs,gs.action_player()):break
func doll(gs) -> Dictionary:
	for u in gs.player(0).units:
		if u.get("dollSummon",false) and int(u.hp)>0 and not u.get("removed",false):return u
	return {}
func first_card_and_nullify() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1)
	p.energy=0; p.nullifyNextCardTurn=gs.turn_counter
	var hp: int=foe.units[0].hp
	play(gs,"c27201",foe.units[0].uid)
	check(foe.units[0].hp==hp,"first real card is nullified as a whole")
	check(not gs.VerifiedRules.ThreeTail.free_first(gs,0),"countering never refunds first-card privilege")
	var i:=give(gs,"c25801");check(not gs.can_play_card(0,i,foe.units[0].uid).ok,"second noninstant card still needs actual fire")
	p.energy=10;play(gs,"c25801",foe.units[0].uid)
	check(p.energy==9,"unrelated shikigami pays normal cost after first card")
	check(not doll(gs).is_empty(),"paid unrelated summon remains actual summon")
func bindings_and_true_knockout() -> void:
	var gs:=game();var foe: Dictionary=gs.player(1);var target: Dictionary=foe.units[0]
	play(gs,"c25801",target.uid);var body:=doll(gs)
	check(not body.is_empty(),"doll physically exists at stable index")
	var idx: int=gs._unit_index_by_uid(0,body.uid)
	play(gs,"c25802",body.uid)
	check(target.frozen>0,"actual thorn damage triggers bound enemy stun")
	var count: int=gs.player(0).units.size()
	gs._knockout_unit(target,0,1);gs._resolve_resolution_stack()
	check(target.hp==0,"bound enemy truly knocked out")
	gs.VerifiedRules.Peach.revive(gs,1,0,target,false,false)
	target.frozen=0;gs._damage_unit(0,idx,1,1,1);gs._resolve_resolution_stack()
	check(target.hp>0 and target.frozen==0,"real revival never restores an expired physical binding")
	check(gs.player(0).units.size()==count and gs.player(0).units[idx].uid==body.uid,"binding cleanup never shifts summon indexes")
func doll_replacement_and_powder() -> void:
	var gs:=game();var target: Dictionary=gs.player(1).units[0]
	play(gs,"c25801",target.uid);var old:=doll(gs);var old_idx: int=gs._unit_index_by_uid(0,old.uid)
	play(gs,"c25806",target.uid);var current:=doll(gs)
	check(old.removed and int(old.hp)==0 and current.uid!=old.uid,"summoning another doll really removes first body")
	check(not old.has("weaverGrave"),"removal does not produce a false powder grave")
	var idx: int=gs._unit_index_by_uid(0,current.uid)
	gs._knockout_unit(current,1,1);gs._resolve_resolution_stack()
	check(current.hp==0 and current.get("removed",false) and current.has("weaverGrave"),"actual doll knockout records true summon grave")
	play(gs,"c23603")
	check(current.hp>0 and not current.removed and int(current.front)==1,"powder actually revives original doll")
	check(gs.player(0).units[idx].uid==current.uid and gs.player(0).units[old_idx].uid==old.uid,"revival keeps all physical indexes and identities")
func permanent_body_and_substitute() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1)
	var u: Dictionary=foe.units[2];var base_attack: int=u.attack;var base_hp: int=u.maxHp
	gs._awaken(1,2,gs.ContentLoader.card_def("c25706"),{"attack":1,"hp":1})
	gs._grow_unit(u,3,2)
	check(gs.VerifiedRules.Glutton.permanent_stats(u)=={"attack":1,"hp":1},"ledger separates real awakening white stats from ordinary modifiers")
	play(gs,"c21708",u.uid)
	check(u.awakened and u.attack==base_attack+3 and u.maxHp==base_hp+2,"draining white stats preserves awakening ability and ordinary growth")
	var eater: Dictionary=p.units[1]
	check(gs.VerifiedRules.Glutton.permanent_stats(eater)=={"attack":2,"hp":2},"own awakening and actually stolen white growth both remain permanent")
	check(gs.VerifiedRules.Glutton.satiated(eater),"removing real permanent enhancement attaches real satiation")
	var attack: int=eater.attack;gs.VerifiedRules.Moon.full_moon(gs,eater)
	check(eater.attack==attack-2 and not gs.VerifiedRules.Glutton.satiated(eater),"full moon removes physical satiation without taking permanent body growth")
	check(gs.end_turn(0),"advance to target owner for actual substitute form")
	foe.levelUpUsed=true;foe.energy=80;play(gs,"c25707",null,1)
	gs._knockout_unit(u,0,1);gs._resolve_resolution_stack()
	check(u.hp>0 and u.knockout==0,"real substitute still avoids knockout after its white stats were eaten")
	check(u.attack==base_attack and u.maxHp==base_hp,"substitute cannot reconstruct previously removed awakening values")
	gs._knockout_unit(eater,1,0);gs._resolve_resolution_stack()
	check(eater.hp==0 and gs.VerifiedRules.Glutton.permanent_stats(eater)=={"attack":2,"hp":2},"actual knockout retains both exact permanent growth sources")
	gs.VerifiedRules.Peach.revive(gs,0,1,eater,false,false)
	check(eater.hp==eater.maxHp and eater.attack==int(eater.baseAttack)+2,"revival restores permanent body and never invents expired satiation")
func _initialize() -> void:
	first_card_and_nullify();bindings_and_true_knockout();doll_replacement_and_powder();permanent_body_and_substitute()
	print("FOX_GLUTTON_DOLL checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
