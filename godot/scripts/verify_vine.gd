extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Vine := preload("res://scripts/vine_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("VINE_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["tengji","rulianshi","xiaosongwan","yanmo"],["yaodaoji","bingyong","xuenv","baizangzhu"],228)
	for p in gs.players:
		p.hand.clear(); p.energy=80; p.levelUpUsed=true
		for u in p.units: u.level=3
	# Opening owner-turn already applied the real base passive; isolate each
	# fixture by removing that initial charm without fabricating another turn.
	for owner in 2:
		for idx in gs.player(owner).units.size():
			if Vine.bonus(gs.player(owner).units[idx])>0: Vine.detach(gs,owner,idx)
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"vine-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actualcard "+id)
func phantom(gs) -> Dictionary:
	for u in gs.player(0).units:
		if u.get("vineSummon",false) and int(u.hp)>0 and not u.get("removed",false): return u
	return {}
func ncharms(gs, owner: int = 0) -> int:
	return gs.player(owner).units.filter(func(u):return not u.get("vineCharm",{}).is_empty()).size()
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func test_activation() -> void:
	var opening:=GS.create(["tengji","rulianshi","xiaosongwan","yanmo"],["yaodaoji","bingyong","xuenv","baizangzhu"],228)
	check(Vine.bonus(opening.player(0).units[0])==1 and opening.player(0).units[0].attack==2,"actualopeningownerturn triggersbaseexactlyonce")
	var gs:=game(); var u: Dictionary=gs.player(0).units[0]; u.level=0; Vine.turn_start(gs,0)
	check(not u.has("vineCharm"),"unactivatedsource cannotattach atownerstart")
	gs=game(); u=gs.player(0).units[0]; u.baseRulesSuppressed=true; Vine.turn_start(gs,0)
	check(not u.has("vineCharm"),"paper-suppressedsource cannotattach atownerstart")
	gs=game(); u=gs.player(0).units[0]; gs._knockout_unit(u); gs._resolve_resolution_stack(); Vine.turn_start(gs,0)
	check(not u.has("vineCharm") and u.hp==0,"knockedsource doesnot inventnewcharm orrevive")
func test_charm_stats() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(u.attack==1 and u.maxHp==1 and u.passive_hooks.is_empty(),"exact1/1 base oldpassive removed")
	Vine.attach(gs,0,0); check(u.attack==2 and u.hp==2 and u.maxHp==2 and Vine.bonus(u)==1,"actual+1/+1 resides onrealcharm")
	var first: String=u.vineCharm.uid; Vine.attach(gs,0,0)
	check(u.attack==3 and u.hp==3 and u.maxHp==3 and u.vineCharm.count==2 and u.vineCharm.uid!=first and ncharms(gs)==1,"newcharm physicallyfuses oldcount, onecarrier")
	Vine.attach(gs,0,1)
	check(not u.has("vineCharm") and u.attack==1 and u.hp==1 and p.units[1].attack==5 and p.units[1].hp==6 and ncharms(gs)==1,"newtarget receives entire3charm andold losesbonus")
	gs=game(); p=gs.player(0); u=p.units[0]; Vine.attach(gs,0,0); gs._damage_unit(0,0,1,1,0); Vine.attach(gs,0,0)
	check(u.attack==3 and u.maxHp==3 and u.hp==2,"samehostfusion adds onlynew1HP andpreservesactualwounds")
	gs=game(); p=gs.player(0); u=p.units[1]; Vine.attach(gs,0,1,7)
	gs._damage_unit(0,1,6,1,0); check(u.attack==9 and u.maxHp==10 and u.hp==4,"fixture woundpartlyoncharm")
	Vine.attach(gs,0,0)
	check(u.attack==2 and u.maxHp==3 and u.hp==3 and p.units[0].attack==9 and p.units[0].hp==9,"movingcharm keepsoldHP clipped tonewmax, restoresnew full8bonus")
	gs=game(); p=gs.player(0); u=p.units[1]; Vine.attach(gs,0,1,2); gs._damage_unit(0,1,4,1,0); Vine.attach(gs,0,0)
	check(u.hp==1 and u.maxHp==3,"oldwound beyondbonus persists, nodouble subtract")
	gs=game(); p=gs.player(0); Vine.attach(gs,0,0); gs.player(1).units[0].front=1
	var foehp: int=gs.player(1).units[0].hp; var card:=give(gs,"c22801")
	check(gs.can_play_card(0,card,p.units[1].uid).ok and not gs.can_play_card(0,card,gs.player(1).units[0].uid).ok,"violet legalallies andillegalenemy")
	check(gs.play_card(0,card,p.units[1].uid) and p.units[1].vineCharm.count==2 and gs.player(1).units[0].hp==foehp,"actualviolet movesgrowcharm withoutfakedamage")
