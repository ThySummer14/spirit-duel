extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
const EF := preload("res://scripts/essence_feast_rules.gd")
const Food := preload("res://scripts/cooking_rules.gd")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("ESSENCE_FEAST_FAIL ",message)
func game() -> GS:
	var gs:=GS.create(["fenpopo","jiao","fansi","shantong"],["yaoginshi","bingyong","bailang","hetong"],603606638)
	for side in gs.players:
		side.hand.clear();side.energy=60;side.levelUpUsed=true
		for u in side.units:u.level=3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"ef-test-%d"%gs.next_card_id});gs.next_card_id+=1;return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,owner: int=0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)
func resolve(gs) -> void:
	gs._resolve_resolution_stack();check(gs.resolution_stack.is_empty() and gs.pending_choice.is_empty(),"stack fully resolves")
func tough(gs) -> void:
	for u in gs.player(1).units:gs._grow_unit(u,0,40)
func total(gs, owner: int = 1) -> int:
	var n:int=gs.player(owner).avatarHp
	for u in gs.player(owner).units:n+=int(u.hp)
	return n
func essence() -> void:
	var gs:=game();var p:Dictionary=gs.player(0)
	EF.gain_essence(gs,0,12)
	check(p.hand.size()==2 and p.hand[0].efStacks==10 and p.hand[1].efStacks==2,"real essence stacks10 then creates remainder2")
	var card:Dictionary=gs.hand_card_def(0,0)
	check(card.unitId=="" and card.neutralEssence and card.level==0 and card.cost==1 and card.keywords.has("instant"),"real neutral1fee instant card projection")
	gs._knockout_unit(p.units[0]);p.avatarHp=20;var deck:int=p.deck.size()
	check(gs.play_card(0,0,"avatar-0"),"neutral essence remains usable after former generator knockout")
	check(p.avatarHp==30 and p.deck.size()==deck and p.energy==60 and p.hand.size()==1,"stack10 heals10, consumes one instance, no invented draw")
	check(gs.play_card(0,0,p.units[2].uid) and p.energy==59,"second instant in same turn costs1 and can heal shikigami")
	gs=game();p=gs.player(0);EF.gain_essence(gs,0,1);give(gs,"c12807",1);var hp:int=p.units[2].hp;p.units[2].hp-=2;hp-=2
	check(gs.play_card(0,0,p.units[2].uid),"essence enters real counter pipeline")
	check(p.units[2].hp==hp and gs.player(1).hand.is_empty(),"opponent magic counter cancels actual neutral effect")
	gs=game();p=gs.player(0);EF.gain_essence(gs,0,9)
	for _i in 11:give(gs,"c60301")
	EF.gain_essence(gs,0,2)
	check(p.hand.size()==12 and p.hand[0].efStacks==10,"stacking first works in full hand and overflow newinstance burns")
