from pathlib import Path
import json,re,subprocess
root=Path.cwd();out=root/'output/godot-lantern-20261027';p=root/'godot/content/verified_rules.json';v=json.loads(p.read_text());raw={int(x['id']):x for x in json.loads((root/'research-data/cards.json').read_text())};js=(out/'official-index.js').read_text();matches=[]
for n in range(29300,29309):
 m=re.search(r'\{id:'+str(n)+r',.*?\}',js);assert m
 x=json.loads(subprocess.run(['node','-e','process.stdout.write(JSON.stringify(('+m.group(0)+')))'],capture_output=True,text=True,check=True).stdout);assert x==raw[n];matches.append(x)
(out/'official-source-evidence.json').write_text(json.dumps({'url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','matched':matches},ensure_ascii=False,indent=2)+'\n')
sid='lantern-original-20261027';pending=['按29300–29308完整原卡面和官网基础牌文实现；指定录像尚未逐牌覆盖，保留原客户端核验。','蓄力与回合开始多能力全序、致死伤害运势/即时复活及额外攻击的复杂联动仍待实机核验；专注自动使用及随机分配伤害增强组合待核验。']
v['sources'].append({'id':sid,'kind':'official-card-art','path':'research-notes/80-lantern-rules.md','url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js'})
v['units']['gulonghuo']={'verifiedRules':True,'lanternRules':True,'attack':2,'maxHp':5,'passive':{'id':'lantern-base','name':'笼火','text':raw[29300]['desc'].split('&')[0],'hooks':[]},'awakenedPassive':{'id':'lantern-awake','name':'笼火','text':'气绝时投射2，每次复活永久+1；己方回合开始时，若已气绝，运势4：气绝倒计时-1。','hooks':[]},'formLifecycle':{},'sources':[sid],'verificationPending':pending}
for n in range(29301,29309):
 r=raw[n];typ={'法术':'spell','战斗':'combat','形态':'form','结界':'realm'}[r['type']];txt=r['desc'].split('&')[0].replace('#r','\n');txt=re.sub(r'#\[([^]]+)\]',r'\1',txt)
 c={'verifiedRules':True,'lanternRules':True,'type':typ,'typeLabel':{'spell':'法术牌','combat':'战斗牌','form':'形态牌','realm':'幻境牌'}[typ],'level':int(r['stage']),'cost':1,'text':txt,'officialText':txt,'target':'auto','effect':'lantern-'+str(n%100),'value':0,'effects':[],'keywords':[],'formRules':{},'formHooks':[],'formAbility':'','timing':'main','responseTo':[],'autoResponse':'','sources':[sid],'verificationPending':pending}
 action={1:'lantern-revive-one',2:'lantern-combat',3:'lantern-burn',4:'form',5:'lantern-awaken',6:'lantern-combat',7:'lantern-realm',8:'lantern-release'}[n%100]
 if n in [29301,29305,29307]:c['allowKnockedSource']=True
 if n in [29301,29302]:c['keywords']=['instant']
 if n in [29302,29306]:
  c['lanternFocus']=True;c['value']=int(r['ll']);c['combatOption']={'shield':int(r['sm'])};c['responseAction']='assault'
 if n==29304:
  c['effect']='form';c['value']={'attack':3,'hp':9,'setBase':True};c['formRules']={'lanternDrift':True};c['formAbility']=txt
 if n==29305:c['value']={'attack':1,'hp':1}
 if n==29306:c['target']='enemy';c['combatOption']['pursuit']=True
 if n==29307:c['realm']={'hp':8,'nativeRealm':'lantern-luck','trigger':'none'}
 if n==29308:c['chargeOnly']=True;c['responseAction']='damage'
 c['effects']=[{'action':action,'target':'source','value':c['value']}]
 v['cards'][f'c{n}']=c
p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def edit(name,a,b):
 p=root/name;s=p.read_text();assert s.count(a)==1,(name,a,s.count(a));p.write_text(s.replace(a,b,1))
