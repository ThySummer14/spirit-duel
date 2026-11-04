extends "res://scripts/verify_sugar_cat.gd"
## One necessary native pass for the five newly sourced derived-card images.
## Full rules and two viewport interactions are covered by verify_sugar_cat.
func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme(); root.size = Vector2i(1280, 800)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	for id in ["cat-one", "cat-four", "cat-two", "sugar-small", "sugar-big"]:
		var def: Dictionary = Content.unit_def(id)
		check(def.get("token", false) and not def.get("selectable", true) and def.get("summoned", false) and not def.get("verificationPending", []).is_empty() and Content.cards_for_unit(id).is_empty() and not Content.playable_units().has(def), "derivedentity has no inventedconstructible entry " + id)
		check(ResourceLoader.exists("res://" + str(def.get("art", ""))), "derivedfulloriginal image actually imported " + id)
	var b := Battle.new(); b.setup(["maozhanggui", "yixigong", "bingyong", "shantong"], ["bingyong", "shantong", "bailang", "hetong"], 246249)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	root.add_child(b); await create_timer(0.4).timeout
	var gs = b.gs; var p: Dictionary = gs.player(0)
	hand(b, ["c24606"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	for entry in [["sc-cat-one", "one.png"], ["sc-cat-four", "four.jpg"], ["sc-cat-two", "two.png"]]:
		var face := choice_face(b, str(entry[0]))
		check(face != null and face._texture != null and face._texture_path == "res://assets/official/summons/" + str(entry[1]), "actualcat choice shows distinctoriginalart " + str(entry[0]))
	await capture("derived-01-three-cats")
	var tile := choice_face(b, "sc-cat-one"); if tile != null: await click(tile)
	await settled(b)
	check(front(gs).get("scCatType", "") == "one" and b._unit_widget(str(front(gs).uid))._texture_path == "res://assets/official/summons/one.png", "selectedone enters with realoriginalportrait")
	hand(b, ["c24903"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(front(gs).get("scCandy", false) and front(gs).attack == 2 and b._unit_widget(str(front(gs).uid))._texture_path == "res://assets/official/summons/small.png", "mastersmallcandy shows actual2/2originalart")
	feast(gs); b._last_view = {}; b._refresh(); await settled(b)
	await click(b._hand_row.get_child(0)); await click(b._unit_widget(str(p.units[0].uid))); await settled(b)
	check(front(gs).get("scBigCandy", false) and front(gs).attack == 6 and front(gs).hp == 6 and front(gs).unyielding and b._unit_widget(str(front(gs).uid))._texture_path == "res://assets/official/summons/big.png", "actualhandfeast fusesbigcandy and changes to correctoriginalart")
	await capture("derived-02-big-candy")
	b.queue_free(); await process_frame; await process_frame
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("SUGAR_CAT_ART checks=%d failures=%d" % [checks, failures]); quit(0 if failures == 0 else 1)
