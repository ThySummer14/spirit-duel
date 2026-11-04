extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const RulesFox := preload("res://scripts/fox_lotus_rules.gd")
const Inc := preload("res://scripts/incarnation_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FOX_LOTUS_FAIL ",detail)

func game(last_unit: String = "taohuayao") -> GS:
	var gs := GS.create(["yuzaoqian","dishitian","fenghuanghuo",last_unit],["yaodaoji","bingyong","yuzaoqian","baizangzhu"],221225)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units:
			u.level=3; u.incarnationUsedTurn=gs.turn_counter; u.incarnationCount=2
	return gs

func inst(gs, id: String) -> Dictionary:
	var i := {"definitionId":id,"instanceId":"fox-lotus-%d" % gs.next_card_id}; gs.next_card_id+=1; return i

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(inst(gs,id)); return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func auto(gs, id: String, target = null, owner: int = 0) -> void:
	var c := Content.card_def(id).duplicate(true)
	gs._push_card_frames(owner,id,target,c,gs._source_index(owner,c),0,true); gs._resolve_resolution_stack()

func total_hp(gs, owner: int) -> int:
	var n:=int(gs.player(owner).avatarHp)
	for u in gs.player(owner).units: n+=int(u.hp)
	return n

func grow_foe(gs) -> void:
	for u in gs.player(1).units: gs._grow_unit(u,0,30)

func count_event(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()

func fox_spells() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); grow_foe(gs)
	check(p.units[0].attack==3 and p.units[0].maxHp==4 and p.units[1].attack==2 and p.units[1].maxHp==5,"exact3/4 fox and2/5 lotus baselines")
	var hp: int=foe.units[1].hp; play(gs,"c22101",foe.units[1].uid)
	check(foe.units[1].hp==hp-2 and p.units[0].foxSpellBonus==1 and foe.avatarHp==30,"first hand strike deals base2 then permanent spell+1 without outside-hand projectile")
	hp=foe.units[1].hp; play(gs,"c22101",foe.units[1].uid)
	check(foe.units[1].hp==hp-3 and p.units[0].foxSpellBonus==2,"next hand strike actually uses prior bonus then increments")
	hp=foe.units[1].hp; var hand_size: int=p.hand.size(); var energy: int=p.energy; auto(gs,"c22101",foe.units[1].uid)
	check(foe.units[1].hp==hp-4 and p.units[0].foxSpellBonus==2 and foe.avatarHp==28,"generated strike uses permanent spell bonus but only base2 independent ability projectile")
	check(p.hand.size()==hand_size and p.energy==energy,"outside-hand casting consumes neither hand nor fire")
	hp=foe.avatarHp; play(gs,"c22102")
	check(foe.avatarHp==hp-5 and p.units[0].foxSpellBonus==3,"hand foxfire real projection uses base3+2")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[1].front=1; hp=foe.units[1].hp
	play(gs,"c22102"); check(foe.units[1].hp==hp-3 and foe.avatarHp==30,"foxfire hits actual front rather than arbitrary face")
	gs=game(); p=gs.player(0); grow_foe(gs); var before:=total_hp(gs,1); play(gs,"c22103")
	check(total_hp(gs,1)==before-4 and p.units[0].foxSpellBonus==1,"falling sky distributes four individual points, not four multiplied packets")
	p.units[0].foxSpellBonus=3; before=total_hp(gs,1); play(gs,"c22103")
	check(total_hp(gs,1)==before-7 and p.units[0].foxSpellBonus==4,"distribution adds spell bonus to total once")
	gs._knockout_unit(p.units[0]); gs._resolve_resolution_stack()
	check(p.units[0].foxSpellBonus==4 and gs.VerifiedRules.Peach.revive(gs,0,3,p.units[0],false,false),"permanent spell bonus survives actual knockout and resurrection")
	check(gs.hand_card_def(0,give(gs,"c22101")).currentCardStats=="当前伤害6","live card shows real damage after revival")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c22104"); check(p.units[0].attack==3 and p.units[0].maxHp==4,"prayer form exact3/4")
	play(gs,"c22108"); check(p.units[0].attack==3 and p.units[0].maxHp==7,"nine tails exact3/7")
	gs=game(); p=gs.player(0); grow_foe(gs); play(gs,"c22106")
	check(p.units[0].front==0 and count_event(gs,"fox-generated-spell")==1 and int(p.units[0].get("foxSpellBonus",0))==0,"burning snow actual remote battle plus generated first-level spell without hand-only enhancement")
	gs=game(); p=gs.player(0); grow_foe(gs); play(gs,"c22107")
	check(p.units[0].attack==4 and p.units[0].maxHp==5 and p.units[0].awakened,"fox awakening exact1/1")
	var hp_before: int=gs.player(1).avatarHp; auto(gs,"c22101",gs.player(1).units[1].uid)
	check(gs.player(1).avatarHp==hp_before-3,"awakened outside-hand projectile genuinely3")
	check(gs.end_turn(0) and count_event(gs,"fox-generated-spell")==1,"awakened own end generates and uses one actual spell")
	gs=game(); p=gs.player(0); grow_foe(gs); play(gs,"c22107"); p.units[0].frozen=1
	check(gs.end_turn(0) and p.units[0].frozen==0 and count_event(gs,"fox-generated-spell")==1 and gs.current_player==1,"ordinary end-turn stun expires before awakened automatic spell and turn transition")
	gs=game(); p=gs.player(0); grow_foe(gs); play(gs,"c22107"); p.units[0].frozen=2
	check(gs.end_turn(0) and p.units[0].frozen==1 and count_event(gs,"fox-generated-spell")==0,"remaining stun still prevents end-turn automatic spell")
	gs=game(); p=gs.player(0); grow_foe(gs); play(gs,"c22105"); check(p.realms.size()==1 and p.realms[0].hp==5,"dream real5durability realm")
	gs.VerifiedRules.Panguan.destroy(gs,0,2,1,0); gs._resolve_resolution_stack()
	check(count_event(gs,"fox-generated-spell")==1,"dream triggers actual spell when enemy shikigami dies")
	gs.VerifiedRules.Panguan.destroy(gs,0,2,1,1); gs._resolve_resolution_stack(); check(count_event(gs,"fox-generated-spell")==1,"dream once in same player turn")
	check(gs.end_turn(0),"actual enemy turn starts for dream reset")
	gs.VerifiedRules.Panguan.destroy(gs,0,2,1,2); gs._resolve_resolution_stack(); check(count_event(gs,"fox-generated-spell")==2,"dream also triggers once on opponent player turn")

