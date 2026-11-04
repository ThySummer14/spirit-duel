extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Paint := preload("res://scripts/paint_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("PAINT_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["huaniajuan","huang","taohuayao","yaodaoji"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],229)
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	# Creation itself can have started flower's first turn.
	gs.player(0).realms.clear()
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"paint-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func sum_hp(gs, owner: int) -> int:
	var result: int=gs.player(owner).avatarHp
	for u in gs.player(owner).units: result+=int(u.hp)
	return result

func field_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0)
	Paint.turn_start(gs,0)
	check(Paint.durability(gs,0)==2 and p.realms.size()==1,"basic creates actual2durability realm, no shields or draw substitute")
	var first:=Paint.field(gs,0).duplicate(true)
	Paint.field(gs,0).testInherited="retained"
	Paint.turn_start(gs,0)
	check(Paint.durability(gs,0)==4 and p.realms.size()==1 and Paint.field(gs,0).uid!=first.uid,"fusion creates new realm identity and sums current durability")
	check(Paint.field(gs,0).testInherited=="retained" and events(gs,"realm-destroyed")==0,"fusion inherits states without destruction effects")
	Paint.summon_field(gs,0,0,5,true); Paint.turn_start(gs,0)
	check(Paint.durability(gs,0)==11,"base condition9durability gains2 beyond ten, no hard cap")
	Paint.turn_start(gs,0)
	check(Paint.durability(gs,0)==11,"base condition excludes10or above")
	gs._damage_avatar(0,3,1,0)
	check(Paint.durability(gs,0)==8,"front actual realm loses durability from real avatar damage")
	check(Paint.consume(gs,0)==8 and p.realms.is_empty() and events(gs,"realm-destroyed")==0,"consumption removes actual field without destruction history")
	check(Paint.consume(gs,0)==0,"no field consumption safely yields zero")
	for mode in ["dead","inactive","suppressed","stunned"]:
		gs=game(); var u: Dictionary=gs.player(0).units[0]
		if mode=="dead": gs._knockout_unit(u)
		if mode=="inactive": u.level=0
		if mode=="suppressed": u.baseRulesSuppressed=true
		if mode=="stunned": u.frozen=1
		Paint.turn_start(gs,0)
		check(Paint.durability(gs,0)==(2 if mode=="stunned" else 0),"basic actual "+mode+" eligibility")
	gs=game(); p=gs.player(0); play(gs,"c22904")
	check(p.units[0].awakened and p.units[0].attack==3 and p.units[0].maxHp==5 and Paint.durability(gs,0)==3,"awakening real+1/+1 and immediate3durability")
	Paint.summon_field(gs,0,0,8,true); Paint.turn_start(gs,0)
	check(Paint.durability(gs,0)==14,"awakening removes ten threshold and starts3")
	play(gs,"c22901")
	check(Paint.durability(gs,0)==17,"awaken modifies dedicated summoned field to3")
	var view: Dictionary=Status.unit_view(gs,0,0,0)
	check(view.get("paintDurability")==17,"readonly status exposes actual field durability")
	var stamp:=JSON.stringify(gs.snapshot())
	gs.hand_card_def(0,0); Status.unit_view(gs,0,0,0)
	check(JSON.stringify(gs.snapshot())==stamp,"card and unit descriptions do not mutate field")

