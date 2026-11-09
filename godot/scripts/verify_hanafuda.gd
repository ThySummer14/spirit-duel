extends "res://scripts/verify_insight.gd"

const Hana := preload("res://scripts/hanafuda_rules.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const STORM := ["chulingshanfeng", "daixiaoguhuoniao", "xixueji-xiyi", "shantong"]
const WISH := ["geluoduo", "yinghuayao-lijing", "fenghuanghuo-jingyu", "yinfanhuiyeji"]
const ENEMIES := ["bingyong", "bailang", "yaohu", "xuenv"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("HANAFUDA_FAIL ", detail)

func fixture(team: Array = STORM) -> GS:
	var gs := GS.create(team, ENEMIES, 661667)
	prepare(gs)
	for owner in 2:
		var p := gs.player(owner)
		p.realms.clear()
		p.deck.clear()
		p.avatarHp = 30
		for u in p.units: u.front = 0
		for i in 12: p.deck.append(Insight.instance(gs, owner, "c11301"))
	return gs

func settle_rules(gs: GS) -> void:
	for i in 12:
		if gs.pending_choice.is_empty() and gs.response_window.is_empty(): break
		var owner := gs.action_player()
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, owner), "AI resolves " + str(gs.pending_choice.get("type", "")))
		else: gs.pass_response(owner)
	check(gs.pending_choice.is_empty() and gs.response_window.is_empty(), "resolution completes")

func readiness() -> void:
	for n in range(661, 668):
		for i in range(1, 9):
			var gs := fixture(STORM if n in [662, 663, 667] else WISH)
			var id := "c%d" % (n * 100 + i)
			var card := Content.card_def(id)
			check(card.get("verifiedRules", false) and FileAccess.file_exists("res://assets/official/cards/%s.png" % id), id + " native and original PNG")
			var src := gs._source_index(0, card)
			if id == "c66402": gs._knockout_unit(gs.player(0).units[src])
			if id == "c66104": gs._knockout_unit(gs.player(0).units[1])
			var index := give(gs, id)
			var candidate := AI._best_card(gs, 0)
			check(candidate.ok, id + " legal AI target")
			if not candidate.ok: continue
			check(gs.can_play_card(0, index, candidate.target).ok, id + " actual legal route")
			check(gs.play_card(0, index, candidate.target), id + " actual play")
			settle_rules(gs)
			check(gs.command_log.any(func(entry): return entry.c == "play_card" and entry.a.card == id and str(entry.a.cardView.effect).begins_with("hf-")), id + " announces native executor")

func storm() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var wind: Dictionary = p.units[0]
	var bird: Dictionary = p.units[1]
	var blood: Dictionary = p.units[2]
	var ally: Dictionary = p.units[3]
	check(gs.basic_attack(0, 0), "wind actual attack from reserve")
	check(Hana.enter_count(gs, wind) == 1 and wind.front == 1, "real entry triggers wind base")
	play(gs, "c66202")
	play(gs, "c66203")
	check(wind.front == 0 and wind.attack == 4 and wind.swift and not p.attackUsed and gs.VerifiedRules.Combat.has(wind, "first-strike"), "swift form and reset respond to actual movement")
	play(gs, "c66205", ally.uid)
	play(gs, "c66204", ally.uid)
	check(Hana.enter_count(gs, wind) >= 3 and int(ally.get("battlePower", 0)) >= 1, "explicit and duplicated entry affects real units and awakening")
	play(gs, "c66706")
	bird.charge = 0
	gs.VerifiedRules.Movement.move_to(gs, 0, 3, 1)
	check(bird.charge == 2 and int(bird.get("battlePower", 0)) == 1, "bird form listens to another shikigami entry")
	gs.VerifiedRules.Movement.move_to(gs, 0, 3, 0)
	gs.VerifiedRules.Movement.move_to(gs, 0, 3, 1)
	check(bird.charge == 2, "bird form ignores second entry in same turn")
	play(gs, "c66701", wind.uid)
	check(bird.charge == 5 and int(wind.get("battlePower", 0)) == 1, "chosen ally receives battle power and bird real charge")
	play(gs, "c66702", ally.uid)
	check(ally.swift and gs.basic_attack(0, 3), "selected target gains swift and can attack")
	settle_rules(gs)
	check(not p.attackUsed and bird.charge == 2 and Hana.spend_count(gs, bird) == 1 and Hana.realm_cards(gs, 0, "hf-bird")[0].hp == 3, "after allied attack real cost, realm durability and use-count: %s" % str([p.attackUsed, bird.charge, Hana.spend_count(gs, bird), Hana.realm_cards(gs, 0, "hf-bird")[0].hp]))
	var instant := gs.hand_card_def(0, give(gs, "c66705"))
	check(instant.keywords.has("instant"), "actual spending upgrades 羽授")
	p.night = 2
	foe.units[0].hp = 20
	play(gs, "c66301", foe.units[0].uid)
	check(p.night == 3 and blood.attack == 2 and foe.units[0].hp == 16, "failed night grows resource but does not grant condition")
	play(gs, "c66301", foe.units[0].uid)
	check(p.night == 3 and blood.attack == 3 and blood.maxHp == 6, "passed night grows printed body")
	play(gs, "c66307")
	var before: int = p.avatarHp
	check(blood.hp == before and blood.maxHp == p.maxAvatarHp and Hana.unyielding(blood), "shared life uses avatar actual life")
	gs._damage_unit(0, 2, 2, 1, 0)
	check(p.avatarHp == before - 2 and blood.hp == p.avatarHp, "unshielded unit damage changes same pool")
	gs._heal_avatar(0, 1)
	check(blood.hp == p.avatarHp and p.avatarHp == before - 1, "avatar healing changes same pool")
	gs.VerifiedRules.Movement.move_to(gs, 0, 2, 1)
	check(p.hand.any(func(inst): return inst.get("hfInstant", false) and Content.card_def(inst.definitionId).unitId == Hana.BLOOD), "shared form real entry produces instant eligible card")

