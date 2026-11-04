extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Moon := preload("res://scripts/moon_rules.gd")
const Bamboo := preload("res://scripts/bamboo_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("MOON_BAMBOO_FAIL ",detail)

func game() -> GS:
	var gs := GS.create(["zhuiyueshen","huiyeji","xun","yaodaoji"],["zhuiyueshen","huiyeji","bingyong","bailang"],197176)
	for p in gs.players:
		p.hand.clear(); p.energy=30; p.levelUpUsed=true
		for unit in p.units: unit.level=3
	return gs

func inst(gs, id: String) -> Dictionary:
	var entry := {"definitionId":id,"instanceId":"moon-bamboo-%d" % gs.next_card_id}; gs.next_card_id+=1; return entry

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(inst(gs,id)); return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)

func turn(gs, owner: int) -> void:
	check(gs.end_turn(owner),"real turn %d" % owner); gs.player(1-owner).levelUpUsed=true

func choices(gs) -> void:
	var count := 0
	while not gs.pending_choice.is_empty() and count<30:
		check(AI._resolve_choice(gs,int(gs.pending_choice.playerIndex)),"AI resolves actual "+str(gs.pending_choice.get("type"))); count+=1
	check(gs.pending_choice.is_empty(),"choice fully resumes")

func moon_charm() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	check(p.units[0].attack==2 and p.units[0].maxHp==4,"moon exact2/4")
	p.units[0].erase("moonCharm"); p.deck.append(inst(gs,"c19703")); gs._draw(0,1); gs._resolve_resolution_stack()
	check(not p.units[0].get("moonCharm",{}).is_empty(),"actual Moon draw attaches charm")
	p.energy=0; var h := give(gs,"c19702")
	check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==0,"base Moon at0 gains real instant")
	check(gs.play_card(0,h,p.units[3].uid) and p.energy==0 and p.units[0].get("moonCharm",{}).is_empty(),"instant spends charm without invented energy")
	h=give(gs,"c19702"); check(not gs.can_play_card(0,h,p.units[3].uid).ok,"consumed charm cannot remain instant")
	Moon.attach(gs,0,0); gs.kw_usage(0,"instant").used=true
	check(not gs.can_play_card(0,h,p.units[3].uid).ok,"shared instant once per turn still applies")
	p.energy=2; gs.kw_usage(0,"instant").used=false
	check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==1,"unawakened charm does not grant instant above0")
	check(gs.play_card(0,h,p.units[3].uid) and not p.units[0].get("moonCharm",{}).is_empty(),"normal use above0 preserves charm")
	gs=game(); p=gs.player(0); play(gs,"c19706"); Moon.attach(gs,0,0)
	h=give(gs,"c17602"); check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==0,"awake charm grants any own card instant above0")
	check(gs.play_card(0,h) and p.energy==29 and p.units[0].get("moonCharm",{}).is_empty(),"other character realm consumes Moon charm")
	gs=game(); p=gs.player(0); p.units[0].level=0; p.units[0].erase("moonCharm"); p.deck.append(inst(gs,"c19701")); gs._draw(0,1); gs._resolve_resolution_stack()
	check(p.units[0].get("moonCharm",{}).is_empty(),"inactive Moon cannot attach")
	p.units[0].level=3; gs._knockout_unit(p.units[0]); p.deck.append(inst(gs,"c19701")); gs._draw(0,1); gs._resolve_resolution_stack()
	check(p.units[0].get("moonCharm",{}).is_empty(),"knocked Moon cannot attach")
	gs=game(); p=gs.player(0); p.units[0].erase("moonCharm"); var fetched := inst(gs,"c19701"); p.hand.append(fetched); gs.VerifiedRules.BondDream.fetched(gs,fetched)
	check(p.units[0].get("moonCharm",{}).is_empty(),"fetching is not drawing")

