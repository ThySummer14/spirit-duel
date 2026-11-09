extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const BD := preload("res://scripts/bond_dream_rules.gd")
const Divination := preload("res://scripts/native_divination_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BOND_DREAM_FAIL ", detail)

func game(lineup: Array = [], enemy: Array = []) -> GS:
	var gs := GS.create(["jieshen", "shimengmo", "baimugui", "xieji"] if lineup.is_empty() else lineup, ["bingyong", "yaodaoji", "shanfeng", "longyechaji"] if enemy.is_empty() else enemy, 216187)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "bond-dream-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "actual play " + id)

func marked(id: String, iid: String, bonds: int = 0, dreams: int = 0, owner: int = 0) -> Dictionary:
	var inst := {"definitionId":id, "instanceId":iid}
	if bonds > 0: inst.bondMarks = []
	for i in bonds: inst.bondMarks.append({"owner":owner,"sourceUid":""})
	if dreams > 0: inst.nightmareMarks = []
	for i in dreams: inst.nightmareMarks.append({"owner":owner,"sourceUid":""})
	return inst

func marks(gs, owner: int, key: String) -> int:
	var count := 0
	for inst in gs.player(owner).deck: count += inst.get(key, []).size()
	return count

func finish(gs) -> void:
	for i in 80:
		if gs.winner >= 0 or (gs.pending_choice.is_empty() and gs.response_window.is_empty()): return
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs, gs.action_player()), "AI completes actual choice")
		else: gs.pass_response(gs.action_player())
	check(false, "choice continuation terminates")

