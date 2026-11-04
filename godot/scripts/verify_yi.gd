extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Yi := preload("res://scripts/yi_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("YI_FAIL ", detail)

func settled(b) -> void:
	for i in 3: await process_frame
	while b._input_locked(): await create_timer(b._presentation_remaining() + 0.05).timeout
	await create_timer(0.30).timeout

func game(lineup: Array = []) -> GS:
	var gs := GS.create(["yi","shuweng","huajing","taohuayao"] if lineup.is_empty() else lineup, ["bingyong","huang","yaodaoji","baizangzhu"], 239)
	for p in gs.players:
		p.hand.clear(); p.deck.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.rule_events.clear(); return gs

func inst(gs, id: String) -> Dictionary:
	var item := {"instanceId":"yi-test-%d" % gs.next_card_id,"definitionId":id}
	gs.next_card_id += 1; return item

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(inst(gs,id)); return gs.player(owner).hand.size() - 1

func deck(gs, ids: Array, owner: int = 0) -> void:
	gs.player(owner).deck.clear()
	for id in ids: gs.player(owner).deck.append(inst(gs,str(id)))

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner,give(gs,id,owner),target),"actual use " + id)

func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)

func first_card(unit: String, type: String = "") -> String:
	for c in Content.cards_for_unit(unit):
		if (type == "" or str(c.type) == type) and not c.get("token", false): return str(c.id)
	return ""

func finish(gs, owner: int = 0) -> void:
	var guard := 0
	while not gs.pending_choice.is_empty() and guard < 50:
		guard += 1
		check(AI._resolve_choice(gs,owner),"real AI choice resumes " + str(gs.pending_choice.get("type","")))
	check(guard < 50,"all continuations terminate")

func bottom_divination(gs) -> String:
	check(gs.pending_choice.get("type") == "native-divination","real shuffle waits for divination before follow-up")
	if gs.pending_choice.get("type") != "native-divination": return ""
	var iid := str(gs.pending_choice.instanceIds[0])
	check(gs.resolve_divination_choice(0,iid) and gs.resolve_divination_choice(0,gs.VerifiedRules.Divination.BOTTOM),"player may change forthcoming draw by bottoming the revealed actual card")
	return iid

func passive() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var u: Dictionary = p.units[0]
	check(u.attack == 2 and u.maxHp == 5 and u.passive_hooks.is_empty(),"printed2/5 without old turn-start draw")
	deck(gs,["c23902","c23908","c23901"])
	gs.hand_card_def(0,give(gs,"c23902")); p.hand.clear()
	check(events(gs,"yi-shuffle-divination").is_empty(),"hand preview never invokes shuffle ability")
	var pool: Array = p.deck.duplicate(true); gs._shuffle(pool); gs._resolve_resolution_stack()
	check(gs.pending_choice.is_empty() and not u.has("yiDivinationTurn"),"random candidate shuffle is not actual deck shuffle")
	gs._shuffle(p.deck); check(gs.pending_choice.is_empty(),"shuffle schedules ability instead of opening nested choice")
	gs._resolve_resolution_stack(); check(gs.pending_choice.get("type") == "native-divination" and gs.pending_choice.count == 1,"own deck shuffle opens actual divination1")
	finish(gs); gs._shuffle(gs.player(1).deck); gs._resolve_resolution_stack()
	check(gs.pending_choice.is_empty() and events(gs,"yi-shuffle-divination").size() == 1,"opposing deck shuffle cannot repeat same-turn passive")
	gs = game(); p = gs.player(0); u = p.units[0]; u.awakened = true; deck(gs,["c23901","c23902","c23903"])
	gs._shuffle(gs.player(1).deck); gs._resolve_resolution_stack()
	check(gs.pending_choice.get("count") == 2,"opposing deck shuffle also causes awakened divination2")
	finish(gs)
	for state in ["knocked","unleveled","suppressed","enemy-turn"]:
		gs = game(); p = gs.player(0); u = p.units[0]; deck(gs,["c23901","c23902"])
		if state == "knocked": gs._knockout_unit(u,1,0)
		if state == "unleveled": u.level = 0
		if state == "suppressed": u.baseRulesSuppressed = true
		if state == "enemy-turn": gs.current_player = 1
		gs._shuffle(p.deck); gs._resolve_resolution_stack()
		check(gs.pending_choice.is_empty(),"inactive or off-turn source cannot divine: " + state)
	gs = game(); p = gs.player(0); p.units[0].frozen = 1; deck(gs,["c23901"])
	gs._shuffle(p.deck); gs._resolve_resolution_stack()
	check(gs.pending_choice.get("type") == "native-divination","stun does not suppress passive")
	finish(gs)

