extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Baize := preload("res://scripts/baize_rules.gd")
const Div := preload("res://scripts/native_divination_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("BAIZE_FAIL ",detail)
func game(own: Array=["baize","shuweng","shantong","taohuayao"]) -> GS:
	var gs:=GS.create(own,["bingyong","fenghuanghuo","xuenv","baizangzhu"],273)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.rule_events.clear(); return gs
func give(gs,id: String) -> int:
	gs.player(0).hand.append({"instanceId":"baize-test-%d"%gs.next_card_id,"definitionId":id}); gs.next_card_id+=1
	return gs.player(0).hand.size()-1
func play(gs,id: String,target=null) -> void:
	var idx:=give(gs,id); var reason:Dictionary=gs.can_play_card(0,idx,target)
	check(gs.play_card(0,idx,target),"actualuse "+id+" "+str(reason))
func deck(gs,ids: Array, owner: int=0) -> void:
	gs.player(owner).deck.clear()
	for n in range(ids.size()-1,-1,-1):
		gs.player(owner).deck.append({"instanceId":"baize-deck-%d"%gs.next_card_id,"definitionId":ids[n]}); gs.next_card_id+=1
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func knock(gs,owner: int,idx: int) -> void:
	gs._knockout_unit(gs.player(owner).units[idx],1-owner,0); gs._resolve_resolution_stack()
func place(gs,definition: String,bottom: bool) -> void:
	var found:=""
	for iid in gs.pending_choice.get("instanceIds",[]):
		if Div.instance(gs,0,str(iid)).get("definitionId")==definition: found=str(iid); break
	check(not found.is_empty() and gs.resolve_divination_choice(0,found),"selectactualdivinationinstance "+definition)
	check(gs.resolve_divination_choice(0,Div.BOTTOM if bottom else Div.TOP),"actualplacement "+definition)
func finish(gs) -> void:
	var n:=0
	while not gs.pending_choice.is_empty() and n<50:
		n+=1
		if not AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)): break
	check(gs.pending_choice.is_empty() and gs.phase=="main","AIcompletesallchoicesandresumesstack")
func base_and_dazhi() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==5 and u.passive_hooks.is_empty(),"original2/5withoutfaketurnstartdraw")
	deck(gs,["c11901","c11902","c11903","c11904"]); var before:Array=p.deck.duplicate(true); var hand_count:int=p.hand.size()
	Baize.turn_start(gs,0,0)
	check(p.deck.size()==5 and p.hand.size()==hand_count and p.deck.filter(func(i):return i.definitionId==Baize.DAZHI).size()==1,"startinsertsoneactualdazhiwithoutdrawing")
	check(p.deck.filter(func(i):return i.definitionId!=Baize.DAZHI)==before,"insertionpreservesexistingdeckorder")
	check(gs.basic_attack(0,0) and p.deck.size()==6,"realdeploymentalsoinsertsdazhi")
	var prior:int=p.deck.size(); u.inspired=true; gs._resolve_combat(0,0,0,false,false,false,false)
	check(p.deck.size()==prior,"commandedcombatdoesnotinventdeploymenttrigger")
	knock(gs,0,0); Baize.turn_start(gs,0,0); check(p.deck.size()==prior,"KObaseabilityinactive")
	gs=game(); p=gs.player(0); p.units[0].level=0; prior=p.deck.size(); Baize.turn_start(gs,0,0); check(p.deck.size()==prior,"level0baseabilityinactive")
	gs=game(); p=gs.player(0); deck(gs,["c11901","c11902","c11903"]); var cost:int=p.energy
	play(gs,Baize.DAZHI)
	check(gs.pending_choice.type=="native-divination" and gs.pending_choice.count==2 and p.hand.is_empty() and p.energy==cost and p.keywordUsage.instant.used,"manualinstantusesfirstfreeturnallowanceanddrawwaitsfordivination")
	place(gs,"c11901",false); var last:String=gs.pending_choice.instanceIds[0]; gs.resolve_divination_choice(0,last)
	check(gs.pending_choice.instanceIds==[Div.BOTTOM] and not gs.resolve_divination_choice(0,Div.TOP),"lastplacementcannotviolateminimumonebottom")
	gs.resolve_divination_choice(0,Div.BOTTOM)
	check(p.hand.size()==1 and p.hand[0].definitionId=="c11901" and p.deck.back().definitionId=="c11903","mandatorydrawafterreorderingwithoutfreeextraorautoondraw")
	gs=game(); p=gs.player(0); deck(gs,["c11901"]); play(gs,Baize.DAZHI)
	place(gs,"c11901",true)
	check(p.hand.size()==1 and p.hand[0].definitionId=="c11901" and p.deck.is_empty(),"singlecardmustbottomthenactualdrawsameinstance")
	gs=game(); deck(gs,[]); play(gs,Baize.DAZHI); check(gs.winner==1,"emptydivinationstillperformsmandatorydrawandexhaustion")
