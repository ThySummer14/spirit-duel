class_name GluttonRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Glossary := preload("res://scripts/ui/keyword_glossary.gd")
const TRAITS := ["swift","pierce","combo","remote","first-strike","direct","pursuit","penetration","unyielding","crit","lethal","lifesteal","veil","inspired"]
static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("gluttonRules",false))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func satiated(u: Dictionary) -> bool:
	return active(u) and not u.get("gluttonSatiation",{}).is_empty()
static func power(_gs, u: Dictionary) -> int:
	return 2 if satiated(u) else 0
static func has(u: Dictionary, key: String) -> bool:
	if not active(u): return false
	if key=="swift" and u.get("formRules",{}).get("gluttonSwift",false) and satiated(u): return true
	return key in u.get("formRules",{}).get("gluttonKeywords",[])
static func consume_unyielding(u: Dictionary) -> void:
	if u.has("formRules"): u.formRules.gluttonKeywords=u.formRules.get("gluttonKeywords",[]).filter(func(k):return k!="unyielding")
static func consume_attack_traits(u: Dictionary) -> void:
	if u.has("formRules"):u.formRules.gluttonKeywords=u.formRules.get("gluttonKeywords",[]).filter(func(k):return k not in ["swift","inspired"])
static func record_permanent(u: Dictionary, attack: int, hp: int, awakening: bool = false) -> void:
	u.gluttonPermanentAttack=int(u.get("gluttonPermanentAttack",0))+attack
	u.gluttonPermanentHp=int(u.get("gluttonPermanentHp",0))+hp
	if awakening:
		u.gluttonAwakenAttack=attack;u.gluttonAwakenHp=hp
static func awakened_hp(u: Dictionary) -> int:
	return int(u.get("gluttonAwakenHp",1 if u.get("awakened",false) else 0))
static func awakened_attack(u: Dictionary) -> int:
	return int(u.get("gluttonAwakenAttack",1 if u.get("awakened",false) else 0))
static func permanent_stats(u: Dictionary) -> Dictionary:
	return {"attack":maxi(0,int(u.get("permanentAttack",0)))+maxi(0,int(u.get("gluttonPermanentAttack",0)))+maxi(0,int(u.get("blessingPermanentAttack",0))),"hp":maxi(0,int(u.get("gluttonPermanentHp",0)))+maxi(0,int(u.get("oniPermanentHp",0)))+maxi(0,int(u.get("sparrowPermanentHp",0)))+maxi(0,int(u.get("windPermanentHp",0)))+maxi(0,int(u.get("blessingPermanentHp",0)))}
static func take_permanent(gs, target: Dictionary) -> Dictionary:
	var amount:=permanent_stats(target)
	target.attackBonus=int(target.attackBonus)-maxi(0,int(target.get("gluttonPermanentAttack",0)))-maxi(0,int(target.get("blessingPermanentAttack",0)))
	target.maxHpBonus=int(target.maxHpBonus)-int(amount.hp)
	for key in ["permanentAttack","gluttonPermanentAttack","gluttonPermanentHp","gluttonAwakenAttack","gluttonAwakenHp","oniPermanentHp","sparrowPermanentHp","windPermanentHp","blessingPermanentAttack","blessingPermanentHp"]:target[key]=0
	gs._recalc(target)
	return amount
static func mark_hand(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if source(u) and satiated(u):
			for inst in gs.player(owner).hand:
				if inst.definitionId=="c21705":inst.gluttonFeasted=true
static func attach(gs, owner: int, idx: int) -> void:
	var u: Dictionary=gs.player(owner).units[idx]
	if not active(u): return
	u.gluttonSatiation={"uid":"satiation-%d" % gs.next_card_id,"remaining":2,"owner":owner}
	gs.next_card_id+=1;mark_hand(gs,owner);gs._recalc(u)
	gs.VerifiedRules.event(gs,"glutton-satiated",{"player":owner,"uid":u.uid,"remaining":2})
static func remove_charm(gs, owner: int, idx: int, reason: String = "灵咒被移除") -> void:
	if owner<0 or idx<0:return
	var u: Dictionary=gs.player(owner).units[idx]
	if not u.has("gluttonSatiation"):return
	mark_hand(gs,owner);u.erase("gluttonSatiation");gs._recalc(u)
	gs.VerifiedRules.event(gs,"glutton-satiation-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func knocked_out(gs, owner: int, u: Dictionary) -> void:
	remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),"气绝")
