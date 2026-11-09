class_name IncarnationRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func config(u: Dictionary, gs = null, owner: int = -1) -> Dictionary:
	if int(u.get("level",0))<1 or u.get("baseRulesSuppressed",false) or (int(u.get("frozen",0))>0 and (gs==null or gs.VerifiedRules.Stun.blocks(gs,owner,u))): return {}
	var sg=preload("res://scripts/serpent_ghost_rules.gd").incarnation_config(u)
	if sg!=null:return sg
	var def := Content.runtime_unit_def(u)
	if def.get("rebirthRole")=="skeleton":
		return {"start":20,"action":8,"limit":1,"mode":"skeleton"} if u.awakened and int(u.hp)<=0 else {}
	if int(u.hp)<=0: return {}
	if u.get("starsFrogIncarnation", false): return {"start":20,"action":8,"limit":2,"mode":"stars-frog-army"}
	if def.get("goldfishRules",false) and u.get("goldfishAttached",false): return {"start":20,"action":8,"limit":1,"mode":"goldfish"}
	if def.get("foxLotusRole")=="lotus":
		return {"start":20 if u.awakened else 25,"action":8 if u.awakened else 25,"limit":1,"mode":"lotus-awake" if u.awakened else "lotus"}
	var form: Dictionary=u.get("formRules",{})
	return form.get("incarnation",{})

static func pool(gs, owner: int, src: int) -> Array:
	var u: Dictionary=gs.player(owner).units[src]
	var cfg := config(u,gs,owner)
	var out: Array=[]
	if cfg.is_empty(): return out
	if cfg.mode=="sg-chaos":return gs.VerifiedRules.SerpentGhost.incarnation_pool(gs,owner,src)
	if cfg.mode=="goldfish": return gs.VerifiedRules.Goldfish.incarnation_pool(gs,owner,src)
	if cfg.mode == "stars-frog-army": return gs.VerifiedRules.CarFrog.incarnation_pool(gs, owner)
	for card in Content.cards_for_unit(str(u.id)):
		if card.get("type") not in ["spell","combat"] or int(card.level)>int(u.level) or card.get("skin",false) or card.get("token",false): continue
		match str(cfg.mode):
			"skeleton":
				if not card.get("allowKnockedSource",false) or not gs.VerifiedRules.Rebirth.can_use(gs,owner,card): continue
			"lotus":
				if not card.get("lotusGrace",false): continue
			"lotus-awake":
				if card.get("type")!="spell": continue
			"fox":
				if card.get("type")!="spell" or int(card.level)!=1: continue
		if card.get("target","auto")!="auto" and gs.valid_targets(owner,card).is_empty(): continue
		out.append(card)
	return out

static func has_source(gs, owner: int) -> bool:
	return gs.player(owner).units.any(func(u):
		var def:=Content.runtime_unit_def(u)
		return u.get("starsFrogIncarnation", false) or gs.VerifiedRules.SerpentGhost.has_incarnation(u) or def.get("rebirthRole")=="skeleton" or def.has("foxLotusRole") or def.get("goldfishRules",false))

static func queue(gs, owner: int, turn_start: bool) -> void:
	if gs.current_player==owner and has_source(gs,owner):
		gs.resolution_stack.append({"kind":"incarnation-check","playerIndex":owner,"turnStart":turn_start,"sourceIndex":0})

static func resolve_frame(gs, f: Dictionary) -> bool:
	if f.get("kind")!="incarnation-check": return false
	var owner := int(f.playerIndex); var src := int(f.sourceIndex)
	if gs.current_player!=owner or gs.winner>=0 or src>=gs.player(owner).units.size(): return true
	# Each generated spell finishes, including choices, before the next source.
	var next:=f.duplicate(true); next.sourceIndex=src+1; gs.resolution_stack.append(next)
	check_source(gs,owner,src,bool(f.turnStart))
	return true

static func trigger_now(gs, owner: int, turn_start: bool) -> void:
	if gs.current_player!=owner or gs.winner>=0: return
	for src in gs.player(owner).units.size(): check_source(gs,owner,src,turn_start)

static func check_source(gs, owner: int, src: int, turn_start: bool) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	var cfg := config(u,gs,owner)
	if cfg.is_empty(): return
	var used := int(u.get("incarnationCount",1)) if int(u.get("incarnationUsedTurn",-1))==gs.turn_counter else 0
	if used>=int(cfg.limit): return
	var cards := pool(gs,owner,src)
	if cards.is_empty(): return
	u.incarnationChance=mini(100,int(u.get("incarnationChance",0))+int(cfg.start if turn_start else cfg.action))
	var roll := int(floor(gs.randf01()*100))
	gs.VerifiedRules.event(gs,"incarnation-roll",{"player":owner,"uid":u.uid,"chance":u.incarnationChance,"roll":roll})
	if roll>=int(u.incarnationChance): return
	u.incarnationChance=0; u.incarnationUsedTurn=gs.turn_counter; u.incarnationCount=used+1
	var card: Dictionary=cards[int(floor(gs.randf01()*cards.size()))].duplicate(true)
	var targets: Array=[null] if card.get("target","auto")=="auto" else gs.valid_targets(owner,card)
	if cfg.mode=="goldfish": targets=gs.VerifiedRules.Goldfish.automatic_targets(gs,owner,card,targets)
	if str(cfg.mode).begins_with("lotus"): targets=gs.VerifiedRules.FoxLotus.automatic_targets(gs,owner,card,targets)
	var target=targets[int(floor(gs.randf01()*targets.size()))]
	gs._push_card_frames(owner,str(card.id),target,card,src,0,true)
	gs.VerifiedRules.event(gs,"incarnation-card",{"player":owner,"uid":u.uid,"card":card,"target":target,"count":used+1})
