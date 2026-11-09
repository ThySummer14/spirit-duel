extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Marks := preload("res://scripts/hand_blessing_rules.gd")
const Pair := preload("res://scripts/koi_fragrance_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("KOI_FRAGRANCE_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["liyujing","xunxiangxing","shuweng","shantong"],["liyujing","xunxiangxing","shuweng","shantong"],282288)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.rule_events.clear(); return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"instanceId":"pair-%d"%gs.next_card_id,"definitionId":id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,owner: int=0) -> void:
	var idx:=give(gs,id,owner); var why:Dictionary=gs.can_play_card(owner,idx,target)
	check(gs.play_card(owner,idx,target),"actualplay "+id+" "+str(why))
func choose(gs) -> void:
	check(not gs.pending_choice.is_empty(),"expectedchoice")
	if not gs.pending_choice.is_empty(): check(gs.resolve_divination_choice(int(gs.pending_choice.playerIndex),str(gs.pending_choice.instanceIds[0])),"actualchoice")
func finish(gs) -> void:
	var guard:=0
	while not gs.pending_choice.is_empty() and guard<30:
		check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"AIresolvesactualchoice"); guard+=1
	check(guard<30,"finitecontinuations")
func marked(gs,id: String,which: String,effects: Array,owner: int=0) -> int:
	var i:=give(gs,id,owner); Marks.apply_mark(gs,1-owner if which=="erosion" else owner,owner,gs.player(owner).hand[i],which,effects); return i
func events(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func mark_contract() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0)
	for id in ["c28201","c28202","c28203","c28204"]: give(gs,id)
	var stamp:=JSON.stringify(p.hand); Marks.start(gs,0,"ward")
	check(gs.pending_choice.instanceIds.size()==2 and JSON.stringify(p.hand)==stamp,"twoactualrandomcandidatesandprerollwithoutmutation")
	for iid in gs.pending_choice.instanceIds:
		var c:Dictionary=Marks.choice_card(gs,0,iid); check(not c.choiceExplanation.is_empty() and not c.effectReplacementText.is_empty(),"visibleprerolledactualeffect")
	check(JSON.stringify(p.hand)==stamp and not gs.resolve_divination_choice(1,str(gs.pending_choice.instanceIds[0])) and not gs.resolve_divination_choice(0,"bad-iid"),"previewpureandinvalidchoiceblocked")
	var selected:String=gs.pending_choice.instanceIds[0]; choose(gs)
	check(p.hand.filter(func(i):return Marks.kind(i)=="ward").size()==1 and Marks.kind(Marks.instance(gs,0,selected))=="ward","onlyselectedinstancechanges")
	var inst:=Marks.instance(gs,0,selected)
	check(not inst.get("revealed",false) and not Marks.apply_mark(gs,0,0,inst,"ward",["draw"]),"wardnotrevealedandnoduplicatemark")
	check(not Marks.apply_mark(gs,1,0,inst,"erosion",["spell-2"]) and Marks.kind(inst)=="" and not inst.get("revealed",false),"oppositemarkcancelswithouthiddenmetadata")
	check(Marks.apply_mark(gs,1,0,inst,"erosion",["spell-2"]) and inst.revealed and Marks.eligible(gs,1,"erosion").size()==3,"erosionrevealsactualcardandcannotretargetsamekind")
	Marks.apply_mark(gs,0,0,inst,"ward",["instant"]); check(not inst.revealed and not inst.has("handCharm"),"cancellationrestorespriorvisibility")
	for type in ["spell","awakening","combat","form","realm"]:
		for which in ["ward","erosion"]:
			var pool:=Marks.pool({"type":type},which); var unique:Dictionary={};
			for e in pool: unique[e]=true
			check(pool.size()>=4 and pool.size()==unique.size(),"distincttypepool "+type+which)