func karuta() -> void:
	var gs := fixture(WISH)
	var p := gs.player(0)
	var foe := gs.player(1)
	play(gs, "c66101")
	check(p.hand.size() == 2 and p.hand.all(func(inst): return inst.definitionId in Hana.HANA), "花叠百景 creates only actual flower cards")
	var first: int = p.hand.find_custom(func(inst): return inst.definitionId != Hana.HANA[4])
	if first < 0: first = give(gs, Hana.HANA[2])
	var cost: int = p.energy
	check(gs.card_payment(0, gs.hand_card_def(0, first)).get("hfChain", false), "eligible flower quote free")
	check(gs.play_card(0, first) and p.energy == cost and gs.instant_available(0), "chain does not consume instant or fire")
	var next := give(gs, Hana.HANA[1])
	check(not gs.card_payment(0, gs.hand_card_def(0, next)).get("hfChain", false), "base chain quota applies")
	play(gs, "c66105")
	check(gs.pending_choice.instanceIds == Hana.HANA and not gs.resolve_divination_choice(0, "hf-rabbit-heal"), "awakening has six real options only")
	check(gs.resolve_divination_choice(0, Hana.HANA[0]) and p.units[0].awakened, "human choice grants actual selected card")
	var enemy: Dictionary = foe.units[0]
	enemy.hp = 25
	play(gs, "c66106", enemy.uid)
	check(enemy.hp == 19, "one previously used flower applies a separate repeated hit")
	gs._knockout_unit(p.units[1])
	play(gs, "c66104", p.units[1].uid)
	check(p.units[1].hp > 0, "temporary ally returns")
	turn(gs, 0)
	check(p.units[1].hp > 0, "temporary ally lasts own turn end")
	turn(gs, 1)
	check(p.units[1].hp == 0, "temporary ally expires at opponent turn end")

