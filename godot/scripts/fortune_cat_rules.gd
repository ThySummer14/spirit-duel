extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const Flow := preload("res://scripts/dragon_flow_rules.gd")
const ID := "zhaocaimao"
const BUSINESS := "fortune-cat-business"
const HEALTH := "fortune-cat-health"
const MONEY := "fortune-cat-money"
const TRAITS := ["swift","pierce","combo","remote","first-strike","direct","pursuit","penetration","unyielding","crit","lethal","lifesteal","veil","barrier","inspired"]

static func extra(gs, owner: int) -> int:
	return floori(float(gs.player(owner).get("fortuneCatUsed",0))/2.0)

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("id","") not in ["c65901","c65903","c65908"]: return card
	var out := card.duplicate(true)
	var bonus := extra(gs, owner)
	out.currentCardStats = "已使用商店牌%d张 · 增强+%d" % [int(gs.player(owner).get("fortuneCatUsed",0)),bonus]
	if out.id != "c65901":
		out.value = int(out.value)+bonus
		out.effects[0].value = out.value
	return out

static func announced(gs, frame: Dictionary) -> void:
	if not frame.get("usedFromHand",frame.get("fromHand",false)): return
	var owner := int(frame.playerIndex)
	var src := Flow.active(gs,owner,ID)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.get("fortuneCatHandTurn",-1)) == gs.turn_counter: return
	u.fortuneCatHandTurn = gs.turn_counter
	gs.VerifiedRules.BattleShop.gain_bounty(gs,owner,2 if u.awakened else 1)

static func income(gs, owner: int, realm: Dictionary) -> bool:
	var amount := [BUSINESS, HEALTH, MONEY].find(str(realm.get("nativeRealm","")))+1
	if amount == 0: return false
	if int(gs.VerifiedRules.BattleShop.state(gs,owner).bounty) < 3: gs.VerifiedRules.BattleShop.gain_bounty(gs,owner,amount)
	return true

static func turn_start(gs, owner: int) -> void:
	var src := Flow.active(gs,owner,ID)
	if src >= 0 and gs.player(owner).units[src].get("formRules",{}).get("fortuneCatCopy",false):
		gs.resolution_stack.append({"kind":"cosmos-cat-copy","playerIndex":owner,"sourceIndex":src})

static func give_trait(gs, owner: int, ally: Dictionary) -> void:
	var pool := TRAITS.filter(func(key): return not ally.get(key, false) and not gs.VerifiedRules.Combat.has(ally,key))
	var picked := Choice.sample(gs,pool,1)
	if picked.is_empty(): return
	match str(picked[0]):
		"swift": ally.swift = true
		"unyielding": ally.unyielding = true
		"barrier": ally.barrier = true
		"inspired": gs.VerifiedRules.Combat.grant_inspired(gs,owner,gs._unit_index_by_uid(owner,ally.uid))
		_:
			if not ally.has("keywords"): ally.keywords = []
			ally.keywords.append(picked[0])

static func used(gs, details: Dictionary) -> void:
	var owner := int(details.get("player",-1))
	if owner < 0: return
	var p: Dictionary = gs.player(owner)
	p.fortuneCatUsed = int(p.get("fortuneCatUsed",0))+1
	var src := Flow.source(gs,owner,ID)
	var awake: bool = src >= 0 and gs.VerifiedRules.OwlInsect.active(p.units[src]) and bool(p.units[src].awakened)
	for realm in p.realms.duplicate():
		var id := str(realm.get("nativeRealm",""))
		if int(realm.hp)<=0 or id not in [BUSINESS, HEALTH, MONEY]: continue
		if id != MONEY:
			if owner != gs.current_player or int(realm.get("fortuneCatShopTurn",-1)) == gs.turn_counter: continue
			realm.fortuneCatShopTurn = gs.turn_counter
		for _i in (2 if awake else 1):
			gs.resolution_stack.append({"kind":"cosmos-cat-realm","playerIndex":owner,"sourceIndex":src,"realm":id})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex",-1))
	var src := int(frame.get("sourceIndex",-1))
	match frame.get("kind",""):
		"cosmos-cat-copy":
			var picks := Choice.sample(gs,gs.VerifiedRules.BattleShop.offers(gs,owner).filter(func(item): return not item.get("purchased",false)),1)
			if not picks.is_empty(): gs.VerifiedRules.BattleShop.use_offer(gs,owner,str(picks[0].slot))
		"cosmos-cat-realm":
			match frame.realm:
				BUSINESS:
					var choices := Choice.sample(gs, Choice.live_units(gs,1-owner), 1)
					if not choices.is_empty(): Flow.hit(gs,owner,src,choices[0].uid,2)
				HEALTH: gs._apply_encourage(owner,0,2,2)
				MONEY:
					var choices := Choice.sample(gs, Choice.live_units(gs,owner), 1)
					if not choices.is_empty():
						var target: Dictionary = choices[0]
						gs.VerifiedRules.Glutton.record_permanent(target,2,2)
						gs._grow_unit(target,2,2)
						give_trait(gs,owner,target)
		_: return false
	return true

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id) -> bool:
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	var power := int(u.get("spellPower",0))
	match effect.action:
		"fortune_cat-1":
			gs.VerifiedRules.BattleShop.gain_bounty(gs,owner,3+extra(gs,owner))
			gs._heal_avatar(owner,3)
		"fortune_cat-2","fortune_cat-4","fortune_cat-7":
			gs._deploy_realm(owner,card)
			income(gs,owner,gs.player(owner).realms.back())
		"fortune_cat-3":
			var hit := Flow.hit(gs,owner,src,target_id,int(effect.value)+power)
			if hit.get("knocked",false): gs.VerifiedRules.HairPower.grant_guard(gs,owner,1,1)
		"fortune_cat-5": gs._awaken(owner,src,card,effect.value)
		"fortune_cat-6":
			gs._apply_form(owner,src,card,effect.value)
			gs.resolution_stack.append({"kind":"cosmos-cat-copy","playerIndex":owner,"sourceIndex":src})
		"fortune_cat-8": gs.VerifiedRules.ThreeTail.projectile(gs,owner,src,int(effect.value)+power,card.name)
		_: return false
	return true
