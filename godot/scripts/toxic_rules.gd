class_name ToxicRules
extends RefCounted
## 鸣雷启蛰的剧毒/中毒，与清姬的破甲完全独立。采用完整基础卡面的初版机制。
const Content := preload("res://scripts/content_loader.gd")
static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("toxicRole",""))
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func aura(gs, owner: int, u: Dictionary) -> int:
	if not u.get("toxicPoisoned",false): return 0
	var amount:=0
	for bug in gs.player(1-owner).units:
		if active(bug) and role(bug)=="bug": amount+=2 if bug.awakened else 1
	return amount
static func refresh(gs) -> void:
	for p in gs.players:
		for u in p.units:
			if u.get("toxicPoisoned",false):
				var current_hp:=int(u.hp)
				gs._recalc(u)
				# This refresh changes power only; poison freezes form health resets.
				u.hp=current_hp
static func traits(gs, owner: int, src: int, combat: bool) -> Dictionary:
	var poison:=false; var lethal:=false
	if owner<0 or src<0 or src>=gs.player(owner).units.size(): return {"toxic":false,"lethal":false}
	var u:Dictionary=gs.player(owner).units[src]
	if active(u): poison=u.get("toxicSwarm",false) or (role(u)=="scorpion" and u.awakened) or gs.VerifiedRules.Combat.has(u,"toxic")
	var ctx:Dictionary=gs._card_effect_context
	if not combat and int(ctx.get("playerIndex",-1))==owner and int(ctx.get("sourceIndex",-1))==src:
		var card:Dictionary=ctx.get("cardOverride",{})
		poison=poison or card.get("toxicDamage",false) or "toxic" in card.get("keywords",[])
	if int(gs._toxic_damage_context.get("playerIndex",-1))==owner and int(gs._toxic_damage_context.get("sourceIndex",-1))==src: poison=true
	if combat and owner==gs.current_player:
		for field in gs.player(owner).realms:
			if field.get("nativeRealm")=="bug-dream" and int(field.hp)>0:
				lethal=poison; poison=true; break
	return {"toxic":poison,"lethal":lethal}
static func apply(gs, owner: int, src: int, victim: int, idx: int) -> void:
	var target:Dictionary=gs.player(victim) if idx<0 else gs.player(victim).units[idx]
	var key:="avatarToxicPoisoned" if idx<0 else "toxicPoisoned"
	if target.get(key,false) or (idx>=0 and (int(target.hp)<=0 or target.get("removed",false))):return
	target[key]=true
	if idx>=0:
		var p:Dictionary=gs.player(1-victim)
		if int(p.get("toxicEventTurn",-1))!=gs.turn_counter:p.toxicEventTurn=gs.turn_counter;p.toxicEvents=0
		p.toxicEvents=int(p.get("toxicEvents",0))+1
		for scorpion in p.units:
			if active(scorpion) and scorpion.get("formRules",{}).get("scorpionArmor",false):gs._grant_unit_armor(scorpion,2)
		gs._recalc(target)
	gs.VerifiedRules.event(gs,"toxic-applied",{"player":owner,"uid":"" if src<0 else gs.player(owner).units[src].uid,"victimPlayer":victim,"target":"" if idx<0 else target.uid})
static func executes(gs, owner: int, src: int, victim: int, idx: int, amount: int, combat: bool) -> bool:
	if amount<=0:return false
	var t:=traits(gs,owner,src,combat); var target:Dictionary=gs.player(victim) if idx<0 else gs.player(victim).units[idx]
	return t.toxic and (target.get("avatarToxicPoisoned" if idx<0 else "toxicPoisoned",false))
static func damaged(gs, owner: int, src: int, victim: int, idx: int, amount: int, combat: bool) -> bool:
	if amount<=0 or owner<0 or src<0:return false
	var t:=traits(gs,owner,src,combat)
	if idx>=0 and t.toxic:apply(gs,owner,src,victim,idx)
	var u:Dictionary=gs.player(owner).units[src]
	if combat and owner!=victim and active(u) and u.get("formRules",{}).get("scorpionExtraPoison",false) and int(u.get("scorpionExtraPoisonTurn",-1))!=gs.turn_counter:
		u.scorpionExtraPoisonTurn=gs.turn_counter;apply(gs,owner,src,victim,idx)
	return idx>=0 and t.lethal and int(gs.player(victim).units[idx].hp)>0
