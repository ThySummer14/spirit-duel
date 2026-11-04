class_name GoldfishRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const BASE_IDS := ["c22701","c22702","c22703"]
## Official 2021-07-29 hierarchy. Each lower tier is exhausted before the
## repeatable upper tier; attack and defense upgrades retain separate histories.
const TIERS := {
	"c22701": {"attack":[["support-power"],["support-inspired","support-swift"],["support-growth"]],"defense":[["support-life"],["support-barrier","support-veil"],["support-growth"]]},
	"c22702": {"attack":[["training-power"],["training-lethal","training-pierce"],["training-growth"]],"defense":[["training-stun"],["training-immune","training-lifesteal"],["training-growth"]]},
	"c22703": {"attack":[["rest-overheal"],["rest-encourage","rest-instant"],["rest-others"]],"defense":[["rest-armor"],["rest-draw","rest-revive"],["rest-heal"]]}}
const LABELS := {"support-power":"额外+2力量","support-inspired":"额外+1力量并获得昂扬","support-swift":"额外+1力量并获得迅捷","support-growth":"额外+1力量/+1生命","support-life":"额外+2生命","support-barrier":"额外+1力量并获得屏障","support-veil":"额外+1生命并获得帷幕","training-power":"本次战斗额外+2力量","training-lethal":"本次战斗必杀","training-pierce":"本次战斗额外+1力量且贯通","training-growth":"本次战斗额外+1力量/+1护甲","training-stun":"本次战斗伤害眩晕敌方式神","training-immune":"本次战斗免疫战斗伤害","training-lifesteal":"本次战斗吸血","rest-overheal":"此次过量治疗转化为护甲","rest-encourage":"鼓舞：+2力量/+2护甲","rest-instant":"随机一张手牌获得瞬发","rest-others":"为其他角色恢复2生命","rest-armor":"被治疗角色额外获得5护甲","rest-draw":"额外抽一张牌","rest-revive":"额外随机复活一个己方式神","rest-heal":"额外恢复2生命"}
static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("goldfishRules",false))
static func active(u: Dictionary) -> bool:
	return source(u) and int(u.hp)>0 and int(u.level)>0
static func attached(u: Dictionary) -> bool:
	return source(u) and bool(u.get("goldfishAttached",false))
