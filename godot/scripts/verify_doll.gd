extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Doll := preload("res://scripts/doll_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("DOLL_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["choushizhinv","rulianshi","tianjingxia","guiqie"],["fenghuanghuo","bingyong","xuenv","baizangzhu"],258)
	while not gs.pending_choice.is_empty():
		if not AI._resolve_choice(gs,gs.action_player()): break
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.VerifiedRules.Onikiri.remove_charms(gs.player(0).units[3]);gs.rule_events.clear()
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"doll-test-%d" % gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actualcard "+id)
func current(gs,owner: int = 0) -> Dictionary:
	for u in gs.player(owner).units:
		if u.get("dollSummon",false) and int(u.hp)>0 and not u.get("removed",false):return u
	return {}
func spawn(gs, kind: String = "resent", target: String = "") -> Dictionary:
	if target=="":target=str(gs.player(1).units[0].uid)
	var idx:=Doll.summon(gs,0,0,kind,target);gs._resolve_resolution_stack()
	return gs.player(0).units[idx]
func test_base_and_targets() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1)
	check(p.units[0].attack==3 and p.units[0].maxHp==4,"base exact3/4")
	var at:=give(gs,"c25801");var c: Dictionary=gs.hand_card_def(0,at)
	check(gs.valid_targets(0,c).has(foe.units[0].uid) and not gs.valid_targets(0,c).has(p.units[0].uid) and not gs.valid_targets(0,c).has("avatar-1"),"summon chooses enemy shikigami only")
	foe.units[1].keywords=["veil"]
	check(not gs.valid_targets(0,c).has(foe.units[1].uid),"selected binding respects veil")
	check(not gs.play_card(0,at,p.units[0].uid),"reject wrongside target")
	check(gs.play_card(0,at,foe.units[0].uid),"real summon card")
	var d:=current(gs)
	check(d.id=="doll-resent" and d.attack==0 and d.hp==4 and d.front==1,"real0/4 stablefront summon")
	check(d.dollTargets==[foe.units[0].uid] and p.units.size()==5,"actual uid binding one appendedbody")
	check(p.night==1 and d.attack==0,"failednight3 gains1 but no premature3power")
	check(p.dollHistory==["resent"],"actual kind recorded once")
	foe.units[1].keywords=[]
	var index: int=gs._unit_index_by_uid(0,d.uid);play(gs,"c25806",foe.units[2].uid)
	check(d.removed and d.knockout==0 and not d.has("weaverGrave"),"replacement true removal not death or powdergrave")
	check(gs._unit_index_by_uid(0,d.uid)==index and p.units.size()==6,"removal preserves stable index")
	check(current(gs).id=="doll-curse" and p.dollHistory.size()==2,"new actual kind not copied substitute")
	play(gs,"c25807",foe.units[1].uid)
	check(current(gs).id=="doll-substitute" and current(gs).attack==0 and p.night==3,"third failedcheck raisesnight3 still no prematurebuff")
	play(gs,"c25801",foe.units[3].uid)
	check(current(gs).attack==3 and current(gs).hp==4 and p.night==3,"thresholdpass actually+3power no resourceconsumption")
	at=give(gs,"c25802");c=gs.hand_card_def(0,at)
	check(gs.valid_targets(0,c).has(current(gs).uid) and not gs.valid_targets(0,c).has(foe.units[0].uid),"nail only actual summons")
	check(not gs.can_play_card(0,give(gs,"doll-resent")).ok,"derived body cannot manuallycast")
