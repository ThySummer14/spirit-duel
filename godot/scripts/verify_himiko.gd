extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Himiko := preload("res://scripts/himiko_rules.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const SUNDIAL := "w13-himiko-93153"
const GAP := "w13-himiko-93154"
const REMOTE := "w13-himiko-93155"
const AWAKEN := "w13-himiko-93156"
const GLORY := "w13-himiko-93157"
const KNOCKOUT := "w13-himiko-93158"
const CONQUEST := "w13-himiko-93159"
const QUEEN := "w13-himiko-93160"
var checks := 0
var failures := 0

func _initialize() -> void:
	_data()
	_payment()
	_gap()
	_glory()
	_sundial()
	_knockout()
	_conquest()
	_queen()
	print("HIMIKO checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("HIMIKO_FAIL ", label)

func game() -> GS:
	var gs := GS.create([Himiko.ID, "fenghuanghuo", "shenqi-huang", "bingyong"], ["shantong", "yaodaoji", "yingcao", "huang"], 93158)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs

func put(gs: GS, owner: int, id: String) -> Dictionary:
	return gs.VerifiedRules.Insight.instance(gs, owner, id)

func deck(gs: GS, owner: int, ids: Array) -> void:
	gs.player(owner).deck = ids.map(func(id): return put(gs, owner, id))

func play(gs: GS, id: String, target = null) -> bool:
	var hand: Array = gs.player(0).hand
	hand.append(put(gs, 0, id))
	return gs.play_card(0, hand.size() - 1, target)

func hp_total(gs: GS, owner: int = 1) -> int:
	var hp := int(gs.player(owner).avatarHp)
	for u in gs.player(owner).units: hp += int(u.hp)
	return hp

func _data() -> void:
	var cards := Content.cards_for_unit(Himiko.ID)
	check(cards.size() == 9 and Content.starter_card_ids(Himiko.ID).size() == 8, "eight legal deck cards and one token")
	check(Content.unit_def(Himiko.ID).maxHp == 4 and Content.unit_def(Himiko.ID).attack == 2, "official base body")
	check(game().VerifiedRules.Factions.printed({"id": Himiko.ID}) == "红莲", "authentic faction")
	for card in cards:
		check(card.get("verifiedRules", false) and card.effects.size() == 1, "native overlay for " + card.id)
	check(Content.card_def(Himiko.ECLIPSE).token and Content.card_def(Himiko.ECLIPSE).cost == 0, "free eclipse excluded from deck")

func _payment() -> void:
	var gs := game()
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	var enemy := gs.player(1)
	check(play(gs, AWAKEN), "first awakening played")
	check(u.awakened and u.attack == 3 and u.maxHp == 5 and p.energy == 40 and enemy.avatarHp == 29, "base triggers on free awakening, stats and token applied")
	check(p.hand.size() == 1 and p.hand[0].definitionId == Himiko.ECLIPSE and gs.instant_available(0), "awake grants remaining allowance")
	check(play(gs, AWAKEN) and u.attack == 4 and u.maxHp == 6 and p.energy == 40 and enemy.avatarHp == 28, "second actual instant and duplicate growth")
	check(p.hand.size() == 2 and not gs.instant_available(0), "two different eclipse instances, instant allowance exhausted")
	check(play(gs, REMOTE) and p.energy == 39 and enemy.avatarHp == 24, "third instant pays normally and does not trigger base")
	check(int(u.front) == 0 and gs.kw_usage(0, "encourage").battlePower == 1 and gs.kw_usage(0, "encourage").shield == 1, "remote fight leaves preparation and supplies actual encouragement")
	var before := int(enemy.avatarHp)
	check(gs.play_card(0, 0) and p.energy == 39 and enemy.avatarHp == before - 2, "first eclipse improves its own projection and is inherently free")
	check(gs.play_card(0, 0) and p.energy == 39 and enemy.avatarHp == before - 5, "second eclipse accumulates damage")
	check(p.hand.size() == 2 and p.hand.all(func(i): return gs._source_index(0, Content.card_def(i.definitionId)) >= 0), "eclipses immediately generate real own specialty cards")
	gs._knockout_unit(u)
	check(not Himiko.extra_instant(gs, 0), "extra slot lost while dead")
	gs.turn_counter += 1
	gs._begin_turn(0)
	check(gs.instant_available(0), "normal allowance resets after turn even if source dead")
	gs.consume_instant(0)
	check(not gs.instant_available(0), "dead source provides no additional slot")

	gs = game()
	p = gs.player(0)
	enemy = gs.player(1)
	check(play(gs, AWAKEN) and Himiko.extra_instant(gs, 0), "觉醒时原本提供额外瞬发")
	gs.VerifiedRules.Fortune.transform(gs, 0, 0, false)
	check(not Himiko.extra_instant(gs, 0) and not gs.instant_available(0), "纸人变形压制额外瞬发额度")
	gs.turn_counter += 1
	gs._begin_turn(0)
	var before_transform_attack := int(enemy.avatarHp)
	var fire := int(p.energy)
	check(play(gs, "c12401") and p.energy == fire and enemy.avatarHp == before_transform_attack - 3, "纸人形态期间凤鸣仍消耗零鬼火，只有凤凰火自身的两段伤害")

func _gap() -> void:
	var gs := game()
	var p := gs.player(0)
	var selected: Dictionary = p.units[1]
	check(play(gs, GAP, selected.uid), "deploy four-durability targeted realm")
	check(p.realms[0].hp == 4 and p.realms[0].himikoTarget == selected.uid and p.energy == 40, "realm does not retroactively trigger on its own first play")
	var instance := put(gs, 0, "c12403")
	var desc := gs.describe_card_instance(0, instance)
	check(gs._source_index(0, desc) == 1 and gs._kw(desc, "instant"), "chosen unit's real cards become instant")
	check(not gs._kw(gs.describe_card_instance(0, put(gs, 0, GLORY)), "instant"), "other units' cards retain ordinary timing")
	check(play(gs, AWAKEN) and p.energy == 39 and p.realms[0].hp == 4, "paid play spends no durability")
	check(play(gs, REMOTE) and p.realms[0].hp == 2, "free hand play spends two durability")
	check(int(selected.shield) == 1 and int(p.units[0].shield) == 0, "buff goes to realm's selected target")
	check(play(gs, Himiko.ECLIPSE) and p.realms.is_empty(), "next free hand card destroys depleted realm")
	check(not gs._kw(gs.describe_card_instance(0, instance), "instant"), "destroyed realm removes the actual instant grant")
	gs = game()
	var dead: Dictionary = gs.player(1).units[0]
	gs._knockout_unit(dead)
	check(not play(gs, GAP, dead.uid) and gs.player(0).energy == 40, "reject dead target before paying")
	var veiled: Dictionary = gs.player(1).units[1]
	veiled.movementVeil = true
	check(not Himiko.valid_gap_target(gs, 0, veiled.uid), "时间之隙结算时拒绝获得帷幕的敌方目标")
	veiled.movementVeil = false
	check(Himiko.valid_gap_target(gs, 0, veiled.uid), "失去帷幕后重新成为合法敌方目标")

func _glory() -> void:
	var gs := game()
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	check(play(gs, GLORY) and u.attack == 4 and u.maxHp == 5, "printed form")
	p.attackUsed = true
	var before := int(gs.player(1).avatarHp)
	Himiko.announced(gs, {"playerIndex": 0, "sourceIndex": 2, "automatic": true, "usedFromHand": false})
	gs._resolve_resolution_stack()
	check(not p.attackUsed and gs.kw_usage(0, "encourage").battlePower == 1 and gs.kw_usage(0, "encourage").shield == 1, "form triggers from an automatic no-cost card")
	check(gs.player(1).avatarHp == before, "same automatic use does not satisfy hand-only base")
	p.attackUsed = true
	Himiko.announced(gs, {"playerIndex": 0, "sourceIndex": 2, "automatic": true, "usedFromHand": false})
	check(p.attackUsed and gs.kw_usage(0, "encourage").battlePower == 2, "same turn still encourages but does not reset twice")
	Himiko.announced(gs, {"playerIndex": 0, "sourceIndex": 2, "automatic": true, "usedFromHand": false, "paidFire": 1})
	check(gs.kw_usage(0, "encourage").battlePower == 2, "actual paid automated card does not qualify")

func _sundial() -> void:
	var gs := game()
	var p := gs.player(0)
	var target: Dictionary = p.units[2]
	gs._knockout_unit(target)
	deck(gs, 0, ["w13-shenqi-huang-93118", "c10301"])
	check(play(gs, SUNDIAL) and gs.pending_choice.get("type") == Fate.KIND, "revival waits for deck position choice")
	check(target.hp == 0 and p.deck.size() == 2, "no premature revival or draw")
	check(not gs.resolve_divination_choice(1, Fate.REVERSE), "other player cannot claim the choice")
	check(AI.take_action(gs, 0) and target.hp == target.maxHp and target.knockout == 0, "AI selects the real defeated card owner and revives")
	check(p.deck.size() == 2 and p.deck.back().definitionId == "w13-shenqi-huang-93118", "actual revealed card remains in deck")
	gs = game()
	p = gs.player(0)
	var forbidden: Dictionary = p.units[1]
	target = p.units[2]
	forbidden.catCannotRevive = true
	gs._knockout_unit(forbidden)
	gs._knockout_unit(target)
	forbidden.knockout = 4
	deck(gs, 0, ["w13-shenqi-huang-93118", "c12403"])
	check(play(gs, SUNDIAL) and gs.pending_choice.get("type") == Fate.KIND, "时汐之晷比较两个气绝式神的牌")
	check(AI.take_action(gs, 0) and target.hp > 0 and forbidden.hp == 0, "AI 逆天选择可实际复活的式神，避开更长但永久的气绝")

func _knockout() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	deck(gs, 1, ["c17802", "c10201"])
	check(play(gs, KNOCKOUT) and gs.pending_choice.get("type") == Fate.KIND and gs.pending_choice.deckOwner == 1, "use enemy deck with caster deciding")
	check(p.attackUsed and p.energy == 40, "swift-card spends deployment, not fire")
	check(gs.resolve_divination_choice(0, Fate.REVERSE) and foe.units[3].hp == 0 and foe.units[3].knockout == 2, "reveal knocks selected card's owner to two")
	foe.units[3].knockout = 1
	p.attackUsed = true
	check(play(gs, KNOCKOUT) and p.energy == 39, "without deployment this card spends fire")
	check(gs.resolve_divination_choice(0, Fate.FOLLOW) and foe.units[3].knockout == 2, "revealing already knocked out unit resets its countdown")

func _conquest() -> void:
	var gs := game()
	var p := gs.player(0)
	deck(gs, 0, ["c10301", CONQUEST])
	var id: String = p.deck.back().instanceId
	check(not gs._kw(gs.describe_card_instance(0, p.deck.back()), "instant"), "unrevealed conquest is ordinary")
	Fate.reveal_top(gs, 1, 0)
	check(p.deck.size() == 1 and p.hand.size() == 1 and p.hand[0].instanceId == id, "opponent revelation moves the same instance to its owner")
	check(gs._kw(gs.hand_card_def(0, 0), "instant") and gs._kw(gs.hand_card_def(0, 0), "bounce"), "revealed conquest has live instant and bounce traits")
	var hp := hp_total(gs)
	check(gs.play_card(0, 0) and p.energy == 40 and p.hand[0].instanceId == id, "first cast bounces same instance")
	check(hp_total(gs) == hp - 9 and gs.player(1).avatarHp == 29, "sweep hits four shikigami and base separately hits player")
	check(not gs._kw(gs.hand_card_def(0, 0), "bounce") and gs._kw(gs.hand_card_def(0, 0), "instant"), "only bounce is consumed")
	check(gs.play_card(0, 0) and p.energy == 39 and p.hand.is_empty(), "second cast pays fire and does not bounce")

func _queen() -> void:
	var gs := game()
	var p := gs.player(0)
	check(play(gs, QUEEN) and p.energy == 40 and p.hand.size() == 3, "queen adds exactly three global cards directly")
	for instance in p.hand:
		var card := Content.card_def(instance.definitionId)
		check(card.type != "awakening" and not str(card.name).begins_with("觉醒") and not card.token and gs._kw(card, "instant") and not gs.VerifiedRules.Factions.printed({"id": card.unitId}).is_empty(), "candidate is collectible original instant, not awakening")
