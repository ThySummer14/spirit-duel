extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Fox := preload("res://scripts/pipe_fox_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("PIPE_FOX_FAIL ",detail)

func game() -> GS:
	var gs := GS.create(["guanhu","baizangzhu","yaodaoji","wuguishi"],["guanhu","baizangzhu","bingyong","yaodaoji"],235233)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for unit in p.units: unit.level=3
		p.units[0].abilityCountdown.remaining=2
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"pipe-fox-%d" % gs.next_card_id}); gs.next_card_id+=1; return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"real play "+id)

func turn(gs, owner: int) -> void:
	check(gs.end_turn(owner),"real end turn %d" % owner); gs.player(1-owner).levelUpUsed=true

func tick(gs, amount: int) -> void:
	gs.VerifiedRules.reduce_countdown(gs,0,0,amount); gs._resolve_resolution_stack()

func combat(gs, owner: int, idx: int) -> void:
	gs._resolve_combat(owner,idx,0,false,false,false,false); gs._resolve_resolution_stack()

func pipe_rules() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	check(p.units[0].attack==2 and p.units[0].maxHp==4 and p.units[0].abilityCountdown.remaining==2,"pipe base exact2/4 with real countdown2")
	var avatar: int=foe.avatarHp; tick(gs,2); check(foe.avatarHp==avatar,"base countdown never projects into empty front")
	for unit in foe.units: gs._grow_unit(unit,0,30)
	foe.units[2].front=1; var front_hp: int=foe.units[2].hp; var reserve_hp: int=foe.units[3].hp
	Fox.mark(gs,0,0,1,3); Fox.mark(gs,0,0,1,3); tick(gs,2)
	check(foe.units[2].hp==front_hp-2 and foe.units[3].hp==reserve_hp-4 and foe.units[3].get("pipeMarks",[]).is_empty(),"countdown base hit plus two independent mark replicas, then marks removed")
	Fox.mark(gs,0,0,1,2); front_hp=foe.units[2].hp; tick(gs,2)
	check(foe.units[2].hp==front_hp-4,"marked main target gets primary and extra hit")
	var count: int=gs.rule_events.filter(func(e):return e.kind=="ability-trigger" and e.uid==p.units[0].uid).size()
	check(count==3 and p.units[0].abilityCountdown.remaining==2,"countdown uses true ability events and resets2")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.units[0].abilityCountdown.remaining=2
	play(gs,"c23501",foe.units[3].uid); check(p.energy==40 and p.units[0].abilityCountdown.remaining==1 and foe.units[3].pipeMarks.size()==1,"missile instant attaches before reducing countdown1")
	play(gs,"c23503",foe.units[2].uid)
	check(foe.units[2].frozen>0 and foe.units[3].frozen>0 and foe.units[2].get("pipeMarks",[]).is_empty() and foe.units[3].pipeMarks.is_empty(),"stun bomb marks chosen target then stuns all marked enemies and removes all marks")
	check(foe.units[0].frozen==0,"stun bomb leaves unmarked enemy unchanged")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[2],0,30); foe.units[2].front=1; front_hp=foe.units[2].hp
	play(gs,"c23504"); check(foe.units[2].hp==front_hp-7 and foe.units[2].get("pipeMarks",[]).is_empty() and p.units[0].shield==0,"contract marks front, triggers2+2 before actual3power combat and real shield")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23505")
	check(p.units[0].attack==3 and p.units[0].maxHp==5 and p.units[0].abilityCountdown.mode=="awakened","pipe awakening exact1/1 changes timer mode")
	for unit in foe.units: gs._grow_unit(unit,0,20)
	var total_before := 0
	for unit in foe.units: total_before+=int(unit.hp)
	tick(gs,2); var total_after := 0
	for unit in foe.units: total_after+=int(unit.hp)
	check(total_after==total_before-2,"awake countdown hits a random enemy unit with no front")
	turn(gs,0); check(Fox.mark_count(gs,0)==1,"awake own end really attaches random mark")
	gs=game(); p=gs.player(0); foe=gs.player(1)
	Fox.mark(gs,0,0,1,0); Fox.mark(gs,0,0,1,3); gs._grow_unit(foe.units[2],15,30)
	var health: int=p.units[0].hp; var h := give(gs,"c23506")
	check(gs.hand_card_def(0,h).value==6 and gs.valid_targets(0,gs.hand_card_def(0,h)).has(foe.units[2].uid),"throw reads two real marks and allows pursuit reserve target")
	check(gs.play_card(0,h,foe.units[2].uid) and p.units[0].hp==health and foe.units[2].hp==28,"pursuit throw actual8damage and immune combat counter")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23507","avatar-1")
	check(foe.avatarHp==25 and Fox.mark_count(gs,0)==4,"thunder actual5damage then marks every living enemy unit")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[3].hp=1; play(gs,"c23507",foe.units[3].uid)
	check(foe.units[3].hp==0 and Fox.mark_count(gs,0)==3,"thunder does not attach to killed target")