edit('godot/scripts/verified_card_rules.gd','const SeaButterfly :=','const Lantern := preload("res://scripts/lantern_rules.gd")\nconst SeaButterfly :=')
edit('godot/scripts/verified_card_rules.gd','\tif SeaButterfly.resolve_action(gs,p_idx,src,card,effect,target): return true','\tif Lantern.resolve_action(gs,p_idx,src,card,effect,target_id): return true\n\tif SeaButterfly.resolve_action(gs,p_idx,src,card,effect,target): return true')
edit('godot/scripts/verified_card_rules.gd','\tunit.erase("seaSpirit")','\tunit.erase("lanternStored")\n\tunit.erase("seaSpirit")')
edit('godot/scripts/movement_rules.gd','static func revived(gs, owner: int, idx: int) -> void:\n','static func revived(gs, owner: int, idx: int) -> void:\n gs.VerifiedRules.Lantern.revived(gs,owner,idx)\n')
edit('godot/scripts/game_state.gd','\tcard = VerifiedRules.SeaButterfly.describe_card(self,p_idx,inst,card)','\tcard = VerifiedRules.Lantern.describe_card(self,p_idx,card)\n\tcard = VerifiedRules.SeaButterfly.describe_card(self,p_idx,inst,card)')
edit('godot/scripts/game_state.gd','\tif not VerifiedRules.SeaButterfly.can_use','\tif not VerifiedRules.Lantern.can_use(self,p_idx,card): return {"ok":false,"reason":"古笼火已经觉醒、正在蓄力或无法复活。"}\n\tif not VerifiedRules.SeaButterfly.can_use')
edit('godot/scripts/game_state.gd','\treturn {"cost": (0 if three_tail_free','\tvar payment := {"cost": (0 if three_tail_free')
edit('godot/scripts/game_state.gd','"ownTurn": current_player == p_idx, "response": not response_window.is_empty()}','"ownTurn": current_player == p_idx, "response": not response_window.is_empty()}\n\tif card.get("lanternFocus",false):\n\t\tpayment.focusPaid=int(player(p_idx).energy)>int(payment.cost)\n\t\tif payment.focusPaid:payment.cost=int(payment.cost)+1\n\treturn payment')
edit('godot/scripts/game_state.gd','\tvar payment := card_payment(p_idx, card)\n\trecord_args.payment','\tvar payment := card_payment(p_idx, card)\n\tif card.get("chargeOnly",false):return VerifiedRules.Lantern.store_card(self,p_idx,hand_index,card,payment)\n\tif card.get("lanternFocus",false):card.lanternFocused=bool(payment.get("focusPaid",false))\n\trecord_args.payment')
edit('godot/scripts/game_state.gd','\tvar fire_frames := VerifiedRules.Moon.card_frames(self,p_idx)','\tcard=VerifiedRules.Lantern.prepare_automatic(self,p_idx,card,automatic)\n\tvar fire_frames := VerifiedRules.Moon.card_frames(self,p_idx)')
edit('godot/scripts/game_state.gd','func _resolve_frame(frame: Dictionary) -> void:\n','func _resolve_frame(frame: Dictionary) -> void:\n\tif VerifiedRules.Lantern.resolve_frame(self,frame):return\n')
edit('godot/scripts/game_state.gd','\tVerifiedRules.SpiderLily.unit_damaged(self,p_idx,unit_index,unshielded)','\tVerifiedRules.Lantern.damaged(self,p_idx,unit_index,taken)\n\tVerifiedRules.SpiderLily.unit_damaged(self,p_idx,unit_index,unshielded)')
edit('godot/scripts/game_state.gd','\tvar jorogumo_saved :=','\tvar lantern_saved:=VerifiedRules.Lantern.death_frames(self,victim,u)\n\tvar jorogumo_saved :=')
edit('godot/scripts/game_state.gd','\tresolution_stack.append_array(silk_saved)','\tresolution_stack.append_array(silk_saved)\n\tresolution_stack.append_array(lantern_saved)')
edit('godot/scripts/game_state.gd','\tVerifiedRules.SilkNinja.turn_start(self,p_idx)','\tVerifiedRules.Lantern.turn_start(self,p_idx)\n\tVerifiedRules.SilkNinja.turn_start(self,p_idx)')
edit('godot/scripts/game_ai.gd','\tvar sea_score=','\tvar lantern_score=_gs.VerifiedRules.Lantern.score_card(_gs,p_idx,card)\n\tif lantern_score!=null:return int(lantern_score)\n\tvar sea_score=')
edit('godot/scripts/ui/battle_status.gd','\tview.seaSpiritMarks=','\tview.lanternMarks=gs.VerifiedRules.Lantern.marks(gs,owner,idx)\n\tview.seaSpiritMarks=')
edit('godot/scripts/ui/battle_status.gd','\tfor detail in unit.get("seaSpiritMarks",[]):','\tfor detail in unit.get("lanternMarks",[]):result.append(mark("lantern-rule",str(detail),str(detail),"e2ad70"))\n\tfor detail in unit.get("seaSpiritMarks",[]):')
edit('godot/scripts/ui/keyword_glossary.gd','const ENTRIES := {','const ENTRIES := {\n\t"lantern-charge": ["蓄力", "消耗正常鬼火移出手牌并记录；下个己方回合开始自动施放。一个式神同时只能蓄力一张，气绝移除，眩晕时不能触发。"],\n\t"lantern-focus": ["专注", "使用牌支付基本鬼火后，若仍有鬼火，强制额外消耗1点并执行专注效果。"],')
edit('scripts/godot-verify.sh','verify_sea_butterfly verify_combat','verify_sea_butterfly verify_lantern verify_combat')
print('LANTERN_INTEGRATION_DONE')
