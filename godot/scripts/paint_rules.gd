class_name PaintRules
extends RefCounted
## 花鸟卷基础快照：融合画境、耐久兑现与丹青绘卷完整生命周期。
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("paintBasic",false)
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)
static func field(gs, owner: int) -> Dictionary:
	for r in gs.player(owner).realms:
		if r.get("nativeRealm")=="paint" and int(r.hp)>0: return r
	return {}
static func durability(gs, owner: int) -> int:
	return int(field(gs,owner).get("hp",0))
static func awakened(gs, owner: int, src: int) -> bool:
	return src>=0 and source(gs.player(owner).units[src]) and gs.player(owner).units[src].awakened
static func summon_field(gs, owner: int, src: int, amount: int = 2, exact: bool = false) -> Dictionary:
	if not exact and awakened(gs,owner,src): amount=3
	if amount<=0: return {}
	var old:=field(gs,owner)
	var realm: Dictionary=old.duplicate(true) if not old.is_empty() else {"sourceUnit":"huaniajuan","cardId":"c22901","name":"画境","nativeRealm":"paint","trigger":"native-continuous","triggerEffect":"","triggerValue":0,"triggerEffects":[],"countdown":0,"countdownReset":0,"handCountdown":0,"avatarLinked":false,"returnOnDestroy":false,"returnInstance":{}}
	var old_uid:=str(old.get("uid",""))
	if not old.is_empty(): gs.player(owner).realms.erase(old)
	realm.uid="realm-%s-paint-%d" % [gs.player(owner).id,gs.next_card_id]; gs.next_card_id+=1
	realm.hp=int(old.get("hp",0))+amount
	gs.player(owner).realms.append(realm)
	gs.VerifiedRules.Night.refresh(gs); gs.VerifiedRules.MonkCleaner.refresh(gs)
	gs._fire_hooks(owner,-1,"realm-deployed",{})
	gs.VerifiedRules.event(gs,"paint-summoned",{"player":owner,"realm":realm.uid,"amount":amount,"remaining":realm.hp,"merged":not old.is_empty(),"previousRealm":old_uid})
	return realm
static func consume(gs, owner: int) -> int:
	var realm:=field(gs,owner)
	var amount:=int(realm.get("hp",0))
	if amount>0:
		# 移除不是消灭，不记录峰回路转，也不触发被消灭能力。
		gs.player(owner).realms.erase(realm)
		gs.VerifiedRules.Night.refresh(gs); gs.VerifiedRules.MonkCleaner.refresh(gs)
		gs.VerifiedRules.event(gs,"paint-removed",{"player":owner,"realm":realm.uid,"amount":amount})
	return amount
static func can_use(_gs, _owner: int, _card: Dictionary) -> bool:
	return true
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("paintRules",false) or card.get("effect")!="paint-bird": return null
	var result: Array=[]
	for side in [owner,1-owner]:
		for u in gs.player(side).units:
			if int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side==owner or not (gs.VerifiedRules.Combat.has(u,"veil") or gs.VerifiedRules.Movement.has_veil(u))): result.append(str(u.uid))
	return result
