extends "res://scripts/verify_book_jue_ui.gd"

const Content := preload("res://scripts/content_loader.gd")
const Game := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const DeckBuilder := preload("res://scripts/ui/deck_builder.gd")
const Save := preload("res://scripts/save_store.gd")
const Divination := preload("res://scripts/native_divination_rules.gd")

const ICE := "c106112"
const SEAL := "c106112:xuenv"
const BLADE := "c106112:xuetongzi"
const ARROW := "c107110"
const GRASS := "c107110:yingcao"
const ALLIES := ["xuenv", "xuetongzi", "yi", "hetong"]
const FOES := ["bingyong", "yaodaoji", "shantong", "huang"]


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("COOP_FAIL ", detail)


func configured_game(allies: Array = ALLIES, foes: Array = FOES) -> Game:
	var gs := Game.create(allies, foes, 106112)
	for p in gs.players:
		p.hand.clear()
		p.energy = 10
		p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	return gs


func deck_rules() -> void:
	var roots: Array = Content.load_content().cards.filter(func(card): return card.get("type") == "coop")
	var owners := {}
	for card in roots:
		var partners := Content.card_unit_ids(card)
		check(partners.size() == 2 and card.coopFaces.size() == 2 and FileAccess.file_exists("res://" + str(card.cardArt)), card.id + " has one original card and two owners/faces")
		for branch in card.coopFaces:
			owners[branch.unitId] = true
			check(branch.unitId in partners and card in Content.cards_for_unit(branch.unitId), branch.name + " listed for its printed owner")
			check(ResourceLoader.exists("res://" + str(branch.coopFaceArt)), branch.name + " has its own original face image")
	check(roots.size() == 17 and owners.size() == 34, "all original cooperation roots indexed")

	var snow := Content.starter_card_ids("xuenv")
	var child := Content.starter_card_ids("xuetongzi")
	snow[0] = ICE
	child[0] = ICE
	Save.set_deck("xuenv", snow)
	Save.set_deck("xuetongzi", child)
	var deck := Save.deck_definition(ALLIES)
	check(deck.cardIds.count(ICE) == 2 and Content.cooperation_deck_error(deck.cardIds, deck.slotOwners).is_empty(), "both owners can carry one of the two shared copies")
	var gs := Game.create(ALLIES, FOES, 106112, deck)
	var p := gs.player(0)
	var actual: Array = (p.deck + p.hand).filter(func(inst): return inst.definitionId == ICE)
	check(actual.size() == 2 and actual[0].instanceId != actual[1].instanceId and actual[0].coopDeckOwner != actual[1].coopDeckOwner, "separate physical instances survive native setup")
	var builder := DeckBuilder.new()
	builder.setup("xuenv", ALLIES)
	check(builder._limit_of(Content.card_def(ICE)) == 1, "builder reserves partner's saved copy within formation")
	builder.setup("xuenv", ["xuenv", "yi", "hetong", "shantong"])
	check(builder._limit_of(Content.card_def(ICE)) == 2, "outside formation partner's deck does not consume a slot")
	builder.free()

	child[1] = ICE
	Save.set_deck("xuetongzi", child)
	deck = Save.deck_definition(ALLIES)
	check(not Content.cooperation_deck_error(deck.cardIds, deck.slotOwners).is_empty(), "third shared copy rejected before entering battle")
	check(not Content.cooperation_deck_error([ICE], ["yi"]).is_empty(), "unrelated owner cannot carry the card")