func long_think() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	var h := give(gs,"c23901")
	check(not gs.can_play_card(0,h).ok,"long think alone has no hand card to return")
	var kept := inst(gs,"c23908"); kept.opaqueEnhancement = {"value":7}; kept.revealed = true; p.hand.append(kept)
	deck(gs,["c23902","c23903","c23904","c23906","c23908","c23901"])
	check(gs.play_card(0,h) and gs.pending_choice.get("type") == "yi-long-think","long think starts real hand choice")
	var choice_view: Dictionary = Yi.choice_card(gs,0,str(kept.instanceId))
	check(choice_view.value.attack == 4 and choice_view.value.hp == 4 and choice_view.playedInstance.opaqueEnhancement.value == 7,"long think choice displays dynamic body and the selected instance enhancement")
	var fire := int(p.energy)
	check(not gs.resolve_divination_choice(1,str(kept.instanceId)) and not gs.resolve_divination_choice(0,"invented"),"foreign and fabricated hand choices rejected")
	check(p.energy == fire and p.hand.size() == 1,"invalid choice changes neither hand nor fire")
	check(gs.resolve_divination_choice(0,str(kept.instanceId)),"selected actual hand instance returns")
	check(p.hand.is_empty() and p.deck.any(func(i): return i.instanceId == kept.instanceId and i.opaqueEnhancement.value == 7 and not i.get("revealed",false)),"return preserves instance enhancement and clears reveal")
	check(gs.pending_choice.get("type") == "native-divination" and p.yiLongThinkDraws.size() == 1,"shuffle ability precedes future draw, no immediate fake draw2")
	finish(gs); var before: int = p.deck.size()
	gs._knockout_unit(p.units[0],1,0); gs.resolution_stack.clear(); deck(gs,["c23902","c23908"],1)
	check(gs.end_turn(0) and gs.end_turn(1),"advance real turns after source knockout")
	check(p.deck.size() == before - 3 and p.hand.size() == 3 and p.yiLongThinkDraws.is_empty(),"next own start draws extra2 plus normal1 even with Yi knocked")

func combat_and_damage() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	gs._grow_unit(foe.units[0],20,20); foe.units[0].front = 1
	play(gs,"c23902"); check(p.units[0].hp == 0,"unshuffled征子 receives actual counterdamage")
	gs = game(); p = gs.player(0); foe = gs.player(1); deck(gs,["c23901","c23908"])
	gs._grow_unit(foe.units[0],20,20); foe.units[0].front = 1
	gs._shuffle(foe.deck); gs._resolve_resolution_stack(); finish(gs)
	var before := int(foe.units[0].hp); play(gs,"c23902")
	check(p.units[0].hp == 5 and foe.units[0].hp == before - 4,"any actual deck shuffle enables printed+2 battle with combat immunity")
	gs._damage_unit(0,0,3,1,0); check(p.units[0].hp == 2,"combat immunity never prevents later spell damage")
	gs = game(); p = gs.player(0); foe = gs.player(1); deck(gs,["c23901","c23902"])
	var dedicated := first_card("bingyong"); give(gs,dedicated,1); give(gs,first_card("yaodaoji"),1)
	foe.units[0].barrier = true; var hand_id := str(foe.hand[0].instanceId)
	play(gs,"c23903",foe.units[0].uid)
	check(foe.units[0].hp == foe.units[0].maxHp and foe.hand.size() == 1 and foe.deck.any(func(i): return str(i.instanceId) == hand_id),"zero damage from barrier still returns one real dedicated card")
	check(gs.pending_choice.get("type") == "native-divination","enemy hand return shuffles the actual enemy deck")
	finish(gs)
	gs = game(); foe = gs.player(1); give(gs,first_card("bingyong"),1); foe.units[0].hp = 1
	play(gs,"c23903",foe.units[0].uid)
	check(foe.units[0].hp == 0 and foe.hand.size() == 1 and foe.deck.is_empty(),"lethal target never returns dedicated card")
	gs = game(); foe = gs.player(1); foe.units[0].keywords = ["veil"]; h_target_check(gs,foe.units[0].uid)

