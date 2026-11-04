class_name OniAsuraRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("baseRulesSuppressed",false)

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("oniAsuraRole",""))

static func drawn(gs, owner: int, inst: Dictionary) -> void:
	if gs.opening_deal: return
	var p: Dictionary=gs.player(owner)
	var definition: Dictionary=Content.card_def(str(inst.definitionId))
	if definition.get("oniDrawInstant",false) or definition.get("oniDrawLethal",false) or definition.get("oniDrawUnyielding",false): inst.drawnTurn=gs.turn_counter
	p.oniDrawCounter=int(p.get("oniDrawCounter",0))+1
	if not p.has("oniDrawHistory"): p.oniDrawHistory=[]
	p.oniDrawHistory.append({"count":p.oniDrawCounter,"card":inst.definitionId})
	if p.oniDrawHistory.size()>64: p.oniDrawHistory.pop_front()
	if int(p.get("oniFirstDrawTurn",-1))==gs.turn_counter: return
	p.oniFirstDrawTurn=gs.turn_counter; p.oniFirstDrawCard=inst.definitionId
	for idx in p.units.size():
		if active(p.units[idx]) and role(p.units[idx])=="oni": gs.resolution_stack.append({"kind":"oni-first-draw","playerIndex":owner,"sourceIndex":idx})

static func drawn_card(gs, owner: int, before: int) -> String:
	for entry in gs.player(owner).get("oniDrawHistory",[]):
		if int(entry.count)==before+1: return str(entry.card)
	return ""

static func own_card(id: String, u: Dictionary) -> bool:
	return Content.card_def(id).get("unitId")==u.id

static func impulse(gs, owner: int, src: int) -> void:
	var p: Dictionary=gs.player(owner); var u: Dictionary=p.units[src]
	if not active(u) or not u.get("formRules",{}).get("oniImpulse",false) or int(p.get("oniFirstDrawTurn",-1))!=gs.turn_counter or not own_card(str(p.get("oniFirstDrawCard","")),u): return
	var installed := int(u.get("formInstalledOrder",-1))
	if int(u.get("oniImpulseOrder",-2))==installed and int(u.get("oniImpulseTurn",-1))==gs.turn_counter: return
	u.oniImpulseOrder=installed; u.oniImpulseTurn=gs.turn_counter
	if int(u.frozen)>0: return
	gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"immuneCombat":true,"oniAutomatic":true})

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary=gs.player(owner)
	for u in p.units:
		if not active(u) or role(u)!="oni" or p.deck.is_empty(): continue
		if own_card(str(p.deck.back().definitionId),u):
			if u.awakened:
				u.permanentAttack=int(u.get("permanentAttack",0))+1; u.oniPermanentHp=int(u.get("oniPermanentHp",0))+1
				gs._grow_unit(u,0,1)
				gs.VerifiedRules.event(gs,"oni-permanent-growth",{"player":owner,"uid":u.uid})
		else:
			var entry: Dictionary=p.deck.pop_back(); p.deck.push_front(entry)
			gs.VerifiedRules.event(gs,"oni-deck-bottom",{"player":owner,"uid":u.uid,"instanceId":entry.instanceId})

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("oniAsuraRules",false): return card
	var out := card.duplicate(true)
	out.oniHandInstance=inst.duplicate(true)
	var enhanced: bool=int(inst.get("drawnTurn",-1))==gs.turn_counter
	if card.get("oniDrawInstant",false) and enhanced: out.keywords.append("instant")
	if card.get("oniDrawLethal",false) and enhanced: out.combatOption.lethal=true; out.enhanced=true
	if card.get("oniDrawUnyielding",false) and enhanced: out.formRules.oniEntryUnyielding=true; out.enhanced=true
	if card.get("formRules",{}).get("oniGuide",false):
		var count := int(gs.player(owner).get("oniGuideGrowth",0))
		out.value.attack=3+2*count; out.value.hp=6+count; out.effects[0].value=out.value.duplicate(true)
		out.text+="\n同名牌已成长%d次，当前%d/%d。" % [count,out.value.attack,out.value.hp]
	if card.get("asuraBloodInstant",false) and int(gs.player(owner).get("asuraSelfDamageTurn",-1))==gs.turn_counter: out.keywords.append("instant")
	if card.get("effect")=="asura-break":
		var src: int=gs._source_index(owner,card)
		out.text+="\n本次复活后依次结算%d次2点己方伤害。" % (1+int(gs.player(owner).units[src].knockout))
	return out

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("oniAsuraRules",false): return
	var u: Dictionary=gs.player(owner).units[src]
	u.oniFormInstance=card.get("oniHandInstance",{}).duplicate(true)
	if card.get("formRules",{}).get("oniEntryUnyielding",false): u.unyielding=true
	if card.get("formRules",{}).get("oniImpulse",false): gs.resolution_stack.append({"kind":"oni-first-draw","playerIndex":owner,"sourceIndex":src})
	if card.get("formRules",{}).get("asuraEntryDamage",0)>0: self_damage(gs,owner,src,int(card.formRules.asuraEntryDamage))