func lotus_cards() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var deck: int=p.deck.size()
	play(gs,"c22501",foe.units[0].uid)
	check(RulesFox.marked(foe.units[0],0) and foe.units[0].attack==2 and p.deck.size()==deck-1 and p.energy==40,"grace unique actual mark-1, hand draw and shared instant")
	deck=p.deck.size(); auto(gs,"c22501",foe.units[1].uid)
	check(not RulesFox.marked(foe.units[0]) and foe.units[0].attack==3 and RulesFox.marked(foe.units[1],0) and p.deck.size()==deck,"new owned lotus replaces previous, generated grace never draws")
	play(gs,"c22503",foe.units[0].uid); check(foe.units[0].attack==1 and p.lotusDebuff==1,"boon permanently strengthens lotus penalty to2")
	play(gs,"c22503",foe.units[1].uid); check(foe.units[0].attack==3 and foe.units[1].attack==0 and p.lotusDebuff==2,"global boon enhancement follows transferred mark and never stacks duplicate charms")
	auto(gs,"c22501",foe.units[2].uid); check(foe.units[2].attack==0,"future marks inherit prior permanent lotus enhancement")
	gs=game(); p=gs.player(0); foe=gs.player(1); var hp: int=foe.units[1].hp; play(gs,"c22504",foe.units[1].uid)
	check(foe.units[1].hp==hp-4,"unmarked judgement is exactly4damage")
	gs=game(); foe=gs.player(1); gs._grow_unit(foe.units[1],0,100); RulesFox.attach(gs,0,1,foe.units[1]); play(gs,"c22504",foe.units[1].uid)
	check(foe.units[1].hp==0 and not RulesFox.marked(foe.units[1]),"marked judgement truly destroys high-health target and death clears lotus")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c22505",foe.units[0].uid)
	check(p.units[1].attack==4 and p.units[1].maxHp==7 and p.units[1].awakened and RulesFox.marked(foe.units[0],0),"lotus awakening exact2/2 plus actual selected charm")
	gs=game(); p=gs.player(0); foe=gs.player(1); RulesFox.attach(gs,0,1,foe.units[1]); play(gs,"c22502")
	check(p.units[1].attack==3 and p.units[1].maxHp==6,"holy king form3/6")
	hp=foe.units[1].hp; check(gs.end_turn(0) and foe.units[1].hp==hp-2,"holy king own-end deals2 to actual current lotus target")
	gs=game(); p=gs.player(0); foe=gs.player(1); grow_foe(gs); play(gs,"c22507"); RulesFox.attach(gs,0,1,foe.units[1]); deck=p.deck.size(); var energy: int=p.energy
	play(gs,"c22101",foe.units[1].uid)
	check(p.energy==energy and p.deck.size()==deck-1 and p.units[1].attack==5 and p.units[1].maxHp==7,"mercy5/7 rewards exact1fire and1draw after teammate targeted spell")
	energy=p.energy; deck=p.deck.size(); play(gs,"c22101",foe.units[1].uid)
	check(p.energy==energy-1 and p.deck.size()==deck,"mercy shared once per player turn")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c22507"); energy=p.energy; deck=p.deck.size(); play(gs,"c22501",foe.units[1].uid)
	check(p.energy==energy and p.deck.size()==deck-1,"first grace on unmarked target does not retroactively trigger mercy")
	gs=game(); foe=gs.player(1); RulesFox.attach(gs,0,1,foe.units[3]); var power: int=foe.units[3].attack
	gs.VerifiedRules.PipeFox.cleanse(gs,1,3)
	check(not RulesFox.marked(foe.units[3]) and foe.units[3].attack==power+1,"white fox cleanse removes actual hostile lotus and restores power")

