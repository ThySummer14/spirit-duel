class_name LinkRules
extends RefCounted
const Content:=preload("res://scripts/content_loader.gd")
# Linking is a pre-use replacement, not a draw or a second card use.
static func candidates(gs, owner: int, card: Dictionary) -> Array:
	if not gs.response_window.is_empty() or gs.phase=="opening" or card.get("twoFacesFromDeck",false):return []
	var zen: Array = gs.VerifiedRules.ZenMisfortune.zen_candidates(gs, owner, card)
	if not zen.is_empty(): return zen
	var ms_pool:Array=gs.VerifiedRules.MirrorSong.candidates(gs,owner,card)
	if not ms_pool.is_empty():return ms_pool
	var result:Array=gs.VerifiedRules.BlackWhite.link_candidates(gs,owner,card)
	if not result.is_empty():return result
	return gs.VerifiedRules.TwoFaces.link_candidates(gs,owner,card)
static func ready_hand(gs, owner: int) -> int:return int(gs.player(owner).get("linkReady",{}).get("hand",-1))
static func extra_instances(gs, owner: int) -> Array:
	var p:Dictionary=gs.player(owner);var ids:Array=[]
	for grant in p.get("twoFacesDeckAccess",[]):
		if int(grant.turn)==gs.turn_counter and grant.id not in ids:ids.append(grant.id)
	return p.deck.filter(func(i):return str(i.instanceId) in ids and (not gs.playable_deck_top(owner) or i!=p.deck.back()))
static func virtual_instance(gs, owner: int, index: int):
	var p:Dictionary=gs.player(owner);var ready:Dictionary=p.get("linkReady",{})
	if not ready.is_empty() and index>=0 and index==int(ready.get("hand",-1)):
		return ready.selected
	var extra:int=index-p.hand.size()-(1 if gs.playable_deck_top(owner) else 0);var cards:=extra_instances(gs,owner)
	if extra>=0 and extra<cards.size():
		var inst:Dictionary=cards[extra].duplicate(true);inst.twoFacesFromDeck=true;return inst
	return null
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var c:=card.duplicate(true)
	for key in ["linkedUse","linkOtherId","linkRetrieve","linkedByUid","twoFacesFromDeck"]:
		if inst.has(key):c[key]=inst[key]
	if c.get("twoFacesFromDeck",false):
		c.twoFacesDeckFree=int(gs.player(owner).get("twoFacesDeckFreeTurn",-1))!=gs.turn_counter
		c.currentCardStats="风雷万象 · 从牌库使用 · "+("本回合首次免费" if c.twoFacesDeckFree else "正常消耗鬼火")
	elif not inst.get("linkedUse",false) and ready_hand(gs,owner)<0:
		c.linkAvailable=not candidates(gs,owner,c).is_empty()
		# Preview the original choice with its real enhanced legality/payment.
		if c.linkAvailable:c.linkedUse=true
	return c
static func start(gs, owner: int, index: int) -> bool:
	var ms_link=gs.VerifiedRules.MirrorSong.start_link(gs,owner,index)
	if ms_link!=null:return bool(ms_link)
	if ready_hand(gs,owner)>=0 or not gs.pending_choice.is_empty():return false
	var inst:Dictionary=gs.card_instance(owner,index)
	if inst.is_empty() or inst.get("twoFacesFromDeck",false):return false
	var card:Dictionary=Content.card_def(str(inst.definitionId));var pool:=candidates(gs,owner,card)
	if inst.get("zenOrigin", false):
		card = gs.VerifiedRules.ZenMisfortune.describe(gs, owner, inst, card)
		pool = candidates(gs, owner, card)
	if pool.is_empty():return false
	# A target is chosen after the replacement. Check the original with any valid target.
	var view:Dictionary=gs.hand_card_def(owner,index);var targets:Array=[null] if view.get("target","auto")=="auto" else gs.valid_targets(owner,view)
	if not targets.any(func(t):return gs.can_play_card(owner,index,t).ok):return false
	if card.get("unitId") == gs.VerifiedRules.ZenMisfortune.ZEN:
		return start_zen(gs, owner, index, inst, pool)
	var other:Dictionary=pool[int(gs.next_random()%pool.size())].duplicate(true)
	var src:int=gs._source_index(owner,card)
	var opts:Array=[inst.duplicate(true),other]
	for option in opts:
		option.linkedUse=true;option.linkedByUid=gs.player(owner).units[src].uid
		option.linkRetrieve=gs.VerifiedRules.BlackWhite.link_retrieve(gs,owner,src)
		option.linkOtherId=other.instanceId if option.instanceId==inst.instanceId else inst.instanceId
	gs.pending_choice={"type":"native-link","playerIndex":owner,"hand":index,"original":inst.duplicate(true),"candidate":other,"options":opts,"instanceIds":opts.map(func(i):return str(i.instanceId)),"originFromDeck":index>=gs.player(owner).hand.size(),"heading":"连 引","title":"选择本次使用的牌，再选择目标","hint":"仅使用所选的一张；另一张洗回牌库。两张均视为连引使用。"}
	gs.phase="choice";gs.state_changed.emit();return true
