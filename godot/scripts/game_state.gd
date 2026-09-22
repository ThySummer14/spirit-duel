class_name GameState
extends RefCounted
## Pure rules for the vertical slice. No UI. Seeded RNG + command log for replay.

const ContentLoader := preload("res://scripts/content_loader.gd")

signal log_emitted(text: String, tone: String)
signal state_changed
signal match_finished(winner: int)

const TONE_NEUTRAL := "neutral"
const TONE_TURN := "turn"
const TONE_CARD := "card"
const TONE_DANGER := "danger"
const TONE_SUCCESS := "success"

var seed: int = 0
var rng_state: int = 0
var turn_counter: int = 1
var current_player: int = 0
var winner: int = -1
var log: Array = []
var command_log: Array = []
var players: Array = []
var next_card_id: int = 1
var rules: Dictionary = {}
var _pending_form_reminders: Array = []
var resolution_stack: Array = []
var response_window: Dictionary = {}
var is_resolving: bool = false
var next_resolution_id: int = 1
var phase: String = "main"
var pending_choice: Dictionary = {}
const MAX_RESOLUTION_STACK_LENGTH := 64
const MAX_RESPONSE_DEPTH := 8


static func create(lineup_a: Array, lineup_b: Array, p_seed: int = 0, deck_a: Dictionary = {}, deck_b: Dictionary = {}) -> GameState:
	var gs := GameState.new()
	gs.rules = ContentLoader.rules()
	gs.seed = p_seed if p_seed != 0 else (Time.get_unix_time_from_system() as int) & 0x7fffffff
	gs.rng_state = gs.seed if gs.seed != 0 else 1
	var deck0: Dictionary = deck_a if not deck_a.is_empty() else ContentLoader.default_deck(lineup_a)
	var deck1: Dictionary = deck_b if not deck_b.is_empty() else ContentLoader.default_deck(lineup_b)
	gs.players = [
		gs._create_player("player", "巡界者", deck0),
		gs._create_player("ai", "失序体", deck1),
	]
	for p in gs.players:
		if not p.units.is_empty():
			p.units[0].level = 1
	gs._draw(0, int(gs.rules.openingHandSize) - 1)
	gs._draw(1, int(gs.rules.openingHandSize) - 1)
	gs._begin_turn(0)
	gs._log("灵契编成已锁定，对局开始。", TONE_TURN)
	gs.state_changed.emit()
	return gs


func next_random() -> int:
	# LCG 与浏览器 game-core.js nextRandom 对齐（双实现对拍）
	rng_state = (rng_state * 1664525 + 1013904223) & 0xffffffff
	return rng_state


func randf01() -> float:
	return float(next_random()) / 4294967296.0


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := int(floor(randf01() * float(i + 1)))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _log(text: String, tone: String = TONE_NEUTRAL) -> void:
	log.append({"text": text, "tone": tone, "turn": turn_counter})
	if log.size() > 400:
		log.resize(400)
	log_emitted.emit(text, tone)


func _record(cmd: String, args: Dictionary) -> void:
	command_log.append({
		"t": turn_counter,
		"p": current_player,
		"c": cmd,
		"a": args,
		"r": rng_state,
	})


func get_round() -> int:
	return ceili(float(turn_counter) / 2.0)


func player(idx: int) -> Dictionary:
	return players[idx]


func enemy_index(idx: int) -> int:
	return 1 - idx


func front_index(idx: int) -> int:
	var p := player(idx)
	for i in p.units.size():
		var u: Dictionary = p.units[i]
		if int(u.get("front", 0)) == 1 and int(u.hp) > 0:
			return i
	return -1


func front_unit(idx: int) -> Dictionary:
	var fi := front_index(idx)
	return player(idx).units[fi] if fi >= 0 else {}


func kw_usage(p_idx: int, key: String) -> Dictionary:
	var p := player(p_idx)
	if not p.has("keywordUsage") or not (p.keywordUsage is Dictionary):
		p["keywordUsage"] = {}
	if not p.keywordUsage.has(key) or not (p.keywordUsage[key] is Dictionary):
		p.keywordUsage[key] = {}
	return p.keywordUsage[key]


func start_divination(p_idx: int, card: Dictionary, frame: Dictionary) -> void:
	var p := player(p_idx)
	var cfg = card.get("divination", {})
	var want := 3
	if cfg is Dictionary and cfg.has("count"):
		want = int(cfg.count)
	# 牌库顶 = 数组末尾（与 JS deck.slice(-count) / pop 一致）
	var count: int = mini(want, p.deck.size())
	if count <= 0:
		return
	var ids: Array = []
	for i in range(p.deck.size() - count, p.deck.size()):
		ids.append(p.deck[i].get("instanceId"))
	pending_choice = {
		"type": "divination",
		"playerIndex": p_idx,
		"resolutionId": int(frame.get("resolutionId", -1)),
		"definitionId": str(card.get("id", "")),
		"instanceIds": ids,
	}
	phase = "choice"
	_log("%s 正在占卜牌库顶的 %d 张牌。" % [p.name, ids.size()], TONE_CARD)


func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:
	if pending_choice.is_empty() or str(pending_choice.get("type", "")) != "divination":
		_log("当前没有可由你处理的占卜选择。", TONE_DANGER)
		return false
	if int(pending_choice.get("playerIndex", -1)) != p_idx:
		_log("当前没有可由你处理的占卜选择。", TONE_DANGER)
		return false
	var ids: Array = pending_choice.get("instanceIds", [])
	var p := player(p_idx)
	var deck_index := -1
	var chosen_id := instance_id
	if not (instance_id in ids):
		# 允许用 definitionId 指定展示中的牌（对拍中立命令）
		for iid in ids:
			for i in p.deck.size():
				if str(p.deck[i].get("instanceId", "")) == str(iid) and str(p.deck[i].get("definitionId", "")) == instance_id:
					deck_index = i
					chosen_id = str(iid)
					break
			if deck_index >= 0:
				break
		if deck_index < 0:
			_log("请选择占卜展示的卡牌。", TONE_DANGER)
			return false
	else:
		for i in p.deck.size():
			if str(p.deck[i].get("instanceId", "")) == instance_id:
				deck_index = i
				break
	if deck_index < 0:
		_log("占卜的卡牌已不在牌库中。", TONE_DANGER)
		return false
	var selected: Dictionary = p.deck[deck_index]
	p.deck.remove_at(deck_index)
	p.deck.append(selected)
	var def := ContentLoader.card_def(str(selected.get("definitionId", "")))
	_log("%s 将「%s」置于牌库顶。" % [p.name, def.get("name", selected.get("definitionId"))], TONE_SUCCESS)
	pending_choice = {}
	phase = "main"
	_resolve_resolution_stack()
	state_changed.emit()
	return true


func _roll_fortune(p_idx: int, card: Dictionary) -> bool:
	var cfg = card.get("fortune", {})
	if not (cfg is Dictionary) or not cfg.has("sides"):
		return true
	var sides := int(cfg.get("sides", 6))
	var threshold := int(cfg.get("threshold", 4))
	var roll := int(floor(randf01() * float(sides))) + 1
	var success := roll >= threshold
	kw_usage(p_idx, "fortune")["last"] = {"roll": roll, "sides": sides, "threshold": threshold, "success": success}
	_log("%s 的运势骰子为 %d/%d%s" % [player(p_idx).name, roll, sides, "，运势成功。" if success else "，未达成。"], TONE_CARD if success else TONE_NEUTRAL)
	return success


func _fortune_success(p_idx: int) -> bool:
	var last = kw_usage(p_idx, "fortune").get("last")
	if last is Dictionary:
		return bool(last.get("success", false))
	return false


func _apply_encourage(p_idx: int, attack: int, shield: int) -> void:
	var usage := kw_usage(p_idx, "encourage")
	usage["attack"] = int(usage.get("attack", 0)) + attack
	usage["shield"] = int(usage.get("shield", 0)) + shield
	_log("%s 鼓舞累积 +%d攻/+%d甲。" % [player(p_idx).name, attack, shield], TONE_SUCCESS)


func _prepare_encourage(p_idx: int) -> Dictionary:
	var usage := kw_usage(p_idx, "encourage")
	var attack := int(usage.get("attack", 0))
	var shield := int(usage.get("shield", 0))
	if attack <= 0 and shield <= 0:
		return {"attack": 0, "shield": 0, "active": false}
	# 消耗全部鼓舞（与 JS consumeCombatActivation 一致）
	usage["attack"] = 0
	usage["shield"] = 0
	_log("%s 出击鼓舞生效 +%d攻/+%d甲。" % [player(p_idx).name, attack, shield], TONE_SUCCESS)
	return {"attack": attack, "shield": shield, "active": true}


