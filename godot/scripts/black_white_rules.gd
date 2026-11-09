class_name BlackWhiteRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("blackWhiteRole", ""))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func partner(gs, owner: int, source_role: String) -> int:
	for i in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[i]
		if role(u)==("white" if source_role=="black" else "black") and not u.get("removed",false):return i
	return -1
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if str(card.get("id","")) not in ["c24006","c24106"]:return true
	var src:int=gs._source_index(owner,card)
	return src>=0 and not bool(gs.player(owner).units[src].get("awakened",false))
static func link_candidates(gs, owner: int, card: Dictionary) -> Array:
	var src:int=gs._source_index(owner,card)
	if src<0:return []
	var u:Dictionary=gs.player(owner).units[src]
	if role(u).is_empty() or not active(u):return []
	var other:=partner(gs,owner,role(u))
	if other<0:return []
	var ally:Dictionary=gs.player(owner).units[other]
	return gs.player(owner).deck.filter(func(inst):
		var c:Dictionary=Content.card_def(str(inst.definitionId))
		return str(c.get("unitId",""))==str(ally.id) and int(c.get("level",0))==int(ally.level))
static func link_retrieve(gs, owner: int, src: int) -> bool:
	return src>=0 and not role(gs.player(owner).units[src]).is_empty() and active(gs.player(owner).units[src]) and gs.player(owner).units[src].awakened
static func describe_card(_gs, _owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("blackWhiteRules",false):return card
	var c:=card.duplicate(true);c.linkedUse=bool(inst.get("linkedUse",card.get("linkedUse",false)))
	if c.id in ["c24007","c24008","c24107","c24108"]:
		c.enhanced=c.linkedUse
		var label:String={"c24007":"获得迅捷","c24008":"两次攻击间免疫战斗伤害","c24107":"获得昂扬","c24108":"本次战斗获得必杀"}[str(c.id)]
		c.currentCardStats=("连引增强 · "+label) if c.linkedUse else "连引使用时增强 · "+label
	return c
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("blackWhiteRules",false):return null
	if card.id=="c24002":
		return gs.player(owner).units.filter(func(u):return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (int(u.front)==1 or (not gs.VerifiedRules.Combat.has(u,"remote") and not gs.VerifiedRules.Bingyong.replacement_blocked(gs,owner,u)))).map(func(u):return str(u.uid))
	if card.id=="c24102":
		return gs.player(owner).units.filter(func(u):return int(u.hp)<=0 and int(u.level)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u) and gs.VerifiedRules.Rebirth.can_revive(u)).map(func(u):return str(u.uid))
	return null
static func temp_grow(gs, u: Dictionary, atk: int, hp: int) -> void:
	u.blackWhiteGrowthAttack=int(u.get("blackWhiteGrowthAttack",0))+atk
	u.blackWhiteGrowthHp=int(u.get("blackWhiteGrowthHp",0))+hp
	gs._grow_unit(u,atk,hp)
static func damaged(gs, owner: int, idx: int, amount: int) -> void:
	if amount<=0 or role(gs.player(owner).units[idx]).is_empty():return
	for u in gs.player(owner).units:
		if not active(u):continue
		var kind:=str(u.get("formRules",{}).get("blackWhiteHurt",""))
		if kind=="black":temp_grow(gs,u,1,0)
		elif kind=="white":temp_grow(gs,u,0,1)
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("blackWhiteRules",false):return
	var u:Dictionary=gs.player(owner).units[src]
	if card.id in ["c24003","c24103"] and not card.get("blackWhiteBondCast",false):
		var idx:=partner(gs,owner,role(u))
		if idx>=0 and int(gs.player(owner).units[idx].hp)>0:
			var c:Dictionary=Content.card_def("c24103" if card.id=="c24003" else "c24003").duplicate(true)
			c.blackWhiteBondCast=true
			gs._push_card_frames(owner,str(c.id),null,c,idx,0,true)
	if card.get("linkedUse",false):
		if card.id=="c24007":u.swift=true
		elif card.id=="c24107":gs.VerifiedRules.Combat.grant_inspired(gs,owner,src)