func pipe_forms() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c23502"); check(p.units[0].attack==3 and p.units[0].maxHp==5 and p.units[0].formCountdown.remaining==3,"bamboo form3/5 countdown3 replaces base timer")
	check(p.units[0].formAbility.contains("倒计时3") and p.units[0].formAbility.contains("5点伤害"),"pipe form inspector uses corrected native ability, not old1damage text")
	gs._grow_unit(foe.units[3],0,30); Fox.mark(gs,0,0,1,3); var health: int=foe.units[3].hp
	tick(gs,3); check(foe.avatarHp==25 and foe.units[3].hp==health-5 and p.units[0].formCountdown.remaining==3,"bamboo5avatar and marked unit copies same5damage")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23508"); tick(gs,6)
	check(p.units[0].formCountdown.remaining==3,"bomb actual countdown9 reduced to3")
	play(gs,"c23502"); check(p.units[0].pipeBombRemaining==3 and p.units[0].formCountdown.remaining==3,"departing bomb remembers remaining, new bamboo owns independent3timer")
	play(gs,"c23508"); check(p.units[0].formCountdown.remaining==3,"next same bomb inherits old remaining3")
	for unit in foe.units: gs._grow_unit(unit,0,30)
	var amounts: Array=foe.units.map(func(u):return int(u.hp)); Fox.mark(gs,0,0,1,0); Fox.mark(gs,0,0,1,3)
	tick(gs,3); check(foe.avatarHp==16 and Fox.mark_count(gs,0)==0 and p.units[0].formCountdown.remaining==9,"bomb removes two marks first, deals14all and resets9")
	for idx in foe.units.size(): check(foe.units[idx].hp==int(amounts[idx])-14,"bomb exact14 once to enemy %d without ordinary mark duplicates" % idx)
	play(gs,"c23508"); check(p.units[0].formCountdown.remaining==9,"bomb after triggering inherits reset9 rather than old3")
	tick(gs,2); gs._knockout_unit(p.units[0]); check(p.units[0].pipeBombRemaining==7 and p.units[0].get("formCountdown",{}).is_empty(),"knockout removes form but remembers7")
	gs.VerifiedRules.reduce_countdown(gs,0,0,int(p.units[0].knockout)); play(gs,"c23508")
	check(p.units[0].formCountdown.remaining==7,"bomb history persists after natural-style revival")
	gs=game(); p=gs.player(0); p.units[0].level=0; tick(gs,2); check(p.units[0].abilityCountdown.remaining==2,"inactive pipe timer cannot tick")
	gs=game(); p=gs.player(0); foe=gs.player(1); Fox.mark(gs,0,0,1,3); gs._knockout_unit(foe.units[3]); check(foe.units[3].get("pipeMarks",[]).is_empty(),"knockout clears live fox marks")