static func attach(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or attached(u): return
	u.goldfishAttached=true
	gs.VerifiedRules.event(gs,"goldfish-attached",{"player":owner,"uid":u.uid,"card":Content.card_def("jinyu")})
static func remove_charm(u: Dictionary) -> void:
	u.erase("goldfishAttached")
static func has(u: Dictionary, keyword: String) -> bool:
	return keyword=="veil" and int(u.get("hp",0))>0 and int(u.get("level",0))>0 and bool(u.get("goldfishVeil",false))
static func knocked_out(u: Dictionary) -> void:
	remove_charm(u)
	u.attackBonus=int(u.attackBonus)-int(u.get("goldfishGrowthAttack",0))
	u.maxHpBonus=int(u.maxHpBonus)-int(u.get("goldfishGrowthHp",0))
	for key in ["goldfishGrowthAttack","goldfishGrowthHp","goldfishVeil"]:u.erase(key)
static func upgrades(gs, owner: int, id: String, direction: String = "") -> Array:
	var store: Dictionary=gs.player(owner).get("goldfishUpgrades",{}).get(id,{})
	if direction!="":return store.get(direction,[])
	var out: Array=store.get("attack",[]).duplicate();out.append_array(store.get("defense",[]));return out
static func next_pool(gs, owner: int, id: String, direction: String) -> Array:
	if not TIERS.has(id) or not TIERS[id].has(direction):return []
	var have:=upgrades(gs,owner,id,direction)
	for tier in 3:
		var pool: Array=TIERS[id][direction][tier].duplicate()
		if tier==2:return pool
		pool=pool.filter(func(key):return not have.has(key))
		if not pool.is_empty():return pool
	return []
static func strengthen(gs, owner: int, id: String, direction: String) -> String:
	var p: Dictionary=gs.player(owner);var pool:=next_pool(gs,owner,id,direction)
	if pool.is_empty():return ""
	var key:=str(pool[int(floor(gs.randf01()*pool.size()))])
	return _grant_upgrade(gs,owner,id,direction,key)
static func _grant_upgrade(gs, owner: int, id: String, direction: String, key: String) -> String:
	var p: Dictionary=gs.player(owner)
	if not next_pool(gs,owner,id,direction).has(key):return ""
	if not p.has("goldfishUpgrades"):p.goldfishUpgrades={}
	if not p.goldfishUpgrades.has(id):p.goldfishUpgrades[id]={"attack":[],"defense":[]}
	p.goldfishUpgrades[id][direction].append(key)
	gs.VerifiedRules.event(gs,"goldfish-strengthened",{"player":owner,"card":Content.card_def(id),"direction":direction,"upgrade":key,"text":LABELS[key],"count":upgrades(gs,owner,id,direction).size()})
	return key
static func _upgrade_text(keys: Array) -> String:
	var lines:=PackedStringArray()
	for key in keys:lines.append(str(LABELS.get(key,key)))
	return "；".join(lines)
static func describe_card(gs, owner: int, entry: Dictionary, card: Dictionary) -> Dictionary:
	var out: Dictionary=card
	if entry.get("goldfishInstant",false):
		out=card.duplicate(true)
		if not out.get("keywords",[]).has("instant"):out.keywords.append("instant")
		out.text=str(out.get("text",""))+"\n金鱼·休憩强化：此实例获得瞬发。"
	if not card.get("goldfishRules",false):return out
	if out==card:out=card.duplicate(true)
	var src: int=gs._source_index(owner,card)
	if src<0:return out
	var u: Dictionary=gs.player(owner).units[src]
	if BASE_IDS.has(str(card.id)):
		out.goldfishEnhancements=upgrades(gs,owner,str(card.id)).duplicate()
		if not attached(u):
			out.goldfishAttachmentReplacement=true;out.target="auto";out.effect="goldfish-first"
			out.effects=[{"condition":"always","action":"goldfish-first","target":"source","value":0}]
			out.text="金鱼未结附：本牌效果改为结附「金鱼」并抽一张牌。"
		else:
			out.text=str(card.text)
			if not out.goldfishEnhancements.is_empty():out.text+="\n已强化："+_upgrade_text(out.goldfishEnhancements)
		if card.id=="c22702":
			var cfg:=training_config(out.goldfishEnhancements)
			out.value=int(cfg.power);out.currentCardStats="当前战斗 +%d力量/+%d护甲" % [cfg.power,cfg.shield]
		else:out.currentCardStats="金鱼灵咒：已结附" if attached(u) else "金鱼灵咒：未结附 · 本次结附并抽1"
	if card.id=="c22706":out.goldfishAwakenEnhanced=attached(u)
	return out
static func training_config(keys: Array) -> Dictionary:
	var cfg: Dictionary={"power":1,"shield":1,"goldfishRetreat":true}
	for key in keys:
		match str(key):
			"training-power":cfg.power+=2
			"training-lethal":cfg.lethal=true
			"training-pierce":cfg.power+=1;cfg.pierce=true
			"training-growth":cfg.power+=1;cfg.shield+=1
			"training-stun":cfg.snowCombatStun=true
			"training-immune":cfg.immuneCombat=true
			"training-lifesteal":cfg.bloodLifeSteal=true
	return cfg
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("goldfishRules",false):return null
	if card.get("goldfishAttachmentReplacement",false) or card.get("target")=="auto":return []
	var ids: Array=[]
	for u in gs.player(owner).units:
		if int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u):ids.append(str(u.uid))
	if card.id=="c22703":ids.append("avatar-%d"%owner)
	return ids
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("goldfishRules",false):return true
	var src: int=gs._source_index(owner,card)
	return src>=0 and not (card.get("type")=="awakening" and gs.player(owner).units[src].awakened)
