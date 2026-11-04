extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Otake := preload("res://scripts/otakemaru_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("OTAKEMARU_FAIL ",detail)
func game(mirror: bool = false) -> GS:
	var gs:=GS.create(["dayueling","fenghuanghuo","yanmo","taohuayao"],["dayueling" if mirror else "yaodaoji","bingyong","fenghuanghuo","baizangzhu"],190)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.rule_events.clear()
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"otake-card-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual command "+id)
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func jade_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(u.attack==3 and u.maxHp==4 and Content.unit_def("dayueling").passive.hooks.is_empty(),"exact3/4source no oldturngrowth")
	play(gs,"c19001")
	check(u.attack==5 and u.maxHp==4 and gs.player(1).avatarHp==25,"穿 attachesrealbase1plusself1 beforeexact5powercombat")
	check(Otake.owned(gs,0).unit.uid==u.uid and u.otakeJades.size()==1 and p.energy==39,"oneowneronephysicaljade actualcost")
	var old_uid: String=u.otakeJades["0"].uid
	play(gs,"nuoyi",p.units[1].uid)
	check(not u.has("otakeJades") and u.attack==3 and p.units[1].attack==3,"relocate removes oldbonus andgives allybase1only")
	check(p.units[1].otakeJades["0"].uid!=old_uid and p.units[1].maxHp==4,"unique reattachmentnewphysicalinstance nohealthbuff")
	play(gs,"nuoyi",p.units[1].uid)
	check(p.units[1].attack==3 and p.units[1].otakeJades.size()==1,"repeatedsamehost doesnotstackjadebonus")
	Otake.remove_charm(gs,0,1,"test cleanse")
	check(p.units[1].attack==2 and not p.units[1].has("otakeJades"),"actual removal stripsonlyjadepower")
	gs=game(true); p=gs.player(0); var foe: Dictionary=gs.player(1)
	Otake.attach(gs,1,0,1,0)
	play(gs,"c19004",foe.units[0].uid)
	check(foe.units[0].otakeJades.size()==2 and foe.units[0].attack==7,"opposingownersuniquejades coexist andeachgrantsrealpower")
	check(Otake.owned(gs,0).player==1 and Otake.owned(gs,1).player==1,"ownerofjade distinctfromhostplayer")
	play(gs,"nuoyi",p.units[0].uid)
	check(foe.units[0].otakeJades.size()==1 and foe.units[0].attack==5 and p.units[0].attack==5,"moving ownjade leaves opposingjade and itsfullpower")

func cover_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	play(gs,"c19002",u.uid)
	check(u.otakeCover and u.attack==5 and not u.unyielding and not u.get("barrier",false),"cover truejade plusindependentnextdamageimmunity")
	play(gs,"nuoyi",p.units[1].uid)
	check(u.otakeCover and u.attack==3 and p.units[1].attack==3,"movingjade leavescoveronoriginalhost")
	u.shield=2; u.armorBreak=1
	var hit: Dictionary=gs._damage_unit(0,0,99,1,0); gs._resolve_resolution_stack()
	check(hit.damage==0 and u.hp==4 and u.shield==2 and u.armorBreak==1 and not u.get("otakeCover",false),"cover blocksonearbitraryspell beforearmor/break, notjustlethal")
	hit=gs._damage_unit(0,0,1,1,0); gs._resolve_resolution_stack()
	check(u.shield==0 and u.armorBreak==0 and u.hp==4,"secondhit resolves real1damage+1break against2armor aftercoverconsumed")
	gs=game(); u=gs.player(0).units[0]; play(gs,"c19002",u.uid)
	gs._damage_unit(0,0,0,1,0)
	check(u.get("otakeCover",false),"zerodamage doesnotconsumeimmuneonce")
	gs._damage_unit(0,0,1,1,0)
	check(u.hp==4 and not u.get("otakeCover",false) and events(gs,"otake-cover-consumed")==1,"nonlethal1damage consumescoveronce")
	gs=game(); p=gs.player(0); u=p.units[0]; u.front=1
	give(gs,"c19002"); gs.current_player=1; gs.player(1).attackUsed=false
	gs._grow_unit(gs.player(1).units[0],0,10)
	check(gs.basic_attack(1,0,u.uid),"opponentactualbasictriggersautomaticcoverresponse")
	check(p.hand.is_empty() and p.energy==39 and u.hp==4 and u.attack==5 and not u.get("otakeCover",false),"responseuses realhand/pay/cardrulesandblocksbattlehit")
	check(events(gs,"response-card")==1 and events(gs,"otake-cover-consumed")==1,"exactoneautoresponse andoneactualblock")
	gs=game(); p=gs.player(0); u=p.units[0]; u.front=1; p.energy=0; give(gs,"c19002"); gs.current_player=1
	gs.basic_attack(1,0,u.uid)
	check(p.hand.size()==1 and u.hp==1 and not u.has("otakeJades"),"unpayable responsecannotfakeprotection")

