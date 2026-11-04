# ApeSleeve 接口

`const ApeSleeve := preload("res://scripts/ape_sleeve_rules.gd")`。

- `resolve_action(gs,owner,src,card,effect,target_id)`、`resolve_frame(gs,frame)`、`targets(gs,owner,card)`、`score_card(gs,owner,card,target_id)`、`marks(gs,owner,u)`按其他模块接入。
- `describe(gs,owner,inst,card)`在describe_card_instance用于生成的零鬼火变幻自在；保留inst.apeFree跨存档。
- `choice_card`、`resolve_choice`、`ai_choice`接入通用选择UI/AI。
- `turn_start(gs,owner)`每个回合起始调用一次（函数内部处理双方猿猴夺月，己方基础互换/觉醒发牌），应在普通抽牌前。
- `end_turn(gs,owner)`每个回合结束时移除天衣无缝临时增益。
- `form_entered(gs,owner,src,card)`实际形态安装后调用。
- `completed(gs,frame,card)`完成用牌后触发补缀添香。
- `attack_started(gs,frame)->bool`置于combat-start帧其他触发附近；true则已压回续帧并暂停，用于丝缕相连攻击前随机1伤。
- `combat_finished(gs,owner,src,options)`在finish_combat里撤销仿模本次战斗增益。
- `_damage_unit`非零实际伤害后（气绝清理前）调用`damage_dealt(gs,source_owner,source_index,victim,unit_index,taken)`，只会给真正小袖来源生成被动帧。
- `_knockout_unit`确认不被替身替代后，清理前保存`var sleeve_saved=ApeSleeve.death_frames(gs,victim,u)`；清理后append_array(sleeve_saved)。这会移除幸存者身上一次缝补并生成4伤帧。
- `ApeSleeve.knocked_out(u)`在气绝数值重算前调用，减去此模块的普通/回合/本次战斗增益、清空一次缝补；永久结袂保留。
- `ApeSleeve.reset_ledger(u)`在日出有曜等清除数值后调用，避免将已经消除的本模块数值重复撤回。
- `base_damage_bonus(gs,owner)->int`供共享base_damage_unit/avatar/projectile wrappers使用，统计活着且觉醒未压制的小袖，增幅只作用基础/觉醒能力。

`c29606`完整结袂定义已用日文wiki和原客户端玩家实录描述补充，主体16牌均有主要机制；中服tooltip与复杂全序保留verificationPending。新增`revived(gs,owner,idx)`与`remove_charm(gs,owner,idx)`已接入Movement/PipeFox，共享脚本已执行后请勿重复运行旧integrate-runtime.py。
