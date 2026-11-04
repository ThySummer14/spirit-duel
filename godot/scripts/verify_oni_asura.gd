extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Oni := preload("res://scripts/oni_asura_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("ONI_ASURA_FAIL ",detail)

func game() -> GS:
	var gs := GS.create(["gitongwan","axiuluo","yaodaoji","baizangzhu"],["gitongwan","axiuluo","bingyong","yaodaoji"],214224)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.oniFirstDrawTurn=-1
		for u in p.units: u.level=3
	return gs

func inst(gs, id: String) -> Dictionary:
	var entry := {"definitionId":id,"instanceId":"oni-asura-%d" % gs.next_card_id}; gs.next_card_id+=1; return entry

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(inst(gs,id)); return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)

func choices(gs) -> void:
	var attempts := 0
	while not gs.pending_choice.is_empty() and attempts<30:
		check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"AI handles real choice"); attempts+=1
	check(gs.pending_choice.is_empty(),"choice continuation completes")

func turn(gs, owner: int) -> void:
	check(gs.end_turn(owner),"actual turn end %d" % owner); gs.player(1-owner).levelUpUsed=true

func draw(gs, id: String, owner: int = 0) -> Dictionary:
	var entry := inst(gs,id); gs.player(owner).deck.append(entry); gs._draw(owner,1); gs._resolve_resolution_stack(); return entry

func ghost_draw_and_forms() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	check(p.units[0].attack==2 and p.units[0].maxHp==6,"oni exact base2/6")
	var top := inst(gs,"c22401"); p.deck.append(top); Oni.turn_start(gs,0)
	check(p.deck.front().instanceId==top.instanceId,"base moves actual non-oni top card to bottom without shuffle")
	top=inst(gs,"c21402"); p.deck.append(top); Oni.turn_start(gs,0); check(p.deck.back().instanceId==top.instanceId,"base preserves own top card")
	play(gs,"c21404"); check(p.units[0].attack==3 and p.units[0].maxHp==6,"oni awaken exact1/0")
	Oni.turn_start(gs,0); check(p.units[0].attack==4 and p.units[0].maxHp==7,"awake own top yields real permanent1/1")
	gs._knockout_unit(p.units[0]); gs.VerifiedRules.reduce_countdown(gs,0,0,int(p.units[0].knockout))
	check(p.units[0].attack==4 and p.units[0].maxHp==7,"awake top growth survives knockout and revival")
	gs=game(); p=gs.player(0); foe=gs.player(1); var before: int=foe.avatarHp; play(gs,"c21401")
	check(p.units[0].attack==3 and p.units[0].maxHp==6 and foe.avatarHp==before,"impulse form3/6 does not attack without qualifying first draw")
	draw(gs,"c21402"); check(foe.avatarHp==before-3 and not p.attackUsed,"first own card really triggers free automatic attack without consuming ordinary action")
	draw(gs,"c21402"); check(foe.avatarHp==before-3,"later own card cannot retrigger same impulse installation")
	turn(gs,0); before=foe.avatarHp; draw(gs,"c21402")
	check(foe.avatarHp==before-3,"same impulse installation triggers from qualifying first draw on opponent turn")
	draw(gs,"c21402"); check(foe.avatarHp==before-3,"later draws in opponent turn cannot repeat impulse")
	p.deck.append(inst(gs,"c21402")); before=foe.avatarHp; turn(gs,1)
	check(foe.avatarHp==before-3 and not p.attackUsed,"same impulse installation triggers again on next own turn first draw")
	draw(gs,"c21402"); check(foe.avatarHp==before-3,"next own turn later draws cannot repeat impulse")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c21401"); draw(gs,"c22401"); before=foe.avatarHp; draw(gs,"c21402")
	check(foe.avatarHp==before,"first non-oni draw cannot be replaced by later oni draw")
	gs=game(); p=gs.player(0); foe=gs.player(1); draw(gs,"c21401"); before=foe.avatarHp; play(gs,"c21401")
	check(foe.avatarHp==before-3,"installing impulse after own first draw triggers immediately")
	gs=game(); p=gs.player(0); foe=gs.player(1); var entry := draw(gs,"c21402"); var h: int=p.hand.find(entry)
	check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==0,"draw-turn falling strike gets actual instant")
	check(gs.play_card(0,h) and p.energy==40,"enhanced falling strike spends shared instant and no fire")
	gs=game(); p=gs.player(0); foe=gs.player(1); var old := give(gs,"c21402")
	check(gs.effective_card_cost(0,gs.hand_card_def(0,old))==1,"ordinary starting/generated card is not draw-enhanced")
	entry=draw(gs,"c21405"); h=p.hand.find(entry); check(gs.play_card(0,h) and p.units[0].attack==6 and p.units[0].maxHp==6 and p.units[0].unyielding,"draw-turn6/6form grants real unyielding")
	gs._damage_unit(0,0,100,1,2); check(p.units[0].hp==1 and not p.units[0].unyielding,"enhanced unyielding saves once")
	gs=game(); p=gs.player(0); play(gs,"c21405"); check(not p.units[0].unyielding,"non-draw form has no invented unyielding")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[2],0,30); entry=draw(gs,"c21406"); h=p.hand.find(entry)
	check(gs.hand_card_def(0,h).combatOption.lethal and gs.play_card(0,h,foe.units[2].uid) and foe.units[2].hp==0,"draw-turn pursuit gets actual lethal against high HP reserve")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[2],0,30); play(gs,"c21406",foe.units[2].uid)
	check(foe.units[2].hp>0,"unearned pursuit does not gain lethal")

