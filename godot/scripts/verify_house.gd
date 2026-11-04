extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const House := preload("res://scripts/house_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("HOUSE_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["tianjingxia","zhen","rulianshi","bingyong"],["yaodaoji","bingyong","xuenv","baizangzhu"],168)
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs
func give(gs, id: String, owner: int = 0, enhanced: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"house-%d" % gs.next_card_id,"houseEnhance":enhanced}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actualcard "+id)
func house(gs) -> Dictionary:
	for u in gs.player(0).units:
		if u.get("houseSummon",false) and int(u.hp)>0 and not u.get("removed",false): return u
	return {}
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func test_base_tokens() -> void:
	var opening:=GS.create(["tianjingxia","zhen","rulianshi","bingyong"],["yaodaoji","bingyong","xuenv","baizangzhu"],168)
	check(opening.player(0).hand.filter(func(e):return e.definitionId=="yaowu-lingli").size()==1,"actualopening addsone realtoken")
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==5 and u.passive_hooks.is_empty(),"base exact2/5 noold duplicatehooks")
	House.turn_start(gs,0); var first: Dictionary=p.hand[0]; var iid: String=first.instanceId
	House.turn_start(gs,0); House.turn_end(gs,0)
	check(p.hand.size()==1 and first.instanceId==iid and first.houseEnhance==0,"start/end checkabsence keepssame handinstance")
	check(gs.hand_card_def(0,0).cost==1 and gs.hand_card_def(0,0).level==1 and not gs.hand_card_def(0,0).keywords.has("instant"),"power real1level1fire nofakeinstant/projectile")
	var shield: int=p.units[2].shield; var fire: int=p.energy; var face: int=gs.player(1).avatarHp
	check(gs.play_card(0,0,p.units[2].uid) and p.units[2].shield==shield+1 and p.energy==fire-1,"actualpower giveschosenallyarmor foronefire")
	check(gs.player(1).avatarHp==face,"power doesnotfakeprojectile")
	House.turn_end(gs,0); check(p.hand.size()==1 and p.hand[0].instanceId!=iid and p.hand[0].houseEnhance==0,"usedtoken replenished asnew unenhancedinstance atend")
	var idx:=give(gs,"yaowu-lingli",0,4); var card: Dictionary=gs.hand_card_def(0,idx); var foe: Dictionary=gs.player(1)
	check(card.value==5 and gs.valid_targets(0,card).has(p.units[2].uid) and gs.valid_targets(0,card).has(foe.units[2].uid) and not gs.valid_targets(0,card).has("avatar-1"),"enhancedtoken readonlyactual5 andbothside unitonly")
	check(gs.play_card(0,idx,foe.units[2].uid) and foe.units[2].armorBreak==5,"enhancedpower actuallygives5break chosenenemy")
	gs=game(); p=gs.player(0); u=p.units[0]; u.level=0; House.turn_start(gs,0); check(p.hand.is_empty(),"unactivatedbase nofree token")
	u.level=3; u.baseRulesSuppressed=true; House.turn_end(gs,0); check(p.hand.is_empty(),"suppressedbase nofree token")
	u.erase("baseRulesSuppressed"); gs._knockout_unit(u); House.turn_start(gs,0); check(p.hand.is_empty(),"deadbase nofree token")
