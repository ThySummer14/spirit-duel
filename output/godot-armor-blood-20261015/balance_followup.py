from pathlib import Path
import json
p=Path('godot/content/verified_rules.json');v=json.loads(p.read_text())
v['sources'] += [{'id':'blood-scent-balance-20200928','url':'https://www.taptap.cn/moment/59609610805317142','evidence':'官方常规平衡：血香增强改为生命30时免疫战斗伤害，覆盖旧卡库连击；2023玩家资料仍写连击，未找到官方回调，保留冲突。'},{'id':'poison-healing-balance-20230629','url':'https://www.taptap.cn/moment/423224857543574099','evidence':'官方常规平衡：中毒不再禁止治疗及生命上升，覆盖2023-04-27福满乾坤禁回复旧修复。'}]
c=v['cards']['c17306'];c['sources'].append('blood-scent-balance-20200928');c['text']=c['officialText']='增强：若你生命值为30，此牌获得免疫战斗伤害。'
c['verificationPending'].append('血香2020-09-28官方改为免疫战斗伤害，2023原作者组牌资料仍写连击；尚未找到官方回调及指定录像牌面。当前采用可追溯官方改版。')
c['ruleFidelity']['pending']=c['verificationPending']
for id,text in {
 'c12905':'当青行灯攻击时，获得一张「明灯」。',
 'c12907':'投射：造成5点伤害。你每有1点鬼火便重复一次。清空你的鬼火。',
 'c13001':'进场和己方回合开始时，双方牌手运势4：抽一张牌。',
 'c13002':'进场和己方回合开始时，双方牌手运势4：恢复3点生命。',
 'c13008':'增强：本局游戏若双方运势判定成功12次，则双方生命变为30，抽手牌直至十张，获得3点鬼火。'
}.items():
 c=v['cards'][id];c['text']=c['officialText']=text;c['sources'].append('blood-balance-20220126')
 if id in ['c12905','c13001','c13002']:c['formAbility']=text
 if id=='c12905':c['formRules']={'lanternAttackFire':True}
 if id=='c13008':
  c['sources'].append('poison-healing-balance-20230629');c['verificationPending']=['用户指定录像及2023之后常规版本尚未穷尽核验。'];c['ruleFidelity']={'status':'source-backed-pending','pending':c['verificationPending']}
p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
p=Path('godot/scripts/armor_blood_rules.gd');s=p.read_text().replace('view.keywords = ["combo"]\n\t\tview.text += "\\n已增强：连击。"','view.combatOption.immuneCombat = true\n\t\tview.text += "\\n已增强：免疫战斗伤害。"');p.write_text(s)
p=Path('godot/scripts/light_healer_rules.gd');s=p.read_text().replace('static func before_attack(gs, owner: int, src: int) -> bool:\n\tvar zero', 'static func before_attack(gs, owner: int, src: int) -> bool:\n\tif gs.player(owner).units[src].get("formRules", {}).get("lanternAttackFire", false): add_lantern(gs, owner)\n\tvar zero')
a=s.index('static func combat_dealt(');b=s.index('\nstatic func form_entered',a)
s=s[:a]+'''static func combat_dealt(_gs, _owner: int, _src: int, _victim: int, _idx: int, _result: Dictionary) -> void:
	pass
'''+s[b:]
s=s.replace('static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:\n','static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:\n\tif card.get("formRules", {}).has("fortuneTurnStart"): form_turn_start(gs, owner, src)\n')
s=s.replace('4 + int(card.get("foxHandDamageBonus", 0))','5 + int(card.get("foxHandDamageBonus", 0))')
s=s.replace('fortune_total(gs) >= 15','fortune_total(gs) >= 12').replace('%d/15','%d/12')
s=s.replace('if not recipient.get("avatarHealingBlocked", false): recipient.avatarHp = mini(30, int(recipient.maxAvatarHp))','recipient.avatarHp = mini(30, int(recipient.maxAvatarHp))');p.write_text(s)
p=Path('godot/scripts/ui/battle_status.gd');s=p.read_text().replace('双方运势 %d/15','双方运势 %d/12');p.write_text(s)
