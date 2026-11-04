extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Fish := preload("res://scripts/goldfish_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("GOLDFISH_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["jinyuji","yaodaoji","taohuayao","shantu"],["yaodaoji","bingyong","xuenv","baizangzhu"],227)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true;p.avatarArmor=0
		for u in p.units:u.level=3;u.incarnationChance=-100000
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"goldfish-fixture-%d"%gs.next_card_id});gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actualhandplay "+id)
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func upgrade(gs, id: String, direction: String, count: int) -> void:
	for n in count:Fish.strengthen(gs,0,id,direction)
func base_cards() -> void:
	for id in Fish.BASE_IDS:
		var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];var foe: Dictionary=gs.player(1);foe.units[1].front=1
		check(u.attack==3 and u.maxHp==4 and u.passive_hooks.is_empty(),"base3/4nooldturngrowth")
		var deck: int=p.deck.size();var atk: int=p.units[1].attack;var hp: int=foe.units[1].hp;p.avatarHp=20
		var idx:=give(gs,id);var card:=gs.hand_card_def(0,idx)
		check(card.goldfishAttachmentReplacement and card.target=="auto" and gs.valid_targets(0,card).is_empty(),"unattached1cardneedsnotarget "+id)
		check(gs.play_card(0,idx) and Fish.attached(u) and p.deck.size()==deck-1,"firstcardactuallyattachesanddrawsone "+id)
		check(p.units[1].attack==atk and foe.units[1].hp==hp and p.avatarHp==20 and u.front==0 and u.shield==0,"firstcardreplacesalloriginaleffects "+id)
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];Fish.attach(gs,0,0)
	var idx:=give(gs,"c22701");var card:=gs.hand_card_def(0,idx)
	check(gs.valid_targets(0,card).has(p.units[1].uid) and not gs.valid_targets(0,card).has("avatar-0") and not gs.can_play_card(0,idx,gs.player(1).units[0].uid).ok,"supportallowsownshikigamionly")
	var power: int=p.units[1].attack;var life: int=p.units[1].maxHp
	check(gs.play_card(0,idx,p.units[1].uid) and p.units[1].attack==power+1 and p.units[1].maxHp==life+1,"actualsupportexact1/1")
	gs._knockout_unit(p.units[1]);check(p.units[1].attack==power and p.units[1].maxHp==life,"nonpermanentsupportgrowthclearsatknockout")
	gs.player(1).units[1].front=1;gs._grow_unit(gs.player(1).units[1],0,20);var foehp: int=gs.player(1).units[1].hp
	var ownhp: int=u.hp;play(gs,"c22702")
	check(gs.player(1).units[1].hp==foehp-4 and u.hp==ownhp and u.shield==0 and u.front==0,"realtraining+1attack/+1armorandretreataftercounter")
	p.avatarHp=20;play(gs,"c22703","avatar-0");check(p.avatarHp==25,"restbase5actualownavatarheal")
	gs._damage_unit(0,3,2,1,0);var before: int=p.units[3].hp;play(gs,"c22703",p.units[3].uid);check(p.units[3].hp==mini(before+5,int(p.units[3].maxHp)),"resthealschosenlivingally")
	idx=give(gs,"c22703");check(not gs.can_play_card(0,idx,"avatar-1").ok and not gs.can_play_card(0,idx,p.units[1].uid).ok,"restrejectsenemyandknockedtarget")