func revival_and_bottoms() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; var a:Dictionary=p.units[2]
	knock(gs,0,0); knock(gs,0,2); deck(gs,["c11901","c11902"])
	var idx:=give(gs,"c27302"); var ts:Array=gs.valid_targets(0,gs.hand_card_def(0,idx)); var fire:int=p.energy
	check(ts.has(u.uid) and ts.has(a.uid) and not ts.has(p.units[1].uid),"KOsourcecanselectactualknockedalliesincludingitself")
	check(not gs.play_card(0,idx,gs.player(1).units[0].uid) and p.energy==fire,"invalidrevivaltargetcostsnothing")
	check(gs.play_card(0,idx,a.uid) and a.hp==a.maxHp and u.hp==0 and gs.pending_choice.count==2,"reviveselectedallyfirstthenopenstwodivination")
	finish(gs)
	gs=game(); p=gs.player(0); knock(gs,0,0); knock(gs,0,2); deck(gs,["c27302","c11901"])
	Div.start(gs,0,2); place(gs,"c11901",false); place(gs,"c27302",true)
	check(p.units.filter(func(x):return x.hp<=0).size()==1 and p.deck[0].definitionId=="c27302","bottomrandomrevivereallyrevivesoneevenwithKOhostandretainscard")
	check(events(gs,"peach-growth").is_empty(),"revivaldoesnotborrowpeachgrowth")
	gs=game(); p=gs.player(0); deck(gs,["c27303","c11901"]); p.deck.back().eyeCurses=2; var actual:String=p.deck.back().instanceId
	Div.start(gs,0,2); place(gs,"c27303",true); place(gs,"c11901",false)
	check(p.hand.size()==1 and p.hand[0].instanceId==actual and p.hand[0].eyeCurses==2 and not p.deck.any(func(i):return i.instanceId==actual),"xiaowanwureturnsexactsameinstanceincludingcharmswithoutcopy")
	gs=game(); p=gs.player(0); deck(gs,["c27307","c11901"]); Div.start(gs,0,2); place(gs,"c27307",true); place(gs,"c11901",false)
	check(p.hand.size()==1 and p.hand[0].definitionId==Baize.DAZHI and p.deck[0].definitionId=="c27307","bottomSSRgeneratesactualmanualdazhiandstaysdeck")
	gs=game(); p=gs.player(0); deck(gs,["c27303"])
	for i in 12: give(gs,"c11901")
	Div.start(gs,0,1); place(gs,"c27303",true)
	check(p.hand.size()==12 and p.deck.is_empty() and events(gs,"baize-card-to-hand")[0].burned,"bottomreturnobeysactualhandcapwithoutduplicate")
