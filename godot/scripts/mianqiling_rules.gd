class_name MianqilingRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Factions := preload("res://scripts/faction_rules.gd")

static func source(unit: Dictionary) -> bool:
	return Content.runtime_unit_def(unit).get("mianqilingRules",false)

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp",0)) > 0 and int(unit.get("level",0)) > 0 and not unit.get("removed",false) and not unit.get("baseRulesSuppressed",false)

static func wheel(unit: Dictionary) -> bool:
	return active(unit) and unit.get("formRules",{}).get("mianReincarnation",false)

static func has_trait(unit: Dictionary, keyword: String) -> bool:
	if not wheel(unit): return false
	return (keyword == "pierce" and Factions.get_faction(unit) == "红莲") or (keyword == "veil" and Factions.get_faction(unit) == "青岚")

static func swift(unit: Dictionary) -> bool:
	return wheel(unit) and Factions.get_faction(unit) == "苍叶" and not unit.get("mianSwiftSpent",false)

static func unyielding(unit: Dictionary) -> bool:
	return wheel(unit) and Factions.get_faction(unit) == "紫岩" and not unit.get("mianUnyieldingSpent",false)

static func consume_swift(unit: Dictionary) -> void:
	if swift(unit): unit.mianSwiftSpent = true

static func consume_unyielding(unit: Dictionary) -> void:
	if unyielding(unit): unit.mianUnyieldingSpent = true

static func state(unit: Dictionary) -> Dictionary:
	return {"uid":str(unit.get("uid","")), "faction":Factions.get_faction(unit), "passive":source(unit) and active(unit), "awakened":bool(unit.get("awakened",false))}

static func _damage_state(gs, unit: Dictionary, combat: bool) -> Dictionary:
	if combat:
		for side in ["source","target"]:
			var captured: Dictionary = gs._mianqiling_damage_scope.get(side,{})
			if captured.get("uid") == unit.get("uid"): return captured
	return state(unit)

static func modify_damage(gs, owner: int, idx: int, amount: int, source_owner: int, source_idx: int, combat: bool = false) -> int:
	if source_owner < 0 or source_owner >= gs.players.size() or source_idx < 0 or source_idx >= gs.player(source_owner).units.size(): return amount
	var src: Dictionary = _damage_state(gs,gs.player(source_owner).units[source_idx],combat)
	var dst: Dictionary = _damage_state(gs,gs.player(owner).units[idx],combat)
	if src.faction not in Factions.VALUES or dst.faction not in Factions.VALUES: return amount
	var result := amount
	if src.passive and src.faction != dst.faction: result = result * 2 if src.awakened else result + 1
	if dst.passive and src.faction == dst.faction: result = int(result / 2) if dst.awakened else maxi(0,result - 1)
	return result

static func positive_zero(gs, owner: int, idx: int, source_owner: int, source_idx: int, combat: bool = false) -> bool:
	return modify_damage(gs,owner,idx,0,source_owner,source_idx,combat) > 0

static func snapshot_exchange(gs, owner: int, src: int, victim: int, idx: int, attack: Dictionary, counter: Dictionary) -> void:
	attack.mianSource = state(gs.player(owner).units[src]); attack.mianTarget = state(gs.player(victim).units[idx])
	counter.mianSource = attack.mianTarget.duplicate(true); counter.mianTarget = attack.mianSource.duplicate(true)

static func begin_strike(gs, owner: int, src: int, victim: int, idx: int, options: Dictionary) -> Dictionary:
	var previous: Dictionary = gs._mianqiling_damage_scope
	gs._mianqiling_damage_scope = {}
	if idx >= 0:
		gs._mianqiling_damage_scope = {"source":options.get("mianSource",state(gs.player(owner).units[src])), "target":options.get("mianTarget",state(gs.player(victim).units[idx]))}
	return previous

static func end_strike(gs, previous: Dictionary) -> void:
	gs._mianqiling_damage_scope = previous

