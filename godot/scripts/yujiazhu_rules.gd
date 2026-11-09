class_name YujiazhuRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Charge := preload("res://scripts/sun_smoke_rules.gd")
const TALISMANS := ["c18901", "c18904", "c18907"]

static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("yujiazhuRules", false))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func history(gs, owner: int) -> Array:
	return gs.player(owner).get("yujTalismansUsed", [])
static func discount(gs, owner: int) -> int:
	return gs.player(owner).realms.filter(func(r):return int(r.hp)>0 and r.get("nativeRealm")=="yuj-fox-hunt").size()

# Nominal burst size governs the effect and burst history; only its payment is
# reduced. Ordinary charging abilities continue to use SunSmoke's own API.
static func quote_burst(gs, owner: int, src: int, nominal: int) -> Dictionary:
	var reduction:=mini(maxi(0,nominal),discount(gs,owner))
	var q:Dictionary=Charge.quote_charge(gs,owner,src,maxi(0,nominal-reduction),true)
	q.nominalAmount=nominal;q.discount=reduction
	return q
static func can_pay_burst(gs, owner: int, src: int, nominal: int) -> bool:
	return bool(quote_burst(gs,owner,src,nominal).ok)
static func pay_burst(gs, owner: int, src: int, nominal: int) -> bool:
	var q:=quote_burst(gs,owner,src,nominal)
	if not q.ok:return false
	if not Charge.pay_charge(gs,owner,src,int(q.amount),true):return false
	gs.VerifiedRules.event(gs,"burst-payment",{"player":owner,"uid":gs.player(owner).units[src].uid,"nominal":nominal,"cost":int(q.amount),"discount":int(q.discount),"free":bool(q.free)})
	return true

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("yujiazhuRules",false):return card
	var c:=card.duplicate(true);var src:int=gs._source_index(owner,c)
	if src<0:return c
	var u:Dictionary=gs.player(owner).units[src]
	if c.id in TALISMANS:
		c.movementBurst=int(inst.get("movementBurst",0))
		if discount(gs,owner)>0 and "instant" not in c.keywords:c.keywords.append("instant")
		if int(c.movementBurst)==3:
			c.yujArrow=true;c.type="combat";c.typeLabel="战斗牌";c.name=str(c.name).replace("符","箭")
			c.responseAction="assault"
			c.value=1;c.target="enemy-unit";c.combatOption={"shield":1,"pursuit":true,"immuneCombat":bool(u.awakened)}
			if "pursuit" not in c.keywords:c.keywords.append("pursuit")
			var q:=quote_burst(gs,owner,src,3)
			c.currentCardStats="符咒转化 · 爆能3 · "+("日和坊免支付" if q.free else "支付%d能量"%int(q.amount))
			c.text+="\n爆能3：转化为+1力量/+1护甲战斗牌，先结算符咒，再攻击所选敌方式神。"+("本次战斗免疫战斗伤害。" if u.awakened else "")
		else:
			c.yujArrow=false;c.currentCardStats="普通符咒 · 可选择爆能3"
	elif c.id=="c18908":
		var n:=history(gs,owner).size()
		c.value={"attack":3+n,"hp":6+n,"setBase":true};c.effects[0].value=c.value.duplicate(true)
		c.formRules.yujPrayerCount=n;c.currentCardStats="已使用%d种符咒 · 当前%d/%d"%[n,3+n,6+n]
	return c
static func targets(gs, owner: int, card: Dictionary):
	if str(card.get("id","")) not in TALISMANS:return null
	return gs.player(1-owner).units.filter(func(u):
		return int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u,"veil") and (card.get("yujArrow",false) or card.id!="c18901" or not u.get("form",{}).is_empty())).map(func(u):return str(u.uid))
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("yujiazhuRules",false):return true
	var src:int=gs._source_index(owner,card)
	if src<0:return false
	if card.id=="c18905" and gs.player(owner).units[src].awakened:return false
	if card.id in TALISMANS:
		var n:=int(card.get("movementBurst",0))
		return n==0 or (n==3 and active(gs.player(owner).units[src]) and can_pay_burst(gs,owner,src,3))
	return true
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if str(card.get("id","")) not in TALISMANS:return
	var owner:=int(frame.playerIndex)
	if str(card.id) not in history(gs,owner):
		if not gs.player(owner).has("yujTalismansUsed"):gs.player(owner).yujTalismansUsed=[]
		gs.player(owner).yujTalismansUsed.append(str(card.id))
		refresh_prayer(gs,owner)
	gs.VerifiedRules.event(gs,"yuj-talisman-used",{"player":owner,"uid":gs.player(owner).units[int(frame.sourceIndex)].uid,"card":str(card.id),"distinct":history(gs,owner).size(),"arrow":bool(card.get("yujArrow",false))})