func prison_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=foe.units[1]
	var power: int=u.attack; play(gs,"c19004",u.uid)
	check(u.frozen>0 and Otake.continuously_stunned(u) and u.attack==power+1,"enemyprisoncontinuousstun andrealjadepower")
	for i in 4:
		gs.VerifiedRules.Stun.end_turn(gs,1)
		check(u.frozen>0 and Otake.continuously_stunned(u),"prisonremains afterenemyend%d notfixed2turns" % i)
	gs.current_player=1; foe.levelUpUsed=true
	check(not gs.can_basic_attack(1,1).ok,"actualenemycommandsblockedbycontinuousprison")
	gs.current_player=0
	play(gs,"nuoyi",p.units[0].uid)
	check(not Otake.continuously_stunned(u) and u.frozen==0 and p.units[0].attack==5,"movinguniquejadeimmediatelyreleasesonlyprison")
	gs=game(); u=gs.player(1).units[1]; gs.VerifiedRules.Stun.apply(gs,1,1,2,1); var base: int=u.frozen
	play(gs,"c19004",u.uid); Otake.remove_charm(gs,1,1,"cleanse")
	check(u.frozen==base and not Otake.continuously_stunned(u),"prisoncleanse preservesindependentfinitestun")
	gs=game(); u=gs.player(1).units[1]; play(gs,"c19004",u.uid); gs.VerifiedRules.Stun.apply(gs,1,1,3,0)
	Otake.remove_charm(gs,1,1,"cleanse")
	check(u.frozen==3,"laternormalstun survivesjade removal")
	gs=game(); u=gs.player(1).units[1]; play(gs,"c19004",u.uid); gs.VerifiedRules.Panguan.destroy(gs,0,1,1,1); gs._resolve_resolution_stack()
	check(u.hp==0 and not u.has("otakeJades") and not Otake.continuously_stunned(u),"actualKOremovesjade andperpetualstun")

func assault_and_boom_rules() -> void:
	var gs:=game(); var foe: Dictionary=gs.player(1); var u: Dictionary=gs.player(0).units[0]
	foe.units[0].front=1; foe.units[0].baseAttack=6; foe.units[0].baseMaxHp=20; foe.units[0].hp=20; foe.units[0].maxHp=20; gs._recalc(foe.units[0])
	play(gs,"c19005")
	check(u.hp==0 and foe.units[0].hp==15,"un-enhanced袭 attachesjade5powerbutreal6counterpierces2armor")
	gs=game(); foe=gs.player(1); u=gs.player(0).units[0]
	play(gs,"nuoyi",gs.player(0).units[1].uid)
	foe.units[0].front=1; foe.units[0].baseAttack=9; gs._grow_unit(foe.units[0],0,20); gs._recalc(foe.units[0]); var hp: int=foe.units[0].hp
	play(gs,"c19005")
	check(u.hp==4 and u.shield==2 and u.attack==5 and foe.units[0].hp==hp-5,"enhanced袭 realfullcombatimmunity preserves2armor andoriginalhp")
	gs=game(); play(gs,"c19004",gs.player(1).units[0].uid); give(gs,"c19005")
	check(gs.hand_card_def(0,0).otakeEnhanced,"enhancementcountsownedjadehostedenemy")
	gs=game(); var p: Dictionary=gs.player(0); foe=gs.player(1); u=p.units[0]
	check(not gs.can_play_card(0,give(gs,"c19006"),foe.units[0].uid).ok,"灭requiresrealfriendlyjadeholder")
	p.hand.clear(); play(gs,"nuoyi",p.units[1].uid); foe.units[2].front=1; foe.units[0].hp=2
	play(gs,"c19006",foe.units[0].uid)
	check(foe.units[0].hp==0 and p.units[1].front==1 and p.units[1].hp==3 and p.units[1].shield==0,"灭real4powerfriendlyholderpursueschosenreserve with2armorand3counter")
	check(u.hp==4 and u.shield==0 and u.front==0 and foe.avatarHp==30,"灭doesnotdamagespell/fakearmorormakemasterfight")
	gs=game(); p=gs.player(0); play(gs,"nuoyi",p.units[0].uid); play(gs,"c19008",p.units[0].uid)
	check(gs.player(1).avatarHp==19 and p.units[0].attack==5 and p.units[0].shield==1,"轰selftargettrue6temporaryfirstattackthen5powerfollowup exact11")
	check(events(gs,"combat-complete")==2 and not p.attackUsed,"轰twoactualcombats withoutordinaryquota")
	gs=game(); p=gs.player(0); play(gs,"c19008",p.units[1].uid)
	check(gs.player(1).avatarHp==23 and p.units[1].attack==3 and p.units[1].front==1 and p.units[0].front==0,"轰withoutinitialjade4source then3friendlybody truehandoff")
	gs=game(); foe=gs.player(1); u=gs.player(0).units[0]; foe.units[0].front=1; foe.units[0].hp=2; foe.units[0].shield=1
	play(gs,"c19001")
	check(foe.units[0].hp==0 and foe.avatarHp==28 and u.hp==1,"穿real5powerpierces2hp1armorfor2 andcounteractual3")