func hand_rules() -> void:
	var gs := configured_game(["yingcao", "bailang", "yi", "hetong"])
	var p := gs.player(0)
	var inst := {"definitionId": ARROW, "instanceId": "shared", "giftGranted": {"key": "x"}}
	p.hand = [inst]
	p.units[1].level = 1
	var root_card := gs.hand_card_def(0, 0)
	var view := gs.playable_card(0, 0, GRASS)
	check(root_card.unitId == "" and not Content.is_spell(root_card) and gs.VerifiedRules.GiftEnergy.options(inst).is_empty(), "unplayed card has dual owners, no typed spell and no gift mode")
	check(view.coopBond and view.level == 2 and view.unitId == "yingcao", "living one-rank partner qualifies for a two-rank bond")
	check(not gs.can_play_card(0, 0).ok and not gs.can_play_card(0, 0, null, "wrong-face").ok and p.energy == 10 and p.hand.size() == 1, "missing and invented face IDs cannot spend the card")
	p.units[1].level = 0
	check(not gs.playable_card(0, 0, GRASS).coopBond, "unleveled living partner does not qualify")
	p.units[1].level = 3
	gs._knockout_unit(p.units[1])
	check(not gs.playable_card(0, 0, GRASS).coopBond, "knocked out partner does not qualify")
	p.units[0].level = 1
	check(not gs.can_play_card(0, 0, p.units[2].uid, GRASS).ok, "caster still needs the face's own level")

	gs = configured_game()
	p = gs.player(0)
	p.units[1].level = 0
	p.hand = [{"definitionId": ICE, "instanceId": "ai-ice"}]
	var choice := AI._best_card(gs, 0)
	check(choice.ok and choice.origin == SEAL and gs.can_play_card(0, choice.hand, choice.target, choice.origin).ok, "AI chooses the only legal face and a legal target")
	check(AI.take_action(gs, 0) and gs.command_log.back().a.coopFace == SEAL and p.energy == 9, "AI executes the same face and pays once")
	check(not p.hand.any(func(card): return card.instanceId == "ai-ice"), "selected face consumes one original instance")
	p.hand = [{"definitionId": ICE, "instanceId": "instant-ice", "blessingInstant": true}]
	p.energy = 0
	check(gs.can_play_card(0, 0, gs.player(1).units[0].uid, SEAL).ok and gs.effective_card_cost(0, gs.playable_card(0, 0, SEAL)) == 0, "choosing a face preserves instant granted to the real card")

	gs = configured_game()
	p = gs.player(0)
	p.deck = [{"definitionId": ICE, "instanceId": "search-ice"}]
	var search := gs.valid_targets(0, Content.card_def("c23904"))
	check(p.units[0].uid in search and p.units[1].uid in search and not p.units[3].uid in search, "search by exclusive owner recognizes both partners")
	p.hand = [{"definitionId": "c23904", "instanceId": "yi-search"}]
	check(gs.play_card(0, 0, p.units[1].uid) and gs.pending_choice.instanceIds == ["search-ice"], "search opens the exact shared deck instance")
	check(gs.resolve_divination_choice(0, "search-ice") and p.hand[0].instanceId == "search-ice", "search takes the original card, retaining both faces")

	gs = configured_game(["baimugui", "yi", "hetong", "huang"], ALLIES)
	gs.player(1).deck = [{"definitionId": "c23904", "instanceId": "eye-yi"}, {"definitionId": ICE, "instanceId": "eye-ice"}]
	gs.player(0).hand = [{"definitionId": "c19607", "instanceId": "eye-search"}]
	check(gs.play_card(0, 0) and gs.resolve_divination_choice(0, "eye-ice") and gs.resolve_divination_choice(0, Divination.TOP), "百目鬼 places a chosen cooperation card on the enemy deck top")
	check(gs.resolve_divination_choice(0, "eye-yi") and gs.resolve_divination_choice(0, Divination.BOTTOM), "百目鬼 finishes the actual enemy divination")
	check(gs.player(1).units[0].hp == 0 and gs.player(1).units[1].hp == 0 and gs.player(1).units[2].hp > 0, "百目鬼 destroys the two actual owners revealed on the deck top")

	gs = configured_game(["xuenv", "xuetongzi", "liyujing", "yi"])
	p = gs.player(0)
	p.hand = [{"definitionId": ICE, "instanceId": "ward-ice"}, {"definitionId": "c28201", "instanceId": "ward-spell"}]
	var power: int = p.units[0].attack
	gs._knockout_unit(p.units[1])
	check(gs.play_card(0, 1) and gs.resolve_divination_choice(0, "ward-ice"), "鲤鱼精 can ward an actual unplayed cooperation card")
	check(p.units[0].attack == power + 1 and p.units[1].knockout == 1, "加护 grows the living owner and advances the other owner's revival")


func option(b, face_id: String) -> Control:
	for face in faces(b._origin_choice_layer):
		if face.data.coopFaceId == face_id: return face
	return null


func battle_clicks(physical: Vector2i) -> void:
	root.size = physical
	var b := Battle.new()
	b.setup(ALLIES, FOES, 106112)
	b._ai_thinking = true
	var p := b.gs.player(0)
	p.energy = 10
	p.levelUpUsed = true
	p.units[0].level = 1
	p.units[1].level = 0
	b.gs.player(1).units[0].level = 0
	root.add_child(b)
	await create_timer(0.3).timeout
	hand(b, [ICE])
	await settled(b)
	await click(b._hand_row.get_child(0))
	await settled(b)
	var panel := b._origin_choice_layer
	check(is_instance_valid(panel), "mouse opens the two-face selector")
	if not is_instance_valid(panel):
		b.queue_free()
		await process_frame
		return
	var seal := option(b, SEAL)
	var blade := option(b, BLADE)
	check(seal != null and blade != null and texts(panel).contains("雪女 · 法术牌") and texts(panel).contains("雪童子 · 幻境牌"), "selector displays distinct source and type for both faces")
	check(blade != null and blade.modulate.a < 1.0 and seal != null and seal.modulate.a == 1.0, "unleveled source's face is disabled")
	if blade != null: await click(blade)
	check(is_instance_valid(b._origin_choice_layer) and p.energy == 10 and p.hand.size() == 1, "clicking disabled branch consumes neither resource")
	escape()
	await process_frame
	check(not is_instance_valid(b._origin_choice_layer) and p.energy == 10 and p.hand.size() == 1, "cancel closes selector without consuming the shared card")
	await click(b._hand_row.get_child(0))
	await settled(b)
	if is_instance_valid(b._origin_choice_layer):
		seal = option(b, SEAL)
		if seal != null: await click(seal)
	await settled(b)
	check(b._pending_target_card == 0 and b._pending_use_origin == SEAL and p.energy == 10, "valid face advances to targeting before any payment")
	await click(b._unit_widget(str(p.units[0].uid)))
	await settled(b)
	check(b._pending_target_card == 0 and p.energy == 10, "target click rejects a friendly unit")
	await click(b._unit_widget(str(b.gs.player(1).units[0].uid)))
	await settled(b)
	check(b._pending_target_card < 0 and p.energy == 9 and b.gs.player(1).units[0].frozen > 0, "actual mouse casts and stuns the living zero-rank enemy")
	check(b.gs.command_log.back().a.get("coopFace") == SEAL, "battle history records selected branch")
	b.queue_free()
	await process_frame


func run() -> void:
	var stores := Support.isolate_stores()
	root.theme = ThemeBuilder.build_theme()
	deck_rules()
	hand_rules()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		await battle_clicks(physical)
	Support.cleanup_audio()
	Support.cleanup_stores(stores)
	await process_frame
	print("COOP checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
