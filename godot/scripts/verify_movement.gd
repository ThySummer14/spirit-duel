extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Movement := preload("res://scripts/movement_rules.gd")
const Charge := preload("res://scripts/sun_smoke_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("MOVEMENT_FAIL ", message)
func fixture() -> GS:
 var gs := GS.create(["xiaolunan", "lianyou", "yatiangou", "basalt"], ["xiaolunan", "lianyou", "yatiangou", "basalt"], 20261014)
 for p in gs.players:
  p.hand.clear()
  p.energy = 20
  p.levelUpUsed = true
  for u in p.units:
   u.level = 3
   u.charge = 0
 return gs
func give(gs, id: String, burst: int = 0, owner: int = 0) -> int:
 gs.player(owner).hand.append({"instanceId": "movement-%d" % gs.next_card_id, "definitionId": id, "movementBurst": burst})
 gs.next_card_id += 1
 return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, burst: int = 0, owner: int = 0) -> void:
 check(gs.play_card(owner, give(gs, id, burst, owner), target), "play " + id)
func roundtrip(gs) -> void:
 gs.players = JSON.parse_string(JSON.stringify(gs.players))
 gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
 gs.pending_choice = JSON.parse_string(JSON.stringify(gs.pending_choice))
 gs.response_window = JSON.parse_string(JSON.stringify(gs.response_window))
func _initialize() -> void:
 _movement()
 _crow()
 _deer()
 _weasel()
 _burst_choices()
 _ai()
 print("MOVEMENT checks=%d failures=%d" % [checks, failures])
 quit(0 if failures == 0 else 1)
func _movement() -> void:
 for serialized in [false, true]:
  var gs := fixture()
  var crow: Dictionary = gs.player(0).units[2]
  if serialized: roundtrip(gs);crow = gs.player(0).units[2]
  Movement.move_to(gs, 0, 2, 1)
  check(Movement.moves(crow, gs.turn_counter) == 1, "entry counts real move")
  if serialized: gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
  gs._resolve_resolution_stack()
  check(gs.player(1).avatarHp == 29, "entry projectile")
  Movement.move_to(gs, 0, 2, 1)
  gs._resolve_resolution_stack()
  check(gs.player(1).avatarHp == 29, "same-position no move")
  Movement.move_to(gs, 0, 0, 1)
  gs._resolve_resolution_stack()
  check(crow.front == 0 and Movement.moves(crow, gs.turn_counter) == 2 and gs.player(1).avatarHp == 28, "replacement retreats crow and triggers")
  Movement.move_to(gs, 0, 2, 1)
  gs._resolve_resolution_stack()
  gs._begin_turn(0)
  check(crow.front == 0 and gs.player(1).avatarHp == 26, "natural retreat triggers before draw")
  var hp := int(gs.player(1).avatarHp)
  crow.level = 0
  Movement.move_to(gs, 0, 2, 1)
  gs._resolve_resolution_stack()
  check(gs.player(1).avatarHp == hp, "inactive crow no ability")
 var gs := fixture()
 gs.player(1).units[0].front = 1
 gs.player(1).units[0].hp = 1
 check(gs.basic_attack(0, 2), "crow basic attack")
 check(gs.player(1).units[0].hp == 0 and gs.player(1).avatarHp == 29, "entry projectile kills front before actual combat retargets avatar")
 gs = fixture()
 gs.player(0).units[2].awakened = true
 gs.player(1).units[0].front = 1
 gs.player(1).units[0].baseAttack = 20
 gs._recalc(gs.player(1).units[0])
 Movement.move_to(gs, 0, 2, 1)
 gs._resolve_resolution_stack()
 check(gs.player(0).units[2].front == 1 and gs.player(0).units[2].hp == 6 and gs.player(1).units[0].hp == 5, "awake remote preserves front and no counter")
 Movement.move_to(gs, 0, 2, 0)
 gs._resolve_resolution_stack()
 check(gs.player(0).units[2].front == 0 and gs.player(1).units[0].hp == 4, "awake retreat also remote attacks")
