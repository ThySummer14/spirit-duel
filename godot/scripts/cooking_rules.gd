class_name CookingRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const INGREDIENT_IDS := {"mountain":"cooking-mountain", "sea":"cooking-sea", "vegetable":"cooking-vegetable"}
const KIND_NAMES := {"mountain":"山珍", "sea":"海味", "vegetable":"时蔬", "ingredient":"食材", "unknown":"不明食材", "feast":"佳肴", "dark":"黑暗料理"}

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("cookingRole", ""))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func food_kind(value: Dictionary) -> String:
	if value.has("foodData"): return str(value.foodData.get("kind",""))
	var id := str(value.get("id",value.get("definitionId","")))
	if id in INGREDIENT_IDS.values(): return "ingredient"
	return "unknown" if id=="shi-cai" else "feast" if id=="jia-yao" else "dark" if id=="cooking-dark" else ""
static func hand_food_count(gs, owner: int, kind: String = "") -> int:
	var n:=0
	for inst in gs.player(owner).hand:
		var k:=food_kind(inst)
		if not k.is_empty() and (kind.is_empty() or k==kind or (kind=="ingredient" and k=="unknown")):n+=1
	return n
static func feast_count(gs, owner: int) -> int:
	return int(gs.player(owner).get("cookingFeasts",0))
static func _quality(gs, owner: int, src: int) -> int:
	return clampi(int(gs.player(owner).units[src].level),1,3) if src>=0 and src<gs.player(owner).units.size() else 1
static func _vegetable_pool(gs, owner: int, quality: int, avoid_duplicate: bool) -> Array:
	var pool:Array=["inspired"]
	if quality>=2:pool.append("pierce")
	if quality>=3:pool.append("swift")
	if avoid_duplicate:
		for inst in gs.player(owner).hand:
			if food_kind(inst)!="ingredient":continue
			for part in inst.get("foodData",{}).get("parts",[]):
				if not str(part.get("keyword","")).is_empty():pool.erase(str(part.keyword))
	return pool
static func _ingredient_data(gs, owner: int, src: int, kind: String, randomize: bool, avoid_duplicate: bool = false) -> Dictionary:
	var quality:=_quality(gs,owner,src)
	var k:=kind
	if k.is_empty():k=["mountain","sea","vegetable"][int(gs.next_random()%3)]
	var part:Dictionary={"attack":quality if k=="mountain" else 0,"hp":quality if k=="sea" else 0}
	if k=="vegetable":
		var pool:=_vegetable_pool(gs,owner,quality,avoid_duplicate)
		if pool.is_empty():return _ingredient_data(gs,owner,src,["mountain","sea"][int(gs.next_random()%2)],randomize,false)
		if randomize:part.keyword=str(pool[int(gs.next_random()%pool.size())])
		else:part.keywordPool=pool
	return {"kind":"ingredient","ingredientKind":k,"quality":quality,"parts":[part]}
static func _instance(gs, data: Dictionary) -> Dictionary:
	var id:=str(INGREDIENT_IDS.get(str(data.get("ingredientKind","")),"shi-cai" if data.kind=="unknown" else "cooking-dark" if data.kind=="dark" else "jia-yao"))
	var inst:Dictionary={"definitionId":id,"instanceId":"cooking-food-%d"%gs.next_card_id,"foodData":data.duplicate(true)}
	gs.next_card_id+=1;return inst
static func ingredient_options(gs, owner: int, src: int) -> Array:
	var out:Array=[]
	for k in INGREDIENT_IDS:
		out.append({"definitionId":INGREDIENT_IDS[k],"foodData":_ingredient_data(gs,owner,src,str(k),false)})
	return out
