extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Blessing := preload("res://scripts/upgrade_blessing_rules.gd")

func game() -> GS:
	var gs := GS.create(["huibishou","yaodaoji","yingcao","qingxingdeng"],["bingyong","yingcao","yaodaoji","qingfangzhu"],20917)
	for p in gs.players:
		p.hand.clear(); p.energy = 20; p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs

func give(gs, id: String) -> int:
	gs.player(0).hand.append({"definitionId":id,"instanceId":"ebisu-test-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(0).hand.size()-1

func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actual play "+id)

func rules() -> void:
	for enhanced in [false,true]:
		var gs := game(); var p: Dictionary = gs.player(0)
		p.units[2].level = 3 if enhanced else 2
		var h := give(gs,"c20902"); var target: Dictionary = gs.player(1).units[0]
		var power := int(target.attack); var top: String = p.deck.back().instanceId
		check(gs.hand_card_def(0,h).value == (5 if enhanced else 1),"omen real all-team threshold")
		check(not gs.can_play_card(0,h,"avatar-1").ok,"omen excludes avatars")
		check(gs.play_card(0,h,target.uid) and target.attack == power+(5 if enhanced else 1) and p.hand.back().instanceId == top,"omen can buff selected enemy and draws real top")
		gs._knockout_unit(target)
		check(target.attack == power,"ordinary omen growth clears on knockout")
	var gs := game(); var p: Dictionary = gs.player(0); var target: Dictionary = p.units[1]
	play(gs,"c20903")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 6,"revival form replaces base body with3/6")
	target.level = 1; gs._knockout_unit(target); p.levelUpUsed = false
	check(gs.level_up(0,1) and target.hp == target.maxHp and target.knockout == 0,"real upgrade revives knocked ally")
	check(target.maxHp == target.baseMaxHp,"dead-at-upgrade target does not gain living-only base blessing")
	gs._knockout_unit(p.units[0]); gs._knockout_unit(target); gs.raise_unit_level(0,1)
	check(target.hp == 0,"knocked form source cannot revive")
	gs = game(); p = gs.player(0); target = p.units[1]; target.level = 2
	var h := give(gs,"c20904")
	check(not gs.can_play_card(0,h,p.units[0].uid).ok and not gs.can_play_card(0,h,gs.player(1).units[0].uid).ok,"temporary level excludes self and enemy")
	check(gs.play_card(0,h,target.uid) and target.level == 3,"temporary level raises only chosen unit")
	for id in ["c10105","c10107"]:
		check(not gs.can_play_card(0,give(gs,id)).ok,"temporary restriction blocks form and spell-typed awakening "+id)
	check(gs.can_play_card(0,give(gs,"c10106")).ok,"temporary restriction still permits ordinary high-level spells")
	gs.players = JSON.parse_string(JSON.stringify(gs.players)); p = gs.player(0); target = p.units[1]
	check(gs.end_turn(0) and target.level == 2 and not target.has("blessingRestrictedTurn"),"serialized temporary upgrade expires at actual end turn")
	gs = game(); p = gs.player(0); target = p.units[1]; target.level = 1
	play(gs,"c20904",target.uid); gs.raise_unit_level(0,1); gs._resolve_resolution_stack()
	gs.end_turn(0); check(target.level == 2,"temporary rollback preserves a later permanent upgrade")
	gs = game(); p = gs.player(0); target = p.units[1]; target.level = 2
	play(gs,"c20906")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 8,"sea form replaces base with3/8")
	p.deck = [{"definitionId":"c10701","instanceId":"other-bottom"},{"definitionId":"c10103","instanceId":"owned-original"}]
	p.levelUpUsed = false; check(gs.level_up(0,1),"sea triggered by actual ordinary upgrade")
	var drawn: Dictionary = p.hand.back()
	check(drawn.instanceId == "owned-original" and p.deck.size() == 1 and drawn.blessingInstant,"sea searches matching original instance without drawing another owner")
	var stamp := JSON.stringify(gs.snapshot()); var view: Dictionary = gs.hand_card_def(0,p.hand.size()-1)
	check(gs.card_payment(0,view).usesInstant and JSON.stringify(gs.snapshot()) == stamp,"searched instance has real instant with read-only queries")
	check(gs.play_card(0,p.hand.size()-1) and p.keywordUsage.instant.used,"searched card actually consumes shared instant")
	check(gs.command_log.filter(func(c):return c.c=="play_card").back().a.cardView.blessingInstant,"dynamic instant preserved in replay card view")
	p.units[2].level = 2; p.deck.clear(); gs.raise_unit_level(0,2); gs._resolve_resolution_stack()
	check(gs.winner < 0 and p.hand.is_empty(),"missing sea search is not an empty-deck draw loss")
	gs = game(); p = gs.player(0); target = p.units[1]
	play(gs,"c20907"); p.levelUpUsed = false
	var power := int(target.attack); var hp := int(target.maxHp)
	check(gs.is_upgrade_pending(0) and gs.can_level_up(0,1),"realm permits real all-three upgrade phase")
	check(gs.level_up(0,1) and target.level == 3 and target.attack == power+5 and target.maxHp == hp+6,"three-level upgrade grants permanent5/5 plus ordinary base blessing without level4")
	check(p.hand.size() == 1 and Content.card_def(str(p.hand[0].definitionId)).unitId == target.id and int(Content.card_def(str(p.hand[0].definitionId)).level) == 3,"realm generates only chosen owner's three-level card")
	gs._knockout_unit(target)
	check(target.attack == power+5 and target.maxHp == hp+5,"permanent realm growth survives while ordinary blessing clears")
	gs.VerifiedRules.Huang.destroy(gs,0,p.realms[0],"test")
	check(not Blessing.can_raise(gs,0,target),"realm destruction removes overlevel permission")
	gs = game(); p = gs.player(0); p.units[1].level = 1; p.units[2].level = 2
	play(gs,"c20908")
	check(p.units[1].level == 2 and p.units.filter(func(u):return int(u.level)==3).size() == 3,"wander recalculates minimum before second random upgrade")
	check(gs.rule_events.filter(func(e):return e.kind=="blessing-level-raised").size() == 2,"wander resolves exactly two upgrades")
	gs = game(); p = gs.player(0); play(gs,"c20907"); p.hand.clear(); p.levelUpUsed = false
	check(AI.take_action(gs,0) and p.levelUpUsed and p.units.any(func(u):return int(u.get("blessingPermanentAttack",0))==5),"AI performs permitted three-level upgrade")
	gs = game(); p = gs.player(0); p.units[1].level = 2
	give(gs,"c20904"); give(gs,"c10107")
	check(int(Blessing.score_card(gs,0,gs.hand_card_def(0,0),p.units[1].uid)) == -100,"AI does not boost solely to use forbidden awakening")

