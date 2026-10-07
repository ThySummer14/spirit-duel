extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Rules := preload("res://scripts/verified_card_rules.gd")
const Countdown := preload("res://scripts/countdown_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YAOQIN_FAIL ", message)

func fixture() -> GS:
	var gs := GS.create(["yaoginshi", "datiangou-gangfeng", "basalt", "lumen"], ["yaoginshi", "datiangou-gangfeng", "basalt", "lumen"], 12808)
	for p in gs.players:
		p.hand.clear()
		p.levelUpUsed = true
		p.energy = 20
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
		p.units[0].abilityCountdown.remaining = 3
	return gs

func give(gs: GS, p: int, id: String) -> int:
	gs.player(p).hand.append({"instanceId": "test-%d-%d" % [p, gs.next_card_id], "definitionId": id})
	gs.next_card_id += 1
	return gs.player(p).hand.size() - 1

func play(gs: GS, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, owner, id), target), "play " + id)

func advance(gs: GS, owner: int, src: int, amount: int) -> void:
	Rules.reduce_countdown(gs, owner, src, amount)
	gs._resolve_resolution_stack()

func triggers(gs: GS, remember: bool = true) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == "ability-trigger" and e.remember == remember)

func _initialize() -> void:
	_basic()
	_awakenings()
	_targets()
	_team_chain()
	_ensemble()
	_counters()
	_ai_replay()
	print("YAOQIN checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("YAOQIN_OK")
	quit(0 if failures == 0 else 1)

func _basic() -> void:
	var gs := fixture()
	var p := gs.player(0)
	p.avatarHp = 20
	p.units[0].hp = 1
	p.units[1].hp = 1
	p.units[2].hp = 0
	p.units[2].knockout = 2
	gs._begin_turn(0)
	check(p.avatarHp == 20 and p.units[0].hp == 1 and p.units[0].abilityCountdown.remaining == 2, "base ability waits for countdown, no every-turn substitute")
	advance(gs, 0, 0, 1)
	check(p.avatarHp == 20 and triggers(gs).is_empty(), "not ready means no heal or history")
	advance(gs, 0, 0, 5)
	check(p.avatarHp == 23 and p.units[0].hp == 4 and p.units[1].hp == 4, "base heals owner and living allies by three with cap")
	check(p.units[2].hp == 0 and p.units[2].knockout == 1, "base healing cannot revive")
	check(p.units[0].abilityCountdown.remaining == 3 and triggers(gs).size() == 1, "overflow discarded, once and reset")
	check(p.units[0].abilityHistory == ["healing"], "record actual base ability")
	Rules.knocked_out(p.units[0])
	p.units[0].hp = 0
	p.units[0].knockout = 1
	gs._begin_turn(0)
	check(p.units[0].hp > 0 and p.units[0].abilityCountdown.remaining == 2, "natural revival precedes ability tick")
	p.units[0].level = 0
	advance(gs, 0, 0, 5)
	check(p.units[0].abilityCountdown.remaining == 2, "inactive unit does not trigger countdown")

func _awakenings() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	p.avatarHp = 20
	play(gs, "c12802")
	check(p.avatarHp == 23 and u.abilityCountdown.mode == "kagura", "old healing resolves before switching to kagura")
	check(u.attack == 4 and u.maxHp == 4 and u.abilityHistory == ["healing"], "authentic awakening stats, new mode not recorded until fired")
	check(p.units[1].attackBonus == 0, "playing kagura does not invent immediate team growth")
	play(gs, "c12803")
	check(u.attack == 5 and u.maxHp == 5 and u.abilityCountdown.mode == "requiem", "second awakening really switches and grants printed stats")
	check(p.units[1].attackBonus == 1 and u.abilityHistory == ["healing", "kagura"], "kagura resolved before requiem switch")
	var deck_size: int = p.deck.size()
	p.energy = 2
	var fire: int = p.energy
	advance(gs, 0, 0, 3)
	check(p.deck.size() == deck_size - 1 and p.energy == fire + 1, "requiem draws and gains fire only on actual trigger")
	check(u.abilityHistory == ["healing", "kagura", "requiem"], "three distinct triggered modes remembered")
	play(gs, "c12802")
	check(u.abilityCountdown.mode == "kagura" and u.attack == 6, "repeat awakening isn't blocked by a global awakened boolean")
	gs = fixture()
	u = gs.player(0).units[0]
	var before := _total_hp(gs, 1)
	play(gs, "c12801")
	check(before - _total_hp(gs, 1) == 5 and u.abilityCountdown.mode == "battle", "entry battle mode uses five individually allocated damage points")
	check(u.abilityHistory == ["battle"] and u.maxHp == 5, "new入阵歌 does not silently reuse removed heal-before-awaken effect")
	var hand_size: int = gs.player(0).hand.size()
	advance(gs, 0, 0, 3)
	check(u.abilityHistory.size() == 1 and gs.player(0).hand.size() == hand_size, "repeated battle ability neither duplicates history nor draws")
	check(gs.rule_events.filter(func(e): return e.kind == "automatic-card").is_empty(), "ability triggers are not spell casts")

func _targets() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	p.units[2].hp = 0
	p.units[2].knockout = 2
	var card := ContentLoader.card_def("c12804")
	check(gs.valid_targets(0, card).size() == 8, "惊弦 can target either side including knockout")
	play(gs, "c12804", p.units[2].uid)
	check(p.units[2].hp == p.units[2].maxHp and p.units[2].knockout == 0, "惊弦 advances knockout to real revival")
	var hp: int = foe.units[2].hp
	play(gs, "c12804", foe.units[2].uid)
	check(foe.units[2].hp == hp and foe.units[2].shield == 0, "timerless target takes no substitute damage/heal/armor")
	foe.units[2].hp = 0
	foe.units[2].knockout = 1
	p.avatarHp = 20
	play(gs, "c12805", foe.units[2].uid)
	check(foe.units[2].knockout == 3 and p.avatarHp == 23, "疯魔 extends enemy death timer and resolves own timer")
	check(foe.units.all(func(u): return u.frozen == 0), "疯魔 does not freeze the enemy team")
	var i := give(gs, 0, "c12805")
	check(not gs.can_play_card(0, i, p.units[0].uid).ok, "疯魔 rejects friendly target")
	check(not gs.can_play_card(0, i, "avatar-1").ok, "countdown spell rejects avatar")
	foe.units[0].abilityCountdown.remaining = 2
	check(gs.play_card(0, i, foe.units[0].uid), "疯魔 accepts living ability timer")
	check(foe.units[0].abilityCountdown.remaining == 4, "increase can exceed base reset length")
	foe.units[0].level = 0
	check(not gs.valid_targets(0, card).has(foe.units[0].uid), "inactive target excluded")

func _team_chain() -> void:
	var gs := fixture()
	var p := gs.player(0)
	play(gs, "c29001")
	play(gs, "c12802")
	p.units[2].hp = 0
	p.units[2].knockout = 1
	var atk: int = p.units[2].attack
	var max_hp: int = p.units[2].maxHp
	play(gs, "c12806")
	check(p.units[1].spellCountdown.remaining == 2, "kagura and余音 separately reduce steel timer and trigger origin")
	check(gs.rule_events.filter(func(e): return e.kind == "automatic-card").size() == 1, "cross-character timer triggers an actual origin card")
	check(p.units[2].hp == max_hp and p.units[2].attack == atk, "kagura revives death timer without granting that target growth")
	check(p.units[1].attackBonus == 1, "living teammate receives exact printed kagura stats")
	gs = fixture()
	p = gs.player(0)
	p.units[2].hp = 0
	p.units[2].knockout = 2
	play(gs, "c12806")
	check(p.units[2].knockout == 2 and p.units[1].attackBonus == 0, "余音 alone doesn't touch dead teammates or invent growth")

func _ensemble() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	var hp := _total_hp(gs, 0)
	var deck: int = p.deck.size()
	play(gs, "c12808")
	check(_total_hp(gs, 0) == hp and p.deck.size() == deck and u.attackBonus == 0, "empty-history ensemble has no invented fallback")
	check(p.energy == 20, "first instant costs no fire")
	advance(gs, 0, 0, 3)
	advance(gs, 0, 0, 3)
	p.avatarHp = 20
	play(gs, "c12808")
	check(p.avatarHp == 23 and u.abilityHistory == ["healing"], "repeat one distinct ability once, not once per historical trigger")
	check(p.energy == 19, "second instant pays printed cost")
	play(gs, "c12802")
	advance(gs, 0, 0, 3)
	play(gs, "c12803")
	advance(gs, 0, 0, 3)
	play(gs, "c12801")
	var history: Array = u.abilityHistory.duplicate()
	var atk: int = p.units[1].attack
	var health := _total_hp(gs, 1)
	deck = p.deck.size()
	var live_view := Countdown.describe_card(ContentLoader.card_def("c12808"), u)
	check("5点伤害" in live_view.text and "获得1点鬼火" in live_view.text and not "当你使用" in live_view.text, "live card text shows only recorded countdown effects")
	play(gs, "c12808")
	check(triggers(gs, false).size() == 5, "ensemble replays healing once earlier plus all four distinct modes")
	check(p.deck.size() == deck - 1 and p.units[1].attack == atk + 1 and health - _total_hp(gs, 1) == 5, "ensemble resolves draw, team timer growth and five random hits")
	check(u.abilityHistory == history and u.abilityCountdown.mode == "battle", "ensemble doesn't change mode or record a new ability")

func _counters() -> void:
	for blocked in ["c29001", "c29003", "c29008", "c12802", "c12804", "c12808"]:
		var gs := fixture()
		var p := gs.player(0)
		var foe := gs.player(1)
		give(gs, 1, "c12807")
		var target = p.units[0].uid if blocked in ["c29003", "c12804"] else null
		var before: Array = p.units.duplicate(true)
		var hp: int = foe.avatarHp
		play(gs, blocked, target)
		check(foe.hand.is_empty() and foe.energy == 19, "response consumes one hand card and printed fire: " + blocked)
		if blocked == "c29001":
			check(p.units[1].has("spellCountdown"), "steel when-used ability survives combat counter")
			before[1].spellCountdown = p.units[1].spellCountdown.duplicate(true)
		check(p.units == before and p.realms.is_empty() and foe.avatarHp == hp, "card effects nullified; independent when-used ability retained: " + blocked)
		check(gs.response_window.is_empty() and gs.resolution_stack.is_empty(), "automatic response finishes without manual window: " + blocked)
		check(gs.rule_events.any(func(e): return e.kind == "card-nullified"), "counter event published: " + blocked)
	for reason in ["energy", "level", "dead", "stun"]:
		var gs := fixture()
		var foe := gs.player(1)
		give(gs, 1, "c12807")
		match reason:
			"energy": foe.energy = 0
			"level": foe.units[0].level = 1
			"dead": foe.units[0].hp = 0
			"stun": foe.units[0].frozen = 1
		play(gs, "c29001")
		check(foe.hand.size() == 1 and foe.avatarHp < 30, "automatic response respects " + reason)
	var gs := fixture()
	play(gs, "c12807")
	gs.end_turn(0)
	gs.player(1).levelUpUsed = true
	play(gs, "c29001", null, 1)
	check(gs.front_index(1) == 1, "proactive seal expires at turn boundary")
	gs = fixture()
	# Active seal catches opposing automatic response, allowing the original card.
	play(gs, "c12807")
	give(gs, 1, "c12807")
	play(gs, "c29001")
	check(gs.front_index(0) == 1 and gs.player(1).avatarHp < 30, "active counter cancels opposing automatic counter")
	check(gs.rule_events.filter(func(e): return e.kind == "card-nullified").size() == 1, "no duplicated or recursive cancellation")
	gs = fixture()
	give(gs, 1, "c12807")
	give(gs, 1, "c12807")
	play(gs, "c29001")
	check(gs.player(1).hand.size() == 1, "only one eligible counter consumed per attempted card")
	play(gs, "c29001")
	check(gs.player(1).hand.is_empty(), "next attempt consumes second counter, not a lingering first one")
	gs = fixture()
	give(gs, 1, "c12807")
	advance(gs, 0, 0, 3)
	check(gs.player(1).hand.size() == 1 and triggers(gs).size() == 1, "innate ability does not trigger a card-only counter")
	gs = fixture()
	play(gs, "c29001")
	give(gs, 1, "c12807")
	var hp: int = gs.player(1).avatarHp
	var own_hand: int = gs.player(0).hand.size()
	advance(gs, 0, 1, 2)
	check(gs.player(1).hand.size() == 1 and gs.player(1).avatarHp == hp - 2, "countdown ability replay is not countered by player-card response")
	check(gs.player(0).hand.size() == own_hand and gs.player(0).units[1].spellCountdown.remaining == 2, "auto-origin keeps timer reset, creates no hand card")

func _ai_replay() -> void:
	var gs := fixture()
	give(gs, 0, "c12807")
	check(not AI._best_card(gs, 0).ok, "AI reserves automatic counter instead of wasting it")
	give(gs, 0, "c12804")
	gs.player(0).units[2].hp = 0
	gs.player(0).units[2].knockout = 1
	check(AI._best_card(gs, 0).target == gs.player(0).units[2].uid, "AI prefers friendly revival over enemy assistance")
	var a := fixture()
	var b := fixture()
	for current in [a, b]:
		play(current, "c12801")
		play(current, "c12802")
		play(current, "c12806")
		give(current, 1, "c12807")
		play(current, "c12808")
	check(a.snapshot() == b.snapshot(), "same seed and commands reproduce ability history, random hits and automatic counter")
	check(JSON.parse_string(JSON.stringify(a.snapshot())) is Dictionary, "new timer/history/events remain JSON serializable")

func _total_hp(gs: GS, p: int) -> int:
	var value: int = gs.player(p).avatarHp
	for u in gs.player(p).units: value += int(u.hp)
	return value