func guide_and_chain() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	var h := give(gs,"c21403"); var iid: String=p.hand[h].instanceId; p.hand[h].retainedMarker=7
	check(gs.play_card(0,h) and p.units[0].attack==3 and p.units[0].maxHp==6,"guide initial exact3/6")
	play(gs,"c21405"); var returned: Array=p.deck.filter(func(i):return str(i.instanceId)==iid)
	check(returned.size()==1 and returned[0].retainedMarker==7 and p.oniGuideGrowth==1,"departing guide shuffles original identity and metadata, grows all own same-name cards once")
	h=give(gs,"c21403"); var card: Dictionary=gs.hand_card_def(0,h)
	check(card.value.attack==5 and card.value.hp==7 and gs.play_card(0,h) and p.units[0].attack==5 and p.units[0].maxHp==7,"next guide really installs enhanced5/7")
	gs._knockout_unit(p.units[0]); check(p.oniGuideGrowth==2 and p.deck.any(func(i):return i.definitionId=="c21403"),"guide also returns and grows on source knockout")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.deck=[inst(gs,"c22401"),inst(gs,"c21402"),inst(gs,"c21402")]
	play(gs,"c21407")
	check(foe.avatarHp==21 and p.hand.size()==3 and p.deck.is_empty() and not p.attackUsed,"chain actual first5damage then two plain2damage attacks, three actual draws and no action spending")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[2].front=1; gs._grow_unit(foe.units[2],0,30); var deck: int=p.deck.size()
	play(gs,"c21407"); check(p.deck.size()==deck,"chain does not draw from unit-only damage")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.avatarArmor=20; deck=p.deck.size(); play(gs,"c21407")
	check(p.deck.size()==deck,"fully armored avatar damage does not trigger chain draw")

func install_rebirth(gs, ids: Array) -> void:
	gs.player(0).deck.clear()
	for id in ids: gs.player(0).deck.append(inst(gs,str(id)))
	play(gs,"c21408"); check(gs.pending_choice.get("type")=="native-divination" and gs.pending_choice.count==mini(3,ids.size()),"rebirth card use starts real divination3")
	choices(gs); check(gs.player(0).units[0].get("formRules",{}).get("oniRebirth",false) and gs.player(0).units[0].hp==7,"rebirth form7/7 installed after completed divination")

func rebirth_rules() -> void:
	var gs := game(); var p: Dictionary=gs.player(0)
	install_rebirth(gs,["c21402","c21402","c21402"]); var deck: int=p.deck.size(); gs._damage_unit(0,0,100,1,2); gs._resolve_resolution_stack()
	check(p.units[0].hp==7 and p.units[0].form.cardId=="c21408" and p.deck.size()==deck-1 and gs.pending_choice.is_empty(),"knockout draws1 revives and reinstalls form from own card without another divination")
	gs=game(); p=gs.player(0); install_rebirth(gs,["c22401","c22401","c22401"]); gs._damage_unit(0,0,100,1,2); gs._resolve_resolution_stack()
	check(p.units[0].hp==6 and p.units[0].form.is_empty(),"non-oni draw still revives base body without reattaching form")
	gs=game(); p=gs.player(0); var foe: Dictionary=gs.player(1); install_rebirth(gs,["c21402","c21402","c21402"]); gs._grow_unit(foe.units[3],10,100); p.units[0].front=1; deck=p.deck.size()
	gs._resolve_combat(1,3,0,false,false,true,true); gs._resolve_resolution_stack()
	check(p.units[0].hp==7 and p.deck.size()==deck-2,"rebirth resolves between enemy combo exchanges, not after entire attack")
	gs=game(); p=gs.player(0); foe=gs.player(1); install_rebirth(gs,["c21402","c21402","c21402"]); gs._grow_unit(foe.units[3],10,100); p.units[0].front=1
	p.deck.back().eyeCurses=1; deck=p.deck.size(); gs._resolve_combat(1,3,0,false,false,true,true); gs._resolve_resolution_stack()
	check(gs.pending_choice.get("type")=="eye-curse" and p.units[0].hp==0 and gs.resolution_stack.any(func(f):return f.kind=="oni-combat-resume"),"rebirth draw charm pauses combat with serialized next exchange")
	check(gs.resolve_divination_choice(0,"eye-curse-hand"),"actual draw charm choice resumes")
	check(p.units[0].hp==7 and p.deck.size()==deck-2 and gs.pending_choice.is_empty(),"after choice remaining combo exchange and second rebirth complete exactly once")