func powder() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);tough(gs);gs.player(1).units[3].front=1
	var hp:int=gs.player(1).units[3].hp;gs._heal_avatar(0,3);resolve(gs)
	check(gs.player(1).units[3].hp==hp-2,"full life actual excess triggers base projectile2")
	gs._heal_unit(p.units[0],2);resolve(gs);check(gs.player(1).units[3].hp==hp-2,"same-turn powder/you excess shares base once limit")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c60302");var before:=total(gs);gs._heal_avatar(0,2);resolve(gs)
	check(total(gs)==before-4,"paint shape and base independent once-per-turn real2+2")
	gs=game();p=gs.player(0);play(gs,"c60304");check(p.hand.any(func(i):return i.definitionId=="shengmingjinghua"),"powder box form entering obtains true essence")
	gs._heal_avatar(0,1);resolve(gs);var box:Dictionary=gs.front_unit(0)
	check(box.get("efPowderBoxSummon",false) and box.attack==3 and box.hp==3,"overheal summons actual3/3 box")
	check(gs.end_turn(0) and gs.end_turn(1),"real turn resets box use")
	p.levelUpUsed=true;gs._heal_avatar(0,1);resolve(gs);box=gs.front_unit(0)
	check(box.attack==6 and box.maxHp==6 and box.hp==6,"real box fusion combines bodies")
	gs=game();p=gs.player(0);gs._knockout_unit(p.units[0]);play(gs,"c60303",p.units[0].uid)
	check(p.units[0].hp==p.units[0].maxHp and p.hand.size()==1 and p.hand[0].efStacks==2,"knocked-out source can revive itself and obtain2stack essence")
	gs=game();p=gs.player(0);tough(gs);p.units[0].level=1;var target:Dictionary=gs.player(1).units[3];hp=target.hp;play(gs,"c60307",target.uid)
	check(target.hp==hp-2 and p.hand[0].efStacks==2,"snow underlevel automatically uses2damage2essence trick")
	gs=game();p=gs.player(0);tough(gs);give(gs,"c60308");p.avatarHp=20;gs._heal_avatar(0,5);resolve(gs)
	check(p.units[0].awakened and not p.hand.any(func(i):return i.definitionId=="c60308"),"actual5recovery automatically uses real awakening instance")
	check(p.units[0].attack==5 and p.units[0].maxHp==6,"printed powder awakening2/2 exact")
	check(not gs.can_play_card(0,give(gs,"c60308")).ok,"duplicate real awakening rejected")
	gs=game();p=gs.player(0);p.units[0].hp=1;give(gs,"c60308");gs._heal_unit(p.units[0],5);resolve(gs)
	check(not p.units[0].awakened,"restoring powder5 is not restoring player5 for auto-awakening")
func pearl() -> void:
	var gs:=game();var p:Dictionary=gs.player(0)
	gs._damage_avatar(0,1,1,0);gs._damage_avatar(0,1,1,0);resolve(gs)
	check(int(p.efDamagePackets)==2 and p.hand.size()==1 and p.hand[0].efStacks==1,"pearl base once per turn while actual damage history counts every packet")
	play(gs,"c60603");var hp:int=p.units[1].hp;var avatar:int=p.avatarHp
	gs._damage_unit(0,1,3,1,0);resolve(gs)
	check(p.avatarHp==avatar-1 and p.units[1].hp==hp-2,"spring transfers exactly1 from actual3 packet")
	gs=game();p=gs.player(0);play(gs,"c60607");var allhp:int=total(gs,0)+total(gs,1);hp=p.units[1].hp
	gs._damage_unit(0,1,4,1,0);resolve(gs)
	check(total(gs,0)+total(gs,1)==allhp-4 and p.units[1].hp==hp and p.units[1].efPearlSplitTurn==gs.turn_counter,"pearl tear splits real packet without losing or duplicating points")
	gs=game();p=gs.player(0);gs._knockout_unit(p.units[3]);play(gs,"c60604");check(p.units[1].front==1 and p.hand[0].efStacks==3,"moist realm moves pearl front and gains3 essence")
	var attack:int=p.units[0].attack;gs._damage_avatar(0,1,1,0);resolve(gs)
	check(p.units[0].attack==attack+1 and p.units[3].knockout==1,"moist actual player hit buffs living and reduces knocked countdown")
	gs=game();p=gs.player(0);tough(gs)
	for _i in 4:gs._damage_avatar(0,1,1,0)
	var target:Dictionary=gs.player(1).units[3];hp=target.hp;play(gs,"c60606",target.uid)
	check(target.hp==hp-4,"water bullet uses actual global packet count")
	gs=game();p=gs.player(0);p.units[1].level=1;tough(gs);target=gs.player(1).units[3];hp=target.hp;play(gs,"c60606",target.uid)
	check(target.hp==hp-3,"water bullet underlevel uses fixed3 trick")
	gs=game();p=gs.player(0);gs._knockout_unit(p.units[3]);avatar=p.avatarHp;play(gs,"c60602",p.units[3].uid)
	check(p.units[3].hp==p.units[3].maxHp and p.avatarHp==avatar-p.units[3].hp,"bright pearl revives then pays actual revived life as damage")

	gs=game();p=gs.player(0);tough(gs)
	var foe := gs.player(1)
	foe.units[0].front = 1
	foe.units[0].baseAttack = 4
	gs._recalc(foe.units[0])
	var summon := gs._make_unit("ordinary-pearl-summon", "shantong")
	summon.summoned = true
	summon.countsAsShikigami = false
	summon.level = 0
	gs._grow_unit(summon, 0, 8)
	foe.units.append(summon)
	var bullet := give(gs, "c60606")
	check(not gs.can_play_card(0, bullet, summon.uid).ok, "水花弹的式神目标排除普通召唤物")
	hp = int(p.units[1].hp)
	var summon_hp := int(summon.hp)
	play(gs, "c60608", summon.uid)
	check(int(p.units[1].hp) == hp and int(summon.hp) == summon_hp - 4, "借水扬波把战斗反击伤害转移到所选敌方普通召唤物")
	EF.gain_essence(gs, 0, 2)
	var essence_index: int = p.hand.find_custom(func(inst): return inst.definitionId == "shengmingjinghua")
	var can_heal := gs.can_play_card(0, essence_index, summon.uid)
	check(can_heal.ok, "普通召唤物是生命精华的合法角色：" + str(can_heal.reason))
	var heal_stacks := int(p.hand[essence_index].efStacks)
	check(gs.play_card(0, essence_index, summon.uid) and int(summon.hp) == mini(summon_hp, summon_hp - 4 + heal_stacks), "生命精华实际恢复普通召唤物生命，层数 %d，当前生命 %d" % [heal_stacks, int(summon.hp)])
