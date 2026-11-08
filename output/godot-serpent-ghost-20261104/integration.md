# SerpentGhost共享接入与本次验证

范围为鬼使黑·鬼使白194、八岐大蛇220，共16主体、2派生身体、2派生法术。主体来自本地18张完整中文PNG，派生来源与保留差异见`../../research-notes/102-serpent-ghost-rules.md`。`prepare.py`可重建overlay/new_definitions、16主体原图与4派生图manifest。root已顺序接入共享生产层并merge/export；`integrate-runtime.py`为早期接入记录，本次未重复执行。最新额外光环hook由root直接接入，见下文。

## 规则与共享契约

- `source_index`允许混沌复制法术用`sgCasterUid`指向真实复制身体。`runtime_definition`对应`ContentLoader.runtime_unit_def`中的`sgRuntimeDefinition`：原UID/id保留所属专牌身份，身体能力/图像有明确派生定义。`has_charge`让白不获得黑基础充能。
- 标准气绝前，铃彦姬等自有身体切换优先于大蛇替换；鬼使黑`replace_knockout`扣2能量并排`sg-switch-white`。`sg-`帧在连击交换间inline结算，在群伤整组后结算。白真正气绝恢复黑气绝身份，不触发切回黑历史。
- `death_snapshot/after_knockout`在普通死亡前保存原身份、清理后排变蛇，蛇死亡排原身份气绝恢复；源大蛇、召唤物、已变蛇与被压制原基础身体不重复变蛇。`transform_snake`保留UID/id并改实际基础身材/能力/原图；觉醒大蛇会让新蛇复制当前身材、形态和混沌化身。它们不是额外占位召唤物。
- `can_deploy/can_use/targets/describe_card/ai_prepare/score_card`控制真实身份可用性、敌方准备区追猎、敌方变蛇目标、黑白同名觉醒投影及AI爆能支付，未隐藏角色入口或缩减卡池。白/蛇派生定义为token-only，不加入构筑入口。
- `Movement.request_burst/resolve_choice`为共用爆能交互，不在SG另造虚拟菜单。原卡名仍可显示在完整原PNG上，菜单实际可见`currentCardStats`徽标区分普通使用/爆能2；点击后原实例设置爆能并由原生UI续用真实牌。`Yujiazhu`负责能量报价与支付。
- `combat_finished`只在不洁之力明确标记的攻击后消灭非蛇魔。索命通过有限`sg-reap-next`帧及真正自动用牌延续本链，不把增强次数重新展开。无常鬼使接原`source-attacked`响应。白觉醒通过`_push_card_frames`额外使用真正索魂，按实际受伤量投射，每回合一次。
- `incarnation_config/pool/has_incarnation`对觉醒本体及新复制蛇提供25/15、每回合一次化身，眩晕时不触发；复制牌实际源UID参与目标判断。不能以手动出击/留着原专属牌代替混沌失控机制。
- 神念之影本地中文PNG为3/6且有蛇魔力量+1。`power_delta`计算当前同侧每个active且`sgInspireSnakes`形态来源，给实际蛇魔每源+1；`_recalc`将其写入`sgSnakeAuraApplied`并加入真实力量。`refresh`只在贡献变化时重算，root将其接入两个每帧清理区；本模块在实际入形态、新蛇/复制身体建立、气绝后也同步。替换形态、来源压制/气绝会撤销，复制形态会成为独立来源，普通式神与敌方不会误获增益。

## 已运行的检查

`Godot4.6.3 --headless --path godot --script res://scripts/verify_serpent_ghost.gd -- --rules-only`最终136检查、0失败，`rules-only.log`无SCRIPT ERROR/ERROR。覆盖16主体实际结算、16原图存在、黑白身份/能量门槛/真实气绝/倒计时、状态清保留、群伤后与连击间切换、爆能真实选择与支付、白觉醒受伤投射/次数、真实响应、索命有限链、蛇生命周期及混沌复制等。神念力量光环有进入、晚生蛇、敌方回合不触发昂扬、己方始回不叠加力量、来源压制恢复、真实换形态、气绝、多复制来源叠加/移除正反例。

连击最初错误fixture把“攻击者有连击”当作防守黑也有额外反击。已修正新专项断言：攻击方独有连击，敌从30到28；双方有连击为30到25（黑3/白2）；防守方独有连击为30到24（黑3两次，普通交换后才切白）。未修改生产连击规则来迁就fixture，旧verify未改，大型调试输出已移除。

`verify_serpent_ghost_ai.gd`独立运行48检查、0失败，`ai.log`无ERROR。每张主体均先取得真实AI合法候选/目标，再执行`AI.take_action`，核对真实`command_log`的`play_card`、card和target。不是仅调用评分接口或绕开AI直接`gs.play_card`冒充AI使用。兄弟之忆准备白身份，大蛇牌准备真实蛇魔，爆能由AI准备。

原生1280×800、1600×740的`verify_serpent_ghost.gd`实际运行133检查、0失败，`native.log`无ERROR；这是加入光环17项附加断言之前的119规则/纹理+14鼠标交互。六张`native/*.png`已逐张view_image目检：两尺寸的原卡选靶高亮、敌方3/3蛇魔、鬼使白原图/名字/5/7临时实际身体、普通使用/爆能2/取消三选项均可见。实际点击完成敌方变蛇、无常切白、兄弟切黑、爆能2选择；用原手牌instance引用及最终能量扣2、手牌消耗核对实际执行。光环后续增加不涉及这三个UI场景，按本批约束没有重复跑整套原生截图。

16主体源/目标SHA256全部匹配，`art-validation.json`错误0。派生索魂源JPEG转PNG，`derivative-art-manifest.json`单列源/目标hash并验证decodedPixelsEqual=true，其余3派生保留原字节。新增`verify_serpent_ghost_assets.gd`用于root统一import后检查4派生真实Texture2D及CardFace原图路径；统一导入后4项派生纹理检查全部通过，见`derived-assets.log`及`validation-summary.json`。

## 仍待原版精确核对

主体主要机制按中文基础牌文完成；并未逐赛季追溯平衡，也未宣称指定录像已逐牌核验。跨身体复杂附属状态、觉醒复制的所有附属状态、直接变形后的永久成长恢复、神愤免战伤持续边界与复杂响应/群伤的原客户端精细全序仍在元数据`verificationPending`。全库还原审计须继续失败，普通对局稳定与本专项通过都不能替代全库还原完成。
