extends RefCounted
## In-match storefront. Bounty and stock are private to each player.
const Content := preload("res://scripts/content_loader.gd")
const BOND := "jieshen-suiyuan"
const MOUSE := "tieshu-haojia"
const BIRD := "yijin-qianxun"
const GUIDE := "stars-bird-guide"
const COST := "stars-mouse-cost"
const ESSENCE := "shengmingjinghua"
const MEAL := "stars-shop-meal"
const GOODS := [
	["swift","ink","moon","kite","flute","essence"],
	["dew","hall","drum","staff","meal"],
	["fan","wine","compass","bow","armor"],
]
const REFRESH_PRICE := 1
const TIER_THRESHOLDS := [0, 5, 10]

static func state(gs, owner: int) -> Dictionary:
	var p: Dictionary = gs.player(owner)
	if not p.has("battleShop"):
		p.battleShop = {"unlocked":false,"bounty":0,"spent":0,"shelf":[],"sold":{},"scheduled":[]}
	return p.battleShop

static func offers(gs, owner: int) -> Array:
	return state(gs, owner).shelf

static func source(gs, owner: int, role: String) -> int:
	return gs._source_index(owner, {"unitId":role})

static func tier(s: Dictionary) -> int:
	var level := 1
	for i in range(1, TIER_THRESHOLDS.size()):
		if int(s.spent) >= TIER_THRESHOLDS[i]: level = i + 1
	return level

static func open(gs, owner: int) -> bool:
	var s := state(gs, owner)
	if s.unlocked: return false
	s.unlocked = true
	refresh(gs, owner)
	return true

static func gain_bounty(gs, owner: int, amount: int) -> void:
	if amount <= 0: return
	var s := state(gs, owner)
	s.bounty += amount
	open(gs, owner)
	gs.VerifiedRules.event(gs, "bounty-gained", {"player":owner,"amount":amount,"bounty":s.bounty})

static func limit(id: String) -> int:
	if id == GUIDE: return 2147483647
	if id.begins_with("stars-bond-") or id == "c64803" or int(Content.card_def(id).get("shopTier",0)) == 3: return 1
	return 2

static func add_to_shelf(s: Dictionary, id: String, blessed := false) -> void:
	if int(s.sold.get(id, 0)) >= limit(id): return
	var def := Content.card_def(id)
	if def.is_empty(): return
	s.shelf.append({"id":id,"slot":"shop-%d" % s.shelf.size(),"price":int(def.get("shopPrice", 2)),"blessed":blessed})

static func queue(gs, owner: int, id: String, blessed := false) -> void:
	var s := state(gs, owner)
	if int(s.sold.get(id, 0)) >= limit(id) or s.scheduled.any(func(item): return item.id == id): return
	s.scheduled.append({"id":id,"blessed":blessed})

static func bless(gs, owner: int, count: int) -> void:
	var pool := offers(gs, owner).filter(func(item): return not item.blessed and not item.get("purchased", false))
	for i in mini(count, pool.size()):
		var item: Dictionary = pool.pop_at(int(gs.next_random() % pool.size()))
		item.blessed = true

static func refresh(gs, owner: int) -> void:
	var s := state(gs, owner)
	if not s.unlocked: return
	var pool: Array = []
	s.shelf = []
	for item in s.scheduled: add_to_shelf(s, str(item.id), item.blessed)
	s.scheduled = []
	var level := tier(s)
	for i in level:
		for key in GOODS[i]:
			var id := ESSENCE if key == "essence" else "stars-shop-" + str(key)
			if int(s.sold.get(id, 0)) < limit(id) and not s.shelf.any(func(item): return item.id == id): pool.append(id)
	while s.shelf.size() < 3 and not pool.is_empty(): add_to_shelf(s, str(pool[int(gs.next_random() % pool.size())]))
	if source(gs, owner, BIRD) >= 0: add_to_shelf(s, GUIDE)
	var src := source(gs, owner, BOND)
	if src >= 0 and not gs.player(owner).units[src].get("baseRulesSuppressed", false):
		var u: Dictionary = gs.player(owner).units[src]
		if int(u.hp) > 0: bless(gs, owner, 2 if u.awakened else 1)
	gs.VerifiedRules.event(gs, "shop-refreshed", {"player":owner,"level":level,"size":s.shelf.size()})

static func pay(gs, owner: int, amount: int) -> bool:
	var s := state(gs, owner)
	if int(s.bounty) < amount: return false
	s.bounty -= amount
	s.spent += amount
	for r in gs.player(owner).realms:
		if r.nativeRealm == "stars-shop-ink": r.hp = int(r.hp) + amount
	return true