func _crow() -> void:
 var gs := fixture()
 var deck: int = gs.player(0).deck.size()
 play(gs, "c13901")
 check(gs.player(0).units[2].front == 1 and gs.player(0).hand.size() == 1 and gs.player(0).deck.size() == deck - 1 and gs.player(0).energy == 20, "wind moves then draws with instant")
 play(gs, "c13901")
 check(gs.player(0).units[2].front == 0 and gs.player(1).avatarHp == 28 and gs.player(0).energy == 19, "second instant uses ordinary fire and retreats")
 var idx := give(gs, "c13906")
 check(gs.hand_card_def(0, idx).value == 4, "victory two movement history enhance+4")
 check(gs.play_card(0, idx), "enhanced victory")
 check(gs.player(1).avatarHp == 22, "card snapshot excludes move induced by its own play")
 gs = fixture()
 gs.player(0).units[0].front = 1
 play(gs, "c13902")
 check(gs.player(1).avatarHp == 25 and gs.player(0).units[2].shield == 2, "justice ally attack2 thencrow movement1 thenattack2 withprintedarmor")
 gs = fixture()
 gs.player(1).units[0].front = 1
 play(gs, "c13903", gs.player(1).units[1].uid)
 check(gs.player(1).units[0].front == 0 and gs.player(1).units[1].front == 1 and gs.player(1).units[1].frozen == 1 and gs.player(1).units[1].hp == 3, "feather force enemyfront and stun before crowprojectile")
 gs = fixture()
 play(gs, "c13904")
 var crow: Dictionary = gs.player(0).units[2]
 check(crow.attack == 2 and crow.maxHp == 8 and gs.player(1).units[0].hp == 6, "drain form exact2/8 no enter damage")
 crow.hp = 3
 Movement.move_to(gs, 0, 2, 1)
 gs._resolve_resolution_stack()
 gs.player(1).units[0].barrier = true
 Movement.end_turn(gs, 1)
 check(crow.hp == 3, "enemyendturn no drain")
 Movement.end_turn(gs, 0)
 check(crow.hp == 6 and gs.player(1).units[0].hp == 6 and gs.player(1).units[1].hp == 3, "drain heals total actual damage3 excludingbarrier")
 gs = fixture()
 gs.player(1).units[2].front = 1
 give(gs, "c13905", 0, 1)
 check(gs.basic_attack(0, 0), "attack into crow response")
 check(gs.player(1).hand.is_empty() and gs.player(1).units[2].hp == 6 and gs.player(0).units[0].hp == 4, "dodge cancels originalhit and moves twice projectiles2")
 check(gs.player(1).units[2].front == 1 and Movement.moves(gs.player(1).units[2], gs.turn_counter) == 2, "dodge two sequential moves return")
 gs = fixture()
 play(gs, "c13907", gs.player(1).units[0].uid)
 var target: Dictionary = gs.player(1).units[0]
 check(target.frozen == 1, "hold applies stun")
 roundtrip(gs)
 target = gs.player(1).units[0]
 gs.VerifiedRules.Stun.end_turn(gs, 1)
 gs.VerifiedRules.Stun.end_turn(gs, 1)
 check(target.frozen == 1, "hold survives naturalstun expiry afterJSON")
 gs.VerifiedRules.Stun.apply(gs, 1, 0, 2, 0)
 play(gs, "c13901")
 check(target.frozen == 2 and not target.has("movementHolders"), "crow next card releases hold but preserves independentstun")
 gs = fixture()
 play(gs, "c13907", gs.player(1).units[0].uid)
 gs._knockout_unit(gs.player(0).units[2])
 check(gs.player(1).units[0].frozen == 0, "crow knockout releases hold")
 gs = fixture()
 play(gs, "c13908")
 check(gs.player(0).units[2].attack == 3 and gs.player(0).units[2].maxHp == 8 and gs.player(0).units[2].awakened, "awake crow+2/+2")
