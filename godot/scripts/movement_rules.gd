class_name MovementRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")
const Charge := preload("res://scripts/sun_smoke_rules.gd")
const CANCEL := "movement-cancel"

static func role(unit: Dictionary) -> String:
 return str(ContentLoader.runtime_unit_def(unit).get("movementRole", ""))
static func active(unit: Dictionary) -> bool:
 return int(unit.hp) > 0 and int(unit.level) >= 1 and not unit.get("baseRulesSuppressed", false)
static func power(unit: Dictionary, turn: int) -> int:
 var bonus: int = int(unit.get("charge", 0)) / 2 if unit.get("formRules", {}).get("chargePower", false) else 0
 return int(bonus)
static func zero_power(gs, unit: Dictionary) -> bool:
 return int(unit.get("movementZeroTurn", -1)) == gs.turn_counter
static func has_veil(unit: Dictionary) -> bool:
 if unit.get("randomTargetPreview",false):return false
 return int(unit.get("hp", 0)) > 0 and bool(unit.get("movementVeil", false))
static func moves(unit: Dictionary, turn: int) -> int:
 return int(unit.get("movementCount", 0)) if int(unit.get("movementCountTurn", -1)) == turn else 0
static func clear_hold(gs, unit: Dictionary) -> void:
 for side in gs.players:
  for target in side.units:
   if not target.has("movementHolders"): continue
   target.movementHolders = target.movementHolders.filter(func(h): return str(h.sourceUid) != str(unit.uid))
   if target.movementHolders.is_empty():
    target.frozen = int(target.get("movementBaseFrozen", 0))
    target.erase("movementHolders")
    target.erase("movementBaseFrozen")
    gs.VerifiedRules.event(gs, "movement-hold-released", {"uid": target.uid})
static func hold(gs, owner: int, src: int, victim: int, idx: int) -> void:
 var target: Dictionary = gs.player(victim).units[idx]
 var baseline := int(target.get("movementBaseFrozen", target.frozen))
 gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)
 if not target.has("movementHolders"): target.movementHolders = []
 target.movementBaseFrozen = baseline
 target.movementHolders.append({"sourceUid": str(gs.player(owner).units[src].uid), "sourceOwner": owner})
static func end_turn(gs, owner: int) -> void:
 for side in gs.players:
  for unit in side.units:
   if int(unit.get("movementZeroTurn", -1)) == gs.turn_counter:
    unit.erase("movementZeroTurn")
    gs._recalc(unit)
 for idx in gs.player(owner).units.size():
  var unit: Dictionary = gs.player(owner).units[idx]
  if not active(unit) or not unit.get("formRules", {}).get("crowDrain", false) or int(unit.front) != 1: continue
  var healed := 0
  for i in gs.player(1 - owner).units.size():
   if gs.winner >= 0: break
   var result: Dictionary = gs._damage_unit(1 - owner, i, 1, owner, idx)
   healed += int(result.get("damage", 0))
  gs._heal_unit(unit, healed)
static func revived(gs, owner: int, idx: int) -> void:
 gs.VerifiedRules.ApeSleeve.revived(gs,owner,idx)
 gs.VerifiedRules.RedPurple.refresh(gs)
 gs.VerifiedRules.Lantern.revived(gs,owner,idx)
 gs.VerifiedRules.Rebirth.revived(gs,owner,idx)
 gs.VerifiedRules.Samurai.revived(gs,owner,idx)
 gs.VerifiedRules.Pine.revived(gs,owner,idx)
 gs.VerifiedRules.Puppet.revived(gs,owner,idx)
 gs.VerifiedRules.House.revived(gs,owner,idx)
 gs.VerifiedRules.Doll.revived(gs,owner,idx)
 gs.VerifiedRules.TreeSakura.sync_power(gs.player(owner).units[idx])
 var unit: Dictionary = gs.player(owner).units[idx]
 if gs.VerifiedRules.MonkCleaner.role(unit) == "cleaner" and unit.awakened: unit.unyielding = true
 if ContentLoader.runtime_unit_def(unit).get("maskDivination", false) and unit.awakened: unit.swift = true
 if role(unit) == "deer": Charge.gain_charge(gs, owner, idx, 2)
