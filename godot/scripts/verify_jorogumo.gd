extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Spider := preload("res://scripts/jorogumo_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("JOROGUMO_FAIL ",detail)
func game() -> GS:
	var gs := GS.create(["luoxinfu","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],275)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.avatarArmor=0
		for u in p.units: u.level=3
	gs.rule_events.clear(); return gs
func instance(gs,id: String) -> Dictionary:
	var inst := {"instanceId":"spider-test-%d" % gs.next_card_id,"definitionId":id}; gs.next_card_id+=1; return inst
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append(instance(gs,id)); return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actualuse "+id)
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind==kind)
func knock(gs,owner: int,idx: int) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0); gs._resolve_resolution_stack()
func mark_and_damage() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]; var target: Dictionary=foe.units[0]
	check(u.attack==3 and u.maxHp==4 and u.passive_hooks.is_empty(),"base3/4nofakecombatarmorbreak")
	var fire: int=p.energy; var hp: int=target.hp; play(gs,"c27502",target.uid)
	check(Spider.marked(target) and target.hp==hp-2 and target.armorBreak==0,"needlemarkfirstthen1damageactually2withoutarmorbreak")
	check(p.energy==fire and u.battleSkillId=="c27502","originalinstantcostandactualspellwarskill")
	var before: Dictionary=gs.snapshot(); hp=foe.units[1].hp; fire=p.energy
	check(gs.basic_attack(0,0,foe.units[1].uid) and foe.units[1].hp==hp-2 and u.front==0 and p.energy==fire-1,"poisonneedlewarskillreplacesdeploymentwithoutinventedcombat")
	check(events(gs,"combat-hit").is_empty(),"spellwarskillisnotanattackforbaselast-attacker")
	gs=game(); foe=gs.player(1); target=foe.units[0]; Spider.attach(gs,0,0,target); Spider.attach(gs,0,0,target); hp=target.hp
	gs._damage_unit(1,0,1,0,1); check(target.hp==hp-2 and Spider.marked(target),"uniquepermanentmarkdoesnotstackorconsumeonhit")
	hp=target.hp; gs._damage_unit(1,0,0,0,1); check(target.hp==hp,"markcannotinventdamagefromzero")
	target.barrier=true; gs._damage_unit(1,0,2,0,1); check(target.hp==hp and not target.barrier and Spider.marked(target),"barrierblockswholemarkedenhanceddamage")
	target.shield=2; gs._damage_unit(1,0,1,0,1); check(target.hp==hp and target.shield==1 and Spider.marked(target),"armorfullyblockedpacketdoesnotbecome1damagefrommark")
	target.shield=0; gs._damage_unit(1,0,1,1,1); check(target.hp==hp-2,"markalsoenhancesfriendlydamage")
	gs._grow_unit(target,0,5); hp=target.hp; gs._damage_unit(1,0,1,0,1,false,-1,false,true); check(target.hp==hp-3,"criticaldoublesbasebeforeaddingonefrommark")
	knock(gs,1,0); check(not Spider.marked(target),"actualKOclearsmark")
	gs=game(); foe=gs.player(1); Spider.attach(gs,0,0,foe.units[0]); gs.VerifiedRules.PipeFox.cleanse(gs,1,3)
	check(not Spider.marked(foe.units[0]),"whitefoxcleansesactualenemymark")
	Spider.attach(gs,0,0,foe.units[1]); gs.VerifiedRules.Moon.full_moon(gs,foe.units[1]); check(not Spider.marked(foe.units[1]),"fullmoonremovesactualmark")
	gs=game(); foe=gs.player(1); foe.units[1].level=0; var idx:=give(gs,"c27502")
	check(gs.valid_targets(0,gs.hand_card_def(0,idx)).has(foe.units[1].uid) and gs.play_card(0,idx,foe.units[1].uid),"markcanselectlivinginactiveenemywithoutinventedlevelrestriction")
