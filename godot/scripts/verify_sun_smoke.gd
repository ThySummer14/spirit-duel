extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Rules := preload("res://scripts/sun_smoke_rules.gd")
const Content := preload("res://scripts/content_loader.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("SUN_SMOKE_FAIL ", detail)
func fixture() -> GS:
 var gs := GS.create(["rihefang", "yanyanluo", "taohuayao", "shantong"], ["yanyanluo", "rihefang", "xuenv", "jutun-tongzi"], 20261014)
 gs.turn_counter = 20
 gs.current_player = 0
 for p in gs.players:
  p.hand.clear()
  p.energy = 40
  p.levelUpUsed = true
  for u in p.units:
   u.level = 3
   u.charge = 0
 return gs
func give(gs, id: String, owner: int = 0) -> int:
 gs.player(owner).hand.append({"instanceId": "sun-smoke-%d" % gs.next_card_id, "definitionId": id})
 gs.next_card_id += 1
 return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
 check(gs.play_card(owner, give(gs, id, owner), target), "legal play " + id)
func choose(gs, id: String, owner: int = 0) -> void:
 check(gs.resolve_divination_choice(owner, id), "legal choice " + id)
func clone(gs, owner: int = 0) -> Dictionary:
 return gs.front_unit(owner)
func _initialize() -> void:
 _charge()
 _sun_forms()
 _sun_spells()
 _smoke_spells()
 _clones()
 _shared_summon_lifecycle()
 _response()
 _reset()
 _ai_json()
 print("SUN_SMOKE checks=%d failures=%d" % [checks, failures])
 quit(0 if failures == 0 else 1)
func _charge() -> void:
 var gs := fixture()
 var p: Dictionary = gs.player(0)
 check(Rules.has_charge(p.units[0]) and Rules.has_charge(p.units[1]) and not Rules.has_charge(p.units[2]), "native charge ignores old approximate hooks")
 Rules.gain_charge(gs, 0, 1, 1)
 check(p.units[1].charge == 2, "smoke from zero gains one extra")
 Rules.gain_charge(gs, 0, 1, 1)
 check(p.units[1].charge == 3, "smoke positive energy no extra")
 p.units[1].charge = 0
 play(gs, "c16406")
 check(p.units[1].charge == 3 and p.units[1].attack == 3 and p.units[1].maxHp == 5, "smoke gain2 before ability replacement and awakening stats")
 Rules.gain_charge(gs, 0, 1, 2)
 check(p.units[1].charge == 7, "awakened smoke doubles future energy")
 Rules.gain_charge(gs, 0, 1, 10)
 check(p.units[1].charge == 10, "charge caps at ten")
 gs = fixture(); p = gs.player(0)
 check(not Rules.pay_charge(gs, 0, 1, 2) and p.units[1].hp == 4, "non-sun cannot substitute health")
 p.units[0].charge = 1
 check(Rules.pay_charge(gs, 0, 0, 3) and p.units[0].charge == 0 and p.units[0].hp == 4, "sun shortage spends exactly missing health")
 p.units[0].hp = 2
 check(not Rules.pay_charge(gs, 0, 0, 2) and p.units[0].hp == 2, "sun cannot reduce health to zero")
 p.units[0].shield = 2
 check(Rules.quote_charge(gs, 0, 0, 2).health == 0, "quote uses armor fallback")
 check(Rules.pay_charge(gs, 0, 0, 2) and p.units[0].hp == 2 and p.units[0].shield == 0, "armor covers missing energy")
 p.units[0].armorBreak = 1
 check(not Rules.pay_charge(gs, 0, 0, 1), "quote accounts for armor break lethal cost")
 p.units[0].armorBreak = 0; p.units[0].hp = 6
 play(gs, "c16607")
 check(p.units[0].attack == 1 and p.units[0].maxHp == 9 and p.units[0].awakened, "sun awakening printed zero attack and three health")
 var q := Rules.quote_charge(gs, 0, 1, 8)
 check(q.ok and q.free and q.amount == 8 and q.charge == 0 and not p.has("sunFreeChargeTurn"), "free quote is read-only and preserves fixed burst amount")
 check(Rules.pay_charge(gs, 0, 1, 8) and p.units[1].charge == 0, "first team energy consumption waived even when short")
 check(not Rules.pay_charge(gs, 0, 1, 1), "second consuming effect must really pay")
 gs.turn_counter += 1
 p.units[0].hp = 0
 check(not Rules.pay_charge(gs, 0, 1, 8), "knocked sun cannot supply free aura")
 p.units[0].hp = 9
 check(Rules.pay_charge(gs, 0, 1, 8), "free aura resets on next turn serial")
 gs = fixture(); p = gs.player(0)
 p.units[1].hp = 0; p.units[1].knockout = 1
 gs._begin_turn(0)
 check(p.units[1].hp == 4 and p.units[1].charge == 2 and p.units[0].charge == 1, "natural revival participates in turn-start native charge")
func _sun_forms() -> void:
 var gs := fixture(); var p: Dictionary = gs.player(0)
 var n: int = p.deck.size()
 play(gs, "c16603")
 check(p.units[0].maxHp == 7 and p.units[0].hp == 4 and p.deck.size() == n - 1, "2023 pray entry costs3 and draws1")
 p.hand.clear(); gs._begin_turn(0)
 check(p.units[0].charge == 0 and p.units[0].hp == 2 and p.deck.size() == n - 3, "pray own-start after charge before regular draw")
 gs = fixture(); p = gs.player(0)
 p.units[1].charge = 4
 p.units[2].keywords = ["charge"]; p.units[2].charge = 1
 play(gs, "c16605")
 check(p.units[0].attack == 2 and p.units[0].maxHp == 7 and p.units[0].hp == 5, "transfer form real body and cost2")
 check(p.units[1].charge == 4 and p.units[2].charge == 3 and p.energy == 39, "transfer chooses other minimum-energy charged unit without ghost fire grant")
 gs = fixture(); p = gs.player(0)
 p.units[1].hp = 0
 play(gs, "c16605")
 check(p.units[0].hp == 7 and p.units[0].charge == 0, "no eligible transfer target does not pay energy")
 gs = fixture(); p = gs.player(0)
 p.units[0].charge = 3; p.units[1].hp = 1; p.avatarHp = 20
 play(gs, "c16608")
 check(p.units[0].attack == 3 and p.units[0].maxHp == 8 and p.units[0].charge == 0 and p.units[1].hp == 4 and p.avatarHp == 23, "rain entry heals other characters including avatar")
 p.units[0].hp = 2
 gs._damage_unit(0, 1, 1, 1, 0)
 check(p.units[0].hp == 5, "other ally damage triggers rain self heal")
 gs._damage_avatar(0, 1, 1, 0)
 check(p.units[0].hp == 8, "avatar damage triggers rain self heal")
 gs._damage_unit(0, 0, 2, 1, 0)
 check(p.units[0].hp == 6, "rain does not self heal from its own damage")
 p.units[1].hp = 1; p.avatarHp = 20; p.units[0].charge = 3
 gs._begin_turn(1)
 check(p.units[1].hp == 4 and p.avatarHp == 23 and p.units[0].charge == 0, "rain also triggers at enemy turn start")
 gs = fixture(); p = gs.player(0)
 p.units[0].awakened = true
 play(gs, "c16603")
 check(p.units[0].hp == 7 and int(p.sunFreeChargeTurn) == gs.turn_counter, "first entry trigger uses sun free allowance")
 play(gs, "c16605")
 check(p.units[0].hp == 5, "second installed form consumes after free allowance used")
func _sun_spells() -> void:
 var gs := fixture(); var p: Dictionary = gs.player(0)
 p.units[0].hp = 2; p.units[1].hp = 1; p.units[2].hp = 1
 var fire: int = p.energy
 play(gs, "c16601")
 check(p.energy == fire and p.units[0].hp == 6 and p.units[1].hp == 4 and p.units[2].hp == 1, "instant bath restores only charged units and costs free first instant")
 check(p.units[0].charge == 1 and p.units[1].charge == 2 and p.units[2].shield == 0, "bath charge gain uses smoke zero bonus and no historical armor approximation")
 play(gs, "c16604")
 check(p.units[0].attack == 2 and p.units[0].maxHp == 7 and p.units[0].charge == 3 and p.units[1].attack == 3 and p.units[1].maxHp == 5 and p.units[1].charge == 4, "winter only charged growth1/1 and energy2")
 check(p.units[2].attack == p.units[2].baseAttack and p.units[2].charge == 0, "winter ignores non-charge allies")
 gs._knockout_unit(p.units[1])
 check(p.units[1].attack == 2 and p.units[1].maxHp == 4, "winter ordinary growth is cleared by knockout")
 gs = fixture(); var e: Dictionary = gs.player(1)
 e.units[0].barrier = true
 play(gs, "c16602", e.units[0].uid)
 check(e.units[0].hp == 4 and e.units[0].frozen == 1 and not e.units[0].barrier, "heat stun occurs even when damage blocked")
 var h: int = gs.player(0).units[1].hp
 play(gs, "c16602", gs.player(0).units[1].uid)
 check(gs.player(0).units[1].hp == h - 1 and gs.player(0).units[1].frozen == 2, "heat intentionally supports friendly legal targets")
func _smoke_spells() -> void:
 var gs := fixture(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
 p.units[1].charge = 3
 var h: int = e.units[0].hp
 play(gs, "c16401", e.units[0].uid)
 check(gs.pending_choice.type == "smoke-burst" and e.units[0].hp == h, "targeted spell waits for explicit optional burst")
 check(not gs.resolve_divination_choice(1, "smoke-burst") and not gs.resolve_divination_choice(0, "bogus"), "choice rejects wrong owner and foreign id")
 choose(gs, "smoke-plain")
 check(p.units[1].charge == 3 and e.units[0].hp == h - 2, "declining burst preserves all energy")
 gs = fixture(); p = gs.player(0); e = gs.player(1)
 p.units[1].charge = 4; e.units[0].baseMaxHp = 20; e.units[0].maxHp = 20; e.units[0].hp = 20
 play(gs, "c16401", e.units[0].uid); choose(gs, "smoke-burst")
 check(e.units[0].hp == 14 and p.units[1].charge == 0, "X is all source energy and consumed exactly once")
 gs = fixture(); p = gs.player(0); e = gs.player(1)
 p.avatarHp = 20; var enemy_hp: int = e.avatarHp
 play(gs, "c16403"); choose(gs, "smoke-plain")
 check(e.avatarHp == enemy_hp and p.avatarHp == 23, "greedy empty front heals without misdirected avatar damage")
 e.units[0].front = 1; p.units[1].charge = 1
 play(gs, "c16403"); choose(gs, "smoke-burst")
 check(e.units[0].hp == 0 and e.avatarHp == enemy_hp and p.avatarHp == 26, "greedy damages front only, never overflows")
 gs = fixture(); p = gs.player(0); e = gs.player(1)
 play(gs, "c16408"); choose(gs, "smoke-plain")
 check(e.avatarHp == 26 and p.units[1].charge == 0, "2024 projectile4 resolves to empty front avatar")
 e.units[0].front = 1
 play(gs, "c16408"); choose(gs, "smoke-plain")
 check(e.units[0].hp == 0 and p.units[1].charge == 5 and e.avatarHp == 26, "2024 kill gain4 includes zero-energy basic extra1")
 gs = fixture(); p = gs.player(0)
 play(gs, "c16405")
 check(p.units[1].charge == 4 and p.energy == 40, "instant smoke charge3 with zero extra1 and real instant payment")
 gs = fixture(); p = gs.player(0); e = gs.player(1)
 var c: Dictionary = Content.card_def("c16401").duplicate(true)
 c.foxHandDamageBonus = 1; c.smokeBurstSelected = false
 Rules.resolve_smoke_hit(gs, 0, 1, c, e.units[0].uid)
 check(e.units[0].hp == 1 and c.value == 2, "hand spell damage bonus applied once without changing printed value")
func _clones() -> void:
 var gs := fixture(); var p: Dictionary = gs.player(0)
 p.units[1].charge = 5; p.units[1].attackBonus = 2; p.units[1].shield = 3; p.units[1].armorBreak = 2; p.units[1].unyielding = true; p.units[1].barrier = true; p.units[1].swift = true
 gs._recalc(p.units[1]); p.units[1].hp = 3
 play(gs, "c16404")
 var c := clone(gs)
 check(c.smokeClone and c.attack == 4 and c.maxHp == 4 and c.hp == 3 and c.charge == 2, "clone snapshots current stats currentHP and floor-half energy")
 check(c.shield == 3 and c.armorBreak == 2 and not c.awakened and not c.unyielding and not c.barrier and not c.swift, "clone preserves armor and break but excludes positive abilities")
 Rules.gain_charge(gs, 0, gs.front_index(0), 1)
 check(c.charge == 3, "clone charges without original smoke basic extra")
 p.units[1].attackBonus += 1; gs._recalc(p.units[1])
 check(c.attack == 4, "later original growth does not alter clone snapshot")
 gs.VerifiedRules.move_unit(gs, 0, c)
 check(c.hp == 0 and c.removed and c.knockout == 0, "moving clone out removes rather than permanent reserve slot")
 gs = fixture(); p = gs.player(0)
 p.units[1].charge = 6
 play(gs, "c16402")
 c = clone(gs)
 check(p.units[1].attack == 2 and p.units[1].maxHp == 4 and c.charge == 3 and c.attack == 5, "smoke power form charge power belongs only to clone")
 Rules.gain_charge(gs, 0, gs.front_index(0), 2)
 check(c.attack == 7, "clone strength dynamically reflects own energy")
 gs._knockout_unit(c)
 check(c.removed and c.knockout == 0, "destroyed clone cannot naturally revive")
 gs = fixture(); p = gs.player(0)
 p.units[1].charge = 6
 play(gs, "c16407")
 check(gs.pending_choice.type == "smoke-pick" and gs.front_index(0) < 0, "2023 form waits for generated card choice before summon")
 check(gs.pending_choice.instanceIds.size() == 3 and gs.pending_choice.instanceIds.has("c16408"), "all smoke burst cards offered without hand/deck restriction")
 choose(gs, "c16408")
 c = clone(gs)
 check(p.hand[0].definitionId == "c16408" and c.attack == 3 and c.maxHp == 6 and c.charge == 3, "choice generates fresh card and real3/6 copy clone")
 p.hand.clear()
 var e: Dictionary = gs.player(1)
 e.units[0].baseMaxHp = 30; e.units[0].maxHp = 30; e.units[0].hp = 30; e.units[0].front = 1
 play(gs, "c16401", e.units[0].uid); choose(gs, "smoke-burst")
 check(e.units[0].hp == 17 and p.units[1].charge == 0 and c.charge == 0, "copy targeted burst uses original6 and clone3 separately, same target")
 check(gs.rule_events.any(func(ev): return ev.kind == "smoke-spell-copy"), "copy enters native announcement/complete stack")
 p.hand.clear(); play(gs, "c16405")
 check(p.units[1].charge == 4 and c.charge == 3, "copy gain uses each body's own charge ability")
 play(gs, "c16601")
 check(p.units[1].charge == 5 and c.charge == 4 and c.hp == c.maxHp, "bath includes charged summoned clone")
 c.frozen = 1; p.units[1].charge = 0; c.charge = 0
 play(gs, "c16405")
 check(p.units[1].charge == 4 and c.charge == 0, "frozen clone cannot copy spell")
 c.frozen = 0; gs._begin_turn(0)
 check(c.removed and clone(gs).uid != c.uid and clone(gs).charge == 2, "copy form turn-start replaces clone with half updated original energy")
 # Original kills front; copied projectile sees current empty front and hits avatar.
 gs = fixture(); p = gs.player(0); e = gs.player(1)
 play(gs, "c16407"); choose(gs, "c16408"); p.hand.clear()
 e.units[0].front = 1
 play(gs, "c16408"); choose(gs, "smoke-plain")
 check(e.units[0].hp == 0 and e.avatarHp == 26 and p.units[1].charge == 5, "projectile copy retargets updated front after original kill")
 # A summon spell must not retroactively copy itself through its new clone.
 gs = fixture(); p = gs.player(0)
 play(gs, "c16407"); choose(gs, "c16408"); p.hand.clear()
 var old_clone: Dictionary = clone(gs)
 play(gs, "c16404")
 check(old_clone.removed and clone(gs).summonerUid == p.units[1].uid and clone(gs).formRules.smokeCopies, "replacement clone belongs to original and keeps installed copy form")
 var active_clones: Array = p.units.filter(func(u): return u.get("smokeClone", false) and u.hp > 0)
 check(active_clones.size() == 1 and p.units.size() == 6, "newly created clone cannot retroactively copy summon spell")
 p.units[1].charge = 0
 play(gs, "c16405")
 check(clone(gs).charge == 3, "replacement clone continues to copy later spells")
func _shared_summon_lifecycle() -> void:
 var gs := fixture()
 var old: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs,0,2,"legacy-front","其他召唤物",2,4)
 play(gs, "c16404")
 var first := clone(gs)
 check(first.get("smokeClone",false) and old.get("removed",false) and old.hp == 0 and old.knockout == 0, "Smoke clone removes the displaced native summon")
 var removed: int = gs.rule_events.find_custom(func(e): return e.kind == "summon-removed" and e.uid == old.uid)
 var entered: int = gs.rule_events.find_custom(func(e): return e.kind == "summon-created" and e.uid == first.uid)
 check(removed >= 0 and entered > removed, "old summon leaves before smoke entry triggers inspect the board")
 play(gs, "c16404")
 check(first.get("removed",false) and clone(gs).uid != first.uid, "second clone replaces the first once")
 play(gs, "c16404")
 var removals: Array = gs.rule_events.filter(func(e): return e.kind == "summon-removed" and e.uid == first.uid)
 check(removals.size() == 1, "third clone never announces another removal of the old tombstone")
func _response() -> void:
 var gs := fixture(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
 give(gs, "c16602", 1); e.units[1].level = 2; p.units[1].level = 1; p.levelUpUsed = false
 check(gs.level_up(0, 1), "level-up action remains valid with automatic sun response")
 check(p.units[1].level == 2 and p.units[1].hp == 3 and p.units[1].frozen == 2 and not e.hand.any(func(i): return i.definitionId == "c16602") and e.units[1].charge == 0, "heat response targets upgraded enemy and has no stale3energy cost")
 gs = fixture(); p = gs.player(0)
 give(gs, "c16602"); p.units[1].level = 1; p.levelUpUsed = false
 gs.level_up(0, 1)
 check(p.hand.size() == 1 and p.units[1].hp == 4, "heat never responds on own turn")
 gs = fixture(); p = gs.player(0); e = gs.player(1)
 give(gs, "c16404", 1)
 e.units[0].charge = 4
 var hp: int = e.avatarHp
 check(gs.basic_attack(0, 3), "avatar attack accepted")
 check(e.avatarHp == hp and e.hand.is_empty() and e.units.size() == 5 and e.units[4].smokeClone, "smoke avatar response summons blocking front before hit")
 check(e.units.size()>4 and e.units[4].hp < 4 and p.units[3].hp < p.units[3].maxHp, "attack really exchanges combat damage with response clone")
func _reset() -> void:
 var gs := fixture(); var p: Dictionary = gs.player(0); var sun: Dictionary = p.units[0]
 play(gs, "c16607"); play(gs, "c16603")
 # Free entry: current 1/7 form plus permanent awakening +0/+3.
 gs._grow_unit(sun, 4, 4); sun.shield = 5; sun.armorBreak = 3; sun.hp = 2
 play(gs, "c16606", sun.uid)
 check(sun.attack == 1 and sun.maxHp == 10 and sun.hp == 10 and sun.shield == 0 and sun.armorBreak == 0 and sun.form.cardId == "c16603", "reset restores current printed form and preserves awakening")
 gs = fixture(); p = gs.player(0)
 play(gs, "c10809")
 p.units[1].hp = 1
 play(gs, "c10801", p.units[1].uid)
 var a: int = p.units[1].attack; var h: int = p.units[1].maxHp
 play(gs, "c16604")
 play(gs, "c16606", p.units[1].uid)
 check(p.units[1].attack == a and p.units[1].maxHp == h and not p.units[1].has("sunTemporaryGrowth"), "reset preserves explicit permanent peach growth and clears winter tracker")
 gs._knockout_unit(p.units[1])
 check(p.units[1].attack == a and p.units[1].maxHp == h, "cleared winter tracker cannot subtract permanent growth later")
 gs = fixture(); p = gs.player(0)
 p.units[3].permanentAttack = 3; gs._grow_unit(p.units[3], 2, 2)
 play(gs, "c16606", p.units[3].uid)
 check(p.units[3].attack == p.units[3].baseAttack + 3 and p.units[3].maxHp == p.units[3].baseMaxHp, "reset retains separately stored permanentAttack")
 gs.kw_usage(1, "encourage").attack = 4; gs.kw_usage(1, "encourage").shield = 3
 gs.player(1).avatarArmor = 5
 play(gs, "c16606", "avatar-1")
 check(gs.kw_usage(1, "encourage").attack == 0 and gs.kw_usage(1, "encourage").shield == 0 and gs.player(1).avatarArmor == 5, "avatar reset clears encourage and does not erase unrelated avatar armor")
func _ai_json() -> void:
 var gs := fixture(); var p: Dictionary = gs.player(0); var e: Dictionary = gs.player(1)
 p.units[1].charge = 3
 play(gs, "c16401", e.units[0].uid)
 var encoded := JSON.stringify(gs.snapshot())
 var restored: Dictionary = JSON.parse_string(encoded)
 check(restored.pendingChoiceState.type == "smoke-burst" and restored.pendingChoiceState.card.id == "c16401" and restored.pendingChoiceState.targetId == e.units[0].uid, "pending burst JSON retains exact source card target and resolution")
 gs.pending_choice = restored.pendingChoiceState
 check(AI._resolve_choice(gs, 0) and gs.pending_choice.is_empty() and p.units[1].charge == 0, "AI resolves JSON-restored burst legally")
 gs = fixture(); play(gs, "c16407")
 restored = JSON.parse_string(JSON.stringify(gs.snapshot()))
 check(restored.pendingChoiceState.instanceIds.size() == 3 and Rules.choice_card(gs, 0, "c16408").value == 4, "generated-card JSON and UI values use latest4 damage")
 check(AI._resolve_choice(gs, 0) and gs.player(0).hand[0].definitionId == "c16408", "AI legally chooses generated burst card")
 check(AI._score_card(gs, 0, Content.card_def("c16602"), gs.player(0).units[0].uid) < 0 and AI._score_card(gs, 0, Content.card_def("c16602"), gs.player(1).units[0].uid) > 0, "AI heat evaluates hostile target instead of friendly stun")
 for c in Content.cards_for_unit("rihefang") + Content.cards_for_unit("yanyanluo"):
  if c.get("type") == "coop":
   check(c.id == "c164166" and c.coopFaces.size() == 2 and c.coopFaces.all(func(face): return face.get("verifiedRules", false) and str(face.effect).begins_with("coop-middle-")), "full native cooperative faces " + c.id)
  else:
   check(c.get("sunSmoke", false) and not c.text.contains("简化") and not c.get("effects", []).is_empty(), "full native content " + c.id)
