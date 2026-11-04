猫掌柜246 / 饴细工249，共16张主体牌。`prepare.py`已执行；`integrate-runtime.py`只准备，供主任务顺序接入，不由本agent执行。`new_definitions.json`现提供三猫/大小糖人5个无专属牌token-only unit定义，供运行时实体与选择UI显示真实派生原图，不进入可构筑式神子集；实体各有独立uid、身材、关键词及墓地。

共享接入清单：

- VerifiedRules preload `SugarCat`；`event`转`rule_event`；普通`announce_card`转`announced(gs,frame,announced)`，勿从中立食物announcement调用；resolve_action转发。
- GameState `_resolve_frame`优先转`SugarCat.resolve_frame`，普通card-complete转`completed`，`_install_form`完成身材重算后转`form_entered`；真实己方回合开始转`begin_turn`。
- 手牌投影`describe_card(gs,owner,inst,card)`；can_play调用`can_use`；valid_targets调用`targets`并保留null的原路由；AI `_score_card`调用`score_card`，`_resolve_choice`调用`ai_choice`。选择UI通过`choice_card(gs,owner,iid)`，实际resolve_divination_choice优先转`resolve_choice`；battle_status状态标记增加`marks`。
- 两处全局resolver清理增加`remove_departed`；通用summoned死亡分支增加`summoned_knockout`；Weaver.leave_front在原有召唤物分支前识别`scSummon`并remove_summon（不能只把front改0而迟到后续召唤之后才移除）。Weaver.revive在leave_front前：对scCandy调用`fuse_revived`，返回>=0直接return；SugarCat.revived同步四饼全局力量。
- CookingRules提供cook/gain_ingredient/ingredient_options/gain_feast/auto_use_from_hand/hand_food_count/feast_count/describe_food；糖人大师只观察food-used且fromHand=true，normal feast/dark都触发，自动新生成及食神复制不触发。觉醒饴细工不观察无式神来源的中立食物。

结算顺序：召唤物本次攻击先入栈，随后emit summon-created排食材使用，最后generic entered进场响应；LIFO保证真实食材和对应三猫基础能力先于攻击。猫乱斗每个“召唤→喂食→基础能力→随机攻击”完成后才下一个召唤。糖人融合复用Weaver.combine，实际两实体受伤身材相加并传递不屈/食材关键词/附属状态，旧实体独立墓地；scCandy无weaverSummon标记，不继承织雪入场回合不能出击的限制。

15牌主要机制接入；c24908甘如暖阳明确partial/verifiedRules=false。特殊佳肴完整独立随机词池缺资料，Cooking.gain_feast空池发food-definition-unverified，不制造普通三食材随机佳肴。6张阈值永久+5/+5及恢复10保留有条件代码。猫乱斗历史按首次召唤类型去重的边界、糖人融合是否算入场、中文独立召唤物tooltip、复杂响应全序保留verificationPending，不通过测试来声称已由原客户端验证。

2026-11-04实际验证：rules-only 157 checks/0 failures；native完整verify 173 checks/0 failures（包含规则157及两尺寸真实鼠标16），日志无SCRIPT ERROR。新增5张派生日文完整原卡图已逐一view，见summon-art-manifest.json；新增verify_sugar_cat_art.gd只补一轮原生资产/实体显示检查及2张必要截图，不重复前6张双尺寸图。

派生资产最终补验：Godot4.6.3 import无ERROR；verify_sugar_cat_art.gd原生16 checks/0 failures/exit0，实际鼠标选择显示三猫不同原图，先验证2/2小糖人，再手牌佳肴真实融合6/6不屈大糖人。仅新增derived-ui/derived-01-three-cats.png和derived-02-big-candy.png两张截图，已view检查。该结果后规则GDScript与资产冻结。