func feast() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);tough(gs);var u:Dictionary=p.units[2]
	Food.gain_ingredient(gs,0,0,"sea");check(gs.play_card(0,0,u.uid),"actual neutral food targets Fansi")
	check(int(u.efSatiety)==2 and u.attack==5 and int(p.efFansiTargetCount)==1,"neutral hand food gives2 satiety and unique-target history")
	EF.gain_essence(gs,0,1);check(gs.play_card(0,0,u.uid),"actual essence targets Fansi")
	check(int(u.efSatiety)==4 and u.attack==7,"neutral essence counted as second real2satiety")
	EF.gain_essence(gs,0,1);check(gs.play_card(0,0,u.uid),"third neutral food remains actual instance")
	check(int(u.efSatiety)==5 and u.attack==8,"satiety caps5 without raising maxHP")
	var fi:Dictionary=gs.player(1).units[3];fi.front=1;fi.baseAttack=0;gs._recalc(fi);var hp:int=fi.hp
	check(gs.basic_attack(0,2),"Fansi actual attack")
	check(fi.hp==hp-8 and int(u.get("efSatiety",0))==0 and u.attack==3,"combat damage uses satiety then removes all charm boost")
	gs=game();p=gs.player(0);u=p.units[2];tough(gs);play(gs,"c63808");EF.clear_satiety(gs,u);var attack:int=u.attack;var maxhp:int=u.maxHp
	Food.gain_ingredient(gs,0,0,"mountain");check(gs.play_card(0,0,u.uid),"awake fansi consumes actual food")
	check(u.attack==attack+7 and u.maxHp==maxhp+2 and u.efSatiety==2,"awake target2/2 plus food3power plus2satiety remain distinct ledgers")
	gs=game();p=gs.player(0);u=p.units[2];u.level=1;play(gs,"c63808")
	check(not u.awakened and p.hand.size()==2 and p.hand.any(func(i):return i.definitionId=="shengmingjinghua") and p.hand.any(func(i):return Food.food_kind(i)=="ingredient"),"awake card underlevel uses randomfood+essence trick only")
	gs=game();p=gs.player(0);u=p.units[2];tough(gs);play(gs,"c63802")
	var before_fire:int=p.energy;var before_enemy:int=gs.player(1).avatarHp
	check(gs.basic_attack(0,2) and p.energy==before_fire and gs.front_index(0)==2 and gs.player(1).avatarHp==before_enemy,"Moon chef actual guard action is free entry without attacking")
	EF.gain_essence(gs,0,1);check(gs.play_card(0,0,u.uid),"target history before leap")
	var h:=give(gs,"c63804");check(gs.hand_card_def(0,h).get("enhanced",false) and gs.valid_targets(0,gs.hand_card_def(0,h)).has(gs.player(1).units[3].uid),"enhanced flying leap opens actual reserve target")
	var energy:int=p.energy;hp=gs.player(1).units[3].hp;check(gs.play_card(0,h,gs.player(1).units[3].uid),"actual pursued leap")
	check(gs.player(1).units[3].hp<hp and p.energy==energy-1,"leap targets selected unit with real battle payment")
