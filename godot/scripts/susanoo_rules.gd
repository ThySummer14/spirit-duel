class_name SusanooRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("susanooRules",false)
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func tomb(u: Dictionary) -> bool:
	return u.has("susanooOriginal")
static func field(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r): return r.get("nativeRealm")=="susanoo-domain" and int(r.hp)>0)
static func one_hp(gs, owner: int) -> bool:
	return gs.player(1-owner).units.any(func(u): return int(u.hp)==1 and not u.get("removed",false))
static func prepare_attack(gs, owner: int, src: int, idx: int, options: Dictionary) -> bool:
	var u: Dictionary=gs.player(owner).units[src]
	if idx<0 or not source(u) or not active(u) or options.get("susanooAttackPrepared",false): return false
	options.susanooAttackPrepared=true
	gs._grow_unit(u,1,0)
	u.susanooOrdinaryPower=int(u.get("susanooOrdinaryPower",0))+1
	var victim:=int(options.get("combatVictim",1-owner))
	if u.awakened or int(gs.player(victim).units[idx].hp)==1: options.pierce=true
	gs.VerifiedRules.event(gs,"susanoo-attack-growth",{"player":owner,"uid":u.uid,"target":gs.player(victim).units[idx].uid,"pierce":bool(options.get("pierce",false))})
	return true
static func begin_strike(gs, owner: int, src: int, options: Dictionary) -> Dictionary:
	var u: Dictionary=gs.player(owner).units[src]
	var old := {"present":u.has("susanooTombDamage"),"value":u.get("susanooTombDamage",false),"domain":u.get("susanooDomainStrike",false)}
	u.susanooDomainStrike=source(u) and options.get("basicAttack",false) and field(gs,owner)
	u.susanooTombDamage=source(u) and (options.get("susanooTomb",false) or (options.get("basicAttack",false) and field(gs,owner)))
	return old
