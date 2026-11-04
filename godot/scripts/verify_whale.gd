extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Whale := preload("res://scripts/whale_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("WHALE_FAIL ",detail)
func game(own: Array=["huajing","shuweng","shantong","taohuayao"]) -> GS:
	var gs:=GS.create(own,["bingyong","fenghuanghuo","xuenv","baizangzhu"],278)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3; u.charge=0
	gs.rule_events.clear(); return gs
func give(gs,id: String,burst: int=0) -> int:
	gs.player(0).hand.append({"instanceId":"whale-test-%d"%gs.next_card_id,"definitionId":id,"movementBurst":burst}); gs.next_card_id+=1
	return gs.player(0).hand.size()-1
func play(gs,id: String,target=null,burst: int=0) -> void:
	var idx:=give(gs,id,burst)
	var reason:Dictionary=gs.can_play_card(0,idx,target)
	check(gs.play_card(0,idx,target),"actualuse "+id+" burst="+str(burst)+" "+str(reason))
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func knock(gs,owner: int,idx: int) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0); gs._resolve_resolution_stack()
func charge_and_charms() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]; var a:Dictionary=p.units[1]
	check(u.attack==2 and u.maxHp==6 and u.passive_hooks.is_empty(),"base2/6noinventedghostfirepassive")
	play(gs,"c27801",a.uid); play(gs,"c27802",a.uid)
	check(a.attack==int(Content.unit_def("shuweng").attack) and a.shield==0 and Whale.charm(a,"Tooth") and Whale.charm(a,"Body"),"twouniquecharmswithoutstatarmorapproximation")
	Whale.attach(gs,0,0,a,"Tooth"); check(a.whaleTooth is Dictionary,"repeatedattachdoesnotstack")
	foe.units[0].front=1; foe.units[0].hp=2; a.hp=a.maxHp-1; p.avatarHp=10; a.spellPower=50
	var face:int=foe.avatarHp; var fire:int=p.energy
	check(gs.basic_attack(0,1),"realcarrierdeployment")
	check(foe.units[0].hp==0 and foe.avatarHp==face-a.attack,"toothprojectilekillsfrontbeforeactualcombatretargetsavatar")
	check(p.avatarHp==11 and a.hp==a.maxHp,"bodyselfheal2with1actualoverflow")
	check(u.charge==1 and p.energy==fire-1,"deploymentcharge1distinctfromplayerghostfire")
	a.inspired=true; face=foe.avatarHp; gs.basic_attack(0,1)
	check(u.charge==1 and foe.avatarHp==face-a.attack-2 and p.avatarHp==13,"nextdeploymentcharmsrepeatbutbaseonceperturn")
	var n:int=events(gs,"whale-tooth-hit").size(); gs._resolve_combat(0,1,0,false,false,false,false)
	check(events(gs,"whale-tooth-hit").size()==n and u.charge==1,"forcedcombatdoesnotinventdeploymentcharmorcharge")
	gs=game(); p=gs.player(0); foe=gs.player(1); a=p.units[1]; u=p.units[0]; Whale.attach(gs,0,0,a,"Tooth"); Whale.attach(gs,0,0,a,"Body"); knock(gs,0,0); p.avatarHp=10
	face=foe.avatarHp; gs.basic_attack(0,1); check(foe.avatarHp==face-a.attack-2 and p.avatarHp==12,"attachedcharmsworkwhilewhaleKO")
	knock(gs,0,1); check(not Whale.charm(a,"Tooth") and not Whale.charm(a,"Body"),"ordinarycharmsremovedonKO")
	gs=game(); p=gs.player(0); foe=gs.player(1); a=p.units[1]; Whale.attach(gs,0,0,a,"Tooth"); foe.units[0].front=1; foe.units[0].barrier=true; var hp:int=foe.units[0].hp
	gs.basic_attack(0,1); check(foe.units[0].hp==hp-a.attack and not foe.units[0].barrier and Whale.charm(a,"Tooth"),"projectilerespectsbarrieranddoesnotconsumecharm")
	gs=game(); p=gs.player(0); u=p.units[0]; u.charge=0; gs.end_turn(0); gs.player(1).levelUpUsed=true; gs.end_turn(1)
	check(u.charge==1,"nativechargebeginsnextownturn")