static func reduce_timer(gs, owner: int, idx: int, amount: int) -> bool:
	if idx<0 or idx>=gs.player(owner).units.size():return false
	var u: Dictionary=gs.player(owner).units[idx]
	if not satiated(u):return false
	u.gluttonSatiation.remaining=maxi(0,int(u.gluttonSatiation.remaining)-amount)
	if int(u.gluttonSatiation.remaining)==0:remove_charm(gs,owner,idx,"倒计时结束")
	return true
static func turn_start(gs, owner: int) -> void:
	mark_hand(gs,owner)
	for idx in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[idx]
		if not active(u) or not u.has("gluttonSatiation"):continue
		u.gluttonSatiation.remaining=int(u.gluttonSatiation.remaining)-1
		if int(u.gluttonSatiation.remaining)<=0:remove_charm(gs,owner,idx,"倒计时结束")
static func removed(gs, owner: int, src: int, kind: String, target_id: String) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	u.gluttonRemovedCount=int(u.get("gluttonRemovedCount",0))+1
	gs.VerifiedRules.event(gs,"glutton-target-removed",{"player":owner,"uid":u.uid,"targetKind":kind,"target":target_id,"count":u.gluttonRemovedCount})
	if source(u) and active(u):attach(gs,owner,src)
static func locate(gs, id) -> Dictionary:
	for side in 2:
		var idx: int=gs._unit_index_by_uid(side,str(id))
		if idx>=0:return {"owner":side,"index":idx,"unit":gs.player(side).units[idx]}
	return {}
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("gluttonRules",false):return null
	if card.get("effect") not in ["glutton-swallow","glutton-awaken"]:return null
	var out: Array=[];var src: int=gs._source_index(owner,card)
	for side in 2:
		for idx in gs.player(side).units.size():
			var u: Dictionary=gs.player(side).units[idx]
			if not active(u) or not gs.VerifiedRules.OwlInsect.shikigami(u):continue
			if side!=owner and gs.VerifiedRules.Combat.has(u,"veil"):continue
			if card.effect=="glutton-awaken":
				if side==owner and idx==src:continue
				var stats:=permanent_stats(u)
				if int(stats.attack)<=0 and int(stats.hp)<=0:continue
			out.append(str(u.uid))
	return out
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("gluttonRules",false):return true
	if card.get("effect")=="glutton-charm-token":return false
	var src: int=gs._source_index(owner,card)
	if src<0:return false
	if card.get("effect")=="glutton-aftertaste":return satiated(gs.player(owner).units[src])
	if card.get("effect")=="glutton-awaken":return not gs.player(owner).units[src].awakened
	return true
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("gluttonRules",false):return card
	var out:=card.duplicate(true);var src: int=gs._source_index(owner,card)
	if src<0:return out
	var u: Dictionary=gs.player(owner).units[src]
	out.currentCardStats="本局已移除%d个目标 · %s" % [int(u.get("gluttonRemovedCount",0)),"饱腹倒计时%d" % int(u.gluttonSatiation.remaining) if satiated(u) else "未饱腹"]
	if str(card.id)=="c21705":out.gluttonEnhanced=bool(inst.get("gluttonFeasted",false)) or satiated(u)
	return out