func test_substitute_removal() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[1]
	play(gs,"c23604"); Vine.attach(gs,0,1,3); u.swift=true; u.enraged=true; var form: String=u.form.cardId
	gs._damage_unit(0,1,999,1,0)
	check(u.hp==5 and u.maxHp==5 and u.attack==3 and u.knockout==0 and u.form.cardId==form,"lethaldamage substitute stripscharm andheals underlyingform; nofalseKO")
	check(u.swift and u.enraged and events(gs,"vine-substitute")==1 and not u.has("vineCharm"),"substitute keepsliveform/status andconsumes exactlyonce")
	gs._damage_unit(0,1,999,1,0); gs._resolve_resolution_stack()
	check(u.hp==0 and u.knockout==2 and u.form.is_empty(),"secondlethal withoutcharm enters realKO")
	gs=game(); p=gs.player(0); u=p.units[1]; Vine.attach(gs,0,1,2); gs._knockout_unit(u)
	check(u.hp==3 and u.knockout==0 and not u.has("vineCharm"),"directdestroy also respectstruesubstitute")
	gs=game(); p=gs.player(0); u=p.units[1]; Vine.attach(gs,0,1,2); gs._damage_unit(0,1,4,1,0)
	Vine.remove_charm(gs,0,1,"test dispel")
	check(u.hp==1 and u.maxHp==3 and u.knockout==0,"explicitdispel isnot substitute-heal andkeepsactualwound")
	gs=game(); p=gs.player(0); play(gs,"c22802"); var v:=phantom(gs); var idx: int=gs._unit_index_by_uid(0,v.uid); var size: int=p.units.size(); var uid: String=v.uid
	check(v.baseAttack==0 and v.baseMaxHp==0 and v.attack==1 and v.hp==1 and v.maxHp==1 and not v.get("removed",false),"garden0/0 attachedbeforeentry nofakezeroHP death")
	gs._damage_unit(0,idx,999,1,0); gs._resolve_resolution_stack()
	check(v.removed and v.hp==0 and v.knockout==0 and p.units.size()==size and p.units[idx].uid==uid,"bare0/0 phantom reallydies aftersubstitute cannotfakeheal")
	check(Vine.bonus(p.units[0])==1 and p.units[0].hp==2 and ncharms(gs)==1,"garden returns removedsamecharm tosource exactlyonce")
	Vine.remove_summon(gs,0,v); check(Vine.bonus(p.units[0])==1,"removedphantomcallback idempotent")
	gs=game(); p=gs.player(0); play(gs,"c22802"); v=phantom(gs); idx=gs._unit_index_by_uid(0,v.uid)
	check(gs.VerifiedRules.Movement.move_to(gs,0,1,1),"actualfront replacement movesnormalally")
	check(v.removed and Vine.bonus(p.units[0])==1 and not v.has("weaverGrave"),"forceddeparture returnscharm butnotfakecorpse")
	gs=game(); p=gs.player(0); play(gs,"c22802"); play(gs,"c22804"); v=phantom(gs)
	check(v.vineCharm.count==4 and v.hp==4 and not p.units[0].has("vineCharm") and ncharms(gs)==1,"replacingphantom returnsoldcharm beforefresh3 fuses to4")