func attacks_and_awakening() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	check(gs.end_turn(0),"actualswitchtoenemy")
	foe.levelUpUsed=true; foe.energy=40
	check(gs.basic_attack(1,0),"enemyfirstactualattack")
	foe.units[1].inspired=true; check(gs.basic_attack(1,1),"enemysecondactualattack")
	check(not Spider.marked(foe.units[0]) and not Spider.marked(foe.units[1]),"baseabilitywaitsforenemyturnend")
	check(gs.end_turn(1) and not Spider.marked(foe.units[0]) and Spider.marked(foe.units[1]),"realendmarksactualfinalattackeronly")
	gs=game(); foe=gs.player(1); gs.current_player=1; foe.levelUpUsed=true; gs.end_turn(1)
	check(not foe.units.any(func(enemy):return Spider.marked(enemy)),"noattackturncannotfabricatemark")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; play(gs,"c27505",foe.units[0].uid)
	check(u.awakened and u.attack==4 and u.maxHp==5 and Spider.marked(foe.units[0]),"awakeningisprintedspell+1/+1andrealentrymark")
	check(Content.card_def("c27505").type=="spell" and not gs.can_play_card(0,give(gs,"c27505"),foe.units[1].uid).ok,"awakeningprintedspellcannotrepeat")
	p.hand.clear(); var hp: int=foe.units[0].hp; Spider.attach(gs,0,0,foe.units[0])
	check(foe.units[0].hp==hp-3 and Spider.marked(foe.units[0]),"awakenedrepeatmarkreplacedwith2damageplusactualmark1")
	gs.current_player=1; hp=foe.units[1].hp; check(gs.basic_attack(1,1) and Spider.marked(foe.units[1]) and foe.units[1].hp==hp,"awakefirstattackmarkswithoutinventeddirectdamage")
	foe.units[1].inspired=true; hp=foe.units[1].hp; gs.basic_attack(1,1)
	check(foe.units[1].hp==hp-3,"awakefollowingattackrepeatmarkdeals3beforeattack")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c27505",foe.units[0].uid); foe.units[0].hp=3; gs.current_player=1; var face: int=p.avatarHp
	check(gs.basic_attack(1,0) and foe.units[0].hp==0 and p.avatarHp==face,"awakepreattackmarkkillscancelactualpendingattack")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c27505",foe.units[0].uid); knock(gs,0,0); gs.current_player=1; hp=foe.units[0].hp; gs.basic_attack(1,0)
	check(foe.units[0].hp==hp,"KOawakecannotexecuteitsability")
func pursuit_cards() -> void:
	for marked_target in [false,true]:
		var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]; var target: Dictionary=foe.units[1]
		gs._grow_unit(target,3,10); foe.units[0].front=1
		if marked_target: Spider.attach(gs,0,0,target)
		var hp: int=target.hp; var ownhp: int=u.hp; play(gs,"c27503",target.uid)
		check(target.hp==hp-(4 if marked_target else 3),"huntoriginal0attackbonusandmarkdamage "+str(marked_target))
		check(u.hp==(ownhp if marked_target else ownhp-4) and u.shield==(1 if marked_target else 0),"huntconditionalactualcombatimmunitynotfakearmor "+str(marked_target))
		gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; target=foe.units[1]; p.avatarHp=10; gs._grow_unit(target,0,10); foe.units[0].front=1
		if marked_target: Spider.attach(gs,0,0,target)
		hp=target.hp; ownhp=u.hp; play(gs,"c27506",target.uid)
		check(target.hp==hp-(5 if marked_target else 4) and p.avatarHp==(15 if marked_target else 10),"silkprinted1/1actualconditionallifestealnotselfheal "+str(marked_target))
		check(u.hp==ownhp-1,"silkhasnoinventedcombatimmunityorselfheal")
	var gs:=game(); var p:Dictionary=gs.player(0); var idx:=give(gs,"c27503"); var fire:int=p.energy
	check(not gs.play_card(0,idx,p.units[1].uid) and p.energy==fire and p.hand.size()==1,"invalidpursuitallycostsnothing")
