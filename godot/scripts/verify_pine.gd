extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Pine := preload("res://scripts/pine_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("PINE_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["xiaosongwan","shantu","yaoqinshi","taohuayao"],["yaodaoji","bingyong","xuenv","baizangzhu"],245)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"pine-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)
func force_die(gs, first: int) -> void:
	for seed in 100000:
		var a: int=(seed*1664525+1013904223)&0xffffffff
		if 1+int(floor(float(a)/4294967296.0*6))==first: gs.rng_state=seed; return
	check(false,"deterministic die fixture")
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func roll(gs, owner: int = 0, die: int = 6) -> bool:
	force_die(gs,die)
	return gs.VerifiedRules.Light.roll(gs,owner,4,6,0)
func base_and_bounce() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==6 and u.passive_hooks.is_empty(),"base exact2/6 and no old artificial turn growth")
	check(roll(gs) and not u.has("abilityCountdown") and not u.has("formCountdown"),"success with no countdown creates no fake buff/timer")
	gs._knockout_unit(u); check(u.knockout==2 and u.hp==0,"real base knockout2")
	check(not roll(gs,0,2) and u.knockout==2,"failed actual fortune never reduces knockout")
	check(roll(gs,1) and u.knockout==2,"enemy fortune never reduces own knockout")
	check(roll(gs) and u.knockout==1 and u.hp==0,"success reduces real knocked-out countdown")
	check(roll(gs) and u.knockout==0 and u.hp==6 and u.get("pineCountdownZeros",0)==1,"success revives on exactzero and records enhancement")
	gs=game(); p=gs.player(0); u=p.units[0]; u.level=0; gs._knockout_unit(u); roll(gs)
	check(u.knockout==2,"unactivated pine passive remains inactive")
	gs=game(); p=gs.player(0); u=p.units[0]; u.baseRulesSuppressed=true; gs._knockout_unit(u); u.baseRulesSuppressed=true; roll(gs)
	check(u.knockout==2,"suppressed base passive cannot reduce timer")
	gs=game(); p=gs.player(0); u=p.units[0]; gs._knockout_unit(u); var deck: int=p.deck.size(); var idx:=give(gs,"c24502"); var iid: String=p.hand[idx].instanceId; var fire: int=p.energy
	check(gs.can_play_card(0,idx).ok,"carry actually legal while source knocked out")
	force_die(gs,6); check(gs.play_card(0,idx),"actual carry success while knocked out")
	check(p.deck.size()==deck-1 and u.knockout==1 and p.energy==fire,"carry exact success draw and instant free use")
	idx=p.hand.find_custom(func(i):return i.instanceId==iid)
	check(idx>=0 and p.hand[idx].pineBounceSpent and not gs.hand_card_def(0,idx).keywords.has("bounce"),"bounce returns identical instance once and removes its bounce")
	force_die(gs,2); check(gs.play_card(0,idx),"carry replays returned actual instance")
	check(not p.hand.any(func(i):return i.instanceId==iid) and p.deck.size()==deck-1 and p.energy==fire-1,"failed replay draws nothing and cannot bounce or instant again")
	gs=game(); p=gs.player(0); u=p.units[0]; idx=give(gs,"c24502"); iid=p.hand[idx].instanceId; deck=p.deck.size(); force_die(gs,2); check(gs.play_card(0,idx),"first failed carry is still real use")
	check(p.hand.size()==1 and p.hand[0].instanceId==iid and p.deck.size()==deck,"bounce is independent of fortune success")
