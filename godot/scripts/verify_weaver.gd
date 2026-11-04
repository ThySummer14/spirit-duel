extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Weaver := preload("res://scripts/weaver_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("WEAVER_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["rulianshi","xiaosongwan","taohuayao","tiaotiaomeimei"],["yaodaoji","bingyong","xuenv","baizangzhu"],236)
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"weaver-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)
func snow(gs, owner: int = 0) -> Dictionary:
	var idx:=Weaver.live_snow(gs,owner)
	return {} if idx<0 else gs.player(owner).units[idx]
func event_count(gs, key: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==key).size()
func test_base_fusion() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==3 and u.passive_hooks.is_empty(),"exact base2/3, oldgrowth removed")
	check(not gs.can_play_card(0,give(gs,"c23601")).ok,"mourn illegal without summon")
	check(not gs.can_play_card(0,give(gs,"c23603")).ok,"revive illegal without real graveyard")
	var deck: int=p.deck.size(); play(gs,"c23602")
	var first:=snow(gs); var first_idx: int=gs._unit_index_by_uid(0,first.uid)
	check(first.attack==3 and first.maxHp==3 and first.hp==3 and first.front==1 and first.weaverFusionCount==0,"umbrella real3/3 frontline")
	check(p.deck.size()==deck and u.shield==0 and u.front==0,"umbrella no old fake draw/shield")
	check(not gs.can_basic_attack(0,first_idx).ok,"entry turn blocks normalattack")
	gs._damage_unit(0,first_idx,1,1,0); first.keywords=["lifesteal"]; first.shield=2; first.frozen=1
	var old_size: int=p.units.size(); play(gs,"c23602"); var second:=snow(gs)
	check(p.units.size()==old_size+1 and second.uid!=first.uid and first.removed and first.hp==0,"fusion creates actualnew stableindex; old remains tombstone")
	check(second.attack==6 and second.hp==5 and second.maxHp==6 and second.weaverFusionCount==1,"fusion adds currentHP and maxHP independently")
	check(second.shield==2 and second.frozen==1 and second.keywords.has("lifesteal"),"fusion inherits positive and negative status")
	check(Weaver.revive_candidates(gs,0).has(first_idx),"actual fusion material belongs eligible archive")
	check(not gs.can_basic_attack(0,gs._unit_index_by_uid(0,second.uid)).ok,"fusion resets currentturn ordinaryattack lock")
	second.frozen=0; var hp: int=gs.player(1).avatarHp; var fire: int=p.energy; play(gs,"c23601")
	check(gs.player(1).avatarHp==hp-7 and p.energy==fire,"mourn instant actually attacks with+1 through entrylock")
	check(second.attack==6 and second.hp==5 and second.shield==2 and not p.attackUsed,"mourn power/immunity scoped and ordinary quota untouched")
	check(gs.end_turn(0) and gs.end_turn(1),"actual turnsequence")
	p.levelUpUsed=true
	check(gs.can_basic_attack(0,gs._unit_index_by_uid(0,second.uid)).ok,"entrylock expires on actual later turn")
	gs=game(); p=gs.player(0); play(gs,"c23602"); first=snow(gs); first_idx=gs._unit_index_by_uid(0,first.uid)
	check(gs.VerifiedRules.Movement.move_to(gs,0,0,1),"real displacement")
	check(first.removed and first.hp==0 and not first.has("weaverGrave") and Weaver.revive_candidates(gs,0).is_empty(),"forcedmovement removes but never fakes corpse")
	play(gs,"rulianshi-zhixue"); check(snow(gs).attack==3,"legacy token entry now actualsummon, notdamage")