static func _support(gs, owner: int, target: Dictionary, keys: Array) -> void:
	if target.is_empty() or int(target.hp)<=0:return
	var power:=1;var life:=1
	for key in keys:
		match str(key):
			"support-power":power+=2
			"support-inspired":power+=1;gs.VerifiedRules.Combat.grant_inspired(gs,owner,gs._unit_index_by_uid(owner,str(target.uid)))
			"support-swift":power+=1;target.swift=true
			"support-growth":power+=1;life+=1
			"support-life":life+=2
			"support-barrier":power+=1;target.barrier=true
			"support-veil":
				life+=1
				target.goldfishVeil=true
	gs._grow_unit(target,power,life)
	target.goldfishGrowthAttack=int(target.get("goldfishGrowthAttack",0))+power
	target.goldfishGrowthHp=int(target.get("goldfishGrowthHp",0))+life
	gs.VerifiedRules.event(gs,"goldfish-support",{"player":owner,"target":target.uid,"attack":power,"hp":life,"upgrades":keys})
static func _heal(gs, owner: int, id: String, amount: int, armor: int, overflow_armor: bool) -> void:
	var over:=0
	if id=="avatar-%d"%owner:
		var missing:=maxi(0,int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp));over=maxi(0,amount-missing)
		gs._heal_avatar(owner,amount)
		gs._grant_avatar_armor(owner,armor+(over if overflow_armor else 0))
	else:
		var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,id)
		if u.is_empty() or int(u.hp)<=0:return
		over=maxi(0,amount-maxi(0,int(u.maxHp)-int(u.hp)))
		gs._heal_unit(u,amount);gs._grant_unit_armor(u,armor+(over if overflow_armor else 0))
static func _rest(gs, owner: int, src: int, target_id, keys: Array) -> void:
	var amount:=5+2*keys.count("rest-heal");var armor:=5*keys.count("rest-armor")
	_heal(gs,owner,str(target_id),amount,armor,keys.has("rest-overheal"))
	for key in keys:
		match str(key):
			"rest-encourage":gs._apply_encourage(owner,2,2)
			"rest-instant":
				var p: Dictionary=gs.player(owner)
				if not p.hand.is_empty():p.hand[int(floor(gs.randf01()*p.hand.size()))].goldfishInstant=true
			"rest-draw":gs._draw(owner,1)
			"rest-revive":
				var pool: Array=gs.player(owner).units.filter(func(u):return int(u.hp)<=0 and not u.get("summoned",false) and gs.VerifiedRules.Rebirth.can_revive(u))
				if not pool.is_empty():gs.VerifiedRules.Peach.revive(gs,owner,src,pool[int(floor(gs.randf01()*pool.size()))],false,false)
			"rest-others":
				# The official hierarchy says other characters, without an ally
				# restriction. Preserve that literal scope pending client footage.
				for side in gs.players.size():
					if str(target_id)!="avatar-%d"%side:gs._heal_avatar(side,2)
					for u in gs.player(side).units:
						if str(u.uid)!=str(target_id):gs._heal_unit(u,2)
	gs.VerifiedRules.event(gs,"goldfish-rest",{"player":owner,"target":target_id,"amount":amount,"upgrades":keys})
static func _choose_upgrade(gs, owner: int, src: int, direction: String) -> void:
	var offers: Dictionary={}
	for id in BASE_IDS:
		var pool:=next_pool(gs,owner,id,direction)
		offers[id]=pool[int(floor(gs.randf01()*pool.size()))]
	gs.pending_choice={"offers":offers,"type":"goldfish-upgrade","playerIndex":owner,"sourceIndex":src,"direction":direction,"instanceIds":BASE_IDS.duplicate(),"heading":"金鱼·进攻强化" if direction=="attack" else "金鱼·防御强化","hint":"选择一种1级牌，按当前梯度强化；完成后抽一张牌。"}
	gs.phase="choice"
