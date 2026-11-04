class_name FoxLotusRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("foxLotusRole",""))

static func marked(u: Dictionary, owner: int = -1) -> bool:
	var charm: Dictionary=u.get("lotusCharm",{})
	return not charm.is_empty() and (owner<0 or int(charm.owner)==owner)

static func marked_target(gs, owner: int) -> Dictionary:
	for u in gs.player(1-owner).units:
		if int(u.hp)>0 and marked(u,owner): return u
	return {}

static func penalty(gs, u: Dictionary) -> int:
	if not marked(u) or u.get("baseRulesSuppressed",false): return 0
	return 1+int(gs.player(int(u.lotusCharm.owner)).get("lotusDebuff",0))

static func remove_charm(gs, u: Dictionary) -> void:
	u.erase("lotusCharm"); gs._recalc(u)

static func attach(gs, owner: int, src: int, target: Dictionary) -> void:
	if target.is_empty() or int(target.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(target): return
	for side in gs.players:
		for u in side.units:
			if marked(u,owner): remove_charm(gs,u)
	target.lotusCharm={"owner":owner,"sourceUid":gs.player(owner).units[src].uid}
	gs._recalc(target)
	gs.VerifiedRules.event(gs,"lotus-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":target.uid})

static func prevents_damage(gs, owner: int, src: int) -> bool:
	if owner<0 or src<0 or src>=gs.player(owner).units.size(): return false
	var u: Dictionary=gs.player(owner).units[src]
	if not marked(u) or u.get("baseRulesSuppressed",false): return false
	return gs.player(int(u.lotusCharm.owner)).realms.any(func(r):return int(r.hp)>0 and r.get("nativeRealm")=="lotus-ideal")

static func projectile(gs, owner: int, src: int, amount: int) -> void:
	var idx: int=gs.front_index(1-owner)
	if idx<0: gs._damage_avatar(1-owner,amount,owner,src)
	else: gs._damage_unit(1-owner,idx,amount,owner,src)

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("foxLotusRules",false): return card
	var out:=card.duplicate(true)
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.get("foxDamage",false):
		var amount:=int(card.foxBaseDamage)+int(u.get("foxSpellBonus",0))
		out.value=amount; out.currentCardStats="当前伤害%d" % amount
		out.text+="\n当前法伤增强+%d，本牌伤害%d。" % [int(u.get("foxSpellBonus",0)),amount]
	elif card.get("type")=="form": out.currentCardStats="当前%d/%d" % [int(card.value.attack),int(card.value.hp)]
	return out

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("foxLotusRules",false) or card.get("target")!="enemy-unit": return null
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))

static func automatic_targets(gs, owner: int, card: Dictionary, targets: Array) -> Array:
	var selected: Array=[]
	if card.get("lotusGrace",false) or card.get("effect")=="lotus-boon":
		selected=targets.filter(func(id):return not marked(gs._unit_by_uid(gs.player(1-owner).units,str(id)),owner))
		if not selected.is_empty():
			var front: Dictionary=gs.front_unit(1-owner)
			if not front.is_empty() and selected.has(front.uid): return [front.uid]
	elif card.get("effect")=="lotus-judgement":
		selected=targets.filter(func(id):return marked(gs._unit_by_uid(gs.player(1-owner).units,str(id)),owner))
	return targets if selected.is_empty() else selected