func realm_and_swarm() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]
	for enemy in foe.units: gs._grow_unit(enemy,0,10)
	var hps:Array=foe.units.map(func(enemy):return enemy.hp); var fire:int=p.energy; play(gs,"c27501",foe.units[0].uid)
	check(p.energy==fire-1 and p.realms.size()==1 and p.realms[0].hp==5,"realmprinted1fireand5durability")
	for i in foe.units.size(): check(foe.units[i].hp==hps[i]-(4 if i==0 else 3),"realmreallevel3AOEafterentrymark "+str(i))
	var face:int=foe.avatarHp; knock(gs,1,1)
	check(p.realms[0].hp==6 and foe.avatarHp==face-1,"realenemyKOevenunmarkedgains1realmHPanddamagesavatar1")
	knock(gs,0,0); face=foe.avatarHp; knock(gs,1,2)
	check(p.realms[0].hp==7 and foe.avatarHp==face-1,"realmstillworkswhilehostKO")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; play(gs,"c27504",foe.units[0].uid)
	check(u.attack==4 and u.maxHp==6 and Spider.marked(foe.units[0]),"queenprinted4/6andentrymark")
	var rng:int=gs.rng_state; knock(gs,1,0)
	var swarms:Array=p.units.filter(func(unit):return unit.get("jorogumoSwarm",false) and int(unit.hp)>0)
	check(swarms.size()==1 and swarms[0].attack==3 and swarms[0].hp==4 and swarms[0].front==1,"markedKOcreatesactual3/4frontswarm")
	check(gs.rng_state==rng and p.units.size()==5,"summoncreatesnohiddenplayerdeckorRNGsideeffects")
	var swarm:Dictionary=swarms[0]; var si:int=gs._unit_index_by_uid(0,swarm.uid); gs._grow_unit(foe.units[1],0,10); foe.units[1].front=1; var hp:int=foe.units[1].hp
	check(gs.basic_attack(0,si) and foe.units[1].hp==hp-3 and Spider.marked(foe.units[1]),"realnewswarmcanattackandmarkafteractualdamage")
	Spider.attach(gs,0,0,foe.units[2]); knock(gs,1,2)
	check(p.units.filter(func(unit):return unit.get("jorogumoSwarm",false)).size()==1,"queenonceperturncannotresummonsecondmarkedKO")
	gs.turn_counter+=1; Spider.attach(gs,0,0,foe.units[3]); knock(gs,1,3)
	check(swarm.get("removed",false) and p.units.filter(func(unit):return unit.get("jorogumoSwarm",false) and int(unit.hp)>0).size()==1,"nextturnnewphysicalswarmreplacesoldwithoutfakeKO")
	var second:Dictionary=p.units.back(); gs.VerifiedRules.Movement.move_to(gs,0,p.units.size()-1,0)
	check(second.removed and second.knockout==0,"forcedswarmdepartureisremovalnotKO")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c27504",foe.units[0].uid); knock(gs,1,1)
	check(p.units.size()==4,"unmarkedKOcannottriggerqueen")
	knock(gs,0,0); knock(gs,1,0); check(p.units.size()==4,"KOqueencannotnewlytriggerswarm")