func test_knockout_form() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(u.hp==0 and u.knockout==2 and snow(gs).attack==3,"actual sourceKO summons truebody")
	check(not gs.can_play_card(0,give(gs,"c23602")).ok,"summonspells do not invent deadsource use")
	gs=game(); p=gs.player(0); u=p.units[0]; u.level=0; gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(snow(gs).is_empty(),"unactivated passive cannot summon")
	gs=game(); p=gs.player(0); u=p.units[0]; u.baseRulesSuppressed=true; gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(snow(gs).is_empty(),"paper-suppressed source cannot summon")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23604")
	check(u.attack==3 and u.maxHp==5 and u.shield==0 and u.formRules.weaverCoffinBearer,"coffinbearer exact3/5 nofake entryshield")
	gs._knockout_unit(p.units[1]); gs._resolve_resolution_stack()
	check(snow(gs).is_empty() and u.attack==3,"reserveallyKO neither summons nor buffs")
	gs.VerifiedRules.Movement.move_to(gs,0,2,1); gs._knockout_unit(p.units[2]); gs._resolve_resolution_stack()
	check(snow(gs).attack==3 and u.attack==3 and u.hp==5,"actualfront non-summonedallydeath createsbody, notselfbuff")
	var idx: int=gs._unit_index_by_uid(0,snow(gs).uid); gs._damage_unit(0,idx,100,1,0); gs._resolve_resolution_stack()
	check(snow(gs).is_empty(),"summonedfrontdeath cannot triggercoffinbearer")
	gs.VerifiedRules.Movement.move_to(gs,0,0,1); gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(snow(gs).attack==6 and snow(gs).weaverFusionCount==1,"self-frontdeath triggers base plusattachedform separately")
	gs=game(); p=gs.player(0); play(gs,"c23604"); gs._knockout_unit(p.units[0]); gs._resolve_resolution_stack()
	check(snow(gs).attack==3,"sourcebackrowdeath base only")
	gs=game(); p=gs.player(0); play(gs,"c23604"); p.units[1].front=1; gs._damage_unit(0,1,999,1,0); gs._resolve_resolution_stack()
	check(snow(gs).attack==3,"lethal damage preserves dyingfront observation at HPzero")
func test_awake_coffin() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	play(gs,"c23605"); check(u.awakened and u.attack==2 and u.maxHp==3 and snow(gs).attack==4 and snow(gs).maxHp==4,"awake summons then+1/+1 onlysnow")
	var first:=snow(gs); play(gs,"c23605")
	check(p.weaverPermanent==2 and snow(gs).attack==9 and snow(gs).hp==9,"repeatedawake stacks permanent after realfusion")
	check(first.weaverGrave.attack==5,"permanentgrowth updates grave original for realfuture revival")
	var idx: int=gs._unit_index_by_uid(0,snow(gs).uid); gs._damage_unit(0,idx,999,1,0); gs._resolve_resolution_stack(); play(gs,"c23602")
	check(snow(gs).attack==5 and snow(gs).hp==5 and snow(gs).weaverFusionCount==0,"newbody afterdeath getsboth permanentbonus, newfusionhistory")
	gs=game(); p=gs.player(0); p.avatarHp=17; play(gs,"c23608")
	check(snow(gs).attack==17 and snow(gs).hp==17 and p.units[0].attack==2 and p.units[0].hp==3,"coffin snapshots actualplayerHP withoutfake sourcebuff")
	p.avatarHp=8; play(gs,"c23608"); check(snow(gs).attack==25 and snow(gs).hp==25 and snow(gs).weaverFusionCount==1,"nextcoffin snapshots changedHP and truefuses")
	gs=game(); p=gs.player(0); play(gs,"c23605"); p.avatarHp=11; play(gs,"c23608")
	check(snow(gs).attack==16 and snow(gs).maxHp==16,"coffin receives matchlong +1/+1 thenfuses existing4/4")
