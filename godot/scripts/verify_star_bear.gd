extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Star := preload("res://scripts/star_bear_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1; printerr("STAR_BEAR_FAIL ",detail)

func game() -> GS:
	var gs:=GS.create(["xingxiongtongzi","yaodaoji","taohuayao","duyanxiaoseng"],["yaodaoji","bingyong","xuenv","baizangzhu"],251)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.avatarArmor=0
		for u in p.units: u.level=3
		var enc: Dictionary=gs.kw_usage(gs.players.find(p),"encourage"); enc.attack=0; enc.shield=0
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"star-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual card "+id)

func suppression_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	check(u.attack==2 and u.hp==5 and u.passive_hooks.is_empty(),"exact2/5 body clears old immediate-front approximation")
	foe.units[1].front=1; Star.turn_start(gs,0)
	check(foe.units[1].armorBreak==0 and gs.kw_usage(1,"encourage").get("shield",0)==-1,"start banks suppression even with an enemy blocker, never directly applies status")
	play(gs,"c25101",foe.units[0].uid)
	check(foe.units[0].enraged and foe.units[0].attack==3 and foe.units[0].armorBreak==0,"talk enrage does not immediately nerf selected character")
	check(gs.kw_usage(1,"encourage").attack==-1 and gs.kw_usage(1,"encourage").shield==-2,"talk adds exact-1/-1 to existing outgoing suppression")
	gs._apply_encourage(1,2,3)
	check(gs.kw_usage(1,"encourage").attack==1 and gs.kw_usage(1,"encourage").shield==1,"positive encouragement algebraically cancels negative suppression")
	gs.current_player=1; var face: int=p.avatarHp
	check(gs.basic_attack(1,0) and p.avatarHp==face-4 and foe.units[0].shield==1 and not foe.units[0].get("enraged",false),"net positive ledger applied to genuine basic attack and enrage consumed")
	check(gs.kw_usage(1,"encourage").attack==0 and gs.kw_usage(1,"encourage").shield==0,"ordinary attack consumes signed ledger once")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25101",foe.units[0].uid); gs.current_player=1
	play(gs,"c10101",null,1)
	check(gs.kw_usage(1,"encourage").attack==-1 and gs.kw_usage(1,"encourage").shield==-1 and foe.units[0].armorBreak==0,"battle card never ordinarily spends suppression")
	foe.attackUsed=false; face=p.avatarHp
	var attacked: bool=gs.basic_attack(1,0)
	check(attacked and p.avatarHp==face-2 and foe.units[0].armorBreak==0 and foe.units[0].shield==0,"subsequent basic attack receives real reduced power and break cancels prior battle-card armor")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25106")
	check(p.units[0].awakened and p.units[0].attack==3 and p.units[0].maxHp==6,"awakening exact+1/+1")
	check(foe.units[0].attack==3 and gs.kw_usage(1,"encourage").attack==-10,"awakening banks-10 instead of immediately reducing any shikigami")
	Star.turn_start(gs,0)
	check(gs.kw_usage(1,"encourage").attack==-11 and gs.kw_usage(1,"encourage").shield==-1,"awakened own start uses basic version-1 power/1break")
	check(not gs.can_play_card(0,give(gs,"c25106")).ok,"awakening cannot legally repeat")
	gs.current_player=1; face=p.avatarHp; check(gs.basic_attack(1,0) and p.avatarHp==face,"negative attack power clamps at0 without negative damage healing")
	gs=game(); u=gs.player(0).units[0]; u.level=0; Star.turn_start(gs,0)
	check(gs.kw_usage(1,"encourage").get("shield",0)==0,"inactive level0 passive absent")
	u.level=3; u.baseRulesSuppressed=true; Star.turn_start(gs,0)
	check(gs.kw_usage(1,"encourage").get("shield",0)==0,"paper-suppressed passive absent")
	u.baseRulesSuppressed=false; gs._knockout_unit(u); Star.turn_start(gs,0)
	check(gs.kw_usage(1,"encourage").get("shield",0)==0,"knocked-out passive absent")
	gs=game(); play(gs,"c25101",gs.player(0).units[1].uid)
	check(gs.player(0).units[1].enraged and not gs.can_basic_attack(0,0).ok and gs.can_basic_attack(0,1).ok,"talk accepts friendly target and reuses actual enrage attack-priority legality")
	check(not gs.valid_targets(0,Content.card_def("c25101")).has("avatar-1"),"talk selects shikigami, never avatar")
	gs.player(1).units[2].keywords=["veil"]
	check(not gs.valid_targets(0,Content.card_def("c25101")).has(gs.player(1).units[2].uid),"targeted enrage obeys enemy veil")