static func insert_after_card(gs, frame: Dictionary, after: Dictionary) -> void:
	for i in gs.resolution_stack.size():
		var pending: Dictionary=gs.resolution_stack[i]
		if pending.get("kind")=="card-complete" and int(pending.get("resolutionId",-1))==int(frame.resolutionId):
			gs.resolution_stack.insert(i,after); return

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex)
	var source: Dictionary=gs.player(owner).units[src]
	if role(source)=="fox" and active(source) and frame.get("automatic",false):
		insert_after_card(gs,frame,{"kind":"lotus-fox-projectile","playerIndex":owner,"sourceIndex":src,"amount":3 if source.awakened else 2})
	if card.get("type")!="spell": return
	var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(frame.get("targetId","")))
	var affects_enemy: bool=not target.is_empty() and gs.VerifiedRules.OwlInsect.shikigami(target)
	if not affects_enemy:
		for effect in card.get("effects",[]):
			if effect.get("target") in ["all-enemy-units","all-enemies"]: affects_enemy=true
	if not affects_enemy: return
	var observers: Array=[]
	for i in gs.player(owner).units.size():
		var observer: Dictionary=gs.player(owner).units[i]
		if not active(observer): continue
		var form: Dictionary=observer.get("formRules",{})
		if form.get("lotusMercy",false) and (marked(target,owner) or (target.is_empty() and not marked_target(gs,owner).is_empty())) and int(observer.get("lotusMercyTurn",-1))!=gs.turn_counter:
			observer.lotusMercyTurn=gs.turn_counter
			observers.append({"kind":"mercy","sourceIndex":i,"sourceUid":observer.uid})
		if form.get("lotusSaint",false) and not card.get("lotusCopied",false):
			if int(observer.get("lotusSaintTurn",-1))!=gs.turn_counter and not marked_target(gs,owner).is_empty():
				observer.lotusSaintTurn=gs.turn_counter
				observers.append({"kind":"saint","sourceIndex":i,"sourceUid":observer.uid})
	if not observers.is_empty(): insert_after_card(gs,frame,{"kind":"lotus-after-spell","playerIndex":owner,"sourceIndex":src,"card":card.duplicate(true),"observers":observers})

