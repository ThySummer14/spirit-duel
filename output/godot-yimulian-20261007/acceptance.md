# 一目连形态机制验收（2026-10-07）

本轮重写 Godot 中原版一目连的基础能力和 8 张历史卡牌 `c11801–c11808`，补齐形态独立倒计时、替换/气绝/主动移除时的退场触发、觉醒后的进场触发、罡风的先移除后抽牌、牌手护甲、出击鼓舞、直接消灭、龙的递增目标，以及瞬的本人受击响应和当前回合结束自毁。具体规则、来源和版本差异见[研究记录](../../research-notes/12-yimulian-form-lifecycle.md)。

形态能力作为独立结算帧执行，不借用额外使用法术。AI、倒计时选择、状态详情、牌手护甲/鼓舞显示和响应演出同步调整。视频 03:20 帧用于核对布局、定向交互和粉色沙漏；该片段没有原版一目连，不作为其全部结算规则的实测证据。

## 验证结果

| 检查 | 本次结果 | 记录 |
| --- | --- | --- |
| 一目连规则回归 | 128 项，0 失败；包含未觉醒/觉醒、替换、气绝、护甲抵伤与清除、鼓舞仅出击消耗、销毁防护穿透、独立龙次数、响应正反例与 AI | [rules-final.log](rules-final.log) |
| 一目连原生窗口交互 | 52 项，0 失败；1280×800 和 1600×740，实际选择/点击、输入锁定、响应顺序与状态展示 | [ui-native-final.log](ui-native-final.log) |
| Godot 全量验证 | `GODOT_VERIFY_ALL_OK`；63 场全角色覆盖、60 场种子对局、20 场专项对局，共 143 场；对局测试报告无卡死 | [full-verify.log](full-verify.log) |
| 最终 UI 调整后专项复验 | presentation 120 项、video layout 884 项，均 0 失败 | [presentation-final.log](presentation-final.log)、[layout-final.log](layout-final.log) |
| JavaScript 回归 | 164 项通过 | [node-tests.log](node-tests.log) |
| 现有 UI/内容结构审计 | 385 项，0 错误 | [catalog-audit.log](catalog-audit.log) |
| 全库还原审计 | 按约束返回失败：`RULE_FIDELITY_INCOMPLETE`，`fullCatalogRestored: false` | [rule-fidelity.log](rule-fidelity.log)、[完整明细](rule-fidelity.json) |

全量验证当时的一目连用例数为 123/50；随后增加龙的跨卡次数回归和倒计时展示断言，并修改沙漏绘制与目标上限文案，最终独立复验结果为 128/52。最后的显示改动另经 presentation 和 video layout 检查，没有用旧日志代替最终专项验证。

## 原生截图

复查两种窗口尺寸的牌手护甲、鼓舞、瞬的自动响应、惊弦选择形态倒计时和龙触发。截图来自原生 Godot 窗口，夹具提高资源便于串联验证，截图中的鬼火数不代表正常对局初始资源。

| 场景 | 1280×800 | 1600×740 |
| --- | --- | --- |
| 牌手护甲 | [截图](native-shots-final/1280-01-avatar-armor.png) | [截图](native-shots-final/1600-01-avatar-armor.png) |
| 鼓舞资源 | [截图](native-shots-final/1280-02-encourage.png) | [截图](native-shots-final/1600-02-encourage.png) |
| 瞬自动响应 | [截图](native-shots-final/1280-03-instant-response.png) | [截图](native-shots-final/1600-03-instant-response.png) |
| 形态倒计时目标与沙漏 | [截图](native-shots-final/1280-04-form-countdown-aim.png) | [截图](native-shots-final/1600-04-form-countdown-aim.png) |
| 龙的能力触发 | [截图](native-shots-final/1280-05-dragon-wave.png) | [截图](native-shots-final/1600-05-dragon-wave.png) |

## 保留的问题

风符·龙的“同一波不同目标”“两张牌不共享次数”有旧版细则支持，但还缺原作者来源和录像对应版本的交叉实测，保持 `verificationPending`。本轮为此加强审计：待核验卡不能计入 `source-backed-native`。

当前累计有 4 个式神和 32 张牌计入 `source-backed-native`，1 张牌待核验；仍有 154 个式神/1073 张牌为已知近似，92 个式神/1008 张牌未核对。这个分类表示现有证据与实现范围，不表示这些角色与全卡库的所有联动均已还原。

本轮未同步旧 JS/网页执行器；同一攻击的多响应优先级、同时气绝的完整排序、全局气绝周期、先后手补偿和其他未还原角色联动仍待继续。原版一目连新增协战牌不在当前 8 张历史卡库范围。规则、交互回归与稳定性通过不能替代全库还原，也不能宣称手感已经完全一致。
