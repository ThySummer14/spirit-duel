extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Enma := preload("res://scripts/enma_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("ENMA_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["yanmo","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],230)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true
		for u in p.units: u.level=3
	gs.rule_events.clear()
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"enma-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1
func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actual card command "+id)
func events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()
func basic_and_fusion() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; var foe: Dictionary=gs.player(1)
	check(u.attack==3 and u.maxHp==3 and Content.unit_def("yanmo").passive.hooks.is_empty(),"exact3/3 source and no legacy combatgrowth")
	check(Enma.ghost(gs,0).is_empty(),"initially no invented ghost")
	check(gs.basic_attack(0,0,"avatar-1"),"ordinary enma actual command")
	var body:=Enma.ghost(gs,0)
	check(not body.is_empty() and body.attack==3 and body.maxHp==1 and body.hp==1,"basic source creates real3/1 ghost")
	check(u.front==0 and u.hp==3 and u.attack==3 and body.front==1,"master neither enters front nor fights/grows")
	check(foe.avatarHp==27 and p.energy==39 and p.attackUsed,"replacement still pays exactly ordinary1fire/quota")
	check(events(gs,"enma-basic-replaced")==1 and events(gs,"enma-ghost-summoned")==1,"observable replacement/summon event without fake mastercombat")
	check(not gs.can_basic_attack(0,0).ok and not gs.can_basic_attack(0,p.units.size()-1).ok,"real ordinary quota shared with generatedghost")
	var first: String=body.uid; body.shield=4; body.frozen=1; body.inspired=true; body.swift=true; body.brittle=2; body.armorBreak=1
	p.attackUsed=false
	check(gs.basic_attack(0,0,"avatar-1"),"second actual enma command fuses")
	body=Enma.ghost(gs,0)
	check(body.uid!=first and body.attack==6 and body.maxHp==2 and body.hp==2,"fusion creates new instance6/2")
	check(body.frozen==1 and body.inspired and body.swift and body.brittle==2,"fusion preserves stun, inspired, swift and attachedstate")
	check(p.units[4].removed and p.units[4].enmaFused and not gs.VerifiedRules.Rebirth.can_revive(p.units[4]),"fused old identity is tombstone and never revives")
	check(events(gs,"enma-ghost-fused")==1 and events(gs,"enma-ghost-removed")==0 and events(gs,"kill-recorded")==0,"fusion does not counterfeit removal or death")
	gs=game(); p=gs.player(0); u=p.units[0]; u.attackBonus=-10; gs._recalc(u)
	check(gs.basic_attack(0,0,"avatar-1") and Enma.ghost(gs,0).attack==1,"nonpositive enma power clamps newbornghost to1")
	gs=game(); p=gs.player(0); u=p.units[0]; u.frozen=1
	check(not gs.basic_attack(0,0,"avatar-1") and Enma.ghost(gs,0).is_empty(),"stunned source cannot bypass real ordinary gate")
	u.frozen=0; gs._knockout_unit(u)
	check(not gs.basic_attack(0,0,"avatar-1") and Enma.ghost(gs,0).is_empty(),"knocked source cannot summon via ordinarycommand")
	gs=game(); u=gs.player(0).units[0]; u.baseRulesSuppressed=true
	check(not Enma.replace_basic(gs,0,0,"avatar-1"),"suppressed source never executes original passive")

func steal_and_pressure() -> void:
	for armor in [0,2,5]:
		var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var victim: Dictionary=foe.units[0]
		victim.hp=3; victim.shield=armor
		play(gs,"c23001",victim.uid)
		check((victim.hp==0)==(armor==0),"steal actual3 damage throughshield%d" % armor)
		check(bool(p.units[0].get("swift",false))==(armor==0),"swift only actualkill aftershield%d" % armor)
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	foe.units[0].barrier=true; foe.units[0].hp=1; play(gs,"c23001",foe.units[0].uid)
	check(foe.units[0].hp==1 and not p.units[0].get("swift",false),"prevented lethal never fabricates swift")
	foe.units[1].keywords=["veil"]
	check(not gs.valid_targets(0,Content.card_def("c23001")).has(foe.units[1].uid),"steal excludes hostile veil")
	var h:=give(gs,"c23005"); var fire: int=p.energy
	check(not gs.can_play_card(0,h,foe.units[0].uid).ok and not gs.play_card(0,h,foe.units[0].uid),"pressure cannot invent a ghost from missingbody")
	check(p.energy==fire and p.hand.size()==1,"failed missingghost command pays nothing")
	check(gs.basic_attack(0,0,"avatar-1"),"setup actualghost")
	var body:=Enma.ghost(gs,0); var idx: int=gs._unit_index_by_uid(0,str(body.uid)); var enemyfront: Dictionary=foe.units[2]; enemyfront.front=1
	foe.units[0].hp=1; foe.units[0].barrier=false
	var deck: int=p.deck.size(); var bodyid: String=body.uid; var avatar: int=foe.avatarHp
	check(gs.play_card(0,h,foe.units[0].uid),"pressure actual chosenreserve enemy bypasses unrelatedfront")
	check(foe.units[0].hp==0 and foe.avatarHp==avatar and enemyfront.hp==enemyfront.maxHp,"pressure damages chosenreserve only withtruecombat")
	check(p.deck.size()==deck-1 and p.hand.size()==1 and p.units[0].hp==3,"pressure actualkill draws exactly1; master never fights")
	check(p.units[idx].uid==bodyid and p.units[idx].hp==0 and p.units[idx].removed,"pressure reuses existing1hpghost and realcounter killsit")
	check(not gs.can_play_card(0,give(gs,"c23005"),foe.units[2].uid).ok,"after trueghostdeath pressure unavailable")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c23006"); gs.basic_attack(0,0,"avatar-1")
	gs._grow_unit(foe.units[0],0,20); deck=p.deck.size(); play(gs,"c23005",foe.units[0].uid)
	check(p.deck.size()==deck and foe.units[0].hp==20,"surviving target yieldsno pressure draw, exact4damage")
	check(gs.player(0).attackUsed==false,"pressure never spends ordinaryquota; awakened firstbasic hadinspired")
	check(not gs.valid_targets(0,Content.card_def("c23005")).has("avatar-1"),"pressure never permits avatar target")

func forms_and_awaken() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	gs.basic_attack(0,0,"avatar-1"); var body:=Enma.ghost(gs,0)
	play(gs,"c23002")
	check(u.attack==3 and u.maxHp==3 and gs.VerifiedRules.Combat.has(body,"veil"),"eye exact3/3 gives currentghostveil, no invented shield")
	check(not u.get("enmaVeil",false) and u.shield==0,"eye protects ghost only")
	check(not gs.valid_targets(1,Content.card_def("c23001")).has(body.uid),"actual hostile targetedspell excludes veiledghost")
	play(gs,"c23004")
	check(u.attack==4 and u.maxHp==4 and not gs.VerifiedRules.Combat.has(body,"veil") and body.shield==0,"judge replacingeye removesaura without invented onexisting armor")
	p.attackUsed=false; gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0)
	check(body.attack==7 and body.maxHp==2 and body.shield==2 and u.shield==0,"judge fusion gains2armor onghost only")
	p.attackUsed=false; gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0)
	check(body.shield==4 and body.attack==11 and body.maxHp==3,"judge repeatedfusion retains andadds armor")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23006")
	check(u.awakened and u.attack==4 and u.maxHp==4 and gs.VerifiedRules.Combat.has(u,"inspired") and not u.get("swift",false),"awakening exact1/1 and oneoffinspired, never substitutes swift")
	var fire: int=p.energy; gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0)
	check(body.attack==4 and body.maxHp==4 and p.energy==fire-1 and not p.attackUsed and not gs.VerifiedRules.Combat.has(u,"inspired"),"awakeghost true4/4 firstordinary consumesonly inspired")
	check(gs.basic_attack(0,0,"avatar-1") and p.attackUsed and Enma.ghost(gs,0).maxHp==8,"awake allows secondordinary then consumes quota andfuses8/8")
	check(not gs.can_basic_attack(0,0).ok and not gs.can_play_card(0,give(gs,"c23006")).ok,"awakening hasno infiniteattacks/repeatedcard")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23007"); play(gs,"c23006"); gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0)
	check(u.attack==6 and body.attack==6 and Enma.has(body,"pierce") and Enma.has(body,"unyielding") and not u.unyielding,"mercy6/6awakeghost gets exactpierce/unyielding, masterdoesnot")
	var idx: int=gs._unit_index_by_uid(0,str(body.uid)); gs._damage_unit(0,idx,99,1,0); gs._resolve_resolution_stack()
	check(body.hp==1 and not Enma.has(body,"unyielding"),"mercyghost firstlethal consumesunyielding")
	Enma.refresh(gs)
	check(not Enma.has(body,"unyielding"),"aura refresh doesnotregrant alreadyconsumedunyielding")
	gs._heal_unit(body,3); gs._damage_unit(0,idx,99,1,0); gs._resolve_resolution_stack()
	check(body.hp==0 and body.removed,"secondlethal killsghost evenafterheal")
	gs=game(); p=gs.player(0); play(gs,"c23007"); play(gs,"c23006"); var foe: Dictionary=gs.player(1); foe.units[0].front=1; foe.units[0].hp=2; foe.units[0].shield=1
	gs.basic_attack(0,0,foe.units[0].uid)
	check(foe.units[0].hp==0 and foe.avatarHp==27,"mercy true6power pierces2hp1armor blockerfor3")

