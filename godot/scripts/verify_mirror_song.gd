extends "res://scripts/verify_book_jue_ui.gd"

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const MS := preload("res://scripts/mirror_song_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MIRROR_SONG_FAIL ", detail)

func game(lineup: Array = ["yunwaijing", "song", "shuweng", "taohuayao"], foe_lineup: Array = ["bingyong", "yaodaoji", "fenghuanghuo", "baizangzhu"]) -> GS:
	var gs := GS.create(lineup, foe_lineup, 242244)
	for p in gs.players:
		p.hand.clear(); p.deck.clear(); p.energy = 40; p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.rule_events.clear()
	return gs

func inst(gs, id: String) -> Dictionary:
	var item := {"definitionId": id, "instanceId": "mirror-song-test-%d" % gs.next_card_id}
	gs.next_card_id += 1
	return item

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append(inst(gs, id))
	return gs.player(owner).hand.size() - 1

func put_deck(gs, ids: Array, owner: int = 0) -> void:
	gs.player(owner).deck.clear()
	for id in ids: gs.player(owner).deck.append(inst(gs, str(id)))

func play(gs, id: String, target = null, owner: int = 0) -> void:
	var h := give(gs, id, owner)
	var legal: Dictionary = gs.can_play_card(owner, h, target)
	check(gs.play_card(owner, h, target), "actual use " + id + " " + str(legal.get("reason", "")))

func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == kind)

func finish(gs, owner: int = 0) -> void:
	var guard := 0
	while not gs.pending_choice.is_empty() and guard < 50:
		guard += 1
		check(AI._resolve_choice(gs, owner), "AI completes " + str(gs.pending_choice.get("type", "")))
	check(guard < 50, "choice continuations terminate")

func linked_use(gs, original: String, other: String, selected: String, target = null) -> void:
	put_deck(gs, [other])
	var h := give(gs, original)
	check(gs.play_card(0, h) and gs.pending_choice.get("type") == "native-link", "actual use opens link " + original)
	var iid := ""
	for option in gs.pending_choice.get("options", []):
		if str(option.definitionId) == selected: iid = str(option.instanceId)
	check(iid != "" and gs.resolve_divination_choice(0, iid), "select actual linked card " + selected)
	check(gs.play_card(0, h, target), "execute selected linked card " + selected)
	finish(gs)

func first_card(unit_id: String, type: String = "") -> String:
	for c in Content.cards_for_unit(unit_id):
		if (type == "" or c.type == type) and not c.get("token", false): return str(c.id)
	return ""

func definitions() -> void:
	var gs := game()
	check(gs.player(0).units[0].attack == 2 and gs.player(0).units[0].maxHp == 5, "printed mirror2/5")
	check(gs.player(0).units[1].attack == 3 and gs.player(0).units[1].maxHp == 4, "printed song3/4")
	for role_id in [242, 244]:
		for n in range(1, 9):
			var c := Content.card_def("c%d%02d" % [role_id, n])
			check(c.get("mirrorSongRules", false) and c.get("verifiedRules", false) and not c.effects.is_empty(), "executable definition " + c.id)
			check(not c.get("verificationPending", []).is_empty() and FileAccess.file_exists("res://assets/official/cards/%s.png" % c.id), "original art and pending boundaries " + c.id)