func test_enhance_and_awake() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var idx:=give(gs,"yaowu-lingli"); var first: Dictionary=p.hand[idx]; var iid: String=first.instanceId
	gs._grant_unit_armor(p.units[2],7); gs._grant_avatar_armor(0,4); gs.VerifiedRules.ArmorBreak.give(gs,0,0,1,2,9)
	check(gs.end_turn(0),"realround entersenemy cleanup")
	check(first.houseEnhance==1 and foe.units[2].armorBreak==0,"enemy9break naturalremoval enhancesone, notequal9")
	foe.levelUpUsed=true; check(gs.end_turn(1),"realround entersown cleanup")
	check(first.houseEnhance==3 and p.units[2].shield==0 and p.avatarArmor==0 and first.instanceId==iid,"own7unitarmor+4avatararmor removals twoevents, originalinstance retained")
	var current: int=first.houseEnhance; House.turn_start_removed(gs,0,0,0,0)
	check(first.houseEnhance==current,"zero/noremoval noartificialenhancement")
	gs=game(); p=gs.player(0); idx=give(gs,"yaowu-lingli",0,6); first=p.hand[idx]; iid=first.instanceId; var extra_idx:=give(gs,"yaowu-lingli",0,2); var second: Dictionary=p.hand[extra_idx]; var second_id: String=second.instanceId
	play(gs,"c16808")
	check(p.units[0].awakened and p.units[0].attack==4 and p.units[0].maxHp==7,"awake exact+2/+2")
	check(first.definitionId=="yaowu-quan" and first.instanceId==iid and first.houseEnhance==6 and second.definitionId=="yaowu-quan" and second.instanceId==second_id and second.houseEnhance==2,"awake transforms allactual handinstances preservingidentity andenhancement")
	check(not gs.hand_card_def(0,0).keywords.has("instant") and gs.hand_card_def(0,0).value==7,"baselinespring noninstant current7 retained")
	check(not gs.can_play_card(0,give(gs,"c16808")).ok,"awakecannotrepeat")
	House.turn_end(gs,0); check(p.hand.filter(func(e):return e.definitionId=="yaowu-quan").size()==2,"awakebase detectsany existing泉 noaddduplicate")
	p.hand.clear(); House.turn_start(gs,0); check(p.hand.size()==1 and p.hand[0].definitionId=="yaowu-quan" and p.hand[0].houseEnhance==0,"awake replenishesnew泉 only")
	gs=game(); p=gs.player(0); foe=gs.player(1); idx=give(gs,"yaowu-quan",0,2); var face: int=p.avatarHp
	check(gs.play_card(0,idx),"actualenhancedspring")
	check(p.units.all(func(u):return u.shield==3) and foe.units.all(func(u):return u.armorBreak==3),"泉 appliesboth allallyarmor AND allenemybreak exact3")
	check(p.avatarArmor==0 and foe.avatarArmorBreak==0 and p.avatarHp==face,"泉 excludesavatars andnofakehealing")
func test_noise_choice() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var a:=give(gs,"yaowu-lingli"); var first: Dictionary=p.hand[a]; var q:=give(gs,"yaowu-quan",0,2); var second: Dictionary=p.hand[q]
	p.units[2].shield=7; p.units[2].shieldExpires=7; p.units[2].armorBreak=3
	var idx:=give(gs,"c16801"); var card: Dictionary=gs.hand_card_def(0,idx)
	check(gs.valid_targets(0,card).has(p.units[2].uid) and not gs.valid_targets(0,card).has(foe.units[0].uid),"noise genuinepositive status targets")
	var fire: int=p.energy; check(gs.play_card(0,idx,p.units[2].uid),"actualnoise castdualstatus")
	check(gs.pending_choice.type=="house-status" and p.units[2].shield==7 and p.units[2].armorBreak==3 and p.energy==fire,"dualstatus mustchoose, instantpaysonce andmutatesneither")
	check(not gs.resolve_divination_choice(0,"house:invalid") and not gs.resolve_divination_choice(1,"house:armor"),"choice rejectsinvalid andwrongowner")
	check(gs.resolve_divination_choice(0,"house:break"),"actualUIrouter resolveschosenbreak")
	check(p.units[2].shield==7 and p.units[2].armorBreak==0 and first.houseEnhance==3 and second.houseEnhance==5,"chosenbreakonly removed, bothtokeninstances enhanceactual3")
	play(gs,"c16801",p.units[2].uid)
	check(p.units[2].shield==0 and first.houseEnhance==10 and second.houseEnhance==12 and gs.pending_choice.is_empty(),"singlearmor automaticallychosen withoutphantomchoice; equal7enhance")
	gs=game(); p=gs.player(0); p.avatarArmor=6; p.avatarArmorBreak=2; a=give(gs,"yaowu-lingli"); first=p.hand[a]; play(gs,"c16801","avatar-0")
	check(gs.pending_choice.type=="house-status" and House.choice_card(gs,0,"house:armor").name.contains("6"),"avatar dualstates getsreadableactualchoice")
	check(gs.resolve_divination_choice(0,"house:armor") and p.avatarArmor==0 and p.avatarArmorBreak==2 and first.houseEnhance==6,"avatar chosenarmor exactremoval andenchantment")
	gs=game(); p=gs.player(0); foe=gs.player(1); a=give(gs,"yaowu-lingli"); first=p.hand[a]; foe.units[1].shield=4; play(gs,"c16801",foe.units[1].uid)
	check(foe.units[1].shield==0 and first.houseEnhance==4,"noise mayremoveenemyarmor, notonlyownresource")
