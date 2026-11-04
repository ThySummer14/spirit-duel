# Shared integration

preload `const RednightWalnut := preload("res://scripts/rednight_walnut_rules.gd")` on VerifiedRules.

- VerifiedRules.event: `RednightWalnut.rule_event(gs,kind,details)` (inside before final append is fine, queues only).
- announce_card: `RednightWalnut.announced(gs,frame,announced)`.
- resolve_action dispatch: RednightWalnut.resolve_action(gs,p_idx,src,card,effect,target_id).
- game_state describe_card: RednightWalnut.describe_card(self,p_idx,card).
- valid_targets: RednightWalnut.targets(self,p_idx,card) != null overrides.
- can_play: RednightWalnut.can_use(self,p_idx,card).
- can_basic_attack: !can_deploy(u) => false; this only blocks deployments, not combat cards.
- _resolve_combat just after Samurai.available and before replacement/prepare/movement: `if options.get("basicAttack",false) and RednightWalnut.replace_basic(self,p_idx,unit_index,target_id): return`.
- _resolve_combat_ready after available check: `if RednightWalnut.before_attack(self,frame):return`.
- _resolve_combat_ready after fi computed (and Yujiazhu/deer target changes) but before avatar branch: `if RednightWalnut.before_hit(self,frame,fi):return`.
- Combat.strike very beginning: if options.rwNoDamage return {damage:0,dealt:0,knocked:false,overkill:0}. This means no damage including armor-break interaction (not zero attack power).
- _finish_combat: RednightWalnut.combat_finished(self,owner,src,options).
- _install_form: RednightWalnut.form_entered(self,p_idx,src,card).
- per-unit turn start: RednightWalnut.turn_start(self,p_idx,i).
- _trigger_realms: RednightWalnut.trigger_realm(self,p_idx,realm) => continue.
- _damage_unit at Xuenv.damage_dealt: RednightWalnut.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken,combat).
- _knockout_unit before fields removed: `var rw_saved:=RednightWalnut.death_frames(self,victim,u)`; append these frames near other saved death frames.
- end_turn(gs,p_idx): RednightWalnut.end_turn(gs,p_idx) to expire deploy lock at target owner's turn end.
- resolution_frame dispatch: RednightWalnut.resolve_frame(self,frame).
- resolve_divination_choice: pending.type==rw-items -> RednightWalnut.resolve_choice.
- choice_card: RednightWalnut.choice_card (null if unrelated).
- AI choice: RednightWalnut.ai_choice (null if unrelated); score_card; marks on battle status.

Data has 16 subjects + sword aura token. Set Ning canCharge only c26601/02/03/05/08; c26604/06/07 have no 蓄力 option on print; forms retain custom rw-card action and install_form manually.
