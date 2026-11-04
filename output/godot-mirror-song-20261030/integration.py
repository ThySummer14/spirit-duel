from pathlib import Path
root=Path(__file__).resolve().parents[2]
changed={}; edits=[]
def edit(path,old,new,count=1):edits.append((path,None,old,new,count))
def function(path,name,old,new,count=1):edits.append((path,name,old,new,count))
gs='godot/scripts/game_state.gd';v='godot/scripts/verified_card_rules.gd'
edit(v,'const Link := preload("res://scripts/link_rules.gd")','const Link := preload("res://scripts/link_rules.gd")\nconst MirrorSong := preload("res://scripts/mirror_song_rules.gd")')
edit(v,'\tif Yi.resolve_action(gs,p_idx,src,card,effect,target_id):return true','\tif MirrorSong.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif Yi.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
edit(v,'\tYujiazhu.knocked_out(unit)','\tunit.erase("msBeautyReceiver")\n\tYujiazhu.knocked_out(unit)')
# The ally-front response may replace the front with Song, subject to the same blocker as other defender replacements.
edit(v,'\t\tif (card.get("dogGuard", false) or card.get("poisonGuard", false) or card.get("yitiaoCover", false)) and Bingyong.replacement_blocked(gs, owner, unit): continue','\t\tif (card.get("dogGuard", false) or card.get("poisonGuard", false) or card.get("yitiaoCover", false) or card.id=="c24404") and Bingyong.replacement_blocked(gs, owner, unit): continue')
edit(v,'if card.get("owlInterfere",false) or (card.get("yujiazhuRules",false) and card.id=="c18904"): actual_target =','if card.get("owlInterfere",false) or card.id=="c24404" or (card.get("yujiazhuRules",false) and card.id=="c18904"): actual_target =')
edit(gs,'var _card_effect_context: Dictionary = {}','var _card_effect_context: Dictionary = {}\nvar _mirror_spell_overflow := false\nvar _mirror_redirecting := false')
edit(gs,'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type")=="ms-beauty":return VerifiedRules.MirrorSong.resolve_choice(self,p_idx,instance_id)\n')
edit(gs,'\tcard = VerifiedRules.Yi.describe_card(self,p_idx,inst,card)','\tcard = VerifiedRules.Yi.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.MirrorSong.describe_card(self,p_idx,inst,card)')
edit(gs,'\tvar yi_targets=VerifiedRules.Yi.targets(self,p_idx,card)','\tvar ms_targets=VerifiedRules.MirrorSong.targets(self,p_idx,card)\n\tif ms_targets!=null:return ms_targets\n\tvar yi_targets=VerifiedRules.Yi.targets(self,p_idx,card)')
edit(gs,'\tif not VerifiedRules.Yi.can_use(self,p_idx,card):','\tif not VerifiedRules.MirrorSong.can_use(self,p_idx,card):return {"ok":false,"reason":"已经觉醒或缺少被指挥的合法式神。"}\n\tif not VerifiedRules.Yi.can_use(self,p_idx,card):')
edit(gs,'\tif VerifiedRules.Yi.resolve_frame(self,frame):return','\tif VerifiedRules.MirrorSong.resolve_frame(self,frame):return\n\tif VerifiedRules.Yi.resolve_frame(self,frame):return')
edit(gs,'\tVerifiedRules.Yi.form_installed(self,p_idx,src,card)','\tVerifiedRules.Yi.form_installed(self,p_idx,src,card)\n\tVerifiedRules.MirrorSong.form_entered(self,p_idx,src,card)')
edit(gs,'\tVerifiedRules.Yi.turn_start(self,p_idx)','\tVerifiedRules.MirrorSong.turn_start(self,p_idx)\n\tVerifiedRules.Yi.turn_start(self,p_idx)')
edit(gs,'\t\tVerifiedRules.Yi.promote(self)','\t\tVerifiedRules.Yi.promote(self)\n\t\tVerifiedRules.MirrorSong.promote(self)',2)
function(gs,'_push_card_frames','\tresolution_stack.append(announce)','\tresolution_stack.append(announce)\n\tVerifiedRules.MirrorSong.pre_card_frames(self,p_idx,src,card)')
function(gs,'_resolve_frame','\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="yuj-talisman":','\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="ms-beauty":\n\t\tVerifiedRules.MirrorSong.respond_combat(self,int(frame.combatResponseId),p_idx,src,card,str(target_id));return\n\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="yuj-talisman":')
# Link-enhanced damage uses the same unit/avatar damage pipeline as the card it belongs to.
function(gs,'_damage_unit','\tif VerifiedRules.FoxLotus.prevents_damage(self,_src_player,source_index):','\tcritical=VerifiedRules.MirrorSong.spell_critical(self,_src_player,source_index,combat,critical)\n\tvar mirror_damage=VerifiedRules.MirrorSong.spell_unit(self,p_idx,unit_index,amount,_src_player,source_index,combat,knockout_extra,transfer_pending,critical,shell_modified)\n\tif mirror_damage!=null:return mirror_damage\n\tif VerifiedRules.FoxLotus.prevents_damage(self,_src_player,source_index):')
function(gs,'_damage_unit','\tif not _card_effect_context.is_empty() and int(_card_effect_context.playerIndex) != p_idx:','\tvar mirror_redirect=VerifiedRules.MirrorSong.redirect(self,p_idx,unit_index,amount,_src_player,source_index,combat,critical)\n\tif mirror_redirect!=null:return mirror_redirect\n\tif not _card_effect_context.is_empty() and int(_card_effect_context.playerIndex) != p_idx:')
function(gs,'_damage_unit','\tif not combat: VerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, unshielded)','\tif not combat: VerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, unshielded)\n\tVerifiedRules.MirrorSong.after_spell_unit(self,_src_player,source_index,p_idx,unit_index,combat,overkill,unshielded)')
function(gs,'_damage_avatar','\tif VerifiedRules.FoxLotus.prevents_damage(self,_src_player,source_index):','\tcritical=VerifiedRules.MirrorSong.spell_critical(self,_src_player,source_index,combat,critical)\n\tif VerifiedRules.FoxLotus.prevents_damage(self,_src_player,source_index):')
function(gs,'_damage_avatar','\tVerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, amount)','\tVerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, amount)\n\tVerifiedRules.MirrorSong.after_spell_avatar(self,_src_player,source_index,combat,amount)')
# Same-side forced attacks keep the ordinary attack, response and counterstrike pipeline.
function(gs,'_resolve_combat','\tvar e_idx := enemy_index(p_idx)','\tvar e_idx := int(options.get("combatVictim",enemy_index(p_idx)))')
function(gs,'_resolve_combat_entered','\tvar e_idx := 1 - p_idx','\tvar e_idx := int(frame.options.get("combatVictim",1-p_idx))')
function(gs,'_resolve_combat_ready','\tvar e_idx := 1 - p_idx','\tvar e_idx := int(frame.options.get("combatVictim",1-p_idx))')
function(gs,'_resolve_combat_ready','\tif VerifiedRules.Yujiazhu.prayer_started(self,frame):return','\tif VerifiedRules.MirrorSong.before_attack(self,frame):return\n\tif VerifiedRules.Yujiazhu.prayer_started(self,frame):return')
function(gs,'_offer_attack_responses','\tvar victim := 1-owner','\tvar victim := int(frame.options.get("combatVictim",1-owner))')
function(gs,'_resolve_combat_hit','\tvar victim := 1 - owner','\tvar victim := int(frame.options.get("combatVictim",1-owner))')
function(gs,'_resolve_combat_hit','\tVerifiedRules.Mianqiling.combat_prepare(self,frame)','\tVerifiedRules.MirrorSong.combat_prepare(self,frame)\n\tVerifiedRules.Mianqiling.combat_prepare(self,frame)')
function(gs,'_resolve_combat_hit','\t\tif options.get("lightZeroAttack", false): power = 0','\t\tpower=maxi(0,power+int(options.get("msAttackDelta",0)))\n\t\tif options.get("lightZeroAttack", false): power = 0')
function(gs,'_resolve_combat_hit','\t\tvar counter_power := VerifiedRules.Combat.power(self, victim, defender, int(frame.get("defenderBonus", 0)))','\t\tvar counter_power := VerifiedRules.Combat.power(self, victim, defender, int(frame.get("defenderBonus", 0)))\n\t\tcounter_power=maxi(0,counter_power+int(options.get("msCounterDelta",0)))')
function(gs,'_finish_combat','\tVerifiedRules.Susanoo.finish_duel(self,options)','\tVerifiedRules.MirrorSong.combat_finished(self,owner,src,options)\n\tVerifiedRules.Susanoo.finish_duel(self,options)')
function('godot/scripts/movement_rules.gd','counterstrike',' var owner := 1 - int(frame.playerIndex)',' var victim := int(frame.playerIndex)\n var owner := int(frame.options.get("combatVictim",1-victim))')
function('godot/scripts/movement_rules.gd','counterstrike','gs.player(1 - owner).units[target]','gs.player(victim).units[target]')
function('godot/scripts/movement_rules.gd','counterstrike','gs, owner, src, 1 - owner, target','gs, owner, src, victim, target')
function('godot/scripts/movement_rules.gd','counterstrike','_strike(owner, src, 1 - owner, target','_strike(owner, src, victim, target')
# Susanoo's duel preparation also receives a complete combat frame.
function('godot/scripts/susanoo_rules.gd','begin_duel','var victim:=1-owner','var victim:=int(frame.options.get("combatVictim",1-owner))')
link='godot/scripts/link_rules.gd'
function(link,'candidates','\tvar result:Array=gs.VerifiedRules.BlackWhite.link_candidates(gs,owner,card)','\tvar ms_pool:Array=gs.VerifiedRules.MirrorSong.candidates(gs,owner,card)\n\tif not ms_pool.is_empty():return ms_pool\n\tvar result:Array=gs.VerifiedRules.BlackWhite.link_candidates(gs,owner,card)')
function(link,'start','\tif ready_hand(gs,owner)>=0 or not gs.pending_choice.is_empty():return false','\tvar ms_link=gs.VerifiedRules.MirrorSong.start_link(gs,owner,index)\n\tif ms_link!=null:return bool(ms_link)\n\tif ready_hand(gs,owner)>=0 or not gs.pending_choice.is_empty():return false')
function(link,'option_ready','\treturn {"hand":choice.hand','\tif choice.get("msLink",false):return preload("res://scripts/mirror_song_rules.gd").ready(choice,selected)\n\treturn {"hand":choice.hand')
function(link,'take','\tvar p:Dictionary=gs.player(owner);var ready:Dictionary=p.get("linkReady",{})','\tvar ms_taken=gs.VerifiedRules.MirrorSong.take_link(gs,owner,index)\n\tif ms_taken!=null:return ms_taken\n\tvar p:Dictionary=gs.player(owner);var ready:Dictionary=p.get("linkReady",{})')
function(link,'take','\t\treturn selected','\t\tgs.VerifiedRules.MirrorSong.link_taken(gs,owner)\n\t\treturn selected')
function(link,'completed','\tif not card.get("linkedUse",false) or not card.has("linkOtherId"):return','\tif card.get("msLinked",false):gs.VerifiedRules.MirrorSong.link_completed(gs,owner,card);return\n\tif not card.get("linkedUse",false) or not card.has("linkOtherId"):return')
edit('godot/scripts/game_ai.gd','\tvar yi_choice=gs.VerifiedRules.Yi.ai_choice(gs,p_idx)','\tvar ms_choice=gs.VerifiedRules.MirrorSong.ai_choice(gs,p_idx)\n\tif ms_choice!=null:return bool(ms_choice)\n\tvar yi_choice=gs.VerifiedRules.Yi.ai_choice(gs,p_idx)')
edit('godot/scripts/game_ai.gd','\tvar yi_score=_gs.VerifiedRules.Yi.score_card(_gs,p_idx,card,_target)','\tvar ms_score=_gs.VerifiedRules.MirrorSong.score_card(_gs,p_idx,card,_target)\n\tif ms_score!=null:return int(ms_score)\n\tvar yi_score=_gs.VerifiedRules.Yi.score_card(_gs,p_idx,card,_target)')
edit('godot/scripts/ui/battle_screen.gd','\t\tvar yi_choice_card=gs.VerifiedRules.Yi.choice_card(gs,PLAYER,str(iid))','\t\tvar ms_choice_card=gs.VerifiedRules.MirrorSong.choice_card(gs,PLAYER,str(iid))\n\t\tif ms_choice_card!=null:def=ms_choice_card\n\t\tvar yi_choice_card=gs.VerifiedRules.Yi.choice_card(gs,PLAYER,str(iid))')
edit('godot/scripts/ui/battle_status.gd','\tview.yiMarks=gs.VerifiedRules.Yi.marks(gs,owner,idx)','\tview.msMarks=gs.VerifiedRules.MirrorSong.marks(gs,owner,view)\n\tview.yiMarks=gs.VerifiedRules.Yi.marks(gs,owner,idx)')
edit('godot/scripts/ui/battle_status.gd','\tfor detail in unit.get("yiMarks",[]):result.append','\tfor detail in unit.get("msMarks",[]):result.append(mark("mirror-song",str(detail),str(detail),"a9c4bf"))\n\tfor detail in unit.get("yiMarks",[]):result.append')
edit('scripts/godot-verify.sh','verify_mianqiling verify_yi','verify_mianqiling verify_mirror_song verify_yi')
for path,name,old,new,count in edits:
 s=changed.get(path,(root/path).read_text())
 if name:
  import re
  pattern=r'(?m)^(?:static )?func '+re.escape(name)+r'\('
  match=re.search(pattern,s);assert match,(path,name)
  end=re.search(r'(?m)^(?:static )?func ',s[match.end():]);stop=match.end()+end.start() if end else len(s)
  block=s[match.start():stop];assert block.count(old)==count,(path,name,old,block.count(old))
  s=s[:match.start()]+block.replace(old,new)+s[stop:]
 else:
  assert s.count(old)==count,(path,old,s.count(old));s=s.replace(old,new)
 changed[path]=s
import sys
if "--check" not in sys.argv:
 for path,s in changed.items():(root/path).write_text(s)
print('MIRROR_SONG_SHARED_HOOKS',len(edits),'edits',len(changed),'files')
