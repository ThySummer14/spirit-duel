extends "res://scripts/verify_insight.gd"

const PARTY := {635:"xiaolunan-qianshou",648:"jieshen-suiyuan",649:"tieshu-haojia",650:"yijin-qianxun",651:"baizangzhu-lixin",652:"guijinyang",653:"longche"}
const STAR_FOES := ["bingyong","fenghuanghuo","yaohu","xuenv"]

func setup(role: int) -> GS:
	var gs := GS.create([PARTY[role],"yingcao","bailang","yaodaoji"], STAR_FOES, 651653)
	prepare(gs)
	return gs

func choices(gs: GS) -> void:
	for i in 24:
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, int(gs.pending_choice.playerIndex)), "AI选择 %s" % gs.pending_choice.get("type",""))
		elif not gs.response_window.is_empty():
			check(gs.pass_response(int(gs.response_window.playerIndex)), "正常跳过响应")
		else:
			return
	check(false, "选择恢复结算")

func play_from(gs: GS, owner: int, cid: String, target_id = null, mode = false) -> bool:
	var h: int = gs.player(owner).hand.size()
	gs.player(owner).hand.append(gs.VerifiedRules.GiftEnergy.fresh_instance(gs, owner, cid))
	var legal := gs.can_play_card(owner, h, target_id, mode)
	check(legal.ok, "合法 %s %s" % [cid, legal.get("reason","")])
	return legal.ok and gs.play_card(owner, h, target_id, mode)

func catalog() -> void:
	for role in PARTY:
		for n in range(1,9):
			var gs := setup(int(role))
			var id := "c%d" % (int(role)*100+n)
			if id == "c65104": give(gs, "stars-shop-moon", 1)
			var h := give(gs, id)
			var card := gs.hand_card_def(0, h)
			check(Content.card_def(id).get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), "牌图及规则 " + id)
			var targets: Array = [null] if card.target == "auto" else gs.valid_targets(0, card)
			check(not targets.is_empty(), "有合法目标 " + id)
			if targets.is_empty(): continue
			var candidate := AI._best_card(gs, 0)
			if id in ["c65104", "c65206"]:
				check(not candidate.ok, "AI将响应保留至敌方行动 " + id)
			else: check(candidate.ok and gs.can_play_card(0, candidate.hand, candidate.target, candidate.origin).ok, "AI合法选牌 " + id)
			var legal := gs.can_play_card(0, h, targets[0])
			check(legal.ok, "正常手牌可用 %s %s" % [id, legal.get("reason","")])
			if legal.ok:
				check(gs.play_card(0, h, targets[0]), "结算 " + id)
				choices(gs)

func fox_cases() -> void:
	var gs := setup(651)
	var rules := gs.VerifiedRules.FoxFlame
	var foe: Dictionary = gs.player(1).units[0]
	var victim: Dictionary = gs.player(0).units[1]
	var initial := int(victim.hp)
	play(gs, "c65101", foe.uid)
	check(rules.marked(foe) == 1, "守护之道一层")
	rules.attach(gs, 0, 0, foe)
	gs._damage_unit(0, 1, 3, 1, 0)
	check(int(victim.hp) == initial - 2 and rules.marked(foe) == 1, "青焰减伤不叠加并消耗一层")
	gs._damage_avatar(0, 3, 1, 0)
	check(rules.marked(foe) == 1, "对牌手不消耗青焰")
	play(gs, "c65105")
	check(int(foe.get("foxFlameRed",0)) >= 1 and not foe.has("foxFlameBlue"), "觉醒强化既有狐焰")
	var before := int(foe.hp)
	gs._damage_unit(1, 0, 1, 0, 0)
	check(int(foe.hp) == before - 2, "赤焰受伤+1")
	var h := give(gs, "c65108")
	var marked: Array = gs.valid_targets(0, gs.playable_card(0,h,true))
	check(not marked.is_empty(), "戏法只选择狐焰目标")
	gs.player(0).hand.clear()
	give(gs,"c65104")
	gs._switch_turn(0)
	gs.player(0).energy = 8
	gs.player(1).energy = 8
	gs.player(1).levelUpUsed = true
	var a: Dictionary = gs.player(1).units[1]
	a.level = 3
	var target_hp := int(victim.hp)
	check(play_from(gs, 1, "c12407", victim.uid), "敌方发动牌")
	choices(gs)
	check(int(victim.hp) == target_hp, "反制跳过原效果")

