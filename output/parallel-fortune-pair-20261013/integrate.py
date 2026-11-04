"""Exact guarded FortunePair integration. Usage: python3 integrate.py /absolute/godot/path."""
import json,re,sys
from pathlib import Path
root=Path(sys.argv[1]).resolve();changes={}
def edit(rel,old,new,n=1):
 p=root/rel;s=changes.get(rel,p.read_text());actual=s.count(old)
 if actual!=n:raise SystemExit(f'{rel}: expected {n}, got {actual}: {old[:90]!r}')
 changes[rel]=s.replace(old,new,n)
def after(rel,old,new):edit(rel,old,old+new)
def before(rel,old,new):edit(rel,old,new+old)
f='scripts/verified_card_rules.gd'
after(f,'const Light := preload("res://scripts/light_healer_rules.gd")','\nconst Fortune := preload("res://scripts/fortune_pair_rules.gd")')
after(f,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n','\tif Fortune.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true\n')
after(f,'static func knocked_out(unit: Dictionary) -> void:\n','\tif unit.get("baseRulesSuppressed", false):\n\t\tFortune.restore(unit)\n\t\tunit.form = {}\n\t\tunit.formRules = {}\n\t\tunit.formHooks = []\n\t\tunit.formAbility = ""\n')
# fortune-combat responses produce their fortune effect, then augment the interrupted combat.
edit(f,'var combat_id := int(continuation.get("combatId", -1)) if card.get("responseModifiesCombat", false) else -1','var combat_id := int(continuation.get("combatId", -1)) if card.get("responseModifiesCombat", false) else -1')
after(f,'static func end_turn(gs, p_idx: int) -> void:\n','\tFortune.end_turn(gs)\n')
after(f,'\t\tvar unit: Dictionary = p.units[src]\n','\t\tif unit.get("baseRulesSuppressed", false): continue\n')
f='scripts/game_state.gd'
after(f,'\tvar su: Dictionary = p.units[src]\n','\tif su.get("baseRulesSuppressed", false):\n\t\treturn {"ok": false, "reason": "纸人变形期间无法使用原式神的卡牌。"}\n')
after(f,'\tcard = VerifiedRules.Light.describe_card(self, p_idx, p.hand[hand_index], card)\n','\tcard = VerifiedRules.Fortune.describe_card(self, p_idx, card)\n')
after(f,'\tunit.attack = int(unit.baseAttack) + int(unit.attackBonus) + int(form.get("attackBonus", 0)) + int(unit.get("cranePower", 0)) + int(unit.get("permanentAttack", 0)) + int(unit.get("temporaryAttack", 0)) + int(unit.get("untilAttack", {}).get("attack", 0)) - int(unit.get("judgeInkAttack", 0))\n','\tunit.attack += VerifiedRules.Fortune.power(self, unit)\n')
before(f,'\tVerifiedRules.DogDemon.knocked_out(u)\n','\tif u.get("baseRulesSuppressed", false):\n\t\tVerifiedRules.Fortune.restore(u)\n\t\tu.form = {}\n\t\tu.formRules = {}\n\t\tu.formHooks = []\n\t\tu.formAbility = ""\n')
after(f,'\tVerifiedRules.Light.form_entered(self, p_idx, src, card)\n','\tVerifiedRules.Fortune.form_entered(self, p_idx, src, card)\n')
after(f,'func _begin_turn(p_idx: int) -> void:\n','\tVerifiedRules.Fortune.turn_boundary(self)\n')
after(f,'\t\t\t\tVerifiedRules.DogDemon.turn_start(self, p_idx, i)\n','\t\t\t\tVerifiedRules.Fortune.turn_start(self, p_idx, i)\n')
after(f,'\tVerifiedRules.SnowCrane.before_attack(self, p_idx, unit_index)\n','\tVerifiedRules.Fortune.before_attack(self, p_idx, unit_index)\n')
after(f,'\tvar continuation := {"kind": "combat-hit",','') if False else None
before(f,'\tvar continuation := {"kind": "combat-hit", "playerIndex": p_idx,','\tVerifiedRules.Fortune.before_attacked(self, e_idx, fi)\n')
after(f,'\tVerifiedRules.Light.after_attack(self, owner, src)\n','\tVerifiedRules.Fortune.combat_finished(self, owner, src, options)\n')
edit(f,'if int(frame.get("combatResponseId", -1)) >= 0 and effects[idx].get("action") == "assault":','if int(frame.get("combatResponseId", -1)) >= 0 and effects[idx].get("action") in ["assault", "fortune-combat"]:')
after(f,'\tif int(frame.get("combatResponseId", -1)) >= 0 and effects[idx].get("action") in ["assault", "fortune-combat"]:\n','\t\tif VerifiedRules.Fortune.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return\n')
edit(f,'\treturn VerifiedRules.Light.roll(self, p_idx, threshold, sides)\n','\treturn VerifiedRules.Light.roll(self, p_idx, threshold, sides, int(card.get("fortuneSourceIndex", -1)))\n')
# Stable legacy conditional uses the real roll; never generate a second random boolean.
edit(f,'\t\t\t# simplified: fortune auto-succeeds on even rng\n\t\t\tif next_random() % 2 == 0:\n','\t\t\tif not _fortune_success(p_idx):\n')
f='scripts/light_healer_rules.gd'
edit(f,'static func roll(gs, owner: int, threshold: int, sides: int = 6) -> bool:\n\tvar first := int(floor(gs.randf01() * sides)) + 1','static func roll(gs, owner: int, threshold: int, sides: int = 6, source: int = -1, force_success: bool = false) -> bool:\n\tvar forced: int = gs.VerifiedRules.Fortune.forced_die(gs, owner, source)\n\tvar first := forced if forced > 0 else int(floor(gs.randf01() * sides)) + 1\n\tgs.VerifiedRules.Fortune.record_die(gs, owner, first)')
after(f,'\t\t\tresult = int(floor(gs.randf01() * sides)) + 1\n','\t\t\tgs.VerifiedRules.Fortune.record_die(gs, owner, result)\n')
edit(f,'\tvar success := result >= threshold\n','\tvar success := force_success or result >= threshold\n\tvar copies: int = gs.VerifiedRules.Fortune.repeat_count(gs, owner) if success else 0\n')
edit(f,'"success": success, "rerolled": rerolled}', '"success": success, "rerolled": rerolled, "effectRepeats": copies}',2)
after(f,'\tif success: gs.player(owner).fortuneSuccesses = int(gs.player(owner).get("fortuneSuccesses", 0)) + 1\n','\tif success:\n\t\tfor copy in copies: gs.VerifiedRules.Fortune.success(gs, owner)\n')
edit(f,'\t\tif roll(gs, recipient, 4):\n\t\t\tif mode == "draw": gs._draw(recipient, 1)\n\t\t\telif mode == "heal": heal(gs, owner, src, recipient, -1, 3)', '\t\tif roll(gs, recipient, 4, 6, src if recipient == owner else -1):\n\t\t\tfor copy in gs.VerifiedRules.Fortune.last_repeats(gs, recipient):\n\t\t\t\tif mode == "draw": gs._draw(recipient, 1)\n\t\t\t\telif mode == "heal": heal(gs, owner, src, recipient, -1, 3)')
edit(f,'\t\t\t\tif not roll(gs, owner, 4): zero = true','\t\t\t\tif not roll(gs, owner, 4, 6, src): zero = true')
edit(f,'\t\t\t\tif not roll(gs, owner, 4): gs.VerifiedRules.Stun.apply(gs, owner, src)','\t\t\t\tif not roll(gs, owner, 4, 6, src): gs.VerifiedRules.Stun.apply(gs, owner, src)')
edit(f,'\t\t\tif gs.winner < 0 and roll(gs, owner, 4): gain_fire(gs, owner, 2)','\t\t\tif gs.winner < 0 and roll(gs, owner, 4, 6, src): gain_fire(gs, owner, 2 * gs.VerifiedRules.Fortune.last_repeats(gs, owner))')
f='scripts/countdown_rules.gd'
after(f,'static func timer(unit: Dictionary) -> Dictionary:\n','\tif unit.get("baseRulesSuppressed", false): return {}\n')
f='scripts/phoenix_rules.gd'
edit(f,'gs._roll_fortune(owner, {"fortune": {"sides": 6, "threshold": int(cfg.get("threshold", 4))}})','gs._roll_fortune(owner, {"fortuneSourceIndex": src, "fortune": {"sides": 6, "threshold": int(cfg.get("threshold", 4))}})')
start='\tvar p: Dictionary = gs.player(owner)\n\tvar card := ContentLoader.card_def(str(cfg.card))\n'
s=changes.get(f,(root/f).read_text()); pos=s.index(start,s.index('static func _generate_on_fortune'))
end=s.index('\nstatic func ',pos)
block=s[pos:end];s=s[:pos]+'\tfor copy in gs.VerifiedRules.Fortune.last_repeats(gs, owner):\n'+''.join('\t'+line if line.strip() else line for line in block.splitlines(True))+s[end:];changes[f]=s
f='scripts/game_ai.gd'
after(f,'static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','\tvar fortune_score = _gs.VerifiedRules.Fortune.score_card(_gs, p_idx, card, _target)\n\tif fortune_score != null: return int(fortune_score)\n')
# One runtime accessor suppresses original unit/awakening traits after true transformation.
f='scripts/content_loader.gd'
after(f,'static func rules() -> Dictionary:\n','') if False else None
before(f,'static func rules() -> Dictionary:\n','static func runtime_unit_def(unit: Dictionary) -> Dictionary:\n\treturn {} if unit.get("baseRulesSuppressed", false) else unit_def(str(unit.get("id", "")))\n\n')
for p in (root/'scripts').glob('*rules.gd'):
 rel=str(p.relative_to(root));s=changes.get(rel,p.read_text())
 s=re.sub(r'ContentLoader\.unit_def\(str\((unit|source|observer)\.get\("id", ""\)\)\)',r'ContentLoader.runtime_unit_def(\1)',s)
 s=re.sub(r'ContentLoader\.unit_def\(str\((unit|source|observer)\.id\)\)',r'ContentLoader.runtime_unit_def(\1)',s)
 if s!=changes.get(rel,p.read_text()):changes[rel]=s
# Transformation and die history are visible in inspector and target selection.
f='scripts/ui/battle_status.gd'
edit(f,'\tvar definition := ContentLoader.unit_def(str(unit.get("id", "")))\n','\tvar definition := ContentLoader.runtime_unit_def(unit)\n')
after(f,'\tvar view: Dictionary = gs.VerifiedRules.Bailang.unit_view(gs, owner, idx, viewer)\n','\tview.fortuneSixes = gs.VerifiedRules.Fortune.sixes(gs, owner)\n\tview.fortuneDistinct = gs.player(owner).get("fortuneNumbers", []).size()\n\tif view.get("baseRulesSuppressed", false):\n\t\tview.presentationId = "zhiren"\n\t\tview.art = ContentLoader.unit_def("zhiren").art\n\t\tview.awakenedArt = view.art\n')
after(f,'\tvar definition := ContentLoader.runtime_unit_def(unit)\n','\tif unit.get("baseRulesSuppressed", false): result.append(mark("paper-transform", "纸人 · 能力失效", "失去原形态、初始和觉醒能力。", "e2c58c"))\n')
after(f,'\tvar definition := ContentLoader.runtime_unit_def(unit)\n','\tif definition.get("fortuneRole", "") != "": result.append(mark("fortune-six-history", "已投6点 %d次 · %d种点数" % [int(unit.get("fortuneSixes", 0)), int(unit.get("fortuneDistinct", 0))], "记录己方实际骰面，包含重投；成功次数另外计算。", "e2c58c"))\n')
f='scripts/ui/ui_widgets.gd'
after(f,'\tvbox.add_child(ThemeBuilder.hline())\n\tvar def := ContentLoader.unit_def(str(unit.get("id", "")))\n','') if False else None
edit(f,'\tvbox.add_child(ThemeBuilder.hline())\n\tvar def := ContentLoader.unit_def(str(unit.get("id", "")))\n','\tvbox.add_child(ThemeBuilder.hline())\n\tif unit.get("baseRulesSuppressed", false):\n\t\tvbox.add_child(_titled("纸人能力", "失去原形态、初始能力和觉醒能力。", ThemeBuilder.TYPE_FORM, false))\n\t\treturn panel\n\tvar def := ContentLoader.unit_def(str(unit.get("id", "")))\n')
f='scripts/ui/portrait_library.gd'
edit(f,'_units.get(str(unit.get("id", "")), {})','_units.get(str(unit.get("presentationId", unit.get("id", ""))), {})')
f='scripts/ui/battle_screen.gd'
# Generated derivative form previews are already present in the unit inspector; no artificial player choice for random discard.
overlay=json.loads(Path(__file__).with_name('overlay.json').read_text());v=json.loads((root/'content/verified_rules.json').read_text())
known={s['id'] for s in v['sources']};v['sources'].extend(s for s in overlay['sources'] if s['id'] not in known)
for group in ['units','cards']:v[group].update(overlay[group])
for rel,s in changes.items():(root/rel).write_text(s)
(root/'content/verified_rules.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
print('FORTUNE_PAIR_INTEGRATION_OK',root,'files',len(changes))
