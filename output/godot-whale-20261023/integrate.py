from pathlib import Path
import json

def edit(path,a,b,n=1):
 p=Path(path);s=p.read_text();assert s.count(a)==n,(path,a,s.count(a));p.write_text(s.replace(a,b))
p='godot/scripts/verified_card_rules.gd'
edit(p,'const Jorogumo :=','const Whale := preload("res://scripts/whale_rules.gd")\nconst Jorogumo :=')
edit(p,'\tif Jorogumo.resolve_action','\tif Whale.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true\n\tif Jorogumo.resolve_action')
edit(p,'static func end_turn(gs, p_idx: int) -> void:\n','static func end_turn(gs, p_idx: int) -> void:\n\tWhale.end_turn(gs)\n')
edit(p,'static func knocked_out(unit: Dictionary) -> void:\n','static func knocked_out(unit: Dictionary) -> void:\n\tWhale.knocked_out(unit)\n')
p='godot/scripts/game_state.gd'
edit(p,'\tif pending_choice.get("type") == "movement-burst":','\tif pending_choice.get("type") == "whale-awaken": return VerifiedRules.Whale.resolve_choice(self,p_idx,instance_id)\n\tif pending_choice.get("type") == "movement-burst":')
edit(p,'\tcard = VerifiedRules.Jorogumo.describe_card','\tcard = VerifiedRules.Whale.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.Jorogumo.describe_card')
edit(p,'for targets in [VerifiedRules.Jorogumo.targets','for targets in [VerifiedRules.Whale.targets(self,p_idx,card),VerifiedRules.Jorogumo.targets')
edit(p,'\tif not VerifiedRules.Jorogumo.can_use','\tif not VerifiedRules.Whale.can_use(self,p_idx,card): return {"ok":false,"reason":"化鲸已觉醒或所选爆能不可支付。"}\n\tif not VerifiedRules.Jorogumo.can_use')
edit(p,'\tif VerifiedRules.Jorogumo.resolve_frame','\tif VerifiedRules.Whale.resolve_frame(self,frame): return\n\tif VerifiedRules.Jorogumo.resolve_frame')
edit(p,'\t\tVerifiedRules.Jorogumo.remove_departed(self)','\t\tVerifiedRules.Jorogumo.remove_departed(self)\n\t\tVerifiedRules.Whale.remove_departed(self)',2)
edit(p,'\t\tif not attacker.get("jorogumoSwarm",false):','\t\tif not attacker.get("whaleGuardian",false): VerifiedRules.Whale.clear_summons(self,p_idx)\n\t\tif not attacker.get("jorogumoSwarm",false):')
edit(p,'\tVerifiedRules.Movement.combat_finished(self, owner, src, options)','\tVerifiedRules.Movement.combat_finished(self, owner, src, options)\n\tVerifiedRules.Whale.combat_finished(self,owner,src,options)')
edit(p,'\t\tVerifiedRules.event(self, "combat-hit", {"player": p_idx, "uid": attacker.uid, "target": ""})','\t\toptions.whaleAttackStarted=true\n\t\tVerifiedRules.event(self, "combat-hit", {"player": p_idx, "uid": attacker.uid, "target": ""})')
edit(p,'\tVerifiedRules.event(self, "combat-hit", {"player": owner, "uid": attacker.uid, "target": defender.uid})','\toptions.whaleAttackStarted=true\n\tVerifiedRules.event(self, "combat-hit", {"player": owner, "uid": attacker.uid, "target": defender.uid})')
edit(p,'\tif u.get("jorogumoSwarm",false):','\tif u.get("whaleGuardian",false):\n\t\tu.hp=0; u.front=0; u.knockout=0; u.removed=true\n\tif u.get("jorogumoSwarm",false):')
p='godot/scripts/battle_skill_rules.gd'
edit(p,'\t\t\tgs.VerifiedRules.Garuda.before_basic(gs, owner, src)','\t\t\tgs.VerifiedRules.Garuda.before_basic(gs, owner, src)\n\t\t\tgs.VerifiedRules.Whale.before_basic(gs,owner,src)')
p='godot/scripts/movement_rules.gd'
edit(p,' if amount > 0 and not Charge.pay_charge(gs, owner, src, amount): return true',' if amount > 0 and not Charge.pay_charge(gs, owner, src, amount): return true\n if amount > 0: gs.VerifiedRules.Whale.burst(gs,owner,src,amount)')
edit(p,'  if unit.get("jorogumoSwarm",false):','  if unit.get("whaleGuardian",false):\n   gs.VerifiedRules.Whale.remove_summon(gs,owner,unit)\n   return true\n  if unit.get("jorogumoSwarm",false):')
p='godot/scripts/sun_smoke_rules.gd'
edit(p,'\t\tif pay_charge(gs, owner, src, energy): amount += energy','\t\tif pay_charge(gs, owner, src, energy):\n\t\t\tamount += energy\n\t\t\tgs.VerifiedRules.Whale.burst(gs,owner,src,energy)')
p='godot/scripts/weaver_rules.gd'
edit(p,'\t\telif old.get("jorogumoSwarm",false):','\t\telif old.get("whaleGuardian",false): gs.VerifiedRules.Whale.remove_summon(gs,owner,old,"战斗区被替换")\n\t\telif old.get("jorogumoSwarm",false):')
p='godot/scripts/moon_rules.gd'
edit(p,'\tgs.VerifiedRules.Onikiri.remove_charms(unit)','\tgs.VerifiedRules.Whale.remove_charms(unit)\n\tgs.VerifiedRules.Onikiri.remove_charms(unit)')
p='godot/scripts/sparrow_rules.gd'
edit(p,'\tfor key in ["spiderMark",','\tgs.VerifiedRules.Whale.remove_charms(u,false)\n\tfor key in ["spiderMark",')
p='godot/scripts/pipe_fox_rules.gd'
edit(p,'\t\tif not unit.get("spiderMark",{}).is_empty()', '\t\tfor kind in ["Tooth","Body"]:\n\t\t\tvar key := "whale"+kind\n\t\t\tif not unit.get(key,{}).is_empty() and int(unit[key].sourceOwner)!=owner:\n\t\t\t\tvar e:=base.duplicate(); e.key=key; out.append(e)\n\t\tif not unit.get("spiderMark",{}).is_empty()')
edit(p,'"spiderMark", "garudaFeather": target.erase(key)','"whaleTooth", "whaleBody", "spiderMark", "garudaFeather": target.erase(key)')
p='godot/scripts/ui/battle_status.gd'
edit(p,'\tview.jorogumoMarks=','\tview.whaleMarks=gs.VerifiedRules.Whale.unit_marks(gs,owner,idx)\n\tview.jorogumoMarks=')
edit(p,'\tfor detail in unit.get("jorogumoMarks",[]):','\tfor detail in unit.get("whaleMarks",[]): result.append(mark("whale-rule",str(detail),str(detail),"80c0e0"))\n\tfor detail in unit.get("jorogumoMarks",[]):')
p='godot/scripts/ui/battle_screen.gd'
edit(p,'for choice_card in [gs.VerifiedRules.Yitiao.choice_card','for choice_card in [gs.VerifiedRules.Whale.choice_card(gs,PLAYER,str(iid)),gs.VerifiedRules.Yitiao.choice_card')
p='godot/scripts/ui/battle_effect_cues.gd'
edit(p,'"jorogumo-card-hit",','"whale-tooth-hit", "jorogumo-card-hit",')
p='godot/scripts/game_ai.gd'
edit(p,'\tgs.VerifiedRules.Movement.ai_prepare(gs, p_idx)','\tgs.VerifiedRules.Whale.ai_prepare(gs,p_idx)\n\tgs.VerifiedRules.Movement.ai_prepare(gs, p_idx)')
edit(p,'\tvar jorogumo_score =','\tvar whale_score = _gs.VerifiedRules.Whale.score_card(_gs,p_idx,card,_target)\n\tif whale_score != null: return int(whale_score)\n\tvar jorogumo_score =')
edit(p,'\tif gs.pending_choice.get("type") == "movement-burst":','\tif gs.pending_choice.get("type") == "whale-awaken": return gs.VerifiedRules.Whale.ai_choice(gs,p_idx)\n\tif gs.pending_choice.get("type") == "movement-burst":')
p='scripts/godot-verify.sh';edit(p,'verify_jorogumo verify_combat','verify_jorogumo verify_whale verify_combat')
p='godot/scripts/whale_rules.gd'
edit(p,'\t\t\t\tgs._add_card_to_hand(owner,"c27802" if card.id=="c27801" else "c27801")','\t\t\t\tgs.player(owner).hand.append({"instanceId":"%s-whale-%d"%[gs.player(owner).id,gs.next_card_id],"definitionId":"c27802" if card.id=="c27801" else "c27801"})\n\t\t\t\tgs.next_card_id+=1')

