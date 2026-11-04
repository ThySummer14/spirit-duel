class_name OnikiriRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const CHARMS := ["onikiri-hige","onikiri-tomo","onikiri-lion"]
const BATTLES := ["c19101","c19105","c19108"]
static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("onikiriRules",false)
static func active(u: Dictionary) -> bool:
	return source(u) and int(u.hp)>0 and int(u.level)>0
static func charms(u: Dictionary) -> Array:
	return u.get("onikiriCharms",[])
static func remove_charms(u: Dictionary) -> void:
	u.erase("onikiriCharms")
static func knocked_out(u: Dictionary) -> void:
	remove_charms(u)
static func power(gs, u: Dictionary) -> int:
	if not active(u) or not u.get("formRules",{}).get("onikiriEnemyPower",false):return 0
	return 3 if not gs.player(gs.current_player).units.has(u) else 0
static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("onikiriRules",false):return card
	var out:=card.duplicate(true);var src: int=gs._source_index(owner,card)
	if src>=0 and gs.player(owner).units[src].awakened and card.get("type")=="combat":
		if not out.keywords.has("instant"):out.keywords.append("instant")
		out.text+="\n觉醒·鬼切：此战斗牌获得瞬发（共享本回合额度）。"
	if card.get("type")=="combat":out.currentCardStats="战斗 +2力量/+1护甲 · 响应时才附加牌面响应效果"
	if card.get("type")=="form":out.currentCardStats="当前%d/%d" % [int(card.value.attack),int(card.value.hp)]
	return out
static func attach(gs, owner: int, src: int, id: String) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or not CHARMS.has(id) or charms(u).has(id):return
	if not u.has("onikiriCharms"):u.onikiriCharms=[]
	u.onikiriCharms.append(id)
	gs._log("%s 结附「%s」。" % [u.name,Content.card_def(id).get("name",id)],gs.TONE_CARD)
	gs.VerifiedRules.event(gs,"onikiri-charm-attached",{"player":owner,"uid":u.uid,"charm":id,"card":Content.card_def(id)})
static func _choice(gs, owner: int, src: int, mode: String, draw_after: bool = false) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	var ids: Array=BATTLES.duplicate() if mode=="battle" else CHARMS.filter(func(id):return not charms(u).has(id))
	if ids.is_empty():
		if draw_after:gs._draw(owner,1)
		return
	gs.pending_choice={"type":"onikiri-"+mode,"playerIndex":owner,"sourceIndex":src,"instanceIds":ids,"drawAfter":draw_after,"heading":"觉醒·鬼切 · 选择战斗牌" if mode=="battle" else "鬼斩 · 选择未结附的灵咒","hint":"将所选鬼切战斗牌的新实例置入手牌。" if mode=="battle" else "只显示尚未结附的鬼斩；确认后继续当前结算。"}
	gs.phase="choice"
static func choice_card(gs, owner: int, id: String):
	if not str(gs.pending_choice.get("type","")).begins_with("onikiri-"):return null
	if not gs.pending_choice.get("instanceIds",[]).has(id):return {}
	return describe_card(gs,owner,{},Content.card_def(id))
static func resolve_choice(gs, owner: int, id: String) -> bool:
	var choice: Dictionary=gs.pending_choice
	if not str(choice.get("type","")).begins_with("onikiri-") or int(choice.get("playerIndex",-1))!=owner or not choice.get("instanceIds",[]).has(id):return false
	var src:=int(choice.sourceIndex)
	if choice.type=="onikiri-battle":
		var p: Dictionary=gs.player(owner);var entry: Dictionary={"instanceId":"%s-onikiri-%d" % [p.id,gs.next_card_id],"definitionId":id}
		gs.next_card_id+=1
		if p.hand.size()<int(gs.rules.maxHandSize):p.hand.append(entry)
		gs.VerifiedRules.event(gs,"onikiri-battle-obtained",{"player":owner,"uid":p.units[src].uid,"card":Content.card_def(id),"instanceId":entry.instanceId})
	else:attach(gs,owner,src,id)
	gs.pending_choice={};gs.phase="main"
	if choice.get("drawAfter",false):gs._draw(owner,1)
	gs._record("resolve_divination_choice",{"instanceId":id,"choice":choice.type,"card":id},owner)
	gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
	var choice: Dictionary=gs.pending_choice
	if not str(choice.get("type","")).begins_with("onikiri-"):return null
	if int(choice.playerIndex)!=owner:return false
	var ids: Array=choice.instanceIds;var selected:=str(ids[0])
	if choice.type=="onikiri-battle":
		if gs.front_index(1-owner)<0 and ids.has("c19108"):selected="c19108"
		elif ids.has("c19101"):selected="c19101"
	else:
		if gs.front_index(1-owner)<0 and ids.has("onikiri-lion"):selected="onikiri-lion"
		elif ids.has("onikiri-hige"):selected="onikiri-hige"
	return resolve_choice(gs,owner,selected)