static func combat_prepare(gs, frame: Dictionary) -> void:
	if frame.options.get("combatCard",{}).get("id") != "c20802": return
	if frame.get("mianSevenPrepared",false): return
	if int(frame.get("sourceIndex",-1)) < 0 or int(frame.get("defenderIndex",-1)) < 0: return
	frame.mianSevenPrepared = true
	var attacker: Dictionary = gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
	var defender: Dictionary = gs.player(1-int(frame.playerIndex)).units[int(frame.defenderIndex)]
	if Factions.same(attacker,defender): frame.options.lethal = true
	elif Factions.different(attacker,defender): attacker.combatUnyielding = true
	gs.VerifiedRules.event(gs,"mian-seven-faces",{"player":int(frame.playerIndex),"uid":attacker.uid,"target":defender.uid,"lethal":Factions.same(attacker,defender),"unyielding":Factions.different(attacker,defender)})

static func set_faction(gs, owner: int, idx: int, faction: String, permanent: bool = false) -> bool:
	if faction not in Factions.VALUES: return false
	var unit: Dictionary = gs.player(owner).units[idx]
	if int(unit.hp) <= 0 or unit.get("removed",false): return false
	var old := Factions.get_faction(unit)
	if permanent:
		unit.factionPermanent = faction; unit.erase("factionOverride")
	else: unit.factionOverride = faction
	gs.VerifiedRules.event(gs,"faction-changed",{"player":owner,"uid":unit.uid,"from":old,"to":faction,"permanent":permanent,"changed":old != faction})
	if old != faction:
		unit.erase("mianSwiftSpent"); unit.erase("mianUnyieldingSpent")
		if wheel(unit): gs.resolution_stack.append({"kind":"mian-wheel-effect","playerIndex":owner,"sourceIndex":idx,"faction":faction})
	gs.VerifiedRules.RedPurple.refresh(gs)
	return true

static func random_faction(gs, owner: int, idx: int) -> void:
	var current := Factions.get_faction(gs.player(owner).units[idx])
	var pool: Array = Factions.VALUES.filter(func(f): return f != current)
	set_faction(gs,owner,idx,str(pool[int(gs.next_random() % pool.size())]))

static func form_entered(_gs, _owner: int, _src: int, _card: Dictionary) -> void:
	var unit: Dictionary = _gs.player(_owner).units[_src]
	unit.erase("mianSwiftSpent"); unit.erase("mianUnyieldingSpent")
	if _card.get("id") == "c20803": _choose(_gs,_owner,_src,unit,"normal",_card)

static func form_turn_start(gs, owner: int, src: int) -> void:
	if wheel(gs.player(owner).units[src]): random_faction(gs,owner,src)

static func knocked_out(unit: Dictionary) -> void:
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("mianRedGrowth",0))
	for key in ["mianRedGrowth","mianSwiftSpent","mianUnyieldingSpent"]: unit.erase(key)
	Factions.knocked_out(unit)