func test_reactions() -> void:
	var gs:=game();var foe: Dictionary=gs.player(1);var d:=spawn(gs);var idx: int=gs._unit_index_by_uid(0,d.uid)
	gs._damage_unit(0,idx,0,1,0);gs._resolve_resolution_stack()
	check(foe.units[0].frozen==0,"zero damage never stuns")
	gs._grant_unit_armor(d,2);gs._damage_unit(0,idx,2,1,0);gs._resolve_resolution_stack()
	check(foe.units[0].frozen==0 and d.hp==4 and d.shield==0,"armor fullabsorb never triggers damageability")
	gs._damage_unit(0,idx,1,1,0);gs._resolve_resolution_stack()
	check(d.hp==3 and foe.units[0].frozen>0,"actualpositive damage stuns boundtarget")
	check(foe.units[1].frozen==0,"nonbound target untouched")
	gs=game();foe=gs.player(1);d=spawn(gs,"curse");idx=gs._unit_index_by_uid(0,d.uid)
	give(gs,"c12401",1);give(gs,"c12404",1);give(gs,"c11401",1)
	gs._damage_unit(0,idx,1,1,0);gs._resolve_resolution_stack()
	check(foe.hand.size()==2 and gs.rule_events.filter(func(e):return e.kind=="card-discarded").size()==1,"curse truly discards one actual handinstance")
	check(gs.rule_events.filter(func(e):return e.kind=="card-discarded").back().card.unitId=="fenghuanghuo" and foe.hand.any(func(e):return e.definitionId=="c11401"),"curse only boundcharacter exclusivecards")
	foe.hand.clear();gs._damage_unit(0,idx,1,1,0);gs._resolve_resolution_stack()
	check(foe.hand.is_empty() and gs.rule_events.filter(func(e):return e.kind=="card-discarded").size()==1,"empty eligiblehand causes no fake discard")
	gs=game();foe=gs.player(1);d=spawn(gs,"substitute");idx=gs._unit_index_by_uid(0,d.uid);var hp: int=foe.units[0].hp
	gs._grant_unit_armor(d,1);gs._damage_unit(0,idx,3,1,0);gs._resolve_resolution_stack()
	check(d.hp==2 and foe.units[0].hp==hp-2,"substitute equal postarmor damage not raw3")
	check(foe.units[1].hp==foe.units[1].maxHp,"substitute no unbound splash")
	gs=game();foe=gs.player(1);d=spawn(gs,"substitute");idx=gs._unit_index_by_uid(0,d.uid);foe.units[1].hp=6;d.dollTargets=[foe.units[1].uid]
	gs._damage_unit(0,idx,3,1,0,false,-1,false,true);gs._resolve_resolution_stack()
	check(d.removed and foe.units[1].hp==0,"critical6 and lethal original hit still transmits full6")
	check(gs.player(0).units[idx].uid==d.uid,"lethal body retains original index")
	gs=game();foe=gs.player(1);d=spawn(gs,"substitute");idx=gs._unit_index_by_uid(0,d.uid);hp=foe.units[0].hp;d.barrier=true
	gs._damage_unit(0,idx,9,1,0);gs._resolve_resolution_stack()
	check(d.hp==4 and foe.units[0].hp==hp and not d.barrier,"barrier prevents all received damage and reaction")