func awaken_and_tokens() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; var foe: Dictionary=gs.player(1)
	play(gs,"c19007",p.units[1].uid)
	check(u.awakened and u.attack==3 and u.maxHp==5 and p.units[1].attack==3,"baselineawakeningexact0/+1 andrealallyjade")
	play(gs,"c12404",foe.units[0].uid)
	check(Otake.magnitude(gs,0)==2 and p.units[1].attack==4 and events(gs,"otake-jade-grown")==1,"noncombatrealspellkillbypresentjadeholdergrowsphysicaleffect")
	foe.units[1].hp=2
	play(gs,"c12404",foe.units[1].uid)
	check(Otake.magnitude(gs,0)==3 and p.units[1].attack==5,"eachrealenemykilladdsoneeffect")
	play(gs,"nuoyi",u.uid)
	check(u.attack==9 and p.units[1].attack==2,"awakeself3baseplus3effectdoubled6, oldallylosesentirebonus")
	Otake.remove_charm(gs,0,0,"cleanse"); play(gs,"nuoyi",u.uid)
	check(u.attack==9,"ownedjadeeffectgrowth survivesphysicalrecreation")
	check(not gs.can_play_card(0,give(gs,"c19007"),u.uid).ok,"alreadyawakecommandunavailable")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"nuoyi",p.units[1].uid); gs._damage_unit(1,0,99,0,1); gs._resolve_resolution_stack()
	check(Otake.magnitude(gs,0)==1 and p.units[1].attack==3,"unawakenedjadeholderkill noinventedgrowth")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c19009")
	check(u.attack==4 and u.maxHp==6 and p.hand.size()==1 and p.hand[0].definitionId=="nuoyi","mountainactual4/6 andentrygeneratesrealtoken")
	var iid: String=p.hand[0].instanceId; Otake.turn_start(gs,0)
	check(p.hand.size()==2 and p.hand[1].definitionId=="nuoyi" and p.hand[1].instanceId!=iid,"eachownstartgeneratesdistinctdedicatedcardinstance")
	check(gs.play_card(0,0,p.units[1].uid) and p.units[1].attack==3 and gs.player(1).avatarHp==30,"generatedtokenactuallymovesjade nofakeprojectile")
	gs._knockout_unit(u); gs._resolve_resolution_stack(); var handsize: int=p.hand.size(); Otake.turn_start(gs,0)
	check(p.hand.size()==handsize and u.formRules.is_empty(),"knockedformcannotgenerateoldturnhook")
	gs=game(); var token:=Content.card_def("otakemaru-jade")
	check(token.type=="charm" and token.effects[0].action=="otake-jade-token" and not gs.can_play_card(0,give(gs,"otakemaru-jade"),gs.player(0).units[1].uid).ok,"physicaljadeinspectiontokenhasrealactionnotordinaryhandplay")
	check(Otake.resolve_action(gs,0,0,token,token.effects[0],gs.player(0).units[1],gs.player(0).units[1].uid) and gs.player(0).units[1].attack==3,"derivedjadeactionactuallyattachesrealpermanent")