func asura_growth_and_realms() -> void:
	var gs := game(); var p: Dictionary=gs.player(0)
	check(p.units[1].attack==2 and p.units[1].maxHp==5,"asura exact2/5")
	gs._damage_avatar(0,3,0,0); gs._resolve_resolution_stack()
	check(p.units[1].attack==3 and p.asuraSelfDamageTurn==gs.turn_counter,"any actual friendly avatar damage gives base1power and marks turn")
	gs._damage_avatar(0,1,1,2); check(p.units[1].attack==3,"enemy avatar damage never grants self-damage growth")
	p.avatarArmor=5; gs._damage_avatar(0,2,0,0); check(p.units[1].attack==3,"fully blocked friendly damage does not grow")
	play(gs,"c22407"); check(p.units[1].attack==5 and p.units[1].maxHp==7,"asura awakening exact2/2")
	p.avatarArmor=0; gs._damage_avatar(0,3,0,0); check(p.units[1].attack==8,"awakened growth equals actual3damage")
	gs._knockout_unit(p.units[1]); check(p.units[1].attack==4,"ordinary self-damage power clears on knockout, awakening retained")
	gs=game(); p=gs.player(0); play(gs,"c22401"); check(p.units[1].attack==2 and p.units[1].maxHp==7,"dark child exact2/7")
	var hp: int=p.avatarHp; check(gs.basic_attack(0,1) and p.avatarHp==hp-1 and p.units[1].attack==3 and gs.player(1).avatarHp==27,"before-attack self1 grows before reading attack power")
	gs=game(); p=gs.player(0); play(gs,"c22404"); check(p.avatarHp==25 and p.units[1].attack==7 and p.units[1].maxHp==7,"demon6/7 entry self5 produces one base growth")
	gs=game(); p=gs.player(0); var h := give(gs,"c22403"); check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==1,"blood combat not instant before friendly damage")
	gs._damage_avatar(0,1,0,0); check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==0 and gs.play_card(0,h) and p.energy==40,"blood combat gains actual shared instant this turn")
	gs=game(); p=gs.player(0); play(gs,"c22406"); check(p.energy==40 and p.realms[0].hp==7,"healing realm real instant and7durability")
	hp=p.avatarHp; gs._damage_avatar(0,2,0,1); gs._resolve_resolution_stack()
	check(p.avatarHp==hp and p.realms[0].hp==5 and p.units[1].attack==3,"friendly avatar damage remains real event then heals equal2, still consumes realm durability and grants growth")
	p.units[2].hp=3; gs._damage_unit(0,2,1,0,1); gs._resolve_resolution_stack(); check(p.units[2].hp==3,"realm restores actual friendly unit self damage")
	gs._damage_unit(0,2,1,1,2); gs._resolve_resolution_stack(); check(p.units[2].hp==2,"realm does not heal enemy source damage")
	gs._damage_unit(0,2,20,0,1); gs._resolve_resolution_stack(); check(p.units[2].hp==0,"realm cannot resurrect a lethally damaged unit")

