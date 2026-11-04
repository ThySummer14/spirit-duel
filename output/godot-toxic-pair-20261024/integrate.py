from pathlib import Path
import json,shutil
root=Path.cwd();out=root/'output/godot-toxic-pair-20261024'
def edit(path,old,new):
 p=root/path;s=p.read_text();assert s.count(old)==1,(path,old,s.count(old));p.write_text(s.replace(old,new,1))
def after(path,needle,text):edit(path,needle,needle+text)
p='godot/scripts/toxic_rules.gd';s=(root/p).read_text().replace(' or u.get("scorpionAttackToxic",false)','').replace('gs._rng.randi_range(0,list.size()-1)','gs.next_random()%list.size()').replace('int(realm.get("sourceIndex",-1))','gs._source_index(victim,{"unitId":realm.get("sourceUnit","")})').replace(' or (idx>=0 and t.lethal)','')
a=s.index('static func before_attack(');b=s.index('static func apply(',a);s=s[:a]+s[b:]
s=s.replace('static func damaged(gs, owner: int, src: int, victim: int, idx: int, amount: int, combat: bool) -> void:','static func damaged(gs, owner: int, src: int, victim: int, idx: int, amount: int, combat: bool) -> bool:').replace('if amount<=0 or owner<0 or src<0:return\n\tvar t:=traits','if amount<=0 or owner<0 or src<0:return false\n\tvar t:=traits')
s=s.replace('\nstatic func avatar_damaged','\n\treturn idx>=0 and t.lethal and int(gs.player(victim).units[idx].hp)>0\nstatic func avatar_damaged',1)
(root/p).write_text(s)
p='godot/scripts/verified_card_rules.gd';after(p,'const HandBlessing := preload("res://scripts/hand_blessing_rules.gd")\n','const Toxic := preload("res://scripts/toxic_rules.gd")\n');after(p,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n','\tif Toxic.resolve_action(gs,p_idx,src,card,effect,target): return true\n');after(p,'static func knocked_out(unit: Dictionary) -> void:\n','\tToxic.knocked_out(unit)\n')
p='godot/scripts/game_state.gd';after(p,'var _hand_combat_context: Dictionary = {}\n','var _toxic_damage_context: Dictionary = {}\n')
edit(p,'return VerifiedRules.HandBlessing.describe_card(self,p_idx,inst,VerifiedRules.SpiderLily.describe_card(self, p_idx, inst, card, hand_index == p.hand.size()))','return VerifiedRules.HandBlessing.describe_card(self,p_idx,inst,VerifiedRules.Toxic.describe_card(self,p_idx,inst,VerifiedRules.SpiderLily.describe_card(self, p_idx, inst, card, hand_index == p.hand.size())))')
after(p,'\tif not VerifiedRules.KoiFragrance.can_use(self,p_idx,card):','') if False else None
needle='\tif not VerifiedRules.HandBlessing.can_use(card):';s=(root/p).read_text();line=next(x for x in s.splitlines(True) if x.startswith(needle));after(p,line,'\tif not VerifiedRules.Toxic.can_use(self,p_idx,card): return {"ok":false,"reason":"当前不能使用此剧毒牌。"}\n')
# Custom targets and stack frames use the established shared entry points.
edit(p,'for targets in [VerifiedRules.KoiFragrance.targets(self,p_idx,card),','for targets in [VerifiedRules.Toxic.targets(self,p_idx,card),VerifiedRules.KoiFragrance.targets(self,p_idx,card),')
after(p,'\tif VerifiedRules.HandBlessing.resolve_frame(self,frame): return\n','\tif VerifiedRules.Toxic.resolve_frame(self,frame): return\n')
after(p,'\tif attacker.get("cannotAttack", false): return\n','\tif VerifiedRules.Toxic.role(attacker)=="scorpion" and VerifiedRules.Toxic.active(attacker): options.toxicAttack=true\n')
after(p,'\t\tvar d_options := {"convertCombatToArmorBreak": options.get("convertCombatToArmorBreak", false)}\n','\t\td_options.toxicAttack=VerifiedRules.Toxic.traits(self,victim,idx,true).toxic\n')
# A second poisonous damage event directly knocks out; barriers, armor, conversion and transfer have resolved first.
needle='\tvar cap := int(u.get("formRules", {}).get("damageCap", 0))\n';before='''	if VerifiedRules.Toxic.executes(self,_src_player,source_index,p_idx,unit_index,unshielded,combat):
		var deaths_before:=int(u.get("rebirthDeaths",0))
		_knockout_unit(u,_src_player,source_index,knockout_extra,house_break_snapshot)
		var body_knocked:=int(u.get("rebirthDeaths",0))>deaths_before
		if body_knocked: VerifiedRules.Yaodao.unit_killed(self,_src_player,source_index,p_idx,unit_index)
		VerifiedRules.event(self,"toxic-execution",{"player":_src_player,"victimPlayer":p_idx,"target":u.uid})
		return {"damage":0,"dealt":0,"knocked":int(u.hp)<=0,"bodyKnocked":body_knocked,"overkill":0,"poisonExecution":true}
''';edit(p,needle,before+needle)
after(p,'\tvar knocked := false\n','\tvar toxic_lethal:=VerifiedRules.Toxic.damaged(self,_src_player,source_index,p_idx,unit_index,taken,combat)\n')
edit(p,'\tif int(u.hp) <= 0:\n\t\tvar deaths_before:=','\tif int(u.hp) <= 0 or toxic_lethal:\n\t\tvar deaths_before:=')
after(p,'\tvar jorogumo_saved := VerifiedRules.Jorogumo.death_frames(self,victim,u)\n','\tvar toxic_saved:=VerifiedRules.Toxic.death_frames(self,victim,u,source_owner,source_index)\n')
after(p,'\tresolution_stack.append_array(jorogumo_saved)\n','\tresolution_stack.append_array(toxic_saved)\n\tVerifiedRules.Toxic.refresh(self)\n\tif u.get("toxicSwarm",false): VerifiedRules.Toxic.remove_swarm(self,victim,u)\n')
needle='\tvar floor_hp := 1 if VerifiedRules.ArmorBlood.protects_avatar(self, p_idx) else 0\n';edit(p,needle,'''	if VerifiedRules.Toxic.executes(self,_src_player,source_index,p_idx,-1,amount,combat):
		p.avatarHp=0
		VerifiedRules.event(self,"toxic-execution",{"player":_src_player,"victimPlayer":p_idx,"target":""})
		_check_winner(); return 0
'''+needle)
after(p,'\tVerifiedRules.KoiFragrance.avatar_damage(self,_src_player,source_index,p_idx,actual_loss,combat)\n','\tVerifiedRules.Toxic.avatar_damaged(self,_src_player,source_index,p_idx,actual_loss,combat)\n')
edit(p,'\tif gain > 0 and int(unit.hp) > 0:\n','\tif gain > 0 and int(unit.hp) > 0 and not unit.get("toxicPoisoned",false):\n')
after(p,'\tunit.attack += VerifiedRules.OwlInsect.power(self,unit) - int(unit.get("insectCorrosion",0))\n','\tfor side in players.size():\n\t\tif player(side).units.has(unit): unit.attack-=VerifiedRules.Toxic.aura(self,side,unit)\n')
after(p,'func _install_form(p_idx: int, src: int, card: Dictionary, value: Dictionary = {}) -> void:\n','\tvar poison_hp:=int(player(p_idx).units[src].hp) if player(p_idx).units[src].get("toxicPoisoned",false) else -1\n')
edit(p,'\tif int(u.hp) > 0 and not card.get("puppetFusion",false):\n\t\tu.hp = int(u.maxHp)\n','\tif poison_hp>0: u.hp=poison_hp\n\telif int(u.hp) > 0 and not card.get("puppetFusion",false):\n\t\tu.hp = int(u.maxHp)\n')
after(p,'\tVerifiedRules.KoiFragrance.form_entered(self,p_idx,src,card)\n','\tVerifiedRules.Toxic.form_entered(self,p_idx,src,card)\n')
after(p,'func _heal_unit(unit: Dictionary, amount: int) -> void:\n','\tif unit.get("toxicPoisoned",false): return\n')
after(p,'func _heal_avatar(p_idx: int, amount: int) -> void:\n','\tif player(p_idx).get("avatarToxicPoisoned",false): return\n')
p='godot/scripts/form_countdown_rules.gd';shutil.copyfile(root/p,out/'before'/p)
after(p,'static func remove(gs, owner: int, src: int, reason: String) -> void:\n','\tvar poison_hp:=int(gs.player(owner).units[src].hp) if gs.player(owner).units[src].get("toxicPoisoned",false) else -1\n')
edit(p,'\tif int(unit.hp) > 0: unit.hp = int(unit.maxHp)\n','\tif poison_hp>0: unit.hp=poison_hp\n\telif int(unit.hp) > 0: unit.hp = int(unit.maxHp)\n')
p='godot/scripts/combat_keyword_rules.gd';needle='\tvar result: Dictionary = gs.VerifiedRules.ArmorBreak.combat_damage(gs, owner, src, victim, idx, amount, bool(options.get("convertCombatToArmorBreak", false)), immune, int(options.get("victimKnockoutExtra", -1)), critical)\n';edit(p,needle,'\tvar outer_toxic_context: Dictionary=gs._toxic_damage_context\n\tif options.get("toxicAttack",false): gs._toxic_damage_context={"playerIndex":owner,"sourceIndex":src}\n'+needle+'\tgs._toxic_damage_context=outer_toxic_context\n')
p='godot/scripts/weaver_rules.gd';after(p,'\t\telif old.get("jorogumoSwarm",false): gs.VerifiedRules.Jorogumo.remove_summon(gs,owner,old,"战斗区被替换")\n','\t\telif old.get("toxicSwarm",false): gs.VerifiedRules.Toxic.remove_swarm(gs,owner,old)\n')
p='godot/scripts/game_ai.gd';after(p,'static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','\tvar toxic_score=_gs.VerifiedRules.Toxic.score_card(_gs,p_idx,card,_target)\n\tif toxic_score!=null: return int(toxic_score)\n')
p='godot/scripts/ui/battle_status.gd';after(p,'\tview.koiFragranceMarks=gs.VerifiedRules.KoiFragrance.unit_marks(gs,owner,idx)\n','\tview.toxicMarks=gs.VerifiedRules.Toxic.unit_marks(gs,owner,idx)\n');after(p,'static func unit_marks(unit: Dictionary, turn: int = -1) -> Array:\n','')
needle='\tfor detail in unit.get("koiFragranceMarks",[]): result.append(mark("koi-fragrance-rule",str(detail),str(detail),"90c8b8"))\n';after(p,needle,'\tfor detail in unit.get("toxicMarks",[]): result.append(mark("toxic-rule",str(detail),str(detail),"b1ca70"))\n')
p='godot/scripts/ui/battle_screen.gd';edit(p,'\t\tpair[0].text = "破 %d" % int(pair[1].get("avatarArmorBreak", 0))\n\t\tpair[0].visible = int(pair[1].get("avatarArmorBreak", 0)) > 0','\t\tpair[0].text = ("中毒 · 再受剧毒即败 " if pair[1].get("avatarToxicPoisoned",false) else "") + ("破 %d" % int(pair[1].get("avatarArmorBreak", 0)) if int(pair[1].get("avatarArmorBreak",0))>0 else "")\n\t\tpair[0].visible = pair[1].get("avatarToxicPoisoned",false) or int(pair[1].get("avatarArmorBreak", 0)) > 0')
p='godot/scripts/ui/keyword_glossary.gd';after(p,'const ENTRIES := {\n','\t"toxic": ["剧毒", "对式神造成实际伤害使其中毒；已中毒的角色再受到剧毒伤害直接气绝。采用基础版本，中毒不能恢复或重置生命。"],\n')
p='scripts/godot-verify.sh';edit(p,'verify_koi_fragrance verify_combat','verify_koi_fragrance verify_toxic_pair verify_combat')
print('TOXIC_ENGINE_INTEGRATED')
