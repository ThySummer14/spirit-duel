from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
raw = {int(c['id']): c for c in json.loads((root/'research-data/cards.json').read_text())}
source = root/'art-reference-official/卡面-按版本/12_浮生方醒/239_弈'
pending = [
    '按23900–23908完整原PNG和官网基础快照接入，未逐牌覆盖指定录像；保留原客户端核验。',
    '洗牌触发、调度、复盘与响应及离场能力的完整顺序，辉夜姬合并幻境、变形状态与奇数牌库取整边界仍待原客户端核验。',
]
units = {'yi': {'verifiedRules': True, 'yiRules': True, 'attack': 2, 'maxHp': 5,
    'passive': {'id': 'yi-shuffle', 'name': '占卜', 'text': '己方回合每回合一次，当任一牌手洗牌库时，占卜1。', 'hooks': []},
    'awakenedPassive': {'id': 'yi-shuffle-awake', 'name': '占卜', 'text': '己方回合每回合一次，当任一牌手洗牌库时，占卜2。', 'hooks': []},
    'sources': ['yi-original-20261029','yi-fixes-20220126'], 'verificationPending': pending}}
types = ['spell','combat','spell','spell','spell','spell','spell','form']
actions = ['yi-long-think','yi-combat','yi-damage','yi-search','yi-awaken','yi-heal-draw','yi-review','form']
labels = {'spell':'法术牌','combat':'战斗牌','form':'形态牌'}
cards = {}
manifest = []
for pos in range(1,9):
    num = 23900 + pos; cid = f'c{num}'; item = raw[num]
    text = item['desc'].replace('#r','\n').replace('#[力量]','力量').replace('#[生命]','生命').strip()
    value = {'attack':1,'hp':1,'setBase':True} if pos==8 else 2 if pos==2 else 0
    card = {'verifiedRules':True,'yiRules':True,'type':types[pos-1],'typeLabel':labels[types[pos-1]],
        'level':int(item['stage']),'cost':1,'target':'enemy-unit' if pos==3 else 'ally-unit' if pos==4 else 'auto',
        'effect':actions[pos-1],'value':value,'effects':[{'condition':'always','action':actions[pos-1],'target':'source','value':value}],
        'keywords':['instant'] if pos in (1,6) else [],'tags':['觉醒'] if pos==5 else [],'timing':'main','responseTo':[],
        'formHooks':[],'formRules':{},'formAbility':'','text':text,'officialText':text,
        'sources':['yi-original-20261029','yi-fixes-20220126'],'verificationPending':pending}
    if pos==2: card['combatOption']={'shield':0,'immuneCombat':False}
    if pos==3: card['responseAction']='damage'
    if pos==5: card['awakening']=True
    if pos==8: card['formAbility']=text
    cards[cid]=card
    src=next(source.glob(f'{num}_*.png')); target=root/f'godot/assets/official/cards/{cid}.png'
    if target.exists(): assert target.read_bytes()==src.read_bytes(), target
    else: shutil.copy2(src,target)
    manifest.append({'cardId':cid,'source':str(src.relative_to(root)),'target':str(target.relative_to(root)), 'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
sources = [
    {'id':'yi-original-20261029','path':str(source.relative_to(root)), 'url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','evidence':'23900–23908完整原PNG及research-data/cards.json基础牌库快照：真实洗牌占卜、调度、手牌/场上卡洗回、检索与牌库量身材。'},
    {'id':'yi-fixes-20220126','url':'https://www.taptap.cn/moment/235144264613364682','evidence':'官方2022-01-26维护：复盘多张形态洗回不能重复触发弈；气合零实际伤害仍应在目标存活时洗回专属手牌。'},
]
(out/'overlay.json').write_text(json.dumps({'units':units,'cards':cards,'sources':sources},ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps({'baseSnapshot':'research-data/cards.json','matched':[raw[i] for i in range(23900,23909)],'originalPNG':str(source.relative_to(root))},ensure_ascii=False,indent=2)+'\n')
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('YI_OVERLAY_READY',len(cards),'ORIGINAL_PNG',len(manifest))
