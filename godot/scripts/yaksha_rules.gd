class_name YakshaRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("yakshaRules",false)

static func active(u: Dictionary) -> bool:
	return source(u) and int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false)

static func night_triggered(gs, owner: int, effect_depth: int = -1) -> void:
	# Official reveal: after every 入夜X effect, both success and +1 branches.
	# A bare resource acquisition is not this event. Check life/quota on resolve.
	var frame: Dictionary={"kind":"yaksha-night-strength","playerIndex":owner}
	if effect_depth>=0: gs.resolution_stack.insert(effect_depth,frame)
	else: gs.resolution_stack.append(frame)

static func knockout_snapshot(u: Dictionary) -> bool:
	return source(u) and not u.get("removed",false)

static func knocked_out(gs, victim: int, u: Dictionary, eligible: bool = true) -> void:
	if victim<0 or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	var frames: Array=[]
	for realm in gs.player(1-victim).realms:
		if realm.get("nativeRealm")=="yaksha-sea" and int(realm.hp)>0:
			frames.append({"kind":"yaksha-sea-death","playerIndex":1-victim,"targetUid":u.uid,"realmUid":realm.uid})
	if eligible and source(u) and gs.VerifiedRules.Maple.night_value(gs,victim)==10 and gs.VerifiedRules.Rebirth.can_revive(u):
		frames.append({"kind":"yaksha-auto-form","playerIndex":victim,"sourceIndex":gs._unit_index_by_uid(victim,str(u.uid))})
	frames.reverse(); gs.resolution_stack.append_array(frames)

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if not active(u): return
	var kind:=str(card.get("formRules",{}).get("yakshaEntry",""))
	match kind:
		"pursuit":
			if gs.VerifiedRules.Maple.nightfall(gs,owner,3):
				var traits: Array=u.formRules.get("combatKeywords",[])
				if not traits.has("pursuit"): traits.append("pursuit")
				u.formRules.combatKeywords=traits
		"barrier":
			if gs.VerifiedRules.Maple.nightfall(gs,owner,7):
				u.barrier=true
				gs.VerifiedRules.event(gs,"barrier-gained",{"player":owner,"uid":u.uid})
		"front":
			if gs.VerifiedRules.Maple.nightfall(gs,owner,10): gs.VerifiedRules.Movement.move_to(gs,owner,src,1)