func mirror_and_lord() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]
	play(gs,"c23003")
	check(p.realms.size()==1 and p.realms[0].hp==6 and p.realms[0].nativeRealm=="enma-mirror","mirror actual6durabilityrealm")
	check(p.units.all(func(a):return a.shield==0) and u.attack==3 and u.maxHp==3,"mirror never buffsnonsummonedmaster or fakearmor")
	gs.basic_attack(0,0,"avatar-1"); var body:=Enma.ghost(gs,0)
	check(body.attack==4 and body.maxHp==2 and body.hp==2,"mirror buffs newborn summon exact1/1")
	p.attackUsed=false; gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0)
	check(body.attack==7 and body.maxHp==3 and body.hp==3,"fusion inherits bodywithout doublecountingmirror aura")
	body.hp=1; p.attackUsed=false; gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0)
	check(body.attack==10 and body.maxHp==4 and body.hp==2,"wounded fusion preserves wounds withsingleaura")
	Enma.turn_start(gs,0)
	check(body.swift and body.inspired and not u.get("swift",false) and not u.get("inspired",false),"mirror ownstart givesonly summons swift/inspired")
	var fire: int=p.energy; var idx: int=gs._unit_index_by_uid(0,str(body.uid)); p.attackUsed=true
	check(gs.basic_attack(0,idx,"avatar-1") and p.energy==fire and p.attackUsed and not body.swift and not body.get("inspired",false),"ghost can consume bothgrants afterquota alreadyused")
	p.realms.clear(); Enma.refresh(gs)
	check(body.attack==9 and body.maxHp==3 and body.hp==2,"mirror removal subtractsonlycontinuous1/1 withouthealingwounds")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23002"); play(gs,"c23004"); play(gs,"c23007")
	var h:=give(gs,"c23008"); var card:=gs.hand_card_def(0,h)
	check(card.formRules.enmaEye and card.formRules.enmaJudge and card.formRules.enmaMercy and card.formRules.enmaLord,"lordinherits three different previouslyusedformabilities")
	check(Content.card_def("c23008").formRules.keys().size()==2,"dynamic enhancement nevermutates sharedbasecard")
	check(gs.play_card(0,h) and u.attack==5 and u.maxHp==5 and u.swift,"lordactual5/5 andswift, nofakeassault")
	check(gs.player(1).avatarHp==30 and Enma.ghost(gs,0).is_empty(),"lordentry doesnot invent attack/summon")
	play(gs,"c23006"); gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0); idx=gs._unit_index_by_uid(0,str(body.uid))
	check(body.attack==6 and body.maxHp==6 and body.shield==2 and Enma.has(body,"veil") and Enma.has(body,"pierce") and Enma.has(body,"unyielding"),"lordinheritsall exact liveghosteffects")
	var power: int=u.attack; gs.VerifiedRules.Panguan.destroy(gs,1,0,0,idx); gs._resolve_resolution_stack()
	check(u.attack==power+3 and u.maxHp==6,"lordtrueghostKO givesfloorhalf6poweras3attackonly")
	check(events(gs,"enma-lord-growth")==1 and body.removed and body.knockout==0,"ghostKO rewards once andneverrevives")
	gs._knockout_unit(body); gs._resolve_resolution_stack()
	check(u.attack==power+3 and events(gs,"enma-lord-growth")==1,"alreadyremovedghost neverrepeatdeathgrowth")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23008"); gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0); idx=gs._unit_index_by_uid(0,str(body.uid)); power=u.attack
	check(body.attack==5 and not Enma.has(body,"veil") and not Enma.has(body,"pierce"),"lordwithoutpastforms inheritsnothing")
	gs.VerifiedRules.Panguan.destroy(gs,1,0,0,idx); gs._resolve_resolution_stack()
	check(u.attack==power+2,"odd5powerghost givesfloorhalf2growth")
	gs=game(); p=gs.player(0); u=p.units[0]; play(gs,"c23008"); gs.basic_attack(0,0,"avatar-1"); body=Enma.ghost(gs,0); idx=gs._unit_index_by_uid(0,str(body.uid)); power=u.attack
	check(gs.VerifiedRules.Movement.move_to(gs,0,idx,0),"movingghostoutfront actual command")
	gs._resolve_resolution_stack()
	check(body.removed and body.hp==0 and body.knockout==0 and u.attack==power and events(gs,"enma-lord-growth")==0,"departure removeswithoutdeathgrowth")