func _deer() -> void:
 var gs := fixture()
 var deer: Dictionary = gs.player(0).units[0]
 check(deer.attack == 2 and deer.hp == 6 and gs.player(0).units[1].attack == 3, "base stats")
 gs._knockout_unit(deer)
 deer.charge = 0
 gs.VerifiedRules.reduce_countdown(gs, 0, 0, 2)
 check(deer.hp == 6 and deer.charge == 2, "deathcountdown revive grants2charge")
 play(gs, "c16301")
 check(deer.attack == 3 and deer.maxHp == 6, "blessingform3/6")
 Movement.deer_combat(gs, 0, 0)
 check(gs.player(0).units[1].charge == 1 and deer.charge == 2 and gs.player(0).energy == 19, "blessing othernativecharge nofiregain")
 gs.player(0).units[1].level = 0
 Movement.deer_combat(gs, 0, 0)
 check(gs.player(0).units[1].charge == 1, "inactivecharge recipient excluded")
 gs = fixture()
 play(gs, "c16302", gs.player(0).units[2].uid)
 check(gs.player(0).units[2].attack == 2 and gs.player(0).units[2].hp == 7 and gs.player(0).units[2].shield == 1 and gs.player(0).units[0].hp == 6, "aid normal singleally")
 gs = fixture()
 gs.player(0).units[0].charge = 2
 play(gs, "c16302", null, 2)
 check(gs.player(0).units[0].charge == 0 and gs.player(0).units.all(func(u): return int(u.shield) == 1), "aidburst allallies pays2")
 gs = fixture()
 gs.player(0).units[0].charge = 2
 gs.player(0).energy = 0
 play(gs, "c16303", gs.player(1).units[0].uid, 2)
 check(gs.player(0).energy == 0 and gs.player(0).units[0].charge == 0 and gs.player(1).units[0].frozen == 1 and gs.player(1).units[0].hp == 3, "forceburst2 instantstunthen3damage")
 gs = fixture()
 play(gs, "c16304")
 deer = gs.player(0).units[0]
 Movement.deer_combat(gs, 0, 0)
 Movement.deer_combat(gs, 0, 0)
 check(deer.attack == 4 and deer.maxHp == 6 and deer.charge == 1 and deer.shield == 1, "current2023 self once per actual turn gainschargeandarmor1")
 gs.turn_counter += 1
 Movement.deer_combat(gs, 0, 0)
 check(deer.charge == 2 and deer.shield == 2, "self triggers again opponentturn")
 gs = fixture()
 play(gs, "c16305", gs.player(0).units[1].uid)
 var enemyspell := ContentLoader.card_def("c16303")
 check(not gs.valid_targets(1, enemyspell).has(gs.player(0).units[1].uid), "veil denies enemy targetedspell")
 check(gs.valid_targets(0, enemyspell).has(gs.player(0).units[1].uid), "veil permits own targeting")
 check(gs._damage_unit(0, 1, 1, 1).damage == 1, "veil permits untargeted damage")
 for burst in [0, 2, 4, 8]:
  gs = fixture()
  gs.player(0).avatarHp = 10
  gs.player(0).units[0].charge = burst
  gs.player(1).units[3].front = 1
  play(gs, "c16306", null, burst)
  check(gs.player(0).units[0].charge == 0, "collision paysselectedtier%d" % burst)
  check(gs.player(0).units[0].hp == 6, "collision immunity tier%d" % burst)
  check(gs.player(0).avatarHp > 10 if burst >= 2 else gs.player(0).avatarHp == 10, "collision lifesteal healsavatar tier%d" % burst)
  if burst == 8: check(gs.player(1).units[3].hp == 0 and gs.player(1).avatarHp < 30, "collisionfull burstcombo+pierce actualsecondattack")
 gs = fixture()
 play(gs, "c16307")
 deer = gs.player(0).units[0]
 deer.charge = 0
 Movement.deer_combat(gs, 0, 0)
 check(gs.player(1).avatarHp == 30, "lifewithoutcharge nofakeprojectile")
 deer.charge = 1
 Movement.deer_combat(gs, 0, 0)
 check(deer.charge == 0 and gs.player(1).avatarHp == 27, "life spends1projectile3")
 gs = fixture()
 deer = gs.player(0).units[0]
 gs._knockout_unit(deer)
 play(gs, "c16308")
 check(deer.hp == 7 and deer.maxHp == 7 and deer.charge == 2 and deer.awakened, "awakedeadrevivefull+1hpand2charge")
 gs._knockout_unit(deer)
 deer.charge = 2
 var form := give(gs, "c16301")
 check(not gs.can_play_card(0, form).ok, "awakeformdead insufficient3charge illegal")
 deer.charge = 3
 check(gs.play_card(0, form), "awakeformdeadpay3")
 check(deer.hp == 7 and deer.charge == 2 and deer.attack == 3, "reviveform keepsawakegrowth2charge")
 gs = fixture()
 gs._knockout_unit(gs.player(0).units[0])
 check(not gs.can_play_card(0, give(gs, "c16301")).ok, "nonawakeformcannotusedead")
