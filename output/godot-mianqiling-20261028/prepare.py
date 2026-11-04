from pathlib import Path
import json,shutil,hashlib
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
folder=root/'art-reference-official/卡面-按版本/09_四相琉璃/208_面灵气'
pending=['以完整原PNG接入面灵气基础牌文；旧官网快照存在抽牌、免战伤、自欺倍率与轮回身材差异，指定录像未逐牌复核。','觉醒奇数伤害减半的取整、组合伤害变换优先级和多源反应全序仍待原客户端核验；当前减半按整数向下取整。','派系数据依215条完整原图标逐图核对；35个无独立派系图标的历史入口/衍生体保留未核验，不按名称推定。']
pending.append('雷冢等替换身体的派系未获完整原卡或官方图标确认；雷冢暂保留未知，不借用被替换式神派系，也不把社区单句当作官方核验。')
source='mianqiling-original-20261029'
payload={'sources':[{'id':source,'path':'art-reference-official/卡面-按版本/09_四相琉璃/208_面灵气/','evidence':'20800–20808完整原PNG；新生双面无抽牌、心生七面异派不屈、自欺派系数+2、轮回5/5。'},{'id':'mianqiling-wheel-detail-2021','url':'https://www.taptap.cn/moment/121029471275845061','evidence':'官方版主原帖轮回之面图示补充四派系状态与变派系时效果；早期测试服身材与基础卡面不同，采用当前原PNG。'},{'id':'mianqiling-damage-order-player','url':'https://www.taptap.cn/moment/467093870207830538','evidence':'社区实测：护甲、暴击后再算面灵气加成；原始0伤面灵气仍能+1；保留复杂组合原客户端核验。'}], 'units':{},'cards':{}}
payload['units']['mianqiling']={'verifiedRules':True,'mianqilingRules':True,'attack':2,'maxHp':5,'passive':{'id':'mian-faction','name':'四相之面','text':'面灵气受到同派系式神的伤害-1，对不同派系式神造成的伤害+1。','hooks':[]},'awakenedPassive':{'id':'mian-faction-awake','name':'四相之面','text':'面灵气受到同派系式神的伤害减半，对不同派系式神造成的伤害翻倍。','hooks':[]},'formLifecycle':{},'verificationPending':pending,'sources':[source]}
texts=['瞬发。使一个式神变为任一派系。','若交战式神为同派系，本次战斗获得必杀；若交战式神为不同派系，本次战斗获得不屈。','使用时使面灵气变为任一派系。','对一个式神造成X点伤害，X为场上未气绝式神的所属派系数量总和+2。','己方未气绝式神中每有一种派系，便抽一张牌。','己方回合开始时，使面灵气随机变为另一派系。','使面灵气永久变为任一派系。觉醒：面灵气受到同派系式神的伤害减半，对不同派系式神造成的伤害翻倍。','投射：造成X点伤害，X为与面灵气相同派系未气绝式神的数量，然后使面灵气随机变为另一种派系。将此效果额外重复2次。']
actions=['mian-faction','mian-combat','form','mian-self-deceit','mian-draw','form','mian-awaken-choice','mian-jealous']
levels=[1,1,1,2,2,2,3,3]
for i in range(1,9):
 c={'verifiedRules':True,'mianqilingRules':True,'type':'form' if i in (3,6) else 'combat' if i==2 else 'spell','level':levels[i-1],'cost':1,'copies':2,'deckLimit':2,'target':'any-unit' if i in (1,4) else 'auto','effect':actions[i-1],'value':0,'effects':[],'keywords':['instant'] if i==1 else [],'tags':['觉醒'] if i==7 else [],'text':texts[i-1],'officialText':texts[i-1],'timing':'main','responseTo':[],'formHooks':[],'formRules':{},'formAbility':'','sources':[source],'verificationPending':pending}
 c['typeLabel']={'spell':'法术牌','form':'形态牌','combat':'战斗牌'}[c['type']]
 if i==2:c.update(value=1,combatOption={'shield':0},responseAction='assault')
 if i in (3,6):
  c['value']={'attack':3 if i==3 else 5,'hp':6 if i==3 else 5,'setBase':True};c['formAbility']=texts[i-1]
 if i==6:
  c['formRules']={'mianReincarnation':True};c['formAbility']+=' 红莲：贯通，变派系时己方所有式神+1力量；紫岩：不屈，变派系时自己和牌手回复3；苍叶：迅捷，变派系时随机敌方式神受2伤；青岚：帷幕，变派系时敌方所有式神受1伤。';c['sources'].append('mianqiling-wheel-detail-2021')
 if i==7:c['value']={'attack':2,'hp':2}
 if i==4:c['responseAction']='damage'
 c['effects']=[{'action':actions[i-1],'target':'selected' if i in (1,4) else 'source','value':c['value']}]
 payload['cards'][f'c208{i:02}']=c
art=[]
for i in range(1,9):
 p=next(folder.glob(f'208{i:02}_*.png'));dst=root/f'godot/assets/official/cards/c208{i:02}.png';shutil.copy2(p,dst);art.append({'source':str(p.relative_to(root)),'target':str(dst.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'card-art-manifest.json').write_text(json.dumps(art,ensure_ascii=False,indent=2)+'\n');(out/'overlay.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
raw=json.load(open(root/'research-data/cards.json'));(out/'official-source-evidence.json').write_text(json.dumps([c for c in raw if str(c.get('role'))=='208'],ensure_ascii=False,indent=2)+'\n')
print('MIAN_OVERLAY',len(payload['cards']))
