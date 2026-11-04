from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
raw={int(c['id']):c for c in json.loads((root/'research-data/cards.json').read_text())}
pending=['按24200–24208／24400–24408完整原PNG和基础牌文接入，未逐牌覆盖指定录像。','连引与蓄力/反制、浮世万象永久增强、绮丽承伤/屏障/贯通及被指挥攻击触发的复杂全序仍待原客户端核验；斗转按交换式神面板力量后应用战斗牌加成。']
sources=[{'id':'mirror-song-original-20261030','path':'art-reference-official/卡面-按版本/12_浮生方醒/','evidence':'24200–24208与24400–24408完整原PNG逐图核对；昙无采用原PNG投射4，觉醒松连引其他未气绝式神各一张。'}, {'id':'link-explanation-20211209','url':'https://m.ali213.net/news/gl2112/745429.html','evidence':'转载机制Q&A：原牌须可用、每个被连引式神按其当前等级筛选，最终只使用一张，其余先洗回；连引检索不视为抽牌。'}, {'id':'mirror-form-retention-explanation','url':'https://m.ali213.net/news/gl2201/769555.html','evidence':'基础机制解析：浮世万象为唯一保留历次参与连引所得效果的卡牌，其余卡的增强用于本次连引。'}, {'id':'song-dream-community','url':'https://www.taptap.cn/moment/341546240254673892','evidence':'社区机制记录：梦浮世一次连引固定触发一次，不按参与牌数重复；绮丽承伤目标最多承受松生命边界内的伤害，过量贯通仍打松牌手。保留原客户端核验。'}]
units={}
for uid,r in [('yunwaijing',242),('song',244)]:
 u=raw[r*100];text=u['desc'];awake=raw[r*100+(6 if r==242 else 2)]['desc'].split('觉醒：')[-1]
 units[uid]={'verifiedRules':True,'mirrorSongRole':'mirror' if r==242 else 'song','attack':int(u['ll']),'maxHp':int(u['sm']),'passive':{'id':uid+'-link','name':'镜像连引' if r==242 else '琴弦连引','text':text,'hooks':[]},'awakenedPassive':{'id':uid+'-link-awake','name':'镜像连引' if r==242 else '琴弦连引','text':awake,'hooks':[]},'formLifecycle':{},'sources':[s['id'] for s in sources],'verificationPending':pending}
texts={24201:'与此牌连引时，参与连引的牌都获得吸血。\n对一个敌方角色造成3点伤害。',24202:'此牌参与连引时，获得1力量与1生命。\n永久保留连引时获得的额外效果。',24203:'追猎。与此牌连引时，参与连引的牌都获得贯通。\n本次战斗交换云外镜和目标式神的力量。',24204:'与此牌连引时，参与连引的牌都获得使用时投射：造成2点伤害。\n投射：造成4点伤害。',24205:'与此牌连引时，参与连引的形态牌都获得迅捷。',24206:'与此牌连引时，参与连引的牌都获得瞬发。\n觉醒：云外镜使用牌时，连引一张他的牌。若连引的是同名牌，两者都获得瞬发。',24207:'与此牌连引时，参与连引的牌都获得暴击。',24208:'与此牌连引时，参与连引的牌都获得使用时抽一张牌。\n对敌方所有角色造成2点伤害。',24401:'远程。移动敌方准备区式神。',24402:'觉醒：当松使用牌时，连引所有己方其他未气绝式神各一张牌。',24403:'瞬发。占卜1，然后为敌方牌手占卜1。',24404:'本次战斗松受到的战斗伤害改由另一个敌方式神承受。\n响应：当己方战斗区式神被攻击时，自动使用此牌。',24405:'使敌方战斗区式神攻击一个其他式神。',24406:'当松攻击时，使敌方战斗区式神攻击敌方牌手。',24407:'进场和己方回合开始时，随机眩晕一个敌方式神。\n敌方回合开始时，使每个眩晕的敌方式神对敌方牌手造成等同其力量的伤害。',24408:'己方式神连引时，对敌方所有式神造成1点伤害。'}
actions={24201:'ms-damage',24202:'form',24203:'ms-combat',24204:'ms-projectile',24205:'form',24206:'awaken',24207:'ms-combat',24208:'ms-area',24401:'ms-move-combat',24402:'awaken',24403:'ms-divination',24404:'ms-beauty',24405:'ms-command',24406:'form',24407:'ms-night',24408:'form'}
cards={};manifest=[]
for r in [242,244]:
 source=next((root/'art-reference-official/卡面-按版本').glob(f'*/{r}_*'))
 for n in range(1,9):
  id=r*100+n;b=raw[id];action=actions[id];typ={'形态':'form','战斗':'combat','法术':'spell','结界':'realm'}[b['type']];value=0
  c={'verifiedRules':True,'mirrorSongRules':True,'type':typ,'typeLabel':{'form':'形态牌','combat':'战斗牌','spell':'法术牌','realm':'幻境牌'}[typ],'level':int(b['stage']),'cost':1,'copies':2,'deckLimit':2,'target':'auto','text':texts[id],'officialText':texts[id],'keywords':[],'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':[s['id'] for s in sources],'verificationPending':pending}
  if id in [24201,24203,24401,24405]:c['target']='enemy-character' if id==24201 else 'any-unit' if id==24405 else 'enemy-unit'
  if typ=='form':value={'attack':int(b['ll']),'hp':int(b['sm']),'setBase':True};c['formAbility']=texts[id]
  if typ=='combat':value=int(b.get('ll') or 0);c['combatOption']={'shield':int(b.get('sm') or 0)};c['responseAction']='assault'
  if id==24203:c['keywords']=['pursuit'];c['combatOption']['pursuit']=True
  if id==24401:c['keywords']=['remote'];c['combatOption']['pursuit']=True
  if id==24403:c['keywords']=['instant']
  if id in [24206,24402]:value={'attack':1,'hp':1}
  if id==24404:c.update(autoResponse='front-attacked',responseModifiesCombat=True)
  if id==24406:c['formRules']={'songPuppet':True}
  if id==24408:c['formRules']={'songDream':True}
  if id==24407:c['realm']={'hp':5,'nativeRealm':'song-night','triggerEffect':''}
  c.update(effect=action,value=value,effects=[{'action':action,'target':'selected' if c['target']!='auto' else 'source','value':value}]);cards[f'c{id}']=c
  p=next(source.glob(f'{id}_*.png'));dest=root/f'godot/assets/official/cards/c{id}.png';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest);manifest.append({'source':str(p.relative_to(root)),'target':str(dest.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'overlay.json').write_text(json.dumps({'units':units,'cards':cards,'sources':sources},ensure_ascii=False,indent=2)+'\n')
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps({'baseline':[raw[id] for id in list(range(24200,24209))+list(range(24400,24409))],'sources':sources},ensure_ascii=False,indent=2)+'\n')
print('MIRROR_SONG_OVERLAY_READY',len(cards))
