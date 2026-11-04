"""Transactional, exact and idempotent native hooks. python3 integrate.py <godot-dir> [--check]."""
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]);out=pathlib.Path(__file__).parent;changes={}
def transform(path,pairs):
 p=root/path;s=changes.get(p,p.read_text())
 for old,new in pairs:
  if new in s:continue
  if s.count(old)!=1:raise RuntimeError(f'{path}: unique anchor required {old[:100]!r}; got {s.count(old)}')
  s=s.replace(old,new,1)
 changes[p]=s
transform('scripts/verified_card_rules.gd',[
 ('const BookJue := preload("res://scripts/book_jue_rules.gd")','const BookJue := preload("res://scripts/book_jue_rules.gd")\nconst SunSmoke := preload("res://scripts/sun_smoke_rules.gd")'),
 ('\tBookJue.announced(gs, frame, announced)', '\tBookJue.announced(gs, frame, announced)\n\tSunSmoke.smoke_copy(gs, frame, announced)'),
 ('\tvar entry := details.duplicate(true)','\tSunSmoke.rule_event(gs, kind, details)\n\tvar entry := details.duplicate(true)'),
 ('\tif BookJue.resolve_action(gs, p_idx, src, card, effect, target): return true','\tif SunSmoke.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true\n\tif BookJue.resolve_action(gs, p_idx, src, card, effect, target): return true'),
 ('\tif unit.get("summoned", false):\n\t\tXuenv.remove_wall(gs, p_idx, unit)','\tif unit.get("summoned", false):\n\t\tif SunSmoke.remove_clone(gs, p_idx, unit): return\n\t\tXuenv.remove_wall(gs, p_idx, unit)')])
p=root/'scripts/game_state.gd';s=p.read_text();start=s.index('func _pay_charge_cost(');end=s.index('\n\nfunc ',start)
old=s[start:end];new='''func _pay_charge_cost(p_idx: int, src: int, card: Dictionary) -> bool:
	if not card.has("chargeCost"): return true
	return VerifiedRules.SunSmoke.pay_charge(self, p_idx, src, int(card.chargeCost))'''
transform('scripts/game_state.gd',[(old,new),
 ('func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type") in ["smoke-burst", "smoke-pick"]: return VerifiedRules.SunSmoke.resolve_choice(self, p_idx, instance_id)\n'),
 ('\t_log("%s 提升至 %d 勾玉。" % [u.name, int(u.level)], TONE_SUCCESS)','\t_log("%s 提升至 %d 勾玉。" % [u.name, int(u.level)], TONE_SUCCESS)\n\tVerifiedRules.automatic_response(self, 1 - p_idx, "enemy-upgraded", u.uid, {"kind": "response-complete"})\n\t_resolve_resolution_stack()'),
 ('\tcard = VerifiedRules.BookJue.describe_card(self, p_idx, p.hand[hand_index], card)','\tcard = VerifiedRules.BookJue.describe_card(self, p_idx, p.hand[hand_index], card)\n\tcard = VerifiedRules.SunSmoke.describe_card(self, p_idx, card)'),
 ('\tif card.has("chargeCost") and int(su.get("charge", 0)) < int(card.get("chargeCost", 0)):','\tif card.has("chargeCost") and not VerifiedRules.SunSmoke.can_pay_charge(self, p_idx, src, int(card.get("chargeCost", 0))):'),
 ('\t\tVerifiedRules.Xuenv.remove_departed_walls(self)','\t\tVerifiedRules.Xuenv.remove_departed_walls(self)\n\t\tVerifiedRules.SunSmoke.remove_departed(self)'),
 ('func _resolve_frame(frame: Dictionary) -> void:\n','func _resolve_frame(frame: Dictionary) -> void:\n\tif VerifiedRules.SunSmoke.resolve_frame(self, frame): return\n'),
 ('\tunit.attackBonus = int(unit.attackBonus) + atk','\tVerifiedRules.SunSmoke.grew(self, unit, atk, hp)\n\tunit.attackBonus = int(unit.attackBonus) + atk'),
 ('func _recalc(unit: Dictionary) -> void:\n','func _recalc(unit: Dictionary) -> void:\n\tVerifiedRules.SunSmoke.refresh_clone(unit)\n'),
 (' - int(unit.get("judgeInkAttack", 0))\n\tunit.attack += VerifiedRules.Fortune.power(self, unit)',' - int(unit.get("judgeInkAttack", 0)) + int(unit.get("smokeChargePower", 0))\n\tunit.attack += VerifiedRules.Fortune.power(self, unit)'),
 ('\tVerifiedRules.BookJue.form_entered(self, p_idx, src, card)','\tVerifiedRules.BookJue.form_entered(self, p_idx, src, card)\n\tVerifiedRules.SunSmoke.form_entered(self, p_idx, src, card)'),
 ('\tVerifiedRules.Shuten.record_damage(self, p_idx, unit_index, unshielded, _src_player)','\tVerifiedRules.Shuten.record_damage(self, p_idx, unit_index, unshielded, _src_player)\n\tVerifiedRules.SunSmoke.damaged(self, p_idx, unit_index, unshielded)'),
 ('\tVerifiedRules.Bingyong.knocked_out(u)','\tVerifiedRules.Bingyong.knocked_out(u)\n\tVerifiedRules.SunSmoke.knocked_out(u)'),
 ('\t_log("%s 气绝，将在 %d 个己方回合后归队。" % [u.name, int(u.knockout)], TONE_DANGER)','\tif u.get("smokeClone", false): VerifiedRules.SunSmoke.remove_clone(self, victim, u, "分身气绝")\n\t_log("%s 气绝，将在 %d 个己方回合后归队。" % [u.name, int(u.knockout)], TONE_DANGER)'),
 ('\tVerifiedRules.BookJue.avatar_damaged(self, _src_player, source_index, p_idx, amount)','\tVerifiedRules.BookJue.avatar_damaged(self, _src_player, source_index, p_idx, amount)\n\tVerifiedRules.SunSmoke.damaged(self, p_idx, -1, amount)'),
 ('\t\tif VerifiedRules.Poison.avatar_response(self, frame, power, options): return','\t\tif VerifiedRules.SunSmoke.avatar_response(self, frame, bool(options.get("directAvatar", false))): return\n\t\tif VerifiedRules.Poison.avatar_response(self, frame, power, options): return'),
 ('\t\t\tVerifiedRules.Light.form_turn_start(self, p_idx, i)','\t\t\tVerifiedRules.Light.form_turn_start(self, p_idx, i)\n\t\t\tVerifiedRules.SunSmoke.form_turn_start(self, p_idx, i)'),
 ('\t# 回合开始能力结算后，战斗区回退准备区，最后进入抽牌阶段。','\tVerifiedRules.SunSmoke.enemy_turn_start(self, p_idx)\n\t_resolve_resolution_stack()\n\t# 回合开始能力结算后，战斗区回退准备区，最后进入抽牌阶段。')])