static func describe_card(gs, owner: int, entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("paintRules",false): return card
	var view:=card.duplicate(true)
	var n:=durability(gs,owner)
	if card.id=="c22901":
		view.paintInstance=entry.duplicate(true)
		view.paintReturn=not entry.get("paintBounceSpent",false)
		if not view.paintReturn:
			view.keywords=view.keywords.filter(func(k):return k!="bounce")
			view.text=view.text.replace("弹回，","")+"\n此副本已失去弹回。"
		var src: int=gs._source_index(owner,card)
		view.text+="\n本次召唤%d耐久画境。" % (3 if awakened(gs,owner,src) else 2)
	if card.id=="c22902": view.text+="\n当前画境%d耐久，造成%d点伤害。" % [n,n+1]
	if card.id=="c22905": view.text+="\n当前画境%d耐久，共生效%d次。" % [n,1+n/2]
	if card.id=="c22906": view.text+="\n当前召唤%d力量/%d生命丹青绘卷。" % [3+n,3+n]
	if card.id=="c22908": view.text+="\n当前画境%d耐久，投射%d点伤害。" % [n,n]
	return view
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("paintReturn",false): return
	var after: Dictionary={"kind":"paint-return","playerIndex":int(frame.playerIndex),"card":card.duplicate(true)}
	for i in gs.resolution_stack.size():
		var pending: Dictionary=gs.resolution_stack[i]
		if pending.get("kind")=="card-complete" and pending.get("resolutionId")==frame.resolutionId:
			gs.resolution_stack.insert(i,after); return
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("paintSummon",false) or u.get("removed",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	gs.VerifiedRules.event(gs,"paint-scroll-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("paintSummon",false) and (int(u.hp)<=0 or int(u.front)==0): remove_summon(gs,owner,u)
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	remove_summon(gs,owner,u,"召唤物被消灭")
static func summon_scroll(gs, owner: int, src: int, amount: int) -> int:
	var p: Dictionary=gs.player(owner)
	var old: Array=p.units.map(func(u):return int(u.front))
	clear_summons(gs,owner); gs.VerifiedRules.TomatoFire.clear_summons(gs,owner); gs.VerifiedRules.Xuenv.clear_wall(gs,owner)
	for u in p.units:
		if u.get("smokeClone",false): gs.VerifiedRules.SunSmoke.remove_clone(gs,owner,u,"战斗区被替换")
		u.front=0
	gs.VerifiedRules.Bamboo.remove_departed(gs)
	gs.VerifiedRules.Pine.remove_departed(gs)
	var hp:=3+amount
	var u: Dictionary={"uid":"%s:paint-scroll-%d" % [p.id,gs.next_card_id],"id":"paint-scroll","name":"丹青绘卷","title":"花鸟卷召唤物","art":Content.unit_def("huaniajuan").art,"color":"#d4a0b8","baseAttack":hp,"baseMaxHp":hp,"attack":hp,"maxHp":hp,"hp":hp,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"己方回合开始时，自毁并召唤一个耐久等于其生命的画境。离开战斗区移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"paintSummon":true,"summonerUid":p.units[src].uid,"swift":false}
	gs.next_card_id+=1; p.units.append(u)
	gs.VerifiedRules.Enma.remove_departed(gs)
	gs.VerifiedRules.Weaver.remove_departed(gs)
	gs.VerifiedRules.Vine.remove_departed(gs)
	gs.VerifiedRules.WindRaccoon.remove_departed(gs)
	gs.VerifiedRules.House.remove_departed(gs)
	gs.VerifiedRules.Doll.remove_departed(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	for i in old.size(): gs.VerifiedRules.Movement.moved(gs,owner,i,int(old[i]))
	var idx: int=p.units.size()-1
	gs.VerifiedRules.event(gs,"paint-scroll-summoned",{"player":owner,"uid":u.uid,"amount":hp})
	gs._fire_hooks(owner,idx,"unit-entered-front",{}); gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
	return idx
static func turn_start(gs, owner: int) -> void:
	# 基础式神在其后生成的绘卷之前触发；气绝或未激活不生效。
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if source(u) and active(u) and (u.awakened or durability(gs,owner)<10): summon_field(gs,owner,src)
	for u in gs.player(owner).units.duplicate():
		if not u.get("paintSummon",false) or not active(u): continue
		var amount:=int(u.hp)
		var src: int=gs._unit_index_by_uid(owner,str(u.summonerUid))
		remove_summon(gs,owner,u,"己方回合开始自毁")
		# 绘卷自己的召唤不受花鸟卷觉醒的3耐久替换。
		summon_field(gs,owner,src,amount,true)
static func end_turn(gs, current: int) -> void:
	for owner in [current,1-current]:
		for src in gs.player(owner).units.size():
			var u: Dictionary=gs.player(owner).units[src]
			if active(u) and u.get("formRules",{}).get("paintGirl",false) and durability(gs,owner)==0:
				summon_field(gs,owner,src); summon_field(gs,owner,src)
static func _random_character(gs, owner: int, injured: bool = false) -> int:
	var pool: Array=[]
	var p: Dictionary=gs.player(owner)
	if not injured or int(p.avatarHp)<int(p.get("maxAvatarHp",30)): pool.append(-1)
	for i in p.units.size():
		var u: Dictionary=p.units[i]
		if int(u.hp)>0 and not u.get("removed",false) and (not injured or int(u.hp)<int(u.maxHp)): pool.append(i)
	if injured and pool.is_empty(): return _random_character(gs,owner,false)
	return int(pool[int(floor(gs.randf01()*pool.size()))])
static func _fragrance_hit(gs, owner: int, src: int) -> void:
	var idx:=_random_character(gs,1-owner)
	if idx<0: gs._damage_avatar(1-owner,2,owner,src)
	else: gs._damage_unit(1-owner,idx,2,owner,src)
	if gs.winner>=0: return
	var heal:=_random_character(gs,owner,true)
	if heal<0: gs._heal_avatar(owner,2)
	else: gs._heal_unit(gs.player(owner).units[heal],2)
	gs.VerifiedRules.event(gs,"paint-fragrance-hit",{"player":owner,"target":idx,"healed":heal,"remainingPaint":durability(gs,owner)})
static func _soul(gs, owner: int, src: int, amount: int) -> void:
	if amount<=0: return
	var enemy:=1-owner
	amount+=gs.VerifiedRules.Maple.damage_bonus(gs,owner,src,false)
	var idx: int=gs.front_index(enemy)
	var overflow:=0
	if idx>=0:
		var u: Dictionary=gs.player(enemy).units[idx]
		if not u.get("bloodTransfer",false): overflow=maxi(0,amount+int(u.armorBreak)-int(u.shield)-int(u.hp))
		var hit: Dictionary=gs._damage_unit(enemy,idx,amount,owner,src,false,-1,false,false,true)
		if hit.get("redirected",false) or hit.has("transferredDealt"): overflow=0
	else: gs._damage_avatar(enemy,amount,owner,src,false,false,true)
	if overflow>0 and gs.winner<0: gs._damage_avatar(enemy,overflow,owner,src,false,false,true)
	gs.VerifiedRules.event(gs,"paint-soul",{"player":owner,"amount":amount,"overflow":overflow,"targetIndex":idx})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id) -> bool:
	match str(effect.get("action","")):
		"paint-summon": summon_field(gs,owner,src)
		"paint-bird":
			var amount:=1+consume(gs,owner)
			for side in [owner,1-owner]:
				var idx: int=gs._unit_index_by_uid(side,str(target_id))
				if idx<0 or int(gs.player(side).units[idx].hp)<=0: continue
				var hit: Dictionary=gs._damage_unit(side,idx,amount,owner,src)
				if hit.get("knocked",false): gs._draw(owner,1)
		"paint-awaken": gs._awaken(owner,src,card,{"attack":1,"hp":1}); summon_field(gs,owner,src)
		"paint-fragrance":
			# 第一次先结算，再移除画境并按实际剩余耐久快照重复。
			_fragrance_hit(gs,owner,src)
			if gs.winner<0:
				var count:=consume(gs,owner)/2
				for i in count:
					if gs.winner>=0: break
					_fragrance_hit(gs,owner,src)
		"paint-scroll": summon_scroll(gs,owner,src,consume(gs,owner))
		"paint-enter":
			var pool: Array=[]; var lowest:=2147483647
			for i in gs.player(1-owner).units.size():
				var u: Dictionary=gs.player(1-owner).units[i]
				if int(u.hp)<=0 or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
				var power: int=u.attack
				if power<lowest: lowest=power; pool.clear()
				if power==lowest: pool.append(i)
			if not pool.is_empty(): gs.VerifiedRules.Panguan.destroy(gs,owner,src,1-owner,int(pool[int(floor(gs.randf01()*pool.size()))]),card)
			summon_field(gs,owner,src)
		"paint-soul": _soul(gs,owner,src,consume(gs,owner))
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="paint-return": return false
	var owner:=int(frame.playerIndex)
	var card: Dictionary=frame.card
	var entry: Dictionary=card.get("paintInstance",{}).duplicate(true)
	if entry.is_empty(): return true
	entry.paintBounceSpent=true
	if gs.player(owner).hand.size()<int(gs.rules.maxHandSize): gs.player(owner).hand.append(entry)
	else: gs._log("手牌已满，弹回的花鸟风月被烧毁。",gs.TONE_DANGER)
	gs.VerifiedRules.event(gs,"paint-card-returned",{"player":owner,"instanceId":entry.instanceId})
	return true
static func score_card(gs, owner: int, card: Dictionary, target) -> Variant:
	if not card.get("paintRules",false): return null
	var n:=durability(gs,owner)
	match str(card.effect):
		"paint-bird":
			if gs._unit_index_by_uid(owner,str(target))>=0: return -1000
			var idx: int=gs._unit_index_by_uid(1-owner,str(target))
			if idx<0: return -1000
			var u: Dictionary=gs.player(1-owner).units[idx]
			return 35+mini(n+1,int(u.hp))*5+(35 if n+1>=int(u.hp)+int(u.shield) else 0)
		"paint-summon": return 35 if n<10 else 15
		"paint-awaken": return 75
		"paint-fragrance": return 40+n*4
		"paint-scroll": return 40+n*3 if gs.front_index(owner)<0 else 20+n*2
		"paint-enter": return 75 if gs.player(1-owner).units.any(func(u):return int(u.hp)>0) else 15
		"paint-soul": return -100 if n==0 else 30+n*5
	return 45
static func unit_view(gs, owner: int, _idx: int, view: Dictionary) -> Dictionary:
	view.paintDurability=durability(gs,owner)
	return view
static func realm_card(realm: Dictionary, card: Dictionary) -> Dictionary:
	if realm.get("nativeRealm")!="paint": return card
	var view:=card.duplicate(true)
	view.name="画境"; view.type="realm"; view.typeLabel="幻境"; view.keywords=["fusion"]
	view.text="融合。\n召唤新画境时，与已有画境合并，耐久相加；作为最先部署的幻境时承受牌手所受伤害对应的耐久损失。\n当前耐久%d。" % int(realm.hp)
	view.effects=[]; view.realm={"hp":int(realm.hp)}
	return view
