class_name TreeSakuraRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func role(unit: Dictionary) -> String:
	return str(Content.runtime_unit_def(unit).get("treeSakuraRole", ""))

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func shikigami(unit: Dictionary) -> bool:
	return not unit.get("removed", false) and (not unit.get("summoned", false) or unit.get("countsAsShikigami", false))

static func sync_power(unit: Dictionary) -> void:
	if role(unit) == "tree" and unit.awakened and active(unit): unit.attack = int(unit.hp)

static func health_damage(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and unit.get("treeHealthCombat", false)

static func floating(unit: Dictionary) -> bool:
	return active(unit) and unit.get("formRules", {}).get("sakuraFreeAttack", false)

static func delay_dead(unit: Dictionary) -> bool:
	return role(unit) == "sakura" and unit.awakened and int(unit.level) > 0

static func dead_damage(gs, owner: int, src: int, victim: int, idx: int, amount: int, earned: bool = false) -> bool:
	if amount <= 0 or owner < 0 or src < 0 or owner == victim: return false
	var source: Dictionary = gs.player(owner).units[src]
	var target: Dictionary = gs.player(victim).units[idx]
	if not shikigami(target) or int(target.hp) > 0 or int(target.knockout) <= 0: return false
	if not delay_dead(source) and not earned: return false
	target.knockout = int(target.knockout) + 1
	gs._log("樱花妖使%s气绝倒计时+1，现为%d。" % [target.name, int(target.knockout)], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "sakura-delay", {"player":owner,"uid":source.uid,"target":target.uid,"remaining":target.knockout})
	return true

static func recover(gs, owner: int, src: int, target_id: String, amount: int) -> bool:
	if amount <= 0: return false
	if target_id == "avatar-%d" % owner:
		gs._heal_avatar(owner, amount)
		return false
	var idx: int = gs._unit_index_by_uid(owner, target_id)
	if idx < 0: return false
	var unit: Dictionary = gs.player(owner).units[idx]
	if int(unit.hp) > 0:
		gs._heal_unit(unit, amount)
		return false
	if not shikigami(unit) or int(unit.knockout) <= 0: return false
	gs.VerifiedRules.reduce_countdown(gs, owner, idx, 1)
	gs.VerifiedRules.event(gs, "sakura-recovery-countdown", {"player":owner,"uid":gs.player(owner).units[src].uid,"target":unit.uid,"remaining":unit.knockout})
	sync_power(unit)
	return int(unit.hp) > 0

static func hit(gs, owner: int, src: int, target_id: String, amount: int, earned: bool = false) -> bool:
	var victim := 1 - owner
	if target_id == "avatar-%d" % victim:
		gs._damage_avatar(victim, amount, owner, src)
		return false
	var idx: int = gs._unit_index_by_uid(victim, target_id)
	if idx < 0: return false
	if int(gs.player(victim).units[idx].hp) <= 0:
		dead_damage(gs, owner, src, victim, idx, amount, earned)
		return false
	return bool(gs._damage_unit(victim, idx, amount, owner, src).get("knocked", false))

static func targets(gs, owner: int, card: Dictionary):
	var rule := str(card.get("treeSakuraRule", ""))
	if rule not in ["curse", "bless", "disaster", "fall"]: return null
	var src: int = gs._source_index(owner, card)
	var out: Array = []
	for side in [owner, 1-owner]:
		if rule == "fall": out.append("avatar-%d" % side)
		for unit in gs.player(side).units:
			if unit.get("removed", false): continue
			if side != owner and (gs.VerifiedRules.Combat.has(unit,"veil") or gs.VerifiedRules.Movement.has_veil(unit)): continue
			if rule == "fall":
				if int(unit.hp) > 0 or (shikigami(unit) and (side == owner or (src >= 0 and delay_dead(gs.player(owner).units[src])))): out.append(str(unit.uid))
			elif int(unit.hp) > 0 and shikigami(unit):
				if rule == "curse" and unit.get("form", {}).is_empty(): continue
				if rule == "bless" and src >= 0 and str(unit.uid) == str(gs.player(owner).units[src].uid): continue
				out.append(str(unit.uid))
	return out

static func attack_targets(gs, owner: int, src: int):
	var source: Dictionary = gs.player(owner).units[src]
	if not floating(source): return null
	var out: Array = []
	for side in [owner,1-owner]:
		out.append("avatar-%d" % side)
		for unit in gs.player(side).units:
			if str(unit.uid) == str(source.uid) or unit.get("removed",false): continue
			if side != owner and (gs.VerifiedRules.Combat.has(unit,"veil") or gs.VerifiedRules.Movement.has_veil(unit)): continue
			if int(unit.hp) > 0 or (shikigami(unit) and (side == owner or delay_dead(source))): out.append(str(unit.uid))
	return out

# Only the friendly/dead-target branches need a new exchange. Living enemy
# targets continue through the normal combat, response and damage pipeline.
static func special_attack(gs, frame: Dictionary, power: int, options: Dictionary) -> bool:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var source: Dictionary = gs.player(owner).units[src]
	if not floating(source) or frame.targetId == null: return false
	var target_id := str(frame.targetId)
	if not attack_targets(gs,owner,src).has(target_id): return true
	var ally: int = gs._unit_index_by_uid(owner,target_id)
	var enemy: int = gs._unit_index_by_uid(1-owner,target_id)
	if ally >= 0 or target_id == "avatar-%d" % owner:
		var hits := 2 if ally >= 0 and shikigami(gs.player(owner).units[ally]) else 1
		for step in hits:
			if gs.winner >= 0 or int(source.hp) <= 0: break
			recover(gs,owner,src,target_id,power)
			gs.VerifiedRules.event(gs,"sakura-combat-heal",{"player":owner,"uid":source.uid,"target":target_id,"amount":power,"step":step})
		gs._finish_combat(owner,src,{} if ally < 0 else gs.player(owner).units[ally],false,options,0)
		return true
	if enemy >= 0 and int(gs.player(1-owner).units[enemy].hp) <= 0:
		for step in 2:
			dead_damage(gs,owner,src,1-owner,enemy,power)
		gs._finish_combat(owner,src,gs.player(1-owner).units[enemy],false,options,0)
		return true
	return false

static func after_attack(gs, owner: int, src: int) -> void:
	var queue: Array = []
	for side in [owner,1-owner]:
		for i in gs.player(side).units.size():
			var unit: Dictionary = gs.player(side).units[i]
			if not active(unit): continue
			if side == owner and unit.get("formRules",{}).get("sakuraAfterAlly",false):
				queue.append({"kind":"tree-sakura-after","playerIndex":side,"sourceIndex":i,"target":gs.player(owner).units[src].uid,"heal":true})
			elif side != owner and unit.get("formRules",{}).get("sakuraAfterEnemy",false):
				queue.append({"kind":"tree-sakura-after","playerIndex":side,"sourceIndex":i,"target":gs.player(owner).units[src].uid,"heal":false,"earnedAwakened":delay_dead(unit)})
	queue.reverse(); gs.resolution_stack.append_array(queue)

static func turn_start(gs, current: int) -> void:
	for unit in gs.player(1-current).units:
		if active(unit) and role(unit) == "tree": gs._heal_unit(unit,int(unit.maxHp))
	var frames: Array = []
	for owner in [current,1-current]:
		for realm in gs.player(owner).realms.duplicate():
			if int(realm.hp) <= 0 or realm.get("nativeRealm") != "tree-forest": continue
			var src: int = gs._source_index(owner,Content.card_def(str(realm.cardId)))
			if src < 0: continue
			var amounts := [{"target":"avatar-%d" % current,"amount":int(gs.player(current).avatarHp)/2}]
			for unit in gs.player(current).units:
				if int(unit.hp) > 0: amounts.append({"target":str(unit.uid),"amount":int(unit.hp)/2})
			frames.append({"kind":"tree-forest","playerIndex":owner,"sourceIndex":src,"victim":current,"amounts":amounts})
	frames.reverse(); gs.resolution_stack.append_array(frames)
	gs._resolve_resolution_stack()

static func end_turn(gs, current: int) -> void:
	var frames: Array = []
	for owner in [current,1-current]:
		for i in gs.player(owner).units.size():
			var unit: Dictionary = gs.player(owner).units[i]
			if int(unit.hp) <= 0: continue
			if owner != current and active(unit) and unit.get("formRules",{}).get("treeNutrients",false):
				frames.append({"kind":"tree-nutrients","playerIndex":owner,"sourceIndex":i})
			if owner != current: continue
			for disaster in unit.get("treeDisasters",[]).duplicate():
				if int(disaster.dueTurn) > gs.turn_counter: continue
				unit.treeDisasters.erase(disaster)
				frames.append({"kind":"tree-disaster","playerIndex":owner,"sourceIndex":i})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func queue_card(gs, frame: Dictionary) -> void:
	frame.cardContext = gs._card_effect_context.duplicate(true)
	gs.resolution_stack.append(frame)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if not str(frame.get("kind", "")).begins_with("tree-"): return false
	var previous: Dictionary = gs._card_effect_context
	gs._card_effect_context = frame.get("cardContext", {})
	var handled := resolve_native_frame(gs, frame)
	gs._card_effect_context = previous
	return handled

static func resolve_native_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind",""))
	if not kind.begins_with("tree-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[src]
	match kind:
		"tree-nutrients":
			if active(unit):
				var amount := maxi(0,int(gs.player(owner).energy))
				gs.VerifiedRules.Glutton.record_permanent(unit,0,amount)
				gs._grow_unit(unit,0,amount)
		"tree-disaster":
			if int(unit.hp) > 0: gs._damage_unit(owner,src,int(unit.hp),owner,src)
		"tree-forest":
			for entry in frame.amounts:
				if gs.winner >= 0: break
				var victim := int(frame.victim)
				if str(entry.target) == "avatar-%d" % victim: gs._damage_avatar(victim,int(entry.amount),owner,src)
				else:
					var idx: int = gs._unit_index_by_uid(victim,str(entry.target))
					if idx >= 0: gs._damage_unit(victim,idx,int(entry.amount),owner,src)
		"tree-sakura-after":
			if frame.heal: recover(gs,owner,src,str(frame.target),3)
			else: hit(gs,owner,src,str(frame.target),2,bool(frame.earnedAwakened))
		"tree-sakura-bloom":
			for target in gs.player(owner).units.duplicate():
				if shikigami(target): recover(gs,owner,src,str(target.uid),3)
		"tree-sakura-cloud":
			if int(frame.remaining) <= 0 or gs.winner >= 0: return true
			var healing: Array = []
			if int(gs.player(owner).avatarHp) < int(gs.player(owner).maxAvatarHp): healing.append("avatar-%d" % owner)
			for target in gs.player(owner).units:
				if not target.get("removed",false) and ((int(target.hp)>0 and int(target.hp)<int(target.maxHp)) or (shikigami(target) and int(target.hp)<=0 and int(target.knockout)>0)): healing.append(str(target.uid))
			var damage: Array = ["avatar-%d" % (1-owner)]
			for target in gs.player(1-owner).units:
				if not target.get("removed",false) and (int(target.hp) > 0 or (shikigami(target) and delay_dead(unit))): damage.append(str(target.uid))
			var heal: bool = not healing.is_empty() and gs.randf01() < 0.5
			var pool: Array = healing if heal else damage
			var target_id := str(pool[int(floor(gs.randf01()*pool.size()))])
			queue_card(gs,{"kind":kind,"playerIndex":owner,"sourceIndex":src,"remaining":int(frame.remaining)-1,"bonus":frame.bonus})
			if heal: recover(gs,owner,src,target_id,2+int(frame.bonus))
			else: hit(gs,owner,src,target_id,1+int(frame.bonus))
			gs.VerifiedRules.event(gs,"sakura-cloud-step",{"player":owner,"uid":unit.uid,"target":target_id,"heal":heal})
		"tree-sakura-blizzard":
			var again := false
			var heal := bool(frame.heal)
			var side := owner if heal else 1-owner
			for target in gs.player(side).units.duplicate():
				if not shikigami(target) or gs.winner >= 0: continue
				if heal: again = recover(gs,owner,src,str(target.uid),3) or again
				else: again = hit(gs,owner,src,str(target.uid),2) or again
			if again and int(frame.repeats) == 0:
				var next := frame.duplicate(); next.repeats = int(frame.repeats)+1; gs.resolution_stack.append(next)
		_: return false
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action",""))
	if not action.begins_with("tree-sakura-"): return false
	var unit: Dictionary = gs.player(owner).units[src]
	match action:
		"tree-sakura-curse":
			if target.is_empty() or target.get("form",{}).is_empty() or int(target.hp) <= 0: return true
			# Transform the attachment, without firing removal/entry abilities.
			target.form = {"attackBonus":1-int(target.baseAttack),"hpBonus":6-int(target.baseMaxHp),"name":"诅咒之木","cardId":"tree-cursed-wood","native":true}
			target.formRules = {}; target.formHooks = []; target.formAbility = ""
			for key in ["formCountdown","formExpiresTurn","monkFormUnyielding","snowInstance"]: target.erase(key)
			gs.VerifiedRules.Poison.refresh_all(gs)
			gs._recalc(target); target.hp = int(target.maxHp); sync_power(target)
		"tree-sakura-bless":
			if not target.is_empty() and int(target.hp) > 0: target.treeHealthCombat = true
		"tree-sakura-disaster":
			if not target.is_empty() and int(target.hp) > 0:
				var side := owner if gs._unit_index_by_uid(owner,str(target.uid)) >= 0 else 1-owner
				if not target.has("treeDisasters"): target.treeDisasters = []
				target.treeDisasters.append({"dueTurn":gs.turn_counter+(2 if side == gs.current_player else 1)})
		"tree-sakura-awaken": gs._awaken(owner,src,card,effect.value)
		"tree-sakura-fall":
			var friendly: bool = str(target_id) == "avatar-%d" % owner or gs._unit_index_by_uid(owner,str(target_id)) >= 0
			var bonus := int(unit.get("spellPower",0))
			if friendly: recover(gs,owner,src,str(target_id),5+bonus)
			else: hit(gs,owner,src,str(target_id),3+bonus)
		"tree-sakura-bloom":
			for i in 2: queue_card(gs,{"kind":"tree-sakura-bloom","playerIndex":owner,"sourceIndex":src})
		"tree-sakura-cloud": queue_card(gs,{"kind":"tree-sakura-cloud","playerIndex":owner,"sourceIndex":src,"remaining":7,"bonus":int(unit.get("spellPower",0))})
		"tree-sakura-blizzard":
			queue_card(gs,{"kind":"tree-sakura-blizzard","playerIndex":owner,"sourceIndex":src,"heal":true,"repeats":0})
			queue_card(gs,{"kind":"tree-sakura-blizzard","playerIndex":owner,"sourceIndex":src,"heal":false,"repeats":0})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	var rule := str(card.get("treeSakuraRule",""))
	if rule.is_empty(): return null
	var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units,target_id)
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1-owner).units,target_id)
	match rule:
		"curse": return 75 if not enemy.is_empty() and not enemy.get("formRules",{}).is_empty() else -100
		"bless":
			if not enemy.is_empty(): return 50 if int(enemy.hp) < int(enemy.attack) and not enemy.get("treeHealthCombat",false) else -100
			return 55+int(ally.hp) if not ally.is_empty() and int(ally.hp)>int(ally.attack) and not ally.get("treeHealthCombat",false) else -100
		"disaster": return 55+int(enemy.hp) if not enemy.is_empty() and enemy.get("treeDisasters",[]).is_empty() else -100
		"fall":
			if not ally.is_empty(): return 55 if int(ally.hp)<=0 else (40+mini(5,int(ally.maxHp)-int(ally.hp))*6 if int(ally.hp)<int(ally.maxHp) else -100)
			if str(target_id)=="avatar-%d" % owner: return 50 if int(gs.player(owner).avatarHp)<25 else -100
			return 65 if not enemy.is_empty() and int(enemy.hp)<=3 else 42
		"bloom", "blizzard": return 70 if gs.player(owner).units.any(func(u):return int(u.hp)<int(u.maxHp)) else (50 if rule=="blizzard" else -100)
		"cloud": return 55
		_: return 45

static func attack_score(gs, owner: int, src: int, target_id):
	var unit: Dictionary = gs.player(owner).units[src]
	if not floating(unit): return null
	var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units,target_id)
	if str(target_id)=="avatar-%d" % owner: return mini(int(unit.attack),int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp))*14
	if not ally.is_empty(): return 110 if int(ally.hp)<=0 else mini(int(unit.attack)*2,int(ally.maxHp)-int(ally.hp))*14
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1-owner).units,target_id)
	if not enemy.is_empty() and int(enemy.hp)<=0: return 60
	return null
