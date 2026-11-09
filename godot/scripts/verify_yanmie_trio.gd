extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const C := preload("res://scripts/content_loader.gd")
const Trio := preload("res://scripts/yanmie_trio_rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YANMIE_TRIO_FAIL ", text)

func fixture(enemy: Array = ["yimulian", "fenghuanghuo", "yingcao", "peach"]) -> GS:
	var gs := GS.create(["guishibai", "yingcao-pupu", "tongnantongnv", "fenghuanghuo"], enemy, 630006)
	for owner in 2:
		var p := gs.player(owner)
		p.hand.clear()
		p.deck.clear()
		p.realms.clear()
		for i in 25: p.deck.append({"instanceId":"deck-%d-%d" % [owner, i], "definitionId":"c63202"})
		p.energy = 20
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.front = 0
			u.passive_hooks = []
	return gs

func give(gs: GS, id: String, owner: int = 0) -> int:
	var hand: Array = gs.player(owner).hand
	hand.append({"definitionId":id, "instanceId":"trio-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return hand.size()-1

func play(gs: GS, id: String, target = null, origin: bool = false, owner: int = 0) -> void:
	var i := give(gs, id, owner)
	var result := gs.can_play_card(owner, i, target, origin)
	check(result.ok and gs.play_card(owner, i, target, origin), "play %s: %s" % [id, result.get("reason", "")])

func drop(gs: GS, u: Dictionary) -> void:
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()

func white_rules() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var target: Dictionary = own.units[3]
	var idx := give(gs, "c62701")
	check(not gs.can_play_card(0, idx, target.uid).ok, "royal decree rejects a unit that never revived")
	drop(gs, target)
	check(gs.VerifiedRules.Peach.revive(gs, 0, 0, target, false, false), "early revival succeeds")
	gs._resolve_resolution_stack()
	check(int(target.battlePower) == 1, "white grants revived ally 1 battle power")
	check(gs.can_play_card(0, idx, target.uid).ok, "royal decree sees current turn revival")
	var hp := int(foe.avatarHp)
	check(gs.play_card(0, idx, target.uid), "royal decree attack executes")
	check(int(foe.avatarHp) == hp-int(target.attack)-3 and int(target.front) == 1, "royal decree enters battle and uses both power bonuses")
	gs.turn_counter += 2
	idx = give(gs, "c62701")
	check(not gs.can_play_card(0, idx, target.uid).ok, "royal decree cannot use older revival")

	gs = fixture()
	own = gs.player(0)
	play(gs, "c62702")
	check(int(own.realms[0].hp) == 5 and int(gs.kw_usage(0, "encourage").battlePower) == 1, "father is printed five and grants combat power encouragement")
	target = own.units[3]
	drop(gs, target)
	check(int(target.hp) > 0 and own.realms.is_empty(), "father spends real realm and revives same ally")

	gs = fixture()
	own = gs.player(0)
	drop(gs, own.units[0])
	play(gs, "c62703")
	check(int(own.units[0].hp) == 5 and own.units[0].form.cardId == "c62703", "young form is playable while dead and revives in printed form")
	check(gs._kw(gs.hand_card_def(0, give(gs, "c62702")), "instant"), "young form grants its revived owner's dedicated cards instant")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	drop(gs, foe.units[1])
	foe.units[1].factionOverride = "苍叶"
	play(gs, "c62704", foe.units[1].uid)
	check(foe.units[1].name == "白色小鬼" and int(foe.units[1].hp) == 3 and foe.units[1].baseRulesSuppressed, "green enemy transforms to real small white ghost")
	drop(gs, foe.units[1])
	check(foe.units[1].name == "凤凰火" and int(foe.units[1].knockout) == 1, "white ghost restores identity on death and counts down one sooner")
	var before := int(own.deck.size())
	play(gs, "c62705", own.units[3].uid)
	check(int(own.units[3].hp) > 0 and own.deck.size() == before-2, "cycle destroys, revives and draws only for ally")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	play(gs, "c63002")
	var instance_id := str(own.units[1].form.cardInstance.instanceId)
	drop(gs, own.units[1])
	drop(gs, foe.units[2])
	play(gs, "c62706", own.units[1].uid)
	check(int(own.units[0].attack) == 5 and int(own.units[0].maxHp) == 7, "lamplighter uses printed body")
	check(own.units[1].form.get("cardId") == "c63002" and own.units[1].form.cardInstance.instanceId == instance_id, "early allied revival auto-uses its last departed form instance")
	check(not gs.VerifiedRules.Peach.revive(gs,1,0,foe.units[2],false,false), "lamplighter locks enemy nonzero countdown revival")
	gs.VerifiedRules.reduce_countdown(gs,1,2,2)
	check(int(foe.units[2].hp) > 0, "lamplighter allows zero countdown")
	play(gs, "c62707")
	target = own.units[3]
	drop(gs, target)
	check(gs.VerifiedRules.Peach.revive(gs,0,0,target,false,false), "awakened revival fixture")
	gs._resolve_resolution_stack()
	check(int(target.get("battlePower", 0)) == 2, "awakened white grants 2 combat power")
	drop(gs, own.units[1])
	drop(gs, foe.units[2])
	drop(gs, own.units[0])
	play(gs, "c62703")
	play(gs, "c62708", foe.units[1].uid)
	check(int(foe.units[1].hp) == 0 and int(foe.units[2].hp) > 0 and int(own.units[1].hp) > 0, "borrow excludes its destroyed target and revives one other per side")

	gs = fixture(["zhuiyueshen-shuiyue", "fenghuanghuo", "yingcao", "peach"])
	own = gs.player(0)
	play(gs, "c63002")
	var seed: Dictionary = own.units[1]
	instance_id = str(seed.form.cardInstance.instanceId)
	gs.current_player = 1
	play(gs, "c61802", seed.uid, false, 1)
	check(seed.form.is_empty() and gs.VerifiedRules.Insight.zone(gs, 0).any(func(inst): return inst.instanceId == instance_id), "enemy reflect moves the original form to its owner's insight")
	gs.current_player = 0
	drop(gs, seed)
	play(gs, "c62706", seed.uid)
	check(seed.form.get("cardId") == "c63002" and seed.form.cardInstance.instanceId == instance_id, "lamp replay reinstalls the departed form using its original instance")
	check(not gs.VerifiedRules.Insight.zone(gs, 0).any(func(inst): return inst.instanceId == instance_id), "the replayed physical form leaves insight rather than duplicating")
	var announce: Array = gs.rule_events.filter(func(event): return event.kind == "automatic-card" and event.card.id == "c63002")
	check(not announce.is_empty() and not announce.back().card.get("usedFromHand", false), "lamp replay is automatic and does not inherit the former hand-use marker")

func seed_rules() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var base_hp := int(foe.avatarHp)
	play(gs, "c63002")
	check(own.hand.any(func(i): return i.definitionId == "yanmie-wisdom"), "first use generates wisdom before a new form enters")
	check(int(foe.avatarHp) == base_hp-2 and int(own.units[1].attack) == 3, "insight form projects two")
	play(gs, "c63003")
	check(int(foe.avatarHp) == base_hp-2, "second play in turn does not replay entry")
	gs.turn_counter += 1
	var before := int(own.deck.size())
	play(gs, "c63002", null, true)
	check(own.units[1].form.cardId == "c10702" and own.units[1].form.cardInstance.definitionId == "c63002", "origin installs printed classic form using one physical seed instance")
	check(own.deck.size() == before-1, "wind draws for living allied green form")
	var instance_id := str(own.units[1].form.cardInstance.instanceId)
	play(gs, "c63001", own.units[1].uid)
	var idx: int = own.hand.find_custom(func(i): return i.instanceId == instance_id)
	check(idx >= 0 and own.units[1].form.is_empty(), "recall moves the actual form instance back")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 0, "recalled instance costs zero")
	gs.turn_counter += 1
	gs.kw_usage(0, "instant").used = true
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 1, "recall discount expires")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	var front: Dictionary = foe.units[0]
	front.front = 1
	var hp := int(front.hp)
	play(gs, "c63004")
	check(int(front.hp) == hp-2 and int(front.get("battlePower", 0)) == -2, "power seed damage and two frailty")
	gs._grant_unit_armor(front, 9)
	front.barrier = true
	front.factionOverride = "紫岩"
	gs._install_form(1,0,C.card_def("c10702"))
	play(gs,"c63005",front.uid)
	check(front.form.is_empty() and not front.barrier and int(front.shield) == 0, "wish removes violet form and punctures protection")
	check(gs.rule_events.any(func(e): return e.kind == "damage-resolved" and e.get("card", {}).get("id") == "c63005" and e.target == front.uid), "心愿达成移除形态后的延迟伤害仍归属原法术")
	play(gs, "c63006")
	play(gs, "c63008")
	check(own.units[1].form.cardId == "c63008", "waking seed is a physical form")
	check(gs.end_turn(0) and gs.end_turn(1), "advance to awakened turn start")
	check(own.units[1].form.cardId == "c10705", "awakening automatically switches to the alternate origin")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	own.units[1].level = 1
	play(gs, "c63007")
	check(own.realms[0].nativeRealm == "yanmie-clover-trick", "clover uses lower-level trick")
	base_hp = int(foe.avatarHp)
	play(gs, "c63002")
	check(int(foe.avatarHp) == base_hp-4 and int(own.units[1].front) == 0, "trick projects once without replacing actual attack mode")
	own.units[1].level = 3
	play(gs, "c63007")
	foe.units[0].front = 1
	foe.units[0].attackBonus = 9
	gs._recalc(foe.units[0])
	play(gs, "c63002")
	check(int(own.units[1].front) == 1 and int(own.units[1].hp) == int(own.units[1].maxHp), "full clover attacks with combat immunity")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	play(gs, "c63003")
	var wisdom: int = own.hand.find_custom(func(i): return i.definitionId == "yanmie-wisdom")
	check(wisdom >= 0 and gs.play_card(0, wisdom), "wisdom token playable")
	check(gs.pending_choice.get("type") == "yanmie-wisdom", "wisdom asks for its printed option")
	base_hp = int(foe.avatarHp)
	check(gs.resolve_divination_choice(0, "damage"), "wisdom resolves selection")
	check(int(foe.avatarHp) == base_hp-3, "wisdom uses current level as amount")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	play(gs, "c63006")
	play(gs, "c63002")
	var pupu: Dictionary = own.units[1]
	front = foe.units[0]
	front.front = 1
	front.hp = 2
	front.attackBonus = 30
	gs._recalc(front)
	gs.turn_counter += 1
	base_hp = int(foe.avatarHp)
	check(gs.basic_attack(0, 1) and front.hp == 0 and pupu.hp > 0, "觉醒蒲蒲攻击时先触发种子投射击倒前排，免受其反击")
	check(int(foe.avatarHp) == base_hp - int(pupu.attack), "种子投射完成后仍继续实际攻击")

	gs = fixture()
	foe = gs.player(1)
	front = foe.units[0]
	gs._apply_form(1, 0, C.card_def("c10702"))
	front.form.cardInstance = {"instanceId": "pupu-veiled-form", "definitionId": "c10702"}
	front.movementVeil = true
	var recall := give(gs, "c63001")
	check(not gs.can_play_card(0, recall, front.uid).ok, "一起回家不能选择移动能力赋予帷幕的敌方形态")
	front.movementVeil = false
	check(gs.play_card(0, recall, front.uid) and front.form.is_empty(), "敌方帷幕解除后可真实回收其形态")