func awaken_and_lifetimes() -> void:
	for selection in ["whale-tooth","whale-body"]:
		var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]
		play(gs,"c27806"); check(gs.pending_choice.type=="whale-awaken" and not u.awakened,"realawakeningpausesforchoice")
		check(not gs.resolve_divination_choice(1,selection) and not gs.resolve_divination_choice(0,"invalid"),"choicevalidatesownerandoption")
		check(gs.resolve_divination_choice(0,selection) and u.awakened and u.attack==2 and u.maxHp==6,"awakeningchoicenoimaginary+1/+3")
		var kind:String="Tooth" if selection=="whale-tooth" else "Body"
		check(Whale.charm(u,kind) and u["whale"+kind].permanent,"chosencharmpermanent")
		check(not gs.can_play_card(0,give(gs,"c27806")).ok,"awakeningcannotrepeat")
		knock(gs,0,0); check(Whale.charm(u,kind),"permanentcharmretainedthroughKO")
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; var foe:Dictionary=gs.player(1)
	Whale.attach(gs,0,0,u,"Body"); play(gs,"c27806"); gs.resolve_divination_choice(0,"whale-tooth"); var face:int=foe.avatarHp; p.avatarHp=10
	check(gs.basic_attack(0,0),"awakewhalerealattack")
	check(foe.avatarHp==face-6 and p.avatarHp==14 and u.charge==1,"awakeownattacktriggersbothcharms2timesbutcharge1")
	u.inspired=true; face=foe.avatarHp; gs.basic_attack(0,0)
	check(foe.avatarHp==face-4 and p.avatarHp==16 and u.charge==1,"laterawakeownattackonlynormalcharmonce")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; play(gs,"c27806"); gs.resolve_divination_choice(0,"whale-tooth"); face=foe.avatarHp
	gs.basic_attack(0,1); check(foe.avatarHp==face-p.units[1].attack-2,"otherallydeploymentextraawakewhalecharm")
	gs=game(); p=gs.player(0); foe=gs.player(1); var a:Dictionary=p.units[1]
	Whale.attach(gs,1,3,a,"Tooth"); gs.VerifiedRules.PipeFox.cleanse(gs,0,0); check(not Whale.charm(a,"Tooth"),"enemyownedcharmcanbecleansed")
	Whale.attach(gs,0,0,a,"Body"); gs.VerifiedRules.Moon.full_moon(gs,a); check(not Whale.charm(a,"Body"),"fullmoonexplicitlyremovescharms")
	Whale.attach(gs,0,0,a,"Tooth"); play(gs,"c27803",foe.units[0].uid)
	check(a.swift and not p.units[2].get("swift",false),"wateronlyattachedalliesgainturnswift")
	gs.end_turn(0); check(not a.swift,"unusedwaterswiftexpiresatturnend")
	gs=game(); p=gs.player(0); a=p.units[1]; a.swift=true; Whale.attach(gs,0,0,a,"Body"); play(gs,"c27803",p.units[2].uid); gs.end_turn(0)
	check(a.swift,"waterexpirationpreservespreexistingswift")