func _pay_charge_cost(p_idx: int, src: int, card: Dictionary) -> bool:
	if not card.has("chargeCost"):
		return true
	var need := int(card.get("chargeCost", 0))
	var u: Dictionary = player(p_idx).units[src]
	var have := int(u.get("charge", 0))
	if have < need:
		_log("充能不足：需要 %d，%s 当前为 %d。" % [need, u.get("name"), have], TONE_DANGER)
		return false
	u.charge = have - need
	_log("%s 消耗 %d 点充能。" % [u.get("name"), need], TONE_SUCCESS)
	return true


func _create_player(pid: String, pname: String, deck_definition: Dictionary) -> Dictionary:
	var unit_ids: Array = deck_definition.get("unitIds", [])
	var units: Array = []
	for uid in unit_ids:
		var def := ContentLoader.unit_def(uid)
		if def.is_empty():
			continue
		units.append({
			"uid": "%s:%s" % [pid, uid],
			"id": uid,
			"name": def.get("name", uid),
			"title": def.get("title", ""),
			"color": def.get("color", "#8b93b8"),
			"baseAttack": int(def.get("attack", 1)),
			"baseMaxHp": int(def.get("maxHp", 8)),
			"attack": int(def.get("attack", 1)),
			"maxHp": int(def.get("maxHp", 8)),
			"hp": int(def.get("maxHp", 8)),
			"shield": 0,
			"knockout": 0,
			"frozen": 0,
			"brittle": 0,
			"unyielding": false,
			"level": 0,
			"front": 0,
			"attackBonus": 0,
			"maxHpBonus": 0,
			"awakened": false,
			"form": {},
			"formAbility": "",
			"charge": 0,
			"passive_hooks": def.get("passive", {}).get("hooks", []) if def.get("passive") is Dictionary else [],
		})
	var deck: Array = []
	for card_id in deck_definition.get("cardIds", []):
		deck.append({"instanceId": "%s-c%d" % [pid, next_card_id], "definitionId": card_id})
		next_card_id += 1
	_shuffle(deck)
	return {
		"id": pid,
		"name": pname,
		"avatarHp": int(rules.get("startingAvatarHp", 30)),
		"maxAvatarHp": int(rules.get("startingAvatarHp", 30)),
		"energy": 0,
		"maxEnergy": int(rules.get("maxEnergy", 2)),
		"deck": deck,
		"hand": [],
		"units": units,
		"attackUsed": false,
		"levelUpUsed": false,
		"bonusUpgrades": 0,
		"cardsPlayedThisTurn": 0,
		"realms": [],
		"keywordUsage": {},
	}


func _draw(p_idx: int, count: int) -> void:
	var p := player(p_idx)
	for _i in count:
		if p.deck.is_empty():
			if p.avatarHp > 0 and winner < 0:
				p.avatarHp = 0
				_log("%s 牌库耗尽，核心崩解。" % p.name, TONE_DANGER)
				_check_winner()
			return
		var card: Dictionary = p.deck.pop_back()
		p.hand.append(card)
		var def := ContentLoader.card_def(card.definitionId)
		_log("%s 抽到「%s」。" % [p.name, def.get("name", card.definitionId)], TONE_NEUTRAL)
		while p.hand.size() > int(rules.get("maxHandSize", 12)):
			var burned: Dictionary = p.hand.pop_front()
			var bdef := ContentLoader.card_def(burned.definitionId)
			_log("%s 手牌已满，「%s」被烧毁。" % [p.name, bdef.get("name", burned.definitionId)], TONE_DANGER)


func is_upgrade_pending(p_idx: int) -> bool:
	# 与 game-core.js isUpgradePending 对齐：仅存活角色、仅本回合尚未升勾时强制
	if winner >= 0 or current_player != p_idx:
		return false
	var p := player(p_idx)
	if p.levelUpUsed:
		return false
	for u in p.units:
		if int(u.hp) > 0 and int(u.level) < int(rules.get("maxUnitLevel", 3)):
			return true
	return false


func min_level(p_idx: int) -> int:
	var mn: int = 99
	for u in player(p_idx).units:
		mn = mini(mn, int(u.level))
	return mn


func can_level_up(p_idx: int, unit_index: int) -> bool:
	if winner >= 0 or current_player != p_idx:
		return false
	var p := player(p_idx)
	if unit_index < 0 or unit_index >= p.units.size():
		return false
	var u: Dictionary = p.units[unit_index]
	# 与 JS 对齐：气绝角色也可升勾，避免「最低勾在气绝角色上」卡死
	if int(u.level) >= int(rules.get("maxUnitLevel", 3)):
		return false
	if int(u.level) > min_level(p_idx):
		return false
	if p.levelUpUsed and int(p.bonusUpgrades) <= 0:
		return false
	return true


func level_up(p_idx: int, unit_index: int) -> bool:
	if not pending_choice.is_empty():
		_log("请先完成当前的占卜选择。", TONE_DANGER)
		return false
	if not response_window.is_empty():
		_log("请先处理当前响应窗口。", TONE_DANGER)
		return false
	if not can_level_up(p_idx, unit_index):
		return false
	_record("level_up", {"unit": unit_index})
	var p := player(p_idx)
	var u: Dictionary = p.units[unit_index]
	u.level = int(u.level) + 1
	if p.levelUpUsed:
		p.bonusUpgrades = int(p.bonusUpgrades) - 1
	else:
		p.levelUpUsed = true
	_log("%s 提升至 %d 勾玉。" % [u.name, int(u.level)], TONE_SUCCESS)
	state_changed.emit()
	return true


func hand_card_def(p_idx: int, hand_index: int) -> Dictionary:
	var p := player(p_idx)
	if hand_index < 0 or hand_index >= p.hand.size():
		return {}
	return ContentLoader.card_def(p.hand[hand_index].definitionId)


func _source_index(p_idx: int, card: Dictionary) -> int:
	var p := player(p_idx)
	for i in p.units.size():
		if p.units[i].id == card.get("unitId"):
			return i
	return -1


func valid_targets(p_idx: int, card: Dictionary) -> Array:
	var t: String = card.get("target", "auto")
	var own := player(p_idx)
	var foe := player(enemy_index(p_idx))
	var out: Array = []
	if t == "ally-unit":
		for i in own.units.size():
			var u: Dictionary = own.units[i]
			if int(u.hp) > 0 and int(u.level) >= 1:
				out.append(u.uid)
	elif t == "knocked-ally":
		for i in own.units.size():
			var u: Dictionary = own.units[i]
			if int(u.hp) <= 0 and int(u.level) >= 1:
				out.append(u.uid)
	elif t == "enemy-unit":
		for i in foe.units.size():
			var u: Dictionary = foe.units[i]
			if int(u.hp) > 0 and int(u.level) >= 1:
				out.append(u.uid)
	return out


func card_matches_response_window(card: Dictionary) -> bool:
	if response_window.is_empty():
		return false
	if str(card.get("timing", "main")) != "response":
		return false
	var to: Array = card.get("responseTo", []) if card.get("responseTo") is Array else []
	var action := str(response_window.get("action", ""))
	return action in to


func has_playable_response(p_idx: int) -> bool:
	for i in player(p_idx).hand.size():
		var card := ContentLoader.card_def(player(p_idx).hand[i].definitionId)
		if card.is_empty() or not card_matches_response_window(card):
			continue
		var check := can_play_card(p_idx, i, null)
		if check.ok:
			return true
	return false


func either_player_has_response() -> bool:
	var first := int(response_window.get("playerIndex", 0))
	if has_playable_response(first):
		return true
	response_window.playerIndex = 1 - first
	var other := has_playable_response(1 - first)
	response_window.playerIndex = first
	return other