static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int, combat: bool) -> void:
	damaged(gs,owner,src,victim,-1,amount,combat)
	if owner<0 or src<0 or owner==victim or amount<=0:return
	for realm in gs.player(victim).realms:
		if realm.get("nativeRealm")=="scorpion-den" and int(realm.hp)>0:gs.resolution_stack.append({"kind":"toxic-den","playerIndex":victim,"sourceIndex":gs._source_index(victim,{"unitId":realm.get("sourceUnit","")}),"targetUid":gs.player(owner).units[src].uid})
static func death_frames(gs, victim: int, u: Dictionary, owner: int, src: int) -> Array:
	var frames:Array=[]
	if victim<0:return frames
	if role(u)=="scorpion" and u.get("formRules",{}).get("scorpionRetaliate",false) and owner==1-victim and src>=0:
		frames.append({"kind":"toxic-retaliate","playerIndex":victim,"sourceIndex":gs._unit_index_by_uid(victim,u.uid),"targetUid":gs.player(owner).units[src].uid})
	if not u.get("toxicPoisoned",false):return frames
	for i in gs.player(1-victim).units.size():
		var bug:Dictionary=gs.player(1-victim).units[i]
		if role(bug)!="bug" or not active(bug):continue
		for pair in [["bugDraw","bugDrawTurn","toxic-draw"],["bugHeal","bugHealTurn","toxic-heal"]]:
			if bug.get("formRules",{}).get(pair[0],false) and int(bug.get(pair[1],-1))!=gs.turn_counter:
				bug[pair[1]]=gs.turn_counter;frames.append({"kind":pair[2],"playerIndex":1-victim,"sourceIndex":i,"amount":maxi(0,int(u.hp))})
		if bug.awakened and int(bug.get("bugFireTurn",-1))!=gs.turn_counter:
			bug.bugFireTurn=gs.turn_counter;frames.append({"kind":"toxic-fire","playerIndex":1-victim,"sourceIndex":i})
	return frames
static func knocked_out(u: Dictionary) -> void:
	u.erase("toxicPoisoned");u.erase("scorpionAttackToxic")
static func damage(gs, owner: int, src: int, target: Dictionary, amount: int) -> void:
	if target.is_empty() or int(target.hp)<=0:return
	var old:Dictionary=gs._toxic_damage_context;gs._toxic_damage_context={"playerIndex":owner,"sourceIndex":src}
	for side in [owner,1-owner]:
		var idx:int=gs._unit_index_by_uid(side,target.uid)
		if idx>=0:
			var hit:Dictionary=gs._damage_unit(side,idx,amount,owner,src)
			if gs._card_effect_context.is_empty() and not hit.get("poisonExecution",false):
				gs.VerifiedRules.event(gs,"damage-resolved",{"player":owner,"uid":gs.player(owner).units[src].uid,"victimPlayer":side,"target":target.uid,"amount":int(hit.damage),"blocked":int(hit.damage)==0,"card":{"id":"toxic-ability","type":"ability","unitId":gs.player(owner).units[src].id,"name":"剧毒"}})
			break
	gs._toxic_damage_context=old
static func random_damage(gs, owner: int, src: int, amount: int) -> void:
	var list:Array=gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and not u.get("removed",false))
	if not list.is_empty():damage(gs,owner,src,list[gs.next_random()%list.size()],amount)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("scorpionMove",false):gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
	if card.get("formRules",{}).get("scorpionExtraPoison",false):gs.player(owner).units[src].unyielding=true
	refresh(gs)
static func remove_swarm(gs, owner: int, u: Dictionary) -> void:
	u.hp=0;u.front=0;u.knockout=0;u.removed=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"summonKind":"展翅虫群"})
