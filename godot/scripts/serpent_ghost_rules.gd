class_name SerpentGhostRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const SLAYER := "tanjirou"
const SLAYER_SISTER := "slayer-sister-body"

static func slayer(u: Dictionary) -> bool:
	return str(u.get("id", "")) in [SLAYER, "nezuko"]

static func duo_body(u: Dictionary, white: bool) -> String:
	if slayer(u): return SLAYER_SISTER if white else SLAYER
	return "sg-ghost-white" if white else "guishiheibai"

static func printed(card: Dictionary) -> String:
	return str(card.get("slayerSourceCard", card.get("id", "")))

static func initialize_duo(u: Dictionary) -> void:
	if u.id == "nezuko": set_duo_body(u, false)

static func role(u: Dictionary) -> String:
	if u.get("baseRulesSuppressed",false):return ""
	if u.get("sgSnake",false):return "serpent" if u.get("sgSnakeCopy",false) else "snake"
	return str(Content.unit_def(str(u.get("id",""))).get("serpentGhostRole",""))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func runtime_definition(u: Dictionary):
	if u.has("sgRuntimeDefinition"):return Content.unit_def(str(u.sgRuntimeDefinition))
	return null
static func source_index(gs, owner: int, card: Dictionary):
	if card.has("sgCasterUid"):return gs._unit_index_by_uid(owner,str(card.sgCasterUid))
	return null
static func can_deploy(u: Dictionary) -> bool:
	return not u.get("sgChaos",false) and not u.get("sgSwitchPending",false)
static func has_charge(u: Dictionary):
	if role(u)=="ghost":return not u.get("sgWhite",false)
	return null
static func combat_immune(u: Dictionary) -> bool:
	return active(u) and u.get("sgSnakeCombatImmune",false)
static func _frame(gs, kind: String, owner: int, src: int, data: Dictionary={}) -> void:
	gs.resolution_stack.append({"kind":kind,"playerIndex":owner,"sourceIndex":src,"uid":str(gs.player(owner).units[src].uid),"data":data.duplicate(true)})
static func _snakes(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u):return active(u) and u.get("sgSnake",false))
static func power_delta(gs, u: Dictionary) -> int:
	if not active(u) or not u.get("sgSnake",false):return 0
	for owner in gs.players.size():
		if gs.player(owner).units.has(u):
			return gs.player(owner).units.filter(func(source):return active(source) and source.get("formRules",{}).get("sgInspireSnakes",false)).size()
	return 0
static func refresh(gs) -> void:
	for p in gs.players:
		for u in p.units:
			if int(u.get("sgSnakeAuraApplied",0))!=power_delta(gs,u):gs._recalc(u)
static func _remove_temporary(gs, u: Dictionary) -> void:
	# Switching removes temporary numeric bonuses, not attached charms/stuns.
	for key in ["temporaryAttack","peachTemporaryAttack","shutenTemporaryAttack","bgGreenTemporary","mianRedGrowth"]:
		var n:int=int(u.get(key,0));u.attackBonus=int(u.attackBonus)-n;u.erase(key)
	u.attackBonus=int(u.attackBonus)-int(u.get("sgSwitchGrowth",0));u.maxHpBonus=int(u.maxHpBonus)-int(u.get("sgSwitchHp",0));u.erase("sgSwitchGrowth");u.erase("sgSwitchHp")
	u.shield=0;u.shieldExpires=0;u.armorBreak=0
static func switch_ghost(gs, owner: int, src: int, white: bool, count_switch: bool=true) -> void:
	var u:Dictionary=gs.player(owner).units[src]
	if role(u)!="ghost" or u.get("sgSnake",false):return
	if not u.get("form",{}).is_empty():gs.VerifiedRules.Forms.remove(gs,owner,src,"随式神切换")
	_remove_temporary(gs,u)
	u.sgWhite=white;u.erase("sgSwitchPending")
	set_duo_body(u, white)
	u.passive_hooks=[];u.front=0;u.knockout=0;u.hp=1
	u.sgWhiteCountdown=1 if u.get("sgWhiteAwakened",false) else 2
	if not white:
		if count_switch:u.sgBlackSwitches=int(u.get("sgBlackSwitches",0))+1
		u.swift=bool(u.get("sgBlackAwakened",false))
	u.unyielding=white and u.get("sgWhiteAwakened",false)
	gs._recalc(u);u.hp=int(u.maxHp)
	gs.VerifiedRules.event(gs,"sg-switch",{"player":owner,"uid":u.uid,"white":white,"count":int(u.get("sgBlackSwitches",0))})