func link_choices() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	put_deck(gs, ["c24207"]); var original := inst(gs, "c24201"); p.hand.append(original)
	var fire := int(p.energy); var hp := int(foe.avatarHp)
	check(gs.play_card(0, 0) and gs.pending_choice.type == "native-link" and gs.pending_choice.options.size() == 2, "mirror shows original and one true dedicated deck card")
	check(p.energy == fire and p.hand.size() == 1 and p.deck.size() == 1 and foe.avatarHp == hp, "link selection itself pays nothing and performs no card effect")
	check(not gs.resolve_divination_choice(1, str(original.instanceId)) and not gs.resolve_divination_choice(0, "invented"), "foreign or fabricated link cannot commit")
	var before := JSON.stringify(gs.snapshot())
	var displayed: Dictionary = gs.VerifiedRules.Link.choice_card(gs, 0, str(original.instanceId))
	check("crit" in displayed.keywords and displayed.get("bloodSpellLifeSteal", false), "both participants expose granted crit and lifesteal before selection")
	check(before == JSON.stringify(gs.snapshot()), "link preview cannot alter physical zones or pay resources")
	check(gs.resolve_divination_choice(0, str(original.instanceId)) and gs.player(0).get("linkReady", {}).msLink, "selected actual instance becomes ready")
	check(gs.play_card(0, 0, "avatar-1") and p.energy == fire - 1 and foe.avatarHp == hp - 6, "exactly selected spell resolves once with actual crit")
	check(p.hand.is_empty() and p.deck.size() == 1 and p.deck[0].definitionId == "c24207" and not p.deck[0].has("msLinkTraits"), "unselected ordinary card returns without temporary enhancements")
	check(events(gs, "link-used").size() == 1 and events(gs, "link-used")[0].participants == 2, "one real two-participant link is recorded")
	gs = game(); p = gs.player(0); p.units[0].level = 1
	put_deck(gs, ["c24207", "c24204", "c24202"])
	check(MS.candidates(gs, 0, Content.card_def("c24201")).map(func(i): return i.definitionId) == ["c24202"], "mirror deck search respects actual current level")
	for state in ["knocked", "unleveled", "suppressed"]:
		gs = game(); p = gs.player(0); put_deck(gs, ["c24202"])
		if state == "knocked": gs._knockout_unit(p.units[0], 1, 0)
		elif state == "unleveled": p.units[0].level = 0
		else: p.units[0].baseRulesSuppressed = true
		var h := give(gs, "c24201")
		check(MS.candidates(gs, 0, Content.card_def("c24201")).is_empty() and not gs.play_card(0, h, "avatar-1") and p.hand.size() == 1, "inactive mirror cannot link or pay: " + state)
	gs = game(); p = gs.player(0); put_deck(gs, ["c24202"]); p.units[0].frozen = 1
	check(not gs.play_card(0, give(gs, "c24201"), "avatar-1") and p.hand.size() == 1, "stunned source cannot begin active link")
	gs = game(); p = gs.player(0); p.units[2].front = 1
	put_deck(gs, ["c24201", first_card("shuweng"), first_card("taohuayao")])
	check(MS.groups(gs, 0, Content.card_def("c24403")).size() == 1 and MS.candidates(gs, 0, Content.card_def("c24403"))[0].definitionId == first_card("shuweng"), "unawakened song links only the other allied front shikigami")
	p.units[2].front = 0; p.units[1].front = 1
	check(MS.groups(gs, 0, Content.card_def("c24403")).is_empty(), "song cannot link itself as allied front")
	p.units[1].awakened = true
	var h := give(gs, "c24403")
	check(gs.play_card(0, h) and gs.pending_choice.options.size() == 4, "awakened song presents one actual card from each of three other living base allies")
	var chosen := str(gs.pending_choice.options.filter(func(i): return i.definitionId == "c24201")[0].instanceId)
	check(gs.resolve_divination_choice(0, chosen) and gs.play_card(0, h, "avatar-1"), "song may actually choose the other ally's card")
	check(p.deck.size() == 3 and p.deck.any(func(i): return i.definitionId == "c24403") and events(gs, "link-used").back().participants == 4, "all three unchosen physical instances return in the same link")
	check(not p.deck.any(func(i): return i.instanceId == chosen), "selected deck instance is removed exactly once")

func permanent_form() -> void:
	var gs := game(["yunwaijing", "song", "yi", "taohuayao"]); var p: Dictionary = gs.player(0)
	linked_use(gs, "c24202", "c24201", "c24202")
	var u: Dictionary = p.units[0]; var physical := str(u.form.cardInstance.instanceId)
	check(u.attack == 4 and u.maxHp == 6 and gs.VerifiedRules.Combat.has(u, "lifesteal"), "participating floating form keeps +1/+1 and inherited lifesteal")
	put_deck(gs, ["c24207", "c24204"])
	play(gs, "c23907"); finish(gs)
	var returned: Dictionary = p.deck.filter(func(i): return str(i.instanceId) == physical)[0]
	check(returned.get("msLinkPower", 0) == 1 and "lifesteal" in returned.get("msLinkTraits", []) and not returned.get("linkedUse", false), "review returns exact persistent enhanced form without one-use link tags")
	check(not returned.has("msLinked") and not returned.has("msLinkOtherIds"), "review clears multi-link bookkeeping while retaining permanent mirror enhancements")
	p.deck.erase(returned); p.hand.append(returned)
	put_deck(gs, ["c24207"])
	var h: int = p.hand.find_custom(func(i): return str(i.instanceId) == physical)
	check(gs.play_card(0, h) and gs.pending_choice.type == "native-link", "returned persistent form links again through actual hand use")
	check(gs.resolve_divination_choice(0, physical) and gs.play_card(0, h), "player reuses the same physical enhanced form")
	finish(gs)
	check(u.attack == 5 and u.maxHp == 7 and gs.VerifiedRules.Combat.has(u, "lifesteal") and gs.VerifiedRules.Combat.has(u, "crit"), "later link stacks printed form growth and preserves prior extra keyword")
	check(str(u.form.cardInstance.instanceId) == physical, "replayed form preserves original physical identity")
	gs = game(); p = gs.player(0)
	linked_use(gs, "c24202", "c24205", "c24202")
	p.energy = 0
	check(p.units[0].swift and gs.can_basic_attack(0, 0).ok, "linked mirror flower gives the selected form a real zero-fire swift attack")
	check(gs.basic_attack(0, 0) and not p.units[0].swift, "real basic attack consumes inherited swift")
	gs = game(); p = gs.player(0); p.units[0].awakened = true
	linked_use(gs, "c24202", "c24202", "c24202")
	check(p.energy == 40 and gs.kw_usage(0, "instant").used, "awakened same-name link gains actual instant payment")
	gs = game(["yunwaijing", "song", "yi", "taohuayao"]); p = gs.player(0)
	linked_use(gs, "c24205", "c24201", "c24205")
	physical = str(p.units[0].form.cardInstance.instanceId)
	check(gs.VerifiedRules.Combat.has(p.units[0], "lifesteal"), "different installed mirror form uses the effect of its actual selected link")
	play(gs, "c23907"); finish(gs)
	returned = p.deck.filter(func(i): return str(i.instanceId) == physical)[0]
	check(not returned.has("msLinkTraits") and not returned.has("msLinked"), "review removes temporary linked enhancements from a form without permanent retention")
	p.deck.erase(returned); p.hand.append(returned); put_deck(gs, ["c23908"])
	var returned_hand: int = p.hand.find_custom(func(i): return str(i.instanceId) == physical)
	check(gs.play_card(0, returned_hand) and not gs.VerifiedRules.Combat.has(p.units[0], "lifesteal"), "ordinary form replays without a stale previous-link effect")

