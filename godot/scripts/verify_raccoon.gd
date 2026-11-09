extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Raccoon := preload("res://scripts/raccoon_rules.gd")
const Stun := preload("res://scripts/stun_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("RACCOON_FAIL ",detail)

func game(own: Array = ["limao","fenghuanghuo","yuzaoqian","baizangzhu"]) -> GS:
	var gs:=GS.create(own,["limao","yaodaoji","bingyong","baizangzhu"],248)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"raccoon-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()

func passives() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(u.attack==2 and u.maxHp==6,"base exact2/6")
	u.hp=1; Stun.apply(gs,0,0,1,0); gs._resolve_resolution_stack()
	check(u.hp==4 and u.attack==4 and u.frozen==2,"self stun heals3 grows2 and keeps actual next-own-end duration")
	check(not gs.can_basic_attack(0,0).ok,"ordinary stunned raccoon cannot basic attack")
	var h:=give(gs,"c24801"); check(not gs.can_play_card(0,h,p.units[1].uid).ok,"ordinary spell remains illegal while stunned")
	h=give(gs,"c24802"); check(gs.can_play_card(0,h).ok,"cup explicitly usable while stunned")
	h=give(gs,"c24807"); check(gs.can_play_card(0,h).ok,"flame explicitly usable while stunned")
	Stun.apply(gs,0,0,1,1); gs._resolve_resolution_stack()
	check(u.hp==6 and u.attack==6 and u.frozen==2,"reapplied stun is retained and triggers recovery without deleting stun")
	for mode in ["inactive","paper","dead"]:
		gs=game(); u=gs.player(0).units[0]; u.hp=1
		if mode=="inactive": u.level=0
		elif mode=="paper": u.baseRulesSuppressed=true
		else: gs._knockout_unit(u)
		var power: int=u.attack; Stun.apply(gs,0,0,1,1); gs._resolve_resolution_stack()
		check(u.attack==power and events(gs,"raccoon-stun-reaction")==0,"no native passive when "+mode)
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c24804")
	check(u.awakened and u.attack==3 and u.maxHp==7 and p.hand.size()==1 and p.hand[0].definitionId=="yaojiu","awakening exact1/1 plus actual generated wine in baseline version")
	u.hp=1; play(gs,"yaojiu",u.uid)
	check(u.hp==7 and u.attack==5 and u.frozen==2 and gs.can_basic_attack(0,0).ok,"awake restores all health and ignores restrictions while retaining stun")
	check(gs.basic_attack(0,0) and u.frozen==2 and p.attackUsed,"awake actual basic attack consumes normal shared attack but leaves stun")
	check(gs.end_turn(0) and u.frozen==1 and gs.end_turn(1) and gs.end_turn(0) and u.frozen==0,"ignored stun still expires through real turn boundaries")

func cards_and_targets() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	var hp: int=p.units[3].hp; play(gs,"c24801",p.units[3].uid)
	check(p.units[3].hp==hp-3 and p.hand.size()==1 and p.hand[0].definitionId=="yaojiu" and p.units[0].shield==0,"persuade actual friendly3damage plus wine, never substitute armor")
	var energy: int=p.energy; play(gs,"yaojiu",foe.units[1].uid)
	check(foe.units[1].frozen==1 and p.energy==energy and gs.kw_usage(0,"instant").used,"first wine shares actual instant quota")
	foe.units[2].level=0
	play(gs,"yaojiu",foe.units[2].uid); check(p.energy==energy-1 and foe.units[2].frozen>0,"第二张妖酒实扣鬼火并眩晕零勾式神")
	foe.units[3].keywords=["veil"]; p.units[2].keywords=["veil"]
	var h:=give(gs,"yaojiu"); var opts:=gs.valid_targets(0,gs.hand_card_def(0,h))
	check(opts.has(p.units[0].uid) and opts.has(p.units[2].uid) and not opts.has(foe.units[3].uid) and not opts.has("avatar-1"),"wine supports friendly shikigami, obeys hostile veil and rejects avatars")
	check(not gs.can_play_card(0,h,foe.units[3].uid).ok,"command cannot bypass hostile veil")
	gs=game(); p=gs.player(0); play(gs,"c24803")
	check(p.units[0].attack==2 and p.units[0].maxHp==6,"expert actual2/6 form")
	check(gs.end_turn(0) and p.hand.is_empty(),"expert reserve does not generate wine at own end")
	gs=game(); p=gs.player(0); play(gs,"c24803"); p.units[0].front=1
	check(gs.end_turn(0) and p.hand.size()==1 and p.hand[0].definitionId=="yaojiu","expert actual own end generates one wine on front")
	check(gs.end_turn(1) and events(gs,"raccoon-wine-created")==1,"expert never generates at enemy end or own start")
	gs=game(); p=gs.player(0); play(gs,"c24805")
	check(p.units[0].attack==4 and p.units[0].maxHp==6 and gs.VerifiedRules.Combat.has(p.units[0],"veil") and p.hand.size()==1,"drunk4/6 grants real veil and one actual wine")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c24806"); gs._grow_unit(foe.units[1],7,30); foe.units[1].front=1; hp=foe.units[1].hp; p.units[0].hp=2; energy=p.energy
	check(p.units[0].attack==4 and p.units[0].maxHp==8 and p.hand.size()==2,"drunkard4/8 enters with two wine instances")
	play(gs,"yaojiu",p.units[0].uid)
	check(p.units[0].attack==6 and p.units[0].hp==5 and foe.units[1].hp==hp-6 and p.units[0].front==1,"stun triggers real6power immune attack after native healing")
	check(p.units[0].frozen==2 and not p.attackUsed and p.energy==energy,"triggered attack bypasses stun, consumes neither ordinary attack nor extra fire")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.units[0].frozen=1; gs._grow_unit(foe.units[1],8,30); foe.units[1].front=1; hp=p.units[0].hp; var before: int=foe.units[1].hp
	play(gs,"c24802"); check(p.units[0].hp==hp and foe.units[1].hp==before-3 and p.units[0].frozen==1,"stunned proactive cup performs exact+1 immune actual combat")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.units[0].front=1; p.units[0].frozen=1; give(gs,"c24802"); check(gs.end_turn(0),"enter real enemy turn for cup response"); foe.energy=2; foe.levelUpUsed=true
	gs._grow_unit(foe.units[1],8,30); hp=p.units[0].hp; before=foe.units[1].hp
	check(gs.basic_attack(1,1) and p.units[0].hp==hp and foe.units[1].hp==before-3 and p.hand.is_empty(),"stunned cup automatically modifies current defense, no separate assault or fake armor")
	check(events(gs,"response-card")==1,"cup uses actual response pipeline")
	gs=game(); p=gs.player(0); p.units[0].front=1; p.units[0].frozen=1; p.energy=0; give(gs,"c24802"); check(gs.end_turn(0),"no-fire response enters actual enemy turn")
	gs.player(1).levelUpUsed=true; hp=p.units[0].hp
	check(gs.basic_attack(1,1) and p.units[0].hp==hp-3 and p.hand.size()==1 and events(gs,"response-card")==0,"cup cannot automatically respond without actual fire")

func flame_and_realm() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	for u in foe.units: gs._grow_unit(u,0,30)
	foe.units[0].frozen=1; foe.avatarFrozen=1; p.units[0].frozen=1
	var hps: Array=foe.units.map(func(u):return int(u.hp)); play(gs,"c24807")
	check(foe.avatarHp==24 and foe.units[0].hp==hps[0]-6 and foe.units[1].hp==hps[1]-3 and foe.units[2].hp==hps[2]-3 and foe.units[3].hp==hps[3]-3,"flame actual two waves:3all then3only currently stunned including avatar")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c24808"); p.units[1].frozen=1
	check(p.realms[0].hp==6 and p.energy==39,"feast exact6durability and1fire")
	var h:=give(gs,"c12404"); var card:=gs.hand_card_def(0,h)
	check(card.keywords.has("instant") and gs.effective_card_cost(0,card)==0 and gs.can_play_card(0,h,foe.units[1].uid).ok,"stunned teammate spell gains real shared instant and legal casting")
	check(gs.can_basic_attack(0,1).ok and p.units[1].frozen==1,"feast allows actual stunned teammate basic command without clearing state")
	p.avatarFrozen=1; check(not gs.can_basic_attack(0,1).ok,"feast affects stunned shikigami, never overrides stunned avatar restriction"); p.avatarFrozen=0
	check(not gs.hand_card_def(0,give(gs,"c22101")).keywords.has("instant"),"unstunned teammate receives no instant")
	var energy: int=p.energy; check(gs.play_card(0,h,foe.units[1].uid) and p.energy==energy,"feast actual instant payment")
	h=give(gs,"c12404"); check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==1,"feast never grants unlimited free casts")
	gs._knockout_unit(p.units[0]); check(not Stun.blocks(gs,0,p.units[1]),"independent feast persists while raccoon caster is knocked out")
	var marks:=Status.unit_marks(Status.unit_view(gs,0,1,0),gs.turn_counter)
	check(marks.any(func(m):return m.id=="ignore-stun") and marks.any(func(m):return m.id=="stun-instant"),"live status distinguishes actual stun, ignored restriction and instant")
	p.realms[0].hp=0
	check(Stun.blocks(gs,0,p.units[1]) and not gs.can_basic_attack(0,1).ok and not gs.hand_card_def(0,h).keywords.has("instant"),"destroyed feast immediately restores restrictions and removes dynamic instant")
	check(not Content.card_def("c12404").keywords.has("instant"),"continuous view never mutates global card definition")
	gs=game(); p=gs.player(0); play(gs,"c24808")
	# 化身实际用牌也服从忽略眩晕；默认查询仍保留无上下文的原入口。
	play(gs,"c22104"); p.units[2].frozen=1; p.units[2].incarnationChance=100
	gs.VerifiedRules.Incarnation.queue(gs,0,true); gs._resolve_resolution_stack()
	check(events(gs,"incarnation-card")==1 and p.units[2].frozen==1,"feast allows actually generated incarnation spell while source remains stunned")