static func generated_fox(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or gs.VerifiedRules.Stun.blocks(gs,owner,u): return
	var pool: Array=Content.cards_for_unit(str(u.id)).filter(func(c):return c.get("type")=="spell" and int(c.level)==1)
	pool=pool.filter(func(c):return c.get("target","auto")=="auto" or not gs.valid_targets(owner,c).is_empty())
	if pool.is_empty(): return
	var card: Dictionary=pool[int(floor(gs.randf01()*pool.size()))].duplicate(true)
	var target=gs.VerifiedRules.SpellReplay.random_target(gs,owner,card)
	gs._push_card_frames(owner,str(card.id),target,card,src,0,true)
	gs.VerifiedRules.event(gs,"fox-generated-spell",{"player":owner,"uid":u.uid,"card":card,"target":target})

static func knocked_out(gs, victim: int, u: Dictionary) -> void:
	u.erase("lotusCharm")
	if not gs.VerifiedRules.OwlInsect.shikigami(u): return
	for owner in gs.players.size():
		if owner==victim: continue
		for realm in gs.player(owner).realms:
			if int(realm.hp)<=0 or realm.get("nativeRealm")!="fox-dream" or int(realm.get("foxUsedTurn",-1))==gs.turn_counter: continue
			var src: int=gs._source_index(owner,{"unitId":realm.sourceUnit})
			if src<0 or not active(gs.player(owner).units[src]) or gs.VerifiedRules.Stun.blocks(gs,owner,gs.player(owner).units[src]): continue
			realm.foxUsedTurn=gs.turn_counter
			gs.resolution_stack.append({"kind":"lotus-fox-random","playerIndex":owner,"sourceIndex":src})

static func end_turn(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if not active(u): continue
		if u.get("formRules",{}).get("lotusKing",false):
			var target:=marked_target(gs,owner)
			if not target.is_empty(): gs.resolution_stack.append({"kind":"lotus-king-hit","playerIndex":owner,"sourceIndex":src,"targetUid":target.uid})

static func after_stun_end(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		var u: Dictionary=gs.player(owner).units[src]
		if active(u) and role(u)=="fox" and u.awakened and not gs.VerifiedRules.Stun.blocks(gs,owner,u):
			gs.resolution_stack.append({"kind":"lotus-fox-random","playerIndex":owner,"sourceIndex":src})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var source: Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"fox-damage":
			var amount:=int(card.foxBaseDamage)+int(source.get("foxSpellBonus",0))
			var mode:=str(card.foxDamageMode)
			if mode=="random":
				for i in amount: gs.resolution_stack.append({"kind":"lotus-fox-random-hit","playerIndex":owner,"sourceIndex":src,"context":gs._card_effect_context})
			elif mode=="projectile": projectile(gs,owner,src,amount)
			elif not target.is_empty() and int(target.hp)>0:
				var idx: int=gs._unit_index_by_uid(1-owner,str(target.uid))
				if idx>=0: gs._damage_unit(1-owner,idx,amount,owner,src)
		"fox-bonus-hand":
			if not gs._card_effect_context.get("automatic",false):
				source.foxSpellBonus=int(source.get("foxSpellBonus",0))+1
				gs.VerifiedRules.event(gs,"fox-spell-bonus",{"player":owner,"uid":source.uid,"amount":source.foxSpellBonus})
		"fox-random-spell": generated_fox(gs,owner,src)
		"lotus-grace":
			attach(gs,owner,src,target)
			if not gs._card_effect_context.get("automatic",false): gs._draw(owner,1)
		"lotus-boon":
			attach(gs,owner,src,target)
			gs.player(owner).lotusDebuff=int(gs.player(owner).get("lotusDebuff",0))+1
			for side in gs.players:
				for u in side.units:
					if marked(u,owner): gs._recalc(u)
		"lotus-judgement":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid","")))
			if idx>=0:
				if marked(target,owner): gs.VerifiedRules.Panguan.destroy(gs,owner,src,1-owner,idx,card)
				else: gs._damage_unit(1-owner,idx,4,owner,src)
		"lotus-awaken": gs._awaken(owner,src,card,card.value); attach(gs,owner,src,target)
		_: return false
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind:=str(f.get("kind",""))
	if not kind.begins_with("lotus-"): return false
	var owner:=int(f.playerIndex); var src:=int(f.sourceIndex)
	var context: Dictionary=gs._card_effect_context
	gs._card_effect_context=f.get("context",{}) if kind=="lotus-fox-random-hit" else {}
	match kind:
		"lotus-fox-random": generated_fox(gs,owner,src)
		"lotus-fox-projectile": gs.VerifiedRules.base_damage_projectile(gs,owner,src,int(f.amount),"玉藻前非手牌用牌")
		"lotus-fox-random-hit":
			var pool: Array=[-1]
			for i in gs.player(1-owner).units.size():
				if int(gs.player(1-owner).units[i].hp)>0: pool.append(i)
			var idx: int=pool[int(floor(gs.randf01()*pool.size()))]
			if idx<0: gs._damage_avatar(1-owner,1,owner,src)
			else: gs._damage_unit(1-owner,idx,1,owner,src)
		"lotus-king-hit":
			var idx: int=gs._unit_index_by_uid(1-owner,str(f.targetUid))
			if idx>=0: gs._damage_unit(1-owner,idx,2,owner,src)
		"lotus-after-spell":
			for i in range(f.observers.size()-1,-1,-1):
				var observer: Dictionary=f.observers[i]
				var u: Dictionary=gs.player(owner).units[int(observer.sourceIndex)]
				if u.uid!=observer.sourceUid: continue
				if observer.kind=="mercy":
					gs._set_fire(owner,int(gs.player(owner).energy)+1); gs._draw(owner,1)
					gs.VerifiedRules.event(gs,"lotus-mercy",{"player":owner,"uid":u.uid})
				else:
					var target:=marked_target(gs,owner)
					var card: Dictionary=f.card.duplicate(true)
					if target.is_empty() or (card.get("target","auto")!="auto" and not gs.valid_targets(owner,card).has(target.uid)): continue
					card.lotusCopied=true; card.crabReturn=false
					card.paintReturn=false; card.erase("paintInstance")
					card.pineReturn=false; card.erase("pineInstance")
					card.keywords=card.get("keywords",[]).filter(func(k):return str(k).to_lower()!="bounce")
					gs._push_card_frames(owner,str(card.id),null if card.get("target","auto")=="auto" else target.uid,card,src,0,true)
					gs.VerifiedRules.event(gs,"lotus-spell-copy",{"player":owner,"uid":u.uid,"casterUid":gs.player(owner).units[src].uid,"target":target.uid,"card":card})
	gs._card_effect_context=context
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("foxLotusRules",false): return null
	var source: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
	if card.get("type")=="awakening": return 75 if not source.awakened else -100
	if card.get("type")=="form": return 52 if source.get("form",{}).get("cardId")!=card.id else -20
	if card.get("effect")=="lotus-judgement": return 85+maxi(0,int(target.get("attack",0)))*3 if marked(target,owner) else 45
	if card.get("lotusGrace",false): return 45+maxi(0,int(target.get("attack",0)))*2 if not marked(target,owner) else 15
	return 55