static func option_ready(choice: Dictionary, selected: Dictionary) -> Dictionary:
	if choice.get("msLink",false):return preload("res://scripts/mirror_song_rules.gd").ready(choice,selected)
	if choice.get("zenLink", false):
		return {"hand":choice.hand,"selected":selected.duplicate(true),"original":choice.original.duplicate(true),"zenLinkedCards":choice.zenLinkedCards.duplicate(true)}
	return {"hand":choice.hand,"selected":selected.duplicate(true),"original":choice.original.duplicate(true),"candidate":choice.candidate.duplicate(true),"originFromDeck":choice.originFromDeck}
static func option_check(gs, owner: int, iid: String) -> Dictionary:
	var choice:Dictionary=gs.pending_choice
	if choice.get("type")!="native-link" or int(choice.playerIndex)!=owner:return {"ok":false}
	for option in choice.options:
		if str(option.instanceId)!=iid:continue
		var p:Dictionary=gs.player(owner);var old:Dictionary=p.get("linkReady",{});p.linkReady=option_ready(choice,option);gs.pending_choice={}
		var card:Dictionary=gs.hand_card_def(owner,int(choice.hand));var targets:Array=[null] if card.get("target","auto")=="auto" else gs.valid_targets(owner,card);var result:Dictionary={"ok":false,"reason":"没有合法目标"}
		for target in targets:
			result=gs.can_play_card(owner,int(choice.hand),target)
			if result.ok:break
		gs.pending_choice=choice
		if old.is_empty():p.erase("linkReady")
		else:p.linkReady=old
		result.view=card;return result
	return {"ok":false}
static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type")!="native-link":return null
	var result:=option_check(gs,owner,iid);var c:Dictionary=result.get("view",{}).duplicate(true)
	c.choiceDisabled=not result.ok
	c.choiceExplanation="选此牌，随后选目标" if result.ok else str(result.get("reason","当前不可用"))
	if not gs.pending_choice.get("msLink",false) and not gs.pending_choice.get("zenLink",false):c.erase("currentCardStats")
	return c
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	if not option_check(gs,owner,iid).get("ok",false):return false
	var choice:Dictionary=gs.pending_choice
	for option in choice.options:
		if str(option.instanceId)==iid:
			gs.player(owner).linkReady=option_ready(choice,option);gs.pending_choice={};gs.phase="main";gs.state_changed.emit();return true
	return false
static func take(gs, owner: int, index: int):
	var ms_taken=gs.VerifiedRules.MirrorSong.take_link(gs,owner,index)
	if ms_taken!=null:return ms_taken
	var p:Dictionary=gs.player(owner);var ready:Dictionary=p.get("linkReady",{})
	if index==int(ready.get("hand",-1)):
		var selected:Dictionary=ready.selected;var original:Dictionary=ready.original
		if ready.has("zenLinkedCards"): return take_zen(gs, owner, index, ready)
		if ready.originFromDeck:
			p.deck=p.deck.filter(func(i):return i.instanceId!=original.instanceId)
		else:p.hand.remove_at(index)
		if selected.instanceId!=original.instanceId:
			p.deck=p.deck.filter(func(i):return i.instanceId!=selected.instanceId);p.deck.append(original)
		gs._shuffle(p.deck);p.erase("linkReady")
		gs.VerifiedRules.event(gs,"link-used",{"player":owner,"uid":selected.linkedByUid,"card":str(selected.definitionId),"other":str(selected.linkOtherId)})
		gs.VerifiedRules.MirrorSong.link_taken(gs,owner)
		return selected
	var virtual=virtual_instance(gs,owner,index)
	if virtual!=null and virtual.get("twoFacesFromDeck",false):
		p.deck=p.deck.filter(func(i):return i.instanceId!=virtual.instanceId);p.twoFacesDeckFreeTurn=gs.turn_counter
		return virtual
	return null
