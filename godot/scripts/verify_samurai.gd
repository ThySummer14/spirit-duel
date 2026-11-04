extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Samurai := preload("res://scripts/samurai_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1; printerr("SAMURAI_FAIL ",detail)

func game() -> GS:
	var gs:=GS.create(["wushizhiling","taohuayao","bingyong","yaodaoji"],["yaodaoji","bingyong","xuenv","baizangzhu"],193)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"samurai-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()

func lifecycle() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	check(u.attack==3 and u.maxHp==3 and u.passive_hooks.is_empty(),"body exact3/3 and no old post-combat-growth approximation")
	gs._knockout_unit(u)
	check(u.hp==0 and u.knockout==2 and Samurai.ghost(u) and Samurai.power(u)==1,"real dead identity plus1/0 ghost transformation")
	check(not u.swift and gs.VerifiedRules.TomatoFire.basic_cost(gs,0,u)==1,"ordinary ghost never mixes in removed historical swift")
	check(not gs.valid_targets(1,Content.card_def("c11902")).has(u.uid),"ghost is not a living spell target")
	gs._heal_unit(u,9); gs._damage_unit(0,0,9,1,0)
	check(u.hp==0 and u.samuraiDeaths==1,"ghost cannot be healed into fake body or killed repeatedly by damage")
	foe.units[1].front=1; var hp: int=foe.units[1].hp; var face: int=foe.avatarHp; var energy: int=p.energy
	check(gs.basic_attack_targets(0,0)==["avatar-1"] and gs.can_basic_attack(0,0).ok,"actual ghost basic command has avatar target through enemy front")
	check(gs.basic_attack(0,0,"avatar-1") and foe.avatarHp==face-1 and foe.units[1].hp==hp and p.energy==energy-1,"real ghost basic combat bypasses blocker for exact1 damage")
	check(u.hp==0 and gs.front_index(0)<0 and p.attackUsed,"ghost stays dead, cannot block and consumes ordinary shared attack")
	check(not gs.basic_attack(0,0,"avatar-1"),"ghost receives no unlimited ordinary attacks")
	check(gs.end_turn(0),"real enemy turn after ghost attack"); foe.levelUpUsed=true
	face=p.avatarHp
	check(gs.basic_attack(1,0) and p.avatarHp==face-3 and u.hp==0,"enemy actual combat ignores dead ghost front and hits avatar")
	check(gs.end_turn(1) and u.knockout==1 and Samurai.ghost(u),"first own turn decrements real death countdown")
	check(gs.end_turn(0) and gs.end_turn(1) and u.hp==u.maxHp and u.knockout==0 and not Samurai.ghost(u),"natural second own turn restores body and removes ghost form")
	check(Samurai.power(u)==3,"body returns to actual3 strength")
	gs=game(); u=gs.player(0).units[0]; u.baseRulesSuppressed=true; gs._knockout_unit(u)
	check(not u.get("samuraiGhost",false),"paper-suppressed death snapshot does not accidentally activate restored samurai passive")
	gs=game(); u=gs.player(0).units[0]; u.level=0; gs._knockout_unit(u)
	check(not Samurai.ghost(u) and not gs.can_basic_attack(0,0).ok,"inactive body never obtains usable ghost")

func combat_cards() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	foe.units[1].front=1; gs._grow_unit(foe.units[1],0,30); var hp: int=foe.units[1].hp; var energy: int=p.energy
	play(gs,"c19301"); check(p.energy==energy-1 and foe.units[1].hp==hp-4,"living heart costs1 and actual3+1 combat")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; gs._knockout_unit(u); energy=p.energy
	play(gs,"c19301"); check(foe.avatarHp==28 and p.energy==energy and gs.kw_usage(0,"instant").used,"ghost heart exact2 real combat consumes first shared instant")
	play(gs,"c19301"); check(foe.avatarHp==26 and p.energy==energy-1,"second ghost heart costs real fire, no unlimited instant")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; var deck: int=p.deck.size(); play(gs,"c19302")
	check(u.hp==0 and u.samuraiGhostBonus==1 and Samurai.power(u)==2 and p.deck.size()==deck and p.hand.is_empty(),"suicide truly kills body and permanently strengthens ghost only without inventing draw")
	play(gs,"c19302"); check(u.samuraiDeaths==1 and u.samuraiGhostBonus==2 and Samurai.power(u)==3,"suicide while already ghost strengthens without a second fake death")
	check(gs.VerifiedRules.Peach.revive(gs,0,1,u,false,false) and u.hp==3 and not Samurai.ghost(u) and Samurai.power(u)==3,"external legal revival restores body without applying ghost-only permanent bonus")
	gs._knockout_unit(u); check(Samurai.power(u)==3,"subsequent ghost reuses both permanent suicide bonuses")
	foe.units[1].front=1; gs._grow_unit(foe.units[1],0,30); hp=foe.units[1].hp; var face: int=foe.avatarHp
	play(gs,"c19303"); check(foe.units[1].hp==hp-4 and foe.avatarHp==face and u.hp==0,"Tangzhu suppresses ghost direct attack for this real combat and hits blocker")
	play(gs,"c19301"); check(foe.avatarHp==face-4,"Tangzhu suppression expires with its attack, next heart is direct again")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; u.hp=1; foe.units[1].front=1; gs._grow_unit(foe.units[1],3,30); hp=foe.units[1].hp
	play(gs,"c19304")
	check(u.hp==0 and Samurai.ghost(u) and foe.units[1].hp==hp-5 and foe.avatarHp==27,"anger body combat deaths followed by exact+2 ghost combat")
	check(events(gs,"samurai-anger-reused")==1 and p.hand.is_empty() and p.energy==39,"anger genuinely reuses once through generated card frames with no hand/fire cost")
	gs=game(); foe=gs.player(1); gs._grow_unit(gs.player(0).units[0],0,30); foe.units[1].front=1; gs._grow_unit(foe.units[1],0,30); play(gs,"c19304")
	check(events(gs,"samurai-anger-reused")==0 and foe.avatarHp==30,"survived anger never generates an extra attack")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; u.hp=1; u.keywords=["combo"]; foe.units[1].keywords=["combo"]; foe.units[1].front=1; gs._grow_unit(foe.units[1],3,30); hp=foe.units[1].hp
	play(gs,"c19301"); check(u.hp==0 and foe.units[1].hp==hp-4 and foe.avatarHp==30,"body death invalidates remaining old combo instead of letting converted ghost continue")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; foe.units[1].front=1; gs._grow_unit(foe.units[1],0,30); hp=foe.units[1].hp
	play(gs,"c19305"); check(foe.units[1].hp==hp-6 and u.shield==2 and u.hp==3,"honor exact+3attack/+3armor participates in actual simultaneous battle")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; gs._knockout_unit(u); play(gs,"c19305")
	check(foe.avatarHp==26 and u.hp==0 and u.shield==0,"ghost honor remains dead and cannot turn armor into a blocking body")

func conditional_and_awaken() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	var hand_idx:=give(gs,"c19306"); check(gs.hand_card_def(0,hand_idx).value==1,"grudge positive base+1 with no dead allies")
	gs._knockout_unit(p.units[1]); gs._knockout_unit(p.units[2]); check(gs.hand_card_def(0,hand_idx).value==3,"grudge counts exactly two currently knocked-out actual shikigami")
	gs._knockout_unit(u); check(gs.hand_card_def(0,hand_idx).value==4,"grudge includes samurai ghost's actual dead identity")
	check(gs.play_card(0,hand_idx) and foe.avatarHp==25,"grudge actual ghost1 plus enhanced4 direct combat")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; hand_idx=give(gs,"c19307")
	check(gs.hand_card_def(0,hand_idx).target=="auto" and not gs.hand_card_def(0,hand_idx).keywords.has("pursuit"),"body soulcut has no pursuit or target choice")
	gs._knockout_unit(u); foe.units[0].front=1; foe.units[2].keywords=["veil"]
	var card:=gs.hand_card_def(0,hand_idx); var opts:=gs.valid_targets(0,card)
	check(card.keywords.has("pursuit") and opts.has(foe.units[1].uid) and not opts.has(foe.units[2].uid) and not opts.has("avatar-1"),"ghost soulcut selects live enemy reserve and obeys veil, never avatar")
	check(not gs.can_play_card(0,hand_idx,foe.units[2].uid).ok and not gs.can_play_card(0,hand_idx,"avatar-1").ok,"direct command cannot bypass pursuit target legality")
	var hp: int=foe.units[1].hp; check(gs.play_card(0,hand_idx,foe.units[1].uid) and foe.units[1].hp==hp-3 and foe.avatarHp==30,"soulcut pursuit overrides ghost direct attack for exact1+2 chosen reserve combat")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; play(gs,"c19308")
	check(u.awakened and u.hp==0 and Samurai.ghost(u) and u.samuraiCannotRevive and Samurai.power(u)==3,"awakening true self-knockout, exact+2 persistent power and cannot-revive")
	check(not gs.VerifiedRules.Peach.revive(gs,0,1,u,false,false) and not gs.VerifiedRules.Rebirth.can_revive(u),"both common external revival and natural revival reject awakened ghost")
	p.energy=0; check(gs.can_basic_attack(0,0).ok and gs.basic_attack(0,0,"avatar-1") and p.energy==0 and foe.avatarHp==27,"awake permanent swift permits actual ordinary ghost attack with zero fire")
	check(not gs.can_basic_attack(0,0).ok,"permanent swift does not restore used ordinary attack quota")
	var countdown: int=u.knockout
	check(gs.end_turn(0) and gs.end_turn(1) and u.knockout==countdown and u.hp==0,"awake remains true dead ghost after own-start lifecycle")
	p.levelUpUsed=true; p.energy=0; check(gs.can_basic_attack(0,0).ok and gs.basic_attack(0,0,"avatar-1") and p.energy==0,"permanent swift persists across real turn and ordinary consumption")
	gs=game(); u=gs.player(0).units[0]; play(gs,"c19302"); play(gs,"c19308")
	check(Samurai.power(u)==4 and u.samuraiDeaths==1,"awakening while ghost adds exact2 once without resetting death/ghost bonus")
	check(not gs.can_play_card(0,give(gs,"c19308")).ok,"awakening cannot be legally repeated")
	gs=game(); u=gs.player(0).units[0]; gs._knockout_unit(u); u.frozen=1
	check(not gs.can_basic_attack(0,0).ok and not gs.can_play_card(0,give(gs,"c19301")).ok,"ghost exemption applies to knockout, not an unrelated real stun")

func ai_and_art() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); gs._knockout_unit(p.units[0]); foe.units[1].front=1
	give(gs,"c19301"); var best:=AI._best_card(gs,0)
	check(best.ok and best.card_id=="c19301" and gs.play_card(0,best.hand,best.target) and foe.avatarHp==28,"AI actually uses legal knocked-out source instant direct combat")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._knockout_unit(p.units[0]); give(gs,"c19307"); foe.units[2].keywords=["veil"]; best=AI._best_card(gs,0)
	check(best.ok and gs.valid_targets(0,gs.hand_card_def(0,best.hand)).has(best.target) and best.target!=foe.units[2].uid and gs.play_card(0,best.hand,best.target),"AI selects and executes actual legal ghost pursuit against shikigami")
	for id in ["c19301","c19302","c19303","c19304","c19305","c19306","c19307","c19308"]: check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original art "+id)

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["wushizhiling","taohuayao","bingyong","yaodaoji"],["yaodaoji","bingyong","xuenv","baizangzhu"],193); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for unit in side.units: unit.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
		foe.units[1].front=1; gs._grow_unit(foe.units[1],0,30); hand(b,["c19302"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(u.hp==0 and Samurai.ghost(u) and Samurai.power(u)==2,"native real suicide preserves0HP and creates strengthened ghost")
		hand(b,["c19301"]); await settled(b)
		check(b._hand_row.get_child(0).playable and b._hand_row.get_child(0).data.payment.usesInstant,"native ghost hand is enabled with actual shared instant quote")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(foe.avatarHp==27 and u.hp==0,"native ghost instant causes real direct3damage through blocker")
		hand(b,["c19307"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[0].uid)).selected and b._unit_widget(str(foe.units[2].uid)).selected,"native pursuit presents actual enemy frontline and reserve targets")
		if physical.x==1600: await capture("01-ghost-pursuit-real-targets")
		var hp: int=foe.units[1].hp; await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(foe.units[1].hp==hp-4 and foe.avatarHp==27 and u.hp==0,"native target click executes ghost pursuit instead of fake avatar damage")
		hand(b,["c19308"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(u.awakened and u.samuraiCannotRevive and Samurai.power(u)==4,"native awakening works while truly knocked out and keeps ghost-only permanent bonus")
		await click(b._unit_widget(str(u.uid))); await settled(b)
		# A usable ghost must have its regular attack selector; second click opens inspector.
		if b._selected_attacker==0: await click(b._unit_widget(str(u.uid))); await settled(b)
		check(texts(b).contains("幽魂") and texts(b).contains("不能复活"),"native live inspector exposes ghost and irreversible awakening rule")
		if physical.x==1280: await capture("02-awakened-ghost-live-inspector")
		escape(); await settled(b); p.attackUsed=false; p.energy=0; b._refresh(); await settled(b)
		await click(b._unit_widget(str(u.uid))); await settled(b)
		check(b._selected_attacker==0,"native zeroHP permanent-swift ghost selectable for real ordinary attack")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores()
	var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	lifecycle(); combat_cards(); conditional_and_awaken(); ai_and_art()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("SAMURAI checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