func discard_and_ai() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); gs.current_player=1; play(gs,"c24808",null,1)
	p.units[0].frozen=1; p.units[0].awakened=true; p.units[1].frozen=1; p.units[0].front=1
	for id in ["c24801","c24807","c12401","c12404","c22101"]: give(gs,id)
	var first: String=p.hand[0].instanceId; var second: String=p.hand[2].instanceId; var unrelated: String=p.hand[4].instanceId; var deck: int=p.deck.size()
	check(gs.end_turn(1) and gs.pending_choice.get("type")=="raccoon-discard" and gs.action_player()==0,"enemy feast opens real current-player discard at turn start")
	check(gs.pending_choice.instanceIds.size()==2 and gs.pending_choice.instanceIds.has(first) and p.deck.size()==deck and p.units[0].front==1,"only first stunned unit's dedicated hand cards shown, ordinary draw and retreat paused")
	check(not gs.resolve_divination_choice(1,first) and not gs.resolve_divination_choice(0,unrelated),"discard rejects wrong controller and unrelated card")
	check(gs.resolve_divination_choice(0,first) and gs.pending_choice.get("type")=="raccoon-discard" and gs.pending_choice.instanceIds.has(second),"first discard advances to second stunned source independently")
	check(AI._resolve_choice(gs,0) and gs.pending_choice.is_empty() and p.deck.size()==deck-1 and p.units[0].front==0 and p.hand.size()==4,"AI chooses legal second dedicated discard then normal retreat and draw resume once")
	check(events(gs,"raccoon-discarded")==2,"exact two actual discard events")
	gs=game(); p=gs.player(0); gs.current_player=1; play(gs,"c24808",null,1); p.units[0].frozen=1; give(gs,"c22101")
	check(gs.end_turn(1) and gs.pending_choice.is_empty() and p.hand.size()==2,"no matching dedicated card skips discard without inventing unrelated loss")
	gs=game(); p=gs.player(0); play(gs,"c24804"); p.hand.clear(); give(gs,"yaojiu"); p.units[0].hp=1
	var best: Dictionary=AI._best_card(gs,0)
	check(best.ok and best.target==p.units[0].uid and gs.play_card(0,best.hand,best.target) and p.units[0].hp==p.units[0].maxHp,"AI legally chooses awake self wine for full recovery")
	for id in ["c24801","c24802","c24803","c24804","c24805","c24806","c24807","c24808"]: check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"full original art "+id)

