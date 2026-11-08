# 天逆每集成记录

父任务顺序执行本目录`prepare.py`、`output/godot-completion-drive-20261104/merge-content.py`（传此目录）、项目原Godot导出和`integrate-runtime.py`。准备脚本只写本模块元数据/原画及本目录输出；runtime脚本先验证全部anchor，再提交6个共享文件的文本更新，避免半次挂接。

`verified_card_rules.gd`preload `FearWing`，将`battle-power-changed`转给`rule_event`、接入native action及自动用牌许可。`game_state.gd`接入实际描述、目标、手动许可、frame、形态进场、回合开始、结界触发、恐惧气绝前snapshot/实际气绝后清理（含已接入的替代身份分支）、战斗开始前续帧及结束kill回调。`game_ai.gd`接入目标分值及真实选择处理。`ui/battle_screen.gd`接入真实实例及形态目标选择卡面，`ui/battle_status.gd`展示恐惧徽章；`sun_smoke_rules.gd`接还原灵咒清理。模块不修改共用战力实现。

`c61106`在`_resolve_combat_entered`的MusicFire检查之后执行一次翻倍，插`fw-resume-attack`续帧；正值资源变化只排fear-damage，不从event重入整个栈。`c61108`自动使用翼仍发出原`automatic-card`事件，具备真实`usedFromHand`/`playedInstance`，不把数量/层数转成一次无来源的增益。

已取得的官方原图、8张本地主体PNG及裁取派生面板见manifest。惧意蔓延实例选择的原版交互仍属推断，详见`research-notes/104-fear-wing-rules.md`和各条目的`verificationPending`。不得以本批测试通过宣称全库或所有实机交互已还原。

最终本模块日志：rules119/0，native149/0（含双尺寸30鼠标交互），12截图已查看，详见verification.json。没有提交commit。
