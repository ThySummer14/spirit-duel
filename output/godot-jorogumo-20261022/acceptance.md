# 络新妇批次验收

2026-10-22开始，2026-10-23完成本批实现与验证。本批接入Godot络新妇基础/觉醒、8张主体牌和真实3/4蛛群；保持卡池、角色入口、已有工作区修改及严格全库审计。8张主体牌均按原版完整PNG显示。

实际接入：持续且唯一的蜘蛛印记；敌方回合最后攻击者记录；毒针战技；条件免战伤/吸血与追猎；独立蛛群召唤、交战、造成伤害结附及离场移除；觉醒重复印记替代伤害；幻境进场群伤、气绝加耐久/伤害；手牌与主动出击的额外鬼火；诛灭条件消灭/抽牌。选择UI、状态检视、AI与条件正反例同时验证。未把这些机制替换成破甲、固定属性或自疗。

| 检查 | 本次结果与证据 |
| --- | --- |
| 原牌面/官网快照 | 9个定义逐字段匹配，采用完整PNG数值与版本。见[资料证据](official-source-evidence.json)。 |
| 纯规则 | 126项，0失败，包含法术伤害加成、暴击/护甲顺序、条件正反例、群伤气绝、同刻宿主气绝、真实费用和AI命令蛛群。见[rules.log](rules.log)。 |
| 原生交互 | 140项，0失败（包含126项规则）；Godot 4.8.dev5，1280×800及1600×740，实际鼠标操作选靶、错误目标、Escape取消、形态进场印记、蛛群显示、诛灭和罗网目标。见[native.log](native.log)。 |
| 相关回归 | 16组全部通过：一条、蝴蝶精、迦楼罗、通用战斗/状态/瞬发/资源、管狐/白藏主、追月神/辉夜姬、护甲吸血、兵俑、入内雀、入殓师、丑时之女、凤凰火、独眼小僧/垢尝。见[结果](regressions/results.json)。 |
| 本地Web | Godot 4.6.3导入/导出通过，约156.6 MiB；691项规则/原图/JSON哈希与构建副本一致，4个入口文件齐全。见[构建日志](build.log)、[校验结果](build-validation.json)。 |
| 源码检查 | `git diff --check`及本批新增行尾部空白检查通过。见[最终验证](final-validation.json)。 |
| 原图 | 新增8张逐字节匹配本地原版PNG；累计53位424张主体及3张草人派生，共427张。见[清单](card-art-manifest.json)。 |
| 严格还原审计 | 退出1，`fullCatalogRestored=false`；19项既有诊断逐项相同。见[审计日志](audit.log)、[比较](audit-comparison.json)。 |

已目检6张原生截图：

- [1280形态进场选靶](1280-01-queen-entry-target.png)、[1600形态进场选靶](1600-01-queen-entry-target.png)。
- [1280实际蛛群](1280-02-actual-swarm.png)、[1600实际蛛群](1600-02-actual-swarm.png)。
- [1280罗网印记](1280-03-web-mark.png)、[1600罗网印记](1600-03-web-mark.png)。

全库卡牌已知近似613→608、未核对692→689、待核验614→622，有来源原生207不变；单位未核对48→47、待核验83→84，近似104及有来源15不变。实现通过不能等同于全部原客户端效果已核验。

复查命令：

```sh
.build/tools/godot-4.6.3.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_jorogumo.gd -- --rules-only
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_jorogumo.gd -- "$PWD/output/godot-jorogumo-20261022"
python3 output/godot-jorogumo-20261022/build_export.py
npm run audit:rules -- --out output/godot-jorogumo-20261022/rule-fidelity-report.json
```

残余边界：蜘蛛印记/蛛群中文原客户端词条及原图，自动用牌/战技替换是否另收额外鬼火，以及多种伤害转移、前线触发和气绝响应的全序。本批已接入真实手牌（含响应）和主动出击的额外费用，未宣称其他自动用牌的全部费用边界已完成。蛛群原图检索未取得可用本地素材，外部图片下载超时，当前保留已有占位绘制及明确的名称、3/4和规则说明。指定录像未逐牌覆盖本角色，全部新增定义保留`verificationPending`；旧HTML/JS专属结算器未在本批接入。

改动见[continuation.diff](continuation.diff)及[文件清单](changed-files.json)，修改前版本保存在`before/`。规则和来源细节见[研究71](../../research-notes/71-jorogumo-rules.md)。本地Web产物在`.build/pages/play/`；未提交、推送或发布。
