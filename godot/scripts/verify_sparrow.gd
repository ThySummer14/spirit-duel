extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Sparrow := preload("res://scripts/sparrow_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("SPARROW_FAIL ",detail)

func game() -> GS:
	var gs:=GS.create(["rurineque","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],257)
	for p in gs.players:
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.night=0
		for u in p.units: u.level=3
	gs.rule_events.clear()
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"sparrow-%d" % gs.next_card_id}); gs.next_card_id+=1
	return gs.player(owner).hand.size()-1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual command "+id)

func count_events(gs, kind: String) -> int:
	return gs.rule_events.filter(func(e):return e.kind==kind).size()

func baseline_rules() -> void:
	var gs:=game(); var u: Dictionary=gs.player(0).units[0]
	check(u.attack==2 and u.maxHp==6,"basic body exact2/6")
	check(Content.unit_def("rurineque").passive.hooks.is_empty() and Content.unit_def("rurineque").awakenedPassive.hooks.is_empty(),"legacy front-only shield and fixed healing removed")
	for i in range(1,9):
		var id:="c2570%d" % i; var c:=Content.card_def(id)
		check(c.get("verifiedRules",false) and c.get("sparrowRules",false),"native complete card "+id)
		check(not c.get("verificationPending",[]).is_empty(),"unseen original boundaries retained "+id)
		check(c.cost==1 and not "简化" in c.text,"real cost and text "+id)
		check(FileAccess.file_exists("res://assets/official/cards/"+id+".png"),"original artwork "+id)
	gs.current_player=1; gs.player(0).night=2
	check(gs.end_turn(1) and gs.player(0).night==3 and u.shield==0,"real own start threshold2 gainsone but no same-threshold success")
	gs.player(0).night=3; Sparrow.turn_start(gs,0); gs._resolve_resolution_stack()
	check(u.shield==2 and gs.player(0).night==3 and int(u.front)==0,"ready-area basic receives exact2armor without consumingnight")
	for mode in ["dead","inactive","suppressed"]:
		gs=game(); u=gs.player(0).units[0]
		if mode=="dead": gs._knockout_unit(u)
		elif mode=="inactive": u.level=0
		else: u.baseRulesSuppressed=true
		Sparrow.turn_start(gs,0); gs._resolve_resolution_stack()
		check(gs.player(0).get("night",0)==0 and int(u.shield)==0,"basic inactive does not grow night "+mode)

func peck_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1)
	var u: Dictionary=p.units[0]; u.hp=1
	var h:=give(gs,"c25701"); var energy: int=p.energy
	check(gs.valid_targets(0,gs.hand_card_def(0,h)).size()==4,"peck targets all living hostile shikigami")
	check(not gs.play_card(0,h,p.units[1].uid) and p.energy==energy,"friendly peck rejected without payment")
	check(gs.play_card(0,h,foe.units[0].uid),"chosen peck command accepted")
	check(foe.units[0].hp==1 and u.hp==4 and p.night==1 and u.shield==0,"peck3 then restore3; below3 only night+1")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; p.night=3; u.hp=1
	for victim in foe.units: gs._grow_unit(victim,0,10)
	var before: Array=foe.units.map(func(v):return int(v.hp)); var selected: String=foe.units[0].uid
	play(gs,"c25701",selected)
	var damaged: Array=[]
	for i in foe.units.size():
		if int(foe.units[i].hp)<int(before[i]): damaged.append(i)
	check(damaged.size()==2 and damaged.has(0) and int(foe.units[0].hp)==int(before[0])-3,"night3 hits exactly one distinct secondary, never original again")
	check(u.hp==4 and u.shield==3 and p.night==3,"secondary gives actual3armor and threshold never spendsnight")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; u.hp=1; p.night=3
	foe.units[0].barrier=true
	for i in range(1,foe.units.size()): gs._knockout_unit(foe.units[i])
	play(gs,"c25701",foe.units[0].uid)
	check(u.hp==1 and u.shield==0 and not foe.units[0].barrier,"blocked primary gives no fabricated heal and no second target gives no armor")
	check(p.night==3 and count_events(gs,"night-triggered")==1,"empty secondary still evaluates its printed night clause")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; u.hp=1; foe.units[0].shield=2
	play(gs,"c25701",foe.units[0].uid)
	check(u.hp==2 and foe.units[0].hp==3,"armor reduces both actual peck damage and equal healing")
	foe.units[1].keywords=["veil"]
	check(not gs.valid_targets(0,Content.card_def("c25701")).has(foe.units[1].uid),"chosen peck respects hostile veil")
	for armor in [0,1,3]:
		gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; u.hp=1; foe.units[0].hp=1; foe.units[0].shield=armor
		play(gs,"c25701",foe.units[0].uid)
		check(u.hp==1+maxi(0,3-armor),"peck primary equal damage follows postarmor overkill contract armor%d" % armor)
		gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; p.night=3; foe.units[1].hp=1; foe.units[1].shield=armor
		for i in [2,3]: gs._knockout_unit(foe.units[i])
		play(gs,"c25701",foe.units[0].uid)
		check(u.shield==maxi(0,3-armor),"peck secondary equal armor follows postarmor overkill contract armor%d" % armor)

