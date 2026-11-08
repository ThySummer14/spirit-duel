from pathlib import Path
import json,sys,re,ast,shutil
root=Path(__file__).resolve().parents[2]
p=root/'godot/content/verified_rules.json';data=json.loads(p.read_text())
for rel in sys.argv[1:]:
 folder=root/rel;overlay=json.loads((folder/'overlay.json').read_text())
 for k in ['units','cards']:data[k].update(overlay[k])
 for source in overlay['sources']:
  if not any(s['id']==source['id'] for s in data['sources']):data['sources'].append(source)
 definitions=json.loads((folder/'new_definitions.json').read_text())
 for unit in definitions.get('units',[]):
  for art in set([unit['art'],unit.get('awakenedArt',unit['art'])]):
   dest=root/art;src=root/'godot'/art
   if not dest.exists() and src.exists():dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
  wave=int(unit.get('pack','wave5').replace('wave',''));gen=root/f'scripts/gen-wave{wave}-content.py';js=root/f'game-content-wave{wave}.js'
  extra={**unit,'awakenedArt':unit.get('awakenedArt',unit['art'])}
  if re.search(r'"id":\s*"'+re.escape(unit['id'])+r'"|id:\s*"'+re.escape(unit['id'])+r'"',js.read_text()):
   lines=js.read_text().splitlines()
   for i,line in enumerate(lines):
    if line.strip().startswith('{"id": "'+unit['id']+'"'):
     lines[i]='  '+json.dumps(extra,ensure_ascii=False)+','
   js.write_text('\n'.join(lines)+'\n')
   lines=gen.read_text().splitlines()
   for i,line in enumerate(lines):
    if line.startswith('EXTRA_UNITS += '):
     units=ast.literal_eval(line.split(' += ',1)[1]);changed=False
     for n,old in enumerate(units):
      if old['id']==unit['id']:units[n]=extra;changed=True
     if changed:lines[i]='EXTRA_UNITS += '+repr(units)
   gen.write_text('\n'.join(lines)+'\n');continue
  text=gen.read_text()
  if 'EXTRA_UNITS = []' not in text:
   text=text.replace('def main() -> None:', 'EXTRA_UNITS = []\n\n\ndef main() -> None:',1)
   unit_pos=text.index(f'lines.append("export const WAVE{wave}_UNIT_DEFINITIONS')
   end_pos=text.index('    lines.append("]);")',unit_pos)
   text=text[:end_pos]+'    for extra_unit in EXTRA_UNITS:\n        lines.append("  " + json.dumps(extra_unit, ensure_ascii=False) + ",")\n\n'+text[end_pos:]
  text=text.replace('def main() -> None:',f'EXTRA_UNITS += {repr([extra])}\n\n\ndef main() -> None:',1);gen.write_text(text)
  text=js.read_text();anchor=']);\n\nfunction eff(';assert text.count(anchor)==1
  text=text.replace(anchor,'  '+json.dumps(extra,ensure_ascii=False)+',\n'+anchor,1);js.write_text(text)
 for card in definitions['cards']:
  uid=card['unitId']; wave=next((w for w in range(3,10) if f'("{uid}",' in (root/f'scripts/gen-wave{w}-content.py').read_text()),5)
  gen=root/f'scripts/gen-wave{wave}-content.py';js=root/f'game-content-wave{wave}.js'
  if re.search(r'"id":\s*"'+re.escape(card['id'])+r'"|id:\s*"'+re.escape(card['id'])+r'"',js.read_text()):continue
  text=gen.read_text();tok={k:card[k] for k in ['id','unitId','name','type','level','cost','text','target']};tok.update(deckLimit=0,token=True,starter=0)
  tok['effects']=[['always',e['action'],e['target'],e.get('value')] for e in card['effects']]
  text=text.replace('def main() -> None:',f'EXTRA_TOKENS += {repr([tok])}\n\n\ndef main() -> None:',1);gen.write_text(text)
  match=re.search(r'\("'+uid+r'",.*?"([^\"]+)"\),',text)
  subpack=match.group(1) if match else 'xuanhua'
  body=json.dumps({**tok,'subpack':subpack},ensure_ascii=False,indent=4)
  text=js.read_text();anchor=f']);\n\nexport function getWave{wave}UnitIds()';assert anchor in text
  text=text.replace(anchor,f'  wave{wave}Card(0, "{uid}", {body}),\n'+anchor,1);js.write_text(text)
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('merged',*sys.argv[1:])
