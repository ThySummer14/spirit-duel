extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Late := preload("res://scripts/coop_late_rules.gd")

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	printerr("COOP_LATE_FAIL ", label)


func game(pair: Array) -> GS:
	var allies := pair + ["quanshen", "yingcao"]
	var gs := GS.create(allies, ["bingyong", "bailang", "taohuayao", "shantong"], 1142165)
	gs.phase = "main"
	for p in gs.players:
		p.hand.clear()
		p.energy = 30
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
	return gs


func give(gs: GS, id: String) -> int:
	var p := gs.player(0)
	p.hand.append(gs.VerifiedRules.Insight.instance(gs, 0, id))
	return p.hand.size() - 1


func play(gs: GS, id: String, unit: String, target = null) -> bool:
	return gs.play_card(0, give(gs, id), target, id + ":" + unit if not unit.is_empty() else false)


func attack(gs: GS, src: int) -> void:
	gs._resolve_combat(0, src, 0, false, false, false, false)
	gs._resolve_resolution_stack()


func owl() -> void:
	var gs := game(["shanfeng", "xun"])
	var p := gs.player(0)
	var wind: Dictionary = p.units[0]
	wind.abilityCountdown.remaining = 3
	check(play(gs, "c175186", "shanfeng"), "庇羽 can be selected and cast")
	check(gs.VerifiedRules.OwlInsect.guarded(wind) and int(wind.shield) == 1 and int(wind.abilityCountdown.remaining) == 2, "bond entry attaches real guard and triggers own realm on receiving it")
	gs.VerifiedRules.OwlInsect.attach_guard(gs, 0, 1, 2)
	check(int(wind.shield) == 1 and int(wind.abilityCountdown.remaining) == 2, "attachment to a different shikigami never triggers 庇羽")
	check(play(gs, "c175186", "xun"), "鸮鸣 can be selected and cast")
	check(gs.VerifiedRules.Countdown.timer(wind).remaining == 3, "bond reduces countdown by two and resolves the real countdown")
	gs.VerifiedRules.OwlInsect.attach_guard(gs, 0, 1, 2)
	var guarded: Dictionary = p.units[2]
	var power := int(guarded.attack)
	var deck_count: int = p.deck.size()
	attack(gs, 2)
	attack(gs, 2)
	check(int(guarded.attack) == power + 2 and p.deck.size() == deck_count, "two guarded attacks get two temporary power, no draw")
	gs.end_turn(0)
	check(int(guarded.attack) == power and not guarded.has("coopLatePower"), "temporary owl power expires on actual end turn")
	gs = game(["shanfeng", "xun"])
	p = gs.player(0)
	p.units[1].level = 0
	check(play(gs, "c175186", "shanfeng") and not gs.VerifiedRules.OwlInsect.guarded(p.units[0]), "living level-zero counterpart gives no bond")


func tides() -> void:
	var gs := game(["jiuciliang", "xieji"])
	var p := gs.player(0)
	var original := give(gs, "c21004")
	var existing: Dictionary = p.hand[original]
	existing.set("coopTestMark", true)
	check(play(gs, "c179210", "jiuciliang"), "鲸甲引潮 selected")
	check(p.hand.size() == 2 and p.hand[1].instanceId != existing.instanceId and p.hand[1].get("coopTestMark", false), "entry creates a copy of the actual random hand instance")
	check(play(gs, "c179210", "xieji"), "钳浪千袭 selected")
	check(p.realms.size() == 2 and p.units[0].front == 1 and p.units[0].shield == 2, "realm use moves whale and both one-armor effects apply")
	check(play(gs, "c179210", "xieji"), "second 钳浪千袭 selected")
	check(p.realms.filter(func(r): return r.nativeRealm == Late.CRAB_WAVES).size() == 3 and p.units[0].shield == 4, "second use adds another realm and entry bond per deployed copy while whale trigger stays once")
	p.deck = [
		{"definitionId":"c21004", "instanceId":"same-name-a"},
		{"definitionId":"c21004", "instanceId":"same-name-b"},
		{"definitionId":"c21001", "instanceId":"other-name"},
	]
	check(gs.play_card(0, original), "crab can use its original held form")
	check(p.deck.size() == 1 and p.deck[0].instanceId == "other-name", "each active crab realm can draw the actual same-name deck instance")
	var deck_size: int = p.deck.size()
	check(play(gs, "c21001", "") and p.deck.size() == deck_size, "already used crab realms cannot draw again the same turn")