func test_cards_targets() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	var idx:=give(gs,"c22803"); var fire: int=p.energy
	check(not gs.can_play_card(0,idx,foe.units[1].uid).ok and p.energy==fire,"relief requiresrealfrontsummon beforecost")
	play(gs,"c22804"); var v:=phantom(gs); var c: Dictionary=gs.hand_card_def(0,idx)
	check(v.attack==3 and v.hp==3 and p.deck.size()>0,"weave actual0/0with3charm, nofakedraw")
	check(gs.valid_targets(0,c).has(p.units[1].uid) and gs.valid_targets(0,c).has(foe.units[1].uid) and not gs.valid_targets(0,c).has(v.uid),"relief permitsbothside actualnon-summon only")
	gs.VerifiedRules.Xuenv.summon_wall(gs,1,2); var wall: Dictionary=foe.units.back()
	check(not gs.valid_targets(0,c).has(wall.uid),"relief cannot targetenemy summons")
	foe.units[1].shield=100; gs._grow_unit(foe.units[1],0,50); check(gs.play_card(0,idx,foe.units[1].uid),"actualrelief harddestroyhightoughness")
	check(v.removed and v.hp==0 and foe.units[1].hp==0 and not v.has("weaverGrave"),"relief paysactualremoval cost andrealharddestroy")
	gs=game(); p=gs.player(0); foe=gs.player(1); var deck: int=p.deck.size(); play(gs,"c22806")
	check(phantom(gs).hp==1 and p.deck.size()==deck-1 and foe.units[0].hp==foe.units[0].maxHp,"mysterious withoutenemy summons stillsummon+draw nofakedamage")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs.VerifiedRules.Xuenv.summon_wall(gs,1,2); wall=foe.units.back(); deck=p.deck.size(); play(gs,"c22806")
	check(wall.removed and wall.hp==0 and phantom(gs).hp==1 and p.deck.size()==deck-1,"mysterious trueenemy summonKO beforeown summonanddraw")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._grow_unit(foe.units[1],5,7); gs._damage_unit(1,1,2,0,1)
	var atk: int=foe.units[1].attack; var hp: int=foe.units[1].hp; var maxhp: int=foe.units[1].maxHp
	play(gs,"c22807",foe.units[1].uid); v=phantom(gs)
	check(v.baseAttack==atk and v.baseMaxHp==hp and v.attack==atk+1 and v.maxHp==hp+1 and hp<maxhp,"phantomecho copiesactualATK/currentHP thencharm, notmaxHP")
	check(foe.units[1].hp==hp,"phantomecho doesnot damagecopytarget")
	var vi: int=gs._unit_index_by_uid(0,v.uid); gs._damage_unit(0,vi,999,1,0)
	check(v.hp==hp and v.maxHp==hp and not v.removed and not v.has("vineCharm"),"copiedbody phantom hasgenuine underlyingHP substitute")
	gs=game(); p=gs.player(0); foe=gs.player(1); foe.units[1].keywords=["veil"]; idx=give(gs,"c22807"); c=gs.hand_card_def(0,idx)
	check(not gs.valid_targets(0,c).has(foe.units[1].uid) and not gs.can_play_card(0,idx,foe.units[1].uid).ok,"echo respectsenemyveil beforepayment")
func test_base_awake_realms() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	check(gs.end_turn(0) and gs.end_turn(1),"actualturnsto firstnaturalcharm")
	p.levelUpUsed=true; check(Vine.bonus(u)==1 and u.attack==2,"naturalownerstart createsonecharm")
	check(gs.end_turn(0) and gs.end_turn(1),"actualsecondnaturalround")
	p.levelUpUsed=true; check(Vine.bonus(u)==2 and u.attack==3,"naturalstart fuses sameglobalcharm")
	play(gs,"c22805"); check(u.awakened and u.vineCharm.count==3 and u.baseAttack==1 and u.baseMaxHp==1,"awake actualattach3 nofakeselfstat")
	check(not gs.can_play_card(0,give(gs,"c22805")).ok,"secondawakeillegal")
	Vine.summon(gs,0,0); var v:=phantom(gs); var v_idx: int=gs._unit_index_by_uid(0,v.uid)
	# Find deterministic random fixture that selects the live summoned unit.
	for seed in 10000:
		var next: int=(seed*1664525+1013904223)&0xffffffff
		if next%5==v_idx: gs.rng_state=seed; break
	Vine.turn_start(gs,0)
	check(Vine.bonus(v)>0 and ncharms(gs)==1,"awake randompool includes realphantom")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c22808"); check(Vine.realm_count(gs,0)==1 and p.realms.back().hp==8,"millennium real8durability realm")
	var foe: Dictionary=gs.player(1); gs._grow_unit(foe.units[0],0,30); foe.units[0].front=1; var hp: int=foe.units[0].hp
	check(gs.basic_attack(0,1) and foe.units[0].hp==hp-3 and Vine.bonus(p.units[1])==1,"millennium grantscharm beforeactualbasicstrengthsnapshot")
	gs._heal_unit(p.units[1],30); gs._damage_unit(0,1,999,1,0); gs._resolve_resolution_stack()
	check(p.units[1].hp==3 and Vine.bonus(u)==1 and p.units[1].knockout==0,"millennium returnsremovedallycharm toTengji onsubstitute")
	var count: int=Vine.bonus(u); gs._resolve_combat(0,2,0,false,false,false,false); gs._resolve_resolution_stack()
	check(Vine.bonus(u)==count and not p.units[2].has("vineCharm"),"millennium excludes forcedattack/combatcardstyle attacks")
	p.attackUsed=false; var pine_idx: int=gs.VerifiedRules.Pine.summon(gs,0,2); check(gs.basic_attack(0,pine_idx),"actualsummonbasicattack")
	check(Vine.bonus(u)==count and not p.units[pine_idx].has("vineCharm"),"millennium excludes summonedbasicattacker")
	play(gs,"c22808"); p.attackUsed=false; check(gs.basic_attack(0,1),"two-realms non-summonedbasicattack")
	check(Vine.bonus(p.units[1])==count+2 and ncharms(gs)==1,"twoindependentmillennium triggers addtwonewcharm")
	gs._damage_avatar(0,8,1,0)
	check(Vine.realm_count(gs,0)==1,"realm losesactualdurability andfirstdestroyed")