func response_and_forms() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	give(gs,"c25104"); gs.current_player=1; var hp: int=p.avatarHp
	check(gs.basic_attack(1,0) and p.avatarHp==hp-1 and foe.units[0].armorBreak==2,"spare responds before existing basic attack reads exact-2power/+2break")
	check(p.hand.is_empty() and p.energy==40 and gs.kw_usage(0,"instant").used,"enemy-turn instant response consumes shared turn allowance with0 fire")
	check(gs.rule_events.any(func(e):return e.kind=="response-card" and e.trigger=="enemy-basic-attack"),"real response event names basic attack rather than front-entry")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[0].front=1; give(gs,"c25104"); gs.current_player=1; hp=p.avatarHp
	check(gs.basic_attack(1,0) and p.avatarHp==hp-1 and p.hand.is_empty(),"already-frontline basic attack also triggers response")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[0].keywords=["remote"]; give(gs,"c25104"); gs.current_player=1; hp=p.avatarHp
	check(gs.basic_attack(1,0) and p.avatarHp==hp-1 and foe.units[0].front==0 and p.hand.is_empty(),"remote ordinary attack triggers response without invented front movement")
	gs=game(); p=gs.player(0); give(gs,"c25104"); gs.current_player=1; play(gs,"c10101",null,1)
	check(p.hand.size()==1 and gs.kw_usage(1,"encourage").get("attack",0)==0,"enemy combat card does not trigger basic-only response")
	gs=game(); p=gs.player(0); p.energy=0; gs.kw_usage(0,"instant").used=true; give(gs,"c25104"); gs.current_player=1; hp=p.avatarHp
	check(gs.basic_attack(1,0) and p.avatarHp==hp-3 and p.hand.size()==1,"unfunded response remains in hand and never reduces enemy attack")
	gs=game(); p=gs.player(0); p.units[0].frozen=1; give(gs,"c25104"); gs.current_player=1
	check(gs.basic_attack(1,0) and p.hand.size()==1,"stunned source cannot automatically respond")
	gs=game(); p=gs.player(0); play(gs,"c25104")
	check(gs.kw_usage(1,"encourage").attack==-2 and gs.kw_usage(1,"encourage").shield==-2 and p.energy==40,"active spare banks same suppression with shared instant discount")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25103"); p.avatarHp=20; gs.current_player=1
	play(gs,"c10101",null,1)
	check(foe.avatarHp==28 and p.avatarHp==19,"no violence exact2 damage/heal triggers before actual4damage battle")
	check(p.units[0].attack==2 and p.units[0].maxHp==6,"no violence actual2/6 form")
	var face: int=foe.avatarHp; gs._damage_avatar(0,1,1,0)
	check(foe.avatarHp==face,"noncombat damage never masquerades as use of a battle card")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25105"); gs.current_player=1; play(gs,"c10101",null,1)
	check(p.units[0].attack==8 and p.units[0].maxHp==8 and p.units[0].hp==8,"leisure exact6/6 plus2/2 on opposing battle-card use")
	check(not p.units[0].get("unyielding",false) and not p.units[0].get("formRules",{}).get("monkUnyielding",false),"leisure does not mix later-version unyielding")
	gs.current_player=0; play(gs,"c10101")
	check(p.units[0].attack==8 and p.units[0].maxHp==8,"friendly battle-card use cannot grow leisure")
	gs._knockout_unit(p.units[0]); gs.current_player=1; play(gs,"c10101",null,1)
	check(p.units[0].hp==0 and p.units[0].maxHp==7,"knockout removes native form; no posthumous leisure trigger")

