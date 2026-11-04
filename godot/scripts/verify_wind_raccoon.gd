extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const WindRaccoon := preload("res://scripts/wind_raccoon_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("WIND_RACCOON_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["fengli","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],232)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.rule_events.clear()
	return gs
func give(gs, id: String) -> int:
	gs.player(0).hand.append({"definitionId":id,"instanceId":"wind-raccoon-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(0).hand.size()-1
func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actual command "+id)
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func events_of(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e):return e.kind==kind)
func baseline_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; var foe: Dictionary=gs.player(1)
	check(u.attack==2 and u.hp==3 and Content.unit_def("fengli").passive.hooks.is_empty(),"true2/3 source without old aftercombat1damage")
	check(gs.basic_attack(0,0,"avatar-1"),"actual ordinary command")
	var body:=WindRaccoon.clone(gs,0)
	check(body.attack==2 and body.maxHp==3 and body.hp==3 and body.front==1,"base createstrue2/3combatbody")
	check(foe.avatarHp==26 and u.front==0 and u.attack==2 and u.hp==3,"base actualsource2thenclone2, nofakegrowth/sourcefront")
	check(p.energy==39 and p.attackUsed and events(gs,"wind-raccoon-summoned")==1,"base costsonefire/quota; clone neverrecursive")
	check(events(gs,"combat-complete")==2 and events(gs,"wind-raccoon-fused")==0,"exacttwo actualcombats")
	gs=game(); p=gs.player(0); u=p.units[0]; gs._grow_unit(u,7,4)
	gs._damage_avatar(1,1,0,0); gs._resolve_resolution_stack(); body=WindRaccoon.clone(gs,0)
	check(body.attack==2 and body.maxHp==3 and gs.player(1).avatarHp==27,"noncombat actualdamage triggersfixed2/3 regardlessbuffedmaster")
	gs=game(); gs.player(1).avatarArmor=10; gs._damage_avatar(1,3,0,0); gs._resolve_resolution_stack()
	check(WindRaccoon.clone(gs,0).is_empty() and gs.player(1).avatarHp==30,"armorblockedHPdamage createsnoclone")
	gs=game(); gs._damage_avatar(0,1,0,0); gs._resolve_resolution_stack()
	check(WindRaccoon.clone(gs,0).is_empty(),"friendlyavatar damage nevertriggers hostilepassive")
	gs._damage_avatar(1,1,0,1); gs._resolve_resolution_stack()
	check(WindRaccoon.clone(gs,0).is_empty(),"teammateavatar damage not attributed towindraccoon")
	gs=game(); gs.player(0).units[0].baseRulesSuppressed=true; gs._damage_avatar(1,1,0,0); gs._resolve_resolution_stack()
	check(WindRaccoon.clone(gs,0).is_empty(),"suppressed originalability doesnottrigger")
	gs=game(); foe=gs.player(1); foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20)
	gs.basic_attack(0,0,foe.units[0].uid)
	check(gs.player(0).units[0].hp==0 and WindRaccoon.clone(gs,0).is_empty() and foe.avatarHp==30,"base losesrealcombat againstfront and neverinventsonlyaftercombatdamage")

func clone_and_remote_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	u.hp=1; gs._grow_unit(u,3,0); var deck: int=p.deck.size(); play(gs,"c23203")
	var body:=WindRaccoon.clone(gs,0)
	check(body.attack==5 and body.maxHp==1 and body.hp==1 and u.hp==1,"spellcopiessourcecurrentpower/currentlife, notmaxhp")
	check(p.deck.size()==deck and p.hand.is_empty() and p.energy==40 and gs.player(1).avatarHp==30,"instantspell summons withoutfake draw/attack")
	check(gs.kw_usage(0,"instant").used and u.front==0 and not p.attackUsed,"firstinstant consumes sharedinstant notordinaryquota")
	var old: String=body.uid; body.shield=2; body.swift=true; body.inspired=true; body.frozen=1
	play(gs,"c23203"); body=WindRaccoon.clone(gs,0)
	check(body.uid!=old and body.attack==10 and body.maxHp==2 and body.hp==2,"same-sourcemerge newidentity10/2")
	check(body.shield==2 and body.swift and body.inspired and body.frozen==1,"fusion keeps armor/swift/inspired/stun")
	check(p.energy==39 and events(gs,"kill-recorded")==0 and events(gs,"wind-raccoon-removed")==0,"secondinstant realfire; fusionnotfakeKO/removal")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23203"); play(gs,"c23201"); body=WindRaccoon.clone(gs,0)
	check(u.front==0 and u.hp==3 and body.attack==4 and body.maxHp==6,"remote staysreserve andgrows existingclonethroughfusion")
	check(gs.player(1).avatarHp==24 and events(gs,"combat-complete")==2,"remote exactsource2plusfusedclone4actualcombat")
	gs=game(); var foe: Dictionary=gs.player(1); foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20); var hp: int=foe.units[0].hp
	play(gs,"c23201")
	check(foe.units[0].hp==hp-2 and gs.player(0).units[0].hp==3 and gs.player(0).units[0].front==0,"remoteexact2frontdamage nocounterandnomove")
	check(WindRaccoon.clone(gs,0).is_empty() and foe.avatarHp==30,"remoteunitdamageisnotavatartrigger")

func combat_sequence_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c23204")
	check(foe.avatarHp==21 and events(gs,"combat-complete")==3,"bomb true2spell+2clone+3source+2clone damagefourtimes")
	var hits:=events_of(gs,"combat-hit")
	check(hits.size()==3 and str(hits[0].uid).contains("wind-raccoon") and hits[1].uid==p.units[0].uid and str(hits[2].uid).contains("wind-raccoon"),"bomb firstclonethenmasterthennewclone order")
	check(p.units[0].attack==2 and p.energy==39,"bomb printed+1temporarycombat no permanentpower")
	gs=game(); p=gs.player(0); play(gs,"c23203"); var body:=WindRaccoon.clone(gs,0); var old: String=body.uid
	play(gs,"c23202"); hits=events_of(gs,"combat-hit")
	check(hits.size()==3 and hits[0].uid==old and hits[1].uid==p.units[0].uid and hits[2].uid!=old,"substitute enhancedoldbodyattacks beforemaster thenpassiveclone")
	check(gs.player(1).avatarHp==24 and body.removed and events(gs,"wind-raccoon-generated")==0,"substituteexactthree2powercombats, replacedoldbody notgrowth/draw")
	gs=game(); play(gs,"c23202")
	check(gs.player(1).avatarHp==26 and events(gs,"combat-complete")==2,"unenhancedsubstitutejustnormal0bonusmasterpluspassiveclone")
	gs=game(); p=gs.player(0); play(gs,"c23203"); var deck: int=p.deck.size(); play(gs,"c23205")
	check(p.hand.size()==1 and p.hand[0].definitionId=="c23203" and p.hand[0].instanceId.begins_with("wind-raccoon-card-"),"hide enhancedgeneratesnewactualdedicatedspellinstance")
	check(p.deck.size()==deck and p.units[0].maxHp==3 and p.units[0].hp==3 and p.units[0].shield==3,"hide nofake draw/health; actual3battlearmor")
	check(gs.player(1).avatarHp==26,"hideexact0combatbonus plusnormalclone")
	gs=game(); p=gs.player(0); play(gs,"c23205")
	check(p.hand.is_empty() and events(gs,"wind-raccoon-generated")==0,"hide withoutinitialsummon cannotretroactivelyenhance frompassiveclone")
	gs=game(); foe=gs.player(1); foe.units[1].front=1; var hp: int=foe.units[1].hp; play(gs,"c23206")
	check(foe.avatarHp==27 and foe.units[1].hp==hp-2,"direct source+1hitsavatar thenclonehitsactualfront")
	check(gs.player(0).units[0].attack==2 and gs.player(0).units[0].hp==3,"directnotfake+3permanentorcounterthroughfront")

func awaken_and_six_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; var foe: Dictionary=gs.player(1)
	play(gs,"c23207")
	check(u.awakened and u.attack==3 and u.maxHp==3 and u.swift and u.passive_hooks.is_empty(),"awakeexact+1/+0swift replacesoldpassive")
	gs._damage_avatar(1,1,0,0); gs._resolve_resolution_stack()
	check(WindRaccoon.clone(gs,0).is_empty() and foe.avatarHp==29,"awakeningremovesbaseavatar-trigger ratherthanstackingit")
	foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20); var hp: int=foe.units[0].hp; var fire: int=p.energy
	check(gs.basic_attack(0,0,foe.units[0].uid),"awakebasicactualcommand")
	check(u.hp==3 and p.energy==fire and p.attackUsed and not u.swift,"awakebasiccombatimmunity and one-offswift paidcorrectly")
	check(foe.units[0].hp==hp-6 and events(gs,"wind-raccoon-summoned")==1,"awakeafterattack truecurrent3/3cloneattacksfrontafter3source")
	var bodies: Array=p.units.filter(func(a):return a.get("windRaccoonClone",false))
	check(bodies.size()==1 and bodies[0].hp==0 and bodies[0].removed,"clone doesnotinherit master'scombatimmunity")
	check(not gs.can_play_card(0,give(gs,"c23207")).ok,"repeatawakening unavailable")
	gs=game(); p=gs.player(0); u=p.units[0]; foe=gs.player(1); play(gs,"c23207"); foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20)
	play(gs,"c23202")
	check(u.hp==0 and WindRaccoon.clone(gs,0).is_empty(),"basic-specificawakeningimmunity doesnotprotectcombatcardattack")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23207"); play(gs,"c23201")
	var body:=WindRaccoon.clone(gs,0)
	check(u.front==0 and u.hp==3 and body.attack==3 and body.maxHp==3 and gs.player(1).avatarHp==24,"awake remotecard afterattack clonecopies3notcombatbonuses")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23208")
	check(u.attack==2 and u.maxHp==6 and u.hp==6 and u.formHooks.is_empty(),"sixexact2/6 form nofakedrawturnhook")
	play(gs,"c23203"); body=WindRaccoon.clone(gs,0)
	check(body.attack==4 and body.maxHp==12 and body.hp==12 and gs.player(1).avatarHp==30,"six doubles summons andfusesactual4/12; spellnoattack")
	check(events(gs,"wind-raccoon-summoned")==1 and events(gs,"wind-raccoon-fused")==1,"sixexacttwo createsonefusedbody withoutrecursion")
	gs=game(); p=gs.player(0); play(gs,"c23208"); gs.basic_attack(0,0,"avatar-1"); body=WindRaccoon.clone(gs,0)
	check(body.attack==4 and body.maxHp==6 and gs.player(1).avatarHp==24,"sixbaseextra summonfuses firstthenouterabilityoneattack")
	check(events(gs,"combat-complete")==2,"sixextra summon doesnotcopyunprintedextraattack")