func test_revive() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); p.avatarHp=21; play(gs,"c23608")
	var first:=snow(gs); var uid: String=first.uid; var idx: int=gs._unit_index_by_uid(0,uid); var size: int=p.units.size()
	gs._damage_unit(0,idx,999,1,0); gs._resolve_resolution_stack()
	check(first.removed and first.hp==0 and first.weaverReviveReason=="knockout" and first.weaverGrave.attack==21,"realKO archives actualbody")
	check(gs.can_play_card(0,give(gs,"c23603")).ok,"powder legal from realdeadbody")
	play(gs,"c23603")
	check(p.units.size()==size and first.uid==uid and first.hp==21 and first.front==1 and not first.removed,"revival restores identicalobject+index, noforgedcopy")
	check(not first.has("weaverGrave") and not gs.can_play_card(0,give(gs,"c23603")).ok,"livingbody ceases eligible, ordinarydead unitsnotcandidates")
	gs._damage_unit(0,idx,999,1,0); gs._resolve_resolution_stack(); play(gs,"c23602"); play(gs,"c23603")
	check(snow(gs).attack==24 and snow(gs).hp==24 and snow(gs).weaverFusionCount==1 and first.removed,"actual revivedbody fuses with current3/3")
	gs=game(); p=gs.player(0)
	var pine_idx: int=gs.VerifiedRules.Pine.summon(gs,0,1); var pine: Dictionary=p.units[pine_idx]; var pine_uid: String=pine.uid
	gs._damage_unit(0,pine_idx,999,1,0); gs._resolve_resolution_stack(); play(gs,"c23602"); var weak:=snow(gs)
	var weak_idx: int=gs._unit_index_by_uid(0,weak.uid); gs._damage_unit(0,weak_idx,999,1,0); gs._resolve_resolution_stack()
	var pool:=Weaver.revive_candidates(gs,0)
	check(pool==[pine_idx],"revive compares actualfallen summon strength acrossroles4>3")
	play(gs,"c23603")
	check(pine.hp==4 and pine.front==1 and pine.uid==pine_uid and not pine.removed,"powder reallyrevives otherrole samepine instance")
	gs.VerifiedRules.Movement.move_to(gs,0,0,1)
	check(pine.removed and not Weaver.revive_candidates(gs,0).has(pine_idx),"forcedremoval afterrevival doesnot inherit oldKO eligibility")
	gs=game(); p=gs.player(0); play(gs,"c23602"); first=snow(gs); idx=gs._unit_index_by_uid(0,first.uid); gs._damage_unit(0,idx,999,1,0); gs._resolve_resolution_stack(); play(gs,"c23602"); var second:=snow(gs); var second_idx: int=gs._unit_index_by_uid(0,second.uid); gs._damage_unit(0,second_idx,999,1,0); gs._resolve_resolution_stack()
	check(Weaver.revive_candidates(gs,0).size()==2,"equalhighest retains both actualdead candidates")
	play(gs,"c23603"); check(not snow(gs).is_empty() and (first.hp>0 or second.hp>0),"equalhighest resolves onevalid corpse randomly")
func test_exile_funeral() -> void:
	var gs:=game(); var foe: Dictionary=gs.player(1); var p: Dictionary=gs.player(0)
	foe.units[2].keywords=["veil"]; var i:=give(gs,"c23606"); var c: Dictionary=gs.hand_card_def(0,i)
	check(gs.valid_targets(0,c).has(foe.units[0].uid) and not gs.valid_targets(0,c).has(foe.units[2].uid) and not gs.valid_targets(0,c).has("avatar-1"),"exile actualreserve target, veil andavatar excluded")
	check(not gs.can_play_card(0,i,p.units[1].uid).ok and not gs.can_play_card(0,i,foe.units[2].uid).ok,"illegal directtargets rejected beforepayment")
	gs._grow_unit(foe.units[1],0,50); foe.units[1].shield=99; foe.units[1].unyielding=true; var deck: int=foe.deck.size(); var hp: int=foe.avatarHp
	check(gs.play_card(0,i,foe.units[1].uid),"actual exile highHP armoredunyielding")
	check(foe.units[1].hp==0 and snow(gs,1).attack==3 and foe.deck.size()==deck-1 and foe.avatarHp==hp,"harddestroy ignoresarmor/HP/unying andgives trueenemy summonplusdraw")
	check(snow(gs).is_empty(),"exile compensation doesnot go to caster")
	gs=game(); foe=gs.player(1); p=gs.player(0); gs.VerifiedRules.Xuenv.summon_wall(gs,1,2); var wall: Dictionary=foe.units.back(); play(gs,"c23606",foe.units[0].uid)
	check(wall.removed and wall.hp==0 and snow(gs,1).front==1,"compensatingenemy summondisplaces existingdifferent token")
	gs=game(); foe=gs.player(1); p=gs.player(0)
	for unit in foe.units: gs._grow_unit(unit,0,30)
	var hp_before: int=foe.units[0].hp; hp=foe.avatarHp; play(gs,"c23607")
	check(foe.units[0].hp==hp_before-2 and foe.avatarHp==hp-2 and event_count(gs,"weaver-funeral-wave")==1,"funeral nofusion exactone separate2AOEwave")
	play(gs,"c23607")
	check(foe.units[0].hp==hp_before-6 and foe.avatarHp==hp-6 and event_count(gs,"weaver-funeral-wave")==3,"secondfuneral fuses once anddoes two real2waves")
	play(gs,"c23607")
	check(foe.units[0].hp==hp_before-12 and foe.avatarHp==hp-12 and event_count(gs,"weaver-funeral-wave")==6,"thirdfuneral fusion2 doesthree actualwaves")
	check(snow(gs).weaverFusionCount==2,"AOE countuses actual currenttoken history")
	var snap:=JSON.stringify(gs.snapshot()); var marks:=Weaver.unit_marks(gs,0,gs._unit_index_by_uid(0,snow(gs).uid))
	check(marks[0].contains("2") and JSON.stringify(gs.snapshot())==snap,"livefusion inspector read-only")
