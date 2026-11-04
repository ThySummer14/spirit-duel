class_name FutakuchiRules
extends RefCounted
const Content:=preload("res://scripts/content_loader.gd")
const FOCUS_POOL:=["c29501","c29502","c29503","c29504","c29505","c29507","c29508"]
static func source(u: Dictionary) -> bool:return Content.runtime_unit_def(u).get("futakuchiRules",false)
static func active(u: Dictionary) -> bool:return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func provider(gs, owner: int, card: Dictionary) -> int:
	var src:int=gs._source_index(owner,card)
	for idx in gs.player(owner).units.size():
		var u:Dictionary=gs.player(owner).units[idx]
		if source(u) and active(u) and (idx==src or u.awakened) and gs.VerifiedRules.SunSmoke.can_pay_charge(gs,owner,idx,2):return idx
	return -1
static func pool(level: int) -> Array:return FOCUS_POOL.filter(func(id):return int(Content.card_def(id).level)<=level)
static func symbiosis(gs, owner: int, src: int) -> bool:
	var u:Dictionary=gs.player(owner).units[src]
	if not active(u) or not u.get("formRules",{}).get("futakuchiSymbiosis",false):return false
	if not gs.VerifiedRules.SunSmoke.pay_charge(gs,owner,src,2):return false
	var choices:=pool(int(u.level));var id:String=choices[int(gs.next_random()%choices.size())]
	gs.resolution_stack.append({"kind":"futakuchi-focus","playerIndex":owner,"sourceIndex":src,"cardId":id,"context":{}})
	gs.VerifiedRules.event(gs,"futakuchi-symbiosis",{"player":owner,"uid":u.uid,"cardId":id,"name":Content.card_def(id).name})
	return true
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("futakuchiSymbiosis",false):symbiosis(gs,owner,src)
static func attack_started(gs, frame: Dictionary) -> bool:
	if frame.get("futakuchiOffered",false):return false
	frame.futakuchiOffered=true
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var u:Dictionary=gs.player(owner).units[src]
	if not gs.VerifiedRules.Samurai.combat_available(u,frame.options) or gs.winner>=0:return false
	if gs.VerifiedRules.OwlInsect.shikigami(u):
		for r in gs.player(owner).realms:
			if r.get("nativeRealm")=="futakuchi-fear" and int(r.hp)>0:
				var source_idx:int=gs._source_index(owner,Content.card_def(str(r.cardId)))
				if source_idx>=0:gs.VerifiedRules.SunSmoke.gain_charge(gs,owner,source_idx,1)
	var depth:int=gs.resolution_stack.size()
	if symbiosis(gs,owner,src):
		gs.resolution_stack.insert(depth,{"kind":"futakuchi-combat-ready","combat":frame.duplicate(true)});return true
	return false
static func knocked_out(u: Dictionary) -> void:
	var growth:=int(u.get("futakuchiFearGrowth",0));u.attackBonus=int(u.attackBonus)-growth;u.maxHpBonus=int(u.maxHpBonus)-growth
	u.erase("futakuchiFearGrowth");u.erase("futakuchiUnyielding")
static func candidates(gs, owner: int, wounded: bool=false) -> Array:
	return gs.player(owner).units.filter(func(u):return int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u) and (not wounded or int(u.hp)<int(u.maxHp)))