func damage_and_combat() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); p.avatarHp = 20
	linked_use(gs, "c24201", "c24201", "c24201", "avatar-1")
	check(foe.avatarHp == 27 and p.avatarHp == 23, "linked lifesteal heals true direct avatar damage")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.avatarHp = 20
	foe.units[0].hp = 1; foe.units[0].shield = 1
	linked_use(gs, "c24201", "c24203", "c24201", foe.units[0].uid)
	check(foe.units[0].hp == 0 and foe.avatarHp == 29, "spell pierce allocates excess after armor to the actual enemy avatar")
	check(p.avatarHp == 22, "piercing spell lifesteal cannot count the same allocated overflow twice")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.avatarHp = 20; foe.units[0].hp = 1; foe.units[0].shield = 1
	put_deck(gs, ["c24203"]); var blessed := give(gs, "c24201")
	check(gs.VerifiedRules.HandBlessing.apply_mark(gs, 0, 0, p.hand[blessed], gs.VerifiedRules.HandBlessing.WARD, ["spell+1"]), "actual hand mark applies to linked source instance")
	check(gs.play_card(0, blessed), "blessed piercing link starts")
	var blessed_iid := str(gs.pending_choice.original.instanceId)
	check(gs.resolve_divination_choice(0, blessed_iid) and gs.play_card(0, blessed, foe.units[0].uid), "blessed linked spell uses its exact enhanced instance")
	check(foe.avatarHp == 28 and p.avatarHp == 23, "pierce allocation does not apply spell bonus or lifesteal to overflow twice")
	for mirror_power in [2, 1]:
		gs = game(); p = gs.player(0); foe = gs.player(1)
		gs._grow_unit(p.units[0], mirror_power - int(p.units[0].attack), 20)
		gs._grow_unit(foe.units[1], 0, 20); var hp := int(foe.units[1].hp); var own := int(p.units[0].hp); var enemy_power := int(foe.units[1].attack)
		play(gs, "c24203", foe.units[1].uid)
		check(foe.units[1].hp == hp - maxi(0, enemy_power - 2) and p.units[0].hp == own - mirror_power, "actual swap precedes signed card bonus and counter: source" + str(mirror_power))
		check(p.units[0].attack == mirror_power and foe.units[1].attack == enemy_power, "power exchange does not change later panel strength")
		var exchange: Dictionary = events(gs, "ms-power-swapped")[0]
		check(exchange.currentAttack == enemy_power and exchange.currentCounter == mirror_power and not p.units[0].has("msSwapDeltas") and not foe.units[1].has("msSwapDeltas"), "actual panels are swapped during combat and only current exchange is restored")
	gs = game(); p = gs.player(0); foe = gs.player(1); gs._grow_unit(p.units[0], 0, 20); gs._grow_unit(foe.units[1], 0, 20)
	p.units[0].temporaryAttack = 4; gs._recalc(p.units[0]); var previous_hp := int(p.units[0].hp); var previous_enemy_hp := int(foe.units[1].hp)
	play(gs, "c24203", foe.units[1].uid)
	check(p.units[0].hp == previous_hp - 6 and foe.units[1].hp == previous_enemy_hp - 1, "swap reads actual temporary-buffed panel before both strike calculations")
	check(p.units[0].attack == 6 and p.units[0].temporaryAttack == 4 and foe.units[1].attack == 3, "exchange cleanup preserves unrelated temporary power")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[0].hp = 1; gs._grow_unit(foe.units[1], 0, 20)
	play(gs, "c24203", foe.units[1].uid)
	check(p.units[0].hp == 0 and p.units[0].attack == 2 and foe.units[1].attack == 3 and not p.units[0].has("msSwapDeltas"), "actual knockout clears swap ledger before finish and cannot refund cleared power")
	gs = game(["yunwaijing", "song", "rihefang", "taohuayao"]); p = gs.player(0); foe = gs.player(1)
	var interrupted := {"playerIndex": 0, "sourceIndex": 0, "defenderIndex": 1, "combatId": 2420301, "attackBaseBonus": -2, "options": {"combatCard": Content.card_def("c24203")}}
	MS.combat_prepare(gs, interrupted)
	check(p.units[0].attack == 3 and foe.units[1].attack == 2, "interrupted combat snapshot contains actual exchanged panels")
	play(gs, "c16606", p.units[0].uid)
	MS.combat_finished(gs, 0, 0, interrupted.options)
	check(p.units[0].attack == 2 and foe.units[1].attack == 3 and not p.units[0].has("msSwapDeltas"), "actual numeric reset clears the pending refund ledger while restoring the other combatant normally")
	gs = game(); p = gs.player(0); foe = gs.player(1); foe.units[1].front = 1; gs._grow_unit(foe.units[1], 0, 20)
	var hp := int(foe.units[1].hp); play(gs, "c24207")
	check(foe.units[1].hp == hp - 2 and p.units[0].hp == 5 and p.units[0].shield == 1, "plain mirror rage grants printed armor4 and real combat")
	gs = game(); foe = gs.player(1); foe.units[0].front = 1
	play(gs, "c24204"); check(foe.units[0].hp == 2 and foe.avatarHp == 30, "plain4 projectile hits current front")
	gs = game(); foe = gs.player(1); play(gs, "c24204"); check(foe.avatarHp == 26, "plain projectile reaches empty front avatar")
	gs = game(); foe = gs.player(1); var healths: Array = foe.units.map(func(u): return u.hp)
	play(gs, "c24208")
	check(foe.avatarHp == 28 and range(4).all(func(i): return foe.units[i].hp == healths[i] - 2), "comprehension really hits all opposing characters")
	gs = game(); foe = gs.player(1)
	linked_use(gs, "c24201", "c24204", "c24201", "avatar-1")
	check(foe.avatarHp == 25, "tanna link adds a real2 projectile in addition to selected spell3")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	put_deck(gs, ["c24208", "c11901", "c11902"]); var h := give(gs, "c24201")
	check(gs.play_card(0, h), "draw-granting link starts")
	var original := str(gs.pending_choice.original.instanceId)
	check(gs.resolve_divination_choice(0, original) and gs.play_card(0, h, "avatar-1"), "use original card with linked draw")
	check(p.hand.size() == 1 and p.deck.size() == 2 and foe.avatarHp == 27, "linked draw obtains a real physical card without casting the unselected area spell")