func moon_spells() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c19701"); check(gs.pending_choice.get("type")=="native-divination" and gs.pending_choice.count==2 and p.energy==29,"tide pauses for real divination before fire gain")
	choices(gs); check(p.energy==4,"tide gains1 after completed placements")
	gs=game(); p=gs.player(0); foe=gs.player(1)
	p.units[3].hp=1; p.units[3].moonCharm={"serial":1}; p.units[3].owlGuard={"sourceUid":p.units[2].uid}; p.units[3].treeHealthCombat=true
	p.units[3].insectCorrosion=1; gs._recalc(p.units[3])
	play(gs,"c19702",p.units[3].uid)
	check(p.units[3].hp==p.units[3].maxHp and not p.units[3].has("moonCharm") and not p.units[3].has("owlGuard") and not p.units[3].has("insectCorrosion") and p.units[3].treeHealthCombat,"full moon removes live charms, heals fully, preserves ability grants")
	foe.units[2].level=0; check(gs.valid_targets(0,Content.card_def("c19702")).has(foe.units[2].uid),"full moon can target living inactive enemy")
	gs._knockout_unit(foe.units[2]); check(not gs.valid_targets(0,Content.card_def("c19702")).has(foe.units[2].uid),"full moon excludes knocked targets")
	gs=game(); p=gs.player(0); p.units[0].erase("moonCharm"); var old := inst(gs,"c17601"); old.bambooDurabilityBonus=5; p.hand.append(old)
	p.deck.append(inst(gs,"c19702")); p.deck.append(inst(gs,"c19705")); var size_before: int=p.deck.size()
	play(gs,"c19703"); check(gs.pending_choice.get("type")=="moon-hand-top" and p.deck.size()==size_before-2 and not p.units[0].get("moonCharm",{}).is_empty(),"invite draws2 with base trigger before hand choice")
	check(not gs.resolve_divination_choice(1,str(old.instanceId)) and not gs.resolve_divination_choice(0,"missing"),"invite rejects wrong owner and stale ID")
	check(gs.resolve_divination_choice(0,str(old.instanceId)) and p.deck.back().instanceId==old.instanceId and p.deck.back().bambooDurabilityBonus==5 and not p.hand.has(old),"invite moves selected actual original instance and metadata to top")
	gs=game(); p=gs.player(0); foe=gs.player(1)
	gs._knockout_unit(foe.units[2]); gs._knockout_unit(p.units[2]); gs._begin_turn(0); gs._begin_turn(1); gs.current_player=0; p.levelUpUsed=true
	foe.units[2].hp=foe.units[2].maxHp; foe.units[2].knockout=0; p.units[2].hp=p.units[2].maxHp; p.units[2].knockout=0
	gs._knockout_unit(p.units[3]); gs._knockout_unit(foe.units[3]); play(gs,"c19704")
	check(foe.units[2].hp==0 and p.units[2].hp==0 and p.units[3].hp==p.units[3].maxHp and foe.units[3].hp==foe.units[3].maxHp,"rewind both sides uses previous start rather than current HP or current start")

