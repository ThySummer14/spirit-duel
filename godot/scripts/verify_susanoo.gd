extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Susanoo := preload("res://scripts/susanoo_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("SUSANOO_FAIL ",detail)
func game(own: Array=["xuzuozhinan","shuweng","shantong","taohuayao"]) -> GS:
	var gs:=GS.create(own,["bingyong","fenghuanghuo","xuenv","baizangzhu"],281)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.rule_events.clear(); return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"susanoo-test-%d"%gs.next_card_id,"definitionId":id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null) -> void:
	var idx:=give(gs,id); var reason:Dictionary=gs.can_play_card(0,idx,target)
	check(gs.play_card(0,idx,target),"actualuse "+id+" "+str(reason))
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func knock(gs,owner: int,idx: int) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0); gs._resolve_resolution_stack()
func attack_and_thunder() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]; var face:int=foe.avatarHp
	check(u.attack==2 and u.maxHp==5 and u.passive_hooks.is_empty(),"original2/5withnolegacycombatresolvedfakegrowth")
	check(gs.basic_attack(0,0) and u.attack==2 and foe.avatarHp==face-2,"avatarattackcannottriggerunitattackgrowth")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; foe.units[0].front=1; foe.units[0].hp=1; face=foe.avatarHp
	check(gs.basic_attack(0,0) and u.attack==3 and foe.units[0].hp==0 and foe.avatarHp==face-2,"actualtargetunitgrowthbeforepowerandconditionaloneHPpierce")
	check(events(gs,"susanoo-attack-growth").size()==1,"onegrowthperattacknotperdamageorcounter")
	knock(gs,0,0); check(u.attack==2 and not u.has("susanooOrdinaryPower"),"ordinaryattackgrowthclearsKO")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; foe.units[0].front=1; face=foe.avatarHp; var hp:int=foe.units[0].hp
	gs.basic_attack(0,0); check(u.attack==3 and foe.units[0].hp==hp-3 and foe.avatarHp==face,"largerHPtargetreceivesgrowthwithoutinventedpierce")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; foe.units[0].front=1; foe.units[1].hp=1; foe.units[1].foxVeil=true; var idx:=give(gs,"c28101"); var card:Dictionary=gs.hand_card_def(0,idx); var ts:Array=gs.valid_targets(0,card); var fire:int=p.energy; hp=u.hp; face=foe.avatarHp
	check(ts==[foe.units[1].uid] and card.cost==1 and card.value==0,"originalthunderonlyoneHPunitpursuitincludingveiledreserveandprintedonefire")
	check(not gs.play_card(0,idx,foe.units[0].uid) and not gs.play_card(0,idx,"avatar-1") and p.energy==fire,"invalidHPandavatartargetcannotpay")
	check(gs.play_card(0,idx,foe.units[1].uid) and foe.units[1].hp==0 and foe.units[0].hp==foe.units[0].maxHp,"actualpursuitselectsreserveinsteadfront")
	check(u.hp==hp and u.attack==3 and foe.avatarHp==face-2 and p.energy==fire,"printedzeroattackbonusandrealcombatimmunityplusfirstinstantallowance")
	gs=game(); foe=gs.player(1); foe.units[0].front=1; gs._grow_unit(foe.units[0],20,0); foe.units[0].hp=1; hp=gs.player(0).units[0].hp
	play(gs,"c28101",foe.units[0].uid); check(gs.player(0).units[0].hp==hp,"thunderreallyimmuneshighcounterdamage")