func tax_and_exterminate() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); play(gs,"c27507",foe.units[1].uid)
	check(p.units[0].attack==4 and p.units[0].maxHp==6 and Spider.tax(gs,1,foe.units[1])==1,"webprinted4/6andactualmarkedtax")
	gs.current_player=1; var idx:=give(gs,"c12407",1); var card:Dictionary=gs.hand_card_def(1,idx)
	check(gs.card_payment(1,card).cost==int(card.cost)+1,"spellactualquoteincludesextra1fire")
	foe.energy=int(card.cost); check(not gs.can_play_card(1,idx,p.units[0].uid).ok,"notaxfireblocksphysicalcardbeforepay")
	foe.energy=40; var fire:int=foe.energy; check(gs.play_card(1,idx,p.units[0].uid) and foe.energy==fire-int(card.cost)-1,"actualspellpaysadditionalfire")
	foe.attackUsed=false; foe.units[1].swift=true; foe.energy=0; check(not gs.can_basic_attack(1,1).ok,"swiftbasefreecannotbypasswebtax")
	foe.energy=1; fire=foe.energy; check(gs.basic_attack(1,1) and foe.energy==fire-1,"swiftdeploymentactualextraghostpayment")
	foe.units[1].inspired=true; foe.energy=1; check(not gs.can_basic_attack(1,1).ok,"normalbase1plusweb1needs2ghosts")
	gs.VerifiedRules.Moon.full_moon(gs,foe.units[1]); check(Spider.tax(gs,1,foe.units[1])==0,"removingmarkremovestax")
	Spider.attach(gs,0,0,foe.units[2]); knock(gs,0,0); check(Spider.tax(gs,1,foe.units[2])==0,"KOwebdoesnotchargeenemies")
	for marked_target in [false,true]:
		gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[0],0,10); var target:Dictionary=foe.units[0]
		if marked_target: Spider.attach(gs,0,0,target); target.barrier=true; target.shield=20
		var hp:int=target.hp; var handsize:int=p.hand.size(); play(gs,"c27508",target.uid)
		check((target.hp==0 if marked_target else target.hp==hp-5) and p.hand.size()==handsize+1,"exterminateconditionaldestroyignoresbarrierarmoranddraws "+str(marked_target))
	gs=game(); p=gs.player(0); var hp:int=p.units[2].hp; play(gs,"c27508",p.units[2].uid)
	check(p.units[2].hp==maxi(0,hp-5),"exterminateprintedanyshikigamiallowsfriendlytarget")
func cross_rule_boundaries() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1)
	for enemy in foe.units: enemy.hp=3
	var face:int=foe.avatarHp; play(gs,"c27501",foe.units[0].uid)
	check(foe.units.all(func(enemy):return int(enemy.hp)==0) and p.realms[0].hp==9 and foe.avatarHp==face-4,"realmgroupKOqueues4independentdurabilityanddamageevents")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c27504",foe.units[0].uid)
	gs._grow_unit(foe.units[0],5,0); foe.units[0].hp=2; foe.units[0].front=1
	check(gs.basic_attack(0,0) and p.units[0].hp==0 and p.units.back().get("jorogumoSwarm",false),"alreadytriggeredswarmresolvesafterqueenKOinsameexchange")
	gs=game(); p=gs.player(0); foe=gs.player(1); Spider.attach(gs,0,0,foe.units[0]); foe.units[0].hp=2; foe.units[0].front=1
	p.units[0].keywords=["pierce"]; var hp:int=foe.avatarHp; gs.basic_attack(0,0)
	check(foe.units[0].hp==0 and foe.avatarHp==hp-2,"markdamageparticipatesinactualpierceoverflow")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c27507",foe.units[1].uid); gs.current_player=1; foe.energy=0
	var idx:=give(gs,"c12401",1); var card:Dictionary=gs.hand_card_def(1,idx)
	check(gs.card_payment(1,card).usesInstant and gs.card_payment(1,card).cost==1,"firstinstantstillhasadditionalwebtax")
	check(not gs.can_play_card(1,idx).ok,"zeroenergycannotuseinstantthroughwebtax")
	foe.energy=1; check(gs.play_card(1,idx) and foe.energy==0,"actualinstantpayswebtaxonce")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs.current_player=1
	gs.basic_attack_ex(1,1,0,false); gs._resolve_resolution_stack(); check(gs.end_turn(1) and Spider.marked(foe.units[1]),"forcedrealcombatcountsasattackforendturnmark")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c27502",foe.units[0].uid); p.attackUsed=false
	check(gs.basic_attack(0,0,foe.units[1].uid) and p.units[0].front==0,"actualspellwarskillreplacesratherthanaddsattack")
	check(not p.get("jorogumoLastAttack",{}).has("uid"),"spellwarskilldoesnotinventattackhistory")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.units[0].spellPower=2; gs._grow_unit(foe.units[0],0,15); hp=foe.units[0].hp; idx=give(gs,"c27502")
	check(gs.hand_card_def(0,idx).value==3 and gs.play_card(0,idx,foe.units[0].uid) and foe.units[0].hp==hp-4,"needlerealspellpowerandmarkdamage")
	hp=foe.units[1].hp; gs.basic_attack(0,0,foe.units[1].uid); check(foe.units[1].hp==hp-4,"spellwarskillkeepsactualspellpower")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.units[0].spellPower=2; gs._grow_unit(foe.units[0],0,15); hp=foe.units[0].hp; play(gs,"c27508",foe.units[0].uid)
	check(foe.units[0].hp==hp-7,"unmarkedexterminaterealspellpower")
	gs=game(); p=gs.player(0); Spider.summon(gs,0,0)
	for i in 4: p.units[i].cannotAttack=true
	var best:Dictionary=AI._best_attack(gs,0)
	check(best.ok and best.unit==4 and gs.basic_attack(0,best.unit,best.target),"AIcanlegallycommandactualswarm")