func choices_and_tiers() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var deck: int=p.deck.size();var power: int=p.units[1].attack
	play(gs,"c22704")
	check(gs.pending_choice.type=="goldfish-upgrade" and gs.pending_choice.instanceIds==Fish.BASE_IDS and p.deck.size()==deck,"attackupgradeexact3choicebeforelaterdraw")
	check(not gs.resolve_divination_choice(1,"c22701") and not gs.resolve_divination_choice(0,"c10101"),"choicewrongownerandunknownrejected")
	var view: Dictionary=Fish.choice_card(gs,0,"c22701");check(view.text.contains("额外+2力量"),"choiceexposesnextrealupgrade")
	check(gs.resolve_divination_choice(0,"c22701") and gs.pending_choice.is_empty() and p.deck.size()==deck-1,"realchoiceupgradesselectedcardthendrawsexact1")
	check(Fish.upgrades(gs,0,"c22701")==["support-power"] and Fish.upgrades(gs,0,"c22702").is_empty() and p.units[1].attack==power,"upgradingonlychangescardnotimmediateboard")
	play(gs,"c22705");check(gs.resolve_divination_choice(0,"c22703") and Fish.upgrades(gs,0,"c22703")==["rest-armor"],"defensechoicehasindependentfirsttier")
	play(gs,"c22704");var offered: String=gs.pending_choice.offers["c22701"]
	var snapshot:=JSON.stringify(gs.snapshot());view=Fish.choice_card(gs,0,"c22701")
	check(view.text.contains(Fish.LABELS[offered]) and JSON.stringify(gs.snapshot())==snapshot,"secondtierchoiceexposesfixedreadonlyofferedkeyword")
	check(gs.resolve_divination_choice(0,"c22701") and Fish.upgrades(gs,0,"c22701","attack").back()==offered,"selectedofferedupgradeappliedwithouthiddenreroll")
	for id in Fish.BASE_IDS:
		for direction in ["attack","defense"]:
			gs=game();p=gs.player(0)
			var first:=Fish.strengthen(gs,0,id,direction)
			check(first==Fish.TIERS[id][direction][0][0],"officialfirsttier "+id+direction)
			var second:=Fish.strengthen(gs,0,id,direction);var third:=Fish.strengthen(gs,0,id,direction)
			check(second!=third and Fish.TIERS[id][direction][1].has(second) and Fish.TIERS[id][direction][1].has(third),"bothseconddistinctbeforetier3 "+id+direction)
			var fourth:=Fish.strengthen(gs,0,id,direction);var fifth:=Fish.strengthen(gs,0,id,direction)
			check(fourth==fifth and fourth==Fish.TIERS[id][direction][2][0],"highesttierrepeatable "+id+direction)
			gs._knockout_unit(p.units[0]);check(Fish.upgrades(gs,0,id,direction).size()==5,"permanentcardupgradessurviveknockout "+id+direction)
func support_training_traits() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);Fish.attach(gs,0,0);upgrade(gs,"c22701","attack",3);upgrade(gs,"c22701","defense",3)
	var u: Dictionary=p.units[1];var attack: int=u.attack;var life: int=u.maxHp
	play(gs,"c22701",u.uid)
	check(u.attack==attack+6 and u.maxHp==life+4 and u.swift and u.inspired and u.barrier and gs.VerifiedRules.Combat.has(u,"veil"),"all6distinctsupportupgradesgenuinekeywordsandstats")
	gs._knockout_unit(u);check(u.attack==attack and u.maxHp==life and not gs.VerifiedRules.Combat.has(u,"veil") and not u.swift,"supportveilnotpermanentbeyonddeath")
	gs=game();p=gs.player(0);Fish.attach(gs,0,0);upgrade(gs,"c22702","attack",3);upgrade(gs,"c22702","defense",3)
	u=p.units[0];var foe: Dictionary=gs.player(1);foe.units[1].front=1;gs._grow_unit(foe.units[1],20,20);var oldhp: int=u.hp;p.avatarHp=10
	play(gs,"c22702")
	check(foe.units[1].hp==0 and u.hp==oldhp and u.front==0 and p.avatarHp>10,"trainingreallethalcombatimmune,lifesteal,actualretreat")
	check(not u.get("immuneCombat",false) and not gs.VerifiedRules.Combat.has(u,"lethal"),"trainingkeywordsrestrictedtothiscombat")
	gs=game();p=gs.player(0);Fish.attach(gs,0,0);upgrade(gs,"c22702","defense",1);foe=gs.player(1);foe.units[1].front=1;gs._grow_unit(foe.units[1],0,20);play(gs,"c22702")
	check(foe.units[1].frozen>0,"realtrainingdamagegrantsstunfromdefensefirsttier")
	gs=game();p=gs.player(0);Fish.attach(gs,0,0);upgrade(gs,"c22702","attack",3);foe=gs.player(1);foe.units[1].front=1;foe.units[1].hp=1;var avatar: int=foe.avatarHp;play(gs,"c22702")
	check(foe.units[1].hp==0 and foe.avatarHp<avatar,"trainingtruepierceoverflow")