static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int) -> void:
 if owner < 0 or src < 0 or amount <= 0 or owner == victim: return
 if active(gs.player(owner).units[src]) and role(gs.player(owner).units[src]) == "weasel": Charge.gain_charge(gs, owner, src, 1)
static func announced(gs, owner: int, src: int) -> void:
 var unit: Dictionary = gs.player(owner).units[src]
 if unit.has("arkHeldTarget") and unit.has("lanternStored"): return
 clear_hold(gs, unit)
static func knocked_out(gs, unit: Dictionary) -> void:
 clear_hold(gs, unit)
 unit.erase("movementZeroTurn")
 unit.erase("movementVeil")
 unit.erase("movementHolders")
 unit.erase("movementBaseFrozen")
static func moved(gs, owner: int, idx: int, previous: int) -> void:
 var unit: Dictionary = gs.player(owner).units[idx]
 if int(unit.front) == previous or not active(unit): return
 gs.VerifiedRules.event(gs, "unit-moved", {"player": owner, "uid": unit.uid, "front": int(unit.front)})
 if role(unit) != "crow": return
 if int(unit.get("movementCountTurn", -1)) != gs.turn_counter:
  unit.movementCountTurn = gs.turn_counter
  unit.movementCount = 0
 unit.movementCount = int(unit.movementCount) + 1
 gs.resolution_stack.append({"kind": "movement-crow-trigger", "playerIndex": owner, "sourceIndex": idx, "awakened": bool(unit.awakened)})
static func move_to(gs, owner: int, idx: int, front: int) -> bool:
 var unit: Dictionary = gs.player(owner).units[idx]
 if int(unit.hp) <= 0 or int(unit.front) == front: return false
 if unit.get("summoned", false):
  if unit.get("efPowderBoxSummon",false):
   gs.VerifiedRules.EssenceFeast.remove_box(gs,owner,unit)
   return true
  if unit.get("mfDoll",false):
   gs.VerifiedRules.MusicFire.remove_doll(gs,owner,unit)
   return true
  if unit.get("rtSpear",false):
   gs.VerifiedRules.RabbitTide.remove_spear(gs,owner,unit)
   return true
  if unit.get("scSummon",false):
   gs.VerifiedRules.SugarCat.remove_summon(gs,owner,unit)
   return true
  if unit.get("boxSummon",false):
   gs.VerifiedRules.BoxMaiden.remove_summon(gs,owner,unit)
   return true
  if unit.get("whaleGuardian",false):
   gs.VerifiedRules.Whale.remove_summon(gs,owner,unit)
   return true
  if unit.get("jorogumoSwarm",false):
   gs.VerifiedRules.Jorogumo.remove_summon(gs,owner,unit)
   return true
  if unit.get("dollSummon",false):
   gs.VerifiedRules.Doll.remove_summon(gs,owner,unit)
   return true
  if unit.get("houseSummon",false):
   gs.VerifiedRules.House.remove_summon(gs,owner,unit)
   return true
  if unit.get("vineSummon",false):
   gs.VerifiedRules.Vine.remove_summon(gs,owner,unit)
   return true
  if unit.get("windRaccoonClone",false):
   gs.VerifiedRules.WindRaccoon.remove_summon(gs,owner,unit)
   return true
  if unit.get("enmaGhost",false):
   gs.VerifiedRules.Enma.remove_summon(gs,owner,unit)
   return true
  if unit.get("weaverSummon",false):
   gs.VerifiedRules.Weaver.remove_summon(gs,owner,unit)
   return true
  if unit.get("pineSummon",false):
   gs.VerifiedRules.Pine.remove_summon(gs,owner,unit)
   return true
  if unit.get("paintSummon",false):
   gs.VerifiedRules.Paint.remove_summon(gs,owner,unit)
   return true
  if unit.get("bambooStone", false):
   unit.front=0
   gs.VerifiedRules.Bamboo.remove_departed(gs)
   return true
  if unit.get("tomatoFireSummon", false):
   gs.VerifiedRules.TomatoFire.remove_summon(gs, owner, unit)
   return true
  if unit.get("smokeClone", false):
   Charge.remove_clone(gs, owner, unit)
   return true
  gs.VerifiedRules.Xuenv.remove_wall(gs, owner, unit)
  return true
 if front == 1 and gs.VerifiedRules.Combat.has(unit, "remote"): return false
 if front == 1 and gs.VerifiedRules.Bingyong.replacement_blocked(gs, owner, unit): return false
 var changed: Array = []
 if front == 1:
  gs.VerifiedRules.TomatoFire.clear_summons(gs, owner)
  gs.VerifiedRules.Xuenv.clear_wall(gs, owner)
  gs.VerifiedRules.Paint.clear_summons(gs,owner)
  gs.VerifiedRules.Pine.clear_summons(gs,owner)
  gs.VerifiedRules.Enma.clear_summons(gs,owner)
  gs.VerifiedRules.Weaver.clear_summons(gs,owner)
  gs.VerifiedRules.Vine.clear_summons(gs,owner)
  gs.VerifiedRules.WindRaccoon.clear_summons(gs,owner)
  gs.VerifiedRules.BoxMaiden.clear_summons(gs,owner)
  gs.VerifiedRules.House.clear_summons(gs,owner)
  for i in gs.player(owner).units.size():
   var other: Dictionary = gs.player(owner).units[i]
   if i != idx and int(other.front) == 1:
    other.front = 0
    changed.append(i)
 var old := int(unit.front)
 unit.front = front
 # LIFO keeps displaced and entering movement abilities distinct.
 moved(gs, owner, idx, old)
 for i in changed: moved(gs, owner, int(i), 1)
 gs.VerifiedRules.Bamboo.remove_departed(gs)
 gs.VerifiedRules.SunSmoke.remove_departed(gs)
 if front == 1:
  gs._fire_hooks(owner, idx, "unit-entered-front", {})
  gs._run_form_hooks(owner, idx, "unit-entered-front", {})
  gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-entered-front", unit.uid, {"kind": "response-complete"})
 return true