func koi_cards() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var u:Dictionary=p.units[0]; var old:int=u.attack
	give(gs,"c28201"); play(gs,"c28201"); check(gs.phase=="choice" and u.shield==0,"bubbleguardactualwardnotfakearmor"); choose(gs)
	check(u.attack==old+1 and u.maxHp==4,"ordinarybasepoweronly"); Pair.end_turn(gs); check(u.attack==old,"ordinarygrowthendsactualturn")
	gs=game(); p=gs.player(0); p.avatarHp=20; marked(gs,"c28201","ward",["instant"]); give(gs,"c28203"); play(gs,"c28202")
	check(p.avatarHp==20,"healingwaitsforchoice"); choose(gs); check(p.avatarHp==22,"healcountsactualmarkedcardsafterselection")
	gs=game(); p=gs.player(0)
	for id in ["c28201","c28202","c28204","c28205"]: give(gs,id)
	play(gs,"c28203"); check(gs.pending_choice.instanceIds.size()==3 and p.units[0].hp==5,"3/5entryandactualextraofferedcard"); choose(gs)
	gs=game(); p=gs.player(0); give(gs,"c28201"); play(gs,"c28204"); check(p.realms.size()==1 and p.realms[0].hp==6,"6durrealrealm"); choose(gs)
	gs._knockout_unit(p.units[0],1,0); give(gs,"c28202"); Pair.turn_start(gs,0); gs._resolve_resolution_stack(); check(gs.phase=="choice","realmpersistswithKOsource"); choose(gs)
	check(p.units[0].knockout==2,"KOkoibasecannotreduceitsowncountdownthroughpersistingrealm")
	gs=game(); p=gs.player(0); gs._knockout_unit(p.units[2],1,0); give(gs,Content.cards_for_unit("shuweng")[0].id); Marks.start(gs,0,"ward"); choose(gs)
	check(p.units[2].knockout==1,"livingkoireducescorrespondingKOshikigamiactualcountdown")
	gs=game(); p=gs.player(0); give(gs,"c28201"); var ownhp:int=p.units[3].hp; var foehp:int=gs.player(1).units[0].hp
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs,0,0,"koi-decoy","普通召唤物",0,9,{"countsAsShikigami":false})
	check(not gs.valid_targets(0,Content.card_def("c28205")).has(decoy.uid),"鲤鱼精甩尾不能指定普通召唤物")
	play(gs,"c28205",p.units[3].uid); check(p.units[3].hp==maxi(0,ownhp-4) and gs.player(1).units[0].hp==foehp and gs.phase=="choice","tailwhipcanactuallyselectownunitthenward"); choose(gs)
	gs=game(); p=gs.player(0); give(gs,"c28201"); play(gs,"c28206"); check(not p.units[0].awakened,"wardbeforeawakening"); choose(gs)
	check(p.units[0].awakened and p.units[0].attack==5 and p.units[0].maxHp==5,"printedawakeningandpreawakeordinarygrowth"); Pair.end_turn(gs)
	var idx:=give(gs,"c28202"); Marks.start(gs,0,"ward"); choose(gs); check(p.units[0].attack==5 and p.units[0].maxHp==6,"awakewardgrowsbothstats")
	gs._knockout_unit(p.units[0],1,0); check(p.units[0].attack==4 and p.units[0].maxHp==5 and p.units[0].awakened,"KOremovesordinaryawakegrowthpreservingawakening")
	check(not gs.can_play_card(0,give(gs,"c28206")).ok,"repeatawakeningillegal")
	gs=game(); p=gs.player(0); p.deck.clear()
	for id in ["c28201","c28202","c28204"]: p.deck.append({"instanceId":"deck-"+id,"definitionId":id})
	play(gs,"c28207"); check(p.hand.size()==2 and gs.phase=="choice","playdrawtwobeforefirstward"); choose(gs); check(gs.phase=="choice","secondwardwaitsfirstchoice"); choose(gs)
	check(p.hand.filter(func(i):return Marks.kind(i)=="ward").size()==2,"twoseparateselectedinstances")
	gs=game(); p=gs.player(0); give(gs,"c28201"); play(gs,"c28208")
	check(p.units[0].form.cardId=="c28208" and p.units[0].maxHp==7 and gs.phase=="choice","4/7entrydrawtriggersward")
	for iid in gs.pending_choice.instanceIds: check(gs.pending_choice.effects[iid].size()==2 and gs.pending_choice.effects[iid][0]!=gs.pending_choice.effects[iid][1],"SSRtwodistincteffectsononecard")
	choose(gs); var before:=events(gs,"hand-charm-attached").size(); gs._draw(0,2); gs._resolve_resolution_stack()
	check(gs.pending_choice.is_empty() and events(gs,"hand-charm-attached").size()==before,"drawwardonlyoncethisactualturn")
	gs.turn_counter+=1; gs._draw(0,2); gs._resolve_resolution_stack(); check(gs.phase=="choice","drawwardresetsactualturn"); finish(gs)
