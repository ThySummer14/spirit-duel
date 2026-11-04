extends SceneTree
const GS := preload("res://scripts/game_state.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("ABILITY_SOURCES_FAIL ",detail)
func game(uid: String, aura: bool) -> GS:
	var gs := GS.create([uid,"xiaoxiuzhishou","taohuayao","yimulian"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],29630)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.avatarHp=100; p.maxAvatarHp=100
		for u in p.units: u.level=3; u.shield=0; u.shieldExpires=0; u.front=0; u.hp=int(u.maxHp)
	gs.player(0).units[1].awakened=true
	gs.player(0).units[1].baseRulesSuppressed=not aura
	for u in gs.player(1).units: u.baseMaxHp=100;u.maxHp=100;u.hp=100
	gs.rule_events.clear();return gs
func life(gs) -> int:
	var hp := int(gs.player(1).avatarHp)
	for u in gs.player(1).units: hp+=int(u.hp)
	return hp
func loss(uid: String, aura: bool, callback: Callable) -> int:
	var gs:=game(uid,aura);var hp:=life(gs)
	callback.call(gs);gs._resolve_resolution_stack()
	check(gs.winner<0 and gs.pending_choice.is_empty() and gs.response_window.is_empty(),uid+" ability completes without unrelated choice")
	return hp-life(gs)
func compare(uid: String, callback: Callable, expected: int, difference: int=1) -> void:
	var ordinary:=loss(uid,false,callback);var enhanced:=loss(uid,true,callback)
	check(ordinary==expected,uid+" retains printed baseline "+str(expected)+" got "+str(ordinary))
	check(enhanced==ordinary+difference,uid+" receives exactly "+str(difference)+" base ability bonus got "+str(enhanced))
func run() -> void:
	compare("bailang",func(gs):gs.VerifiedRules.Bailang.damage_dealt(gs,0,0,1,1,true),2)
	compare("shuweng",func(gs):
		gs.player(0).bookEmptyDraw=true;gs.player(0).bookEmptyDrawSource=gs.player(0).units[0].uid
		gs.player(0).deck.clear();gs._draw(0,1),10)
	compare("yaohu",func(gs):
		gs.player(0).units[0].awakened=true;gs.VerifiedRules.FoxSuzuka.fortune_success(gs,0),2)
	compare("yatiangou",func(gs):gs.VerifiedRules.Movement.move_to(gs,0,0,1),1)
	compare("baimugui",func(gs):gs.VerifiedRules.Eye.divined(gs,0,2),1)
	compare("duyanxiaoseng",func(gs):
		gs.player(1).units[0].front=1;gs._damage_unit(0,0,1,1,0,true),2)
	compare("guanhu",func(gs):
		gs.player(1).units[0].front=1;gs.VerifiedRules.PipeFox.countdown(gs,0,0,"front",true),2)
	compare("yuzaoqian",func(gs):
		gs.resolution_stack.append({"kind":"card-complete","resolutionId":29630})
		gs.VerifiedRules.FoxLotus.announced(gs,{"playerIndex":0,"sourceIndex":0,"automatic":true,"resolutionId":29630},{"type":"combat"})
		gs.resolution_stack=gs.resolution_stack.filter(func(f):return f.get("kind")!="card-complete"),2)
	compare("gunvhongye",func(gs):gs.VerifiedRules.Maple.gain_night(gs,0,1),1)
	compare("biyehua",func(gs):gs._damage_avatar(0,1,0,0),1)
	compare("xunxiangxing",func(gs):gs.VerifiedRules.KoiFragrance.charmed(gs,0,1,{"definitionId":"c12401"},"etch"),1)
	compare("yujuchong",func(gs):
		gs.player(1).units[0].toxicPoisoned=true;gs._knockout_unit(gs.player(1).units[0],0,2),101)
	compare("linghaidie",func(gs):
		gs.player(0).units[0].awakened=true
		gs.VerifiedRules.SeaButterfly.attach(gs,0,0,gs.player(0).units[0]);gs.VerifiedRules.SeaButterfly.attach(gs,0,0,gs.player(0).units[0]),2)
	compare("gulonghuo",func(gs):gs._knockout_unit(gs.player(0).units[0],1,0),2)
	compare("panguan",func(gs):gs.VerifiedRules.Panguan.destroy(gs,0,0,1,0),101)
	compare("yaoginshi",func(gs):gs.VerifiedRules.Countdown.queue_ability(gs,0,0,"battle"),5,5)
	compare("huangchuanzhizhu",func(gs):gs._run_passive_effect(0,0,"passive-damage-enemy-front-on-spell",{"amount":1},{}),1)
	compare("huangchuanzhizhu",func(gs):gs._run_passive_effect(0,0,"passive-damage-enemy-front-on-spell",{"amount":1},{},false),1,0)
	# These damage paths are cards, forms or charms, so the base-only aura stays out.
	compare("yaohu",func(gs):gs.VerifiedRules.FoxSuzuka._hit(gs,0,0,1,0,3,{"id":"suzuka-home","type":"ability"}),3,0)
	compare("guanhu",func(gs):
		gs.player(1).units[0].front=1;gs.VerifiedRules.PipeFox.countdown(gs,0,0,"front",false),2,0)
	compare("gunvhongye",func(gs):gs.VerifiedRules.Maple.projectile(gs,0,0,3),3,0)
	compare("yujuchong",func(gs):gs.VerifiedRules.SilkNinja.projectile(gs,0,0,3,false),3,0)
	print("ABILITY_SOURCES_VERIFY checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func _initialize() -> void:run.call_deferred()
