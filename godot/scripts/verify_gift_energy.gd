extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Gift := preload("res://scripts/gift_energy_rules.gd")

var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GIFT_FAIL ", detail)

func fixture() -> GS:
	var gs := GS.create(["longzi", "yanyanluo-fumiao", "rihefang-qingyang", "shantong"], ["taohuayao", "xuenv", "bingyong", "yanyanluo"], 20261109)
	gs.current_player = 0
	gs.turn_counter = 21
	for p in gs.players:
		p.hand.clear()
		p.energy = 8
		p.levelUpUsed = true
		p.avatarHp = 30
		for u in p.units:
			u.level = 3
			u.charge = 0
			u.front = 0
	return gs

func grant(gs: GS, id: String) -> int:
	var p := gs.player(0)
	p.hand.append(Gift.fresh_instance(gs, 0, id))
	return p.hand.size() - 1

func finish(gs: GS) -> void:
	var remaining := 24
	while remaining > 0 and (not gs.pending_choice.is_empty() or not gs.response_window.is_empty()):
		remaining -= 1
		if not gs.pending_choice.is_empty():
			check(AI._resolve_choice(gs, int(gs.pending_choice.playerIndex)), "AI resolves " + str(gs.pending_choice.get("type")))
		else:
			check(gs.pass_response(int(gs.response_window.playerIndex)), "passes response")
	check(gs.pending_choice.is_empty() and gs.response_window.is_empty(), "resolution finishes")

func play(gs: GS, id: String, target: Variant = null, mode: Variant = false) -> void:
	check(gs.play_card(0, grant(gs, id), target, mode), "play %s as %s" % [id, str(mode)])
	finish(gs)

