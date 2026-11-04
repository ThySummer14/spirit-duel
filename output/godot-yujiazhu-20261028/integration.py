from pathlib import Path
root=Path(__file__).resolve().parents[2]
def edit(path, old, new, count=1):
 p=root/path;s=p.read_text();assert s.count(old)==count,(path,old,s.count(old),count);p.write_text(s.replace(old,new))
edit('godot/scripts/verified_card_rules.gd','const BoxMaiden := preload("res://scripts/box_maiden_rules.gd")','const BoxMaiden := preload("res://scripts/box_maiden_rules.gd")\nconst Yujiazhu := preload("res://scripts/yujiazhu_rules.gd")')
edit('godot/scripts/verified_card_rules.gd','\tif Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true','\tif Yujiazhu.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
edit('godot/scripts/verified_card_rules.gd','\tBoxMaiden.end_turn(gs,p_idx)','\tYujiazhu.end_turn(gs)\n\tBoxMaiden.end_turn(gs,p_idx)')
edit('godot/scripts/verified_card_rules.gd','\tFutakuchi.knocked_out(unit)','\tYujiazhu.knocked_out(unit)\n\tFutakuchi.knocked_out(unit)')
edit('godot/scripts/verified_card_rules.gd','\tLink.announced(gs,frame,announced)','\tYujiazhu.announced(gs,frame,announced)\n\tLink.announced(gs,frame,announced)')
edit('godot/scripts/verified_card_rules.gd','\t\tif not DogDemon.can_use(gs, owner, card): continue','\t\tif not Yujiazhu.can_use(gs,owner,card):continue\n\t\tif not DogDemon.can_use(gs, owner, card): continue')
edit('godot/scripts/verified_card_rules.gd','\t\tif card.get("owlInterfere",false): actual_target = gs.player(int(continuation.playerIndex)).units[int(continuation.sourceIndex)].uid','\t\tif card.get("owlInterfere",false) or (card.get("yujiazhuRules",false) and card.id=="c18904"): actual_target = gs.player(int(continuation.playerIndex)).units[int(continuation.sourceIndex)].uid')
edit('godot/scripts/game_state.gd','\tcard = VerifiedRules.SeaButterfly.describe_card(self,p_idx,inst,card)','\tcard = VerifiedRules.Yujiazhu.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.SeaButterfly.describe_card(self,p_idx,inst,card)')
edit('godot/scripts/game_state.gd','\tvar black_white_targets=VerifiedRules.BlackWhite.targets(self,p_idx,card)','\tvar yuj_targets=VerifiedRules.Yujiazhu.targets(self,p_idx,card)\n\tif yuj_targets!=null:return yuj_targets\n\tvar black_white_targets=VerifiedRules.BlackWhite.targets(self,p_idx,card)')
edit('godot/scripts/game_state.gd','\tif not VerifiedRules.Futakuchi.can_use(self,p_idx,card):return {"ok":false,"reason":"二口女已经觉醒。"}','\tif not VerifiedRules.Yujiazhu.can_use(self,p_idx,card):return {"ok":false,"reason":"御馔津已觉醒或符箭爆能不能支付。"}\n\tif not VerifiedRules.Futakuchi.can_use(self,p_idx,card):return {"ok":false,"reason":"二口女已经觉醒。"}')
edit('godot/scripts/game_state.gd','func _resolve_frame(frame: Dictionary) -> void:\n','func _resolve_frame(frame: Dictionary) -> void:\n\tif VerifiedRules.Yujiazhu.resolve_frame(self,frame):return\n')
anchor='\tif int(frame.get("combatResponseId", -1)) >= 0 and effects[idx].get("action") in ["assault", "fortune-combat", "movement-combat"]:'
edit('godot/scripts/game_state.gd',anchor,'\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="yuj-talisman":\n\t\tVerifiedRules.Yujiazhu.respond_combat(self,int(frame.combatResponseId),p_idx,src,card,target_id)\n\t\treturn\n'+anchor)
edit('godot/scripts/game_state.gd','\tVerifiedRules.Futakuchi.form_entered(self,p_idx,src,card)','\tVerifiedRules.Yujiazhu.form_entered(self,p_idx,src,card)\n\tVerifiedRules.Futakuchi.form_entered(self,p_idx,src,card)')
edit('godot/scripts/game_state.gd','\tvar toxic_lethal:=VerifiedRules.Toxic.damaged(self,_src_player,source_index,p_idx,unit_index,taken,combat)','\tvar yuj_doom:=VerifiedRules.Yujiazhu.damaged(self,u,taken)\n\tvar toxic_lethal:=VerifiedRules.Toxic.damaged(self,_src_player,source_index,p_idx,unit_index,taken,combat)')
edit('godot/scripts/game_state.gd','\tif int(u.hp) <= 0 or toxic_lethal:','\tif int(u.hp) <= 0 or toxic_lethal or yuj_doom:')
edit('godot/scripts/game_state.gd','\tif forced!=null: return [forced]','\tif forced!=null: return [forced]\n\tvar yuj_targets=VerifiedRules.Yujiazhu.prayer_targets(self,p_idx,unit_index)\n\tif yuj_targets!=null:return yuj_targets')
edit('godot/scripts/game_state.gd','\tif VerifiedRules.SilkNinja.before_response(self,frame): return','\tif VerifiedRules.SilkNinja.before_response(self,frame): return\n\tif VerifiedRules.Yujiazhu.prayer_started(self,frame):return')
edit('godot/scripts/game_state.gd','\tif fi >= 0: VerifiedRules.Movement.deer_combat(self, e_idx, fi)','\tVerifiedRules.Yujiazhu.prepare_attack(self,frame,fi)\n\tif fi >= 0: VerifiedRules.Movement.deer_combat(self, e_idx, fi)')
edit('godot/scripts/combat_keyword_rules.gd','or (idx>=0 and options.get("headlessUnitCrit",false)))','or (idx>=0 and options.get("headlessUnitCrit",false)) or (idx>=0 and options.get("yujCritical",false)))')
edit('godot/scripts/ui/battle_status.gd','\tview.futakuchiMarks=gs.VerifiedRules.Futakuchi.marks(gs,owner,idx)','\tview.yujMarks=gs.VerifiedRules.Yujiazhu.marks(gs,owner,idx)\n\tview.futakuchiMarks=gs.VerifiedRules.Futakuchi.marks(gs,owner,idx)')
edit('godot/scripts/ui/battle_status.gd','\tfor detail in unit.get("futakuchiMarks",[]):','\tfor detail in unit.get("yujMarks",[]):result.append(mark("yuj-rule",str(detail),str(detail),"c5b373"))\n\tfor detail in unit.get("futakuchiMarks",[]):')
# Only explicit 爆能 calls get a discount. Revive/abilities retain charge payment.
edit('godot/scripts/movement_rules.gd','Charge.can_pay_charge(gs, owner, src, amount)','gs.VerifiedRules.Yujiazhu.can_pay_burst(gs, owner, src, amount)',2)
edit('godot/scripts/movement_rules.gd','Charge.can_pay_charge(gs, owner, src, int(amount))','gs.VerifiedRules.Yujiazhu.can_pay_burst(gs, owner, src, int(amount))',2)
edit('godot/scripts/movement_rules.gd','if amount > 0 and not Charge.pay_charge(gs, owner, src, amount):','if amount > 0 and not gs.VerifiedRules.Yujiazhu.pay_burst(gs, owner, src, amount):')
anchor=' card.text = "不消耗能量。" if amount == 0 else "使用本牌并选择爆能%d。" % amount'
edit('godot/scripts/movement_rules.gd',anchor,anchor+'\n if amount>0:\n  var src:int=gs._source_index(owner,card)\n  var q:Dictionary=gs.VerifiedRules.Yujiazhu.quote_burst(gs,owner,src,amount)\n  card.currentCardStats="爆能%d · 支付%d能量"%[amount,int(q.amount)]\n  card.text="选择后支付%d能量；效果仍按爆能%d结算。"%[int(q.amount),amount]')
edit('godot/scripts/whale_rules.gd','Charge.can_pay_charge(gs,owner,src,n)','gs.VerifiedRules.Yujiazhu.can_pay_burst(gs,owner,src,n)')
edit('godot/scripts/whale_rules.gd','Charge.can_pay_charge(gs,owner,src,int(n))','gs.VerifiedRules.Yujiazhu.can_pay_burst(gs,owner,src,int(n))')
edit('godot/scripts/whale_rules.gd','Charge.pay_charge(gs,owner,src,amount)','gs.VerifiedRules.Yujiazhu.pay_burst(gs,owner,src,amount)')
edit('godot/scripts/box_maiden_rules.gd','card.boxBurstPaid=Charge.pay_charge(gs,owner,src,10)','card.boxBurstPaid=gs.VerifiedRules.Yujiazhu.pay_burst(gs,owner,src,10)')
edit('godot/scripts/sun_smoke_rules.gd','if pay_charge(gs, owner, src, energy):','if gs.VerifiedRules.Yujiazhu.pay_burst(gs, owner, src, energy):')
anchor='\tvar out := card.duplicate(true)\n\tout.id = iid'
edit('godot/scripts/sun_smoke_rules.gd',anchor,'\tvar cost:int=int(gs.VerifiedRules.Yujiazhu.quote_burst(gs,owner,int(choice.sourceIndex),amount).amount)\n'+anchor)
edit('godot/scripts/sun_smoke_rules.gd','"消耗全部%d能量，本次伤害额外+%d。%s" % [amount, amount,','"爆能%d：支付%d能量，本次伤害额外+%d。%s" % [amount, cost, amount,')
# Registration is added last so partially applied scripts cannot claim verification.
edit('scripts/godot-verify.sh','verify_two_faces verify_link_cross','verify_two_faces verify_link_cross verify_yujiazhu')
print('YUJIAZHU_SHARED_HOOKS_INSTALLED')