static func turn_start(gs, owner: int) -> void:
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		if active(gs.player(owner).units[src]):gs.resolution_stack.append({"kind":"onikiri-start-choice","playerIndex":owner,"sourceIndex":src})
static func _ready(gs, owner: int, u: Dictionary, charm: String) -> bool:
	return owner!=gs.current_player and active(u) and charms(u).has(charm) and (int(u.front)==1 or u.get("formRules",{}).get("onikiriRevenge",false)) and not gs.VerifiedRules.Stun.blocks(gs,owner,u)
static func _consume_queue(gs, owner: int, src: int, charm: String, target_id, spell: Dictionary = {}) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	u.onikiriCharms.erase(charm)
	var copies:=2 if u.get("formRules",{}).get("onikiriEcho",false) else 1
	var cut_id: int=gs.next_resolution_id;gs.next_resolution_id+=1
	gs.resolution_stack.append({"kind":"onikiri-cut","playerIndex":owner,"sourceIndex":src,"cutId":cut_id,"charm":charm,"targetId":target_id,"copies":copies,"spell":spell.duplicate(true)})
	gs.VerifiedRules.event(gs,"onikiri-charm-triggered",{"player":owner,"uid":u.uid,"charm":charm,"target":target_id,"copies":copies,"cutId":cut_id})
static func enter_response(gs, owner: int, trigger: String, target_id, continuation: Dictionary) -> bool:
	if trigger!="enemy-entered-front" or continuation.get("onikiriEntryChecked",false) or owner==gs.current_player:return false
	var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
	if target.is_empty() or not gs.VerifiedRules.OwlInsect.shikigami(target):return false
	var pool: Array=[]
	for src in gs.player(owner).units.size():
		if _ready(gs,owner,gs.player(owner).units[src],"onikiri-hige"):pool.append(src)
	if pool.is_empty():return false
	var next:=continuation.duplicate(true);next.onikiriEntryChecked=true
	gs.resolution_stack.append({"kind":"onikiri-entry-resume","playerIndex":owner,"targetId":target_id,"continuation":next})
	pool.reverse()
	for src in pool:_consume_queue(gs,owner,int(src),"onikiri-hige",target_id)
	return true
static func enemy_spell(gs, frame: Dictionary, card: Dictionary) -> bool:
	if frame.get("automatic",false) or not Content.is_spell(card):return false
	var owner:=1-int(frame.playerIndex)
	if owner==gs.current_player:return false
	var pool: Array=[]
	for src in gs.player(owner).units.size():
		if _ready(gs,owner,gs.player(owner).units[src],"onikiri-tomo"):pool.append(src)
	if pool.is_empty():return false
	gs.resolution_stack.append({"kind":"onikiri-spell-resume","playerIndex":owner,"frame":frame.duplicate(true),"card":card.duplicate(true)})
	pool.reverse()
	for src in pool:_consume_queue(gs,owner,int(src),"onikiri-tomo",gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)].uid,frame)
	return true
static func end_turn(gs, ending_owner: int) -> void:
	var owner:=1-ending_owner
	gs.resolution_stack.append({"kind":"onikiri-end-cleanup","playerIndex":owner})
	if gs.front_index(ending_owner)>=0:return
	for src in range(gs.player(owner).units.size()-1,-1,-1):
		if _ready(gs,owner,gs.player(owner).units[src],"onikiri-lion"):_consume_queue(gs,owner,src,"onikiri-lion","avatar-%d"%ending_owner)
static func _response_allowed(gs, owner: int, u: Dictionary, card: Dictionary) -> bool:
	if not active(u) or int(u.level)<int(card.level) or gs.VerifiedRules.Stun.blocks(gs,owner,u,card) or gs.VerifiedRules.UpgradeBlessing.card_blocked(gs,u,card):return false
	# A ghost-cut response uses the same source and cross-role card restrictions
	# as a normal hand response, including Star Bear's enraged hand lock.
	for rules in [gs.VerifiedRules.Onikiri,gs.VerifiedRules.Otakemaru,gs.VerifiedRules.House,gs.VerifiedRules.Goldfish,gs.VerifiedRules.Vine,gs.VerifiedRules.WindRaccoon,gs.VerifiedRules.Puppet,gs.VerifiedRules.Enma,gs.VerifiedRules.Weaver,gs.VerifiedRules.Sparrow,gs.VerifiedRules.Headless,gs.VerifiedRules.Yaksha,gs.VerifiedRules.StarBear,gs.VerifiedRules.Rebirth,gs.VerifiedRules.DogDemon,gs.VerifiedRules.Panguan]:
		if not rules.can_use(gs,owner,card):return false
	return not gs.VerifiedRules.Bingyong.replacement_blocked(gs,owner,u)