func bond_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0)
	var definition := Content.card_def("yuanjie")
	check(definition.type == "charm" and definition.nonHandDerivative and not Content.is_spell(definition), "缘结 definition is a deck charm")
	var legacy := give(gs, "yuanjie")
	check(not gs.play_card(0, legacy) and p.energy == 30 and p.hand.size() == 1, "a historical spell instance cannot grant its old draw and armor")
	p.hand.clear()
	check(p.units[0].attack == 1 and p.units[0].maxHp == 5 and p.units[1].attack == 2 and p.units[1].maxHp == 6, "base bodies use source values")
	BD.end_turn(gs, 0)
	check(marks(gs, 0, "bondMarks") == 1 and p.hand.is_empty(), "base ends by enchanting actual deck without synthetic token")
	gs._knockout_unit(p.units[0]); BD.end_turn(gs, 0)
	check(marks(gs, 0, "bondMarks") == 1, "knocked bond master does not enchant")
	gs = game(); p = gs.player(0)
	play(gs, "c21603"); BD.end_turn(gs, 0)
	check(marks(gs, 0, "bondMarks") == 2 and p.hand.is_empty(), "blossom adds a real second deck enchantment without turn draw")
	play(gs, "c21608")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 7 and p.units[0].awakened, "bond awakening exact2/2")
	BD.end_turn(gs, 0)
	check(marks(gs, 0, "bondMarks") == 5, "awakened end2 plus blossom1")
	gs = game(); p = gs.player(0)
	p.avatarHp = 20; p.units[3].hp = 1
	p.deck = [marked("c21005", "bond-heal", 1)]
	gs._draw(0, 1)
	check(p.avatarHp == 22 and p.units[3].hp == 3 and p.hand[0].instanceId == "bond-heal", "draw heals actual avatar and card's corresponding unit")
	gs = game(["jieshen", "xuenv", "xuetongzi", "xieji"]); p = gs.player(0)
	p.avatarHp = 20; p.units[1].hp = 1; p.units[2].hp = 1; p.units[3].hp = 1
	p.deck = [marked("c106112", "bond-coop", 1)]
	gs._draw(0, 1)
	check(p.avatarHp == 22 and p.units[1].hp == 3 and p.units[2].hp == 3 and p.units[3].hp == 1, "协战 draw heals each owner and the avatar once")
	check(p.hand.size() == 1 and p.hand[0].instanceId == "bond-coop" and gs.hand_card_def(0, 0).text.contains("抽到结附此灵咒"), "缘结 is visible on the single drawn cooperation instance")
	gs = game(); p = gs.player(0)
	play(gs, "c21608"); p.avatarHp = 20; p.units[3].hp = 1
	p.deck = [marked("c21005", "bond-double", 1)]
	gs._draw(0, 1)
	check(p.avatarHp == 24 and p.units[3].hp == 5, "awakening doubles bond healing")
	gs = game(); p = gs.player(0)
	play(gs, "c21602")
	check(p.units[0].attack == 2 and p.units[0].maxHp == 5, "goddess sets2/5 without additive legacy growth")
	p.deck = [marked("c21005", "goddess-third", 1),marked("c21005", "goddess-second", 1),marked("c21005", "goddess-first", 1)]
	gs._draw(0, 1)
	check(p.hand.size() == 2 and p.deck.size() == 1, "goddess draws once per turn and nested bond cannot loop")
	gs._draw(0, 1)
	check(p.hand.size() == 3 and gs.winner < 0, "second bond same turn cannot request extra empty draw")
	gs = game(); p = gs.player(0)
	play(gs, "c21604"); var energy: int = p.energy
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5 and energy == 29, "merchant4/5 grants no invented immediate energy")
	p.deck = [marked("c21005", "merchant-later", 1),marked("c21005", "merchant-now", 1)]
	gs._draw(0, 2)
	check(p.energy == energy + 1, "merchant grants exactly one fire for multiple bonds same turn")
	gs = game(); p = gs.player(0)
	play(gs, "c21608"); play(gs, "c21604"); energy = p.energy
	p.deck = [marked("c21005", "merchant-awake", 1)]
	gs._draw(0, 1)
	check(p.energy == energy + 2, "awakening doubles once-per-turn merchant reward")
	gs = game(); p = gs.player(0)
	play(gs, "c21605")
	check(gs.pending_choice.is_empty() and p.hand.is_empty() and p.units[0].attack == 3 and p.units[0].maxHp == 5, "fate does not invent entry divination or draw")
	gs._knockout_unit(p.units[3]); p.deck = [marked("c21005", "revive-crab", 1)]
	gs._draw(0, 1)
	check(p.units[3].hp == p.units[3].maxHp and p.units[3].attack == 3 and p.units[3].knockout == 0, "fate revives corresponding real unit then grows1/1")
	p.deck.append(marked("c21005", "turn-fate", 1)); p.units[3].front = 1
	gs._begin_turn(0)
	check(gs.pending_choice.get("type") == "native-divination" and p.deck.size() == 1 and p.units[3].front == 1, "turn-start fate divines before retreat and normal draw")
	finish(gs)
	check(p.deck.is_empty() and p.units[3].front == 0, "fate choice resumes retreat then actual draw")
	gs = game(); p = gs.player(0); p.avatarHp = 20
	play(gs, "c21601")
	check(p.hand.size() == 1 and not p.hand[0].get("bondMarks", []).is_empty() and p.avatarHp == 22 and marks(gs, 0, "bondMarks") == 2, "traveler attaches3 then truly draws an enchanted instance")
	gs = game(); p = gs.player(0)
	for id in ["c21001","c21002","c21003","c21004"]: give(gs, id)
	var before: int = p.deck.size(); var ids: Array = p.hand.map(func(i): return str(i.instanceId))
	play(gs, "c21607")
	check(p.hand.size() == 4 and p.deck.size() == before and gs.kw_usage(0, "instant").used and p.energy == 30, "together returns3 originals and draws3 with shared instant")
	var returned: Array = p.deck.filter(func(i): return str(i.instanceId) in ids and not i.get("bondMarks", []).is_empty()) + p.hand.filter(func(i): return str(i.instanceId) in ids and not i.get("bondMarks", []).is_empty())
	check(returned.size() == 3, "together preserves3 original identities and enchantments")

