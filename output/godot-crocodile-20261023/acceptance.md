# 影鳄批次验收

2026-10-23接入Godot影鳄基础/觉醒与8张主体牌。实际实现升级结附鬼鳄、主动出击成长、永久灵咒效果与迁移、贯通及攻击时先攻、幻境迅捷、觉醒气绝生效与匿息气绝用牌、伏猎命令友方真实免战伤攻击、诡影重重动态瞬发与出击结附。8张主体牌均使用原版完整PNG。保持角色入口、卡池及严格全库审计，保留工作区既有改动。

| 检查 | 本次结果与证据 |
| --- | --- |
| 原牌面/官网快照 | 27900–27908共9个定义与原始快照逐字段匹配，采用已有完整PNG的版本。见[资料证据](official-source-evidence.json)。 |
| 纯规则 | 104项、0失败。覆盖开局/真实升级、重复成长、迁移、条件正反例、进攻与防守先攻区别、觉醒气绝、命令攻击、净化/望月/替身及AI。见[rules.log](rules.log)。 |
| 原生交互 | 120项、0失败（含104项规则）；Godot 4.8.dev5，1280×800与1600×740，真实鼠标完成幻境进场选友方、觉醒、追猎准备区、气绝匿息与伏猎命令友方。见[native.log](native.log)。 |
| 相关回归 | 14组通过：化鲸、蝴蝶精、迦楼罗、一条、络新妇、藤姬、入内雀、管狐/白藏主、追月神/辉夜姬、护甲吸血、战斗、资源、状态、升级赐福。见[结果](regressions/results.json)。 |
| 本地Web | Godot 4.6.3导入/导出通过，约159.2 MiB；711项GD/原图/JSON与构建副本哈希一致，4个入口文件齐全。见[构建日志](build.log)、[导入](import.log)、[导出](export.log)、[校验](build-validation.json)。 |
| 源码检查 | `git diff --check`及本批20个文本文件尾部空白检查通过。见[最终验证](final-validation.json)。 |
| 原图 | 新增8张逐字节匹配本地原PNG；累计55位角色440主体及3草人派生，共443张。见[清单](card-art-manifest.json)。 |
| 严格全库审计 | 退出1、`fullCatalogRestored=false`；19项既有诊断逐项相同。见[审计日志](audit.log)、[比较](audit-comparison.json)。 |

6张截图已目检：

- [1280幻境进场选靶](1280-01-realm-entry-target.png)、[1600幻境进场选靶](1600-01-realm-entry-target.png)。
- [1280追猎准备区](1280-02-pursuit-target.png)、[1600追猎准备区](1600-02-pursuit-target.png)。
- [1280气绝匿息](1280-03-knocked-nixi-target.png)、[1600气绝匿息](1600-03-knocked-nixi-target.png)。

全库卡牌已知近似601→597、未核对688→684、待核验630→638、有来源207不变；单位未核对47→46、待核验85→86、近似103及有来源15不变。普通程序验证通过不能等同全库原版已还原。

复查命令：

```sh
.build/tools/godot-4.6.3.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_crocodile.gd -- --rules-only
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_crocodile.gd -- "$PWD/output/godot-crocodile-20261023"
python3 output/godot-crocodile-20261023/build_export.py
npm run audit:rules -- --out output/godot-crocodile-20261023/rule-fidelity-report.json
python3 output/godot-crocodile-20261023/finalize.py
```

仍待核验：旧版鬼鳄中文客户端完整派生词条和原图、唯一范围、永久增强在灵咒移除/重附后的具体承载模型、首次升级恰逢气绝、形态与觉醒同次出击全序，以及跨角色复制/变形/迁移的全部组合。当前采用每方唯一、永久增强由对局记录保留、灵咒移除时解除携带者增益的模型；这是依据原牌文和补充资料作出的实现判断，不能声称所有边界已在中文实机确认。

本批没有把日文新版的鬼鳄离场返匿息、基础能力每回合一次、匿息天然气绝可用、伏猎+1/+1或幻境扣耐久混入现有PNG。指定录像未逐牌覆盖本角色，所有新增定义保留`verificationPending`。鬼鳄是灵咒状态，不伪造独立可用手牌。旧HTML/JS专属结算器未在本批接入。

初次导入的`trait`保留字冲突已改为`has_trait`；保留[初次日志](initial-import.log)，最终专项、相关回归及导入/导出均无脚本错误，未放宽断言。改动见[continuation.diff](continuation.diff)、[文件清单](changed-files.json)，修改前版本保存在`before/`。细节见[研究73](../../research-notes/73-crocodile-rules.md)。本地Web产物位于`.build/pages/play/`；未提交、推送或发布。