func h_target_check(gs, veil_id: String) -> void:
	var h := give(gs,"c23903"); var card: Dictionary = gs.hand_card_def(0,h)
	check(not gs.valid_targets(0,card).has(veil_id) and not gs.can_play_card(0,h,"avatar-1").ok and not gs.can_play_card(0,h,gs.player(0).units[0].uid).ok,"氣合 rejects veil, avatar and friendly targets")

func search_and_awakening() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	var special := inst(gs,"c11908"); special.opaqueEnhancement = {"value":9}; p.deck.append(special); p.deck.append(inst(gs,"c23908"))
	gs._knockout_unit(p.units[1],1,0); gs.resolution_stack.clear()
	var h := give(gs,"c23904"); var card: Dictionary = gs.hand_card_def(0,h)
	check(gs.valid_targets(0,card).has(p.units[1].uid) and not gs.valid_targets(0,card).has(p.units[0].uid),"search allows knocked other teammate but never Yi himself")
	check(gs.play_card(0,h,p.units[1].uid) and gs.pending_choice.instanceIds == [special.instanceId],"search shows actual selected teammate deck instances")
	check(gs.resolve_divination_choice(0,str(special.instanceId)) and p.hand.size() == 1 and p.hand[0].instanceId == special.instanceId and p.hand[0].opaqueEnhancement.value == 9,"selected physical card fetched with enhancement intact")
	check(events(gs,"yi-shuffle-divination").is_empty(),"search does not invent a shuffle")
	gs = game(); p = gs.player(0); deck(gs,["c23902","c23903","c23906","c23908"])
	give(gs,"c23901"); var h_awake := give(gs,"c23905")
	check(gs.play_card(0,h_awake) and gs.pending_choice.type == "book-dispatch" and not p.units[0].awakened,"awakening first opens genuine three-opportunity dispatch")
	var rejected := str(p.hand[0].instanceId)
	check(gs.resolve_divination_choice(0,rejected),"actual hand dispatch exchanges one card")
	check(gs.resolve_divination_choice(0,gs.VerifiedRules.BookJue.FINISH),"dispatch may finish early")
	check(gs.pending_choice.get("type") == "native-divination" and gs.pending_choice.count == 1 and not p.units[0].awakened,"dispatch return shuffles before the following awakening effect")
	finish(gs)
	check(p.units[0].awakened and p.units[0].attack == 3 and p.units[0].maxHp == 6,"awakening completes printed+1/+1 after dispatch/divination")
	check(not gs.can_play_card(0,give(gs,"c23905")).ok,"repeated awakening rejected")