func can_play_card(p_idx: int, hand_index: int, target_id: Variant = null) -> Dictionary:
	if winner >= 0:
		return {"ok": false, "reason": "对局已经结束。"}
	if not pending_choice.is_empty():
		return {"ok": false, "reason": "请先完成当前的占卜选择。"}
	if not response_window.is_empty():
		if int(response_window.get("playerIndex", -1)) != p_idx:
			return {"ok": false, "reason": "等待对手决定是否响应。"}
	elif current_player != p_idx:
		return {"ok": false, "reason": "等待对手完成行动。"}
	# 响应窗口中不走升勾门槛（对手回合 isUpgradePending 恒 false；己方窗口由 JS 语义同样放行响应牌）
	if response_window.is_empty() and is_upgrade_pending(p_idx):
		return {"ok": false, "reason": "升级阶段：请先选择一名角色提升勾玉。"}
	var p := player(p_idx)
	if hand_index < 0 or hand_index >= p.hand.size():
		return {"ok": false, "reason": "没有找到这张牌。"}
	var card := ContentLoader.card_def(p.hand[hand_index].definitionId)
	if card.is_empty():
		return {"ok": false, "reason": "未知卡牌。"}
	if not response_window.is_empty() and not card_matches_response_window(card):
		return {"ok": false, "reason": "响应窗口中只能使用符合触发条件的响应牌。"}
	var cost := int(card.get("cost", 0))
	if int(p.energy) < cost:
		return {"ok": false, "reason": "鬼火不足：需要 %d，当前 %d。" % [cost, int(p.energy)]}
	var src := _source_index(p_idx, card)
	if src < 0:
		return {"ok": false, "reason": "缺少所属角色。"}
	var su: Dictionary = p.units[src]
	if int(su.hp) <= 0:
		return {"ok": false, "reason": "%s 已气绝，无法使用其牌。" % su.name}
	if int(su.level) < int(card.get("level", 1)):
		return {"ok": false, "reason": "%s 勾玉不足，需要 %d 勾。" % [su.name, int(card.get("level", 1))]}
	if int(su.frozen) > 0 and card.get("type") == "combat":
		return {"ok": false, "reason": "%s 处于眩晕，无法发动战斗牌。" % su.name}
	if card.has("chargeCost") and int(su.get("charge", 0)) < int(card.get("chargeCost", 0)):
		return {"ok": false, "reason": "充能不足：需要 %d，%s 当前为 %d。" % [int(card.chargeCost), su.name, int(su.get("charge", 0))]}
	var t: String = card.get("target", "auto")
	if t != "auto":
		var opts := valid_targets(p_idx, card)
		if target_id == null or not opts.has(target_id):
			return {"ok": false, "reason": "请选择一个有效目标。"}
	return {"ok": true, "reason": "", "card": card, "source_index": src}


func play_card(p_idx: int, hand_index: int, target_id: Variant = null) -> bool:
	var check := can_play_card(p_idx, hand_index, target_id)
	if not check.ok:
		_log(str(check.reason), TONE_DANGER)
		return false
	var card: Dictionary = check.card
	var src: int = check.source_index
	var p := player(p_idx)
	var inst: Dictionary = p.hand[hand_index]
	var is_response := not response_window.is_empty()
	var response_depth := 0
	var response_ctx := response_window.duplicate(true)
	if is_response:
		response_depth = int(response_ctx.get("depth", 0)) + 1
	_record("play_card", {"hand": hand_index, "target": target_id, "card": inst.definitionId})
	p.energy = int(p.energy) - int(card.get("cost", 0))
	p.hand.remove_at(hand_index)
	p.cardsPlayedThisTurn = int(p.cardsPlayedThisTurn) + 1
	_log("%s 使用「%s」。" % [p.name, card.get("name", "?")], TONE_CARD)
	# 充能支付 / 运势投骰 / 卡面鼓舞（与 JS beforeCardResolution + applyEffect 对齐）
	if not _pay_charge_cost(p_idx, src, card):
		# 校验已挡；防御性回退
		pass
	if card.has("fortune"):
		_roll_fortune(p_idx, card)
	if card.get("encourage") is Dictionary:
		_apply_encourage(p_idx, int(card.encourage.get("attack", 0)), int(card.encourage.get("shield", 0)))
	_push_card_frames(p_idx, inst.definitionId, target_id, card, src, response_depth)
	if is_response:
		# 响应结算后，原帧重新开放响应（JS: previousFrame.responseOffered = false）
		var want_id := int(response_ctx.get("resolutionId", -1))
		for i in resolution_stack.size():
			var fr: Dictionary = resolution_stack[i]
			if int(fr.get("resolutionId", -1)) == want_id and str(fr.get("kind", "")) == "card-effect":
				resolution_stack[i].responseOffered = false
		response_window = {}
	_resolve_resolution_stack()
	_check_winner()
	state_changed.emit()
	return true


func pass_response(p_idx: int) -> bool:
	if not pending_choice.is_empty():
		_log("请先完成当前的占卜选择。", TONE_DANGER)
		return false
	if response_window.is_empty() or int(response_window.get("playerIndex", -1)) != p_idx:
		_log("当前没有可由你处理的响应窗口。", TONE_DANGER)
		return false
	_record("pass_response", {"player": p_idx})
	var passes := int(response_window.get("consecutivePasses", 0))
	if passes == 0:
		response_window.consecutivePasses = 1
		response_window.playerIndex = 1 - p_idx
		_log("%s 放弃响应，优先权转移。" % player(p_idx).name, TONE_NEUTRAL)
	else:
		response_window = {}
		phase = "main"
		_log("双方放弃响应，继续结算。", TONE_NEUTRAL)
		_resolve_resolution_stack()
	state_changed.emit()
	return true


func _card_matches_response(card: Dictionary) -> bool:
	return card_matches_response_window(card)


func _push_card_frames(p_idx: int, definition_id: String, target_id, card: Dictionary, src: int, response_depth: int) -> void:
	var rid := next_resolution_id
	next_resolution_id += 1
	var base := {
		"resolutionId": rid,
		"playerIndex": p_idx,
		"definitionId": definition_id,
		"targetId": target_id,
		"sourceIndex": src,
		"responseDepth": response_depth,
	}
	var effects := _effect_list(card)
	var complete := {
		"kind": "card-complete",
		"respondable": false,
		"responseOffered": false,
	}
	complete.merge(base, true)
	resolution_stack.append(complete)
	# LIFO：先压靠后的效果
	for i in range(effects.size() - 1, -1, -1):
		var fr := {
			"kind": "card-effect",
			"effectIndex": i,
			"respondable": i == 0 and response_depth < MAX_RESPONSE_DEPTH,
			"responseOffered": false,
		}
		fr.merge(base, true)
		resolution_stack.append(fr)
	if resolution_stack.size() > MAX_RESOLUTION_STACK_LENGTH:
		_log("结算栈超过安全上限。", TONE_DANGER)
		resolution_stack.clear()


func _create_response_window(frame: Dictionary) -> Dictionary:
	var card := ContentLoader.card_def(str(frame.get("definitionId", "")))
	var effects := _effect_list(card)
	var idx := int(frame.get("effectIndex", 0))
	var effect: Dictionary = effects[idx] if idx >= 0 and idx < effects.size() else {}
	return {
		"id": "response-%s-%s" % [frame.get("resolutionId"), frame.get("responseDepth")],
		"playerIndex": 1 - int(frame.get("playerIndex", 0)),
		"sourcePlayerIndex": int(frame.get("playerIndex", 0)),
		"resolutionId": int(frame.get("resolutionId", -1)),
		"definitionId": str(frame.get("definitionId", "")),
		"action": str(effect.get("action", "")),
		"target": str(effect.get("target", "")),
		"targetId": frame.get("targetId"),
		"consecutivePasses": 0,
		"depth": int(frame.get("responseDepth", 0)),
	}


func _resolve_resolution_stack() -> void:
	if is_resolving or not response_window.is_empty():
		return
	is_resolving = true
	while not resolution_stack.is_empty() and winner < 0:
		var frame: Dictionary = resolution_stack.back()
		if str(frame.get("kind", "")) == "card-effect" and bool(frame.get("respondable", false)) and not bool(frame.get("responseOffered", false)):
			frame.responseOffered = true
			resolution_stack[resolution_stack.size() - 1] = frame
			response_window = _create_response_window(frame)
			if either_player_has_response():
				phase = "response"
				_log("响应窗口开启：%s 可响应「%s」。" % [
					player(int(response_window.playerIndex)).name,
					str(response_window.action),
				], TONE_TURN)
				is_resolving = false
				return
			response_window = {}
		resolution_stack.pop_back()
		_resolve_frame(frame)
		if not pending_choice.is_empty():
			is_resolving = false
			return
	is_resolving = false
	if response_window.is_empty():
		phase = "main"


func _resolve_frame(frame: Dictionary) -> void:
	var p_idx := int(frame.get("playerIndex", 0))
	var card := ContentLoader.card_def(str(frame.get("definitionId", "")))
	var src := int(frame.get("sourceIndex", -1))
	if card.is_empty() or src < 0:
		return
	var target_id = frame.get("targetId")
	var target_unit := _unit_by_uid(_all_units(), target_id) if target_id != null else {}
	if str(frame.get("kind", "")) == "card-complete":
		if str(card.get("type", "")) == "form" and int(player(p_idx).units[src].get("hp", 0)) > 0:
			# 形态共鸣已在 _apply_form 内回满；此处补 card-played 钩子
			pass
		_fire_hooks(p_idx, src, "card-played", {"card": card, "cardType": str(card.get("type", ""))})
		_run_form_hooks(p_idx, src, "card-played", {"card": card, "cardType": str(card.get("type", ""))})
		return
	var effects := _effect_list(card)
	var idx := int(frame.get("effectIndex", 0))
	if idx < 0 or idx >= effects.size():
		return
	_resolve_one_effect(p_idx, src, card, effects[idx], target_id, target_unit)