func test_transfer_scopes() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); play(gs,"c22804"); var v:=phantom(gs); var idx: int=gs._unit_index_by_uid(0,v.uid)
	Vine.remove_summon(gs,0,v,"explicit remove")
	check(v.removed and ncharms(gs)==0 and Vine.bonus(p.units[0])==0,"noGarden/norealm neverinventreturn")
	gs=game(); p=gs.player(0); play(gs,"c22802"); play(gs,"c22808"); v=phantom(gs); idx=gs._unit_index_by_uid(0,v.uid)
	var returned: int=events(gs,"vine-returned"); Vine.remove_summon(gs,0,v)
	check(Vine.bonus(p.units[0])==1 and ncharms(gs)==1 and events(gs,"vine-returned")==returned+1,"gardenplusmillennium observeone physicalcharm, noreturncopy")
	gs=game(); p=gs.player(0); play(gs,"c22802"); v=phantom(gs); idx=gs._unit_index_by_uid(0,v.uid); gs.VerifiedRules.Moon.full_moon(gs,v)
	check(v.removed and v.hp==0 and v.knockout==0 and Vine.bonus(p.units[0])==1,"genericMoon dispel callsrealremoval thenheal cannotfake revive0/0")
	gs=game(); p=gs.player(0); play(gs,"c22808"); Vine.attach(gs,0,1,3); var charm_uid: String=p.units[1].vineCharm.uid
	gs.VerifiedRules.Moon.full_moon(gs,p.units[1])
	check(p.units[1].hp==p.units[1].maxHp and Vine.bonus(p.units[0])==3 and p.units[0].vineCharm.uid==charm_uid,"genericdispel returns originalsameUID withsamecount andheals survivingbody")
	gs=game(); p=gs.player(0); play(gs,"c22808"); Vine.attach(gs,0,0,2); Vine.remove_charm(gs,0,0)
	check(ncharms(gs)==0 and p.units[0].hp==1,"millennium excludesTengjis owncharm fromreturn loop")
	gs=game(); p=gs.player(0); play(gs,"c22808"); Vine.attach(gs,0,1,3); gs._damage_avatar(0,8,1,0); Vine.remove_charm(gs,0,1)
	check(ncharms(gs)==0 and Vine.realm_count(gs,0)==0,"destroyedmillennium cannotreturn laterremovedcharm")
	gs=game(); p=gs.player(0); play(gs,"c22802"); v=phantom(gs); gs._knockout_unit(p.units[0]); gs._resolve_resolution_stack(); Vine.remove_summon(gs,0,v)
	check(ncharms(gs)==0 and p.units[0].hp==0,"knockedTengji/goneform cannotreturncharm orfake revive")