func target_and_copy() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);tough(gs);var u:Dictionary=p.units[2]
	EF.gain_essence(gs,0,1);check(gs.play_card(0,0,u.uid),"prime actual hand target history")
	var foe:Dictionary=gs.player(1).units[3];foe.barrier=true;foe.baseAttack=0;gs._recalc(foe)
	play(gs,"c63804",foe.uid)
	check(u.get("efSatiety",0)==3 and p.efFansiTargetCount==2,"pursuit attack recipient is not a second logical card target; nutrition persists when barrier prevents damage")
	gs=game();p=gs.player(0);u=p.units[2];tough(gs);EF.gain_essence(gs,0,1);check(gs.play_card(0,0,p.units[3].uid),"prime other ally history")
	var count:int=p.get("efFansiTargetCount",0);play(gs,"c63807",p.units[3].uid)
	check(p.get("efFansiTargetCount",0)==count and not p.get("efTargetsTurn",[]).has(u.uid),"combat also commands selected other ally; two logical targets do not feed Fansi or mark caster")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c63808");u=p.units[2]
	var ally:Dictionary=p.units[3];var attack:int=ally.attack;var life:int=ally.maxHp;var owncount:int=p.efFansiTargetCount
	EF.gain_essence(gs,0,1);check(gs.play_card(0,0,ally.uid),"awake observer sees other allied sole target")
	check(ally.attack==attack+2 and ally.maxHp==life+2 and p.efFansiTargetCount==owncount,"awake gives2/2 to actual other ally without feeding Fansi")
	var generation:int=ally.efFeastGrowth;gs._knockout_unit(ally);gs.VerifiedRules.Peach.revive(gs,0,0,ally,false,false)
	check(ally.attack==attack and ally.maxHp==life and not ally.has("efFeastGrowth") and generation==2,"awake nonpermanent growth removes exactly once through real KO/revive")
	# Other roles' attack selection likewise targets the caster for card nutrition.
	var f:Dictionary={"sourceIndex":1,"targetId":gs.player(1).units[3].uid}
	check(EF.sole_target(gs,0,f,{"type":"combat","target":"enemy-unit","id":"other-pursuit"})==p.units[1].uid,"other role pursuit logical target is caster")
	check(EF.sole_target(gs,0,f,Content.card_def("c60608"))=="","borrow additionally redirects to selected enemy, so is not a sole allied target")
	var h:=give(gs,"c60307");check(gs.play_card(0,h,gs.player(1).units[3].uid),"enemy spell actual resolves")
	check(p.efFansiTargetCount==owncount,"enemy spell grants no friendly nutrition")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c63805");gs._knockout_unit(p.units[2]);gs._knockout_unit(p.units[3]);play(gs,"c60303",p.units[2].uid)
	check(p.units[2].hp>0 and p.units[3].hp>0,"meal copy happens after original revival and chooses remaining legal knocked ally")
	check(p.hand.size()==1 and p.hand[0].get("efStacks",0)==4,"original and real automatic revival copy each obtain2 essence")
	check(gs.resolution_stack.is_empty() and gs.pending_choice.is_empty(),"meal copy never recurses or leaves unresolved work")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c63806");u=p.units[2];p.hand.clear();var deck:int=p.deck.size();var fire:int=p.energy
	EF.gain_essence(gs,0,1);check(gs.play_card(0,0,u.uid),"divine form reacts to real essence targeting")
	check(u.swift and p.deck.size()==deck and p.energy==fire,"divine grants true turn swift without invented draw or fire")
	check(gs.end_turn(0) and not u.swift,"unused divine turn swift expires at actual turn end")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c60603");u=p.units[1];u.formRules.monkReduction=1;u.shield=1;var hp:int=u.hp;var avatar:int=p.avatarHp
	gs._damage_unit(0,1,5,1,0);resolve(gs)
	check(u.shield==0 and u.hp==hp-2 and p.avatarHp==avatar-1,"spring preserves armor and reduction exactly once before1point transfer")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c60603");u=p.units[1];hp=u.hp;p.avatarArmor=2;avatar=p.avatarHp
	gs._damage_unit(0,1,3,1,0);resolve(gs)
	check(u.hp==hp-2 and p.avatarHp==avatar and p.avatarArmor==1,"transferred1 uses recipient normal armor without restoring original residual")
	gs=GS.create(["fenpopo","jiao","fansi","shantong"],["fansi","bingyong","bailang","hetong"],7)
	for side in gs.players:
		side.hand.clear();side.energy=50;side.levelUpUsed=true
		for unit in side.units:unit.level=3
	EF.gain_satiety(gs,0,2,2);EF.gain_satiety(gs,1,0,4);gs._grow_unit(gs.player(1).units[3],0,40);gs.player(1).units[3].front=1
	check(gs.basic_attack(0,2),"actual combat with opposing Fansi ledgers")
	check(gs.player(0).units[2].get("efSatiety",0)==0 and gs.player(1).units[0].get("efSatiety",0)==4,"only actual damaging Fansi clears its own satiety")
