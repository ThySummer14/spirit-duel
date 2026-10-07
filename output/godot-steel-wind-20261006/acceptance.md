# 2026-10-06 原版规则与交互修复验收

本轮原生规则修复范围为大天狗·钢风的基础能力及 8 张牌。已移除旧卡组中以加攻、护甲、抽牌或固定直伤代替复杂能力的映射，恢复手牌起源选择、倒计时使用起源、条件移动/抽牌、准备区追猎、屏障、条件连击、形态和幻境触发。两端基础战斗同步删除无依据的“击倒式神额外扣牌手 1 血”。

**全库还原尚未完成。** 规则审计明确失败：原生有效数据中至少 155 个角色能力、1084 张牌含明确简化标记；94 个角色与 1022 张牌未逐条核对。未标记内容也不能视为正确。本轮没有通过关闭角色、删除卡池或隐藏简化描述规避缺口。详见 [规则审计结果](rule-fidelity.json)、[审计日志](rule-fidelity.log) 和 [资料核对及未完成边界](../../research-notes/09-steel-wind-video-rules.md)。

## 已运行验证

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| `verify_steel_wind.gd` | 115 项、0 失败；八张牌、原版起源伤害与消灭抽牌、手动/自动起源、倒计时重置/气绝保留、形态、屏障、幻境、响应续结算 | [完整日志](acceptance-verify.log) |
| `verify_steel_wind_ui.gd` | 44 项、0 失败；1280×800 与 1600×740 原生鼠标输入、选择/取消、非法目标、输入锁、自动施放可读停留、追猎目标、重开清理 | [原生窗口日志](native-ui-final.log) |
| `./scripts/godot-verify.sh` | `GODOT_VERIFY_ALL_OK`；63 场全角色覆盖、60 场随机对局、20 场响应/选择对局，143 场全部结束，无卡死 | [完整日志](acceptance-verify.log) |
| `npm test` | 164 测试通过 | [日志](node-test-final.log) |
| `npm run audit` | 385 检查，0 错误 | [日志](audit-final.log) |
| `scripts/parity/sample-*.json` | 17 组共享基础行为逐步快照对照全部一致，包括删除气绝额外扣血后的响应连锁 | [日志](parity-all.log) |
| `npm run audit:rules -- --out …/rule-fidelity.json` | **退出 1，未通过**；上列全库简化/未核对缺口尚存。该结果必须保留为未完成信号 | [日志](rule-fidelity.log) |
| `git diff --check` | 无输出，退出 0 | 本次终端检查 |

完整 Godot 检查之后的最后改动仅将起源选择层置于悬停手牌之上；随后重新跑原生 44 项交互检查并复查截图，通过。JS/Godot 对照仅用于共享基础行为，不以旧 JS 钢风简化效果作为期望值。

## 原生截图

全部截图来自隔离测试存档的实际 Godot 窗口。测试使用固定血量与鬼火让连续演出可复现，不改正式游戏数值，也不改玩家存档。

| 场景 | 普通窗口 | 宽屏 |
| --- | --- | --- |
| 叶隐合法移动与抽牌提示 | [1280](shots-final/1280-01-leaf-aim.png) | [1600](shots-final/1600-01-leaf-aim.png) |
| 移动后的前线 | [1280](shots-final/1280-02-leaf-moved.png) | [1600](shots-final/1600-02-leaf-moved.png) |
| 有倒计时目标的提示分支 | [1280](shots-final/1280-03-countdown-aim.png) | [1600](shots-final/1600-03-countdown-aim.png) |
| 对应起源自动施放 | [1280](shots-final/1280-04-origin-cast.png) | [1600](shots-final/1600-04-origin-cast.png) |
| 追猎准备区目标 | [1280](shots-final/1280-05-pursuit.png) | [1600](shots-final/1600-05-pursuit.png) |
| 同一手牌的战斗/起源选择 | [1280](shots-final/1280-06-origin-choice.png) | [1600](shots-final/1600-06-origin-choice.png) |

程序化演出继续使用现有角色立绘，没有逐牌复制原版独有美术和动画。气绝保留倒计时在复活回合的具体推进边界尚缺直接原版实机证据，不能声称完全一致。旧 JS 钢风卡牌和其余角色的复杂联动仍需后续逐项修复。本轮没有重新构建或发布线上 Web 包。
