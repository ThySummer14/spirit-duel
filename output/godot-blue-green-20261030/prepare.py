from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
raw = {int(c['id']): c for c in json.loads((root / 'research-data/cards.json').read_text())}
source_id = 'blue-green-original-20261030'
sources = [
    {'id': source_id, 'path': 'art-reference-official/卡面-按版本/09_四相琉璃/', 'evidence': '20600–20608、20700–20708完整原PNG；无染2/5、勾勒占卜2、窥秘第二青岚牌得1能量优先于旧snapshot。'},
    {'id': 'four-faction-awaken-fix-20210429-bg', 'url': 'https://www.taptap.cn/moment/136561818402291925', 'evidence': '再次使用四相觉醒不能令已获光环加成的单位无故恢复生命；亦确认勾勒不能因青岚衍生物在场而把混色队当纯青岚。'},
    {'id': 'blue-kurikara-observation', 'url': 'https://gamerch.com/onmyojicard/351763', 'evidence': '意临派生俱利伽罗丸：瞬发，对所有眩晕敌方式神造成2伤；中文控制新星攻略与英文wiki交叉一致。'},
    {'id': 'blue-kurikara-source-20210320', 'url': 'https://www.iyingdi.com/tz/post/2359841', 'evidence': '同期多位作者明确意临接瞬发衍生可触发樱雪姬基础能力，俱利伽罗丸按真实樱雪姬来源计入青岚用牌，不因token标记一律跳过。'},
    {'id': 'green-original-intro-20210313', 'url': 'https://www.taptap.cn/moment/119792466550326591', 'evidence': '官方净琉璃御前卡牌曝光；身材采用本地完整原PNG。'},
]
pending = [
    '采用206/207完整原PNG和基础牌文，指定录像未逐牌核验；多源响应、同时伤害与离场反应的完整顺序仍待原客户端核验。',
    '同派觉醒为在场光环；重复觉醒可使用且不得重复治疗已获光环单位，按2021-04-29官方修复接入。',
]
units = {}
for uid, role, faction, base, awake in [
    ('yingxueji', 'blue', '青岚', '每回合当你使用第二张青岚式神的牌时，投射：造成2点伤害。', '己方所有其他青岚式神获得1力量和1生命。本回合当你使用第二张青岚式神的牌时，投射：造成2点伤害。'),
    ('jingliuliqian', 'green', '苍叶', '当你使用其他苍叶式神的牌时，净琉璃御前本回合获得1力量。', '己方所有其他苍叶式神获得1力量和1生命。当你使用其他苍叶式神的牌时，净琉璃御前本回合获得1力量。'),
]:
    units[uid] = {'verifiedRules': True, 'blueGreenRole': role, 'attack': 2, 'maxHp': 5, 'passive': {'id': 'bg-' + role, 'name': faction + '之契', 'text': base, 'hooks': []}, 'awakenedPassive': {'id': 'bg-' + role + '-awake', 'name': faction + '之契', 'text': awake, 'hooks': []}, 'formLifecycle': {}, 'sources': [source_id, 'four-faction-awaken-fix-20210429-bg'], 'verificationPending': pending}
units['yingxueji']['sources'].append('blue-kurikara-source-20210320')