func conditions() -> void:
	var gs:=game();var p:Dictionary=gs.player(0);tough(gs);var enemy:Dictionary=gs.player(1).units[0]
	play(gs,"c60301",enemy.uid);p.hand.clear();p.units[3].front=1;gs._grow_unit(p.units[3],0,20);gs.current_player=1
	check(gs.basic_attack(1,0),"heartbroken actual enemy basic attack")
	check(p.hand.size()==1 and p.hand[0].efStacks==1,"heartbroken attacker grants opposing player essence")
	play(gs,"c12801",null,1)
	check(p.hand[0].efStacks==2,"heartbroken actual card announcement grants another essence")
	gs=game();p=gs.player(0);tough(gs);p.units[1].hp-=1;p.units[3].hp-=2;play(gs,"c60305")
	check(p.units.all(func(u):return u.hp==u.maxHp) and p.hand.size()==1 and p.hand[0].efStacks==5,"group heal counts exact2+1+2+0 actual excess as5 stacked essence")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c60306");var fire:int=p.energy;gs._heal_unit(p.units[3],1);resolve(gs)
	check(p.energy==fire+1,"grudge realm actual allied excess grants1fire")
	gs._heal_unit(p.units[1],2);resolve(gs);gs._heal_avatar(0,2);resolve(gs)
	check(p.energy==fire+1,"grudge shared once per turn ignores second ally and avatar-only heal")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c60601");var before:=total(gs);gs._damage_avatar(0,1,1,0);resolve(gs);gs._damage_avatar(0,1,1,0);resolve(gs)
	check(total(gs)==before-1,"torrent independent once-per-turn projectile1 on actual avatar damage")
	gs=game();p=gs.player(0);tough(gs);play(gs,"c60605");p.hand.clear();gs._damage_avatar(0,5,1,0);resolve(gs)
	check(p.hand.size()==1 and p.hand[0].efStacks==3,"awake pearl gains ceil5/2 real essence stacks")
	p.units[0].level=1;p.avatarHp=20;var deck:int=p.deck.size();gs._heal_avatar(0,4);resolve(gs);check(p.deck.size()==deck,"awake pearl actual recovery4 does not draw")
	gs._heal_avatar(0,5);resolve(gs);check(p.deck.size()==deck-1,"awake pearl actual recovery5 draws one")
	gs=game();p=gs.player(0);tough(gs);enemy=gs.player(1).units[0];enemy.front=1;enemy.baseAttack=4;gs._recalc(enemy);var chosen:Dictionary=gs.player(1).units[3];chosen.shield=1;var hp:int=chosen.hp;var jiaohp:int=p.units[1].hp
	play(gs,"c60608",chosen.uid)
	check(p.units[1].hp==jiaohp and chosen.hp==hp-3 and chosen.shield==0 and not p.units[1].has("efBorrowTarget"),"borrow redirects all real counterattack into selected enemy normal protection then clears at combat end")
	gs=game();p=gs.player(0);tough(gs);p.units[1].level=1;enemy=gs.player(1).units[0];enemy.front=1;enemy.baseAttack=7;gs._recalc(enemy);jiaohp=p.units[1].hp;hp=enemy.hp;play(gs,"c60608")
	check(p.units[1].hp==jiaohp and enemy.hp<hp and not p.units[1].has("efBorrowTarget"),"borrow underlevel trick grants combat immunity with actual attack, no redirect recipient")
	for primed in [false,true]:
		gs=game();p=gs.player(0);tough(gs);var ally:Dictionary=p.units[3];gs._grow_unit(ally,0,20);enemy=gs.player(1).units[0];enemy.front=1;enemy.baseAttack=4;gs._recalc(enemy)
		if primed:EF.gain_essence(gs,0,1);check(gs.play_card(0,0,ally.uid),"prior hand selects appetite ally")
		var original:int=ally.hp;play(gs,"c63801",ally.uid)
		check(ally.hp==original if primed else ally.hp==original-4,"appetite immunity requires earlier other card, not its own announcement "+str(primed))
	gs=game();p=gs.player(0);tough(gs);var u:Dictionary=p.units[2];var h:=give(gs,"c63807")
	check(not gs.can_play_card(0,h,u.uid).ok and gs.valid_targets(0,gs.hand_card_def(0,h)).is_empty(),"stomach cannot create its own required earlier target history")
	p.hand.clear();EF.gain_essence(gs,0,1);check(gs.play_card(0,0,u.uid),"prime stomach self")
	h=give(gs,"c63807");var count:int=p.efFansiTargetCount;check(gs.play_card(0,h,u.uid),"stomach can choose previously marked caster itself")
	check(p.efFansiTargetCount==count+1,"stomach selected self is one logical target and feeds once")
	gs=game();p=gs.player(0);u=p.units[2]
	for _n in 6:EF.gain_essence(gs,0,1);check(gs.play_card(0,0,u.uid),"real neutral target increases enhancement history")
	h=give(gs,"c63803");var card:Dictionary=gs.hand_card_def(0,h)
	check(card.value==5 and card.combatOption.shield==1,"stored combat enhancement caps attack5 and keeps printed armor1")
	gs=game();p=gs.player(0);h=give(gs,"c63804");card=gs.hand_card_def(0,h)
	check(not card.get("enhanced",false) and card.target=="auto" and not card.keywords.has("pursuit") and not card.keywords.has("swift-card"),"unmarked leap has only printed pierce, no pursuit or removed swift")