func mixed() -> GS:
	var gs:=GS.create(["rulianshi","xiaosongwan","yanmo","xuenv"],["yaodaoji","bingyong","xuenv","baizangzhu"],236)
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs
func test_cross_fusion() -> void:
	var gs:=mixed(); var p: Dictionary=gs.player(0)
	var pine_idx: int=gs.VerifiedRules.Pine.summon(gs,0,1); var incoming: Dictionary=p.units[pine_idx]
	gs.VerifiedRules.Pine.summon(gs,0,1); check(incoming.attack==8 and incoming.maxHp==8,"fixture actual8/8 fusedpine")
	incoming.keywords=["lifesteal"]; incoming.shield=2
	gs._damage_unit(0,pine_idx,999,1,0); gs._resolve_resolution_stack()
	var living_idx: int=gs.VerifiedRules.Pine.summon(gs,0,1); var living: Dictionary=p.units[living_idx]; var living_uid: String=living.uid
	play(gs,"c23603")
	check(living.uid==living_uid and living.attack==12 and living.maxHp==12 and living.hp==12,"powder8/8pine usesexisting fusionentry with actualbody, notdefault+4")
	check(incoming.removed and incoming.hp==0 and living.front==1 and p.units.filter(func(u):return u.get("pineSummon",false) and int(u.hp)>0).size()==1,"revivedpinefusion leaves onebody and archives trueoriginal")
	check(living.keywords.has("lifesteal"),"revivedpinefusion inherits material keyword")
	gs= mixed(); p=gs.player(0); play(gs,"c23003"); play(gs,"c23602")
	check(snow(gs).attack==4 and snow(gs).maxHp==4,"mirror fresh3/3snow aura once")
	play(gs,"c23602"); check(snow(gs).attack==7 and snow(gs).maxHp==7,"mirror secondsnow fusion aura once")
	play(gs,"c23602"); check(snow(gs).attack==10 and snow(gs).maxHp==10,"mirror thirdsnow noaccumulatedaura")
	var big:=snow(gs); var big_idx: int=gs._unit_index_by_uid(0,big.uid); gs._damage_unit(0,big_idx,999,1,0); gs._resolve_resolution_stack(); play(gs,"c23602"); play(gs,"c23603")
	check(snow(gs).attack==13 and snow(gs).maxHp==13 and snow(gs).hp==13,"mirror revived9body+3body has oneaura, not14")
	gs.VerifiedRules.Enma.refresh(gs); gs.VerifiedRules.Enma.refresh(gs)
	check(snow(gs).attack==13 and snow(gs).hp==13,"mirror repeatedrefresh never changes mergedbody")
	gs=mixed(); p=gs.player(0); play(gs,"c23003"); pine_idx=gs.VerifiedRules.Pine.summon(gs,0,1); incoming=p.units[pine_idx]; gs.VerifiedRules.Pine.summon(gs,0,1)
	check(incoming.attack==9 and incoming.maxHp==9,"mirror8/8pine plusoneaura")
	gs._damage_unit(0,pine_idx,999,1,0); gs._resolve_resolution_stack(); living_idx=gs.VerifiedRules.Pine.summon(gs,0,1); living=p.units[living_idx]; play(gs,"c23603")
	check(living.attack==13 and living.maxHp==13 and living.hp==13,"mirror revived8/8pine plus4/4 has exactlyoneaura")
	gs=mixed(); p=gs.player(0); play(gs,"c23003"); play(gs,"c23007")
	var ghost_idx: int=gs.VerifiedRules.Enma.summon_ghost(gs,0,2); var ghost: Dictionary=p.units[ghost_idx]; var ghost_uid: String=ghost.uid
	ghost.enmaUnyielding=false; gs._damage_unit(0,ghost_idx,999,1,0); gs._resolve_resolution_stack()
	check(ghost.removed and ghost.get("enmaDeathRecorded",false) and ghost.get("enmaRemovalRecorded",false),"actualghostKO records eachdeath/removalflag")
	play(gs,"c23603")
	check(ghost.hp==ghost.maxHp and ghost.uid==ghost_uid and not ghost.get("enmaDeathRecorded",false) and not ghost.get("enmaRemovalRecorded",false),"powder revives sameghost and resetsdeath/removal guards")
	check(ghost.get("enmaUnyielding",false),"revivedghost re-evaluates liveMercy aura")
	ghost.enmaUnyielding=false; gs._damage_unit(0,ghost_idx,999,1,0); gs._resolve_resolution_stack(); var old_idx: int=gs.VerifiedRules.Enma.summon_ghost(gs,0,2); var old: Dictionary=p.units[old_idx]
	play(gs,"c23603"); var merged: Dictionary=gs.VerifiedRules.Enma.ghost(gs,0)
	check(merged.attack==11 and merged.maxHp==3 and merged.hp==3,"powder realghost5/1+5/1 fusion plusone mirror")
	check(merged.uid!=ghost_uid and merged.uid!=old.uid and ghost.removed and old.removed,"ghost resurrection fusion createsactualnew instance, nofakecover")
	check(merged.get("enmaUnyielding",false),"ghostfusion retains/re-applies actualMercy")
