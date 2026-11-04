extends SceneTree
const GS := preload("res://scripts/game_state.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("GOLDFISH_VINE_WIND_FAIL ",detail)
func game(extra: String = "jinyuji") -> GS:
	var gs:=GS.create(["tengji","fengli",extra,"rulianshi"],["yaodaoji","bingyong","xuenv","baizangzhu"],227228232)
	for owner in 2:
		var p: Dictionary=gs.player(owner)
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs
func play(gs, id: String, target = null, owner: int = 0) -> void:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"goldfish-vine-wind-%d" % gs.next_card_id}); gs.next_card_id+=1
	check(gs.play_card(owner,gs.player(owner).hand.size()-1,target),"actual card "+id)
func source_count(gs) -> int:
	return gs.player(0).units.filter(func(u):return not u.get("removed",false) and not u.get("vineCharm",{}).is_empty()).size()
func substitute_and_real_death() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0)
	play(gs,"c23203"); var body: Dictionary=gs.VerifiedRules.WindRaccoon.clone(gs,0); var idx: int=gs._unit_index_by_uid(0,body.uid)
	gs.VerifiedRules.Vine.attach(gs,0,idx)
	check(source_count(gs)==1 and gs.VerifiedRules.Vine.bonus(body)>=1,"wind clone becomes sole real vine host")
	var hit: Dictionary=gs._damage_unit(0,idx,1,1,0); gs._resolve_resolution_stack()
	check(not hit.knocked and body.hp==3 and not body.removed,"self-destruction can consume real vine replacement and restore original clone health")
	check(not body.has("weaverGrave") and not gs.rule_events.any(func(e):return e.kind=="wind-raccoon-removed"),"substitute never records a phantom corpse or summon departure")
	hit=gs._damage_unit(0,idx,1,1,0); gs._resolve_resolution_stack()
	check(hit.knocked and body.removed and body.hp==0 and body.has("weaverGrave"),"next positive damage truly self-destructs and records one summon grave")
	var original_uid: String=body.uid
	play(gs,"c23603")
	check(p.units[idx].uid==original_uid and body.hp==3 and not body.get("windRaccoonRemoval",false),"powder restores original clone identity and live departure guards")
	play(gs,"c23203"); var merged: Dictionary=gs.VerifiedRules.WindRaccoon.clone(gs,0)
	check(merged.uid!=original_uid and merged.hp==6 and merged.maxHp==6,"revived clone then real summoning creates new fused identity")
	check(not body.has("vineCharm") and not merged.has("vineCharm"),"consumed replacement charm never resurrects from archived fusion body")
func shared_charm_removal() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var fish: Dictionary=p.units[2]
	play(gs,"c22701")
	check(fish.get("goldfishAttached",false),"first card attaches actual goldfish")
	gs.VerifiedRules.Vine.attach(gs,0,2)
	fish.hp=1
	gs.VerifiedRules.Moon.full_moon(gs,fish); gs._resolve_resolution_stack()
	check(not fish.has("goldfishAttached") and not fish.has("vineCharm") and fish.hp==fish.maxHp and fish.maxHp==4,"one shared cleanse removes both real charm types and heals remaining body")
	check(gs.VerifiedRules.Incarnation.config(fish,gs,0).is_empty(),"cleansed goldfish cannot retain a hidden incarnation source")
	var uid: String=p.units[1].uid; var power: int=p.units[1].attack; var deck: int=p.deck.size()
	play(gs,"c22701")
	check(fish.get("goldfishAttached",false) and p.units[1].attack==power and p.deck.size()==deck-1,"next first-level card truly replaces target buff with charm and one draw")
func old_summon_departures() -> void:
	for role in ["xuenv","xiaosongwan","huaniajuan","huiyeji","yanmo"]:
		var gs:=game(role); var p: Dictionary=gs.player(0)
		play(gs,"c22808")
		var idx: int=-1
		match role:
			"xuenv": gs.VerifiedRules.Xuenv.summon_wall(gs,0,2); idx=p.units.size()-1
			"xiaosongwan": idx=gs.VerifiedRules.Pine.summon(gs,0,2)
			"huaniajuan": idx=gs.VerifiedRules.Paint.summon_scroll(gs,0,2,0)
			"huiyeji": gs.VerifiedRules.Bamboo.summon_stone(gs,0,4); idx=p.units.size()-1
			_: idx=gs.VerifiedRules.Enma.summon_ghost(gs,0,2)
		gs.VerifiedRules.Vine.attach(gs,0,idx)
		var body: Dictionary=p.units[idx]; var charm: String=body.vineCharm.uid; var count: int=body.vineCharm.count
		check(gs.VerifiedRules.Movement.move_to(gs,0,1,1),"actual other hero replaces "+role)
		gs._resolve_resolution_stack()
		check(body.get("removed",false) and body.hp==0 and not body.has("vineCharm"),"old summon departure really removes physical charm: "+role)
		check(p.units[0].get("vineCharm",{}).get("uid")==charm and gs.VerifiedRules.Vine.bonus(p.units[0])==count and source_count(gs)==1,"millennium returns same physical charm once: "+role)
func fused_charm_identity() -> void:
	var gs:=game("yanmo"); var p: Dictionary=gs.player(0)
	var idx: int=gs.VerifiedRules.Enma.summon_ghost(gs,0,2); var first: Dictionary=p.units[idx]
	gs.VerifiedRules.Vine.attach(gs,0,idx); var charm: String=first.vineCharm.uid; var count: int=first.vineCharm.count
	idx=gs.VerifiedRules.Enma.summon_ghost(gs,0,2); var second: Dictionary=p.units[idx]
	check(second.get("vineCharm",{}).get("uid")==charm and not first.has("vineCharm") and source_count(gs)==1,"enma fusion transfers one real charm to new identity without tombstone copy")
	check(gs.VerifiedRules.Vine.bonus(second)==count,"enma fusion does not increase inherited charm fusion count")
	gs=game(); p=gs.player(0); play(gs,"c23602"); idx=gs.VerifiedRules.Weaver.live_snow(gs,0); first=p.units[idx]
	gs.VerifiedRules.Vine.attach(gs,0,idx); charm=first.vineCharm.uid
	play(gs,"c23602"); second=p.units[gs.VerifiedRules.Weaver.live_snow(gs,0)]
	check(second.get("vineCharm",{}).get("uid")==charm and not first.has("vineCharm") and not first.weaverGrave.has("vineCharm"),"snow fusion archive cannot revive a duplicate physical charm")
func _initialize() -> void:
	substitute_and_real_death(); shared_charm_removal(); old_summon_departures(); fused_charm_identity()
	print("GOLDFISH_VINE_WIND checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
