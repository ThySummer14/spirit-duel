from pathlib import Path
import json,sys,re
root=Path(__file__).resolve().parents[2]
p=root/'godot/content/verified_rules.json';data=json.loads(p.read_text())
for rel in sys.argv[1:]:
 folder=root/rel;overlay=json.loads((folder/'overlay.json').read_text())
 for k in ['units','cards']:data[k].update(overlay[k])
 for source in overlay['sources']:
  if not any(s['id']==source['id'] for s in data['sources']):data['sources'].append(source)
 for card in json.loads((folder/'new_definitions.json').read_text())['cards']:
  uid=card['unitId']; wave=next(w for w in range(3,10) if f'("{uid}",' in (root/f'scripts/gen-wave{w}-content.py').read_text())
  gen=root/f'scripts/gen-wave{wave}-content.py';js=root/f'game-content-wave{wave}.js'
  if re.search(r'"id":\s*"'+re.escape(card['id'])+r'"|id:\s*"'+re.escape(card['id'])+r'"',js.read_text()):continue
  text=gen.read_text();tok={k:card[k] for k in ['id','unitId','name','type','level','cost','text','target']};tok.update(deckLimit=0,token=True,starter=0)
  tok['effects']=[['always',e['action'],e['target'],e.get('value')] for e in card['effects']]
  text=text.replace('def main() -> None:',f'EXTRA_TOKENS += {repr([tok])}\n\n\ndef main() -> None:',1);gen.write_text(text)
  subpack=re.search(r'\("'+uid+r'",.*?"([^\"]+)"\),',text).group(1)
  body=json.dumps({**tok,'subpack':subpack},ensure_ascii=False,indent=4)
  text=js.read_text();anchor=f']);\n\nexport function getWave{wave}UnitIds()';assert anchor in text
  text=text.replace(anchor,f'  wave{wave}Card(0, "{uid}", {body}),\n'+anchor,1);js.write_text(text)
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('merged',*sys.argv[1:])
