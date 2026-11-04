class_name RebirthRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("rebirthRole", ""))

static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("baseRulesSuppressed",false)

static func can_revive(u: Dictionary) -> bool:
	return not u.get("catCannotRevive",false) and not u.get("samuraiCannotRevive",false) and not u.get("removed",false)

static func swift(u: Dictionary) -> bool:
	return active(u) and bool(u.get("catPermanentSwift",false))

static func attach_life(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	u.catLives=int(u.get("catLives",0))+1
	gs.VerifiedRules.event(gs,"cat-life-attached",{"player":owner,"uid":u.uid,"count":u.catLives})
	if int(u.catLives)<5: return
	u.catCannotRevive=true
	if int(u.hp)>0: gs._knockout_unit(u)
	for zone in ["hand","deck"]:
		var retained: Array=[]
		for inst in gs.player(owner)[zone]:
			var card := Content.card_def(str(inst.definitionId))
			if card.get("unitId")==u.id and not card.get("catSurvival",false):
				gs.VerifiedRules.event(gs,"cat-card-removed",{"player":owner,"uid":u.uid,"zone":zone,"instanceId":inst.instanceId,"card":card})
			else: retained.append(inst)
		gs.player(owner)[zone]=retained
	gs.VerifiedRules.BondDream.refresh(gs)
	gs.VerifiedRules.event(gs,"cat-permanent-knockout",{"player":owner,"uid":u.uid})

static func knockout_snapshot(gs, owner: int, u: Dictionary, was_front: bool) -> Array:
	var frames: Array=[]
	if owner<0: return frames
	u.rebirthDeaths=int(u.get("rebirthDeaths",0))+1
	var src: int=gs._unit_index_by_uid(owner,str(u.uid))
	if int(u.level)>0 and not u.get("baseRulesSuppressed",false):
		if role(u)=="cat" and can_revive(u): frames.append({"kind":"rebirth-cat","playerIndex":owner,"sourceIndex":src,"awakened":bool(u.awakened)})
		if u.get("formRules",{}).get("skeletonRebirth",false): frames.append({"kind":"rebirth-skeleton","playerIndex":owner,"sourceIndex":src})
	if was_front:
		for i in gs.player(owner).units.size():
			var cat: Dictionary=gs.player(owner).units[i]
			if i!=src and active(cat) and cat.get("formRules",{}).get("catCar",false): frames.append({"kind":"rebirth-car","playerIndex":owner,"sourceIndex":i,"targetUid":u.uid})
	return frames

static func revived(gs, owner: int, src: int) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u): return
	if swift(u): u.swift=true
	if role(u)!="skeleton": return
	if u.awakened:
		u.permanentAttack=int(u.get("permanentAttack",0))+1
		gs.VerifiedRules.Glutton.record_permanent(u,0,1)
		gs._grow_unit(u,0,1)
		gs._recalc(u)
	gs.VerifiedRules.Movement.move_to(gs,owner,src,1-int(u.front))
	gs.VerifiedRules.event(gs,"skeleton-revived",{"player":owner,"uid":u.uid,"awakened":bool(u.awakened)})

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("rebirthRules",false): return card
	var out := card.duplicate(true)
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	var lives := int(u.get("catLives",0))
	if card.get("catClaw",false) and lives>=2: out.value=3; out.effects[0].value=3
	if card.get("catBell",false): out.value.attack=3+lives; out.effects[0].value=out.value.duplicate(true)
	if card.get("skeletonInstant",false) and int(u.front)==1: out.keywords.append("instant")
	if card.get("skeletonFog",false): out.combatOption.skeletonFog=int(u.front)==1
	if card.get("type")=="form": out.currentCardStats="当前%d/%d" % [int(out.value.attack),int(out.value.hp)]
	elif card.get("type")=="combat": out.currentCardStats=("首击+%d · 续击+0" % int(out.value)) if card.get("catDance",false) else ("+%d攻/+%d甲" % [int(out.value),int(out.combatOption.get("shield",0))])
	if role(u)=="cat": out.text+="\n当前九命%d/5%s。" % [lives,"，不能复活" if not can_revive(u) else ""]
	return out

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("catDance",false): return null
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("rebirthRules",false): return true
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.get("catSurvival",false): return bool(u.get("catCannotRevive",false))
	return not card.get("skeletonDeadOnly",false) or int(u.hp)<=0

