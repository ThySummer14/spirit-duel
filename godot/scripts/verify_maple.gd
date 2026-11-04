extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Maple := preload("res://scripts/maple_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("MAPLE_FAIL ",detail)

func game() -> GS:
	var gs:=GS.create(["gunvhongye","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","gunvhongye","baizangzhu"],259)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"maple-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()

func night_rules() -> void:
	var gs:=game(); var foe: Dictionary=gs.player(1)
	check(Maple.night_value(gs,0)==0 and Maple.night_value(gs,1)==0,"both players start actual independent night at zero")
	check(not Maple.nightfall(gs,0,3) and Maple.night_value(gs,0)==1 and Maple.night_value(gs,1)==0,"failed threshold gains exactly one for corresponding player")
	gs._resolve_resolution_stack(); check(foe.avatarHp==29 and events(gs,"maple-projectile")==1,"actual night gain produces front-priority projectile, no random victim")
	foe.units[1].front=1; var hp: int=foe.units[1].hp
	check(Maple.gain_night(gs,0,3)==3,"gain API stores actual amount")
	gs._resolve_resolution_stack(); check(Maple.night_value(gs,0)==4 and foe.units[1].hp==hp-1 and foe.avatarHp==29,"one gain event triggers once even multi-point gain")
	check(Maple.nightfall(gs,0,3) and Maple.night_value(gs,0)==4 and events(gs,"night-gained")==2,"successful threshold never consumes or increases stored night")
	Maple.gain_night(gs,0,99); gs._resolve_resolution_stack(); hp=foe.units[1].hp
	check(Maple.night_value(gs,0)==10 and Maple.gain_night(gs,0,1)==0,"night clamps at ten and capped gain is no acquisition")
	gs._resolve_resolution_stack(); check(foe.units[1].hp==hp,"no fake passive on clamped or zero gain")
	check(Maple.gain_night(gs,0,-5)==0 and Maple.night_value(gs,0)==10,"negative gain cannot consume persistent night")
	for state in ["dead","inactive","suppressed"]:
		gs=game(); var u: Dictionary=gs.player(0).units[0]
		if state=="dead": gs._knockout_unit(u)
		elif state=="inactive": u.level=0
		else: u.baseRulesSuppressed=true
		Maple.gain_night(gs,0); gs._resolve_resolution_stack()
		check(Maple.night_value(gs,0)==1 and events(gs,"maple-projectile")==0,"resource gains while native source "+state+" but no passive")
	gs=game(); gs.player(0).units[0].frozen=1; Maple.gain_night(gs,0); gs._resolve_resolution_stack()
	check(events(gs,"maple-projectile")==1,"stun does not silence passive night acquisition trigger")
	gs=game(); check(gs.end_turn(0) and gs.end_turn(1) and events(gs,"maple-projectile")==0,"plain turn start has no legacy random damage without actual night gain")

func doll_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	gs._grow_unit(foe.units[0],0,30); var hp: int=foe.units[0].hp
	play(gs,"c25901",foe.units[0].uid)
	check(foe.units[0].hp==hp-3 and Maple.marked(foe.units[0]) and int(foe.units[0].armorBreak)==0 and not foe.units[0].get("poison",false),"symbol deals3 and real doll, no poison or armor-break substitute")
	check(gs.end_turn(0) and foe.units[0].hp==hp-3 and Maple.marked(foe.units[0]),"doll does not fire at source owner's end on opposing host")
	check(gs.end_turn(1) and foe.units[0].hp==hp-5 and not Maple.marked(foe.units[0]) and Maple.night_value(gs,0)==1 and foe.avatarHp==29,"host owner's actual end removes doll, deals2, failed night10 gains1 and passive1")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[0],0,30); Maple.attach(gs,0,0,foe.units[0]); Maple.attach(gs,0,0,foe.units[0]); hp=foe.units[0].hp
	Maple.end_turn(gs,1); gs._resolve_resolution_stack()
	check(foe.units[0].hp==hp-2 and Maple.night_value(gs,0)==1,"same doll reattachment replaces single spirit without stacking")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=10
	for u in foe.units: gs._grow_unit(u,0,30)
	var hps: Array=foe.units.map(func(u):return int(u.hp)); Maple.attach(gs,0,0,foe.units[0]); Maple.end_turn(gs,1); gs._resolve_resolution_stack()
	check(foe.units[0].hp==hps[0]-2 and foe.units[1].hp==hps[1]-2 and foe.units[2].hp==hps[2]-2 and foe.units[3].hp==hps[3]-2 and foe.avatarHp==28,"night10 doll damages host exactly once and every other hostile character2")
	check(p.night==10 and events(gs,"night-gained")==0 and events(gs,"maple-projectile")==0,"successful doll threshold never creates phantom acquisition projectile")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=9
	for u in foe.units: gs._grow_unit(u,0,30)
	hps=foe.units.map(func(u):return int(u.hp)); Maple.attach(gs,0,0,foe.units[0]); Maple.attach(gs,0,0,foe.units[1]); Maple.end_turn(gs,1); gs._resolve_resolution_stack()
	check(p.night==10 and foe.avatarHp==27 and foe.units[0].hp==hps[0]-4 and foe.units[1].hp==hps[1]-2 and foe.units[2].hp==hps[2]-2,"two dolls resolve sequentially: first crosses9to10 withoutAOE, next meets10 and AOEs other host")
	check(events(gs,"maple-projectile")==1,"sequential threshold only triggers acquisition once")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[0],0,30); Maple.attach(gs,0,0,foe.units[0]); gs._knockout_unit(p.units[0]); hp=foe.units[0].hp
	Maple.end_turn(gs,1); gs._resolve_resolution_stack()
	check(foe.units[0].hp==hp-2 and Maple.night_value(gs,0)==1 and events(gs,"maple-projectile")==0,"independent attached doll works while source dead, native passive remains inactive")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(p.units[1],0,30); hp=p.units[1].hp; play(gs,"c25901",p.units[1].uid)
	check(Maple.marked(p.units[1]) and gs.end_turn(0) and p.units[1].hp==hp-5 and Maple.night_value(gs,0)==1,"explicit any-shikigami spell supports own host with own-turn actual delay")
	gs=game(); foe=gs.player(1); Maple.attach(gs,0,0,foe.units[0]); Maple.remove_doll(gs,foe.units[0]); Maple.end_turn(gs,1); gs._resolve_resolution_stack()
	check(not Maple.marked(foe.units[0]) and events(gs,"night-triggered")==0,"removing charm never triggers its damage or night effect")
	Maple.attach(gs,0,0,foe.units[0]); gs._knockout_unit(foe.units[0]); gs._resolve_resolution_stack()
	check(not Maple.marked(foe.units[0]) and Maple.night_value(gs,0)==0,"knockout removes doll without faking end-of-turn explosion")

