extends "res://scripts/verify_insight.gd"

const MARKET_TEAM := ["zhaocaimao","maozhanggui-huanyan","fengyangjun","jintianyuzaoqian"]
const FortuneCat := preload("res://scripts/fortune_cat_rules.gd")

func fixture() -> GS:
	var gs := GS.create(MARKET_TEAM,FOE,659)
	prepare(gs)
	gs.turn_counter = 16
	return gs

func _initialize() -> void:
	for n in range(1,9):
		var gs := fixture()
		var id := "c6590%d" % n
		var i := give(gs,id)
		var target = gs.player(1).units[0].uid if n==3 else null
		check(gs.hand_card_def(0,i).get("verifiedRules",false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "原牌面 "+id)
		check(gs.can_play_card(0,i,target).ok and gs.play_card(0,i,target), "标准手牌行动 "+id)
	var gs := fixture()
	var p := gs.player(0)
	var cat: Dictionary = p.units[0]
	var foe := gs.player(1)
	var shop = gs.VerifiedRules.BattleShop
	p.avatarHp = 24
	play(gs,"c65901")
	var store: Dictionary = shop.state(gs,0)
	check(int(store.bounty)==4 and p.avatarHp==27 and store.shelf.size()==3 and not shop.unlocked(gs,1), "真实手牌收益开己方独立商店")
	play(gs,"c65902")
	play(gs,"c65904")
	check(int(store.bounty)==4, "拥有至少3赏金时御守无进场收益")
	store.bounty = 1
	gs._trigger_one_realm(0,p.realms[0].uid)
	check(int(store.bounty)==2,"事业御守以实际赏金判定回合收益")
	gs._trigger_one_realm(0,p.realms[1].uid)
	check(int(store.bounty)==4,"健康御守独立补2赏金")
	play(gs,"c65905")
	check(cat.awakened,"招财猫实际觉醒")
	store.shelf.assign([{"slot":"shop-0","id":"stars-shop-moon","price":2,"blessed":false}])
	check(shop.buy(gs,0,"shop-0") and int(store.bounty)==2, "真实使用赏金买商品")
	var product := int(p.hand.find_custom(func(i):return i.definitionId=="stars-shop-moon"))
	var enemy: Dictionary = foe.units[0]
	enemy.hp = 12
	var total: int = foe.units.reduce(func(sum,u): return int(sum)+int(u.hp),0)
	check(product>=0 and gs.play_card(0,product,enemy.uid), "手中实际使用所购商品")
	check(int(p.fortuneCatUsed)==1 and int(gs.kw_usage(0,"encourage").battlePower)==4 and int(gs.kw_usage(0,"encourage").shield)==4, "觉醒使健康御守一次商品双鼓舞")
	check(int(foe.units.reduce(func(sum,u): return int(sum)+int(u.hp),0))<=total-7, "事业御守的两次随机伤害实际结算")
	store.shelf.assign([{"slot":"shop-0","id":"stars-shop-moon","price":2,"blessed":false}])
	var bounty := int(store.bounty)
	play(gs,"c65906")
	check(int(p.fortuneCatUsed)==2 and int(store.bounty)==bounty and not store.shelf[0].get("purchased",false), "形态复制使用现有商品且保留货架和赏金")
	var i := give(gs,"c65908")
	check(int(gs.hand_card_def(0,i).value)==7 and int(gs.kw_usage(0,"encourage").battlePower)==4,"两商品实际增强且一次限定御守不重复")
	gs.turn_counter += 1
	play(gs,"c65907")
	check(int(store.bounty)>=bounty+2, "觉醒后每回合首手牌真实取得2赏金")
	check_money_charm()
	if failures == 0: print("COSMOS_MARKET_OK cases=",checks)
	quit(1 if failures else 0)

func check_money_charm() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var cat: Dictionary = p.units[0]
	for i in range(1, p.units.size()): p.units[i].hp = 0
	cat.keywords = FortuneCat.TRAITS.filter(func(keyword): return keyword not in ["lifesteal", "life-steal", "swift", "unyielding", "barrier"])
	cat.swift = true
	cat.unyielding = true
	cat.barrier = true
	play(gs, "c65907")
	var product := give(gs, "stars-shop-moon")
	var target: Dictionary = gs.player(1).units[0]
	check(gs.play_card(0, product, target.uid), "使用商店牌触发金运御守")
	check(gs.VerifiedRules.Combat.has(cat, "lifesteal"), "金运御守的随机吸血可被战斗层识别")
	cat.keywords = ["lifesteal"] if gs.VerifiedRules.Combat.has(cat, "lifesteal") else []
	p.avatarHp = 15
	check(gs.basic_attack(0, 0) and p.avatarHp > 15, "御守实际给予的吸血能在战斗中恢复牌手生命")