func forms_and_history() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	play(gs,"c24501"); check(u.attack==2 and u.maxHp==7 and u.formCountdown.remaining==3,"curiosity exact2/7 attached countdown3")
	roll(gs); check(u.formCountdown.remaining==2 and u.attack==2,"one fortune only reduces one")
	roll(gs); roll(gs); gs._resolve_resolution_stack()
	check(u.attack==3 and u.maxHp==8 and u.hp==8 and u.formCountdown.remaining==3,"curiosity actualzero exact+1/+1 and reset3")
	var h:=give(gs,"c24507"); check(gs.hand_card_def(0,h).value.attack==1,"awake hand reads actual lifetime timer history")
	u.formCountdown.remaining=1; var hp: int=foe.units[0].hp; foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20); hp=foe.units[0].hp
	check(gs.basic_attack(0,0) and foe.units[0].hp==hp-4,"attack-start countdownzero grows before this actual attack strength snapshot")
	check(u.get("pineCountdownZeros",0)==2 and u.formCountdown.remaining==3,"attack-trigger counted once and resets")
	gs._heal_unit(u,30); var history: int=u.pineCountdownZeros
	play(gs,"c24504"); check(u.attack==10 and u.maxHp==10 and u.form.is_empty()==false,"coward exact8/8 body retains earlier permanent+2/+2")
	gs._damage_unit(0,0,100,1,0); check(u.hp==0 and u.knockout==5 and u.form.is_empty(),"coward death exactbase2+3 even damage already reduced HP tozero")
	check(u.pineCountdownZeros==history,"death/formremoval do not fabricate timerzero")
	gs.VerifiedRules.reduce_countdown(gs,0,0,100); check(u.hp==u.maxHp and u.pineCountdownZeros==history+1,"death countdown overflow counts onezero")
	gs=game(); p=gs.player(0); u=p.units[0]; gs._knockout_unit(u); check(gs.end_turn(0) and gs.end_turn(1) and u.knockout==1,"actual natural countdown first turn")
	check(gs.end_turn(0) and gs.end_turn(1) and u.hp==6 and u.get("pineCountdownZeros",0)==1,"actual natural revival increments same history")
	gs=game(); p=gs.player(0); u=p.units[0]; var deck: int=p.deck.size(); play(gs,"c24505")
	check(u.attack==2 and u.maxHp==6 and u.front==1 and u.formCountdown.remaining==2 and p.deck.size()==deck-1,"forest idol actualinstant2/6 enters then draws1")
	gs.VerifiedRules.reduce_countdown(gs,0,0,2); gs._resolve_resolution_stack()
	check(u.form.is_empty() and not u.has("formCountdown") and u.attack==2 and u.maxHp==6 and u.front==1,"idol actual removal resets underlying body while keeping front")
	check(p.hand.any(func(i):return i.definitionId=="c24505"),"idol actual card returns hand atzero")
	p.hand.clear(); play(gs,"c24505"); play(gs,"c24504"); gs.VerifiedRules.reduce_countdown(gs,0,0,10); gs._resolve_resolution_stack()
	check(not p.hand.any(func(i):return i.definitionId=="c24505") and u.form.cardId=="c24504","replacing idol removes its timer with no imaginary returned oldform")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c24505"); p.hand.clear(); gs._knockout_unit(u); gs.VerifiedRules.reduce_countdown(gs,0,0,2); gs._resolve_resolution_stack()
	check(p.hand.is_empty(),"dead idol removed once and cannot later return from old countdown")
func damage_and_combat() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	var idx:=give(gs,"c24503"); foe.units[2].keywords=["veil"]; var card:=gs.hand_card_def(0,idx)
	check(gs.valid_targets(0,card).has(foe.units[0].uid) and not gs.valid_targets(0,card).has(foe.units[2].uid) and not gs.valid_targets(0,card).has("avatar-1"),"hit live reserve target and actual veil/avatar restrictions")
	check(not gs.can_play_card(0,idx,p.units[1].uid).ok and not gs.can_play_card(0,idx,foe.units[2].uid).ok,"direct hit API rejects ally and veil before payment")
	foe.units[1].level=0
	var hp: int=foe.units[1].hp; force_die(gs,6); check(gs.play_card(0,idx,foe.units[1].uid),"松果一击实际命中指定的零勾准备区式神")
	check(foe.units[1].hp==hp-3 and foe.units[1].frozen==1 and u.front==1 and u.hp==6,"hit exact3 damage then successfulstun, source enters unhurt withoutcombat")
	gs=game(); foe=gs.player(1); u=gs.player(0).units[0]; hp=foe.units[1].hp; force_die(gs,2); play(gs,"c24503",foe.units[1].uid)
	check(foe.units[1].hp==hp-3 and foe.units[1].frozen==0 and u.front==1,"failedhitfortune keeps damage andentry, no fake stun")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; foe.units[1].front=1; gs._grow_unit(foe.units[1],6,20); hp=foe.units[1].hp; force_die(gs,6); play(gs,"c24506",foe.units[1].uid)
	check(foe.units[1].hp==hp-4 and u.hp==6,"pursuit+2 truecombat success immune to actual highcounterstrike")
	check(not u.get("immuneCombat",false),"leap immunity is scoped only to this battle")
	gs._damage_unit(0,0,1,1,0); check(u.hp==5,"leap doesnot grant permanent or spell immunity")
	gs=game(); foe=gs.player(1); u=gs.player(0).units[0]; force_die(gs,2); play(gs,"c24506",foe.units[0].uid)
	check(foe.units[0].hp==0 and u.hp==3,"failed leap retains real4 damage plus3 normalcounterstrike")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; play(gs,"c24501"); u.formCountdown.remaining=1; hp=foe.units[0].hp; force_die(gs,6); play(gs,"c24506",foe.units[0].uid)
	check(u.attack==3 and u.maxHp==8 and foe.units[0].hp==0 and u.formCountdown.remaining==2,"leap fortunezero grows before battle; curiosity attack separately reduces reset timer")
