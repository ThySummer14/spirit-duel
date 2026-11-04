class_name SilkNinjaRules
extends RefCounted
## 於菊虫与海忍共用真实中毒状态；气绝历史属于牌手，不随式神气绝清除。
const Content := preload("res://scripts/content_loader.gd")
static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("silkNinjaRole",""))
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("silkNinjaRules",false):return card
	var c:=card.duplicate(true);var p:Dictionary=gs.player(owner)
	if c.get("silkBounce",false):
		c.silkInstance=inst.duplicate(true);c.silkReturn=not inst.get("silkBounceSpent",false)
		if not c.silkReturn:
			c.keywords=c.keywords.filter(func(k):return k!="bounce")
			c.text=c.text.replace("弹回\n","")+"\n此实例已失去弹回。"
	if c.id=="c28508":
		var n:=int(p.get("toxicEnemyDeaths",0));c.effects[0].value=5+n;c.value=5+n;c.enhanced=n>0
		c.currentCardStats="中毒敌方气绝%d次 · 投射%d点剧毒"%[n,5+n];c.text+="\n"+c.currentCardStats
	if c.id=="c28603" and int(inst.get("ninjaInstantTurn",-1))==gs.turn_counter:
		if "instant" not in c.keywords:c.keywords.append("instant")
		c.enhanced=true;c.currentCardStats="本回合中毒敌方气绝 · 瞬发";c.text+="\n"+c.currentCardStats
	return c
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("silkReturn",false) or frame.get("automatic",false):return
	for i in gs.resolution_stack.size():
		var f:Dictionary=gs.resolution_stack[i]
		if f.get("kind")=="card-complete" and f.get("resolutionId")==frame.resolutionId:
			gs.resolution_stack.insert(i,{"kind":"silk-bounce","playerIndex":int(frame.playerIndex),"instance":card.silkInstance.duplicate(true)});return
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("silkNinjaRules",false) or card.get("target","auto")=="auto":return null
	var result:Array=[]
	for side in ([owner,1-owner] if card.target=="any-living-unit" else [1-owner]):
		for u in gs.player(side).units:
			if int(u.hp)<=0 or u.get("removed",false):continue
			if side!=owner and gs.VerifiedRules.Combat.has(u,"veil"):continue
			if card.target=="unpoisoned-enemy-unit" and u.get("toxicPoisoned",false):continue
			result.append(u.uid)
	if card.target=="pursuit-enemy" and gs.front_index(1-owner)<0:result.append("avatar-%d"%(1-owner))
	return result
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("id","") not in ["c28506","c28604"] or not gs.player(owner).units[gs._source_index(owner,card)].awakened
static func knockout_extra(gs, victim: int, u: Dictionary) -> int:
	if victim<0 or not u.get("toxicPoisoned",false):return 0
	var n:=0
	for observer in gs.player(1-victim).units:
		if active(observer) and observer.get("formRules",{}).get("silkNight",false):n+=1
	return n
static func death_frames(gs, victim: int, u: Dictionary) -> Array:
	if victim<0 or not u.get("toxicPoisoned",false):return []
	var owner:=1-victim;var p:Dictionary=gs.player(owner);var frames:Array=[]
	p.toxicEnemyDeaths=int(p.get("toxicEnemyDeaths",0))+1
	for inst in p.hand:
		if inst.definitionId=="c28603":inst.ninjaInstantTurn=gs.turn_counter
	for src in p.units.size():
		var observer:Dictionary=p.units[src]
		if not active(observer):continue
		if role(observer)=="silk":frames.append({"kind":"silk-drain","playerIndex":owner,"sourceIndex":src,"amount":2 if observer.awakened else 1})
		if observer.get("formRules",{}).get("ninjaLone",false):frames.append({"kind":"silk-lone","playerIndex":owner,"sourceIndex":src})
	if owner==gs.current_player:
		for realm in p.realms:
			if realm.get("nativeRealm")=="silk-dusk" and int(realm.hp)>0:frames.append({"kind":"silk-erosion","playerIndex":owner})
	frames.reverse();return frames