func test_joy_transfer_heal() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); play(gs,"c16802")
	check(p.units[0].attack==3 and p.units[0].maxHp==5 and House.armor_bonus(gs,0)==1,"joy exact3/5 aura")
	check(gs._grant_unit_armor(p.units[2],1)==2 and p.units[2].shield==2,"centralunitarmor grant amplifiedonce")
	check(gs._grant_avatar_armor(0,1)==2 and p.avatarArmor==2,"centralavatararmor amplifiedonce")
	gs.VerifiedRules.ArmorBreak.give(gs,0,0,1,2,1); check(foe.units[2].armorBreak==2,"centralenemybreak amplifiedonce")
	gs.VerifiedRules.ArmorBreak.give(gs,1,0,1,3,1); check(foe.units[3].armorBreak==2,"enemyselfinflictedbreak stillenemyacquisition underjoy")
	gs._grant_unit_armor(foe.units[0],1); check(foe.units[0].shield==1,"enemyarmor neverownjoy boosted")
	gs.VerifiedRules.ArmorBreak.give(gs,1,0,0,1,1); check(p.units[1].armorBreak==1,"ownbreak neverownjoy boosted")
	gs._grant_unit_armor(p.units[1],1); check(p.units[1].shield==1 and p.units[1].armorBreak==0,"joy boost beforearmor/break cancellation, remainder1")
	play(gs,"c11606"); var hp: int=foe.units[2].hp; gs.VerifiedRules.ArmorBreak.give(gs,0,1,1,2,1)
	check(foe.units[2].hp==hp-3 and foe.units[2].armorBreak==0,"realzhen conversion isdamage1+existing2, notboostedbreak2")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c16802"); p.avatarArmor=2; p.avatarArmorBreak=1; foe.avatarArmor=3; foe.avatarArmorBreak=4; p.units[2].shield=5; p.units[2].shieldExpires=5; foe.units[1].armorBreak=6
	play(gs,"c16807",p.units[1].uid)
	check(p.units[1].shield==10 and p.units[1].armorBreak==11 and p.units[1].shieldExpires==10,"gather transferindependent10armor11break nojoyamplification/cancellation")
	check(p.avatarArmor==0 and p.avatarArmorBreak==0 and foe.avatarArmor==0 and foe.avatarArmorBreak==0 and p.units[2].shield==0 and foe.units[1].armorBreak==0,"gather includesallavatars andbothsides units, removesoriginals")
	var power:=give(gs,"yaowu-lingli"); play(gs,"c16801",p.units[1].uid)
	check(gs.pending_choice.type=="house-status","gather realcoexistingstates produceactualnoisechoice")
	check(gs.resolve_divination_choice(0,"house:armor") and p.units[1].armorBreak==11 and p.hand[power].houseEnhance==10,"noise ongather doesnot touch unchosenbreak")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.avatarHp=5; foe.avatarArmorBreak=12; p.units[2].shield=7; play(gs,"c16803")
	check(p.avatarHp==17,"rain readswholefield maximum includingenemyavatar")
	gs=game(); p=gs.player(0); p.avatarHp=5; play(gs,"c16803"); check(p.avatarHp==5,"rain zeroresource nofixedfakeheal")
