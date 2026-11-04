extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const RW := preload("res://scripts/rednight_walnut_rules.gd")
const CP := preload("res://scripts/charged_pair_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("REDNIGHT_WALNUT_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["ninghongye","tayumenhutao","rihefang","taohuayao"],["bingyong","yaodaoji","fenghuanghuo","baizangzhu"],266267)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	gs.rule_events.clear();return gs
func give(gs,id: String,owner: int=0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"rw-test-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actual use "+id)
func charge(gs,id: String,target=null) -> void:
	var h:=give(gs,id);var fire:=int(gs.player(0).energy)
	check(CP.request_mode(gs,0,h),"real charge selection "+id)
	check(gs.resolve_divination_choice(0,"charged-store"),"real store selection "+id)
	check(CP.ready_hand(gs,0)==h and gs.play_card(0,h,target),"real store "+id)
	check(gs.player(0).energy==fire-1,"stored card pays once "+id)
func release_now(gs,src: int) -> void:
	check(CP.release(gs,0,src),"release real stored card");gs._resolve_resolution_stack()
func cycle(gs) -> void:
	check(gs.end_turn(0) and gs.end_turn(1),"real full turn cycle")
func evt(gs,kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func rednight_cards() -> void:
	var gs:=game();var u:Dictionary=gs.player(0).units[0];var target:Dictionary=gs.player(1).units[0]
	check(u.attack==3 and u.maxHp==4 and gs.player(0).units[1].attack==2 and gs.player(0).units[1].maxHp==5,"printed base bodies")
	gs._grow_unit(target,0,20);var hp:=int(target.hp)
	play(gs,"c26602",target.uid);check(target.hp==hp-3 and gs.player(1).avatarHp==30,"ordinary shooting has3 and no charged passive")
	gs=game();target=gs.player(1).units[0];gs._grow_unit(target,0,20);hp=int(target.hp)
	charge(gs,"c26602",target.uid);check(target.hp==hp and gs.player(1).avatarHp==30,"unawake storage causes no damage")
	release_now(gs,0);check(target.hp==hp-5 and gs.player(1).avatarHp==29,"charged shooting has5 and real1 projectile")
	gs=game();play(gs,"c26601");target=gs.player(1).units[0]
	gs._damage_unit(1,0,1,0,0);check(not gs.can_basic_attack(1,0).ok,"enemy not current cannot attack irrespective lock")
	check(target.rwDeployBlocked==1 and not RW.can_deploy(target),"lock form noncombat damage records one future deployment turn")
	gs._resolve_resolution_stack();check(gs.end_turn(0),"switch into locked target turn")
	check(not gs.can_basic_attack(1,0).ok and gs.can_basic_attack(1,1).ok,"only actual lock target blocked")
	check(gs.end_turn(1) and not target.has("rwDeployBlocked"),"lock expires after target turn ends")
	gs=game();play(gs,"c26601");target=gs.player(1).units[0];gs._damage_unit(1,0,1,0,0,true)
	check(not target.has("rwDeployBlocked"),"combat damage cannot lock")
	gs=game();charge(gs,"c26601");release_now(gs,0)
	check(gs.player(0).units[0].form.cardId=="c26601" and gs.player(1).units.any(func(t):return t.has("rwDeployBlocked")),"charged lock enters and random3 triggers its own installed form")
	gs=game();target=gs.player(1).units[0];gs._grow_unit(target,0,20);target.front=1;hp=int(target.hp)
	charge(gs,"c26603");release_now(gs,0)
	check(target.hp==hp-5 and gs.player(0).units[0].front==0,"remote arrow4 combat plus1 passive without moving attacker")
	check(gs.player(1).units[1].hp==gs.player(1).units[1].maxHp-1 and gs.player(1).units[2].hp==gs.player(1).units[2].maxHp-1,"charged arrow hits reserve units only")
	gs=game();charge(gs,"c26602",gs.player(1).units[0].uid);u=gs.player(0).units[0];play(gs,"c26604",u.uid)
	check(not u.has("lanternStored") and u.frozen>0 and gs.player(0).energy==39,"instant Kunlun removes actual stored card and stuns without extra fire")
	check(not CP.release(gs,0,0),"removed charge cannot release later")
	gs=game();play(gs,"c26606");u=gs.player(0).units[0];var fire:=int(gs.player(0).energy)
	check(u.swift and gs.basic_attack(0,0),"phoenix form grants genuine swift deployment")
	check(u.has("lanternStored") and u.lanternStored.card.id=="rednight-sword-aura" and gs.player(1).avatarHp==30 and u.front==0,"phoenix replaces deployment with sword-aura charge and no combat")
	check(gs.player(0).energy==fire,"swift replacement costs no fire")
	gs.player(1).units[0].front=1;gs._grow_unit(gs.player(1).units[0],20,30);hp=int(u.hp);var enemy_hp:=int(gs.player(1).units[0].hp)
	release_now(gs,0)
	check(u.hp==hp and u.shield==2 and gs.player(1).units[0].hp==enemy_hp-7,"sword aura actual3 combat +3 postprojectile +1 base, immune counter,2armor remains")
	gs=game();play(gs,"c26607");u=gs.player(0).units[0];check(u.awakened and u.attack==5 and u.maxHp==6,"rednight awakening2/2")
	charge(gs,"c26602",gs.player(1).units[0].uid)
	check(gs.player(1).avatarHp==28 and gs.player(1).avatarFrozen>0,"awake storage real2 projectile stuns actual hit avatar")
	release_now(gs,0);check(gs.player(1).avatarHp==26,"awake release triggers another2 once")
	gs=game();charge(gs,"c26608",gs.player(1).units[0].uid);release_now(gs,0)
	check(gs.player(1).units.all(func(t):return t.frozen>0),"charged scarlet stuns all actual enemy shikigami")
	gs=game();play(gs,"c26608",gs.player(1).units[0].uid)
	check(gs.player(1).units[0].frozen>0 and gs.player(1).units[1].frozen==0,"ordinary scarlet stuns only chosen enemy")
	gs=game()
	for t in gs._all_units():gs._grow_unit(t,0,30)
	var before: Array=gs._all_units().map(func(t):return int(t.hp));play(gs,"c26605",gs.player(1).units[0].uid)
	var hit_count:=0
	for i in before.size():
		if gs._all_units()[i].hp==before[i]-3:hit_count+=1
	check(hit_count==2,"scatter selects one distinct enemy other and deals3 to each")
	check(gs.player(0).units.all(func(t):return t.hp==before[gs.player(0).units.find(t)]),"scatter cannot damage own shikigami")
	check(not gs.valid_targets(0,Content.card_def("c26605")).has(gs.player(0).units[0].uid),"scatter cannot manually select own shikigami")
func walnut_cards() -> void:
	var gs:=game();var u:Dictionary=gs.player(0).units[1];var ally:Dictionary=gs.player(0).units[2]
	gs._knockout_unit(ally,1,0);gs._resolve_resolution_stack();var ko:=int(ally.knockout)
	check(gs.basic_attack(0,1) and ally.knockout==ko-1 and gs.player(1).avatarHp==30,"walnut basic accelerates real KO and deals no damage")
	gs=game();check(gs.basic_attack(0,1) and gs.player(1).avatarHp==28,"walnut basic without KO retains printed2 damage")
	gs=game();u=gs.player(0).units[1];ally=gs.player(0).units[2];gs._knockout_unit(ally,1,0);gs._resolve_resolution_stack();ally.knockout=1
	check(gs.basic_attack(0,1) and ally.hp==ally.maxHp and gs.player(1).avatarHp==30,"KO reaches zero revives but original basic attack still no damage")
	gs=game();u=gs.player(0).units[1];ally=gs.player(0).units[2];ally.hp=1
	play(gs,"c26701",ally.uid);check(u.attack==2 and u.maxHp==6 and ally.hp==4 and u.rwProtectedUid==ally.uid,"shelter exact2/6 binds actual selected ally and heals3")
	gs._knockout_unit(ally,1,0);gs._resolve_resolution_stack();ko=int(ally.knockout);RW.turn_start(gs,0,1)
	check(ally.knockout==ko-1,"shelter same bound ally switches to KO acceleration")
	gs=game();ally=gs.player(0).units[2];gs._knockout_unit(ally,1,0);gs._resolve_resolution_stack();ko=int(ally.knockout)
	play(gs,"c26701",ally.uid);check(ally.knockout==ko-1,"shelter selectable KO target at entry")
	gs=game();play(gs,"c26702");play(gs,"c26702");var marked:Array=gs.player(1).units.filter(func(t):return t.has("rwBounties"))
	var total:=0
	for t in marked:total+=t.rwBounties.size()
	check(total==2,"bounty records two actual marks")
	var deck:=int(gs.player(0).deck.size());var draws:int=marked[0].rwBounties.size()*2
	gs._knockout_unit(marked[0],0,0);gs._resolve_resolution_stack();check(gs.player(0).deck.size()==deck-draws and not marked[0].has("rwBounties"),"marked KO really draws2 per mark then removes marks")
	gs=game();play(gs,"c26707");u=gs.player(0).units[1];ally=gs.player(0).units[2];gs._knockout_unit(ally,1,0);gs._resolve_resolution_stack()
	check(u.swift and u.attack==4 and u.maxHp==7 and gs.basic_attack(0,1),"walnut awakening2/2 swift deploy")
	check(ally.hp==ally.maxHp and gs.player(1).avatarHp==26,"awake attack revives all KO and retains combat damage")
	gs=game();play(gs,"c26703");u=gs.player(0).units[1];check(u.attack==4 and u.maxHp==7,"parry exact4/7 form")
	gs.player(0).units[2].formRules={"alwaysSix":true};gs.player(1).units[0].front=1;gs._grow_unit(gs.player(1).units[0],0,20);var hp:=int(gs.player(1).units[0].hp)
	check(gs.basic_attack(0,1),"actual parry attack");check(gs.player(1).units[0].hp==hp-7 and evt(gs,"fortune-result").size()==1,"successful attack parry3 precedes combat4")
	gs=game();play(gs,"c26703");u=gs.player(0).units[1];u.front=1;gs.player(0).units[2].formRules={"alwaysSix":true}
	var enemy:Dictionary=gs.player(1).units[0];check(gs.end_turn(0),"switch to enemy before charging")
	gs.player(1).levelUpUsed=true
	check(CP.store_copy(gs,1,0,Content.card_def("c10101"),null),"real enemy charging")
	check(gs.basic_attack(1,0),"real charged attacker meets defending parry")
	check(enemy.hp==0 and u.hp==7 and evt(gs,"fortune-result").size()==1,"parry destroys actual charging attacker before damage")
func realms_and_items() -> void:
	var gs:=game();var p:Dictionary=gs.player(0)
	play(gs,"c26705");check(p.realms[0].hp==8 and p.units.all(func(t):return t.shield==2),"pure realm entry converts full-health overflow to2armor")
	p.realms[0].hp=3
	for t in gs._all_units():t.shield=0
	var hp: Array=gs._all_units().map(func(t):return int(t.hp));gs._trigger_realms(0);gs._resolve_resolution_stack()
	check(p.realms.is_empty(),"low pure realm truly destroys itself")
	for i in hp.size():check(gs._all_units()[i].hp==hp[i]-2,"pure detonation damages both sides shikigami "+str(i))
	gs=game();p=gs.player(0);play(gs,"c26706");check(p.realms[0].hp==6,"earth realm exact durability6")
	var initial:=evt(gs,"damage-resolved").size()
	for t in gs.player(1).units:gs._knockout_unit(t,0,0)
	gs._resolve_resolution_stack();gs._trigger_realms(0);gs._resolve_resolution_stack();check(evt(gs,"damage-resolved").size()==initial,"earth pool includes all KO, cannot damage or retarget living inventively")
	for turn in [4,5]:
		gs=game();p=gs.player(0);p.turnsTaken=turn;play(gs,"c26704");var e:Dictionary=evt(gs,"rw-loot-item").back();check(e.multiplier==(2 if turn==5 else 1),"loot fifth own turn threshold "+str(turn))
		if not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,0),"AI resolves genuine loot divination")
	for scale in [1,2]:
		for item in RW.OFFENSE+RW.SUPPORT:
			gs=game();p=gs.player(0);p.turnsTaken=10 if scale==2 else 9;p.avatarHp=10
			play(gs,"c26708");check(gs.pending_choice.type=="rw-items" and gs.pending_choice.multiplier==scale,"hurricane threshold9/10")
			var stage:=0 if item in RW.OFFENSE else 1
			if stage==1:check(gs.resolve_divination_choice(0,"rw-flame"),"first choice resolves before support")
			var before: Array=p.units.map(func(t):return [int(t.attack),int(t.maxHp)])
			check(gs.resolve_divination_choice(0,item),"real item choice "+item)
			match item:
				"rw-bees":check(gs.player(1).avatarHp==30-5*scale,"five/ten distinct projectile packets")
				"rw-wheel":check(gs.player(1).avatarHp==30-2-2*scale and p.units[1].attack==2+2*scale,"wheel permanent-until-KO2/4power and actual immune attack")
				"rw-weapon","rw-armor":
					for i in p.units.size():check(p.units[i].attack==before[i][0]+(2*scale if item=="rw-weapon" else 0) and p.units[i].maxHp==before[i][1]+(3*scale if item=="rw-armor" else 0),"actual team permanent item "+item)
				"rw-rebirth":check(p.avatarHp==10+6*scale,"real avatar healing6/12")
				"rw-flame":check(gs.player(1).units[0].hp==gs.player(1).units[0].maxHp-2*scale,"actual enemy AoE2/4")
			while not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,0),"AI resolves remaining item choice")
