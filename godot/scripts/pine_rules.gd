class_name PineRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Glossary := preload("res://scripts/ui/keyword_glossary.gd")
# The official text lists fourteen buff references. Keep the complete keyword
# set; do not turn an unknown buff ID into a guessed stat bonus.
const TRAITS := ["swift","pierce","combo","remote","first-strike","direct","pursuit","penetration","unyielding","crit","lethal","lifesteal","veil","inspired"]

static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("pineRules",false))
static func active(u: Dictionary) -> bool:
	return source(u) and int(u.hp)>0 and int(u.level)>0
static func countdown_zero(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not source(u): return
	u.pineCountdownZeros=int(u.get("pineCountdownZeros",0))+1
	gs.VerifiedRules.event(gs,"pine-countdown-zero",{"player":owner,"uid":u.uid,"count":u.pineCountdownZeros})
static func fortune_success(gs, owner: int) -> void:
	for idx in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[idx]
		if source(u) and int(u.level)>0:
			gs.VerifiedRules.reduce_countdown(gs,owner,idx,1)
static func knockout_extra(u: Dictionary) -> int:
	return 3 if source(u) and int(u.level)>0 and u.get("formRules",{}).get("pineCoward",false) else 0
static func knocked_out(u: Dictionary) -> void:
	if "unyielding" in u.get("pineKeywords",[]): u.unyielding=false
	for key in u.get("pineKeywords",[]):
		if u.has("keywords"): u.keywords.erase(key)
	u.erase("pineKeywords")
static func before_attack(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if active(u) and u.get("formRules",{}).get("pineCurious",false): gs.VerifiedRules.reduce_countdown(gs,owner,src,1)
static func revived(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if active(u) and u.awakened: u.swift=true
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("pineRules",false): return
	if card.get("formRules",{}).get("pineIdol",false):
		# Drawing follows entry and any entry response, including lethal ones.
		gs.resolution_stack.append({"kind":"pine-idol-draw","playerIndex":owner})
		gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
	if card.get("formRules",{}).get("pineHarvest",false): gs.VerifiedRules.reduce_countdown(gs,owner,src,2,owner)
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("pineRules",false): return card
	var out:=card.duplicate(true)
	var src: int=gs._source_index(owner,card)
	if src<0: return out
	var u: Dictionary=gs.player(owner).units[src]
	if card.get("pineBounce",false):
		out.pineInstance=inst.duplicate(true)
		out.pineReturn=not inst.get("pineBounceSpent",false)
		if not out.pineReturn:
			out.keywords=out.keywords.filter(func(k):return k!="bounce")
			out.text=out.text.replace("，弹回","")
	if card.get("effect")=="pine-awaken":
		var count:=int(u.get("pineCountdownZeros",0))
		out.value={"attack":count,"hp":count}
		out.effects[0].value=out.value.duplicate(true)
		out.currentCardStats="当前增益 +%d/+%d" % [count,count]
		out.text+="\n本局小松丸倒计时已归零%d次。" % count
	return out
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("pineReturn",false): return
	for i in gs.resolution_stack.size():
		if gs.resolution_stack[i].get("kind")=="card-complete" and gs.resolution_stack[i].get("resolutionId")==frame.resolutionId:
			gs.resolution_stack.insert(i,{"kind":"pine-bounce","playerIndex":int(frame.playerIndex),"card":card.duplicate(true)})
			return
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("pineRules",false): return true
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	var u: Dictionary=gs.player(owner).units[src]
	return not (card.get("effect")=="pine-awaken" and u.awakened)
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("pineRules",false) or card.get("target")!="enemy-unit": return null
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	var u: Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"pine-grow":
			if active(u): gs._grow_unit(u,1,1)
		"pine-return-form":
			if int(u.hp)>0 and u.get("form",{}).get("cardId")==card.id:
				gs.VerifiedRules.Forms.remove(gs,owner,src,"倒计时返回手牌")
				add_card(gs,owner,str(card.id))
				gs.VerifiedRules.event(gs,"pine-form-returned",{"player":owner,"uid":u.uid,"card":card})
		"pine-summon":
			if active(u): summon(gs,owner,src)
		"pine-carry":
			var depth: int=gs.resolution_stack.size()
			if gs.VerifiedRules.Light.roll(gs,owner,4,6,src):
				gs.resolution_stack.insert(depth,{"kind":"pine-draw","playerIndex":owner,"amount":gs.VerifiedRules.Fortune.last_repeats(gs,owner)})
		"pine-hit":
			gs.resolution_stack.append({"kind":"pine-hit-after-entry","playerIndex":owner,"sourceIndex":src,"targetId":target_id,"card":card.duplicate(true)})
			gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
		"pine-combat":
			var opts: Dictionary=card.get("combatOption",{}).duplicate(true)
			opts.combatCard=card.duplicate(true)
			var depth: int=gs.resolution_stack.size()
			opts.immuneCombat=gs.VerifiedRules.Light.roll(gs,owner,4,6,src)
			# Fortune can finish the attached timer. Its effects resolve before
			# the attack begins, preserving the actual resulting body/frontline.
			gs.resolution_stack.insert(depth,{"kind":"pine-combat-ready","playerIndex":owner,"sourceIndex":src,"targetId":target_id,"value":int(effect.value),"options":opts})
		"pine-awaken":
			if not u.awakened:
				u.awakened=true; u.passive_hooks=[]; u.swift=true
				gs._grow_unit(u,int(effect.value.attack),int(effect.value.hp))
		_: return false
	return true
static func add_card(gs, owner: int, id: String) -> void:
	if gs.player(owner).hand.size()>=int(gs.rules.maxHandSize): return
	gs.player(owner).hand.append({"instanceId":"%s-pine-%d" % [gs.player(owner).id,gs.next_card_id],"definitionId":id})
	gs.next_card_id+=1
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind","")); var owner:=int(frame.get("playerIndex",0))
	match kind:
		"pine-idol-draw","pine-draw": gs._draw(owner,int(frame.get("amount",1)))
		"pine-bounce":
			var card: Dictionary=frame.card
			var inst: Dictionary=card.pineInstance.duplicate(true); inst.pineBounceSpent=true
			if gs.player(owner).hand.size()<int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
			gs.VerifiedRules.event(gs,"pine-card-returned",{"player":owner,"card":card,"instanceId":inst.get("instanceId","")})
		"pine-combat-ready":
			var src:=int(frame.sourceIndex)
			if int(gs.player(owner).units[src].hp)>0: gs._resolve_combat(owner,src,int(frame.value),false,false,false,false,frame.targetId,false,frame.options)
		"pine-hit-after-entry":
			var idx: int=gs._unit_index_by_uid(1-owner,frame.targetId); var src:=int(frame.sourceIndex)
			if idx<0 or int(gs.player(1-owner).units[idx].hp)<=0: return true
			gs._damage_unit(1-owner,idx,3,owner,src)
			# The fortune clause is independent of whether the damage killed.
			if gs.VerifiedRules.Light.roll(gs,owner,4,6,src):
				if int(gs.player(1-owner).units[idx].hp)>0: gs.VerifiedRules.Stun.apply(gs,1-owner,idx,1,owner)
		_: return false
	return true
static func grant_trait(gs, owner: int, idx: int, key: String) -> void:
	var u: Dictionary=gs.player(owner).units[idx]
	if key not in TRAITS or not active(u): return
	if not u.has("pineKeywords"): u.pineKeywords=[]
	if not u.pineKeywords.has(key): u.pineKeywords.append(key)
	if key=="swift": u.swift=true
	elif key=="unyielding": u.unyielding=true
	elif key=="inspired": gs.VerifiedRules.Combat.grant_inspired(gs,owner,idx)
	else:
		if not u.has("keywords"): u.keywords=[]
		if not u.keywords.has(key): u.keywords.append(key)
	gs.VerifiedRules.event(gs,"pine-keyword-gained",{"player":owner,"uid":u.uid,"keyword":key})
static func left(gs, owner: int, token: Dictionary) -> void:
	if token.get("pineLeaveResolved",false): return
	token.pineLeaveResolved=true
	for idx in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[idx]
		if not active(u) or not u.get("formRules",{}).get("pineHarvest",false): continue
		var pool:=TRAITS.filter(func(k):return not u.get("pineKeywords",[]).has(k))
		if pool.is_empty(): continue
		grant_trait(gs,owner,idx,str(pool[int(floor(gs.randf01()*pool.size()))]))
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("pineSummon",false) or u.get("removed",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	left(gs,owner,u)
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("pineSummon",false) and int(u.front)==0: remove_summon(gs,owner,u)
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	if not u.get("pineSummon",false): return
	# Generic summoned-knockout cleanup may already mark it removed. The
	# source's leave trigger still resolves once for that actual departure.
	u.hp=0; u.front=0; u.knockout=0; u.removed=true
	left(gs,owner,u)
static func summon(gs, owner: int, src: int) -> int:
	var p: Dictionary=gs.player(owner)
	for idx in p.units.size():
		var old: Dictionary=p.units[idx]
		if old.get("pineSummon",false) and int(old.hp)>0 and not old.get("removed",false):
			# Fusion is a continuous object, so it never fires leave rewards.
			gs._grow_unit(old,4,4)
			gs.VerifiedRules.event(gs,"pine-summon-fused",{"player":owner,"uid":old.uid,"attack":old.attack,"hp":old.hp})
			return idx
	gs.VerifiedRules.TomatoFire.clear_summons(gs,owner); gs.VerifiedRules.Xuenv.clear_wall(gs,owner)
	gs.VerifiedRules.Paint.clear_summons(gs,owner)
	for other in p.units:
		if other.get("smokeClone",false): gs.VerifiedRules.SunSmoke.remove_clone(gs,owner,other,"战斗区被替换")
		var before:=int(other.front); other.front=0
		gs.VerifiedRules.Movement.moved(gs,owner,gs._unit_index_by_uid(owner,other.uid),before)
	gs.VerifiedRules.Bamboo.remove_departed(gs)
	var u: Dictionary={"uid":"%s:pine-%d" % [p.id,gs.next_card_id],"id":"pine-fruit","name":"美味松果","title":"小松丸召唤物","art":Content.unit_def("xiaosongwan").art,"color":"#c09040","baseAttack":4,"baseMaxHp":4,"attack":4,"maxHp":4,"hp":4,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"融合。4/4。离开战斗区移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"pineSummon":true,"summonerUid":p.units[src].uid}
	gs.next_card_id+=1; p.units.append(u)
	gs.VerifiedRules.Enma.remove_departed(gs)
	gs.VerifiedRules.Weaver.remove_departed(gs)
	gs.VerifiedRules.Vine.remove_departed(gs)
	gs.VerifiedRules.WindRaccoon.remove_departed(gs)
	gs.VerifiedRules.House.remove_departed(gs)
	gs.VerifiedRules.Doll.remove_departed(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	var idx: int=p.units.size()-1
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":p.units[src].uid,"summonKind":"pine-fruit"})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
	return idx
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]; var marks: Array=[]
	if source(u):
		marks.append("倒计时归零 %d次" % int(u.get("pineCountdownZeros",0)))
		if int(u.hp)<=0: marks.append("运势成功：气绝倒计时-1")
		if not u.get("pineKeywords",[]).is_empty(): marks.append("松果关键词："+"、".join(u.pineKeywords.map(func(k):return Glossary.label(k))))
	if u.get("pineSummon",false): marks.append("融合松果 · 离场触发秋收冬藏")
	return marks
static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("pineRules",false): return null
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	match str(card.get("effect","")):
		"pine-carry": return 45 if int(u.hp)>0 else 80
		"pine-hit":
			var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,target_id)
			return -100 if target.is_empty() else 50+(30 if int(target.hp)<=3 else 0)
		"pine-combat":
			var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,target_id)
			return -100 if target.is_empty() else 50+(30 if int(target.hp)<=int(u.attack)+2 else 0)
		"pine-awaken": return 50+int(card.value.attack)*4
		"form": return -25 if u.get("form",{}).get("cardId")==card.id else 56+int(card.value.hp)
	return 45
