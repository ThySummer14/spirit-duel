class_name KoiFragranceRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("koiFragranceRole",""))
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func extra(gs, owner: int, which: String) -> int:
	if which!="ward": return 0
	return gs.player(owner).units.filter(func(u):return active(u) and u.get("formRules",{}).get("koiExtra",false)).size()
static func dual(gs, owner: int, which: String) -> bool:
	return which=="ward" and gs.player(owner).units.any(func(u):return active(u) and u.get("formRules",{}).get("koiDouble",false))
static func queue_mark(gs, owner: int, which: String, context: Dictionary={}) -> void:
	gs.resolution_stack.append({"kind":"pair-mark","playerIndex":owner,"which":which,"context":context.duplicate(true)})
static func charmed(gs, actor: int, owner: int, inst: Dictionary, which: String) -> void:
	if which=="ward":
		var card := Content.card_def(str(inst.definitionId))
		for unit_id in Content.card_unit_ids(card):
			var idx: int = gs._source_index(owner, {"unitId": unit_id})
			if idx < 0: continue
			var target: Dictionary = gs.player(owner).units[idx]
			for u in gs.player(actor).units:
				if role(u) != "koi" or not active(u): continue
				if int(target.hp) <= 0:
					gs.VerifiedRules.reduce_countdown(gs, owner, idx, 1, actor)
				else:
					gs._grow_unit(target, 1, 1 if u.awakened else 0)
					if u.awakened:
						target.koiOrdinaryGrowth = int(target.get("koiOrdinaryGrowth", 0)) + 1
					else: target.koiTemporaryPower = int(target.get("koiTemporaryPower", 0)) + 1
				gs.VerifiedRules.event(gs, "koi-charm-growth", {"player": actor, "uid": u.uid, "target": target.uid, "awakened": bool(u.awakened)})
	else:
		for i in range(gs.player(actor).units.size()-1,-1,-1):
			var u: Dictionary=gs.player(actor).units[i]
			if role(u)=="fragrance" and active(u): gs.resolution_stack.append({"kind":"pair-projectile","playerIndex":actor,"sourceIndex":i,"amount":2 if u.awakened else 1})
		for field in gs.player(actor).realms:
			if field.get("nativeRealm")=="fragrance-pressure" and int(field.hp)>0: gs._apply_encourage(owner,-1,-1)
static func drawn(gs, owner: int) -> bool:
	var triggered:=false
	for u in gs.player(owner).units:
		if active(u) and u.get("formRules",{}).get("koiDrawWard",false) and int(u.get("koiDrawWardTurn",-1))!=gs.turn_counter:
			u.koiDrawWardTurn=gs.turn_counter; queue_mark(gs,owner,"ward"); triggered=true
	return triggered
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("koiEntryWard",false): queue_mark(gs,owner,"ward")
	if card.get("formRules",{}).get("koiEntryDraw",false): gs.resolution_stack.append({"kind":"pair-entry-draw","playerIndex":owner})
	if card.get("formRules",{}).get("fragranceTick",false): queue_mark(gs,owner,"erosion")
static func form_turn_start(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if active(u) and u.get("formRules",{}).get("fragranceTick",false): queue_mark(gs,owner,"erosion")
static func turn_start(gs, owner: int) -> void:
	for field in gs.player(owner).realms.duplicate():
		if field.get("nativeRealm")=="koi-stream" and int(field.hp)>0: queue_mark(gs,owner,"ward")
static func avatar_damage(gs, owner: int, src: int, victim: int, amount: int, combat: bool) -> void:
	if owner<0 or src<0 or owner==victim or amount<=0 or not combat: return
	for u in gs.player(owner).units:
		if active(u) and u.get("formRules",{}).get("fragranceBattleErosion",false) and int(u.get("fragranceBattleTurn",-1))!=gs.turn_counter:
			u.fragranceBattleTurn=gs.turn_counter; queue_mark(gs,owner,"erosion")
static func end_turn(gs) -> void:
	for p in gs.players:
		for u in p.units:
			var n:=int(u.get("koiTemporaryPower",0))
			if n>0: u.attackBonus=int(u.attackBonus)-n; u.erase("koiTemporaryPower"); gs._recalc(u)
static func knocked_out(u: Dictionary) -> void:
	var ordinary:=int(u.get("koiOrdinaryGrowth",0)); var temporary:=int(u.get("koiTemporaryPower",0))
	u.attackBonus=int(u.attackBonus)-ordinary-temporary; u.maxHpBonus=int(u.maxHpBonus)-ordinary
	u.erase("koiTemporaryPower"); u.erase("koiOrdinaryGrowth")
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("koiFragranceRules",false): return null
	if card.get("target","auto")=="auto": return null
	var ids: Array=[]
	for side in [owner,1-owner] if card.get("target")=="any-unit" else [1-owner]:
		for u in gs.player(side).units:
			if int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side==owner or not (gs.VerifiedRules.Combat.has(u,"veil") or gs.VerifiedRules.Movement.has_veil(u))): ids.append(u.uid)
	return ids
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("koiFragranceRules",false): return true
	if card.id not in ["c28206","c28805"]: return true
	var idx: int=gs._source_index(owner,card)
	return idx>=0 and not gs.player(owner).units[idx].awakened
