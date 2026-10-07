# 鸩机制修复验收 · 2026-10-07

本轮修改 Godot 原版鸩的基础能力及 `c11601–c11608`，补齐独立倒计时、破甲取得与消耗、双方伤害转换、响应原战斗、条件免伤/吸血、首次获得破甲触发和比例破甲。没有用额外力量或护甲替代这些机制。完整牌文依据、版本差异和实现顺序见[规则研究记录](../../research-notes/13-zhen-armor-break.md)。

## 实际改动

- 增加 `armor_break_rules.gd`：统一式神与牌手破甲、来源归属、伤害转换、屏障/护甲处理、战斗条件快照。回合开始与气绝按对应对象清除破甲。
- 毒蚀响应使用结算 ID 修改正在进行的原战斗；防守者不额外攻击或换位。反制、准备区追猎、鬼火不足、眩晕等分支都有检查。
- 鸩羽苏生先完整结算倒计时再抽牌；寂寥心象按每个敌方式神本回合首次获得破甲触发；碧羽散华只转换鸩自己施加的破甲，取消过期的“目标已有破甲”限制。
- 觉醒保留整局能力触发历史；鸩羽和致命诱惑在发起攻击时判断目标破甲；毒之华在实际伤害后按剩余生命施加破甲。
- 更新 AI 的合法用牌与目标收益判断；界面显示牌手破甲、倒计时和形态共存、觉醒历史，以及响应、免伤、转换与破甲反馈。

## 本次验证

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 修改前专项复现 | 16 项中 8 项失败 | [baseline.log](baseline.log) |
| 鸩规则正反例与结算顺序 | 122 项，0 失败 | [rules.log](rules.log) |
| 鸩交互，headless | 48 项，0 失败 | [ui-headless.log](ui-headless.log) |
| 鸩交互，真实原生窗口 | 48 项，0 失败；1280×800、1600×740 | [ui-native.log](ui-native.log) |
| Godot 全量验证 | `GODOT_VERIFY_ALL_OK`；含既有角色、布局、资源、交互与启动检查 | [full-verify.log](full-verify.log) |
| 全量验证中的对局 | 全角色 63 场、固定种子 60 场、重点机制 20 场；共 143 场完成 | [full-verify.log](full-verify.log) |
| JavaScript 既有回归 | 164 项通过，0 失败 | [node-tests.log](node-tests.log) |
| 普通库/界面审计 | 385 项，0 错误 | [catalog-audit.log](catalog-audit.log) |
| 全库还原审计 | **预期失败，退出码 1**；`fullCatalogRestored: false`，结构错误 0 | [rule-fidelity.log](rule-fidelity.log)、[完整报告](rule-fidelity.json) |
| 当前原生版本启动 | Godot 4.8.dev5 / Apple M5 OpenGL，启动日志无错误 | [native-boot.log](native-boot.log) |

测试验证的是记录中的实现模型，不能单独证明原版规则或完整操作手感。当前模型中仍有明确待核验项，见下文。

## 原生截图与录像参照

本轮复查指定录像 06:50 的布局、战斗位置和倒计时角标；录像不作为未展示的鸩规则证据。原生截图共 12 张，已检查瞄准、状态显示和响应效果：

| 场景 | 1280×800 | 1600×740 |
| --- | --- | --- |
| 牌手破甲、能力倒计时 | [截图](native-shots/1280-01-avatar-poison.png) | [截图](native-shots/1600-01-avatar-poison.png) |
| 倒计时法术选择目标 | [截图](native-shots/1280-02-countdown-target.png) | [截图](native-shots/1600-02-countdown-target.png) |
| 毒蚀双向转换 | [截图](native-shots/1280-03-toxic-combat.png) | [截图](native-shots/1600-03-toxic-combat.png) |
| 致命诱惑条件吸血 | [截图](native-shots/1280-04-conditional-lifesteal.png) | [截图](native-shots/1600-04-conditional-lifesteal.png) |
| 原战斗中的毒蚀响应 | [截图](native-shots/1280-05-toxic-response.png) | [截图](native-shots/1600-05-toxic-response.png) |
| 碧羽散华与倒计时 | [截图](native-shots/1280-06-scatter-countdown.png) | [截图](native-shots/1600-06-scatter-countdown.png) |

## 未完成范围

本轮 3 张牌及鸩式神条目保留 `verificationPending`：觉醒减计时与替换能力的顺序、正在发生的触发是否计入增强；毒蚀与屏障/碧羽散华的精确优先级；毒之华奇数剩余生命取整。当前分别按牌文顺序与此前已完成次数、转换先于防护且只替换一次、向下取整执行。没有将这些假设标记为已获原版实测支持。过量伤害吸血及多替换效果叠加也需要更广泛的客户端交叉验证。

全库现有卡牌仍为：已知近似 1072、未核对 1001、待核验 4、已建立来源与原生实现 37；式神分别为 154、91、1、4。4 张待核验牌包含上一轮遗留 1 张和本轮 3 张。`source-backed-native` 同样不能替代原版实机交互验收。

旧网页 JavaScript 执行器尚未同步本轮规则；其他式神近似效果、全局气绝周期、先后手补偿、多响应优先级及录像整体手感继续属于未完成范围。本轮没有关闭角色入口、减少卡池或放宽全库还原检查。