func metadata_ai() -> void:
	for role_id in [603,606,638]:
		for n in range(1,9):
			var id:="c%d%02d"%[role_id,n];var gs:=game();var p:Dictionary=gs.player(0);tough(gs)
			check(Content.card_def(id).get("verifiedRules",false),"metadata reviewed "+id);check(ResourceLoader.exists("res://assets/official/cards/%s.png"%id),"complete original texture "+id)
			if id in ["c60303","c60602"]:gs._knockout_unit(p.units[3])
			if id=="c60606":gs._damage_avatar(0,1,1,0)
			if id=="c63807":
				EF.gain_essence(gs,0,1);check(gs.play_card(0,0,p.units[3].uid),"prime legal marked ally for actual stomach combat")
			var h:=give(gs,id);var c:Dictionary=gs.hand_card_def(0,h);var choices:Array=[null] if c.get("target","auto")=="auto" else gs.valid_targets(0,c)
			var target=null;var legal:=false
			for candidate in choices:
				if gs.can_play_card(0,h,candidate).ok and AI._score_card(gs,0,c,candidate)>0:target=candidate;legal=true;break
			check(legal,"AI has actual legal candidate "+id)
			if legal:
				check(gs.play_card(0,h,target),"all24 actual standard play "+id)
				check(gs.resolution_stack.is_empty() and gs.pending_choice.is_empty(),"all24 actual stack drain "+id)
			if c.type=="form":
				var u:Dictionary=p.units[gs._source_index(0,c)]
				check(int(u.baseAttack)+int(u.form.attackBonus)==int(c.value.attack) and int(u.baseMaxHp)+int(u.form.hpBonus)==int(c.value.hp),"printed form base stats replace body "+id)