func sea() -> void:
	var gs := game(["lingyuyuqian", "dayueling"])
	var p := gs.player(0)
	var foe := gs.player(1)
	var target: Dictionary = p.units[2]
	target.level = 0
	var idx := give(gs, "c180190")
	var spell := gs.playable_card(0, idx, "c180190:dayueling")
	p.units[3].summoned = true
	p.units[3].countsAsShikigami = false
	var valid := gs.valid_targets(0, spell)
	check(not valid.has(foe.units[0].uid) and not valid.has(p.units[3].uid) and valid.has(target.uid), "琼玉镇海 excludes enemies and non-shikigami tokens, and includes a living zero-level ally")
	p.units[3].countsAsShikigami = true
	check(gs.valid_targets(0, spell).has(p.units[3].uid), "a summon explicitly counted as shikigami is a legal target")
	p.units[3].erase("summoned")
	p.units[3].erase("countsAsShikigami")
	var hp := int(foe.avatarHp)
	check(gs.play_card(0, idx, target.uid, "c180190:dayueling"), "琼玉镇海 selected")
	check(target.swift and target.get("otakeJades", {}).has("0") and int(foe.avatarHp) == hp - 1, "spell grants real jade at zero level, swift, and one point of bonded projection")
	target.level = 1
	hp = int(foe.avatarHp)
	var prior_break := int(foe.avatarArmorBreak)
	attack(gs, 2)
	var first := hp - int(foe.avatarHp)
	hp = int(foe.avatarHp)
	attack(gs, 2)
	check(first == int(target.attack) + prior_break + 2 and hp - int(foe.avatarHp) == int(target.attack), "jade inflicts two armor break to the real avatar once per attacker per turn")
	foe.units[0].front = 1
	foe.units[0].armorBreak = 3
	foe.units[0].attack = 0
	check(play(gs, "c180190", "lingyuyuqian"), "裂甲归潮 selected")
	check(p.units[0].get("otakeJades", {}).has("0") and target.get("otakeJades", {}).is_empty(), "combat bond transfers the same unique jade to Suzuka")
	check(int(p.units[0].shield) == 5, "combat gives armor equal to actual defender armor break, including this attack's two")
	var jade_source: int = gs._source_index(0, {"unitId":"dayueling"})
	gs.VerifiedRules.Otakemaru.attach(gs, 0, jade_source, 1, 1)
	p.units[0].shield = 0
	gs._resolve_combat(1, 1, 0, false, false, false, false)
	gs._resolve_resolution_stack()
	check(gs.rule_events.any(func(e): return e.kind == "armor-break-gained" and e.player == 1 and e.uid == foe.units[1].uid and e.amount == 2), "jade history applies to the current carrier, including an opposing shikigami")
	gs = game(["lingyuyuqian", "dayueling"])
	p = gs.player(0)
	p.units[1].level = 0
	check(play(gs, "c180190", "lingyuyuqian") and p.units[0].get("otakeJades", {}).is_empty() and int(p.units[0].shield) == 0, "no bond and no armor break leave jade and armor absent")


