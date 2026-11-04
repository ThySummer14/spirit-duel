# 判官／海坊主旧规则替换验收

日期：2026-10-09。范围：Godot 两位式神、16 张主体牌、共享消灭与治疗来源、目标选择、自动响应、AI 和状态显示。没有修改旧 JS 引擎或缩减卡池。详细来源及 5 张牌的待核对边界见[规则记录](../../research-notes/24-judge-tide-rules.md)。

## 可运行结果

本地预览：[打开游戏](http://localhost:4182/play/)。本轮独立 Web 输出位于 `.build/judge-tide-20261009/pages`，Godot 4.6.3 stable 构建，89.2 MiB。已在 Codex 浏览器实际打开主城，启动时浏览器控制台未返回 error/warn。没有对外发布。预览服务存活期间可直接访问；重启命令：

```sh
python3 scripts/dev-server.py 4182 .build/judge-tide-20261009/pages
```

最终导出前重新同步了最后的自身伤害来源修正。`manifest.json` 确认构建副本所有 `.gd` 及 `verified_rules.json` 与当前源码一致，并记录了本轮相对于 `before.zip` 的改动和 SHA-256。已有未提交工作保留，没有 commit、push 或部署。

## 验证结果

| 检查 | 本次结果 | 证据 |
| --- | --- | --- |
| 原始失败反例 | 9 项，旧逻辑 5 项失败；实现后全部通过 | `before-reproducer.log`、`rules-first.log` |
| 最终判官／海坊主规则 | 147 项，0 失败，含 12 场专项 AI 对局 | `final-source-regressions.log` |
| 真实鼠标 UI | 1280×800、1600×740 共 50 项，0 失败 | `ui-native.log`、8 张 `screenshots/*.png` |
| 全量 Godot | 53 个 verify 入口通过；63 场全角色、60 场 burst、20 场 focus 全部结束，无卡死；启动检查通过 | `full-verify.log`，末尾 `GODOT_VERIFY_ALL_OK` |
| 最后一处自身伤害来源回归 | 新增两个反例先失败；修复后规则147、自伤39、酒吞97、经典共享30、战斗16、一目连128 全通过 | `self-source-before.log`、`final-source-regressions.log` |
| Godot 4.6.3 | 最终规则147及 UI 50 通过 | `stable-rules-final.log`、`stable-ui.log` |
| Node 测试及 UI audit | 164 测试、385 检查，0 失败／错误 | `node-test.log`、`ui-audit.log` |
| Web 构建 | import、export 成功；末次修正后重新导出成功 | `web-build.log`、`web-final-export.log` |
| diff 格式 | `git diff --check` 通过 | 本轮命令结果 |
| 全库还原审计 | **按要求失败，退出码1**，`errors: []` | `rules-audit.log` |

全量脚本运行时规则专项为145项；之后发现并修正旧 `damage-self` 将自身伤害归给敌方的问题，增加两项反例，并重跑表列相关回归及 stable 规则测试。没有把不同源码时点的测试混称为末次源码全量重跑。155 场不同种子的本轮对局是 143 场全量加 12 场专项；重复回归未叠加计数。

## 还原审计与限制

| 分类 | 式神 | 卡牌 |
| --- | ---: | ---: |
| 已知近似 | 154 | 1057 |
| 未核对 | 81 | 929 |
| 待进一步验证 | 5 | 28 |
| 有来源的原生实现 | 10 | 100 |

本轮 5 张待核对牌是断罪、灵能、蹈海、巨浪、沧海之盾，具体是已用形态增强、满血治疗回响、气绝反击治疗、过杀汇总及授予能力归属。对应行为已经实现并有执行测试，仍需原版实机证据确认；不会靠删除待核对标记将其算作全部还原。法术必杀及复活／替身组合也不在本轮核对范围。

## 原生截图

消灭进度与墨笔分别来自真实出牌，海坊主觉醒后的过量治疗转换及沧海之盾显示实际状态。已检查两个分辨率下详情文本、数值和标记，没有本轮新内容遮挡或截断。

![判官消灭进度](screenshots/1280-01-judge-progress.png)

![海坊主过量治疗与实际力量护甲](screenshots/1600-03-overheal.png)

![沧海之盾本回合状态](screenshots/1600-04-combat-heal.png)
