class_name PuppetRules
extends RefCounted
## A fusion creates one carrier, preserving its real instance and the old form's
## statistics, statuses and distinct abilities. Absorption is not removal.
const Content := preload("res://scripts/content_loader.gd")
const AWAKEN_FORM := "puppet-awaken-form"
const FORM_IDS := ["c23102","c23103","c23104","c23105","c23108"]
static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("puppetRules",false))
static func active(u: Dictionary) -> bool:
	return source(u) and int(u.hp)>0 and int(u.level)>0
static func base_bonus(u: Dictionary) -> int:
	return 3 if source(u) and not u.awakened and not u.get("form",{}).is_empty() else 0
static func components(u: Dictionary) -> Array:
	return u.get("form",{}).get("puppetInstance",{}).get("puppetComponents",[])
static func _growth(gs, owner: int) -> int:
	return int(gs.player(owner).get("puppetCardGrowth",0))
static func _instance(card: Dictionary) -> Dictionary:
	return card.get("puppetInstance",{}).duplicate(true)
static func _body(entry: Dictionary, card: Dictionary, growth: int) -> Dictionary:
	var v: Dictionary=card.get("value",{})
	var delta:=growth-int(entry.get("puppetGrowthApplied",0))
	return {"attack":int(entry.get("puppetAttack",v.get("attack",0)))+delta,"hp":int(entry.get("puppetHp",v.get("hp",0)))+delta,"setBase":true}