static func price(gs, owner: int, item: Dictionary) -> int:
	var discount := (2 if gs.player(owner).get("starsBondDiscount", false) else 1) if item.blessed else 0
	return maxi(0, int(item.price) - discount)

static func unlocked(gs, owner: int) -> bool:
	return gs.player(owner).get("battleShop", {}).get("unlocked", false)

static func legal(gs, owner: int) -> bool:
	return gs.current_player == owner and gs.winner < 0 and gs.phase == "main" and gs.pending_choice.is_empty() and gs.response_window.is_empty() and gs.resolution_stack.is_empty() and unlocked(gs, owner) and not gs.VerifiedRules.Insight.active(gs, owner)

static func manual_refresh(gs, owner: int) -> bool:
	if not legal(gs, owner) or not pay(gs, owner, REFRESH_PRICE): return false
	refresh(gs, owner)
	gs._record("shop_refresh", {}, owner)
	gs.state_changed.emit()
	return true

static func find_offer(gs, owner: int, slot: String) -> Dictionary:
	for item in offers(gs, owner):
		if str(item.slot) == slot and not item.get("purchased", false) and int(state(gs, owner).sold.get(item.id, 0)) < limit(str(item.id)): return item
	return {}

static func make_instance(gs, owner: int, id: String, from_shop: bool = false, layers: int = 1) -> Dictionary:
	var inst: Dictionary = gs.VerifiedRules.GiftEnergy.fresh_instance(gs, owner, id)
	inst.shopProduct = from_shop
	inst.shopLayers = layers
	if id == "c64803" and from_shop: inst.shopRealmReturned = true
	return inst

static func add_hand(gs, owner: int, id: String, count: int = 1, from_shop: bool = false) -> bool:
	var p: Dictionary = gs.player(owner)
	var cap := int(Content.card_def(id).get("shopStack", 0))
	if cap <= 0 and p.hand.size() >= int(gs.rules.get("maxHandSize", 12)): return false
	var received := false
	for i in count:
		var target: Dictionary = {}
		if cap > 0:
			for inst in p.hand:
				if inst.definitionId == id and int(inst.get("shopLayers", 1)) < cap: target = inst; break
		if not target.is_empty():
			target.shopLayers = int(target.get("shopLayers", 1)) + 1
			target.shopProduct = target.get("shopProduct", false) or from_shop
		elif p.hand.size() < int(gs.rules.get("maxHandSize", 12)):
			gs.VerifiedRules.Baize.put_hand(gs, owner, make_instance(gs, owner, id, from_shop))
		else: continue
		received = true
	return received

static func can_receive(gs, owner: int, id: String) -> bool:
	var p: Dictionary = gs.player(owner)
	if p.hand.size() < int(gs.rules.get("maxHandSize", 12)): return true
	if id == ESSENCE: return p.hand.any(func(inst): return inst.definitionId == ESSENCE and int(inst.get("efStacks", 1)) <= 8)
	var cap := int(Content.card_def(id).get("shopStack", 0))
	return cap > 0 and p.hand.any(func(inst): return inst.definitionId == id and int(inst.get("shopLayers", 1)) < cap)

static func buy(gs, owner: int, slot: String, free: bool = false) -> bool:
	if not free and not legal(gs, owner): return false
	var item := find_offer(gs, owner, slot)
	if item.is_empty() or not can_receive(gs, owner, str(item.id)): return false
	var paid := 0 if free else price(gs, owner, item)
	if not pay(gs, owner, paid): return false
	var id := str(item.id)
	var s := state(gs, owner)
	item.purchased = true
	s.sold[id] = int(s.sold.get(id, 0)) + 1
	if id == ESSENCE: gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 2)
	else: add_hand(gs, owner, id, 1, id != MEAL)
	for inst in gs.player(owner).hand:
		if inst.definitionId == "stars-shop-ink" and id != "stars-shop-ink": inst.shopInkInstant = true
	if item.blessed:
		var p: Dictionary = gs.player(owner)
		p.starsBondBlessed = int(p.get("starsBondBlessed", 0)) + 1
		gs._heal_avatar(owner, 1)
		var src := source(gs, owner, BOND)
		if src >= 0 and gs.VerifiedRules.GiftEnergy.active(p.units[src]):
			var u: Dictionary = p.units[src]
			if u.awakened and int(u.get("starsBondBountyTurn", -1)) != gs.turn_counter:
				u.starsBondBountyTurn = gs.turn_counter
				gain_bounty(gs, owner, 1)
			if u.get("formRules", {}).get("starsBondGift", false) and int(u.get("starsBondFireTurn", -1)) != gs.turn_counter:
				u.starsBondFireTurn = gs.turn_counter
				gs._set_fire(owner, int(p.energy) + 1)
	gs.VerifiedRules.event(gs, "shop-purchased", {"player":owner,"cardId":id,"price":paid,"blessed":item.blessed})
	if not free:
		gs._record("shop_buy", {"slot":slot,"card":id}, owner)
		gs._resolve_resolution_stack()
		gs.state_changed.emit()
	return true

