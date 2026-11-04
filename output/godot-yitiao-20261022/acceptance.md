# 一条批次验收（2026-10-22）

本批实际修改：Godot一条基础/觉醒、8张主体牌和勤勉修行派生；升级奖励、战技跨气绝累计、卫戍追猎、三种架势、孤斗不屈/贯通、重任自动响应与独立战斗、觉醒气绝战斗牌改为复活。主规则、选择/目标UI、状态展示、AI与条件正反例一起接入，未关闭入口、缩减卡池或放宽全库审计。

134项纯规则检查和160项含原生交互检查均通过；后者包含前者。原生测试使用Godot 4.8.dev5，两个尺寸1280×800与1600×740，真实鼠标点击居合选择、普通出击、气绝用牌、追猎选靶、非法友方目标及Escape取消，并显示实际自动响应的结算结果。6张截图已目检。最初对Canvas绘制的选择文字使用Label文本查询，后按真实CardFace数据和截图验证；气绝牌静态原PNG仍写追猎的问题已修正为效果区域覆盖「复活自己」。最终日志无脚本错误或失败断言。

| 验证 | 本次结果与证据 |
| --- | --- |
| 原牌面与官网数据 | 9个原始定义逐字段一致；觉醒采用PNG的+4力量/+0生命。见[资料证据](official-source-evidence.json)。 |
| 纯规则 | 134项，0失败。见[rules.log](rules.log)。 |
| 原生交互 | 160项，0失败。见[native.log](native.log)。 |
| 相关回归 | 12组全部通过：蝴蝶精、迦楼罗、惠比寿、赐福续结、桃花妖、犬神、兵俑、通用战斗、瞬发、状态展示、彼岸花、妖琴师。见[逐组结果](regressions/results.json)。 |
| 本地Web构建 | Godot 4.6.3导入/导出通过，681项规则/原图/JSON哈希与构建副本一致；四个入口文件齐全，约155.2 MiB。见[构建日志](build.log)、[校验结果](build-validation.json)。 |
| 源码检查 | `node --check game-content-wave6.js`、Python生成脚本AST解析及`git diff --check`通过；本批新增行无尾部空白。见[最终验证](final-validation.json)。 |
| 全库严格审计 | 预期退出1，`fullCatalogRestored=false`。19项既有诊断逐项相同；未增加未知定义。见[审计日志](audit.log)、[前后比较](audit-comparison.json)。 |
| 原图 | 新增8张逐字节匹配本地原图；累计52位416张主体及3张草人派生，共419张。勤勉修行中文完整原图仍缺失。见[清单](card-art-manifest.json)。 |

全库审计：卡牌已知近似617→613、未核对696→692、待核验605→614，有来源原生207不变；单位未核对49→48、待核验82→83，近似104及有来源15不变。待核验增加包含8张主体牌和新派生牌，未把有实现等同于原客户端已经全部验证。

原生截图：

- [1280居合选择](1280-01-iiai-choice.png)、[1600居合选择](1600-01-iiai-choice.png)。
- [1280气绝复活牌](1280-02-awake-KO-revive.png)、[1600气绝复活牌](1600-02-awake-KO-revive.png)。
- [1280重任响应](1280-03-cover-response.png)、[1600重任响应](1600-03-cover-response.png)。

复查入口：

```sh
.build/tools/godot-4.6.3.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_yitiao.gd -- --rules-only
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_yitiao.gd -- "$PWD/output/godot-yitiao-20261022"
python3 output/godot-yitiao-20261022/build_export.py
npm run audit:rules -- --out output/godot-yitiao-20261022/rule-fidelity-report.json
```

未完成边界：勤勉修行的中文原客户端牌文/原图、居合出击关键词的严格持续边界、气绝替代用牌是否计入战技次数、被反制时手牌强化的原版时机，以及多重响应/转移同时发生的全序。补充词条目前来自日文客户端转录；所有新增定义保留`verificationPending`。指定录像未逐牌覆盖一条，旧HTML/JS专属结算器未在本批接入，全库仍有613项明确近似及692张未核对卡牌。本地原生运行和Web构建通过不代表全库效果已经还原。

本批相对继续前的修改见[continuation.diff](continuation.diff)和[文件清单](changed-files.json)；`before/`保存修改前版本，未回退已有工作区修改。本地Web产物在`.build/pages/play/`，未提交、推送或发布。规则与来源细节见[研究70](../../research-notes/70-yitiao-rules.md)。