func split_and_sources() -> void:
	var gs:=game();var enemy:Dictionary=gs.player(1).units[0]
	enemy.barrier=true;var hp:int=enemy.hp
	charge(gs,"c26602",enemy.uid);release_now(gs,0)
	check(not enemy.barrier and enemy.hp==hp-2,"shot is real3 then extra2; first packet barrier cannot absorb second")
	var hits:Array=evt(gs,"damage-resolved").filter(func(e):return e.card.get("id","")=="c26602")
	check(hits.size()==2 and int(hits[0].amount)==0 and int(hits[1].amount)==2,"separate shot events preserve source and packet order")
	gs=game();var u:Dictionary=gs.player(0).units[1]
	var ally:Dictionary=gs.player(0).units[2];gs._knockout_unit(ally,1,0);gs._resolve_resolution_stack()
	enemy=gs.player(1).units[0];enemy.front=1;enemy.armorBreak=5;enemy.shield=2;enemy.barrier=true
	var avatar_hp:int=gs.player(1).avatarHp;hp=enemy.hp
	u.keywords=["pierce","penetration"]
	check(gs.basic_attack(0,1),"actual walnut deployment with KO and combat modifiers")
	check(enemy.hp==hp and enemy.shield==2 and enemy.armorBreak==5 and enemy.barrier and gs.player(1).avatarHp==avatar_hp,"noDamage prevents protection stripping, armor-break consumption and piercing spill")
	gs=sleeve_game();enemy=gs.player(1).units[0];gs._grow_unit(enemy,0,20);hp=enemy.hp
	charge(gs,"c26602",enemy.uid);release_now(gs,0)
	check(enemy.hp==hp-5 and gs.player(1).avatarHp==28,"sleeve boosts Ning base1→2, not normal shot3+2")
	gs=sleeve_game();charge(gs,"c26601");release_now(gs,0)
	hits=evt(gs,"damage-resolved").filter(func(e):return e.card.get("id","")=="c26601")
	check(hits.size()==1 and int(hits[0].amount)==3,"charged form entry damage3 is form source, not base aura damage4")
	gs=sleeve_game();play(gs,"c26703");gs.player(0).units[3].formRules={"alwaysSix":true}
	enemy=gs.player(1).units[0];enemy.front=1;gs._grow_unit(enemy,0,20);hp=enemy.hp
	check(gs.basic_attack(0,1),"real parry with awakened sleeve ally")
	hits=evt(gs,"damage-resolved").filter(func(e):return e.card.get("id","")=="c26703")
	check(hits.size()==1 and int(hits[0].amount)==3 and enemy.hp==hp-7,"parry form has exact3 plus4combat, cannot inherit sleeve base bonus")
	gs=sleeve_game();play(gs,"c26708");check(gs.resolve_divination_choice(0,"rw-bees"),"actual item projectiles under sleeve aura")
	check(gs.player(1).avatarHp==25,"five ordinary spell projectiles remain1 each under base aura")
	hits=evt(gs,"damage-resolved").filter(func(e):return e.card.get("id","")=="c26708")
	check(hits.size()==5 and hits.all(func(e):return int(e.amount)==1),"item projectiles retain original spell context across choice")
	check(gs.resolve_divination_choice(0,"rw-weapon"),"finish real support choice")
	gs=sleeve_game();play(gs,"c26606");enemy=gs.player(1).units[0];enemy.front=1;gs._grow_unit(enemy,0,20);hp=enemy.hp
	check(gs.basic_attack(0,0),"phoenix replaces deployment under sleeve aura")
	release_now(gs,0)
	check(enemy.hp==hp-8,"sword-aura combat3 and spell post3 stay exact; base1 alone gets+1")
	gs=sleeve_game();play(gs,"c26607");charge(gs,"c26602",gs.player(1).units[0].uid)
	check(gs.player(1).avatarHp==27 and gs.player(1).avatarFrozen>0,"awake Ning storage projectile2→3 with real stun")
