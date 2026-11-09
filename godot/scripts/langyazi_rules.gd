class_name LangyaRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

# Curses are realms summoned into the ENEMY player's realm zone, written from the
# curse owner's perspective. They enter at the front (first durability sink).
const CURSES := {
	"meizhou": {"name": "寐咒", "hp": 2, "unique": false, "level": 1, "text": "你的回合开始时，对你的牌手造成1点伤害。此伤害造成的幻境耐久降低值翻倍。"},
	"wangzhou": {"name": "忘咒", "hp": 4, "unique": true, "level": 2, "text": "进场时眩晕所选式神，并随机弃掉其一张专属牌。离场时，召唤此咒印的牌手抽一张牌。"},
	"zhenzhou": {"name": "镇咒", "hp": 5, "unique": true, "level": 1, "text": "进场时使所选式神失去2力量。离场时，为召唤此咒印的牌手召唤一个「蜃境」。"},
	"miezhou": {"name": "灭咒", "hp": 4, "unique": true, "level": 1, "text": "进场时对所选式神造成等同于场上幻境总数的伤害。离场时，随机使你的一个气绝式神气绝倒计时+1。"},
	"hunzhou": {"name": "魂咒", "hp": 4, "unique": true, "level": 2, "text": "进场时为你召唤一个「缚魂」。离场时，为召唤此咒印的牌手召唤一个「束魂」。"},
	"yongshengzhou": {"name": "永生咒", "hp": 6, "unique": true, "level": 3, "text": "进场时随机消灭你的一个式神。离场时，为召唤此咒印的琅琊子结附「长生丹」。"},
}

static func realm_card(realm: Dictionary, card: Dictionary) -> Dictionary:
	var kind := str(realm.get("curseKind", ""))
	if CURSES.has(kind):
		var def: Dictionary = CURSES[kind]
		var label := "幻境牌 / 咒印"
		var text := "唯一。\n" + str(def.text) if def.unique else str(def.text)
		var display := card.duplicate()
		display.merge({"id": realm.cardId, "unitId": "langyazi", "name": def.name, "type": "realm",
			"typeLabel": label, "level": def.level, "text": text}, true)
		return display
	if realm.get("nativeRealm") == "langyazi-mirage":
		return {"id": realm.cardId, "unitId": "langyazi", "name": "蜃境", "type": "realm", "typeLabel": "幻境牌", "text": "每回合一次，当己方式神攻击后，获得一次坚守，附带1战力和1护甲。"}
	return card

static func source(u: Dictionary) -> bool: return Content.runtime_unit_def(u).get("langyaziRules", false)
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)

static func source_index(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": "langyazi"})

static func has_curse(gs, owner: int, kind: String) -> bool:
	return gs.player(owner).realms.any(func(r): return r.get("curseKind","")==kind and int(r.hp)>0)

static func summon_curse(gs, victim: int, kind: String, target_uid: String, summoner: int):
	var def: Dictionary = CURSES.get(kind, {})
	if def.is_empty(): return null
	if def.unique and has_curse(gs, victim, kind): return null
	var realm := {
		"uid": "realm-%s-%d" % [gs.player(victim).id, gs.next_card_id],
		"nativeRealm": "langyazi-curse", "curseKind": kind, "curseSummoner": summoner,
		"targetUid": target_uid, "sourceUnit": "langyazi", "cardId": "meizhou" if kind == "meizhou" else "ly-"+kind,
		"name": def.name, "hp": def.hp, "maxHp": def.hp, "curseLevel": def.level,
		"trigger": "native-continuous", "triggerEffect": "", "triggerValue": 0,
		"triggerEffects": [], "countdown": 0, "countdownReset": 0, "handCountdown": 0,
		"avatarLinked": false, "returnOnDestroy": false, "returnInstance": {}, "cardInstance": {},
	}
	gs.next_card_id += 1
	gs.player(victim).realms.push_front(realm)
	gs._log("为%s召唤咒印「%s」。" % [gs.player(victim).name, def.name], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "realm-deployed", {"player": victim, "realm": realm.uid})
	gs.VerifiedRules.MonkCleaner.refresh(gs)
	gs.VerifiedRules.Night.refresh(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	curse_entered(gs, victim, realm)
	return realm

static func curse_entered(gs, victim: int, realm: Dictionary) -> void:
	var kind := str(realm.curseKind); var summoner := int(realm.get("curseSummoner", 1-victim))
	var target: Dictionary = gs._unit_by_uid(gs.player(victim).units, str(realm.targetUid))
	match kind:
		"wangzhou":
			if not target.is_empty() and int(target.hp)>0:
				var idx: int = gs._unit_index_by_uid(victim, str(target.uid))
				gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, summoner)
				_discard_random_owned(gs, victim, target)
		"zhenzhou":
			if not target.is_empty() and int(target.hp)>0:
				target.attackBonus = int(target.attackBonus) - 2; gs._recalc(target)
		"miezhou":
			if not target.is_empty() and int(target.hp)>0:
				var total: int = gs.player(0).realms.size() + gs.player(1).realms.size()
				var idx: int = gs._unit_index_by_uid(victim, str(target.uid))
				gs._damage_unit(victim, idx, total, summoner, source_index(gs, summoner))
		"hunzhou":
			_summon_soul(gs, victim, "fu-soul")
		"yongshengzhou":
			var living: Array = gs.player(victim).units.filter(func(u): return int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u))
			if not living.is_empty():
				var pick: Dictionary = living[int(gs.next_random() % living.size())]
				gs.VerifiedRules.Panguan.destroy(gs, summoner, source_index(gs, summoner), victim, gs._unit_index_by_uid(victim,str(pick.uid)), {})