p=root/'scripts/game_state.gd';s=changes[p]
if '# Native charge after natural revival.' not in s:
 start=s.index('\t# 充能：回合开始 +1');end=s.index('\t# knockout countdown',start)
 s=s[:start]+s[end:]
 anchor='\t# Snapshot after natural revival;'
 if s.count(anchor)!=1:raise RuntimeError('charge begin anchor')
 s=s.replace(anchor,'\t# Native charge after natural revival.\n\tVerifiedRules.SunSmoke.begin_turn_charge(self, p_idx)\n'+anchor,1)
 changes[p]=s
transform('scripts/game_ai.gd',[
 ('static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n\tvar sun_smoke_score = _gs.VerifiedRules.SunSmoke.score_card(_gs, p_idx, card, _target)\n\tif sun_smoke_score != null: return int(sun_smoke_score)\n'),
 ('static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n','static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n\tvar sun_smoke_choice = gs.VerifiedRules.SunSmoke.ai_choice(gs, p_idx)\n\tif sun_smoke_choice != null: return bool(sun_smoke_choice)\n')])
transform('scripts/ui/battle_screen.gd',[
 ('\t\tif book_jue_choice_card != null: def = book_jue_choice_card','\t\tif book_jue_choice_card != null: def = book_jue_choice_card\n\t\tvar sun_smoke_choice_card = gs.VerifiedRules.SunSmoke.choice_card(gs, PLAYER, str(iid))\n\t\tif sun_smoke_choice_card != null: def = sun_smoke_choice_card'),
 ('\t\t\tif a.get("choice") == "book-mind":','\t\t\tif a.get("choice") == "smoke-burst": what = "爆能" if a.get("instanceId") == "smoke-burst" else "保留能量"\n\t\t\telif a.get("choice") == "smoke-pick": what = "无孔不入获得「%s」" % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")\n\t\t\telif a.get("choice") == "book-mind":')])
p=root/'content/verified_rules.json';r=json.loads(p.read_text());over=json.loads((out/'overlay.json').read_text())
for k in ['units','cards']:r[k].update(over[k])
ids={s['id'] for s in r['sources']};r['sources'] += [s for s in over['sources'] if s['id'] not in ids]
changes[p]=json.dumps(r,ensure_ascii=False,indent=2)+'\n'
# All hooks and overlay are validated before any write.
if '--check' not in sys.argv:
 for p,s in changes.items():p.write_text(s)
print('SUN_SMOKE_INTEGRATION_CHECK_OK' if '--check' in sys.argv else 'SUN_SMOKE_INTEGRATION_OK',root)