func bursts_and_memory() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; u.charge=3; var a:Dictionary=p.units[1]; var fire:int=p.energy
	play(gs,"c27801",a.uid,3)
	check(u.charge==0 and p.energy==fire and p.hand.size()==1 and gs.hand_card_def(0,0).id=="c27802","burst3paysunitenergygeneratesrealoppositecard")
	check(p.whaleBursts==1 and events(gs,"burst-used").size()==1,"bursthistorycountsactivationsnotpoints")
	p.hand.clear(); u.charge=3; play(gs,"c27802",a.uid,0)
	check(u.charge==3 and p.hand.is_empty() and p.whaleBursts==1,"normalusehasnoburstorgeneration")
	var idx:=give(gs,"c27801",5); fire=p.energy
	check(not gs.play_card(0,idx,a.uid) and p.energy==fire and u.charge==3,"unprintedbursttiercostsnothing")
	p.hand.clear(); idx=give(gs,"c27801",3); u.charge=2
	check(not gs.play_card(0,idx,a.uid),"insufficientenergyrejectsbeforepayingghostfire")
	gs=game(); p=gs.player(0); u=p.units[0]; u.charge=3; idx=give(gs,"c27801"); fire=p.energy
	check(gs.VerifiedRules.Movement.request_burst(gs,0,idx) and p.energy==fire and u.charge==3,"burstmodalopenswithoutpayment")
	check(gs.resolve_divination_choice(0,"movement-cancel") and p.hand.size()==1 and not Whale.charm(p.units[1],"Tooth"),"burstcancelkeepsrealhandinstance")
	gs.VerifiedRules.Movement.request_burst(gs,0,0); check(gs.resolve_divination_choice(0,"burst:3"),"burstselectionrecorded")
	check(p.energy==fire and u.charge==3 and gs.VerifiedRules.Movement.ready_hand(gs,0)==0,"burstselectionawaitstargetwithoutpaying")
	gs=game(); p=gs.player(0); u=p.units[0]; u.charge=3; p.nullifyNextCardTurn=gs.turn_counter
	play(gs,"c27801",p.units[1].uid,3); check(u.charge==3 and not Whale.charm(p.units[1],"Tooth") and int(p.get("whaleBursts",0))==0,"counteredcardcannotpayburstattachorgenerate")
	for amount in [0,5,10]:
		gs=game(); p=gs.player(0); u=p.units[0]; u.charge=10; a=p.units[1]; var before:Array=p.units.map(func(x):return [x.attack,x.maxHp,x.shield])
		play(gs,"c27808",a.uid,amount)
		var affected:Array=p.units.filter(func(x):return Whale.charm(x,"Tooth") and Whale.charm(x,"Body"))
		check(affected.size()==(1 if amount==0 else 2 if amount==5 else 3),"memoryexactdistincttargetcount "+str(amount))
		check(affected.has(a) and affected.all(func(x):return x.swift and x.inspired),"memoryselectedandrandomothersgainbothkeywords "+str(amount))
		check(u.charge==10-amount,"memoryexactburstpayment "+str(amount))
		check(before==p.units.map(func(x):return [x.attack,x.maxHp,x.shield]),"memoryneverreplacedbystatsorarmor "+str(amount))
		gs.end_turn(0); check(affected.all(func(x):return not x.swift and not x.get("inspired",false) and Whale.charm(x,"Tooth")),"memorykeywordsturnonlycharmsremain "+str(amount))
	gs=game(); p=gs.player(0); p.whaleBursts=3; idx=give(gs,"c27807"); var stamp:=JSON.stringify(gs.snapshot()); var card:Dictionary=gs.hand_card_def(0,idx)
	check(card.value.attack==9 and card.value.hp==9 and JSON.stringify(gs.snapshot())==stamp,"lonewhalequerypurehistoricalbonus")
	check(gs.play_card(0,idx) and p.units[0].attack==9 and p.units[0].hp==9 and gs.VerifiedRules.Combat.has(p.units[0],"veil"),"lonewhalereal9/9formwithveil")
func guardian_and_cross_rules() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; u.charge=3
	play(gs,"c27804"); check(p.realms.size()==1 and p.realms[0].hp==6 and p.units.size()==4,"plainrealmdoesnotinventguardianwithoutburst")
	play(gs,"c27801",p.units[1].uid,3)
	var g:Dictionary=p.units.back(); check(g.get("whaleGuardian",false) and g.attack==3 and g.hp==3 and g.front==1,"alliedburstemptyfrontcreatesreal3/3guardian")
	check(gs.basic_attack(0,2) and g.removed and p.units[2].barrier and g.knockout==0,"guardianactuallydisappearsandgrantsbarrieronothersdeployment")
	u.charge=3; var count:int=p.units.size(); play(gs,"c27802",p.units[1].uid,3); check(p.units.size()==count,"occupiedfrontpreventsrealmtrigger")
	gs=game(); p=gs.player(0); u=p.units[0]; u.charge=3; play(gs,"c27804",null,3)
	check(p.units.back().get("whaleGuardian",false) and p.units.back().front==1 and p.units[0].shield==0 and p.units.size()==5 and events(gs,"summon-created").size()==1,"realmprintedburst3summonswithoutarmorapproximation")
	gs=game(); p=gs.player(0); var foe:Dictionary=gs.player(1); play(gs,"c27805")
	g=p.units.back(); check(g.get("whaleGuardian",false) and p.units[0].front==0,"remoteawaitafteractualattackcreatesguardianandreplacesfront")
	check(p.units[0].battleSkillId=="c27805" and p.units[0].charge==0,"manualcombatinstallswarskillwithoutdeploymentcharge")
	var old:Dictionary=g; gs.basic_attack(0,0); g=p.units.back()
	check(old.removed and g!=old and g.get("whaleGuardian",false) and p.units[0].charge==1,"realwarskilldeploymentsacrificesguardianthenattacksandresummons")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[0],20,20); foe.units[0].front=1; play(gs,"c27805")
	check(p.units[0].hp==0 and p.units.size()==4,"awaitcannotresummonifwhaleknockedoutduringattack")
	gs=game(); p=gs.player(0); Whale.summon(gs,0,0); g=p.units.back(); var gi:int=p.units.size()-1
	gs.basic_attack(0,gi); check(not g.removed and not g.barrier,"guardianitselfcannotselfsacrificetobarrier")
	gs.VerifiedRules.Movement.move_to(gs,0,gi,0); check(g.removed and g.knockout==0,"forcedguardianexitremoveswithoutfakeKO")
	gs=game(["huajing","lianyou","yanyanluo","taohuayao"]); p=gs.player(0); gs._deploy_realm(0,Content.card_def("c27804")); p.units[1].charge=3
	gs.VerifiedRules.SunSmoke.pay_charge(gs,0,1,1); check(int(p.get("whaleBursts",0))==0 and p.units.size()==4,"ordinaryenergypaymentisnotburst")
	var movement:Dictionary=Content.load_content().cards.filter(func(c):return c.get("movementBurstOptions",[]).size()>0 and c.unitId=="lianyou")[0]
	p.units[1].charge=10; idx_cross(gs,movement)
	check(int(p.get("whaleBursts",0))==1,"existingmovementburstenterssharedhistory")
	gs=game(["huajing","lianyou","yanyanluo","taohuayao"]); p=gs.player(0); p.units[2].charge=3; gs._deploy_realm(0,Content.card_def("c27804")); var smoke:Dictionary=Content.load_content().cards.filter(func(c):return c.get("smokeBurst",false))[0].duplicate(true); smoke.smokeBurstSelected=true
	gs.VerifiedRules.SunSmoke.resolve_smoke_hit(gs,0,2,smoke,gs.player(1).units[0].uid)
	check(int(p.get("whaleBursts",0))==1 and p.units.back().get("whaleGuardian",false),"existingsmokebursttriggershistoryandrealm")