func moon_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	p.deck = [marked("c21005", "moon-before", 1)]
	gs._draw(0, 1); p.hand.clear(); play(gs, "c21606")
	check(p.units[3].swift and gs.VerifiedRules.Combat.has(p.units[3], "pursuit") and not p.units[1].get("swift",false), "moon grants actual pursuit/swift only to bond-affected unit")
	check(p.units[3].attack == 2 and p.units[3].maxHp == 6, "moon鼓舞 is not a permanent stat buff")
	foe.units[0].front = 1; foe.units[1].formRules = {"combatKeywords":["veil"]}
	var targets: Array = gs.basic_attack_targets(0, 3)
	check(targets.size() == 3 and not targets.has(foe.units[1].uid) and not targets.has("avatar-1"), "pursuit lists reserve and front but excludes veil and avatar")
	var energy: int = p.energy
	check(not gs.basic_attack(0, 3) and not gs.basic_attack(0, 3, "avatar-1") and p.energy == energy, "missing or illegal pursuit selection rejected before paying")
	var health: int = foe.units[2].hp
	check(gs.basic_attack(0, 3, foe.units[2].uid) and int(foe.units[2].hp) < health and p.energy == energy, "swift attack truly hits selected reserve without fire")
	check(p.units[3].shield == 0 and p.units[3].hp == 6 and not p.units[3].swift, "encourage armor applied to actual basic attack and swift consumed")
	BD.expire_turn(gs)
	check(not gs.VerifiedRules.Combat.has(p.units[3], "pursuit") and not p.units[3].swift, "moon grants expire at turn boundary")
	gs = game(); p = gs.player(0); play(gs, "c21606")
	p.deck = [marked("c21005", "moon-after", 1)]
	gs._draw(0, 1)
	check(p.units[3].swift and gs.hand_card_def(0, give(gs, "c21002")).combatOption.pursuit, "later bond also grants pursuit and selected combat-card UI")
	for u in gs.player(1).units: gs._knockout_unit(u)
	check(not gs.can_basic_attack(0, 3).ok, "pursuit basic attack cannot bypass all missing units to hit avatar")
	check(gs.valid_targets(0, gs.hand_card_def(0, p.hand.size()-1)).has("avatar-1"), "pursuit combat card can hit avatar with no enemy front")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	p.units[0].bondMoonPursuit = true; foe.units[0].shield = 99; foe.units[0].front = 1; foe.units[2].hp = 1
	for i in [1,2,3]: p.units[i].frozen = 1
	var attack: Dictionary = AI._best_attack(gs, 0)
	check(attack.ok and attack.target == foe.units[2].uid and gs.basic_attack(0, attack.unit, attack.target), "AI selects legal vulnerable reserve for pursuit")