func white_combat() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	check(p.units[1].attack==3 and p.units[1].maxHp==3,"white base3/3")
	gs._grow_unit(p.units[1],0,30); gs._grow_unit(foe.units[2],4,30); foe.units[2].front=1
	var hp: int=p.units[1].hp; check(gs.basic_attack(0,1) and p.units[1].hp==hp and p.units[1].foxImmuneTurn==gs.turn_counter,"white attacks stronger enemy and grants true combat immunity")
	combat(gs,0,1); check(p.units[1].hp<hp,"white base immunity once per turn")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(p.units[1],0,20); foe.units[3].front=1; hp=p.units[1].hp
	combat(gs,0,1); check(p.units[1].hp==hp-3 and not p.units[1].has("foxImmuneTurn"),"equal enemy power does not trigger or consume immunity")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(p.units[1],0,20); gs._grow_unit(foe.units[2],4,20); p.units[1].front=1; hp=p.units[1].hp
	combat(gs,1,2); check(p.units[1].hp==hp-5,"unawakened white cannot immune on defense")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23305"); gs._grow_unit(p.units[1],0,20); gs._grow_unit(foe.units[2],5,20); p.units[1].front=1; hp=p.units[1].hp
	combat(gs,1,2); check(p.units[1].attack==4 and p.units[1].hp==hp,"awake exact1/1 also immunes defense against stronger enemy")
	gs._damage_unit(0,1,2,1,2); check(p.units[1].hp==hp-2,"combat immunity never prevents later noncombat damage")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23301"); check(p.units[1].attack==3 and p.units[1].maxHp==6,"guard form3/6")
	check(p.units[1].formAbility.contains("免疫敌方非战斗伤害"),"white form inspector uses native immunity instead of legacy armor text")
	gs._damage_avatar(0,8,1,2); check(p.avatarHp==30,"guard prevents enemy noncombat avatar damage")
	gs._damage_avatar(0,2,0,1); check(p.avatarHp==28,"guard allows friendly self damage")
	gs._damage_avatar(0,2,1,2,false,true); check(p.avatarHp==26,"guard allows enemy combat damage")
	gs._knockout_unit(p.units[1]); gs._damage_avatar(0,1,1,2); check(p.avatarHp==25,"guard stops when source knocked")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23308"); gs._grow_unit(p.units[2],0,20); var hp2: int=p.units[2].hp
	gs._damage_unit(0,2,12,1,2); check(p.units[2].hp==hp2-5,"dream shadow caps unit damage12to5")
	gs._damage_avatar(0,6,1,2); check(p.avatarHp==25,"dream shadow caps avatar6to5")
	p.units[2].shield=8; hp2=p.units[2].hp; gs._damage_unit(0,2,12,1,2)
	check(p.units[2].hp==hp2-4 and p.units[2].shield==0,"damage threshold applied after armor, remaining4not5")
	play(gs,"c23301"); hp2=p.units[2].hp; gs._damage_unit(0,2,8,1,2); check(p.units[2].hp==hp2-8,"replacing shadow removes global cap")

func white_spells() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	var hp: int=foe.units[2].hp; var power: int=foe.units[2].attack
	play(gs,"c23302",foe.units[2].uid); check(p.energy==40 and foe.units[2].hp==hp-2 and foe.units[2].maxHp==hp-2 and foe.units[2].attack==power+2,"pillow instant actual temporary+2/-2")
	turn(gs,0); check(foe.units[2].hp==hp and foe.units[2].maxHp==hp and foe.units[2].attack==power,"pillow expires at actual end turn")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[3].hp=2; play(gs,"c23302",foe.units[3].uid)
	check(foe.units[3].hp==0 and not foe.units[3].has("foxPillow"),"pillow reduction can actually knock out2HPtarget and does not survive death")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23304",foe.units[3].uid)
	check(foe.units[3].hp>0 and foe.units[3].frozen>0,"rage stuns enemy below6withoutdestroy")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[2],5,0); play(gs,"c23304",foe.units[2].uid)
	check(foe.units[2].hp==0,"rage exact6destroys without damage")
	gs=game(); p=gs.player(0); foe=gs.player(1)
	var hp_before: Array=foe.units.map(func(u):return int(u.hp)); var powers: Array=foe.units.map(func(u):return int(u.attack))
	play(gs,"c23307")
	for idx in foe.units.size(): check(foe.units[idx].hp==maxi(0,int(hp_before[idx])-int(powers[idx])),"burn uses each victim own power %d" % idx)
	gs=game(); p=gs.player(0); foe=gs.player(1); var deck: int=p.deck.size(); play(gs,"c23303")
	check(p.deck.size()==deck-1 and Fox.avatar_veil(gs,0) and p.units.all(func(u):return u.get("foxVeil",false)),"manual white gives all own living characters veil then draws1")
	check(not gs.valid_targets(1,Content.card_def("c23507")).has("avatar-0") and not gs.valid_targets(1,Content.card_def("c23507")).has(p.units[2].uid),"white veil actually prevents targeted enemy spell on unit and avatar")
	turn(gs,0); check(Fox.avatar_veil(gs,0),"white veil survives opponent start")
	turn(gs,1); check(not Fox.avatar_veil(gs,0) and not p.units.any(func(u):return u.get("foxVeil",false)),"white veil expires exactly own next start")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); var hp_target: int=foe.units[2].hp; deck=foe.deck.size(); play(gs,"c23507",foe.units[2].uid)
	check(foe.units[2].hp==hp_target and foe.hand.size()==1 and foe.deck.size()==deck-1 and foe.energy==39 and Fox.mark_count(gs,0)==0,"automatic white counter cancels entire original thunder, pays real fire and draws")
	check(gs.rule_events.any(func(e):return e.kind=="card-nullified" and e.get("byCard")=="c23303"),"counter records actual original resolution")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); foe.energy=0; play(gs,"c23507","avatar-1")
	check(foe.avatarHp==25 and foe.hand.size()==1,"unpayable white response never cancels card")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); play(gs,"c23307")
	check(foe.hand.size()==1,"nontargeted area spell never triggers single-target counter")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); hp_target=foe.units[2].hp
	play(gs,"c23506",foe.units[2].uid); check(foe.units[2].hp==hp_target and int(p.units[0].front)==0,"white also counters actual targeted combat card before entry")