func wind_bird_girl() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	give(gs,"c22901"); var iid: String=p.hand[0].instanceId
	check(gs.play_card(0,0) and p.energy==80 and gs.card_payment(0,Content.card_def("c22901")).instantUsed,"first wind uses shared instant payment")
	check(Paint.durability(gs,0)==2 and p.hand.size()==1 and p.hand[0].instanceId==iid and p.hand[0].paintBounceSpent,"wind returns original instance once after use")
	check(not gs.hand_card_def(0,0).keywords.has("bounce"),"returned wind loses only bounce and describes it")
	check(gs.play_card(0,0) and p.energy==79 and p.hand.is_empty() and Paint.durability(gs,0)==4,"second same instance pays one and never returns twice")
	var h: int=p.hand.size(); foe.units[0].hp=5
	play(gs,"c22902",foe.units[0].uid)
	check(foe.units[0].hp==0 and p.hand.size()==h+1 and Paint.durability(gs,0)==0,"bird spends4, deals5 to lethal and actually draws1")
	gs=game(); p=gs.player(0); foe=gs.player(1); var hp: int=foe.units[1].hp
	play(gs,"c22902",foe.units[1].uid)
	check(foe.units[1].hp==hp-1 and p.hand.is_empty(),"bird with no field deals1 and does not draw on survival")
	Paint.summon_field(gs,0,0,2,true); p.units[2].hp=2
	play(gs,"c22902",p.units[2].uid)
	check(p.units[2].hp==0 and p.hand.size()==1,"bird may target friendly shikigami and kill-draw is not enemy-only")
	foe.units[0].keywords=["veil"]
	var opts: Array=gs.valid_targets(0,Content.card_def("c22902"))
	check(opts.has(p.units[0].uid) and not opts.has(foe.units[0].uid) and not opts.has("avatar-1"),"bird actual targets both sides' shikigami, enemy veil, no avatar")
	gs=game(); p=gs.player(0); play(gs,"c22903")
	check(p.units[0].attack==3 and p.units[0].maxHp==5 and p.units[0].formRules.paintGirl,"girl actual3/5 base form and native rule")
	Paint.end_turn(gs,0)
	check(Paint.durability(gs,0)==4,"girl owner end summons two2durability fields and fuses4")
	Paint.end_turn(gs,1)
	check(Paint.durability(gs,0)==4,"girl never summons while field exists")
	Paint.consume(gs,0); Paint.end_turn(gs,1)
	check(Paint.durability(gs,0)==4,"girl triggers at opposing end too")
	play(gs,"c22904"); Paint.consume(gs,0); Paint.end_turn(gs,1)
	check(Paint.durability(gs,0)==6,"awakened girl summons two3durability fields")
	gs._knockout_unit(p.units[0]); Paint.consume(gs,0); Paint.end_turn(gs,1)
	check(Paint.durability(gs,0)==0 and p.units[0].formRules.is_empty(),"dead girl's form ceases, no passive substitute")

func fragrance_enter_soul() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	for u in foe.units: gs._grow_unit(u,0,40)
	p.avatarHp=20; Paint.summon_field(gs,0,0,5,true)
	var total:=sum_hp(gs,1); play(gs,"c22905")
	check(total-sum_hp(gs,1)==6 and events(gs,"paint-fragrance-hit")==3,"fragrance initial2 plus floor5/2 repeats, no lost initial hit")
	check(p.avatarHp==26 and Paint.durability(gs,0)==0,"fragrance chooses injured avatar and actually heals each packet")
	var packet: Array=gs.rule_events.filter(func(e):return e.kind=="paint-fragrance-hit")
	check(packet[0].remainingPaint==5 and packet[1].remainingPaint==0,"fragrance first packet precedes field removal")
	gs=game(); foe=gs.player(1); total=sum_hp(gs,1); play(gs,"c22905")
	check(total-sum_hp(gs,1)==2 and events(gs,"paint-fragrance-hit")==1,"fragrance no-field retains initial random hit and heal")
	gs=game(); foe=gs.player(1); foe.units[0].attack=9; foe.units[1].attack=1; foe.units[1].hp=50; foe.units[1].maxHp=50; foe.units[1].barrier=true; foe.units[1].keywords=["veil"]; foe.units[1].unyielding=true
	play(gs,"c22907")
	check(foe.units[1].hp==0 and foe.units[0].hp>0 and Paint.durability(gs,0)==2,"enter destroys actual lowest power through veil, barrier, unyielding; creates field")
	gs=game(); foe=gs.player(1); for u in foe.units: gs._knockout_unit(u)
	play(gs,"c22907"); check(Paint.durability(gs,0)==2,"enter still summons field with no living enemy")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.avatarHp=10; Paint.summon_field(gs,0,0,6,true)
	foe.units[0].front=1; foe.units[0].hp=2; foe.units[0].shield=1
	play(gs,"c22908")
	check(foe.units[0].hp==0 and foe.avatarHp==27 and Paint.durability(gs,0)==0,"soul projects6, armor1 before overkill3, removes field")
	check(p.avatarHp==18,"soul actually heals from unshielded spell packets through shared lifesteal")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.avatarHp=10; Paint.summon_field(gs,0,0,4,true)
	play(gs,"c22908"); check(foe.avatarHp==26 and p.avatarHp==14,"soul empty front projects avatar4 and heals4")
	play(gs,"c22908"); check(foe.avatarHp==26 and p.avatarHp==14,"soul no field never deals fixed or phantom damage")
	gs=game(); foe=gs.player(1); Paint.summon_field(gs,0,0,6,true); foe.units[0].front=1; foe.units[0].hp=2; foe.units[0].barrier=true
	play(gs,"c22908"); check(foe.units[0].hp==2 and not foe.units[0].barrier and foe.avatarHp==26,"barrier blocks unit packet but independent pierce4 still hits avatar")

