from pathlib import Path
import json,re
p=Path('godot/content/verified_rules.json');v=json.loads(p.read_text());raw={int(c['id']):c for c in json.load(open('research-data/cards.json'))}
v['sources'].append({'id':'toxic-original-faces','kind':'original-card-images','path':'art-reference-official/卡面-按版本/17_鸣雷启蛰','note':'虫师/蝎女基础与16张主体完整PNG；百蝎之毒采用PNG3/9，官网文字快照的3/8是旧数值。'})
v['sources'].append({'id':'toxic-official-guide','url':'https://www.taptap.cn/moment/384310935424077383?group_id=188707','kind':'official-keyword-guide','note':'官方2023-03-13剧毒/中毒原图，基础版本不能恢复或重置生命，包含形态进场和离场。'})
v['sources'].append({'id':'toxic-swarm-transcription','url':'https://gamerch.com/onmyojicard/758268','kind':'derived-transcription','note':'展翅虫群1/3，迅捷、剧毒；无中文独立完整原PNG。'})
sources=['toxic-original-faces','toxic-official-guide','toxic-swarm-transcription']
pending=['基础完整PNG与官方初版毒机制图接入主要机制；指定录像逐牌及全组合未完成核验。剧毒直接气绝与被动/响应/即时复活/替身/转移/贯通的全序、簌簌虫痕生命快照、攻击时剧毒及反击、毒牌检索范围、百蝎之毒对牌手的全部细节仍待原客户端确认。采用本地基础版本，不混入后来治疗解禁、额外加护/吸血/回血封锁等调整。']
for id,role,atk,hp in [('chongshi','bug',2,5),('xieenv','scorpion',2,6)]:
 v['units'][id]={'toxicRole':role,'verifiedRules':True,'attack':atk,'maxHp':hp,'passive':{'id':'toxic-'+role,'name':'中毒削力' if role=='bug' else '剧毒','text':'中毒的敌方式神降低1力量。' if role=='bug' else '蝎女攻击时获得剧毒。','hooks':[]},'formLifecycle':{},'sources':sources,'verificationPending':pending,'awakenedPassive':{'id':'toxic-'+role+'-awakened','name':'觉醒','text':'中毒的敌方式神降低2力量。每回合一次，当一个中毒的敌方式神气绝时，你获得一点鬼火。' if role=='bug' else '剧毒。','hooks':[]}}
def e(action,value=0,target='source'):return {'action':action,'value':value,'target':target}
def card(n,typ,actions,target='auto',value=0,keywords=[],form={},extra={}):
 r=raw[n];text=(r.get('desc') or '').replace('#r','\n').replace('#[力量]','力量').replace('#[生命]','生命')
 c={'verifiedRules':True,'toxicRules':True,'type':typ,'typeLabel':{'spell':'法术牌','form':'形态牌','combat':'战斗牌','realm':'幻境牌'}[typ],'level':int(r['stage']),'cost':1,'text':text,'officialText':text,'target':target,'effect':actions[0]['action'],'value':value,'effects':actions,'keywords':keywords,'formRules':form,'formHooks':[],'formAbility':text if typ=='form' else '', 'timing':'main','responseTo':[],'autoResponse':'','sources':sources,'verificationPending':pending,'toxicSearch':'剧毒' in (r.get('keyword') or '')}
 c.update(extra);v['cards']['c'+str(n)]=c
for n,atk,hp,rules in [(28301,4,5,{'bugDraw':True}),(28304,2,5,{'bugHeal':True}),(28403,2,6,{'scorpionRetaliate':True}),(28405,4,6,{'scorpionMove':True,'scorpionArmor':True}),(28408,3,9,{'scorpionExtraPoison':True})]:
 val={'attack':atk,'hp':hp,'setBase':True};card(n,'form',[e('form',val)],value=val,form=rules,keywords=['unyielding'] if n==28408 else [])
card(28302,'spell',[e('toxic-summon')])
card(28303,'spell',[e('toxic-damage',3,'selected-enemy')],'enemy-unit',keywords=['toxic'],extra={'toxicDamage':True,'responseAction':'damage'})
card(28305,'spell',[e('toxic-search'),e('pair-ward')])
card(28306,'spell',[e('toxic-revive'),e('toxic-random',2)],'ally-knocked-unit',keywords=['toxic'],extra={'toxicDamage':True,'responseAction':'revive'})
card(28307,'realm',[e('toxic-realm'),e('toxic-damage',2,'selected-enemy')],'enemy-unit',extra={'realm':{'hp':8,'nativeRealm':'bug-dream','trigger':'none'}})
card(28308,'spell',[e('toxic-damage',4,'selected-enemy'),e('toxic-awaken',{'attack':2,'hp':2})],'enemy-unit',keywords=['toxic','awakening'],extra={'toxicDamage':True,'responseAction':'damage'})
card(28401,'spell',[e('toxic-revive-self'),e('pair-ward')],extra={'allowKnockedSource':True})
card(28402,'combat',[e('pair-ward'),e('assault',0)],extra={'combatOption':{'shield':0}})
card(28404,'spell',[e('pair-ward'),e('toxic-awaken',{'attack':1,'hp':1})],keywords=['awakening'])
card(28406,'combat',[e('assault',1)],value=1,extra={'combatOption':{'shield':1}})
card(28407,'realm',[e('toxic-realm'),e('toxic-damage',2,'selected-enemy')],'enemy-unit',extra={'realm':{'hp':6,'nativeRealm':'scorpion-den','trigger':'none'}})
p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
p=Path('godot/scripts/toxic_rules.gd');s=p.read_text().replace('return c.get("toxicDamage",false) or "toxic" in c.get("keywords",[])','return c.get("toxicSearch",false) or c.get("toxicDamage",false) or "toxic" in c.get("keywords",[])');p.write_text(s)
print('TOXIC_CONTENT16_AND_TWO_UNITS')