func dream_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	check(gs.basic_attack(0, 1), "base dream attacks actual avatar")
	check(BD.nightmare_total(gs, 1) == 1, "base avatar combat attaches1")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.avatarArmor = 99; gs.basic_attack(0, 1)
	check(BD.nightmare_total(gs, 1) == 0, "fully armored avatar hit does not attach")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c18701")
	check(BD.nightmare_cards(gs, 1).size() == 3 and foe.units[0].attack == foe.units[0].baseAttack, "sleep attaches3 without invented global debuff")
	play(gs, "c18704")
	check(p.units[1].attack == 3 and p.units[1].maxHp == 7 and gs.VerifiedRules.Combat.has(p.units[1], "pierce"), "dream awakens1/1 and actual pierce")
	foe.units[0].front = 1; foe.units[0].hp = 1
	var count := BD.nightmare_total(gs, 1)
	gs.basic_attack(0, 1)
	check(BD.nightmare_total(gs, 1) == count + 3 and foe.avatarHp == 28, "actual pierce overflow attaches awakened3")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c18702"); var deck_size: int = p.deck.size()
	gs._trigger_realms(0)
	check(p.deck.size() == deck_size, "whisper has no fake owner-start draw")
	BD.end_turn(gs, 0)
	check(BD.nightmare_total(gs, 1) == 1, "whisper attaches1 at owner end")
	gs.current_player = 1; foe.deck = [marked("c10101","dream-debuff",0,1)]
	var attack: int = foe.units[1].attack
	gs._draw(1, 1)
	check(foe.avatarHp == 27 and foe.units[1].attack == attack - 2 and foe.units[0].attack == foe.units[0].baseAttack, "dream damages avatar3 and whisper reduces only corresponding unit")
	BD.expire_turn(gs)
	check(foe.units[1].attack == attack, "whisper power penalty expires at exact turn end")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c18705"); check(p.units[1].attack == 4 and p.units[1].maxHp == 7, "dream-emerges sets4/7")
	play(gs, "c21606")
	check(BD.nightmare_total(gs, 1) == 1, "ally spell really triggers dream form regardless of source unit")
	play(gs, "c18706")
	check(BD.nightmare_total(gs, 1) == 1, "realm use is not a spell")
	gs.current_player = 1; foe.deck = [marked("c10101","dream-kill",0,1)]; foe.units[1].barrier = true; foe.units[1].shield = 20
	gs._draw(1, 1)
	check(foe.units[1].hp == 0 and foe.avatarHp == 27, "eternal sleep destroys corresponding unit through barrier and armor")
	gs = game(); p = gs.player(0); p.avatarHp = 15
	play(gs, "c18701"); play(gs, "c18707")
	check(p.avatarHp == 21 and BD.nightmare_total(gs, 1) == 6, "feast heals actual total after attaching3")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.deck = [marked("c10101", "body-one",0,2),marked("c17502", "body-two",0,1),marked("c10101", "body-three",0,1),marked("c17502", "body-four",0,1)]
	var h := give(gs, "c18708"); var view: Dictionary = gs.hand_card_def(0,h)
	check(view.value.attack == 4 and view.currentCardStats == "当前面板 4/4", "SSR preview counts4 real cards rather than5 layers")
	check(gs.play_card(0,h) and p.units[1].attack == 4 and p.units[1].maxHp == 4 and p.energy == 29, "SSR installs exact4/4 at1 fire")
	var result: Dictionary = gs._damage_unit(0,1,9,1,0)
	check(result.damage == 0 and foe.deck.size() == 1 and p.units[1].hp == 1 and p.units[1].attack == 1, "SSR replaces9 damage by removing max3 actual deck cards")
	gs._damage_unit(0,1,1,1,0)
	check(foe.deck.is_empty() and p.units[1].hp == 0 and p.units[1].formRules.is_empty(), "last dream removed causes real zero-health knockout and clears form")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.deck = [marked("c10101","body-shield",0,1),marked("c17502","body-second",0,1)]
	play(gs,"c18708"); p.units[1].shield = 3
	gs._damage_unit(0,1,2,1,0)
	check(foe.deck.size() == 2 and p.units[1].shield == 1 and p.units[1].hp == 2, "armor absorbs before SSR replacement without discarding dream cards")
	gs.current_player = 1; gs._draw(1,1)
	check(p.units[1].attack == 1 and p.units[1].maxHp == 1, "enemy actual draw immediately updates SSR dynamic body")