static func live_shikigami(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id") not in ["c20801","c20804"]: return null
	var result: Array = []
	for side in [owner,1-owner]:
		for unit in live_shikigami(gs,side):
			if side == owner or not gs.VerifiedRules.Combat.has(unit,"veil"): result.append(str(unit.uid))
	return result

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("id") != "c20807": return true
	var src: int = gs._source_index(owner,card)
	return src >= 0 and not gs.player(owner).units[src].awakened

static func _choose(gs, owner: int, src: int, target: Dictionary, mode: String, card: Dictionary) -> void:
	if target.is_empty() or int(target.hp) <= 0: return
	gs.pending_choice = {"type":"mian-faction","playerIndex":owner,"sourceIndex":src,"targetUid":str(target.uid),"mode":mode,"card":card.duplicate(true),"instanceIds":Factions.VALUES.duplicate(),"heading":"选 择 派 系","hint":"为「%s」选择派系；%s" % [target.name,"永久改变，随后觉醒" if mode=="awaken" else "持续至目标气绝"]}
	gs.phase = "choice"

static func choice_card(gs, owner: int, id: String):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "mian-faction" or int(choice.playerIndex) != owner or id not in Factions.VALUES: return null
	var target: Dictionary = gs._unit_by_uid(gs._all_units(),choice.targetUid)
	var detail := "将%s变为%s派系。" % [target.get("name","目标"),id]
	if wheel(target):
		detail += {"红莲":"贯通；真正变派系时，己方全体式神+1力量。","紫岩":"不屈；真正变派系时，自己与牌手恢复3生命。","苍叶":"迅捷；真正变派系时，随机敌方式神受2伤。","青岚":"帷幕；真正变派系时，所有敌方式神受1伤。"}[id]
	return {"id":id,"name":id,"unitId":"mianqiling","type":"spell","typeLabel":"派系选择","level":0,"cost":0,"text":detail,"color":"#"+str(Factions.COLORS[id])}

static func resolve_choice(gs, owner: int, id: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "mian-faction" or int(choice.playerIndex) != owner or id not in Factions.VALUES: return false
	var target_owner := -1; var target_idx := -1
	for side in 2:
		var idx: int = gs._unit_index_by_uid(side,str(choice.targetUid))
		if idx >= 0: target_owner=side; target_idx=idx; break
	if target_idx < 0 or int(gs.player(target_owner).units[target_idx].hp) <= 0: return false
	gs.pending_choice={}; gs.phase="main"
	gs._record("resolve_divination_choice",{"choice":"mian-faction","instanceId":id,"target":choice.targetUid},owner)
	if choice.mode == "awaken": gs.resolution_stack.append({"kind":"mian-awaken","playerIndex":owner,"sourceIndex":int(choice.sourceIndex),"card":choice.card})
	set_faction(gs,target_owner,target_idx,id,choice.mode=="awaken")
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("mianqilingRules",false): return card
	var result := card.duplicate(true)
	if card.id == "c20804": result.currentCardStats="当前伤害%d · 场上%d种派系" % [Factions.distinct(gs._all_units()).size()+2,Factions.distinct(gs._all_units()).size()]
	elif card.id == "c20805": result.currentCardStats="当前抽%d张 · 己方派系种类" % Factions.distinct(gs.player(owner).units).size()
	elif card.id == "c20808":
		var src: int = gs._source_index(owner,card)
		result.currentCardStats="当前派系%s · 每段重新统计 · 共3次" % Factions.get_faction(gs.player(owner).units[src])
	return result

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not str(effect.get("action","")).begins_with("mian-"): return false
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.action):
		"mian-faction": _choose(gs,owner,src,gs._unit_by_uid(gs._all_units(),str(target_id)),"normal",card)
		"mian-awaken-choice": _choose(gs,owner,src,unit,"awaken",card)
		"mian-combat":
			var options: Dictionary = card.get("combatOption",{}).duplicate(true); options.combatCard=card.duplicate(true)
			gs._record("assault",{"unit":src,"bonus":int(card.value),"target":target_id},owner)
			gs._resolve_combat(owner,src,int(card.value),false,false,false,false,target_id,false,options)
		"mian-self-deceit":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side,str(target_id))
				if idx >= 0: gs._damage_unit(side,idx,Factions.distinct(gs._all_units()).size()+2+int(unit.get("spellPower",0)),owner,src)
		"mian-draw": gs._draw(owner,Factions.distinct(gs.player(owner).units).size())
		"mian-jealous": gs.resolution_stack.append({"kind":"mian-jealous-hit","playerIndex":owner,"sourceIndex":src,"remaining":3,"context":gs._card_effect_context.duplicate(true)})
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if not kind.begins_with("mian-"): return false
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex); var unit: Dictionary = gs.player(owner).units[src]
	match kind:
		"mian-awaken": gs._awaken(owner,src,frame.card,{"attack":2,"hp":2})
		"mian-jealous-hit":
			var faction := Factions.get_faction(unit); var count := 0
			for target in gs._all_units():
				if int(target.hp)>0 and not target.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(target) and Factions.get_faction(target)==faction: count+=1
			gs.resolution_stack.append({"kind":"mian-jealous-change","playerIndex":owner,"sourceIndex":src,"remaining":int(frame.remaining)-1,"context":frame.context})
			var prior: Dictionary = gs._card_effect_context; gs._card_effect_context=frame.context
			gs.VerifiedRules.ThreeTail.projectile(gs,owner,src,count+int(unit.get("spellPower",0)),"妒心")
			gs._card_effect_context=prior
		"mian-jealous-change":
			if int(frame.remaining)>0: gs.resolution_stack.append({"kind":"mian-jealous-hit","playerIndex":owner,"sourceIndex":src,"remaining":int(frame.remaining),"context":frame.context})
			random_faction(gs,owner,src)
		"mian-wheel-effect":
			var old: Dictionary = gs._card_effect_context; gs._card_effect_context={}
			match str(frame.faction):
				"红莲":
					for target in live_shikigami(gs,owner):
						target.mianRedGrowth=int(target.get("mianRedGrowth",0))+1; gs._grow_unit(target,1,0)
				"紫岩": gs._heal_avatar(owner,3); gs._heal_unit(unit,3)
				"苍叶":
					var pool := live_shikigami(gs,1-owner)
					if not pool.is_empty(): gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,str(pool[int(gs.next_random()%pool.size())].uid)),2,owner,src)
				"青岚":
					var pool := live_shikigami(gs,1-owner)
					for i in range(pool.size()-1,-1,-1): gs.resolution_stack.append({"kind":"mian-wheel-hit","playerIndex":owner,"sourceIndex":src,"targetUid":str(pool[i].uid)})
			gs._card_effect_context=old
			gs.VerifiedRules.event(gs,"mian-reincarnation",{"player":owner,"uid":unit.uid,"faction":frame.faction})
		"mian-wheel-hit":
			var idx: int = gs._unit_index_by_uid(1-owner,str(frame.targetUid))
			var old: Dictionary = gs._card_effect_context; gs._card_effect_context={}
			if idx>=0: gs._damage_unit(1-owner,idx,1,owner,src)
			gs._card_effect_context=old
	return true