func moon_fire_and_attack() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c19707"); check(p.units[0].attack==4 and p.units[0].maxHp==5 and not p.units[0].get("moonCharm",{}).is_empty(),"moon form4/5 enters with charm")
	p.energy=2; check(gs.basic_attack(0,3) and p.energy==1 and not p.units[0].get("moonCharm",{}).is_empty(),"first basic still uses ordinary action and fire")
	check(gs.basic_attack(0,2) and p.energy==1 and p.units[0].get("moonCharm",{}).is_empty(),"after action spent any ally can consume charm for free basic")
	check(not gs.can_basic_attack(0,2).ok,"extra basic cannot repeat without fresh charm")
	Moon.attach(gs,0,0); p.units[2].frozen=1; check(not gs.can_basic_attack(0,2).ok,"moon extra respects frozen attacker")
	p.units[2].frozen=0; p.energy=0; check(gs.can_basic_attack(0,2).ok,"extra basic legal with0fire")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.energy=2; foe.energy=1; give(gs,"c19705",1)
	check(gs.basic_attack(0,3) and p.energy==0 and foe.energy==0 and foe.hand.is_empty(),"normal basic2to1 triggers real enemy eclipse before combat")
	var resp: Array=gs.rule_events.filter(func(e):return e.kind=="response-card")
	check(resp.size()==1 and resp[0].trigger=="enemy-fire-one","fire trigger consumes actual response card exactly once")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.energy=3; foe.energy=1; give(gs,"c19705",1); gs._set_fire(0,2); gs._resolve_resolution_stack()
	check(foe.hand.size()==1 and p.energy==2,"fire transition not to1 does not respond")
	gs._set_fire(0,1); gs._resolve_resolution_stack(); check(p.energy==0 and foe.hand.is_empty(),"fire loss into1 does trigger response")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c19708"); check(p.realms[0].hp==5,"moon lock exact5durability")
	p.energy=4; play(gs,"c17601"); check(p.energy==0,"any real fire spending clears rest")
	p.energy=4; gs._set_fire(0,3); check(p.energy==3,"fire loss is not spending")
	foe.energy=4; play(gs,"c19705"); check(foe.energy==3,"eclipse active loss is not moon-lock spending")
	gs=game(); p=gs.player(0); play(gs,"c19708"); p.units[0].erase("moonCharm"); turn(gs,0); turn(gs,1)
	check(not p.units[0].get("moonCharm",{}).is_empty(),"moon lock attaches at owner start")

func bamboo_merge_search() -> void:
	var gs := game(); var p: Dictionary=gs.player(0)
	check(p.units[1].attack==1 and p.units[1].maxHp==5,"bamboo exact1/5")
	play(gs,"c17601"); var uid: String=p.realms[0].uid; play(gs,"c17602")
	check(p.realms.size()==1 and p.realms[0].hp==10 and p.realms[0].uid==uid and p.realms[0].bambooAbilities==["c17602"] and p.units[0].shield==0,"base merges durability, new ability replaces old without fake armor")
	play(gs,"c17606"); play(gs,"c17602"); play(gs,"c17604")
	check(p.units[1].attack==2 and p.units[1].maxHp==6 and p.realms[0].hp==20 and p.realms[0].bambooAbilities==["c17602","c17602","c17604"],"awake1/1 keeps existing ability and accumulates same/different abilities")
	gs=game(); p=gs.player(0); p.deck.clear()
	for id in Bamboo.cards(): p.deck.append(inst(gs,str(id)))
	var h := give(gs,"c17603"); check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==0,"five distinct in actual deck enhances search to instant")
	var target: Dictionary=p.deck[0]; target.bondMarks=[{"owner":0}]
	check(gs.play_card(0,h) and p.energy==30 and gs.pending_choice.instanceIds.size()==5,"instant search opens all real deck options")
	check(not gs.resolve_divination_choice(1,str(target.instanceId)),"search wrong owner rejected")
	check(gs.resolve_divination_choice(0,str(target.instanceId)) and p.hand.back().instanceId==target.instanceId and not p.hand.back().has("bondMarks") and p.hand.back().bambooDurabilityBonus==5,"fetch preserves instance, removes draw charms, grants actual durability")
	check(gs.hand_card_def(0,p.hand.size()-1).realm.hp==10,"search bonus shown on real hand card")
	check(gs.play_card(0,p.hand.size()-1) and p.realms[0].hp==10,"search bonus really deployed")
	h=give(gs,"c17603"); check(gs.effective_card_cost(0,gs.hand_card_def(0,h))==1,"four distinct is not enhanced")
	p.deck.clear(); check(not gs.can_play_card(0,h).ok,"empty realm pool cannot play search")
	gs=game(); p=gs.player(0)
	for id in Bamboo.cards(): play(gs,str(id))
	h=give(gs,"c17606"); check(gs.hand_card_def(0,h).enhanced,"summoned five distinct enhances awakening")
	check(gs.play_card(0,h) and p.realms.size()==1 and p.realms[0].hp==30 and p.realms[0].bambooAbilities.size()==6,"enhanced awakening summons all5 at1dur after enabling stack")
	gs=game(); p=gs.player(0); play(gs,"c17601"); play(gs,"c17601"); play(gs,"c17601"); play(gs,"c17601"); play(gs,"c17601")
	h=give(gs,"c17606"); check(not gs.hand_card_def(0,h).enhanced,"five same realm is not five distinct")