func song_targets_and_beauty() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	var h := give(gs, "c24401"); foe.units[2].keywords = ["veil"]; foe.units[0].front = 1
	var valid := gs.valid_targets(0, gs.hand_card_def(0, h))
	check(valid.has(foe.units[1].uid) and not valid.has(foe.units[0].uid) and not valid.has(foe.units[2].uid), "verse targets only legal enemy reserve shikigami")
	check(not gs.play_card(0, h, foe.units[0].uid) and p.energy == 40, "verse rejects current enemy front before payment")
	var command: Dictionary = Content.card_def("c24405")
	foe.units[3].summoned = true; foe.units[3].countsAsShikigami = false
	check(not gs.valid_targets(0, command).has(foe.units[3].uid) and not gs.valid_targets(0, command).has("avatar-1"), "command targets other shikigami and excludes nonshikigami bodies and avatars")
	foe.units[0].summoned = true; foe.units[0].countsAsShikigami = false
	check(gs.valid_targets(0, command).is_empty() and not gs.can_play_card(0, give(gs, "c24405"), p.units[2].uid).ok, "command requires an actual enemy front shikigami before paying")
	foe.units[0].erase("summoned"); foe.units[0].erase("countsAsShikigami"); foe.units[3].erase("summoned"); foe.units[3].erase("countsAsShikigami")
	p.units[2].front = 1; var own_hp := int(p.units[1].hp); gs._grow_unit(foe.units[1], 0, 20); var hp := int(foe.units[1].hp)
	check(gs.play_card(0, h, foe.units[1].uid), "verse really moves selected reserve and attacks")
	check(foe.units[1].front == 1 and foe.units[0].front == 0 and foe.units[1].hp == hp - 4, "verse moves actual enemy then deals printed remote combat")
	check(p.units[2].front == 1 and p.units[1].front == 0 and p.units[1].hp == own_hp, "remote attack does not enter own front or take counter damage")
	gs = game(); p = gs.player(0); foe = gs.player(1); foe.units[0].front = 1; gs._grow_unit(foe.units[1], 0, 20)
	var incoming := int(foe.units[0].attack); hp = int(foe.units[1].hp)
	play(gs, "c24404")
	check(gs.pending_choice.type == "ms-beauty" and str(foe.units[0].uid) not in gs.pending_choice.instanceIds, "beauty opens second-level receiver choice excluding actual combat foe")
	check(not gs.resolve_divination_choice(0, str(foe.units[0].uid)) and not gs.resolve_divination_choice(1, str(foe.units[1].uid)), "beauty rejects invalid receiver or opposing controller")
	check(gs.resolve_divination_choice(0, str(foe.units[1].uid)), "player chooses actual receiving enemy")
	check(p.units[1].hp == 4 and foe.units[1].hp == hp - incoming and not p.units[1].has("msBeautyReceiver"), "receiver takes actual counter damage and transfer ends with combat")
	gs = game(); p = gs.player(0); foe = gs.player(1); p.units[2].front = 1; gs._grow_unit(foe.units[0], 0, 20); gs._grow_unit(foe.units[1], 0, 20)
	hp = int(foe.units[0].hp); var attacker_hp := int(foe.units[1].hp); incoming = int(foe.units[1].attack); give(gs, "c24404"); gs.current_player = 1
	check(gs.basic_attack(1, 1) and gs.pending_choice.get("type") == "ms-beauty", "real enemy attack automatically pays for front ally's beauty response")
	check(p.hand.is_empty() and p.energy == 39 and events(gs, "response-card").size() == 1, "automatic beauty consumes one real hand card and one fire")
	check(gs.resolve_divination_choice(0, str(foe.units[0].uid)), "defensive beauty player chooses receiver")
	check(p.units[1].front == 1 and p.units[2].front == 0 and p.units[1].hp == 4 and p.units[2].hp == p.units[2].maxHp, "responding song actually replaces allied front and protects old body")
	check(foe.units[0].hp == hp - incoming and foe.units[1].hp == attacker_hp - 3, "defensive response transfers one incoming strike and retains real counterattack")

