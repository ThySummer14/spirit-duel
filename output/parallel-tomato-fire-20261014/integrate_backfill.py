import json,sys,shutil
from pathlib import Path
root=Path(sys.argv[1]).resolve();source=Path(__file__).resolve().parents[2]
p=json.loads(Path(__file__).with_name('backfill_overlay.json').read_text());v=json.loads((root/'content/verified_rules.json').read_text())
if 'poison-snake-balance-2020-06-24' not in {s['id']for s in v['sources']}:v['sources']+=p['sources']
for id,fields in p['cards'].items():v['cards'][id].update(fields)
for name in ['poison_rules.gd','verify_poison_pair.gd','verify_poison_pair_ui.gd']:
 src=source/'godot/scripts'/name;dst=root/'scripts'/name
 if src.resolve()!=dst.resolve():shutil.copy2(src,dst)
(root/'content/verified_rules.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
print('POISON_SNAKE_BACKFILL_OK',root)