func discord_and_focus() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c25107"); check(p.units[0].attack==5 and p.units[0].hp==8,"discord exact5/8 real form")
	for i in range(1,foe.units.size()): gs._knockout_unit(foe.units[i])
	check(gs.end_turn(0) and foe.units[0].get("enraged",false),"real enemy start randomly enrages sole living opponent")
	foe.levelUpUsed=true; foe.energy=40; var hand_idx:=give(gs,"c10101",1)
	check(not gs.can_play_card(1,hand_idx).ok and not Star.can_use(gs,1,gs.hand_card_def(1,hand_idx)),"discord prevents enraged owner's hand cards before payment")
	check(not AI._best_card(gs,1).ok,"AI excludes discord-locked hand")
	check(gs.can_basic_attack(1,0).ok and gs.basic_attack(1,0),"locked shikigami can use real basic attack to clear enrage")
	check(gs.can_play_card(1,hand_idx).ok,"attack clears enrage and immediately restores source hand legality")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c25107"); gs.VerifiedRules.MonkCleaner.enrage(gs,1,0)
	gs._knockout_unit(p.units[0]); gs.current_player=1
	check(gs.can_play_card(1,give(gs,"c10101",1)).ok,"discord aura disappears when its source is knocked out")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[1].front=1
	gs._apply_encourage(1,2,3); var before: int=foe.units[2].attack; var hp: int=foe.units[2].hp
	play(gs,"c25102",foe.units[2].uid)
	check(foe.units[2].attack==before+2 and foe.units[2].shield==3 and foe.units[2].front==0,"focus copies enemy net positive stats to reserve without moving it")
	check(gs.kw_usage(1,"encourage").attack==2 and gs.kw_usage(1,"encourage").shield==3,"focus reads but never spends enemy outgoing ledger")
	check(gs.basic_attack_targets(0,1)==[foe.units[2].uid],"basic target selector forced to exact focus reserve despite existing front")
	var front_hp: int=foe.units[1].hp; play(gs,"c10101")
	check(foe.units[1].hp==front_hp-3 and foe.units[2].hp==hp,"ordinary combat card retains enemy blocker instead of focus redirect")
	check(gs.basic_attack(0,1,foe.units[2].uid) and foe.units[2].shield==0 and foe.units[1].hp==front_hp-3,"actual ordinary attack forced to reserve and spends its3 copied armor")
	check(gs.end_turn(0) and foe.units[2].attack==before and Star.basic_target(gs,0)==null,"focus power/forced target expires at actual turn boundary")
	gs=game(); p=gs.player(0); foe=gs.player(1); Star.suppress(gs,0,2,3); before=foe.units[1].attack
	play(gs,"c25102",foe.units[1].uid)
	check(foe.units[1].attack==before-2 and foe.units[1].armorBreak==3,"focus copies signed negative power and real3 armor break")
	check(gs.end_turn(0) and foe.units[1].attack==before and foe.units[1].armorBreak==0,"unused focus debuffs fully expire this turn")
	gs=game(); foe=gs.player(1); var target: Dictionary=foe.units[1]; gs._grant_unit_armor(target,4,false); gs._apply_encourage(1,0,2); play(gs,"c25102",target.uid)
	gs._damage_unit(1,1,1,0,0); check(target.shield==5 and target.starTargetArmor==1,"damage consumes copied temporary armor before old permanent armor")
	Star.expire_turn(gs); check(target.shield==4,"expiration removes only surviving copied armor, retaining preexisting armor")
	gs=game(); foe=gs.player(1); target=foe.units[1]; Star.suppress(gs,0,0,3); play(gs,"c25102",target.uid)
	gs._grant_unit_armor(target,2,false); check(target.armorBreak==1 and target.starTargetBreak==1,"armor cancellation tracks remaining copied break")
	Star.expire_turn(gs); check(target.armorBreak==0,"break expiration removes remaining1 exactly")
	gs=game(); foe=gs.player(1); target=foe.units[1]; Star.suppress(gs,0,0,3); play(gs,"c25102",target.uid); gs._damage_unit(1,1,1,0,0)
	check(target.armorBreak==0 and target.get("starTargetBreak",0)==0,"damage consumes copied break and expiration bookkeeping together")
	gs=game(); foe=gs.player(1); gs._apply_encourage(1,2,0); play(gs,"c25102",foe.units[1].uid); play(gs,"c25102",foe.units[2].uid)
	check(Star.basic_target(gs,0)==foe.units[2].uid and foe.units[1].starTargetPower==2,"latest focus changes forced target while earlier temporary stats remain")
	gs._knockout_unit(foe.units[2]); check(Star.basic_target(gs,0)==null and not foe.units[2].has("starTargetPower"),"dead focus target stops redirect and cannot retain temporary stats through revival")