func tomb_and_domain() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]; var target:Dictionary=foe.units[1]; var original_name:String=target.name; target.hp=2; foe.units[0].front=1
	play(gs,"c28102",target.uid)
	check(Susanoo.tomb(target) and target.attack==0 and target.hp==1 and target.maxHp==1 and target.name=="雷冢","actualpursuitkillreplaceswithreal0/1tomb")
	check(target.uid==target.susanooOriginal.uid and target.susanooOriginal.name==original_name and target.susanooOriginal.hp==0,"replacementretainsactualoriginalidentityanddeadbody")
	check(target.cannotAttack and target.baseRulesSuppressed and target.passive_hooks.is_empty(),"tombcannotattackanddoesnotborroworiginalabilities")
	check(p.destroyedUnits==1 and events(gs,"combat-complete").back().kills==1,"transformationstillcountsasactualkill")
	Susanoo.end_turn(gs,0); check(Susanoo.tomb(target),"attackersendturncannotprematurelyrestoreopponent")
	gs.current_player=1; var enemy_card:String=Content.cards_for_unit(str(target.id))[0].id; idx_give_and_check_block(gs,enemy_card,1,target.uid)
	check(not gs.can_basic_attack(1,1).ok and not gs.basic_attack(1,1),"actualtombbasicattackillegal")
	check(gs.end_turn(1) and not Susanoo.tomb(target) and target.name==original_name and target.hp==1 and target.knockout==0,"actualownersendrestoresoriginalrevivedatoneHP")
	check(not target.get("cannotAttack",false) and not target.get("baseRulesSuppressed",false),"restorationreenablesoriginalabilitiesandcards")
	gs=game(); p=gs.player(0); foe=gs.player(1); target=foe.units[0]; target.front=1; target.hp=1; play(gs,"c28102",target.uid)
	check(Susanoo.tomb(target),"firstkillcreatesfronttomb")
	gs._damage_unit(1,0,1,0,1); gs._resolve_resolution_stack()
	check(not Susanoo.tomb(target) and target.hp==0 and target.knockout==2,"killingtombagainrestoresoriginaltoordinaryKOwithoutretransform")
	Susanoo.end_turn(gs,1); check(target.hp==0,"destroyedtombdoesnotleaveghostendturnrevival")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; var power:int=u.attack; var max_hp:int=u.maxHp
	play(gs,"c28103")
	check(p.realms.size()==1 and p.realms[0].hp==5 and u.attack==power and u.maxHp==max_hp and u.shield==0,"domainisreal5durwithoutfakebodybufforblanketarmor")
	check(gs.kw_usage(0,"encourage").attack==1 and gs.kw_usage(0,"encourage").shield==1,"domainentrygivesrealshared1/1encourage")
	foe.units[0].front=1; foe.units[0].hp=2; gs.basic_attack(0,0)
	check(Susanoo.tomb(foe.units[0]) and u.attack==3 and u.shield>=0,"domaintransformsonlyrealSusanoobasicdeploymentkill")
	u.inspired=true; gs.basic_attack(0,0)
	check(Susanoo.tomb(foe.units[0]) and p.destroyedUnits==2,"domaincanreplacekilledtombagainwithoutcardrestriction")
	gs=game(); foe=gs.player(1); play(gs,"c28103"); foe.units[0].hp=1; play(gs,"c28101",foe.units[0].uid)
	check(foe.units[0].hp==0 and not Susanoo.tomb(foe.units[0]),"domaincannotpretendmanualcombatcardisanordinarydeployment")
	gs=game(); foe=gs.player(1); play(gs,"c28103"); gs.player(0).realms[0].hp=0; foe.units[0].hp=1; foe.units[0].front=1; gs.basic_attack(0,0)
	check(foe.units[0].hp==0 and not Susanoo.tomb(foe.units[0]),"destroyeddomaincannottransform")
func idx_give_and_check_block(gs,id: String,owner: int,_uid: String) -> void:
	var idx:=give(gs,id,owner); var card:Dictionary=gs.hand_card_def(owner,idx)
	check(not gs.can_play_card(owner,idx,null if card.target=="auto" else gs.player(0).units[0].uid).ok,"tombcannotuseanyoriginalshikigamicard")
func lethal_guard_awakening() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]; var target:Dictionary=foe.units[0]; target.front=1; gs._grow_unit(target,0,30)
	play(gs,"c28104")
	check(Susanoo.tomb(target) and u.attack==3,"printedlethalreallykillslargeHPenemyandcreates0/1insteadfakeextra3damage")
	check(u.shield==1,"lethalgrantsprinted2armorwithactualcounterdamage")
	gs=game(); foe=gs.player(1); foe.units[0].front=1; foe.units[0].barrier=true; play(gs,"c28104")
	check(not Susanoo.tomb(foe.units[0]) and foe.units[0].hp==foe.units[0].maxHp,"barrierzeroactualdamagerespectslethalcondition")
	gs=game(); foe=gs.player(1); foe.units[0].front=1; foe.units[0].shield=99; play(gs,"c28104")
	check(not Susanoo.tomb(foe.units[0]) and foe.units[0].hp>0,"fullarmorpreventslethalandtransform")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; knock(gs,0,0); var idx:=give(gs,"c28105"); var stamp:=JSON.stringify(gs.snapshot())
	check(not gs.hand_card_def(0,idx).allowKnockedSource and not gs.can_play_card(0,idx).ok and JSON.stringify(gs.snapshot())==stamp,"KOguardillegalwithoutactualoneHPenemyandquerypure")
	foe.units[1].hp=1; var card:Dictionary=gs.hand_card_def(0,idx)
	check(card.enhanced and card.allowKnockedSource,"guardenhancementdynamicallyactivatesforreserveoneHPenemy")
	check(gs.play_card(0,idx) and u.hp==7 and u.maxHp==7 and u.attack==4 and u.knockout==0,"conditionalguardreallyrevivestheninstallsprinted4/7")
	gs=game(); u=gs.player(0).units[0]; u.hp=2; play(gs,"c28105"); check(u.attack==4 and u.hp==7 and u.maxHp==7,"livingguardlegallyinstalls4/7withoutinventedunconditionalKOaccess")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c28106")
	check(u.awakened and u.attack==3 and u.maxHp==6 and p.hand.size()==1 and p.hand[0].definitionId=="c28101","awakeninggeneratesrealusablethunderthenpermanent1/1")
	check(gs.VerifiedRules.Combat.has(u,"pierce") and not gs.can_play_card(0,give(gs,"c28106")).ok,"awakeninggrantsactualpersistentpierceandcannotrepeat")
	foe=gs.player(1); foe.units[0].front=1; foe.units[0].hp=2; var face:int=foe.avatarHp; gs.basic_attack(0,0)
	check(u.attack==4 and foe.avatarHp==face-2,"awakepiercesnononeHPenemywhilegrowingonlyonce")
	knock(gs,0,0); check(u.attack==3 and u.maxHp==6 and u.awakened,"KOremovesordinarygrowthandretainspermanentawakening1/1")