texts = {
    20601: '迅捷。增强：你每有一个未气绝的其他苍叶式神，此牌便获得1力量。',
    20602: '增强：本回合当你的运势判定成功时，此牌获得+1力量并随机强化一次。',
    20603: '对一个式神造成3点伤害。增强：若己方式神都为苍叶派系，此牌获得+1伤害和贯通。',
    20604: '己方苍叶式神对牌手造成的伤害+1。',
    20605: '倒计时3：发起攻击，本次攻击获得直击。每当你运势判定成功时，净琉璃御前倒计时-1。',
    20606: '觉醒：己方所有其他苍叶式神获得1力量和1生命。当你使用其他苍叶式神的牌时，净琉璃御前本回合获得1力量。',
    20607: '你的所有式神获得直击。',
    20608: '使己方所有苍叶式神本回合获得免疫战斗伤害，然后随机顺序各发动一次攻击。',
    20701: '眩晕一个式神。将一张「俱利伽罗丸」置入手牌。',
    20702: '充能。己方回合结束时，消耗4能量，投射：眩晕该角色。每回合当你使用第二张青岚式神的牌时，获得1能量。',
    20703: '抽两张牌。增强：若己方式神都为青岚派系，额外先占卜2。',
    20704: '远程。增强：你每有一个其他未气绝的青岚式神，此牌便获得1力量。',
    20705: '每回合当你使用第二张青岚式神的牌时，抽一张牌。',
    20706: '觉醒：己方所有其他青岚式神获得1力量和1生命。本回合当你使用第二张青岚式神的牌时，投射：造成2点伤害。',
    20707: '随机眩晕一个敌方式神，然后消灭所有眩晕的式神。',
    20708: '己方回合时己方所有青岚式神获得免疫战斗伤害以及眩晕被他造成战斗伤害的角色。',
}
actions = {20601: 'form', 20602: 'bg-combat', 20603: 'bg-revelation', 20604: 'realm', 20605: 'form', 20606: 'bg-awaken', 20607: 'bg-dark-feather', 20608: 'bg-team-attack', 20701: 'bg-intent', 20702: 'form', 20703: 'bg-outline', 20704: 'form', 20705: 'realm', 20706: 'bg-awaken', 20707: 'bg-freehand', 20708: 'realm'}
stats = {20601: (2, 5), 20605: (6, 5), 20702: (2, 5), 20704: (3, 6)}
realms = {20604: ('bg-glass', 6), 20705: ('bg-sakura', 6), 20708: ('bg-snow', 10)}
cards = {}
for number in list(range(20601, 20609)) + list(range(20701, 20709)):
    entry = raw[number]
    action = actions[number]
    typ = 'form' if number in stats else 'realm' if number in realms else 'combat' if number in [20602, 20608] else 'spell'
    c = {'verifiedRules': True, 'blueGreenRules': True, 'type': typ, 'typeLabel': {'form': '形态牌', 'realm': '幻境牌', 'combat': '战斗牌', 'spell': '法术牌'}[typ], 'level': int(entry['stage']), 'cost': 1, 'copies': 2, 'deckLimit': 2, 'target': 'any-unit' if number in [20603, 20701] else 'auto', 'text': texts[number], 'officialText': texts[number], 'effect': action, 'value': 0, 'keywords': [], 'tags': [], 'timing': 'main', 'responseTo': [], 'formRules': {}, 'formHooks': [], 'formAbility': '', 'sources': [source_id], 'verificationPending': pending}
    if number in stats:
        attack, hp = stats[number]
        c['value'] = {'attack': attack, 'hp': hp, 'setBase': True}
        c['formAbility'] = c['text']
    if number in realms:
        key, hp = realms[number]
        c['realm'] = {'nativeRealm': key, 'hp': hp, 'trigger': 'native-continuous', 'triggerEffect': ''}
    if number in [20606, 20706]: c.update(awakening=True, tags=['觉醒'], value={'attack': 1, 'hp': 1})
    if number == 20601: c['keywords'] = ['swift']
    if number == 20602:
        c.update(value=1, combatOption={'shield': 1}, responseAction='assault', bgMingchePool=[])
        c['verifiedRules'] = False
        c['verificationPending'] = pending + ['明澈10个官方buff ID尚缺完整释义，日文7词条资料与官方10ID冲突；未配置随机强化池，本卡不得计入已完成范围。']
    if number == 20603: c['value'] = 3
    if number == 20605: c['formRules'] = {'countdown': 3, 'bgTwin': True, 'countdownEffects': [{'action': 'bg-twin-attack', 'target': 'source', 'value': 0}]}
    if number == 20608: c['responseAction'] = 'assault'
    if number == 20702: c['formRules'] = {'bgCharging': True, 'nativeCharge': True}
    if number == 20704: c['keywords'] = ['remote']; c['formRules'] = {'combatKeywords': ['remote']}
    c['effects'] = [{'action': action, 'target': 'selected' if number in [20603, 20701] else 'source', 'value': c['value']}]
    cards[f'c{number}'] = c
cards['c20701']['sources'].append('blue-kurikara-source-20210320')

cards['julijialuo-wan'] = {'verifiedRules': True, 'blueGreenRules': True, 'type': 'spell', 'level': 1, 'cost': 1, 'copies': 0, 'deckLimit': 0, 'token': True, 'keywords': ['instant'], 'text': '瞬发。对所有眩晕的敌方式神造成2点伤害。', 'officialText': '瞬发。对所有眩晕的敌方式神造成2点伤害。', 'target': 'auto', 'effect': 'bg-kurikara', 'value': 2, 'effects': [{'action': 'bg-kurikara', 'target': 'all-enemy-units', 'value': 2}], 'tags': [], 'sources': ['blue-kurikara-observation'], 'verificationPending': pending + ['派生缺独立本地原PNG；采用中日英文资料一致的瞬发与全体眩晕敌方式神2伤，重复用瞬发后的鬼火费用仍待原客户端核验。']}
cards['julijialuo-wan']['sources'].append('blue-kurikara-source-20210320')
(out / 'overlay.json').write_text(json.dumps({'units': units, 'cards': cards, 'sources': sources}, ensure_ascii=False, indent=2) + '\n')
manifest = []
for number in list(range(20601, 20609)) + list(range(20701, 20709)):
    source = next((root / 'art-reference-official/卡面-按版本/09_四相琉璃').glob(f'{number // 100}_* /{number}_*.png'.replace(' ', '')))
    target = root / f'godot/assets/official/cards/c{number}.png'
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    manifest.append({'source': str(source.relative_to(root)), 'target': str(target.relative_to(root)), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest()})
(out / 'card-art-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print('BLUE_GREEN_PREPARED main_cards=16 derivative=1; c20602 RANDOM_POOL_UNRESOLVED')