func asura_combat() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	gs._grow_unit(foe.units[2],5,30); foe.units[2].front=1; var hp: int=p.units[1].hp; var avatar: int=p.avatarHp
	play(gs,"c22402"); check(p.units[1].hp==hp and p.avatarHp==avatar-6 and p.units[1].attack==2,"conquest transfers enemy combat damage to avatar while preserving enemy source, no false growth")
	check(p.units[1].get("asuraConquestTokens",[]).is_empty(),"conquest transfer ends with actual battle")
	gs._damage_unit(0,1,1,1,2,true); check(p.units[1].hp==hp-1,"later combat damage no longer uses expired conquest")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c22407"); avatar=p.avatarHp; hp=p.units[1].hp
	gs._damage_unit(0,1,3,1,2,true); gs._resolve_resolution_stack()
	check(p.units[1].hp==hp and p.avatarHp==avatar-3 and p.units[1].attack==7,"awake first combat replacement becomes friendly3damage and grants3power")
	gs._damage_unit(0,1,2,1,2,true); check(p.units[1].hp==hp-2 and p.avatarHp==avatar-3,"awake transfer once per turn")
	gs=game(); p=gs.player(0); gs._knockout_unit(p.units[1]); var ko: int=p.units[1].knockout; avatar=p.avatarHp
	play(gs,"c22405"); check(p.units[1].hp==5 and p.units[1].attack==2+1+ko and p.avatarHp==avatar-2*(1+ko) and p.units[1].front==1,"break snapshots KO, revives first, independent2damage repeats and actual combat")
	gs=game(); p=gs.player(0); avatar=p.avatarHp; play(gs,"c22405"); check(p.avatarHp==avatar-2 and p.units[1].attack==3,"break also legal alive with one2damage packet")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c22408")
	check(p.avatarHp==28 and p.units[1].hp==3 and p.units[1].attack==3 and foe.avatarHp==22 and p.units[1].shield==3,"inferno damages all characters2before true+3/+3 combat with self-growth")
	for u in foe.units: check(u.hp==int(u.maxHp)-2,"inferno hits each enemy unit exactly once")

func boundary_rules() -> void:
	var gs := GS.create(["gitongwan","axiuluo","yaodaoji","baizangzhu"],["gitongwan","axiuluo","bingyong","yaodaoji"],214224)
	check(gs.player(0).hand.slice(0,4).all(func(i):return not i.has("drawnTurn")) and gs.player(1).hand.all(func(i):return not i.has("drawnTurn")),"opening dealing does not grant draw-turn enhancement")
	check(gs.player(0).get("oniDrawCounter",0)==1 and gs.player(0).oniDrawHistory.back().card==gs.player(0).hand.back().definitionId,"normal first-turn draw is recorded independently of opening")
	gs=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c21401"); gs._grow_unit(foe.units[2],10,30); foe.units[2].front=1; var hp: int=p.units[0].hp; var energy: int=p.energy
	draw(gs,"c21402"); check(p.units[0].hp==hp and p.energy==energy and not p.attackUsed,"impulse immune attack survives strong counter and pays neither fire nor ordinary action")
	gs=game(); p=gs.player(0); var entry := draw(gs,"c21402"); var h: int=p.hand.find(entry); turn(gs,0)
	check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==1,"draw-turn instant expires at real next turn boundary")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.units[0].level=0; var top := inst(gs,"c22401"); p.deck.append(top); Oni.turn_start(gs,0)
	check(p.deck.back().instanceId==top.instanceId,"inactive oni does not filter deck top")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.units[0].frozen=1; p.units[0].formRules={"oniImpulse":true}; p.units[0].formInstalledOrder=999; var avatar: int=foe.avatarHp
	draw(gs,"c21402"); check(foe.avatarHp==avatar,"frozen oni cannot take automatic impulse attack")
	gs=game(); p=gs.player(0); install_rebirth(gs,["c21402","c21402","c21402"]); p.deck.clear(); gs._damage_unit(0,0,100,1,2); gs._resolve_resolution_stack()
	check(gs.winner==1 and p.units[0].hp==0,"rebirth empty-deck draw loses normally rather than inventing revival")
	gs=game(); p=gs.player(0); play(gs,"c22407"); p.units[1].shield=5; hp=p.units[1].hp
	gs._damage_unit(0,1,3,1,2,true); check(p.units[1].hp==hp and not p.units[1].has("asuraTransferTurn"),"fully blocked combat damage does not consume awake replacement")
	p.units[1].shield=0; gs._damage_unit(0,1,1,1,2,false); check(p.units[1].hp==hp-1 and not p.units[1].has("asuraTransferTurn"),"noncombat damage does not consume awake replacement")
	gs=game(); p=gs.player(0); play(gs,"c22407"); gs._damage_unit(0,1,1,1,2,true); var used: int=p.units[1].asuraTransferTurn
	turn(gs,0); hp=p.units[1].hp; gs._damage_unit(0,1,1,1,2,true)
	check(p.units[1].hp==hp and p.units[1].asuraTransferTurn!=used,"awake replacement refreshes at every player turn")
	gs=game(); p=gs.player(0); play(gs,"c22406"); gs.kw_usage(0,"instant").used=false; play(gs,"c22406"); p.avatarHp=20
	gs._damage_avatar(0,1,0,1); gs._resolve_resolution_stack(); check(p.avatarHp==21,"two actual healing realms trigger independently and can restore prior missing health")
	gs=game(); p=gs.player(0); play(gs,"c22406"); p.avatarHp=1; gs._damage_avatar(0,2,0,1); gs._resolve_resolution_stack()
	check(gs.winner==1 and p.avatarHp==0,"post-damage realm recovery does not bypass lethal self-damage")
	gs=game(); p=gs.player(0); gs._knockout_unit(p.units[1]); p.avatarHp=2; var hbreak := give(gs,"c22405")
	check(AI._score_card(gs,0,gs.hand_card_def(0,hbreak),null)<0,"AI avoids certain lethal revival self-damage")
	gs=game(); p=gs.player(0); foe=gs.player(1); var htarget := give(gs,"c21406"); var candidate: Dictionary=AI._best_card(gs,0)
	check(candidate.ok and gs.valid_targets(0,gs.playable_card(0,int(candidate.hand),bool(candidate.origin))).has(candidate.target),"AI pursuit chooses legal actual reserve target")
	check(gs.play_card(0,int(candidate.hand),candidate.target,bool(candidate.origin)),"AI chosen combat actually executes")
	gs=game(); p=gs.player(0); var options: Dictionary={"asuraConquest":true}; Oni.combat_started(gs,0,1,options)
	gs._resolve_combat_hit({"movementCancelled":true,"playerIndex":0,"sourceIndex":1,"options":options})
	check(p.units[1].get("asuraConquestTokens",[]).is_empty(),"cancelled battle clears conquest scope before any later combat")