static func _remember_gain(gs, owner: int, src: int, inst: Dictionary) -> void:
	var data:Dictionary=inst.foodData;var p:Dictionary=gs.player(owner)
	if data.kind=="ingredient":
		if not p.has("cookingSeenKinds"):p.cookingSeenKinds=[]
		if not p.cookingSeenKinds.has(str(data.ingredientKind)):p.cookingSeenKinds.append(str(data.ingredientKind))
	if data.kind=="feast":p.cookingFeasts=feast_count(gs,owner)+1
	gs.VerifiedRules.event(gs,"food-gained",{"player":owner,"sourceIndex":src,"kind":data.kind,"foodData":data.duplicate(true),"instanceId":inst.instanceId})
	if data.kind!="feast":return
	for i in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[i]
		if role(u)=="chef" and u.awakened and int(u.level)>0 and int(u.hp)<=0 and gs.VerifiedRules.Rebirth.can_revive(u):
			gs.VerifiedRules.Peach.revive(gs,owner,i,u,false,false)
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm")=="cooking-dream" and int(realm.hp)>0:gs.resolution_stack.append({"kind":"cooking-dream-draw","playerIndex":owner})
static func _gain(gs, owner: int, src: int, data: Dictionary) -> Dictionary:
	var inst:=_instance(gs,data)
	if gs.player(owner).hand.size()>=int(gs.rules.maxHandSize):
		gs.VerifiedRules.event(gs,"food-burned",{"player":owner,"kind":data.kind,"instanceId":inst.instanceId});return {}
	gs.player(owner).hand.append(inst);_remember_gain(gs,owner,src,inst);return inst
static func gain_ingredient(gs, owner: int, src: int, kind: String = "") -> Dictionary:
	return _gain(gs,owner,src,_ingredient_data(gs,owner,src,kind,true))
static func gain_unknown(gs, owner: int, src: int) -> Dictionary:
	return _gain(gs,owner,src,{"kind":"unknown","quality":1,"parts":[],"armorBreak":4})
static func gain_feast(gs, owner: int, src: int, parts: Array = []) -> Dictionary:
	if parts.is_empty():
		# 甘如暖阳 has a larger independent keyword pool. Its unknown pool must
		# not silently be replaced by three ordinary random ingredients.
		var pool:Array=Content.card_def("c24908").get("cookingDirectFeastPool",[])
		if pool.is_empty():gs.VerifiedRules.event(gs,"food-definition-unverified",{"player":owner,"card":"c24908"});return {}
		parts=pool[int(gs.next_random()%pool.size())].duplicate(true)
	return _gain(gs,owner,src,{"kind":"feast","quality":3,"parts":parts.duplicate(true)})