static func _response(gs, cut: Dictionary, launch: Dictionary) -> bool:
	var owner:=int(cut.playerIndex);var src:=int(cut.sourceIndex);var p: Dictionary=gs.player(owner);var u: Dictionary=p.units[src]
	var id: String={"onikiri-hige":"c19101","onikiri-tomo":"c19105","onikiri-lion":"c19108"}[cut.charm]
	for idx in p.hand.size():
		if p.hand[idx].definitionId!=id:continue
		var card: Dictionary=gs.hand_card_def(owner,idx)
		if not _response_allowed(gs,owner,u,card):continue
		var payment: Dictionary=gs.card_payment(owner,card)
		if int(p.energy)<int(payment.cost):continue
		gs._set_fire(owner,int(p.energy)-int(payment.cost),true)
		gs.VerifiedRules.Moon.consume_card(gs,card)
		if payment.usesInstant:gs.kw_usage(owner,"instant").used=true
		p.hand.remove_at(idx);p.cardsPlayedThisTurn=int(p.cardsPlayedThisTurn)+1
		card=card.duplicate(true);card.onikiriCutId=int(cut.cutId)
		gs._push_card_frames(owner,id,null,card,src,gs.MAX_RESPONSE_DEPTH,false)
		gs._log("%s 响应，自动使用「%s」。" % [u.name,card.name],gs.TONE_CARD)
		gs.VerifiedRules.event(gs,"response-card",{"player":owner,"uid":u.uid,"card":card,"target":cut.targetId,"trigger":cut.charm,"payment":payment})
		gs.VerifiedRules.event(gs,"onikiri-hand-response",{"player":owner,"uid":u.uid,"card":card,"cost":int(payment.cost),"cutId":cut.cutId})
		return true
	return false
static func _attack(gs, f: Dictionary) -> void:
	var owner:=int(f.playerIndex);var src:=int(f.sourceIndex);var u: Dictionary=gs.player(owner).units[src]
	if not active(u) or gs.VerifiedRules.Stun.blocks(gs,owner,u):return
	var target_id=f.targetId
	if not str(target_id).begins_with("avatar-"):
		var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		if target.is_empty() or int(target.hp)<=0:return
	var options: Dictionary={"onikiriCutId":int(f.get("cutId",-1)),"onikiriCounterRid":int(f.get("counterRid",-1)),"onikiriCounterUid":str(f.get("counterUid","")),"pursuit":not str(target_id).begins_with("avatar-"),"directAvatar":str(target_id).begins_with("avatar-"),"crabImmuneAll":bool(f.get("immune",false)),"immuneCombat":bool(f.get("immune",false)),"lethal":bool(f.get("lethal",false))}
	if f.has("card"):options.combatCard=f.card.duplicate(true)
	gs._grant_unit_armor(u,int(f.get("armor",0)))
	gs.VerifiedRules.event(gs,"onikiri-extra-attack",{"player":owner,"uid":u.uid,"target":target_id,"bonus":int(f.bonus),"immune":options.crabImmuneAll,"cutId":int(f.get("cutId",-1))})
	gs._resolve_combat(owner,src,int(f.bonus),false,false,false,false,target_id,false,options)