func _resolve_one_effect(p_idx: int, src: int, card: Dictionary, effect: Dictionary, target_id, target_unit: Dictionary) -> void:
	var cond: String = str(effect.get("condition", "always"))
	if cond == "source-ready":
		var su: Dictionary = player(p_idx).units[src]
		if int(su.frozen) > 0:
			return
	elif cond == "target-alive":
		if target_unit.is_empty() or int(target_unit.get("hp", 0)) <= 0:
			return
	elif cond == "target-frozen":
		if target_unit.is_empty() or int(target_unit.get("frozen", 0)) <= 0:
			return
	elif cond == "fortune-success":
		if not _fortune_success(p_idx):
			return
	elif cond == "bestow-ready":
		pass
	elif cond == "match-active":
		if winner >= 0:
			return
	_resolve_action(p_idx, src, card, effect, target_id, target_unit)


func _all_units() -> Array:
	var out: Array = []
	for p in players:
		for u in p.units:
			out.append(u)
	return out


func _unit_by_uid(arr: Array, uid) -> Dictionary:
	for u in arr:
		if u.get("uid") == uid:
			return u
	return {}


func _unit_index_by_uid(p_idx: int, uid) -> int:
	var p := player(p_idx)
	for i in p.units.size():
		if p.units[i].uid == uid:
			return i
	return -1


func _effect_list(card: Dictionary) -> Array:
	var effects = card.get("effects")
	if effects is Array and effects.size() > 0:
		return effects
	var action = card.get("effect")
	if action == null:
		return []
	return [{
		"condition": "always",
		"action": action,
		"target": card.get("target", "auto"),
		"value": card.get("value"),
	}]


func _num(v) -> int:
	if v is int or v is float:
		return int(v)
	return 0


func _value_dict(v) -> Dictionary:
	return v if v is Dictionary else {}


func _resolve_card_effects(p_idx: int, src: int, card: Dictionary, target_id, target_unit: Dictionary) -> void:
	var effects := _effect_list(card)
	if effects.is_empty():
		_log("效果暂未完全结算", TONE_NEUTRAL)
		return
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var cond: String = effect.get("condition", "always")
		if cond == "source-ready":
			var su: Dictionary = player(p_idx).units[src]
			if int(su.frozen) > 0:
				continue
		elif cond == "target-alive":
			if target_unit.is_empty() or int(target_unit.get("hp", 0)) <= 0:
				continue
		elif cond == "target-frozen":
			if target_unit.is_empty() or int(target_unit.get("frozen", 0)) <= 0:
				continue
		elif cond == "match-active":
			pass
		elif cond == "fortune-success":
			# simplified: fortune auto-succeeds on even rng
			if next_random() % 2 == 0:
				continue
		elif cond == "bestow-ready":
			if int(player(p_idx).units[src].get("charge", 0)) < 2:
				continue
		_resolve_action(p_idx, src, card, effect, target_id, target_unit)


func _resolve_action(p_idx: int, src: int, card: Dictionary, effect: Dictionary, target_id, target_unit: Dictionary) -> void:
	var action: String = str(effect.get("action", ""))
	var value = effect.get("value", card.get("value"))
	var et: String = str(effect.get("target", card.get("target", "auto")))
	var p := player(p_idx)
	var e_idx := enemy_index(p_idx)
	var source: Dictionary = p.units[src]
	match action:
		"assault":
			var bonus := _num(value)
			var kws: Array = card.get("keywords", []) if card.get("keywords") is Array else []
			var has_kw := false
			for k in kws:
				if str(k).to_lower() in ["pierce", "remote", "combo", "first-strike", "crit"]:
					has_kw = true
					break
			if has_kw:
				_resolve_combat(p_idx, src, bonus, _kw(card, "pierce"), _kw(card, "remote"), _kw(card, "combo"), _kw(card, "first-strike"), target_id, _kw(card, "crit"))
			else:
				basic_attack_ex(p_idx, src, bonus, false, target_id)
		"damage":
			_apply_damage_action(p_idx, et, value, target_unit)
		"heal":
			for u in _ally_targets(p_idx, et, src, target_id, target_unit):
				_heal_unit(u, _num(value))
		"heal-avatar":
			_heal_avatar(p_idx, _num(value))
		"shield":
			for u in _ally_targets(p_idx, et, src, target_id, target_unit):
				u.shield = int(u.shield) + _num(value)
				_log("%s 获得 %d 点护盾。" % [u.name, _num(value)], TONE_SUCCESS)
		"fortify":
			# enter front + shield source
			source.front = 1
			for u in p.units:
				if u != source:
					u.front = 0
			source.shield = int(source.shield) + _num(value)
			_log("%s 进入前线并获得 %d 点护盾。" % [source.name, _num(value)], TONE_SUCCESS)
			_fire_hooks(p_idx, src, "unit-entered-front", {})
		"draw":
			_draw(p_idx, _num(value) if _num(value) > 0 else 1)
		"revive":
			for u in _ally_targets(p_idx, et, src, target_id, target_unit):
				if int(u.hp) <= 0:
					u.hp = int(u.maxHp)
					u.knockout = 0
					u.shield = 0
					u.front = 0
					_log("%s 被余辉唤回，恢复全部生命。" % u.name, TONE_SUCCESS)
				else:
					_heal_unit(u, _num(value))
		"freeze":
			for u in _enemy_targets(p_idx, et, target_unit):
				u.frozen = maxi(int(u.frozen), _num(value) if _num(value) > 0 else 1)
				_log("%s 陷入眩晕。" % u.name, TONE_CARD)
		"apply-brittle", "brittle":
			for u in _enemy_targets(p_idx, et, target_unit):
				if int(u.hp) > 0:
					u.brittle = maxi(int(u.brittle), _num(value) if _num(value) > 0 else 1)
					_log("%s 进入晶裂。" % u.name, TONE_CARD)
		"apply-keyword":
			var vd := _value_dict(value)
			var kid: String = str(vd.get("keywordId", "encourage"))
			if kid == "encourage":
				# 与 JS ENCOURAGE.applyEffect 对齐：累积到玩家鼓舞池，下次出击消耗
				_apply_encourage(p_idx, _num(vd.get("attack", 0)), _num(vd.get("shield", 0)))
			elif kid == "fusion":
				for u in _ally_targets(p_idx, et if et != "ally-player" and et != "source" else "source", src, target_id, target_unit):
					_grow_unit(u, _num(vd.get("attack", 0)), _num(vd.get("hp", 0)))
				_log("关键词「融合」生效。", TONE_SUCCESS)
			else:
				_log("效果暂未完全结算：%s" % kid, TONE_NEUTRAL)
		"grant-unyielding":
			for u in _ally_targets(p_idx, et, src, target_id, target_unit):
				u.unyielding = true
				_log("%s 获得不屈。" % u.name, TONE_SUCCESS)
		"damage-enemy-front":
			var fi: int = front_index(e_idx)
			if fi >= 0:
				_damage_unit(e_idx, fi, _num(value), p_idx)
			else:
				_damage_avatar(e_idx, _num(value), p_idx)
		"damage-enemy-avatar", "enemy-avatar":
			_damage_avatar(e_idx, _num(value), p_idx)
		"form":
			_apply_form(p_idx, src, card, _value_dict(value))
		"realm":
			_deploy_realm(p_idx, card)
		"awaken":
			_awaken(p_idx, src, card, _value_dict(value))
		"burn-all":
			for i in player(e_idx).units.size():
				var u: Dictionary = player(e_idx).units[i]
				if int(u.hp) > 0:
					_damage_unit(e_idx, i, _num(value), p_idx)
			_damage_avatar(e_idx, 2, p_idx)
		"remove-shield":
			for u in _enemy_targets(p_idx, et, target_unit):
				var removed := int(u.shield)
				u.shield = 0
				_log("%s 被碎甲，移除 %d 点护盾。" % [u.name, removed], TONE_CARD)
		"draw-heal":
			_draw(p_idx, _num(value) if _num(value) > 0 else 1)
			_heal_avatar(p_idx, 1)
		"focus-draw":
			if int(p.cardsPlayedThisTurn) <= 1:
				_draw(p_idx, _num(value) if _num(value) > 0 else 1)
			else:
				_log("专注未达成。", TONE_NEUTRAL)
		"chain-draw":
			var unit_id: String = card.get("unitId", "")
			var found: int = -1
			for i in p.deck.size():
				var ddef := ContentLoader.card_def(p.deck[i].definitionId)
				if ddef.get("unitId") == unit_id:
					found = i
					break
			if found >= 0:
				var inst: Dictionary = p.deck.pop_at(found)
				p.hand.append(inst)
				var idef := ContentLoader.card_def(inst.definitionId)
				_log("连引：将「%s」纳入手牌。" % idef.get("name", "?"), TONE_SUCCESS)
			else:
				_log("连引未果。", TONE_NEUTRAL)
		"origin-shuffle":
			var inst := {"instanceId": "%s-o%d" % [p.id, next_card_id], "definitionId": card.get("id")}
			next_card_id += 1
			var at: int = next_random() % (int(p.deck.size()) + 1)
			p.deck.insert(at, inst)
			_log("起源：一张「%s」回到牌库。" % card.get("name", "?"), TONE_SUCCESS)
		"cook-ingredient":
			_log("获得食材「%s」。" % str(value), TONE_SUCCESS)
		"attach-charge":
			var vd2 := _value_dict(value)
			source.charge = 0
			_log("%s 进入蓄力。" % source.name, TONE_CARD)
		"set-nightfall":
			_log("夜幕已预约。", TONE_CARD)
		"divination":
			start_divination(p_idx, card, {"resolutionId": next_resolution_id - 1})
		_:
			_log("效果暂未完全结算", TONE_NEUTRAL)