func rest_traits() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);Fish.attach(gs,0,0);upgrade(gs,"c22703","attack",3);upgrade(gs,"c22703","defense",3)
	p.avatarHp=29;gs._knockout_unit(p.units[1]);var deck: int=p.deck.size();give(gs,"c10101");play(gs,"c22703","avatar-0")
	check(p.avatarHp==30 and p.avatarArmor==9 and gs.kw_usage(0,"encourage").attack==2 and gs.kw_usage(0,"encourage").shield==2,"restexact5heal,4excessarmorand5extraarmor,realencourage")
	check(p.deck.size()==deck-1 and p.units[1].hp>0,"resttruedrawandrandomlegalrevival")
	check(p.hand.any(func(entry):return entry.get("goldfishInstant",false)),"restmarksactualrandomhandinstance")
	var idx: int=p.hand.find_custom(func(entry):return entry.get("goldfishInstant",false));var card: Dictionary=gs.hand_card_def(0,idx)
	check(card.keywords.has("instant") and gs.card_payment(0,card).cost==0,"foreigncardinstanceactualinstantpayment")
	p.energy=0;check(gs.play_card(0,idx) and gs.kw_usage(0,"instant").used,"foreigninstantactuallyplaysandconsumesonceperturnallowance")
	gs=game();p=gs.player(0);Fish.attach(gs,0,0);upgrade(gs,"c22703","attack",5);upgrade(gs,"c22703","defense",5)
	p.avatarHp=10;gs.player(1).avatarHp=20;gs._damage_unit(0,1,3,1,0);var before: int=p.units[1].hp;play(gs,"c22703","avatar-0")
	check(p.avatarHp==19 and p.units[1].hp==mini(before+4,int(p.units[1].maxHp)),"repeatabletier3actualextra4targethealplusothercharacters4")
	check(gs.player(1).avatarHp==24,"officialothercharactersscopeincludesenemyavatarwithoutinventedallyfilter")
func auto_and_awake() -> void:
	var gs:=game();var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];var hand_count: int=p.hand.size();var fire: int=p.energy;var deck: int=p.deck.size()
	Fish.generated(gs,0,0,"c22701");gs._resolve_resolution_stack()
	check(Fish.attached(u) and p.energy==fire and p.hand.size()==hand_count+1 and p.deck.size()==deck-1,"generatedinitialbasealsoreplaceswithattachanddrawwithoutfire")
	p.hand.clear();deck=p.deck.size();var avatar: int=gs.player(1).avatarHp;play(gs,"c22707")
	var uses: Array=events(gs,"goldfish-generated").slice(1).map(func(e):return e.card.id)
	check(uses==Fish.BASE_IDS and events(gs,"automatic-card").size()==4,"fanreallygeneratesall3sequentialactualcards")
	check(p.deck.size()==deck and p.energy==fire-1 and gs.player(1).avatarHp<avatar and u.front==0,"fanwithoutfakefirstdraworalliedbuffshortcut")
	gs=game();p=gs.player(0);u=p.units[0];play(gs,"c22706")
	check(u.awakened and u.attack==4 and u.maxHp==5 and not Fish.attached(u) and events(gs,"goldfish-generated").is_empty(),"unattachedawake1/1nogeneratedenhancementandnostraydraw")
	Fish.turn_start(gs,0);gs._resolve_resolution_stack();check(Fish.attached(u),"awakenedstartattachtruecharm")
	gs._knockout_unit(u);check(not Fish.attached(u),"knockoutremovesrealgoldfishcharm")
	Fish.turn_start(gs,0);check(not Fish.attached(u) and u.hp==0,"knockedawakecannotreattachorrevive")
	gs=game();p=gs.player(0);u=p.units[0];Fish.attach(gs,0,0);play(gs,"c22706")
	check(events(gs,"goldfish-generated").size()==1 and not gs.can_play_card(0,give(gs,"c22706")).ok,"attachedawakeenhanceswithrealgeneratedbasecardandnoawakereuse")
	gs=game();p=gs.player(0);u=p.units[0];play(gs,"c22708")
	check(u.maxHp>=8 and u.form.cardId=="c22708" and events(gs,"goldfish-strengthened").size()==1 and events(gs,"goldfish-generated").size()==1,"form3/8entryrandomrealupgradeandactualcarduse")
	Fish.turn_start(gs,0);gs._resolve_resolution_stack();check(events(gs,"goldfish-strengthened").size()==2 and events(gs,"goldfish-generated").size()==2,"formrealstartupgradeanduseagain")
	u.frozen=2;Fish.turn_start(gs,0);gs._resolve_resolution_stack();check(events(gs,"goldfish-generated").size()==2,"stunnedformcannotusegeneratedcards")
	gs=game();p=gs.player(0);u=p.units[0];check(gs.VerifiedRules.Incarnation.config(u,gs,0).is_empty(),"withoutcharmnoincarnation")
	Fish.attach(gs,0,0);var cfg:=gs.VerifiedRules.Incarnation.config(u,gs,0)
	check(cfg.get("mode")=="goldfish" and cfg.start==20 and cfg.action==8 and cfg.limit==1,"actualgoldfishcharmnativeincarnationconfig")
	u.incarnationChance=100;var before_hand: int=p.hand.size();fire=p.energy;deck=p.deck.size()
	gs.VerifiedRules.Incarnation.trigger_now(gs,0,true);gs._resolve_resolution_stack()
	check(events(gs,"incarnation-card").size()==1 and p.hand.size()==before_hand and p.deck.size()==deck and p.energy==fire,"forcedrealincarnationgeneratesactualbasewithoutzonesorfire")
	u.incarnationChance=100;gs.VerifiedRules.Incarnation.trigger_now(gs,0,false);gs._resolve_resolution_stack();check(events(gs,"incarnation-card").size()==1,"goldfishincarnationgenuineonceperturn")
	gs.VerifiedRules.Moon.full_moon(gs,u);check(not Fish.attached(u) and gs.VerifiedRules.Incarnation.config(u,gs,0).is_empty(),"realmoonremoveallcharmsdisablesgoldfishincarnation")
	gs=game();p=gs.player(0);u=p.units[0];deck=p.deck.size();p.nullifyNextCardTurn=gs.turn_counter;play(gs,"c22701")
	check(not Fish.attached(u) and p.deck.size()==deck,"counteredfirst1cardcannotattachtokenorfakedraw")