func test_response_ai() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); p.units[1].front=1
	give(gs,"c22801"); check(gs.end_turn(0),"enterenemyturnresponsefixture"); p.energy=3; var target: Dictionary=p.units[1]; var before: int=target.hp
	check(gs.basic_attack(1,0),"enemyactualbasicattack")
	check(target.vineCharm.count==1 and target.hp==before+1-int(foe.units[0].attack) and p.hand.is_empty() and events(gs,"response-card")==1,"actualviolet automaticresponse attaches todefender beforedamage")
	gs=game(); p=gs.player(0); give(gs,"c22803"); give(gs,"c22806"); var best:=AI._best_card(gs,0)
	check(best.ok and best.card_id=="c22806" and gs.play_card(0,best.hand,best.target),"AI skipillegalrelief andactuallysummons+draws")
	p.hand.clear(); give(gs,"c22803"); best=AI._best_card(gs,0)
	check(best.ok and gs._unit_index_by_uid(1,best.target)>=0 and gs.play_card(0,best.hand,best.target),"AI actualrelief selects legalenemynonsummon andpayscost")
	gs=game(); give(gs,"c22807"); gs.player(1).units[1].keywords=["veil"]; best=AI._best_card(gs,0)
	check(best.ok and best.target!=gs.player(1).units[1].uid and gs.play_card(0,best.hand,best.target),"AI echoesactuallegalvisibleenemy")
	var state:=JSON.stringify(gs.snapshot()); var marks:=Vine.unit_marks(gs,0,gs._unit_index_by_uid(0,phantom(gs).uid))
	check(marks.size()==2 and marks[0].contains("替身") and JSON.stringify(gs.snapshot())==state,"read-only livecharm/phantom inspector")
	for id in ["c22801","c22802","c22803","c22804","c22805","c22806","c22807","c22808"]:
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalart "+id)
		check(Content.card_def(id).verifiedRules and not Content.card_def(id).verificationPending.is_empty(),"pendingnative "+id)
func native_ui() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["tengji","rulianshi","xiaosongwan","yanmo"],["yaodaoji","bingyong","xuenv","baizangzhu"],228); b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=80; side.levelUpUsed=true
			for u in side.units: u.level=3
		for owner in 2:
			for idx in b.gs.player(owner).units.size():
				if Vine.bonus(b.gs.player(owner).units[idx])>0: Vine.detach(b.gs,owner,idx)
		root.add_child(b); await create_timer(0.4).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		hand(b,["c22803","c22802"]); await settled(b)
		check(not b._hand_row.get_child(0).playable,"native costdisabled withoutfrontsummon")
		await click(b._hand_row.get_child(1)); await settled(b)
		var v:=phantom(gs); check(v.hp==1 and v.attack==1,"native garden createsreal1/1supported0/0")
		await click(b._unit_widget(str(v.uid))); await settled(b)
		if b._selected_attacker>=0: await click(b._unit_widget(str(v.uid))); await settled(b)
		check(texts(b).contains("藤色") and texts(b).contains("替身"),"native inspector explainstrueenchantment")
		if physical.x==1280: await capture("01-vine-real-charm-inspector")
		escape(); await settled(b); hand(b,["c22803"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0 and b._unit_widget(str(foe.units[1].uid)).selected and b._unit_widget(str(p.units[1].uid)).selected,"native relief showstruebothside non-summontargets")
		var fire: int=p.energy; await click(b._unit_widget(str(v.uid))); await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"native summonedtarget rejected withoutpayingcost")
		if physical.x==1600: await capture("02-vine-relief-real-targets")
		await click(b._unit_widget(str(foe.units[1].uid))); await settled(b)
		check(v.removed and foe.units[1].hp==0 and Vine.bonus(p.units[0])==1,"native actualcost harddestroy andcharmreturn")
		hand(b,["c22807"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		var atk: int=foe.units[0].attack; var hp: int=foe.units[0].hp; await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(phantom(gs).attack==atk+2 and phantom(gs).hp==hp+2 and Vine.bonus(phantom(gs))==2,"native echoesactualbody plusfusedexistingcharm")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores(); var args:=OS.get_cmdline_user_args(); var rules_only:=args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out=str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	test_activation(); test_charm_stats(); test_substitute_removal(); test_cards_targets(); test_base_awake_realms(); test_transfer_scopes(); test_response_ai()
	if not rules_only: await native_ui()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("VINE_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures==0 else 1)