func saint_and_ideal() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); grow_foe(gs)
	RulesFox.attach(gs,0,1,foe.units[3]); play(gs,"c22508"); check(p.units[1].attack==4 and p.units[1].maxHp==6,"saint exact4/6")
	var hp: int=foe.units[1].hp; var marked_hp: int=foe.units[3].hp
	play(gs,"c12404",foe.units[1].uid)
	check(foe.units[1].hp==hp-5 and foe.units[3].hp==marked_hp-5 and count_event(gs,"lotus-spell-copy")==1,"saint copies teammate's actual spell to lotus exactly once")
	var copied: Array=gs.rule_events.filter(func(e):return e.kind=="lotus-spell-copy")
	check(copied[0].casterUid==p.units[2].uid and foe.avatarHp==28,"copy retains real Phoenix caster, triggers its own use ability, no recursive saint")
	hp=foe.units[1].hp; marked_hp=foe.units[3].hp; play(gs,"c12404",foe.units[1].uid)
	check(foe.units[1].hp==hp-5 and foe.units[3].hp==marked_hp and count_event(gs,"lotus-spell-copy")==1,"second spell same turn is not copied")
	play(gs,"c22508"); play(gs,"c12404",foe.units[1].uid)
	check(count_event(gs,"lotus-spell-copy")==1,"reinstalling saint cannot refresh once-per-turn copy")
	for u in foe.units: u.incarnationUsedTurn=gs.turn_counter+1; u.incarnationCount=2
	check(gs.end_turn(0),"saint reset advances actual opponent turn")
	p.units[1].incarnationUsedTurn=gs.turn_counter+1; p.units[1].incarnationCount=2
	check(gs.end_turn(1),"saint reset advances actual new own turn")
	hp=foe.units[3].hp; play(gs,"c12404",foe.units[1].uid)
	check(count_event(gs,"lotus-spell-copy")==2 and foe.units[3].hp==hp-5,"new player turn restores one real copy")
	gs=game(); p=gs.player(0); foe=gs.player(1); grow_foe(gs); RulesFox.attach(gs,0,1,foe.units[3]); play(gs,"c22508"); hp=foe.units[1].hp
	play(gs,"c12402"); check(foe.units[1].hp==hp-2 and count_event(gs,"lotus-spell-copy")==1,"saint copies real area spell as area spell, not a fabricated single damage packet")
	gs=game(); p=gs.player(0); foe=gs.player(1); RulesFox.attach(gs,0,1,foe.units[3]); play(gs,"c22508"); play(gs,"c22505",foe.units[0].uid)
	check(count_event(gs,"lotus-spell-copy")==0,"saint does not copy awakening spells")
	gs=game(); p=gs.player(0); foe=gs.player(1); grow_foe(gs); RulesFox.attach(gs,0,1,foe.units[3]); play(gs,"c22508")
	var card:=Content.card_def("c12404").duplicate(true); card.crabReturn=true; card.keywords.append("bounce")
	gs._push_card_frames(0,"c12404",foe.units[1].uid,card,2,0,false); gs._resolve_resolution_stack()
	copied=gs.rule_events.filter(func(e):return e.kind=="lotus-spell-copy")
	check(copied.size()==1 and not copied[0].card.crabReturn and not copied[0].card.keywords.has("bounce"),"official copy rule removes bounce from generated copy")
	gs=game(); p=gs.player(0); foe=gs.player(1); RulesFox.attach(gs,0,1,foe.units[0]); play(gs,"c22506")
	check(p.realms[0].hp==5,"ideal has real5durability")
	p.units[3].shield=3; hp=p.units[3].hp; var avatar: int=p.avatarHp
	check(gs._damage_unit(0,3,8,1,0).damage==0 and p.units[3].hp==hp and p.units[3].shield==3,"ideal blocks unit damage before consuming target armor")
	check(gs._damage_avatar(0,8,1,0)==0 and p.avatarHp==avatar,"ideal blocks marked source avatar damage")
	hp=foe.units[1].hp; gs._damage_unit(1,1,4,1,0); check(foe.units[1].hp==hp,"ideal blocks friendly source damage as well")
	hp=p.units[2].hp; gs._damage_unit(0,2,1,1,1); check(p.units[2].hp==hp-1,"unmarked other sources still deal actual damage")
	gs.current_player=1; p.units[3].shield=0; hp=p.units[3].hp; play(gs,"c22101",p.units[3].uid,1)
	check(p.units[3].hp==hp-2,"unmarked fox spell still works")
	RulesFox.attach(gs,0,1,foe.units[2]); hp=p.units[3].hp; play(gs,"c22101",p.units[3].uid,1)
	check(p.units[3].hp==hp and foe.units[2].foxSpellBonus==2,"marked spell source loses damage but keeps non-damage enhancement")
	RulesFox.attach(gs,0,1,foe.units[0]); hp=p.units[2].hp; foe.units[0].front=1; p.units[2].front=1; gs._resolve_combat(1,0,10,false,false,false,false); gs._resolve_resolution_stack()
	check(p.units[2].hp==hp,"marked source combat strike genuinely cannot deal damage")
	gs._damage_unit(0,1,100,1,1); gs._resolve_resolution_stack(); hp=p.avatarHp
	check(gs._damage_avatar(0,3,1,0)==0 and p.avatarHp==hp,"ideal persists as actual realm when its caster is knocked out")
	p.realms[0].hp=0; check(gs._damage_avatar(0,2,1,0)==2,"breaking actual ideal immediately restores damage")
	gs=game(); p=gs.player(0); foe=gs.player(1); RulesFox.attach(gs,0,1,foe.units[0]); play(gs,"c22506"); hp=p.avatarHp
	gs._apply_realm_trigger(1,0,{"sourceUnit":foe.units[0].id,"name":"source attribution","triggerEffect":"damage-enemy-front","triggerValue":5})
	check(p.avatarHp==hp,"realm ability damage retains source shikigami and obeys ideal")
	check(gs.VerifiedRules.Panguan.destroy(gs,1,0,0,3) and p.units[3].hp==0,"ideal does not suppress non-damage destruction")