func bowl_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var target: Dictionary=foe.units[1]
	gs._grow_unit(target,0,40); target.level=0
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs,1,0,"bowl-decoy","普通召唤物",0,9,{"countsAsShikigami":false})
	var bowl := give(gs,"c25108")
	check(not gs.can_play_card(0,bowl,decoy.uid).ok and gs.play_card(0,bowl,target.uid),"酒碗拒绝普通召唤物，可以作用于零勾式神")
	check(target.frozen==1 and not Star.bowl(gs).is_empty(),"bowl uses real stun plus persistent replacement marker")
	var hp: int=target.hp; var ours: int=p.avatarHp; var theirs: int=foe.avatarHp
	gs._damage_avatar(0,2,1,0); gs._damage_avatar(1,3,0,0)
	check(target.hp==hp-5 and p.avatarHp==ours and foe.avatarHp==theirs,"both avatars route their original damage to one enemy bowl bearer")
	p.units[2].barrier=true; p.units[2].shield=9; var own_hp: int=p.units[2].hp
	gs._damage_unit(0,2,2,1,0)
	check(target.hp==hp-7 and p.units[2].hp==own_hp and p.units[2].barrier and p.units[2].shield==9,"cross-owner unit replacement precedes original barrier/armor")
	var other_hp: int=foe.units[2].hp; gs._damage_unit(1,2,1,0,0)
	check(target.hp==hp-8 and foe.units[2].hp==other_hp,"same-side other enemy unit routes damage too")
	target.barrier=true; gs._damage_avatar(0,4,1,0)
	check(target.hp==hp-8 and not target.barrier and p.avatarHp==ours,"only final damage receiver consumes barrier")
	gs._grant_unit_armor(target,3,false); gs._damage_avatar(0,2,1,0)
	check(target.shield==1 and target.hp==hp-8,"bowl receiver's armor absorbs redirected damage")
	gs._damage_unit(1,1,2,0,0)
	check(target.hp==hp-9 and target.shield==0,"direct damage to bowl bearer resolves once without redirect loop")
	gs._knockout_unit(p.units[0]); gs._damage_avatar(0,2,1,0)
	check(target.hp==hp-11 and p.avatarHp==ours,"bowl attachment persists after source knockout")
	check(gs.end_turn(0) and target.frozen==1 and gs.end_turn(1) and target.frozen==0,"stun expires only after target's real turn ends")
	gs._damage_avatar(0,2,1,0)
	check(p.avatarHp==ours-2 and target.hp==hp-11,"cleared stun immediately ends replacement")
	gs=game(); p=gs.player(0); foe=gs.player(1); target=foe.units[1]; gs._grow_unit(target,0,20); play(gs,"c25108",target.uid)
	gs.VerifiedRules.Stun.apply(gs,1,1,1,0); target.frozen=0
	check(Star.bowl(gs).is_empty(),"replacement requires actual active stun, not stale attachment alone")
	gs=game(); p=gs.player(0); foe=gs.player(1); target=foe.units[1]; gs._grow_unit(target,0,20); play(gs,"c25108",target.uid)
	p.units[2].front=1; var ally_hp: int=p.units[2].hp; hp=target.hp; var result: Dictionary=gs.VerifiedRules.Combat.strike(gs,1,0,0,2,3,{})
	check(result.get("redirectedPlayer",-1)==1 and result.redirectedIndex==1 and result.redirectedTarget==target.uid,"cross-owner combat result reports actual receiver player/index/uid")
	check(target.hp==hp-3 and p.units[2].hp==ally_hp,"combat uses single actual3 damage despite original target on other side")
	gs=game(); p=gs.player(0); foe=gs.player(1); target=foe.units[1]; play(gs,"c25108",target.uid); gs._damage_avatar(0,20,1,0)
	check(target.hp==0 and not target.has("starBowlSerial") and Star.bowl(gs).is_empty(),"lethal replacement removes bearer and attachment without overflow to original avatar")
	gs._damage_avatar(0,2,1,0); check(p.avatarHp==28,"later damage resumes normal target after bowl knockout")
	gs=game(); foe=gs.player(1); gs._grow_unit(foe.units[1],0,20); gs._grow_unit(foe.units[2],0,20); play(gs,"c25108",foe.units[1].uid); play(gs,"c25108",foe.units[2].uid)
	check(Star.bowl(gs).uid==foe.units[2].uid,"multiple bowl selection preserves latest application order")
	foe.units[2].frozen=0; check(Star.bowl(gs).uid==foe.units[1].uid,"after newest stun ends an older still-stunned attachment remains independently active")