static func summon(gs, owner: int, src: int) -> void:
	gs.VerifiedRules.Weaver.leave_front(gs,owner)
	var p:Dictionary=gs.player(owner);var u:Dictionary={"color":"#96aa68","shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"charge":0,"removed":false}
	u.uid="%s:toxic-swarm-%d"%[p.id,gs.next_card_id];gs.next_card_id+=1;u.id="toxic-winged-swarm";u.name="展翅虫群";u.title="虫师召唤物";u.art=Content.unit_def("chongshi").art;u.awakenedArt=u.art
	u.baseAttack=1;u.baseMaxHp=3;u.attack=1;u.maxHp=3;u.hp=3;u.level=1;u.front=1;u.summoned=true;u.summon=true;u.countsAsShikigami=true;u.toxicSwarm=true;u.swift=true;u.keywords=["toxic"];u.summonerUid=p.units[src].uid;u.passive_hooks=[];u.formAbility="迅捷、剧毒。离开战斗区时移除。"
	p.units.append(u);gs.VerifiedRules.Enma.refresh(gs);gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":u.summonerUid,"summonKind":"展翅虫群"})
	gs._fire_hooks(owner,p.units.size()-1,"unit-entered-front",{});gs._run_form_hooks(owner,p.units.size()-1,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
static func describe_card(gs, owner: int, _inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.get("id","")!="c28406":return card
	var c:=card.duplicate(true);var p:Dictionary=gs.player(owner);var n:=int(p.get("toxicEvents",0)) if int(p.get("toxicEventTurn",-1))==gs.turn_counter else 0
	c.value=1+n;c.effects[0].value=1+n;c.combatOption.shield=1+n;c.enhanced=n>0;c.currentCardStats="本回合中毒%d次 · +%d力量/+%d护甲"%[n,1+n,1+n];c.text+="\n"+c.currentCardStats
	return c
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("toxicRules",false):return null
	if card.get("target","auto")=="auto":return null
	var list:Array=[]
	if card.get("target")=="ally-knocked-unit":
		for u in gs.player(owner).units:
			if int(u.hp)<=0 and not u.get("summoned",false) and gs.VerifiedRules.Rebirth.can_revive(u):list.append(u.uid)
	else:
		for u in gs.player(1-owner).units:
			if int(u.hp)>0 and not u.get("removed",false) and not gs.VerifiedRules.Combat.has(u,"veil"):list.append(u.uid)
	return list
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("id","")=="c28404":return not gs.player(owner).units[gs._source_index(owner,card)].awakened
	return true
static func searchable(card: Dictionary) -> bool:
	if card.has("toxicSearch"): return bool(card.toxicSearch)
	return "toxic" in card.get("keywords",[]) or "剧毒" in str(card.get("sourceSnapshotText",card.get("officialText","")))
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action","")):
		"toxic-damage":damage(gs,owner,src,target,int(effect.value))
		"toxic-summon":summon(gs,owner,src)
		"toxic-revive":gs.VerifiedRules.Peach.revive(gs,owner,src,target,false,false)
		"toxic-revive-self":gs.VerifiedRules.Peach.revive(gs,owner,src,gs.player(owner).units[src],false,false)
		"toxic-random":random_damage(gs,owner,src,int(effect.value))
		"toxic-search":
			var pool:Array=gs.player(owner).deck.filter(func(i):var c:=Content.card_def(str(i.definitionId));return searchable(c))
			gs._shuffle(pool)
			for i in mini(2,pool.size()):
				gs.player(owner).deck.erase(pool[i])
				if gs.player(owner).hand.size()<12:gs.player(owner).hand.append(pool[i])
		"toxic-realm":gs._deploy_realm(owner,card)
		"toxic-awaken":
			var u:Dictionary=gs.player(owner).units[src]
			if u.awakened:
				gs.VerifiedRules.Glutton.record_permanent(u,int(effect.value.attack),int(effect.value.hp),true)
				gs._grow_unit(u,int(effect.value.attack),int(effect.value.hp))
			else:gs._awaken(owner,src,card,effect.value)
			u.erase("bugFireTurn");refresh(gs)
		_:return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var k:=str(f.get("kind",""))
	if not k.begins_with("toxic-"):return false
	var owner:=int(f.playerIndex);var src:=int(f.sourceIndex)
	match k:
		"toxic-draw":gs._draw(owner,1)
		"toxic-heal":gs._heal_avatar(owner,int(f.amount))
		"toxic-fire":gs._set_fire(owner,int(gs.player(owner).energy)+1)
		"toxic-den","toxic-retaliate":
			var target:Dictionary=gs._unit_by_uid(gs.player(1-owner).units,f.targetUid)
			if src>=0:
				var old:Dictionary=gs._card_effect_context;gs._card_effect_context={};damage(gs,owner,src,target,2);gs._card_effect_context=old
		_:return false
	return true
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx];var marks:Array=[]
	if u.get("toxicPoisoned",false):marks.append("中毒 · 不能恢复或重置生命，再次受到剧毒伤害直接气绝")
	if role(u)=="bug":marks.append("中毒敌方力量降低%d"%(2 if u.awakened else 1))
	if role(u)=="scorpion":marks.append("剧毒 · "+("所有伤害" if u.awakened else "攻击时"))
	return marks
static func score_card(gs, owner: int, card: Dictionary, target):
	if not card.get("toxicRules",false):return null
	if card.get("type")=="form":return -40 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 70
	if card.get("type")=="combat":return 50
	return 85 if card.id in ["c28308","c28404"] else 65 if target==null else 75