func sleeve_game() -> GS:
	var gs:=GS.create(["ninghongye","tayumenhutao","xiaoxiuzhishou","rihefang"],["bingyong","yaodaoji","fenghuanghuo","baizangzhu"],266296)
	for p in gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	play(gs,"c29608")
	for t in gs.player(1).units:t.hp=int(t.maxHp);t.knockout=0;t.shield=0
	gs.player(1).avatarHp=30;gs.player(1).avatarFrozen=0
	gs.rule_events.clear();return gs

func loot_pool_and_permanence() -> void:
	for scale in [1,2]:
		for item in 5:
			var gs:=game();var p:Dictionary=gs.player(0);p.turnsTaken=4 if scale==1 else 5;p.avatarHp=20;p.avatarArmor=0
			var attack:int=0;var life:int=0
			for u in p.units:attack+=int(u.attack);life+=int(u.maxHp);u.shield=0
			var state:int=1
			while ((state*1664525+1013904223)&0xffffffff)%5!=item:state+=1
			gs.rng_state=state;gs._deploy_realm(0,Content.card_def("c26704"));gs._trigger_realms(0);gs._resolve_resolution_stack()
			check(int(evt(gs,"rw-loot-item").back().item)==item,"actual deterministic loot selects printed item "+str(item))
			var after_attack:int=0;var after_life:int=0
			for u in p.units:after_attack+=int(u.attack);after_life+=int(u.maxHp)
			match item:
				0:check(after_attack==attack+scale and after_life==life,"weapon loot grows only one real ally's power")
				1:check(after_attack==attack and after_life==life+scale,"armor loot grows only one real ally's life")
				2:check(p.avatarHp==20+2*scale,"blood pellet loot heals actual avatar")
				3:check(p.avatarArmor==scale and p.units.all(func(u):return int(u.shield)==scale),"powder loot grants armor to all allied characters")
				4:
					var deck:int=p.deck.size();check(gs.pending_choice.get("count")==scale,"supply box opens real divination with doubled count")
					while not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,0),"resolve actual supply-box divination")
					check(p.deck.size()==deck,"supply-box divination never invents a draw")
	var gs:=game();var p:Dictionary=gs.player(0);var old_attack:int=p.units[0].attack;var old_life:int=p.units[0].maxHp
	play(gs,"c26708");check(gs.resolve_divination_choice(0,"rw-flame") and gs.resolve_divination_choice(0,"rw-weapon"),"real permanent power support")
	gs._knockout_unit(p.units[0],1,0);gs._resolve_resolution_stack();gs.VerifiedRules.Peach.revive(gs,0,3,p.units[0],false,false)
	check(p.units[0].attack==old_attack+2,"weapon permanent growth survives actual KO and revival")
	play(gs,"c26708");check(gs.resolve_divination_choice(0,"rw-flame") and gs.resolve_divination_choice(0,"rw-armor"),"real permanent life support")
	gs._knockout_unit(p.units[0],1,0);gs._resolve_resolution_stack();gs.VerifiedRules.Peach.revive(gs,0,3,p.units[0],false,false)
	check(p.units[0].attack==old_attack+2 and p.units[0].maxHp==old_life+3,"permanent life and prior permanent power both survive revival")