func revived_fusion_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0)
	play(gs,"c23003"); play(gs,"c23006")
	gs.basic_attack(0,0,"avatar-1")
	var first:=Enma.ghost(gs,0); var first_idx: int=gs._unit_index_by_uid(0,str(first.uid))
	gs.VerifiedRules.Panguan.destroy(gs,1,0,0,first_idx); gs._resolve_resolution_stack()
	check(first.has("weaverGrave") and first.weaverGrave.attack==5,"generic trueghostKO snapshots actual5power for powderrevival")
	gs.basic_attack(0,0,"avatar-1")
	var old:=Enma.ghost(gs,0); old.hp=2; old.inspired=true; old.swift=true; old.shield=3
	var kills:=events(gs,"kill-recorded")
	var fused: int=gs.VerifiedRules.Weaver.revive(gs,0,first_idx); gs._resolve_resolution_stack()
	check(fused>=0 and fused!=first_idx and gs.player(0).units[fused].get("enmaGhost",false),"real powdergeneric revive fuses with existingghost into newidentity")
	var result: Dictionary=gs.player(0).units[fused]
	check(result.attack==9 and result.maxHp==9 and result.hp==6,"revived5/5 plus wounded2of5 leaves one1/1aura and true6of9hp")
	check(result.shield==3 and result.inspired and result.swift,"revived fusion retains existingarmor/inspired/swift")
	check(first.removed and old.removed and first.enmaFused and old.enmaFused and events(gs,"kill-recorded")==kills,"both fusioninputs disappear withoutnewKO")
	check(not result.get("enmaDeathRecorded",false) and not result.get("enmaRemovalRecorded",false),"newfusion can later die exactlyonce")
	gs=game(); gs.basic_attack(0,0,"avatar-1"); first=Enma.ghost(gs,0); first_idx=gs._unit_index_by_uid(0,str(first.uid))
	gs.VerifiedRules.Panguan.destroy(gs,1,0,0,first_idx); gs._resolve_resolution_stack()
	var revived: int=gs.VerifiedRules.Weaver.revive(gs,0,first_idx)
	check(revived==first_idx and first.hp==1 and first.front==1 and not first.removed,"powderwithoutotherghost revives originalidentity/body")