static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type")!="goldfish-upgrade" or not BASE_IDS.has(iid):return null
	var out:=describe_card(gs,owner,{},Content.card_def(iid))
	out.text="当前强化："+_upgrade_text(upgrades(gs,owner,iid))+"\n本次获得："+str(LABELS[gs.pending_choice.offers[iid]])
	out.currentCardStats=""
	out.target="auto";return out
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary=gs.pending_choice
	if choice.get("type")!="goldfish-upgrade" or int(choice.playerIndex)!=owner or not BASE_IDS.has(iid):return false
	_grant_upgrade(gs,owner,iid,str(choice.direction),str(choice.offers[iid]))
	gs.pending_choice={};gs.phase="main";gs._draw(owner,1)
	gs._record("resolve_divination_choice",{"instanceId":iid,"choice":"goldfish-upgrade","direction":choice.direction},owner)
	gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="goldfish-upgrade":return null
	if int(gs.pending_choice.playerIndex)!=owner:return false
	var selected: String=BASE_IDS[0];var highest:=-999
	for id in BASE_IDS:
		var score:=30+10*int(id=="c22701")
		if id=="c22703":score+=int(int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp))*2
		if id=="c22702" and int(gs.player(owner).units[int(gs.pending_choice.sourceIndex)].attack)>=5:score+=25
		score+=upgrades(gs,owner,id).size()*2
		if score>highest:highest=score;selected=id
	return resolve_choice(gs,owner,selected)
static func automatic_targets(gs, owner: int, card: Dictionary, ids: Array) -> Array:
	if ids.is_empty() or card.get("target","auto")=="auto":return ids
	var chosen: Array=[];var best:=-999
	for id in ids:
		var score:=0
		if card.id=="c22703":
			var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(id))
			score=int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp) if u.is_empty() else int(u.maxHp)-int(u.hp)
		else:
			var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(id))
			score=int(u.attack)+2*int(u.front)+int(u.maxHp)-int(u.hp)
		if score>best:best=score;chosen.clear()
		if score==best:chosen.append(id)
	return ids if chosen.is_empty() else chosen
static func prepared_auto(gs, owner: int, id: String) -> Dictionary:
	return describe_card(gs,owner,{},Content.card_def(id))
static func incarnation_pool(gs, owner: int, src: int) -> Array:
	var out: Array=[];var best:=-999
	for id in BASE_IDS:
		var card:=prepared_auto(gs,owner,id)
		if card.get("target")!="auto" and gs.valid_targets(owner,card).is_empty():continue
		if id=="c22702" and gs.VerifiedRules.Bingyong.replacement_blocked(gs,owner,gs.player(owner).units[src]):continue
		var score:=20
		if id=="c22701":score=25+2*upgrades(gs,owner,id).size()
		elif id=="c22702":score=int(gs.player(owner).units[src].attack)+1+upgrades(gs,owner,id).size()
		else:
			var missing:=maxi(0,int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp))
			for u in gs.player(owner).units:missing=maxi(missing,int(u.maxHp)-int(u.hp))
			score=10+missing*5+upgrades(gs,owner,id).size()
		if score>best:best=score;out.clear()
		if score==best:out.append(card)
	return out