func silent_and_dawn_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	p.night=5; var hp: int=foe.avatarHp
	play(gs,"c25702")
	check(u.attack==3 and u.maxHp==6 and foe.avatarHp==hp,"silent exact3/6 and no invented entry projectile")
	gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(u.hp==0 and foe.avatarHp==hp-5 and u.formRules.is_empty(),"real knockout snapshot fires currentnight5 after form departs")
	gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(foe.avatarHp==hp-5,"already knocked source cannot repeat old deathform")
	var h:=give(gs,"c25703"); var c:=gs.hand_card_def(0,h)
	check(c.allowKnockedSource and gs.can_play_card(0,h).ok,"dawn genuinely legal while source knocked")
	check(c.value==0 and c.currentCardStats.contains("获得2护甲"),"dawn prints exact zero attack and oddnight floor2armor")
	check(gs.play_card(0,h),"actual knocked-source dawn command")
	check(u.hp==6 and u.knockout==0 and u.front==1 and foe.avatarHp==hp-7,"dawn revives basebody then actual2power battle")
	check(u.shield==2 and count_events(gs,"peach-revive")==1,"dawn armor from floornight and genuine revival event")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; p.night=9; foe.units[0].front=1; gs._grow_unit(foe.units[0],0,10)
	play(gs,"c25702"); hp=foe.units[0].hp; gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(foe.units[0].hp==hp-9 and foe.avatarHp==30,"silent projectile chooses actual front instead of avatar")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=1
	play(gs,"c25703")
	check(u.hp==6 and u.shield==0 and count_events(gs,"peach-revive")==0,"dawn alive remains playable without fake revival, night1 grantszeroarmor")
	gs._knockout_unit(u); u.samuraiCannotRevive=true
	h=give(gs,"c25703"); check(not gs.can_play_card(0,h).ok,"dawn cannot bypass permanent cannotrevive")

func court_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	play(gs,"c25704"); p.night=4; u.front=1; u.shield=30; gs._grow_unit(foe.units[0],2,12)
	var hp: int=u.shield; gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(p.night==5 and u.shield==hp-5 and int(foe.units[0].attack)==5,"court night4 gains1 but does not lower first attacker")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; play(gs,"c25704"); p.night=5; u.front=1; u.shield=30
	check(u.attack==4 and u.maxHp==7,"court exact4/7")
	gs._grow_unit(foe.units[0],2,12); foe.units[0].temporaryAttack=3; gs._recalc(foe.units[0]); hp=u.shield
	gs._resolve_combat(1,0,0,false,false,false,false); gs._resolve_resolution_stack()
	check(foe.units[0].attack==6 and u.shield==hp-6 and foe.units[0].get("sparrowCourtPenalty",0)==2,"court lowers actual attacker before current combat snapshot settles")
	check(p.night==5 and count_events(gs,"sparrow-court")==1,"court successful threshold neither grows nor consumesnight")
	Sparrow.end_turn(gs,1); gs._resolve_resolution_stack()
	check(foe.units[0].attack==8 and foe.units[0].temporaryAttack==3 and not foe.units[0].has("sparrowCourtPenalty"),"court clears only own -2 retaining unrelated temporary+3")
	gs._damage_unit(0,0,1,1,1); gs._resolve_resolution_stack()
	check(count_events(gs,"sparrow-court")==1,"noncombatdamage never substitutes for attacked condition")
	foe.units[0].temporaryAttack=-2; foe.units[0].sparrowCourtPenalty=2; gs._recalc(foe.units[0]); gs._knockout_unit(foe.units[0]); Sparrow.end_turn(gs,1); gs._resolve_resolution_stack()
	check(not foe.units[0].has("sparrowCourtPenalty") and int(foe.units[0].get("temporaryAttack",0))==0,"real knockout clears court debt without postdeath positive refund")