static func before_attack(gs, owner: int, src: int) -> void:
 var unit: Dictionary = gs.player(owner).units[src]
 clear_hold(gs, unit)
 deer_combat(gs, owner, src)
static func deer_combat(gs, owner: int, idx: int) -> void:
 var unit: Dictionary = gs.player(owner).units[idx]
 if not active(unit): return
 match str(unit.get("formRules", {}).get("deerCombat", "")):
  "blessing":
   var pool: Array = []
   for i in gs.player(owner).units.size():
    if i != idx and active(gs.player(owner).units[i]) and Charge.has_charge(gs.player(owner).units[i]): pool.append(i)
   if not pool.is_empty(): Charge.gain_charge(gs, owner, int(pool[int(floor(gs.randf01() * pool.size()))]), 1)
  "self":
   if int(unit.get("deerSelfTurn", -1)) == gs.turn_counter: return
   unit.deerSelfTurn = gs.turn_counter
   Charge.gain_charge(gs, owner, idx, 1)
   gs._grant_unit_armor(unit, 1)
  "life":
   if Charge.pay_charge(gs, owner, idx, 1):
    var enemy: int = gs.front_index(1 - owner)
    if enemy < 0: gs._damage_avatar(1 - owner, 3, owner, idx)
    else: gs._damage_unit(1 - owner, enemy, 3, owner, idx)
static func prevents_lethal(gs, owner: int, idx: int, amount: int) -> bool:
 var unit: Dictionary = gs.player(owner).units[idx]
 if amount < int(unit.hp) or not unit.get("formRules", {}).get("weaselImmortal", false): return false
 if not Charge.pay_charge(gs, owner, idx, 3): return false
 move_to(gs, owner, idx, 0)
 gs.VerifiedRules.event(gs, "movement-lethal-prevented", {"player": owner, "uid": unit.uid})
 return true
static func extra_attack(gs, owner: int, unit: Dictionary) -> bool:
 return active(unit) and role(unit) == "weasel" and unit.awakened and int(gs.player(owner).energy) == 0 and bool(gs.player(owner).attackUsed) and Charge.can_pay_charge(gs, owner, gs._unit_index_by_uid(owner, unit.uid), 3)
