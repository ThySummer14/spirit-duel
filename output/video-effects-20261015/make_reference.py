from pathlib import Path
from html import escape
import json
out=Path(__file__).resolve().parent
sources=json.loads((out/'sources.json').read_text())
items=[
 ('瞬发、迅捷、昂扬的区分','huang-swift-vigor','BV1mVGFzoEBm',345,379,'2025 正式对局 · 含2×回放','作者在06:13附近明确说到迅捷、昂扬；镜头包含连续使用卡牌、资源变化及再出击。两种式神状态应分别记录获得、保留和消耗；不能把瞬发、迅捷与昂扬合成一个免费标记。','细小状态纹样与精确颜色受360p限制，暂不据此定稿。'),
 ('结附：随目标保留的鸮形标记','xun-attachment','BV1ZjGg6sELz',17,41,'2026 正式对局 · 含1.5×回放','结合00:00、00:10及00:25的原帧，可观察山风卡下沿浅色鸮形标记随式神位置变化保留。结附应表现为属于该目标的持续状态，获得时再叠加一次演出。','触发后移除的完整同一目标链尚未闭合；不把蓝色光球一概视为灵咒。'),
 ('御馔津：符咒、出击与命中','arrow-combat','BV1r54y1C7d6',104,144,'2020 测试服预览 · 只参考表现','可观察卡牌先展示，再出现围绕角色的金色符印和射向具体目标的箭，随后目标受击并出现气绝。角色轮廓、飞行轨迹和命中节点各有职责。','测试服牌文存在后续改版，不能由这段视频覆盖当前规则。'),
 ('专属演出：羽毛与角色构图','feather-entrance','BV1vg4y1q7m1',20,32,'2020 异画演出合集','角色、羽毛和镜头构图构成专属演出，不能仅用统一光球替代。','这是异画展示，不代表每次普通出牌都应插入全屏动画。'),
 ('专属演出：书翁的纸墨母题','ink-entrance','BV1vg4y1q7m1',128,145,'2020 异画演出合集','纸张、笔墨、飞散碎片与人物动作统一形成角色识别。角色主题应由实际卡牌定义驱动，数值结算另读真实事件。','参考主体、方向与层次，不推定这段展示中的原版出牌时长。'),
 ('大型效果：星空旋涡与场上可读性','cosmic-effect','BV1mVGFzoEBm',756,780,'2025 正式对局 · 含2×回放','12:45原帧可见带方片和环形轨迹的星空旋涡，随即回到战场继续结算。大型效果与持续战场状态需分开。','此段具体关联卡名仍需高清画面确认；不能因视频标题含荒就直接认定为月坠。')]
by={s['bvid']:s for s in sources}
def ts(n):return f'{n//60:02d}:{n%60:02d}'
cards=[]
for title,name,bv,start,end,kind,seen,pending in items:
 src=by[bv]
 cards.append(f'''<article><div class="kicker">{escape(kind)} · {ts(start)}–{ts(end)}</div><h2>{escape(title)}</h2><video controls preload="metadata" src="clips/{name}.mp4"></video><p>{escape(seen)}</p><p class="pending">待核对：{escape(pending)}</p><a href="{escape(src['url'])}?t={start}" target="_blank" rel="noreferrer">原视频 · {escape(src['owner']['name'])} ↗</a></article>''')
rows=''.join(f'<tr><td><a href="{escape(s["url"])}" target="_blank" rel="noreferrer">{escape(s["title"])}</a></td><td>{escape(s["owner"]["name"])}</td><td>{s["publishedDate"]}</td><td><a href="{s["localPath"]}">本地MP4</a></td></tr>' for s in sources)
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>百闻牌 · 演出参照</title><link rel="icon" href="data:,"><style>
*{box-sizing:border-box}body{margin:0;background:#f3efe7;color:#28241e;font:16px/1.7 system-ui,-apple-system,sans-serif}main{max-width:1320px;margin:auto;padding:48px 32px}h1{font-family:serif;font-size:42px;margin:0 0 10px}h2{font-size:21px;line-height:1.4;margin:6px 0 18px}a{color:#785633;text-underline-offset:4px}p{margin:14px 0}.lead{max-width:900px;color:#625b4f}.grid{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-top:34px}article{background:#faf8f3;border:1px solid #d9d0c1;padding:24px}video{width:100%;aspect-ratio:16/9;background:#17181b}.kicker{font-size:12px;letter-spacing:.04em;color:#776d5f}.pending{font-size:14px;color:#776e61;border-top:1px solid #e5ddd0;padding-top:12px}table{border-collapse:collapse;width:100%;font-size:14px}td,th{text-align:left;padding:12px 10px;border-bottom:1px solid #d8cfc1}th{font-size:12px;font-weight:600;color:#6d6254}.source{margin-top:48px}footer{font-size:13px;color:#776d5f;margin-top:30px}@media(max-width:760px){main{padding:28px 16px}h1{font-size:32px}.grid{grid-template-columns:1fr}article{padding:18px}table{display:block;overflow:auto;white-space:nowrap}}
</style><main><div class="kicker">原版表现研究 · 2026.10.15—10.16</div><h1>百闻牌 · 演出参照</h1><p class="lead">已下载5段公开视频，抽取6个可回看区间。主参照仍为用户指定录像；本页补充瞬发、结附、昂扬及角色专属演出。下列说明区分直接观察、设计取向和未确认细节。</p><p class="lead">公开匿名流为360p。部分实机视频标有1.5×或2×回放，片段时长不能直接当作原版动画时长。未对整片逐帧验收。</p><section class="grid">'''+''.join(cards)+'''</section><section class="source"><h2>已下载的来源</h2><table><thead><tr><th>视频</th><th>作者</th><th>发布日期</th><th>文件</th></tr></thead><tbody>'''+rows+'''</tbody></table></section><footer>4秒《百闻牌薰》仅展示卡表，已归档，未把它作为结附动态效果的证据。原始文件及SHA256见 sources.json；片段定位见 clip-times.json。视频中的卡牌数值不自动覆盖当前规则核对数据。</footer></main></html>'''
(out/'index.html').write_text(html)
print('REFERENCE_INDEX_READY',len(items),'clips',len(sources),'sources')