static func show(gs, owner: int) -> bool:
	if not legal(gs, owner): return false
	var options: Array = []
	for item in offers(gs, owner):
		if not find_offer(gs, owner, str(item.slot)).is_empty(): options.append(str(item.slot))
	options.append_array(["shop-refresh","shop-close"])
	var s := state(gs, owner)
	gs.VerifiedRules.StarRealms.choose(gs, owner, "shop", options, -1, "神秘商店 · 等级%d · 赏金%d" % [tier(s), int(s.bounty)], {"hint":"购买后加入手牌，使用时按卡牌规则消耗鬼火。"})
	gs.state_changed.emit()
	return true

static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type") != "stars-shop": return null
	if iid == "shop-refresh": return {"id":iid,"name":"刷新商品","type":"spell","text":"支付%d赏金，刷新你的商店。" % REFRESH_PRICE,"choiceDisabled":int(state(gs, owner).bounty)<REFRESH_PRICE}
	if iid == "shop-close": return {"id":iid,"name":"离开商店","type":"spell","text":"返回战场。"}
	var item := find_offer(gs, owner, iid)
	if item.is_empty(): return null
	var card := Content.card_def(str(item.id)).duplicate(true)
	var cost := price(gs, owner, item)
	var remaining := limit(str(item.id)) - int(state(gs, owner).sold.get(item.id, 0))
	card.name = "%s · %d赏金" % [card.name, cost]
	if item.id == ESSENCE: card.text = "瞬发，堆叠。为一个角色恢复2生命（此商品包含两层）。"
	card.text = "库存 %s\n%s" % ["无限" if item.id == GUIDE else str(remaining), str(card.text)]
	if item.blessed: card.text = "福缘。购买后回复1生命。\n" + str(card.text)
	card.choiceDisabled = cost > int(state(gs, owner).bounty) or not can_receive(gs, owner, str(item.id))
	return card

static func choice(gs, owner: int, iid: String) -> bool:
	if iid == "shop-close": return true
	var ok := manual_refresh(gs, owner) if iid == "shop-refresh" else buy(gs, owner, iid)
	if ok: show(gs, owner)
	return true

static func play_copy(gs, owner: int, card: Dictionary, target_id = null, from_hand: bool = false) -> bool:
	if card.is_empty(): return false
	var neutral := bool(card.get("shopNeutral", false))
	var src: int = -1 if neutral else gs._source_index(owner, card)
	if not neutral and src < 0: return false
	var copy := card.duplicate(true)
	if copy.get("target", "auto") != "auto" and target_id == null:
		var options: Array = gs.valid_targets(owner, copy)
		if options.is_empty(): return false
		target_id = options[int(gs.next_random() % options.size())]
	copy.usedFromHand = from_hand
	copy.shopAutomatic = true
	if neutral: push_neutral(gs, owner, copy, target_id, from_hand, true)
	else: gs._push_card_frames(owner, str(copy.id), target_id, copy, src, 0, true)
	return true

static func use_offer(gs, owner: int, slot: String) -> bool:
	var item := find_offer(gs, owner, slot)
	if item.is_empty(): return false
	if item.id == ESSENCE:
		var targets: Array = gs.VerifiedRules.EssenceFeast.essence_targets(gs, owner)
		if targets.is_empty(): return false
		var essence: Dictionary = gs.VerifiedRules.EssenceFeast.essence_card(gs, owner, {"efStacks":2})
		gs.VerifiedRules.EssenceFeast._push_essence(gs, owner, essence, targets[int(gs.next_random() % targets.size())], true)
		return true
	var card: Dictionary = gs.describe_card_instance(owner, make_instance(gs, owner, str(item.id), item.id != MEAL))
	return play_copy(gs, owner, card)

static func random_hand(gs, owner: int) -> bool:
	var hand: Array = gs.player(owner).hand
	var candidates: Array = []
	for i in hand.size():
		var card: Dictionary = gs.describe_card_instance(owner, hand[i])
		if not card.get("shopProduct", false): continue
		if card.get("target", "auto") != "auto" and gs.valid_targets(owner, card).is_empty(): continue
		candidates.append({"index":i,"card":card})
	if candidates.is_empty(): return false
	var item: Dictionary = candidates[int(gs.next_random() % candidates.size())]
	if not play_copy(gs, owner, item.card, null, true): return false
	hand.remove_at(int(item.index))
	return true