func barrier_spell_lifesteal() -> void:
	for persistent_form in [false, true]:
		var gs := game(["yunwaijing", "song", "yi", "taohuayao"]); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
		if persistent_form:
			linked_use(gs, "c24202", "c24201", "c24202")
			var physical := str(p.units[0].form.cardInstance.instanceId)
			play(gs, "c23907"); finish(gs)
			var returned: Dictionary = p.deck.filter(func(i): return str(i.instanceId) == physical)[0]
			p.deck.erase(returned); p.hand.append(returned); put_deck(gs, ["c24203"])
			var h: int = p.hand.find_custom(func(i): return str(i.instanceId) == physical)
			check(gs.play_card(0, h) and gs.pending_choice.get("type") == "native-link", "persistent lifesteal form actually returns and links a second effect")
			check(gs.resolve_divination_choice(0, physical) and gs.play_card(0, h), "same physical form really acquires additional pierce")
			check(gs.VerifiedRules.Combat.has(p.units[0], "lifesteal") and gs.VerifiedRules.Combat.has(p.units[0], "pierce"), "actual installed floating form carries both persisted keywords")
			put_deck(gs, ["c23901"])
		p.avatarHp = 20; foe.units[1].front = 1; foe.units[1].hp = 1; foe.units[1].shield = 0; foe.units[1].barrier = true
		var unit_hp := int(foe.units[1].hp); var avatar_hp := int(foe.avatarHp); var own_hp := int(p.avatarHp)
		if persistent_form: play(gs, "c24201", foe.units[1].uid)
		else: linked_use(gs, "c24201", "c24203", "c24201", foe.units[1].uid)
		var avatar_damage := avatar_hp - int(foe.avatarHp); var healed := int(p.avatarHp) - own_hp
		print("MIRROR_BARRIER_LIFESTEAL form=%s avatar_damage=%d healed=%d unit_loss=%d" % [persistent_form, avatar_damage, healed, unit_hp - int(foe.units[1].hp)])
		check(foe.units[1].hp == unit_hp and not foe.units[1].barrier, "actual spell consumes barrier and does not damage the protected unit")
		check(healed == avatar_damage, "barrier overflow heals actual avatar damage once, form=" + str(persistent_form) + " actual=" + str(avatar_damage) + " healed=" + str(healed))

func forced_combat() -> void:
	for same_side in [false, true]:
		var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1); foe.units[1].front = 1
		var victim := 1 if same_side else 0; var idx := 2
		gs._grow_unit(foe.units[1], 0, 20); gs._grow_unit(gs.player(victim).units[idx], 0, 20)
		var a_hp := int(foe.units[1].hp); var d_hp := int(gs.player(victim).units[idx].hp); var a_power := int(foe.units[1].attack); var d_power := int(gs.player(victim).units[idx].attack); var fire := int(foe.energy)
		play(gs, "c24405", gs.player(victim).units[idx].uid)
		check(gs.player(victim).units[idx].hp == d_hp - a_power and foe.units[1].hp == a_hp - d_power, "command preserves actual attack and counter for same-side=" + str(same_side))
		check(foe.energy == fire and not foe.attackUsed and p.energy == 39, "commanded attack neither pays enemy fire nor consumes their normal attack allowance")
		check(p.avatarHp == 30 and foe.avatarHp == 30, "command without pierce creates no direct avatar damage")
	var gs := game(); var foe: Dictionary = gs.player(1); foe.units[1].front = 1; foe.units[1].keywords = ["first-strike"]; foe.units[2].hp = 2
	var before := int(foe.units[1].hp); play(gs, "c24405", foe.units[2].uid)
	check(foe.units[2].hp == 0 and foe.units[1].hp == before, "same-side first strike kills before counter without posthumous damage")
	gs = game(); foe = gs.player(1); foe.units[1].front = 1; foe.units[1].keywords = ["pierce"]; foe.units[2].hp = 1; var power := int(foe.units[1].attack)
	play(gs, "c24405", foe.units[2].uid)
	check(foe.units[2].hp == 0 and foe.avatarHp == 30 - (power - 1) and gs.player(0).avatarHp == 30, "same-side pierce overflow hits the real victim's avatar")
	gs = game(); var p: Dictionary = gs.player(0); foe = gs.player(1); play(gs, "c24406"); foe.units[1].front = 1; gs._grow_unit(foe.units[1], 0, 20)
	var hp := int(foe.units[1].hp); power = int(foe.units[1].attack); var fire := int(p.energy)
	check(gs.basic_attack(0, 1), "puppeteer actual normal attack starts")
	check(foe.avatarHp == 30 - power and foe.units[1].hp == hp - 3 and p.units[1].hp == 6 - power, "puppeteer orders enemy front to its avatar then resumes original real combat")
	check(p.energy == fire - 1 and p.attackUsed and foe.energy == 40 and not foe.attackUsed, "puppeteer preserves actual own and enemy attack resources")