static func end_turn(gs, owner: int) -> void:
	for side in gs.players.size():
		for u in gs.player(side).units.duplicate():
			if not active(u): continue
			if u.get("formRules",{}).get("catExtend",false):
				u.catLives=maxi(0,int(u.get("catLives",0))-1)
				gs.VerifiedRules.event(gs,"cat-life-removed",{"player":side,"uid":u.uid,"count":u.catLives})
			if side!=owner and u.get("formRules",{}).get("skeletonEndDeath",false): gs._knockout_unit(u)

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
	if not card.get("combatOption",{}).get("catRevenge",false): return false
	for frame in gs.resolution_stack:
		if frame.get("kind")!="combat-hit" or int(frame.get("combatId",-1))!=combat_id: continue
		frame.defenderBonus=int(frame.get("defenderBonus",0))+int(card.value)
		frame.options.catDefenderRevenge={"playerIndex":owner,"sourceIndex":src,"deaths":int(gs.player(owner).units[src].get("rebirthDeaths",0))}
		return true
	return true

static func combat_started(gs, owner: int, src: int, options: Dictionary) -> void:
	if options.get("catRevenge",false): options.catRevengeDeaths=int(gs.player(owner).units[src].get("rebirthDeaths",0))

static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	var guards: Array=[]
	if options.get("catRevenge",false): guards.append({"playerIndex":owner,"sourceIndex":src,"deaths":int(options.get("catRevengeDeaths",0))})
	if options.has("catDefenderRevenge"): guards.append(options.catDefenderRevenge)
	for guard in guards:
		var u: Dictionary=gs.player(int(guard.playerIndex)).units[int(guard.sourceIndex)]
		if int(u.get("rebirthDeaths",0))>int(guard.deaths) and can_revive(u): gs.resolution_stack.append({"kind":"rebirth-revenge","playerIndex":guard.playerIndex,"sourceIndex":guard.sourceIndex})
	if options.get("skeletonFog",false): queue_enemy_hits(gs,owner,src,1,true)
	if options.get("basicAttack",false): queue_incarnation(gs,owner,false)

static func queue_enemy_hits(gs, owner: int, src: int, amount: int, avatar: bool, feast: bool = false) -> void:
	var frames: Array=[]
	for u in gs.player(1-owner).units:
		if int(u.hp)>0 and (avatar or gs.VerifiedRules.OwlInsect.shikigami(u)): frames.append({"kind":"rebirth-enemy-hit","playerIndex":owner,"sourceIndex":src,"targetUid":u.uid,"amount":amount,"feast":feast,"context":gs._card_effect_context.duplicate(true)})
	if avatar: frames.append({"kind":"rebirth-enemy-hit","playerIndex":owner,"sourceIndex":src,"targetUid":"avatar-%d" % (1-owner),"amount":amount})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func incarnation_pool(gs, owner: int, src: int) -> Array:
	return gs.VerifiedRules.Incarnation.pool(gs,owner,src)

static func queue_incarnation(gs, owner: int, turn_start: bool) -> void:
	gs.VerifiedRules.Incarnation.queue(gs,owner,turn_start)

