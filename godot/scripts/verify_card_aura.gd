extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")

func game() -> GS:
	var gs := GS.create(["huibishou", "yaodaoji", "yingcao", "qingfangzhu"], ["huibishou", "bingyong", "yingcao", "qingfangzhu"], 20917)
	for p in gs.players:
		p.hand.clear()
		p.energy = 8
		p.levelUpUsed = true
		for u in p.units: u.level = 1
	gs.player(0).units[0].level = 2
	return gs

func give(gs, id: String) -> int:
	gs.player(0).hand.append({"definitionId": id, "instanceId": "aura-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(0).hand.size() - 1

func rules() -> void:
	var gs := game()
	var p: Dictionary = gs.player(0)
	var target: Dictionary = p.units[1]
	var hp := int(target.maxHp)
	check(gs.play_card(0, give(gs, "c20905")), "actual awakening play")
	check(p.units[0].awakened and target.maxHp == hp and not target.get("inspired", false), "awakening grants its own body without immediate team buff")
	p.levelUpUsed = false
	check(gs.level_up(0, 1), "ordinary upgrade triggers blessing")
	check(target.attack == int(target.baseAttack) + 1 and target.maxHp == hp + 1 and target.inspired, "upgraded ally receives exact stats and actual inspired")
	p.attackUsed = true
	p.energy = 1
	check(gs.can_basic_attack(0, 1).ok and gs.basic_attack(0, 1), "inspired permits basic attack after shared attack used")
	check(p.energy == 0 and p.attackUsed and not target.has("inspired"), "inspired spends fire, preserves used shared allowance and consumes itself")
	p.energy = 1
	check(not gs.can_basic_attack(0, 1).ok, "no second inspired attack after consumption")
	gs = game(); p = gs.player(0); target = p.units[1]
	gs.VerifiedRules.Combat.grant_inspired(gs, 0, 1)
	check(gs.play_card(0, give(gs, "c10101")) and target.inspired, "combat card does not spend inspired")
	p.energy = 0; p.attackUsed = false
	check(not gs.can_basic_attack(0, 1).ok and target.inspired, "inspired alone does not waive ghost fire")
	target.swift = true
	check(gs.basic_attack(0, 1) and p.energy == 0 and not p.attackUsed and not target.get("inspired", false) and not target.swift, "swift and inspired independently waive both resources once")
	for mode in ["base", "knocked-source", "paper-source", "knocked-target", "enemy"]:
		gs = game(); p = gs.player(0); target = p.units[1]
		hp = int(target.maxHp)
		if mode == "knocked-source": gs._knockout_unit(p.units[0])
		if mode == "paper-source": p.units[0].baseRulesSuppressed = true
		if mode == "knocked-target": gs._knockout_unit(target)
		gs.raise_unit_level(1 if mode == "enemy" else 0, 1)
		check(target.maxHp == hp + (1 if mode == "base" else 0) and not target.get("inspired", false), "upgrade condition " + mode)
	gs = game(); p = gs.player(0)
	gs.play_card(0, give(gs, "c20905"))
	var h := give(gs, "c20901")
	var card: Dictionary = gs.hand_card_def(0, h)
	var stamp := JSON.stringify(gs.snapshot())
	check(gs.valid_targets(0, card).size() == 3 and not gs.valid_targets(0, card).has(p.units[0].uid), "2025 blessing targets only lowest allies")
	check(not gs.can_play_card(0, h, p.units[0].uid).ok and JSON.stringify(gs.snapshot()) == stamp, "invalid high target rejected without state changes")
	var deck_size: int = p.deck.size()
	check(gs.play_card(0, h, p.units[2].uid), "selected lowest ally plays new blessing")
	check(p.units[2].level == 2 and p.units[2].inspired and p.deck.size() == deck_size - 1, "blessing upgrades chosen ally then draws actual top")
	check(gs.player(1).units.filter(func(u): return int(u.level) == 2).size() == 1, "blessing upgrades exactly one random lowest enemy")
	gs.players = JSON.parse_string(JSON.stringify(gs.players))
	check(gs.VerifiedRules.Combat.has(gs.player(0).units[2], "inspired"), "inspired survives serialization")
	gs._knockout_unit(gs.player(0).units[2])
	check(not gs.player(0).units[2].get("inspired", false), "knockout clears one-use inspired")
	gs = game(); p = gs.player(0)
	gs.play_card(0, give(gs, "c20905")); give(gs, "c20901")
	check(AI.take_action(gs, 0) and p.units.filter(func(u): return int(u.level) == 2).size() == 2, "AI chooses a legal blessing target")
	gs = game(); p = gs.player(0); p.attackUsed = true; p.energy = 1
	gs.VerifiedRules.Combat.grant_inspired(gs, 0, 1)
	check(AI.take_action(gs, 0) and p.energy == 0 and not p.units[1].get("inspired", false), "AI uses inspired after shared attack spent")
	gs = GS.create(["huibishou", "yaodaoji", "yingcao", "qingfangzhu"], ["rihefang", "bingyong", "yingcao", "qingfangzhu"], 20917)
	for side in gs.players:
		side.hand.clear(); side.energy = 4; side.levelUpUsed = true
		for u in side.units: u.level = 2
	p = gs.player(0); target = p.units[1]; target.level = 1
	gs.player(1).hand.append({"definitionId": "c16602", "instanceId": "upgrade-response"})
	hp = int(target.hp)
	check(gs.play_card(0, give(gs, "c20901"), target.uid) and target.level == 2 and target.frozen == 2 and target.hp == hp, "card upgrade triggers Sun response; own-turn stun lasts through next turn")
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 3 and gs.rule_events.filter(func(e): return e.kind == "response-card" and e.trigger == "enemy-upgraded").size() == 1, "upgrade response pays and triggers once")

func frames(count: int) -> void:
	for i in count: await process_frame

func aura_face(b, id: String):
	for face in b._hand_row.get_children():
		if face.data.id == id: return face
	return null

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out = OS.get_cmdline_user_args()[0]
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	rules()
	root.theme = ThemeBuilder.build_theme()
	root.size = Vector2i(1600, 740)
	var b := Battle.new()
	b.setup(["huibishou", "yaodaoji", "yingcao", "qingfangzhu"], ["bingyong", "yingcao", "yaodaoji", "qingfangzhu"], 20917)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 4; p.levelUpUsed = true
		for u in p.units: u.level = 2
	root.add_child(b)
	hand(b, ["c10702", "c10703", "c20905", "c20901"])
	await settled(b)
	check(aura_face(b, "c10702").play_aura_kind() == "instant" and aura_face(b, "c20905").play_aura_kind() == "inspired", "real hand shows distinct blue and yellow eligibility")
	await frames(60)
	await capture("01-blue-yellow-ready")
	await click(aura_face(b, "c10702"))
	await settled(b)
	check(aura_face(b, "c10703").play_aura_kind().is_empty(), "actual instant payment extinguishes remaining blue aura")
	await click(aura_face(b, "c20905"))
	await settled(b)
	check(aura_face(b, "c20901").play_aura_kind() == "inspired", "real awakening enables related blessing yellow aura")
	b.gs.player(0).units[1].level = 1
	b.gs.player(0).units[2].level = 1
	b._refresh()
	await frames(15)
	await click(aura_face(b, "c20901"))
	check(b._pending_target_card >= 0, "real click opens blessing target selection")
	await click(b._unit_widget(str(b.gs.player(0).units[0].uid)))
	check(b._pending_target_card >= 0, "high-level target click remains pending")
	await click(b._unit_widget(str(b.gs.player(0).units[1].uid)))
	await settled(b)
	var target: Dictionary = b.gs.player(0).units[1]
	check(b._pending_target_card == -1 and target.inspired, "real lowest target click upgrades and grants inspired")
	check(b._unit_widget(str(target.uid)).play_aura_kind() == "inspired", "actual inspired unit shows yellow aura")
	await frames(60)
	await capture("02-inspired-unit")
	b.gs.player(0).units[2].level = 2
	b.gs.player(0).units[2].frozen = 1
	b.gs.player(0).keywordUsage.instant.used = false
	b._refresh()
	await frames(10)
	check(aura_face(b, "c10703").play_aura_kind().is_empty(), "stunned owner blocks blue despite unused instant allowance")
	await click(b._unit_widget(str(target.uid)))
	await click(b._enemy_target_btn)
	await settled(b)
	check(not target.get("inspired", false) and b._unit_widget(str(target.uid)).play_aura_kind().is_empty(), "real ordinary attack consumes inspired and yellow aura")
	await capture("03-after-consumption")
	await frames(15)
	b.queue_free()
	Support.cleanup_audio()
	await process_frame
	Support.cleanup_stores(stores)
	print("CARD_AURA checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