static func refresh_prayer(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if not active(u) or not u.get("formRules",{}).get("yujPrayer",false):continue
		var n:=history(gs,owner).size();var change:=n-int(u.formRules.get("yujPrayerCount",0))
		u.formRules.yujPrayerCount=n
		if change!=0:u.form.attackBonus=int(u.form.attackBonus)+change;u.form.hpBonus=int(u.form.hpBonus)+change;gs._recalc(u)
static func form_entered(gs, owner: int, _src: int, _card: Dictionary) -> void:
	refresh_prayer(gs,owner)
static func apply_talisman(gs, owner: int, src: int, id: String, target_id) -> void:
	var victim:=1-owner;var idx:int=gs._unit_index_by_uid(victim,str(target_id))
	if idx<0:return
	var u:Dictionary=gs.player(victim).units[idx]
	if int(u.hp)<=0 or u.get("removed",false):return
	match id:
		"c18901":
			if not u.get("form",{}).is_empty():u.yujDoomTurn=gs.turn_counter
		"c18904":
			gs.VerifiedRules.Stun.apply(gs,victim,idx,1,owner);u.movementZeroTurn=gs.turn_counter;gs._recalc(u)
		"c18907":u.yujBreakTurn=gs.turn_counter
	gs.VerifiedRules.event(gs,"yuj-talisman-applied",{"player":owner,"uid":gs.player(owner).units[src].uid,"cardId":id,"target":u.uid})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.get("action","")):
		"yuj-talisman":
			if card.get("yujArrow",false):
				if not pay_burst(gs,owner,src,3):return true
				gs.VerifiedRules.Whale.burst(gs,owner,src,3)
			apply_talisman(gs,owner,src,str(card.id),target_id)
			if card.get("yujArrow",false):
				var options:Dictionary=card.combatOption.duplicate(true);options.combatCard=card.duplicate(true)
				gs._grant_unit_armor(gs.player(owner).units[src],1)
				gs._record("assault",{"unit":src,"bonus":1,"target":target_id},owner)
				gs._resolve_combat(owner,src,1,false,false,false,false,target_id,false,options)
		"yuj-harvest":Charge.gain_charge(gs,owner,src,3);gs._draw(owner,1)
		_:return false
	return true
static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary, target_id) -> void:
	if card.get("yujArrow",false):
		if not pay_burst(gs,owner,src,3):return
		gs.VerifiedRules.Whale.burst(gs,owner,src,3)
	apply_talisman(gs,owner,src,str(card.id),target_id)
	if card.get("yujArrow",false):gs.VerifiedRules.ArmorBreak.respond_combat(gs,combat_id,owner,src,card)

static func prayer_targets(gs, owner: int, src: int):
	var u:Dictionary=gs.player(owner).units[src]
	if not active(u) or not u.get("formRules",{}).get("yujPrayer",false):return null
	var ids:Array=gs.player(1-owner).units.filter(func(t):return int(t.hp)>0 and gs.VerifiedRules.OwlInsect.shikigami(t) and not gs.VerifiedRules.Combat.has(t,"veil")).map(func(t):return str(t.uid))
	if gs.front_index(1-owner)<0:ids.append("avatar-%d"%(1-owner))
	return ids
static func prayer_started(gs, frame: Dictionary) -> bool:
	if frame.get("yujPrayerOffered",false):return false
	frame.yujPrayerOffered=true
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var u:Dictionary=gs.player(owner).units[src]
	if not frame.options.get("basicAttack",false) or not active(u) or not u.get("formRules",{}).get("yujPrayer",false):return false
	var target_id=frame.get("targetId");var target:int=gs._unit_index_by_uid(1-owner,str(target_id))
	if target<0 or int(gs.player(1-owner).units[target].hp)<=0 or history(gs,owner).is_empty():return false
	gs.resolution_stack.append({"kind":"yuj-prayer-ready","combat":frame.duplicate(true)})
	var used:Array=history(gs,owner)
	for i in range(used.size()-1,-1,-1):
		var card:Dictionary=Content.card_def(str(used[i])).duplicate(true)
		card.movementBurst=0;card.yujArrow=false;card.yujPrayerAutomatic=true
		gs._push_card_frames(owner,str(card.id),target_id,card,src,0,true)
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="yuj-prayer-ready":return false
	gs._resolve_combat_ready(frame.combat);return true
static func prepare_attack(gs, frame: Dictionary, target: int) -> void:
	if target<0:return
	var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var u:Dictionary=gs.player(owner).units[src]
	var victim := int(frame.options.get("combatVictim", 1-owner))
	if active(u) and u.get("formRules",{}).get("yujHunt",false):frame.options.comboAgainstUnit=true
	if int(gs.player(victim).units[target].get("yujBreakTurn",-1))==gs.turn_counter:
		frame.options.yujCritical=true;frame.options.pierce=true
static func damaged(gs, u: Dictionary, taken: int) -> bool:
	return taken>0 and int(u.get("yujDoomTurn",-1))==gs.turn_counter
static func knocked_out(u: Dictionary) -> void:
	u.erase("yujDoomTurn");u.erase("yujBreakTurn")
static func end_turn(gs) -> void:
	for p in gs.players:
		for u in p.units:
			for key in ["yujDoomTurn","yujBreakTurn"]:
				if int(u.get(key,-1))==gs.turn_counter:u.erase(key)
static func marks(gs, owner: int, idx: int) -> Array:
	var u:Dictionary=gs.player(owner).units[idx];var out:Array=[]
	if source(u):out.append("已使用%d/3种符咒"%history(gs,owner).size())
	if int(u.get("yujDoomTurn",-1))==gs.turn_counter:out.append("驱魔 · 本回合实际受伤时气绝")
	if int(u.get("yujBreakTurn",-1))==gs.turn_counter:out.append("破魔 · 本回合攻击该式神获得暴击及贯通")
	if u.get("formRules",{}).get("yujHunt",false):out.append("御狩 · 攻击式神获得连击")
	return out
static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("yujiazhuRules",false):return null
	if card.id=="c18905":return 58
	if card.id=="c18908":return 40+8*history(gs,owner).size()
	if card.id=="c18901" and not card.get("yujArrow",false):return 32
	if card.id in TALISMANS:
		var target:Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(target_id))
		return 40+int(target.get("attack",0))+(12 if card.get("yujArrow",false) else 0)
	return 35