p=Path('godot/content/verified_rules.json');data=json.loads(p.read_text())
sources=['whale-original-faces','whale-official-snapshot','whale-charms-guardian']
for id,kind,label,ref in [('whale-original-faces','local-original-card-images','化鲸27800–27808完整卡面','art-reference-official/卡面-按版本/16_远山遥泽/278_化鲸/'),('whale-official-snapshot','official-card-database','官网化鲸基础牌文快照','https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js'),('whale-charms-guardian','secondary-client-transcription','齿甲体甲、母亲的守护词条转录','https://gamerch.com/onmyojicard/629910')]:
 data['sources'].append({'id':id,'type':kind,'title':label,'path':ref} if ref.startswith('art-') else {'id':id,'type':kind,'title':label,'url':ref})
pending=['按27800–27808完整PNG及基础牌文接入；齿甲投射2、体甲自疗2且溢出治疗牌手、母亲的守护3/3与障壁按日文客户端词条补齐，中文派生原图待核。指定录像未逐牌覆盖；同次出击触发全序、永久灵咒被移除/替身的边界、孤鲸已进场后的后续爆能增长，以及爆能X为0的判定仍待原客户端核验。']
base='充能。每回合一次，当己方式神出击时，化鲸获得1能量。'
awake='充能。每回合一次，当己方式神出击时，化鲸获得1能量，并额外触发结附于化鲸的「齿甲」和「体甲」一次。'
data['units']['huajing']={'verifiedRules':True,'whaleRules':True,'nativeCharge':True,'attack':2,'maxHp':6,'passive':{'id':'whale-charge','name':'充能','text':base,'hooks':[]},'awakenedPassive':{'id':'whale-awakened','name':'觉醒·化鲸','text':awake,'hooks':[]},'sources':sources,'verificationPending':pending,'formLifecycle':{}}
raw=json.load(open('research-data/cards.json'))
texts={1:'瞬发，使一个己方式神结附「齿甲」（不能叠加）。\n爆能3：将一张「体甲」置入手牌。',2:'瞬发，使一个己方式神结附「体甲」（不能叠加）。\n爆能3：将一张「齿甲」置入手牌。',3:'对一个式神造成3点伤害，然后使己方所有结附「齿甲」或「体甲」的式神本回合获得迅捷。',4:'当己方式神爆能时，若你战斗区没有式神，召唤一个「母亲的守护」。\n爆能3：召唤一个「母亲的守护」。',5:'战技\n攻击后召唤一个「母亲的守护」。',6:'使化鲸永久结附「齿甲」或「体甲」。\n觉醒：'+awake,7:'帷幕\n本局游戏己方式神每爆能过一次，此牌便获得2力量和2生命。',8:'使一个己方式神结附「齿甲」和「体甲」，并且在本回合获得迅捷、昂扬。\n爆能5：然后随机对另一个己方式神复制此效果。\n爆能10：改为随机对另两个己方式神复制此效果。'}
for n in range(1,9):
 id=f'c278{n:02}';type='realm' if n==4 else 'combat' if n==5 else 'form' if n==7 else 'spell'
 c={'verifiedRules':True,'whaleRules':True,'type':type,'typeLabel':{'spell':'法术牌','realm':'幻境牌','combat':'战斗牌','form':'形态牌'}[type],'level':1 if n<4 else 3 if n>6 else 2,'cost':1,'text':texts[n],'officialText':texts[n],'keywords':['instant'] if n<3 else ['veil'] if n==7 else [],'timing':'main','responseTo':[],'autoResponse':'','formRules':{},'formHooks':[],'formAbility':'','target':'ally-unit' if n in [1,2,8] else 'any-unit' if n==3 else 'auto','effect':'whale-card','value':0,'effects':[{'action':'whale-card','target':'source','value':0}],'sources':sources,'verificationPending':pending}
 if n in [1,2,4,8]:c['movementBurstOptions']=[5,10] if n==8 else [3]
 if n==4:c['realm']={'hp':6,'nativeRealm':'whale-sea','trigger':'none','triggerEffect':''}
 if n==5:c['battleSkill']=True;c['value']=1
 if n==7:c['value']={'attack':3,'hp':3,'setBase':True};c['formRules']={'combatKeywords':['veil']}
 data['cards'][id]=c
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