func bamboo_triggers() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	play(gs,"c17601"); p.units[0].hp=1; p.avatarHp=20; turn(gs,0)
	check(p.units[0].hp==2 and p.avatarHp==21,"shell heals all own characters at own end")
	p.units[0].hp=1; turn(gs,1); check(p.units[0].hp==1,"shell under10 does not heal at enemy end")
	play(gs,"c17601"); turn(gs,0); p.units[0].hp=1; turn(gs,1); check(p.units[0].hp==2,"shell10 heals at enemy end")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c17602"); var hp: int=foe.units[3].hp
	gs.VerifiedRules.Combat.strike(gs,1,3,0,-1,1,{}); check(foe.units[3].hp==hp-2,"rat avatar combat retaliates2")
	hp=foe.units[3].hp; gs.VerifiedRules.Combat.strike(gs,1,3,0,0,1,{})
	check(foe.units[3].hp==hp,"rat under10 no unit retaliation")
	play(gs,"c17602"); p.realms[0].hp=10; gs.VerifiedRules.Combat.strike(gs,1,3,0,0,1,{}); check(foe.units[3].hp==hp-1,"rat10 unit combat retaliates1")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c17602"); hp=foe.units[3].hp; p.units[0].shield=10
	gs.VerifiedRules.Combat.strike(gs,1,3,0,0,1,{}); gs._damage_avatar(0,1,1,3)
	check(foe.units[3].hp==hp,"zero actual combat and noncombat damage do not retaliate")
	gs=game(); p=gs.player(0); play(gs,"c17604"); turn(gs,0)
	var stone: Dictionary=p.units.back(); check(stone.get("bambooStone",false) and stone.attack==0 and stone.hp==5 and stone.front==1,"stone is real0/5 front summon")
	turn(gs,1); check(p.units.size()==5,"stone remains in front across turn retreat")
	gs.VerifiedRules.move_unit(gs,0,stone); Bamboo.remove_departed(gs); check(p.units.size()==5 and p.units.back()==stone and stone.removed and int(stone.hp)==0 and not gs.VerifiedRules.Rebirth.can_revive(stone) and not stone.has("weaverGrave"),"stone departure keeps stable tombstone without generic revival or true-death grave")
	gs=game(); p=gs.player(0); play(gs,"c17604"); play(gs,"c17604"); turn(gs,0)
	check(p.units.back().attack==4 and p.units.back().hp==5,"stone10 summons4/5")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c17605"); foe.units[2].front=1; var before: int=foe.units[2].hp; var reserve: int=foe.units[3].hp
	turn(gs,0); check(foe.units[2].hp==before-2 and foe.units[3].hp==reserve,"dragon projects2 to actual front, no reserve below10")
	var end_avatar: int=foe.avatarHp; turn(gs,1); check(foe.avatarHp==end_avatar-2,"dragon also projects at enemy end after front retreats")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c17605"); play(gs,"c17605"); var avatar: int=foe.avatarHp; reserve=foe.units[3].hp
	turn(gs,0); check(foe.avatarHp==avatar-2 and foe.units[3].hp==reserve-1,"dragon10 avatar projection then reserve1")
	gs=game(); p=gs.player(0); play(gs,"c17607"); p.energy=1; var deck: int=p.deck.size(); var energy: int=p.energy; turn(gs,0)
	check(p.deck.size()==deck-1 and p.energy==energy+1,"branch triggers at opponent start draw1+fire1")
	gs=game(); p=gs.player(0); play(gs,"c17607"); play(gs,"c17607"); p.energy=1; deck=p.deck.size(); energy=p.energy; turn(gs,0)
	check(p.deck.size()==deck-2 and p.energy==energy+2,"branch10 separately draws twice and gains twice")
	gs=game(); p=gs.player(0); play(gs,"c17608"); check(p.units[1].attack==5 and p.units[1].maxHp==5,"bamboo form5/5")
	turn(gs,0); check(p.realms.size()==1 and p.realms[0].hp==5,"form random realm at own end")
	turn(gs,1); check(p.realms.size()==1 and p.realms[0].hp==10,"form random realm also enemy end")
	gs=game(); p=gs.player(0); play(gs,"c17608"); play(gs,"c17601"); play(gs,"c17601"); play(gs,"c17601"); play(gs,"c17601")
	var health: int=p.units[1].hp; gs._damage_unit(0,1,100,1,3)
	check(p.units[1].hp==health and p.realms[0].hp==15,"20dur replaces full damage with maximum5realm loss")
	gs._damage_unit(0,1,1,1,3); check(p.units[1].hp==health-1 and p.realms[0].hp==15,"below20 next damage no replacement")

