from pathlib import Path
import json

def edit(path,a,b):
 p=Path(path);s=p.read_text();assert s.count(a)==1,(path,a,s.count(a));p.write_text(s.replace(a,b))
p='godot/scripts/verified_card_rules.gd'
edit(p,'const Crocodile :=','const Baize := preload("res://scripts/baize_rules.gd")\nconst Crocodile :=')
edit(p,'\tif Crocodile.resolve_action','\tif Baize.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true\n\tif Crocodile.resolve_action')
edit(p,'static func end_turn(gs, p_idx: int) -> void:\n','static func end_turn(gs, p_idx: int) -> void:\n\tBaize.end_turn(gs)\n')
edit(p,'static func knocked_out(unit: Dictionary) -> void:\n','static func knocked_out(unit: Dictionary) -> void:\n\tBaize.clear_temporary(unit)\n')
p='godot/scripts/game_state.gd'
edit(p,'\tif is_divination: want += VerifiedRules.Eye.bonus(self, p_idx)','\tif is_divination and VerifiedRules.Baize.present(self):\n\t\tVerifiedRules.Divination.start(self,p_idx,want)\n\t\treturn\n\tif is_divination: want += VerifiedRules.Eye.bonus(self, p_idx)')
edit(p,'for targets in [VerifiedRules.Crocodile.targets','for targets in [VerifiedRules.Baize.targets(self,p_idx,card),VerifiedRules.Crocodile.targets')
edit(p,'\tif not VerifiedRules.Crocodile.can_use','\tif not VerifiedRules.Baize.can_use(self,p_idx,card): return {"ok":false,"reason":"白泽已经觉醒。"}\n\tif not VerifiedRules.Crocodile.can_use')
edit(p,'\tif VerifiedRules.Whale.resolve_frame','\tif VerifiedRules.Baize.resolve_frame(self,frame): return\n\tif VerifiedRules.Whale.resolve_frame')
edit(p,'\t\t\t\tVerifiedRules.BookJue.turn_start(self, p_idx, i)','\t\t\t\tVerifiedRules.Baize.turn_start(self,p_idx,i)\n\t\t\t\tVerifiedRules.BookJue.turn_start(self, p_idx, i)')
p='godot/scripts/battle_skill_rules.gd';edit(p,'\t\t\tgs.VerifiedRules.Crocodile.before_basic','\t\t\tgs.VerifiedRules.Baize.before_basic(gs,owner,src)\n\t\t\tgs.VerifiedRules.Crocodile.before_basic')
p='godot/scripts/game_ai.gd';edit(p,'\tvar croc_score =','\tvar baize_score = _gs.VerifiedRules.Baize.score_card(_gs,p_idx,card,_target)\n\tif baize_score != null: return int(baize_score)\n\tvar croc_score =')
p='godot/scripts/ui/battle_status.gd';edit(p,'\tview.crocodileMarks=','\tview.baizeMarks=gs.VerifiedRules.Baize.unit_marks(gs,owner,idx)\n\tview.crocodileMarks=');edit(p,'\tfor detail in unit.get("crocodileMarks",[]):','\tfor detail in unit.get("baizeMarks",[]): result.append(mark("baize-rule",str(detail),str(detail),"a0d0b0"))\n\tfor detail in unit.get("crocodileMarks",[]):')
p='godot/scripts/native_divination_rules.gd'
edit(p,'controller: int = -1) -> void:','controller: int = -1, context: Dictionary = {}) -> void:')
edit(p,'\tvar ids: Array = []','\tcount=gs.VerifiedRules.Baize.prepare_divination(gs,owner,count,controller)\n\tvar ids: Array = []')
edit(p,'\tgs.phase = "choice"','\tgs.pending_choice.merge(context,true)\n\tgs.pending_choice.hint+= " 至少置底%d张。"%int(context.minimumBottom) if int(context.get("minimumBottom",0))>0 else ""\n\tgs.VerifiedRules.Baize.revealed(gs,owner,ids,controller)\n\tgs.phase = "choice"')
edit(p,'\t\tchoice.instanceIds = [TOP, BOTTOM]','\t\tvar required:=mini(int(choice.get("minimumBottom",0)),int(choice.count))-choice.bottom.size()\n\t\tchoice.instanceIds = [BOTTOM] if choice.remaining.size()<=required else [TOP, BOTTOM]')
edit(p,'choice.top.size(), choice.bottom.size()]','choice.top.size(), choice.bottom.size()]\n\t\tif TOP not in choice.instanceIds: choice.hint+=" · 至少置底%d张，本张必须置底"%int(choice.minimumBottom)')
edit(p,'\t\t\tgs.VerifiedRules.Eye.divined(gs, owner, int(choice.count))','\t\t\tgs.VerifiedRules.Eye.divined(gs, owner, int(choice.count))\n\t\t\tgs.VerifiedRules.Baize.completed(gs,choice)')
edit(p,'return resolve_choice(gs, owner, TOP if usable else BOTTOM)','return resolve_choice(gs, owner, BOTTOM if TOP not in choice.instanceIds or gs.VerifiedRules.Baize.prefer_bottom(gs,deck_owner,card) or not usable else TOP)')
p='scripts/godot-verify.sh';edit(p,'verify_crocodile verify_combat','verify_crocodile verify_baize verify_combat')

