import urllib.request,urllib.parse,gzip,json,re
from pathlib import Path
out=Path(__file__).resolve().parent
headers={'User-Agent':'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36','Referer':'https://www.bilibili.com/'}
def get(url):
 r=urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=25);b=r.read();return (gzip.decompress(b) if b[:2]==b'\x1f\x8b' else b).decode()
initial=json.loads((out/'__INITIAL_STATE__.json').read_text());v=initial['videoData']
url='https://api.bilibili.com/x/player/playurl?'+urllib.parse.urlencode({'avid':v['aid'],'cid':v['cid'],'qn':32,'fnval':0,'fourk':0})
try:
 x=json.loads(get(url));(out/'entrance-playurl.json').write_text(json.dumps(x,ensure_ascii=False));print('public playurl',x.get('code'),x.get('message'),'video data',list(x.get('data') or {}))
except Exception as e:print('public playurl',type(e).__name__,str(e))
for name,query in [('huang','百闻牌 昂扬配荒 物理月坠'),('attachment','百闻牌 御馔津 三带一')]:
 try:
  s=get('https://search.bilibili.com/all?'+urllib.parse.urlencode({'keyword':query}));(out/(name+'-search.html')).write_text(s)
  hits=list(dict.fromkeys(re.findall(r'BV[0-9A-Za-z]{10}',s)))
  print(name,'bytes',len(s),'bvids',hits[:12])
 except Exception as e:print(name,type(e).__name__,str(e))