func ordering_rules() -> void:
	var gs := game([], ["jieshen","shimengmo","baimugui","xieji"]); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	play(gs,"c21605"); gs.current_player = 1; play(gs,"c18706",null,1); gs.current_player = 0
	gs._knockout_unit(p.units[3]); p.avatarHp = 20
	var inst := marked("c21005","all-three",1,1,1); inst.bondMarks[0].owner = 0; inst.eyeCurses = 1
	p.deck = [marked("c21002","second-card"), inst]
	gs._draw(0,2)
	check(p.avatarHp == 19 and p.units[3].hp == 0 and p.units[3].attackBonus == 1 and gs.pending_choice.get("type") == "eye-curse", "bond heals/revives before dream damages/destroys before curse choice")
	check(p.deck.size() == 1 and p.hand.size() == 1, "batch draw pauses after first charmed card before second draw")
	check(gs.resolve_divination_choice(0,"eye-curse-life") and p.avatarHp == 8 and p.hand.size() == 2 and p.deck.is_empty(), "curse completion resumes remaining actual draw")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	var h := give(gs,"c18703")
	check(not gs._kw(gs.hand_card_def(0,h),"instant") and gs.hand_card_def(0,h).combatOption.get("shield",0) == 0, "shock is neither instant nor armored before dream draw")
	gs.current_player = 1; foe.deck = [marked("c10101","shock-trigger",0,1)]
	gs._draw(1,1); gs._resolve_resolution_stack(); finish(gs)
	check(p.hand.is_empty() and p.units[1].front == 1 and p.units[1].shield == 3 and foe.avatarHp == 23 and p.energy == 30, "dream draw really auto-uses enhanced shock and attacks after3 damage")
	check(BD.nightmare_total(gs,1) == 0, "new attack with exhausted deck does not invent dream instances")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	gs.current_player = 1; p.energy = 0; gs.kw_usage(0,"instant").used = true; give(gs,"c18703")
	foe.deck = [marked("c10101","shock-no-fire",0,1)]; gs._draw(1,1); gs._resolve_resolution_stack()
	check(p.hand.size() == 1 and p.units[1].front == 0, "automatic shock respects used instant and unavailable fire")
	gs = game(); p = gs.player(0)
	for i in 12: give(gs,"c21002")
	p.avatarHp = 20; p.deck = [marked("c21005","burned-bond",1)]
	gs._draw(0,1)
	check(p.hand.size() == 12 and p.avatarHp == 22, "burned actual draw still resolves bond")
	gs = game(); p = gs.player(0)
	var stamp := JSON.stringify(gs.snapshot())
	var card := marked("c21002","query",1,1)
	BD.describe_card(gs,0,card,Content.card_def("c21002"))
	check(JSON.stringify(gs.snapshot()) == stamp, "read-only spirit card preview does not mutate state")

func fetch_rules() -> void:
	var gs := game(["taohuayao","shuweng","qingxingdeng","shimengmo"]); var p: Dictionary = gs.player(0)
	var inst := marked("c11901","search-peach",1,1,1); inst.eyeCurses = 1
	p.deck = [inst]; p.avatarHp = 20
	gs.VerifiedRules.Peach.search_deck(gs,0,p.units[1])
	check(p.hand.size() == 1 and p.hand[0].instanceId == "search-peach" and not p.hand[0].has("bondMarks") and not p.hand[0].has("nightmareMarks") and not p.hand[0].has("eyeCurses") and p.avatarHp == 20 and gs.pending_choice.is_empty(), "flower fetch preserves identity while clearing all3 charms without triggering")
	gs = game(["taohuayao","shuweng","qingxingdeng","shimengmo"]); p = gs.player(0)
	play(gs,"c11904"); inst = marked("c11901","mind-charms",1,1,1); inst.eyeCurses = 1
	p.deck = [inst]; p.avatarHp = 20
	check(gs.VerifiedRules.BookJue.turn_draw(gs,0) and gs.pending_choice.type == "book-mind", "mind uses actual inspect/obtain choice")
	check(gs.resolve_divination_choice(0,"mind-charms") and p.hand[0].instanceId == "mind-charms" and not p.hand[0].has("bondMarks") and not p.hand[0].has("nightmareMarks") and not p.hand[0].has("eyeCurses") and p.avatarHp == 20, "mind obtain clears3 charms without treating it as actual draw")
	gs = game(["taohuayao","shuweng","qingxingdeng","shimengmo"]); p = gs.player(0)
	inst = marked("c11901","lantern-charms",1,1,1); inst.eyeCurses = 1; p.deck = [inst]; p.avatarHp = 20
	gs.VerifiedRules.Light.start_choice(gs,0,1)
	check(gs.resolve_divination_choice(0,"lantern-charms") and p.hand[0].instanceId == "lantern-charms" and not p.hand[0].has("bondMarks") and not p.hand[0].has("nightmareMarks") and not p.hand[0].has("eyeCurses") and p.avatarHp == 20, "lantern obtain clears3 charms and does not open curse")
	gs = game(["taohuayao","shuweng","qingxingdeng","shimengmo"]); p = gs.player(0)
	inst = marked("c11901","dispatch-charms",1,1,1); inst.eyeCurses = 1; p.deck = [inst]; p.avatarHp = 20
	give(gs,"c11901"); var original := str(p.hand[0].instanceId)
	play(gs,"c11907")
	check(gs.resolve_divination_choice(0,original), "dispatch exchanges an actual held card")
	check(p.hand[0].instanceId == "dispatch-charms" and not p.hand[0].has("bondMarks") and not p.hand[0].has("nightmareMarks") and not p.hand[0].has("eyeCurses") and p.avatarHp == 20, "dispatch replacement also removes all3 charms without drawing")