static func form_removed(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if u.get("formRules",{}).get("oniGuide",false):
		var entry: Dictionary=u.get("oniFormInstance",{}).duplicate(true)
		if entry.is_empty(): entry={"definitionId":u.form.cardId,"instanceId":"oni-guide-%d" % gs.next_card_id}; gs.next_card_id+=1
		gs.player(owner).oniGuideGrowth=int(gs.player(owner).get("oniGuideGrowth",0))+1
		gs.player(owner).deck.append(entry); gs._shuffle(gs.player(owner).deck)
		gs.VerifiedRules.BondDream.refresh(gs)
		gs.VerifiedRules.event(gs,"oni-guide-return",{"player":owner,"uid":u.uid,"instanceId":entry.instanceId,"growth":gs.player(owner).oniGuideGrowth})
	u.erase("oniFormInstance")

static func knockout_snapshot(gs, victim: int, u: Dictionary) -> Dictionary:
	if victim<0 or int(u.get("level",0))<1 or u.get("baseRulesSuppressed",false) or not u.get("formRules",{}).get("oniRebirth",false): return {}
	return {"kind":"oni-rebirth","playerIndex":victim,"sourceIndex":gs._unit_index_by_uid(victim,str(u.uid)),"card":Content.card_def(str(u.form.cardId)).duplicate(true),"instance":u.get("oniFormInstance",{}).duplicate(true)}

static func knocked_out(u: Dictionary) -> void:
	u.attackBonus=int(u.attackBonus)-int(u.get("asuraPower",0))
	for key in ["asuraPower","asuraConquestTokens"]: u.erase(key)

static func heal_count(gs, owner: int, source_owner: int) -> int:
	if owner!=source_owner: return 0
	return gs.player(owner).realms.filter(func(r):return int(r.hp)>0 and r.get("nativeRealm")=="asura-heal").size()

static func damaged(gs, owner: int, idx: int, source_owner: int, amount: int, heals: int) -> void:
	if amount<=0: return
	if owner==source_owner and idx<0:
		gs.player(owner).asuraSelfDamageTurn=gs.turn_counter
		for u in gs.player(owner).units:
			if active(u) and role(u)=="asura":
				var gain := amount if u.awakened else 1
				u.asuraPower=int(u.get("asuraPower",0))+gain; gs._grow_unit(u,gain,0)
				gs.VerifiedRules.event(gs,"asura-growth",{"player":owner,"uid":u.uid,"amount":gain,"damage":amount})
	for i in heals:
		gs.resolution_stack.append({"kind":"asura-recover","playerIndex":owner,"targetUid":"avatar-%d" % owner if idx<0 else gs.player(owner).units[idx].uid,"amount":amount})

static func self_damage(gs, owner: int, src: int, amount: int) -> void:
	var context: Dictionary=gs._card_effect_context; gs._card_effect_context={}
	gs._damage_avatar(owner,amount,owner,src)
	gs._card_effect_context=context

static func before_attack(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if active(u) and u.get("formRules",{}).get("asuraAttackDamage",false): self_damage(gs,owner,src,1)

static func combat_started(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.get("asuraConquest",false): return
	var u: Dictionary=gs.player(owner).units[src]
	if not u.has("asuraConquestTokens"): u.asuraConquestTokens=[]
	options.asuraConquestToken=gs.next_rule_event_id; u.asuraConquestTokens.append(options.asuraConquestToken)
	gs.VerifiedRules.event(gs,"asura-conquest",{"player":owner,"uid":u.uid})

static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if options.has("asuraConquestToken"): gs.player(owner).units[src].get("asuraConquestTokens",[]).erase(options.asuraConquestToken)

static func will_transfer(gs, u: Dictionary) -> bool:
	return active(u) and role(u)=="asura" and (not u.get("asuraConquestTokens",[]).is_empty() or (u.awakened and int(u.get("asuraTransferTurn",-1))!=gs.turn_counter))

static func transfer(gs, owner: int, idx: int, amount: int, source_owner: int, source_index: int, combat: bool):
	var u: Dictionary=gs.player(owner).units[idx]
	if not combat or amount<=0 or not will_transfer(gs,u): return null
	var conquest: bool=not u.get("asuraConquestTokens",[]).is_empty()
	if not conquest: u.asuraTransferTurn=gs.turn_counter
	var context: Dictionary=gs._card_effect_context; gs._card_effect_context={}
	var dealt: int=gs._damage_avatar(owner,amount,source_owner if conquest else owner,source_index if conquest else idx,false,conquest)
	gs._card_effect_context=context
	gs.VerifiedRules.event(gs,"asura-transfer",{"player":owner,"uid":u.uid,"amount":amount,"dealt":dealt,"conquest":conquest,"sourcePlayer":source_owner})
	return {"damage":0,"dealt":0,"transferredDealt":dealt if conquest else 0,"knocked":false,"overkill":0}

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if owner==victim or idx>=0 or int(result.get("dealt",result.get("damage",0)))<=0 or not options.get("oniChain",false): return
	gs.resolution_stack.append({"kind":"oni-chain-draw","playerIndex":owner,"sourceIndex":src})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	match str(effect.get("action","")):
		"oni-divination": gs.VerifiedRules.Divination.start(gs,owner,3)
		"asura-break":
			var u: Dictionary=gs.player(owner).units[src]; var repeats := 1+int(u.knockout)
			gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
			var frames: Array=[]
			for i in repeats: frames.append({"kind":"asura-self-hit","playerIndex":owner,"sourceIndex":src,"amount":2})
			frames.reverse(); gs.resolution_stack.append_array(frames)
		"asura-all":
			var frames: Array=[]
			for side in [owner,1-owner]:
				for u in gs.player(side).units:
					if int(u.hp)>0: frames.append({"kind":"asura-all-hit","playerIndex":owner,"sourceIndex":src,"victim":side,"targetUid":u.uid})
				frames.append({"kind":"asura-all-hit","playerIndex":owner,"sourceIndex":src,"victim":side,"targetUid":"avatar-%d" % side})
			frames.reverse(); gs.resolution_stack.append_array(frames)
		_: return false
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind := str(f.get("kind",""))
	if kind=="oni-combat-resume": gs._resolve_combat_hit(f.combatFrame); return true
	if kind not in ["oni-first-draw","oni-rebirth","oni-rebirth-after","oni-chain-draw","oni-chain-after","asura-self-hit","asura-recover","asura-all-hit"]: return false
	var owner := int(f.playerIndex); var src := int(f.get("sourceIndex",-1))
	var old: Dictionary=gs._card_effect_context; gs._card_effect_context={}
	match kind:
		"oni-first-draw": impulse(gs,owner,src)
		"oni-rebirth", "oni-chain-draw":
			var next := f.duplicate(true); next.kind="oni-rebirth-after" if kind=="oni-rebirth" else "oni-chain-after"; next.before=int(gs.player(owner).get("oniDrawCounter",0))
			gs.resolution_stack.append(next); gs._draw(owner,1)
		"oni-rebirth-after":
			var u: Dictionary=gs.player(owner).units[src]
			gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
			if own_card(drawn_card(gs,owner,int(f.before)),u) and int(u.hp)>0:
				var card: Dictionary=f.card.duplicate(true); card.oniHandInstance=f.instance
				gs._install_form(owner,src,card,card.value)
		"oni-chain-after":
			var u: Dictionary=gs.player(owner).units[src]
			if active(u) and int(u.frozen)==0 and own_card(drawn_card(gs,owner,int(f.before)),u): gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"oniChain":true,"oniAutomatic":true})
		"asura-self-hit": self_damage(gs,owner,src,int(f.amount))
		"asura-recover":
			if str(f.targetUid)=="avatar-%d" % owner: gs._heal_avatar(owner,int(f.amount))
			else:
				var target: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(f.targetUid))
				if not target.is_empty(): gs._heal_unit(target,int(f.amount))
		"asura-all-hit":
			var victim := int(f.victim); var idx: int=gs._unit_index_by_uid(victim,str(f.targetUid))
			if str(f.targetUid)=="avatar-%d" % victim: gs._damage_avatar(victim,2,owner,src)
			elif idx>=0: gs._damage_unit(victim,idx,2,owner,src)
	gs._card_effect_context=old
	return true

static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("oniAsuraRules",false): return null
	if card.get("effect")=="asura-break":
		var src: int=gs._source_index(owner,card)
		return 65 if int(gs.player(owner).avatarHp)>2*(1+int(gs.player(owner).units[src].knockout)) else -100
	if card.get("type")=="form": return 40 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")!=card.id else -50
	return 50