func damage_and_war_skill() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); var u:Dictionary=p.units[0]; foe.units[1].front=1; gs._grow_unit(foe.units[1],0,5); var hp:int=foe.units[1].hp; var face:int=foe.avatarHp
	gs._grow_unit(u,2,0); play(gs,"c27304")
	check(foe.units[1].hp==hp-4 and foe.units[1].frozen>0 and foe.avatarHp==face and u.battleSkillId=="c27304","projectileusesactual4powerandstunsactualinjuredenemyandregisterswarspell")
	var count:int=p.deck.size(); var fire:int=p.energy; foe.units[1].shield=99; hp=foe.units[1].hp
	check(gs.basic_attack(0,0) and p.deck.size()==count+1 and p.energy==fire-1 and u.front==0,"actualwarspelldeploymentinsertsdazhiandconsumesbasicpaymentwithoutcombat")
	check(foe.units[1].hp==hp,"absorbedwarspelldealsnoHPdamage")
	gs=game(); foe=gs.player(1); foe.units[0].front=1; foe.units[0].shield=99; play(gs,"c27304")
	check(foe.units[0].frozen==0,"fullyabsorbedprojectilecannotstun")
	gs=game(); foe=gs.player(1); foe.units[0].front=1; foe.units[0].barrier=true; play(gs,"c27304"); check(foe.units[0].frozen==0,"barrierpreventsdamageandstun")
	gs=game(); foe=gs.player(1); face=foe.avatarHp; play(gs,"c27304"); check(foe.avatarHp==face-2 and foe.units.all(func(x):return x.frozen==0),"emptyfrontprojectilesavatarwithoutstunningarandomreserve")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[0].front=1; deck(gs,["c27304","c11901"]); var iid:String=p.deck.back().instanceId; fire=p.energy; hp=foe.units[0].hp
	Div.start(gs,0,2); place(gs,"c27304",true); place(gs,"c11901",false)
	check(foe.units[0].hp==hp-2 and foe.units[0].frozen>0 and p.energy==fire and not p.deck.any(func(i):return i.instanceId==iid),"bottomautomaticallyusesactualcardfreeandconsumesphysicaldeckinstance")
	check(p.units[0].battleSkillId=="c27304" and events(gs,"automatic-card").size()==1,"autousestillannouncesrealwarspell")
	gs=game(); p=gs.player(0); knock(gs,0,0); deck(gs,["c27304"]); Div.start(gs,0,1); place(gs,"c27304",true)
	check(p.deck.size()==1 and events(gs,"automatic-card").is_empty(),"KOhostcannotillegallyautousewarspell")
	gs=game(); foe=gs.player(1); deck(gs,["c11901","c11902"]); var hps:Array=foe.units.map(func(x):return x.hp)
	var decoy: Dictionary=gs.VerifiedRules.NativeSummons.summon(gs,1,0,"baize-decoy","普通召唤物",0,9,{"countsAsShikigami":false})
	play(gs,"c27303")
	check(foe.units[0].hp==hps[0]-2 and foe.units[1].hp==hps[1]-2 and gs.pending_choice.count==2,"allactualenemyshikigamitakedamagebeforedivination")
	check(decoy.hp==9,"群攻只伤式神，普通召唤物不受伤")
	finish(gs)
	gs=game(); foe=gs.player(1); var target:Dictionary=foe.units[1]; gs._grow_unit(target,0,5); hp=target.hp; play(gs,"c27305",target.uid)
	check(target.hp==hp-5 and foe.units[0].hp==foe.units[0].maxHp,"manualtimeflowusesselectedenemyandprinted5")
	gs=game(); foe=gs.player(1); deck(gs,["c27305"]); var total:int=0
	for x in foe.units: total+=int(x.hp)
	Div.start(gs,0,1); place(gs,"c27305",true); var after:int=0
	for x in foe.units: after+=int(x.hp)
	check(after==total-2 and gs.player(0).deck.size()==1,"bottomtimeflowrandom2withoutcasting5orconsumingcard")