func revived_fusion_rules() -> void:
	var gs:=game(); play(gs,"c23203")
	var first:=WindRaccoon.clone(gs,0); var first_idx: int=gs._unit_index_by_uid(0,str(first.uid))
	gs.VerifiedRules.Panguan.destroy(gs,1,0,0,first_idx); gs._resolve_resolution_stack()
	play(gs,"c23203"); var old:=WindRaccoon.clone(gs,0); old.shield=2; old.swift=true; old.inspired=true
	var fused: int=gs.VerifiedRules.Weaver.revive(gs,0,first_idx); gs._resolve_resolution_stack()
	check(fused>=0 and fused!=first_idx and gs.player(0).units[fused].get("windRaccoonClone",false),"powderrealrevivalfusesexisting same-sourcedclone")
	var body: Dictionary=gs.player(0).units[fused]
	check(body.attack==4 and body.maxHp==6 and body.hp==6 and body.shield==2 and body.swift and body.inspired,"revivedfusion exact4/6 withretainedarmor/swift/inspired")
	check(first.removed and old.removed and events(gs,"kill-recorded")==1,"revivedfusion consumesinputs withoutfakesecondkill")
	gs=game(); play(gs,"c23207"); var foe: Dictionary=gs.player(1)
	foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20); play(gs,"c23205")
	var born:=events_of(gs,"wind-raccoon-summoned")
	check(gs.player(0).units[0].hp==3 and gs.player(0).units[0].maxHp==3 and born.size()==1 and born[0].hp==3,"hide3armor absorbedcounter; awakeclone life3neverfake6")

