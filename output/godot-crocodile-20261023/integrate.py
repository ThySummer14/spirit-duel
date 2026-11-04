from pathlib import Path
import json

def edit(path,a,b,n=1):
 p=Path(path);s=p.read_text();assert s.count(a)==n,(path,a,s.count(a));p.write_text(s.replace(a,b))
p='godot/scripts/verified_card_rules.gd'
edit(p,'const Whale :=','const Crocodile := preload("res://scripts/crocodile_rules.gd")\nconst Whale :=')
edit(p,'\tif Whale.resolve_action','\tif Crocodile.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true\n\tif Whale.resolve_action')
edit(p,'static func event(gs, kind: String, details: Dictionary) -> void:\n','static func event(gs, kind: String, details: Dictionary) -> void:\n\tif kind in ["summon-removed","unit-removed"]: Crocodile.removed(gs,details)\n')
p='godot/scripts/game_state.gd'
edit(p,'\t\tif not gs.player(owner).units.is_empty(): gs.VerifiedRules.Yitiao.upgraded(gs, owner, 0)','\t\tif not gs.player(owner).units.is_empty(): gs.VerifiedRules.Yitiao.upgraded(gs, owner, 0)\n\t\tif not gs.player(owner).units.is_empty(): gs.VerifiedRules.Crocodile.upgraded(gs,owner,0)')
edit(p,'\tcard = VerifiedRules.Whale.describe_card','\tcard = VerifiedRules.Crocodile.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.Whale.describe_card')
edit(p,'for targets in [VerifiedRules.Whale.targets','for targets in [VerifiedRules.Crocodile.targets(self,p_idx,card),VerifiedRules.Whale.targets')
edit(p,'\tif not VerifiedRules.Whale.can_use','\tif not VerifiedRules.Crocodile.can_use(self,p_idx,card): return {"ok":false,"reason":"影鳄已经觉醒。"}\n\tif not VerifiedRules.Whale.can_use')
edit(p,'\tunit.attack += VerifiedRules.Yitiao.guard_power(self,unit)','\tunit.attack += VerifiedRules.Yitiao.guard_power(self,unit) + VerifiedRules.Crocodile.bonus(self,unit,"attack")')
edit(p,'\tnew_max += VerifiedRules.Puppet.base_bonus(unit)','\tnew_max += VerifiedRules.Crocodile.bonus(self,unit,"hp")\n\tnew_max += VerifiedRules.Puppet.base_bonus(unit)')
edit(p,'\tif VerifiedRules.Vine.absorb_knockout(self,victim,u): return','\tif VerifiedRules.Vine.absorb_knockout(self,victim,u): return\n\tVerifiedRules.Crocodile.detach(self,u,"随式神气绝",false)')
edit(p,'\tfirst_strike = first_strike or VerifiedRules.Combat.has(attacker, "first-strike")','\tfirst_strike = first_strike or VerifiedRules.Combat.has(attacker, "first-strike") or VerifiedRules.Crocodile.attack_first(attacker)')
p='godot/scripts/upgrade_blessing_rules.gd'
edit(p,'\tgs.VerifiedRules.Yitiao.upgraded(gs, owner, idx)','\tgs.VerifiedRules.Yitiao.upgraded(gs, owner, idx)\n\tgs.VerifiedRules.Crocodile.upgraded(gs,owner,idx)')
p='godot/scripts/battle_skill_rules.gd'
edit(p,'\t\t\tgs.VerifiedRules.Whale.before_basic(gs,owner,src)','\t\t\tgs.VerifiedRules.Crocodile.before_basic(gs,owner,src)\n\t\t\tgs.VerifiedRules.Whale.before_basic(gs,owner,src)')
p='godot/scripts/combat_keyword_rules.gd'
edit(p,'\tif keyword == "pierce" and unit.get("yitiaoPierce", false):','\tif keyword == "pierce" and preload("res://scripts/crocodile_rules.gd").trait(unit,"pierce"): return true\n\tif keyword == "pierce" and unit.get("yitiaoPierce", false):')
p='godot/scripts/moon_rules.gd';edit(p,'\tgs.VerifiedRules.Whale.remove_charms(unit)','\tgs.VerifiedRules.Crocodile.detach(gs,unit,"望月：移除灵咒",false)\n\tgs.VerifiedRules.Whale.remove_charms(unit)')
p='godot/scripts/sparrow_rules.gd';edit(p,'\tgs.VerifiedRules.Whale.remove_charms(u,false)','\tgs.VerifiedRules.Crocodile.detach(gs,u,"替身",false)\n\tgs.VerifiedRules.Whale.remove_charms(u,false)')
p='godot/scripts/pipe_fox_rules.gd'
edit(p,'\t\tfor kind in ["Tooth","Body"]:','\t\tif not unit.get("crocCharm",{}).is_empty() and int(unit.crocCharm.owner)!=owner:\n\t\t\tvar e:=base.duplicate(); e.key="crocCharm"; out.append(e)\n\t\tfor kind in ["Tooth","Body"]:')
edit(p,'\t\t"whaleTooth",','\t\t"crocCharm": gs.VerifiedRules.Crocodile.detach(gs,target,"白藏主：移除敌方灵咒")\n\t\t"whaleTooth",')
p='godot/scripts/ui/battle_status.gd'
edit(p,'\tview.whaleMarks=','\tview.crocodileMarks=gs.VerifiedRules.Crocodile.unit_marks(gs,owner,idx)\n\tview.whaleMarks=')
edit(p,'\tfor detail in unit.get("whaleMarks",[]):','\tfor detail in unit.get("crocodileMarks",[]): result.append(mark("crocodile-rule",str(detail),str(detail),"70b090"))\n\tfor detail in unit.get("whaleMarks",[]):')
p='godot/scripts/game_ai.gd'
edit(p,'\tvar whale_score =','\tvar croc_score = _gs.VerifiedRules.Crocodile.score_card(_gs,p_idx,card,_target)\n\tif croc_score != null: return int(croc_score)\n\tvar whale_score =')
p='scripts/godot-verify.sh';edit(p,'verify_whale verify_combat','verify_whale verify_crocodile verify_combat')
p='godot/scripts/crocodile_rules.gd'
edit(p,'static func attack_first(u: Dictionary)', 'static func removed(gs, details: Dictionary) -> void:\n\tvar u: Dictionary=gs._unit_by_uid(gs._all_units(),details.get("uid",""))\n\tif not u.is_empty(): detach(gs,u,"携带者被移除",false)\nstatic func attack_first(u: Dictionary)')
p=Path('godot/content/verified_rules.json');data=json.loads(p.read_text());sources=['crocodile-original-faces','crocodile-official-snapshot','crocodile-charm-transcription']
data['sources'] += [{'id':sources[0],'path':'art-reference-official/卡面-按版本/16_远山遥泽/279_影鳄/','evidence':'27900–27908完整PNG主体牌文与数值。'},{'id':sources[1],'url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','evidence':'2026-10-22保存的官网响应与本地27900–27908原始快照逐字段比较。'},{'id':sources[2],'url':'https://gamerch.com/onmyojicard/629928','evidence':'鬼鳄唯一、基础+1力量的派生转录；永久效果迁移参考https://www.taptap.cn/moment/481417724480717268。日文页面已改版，未采用离场返匿息、基础能力每回合一次等新版内容。'}]
pending=['按27900–27908完整PNG及基础牌文接入。鬼鳄唯一、初始+1力量参考派生转录，永久增强与迁移按原牌文和中文配队实测解释实现；指定录像未逐牌覆盖。旧版鬼鳄中文派生完整词条/原图、唯一灵咒重新结附及移除后的永久效果载体、首次升级气绝边界、形态与觉醒同次出击全序仍待原客户端核验；未采用新版离场返匿息和每回合一次限制。']
base='第一次升级时结附「鬼鳄」。出击时获得1力量，若已结附「鬼鳄」，改为使「鬼鳄」效果永久获得+1力量。'
awake='己方式神出击时获得1力量，若已结附「鬼鳄」，改为使「鬼鳄」效果永久获得+1力量（气绝时有效）。本局游戏中匿息获得气绝时可用。'
data['units']['yinge']={'verifiedRules':True,'crocodileRules':True,'attack':2,'maxHp':4,'passive':{'id':'crocodile-growth','name':'鬼鳄','text':base,'hooks':[]},'awakenedPassive':{'id':'crocodile-awakened','name':'觉醒·影鳄','text':awake,'hooks':[]},'formLifecycle':{},'sources':sources,'verificationPending':pending}
raw=json.load(open('research-data/cards.json'));lookup={int(x['id']):x for x in raw}
texts={1:'使一个己方式神结附「鬼鳄」。若其已结附「鬼鳄」，改为使「鬼鳄」效果永久获得+1力量和+1生命。',2:'贯通\n若影鳄已结附「鬼鳄」，使「鬼鳄」效果永久获得贯通。',3:'进场时使一个己方式神结附「鬼鳄」。\n当己方式神结附「鬼鳄」时，使其获得迅捷。',4:'使影鳄结附「鬼鳄」。\n觉醒：'+awake,5:'先攻，追猎\n若影鳄已结附「鬼鳄」，使「鬼鳄」效果永久获得攻击时先攻。',6:'使一个己方式神结附「鬼鳄」并使其发起攻击，本次攻击免疫战斗伤害。',7:'增强：若影鳄已结附「鬼鳄」，此牌获得瞬发。\n当己方式神出击时，使其结附「鬼鳄」。',8:'若影鳄已结附「鬼鳄」，使「鬼鳄」效果永久获得+2力量和+2生命。'}
for n in range(1,9):
 id=f'c279{n:02}';typ='combat' if n in [2,5,8] else 'realm' if n==3 else 'form' if n==7 else 'spell';action={1:'nixi',2:'combat',3:'realm',4:'awaken',5:'combat',6:'hunt',7:'form',8:'combat'}[n]
 value={2:1,4:{'attack':1,'hp':1},5:2,7:{'attack':5,'hp':6,'setBase':True},8:1}.get(n,0)
 c={'verifiedRules':True,'crocodileRules':True,'type':typ,'typeLabel':{'spell':'法术牌','combat':'战斗牌','realm':'幻境牌','form':'形态牌'}[typ],'level':int(lookup[27900+n]['stage']),'cost':1,'text':texts[n],'officialText':texts[n],'keywords':['pierce'] if n==2 else ['first-strike','pursuit'] if n==5 else [],'timing':'main','responseTo':[],'autoResponse':'','formRules':{},'formHooks':[],'formAbility':'','target':'ally-unit' if n in [1,3,6] else 'enemy-unit' if n==5 else 'auto','effect':'form' if n==7 else 'crocodile-'+action,'value':value,'effects':[{'action':'form' if n==7 else 'crocodile-'+action,'target':'source','value':value}],'sources':sources,'verificationPending':pending}
 if n in [2,5,8]: c['combatOption']={'shield':1 if n==8 else 0,'pierce':n==2,'firstStrike':n==5,'pursuit':n==5}
 if n==3:c['realm']={'hp':5,'nativeRealm':'crocodile-shadow','trigger':'none','triggerEffect':''}
 if n==7:c['formRules']={'crocodileDeployment':True};c['formAbility']=texts[n].split('\n')[1]
 data['cards'][id]=c
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
