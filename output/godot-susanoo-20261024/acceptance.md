# 须佐之男批次验收

2026-10-24接入Godot须佐之男基础/觉醒与8张主体牌，实际实现攻击成长、条件贯通、1生命追猎免战伤、击杀雷冢替换、幻境鼓舞、必杀、条件气绝复活、觉醒生成手牌、雷切不同目标的两段伤害与正常战斗，以及天雷万象的最低生命攻击和双方临时不屈。AI、选靶、动态增强、状态显示及真实鼠标交互一起验证，保留角色入口和完整卡池。

| 检查 | 本次结果与证据 |
| --- | --- |
| 原牌面/官网快照 | 28100–28108共9个定义逐字段匹配，本地主体完整PNG为采用版本；雷冢词条由官方曝光图补足，未混入预览主体差异；见[资料证据](official-source-evidence.json)。 |
| 纯规则 | 107项、0失败，覆盖条件正反例、真实攻击/反击区别、雷冢身份与复归、实际必杀/免疫、增强气绝用牌、两段不同选敌、觉醒贯通、双方不屈期限、倒计时及AI；见[rules.log](rules.log)。 |
| 原生交互 | 121项、0失败（含107项规则）；Godot 4.8.dev5，1280×800和1600×740真实鼠标完成1生命追猎选择、拒绝非法目标、击杀生成0/1雷冢、气绝增强神明之护与SSR自动攻击；见[native.log](native.log)。 |
| 相关回归 | 16组全部通过：战斗、成长、资源、回合顺序、九命猫/荒骷髅、运势/变形、治疗/即时复活、追月神/辉夜姬、化鲸、影鳄、护甲吸血、经典核心、状态、夜间/不见岳/红叶、彼岸花及鬼切；见[结果](regressions/results.json)。 |
| 既有必杀缺陷 | 修改前独立副本复现同一原断言失败；修复后资源2、生命5，不再同次重复击杀即时复活身体。原`verify_light_healer.gd`字节完全相同，593项全部通过；见[前后比较](lethal-regression-comparison.json)、[原版本失败日志](baseline-light-healer.log)、[最终回归](regressions/verify_light_healer.log)。 |
| 本地Web | Godot 4.6.3导入/导出通过，162.1 MiB；731项GD/原图/JSON与构建副本哈希一致，4个入口文件齐全；见[构建](build.log)、[导入](import.log)、[导出](export.log)、[校验](build-validation.json)。 |
| 源码检查 | `git diff --check`及本批15个文本文件尾部空白检查通过；见[最终验证](final-validation.json)。 |
| 原图 | 新增8张逐字节匹配本地原PNG；累计57位角色456主体及3草人派生，共459张；见[清单](card-art-manifest.json)。 |
| 严格全库审计 | 退出1、`fullCatalogRestored=false`；19项既有诊断逐项相同；见[审计](audit.log)、[比较](audit-comparison.json)。 |

6张原生截图均已目检：

- [1280条件追猎选靶](1280-01-one-hp-pursuit.png)、[1600条件追猎选靶](1600-01-one-hp-pursuit.png)。
- [1280真实0/1雷冢](1280-02-real-thunder-tomb.png)、[1600真实0/1雷冢](1600-02-real-thunder-tomb.png)。
- [1280气绝增强复活4/7](1280-03-enhanced-guard.png)、[1600气绝增强复活4/7](1600-03-enhanced-guard.png)。

全库卡牌已知近似594→590、未核对679→675、待核验647→655、有来源207不变；单位近似102→101、未核对46不变、待核验87→88、有来源15不变。全部新增8张卡和基础角色保留`verificationPending`，程序稳定与交互检查通过不等于全库原版还原完成。

仍需原客户端逐项确认：雷冢与死亡、形态离场、即时复活、替身的完整优先级，被再次击杀与幻境重复替换，原式神成长/倒计时恢复边界，召唤物、复制和变形组合；雷切贯通与伤害转移、免疫组合；天雷万象嵌套交战和不屈全序。本批未完成指定录像对这些边界的逐项核验。雷冢中文独立完整卡面仍缺；官方曝光图只用来核对词条，不裁切成“完整原版卡面”冒充素材。

复查命令：

```sh
.build/tools/godot-4.6.3.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_susanoo.gd -- --rules-only
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_susanoo.gd -- "$PWD/output/godot-susanoo-20261024"
python3 output/godot-susanoo-20261024/regressions.py
python3 output/godot-susanoo-20261024/build_export.py
npm run audit:rules -- --out output/godot-susanoo-20261024/rule-fidelity-report.json
python3 output/godot-susanoo-20261024/finalize.py
```

本批修复选靶入口对无`id`通用卡的访问；相关回归发现的既有即时复活/必杀缺陷通过独立修改前副本定位，再修复共享伤害的`bodyKnocked`记录，原断言未修改。最终专项、16组相关回归、导入与导出均无脚本错误。没有反复执行全量卡库测试或对局压测。

原生检查使用独立临时存储，不改玩家存档。修改前文件在`before/`，独立对照工程在`baseline-runtime/`；变更见[continuation.diff](continuation.diff)、[文件清单](changed-files.json)。详细机制与待核验判断见[研究75](../../research-notes/75-susanoo-rules.md)。本地Web产物位于`.build/pages/play/`；未提交、推送或发布。