func test_unbinding_and_lifecycle() -> void:
	var gs:=game();var foe: Dictionary=gs.player(1);var d:=spawn(gs,"resent");var idx: int=gs._unit_index_by_uid(0,d.uid)
	gs._knockout_unit(foe.units[0],0,0);gs._resolve_resolution_stack()
	check(d.dollTargets.is_empty(),"real KO unbinds actualuid")
	foe.units[0].hp=foe.units[0].maxHp;foe.units[0].knockout=0;gs.VerifiedRules.Movement.revived(gs,1,0)
	gs._damage_unit(0,idx,1,1,0);gs._resolve_resolution_stack()
	check(foe.units[0].frozen==0,"sameuid revival never rebinds stale originallink")
	gs=game();foe=gs.player(1);d=spawn(gs,"resent");gs.VerifiedRules.Vine.attach(gs,1,0)
	gs._knockout_unit(foe.units[0],0,0);gs._resolve_resolution_stack()
	check(foe.units[0].hp>0 and d.dollTargets.has(foe.units[0].uid),"knockout substitution keeps legitimate binding")
	gs=game();d=spawn(gs,"resent");idx=gs._unit_index_by_uid(0,d.uid);var uid: String=d.uid
	gs._knockout_unit(d,1,0);gs._resolve_resolution_stack()
	check(d.removed and d.has("weaverGrave") and d.knockout==0,"actual doll death records genuine powder grave")
	play(gs,"c23603")
	check(d.hp==4 and d.uid==uid and not d.removed and d.front==1 and gs._unit_index_by_uid(0,uid)==idx,"powder revives exact doll original body")
	check(not d.get("dollDepartureRecorded",false),"revival clears stale departed bookkeeping")
	play(gs,"c23602")
	check(d.removed and d.hp==0 and d.knockout==0,"other summon truly replaces revived doll")
	gs=game();d=spawn(gs,"resent");idx=gs._unit_index_by_uid(0,d.uid)
	check(gs.VerifiedRules.Movement.move_to(gs,0,idx,0) and d.removed and d.knockout==0,"move to reserve truly removes summon no death")
	gs=game();foe=gs.player(1);d=spawn(gs);idx=gs._unit_index_by_uid(0,d.uid)
	gs._knockout_unit(d,1,0);gs._resolve_resolution_stack()
	check(d.weaverGrave.dollTargets==[foe.units[0].uid],"real corpse stores same stillvalid physical binding")
	gs._knockout_unit(foe.units[0],0,0);gs._resolve_resolution_stack()
	check(d.dollTargets.is_empty() and d.weaverGrave.dollTargets.is_empty(),"boundtarget KO also invalidates corpse binding snapshot")
	foe.units[0].hp=foe.units[0].maxHp;foe.units[0].knockout=0;play(gs,"c23603")
	gs._damage_unit(0,idx,1,1,0);gs._resolve_resolution_stack()
	check(d.dollTargets.is_empty() and foe.units[0].frozen==0,"powder cannot restore invalidated oldtarget link")
func test_forms_and_night() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1)
	play(gs,"c25803");check(p.units[0].attack==3 and p.units[0].maxHp==5,"baseline growthform exact3/5")
	var d:=spawn(gs);var hp: int=p.units[0].hp
	check(gs.end_turn(0),"natural endturn")
	check(d.hp==6 and d.maxHp==6 and p.units[0].hp==hp,"growth buffs true summon +2hp not master")
	check(d.attack==0,"baseline growth no invented night5 power")
	gs=game();p=gs.player(0);play(gs,"c25805")
	check(p.units[0].attack==4 and p.units[0].maxHp==5 and p.night==1 and current(gs).is_empty(),"randomform4/5 failednight7 gains1 no fake summon")
	p.night=7;Doll.turn_start(gs,0);gs._resolve_resolution_stack();d=current(gs)
	check(not d.is_empty() and d.hp==3 and d.attack==3,"true random summon0/4 gainsnight3 andselfdamage1")
	check(d.dollTargets.size()==1 and p.dollHistory.size()==1,"random summon realkind andtarget recorded")
	check(gs.rule_events.any(func(e):return e.kind=="doll-reaction"),"entry selfdamage triggers bound grass ability")
	gs=game();p=gs.player(0);foe=gs.player(1)
	check(not gs.can_play_card(0,give(gs,"c25808"),foe.units[0].uid).ok,"awake requires previouslyactuallysummoned kind")
	p.hand.clear();spawn(gs,"resent");p.night=9;play(gs,"c25808",foe.units[1].uid);d=current(gs)
	check(p.units[0].awakened and p.units[0].attack==4 and p.units[0].maxHp==5,"awake actual+1/+1")
	check(d.dollKind=="resent" and d.attack==9 and d.dollTargets==[foe.units[1].uid] and p.night==10,"awake usesrealhistory thennight9 beforefailed10 check")
	play(gs,"c25806",foe.units[0].uid);d=current(gs)
	check(d.attack==10 and d.hp==4 and d.dollTargets.size()==2,"awake currentnight10power andadditional actual binding")
	check(d.dollTargets[0]!=d.dollTargets[1],"additional binding picks distinct enemy")
	check(not gs.can_play_card(0,give(gs,"c25808"),foe.units[0].uid).ok,"awake cannotrepeat")