func card_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	foe.units[0].keywords=["veil"]; p.units[1].keywords=["veil"]
	var h:=give(gs,"c25901"); var targets:=gs.valid_targets(0,gs.hand_card_def(0,h))
	check(targets.has(p.units[1].uid) and not targets.has(foe.units[0].uid) and not targets.has("avatar-1"),"manual any-unit target obeys hostile veil and rejects avatar")
	check(not gs.can_play_card(0,h,foe.units[0].uid).ok,"command cannot bypass hostile veil")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[0],0,30); var hp: int=foe.units[0].hp; play(gs,"c25902",foe.units[0].uid)
	check(foe.units[0].hp==hp and Maple.night_value(gs,0)==0,"night0 damage is truly zero, no fixed4 or night gain")
	p.night=7; play(gs,"c25902",foe.units[0].uid); check(foe.units[0].hp==hp-7 and p.night==7,"night damage reads actual7 without consuming resource")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25903")
	check(p.units[0].attack==2 and p.units[0].maxHp==6,"blood true2/6 form")
	gs._grow_unit(foe.units[0],0,30); foe.units[0].front=1; check(gs.basic_attack(0,0) and Maple.marked(foe.units[0]),"blood actual combat HP damage attaches doll")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25903"); foe.units[0].front=1; foe.units[0].shield=99
	check(gs.basic_attack(0,0) and not Maple.marked(foe.units[0]),"fully armored combat never counts as actual HP damage for doll")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25903"); gs._grow_unit(foe.units[1],0,30); gs._damage_unit(1,1,1,0,0)
	check(not Maple.marked(foe.units[1]),"blood rejects noncombat damage")
	gs._damage_unit(1,1,1,0,0,true); check(Maple.marked(foe.units[1]),"combat target can be backrow and is not hardcoded front")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25904"); check(p.units[0].attack==3 and p.units[0].maxHp==6,"dance true3/6 form")
	for n in [0,4,5,9,10]: p.night=n; check(Maple.damage_bonus(gs,0,0,false)==int(n/5) and Maple.damage_bonus(gs,0,0,true)==0,"dynamic floor night/5 bonus, never combat at night%d" % n)
	p.night=10; gs._grow_unit(foe.units[0],0,30); hp=foe.units[0].hp; play(gs,"c25901",foe.units[0].uid)
	check(foe.units[0].hp==hp-5,"dance applies actual spell damage bonus")
	hp=foe.units[0].hp; gs._damage_unit(1,0,2,0,0,true); check(foe.units[0].hp==hp-2,"actual combat damage never uses noncombat enhancement")
	var avatar: int=foe.avatarHp; Maple.projectile(gs,0,0,1); check(foe.avatarHp==avatar-3,"damage bonus also enhances native ability projectile")
	gs=game(); p=gs.player(0); foe=gs.player(1)
	for u in foe.units: gs._grow_unit(u,0,30)
	var hps: Array=foe.units.map(func(u):return int(u.hp)); var energy: int=p.energy
	play(gs,"c25905",foe.units[0].uid)
	check(foe.units[0].hp==hps[0]-3 and foe.units[1].hp==hps[1] and foe.avatarHp==30 and p.energy==energy,"unmarked scatter only3damage and actual first shared instant")
	Maple.attach(gs,0,0,foe.units[0]); hps=foe.units.map(func(u):return int(u.hp)); play(gs,"c25905",foe.units[0].uid)
	check(foe.units[0].hp==hps[0]-5 and foe.units[1].hp==hps[1]-2 and foe.avatarHp==28 and not Maple.marked(foe.units[0]),"marked scatter removes actual doll and deals separate2 to all hostiles")
	check(p.energy==energy-1 and Maple.night_value(gs,0)==0,"second scatter pays1 and manual removal never causes doll night gain")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25906")
	check(foe.units.all(func(u):return Maple.marked(u)) and foe.avatarHp==30 and Maple.night_value(gs,0)==0,"baseline death dance only attaches all, no invented immediate damage")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25907")
	check(p.units[0].attack==4 and p.units[0].maxHp==7 and foe.units.filter(func(u):return Maple.marked(u)).size()==1,"burst true4/7 and exactly one random on actual form entry")
	for u in foe.units: u.erase("mapleDoll")
	check(gs.end_turn(0) and foe.units.all(func(u):return not Maple.marked(u)),"burst cannot substitute own end with random doll")
	check(gs.end_turn(1) and foe.units.filter(func(u):return Maple.marked(u)).size()==1,"burst adds exactly one at actual own start")
	var host: Dictionary=foe.units.filter(func(u):return Maple.marked(u))[0]; var before: int=foe.avatarHp
	gs._knockout_unit(host); gs._resolve_resolution_stack(); check(foe.avatarHp==before-2 and not Maple.marked(host),"burst reacts to marked enemy actual knockout for2avatar")
	before=foe.avatarHp; gs._knockout_unit(foe.units.filter(func(u):return int(u.hp)>0)[0]); gs._resolve_resolution_stack(); check(foe.avatarHp==before,"unmarked enemy knockout never triggers burst")

