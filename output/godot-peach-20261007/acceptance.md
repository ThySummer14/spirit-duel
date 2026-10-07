# 桃花妖专项验收（2026-10-07）

处理原版桃花妖的基础能力、觉醒能力与 8 张牌：`c10801–c10805,c10807–c10809`。研究及版本依据见 `research-notes/15-peach-rules.md`；规则交付片段为本目录 `overlay.json`。

已实现来源归属的治疗成长、临时/永久增益的气绝区别、双阵营与双牌手治疗、真实牌库实例定向随机抽取、丰实/盛开入场及逐次随机恢复、印刷形态身材、零费鼓舞的反制时序、全量复活、气绝时施法、条件瞬发，以及可跨回合保留且只用于下次普通出击的迅捷。AI 使用实际合法目标与资源条件。

## 验证结果

- `rules.log`：`PEACH checks=114 failures=0`。包含真实出牌流程、正反例、反制、0 勾目标、跨萤草形态入场顺序和 AI 合法性。
- `ui-headless.log`：`PEACH_UI checks=48 failures=0`，1280×800 与 1600×740 两种尺寸，使用真实鼠标事件。
- `baseline.log`：共享层尚未接入时的早期 88 项测试出现 52 失败，证明覆盖原先缺失能力。后续追加至 114 项。
- `ui-native.log`：原生窗口 `PEACH_UI checks=48 failures=0`，退出码 0；以 `--verbose` 运行，完整日志没有 `ERROR`、`WARNING`、ObjectDB 泄漏或残留资源告警。输出 16 张截图至 `native-shots/`。

UI 首次运行时，测试在扇形手牌的入场动画结束前点击，命中了重叠的盛开而不是觉醒。`ui-debug.log` 保存了实际出牌证据；等待布局结束后重跑通过，没有修改目标数值断言。

首轮原生图发现同目标「归队」「成长」「迅捷」浮字重叠。共享表现层现在逐次展示实际恢复与成长，并抑制同一事件的总生命差浮字；成长文本向上偏移 80 像素，同目标多次恢复间隔 0.7 秒。修改后已在两种尺寸重新运行原生交互并目视核验：恢复/归队位于卡面内，永久成长位于卡面上方，迅捷保留独立角标，没有互相遮挡。截图分别见 `1280-03a-heal-sequence.png`、`1600-03a-heal-sequence.png`、`1280-04a-revive-sequence.png`、`1600-04a-revive-sequence.png`；牌手指向、未激活式神检索、免费普通出击及全体归队也保留截图。

上一轮原生退出留下 2 个 ObjectDB 实例和 1 个资源告警。本次仅在所有场景结束后停止全局 `SfxHub` 播放器、释放音频流并等待音频线程收尾；实际交互期间仍播放音频，没有静音或跳过场景。修复后 headless 与 native 均重新通过原有 48 项断言。

本轮复验命令（项目根目录执行，`GODOT` 指向 `/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot`）：

```sh
"$GODOT" --headless --path godot --script res://scripts/verify_peach_ui.gd
"$GODOT" --verbose --path godot --script res://scripts/verify_peach_ui.gd -- "$PWD/output/godot-peach-20261007/native-shots"
```

## 验证边界

本地测试验证当前实现，不等同于原客户端所有交互已确认。桃花妖本体、桃之馨息、桃华灼灼保留 `verificationPending`：零实际治疗的成长触发，以及气绝桃花妖群体复活时的成长时点。旧 JS 引擎未应用此覆盖。跨角色禁疗、治疗转伤、切换等尚未还原的体系不在此次通过声明中。

全库还原状态由主代理运行 `npm run audit:rules` 汇总；本专项不应使尚有待核验/近似项的审计提前通过。
