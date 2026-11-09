extends "res://scripts/verify_insight.gd"

const Paper := preload("res://scripts/paper_dance_rules.gd")
const Twin := preload("res://scripts/twin_sight_rules.gd")
const Sand := preload("res://scripts/sand_book_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const CHARM_TEAM := ["zhiwu", "ertong", "alaina", "fenghuanghuo"]
const CHARM_ENEMY := ["bingyong", "xuenv", "fenghuanghuo", "yaodaoji"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CHARM_REALMS_FAIL ", detail)

func charm_game(team: Array = CHARM_TEAM) -> GS:
	var gs := GS.create(team, CHARM_ENEMY, 633)
	prepare(gs)
	return gs

func card_in_deck(gs: GS, owner: int, id: String) -> Dictionary:
	var inst := {"definitionId": id, "instanceId": "charm-deck-%d" % gs.next_card_id}
	gs.next_card_id += 1
	gs.player(owner).deck.append(inst)
	return inst

func choose_divination(gs: GS, to_top: String = "") -> void:
	for i in 20:
		if gs.pending_choice.get("type", "") != "native-divination": return
		if gs.pending_choice.has("selected"):
			var position := "divination-place-top" if gs.pending_choice.selected == to_top else "divination-place-bottom"
			check(gs.resolve_divination_choice(0, position), "place exact divination instance")
		else:
			check(gs.resolve_divination_choice(0, str(gs.pending_choice.instanceIds[0])), "select revealed divination instance")

func paper_rules() -> void:
	var gs := charm_game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var paper: Dictionary = p.units[0]
	var ally: Dictionary = p.units[1]
	var attack: int = ally.attack
	play(gs, "c63301", ally.uid)
	check(ally.paperFall and ally.attack == attack+1 and ally.shield == 1 and ally.swift, "blade attaches fall, grants armor and gives swift to 青岚")
	check(foe.avatarHp == 29, "base projects for an ally's fall")
	play(gs, "c63301", ally.uid)
	check(ally.attack == attack+1 and ally.shield == 2 and foe.avatarHp == 29, "nonstacking fall and one projectile per turn")
	gs.VerifiedRules.Moon.attach(gs, 0, 1)
	gs.VerifiedRules.WaterMoon.grant(gs, 0, ally, "waterReturnLight", "溯光")
	check(ally.attack == attack+3, "three distinct friendly charms make fall grant three power")
	check(Status.unit_view(gs, 0, 1, 0).paperFall, "live battle status includes fall")
	play(gs, "c63302")
	check(gs.pending_choice.count == 1, "divination count is carriers, not total charms")
	choose_divination(gs)
	play(gs, "c63303")
	var hp: int = paper.hp
	foe.units[2].front = 1
	foe.units[2].attack = 15
	foe.units[2].hp = 14
	play(gs, "c63301", paper.uid)
	check(paper.front == 1 and paper.hp == hp and foe.units[2].hp == 11, "form attacks once with real combat immunity")
	play(gs, "c63301", paper.uid)
	check(foe.units[2].hp == 11, "form does not attack twice in one turn")
	play(gs, "c63304", ally.uid)
	check(paper.awakened and paper.attack == 4 and Paper.charms(0, ally) == 3, "awakening installs both fall charms and printed body")
	play(gs, "c63305", foe.units[2].uid)
	check(foe.units[2].hp <= 5, "swallow is printed four plus two friendly carriers")
	play(gs, "c63306")
	check(gs.VerifiedRules.HairPower.guard_count(gs, 0) == 1 and p.guardDeployments[0].armor == 2, "lodge grants real armor guard")
	gs.VerifiedRules.Movement.move_to(gs, 0, 3, 1)
	gs._resolve_resolution_stack()
	check(p.units[3].paperFall, "moving into combat attaches fall")
	play(gs, "c63308")
	check(p.hand.size() == 1 and gs.hand_card_def(0, 0).id == "c63301" and gs._kw(gs.hand_card_def(0, 0), "instant"), "form grants a real instant blade")
	ally.erase("moonCharm")
	ally.erase("waterReturnLight")
	check(gs.play_card(0, 0, ally.uid) and ally.has("moonCharm") and ally.waterReturnLight, "replay restores historically attached native charms")
	foe.units[2].hp = 30
	foe.units[2].front = 1
	play(gs, "c63307")
	check(foe.units[2].hp == 0, "stacked hearts deal lethal combat to actual 红莲 opponent")
	foe.units[0].hp = 30
	foe.units[0].front = 1
	play(gs, "c63307")
	check(foe.units[0].hp > 0, "ordinary non-red opponent is not instantly defeated")

func twin_rules() -> void:
	var gs := charm_game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var enemy: Dictionary = foe.units[2]
	play(gs, "c63306")
	play(gs, "c63101")
	check(p.realms[0].cardId == "c63101" and p.realms[0].hp == 1 and Twin.cat(gs, 0).attack == 2, "welcome enters first and summons original 2/2")
	var health: int = foe.avatarHp
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "测试离场")
	gs._resolve_resolution_stack()
	check(foe.avatarHp == health - 2, "welcome leave makes the existing cat attack")
	gs.VerifiedRules.Movement.move_to(gs, 0, 0, 1)
	check(Twin.cat(gs, 0).is_empty(), "cat leaves when the front position is replaced")
	gs._resolve_resolution_stack()
	play(gs, "c63105")
	var spirit := Twin.cat(gs, 0)
	check(spirit.attack == 3 and spirit.hp == 3, "third real realm use makes next cat 3/3")
	var patrol: Dictionary = p.realms.filter(func(r): return r.cardId == "c63105")[0]
	check(patrol.hp in [4, 7], "patrol has real durability and wears once per allied entry")
	play(gs, "c63101")
	check(patrol.hp >= 4 and Twin.cat(gs, 0).uid == spirit.uid, "new welcome preserves the existing cat and patrol does not repeat this turn")
	var top := card_in_deck(gs, 0, "c63105")
	play(gs, "c63102")
	check(gs.pending_choice.get("type", "") == "native-divination", "keeper entry opens native divination")
	choose_divination(gs, str(top.instanceId))
	check(p.hand.has(top), "divining a realm to the top draws that real instance")
	play(gs, "c63103")
	check(gs.pending_choice.instanceIds.size() == 3, "discover displays three distinct instances")
	check(not gs.resolve_divination_choice(0, "not-offered") and AI.take_action(gs, 0), "discover rejects invalid choices and AI chooses a legal offered instance")
	var new_realm := card_in_deck(gs, 0, "c63306")
	var new_spell := card_in_deck(gs, 0, "c63301")
	play(gs, "c63106")
	check(p.hand.has(new_realm) and new_realm.twinInstantTurn == gs.turn_counter and p.hand.has(new_spell) and not new_spell.has("twinInstantTurn"), "incense buffs only actual newly drawn realms")
	play(gs, "c63104")
	check(p.units[1].awakened and p.units[1].attack == 3 and p.units[1].maxHp == 6, "awakening gives printed stats on the current form")
	enemy.baseMaxHp = 20
	enemy.maxHp = 20
	enemy.hp = 20
	play(gs, "c63108", enemy.uid)
	check(enemy.attack == 0 and enemy.hp == 20, "reincarnation zeroes the selected target and does not trigger its own listener")
	play(gs, "c63305", enemy.uid)
	check(enemy.hp < 14 and Twin.cat(gs, 0).shield == 2, "existing realm follows a targeted spell with an attack on the same reserve unit")
	play(gs, "c63107")
	check(p.units[1].form.cardId == "c63107", "cat god installs original form")
	var before: int = enemy.attack
	gs.turn_counter += 1
	gs._recalc(enemy)
	check(before == 0 and enemy.attack > 0, "power zero expires on the next actual turn")

func attachment_and_target_boundaries() -> void:
	var gs := charm_game(["zhiwu", "longjue", "ertong", "fenghuanghuo"])
	var dragon: Dictionary = gs.player(0).units[1]
	play(gs, "c65406")
	check(Paper.charms(0, dragon) == 2, "纸舞把龙息乾与坤记为两种己方灵咒")
	play(gs, "c63301", dragon.uid)
	check(Paper.power(dragon) == 3, "乾坤及落纸达到三种时获得完整增益")
	play(gs, "c63308")
	dragon.erase("dragonDry")
	dragon.erase("dragonWet")
	play(gs, "c63301", dragon.uid)
	check(dragon.get("dragonDry", false) and dragon.get("dragonWet", false), "落纸再次结附两种历史龙息")

	gs = charm_game(["zhiwu", "ertong", "alaina", "yingcao"])
	var foe: Dictionary = gs.player(1).units[0]
	foe.hp = 30
	play(gs, "c63108", foe.uid)
	play(gs, "c10701", "avatar-1")
	check(Twin.cat(gs, 0).is_empty(), "只以牌手为目标的法术不会触发猫灵铃迴")
	play(gs, "c63305", foe.uid)
	check(not Twin.cat(gs, 0).is_empty() and foe.hp < 26, "选择敌方式神的法术会正常触发猫灵追击")

func new_charm_sources() -> void:
	var gs := charm_game(["zhiwu", "shuweng-zhixing", "dayueling-yuxin", "fenghuanghuo"])
	var p := gs.player(0)
	var foe := gs.player(1)
	var paper: Dictionary = p.units[0]
	var traveler: Dictionary = p.units[1]
	play(gs, "c64601", paper.uid)
	check(int(foe.avatarHp) == 29, "纸舞结附己方八尺琼勾玉时触发真实投射")
	play(gs, "c64601", foe.units[0].uid)
	check(not 0 in paper.get("abyssJades", []), "勾玉的正常转移移除原结附")
	play(gs, "c63308")
	play(gs, "c63301", paper.uid)
	check(0 in paper.get("abyssJades", []) and not 0 in foe.units[0].get("abyssJades", []), "落纸按历史重新结附己方唯一的八尺琼勾玉")
	var notes := int(traveler.get("travelNotes", 0))
	play(gs, "c64302")
	choose_divination(gs)
	check(int(traveler.get("travelNotes", 0)) == notes + 1, "书翁使用真实牌取得一份额外游记")
	for i in int(traveler.travelNotes): gs.VerifiedRules.DragonAbyss.Travel.spend(gs, 0)
	var natural_notes := int((int(traveler.travelHandUses) + 1) % 2 == 0)
	play(gs, "c63301", traveler.uid)
	check(int(traveler.get("travelNotes", 0)) == natural_notes + 1, "已消耗的游记按每种一份重新结附")

	gs = GS.create(["zhiwu", "shantong", "bingyong", "yaodaoji"], ["dayueling-yuxin", "xuenv", "fenghuanghuo", "bailang"], 633)
	prepare(gs)
	gs.current_player = 1
	paper = gs.player(0).units[0]
	check(gs.play_card(1, give(gs, "c64601", 1), paper.uid), "敌方可以正常将其勾玉结附给纸舞")
	check(1 in paper.get("abyssJades", []) and paper.get("paperCharmHistory", {}).is_empty() and int(gs.player(1).avatarHp) == 30, "敌方灵咒不能进入己方历史或触发纸舞投射")

func sand_rules() -> void:
	var gs := charm_game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var foe_unit: Dictionary = foe.units[2]
	play(gs, "c64101")
	check(gs.pending_choice.instanceIds.size() == 3 and gs.pending_choice.zoneOwner == 1, "battle skill sees only three real enemy top cards")
	var iid: String = gs.pending_choice.instanceIds[0]
	var inst := gs.VerifiedRules.Divination.instance(gs, 1, iid)
	check(Sand.choice_card(gs, 0, iid).id == inst.definitionId and gs.resolve_divination_choice(0, iid), "UI definition and chosen deck instance match")
	check(Sand.has_charm(0, 1, inst) and not Sand.has_charm(1, 1, inst) and p.units[2].battleSkillId == "c64101", "limitless has exact controller and battle skill is installed")
	check(gs.basic_attack(0, 2) and gs.pending_choice.type == "charm-sand-top" and AI.take_action(gs, 0), "ordinary attack fires installed skill and AI handles it")
	var marks_before: int = foe.deck.filter(func(i): return Sand.has_charm(0, 1, i)).size()
	play(gs, "c64102")
	check(foe.deck.filter(func(i): return Sand.has_charm(0, 1, i)).size() == marks_before + 2, "holy book attaches then copies to a different instance once")
	var forced := card_in_deck(gs, 1, "c12401")
	Sand._attach(gs, 0, 1, forced, Sand.LIMITLESS)
	foe_unit.hp = 15
	gs._draw(1, 1)
	check(foe_unit.hp == 12 and not forced.has(Sand.LIMITLESS), "first draw deals three to owning shikigami and consumes charm")
	forced = card_in_deck(gs, 1, "c12401")
	Sand._attach(gs, 0, 1, forced, Sand.LIMITLESS)
	gs._draw(1, 1)
	check(foe_unit.hp == 7, "later draw deals five")
	play(gs, "c64103")
	check(gs.pending_choice.get("type", "") == "native-divination" and gs.pending_choice.count >= 1, "rewind finishes both draw and shuffle sequences before divination")
	choose_divination(gs)
	play(gs, "c64104")
	check(p.units[2].awakened, "awakening enables three actual draw reactions")
	play(gs, "c64105")
	foe_unit.hp = 0
	forced = card_in_deck(gs, 1, "c12401")
	Sand._attach(gs, 0, 1, forced, Sand.LIMITLESS)
	var health: int = foe.avatarHp
	gs._draw(1, 1)
	check(foe.avatarHp <= health - 5, "library redirects limitless for a knocked-out owner")
	foe_unit.hp = 10
	var idx := give(gs, "c12401", 1)
	var original: Dictionary = foe.hand[idx]
	foe.hand = [original]
	play(gs, "c64106", foe_unit.uid)
	check(foe.deck.has(original) and Sand.has_charm(0, 1, original), "normal bind washes exact dedicated hand instance")
	give(gs, "c64106")
	gs.current_player = 1
	gs.player(0).energy = 2
	idx = give(gs, "c12404", 1)
	original = foe.hand[idx]
	var hp: int = p.units[0].hp
	check(gs.play_card(1, idx, p.units[0].uid), "opponent announces actual enemy hand spell")
	var returned := gs.VerifiedRules.Divination.instance(gs, 1, str(original.instanceId))
	check(p.units[0].hp == hp and not returned.is_empty() and Sand.has_charm(0, 1, returned), "automatic response counters entire effect and preserves played instance")
	check(int(p.energy) == 1, "automatic response paid one actual ghost fire")
	gs.current_player = 0
	p.energy = 40
	p.units[2].level = 1
	idx = give(gs, "c64107")
	var definition := gs.hand_card_def(0, idx)
	check(definition.level == 1 and definition.effect == "sand-trick" and gs._kw(definition, "instant"), "low-level trick uses legal alternate spell")
	check(gs.play_card(0, idx), "trick resolves")
	p.units[2].level = 3
	play(gs, "c64107")
	play(gs, "c64108")
	check(p.units[2].form.cardId == "c64108", "sand book installs original 4/6 form")
	var ally: Dictionary = p.units[3]
	gs._knockout_unit(ally)
	forced = card_in_deck(gs, 0, "c12401")
	Sand._attach(gs, 0, 0, forced, Sand.ENDLESS)
	gs._draw(0, 1)
	check(ally.hp > 0 and ally.swift and ally.inspired, "endless revives dedicated owner and grants swift/inspired")

func charm_assets() -> void:
	for prefix in ["631", "633", "641"]:
		for number in range(1, 9):
			var id := "c%s%02d" % [prefix, number]
			check(Content.card_def(id).verifiedRules and ResourceLoader.exists("res://assets/official/cards/%s.png" % id), "verified overlay and official art " + id)
	check(ResourceLoader.exists("res://assets/official/tokens/twin-sight-cat.png"), "full cat spirit derivative art")

func charm_ui(window_size: Vector2i) -> void:
	root.theme = ThemeBuilder.build_theme()
	root.size = window_size
	DisplayServer.window_set_size(window_size)
	var screen := Battle.new()
	screen.setup(CHARM_TEAM, CHARM_ENEMY, 633)
	screen._ai_thinking = true
	root.add_child(screen)
	await create_timer(0.4).timeout
	var gs := screen.gs
	prepare(gs)
	hand(screen, ["c63301", "c64101"])
	await settled(screen)
	await click(screen._hand_row.get_child(0))
	await settled(screen)
	check(screen._pending_target_card == 0, "blade asks for an actual ally on the battle screen")
	var ally := screen._unit_widget(gs.player(0).units[1].uid)
	if ally != null: await click(ally)
	await settled(screen)
	check(gs.player(0).units[1].get("paperFall", false), "clicking ally applies paper fall in the battle screen")
	await click(screen._hand_row.get_child(0))
	await settled(screen)
	check(is_instance_valid(screen._choice_layer) and gs.pending_choice.get("type", "") == "charm-sand-top", "spell opens visible enemy deck choice")
	if is_instance_valid(screen._choice_layer):
		var iid: String = gs.pending_choice.instanceIds[0]
		var inst := gs.VerifiedRules.Divination.instance(gs, 1, iid)
		var visible := choice_face(screen, str(inst.definitionId))
		check(visible != null, "revealed tile renders the real deck card art")
		if visible != null: await click(visible)
		await settled(screen)
		check(gs.pending_choice.is_empty() and Sand.has_charm(0, 1, inst), "clicking a visible enemy deck card binds that exact instance")
	var enemy: Dictionary = gs.player(1).units[0]
	hand(screen, ["c63108"])
	await settled(screen)
	await click(screen._hand_row.get_child(0))
	await settled(screen)
	await click(screen._unit_widget(enemy.uid))
	await settled(screen)
	check(enemy.get("twinZeroTurn", -1) == gs.turn_counter and Twin.cat(gs, 0).is_empty(), "轮回的真实鼠标目标只结算自身进场效果 " + str(window_size))
	screen.queue_free()
	await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	paper_rules()
	twin_rules()
	attachment_and_target_boundaries()
	new_charm_sources()
	sand_rules()
	charm_assets()
	if "--ui" in OS.get_cmdline_user_args():
		for window_size in [Vector2i(1280, 800), Vector2i(1600, 740)]: await charm_ui(window_size)
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("CHARM_REALMS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