func wishes() -> void:
	var gs := fixture(WISH)
	var p := gs.player(0)
	var foe := gs.player(1)
	var cherry: Dictionary = p.units[1]
	var fire: Dictionary = p.units[2]
	var moon: Dictionary = p.units[3]
	var index := give(gs, "c66602")
	var inst: Dictionary = p.hand[index]
	var insight_prayer := Insight.instance(gs, 0, "c66603")
	var deck_prayer := Insight.instance(gs, 0, "c66607")
	Insight.place(gs, 0, insight_prayer)
	p.deck.push_front(deck_prayer)
	check(not gs.hand_card_def(0, index).hfPrayed, "fresh physical prayer starts unfulfilled")
	gs._knockout_unit(cherry)
	gs._resolve_resolution_stack()
	check(not inst.has("hfPray") and Hana.blossom_index(gs, 0) < 0, "reserve knockout does not trigger a will")
	cherry.hp = cherry.maxHp
	cherry.knockout = 0
	cherry.front = 1
	gs._knockout_unit(cherry)
	gs._resolve_resolution_stack()
	check(int(inst.get("hfPray", -1)) == 1 and Hana.blossom_index(gs, 0) >= 0, "front knockout makes actual summon and decrements prayer")
	play(gs, "c66402")
	var blossom: Dictionary = gs.front_unit(0)
	check(blossom.id == "hf-glass-cherry" and blossom.attack == 4 and blossom.swift, "summon fuses actual 1/1 and 3/3 body")
	play(gs, "c66601")
	check(gs.pending_choice.instanceIds == Hana.RABBIT_OPTIONS and gs.resolve_divination_choice(0, Hana.RABBIT_OPTIONS[0]), "rabbit real choice")
	var rabbit: Dictionary = gs.front_unit(0)
	check(rabbit.id == "hf-rabbit" and rabbit.attack == 3 and rabbit.hp == 3 and blossom.removed, "rabbit actual field body and prior summon leaves")
	var total: int = foe.units.reduce(func(acc, u): return acc + int(u.hp), 0)
	gs._knockout_unit(rabbit)
	gs._resolve_resolution_stack()
	check(total - int(foe.units.reduce(func(acc, u): return acc + int(u.hp), 0)) == 2 and gs.hand_card_def(0, index).hfPrayed, "rabbit will resolves twice and fulfills hand instance")
	check(int(insight_prayer.get("hfPray", -1)) == 0 and not deck_prayer.has("hfPray"), "will ticks the same card instances in hand and insight, with deck cards excluded")
	var hp: int = moon.maxHp
	check(gs.play_card(0, index, moon.uid), "琉璃光 uses actual physical instance")
	var rebound: int = p.hand.find_custom(func(copy): return copy.instanceId == inst.instanceId)
	check(rebound >= 0 and moon.maxHp == hp + 1 and p.hand[rebound].hfBounced and p.hand[rebound].hfPray == 0, "bounced same card lost bounce and keeps prayer")
	play(gs, "c66501")
	check(Hana.spark_count(gs, 0) == 2 and p.hand.filter(func(item): return item.definitionId == Hana.SPARK).size() == 1, "two sparks stack into one physical card")
	fire.front = 1
	gs._knockout_unit(fire)
	gs._resolve_resolution_stack()
	check(Hana.spark_count(gs, 0) == 3 and fire.hp == 0, "front Phoenix will generates one spark without fake automatic recovery")
	var spark_index: int = p.hand.find_custom(func(item): return item.definitionId == Hana.SPARK)
	var before: int = foe.avatarHp
	gs.discard_hand_card(0, spark_index)
	gs._resolve_resolution_stack()
	check(Hana.spark_count(gs, 0) == 1 and fire.hp > 0 and foe.avatarHp == before - 2, "discarding full stack gives two genuine effects")

func blossom_expiry() -> void:
	var gs := fixture(WISH)
	var p := gs.player(0)
	var foe := gs.player(1)
	play(gs, "c66404")
	var blossom: Dictionary = gs.front_unit(0)
	check(blossom.id == "hf-glass-cherry" and blossom.attack == 3 and blossom.inspired, "琉璃樱真实昂扬与觉醒额外身材")
	turn(gs, 0)
	check(int(blossom.hp) > 0 and int(foe.avatarHp) == 30, "琉璃樱己方回合结束仍在")
	turn(gs, 1)
	check(blossom.removed and int(foe.avatarHp) == 27 and p.units[1].awakened, "琉璃樱敌方回合结束以自身实际力量投射后自毁")

