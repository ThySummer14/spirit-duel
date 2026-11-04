from pathlib import Path
r=Path(__file__).resolve().parents[2]
def edit(file,old,new):
 p=r/file;s=p.read_text();assert s.count(old)==1,(file,old[:70],s.count(old));p.write_text(s.replace(old,new,1))
v='godot/scripts/verified_card_rules.gd';g='godot/scripts/game_state.gd'
edit(v,'const Arakawa :=','const Cooking := preload("res://scripts/cooking_rules.gd")\nconst Arakawa :=')
edit(g,'\tvar p := player(p_idx)\n\tvar card: Dictionary = VerifiedRules.Firefly.describe_card(self, p_idx, inst, ContentLoader.card_def(inst.definitionId))','\tvar p := player(p_idx)\n\tif not VerifiedRules.Cooking.food_kind(inst).is_empty():\n\t\treturn VerifiedRules.HandBlessing.describe_card(self,p_idx,inst,VerifiedRules.Cooking.describe_food(self,p_idx,inst))\n\tvar card: Dictionary = VerifiedRules.Firefly.describe_card(self, p_idx, inst, ContentLoader.card_def(inst.definitionId))')
edit(g,'func valid_targets(p_idx: int, card: Dictionary) -> Array:\n','func valid_targets(p_idx: int, card: Dictionary) -> Array:\n\tif card.get("neutralFood",false):return VerifiedRules.Cooking.food_targets(self,p_idx,card)\n')
edit(g,'\tvar three_tail_free: bool = VerifiedRules.ThreeTail.free_first(self,p_idx)','\tvar three_tail_free: bool = not card.get("neutralFood",false) and VerifiedRules.ThreeTail.free_first(self,p_idx)')
edit(g,'\tpayment=VerifiedRules.Zhenjian.payment(self,p_idx,card,payment)','\tpayment=VerifiedRules.Cooking.payment(self,p_idx,card,payment)\n\tpayment=VerifiedRules.Zhenjian.payment(self,p_idx,card,payment)')
edit(g,'\tvar cost := effective_card_cost(p_idx, card)\n','\tif card.get("neutralFood",false):\n\t\tif not ignore_hand_restriction and VerifiedRules.KoiFragrance.restricted(self,p_idx,card):return {"ok":false,"reason":"缚梦明香：请先使用蚀印牌。"}\n\t\treturn VerifiedRules.Cooking.can_play_food(self,p_idx,hand_index,target_id)\n\tvar cost := effective_card_cost(p_idx, card)\n')
edit(g,'\tif not use_origin and VerifiedRules.Link.start(self,p_idx,hand_index):return true','\tif not use_origin and not VerifiedRules.Cooking.food_kind(card_instance(p_idx,hand_index)).is_empty():return VerifiedRules.Cooking.play_food(self,p_idx,hand_index,target_id)\n\tif not use_origin and VerifiedRules.Link.start(self,p_idx,hand_index):return true')
edit(g,'func _resolve_frame(frame: Dictionary) -> void:\n','func _resolve_frame(frame: Dictionary) -> void:\n\tif VerifiedRules.Cooking.resolve_frame(self,frame):return\n\tif frame.get("kind")=="card-announce" and frame.get("cardOverride",{}).get("neutralFood",false):\n\t\tVerifiedRules.announce_neutral_food(self,frame)\n\t\treturn\n')
edit(g,'"uid": player(owner).units[src].uid, "target": target','"uid": str(player(owner).units[src].uid) if src>=0 else "avatar-%d"%owner, "target": target')
edit(v,'"uid": p.units[int(frame.sourceIndex)].uid, "card": card, "resolutionId": rid','"uid": str(p.units[int(frame.sourceIndex)].uid) if int(frame.sourceIndex)>=0 else "avatar-%d"%p_idx, "card": card, "resolutionId": rid')
edit('godot/scripts/armor_break_rules.gd','\tvar source: Dictionary = gs.player(source_owner).units[source_idx]','\tvar source: Dictionary = gs.player(source_owner).units[source_idx] if source_idx>=0 else {"uid":"avatar-%d"%source_owner,"hp":0,"formRules":{}}')
edit('godot/scripts/hand_blessing_rules.gd','var u: Dictionary=gs.player(owner).units[src]\n\tmatch str(frame.effect):','var u: Dictionary=gs.player(owner).units[src] if src>=0 else {}\n\tmatch str(frame.effect):')
edit('godot/scripts/hand_blessing_rules.gd','"heal-self": gs._heal_unit(u,int(u.maxHp))','"heal-self":\n\t\t\tif src>=0:gs._heal_unit(u,int(u.maxHp))')
edit('godot/scripts/hand_blessing_rules.gd','"hurt-source": gs._damage_unit(owner,src,3,owner,src)','"hurt-source":\n\t\t\tif src>=0:gs._damage_unit(owner,src,3,owner,src)')
p=r/v;s=p.read_text();s+='''\n# Food is played by the player, without an invented source shikigami.
static func announce_neutral_food(gs, frame: Dictionary) -> void:
	var card: Dictionary=frame.cardOverride
	Arakawa.announced(gs,frame,card)
	FoxSuzuka.announced(gs,frame,card)
	BondDream.announced(gs,frame,card)
	KoiFragrance.announced(gs,frame,card)
	event(gs,"neutral-card-announced",{"player":int(frame.playerIndex),"card":card.duplicate(true),"resolutionId":int(frame.resolutionId),"sourceIndex":-1})
	if frame.get("automatic",false):return
	if cancel_pending_card(gs,frame):return
	var enemy:=1-int(frame.playerIndex)
	var continuation:=frame.duplicate(true);continuation.kind="card-counter-check"
	if PipeFox.single_target(gs,enemy,frame,card) and automatic_response(gs,enemy,"enemy-single-character",frame.targetId,continuation):return
	automatic_response(gs,enemy,"opponent-card-used",null,continuation)
''';p.write_text(s)
