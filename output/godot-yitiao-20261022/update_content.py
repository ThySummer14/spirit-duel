from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
p=root/'godot/content/verified_rules.json'; data=json.loads(p.read_text())
sources=['yitiao-original-faces','yitiao-official-snapshot','yitiao-training-reference']
pending=['按27600–27608完整官方PNG和基础牌文接入，觉醒采用已见PNG的+4力量/+0生命；勤勉修行的1勾0/0战技和手牌+1/+1、重任自动修行不叠加且替换旧战技由日文客户端转录补齐，仍待中文原客户端复核。指定录像未逐牌覆盖；居合出击关键词持续边界、气绝替代用牌的战技次数、被反制时的手牌强化与多种同刻触发全序继续待核。']
data['sources'] += [
 {'id':sources[0],'path':'art-reference-official/卡面-按版本/16_远山遥泽/276_一条','evidence':'27600–27608完整PNG已目检：基础2/5，三架势2/6、4/5、2/6；此心安处1鬼火，觉醒+4力量/+0生命。'},
 {'id':sources[1],'path':'research-data/cards.json','url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','evidence':'官网公共卡库基础牌文，与PNG交叉核对；不沿用旧属性叠层、护甲和复活近似。'},
 {'id':sources[2],'url':'https://gamerch.com/onmyojicard/629801','relatedUrl':'https://gamerch.com/onmyojicard/629807','evidence':'日文客户端词条转录补充勤勉修行0/0战技、手牌强化+1/+1，以及重任自动修行不强化、替换已装战技、随后原攻击继续的两次交战；作为待中文客户端复核的补充证据。'}]
base='当一条升级时，将一张「勤勉修行」置入手牌。\n一条的战技效果气绝时不会移除。'
awake='迅捷\n一条气绝状态下可以使用战斗牌并使效果改为复活自己。\n一条的战技效果气绝时不会移除。'
data['units']['yitiao']={'verifiedRules':True,'yitiaoRules':True,'attack':2,'maxHp':5,'battleSkillPersistsKnockout':True,'passive':{'id':'yitiao-training','name':'一条','text':base,'hooks':[]},'awakenedPassive':{'id':'yitiao-awakened','name':'觉醒·一条','text':awake,'hooks':[]},'formLifecycle':{},'sources':sources,'verificationPending':pending}
texts={
 'c27601':'战技\n从手牌使用时，使一条的战技效果额外获得等同于一条等级的力量和护甲。',
 'c27602':'追猎\n增强：此牌获得+X力量和+X护甲，X为本局游戏一条的战技效果获得的额外加成值。',
 'c27603':'进场时将一张「勤勉修行」置入手牌。\n敌方回合时获得+X力量，X为本局游戏一条使用过的战技牌数量。',
 'c27604':'进场时将一张「勤勉修行」置入手牌。\n一条的战斗牌获得瞬发。',
 'c27605':'一条获得2力量、不屈和贯通。',
 'c27606':'一条获得屏障并自动使用一张「勤勉修行」。\n响应：当你其他式神被敌方攻击时，自动使用并将攻击目标改为一条。',
 'c27607':'进场时选择：一条出击时获得吸血；或一条出击时获得暴击。',
 'c27608':'气绝时可用。\n觉醒：'+awake,
 'yitiao-training':'战技\n从手牌使用时，使一条的战技效果额外获得1力量和1护甲。'}
def effect(a,v=0,t='source'):return {'action':a,'target':t,'value':v}
for id,text in texts.items():
 n=int(id[-2:]) if id.startswith('c') else 0
 typ='combat' if n in [0,1,2] else 'form' if n in [3,4,7] else 'awakening' if n==8 else 'spell'
 card={'verifiedRules':True,'yitiaoRules':True,'type':typ,'typeLabel':{'combat':'战斗牌','form':'形态牌','awakening':'觉醒牌','spell':'法术牌'}[typ],'text':text,'officialText':text,'level':1 if n<4 else 2 if n<7 else 3,'cost':1,'keywords':[],'timing':'main','responseTo':[],'autoResponse':'','formHooks':[],'formRules':{},'target':'auto','sources':sources,'verificationPending':pending}
 if n in [0,1,2]:
  card.update(effect='yitiao-combat',value=0,combatOption={'shield':0},effects=[effect('yitiao-combat')])
  if n in [0,1]:card.update(battleSkill=True,keywords=['battle-skill'],effects=[effect('yitiao-skill-grow'),effect('yitiao-combat')])
  else: card.update(target='enemy-unit',keywords=['pursuit'],combatOption={'pursuit':True,'shield':0})
 elif n in [3,4,7]:
  val={'attack':4 if n==4 else 2,'hp':5 if n==4 else 6,'setBase':True}
  card.update(effect='form',value=val,effects=[effect('form',val),effect('yitiao-stance' if n==7 else 'yitiao-training')])
  if n==3:card['formRules']={'yitiaoGuard':True}
  if n==4:card['formRules']={'yitiaoCombatInstant':True}
 elif n==5:card.update(effect='yitiao-alone',value=2,effects=[effect('yitiao-alone')])
 elif n==6:card.update(effect='yitiao-cover',value=0,keywords=['response'],autoResponse='other-ally-attacked',yitiaoCover=True,responseModifiesCombat=True,effects=[effect('yitiao-cover')])
 elif n==8:card.update(effect='yitiao-awaken',value={'attack':4,'hp':0},allowKnockedSource=True,effects=[effect('yitiao-awaken',{'attack':4,'hp':0})])
 data['cards'][id]=card
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
token={'id':'yitiao-training','unitId':'yitiao','name':'勤勉修行','type':'combat','level':1,'cost':1,'text':texts['yitiao-training'],'target':'auto','subpack':'yuanshan','deckLimit':0,'starter':0,'token':True,'rarity':'common','keywords':['battle-skill'],'effects':[['always','yitiao-skill-grow','source',0],['always','yitiao-combat','source',0]]}
p=root/'game-content-wave6.js';s=p.read_text();mark='\n]);\n\nexport function getWave6UnitIds()';assert s.count(mark)==1;s=s.replace(mark,'\n  wave6Card(0, "yitiao", '+json.dumps(token,ensure_ascii=False,indent=2)+'),'+mark);p.write_text(s)
p=root/'godot/content/content.json';c=json.loads(p.read_text());new=token.copy();new.update(typeLabel='战斗牌',copies=0,starterCopies=0,pack='wave6',officialText=token['text'],timing='main',responseTo=[],effect='yitiao-combat',value=0,effects=[{'condition':e[0],'action':e[1],'target':e[2],'value':e[3]} for e in token['effects']]);new.pop('starter');c['cards'].append(new);p.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
p=root/'scripts/gen-wave6-content.py';s=p.read_text();idx=s.index('\n',s.index('EXTRA_TOKENS: list = '));s=s[:idx]+ '\nEXTRA_TOKENS += '+repr([token])+'\n'+s[idx:];p.write_text(s)
p=root/'godot/scripts/tomato_fire_rules.gd';s=p.read_text().replace('or gs.VerifiedRules.Samurai.swift(u) else 1','or gs.VerifiedRules.Samurai.swift(u) or gs.VerifiedRules.Yitiao.swift(u) else 1');p.write_text(s)
p=root/'output/godot-yitiao-20261022/build_export.py';p.write_text(p.read_text().replace('GARUDA_BUILD','YITIAO_BUILD'))
print('YITIAO_CONTENT: 1 unit + 8 main cards + 1 generated training')