func heal_and_body() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); p.avatarHp = 20
	deck(gs,["c23901","c23908","c23903"]); var top := str(p.deck.back().instanceId); var h := give(gs,"c23906"); var original := str(p.hand[h].instanceId)
	check(gs.play_card(0,h),"real heal/draw/return spell")
	check(p.avatarHp == 23 and p.hand.size() == 1 and p.hand[0].instanceId == top and p.deck.any(func(i): return i.instanceId == original),"heals3 then draws former top before returning same source card")
	check(gs.pending_choice.get("type") == "native-divination" and p.deck.size() == 3,"return spell shuffles only after draw and uses exact same instance")
	finish(gs)
	gs = game(); p = gs.player(0); p.avatarHp = 20; play(gs,"c23906")
	check(gs.winner == 1 and p.deck.is_empty(),"empty deck draw loses before the spell can return itself")
	for size in [0,1,2,5,10]:
		gs = game(); p = gs.player(0)
		for i in size: p.deck.append(inst(gs,"c23902"))
		var idx := give(gs,"c23908"); var card: Dictionary = gs.hand_card_def(0,idx); var body := 1 + int(size / 2)
		check(card.value.attack == body and card.value.hp == body,"form hand enhancement reads exact deck size " + str(size))
		check(gs.play_card(0,idx) and p.units[0].attack == body and p.units[0].maxHp == body,"actual form body is snapshot of current deck " + str(size))
		p.deck.append(inst(gs,"c23902")); gs._recalc(p.units[0]); check(p.units[0].attack == body,"later deck changes do not mutate installed form")

func replay() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	deck(gs,["c23901","c23902","c23908"])
	var form_id := first_card("shuweng","form"); var h := give(gs,form_id)
	p.hand[h].opaqueEnhancement = {"value":11}; p.hand[h].linkedUse = true; p.hand[h].linkOtherId = "gone"; p.hand[h].linkRetrieve = true; p.hand[h].linkedByUid = p.units[1].uid
	var iid := str(p.hand[h].instanceId)
	check(gs.play_card(0,h),"install true allied form instance before review")
	var enemy_form := first_card("bingyong","form"); gs.current_player = 1; play(gs,enemy_form,null,1)
	var enemy_iid := str(foe.units[0].form.cardInstance.instanceId)
	var sea := ""
	for c in Content.cards_for_unit("huang"):
		if c.get("realm",{}).get("nativeRealm") == "huang-sea": sea = str(c.id)
	check(sea != "","actual return-on-destroy realm exists")
	play(gs,sea,null,1); var realm_iid := str(foe.realms[0].cardInstance.instanceId); gs.current_player = 0
	var destroyed := events(gs,"realm-destroyed").size(); play(gs,"c23907")
	check(p.units[1].form.is_empty() and foe.units[0].form.is_empty() and foe.realms.is_empty(),"review really removes both sides' forms and realms")
	var returned: Dictionary = {}
	for entry in p.deck:
		if str(entry.instanceId) == iid: returned = entry
	check(not returned.is_empty() and returned.opaqueEnhancement.value == 11 and not returned.has("linkedUse") and not returned.has("linkOtherId"),"physical form returns with enhancement but no one-use link fields")
	check(foe.deck.any(func(i): return i.instanceId == enemy_iid) and foe.deck.any(func(i): return i.instanceId == realm_iid) and foe.hand.is_empty(),"opposing state instances return to owner's deck; sea does not falsely return to hand")
	check(events(gs,"realm-destroyed").size() == destroyed and events(gs,"yi-shuffle-divination").size() == 1,"review wash is not destruction and multi-card return causes one ability")
	finish(gs)
	gs = game(); p = gs.player(0); p.units[1].form = {"cardId":"unmapped-transform","name":"non-card transformation","attackBonus":0,"hpBonus":0}
	play(gs,"c23907")
	check(p.deck.is_empty() and not p.deck.any(func(i): return i.definitionId == "unmapped-transform"),"untracked non-card transformation cannot fabricate undefined deck cards")