func forest_cases() -> void:
	var gs := setup(635)
	var u: Dictionary = gs.player(0).units[0]
	play(gs,"c63502")
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()
	check(gs.VerifiedRules.ForestSpirit.spirit(u) and u.charge == 2 and not gs.can_basic_attack(0,0).ok, "森之灵独立气绝状态")
	check(gs.player(0).hand.any(func(x): return x.definitionId == "c63502" and x.get("forestReturned",false)), "一律移回手牌并失去回手")
	var h := give(gs,"c63501")
	check(not gs.can_play_card(0,h).ok and gs.can_play_card(0,h,null,"gift:0").ok, "森之灵不能使用本体战斗牌但能赐能")
	check(gs.play_card(0,h,null,"gift:0") and int(u.charge) == 0 and u.get("forestPursuit",false), "赐能支付与永久基础牌特性")
	var before := int(gs.player(1).avatarHp)
	play(gs,"c63503")
	check(int(u.hp) > 0 and not gs.VerifiedRules.ForestSpirit.spirit(u) and int(gs.player(1).avatarHp) == before, "0能量复活不造成伤害")
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()
	play(gs,"c63506")
	check(gs.player(0).hand.any(func(x): return x.definitionId == "stars-deer-strength"), "巨鹿神像派生牌进入手牌")
	for i in gs.player(0).hand.size():
		var c := gs.hand_card_def(0,i)
		if c.id == "stars-deer-strength": check(gs.card_payment(0,c).get("forestFree",false), "巨鹿神像不消耗瞬发")

func goat_cases() -> void:
	var gs := setup(652)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	var foe: Dictionary = gs.player(1).units[2]
	gs.VerifiedRules.GoatHeist.turn_start(gs,0)
	gs.VerifiedRules.GoatHeist.turn_start(gs,0)
	check(p.hand.filter(func(x): return x.definitionId == "stars-goat-notice").size() == 1, "预告信无重复")
	var attack := int(foe.attack)
	play(gs,"c65201",foe.uid)
	check(int(foe.attack) == attack - 1 and int(p.starsGoatStolenAttack) == 1, "双方真实移动攻击力")
	gs.VerifiedRules.GoatHeist.turn_start(gs,0)
	check(int(foe.attack) == attack and int(p.starsGoatStolenAttack) == 1, "到己方回合返还，保留历史")
	var hp := int(gs.player(1).maxAvatarHp)
	play(gs,"stars-goat-notice")
	check(int(gs.player(1).maxAvatarHp) == hp - 1 and u.starsGoatBounty == 1, "预告信将投射改为牌手生命上限转移")
	gs._knockout_unit(u)
	check(int(gs.VerifiedRules.BattleShop.state(gs,1).bounty) == 1, "悬赏从亡者发给对手")

func car_cases() -> void:
	var gs := setup(653)
	var p := gs.player(0)
	var car: Dictionary = p.units[0]
	car.barrier = true
	gs._damage_unit(0,0,2,1,0)
	gs._resolve_resolution_stack()
	check(gs.front_unit(0).is_empty(), "屏障挡下不召唤")
	gs._damage_unit(0,0,2,1,0)
	gs._resolve_resolution_stack()
	check(gs.front_unit(0).has("starsFrog") and p.starsFrogsSummoned == 1, "受伤触发独立召唤物")
	play(gs,"c65302")
	check(p.starsFrogEncouraged and gs.front_unit(0).attackBonus == 1, "鼓舞呱心的常驻成长")
	play(gs,"c65304")
	p.attackUsed = false
	check(gs.basic_attack(0,0) and gs.pending_choice.get("type","") == "stars-car-maintain", "觉醒后出击选择保养能力")
	check(not gs.resolve_divination_choice(0,"bad") and gs.resolve_divination_choice(0,"rest"), "保养不能选无效值")
	gs._knockout_unit(car)
	check(int(car.knockout) == int(gs.rules.knockoutCountdown) + 1, "胧车气绝倒计时+1")