static func prepare_form(gs, owner: int, src: int, card: Dictionary, value: Dictionary) -> Dictionary:
	var result: Dictionary={"card":card,"value":value}
	if not card.get("gluttonRules",false) or card.get("type")!="form":return result
	var c:=card.duplicate(true);var v: Dictionary=value.duplicate(true) if not value.is_empty() else card.get("value",{}).duplicate(true)
	if str(c.id)=="c21705":c.formRules.gluttonKeywords=["unyielding","veil"] if c.get("gluttonEnhanced",false) else []
	if str(c.id)=="c21707":
		var count: int=gs.player(owner).units[src].get("gluttonRemovedCount",0)
		v.attack=int(v.get("attack",5))+count;v.hp=int(v.get("hp",5))+count
		var pool:=TRAITS.duplicate();var selected: Array=[]
		for i in mini(count,pool.size()):
			var pick: int=gs.next_random()%pool.size();selected.append(pool[pick]);pool.remove_at(pick)
		c.formRules.gluttonKeywords=selected;c.formRules.gluttonSwallowed=count
	result.card=c;result.value=v;return result
static func prepare_combat(gs, owner: int, src: int, victim: int, idx: int, options: Dictionary) -> void:
	if not options.get("gluttonRaw",false) or options.get("gluttonRawDone",false):return
	options.gluttonRawDone=true
	if idx<0:return
	var u: Dictionary=gs.player(victim).units[idx];var amount: int=u.shield
	if amount<=0:return
	gs.VerifiedRules.StarBear.consumed_armor(u,amount);u.shield=0;u.shieldExpires=0
	gs.VerifiedRules.ArmorBlood.armor_changed(gs,u)
	removed(gs,owner,src,"护甲",str(u.uid));gs._grant_unit_armor(gs.player(owner).units[src],amount)
static func realms(gs) -> Array:
	var out: Array=[]
	for side in 2:
		for r in gs.player(side).realms:
			if int(r.get("hp",0))>0:out.append({"owner":side,"realm":r})
	return out
static func realm_choice(gs, owner: int, src: int) -> void:
	var available:=realms(gs)
	if available.is_empty():return
	gs.pending_choice={"type":"glutton-realm","playerIndex":owner,"sourceIndex":src,"instanceIds":available.map(func(e):return str(e.realm.uid)),"heading":"饥不择食","title":"选择移除一个幻境","hint":"移除真实幻境后结附饱腹，再继续原战斗。"};gs.phase="choice"
static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type")!="glutton-realm" or int(gs.pending_choice.playerIndex)!=owner:return null
	for e in realms(gs):
		if str(e.realm.uid)==iid:
			var card:=Content.card_def(str(e.realm.cardId)).duplicate(true)
			card.id=iid;card.name=("己方·" if int(e.owner)==owner else "敌方·")+str(e.realm.name)
			card.text="移除此幻境（当前耐久%d），使饿鬼结附饱腹。" % int(e.realm.hp)
			return card
	return null
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary=gs.pending_choice
	if c.get("type")!="glutton-realm" or int(c.playerIndex)!=owner or iid not in c.instanceIds:return false
	for e in realms(gs):
		if str(e.realm.uid)==iid:
			gs.player(int(e.owner)).realms.erase(e.realm)
			removed(gs,owner,int(c.sourceIndex),"幻境",iid)
			gs.VerifiedRules.event(gs,"realm-removed",{"player":int(e.owner),"uid":iid,"reason":"饥不择食"})
			break
	gs.pending_choice={};gs.phase="main";gs._record("resolve_divination_choice",{"choice":"glutton-realm","instanceId":iid},owner)
	gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="glutton-realm" or int(gs.pending_choice.playerIndex)!=owner:return null
	var available:=realms(gs);var selected: String=str(gs.pending_choice.instanceIds[0])
	for e in available:
		if int(e.owner)!=owner:selected=str(e.realm.uid);break
	return resolve_choice(gs,owner,selected)