static func _discard_random_owned(gs, victim: int, target: Dictionary) -> void:
	var p: Dictionary = gs.player(victim); var uid := str(target.get("id",""))
	var pool: Array = []
	for inst in p.hand:
		if uid in Content.card_unit_ids(gs.describe_card_instance(victim, inst)): pool.append(inst)
	if pool.is_empty(): return
	var pick: Dictionary = pool[int(gs.next_random() % pool.size())]
	gs.discard_hand_card(victim, p.hand.find(pick))
	gs._log("%s 随机弃掉一张%s的专属牌。" % [p.name, target.name], gs.TONE_DANGER)
	gs.VerifiedRules.event(gs, "card-discarded", {"player": victim, "uid": target.uid, "card": Content.card_def(str(pick.definitionId)), "instanceId": str(pick.instanceId)})

static func _summon_soul(gs, owner: int, id: String) -> void:
	var def: Dictionary = Content.unit_def(id)
	if def.is_empty(): return
	var u := {"uid":"%s:%s-%d"%[gs.player(owner).id,id,gs.next_card_id],"id":id,"name":def.name,"title":def.get("title",""),"art":def.get("art",""),"color":def.get("color","#b090d0"),"baseAttack":int(def.attack),"baseMaxHp":int(def.maxHp),"attack":int(def.attack),"maxHp":int(def.maxHp),"hp":int(def.maxHp),"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":def.get("formRules",{}).duplicate(true),"formHooks":[],"formAbility":def.get("passive",{}).get("text",""),"charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"lySoul":true,"keywords":def.get("keywords",[]).duplicate()}
	gs.next_card_id += 1
	var enters_front := can_front(u)
	u.front = int(enters_front)
	if enters_front: gs.VerifiedRules.Weaver.leave_front(gs, owner)
	gs.player(owner).units.append(u)
	var idx: int = gs.player(owner).units.size()-1
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"summonKind":id})
	if enters_front: gs.VerifiedRules.Weaver.entered(gs, owner, idx)

static func remove_soul(gs, owner: int, unit: Dictionary) -> void:
	var idx: int = gs._unit_index_by_uid(owner, unit.uid)
	gs.VerifiedRules.Otakemaru.remove_charm(gs, owner, idx, "离开战斗区")
	gs.VerifiedRules.Vine.remove_charm(gs, owner, idx, "离开战斗区", false)
	unit.hp = 0
	unit.front = 0
	unit.knockout = 0
	unit.removed = true
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": unit.uid, "reason": "离开战斗区"})

static func clear_front_souls(gs, owner: int, attacker: Dictionary) -> void:
	for unit in gs.player(owner).units:
		if unit != attacker and unit.get("lySoul", false) and int(unit.hp) > 0 and int(unit.front) == 1:
			remove_soul(gs, owner, unit)