func twin_rules() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var ally: Dictionary = own.units[3]
	var twins: Dictionary = own.units[2]
	gs._grant_unit_armor(ally, 2)
	gs._grant_unit_armor(ally, 3)
	check(int(ally.battlePower) == 1 and int(ally.shield) == 5, "twins grant one battle power per ally per turn")
	var before := int(own.deck.size())
	var fire := int(own.energy)
	play(gs, "c63201", ally.uid)
	check(int(own.energy) == fire and own.deck.size() == before-1, "guard launches combat and refunds at six, draws at three")
	play(gs, "c63202")
	check(gs.pending_choice.get("type") == "yanmie-song", "song asks for printed mode")
	check(gs.resolve_divination_choice(0, "armor"), "song armor mode")
	check(gs.pending_choice.get("type") == "yanmie-song-target" and not gs.resolve_divination_choice(0, foe.units[0].uid), "song targets only allied living unit")
	check(gs.resolve_divination_choice(0, twins.uid), "song awards chosen ally armor")
	var song: int = own.hand.find_custom(func(i): return i.definitionId == "c63202" and i.get("yanmieBounceSpent", false))
	check(song >= 0 and not gs._kw(gs.hand_card_def(0,song), "bounce"), "song bounces the same instance, loses bounce")
	check(gs.play_card(0, song) and gs.resolve_divination_choice(0, "divine"), "song supports second printed mode")
	check(gs.pending_choice.get("type") == "divination" and gs.pending_choice.instanceIds.size() == 2, "song starts real divination two")
	check(gs.resolve_divination_choice(0, gs.pending_choice.instanceIds[0]), "finish divination")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	ally = own.units[3]
	foe.units[0].front = 1
	foe.units[0].barrier = true
	play(gs, "c63203", ally.uid)
	gs._resolve_combat(0,3,0,false,false,false,false)
	gs._resolve_resolution_stack()
	check(int(foe.units[0].hp) == 0 and int(ally.hp) > 0, "soul offering directly destroys defender after no actual life damage")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	twins = own.units[2]
	play(gs, "c63204")
	check(Trio.top_visible(gs,0) and not Trio.top_available(gs,0), "top card displayed below three armor but is unavailable")
	play(gs, "c63205", twins.uid)
	check(Trio.top_available(gs,0) and own.hand.any(func(i): return i.definitionId == "yanmie-feather"), "coat generates feather and unlocks actual deck top")
	var top := int(own.hand.size())
	fire = int(own.energy)
	check(gs.can_play_card(0, top).ok and gs.play_card(0, top), "top card played in normal entry")
	check(int(own.energy) == fire and not Trio.top_available(gs,0), "top play is free and once per turn")
	check(gs.resolve_divination_choice(0, "armor") and gs.resolve_divination_choice(0, twins.uid), "top song resolves the same choices")
	play(gs, "c63206")
	check(gs.VerifiedRules.HairPower.guard_count(gs,0) == 1, "shrine enters with actual guard")
	twins.front = 1
	base_projectile(gs, twins)
	play(gs, "c63207")
	check(gs.pending_choice.get("type") == "yanmie-hide" and gs.resolve_divination_choice(0, "attack"), "hide choice starts actual crimson follow-up")
	check(gs.resolve_divination_choice(0, own.units[3].uid), "hide follow-up targets a crimson ally")
	check(int(own.units[3].front) == 1, "hide follow-up attacker moves into combat")
	play(gs, "c63208", twins.uid)
	gs.turn_counter += 1
	gs._grant_unit_armor(own.units[3], 6)
	check(int(own.units[3].get("battlePower", 0)) >= 6 and own.units[3].swift and gs.VerifiedRules.Combat.has(own.units[3],"pierce"), "awakened six armor grants equal power, swift and pierce")
	check(gs.end_turn(0), "end turn after song and armor")
	check(not own.hand.any(func(i): return i.definitionId == "yanmie-feather"), "feather expires at turn end")

	gs = fixture()
	own = gs.player(0)
	var summoned := gs._make_unit("non-shikigami-twins", "fenghuanghuo")
	summoned.summoned = true
	summoned.countsAsShikigami = false
	own.units.append(summoned)
	gs._grant_unit_armor(summoned, 2)
	gs._grant_unit_armor(own.units[3], 2)
	check(int(summoned.shield) == 2 and int(summoned.get("battlePower", 0)) == 0, "非式神召唤物可以获得护甲，但不触发童男童女的能力")
	check(int(own.units[3].get("battlePower", 0)) == 1, "真正的己方式神获得护甲时仍获一次战力")
	play(gs, "c63202")
	check(gs.resolve_divination_choice(0, "armor") and not gs.resolve_divination_choice(0, summoned.uid), "童羽歌护甲模式排除己方普通召唤物")
	check(gs.resolve_divination_choice(0, own.units[3].uid), "童羽歌仍可选择己方式神")

	gs = fixture()
	foe = gs.player(1)
	summoned = gs._make_unit("non-shikigami-hide", "yingcao")
	summoned.summoned = true
	summoned.countsAsShikigami = false
	summoned.factionPermanent = "苍叶"
	foe.units.append(summoned)
	foe.units[0].factionPermanent = "苍叶"
	var attack_bonus := int(foe.units[0].attackBonus)
	play(gs, "c63207")
	check(gs.resolve_divination_choice(0, "weaken"), "隐身术通过真实选项施放削弱")
	check(int(foe.units[0].attackBonus) == attack_bonus - 4 and int(summoned.attackBonus) == 0, "隐身术只削弱敌方苍叶式神")

func base_projectile(gs: GS, u: Dictionary) -> void:
	var hp := int(gs.player(1).avatarHp)
	gs.VerifiedRules.Combat.strip_protection(gs,0,2,false)
	gs._resolve_resolution_stack()
	check(int(gs.player(1).avatarHp) == hp-2 and int(u.shield) == 0, "removing front armor triggers shrine projectile")

func _initialize() -> void:
	for prefix in [627, 630, 632]:
		for i in range(1,9): check(C.card_def("c%d%02d" % [prefix,i]).get("verifiedRules", false), "verified catalogue %d/%d" % [prefix,i])
	white_rules()
	seed_rules()
	twin_rules()
	var gs := fixture()
	drop(gs,gs.player(0).units[3])
	give(gs,"c62701")
	give(gs,"c62704")
	var move := AI._best_card(gs,0)
	check(move.ok and move.card_id == "c62704" and move.target == gs.player(0).units[3].uid, "AI selects legal revival over illegal royal decree")
	print("YANMIE_TRIO checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
