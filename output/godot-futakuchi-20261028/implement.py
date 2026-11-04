from pathlib import Path
import json,re,hashlib,shutil
root=Path.cwd();out=root/'output/godot-futakuchi-20261028';p=root/'godot/content/verified_rules.json';v=json.loads(p.read_text());raw={int(x['id']):x for x in json.loads((root/'research-data/cards.json').read_text())}
artread=root/'godot/assets/official/README.md';dest=out/'before/godot/assets/official/README.md';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(artread,dest);h=json.loads((out/'before-hashes.json').read_text());h[str(artread.relative_to(root))]=hashlib.sha256(artread.read_bytes()).hexdigest();(out/'before-hashes.json').write_text(json.dumps(h,indent=2)+'\n')
sid='futakuchi-original-20261028';pending=['按29500–29508完整原PNG和官网基础牌文接入，未逐牌覆盖指定录像；保留原客户端核验。','专注替代能量不足时的普通鬼火回退、自动用牌、共生与幻境/攻击触发全序及多源伤害增强组合仍待原客户端核验。']
v['sources'].append({'id':sid,'kind':'official-card-art','path':'research-notes/81-futakuchi-rules.md','url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js'})
v['units']['erkounv']={'verifiedRules':True,'futakuchiRules':True,'nativeCharge':True,'attack':2,'maxHp':6,'keywords':['charge'],'passive':{'id':'futakuchi-base','name':'二口','text':raw[29500]['desc'].replace('#[能量]','能量'),'hooks':[]},'awakenedPassive':{'id':'futakuchi-awake','name':'二口','text':'充能。己方式神使用有专注效果的牌时，消耗二口女的2能量代替专注的额外鬼火消耗。','hooks':[]},'formLifecycle':{},'sources':[sid],'verificationPending':pending}
for n in range(29501,29509):
 r=raw[n];i=n%100;typ={'法术':'spell','战斗':'combat','形态':'form','结界':'realm'}[r['type']];txt=re.sub(r'#\[([^]]+)\]',r'\1',r['desc'].split('&')[0].replace('#r','\n'))
 c={'verifiedRules':True,'futakuchiRules':True,'type':typ,'typeLabel':{'spell':'法术牌','combat':'战斗牌','form':'形态牌','realm':'幻境牌'}[typ],'level':r['stage'],'cost':1,'text':txt,'officialText':txt,'target':'auto','effect':'futakuchi-'+str(i),'value':0,'effects':[],'keywords':[],'formRules':{},'formHooks':[],'formAbility':'','timing':'main','responseTo':[],'autoResponse':'','sources':[sid],'verificationPending':pending}
 focus={'action':'futakuchi-focus','target':'source'}
 if i!=6:c['focusEffect']=f'c{n}'
 if typ=='combat':
  c['value']=r['ll'];c['combatOption']={'shield':r['sm'] or 0};c['responseAction']='assault';c['effects']=[focus,{'action':'futakuchi-combat','target':'source','value':r['ll']}]
 if i in [2,6]:
  c['effect']='form';c['value']={'attack':r['ll'],'hp':r['sm'],'setBase':True};c['formAbility']=txt;c['effects']=[{'action':'form','target':'source','value':c['value']}]
  if i==2:c['effects'].append(focus)
  else:c['formRules']={'futakuchiSymbiosis':True}
 if i==3:c['realm']={'hp':5,'nativeRealm':'futakuchi-fear','trigger':'none'};c['effects']=[{'action':'realm','target':'source'},focus]
 if i==4:c['target']='enemy-unit';c['combatOption']['pursuit']=True
 if i==5:c['value']={'attack':1,'hp':1};c['effects']=[focus,{'action':'awaken','target':'source','value':c['value']}]
 if i in [5,7]:c['keywords']=['instant']
 if i==8:c['target']='enemy-unit';c['responseAction']='damage';c['effects']=[{'action':'futakuchi-damage','target':'selected','value':6},focus]
 v['cards'][f'c{n}']=c
p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def edit(name,a,b):
 p=root/name;s=p.read_text();assert s.count(a)==1,(name,a,s.count(a));p.write_text(s.replace(a,b,1))