func _ally_targets(p_idx: int, et: String, src: int, target_id, target_unit: Dictionary) -> Array:
	var p := player(p_idx)
	if et == "source":
		return [p.units[src]]
	if et == "all-ally-units":
		return p.units.filter(func(u): return int(u.hp) > 0)
	if et == "all-other-allies":
		return p.units.filter(func(u): return int(u.hp) > 0 and u.uid != p.units[src].uid)
	if et == "ally-avatar":
		return []
	if target_id != null:
		var i := _unit_index_by_uid(p_idx, target_id)
		if i >= 0:
			return [p.units[i]]
	if not target_unit.is_empty():
		return [target_unit]
	return [p.units[src]]


func _enemy_targets(p_idx: int, et: String, target_unit: Dictionary) -> Array:
	var foe := player(enemy_index(p_idx))
	if et == "all-enemy-units":
		return foe.units.filter(func(u): return int(u.hp) > 0)
	if not target_unit.is_empty() and int(target_unit.get("hp", 0)) > 0:
		return [target_unit]
	return foe.units.filter(func(u): return int(u.hp) > 0)


func _apply_damage_action(p_idx: int, et: String, value, target_unit: Dictionary) -> void:
	var amount := _num(value)
	var e_idx := enemy_index(p_idx)
	if et == "all-enemy-units":
		var foe := player(e_idx)
		for i in foe.units.size():
			if int(foe.units[i].hp) > 0:
				_damage_unit(e_idx, i, amount, p_idx)
	elif et == "enemy-avatar" or et == "ally-avatar":
		_damage_avatar(e_idx, amount, p_idx)
	elif et == "enemy-front" or (et == "selected-enemy" and target_unit.is_empty()):
		var fi: int = front_index(e_idx)
		if fi >= 0:
			_damage_unit(e_idx, fi, amount, p_idx)
		else:
			_damage_avatar(e_idx, amount, p_idx)
	else:
		var idx := _unit_index_by_uid(e_idx, target_unit.get("uid", ""))
		if idx >= 0:
			_damage_unit(e_idx, idx, amount, p_idx)
		elif not target_unit.is_empty():
			# may be ally selected incorrectly — try own
			var aidx := _unit_index_by_uid(p_idx, target_unit.get("uid", ""))
			if aidx >= 0:
				_damage_unit(p_idx, aidx, amount, p_idx)


func _grow_unit(unit: Dictionary, atk: int, hp: int) -> void:
	unit.attackBonus = int(unit.attackBonus) + atk
	unit.maxHpBonus = int(unit.maxHpBonus) + hp
	_recalc(unit)
	if hp > 0:
		unit.hp = mini(int(unit.hp) + hp, int(unit.maxHp))
	unit.attack = int(unit.baseAttack) + int(unit.attackBonus) + int(unit.form.get("attackBonus", 0))
	unit.maxHp = int(unit.baseMaxHp) + int(unit.maxHpBonus) + int(unit.form.get("hpBonus", 0))


func _recalc(unit: Dictionary) -> void:
	var form: Dictionary = unit.get("form", {})
	unit.attack = int(unit.baseAttack) + int(unit.attackBonus) + int(form.get("attackBonus", 0))
	var new_max := int(unit.baseMaxHp) + int(unit.maxHpBonus) + int(form.get("hpBonus", 0))
	var gain := new_max - int(unit.maxHp)
	unit.maxHp = new_max
	if gain > 0 and int(unit.hp) > 0:
		unit.hp = mini(int(unit.hp) + gain, new_max)
	elif int(unit.hp) > new_max:
		unit.hp = new_max


func _apply_form(p_idx: int, src: int, card: Dictionary, value: Dictionary = {}) -> void:
	var u: Dictionary = player(p_idx).units[src]
	var v := value if not value.is_empty() else _value_dict(card.get("value"))
	var atk := _num(v.get("attack", 0))
	var hp := _num(v.get("hp", 0))
	var ability: String = str(card.get("formAbility", card.get("text", "")))
	u.form = {"attackBonus": atk, "hpBonus": hp, "name": card.get("name", "形态"), "cardId": card.get("id")}
	u.formAbility = ability
	u["formHooks"] = card.get("formHooks", []) if card.get("formHooks") is Array else []
	_recalc(u)
	if int(u.hp) > 0:
		u.hp = int(u.maxHp)
	_log("%s 化作「%s」（+%d攻/+%d生命）。" % [u.name, card.get("name", "形态"), atk, hp], TONE_CARD)
	if ability != "":
		_log("形态提醒：%s" % ability, TONE_NEUTRAL)


func _awaken(p_idx: int, src: int, card: Dictionary, value: Dictionary) -> void:
	var p := player(p_idx)
	var u: Dictionary = p.units[src]
	if u.awakened:
		_log("%s 已经觉醒。" % u.name, TONE_NEUTRAL)
		return
	u.awakened = true
	_grow_unit(u, _num(value.get("attack", 1)), _num(value.get("hp", 1)))
	if value.get("grantUnyielding", false):
		u.unyielding = true
	var def := ContentLoader.unit_def(u.id)
	u.passive_hooks = def.get("awakenedPassive", {}).get("hooks", []) if def.get("awakenedPassive") is Dictionary else u.passive_hooks
	_log("%s 觉醒！" % u.name, TONE_SUCCESS)


func _deploy_realm(p_idx: int, card: Dictionary) -> void:
	var realm = card.get("realm", {})
	if not (realm is Dictionary):
		realm = {}
	var p := player(p_idx)
	p.realms.append({
		"uid": "realm-%s-%d" % [p.id, p.realms.size()],
		"cardId": card.get("id"),
		"name": card.get("name", "幻境"),
		"hp": _num(realm.get("hp", 3)),
		"trigger": str(realm.get("trigger", "owner-turn-start")),
		"triggerEffect": str(realm.get("triggerEffect", "")),
		"triggerValue": realm.get("triggerValue", 0),
		"triggerEffects": realm.get("triggerEffects", []),
		"countdown": _num(realm.get("countdown", 0)),
		"countdownReset": _num(realm.get("countdownReset", 0)),
	})
	_log("%s 部署幻境「%s」。" % [p.name, card.get("name", "?")], TONE_CARD)
	_fire_hooks(p_idx, -1, "realm-deployed", {})


func _heal_unit(unit: Dictionary, amount: int) -> void:
	if int(unit.hp) <= 0 or amount <= 0:
		return
	var healed := mini(amount, int(unit.maxHp) - int(unit.hp))
	if healed <= 0:
		return
	unit.hp = int(unit.hp) + healed
	_log("%s 恢复 %d 点生命。" % [unit.name, healed], TONE_SUCCESS)


func _heal_avatar(p_idx: int, amount: int) -> void:
	var p := player(p_idx)
	if amount <= 0:
		return
	var healed := mini(amount, int(p.maxAvatarHp) - int(p.avatarHp))
	if healed <= 0:
		return
	p.avatarHp = int(p.avatarHp) + healed
	_log("%s 的核心恢复 %d 点生命。" % [p.name, healed], TONE_SUCCESS)