static func cook(gs, owner: int, src: int) -> void:
	if gs.winner>=0 or src<0 or src>=gs.player(owner).units.size():return
	var u:Dictionary=gs.player(owner).units[src]
	if not active(u):return
	gs.VerifiedRules.event(gs,"cooking",{"player":owner,"sourceIndex":src,"uid":u.uid,"quality":_quality(gs,owner,src)})
	for chef in gs.player(owner).units:
		if active(chef) and role(chef)=="chef":
			chef.cookingChefGrowth=int(chef.get("cookingChefGrowth",0))+1
			# Passive growth while resolving 觉醒·食灵 is still ordinary growth.
			var old_context:Dictionary=gs._card_effect_context
			gs._card_effect_context={"playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,str(chef.uid)),"cardOverride":{"effect":"cooking-passive-growth"}}
			gs._grow_unit(chef,1,0);gs._card_effect_context=old_context
		if active(chef) and chef.get("formRules",{}).get("cookingHotChef",false):gs._apply_encourage(owner,1,1)
	var data:=_ingredient_data(gs,owner,src,"",true,true);var picked:Array=[]
	for i in range(gs.player(owner).hand.size()-1,-1,-1):
		if food_kind(gs.player(owner).hand[i]) in ["ingredient","unknown"]:picked.append(i)
		if picked.size()==2:break
	if picked.size()<2:_gain(gs,owner,src,data);return
	# Merge before adding the third ingredient, so a 12-card hand can cook.
	var fresh:=_instance(gs,data);_remember_gain(gs,owner,src,fresh)
	var parts:Array=data.parts.duplicate(true);var dark:=false;var ids:Array=[str(fresh.instanceId)]
	for i in picked:
		var inst:Dictionary=gs.player(owner).hand.pop_at(int(i));ids.append(str(inst.instanceId))
		if food_kind(inst)=="unknown":dark=true
		parts.append_array(inst.get("foodData",{}).get("parts",[]).duplicate(true))
	var result:=_gain(gs,owner,src,{"kind":"dark" if dark else "feast","quality":_quality(gs,owner,src),"parts":[] if dark else parts,"armorBreak":6 if dark else 0,"mergedFrom":ids})
	gs.VerifiedRules.event(gs,"food-combined",{"player":owner,"kind":"dark" if dark else "feast","from":ids,"instanceId":result.get("instanceId","")})
static func _food_text(data: Dictionary) -> String:
	if data.kind in ["unknown","dark"]:return ("瞬发。" if data.kind=="dark" else "")+"使一个式神获得%d破甲。"%int(data.get("armorBreak",6 if data.kind=="dark" else 4))
	var lines:Array=[]
	for part in data.get("parts",[]):
		if int(part.get("attack",0))!=0:lines.append("获得%d力量"%int(part.attack))
		if int(part.get("hp",0))!=0:lines.append("获得%d生命"%int(part.hp))
		if not str(part.get("keyword","")).is_empty():lines.append("获得"+{"inspired":"昂扬","pierce":"贯通","swift":"迅捷"}.get(str(part.keyword),str(part.keyword)))
		if part.has("keywordPool"):lines.append("随机获得"+"／".join(part.keywordPool))
	return "使一个己方式神"+"，".join(lines)+"。"
static func describe_food(_gs, _owner: int, inst: Dictionary, original: Dictionary = {}) -> Dictionary:
	var c:Dictionary=(original if not original.is_empty() else Content.card_def(str(inst.get("definitionId","")))).duplicate(true)
	var kind:=food_kind(inst)
	if kind.is_empty():return c
	var data:Dictionary=inst.get("foodData",{"kind":kind,"parts":[],"quality":1,"armorBreak":6 if kind=="dark" else 4}).duplicate(true)
	c.neutralFood=true;c.foodData=data;c.unitId="";c.type="spell";c.typeLabel="中立法术牌";c.level=0;c.cost=1;c.target="food-target";c.keywords=["instant"] if kind=="dark" else [];c.text=_food_text(data);c.officialText=c.text;c.effects=[{"action":"cooking-food","target":"selected","value":data}];c.effect="cooking-food";c.value=data
	c.currentCardStats=(str(KIND_NAMES.get(str(data.get("ingredientKind","")),"食材"))+" · 品质%d"%int(data.get("quality",1))) if kind=="ingredient" else str(KIND_NAMES.get(kind,kind))
	return c
static func food_targets(gs, owner: int, card: Dictionary) -> Array:
	var kind:=food_kind(card);var ids:Array=[]
	var revivable:bool=gs.player(owner).units.any(func(u):return active(u) and u.get("formRules",{}).get("sugarReviveFood",false))
	for side in [owner,1-owner] if kind in ["unknown","dark"] else [owner]:
		for u in gs.player(side).units:
			if u.get("removed",false) or not gs.VerifiedRules.OwlInsect.shikigami(u) or int(u.level)<=0:continue
			if side!=owner and gs.VerifiedRules.Combat.has(u,"veil"):continue
			if int(u.hp)>0 or (kind=="feast" and side==owner and revivable and gs.VerifiedRules.Rebirth.can_revive(u)):ids.append(str(u.uid))
	return ids
static func payment(gs, owner: int, card: Dictionary, quote: Dictionary) -> Dictionary:
	if not card.get("neutralFood",false) or food_kind(card) not in ["ingredient","feast"]:return quote
	if int(gs.player(owner).get("cookingFreeTurn",-1))==gs.turn_counter:return quote
	if gs.player(owner).units.any(func(u):return active(u) and u.get("formRules",{}).get("cookingDivinity",false)):
		var q:=quote.duplicate(true);q.cost=0;q.usesInstant=false;q.cookingFree=true;return q
	return quote
static func consume_payment(gs, owner: int, quote: Dictionary) -> void:
	if quote.get("cookingFree",false):gs.player(owner).cookingFreeTurn=gs.turn_counter
static func can_play_food(gs, owner: int, hand: int, target_id) -> Dictionary:
	var card:Dictionary=gs.hand_card_def(owner,hand)
	if not card.get("neutralFood",false):return {"ok":false,"reason":"不是食物。"}
	var quote:Dictionary=gs.card_payment(owner,card)
	if int(gs.player(owner).energy)<int(quote.cost):return {"ok":false,"reason":"鬼火不足。"}
	if not food_targets(gs,owner,card).has(str(target_id)):return {"ok":false,"reason":"请选择合法食物目标。"}
	return {"ok":true,"card":card,"source_index":-1,"reason":""}
static func _push_food(gs, owner: int, card: Dictionary, target_id, from_hand: bool, automatic: bool) -> void:
	var rid:int=gs.next_resolution_id;gs.next_resolution_id+=1
	var base:Dictionary={"resolutionId":rid,"playerIndex":owner,"sourceIndex":-1,"definitionId":str(card.id),"cardOverride":card.duplicate(true),"targetId":target_id,"automatic":automatic,"fromHand":from_hand,"respondable":false,"affectedUnits":[]}
	for kind in ["card-complete","card-effect","card-announce"]:
		var f:=base.duplicate(true);f.kind=kind;f.effectIndex=0;gs.resolution_stack.append(f)
static func play_food(gs, owner: int, hand: int, target_id) -> bool:
	var check:Dictionary=gs.can_play_card(owner,hand,target_id)
	if not check.ok:return false
	var card:Dictionary=check.card;var q:Dictionary=gs.card_payment(owner,card)
	var inst:Dictionary=gs.take_card_instance(owner,hand);card.playedInstance=inst.duplicate(true);card.usedFromHand=true
	gs._set_fire(owner,int(gs.player(owner).energy)-int(q.cost),true);consume_payment(gs,owner,q)
	if q.get("usesInstant",false):gs.kw_usage(owner,"instant").used=true
	gs.player(owner).cardsPlayedThisTurn=int(gs.player(owner).cardsPlayedThisTurn)+1
	gs._record("play_card",{"hand":hand,"card":card.id,"target":target_id,"cardView":card.duplicate(true),"payment":q.duplicate(true),"neutralFood":true},owner)
	_push_food(gs,owner,card,target_id,true,false);gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func auto_use_from_hand(gs, owner: int, src: int, target_uid, kind: String) -> bool:
	var indices:Array=[]
	for i in gs.player(owner).hand.size():
		if food_kind(gs.player(owner).hand[i])==kind or (kind=="ingredient" and food_kind(gs.player(owner).hand[i])=="unknown"):indices.append(i)
	if indices.is_empty():return false
	var index:int=indices[int(gs.next_random()%indices.size())];var card:Dictionary=gs.hand_card_def(owner,index);var inst:Dictionary=gs.player(owner).hand.pop_at(index);card.playedInstance=inst;card.usedFromHand=true;card.cookingAbilitySource=src
	_push_food(gs,owner,card,target_uid,true,true);return true
static func auto_use_generated(gs, owner: int, src: int, target_uid, kind: String) -> bool:
	if kind not in ["ingredient","unknown"]:return false
	var data:Dictionary={"kind":"unknown","quality":1,"parts":[],"armorBreak":4} if kind=="unknown" else _ingredient_data(gs,owner,src,"",true)
	var card:=describe_food(gs,owner,_instance(gs,data));card.cookingAbilitySource=src
	_push_food(gs,owner,card,target_uid,false,true);return true
static func _apply_food(gs, owner: int, target_id, card: Dictionary) -> bool:
	var target:Dictionary=gs._unit_by_uid(gs._all_units(),str(target_id));if target.is_empty() or target.get("removed",false):return false
	var side:int=owner if gs._unit_index_by_uid(owner,str(target_id))>=0 else 1-owner;var idx:int=gs._unit_index_by_uid(side,str(target_id));var data:Dictionary=card.foodData
	if int(target.hp)<=0:
		if data.kind!="feast" or side!=owner or not food_targets(gs,owner,card).has(str(target_id)):return false
		gs.VerifiedRules.Peach.revive(gs,owner,-1,target,false,false)
	if data.kind in ["unknown","dark"]:gs.VerifiedRules.ArmorBreak.give(gs,owner,-1,side,idx,int(data.get("armorBreak",6 if data.kind=="dark" else 4)));return true
	for part in data.get("parts",[]):
		if int(part.get("attack",0))!=0 or int(part.get("hp",0))!=0:
			target.cookingFoodAttack=int(target.get("cookingFoodAttack",0))+int(part.get("attack",0));target.cookingFoodHp=int(target.get("cookingFoodHp",0))+int(part.get("hp",0))
			gs._grow_unit(target,int(part.get("attack",0)),int(part.get("hp",0)))
		var keyword:=str(part.get("keyword",""))
		if keyword=="swift":target.swift=true
		elif keyword=="inspired":gs.VerifiedRules.Combat.grant_inspired(gs,side,idx)
		elif not keyword.is_empty():
			if not target.has("keywords"):target.keywords=[]
			if not target.keywords.has(keyword):
				target.keywords.append(keyword)
				if not target.has("cookingFoodKeywords"):target.cookingFoodKeywords=[]
				target.cookingFoodKeywords.append(keyword)
	return true
static func _used(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner:=int(frame.playerIndex);var uid:=str(frame.targetId);var side:int=owner if gs._unit_index_by_uid(owner,uid)>=0 else 1-owner;var target:Dictionary=gs._unit_by_uid(gs._all_units(),uid);var kind:=food_kind(card)
	if kind in ["feast","dark"]:gs.player(owner).cookingFeastUsedTurn=gs.turn_counter
	if side==owner and not target.is_empty() and role(target)=="cat":
		if kind in ["ingredient","unknown"]:target.cookingIngredientUses=int(target.get("cookingIngredientUses",0))+1
		if kind in ["feast","dark"]:target.cookingFeastUses=int(target.get("cookingFeastUses",0))+1
		if kind in ["feast","dark"] and active(target):
			if target.get("formRules",{}).get("cookingCatWork",false):gs._draw(owner,1);gs._set_fire(owner,int(gs.player(owner).energy)+1)
			if gs.current_player==owner and target.get("formRules",{}).get("cookingCatDay",false):target.barrier=true;gs.resolution_stack.append({"kind":"cooking-cat-attack","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,uid)})
	gs.VerifiedRules.event(gs,"food-used",{"player":owner,"sourceIndex":-1,"targetUid":uid,"targetOwner":side,"kind":kind,"card":card.duplicate(true),"automatic":bool(frame.automatic),"fromHand":bool(frame.fromHand),"abilitySourceIndex":int(card.get("cookingAbilitySource",-1))})
static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.get("cookingBounce",false):
		var inst:Dictionary=card.cookingInstance.duplicate(true);inst.cookingBounceSpent=true
		gs.resolution_stack.append({"kind":"cooking-bounce","playerIndex":int(frame.playerIndex),"instance":inst})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")=="cooking-bounce":
		if gs.player(int(frame.playerIndex)).hand.size()<int(gs.rules.maxHandSize):gs.player(int(frame.playerIndex)).hand.append(frame.instance.duplicate(true))
		return true
	if frame.get("kind")=="cooking-combat-after-food":
		var card:Dictionary=frame.card;var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
		if active(gs.player(owner).units[src]):gs._grant_unit_armor(gs.player(owner).units[src],int(options.get("shield",0)));gs._resolve_combat(owner,src,int(card.value),bool(options.get("pierce",false)),false,false,bool(options.get("firstStrike",false)),frame.get("targetId"),false,options)
		return true
	var kind:=str(frame.get("kind",""))
	if kind=="cooking-draw":gs._draw(int(frame.playerIndex),1);return true
	if kind=="cooking-cook":cook(gs,int(frame.playerIndex),int(frame.sourceIndex));return true
	if kind=="cooking-dream-draw":gs._draw(int(frame.playerIndex),1);return true
	if kind=="cooking-cat-attack":
		var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex)
		if active(gs.player(owner).units[src]):gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"cookingAutoAttack":true})
		return true
	var card:Dictionary=frame.get("cardOverride",{})
	if not card.get("neutralFood",false) or kind not in ["card-effect","card-complete"]:return false
	var owner:=int(frame.playerIndex)
	if kind=="card-complete":
		gs.VerifiedRules.Arakawa.completed(gs,frame,card)
		gs.VerifiedRules.HandBlessing.completed(gs,owner,-1,card)
		gs.VerifiedRules.event(gs,"neutral-card-completed",{"player":owner,"card":card.duplicate(true),"resolutionId":frame.resolutionId})
		return true
	var old_context:Dictionary=gs._card_effect_context;gs._card_effect_context=frame
	if _apply_food(gs,owner,frame.targetId,card):
		_used(gs,frame,card)
		if not card.get("cookingDuplicated",false) and gs._unit_index_by_uid(owner,str(frame.targetId))>=0 and food_kind(card) in ["ingredient","feast"] and gs.player(owner).units.any(func(u):return active(u) and u.get("formRules",{}).get("cookingDivinity",false)):
			var targets:=food_targets(gs,owner,card);targets.reverse()
			for target_id in targets:
				if str(target_id)!=str(frame.targetId) and gs._unit_index_by_uid(owner,str(target_id))>=0:
					var copy:=card.duplicate(true);copy.cookingDuplicated=true;copy.usedFromHand=false;_push_food(gs,owner,copy,target_id,false,true)
	gs._card_effect_context=old_context
	return true
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("cookingRules",false):return card
	var c:=card.duplicate(true);var src:int=gs._source_index(owner,c)
	if src<0:return c
	if c.id=="c25306":
		c.cookingBounce=not inst.get("cookingBounceSpent",false);c.cookingInstance=inst.duplicate(true)
		if c.cookingBounce and not c.keywords.has("bounce"):c.keywords.append("bounce")
		if not c.cookingBounce:c.text=c.text.replace("，弹回", "").replace("弹回", "")
	if c.id in ["c25201","c25206"] and int(gs.player(owner).get("cookingFeastUsedTurn",-1))==gs.turn_counter:
		c.enhanced=true
		if c.id=="c25201":c.keywords.append("instant")
		else:c.combatOption.pursuit=true;c.target="enemy-unit"
	if c.id=="c25202":
		var u:Dictionary=gs.player(owner).units[src];c.value=int(u.get("cookingIngredientUses",0))+2*int(u.get("cookingFeastUses",0));c.effects[0].value=c.value;c.currentCardStats="本局食材%d／佳肴%d · +%d力量"%[int(u.get("cookingIngredientUses",0)),int(u.get("cookingFeastUses",0)),int(c.value)]
	if c.id=="c25307":
		c.target="enemy-unit";var n:=feast_count(gs,owner);c.value=2*n;c.effects[0].value=c.value;c.combatOption.shield=2*n;c.currentCardStats="本局获得%d佳肴 · +%d力量／护甲"%[n,2*n]
	return c
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if str(card.get("id","")) not in ["c25208","c25304"]:return true
	var src:int=gs._source_index(owner,card)
	return src>=0 and not gs.player(owner).units[src].awakened
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if str(card.get("id",""))=="c25205":cook(gs,owner,src)
static func end_turn(gs, owner: int) -> void:
	for i in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[i]
		if active(u) and u.get("formRules",{}).get("cookingOnEndFront",false) and int(u.front)==1:gs.resolution_stack.append({"kind":"cooking-cook","playerIndex":owner,"sourceIndex":i})
static func combat_dealt(gs, owner: int, src: int, _victim: int, idx: int, result: Dictionary, _options: Dictionary) -> void:
	if owner<0 or src<0 or int(result.get("dealt",result.get("damage",0)))<=0:return
	var u:Dictionary=gs.player(owner).units[src]
	if active(u) and role(u)=="cat" and (u.awakened or idx<0):cook(gs,owner,src)
static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm")!="cooking-dream":return false
	return true
static func realm_entered(gs, owner: int, card: Dictionary) -> void:
	if card.get("id")=="c25303":cook(gs,owner,gs._source_index(owner,card))
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u:Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"cooking-cook":cook(gs,owner,src)
		"cooking-form":gs._install_form(owner,src,card,effect.value)
		"cooking-realm":gs._deploy_realm(owner,card);realm_entered(gs,owner,card)
		"cooking-play-feast":
			gs.resolution_stack.append({"kind":"cooking-draw","playerIndex":owner})
			auto_use_from_hand(gs,owner,src,u.uid,"feast")
		"cooking-cat-combat","cooking-chef-combat":
			var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
			if card.id=="c25204":gs.resolution_stack.append({"kind":"cooking-combat-after-food","playerIndex":owner,"sourceIndex":src,"card":card.duplicate(true),"targetId":target_id});auto_use_from_hand(gs,owner,src,u.uid,"feast")
			else:gs._grant_unit_armor(u,int(options.get("shield",0)));gs._resolve_combat(owner,src,int(card.value),bool(options.get("pierce",false)),false,false,bool(options.get("firstStrike",false)),target_id,false,options)
		"cooking-awaken":
			if not u.awakened:gs._awaken(owner,src,card,{"attack":1,"hp":1})
		_:return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if card.get("neutralFood",false):return 30 if gs._unit_index_by_uid(owner,str(target_id))>=0 else 35
	if not card.get("cookingRules",false):return null
	if card.id=="c25203":return 50 if hand_food_count(gs,owner,"feast")>0 else 10
	if card.id in ["c25208","c25304"]:return 65 if not gs.player(owner).units[gs._source_index(owner,card)].awakened else 0
	return 40
static func marks(gs, owner: int, u: Dictionary) -> Array:
	var result:Array=[]
	if role(u)=="cat":result.append("被使用食材%d／佳肴%d"%[int(u.get("cookingIngredientUses",0)),int(u.get("cookingFeastUses",0))])
	if role(u)!="":result.append("本局获得佳肴%d · 手牌食物%d"%[feast_count(gs,owner),hand_food_count(gs,owner)])
	return result

static func reset_ledger(u: Dictionary) -> void:
	u.erase("cookingFoodAttack");u.erase("cookingFoodHp");u.erase("cookingChefGrowth")
static func knocked_out(u: Dictionary) -> void:
	u.attackBonus=int(u.attackBonus)-int(u.get("cookingFoodAttack",0))-int(u.get("cookingChefGrowth",0));u.maxHpBonus=int(u.maxHpBonus)-int(u.get("cookingFoodHp",0))
	for keyword in u.get("cookingFoodKeywords",[]):u.get("keywords",[]).erase(keyword)
	u.erase("cookingFoodKeywords");reset_ledger(u)
