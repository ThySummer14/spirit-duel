from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; p=root/'godot/content/verified_rules.json'; v=json.loads(p.read_text())
sources=['mengpo-current-cardmaker','mengpo-awaken-20201126','mengpo-standard-20241226','mengpo-soup-20221027']
new=[{'id':sources[0],'url':'https://ssr.163.com/cardmaker/','asset':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','retrieved':'2026-10-16','evidence':'本次取得17100–17108官网数据和17102/17104/17108卡图；官网仍包含过期牌文，以下正式公告覆盖。'}, {'id':sources[1],'url':'https://www.taptap.cn/moment/80802089336308748','evidence':'2020-11-26正式服觉醒·孟婆印刷加成改为+2/+2。'}, {'id':sources[2],'url':'https://www.taptap.cn/moment/621096374275932510','image':'https://img2-tc.tapimg.com/moment/etag/lvIYVVAlF6_TAuvDieZrP-zXe6QD.jpg/_tap_ugc.jpg','evidence':'本次直接查看官方2024-12-26长图：忘忧瞬发、按敌方式神当前等级限牌名、移同名后再移底2；觉醒敌方牌库≤12时给予迅捷。'}, {'id':sources[3],'url':'https://m.youxi369.com/gonglue/142422.html','evidence':'2022-10-27维护公告转载：孟婆汤改为敌方式神3伤后移敌方牌库底3；官方原帖尚待补齐。'}]
for x in new:
 if not any(y['id']==x['id'] for y in v['sources']):v['sources'].append(x)
pending=['指定录像没有孟婆全组实机结算；后续正式服公告尚未穷尽。孟婆汤2022公告目前为正式公告转载，待补官方原帖。','忘忧按所选敌方式神当前等级过滤；同名皮肤、衍生牌候选范围、无可选牌名时使用限制及同时气绝反击后基础能力时序仍待原版核验。奈何桥头采用普通对战同名移除，未混入2023有个牌局专用底1版本。']
v['units']['mengpo']={'mengpoMill':True,'attack':3,'maxHp':4,'formLifecycle':{},'officialAbility':'每当孟婆对敌方牌手造成伤害时，将他牌库底一张牌移除。','passive':{'name':'基础能力','text':'每当孟婆对敌方牌手造成伤害时，将他牌库底一张牌移除。','hooks':[]},'awakenedPassive':{'name':'觉醒能力','text':'每当孟婆对敌方牌手造成伤害时，将他牌库底五张牌移除。','hooks':[]},'sources':sources,'verificationPending':pending}
def card(i,text,action,value=0,target='auto',kind='spell',level=1,keywords=(),**extra):
 d={'verifiedRules':True,'mengpoRules':True,'type':kind,'typeLabel':{'spell':'法术牌','form':'形态牌','awakening':'觉醒牌'}[kind],'level':level,'cost':1,'copies':2,'deckLimit':2,'text':text,'officialText':text,'effect':action,'value':value,'target':target,'effects':[{'condition':'always','action':action,'target':target,'value':value}],'keywords':list(keywords),'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','combatOption':{},'tags':[],'sources':sources,'verificationPending':pending,'ruleFidelity':{'status':'source-backed-pending','pending':pending}}
 d.update(extra)
 if kind=='form':d['formAbility']=text
 v['cards']['c171%02d'%i]=d;return d
c=card(1,'对一个敌方式神造成3点伤害，将敌方牌手牌库底三张牌移除。','damage',3,'enemy-unit');c['effects'].append({'condition':'always','action':'mengpo-bottom','target':'enemy-player','value':3})
card(2,'抽两张牌，弃一张牌。\n增强：若敌方牌库张数≤16，此牌获得瞬发。','mengpo-draw-discard',mengpoEnhance='instant')
card(3,'己方回合结束时，双方牌手各将牌库底一张牌移除。','form',{'attack':4,'hp':5,'setBase':True},kind='form',formRules={'mengpoTurnEnd':True})
card(4,'贯通。\n增强：若敌方牌库张数≤16，此牌获得3力量和3生命。','form',{'attack':5,'hp':7,'setBase':True},kind='form',level=2,keywords=['pierce'],mengpoEnhance='body',formRules={'combatKeywords':['pierce']})
card(5,'投射：造成4点伤害。\n增强：若敌方牌库张数≤16，此牌伤害翻倍。','damage-enemy-front',4,level=2,keywords=['projectile'],mengpoEnhance='damage')
card(6,'每当牌手使用一张牌时，将其手牌和牌库中的同名牌移除。','form',{'attack':4,'hp':6,'setBase':True},kind='form',level=2,formRules={'mengpoBridge':True})
card(7,'增强：若敌方牌库张数≤12，使孟婆获得迅捷。\n觉醒：每当孟婆对敌方牌手造成伤害时，将他牌库底五张牌移除。','mengpo-awaken',{'attack':2,'hp':2},kind='awakening',level=3,mengpoEnhance='swift')
card(8,'瞬发。选择敌方式神的一张牌名（只能选择等级小于等于该式神当前等级的牌），将其手牌和牌库中所有同名牌移除，然后将敌方牌手牌库底两张牌移除。','mengpo-name',level=3,keywords=['instant'])
p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
print('Mengpo overlay: unit +8 cards')