func continuation_rules() -> void:
	var gs := game(["mengpo","shuweng","shimengmo","jieshen"]); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	var cursed := marked("c11901","mengpo-curse"); cursed.eyeCurses = 1
	p.deck = [marked("c11902","mengpo-next"),cursed]
	play(gs,"c17102")
	check(gs.pending_choice.get("type") == "eye-curse" and p.deck.size() == 1 and p.hand.size() == 1, "draw2-discard suspends at first curse without replacing its choice")
	check(gs.resolve_divination_choice(0,"eye-curse-life") and gs.pending_choice.get("type") == "mengpo-discard" and p.hand.size() == 2 and p.deck.is_empty(), "curse resumes remaining draw before original discard choice")
	check(gs.resolve_divination_choice(0,"mengpo-next") and p.hand.size() == 1 and gs.pending_choice.is_empty(), "actual original discard completes after spirit resolution")
	gs = game(["mengpo","shuweng","shimengmo","jieshen"]); p = gs.player(0); foe = gs.player(1)
	cursed = marked("c11901","ink-curse"); cursed.eyeCurses = 1; p.deck = [cursed]
	var hp: int = foe.units[0].hp
	give(gs,"c11901"); play(gs,"c11903",foe.units[0].uid)
	check(gs.pending_choice.get("type") == "eye-curse" and foe.units[0].hp == hp, "ink damage waits until drawn-card curse finishes")
	check(gs.resolve_divination_choice(0,"eye-curse-hand") and p.hand.size() == 1 and foe.units[0].hp == hp, "ink computes damage from actual hand after curse discard rather than stale size")
	gs = game(); p = gs.player(0)
	cursed = marked("c21005","end-curse"); cursed.eyeCurses = 1; p.deck = [cursed]
	gs.resolution_stack.append({"kind":"charm-extra-draw","playerIndex":0,"count":1})
	check(gs.end_turn(0) and gs.current_player == 0 and gs.pending_choice.get("type") == "eye-curse", "end-turn continuation waits for actual spirit choice before changing turn")
	check(gs.resolve_divination_choice(0,"eye-curse-life") and gs.current_player == 1 and gs.turn_counter == 2, "finished end-turn choice changes turn exactly once")
	gs = game(); p = gs.player(0); p.avatarHp = 2; gs._knockout_unit(p.units[0])
	p.deck = [marked("c21005","end-lethal-dream",0,1,1)]
	gs.resolution_stack.append({"kind":"charm-extra-draw","playerIndex":0,"count":1})
	check(gs.end_turn(0) and gs.winner == 1 and gs.current_player == 0 and gs.turn_counter == 1, "lethal end-turn charm finishes game without advancing a dead match")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c21608"); play(gs,"c21602")
	p.deck = [marked("c21002","awake-extra2"),marked("c21003","awake-extra1"),marked("c21005","awake-bond",1)]
	gs._draw(0,1)
	check(p.hand.size() == 3 and p.deck.is_empty() and gs.winner < 0, "awakened goddess doubles its actual once-per-turn extra draw")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18702"); gs._knockout_unit(p.units[1]); foe.deck = [marked("c10101","realm-source-dead",0,1)]
	gs.current_player = 1; gs._draw(1,1)
	check(foe.units[1].attack == foe.units[1].baseAttack - 2, "installed whisper keeps triggering with its source knocked")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs,"c18702"); p.realms[0].hp = 0; foe.deck = [marked("c10101","realm-exhausted",0,1)]
	gs.current_player = 1; gs._draw(1,1)
	check(foe.units[1].attack == foe.units[1].baseAttack, "zero-durability whisper cannot debuff")
	gs = game(); p = gs.player(0)
	var index := give(gs,"c18708")
	check(int(BD.score_card(gs,0,gs.hand_card_def(0,index))) < 0, "AI declines zero-dream SSR rather than intentionally killing its source")

