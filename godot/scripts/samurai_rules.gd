class_name SamuraiRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("samuraiGhostRules",false)

static func ghost(u: Dictionary) -> bool:
	return source(u) and bool(u.get("samuraiGhost",false)) and int(u.hp)<=0 and int(u.level)>0 and not u.get("removed",false)

static func available(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 or ghost(u) or u.has("waveIbarakiGhost")

static func swift(u: Dictionary) -> bool:
	return source(u) and available(u) and int(u.level)>0 and bool(u.get("samuraiCannotRevive",false))

static func power(u: Dictionary) -> int:
	if u.has("waveIbarakiGhost"): return int(u.get("waveIbarakiAttack", 0))
	return maxi(0,int(u.attack)-int(u.baseAttack)+int(Content.runtime_unit_def(u).get("ghostBaseAttack",1))+int(u.get("samuraiGhostBonus",0))) if ghost(u) else int(u.attack)

static func knockout_snapshot(u: Dictionary) -> bool:
	return source(u) and int(u.level)>0 and (u.id != "wushi-maoshi" or not u.get("baseRulesSuppressed", false))

static func knocked_out(gs, owner: int, u: Dictionary, eligible: bool = true) -> void:
	if not eligible or not source(u) or int(u.level)<1: return
	u.samuraiGhost=true
	u.samuraiDeaths=int(u.get("samuraiDeaths",0))+1
	gs.VerifiedRules.event(gs,"samurai-ghost-entered",{"player":owner,"uid":u.uid,"power":power(u),"knockout":int(u.knockout)})

static func revived(gs, owner: int, idx: int) -> void:
	if idx<0: return
	var u: Dictionary=gs.player(owner).units[idx]
	if not u.get("samuraiGhost",false): return
	u.erase("samuraiGhost")
	gs.VerifiedRules.event(gs,"samurai-body-returned",{"player":owner,"uid":u.uid})

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("samuraiRules",false): return card
	var out:=card.duplicate(true)
	var src: int=gs._source_index(owner,card)
	if src<0: return out
	var u: Dictionary=gs.player(owner).units[src]
	out.allowKnockedSource=ghost(u)
	if card.get("samuraiInstant",false) and ghost(u): out.keywords.append("instant")
	if card.get("samuraiGrudge",false):
		out.value=int(card.value)+gs.player(owner).units.filter(func(ally):return int(ally.hp)<=0 and not ally.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(ally)).size()
		out.effects[0].value=out.value
	if card.get("samuraiPursuit",false) and ghost(u):
		out.target="enemy-unit"
		out.keywords.append("pursuit")
		out.combatOption.pursuit=true
	if card.get("type")=="combat":
		out.currentCardStats="+%d攻/+%d甲" % [int(out.value),int(out.combatOption.get("shield",0))]
		if ghost(u): out.currentCardStats+=" · 幽魂%d力量" % power(u)
	return out

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("samuraiRules",false): return true
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	var u: Dictionary=gs.player(owner).units[src]
	return available(u) and not (card.get("type")=="awakening" and u.awakened)

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("samuraiPursuit",false): return null
	var src: int=gs._source_index(owner,card)
	if src<0 or not ghost(gs.player(owner).units[src]): return null
	return gs.player(1-owner).units.filter(func(u):return int(u.hp)>0 and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil")).map(func(u):return str(u.uid))

static func attack_targets(gs, owner: int, src: int):
	if src<0 or not ghost(gs.player(owner).units[src]): return null
	if gs.VerifiedRules.Combat.has(gs.player(owner).units[src],"pursuit"): return null
	return ["avatar-%d" % (1-owner)]

static func combat_available(u: Dictionary, options: Dictionary) -> bool:
	return available(u) and (not options.has("samuraiStartDeaths") or int(options.samuraiStartDeaths)==int(u.get("samuraiDeaths",0)))

static func prepare_combat(gs, owner: int, src: int, options: Dictionary, _target_id = null) -> Dictionary:
	var out:=options.duplicate(true)
	var u: Dictionary=gs.player(owner).units[src]
	if source(u): out.samuraiStartDeaths=int(u.get("samuraiDeaths",0))
	if out.get("samuraiAnger",false): out.samuraiDeathSnapshot=int(u.get("samuraiDeaths",0))
	if out.get("samuraiTangzhu",false):
		out.erase("directAvatar")
		out.samuraiNoDirect=true
	elif ghost(u) and u.id != "wushi-maoshi" and not out.get("pursuit",false): out.directAvatar=true
	return out

static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if options.get("samuraiAnger",false) and int(u.get("samuraiDeaths",0))>int(options.get("samuraiDeathSnapshot",0)):
		gs.resolution_stack.append({"kind":"samurai-anger-reuse","playerIndex":owner,"sourceIndex":src,"card":options.get("combatCard",Content.card_def("c19304")).duplicate(true)})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id = null) -> bool:
	var u: Dictionary=gs.player(owner).units[src]
	match str(effect.get("action","")):
		"samurai-suicide":
			if int(u.hp)>0: gs._knockout_unit(u,owner,src)
			u.samuraiGhostBonus=int(u.get("samuraiGhostBonus",0))+1
			gs.VerifiedRules.event(gs,"samurai-ghost-strengthened",{"player":owner,"uid":u.uid,"bonus":u.samuraiGhostBonus})
		"samurai-awaken":
			if u.awakened: return true
			u.awakened=true
			u.passive_hooks=[]
			u.samuraiCannotRevive=true
			u.permanentAttack=int(u.get("permanentAttack",0))+int(effect.value.attack)
			gs._recalc(u)
			if int(u.hp)>0: gs._knockout_unit(u,owner,src)
			gs.VerifiedRules.event(gs,"samurai-awakened",{"player":owner,"uid":u.uid})
		"samurai-combat":
			if not available(u) or gs.VerifiedRules.Stun.blocks(gs,owner,u,card): return true
			var opts: Dictionary=card.get("combatOption",{}).duplicate(true)
			opts.combatCard=card.duplicate(true)
			gs._grant_unit_armor(u,int(opts.get("shield",0)))
			gs._resolve_combat(owner,src,int(effect.value),false,false,false,false,target_id,false,opts)
		_: return false
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	if f.get("kind")!="samurai-anger-reuse": return false
	var owner:=int(f.playerIndex); var src:=int(f.sourceIndex)
	var u: Dictionary=gs.player(owner).units[src]
	if not available(u) or gs.VerifiedRules.Stun.blocks(gs,owner,u): return true
	var card: Dictionary=f.card
	gs.VerifiedRules.event(gs,"samurai-anger-reused",{"player":owner,"uid":u.uid,"card":card})
	gs._push_card_frames(owner,str(card.id),null,card,src,0,true)
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("samuraiRules",false): return null
	var u: Dictionary=gs.player(owner).units[gs._source_index(owner,card)]
	if card.get("effect")=="samurai-suicide": return 32 if ghost(u) else 48
	if card.get("type")=="awakening": return 78 if not u.awakened else -100
	var damage:=maxi(0,power(u)+int(card.value))
	if card.get("combatOption",{}).get("pursuit",false):
		var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,target_id)
		if target.is_empty(): return -100
		return 55+damage+(25 if damage>=int(target.hp)+int(target.shield) else 0)
	if ghost(u) and not card.get("combatOption",{}).get("samuraiTangzhu",false): return 60+damage*3+(200 if damage>=int(gs.player(1-owner).avatarHp) else 0)
	return 42+damage*2