static func curse_left(gs, victim: int, realm: Dictionary) -> void:
	var kind := str(realm.get("curseKind","")); var summoner := int(realm.get("curseSummoner", 1-victim))
	match kind:
		"wangzhou": gs._draw(summoner, 1)
		"zhenzhou": _deploy_mirage(gs, summoner)
		"miezhou":
			var knocked: Array = gs.player(victim).units.filter(func(u): return int(u.hp)<=0 and not u.get("removed",false) and int(u.knockout)>0 and gs.VerifiedRules.OwlInsect.shikigami(u))
			if not knocked.is_empty():
				var pick: Dictionary = knocked[int(gs.next_random() % knocked.size())]
				pick.knockout = int(pick.knockout) + 1
				gs.VerifiedRules.event(gs,"countdown-changed",{"player":victim,"uid":pick.uid,"remaining":pick.knockout})
		"hunzhou": _summon_soul(gs, summoner, "shu-soul")
		"yongshengzhou": _attach_changshengdan(gs, summoner)

static func _deploy_mirage(gs, owner: int) -> void:
	var realm := {"uid":"realm-%s-%d"%[gs.player(owner).id,gs.next_card_id],"nativeRealm":"langyazi-mirage","sourceUnit":"langyazi","cardId":"ly-mirage","name":"蜃境","hp":1,"maxHp":1,"trigger":"native-continuous","triggerEffect":"","triggerValue":0,"triggerEffects":[],"countdown":0,"countdownReset":0,"handCountdown":0,"avatarLinked":false,"returnOnDestroy":false,"returnInstance":{},"cardInstance":{}}
	gs.next_card_id += 1
	gs.player(owner).realms.append(realm)
	gs.VerifiedRules.event(gs,"realm-deployed",{"player":owner,"realm":realm.uid})

static func _attach_changshengdan(gs, owner: int) -> void:
	var idx := source_index(gs, owner)
	if idx < 0: return
	var card: Dictionary = Content.card_def("ly-changshengdan")
	gs._install_form(owner, idx, card)

static func realm_destroyed(gs, victim: int, realm: Dictionary) -> void:
	if realm.get("nativeRealm", "") == "langyazi-curse": curse_left(gs, victim, realm)
	var owner := 1 - victim
	var initial := int(realm.get("maxHp", Content.card_def(str(realm.cardId)).get("realm", {}).get("hp", 0)))
	for r in gs.player(owner).realms.duplicate():
		if r.get("nativeRealm", "") == "langyazi-dongtian" and int(r.hp) > 0:
			gs._heal_avatar(owner, initial)

static func passive_trigger(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not source(u) or not active(u): return
	if int(u.get("lyPassiveTurn",-1)) == gs.turn_counter: return
	u.lyPassiveTurn = gs.turn_counter
	summon_curse(gs, 1-owner, "meizhou", "", owner)
	if u.awakened:
		var count := 0
		for r in gs.player(1-owner).realms:
			if r.get("nativeRealm","") == "langyazi-curse" and int(r.hp)>0: count += 1
		for i in count:
			var living: Array = gs.player(1-owner).units.filter(func(t): return int(t.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(t))
			if living.is_empty() or gs.winner >= 0: break
			var pick: Dictionary = living[int(gs.next_random() % living.size())]
			gs.VerifiedRules.base_damage_unit(gs, owner, src, 1-owner, gs._unit_index_by_uid(1-owner, pick.uid), 1)

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("langyaziRules", false): return null
	var id := str(card.get("id",""))
	if id == "c61501":
		if gs.VerifiedRules.ArmorBlood.realm_veil(gs, 1-owner): return []
		var out: Array = []
		for r in gs.player(1-owner).realms:
			if int(r.hp)>0: out.append(str(r.uid))
		return out
	if id in ["c61502","c61503","c61504"]:
		return gs.player(1-owner).units.filter(func(u): return int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u): return str(u.uid))
	return null

static func play_block(gs, owner: int, src: int, card: Dictionary) -> String:
	if not card.get("langyaziRules", false): return ""
	if card.id == "meizhou": return "寐咒由琅琊子的能力召唤。"
	if card.id == "c61506" and gs.player(owner).units[src].awakened: return "琅琊子已经觉醒。"
	if card.get("effect") != "ly-summon-curse": return ""
	var kind := str(card.effects[0].curse)
	return "敌方已有该咒印。" if has_curse(gs, 1-owner, kind) else ""

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("langyaziRules", false): return card
	var out := card.duplicate(true)
	if str(card.id) == "c61504":
		var total: int = gs.player(0).realms.size() + gs.player(1).realms.size()
		out.currentCardStats = "当前场上幻境总数：%d" % total
	return out

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("id","") == "ly-changshengdan":
		var u: Dictionary = gs.player(owner).units[src]
		if int(u.hp) <= 0: gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)