func shuffle_continuations() -> void:
	var gs := game(["yi","liangmianfo","shuweng","taohuayao"])
	var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	deck(gs,["c23801","c23901","c23902","c23908"])
	var h := give(gs,"c23802"); var hp: int = foe.units[0].hp
	check(gs.play_card(0,h,foe.units[0].uid) and gs.pending_choice.get("type") == "native-link","real two faces hand use opens link before Yi ability")
	var original := str(gs.pending_choice.options[0].instanceId)
	check(gs.resolve_divination_choice(0,original) and gs.play_card(0,h,foe.units[0].uid),"confirm original physical link card then commit use")
	check(foe.units[0].hp == hp and gs.pending_choice.get("type") == "native-divination","Link.take shuffle suspends actual selected card damage")
	bottom_divination(gs)
	check(foe.units[0].hp == hp - 3 and events(gs,"yi-shuffle-divination").size() == 1 and gs.resolution_stack.is_empty(),"linked damage resumes once after divination without orphan frames")
	gs = game(["yi","jue","shuweng","taohuayao"]); p = gs.player(0); foe = gs.player(1)
	deck(gs,["c23902","c23903","c23908"]); deck(gs,["c23901","c23908"],1)
	var victim := inst(gs,first_card("bingyong")); victim.revealed = true; foe.hand.append(victim)
	play(gs,"c12003")
	check(gs.pending_choice.get("type") == "book-dispatch" and gs.resolve_divination_choice(0,str(victim.instanceId)),"real strong-arm dispatch exchanges revealed enemy hand card")
	check(gs.pending_choice.get("type") == "native-divination","dispatch finishes automatically after only revealed enemy card is exchanged")
	check(p.hand.is_empty() and gs.pending_choice.get("type") == "native-divination" and gs.resolution_stack.any(func(f):return f.get("kind") == "yi-draw"),"dispatch follow-up draw pauses despite synchronous BookJue caller")
	var bottomed := bottom_divination(gs)
	check(p.hand.size() == 1 and p.hand[0].instanceId != bottomed and gs.resolution_stack.is_empty(),"dispatch extra draw uses rearranged Yi deck and resumes exactly once")
	gs = game(["yi","xieji","shuweng","taohuayao"]); p = gs.player(0)
	deck(gs,["c23901","c23902","c23908"]); var selected := inst(gs,"c21002"); p.hand.append(selected)
	play(gs,"c21001")
	check(gs.pending_choice.get("type") == "crab-sleep" and gs.resolve_divination_choice(0,str(selected.instanceId)),"real sleep choice copies actual selected crab card")
	check(p.deck.size() == 6 and p.hand.size() == 1 and gs.pending_choice.get("type") == "native-divination","three copies are shuffled before deferred sleep draw; original stays in hand")
	bottomed = bottom_divination(gs)
	check(p.hand.size() == 2 and p.hand[0].instanceId == selected.instanceId and p.hand[1].instanceId != bottomed and p.deck.size() == 5,"sleep draws after player rearrangement without duplicating original instance")
	gs = game(["yi","jieshen","shuweng","taohuayao"]); p = gs.player(0)
	deck(gs,["c23901","c23902","c23908"])
	for id in ["c23903","c11908","c21602"]: give(gs,id)
	play(gs,"c21607")
	check(p.hand.is_empty() and p.deck.size() == 6 and gs.pending_choice.get("type") == "native-divination","bond-together candidate shuffle does not fire passive; actual deck shuffle precedes draw3")
	check(events(gs,"yi-shuffle-divination").size() == 1,"random candidate pool and actual deck produce exactly one Yi ability")
	bottomed = bottom_divination(gs)
	check(p.hand.size() == 3 and p.deck.size() == 3 and not p.hand.any(func(i):return i.instanceId == bottomed) and gs.resolution_stack.is_empty(),"bond draw3 and per-card charms complete after divination with no stale continuation")
	var status := preload("res://scripts/ui/battle_status.gd")
	var view: Dictionary = status.unit_view(gs,0,0,0)
	check(view.yiMarks.size() == 1 and str(view.yiMarks[0]).contains("已触发") and status.unit_marks(view,gs.turn_counter).any(func(m):return m.id == "yi-rule"),"battle status projects real once-per-turn passive consumption")

