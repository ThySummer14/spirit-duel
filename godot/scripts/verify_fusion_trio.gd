extends SceneTree
const GS := preload("res://scripts/game_state.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FUSION_TRIO_FAIL ",detail)
func game(extra: String = "huiyeji") -> GS:
	var gs:=GS.create(["yanmo","rulianshi","kuileishi",extra],["yaodaoji","bingyong","xuenv","huaniajuan"],230231236)
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs
func play(gs, id: String, target = null, owner: int = 0) -> void:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"fusion-trio-%d" % gs.next_card_id}); gs.next_card_id+=1
	check(gs.play_card(owner,gs.player(owner).hand.size()-1,target),"actual card "+id)
func snow(gs) -> Dictionary:
	var i: int=gs.VerifiedRules.Weaver.live_snow(gs,0)
	return {} if i<0 else gs.player(0).units[i]
func mirror_bodies() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0)
	play(gs,"c23003"); play(gs,"c23602"); var first:=snow(gs)
	check(first.attack==4 and first.maxHp==4 and first.hp==4,"new snow receives one continuous mirror aura before entry")
	play(gs,"c23602"); var fused:=snow(gs)
	check(fused.attack==7 and fused.hp==7 and fused.maxHp==7,"snow fusion merges bodies without copying realm aura twice")
	var idx: int=gs._unit_index_by_uid(0,fused.uid); gs._damage_unit(0,idx,1,1,0)
	gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"专项真实消灭"); gs._resolve_resolution_stack()
	check(fused.attack==6 and fused.maxHp==6 and fused.hp==6,"destroy mirror removes continuous stats and caps wounded currentHP")
	check(first.removed and first.weaverReviveReason=="fusion","fusion grave differs from current live body")
	for kind in ["xiaosongwan","huaniajuan","xuenv","huiyeji"]:
		gs=game(kind); p=gs.player(0); play(gs,"c23003")
		var body: Dictionary
		match kind:
			"xiaosongwan": body=p.units[gs.VerifiedRules.Pine.summon(gs,0,3)]
			"huaniajuan": body=p.units[gs.VerifiedRules.Paint.summon_scroll(gs,0,3,0)]
			"xuenv": gs.VerifiedRules.Xuenv.summon_wall(gs,0,3); body=p.units[-1]
			_: gs.VerifiedRules.Bamboo.summon_stone(gs,0,2); body=p.units[-1]
		check(body.attack==int(body.baseAttack)+1 and body.maxHp==int(body.baseMaxHp)+1 and body.hp==body.maxHp,"all original summon entries receive mirror: "+kind)
func departure_and_death() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0)
	play(gs,"c23008"); play(gs,"c23602"); var old_snow:=snow(gs)
	check(gs.basic_attack(0,0),"actual enma paid ordinary attack")
	var ghost: Dictionary=gs.VerifiedRules.Enma.ghost(gs,0)
	check(old_snow.removed and not old_snow.has("weaverGrave"),"ghost replaces snow by removal without fake revival candidate")
	check(not ghost.is_empty() and p.units[0].front==0,"replacement leaves enma in reserve and attacks with real ghost")
	var strength: int=p.units[0].attack
	play(gs,"c23602")
	check(ghost.removed and not ghost.has("weaverGrave") and p.units[0].attack==strength,"snow replaces ghost without death/lord reward")
	p.attackUsed=false; check(gs.basic_attack(0,0),"second actual ghost replacement")
	ghost=gs.VerifiedRules.Enma.ghost(gs,0); var power: int=ghost.attack; var ghost_idx: int=gs._unit_index_by_uid(0,ghost.uid)
	gs._knockout_unit(ghost); gs._resolve_resolution_stack()
	check(p.units[0].attack==strength+int(power/2) and p.units[ghost_idx].has("weaverGrave"),"real ghost death creates one archive and half-power lord reward")
	var original_uid: String=ghost.uid
	play(gs,"c23603")
	check(p.units[ghost_idx].uid==original_uid and not p.units[ghost_idx].removed and p.units[ghost_idx].hp>0,"powder revives real same-index ghost without fabricating hero")
	check(gs.VerifiedRules.Weaver.revive_candidates(gs,0).is_empty(),"revived archive cannot be used repeatedly")
func stable_summon_indices() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0)
	gs.VerifiedRules.Bamboo.summon_stone(gs,0,4)
	var stone: Dictionary=p.units[-1]; var idx: int=p.units.size()-1; var uid: String=stone.uid
	gs._knockout_unit(stone); gs._resolve_resolution_stack(); gs.VerifiedRules.Bamboo.remove_departed(gs)
	check(p.units.size()==idx+1 and p.units[idx].uid==uid and stone.removed,"stone true death keeps queued indices and archive tombstone")
	play(gs,"c23603")
	check(p.units[idx].uid==uid and p.units[idx].hp==5 and p.units[idx].front==1,"powder revives original stone with full real health")
	check(not gs.can_basic_attack(0,idx).get("reason","").contains("织雪"),"snow entry-only restriction never leaks to other revived summon kinds")
	gs=game(); p=gs.player(0); gs.VerifiedRules.Bamboo.summon_stone(gs,0,4); stone=p.units[-1]; idx=p.units.size()-1
	play(gs,"c23602")
	check(p.units[idx].uid==stone.uid and stone.removed and not stone.has("weaverGrave"),"forced departure keeps stable stone index without fake death candidate")
func _initialize() -> void:
	mirror_bodies(); departure_and_death(); stable_summon_indices()
	print("FUSION_TRIO checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