static func incarnation(gs, owner: int, turn_start: bool) -> void:
	gs.VerifiedRules.Incarnation.trigger_now(gs,owner,turn_start)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target) -> bool:
	var u: Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"cat-survival":
			u.catCannotRevive=false; u.catLives=0
			u.permanentAttack=int(u.get("permanentAttack",0))+1; gs.VerifiedRules.Glutton.record_permanent(u,0,1); gs._grow_unit(u,0,1); gs._recalc(u)
			u.catPermanentSwift=true
			gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
			attach_life(gs,owner,src); attach_life(gs,owner,src)
			gs.VerifiedRules.Yaodao.resolve_action(gs,owner,src,{"generatedCards":card.generatedCards},{"action":"yaodao-killing-intent","value":2},{})
		"cat-dance":
			for step in range(1,-1,-1): gs.resolution_stack.append({"kind":"rebirth-cat-attack","playerIndex":owner,"sourceIndex":src,"bonus":int(effect.value) if step==0 else 0,"targetUid":target,"step":step,"card":card})
		"skeleton-question":
			var idx: int=gs._unit_index_by_uid(1-owner,str(target))
			gs.resolution_stack.append({"kind":"rebirth-reduce","playerIndex":owner,"sourceIndex":src})
			if idx>=0: gs._damage_unit(1-owner,idx,3,owner,src)
			elif str(target)=="avatar-%d" % (1-owner): gs._damage_avatar(1-owner,3,owner,src)
		"skeleton-loyalty":
			if gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false): gs._grant_unit_armor(u,4)
		"skeleton-feast": queue_enemy_hits(gs,owner,src,2,false,true)
		"skeleton-flower":
			gs._grant_unit_armor(u,3)
			gs.resolution_stack.append({"kind":"rebirth-flower","playerIndex":owner,"sourceIndex":src,"step":0,"deaths":int(u.get("rebirthDeaths",0)),"card":card})
		_: return false
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind := str(f.get("kind",""))
	if not kind.begins_with("rebirth-"): return false
	var owner := int(f.playerIndex); var src := int(f.get("sourceIndex",-1))
	var u: Dictionary={} if src<0 else gs.player(owner).units[src]
	var context: Dictionary=gs._card_effect_context
	# Spell packets retain their casting source; lifecycle and attacks are abilities.
	gs._card_effect_context=f.get("context",{}) if kind=="rebirth-enemy-hit" else {}
	match kind:
		"rebirth-cat":
			attach_life(gs,owner,src)
			if gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false) and f.awakened: gs.resolution_stack.append({"kind":"rebirth-auto-attack","playerIndex":owner,"sourceIndex":src})
		"rebirth-skeleton": gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
		"rebirth-car":
			if active(u) and u.get("formRules",{}).get("catCar",false):
				gs.VerifiedRules.Movement.move_to(gs,owner,src,1-int(u.front))
				var target: Dictionary=gs._unit_by_uid(gs.player(owner).units,str(f.targetUid))
				if not target.is_empty(): gs.VerifiedRules.Peach.revive(gs,owner,src,target,false,false)
				attach_life(gs,owner,src)
		"rebirth-auto-attack", "rebirth-revenge":
			if kind=="rebirth-revenge" and int(u.hp)<=0: gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
			if active(u) and int(u.frozen)==0: gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"immuneCombat":kind=="rebirth-revenge"})
		"rebirth-cat-attack":
			if active(u) and int(u.frozen)==0:
				var target_id=f.targetUid; var idx: int=gs._unit_index_by_uid(1-owner,str(target_id))
				if idx>=0 and int(gs.player(1-owner).units[idx].hp)<=0:
					gs._card_effect_context=context
					return true
				gs._resolve_combat(owner,src,int(f.bonus),false,false,false,false,target_id,false,{"pursuit":target_id!=null,"combatCard":f.card})
		"rebirth-reduce": gs.VerifiedRules.reduce_countdown(gs,owner,src,1)
		"rebirth-enemy-hit":
			var idx: int=gs._unit_index_by_uid(1-owner,str(f.targetUid))
			if idx>=0 and int(gs.player(1-owner).units[idx].hp)>0:
				var result: Dictionary=gs._damage_unit(1-owner,idx,int(f.amount),owner,src)
				if f.get("feast",false) and result.get("knocked",false): gs.VerifiedRules.reduce_countdown(gs,owner,src,1)
			elif str(f.targetUid)=="avatar-%d" % (1-owner): gs._damage_avatar(1-owner,int(f.amount),owner,src)
		"rebirth-flower":
			if active(u) and int(u.frozen)==0 and int(u.get("rebirthDeaths",0))==int(f.deaths):
				var step := int(f.step); var target_id=null
				if step<2: var next:=f.duplicate(true); next.step=step+1; gs.resolution_stack.append(next)
				if step==0:
					var front: Dictionary=gs.front_unit(1-owner)
					if not front.is_empty(): target_id=front.uid
				elif step==1:
					var pool: Array=gs.player(1-owner).units.filter(func(e):return int(e.hp)>0 and int(e.front)==0 and gs.VerifiedRules.OwlInsect.shikigami(e))
					if not pool.is_empty(): target_id=pool[int(floor(gs.randf01()*pool.size()))].uid
				else: target_id="avatar-%d" % (1-owner)
				if target_id!=null: gs._resolve_combat(owner,src,3,false,false,false,false,target_id,false,{"directAvatar":step==2,"pursuit":step<2,"combatCard":f.card})
		"rebirth-incarnation": incarnation(gs,owner,bool(f.turnStart))
	gs._card_effect_context=context
	return true

static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("rebirthRules",false): return null
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.get("catSurvival",false): return 110 if u.get("catCannotRevive",false) else -100
	if card.get("skeletonDeadOnly",false): return 85 if int(u.hp)<=0 else -100
	if card.get("type")=="awakening": return 70 if not u.awakened else -100
	if card.get("type")=="form": return 45 if u.get("form",{}).get("cardId")!=card.id else -20
	return 55
