from pathlib import Path
import re,json
folder=Path(__file__).parent/'regressions';entries=[]
for file in sorted(folder.glob('*.log')):
 s=file.read_text();lines=[x for x in s.splitlines() if re.search(r'(?:checks|CHECKS|_OK|FAIL|ERROR:)',x)]
 bad=bool(re.search(r'(?:SCRIPT )?ERROR:|FAILURES [1-9]|failures["=: ]+[1-9]|(?:^|_)FAILED|(?:^|_)FAIL ',s,re.M))
 passed=not bad and bool(re.search(r'_OK|failures["=: ]+0|FAILURES 0',s))
 entries.append({'name':file.stem,'passed':passed,'summary':lines[-2:]})
(folder/'final-results.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(entries,ensure_ascii=False,indent=2));assert all(x['passed'] for x in entries)
