# Godot 慧明灯批次验收（2026-11-07）

本批在 Godot 接入慧明灯基础/觉醒与 8 张主体牌（净秽、嗔念、佛智、觉醒·慧明灯、正念、业回、业障、明识灯），复用已核对的战力/坚守共用层；8 张主体卡图与本地完整原 PNG 字节一致。规则来源与待核验边界见[研究105](../../research-notes/105-wisdom-lamp-rules.md)。

## 实际修复范围

- 上回合真实战伤来源 ledger（序列化、只认战斗伤害/式神来源、护甲全吸不算）、净秽真实消灭与疾速支付、嗔念激怒+坚守、佛智进场前增强判定与战斗结束双治疗、觉醒坚守替换移动、正念回合结束按实际战力投射并等量治疗（屏障挡伤仍治疗）、业回复活+独立坚守、业障坚守出击加成、明识灯真实耐久与护甲截断/免疫消灭。
- 目标选择、状态徽记、AI 合法使用与原生鼠标交互同步；全组保留 `verificationPending`（指定录像缺失）。
- 顺带修复 roster 暴露的三处 HEAD 基线缺陷：八岐大蛇蛇魔复制容器键兜底误写 int、百目鬼 AI 评分 int(null)、roster 初始化断言未计千姬首回合贝戟召唤。详见研究105。

## 验证结果（Godot 4.6.3 实跑）

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 慧明灯规则+双尺寸原生 | 132 检查 / 0 失败（含 20 项鼠标交互） | [ui.log](ui.log)、[截图](ui/) |
| 相关旧回归 24 组 | 全部通过 | [regressions/results.json](regressions/results.json) |
| roster 全库回归 | 5304 检查 / 0 失败，63 场完赛，250 式神覆盖 | [regressions/roster.log](regressions/roster.log) |
| 主体卡图 | 8/8 与原 PNG SHA256 一致 | [art-manifest.json](art-manifest.json) |
| 旧验证完整性 | 186 个哈希一致；verify_roster 一处有据修正 | [old-verify-integrity.json](old-verify-integrity.json) |
| 本地 Web 构建 | 233.1 MiB，1199 个源哈希与构建副本一致 | [build.log](build.log)、[build-source-hashes.json](build-source-hashes.json) |
| 导出 PCK 直接加载 | 33 检查 / 0 失败 | [package.log](package.log)、[package-probe/check.gd](package-probe/check.gd) |
| 全库审计 | 近似 331→326、未核对 561→558、待核验 1040→1048，21 条诊断不变，继续失败 | [audit-after.json](audit-after.json) |

双尺寸截图已目检：净化合法来源选靶、坚守免费出击选友方、复活气绝目标、明识灯伤害上限徽记均正常。

## 未完成范围

全库仍有 326 张已知近似、558 张未核对、1048 张待核验；本批 8 张主体全部保留实机待核验（复杂转移/贯通/同时回合触发全序、多个坚守出击加成累积）。旧 HTML/JS 执行器未同步。`audit:rules` 应继续失败；本批通过不代表全库还原。