func awakening_and_ai() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c25908"); check(p.units[0].awakened and p.units[0].attack==3 and p.units[0].maxHp==6 and foe.avatarHp==30,"awake exact1/1 and no old5front invented damage")
	Maple.gain_night(gs,0); gs._resolve_resolution_stack(); check(foe.avatarHp==27,"awake acquisition is true3projectile")
	p.night=9; Maple.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.night==10 and foe.avatarHp==24 and not p.units[0].get("mapleAwakenUsed",false),"awake end threshold9 gains1 and3projectile,10damage remains unused")
	Maple.end_turn(gs,0); gs._resolve_resolution_stack(); check(foe.avatarHp==14 and p.units[0].get("mapleAwakenUsed",false),"next awake end with10 fires exact10once")
	Maple.end_turn(gs,0); gs._resolve_resolution_stack(); check(foe.avatarHp==14,"awake ten-shot never repeats next turn")
	gs._knockout_unit(p.units[0]); gs.VerifiedRules.Peach.revive(gs,0,3,p.units[0],false,false); Maple.end_turn(gs,0); gs._resolve_resolution_stack()
	check(foe.avatarHp==14 and p.units[0].get("mapleAwakenUsed",false),"single use persists through actual knockout and revival")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=8; give(gs,"c25902"); gs._grow_unit(foe.units[0],0,30)
	var best: Dictionary=AI._best_card(gs,0)
	check(best.ok and gs.valid_targets(0,gs.hand_card_def(0,int(best.hand))).has(best.target) and not gs._unit_by_uid(foe.units,str(best.target)).is_empty(),"AI uses legal hostile shikigami despite friendly valid targets")
	check(gs.play_card(0,int(best.hand),best.target),"AI-selected actual command resolves")
	p.night=5; h_current(gs)
	for id in ["c25901","c25902","c25903","c25904","c25905","c25906","c25907","c25908"]: check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original card art "+id)

func h_current(gs) -> void:
	var h:=give(gs,"c25902"); var c: Dictionary=gs.hand_card_def(0,h)
	check(c.get("currentCardStats","").contains("当前伤害5") and Content.card_def("c25902").get("currentCardStats","")=="","live card shows current night damage without mutating shared definition")