func ai_and_art() -> void:
	for n in range(1,9):
		var gs:=game();var p: Dictionary=gs.player(0);Fish.attach(gs,0,0);p.avatarHp=20
		var id: String="c227%02d"%n;give(gs,id);var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AIlegalchoice "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AIactualhandplay "+id)
		if not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty(),"AIactualupgradechoice "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalPNG "+id)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["jinyuji","yaodaoji","taohuayao","shantu"],["yaodaoji","bingyong","xuenv","baizangzhu"],227);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true
			for u in p.units:u.level=3;u.incarnationChance=-100000
		root.add_child(b);await create_timer(0.4).timeout
		var gs=b.gs;var p: Dictionary=gs.player(0);var u: Dictionary=p.units[0];var foe: Dictionary=gs.player(1)
		hand(b,["c22702"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(Fish.attached(u) and u.front==0 and b._pending_target_card<0,"nativemousefirstcombatonlyattachesnodamagetarget")
		hand(b,["c22704"]);await settled(b);var deck: int=p.deck.size();await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.get("type")=="goldfish-upgrade" and faces(b._choice_layer).size()==3 and p.deck.size()==deck,"native3realattackupgradeoptionsbeforelaterdraw")
		check(texts(b._choice_layer).contains("进攻") and texts(b._choice_layer).contains("额外+2力量"),"nativeupgradeoptionsdetailactualcurrenttier")
		if physical.x==1280:await capture("01-goldfish-attack-upgrade-choice")
		var face:=choice_face(b,"c22701");check(face!=null,"nativeactualsupportchoicecard")
		if face!=null:await click(face)
		await settled(b);check(gs.pending_choice.is_empty() and Fish.upgrades(gs,0,"c22701").has("support-power") and p.deck.size()==deck-1,"nativemousechoiceupgradesonlychosenanddraws")
		hand(b,["c22701"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0,"nativeattachedsupportrealallytargetmode")
		var power: int=p.units[1].attack;await click(b._unit_widget(str(foe.units[0].uid)));await settled(b);check(b._pending_target_card==0,"nativerejectenemywithoutpaying")
		await click(b._unit_widget(str(p.units[1].uid)));await settled(b);check(p.units[1].attack==power+3,"nativeactualupgradedsupportplus3power")
		hand(b,["c22703"]);p.avatarHp=20;await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and gs.valid_targets(0,b._pending_target_card_def).has("avatar-0"),"nativerestactualavatarandunitselectors")
		await click(b._ally_target_btn);await settled(b);check(p.avatarHp==25,"nativeactualmousehealsownavatar5")
		hand(b,["c22705"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.get("direction")=="defense" and faces(b._choice_layer).size()==3,"nativeindependentdefense3options")
		if physical.x==1600:await capture("02-goldfish-defense-upgrade-choice")
		face=choice_face(b,"c22703")
		if face!=null:await click(face)
		await settled(b);check(Fish.upgrades(gs,0,"c22703").has("rest-armor"),"nativeactualrestdefensearmorupgrade")
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	base_cards();choices_and_tiers();support_training_traits();rest_traits();auto_and_awake();ai_and_art()
	if not rules_only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("GOLDFISH checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
