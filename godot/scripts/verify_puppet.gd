extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Puppet := preload("res://scripts/puppet_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("PUPPET_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["kuileishi","yaodaoji","taohuayao","shantu"],["yaodaoji","bingyong","xuenv","baizangzhu"],231)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true;p.avatarArmor=0;p.avatarHp=500
		for u in p.units:u.level=3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"puppet-fixture-%d"%gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner)),"actual handplay "+id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func base_and_fusion() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var f: Dictionary=gs.player(1);var u: Dictionary=p.units[0]
	check(u.attack==3 and u.maxHp==3 and u.passive_hooks.is_empty(),"exactbase3/3 nohistoricaldraworgrowth")
	var hp: int=f.avatarHp;var deck: int=p.deck.size()
	play(gs,"c23102");check(u.attack==4 and u.maxHp==4 and u.hp==4,"initial1/1formplusconditional3/3")
	check(f.avatarHp==hp and p.deck.size()==deck and events(gs,"puppet-fusion-ability").is_empty(),"firstformneitherfusionnorprojectile")
	var old: String=u.form.puppetInstance.instanceId
	gs._damage_unit(0,0,2,1,0);u.armorBreak=2;u.barrier=true;u.keywords=["veil"];gs._grow_unit(u,2,1)
	var damaged: int=u.maxHp-u.hp;var power: int=u.attack
	play(gs,"c23104")
	check(u.attack==power+2 and u.maxHp==7 and u.hp==7-damaged,"fusiononlyaddsprinted2/2andpreservesdamage")
	check(u.armorBreak==2 and u.barrier and u.keywords.has("veil") and u.attackBonus==2,"fusionpreservesallattachedunitstatesandgrowth")
	check(u.form.puppetInstance.instanceId!=old and p.get("puppetRemoved",[]).is_empty(),"newrealcarrierabsorbsoldwithoutremovedevent")
	check(f.avatarHp==hp-3 and p.deck.size()==deck-1,"fusionrunsinheritedprojectileandnewdrawonceeach")
	deck=p.deck.size();hp=f.avatarHp;play(gs,"c23104")
	check(p.deck.size()==deck-1 and f.avatarHp==hp-3 and Puppet.components(u).size()==2,"sameformstatsstackbutidenticalabilitiesdonotduplicate")
	gs.VerifiedRules.Forms.remove(gs,0,0,"专项真实移除")
	check(u.form.is_empty() and u.attack==5 and u.maxHp==4 and u.hp==4,"removeconditionalbonusandshape,retaingenuinegrowth")
	check(p.puppetRemoved.size()==1 and p.puppetRemoved[0].puppetFusionCount==2,"realremovalstoreswholefusedcarrierwithactualcount")
	gs=game();p=gs.player(0);u=p.units[0];u.baseRulesSuppressed=true
	check(Puppet.base_bonus(u)==0 and not gs.can_play_card(0,give(gs,"c23102")).ok,"paper suppressesbaseandoriginalcards")
func barrier_swift_heart() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
	play(gs,"c23103");check(not u.get("barrier",false) and u.shield==0,"initialwarddoesnotfakearmororbarrierbeforefusion")
	play(gs,"c23105");check(u.barrier and u.swift and u.attack==6 and u.maxHp==6,"fusionwardgrantsrealbarrierandnewswift")
	var hp: int=u.hp;gs._damage_unit(0,0,99,1,0)
	check(u.hp==hp and not u.barrier and u.shield==0,"barrierpreventsonewholehitwithoutarmor")
	var fire: int=p.energy;var avatar: int=gs.player(1).avatarHp
	check(gs.basic_attack(0,0) and p.energy==fire and not u.swift and gs.player(1).avatarHp==avatar-u.attack,"actualswiftfreeattackconsumesstatusnotfakeforcedcombat")
	play(gs,"c23104");check(u.barrier and u.swift,"laterfusionrefreshesinheritedbarrierandswift")
	gs=game();p=gs.player(0);u=p.units[0];play(gs,"c23108")
	check(gs.VerifiedRules.Combat.has(u,"pierce") and int(p.get("puppetCardGrowth",0))==0,"heartpierceimmediatelybutfirstnotfusiongrowth")
	var idx:=give(gs,"c23102");var inst: String=p.hand[idx].instanceId
	play(gs,"c23104");check(p.puppetCardGrowth==1 and u.attack==8 and u.maxHp==8,"heartgrowsallunplayedcardsnotalreadyfusedbody")
	idx=p.hand.find_custom(func(e):return e.instanceId==inst);var card: Dictionary=gs.hand_card_def(0,idx)
	check(card.value.attack==2 and card.value.hp==2,"existinghandshapegainspermanent1/1")
	var snapshot:=JSON.stringify(gs.snapshot());Puppet.describe_card(gs,0,p.hand[idx],card);check(JSON.stringify(gs.snapshot())==snapshot,"dynamicsread-only")
	var fire_before: int=p.energy;check(gs.play_card(0,idx) and p.energy==fire_before-1,"permanentgrowthusesactualhandinstance")
	check(u.attack==10 and u.maxHp==10 and p.puppetCardGrowth==2,"incominggrowthsnapshottedonce,builtcomponentsnotretroactivelygrown")
	check(gs.VerifiedRules.Combat.has(u,"pierce"),"fusioninheritspiercefromolderheart")
	var foe: Dictionary=gs.player(1);foe.units[1].front=1;foe.units[1].hp=1;foe.units[1].shield=0;avatar=foe.avatarHp
	play(gs,"c23105");check(foe.units[1].hp==0 and foe.avatarHp==avatar-2,"inheritedfusionprojectiletruepierceoverflow")
