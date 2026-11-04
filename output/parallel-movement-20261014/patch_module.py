from pathlib import Path
p=Path('godot/scripts/movement_rules.gd');s=p.read_text()
s=s.replace('var bonus := int(unit.get("charge", 0)) / 2 if','var bonus: int = int(unit.get("charge", 0)) / 2 if')
s=s.replace(' return 0 if int(unit.get("movementZeroTurn", -1)) == turn else int(bonus)',' return int(bonus)\nstatic func zero_power(gs, unit: Dictionary) -> bool:\n return int(unit.get("movementZeroTurn", -1)) == gs.turn_counter\nstatic func has_veil(unit: Dictionary) -> bool:\n return int(unit.hp) > 0 and bool(unit.get("movementVeil", false))')
s=s.replace(' if not target.has("movementHolders"):\n  target.movementBaseFrozen = int(target.frozen)\n  target.movementHolders = []\n gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)\n target.movementHolders.append', ' var baseline := int(target.get("movementBaseFrozen", target.frozen))\n gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)\n if not target.has("movementHolders"): target.movementHolders = []\n target.movementBaseFrozen = baseline\n target.movementHolders.append')
s=s.replace(' unit.erase("movementZeroTurn")\n unit.erase("movementHolders")',' unit.erase("movementZeroTurn")\n unit.erase("movementVeil")\n unit.erase("movementHolders")')
s=s.replace(' if not gs.pending_choice.is_empty(): return false\n var card: Dictionary = gs.hand_card_def(owner, index)',' if not gs.pending_choice.is_empty() or gs.winner >= 0 or gs.current_player != owner or gs.is_upgrade_pending(owner): return false\n var card: Dictionary = gs.hand_card_def(owner, index)')
s=s.replace('   if int(frame.get("remaining", 1)) > 1:', '   if frame.get("draw", false):\n    gs.resolution_stack.append({"kind": "movement-draw", "playerIndex": owner, "sourceIndex": src})\n   if int(frame.get("remaining", 1)) > 1:')
s=s.replace('"movement-justice-attack"]', '"movement-justice-attack", "movement-draw"]')
s=s.replace('  "movement-justice-attack":', '  "movement-draw": gs._draw(owner, 1)\n  "movement-justice-attack":')
s=s.replace(' if int(hit.get("damage", 0)) <= 0: return\n var mode', ' if int(hit.get("damage", 0)) <= 0: return\n if options.get("lifeSteal", false): gs._heal_unit(gs.player(owner).units[src], int(hit.damage))\n var mode')
s=s.replace(' for id in options.movementChain.duplicate().reversed():', ' var chain: Array = options.movementChain.duplicate()\n chain.reverse()\n for id in chain:')
s=s.replace('"remaining": int(effect.get("value", 1))})', '"remaining": int(effect.get("value", 1)), "draw": mode == "crow-wind"})')
s=s.replace('    gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx, 1, owner)\n    gs.resolution_stack.append', '    gs.resolution_stack.append')
s=s.replace('    move_to(gs, 1 - owner, idx, 1)\n  "movement-crow-hold":', '    move_to(gs, 1 - owner, idx, 1)\n    gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx, 1, owner)\n  "movement-crow-hold":')
s=s.replace('   if mode == "axe"', '   if mode == "weasel-redirect":\n    options.movementRedirect = true\n    options.immuneCombat = true\n   if mode == "axe"')
s=s.replace('    options.combatCard = played\n    gs.resolution_stack', '    options.combatCard = played\n    gs._grant_unit_armor(unit, int(options.get("shield", 0)))\n    gs.resolution_stack')
s=s.replace(' static',' static')
s+='''
static func redirect_target(gs, owner: int, original: int) -> int:
 var pool: Array = []
 for idx in gs.player(1 - owner).units.size():
  if idx != original and int(gs.player(1 - owner).units[idx].hp) > 0: pool.append(idx)
 if original >= 0: pool.append(-1)
 if pool.is_empty(): return original
 return int(pool[int(floor(gs.randf01() * pool.size()))])
static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
 if card.get("movementMode") != "weasel-redirect": return false
 for frame in gs.resolution_stack:
  if frame.get("kind") != "combat-hit" or int(frame.get("combatId", -1)) != combat_id: continue
  var target: int = redirect_target(gs, owner, int(frame.sourceIndex))
  frame.movementCounterTarget = target
  frame.defenderImmuneCombat = true
  frame.defenderBonus = int(frame.get("defenderBonus", 0)) + int(card.value)
  frame.defenderCombatCard = card.duplicate(true)
  gs._grant_unit_armor(gs.player(owner).units[src], int(card.get("combatOption", {}).get("shield", 0)))
  gs.VerifiedRules.event(gs, "movement-redirect", {"player": owner, "target": target, "combatId": combat_id})
  return true
 return true
static func counterstrike(gs, frame: Dictionary, amount: int, options: Dictionary) -> Dictionary:
 var owner := 1 - int(frame.playerIndex)
 var src := int(frame.defenderIndex)
 var target := int(frame.get("movementCounterTarget", frame.sourceIndex))
 if target >= 0 and int(gs.player(1 - owner).units[target].hp) <= 0: return {"damage": 0, "knocked": false, "dealt": 0}
 var redirected := frame.has("movementCounterTarget")
 var hit: Dictionary = gs.VerifiedRules.Combat.strike(gs, owner, src, 1 - owner, target, amount, options, bool(frame.get("defenderPierce", false)), false if redirected else bool(frame.options.get("immuneCombat", false)))
 gs._record_combat_strike(owner, src, 1 - owner, target, hit, int(frame.get("movementVisualStep", 0)), frame.get("defenderCombatCard", {}))
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
'''
p.write_text(s)
