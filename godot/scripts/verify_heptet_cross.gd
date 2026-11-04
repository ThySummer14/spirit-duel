extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const CP := preload("res://scripts/charged_pair_rules.gd")
const Content := preload("res://scripts/content_loader.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("HEPTET_CROSS_FAIL ",detail)
func game(team: Array, enemy: Array = ["bingyong","fenghuanghuo","yaodaoji","xuenv"]) -> GS:
	var gs:=GS.create(team,enemy,271296)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	return gs
func give(gs,id: String) -> int:
	gs.player(0).hand.append({"instanceId":"heptet-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1
	return gs.player(0).hand.size()-1
func play(gs,id: String,target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actual use "+id)
func charge(gs,id: String,target = null) -> void:
	var h:=give(gs,id)
	check(CP.request_mode(gs,0,h) and gs.resolve_divination_choice(0,"charged-store"),"real charge selection "+id)
	check(CP.ready_hand(gs,0)==h and gs.play_card(0,h,target),"actual charge store "+id)
func awaken_sleeve(gs) -> void:
	play(gs,"c29608")
	for u in gs.player(1).units:u.hp=int(u.maxHp);u.knockout=0;u.shield=0
func ability_sources() -> void:
	var gs:=game(["xiaoxiuzhishou","huangchuanzhizhu","shuweng","panguan"])
	awaken_sleeve(gs)
	var e:Dictionary=gs.player(1);e.units[0].attack=20
	var before:int=e.units[0].hp;play(gs,"c27101")
	check(e.units[0].hp==before-2,"Arakawa second-card base gets exactly one sleeve bonus")
	gs=game(["xiaoxiuzhishou","huangchuanzhizhu","shuweng","panguan"]);awaken_sleeve(gs)
	var p:Dictionary=gs.player(0);e=gs.player(1);e.units[0].front=1
	var hp:int=e.units[0].hp
	gs._run_unit_hooks(0,1,"not-an-event",{})
	gs._run_passive_effect(0,1,"passive-damage-enemy-front",{"amount":1},{})
	check(e.units[0].hp==hp-2,"generic base hook gains one damage")
	hp=e.units[0].hp
	gs._run_passive_effect(0,1,"passive-damage-enemy-front",{"amount":1},{},false)
	check(e.units[0].hp==hp-1,"form hook cannot inherit base ability bonus")
	e.units[0].front=0;var av:int=e.avatarHp
	gs._run_passive_effect(0,1,"passive-damage-enemy-front-on-spell",{"amount":1},{})
	check(e.avatarHp==av-2,"generic base hook avatar damage has same bonus")
	var old_context:={"playerIndex":0,"sourceIndex":1,"cardOverride":Content.card_def("c27104"),"affectedUnits":[]}
	gs._card_effect_context=old_context;var prior:int=gs.rule_events.size()
	gs.VerifiedRules.base_damage_avatar(gs,0,1,1,1)
	check(gs._card_effect_context==old_context,"base wrapper restores surrounding spell context")
	check(gs.rule_events.slice(prior).all(func(ev):return ev.kind!="damage-resolved"),"base damage never masquerades as surrounding spell hit")
	gs._card_effect_context={}
	p.units[0].baseRulesSuppressed=true;av=e.avatarHp
	gs.VerifiedRules.base_damage_avatar(gs,0,1,1,1)
	check(e.avatarHp==av-1,"suppressed awakening cannot contribute aura")
	p.units[0].erase("baseRulesSuppressed");p.units[0].hp=0;av=e.avatarHp
	gs.VerifiedRules.base_damage_projectile(gs,0,1,1)
	check(e.avatarHp==av-1,"knocked-out sleeve cannot contribute aura")
func charge_counts() -> void:
	var gs:=game(["huangchuanzhizhu","jicanghai","wuchen","shuzhu"])
	play(gs,"c26406");var p:Dictionary=gs.player(0)
	charge(gs,"c26401")
	check(gs.VerifiedRules.Arakawa.count(gs,0)==1,"charge storage is not use for Arakawa")
	var fire:int=p.energy
	check(gs.release_charge(0,1),"actual manually selected release command")
	check(gs.VerifiedRules.Arakawa.count(gs,0)==2 and p.energy==fire,"manual release is a use but spends no extra fire")
	check(p.units[1].attack==3 and gs.player(1).avatarHp==24,"released charging aura removed; base2+awakening1 remain, printed1+double-charge2 give combat6 only")
	check(not gs.release_charge(0,1),"already released record cannot release again")
func held_stun() -> void:
	var gs:=game(["huangchuanzhizhu","wuchen","taohuayao","shuzhu"])
	var u:Dictionary=gs.player(0).units[0];var target:Dictionary=gs.player(1).units[0]
	gs.VerifiedRules.Stun.apply(gs,1,0,1,0);play(gs,"c27107",target.uid)
	gs._knockout_unit(u,1,0);gs._resolve_resolution_stack()
	check(target.frozen==1 and not target.has("movementHolders"),"devour source death preserves independently applied stun")
func run() -> void:
	ability_sources();charge_counts();held_stun()
	print("HEPTET_CROSS_VERIFY ",JSON.stringify({"checks":checks,"failures":failures}));quit(1 if failures else 0)
func _initialize() -> void:run.call_deferred()