static func pay_extra_attack(gs, owner: int, idx: int) -> bool:
 if not extra_attack(gs, owner, gs.player(owner).units[idx]): return false
 return Charge.pay_charge(gs, owner, idx, 3)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
 if not card.get("movementRules", false): return card
 var out := card.duplicate(true)
 var src: int = gs._source_index(owner, out)
 if src < 0: return out
 var unit: Dictionary = gs.player(owner).units[src]
 var amount := int(inst.get("movementBurst", 0))
 out.movementBurst = amount
 if out.get("movementBurstOptions", []).size() > 0:
  out.text += "\n当前：%s。" % ("普通使用" if amount == 0 else "爆能%d" % amount)
 if out.get("movementMode") == "forest-aid" and amount == 2: out.target = "auto"
 if out.get("movementMode") == "forest-force" and amount == 2: out.keywords.append("instant")
 if out.get("type") == "form" and role(unit) == "deer" and unit.awakened and int(unit.hp) <= 0:
  out.allowKnockedSource = true
  out.movementReviveForm = true
  out.text += "\n气绝使用消耗3能量并复活。"
 if out.get("movementMode") == "crow-victory":
  out.value = 2 * moves(unit, gs.turn_counter)
  out.effects[0].value = out.value
  out.text += "\n本回合移动%d次：+%d力量。" % [moves(unit, gs.turn_counter), int(out.value)]
 return out
static func can_use(gs, owner: int, card: Dictionary) -> bool:
 if not card.get("movementRules", false): return true
 var src: int = gs._source_index(owner, card)
 if src < 0: return false
 var amount := int(card.get("movementBurst", 0))
 if amount > 0 and not card.get("movementBurstOptions", []).any(func(n): return int(n) == amount): return false
 if amount > 0 and not gs.VerifiedRules.Yujiazhu.can_pay_burst(gs, owner, src, amount): return false
 if card.get("movementReviveForm", false) and not Charge.can_pay_charge(gs, owner, src, 3): return false
 return true
static func request_burst(gs, owner: int, index: int) -> bool:
 if not gs.pending_choice.is_empty() or gs.winner >= 0 or gs.current_player != owner or gs.is_upgrade_pending(owner): return false
 var card: Dictionary = gs.hand_card_def(owner, index)
 if card.get("movementBurstOptions", []).is_empty(): return false
 var src: int = gs._source_index(owner, card)
 if src < 0: return false
 var ids: Array = ["burst:0"]
 for amount in card.movementBurstOptions:
  if gs.VerifiedRules.Yujiazhu.can_pay_burst(gs, owner, src, int(amount)): ids.append("burst:%d" % int(amount))
 ids.append(CANCEL)
 gs.pending_choice = {"type": "movement-burst", "playerIndex": owner, "instanceIds": ids, "handIid": str(gs.card_instance(owner, index).instanceId), "card": card.duplicate(true), "heading": "爆 能", "title": "选择普通使用或爆能", "hint": "选择后再指定目标；此时不会支付鬼火或能量。"}
 gs.phase = "choice"
 gs.state_changed.emit()
 return true
static func ready_hand(gs, owner: int) -> int:
 var index := int(gs.player(owner).get("movementReadyHand", -1))
 gs.player(owner).erase("movementReadyHand")
 return index
static func choice_card(gs, owner: int, iid: String) -> Variant:
 if gs.pending_choice.get("type") != "movement-burst": return null
 if iid == CANCEL: return {"id": CANCEL, "unitId": "", "name": "取消", "type": "spell", "level": 1, "cost": 0, "text": "返回手牌，不支付费用。"}
 var card: Dictionary = gs.pending_choice.card.duplicate(true)
 var amount := int(iid.trim_prefix("burst:"))
 card.name = "普通使用" if amount == 0 else "爆能%d" % amount
 card.currentCardStats = card.name
 card.text = "不消耗能量。" if amount == 0 else "使用本牌并选择爆能%d。" % amount
 if amount>0:
  var src:int=gs._source_index(owner,card)
  var q:Dictionary=gs.VerifiedRules.Yujiazhu.quote_burst(gs,owner,src,amount)
  if q.free:
   card.currentCardStats="爆能%d · 日和坊免支付"%amount
   card.text="日和坊使本次爆能免支付；效果仍按爆能%d结算。"%amount
  elif int(q.discount)>0:
   card.currentCardStats="爆能%d · 支付%d能量"%[amount,int(q.amount)]
   card.text="选择后支付%d能量；效果仍按爆能%d结算。"%[int(q.amount),amount]
 return card
