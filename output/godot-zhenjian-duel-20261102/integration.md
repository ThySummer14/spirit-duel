# 季沧海／无尘接入

模块 `ZhenjianDuelRules`（建议 VerifiedRules const `Zhenjian`）已通过独立 parse。共享文件由主任务编辑。

- `_recalc(unit)` 最终清零力量条件前，`unit.attack += VerifiedRules.Zhenjian.power(unit)`；该值独立派生，不能计入永久/普通grow。
- `VerifiedRules.event` 调 `Zhenjian.rule_event(gs, kind, details)`；unit-moved负责无尘，charged-stored/release负责力量刷新和剑阵触发。
- `describe_card_instance` 既有动态 describe 后调 `Zhenjian.describe(self,p_idx,card)`；追加瞬发和实际免火标识；`card_payment` 在最后返回前 `Zhenjian.payment(self,p_idx,card,payment)`，再经Focus报价（保证额外专注按既有规范处理）。
- `_push_card_frames` ChargedPair.prepare_card之后调 `Zhenjian.prepare_card(self,p_idx,src,card)`；这是捕获/消费“下一张”的时点，不能挪到攻击移动后。
- ChargedPair.store_hand 实际支付后、`_stored`前调`Zhenjian.consume_card(gs,owner,src,card)`，蓄力也消费该次优惠，不能在选择/取消时消费。
- ChargedPair.release 在原卡构建完成、标记chargedReleased后，调用`c=Zhenjian.prepare_release(gs,owner,src,c,record)`；这仅生成蓄力子效果次数，不重复整张普通效果。释放erase后力量需刷新（prepare_release已做）。
- Lantern.turn_start 收集自动释放列表时额外 `Zhenjian.auto_release(u)`，觉醒季沧海保留蓄力，其他全维持既有行为。
- `Zhenjian.can_manual_release(gs,owner,src)`／`release(gs,owner,src)`负责觉醒季沧海手动蓄力，可用GameState.release_charge命令包装，记录命令→release→resolve stack→emit。手动释放不占鬼火、不从手牌使用；UI与AI需可触发。
- `can_play_card`与自动响应合法性调用`can_use`；`_resolve_frame`前置 `Zhenjian.resolve_frame`；VerifiedRules.resolve_action前置`Zhenjian.resolve_action`。
- `card-complete`调`Zhenjian.completed(gs,frame,card)`，记录季沧海实际用过的不同战斗牌/狂潮手牌用后蓄力。
- `_install_form`调`form_entered`，`_begin_turn`起始能力阶段调`turn_start`。
- `_damage_unit` armorBreak消费和屏障消耗前调用`prevents_damage(self,p_idx,unit_index,amount,combat)`；true返回标准零伤结构，保证卸劲/非战斗免疫不浪费护甲破甲。护甲后两处 preview/unshielded 调 `reduce_damage(u,amount,combat)`（磐石战斗-1）。
- Panguan.destroy检查`Zhenjian.prevent_destroy(target)`，true返回false（只直接消灭免疫，不能阻止战伤致死）。generic substitute 已由Sparrow.absorb_knockout识别formRules.substitute，无需复制替身流程。
- `_offer_attack_responses` ChargedPair.defend_started前调用`Zhenjian.defend_started(self,frame)`，true return。模块自动释放燎原劲/蓄力振刀并续回原combat，不新增防守攻击，也不走respond_combat。
- `_finish_combat`调用`Zhenjian.combat_finished(self,owner,src,options,defender)`；实际无尘攻击计数，斗转退回，磐石双方战斗后各自随机蓄力1勾牌。
- Combat.strike 实际伤害后与其他combat_dealt同位调`Zhenjian.combat_dealt(gs,owner,src,victim,idx,result,options)`。旋风斩采用真实结算量/2向下取整，并提供“另一个敌方角色”选择。不能伪造随机或固定牌手目标。
- 选择type`zd-whirl`：GameState.resolve_divination_choice路由`Zhenjian.resolve_choice`，UI渲染`Zhenjian.choice_card`；通用heading/hint/instanceIds即可。AI.take_choice先`Zhenjian.ai_choice`。
- `_best_card` ChargedPair.ai_prepare之后调`Zhenjian.ai_prepare`；评分前置`Zhenjian.score_card`；状态`marks(gs,owner,u)`。

`overlay.json`和`new_definitions.json`已由既有prepare提供；新增追加攻击仍需主任务加入JS/gen源然后export，不能改loader绕过缺失定义。卡图16张manifest已有。