func test_summon_revive() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var idx:=give(gs,"c16804"); var c: Dictionary=gs.hand_card_def(0,idx)
	check(gs.valid_targets(0,c).is_empty() and not gs.can_play_card(0,idx).ok,"wake cannotfakecost withoutrealpositive resource")
	p.avatarArmor=8; foe.units[1].armorBreak=6; foe.units[2].shield=9; p.units[1].armorBreak=7; c=gs.hand_card_def(0,idx)
	check(gs.valid_targets(0,c).has("avatar-0") and gs.valid_targets(0,c).has(foe.units[1].uid) and not gs.valid_targets(0,c).has(foe.units[2].uid) and not gs.valid_targets(0,c).has(p.units[1].uid),"wake onlyallyarmor/enemybreak realcharacters")
	check(gs.play_card(0,idx,"avatar-0"),"actualwake takesavatararmor")
	var u:=house(gs); var uid: String=u.uid; var at: int=gs._unit_index_by_uid(0,uid); var count: int=p.units.size()
	check(p.avatarArmor==0 and u.attack==8 and u.maxHp==8 and u.hp==8 and u.front==1 and p.units[0].attack==2,"real8/8house body exactremovedresource, nosourcefakegrowth")
	check(gs.can_basic_attack(0,at).ok,"house actualsummon mayordinaryattack")
	gs._damage_unit(0,at,999,1,0); gs._resolve_resolution_stack()
	check(u.removed and u.hp==0 and u.knockout==0 and u.weaverReviveReason=="knockout","realhouseKO keepsoriginal stablegrave")
	play(gs,"c23603"); check(u.uid==uid and p.units.size()==count and p.units[at].hp==8 and p.units[at].front==1 and not u.removed and not u.has("houseDepartureRecorded"),"powderrevives samehouse uid/index andresetsleaveguard")
	check(gs.VerifiedRules.Movement.move_to(gs,0,0,1),"actualnon-summon displacement")
	check(u.removed and not u.has("weaverGrave"),"displacedhouse removedwithoutfakeKOgrave")
	play(gs,"c16804",foe.units[1].uid); check(foe.units[1].armorBreak==0 and house(gs).attack==6,"wake actualenemybreak6 yields6/6")
	play(gs,"c23602"); check(house(gs).is_empty() and gs.VerifiedRules.Weaver.live_snow(gs,0)>=0,"anotherkind summon actuallyremoveshouse")
func test_shatter_renew() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); play(gs,"c16805")
	check(p.units[0].attack==6 and p.units[0].maxHp==5 and foe.avatarHp==30,"shatter exact6/5 nofakeentrydamage")
	foe.units[1].armorBreak=3; var hp: int=foe.avatarHp; gs._damage_unit(1,1,3,0,2); gs._resolve_resolution_stack()
	check(foe.units[1].hp==0 and foe.avatarHp==hp-3 and events(gs,"house-shatter")==1,"allyspellkill snapshots3break beforeconsumption andtriggeractual3")
	hp=foe.avatarHp; gs._damage_unit(1,0,999,0,2); gs._resolve_resolution_stack()
	check(foe.avatarHp==hp and events(gs,"house-shatter")==1,"unmarkedactualkill nofalse3trigger")
	foe.units[2].armorBreak=2; gs._knockout_unit(foe.units[2]); gs._resolve_resolution_stack()
	check(foe.avatarHp==hp and events(gs,"house-shatter")==1,"unattributeddeath nevercredited toyourkill")
	foe.units[3].armorBreak=2; check(gs.VerifiedRules.Panguan.destroy(gs,0,2,1,3),"actualattributedharddestroy"); gs._resolve_resolution_stack()
	check(foe.avatarHp==hp-3 and events(gs,"house-shatter")==2,"harddestroy markedtarget alsorealownedkill")
	gs=game(); foe=gs.player(1); play(gs,"c16805"); foe.units[1].armorBreak=3; gs.VerifiedRules.Vine.attach(gs,1,1); hp=foe.avatarHp; gs._damage_unit(1,1,999,0,2); gs._resolve_resolution_stack()
	check(foe.units[1].hp>0 and foe.avatarHp==hp and events(gs,"house-shatter")==0,"substitute saves markedtarget withoutfakekill credit")
	gs=game(); p=gs.player(0); play(gs,"c16806"); p.hand.clear(); var deck: int=p.deck.size(); p.avatarArmor=20; House.turn_end(gs,0)
	check(p.deck.size()==deck,"renew onlyshikigamiarmor notavatarthreshold")
	p.units[2].shield=4; deck=p.deck.size(); House.turn_end(gs,0); check(p.deck.size()==deck,"renewarmor4 negativeboundary")
	p.units[2].shield=5; deck=p.deck.size(); House.turn_end(gs,0); check(p.deck.size()==deck-1,"renewarmor5 exactboundarydraw1")
	deck=p.deck.size(); House.turn_end(gs,1); check(p.deck.size()==deck,"renew neverenemyturnend")
	p.units[2].hp=0; p.units[2].removed=true; deck=p.deck.size(); House.turn_end(gs,0); check(p.deck.size()==deck,"dead/tombstonearmor cannotpassrenewthreshold")
