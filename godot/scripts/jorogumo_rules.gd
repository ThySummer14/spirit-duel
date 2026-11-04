class_name JorogumoRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0)) > 0 and int(u.get("level",0)) > 0 and not u.get("baseRulesSuppressed",false) and not u.get("removed",false)
static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("jorogumoRules",false)
static func marked(u: Dictionary) -> bool:
	return not u.get("spiderMark",{}).is_empty()
static func received_damage(u: Dictionary, amount: int) -> int:
	# The modifier applies to positive damage after armor and critical.
	return amount + (1 if marked(u) and amount>0 else 0)
static func enemies(gs, owner: int) -> Array:
	return gs.player(1-owner).units.filter(func(u): return int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func attach(gs, owner: int, src: int, target: Dictionary) -> void:
	if target.is_empty() or int(target.hp)<=0 or target.get("removed",false): return
	if marked(target):
		for i in gs.player(owner).units.size():
			var host: Dictionary = gs.player(owner).units[i]
			if source(host) and active(host) and host.awakened:
				var context: Dictionary = gs._card_effect_context; gs._card_effect_context = {}
				var hit: Dictionary = gs.VerifiedRules.base_damage_unit(gs, owner, i, 1-owner, gs._unit_index_by_uid(1-owner,target.uid), 2)
				gs._card_effect_context = context
				gs.VerifiedRules.event(gs,"jorogumo-repeat-hit",{"player":owner,"uid":host.uid,"target":target.uid,"victimPlayer":1-owner,"amount":int(hit.get("damage",0)),"blocked":int(hit.get("damage",0))==0,"card":{"id":"spider-mark","unitId":"luoxinfu","type":"ability","name":"蜘蛛印记"}})
				return
	target.spiderMark = {"sourceOwner":owner,"sourceUid":gs.player(owner).units[src].uid}
	gs.VerifiedRules.event(gs,"spider-mark-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":target.uid})

static func before_attack(gs, owner: int, src: int) -> void:
	var attacker: Dictionary = gs.player(owner).units[src]
	if gs.VerifiedRules.OwlInsect.shikigami(attacker): gs.player(owner).jorogumoLastAttack = {"turn":gs.turn_counter,"uid":attacker.uid}
	for i in gs.player(1-owner).units.size():
		var host: Dictionary = gs.player(1-owner).units[i]
		if source(host) and active(host) and host.awakened and gs.VerifiedRules.OwlInsect.shikigami(attacker): attach(gs,1-owner,i,attacker)

static func end_turn(gs, current: int) -> void:
	var last: Dictionary = gs.player(current).get("jorogumoLastAttack",{})
	if int(last.get("turn",-1)) != gs.turn_counter: return
	for i in gs.player(1-current).units.size():
		var host: Dictionary = gs.player(1-current).units[i]
		if source(host) and active(host) and not host.awakened:
			gs.resolution_stack.append({"kind":"jorogumo-end-mark","playerIndex":1-current,"sourceIndex":i,"targetUid":last.uid})

static func tax(gs, owner: int, unit: Dictionary) -> int:
	if not marked(unit): return 0
	return gs.player(1-owner).units.filter(func(u): return active(u) and u.get("formRules",{}).get("jorogumoTax",false)).size()
static func card_tax(gs, owner: int, card: Dictionary) -> int:
	var src: int = gs._source_index(owner,card)
	return 0 if src<0 else tax(gs,owner,gs.player(owner).units[src])

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("jorogumoRules",false) or card.get("target","auto") == "auto": return null
	var pool: Array = enemies(gs,owner)
	if card.id == "c27508":
		pool = []
		for side in [owner,1-owner]:
			for u in gs.player(side).units:
				if int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u) and (side==owner or not gs.VerifiedRules.Combat.has(u,"veil")): pool.append(u)
	elif card.type != "combat": pool = pool.filter(func(u): return not gs.VerifiedRules.Combat.has(u,"veil"))
	var ids: Array = pool.map(func(u): return u.uid)
	if card.type == "combat" and gs.front_index(1-owner)<0: ids.append("avatar-%d" % (1-owner))
	return ids
