class_name WisdomLampRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")

static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)

# Keep turn-tagged source identities in saved player state, independent of the
# bounded presentation event log and of whether the observer was alive then.
static func avatar_damaged(gs, victim: int, owner: int, src: int, amount: int, combat: bool) -> void:
	if not combat or amount<=0:return
	var p:Dictionary=gs.player(victim)
	if not p.has("wlDamageHistory"):p.wlDamageHistory={}
	var turn:=str(gs.turn_counter)
	for key in p.wlDamageHistory.keys():
		if int(key)<gs.turn_counter-1:p.wlDamageHistory.erase(key)
	if not p.wlDamageHistory.has(turn):p.wlDamageHistory[turn]=[]
	if owner<0 or src<0 or src>=gs.player(owner).units.size():return
	var u:Dictionary=gs.player(owner).units[src]
	if gs.VerifiedRules.OwlInsect.shikigami(u) and not p.wlDamageHistory[turn].has(str(u.uid)):p.wlDamageHistory[turn].append(str(u.uid))

static func damaged_last_turn(gs, owner: int) -> bool:
	return gs.player(owner).get("wlDamageHistory",{}).has(str(gs.turn_counter-1))

static func last_sources(gs, owner: int) -> Array:
	return gs.player(owner).get("wlDamageHistory",{}).get(str(gs.turn_counter-1),[])

static func begin_turn(gs, owner: int) -> void:
	if not damaged_last_turn(gs,owner):return
	for i in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[i]
		if not active(u) or not Content.runtime_unit_def(u).get("wisdomLampRules",false):continue
		if u.awakened:gs.VerifiedRules.HairPower.grant_guard(gs,owner,2,2)
		else:
			gs.resolution_stack.append({"kind":"wl-move","playerIndex":owner,"sourceIndex":i})

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id") == "c60802":
		return Choice.targetable_shikigami(gs, owner, 1-owner).map(func(u): return u.uid)
	if card.get("id") == "c60806":
		return gs.player(owner).units.filter(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)).map(func(u): return u.uid)
	if card.get("id","")!="c60801":return null
	var out:Array=[]
	if not damaged_last_turn(gs,owner):return out
	for side in [owner,1-owner]:
		for u in gs.player(side).units:
			if int(u.hp)<=0 or u.get("removed",false) or not gs.VerifiedRules.OwlInsect.shikigami(u):continue
			if side!=owner and (gs.VerifiedRules.Combat.has(u,"veil") or gs.VerifiedRules.Movement.has_veil(u)):continue
			if last_sources(gs,owner).has(str(u.uid)):out.append(str(u.uid))
	return out

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("id","")!="c60804":return true
	var src:int=gs._source_index(owner,card)
	return src>=0 and not gs.player(owner).units[src].awakened

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("wisdomLampRules",false):return card
	var out:=card.duplicate(true)
	if card.id=="c60801":out.currentCardStats="上回合战伤来源：%d个合法目标"%targets(gs,owner,card).size()
	if card.id=="c60803":
		var src:int=gs._source_index(owner,card)
		var enhanced:bool=src>=0 and int(gs.player(owner).units[src].front)==1
		out.combatOption.wlHeal=enhanced
		out.currentCardStats="增强已生效：战斗结束为你和慧明灯恢复3生命" if enhanced else "增强未生效：慧明灯不在战斗区"
	return out

static func form_entered(gs, owner: int, _src: int, card: Dictionary) -> void:
	if card.get("id","")=="c60805":gs.VerifiedRules.HairPower.grant_guard(gs,owner,2)

static func guard_bonus(u: Dictionary) -> int:
	return 2 if active(u) and u.get("formRules",{}).get("wlKarma",false) else 0

static func protected(gs, owner: int, u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and not u.get("removed",false) and int(u.get("shield",0))>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and gs.player(owner).realms.any(func(r):return int(r.hp)>0 and r.get("nativeRealm","")=="wisdom-lamp")

static func damage_limit(gs, owner: int, u: Dictionary, amount: int) -> int:
	return mini(amount,int(u.shield)) if protected(gs,owner,u) else amount

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm","")!="wisdom-lamp":return false
	gs.VerifiedRules.HairPower.grant_guard(gs,owner,2,2)
	return true

static func end_turn(gs, owner: int) -> void:
	for i in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[i]
		if active(u) and u.get("formRules",{}).get("wlMindful",false):
			gs.resolution_stack.append({"kind":"wl-project","playerIndex":owner,"sourceIndex":i,"amount":maxi(0,gs.VerifiedRules.HairPower.amount(u))})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind","") not in ["wl-move","wl-project"]:return false
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var u:Dictionary=gs.player(owner).units[src]
	if not active(u):return true
	if frame.kind=="wl-move":
		if gs.VerifiedRules.Movement.move_to(gs,owner,src,1):
			u.wlEnteredTurn=gs.turn_counter
			gs.VerifiedRules.HairPower.give(gs,owner,src,1)
	else:
		var old:Dictionary=gs._card_effect_context;gs._card_effect_context={}
		gs.VerifiedRules.ThreeTail.projectile(gs,owner,src,int(frame.amount),"正念")
		gs._heal_avatar(owner,int(frame.amount))
		gs._card_effect_context=old
	return true

static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.get("wlHeal",false):return
	gs._heal_avatar(owner,3)
	gs._heal_unit(gs.player(owner).units[src],3)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.get("action","")):
		"wl-destroy":
			if not targets(gs,owner,card).has(str(target_id)):return true
			for side in [owner,1-owner]:
				var idx:int=gs._unit_index_by_uid(side,str(target_id))
				if idx>=0:gs.VerifiedRules.Panguan.destroy(gs,owner,src,side,idx,card);break
		"wl-enrage":
			gs.VerifiedRules.HairPower.grant_guard(gs,owner,2)
			gs.VerifiedRules.MonkCleaner.enrage(gs,1-owner,gs._unit_index_by_uid(1-owner,str(target_id)))
		"wl-awaken":gs._awaken(owner,src,card,{"attack":1,"hp":1})
		"wl-form":gs._install_form(owner,src,card,effect.value)
		"wl-revive":
			gs.VerifiedRules.HairPower.grant_guard(gs,owner,1,1)
			var idx:int=gs._unit_index_by_uid(owner,str(target_id))
			if idx>=0:gs.VerifiedRules.Peach.revive(gs,owner,idx,gs.player(owner).units[idx],false,false)
		"wl-realm":
			gs._deploy_realm(owner,card)
			gs.VerifiedRules.HairPower.grant_guard(gs,owner,2,2)
		_:return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("wisdomLampRules",false):return null
	if card.id=="c60801":
		var target:Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return -100 if target.is_empty() or protected(gs,1-owner,target) else 80+int(target.attack)+int(target.hp)
	if card.id=="c60806":return 80
	if card.id=="c60804":return 70
	return 45

static func marks(gs, owner: int, u: Dictionary) -> Array:
	var out:Array=[]
	if protected(gs,owner,u):out.append("明识灯：免疫消灭·伤害上限%d"%int(u.shield))
	if last_sources(gs,1-owner).has(str(u.uid)):out.append("上回合对敌方牌手造成战斗伤害")
	return out