func awakening_and_ssr() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); deck(gs,[Baize.DAZHI,Baize.DAZHI,"c11901","c11902"])
	play(gs,"c27306"); check(not p.units[0].awakened and not p.get("baizeAwakened",false),"printeddivination3precedesawakening")
	place(gs,Baize.DAZHI,true); place(gs,Baize.DAZHI,true); place(gs,"c11901",false)
	check(p.units[0].awakened and p.units[0].attack==3 and p.units[0].maxHp==6 and p.hand.is_empty(),"real1/1awakeningactivatesonlyafteritsownfirstdivination")
	check(not gs.can_play_card(0,give(gs,"c27306")).ok,"awakeningcannotrepeat")
	p.hand.clear(); deck(gs,[Baize.DAZHI,Baize.DAZHI,"c11901","c11902"]); Div.start(gs,0,3); place(gs,Baize.DAZHI,true); place(gs,Baize.DAZHI,true); place(gs,"c11901",false)
	check(p.hand.size()==1 and p.hand[0].definitionId=="c11901" and events(gs,"baize-awake-draw").size()==1,"twodazhibottomedinsameactualdivinationdrawexactlyone")
	knock(gs,0,0); p.hand.clear(); deck(gs,[Baize.DAZHI,"c11901"]); Div.start(gs,0,2); place(gs,Baize.DAZHI,true); place(gs,"c11901",false)
	check(p.units[0].hp==0 and p.hand.size()==1,"gamewideawakeningdrawpersistshostKO")
	gs=game(); p=gs.player(0); p.avatarHp=10; var uhp:int=p.units[0].hp
	deck(gs,["c27302","c27303",Baize.DAZHI,"c11901","c11902","c11903","c11904","c11905","c11906"]); play(gs,"c27307")
	check(gs.pending_choice.count==8 and p.hand.is_empty() and p.avatarHp==10,"SSRisactualeightcarddivinationwithnoprematurehealingordraw")
	for id in ["c27302","c27303",Baize.DAZHI]: place(gs,id,true)
	for id in ["c11901","c11902","c11903","c11904","c11905"]: place(gs,id,false)
	check(p.avatarHp==16 and p.units[0].hp==uhp and p.hand.size()==1 and p.hand[0].definitionId=="c27303","SSReachactualbaizebottomincludingdazhihealsavatar2onlynobodynofake2draw")
	gs=game(); p=gs.player(0); p.avatarHp=10; deck(gs,["c27301","c11901"]); play(gs,"c27307"); place(gs,"c27301",false); place(gs,"c11901",true)
	check(p.avatarHp==10,"SSRunevaluatedtopbaizeandbottomotherunitcannotheal")
func forms_and_cross_divination() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; play(gs,"c27301")
	check(u.attack==3 and u.maxHp==6 and u.formHooks.is_empty(),"historyoriginal3/6withoutfaketurnstartdraw")
	deck(gs,["c11901","c11902","c11903","c27302"]); Div.start(gs,0,2)
	check(gs.pending_choice.count==3 and Div.instance(gs,0,str(gs.pending_choice.originalIds[0])).definitionId=="c27302","historyactuallytutorsrandombaizecardfromwholedeckandincludesextra")
	finish(gs)
	deck(gs,["c11901","c11902","c11903"]); Div.start(gs,0,2); check(gs.pending_choice.count==2,"nohistorybonuswhennobaizecardindeck"); finish(gs)
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c27308"); var a:Dictionary=p.units[1]; var power:int=a.attack; var hp:int=a.hp
	deck(gs,["c11901","c11902","c27302"]); Div.start(gs,0,3)
	check(u.attack==5 and u.maxHp==7 and a.attack==power+2 and a.hp==hp+2 and a.baizeTemporary==2,"causeoriginal4/6grantsrealtemporary1/1pereachrevealedcard")
	finish(gs); play(gs,"c27301"); check(a.attack==power+2,"alreadygrantedturnbuffsurvivesformreplacement")
	gs.end_turn(0); check(a.attack==power and a.maxHp==hp and not a.has("baizeTemporary"),"allcausebonusesexpireatactualturnend")
	gs=game(); p=gs.player(0); play(gs,"c27308"); deck(gs,["c11901"]); Div.start(gs,0,1); finish(gs); knock(gs,0,1)
	check(p.units[1].attackBonus==0 and p.units[1].maxHpBonus==0,"KOremovesactualtemporarybonuses")
	gs.VerifiedRules.Peach.revive(gs,0,3,p.units[1],false,false); gs.end_turn(0); check(p.units[1].attack==Content.unit_def("shuweng").attack,"revivedunitcannotretainorlosegrowthtwice")
	gs=game(); p=gs.player(0); play(gs,"c27308"); play(gs,"c27301"); deck(gs,["c11901"]); var before:int=p.units[1].attack; Div.start(gs,0,1); finish(gs)
	check(p.units[1].attack==before,"causeformleavingstopssubsequentdivinationgrowth")
	gs=game(); deck(gs,["c11901","c11902"]); gs.start_divination(0,{"divination":{"count":2}}, {})
	check(gs.pending_choice.type=="native-divination","otherlegacyactualdivinationroutesnativewhenbaizeispresent"); finish(gs)
	gs.start_divination(0,{"divination":{"count":1}}, {},false); check(gs.pending_choice.type=="divination","nondivinationtopdeckchoicesarenotconverted")