func cut_and_duel() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]; var selected:Dictionary=foe.units[2]; var face:int=foe.avatarHp
	for x in foe.units: x.hp=3
	play(gs,"c28107",selected.uid)
	var hits:=events(gs,"susanoo-cut-damage")
	check(hits.size()==2 and hits[0].target==selected.uid and hits[1].target!=selected.uid,"cutuseschosenenemythenrandomdistinctothernotfixedfront")
	check(events(gs,"susanoo-tomb-created").size()==2 and u.attack==2,"cutdamagekillsreallytransformbutdonotpretenddamageisanattackgrowth")
	check(foe.avatarHp==face-2 and u.front==1 and u.shield==1,"cutthenperformsactualnormalcombatwithprinted1armorandzeroattackbonus")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; play(gs,"c28106"); p.hand.clear()
	for x in foe.units: x.hp=1
	face=foe.avatarHp; play(gs,"c28107",foe.units[2].uid)
	check(foe.avatarHp==face-7 and u.attack==3,"awakecutnormaldamagepierces2eachandthenactual3poweravatarattack")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[0].front=1; foe.units[1].hp=2; foe.units[2].hp=3; foe.units[3].hp=4; var fire:int=p.energy
	play(gs,"c28108"); u=p.units[0]
	check(u.form.cardId=="c28108" and u.maxHp==10 and u.attack==5,"SSRprinted4/10andrealentryattackgrowsbeforehit")
	check(events(gs,"susanoo-lowest-attack").size()==1 and events(gs,"susanoo-lowest-attack")[0].target==foe.units[1].uid,"entryrandomlyattacksactuallowestHPreserveenemy")
	check(foe.units[1].hp==1 and u.hp>0 and events(gs,"susanoo-duel-unyielding").size()==1,"bothactualcombatantshaveoneshotunyieldingduringduel")
	check(not p.attackUsed and p.energy==fire-1 and not u.has("susanooCombatUnyielding") and not foe.units[1].has("susanooCombatUnyielding"),"commandedSSRattackhasnoextraordinaryactionpaymentandfloorscannotleak")
	face=foe.avatarHp; gs._begin_turn(0); gs._resolve_resolution_stack()
	check(foe.units[1].hp==0 and foe.avatarHp==face-5 and u.attack==6,"realturnstartattacksoneHPlowesttargetandunyieldingcannotprotectatone")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; gs._install_form(0,0,Content.card_def("c28108"),{"attack":4,"hp":10,"setBase":true}); gs.resolution_stack.clear(); u.front=1; foe.units[0].hp=3; gs._grow_unit(foe.units[0],20,0); gs.current_player=1
	gs.basic_attack(1,0)
	check(u.hp==1 and foe.units[0].hp==1 and u.attack==4,"defendingSSRgrantsbothunyieldingwithoutdefenderattackgrowth")
	check(not u.has("susanooCombatUnyielding") and not foe.units[0].has("susanooCombatUnyielding"),"defensiveduelcleansbothfloorlifetimes")
	gs._damage_unit(0,0,1,1,1); check(u.hp==0,"outsidecombatsubsequentdamageisnotpermanentlyprevented")
	gs=game(); foe=gs.player(1)
	for i in foe.units.size():knock(gs,1,i)
	face=foe.avatarHp; play(gs,"c28108"); check(events(gs,"susanoo-lowest-attack").is_empty() and foe.avatarHp==face,"SSRwithnoenemyunitcannotinventavatarattack")
