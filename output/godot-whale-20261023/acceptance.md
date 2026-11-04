# 化鲸批次验收

2026-10-23接入Godot化鲸基础/觉醒、8张主体牌与真实3/3母亲的守护；8张主体牌使用原版完整PNG。保持卡池、角色入口、已有工作区改动及严格全库审计。

实际接入：单位充能与每回合出击充能；唯一齿甲投射及体甲治疗溢出；水袭任一式神选靶、法术伤害与本回合迅捷；真实爆能选择、支付、对局次数和生成手牌；泣海空前线守护；遥候战技；守护消失赋予障壁；觉醒永久灵咒二选一及额外触发；孤鲸历史爆能身材和帷幕；虚妄之忆随机给不同友方复制两种灵咒及本回合迅捷/昂扬。规则、UI、AI、条件正反例与实际交互同时接入。

| 检查 | 本次结果与证据 |
| --- | --- |
| 原牌面/官网快照 | 9个定义逐字段匹配本地原始快照，采用27800–27808完整PNG的版本与数值。见[资料证据](official-source-evidence.json)。 |
| 纯规则 | 140项、0失败，覆盖携带者/觉醒/气绝、资源与次数、法术伤害、随机复制、日和坊免付、满手烧牌及跨角色爆能。见[rules.log](rules.log)。 |
| 原生交互 | 162项、0失败（含140项规则）；Godot 4.8.dev5，1280×800与1600×740，真实鼠标完成爆能3、选靶、生成手牌、觉醒二选一、守护显示、爆能10复制及水袭双边目标。见[native.log](native.log)。 |
| 相关回归 | 17组通过：日和坊/烟烟罗、移动系及其延续/选择UI、蝴蝶精、迦楼罗、一条、络新妇、入殓师、资源、战斗、瞬发、入内雀、状态、彼岸花、管狐/白藏主、追月神/辉夜姬。见[结果](regressions/results.json)。 |
| 本地Web | Godot 4.6.3导入/导出通过，约157.9 MiB；701项GD/原图/JSON哈希与构建副本一致，4个入口文件齐全。见[构建日志](build.log)及[校验](build-validation.json)。 |
| 源码检查 | `git diff --check`和本批23个文本文件尾部空白检查通过。见[最终验证](final-validation.json)。 |
| 原图 | 8张主体PNG逐字节匹配本地原图；累计54位角色432主体、3草人派生，共435张。见[原图清单](card-art-manifest.json)。 |
| 严格全库审计 | 退出1、`fullCatalogRestored=false`；19项既有诊断逐项不变。见[审计日志](audit.log)、[比较](audit-comparison.json)。 |

目检发现共用爆能选项顶部状态条继承了手牌“普通使用”，已修正为对应选项的真实档位，并在最终原生验证中重新检查。两个旧UI回归不支持`--rules-only`，第一次把参数当截图目录而报无渲染截图错误；改为无该参数运行后全部通过，没有修改或放宽旧断言。

已目检8张原生截图：

- [1280爆能3](1280-01-burst-choice.png)、[1600爆能3](1600-01-burst-choice.png)。
- [1280永久灵咒选择](1280-02-awakening-choice.png)、[1600永久灵咒选择](1600-02-awakening-choice.png)。
- [1280真实守护](1280-03-guardian.png)、[1600真实守护](1600-03-guardian.png)。
- [1280爆能5/10](1280-04-memory-burst.png)、[1600爆能5/10](1600-04-memory-burst.png)。

全库卡牌已知近似608→601、未核对689→688、待核验622→630、有来源原生207不变；单位已知近似104→103、待核验84→85、未核对47及有来源15不变。本批实现通过不能等同于原客户端全部效果已核验。

复查命令：

```sh
.build/tools/godot-4.6.3.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_whale.gd -- --rules-only
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_whale.gd -- "$PWD/output/godot-whale-20261023"
python3 output/godot-whale-20261023/build_export.py
npm run audit:rules -- --out output/godot-whale-20261023/rule-fidelity-report.json
```

仍待核验：齿甲/体甲/守护的中文客户端派生词条和完整原图，永久结附在显式移除/替身中的边界，孤鲸已进场后的后续爆能增长，爆能X为0，以及多幻境、出击和其他响应的完整全序。当前孤鲸按使用时对局历史安装身材；望月显式移除两种灵咒，气绝与替身保留永久结附；泣海按现有共用支付阶段记录爆能，再部署新幻境，不回溯触发同一事件。上述选择保留待核记录，不冒充逐项实机结论。守护中文完整原图仍缺，保留已有占位绘制、实际名称、3/3及规则说明。指定录像未逐牌覆盖本角色，全部新增定义保留`verificationPending`。旧HTML/JS专属结算器未在本批接入。

规则与来源详见[研究72](../../research-notes/72-whale-rules.md)。改动见[continuation.diff](continuation.diff)与[文件清单](changed-files.json)，修改前版本保存在`before/`。本地Web产物位于`.build/pages/play/`；未提交、推送或发布。
