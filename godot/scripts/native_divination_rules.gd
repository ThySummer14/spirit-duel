class_name NativeDivinationRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")
const TOP := "divination-place-top"
const BOTTOM := "divination-place-bottom"

static func start(gs, owner: int, count: int, controller: int = -1, context: Dictionary = {}) -> void:
	if controller < 0: controller = owner
	if controller != gs.current_player or count <= 0 or gs.player(owner).deck.is_empty(): return
	gs.VerifiedRules.Luohou.divining(gs, owner, controller)
	count += gs.VerifiedRules.Eye.bonus(gs, controller)
	count=gs.VerifiedRules.Baize.prepare_divination(gs,owner,count,controller)
	var ids: Array = []
	var deck: Array = gs.player(owner).deck
	for i in range(deck.size() - 1, maxi(-1, deck.size() - count - 1), -1): ids.append(str(deck[i].instanceId))
	gs.pending_choice = {"type": "native-divination", "playerIndex": controller, "zoneOwner": owner, "count": ids.size(), "remaining": ids.duplicate(), "originalIds": ids.duplicate(), "top": [], "bottom": [], "instanceIds": ids.duplicate(), "heading": "占 卜 · 敌 方 牌 库" if owner != controller else "占 卜", "title": "占卜 · 安排牌库顶与底", "hint": "选择一张牌，再决定置顶或置底；先置顶的先抽到，先置底的沉得更深。"}
	gs.pending_choice.merge(context,true)
	gs.pending_choice.hint+= " 至少置底%d张。"%int(context.minimumBottom) if int(context.get("minimumBottom",0))>0 else ""
	gs.VerifiedRules.Baize.revealed(gs,owner,ids,controller)
	gs.phase = "choice"

static func instance(gs, owner: int, iid: String) -> Dictionary:
	for inst in gs.player(owner).deck:
		if str(inst.instanceId) == iid: return inst
	return {}

static func choice_card(gs, owner: int, iid: String):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "native-divination" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return null
	owner = int(choice.get("zoneOwner", owner))
	if iid in [TOP, BOTTOM]:
		var source: Dictionary = instance(gs, owner, str(choice.selected))
		var view: Dictionary = ContentLoader.card_def(str(source.definitionId)).duplicate(true)
		view.id = iid
		view.name = "置于牌库顶" if iid == TOP else "置于牌库底"
		view.typeLabel = "占卜选择"
		view.text = "先选择置顶的牌先抽到。" if iid == TOP else "先选择置底的牌位于更深处。"
		return view
	var source: Dictionary = instance(gs, owner, iid)
	if source.is_empty(): return {}
	var view: Dictionary = gs.VerifiedRules.Eye.describe_card(gs, owner, source, ContentLoader.card_def(str(source.definitionId)))
	view = gs.VerifiedRules.BondDream.describe_card(gs, owner, source, view)
	return gs.VerifiedRules.BaizeYuanqi.describe(gs, owner, source, view)

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "native-divination" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	var deck_owner := int(choice.get("zoneOwner", owner))
	if iid not in [TOP, BOTTOM]:
		if instance(gs, deck_owner, iid).is_empty(): return false
		choice.selected = iid
		var required: int=mini(int(choice.get("minimumBottom",0)),int(choice.count))-choice.bottom.size()
		choice.instanceIds = [BOTTOM] if choice.remaining.size()<=required else [TOP, BOTTOM]
		choice.hint = "为「%s」选择位置 · 已置顶%d张 / 置底%d张" % [ContentLoader.card_def(str(instance(gs, deck_owner, iid).definitionId)).name, choice.top.size(), choice.bottom.size()]
		if TOP not in choice.instanceIds: choice.hint+=" · 至少置底%d张，本张必须置底"%int(choice.minimumBottom)
	else:
		var selected := str(choice.selected)
		choice["top" if iid == TOP else "bottom"].append(selected)
		choice.remaining.erase(selected)
		gs._record("resolve_divination_choice", {"instanceId": selected, "card": instance(gs, deck_owner, selected).definitionId, "choice": "native-divination", "placement": "top" if iid == TOP else "bottom"}, owner)
		choice.erase("selected")
		if choice.remaining.is_empty():
			var deck: Array = []
			for id in choice.bottom: deck.append(instance(gs, deck_owner, str(id)))
			for inst in gs.player(deck_owner).deck:
				if str(inst.instanceId) not in choice.originalIds: deck.append(inst)
			var top: Array = choice.top.duplicate()
			top.reverse()
			for id in top: deck.append(instance(gs, deck_owner, str(id)))
			gs.player(deck_owner).deck = deck
			gs.pending_choice = {}
			gs.phase = "main"
			gs.VerifiedRules.River.divined(gs, owner)
			gs.VerifiedRules.Eye.divined(gs, owner, int(choice.count))
			gs.VerifiedRules.Baize.completed(gs,choice)
			gs.VerifiedRules.TwinSight.divined(gs, owner)
			gs.VerifiedRules.BaizeYuanqi.divined(gs, choice)
			gs.VerifiedRules.event(gs, "divination-completed", {"player": owner, "top": choice.top.duplicate(), "bottom": choice.bottom.duplicate()})
			gs._resolve_resolution_stack()
		else:
			choice.instanceIds = choice.remaining.duplicate()
			choice.hint = "剩余%d张 · 先置顶的先抽到，先置底的沉得更深。" % choice.remaining.size()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "native-divination": return null
	if int(choice.playerIndex) != owner: return false
	var deck_owner := int(choice.get("zoneOwner", owner))
	if choice.has("selected"):
		var card: Dictionary = ContentLoader.card_def(str(instance(gs, deck_owner, str(choice.selected)).definitionId))
		var src: int = gs._source_index(deck_owner, card)
		var prefer_top = gs.VerifiedRules.Luohou.prefer_divination(gs, owner, deck_owner, card)
		if prefer_top != null: return resolve_choice(gs, owner, TOP if prefer_top and TOP in choice.instanceIds else BOTTOM)
		var usable: bool = src >= 0 and int(gs.player(deck_owner).units[src].hp) > 0 and int(gs.player(deck_owner).units[src].level) >= int(card.level)
		if choice.get("luohouOpponent", false): usable = not usable
		return resolve_choice(gs, owner, BOTTOM if TOP not in choice.instanceIds or gs.VerifiedRules.Baize.prefer_bottom(gs,deck_owner,card) or gs.VerifiedRules.BaizeYuanqi.prefer_bottom(gs, owner, deck_owner, card) or not usable else TOP)
	var best := str(choice.instanceIds[0])
	var score := -999
	for iid in choice.instanceIds:
		var card: Dictionary = ContentLoader.card_def(str(instance(gs, deck_owner, str(iid)).definitionId))
		var src: int = gs._source_index(deck_owner, card)
		var current := int(card.level) + (10 if src >= 0 and int(gs.player(deck_owner).units[src].hp) > 0 and int(gs.player(deck_owner).units[src].level) >= int(card.level) else 0)
		if current > score:
			score = current
			best = str(iid)
	return resolve_choice(gs, owner, best)