func _damage_unit(p_idx: int, unit_index: int, amount: int, _src_player: int) -> Dictionary:
	# 与 game-core.js damageUnit 对齐：气绝不在此处额外打核心（由出击结算 +1）
	var p := player(p_idx)
	if unit_index < 0 or unit_index >= p.units.size():
		return {"damage": 0, "knocked": false, "overkill": 0}
	var u: Dictionary = p.units[unit_index]
	if int(u.hp) <= 0 or amount <= 0:
		return {"damage": 0, "knocked": false, "overkill": 0}
	var dmg := amount
	if int(u.brittle) > 0:
		dmg += 1
		u.brittle = int(u.brittle) - 1
	var absorbed := mini(int(u.shield), dmg)
	u.shield = int(u.shield) - absorbed
	var unshielded := dmg - absorbed
	var unyielding_save: bool = u.unyielding and int(u.hp) > 1 and unshielded >= int(u.hp)
	var effective: int = (int(u.hp) - 1) if unyielding_save else unshielded
	var taken: int = mini(int(u.hp), maxi(0, effective))
	var overkill: int = maxi(0, unshielded - int(u.hp))
	u.hp = maxi(0, int(u.hp) - taken)
	if unyielding_save:
		_log("%s 的不屈抵住致命伤。" % u.name, TONE_SUCCESS)
	elif taken > 0:
		_log("%s 受到 %d 点伤害%s。" % [u.name, taken, ("，护盾抵消 %d 点" % absorbed) if absorbed > 0 else ""], TONE_DANGER)
	elif absorbed > 0:
		_log("%s 的护盾抵消了伤害。" % u.name, TONE_NEUTRAL)
	var knocked := false
	if int(u.hp) <= 0:
		knocked = true
		u.front = 0
		u.knockout = int(rules.get("knockoutCountdown", 2))
		u.shield = 0
		u.frozen = 0
		u.brittle = 0
		_log("%s 气绝，将在 %d 个己方回合后归队。" % [u.name, int(u.knockout)], TONE_DANGER)
	return {"damage": taken, "knocked": knocked, "overkill": overkill}


func _damage_avatar(p_idx: int, amount: int, _src_player: int = -1) -> void:
	var p := player(p_idx)
	if amount <= 0 or winner >= 0:
		return
	p.avatarHp = maxi(0, int(p.avatarHp) - amount)
	_log("%s 的核心受到 %d 点伤害。" % [p.name, amount], TONE_DANGER)
	_check_winner()


func _check_winner() -> void:
	if winner >= 0:
		return
	for i in players.size():
		if int(player(i).avatarHp) <= 0:
			winner = 1 - i
			_log("%s 稳定了界碑核心。" % player(winner).name, TONE_SUCCESS)
			match_finished.emit(winner)
			return


func can_basic_attack(p_idx: int, unit_index: int) -> Dictionary:
	if winner >= 0 or current_player != p_idx:
		return {"ok": false, "reason": "现在不是你的行动阶段。"}
	if is_upgrade_pending(p_idx):
		return {"ok": false, "reason": "升级阶段：请先选择一名角色提升勾玉。"}
	var p := player(p_idx)
	if p.attackUsed:
		return {"ok": false, "reason": "本回合已经出击过。"}
	if int(p.energy) < 1:
		return {"ok": false, "reason": "鬼火不足。"}
	if unit_index < 0 or unit_index >= p.units.size():
		return {"ok": false, "reason": "该角色无法出击。"}
	var u: Dictionary = p.units[unit_index]
	if int(u.hp) <= 0:
		return {"ok": false, "reason": "该角色无法出击。"}
	if int(u.frozen) > 0:
		return {"ok": false, "reason": "该角色正处于眩晕状态。"}
	if int(u.level) < 1:
		return {"ok": false, "reason": "%s 尚未激活（0 勾）。" % u.name}
	return {"ok": true, "reason": ""}


func basic_attack(p_idx: int, unit_index: int, target_id = null) -> bool:
	if not pending_choice.is_empty():
		_log("请先完成当前的占卜选择。", TONE_DANGER)
		return false
	if not response_window.is_empty():
		_log("请先处理当前响应窗口。", TONE_DANGER)
		return false
	var check := can_basic_attack(p_idx, unit_index)
	if not check.ok:
		_log(str(check.reason), TONE_DANGER)
		return false
	var p := player(p_idx)
	p.energy = int(p.energy) - 1
	p.attackUsed = true
	_record("basic_attack", {"unit": unit_index, "target": target_id})
	_resolve_combat(p_idx, unit_index, 0, false, false, false, false, target_id)
	_check_winner()
	state_changed.emit()
	return true


func basic_attack_ex(p_idx: int, unit_index: int, bonus: int, uses_action: bool, target_id = null) -> void:
	# combat card assault — free attack (already paid card cost), grants attack bonus
	if unit_index < 0 or int(player(p_idx).units[unit_index].hp) <= 0:
		return
	if uses_action:
		player(p_idx).attackUsed = true
	_record("assault", {"unit": unit_index, "bonus": bonus, "target": target_id})
	_resolve_combat(p_idx, unit_index, bonus, false, false, false, false, target_id)


func _kw(card: Dictionary, key: String) -> bool:
	var kws = card.get("keywords", [])
	if not (kws is Array):
		return false
	for k in kws:
		if str(k).to_lower() == key:
			return true
	return false


func _resolve_combat(p_idx: int, unit_index: int, bonus: int, pierce: bool, remote: bool, combo: bool, first_strike: bool, target_id = null, crit: bool = false) -> void:
	var p := player(p_idx)
	var e_idx := enemy_index(p_idx)
	var foe := player(e_idx)
	var attacker: Dictionary = p.units[unit_index]
	if int(attacker.hp) <= 0:
		return
	# enter front（远程不改前线）
	var was_front := int(attacker.front) == 1
	var entered_from_reserve := (not remote) and not was_front
	if not remote:
		attacker.front = 1
		for u in p.units:
			if u != attacker:
				u.front = 0
		if entered_from_reserve:
			_log("%s 从准备区进入前线。" % attacker.name, TONE_TURN)
			_fire_hooks(p_idx, unit_index, "unit-entered-front", {})
			_run_form_hooks(p_idx, unit_index, "unit-entered-front", {})
	var enc := _prepare_encourage(p_idx)
	var base_power := int(attacker.attack) + bonus + int(enc.get("attack", 0))
	if int(enc.get("shield", 0)) > 0:
		attacker.shield = int(attacker.shield) + int(enc.shield)
	var power := base_power * 2 if crit else base_power
	var fi: int = front_index(e_idx)
	if fi < 0:
		_log("%s 突破空缺前线。" % attacker.name, TONE_SUCCESS)
		_damage_avatar(e_idx, power, p_idx)
		_fire_hooks(p_idx, unit_index, "combat-resolved", {"defender": null, "from_reserve": entered_from_reserve})
		_run_form_hooks(p_idx, unit_index, "combat-resolved", {"defender": null, "from_reserve": entered_from_reserve})
		return
	var defender: Dictionary = foe.units[fi]
	if remote:
		_log("%s 向 %s 发起远程出击。" % [attacker.name, defender.name], TONE_TURN)
	else:
		_log("%s 向 %s 发起出击。" % [attacker.name, defender.name], TONE_TURN)
	var result := _damage_unit(e_idx, fi, power, p_idx)
	var defender_down: bool = result.knocked
	# 贯通：溢出伤害转移核心
	if pierce and result.knocked and int(result.get("overkill", 0)) > 0 and winner < 0:
		_log("%s 的贯通对核心造成 %d 点伤害。" % [attacker.name, int(result.overkill)], TONE_DANGER)
		_damage_avatar(e_idx, int(result.overkill), p_idx)
	if result.knocked and winner < 0:
		_damage_avatar(e_idx, 1, p_idx)
	# 连击：目标仍存活时追加一次等量战斗伤害
	if combo and winner < 0 and int(defender.hp) > 0:
		var combo_result := _damage_unit(e_idx, fi, power, p_idx)
		defender_down = defender_down or combo_result.knocked
		if combo_result.knocked and winner < 0:
			_damage_avatar(e_idx, 1, p_idx)
	# 先攻：首次伤害即气绝则不反击
	# 与 JS 对齐：目标已气绝仍可反击（先攻除外），不要求 defender.hp > 0
	var counter_allowed := (not remote) and int(defender.frozen) == 0 and int(attacker.hp) > 0 and winner < 0
	if first_strike and defender_down:
		counter_allowed = false
	if counter_allowed and int(defender.attack) > 0:
		_damage_unit(p_idx, unit_index, int(defender.attack), e_idx)
	var ctx := {"defender": defender, "from_reserve": entered_from_reserve, "killed": defender_down}
	_fire_hooks(p_idx, unit_index, "combat-resolved", ctx)
	_run_form_hooks(p_idx, unit_index, "combat-resolved", ctx)