func ai_and_art() -> void:
	for i in range(1,9):
		var gs:=game(); var id:="c2300%d" % i
		if i==5: gs.basic_attack(0,0,"avatar-1")
		give(gs,id); var best:=AI._best_card(gs,0)
		check(best.ok and gs.can_play_card(0,int(best.hand),best.target).ok,"AI legal exactcard "+id)
		check(best.ok and gs.play_card(0,int(best.hand),best.target),"AI actual resolution "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"originalsubjectcardface "+id)
	var gs:=game(); give(gs,"c23005")
	check(not AI._best_card(gs,0).ok,"AI rejects missingghost pressure")
	check(Content.card_def("yanmo-hungui").type=="summon" and Content.card_def("yanmo-hungui").effects[0].action=="enma-token","old fauxprojectiletoken replaced by genuineinspectable summondefinition")
	check(not gs.can_play_card(0,give(gs,"yanmo-hungui")).ok,"derivedbody isnot fabricated playableprojectile")
	gs=game()
	var token:=Content.card_def("yanmo-hungui")
	check(Enma.resolve_action(gs,0,0,token,token.effects[0],{},null),"derived action has real executable summon")
	check(not Enma.ghost(gs,0).is_empty() and gs.player(1).avatarHp==30 and gs.player(0).units[0].front==0,"derived action summons actualbody without counterfeit2projectiledamage")
	for id in ["c23001","c23002","c23003","c23004","c23005","c23006","c23007","c23008"]:
		check(not Content.card_def(id).verificationPending.is_empty(),"baseline honest pending "+id)