static func assault(gs, owner: int, src: int, card: Dictionary) -> void:
	var options: Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card
	gs._resolve_combat(owner,src,int(card.get("value",1)),false,false,false,false,null,false,options)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	match str(effect.get("action","")):
		"glutton-combat":assault(gs,owner,src,card)
		"glutton-eat-realm":
			gs.resolution_stack.append({"kind":"glutton-realm-combat","playerIndex":owner,"sourceIndex":src,"card":card.duplicate(true)})
			realm_choice(gs,owner,src)
		"glutton-swallow":
			var at:=locate(gs,target_id)
			if not at.is_empty():
				gs.resolution_stack.append({"kind":"glutton-swallow-damage","playerIndex":owner,"sourceIndex":src,"targetId":target_id})
				if not at.unit.get("form",{}).is_empty():
					gs.VerifiedRules.Forms.remove(gs,int(at.owner),int(at.index),"鲸吞移除")
					removed(gs,owner,src,"形态",str(target_id))
		"glutton-aftertaste":
			for i in range(2,-1,-1):gs.resolution_stack.append({"kind":"glutton-aftertaste-step","playerIndex":owner,"sourceIndex":src,"step":i})
		"glutton-awaken":
			var at:=locate(gs,target_id)
			if not at.is_empty():
				var amount:=take_permanent(gs,at.unit)
				if int(amount.attack)>0 or int(amount.hp)>0:
					gs._grow_unit(gs.player(owner).units[src],int(amount.attack),int(amount.hp));record_permanent(gs.player(owner).units[src],int(amount.attack),int(amount.hp))
					removed(gs,owner,src,"永久强化",str(target_id))
			gs._awaken(owner,src,card,card.value)
		_ :return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner: int=frame.get("playerIndex",0);var src: int=frame.get("sourceIndex",0)
	match str(frame.get("kind","")):
		"glutton-realm-combat":assault(gs,owner,src,frame.card)
		"glutton-swallow-damage":
			var at:=locate(gs,frame.targetId)
			if not at.is_empty():gs._damage_unit(int(at.owner),int(at.index),4,owner,src)
		"glutton-aftertaste-step":
			var p: Dictionary=gs.player(owner)
			if p.deck.is_empty():return true
			var entry: Dictionary=p.deck.pop_back();var card:=Content.card_def(str(entry.definitionId))
			removed(gs,owner,src,"牌库顶牌",str(entry.get("instanceId",entry.definitionId)))
			if card.get("type")=="combat":gs._apply_encourage(owner,2,2)
			elif card.get("type")=="form":gs._heal_avatar(owner,4)
			else:gs._draw(owner,1)
		_ :return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("gluttonRules",false):return null
	match str(card.get("effect","")):
		"glutton-charm-token":return -100
		"glutton-eat-realm":return 46+realms(gs).size()*8
		"glutton-awaken":
			var at:=locate(gs,target_id)
			if at.is_empty():return -100
			var v:=permanent_stats(at.unit)
			return 55+int(v.attack)*5+int(v.hp)*4 if int(at.owner)!=owner else 10+int(v.attack)+int(v.hp)
		"glutton-swallow":
			var at:=locate(gs,target_id)
			return -100 if at.is_empty() or int(at.owner)==owner else 45+(20 if not at.unit.get("form",{}).is_empty() else 0)-int(at.unit.hp)
		"glutton-aftertaste":return 50 if satiated(gs.player(owner).units[gs._source_index(owner,card)]) else -100
	return 40
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx];var marks: Array=[]
	if source(u):marks.append("本局移除%d个目标" % int(u.get("gluttonRemovedCount",0)))
	if satiated(u):marks.append("饱腹：+2力量 · 倒计时%d" % int(u.gluttonSatiation.remaining))
	if has(u,"swift"):marks.append("饱腹迅捷")
	if not u.get("formRules",{}).get("gluttonKeywords",[]).is_empty():marks.append("关键词："+"、".join(u.formRules.gluttonKeywords.map(func(k):return Glossary.label(k))))
	return marks