static func describe_card(gs, owner: int, _inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("jorogumoRules",false): return card
	var view := card.duplicate(true)
	var src: int = gs._source_index(owner,card)
	if src>=0 and card.id in ["c27502","c27508"]:
		var extra := int(gs.player(owner).units[src].get("spellPower",0))
		if extra!=0:
			view.value = (1 if card.id=="c27502" else 5) + extra
			view.currentCardStats = "当前法术伤害 %d" % int(view.value)
	if card.get("jorogumoEntryMark",false) and targets(gs,owner,card).is_empty(): view.target = "auto"
	return view
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("effect") != "jorogumo-awaken": return true
	return not gs.player(owner).units[gs._source_index(owner,card)].awakened

static func assault(gs, owner: int, src: int, card: Dictionary, target: Dictionary, target_id) -> void:
	var options: Dictionary = card.combatOption.duplicate(true)
	if marked(target):
		if card.id == "c27503": options.immuneCombat = true
		if card.id == "c27506": options.lifeSteal = true
	options.combatCard = card.duplicate(true)
	gs._grant_unit_armor(gs.player(owner).units[src],int(options.get("shield",0)))
	gs._record("assault",{"unit":src,"bonus":int(card.value),"target":target_id},owner)
	gs._resolve_combat(owner,src,int(card.value),false,false,false,false,target_id,false,options)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	match str(effect.get("action","")):
		"jorogumo-mark": attach(gs,owner,src,target)
		"jorogumo-needle":
			attach(gs,owner,src,target)
			var idx: int = gs._unit_index_by_uid(1-owner,target_id)
			if idx>=0 and int(gs.player(1-owner).units[idx].hp)>0: gs._damage_unit(1-owner,idx,1+int(gs.player(owner).units[src].get("spellPower",0)),owner,src)
		"jorogumo-combat": assault(gs,owner,src,card,target,target_id)
		"jorogumo-aoe":
			var ids: Array = enemies(gs,owner).map(func(u): return u.uid)
			for uid in ids:
				var idx: int = gs._unit_index_by_uid(1-owner,uid)
				if idx>=0 and gs.winner<0:
					var hit: Dictionary = gs._damage_unit(1-owner,idx,int(gs.player(owner).units[src].level),owner,src)
					gs.VerifiedRules.event(gs,"jorogumo-card-hit",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":uid,"victimPlayer":1-owner,"amount":int(hit.get("damage",0)),"blocked":int(hit.get("damage",0))==0,"card":card})
		"jorogumo-awaken": gs._awaken(owner,src,card,effect.value)
		"jorogumo-exterminate":
			for side in [owner,1-owner]:
				var idx: int = gs._unit_index_by_uid(side,target_id)
				if idx<0 or int(gs.player(side).units[idx].hp)<=0: continue
				if marked(target): gs.VerifiedRules.Panguan.destroy(gs,owner,src,side,idx,card)
				else: gs._damage_unit(side,idx,5+int(gs.player(owner).units[src].get("spellPower",0)),owner,src)
		_: return false
	return true

static func death_frames(gs, victim: int, unit: Dictionary) -> Array:
	var frames: Array = []
	if victim<0 or int(unit.get("knockout",0))>0 or unit.get("removed",false) or not gs.VerifiedRules.OwlInsect.shikigami(unit): return frames
	var owner := 1-victim
	for field in gs.player(owner).realms:
		if int(field.hp)>0 and field.get("nativeRealm")=="jorogumo-devour": frames.append({"kind":"jorogumo-realm-death","playerIndex":owner,"realmUid":field.uid})
	if marked(unit):
		for i in gs.player(owner).units.size():
			var host: Dictionary = gs.player(owner).units[i]
			if active(host) and host.get("formRules",{}).get("jorogumoSwarm",false) and int(host.get("jorogumoSwarmTurn",-1))!=gs.turn_counter:
				host.jorogumoSwarmTurn = gs.turn_counter
				frames.append({"kind":"jorogumo-summon","playerIndex":owner,"sourceIndex":i})
	return frames

static func remove_summon(gs, owner: int, unit: Dictionary, reason: String = "离开战斗区") -> void:
	if not unit.get("jorogumoSwarm",false) or unit.get("removed",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,unit.uid),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,unit.uid),reason,false)
	unit.hp=0; unit.front=0; unit.knockout=0; unit.removed=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":unit.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("jorogumoSwarm",false) and int(u.hp)>0 and int(u.front)==0: remove_summon(gs,owner,u)