func ai_and_lifecycle() -> void:
	for id in ["c19001","c19002","c19004","c19005","c19006","c19007","c19008","c19009"]:
		var gs:=game()
		if id=="c19006": Otake.attach(gs,0,0,0,1)
		give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and gs.can_play_card(0,int(best.hand),best.target).ok,"AIactuallegality "+id)
		check(best.ok and gs.play_card(0,int(best.hand),best.target),"AIrealresolution "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"primarycardfaceexists "+id)
		check(not Content.card_def(id).verificationPending.is_empty(),"honestpending "+id)
	var gs:=game(); var p: Dictionary=gs.player(0); var idx: int=gs.VerifiedRules.Enma.summon_ghost(gs,0,2)
	Otake.attach(gs,0,0,0,idx); var old: Dictionary=p.units[idx]; var jade_uid: String=old.otakeJades["0"].uid
	var fused: int=gs.VerifiedRules.Enma.summon_ghost(gs,0,2)
	check(not old.has("otakeJades") and p.units[fused].otakeJades["0"].uid==jade_uid and Otake.owned(gs,0).index==fused,"realghostfusionmovesonephysicaljade tonewUID")
	check(p.units[fused].attack==7,"fused6baseplusonejade, nobonusembeddedtwice")
	gs.VerifiedRules.Movement.move_to(gs,0,fused,0); gs._resolve_resolution_stack()
	check(Otake.owned(gs,0).is_empty() and not p.units[fused].has("otakeJades"),"actualsummondeparture removesphysicaljade")
	gs=game(); var u: Dictionary=gs.player(0).units[0]; play(gs,"c19002",u.uid); gs.VerifiedRules.Panguan.destroy(gs,1,0,0,0); gs._resolve_resolution_stack()
	check(not u.has("otakeJades") and not u.get("otakeCover",false) and Otake.owned(gs,0).is_empty(),"directdestructionremovesjade/coverwithoutpretendingdamageimmunity")

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["dayueling","fenghuanghuo","yanmo","taohuayao"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],190)
		b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear(); p.energy=40; p.levelUpUsed=true
			for u in p.units: u.level=3
		root.add_child(b); await create_timer(0.5).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		hand(b,["c19002"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0,"mousecover opensfriendlytargetUI")
		await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(p.units[1].attack==3 and p.units[1].otakeCover and p.hand.is_empty(),"mousecover attachesrealjade/independentimmunity")
		foe.units[0].hp=1; hand(b,["c19006"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		var fire: int=p.energy; await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"mouse灭rejectsfriendlychosenenemy withoutpayment")
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(foe.units[0].hp==0 and p.units[1].front==1 and p.units[1].hp==4 and p.units[1].shield==2,"mouse灭 usesactualjadeholder'scombat/cover")
		hand(b,["c19004"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(Otake.continuously_stunned(foe.units[1]) and not p.units[1].has("otakeJades"),"mouseprisonmovessameownerjade toenemyandlocksactualcommands")
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(texts(b).contains("八尺琼曲玉") and texts(b).contains("持续眩晕"),"mouseinspectorrealjadeandcontinuousstun")
		await capture("%d-otakemaru-prison-inspector" % physical.x)
		escape(); await settled(b)
		hand(b,["c19009"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.hand.size()==1 and p.hand[0].definitionId=="nuoyi","mousemountainentrygivesactualgeneratedtoken")
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(foe.units[1].frozen==0 and p.units[0].attack==6 and p.hand.is_empty(),"mousegeneratedrelocate actuallyreleasesprisonandbuffsformself")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out=arg; DirAccess.make_dir_recursive_absolute(out); break
	root.theme=ThemeBuilder.build_theme()
	jade_rules(); cover_rules(); prison_rules(); assault_and_boom_rules(); awaken_and_tokens(); ai_and_lifecycle()
	if not OS.get_cmdline_user_args().has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("OTAKEMARU checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