func shop_cases() -> void:
	var gs := setup(648)
	var shop := gs.VerifiedRules.BattleShop
	var p := gs.player(0)
	check(shop.unlocked(gs, 0) and not shop.unlocked(gs, 1) and shop.offers(gs,0).size() == 3, "独立商店与首回合解锁")
	check(not shop.manual_refresh(gs, 0) and not shop.show(gs, 1), "零赏金与错方拒绝")
	shop.gain_bounty(gs, 0, 12)
	var chosen: Dictionary = shop.offers(gs,0)[0]
	var slot := str(chosen.slot)
	var expected: int = shop.price(gs,0,chosen)
	var coins := int(shop.state(gs,0).bounty)
	var fire := int(p.energy)
	check(shop.show(gs,0) and not gs.resolve_divination_choice(1,slot), "商店显示且拒绝错方")
	check(gs.resolve_divination_choice(0,slot) and int(shop.state(gs,0).bounty) == coins - expected, "UI选择真实购买扣款")
	check(p.hand.any(func(x): return x.definitionId == chosen.id and (x.get("shopProduct",false) or chosen.id == shop.ESSENCE)), "购买移入手牌实例")
	check(gs.resolve_divination_choice(0,"shop-close") and not shop.buy(gs,0,slot), "货架不能重复买")
	check(int(p.energy) == fire and not shop.unlocked(gs,1), "购买不消耗鬼火也不影响敌方")
	var product_idx := int(p.hand.size()) - 1
	var c := gs.hand_card_def(0,product_idx)
	var targets: Array = [null] if c.target == "auto" else gs.valid_targets(0,c)
	if not targets.is_empty():
		check(gs.play_card(0,product_idx,targets[0]), "中立商品真正可使用")
		check(shop.used_count(gs,0) == (0 if chosen.id == shop.ESSENCE else 1), "商店牌标记及历史计数")
	choices(gs)
	gs = setup(649)
	shop = gs.VerifiedRules.BattleShop
	shop.add_hand(gs,0,shop.COST,4)
	var hand: Array = gs.player(0).hand
	check(hand.size() == 1 and hand[0].shopLayers == 4, "成本控制合并手牌层数")
	check(gs.play_card(0,0) and shop.state(gs,0).bounty == 4, "按层获得赏金")
	gs = setup(650)
	shop = gs.VerifiedRules.BattleShop
	shop.gain_bounty(gs,0,10)
	check(shop.offers(gs,0).size() == 4 and shop.offers(gs,0)[3].id == shop.GUIDE, "风的指引独立窗口")
	shop.add_hand(gs,0,shop.GUIDE,3)
	check(gs.play_card(0,0) and int(gs.player(0).starsWindUsed) == 3, "风的指引按使用层数记录")
	check(AI.take_action(gs,0), "AI可用商店交易")
	gs = setup(650)
	play(gs, "c65006")
	check(gs.VerifiedRules.Combat.has(gs.player(0).units[0], "pursuit"), "仇羽之刃实际获得追猎")

	gs = setup(648)
	var own := gs.kw_usage(0, "encourage")
	var enemy := gs.kw_usage(1, "encourage")
	gs.VerifiedRules.StarShopCards.dharma(gs, 0, "stars-dharma-attack", {}, true)
	check(int(own.get("attack", 0)) == -3 and int(own.get("shield", 0)) == -3 and int(enemy.get("attack", 0)) == 0, "达摩强袭的压制代价扣除己方下次出击的力量和护甲")

func forest_combat_boundaries() -> void:
	var gs := setup(635)
	var p := gs.player(0)
	var foe := gs.player(1)
	var deer: Dictionary = p.units[0]
	gs._grow_unit(deer, 3, 2)
	var h := give(gs, "c63507")
	var card := gs.hand_card_def(0, h)
	check(int(card.value) == 0 and card.currentCardStats == "战力 +3 · 护甲 +2", "击鼓奏谣牌面显示真实战力和护甲")
	var hp := int(foe.avatarHp)
	check(gs.play_card(0, h) and int(foe.avatarHp) == hp - int(deer.attack) - 3 and int(deer.shield) == 2, "击鼓奏谣两种增益均进入真实出击")
	check(gs.rule_events.any(func(e): return e.kind == "battle-power-changed" and e.uid == deer.uid and e.value == 3) and not deer.has("battlePower"), "战力触发可见且按原生战力在战斗后消费")
	play(gs, "c63503")
	play(gs, "c63503")
	hp = int(foe.avatarHp)
	gs._knockout_unit(deer)
	check(gs.VerifiedRules.Peach.revive(gs, 0, 0, deer, false, false) and int(foe.avatarHp) == hp - 4, "两个七角溪畔对同次复活分别投射两点")


func bond_summon_target() -> void:
	var gs := setup(648)
	var p := gs.player(0)
	var bond: Dictionary = p.units[0]
	play(gs, "c64801")
	var house: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, 0, 0, "stars-bond-house", "缘之屋", 6, 6, {"countsAsShikigami":false})
	house.hp = 1
	var targets := gs.basic_attack_targets(0, 0)
	check(targets.has(house.uid) and targets.has("avatar-0") and not targets.has(bond.uid), "缘之书选择其他己方角色，包括非式神缘之屋")
	var before: int = gs.VerifiedRules.BattleShop.state(gs, 0).bounty
	check(gs.basic_attack(0, 0, house.uid) and int(house.hp) == 1 + int(bond.attack) and gs.front_unit(0).uid == house.uid, "真实点击目标改为治疗且保留己方召唤物")
	check(int(gs.VerifiedRules.BattleShop.state(gs, 0).bounty) == before + 2, "友方治疗出击仍结算2赏金")