static func resolve_choice(gs, owner: int, iid: String) -> bool:
 var choice: Dictionary = gs.pending_choice
 if choice.get("type") != "movement-burst" or int(choice.playerIndex) != owner or not choice.instanceIds.has(iid): return false
 if iid != CANCEL:
  var index := -1
  for i in gs.playable_card_count(owner):
   if str(gs.card_instance(owner, i).instanceId) == str(choice.handIid): index = i
  if index < 0: return false
  var src: int = gs._source_index(owner, choice.card)
  var amount := int(iid.trim_prefix("burst:"))
  if amount > 0 and not gs.VerifiedRules.Yujiazhu.can_pay_burst(gs, owner, src, amount): return false
  gs.card_instance(owner, index).movementBurst = amount
  gs.player(owner).movementReadyHand = index
 gs._record("resolve_divination_choice", {"instanceId": iid, "choice": "movement-burst"}, owner)
 gs.pending_choice = {}
 gs.phase = "main"
 gs.state_changed.emit()
 return true
static func ai_prepare(gs, owner: int) -> void:
 for index in gs.playable_card_count(owner):
  var inst: Dictionary = gs.card_instance(owner, index)
  var card: Dictionary = ContentLoader.card_def(str(inst.definitionId))
  if not card.get("movementRules", false) or card.get("movementBurstOptions", []).is_empty(): continue
  var src: int = gs._source_index(owner, card)
  if src < 0: continue
  var mode := 0
  for amount in card.movementBurstOptions:
   if gs.VerifiedRules.Yujiazhu.can_pay_burst(gs, owner, src, int(amount)): mode = int(amount)
  inst.movementBurst = mode
static func resolve_frame(gs, frame: Dictionary) -> bool:
 var kind := str(frame.get("kind", ""))
 if kind not in ["movement-crow-trigger", "movement-move", "movement-combat-entry", "movement-justice-attack", "movement-draw"]: return false
 var owner := int(frame.playerIndex)
 var src := int(frame.sourceIndex)
 var unit: Dictionary = gs.player(owner).units[src]
 match kind:
  "movement-combat-entry":
   frame.kind = "combat-entered"
   if frame.fromReserve and gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-entered-front", unit.uid, frame): return true
   gs._resolve_combat_entered(frame)
  "movement-crow-trigger":
   if not active(unit) or role(unit) != "crow": return true
   if frame.awakened: gs._resolve_combat(owner, src, 0, false, true, false, false, null, false, {"movementRemote": true})
   else:
    var enemy: int = gs.front_index(1 - owner)
    if enemy < 0: gs.VerifiedRules.base_damage_avatar(gs,owner,src,1-owner,1)
    else: gs.VerifiedRules.base_damage_unit(gs,owner,src,1-owner,enemy,1)
  "movement-move":
   if int(unit.hp) <= 0: return true
   if frame.get("draw", false):
    gs.resolution_stack.append({"kind": "movement-draw", "playerIndex": owner, "sourceIndex": src})
   if int(frame.get("remaining", 1)) > 1:
    var next := frame.duplicate(true)
    next.remaining = int(frame.remaining) - 1
    gs.resolution_stack.append(next)
   move_to(gs, owner, src, 1 - int(unit.front))
  "movement-draw": gs._draw(owner, 1)
  "movement-justice-attack":
   if int(unit.hp) > 0: gs._resolve_combat(owner, src, int(frame.get("bonus", 0)), false, false, false, false, null, false, frame.get("options", {}))
 return true
static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, hit: Dictionary, options: Dictionary) -> void:
 if int(hit.get("damage", 0)) <= 0: return
 var mode := str(options.get("movementCombat", ""))
 if mode == "spear": gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, 2)
 elif mode == "club":
  gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)
  if idx >= 0:
   gs.player(victim).units[idx].movementZeroTurn = gs.turn_counter
   gs._recalc(gs.player(victim).units[idx])