static func prevents_lethal(gs, owner: int, idx: int, amount: int) -> bool:
	var u: Dictionary = gs.player(owner).units[idx]
	if not u.get("formRules",{}).get("lyChangshengdan",false) or int(u.hp)<=0: return false
	if amount < int(u.hp): return false
	gs.VerifiedRules.Forms.remove(gs, owner, idx, "长生丹替身")
	u.hp = 6
	gs.VerifiedRules.event(gs,"ly-changshengdan-used",{"player":owner,"uid":u.uid})
	return true

static func form_removed(gs, owner: int, form_rules: Dictionary) -> void:
	if not form_rules.get("lyChangshengdan", false): return
	if not has_curse(gs, 1-owner, "yongshengzhou"):
		summon_curse(gs, 1-owner, "yongshengzhou", "", owner)

static func reduce_damage(u: Dictionary, amount: int) -> int:
	# 坚毅 (束魂): each damage instance reduced by 1, floor 0.
	if u.get("lySoul", false) and Content.runtime_unit_def(u).get("formRules", {}).get("lyResolute", false):
		return maxi(0, amount - 1)
	return amount

static func can_front(u: Dictionary) -> bool:
	return not u.get("lySoul", false) or not Content.runtime_unit_def(u).get("formRules", {}).get("lyCannotBlock", false)

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("curseKind", "") != "meizhou": return false
	gs._damage_avatar(owner, 1, owner, -1, false, false, false, 2)
	return true

static func combat_finished(gs, owner: int, src: int) -> void:
	if not gs.VerifiedRules.OwlInsect.shikigami(gs.player(owner).units[src]): return
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm","") == "langyazi-mirage" and int(realm.hp)>0 and int(realm.get("usedTurn",-1)) != gs.turn_counter:
			realm.usedTurn = gs.turn_counter
			gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1, 1)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var action := str(effect.get("action",""))
	if not action.begins_with("ly-"): return false
	match action:
		"ly-form": gs._apply_form(owner, src, card)
		"ly-destroy-realm":
			var idx := -1
			for i in gs.player(1-owner).realms.size():
				if str(gs.player(1-owner).realms[i].uid) == str(target_id): idx = i; break
			if idx >= 0:
				var realm: Dictionary = gs.player(1-owner).realms[idx]
				var is_curse: bool = realm.get("nativeRealm","") == "langyazi-curse"
				gs.VerifiedRules.Huang.destroy(gs, 1-owner, realm, "钱眼")
				if is_curse: gs._draw(owner, 1)
		"ly-summon-curse":
			var kind := str(effect.get("curse",""))
			var tuid := str(target_id) if target_id != null else ""
			summon_curse(gs, 1-owner, kind, tuid, owner)
		"ly-awaken": gs._awaken(owner, src, card, {"attack":1,"hp":1})
		"ly-dongtian":
			gs._deploy_realm(owner, card)
			var pool: Array = []
			for k in CURSES:
				if int(CURSES[k].level) <= 2 and not (CURSES[k].unique and has_curse(gs,1-owner,k)): pool.append(k)
			if not pool.is_empty():
				var kind: String = pool[int(gs.next_random() % pool.size())]
				var living: Array = gs.player(1-owner).units.filter(func(t): return int(t.hp)>0 and not t.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(t))
				var tuid := str(living[int(gs.next_random() % living.size())].uid) if not living.is_empty() else ""
				summon_curse(gs, 1-owner, kind, tuid, owner)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("langyaziRules", false): return null
	var id := str(card.id)
	if id == "c61501":
		return 70 if not gs.player(1-owner).realms.is_empty() else -100
	if id == "c61508": return 85
	if id == "c61506": return 75
	if id in ["c61502","c61503","c61504"]:
		var t: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, str(target_id))
		return 60 + int(t.get("attack",0)) if not t.is_empty() else -100
	return 50

static func marks(gs, owner: int, u: Dictionary) -> Array:
	var out: Array = []
	if source(u) and u.awakened: out.append("觉醒：出击/用牌召唤寐咒并随机分配咒印数伤害")
	if source(u) and int(u.get("lyPassiveTurn", -1)) == gs.turn_counter: out.append("本回合已触发寐咒")
	if not can_front(u): out.append("无法阻挡")
	if reduce_damage(u, 1) == 0: out.append("坚毅：受到伤害-1")
	if u.get("formRules",{}).get("lyChangshengdan",false): out.append("长生丹：致命伤害替身，生命变为6")
	return out