func idx_cross(gs,card: Dictionary) -> void:
	var idx:=give(gs,card.id,int(card.movementBurstOptions[0])); var view:Dictionary=gs.hand_card_def(0,idx)
	var ts:Array=[null] if view.target=="auto" else gs.valid_targets(0,view)
	check(not ts.is_empty() and gs.play_card(0,idx,ts[0]),"actualotherunitburst")
func ai_and_targets() -> void:
	for n in range(1,9):
		var gs:=game(); var id:="c278%02d"%n; gs.player(0).units[0].charge=10; give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactual "+id)
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs,0),"AIactualawakeningchoice")
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png") and Content.card_def(id).cost==1,"originalPNGandprinted1ghost "+id)
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var idx:=give(gs,"c27803"); var card:Dictionary=gs.hand_card_def(0,idx)
	check(gs.valid_targets(0,card).has(p.units[1].uid) and gs.valid_targets(0,card).has(foe.units[1].uid),"waterselectsanyliveallyorenemy")
	foe.units[1].keywords=["veil"]; check(not gs.valid_targets(0,card).has(foe.units[1].uid),"watercannotselectenemyveil")
	p.units[1].hp=0; check(not gs.valid_targets(0,card).has(p.units[1].uid),"watercannotselectKO")
	idx=give(gs,"c27801"); var fire:int=p.energy
	check(not gs.play_card(0,idx,foe.units[0].uid) and fire==p.energy,"charmcannotselectenemyorpaycost")