static func combat_finished(gs, owner: int, src: int, options: Dictionary, kills: int) -> void:
	var rid:=int(options.get("onikiriCounterRid",-1))
	if rid<0 or kills<=0:return
	var caster: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(options.get("onikiriCounterUid","")))
	if caster.is_empty() or int(caster.hp)>0:return
	var removed: Array=gs.resolution_stack.filter(func(frame):return int(frame.get("resolutionId",-1))==rid)
	if removed.is_empty():return
	var original: Dictionary=removed[0]
	var card: Dictionary=original.get("cardOverride",Content.card_def(str(original.get("definitionId",""))))
	gs.resolution_stack=gs.resolution_stack.filter(func(frame):return int(frame.get("resolutionId",-1))!=rid)
	gs._log("鬼刃·罗城门击杀%s，反制整张「%s」。" % [caster.name,card.get("name","")],gs.TONE_CARD)
	gs.VerifiedRules.event(gs,"card-nullified",{"player":1-owner,"uid":caster.uid,"card":card,"resolutionId":rid,"reason":"onikiri-rocheng"})
	gs.VerifiedRules.event(gs,"onikiri-spell-countered",{"player":owner,"uid":gs.player(owner).units[src].uid,"target":caster.uid,"resolutionId":rid})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, _target_id) -> bool:
	match str(effect.get("action","")):
		"onikiri-attach":attach(gs,owner,src,str(effect.value))
		"onikiri-flash":
			gs.VerifiedRules.Movement.move_to(gs,owner,src,1)
			gs.resolution_stack.append({"kind":"onikiri-flash-choice","playerIndex":owner,"sourceIndex":src})
		"onikiri-awaken":
			gs._awaken(owner,src,card,{"attack":1,"hp":1});_choice(gs,owner,src,"battle")
		"onikiri-combat":
			if card.has("onikiriCutId"):
				for frame in gs.resolution_stack:
					if frame.get("kind")=="onikiri-cut-launch" and int(frame.cutId)==int(card.onikiriCutId):frame.boosted=true;frame.responseCard=card.duplicate(true)
			else:
				var options: Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
				gs._grant_unit_armor(gs.player(owner).units[src],1)
				gs._resolve_combat(owner,src,2,false,false,false,false,null,false,options)
		_:return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var owner:=int(f.get("playerIndex",0));var src:=int(f.get("sourceIndex",-1));var kind:=str(f.get("kind",""))
	match kind:
		"onikiri-start-choice":
			if active(gs.player(owner).units[src]):_choice(gs,owner,src,"charm")
		"onikiri-flash-choice":
			if active(gs.player(owner).units[src]):_choice(gs,owner,src,"charm",true)
		"onikiri-entry-resume":
			if not gs.VerifiedRules.automatic_response(gs,owner,"enemy-entered-front",f.targetId,f.continuation):gs.resolution_stack.append(f.continuation)
		"onikiri-spell-resume":
			var original: Dictionary=f.frame;var rid:=int(original.resolutionId)
			if not gs.resolution_stack.any(func(frame):return int(frame.get("resolutionId",-1))==rid):return true
			var check: Dictionary=original.duplicate(true);check.kind="card-counter-check"
			if gs.VerifiedRules.PipeFox.single_target(gs,owner,original,f.card) and gs.VerifiedRules.automatic_response(gs,owner,"enemy-single-character",original.targetId,check):return true
			gs.VerifiedRules.automatic_response(gs,owner,"opponent-card-used",null,check)
		"onikiri-end-cleanup":
			for u in gs.player(owner).units:
				if source(u) and not u.awakened:remove_charms(u)
		"onikiri-cut":
			var launch:=f.duplicate(true);launch.kind="onikiri-cut-launch";launch.boosted=false
			gs.resolution_stack.append(launch);_response(gs,f,launch)
		"onikiri-cut-launch":
			var card: Dictionary=f.get("responseCard",{})
			# Copies of the response card are free automatic card uses, not a
			# combo flag or an invented multiplier on the first hit.
			if f.boosted and f.charm=="onikiri-lion":
				for copy in 2:gs.resolution_stack.append({"kind":"onikiri-card-copy","playerIndex":owner,"sourceIndex":src,"card":card.duplicate(true)})
			for n in range(int(f.copies)-1,-1,-1):
				var attack:=f.duplicate(true);attack.kind="onikiri-attack";attack.bonus=2 if f.charm=="onikiri-lion" else 0
				attack.immune=f.charm!="onikiri-lion";attack.lethal=false;attack.armor=0
				if n==0 and f.boosted:
					attack.bonus+=2;attack.armor=1;attack.card=card
					attack.lethal=f.charm=="onikiri-hige"
					if f.charm=="onikiri-tomo":attack.counterRid=int(f.spell.get("resolutionId",-1));attack.counterUid=f.targetId
				gs.resolution_stack.append(attack)
		"onikiri-attack":_attack(gs,f)
		"onikiri-card-copy":
			var card: Dictionary=f.card.duplicate(true);card.erase("onikiriCutId");card.onikiriCopied=true
			gs._push_card_frames(owner,str(card.id),null,card,src,0,true)
			gs.VerifiedRules.event(gs,"onikiri-response-copied",{"player":owner,"uid":gs.player(owner).units[src].uid,"card":card})
		_:return false
	return true
static func targets(_gs, _owner: int, _card: Dictionary):return null
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("onikiriRules",false):return true
	var src: int=gs._source_index(owner,card)
	return src>=0 and not (card.get("type")=="awakening" and gs.player(owner).units[src].awakened)
static func score_card(gs, owner: int, card: Dictionary, _target_id):
	if not card.get("onikiriRules",false):return null
	var src: int=gs._source_index(owner,card);var u: Dictionary=gs.player(owner).units[src]
	if card.get("type")=="awakening":return 85
	if card.get("type")=="form":return 70 if card.id!=u.get("form",{}).get("cardId","") else -30
	if card.id=="c19102":return 65 if charms(u).size()<3 else 20
	if card.id=="c19108":return 55
	return 40
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]
	if not source(u):return []
	var out: Array=[]
	for id in charms(u):out.append(str(Content.card_def(id).name)+"："+str(Content.card_def(id).text))
	out.append("觉醒：未触发的鬼斩在敌回合结束保留 · 战斗牌瞬发" if u.awakened else "敌方回合结束时移除未触发鬼斩")
	return out