func _weasel() -> void:
 var gs := fixture()
 play(gs, "c13302")
 check(gs.player(0).units[1].charge == 1 and gs.player(0).energy == 20 and gs.player(0).hand.size() == 1, "cooperateinstantchargecopydraw")
 gs = fixture()
 var weasel: Dictionary = gs.player(0).units[1]
 weasel.charge = 5
 play(gs, "c13303")
 check(weasel.attack == 5 and weasel.maxHp == 5, "crowd3/5 plusfloorcharge/2")
 Charge.pay_charge(gs, 0, 1, 2)
 check(weasel.attack == 4, "dynamicchargepowerdecreasesonpayment")
 Charge.gain_charge(gs, 0, 1, 1)
 check(weasel.attack == 5, "dynamicchargepowerincreasesongain")
 gs = fixture()
 gs.player(0).units[1].charge = 3
 play(gs, "c13301", null, 3)
 check(gs.player(1).avatarHp == 23 and gs.player(0).units[1].charge == 1 and gs.player(0).units[1].shield == 1, "axe3burst+3attack actualavatar gain1energy")
 gs = fixture()
 gs.player(1).avatarArmor = 20
 play(gs, "c13301")
 check(gs.player(0).units[1].charge == 0, "armoronlydamage nochargegain")
 gs = fixture()
 gs.player(0).units[1].charge = 4
 play(gs, "c13304", null, 4)
 check(gs.player(1).avatarHp == 21 and gs.player(1).avatarArmorBreak == 0 and gs.player(0).units[1].charge == 2 and gs.player(0).units[1].shield == 2, "spear3 thenaxe4+armorbreak2 basechainnofurtherburst")
 for tier in [0, 3, 7]:
  gs = fixture()
  gs.player(0).units[1].charge = tier
  play(gs, "c13308", null, tier)
  check(gs.player(1).avatarFrozen == 1, "club actualdamage stunsavatar")
  check(gs.player(1).avatarHp == (25 if tier == 0 else 22 if tier == 3 else 16), "club sequentialbasechain tier%d" % tier)
 gs = fixture()
 gs.player(1).units[3].front = 1
 play(gs, "c13308")
 check(gs.player(1).units[3].attack == 0 and gs.player(0).units[1].hp == 4, "clubzeroscurrentturncounter")
 Movement.end_turn(gs, 0)
 check(gs.player(1).units[3].attack == 1, "clubzeroexpiresendturn")
 gs = fixture()
 play(gs, "c13306")
 weasel = gs.player(0).units[1]
 weasel.front = 1
 weasel.charge = 3
 weasel.shield = 2
 weasel.armorBreak = 1
 var hit: Dictionary = gs._damage_unit(0, 1, 20, 1)
 check(hit.damage == 0 and weasel.hp == 5 and weasel.front == 0 and weasel.charge == 0 and weasel.shield == 2 and weasel.armorBreak == 1, "immortallethalpreventwholeeventretreatwithoutconsumingarmor")
 hit = gs._damage_unit(0, 1, 20, 1)
 check(hit.knocked and weasel.hp == 0, "insufficientchargecannotpreventlethal")
 gs = fixture()
 play(gs, "c13306")
 weasel = gs.player(0).units[1]
 weasel.charge = 3
 hit = gs._damage_unit(0, 1, 1, 1)
 check(hit.damage == 1 and weasel.charge == 3, "nonlethalnotpay")
 gs = fixture()
 play(gs, "c13307")
 weasel = gs.player(0).units[1]
 weasel.charge = 3
 gs.player(0).energy = 0
 gs.player(0).attackUsed = false
 check(not gs.can_basic_attack(0, 1).ok, "awake requiresordinaryattackexhausted")
 gs.player(0).attackUsed = true
 check(gs.basic_attack(0, 1) and weasel.charge == 1 and gs.player(0).energy == 0, "awakeextraattack3chargethenavatarhitgain1")
 check(not gs.can_basic_attack(0, 1).ok, "extraattackcannotoverspend")
 gs = fixture()
 gs.player(1).units[1].front = 1
 give(gs, "c13305", 0, 1)
 var before: Array = gs.player(0).units.map(func(u): return int(u.hp))
 check(gs.basic_attack(0, 0), "weaselautomaticredirectresponse")
 check(gs.player(1).units[1].hp == 4 and gs.player(1).hand.is_empty(), "responseimmuneweaseloriginaldamage")
 check(gs.player(0).units[0].hp == 6, "responsecounterretargetexcludesoriginalattacker")
 check(gs.player(0).avatarHp < 30 or gs.player(0).units.map(func(u): return int(u.hp)) != before, "responseactuallydamagesotherrole")
 gs = fixture()
 gs.player(1).units[0].front = 1
 play(gs, "c13305")
 check(gs.player(1).units[0].hp == 6 and gs.player(0).units[1].hp == 4, "manualredirectexcludesoldfrontimmunity")
