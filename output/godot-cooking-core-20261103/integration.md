# Cooking runtime hooks

Neutral通路已由主任务接入，勿重复注入。

`Cooking.describe_card(gs,owner,inst,card)`：普通16牌动态增强/原实例弹回。`Cooking.resolve_action(gs,owner,src,card,effect,target_id)`：普通动作。

`Cooking.completed(gs,frame,card)`：普通card-complete中调用；原生快速烹饪原实例回手并消耗弹回，不让同一实例无限回手。

`Cooking.form_entered(gs,owner,src,card)`：猫咪日和原图进场烹饪。`Cooking.end_turn(gs,owner)`：现场烹饪在己方结束且位于前线时烹饪。

`Cooking.combat_dealt(gs,owner,src,victim,idx,result,options)`：Combat.strike实际每段伤害后（单位和牌手两路）调用，五丸基础只敌方牌手；觉醒单位/牌手均真实造成战伤才烹饪。keyword combo通过unit.keywords保留觉醒。

`Cooking.trigger_realm(gs,owner,realm)->bool`：拦截梦想料理无回合起始假触发；`Cooking.realm_entered`已在自有cooking-realm action调用一次，不要另在_deploy_realm重复调用。

`Cooking.score_card`、`Cooking.marks`供AI与状态。

Neutral quote `payment`、manual `play_food`、实例 `describe_food`、`food_targets`、`can_play_food`、优先 `resolve_frame`、VerifiedRules.announce_neutral_food 已约定由主任务接入。食品complete本模块调用Arakawa.completed/HandBlessing.completed并发neutral-card-completed事件，不重复普通式神complete钩子。

食品与动态实例：普通中立牌level0/cost1；raw与runtime均 `unitId=""`, sourceIndex=-1，永不绑生成式神。`foodData`完整保存kind/quality/ingredientKind/parts/合成来源。

## Other-module APIs

food_kind / hand_food_count / feast_count / ingredient_options / gain_ingredient / gain_unknown / gain_feast(parts=[])/cook / auto_use_from_hand / auto_use_generated 。auto_use_generated只支持ingredient或unknown，其他返回false。手牌auto_use_from_hand ingredient含unknown，feast明确不含dark。

`food-gained`与`food-used`事件供SugarCat/RabbitTide观察。中立牌sourceIndex=-1，`abilitySourceIndex`另保存自动使用的能力来源。手牌食物/取得历史不把dark当正常feast；五丸的“被使用佳肴”和“本回合使用过佳肴”接受dark，保留中服特殊边界pending。

甘如暖阳的直接佳肴特殊随机池未完整核对，gain_feast无显式parts且c24908.cookingDirectFeastPool为空时返回空并记录food-definition-unverified，不拿普通三食材近似。

`Cooking.can_use(gs,owner,card)`须挂can_play_card，拒绝25208/25304重复觉醒。主任务已接入。`reset_ledger`仅清食品／烹饪数值账本供纸人重置，保留关键词账本；`knocked_out`实际扣除普通成长并移除食品关键词。

最终专项：rules-only152项通过；native当时126规则+14交互=140项通过、8图已目检。日志见rules-only.log/native.log；native.log为exec会话34574实际stdout转存。原型集成脚本已经主任务执行，勿再次注入。