func cross_trigger_order() -> void:
	var gs:=game(["baize","baimugui","shantong","taohuayao"]); var p:Dictionary=gs.player(0)
	p.baizeAwakened=true; deck(gs,[Baize.DAZHI,"c11901","c11902"])
	Div.start(gs,0,2); place(gs,Baize.DAZHI,true); place(gs,"c11901",false)
	var draw_index:=-1; var eye_index:=-1
	for n in gs.rule_events.size():
		var e:Dictionary=gs.rule_events[n]
		if e.kind=="baize-awake-draw": draw_index=n
		if e.kind=="ability-trigger" and e.get("reason")=="占卜投射": eye_index=n
	check(draw_index>=0 and eye_index>draw_index and p.hand.size()==1,"awakeneddrawactuallysettlesbeforeEyeprojectile")
	gs=game(); p=gs.player(0); p.units[0].frozen=1; deck(gs,["c27304"]); Div.start(gs,0,1); place(gs,"c27304",true)
	check(p.deck.size()==1 and events(gs,"automatic-card").is_empty(),"stunnedhostcannotautocastbottomspell")
	gs=game(); p=gs.player(0); deck(gs,["c11901","c11902","c11903"]); p.keywordUsage.instant={"used":true}; var fire:int=p.energy
	play(gs,Baize.DAZHI); finish(gs)
	check(p.energy==fire-1,"dazhipaysprintedoneafterinstantallowanceisused")
	gs=game(); p=gs.player(0); play(gs,"c27308"); deck(gs,["c10301"],1); var enemy:Dictionary=gs.player(1).units[0]; var enemy_power:int=enemy.attack; var own_power:int=p.units[0].attack
	Div.start(gs,1,1,0)
	check(enemy.attack==enemy_power+1 and p.units[0].attack==own_power,"revealedcardgrowthbelongstoactualcardownershikigaminotcontroller")
	finish(gs); gs.end_turn(0); check(enemy.attack==enemy_power,"opponentdeckrevealgrowthisalsotemporary")
	gs=game(); p=gs.player(0); deck(gs,["c27304"]); var size_before:int=p.deck.size(); Div.start(gs,0,1); place(gs,"c27304",false)
	check(p.deck.size()==size_before and events(gs,"automatic-card").is_empty(),"topplacedcardsneverfirebottomabilities")
func ai_and_queries() -> void:
	for n in range(1,10):
		var gs:=game(); var id:="c273%02d"%n if n<9 else Baize.DAZHI
		if n==2: knock(gs,0,2)
		deck(gs,["c11901","c11902","c11903","c11904","c11905","c11906","c11907","c11908","c27303"]); give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegaloriginal "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIusesoriginal "+id); finish(gs)
		check(Content.card_def(id).cost==1 and (n==9 or FileAccess.file_exists("res://assets/official/cards/"+id+".png")),"originalcostandart "+id)
	var gs:=game(); var p:Dictionary=gs.player(0); give(gs,"c27305"); var stamp:=JSON.stringify(gs.snapshot()); gs.hand_card_def(0,0); gs.valid_targets(0,gs.hand_card_def(0,0)); gs.can_play_card(0,0,gs.player(1).units[0].uid)
	check(JSON.stringify(gs.snapshot())==stamp,"allqueriesleaveknowledgeanddeckuntouched")
	gs.player(1).units[0].foxVeil=true; check(not gs.valid_targets(0,gs.hand_card_def(0,0)).has(gs.player(1).units[0].uid),"manualtargetrespectsveil")
	gs=game(); p=gs.player(0); p.nullifyNextCardTurn=gs.turn_counter; deck(gs,["c11901","c11902"]); play(gs,Baize.DAZHI)
	check(gs.pending_choice.is_empty() and p.hand.is_empty() and p.deck.size()==2,"countereddazhicannotdivineordraw")
