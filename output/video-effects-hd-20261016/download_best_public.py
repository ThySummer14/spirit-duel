"""Keep the largest actual public DASH track; never upscale or use account cookies."""
from pathlib import Path
import hashlib, json, subprocess, sys, urllib.request

out = Path(__file__).resolve().parent
bv = sys.argv[1]
data = json.loads((out / (bv + '-playback.json')).read_text())['data']
dash = data['dash']
video = max(dash['video'], key=lambda t: (t['width'] * t['height'], t['bandwidth']))
audio = max(dash.get('audio', []), key=lambda t: t['bandwidth'], default=None)
headers = {'User-Agent': 'Mozilla/5.0', 'Referer': f'https://www.bilibili.com/video/{bv}/'}
media = out / 'media'
media.mkdir(exist_ok=True)
parts = []
for kind, track in [('video', video), ('audio', audio)]:
    if not track: continue
    dest = media / f'{bv}-{kind}.m4s'
    req = urllib.request.Request(track.get('baseUrl', track.get('base_url')), headers=headers)
    with urllib.request.urlopen(req, timeout=30) as r, dest.open('wb') as f:
        while chunk := r.read(1024 * 1024): f.write(chunk)
    parts.append(dest)
    print(kind, dest.stat().st_size, flush=True)
dest = media / (bv + '.mp4')
cmd = ['ffmpeg', '-y', '-v', 'error']
for part in parts: cmd += ['-i', str(part)]
subprocess.run(cmd + ['-c', 'copy', '-movflags', '+faststart', str(dest)], check=True)
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries',
    'stream=codec_type,width,height,r_frame_rate:format=duration', '-of', 'json', str(dest)]))
meta = {'url': f'https://www.bilibili.com/video/{bv}/', 'requestedQuality': 127,
    'advertisedQualities': data['accept_quality'], 'selectedQuality': video['id'],
    'width': video['width'], 'height': video['height'], 'probe': probe,
    'bytes': dest.stat().st_size, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
    'note': 'Public playback tracks capped below advertised 1080p. Original pixels; no upscale.'}
(out / (bv + '-download.json')).write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n')
for part in parts: part.unlink()
print('READY', bv, video['width'], video['height'], flush=True)