func fragrance_cards() -> void:
	var gs:=game(); var foe:Dictionary=gs.player(1); give(gs,"c28201",1); var hp:int=foe.avatarHp
	play(gs,"c28801"); check(foe.avatarHp==hp,"projectilewaitsmarkchoice"); choose(gs)
	check(foe.avatarHp==hp-1 and foe.units[0].get("frozen",0)>0,"livecorrespondingshikigamistunnedafterrealprojectile")
	gs=game(); foe=gs.player(1); gs._knockout_unit(foe.units[0],0,1); give(gs,"c28201",1); play(gs,"c28801"); choose(gs)
	check(foe.get("avatarFrozen",0)>0,"KOcardstunsactualavatar")
	gs=game(); foe=gs.player(1); give(gs,"c28201",1); play(gs,"c28802"); check(gs.VerifiedRules.Combat.has(gs.player(0).units[1],"remote"),"3/5actualremoteform")
	gs._damage_avatar(1,2,0,2); gs._resolve_resolution_stack(); check(gs.pending_choice.is_empty(),"noncombatdamagecannottriggerbattleform")
	gs.basic_attack(0,2); check(gs.phase=="choice","friendlybasicavatarcombatreallytriggerserosion"); choose(gs)
	give(gs,"c28202",1); gs.player(0).units[3].inspired=true; gs.basic_attack(0,3); check(gs.pending_choice.is_empty(),"battleformonceperturn")
	gs=game(); foe=gs.player(1); give(gs,"c28201",1); play(gs,"c28803"); check(gs.player(0).realms[0].hp==5,"real5durpressure"); choose(gs)
	check(gs.kw_usage(1,"encourage").attack==-1 and gs.kw_usage(1,"encourage").shield==-1,"actualnextenemybasicdebuffandarmorbreak")
	gs=game(); foe=gs.player(1); gs._grow_unit(foe.units[2],0,10); hp=foe.units[2].hp; give(gs,"c28201",1); play(gs,"c28804",foe.units[2].uid)
	check(foe.units[2].hp==hp-4 and gs.phase=="choice","selected4damagebeforeerosionnotnewerversion5"); choose(gs)
	gs=game(); foe=gs.player(1); give(gs,"c28201",1); hp=foe.avatarHp; play(gs,"c28805"); check(not gs.player(0).units[1].awakened,"erosionbeforeawake"); choose(gs)
	check(foe.avatarHp==hp-1 and gs.player(0).units[1].awakened,"awakeningmarkstilloneprojectile")
	give(gs,"c28202",1); Marks.start(gs,0,"erosion"); choose(gs); check(foe.avatarHp==hp-3,"futuremarktwoprojectile")
	gs=game(); foe=gs.player(1)
	for id in ["c28201","c28202","c28203","c28204"]:give(gs,id,1)
	play(gs,"c28806"); var offered:Array=gs.pending_choice.instanceIds.duplicate(); var kept:String=offered[0]; choose(gs)
	check(foe.hand.size()==3 and not Marks.instance(gs,1,kept).is_empty() and Marks.instance(gs,1,str(offered[1])).is_empty(),"discardonlyunselectedofferednotwholehand")
	gs=game(); foe=gs.player(1); give(gs,"c28201",1)
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs,1,0,"fragrance-decoy","普通召唤物",0,9,{"countsAsShikigami":false})
	var hps:Array=foe.units.map(func(u):return u.hp); play(gs,"c28807")
	check(foe.units.map(func(u):return u.hp)==hps,"AOEwaitschoice"); choose(gs)
	for i in 4: check(foe.units[i].hp==maxi(0,int(hps[i])-3),"AOEallfouraftermark "+str(i))
	check(decoy.hp==8 and events(gs,"fragrance-projectile").any(func(e):return e.target==decoy.uid),"普通召唤物只受蚀印的独立投射，排除随后式神群伤")