static func summon(gs, owner: int, src: int) -> void:
	gs.VerifiedRules.Weaver.leave_front(gs,owner)
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = {"color":"#d080c0","shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"charge":0,"removed":false}
	unit.uid="%s:spider-%d" % [p.id,gs.next_card_id]; gs.next_card_id+=1
	unit.id="jorogumo-swarm"; unit.name="蛛群"; unit.title="络新妇召唤物"
	unit.art=Content.unit_def("luoxinfu").art; unit.awakenedArt=unit.art
	unit.baseAttack=3; unit.baseMaxHp=4; unit.attack=3; unit.maxHp=4; unit.hp=4
	unit.level=1; unit.front=1; unit.summoned=true; unit.summon=true; unit.countsAsShikigami=true; unit.jorogumoSwarm=true
	unit.summonerUid=p.units[src].uid; unit.passive_hooks=[]; unit.formAbility="对敌方式神造成伤害时，使其结附「蜘蛛印记」。离开战斗区时移除。"
	p.units.append(unit)
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":unit.uid,"sourceUid":unit.summonerUid,"summonKind":"蛛群"})
	gs._fire_hooks(owner,p.units.size()-1,"unit-entered-front",{}); gs._run_form_hooks(owner,p.units.size()-1,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",unit.uid,{"kind":"response-complete"})
static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, hit: Dictionary) -> void:
	if idx<0 or victim==owner or int(hit.get("dealt",hit.get("damage",0)))<=0 or not gs.player(owner).units[src].get("jorogumoSwarm",false): return
	attach(gs,owner,src,gs.player(victim).units[idx])

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if not kind.begins_with("jorogumo-"): return false
	var owner := int(frame.playerIndex)
	match kind:
		"jorogumo-end-mark": attach(gs,owner,int(frame.sourceIndex),gs._unit_by_uid(gs.player(1-owner).units,frame.targetUid))
		"jorogumo-summon": summon(gs,owner,int(frame.sourceIndex))
		"jorogumo-realm-death":
			for field in gs.player(owner).realms:
				if field.uid!=frame.realmUid or int(field.hp)<=0: continue
				field.hp+=1
				var idx: int = gs._source_index(owner,Content.card_def("c27501"))
				var context: Dictionary = gs._card_effect_context; gs._card_effect_context={}
				var dealt: int = gs._damage_avatar(1-owner,1,owner,idx)
				gs._card_effect_context=context
				gs.VerifiedRules.event(gs,"jorogumo-realm-death",{"player":owner,"realmUid":field.uid,"uid":gs.player(owner).units[idx].uid,"target":"","victimPlayer":1-owner,"amount":dealt,"blocked":dealt==0,"card":Content.card_def("c27501")})
	return true

static func unit_marks(gs, owner: int, src: int) -> Array:
	var unit: Dictionary = gs.player(owner).units[src]
	var result: Array = []
	if marked(unit): result.append("蜘蛛印记 · 唯一 · 受到伤害+1")
	if unit.get("jorogumoSwarm",false): result.append("蛛群 · 造成伤害结附蜘蛛印记 · 离场移除")
	if unit.get("formRules",{}).get("jorogumoSwarm",false): result.append("御蛛鬼姬 · 本回合"+("已召唤" if int(unit.get("jorogumoSwarmTurn",-1))==gs.turn_counter else "可召唤蛛群"))
	if unit.get("formRules",{}).get("jorogumoTax",false): result.append("罗网缠织 · 已印记敌方式神出击/用牌额外1鬼火")
	if tax(gs,owner,unit)>0: result.append("罗网缠织 · 出击/用牌额外%d鬼火" % tax(gs,owner,unit))
	return result
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("jorogumoRules",false): return null
	var target: Dictionary = gs._unit_by_uid(gs._all_units(),target_id)
	if card.id=="c27508":
		if gs._unit_index_by_uid(owner,target_id)>=0: return -100
		return 95 if marked(target) else 70 if int(target.get("hp",0))<=5 else 40
	if card.type=="combat": return 55+(20 if marked(target) else 0)+int(target.get("attack",0))*2
	if card.id=="c27502": return 70+(15 if marked(target) else 0)
	if card.id=="c27505": return 95
	if card.type=="form": return -100 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 65
	if card.type=="realm": return 65+enemies(gs,owner).size()*5
	return 40