static func ai_choice(gs, owner: int):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "mian-faction": return null
	if int(choice.playerIndex) != owner: return false
	var target: Dictionary = gs._unit_by_uid(gs._all_units(),str(choice.targetUid))
	var selected := "红莲"
	if wheel(target):
		if int(target.hp)<int(target.maxHp)-2 or int(gs.player(owner).avatarHp)<20: selected="紫岩"
		elif live_shikigami(gs,1-owner).size()>2: selected="青岚"
		elif not gs.player(owner).attackUsed: selected="苍叶"
	else:
		var enemies := live_shikigami(gs,1-owner)
		if not enemies.is_empty(): selected=Factions.get_faction(enemies[0])
		if selected not in Factions.VALUES: selected="红莲"
	return resolve_choice(gs,owner,selected)

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("mianqilingRules",false): return null
	if card.id == "c20804" and gs._unit_index_by_uid(owner,str(target_id))>=0: return -100
	if card.id == "c20801": return 50 if str(target_id)==str(gs.player(owner).units[gs._source_index(owner,card)].uid) else 25
	if card.id == "c20807": return 65
	if card.id == "c20805": return Factions.distinct(gs.player(owner).units).size()*15
	return 40

static func marks(_gs, _owner: int, unit: Dictionary) -> Array:
	var faction := Factions.get_faction(unit)
	var result: Array = ["派系 · "+(faction if faction!="" else "待核验")]
	if unit.has("factionOverride"): result.append("派系变化 · 气绝恢复")
	elif unit.has("factionPermanent"): result.append("派系变化 · 永久")
	if source(unit): result.append("同派减半／异派翻倍" if unit.get("awakened",false) else "同派伤害-1／异派伤害+1")
	if wheel(unit): result.append("轮回之面 · "+{"红莲":"贯通","紫岩":"不屈" if unyielding(unit) else "不屈已用","苍叶":"迅捷" if swift(unit) else "迅捷已用","青岚":"帷幕"}.get(faction,""))
	return result