func forced_legality() -> void:
	var gs:=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1)
	gs._install_form(1,1,Content.card_def("c28808"),{"attack":5,"hp":7,"setBase":true}); gs.resolution_stack.clear()
	marked(gs,"c28201","erosion",["no-instant"]); var other:=give(gs,"c28802"); var stamp:=JSON.stringify(gs.snapshot())
	check(not gs.can_play_card(0,other).ok and gs.can_play_card(0,0).ok,"SSRrequiresactuallyplayableerodedcardfirst")
	check(JSON.stringify(gs.snapshot())==stamp,"recursivelegalquerydoesnotspendallowanceormutate")
	p.energy=0; check(gs.can_play_card(0,other).ok==false and not Pair.has_playable_erosion(gs,0),"zerofireerodedcardnotfalselyplayable")
	p.energy=40; p.units[0].level=0; check(gs.can_play_card(0,other).ok,"underlevelerodedcarddoesnotblocklegalother"); p.units[0].level=3
	check(gs.play_card(0,0),"actualerodedplayreleasesforce"); finish(gs); check(gs.can_play_card(0,p.hand.find(p.hand.filter(func(i):return i.definitionId=="c28802")[0])).ok,"restrictionreleasedafteroneuse")
	give(gs,"c28202"); marked(gs,"c28201","erosion",["no-instant"]); gs.turn_counter+=1
	check(not gs.can_play_card(0,0).ok,"forceallowanceresetsactualturn")
	gs=game(); gs._install_form(1,1,Content.card_def("c28808"),{"attack":5,"hp":7,"setBase":true}); gs.resolution_stack.clear()
	marked(gs,"c28804","erosion",["no-instant"]); other=give(gs,"c28203")
	for u in gs.player(1).units:u.hp=0
	check(gs.can_play_card(0,other).ok,"nolivingtargetmeanserodedtargetedspellcannotforce")
func effect_runtime() -> void:
	for spec in [["ward","spell+1",5],["erosion","spell-2",2]]:
		var gs:=game(); var target:Dictionary=gs.player(1).units[2]; gs._grow_unit(target,0,10); var hp:int=target.hp
		var i:=marked(gs,"c28804",spec[0],[spec[1]]); check(gs.play_card(0,i,target.uid) and target.hp==hp-int(spec[2]),"actualspellmodifier "+spec[1]); finish(gs)
	var gs:=game(); var i:=marked(gs,"c28201","ward",["instant"]); check(gs.card_payment(0,gs.hand_card_def(0,i)).cost==0,"instantactualpayment")
	Marks.apply_mark(gs,1,0,gs.player(0).hand[i],"erosion",["no-instant"]); Marks.apply_mark(gs,1,0,gs.player(0).hand[i],"erosion",["no-instant"])
	check(gs.card_payment(0,gs.hand_card_def(0,i)).cost==1,"erodedinstantremoved")
	for spec in [["ward","form+1+1",4,6],["erosion","form-2-1",1,4],["ward","gain-pierce",4,5]]:
		gs=game(); i=marked(gs,"c28203",spec[0],[spec[1]]); check(gs.play_card(0,i) and gs.player(0).units[0].attack==spec[2] and gs.player(0).units[0].hp==spec[3],"actualformstats "+spec[1]); finish(gs)
	gs=game(); var dummy:Dictionary=Content.card_def("c28203").duplicate(true); dummy.value.hp=2; var inst:={"handCharm":{"kind":"erosion","effects":["form-0-3"]}}
	check(not Marks.can_use(Marks.describe_card(gs,0,inst,dummy)),"nonpositiveHPformillegal")
	for spec in [["ward","realm+4",10],["erosion","realm-half",3]]:
		gs=game(); i=marked(gs,"c28204",spec[0],[spec[1]]); check(gs.play_card(0,i) and gs.player(0).realms[0].hp==spec[2],"actualrealmhp "+spec[1]); finish(gs)
	for effect in ["hit-enemy","hurt-avatar","heal-enemy","hurt-source","encourage","suppress","draw","heal-self"]:
		gs=game(); var p:Dictionary=gs.player(0); var foe:Dictionary=gs.player(1); p.avatarHp=20; foe.avatarHp=20; p.units[0].hp=1
		i=marked(gs,"c28201","ward",[effect]); check(gs.play_card(0,i),"actualposteffectcard "+effect)
		match effect:
			"hit-enemy": check(foe.avatarHp==17,"postenemy3")
			"hurt-avatar": check(p.avatarHp==17,"postself3")
			"heal-enemy": check(foe.avatarHp==23,"postenemyheal3")
			"hurt-source": check(p.units[0].hp==0,"postsource3actualKO")
			"encourage": check(gs.kw_usage(0,"encourage").attack==2 and gs.kw_usage(0,"encourage").shield==1,"postrealencourage")
			"suppress": check(gs.kw_usage(0,"encourage").attack==-2 and gs.kw_usage(0,"encourage").shield==-1,"postrealnegativeencourage")
			"draw": check(p.hand.size()==1,"postactualdraw")
			"heal-self": check(p.units[0].hp==p.units[0].maxHp,"postactualsourceheal")