func wire_and_thread() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];var deck: int=p.deck.size()
	play(gs,"c23101");check(p.hand.is_empty() and p.deck.size()==deck,"wirewithnoremoveddoesnotfakedraw")
	play(gs,"c23102");play(gs,"c23105");play(gs,"c23101")
	check(p.get("puppetRemoved",[]).is_empty() and p.hand.is_empty(),"wirecannotrecoverabsorbedfusionmaterials")
	var iid: String=u.form.puppetInstance.instanceId
	gs.VerifiedRules.Forms.remove(gs,0,0,"真实消灭形态")
	play(gs,"c23104");gs.VerifiedRules.Forms.remove(gs,0,0,"较少融合形态")
	play(gs,"c23101");check(p.hand.size()==1 and p.hand[0].instanceId==iid and p.hand[0].puppetFusionCount==1,"wiremovesmostfusedoriginalcarrierwithsamemetadata")
	check(p.puppetRemoved.size()==1 and not p.puppetRemoved.any(func(e):return e.instanceId==iid),"wireconsumesremovedentrywithoutduplicate")
	check(gs.play_card(0,0) and Puppet.components(u).has("c23102") and Puppet.components(u).has("c23105") and u.attack==5,"returnedfusioncarrierkeepsbodyandtwoabilities")
	gs=game();p=gs.player(0);u=p.units[0];var oldidx:=give(gs,"c23102");var oldiid: String=p.hand[oldidx].instanceId
	p.deck=[{"instanceId":"draw-shape-a","definitionId":"c23103"},{"instanceId":"draw-other","definitionId":"c10101"},{"instanceId":"draw-shape-b","definitionId":"c23105"}]
	play(gs,"c23107");check(p.deck.size()==1 and p.deck[0].instanceId=="draw-other" and p.hand.size()==3,"threadrandomexacttwoownedformsnotarbitrarydraw")
	var freeids: Array=[]
	for idx in p.hand.size():
		var card: Dictionary=gs.hand_card_def(0,idx)
		if p.hand[idx].instanceId==oldiid:check(gs.effective_card_cost(0,card)==1,"oldhandformnotfree")
		else:
			check(card.puppetFree and gs.effective_card_cost(0,card)==0,"onlyactualdrawninstancefreethisturn")
			freeids.append(p.hand[idx].instanceId)
	p.energy=0;var idx: int=p.hand.find_custom(func(e):return e.instanceId==freeids[0]);check(gs.play_card(0,idx),"actualzero-fireformplays")
	check(not p.get("keywordUsage",{}).get("instant",{}).get("used",false),"threadfreeformdoesnotusesinstantallowance")
	gs.turn_counter+=2;idx=p.hand.find_custom(func(e):return e.instanceId==freeids[1]);var card:=gs.hand_card_def(0,idx)
	check(not card.puppetFree and gs.effective_card_cost(0,card)==1 and not gs.can_play_card(0,idx).ok,"unplayedfreeexpiresandlegalityrejectszerofire")
	gs=game();p=gs.player(0);p.deck=[{"instanceId":"one-shape","definitionId":"c23103"},{"instanceId":"not-shape","definitionId":"c10101"}];play(gs,"c23107")
	check(p.hand.size()==1 and p.hand[0].instanceId=="one-shape" and p.deck.size()==1,"threadoneeligibledoesnotinventsecond")