func lifecycle_and_feedback() -> void:
	var gs:=game(); var foe:Dictionary=gs.player(1); var target:Dictionary=foe.units[1]
	target.hp=1; target.awakened=true; target.abilityCountdown={"remaining":1,"reset":3}; target.susanooTombDamage=true; target.susanooDomainStrike=true
	play(gs,"c28102",target.uid)
	check(Susanoo.tomb(target) and not target.has("abilityCountdown"),"tombdoesnotcontinueoriginalabilitycountdown")
	Susanoo.end_turn(gs,1)
	check(target.hp==1 and target.awakened and target.abilityCountdown.remaining==3,"actualoriginalawakeninganddeathresetcountdownreturnonrevival")
	check(not target.has("susanooTombDamage") and not target.has("susanooDomainStrike"),"interruptedstrikescopescannotpersistthroughreplacementrevival")
	gs=game(); foe=gs.player(1); var chosen:Dictionary=foe.units[2]
	play(gs,"c28107",chosen.uid)
	var cues:=events(gs,"damage-resolved").filter(func(e):return e.get("card",{}).get("id")=="c28107")
	check(cues.size()==2 and cues[0].target==chosen.uid and cues[1].target!=chosen.uid,"bothrealcutdamageeventsreachsharedpresentationwithdistincttargets")
	gs=game(); var p:Dictionary=gs.player(0)
	for i in 12:give(gs,"c28101")
	Susanoo.put_thunder(gs,0); check(p.hand.size()==12 and events(gs,"susanoo-thunder-generated")[0].burned,"generatedthunderobeyshandcap")
func ai_and_boundaries() -> void:
	for n in range(1,9):
		var gs:=game(); var id:="c281%02d"%n; gs.player(1).units[1].hp=1; give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualoriginal "+id)
		check(gs.pending_choice.is_empty() and Content.card_def(id).cost==1 and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalcostandfullPNG "+id)
	var gs:=game(); var p:Dictionary=gs.player(0); knock(gs,0,0); gs.player(1).units[1].hp=1; give(gs,"c28105"); var best:=AI._best_card(gs,0)
	check(best.ok and gs.play_card(0,best.hand,best.target) and p.units[0].hp==7,"AIcanactuallyuseenhancedguardfromKO")
	gs=game(); p=gs.player(0); give(gs,"c28101"); check(not AI._best_card(gs,0).ok,"AIrejectsthunderwhenalltargetsaboveoneHP")
	var stamp:=JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0); gs.valid_targets(0,gs.hand_card_def(0,0)); gs.can_play_card(0,0); check(JSON.stringify(gs.snapshot())==stamp,"targetenhancementandcostqueriesdonotmutatecombatstate")
	gs=game(); p=gs.player(0); p.nullifyNextCardTurn=gs.turn_counter; play(gs,"c28106"); check(not p.units[0].awakened and p.hand.is_empty(),"counteredawakeningcannotgeneratecardorgrow")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["xuzuozhinan","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],281); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for x in side.units: x.level=3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs=b.gs; var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]; foe.units[0].front=1; foe.units[1].hp=1
		hand(b,["c28101"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[1].uid)).selected and not b._unit_widget(str(foe.units[0].uid)).selected,"nativethunderhighlightsoneHPreserveonly")
		var fire:int=p.energy; await click(b._unit_widget(str(foe.units[0].uid))); await settled(b); check(p.energy==fire and b._pending_target_card==0,"nativeinvalidHPtargetcannotpay")
		await capture("%d-01-one-hp-pursuit"%physical.x)
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b); check(foe.units[1].hp==0 and u.hp==5,"nativeactualpursuitcombatandimmunity")
		foe.units[2].hp=2; hand(b,["c28102"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(Susanoo.tomb(foe.units[2]) and foe.units[2].hp==1 and foe.units[2].name=="雷冢","nativeactualtombbodyappearsafterselectedkill")
		await capture("%d-02-real-thunder-tomb"%physical.x)
		knock(gs,0,0); hand(b,["c28105"]); await settled(b); check(b._hand_row.get_child(0).data.enhanced and b._hand_row.get_child(0).data.allowKnockedSource,"nativeguardshowsdynamicKOenhancementfromactualtomb")
		await click(b._hand_row.get_child(0)); await settled(b); check(u.hp==7 and u.attack==4 and u.form.cardId=="c28105","nativeactualenhancedguardrevives4/7")
		await capture("%d-03-enhanced-guard"%physical.x)
		foe.units[1].hp=1; hand(b,["c28108"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(u.form.cardId=="c28108" and u.maxHp==10 and events(gs,"susanoo-lowest-attack").size()==1,"nativeSSRentryreallyperformsautomaticlowestattack")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	attack_and_thunder(); tomb_and_domain(); lethal_guard_awakening(); cut_and_duel(); lifecycle_and_feedback(); ai_and_boundaries()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("SUSANOO_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]); quit(0 if failures==0 else 1)