func _fire_hooks(p_idx: int, src: int, event: String, ctx: Dictionary) -> void:
	if src < 0:
		# global / player-level hooks for realm-deployed etc.
		for i in player(p_idx).units.size():
			var u: Dictionary = player(p_idx).units[i]
			if int(u.hp) > 0:
				_run_unit_hooks(p_idx, i, event, ctx)
		return
	_run_unit_hooks(p_idx, src, event, ctx)


func _fire_form_hooks(p_idx: int, src: int, event: String, ctx: Dictionary) -> void:
	if src < 0:
		for i in player(p_idx).units.size():
			_run_form_hooks(p_idx, i, event, ctx)
		return
	_run_form_hooks(p_idx, src, event, ctx)


func _run_form_hooks(p_idx: int, unit_index: int, event: String, ctx: Dictionary) -> void:
	var u: Dictionary = player(p_idx).units[unit_index]
	var hooks: Array = u.get("formHooks", [])
	if hooks.is_empty():
		return
	for hook in hooks:
		if not (hook is Dictionary):
			continue
		if str(hook.get("event", "")) != event:
			continue
		_run_passive_effect(p_idx, unit_index, str(hook.get("effect", "")), hook.get("params", {}), ctx)


func _run_unit_hooks(p_idx: int, unit_index: int, event: String, ctx: Dictionary) -> void:
	var u: Dictionary = player(p_idx).units[unit_index]
	var hooks: Array = u.get("passive_hooks", [])
	var form_ability: String = u.get("formAbility", "")
	for hook in hooks:
		if not (hook is Dictionary):
			continue
		if str(hook.get("event", "")) != event:
			continue
		_run_passive_effect(p_idx, unit_index, str(hook.get("effect", "")), hook.get("params", {}), ctx)
	# lightweight form ability simulation for common hooks (stats already applied)
	if form_ability != "" and event == "unit-entered-front" and "对敌方前线" in form_ability:
		var amount := 1
		var e_idx := enemy_index(p_idx)
		var fi: int = front_index(e_idx)
		if fi >= 0:
			_damage_unit(e_idx, fi, amount, p_idx)
		elif "空场" in form_ability or "核心" in form_ability:
			_damage_avatar(e_idx, amount, p_idx)


func _run_passive_effect(p_idx: int, unit_index: int, effect: String, params, ctx: Dictionary) -> void:
	var p := player(p_idx)
	var u: Dictionary = p.units[unit_index]
	var e_idx := enemy_index(p_idx)
	var pdict: Dictionary = params if params is Dictionary else {}
	var amount := _num(pdict.get("amount", 1))
	match effect:
		"passive-damage-enemy-front", "passive-damage-enemy-front-on-spell", "passive-damage-enemy-front-on-form":
			var fi: int = front_index(e_idx)
			if fi >= 0:
				_damage_unit(e_idx, fi, amount, p_idx)
			elif pdict.get("fallbackAvatar", false):
				_damage_avatar(e_idx, amount, p_idx)
		"passive-shield-self-if-front", "turn-shield", "passive-buff-self-if-front":
			if int(u.front) == 1:
				if effect == "passive-buff-self-if-front":
					_grow_unit(u, _num(pdict.get("attack", 0)), _num(pdict.get("hp", 0)))
				else:
					u.shield = int(u.shield) + amount
					_log("%s 获得 %d 点护盾。" % [u.name, amount], TONE_SUCCESS)
		"passive-heal-self-if-front", "turn-heal":
			if int(u.front) == 1:
				_heal_unit(u, amount)
		"passive-heal-avatar-on-own-card", "card-heal-avatar", "passive-heal-draw-avatar-on-own-card":
			_heal_avatar(p_idx, amount)
			if effect == "passive-heal-draw-avatar-on-own-card":
				_draw(p_idx, 1)
		"passive-shield-self-after-combat", "combat-aegis":
			u.shield = int(u.shield) + amount
			_log("%s 的护盾生效。" % u.name, TONE_SUCCESS)
		"passive-shield-self":
			u.shield = int(u.shield) + amount
		"passive-shield-self-heal-avatar-if-front":
			if int(u.front) == 1:
				u.shield = int(u.shield) + amount
				_heal_avatar(p_idx, amount)
		"passive-buff-self":
			_grow_unit(u, _num(pdict.get("attack", 0)), _num(pdict.get("hp", 0)))
		"passive-buff-self-on-damaged":
			var atk := _num(pdict.get("attack", 1))
			if pdict.get("perDamage", false):
				atk = _num(ctx.get("damage", amount))
			_grow_unit(u, atk, _num(pdict.get("hp", 0)))
		"passive-buff-other-allies":
			for i in p.units.size():
				if i != unit_index and int(p.units[i].hp) > 0:
					_grow_unit(p.units[i], _num(pdict.get("attack", 0)), _num(pdict.get("hp", 0)))
		"passive-buff-healed-attack":
			var healed: Dictionary = ctx.get("healed", u)
			_grow_unit(healed, amount, _num(pdict.get("hp", 0)))
		"passive-heal-all-allies":
			for other in p.units:
				if int(other.hp) > 0:
					_heal_unit(other, amount)
		"passive-heal-ally-if-front-or-any":
			var hurt: Array = []
			for other in p.units:
				if int(other.hp) > 0 and int(other.hp) < int(other.maxHp):
					hurt.append(other)
			if not hurt.is_empty():
				_heal_unit(hurt[randi() % hurt.size()], amount)
		"passive-heal-allies-on-combat":
			for i in p.units.size():
				if i != unit_index and int(p.units[i].hp) > 0:
					_heal_unit(p.units[i], amount)
		"passive-draw-self", "passive-draw-self-on-form":
			_draw(p_idx, amount if amount > 0 else 1)
		"passive-token-to-hand":
			var tokens: Array = pdict.get("tokens", [])
			var count := int(pdict.get("count", 1))
			for i in count:
				if tokens.is_empty():
					break
				var tid: String = str(tokens[i % tokens.size()])
				p.hand.append({"instanceId": "%s-t%d" % [p.id, next_card_id], "definitionId": tid})
				next_card_id += 1
				_log("%s 获得「%s」。" % [p.name, ContentLoader.card_def(tid).get("name", tid)], TONE_CARD)
		"passive-damage-avatar-after-reserve-combat":
			_damage_avatar(e_idx, amount, p_idx)
		"passive-damage-random-enemy":
			var enemies: Array = []
			for i in player(e_idx).units.size():
				if int(player(e_idx).units[i].hp) > 0:
					enemies.append(i)
			if enemies.is_empty():
				return
			if pdict.get("all", false):
				for ei in enemies:
					_damage_unit(e_idx, ei, amount, p_idx)
			else:
				for k in mini(2, enemies.size()):
					_damage_unit(e_idx, enemies[randi() % enemies.size()], amount, p_idx)
		"passive-damage-reserve-on-kill":
			if bool(ctx.get("killed", false)):
				for i in player(e_idx).units.size():
					var eu: Dictionary = player(e_idx).units[i]
					if int(eu.hp) > 0 and int(eu.get("front", 0)) == 0:
						_damage_unit(e_idx, i, amount, p_idx)
		"passive-damage-freeze-defender", "passive-freeze-combat-defender", "passive-freeze-brittle-combat-defender", "form-brittle-defender", "combat-freeze":
			var defender = ctx.get("defender")
			if defender is Dictionary and int(defender.hp) > 0:
				if effect in ["passive-damage-freeze-defender"]:
					# defender lives on enemy side
					for i in player(e_idx).units.size():
						if player(e_idx).units[i].get("uid") == defender.get("uid"):
							_damage_unit(e_idx, i, amount, p_idx)
							break
				if effect in ["passive-freeze-combat-defender", "passive-damage-freeze-defender"]:
					for i in player(e_idx).units.size():
						if player(e_idx).units[i].get("uid") == defender.get("uid"):
							player(e_idx).units[i].frozen = maxi(1, int(player(e_idx).units[i].frozen))
				if effect in ["form-brittle-defender", "passive-freeze-brittle-combat-defender", "combat-freeze"]:
					for i in player(e_idx).units.size():
						if player(e_idx).units[i].get("uid") == defender.get("uid"):
							player(e_idx).units[i].brittle = int(player(e_idx).units[i].brittle) + max(1, amount)
		"passive-growth-attack-on-kill":
			if bool(ctx.get("killed", false)):
				_grow_unit(u, amount, 0)
				_log("%s 噬敌成长，攻击 +%d。" % [u.name, amount], TONE_SUCCESS)
		"passive-gain-charge-after-combat":
			u.charge = int(u.get("charge", 0)) + amount
		"passive-return-to-reserve":
			u.front = 0
			if pdict.get("shield", 0):
				u.shield = int(u.shield) + int(pdict.shield)
			_log("%s 退回准备区。" % u.name, TONE_NEUTRAL)
		"passive-armor-break-self-on-damaged":
			u["armorBreak"] = int(u.get("armorBreak", 0)) + _num(ctx.get("damage", amount))
			if pdict.get("hp", 0):
				_grow_unit(u, 0, int(pdict.hp))
		"passive-armor-break-enemy-on-damage":
			var defender = ctx.get("defender")
			if defender is Dictionary and int(defender.hp) > 0:
				for i in player(e_idx).units.size():
					if player(e_idx).units[i].get("uid") == defender.get("uid"):
						player(e_idx).units[i]["armorBreak"] = int(player(e_idx).units[i].get("armorBreak", 0)) + amount
		"passive-armor-break-enemy-avatar":
			player(e_idx)["avatarArmorBreak"] = int(player(e_idx).get("avatarArmorBreak", 0)) + amount
		"passive-armor-break-enemy-front":
			var fi: int = front_index(e_idx)
			if fi >= 0:
				player(e_idx).units[fi]["armorBreak"] = int(player(e_idx).units[fi].get("armorBreak", 0)) + amount
		"passive-armor-break-defender":
			var defender = ctx.get("defender")
			if defender is Dictionary and int(defender.hp) > 0:
				for i in player(e_idx).units.size():
					if player(e_idx).units[i].get("uid") == defender.get("uid"):
						player(e_idx).units[i]["armorBreak"] = int(player(e_idx).units[i].get("armorBreak", 0)) + amount
		"passive-armor-break-enemies-on-damaged":
			if _num(ctx.get("damage", 0)) >= _num(pdict.get("threshold", 3)):
				for eu in player(e_idx).units:
					if int(eu.hp) > 0:
						eu["armorBreak"] = int(eu.get("armorBreak", 0)) + amount
		"passive-shield-on-overheal":
			u.shield = int(u.shield) + amount
			if pdict.get("attack", 0):
				_grow_unit(u, int(pdict.attack), 0)
		"passive-gain-energy":
			p.energy = mini(int(p.get("maxEnergy", 2)) + 2, int(p.energy) + amount)
		"form-shield-on-spell", "form-mend-on-spell":
			if effect == "form-mend-on-spell":
				_heal_unit(u, amount)
			else:
				u.shield = int(u.shield) + amount
		"passive-shield-front-on-realm", "passive-shield-front-boost-realm-on-realm":
			var fi: int = front_index(p_idx)
			if fi >= 0:
				p.units[fi].shield = int(p.units[fi].shield) + amount
		"realm-shield":
			pass
		"resonance-avatar":
			_damage_avatar(e_idx, amount, p_idx)
		_:
			_log("效果暂未完全结算：%s" % effect, TONE_NEUTRAL)


