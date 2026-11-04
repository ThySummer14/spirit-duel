extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Movement := preload("res://scripts/movement_rules.gd")
const Charge := preload("res://scripts/sun_smoke_rules.gd")
var checks := 0
var failures := 0
var matches := 0
func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("MOVEMENT_CONTINUATION_FAIL ", text)
func fixture(own: Array) -> GS:
 var gs := GS.create(own, ["xiaolunan", "lianyou", "yatiangou", "basalt"], 20261014)
 for p in gs.players:
  p.hand.clear()
  p.energy = 20
  p.levelUpUsed = true
  for u in p.units:
   u.level = 3
   u.charge = 0
 return gs
func give(gs, id: String, burst: int = 0) -> int:
 gs.player(0).hand.append({"instanceId": "movement-linked-%d" % gs.next_card_id, "definitionId": id, "movementBurst": burst})
 gs.next_card_id += 1
 return gs.player(0).hand.size() - 1
func _initialize() -> void:
 _linked_charge()
 _linked_movement()
 var lineups := [
  ["xiaolunan", "lianyou", "yatiangou", "rihefang"],
  ["yanyanluo", "lianyou", "yatiangou", "xiaolunan"],
  ["jue", "shuweng", "quanshen", "yatiangou"],
  ["yaohu", "lingyuyuqian", "qingwa-ciqi", "shantu"],
 ]
 for i in lineups.size():
  for variant in 3:
   var seed := 202610140 + i * 3 + variant
   var a := GS.create(lineups[i], lineups[(i + 1) % lineups.size()], seed)
   var b := GS.create(lineups[i], lineups[(i + 1) % lineups.size()], seed)
   for step in 180:
    if a.winner >= 0 or b.winner >= 0: break
    var owner := a.action_player()
    var before := a.command_log.size()
    AI.take_turn(a, owner)
    AI.take_turn(b, owner)
    check(a.winner >= 0 or a.command_log.size() > before, "mixedAIprogressseed%dstep%d" % [seed, step])
    if step % 3 == 0:
     b.players = JSON.parse_string(JSON.stringify(b.players))
     b.pending_choice = JSON.parse_string(JSON.stringify(b.pending_choice))
     b.response_window = JSON.parse_string(JSON.stringify(b.response_window))
     b.resolution_stack = JSON.parse_string(JSON.stringify(b.resolution_stack))
    var x = JSON.parse_string(JSON.stringify(a.snapshot()))
    var y = JSON.parse_string(JSON.stringify(b.snapshot()))
    check(x == y, "mixedJSONdeterministicseed%dstep%d" % [seed, step])
    if failures > 0: break
   check(a.winner >= 0 and a.winner == b.winner, "mixedseedbothmatchesfinish")
   matches += 1
 print("MOVEMENT_CONTINUATION checks=%d failures=%d matches=%d" % [checks, failures, matches])
 quit(0 if failures == 0 else 1)
func _linked_charge() -> void:
 var gs := fixture(["xiaolunan", "lianyou", "rihefang", "yanyanluo"])
 var p: Dictionary = gs.player(0)
 p.units[2].awakened = true
 var h := give(gs, "c16306", 8)
 var quote := Charge.quote_charge(gs, 0, 0, 8)
 check(quote.ok and quote.amount == 8 and quote.free and quote.charge == 0, "sunfreeallowsfixed8burstwithoutcharge")
 check(gs.play_card(0, h), "collisionfreeburst8play")
 check(p.units[0].charge == 0 and p.sunFreeChargeTurn == gs.turn_counter and gs.player(1).avatarHp == 16, "freekeeps8tierpower+comboandconsumesoneactualturnallowance")
 check(not gs.can_play_card(0, give(gs, "c16306", 8)).ok, "sunsecondburstnotfree")
 gs.turn_counter += 1
 check(gs.can_play_card(0, p.hand.size() - 1).ok, "actualopponentturnresetsfreequote")
 gs = fixture(["xiaolunan", "lianyou", "rihefang", "yanyanluo"])
 p = gs.player(0)
 check(gs.play_card(0, give(gs, "c16301")), "linkedblessingform")
 p.units[1].level = 0
 p.units[2].level = 0
 Movement.deer_combat(gs, 0, 0)
 check(p.units[3].charge == 2 and p.units[0].charge == 0, "blessingsmokeat0usesnativebonusgain2")
 p.units[3].awakened = true
 Movement.deer_combat(gs, 0, 0)
 check(p.units[3].charge == 4, "blessingawakesmokesharedgainx2")
 gs = fixture(["xiaolunan", "lianyou", "rihefang", "yanyanluo"])
 p = gs.player(0)
 gs._knockout_unit(p.units[0])
 p.units[0].knockout = 1
 gs._begin_turn(0)
 check(p.units[0].charge == 3 and p.units[0].hp == 6, "naturalrevive2thenbeginturnnativecharge1")
 gs = fixture(["xiaolunan", "lianyou", "rihefang", "yanyanluo"])
 p = gs.player(0)
 p.units[0].awakened = true
 p.units[2].awakened = true
 gs._knockout_unit(p.units[0])
 check(gs.play_card(0, give(gs, "c16301")), "sunfreeallowsdeadawakeformwith0charge")
 check(p.units[0].hp == 6 and p.units[0].charge == 2 and p.sunFreeChargeTurn == gs.turn_counter, "deadformfreepaymentthenrevive2distinct")
 gs = fixture(["xiaolunan", "lianyou", "rihefang", "yanyanluo"])
 p = gs.player(0)
 p.units[1].awakened = true
 p.units[1].charge = 3
 p.energy = 0
 p.attackUsed = true
 var best := AI._best_attack(gs, 0)
 check(best.ok and best.unit == 1 and gs.basic_attack(0, best.unit), "AIusesawakeextraattacksharedlegalentry")
func _linked_movement() -> void:
 var gs := fixture(["yatiangou", "yanyanluo", "xiaolunan", "lianyou"])
 gs.player(0).units[0].front = 1
 Charge.summon(gs, 0, 1)
 gs._resolve_resolution_stack()
 check(gs.player(0).units[0].front == 0 and gs.player(1).avatarHp == 29 and Movement.moves(gs.player(0).units[0], gs.turn_counter) == 1, "smokesummonretreatcrowtriggersactualmove")
 gs = fixture(["yatiangou", "yanyanluo", "xiaolunan", "lianyou"])
 gs.player(0).units[0].awakened = true
 gs.player(0).units[0].front = 1
 Charge.summon(gs, 0, 1)
 gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
 gs._resolve_resolution_stack()
 check(gs.player(0).units[0].front == 0 and gs.player(1).avatarHp == 29, "serializedsummoncrowremoteattackpreservesreserve")
 gs = fixture(["yatiangou", "yanyanluo", "xiaolunan", "lianyou"])
 var crow: Dictionary = gs.player(0).units[0]
 Movement.move_to(gs, 0, 0, 1)
 gs._resolve_resolution_stack()
 gs.VerifiedRules.move_unit(gs, 1, gs.player(1).units[2])
 gs._resolve_resolution_stack()
 var enemy_crow: Dictionary = gs.player(1).units[2]
 gs.VerifiedRules.move_unit(gs, 1, enemy_crow)
 gs._resolve_resolution_stack()
 check(enemy_crow.front == 0 and Movement.moves(enemy_crow, gs.turn_counter) == 2 and crow.hp == 4, "sharedmovesbothdirectionsdealindependentprojectiles")