static func completed(gs, owner: int, card: Dictionary) -> void:
	if card.get("msLinked",false):gs.VerifiedRules.MirrorSong.link_completed(gs,owner,card);return
	if not card.get("linkedUse",false) or not card.has("linkOtherId"):return
	var p:Dictionary=gs.player(owner);var iid:=str(card.linkOtherId)
	if card.get("linkRetrieve",false):
		for index in p.deck.size():
			if str(p.deck[index].instanceId)==iid:
				var inst:Dictionary=p.deck.pop_at(index)
				if p.hand.size()<int(gs.rules.maxHandSize):p.hand.append(inst)
				gs.VerifiedRules.event(gs,"link-retrieved",{"player":owner,"uid":str(card.linkedByUid),"instanceId":iid});break
	gs.VerifiedRules.TwoFaces.link_completed(gs,owner,iid)
static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="native-link":return null
	if int(gs.pending_choice.playerIndex)!=owner:return false
	var best:="";var best_score:=-100000
	for iid in gs.pending_choice.instanceIds:
		var check:=option_check(gs,owner,str(iid))
		if not check.get("ok",false):continue
		var c:Dictionary=check.view;var score:=int(c.get("level",1))*4
		if c.type=="awakening" or str(c.id) in ["c23803","c24006","c24107"]:score+=4
		if score>best_score:best_score=score;best=str(iid)
	return resolve_choice(gs,owner,best) if best!="" else false
static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.has("linkOtherId") or frame.get("automatic",false):return
	for index in gs.resolution_stack.size():
		if gs.resolution_stack[index].get("kind")=="card-complete" and gs.resolution_stack[index].get("resolutionId")==frame.resolutionId:
			gs.resolution_stack.insert(index,{"kind":"link-finished","playerIndex":int(frame.playerIndex),"card":card.duplicate(true)})
			return
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="link-finished":return false
	completed(gs,int(frame.playerIndex),frame.card);return true

static func start_zen(gs, owner: int, index: int, inst: Dictionary, pool: Array) -> bool:
	var src: int = gs.VerifiedRules.ZenMisfortune.source_for_link(gs, owner)
	var picks: Array = gs.VerifiedRules.ZenMisfortune.sample_links(gs, owner, src, pool)
	var original := inst.duplicate(true)
	original.zenLinked = true
	var options := [original]
	for option in picks:
		var linked: Dictionary = option.duplicate(true)
		linked.zenLinked = true
		linked.linkVirtual = true
		options.append(linked)
	gs.pending_choice = {"type":"native-link","playerIndex":owner,"hand":index,"original":original,"options":options,
		"zenLink":true,"zenLinkedCards":picks,"instanceIds":options.map(func(i): return str(i.instanceId)),
		"heading":"连引","title":"选择本次使用的牌","hint":"本次仅使用一张。连引牌的阴阳效果分别结算。"}
	gs.phase = "choice"
	gs.state_changed.emit()
	return true

static func take_zen(gs, owner: int, index: int, ready: Dictionary) -> Dictionary:
	var p: Dictionary = gs.player(owner)
	var selected: Dictionary = ready.selected
	var original: Dictionary = p.hand.pop_at(index)
	if selected.instanceId != original.instanceId:
		p.deck = p.deck.filter(func(i): return i.instanceId != selected.instanceId)
		p.deck.append(original)
	gs._shuffle(p.deck)
	p.erase("linkReady")
	gs.VerifiedRules.ZenMisfortune.links_resolved(gs, owner, gs.VerifiedRules.ZenMisfortune.source_for_link(gs, owner), ready.zenLinkedCards)
	gs.VerifiedRules.event(gs, "link-used", {"player":owner,"card":str(selected.definitionId),"other":"zen"})
	return selected