func incarnation_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var fox: Dictionary=p.units[0]; var lotus: Dictionary=p.units[1]; grow_foe(gs)
	check(Inc.config(lotus).start==25 and Inc.config(lotus).action==25 and Inc.pool(gs,0,1).size()==1 and Inc.pool(gs,0,1)[0].lotusGrace,"base lotus official25/25 and grace-only pool")
	play(gs,"c22505",gs.player(1).units[0].uid)
	check(Inc.config(lotus).start==20 and Inc.config(lotus).action==8 and Inc.pool(gs,0,1).size()==3,"awake lotus official20/8 and three non-awakening spells")
	play(gs,"c22104"); check(Inc.config(fox).start==20 and Inc.config(fox).action==8 and Inc.config(fox).limit==1 and Inc.pool(gs,0,0).size()==3,"prayer official20/8 once and first-level spells only")
	play(gs,"c22108"); check(Inc.config(fox).start==50 and Inc.config(fox).action==32 and Inc.config(fox).limit==2,"nine tails official50/32 twice")
	fox.erase("incarnationUsedTurn"); fox.incarnationChance=100; var hand_size: int=p.hand.size(); var energy: int=p.energy; var deck: int=p.deck.size()
	Inc.queue(gs,0,false); gs._resolve_resolution_stack(); check(count_event(gs,"incarnation-card")==1 and fox.incarnationCount==1,"actual generated first incarnation")
	fox.incarnationChance=100; Inc.queue(gs,0,false); gs._resolve_resolution_stack(); check(count_event(gs,"incarnation-card")==2 and fox.incarnationCount==2,"nine tails permits actual second incarnation in same turn")
	fox.incarnationChance=100; Inc.queue(gs,0,false); gs._resolve_resolution_stack(); check(count_event(gs,"incarnation-card")==2,"nine tails third check cannot exceed limit")
	check(p.hand.size()==hand_size and p.deck.size()==deck and p.energy==energy and int(fox.get("foxSpellBonus",0))==0,"generated cast never consumes hand deck fire or creates hand-only enhancement")
	fox.frozen=1; check(Inc.config(fox).is_empty(),"stunned source has no active incarnation")
	fox.frozen=0; gs._knockout_unit(fox); gs._resolve_resolution_stack(); check(Inc.config(fox).is_empty(),"dead fox cannot incarnate")
	gs=game(); p=gs.player(0); lotus=p.units[1]
	for u in gs.player(1).units: u.keywords=["veil"]
	lotus.erase("incarnationUsedTurn"); lotus.incarnationChance=100; var before:=count_event(gs,"incarnation-card")
	Inc.queue(gs,0,true); gs._resolve_resolution_stack(); check(count_event(gs,"incarnation-card")==before and lotus.incarnationChance==100,"no legal targets means no generated spell or progress consumption")
	gs.player(1).units[2].keywords=[]; Inc.queue(gs,0,true); gs._resolve_resolution_stack()
	check(count_event(gs,"incarnation-card")==before+1 and RulesFox.marked(gs.player(1).units[2],0),"when one legal target appears full-progress lotus actually casts on it")