static func generated(gs, owner: int, src: int, id: String = "") -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or gs.VerifiedRules.Stun.blocks(gs,owner,u):return
	var card: Dictionary
	if id.is_empty():
		var pool:=incarnation_pool(gs,owner,src)
		if pool.is_empty():return
		card=pool[int(floor(gs.randf01()*pool.size()))]
	else:card=prepared_auto(gs,owner,id)
	if card.id=="c22702" and not card.get("goldfishAttachmentReplacement",false) and gs.VerifiedRules.Bingyong.replacement_blocked(gs,owner,u):return
	var ids: Array=[null] if card.get("target")=="auto" else gs.valid_targets(owner,card)
	ids=automatic_targets(gs,owner,card,ids)
	if ids.is_empty():return
	var target=ids[int(floor(gs.randf01()*ids.size()))]
	gs._push_card_frames(owner,str(card.id),target,card,src,0,true)
	gs.VerifiedRules.event(gs,"goldfish-generated",{"player":owner,"uid":u.uid,"card":card,"target":target})
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("goldfishArakawa",false):gs.resolution_stack.append({"kind":"goldfish-form","playerIndex":owner,"sourceIndex":src})
static func turn_start(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if not active(u):continue
		if u.awakened and not attached(u):attach(gs,owner,src)
		if u.get("formRules",{}).get("goldfishArakawa",false):gs.resolution_stack.append({"kind":"goldfish-form","playerIndex":owner,"sourceIndex":src})
static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if options.get("goldfishRetreat",false) and int(u.hp)>0:gs.VerifiedRules.Movement.move_to(gs,owner,src,0)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var keys: Array=card.get("goldfishEnhancements",upgrades(gs,owner,str(card.get("id",""))))
	match str(effect.get("action","")):
		"goldfish-first":attach(gs,owner,src);gs._draw(owner,1)
		"goldfish-attach":attach(gs,owner,src)
		"goldfish-support":_support(gs,owner,target,keys)
		"goldfish-training":
			var cfg:=training_config(keys);var options:=cfg.duplicate(true);options.combatCard=card.duplicate(true)
			gs._grant_unit_armor(gs.player(owner).units[src],int(cfg.shield))
			gs._resolve_combat(owner,src,int(cfg.power),bool(cfg.get("pierce",false)),false,false,false,null,false,options)
		"goldfish-rest":_rest(gs,owner,src,target_id,keys)
		"goldfish-attack-upgrade":_choose_upgrade(gs,owner,src,"attack")
		"goldfish-defense-upgrade":_choose_upgrade(gs,owner,src,"defense")
		"goldfish-awaken":
			var enhanced: bool=card.get("goldfishAwakenEnhanced",attached(gs.player(owner).units[src]))
			gs._awaken(owner,src,card,{"attack":1,"hp":1})
			if enhanced:generated(gs,owner,src)
		"goldfish-fan":
			for n in range(BASE_IDS.size()-1,-1,-1):gs.resolution_stack.append({"kind":"goldfish-auto","playerIndex":owner,"sourceIndex":src,"cardId":BASE_IDS[n]})
		_:return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner:=int(frame.get("playerIndex",0));var src:=int(frame.get("sourceIndex",-1))
	match str(frame.get("kind","")):
		"goldfish-auto":generated(gs,owner,src,str(frame.cardId))
		"goldfish-form":
			var u: Dictionary=gs.player(owner).units[src]
			if not active(u) or gs.VerifiedRules.Stun.blocks(gs,owner,u):return true
			var id: String=BASE_IDS[int(floor(gs.randf01()*BASE_IDS.size()))]
			strengthen(gs,owner,id,"attack" if gs.next_random()%2==0 else "defense");generated(gs,owner,src,id)
		_:return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("goldfishRules",false):return null
	if card.get("goldfishAttachmentReplacement",false):return 80
	match str(card.id):
		"c22701":
			var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(target_id))
			return 40+int(u.get("attack",0))+int(u.get("front",0))*5
		"c22702":return 35+training_config(card.get("goldfishEnhancements",[])).power*3
		"c22703":
			var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(target_id))
			var missing: int=int(gs.player(owner).maxAvatarHp)-int(gs.player(owner).avatarHp) if u.is_empty() else int(u.maxHp)-int(u.hp)
			return 20+mini(5,missing)*7+5*upgrades(gs,owner,str(card.id)).size()
		"c22704","c22705":return 75
		"c22706":return 85
		"c22707":return 65
		"c22708":return 95
	return 30
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx];var result: Array=[]
	if not source(u):return result
	result.append("金鱼灵咒：已结附 · 化身每回合最多一次" if attached(u) else "金鱼灵咒：未结附 · 下张1级牌改为结附并抽1")
	for id in BASE_IDS:
		var keys:=upgrades(gs,owner,id)
		if not keys.is_empty():result.append(str(Content.card_def(id).name)+"："+_upgrade_text(keys))
	return result