func additional_boundaries() -> void:
	for spec in [["ward","combat+1+1",3,3],["erosion","combat-2-1",0,1],["erosion","combat-1-2",1,0]]:
		var gs:=GS.create(["yaodaoji","liyujing","shuweng","shantong"],["liyujing","xunxiangxing","shuweng","shantong"],282288)
		for p in gs.players:
			p.hand.clear(); p.energy=40
			for u in p.units:u.level=3
		var power:int=gs.player(0).units[0].attack; var hp:int=gs.player(1).avatarHp
		var i:=marked(gs,"c10103",spec[0],[spec[1]])
		check(gs.play_card(0,i) and gs.player(1).avatarHp==hp-power-int(spec[2]) and gs.player(0).units[0].shield==spec[3],"actualcombatpowerandarmor "+spec[1])
	var gs:=GS.create(["xuzuozhinan","liyujing","shuweng","shantong"],["liyujing","xunxiangxing","shuweng","shantong"],281)
	for p in gs.players:
		p.hand.clear(); p.energy=40
		for u in p.units:u.level=3
	var face:int=gs.player(1).avatarHp; var i:=marked(gs,"c28104","ward",["combat+1+1"])
	check(gs.play_card(0,i) and gs.player(1).avatarHp==face-3 and gs.player(0).units[0].shield==3,"nativecustomcombatalsoreceivesactualcharmbonusonce")
	gs=game(); gs.player(0).realms.append({"hp":3,"nativeRealm":"fixture"}); i=marked(gs,"c28204","ward",["realm-others"])
	check(gs.play_card(0,i) and gs.player(0).realms[0].hp==4 and gs.player(0).realms[1].hp==6,"realmraisesotherdurabilityonly"); finish(gs)
	for key in ["swift","pierce","pursuit","unyielding","barrier","inspired"]:
		gs=game(); i=marked(gs,"c28203","ward",["gain-"+key]); check(gs.play_card(0,i),"keywordformactualuse "+key); finish(gs)
		var u:Dictionary=gs.player(0).units[0]
		check(gs.VerifiedRules.Combat.has(u,key) if key in ["pierce","pursuit","inspired"] else bool(u.get(key,false)),"installedactualkeyword "+key)
	gs=game(); var c:Dictionary=Content.card_def("c28203").duplicate(true); c.formRules.combatKeywords=["pierce"]; c.keywords=["pierce"]
	c=Marks.describe_card(gs,0,{"handCharm":{"kind":"erosion","effects":["lose-pierce"]}},c); gs._install_form(0,0,c,c.value); gs.resolution_stack.clear()
	check(not gs.VerifiedRules.Combat.has(gs.player(0).units[0],"pierce") and gs.player(0).units[0].attack==2,"erosionstripsactualformkeywordandpower")
	gs=game(); gs._card_effect_context={"playerIndex":0,"sourceIndex":1,"affectedUnits":[],"cardOverride":{"handCharmDamage":-2}}; var hp:int=gs.player(1).units[0].hp
	check(gs._damage_unit(1,0,1,0,1).damage==0 and gs.player(1).units[0].hp==hp,"negativefalldamagestopsatzero")
	gs._card_effect_context.cardOverride.handCharmDamage=1; gs._grow_unit(gs.player(1).units[0],0,10); hp=gs.player(1).units[0].hp
	gs._damage_unit(1,0,4,0,1,false,-1,false,false,true); check(gs.player(1).units[0].hp==hp-4,"alreadyredirectedamountnotmodifiedtwice")
	gs=game(); gs._install_form(0,0,Content.card_def("c28208"),{"attack":4,"hp":7,"setBase":true}); gs.resolution_stack.clear(); give(gs,"c28201"); gs.current_player=1
	gs._draw(0,2); gs._resolve_resolution_stack(); check(gs.pending_choice.get("playerIndex")==0 and gs.pending_choice.get("zoneOwner")==0,"offturnfirstdrawstillownwardchoice"); finish(gs)
	check(gs.player(0).hand.size()==3 and gs.phase=="main","offturndrawcontinuationpreservesbothcards")
	gs=game(); gs.player(0).nullifyNextCardTurn=gs.turn_counter; i=marked(gs,"c28201","ward",["hit-enemy"]); face=gs.player(1).avatarHp
	check(gs.play_card(0,i) and gs.pending_choice.is_empty() and gs.player(1).avatarHp==face,"counteredcardcannotapplymainorposteffect")
	gs=game(); give(gs,"c28202"); i=marked(gs,"c28201","ward",["hit-enemy"]); face=gs.player(1).avatarHp
	check(gs.play_card(0,i) and gs.phase=="choice" and gs.player(1).avatarHp==face,"posteffectwaitsentiremainchoice"); choose(gs); check(gs.player(1).avatarHp==face-3,"posteffectresumesexactlyonceaftermainchoice")
