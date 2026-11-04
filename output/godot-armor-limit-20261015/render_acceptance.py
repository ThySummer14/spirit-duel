from pathlib import Path
import json

out = Path(__file__).resolve().parent
result = json.loads((out / "validation.json").read_text())
unit = result["fidelitySummary"]["units"]
card = result["fidelitySummary"]["cards"]
text = f"""# 共享护甲上限与送祝福接续验收（2026-10-15）

本轮修复 Godot 的两个已定位缺陷：护甲／破甲缺少原版上限，以及送祝福遗漏后续抽牌。没有新增角色，也没有把整组旧卡或全库标为已还原。相对上一批冻结导出副本的实际差异保存在 `continuation.diff`，其基线文件逐一核对过上一批源码哈希，既有工作区改动保持原样。

## 实际完成

- 式神与牌手的护甲、破甲统一限制65535；即时抵消后只记录实际新增量。临时护甲份额、返回值和破甲获得事件准确记录实际获得，满上限零获得不占用首次获得记录，也不触发对应倒计时观察者。
- 天籁18号结果由直接修改牌手护甲改为共享入口；已有破甲会先抵消。久次良派生力量及海坊主水龙卷预测与实际护甲一致。破甲替换伤害、下一次伤害增量和海坊主觉醒独立力量成长均不错误套用状态上限。
- 送祝福保留己方目标、1／1成长与三次6点后的额外2／2及迅捷，之后从真实牌库顶抽一张。非法目标或取消不支付、不抽；抽空牌库按现有正式抽牌入口败北。手牌说明、目标交互及 AI 使用同一张运行时卡牌。
- 修正五位数被卡面徽记截断的问题。数值字号按现有绘制宽度适配，详情面板保留完整数值；护甲／破甲词条同时解释抵消与上限。

## 本次验证结果

| 检查 | 实际结果 |
| --- | --- |
| 新增规则专项 | 护甲上限72项、送祝福44项，共{sum(result['focusedChecks'].values())}项，失败0 |
| 原生鼠标交互 | {result['nativeUiChecks']}项，失败0；1280×800、1600×740 |
| Godot完整检查 | {result['godotScripts']}个脚本，退出0，`GODOT_VERIFY_ALL_OK`，无脚本错误诊断 |
| 混合AI与全角色 | 随机60局、聚焦20局全部结束，卡死0；63组对局覆盖250角色条目 |
| Node测试 | {result['nodeTests']}项通过，失败0 |
| UI审计 | {result['uiAuditChecks']}项，错误0 |
| Web | Godot 4.6.3稳定版导出通过，两项新增规则专项同样通过，约{result['webBytes']/1024/1024:.1f}MiB |
| 浏览器冒烟 | 主城→对弈→起手换牌→确认起手→战场；控制台错误0、警告0 |

原生交互覆盖未增强／已增强送祝福、敌方误选、取消、从原牌库抽牌、白骨之盾、水龙卷的真实目标及满上限状态检视。8张原生截图在 `screenshots/`；边界测试使用40鬼火和200000生命等注入数据，仅用于隔离结算，不改变正式对局初始资源。已视觉检查1280护甲、1600破甲与浏览器主城、起手及战场截图。

全量检查与 Web 导出使用同一份{result['frozenSourceFiles']}个 GDScript／内容文件：`suite-source-hashes.json` 与 `build-source-hashes.json` 完全相等，运行期间改动列表 `suite-sources-changed.json` 为空。`verify_acceptance.py` 实际核对退出码、87个脚本顺序、错误诊断、专项检查数、原生截图、浏览器日志、Web产物及当前源码哈希，结果 `ARMOR_LIMIT_ACCEPTANCE_OK`；结构化结果在 `validation.json`。

浏览器截图保存在 `../playwright/armor-limit-20261015/`。浏览器仅作启动与进入战场冒烟，未用其证明本轮卡牌效果；具体卡牌交互来自上述原生鼠标验证。Web产物位于 `.build/armor-limit-20261015/pages/play/`，本轮未发布到外部网站。

## 来源及未完成范围

护甲上限来自[2020-09-28官方常规机制公告](https://www.taptap.cn/moment/59609610805317142)。送祝福抽牌来自[2021-06-29完整维护公告转载](https://www.9game.cn/yysbwp/5243125.html)，本轮没有取回官方账号原帖；该牌继续保留 `verificationPending`，原帖、后续普通公告及指定录像直接核验尚未闭合。版本差异与实现边界见[研究39](../../research-notes/39-armor-limit-blessing-followup.md)。

`npm run audit:rules`本次实际退出1，`fullCatalogRestored=false`；没有因普通测试通过而放宽审计。

| 类型 | 已知近似 | 未核对 | 待核对 | 已建立原生资料与实现 |
| --- | ---: | ---: | ---: | ---: |
| 单位条目 | {unit['known-approximation']} | {unit['unreviewed']} | {unit['pending-verification']} | {unit['source-backed-native']} |
| 卡牌 | {card['known-approximation']} | {card['unreviewed']} | {card['pending-verification']} | {card['source-backed-native']} |

仍有{result['remainingUnitEntries']}个单位条目、{result['remainingCards']}张牌未归入原生分类，包括已实现但资料核验不全的项目。19项既有诊断保持不变：番茄／烬染16张历史独立构筑条目缺少受核验执行，其中2张仍含近似；罗生门之鬼随机池／权重仍有缺口。未删除入口或卡池。

上一批白骨能力复制、初拥跨阵营回复归属、部分血蝠复杂防止伤害组合、同名幻境及数量限制仍待原版实机核验。旧 HTML/JS 专属执行器没有同步本轮规则。稳定性、AI对局和可启动的 Web 导出都不代表全库效果已经还原。

## 失败修复与复现

保留首次复现和测试夹具修正日志。护甲专项在原实现上出现35项失败；送祝福在修正夹具后仍有11项真实遗漏失败。初次UI46项通过但视觉检查发现末位截断，修正数值字号后增加完整宽度检查，最终50项通过。没有删除原来的成长／迅捷或全库失败断言。

```sh
bash scripts/godot-verify.sh
npm test
npm run audit
npm run audit:rules -- --out output/godot-armor-limit-20261015/rule-fidelity.json
python3 output/godot-armor-limit-20261015/build_export.py
python3 output/godot-armor-limit-20261015/verify_acceptance.py
```
"""
(out / "acceptance.md").write_text(text)
print("Acceptance written")
