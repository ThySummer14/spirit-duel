# 兵俑本轮验收

范围：兵俑基础能力、觉醒与 8 张主体牌。当前卡库未发现独立皮肤牌或衍生牌。规则来源及版本取舍见 `research-notes/19-bingyong-rules.md`；本轮不是全库还原验收。

## 已运行结果

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 修改前基线 | 8 项，5 项失败 | `baseline.log` |
| 合并引擎规则检查 | 112 项，0 项失败 | `rules.log` |
| 1280×800、1600×740 headless UI 鼠标交互 | 32 项，0 项失败 | `ui-headless.log` |
| 双分辨率原生 OpenGL/Metal UI 鼠标交互 | 32 项，0 项失败；进程 exit 0 | `ui-native.log` |
| 原生渲染截图 | 12 张，已目视检查 | `native/` |

运行引擎为 Godot 4.8.dev5.official.9552dfb68。

```sh
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_bingyong.gd
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://scripts/verify_bingyong_ui.gd
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/verify_bingyong_ui.gd -- "$PWD/output/godot-bingyong-20261007/native"
```

覆盖基础护甲先过期后重取、觉醒保存及气绝清除、尘刀读取实际护甲、冲撞在手实例累计增强及新抽牌排除、形态替换基础身材、不动如山移入与回合成长、森罗逐段伤害上限及屏障先行、护甲与破甲双向即时抵消、古尘之壁按净余护甲给予其他存活者生命、古尘之盾选靶及攻击前自动响应、尘缚动态禁止替换并允许既有前线战斗、合法 AI 操作。

UI 检查通过真实鼠标事件完成古尘之盾选靶、尘刀和形态牌使用、增强数据呈现及尘缚禁用操作，也确认结算期间输入锁定。

初次原生截图发现新发手牌尚在入场动画中，已修正测试等待并加入透明度完成断言，重新运行后增强三次的冲撞完整显示 +5 力量/+5 护甲，尘缚下的尘刀完整显示禁用状态；两种尺寸的牌文均未裁切。本轮没有改动共享视觉层，形态后的战场单位仍沿用本体插画，不据此声称原版画面已完全还原。

## 尚待原客户端交叉验证

四张牌的 `verificationPending` 未移除：尘刀遇战斗准备阶段改变攻击者护甲的跨角色响应时准确取值点；古尘之壁队友生命在目标气绝后的持久性；古尘之盾与同次攻击其他响应的优先级；尘缚与召唤物、特殊强制移动的相互作用。它们不应被“专项检查通过”描述为已全部确认。

`rules-first.log` 是主代理整合过程中缺少 `_finish_combat` 的一次早期编译失败记录，最终结果以 `rules.log` 为准。保留它用于区分失败过程与最终验收，不修改失败输出。