func harvest_and_awake_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20); p.night=6
	var reserve_hp: int=foe.units[1].hp; play(gs,"c25705")
	check(p.night==7 and foe.units[1].hp==reserve_hp and foe.units[0].hp==20,"harvest below7 addsnight only, then true+2 battle targetsfront")
	check(u.hp==4 and u.shield==0,"harvest gets exact+1combatarmor before3powercounter")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; p.night=7; foe.units[0].front=1; gs._grow_unit(foe.units[0],0,20)
	var before: Array=foe.units.map(func(v):return int(v.hp)); play(gs,"c25705")
	check(foe.units[0].hp==int(before[0])-4 and foe.avatarHp==30,"harvest never deals printed2AOE tofront/avatar")
	for i in range(1,foe.units.size()): check(foe.units[i].hp==int(before[i])-2,"harvest actual2damage to reserve index%d" % i)
	check(p.night==7 and u.attack==2,"harvest battlebonus is temporary and successfulnight remains7")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=4; play(gs,"c25706")
	check(u.awakened and u.attack==3 and u.maxHp==7 and u.front==0 and u.shield==0 and p.night==5,"awake threshold4 gainsnight but no falsemovement/shield, exact1/1")
	check(not gs.can_play_card(0,give(gs,"c25706")).ok,"already awakened unavailable to player andAI")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=5; p.units[1].front=1; play(gs,"c25706")
	check(u.front==1 and p.units[1].front==0 and u.awakened,"awake success performs actualfront displacement before awakening")
	p.night=2; Sparrow.turn_start(gs,0); gs._resolve_resolution_stack()
	check(p.night==4 and u.shield==0 and u.attack==3,"independent awakened3then7 failures each grow1 in order")
	p.night=6; Sparrow.turn_start(gs,0); gs._resolve_resolution_stack()
	check(p.night==7 and u.shield==2 and u.attack==3,"awakened first3succeeds then7fails at6 without earlygrowth")
	Sparrow.turn_start(gs,0); gs._resolve_resolution_stack()
	check(u.attack==4 and u.maxHp==8 and u.sparrowPermanentHp==1 and p.night==7,"next true7 grants exact permanent1/1")
	gs._knockout_unit(u); gs.VerifiedRules.Peach.revive(gs,0,3,u,false,false)
	check(u.attack==4 and u.maxHp==8,"explicit permanent awakenedgrowth survives knockout andrevive")

func substitute_rules() -> void:
	for night in [0,1,5,10]:
		var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; p.night=night
		var h:=give(gs,"c25707"); var c:=gs.hand_card_def(0,h)
		check(c.value.attack==night and c.value.hp==night and c.value.setBase,"substitute hand enhancement exactnight%d" % night)
		check(Content.card_def("c25707").value.attack==0 and Content.card_def("c25707").value.hp==0,"dynamic enhancement never changes shared0/0")
		check(gs.play_card(0,h),"real enhanced form command atnight%d" % night)
		if night==0:
			check(u.hp==6 and u.attack==2 and u.formRules.is_empty() and u.knockout==0,"zero0/0 immediately consumes substitute, returns alive2/6")
		else:
			check(u.attack==night and u.maxHp==night and u.hp==night,"positive substitute installs true%d/%d" % [night,night])
			u.front=1; u.swift=true; u.temporaryAttack=3; u.enraged=true; u.shield=1; u.barrier=false; u.frozen=1; gs._recalc(u)
			gs.VerifiedRules.Maple.attach(gs,1,0,u)
			var death_before:=count_events(gs,"kill-recorded"); var revive_before:=count_events(gs,"peach-revive")
			var hit: Dictionary=gs._damage_unit(0,0,99,1,0); gs._resolve_resolution_stack()
			check(u.hp==6 and u.maxHp==6 and u.attack==2 and u.front==1 and u.knockout==0,"substitute replaces knockout and preservesfront atnight%d" % night)
			check(not hit.knocked and u.swift and u.formRules.is_empty() and not u.has("mapleDoll") and not u.get("enraged",false) and u.frozen==0,"substitute stripsform/charm/temporaryability, preserves unspent swift")
			check(count_events(gs,"kill-recorded")==death_before and count_events(gs,"peach-revive")==revive_before,"substitute emits neither death nor revival")
			gs._damage_unit(0,0,99,1,0); gs._resolve_resolution_stack()
			check(u.hp==0 and u.knockout>0,"consumed substitute cannot save anotherhit")
	var direct:=game(); direct.player(0).night=5; play(direct,"c25707")
	check(not direct.VerifiedRules.Panguan.destroy(direct,1,0,0,0) and direct.player(0).units[0].hp==6 and count_events(direct,"unit-destroyed")==0,"direct destruction consumes substitute without false kill result")
	var gs:=game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[0]; p.night=7
	play(gs,"c25706"); Sparrow.turn_start(gs,0); gs._resolve_resolution_stack(); play(gs,"c25707")
	gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(u.awakened and u.hp==8 and u.maxHp==8 and u.attack==4,"substitute retains own awakening and explicit permanent growth")