func fish() -> void:
	var gs := game(["hetong", "liyujing"])
	var p := gs.player(0)
	var foe := gs.player(1)
	attack(gs, 0)
	attack(gs, 0)
	var idx := give(gs, "c213282")
	var koi := gs.playable_card(0, idx, "c213282:liyujing")
	var targets := gs.valid_targets(0, koi)
	check(not targets.has(p.units[1].uid) and not targets.has(foe.units[0].uid) and targets.has(p.units[2].uid), "潮汐共舞 cannot choose its caster or an enemy")
	var power := int(p.units[2].attack)
	var hp := int(foe.avatarHp)
	check(koi.currentCardStats == "本回合力量 +3" and gs.play_card(0, idx, p.units[2].uid, "c213282:liyujing"), "two actual Kappa attacks improve bonded current card stats")
	check(int(p.units[2].attack) == power + 3 and int(foe.avatarHp) == hp - power - 3, "temporary strength is active in the commanded combat")
	idx = give(gs, "c213282")
	var marked: Dictionary = p.hand[idx]
	gs.VerifiedRules.HandBlessing.apply_mark(gs, 0, 0, marked, "ward", ["instant"])
	gs.VerifiedRules.HandBlessing.apply_mark(gs, 1, 0, marked, "erosion", ["cancel"])
	var boosted := Late.wave_values(gs, 0, true)
	var total := 0
	for value in boosted: total += int(value)
	check(total == 8 and Late.wave_values(gs, 0, false) == [4,1,1,1], "only actual own wards improve exactly one numeric parameter")
	hp = int(foe.avatarHp)
	check(gs.play_card(0, idx, null, "c213282:hetong"), "碧波连弹 selected")
	check(int(foe.avatarHp) == hp - int(boosted[0]), "projectile uses deterministic earned damage")
	var grown: Array = p.units.filter(func(unit): return int(unit.attackBonus) > 0 and int(unit.maxHpBonus) > 0)
	check(grown.size() == int(boosted[1]) and grown.all(func(unit): return int(unit.attackBonus) == int(boosted[2]) and int(unit.maxHpBonus) == int(boosted[3])), "random distinct friendly shikigami each get the earned permanent growth")
	p.units[0].level = 1
	idx = give(gs, "c213282")
	var plan := AI._best_card(gs, 0)
	check(plan.ok and plan.hand == idx and plan.get("origin") == "c213282:liyujing" and targets.has(plan.target), "AI selects the only eligible face and a legal other ally")


func forest() -> void:
	var gs := game(["tengji", "song"])
	var p := gs.player(0)
	var foe := gs.player(1)
	p.units[1].level = 1
	check(play(gs, "c228244", "tengji"), "绮幻之舞 selected")
	var phantom: Dictionary = p.units.back()
	check(int(p.units[0].attack) == 1 and int(p.units[0].maxHp) == 1, "vine form uses printed 1/1")
	check(phantom.get("vineSummon", false) and int(phantom.baseAttack) == 1 and int(phantom.baseMaxHp) == 1 and int(phantom.vineCharm.count) >= 2 and phantom.swift, "bond summons partner-level phantom, then aura adds the real second charm and swift")
	var prior_vines := int(phantom.vineCharm.count)
	gs.VerifiedRules.Vine.attach(gs, 0, 2)
	check(int(p.units[2].vineCharm.count) == prior_vines + 1 and not p.units[2].get("swift", false), "aura is once per turn and generic allies do not gain swift")
	gs = game(["tengji", "song"])
	p = gs.player(0)
	foe = gs.player(1)
	check(play(gs, "c228244", "song"), "浮华鸣乐 selected")
	var song: Dictionary = p.units[1]
	check(song.form.name == "浮华鸣乐" and gs.VerifiedRules.Combat.has(song, "remote") and song.get("vineCharm", {}).get("count", 0) > 0 and not song.get("swift", false), "song form has remote and bond vine, without invented swift")
	foe.units[0].front = 1
	foe.units[0].hp = 30
	for i in [1, 2, 3]: foe.units[i].hp = 0
	foe.units[2].hp = 30
	var hp := int(song.hp)
	attack(gs, 1)
	check(int(foe.units[0].hp) == 30 and int(foe.units[2].hp) == 30 - int(song.attack) and int(song.hp) == hp, "combat damage moves to living reserve while remote prevents front counterattack")
	check(gs.rule_events.any(func(e): return e.kind == "combat-damage-resolved" and e.uid == song.uid and e.target == foe.units[2].uid), "combat presentation and damage observers receive the actual reserve target")
	foe.units[2].hp = 0
	attack(gs, 1)
	check(int(foe.units[0].hp) == 30 - int(song.attack), "no living reserve means the actual combat defender takes damage")


func _initialize() -> void:
	owl()
	tides()
	sea()
	fish()
	forest()
	print("COOP_LATE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
