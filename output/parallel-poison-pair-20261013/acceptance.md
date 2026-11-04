# 跳跳弟弟／清姬验收（2026-10-13）

完成范围：Godot 两位式神的基础与觉醒能力、16张普通专属牌、真实目标及目标变更、动态手牌、限时能力、AI与青坊主轮回攻击记录联动。常规经典版按官方2020-02-27和2021-11-25公告覆盖过期快照，2023-03-09「有个牌局」增强未套用。

验证全部在 `.build/poison-pair/godot`，从当前共享基线重新复制并运行精确 `integrate.py`。共享文件由主代理串行合入。

| 验证 | 结果 | 日志 |
| --- | --- | --- |
| 规则、正反条件、合法目标、四场AI完赛 | 612项，0失败 | final-verify_poison_pair.log |
| 原生UI实际鼠标输入，1280×800、1600×740 | 36项，0失败 | final-ui.log |
| 鸩回归 | 125项，0失败 | final-verify_zhen.log |
| 共享战斗回归 | 16例通过 | final-verify_combat.log |
| 经典共享结算回归 | 30项，0失败 | final-verify_classic_core.log |
| 判官／海坊主回归 | 147项，0失败 | final-verify_judge_tide.log |
| Godot导入与编译 | 成功；最终日志无SCRIPT ERROR/ERROR | import-final.log |

截图6张在 `screenshots/`；人工检查蛇行击成长和肿胀状态面板，文字与状态标签可见。曾发现普通牌因空autoResponse字段显示错误响应标签，已去掉空字段并加入原生UI反例；最终截图为修正后产物。

共享接入：

```sh
python3 output/parallel-poison-pair-20261013/integrate.py /absolute/path/to/godot --check
python3 output/parallel-poison-pair-20261013/integrate.py /absolute/path/to/godot
```

脚本先检查全锚点再写入，复制独立的poison_rules及两个验证脚本、合并sources/units/cards overlay；不会替换整个共享文件。主代理另将 `verify_poison_pair verify_poison_pair_ui` 加入 `scripts/godot-verify.sh` 串行清单。

`verificationPending`仍保留两位式神与五张牌的边界，详情见 `research-notes/30-poison-pair-rules.md`。这些测试证明当前模型实现，没有为全库还原作担保。普通破甲能回复生命；真正中毒禁回复及福满乾坤端到端继续pending。旧JS未同步，其他角色未纳入本批。未提交或推送。
