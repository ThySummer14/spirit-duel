# 八角色批次的旧规则回归

使用 Godot 4.6.3 `--headless`，串行运行前批 24 组相关检查及 lantern、cotton、sea_butterfly、silk_ninja、susanoo、sparrow、futakuchi、fortune_pair 共 32 组。脚本支持时传入 `--rules-only`；没有重新执行全库测试或对局压测。

最终结果：32 / 32 组通过，输出合计 4166 条 `checks` 及独立的 16 个 combat `cases`。每组均检查进程状态、最终检查计数、`SCRIPT ERROR` / `ERROR` / `_FAIL` / 非零 `failures`；所有最终日志无上述错误。32 个旧测试脚本的 SHA-256 在首次执行与修复后定向复验之间一致。

首轮发现 combat、armor_limit、puppet、wind_night_mask 四组失败。共同原因是新加入的四相光环刷新无条件重算无关单位，导致旧规则测试设置的生命或攻击在结算途中被重置。root 将刷新限定为实际贡献发生变化的单位后，仅复跑这四组，全部通过。没有修改或放宽旧测试。

`results-first.json` / `summary-first.json` 及原始 `*.log` 保留首次结果；`*-final.log` 为四组修复后的复验日志；`results.json` / `summary.json` 是合并后的最终记录。`sourceChangesDuringRun` 保留并发实现期间的源文件变化供主任务复核。这些结果证明相关程序回归检查通过，不代表全库规则还原已完成。

随后只读核对同侧战斗续帧，实际复现了御馔津破魔标记错侧、傀儡师自击牌手未询问实际受击方护脸响应、声东击西错侧反击、封魔符对友方攻击者非法扣费，以及蓄力防守跳过后续响应/绮丽未排除真实攻击者。root 修复生产路径后，将正反例加入新建的 `godot/scripts/verify_octet_cross.gd`，扩展后的 72 条检查通过，见 `octet-cross-expanded.log`。

修复续帧后，仅定向复跑旧 sun_smoke、poison_pair、yujiazhu、movement 四组，共 1226 条 checks，全部通过且无脚本错误。记录在 `continuation-results.json` 和 `continuation-*.log`；其中 sun_smoke / movement 已包含于最初 32 组，不能把重复检查相加冒充新的独立覆盖。最初探针及修复前后日志保留在 `combat_victim_probe.gd` 和 `combat-victim-probe*.log`，没有修改旧测试。