func ai_and_boundaries() -> void:
	for n in range(1,9):
		var gs:=game(); var id:="c275%02d"%n; give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualoriginal "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalPNG "+id)
	var gs:=game(); var foe:Dictionary=gs.player(1); give(gs,"c27502"); var stamp:=JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0); gs.VerifiedRules.BattleSkill.ready(gs,0,0)
	check(JSON.stringify(gs.snapshot())==stamp,"cardtargetandpaymentqueriesarepure")
	gs.player(0).nullifyNextCardTurn=gs.turn_counter; var hp:int=foe.units[0].hp; check(gs.play_card(0,0,foe.units[0].uid) and not Spider.marked(foe.units[0]) and foe.units[0].hp==hp,"nullifiedneedlecannotmarkordamage")
	gs=game(); foe=gs.player(1)
	for enemy in foe.units: enemy.hp=0; enemy.knockout=2
	var idx:=give(gs,"c27504"); check(gs.hand_card_def(0,idx).target=="auto" and gs.play_card(0,idx),"formstillusablewithoutenemyentrytarget")
	gs=game(); foe=gs.player(1); gs._deploy_realm(0,Content.card_def("c27501")); foe.units[0].hp=1; Spider.attach(gs,0,0,foe.units[0]); var before:Dictionary=gs.snapshot(); gs._damage_unit(1,0,1,0,0); gs._resolve_resolution_stack()
	var Cues:=preload("res://scripts/ui/battle_effect_cues.gd"); var cues:Array=Cues.damage_cues(before,gs.snapshot())
	check(cues.any(func(c):return c.cardId=="c27501" and c.amount==1),"UIseparaterealmdeathactualdamagepacket")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["luoxinfu","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],275); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs=b.gs; var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]
		hand(b,["c27502","c27504"]); await settled(b); var fire:int=p.energy
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"nativenoncombatmarkrejectsallywithoutpayment")
		escape(); await process_frame; check(b._pending_target_card==-1,"nativeEscapecancelsmarktarget")
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(Spider.marked(foe.units[0]) and foe.units[0].hp==foe.units[0].maxHp-2,"nativeactualneedlemarkanddamage")
		await click(b._hand_row.get_child(0)); await settled(b); await capture("%d-01-queen-entry-target"%physical.x)
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(u.form.cardId=="c27504" and Spider.marked(foe.units[1]),"nativeformselectsactualentrymarktarget")
		knock(gs,1,1); b._refresh(); await settled(b); var swarm:Dictionary=p.units.back()
		check(swarm.get("jorogumoSwarm",false) and b._unit_widget(str(swarm.uid))!=null,"nativeactualswarmfrontwidget")
		await capture("%d-02-actual-swarm"%physical.x)
		hand(b,["c27508"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(foe.units[0].hp==0 and p.hand.size()==1,"nativeexterminateactualmarkedKOanddraw")
		hand(b,["c27507"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(Spider.marked(foe.units[2]) and Spider.tax(gs,1,foe.units[2])==1,"nativewebactualselectedenemytax")
		await capture("%d-03-web-mark"%physical.x)
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	mark_and_damage(); attacks_and_awakening(); pursuit_cards(); realm_and_swarm(); tax_and_exterminate(); cross_rule_boundaries(); ai_and_boundaries()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("JOROGUMO_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]); quit(0 if failures==0 else 1)