static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
 if not options.has("movementChain") or not active(gs.player(owner).units[src]): return
 var chain: Array = options.movementChain.duplicate()
 chain.reverse()
 for id in chain:
  var card: Dictionary = ContentLoader.card_def(str(id)).duplicate(true)
  card.movementBurst = 0
  gs._push_card_frames(owner, str(id), null, card, src, 0, true)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
 var mode := str(card.get("movementMode", ""))
 var action := str(effect.get("action", ""))
 if not action.begins_with("movement-"): return false
 var unit: Dictionary = gs.player(owner).units[src]
 var amount := int(card.get("movementBurst", 0))
 if amount > 0 and not gs.VerifiedRules.Yujiazhu.pay_burst(gs, owner, src, amount): return true
 if amount > 0: gs.VerifiedRules.Whale.burst(gs,owner,src,amount)
 match action:
  "movement-form":
   if card.get("movementReviveForm", false):
    if not Charge.pay_charge(gs, owner, src, 3): return true
    gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
   gs._apply_form(owner, src, card, card.value)
  "movement-deer-awaken":
   var dead := int(unit.hp) <= 0
   gs._awaken(owner, src, card, card.value)
   if dead: gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
  "movement-awaken": gs._awaken(owner, src, card, card.value)
  "movement-blessing":
   var pool: Array = gs.player(owner).units.filter(func(u): return int(u.hp) > 0) if amount == 2 else [target]
   for u in pool:
    if u.is_empty(): continue
    gs._grow_unit(u, 1, 1)
    gs._grant_unit_armor(u, 1)
  "movement-forest-force":
   for victim in 2:
    var idx: int = gs._unit_index_by_uid(victim, target_id)
    if idx >= 0:
     gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)
     gs._damage_unit(victim, idx, 3, owner, src)
  "movement-veil":
   if not target.is_empty(): target.movementVeil = true
  "movement-cooperate":
   Charge.gain_charge(gs, owner, src, 1)
   gs.player(owner).deck.append({"instanceId": "%s-move%d" % [gs.player(owner).id, gs.next_card_id], "definitionId": str(card.id)})
   gs.next_card_id += 1
   gs._shuffle(gs.player(owner).deck)
   gs._draw(owner, 1)
  "movement-crow-move":
   gs.resolution_stack.append({"kind": "movement-move", "playerIndex": owner, "sourceIndex": src, "remaining": int(effect.get("value", 1)), "draw": mode == "crow-wind"})
  "movement-crow-dodge":
   var combat_id := int(gs._card_effect_context.get("combatResponseId", -1))
   for pending in gs.resolution_stack:
    if int(pending.get("combatId", -2)) == combat_id: pending.movementCancelled = true
   gs.resolution_stack.append({"kind": "movement-move", "playerIndex": owner, "sourceIndex": src, "remaining": 2})
  "movement-crow-feather":
   var idx: int = gs._unit_index_by_uid(1 - owner, target_id)
   if idx >= 0:
    gs.resolution_stack.append({"kind": "movement-move", "playerIndex": owner, "sourceIndex": src, "remaining": 1})
    move_to(gs, 1 - owner, idx, 1)
    gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx, 1, owner)
  "movement-crow-hold":
   var idx: int = gs._unit_index_by_uid(1 - owner, target_id)
   if idx >= 0: hold(gs, owner, src, 1 - owner, idx)
  "movement-combat":
   var played := card.duplicate(true)
   var options: Dictionary = played.get("combatOption", {}).duplicate(true)
   var bonus := int(played.value)
   if mode == "weasel-redirect":
    options.movementRedirect = true
    options.immuneCombat = true
   if mode == "axe" and amount >= 3: bonus += 3
   if mode == "spear": options.movementChain = ["c13301"] if amount >= 4 else []
   if mode == "club": options.movementChain = ["c13304", "c13301"] if amount >= 7 else (["c13304"] if amount >= 3 else [])
   if mode == "deer-collision":
    bonus += (1 if amount >= 2 else 0) + (1 if amount >= 4 else 0) + (1 if amount >= 8 else 0)
    options.lifeSteal = amount >= 2
    options.immuneCombat = amount >= 4
    if amount >= 8: played.keywords.append("combo")
   if mode == "crow-justice":
    var front: int = gs.front_index(owner)
    options.combatCard = played
    gs._grant_unit_armor(unit, int(options.get("shield", 0)))
    gs.resolution_stack.append({"kind": "movement-justice-attack", "playerIndex": owner, "sourceIndex": src, "bonus": bonus, "options": options})
    if front >= 0 and front != src: gs._resolve_combat(owner, front, 0, false, false, false, false)
   else:
    played.combatOption = options
    gs._resolve_action(owner, src, played, {"action": "assault", "value": bonus, "target": "source"}, target_id, target)
  _: return false
 return true