func _initialize() -> void:
	_catalog()
	_payment_and_return()
	_long_rules()
	_smoke_rules()
	_sunny_rules()
	_cross_zone()
	print("GIFT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _catalog() -> void:
	var targets := {"c63406":"ally", "c63601":"enemy", "c63603":"ally", "c63702":"enemy", "c63706":"ally"}
	for role in [634, 636, 637]:
		for n in range(1, 9):
			var id := "c%d" % (role * 100 + n)
			var gs := fixture()
			var p := gs.player(0)
			for u in p.units: u.charge = 10
			var target: Variant = null
			if targets.get(id) == "ally": target = p.units[3].uid
			if targets.get(id) == "enemy": target = gs.player(1).units[0].uid
			var index := grant(gs, id)
			check(Content.card_def(id).get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "original metadata and PNG " + id)
			check(gs.can_play_card(0, index, target).ok, "base legal " + id)
			var candidate := AI._best_card(gs, 0)
			check(candidate.ok and gs.can_play_card(0, candidate.hand, candidate.target, candidate.origin).ok, "AI legal " + id)
			check(gs.play_card(0, index, target), "base real play " + id)
			finish(gs)

func _payment_and_return() -> void:
	var gs := fixture()
	var p := gs.player(0)
	p.units[0].level = 1
	p.units[0].charge = 1
	p.units[2].charge = 1
	var h := grant(gs, "c63404")
	var iid: String = p.hand[h].instanceId
	check(not gs.can_play_card(0, h, null, "gift:0").ok, "no gift without combined charge")
	p.units[2].charge = 2
	check(not gs.can_play_card(0, h).ok and gs.can_play_card(0, h, null, "gift:0").ok, "gift is independently level one")
	var fire: int = p.energy
	check(gs.play_card(0, h, null, "gift:0"), "real gift spends from two units")
	check(p.units[0].charge == 0 and p.units[2].charge == 0, "helper pays the shortfall")
	check(p.energy == fire and not gs.instant_available(0), "first instant uses the real allowance")
	check(p.hand.size() == 1 and p.hand[0].instanceId == iid and p.hand[0].giftSpent, "same card returns once without gift")
	p.units[0].level = 3
	check(not gs.can_play_card(0, 0, null, "gift:0").ok and gs.can_play_card(0, 0).ok, "base still playable and cannot repeat gift")

func _long_rules() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var e := gs.player(1)
	p.units[0].charge = 3
	play(gs, "c63401", null, "gift:0")
	var snake := gs.front_unit(0)
	check(snake.get("giftHiss", false) and snake.attack == 2 and snake.hp == 2, "real 2/2 snake occupies front")
	var idx := gs.front_index(0)
	gs._damage_unit(0, idx, 9, 1, 0)
	check(snake.hp == 2, "snake nullifies spell damage")
	gs._damage_unit(0, idx, 1, 1, 0, true)
	check(snake.hp == 1, "snake receives combat damage")
	var h := grant(gs, "c63402")
	p.units[0].charge = 3
	check(not gs.can_play_card(0, h, e.units[0].uid, "gift:0").ok, "golden rain requires damaged target")
	gs._damage_unit(1, 0, 1, 0, 0)
	check(gs.can_play_card(0, h, e.units[0].uid, "gift:0").ok and not gs.can_play_card(0, h, e.units[1].uid, "gift:0").ok, "only wounded target")
	check(gs.play_card(0, h, e.units[0].uid, "gift:0"), "golden rain wounds again")
	play(gs, "c63405")
	check(p.units[0].awakened and e.avatarHp < 30, "awakening is an actual combat card")
	check(p.units[0].get("giftDiscount", 0) == 3 and p.units[0].get("giftLongFree", false), "awakened avatar hit grants charge and fire discounts")
	play(gs, "c63403", null, "gift:0")
	check(p.units[0].form.cardId == "c63403" and p.units[0].swift, "gift attaches native form")
	p.units[0].charge = 3
	play(gs, "c63407", null, "gift:0")
	check(p.giftWaveGrowth == 1 and p.deck.any(func(inst): return inst.definitionId == "c63407"), "gift shuffles and permanently grows same-name cards")
	check(gs.describe_card_instance(0, Gift.fresh_instance(gs, 0, "c63407")).value == 2, "new same-name copies see the bonus")

func _smoke_rules() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var e := gs.player(1)
	var smoke: Dictionary = p.units[1]
	smoke.charge = 4
	var target: Dictionary = e.units[2]
	target.hp = 9
	target.maxHp = 9
	play(gs, "c63601", target.uid, "gift:0")
	check(target.frozen > 0 and e.avatarHp == 29, "gift stuns and base passive projects")
	check(gs.play_card(0, 0, target.uid), "can use ordinary face after gift")
	check(target.hp == 3 and smoke.charge == 1, "stunned target takes 6, non-gift hand play charges smoke")
	play(gs, "c63604")
	check(smoke.awakened, "native awakening")
	smoke.charge = 8
	play(gs, "c63607")
	check(smoke.form.cardId == "c16402" and gs.front_unit(0).name == "浮缈的分身", "office auto-uses real form and summons clone")
	var old_hp: int = e.avatarHp
	play(gs, "c63603", null, "gift:0")
	check(e.avatarHp < old_hp and gs.front_unit(0).name == "浮缈的分身", "office clone attacks on gift")
	smoke.charge = 7
	var h := grant(gs, "c63608")
	check(gs.play_card(0, h), "waterfall opens three-step choice")
	check(gs.pending_choice.get("type") == "gift-waterfall", "native choice type")
	check(not gs.resolve_divination_choice(0, "invalid"), "illegal effect choice rejected")
	check(gs.resolve_divination_choice(0, "gift-waterfall-heal"), "pick heal")
	check(gs.resolve_divination_choice(0, "gift-waterfall-random"), "pick random damage")
	check(gs.resolve_divination_choice(0, "gift-waterfall-fragile"), "pick break")
	check(gs.pending_choice.is_empty() and int(e.avatarArmorBreak) == 4, "three paid effects resolve in sequence")
	play(gs, "c63606")
	check(p.hand.any(func(inst): return int(inst.get("giftFreeTurn", -1)) == gs.turn_counter), "recover previously used gift card")

func _sunny_rules() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var e := gs.player(1)
	var sunny: Dictionary = p.units[2]
	play(gs, "c63701")
	check(p.hand.size() == 1 and not Gift.options(p.hand[0]).is_empty(), "gift is on the drawn physical instance")
	var annotated: int = p.deck.filter(func(inst): return inst.has("giftGranted")).size()
	check(annotated == 3, "gift spread selects four unique instances")
	play(gs, "c63704")
	check(sunny.awakened and sunny.charge == 3, "awakening charges and changes passive")
	p.units[0].charge = 3
	p.avatarHp = 20
	p.energy = 0
	gs.kw_usage(0, "instant").used = true
	play(gs, "c63408", null, "gift:0")
	check(p.energy == 0 and p.avatarHp == 22 and p.units[0].inspired, "sunny free gift with exhausted instant heals")
	p.units[0].charge = 3
	var h := grant(gs, "c63401")
	check(not gs.can_play_card(0, h, null, "gift:0").ok, "once per turn free gift")
	p.energy = 8
	var origin := grant(gs, "c63702")
	var old_health: int = p.units[0].maxHp
	p.units[0].hp = 1
	check(gs.play_card(0, origin, null, true) and p.units[0].hp == old_health, "origin uses actual 沐浴阳光")
	p.units[0].hp = 0
	p.units[0].knockout = 3
	play(gs, "c63706", p.units[0].uid)
	var resurrect: int = p.hand.find_custom(func(inst): return inst.get("giftGranted", {}).get("key") == "revive")
	check(resurrect >= 0 and gs.can_play_card(0, resurrect, null, "gift:0").ok, "realm grants a gift playable while knocked out")
	if resurrect >= 0: check(gs.play_card(0, resurrect, null, "gift:0") and p.units[0].hp > 0, "gift resurrects the owning unit")
	p.avatarHp = 18
	sunny.charge = 7
	play(gs, "c63708")
	check(sunny.charge == 10 and p.avatarHp == 25, "form charge cap overflow becomes healing")
	var enemy_total: int = e.avatarHp
	for u in e.units: enemy_total += int(u.hp)
	Gift.spend(gs, 0, 2, 5)
	gs._resolve_resolution_stack()
	var after: int = e.avatarHp
	for u in e.units: after += int(u.hp)
	check(after <= enemy_total - 6, "five spent triggers real divided damage")

func _cross_zone() -> void:
	var gs := GS.create(["longzi", "rihefang-qingyang", "wushi-maoshi", "tongnantongnv"], ["guishibai", "bingyong", "fenghuanghuo", "yingcao"], 20261109)
	var insight = gs.VerifiedRules.Insight
	var p := gs.player(0)
	gs.turn_counter = 21
	p.hand.clear()
	p.energy = 8
	p.levelUpUsed = true
	for u in p.units:
		u.level = 3
		u.charge = 10
	var musashi := Gift.fresh_instance(gs, 0, "c62408")
	var first := Gift.fresh_instance(gs, 0, "c63401")
	var second := Gift.fresh_instance(gs, 0, "c63402")
	p.deck.assign([second, first, musashi])
	Gift.new_effect(musashi, Gift.SUNNY_GIFTS[3])
	Gift.new_effect(musashi, Gift.SUNNY_GIFTS[0])
	check(Gift.options(musashi).size() == 2, "快晴保留旧赐能及本次赋予的不同效果")
	Gift.quick_draw(gs, 0, 2, [])
	gs._resolve_resolution_stack()
	check(not insight.zone(gs, 0).has(musashi) and p.hand.has(musashi) and musashi.get("giftSpent", false), "快晴在武藏换区及补抽之后自动使用赐能并回原实例")
	check(int(p.energy) == 9 and int(gs.player(1).avatarHp) == 28 and p.hand.has(first) and p.hand.has(second), "武藏两个赐能各用一次，补抽保留正常顺序")

	p.hand.clear()
	p.units[0].shield = 3
	p.units[3].formRules = {"yanmieTop": true}
	p.deck.assign([Gift.fresh_instance(gs, 0, "c63408"), Gift.fresh_instance(gs, 0, "c63408")])
	var fire: int = p.energy
	p.units[1].awakened = true
	p.units[0].spiderMark = {"source": "test"}
	var opposing: Dictionary = gs.player(1).units[1]
	opposing.level = 3
	opposing.formRules = {"jorogumoTax": true}
	var top := gs.playable_card(0, 0, "gift:0")
	check(gs.effective_card_cost(0, top) == 1, "晴阳和千纸千烛的免基础鬼火不能吞掉额外鬼火")
	p.units[1].awakened = false
	p.units[0].erase("spiderMark")
	opposing.formRules = {}
	check(gs.play_card(0, 0, null, "gift:0") and p.energy == fire and not gs.playable_deck_top(0), "千纸千烛的顶牌赐能免费且消耗本回合机会")
	var card := Gift.fresh_instance(gs, 0, "c63408")
	insight.place(gs, 0, card)
	insight.enter(gs, 0)
	check(gs.play_card(0, insight.zone(gs, 0).size()-1, null, "gift:0") and not insight.active(gs, 0) and p.hand.has(card), "启悟赐能保留区号，正常退区并回手")

	var enemy_white: Dictionary = gs.player(1).units[0]
	enemy_white.level = 3
	enemy_white.formRules = {"yanmieLamp": true}
	gs._knockout_unit(p.units[0])
	gs._resolve_resolution_stack()
	var revive := Gift.fresh_instance(gs, 0, "c63408")
	Gift.new_effect(revive, Gift.SUNNY_GIFTS[2])
	p.hand.append(revive)
	var charge: int = p.units[1].charge
	check(not gs.play_card(0, p.hand.size()-1, null, "gift:0") and p.hand.has(revive) and int(p.units[1].charge) == charge, "点灯人阻断提前复活赐能及其费用")