func commanded_defense_cross() -> void:
	for same_side in [false, true]:
		var gs := game(["yunwaijing", "song", "linghaidie", "taohuayao"], ["yaodaoji", "shuweng", "linghaidie", "baizangzhu"])
		var victim := 1 if same_side else 0; var defending: Dictionary = gs.player(victim); var foe: Dictionary = gs.player(1)
		gs.current_player = victim; play(gs, "c28702", defending.units[2].uid, victim); finish(gs, victim); gs.current_player = 0
		gs._grow_unit(defending.units[2], 0, 20); gs._grow_unit(foe.units[0], 0, 20); foe.units[0].front = 1
		var hp := int(defending.units[2].hp); var power := int(foe.units[0].attack)
		for seed in 12:
			if ((seed * 1664525 + 1013904223) & 0xffffffff) % 3 == 2: gs.rng_state = seed; break
		play(gs, "c24405", defending.units[2].uid)
		check(gs.VerifiedRules.SeaButterfly.marked(defending.units[2]) == same_side and events(gs, "sea-spirit-triggered").size() == (0 if same_side else 1), "command consumes defensive sea spirit only for an actual enemy attacker: " + str(same_side))
		check(defending.units[2].hp == hp - (power if same_side else maxi(0, power - 2)), "sea spirit penalty applies to actual opposing strike, not friendly command")
		if not same_side: check(events(gs, "sea-spirit-triggered")[0].target == foe.units[0].uid, "defensive sea spirit addresses actual forced attacker")
	for role_id in ["yifanmumian", "rurineque"]:
		for same_side in [false, true]:
			var gs := game(["yunwaijing", "song", role_id, "taohuayao"], ["yaodaoji", "shuweng", role_id, "baizangzhu"])
			var victim := 1 if same_side else 0; var defending: Dictionary = gs.player(victim); var foe: Dictionary = gs.player(1)
			gs.current_player = victim; play(gs, "c26103" if role_id == "yifanmumian" else "c25704", null, victim); gs.current_player = 0
			defending.night = 5; foe.units[0].front = 1; gs._grow_unit(foe.units[0], 0, 20); gs._grow_unit(defending.units[2], 0, 20)
			var hp := int(defending.units[2].hp); var power := int(foe.units[0].attack)
			play(gs, "c24405", defending.units[2].uid)
			if role_id == "yifanmumian":
				check((int(foe.units[0].frozen) > 0) == not same_side, "fear realm stuns only an enemy attacking its actual cotton body: " + str(same_side))
				check((int(defending.realms[0].get("cottonUsedTurn", -1)) == gs.turn_counter) == not same_side and defending.night == 5, "friendly command does not spend fear realm's once-per-turn trigger or night check")
				check(defending.units[2].hp == hp - power, "fear defense continuation retains actual commanded defender")
			else:
				check(events(gs, "sparrow-court").size() == (0 if same_side else 1) and foe.units[0].attack == power - (0 if same_side else 2), "sparrow court penalizes an actual enemy, never the same-side commanded attacker: " + str(same_side))
				check(defending.units[2].hp == hp - maxi(0, power - (0 if same_side else 2)), "sparrow defense changes only the true incoming combat")
	for same_side in [false, true]:
		var gs := game(["yunwaijing", "song", "hainren", "taohuayao"], ["hainren", "shuweng", "yaodaoji", "baizangzhu"])
		var victim := 1 if same_side else 0; var target: Dictionary = gs.player(victim).units[2]; var foe: Dictionary = gs.player(1)
		# Poison correctly prevents later health growth; establish a surviving
		# target before poisoning rather than relying on an illegal poison heal.
		gs._grow_unit(target, 0, 20); gs._grow_unit(foe.units[0], 0, 20); foe.units[0].front = 1
		var poison_owner := 1 - victim
		gs.current_player = poison_owner; play(gs, "c28602", target.uid, poison_owner); gs.current_player = 0
		var hp := int(foe.units[0].hp); var counter := int(target.attack)
		play(gs, "c24405", target.uid)
		check(target.get("toxicPoisoned", false) and events(gs, "ninja-immunity").size() == (0 if same_side else 1), "ninja base checks actual poisoned enemy, excluding poisoned same-side command target: " + str(same_side))
		check(foe.units[0].hp == hp - (counter if same_side else 0), "ninja takes friendly counter damage and prevents actual poisoned enemy counter")
	var gs := game(["yunwaijing", "song", "shuweng", "taohuayao"], ["yaodaoji", "banruo", "huajing", "baizangzhu"])
	var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	# A real summoned front occupies index4; its same-side defender still uses
	# the actual side's deck and response continuation, without mirroring indices.
	gs.current_player = 1; play(gs, "c27805", null, 1); gs.current_player = 0
	check(foe.units.size() > 4 and foe.units[4].get("whaleGuardian", false) and foe.units[4].front == 1, "real guardian command uses expanded side's index4 attacker")
	gs._grow_unit(foe.units[1], 0, 20); var mask_hp := int(foe.units[1].hp); var guardian_hp := int(foe.units[4].hp); var counter := int(foe.units[1].attack)
	put_deck(gs, ["c21501"], 1); var energy := int(foe.energy); var own_hp: Array = p.units.map(func(u): return int(u.hp))
	play(gs, "c24405", foe.units[1].uid)
	check(foe.units[1].hp == mask_hp and foe.units[4].hp == maxi(0, guardian_hp - counter - 1), "same-side mask top ghost protects actual defender and strengthens its counter once")
	check(foe.deck.is_empty() and foe.energy == energy and events(gs, "automatic-card").any(func(e): return e.player == 1 and e.card.id == "c21501"), "same-side mask defense uses actual owner deck without enemy payment")
	check(range(4).all(func(i): return p.units[i].hp == own_hp[i]) and gs.resolution_stack.is_empty() and gs.pending_choice.is_empty(), "expanded-side mask continuation never damages matching opposite indices or stalls")
	for one_hp in [false, true]:
		gs = game(["yunwaijing", "song", "shuweng", "taohuayao"], ["xuzuozhinan", "yaodaoji", "shuweng", "baizangzhu"]); foe = gs.player(1)
		foe.units[0].front = 1; foe.units[1].hp = 1 if one_hp else 4; gs.player(0).units[1].hp = 4 if one_hp else 1
		var power := int(foe.units[0].attack)
		play(gs, "c24405", foe.units[1].uid)
		var growth: Dictionary = events(gs, "susanoo-attack-growth")[0]
		check(growth.target == foe.units[1].uid and growth.pierce == one_hp and foe.units[0].attack == power + 1, "susanoo forced attack growth and one-health check read actual same-side target: " + str(one_hp))
		check(foe.avatarHp == 30 - (power if one_hp else 0) and gs.player(0).avatarHp == 30, "same-side susanoo pierce allocates only actual victim avatar overflow")
	gs = game(["yunwaijing", "song", "shuweng", "taohuayao"], ["xuzuozhinan", "yaodaoji", "shuweng", "baizangzhu"]); foe = gs.player(1)
	for unit in gs.player(0).units: gs._grow_unit(unit, 0, 20)
	gs.current_player = 1; play(gs, "c28108", null, 1); gs.current_player = 0
	foe.units[0].hp = 2; foe.units[1].hp = 2; var duel_events := events(gs, "susanoo-duel-unyielding").size()
	play(gs, "c24405", foe.units[1].uid)
	check(foe.units[0].hp == 1 and foe.units[1].hp == 1 and events(gs, "susanoo-duel-unyielding").size() == duel_events + 1, "same-side susanoo duel grants genuine unyielding to both actual combatants")
	check(not foe.units[0].has("susanooCombatUnyielding") and not foe.units[1].has("susanooCombatUnyielding"), "same-side duel floors expire after this combat")

