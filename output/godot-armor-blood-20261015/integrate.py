from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
def edit(name, replacements):
 p=root/name;s=p.read_text()
 for old,new in replacements:
  assert s.count(old)==1,(name,old[:100],s.count(old))
  s=s.replace(old,new)
 p.write_text(s)
edit('godot/scripts/verified_card_rules.gd',[
 ('const FoxSuzuka := preload("res://scripts/fox_suzuka_rules.gd")','const FoxSuzuka := preload("res://scripts/fox_suzuka_rules.gd")\nconst ArmorBlood := preload("res://scripts/armor_blood_rules.gd")'),
 ('\tif TomatoFire.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true','\tif ArmorBlood.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true\n\tif TomatoFire.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true'),
 ('static func end_turn(gs, p_idx: int) -> void:\n','static func end_turn(gs, p_idx: int) -> void:\n\tArmorBlood.end_turn(gs)\n'),
 ('["source-attacked", "front-attacked", "other-ally-attacked"]','["source-attacked", "front-attacked", "other-ally-attacked", "ally-attacked"]')])
edit('godot/scripts/game_state.gd',[
 ('\treturn VerifiedRules.FoxSuzuka.describe_card(self, p_idx, card)','\tcard = VerifiedRules.ArmorBlood.describe_card(self, p_idx, p.hand[hand_index], card)\n\treturn VerifiedRules.FoxSuzuka.describe_card(self, p_idx, card)'),
 ('\tout = out.filter(func(uid): return not _unit_by_uid(_all_units(), uid).get("removed", false))','\tif card.get("whaleShield", false):\n\t\tvar src := _source_index(p_idx, card)\n\t\tif src >= 0: out.erase(own.units[src].uid)\n\tout = out.filter(func(uid): return not _unit_by_uid(_all_units(), uid).get("removed", false))'),
 ('\tunit.attack += VerifiedRules.Fortune.power(self, unit)','\tunit.attack += VerifiedRules.ArmorBlood.armor_power(self, unit)\n\tunit.attack += VerifiedRules.Fortune.power(self, unit)'),
 ('\tVerifiedRules.Light.form_entered(self, p_idx, src, card)','\tVerifiedRules.Light.form_entered(self, p_idx, src, card)\n\tVerifiedRules.ArmorBlood.form_entered(self, p_idx, src, card)'),
 ('"uid": "realm-%s-%d" % [p.id, p.realms.size()],','"uid": "realm-%s-%d" % [p.id, next_card_id],\n\t\t"nativeRealm": str(realm.get("nativeRealm", "")),\n\t\t"sourceUnit": str(card.get("unitId", "")), '),
 ('\t_log("%s 部署幻境「%s」。" % [p.name, card.get("name", "?")], TONE_CARD)','\tnext_card_id += 1\n\t_log("%s 部署幻境「%s」。" % [p.name, card.get("name", "?")], TONE_CARD)'),
 ('\tVerifiedRules.Light.avatar_healed(self, p_idx, healed)','\tVerifiedRules.ArmorBlood.avatar_healed(self, p_idx, healed)\n\tVerifiedRules.Light.avatar_healed(self, p_idx, healed)'),
 ('\tif cancelled > 0: VerifiedRules.Poison.refresh_all(self)\n\treturn gained','\tif cancelled > 0: VerifiedRules.Poison.refresh_all(self)\n\t_recalc(unit)\n\treturn gained'),
 ('combat: bool = false, knockout_extra: int = -1) -> Dictionary:', 'combat: bool = false, knockout_extra: int = -1, transfer_pending: bool = false) -> Dictionary:'),
 ('\tif VerifiedRules.Poison.convert_damage(self, _src_player, source_index, p_idx, unit_index, amount):','\ttransfer_pending = VerifiedRules.ArmorBlood.take_transfer(u) or transfer_pending\n\tif VerifiedRules.Poison.convert_damage(self, _src_player, source_index, p_idx, unit_index, amount):'),
 ('\t_resolve_damage_response(p_idx, unit_index)\n','\t_resolve_damage_response(p_idx, unit_index)\n\ttransfer_pending = VerifiedRules.ArmorBlood.take_transfer(u) or transfer_pending\n'),
 ('\tvar unshielded := dmg - absorbed\n','\t_recalc(u)\n\tvar unshielded := dmg - absorbed\n\tif transfer_pending: return VerifiedRules.ArmorBlood.transfer(self, p_idx, u, unshielded, _src_player, source_index)\n'),
 ('\tVerifiedRules.Xuenv.damage_dealt(self, _src_player, source_index, p_idx, unit_index, unshielded, combat)','\tVerifiedRules.ArmorBlood.damaged(self, p_idx, unit_index, unshielded)\n\tVerifiedRules.Xuenv.damage_dealt(self, _src_player, source_index, p_idx, unit_index, unshielded, combat)'),
 ('\t_record_spell_damage(p_idx, str(u.uid), taken, taken == 0)','\t_record_spell_damage(p_idx, str(u.uid), taken, taken == 0)\n\tif not combat: VerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, unshielded)'),
 ('\tVerifiedRules.Movement.knocked_out(self, u)','\tVerifiedRules.ArmorBlood.knocked_out(u)\n\tVerifiedRules.Movement.knocked_out(self, u)'),
 ('\tvar actual_loss := mini(int(p.avatarHp), amount)\n\tp.avatarHp = maxi(0, int(p.avatarHp) - amount)\n\t# Verified illusion durability follows damage to its owner as on the card.\n\tfor realm in p.realms.duplicate():\n\t\tif realm.get("avatarLinked", false):\n\t\t\trealm.hp = maxi(0, int(realm.hp) - amount)\n\t\t\tif int(realm.hp) == 0:\n\t\t\t\tp.realms.erase(realm)\n\t\t\t\t_log("幻境「%s」破碎。" % realm.name, TONE_DANGER)', '\tvar floor_hp := 1 if VerifiedRules.ArmorBlood.protects_avatar(self, p_idx) else 0\n\tvar actual_loss := mini(maxi(0, int(p.avatarHp) - floor_hp), amount)\n\tp.avatarHp = maxi(floor_hp, int(p.avatarHp) - amount)\n\tVerifiedRules.ArmorBlood.damage_realm(self, p_idx, amount)'),
 ('\t_check_winner()\n\treturn amount','\t_check_winner()\n\tVerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, amount)\n\treturn amount'),
 ('\t\t\tunit.shieldExpires = 0\n\tVerifiedRules.Poison.turn_start(self, p_idx)','\t\t\tunit.shieldExpires = 0\n\t\t_recalc(unit)\n\tVerifiedRules.Poison.turn_start(self, p_idx)'),
 ('\t\t\t\tVerifiedRules.FoxSuzuka.turn_start(self, p_idx, i)','\t\t\t\tVerifiedRules.FoxSuzuka.turn_start(self, p_idx, i)\n\t\t\t\tVerifiedRules.ArmorBlood.turn_start(self, p_idx, i)'),
 ('\t\t\tVerifiedRules.SunSmoke.form_turn_start(self, p_idx, i)','\t\t\tVerifiedRules.SunSmoke.form_turn_start(self, p_idx, i)\n\t\t\tVerifiedRules.ArmorBlood.form_turn_start(self, p_idx, i)'),
 ('\t\tif realm.get("trigger") == "hand-card-used":','\t\tif realm.get("trigger") in ["hand-card-used", "native-continuous"]:'),
 ('\t\td_options.merge(VerifiedRules.Xuenv.combat_traits(self, victim, idx))','\t\td_options.merge(VerifiedRules.Xuenv.combat_traits(self, victim, idx))\n\t\td_options.merge(VerifiedRules.ArmorBlood.traits(self, victim, idx))')])
