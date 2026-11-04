extends SceneTree
const Content:=preload("res://scripts/content_loader.gd")
const GS:=preload("res://scripts/game_state.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("PACKAGE_FAIL ",text)
func _initialize() -> void:
	for role in [264,265,266,267,271,294,296]:
		for n in range(1,9):
			var id:="c%d%02d"%[role,n];var c:=Content.card_def(id)
			check(not c.is_empty() and c.get("verifiedRules",false) and not c.get("verificationPending",[]).is_empty(),"packed rules and pending "+id)
			check(ResourceLoader.exists("res://assets/official/cards/%s.png"%id),"packed original PNG "+id)
	for id in ["wuchen-followup","rednight-sword-aura","arakawa-annihilate"]:
		check(Content.card_def(id).get("verifiedRules",false),"packed derivative "+id)
	var gs:=GS.create(["huangchuanzhizhu","jicanghai","wuchen","xiaoxiuzhishou"],["ninghongye","tayumenhutao","chuanyuan","shuzhu"],271296)
	check(gs.has_method("_trigger_realm_ids"),"packed final realm continuation executor")
	check(gs.players.size()==2 and gs.player(0).units.size()==4 and gs.player(1).units.size()==4,"packed creates actual heptet match")
	for owner in 2:
		gs.player(owner).hand.clear();gs.player(owner).energy=40;gs.player(owner).levelUpUsed=true
		for u in gs.player(owner).units:u.level=3
	gs.player(0).hand.append({"definitionId":"c27107","instanceId":"packed-devour"})
	var target:Dictionary=gs.player(1).units[0]
	check(gs.play_card(0,0,target.uid) and target.frozen>0 and gs.player(0).units[0].has("lanternStored"),"packed real devour record and held stun")
	check(not Content.card_def("c20602").get("verifiedRules",true),"packed Mingche remains explicitly incomplete")
	print("HEPTET_PACKAGE_CHECK ",JSON.stringify({"checks":checks,"failures":failures}));quit(1 if failures else 0)
