from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
rows=json.loads((out/'faction-slide.json').read_text());raw=json.loads((root/'godot/content/content.json').read_text())
units={};unknown={}
for row in rows:
    p=root/row['path'];item={**row,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'manualReview':'2026-10-29逐图目检faction-sheet-1/2/3中的四种官方派系图标。'}
    if row['role'] in ['182','298']:
        item['faction']='';item['reason']='完整式神PNG未显示四派图标；不采用颜色匹配到立绘的误判。'
        unknown[row['id']]=item
    else:
        units[row['id']]=item
for u in raw['units']:
    if u['id'] not in units and u['id'] not in unknown:
        unknown[u['id']]={'faction':'','reason':'未取得该独立入口的完整官方式神PNG派系图标；不按名称或历史近似推定。'}
payload={'schema':1,'basis':'完整原版式神PNG的四种派系标记，自动图标匹配后逐图目检。','units':units,'unverified':unknown}
(root/'godot/content/factions.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
(out/'faction-evidence.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
print('FACTION_KNOWN',len(units),'UNVERIFIED',len(unknown))
