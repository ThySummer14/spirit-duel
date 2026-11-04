"""Complete the six remaining Ebisu cards from the basic local card text."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[2]
path = root / 'godot/content/verified_rules.json'
x = json.loads(path.read_text())
source = {'id': 'ebisu-basic-rules-20261017', 'path': 'research-data/cards.json',
          'evidence': '20902/20903/20904/20906/20907/20908 基础牌文、形态面板与幻境耐久；按用户要求不逐赛季追查平衡。'}
if not any(s['id'] == source['id'] for s in x['sources']): x['sources'].append(source)
pending = ['按用户要求采用基础卡库机制，不逐赛季追踪平衡；指定主录像没有惠比寿。三勾重复升级、临时等级与同次升级复活的极端组合仍可按实机继续校准。']
base = {'verifiedRules': True, 'blessingRules': True, 'cost': 1, 'copies': 2, 'deckLimit': 2,
        'keywords': [], 'tags': [], 'timing': 'main', 'responseTo': [], 'formHooks': [],
        'formRules': {}, 'formAbility': '', 'combatOption': {}, 'sources': [source['id']],
        'verificationPending': pending, 'ruleFidelity': {'status': 'source-backed-pending', 'pending': pending}}

def card(id, type, level, text, action, target='auto', value=0, **extra):
    data = dict(base, type=type, typeLabel={'form':'形态牌','spell':'法术牌','realm':'幻境牌'}[type],
                level=level, text=text, effect=action, target=target, value=value,
                effects=[{'condition':'always','action':action,'target':'selected' if target != 'auto' else 'source','value':value}])
    data.update(extra)
    x['cards'][id] = data

card('c20902', 'spell', 1, '使一个式神获得1力量和1生命，抽一张牌。增强：若己方式神等级都≥3，改为使其获得5力量和5生命。',
     'blessing-omen', 'any-living-unit', 1, blessingEnhance=True)
card('c20903', 'form', 2, '当己方气绝的式神升级时，使其复活。', 'form', value={'attack':3,'hp':6,'setBase':True},
     formRules={'blessingRevive':True}, formAbility='当己方气绝的式神升级时，使其复活。')
card('c20904', 'spell', 2, '使一个己方其他式神本回合等级+1，且该式神本回合无法使用幻境、形态或觉醒牌。',
     'blessing-temporary-level', 'ally-unit-any-state', blessingRaises=True)
card('c20906', 'form', 3, '当己方式神升级时，从牌库里将一张该式神的牌置入手牌并获得瞬发。', 'form',
     value={'attack':3,'hp':8,'setBase':True}, formRules={'blessingSearch':True},
     formAbility='当己方式神升级时，从牌库里将一张该式神的牌置入手牌并获得瞬发。')
card('c20907', 'realm', 3, '己方等级为3的式神依然可以升级。当己方等级为3的式神升级时，改为使其永久获得5力量和5生命，然后随机获得一张该式神等级为3的牌。',
     'realm', value=None, realm={'hp':10,'nativeRealm':'ebisu-overlevel','trigger':'native-continuous'})
card('c20908', 'spell', 3, '随机使己方一个等级最低的式神等级+1，之后将该效果额外重复一次。',
     'blessing-wander', blessingRaises=True)
x['units']['huibishou']['formLifecycle'] = {}
for obj in [x['units']['huibishou'], x['cards']['c20901'], x['cards']['c20905']]:
    obj['verificationPending'] = pending
    obj['ruleFidelity'] = {'status':'source-backed-pending','pending':pending}
path.write_text(json.dumps(x, ensure_ascii=False, indent=2)+'\n')
