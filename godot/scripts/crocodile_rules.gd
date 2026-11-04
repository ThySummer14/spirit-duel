class_name CrocodileRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("crocodileRules",false)
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func attached(u: Dictionary) -> bool:
	return not u.get("crocCharm",{}).is_empty()
static func stats(gs, owner: int) -> Dictionary:
	return gs.player(owner).get("crocEffect",{"attack":1,"hp":0,"pierce":false,"attackFirst":false})
static func bonus(gs, u: Dictionary, key: String) -> int:
	return int(stats(gs,int(u.crocCharm.owner)).get(key,0)) if attached(u) else 0
static func has_trait(u: Dictionary, key: String) -> bool:
	return attached(u) and bool(u.crocCharm.get(key,false))
static func refresh(gs, owner: int) -> void:
	var effect := stats(gs,owner)
	for p in gs.players:
		for u in p.units:
			if attached(u) and int(u.crocCharm.owner)==owner:
				u.crocCharm.pierce=bool(effect.pierce); u.crocCharm.attackFirst=bool(effect.attackFirst)
				gs._recalc(u)
static func enhance(gs, owner: int, attack: int=0, hp: int=0, keyword: String="") -> void:
	var p: Dictionary=gs.player(owner)
	if not p.has("crocEffect"): p.crocEffect=stats(gs,owner).duplicate(true)
	p.crocEffect.attack=int(p.crocEffect.attack)+attack; p.crocEffect.hp=int(p.crocEffect.hp)+hp
	if keyword!="": p.crocEffect[keyword]=true
	refresh(gs,owner)
	gs.VerifiedRules.event(gs,"crocodile-enhanced",{"player":owner,"attack":int(p.crocEffect.attack),"hp":int(p.crocEffect.hp),"keyword":keyword})
static func detach(gs, u: Dictionary, reason: String="灵咒移除", finish_unit: bool=true) -> void:
	if not attached(u): return
	var owner := int(u.crocCharm.owner)
	u.erase("crocCharm")
	gs._recalc(u)
	gs.VerifiedRules.event(gs,"crocodile-detached",{"player":owner,"uid":u.uid,"reason":reason})
	if finish_unit and int(u.hp)<=0 and int(u.get("knockout",0))==0 and not u.get("removed",false): gs._knockout_unit(u)