func divination_realms_and_dream() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	put_deck(gs, ["c24405", "c24406"]); put_deck(gs, ["c10301", "c10302"], 1)
	play(gs, "c24403")
	check(gs.pending_choice.get("type") == "native-divination" and gs.pending_choice.get("playerIndex") == 0 and gs.pending_choice.get("zoneOwner") == 0, "twelve sections first lets player arrange own real deck")
	var iid := str(gs.pending_choice.instanceIds[0])
	check(gs.resolve_divination_choice(0, iid) and gs.resolve_divination_choice(0, gs.VerifiedRules.Divination.BOTTOM), "player bottoms actual own top")
	check(gs.pending_choice.get("type") == "native-divination" and gs.pending_choice.get("playerIndex") == 0 and gs.pending_choice.get("zoneOwner") == 1, "same player then arranges opponent's deck")
	iid = str(gs.pending_choice.instanceIds[0])
	check(gs.resolve_divination_choice(0, iid) and gs.resolve_divination_choice(0, gs.VerifiedRules.Divination.BOTTOM), "player may bottom actual enemy top")
	check(gs.pending_choice.is_empty() and p.hand.is_empty() and p.deck.size() == 2 and foe.deck.size() == 2, "two real divinations finish without invented draw")
	gs = game(); p = gs.player(0); foe = gs.player(1); put_deck(gs, ["c11901", "c11902"]); put_deck(gs, ["c10301", "c10302"], 1)
	play(gs, "c24407")
	check(p.realms.size() == 1 and p.realms[0].hp == 5 and foe.units.filter(func(u): return u.frozen > 0).size() == 1, "night realm enters at printed5 durability and stuns one actual enemy")
	var stunned: Dictionary = foe.units.filter(func(u): return u.frozen > 0)[0]; var power := int(stunned.attack)
	gs._knockout_unit(p.units[1], 1, 0); gs._resolve_resolution_stack()
	check(gs.end_turn(0), "real opposing turn starts under installed night realm")
	check(foe.avatarHp == 30 - power and p.realms.size() == 1, "night realm persists with source knocked out and stunned enemy damages its own avatar")
	gs = game(); p = gs.player(0); foe = gs.player(1); play(gs, "c24408")
	for target in foe.units: gs._grow_unit(target, 0, 20)
	var healths: Array = foe.units.map(func(u): return u.hp)
	linked_use(gs, "c24201", "c24201", "c24201", foe.units[0].uid)
	check(foe.units[0].hp == healths[0] - 4 and range(1, 4).all(func(i): return foe.units[i].hp == healths[i] - 1), "dream observes actual ally link and damages every enemy shikigami once")
	check(foe.avatarHp == 30, "dream link observer is not avatar damage")
	gs = game(); p = gs.player(0); play(gs, "c24206"); play(gs, "c24402")
	check(p.units[0].awakened and p.units[0].attack == 3 and p.units[0].maxHp == 6 and p.units[1].awakened and p.units[1].attack == 4 and p.units[1].maxHp == 5, "both real awakenings install printed+1/+1 and correct replacement abilities")