func resource_boundaries() -> void:
	var gs:=game(["huajing","rihefang","shuweng","taohuayao"]); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]
	p.units[1].awakened=true; u.charge=0
	play(gs,"c27801",p.units[2].uid,3)
	check(u.charge==0 and int(p.whaleBursts)==1 and int(p.sunFreeChargeTurn)==gs.turn_counter,"sunsfreepaymentstillactualburstnotfakeenergygain")
	check(not gs.can_play_card(0,give(gs,"c27802",3),p.units[2].uid).ok,"sunsfreepaymentonlyonceperturn")
	gs=game(); p=gs.player(0); u=p.units[0]; u.charge=10; gs.basic_attack(0,1)
	check(u.charge==10,"passivechargehonors10cap")
	play(gs,"c27806"); gs.resolve_divination_choice(0,"whale-tooth"); var foe:Dictionary=gs.player(1); var hp:int=foe.avatarHp; p.units[2].inspired=true; gs.basic_attack(0,2)
	check(foe.avatarHp==hp-p.units[2].attack,"awakeningcannotresetalreadyusedonceperturntrigger")
	gs=game(); p=gs.player(0); u=p.units[0]; var a:Dictionary=p.units[1]; a.hp=1; p.avatarHp=10; Whale.attach(gs,0,0,a,"Body"); gs.basic_attack(0,1)
	check(a.hp==3 and p.avatarHp==10,"bodymissingmorethan2hasnoinventedavatarhealing")
	gs=game(); p=gs.player(0); u=p.units[0]; u.spellPower=2; foe=gs.player(1); hp=foe.units[0].hp; play(gs,"c27803",foe.units[0].uid)
	check(foe.units[0].hp==hp-5,"waterrealspellpower3plus2")
	gs=game(); p=gs.player(0); u=p.units[0]; u.charge=10; knock(gs,0,2); knock(gs,0,3); play(gs,"c27808",p.units[1].uid,10)
	check(p.units.filter(func(x):return Whale.charm(x,"Tooth")).size()==2 and not Whale.charm(p.units[2],"Tooth"),"memory10cannotduplicatechosenunitorchooseKOwhenpoolsmall")
	gs=game(); p=gs.player(0); u=p.units[0]; u.charge=3
	for i in int(gs.rules.maxHandSize): give(gs,"c27803")
	play(gs,"c27801",p.units[1].uid,3)
	check(p.hand.size()==int(gs.rules.maxHandSize) and p.hand.all(func(x):return x.definitionId=="c27803"),"oppositecardburnswhenhandfullwithoutchangingpool")
	gs=game(["huajing","lianyou","shuweng","taohuayao"]); p=gs.player(0); gs._deploy_realm(0,Content.card_def("c27804")); knock(gs,0,0); p.units[1].charge=10
	var c:Dictionary=Content.load_content().cards.filter(func(x):return x.get("movementBurstOptions",[]).size()>0 and x.unitId=="lianyou")[0]
	idx_cross(gs,c)
	check(p.units.back().get("whaleGuardian",false),"realmreactstoalliedburstwhilewhaleKO")
func named_choice(b,name: String) -> Control:
	for face in faces(b._choice_layer):
		if face.data.get("name")==name: return face
	return null
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["huajing","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],278); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3; u.charge=0
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs=b.gs; var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; u.charge=10
		hand(b,["c27801"]); await settled(b); var fire:int=p.energy
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.type=="movement-burst" and named_choice(b,"爆能3")!=null and named_choice(b,"爆能3").data.currentCardStats=="爆能3","nativeactualburstmodal")
		await capture("%d-01-burst-choice"%physical.x)
		await click(named_choice(b,"爆能3")); await settled(b)
		check(p.energy==fire and u.charge==10 and b._pending_target_card>=0,"nativeburstselectionawaitstarget")
		await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(Whale.charm(p.units[1],"Tooth") and u.charge==7 and p.hand.size()==1 and gs.hand_card_def(0,0).id=="c27802","nativeactualtargetpaymentandoppositegeneration")
		hand(b,["c27806"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(choice_face(b,"whale-body")!=null and not u.awakened,"nativeactualpermanentchoice")
		await capture("%d-02-awakening-choice"%physical.x)
		await click(choice_face(b,"whale-body")); await settled(b)
		check(u.awakened and Whale.charm(u,"Body") and u.whaleBody.permanent,"nativeawakeningchosenbody")
		hand(b,["c27805"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		var g:Dictionary=p.units.back()
		check(g.get("whaleGuardian",false) and b._unit_widget(str(g.uid))!=null,"nativeactual3/3guardianwidget")
		await capture("%d-03-guardian"%physical.x)
		u.charge=10; hand(b,["c27808"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(named_choice(b,"普通使用")!=null and named_choice(b,"爆能5")!=null and named_choice(b,"爆能10")!=null,"nativeallmemorybursttiersvisible")
		await capture("%d-04-memory-burst"%physical.x)
		await click(named_choice(b,"爆能10")); await settled(b)
		check(b._pending_target_card==0 and u.charge==10,"nativememoryburst10awaitsrealtargetwithoutpayment")
		await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		check(u.charge==0 and Whale.charm(p.units[2],"Tooth") and p.units.filter(func(x):return Whale.charm(x,"Tooth") and Whale.charm(x,"Body")).size()==3,"nativeactualmemory10distinctrandomcopies")
		hand(b,["c27803"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._unit_widget(str(p.units[2].uid)).selected and b._unit_widget(str(gs.player(1).units[1].uid)).selected,"nativewaterallowsactualallyandenemytargets")
		var enemy:Dictionary=gs.player(1).units[1]; var hp:int=enemy.hp
		await click(b._unit_widget(str(enemy.uid))); await settled(b)
		check(enemy.hp==hp-3,"nativewateractualselectedenemy3damage")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	charge_and_charms(); awaken_and_lifetimes(); bursts_and_memory(); guardian_and_cross_rules(); ai_and_targets(); resource_boundaries()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("WHALE_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]); quit(0 if failures==0 else 1)