func target_and_trigger_boundaries() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var wind: Dictionary = p.units[0]
	var bird: Dictionary = p.units[1]
	var enemy: Dictionary = foe.units[0]
	enemy.level = 0
	enemy.front = 1
	enemy.hp = 20
	play(gs, "c66206")
	check(enemy.hp < 20 and enemy.front == 0, "风 moves an actual living 0-level target after dealing combat damage")
	var ally: Dictionary = p.units[3]
	ally.level = 0
	var index := give(gs, "c66701")
	check(not gs.can_play_card(0, index, enemy.uid).ok and gs.can_play_card(0, index, ally.uid).ok, "羽念 targets living allies at 0 but rejects enemies")
	check(gs.play_card(0, index, ally.uid) and int(ally.get("battlePower", 0)) == 1, "羽念 grants real battle power to the selected 0-level ally")
	check(bird.charge == 3, "羽念 gives exactly three energy")
	wind.front = 0
	ally.front = 1
	wind.keywords = ["remote"]
	wind.erase("battlePower")
	play(gs, "c66201")
	check(not gs.VerifiedRules.Combat.has(wind, "pierce"), "林 grants no pierce when remote prevents its move from reserve")

	gs = fixture(["chulingshanfeng", "daixiaoguhuoniao", "rihefang", "xiaoxiuzhishou"])
	p = gs.player(0)
	foe = gs.player(1)
	bird = p.units[1]
	var sun: Dictionary = p.units[2]
	sun.awakened = true
	bird.charge = 0
	check(gs.basic_attack(0, 0), "ally takes a real attack with the energy waiver ready")
	settle_rules(gs)
	check(foe.avatarHp == 24 and bird.charge == 0 and Hana.spend_count(gs, bird) == 0 and p.sunFreeChargeTurn == gs.turn_counter, "bird consumes the shared waiver without inventing energy spent")
	var after: int = foe.avatarHp
	p.units[3].awakened = true
	play(gs, "c66708")
	check(after - int(foe.avatarHp) == int(bird.attack) + 4, "金羽流焰 projectile is printed card damage, separate from the base-ability bonus")

func blood_form_scope() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var blood: Dictionary = p.units[2]
	var enemy: Dictionary = gs.player(1).units[0]
	p.avatarHp = 18
	play(gs, "c66307")
	var marks := Status.unit_marks(Status.unit_view(gs, 0, 2, 0), gs.turn_counter)
	check(marks.any(func(m): return m.id == "blood-shared") and marks.any(func(m): return m.id == "unyielding") and marks.any(func(m): return m.id == "lifesteal"), "二重禁忌 surfaces shared life, unyielding and own-turn lifesteal")
	enemy.hp = 14
	play(gs, "c66301", enemy.uid)
	check(enemy.hp == 10 and p.avatarHp == 22 and blood.hp == 22, "二重禁忌 grants actual spell lifesteal through the shared life pool")
	gs._damage_unit(0, 2, 40, 1, 0)
	check(p.avatarHp == 1 and blood.hp == 1 and not Hana.unyielding(blood), "二重禁忌 saves once and consumes its own shield")
	gs._heal_avatar(0, 12)
	play(gs, "c66307")
	play(gs, "c66304")
	check(not Hana.shared(blood) and not Hana.unyielding(blood) and blood.hp == 6, "replacement drops both shared life and the unused form shield")
	gs._damage_unit(0, 2, 40, 1, 0)
	check(blood.hp == 0 and p.avatarHp == 13, "lethal unit damage after replacement neither retains unyielding nor affects the avatar")

