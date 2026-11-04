"""Apply reviewed light/healer integration to an explicit Godot checkout only.
Usage: python3 .../integrate.py /absolute/path/to/godot
Writes no credentials and never replaces unrelated complete files.
"""
import json,sys
from pathlib import Path
root=Path(sys.argv[1]).resolve()
contents={}
def edit(rel,old,new,count=1):
 p=root/rel;s=contents.get(rel,p.read_text());n=s.count(old)
 if n!=count: raise SystemExit(f'{rel}: expected {count} occurrences, got {n}: {old[:80]!r}')
 contents[rel]=s.replace(old,new,count)
def after(rel,old,new):edit(rel,old,old+new)
def before(rel,old,new):edit(rel,old,new+old)
f='scripts/verified_card_rules.gd'
after(f,'const Tide := preload("res://scripts/haifangzhu_rules.gd")','\nconst Light := preload("res://scripts/light_healer_rules.gd")')
after(f,'static func card_started(gs, p_idx: int, src: int, card: Dictionary, automatic: bool) -> void:\n','\tLight.card_started(gs, p_idx, card)\n')
after(f,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n','\tif Light.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true\n')
after(f,'static func end_turn(gs, p_idx: int) -> void:\n','\tLight.end_turn(gs, p_idx)\n')
f='scripts/game_state.gd'
after(f,'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n','\tif pending_choice.get("type") == "lantern-choice": return VerifiedRules.Light.resolve_choice(self, p_idx, instance_id)\n')
after(f,'\tvar threshold := int(cfg.get("threshold", 4))\n','\treturn VerifiedRules.Light.roll(self, p_idx, threshold, sides)\n')
# Remove replaced old fortune path, avoiding unreachable-code warnings.
edit(f,'\tvar roll := int(floor(randf01() * float(sides))) + 1\n\tvar success := roll >= threshold\n\tkw_usage(p_idx, "fortune")["last"] = {"roll": roll, "sides": sides, "threshold": threshold, "success": success}\n\t_log("%s 的运势骰子为 %d/%d%s" % [player(p_idx).name, roll, sides, "，运势成功。" if success else "，未达成。"], TONE_CARD if success else TONE_NEUTRAL)\n\treturn success\n','')
after(f,'\tcard = VerifiedRules.Tide.describe_card(self, p_idx, card)\n','\tcard = VerifiedRules.Light.describe_card(self, p_idx, p.hand[hand_index], card)\n')
after(f,'func valid_targets(p_idx: int, card: Dictionary) -> Array:\n','\tvar light_targets = VerifiedRules.Light.targets(self, p_idx, card)\n\tif light_targets != null: return light_targets\n')
before(f,'\tif not VerifiedRules.Panguan.can_use(self, p_idx, card):\n','\tif not VerifiedRules.Light.can_use(self, p_idx, card):\n\t\treturn {"ok": false, "reason": "百闻一得需要弃掉一张明灯。"}\n')
after(f,'\tVerifiedRules.Bingyong.form_entered(self, p_idx, src, card)\n','\tVerifiedRules.Light.form_entered(self, p_idx, src, card)\n')
after(f,'\t_log("%s 的核心恢复 %d 点生命。" % [p.name, healed], TONE_SUCCESS)\n','\tVerifiedRules.Light.avatar_healed(self, p_idx, healed)\n')
before(f,'\tVerifiedRules.Firefly.knocked_out(u)\n','\tvar light_saved := VerifiedRules.Light.knockout_snapshot(u)\n')
if '\t\tVerifiedRules.Panguan.destroyed(self, source_owner, source_index, victim, u)\n' in contents[f]:
 after(f,'\t\tVerifiedRules.Panguan.destroyed(self, source_owner, source_index, victim, u)\n','\t\tVerifiedRules.Light.after_knockout(self, victim, _unit_index_by_uid(victim, u.uid), light_saved)\n')
else:
 after(f,'\tif victim >= 0: VerifiedRules.Panguan.destroyed(self, source_owner, source_index, victim, u)\n','\tif victim >= 0: VerifiedRules.Light.after_knockout(self, victim, _unit_index_by_uid(victim, u.uid), light_saved)\n')
after(f,'func _damage_avatar(p_idx: int, amount: int, _src_player: int = -1, source_index: int = -1) -> int:\n\tvar p := player(p_idx)\n\tif amount <= 0 or winner >= 0:\n\t\treturn 0\n','\tvar pending_armor := 0 if _src_player >= 0 and source_index >= 0 and VerifiedRules.Combat.has(player(_src_player).units[source_index], "penetration") else int(p.avatarArmor)\n\tif VerifiedRules.Light.prevents_avatar_damage(self, p_idx, maxi(0, amount + int(p.avatarArmorBreak) - pending_armor)):\n\t\t_record_spell_damage(p_idx, "", 0, true)\n\t\treturn 0\n')
after(f,'\tvar actual_loss := mini(int(p.avatarHp), amount)\n','\tVerifiedRules.Light.avatar_damaged(self, p_idx, _src_player, amount)\n')
after(f,'\tVerifiedRules.SnowCrane.before_attack(self, p_idx, unit_index)\n','\tvar light_zero := VerifiedRules.Light.before_attack(self, p_idx, unit_index)\n')
after(f,'\tvar power := base_power * 2 if crit else base_power\n','\tif light_zero: power = 0\n\toptions.lightZeroAttack = light_zero\n')
after(f,'\tVerifiedRules.SnowCrane.after_attack(self, owner, src)\n','\tVerifiedRules.Light.after_attack(self, owner, src)\n')
after(f,'\t\tvar power := maxi(0, int(frame.power) + (int(attacker.attack) - int(frame.get("attackSnapshot", attacker.attack))) * int(frame.get("powerMultiplier", 1)))\n','\t\tif options.get("lightZeroAttack", false): power = 0\n')
edit(f,'\tp.energy = int(p.maxEnergy)\n','\tVerifiedRules.Light.refresh_fire(self, p_idx)\n\tVerifiedRules.Light.turn_start(self, p_idx)\n')
after(f,'\t\t\tVerifiedRules.Shantong.turn_start(self, p_idx, i)\n','\t\t\tVerifiedRules.Light.form_turn_start(self, p_idx, i)\n')
f='scripts/form_countdown_rules.gd'
after(f,'\tvar old: Dictionary = unit.get("formCountdown", {})\n','\tvar light_rules: Dictionary = unit.get("formRules", {}).duplicate(true)\n')
after(f,'\tunit.formAbility = ""\n','\tgs.VerifiedRules.Light.form_removed(gs, owner, src, light_rules)\n')
f='scripts/combat_keyword_rules.gd'
after(f,'\tgs.VerifiedRules.Tide.combat_dealt(gs, owner, src, result, tide_traits)\n','\tgs.VerifiedRules.Light.combat_dealt(gs, owner, src, victim, idx, result)\n')
edit(f,'if int(result.get("dealt", result.damage)) > 0 and lethal:', 'if int(result.get("dealt", result.damage)) > 0 and lethal and not result.get("knocked", false):')
f='scripts/haifangzhu_rules.gd'
after(f,'\tif amount <= 0 or gs.winner >= 0: return 0\n','\tif gs.VerifiedRules.Light.convert_heal(gs, owner, src, victim, idx, amount): return 0\n')
f='scripts/game_ai.gd'
after(f,'static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','\tvar light_score = _gs.VerifiedRules.Light.score_card(_gs, p_idx, card, _target)\n\tif light_score != null: return int(light_score)\n')
f='scripts/ui/battle_screen.gd'
edit(f,'\t\t\t_prompt("占卜：选择一张牌置于牌库顶", ThemeBuilder.GOLD_BRIGHT)','\t\t\t_prompt(str(gs.pending_choice.get("title", "占卜：选择一张牌置于牌库顶")), ThemeBuilder.GOLD_BRIGHT)')
edit(f,'\tv.add_child(ThemeBuilder.title_label("占 卜", 30))','\tv.add_child(ThemeBuilder.title_label("青 灯 夜 谈" if gs.pending_choice.get("type") == "lantern-choice" else "占 卜", 30))')
edit(f,'\tvar hint := ThemeBuilder.dim_label("选择一张置于牌库顶，下回合即可抽到", 14)','\tvar hint := ThemeBuilder.dim_label("选择一张置入手牌 · 剩余%d次" % int(gs.pending_choice.remaining) if gs.pending_choice.get("type") == "lantern-choice" else "选择一张置于牌库顶，下回合即可抽到", 14)')
after(f,'\t\t\tif gs.resolve_divination_choice(PLAYER, str(iid)):\n','\t\t\t\tif is_instance_valid(_choice_layer): _choice_layer.queue_free()\n\t\t\t\t_choice_layer = null\n')
edit(f,'\t\t"resolve_divination_choice": what = "占卜置顶「%s」" % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")','\t\t"resolve_divination_choice": what = ("青灯夜谈获得「%s」" if a.get("choice") == "lantern-choice" else "占卜置顶「%s」") % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")')
f='scripts/ui/battle_status.gd'
after(f,'\tif ContentLoader.unit_def(str(view.id)).get("snowCombat", false): view.enemyStuns = int(gs.player(owner).get("enemyStuns", 0))\n','\tview.lightFortuneTotal = gs.VerifiedRules.Light.fortune_total(gs)\n\tview.lightDamageEvents = int(gs.player(owner).get("enemyDamageEvents", 0))\n\tview.lightImmune = int(gs.player(owner).get("monkImmuneTurn", -1)) == gs.turn_counter\n')
after(f,'\tvar definition := ContentLoader.unit_def(str(unit.get("id", "")))\n','\tvar light_role := str(definition.get("lightRole", ""))\n\tif light_role == "fortune": result.append(mark("fortune-history", "双方运势 %d/15" % int(unit.get("lightFortuneTotal", 0)), "本局双方运势判定成功次数；重投只计最终结果。", "e2c58c"))\n\tif light_role == "monk":\n\t\tresult.append(mark("monk-history", "受敌伤害 %d次" % int(unit.get("lightDamageEvents", 0)), "轮回按伤害事件增强；自己造成的伤害不计。", "81d6d6"))\n\t\tif unit.get("lightImmune", false): result.append(mark("monk-immunity", "舍生 · 牌手本回合免伤", "保护持续至当前回合结束，青坊主气绝不移除。", "e2c58c"))\n')
after(f,'\tif active:\n','\t\tif light_role == "lantern" and unit.get("awakened", false): result.append(mark("lantern-retain", "鬼火保留 · 上限4", "己方回合开始额外获得2点鬼火，已有鬼火不会清除。", "e2c58c"))\n\t\tif light_role == "fortune": result.append(mark("fortune-reroll", "失败重投一次" if unit.get("awakened", false) else "掷出1重投一次", "每次判定至多重投一次，气绝时不生效。", "e2c58c"))\n\t\tif unit.get("formRules", {}).get("monkHealDraw", false): result.append(mark("monk-draw", "禅心 · 每回合首次回复抽牌", "只在牌手实际回复生命时触发。", "81d6d6"))\n\t\tif unit.get("formRules", {}).get("enemyHealingIsDamage", false): result.append(mark("monk-convert", "对敌治疗转为伤害", "己方来源给予敌方的回复效果改为伤害。", "e892a8"))\n')
source=Path(__file__).with_name('overlay.json');v=json.loads((root/'content/verified_rules.json').read_text());p=json.loads(source.read_text())
v['sources'].extend(p['sources'])
for key in ['units','cards']:v[key].update(p[key])
for rel,body in contents.items():(root/rel).write_text(body)
(root/'content/verified_rules.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
print('LIGHT_HEALER_INTEGRATION_OK',root)