func ui_checks() -> void:
	root.theme=ThemeBuilder.build_theme()
	for size in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=size
		DisplayServer.window_set_size(size)
		var b:=Battle.new();b.setup(["fenpopo","jiao","fansi","shantong"],["yaoginshi","bingyong","bailang","hetong"],603606638);b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear();side.energy=60;side.levelUpUsed=true
			for u in side.units:u.level=3
		root.add_child(b);await create_timer(0.4).timeout
		var gs=b.gs;var p:Dictionary=gs.player(0);EF.gain_essence(gs,0,4);p.avatarHp=20;b._refresh();await settled(b)
		await click(b._hand_row.get_child(0));check(b._pending_target_card==0,"native essence enters real role target "+str(size));await capture("%d-01-essence-target"%size.x)
		await click(b._ally_plate);await settled(b);check(p.avatarHp==24 and p.hand.is_empty(),"native actual stack4 heals4 with handconsumption")
		hand(b,["c60307"]);p.units[0].level=1;b._refresh();await settled(b);await click(b._hand_row.get_child(0));await click(b._unit_widget(str(gs.player(1).units[3].uid)));await settled(b)
		check(p.hand.size()==1 and p.hand[0].get("efStacks",0)==2,"native lowlevel trick produces exactly2essence");await capture("%d-02-trick-and-stack"%size.x)
		p.units[0].level=3;hand(b,["c63804"]);EF.gain_essence(gs,0,1);b._refresh();await settled(b);await click(b._hand_row.get_child(1));await click(b._unit_widget(str(p.units[2].uid)));await settled(b)
		await click(b._hand_row.get_child(0));check(b._pending_target_card==0 and gs.valid_targets(0,b._pending_target_card_def).has(gs.player(1).units[2].uid),"native enhanced pursuit permits reserve")
		await capture("%d-03-pursuit-target"%size.x);await click(b._unit_widget(str(gs.player(1).units[2].uid)));await settled(b)
		check(gs.resolution_stack.is_empty() and int(p.units[2].get("efSatiety",0))==0,"native target battle drains and clears satiety")
		var summon: Dictionary = gs._make_unit("native-essence-summon", "shantong")
		summon.summoned = true
		summon.countsAsShikigami = false
		summon.front = 1
		summon.hp = int(summon.maxHp) - 2
		for enemy in gs.player(1).units: enemy.front = 0
		gs.player(1).units.append(summon)
		hand(b, [])
		EF.gain_essence(gs, 0, 2)
		b._refresh()
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var widget := b._unit_widget(summon.uid)
		check(widget != null and b._pending_target_card == 0, "战斗界面可选择普通召唤物角色 " + str(size))
		if widget != null: await click(widget)
		await settled(b)
		check(int(summon.hp) == int(summon.maxHp) and p.hand.is_empty(), "鼠标选择普通召唤物后生命精华实际治疗并消费 " + str(size))
		b.queue_free();await process_frame;await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();essence();powder();pearl();feast();target_and_copy();conditions();metadata_ai()
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty() and args[0]!="--rules-only":out=args[0];DirAccess.make_dir_recursive_absolute(out)
	if not args.has("--rules-only"):await ui_checks()
	Support.cleanup_stores(stores);Support.cleanup_audio();await process_frame;await process_frame
	print("ESSENCE_FEAST checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