static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
 if not card.get("movementRules", false): return null
 var score := 55 + int(card.get("movementBurst", 0)) * 2
 var src: int = gs._source_index(owner, card)
 if src < 0: return -100
 if card.get("movementReviveForm", false): return 90
 if card.get("type") == "awakening": return 65 if not gs.player(owner).units[src].awakened else 5
 if card.get("movementMode") in ["forest-force", "crow-feather", "crow-hold"]:
  if gs._unit_index_by_uid(owner, target_id) >= 0: return -100
  var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
  score += int(target.get("attack", 0))
 return score

static func redirect_target(gs, owner: int, original: int, exclude_original: bool = true) -> int:
 var pool: Array = []
 for idx in gs.player(1 - owner).units.size():
  if (not exclude_original or idx != original) and int(gs.player(1 - owner).units[idx].hp) > 0: pool.append(idx)
 if not exclude_original or original >= 0: pool.append(-1)
 if pool.is_empty(): return original
 return int(pool[int(floor(gs.randf01() * pool.size()))])
static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
 if card.get("movementMode") != "weasel-redirect": return false
 for frame in gs.resolution_stack:
  if frame.get("kind") != "combat-hit" or int(frame.get("combatId", -1)) != combat_id: continue
  var target: int = redirect_target(gs, owner, int(frame.sourceIndex), int(frame.playerIndex) != owner)
  frame.movementCounterTarget = target
  frame.movementCounterVictim = 1 - owner
  frame.defenderImmuneCombat = true
  frame.defenderBonus = int(frame.get("defenderBonus", 0)) + int(card.value)
  frame.defenderCombatCard = card.duplicate(true)
  gs._grant_unit_armor(gs.player(owner).units[src], int(card.get("combatOption", {}).get("shield", 0)))
  gs.VerifiedRules.event(gs, "movement-redirect", {"player": owner, "victimPlayer": 1-owner, "target": target, "combatId": combat_id})
  return true
 return true
static func counterstrike(gs, frame: Dictionary, amount: int, options: Dictionary) -> Dictionary:
 var attacker_owner := int(frame.playerIndex)
 var owner := int(frame.options.get("combatVictim",1-attacker_owner))
 var victim := int(frame.get("movementCounterVictim", attacker_owner))
 var src := int(frame.defenderIndex)
 var target := int(frame.get("movementCounterTarget", frame.sourceIndex))
 if target >= 0 and int(gs.player(victim).units[target].hp) <= 0: return {"damage": 0, "knocked": false, "dealt": 0}
 var redirected := frame.has("movementCounterTarget")
 var hit: Dictionary = gs.VerifiedRules.Combat.strike(gs, owner, src, victim, target, amount, options, bool(frame.get("defenderPierce", false)), false if redirected else bool(frame.options.get("immuneCombat", false)))
 gs._record_combat_strike(owner, src, victim, target, hit, int(frame.get("movementVisualStep", 0)), frame.get("defenderCombatCard", {}))
 return hit
static func ai_choice(gs, owner: int) -> bool:
 if gs.pending_choice.get("type") != "movement-burst": return false
 var ids: Array = gs.pending_choice.instanceIds
 var selected := str(ids[maxi(0, ids.size() - 2)])
 if not resolve_choice(gs, owner, selected): return false
 var index := ready_hand(gs, owner)
 if index < 0: return true
 var card: Dictionary = gs.hand_card_def(owner, index)
 var targets: Array = [null] if card.get("target") == "auto" else gs.valid_targets(owner, card)
 for target in targets:
  if gs.can_play_card(owner, index, target).ok: return gs.play_card(owner, index, target)
 return true
static func has_playable_burst(gs, owner: int, index: int) -> bool:
 var inst: Dictionary = gs.card_instance(owner, index)
 if inst.is_empty(): return false
 var card: Dictionary = ContentLoader.card_def(str(inst.definitionId))
 if card.get("movementBurstOptions", []).is_empty(): return false
 var previous = inst.get("movementBurst", null)
 var legal := false
 for amount in [0] + card.movementBurstOptions:
  inst.movementBurst = int(amount)
  var view: Dictionary = gs.hand_card_def(owner, index)
  var targets: Array = [null] if view.get("target") == "auto" else gs.valid_targets(owner, view)
  if targets.any(func(t): return gs.can_play_card(owner, index, t).ok): legal = true
 if previous == null: inst.erase("movementBurst")
 else: inst.movementBurst = previous
 return legal