func ai_and_art() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); p.units[2].shield=5; p.units[2].armorBreak=2; give(gs,"yaowu-lingli"); play(gs,"c16801",p.units[2].uid)
	check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty() and p.units[2].shield==0 and p.units[2].armorBreak==2,"AI actualchoice resolveslegal5armor notsilentforced2break")
	gs=game(); var foe: Dictionary=gs.player(1); foe.units[1].armorBreak=7; give(gs,"c16804"); var best:=AI._best_card(gs,0)
	check(best.ok and best.target==foe.units[1].uid and gs.play_card(0,best.hand,best.target) and house(gs).attack==7,"AI actualwake chooseslegalresource thenreal7/7")
	gs=game(); p=gs.player(0); give(gs,"yaowu-lingli",0,3); best=AI._best_card(gs,0)
	check(best.ok and gs.valid_targets(0,gs.hand_card_def(0,best.hand)).has(best.target) and gs.play_card(0,best.hand,best.target),"AI actualtoken targetslegalunit andexecutesstatus")
	var snapshot:=JSON.stringify(gs.snapshot()); var marks:=House.unit_marks(gs,0,0)
	check(marks.size()==1 and JSON.stringify(gs.snapshot())==snapshot,"baseinspector read-only")
	for id in ["c16801","c16802","c16803","c16804","c16805","c16806","c16807","c16808"]:
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalart "+id)
		check(Content.card_def(id).verifiedRules and not Content.card_def(id).verificationPending.is_empty(),"nativepending "+id)
func native_ui() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["tianjingxia","zhen","rulianshi","bingyong"],["yaodaoji","bingyong","xuenv","baizangzhu"],168); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=80; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		p.units[2].shield=4; p.units[2].shieldExpires=4; p.units[2].armorBreak=2; hand(b,["c16801","yaowu-lingli"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(p.units[2].uid)).selected,"native noise exposesstatusbearing actualtarget")
		await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		check(gs.pending_choice.get("type")=="house-status" and choice_face(b,"house:armor")!=null and choice_face(b,"house:break")!=null,"native dualstatus realchoicebothoptions")
		if physical.x==1280: await capture("01-house-noise-dual-status-choice")
		await click(choice_face(b,"house:break")); await settled(b)
		check(p.units[2].shield==4 and p.units[2].armorBreak==0 and gs.hand_card_def(0,0).value==3,"native chosenbreak removesonly2 andenhances survivingtoken3")
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].armorBreak==3,"native enhancedlingli actual3break toselectedenemy")
		hand(b,["c16804"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(p.units[2].uid)).selected,"native wake actualresource targetmode")
		await click(b._unit_widget(str(p.units[2].uid))); await settled(b)
		var u:=house(gs); check(u.attack==4 and u.hp==4 and p.units[2].shield==0,"native wake removesactual4armor andbuilds4/4")
		await click(b._unit_widget(str(u.uid))); await settled(b)
		if b._selected_attacker>=0: await click(b._unit_widget(str(u.uid))); await settled(b)
		check(texts(b).contains("妖怪屋") and texts(b).contains("4/4"),"native housesummon inspector actualbodystats")
		if physical.x==1600: await capture("02-house-real-summon-inspector")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	test_base_tokens(); test_enhance_and_awake(); test_noise_choice(); test_joy_transfer_heal(); test_summon_revive(); test_shatter_renew(); ai_and_art()
	if not rules_only: await native_ui()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("HOUSE_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures==0 else 1)
