extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("SWORD_HOUSE_TRIO_FAIL ",detail)
func game(ghost: bool = true) -> GS:
	var lineup: Array=["guiqie","dayueling","tianjingxia","rulianshi"] if ghost else ["dayueling","tianjingxia","yanmo","rulianshi"]
	var gs:=GS.create(lineup,["fenghuanghuo","bingyong","duyanxiaoseng","baizangzhu"],168190191)
	while not gs.pending_choice.is_empty():
		if not AI._resolve_choice(gs,gs.action_player()):break
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.VerifiedRules.Onikiri.remove_charms(gs.player(0).units[0]); gs.rule_events.clear()
	return gs
func give(gs,id: String,owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"sword-house-%d"%gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs,id: String,target = null,owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)
func response_kill(replacement: bool) -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var oni: Dictionary=p.units[0]
	play(gs,"c16805");play(gs,"c19007",oni.uid)
	oni.front=1;gs.VerifiedRules.Onikiri.attach(gs,0,0,"onikiri-tomo");give(gs,"c19105")
	check(gs.end_turn(0),"actual enemy turn starts")
	foe.levelUpUsed=true;foe.energy=80;foe.units[0].hp=3
	if replacement:gs.VerifiedRules.Vine.attach(gs,1,0)
	gs.VerifiedRules.ArmorBreak.give(gs,0,2,1,0,1,false)
	var hp: int=p.units[3].hp;var enemy_hp: int=foe.avatarHp
	play(gs,"c12404",p.units[3].uid,1)
	if replacement:
		check(foe.units[0].hp>0 and p.units[3].hp<hp,"vine replacement denies counter kill and original spell still damages target")
		check(int(p.get("otakeJadeGrowth",0))==0 and foe.avatarHp==enemy_hp,"substitute never grows jade or triggers house shatter")
		check(not gs.rule_events.any(func(e):return e.kind=="onikiri-spell-countered"),"no whole-card counter for a prevented kill")
	else:
		check(foe.units[0].hp==0 and p.units[3].hp==hp,"real rocheng kill counters whole spell after suspended ghost attack")
		check(int(p.get("otakeJadeGrowth",0))==1 and oni.attack==4,"real jade carrier kill grows one owner-bound permanent effect")
		check(foe.avatarHp==enemy_hp-3,"house reads pre-consumption armor break and fires one real3 damage")
		check(gs.rule_events.filter(func(e):return e.kind=="onikiri-spell-countered").size()==1,"exactly one original resolution is countered")
func armor_and_cover() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
	play(gs,"c16802");play(gs,"c19002",u.uid)
	gs._grant_unit_armor(u,2)
	check(u.shield==3,"joy amplifies actual armor grant once")
	play(gs,"nuoyi",p.units[3].uid)
	check(not u.get("otakeJades",{}).has("0") and u.get("otakeCover",false),"jade transfer leaves independent next-hit immunity at original target")
	var hp: int=u.hp;var hit: Dictionary=gs._damage_unit(0,0,5,1,0)
	check(hit.damage==0 and u.hp==hp and u.shield==3 and not u.get("otakeCover",false),"cover consumes before real armor without following moved jade")
	gs.VerifiedRules.ArmorBreak.give(gs,1,0,0,0,2,false)
	check(u.shield==1 and u.armorBreak==0,"enemy break cancels actual boosted armor without phantom status")
func summon_and_physical_jade() -> void:
	var gs:=game(false);var p: Dictionary=gs.player(0)
	gs._grant_unit_armor(p.units[2],4);play(gs,"c16804",p.units[2].uid)
	var idx: int=p.units.size()-1;var house: Dictionary=p.units[idx]
	check(house.get("houseSummon",false) and house.hp==4 and house.attack==4,"wake creates real body from paid armor")
	play(gs,"c19002",house.uid);var jade: String=house.otakeJades["0"].uid
	gs._knockout_unit(house,1,0);gs._resolve_resolution_stack()
	check(house.removed and not house.has("otakeJades") and not house.get("otakeCover",false),"house true death removes jade and independent cover")
	check(house.has("weaverGrave") and not house.weaverGrave.has("otakeJades"),"summon grave cannot restore a second physical jade")
	play(gs,"c23603")
	check(house.hp==4 and house.front==1 and not house.removed and p.units[idx].uid==house.uid,"powder revives original house uid and stable index")
	check(gs.VerifiedRules.Otakemaru.owned(gs,0).is_empty(),"revived house does not invent expired jade")
	play(gs,"nuoyi",house.uid)
	check(house.attack==5 and house.otakeJades["0"].uid!=jade,"new transfer actually creates its own current jade attachment")
	play(gs,"c23602")
	check(house.removed and not house.has("otakeJades") and gs.VerifiedRules.Otakemaru.owned(gs,0).is_empty(),"snow entry removes original house and its jade before new body")
func foreign_charm_cleanse() -> void:
	var gs:=game();var foe: Dictionary=gs.player(1);var u: Dictionary=foe.units[0]
	play(gs,"c19004",u.uid)
	check(u.frozen>0 and gs.VerifiedRules.Otakemaru.continuously_stunned(u),"prison has real persistent stun and foreign owned charm")
	var candidates: Array=gs.VerifiedRules.PipeFox.candidates(gs,1)
	check(candidates.any(func(c):return c.key=="otakeJades" and c.jadeOwner==0),"native enemy-charm cleanse includes only foreign jade")
	gs.VerifiedRules.PipeFox.cleanse(gs,1,3)
	check(not u.has("otakeJades") and u.frozen==0,"native whitefox cleanse removes prison jade and its own continuous stun")
func _initialize() -> void:
	response_kill(false);response_kill(true);armor_and_cover();summon_and_physical_jade();foreign_charm_cleanse()
	print("SWORD_HOUSE_TRIO checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
