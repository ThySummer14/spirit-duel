# 瞬发与特殊状态验收 · 2026-10-08

接续「继续还原百闻牌对战体验」聊天及工作区已有成果。本轮只修改共享瞬发支付和 Godot 状态表现，没有扩展已核验卡池，没有提交、推送或发布。之前妖刀姬、酒吞、兵俑等未提交成果保留。

## 实际完成

- 统一费用查询、合法性检查、支付和显示。修复零费响应误耗瞬发额度；保留零费牌获得瞬发后，在合法主动时机仍消耗额度的顺序约束。覆盖全队共享、换回合重置、AI 零火使用、桃花存活条件、妖刀赋予与萤草形态光环。
- 手牌显示有效费用和瞬发可用/已用/待机，自然零费单独标识。详情解释当前费用，出牌演出读取实际支付快照，起源选择也读取同一查询。选择目标与取消不消耗资源。
- 战场徽记与详情共用真实状态投影。区分紫色气绝沙漏和红色能力沙漏；支持眩晕、屏障、迅捷、不屈、狂啸、充能、破甲、晶裂、临时瞬发/免火、尘缚、闪烁、自毁、预约护甲、觉醒护甲保留及觉醒等已有状态。两列徽记超限后显示 `+N`，详情保留完整列表。
- 气绝、状态消耗、离开战斗区及回合过期后即时更新；已经打开的详情也会刷新。没有用显示标志代替实际能力结算。

[规则和录像依据](../../research-notes/21-instant-status-indicators.md)记录了本轮可确认的范围。特别是录像中的金色翼状结附仍未充分确认，未将它误套为不屈或屏障；其他本地图形也不宣称等同全部官方图标。

## 验证结果

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 新增规则专项 | 139 项通过；费用无副作用、条件正反例、AI、状态生命周期、几何及 JSON 往返 | [全量日志](full-verify-final.log) |
| 旧支付判定反例 | 使用修复前的 `instant && cost == 0` 判定时，两种零费响应均失败；退出码 1 | [反例日志](pre-fix-reproducer.log) |
| 专项 headless / 原生 UI | 双尺寸各 88 项通过；真实鼠标选牌、选靶、取消、悬停刷新 | [headless](ui-headless.log)、[原生最终](ui-native-final.log) |
| Godot 全量 | `GODOT_VERIFY_ALL_OK`；含规则、保存、演出、布局、美术、所有角色及启动 | [最终全量](full-verify-final.log) |
| 对局 | 63 场全角色覆盖、60 场种子对局、20 场重点机制对局；后两组无卡死 | [最终全量](full-verify-final.log) |
| Godot 4.6.3 | 新规则 139、UI 88 项通过 | [规则](stable-rules.log)、[UI](stable-ui.log) |
| Web 本地构建 | 89.2 MiB；最终重新导出成功，无脚本错误 | [构建](web-build.log)、[最终导出](web-export-final.log) |
| JavaScript 既有测试 | 164 项通过 | [测试](node-tests.log) |
| 普通审计 | 385 项，0 错误 | [审计](catalog-audit.log) |
| 全库还原审计 | **仍失败，退出码 1**；结构错误 0，`fullCatalogRestored: false` | [日志](rule-fidelity.log)、[完整报告](rule-fidelity.json) |

第一次全量在妖琴连续觉醒点击中出现失败，测试现在与已有酒吞测试一致：悬停重排后重新读取控件位置，保留全部规则断言。[首次日志](full-verify-first.log)、[单项复测](yaoqin-final.log)。第二次全量中大天狗响应结束检查出现一次时序失败，当时还有其他验证进程运行；单项诊断及最终全量通过，没有修改该测试的断言或等待时间。[第二次日志](full-verify.log)、[诊断](clock-diagnostic.log)。该偶发时序现象的根因仍未被独立稳定复现，不记为已修复的规则问题。

最终原生截图经过目视复查；采集前等待待释放的详情节点完成移除，避免把过渡帧残影作为最终状态。

| 场景 | 1280×800 | 1600×740 |
| --- | --- | --- |
| 瞬发可用和独立零费 | [截图](native-shots/1280-01-instant-ready.png) | [截图](native-shots/1600-01-instant-ready.png) |
| 额度已用与费用详情 | [截图](native-shots/1280-02-instant-used.png) | [截图](native-shots/1600-02-instant-used.png) |
| 多状态与完整详情 | [截图](native-shots/1280-03-all-statuses.png) | [截图](native-shots/1600-03-all-statuses.png) |
| 气绝与能力倒计时 | [截图](native-shots/1280-04-knockout-countdown.png) | [截图](native-shots/1600-04-knockout-countdown.png) |

最终源文件和 Web 产物哈希见 [manifest](final-artifacts.json)。本地 Web 成品位于 `.build/instant-status-20261008/pages/play/`；线上页面未更新，也未新增依赖。

## 未完成范围

本轮没有实现全库所有专属状态、薰的完整结附体系或所有官方图标；原有机制的 `verificationPending` 继续保留。全库卡牌为已知近似 1064、未核对 954、待核验 20、已有来源与原生实现 76，本轮没有改变这些数量。旧 HTML/JS 规则未同步。全量程序测试证明当前实现的稳定性，不能代替未知机制的原版实机核验。