func scroll_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); Paint.summon_field(gs,0,0,4,true); p.units[3].front=1
	play(gs,"c22906"); var u: Dictionary=p.units.back(); var idx: int=p.units.size()-1
	check(u.paintSummon and u.attack==7 and u.hp==7 and u.front==1 and p.units[3].front==0 and Paint.durability(gs,0)==0,"scroll consumes4 and creates real7/7 frontline, displacing ordinary unit")
	u.hp=5; Paint.turn_start(gs,0)
	check(u.removed and u.hp==0 and u.knockout==0 and Paint.durability(gs,0)==7,"start scroll self-destruct makes currenthp5 field after basic2, no revival timer")
	Paint.turn_start(gs,0); check(Paint.durability(gs,0)==9,"removed scroll never self-destructs twice")
	gs=game(); p=gs.player(0); play(gs,"c22904"); Paint.consume(gs,0); Paint.summon_field(gs,0,0,2,true); play(gs,"c22906"); u=p.units.back(); u.hp=4
	Paint.turn_start(gs,0); check(Paint.durability(gs,0)==7,"scroll own4durability unaffected by flower awakening3 replacement")
	gs=game(); p=gs.player(0); play(gs,"c22906"); u=p.units.back(); idx=p.units.size()-1
	check(u.hp==3 and u.attack==3,"no field still summons actual base3/3")
	check(gs.VerifiedRules.Movement.move_to(gs,0,idx,0) and u.removed and u.hp==0,"moving summon to reserve removes it immediately")
	gs=game(); p=gs.player(0); play(gs,"c22906"); u=p.units.back(); gs._knockout_unit(u)
	check(u.removed and u.knockout==0,"destroyed summon removed and cannot naturally revive")
	gs=game(); p=gs.player(0); play(gs,"c22906"); u=p.units.back(); gs.VerifiedRules.Movement.move_to(gs,0,3,1)
	check(u.removed and gs.front_index(0)==3,"another actual move into frontline removes scroll")
	gs=game(); p=gs.player(0); play(gs,"c22906"); u=p.units.back(); play(gs,"c22906")
	check(u.removed and p.units.back().hp==3 and gs.front_index(0)==p.units.size()-1,"second scroll replaces prior summon with no index shifting")
	gs=game(); p=gs.player(0); play(gs,"c22906"); u=p.units.back(); gs._knockout_unit(p.units[0]); Paint.turn_start(gs,0)
	check(u.removed and Paint.durability(gs,0)==3,"scroll self-destruct still works with flower knocked out")
	gs=game(); p=gs.player(0); play(gs,"c22906"); idx=p.units.size()-1
	check(gs.basic_attack_targets(0,idx).size()>0,"real scroll is legally available for ordinary attack")