func retained_and_original_protection() -> void:
	var gs:=GS.create(["xingxiongtongzi","yaodaoji","taohuayao","duyanxiaoseng"],["yaodaoji","buzhinhuo","xuenv","baizangzhu"],251)
	check(gs.kw_usage(1,"encourage").get("shield",0)==-1,"natural opening own-start activates exact1 banked suppression before fixture changes")
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.avatarArmor=0
		for u in p.units: u.level=3
	for owner in 2:
		var enc: Dictionary=gs.kw_usage(owner,"encourage"); enc.attack=0; enc.shield=0
	gs.current_player=1; play(gs,"c16706",null,1); Star.suppress(gs,0,1,2)
	var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var hp: int=p.avatarHp
	check(gs.basic_attack(1,0) and p.avatarHp==hp-2 and foe.units[0].armorBreak==2,"retaining form still applies signed-1power/2break to real basic attack")
	check(gs.kw_usage(1,"encourage").attack==-1 and gs.kw_usage(1,"encourage").shield==-2,"real5/5 leaving-dance form retains suppression with all outgoing modifiers")
	foe.attackUsed=false; hp=p.avatarHp
	check(gs.basic_attack(1,1) and p.avatarHp==hp-4 and foe.units[1].armorBreak==2,"retained suppression applies to second distinct real basic attacker")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[1],0,20); play(gs,"c25108",foe.units[1].uid)
	hp=foe.units[1].hp
	var result: Dictionary=gs.VerifiedRules.Combat.strike(gs,1,0,0,2,3,{},false,true)
	check(foe.units[1].hp==hp-3 and result.get("redirectedPlayer",-1)==1,"original receiver combat immunity does not prevent substitution to unprotected cross-owner bowl")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[1],0,20); play(gs,"c25108",foe.units[1].uid)
	p.units[3].formRules={"monkCover":"all"}; hp=foe.units[1].hp; var monk_hp: int=p.units[3].hp
	gs._damage_avatar(0,2,1,0)
	check(foe.units[1].hp==hp-2 and p.units[3].hp==monk_hp,"global bowl replacement precedes original side monk cover")

func ai_art() -> void:
	for n in range(1,9):
		var gs:=game(); var id: String="c251%02d"%n; give(gs,id)
		var best:=AI._best_card(gs,0)
		check(best.ok and best.card_id==id and gs.can_play_card(0,best.hand,best.target).ok,"AI can use legal exact rule "+id)
		check(best.ok and gs.play_card(0,best.hand,best.target),"AI actually executes "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original complete card face "+id)
	var gs:=game(); gs.player(1).units[2].keywords=["veil"]; give(gs,"c25108"); var best:=AI._best_card(gs,0)
	check(best.ok and best.target!=gs.player(1).units[2].uid and gs.valid_targets(0,gs.hand_card_def(0,best.hand)).has(best.target),"AI bowl target obeys actual enemy veil and legality")

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["xingxiongtongzi","yaodaoji","taohuayao","duyanxiaoseng"],["yaodaoji","bingyong","xuenv","baizangzhu"],251); b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.avatarArmor=0
			for u in p.units: u.level=3
		for owner in 2:
			var enc: Dictionary=b.gs.kw_usage(owner,"encourage"); enc.attack=0; enc.shield=0
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var foe: Dictionary=gs.player(1); var p: Dictionary=gs.player(0)
		foe.units[1].front=1; gs._grow_unit(foe.units[2],0,20)
		hand(b,["c25101"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(p.units[1].uid)).selected and b._unit_widget(str(foe.units[2].uid)).selected,"native enrage presents actual friendly and enemy shikigami target choices")
		await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].enraged and gs.kw_usage(1,"encourage").attack==-1 and gs.kw_usage(1,"encourage").shield==-1,"native target click banks suppression and grants real enrage")
		hand(b,["c25102"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and not b._unit_widget(str(p.units[1].uid)).selected and b._unit_widget(str(foe.units[2].uid)).selected,"native focus selects enemy-only actual reserve")
		await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].armorBreak==1 and foe.units[2].starTargetPower==-1,"native focus copies signed negative outgoing modifiers")
		await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._selected_attacker==1 and b._unit_widget(str(foe.units[2].uid)).selected and not b._unit_widget(str(foe.units[1].uid)).selected,"native ordinary attack highlights focus reserve instead of frontline")
		if physical.x==1600: await capture("01-star-focus-reserve-target")
		var hp: int=foe.units[2].hp; await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp==hp-4 and foe.units[2].armorBreak==0,"native actual forced reserve combat includes original3power plus1break")
		hand(b,["c25108"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].frozen==1 and Star.bowl(gs).get("uid","")==foe.units[2].uid,"native bowl mouse target commits real stun attachment")
		hp=foe.units[2].hp; var face: int=p.avatarHp; gs._damage_avatar(0,2,1,0); b._refresh(); await settled(b)
		check(p.avatarHp==face and foe.units[2].hp==hp-2,"native live board reflects cross-owner redirected actual damage")
		await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(texts(b).contains("酒碗") and texts(b).contains("眩晕"),"native inspector explains live replacement duration and bearer")
		if physical.x==1280: await capture("02-star-bowl-live-inspector")
		escape(); await settled(b)
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores()
	var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	suppression_rules(); response_and_forms(); discord_and_focus(); bowl_rules(); retained_and_original_protection(); ai_art()
	if not rules_only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("STAR_BEAR checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