func end_turn(p_idx: int) -> bool:
	# 与 JS endTurn 对齐：不强制先升勾（升勾只卡出牌/出击）
	if not pending_choice.is_empty():
		_log("请先完成当前的占卜选择。", TONE_DANGER)
		return false
	if not response_window.is_empty():
		_log("请先处理当前响应窗口。", TONE_DANGER)
		return false
	if winner >= 0 or current_player != p_idx:
		return false
	_record("end_turn", {})
	var p := player(p_idx)
	for u in p.units:
		if int(u.frozen) > 0:
			u.frozen = int(u.frozen) - 1
	current_player = 1 - p_idx
	turn_counter += 1
	_begin_turn(current_player)
	state_changed.emit()
	return true


func _begin_turn(p_idx: int) -> void:
	var p := player(p_idx)
	p.attackUsed = false
	p.levelUpUsed = false
	p.cardsPlayedThisTurn = 0
	p.energy = int(p.maxEnergy)
	if p_idx == 0 and p.get("turnsTaken", 0) + 1 == int(rules.get("bonusUpgradeTurn", 7)):
		p.bonusUpgrades = int(p.bonusUpgrades) + 1
		_log("%s 获得一次额外升勾机会。" % p.name, TONE_SUCCESS)
	p["turnsTaken"] = int(p.get("turnsTaken", 0)) + 1
	# 充能：回合开始 +1（有 charge 关键词或已有 charge 槽的角色）
	for u in p.units:
		if int(u.hp) <= 0:
			continue
		var kws = u.get("keywords", [])
		var has_charge := false
		if kws is Array:
			for k in kws:
				if str(k).to_lower() == "charge":
					has_charge = true
		if has_charge or int(u.get("charge", 0)) > 0:
			var cap := int(u.get("chargeMax", 10))
			var before := int(u.get("charge", 0))
			u.charge = mini(cap, before + int(u.get("chargeGain", 1)))
			if int(u.charge) > before:
				_log("%s 充能 +%d（现 %d）。" % [u.name, int(u.charge) - before, int(u.charge)], TONE_SUCCESS)
	# knockout countdown
	for u in p.units:
		if int(u.hp) <= 0 and int(u.knockout) > 0:
			u.knockout = int(u.knockout) - 1
			if int(u.knockout) == 0:
				u.hp = int(u.maxHp)
				u.shield = 0
				_log("%s 自行归队，生命回复至满。" % u.name, TONE_SUCCESS)
	# realms
	_trigger_realms(p_idx)
	# turn-start passives (need front? fire all living units)
	for i in p.units.size():
		if int(p.units[i].hp) > 0:
			_run_unit_hooks(p_idx, i, "turn-started", {})
			_run_form_hooks(p_idx, i, "turn-started", {})
	if winner < 0:
		_draw(p_idx, 1)
	_log("%s 获得行动权。" % p.name, TONE_TURN)
	# 回合开始时战斗区回退准备区（与 JS beginTurn 末尾对齐）
	for u in p.units:
		if int(u.front) == 1:
			u.front = 0
			_log("%s 从战斗区返回准备区。" % u.name, TONE_NEUTRAL)


func _trigger_realms(p_idx: int) -> void:
	var p := player(p_idx)
	var e_idx := enemy_index(p_idx)
	var kept: Array = []
	for realm in p.realms:
		if int(realm.get("countdown", 0)) > 0:
			realm.countdown = int(realm.countdown) - 1
			if int(realm.countdown) > 0:
				kept.append(realm)
				continue
			realm.countdown = int(realm.get("countdownReset", 2))
		_apply_realm_trigger(p_idx, e_idx, realm)
		if int(realm.get("hp", 0)) > 0:
			kept.append(realm)
	p.realms = kept


func _apply_realm_trigger(p_idx: int, e_idx: int, realm: Dictionary) -> void:
	_log("幻境「%s」引动。" % realm.get("name", "?"), TONE_CARD)
	var steps: Array = []
	if realm.get("triggerEffects") is Array and (realm.triggerEffects as Array).size() > 0:
		steps = realm.triggerEffects
	else:
		steps = [{"effect": realm.get("triggerEffect", ""), "value": realm.get("triggerValue", 0)}]
	for step in steps:
		var effect := str(step.get("effect", "")) if step is Dictionary else str(step)
		var value = step.get("value", 0) if step is Dictionary else 0
		match effect:
			"shield-front":
				var fi := front_index(p_idx)
				if fi >= 0:
					var u: Dictionary = player(p_idx).units[fi]
					u.shield = int(u.shield) + _num(value)
					_log("%s 获得 %d 点护盾。" % [u.name, _num(value)], TONE_SUCCESS)
			"shield-all-allies":
				for u in player(p_idx).units:
					if int(u.hp) > 0:
						u.shield = int(u.shield) + _num(value)
			"damage-enemy-front":
				var fi2: int = front_index(e_idx)
				if fi2 >= 0:
					_damage_unit(e_idx, fi2, _num(value), p_idx)
				else:
					_damage_avatar(e_idx, _num(value), p_idx)
			"draw":
				_draw(p_idx, _num(value) if _num(value) > 0 else 1)
			_:
				_log("效果暂未完全结算", TONE_NEUTRAL)


func snapshot() -> Dictionary:
	return {
		"seed": seed,
		"turn": turn_counter,
		"round": get_round(),
		"current": current_player,
		"winner": winner,
		"phase": phase,
		"responseWindow": (not response_window.is_empty()),
		"stackDepth": resolution_stack.size(),
		"pendingChoice": (not pending_choice.is_empty()),
		"players": players,
		"log_size": log.size(),
		"commands": command_log.size(),
	}


func command_log_json() -> String:
	return JSON.stringify(command_log)