edit('godot/scripts/verified_card_rules.gd','const Lantern :=','const Focus := preload("res://scripts/focus_rules.gd")\nconst Futakuchi := preload("res://scripts/futakuchi_rules.gd")\nconst Lantern :=')
edit('godot/scripts/verified_card_rules.gd','\tif Lantern.resolve_action','\tif Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif Lantern.resolve_action')
edit('godot/scripts/verified_card_rules.gd','\tLantern.knocked_out(unit)','\tFutakuchi.knocked_out(unit)\n\tLantern.knocked_out(unit)')
edit('godot/scripts/game_state.gd','\tcard = VerifiedRules.Lantern.describe_card','\tcard = VerifiedRules.Futakuchi.describe_card(self,p_idx,card)\n\tcard = VerifiedRules.Lantern.describe_card')
edit('godot/scripts/game_state.gd','\tif card.get("lanternFocus",false):\n\t\tpayment.focusPaid=int(player(p_idx).energy)>int(payment.cost)\n\t\tif payment.focusPaid:payment.cost=int(payment.cost)+1\n\treturn payment','\treturn VerifiedRules.Focus.quote(self,p_idx,card,payment)')
edit('godot/scripts/game_state.gd','\tif card.get("lanternFocus",false):card.lanternFocused=bool(payment.get("focusPaid",false))','\tVerifiedRules.Focus.commit(self,p_idx,card,payment)')
edit('godot/scripts/game_state.gd','\tcard=VerifiedRules.Lantern.prepare_automatic(self,p_idx,card,automatic)','\tcard=VerifiedRules.Focus.automatic(self,p_idx,card,automatic)')
edit('godot/scripts/game_state.gd','\tif not VerifiedRules.Lantern.can_use','\tif not VerifiedRules.Futakuchi.can_use(self,p_idx,card):return {"ok":false,"reason":"二口女已经觉醒。"}\n\tif not VerifiedRules.Lantern.can_use')
edit('godot/scripts/game_state.gd','\tif VerifiedRules.Lantern.resolve_frame','\tif VerifiedRules.Futakuchi.resolve_frame(self,frame):return\n\tif VerifiedRules.Lantern.resolve_frame')
edit('godot/scripts/game_state.gd','\tVerifiedRules.Butterfly.form_entered','\tVerifiedRules.Futakuchi.form_entered(self,p_idx,src,card)\n\tVerifiedRules.Butterfly.form_entered')
edit('godot/scripts/game_state.gd','\tif VerifiedRules.Headless.attack_started(self,frame): return','\tif VerifiedRules.Headless.attack_started(self,frame): return\n\tif VerifiedRules.Futakuchi.attack_started(self,frame):return')
edit('godot/scripts/game_state.gd','or bool(u.get("owlUnyielding",false))','or bool(u.get("futakuchiUnyielding",false)) or bool(u.get("owlUnyielding",false))')
edit('godot/scripts/game_state.gd','\t\tu.unyielding = false','\t\tu.unyielding = false\n\t\tu.erase("futakuchiUnyielding")')
edit('godot/scripts/game_ai.gd','\tvar lantern_score=','\tvar futakuchi_score=_gs.VerifiedRules.Futakuchi.score_card(_gs,p_idx,card)\n\tif futakuchi_score!=null:return int(futakuchi_score)\n\tvar lantern_score=')
edit('godot/scripts/ui/battle_status.gd','\tview.lanternMarks=','\tview.futakuchiMarks=gs.VerifiedRules.Futakuchi.marks(gs,owner,idx)\n\tview.lanternMarks=')
edit('godot/scripts/ui/battle_status.gd','\tfor detail in unit.get("lanternMarks",[]):','\tfor detail in unit.get("futakuchiMarks",[]):result.append(mark("futakuchi-rule",str(detail),str(detail),"a8bf8b"))\n\tfor detail in unit.get("lanternMarks",[]):')
edit('godot/scripts/ui/battle_screen.gd','\t\telif entry.kind == "lantern-focus" and widget != null:','\t\telif entry.kind in ["futakuchi-focus","focus-energy-paid","futakuchi-symbiosis"] and widget!=null:\n\t\t\tvar label:String="共生 · "+str(entry.get("name","")) if entry.kind=="futakuchi-symbiosis" else "能量替代专注" if entry.kind=="focus-energy-paid" else "专注"\n\t\t\t_floating_on_unit(label,widget,Color("a8bf8b"),18,impact)\n\t\telif entry.kind == "lantern-focus" and widget != null:')
edit('godot/scripts/ui/keyword_glossary.gd','使用牌支付基本鬼火后，若仍有鬼火，强制额外消耗1点并执行专注效果。','使用牌支付基本鬼火后，若仍有鬼火，强制额外消耗1点并执行专注效果。二口女可消耗2能量代替；觉醒后也替其他己方式神支付。')
edit('scripts/godot-verify.sh','verify_lantern verify_combat','verify_lantern verify_futakuchi verify_combat')
p=root/'godot/scripts/lantern_rules.gd';s=p.read_text();start=s.index('static func prepare_automatic(');end=s.index('static func store_card(',start);s=s[:start]+s[end:];s=s.replace('c.currentCardStats="专注 · 额外消耗1鬼火 · "+','c.currentCardStats=gs.VerifiedRules.Focus.label(gs.card_payment(owner,c))+" · "+').replace('else "没有剩余鬼火 · 本次不触发专注"','else gs.VerifiedRules.Focus.label(gs.card_payment(owner,c))');p.write_text(s)
print('FUTAKUCHI_INTEGRATION_DONE')