func awakening() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0]
	play(gs,"c23106");check(u.awakened and u.attack==3 and u.maxHp==3 and Puppet.components(u)==[Puppet.AWAKEN_FORM],"awakepermanent3/3replacesoldbasebonuswithoutfake1/1")
	check(not gs.can_play_card(0,give(gs,"c23106")).ok,"alreadyawakecannotreuse")
	play(gs,"c23102");check(u.attack==4 and events(gs,"puppet-projectile").size()==1,"firstshapeafterawakeningisactualfusion")
	for id in ["c23103","c23104","c23105"]:play(gs,id)
	var hp: int=gs.player(1).avatarHp;Puppet.turn_start(gs,0);gs._resolve_resolution_stack()
	check(Puppet.components(u).size()==5 and gs.player(1).avatarHp==hp and events(gs,"puppet-awake-hit").is_empty(),"fiveuniqueformsnevertrigger60")
	play(gs,"c23108")
	for enemy in gs.player(1).units:enemy.hp=200;enemy.maxHp=200
	hp=gs.player(1).avatarHp;var total:=hp
	for enemy in gs.player(1).units:total+=int(enemy.hp)
	Puppet.turn_start(gs,0);gs._resolve_resolution_stack()
	var after: int=gs.player(1).avatarHp
	for enemy in gs.player(1).units:after+=int(enemy.hp)
	check(Puppet.components(u).size()==6 and events(gs,"puppet-awake-hit").size()==6 and total-after==60,"sixdistinctformsdealtrue6sequential10randomcharacterhits")
	gs.VerifiedRules.Forms.remove(gs,0,0,"解除形态");gs._resolve_resolution_stack()
	check(Puppet.components(u)==[Puppet.AWAKEN_FORM] and u.attack==3 and u.maxHp==3,"permanentawakeautoreattachesbutlostfusionstayslost")
	gs._knockout_unit(u);gs._resolve_resolution_stack();check(u.hp==0 and u.form.is_empty(),"permanentformdoesnotreviveknockedsource")
	u.hp=3;u.knockout=0;gs.VerifiedRules.Movement.revived(gs,0,0)
	check(Puppet.components(u)==[Puppet.AWAKEN_FORM],"actualrevivalreattachespermanentawakeningform")
	gs=game();p=gs.player(0);u=p.units[0];play(gs,"c23102");play(gs,"c23103");play(gs,"c23106")
	check(u.attack==6 and u.maxHp==6 and Puppet.components(u).size()==3,"awakeningexistingformfuses3/3andremovesoldconditional3/3once")
	var carrier: String=u.form.puppetInstance.instanceId
	check(u.form.puppetInstance.definitionId==Puppet.AWAKEN_FORM,"awakeningisnewrealcarrier")
	gs.VerifiedRules.Forms.remove(gs,0,0,"觉醒载体真实移除");gs._resolve_resolution_stack();play(gs,"c23101")
	var idx: int=p.hand.find_custom(func(e):return e.instanceId==carrier)
	check(idx>=0 and p.hand[idx].definitionId==Puppet.AWAKEN_FORM,"wirecanrecoverremovedcompositeawakeningcarrier")
	if idx>=0:
		var card: Dictionary=gs.hand_card_def(0,idx)
		check(card.type=="form" and card.value.attack==6 and card.value.hp==6 and card.text.contains("机关"),"returnedawakeningtokenpresentswholefusedbodyandabilities")
		check(gs.play_card(0,idx) and Puppet.components(u).size()==3 and u.attack==9,"returnedawakecarrierfuseswithreattachedpermanentform")
		check(events(gs,"puppet-projectile").size()==3 and u.barrier,"returnedawakecarrierretainsprojectileandbarrierabilities")
func ai_and_art() -> void:
	for n in range(1,9):
		var gs:=game();var p: Dictionary=gs.player(0);var id: String="c231%02d"%n
		if n==1:play(gs,"c23102");gs.VerifiedRules.Forms.remove(gs,0,0,"AI取回准备")
		give(gs,id);var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegallychooses "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactuallyexecutes "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalPNG "+id)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["kuileishi","yaodaoji","taohuayao","shantu"],["yaodaoji","bingyong","xuenv","baizangzhu"],231);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true;p.avatarHp=200
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.4).timeout
		var gs=b.gs;var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];var hp: int=gs.player(1).avatarHp
		hand(b,["c23102","c23104"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(u.attack==4 and gs.player(1).avatarHp==hp,"nativemousefirstshapenoattackandexactbody")
		gs._damage_unit(0,0,2,1,0);b._refresh();await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(u.attack==6 and u.maxHp==6 and u.hp==4 and gs.player(1).avatarHp==hp-3,"nativemousefusionpreserveswoundsandrepeatsactualability")
		if physical.x==1280:await capture("01-puppet-real-fusion-wounds")
		gs.VerifiedRules.Forms.remove(gs,0,0,"鼠标回收准备");hand(b,["c23101"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(p.hand.size()==1 and p.hand[0].puppetFusionCount==1,"nativemousewiremovestruefusedcarrier")
		await click(b._hand_row.get_child(0));await settled(b);check(Puppet.components(u).size()==2,"nativemousecanreplayinheritedfusioncard")
		p.deck=[{"definitionId":"c23103","instanceId":"native-shape-a"},{"definitionId":"c23105","instanceId":"native-shape-b"}];hand(b,["c23107"]);p.energy=1;await settled(b)
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.hand.size()==2 and p.energy==0 and b._hand_row.get_child(0).playable and b._hand_row.get_child(1).playable,"nativeactualthreadtwozero-fireenabledforms")
		if physical.x==1600:await capture("02-puppet-thread-zero-fire-forms")
		await click(b._hand_row.get_child(0));await settled(b);check(p.energy==0 and Puppet.components(u).size()==3,"nativeactualzero-firefusioncardplays")
		await click(b._unit_widget(str(u.uid)));await settled(b)
		if b._selected_attacker==0:await click(b._unit_widget(str(u.uid)));await settled(b)
		check(texts(b).contains("融合") and texts(b).contains("操控"),"nativeinspectorpresentsactualinheritedabilities")
		escape();await settled(b);b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	base_and_fusion();barrier_swift_heart();wire_and_thread();awakening();ai_and_art()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("PUPPET checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