static func turn_start(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[src]
		if active(u) and u.get("formRules",{}).get("ninjaShadow",false):shadow(gs,owner)
static func shadow(gs, owner: int) -> void:
	var p:Dictionary=gs.player(owner);var inst:Dictionary={"instanceId":"silk-shadow-%d"%gs.next_card_id,"definitionId":"c28602"};gs.next_card_id+=1
	if p.hand.size()<int(gs.rules.maxHandSize):p.hand.append(inst)
	gs.VerifiedRules.event(gs,"silk-shadow-created",{"player":owner,"instanceId":inst.instanceId,"card":Content.card_def("c28602")})
static func attack_combo(u: Dictionary) -> bool:
	return active(u) and u.get("formRules",{}).get("attackCombo",false)
static func prepare_combat(gs, frame: Dictionary) -> void:
	if frame.options.has("silkCombatId"):return
	var owner:=int(frame.playerIndex);var u:Dictionary=gs.player(owner).units[int(frame.sourceIndex)];var enemy:Dictionary=gs.player(int(frame.options.get("combatVictim",1-owner))).units[int(frame.defenderIndex)]
	if role(u)!="ninja" and role(enemy)!="ninja":return
	frame.options.silkCombatId=gs.next_resolution_id;gs.next_resolution_id+=1
	# The base ability checks the target when attacking, before newly applied poison.
	if int(frame.options.get("combatVictim",1-owner))!=owner and role(u)=="ninja" and active(u) and not u.awakened and enemy.get("toxicPoisoned",false) and int(u.get("ninjaImmuneTurn",-1))!=gs.turn_counter:
		u.ninjaImmuneTurn=gs.turn_counter;frame.options.immuneCombat=true
		gs.VerifiedRules.event(gs,"ninja-immunity",{"player":owner,"uid":u.uid,"turn":gs.turn_counter})
static func damage_immune(gs, owner: int, src: int, victim: int, idx: int, power: int, options: Dictionary) -> bool:
	if idx<0 or power<=0 or owner==victim:return false
	var u:Dictionary=gs.player(victim).units[idx];var enemy:Dictionary=gs.player(owner).units[src]
	if role(u)!="ninja" or not active(u) or not u.awakened:return false
	if not enemy.get("toxicPoisoned",false) and not options.get("sourceWasPoisoned",false):return false
	var combat_id:=int(options.get("silkCombatId",-1))
	if int(u.get("ninjaImmuneTurn",-1))==gs.turn_counter:return combat_id>=0 and int(u.get("ninjaImmuneCombat",-2))==combat_id
	u.ninjaImmuneTurn=gs.turn_counter;u.ninjaImmuneCombat=combat_id
	gs.VerifiedRules.event(gs,"ninja-immunity",{"player":victim,"uid":u.uid,"turn":gs.turn_counter})
	return true
static func projectile(gs, owner: int, src: int, amount: int, pierce: bool) -> void:
	var enemy:=1-owner;var idx:int=gs.front_index(enemy);var old:Dictionary=gs._toxic_damage_context
	gs._toxic_damage_context={"playerIndex":owner,"sourceIndex":src}
	if idx<0:gs._damage_avatar(enemy,amount,owner,src)
	else:
		var u:Dictionary=gs.player(enemy).units[idx]
		var modified:int=maxi(0,amount+gs.VerifiedRules.HandBlessing.damage_delta(gs,owner,src,false))+gs.VerifiedRules.Maple.damage_bonus(gs,owner,src,false)
		var overflow:int=maxi(0,gs.VerifiedRules.OwlInsect.reduced(u,gs.VerifiedRules.Jorogumo.received_damage(u,maxi(0,modified+int(u.armorBreak)-int(u.shield))))-int(u.hp)) if pierce else 0
		gs._damage_unit(enemy,idx,amount,owner,src)
		if overflow>0:gs._damage_avatar(enemy,overflow,owner,src,false,false,true)
	gs._toxic_damage_context=old
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary) -> bool:
	match str(effect.get("action","")):
		"silk-projectile":
			var front:Dictionary=gs.front_unit(1-owner)
			projectile(gs,owner,src,int(effect.value),card.id=="c28508" and front.get("toxicPoisoned",false))
		"silk-daydream":
			var targets:Array=gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and not u.get("removed",false)).map(func(u):return {"uid":u.uid,"poisoned":u.get("toxicPoisoned",false)})
			for t in targets:
				var u:Dictionary=gs._unit_by_uid(gs.player(1-owner).units,t.uid)
				if int(u.hp)<=0:continue
				if t.poisoned:gs.VerifiedRules.Toxic.damage(gs,owner,src,u,int(effect.value))
				else:gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,u.uid),int(effect.value),owner,src)
		"silk-awaken":gs._awaken(owner,src,card,effect.value)
		"silk-shadow":shadow(gs,owner)
		_:return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind:=str(f.get("kind",""))
	if not kind.begins_with("silk-"):return false
	var owner:=int(f.playerIndex);var src:=int(f.get("sourceIndex",-1));var old:Dictionary=gs._card_effect_context
	gs._card_effect_context={}
	match kind:
		"silk-drain":
			gs.VerifiedRules.base_damage_avatar(gs,owner,src,1-owner,int(f.amount));gs._heal_avatar(owner,int(f.amount))
		"silk-erosion":gs.VerifiedRules.HandBlessing.start(gs,owner,"erosion")
		"silk-lone":
			var u:Dictionary=gs.player(owner).units[src]
			if active(u):
				u.permanentAttack=int(u.get("permanentAttack",0))+1;gs._recalc(u)
				gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"immuneCombat":true})
		"silk-bounce":
			var inst:Dictionary=f.instance.duplicate(true);inst.silkBounceSpent=true
			if gs.player(owner).hand.size()<int(gs.rules.maxHandSize):gs.player(owner).hand.append(inst)
			gs.VerifiedRules.event(gs,"silk-card-returned",{"player":owner,"instanceId":inst.instanceId})
		"silk-attack-ready":gs._resolve_combat_ready(f.combat)
		_:gs._card_effect_context=old;return false
	gs._card_effect_context=old;return true
static func before_response(gs, frame: Dictionary) -> bool:
	if frame.get("silkResponseChecked",false):return false
	frame.silkResponseChecked=true
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex)
	if not gs.player(owner).units[src].get("toxicPoisoned",false):return false
	return gs.VerifiedRules.automatic_response(gs,1-owner,"toxic-enemy-attacking",gs.player(owner).units[src].uid,{"kind":"silk-attack-ready","playerIndex":owner,"combat":frame.duplicate(true)})
static func marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx]
	if role(u)=="silk":return ["中毒敌方气绝%d次 · 破茧投射%d"%[int(gs.player(owner).get("toxicEnemyDeaths",0)),5+int(gs.player(owner).get("toxicEnemyDeaths",0))]]
	if role(u)=="ninja":return ["本回合中毒免战伤 · "+("已用" if int(u.get("ninjaImmuneTurn",-1))==gs.turn_counter else "可用")]
	return []
static func score_card(gs, owner: int, card: Dictionary, target):
	if not card.get("silkNinjaRules",false):return null
	if target!=null and gs._unit_index_by_uid(owner,target)>=0:return -70
	if card.type=="form":return -40 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 70
	return 80