func ui_rules() -> void:
	root.size=Vector2i(1600,740)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	var b := Battle.new(); b.setup(["gitongwan","axiuluo","yaodaoji","baizangzhu"],["gitongwan","axiuluo","bingyong","yaodaoji"],214224); b._ai_thinking=true
	for side in b.gs.players:
		side.hand.clear(); side.energy=40; side.levelUpUsed=true; side.oniFirstDrawTurn=-1
		for u in side.units: u.level=3
	root.add_child(b); await create_timer(0.4).timeout
	var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	p.deck=[inst(gs,"c21402"),inst(gs,"c22401"),inst(gs,"c21405")]
	hand(b,["c21408"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(gs.pending_choice.get("type")=="native-divination" and faces(b._choice_layer).size()==3,"native rebirth card exposes actual3topcards")
	await capture("01-original-rebirth-divination")
	while not gs.pending_choice.is_empty():
		await click(choice_face(b)); await settled(b)
	check(p.units[0].form.cardId=="c21408" and p.units[0].hp==7,"native full top-bottom choices install rebirth form")
	hand(b,["c22407","c22406","c22404"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(p.units[1].attack==13 and p.units[1].maxHp==9 and p.avatarHp==30 and p.realms[0].hp==2,"native awake plus realm plus demon entry resolves self-damage growth and recovery")
	await capture("02-asura-self-damage-recovery-and-growth")
	hand(b,["c21406"]); p.hand[0].drawnTurn=gs.turn_counter; gs._grow_unit(foe.units[2],0,30); b._last_view={}; b._refresh(); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	check(b._pending_target_card==0 and b._unit_widget(str(foe.units[2].uid)).selected,"native enhanced pursuit allows actual reserve target")
	await capture("03-original-enhanced-pursuit-target")
	await click(b._unit_widget(str(foe.units[2].uid))); await settled(b); check(foe.units[2].hp==0,"native enhanced pursuit lethal actually removes high HP target")
	hand(b,[]); p.units[0].front=1; gs._grow_unit(foe.units[3],10,100)
	var cursed := inst(gs,"c21402"); cursed.eyeCurses=1; p.deck.append(cursed)
	gs._resolve_combat(1,3,0,false,false,true,true); gs._resolve_resolution_stack(); b._last_view={}; b._refresh(); await settled(b)
	check(gs.pending_choice.get("type")=="eye-curse" and choice_face(b,"eye-curse-hand")!=null,"native combat pauses for actual rebirth draw-charm choices")
	await capture("04-rebirth-pauses-combo-for-draw-choice")
	await click(choice_face(b,"eye-curse-hand")); await settled(b)
	check(gs.pending_choice.is_empty() and p.units[0].hp==7,"native choice resumes remaining exchange and reattaches rebirth exactly once")
	b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out=OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	ghost_draw_and_forms(); guide_and_chain(); rebirth_rules(); asura_growth_and_realms(); asura_combat(); boundary_rules(); await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("ONI_ASURA checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