func boundaries_and_ai() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	gs._deploy_realm(0,Content.card_def("c19708")); play(gs,"c17601"); p.energy=30; play(gs,"c17602")
	check(p.realms.size()==2 and p.realms[0].nativeRealm=="moon-lock" and p.realms[1].hp==10,"bamboo merges only own five realms and keeps independent realm")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c17601"); gs._deploy_realm(0,Content.card_def("c19708")); p.realms[1].hp=2
	turn(gs,0); check(p.realms[0].hp==5 and p.realms[1].hp==3,"shell grows only other own realms")
	gs=game(); p=gs.player(0); play(gs,"c17604"); p.units[2].front=1; turn(gs,0)
	check(p.units.size()==4,"stone is not summoned into occupied front")
	gs=game(); p=gs.player(0); play(gs,"c17604"); turn(gs,0); var stone: Dictionary=p.units.back()
	gs._damage_unit(0,p.units.size()-1,10,1,3); gs._resolve_resolution_stack()
	check(p.units.size()==5 and p.units.back()==stone and stone.removed and stone.hp==0 and stone.knockout==0 and stone.has("weaverGrave") and not gs.VerifiedRules.Rebirth.can_revive(stone),"knocked stone keeps stable true-death archive without automatic generic revival")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c17602"); p.realms[0].hp=1; var hp: int=foe.units[3].hp
	gs.VerifiedRules.Combat.strike(gs,1,3,0,-1,2,{})
	check(p.realms.is_empty() and foe.units[3].hp==hp-2,"rat already earned retaliation survives realm breaking in same hit")
	gs=game(); p=gs.player(0); foe=gs.player(1); play(gs,"c17606"); play(gs,"c17602"); play(gs,"c17602"); p.units[3].front=1; foe.units[3].front=1
	hp=foe.units[3].hp; check(gs.basic_attack(0,3),"real attack exchange for accumulated rat")
	check(foe.units[3].hp==0 and p.units[3].hp>0,"two rat abilities independently retaliate after simultaneous combat")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.energy=2; foe.energy=1; give(gs,"c19705",1)
	play(gs,"c19701"); check(p.energy==0 and gs.pending_choice.get("type")=="native-divination" and foe.hand.is_empty(),"card-payment2to1 responds before tide divination")
	choices(gs); check(p.energy==1,"original tide resumes fire gain after eclipse and divination")
	gs=game(); p=gs.player(0); foe=gs.player(1); gs._deploy_realm(0,Content.card_def("c19708")); p.energy=2; foe.energy=1; give(gs,"c19705",1)
	check(gs.basic_attack(0,3) and p.energy==0 and foe.hand.size()==1,"moon lock2to0 does not invent intermediate1response")
	gs=game(); p=gs.player(0); play(gs,"c17608")
	for i in 4: gs._deploy_realm(0,Content.card_def("c17601"))
	p.units[1].shield=3; gs._damage_unit(0,1,5,1,3)
	check(p.units[1].hp==5 and p.units[1].shield==0 and p.realms[0].hp==18,"bamboo cover replaces only2damage left after3armor")
	gs=game(); p=gs.player(0); play(gs,"c19707"); p.attackUsed=true; p.energy=0; gs._knockout_unit(p.units[0])
	check(not gs.can_basic_attack(0,3).ok,"knocked source cannot offer moon extra attack")
	gs=game(); p=gs.player(0); p.units[0].erase("moonCharm"); p.deck.clear()
	var h := give(gs,"c17603"); check(AI._score_card(gs,0,gs.hand_card_def(0,h),null)<0,"AI avoids empty search pool")
	p.deck.append(inst(gs,"c17604")); check(gs.play_card(0,h) and AI._resolve_choice(gs,0) and p.hand.back().definitionId=="c17604","AI chooses actual legal realm from deck")
	p.hand.clear(); p.deck.append(inst(gs,"c17601")); p.deck.append(inst(gs,"c17602")); play(gs,"c19703"); check(gs.pending_choice.get("type")=="moon-hand-top","AI invite actually reaches hand choice"); choices(gs)
	gs=game(); p=gs.player(0); p.units[3].hp=1; h=give(gs,"c19702")
	check(AI._score_card(gs,0,gs.hand_card_def(0,h),p.units[3].uid)>0 and AI._score_card(gs,0,gs.hand_card_def(0,h),gs.player(1).units[3].uid)<0,"AI full moon prefers wounded friendly over enemy")
	h=give(gs,"c19704"); check(AI._score_card(gs,0,gs.hand_card_def(0,h),null)<0,"AI avoids rewind without beneficial previous state")