func realm_ordering() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);var ally:Dictionary=p.units[2]
	gs._deploy_realm(0,Content.card_def("c26705"));gs._deploy_realm(0,Content.card_def("c26705"));p.realms[1].hp=3
	ally.hp=1;var top:Dictionary=p.realms[0]
	check(not gs._trigger_realms(0),"two same-source realms finish without pending choice");gs._resolve_resolution_stack()
	check(ally.hp==1 and p.realms.size()==1 and p.realms[0].uid==top.uid,"first realm heals before later realm detonates; installed identity survives")
	gs=GS.create(["ninghongye","tayumenhutao","yuanjiulanghu","rihefang"],["bingyong","yaodaoji","fenghuanghuo","baizangzhu"],267205)
	for side in gs.players:
		side.hand.clear();side.energy=40;side.levelUpUsed=true
		for unit in side.units:unit.level=3
	p=gs.player(0);ally=p.units[1];gs._grow_unit(ally,0,4)
	for unit in p.units:unit.hp=1
	ally.hp=5
	gs._deploy_realm(0,Content.card_def("c26705"));gs._deploy_realm(0,Content.card_def("c20506"))
	var deck:int=p.deck.size();gs._trigger_realms(0);gs._resolve_resolution_stack()
	check(ally.hp==7 and p.deck.size()==deck-1,"RW heal completes before later RedPurple observes greatest current life")
	p.realms.reverse()
	for unit in p.units:unit.hp=1
	ally.hp=5;deck=p.deck.size();gs._trigger_realms(0);gs._resolve_resolution_stack()
	check(ally.hp==7 and p.deck.size()==deck,"reversing installation makes RedPurple observe pre-heal life and skip draw")
	gs=game();p=gs.player(0);ally=p.units[2]
	play(gs,"c26701",ally.uid);ally.hp=1
	gs._deploy_realm(0,Content.card_def("c26704"));gs._deploy_realm(0,Content.card_def("c26706"))
	check(gs.end_turn(0),"enter enemy turn before real owner-start pause")
	for unit in gs.player(1).units:gs._grow_unit(unit,0,20)
	var total:int=0
	for unit in gs.player(1).units:total+=int(unit.hp)
	deck=p.deck.size()
	# Pick the deterministic fifth loot result without changing the production RNG.
	var state:int=1
	while ((state*1664525+1013904223)&0xffffffff)%5!=4:state+=1
	gs.rng_state=state
	check(gs.end_turn(1) and gs.pending_choice.get("type")=="native-divination","real turn start pauses on first loot realm's divination")
	var paused_total:int=0
	for unit in gs.player(1).units:paused_total+=int(unit.hp)
	check(p.deck.size()==deck and ally.hp==1 and paused_total==total,"while choice pending: later earth damage, shelter heal and natural draw all wait")
	check(gs.resolution_stack.any(func(f):return f.get("kind")=="realms-continue") and gs.resolution_stack.any(func(f):return f.get("kind")=="turn-after-realms"),"suspended state preserves later installed IDs and turn continuation")
	var selected:String=str(gs.pending_choice.instanceIds[0])
	check(gs.resolve_divination_choice(0,selected) and gs.resolve_divination_choice(0,"divination-place-top"),"complete actual two-step loot divination")
	var final_total:int=0
	for unit in gs.player(1).units:final_total+=int(unit.hp)
	check(gs.pending_choice.is_empty() and final_total==total-4 and ally.hp==4 and p.deck.size()==deck-1,"after choice: earth damage then shelter heal then exactly one natural draw")
	check(gs.resolution_stack.is_empty() and gs.phase=="main","resumed start phase drains all continuation frames")