func nest_and_ai_rules() -> void:
	var gs:=game(); var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); var u: Dictionary=p.units[0]
	gs._knockout_unit(p.units[1]); p.night=9; play(gs,"c25708")
	check(p.realms.size()==1 and p.realms[0].hp==5 and p.realms[0].nativeRealm=="sparrow-nest","nightnest is real5durability realm")
	check(p.units[1].hp==p.units[1].maxHp and p.units[1].knockout==0 and p.night==10,"entry actually revives one then failnight9 to10")
	check(foe.units.all(func(v):return int(v.hp)>0),"reaching10 from failure does not immediately destroyenemy")
	gs._knockout_unit(p.units[2]); foe.units[1].shield=99; foe.units[1].barrier=true
	for i in [0,2,3]: gs._knockout_unit(foe.units[i])
	Sparrow.trigger_realm(gs,0,p.realms[0]); gs._resolve_resolution_stack()
	check(p.units[2].hp==p.units[2].maxHp and foe.units[1].hp==0,"ownstart real randomrevive then true10 harddestroy through99armor/barrier")
	var revived:=count_events(gs,"peach-revive"); Sparrow.trigger_realm(gs,0,p.realms[0]); gs._resolve_resolution_stack()
	check(count_events(gs,"peach-revive")==revived and p.night==10,"emptyrevive and emptyenemy pools safely retain realm/night")
	gs=game(); p=gs.player(0); foe=gs.player(1); u=p.units[0]; p.night=10; u.level=1
	p.deck.clear(); p.hand.clear(); give(gs,"c25708"); var iid: String=p.hand[0].instanceId
	p.energy=0; var played: int=p.cardsPlayedThisTurn
	Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.hand.is_empty() and p.realms.size()==1 and p.energy==0 and p.cardsPlayedThisTurn==played,"auto movesactualhand realm atlevel1 withoutpayment or cardplay")
	check(gs.rule_events.any(func(e):return e.kind=="sparrow-nest-moved" and e.instanceId==iid and e.zone=="hand"),"automove preserves origin instance in observable movementevent")
	give(gs,"c25708"); Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.realms.size()==1 and p.hand.size()==1,"present realm blocks duplicate automovement")
	gs=game(); p=gs.player(0); u=p.units[0]; p.night=10; u.level=1; p.hand.clear(); p.deck=[{"definitionId":"c25708","instanceId":"nest-deck-real"}]
	Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.deck.is_empty() and p.realms.size()==1 and count_events(gs,"sparrow-nest-moved")==1,"auto also moves exact existingdeck instance")
	gs=game(); p=gs.player(0); p.night=9; give(gs,"c25708"); Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.realms.is_empty() and p.hand.size()==1 and p.night==9,"night9 end condition neither moves nor gainsnight")
	gs._knockout_unit(p.units[0]); p.night=10; Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.realms.size()==1 and p.hand.is_empty(),"knocked source does not forbid card moving itself from hand")
	for mode in ["inactive","suppressed"]:
		gs=game(); p=gs.player(0); p.night=10; u=p.units[0]; p.deck.clear(); p.hand.clear(); give(gs,"c25708")
		if mode=="inactive": u.level=0
		else: u.baseRulesSuppressed=true
		p.energy=0; var plays_before: int=p.cardsPlayedThisTurn
		Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
		check(p.realms.size()==1 and p.hand.is_empty() and p.energy==0 and p.cardsPlayedThisTurn==plays_before,"autonomous card movement ignores manualplay source gate "+mode)
	gs=game(); p=gs.player(0); p.night=10; u=p.units[0]; give(gs,"c25708"); u.removed=true
	Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.realms.is_empty() and p.hand.size()==1,"genuinely removed original source cannot own automatic cardtrigger")
	gs=game(); p=gs.player(0); p.night=10; p.hand.clear(); p.deck.clear(); Sparrow.end_turn(gs,0); gs._resolve_resolution_stack()
	check(p.realms.is_empty() and count_events(gs,"sparrow-nest-moved")==0,"empty hand anddeck never fabricate missing nightnest")
	gs=game(); p=gs.player(0); foe=gs.player(1); p.night=3; give(gs,"c25701")
	var best: Dictionary=AI._best_card(gs,0)
	check(best.ok and gs.valid_targets(0,gs.hand_card_def(0,int(best.hand))).has(best.target),"AIpeck chooses legal nonveil hostile shikigami")
	check(gs.play_card(0,int(best.hand),best.target),"AIpeck command resolves actual rules")
	gs=game(); p=gs.player(0); gs._knockout_unit(p.units[0]); give(gs,"c25703"); best=AI._best_card(gs,0)
	check(best.ok and gs.play_card(0,int(best.hand),best.target) and p.units[0].hp>0,"AI legally uses dawn from realknockout")
	gs=game(); p=gs.player(0); p.night=10; give(gs,"c25707"); best=AI._best_card(gs,0)
	check(best.ok and gs.play_card(0,int(best.hand),best.target) and p.units[0].maxHp==10,"AI true enhancedsubstitute form")
	for i in range(1,9):
		gs=game(); p=gs.player(0); p.night=10; var id:="c2570%d" % i
		if i==8: gs._knockout_unit(p.units[1])
		give(gs,id); best=AI._best_card(gs,0)
		check(best.ok and gs.can_play_card(0,int(best.hand),best.target).ok,"AI exact legal command for "+id)
		check(best.ok and gs.play_card(0,int(best.hand),best.target),"AI actual resolution for "+id)