func ai_and_status() -> void:
	var gs:=game(); var foe: Dictionary=gs.player(1); RulesFox.attach(gs,0,1,foe.units[1]); gs._grow_unit(foe.units[1],0,100); give(gs,"c22504")
	var best: Dictionary=AI._best_card(gs,0)
	check(best.ok and best.target==foe.units[1].uid and gs.play_card(0,best.hand,best.target) and foe.units[1].hp==0,"AI prefers legal real destruction of high-health lotus target")
	gs=game(); foe=gs.player(1); foe.units[2].keywords=["veil"]; var h:=give(gs,"c22501")
	check(not gs.valid_targets(0,gs.hand_card_def(0,h)).has(foe.units[2].uid) and not gs.can_play_card(0,h,foe.units[2].uid).ok,"UI and commands both reject veil target")
	best=AI._best_card(gs,0); check(best.ok and gs.can_play_card(0,best.hand,best.target).ok,"AI shares legal lotus targets")
	RulesFox.attach(gs,0,1,foe.units[0]); play(gs,"c22506")
	var marks:=Status.unit_marks(Status.unit_view(gs,1,0,0),gs.turn_counter)
	check(marks.any(func(m):return m.id=="lotus-charm") and marks.any(func(m):return "不能造成伤害" in m.label),"live inspector exposes actual charm and ideal damage block")
	for id in ["c22101","c22102","c22103","c22104","c22105","c22106","c22107","c22108","c22501","c22502","c22503","c22504","c22505","c22506","c22507","c22508"]:
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"full original card art "+id)