func integration_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c25904"); p.night=10; foe.units[0].bloodTransfer=true; foe.units[0].shield=2
	var hp: int=foe.units[0].hp; var before: int=foe.avatarHp
	gs._damage_unit(1,0,3,0,0)
	check(foe.units[0].hp==hp and foe.units[0].shield==0 and foe.avatarHp==before-3,"blood transfer carries once-enhanced5 minus2armor, never adds dance twice")
	check(not foe.units[0].get("bloodTransfer",false),"actual transfer token consumed once")
	gs=GS.create(["gunvhongye","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","duyanxiaoseng","xixueji","baizangzhu"],259)
	for side in gs.players:
		side.hand.clear(); side.energy=40; side.levelUpUsed=true
		for u in side.units: u.level=3
	p=gs.player(0); foe=gs.player(1); gs.current_player=1; play(gs,"c18807",null,1); gs.current_player=0; play(gs,"c25904"); p.night=10
	hp=foe.units[1].hp; before=foe.avatarHp; gs._damage_avatar(1,3,0,0)
	check(foe.avatarHp==before and foe.units[1].hp==hp-5,"real golden-form redirect receives once-enhanced5 instead of7")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25904"); p.night=10; hp=foe.units[0].hp; foe.units[0].barrier=true
	gs._damage_unit(1,0,3,0,0)
	check(foe.units[0].hp==hp and not foe.units[0].barrier,"dance keeps actual barrier single-packet protection")
	Maple.attach(gs,0,0,foe.units[0]); var pool: Array=gs.VerifiedRules.PipeFox.candidates(gs,1)
	check(pool.any(func(c):return c.key=="mapleDoll" and c.uid==foe.units[0].uid),"cleanse exposes real hostile doll as a separate charm candidate")
	gs.VerifiedRules.PipeFox.cleanse(gs,1,3)
	check(not Maple.marked(foe.units[0]) and Maple.night_value(gs,0)==10,"cleanse actually removes doll without triggering a threshold or consuming night")
	Maple.attach(gs,1,2,foe.units[0]); check(not gs.VerifiedRules.PipeFox.candidates(gs,1).any(func(c):return c.key=="mapleDoll"),"cleanse cannot remove friendly-source doll as hostile effect")
	var marks:=Status.unit_marks(Status.unit_view(gs,0,0,0),gs.turn_counter)
	check(marks.any(func(m):return m.id=="maple-night" and m.label.contains("10")) and marks.any(func(m):return m.id=="maple-dance"),"live source status exposes actual shared night and noncombat enhancement")
	marks=Status.unit_marks(Status.unit_view(gs,1,0,0),gs.turn_counter)
	check(marks.any(func(m):return m.id=="maple-doll"),"live target status exposes actual attached doll independently")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25908"); p.night=10
	check(gs.end_turn(0) and foe.avatarHp==20 and p.units[0].get("mapleAwakenUsed",false),"real own end invokes exact awakened10 once through shared transition")
	check(gs.end_turn(1) and foe.avatarHp==20,"enemy end never invokes source awakening")
	check(gs.end_turn(0) and foe.avatarHp==20,"next actual own end respects persistent once-per-game bit")

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["gunvhongye","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","gunvhongye","baizangzhu"],259); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		for u in foe.units: gs._grow_unit(u,0,30)
		hand(b,["c25901"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(p.units[0].uid)).selected and b._unit_widget(str(foe.units[1].uid)).selected,"native symbol exposes actual friendly and hostile targets")
		if physical.x==1280: await capture("01-maple-any-shikigami-target")
		var hp: int=foe.units[1].hp; await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(Maple.marked(foe.units[1]) and foe.units[1].hp==hp-3,"native actual selected doll is attached with exact3damage")
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(texts(b).contains("红枫娃娃") and texts(b).contains("回合结束"),"native live inspector distinguishes doll's real trigger")
		if physical.x==1600: await capture("02-maple-doll-live-inspector")
		escape(); await settled(b)
		hand(b,["c25905"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(not Maple.marked(foe.units[1]) and foe.avatarHp==28 and Maple.night_value(gs,0)==0,"native scatter removes doll and resolves trueAOE without night")
		hand(b,["c25904"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		p.night=7; hand(b,["c25902"]); await settled(b)
		check(b._hand_row.get_child(0).original_stat_changes().contains("当前伤害8"),"native card displays actual current7night plus1noncombat damage")
		if physical.x==1280: await capture("03-maple-live-night-damage-and-art")
		hp=foe.units[0].hp; await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(foe.units[0].hp==hp-8 and p.night==7,"native dynamic selected spell deals8 without consuming night")
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b); await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(texts(b).contains("入夜") and texts(b).contains("非战斗"),"native source inspector exposes night resource and damage bonus")
		if physical.x==1600: await capture("04-maple-night-and-form-inspector")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args()
	if not args.is_empty() and args[0]!="--rules-only": out=args[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	night_rules(); doll_rules(); card_rules(); awakening_and_ai(); integration_rules()
	if not args.has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("MAPLE checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