func mouse_realm_copies() -> void:
	var gs := setup(649)
	var p := gs.player(0)
	var shop := gs.VerifiedRules.BattleShop
	play(gs, "c64907")
	play(gs, "c64907")
	var hp := int(p.maxAvatarHp)
	shop.add_hand(gs, 0, "stars-shop-armor", 1, true)
	var hand := int(p.hand.size()) - 1
	check(gs.play_card(0, hand) and int(p.maxAvatarHp) == hp + 15, "两张收买各复制一次同一真实商品")
	check(shop.used_count(gs, 0) == 3 and p.realms.all(func(field): return int(field.starsShopTriggerTurn) == gs.turn_counter), "复制品计作使用，但不重新递归复制")
	shop.add_hand(gs, 0, "stars-shop-armor", 1, true)
	hand = int(p.hand.size()) - 1
	check(gs.play_card(0, hand) and int(p.maxAvatarHp) == hp + 20 and shop.used_count(gs, 0) == 4, "两张收买本回合都已用，第二商品只结算本体")


func bird_ambush_boundaries() -> void:
	var gs := setup(650)
	var p := gs.player(0)
	var foe := gs.player(1)
	var bird: Dictionary = p.units[0]
	var shop := gs.VerifiedRules.BattleShop
	check(play_from(gs, 0, "c65008", null, true) and not bird.get("starsAmbush", []).is_empty(), "千羽庇佑戏法实际给予突袭")
	var bounty := int(shop.state(gs, 0).bounty)
	check(gs.basic_attack(0, 0) and int(shop.state(gs, 0).bounty) == bounty and not bird.get("starsAmbush", []).is_empty(), "攻击空场牌手不触发也不消费突袭")
	check(gs.end_turn(0), "正常结束以津真天一方回合")
	choices(gs)
	check(gs.end_turn(1), "正常结束敌方回合")
	choices(gs)
	check(not bird.get("starsAmbush", []).is_empty(), "未标本回合的千羽突袭保留到下次出击")
	foe.units[0].front = 1
	foe.units[0].hp = 30
	foe.units[0].attack = 0
	bounty = int(shop.state(gs, 0).bounty)
	check(gs.basic_attack(0, 0) and int(shop.state(gs, 0).bounty) == bounty + 2 and not bird.has("starsAmbush"), "出击实际击中式神后才触发并消费突袭")
	gs = setup(650)
	p = gs.player(0)
	bird = p.units[0]
	play(gs, "c65007")
	shop.add_hand(gs, 0, shop.GUIDE, 2)
	check(gs.play_card(0, int(p.hand.size()) - 1) and bird.swift, "金羽流光的二层风的指引获得迅捷")
	check(gs.end_turn(0) and not bird.get("swift", false), "二层风的指引迅捷随本回合结束到期")
	gs = setup(650)
	p = gs.player(0)
	bird = p.units[0]
	play(gs, "c65003")
	play(gs, "c65003")
	bird.abilityCountdown.remaining = 2
	bounty = int(shop.state(gs, 0).bounty)
	shop.add_hand(gs, 0, "stars-shop-armor", 1, true)
	check(gs.play_card(0, int(p.hand.size()) - 1) and int(shop.state(gs, 0).bounty) == bounty + 2, "两个风的祝福分别减倒计时并实际兑现基础能力")
	gs = setup(650)
	check(play_from(gs, 0, "c65008", null, true), "重新取得千羽突袭")
	bird = gs.player(0).units[0]
	gs._knockout_unit(bird)
	check(not bird.has("starsAmbush"), "气绝清除未消耗的突袭")


func fox_battle_power_boundary() -> void:
	var gs := setup(651)
	var p := gs.player(0)
	var foe := gs.player(1)
	var fox: Dictionary = p.units[0]
	var target: Dictionary = foe.units[2]
	foe.units[0].front = 1
	target.hp = 20
	target.attack = 0
	play(gs, "c65106")
	gs.VerifiedRules.FoxFlame.attach(gs, 0, 0, target)
	gs.VerifiedRules.FoxFlame.attach(gs, 0, 0, target)
	var targets := gs.basic_attack_targets(0, 0)
	check(targets.has(target.uid) and targets.has(foe.units[0].uid) and not targets.has(foe.units[1].uid), "狐啸只允许狐焰或前线式神作为出击目标")
	check(gs.basic_attack(0, 0, target.uid) and int(target.hp) == 15 and int(fox.shield) == 2, "狐啸真实攻击按目标狐焰得到等量战力和护甲")
	check(gs.rule_events.any(func(e): return e.kind == "battle-power-changed" and e.uid == fox.uid and e.value == 2) and not fox.has("battlePower"), "狐啸使用原生战力获取和消费")