p=Path('godot/content/verified_rules.json');data=json.loads(p.read_text())
sources=['baize-original-faces','baize-official-snapshot','baize-divination-transcription','baize-official-insertion-erratum']
data['sources'] += [
 {'id':sources[0],'path':'art-reference-official/卡面-按版本/16_远山遥泽/273_白泽','evidence':'27300–27308完整原版PNG；采用此基础版本，不采用新版溯世命倒计时-1。'},
 {'id':sources[1],'url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','evidence':'本地原始27300–27308快照与已保存官方响应逐字段核对。'},
 {'id':sources[2],'url':'https://gamerch.com/onmyojicard/629772','evidence':'达知为瞬发，占卜2，至少置底一张，再抽一张。觉醒每次占卜只抽一张及优先于鬼眸参考https://www.taptap.cn/moment/357693254503760043。'},
 {'id':sources[3],'url':'https://www.taptap.cn/moment/372493675097230067','evidence':'2023-02-09官方勘误：洗入改置入，实际效果不变；承因续果离场仍生效为已修复缺陷。'}]
pending=['按27300–27308基础完整卡面接入，指定录像未逐牌覆盖。达知派生中文原图仍缺；观史通今额外一张的占卜计数、承因续果同名牌逐张叠加、驱邪祸自动施放的气绝/眩晕边界、敌方牌库占卜及多种置底触发全序仍待原客户端逐项核验。觉醒每次占卜至多抽一张及先于鬼眸参考中文实测转录，保留待核对。']
base='己方回合开始或白泽出击时，将一张「达知」置入牌库。'
awake=base+'本局游戏中当你占卜中将「达知」置于牌库底时，抽一张牌。'
data['units']['baize']={'verifiedRules':True,'baizeRules':True,'attack':2,'maxHp':5,'passive':{'id':'baize-knowledge','name':'达知','text':base,'hooks':[]},'awakenedPassive':{'id':'baize-knowledge-awakened','name':'觉醒·白泽','text':awake,'hooks':[]},'formLifecycle':{},'sources':sources,'verificationPending':pending}
texts={1:'当你占卜时，若牌库里有白泽的牌，额外随机选择其中一张置于牌库顶。',2:'气绝时可用\n复活一个己方式神，然后占卜2。\n当此牌在占卜中被置于牌库底时，随机复活一个己方式神。',3:'对所有敌方式神造成2点伤害，然后占卜2。\n当此牌在占卜中被置于牌库底时，将其置入手牌。',4:'战技\n投射：造成等同于白泽力量的伤害，眩晕受到此伤害的式神。\n当此牌在占卜中被置于牌库底时，自动使用此牌。',5:'对一个敌方式神造成5点伤害。\n当此牌在占卜中被置于牌库底时，随机对一个敌方式神造成2点伤害。',6:'占卜3。\n觉醒：'+awake,7:'占卜8，本次占卜中每将一张白泽的牌置于牌库底，便恢复你2生命。\n当此牌在占卜中被置于牌库底时，将一张「达知」置入手牌。',8:'当你占卜中出现任一一张式神的牌时，本回合该式神便+1力量和+1生命。'}
def eff(action,value=0,target='source'):return {'action':action,'target':target,'value':value}
for n in range(1,9):
 id=f'c273{n:02}';form=n in [1,8];e=[];value={'attack':3 if n==1 else 4,'hp':6,'setBase':True} if form else 0
 if form:e=[eff('form',value)]
 elif n==2:e=[eff('baize-revive'),eff('baize-divination',2)]
 elif n==3:e=[eff('damage',2,'all-enemy-units'),eff('baize-divination',2)]
 elif n==4:e=[eff('baize-projectile')]
 elif n==5:e=[eff('damage',5,'selected-enemy')]
 elif n==6:e=[eff('baize-divination',3),eff('baize-awaken')]
 elif n==7:e=[eff('baize-divination',8)]
 c={'verifiedRules':True,'baizeRules':True,'type':'form' if form else 'spell','typeLabel':'形态牌' if form else '法术牌','level':1 if n<=2 or n==4 else 2 if n<=6 else 3,'cost':1,'text':texts[n],'officialText':texts[n],'keywords':['battle-skill','projectile','stun'] if n==4 else [],'timing':'main','responseTo':[],'autoResponse':'','formRules':{'baizeHistory':True} if n==1 else {'baizeCause':True} if n==8 else {},'formHooks':[],'formAbility':texts[n] if form else '', 'target':'knocked-ally' if n==2 else 'enemy-unit' if n==5 else 'auto','effect':e[0]['action'],'value':value,'effects':e,'sources':sources,'verificationPending':pending}
 if n==2:c['allowKnockedSource']=True
 if n==4:c['battleSkill']=True
 if n==7:c['baizeDivination']={'baizeHealPerCard':2}
 data['cards'][id]=c