static func end_strike(gs, owner: int, src: int, old: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	if old.present: u.susanooTombDamage=old.value
	else: u.erase("susanooTombDamage")
	if old.domain: u.susanooDomainStrike=true
	else: u.erase("susanooDomainStrike")
static func knocked_out(u: Dictionary) -> void:
	u.attackBonus=int(u.attackBonus)-int(u.get("susanooOrdinaryPower",0))
	u.erase("susanooOrdinaryPower"); u.erase("susanooCombatUnyielding")
static func replace_body(u: Dictionary, body: Dictionary) -> void:
	u.clear(); u.merge(body,true)
static func restore_tomb(gs, owner: int, u: Dictionary, revive: bool) -> void:
	if not tomb(u): return
	var original: Dictionary=u.susanooOriginal.duplicate(true)
	var was_front:=int(u.front)
	replace_body(u,original)
	u.hp=0; u.front=was_front; u.knockout=0
	if revive and gs.VerifiedRules.Rebirth.can_revive(u):
		u.hp=1; u.front=0
		gs.VerifiedRules.Movement.revived(gs,owner,gs._unit_index_by_uid(owner,u.uid))
		gs.VerifiedRules.event(gs,"susanoo-tomb-restored",{"player":owner,"uid":u.uid,"hp":1})
	elif revive: u.knockout=int(gs.rules.knockoutCountdown)
	gs._recalc(u)
static func capture_kill(gs, u: Dictionary, killer: int, src: int) -> bool:
	if u.get("susanooPreparingTomb",false) or killer<0 or src<0 or src>=gs.player(killer).units.size(): return false
	var attacker: Dictionary=gs.player(killer).units[src]
	var victim: int=1-killer
	if gs._unit_index_by_uid(victim,u.uid)<0 or not source(attacker) or not attacker.get("susanooTombDamage",false): return false
	var domain: bool=attacker.get("susanooDomainStrike",false)
	if not domain and (tomb(u) or u.get("summoned",false)): return false
	var original: Dictionary
	var position:=int(u.front)
	if tomb(u):
		original=u.susanooOriginal.duplicate(true)
		gs.VerifiedRules.Panguan.destroyed(gs,killer,src,victim,u)
	else:
		# The replacement suppresses the killed body's own death/form abilities.
		# Reuse ordinary cleanup for temporary stats, charms and kill accounting.
		var hooks: Array=u.get("passive_hooks",[]).duplicate(true)
		u.susanooPreparingTomb=true; u.baseRulesSuppressed=true
		u.form={}; u.formRules={}; u.formHooks=[]; u.formAbility=""
		u.erase("formCountdown"); u.erase("formExpiresTurn")
		gs._knockout_unit(u,killer,src)
		u.erase("susanooPreparingTomb"); u.erase("baseRulesSuppressed")
		u.passive_hooks=hooks
		original=u.duplicate(true)
	for key in ["susanooTombDamage","susanooDomainStrike","susanooCombatUnyielding"]: original.erase(key)
	var serial: int=gs.next_rule_event_id
	var body := {"uid":u.uid,"id":original.id,"name":"雷冢","title":"须佐之男 · 替换式神","color":"#b6b395","baseAttack":0,"baseMaxHp":1,"attack":0,"maxHp":1,"hp":1,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":int(original.level),"front":position,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formHooks":[],"formAbility":"不能攻击。原式神所属方回合结束时，复活原式神并使其生命为1。","charge":0,"passive_hooks":[],"baseRulesSuppressed":true,"cannotAttack":true,"susanooOriginal":original,"susanooTombSerial":serial,"presentationId":"susanoo-tomb","art":"assets/ink.svg","awakenedArt":"assets/ink.svg","summoned":original.get("summoned",false),"countsAsShikigami":true}
	replace_body(u,body)
	gs.VerifiedRules.OwlInsect.refresh(gs); gs.VerifiedRules.Poison.refresh_all(gs)
	gs.VerifiedRules.event(gs,"susanoo-tomb-created",{"player":killer,"victimPlayer":victim,"uid":attacker.uid,"target":u.uid,"originalName":original.name,"hp":1})
	return true
static func begin_duel(gs, frame: Dictionary) -> void:
	var owner:=int(frame.playerIndex); var victim:=int(frame.options.get("combatVictim",1-owner))
	var a: Dictionary=gs.player(owner).units[int(frame.sourceIndex)]; var d: Dictionary=gs.player(victim).units[int(frame.defenderIndex)]
	if frame.options.get("susanooDuelPrepared",false): return
	if not ((active(a) and a.get("formRules",{}).get("susanooDuel",false)) or (active(d) and d.get("formRules",{}).get("susanooDuel",false))): return
	frame.options.susanooDuelPrepared=true
	frame.options.susanooDuelFloors=[]
	for u in [a,d]:
		frame.options.susanooDuelFloors.append({"uid":u.uid,"previous":u.get("susanooCombatUnyielding",false)})
		u.susanooCombatUnyielding=true
	gs.VerifiedRules.event(gs,"susanoo-duel-unyielding",{"player":owner,"uid":a.uid,"target":d.uid})
static func finish_duel(gs, options: Dictionary) -> void:
	for item in options.get("susanooDuelFloors",[]):
		var u: Dictionary=gs._unit_by_uid(gs._all_units(),item.uid)
		if u.is_empty(): continue
		if item.previous and int(u.hp)>0 and not tomb(u): u.susanooCombatUnyielding=true
		else: u.erase("susanooCombatUnyielding")
static func end_turn(gs, owner: int) -> void:
	for u in gs.player(owner).units.duplicate():
		if tomb(u): restore_tomb(gs,owner,u,true)
static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.id!="c28105": return card
	var view:=card.duplicate(true)
	view.enhanced=one_hp(gs,owner); view.allowKnockedSource=view.enhanced
	view.currentCardStats="当前4/7 · "+("气绝可用，使用时复活" if view.enhanced else "未满足复活增强")
	return view
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("susanooRules",false): return true
	var src: int=gs._source_index(owner,card)
	if src<0: return false
	var u: Dictionary=gs.player(owner).units[src]
	if card.id=="c28106" and u.awakened: return false
	if card.id=="c28105" and int(u.hp)<=0: return bool(card.get("enhanced",false)) and gs.VerifiedRules.YanmieTrio.can_revive(gs,owner,u)
	return true
static func targets(gs, owner: int, card: Dictionary):
	if card.get("id","") not in ["c28101","c28102","c28107"]: return null
	var pool: Array=gs.player(1-owner).units.filter(func(u): return int(u.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (card.id!="c28101" or int(u.hp)==1)).map(func(u):return u.uid)
	if card.id=="c28102" and gs.front_index(1-owner)<0: pool.append("avatar-%d"%(1-owner))
	return pool
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules",{}).get("susanooDuel",false): queue_lowest(gs,owner,src)
static func form_turn_start(gs, owner: int, src: int) -> void:
	if active(gs.player(owner).units[src]) and gs.player(owner).units[src].get("formRules",{}).get("susanooDuel",false): queue_lowest(gs,owner,src)
static func queue_lowest(gs, owner: int, src: int) -> void:
	gs.resolution_stack.append({"kind":"susanoo-lowest-attack","playerIndex":owner,"sourceIndex":src})
static func put_thunder(gs, owner: int) -> void:
	var p: Dictionary=gs.player(owner)
	var inst := {"instanceId":"%s-thunder-%d"%[p.id,gs.next_card_id],"definitionId":"c28101"}; gs.next_card_id+=1
	if p.hand.size()<int(gs.rules.maxHandSize): p.hand.append(inst)
	gs.VerifiedRules.Glutton.mark_hand(gs,owner)
	gs.VerifiedRules.event(gs,"susanoo-thunder-generated",{"player":owner,"instanceId":inst.instanceId,"burned":not p.hand.has(inst)})
static func cut_damage(gs, owner: int, src: int, target_id) -> void:
	var idx: int=gs._unit_index_by_uid(1-owner,target_id)
	if idx<0 or int(gs.player(1-owner).units[idx].hp)<=0: return
	var u: Dictionary=gs.player(owner).units[src]; var target: Dictionary=gs.player(1-owner).units[idx]
	var overflow:=0
	if u.awakened and not target.get("bloodTransfer",false) and not gs.VerifiedRules.OniAsura.will_transfer(gs,target):
		overflow=maxi(0,gs.VerifiedRules.OwlInsect.reduced(target,gs.VerifiedRules.Jorogumo.received_damage(target,maxi(0,3+int(target.armorBreak)-int(target.shield))))-int(target.hp))
	var scope:=begin_strike(gs,owner,src,{"susanooTomb":true})
	var hit: Dictionary=gs._damage_unit(1-owner,idx,3,owner,src)
	end_strike(gs,owner,src,scope)
	if gs._card_effect_context.is_empty(): gs.VerifiedRules.event(gs,"damage-resolved",{"player":owner,"uid":u.uid,"target":target_id,"victimPlayer":1-owner,"amount":int(hit.get("damage",0)),"blocked":int(hit.get("damage",0))==0,"card":Content.card_def("c28107")})
	if overflow>0 and gs.winner<0:
		var dealt: int=gs._damage_avatar(1-owner,overflow,owner,src)
		if gs._card_effect_context.is_empty(): gs.VerifiedRules.event(gs,"damage-resolved",{"player":owner,"uid":u.uid,"target":"","victimPlayer":1-owner,"amount":dealt,"blocked":dealt==0,"card":Content.card_def("c28107")})
	gs.VerifiedRules.event(gs,"susanoo-cut-damage",{"player":owner,"uid":u.uid,"target":target_id,"amount":3,"overflow":overflow})
static func combat(gs, owner: int, src: int, card: Dictionary, target_id, grant_armor: bool=true) -> void:
	var options: Dictionary=card.get("combatOption",{}).duplicate(true); options.combatCard=card.duplicate(true)
	if grant_armor: gs._grant_unit_armor(gs.player(owner).units[src],int(options.get("shield",0)))
	gs._record("assault",{"unit":src,"bonus":0,"target":target_id},owner)
	gs._resolve_combat(owner,src,0,false,false,false,false,target_id,false,options)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	match str(effect.get("action","")):
		"susanoo-combat": combat(gs,owner,src,card,target_id)
		"susanoo-domain": gs._deploy_realm(owner,card); gs._apply_encourage(owner,1,1)
		"susanoo-guard":
			if int(gs.player(owner).units[src].hp)<=0 and card.get("enhanced",false): gs.VerifiedRules.Peach.revive(gs,owner,src,gs.player(owner).units[src],false,false)
			if int(gs.player(owner).units[src].hp)>0: gs._apply_form(owner,src,card,card.value)
		"susanoo-awaken": put_thunder(gs,owner); gs._awaken(owner,src,card,{"attack":1,"hp":1})
		"susanoo-cut":
			gs._grant_unit_armor(gs.player(owner).units[src],int(card.combatOption.shield))
			gs.resolution_stack.append({"kind":"susanoo-cut-combat","playerIndex":owner,"sourceIndex":src,"card":card.duplicate(true)})
			gs.resolution_stack.append({"kind":"susanoo-cut-second","playerIndex":owner,"sourceIndex":src,"excluded":target.get("uid",target_id)})
			cut_damage(gs,owner,src,target_id)
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind:=str(frame.get("kind",""))
	if not kind.begins_with("susanoo-"): return false
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex); var u: Dictionary=gs.player(owner).units[src]
	match kind:
		"susanoo-lowest-attack":
			if not active(u) or u.get("cannotAttack",false) or gs.VerifiedRules.Stun.blocks(gs,owner,u) or not u.get("formRules",{}).get("susanooDuel",false): return true
			var pool: Array=gs.player(1-owner).units.filter(func(x): return int(x.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(x))
			if pool.is_empty(): return true
			var minimum:=65536
			for x in pool: minimum=mini(minimum,int(x.hp))
			pool=pool.filter(func(x):return int(x.hp)==minimum)
			var chosen: Dictionary=pool[int(floor(gs.randf01()*pool.size()))]
			gs.VerifiedRules.event(gs,"susanoo-lowest-attack",{"player":owner,"uid":u.uid,"target":chosen.uid,"hp":minimum})
			gs._resolve_combat(owner,src,0,false,false,false,false,chosen.uid,false,{"pursuit":true})
		"susanoo-cut-second":
			var pool: Array=gs.player(1-owner).units.filter(func(x):return int(x.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(x) and str(x.uid)!=str(frame.excluded))
			if not pool.is_empty(): cut_damage(gs,owner,src,pool[int(floor(gs.randf01()*pool.size()))].uid)
		"susanoo-cut-combat":
			if active(u) and not gs.VerifiedRules.Stun.blocks(gs,owner,u): combat(gs,owner,src,frame.card,null,false)
		_: return false
	return true
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]; var result: Array=[]
	if tomb(u): result.append("雷冢 · 不能攻击/使用原式神牌 · 己方回合结束复活原式神至1生命")
	if source(u): result.append("攻击式神前 +1力量 · "+("觉醒贯通" if u.awakened else "攻击1生命式神贯通"))
	if u.get("formRules",{}).get("susanooDuel",false): result.append("天雷万象 · 交战双方不屈 · 进场/回合开始攻击最低生命敌方式神")
	return result
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("susanooRules",false): return null
	if card.id=="c28101": return 95
	if card.id=="c28105" and card.get("enhanced",false) and int(gs.player(owner).units[gs._source_index(owner,card)].hp)<=0: return 110
	if card.type=="form": return -50 if gs.player(owner).units[gs._source_index(owner,card)].get("form",{}).get("cardId")==card.id else 75
	var target: Dictionary=gs._unit_by_uid(gs.player(1-owner).units,target_id)
	return 70+int(target.get("attack",0))