func ai_and_saves() -> void:
	for number in [266,267]:
		for n in range(1,9):
			var gs:=game();var id:="c%d%02d"%[number,n];give(gs,id)
			var best:Dictionary=AI._best_card(gs,0);check(best.ok and gs.can_play_card(0,best.hand,best.target).ok,"AI legal target "+id)
			check(best.ok and gs.play_card(0,best.hand,best.target),"AI actual execution "+id)
			while not gs.pending_choice.is_empty():check(AI._resolve_choice(gs,0),"AI actual choice "+id)
	var gs:=game();play(gs,"c26708");check(gs.resolve_divination_choice(0,"rw-bees"),"first item before snapshot")
	var restored:=GS.new();var payload:Dictionary=JSON.parse_string(JSON.stringify({"players":gs.players,"choice":gs.pending_choice,"stack":gs.resolution_stack,"rules":gs.rules,"next":gs.next_card_id,"rng":gs.rng_state}))
	restored.players=payload.players;restored.pending_choice=payload.choice;restored.resolution_stack=payload.stack;restored.rules=payload.rules;restored.next_card_id=int(payload.next);restored.rng_state=int(payload.rng);restored.phase="choice"
	var before:int=restored.player(0).units[0].attack
	check(restored.resolve_divination_choice(0,"rw-weapon") and restored.pending_choice.is_empty() and restored.player(0).units[0].attack==before+2,"JSON-roundtrip pending item state resumes same second effect")
	check(gs.pending_choice.stage==1 and gs.pending_choice.instanceIds==RW.SUPPORT,"support choice remains serialized between effects")
	check(not gs.resolve_divination_choice(1,"rw-weapon") and not gs.resolve_divination_choice(0,"rw-bees"),"wrong owner and prior-stage choice rejected")