func _burst_choices() -> void:
 for serialized in [false, true]:
  var gs := fixture()
  gs.player(0).units[0].charge = 4
  var hand := give(gs, "c16306")
  check(Movement.request_burst(gs, 0, hand), "burstopens")
  check(gs.pending_choice.instanceIds == ["burst:0", "burst:2", "burst:4", "movement-cancel"], "burstquotesonlyaffordabletiers")
  check(gs.player(0).energy == 20 and gs.player(0).units[0].charge == 4, "choiceopeningnopayment")
  if serialized: roundtrip(gs)
  check(not gs.resolve_divination_choice(1, "burst:4"), "wrongownerillegal")
  check(not gs.resolve_divination_choice(0, "burst:8"), "unlistedtierillegal")
  check(gs.resolve_divination_choice(0, "burst:4"), "chooseslegalburst4")
  check(gs.player(0).units[0].charge == 4 and gs.player(0).hand.size() == 1 and gs.phase == "main", "choiceonlyprepareshand")
  check(gs.play_card(0, Movement.ready_hand(gs, 0)), "preparedburstplay")
  check(gs.player(0).units[0].charge == 0, "playpaysonce")
 var gs := fixture()
 var idx := give(gs, "c16303")
 gs.player(0).units[0].charge = 2
 gs.player(0).energy = 0
 check(Movement.has_playable_burst(gs, 0, idx), "zero-fireinstantburstcanopenUI")
 check(Movement.request_burst(gs, 0, idx) and gs.resolve_divination_choice(0, Movement.CANCEL), "cancelburstchoice")
 check(gs.player(0).hand.size() == 1 and gs.player(0).units[0].charge == 2 and gs.player(0).energy == 0, "cancelnopayment")
func _ai() -> void:
 for id in ["c16301","c16302","c16303","c16304","c16305","c16306","c16307","c16308","c13301","c13302","c13303","c13304","c13305","c13306","c13307","c13308","c13901","c13902","c13903","c13904","c13905","c13906","c13907","c13908"]:
  var gs := fixture()
  for u in gs.player(0).units: u.charge = 10
  give(gs, id)
  var best := AI._best_card(gs, 0)
  check(best.ok, "AIcandidate " + id)
  if best.ok:
   check(gs.can_play_card(0, int(best.hand), best.target).ok, "AIlegal " + id)
   check(gs.play_card(0, int(best.hand), best.target), "AIactuallyplays " + id)
   check(gs.pending_choice.is_empty() and gs.response_window.is_empty(), "AIfinishes " + id)