static func knocked_out(u: Dictionary) -> void:
	u.attackBonus=int(u.attackBonus)-int(u.get("blackWhiteGrowthAttack",0))
	u.maxHpBonus=int(u.maxHpBonus)-int(u.get("blackWhiteGrowthHp",0))
	for key in ["blackWhiteGrowthAttack","blackWhiteGrowthHp","blackWhiteVeil","blackWhiteCombatImmune"]:u.erase(key)
static func turn_start(gs, owner: int) -> void:
	for u in gs.player(owner).units:u.erase("blackWhiteVeil")
static func veil(u: Dictionary) -> bool:return int(u.get("hp",0))>0 and u.get("blackWhiteVeil",false)
static func combat_immune(u: Dictionary) -> bool:return int(u.get("hp",0))>0 and u.get("blackWhiteCombatImmune",false)
static func _second_targets(gs, owner: int) -> Array:
	var result:Array=gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and not u.get("removed",false) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
	result.append("avatar-%d"%(1-owner));return result
static func _second_choice(gs, owner: int, src: int) -> void:
	if int(gs.player(owner).units[src].hp)<=0:return
	gs.pending_choice={"type":"black-white-second","playerIndex":owner,"sourceIndex":src,"instanceIds":_second_targets(gs,owner),"heading":"连 斩 · 第二次攻击","hint":"选择一个敌方角色。本次使用普通力量；帷幕目标不可选。"}
	gs.phase="choice"