func ai_art() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); give(gs,"c23601"); give(gs,"c23603"); give(gs,"c23602"); var best:=AI._best_card(gs,0)
	check(best.ok and best.card_id=="c23602" and gs.play_card(0,best.hand,best.target),"AI actuallyskips illegal mourn/revive andsummons")
	p.hand.clear(); give(gs,"c23601"); best=AI._best_card(gs,0)
	check(best.ok and best.card_id=="c23601" and gs.play_card(0,best.hand,best.target),"AI actualforcedsummonattack through normalattacklock")
	gs=game(); gs.player(1).units[2].keywords=["veil"]; give(gs,"c23606"); best=AI._best_card(gs,0)
	check(best.ok and best.target!=gs.player(1).units[2].uid and gs.play_card(0,best.hand,best.target),"AI legallyselects andexecutes enemyharddestroy")
	for id in ["c23601","c23602","c23603","c23604","c23605","c23606","c23607","c23608"]:
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalart "+id)
		check(Content.card_def(id).verifiedRules and not Content.card_def(id).verificationPending.is_empty(),"native rule remains pending "+id)
func native_ui() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["rulianshi","xiaosongwan","taohuayao","tiaotiaomeimei"],["yaodaoji","bingyong","xuenv","baizangzhu"],236); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=80; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		hand(b,["c23601","c23602","c23603"]); await settled(b)
		check(not b._hand_row.get_child(0).playable and not b._hand_row.get_child(2).playable,"native hand disables nofrontsummon andnocorpse")
		await click(b._hand_row.get_child(1)); await settled(b)
		var first:=snow(gs); check(first.attack==3 and first.hp==3,"native mouse actualumbrella summons3/3")
		await click(b._unit_widget(str(first.uid))); await settled(b)
		check(b._selected_attacker<0 and texts(b).contains("融合"),"native entrylocked token opensinspection withfusion info")
		if physical.x==1280: await capture("01-weaver-fusion-inspector")
		escape(); await settled(b); hand(b,["c23601"]); var hp: int=foe.avatarHp
		await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(foe.avatarHp==hp-4 and first.hp==3,"native mourn really+1free attack andimmunity")
		hand(b,["c23606"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[1].uid)).selected,"native exile exposesactual reserve targets")
		var fire: int=p.energy; await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"native illegalally spendsnothing")
		if physical.x==1600: await capture("02-weaver-exile-real-targets")
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(foe.units[1].hp==0 and not snow(gs,1).is_empty(),"native selectedreserve harddestroy andrealenemycompensation")
		var first_uid: String=first.uid; var first_idx: int=gs._unit_index_by_uid(0,first_uid); gs._damage_unit(0,first_idx,999,1,0); gs._resolve_resolution_stack(); hand(b,["c23603"]); await settled(b)
		check(b._hand_row.get_child(0).playable,"native powder enabledfor actualcorpse")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(first.hp==3 and first.uid==first_uid and not first.removed,"native powder revives originalboard instance")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	test_base_fusion(); test_knockout_form(); test_awake_coffin(); test_revive(); test_exile_funeral(); test_cross_fusion(); ai_art()
	if not rules_only: await native_ui()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("WEAVER_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures==0 else 1)