func flower_prayer_and_kindling() -> void:
	var gs := fixture(WISH)
	var p := gs.player(0)
	var foe := gs.player(1)
	var foe_unit: Dictionary = foe.units[0]
	foe_unit.level = 0
	foe_unit.hp = 20
	var veil: Dictionary = foe.units[1]
	veil.keywords = ["veil"]
	var index := give(gs, "c66106")
	check(not gs.can_play_card(0, index, veil.uid).ok and gs.can_play_card(0, index, foe_unit.uid).ok, "雨四光 includes 0-level targets while preserving opposing veil")
	play(gs, Hana.HANA[0])
	play(gs, Hana.HANA[2])
	check(gs.play_card(0, index, foe_unit.uid) and foe_unit.hp == 12, "雨四光 deals printed first hit followed by two real 2-damage packets")
	var hits: Array = gs.rule_events.filter(func(e): return e.kind == "damage-resolved" and e.get("card", {}).get("id") == "c66106")
	check(hits.map(func(e): return int(e.amount)) == [4, 2, 2], "each 雨四光 damage packet preserves its original spell provenance")
	play(gs, Hana.HANA[4], foe_unit.uid)
	var before_deck: int = p.deck.size()
	var before_avatar: int = foe.avatarHp
	play(gs, "c66107", foe_unit.uid)
	check(foe_unit.hp == 8 and p.deck.size() == before_deck - 1 and foe.avatarHp == before_avatar - 4, "五光斩 copies learned selected damage and draw before its own attack")

	var ally: Dictionary = p.units[0]
	ally.level = 0
	play(gs, "c66404")
	var token: Dictionary = gs.front_unit(0)
	index = give(gs, "c66403")
	check(gs.can_play_card(0, index, ally.uid).ok and not gs.can_play_card(0, index, token.uid).ok, "镜花千重 accepts an unactivated ally but rejects 琉璃樱")
	check(gs.play_card(0, index, ally.uid) and ally.get("hfWills", []).any(func(w): return w.kind == "blossom"), "镜花千重 attaches the printed will to the exact ally")
	play(gs, "c66607", ally.uid)
	check(ally.hfWills.map(func(w): return w.kind) == ["blossom", "revive", "blessing"], "月之洗礼 keeps the basic countdown will and its own will on a legal 0-level ally")
	play(gs, "c66603", ally.uid)
	check(ally.front == 1 and not p.attackUsed, "长明如愿 gives an attack independent of 0-level normal deployment")

	gs = fixture(WISH)
	p = gs.player(0)
	foe = gs.player(1)
	var fire: Dictionary = p.units[2]
	foe_unit = foe.units[0]
	foe_unit.hp = 12
	play(gs, "c66501")
	check(Hana.spark_count(gs, 0) == 2, "烬羽 setup uses a real two-layer spark")
	fire.front = 1
	play(gs, "c66506", foe_unit.uid)
	settle_rules(gs)
	check(foe_unit.hp == 6 and fire.hp > 0 and fire.front == 1 and fire.shield == 2 and Hana.spark_count(gs, 0) == 0, "烬羽 resolves sacrifice, six damage, will, three spark discard and live follow-up attack")
	p.hand.clear()
	play(gs, "c66501")
	play(gs, "c66507")
	gs._knockout_unit(fire)
	gs._resolve_resolution_stack()
	check(fire.hp == 0 and not fire.formRules.has("hfPhoenixForm") and Hana.spark_count(gs, 0) == 3, "夜火流空 does not discard three sparks as partial payment")
	check(Hana.revive(gs, 0, 2), "Phoenix returns through the existing revival path")
	play(gs, "c66507")
	fire.front = 1
	gs._knockout_unit(fire)
	gs._resolve_resolution_stack()
	check(fire.hp == 5 and fire.formRules.get("hfPhoenixForm", false) and fire.swift and Hana.spark_count(gs, 0) == 0, "night form pays four sparks, revives through their countdown and reattaches")

func moon_ai_revive() -> void:
	var gs := GS.create(ENEMIES, WISH, 661666)
	prepare(gs)
	turn(gs, 0)
	var p := gs.player(1)
	var ally: Dictionary = p.units[0]
	var enemy: Dictionary = gs.player(0).units[0]
	# The moon player is deliberately on side 1 so ordering cannot choose the ally.
	p.hand.clear()
	p.energy = 40
	gs._knockout_unit(ally)
	gs._knockout_unit(enemy)
	var index := give(gs, "c66604", 1)
	p.hand[index].hfPray = 0
	var candidate := AI._best_card(gs, 1)
	check(candidate.ok and candidate.target == ally.uid and gs.can_play_card(1, index, enemy.uid).ok, "祈愿羽落银阙 AI picks the allied corpse even when both sides are legal")
	check(AI.take_action(gs, 1) and ally.hp > 0 and enemy.hp == 0, "AI uses prayed form to revive its chosen ally")

