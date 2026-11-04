# 妖刀姬专项验收，2026-10-07

本轮仅涵盖普通妖刀姬的八张主体牌、一张万华皮肤、三个历史生成牌 ID 及基础/觉醒能力。妖刀姬·呪刃、未核对的其他角色和 JavaScript 旧执行器不在本轮还原范围。

实际完成规则包括：真实伤害触发瞬发及觉醒免费战斗牌；全队共享瞬发次数和一闪的顺序约束；永久迅捷而不增加普通出击次数；按当前公告改正的不祥击杀抽牌；保留互相气绝后的击杀归属和抽牌；禁锢整局击杀增强；万华主动、防守及空前线的额外先击；见切修改原防守战斗；战斗护甲保留至己方回合开始；杀念的五种完整战斗牌生成。

证据与版本差异见 [研究记录](../../research-notes/17-yaodao-rules.md)，生产覆盖片段为 [overlay.json](overlay.json)。不祥快照中的“命中牌手抽牌”被 2020-12-24 官方公告淘汰，不能按过期牌文修复。

## 已执行检查

| 检查 | 实际结果 | 日志 |
| --- | --- | --- |
| Godot 4.8.dev5 真实 GameState 规则专项 | 277 检查，0 失败；无脚本错误 | [rules-final.log](rules-final.log) |
| headless 鼠标 UI，1280×800 与 1600×740 | 115 检查，0 失败；无脚本错误 | [ui-headless.log](ui-headless.log) |
| 原生鼠标 UI，1280×800 与 1600×740 | 115 检查，0 失败；10 张截图逐张目视 | [ui-native.log](ui-native.log)、[最终截图](shots-final/) |
| 专属模块、规则脚本与 UI 脚本语法检查 | `--check-only` 无脚本错误 | 使用下列命令可复跑 |
| `git diff --check` | 通过 | 无错误输出 |

规则专项还实际调用了 `GameAI.take_action`：零火时先用一闪、再使用已取得瞬发的战斗牌；觉醒后先免费普通出击，再用免火战斗牌。不是仅测试评分函数的返回值。新增逐击演出断言检查万华空前线两刀的独立数值、战意原卡片身份、先击与普通互伤的顺序，以及防守方伤害来源；不能把总生命值正确当作二段表现正确。

主代理统一交接窗口后已执行原生鼠标测试，检查双尺寸共 10 张最终截图。万华 3/8、觉醒后的永久迅捷角标、免火战斗牌、杀念三张完整生成牌、禁锢击杀增强文字以及见切响应牌面均可见；最终响应画面没有回合横幅遮挡。截图证明本轮界面状态与排版，不代表录像中未出现的交叉机制已核验。

## 首轮问题与处理

[rules-first.log](rules-first.log) 保留首次测试：暴露共享响应补甲直接读取不存在的 `shieldExpires`，主代理已改为带默认值累加；另两个断言误将测试用岚岳的力量 1 写成 2，改成真实目录数值。没有削弱万华与响应要求。

[ui-first.log](ui-first.log) 保留首次鼠标测试：选出击者后需等待一帧让界面布局稳定。[ui-diagnostic.log](ui-diagnostic.log) 保留随后定位结果：界面已能正确点牌手，但测试直接写 `current_player` 没有推进回合号，导致上一回合优惠被测试错误保留。现使用真实 `end_turn(0)` 推进回合，验证见切在敌方回合支付一火。规则实现未为这些测试作特殊分支。

[ui-cues-first.log](ui-cues-first.log) 保留逐击演出测试首次的 4 个失败：战意的两刀丢失了原卡片 ID。共享层此前误用仅法术存在的上下文，主代理现改为战斗选项/续帧显式传递原卡片快照，防守响应也保留其独立卡片，包含防守响应卡片身份的最终复测 115/0。

[ui-native-first.log](ui-native-first.log) 保留首次原生 115/0 结果。目视时发现测试没有等待 `end_turn` 过场就调用下一次攻击，且复用气绝目标时只恢复生命、没有清除气绝字段；专项脚本现等待过场并建立一致的测试初态，第二次原生仍为 115/0。重复的首轮 10 张 PNG 已删除，最终 10 张保存在 `shots-final/`，首轮日志仍保留。

## 明确保留的未知项

双万华额外先击排序、防守眩晕的完整交叉组合、先取得基础瞬发再觉醒的层叠、手持多张见切的同事件响应、杀念内部随机权重与重复规则仍带 `verificationPending`。本轮程序按文档列出的显式模型验证，不将未确认分支标成原版已复现。全库 `audit:rules` 仍应失败。

复跑：

```sh
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_yaodao.gd
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_yaodao_ui.gd
# 原生窗口需统一协调；本轮已完成：
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_yaodao_ui.gd -- "$PWD/output/godot-yaodao-20261007/shots-final"
```