func goat_limits_and_response() -> void:
	var gs := setup(652)
	var p := gs.player(0)
	var foe := gs.player(1)
	var goat: Dictionary = p.units[0]
	play(gs, "c65204")
	var attack := int(goat.attack)
	play(gs, "stars-goat-notice")
	check(int(goat.attack) == attack + 2 and goat.swift, "无踪收到真实预告信提供本回合力量和迅捷")
	check(gs.end_turn(0) and int(goat.attack) == attack and not goat.get("swift", false), "无踪力量及未用迅捷均在回合结束时到期")
	gs = setup(652)
	p = gs.player(0)
	foe = gs.player(1)
	give(gs, "stars-shop-moon", 1)
	play(gs, "stars-goat-notice")
	give(gs, "c65201")
	gs.rules.maxHandSize = 1
	check(play_from(gs, 0, "c65202", foe.units[1].uid) and foe.hand.size() == 1 and p.hand.size() == 1, "奇袭按实际手牌上限校验窃取，保留已经支付的战斗")
	for initial in [2, 3]:
		gs = setup(652)
		p = gs.player(0)
		foe = gs.player(1)
		give(gs, "c65206")
		gs.current_player = 1
		foe.energy = initial
		p.units[1].hp = 20
		check(play_from(gs, 1, "c12404", p.units[1].uid), "对手用真实非瞬发手牌后检查宿影暗度")
		choices(gs)
		check(int(foe.energy) == 1 and int(p.get("starsGoatFire", 0)) == (1 if initial == 3 else 0), "宿影暗度只在对手行动后仍有至少2鬼火时自动使用")
		if initial == 3:
			check(gs.end_turn(1) and int(p.energy) == int(gs.rules.maxEnergy) + 1, "偷取的鬼火在鬼金羊方实际下回合到账")


func car_awaken_boundaries() -> void:
	var gs := setup(653)
	var p := gs.player(0)
	var foe := gs.player(1)
	var car: Dictionary = p.units[0]
	play(gs, "c65304")
	gs._damage_unit(0, 0, 1, 1, 0)
	gs._resolve_resolution_stack()
	check(gs.front_unit(0).is_empty() and int(p.get("starsFrogsSummoned", 0)) == 0, "觉醒后受伤不再触发基础召唤能力")
	var hp := int(foe.avatarHp)
	play(gs, "c65303")
	check(gs.pending_choice.is_empty() and int(foe.avatarHp) == hp - int(car.attack), "觉醒胧车的战斗牌正常攻击，不替换成普通出击保养")
	play(gs, "c65306")
	choices(gs)
	hp = int(foe.avatarHp)
	play(gs, "c65301")
	check(int(foe.avatarHp) == hp - 5, "呱太降临的法伤也增加群呱乱舞对空场牌手的投射")

func selected_role_boundaries() -> void:
	for role in [651, 652]:
		var gs := setup(role)
		var targets: Array = gs.player(1).units
		targets[0].level = 0
		targets[1].summoned = true
		targets[2].movementVeil = true
		var cards := ["c65101", "c65107"] if role == 651 else ["c65201", "c65202", "c65205"]
		for id in cards:
			var hand := give(gs, id)
			check(gs.can_play_card(0, hand, targets[0].uid).ok, id + " accepts a living zero-level shikigami")
			check(not gs.can_play_card(0, hand, targets[1].uid).ok and not gs.can_play_card(0, hand, targets[2].uid).ok, id + " rejects an ordinary summon and movement veil")
		if role == 652:
			play(gs, "c65203")
			targets[1].attack = 7
			targets[1].hp = 20
			targets[1].front = 1
			var life: int = gs.player(1).avatarHp
			check(gs.basic_attack(0, 0) and gs.player(1).avatarHp == life and targets[1].hp < 20, "鬼星之主 does not gain direct hit from an ordinary front summon")


func _initialize() -> void:
	catalog()
	fox_cases()
	forest_cases()
	goat_cases()
	car_cases()
	shop_cases()
	forest_combat_boundaries()
	bond_summon_target()
	mouse_realm_copies()
	bird_ambush_boundaries()
	fox_battle_power_boundary()
	goat_limits_and_response()
	car_awaken_boundaries()
	selected_role_boundaries()
	print("STAR_REALMS checks=%d failures=%d" % [checks, failures])

	quit(1 if failures > 0 else 0)