func ui_rules() -> void:
	root.theme=ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b:=Battle.new(); b.setup(["rurineque","fenghuanghuo","baizangzhu","taohuayao"],["yaodaoji","bingyong","fenghuanghuo","baizangzhu"],257)
		b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.night=0
			for unit in p.units: unit.level=3
		root.add_child(b); await create_timer(0.5).timeout
		var gs=b.gs; var p: Dictionary=gs.player(0); var foe: Dictionary=gs.player(1); p.night=3; p.units[0].hp=1
		hand(b,["c25701"]); await settled(b); await click(b._hand_row.get_child(0))
		check(b._pending_target_card==0,"mousepeck enters actual targetUI")
		var energy: int=p.energy
		await click(b._unit_widget(str(p.units[1].uid)))
		check(b._pending_target_card==0 and p.energy==energy,"mousepeck rejects friendlytarget withoutpayment")
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(p.hand.is_empty() and foe.units[0].hp==1 and p.units[0].hp==4 and p.units[0].shield==3,"mouse chosenprimary plus actualrandomsecondary healingarmor")
		gs._knockout_unit(p.units[0]); gs._resolve_resolution_stack(); p.night=9
		hand(b,["c25703"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.hand.is_empty() and p.units[0].hp==6 and p.units[0].front==1 and p.units[0].shield==4,"mouse dawn fromdead actualrevival combat and floorarmor")
		hand(b,["c25707","c25708"]); await settled(b)
		check(b._hand_row.get_child(0).data.value.attack==9 and b._hand_row.get_child(0).data.value.hp==9,"mousecard face displaysdynamic9/9 enhancedform")
		await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[0].maxHp==9 and p.units[0].formRules.get("sparrowSubstitute",false),"mouse form attaches actualsubstitute")
		await capture("%d-sparrow-night-substitute" % physical.x)
		gs._damage_unit(0,0,99,1,0); gs._resolve_resolution_stack(); b._last_view={}; b._refresh(); await settled(b)
		check(p.units[0].hp==6 and p.units[0].front==1 and p.units[0].formRules.is_empty(),"mousedashboard updates actualsubstitutedeathreplacement")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores:=Support.isolate_stores()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out=arg; DirAccess.make_dir_recursive_absolute(out); break
	baseline_rules(); peck_rules(); silent_and_dawn_rules(); court_rules(); harvest_and_awake_rules(); substitute_rules(); nest_and_ai_rules()
	if not OS.get_cmdline_user_args().has("--rules-only"): await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("SPARROW checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