func ui_rules() -> void:
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["yanmo","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],230)
		b._ai_thinking=true
		for side in b.gs.players:
			side.hand.clear(); side.energy=40; side.levelUpUsed=true
			for u in side.units: u.level=3
		root.add_child(b); await create_timer(0.5).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
		hand(b,["c23002","c23003","c23006"]); await settled(b)
		for i in 3: await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].awakened and p.realms.size()==1 and p.units[0].formRules.enmaEye,"mouseplays actualeye mirror awakening")
		await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
		check(b._selected_attacker==0,"mousemaster selects realordinaryattack")
		await click(b._enemy_plate); await settled(b)
		var body:=Enma.ghost(gs,0)
		check(not body.is_empty() and body.attack==5 and body.maxHp==5 and p.units[0].front==0 and foe.avatarHp==25,"mouseordinary replacesmaster byreal5/5ghost andhitsavatar")
		await click(b._unit_widget(str(body.uid))); await settled(b)
		if b._selected_attacker>=0: await click(b._unit_widget(str(body.uid))); await settled(b)
		check(texts(b).contains("融合") and texts(b).contains("魂鬼"),"mouseghostinspector hasactualderivedrules")
		await capture("%d-enma-fused-ghost-inspector" % physical.x)
		escape(); await settled(b)
		foe.units[0].hp=1; hand(b,["c23005"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card==0,"mousepressure enters actualtargetselection")
		var fire: int=p.energy
		await click(b._unit_widget(str(p.units[1].uid))); await settled(b)
		check(b._pending_target_card==0 and p.energy==fire,"mousepressure refusesfriendlytarget withoutpayment")
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(foe.units[0].hp==0 and p.units[0].hp==4 and p.hand.size()==1,"mousepressure chosenreserve realbattlekills/draws")
		b.queue_free(); await process_frame; await process_frame
func run() -> void:
	var stores:=Support.isolate_stores()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out=arg; DirAccess.make_dir_recursive_absolute(out); break
	root.theme=ThemeBuilder.build_theme()
	basic_and_fusion(); steal_and_pressure(); forms_and_awaken(); mirror_and_lord(); revived_fusion_rules(); ai_and_art()
	if not OS.get_cmdline_user_args().has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("ENMA checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