static func has_playable_erosion(gs, owner: int) -> bool:
	for i in gs.player(owner).hand.size():
		if gs.VerifiedRules.HandBlessing.kind(gs.player(owner).hand[i])!="erosion": continue
		var c: Dictionary=gs.hand_card_def(owner,i)
		for target in [null] if c.get("target","auto")=="auto" else gs.valid_targets(owner,c):
			if gs.can_play_card(owner,i,target,false,true).ok: return true
	return false
static func restricted(gs, owner: int, card: Dictionary) -> bool:
	if card.get("handCharm",{}).get("kind")=="erosion": return false
	var enabled: bool=gs.player(1-owner).units.any(func(u):return active(u) and u.get("formRules",{}).get("fragranceForce",false) and int(u.get("fragranceForceTurn",-1))!=gs.turn_counter)
	return enabled and has_playable_erosion(gs,owner)
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.get("handCharm",{}).get("kind")!="erosion": return
	for u in gs.player(1-int(frame.playerIndex)).units:
		if active(u) and u.get("formRules",{}).get("fragranceForce",false): u.fragranceForceTurn=gs.turn_counter
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]; var result: Array=[]
	if role(u)=="koi": result.append("己方手牌加护 · "+("对应式神+1/+1，气绝倒计时-1" if u.awakened else "对应式神本回合+1力量，或气绝倒计时-1"))
	if role(u)=="fragrance": result.append("敌方手牌被蚀印 · 投射%d"%(2 if u.awakened else 1))
	if int(u.get("koiTemporaryPower",0))>0: result.append("加护成长 · 本回合+%d力量"%int(u.koiTemporaryPower))
	if u.get("formRules",{}).get("fragranceForce",false): result.append("本回合首个可用蚀印牌限制 · "+("已解除" if int(u.get("fragranceForceTurn",-1))==gs.turn_counter else "待触发"))
	return result
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, _target_id) -> bool:
	match str(effect.get("action","")):
		"pair-ward": gs.VerifiedRules.HandBlessing.start(gs,owner,"ward")
		"pair-erosion": gs.VerifiedRules.HandBlessing.start(gs,owner,"erosion",card.get("erosionAfter",{}))
		"pair-count-heal":
			var amount: int=gs.player(owner).hand.filter(func(i):return gs.VerifiedRules.HandBlessing.kind(i)=="ward").size()
			gs._heal_avatar(owner,amount)
		"pair-awaken": gs._awaken(owner,src,card,{"attack":1,"hp":1})
		"pair-koi-realm": gs._deploy_realm(owner,card); gs.VerifiedRules.HandBlessing.start(gs,owner,"ward")
		"pair-fragrance-realm": gs._deploy_realm(owner,card); gs.VerifiedRules.HandBlessing.start(gs,owner,"erosion")
		"damage":
			if card.get("id") != "c28807": return false
			for idx in gs.player(1-owner).units.size():
				var u: Dictionary = gs.player(1-owner).units[idx]
				if int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u):
					gs._damage_unit(1-owner,idx,int(effect.value),owner,src)
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""))
	if not kind.begins_with("pair-"): return false
	var owner:=int(frame.playerIndex)
	match kind:
		"pair-mark": gs.VerifiedRules.HandBlessing.start(gs,owner,str(frame.which),frame.get("context",{}))
		"pair-entry-draw": gs._draw(owner,1)
		"pair-projectile":
			var ctx: Dictionary=gs._card_effect_context; gs._card_effect_context={}
			var idx: int=gs.front_index(1-owner); var amount:=0; var src:=int(frame.sourceIndex)
			if idx<0: amount=gs.VerifiedRules.base_damage_avatar(gs,owner,src,1-owner,int(frame.amount))
			else: amount=int(gs.VerifiedRules.base_damage_unit(gs,owner,src,1-owner,idx,int(frame.amount)).get("damage",0))
			gs._card_effect_context=ctx
			gs.VerifiedRules.event(gs,"fragrance-projectile",{"player":owner,"uid":gs.player(owner).units[src].uid,"victimPlayer":1-owner,"target":"" if idx<0 else gs.player(1-owner).units[idx].uid,"amount":amount,"blocked":amount==0,"card":{"id":"fragrance-ability","type":"ability","unitId":"xunxiangxing","name":"蚀印投射"}})
		"pair-after-mark":
			match str(frame.context.get("after","")):
				"stun":
					var c:={"unitId":str(frame.unitId)}; var idx: int=gs._source_index(1-owner,c)
					gs.VerifiedRules.Stun.apply(gs,1-owner,idx if idx>=0 and int(gs.player(1-owner).units[idx].hp)>0 else -1,1,owner)
				"discard":
					var kept: Array=[]
					for inst in gs.player(1-owner).hand:
						if str(inst.instanceId) in frame.offeredIds and str(inst.instanceId)!=str(frame.selectedId): gs.VerifiedRules.event(gs,"fragrance-discard",{"player":owner,"instanceId":inst.instanceId,"card":inst.definitionId})
						else: kept.append(inst)
					gs.player(1-owner).hand=kept
		_: return false
	return true
static func score_card(gs, owner: int, card: Dictionary, _target):
	if not card.get("koiFragranceRules",false): return null
	if card.type=="form": return -50 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 75
	return 90 if card.id in ["c28206","c28805"] else 65