func ui_rules() -> void:
	root.size = Vector2i(1600,740)
	if not out.is_empty(): DisplayServer.window_set_size(root.size)
	var b := Battle.new(); b.setup(["jieshen","shimengmo","baimugui","xieji"],["bingyong","yaodaoji","shanfeng","longyechaji"],216187)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
	root.add_child(b); await create_timer(0.4).timeout
	var gs = b.gs; var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	p.deck = [marked("c21005","ui-moon-bond",1)]
	gs._draw(0,1); hand(b,["c21606"]); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	check(p.units[3].swift and gs.VerifiedRules.Combat.has(p.units[3],"pursuit"), "native mouse uses original moon card and grants pursuit")
	foe.units[0].front = 1; b._last_view = {}; b._refresh(); await settled(b)
	await click(b._unit_widget(str(p.units[3].uid))); await process_frame
	check(b._selected_attacker == 3 and b._unit_widget(str(foe.units[2].uid)).selected and "追猎" in texts(b._cmd_bar), "native attacker selection highlights actual reserve pursuit targets")
	var energy: int = p.energy; var hp: int = foe.units[2].hp
	await capture("01-moon-pursuit-target")
	await click(b._unit_widget(str(foe.units[2].uid))); await settled(b)
	check(foe.units[2].hp < hp and p.energy == energy, "native selected reserve receives actual swift attack")
	hand(b,["c21605"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	p.deck = [marked("c21005","ui-divine-bond",1)]; p.units[3].front = 1
	gs._begin_turn(0); b._last_view = {}; b._refresh(); await settled(b)
	check(gs.pending_choice.get("type") == "native-divination" and p.units[3].front == 1, "native turn-start divination really pauses before retreat")
	await capture("02-fate-charm-divination")
	await click(choice_face(b)); await settled(b)
	await click(choice_face(b,Divination.TOP)); await settled(b)
	check(gs.pending_choice.is_empty() and p.deck.is_empty() and p.hand.any(func(i): return str(i.instanceId) == "ui-divine-bond") and p.units[3].front == 0, "native top choice resumes actual bond draw and retreat")
	foe.deck = [marked("c10101","ui-king1",0,1),marked("c17502","ui-king2",0,1),marked("c10101","ui-king3",0,1)]
	hand(b,["c18708"]); await settled(b)
	check(b._hand_row.get_child(0).data.currentCardStats == "当前面板 3/3", "original SSR card shows current dynamic3/3")
	await capture("03-dream-king-original-face")
	await click(b._hand_row.get_child(0)); await settled(b)
	check(p.units[1].attack == 3 and p.units[1].maxHp == 3, "native original SSR card installs dynamic form")
	b.queue_free(); await process_frame; await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	bond_rules(); moon_rules(); dream_rules(); ordering_rules(); fetch_rules(); continuation_rules()
	await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio()
	await process_frame; await process_frame
	print("BOND_DREAM checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