func prepare(b, ids: Array) -> void:
	b.setup(["huibishou","yaodaoji","yingcao","qingfangzhu"],["bingyong","yingcao","yaodaoji","qingfangzhu"],20917)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 10; p.levelUpUsed = true
		for u in p.units: u.level = 3
	hand(b,ids)
	await settled(b)

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():out = OS.get_cmdline_user_args()[0]
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	rules()
	root.theme = ThemeBuilder.build_theme(); root.size = Vector2i(1600,740)
	var b := Battle.new(); b.setup(["huibishou"],["bingyong"],20917); b._ai_thinking = true; root.add_child(b)
	await prepare(b,["c20903","c20904","c10105","c10107","c10106"])
	await click(b._hand_row.get_child(0)); await settled(b)
	var p: Dictionary = b.gs.player(0); var target: Dictionary = p.units[1]
	target.level = 2; b.gs._knockout_unit(target); b._refresh(); await settled(b)
	await click(b._hand_row.get_child(0))
	check(b._pending_target_card == 0,"mouse temporary upgrade enters target mode")
	await click(b._unit_widget(str(p.units[0].uid)))
	check(b._pending_target_card == 0,"mouse self target rejected")
	await click(b._unit_widget(str(target.uid))); await settled(b)
	check(target.hp > 0 and target.level == 3,"mouse temporary upgrade revives actual knocked target")
	check(not b._hand_row.get_child(0).enabled and not b._hand_row.get_child(1).enabled and b._hand_row.get_child(2).enabled,"hand UI blocks form/awakening and permits ordinary spell")
	b._on_unit_hover(true,0,1)
	check(texts(b._tooltip).contains("福笹"),"inspector explains temporary restriction")
	await capture("01-temporary-revival"); b._hide_tooltip()
	await click(b._end_btn); await settled(b)
	check(target.level == 2 and not target.has("blessingRestrictedTurn"),"real end button rolls back temporary level")
	await prepare(b,["c20906"])
	p = b.gs.player(0); target = p.units[1]; target.level = 2
	p.deck = [{"definitionId":"c10103","instanceId":"ui-sea-original"}]
	await click(b._hand_row.get_child(0)); await settled(b)
	p.levelUpUsed = false; b._refresh(); await settled(b)
	await click(b._unit_widget(str(target.uid))); await settled(b)
	check(p.hand.size() == 1 and p.hand[0].instanceId == "ui-sea-original" and b._hand_row.get_child(0).play_aura_kind() == "instant","real sea search produces usable blue instant hand card")
	await capture("02-sea-search-instant")
	await prepare(b,["c20907"])
	p = b.gs.player(0); target = p.units[1]
	await click(b._hand_row.get_child(0)); await settled(b)
	p.levelUpUsed = false; b._refresh(); await settled(b)
	check(texts(b._cmd_bar).contains("十日戎"),"all-three phase explains overlevel instead of level4")
	await click(b._unit_widget(str(target.uid))); await settled(b)
	check(p.levelUpUsed and target.level == 3 and p.hand.size() == 1,"mouse overlevel grants real card and spends upgrade opportunity")
	await capture("03-overlevel-upgrade")
	b.queue_free(); Support.cleanup_audio(); await process_frame; Support.cleanup_stores(stores)
	print("HUIBISHOU checks=%d failures=%d" % [checks,failures]); quit(0 if failures == 0 else 1)
