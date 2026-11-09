class_name StarBearRules
extends RefCounted
## 星熊：压制与鼓舞共用有符号出击加成；酒碗在防护结算之前换受伤者。
const Content := preload("res://scripts/content_loader.gd")

static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("baseRulesSuppressed",false)

static func role(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("starBearRules",false))

static func power(u: Dictionary) -> int:
	return int(u.get("starTargetPower",0))

static func suppress(gs, owner: int, attack: int, armor_break: int) -> void:
	var use: Dictionary=gs.kw_usage(1-owner,"encourage")
	use.attack=int(use.get("attack",0))-attack
	use.shield=int(use.get("shield",0))-armor_break
	gs.VerifiedRules.event(gs,"star-suppression",{"player":owner,"victimPlayer":1-owner,"attack":attack,"armorBreak":armor_break,"netAttack":use.attack,"netShield":use.shield})
	gs._log("%s 压制：敌方出击加成变为%+d力量/%+d护甲。" % [gs.player(owner).name,int(use.attack),int(use.shield)],gs.TONE_CARD)

static func turn_start(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if active(u) and role(u): suppress(gs,owner,1 if u.awakened else 0,1)
	for src in gs.player(1-owner).units.size():
		var u: Dictionary=gs.player(1-owner).units[src]
		if not active(u) or not u.get("formRules",{}).get("starDiscord",false): continue
		var pool: Array=[]
		for i in gs.player(owner).units.size():
			if int(gs.player(owner).units[i].hp)>0: pool.append(i)
		if pool.is_empty(): continue
		var idx: int=pool[gs.next_random()%pool.size()]
		gs.VerifiedRules.MonkCleaner.enrage(gs,owner,idx)
		gs.VerifiedRules.event(gs,"star-discord",{"player":1-owner,"uid":u.uid,"target":gs.player(owner).units[idx].uid})

static func card_announced(gs, owner: int, _src: int, card: Dictionary) -> void:
	if card.get("type")!="combat": return
	for i in gs.player(1-owner).units.size():
		var u: Dictionary=gs.player(1-owner).units[i]
		if not active(u): continue
		var cfg: Dictionary=u.get("formRules",{})
		if cfg.get("starNoViolence",false):
			gs._damage_avatar(owner,2,1-owner,i)
			gs._heal_avatar(1-owner,2)
			gs.VerifiedRules.event(gs,"star-no-violence",{"player":1-owner,"uid":u.uid})
		elif cfg.get("starLeisure",false):
			gs._grow_unit(u,2,2)
			gs.VerifiedRules.event(gs,"star-leisure",{"player":1-owner,"uid":u.uid})

static func locked(gs, owner: int, u: Dictionary) -> bool:
	if not u.get("enraged",false): return false
	return gs.player(1-owner).units.any(func(other):return active(other) and other.get("formRules",{}).get("starDiscord",false))

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	var src: int=gs._source_index(owner,card)
	if src<0: return true
	var u: Dictionary=gs.player(owner).units[src]
	return not locked(gs,owner,u) and not (card.get("effect")=="star-awaken" and u.get("awakened",false))

static func basic_target(gs, owner: int):
	var mark: Dictionary=gs.player(owner).get("starTarget",{})
	if mark.is_empty() or int(mark.get("turn",-1))!=gs.turn_counter: return null
	var idx: int=gs._unit_index_by_uid(1-owner,str(mark.uid))
	if idx<0 or int(gs.player(1-owner).units[idx].hp)<=0: return null
	return str(mark.uid)

static func before_basic_attack(gs, owner: int, src: int, bonus: int, pierce: bool, remote: bool, combo: bool, first_strike: bool, target_id, crit: bool, options: Dictionary) -> bool:
	if not options.get("basicAttack",false) or options.get("starResponseChecked",false): return false
	var checked:=options.duplicate(true); checked.starResponseChecked=true
	var continuation: Dictionary={"kind":"star-basic-attack-resume","playerIndex":owner,"sourceIndex":src,"bonus":bonus,"pierce":pierce,"remote":remote,"combo":combo,"firstStrike":first_strike,"targetId":target_id,"crit":crit,"options":checked}
	return gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-basic-attack",gs.player(owner).units[src].uid,continuation)

static func bowl(gs) -> Dictionary:
	var best: Dictionary={}; var serial: int=-1
	for owner in gs.players.size():
		for idx in gs.player(owner).units.size():
			var u: Dictionary=gs.player(owner).units[idx]
			if int(u.hp)<=0 or int(u.frozen)<=0 or not u.has("starBowlSerial"): continue
			if int(u.starBowlSerial)>serial:
				serial=int(u.starBowlSerial); best={"player":owner,"index":idx,"uid":str(u.uid)}
	return best

static func redirect(gs, victim: int, idx: int, amount: int, owner: int, src: int, combat: bool, critical: bool = false):
	if amount<=0 or gs.winner>=0: return null
	var marked:=bowl(gs)
	if marked.is_empty() or (int(marked.player)==victim and int(marked.index)==idx): return null
	# A single replacement chain visits each character at most once. This also
	# prevents the bowl and a protecting monk from repeatedly redirecting back.
	if str(marked.uid) in gs._shell_redirect_chain: return null
	var original: String="avatar-%d"%victim if idx<0 else str(gs.player(victim).units[idx].uid)
	var old: Array=gs._shell_redirect_chain
	gs._shell_redirect_chain=old.duplicate(); gs._shell_redirect_chain.append(original); gs._shell_redirect_chain.append(str(marked.uid))
	var result: Dictionary=gs._damage_unit(int(marked.player),int(marked.index),amount,owner,src,combat,-1,false,critical,true)
	gs._shell_redirect_chain=old
	result=result.duplicate(true)
	result.redirected=true
	result.redirectedPlayer=int(result.get("redirectedPlayer",marked.player))
	result.redirectedIndex=int(result.get("redirectedIndex",marked.index))
	result.redirectedTarget=str(gs.player(result.redirectedPlayer).units[result.redirectedIndex].uid)
	gs.VerifiedRules.event(gs,"star-bowl-redirected",{"player":int(marked.player),"uid":str(marked.uid),"target":original,"victimPlayer":victim,"amount":amount,"combat":combat})
	return result

static func consumed_armor(u: Dictionary, amount: int) -> void:
	if u.has("starTargetArmor"): u.starTargetArmor=maxi(0,int(u.starTargetArmor)-amount)

static func consumed_break(u: Dictionary, amount: int) -> void:
	if u.has("starTargetBreak"): u.starTargetBreak=maxi(0,int(u.starTargetBreak)-amount)

static func expire_turn(gs) -> void:
	for p in gs.players:
		p.erase("starTarget")
		for u in p.units:
			if not u.has("starTargetTurn"): continue
			u.shield=maxi(0,int(u.shield)-int(u.get("starTargetArmor",0)))
			u.armorBreak=maxi(0,int(u.armorBreak)-int(u.get("starTargetBreak",0)))
			for key in ["starTargetTurn","starTargetPower","starTargetArmor","starTargetBreak"]: u.erase(key)
			gs._recalc(u); gs.VerifiedRules.ArmorBlood.armor_changed(gs,u)
	gs.VerifiedRules.Poison.refresh_all(gs)

static func knocked_out(u: Dictionary) -> void:
	for key in ["starTargetTurn","starTargetPower","starTargetArmor","starTargetBreak","starBowlSerial"]: u.erase(key)

static func targets(gs, owner: int, card: Dictionary):
	var effect := str(card.get("effect", ""))
	if effect not in ["star-talk", "star-focus", "star-bowl"]: return null
	var ids: Array = []
	for side in ([owner, 1-owner] if effect == "star-talk" else [1-owner]):
		for u in gs.player(side).units:
			if int(u.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
			if side != owner and (gs.VerifiedRules.Combat.has(u, "veil") or gs.VerifiedRules.Movement.has_veil(u)): continue
			ids.append(str(u.uid))
	return ids

static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("starBearCard",false): return card
	var out:=card.duplicate(true)
	if card.get("effect")=="star-focus":
		var use: Dictionary=gs.kw_usage(1-owner,"encourage")
		out.starNetAttack=int(use.get("attack",0)); out.starNetShield=int(use.get("shield",0))
	return out

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, _target_id = null) -> bool:
	match str(effect.get("action","")):
		"star-talk":
			suppress(gs,owner,1,1)
			for side in gs.players.size():
				var idx: int=gs._unit_index_by_uid(side,str(target.get("uid","")))
				if idx>=0: gs.VerifiedRules.MonkCleaner.enrage(gs,side,idx)
		"star-spare": suppress(gs,owner,2,2)
		"star-awaken":
			suppress(gs,owner,10,0)
			gs._awaken(owner,src,card,card.value)
		"star-focus":
			if target.is_empty() or int(target.hp)<=0: return true
			var use: Dictionary=gs.kw_usage(1-owner,"encourage")
			var attack:=int(use.get("attack",0)); var shield:=int(use.get("shield",0))
			target.starTargetPower=int(target.get("starTargetPower",0))+attack
			target.starTargetTurn=gs.turn_counter
			if shield>0:
				var gained: int=gs._grant_unit_armor(target,shield,false)
				target.starTargetArmor=int(target.get("starTargetArmor",0))+gained
			elif shield<0:
				var before:=int(target.armorBreak)
				var idx: int=gs._unit_index_by_uid(1-owner,str(target.uid))
				gs.VerifiedRules.ArmorBreak.give(gs,owner,src,1-owner,idx,-shield,false)
				target.starTargetBreak=int(target.get("starTargetBreak",0))+maxi(0,int(target.armorBreak)-before)
			gs.player(owner).starTarget={"uid":str(target.uid),"turn":gs.turn_counter}
			gs._recalc(target)
			gs.VerifiedRules.event(gs,"star-focus",{"player":owner,"target":target.uid,"attack":attack,"shield":shield})
		"star-bowl":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target.get("uid","")))
			if idx<0: return true
			gs.VerifiedRules.Stun.apply(gs,1-owner,idx,1,owner)
			target.starBowlSerial=gs.next_rule_event_id
			gs.VerifiedRules.event(gs,"star-bowl",{"player":owner,"target":target.uid})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="star-basic-attack-resume": return false
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex)
	if gs.VerifiedRules.Samurai.available(gs.player(owner).units[src]) and gs.winner<0:
		gs._resolve_combat(owner,src,int(frame.bonus),bool(frame.pierce),bool(frame.remote),bool(frame.combo),bool(frame.firstStrike),frame.targetId,bool(frame.crit),frame.options)
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("starBearCard",false): return null
	var enemy: Dictionary=gs.player(1-owner)
	var target: Dictionary=gs._unit_by_uid(enemy.units,target_id)
	match str(card.get("effect","")):
		"star-talk": return 48+(12 if not target.is_empty() and not target.get("enraged",false) else 0)
		"star-spare": return 56
		"star-awaken": return 76
		"star-focus": return -100 if target.is_empty() else 45+maxi(0,-int(gs.kw_usage(1-owner,"encourage").get("shield",0)))*3-int(target.hp)
		"star-bowl": return -100 if target.is_empty() else 72+mini(20,int(target.hp))+int(target.shield)
		"form-set": return 66 if card.get("formRules",{}).get("starDiscord",false) else 54
	return 40