func vine_fusion_rules() -> void:
	var gs:=game(); play(gs,"c23203")
	var old:=WindRaccoon.clone(gs,0); var idx: int=gs._unit_index_by_uid(0,str(old.uid))
	gs.VerifiedRules.Vine.attach(gs,0,idx,2)
	check(old.attack==4 and old.maxHp==5,"realVine2layers alterexistingclonestats")
	var charm_uid: String=old.vineCharm.uid
	play(gs,"c23203"); var body:=WindRaccoon.clone(gs,0)
	check(body.attack==6 and body.maxHp==8 and body.vineCharm.uid==charm_uid and body.vineCharm.count==2,"fusioninherits onephysicalcharm withone+2/+2contribution")
	check(not old.has("vineCharm") and old.removed and events(gs,"vine-removed")==0,"fusion erasesoldrecordwithoutfakecharmremoval")
	idx=gs._unit_index_by_uid(0,str(body.uid))
	check(gs.VerifiedRules.Movement.move_to(gs,0,idx,0),"realmovementremoval ofcharmedclone")
	check(body.removed and not body.has("vineCharm") and events(gs,"vine-removed")==1,"physicaldepartureactuallyremovescharmonce")

func lifecycle_and_ai() -> void:
	for armor in [0,1,3]:
		var gs:=game(); play(gs,"c23203"); var body:=WindRaccoon.clone(gs,0); var idx: int=gs._unit_index_by_uid(0,str(body.uid)); body.shield=armor
		var hit: Dictionary=gs._damage_unit(0,idx,1,1,0); gs._resolve_resolution_stack()
		check((body.hp==0)==(armor==0),"selfdestructrequiresactualHPdamage armor%d" % armor)
		check(bool(hit.knocked)==(armor==0),"selfdestructreturnsactualknockouttoattacker armor%d" % armor)
		check(events(gs,"kill-recorded")==(1 if armor==0 else 0),"selfdestructhasexactrealonekillrecord armor%d" % armor)
	var gs:=game(); play(gs,"c23203"); var body:=WindRaccoon.clone(gs,0); var idx: int=gs._unit_index_by_uid(0,str(body.uid))
	body.barrier=true; gs._damage_unit(0,idx,1,1,0); gs._resolve_resolution_stack()
	check(body.hp==3 and not body.barrier,"barrierconsumedwithoutprematureselfdestruct")
	gs._damage_unit(0,idx,99,1,0); gs._resolve_resolution_stack()
	check(body.removed and body.knockout==0 and events(gs,"kill-recorded")==1,"normallethaldoesnotdoublecountselfdestruct")
	gs=game(); play(gs,"c23203"); body=WindRaccoon.clone(gs,0); idx=gs._unit_index_by_uid(0,str(body.uid))
	check(gs.VerifiedRules.Movement.move_to(gs,0,idx,0) and body.removed and body.hp==0 and events(gs,"kill-recorded")==0,"movementremovalnotfakeKO")
	gs=game(); play(gs,"c23203"); body=WindRaccoon.clone(gs,0); gs.VerifiedRules.Enma.summon_ghost(gs,0,1)
	check(body.removed and events(gs,"kill-recorded")==0,"otherrealsummonreplacesclonewithoutdeath")
	for i in range(1,9):
		gs=game(); var id:="c2320%d" % i
		if i in [2,5]: play(gs,"c23203")
		give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and gs.can_play_card(0,int(best.hand),best.target).ok,"AIlegalexactcard "+id)
		check(best.ok and gs.play_card(0,int(best.hand),best.target),"AIactualresolution "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalart "+id)
		check(not Content.card_def(id).verificationPending.is_empty(),"honestpending "+id)
	gs=game(); var token:=Content.card_def("fengli-fenshen")
	check(token.type=="summon" and token.effects[0].action=="wind-raccoon-token" and not gs.can_play_card(0,give(gs,"fengli-fenshen")).ok,"oldfauxassaulttokenisgenuinebody/nonhandplay")
	check(WindRaccoon.resolve_action(gs,0,0,token,token.effects[0],{},null),"tokenhasactualexecutablesummonaction"); gs._resolve_resolution_stack()
	check(WindRaccoon.clone(gs,0).attack==2 and gs.player(1).avatarHp==30,"tokencreatesbodywithoutinventedassaultdamage")

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["fengli","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],232)
		b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear(); p.energy=40; p.levelUpUsed=true
			for u in p.units: u.level=3
		root.add_child(b); await create_timer(0.5).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		hand(b,["c23203","c23201"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		var body:=WindRaccoon.clone(gs,0)
		check(body.attack==2 and body.hp==3 and p.hand.size()==1 and foe.avatarHp==30,"mousespelltrue2/3summon nofake draw/attack")
		await click(b._hand_row.get_child(0)); await settled(b); body=WindRaccoon.clone(gs,0)
		check(p.units[0].front==0 and body.attack==4 and body.maxHp==6 and foe.avatarHp==24,"mouseremoteactualsource2/fused4andreservebody")
		await click(b._unit_widget(str(body.uid))); await settled(b)
		if b._selected_attacker>=0: await click(b._unit_widget(str(body.uid))); await settled(b)
		check(texts(b).contains("融合") and texts(b).contains("自毁") and texts(b).contains("分身·风狸"),"mousecloneinspectorrealrules")
		await capture("%d-wind-raccoon-fusion-inspector" % physical.x)
		escape(); await settled(b)
		hand(b,["c23205"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.hand.size()==1 and p.hand[0].definitionId=="c23203" and p.units[0].maxHp==3,"mousehidegeneratesrealspellanddoesnotfakehealth")
		hand(b,["c23207"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].awakened and p.units[0].attack==3 and p.units[0].swift,"mouseawakeexactstats/realoneshotswift")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out=arg; DirAccess.make_dir_recursive_absolute(out); break
	root.theme=ThemeBuilder.build_theme()
	baseline_rules(); clone_and_remote_rules(); combat_sequence_rules(); awaken_and_six_rules(); revived_fusion_rules(); vine_fusion_rules(); lifecycle_and_ai()
	if not OS.get_cmdline_user_args().has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("WIND_RACCOON checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
