class_name LanternRules
extends RefCounted
const Content:=preload("res://scripts/content_loader.gd")
static func source(u: Dictionary) -> bool:return Content.runtime_unit_def(u).get("lanternRules",false)
static func enabled(u: Dictionary) -> bool:return int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func history(u: Dictionary) -> int:return int(u.get("lanternRevivals",0))
static func revived(gs, owner: int, idx: int) -> void:
	var u:Dictionary=gs.player(owner).units[idx]
	if source(u):
		u.lanternRevivals=history(u)+1
		gs.VerifiedRules.event(gs,"lantern-revived",{"player":owner,"uid":u.uid,"count":history(u)})
	for r in gs.player(owner).realms.duplicate():
		if r.get("nativeRealm")!="lantern-luck" or int(r.hp)<=0:continue
		gs._heal_avatar(owner,4)
		if gs.VerifiedRules.Light.roll(gs,owner,4,6,gs._source_index(owner,Content.card_def(str(r.cardId)))):
			for copy in gs.VerifiedRules.Fortune.last_repeats(gs,owner):gs._set_fire(owner,int(gs.player(owner).energy)+1)
static func death_frames(gs, owner: int, u: Dictionary) -> Array:
	if owner<0 or not source(u) or not enabled(u):return []
	return [{"kind":"lantern-projectile","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,u.uid),"amount":2+history(u)}]
static func damaged(gs, owner: int, idx: int, amount: int) -> void:
	var u:Dictionary=gs.player(owner).units[idx]
	if amount<=0 or not enabled(u) or not u.get("formRules",{}).get("lanternDrift",false):return
	if gs.VerifiedRules.Light.roll(gs,owner,4,6,idx):
		for copy in gs.VerifiedRules.Fortune.last_repeats(gs,owner):
			var hp:=int(u.hp);gs._grow_unit(u,1,-1);u.hp=maxi(0,hp-1)
			u.lanternDriftChanges=int(u.get("lanternDriftChanges",0))+1
static func knocked_out(u: Dictionary) -> void:
	var amount:=int(u.get("lanternDriftChanges",0))
	u.attackBonus=int(u.attackBonus)-amount;u.maxHpBonus=int(u.maxHpBonus)+amount
	u.erase("lanternDriftChanges");u.erase("lanternStored")
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("lanternRules",false):return true
	var u:Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.id=="c29305" and u.awakened:return false
	if card.get("chargeOnly",false) and u.has("lanternStored"):return false
	if int(u.hp)<=0 and card.get("allowKnockedSource",false):
		if card.id=="c29301":return gs.VerifiedRules.YanmieTrio.can_revive(gs,owner,u)
		return gs.VerifiedRules.Rebirth.can_revive(u)
	return true
static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("lanternRules",false):return card
	var c:=card.duplicate(true);var src:int=gs._source_index(owner,c)
	if src<0:return c
	var u:Dictionary=gs.player(owner).units[src]
	if c.id=="c29308":c.currentCardStats="蓄力 · 下个己方回合自动施放 · 各%d点伤害"%(4+2*history(u));c.enhanced=history(u)>0
	if c.get("lanternFocus",false):
		var focused:bool=gs.card_payment(owner,c).get("focusPaid",false)
		c.currentCardStats=gs.VerifiedRules.Focus.label(gs.card_payment(owner,c))+" · "+("+2力量 / 自身+2破甲" if c.id=="c29302" else "再随机攻击另一敌方式神") if focused else gs.VerifiedRules.Focus.label(gs.card_payment(owner,c))
	return c
static func store_card(gs, owner: int, hand: int, card: Dictionary, payment: Dictionary) -> bool:
	var src:int=gs._source_index(owner,card);var u:Dictionary=gs.player(owner).units[src]
	if u.has("lanternStored"):return false
	var inst:Dictionary=gs.take_card_instance(owner,hand)
	gs._record("play_card",{"hand":hand,"card":card.id,"cardView":card.duplicate(true),"payment":payment.duplicate(),"charge":true},owner)
	gs._set_fire(owner,int(gs.player(owner).energy)-int(payment.cost),true)
	gs.VerifiedRules.Moon.consume_card(gs,card)
	if payment.usesInstant:gs.consume_instant(owner)
	u.lanternStored={"card":card.duplicate(true),"instance":inst.duplicate(true),"turn":gs.turn_counter,"order":gs.next_rule_event_id}
	gs.VerifiedRules.ThreeTail.card_used(gs,owner,src,card,false)
	gs._log("%s 蓄力「%s」，下个己方回合开始时自动施放。"%[u.name,card.name],gs.TONE_CARD)
	gs.VerifiedRules.event(gs,"lantern-stored",{"player":owner,"uid":u.uid,"card":card})
	gs.state_changed.emit();return true
static func turn_start(gs, owner: int) -> void:
	var stored:Array=[]
	for idx in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[idx]
		if source(u) and enabled(u) and u.awakened and int(u.hp)<=0 and gs.VerifiedRules.Rebirth.can_revive(u):
			if gs.VerifiedRules.Light.roll(gs,owner,4,6,idx):
				for copy in gs.VerifiedRules.Fortune.last_repeats(gs,owner):gs.VerifiedRules.reduce_countdown(gs,owner,idx,1)
		if u.has("lanternStored") and int(u.hp)>0 and not u.get("removed",false) and not gs.VerifiedRules.Stun.blocks(gs,owner,u) and int(u.lanternStored.turn)<gs.turn_counter and gs.VerifiedRules.Zhenjian.auto_release(u):stored.append(idx)
	stored.sort_custom(func(a,b):return int(gs.player(owner).units[a].lanternStored.order)<int(gs.player(owner).units[b].lanternStored.order))
	for i in range(stored.size()-1,-1,-1):gs.resolution_stack.append({"kind":"lantern-charged-cast","playerIndex":owner,"sourceIndex":stored[i]})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u:Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"lantern-revive-one":
			gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
			if int(u.hp)>0:u.hp=1;gs.VerifiedRules.TreeSakura.sync_power(u)
		"lantern-awaken":
			gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false);gs._awaken(owner,src,card,effect.value)
		"lantern-realm":gs._deploy_realm(owner,card);gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
		"lantern-burn":
			# Each one-point packet resolves before selecting the next living target.
			gs.resolution_stack.append({"kind":"lantern-scatter","playerIndex":owner,"sourceIndex":src,"remaining":maxi(0,5+int(u.get("spellPower",0))),"context":gs._card_effect_context.duplicate(true)})
			gs._knockout_unit(u,owner,src);gs.VerifiedRules.reduce_countdown(gs,owner,src,1)
		"lantern-combat":
			var focused:bool=card.get("lanternFocused",false);var bonus:=int(card.value)+(2 if focused and card.id=="c29302" else 0)
			if focused:gs.VerifiedRules.event(gs,"lantern-focus",{"player":owner,"uid":u.uid,"card":card})
			if focused and card.id=="c29302":gs.VerifiedRules.ArmorBreak.give(gs,owner,src,owner,src,2,false)
			if focused and card.id=="c29306":gs.resolution_stack.append({"kind":"lantern-extra-attack","playerIndex":owner,"sourceIndex":src,"exclude":target_id})
			var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
			gs._grant_unit_armor(u,int(options.get("shield",0)))
			gs._record("assault",{"unit":src,"bonus":bonus,"target":target_id},owner)
			gs._resolve_combat(owner,src,bonus,false,false,false,false,target_id,false,options)
		"lantern-release":
			var amount:=4+2*history(u)+int(u.get("spellPower",0));var hits:Array=[{"side":1-owner,"idx":-1}]
			for side in [owner,1-owner]:
				for idx in gs.player(side).units.size():
					var target:Dictionary=gs.player(side).units[idx]
					if int(target.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(target):hits.append({"side":side,"idx":idx})
			for i in range(hits.size()-1,-1,-1):gs.resolution_stack.append({"kind":"lantern-area-hit","playerIndex":owner,"sourceIndex":src,"victim":hits[i].side,"idx":hits[i].idx,"amount":amount,"context":gs._card_effect_context.duplicate(true)})
		_:return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind:=str(f.get("kind",""))
	if not kind.begins_with("lantern-"):return false
	if kind=="lantern-charged-cast" and gs.player(int(f.playerIndex)).units[int(f.sourceIndex)].get("lanternStored",{}).get("chargedPair",false):
		gs.VerifiedRules.ChargedPair.release(gs,int(f.playerIndex),int(f.sourceIndex));return true
	var owner:=int(f.playerIndex);var src:=int(f.sourceIndex);var u:Dictionary=gs.player(owner).units[src];var old:Dictionary=gs._card_effect_context
	gs._card_effect_context=f.get("context",{})
	match kind:
		"lantern-projectile":gs.VerifiedRules.base_damage_projectile(gs,owner,src,int(f.amount),"古笼火气绝")
		"lantern-charged-cast":
			if u.has("lanternStored") and int(u.hp)>0 and not u.get("removed",false) and not gs.VerifiedRules.Stun.blocks(gs,owner,u):
				var c:Dictionary=u.lanternStored.card.duplicate(true);u.erase("lanternStored");c.lanternReleased=true
				gs._push_card_frames(owner,str(c.id),null,c,src,0,true)
		"lantern-scatter":
			var candidates:Array=gs.player(1-owner).units.filter(func(t):return int(t.hp)>0 and not t.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(t))
			if int(f.remaining)>0 and not candidates.is_empty():
				var target:Dictionary=candidates[int(gs.next_random()%candidates.size())];var next:=f.duplicate(true);next.remaining=int(f.remaining)-1
				if int(next.remaining)>0:gs.resolution_stack.append(next)
				gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,target.uid),1,owner,src)
		"lantern-extra-attack":
			if int(u.hp)>0 and not gs.VerifiedRules.Stun.blocks(gs,owner,u):
				var candidates:Array=gs.player(1-owner).units.filter(func(t):return int(t.hp)>0 and not t.get("removed",false) and t.uid!=f.exclude and gs.VerifiedRules.OwlInsect.shikigami(t))
				if not candidates.is_empty():
					var t:Dictionary=candidates[int(gs.next_random()%candidates.size())]
					gs._resolve_combat(owner,src,0,false,false,false,false,t.uid,false,{"pursuit":true})
		"lantern-area-hit":
			if int(f.idx)<0:gs._damage_avatar(int(f.victim),int(f.amount),owner,src)
			else:gs._damage_unit(int(f.victim),int(f.idx),int(f.amount),owner,src)
	gs._card_effect_context=old;return true
static func marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx];var result:Array=[]
	if source(u):result.append("复活%d次 · 气绝投射%d · 歧路笼火%d"%[history(u),2+history(u),4+2*history(u)])
	if u.has("lanternStored"):
		var name := str(u.lanternStored.get("card", {}).get("name", "蓄力牌"))
		result.append("蓄力 · %s · 下个己方回合自动施放" % name)
	return result
static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("lanternRules",false):return null
	var u:Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.id=="c29301":return 30 if int(u.hp)<=0 else -10
	if card.id=="c29308":return 25+history(u)*3
	return 22