func lifecycle_and_limits() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0)
	check(gs.end_turn(0) and gs.end_turn(1) and Paint.durability(gs,0)==2,"actual turn lifecycle starts flower basic2")
	gs=game(); p=gs.player(0); play(gs,"c22903")
	check(gs.end_turn(0) and Paint.durability(gs,0)==4,"actual owner end hooks girl before next turn")
	check(gs.end_turn(1) and Paint.durability(gs,0)==6,"actual enemy end preserves existing field then flower start adds2")
	gs=game(); p=gs.player(0); play(gs,"c22906"); var scroll: Dictionary=p.units.back()
	check(gs.end_turn(0) and gs.end_turn(1) and scroll.removed and Paint.durability(gs,0)==5,"actual start processes scroll self-destruct before ordinary retreat")
	gs=game(); p=gs.player(0); Paint.summon_field(gs,0,0,3,true)
	gs._deploy_realm(0,Content.card_def("c17803")); var other: Dictionary=p.realms.back()
	Paint.summon_field(gs,0,0,2,true)
	check(p.realms.size()==2 and p.realms[0].uid==other.uid and Paint.durability(gs,0)==5,"new fused realm enters behind unrelated existing realms")
	Paint.consume(gs,0)
	check(p.realms.size()==1 and p.realms[0].uid==other.uid,"removal consumes flower realm only")
	gs=game(); p=gs.player(0); give(gs,"c22901"); p.nullifyNextCardTurn=gs.turn_counter
	check(gs.play_card(0,0) and Paint.durability(gs,0)==0 and p.hand.size()==1 and p.hand[0].paintBounceSpent,"announced bounce survives ordinary counter while spell itself creates no field")
	gs=game(); p=gs.player(0); give(gs,"c22908")
	check(AI._score_card(gs,0,gs.hand_card_def(0,0),null)==-100,"AI avoids empty field soul with zero effect")
	var stamp:=JSON.stringify(gs.snapshot())
	gs.valid_targets(0,Content.card_def("c22902")); Paint.realm_card({"nativeRealm":"paint","hp":9},Content.card_def("c22901"))
	check(JSON.stringify(gs.snapshot())==stamp,"target and realm inspection queries are readonly")

func ai_and_art() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	Paint.summon_field(gs,0,0,4,true)
	for u in foe.units: gs._grow_unit(u,0,30)
	foe.units[2].hp=4; give(gs,"c22902")
	var best: Dictionary=AI._best_card(gs,0)
	check(best.ok and best.target==foe.units[2].uid and gs.play_card(0,best.hand,best.target) and foe.units[2].hp==0,"AI selects actual lethal enemy bird target over friendly units")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c22906"); best=AI._best_card(gs,0)
	check(best.ok and gs.play_card(0,best.hand,best.target) and p.units.back().get("paintSummon",false),"AI uses untargeted actual summon legally")
	for id in ["c22901","c22902","c22903","c22904","c22905","c22906","c22907","c22908"]:
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original full card art "+id)
		check(Content.card_def(id).paintRules and not Content.card_def(id).get("verificationPending",[]).is_empty(),"sourced native rule retains pending original interaction "+id)

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["huaniajuan","huang","taohuayao","yaodaoji"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],229); b._ai_thinking=true
		for p0 in b.gs.players:
			p0.hand.clear(); p0.energy=40; p0.levelUpUsed=true
			for u0 in p0.units: u0.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); p.realms.clear()
		hand(b,["c22901"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(Paint.durability(gs,0)==2 and p.hand.size()==1 and p.hand[0].paintBounceSpent,"native wind real mouse creates field and returns actual original hand")
		if physical.x==1280: await capture("01-wind-bounce-and-actual-field")
		hand(b,["c22902"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(p.units[2].uid)).selected and b._unit_widget(str(foe.units[2].uid)).selected,"native bird highlights both sides' actual unit targets")
		var energy: int=p.energy; await click(b._enemy_plate); await settled(b)
		check(b._pending_target_card==0 and p.energy==energy,"native bird rejects avatar without paying")
		var hp: int=foe.units[2].hp; await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp==hp-3 and Paint.durability(gs,0)==0,"native bird target actual3 damage and removes field")
		Paint.summon_field(gs,0,0,4,true); hand(b,["c22906"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units.back().get("paintSummon",false) and p.units.back().attack==7 and p.units.back().hp==7,"native summon mouse actually creates7/7 frontend entity")
		if physical.x==1600: await capture("02-real-scroll-frontline")
		hand(b,["c22904"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].awakened and Paint.durability(gs,0)==3,"native awakening actual3 field")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg!="--rules-only": out=arg; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	field_rules(); wind_bird_girl(); fragrance_enter_soul(); scroll_rules(); lifecycle_and_limits(); ai_and_art()
	if not args.has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("PAINT checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