func cleanse_rules() -> void:
	var gs := game(); var p: Dictionary=gs.player(0)
	gs.VerifiedRules.OwlInsect.corrode(gs,1,3,0,2,3,false)
	var hp: int=p.units[2].hp; play(gs,"c23306")
	check(p.units[1].attack==3 and p.units[1].maxHp==7 and p.units[2].insectCorrosion==2 and p.units[2].hp==hp+1,"cleanse form3/7 entry removes exactly one enemy corrosion layer")
	turn(gs,0); check(p.units[2].insectCorrosion==1,"cleanse runs at enemy turn start too")
	turn(gs,1); check(p.units[2].insectCorrosion==0,"cleanse runs at own start too")
	gs=game(); p=gs.player(0); gs.VerifiedRules.OwlInsect.corrode(gs,0,3,0,2,1,false); play(gs,"c23306")
	check(p.units[2].insectCorrosion==1,"cleanse preserves friendly given corrosion")
	gs=game(); p=gs.player(0); gs.VerifiedRules.Stun.apply(gs,0,2,1,1); play(gs,"c23306"); check(p.units[2].frozen==0,"cleanse removes enemy stun")
	gs=game(); p=gs.player(0); gs.VerifiedRules.Stun.apply(gs,0,2,1,0); play(gs,"c23306"); check(p.units[2].frozen>0,"cleanse preserves friendly stun")
	gs=game(); p=gs.player(0); Fox.mark(gs,1,0,0,2); Fox.mark(gs,1,0,0,2); play(gs,"c23306")
	check(p.units[2].pipeMarks.size()==1,"cleanse removes exactly one enemy pipe mark")
	gs=game(); p=gs.player(0)
	for entry in p.deck: entry.erase("eyeCurses"); entry.erase("nightmareMarks"); entry.erase("bondMarks")
	p.deck[0].eyeCurses=2; play(gs,"c23306"); check(p.deck[0].eyeCurses==1,"cleanse reaches actual deck and removes one curse")
	gs=game(); p=gs.player(0); p.deck[0].nightmareMarks=[{"owner":1,"sourceUid":"ai:0"},{"owner":0,"sourceUid":"player:0"}]
	play(gs,"c23306"); check(p.deck[0].nightmareMarks.size()==1 and p.deck[0].nightmareMarks[0].owner==0,"cleanse preserves own charm on same actual deck card")
	gs=game(); p=gs.player(0); Fox.mark(gs,1,0,0,2); play(gs,"c23301"); turn(gs,0)
	check(p.units[2].pipeMarks.size()==1,"other white form does not cleanse")
	gs=game(); p=gs.player(0); play(gs,"c23306"); gs._knockout_unit(p.units[1]); Fox.mark(gs,1,0,0,2); turn(gs,0)
	check(p.units[2].pipeMarks.size()==1,"knocked white cannot keep cleansing")
	gs=game(); p=gs.player(0); Fox.mark(gs,1,0,0,2); gs._knockout_unit(p.units[2]); check(p.units[2].get("pipeMarks",[]).is_empty(),"knockout clears pipe mark metadata")
	gs=game(); p=gs.player(0); Fox.mark(gs,1,0,0,2); gs.VerifiedRules.Moon.full_moon(gs,p.units[2]); check(p.units[2].get("pipeMarks",[]).is_empty(),"full moon is extended to new live charm type")