static func describe_card(gs, owner: int, entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("puppetRules",false): return card
	var out:=card.duplicate(true)
	out.puppetInstance=entry.duplicate(true)
	if card.get("type")=="form":
		out.value=_body(entry,card,_growth(gs,owner))
		out.effects[0].value=out.value.duplicate(true)
		out.puppetFree=int(entry.get("puppetFreeTurn",-1))==gs.turn_counter
		out.currentCardStats="当前%d/%d · 已融合%d次 · %d种形态%s" % [int(out.value.attack),int(out.value.hp),int(entry.get("puppetFusionCount",0)),entry.get("puppetComponents",[card.id]).size()," · 牵丝：本回合免鬼火" if out.puppetFree else ""]
		if entry.has("puppetComponents"):
			out.text=str(out.text)+"\n融合继承："+_names(entry.puppetComponents)+"\n"+_abilities_text(entry.puppetComponents)
		if out.puppetFree: out.text=str(out.text)+"\n牵丝：仅此实例本回合不消耗鬼火。"
	return out
static func _names(ids: Array) -> String:
	var names:=PackedStringArray()
	for id in ids: names.append("觉醒·傀儡术" if id==AWAKEN_FORM else str(Content.card_def(id).get("name",id)))
	return "、".join(names)
static func _abilities_text(ids: Array) -> String:
	var lines:=PackedStringArray()
	for id in ids:
		match str(id):
			"c23102":lines.append("融合完成时：投射造成3点伤害。")
			"c23103":lines.append("融合完成时：获得屏障。")
			"c23104":lines.append("融合完成时：抽一张牌。")
			"c23105":lines.append("融合完成时：获得迅捷。")
			"c23108":lines.append("贯通。融合完成时：傀儡师所有形态牌永久+1力量/+1生命。")
			AWAKEN_FORM:lines.append("觉醒·傀儡术永久结附；己方回合开始时，若融合6种形态，随机敌方角色10伤×6。")
	return "\n".join(lines)
static func prepare_form(gs, owner: int, src: int, card: Dictionary, value: Dictionary = {}) -> Dictionary:
	if not card.get("puppetRules",false) or card.get("type")!="form": return {"card":card,"value":value}
	var u: Dictionary=gs.player(owner).units[src]
	var out:=card.duplicate(true);var entry:=_instance(card)
	if entry.is_empty():
		entry={"definitionId":card.id,"instanceId":"puppet-form-%d" % gs.next_card_id};gs.next_card_id+=1
	var body: Dictionary=card.get("value",{}).duplicate(true) if value.is_empty() else value.duplicate(true)
	var parts: Array=entry.get("puppetComponents",[card.id]).duplicate()
	var count:=int(entry.get("puppetFusionCount",0))
	var old: Dictionary=u.get("form",{}).get("puppetInstance",{})
	var fused:=not old.is_empty()
	if fused:
		body.attack=int(body.get("attack",0))+int(old.get("puppetAttack",0))
		body.hp=int(body.get("hp",0))+int(old.get("puppetHp",0))
		count+=int(old.get("puppetFusionCount",0))+1
		# Keep the inherited order, and merge equal abilities only once.
		var merged: Array=old.puppetComponents.duplicate()
		for id in parts:
			if not merged.has(id): merged.append(id)
		parts=merged
	entry.puppetComponents=parts;entry.puppetFusionCount=count
	entry.puppetAttack=int(body.get("attack",0));entry.puppetHp=int(body.get("hp",0));entry.puppetGrowthApplied=_growth(gs,owner)
	entry.erase("puppetFreeTurn")
	out.puppetInstance=entry;out.puppetFusion=fused;out.value=body;out.value.setBase=true
	out.formRules={"puppetFusion":true,"combatKeywords":["pierce"] if parts.has("c23108") else []}
	out.formHooks=[];out.formAbility="融合%d次 · %d种形态：%s。\n%s" % [count,parts.size(),_names(parts),_abilities_text(parts)]
	return {"card":out,"value":out.value}
static func form_installed(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("puppetRules",false) or card.get("type")!="form": return
	var u: Dictionary=gs.player(owner).units[src]
	u.form.puppetInstance=_instance(card)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("puppetRules",false) or card.get("type")!="form": return
	var u: Dictionary=gs.player(owner).units[src]
	gs.VerifiedRules.event(gs,"puppet-form-entered",{"player":owner,"uid":u.uid,"instanceId":u.form.puppetInstance.instanceId,"fusion":bool(card.get("puppetFusion",false)),"count":int(u.form.puppetInstance.puppetFusionCount),"components":components(u).duplicate()})
	if not card.get("puppetFusion",false): return
	# Each acquired ability triggers once, even if several equal form cards were fused.
	var abilities: Array=components(u).duplicate();abilities.reverse()
	for id in abilities:
		if id==AWAKEN_FORM: continue
		gs.resolution_stack.append({"kind":"puppet-fusion-ability","playerIndex":owner,"sourceIndex":src,"ability":id})
static func form_removed(gs, owner: int, src: int, returning_to_deck: bool = false) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	var entry: Dictionary=u.get("form",{}).get("puppetInstance",{})
	if entry.is_empty(): return
	if not returning_to_deck and (str(entry.get("definitionId",""))!=AWAKEN_FORM or entry.get("puppetComponents",[]).size()>1):
		if not gs.player(owner).has("puppetRemoved"): gs.player(owner).puppetRemoved=[]
		gs.player(owner).puppetRemoved.append(entry.duplicate(true))
		gs.VerifiedRules.event(gs,"puppet-form-removed",{"player":owner,"uid":u.uid,"instanceId":entry.instanceId,"count":entry.puppetFusionCount})
	if u.awakened: gs.resolution_stack.append({"kind":"puppet-restore","playerIndex":owner,"sourceIndex":src})
static func _awake_card(gs, owner: int) -> Dictionary:
	var entry: Dictionary={"definitionId":AWAKEN_FORM,"instanceId":"puppet-permanent-%d"%gs.next_card_id,"puppetComponents":[AWAKEN_FORM],"puppetFusionCount":0,"puppetGrowthApplied":_growth(gs,owner)}
	gs.next_card_id+=1
	# The permanent awakening form's printed body is 3/3. It replaces the
	# unawakened conditional 3/3 bonus, rather than retaining the old passive.
	var body: Dictionary={"attack":3,"hp":3,"setBase":true}
	return {"id":AWAKEN_FORM,"unitId":"kuileishi","name":"觉醒·傀儡术","type":"form","verifiedRules":true,"puppetRules":true,"puppetInstance":entry,"value":body,"text":"融合。永久结附。","formAbility":"融合。永久结附。","formRules":{"puppetFusion":true},"formHooks":[]}
static func restore(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or not u.awakened or components(u).has(AWAKEN_FORM): return
	gs._apply_form(owner,src,_awake_card(gs,owner))
static func revived(gs, owner: int, idx: int) -> void:
	restore(gs,owner,idx)
static func _random_damage(gs, owner: int, src: int, amount: int, projectile: bool) -> void:
	if gs.winner>=0: return
	var enemy:=1-owner;var idx: int=gs.front_index(enemy)
	if not projectile:
		var pool: Array=[-1]
		for n in gs.player(enemy).units.size():
			if int(gs.player(enemy).units[n].hp)>0: pool.append(n)
		idx=int(pool[int(floor(gs.randf01()*pool.size()))])
	amount+=gs.VerifiedRules.Maple.damage_bonus(gs,owner,src,false)
	var overflow:=0
	if idx<0: gs._damage_avatar(enemy,amount,owner,src,false,false,true)
	else:
		var target: Dictionary=gs.player(enemy).units[idx]
		if components(gs.player(owner).units[src]).has("c23108") and not target.get("bloodTransfer",false) and not gs.VerifiedRules.OniAsura.will_transfer(gs,target):
			overflow=maxi(0,gs.VerifiedRules.OwlInsect.reduced(target,maxi(0,amount+int(target.armorBreak)-int(target.shield)))-int(target.hp))
		var result: Dictionary=gs._damage_unit(enemy,idx,amount,owner,src,false,-1,false,false,true)
		if result.get("redirected",false) or result.has("transferredDealt"): overflow=0
		if overflow>0 and gs.winner<0: gs._damage_avatar(enemy,overflow,owner,src,false,false,true)
	gs.VerifiedRules.event(gs,"puppet-projectile" if projectile else "puppet-awake-hit",{"player":owner,"uid":gs.player(owner).units[src].uid,"targetIndex":idx,"amount":amount,"overflow":overflow})
static func turn_start(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if not active(u) or not u.awakened: continue
		restore(gs,owner,src)
		if components(u).size()<6: continue
		gs.resolution_stack.append({"kind":"puppet-awake-hit","playerIndex":owner,"sourceIndex":src,"remaining":6})
static func _wire(gs, owner: int) -> void:
	var p: Dictionary=gs.player(owner);var removed: Array=p.get("puppetRemoved",[])
	if removed.is_empty(): return
	var most:=-1;var pool: Array=[]
	for i in removed.size():
		var count:=int(removed[i].get("puppetFusionCount",0))
		if count>most: most=count;pool.clear()
		if count==most:pool.append(i)
	var idx: int=pool[int(floor(gs.randf01()*pool.size()))]
	var entry: Dictionary=removed.pop_at(idx)
	if p.hand.size()<int(gs.rules.maxHandSize): p.hand.append(entry)
	gs.VerifiedRules.event(gs,"puppet-wired",{"player":owner,"instanceId":entry.instanceId,"count":most,"burned":p.hand.size()>=int(gs.rules.maxHandSize) and not p.hand.has(entry)})
static func _thread(gs, owner: int) -> void:
	var p: Dictionary=gs.player(owner)
	for n in 2:
		var pool: Array=[]
		for idx in p.deck.size():
			if FORM_IDS.has(str(p.deck[idx].definitionId)): pool.append(idx)
		if pool.is_empty(): break
		var idx: int=pool[int(floor(gs.randf01()*pool.size()))]
		var entry: Dictionary=p.deck.pop_at(idx)
		entry.puppetFreeTurn=gs.turn_counter
		if p.hand.size()<int(gs.rules.maxHandSize): p.hand.append(entry)
		gs.VerifiedRules.event(gs,"puppet-thread-draw",{"player":owner,"instanceId":entry.instanceId,"card":Content.card_def(entry.definitionId)})
static func targets(_gs, _owner: int, _card: Dictionary): return null
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("puppetRules",false): return true
	var src: int=gs._source_index(owner,card)
	return src>=0 and not (card.get("type")=="awakening" and gs.player(owner).units[src].awakened)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, _target_id) -> bool:
	match str(effect.get("action","")):
		"puppet-wire": _wire(gs,owner)
		"puppet-thread": _thread(gs,owner)
		"puppet-awaken":
			var u: Dictionary=gs.player(owner).units[src]
			var wounds:=maxi(0,int(u.maxHp)-int(u.hp))
			gs._awaken(owner,src,card,{"attack":0,"hp":0})
			restore(gs,owner,src)
			if int(u.hp)>0: u.hp=maxi(1,int(u.maxHp)-wounds)
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""));var owner:=int(frame.get("playerIndex",0));var src:=int(frame.get("sourceIndex",-1))
	match kind:
		"puppet-restore":restore(gs,owner,src)
		"puppet-awake-hit":
			if gs.winner>=0: return true
			if int(frame.remaining)>1:gs.resolution_stack.append({"kind":kind,"playerIndex":owner,"sourceIndex":src,"remaining":int(frame.remaining)-1})
			_random_damage(gs,owner,src,10,false)
		"puppet-fusion-ability":
			var u: Dictionary=gs.player(owner).units[src]
			match str(frame.ability):
				"c23102": _random_damage(gs,owner,src,3,true)
				"c23103":
					if int(u.hp)>0: u.barrier=true
				"c23104": gs._draw(owner,1)
				"c23105":
					if int(u.hp)>0: u.swift=true
				"c23108":gs.player(owner).puppetCardGrowth=_growth(gs,owner)+1
			gs.VerifiedRules.event(gs,"puppet-fusion-ability",{"player":owner,"uid":u.uid,"ability":frame.ability})
		_: return false
	return true
static func score_card(gs, owner: int, card: Dictionary, _target):
	if not card.get("puppetRules",false): return null
	var src: int=gs._source_index(owner,card);var u: Dictionary=gs.player(owner).units[src]
	if card.get("type")=="awakening":return 85 if not u.awakened else -100
	if card.get("type")=="form":
		var score:=65+components(u).size()*4
		if not components(u).has(card.id):score+=20
		if card.id=="c23104":score+=15
		return score
	if card.get("effect")=="puppet-wire":return 65 if not gs.player(owner).get("puppetRemoved",[]).is_empty() else -100
	if card.get("effect")=="puppet-thread":return 80 if gs.player(owner).deck.any(func(entry):return FORM_IDS.has(entry.definitionId)) else -100
	return 30
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]
	if not source(u):return []
	var marks: Array=[]
	if not components(u).is_empty():marks.append("融合%d次 · %d/6种形态：%s" % [int(u.form.puppetInstance.puppetFusionCount),components(u).size(),_names(components(u))])
	if u.awakened:marks.append("觉醒·傀儡术永久结附 · 集齐6种后己方回合开始10伤×6")
	marks.append("形态永久成长+%d/+%d · 已移除形态%d" % [_growth(gs,owner),_growth(gs,owner),gs.player(owner).get("puppetRemoved",[]).size()])
	return marks