func scroller(n: Node) -> ScrollContainer:
	if n is ScrollContainer: return n
	for child in n.get_children():
		var result:=scroller(child)
		if result!=null: return result
	return null
func ui_place(b,id: String,bottom: bool) -> void:
	var tile:=choice_face(b,id); check(tile!=null,"nativeactualinstanceface "+id)
	if tile!=null: await click(tile)
	await settled(b)
	var placement:=choice_face(b,Div.BOTTOM if bottom else Div.TOP); check(placement!=null,"nativelegalplacementbutton")
	if placement!=null: await click(placement)
	await settled(b)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["baize","shuweng","shantong","taohuayao"],["bingyong","fenghuanghuo","xuenv","baizangzhu"],273); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for x in side.units: x.level=3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs=b.gs; var p:Dictionary=gs.player(0); deck(gs,["c11901","c11902","c11903"]); hand(b,[Baize.DAZHI]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("count")==2 and texts(b._choice_layer).contains("至少置底"),"nativedazhiopensrealminimumbottomchoice")
		await ui_place(b,"c11901",false); await click(choice_face(b,"c11902")); await settled(b)
		check(choice_face(b,Div.TOP)==null and choice_face(b,Div.BOTTOM)!=null,"nativelastcardexposesonlymandatorybottom")
		await capture("%d-01-required-bottom"%physical.x)
		await click(choice_face(b,Div.BOTTOM)); await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.size()==1 and p.hand[0].definitionId=="c11901","nativemousefinishesminimumandresumesmandatorydraw")
		knock(gs,0,0); knock(gs,0,2); deck(gs,["c11901","c11902"]); hand(b,["c27302"]); await settled(b); var fire:int=p.energy
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"nativereviveinvalidlivingtargetcannotpay")
		await capture("%d-02-ko-revive-target"%physical.x)
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(p.units[0].hp==p.units[0].maxHp and p.units[2].hp==0 and gs.pending_choice.get("count")==2,"nativerealKOsourcechoosesselfrevivethendivines")
		await ui_place(b,"c11901",false); await ui_place(b,"c11902",false)
		deck(gs,["c27301","c27302","c27303","c27304","c27305","c27306","c27307","c27308","c11901"]); p.avatarHp=10; hand(b,["c27307"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("count")==8 and faces(b._choice_layer).size()==8,"nativeSSRrenderseightrealindividualcards")
		var scroll:=scroller(b._choice_layer); check(scroll!=null and scroll.get_h_scroll_bar().max_value>scroll.size.x,"nativeeightcardchooserhashorizontalscroll")
		if scroll!=null: scroll.scroll_horizontal=int(scroll.get_h_scroll_bar().max_value)
		await settled(b); var last:=choice_face(b,"c27308")
		check(last!=null and last.get_global_rect().get_center().x<root.size.x,"lastofeightcardsisreachableinscreen")
		await capture("%d-03-eight-card-scroll"%physical.x)
		await ui_place(b,"c27308",true)
		finish(gs); b._refresh(); await settled(b)
		check(gs.pending_choice.is_empty() and p.avatarHp>10 and not is_instance_valid(b._choice_layer),"nativeSSRresumesrealhealbottomtriggersandcloseschoice")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	base_and_dazhi(); revival_and_bottoms(); damage_and_war_skill(); awakening_and_ssr(); forms_and_cross_divination(); cross_trigger_order(); ai_and_queries()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("BAIZE_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]); quit(0 if failures==0 else 1)