static func combat_strike(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	var effect:=str(options.get("yakshaKillEffect",""))
	if effect.is_empty() or not result.get("knocked",false) or owner==victim: return
	# Redirected combat carries the real struck identity, never credit the old target.
	victim=int(result.get("redirectedPlayer",victim))
	if result.has("redirectedIndex"): idx=int(result.redirectedIndex)
	if idx<0 or victim==owner or idx>=gs.player(victim).units.size(): return
	var target: Dictionary=gs.player(victim).units[idx]
	if not gs.VerifiedRules.OwlInsect.shikigami(target): return
	gs.resolution_stack.append({"kind":"yaksha-kill-effect","playerIndex":owner,"sourceIndex":src,"effect":effect,"targetUid":target.uid})

static func auto_form(gs, owner: int, src: int) -> void:
	if src<0: return
	var u: Dictionary=gs.player(owner).units[src]
	if int(u.hp)>0 or not source(u) or gs.VerifiedRules.Maple.night_value(gs,owner)!=10 or not gs.VerifiedRules.Rebirth.can_revive(u): return
	var p: Dictionary=gs.player(owner)
	for zone in ["deck","hand"]:
		for i in p[zone].size():
			var inst: Dictionary=p[zone][i]
			var card:=Content.card_def(str(inst.definitionId))
			if not card.get("yakshaResurrection",false): continue
			p[zone].remove_at(i)
			gs.VerifiedRules.BondDream.fetched(gs,inst)
			gs.VerifiedRules.event(gs,"yaksha-auto-form",{"player":owner,"uid":u.uid,"zone":zone,"instanceId":inst.instanceId,"card":card})
			gs._push_card_frames(owner,str(card.id),null,card,src,0,true)
			return

static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind:=str(f.get("kind",""))
	if not kind.begins_with("yaksha-"): return false
	var owner:=int(f.playerIndex)
	var context: Dictionary=gs._card_effect_context
	gs._card_effect_context={}
	match kind:
		"yaksha-night-strength":
			for u in gs.player(owner).units:
				if not active(u) or (not u.awakened and int(u.get("yakshaStrengthTurn",-1))==gs.turn_counter): continue
				u.yakshaStrengthTurn=gs.turn_counter
				gs._grow_unit(u,1,0)
				gs.VerifiedRules.event(gs,"yaksha-night-strength",{"player":owner,"uid":u.uid,"awakened":bool(u.awakened)})
		"yaksha-sea-death":
			var victim:=1-owner
			var idx: int=gs._unit_index_by_uid(victim,str(f.targetUid))
			if idx>=0 and gs.VerifiedRules.Maple.nightfall(gs,owner,5):
				var u: Dictionary=gs.player(victim).units[idx]
				if int(u.hp)<=0 and int(u.knockout)>0:
					gs.VerifiedRules.Countdown.change(gs,victim,idx,1,owner)
					gs.VerifiedRules.event(gs,"yaksha-sea-extended",{"player":owner,"target":u.uid,"remaining":int(u.knockout),"realmUid":f.realmUid})
		"yaksha-auto-form": auto_form(gs,owner,int(f.sourceIndex))
		"yaksha-kill-effect":
			var src:=int(f.sourceIndex); var u: Dictionary=gs.player(owner).units[src]
			var effect:=str(f.effect)
			var threshold:=3 if effect=="heal" else (7 if effect=="draw" else 10)
			if gs.VerifiedRules.Maple.nightfall(gs,owner,threshold):
				match effect:
					"heal": gs._heal_unit(u,int(u.maxHp))
					"draw": gs._draw(owner,2)
					"fire": gs._set_fire(owner,int(gs.player(owner).energy)+1)
				gs.VerifiedRules.event(gs,"yaksha-kill-reward",{"player":owner,"uid":u.uid,"effect":effect,"target":f.targetUid})
	gs._card_effect_context=context
	return true

static func describe_card(gs, owner: int, _entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("yakshaCard",false): return card
	var out:=card.duplicate(true)
	if card.type=="combat": out.currentCardStats="+%d攻/+%d甲 · 入夜%d/10" % [int(card.value),int(card.get("combatOption",{}).get("shield",0)),gs.VerifiedRules.Maple.night_value(gs,owner)]
	elif card.type=="form": out.currentCardStats="当前%d/%d · 入夜%d/10" % [int(card.value.attack),int(card.value.hp),gs.VerifiedRules.Maple.night_value(gs,owner)]
	return out

static func targets(_gs, _owner: int, _card: Dictionary):
	return null

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("yakshaCard",false): return true
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	var u: Dictionary=gs.player(owner).units[src]
	if card.type=="awakening" and u.awakened: return false
	return not card.get("yakshaResurrection",false) or int(u.hp)>0 or gs.VerifiedRules.Rebirth.can_revive(u)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, _target_id = null) -> bool:
	var u: Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"yaksha-awaken":
			if u.awakened: return true
			u.awakened=true; u.passive_hooks=[]
			gs._grow_unit(u,int(effect.value.attack),int(effect.value.hp))
			gs.VerifiedRules.event(gs,"yaksha-awakened",{"player":owner,"uid":u.uid})
		"yaksha-revive-form":
			if int(u.hp)<=0 and not gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false): return true
			gs._apply_form(owner,src,card,card.value)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, _target_id):
	if not card.get("yakshaCard",false): return null
	var src: int=gs._source_index(owner,card)
	if src<0: return -100
	var u: Dictionary=gs.player(owner).units[src]
	if card.type=="awakening": return -100 if u.awakened else 65
	if card.get("yakshaResurrection",false): return 95 if int(u.hp)<=0 else 45
	if card.type=="form": return 32 if u.get("form",{}).get("cardId")==card.id else 55
	if card.type=="realm": return 48 if gs.player(owner).realms.size()<3 else 20
	var enemy: Dictionary=gs.front_unit(1-owner)
	var power:=int(u.attack)+int(card.value)
	if enemy.is_empty(): return 50+power*2+(500 if power>=int(gs.player(1-owner).avatarHp) else 0)
	var kill: bool=power>=int(enemy.hp)+int(enemy.shield) and not enemy.get("barrier",false) and not enemy.get("unyielding",false)
	return 42+power+(30 if kill else 0)+(12 if kill and gs.VerifiedRules.Maple.night_value(gs,owner)>=int(card.get("yakshaThreshold",0)) else 0)