static func set_duo_body(u: Dictionary, white: bool) -> void:
	var body := duo_body(u, white)
	var definition := Content.unit_def(body)
	u.sgRuntimeDefinition = body
	u.presentationId = body
	u.baseAttack = int(definition.get("attack", 2 if white else 3))
	u.baseMaxHp = int(definition.get("maxHp", 6 if white else 4))
	u.name = str(definition.get("name", u.name)) if slayer(u) else ("鬼使白" if white else "鬼使黑")
	u.art = definition.get("art", "")
	u.awakenedArt = u.art
static func replace_knockout(gs, owner: int, u: Dictionary) -> bool:
	if owner<0 or role(u)!="ghost" or u.get("sgWhite",false) or u.get("sgSwitchPending",false) or int(u.get("charge",0))<2:return false
	u.charge=int(u.charge)-2;u.sgSwitchPending=true;u.hp=0;u.front=0;u.knockout=0
	_frame(gs,"sg-switch-white",owner,gs._unit_index_by_uid(owner,str(u.uid)))
	return true
static func death_snapshot(gs, owner: int, u: Dictionary) -> Dictionary:
	if owner<0 or u.get("summoned",false) or u.get("removed",false):return {}
	if u.get("sgSnake",false):return {"kind":"sg-snake-restore","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,str(u.uid)),"uid":str(u.uid),"original":u.sgOriginal.duplicate(true)}
	if u.get("baseRulesSuppressed",false) or role(u)=="serpent":return {}
	for source in gs.player(owner).units:
		if source!=u and role(source)=="serpent" and active(source):
			return {"kind":"sg-snake-transform","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,str(u.uid)),"uid":str(u.uid),"masterUid":str(source.uid),"original":u.duplicate(true),"copy":bool(source.awakened)}
	return {}
static func after_knockout(gs, owner: int, u: Dictionary, saved: Dictionary) -> void:
	if role(u)=="ghost" and u.get("sgWhite",false):
		u.sgWhite=false;set_duo_body(u, false);u.swift=false;gs._recalc(u)
	if not saved.is_empty():
		if saved.get("kind")=="sg-snake-transform":saved.original=u.duplicate(true)
		gs.resolution_stack.append(saved)
	refresh(gs)
static func _remove_owner_cards(gs, owner: int, original_id: String) -> void:
	for zone in ["hand","deck"]:
		gs.player(owner)[zone]=gs.player(owner)[zone].filter(func(i):return str(Content.card_def(str(i.definitionId)).get("unitId",""))!=original_id)
static func transform_snake(gs, owner: int, src: int, master_idx: int=-1, original: Dictionary={}) -> void:
	var u:Dictionary=gs.player(owner).units[src]
	if u.get("sgSnake",false) or u.get("summoned",false):return
	var old:Dictionary=(original if not original.is_empty() else u).duplicate(true)
	if not u.get("form",{}).is_empty():gs.VerifiedRules.Forms.remove(gs,owner,src,"随蛇魔变形")
	# Replace the body of a transformed shikigami; switching ghosts never uses this path.
	var uid:String=str(u.uid);var level:int=int(u.level)
	u.clear();u.merge({"uid":uid,"id":str(old.id),"name":"蛇魔","title":"八岐大蛇变形","color":"#c68581","level":level,"baseAttack":3,"baseMaxHp":3,"attack":3,"maxHp":3,"hp":3,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"front":0,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"charge":0,"passive_hooks":[],"factionOverride":"红莲"},true)
	# paper's suppression is replaced by the explicit snake body definition.
	u.baseRulesSuppressed=false;u.sgSnake=true;u.sgOriginal=old;u.sgRuntimeDefinition="sg-snake";u.presentationId="sg-snake";u.name="蛇魔";u.baseAttack=3;u.baseMaxHp=3
	u.attackBonus=0;u.maxHpBonus=0;u.form={};u.formRules={};u.formHooks=[];u.formAbility="迅捷。";u.passive_hooks=[];u.swift=true;u.knockout=0;u.hp=3;u.front=0;u.charge=0
	u.art=Content.unit_def("sg-snake").get("art","");u.awakenedArt=u.art
	if master_idx>=0:
		var master:Dictionary=gs.player(owner).units[master_idx]
		if master.awakened:
			u.sgSnakeCopy=true;u.sgChaos=true;u.sgRuntimeDefinition="bayiqidashe";u.awakened=true
			for key in ["baseAttack","baseMaxHp","attackBonus","maxHpBonus","form","formRules","formHooks","formAbility"]:
				var fallback={} if key in ["form","formRules"] else [] if key=="formHooks" else "" if key=="formAbility" else 0
				var copied=master.get(key)
				if copied==null:copied=fallback
				u[key]=copied.duplicate(true) if copied is Dictionary or copied is Array else copied
			u.sgChaosCopiedFrom=str(master.uid);_remove_owner_cards(gs,owner,str(old.id))
	gs._recalc(u);u.hp=int(u.maxHp)
	refresh(gs)
	gs.VerifiedRules.event(gs,"sg-snake-created",{"player":owner,"uid":u.uid,"copied":u.get("sgSnakeCopy",false),"originalId":str(old.id)})
static func before_damage(gs, owner: int, idx: int, incoming: int) -> bool:
	var u:Dictionary=gs.player(owner).units[idx]
	if incoming<int(u.hp) or incoming<=0 or not active(u) or not u.get("formRules",{}).get("sgShadow",false):return false
	var snakes:Array=_snakes(gs,owner).filter(func(s):return s!=u)
	if snakes.is_empty():return false
	var chosen:Dictionary=snakes[int(gs.next_random()%snakes.size())]
	gs.VerifiedRules.Panguan.destroy(gs,owner,idx,owner,gs._unit_index_by_uid(owner,str(chosen.uid)),{})
	gs.VerifiedRules.event(gs,"sg-lethal-replaced",{"player":owner,"uid":u.uid,"snakeUid":chosen.uid,"amount":incoming})
	return true
static func incarnation_config(u: Dictionary):
	if u.get("sgChaos",false) and active(u):return {"start":25,"action":15,"limit":1,"mode":"sg-chaos"}
	return null
static func incarnation_pool(gs, owner: int, src: int) -> Array:
	var out:Array=[]
	for id in ["c22001","c22003","c22005","c22006"]:
		var c:Dictionary=Content.card_def(id).duplicate(true);c.sgCasterUid=str(gs.player(owner).units[src].uid)
		if int(c.level)>int(gs.player(owner).units[src].level):continue
		if c.get("target","auto")!="auto" and targets(gs,owner,c).is_empty():continue
		out.append(c)
	return out
static func has_incarnation(u: Dictionary) -> bool:
	return bool(u.get("sgChaos",false))
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("serpentGhostRules",false):return null
	var id:=str(card.id);var src:int=gs._source_index(owner,card)
	if id in ["c22001","c22003"]:
		return gs.player(owner).units.filter(func(u):return active(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and (src<0 or u!=gs.player(owner).units[src]) and (id!="c22003" or not u.get("summoned",false)) and (not card.has("sgCasterUid") or id!="c22001" or role(u)!="serpent" or u.get("sgSnake",false))).map(func(u):return str(u.uid))
	if card.get("target","")=="sg-pursuit":return gs.player(1-owner).units.filter(func(u):return active(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
	if id=="c22006":return gs.player(1-owner).units.filter(func(u):return active(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and not u.get("sgSnake",false) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
	return null
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	var src:int=gs._source_index(owner,card)
	if src<0:return true
	var u:Dictionary=gs.player(owner).units[src]
	if u.get("sgChaos",false) or u.get("sgSwitchPending",false):return false
	if u.get("sgSnake",false):return false
	if int(card.get("movementBurst",0))>0 and not gs.VerifiedRules.Yujiazhu.can_pay_burst(gs,owner,src,int(card.movementBurst)):return false
	var id := printed(card)
	if id in ["c19402", "c18202"]:return bool(u.get("sgWhite",false))
	if id in ["c19405", "c18205"]:return not u.get("sgWhite",false)
	if id=="c22008":return not u.awakened
	if id in ["sg-white-awaken", "sg-slayer-awaken"]:return u.get("sgWhite",false) and not u.get("sgWhiteAwakened",false)
	return true
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("serpentGhostRules",false):return card
	var c:=card.duplicate(true);var src:int=gs._source_index(owner,c)
	if src<0:return c
	var u:Dictionary=gs.player(owner).units[src]
	var id := printed(c)
	if c.id=="c19404" and gs.player(owner).get("sgGhostAwakeningChanged",false):
		c=Content.card_def("sg-white-awaken").duplicate(true)
	if id=="c18204" and u.get("sgBlackAwakened", false):
		c=Content.card_def("sg-slayer-awaken").duplicate(true)
		c.unitId = u.id
	if id in ["c19406", "c18206"]:
		var count := int(u.get("sgBlackSwitches",0))
		c.currentCardStats="切换回%s%d次 · 复制%d次"%["炭治郎" if slayer(u) else "黑", count, count]
	if u.get("sgSnake",false):c.currentCardStats="蛇魔变形期间不可手动使用原专属牌"
	if id in ["c19401", "c19403", "c18201", "c18203"]:
		var grants_instant := id in ["c19401", "c18201"]
		c.movementBurstOptions=[2];c.movementBurst=int(inst.get("movementBurst",0))
		c.currentCardStats="爆能2 · "+("瞬发" if grants_instant else "追猎") if c.movementBurst==2 else "普通使用 · 可选择爆能2"
		if c.movementBurst==2:
			if grants_instant:c.keywords.append("instant")
			else:c.keywords.append("pursuit");c.target="sg-pursuit";c.combatOption.pursuit=true
	return c
static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if options.get("sgKillAfter",false) and active(gs.player(owner).units[src]) and not gs.player(owner).units[src].get("sgSnake",false):gs.VerifiedRules.Panguan.destroy(gs,owner,src,owner,src,{})
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("sgInspireSnakes",false):
		for snake in _snakes(gs,owner):gs.VerifiedRules.Combat.grant_inspired(gs,owner,gs._unit_index_by_uid(owner,str(snake.uid)))
	refresh(gs)
static func begin_turn(gs, owner: int) -> void:
	for side in 2:
		for src in gs.player(side).units.size():
			var u:Dictionary=gs.player(side).units[src]
			if not active(u):continue
			if side==owner and role(u)=="ghost" and u.get("sgWhite",false):
				u.sgWhiteCountdown=int(u.get("sgWhiteCountdown",2))-1
				if int(u.sgWhiteCountdown)<=0:switch_ghost(gs,side,src,false)
			if u.get("formRules",{}).get("sgWandering",false):
				var ids:Array=[str(u.uid)];ids.append_array(_snakes(gs,side).filter(func(s):return s!=u).map(func(s):return str(s.uid)))
				_frame(gs,"sg-wandering",side,src,{"uids":ids,"cursor":0})
			if side==owner and u.get("formRules",{}).get("sgInspireSnakes",false):form_entered(gs,side,src,{"formRules":{"sgInspireSnakes":true}})
static func end_turn(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[src]
		if active(u) and u.get("formRules",{}).get("sgVerdict",false):
			var armor:int=int(u.charge);switch_ghost(gs,owner,src,true);gs._grant_unit_armor(u,armor)
static func damage_dealt(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> void:
	if owner>=0 and src>=0 and amount>0:
		var u:Dictionary=gs.player(owner).units[src]
		if active(u) and u.get("formRules",{}).get("sgLivingDead",false):gs.VerifiedRules.SunSmoke.gain_charge(gs,owner,src,1)
	if victim<0 or idx<0 or amount<=0:return
	var target:Dictionary=gs.player(victim).units[idx]
	if active(target) and role(target)=="ghost" and target.get("sgWhite",false) and target.get("sgWhiteAwakened",false) and int(target.get("sgSoulTurn",-1))!=gs.turn_counter:
		target.sgSoulTurn=gs.turn_counter
		var c:Dictionary=Content.card_def("sg-slayer-blood" if slayer(target) else "sg-white-soul").duplicate(true);c.sgSoulDamage=amount
		c.unitId = target.id
		gs._push_card_frames(victim,str(c.id),null,c,idx,0,true)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var action:=str(effect.get("action",""));if not action.begins_with("sg-"):return false
	var u:Dictionary=gs.player(owner).units[src]
	match action:
		"sg-form":gs._install_form(owner,src,card,effect.value)
		"sg-impure":
			var idx:int=gs._unit_index_by_uid(owner,str(target_id))
			if idx>=0 and active(gs.player(owner).units[idx]):
				gs._grow_unit(gs.player(owner).units[idx],2,0);gs.player(owner).units[idx].sgOrdinaryGrowth=int(gs.player(owner).units[idx].get("sgOrdinaryGrowth",0))+2
				gs._resolve_combat(owner,idx,0,false,false,false,false,null,false,{"sgKillAfter":not gs.player(owner).units[idx].get("sgSnake",false)})
		"sg-sacrifice":
			var idx:int=gs._unit_index_by_uid(owner,str(target_id))
			if idx>=0 and gs.VerifiedRules.Panguan.destroy(gs,owner,src,owner,idx,card):gs.player(owner).attackUsed=false;gs._draw(owner,1)
		"sg-all-snakes":
			var ids:Array=_snakes(gs,owner).map(func(s):return str(s.uid));_frame(gs,"sg-snake-attacks",owner,src,{"uids":ids,"cursor":0})
		"sg-transform-enemy":
			var idx:int=gs._unit_index_by_uid(1-owner,str(target_id))
			if idx>=0:transform_snake(gs,1-owner,idx)
		"sg-serpent-awaken":
			gs._awaken(owner,src,card,{"attack":5,"hp":5});u.sgChaos=true;_remove_owner_cards(gs,owner,str(u.id))
		"sg-ghost-combat":
			if int(card.get("movementBurst",0))>0 and not gs.VerifiedRules.Yujiazhu.pay_burst(gs,owner,src,int(card.movementBurst)):return true
			var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
			gs._grant_unit_armor(u,int(options.get("shield",0)));gs._resolve_combat(owner,src,int(card.value),false,false,false,false,target_id,false,options)
		"sg-brothers":switch_ghost(gs,owner,src,false);gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"immuneCombat":true,"crabImmuneAll":true})
		"sg-ghost-awaken":
			gs._awaken(owner,src,card,{"attack":1,"hp":1});u.sgBlackAwakened=true;u.swift=true
			if not slayer(u): gs.player(owner).sgGhostAwakeningChanged=true
		"sg-white-awaken":
			gs.VerifiedRules.Glutton.record_permanent(u,2,2,true);gs._grow_unit(u,2,2);u.sgWhiteAwakened=true;u.sgWhiteCountdown=1;u.unyielding=true
		"sg-white-soul":gs.VerifiedRules.base_damage_projectile(gs,owner,src,int(card.get("sgSoulDamage",0)),str(card.name) if slayer(u) else "鬼使白索魂")
		"sg-impermanence":switch_ghost(gs,owner,src,true);u.sgWhiteCountdown=1;gs._grow_unit(u,3,1);u.sgSwitchGrowth=3;u.sgSwitchHp=1;gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{})
		"sg-reap":
			var n:int=int(card.get("sgReapOrdinal",0));var left:int=int(card.get("sgReapRemaining",int(u.get("sgBlackSwitches",0))))
			if left>0:_frame(gs,"sg-reap-next",owner,src,{"card":card.duplicate(true),"ordinal":n+1,"remaining":left-1})
			gs._grant_unit_armor(u,n);gs._resolve_combat(owner,src,n,false,false,false,false,null,false,{"combatCard":card.duplicate(true)})
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""));if not kind.begins_with("sg-"):return false
	var owner:=int(frame.playerIndex);var src:int=gs._unit_index_by_uid(owner,str(frame.uid));if src<0:return true
	var u:Dictionary=gs.player(owner).units[src];var data:Dictionary=frame.get("data",{})
	match kind:
		"sg-switch-white":switch_ghost(gs,owner,src,true)
		"sg-snake-transform":
			var master:int=gs._unit_index_by_uid(owner,str(frame.masterUid))
			if master>=0 and active(gs.player(owner).units[master]) and int(u.hp)<=0:transform_snake(gs,owner,src,master,frame.original)
		"sg-snake-restore":
			var original:Dictionary=frame.original.duplicate(true);var countdown:int=int(u.knockout)
			# Original stored before dying receives a real knockout cleanup before restore.
			for key in ["id","name","baseAttack","baseMaxHp","attackBonus","maxHpBonus","awakened","charge","passive_hooks"]:u[key]=original.get(key,0)
			for key in ["sgSnake","sgSnakeCopy","sgChaos","sgRuntimeDefinition","sgSnakeCombatImmune","sgOriginal"]:u.erase(key)
			u.presentationId=str(u.id);u.form={};u.formRules={};u.formHooks=[];u.formAbility="";u.hp=0;u.front=0;u.knockout=countdown;u.swift=false
			gs.VerifiedRules.knocked_out(u);gs._recalc(u)
		"sg-snake-attacks":
			var cursor:int=int(data.cursor);var ids:Array=data.uids
			if cursor<ids.size():
				data.cursor=cursor+1;_frame(gs,kind,owner,src,data)
				var idx:int=gs._unit_index_by_uid(owner,str(ids[cursor]))
				if idx>=0 and active(gs.player(owner).units[idx]) and gs.player(owner).units[idx].get("sgSnake",false):gs.player(owner).units[idx].sgSnakeCombatImmune=true;gs._resolve_combat(owner,idx,0,false,false,false,false,null,false,{"immuneCombat":true})
		"sg-wandering":
			if not active(u) or not u.get("formRules",{}).get("sgWandering",false):return true
			var cursor:int=int(data.cursor);var ids:Array=data.uids
			if cursor<ids.size():
				data.cursor=cursor+1;_frame(gs,kind,owner,src,data)
				var idx:int=gs._unit_index_by_uid(owner,str(ids[cursor]))
				if idx>=0 and active(gs.player(owner).units[idx]):
					var pool:Array=["avatar-%d"%(1-owner)];pool.append_array(gs.player(1-owner).units.filter(func(t):return int(t.hp)>0 and not t.get("removed",false)).map(func(t):return str(t.uid)))
					var target:String=pool[int(gs.next_random()%pool.size())];var enemy:int=gs._unit_index_by_uid(1-owner,target)
					if enemy<0:gs._damage_avatar(1-owner,3,owner,idx)
					else:gs._damage_unit(1-owner,enemy,3,owner,idx)
		"sg-reap-next":
			if active(u):
				var c:Dictionary=data.card.duplicate(true);c.sgReapOrdinal=int(data.ordinal);c.sgReapRemaining=int(data.remaining);gs._push_card_frames(owner,str(c.id),null,c,src,0,true)
	return true
static func knocked_out(u: Dictionary) -> void:
	u.attackBonus=int(u.attackBonus)-int(u.get("sgOrdinaryGrowth",0))-int(u.get("sgSwitchGrowth",0));u.maxHpBonus=int(u.maxHpBonus)-int(u.get("sgSwitchHp",0))
	for key in ["sgOrdinaryGrowth","sgSwitchGrowth","sgSwitchHp","sgSnakeCombatImmune"]:u.erase(key)
static func marks(_gs, _owner: int, u: Dictionary) -> Array:
	var out:Array=[]
	if role(u)=="ghost":
		var white := bool(u.get("sgWhite",false))
		var label := str(u.name) if slayer(u) else ("鬼使白" if white else "鬼使黑")
		out.append("%s · 倒计时%d"%[label,int(u.get("sgWhiteCountdown",2))] if white else "%s · 切换回初始身份%d次"%[label,int(u.get("sgBlackSwitches",0))])
	if u.get("sgSnake",false):out.append("蛇魔 · 原身份"+str(u.sgOriginal.name))
	if u.get("sgChaos",false):out.append("混沌化身 · 禁止手动操作")
	return out
static func score_card(gs, owner: int, card: Dictionary, target_id=null):
	if not card.get("serpentGhostRules",false):return null
	if card.id=="c22008":return 55
	if card.id in ["c22003","c22001"]:
		var idx:int=gs._unit_index_by_uid(owner,str(target_id));return 50 if idx>=0 and gs.player(owner).units[idx].get("sgSnake",false) else 12
	return 42

static func ai_prepare(gs, owner: int) -> void:
	for i in gs.playable_card_count(owner):
		var inst:Dictionary=gs.card_instance(owner,i)
		if str(inst.get("definitionId","")) not in ["c19401","c19403"]:continue
		var src:int=gs._source_index(owner,Content.card_def(str(inst.definitionId)))
		if src>=0:inst.movementBurst=2 if gs.VerifiedRules.Yujiazhu.can_pay_burst(gs,owner,src,2) else 0