static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type")!="black-white-second" or int(gs.pending_choice.playerIndex)!=owner or not gs.pending_choice.instanceIds.has(iid):return null
	if iid.begins_with("avatar-"):
		var hp:int=int(gs.player(1-owner).avatarHp)
		return {"id":iid,"name":"敌方牌手","type":"spell","typeLabel":"攻击目标","level":0,"cost":0,"text":"牌手生命 %d\n再次攻击敌方牌手。"%hp,"currentCardStats":"生命%d"%hp,"artUnitId":"heitongzi"}
	var u:Dictionary=gs._unit_by_uid(gs.player(1-owner).units,iid)
	return {"id":iid,"name":str(u.name),"unitId":str(u.id),"type":"spell","typeLabel":"攻击目标","level":int(u.level),"cost":0,"text":"力量 %d   生命 %d/%d\n护甲 %d\n再次攻击该敌方式神。"%[u.attack,u.hp,u.maxHp,u.shield],"currentCardStats":"力量%d · 生命%d/%d · 护甲%d"%[u.attack,u.hp,u.maxHp,u.shield]}
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice:Dictionary=gs.pending_choice
	if choice.get("type")!="black-white-second" or int(choice.playerIndex)!=owner or not choice.instanceIds.has(iid) or not _second_targets(gs,owner).has(iid):return false
	var src:=int(choice.sourceIndex)
	gs.pending_choice={};gs.phase="main"
	gs._record("resolve_divination_choice",{"instanceId":iid,"choice":"black-white-second"},owner)
	var options:Dictionary={"directAvatar":iid.begins_with("avatar-"),"pursuit":not iid.begins_with("avatar-"),"immuneCombat":combat_immune(gs.player(owner).units[src])}
	gs._record("assault",{"unit":src,"bonus":0,"target":iid},owner)
	gs._resolve_combat(owner,src,0,false,false,false,false,iid,false,options)
	gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="black-white-second":return null
	if int(gs.pending_choice.playerIndex)!=owner:return false
	var src:=int(gs.pending_choice.sourceIndex);var power:int=gs.player(owner).units[src].attack
	var best:="avatar-%d"%(1-owner);var best_score:=power
	for iid in _second_targets(gs,owner):
		var u:Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(iid))
		if u.is_empty():continue
		var score:=int(u.attack)+8 if int(u.hp)+int(u.shield)<=power else 0
		if score>best_score:best=str(iid);best_score=score
	return resolve_choice(gs,owner,best)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var u:Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"black-white-move":
			if not target.is_empty() and targets(gs,owner,card).has(target.uid):
				gs.VerifiedRules.move_unit(gs,owner,target)
				if role(target)=="white":gs._draw(owner,1)
		"black-white-revive":
			if not target.is_empty() and int(target.hp)<=0:
				var idx:int=gs._unit_index_by_uid(owner,str(target.uid))
				gs.VerifiedRules.reduce_countdown(gs,owner,idx,1)
				if role(target)=="black":gs.VerifiedRules.Peach.revive(gs,owner,src,target,false,false)
		"black-white-pray":
			for ally in gs.player(owner).units:
				if not role(ally).is_empty() and active(ally):temp_grow(gs,ally,2,2)
		"black-white-awaken":
			var idx:=partner(gs,owner,role(u))
			if idx>=0:
				var ally:Dictionary=gs.player(owner).units[idx];var atk:=1 if role(u)=="black" else 0;var hp:=1-atk
				gs.VerifiedRules.Glutton.record_permanent(ally,atk,hp);gs.VerifiedRules.SunSmoke.remember_permanent(ally,atk,hp);gs._grow_unit(ally,atk,hp)
			gs._awaken(owner,src,card,{"attack":1,"hp":1})
		"black-white-combat":
			var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
			if card.id=="c24005":gs.resolution_stack.append({"kind":"black-white-partner-attack","playerIndex":owner,"sourceIndex":src})
			if card.id=="c24008":
				if card.get("linkedUse",false):u.blackWhiteCombatImmune=true;options.immuneCombat=true
				gs.resolution_stack.append({"kind":"black-white-clear-immunity","playerIndex":owner,"sourceIndex":src})
				gs.resolution_stack.append({"kind":"black-white-second","playerIndex":owner,"sourceIndex":src})
			if card.id=="c24108":u.blackWhiteVeil=true;options.lethal=bool(card.get("linkedUse",false))
			gs._grant_unit_armor(u,int(options.get("shield",0)))
			gs._record("assault",{"unit":src,"bonus":int(card.value),"target":target_id},owner)
			gs._resolve_combat(owner,src,int(card.value),false,false,false,false,target_id,false,options)
		_:return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind:=str(f.get("kind",""))
	if not kind.begins_with("black-white-"):return false
	var owner:=int(f.playerIndex);var src:=int(f.sourceIndex)
	match kind:
		"black-white-partner-attack":
			var idx:=partner(gs,owner,"black")
			if idx>=0 and active(gs.player(owner).units[idx]) and not gs.VerifiedRules.Stun.blocks(gs,owner,gs.player(owner).units[idx]):gs._resolve_combat(owner,idx,0,false,false,false,false)
		"black-white-second":_second_choice(gs,owner,src)
		"black-white-clear-immunity":gs.player(owner).units[src].erase("blackWhiteCombatImmune")
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("blackWhiteRules",false):return null
	var u:Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.id=="c24102":return 55 if targets(gs,owner,card).has(target_id) else -100
	if card.id=="c24002":return 35 if role(gs._unit_by_uid(gs.player(owner).units,str(target_id)))=="white" else 15
	if card.id in ["c24006","c24106"]:return 65 if not u.awakened else 20
	if card.type=="form":return 38 if str(u.form.get("cardId",""))!=str(card.id) else -5
	return 40
static func marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx];var result:Array=[]
	if not role(u).is_empty():result.append("连引搭档当前等级牌"+(" · 未选牌回手" if u.awakened else ""))
	if veil(u):result.append("不灭 · 帷幕至下个己方回合开始")
	if combat_immune(u):result.append("连斩 · 免疫战斗伤害")
	return result
