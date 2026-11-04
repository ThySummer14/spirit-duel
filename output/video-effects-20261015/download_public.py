"""Download one publicly playable Bilibili video without account credentials."""
from pathlib import Path
import gzip,json,re,subprocess,sys,urllib.parse,urllib.request
out=Path(__file__).resolve().parent
bv=sys.argv[1]
url='https://www.bilibili.com/video/'+bv+'/'
headers={'User-Agent':'Mozilla/5.0','Referer':url}
def get(u):
 r=urllib.request.urlopen(urllib.request.Request(u,headers=headers),timeout=30);b=r.read();return (gzip.decompress(b) if b[:2]==b'\x1f\x8b' else b).decode()
s=get(url);m=re.search(r'window\.__INITIAL_STATE__\s*=\s*',s)
if not m:raise RuntimeError('Public page did not provide video metadata')
x=json.JSONDecoder().raw_decode(s[m.end():])[0];v=x['videoData']
meta={k:v.get(k) for k in ['bvid','cid','aid','title','duration','pubdate','owner','desc']};meta['url']=url
(out/(bv+'-source.json')).write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n');print(meta,flush=True)
x=json.loads(get('https://api.bilibili.com/x/player/playurl?'+urllib.parse.urlencode({'avid':v['aid'],'cid':v['cid'],'qn':32,'fnval':0,'fourk':0})))
if x.get('code')!=0:raise RuntimeError('Public playback unavailable: '+str(x.get('message')))
segments=x['data'].get('durl',[])
if len(segments)!=1:raise RuntimeError('Expected one publicly playable segment')
dest=out/'media'/(bv+'-part0.flv')
with urllib.request.urlopen(urllib.request.Request(segments[0]['url'],headers=headers),timeout=30) as r,dest.open('wb') as f:
 while chunk:=r.read(1024*1024):f.write(chunk)
print('downloaded',dest.name,dest.stat().st_size,flush=True)
p=subprocess.run(['ffmpeg','-y','-v','error','-i',str(dest),'-c','copy',str(out/'media'/(bv+'.mp4'))],capture_output=True,text=True)
if p.returncode:raise RuntimeError('Remux failed: '+p.stderr[-400:])
dest.unlink()
print('MP4_READY',bv,flush=True)
