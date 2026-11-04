from pathlib import Path
import json

def edit(path,a,b):
 p=Path(path);s=p.read_text();assert s.count(a)==1,(path,a,s.count(a));p.write_text(s.replace(a,b))
p='godot/scripts/verified_card_rules.gd'
edit(p,'const Baize :=','const Susanoo := preload("res://scripts/susanoo_rules.gd")\nconst Baize :=')
edit(p,'\tif Baize.resolve_action','\tif Susanoo.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true\n\tif Baize.resolve_action')
edit(p,'static func end_turn(gs, p_idx: int) -> void:\n','static func end_turn(gs, p_idx: int) -> void:\n\tSusanoo.end_turn(gs,p_idx)\n')
edit(p,'static func knocked_out(unit: Dictionary) -> void:\n','static func knocked_out(unit: Dictionary) -> void:\n\tSusanoo.knocked_out(unit)\n')
p='godot/scripts/game_state.gd'
edit(p,'\tcard = VerifiedRules.Crocodile.describe_card','\tcard = VerifiedRules.Susanoo.describe_card(self,p_idx,card)\n\tcard = VerifiedRules.Crocodile.describe_card')
edit(p,'for targets in [VerifiedRules.Baize.targets','for targets in [VerifiedRules.Susanoo.targets(self,p_idx,card),VerifiedRules.Baize.targets')
edit(p,'\tif not VerifiedRules.Baize.can_use','\tif not VerifiedRules.Susanoo.can_use(self,p_idx,card): return {"ok":false,"reason":"须佐之男无法觉醒或未满足复活条件。"}\n\tif not VerifiedRules.Baize.can_use')
edit(p,'\tif VerifiedRules.Baize.resolve_frame','\tif VerifiedRules.Susanoo.resolve_frame(self,frame): return\n\tif VerifiedRules.Baize.resolve_frame')
edit(p,'\t\t_knockout_unit(u, _src_player, source_index, knockout_extra, house_break_snapshot)\n\t\tknocked = int(u.hp)<=0','\t\tvar tomb_serial:=int(u.get("susanooTombSerial",0))\n\t\t_knockout_unit(u, _src_player, source_index, knockout_extra, house_break_snapshot)\n\t\tknocked = int(u.hp)<=0 or int(u.get("susanooTombSerial",0))>tomb_serial')
edit(p,'\tvar victim := -1\n\tfor owner in players.size():','\tif VerifiedRules.Susanoo.capture_kill(self,u,source_owner,source_index): return\n\tif VerifiedRules.Susanoo.tomb(u):\n\t\tfor side in players.size():\n\t\t\tif _unit_index_by_uid(side,u.uid)>=0: VerifiedRules.Susanoo.restore_tomb(self,side,u,false)\n\tvar victim := -1\n\tfor owner in players.size():')
edit(p,'or bool(u.get("combatUnyielding", false)) or','or bool(u.get("combatUnyielding", false)) or bool(u.get("susanooCombatUnyielding",false)) or')
edit(p,'\t\tu.combatUnyielding = false','\t\tu.combatUnyielding = false\n\t\tu.susanooCombatUnyielding=false')
edit(p,'\tVerifiedRules.Fortune.form_entered(self, p_idx, src, card)','\tVerifiedRules.Fortune.form_entered(self, p_idx, src, card)\n\tVerifiedRules.Susanoo.form_entered(self,p_idx,src,card)')
edit(p,'\tVerifiedRules.Poison.transfer_before_combat(self, p_idx, unit_index, e_idx, fi, options)','\tif VerifiedRules.Susanoo.prepare_attack(self,p_idx,unit_index,fi,options):\n\t\tpower=VerifiedRules.Combat.power(self,p_idx,attacker,bonus+int(enc.get("attack",0)))\n\t\tif light_zero: power=0\n\tpierce=pierce or options.get("pierce",false)\n\tVerifiedRules.Poison.transfer_before_combat(self, p_idx, unit_index, e_idx, fi, options)')
edit(p,'\tVerifiedRules.Glutton.prepare_combat(self,owner,src,victim,idx,options)','\tVerifiedRules.Susanoo.begin_duel(self,frame)\n\tVerifiedRules.Glutton.prepare_combat(self,owner,src,victim,idx,options)')
edit(p,'\tplayer(owner).units[src].erase("enraged")','\tVerifiedRules.Susanoo.finish_duel(self,options)\n\tplayer(owner).units[src].erase("enraged")')
edit(p,'\tif frame.get("movementCancelled",false):\n','\tif frame.get("movementCancelled",false):\n\t\tVerifiedRules.Susanoo.finish_duel(self,frame.options)\n')
edit(p,'\t\t\tVerifiedRules.Garuda.form_turn_start(self,p_idx,i)','\t\t\tVerifiedRules.Susanoo.form_turn_start(self,p_idx,i)\n\t\t\tVerifiedRules.Garuda.form_turn_start(self,p_idx,i)')
p='godot/scripts/combat_keyword_rules.gd'
edit(p,'\tif not options.has("bloodLifeSteal"):','\tvar susanoo_scope: Dictionary=gs.VerifiedRules.Susanoo.begin_strike(gs,owner,src,options)\n\tvar tomb_before: int=0 if idx<0 else int(gs.player(victim).units[idx].get("susanooTombSerial",0))\n\tif not options.has("bloodLifeSteal"):')
edit(p,'\tgs.VerifiedRules.Yaksha.combat_strike(gs,owner,src,victim,idx,result,options)\n\treturn result','\tgs.VerifiedRules.Yaksha.combat_strike(gs,owner,src,victim,idx,result,options)\n\tif idx>=0 and int(gs.player(victim).units[idx].get("susanooTombSerial",0))>tomb_before: result.knocked=true\n\tgs.VerifiedRules.Susanoo.end_strike(gs,owner,src,susanoo_scope)\n\treturn result')
p='godot/scripts/game_ai.gd';edit(p,'\tvar baize_score =','\tvar susanoo_score = _gs.VerifiedRules.Susanoo.score_card(_gs,p_idx,card,_target)\n\tif susanoo_score != null: return int(susanoo_score)\n\tvar baize_score =')
p='godot/scripts/ui/battle_status.gd'
edit(p,'if view.get("baseRulesSuppressed", false):','if view.get("baseRulesSuppressed", false) and not gs.VerifiedRules.Susanoo.tomb(view):')
edit(p,'\tview.baizeMarks=','\tview.susanooMarks=gs.VerifiedRules.Susanoo.unit_marks(gs,owner,idx)\n\tview.baizeMarks=')
edit(p,'\tfor detail in unit.get("baizeMarks",[]):','\tfor detail in unit.get("susanooMarks",[]): result.append(mark("susanoo-rule",str(detail),str(detail),"e5d080"))\n\tfor detail in unit.get("baizeMarks",[]):')
edit(p,'if unit.get("baseRulesSuppressed", false): result.append','if unit.get("baseRulesSuppressed", false) and not unit.has("susanooOriginal"): result.append')
p='scripts/godot-verify.sh';edit(p,'verify_baize verify_combat','verify_baize verify_susanoo verify_combat')
p=Path('godot/content/verified_rules.json');d=json.loads(p.read_text());raw={int(x['id']):x for x in json.load(open('research-data/cards.json'))}
sources=['susanoo-original-faces','susanoo-official-snapshot','susanoo-official-publication','susanoo-tomb-transcription']
d['sources'] += [{'id':sources[0],'path':'art-reference-official/卡面-按版本/17_鸣雷启蛰/281_须佐之男','evidence':'28100–28108完整原PNG；采用原图中的神明之护4/7、天雷万象4/10、天威+1护甲、雷切+1护甲及主体各1鬼火。'},{'id':sources[1],'url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','evidence':'原始卡表与保存官网响应逐字段比较。'},{'id':sources[2],'url':'https://www.taptap.cn/moment/385036106959160862?group_id=188707','evidence':'2023-03-15官方曝光图含雷冢0/1及原式神回合结束复活至1生命词条。曝光图部分主体为预览版本，以本地完整主体PNG为准，不混入神明之护3/7或天威直接变形等预览内容。'},{'id':sources[3],'url':'https://gamerch.com/onmyojicard/758176','evidence':'雷冢0/1、不能攻击、回合结束复活至1生命；中文机制实测参考https://www.taptap.cn/moment/467093870207830538、https://www.taptap.cn/moment/656066957140823410，仍待指定录像逐项核验。'}]
pending=['按28100–28108基础完整PNG与官方曝光雷冢词条接入；指定录像未逐牌覆盖。雷冢替换在原式神死亡/形态离场/即时复活中的全序、被再次击杀与幻境重复替换、原式神成长与倒计时恢复、召唤物及复制边界，雷切贯通与伤害转移组合、天雷万象嵌套交战及不屈授予全序仍待原客户端核验。雷冢中文独立完整原图仍缺。']
base='当须佐之男攻击式神时，获得+1力量。若被攻击的式神生命为1，本次攻击获得贯通。';awake='贯通。须佐之男攻击式神时获得+1力量。'
d['units']['xuzuozhinan']={'verifiedRules':True,'susanooRules':True,'attack':2,'maxHp':5,'passive':{'id':'susanoo-attack','name':'雷霆','text':base,'hooks':[]},'awakenedPassive':{'id':'susanoo-attack-awakened','name':'觉醒·须佐之男','text':awake,'hooks':[]},'awakenedCombatKeywords':['pierce'],'formLifecycle':{},'sources':sources,'verificationPending':pending}
for n in range(1,9):
 id=f'c281{n:02}';r=raw[28100+n];form=n in [5,8];typ='realm' if n==3 else 'form' if form else 'spell' if n==6 else 'combat';text=r['desc'].replace('#r','\n').replace('#[力量]','力量').replace('#[护甲]','护甲').replace('#[生命]','生命');value={'attack':4,'hp':7 if n==5 else 10,'setBase':True} if form else 0
 action='susanoo-guard' if n==5 else 'form' if n==8 else 'susanoo-domain' if n==3 else 'susanoo-awaken' if n==6 else 'susanoo-cut' if n==7 else 'susanoo-combat'
 c={'verifiedRules':True,'susanooRules':True,'type':typ,'typeLabel':{'combat':'战斗牌','spell':'法术牌','realm':'幻境牌','form':'形态牌'}[typ],'level':int(r['stage']),'cost':1,'text':text,'officialText':text,'target':'enemy-unit' if n in [1,2,7] else 'auto','effect':action,'value':value,'effects':[{'action':action,'target':'source','value':value}],'keywords':['instant','pursuit'] if n==1 else ['pursuit'] if n==2 else ['lethal'] if n==4 else [],'timing':'main','responseTo':[],'autoResponse':'','formRules':{'susanooDuel':True} if n==8 else {},'formHooks':[],'formAbility':text if form else '', 'sources':sources,'verificationPending':pending}
 if typ=='combat':c['combatOption']={'shield':1 if n in [2,7] else 2 if n==4 else 0,'immuneCombat':n==1,'pursuit':n in [1,2],'lethal':n==4,'susanooTomb':n in [2,4,7]}
 if n==3:c['realm']={'hp':5,'nativeRealm':'susanoo-domain','trigger':'none','triggerEffect':''}
 d['cards'][id]=c
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('SUSANOO_INTEGRATED')