func boundary_rules() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	turn(gs,0); check(p.units[0].abilityCountdown.remaining==2,"own timer does not naturally tick at enemy start")
	turn(gs,1); check(p.units[0].abilityCountdown.remaining==1,"own timer naturally ticks at own start")
	gs=game(); p=gs.player(0); foe=gs.player(1)
	for unit in foe.units: gs._knockout_unit(unit)
	play(gs,"c23505"); tick(gs,2); turn(gs,0)
	check(Fox.mark_count(gs,0)==0,"awake random damage and attachment safely skip no living enemy")
	gs=game(); p=gs.player(0); foe=gs.player(1); Fox.mark(gs,0,0,1,3); p.units[0].abilityCountdown.remaining=1
	gs._knockout_unit(p.units[0]); var hp: int=foe.units[3].hp
	gs.VerifiedRules.reduce_countdown(gs,0,0,1); gs._resolve_resolution_stack()
	check(foe.units[3].hp==hp and p.units[0].knockout>0,"knocked pipe reduction affects real KO countdown, no living ability")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); play(gs,"c23302",p.units[2].uid)
	check(foe.hand.size()==1 and not Fox.avatar_veil(gs,1),"enemy counter does not respond to friendly-target spell")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); gs._grow_unit(foe.units[2],0,20); foe.units[2].front=1; play(gs,"c23504")
	check(foe.hand.size()==1 and not Fox.avatar_veil(gs,1),"automatic-front combat has no declared single target, no white counter")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); gs._knockout_unit(foe.units[1]); play(gs,"c23507","avatar-1")
	check(foe.avatarHp==25 and foe.hand.size()==1,"knocked response source cannot counter")
	gs=game(); p=gs.player(0); foe=gs.player(1); give(gs,"c23303",1); foe.units[1].frozen=1; play(gs,"c23507","avatar-1")
	check(foe.avatarHp==25 and foe.hand.size()==1,"frozen response source cannot counter")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(p.units[1],0,30); gs._grow_unit(foe.units[2],8,30); foe.units[2].front=1
	combat(gs,0,1); var turn_used: int=p.units[1].foxImmuneTurn; play(gs,"c23305"); p.units[1].front=1; hp=p.units[1].hp
	combat(gs,1,2); check(p.units[1].foxImmuneTurn==turn_used and p.units[1].hp<hp,"awakening does not reset already used per-turn protection")
	gs=game(); p=gs.player(0); gs._grow_unit(p.units[2],0,10)
	gs.VerifiedRules.OwlInsect.corrode(gs,0,3,0,2,1,false); gs.VerifiedRules.OwlInsect.corrode(gs,1,3,0,2,2,false); play(gs,"c23306"); Fox.cleanse(gs,0,1); Fox.cleanse(gs,0,1)
	check(p.units[2].insectCorrosion==1 and p.units[2].insectCorrosionOwners.get("0")==1 and p.units[2].insectCorrosionOwners.get("1")==0,"mixed corrosion cleanup removes only two enemy layers and stops at friendly layer")
	gs=game(); p=gs.player(0); gs.VerifiedRules.Stun.apply(gs,0,2,1,0); gs.VerifiedRules.Stun.apply(gs,0,2,1,1); play(gs,"c23306")
	check(p.units[2].frozen>0 and int(p.units[2].stunOwners.get("1",0))==0 and int(p.units[2].stunOwners.get("0",0))>0,"mixed stun cleanup preserves friendly remaining stun")
	gs=game(); p=gs.player(0); gs.VerifiedRules.Stun.apply(gs,0,-1,1,1); play(gs,"c23306"); check(p.avatarFrozen==0,"cleanse can clear enemy-given avatar stun")
	gs=game(); p=gs.player(0); var h := give(gs,"c23502"); p.hand[h].nightmareMarks=[{"owner":1,"sourceUid":"ai:0"}]
	play(gs,"c23306"); check(p.hand[h].nightmareMarks.is_empty(),"cleanse also reaches actual hand instance charms")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23308"); gs._grow_unit(p.units[2],0,20); p.units[2].shield=1; hp=p.units[2].hp
	gs._damage_unit(0,2,4,1,2,false,-1,false,true); check(p.units[2].hp==hp-5,"critical after armor6damage is capped5")
	gs._knockout_unit(p.units[1]); hp=p.units[2].hp; gs._damage_unit(0,2,8,1,2); check(p.units[2].hp==hp-8,"knocked dream-shadow source stops team cap")