func cooperative_hand() -> void:
	var lineup := ["limao","fenghuanghuo","qingxingdeng","yuzaoqian"]
	var gs := game(lineup); var p: Dictionary = gs.player(0)
	play(gs,"c24808")
	var h := give(gs,"c124129")
	var mode := "c124129:qingxingdeng"
	p.units[3].frozen = 1
	check(not gs.card_payment(0,gs.playable_card(0,h,mode)).usesInstant,"a stunned non-owner does not make the non-instant cooperation face free")
	p.units[1].frozen = 1
	p.energy = 0
	check(gs.hand_card_def(0,h).keywords.has("instant") and gs.can_play_card(0,h,null,mode).ok,"a stunned partner grants the shared hand card instant before selecting the other face")
	check(gs.play_card(0,h,null,mode) and p.energy == 0 and gs.kw_usage(0,"instant").used,"real selected cooperation face uses only the single instant allowance")
	h = give(gs,"c124129")
	check(gs.effective_card_cost(0,gs.playable_card(0,h,mode)) == 1,"second use of that instant cooperation face still costs one fire")
	gs = game(lineup); p = gs.player(0)
	gs.current_player = 1
	play(gs,"c24808",null,1)
	p.units[1].frozen = 1
	p.units[2].frozen = 1
	var shared_iid: String = p.hand[give(gs,"c124129")].instanceId
	var lamp_iid: String = p.hand[give(gs,"c12901")].instanceId
	check(gs.end_turn(1) and gs.pending_choice.get("instanceIds",[]) == [shared_iid],"cooperation card is a dedicated hand card of the first stunned partner")
	check(gs.resolve_divination_choice(0,shared_iid) and gs.pending_choice.get("instanceIds",[]) == [lamp_iid],"the next stunned partner cannot discard the already removed shared instance twice")
	check(gs.resolve_divination_choice(0,lamp_iid) and gs.pending_choice.is_empty(),"normal turn start resumes after both actual discard choices")

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["limao","fenghuanghuo","yuzaoqian","baizangzhu"],["limao","yaodaoji","bingyong","baizangzhu"],248); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		hand(b,["c24806"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].maxHp==8 and p.hand.size()==2,"native drunkard creates two actual wine faces")
		gs._grow_unit(foe.units[1],8,30); foe.units[1].front=1; p.units[0].hp=2; b._refresh(); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(p.units[0].uid)).selected and b._unit_widget(str(foe.units[1].uid)).selected,"native wine highlights friendly and enemy real targets")
		if physical.x==1600: await capture("01-wine-real-friendly-enemy-targets")
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(p.units[0].frozen>0 and p.units[0].hp==5 and foe.units[1].hp==28 and p.hand.size()==1,"native self wine causes actual heal and immune attack")
		# Rebuild a clean live board for the independent realm/turn-start choice.
		b.queue_free(); await process_frame; await process_frame
		b=Battle.new(); b.setup(["limao","fenghuanghuo","yuzaoqian","baizangzhu"],["limao","yaodaoji","bingyong","baizangzhu"],249); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.4).timeout; gs=b.gs; p=gs.player(0); foe=gs.player(1)
		hand(b,["c24808"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		Stun.apply(gs,0,1,1,1); hand(b,["c12404"]); await settled(b)
		check(b._hand_row.get_child(0).playable and b._hand_row.get_child(0).data.payment.usesInstant,"native stunned teammate hand enabled with actual instant quote")
		var hp: int=foe.units[2].hp; var energy: int=p.energy
		await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp==hp-5 and p.energy==energy and p.units[1].frozen>0,"native stunned teammate actually casts selected spell using shared instant")
		await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._selected_attacker==1,"native ignored-stun teammate remains selectable for ordinary attack")
		await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(texts(b).contains("忽略眩晕状态效果") and texts(b).contains("专属牌获得瞬发"),"native live inspector describes retained stun and independent aura")
		if physical.x==1280: await capture("02-stunned-teammate-live-inspector")
		escape(); await settled(b)
		gs.current_player=1; play(gs,"c24808",null,1); p.units[0].frozen=1
		hand(b,["c24801","c24807","c124129","c12404","c22101"]); var deck: int=p.deck.size(); var shared_iid: String=p.hand[2].instanceId
		check(gs.end_turn(1),"native actual enemy end reaches discard choice"); b._refresh(); await settled(b)
		check(gs.pending_choice.get("type")=="raccoon-discard" and is_instance_valid(b._choice_layer) and faces(b._choice_layer).size()==2,"native modal exposes exactly first stunned unit's two dedicated cards")
		if physical.x==1600: await capture("03-feast-own-dedicated-discard")
		await click(choice_face(b)); await settled(b)
		check(gs.pending_choice.get("type")=="raccoon-discard" and faces(b._choice_layer).size()==2 and choice_face(b,"c124129")!=null,"native second discard shows the actual shared card")
		if choice_face(b,"c124129")!=null:
			await click(choice_face(b,"c124129")); await settled(b)
		check(not p.hand.any(func(inst):return inst.instanceId==shared_iid),"native choice consumes the exact cooperation instance")
		check(gs.pending_choice.is_empty() and p.deck.size()==deck-1 and p.hand.size()==4,"native second discard resumes ordinary draw exactly once")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args()
	if not args.is_empty() and args[0]!="--rules-only": out=args[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	passives(); cards_and_targets(); flame_and_realm(); discard_and_ai(); cooperative_hand()
	if not args.has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("RACCOON checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