func puppet_review() -> void:
	var gs := game(["yi","kuileishi","shuweng","taohuayao"])
	var p: Dictionary = gs.player(0); deck(gs,["c23901","c23908"])
	play(gs,"c23102"); play(gs,"c23103")
	var carrier: Dictionary = p.units[1].form.puppetInstance.duplicate(true)
	play(gs,"c23907")
	check(p.units[1].form.is_empty() and p.get("puppetRemoved",[]).is_empty(),"review removes fusion without falsely registering a destroyed form")
	var returned: Dictionary = p.deck.filter(func(i):return i.instanceId == carrier.instanceId)[0]
	check(returned.puppetComponents == carrier.puppetComponents and returned.puppetFusionCount == carrier.puppetFusionCount and returned.puppetAttack == carrier.puppetAttack and returned.puppetHp == carrier.puppetHp,"review preserves actual fused carrier body, components and fusion count")
	finish(gs)
	play(gs,"c23904",p.units[1].uid)
	var choice_view: Dictionary = Yi.choice_card(gs,0,str(carrier.instanceId))
	check(gs.pending_choice.type == "yi-search" and choice_view.puppetInstance.puppetComponents == carrier.puppetComponents and choice_view.value.attack == carrier.puppetAttack and choice_view.value.hp == carrier.puppetHp and str(choice_view.currentCardStats).contains("已融合"),"deck search displays original fused body and component state instead of a fresh printed card")
	check(gs.resolve_divination_choice(0,str(carrier.instanceId)),"search retrieves the actual fused carrier from deck")
	check(gs.play_card(0,p.hand.size()-1) and p.units[1].form.puppetInstance.instanceId == carrier.instanceId and p.units[1].form.puppetInstance.puppetComponents == carrier.puppetComponents,"returned fusion can be used as the same playable instance with inherited abilities")
	gs = game(["yi","biyehua","shuweng","taohuayao"]); p = gs.player(0)
	var lily := inst(gs,"c11902"); p.deck.append(lily)
	p.realms.append({"uid":"yi-choice-road","hp":5,"nativeRealm":"lily-road"})
	play(gs,"c23904",p.units[2].uid)
	choice_view = Yi.choice_card(gs,0,str(lily.instanceId))
	check(choice_view.sourceZone == "deck" and not choice_view.has("lilyRoadDamage") and not choice_view.get("lilyFromDeck",false) and not choice_view.keywords.has("instant"),"ordinary deck search neither claims hand-only road enhancement nor deck-top use permission")
	check(gs.resolve_divination_choice(0,str(lily.instanceId)) and gs.hand_card_def(0,0).get("lilyRoadDamage",0) == 1,"same fetched instance gains actual hand enhancement only after entering hand")
	gs = game(["yi","kuileishi","shuweng","taohuayao"]); p = gs.player(0); deck(gs,["c23901","c23908"])
	play(gs,"c23106"); play(gs,"c23102"); carrier = p.units[1].form.puppetInstance.duplicate(true)
	play(gs,"c23907"); finish(gs)
	check(p.deck.any(func(i):return i.instanceId == carrier.instanceId) and p.units[1].form.puppetInstance.instanceId != carrier.instanceId and p.units[1].form.puppetInstance.puppetComponents == [gs.VerifiedRules.Puppet.AWAKEN_FORM],"review returns old awakened fusion once while permanent awakening reinstalls a separate real carrier")

func ai_cards() -> void:
	for n in range(23901,23909):
		var gs := game(); var p: Dictionary = gs.player(0); var id := "c%d" % n
		deck(gs,["c11902","c11908","c23903","c23908","c23902"])
		if n == 23901: give(gs,"c10101")
		var h := give(gs,id); var card: Dictionary = gs.hand_card_def(0,h)
		var targets: Array = [null] if card.target == "auto" else gs.valid_targets(0,card)
		check(not targets.is_empty() and gs.can_play_card(0,h,targets[0]).ok,"actual legal card/target available to AI " + id)
		var selected: Dictionary = AI._best_card(gs,0)
		check(selected.ok and selected.card_id == id and gs.play_card(0,int(selected.hand),selected.target,bool(selected.get("origin",false))),"real AI selection and command actually use " + id)
		finish(gs)
		check(not Content.card_def(id).get("verificationPending",[]).is_empty(),"client pending remains explicit " + id)