func ai_rules() -> void:
	var gs := game(); var foe: Dictionary=gs.player(1); foe.units[2].hp=2; var h := give(gs,"c23302")
	check(AI._score_card(gs,0,gs.hand_card_def(0,h),foe.units[2].uid)>0 and AI._score_card(gs,0,gs.hand_card_def(0,h),gs.player(0).units[2].uid)<0,"AI pillow chooses beneficial enemy instead of harming own ally")
	gs.player(0).hand.clear(); give(gs,"c23506"); var chosen: Dictionary=AI._best_card(gs,0)
	check(chosen.ok and gs.valid_targets(0,gs.playable_card(0,int(chosen.hand),bool(chosen.origin))).has(chosen.target),"AI pursuit chooses legal actual target")

func ui_rules() -> void:
	root.size=Vector2i(1600,740)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	var b := Battle.new(); b.setup(["guanhu","baizangzhu","yaodaoji","wuguishi"],["guanhu","baizangzhu","bingyong","yaodaoji"],235233); b._ai_thinking=true
	for side in b.gs.players:
		side.hand.clear(); side.energy=40; side.levelUpUsed=true
		for unit in side.units: unit.level=3
		side.units[0].abilityCountdown.remaining=2
	root.add_child(b); await create_timer(0.4).timeout
	var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	hand(b,["c23501","c23503","c23302"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b._pending_target_card==0 and b._unit_widget(str(foe.units[2].uid)).selected,"native missile asks actual enemy target")
	await capture("01-original-missile-target")
	await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
	check(foe.units[2].pipeMarks.size()==1 and p.units[0].abilityCountdown.remaining==1,"native mark and timer change resolve")
	await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[3].uid))); await settled(b)
	check(foe.units[2].frozen>0 and foe.units[3].frozen>0 and foe.units[2].pipeMarks.is_empty(),"native stun bomb stuns real marked targets")
	await capture("02-marked-stun-and-countdown")
	hand(b,["c23302","c23306"]); foe.units[0].hp=2; await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b._unit_widget(str(p.units[2].uid)).selected and b._unit_widget(str(foe.units[0].uid)).selected,"native pillow allows both friendly and enemy actual targets")
	await click(b._unit_widget(str(foe.units[0].uid))); await settled(b); check(foe.units[0].hp==0,"native temporary HP reduction really knocks out selected target")
	Fox.mark(gs,1,0,0,2); hand(b,["c23306"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(p.units[2].pipeMarks.is_empty() and p.units[1].maxHp==7,"native cleanse form installs and removes actual enemy charm")
	hand(b,["c23303"],1); hand(b,["c23507"]); await settled(b); var hp: int=foe.units[2].hp
	await click(b._hand_row.get_child(0)); await settled(b); await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
	check(foe.units[2].hp==hp and Fox.avatar_veil(gs,1),"native enemy white response counter preserves selected target")
	await capture("03-actual-white-counter-and-veil")
	b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out=OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	pipe_rules(); pipe_forms(); white_combat(); white_spells(); cleanse_rules(); boundary_rules(); ai_rules(); await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("PIPE_FOX checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