func awake_and_summon() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	play(gs,"c24507"); check(u.awakened and u.swift and u.attack==2 and u.maxHp==6,"zero-history awake grants exact0/0 and one swift")
	check(gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u)==0 and gs.basic_attack(0,0) and not u.swift,"awakening swift reallyfree once and consumed")
	p.attackUsed=false; check(gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u)==1,"awake doesnot invent permanentlyfree ordinary attacks")
	check(not gs.can_play_card(0,give(gs,"c24507")).ok,"awake cannot be played twice")
	gs._knockout_unit(u); gs.VerifiedRules.reduce_countdown(gs,0,0,2); check(u.hp==6 and u.swift,"revived awakened body regains innate swift")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c24501"); gs.VerifiedRules.reduce_countdown(gs,0,0,3); gs._resolve_resolution_stack(); gs._knockout_unit(u); gs.VerifiedRules.reduce_countdown(gs,0,0,2)
	var h:=give(gs,"c24507"); check(gs.hand_card_def(0,h).value.attack==2 and gs.hand_card_def(0,h).value.hp==2,"awake lifetimehistory includes form and true deathzero")
	check(gs.play_card(0,h) and u.attack==5 and u.maxHp==9,"history2 awake grants exact+2/+2 above previous+1/+1")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c24508")
	var token: Dictionary=p.units.back(); check(token.pineSummon and token.attack==4 and token.hp==4 and token.front==1 and u.front==0,"harvest entry-2 immediately summons real4/4 frontline token")
	check(u.formCountdown.remaining==2 and u.get("pineCountdownZeros",0)==1,"harvestentry timer counts realzero and resets2")
	check(gs.can_basic_attack(0,p.units.size()-1).ok,"real pine token may make legal ordinary attacks")
	var token_id: String=token.uid; var total: int=p.units.size(); gs.VerifiedRules.reduce_countdown(gs,0,0,2); gs._resolve_resolution_stack()
	check(p.units.size()==total and p.units.back().uid==token_id and token.attack==8 and token.hp==8 and not u.has("pineKeywords"),"secondpine trulyfuses4/4 with nofalse leave reward")
	check(gs.VerifiedRules.Movement.move_to(gs,0,0,1),"actual source displaces token")
	check(token.removed and token.hp==0 and token.knockout==0 and u.pineKeywords.size()==1,"real displacement removes token without revival and grants onekeyword")
	var count: int=u.pineKeywords.size(); Pine.clear_summons(gs,0); Pine.remove_departed(gs)
	check(u.pineKeywords.size()==count,"same token leave callback idempotent")
	var token_idx:=Pine.summon(gs,0,0); token=p.units[token_idx]; gs._damage_unit(0,token_idx,100,1,0)
	check(token.removed and token.hp==0 and token.knockout==0 and u.pineKeywords.size()==2,"actual damageknockout removes summon and triggers second distinct reward")
	Pine.summon(gs,0,0); var reward: int=u.pineKeywords.size(); gs.VerifiedRules.Forms.remove(gs,0,0,"替换"); Pine.clear_summons(gs,0)
	check(u.pineKeywords.size()==reward,"departed harvest form has no lingering reward source")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c24508"); var opponent_history: int=u.get("pineKeywords",[]).size(); Pine.clear_summons(gs,1)
	check(u.get("pineKeywords",[]).size()==opponent_history,"enemy summon clearing cannot grant allyreward")
	for keyword in Pine.TRAITS:
		Pine.grant_trait(gs,0,0,keyword)
		check(u.pineKeywords.has(keyword),"full supported randompool "+keyword)
		if keyword=="swift": check(u.swift,"swift reward uses one-usefield")
		elif keyword=="unyielding": check(u.unyielding,"unyielding reward protectsactual damage")
		else: check(gs.VerifiedRules.Combat.has(u,keyword),"keyword actual rule enabled "+keyword)
	var snapshot:=JSON.stringify(gs.snapshot()); var marks:=Pine.unit_marks(gs,0,0)
	check(marks.size()>=2 and JSON.stringify(gs.snapshot())==snapshot,"livepine status read-only exposeshistory andrealrewardpool")
	gs._knockout_unit(u); check(not u.has("pineKeywords") and not gs.VerifiedRules.Combat.has(u,"remote"),"death clears nonpermanent token-granted keywordeffects")