func ui_rules() -> void:
	for n in range(23901,23909):
		var face := preload("res://scripts/ui/card_face.gd").new(); face.data = Content.card_def("c%d" % n); face.refresh_art()
		check(face._original_card != null and face._original_card.resource_path == "res://assets/official/cards/c%d.png" % n,"native original texture " + str(n)); face.free()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["yi","shuweng","kuileishi","taohuayao"],["bingyong","huang","yaodaoji","baizangzhu"],239); b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.deck.clear(); side.energy = 40; side.levelUpUsed = true
			for unit in side.units: unit.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var p: Dictionary = b.gs.player(0); deck(b.gs,["c23902","c23903","c23908","c11908"])
		hand(b,["c23901","c23908"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b.gs.pending_choice.get("type") == "yi-long-think" and faces(b._choice_layer).size() == 1,"native long think shows actual remaining hand")
		var hand_choice: Dictionary = choice_face(b,"c23908").data
		check(hand_choice.value.attack == 3 and hand_choice.value.hp == 3 and str(hand_choice.currentCardStats).contains("当前3/3"),"native hand choice presents the current enhanced form body")
		await capture("%d-01-long-think" % physical.x)
		await click(choice_face(b,"c23908")); await settled(b)
		check(b.gs.pending_choice.get("type") == "native-divination","native hand return resumes into divination")
		var guard := 0
		while not b.gs.pending_choice.is_empty() and guard < 8:
			guard += 1; await click(choice_face(b)); await settled(b)
		check(guard < 8,"native divination choices terminate")
		check(p.hand.is_empty() and p.yiLongThinkDraws.size() == 1,"native long think returns one card without premature draw")
		hand(b,["c23904"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(p.units[1].uid).selected and not b._unit_widget(p.units[0].uid).selected,"native search highlights only other teammate with real deck cards")
		await click(b._unit_widget(p.units[1].uid)); await settled(b)
		check(b.gs.pending_choice.get("type") == "yi-search" and faces(b._choice_layer).size() == 1,"native search opens actual dedicated deck option")
		await capture("%d-02-dedicated-search" % physical.x)
		await click(choice_face(b)); await settled(b)
		check(p.hand.size() == 1 and p.hand[0].definitionId == "c11908","native selected card physically enters hand")
		for id in ["c23102","c23103"]:
			hand(b,[id]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		var carrier: Dictionary = p.units[2].form.puppetInstance.duplicate(true)
		check(carrier.puppetComponents.size() == 2 and int(carrier.puppetFusionCount) == 1,"native actual form uses create one fused carrier")
		hand(b,["c23907"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(p.units[2].form.is_empty() and p.deck.any(func(i):return i.instanceId == carrier.instanceId),"native review returns the actual fusion to deck")
		hand(b,["c23904"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(b._unit_widget(p.units[2].uid)); await settled(b)
		var fusion_choice: Dictionary = choice_face(b).data
		check(b.gs.pending_choice.get("type") == "yi-search" and fusion_choice.value.attack == carrier.puppetAttack and fusion_choice.value.hp == carrier.puppetHp and fusion_choice.puppetInstance.puppetComponents == carrier.puppetComponents and str(fusion_choice.currentCardStats).contains("已融合1次"),"native deck choice shows original fusion body, count and components")
		await capture("%d-03-fused-search" % physical.x)
		await click(choice_face(b)); await settled(b)
		check(p.hand.size() == 1 and p.hand[0].instanceId == carrier.instanceId and p.hand[0].puppetComponents == carrier.puppetComponents,"native search selects the same fusion instance with all inherited components")
		b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	passive(); long_think(); combat_and_damage(); search_and_awakening(); heal_and_body(); replay(); shuffle_continuations(); puppet_review(); ai_cards()
	if not only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("YI_OK checks=%d failures=%d rules_only=%s" % [checks,failures,only]); quit(0 if failures == 0 else 1)