func character_and_shikigami_scope() -> void:
	var gs := fixture(STORM)
	var ally: Dictionary = gs.player(0).units[3]
	var foes: Array = gs.player(1).units
	ally.level = 0
	foes[0].level = 0
	foes[0].hp = 12
	foes[1].summoned = true
	foes[2].movementVeil = true
	var blood := give(gs, "c66301")
	check(not gs.can_play_card(0, blood, foes[1].uid).ok and not gs.can_play_card(0, blood, foes[2].uid).ok, "血绽 rejects ordinary summons and opposing veil")
	check(gs.play_card(0, blood, foes[0].uid) and foes[0].hp == 8, "血绽 hits the selected zero-level shikigami")
	var crane := give(gs, "c66702")
	check(not gs.can_play_card(0, crane, foes[1].uid).ok and gs.can_play_card(0, crane, foes[0].uid).ok, "鹤羽之佑 only offers actual shikigami on either side")
	check(AI._best_card(gs, 0).target != foes[0].uid and gs.play_card(0, crane, ally.uid) and ally.swift, "鹤羽之佑 allows zero-level allies and AI prefers its own side")
	foes[1].front = 1
	foes[1].hp = 20
	play(gs, "c66206")
	check(foes[1].hp < 20 and foes[1].front == 1, "风 can fight an ordinary summon and does not move it")

	gs = fixture(WISH)
	ally = gs.player(0).units[1]
	foes = gs.player(1).units
	ally.level = 0
	foes[0].summoned = true
	foes[0].front = 1
	var spark := give(gs, "c66506")
	check(not gs.can_play_card(0, spark, foes[0].uid).ok and gs.can_play_card(0, spark, ally.uid).ok, "烬羽 allows actual zero-level shikigami only")
	var moon := give(gs, "c66602")
	check(not gs.can_play_card(0, moon, foes[0].uid).ok and gs.can_play_card(0, moon, ally.uid).ok, "琉璃光 also rejects an ordinary summon")
	var life: int = ally.maxHp
	check(gs.play_card(0, moon, ally.uid) and ally.maxHp == life + 1, "琉璃光 actually grows the chosen shikigami")
	var prayer := give(gs, "c66607")
	gs.player(0).hand[prayer].hfPray = 0
	check(gs.play_card(0, prayer, ally.uid) and foes[0].hp > 0 and foes[0].front == 1, "祈愿月之洗礼 skips a front-line summon and still attaches the will")
	foes[0].summoned = false
	prayer = give(gs, "c66607")
	gs.player(0).hand[prayer].hfPray = 0
	check(gs.play_card(0, prayer, ally.uid) and foes[0].hp == 0, "祈愿月之洗礼 destroys an actual front-line shikigami")

	gs = fixture(WISH)
	var token: Dictionary = gs.player(0).units[2]
	token.summoned = true
	play(gs, "c66108")
	life = int(token.hp)
	gs.rng_state = 0
	play(gs, Hana.HANA[2])
	check(token.hp == life - 3, "花月乱舞 random character pool includes an ordinary summon")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = viewport
		DisplayServer.window_set_size(viewport)
		var b := Battle.new()
		b.setup(WISH, ENEMIES, 661666)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, ["c66602"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		var target: Dictionary = gs.player(0).units[2]
		target.level = 0
		var attack: int = target.attack
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).has(target.uid), "mouse selects a legal actual ally")
		await click(b._unit_widget(str(target.uid)))
		await settled(b)
		check(target.attack == attack + 1 and target.has("hfWills"), "mouse target attaches will and grows selected body")
		hand(b, ["c66601"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var rabbit := choice_face(b, Hana.RABBIT_OPTIONS[1])
		check(rabbit != null, "mouse modal displays genuine rabbit options")
		if rabbit != null: await click(rabbit)
		await settled(b)
		check(gs.pending_choice.is_empty() and gs.front_unit(0).hfWills[0].kind == Hana.RABBIT_OPTIONS[1], "mouse selects healing will and summons")
		hand(b, ["c66105"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var flower := choice_face(b, Hana.HANA[0])
		check(flower != null, "mouse modal displays six actual flower cards")
		if flower != null: await click(flower)
		await settled(b)
		check(gs.pending_choice.is_empty() and gs.player(0).hand.any(func(inst): return inst.definitionId == Hana.HANA[0]), "mouse chosen flower enters hand")
		hand(b, ["c66403"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		var summon: Dictionary = gs.front_unit(0)
		check(b._pending_target_card == 0 and not gs.valid_targets(0, b._pending_target_card_def).has(summon.uid), "mouse 镜花千重 filters the summon")
		await click(b._unit_widget(str(target.uid)))
		await settled(b)
		check(target.hfWills.any(func(w): return w.kind == "blossom"), "mouse 镜花千重 attaches to the unactivated chosen ally")
		hand(b, [Hana.HANA[4]])
		await settled(b)
		await click(b._hand_row.get_child(0))
		var enemy: Dictionary = gs.player(1).units[0]
		enemy.hp = 10
		enemy.level = 0
		await click(b._unit_widget(str(enemy.uid)))
		await settled(b)
		hand(b, ["c66107"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).has(enemy.uid), "mouse 五光斩 exposes its copied 桐上凤凰 target")
		await click(b._unit_widget(str(enemy.uid)))
		await settled(b)
		check(enemy.hp == 6, "mouse 五光斩 hits the chosen unit separately from the attack")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	readiness()
	storm()
	karuta()
	wishes()
	blossom_expiry()
	target_and_trigger_boundaries()
	blood_form_scope()
	flower_prayer_and_kindling()
	moon_ai_revive()
	character_and_shikigami_scope()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("HANAFUDA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