edit('godot/scripts/combat_keyword_rules.gd',[
 ('\tunit.shieldExpires = 0\n\tif barrier:', '\tunit.shieldExpires = 0\n\tgs._recalc(unit)\n\tif barrier:'),
 ('\tvar lethal: bool = options.get("lethal", false)', '\toptions = options.duplicate(true)\n\tif not options.has("bloodLifeSteal"): options.merge(gs.VerifiedRules.ArmorBlood.traits(gs, owner, src))\n\tvar lethal: bool = options.get("lethal", false)'),
 ('if pierce and idx >= 0 and amount > 0:', 'if pierce and idx >= 0 and amount > 0 and not gs.player(victim).units[idx].get("bloodTransfer", false):'),
 ('\tgs.VerifiedRules.ArmorBreak.after_combat_damage(gs, owner, src, victim, idx, result, options)','\tgs.VerifiedRules.ArmorBreak.after_combat_damage(gs, owner, src, victim, idx, result, options)\n\tgs.VerifiedRules.ArmorBlood.combat_dealt(gs, owner, result, options)')])
edit('godot/scripts/armor_break_rules.gd',[
 ('\tif cancelled > 0: gs.VerifiedRules.event(gs, "armor-cancelled",','\tif idx >= 0: gs._recalc(gs.player(owner).units[idx])\n\tif cancelled > 0: gs.VerifiedRules.event(gs, "armor-cancelled",'),
 ('\tif power <= 0: return empty\n\tif convert:', '\tif power <= 0: return empty\n\tvar transfer_pending: bool = idx >= 0 and gs.VerifiedRules.ArmorBlood.take_transfer(gs.player(owner).units[idx])\n\tif convert:'),
 ('gs._damage_unit(owner, idx, power, source_owner, src, true)', 'gs._damage_unit(owner, idx, power, source_owner, src, true, -1, transfer_pending)'),
 ('gs._damage_unit(owner, idx, power, source_owner, src, true, knockout_extra)', 'gs._damage_unit(owner, idx, power, source_owner, src, true, knockout_extra, transfer_pending)'),
 ('\tif dealt <= 0: return\n\tif options.get("lifeSteal", false) and gs.winner < 0:\n\t\tgs._heal_avatar(owner, dealt)', '\tvar leech := int(result.get("transferredDealt", dealt))\n\tif leech > 0 and options.get("lifeSteal", false) and gs.winner < 0:\n\t\tgs.VerifiedRules.ArmorBlood.heal(gs, owner, leech)\n\tif dealt <= 0: return')])
edit('godot/scripts/game_ai.gd',[
 ('static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n', 'static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n\tvar armor_blood_score = _gs.VerifiedRules.ArmorBlood.score_card(_gs, p_idx, card, _target)\n\tif armor_blood_score != null: return int(armor_blood_score)\n')])