func ui_rules() -> void:
	root.size=Vector2i(1600,740)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	var b := Battle.new(); b.setup(["zhuiyueshen","huiyeji","xun","yaodaoji"],["zhuiyueshen","huiyeji","bingyong","bailang"],197176); b._ai_thinking=true
	for side in b.gs.players:
		side.hand.clear(); side.energy=30; side.levelUpUsed=true
		for unit in side.units: unit.level=3
	root.add_child(b); await create_timer(0.4).timeout
	var gs=b.gs; var p: Dictionary=gs.player(0)
	p.deck.clear()
	for id in Bamboo.cards(): p.deck.append(inst(gs,str(id)))
	hand(b,["c17603"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(gs.pending_choice.get("type")=="bamboo-deck" and faces(b._choice_layer).size()==5,"native search displays five original realm cards")
	await capture("01-five-real-realm-choices")
	await click(choice_face(b,"c17604")); await settled(b)
	check(gs.pending_choice.is_empty() and p.hand.size()==1 and p.hand[0].definitionId=="c17604" and gs.hand_card_def(0,0).realm.hp==10,"native chosen deck instance reaches hand with10dur")
	await click(b._hand_row.get_child(0)); await settled(b); check(p.realms.size()==1 and p.realms[0].hp==10,"native selected original realm deploys")
	hand(b,["c19703","c17601"]); var original: String=p.hand[1].instanceId; await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(gs.pending_choice.get("type")=="moon-hand-top" and faces(b._choice_layer).size()==3,"native invite shows old hand plus two drawn cards")
	await capture("02-invite-original-hand-top")
	await click(choice_face(b,"c17601")); await settled(b)
	check(gs.pending_choice.is_empty() and p.deck.back().instanceId==original,"native invite mouse choice puts actual old hand on top")
	await capture("03-original-realm-and-moon-hand")
	p.units[3].hp=1; p.units[3].moonCharm={"serial":99}
	hand(b,["c19702","c19707"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b._pending_target_card==0 and b._unit_widget(str(p.units[3].uid)).selected,"native full moon asks for actual shikigami target")
	await capture("04-full-moon-target-and-original-art")
	await click(b._unit_widget(str(p.units[3].uid))); await settled(b)
	check(p.units[3].hp==p.units[3].maxHp and not p.units[3].has("moonCharm"),"native full moon chosen target heals and loses charm")
	b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out=OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	moon_charm(); moon_spells(); moon_fire_and_attack(); bamboo_merge_search(); bamboo_triggers(); boundaries_and_ai()
	await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("MOON_BAMBOO checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