func ai_rules() -> void:
	for role_id in [242, 244]:
		for n in range(1, 9):
			var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
			put_deck(gs, ["c11901", "c11902", "c11903"]); put_deck(gs, ["c10301", "c10302", "c10303"], 1)
			foe.units[0].front = 1
			for u in foe.units: gs._grow_unit(u, 0, 20)
			var id := "c%d%02d" % [role_id, n]; give(gs, id)
			var action: Dictionary = AI._best_card(gs, 0)
			check(action.get("ok", false) and gs.can_play_card(0, int(action.get("hand", -1)), action.get("target")).ok, "AI selects legal actual card " + id)
			if action.get("ok", false): check(gs.play_card(0, int(action.hand), action.target), "AI executes actual card " + id)
			finish(gs)
			check(gs.pending_choice.is_empty() and gs.resolution_stack.is_empty(), "AI completes all actual card choices " + id)

func ui_rules() -> void:
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["yunwaijing", "song", "shuweng", "taohuayao"], ["bingyong", "yaodaoji", "fenghuanghuo", "baizangzhu"], 242244)
		b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.deck.clear(); side.energy = 40; side.levelUpUsed = true
			for unit in side.units: unit.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
		put_deck(gs, ["c24201"]); hand(b, ["c24202"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type") == "native-link" and faces(b._choice_layer).size() == 2, "native mirror link presents two real choices")
		var tile := choice_face(b, "c24202")
		check(tile != null and tile.data.value.attack == 4 and "lifesteal" in tile.data.keywords and str(tile.data.get("currentCardStats", "")).contains("4/6"), "native linked form displays actual enhanced body and keyword badge")
		await capture("%d-01-mirror-link" % physical.x)
		if tile != null: await click(tile)
		await settled(b)
		check(p.units[0].attack == 4 and p.units[0].maxHp == 6 and p.hand.is_empty(), "native selected form really installs after choice")
		p.units[1].awakened = true; put_deck(gs, ["c24201", first_card("shuweng"), first_card("taohuayao")]); hand(b, ["c24403"]); await settled(b)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.options.size() == 4 and faces(b._choice_layer).size() == 4, "native awakened song displays all three allies plus original")
		await capture("%d-02-song-four-choice" % physical.x)
		tile = choice_face(b, "c24201")
		if tile != null: await click(tile)
		await settled(b)
		check(b._pending_target_card >= 0 and b._unit_widget(str(foe.units[0].uid)).selected, "native selected ally spell waits for actual target")
		await click(b._unit_widget(str(foe.units[0].uid))); await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.is_empty() and p.deck.size() == 3, "native multi-link returns all unchosen cards and completes selected spell")
		p.units[1].awakened = false; p.deck.clear(); foe.units[0].front = 1; gs._grow_unit(foe.units[1], 0, 20)
		hand(b, ["c24404"]); await settled(b); var receiver_hp := int(foe.units[1].hp); var song_hp := int(p.units[1].hp); var incoming := int(foe.units[0].attack)
		await click(b._hand_row.get_child(0)); await settled(b)
		check(gs.pending_choice.get("type") == "ms-beauty" and choice_face(b, str(foe.units[1].uid)) != null, "native beauty exposes second-stage real enemy receivers")
		await capture("%d-03-beauty-receiver" % physical.x)
		tile = choice_face(b, str(foe.units[1].uid))
		if tile != null: await click(tile)
		await settled(b)
		check(p.units[1].hp == song_hp and foe.units[1].hp == receiver_hp - incoming and not p.units[1].has("msBeautyReceiver"), "native receiver selection transfers actual counter damage and clears status")
		foe.units[1].front = 1; foe.units[0].front = 0; gs._grow_unit(foe.units[2], 0, 20); var hp := int(foe.units[2].hp); var attack := int(foe.units[1].attack)
		hand(b, ["c24405"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card >= 0 and b._unit_widget(str(foe.units[2].uid)).selected, "native command allows another enemy as the actual forced target")
		await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
		check(foe.units[2].hp == hp - attack and p.hand.is_empty(), "native command causes real same-side combat")
		await capture("%d-04-command-resolved" % physical.x)
		b.queue_free(); await process_frame; await process_frame
	for role_id in [242, 244]:
		for n in range(1, 9):
			var id := "c%d%02d" % [role_id, n]
			var tile = preload("res://scripts/ui/card_face.gd").new(); tile.data = Content.card_def(id); tile.refresh_art()
			check(tile._original_card != null and tile._original_card.resource_path == "res://assets/official/cards/%s.png" % id, "native original texture " + id)
			tile.free()

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args(); var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	definitions(); link_choices(); permanent_form(); damage_and_combat(); song_targets_and_beauty(); barrier_spell_lifesteal(); forced_combat(); commanded_defense_cross(); divination_realms_and_dream(); ai_rules()
	if not only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("MIRROR_SONG_OK checks=%d failures=%d rules_only=%s" % [checks, failures, only])
	quit(0 if failures == 0 else 1)