func ai_cards() -> void:
	for prefix in ["c282","c288"]:
		for n in range(1,9):
			var gs:=game(); var id:String=prefix+"%02d"%n; give(gs,"c28201",1); give(gs,"c28202"); give(gs,id)
			# Keep only the actual card for AI selection; ward can choose the drawn/remaining hand or resolve with no candidate.
			gs.player(0).hand.remove_at(0); var best:=AI._best_card(gs,0)
			check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegal "+id)
			check(best.ok and gs.play_card(0,best.hand,best.target),"AIactual "+id); finish(gs)
			check(Content.card_def(id).cost==1 and FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalcostandPNG "+id)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["liyujing","xunxiangxing","shuweng","shantong"],["liyujing","xunxiangxing","shuweng","shantong"],282288); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units:u.level=3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		hand(b,["c28201","c28202","c28203"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.phase=="choice" and faces(b._choice_layer).size()==2,"nativeactualwardtwochoices")
		var face:=choice_face(b); check(not face.data.choiceExplanation.is_empty() and texts(b._choice_layer).contains(face.data.choiceExplanation),"nativevisibleeffectdescription")
		check(face.get_global_rect().end.y<root.size.y,"nativecardinsideviewport"); await capture("%d-01-ward-choice"%physical.x)
		await click(face); await settled(b); check(b.gs.player(0).hand.filter(func(inst):return Marks.kind(inst)=="ward").size()==1,"nativemouseattachesselectedward")
		hand(b,["c28201","c28202","c28203","c28204"],1); hand(b,["c28806"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.pending_choice.get("which")=="erosion" and faces(b._choice_layer).size()==2,"nativeopponenthandchoice")
		await capture("%d-02-erosion-discard-choice"%physical.x); await click(choice_face(b)); await settled(b)
		check(b.gs.player(1).hand.size()==3 and b.gs.player(1).hand.filter(func(inst):return inst.get("revealed",false) and Marks.kind(inst)=="erosion").size()==1,"nativeactualdiscardandrevealedchoseninstance")
		b.gs._install_form(1,1,Content.card_def("c28808"),{"attack":5,"hp":7,"setBase":true}); b.gs.resolution_stack.clear(); hand(b,["c28201","c28802"])
		Marks.apply_mark(b.gs,1,0,b.gs.player(0).hand[0],"erosion",["no-instant"]); b._last_view={}; b._refresh(); await settled(b)
		check(not b.gs.can_play_card(0,1).ok and b.gs.can_play_card(0,0).ok,"nativeSSRlegalhandrestriction"); await click(b._hand_row.get_child(1)); await settled(b)
		check(b.gs.player(0).hand.size()==2 and b.gs.player(0).units[1].get("form",{}).get("cardId","")!="c28802","nativeblockedcardcannotpayorinstall")
		await capture("%d-03-forced-eroded-hand"%physical.x); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.phase=="choice","nativeerodedcardlegallyplaysandstartsward"); await click(choice_face(b)); await settled(b)
		check(b.gs.can_play_card(0,0).ok,"nativemouseuseunlocksremainingcard")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	mark_contract(); koi_cards(); fragrance_cards(); forced_legality(); effect_runtime(); additional_boundaries(); ai_cards()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("KOI_FRAGRANCE_OK checks=%d failures=%d rules_only=%s"%[checks,failures,rules_only]); quit(0 if failures==0 else 1)