func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical;DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["ninghongye","tayumenhutao","rihefang","taohuayao"],["bingyong","yaodaoji","fenghuanghuo","baizangzhu"],266267);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=40;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.3).timeout;await settled(b)
		hand(b,["c26701"]);b.gs._knockout_unit(b.gs.player(0).units[2],1,0);b.gs._resolve_resolution_stack();b._refresh();await settled(b)
		await click(b._hand_row.get_child(0));await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(b.gs.player(0).units[2].uid).selected,"native shelter exposes genuine KO target")
		await capture("%d-01-shelter-target"%physical.x);await click(b._unit_widget(b.gs.player(0).units[2].uid));await settled(b)
		check(b.gs.player(0).units[1].get("rwProtectedUid","")==b.gs.player(0).units[2].uid,"native shelter binds selected KO entity")
		hand(b,["c26708"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		check(b.gs.pending_choice.get("type")=="rw-items" and choice_face(b,"rw-bees")!=null,"native hurricane shows offensive items")
		await capture("%d-02-hurricane-offense"%physical.x);await click(choice_face(b,"rw-bees"));await settled(b)
		check(b.gs.pending_choice.get("stage")==1 and choice_face(b,"rw-weapon")!=null,"native second choice follows actual projectiles")
		await capture("%d-03-hurricane-support"%physical.x);await click(choice_face(b,"rw-weapon"));await settled(b)
		check(b.gs.pending_choice.is_empty() and b.gs.player(0).units[0].attack==5,"native support applies permanent weapon and closes choice")
		hand(b,["c26602"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		var store:Control=null
		for f in faces(b._choice_layer):
			if f.data.get("currentCardStats","")=="蓄力使用":store=f
		check(store!=null,"native rednight charge/use choice exists");await click(store);await settled(b);await click(b._unit_widget(b.gs.player(1).units[0].uid));await settled(b)
		check(b.gs.player(0).units[0].has("lanternStored") and b.gs.player(0).units[0].lanternStored.targetId==b.gs.player(1).units[0].uid,"native stores actual selected shot target")
		await capture("%d-04-rednight-stored"%physical.x)
		b.queue_free();await process_frame;await process_frame
	for number in [266,267]:
		for n in range(1,9):
			var tile:=preload("res://scripts/ui/card_face.gd").new();var id:="c%d%02d"%[number,n];tile.data=Content.card_def(id);tile.refresh_art()
			check(tile._original_card!=null and tile._original_card.resource_path=="res://assets/official/cards/%s.png"%id,"actual original card texture "+id);tile.free()
func run() -> void:
	var stores:=Support.isolate_stores();var args:=OS.get_cmdline_user_args();var only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"):out=str(arg)
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme();rednight_cards();walnut_cards();realms_and_items();split_and_sources();loot_pool_and_permanence();realm_ordering();ai_and_saves()
	if not only:await ui_rules()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("REDNIGHT_WALNUT_OK checks=%d failures=%d rules_only=%s"%[checks,failures,only]);quit(0 if failures==0 else 1)