func ai_and_art() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); gs._knockout_unit(p.units[0]); give(gs,"c24502"); force_die(gs,6); var best:=AI._best_card(gs,0)
	check(best.ok and best.card_id=="c24502" and gs.play_card(0,best.hand,best.target),"AI legally executes instantbounce carry from truesourceknockout")
	gs=game(); foe=gs.player(1); foe.units[2].keywords=["veil"]; give(gs,"c24506"); force_die(gs,6); best=AI._best_card(gs,0)
	check(best.ok and best.target!=foe.units[2].uid and gs.valid_targets(0,gs.hand_card_def(0,best.hand)).has(best.target) and gs.play_card(0,best.hand,best.target),"AI legally chooses pursuit target and executes actualcombat")
	for id in ["c24501","c24502","c24503","c24504","c24505","c24506","c24507","c24508"]: check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original art "+id)
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["xiaosongwan","shantu","yaoqinshi","taohuayao"],["yaodaoji","bingyong","xuenv","baizangzhu"],245); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for unit in side.units: unit.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
		hand(b,["c24503"]); force_die(gs,6); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[1].uid)).selected,"native hit presents actual reserve targets")
		var fire: int=p.energy; await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"native illegal allytarget spendsnothing")
		var hp: int=foe.units[1].hp; await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(u.front==1 and u.hp==6 and foe.units[1].hp==hp-3 and foe.units[1].frozen>0,"native hit mouse moves source, exact3 andrealstun")
		hand(b,["c24506"]); force_die(gs,6); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[0].uid)).selected,"native pursuit actually enters separatetargetmode")
		if physical.x==1600: await capture("01-pine-pursuit-real-targets")
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(foe.units[0].hp==0 and u.hp==6,"native leap selected reserve gets exact4, actualcounterimmune")
		hand(b,["c24508"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units.back().get("pineSummon",false) and p.units.back().front==1 and u.front==0,"native harvest entry createslive4/4 token")
		await click(b._unit_widget(str(u.uid))); await settled(b)
		if b._selected_attacker==0: await click(b._unit_widget(str(u.uid))); await settled(b)
		check(texts(b).contains("倒计时归零") and texts(b).contains("秋收冬藏"),"native inspector exposes actual history/form countdown")
		if physical.x==1280: await capture("02-pine-harvest-history-inspector")
		escape(); await settled(b); gs.VerifiedRules.Movement.move_to(gs,0,0,1); b._refresh(); await settled(b)
		check(u.get("pineKeywords",[]).size()==1,"native board displacement showsactualkeywordgrowth")
		gs._knockout_unit(u); hand(b,["c24502"]); force_die(gs,6); await settled(b)
		check(b._hand_row.get_child(0).playable,"native realknockout carry remains enabled")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(u.knockout==1 and p.hand.any(func(i):return i.definitionId=="c24502" and i.get("pineBounceSpent",false)),"native deadsource carry actually ticks and bouncesidenticalinstance")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	base_and_bounce(); forms_and_history(); damage_and_combat(); awake_and_summon(); ai_and_art()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("PINE checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