func choice_rules() -> void:
	var gs:=game("baimugui"); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); grow_foe(gs)
	RulesFox.attach(gs,0,1,foe.units[0]); play(gs,"c22508")
	var a:=inst(gs,"c22101"); a.eyeCurses=1; var b:=inst(gs,"c22101"); b.eyeCurses=1; p.deck=[a,b]
	var hp: int=foe.units[1].hp; var marked_hp: int=foe.units[0].hp
	play(gs,"c19606",foe.units[1].uid)
	check(gs.pending_choice.get("type")=="eye-curse" and foe.units[1].hp==hp and count_event(gs,"lotus-spell-copy")==0,"original targeted draw spell pauses before damage and before saint copy")
	check(gs.resolve_divination_choice(0,"eye-curse-hand"),"first real curse selection")
	check(gs.pending_choice.get("type")=="eye-curse" and foe.units[1].hp==hp-2 and foe.units[0].hp==marked_hp and count_event(gs,"lotus-spell-copy")==1,"copy separately draws then pauses for its own choice without early damage")
	check(gs.resolve_divination_choice(0,"eye-curse-life"),"second real copied-spell curse selection")
	check(gs.pending_choice.is_empty() and foe.units[0].hp==marked_hp-2 and count_event(gs,"lotus-spell-copy")==1,"second choice completes copied effect exactly once")

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var battle:=Battle.new(); battle.setup(["yuzaoqian","dishitian","fenghuanghuo","baimugui"],["yaodaoji","bingyong","yuzaoqian","baizangzhu"],221225); battle._ai_thinking=true
		for side in battle.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3; u.incarnationUsedTurn=battle.gs.turn_counter; u.incarnationCount=2
		root.add_child(battle); await create_timer(0.4).timeout
		var gs=battle.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); grow_foe(gs)
		hand(battle,["c22501"]); await settled(battle); await click(battle._hand_row.get_child(0)); await settled(battle)
		check(battle._pending_target_card==0 and battle._unit_widget(str(foe.units[0].uid)).selected,"native grace exposes actual enemy targets")
		await click(battle._unit_widget(str(foe.units[0].uid))); await settled(battle)
		check(RulesFox.marked(foe.units[0],0) and p.energy==40,"native actual grace attaches lotus with real instant payment")
		hand(battle,["c22508"]); await settled(battle); await click(battle._hand_row.get_child(0)); await settled(battle)
		check(p.units[1].attack==4 and p.units[1].maxHp==6,"native saint actual4/6 form")
		var a:=inst(gs,"c22101"); a.eyeCurses=1; var b:=inst(gs,"c22101"); b.eyeCurses=1; p.deck=[a,b]
		hand(battle,["c19606"]); await settled(battle); var hp: int=foe.units[1].hp; var marked_hp: int=foe.units[0].hp
		await click(battle._hand_row.get_child(0)); await settled(battle)
		check(battle._pending_target_card==0 and battle._unit_widget(str(foe.units[1].uid)).selected,"native teammate spell exposes real target before copy")
		if physical.x==1600: await capture("01-saint-teammate-original-target")
		await click(battle._unit_widget(str(foe.units[1].uid))); await settled(battle)
		check(gs.pending_choice.get("type")=="eye-curse" and choice_face(battle,"eye-curse-hand")!=null,"native original spell opens first actual draw-choice")
		await click(choice_face(battle,"eye-curse-hand")); await settled(battle)
		check(gs.pending_choice.get("type")=="eye-curse" and foe.units[1].hp==hp-2 and foe.units[0].hp==marked_hp,"native first choice completes original and opens separate copied-spell choice")
		if physical.x==1280: await capture("02-saint-copy-pauses-for-second-choice")
		await click(choice_face(battle,"eye-curse-life")); await settled(battle)
		check(gs.pending_choice.is_empty() and foe.units[0].hp==marked_hp-2 and count_event(gs,"lotus-spell-copy")==1,"native second choice completes real copy with no recursive duplicate")
		hand(battle,["c22506"]); await settled(battle); await click(battle._hand_row.get_child(0)); await settled(battle)
		check(p.realms.size()==1 and p.realms[0].hp==5,"native ideal5durability installed")
		await click(battle._unit_widget(str(foe.units[0].uid))); await settled(battle)
		check(texts(battle).contains("莲华") and texts(battle).contains("不能造成伤害"),"native inspector exposes actual lotus and ideal restriction")
		if physical.x==1600: await capture("03-ideal-lotus-live-inspector")
		escape(); await settled(battle)
		hand(battle,["c22101"]); await settled(battle); await click(battle._hand_row.get_child(0)); await settled(battle); await click(battle._unit_widget(str(foe.units[3].uid))); await settled(battle)
		hand(battle,["c22101"]); await settled(battle)
		check(battle._hand_row.get_child(0).original_stat_changes()=="当前伤害3","native full original artwork exposes current actual permanent spell bonus")
		if physical.x==1280: await capture("04-fox-current-damage-and-original-art")
		battle.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out=OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	fox_spells(); lotus_cards(); saint_and_ideal(); incarnation_rules(); ai_and_status(); choice_rules(); await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("FOX_LOTUS checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