func test_nail_fire_ai() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1);var d:=spawn(gs,"substitute");p.night=3
	var hand_before: int=p.hand.size();var fire: int=p.energy;play(gs,"c25802",d.uid)
	check(d.hp==1 and p.hand.size()==hand_before+1 and p.energy==fire,"instant nail real3hit andnight3draw")
	check(gs.kw_usage(0,"instant").used,"nail consumes actualinstant allowance")
	gs=game();p=gs.player(0);foe=gs.player(1);d=spawn(gs,"substitute",str(foe.units[1].uid));foe.units[1].baseMaxHp=20;foe.units[1].maxHp=20;foe.units[1].hp=20
	var avatar: int=foe.avatarHp;play(gs,"c25804")
	check(d.hp==1 and foe.units[1].hp==14,"fire hits ownfront3 andenemy3 plus equalgrass3")
	check(foe.avatarHp==avatar and p.units[0].hp==4,"fire excludes avatars andownreserve")
	for id in ["c25801","c25802","c25803","c25804","c25805","c25806","c25807","c25808"]:
		gs=game();p=gs.player(0);foe=gs.player(1)
		if id in ["c25802","c25808"]: spawn(gs,"resent")
		give(gs,id)
		var best: Dictionary=AI._best_card(gs,0)
		check(best.ok,"AI legal candidate "+id)
		if best.ok:check(gs.can_play_card(0,best.hand,best.target).ok and gs.play_card(0,best.hand,best.target),"AI actual legal execution "+id)
		check(Content.card_def(id).get("verifiedRules",false) and not Content.card_def(id).get("verificationPending",[]).is_empty(),"native pending "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original PNG "+id)
	gs=game();d=spawn(gs);var before:=JSON.stringify(gs.snapshot());var marks:=Doll.unit_marks(gs,0,gs._unit_index_by_uid(0,d.uid))
	check(marks.size()==2 and JSON.stringify(gs.snapshot())==before,"binding inspector read-only")
func native_ui() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["choushizhinv","rulianshi","tianjingxia","zhen"],["fenghuanghuo","bingyong","xuenv","baizangzhu"],258);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.energy=80;side.levelUpUsed=true
			for u in side.units:u.level=3
		root.add_child(b);await create_timer(0.4).timeout
		var gs=b.gs;var p: Dictionary=gs.player(0);var foe: Dictionary=gs.player(1)
		hand(b,["c25807"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0,"native actualsummon targetmode")
		await click(b._unit_widget(str(p.units[0].uid)));await settled(b)
		check(b._pending_target_card==0 and current(gs).is_empty(),"native rejects ownbinding target")
		await click(b._unit_widget(str(foe.units[1].uid)));await settled(b)
		var d:=current(gs)
		check(not d.is_empty() and d.dollKind=="substitute" and d.dollTargets==[foe.units[1].uid],"native actual selectedenemy createsbound0/4")
		hand(b,["c25802"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(d.uid)).selected,"native nail real summon target")
		await click(b._unit_widget(str(foe.units[0].uid)));await settled(b)
		check(b._pending_target_card==0 and d.hp==4,"native nail rejects nonsummon no damage")
		await click(b._unit_widget(str(d.uid)));await settled(b)
		check(d.hp==1 and foe.units[1].hp==3,"native nail3 andequal3 copiedtoboundenemy")
		await click(b._unit_widget(str(d.uid)));await settled(b)
		if b._selected_attacker>=0:await click(b._unit_widget(str(d.uid)));await settled(b)
		check(texts(b).contains("替身草人") and texts(b).contains("兵俑") and texts(b).contains("等量"),"native realbinding readable in inspector")
		await capture("%d-doll-binding-inspector" % physical.x)
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	test_base_and_targets();test_reactions();test_unbinding_and_lifecycle();test_forms_and_night();test_nail_fire_ai()
	if not rules_only:await native_ui()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("DOLL checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