static func attach(gs, owner: int, src: int, target: Dictionary) -> bool:
	if target.is_empty() or int(target.hp)<=0 or target.get("removed",false): return false
	if attached(target) and int(target.crocCharm.owner)==owner: return false
	var old_units: Array=[]
	for p in gs.players:
		for old in p.units:
			if attached(old) and int(old.crocCharm.owner)==owner:
				detach(gs,old,"鬼鳄移至另一式神",false); old_units.append(old)
	if attached(target): detach(gs,target,"鬼鳄被替换",false)
	var effect := stats(gs,owner)
	target.crocCharm={"owner":owner,"sourceUid":gs.player(owner).units[src].uid,"pierce":bool(effect.pierce),"attackFirst":bool(effect.attackFirst)}
	gs._recalc(target)
	gs.VerifiedRules.event(gs,"crocodile-attached",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":target.uid})
	for field in gs.player(owner).realms:
		if field.get("nativeRealm")=="crocodile-shadow" and int(field.hp)>0:
			target.swift=true
			gs.VerifiedRules.event(gs,"swift-gained",{"player":owner,"uid":target.uid})
	for old in old_units:
		if int(old.hp)<=0 and int(old.get("knockout",0))==0 and not old.get("removed",false): gs._knockout_unit(old)
	return true
static func upgraded(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not source(u) or u.get("crocFirstUpgrade",false): return
	u.crocFirstUpgrade=true
	if active(u): attach(gs,owner,src,u)
static func before_basic(gs, owner: int, src: int) -> void:
	var p: Dictionary=gs.player(owner); var attacker: Dictionary=p.units[src]
	if not gs.VerifiedRules.OwlInsect.shikigami(attacker): return
	# Both are deployment triggers; cards commanding an attack do not enter here.
	for i in p.units.size():
		var host: Dictionary=p.units[i]
		if active(host) and host.get("formRules",{}).get("crocodileDeployment",false): attach(gs,owner,i,attacker)
	for i in p.units.size():
		var host: Dictionary=p.units[i]
		if not source(host) or int(host.level)<1 or host.get("removed",false) or host.get("baseRulesSuppressed",false): continue
		if not host.awakened and (i!=src or not active(host)): continue
		if attached(attacker): enhance(gs,int(attacker.crocCharm.owner),1)
		else: gs._grow_unit(attacker,1,0)
static func removed(gs, details: Dictionary) -> void:
	var u: Dictionary=gs._unit_by_uid(gs._all_units(),details.get("uid",""))
	if not u.is_empty(): detach(gs,u,"携带者被移除",false)
static func attack_first(u: Dictionary) -> bool:
	return has_trait(u,"attackFirst") and int(u.hp)>0
static func describe_card(gs, owner: int, _inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("crocodileRules",false): return card
	var view := card.duplicate(true)
	var src: int=gs._source_index(owner,card)
	if src<0: return view
	var host: Dictionary=gs.player(owner).units[src]
	if card.id=="c27901" and gs.player(owner).get("crocNixiWhileKnocked",false):
		view.allowKnockedSource=true
		view.currentCardStats="觉醒影鳄 · 气绝可用"
		view.text+="\n本局匿息获得气绝时可用。"
	if card.id=="c27907":
		view.enhanced=attached(host)
		if view.enhanced: view.keywords.append("instant")
		view.currentCardStats="当前5/6 · "+("瞬发" if view.enhanced else "未满足瞬发")
	if card.id in ["c27901","c27903","c27906"]:
		var s:=stats(gs,owner)
		view.crocodileEffectText="鬼鳄 · 唯一 · +%d力量/+%d生命%s%s"%[int(s.attack),int(s.hp)," · 贯通" if s.pierce else ""," · 攻击时先攻" if s.attackFirst else ""]
		view.text+="\n"+view.crocodileEffectText
	return view
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("crocodileRules",false): return true
	var src: int=gs._source_index(owner,card)
	return src>=0 and not (card.id=="c27904" and gs.player(owner).units[src].awakened)
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("crocodileRules",false) or card.get("target","auto")=="auto": return null
	var pool: Array=[]
	for side in [1-owner] if card.type=="combat" else [owner]:
		for u in gs.player(side).units:
			if int(u.hp)<=0 or u.get("removed",false) or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
			if card.id=="c27906" and (not gs.VerifiedRules.Samurai.available(u) or gs.VerifiedRules.Stun.blocks(gs,owner,u) or int(u.level)<1 or u.get("cannotAttack",false) or (not gs.VerifiedRules.Combat.has(u,"remote") and gs.VerifiedRules.Bingyong.replacement_blocked(gs,owner,u))): continue
			pool.append(u.uid)
	if card.type=="combat" and gs.front_index(1-owner)<0: pool.append("avatar-%d"%(1-owner))
	return pool
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	if not str(effect.get("action","")).begins_with("crocodile-"): return false
	var u: Dictionary=gs.player(owner).units[src]
	match str(effect.action):
		"crocodile-nixi":
			if attached(target) and int(target.crocCharm.owner)==owner: enhance(gs,owner,1,1)
			else: attach(gs,owner,src,target)
		"crocodile-realm":
			gs._deploy_realm(owner,card); attach(gs,owner,src,target)
		"crocodile-awaken":
			attach(gs,owner,src,u)
			gs._awaken(owner,src,card,{"attack":1,"hp":1})
			gs.player(owner).crocNixiWhileKnocked=true
		"crocodile-hunt":
			attach(gs,owner,src,target)
			var idx: int=gs._unit_index_by_uid(owner,target_id)
			if idx<0 or not targets(gs,owner,card).has(target_id): return true
			gs._record("assault",{"unit":idx,"bonus":0,"target":null},owner)
			gs._resolve_combat(owner,idx,0,false,false,false,false,null,false,{"immuneCombat":true,"combatCard":card.duplicate(true)})
		"crocodile-combat":
			if attached(u):
				var charm_owner:=int(u.crocCharm.owner)
				if card.id=="c27902": enhance(gs,charm_owner,0,0,"pierce")
				elif card.id=="c27905": enhance(gs,charm_owner,0,0,"attackFirst")
				elif card.id=="c27908": enhance(gs,charm_owner,2,2)
			var options: Dictionary=card.get("combatOption",{}).duplicate(true)
			options.combatCard=card.duplicate(true)
			gs._grant_unit_armor(u,int(options.get("shield",0)))
			gs._record("assault",{"unit":src,"bonus":int(card.value),"target":target_id},owner)
			gs._resolve_combat(owner,src,int(card.value),bool(options.get("pierce",false)),false,false,bool(options.get("firstStrike",false)),target_id,false,options)
		_: return false
	return true
static func unit_marks(gs, owner: int, src: int) -> Array:
	var u: Dictionary=gs.player(owner).units[src]; var result: Array=[]
	if attached(u):
		var s:=stats(gs,int(u.crocCharm.owner))
		result.append("鬼鳄 · 唯一 · +%d力量/+%d生命%s%s"%[int(s.attack),int(s.hp)," · 贯通" if s.pierce else ""," · 攻击时先攻" if s.attackFirst else ""])
	if source(u):
		var s:=stats(gs,owner)
		result.append("鬼鳄永久效果 · +%d/+%d"%[int(s.attack),int(s.hp)])
		if u.awakened: result.append("觉醒 · 己方出击成长，气绝有效 · 匿息气绝可用")
	if u.get("formRules",{}).get("crocodileDeployment",false): result.append("诡影重重 · 己方出击时结附鬼鳄")
	return result
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("crocodileRules",false): return null
	var u: Dictionary=gs._unit_by_uid(gs.player(owner).units,target_id)
	if card.id=="c27901": return 60+int(u.get("attack",0))*2
	if card.id=="c27906": return 65+int(u.get("attack",0))*3
	if card.id=="c27904": return 95
	if card.type=="form": return -50 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 70
	return 60