static func describe(_gs, _owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not inst.get("shopProduct", false) and not card.get("shopCard", false) and not card.has("shopStack") and not inst.get("shopRealmReturned", false): return card
	var view := card.duplicate(true)
	view.shopProduct = bool(inst.get("shopProduct", false) or card.get("shopCard", false))
	if card.has("shopStack"):
		view.shopLayers = int(inst.get("shopLayers", 1))
		view.currentCardStats = "堆叠 %d/%d" % [view.shopLayers, int(card.shopStack)]
	if inst.get("shopInkInstant", false) and not view.keywords.has("instant"): view.keywords.append("instant")
	if inst.get("shopRealmReturned", false):
		view.shopRealmReturned = true
		view.keywords.append("instant")
		view.text = "瞬发。进场时获得2赏金。己方回合开始时获得1赏金。"
	return view

static func can_play_neutral(gs, owner: int, card: Dictionary, target_id) -> Dictionary:
	if int(gs.player(owner).energy) < int(gs.card_payment(owner, card).cost): return {"ok":false,"reason":"鬼火不足。"}
	if card.get("target", "auto") != "auto" and not gs.valid_targets(owner, card).has(target_id): return {"ok":false,"reason":"请选择合法目标。"}
	if card.get("shopTier", 0) > 0:
		var highest := 0
		for u in gs.player(owner).units:
			if not u.get("summoned", false): highest = maxi(highest, int(u.level))
		if highest < int(card.level): return {"ok":false,"reason":"勾玉不足。"}
	return {"ok":true,"card":card,"source_index":-1,"reason":""}

static func push_neutral(gs, owner: int, card: Dictionary, target_id, from_hand: bool, automatic: bool) -> void:
	var rid: int = gs.next_resolution_id
	gs.next_resolution_id += 1
	var base := {"resolutionId":rid,"playerIndex":owner,"sourceIndex":-1,"definitionId":str(card.id),"cardOverride":card.duplicate(true),"targetId":target_id,"automatic":automatic,"usedFromHand":from_hand,"respondable":false,"affectedUnits":[]}
	for kind in ["card-complete","card-effect","card-announce"]:
		var frame := base.duplicate(true)
		frame.kind = kind
		frame.effectIndex = 0
		gs.resolution_stack.append(frame)

static func play_neutral(gs, owner: int, hand: int, target_id, card: Dictionary) -> bool:
	var check := can_play_neutral(gs, owner, card, target_id)
	if not check.ok: return false
	var p: Dictionary = gs.player(owner)
	var payment: Dictionary = gs.card_payment(owner, card)
	card.playedInstance = gs.take_card_instance(owner, hand)
	card.usedFromHand = not card.get("insightFromZone", false)
	gs._set_fire(owner, int(p.energy) - int(payment.cost), true)
	gs.VerifiedRules.Moon.consume_card(gs, card)
	if payment.usesInstant: gs.consume_instant(owner)
	p.cardsPlayedThisTurn = int(p.cardsPlayedThisTurn) + 1
	gs._record("play_card", {"hand":hand,"card":card.id,"target":target_id,"cardView":card,"payment":payment}, owner)
	push_neutral(gs, owner, card, target_id, card.usedFromHand, false)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("shopProduct", false) and not card.get("shopCard", false): return
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	if int(p.get("starsShopUsedTurn", -1)) != gs.turn_counter:
		p.starsShopUsedTurn = gs.turn_counter
		p.starsShopUsedCount = 0
	p.starsShopUsedCount += 1
	gs.VerifiedRules.event(gs, "shop-used", {"player":owner,"card":card,"target":frame.targetId,"automatic":frame.get("automatic", false)})
	gs.VerifiedRules.StarShopCards.product_used(gs, owner, frame, card)

static func used_count(gs, owner: int) -> int:
	var p: Dictionary = gs.player(owner)
	return int(p.get("starsShopUsedCount", 0)) if int(p.get("starsShopUsedTurn", -1)) == gs.turn_counter else 0

static func ai_purchase(gs, owner: int) -> bool:
	if not legal(gs, owner): return false
	var shelf := offers(gs, owner).filter(func(item): return not find_offer(gs, owner, str(item.slot)).is_empty() and int(state(gs, owner).bounty) >= price(gs, owner, item) and can_receive(gs, owner, str(item.id)))
	if shelf.is_empty(): return false
	shelf.sort_custom(func(a,b): return a.id == GUIDE and b.id != GUIDE or (a.id != GUIDE and b.id != GUIDE and price(gs, owner, a) < price(gs, owner, b)))
	return buy(gs, owner, str(shelf[0].slot))