token={'id':'baize-dazhi','unitId':'baize','name':'达知','type':'spell','typeLabel':'法术牌','level':1,'cost':1,'text':'瞬发\n占卜2，至少将一张牌置于牌库底，抽一张牌。','officialText':'瞬发\n占卜2，至少将一张牌置于牌库底，抽一张牌。','target':'auto','subpack':'yuanshan','deckLimit':0,'copies':0,'starterCopies':0,'token':True,'rarity':'common','keywords':['instant'],'timing':'main','responseTo':[],'pack':'wave6','effect':'baize-dazhi','value':0,'effects':[eff('baize-dazhi')]}
data['cards']['baize-dazhi']={**token,'verifiedRules':True,'baizeRules':True,'sources':sources,'verificationPending':pending}
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
p=Path('godot/content/content.json');d=json.loads(p.read_text());assert not any(c['id']=='baize-dazhi' for c in d['cards']);d['cards'].append(token);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
jst={k:v for k,v in token.items() if k not in ['typeLabel','officialText','copies','starterCopies','timing','responseTo','pack','effect','value']};jst['starter']=0;jst['effects']=[['always','baize-dazhi','source',0]]
edit('game-content-wave6.js','\n]);\n\nexport function getWave6UnitIds()', '\n  wave6Card(0, "baize", '+json.dumps(jst,ensure_ascii=False,indent=2)+'),\n]);\n\nexport function getWave6UnitIds()')
edit('scripts/gen-wave6-content.py','\nEXTRA_TOKENS += ', '\nEXTRA_TOKENS += '+repr([jst])+'\nEXTRA_TOKENS += ')
print('BAIZE_INTEGRATED')
