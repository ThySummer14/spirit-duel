class_name FocusRules
extends RefCounted
## One read-only quote is used by the hand, legality, AI and actual payment.
static func enabled(card: Dictionary) -> bool:return card.get("lanternFocus",false) or card.has("focusEffect")
static func quote(gs, owner: int, card: Dictionary, payment: Dictionary) -> Dictionary:
	if not enabled(card):return payment
	payment.focusPaid=false;payment.focusSource=-1;payment.focusFire=0
	if int(gs.player(owner).energy)<int(payment.cost):return payment
	var provider:int=gs.VerifiedRules.Futakuchi.provider(gs,owner,card)
	if provider>=0:
		payment.focusPaid=true;payment.focusSource=provider;payment.focusCharge=gs.VerifiedRules.SunSmoke.quote_charge(gs,owner,provider,2)
	elif int(gs.player(owner).energy)>int(payment.cost):
		payment.focusPaid=true;payment.focusFire=1;payment.cost=int(payment.cost)+1
	return payment
static func commit(gs, owner: int, card: Dictionary, payment: Dictionary) -> void:
	if not enabled(card):return
	card.focusPaid=payment.get("focusPaid",false)
	if card.get("lanternFocus",false):card.lanternFocused=card.focusPaid
	if card.focusPaid and int(payment.get("focusSource",-1))>=0:
		gs.VerifiedRules.SunSmoke.pay_charge(gs,owner,int(payment.focusSource),2)
		gs.VerifiedRules.event(gs,"focus-energy-paid",{"player":owner,"uid":gs.player(owner).units[int(payment.focusSource)].uid,"card":card,"free":payment.focusCharge.free})
static func automatic(gs, owner: int, card: Dictionary, is_auto: bool) -> Dictionary:
	if not is_auto or not enabled(card):return card
	var c:=card.duplicate(true);var payment:=quote(gs,owner,c,{"cost":0})
	gs._set_fire(owner,int(gs.player(owner).energy)-int(payment.cost),true);commit(gs,owner,c,payment)
	return c
static func label(payment: Dictionary) -> String:
	if not payment.get("focusPaid",false):return "专注未触发 · 可用资源不足"
	if int(payment.get("focusSource",-1))>=0:return "专注 · 日和坊免除2能量" if payment.focusCharge.free else "专注 · 二口女消耗2能量"
	return "专注 · 额外消耗1鬼火"
