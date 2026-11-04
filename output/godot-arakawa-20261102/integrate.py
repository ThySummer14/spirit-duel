from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
def edit(name,old,new):
 p=root/name;s=p.read_text();assert old in s,(name,old[:90]);p.write_text(s.replace(old,new,1))
p=root/'godot/content/verified_rules.json'; data=json.loads(p.read_text()); overlay=json.loads((Path(__file__).parent/'overlay.json').read_text())
for k in ['units','cards']:data[k].update(overlay[k])
for source in overlay['sources']:
 if not any(s['id']==source['id'] for s in data['sources']):data['sources'].append(source)
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
# Persist the new derivative in the generator and generated catalog.
c=overlay['cards']['arakawa-annihilate']; token={k:c[k] for k in ['id','unitId','name','type','level','cost','text','target','deckLimit','token']};token['effects']=[['always','ark-annihilate','selected',0]]
edit('scripts/gen-wave6-content.py','def main() -> None:',f'EXTRA_TOKENS += {repr([token])}\n\n\ndef main() -> None:')
body=json.dumps({**token,'starter':0,'subpack':'zhenjian'},ensure_ascii=False,indent=4)
edit('game-content-wave6.js',']);\n\nexport function getWave6UnitIds()',f'  wave6Card(0, "huangchuanzhizhu", {body}),\n]);\n\nexport function getWave6UnitIds()')
edit('godot/scripts/verified_card_rules.gd','const ChargedPair :=','const Arakawa := preload("res://scripts/arakawa_rules.gd")\nconst ChargedPair :=')
edit('godot/scripts/verified_card_rules.gd','\tif BlueGreen.resolve_action','\tif Arakawa.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif BlueGreen.resolve_action')
edit('godot/scripts/verified_card_rules.gd','\tBlueGreen.announced(gs,frame,announced)','\tArakawa.announced(gs,frame,announced)\n\tBlueGreen.announced(gs,frame,announced)')
edit('godot/scripts/game_state.gd','\tcard = VerifiedRules.ChargedPair.describe','\tcard = VerifiedRules.Arakawa.describe_card(self,p_idx,card)\n\tcard = VerifiedRules.ChargedPair.describe')
edit('godot/scripts/game_state.gd','\tvar charged_targets=','\tvar ark_targets=VerifiedRules.Arakawa.targets(self,p_idx,card)\n\tif ark_targets!=null:return ark_targets\n\tvar charged_targets=')
edit('godot/scripts/game_state.gd','\tif not VerifiedRules.ChargedPair.can_use','\tif not VerifiedRules.Arakawa.can_use(self,p_idx,card):return {"ok":false,"reason":"荒川之主已有蓄力。"}\n\tif not VerifiedRules.ChargedPair.can_use')
edit('godot/scripts/game_state.gd','\tvar is_response := not response_window.is_empty()','\tcard.usedFromHand = hand_index < p.hand.size() and not inst.get("linkVirtual", false)\n\tvar is_response := not response_window.is_empty()')
edit('godot/scripts/game_state.gd','\tif VerifiedRules.BlueGreen.resolve_frame','\tif VerifiedRules.Arakawa.resolve_frame(self,frame):return\n\tif VerifiedRules.BlueGreen.resolve_frame')
edit('godot/scripts/game_state.gd','\t\tVerifiedRules.BlueGreen.completed(self,frame,card)','\t\tVerifiedRules.Arakawa.completed(self,frame,card)\n\t\tVerifiedRules.BlueGreen.completed(self,frame,card)')
p=root/'godot/scripts/game_state.gd';s=p.read_text();s=s.replace('\t\tVerifiedRules.Crab.clear_finished_immunity(self)','\t\tVerifiedRules.Arakawa.refresh_hold(self)\n\t\tVerifiedRules.Crab.clear_finished_immunity(self)');p.write_text(s)
edit('godot/scripts/weaver_rules.gd','\t\tif old.get("boxSummon",false):','\t\tif old.get("arkFish",false): gs.VerifiedRules.Arakawa.remove_fish(gs,owner,old)\n\t\tif old.get("boxSummon",false):')
edit('godot/scripts/game_state.gd','\tif u.get("whaleGuardian",false):\n','\tif u.get("arkFish",false):\n\t\tu.hp=0; u.front=0; u.knockout=0; u.removed=true\n\tif u.get("whaleGuardian",false):\n')
edit('godot/scripts/game_ai.gd','\tvar charged_score=','\tvar ark_score=_gs.VerifiedRules.Arakawa.score_card(_gs,p_idx,card,_target)\n\tif ark_score!=null:return int(ark_score)\n\tvar charged_score=')
edit('godot/scripts/ui/battle_status.gd','\tview.chargedMarks=','\tview.arkMarks=gs.VerifiedRules.Arakawa.marks(gs,owner,view)\n\tview.chargedMarks=')
edit('godot/scripts/ui/battle_status.gd','\tfor detail in unit.get("chargedMarks",[]):','\tfor detail in unit.get("arkMarks",[]):result.append(mark("arakawa-rule",str(detail),str(detail),"81b8de"))\n\tfor detail in unit.get("chargedMarks",[]):')
