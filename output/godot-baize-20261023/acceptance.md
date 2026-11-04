# 白泽批次验收

2026-10-23接入Godot白泽基础/觉醒、8张主体牌和达知派生。实际实现回合开始/出击置入达知、完整占卜顶底安排、至少置底一张、原实例回手、底部随机复活/伤害/自动施法、力量投射战技、觉醒每次占卜至多抽一张、占卜8按实际置底治疗，以及形态本回合增益。目标选择、AI、规则栈和原生UI一起接入，保留角色入口和完整卡池。

| 检查 | 本次结果与证据 |
| --- | --- |
| 完整原牌面/官网快照 | 27300–27308共9个定义逐字段匹配，采用已有完整PNG基础版本；见[资料证据](official-source-evidence.json)。 |
| 纯规则 | 197项、0失败。覆盖实际出击/命令攻击区别、插入保序、瞬发费用、强制置底、气绝复活、实例/灵咒保留、自动使用与阻止条件、实际伤害后眩晕、觉醒时序/单次抽牌、八张占卜、临时增益生命周期及AI；见[rules.log](rules.log)。 |
| 原生交互 | 233项、0失败（含197项规则），Godot 4.8.dev5；1280×800及1600×740真实鼠标验证强制置底、气绝复活选靶、八张原牌面横向滚动及续结；见[native.log](native.log)。 |
| 相关回归 | 14组通过：百目鬼/蟹姬、山风/泷夜叉姬/般若、铁鼠/河童、缘结神/食梦貘、书翁/觉、追月神/辉夜姬、化鲸、影鳄、蝴蝶精、抽牌、回合顺序、资源、战斗、瞬发；见[结果](regressions/results.json)。 |
| 派生合同 | 原始与有效达知定义均为白泽瞬发法术、印刷费用1、不可编入卡组、无初始副本；见[token-contract.log](token-contract.log)。 |
| 本地Web | Godot 4.6.3导入/导出通过，160.7 MiB；721项GD/原图/JSON与构建副本哈希一致，4个入口文件齐全；见[构建](build.log)、[导入](import.log)、[导出](export.log)、[校验](build-validation.json)。静态JS的INSTANT枚举同步另外见[记录](static-sync.json)。 |
| 源码检查 | `git diff --check`、本批19个文本文件尾部空白检查通过；见[最终验证](final-validation.json)。 |
| 原图 | 新增8张逐字节匹配本地原PNG，累计56位角色448主体及3草人派生，共451张；见[清单](card-art-manifest.json)。 |
| 严格全库审计 | 退出1、`fullCatalogRestored=false`；19项既有诊断逐项相同；见[审计](audit.log)、[比较](audit-comparison.json)。 |

6张截图已逐张目检：

- [1280强制置底](1280-01-required-bottom.png)、[1600强制置底](1600-01-required-bottom.png)。
- [1280气绝复活目标](1280-02-ko-revive-target.png)、[1600气绝复活目标](1600-02-ko-revive-target.png)。
- [1280八张占卜滚动末端](1280-03-eight-card-scroll.png)、[1600八张占卜滚动末端](1600-03-eight-card-scroll.png)。

卡牌已知近似597→594、未核对684→679、待核验638→647、有来源207不变；单位近似103→102、未核对46不变、待核验86→87、有来源15不变。本批新增9张卡和基础角色均保留`verificationPending`，没有把程序检查通过当成全库原版还原完成。

当前采用的实现判断仍需原客户端逐项确认：观史通今把检索牌作为额外展示一张，以及已经位于牌顶时的计数；承因续果同名牌逐张叠加、气绝目标、敌方牌库展示；驱邪祸自动施放在气绝/眩晕时的合法性；SSR治疗与多个置底能力、觉醒抽牌、恶戏/鬼眸、自动响应的全序。达知派生中文完整原图仍缺失。指定录像未逐牌覆盖本角色，本批不宣称这些边界已在原客户端确认。

复查命令：

```sh
.build/tools/godot-4.6.3.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_baize.gd -- --rules-only
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_baize.gd -- "$PWD/output/godot-baize-20261023"
python3 output/godot-baize-20261023/regressions.py
python3 output/godot-baize-20261023/build_export.py
npm run audit:rules -- --out output/godot-baize-20261023/rule-fidelity-report.json
python3 output/godot-baize-20261023/finalize.py
```

初次导入的局部类型推断错误已修复，[初次日志](initial-import.log)保留；最终导入、导出、专项和相关回归均无脚本错误。旧回归脚本使用`failures=0`而非`_OK`，汇总器已兼容其成功格式，[初次汇总](initial-regressions.log)保留，原有断言未变。原生检查采用独立临时存储，不改玩家存档。变更见[continuation.diff](continuation.diff)、[文件清单](changed-files.json)，修改前版本保存在`before/`。细节见[研究74](../../research-notes/74-baize-rules.md)。本地Web产物位于`.build/pages/play/`；未提交、推送或发布。