static func apply_focus(gs, owner: int, src: int, id: String, spell: bool=false) -> void:
	var u:Dictionary=gs.player(owner).units[src]
	gs.VerifiedRules.event(gs,"futakuchi-focus",{"player":owner,"uid":u.uid,"cardId":id})
	match id:
		"c29501":gs._draw(owner,1)
		"c29502":
			if int(u.hp)>0:
				gs._grow_unit(u,1,1)
				gs.VerifiedRules.Glutton.record_permanent(u,1,1)
				gs.VerifiedRules.SunSmoke.remember_permanent(u,1,1)
		"c29503":
			var targets:=candidates(gs,owner)
			if not targets.is_empty():
				var t:Dictionary=targets[int(gs.next_random()%targets.size())];gs._grow_unit(t,1,1);t.swift=true;t.futakuchiFearGrowth=int(t.get("futakuchiFearGrowth",0))+1
		"c29504":
			if int(u.hp)>0:u.futakuchiUnyielding=true
		"c29505":
			gs.VerifiedRules.SunSmoke.gain_charge(gs,owner,src,3)
			gs.VerifiedRules.ThreeTail.projectile(gs,owner,src,2+(int(u.get("spellPower",0)) if spell else 0),"二口女专注")
		"c29507":
			var hits:Array=[-1]
			for i in gs.player(1-owner).units.size():
				if int(gs.player(1-owner).units[i].hp)>0 and not gs.player(1-owner).units[i].get("removed",false):hits.append(i)
			for i in range(hits.size()-1,-1,-1):gs.resolution_stack.append({"kind":"futakuchi-area-hit","playerIndex":owner,"sourceIndex":src,"targetIndex":hits[i],"context":gs._card_effect_context.duplicate(true)})
		"c29508":
			var targets:=candidates(gs,1-owner,true)
			if not targets.is_empty():
				var target:Dictionary=targets[int(gs.next_random()%targets.size())]
				gs.VerifiedRules.Panguan.destroy(gs,owner,src,1-owner,gs._unit_index_by_uid(1-owner,str(target.uid)),Content.card_def(id))
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.action):
		"futakuchi-damage":
			var target:int=gs._unit_index_by_uid(1-owner,str(target_id))
			if target>=0:gs._damage_unit(1-owner,target,6+int(gs.player(owner).units[src].get("spellPower",0)),owner,src)
		"futakuchi-focus":
			if card.get("focusPaid",false):apply_focus(gs,owner,src,str(card.id),Content.is_spell(card))
		"futakuchi-combat":
			var options:Dictionary=card.combatOption.duplicate(true);options.combatCard=card.duplicate(true)
			gs._grant_unit_armor(gs.player(owner).units[src],int(options.get("shield",0)))
			gs._record("assault",{"unit":src,"bonus":card.value,"target":target_id},owner)
			gs._resolve_combat(owner,src,int(card.value),false,false,false,false,target_id,false,options)
		_:return false
	return true
static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind:=str(f.get("kind",""))
	if not kind.begins_with("futakuchi-"):return false
	if kind=="futakuchi-combat-ready":gs._resolve_combat_entered(f.combat);return true
	var owner:=int(f.playerIndex);var src:=int(f.sourceIndex);var old:Dictionary=gs._card_effect_context;gs._card_effect_context=f.get("context",{})
	match kind:
		"futakuchi-focus":apply_focus(gs,owner,src,str(f.cardId))
		"futakuchi-area-hit":
			if int(f.targetIndex)<0:gs._damage_avatar(1-owner,2,owner,src)
			else:gs._damage_unit(1-owner,int(f.targetIndex),2,owner,src)
	gs._card_effect_context=old;return true
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.id!="c29505" or not gs.player(owner).units[gs._source_index(owner,card)].awakened
static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("futakuchiRules",false):return card
	var c:=card.duplicate(true)
	if c.has("focusEffect"):c.currentCardStats=gs.VerifiedRules.Focus.label(gs.card_payment(owner,c))
	elif c.id=="c29506":
		var u:Dictionary=gs.player(owner).units[gs._source_index(owner,c)]
		c.currentCardStats="共生 · 消耗2能量 · 当前随机池%d种专注"%pool(int(u.level)).size()
	return c
static func marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx];var result:Array=[]
	if source(u):result.append("专注能量替代 · "+("所有己方式神" if u.awakened else "自身"))
	if u.get("futakuchiUnyielding",false):result.append("血口 · 不屈")
	if u.get("formRules",{}).get("futakuchiSymbiosis",false):result.append("共生 · 进场/攻击消耗2能量 · 随机%d种"%pool(int(u.level)).size())
	return result
static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("futakuchiRules",false):return null
	var focused:bool=gs.card_payment(owner,card).get("focusPaid",false)
	return 25+(8 if focused else 0)
