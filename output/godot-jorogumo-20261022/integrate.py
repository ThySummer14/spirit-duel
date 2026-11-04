from pathlib import Path

def edit(p,a,b,n=1):
 q=Path(p);s=q.read_text();assert s.count(a)==n,(p,a,s.count(a));q.write_text(s.replace(a,b))
p='godot/scripts/jorogumo_rules.gd'
edit(p,'int(unit.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(unit)','int(unit.get("knockout",0))>0 or unit.get("removed",false) or not gs.VerifiedRules.OwlInsect.shikigami(unit)')
edit(p,'var unit: Dictionary = gs._create_player("spider-fixture","",["luoxinfu"]).units[0].duplicate(true)','var unit: Dictionary = {"color":"#d080c0","shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"charge":0,"removed":false}')
edit(p,'"blocked":int(hit.get("damage",0))==0}', '"blocked":int(hit.get("damage",0))==0,"card":{"id":"spider-mark","unitId":"luoxinfu","type":"ability","name":"蜘蛛印记"}}')
edit(p,'if idx>=0 and gs.winner<0: gs._damage_unit(1-owner,idx,int(gs.player(owner).units[src].level),owner,src)','if idx>=0 and gs.winner<0:\n\t\t\t\t\tvar hit: Dictionary = gs._damage_unit(1-owner,idx,int(gs.player(owner).units[src].level),owner,src)\n\t\t\t\t\tgs.VerifiedRules.event(gs,"jorogumo-card-hit",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":uid,"victimPlayer":1-owner,"amount":int(hit.get("damage",0)),"blocked":int(hit.get("damage",0))==0,"card":card})')
edit(p,'"realmUid":field.uid,"victimPlayer":1-owner,"amount":dealt}', '"realmUid":field.uid,"uid":gs.player(owner).units[idx].uid,"target":"","victimPlayer":1-owner,"amount":dealt,"blocked":dealt==0,"card":Content.card_def("c27501")}')
p='godot/scripts/verified_card_rules.gd'
edit(p,'const Yitiao :=','const Jorogumo := preload("res://scripts/jorogumo_rules.gd")\nconst Yitiao :=')
edit(p,'\tif Yitiao.resolve_action','\tif Jorogumo.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true\n\tif Yitiao.resolve_action')
edit(p,'static func end_turn(gs, p_idx: int) -> void:\n','static func end_turn(gs, p_idx: int) -> void:\n\tJorogumo.end_turn(gs,p_idx)\n')
edit(p,'\tunit.erase("garudaFeather")','\tunit.erase("spiderMark")\n\tunit.erase("garudaFeather")')
p='godot/scripts/game_state.gd'
edit(p,'\t\tVerifiedRules.Doll.remove_departed(self)','\t\tVerifiedRules.Doll.remove_departed(self)\n\t\tVerifiedRules.Jorogumo.remove_departed(self)',2)
edit(p,'\tcard = VerifiedRules.Yitiao.describe_card','\tcard = VerifiedRules.Jorogumo.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.Yitiao.describe_card')
edit(p,'for targets in [VerifiedRules.Butterfly.targets','for targets in [VerifiedRules.Jorogumo.targets(self,p_idx,card),VerifiedRules.Butterfly.targets')
edit(p,'"cost": 0 if three_tail_free else 0 if deck_free or card.get("headlessFree",false) or card.get("puppetFree",false) else (0 if uses_instant or coin_free else int(card.get("cost", 0))) + VerifiedRules.TomatoFire.extra_cost(self, p_idx, card),','"cost": (0 if three_tail_free else 0 if deck_free or card.get("headlessFree",false) or card.get("puppetFree",false) else (0 if uses_instant or coin_free else int(card.get("cost", 0))) + VerifiedRules.TomatoFire.extra_cost(self, p_idx, card)) + VerifiedRules.Jorogumo.card_tax(self,p_idx,card),')
edit(p,'\tif not VerifiedRules.Yitiao.can_use','\tif not VerifiedRules.Jorogumo.can_use(self,p_idx,card): return {"ok":false,"reason":"络新妇已经觉醒。"}\n\tif not VerifiedRules.Yitiao.can_use')
edit(p,'\tif VerifiedRules.Yitiao.resolve_frame','\tif VerifiedRules.Jorogumo.resolve_frame(self,frame): return\n\tif VerifiedRules.Yitiao.resolve_frame')
edit(p,'"yitiao-revive": "revive"','"yitiao-revive": "revive", "jorogumo-needle": "damage", "jorogumo-combat": "assault", "jorogumo-aoe": "damage", "jorogumo-exterminate": "damage"')
edit(p,'\tvar preview: int = VerifiedRules.Bingyong.limit_damage','\tamount += VerifiedRules.Jorogumo.damage_bonus(u)\n\tvar preview: int = VerifiedRules.Bingyong.limit_damage')
edit(p,'\tvar cotton_saved := VerifiedRules.Cotton.knockout_snapshot','\tvar jorogumo_saved := VerifiedRules.Jorogumo.death_frames(self,victim,u)\n\tvar cotton_saved := VerifiedRules.Cotton.knockout_snapshot')
edit(p,'\tresolution_stack.append_array(house_saved)','\tresolution_stack.append_array(jorogumo_saved)\n\tif u.get("jorogumoSwarm",false):\n\t\tu.hp=0; u.front=0; u.knockout=0; u.removed=true\n\tresolution_stack.append_array(house_saved)')
a='\tif VerifiedRules.Butterfly.free_realm(self,p_idx).is_empty() and not VerifiedRules.Moon.extra_attack(self,p_idx) and not VerifiedRules.Movement.extra_attack(self, p_idx, u) and int(p.energy) < VerifiedRules.TomatoFire.basic_cost(self, p_idx, u):'
b='\tvar deployment_free: bool = not VerifiedRules.Butterfly.free_realm(self,p_idx).is_empty() or VerifiedRules.Moon.extra_attack(self,p_idx) or VerifiedRules.Movement.extra_attack(self,p_idx,u)\n\tvar required_fire: int = VerifiedRules.Jorogumo.tax(self,p_idx,u) if deployment_free else VerifiedRules.TomatoFire.basic_cost(self,p_idx,u)\n\tif int(p.energy) < required_fire:'
edit(p,a,b)
edit(p,'\tif free_deployment:\n\t\tfree_realm.butterflyUsedTurn','\tvar deployment_free: bool = free_deployment or VerifiedRules.Moon.extra_attack(self,p_idx) or VerifiedRules.Movement.extra_attack(self,p_idx,p.units[unit_index])\n\tif free_deployment:\n\t\tfree_realm.butterflyUsedTurn')
edit(p,'\tvar inspired: bool = VerifiedRules.Combat.has(p.units[unit_index], "inspired")','\tif deployment_free: _set_fire(p_idx,int(p.energy)-VerifiedRules.Jorogumo.tax(self,p_idx,p.units[unit_index]),true)\n\tvar inspired: bool = VerifiedRules.Combat.has(p.units[unit_index], "inspired")')
edit(p,'\tVerifiedRules.OwlInsect.attack_started(self,p_idx,unit_index)','\tVerifiedRules.Jorogumo.before_attack(self,p_idx,unit_index)\n\tif not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner>=0: return\n\tVerifiedRules.OwlInsect.attack_started(self,p_idx,unit_index)')
p='godot/scripts/tomato_fire_rules.gd';edit(p,'return cost + (1 if role(u) == "sister" and not u.awakened else 0)','return cost + (1 if role(u) == "sister" and not u.awakened else 0) + gs.VerifiedRules.Jorogumo.tax(gs,owner,u)')
p='godot/scripts/combat_keyword_rules.gd'
edit(p,'amount + int(target.armorBreak) - int(target.shield)','amount + gs.VerifiedRules.Jorogumo.damage_bonus(target) + int(target.armorBreak) - int(target.shield)')
edit(p,'\tgs.VerifiedRules.OwlInsect.combat_dealt','\tgs.VerifiedRules.Jorogumo.combat_dealt(gs,owner,src,victim,idx,result)\n\tgs.VerifiedRules.OwlInsect.combat_dealt')
p='godot/scripts/movement_rules.gd';edit(p,' if unit.get("summoned", false):\n',' if unit.get("summoned", false):\n  if unit.get("jorogumoSwarm",false):\n   gs.VerifiedRules.Jorogumo.remove_summon(gs,owner,unit)\n   return true\n')
p='godot/scripts/weaver_rules.gd';edit(p,'\t\telif old.get("enmaGhost",false):','\t\telif old.get("jorogumoSwarm",false): gs.VerifiedRules.Jorogumo.remove_summon(gs,owner,old,"战斗区被替换")\n\t\telif old.get("enmaGhost",false):')
p='godot/scripts/pipe_fox_rules.gd';edit(p,'\t\tif not unit.get("garudaFeather",{}).is_empty()','\t\tif not unit.get("spiderMark",{}).is_empty() and int(unit.spiderMark.sourceOwner)!=owner: var e:=base.duplicate(); e.key="spiderMark"; out.append(e)\n\t\tif not unit.get("garudaFeather",{}).is_empty()');edit(p,'\t\t"garudaFeather": target.erase(key)','\t\t"spiderMark", "garudaFeather": target.erase(key)')
for name in ['moon_rules','sparrow_rules']:
 p='godot/scripts/'+name+'.gd';edit(p,'["garudaFeather","moonCharm"','["spiderMark","garudaFeather","moonCharm"')
p='godot/scripts/ui/battle_status.gd';edit(p,'\tview.yitiaoMarks=','\tview.jorogumoMarks=gs.VerifiedRules.Jorogumo.unit_marks(gs,owner,idx)\n\tview.yitiaoMarks=');edit(p,'\tfor detail in unit.get("yitiaoMarks",[]):','\tfor detail in unit.get("jorogumoMarks",[]): result.append(mark("spider-rule",str(detail),str(detail),"d080c0"))\n\tfor detail in unit.get("yitiaoMarks",[]):')
p='godot/scripts/game_ai.gd';edit(p,'\tvar yitiao_score =','\tvar jorogumo_score = _gs.VerifiedRules.Jorogumo.score_card(_gs,p_idx,card,_target)\n\tif jorogumo_score != null: return int(jorogumo_score)\n\tvar yitiao_score =')
p='godot/scripts/ui/battle_effect_cues.gd';edit(p,'"garuda-feather-hit", "garuda-card-hit"]','"garuda-feather-hit", "garuda-card-hit", "jorogumo-card-hit", "jorogumo-repeat-hit", "jorogumo-realm-death"]')
