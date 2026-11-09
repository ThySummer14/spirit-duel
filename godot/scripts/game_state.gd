class_name GameState
extends RefCounted
## Pure rules for the vertical slice. No UI. Seeded RNG + command log for replay.

const ContentLoader := preload("res://scripts/content_loader.gd")
const VerifiedRules := preload("res://scripts/verified_card_rules.gd")

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
var rule_events: Array = []
var next_rule_event_id: int = 1
var _card_effect_context: Dictionary = {}
var _mirror_spell_overflow := false
var _mirror_redirecting := false
var _mianqiling_damage_scope: Dictionary = {}
var _hand_combat_context: Dictionary = {}
var _toxic_damage_context: Dictionary = {}
var _night_damage_group: Dictionary = {}
var _shell_redirect_chain: Array = []
var fox_flame_snapshot: Dictionary = {}
var _shell_reactions: Array = []
var _shell_reaction_stack: Array = []
var _shell_in_exchange: bool = false
var moon_current_start: Dictionary = {}
var moon_previous_start: Dictionary = {}
var opening_deal: bool = true
var commission_day: int = 0
var _deferred_winner_checks: int = 0
var phase: String = "main"
var pending_choice: Dictionary = {}
const MAX_RESOLUTION_STACK_LENGTH := 64
const MAX_RESPONSE_DEPTH := 8


static func create(lineup_a: Array, lineup_b: Array, p_seed: int = 0, deck_a: Dictionary = {}, deck_b: Dictionary = {}, opening_choice: bool = false, weekday: int = -1) -> GameState:
	var gs := GameState.new()
	gs.commission_day = weekday if weekday >= 0 and weekday < 7 else int(Time.get_date_dict_from_system().weekday)
	gs.rules = ContentLoader.rules()
	gs.seed = p_seed if p_seed != 0 else (Time.get_unix_time_from_system() as int) & 0x7fffffff
	gs.rng_state = gs.seed if gs.seed != 0 else 1
	var deck0: Dictionary = deck_a if not deck_a.is_empty() else ContentLoader.default_deck(lineup_a)
	var deck1: Dictionary = deck_b if not deck_b.is_empty() else ContentLoader.default_deck(lineup_b)
	gs.players = [
		gs._create_player("player", "巡界者", deck0),
		gs._create_player("ai", "失序体", deck1),
	]
	gs.VerifiedRules.Headless.initialize(gs)
	gs.VerifiedRules.Insight.initialize(gs)
	gs.VerifiedRules.Xuan.initialize(gs)
	for owner in 2:
		if gs.VerifiedRules.FortunateDuo.source(gs, owner) >= 0: gs.VerifiedRules.FortunateDuo.new_die(gs, owner)
	for p in gs.players:
		if not p.units.is_empty():
			p.units[0].level = 1
	for owner in 2:
		if not gs.player(owner).units.is_empty(): gs.VerifiedRules.DogDemon.level_up(gs, owner, 0)
		if not gs.player(owner).units.is_empty(): gs.VerifiedRules.IronMouse.upgraded(gs, owner, 0)
		if not gs.player(owner).units.is_empty(): gs.VerifiedRules.Yitiao.upgraded(gs, owner, 0)
		if not gs.player(owner).units.is_empty(): gs.VerifiedRules.Crocodile.upgraded(gs,owner,0)
		if not gs.player(owner).units.is_empty(): gs.VerifiedRules.Chen.upgraded(gs, owner, 0)
		if not gs.player(owner).units.is_empty(): gs.VerifiedRules.DragonAbyss.Curse.leveled(gs, owner, 0)
	gs._draw(0, int(gs.rules.openingHandSize) - 1 + VerifiedRules.BookJue.opening_extra(gs, 0))
	gs._draw(1, int(gs.rules.openingHandSize) - 1 + VerifiedRules.BookJue.opening_extra(gs, 1))
	gs.opening_deal=false
	gs._begin_turn(0)
	gs._log("灵契编成已锁定，对局开始。", TONE_TURN)
	if opening_choice:
		gs.phase = "opening"
	else:
		VerifiedRules.Commission.opening(gs)
		VerifiedRules.TimeRewind.opening(gs)
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
	VerifiedRules.Yi.shuffled(self,arr)


func _log(text: String, tone: String = TONE_NEUTRAL) -> void:
	log.append({"text": text, "tone": tone, "turn": turn_counter})
	while log.size() > 400:
		log.pop_front()
	log_emitted.emit(text, tone)


func _record(cmd: String, args: Dictionary, p_idx: int) -> void:
	command_log.append({
		"t": turn_counter,
		"p": p_idx,
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


func action_player() -> int:
	if winner >= 0 or phase == "opening":
		return -1
	if not pending_choice.is_empty():
		return int(pending_choice.get("playerIndex", -1))
	if not response_window.is_empty():
		return int(response_window.get("playerIndex", -1))
	return current_player


func confirm_opening(indices: Array) -> bool:
	# Draw replacements before returning rejected cards; the same instances cannot return.
	if phase != "opening" or indices.size() > 3:
		return false
	var p := player(0)
	var seen := {}
	for index in indices:
		if not index is int or index < 0 or index >= p.hand.size() or seen.has(index):
			return false
		seen[index] = true
	if p.deck.size() < indices.size():
		return false
	_record("mulligan", {"indices": indices.duplicate()}, 0)
	var returned: Array = []
	for index in indices:
		returned.append(p.hand[index])
		p.hand[index] = p.deck.pop_back()
	p.deck.append_array(returned)
	if not returned.is_empty():
		_shuffle(p.deck)
	phase = "main"
	VerifiedRules.Commission.opening(self)
	VerifiedRules.TimeRewind.opening(self)
	_log("起手已确认 · 更换 %d 张牌。" % indices.size(), TONE_TURN)
	state_changed.emit()
	return true


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


func start_divination(p_idx: int, card: Dictionary, frame: Dictionary, is_divination: bool = true) -> void:
	var p := player(p_idx)
	var cfg = card.get("divination", {})
	var want := 3
	if cfg is Dictionary and cfg.has("count"):
		want = int(cfg.count)
	if is_divination and (VerifiedRules.Baize.present(self) or VerifiedRules.BaizeYuanqi.present(self) or VerifiedRules.Luohou.source(self, p_idx) >= 0):
		VerifiedRules.Divination.start(self,p_idx,want)
		return
	if is_divination: want += VerifiedRules.Eye.bonus(self, p_idx)
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
	if pending_choice.get("type") == VerifiedRules.Destiny.KIND: return VerifiedRules.Destiny.choose(self, p_idx, instance_id)
	if pending_choice.get("type") == VerifiedRules.BaizeYuanqi.HAND: return VerifiedRules.BaizeYuanqi.choose(self, p_idx, instance_id)
	if VerifiedRules.DragonFlow.resolve_choice(self, p_idx, instance_id): return true
	if VerifiedRules.Blueprint.resolve_choice(self, p_idx, instance_id): return true
	if VerifiedRules.LineageScroll.choice_card(self, p_idx, instance_id) != null: return VerifiedRules.LineageScroll.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("commission-"): return VerifiedRules.Commission.choose(self, p_idx, instance_id)
	if VerifiedRules.FactionArt.choice_card(self, p_idx, instance_id) != null: return VerifiedRules.FactionArt.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "grove-word": return VerifiedRules.PeachGrove.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("abyss-"): return VerifiedRules.DragonAbyss.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("w7-"): return VerifiedRules.Wave7Reworks.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("hf-"): return VerifiedRules.Hanafuda.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("xuan-"): return VerifiedRules.Xuan.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == VerifiedRules.Luohou.DISCARD_CHOICE: return VerifiedRules.Luohou.choose(self, p_idx, instance_id)
	if pending_choice.get("type") == "lunar-seize": return VerifiedRules.LunarTrick.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("stars-"): return VerifiedRules.StarRealms.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "cat-oath": return VerifiedRules.CatSamurai.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("yanmie-"): return VerifiedRules.YanmieTrio.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("water-"): return VerifiedRules.WaterMoon.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "chen-blessing": return VerifiedRules.Chen.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "solar-awaken": return VerifiedRules.Solar.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("treasure-"): return VerifiedRules.Treasure.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type","")).begins_with("fw-"):return VerifiedRules.FearWing.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type","") in ["sc-ingredient","sc-cat"]:return VerifiedRules.SugarCat.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="rw-items":return VerifiedRules.RednightWalnut.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="ape-mimic":return VerifiedRules.ApeSleeve.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="zd-whirl":return VerifiedRules.Zhenjian.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="charged-mode":return VerifiedRules.ChargedPair.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type") in ["rp-fox-mode","rp-fox-target"]:return VerifiedRules.RedPurple.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="ms-beauty":return VerifiedRules.MirrorSong.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="mian-faction":return VerifiedRules.Mianqiling.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type") in ["yi-long-think","yi-search"]:return VerifiedRules.Yi.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="black-white-second":return VerifiedRules.BlackWhite.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="box-pack":return VerifiedRules.BoxMaiden.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="native-link":return VerifiedRules.Link.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="hand-blessing": return VerifiedRules.HandBlessing.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="yitiao-stance": return VerifiedRules.Yitiao.resolve_choice(self,p_idx,instance_id)
	if str(pending_choice.get("type","")).begins_with("mountain-"): return VerifiedRules.Mountain.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="glutton-realm": return VerifiedRules.Glutton.resolve_choice(self,p_idx,instance_id)
	if str(pending_choice.get("type","")).begins_with("three-tail-"): return VerifiedRules.ThreeTail.resolve_choice(self,p_idx,instance_id)
	if str(pending_choice.get("type","")).begins_with("onikiri-"): return VerifiedRules.Onikiri.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="house-status": return VerifiedRules.House.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="goldfish-upgrade": return VerifiedRules.Goldfish.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type")=="raccoon-discard": return VerifiedRules.Raccoon.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type") == "moon-hand-top": return VerifiedRules.Moon.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type") == "bamboo-deck": return VerifiedRules.Bamboo.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type") == "eye-curse": return VerifiedRules.Eye.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "crab-sleep": return VerifiedRules.Crab.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "night-summon": return VerifiedRules.Night.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "mask-hand-top": return VerifiedRules.Mask.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") in ["charm-sand-top", "charm-twin-discover"]: return VerifiedRules.SandBook.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "native-divination": return VerifiedRules.Divination.resolve_choice(self, p_idx, instance_id)
	if str(pending_choice.get("type", "")).begins_with("mengpo-"): return VerifiedRules.Mengpo.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "huang-discard": return VerifiedRules.Huang.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "whale-awaken": return VerifiedRules.Whale.resolve_choice(self,p_idx,instance_id)
	if pending_choice.get("type") == "movement-burst": return VerifiedRules.Movement.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") in ["gift-waterfall", "gift-discard"]: return VerifiedRules.GiftEnergy.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") in ["smoke-burst", "smoke-pick"]: return VerifiedRules.SunSmoke.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") in ["book-dispatch", "book-mind"]: return VerifiedRules.BookJue.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "feather-transform": return VerifiedRules.Yijin.resolve_choice(self, p_idx, instance_id)
	if pending_choice.get("type") == "lantern-choice": return VerifiedRules.Light.resolve_choice(self, p_idx, instance_id)
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
	_record("resolve_divination_choice", {"instanceId": chosen_id, "card": selected.definitionId}, p_idx)
	p.deck.remove_at(deck_index)
	p.deck.append(selected)
	var def := ContentLoader.card_def(str(selected.get("definitionId", "")))
	_log("%s 将「%s」置于牌库顶。" % [p.name, def.get("name", selected.get("definitionId"))], TONE_SUCCESS)
	pending_choice = {}
	VerifiedRules.River.divined(self, p_idx)
	VerifiedRules.Eye.divined(self, p_idx, ids.size())
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
	return VerifiedRules.Light.roll(self, p_idx, threshold, sides, int(card.get("fortuneSourceIndex", -1)))


func _fortune_success(p_idx: int) -> bool:
	var last = kw_usage(p_idx, "fortune").get("last")
	if last is Dictionary:
		return bool(last.get("success", false))
	return false


func _apply_encourage(p_idx: int, attack: int, shield: int, battle_power: int = 0) -> void:
	var increased := VerifiedRules.TomatoFire.amplify(self, p_idx, attack, shield)
	attack = int(increased.attack)
	shield = int(increased.shield)
	var usage := kw_usage(p_idx, "encourage")
	usage["attack"] = int(usage.get("attack", 0)) + attack
	usage["shield"] = int(usage.get("shield", 0)) + shield
	if battle_power != 0: usage["battlePower"] = int(usage.get("battlePower", 0)) + battle_power
	_log("%s 鼓舞累积 +%d攻/+%d甲。" % [player(p_idx).name, attack, shield], TONE_SUCCESS)


func _prepare_encourage(p_idx: int) -> Dictionary:
	return VerifiedRules.TomatoFire.prepare_encourage(self, p_idx)

func _pay_charge_cost(p_idx: int, src: int, card: Dictionary) -> bool:
	if not card.has("chargeCost"): return true
	return VerifiedRules.SunSmoke.pay_charge(self, p_idx, src, int(card.chargeCost))

func _make_unit(pid: String, uid: String) -> Dictionary:
	var def := ContentLoader.unit_def(uid)
	if def.is_empty(): return {}
	var unit := {
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
		"armorBreak": 0,
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
	}
	VerifiedRules.Countdown.initialize(unit, def)
	VerifiedRules.SerpentGhost.initialize_duo(unit)
	return unit


func _create_player(pid: String, pname: String, deck_definition: Dictionary) -> Dictionary:
	var unit_ids: Array = deck_definition.get("unitIds", [])
	var units: Array = []
	for uid in unit_ids:
		var unit := _make_unit(pid, str(uid))
		if not unit.is_empty(): units.append(unit)
	var deck: Array = []
	var card_ids: Array = deck_definition.get("cardIds", [])
	var slot_owners: Array = deck_definition.get("slotOwners", [])
	for index in card_ids.size():
		var card_id := str(card_ids[index])
		var instance := {"instanceId": "%s-c%d" % [pid, next_card_id], "definitionId": card_id}
		if index < slot_owners.size() and ContentLoader.card_def(card_id).get("type") == "coop":
			instance.coopDeckOwner = str(slot_owners[index])
		deck.append(instance)
		next_card_id += 1
	_shuffle(deck)
	return {
		"id": pid,
		"name": pname,
		"avatarHp": int(rules.get("startingAvatarHp", 30)),
		"maxAvatarHp": int(rules.get("startingAvatarHp", 30)),
		"avatarArmor": 0,
		"avatarArmorBreak": 0,
		"energy": 0,
		"maxEnergy": int(rules.get("maxEnergy", 2)),
		"deck": deck,
		"initialDeckNames": deck_definition.get("cardIds", []).map(func(id): return str(ContentLoader.card_def(str(id)).get("name", ""))).filter(func(name): return not name.is_empty()),
		"hand": [],
		"units": units,
		"attackUsed": false,
		"levelUpUsed": false,
		"bonusUpgrades": 0,
		"cardsPlayedThisTurn": 0,
		"realms": [],
		"keywordUsage": {},
	}


func _draw(p_idx: int, count: int, required_level: int = -1, draw_context: Dictionary = {}) -> void:
	if VerifiedRules.Yi.defer_draw(self, p_idx, count, required_level, draw_context): return
	var p := player(p_idx)
	for _i in count:
		if p.deck.is_empty():
			if required_level >= 0 or draw_context.has("sandCharmOwner") or draw_context.get("allowShortDeck", false) or draw_context.has("waveDrawUnit") or draw_context.has("drawInstanceId") or draw_context.has("xuanMaxLevel"): return
			if VerifiedRules.BookJue.empty_draw(self, p_idx): return
			if VerifiedRules.DragonAbyss.Travel.empty_draw(self, p_idx): return
			if p.avatarHp > 0 and winner < 0:
				p.avatarHp = 0
				_log("%s 牌库耗尽，核心崩解。" % p.name, TONE_DANGER)
				_check_winner()
			return
		var card: Dictionary
		if draw_context.has("sandCharmOwner"):
			var matches: Array = []
			for i in p.deck.size():
				if VerifiedRules.SandBook.has_charm(int(draw_context.sandCharmOwner), p_idx, p.deck[i]): matches.append(i)
			if matches.is_empty(): return
			card = p.deck.pop_at(matches[next_random() % matches.size()])
		elif draw_context.has("xuanMaxLevel"):
			var matches := VerifiedRules.Xuan.deck_matches(self, p_idx, int(draw_context.xuanMaxLevel))
			if matches.is_empty(): return
			card = p.deck.pop_at(matches[int(next_random() % matches.size())])
			if draw_context.has("xuanDrawn"): draw_context.xuanDrawn.append(card)
		elif draw_context.has("waveDrawUnit"):
			var matches: Array = []
			for i in p.deck.size():
				if ContentLoader.card_def(str(p.deck[i].definitionId)).get("unitId") == draw_context.waveDrawUnit: matches.append(i)
			if matches.is_empty(): return
			card = p.deck.pop_at(matches[next_random() % matches.size()])
		elif draw_context.has("drawInstanceId"):
			var idx: int = p.deck.find_custom(func(inst): return inst.instanceId == draw_context.drawInstanceId)
			if idx < 0: return
			card = p.deck.pop_at(idx)
		elif required_level < 0:
			card = p.deck.pop_front() if draw_context.get("bottomDraw", false) else p.deck.pop_back()
		else:
			var matches: Array = []
			for i in p.deck.size():
				if int(ContentLoader.card_def(str(p.deck[i].definitionId)).get("level", 0)) == required_level: matches.append(i)
			if matches.is_empty(): return
			card = p.deck.pop_at(matches[int(next_random() % matches.size())])
		var depth := resolution_stack.size()
		var remaining := count - _i - 1
		if remaining > 0: resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": p_idx, "count": remaining, "requiredLevel": required_level, "drawContext": draw_context})
		if draw_context.get("twinRealmInstant", false) and ContentLoader.card_def(str(card.definitionId)).get("type") == "realm": card.twinInstantTurn = turn_counter
		if draw_context.has("giftDrawn"): draw_context.giftDrawn.append(card)
		VerifiedRules.GiftEnergy.drawn(self, p_idx, card)
		if not opening_deal:
			if int(p.get("restoredDrawTurn", -1)) != turn_counter:
				p.restoredDrawTurn = turn_counter
				p.restoredDrawCount = 0
			p.restoredDrawCount += 1
		var musashi: bool = not opening_deal and card.definitionId == VerifiedRules.CatSamurai.MUSASHI
		if musashi: resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": p_idx, "count": 1})
		if draw_context.get("intoInsight", false) or musashi:
			if VerifiedRules.Insight.place(self, p_idx, card) and draw_context.get("attachSunlight", false):
				VerifiedRules.Solar.attach(self, p_idx, card)
		else: p.hand.append(card)
		if not opening_deal: VerifiedRules.Commission.progress(self, p_idx, "draw")
		VerifiedRules.Glutton.mark_hand(self,p_idx)
		var def := ContentLoader.card_def(card.definitionId)
		_log("%s 抽到「%s」。" % [p.name, def.get("name", card.definitionId)], TONE_NEUTRAL)
		while p.hand.size() > int(rules.get("maxHandSize", 12)):
			var burned: Dictionary = p.hand.pop_back()
			var bdef := ContentLoader.card_def(burned.definitionId)
			_log("%s 手牌已满，「%s」被烧毁。" % [p.name, bdef.get("name", burned.definitionId)], TONE_DANGER)

		VerifiedRules.Xuan.drawn(self, p_idx, card)
		VerifiedRules.BaizeYuanqi.drawn(self, p_idx)
		VerifiedRules.Luohou.drawn(self, p_idx, card, draw_context)
		var koi_triggered:=VerifiedRules.KoiFragrance.drawn(self,p_idx)
		var bond_triggered:=VerifiedRules.BondDream.drawn(self,p_idx,card)
		var sand_triggered := VerifiedRules.SandBook.drawn(self, p_idx, card, draw_context)
		if koi_triggered or bond_triggered or sand_triggered or resolution_stack.size() > depth + (1 if remaining > 0 else 0):
			VerifiedRules.BondDream.refresh(self)
			_resolve_inline_frames(depth)
			return
		if remaining > 0: resolution_stack.pop_back()
		VerifiedRules.BondDream.refresh(self)


func _resolve_inline_frames(depth: int) -> void:
	var previous := is_resolving
	var context := _card_effect_context
	is_resolving = true
	while resolution_stack.size() > depth and pending_choice.is_empty() and response_window.is_empty() and winner < 0:
		VerifiedRules.Yi.promote(self)
		VerifiedRules.MirrorSong.promote(self)
		var frame: Dictionary = resolution_stack.back()
		if frame.get("kind") == "card-effect" and frame.get("respondable", false) and not frame.get("responseOffered", false):
			frame.responseOffered = true
			response_window = _create_response_window(frame)
			if either_player_has_response():
				phase = "response"
				break
			response_window = {}
		_card_effect_context = {}
		_resolve_frame(resolution_stack.pop_back())
		VerifiedRules.Arakawa.refresh_hold(self)
		VerifiedRules.Crab.clear_finished_immunity(self)
		VerifiedRules.BondDream.refresh(self)
		VerifiedRules.MonkCleaner.refresh(self)
		VerifiedRules.BlueGreen.refresh(self)
		VerifiedRules.OwlInsect.refresh(self)
		VerifiedRules.Xuenv.remove_departed_walls(self)
		VerifiedRules.TomatoFire.remove_departed(self)
		VerifiedRules.SunSmoke.remove_departed(self)
		VerifiedRules.GiftEnergy.remove_departed(self)
		VerifiedRules.Bamboo.remove_departed(self)
		VerifiedRules.Paint.remove_departed(self)
		VerifiedRules.Pine.remove_departed(self)
		VerifiedRules.Rain.remove_departed(self)
		for side in players.size(): VerifiedRules.NativeSummons.remove_departed(self, side)
		VerifiedRules.Enma.remove_departed(self)
		VerifiedRules.Weaver.remove_departed(self)
		VerifiedRules.Vine.remove_departed(self)
		VerifiedRules.WindRaccoon.remove_departed(self)
		VerifiedRules.BoxMaiden.remove_departed(self)
		VerifiedRules.House.remove_departed(self)
		VerifiedRules.Doll.remove_departed(self)
		VerifiedRules.Jorogumo.remove_departed(self)
		VerifiedRules.Whale.remove_departed(self)
		VerifiedRules.MusicFire.remove_departed(self)
		VerifiedRules.SerpentGhost.refresh(self)
		VerifiedRules.SugarCat.remove_departed(self)
		VerifiedRules.EssenceFeast.remove_departed(self)
		VerifiedRules.RabbitTide.remove_departed(self)
	_card_effect_context = context
	is_resolving = previous


func is_upgrade_pending(p_idx: int) -> bool:
	# 与 game-core.js isUpgradePending 对齐：仅存活角色、仅本回合尚未升勾时强制
	if winner >= 0 or current_player != p_idx:
		return false
	var p := player(p_idx)
	if p.levelUpUsed:
		return false
	for u in p.units:
		if u.get("summoned", false): continue
		if int(u.hp) > 0 and VerifiedRules.UpgradeBlessing.can_raise(self, p_idx, u):
			return true
	return false


func min_level(p_idx: int) -> int:
	var mn: int = 99
	for u in player(p_idx).units:
		if u.get("summoned", false): continue
		mn = mini(mn, int(u.level))
	return mn


func can_level_up(p_idx: int, unit_index: int) -> bool:
	if winner >= 0 or current_player != p_idx or phase == "opening":
		return false
	var p := player(p_idx)
	if unit_index < 0 or unit_index >= p.units.size():
		return false
	var u: Dictionary = p.units[unit_index]
	if u.get("summoned", false): return false
	# 与 JS 对齐：气绝角色也可升勾，避免「最低勾在气绝角色上」卡死
	if not VerifiedRules.UpgradeBlessing.can_raise(self, p_idx, u):
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
	_record("level_up", {"unit": unit_index}, p_idx)
	var p := player(p_idx)
	var u: Dictionary = p.units[unit_index]
	raise_unit_level(p_idx, unit_index)
	if p.levelUpUsed:
		p.bonusUpgrades = int(p.bonusUpgrades) - 1
	else:
		p.levelUpUsed = true
	_log("%s 升级结算，当前 %d 勾玉。" % [u.name, int(u.level)], TONE_SUCCESS)
	_resolve_resolution_stack()
	state_changed.emit()
	return true


## 所有实际升勾共用能力触发；获得升级机会本身不触发。
func raise_unit_level(p_idx: int, unit_index: int) -> void:
	VerifiedRules.UpgradeBlessing.raise_level(self, p_idx, unit_index)


func playable_deck_top(p_idx: int) -> bool:
	return VerifiedRules.SpiderLily.top_available(self, p_idx) or VerifiedRules.YanmieTrio.top_available(self, p_idx)


func playable_card_count(p_idx: int) -> int:
	if VerifiedRules.Insight.active(self, p_idx): return VerifiedRules.Insight.zone(self, p_idx).size()
	return player(p_idx).hand.size() + (1 if playable_deck_top(p_idx) else 0) + VerifiedRules.Link.extra_instances(self,p_idx).size()


func card_instance(p_idx: int, card_index: int) -> Dictionary:
	if VerifiedRules.Insight.active(self, p_idx):
		var zone := VerifiedRules.Insight.zone(self, p_idx)
		return zone[card_index] if card_index >= 0 and card_index < zone.size() else {}
	var virtual=VerifiedRules.Link.virtual_instance(self,p_idx,card_index)
	if virtual!=null:return virtual
	var p := player(p_idx)
	if card_index < 0: return {}
	if card_index < p.hand.size(): return p.hand[card_index]
	if card_index == p.hand.size() and playable_deck_top(p_idx): return p.deck.back()
	return {}


func discard_hand_card(p_idx: int, hand_index: int) -> Dictionary:
	var inst: Dictionary = player(p_idx).hand.pop_at(hand_index)
	VerifiedRules.GiftEnergy.remember(self, p_idx, inst)
	VerifiedRules.Treasure.discarded(self, p_idx, inst)
	VerifiedRules.DragonAbyss.Discard.discarded(self, p_idx, inst)
	VerifiedRules.Hanafuda.discard(self, p_idx, inst)
	return inst


func take_card_instance(p_idx: int, card_index: int) -> Dictionary:
	if VerifiedRules.Insight.active(self, p_idx):
		var zone := VerifiedRules.Insight.zone(self, p_idx)
		if card_index < 0 or card_index >= zone.size(): return {}
		var inst: Dictionary = zone[card_index]
		VerifiedRules.Insight.remove(self, p_idx, inst)
		return inst
	var linked=VerifiedRules.Link.take(self,p_idx,card_index)
	if linked!=null:return linked
	if card_instance(p_idx, card_index).is_empty(): return {}
	var p := player(p_idx)
	return p.hand.pop_at(card_index) if card_index < p.hand.size() else p.deck.pop_back()


func hand_card_def(p_idx: int, hand_index: int) -> Dictionary:
	var p := player(p_idx)
	var from_zone := VerifiedRules.Insight.active(self, p_idx)
	var inst := card_instance(p_idx, hand_index)
	var from_top: bool = not from_zone and hand_index == p.hand.size() and playable_deck_top(p_idx)
	var twins_top: bool = from_top and VerifiedRules.YanmieTrio.top_available(self, p_idx)
	var card := describe_card_instance(p_idx, inst, not from_zone and hand_index < p.hand.size(), from_top and not twins_top)
	if not from_zone and hand_index >= 0 and hand_index < p.hand.size() and not inst.get("linkVirtual", false):
		card = card.duplicate()
		card.w7PayFromHand = true
		if card.has("originCard") and card.originCard is Dictionary:
			card.originCard = card.originCard.duplicate()
			card.originCard.w7PayFromHand = true
	if twins_top and not card.is_empty(): card = VerifiedRules.YanmieTrio.top_card(card)
	return VerifiedRules.DragonAbyss.Discard.describe_hand(self, p_idx, VerifiedRules.Insight.describe(self, p_idx, inst, card, from_zone and not card.is_empty()), not from_zone and hand_index < p.hand.size())


## Read-only projection for actual hand and deck instances, including upgrades.
func describe_card_instance(p_idx: int, inst: Dictionary, from_hand: bool = true, permitted_deck_top: bool = false) -> Dictionary:
	if inst.is_empty(): return {}
	var p := player(p_idx)
	if inst.get("definitionId","")=="shengmingjinghua":return VerifiedRules.EssenceFeast.essence_card(self,p_idx,inst)
	if not VerifiedRules.Cooking.food_kind(inst).is_empty():
		return VerifiedRules.HandBlessing.describe_card(self,p_idx,inst,VerifiedRules.Blueprint.describe(self,p_idx,inst,VerifiedRules.Cooking.describe_food(self,p_idx,inst)))
	var card: Dictionary = VerifiedRules.Firefly.describe_card(self, p_idx, inst, ContentLoader.card_def(inst.definitionId))
	card = VerifiedRules.ZenMisfortune.describe(self, p_idx, inst, card)
	card = VerifiedRules.Link.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.TwoFaces.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Bingyong.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Yaodao.describe_card(self, p_idx, card)
	card = VerifiedRules.CoopFirst.describe(self, p_idx, card)
	card = VerifiedRules.CoopMiddle.describe(self, p_idx, inst, card)
	card = VerifiedRules.DogDemon.describe_card(self, p_idx, card, inst)
	card = VerifiedRules.Shantong.describe_card(self, p_idx, card)
	card = VerifiedRules.Panguan.describe_card(self, p_idx, card)
	card = VerifiedRules.Xuenv.describe_card(self, p_idx, card)
	card = VerifiedRules.Tide.describe_card(self, p_idx, card)
	card = VerifiedRules.Poison.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Light.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Fortune.describe_card(self, p_idx, card)
	card = VerifiedRules.Movement.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Yijin.describe_card(self, p_idx, card)
	card = VerifiedRules.SnowCrane.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.BookJue.describe_card(self, p_idx, inst, card, from_hand)
	card = VerifiedRules.SunSmoke.describe_card(self, p_idx, card)
	card = VerifiedRules.StarRealms.describe(self, p_idx, inst, card)
	card = VerifiedRules.GiftEnergy.describe(self, p_idx, inst, card)
	card = VerifiedRules.DragonAbyss.describe(self, p_idx, inst, card)
	var src := _source_index(p_idx, card)
	if src >= 0:
		card = VerifiedRules.Peach.prepare_hand_card(card, p.units[src])
		card = VerifiedRules.Phoenix.describe_card(card, p.units[src])
		card = VerifiedRules.SpellReplay.prepare_hand_card(card, p.units[src])
		card = VerifiedRules.Shuten.describe_card(self, card, p.units[src])
	card = VerifiedRules.ArmorBlood.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Huang.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Himiko.describe(self, p_idx, inst, card)
	card = VerifiedRules.Mengpo.describe_card(self, p_idx, card)
	card = VerifiedRules.FoxSuzuka.describe_card(self, p_idx, card)
	card = VerifiedRules.IronMouse.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.River.describe_card(self, p_idx, card)
	card = VerifiedRules.Wind.describe_card(self, p_idx, card)
	card = VerifiedRules.Night.describe_card(self, p_idx, card)
	card = VerifiedRules.Mask.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Eye.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.Crab.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.BondDream.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.OwlInsect.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.MonkCleaner.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.SugarCat.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.RabbitTide.describe_card(self,p_idx,card,inst)
	card = VerifiedRules.Bamboo.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.UpgradeBlessing.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.OniAsura.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.PipeFox.describe_card(self,p_idx,card)
	card=VerifiedRules.Rebirth.describe_card(self,p_idx,card)
	card=VerifiedRules.FoxLotus.describe_card(self,p_idx,card)
	card=VerifiedRules.Paint.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Pine.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.StarBear.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.ThreeTail.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Glutton.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Doll.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Onikiri.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Otakemaru.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.House.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Goldfish.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Vine.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.WindRaccoon.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Puppet.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Enma.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Weaver.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Sparrow.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Headless.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Yaksha.describe_card(self,p_idx,inst,card)
	card=VerifiedRules.Samurai.describe_card(self,p_idx,card)
	card=VerifiedRules.Maple.describe_card(self,p_idx,card)
	card = VerifiedRules.Raccoon.describe_card(self,p_idx,VerifiedRules.Moon.describe_card(self,p_idx,card))
	card = VerifiedRules.Susanoo.describe_card(self,p_idx,card)
	card = VerifiedRules.Crocodile.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Whale.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Jorogumo.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Yitiao.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Garuda.describe_card(self, p_idx, inst, card, from_hand)
	card = VerifiedRules.Butterfly.describe_card(self, p_idx, inst, card, from_hand)
	card = VerifiedRules.Cotton.describe_card(self, p_idx, inst, card)
	card = VerifiedRules.BlueGreen.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.RedPurple.describe_card(self,p_idx,card)
	card = VerifiedRules.Mianqiling.describe_card(self,p_idx,card)
	card = VerifiedRules.Futakuchi.describe_card(self,p_idx,card)
	card = VerifiedRules.BoxMaiden.describe_card(self,p_idx,card)
	card = VerifiedRules.RednightWalnut.describe_card(self,p_idx,card)
	card = VerifiedRules.Arakawa.describe_card(self,p_idx,card)
	card = VerifiedRules.ChargedPair.describe(self,p_idx,inst,card)
	card = VerifiedRules.ApeSleeve.describe(self,p_idx,inst,card)
	card = VerifiedRules.Zhenjian.describe(self,p_idx,card)
	card = VerifiedRules.Cooking.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.EssenceFeast.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.SerpentGhost.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Commission.describe(self, p_idx, inst, card)
	card = VerifiedRules.MusicFire.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.WisdomLamp.describe(self,p_idx,card)
	card = VerifiedRules.Langya.describe(self,p_idx,card)
	card = VerifiedRules.Guishihei.describe(self, p_idx, card)
	card = VerifiedRules.Treasure.describe(self, p_idx, card)
	card = VerifiedRules.PaperDance.describe(self, inst, card)
	card = VerifiedRules.TwinSight.describe(self, p_idx, inst, card)
	card = VerifiedRules.SandBook.describe(self, p_idx, inst, card)
	card = VerifiedRules.Astral.describe(self, p_idx, card)
	card = VerifiedRules.Chen.describe(self, p_idx, inst, card)
	card = VerifiedRules.WaterMoon.describe(self, p_idx, card)
	card = VerifiedRules.Wave7Reworks.describe(self, p_idx, inst, card)
	card = VerifiedRules.Hanafuda.describe(self, p_idx, inst, card)
	card = VerifiedRules.Xuan.describe(self, p_idx, card)
	card = VerifiedRules.Hanafuda.aim_card(self, p_idx, card)
	card = VerifiedRules.LunarTrick.describe(self, p_idx, card)
	card = VerifiedRules.LineageScroll.describe(self, p_idx, inst, card)
	card = VerifiedRules.DragonFlow.describe(self, p_idx, inst, card)
	card = VerifiedRules.Blueprint.describe(self, p_idx, inst, card)
	card = VerifiedRules.NineTails.describe(self, p_idx, inst, card)
	card = VerifiedRules.FortuneCat.describe(self, p_idx, card)
	card = VerifiedRules.Grudge.describe(self, p_idx, card, from_hand)
	card = VerifiedRules.BaizeYuanqi.describe(self, p_idx, inst, card)
	card = VerifiedRules.TimeRewind.describe(self, p_idx, card)
	card = VerifiedRules.FactionArt.describe(self, p_idx, inst, card)
	card = VerifiedRules.WindCharm.describe(self, p_idx, card)
	card = VerifiedRules.FortunateDuo.describe(self, p_idx, inst, card)
	card = VerifiedRules.Izanami.describe(self, p_idx, card)
	card = VerifiedRules.YanmieTrio.describe(self, p_idx, inst, card)
	card = VerifiedRules.HairPower.describe(self,p_idx,card)
	card = VerifiedRules.DuskCycle.describe(self, p_idx, inst, card)
	card = VerifiedRules.PeachGrove.describe(self, p_idx, inst, card)
	card = VerifiedRules.FearWing.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Yi.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.MirrorSong.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.BlackWhite.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.Lantern.describe_card(self,p_idx,card)
	card = VerifiedRules.Yujiazhu.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.SeaButterfly.describe_card(self,p_idx,inst,card)
	card = VerifiedRules.SilkNinja.describe_card(self,p_idx,inst,card)
	return VerifiedRules.HandBlessing.describe_card(self,p_idx,inst,VerifiedRules.Toxic.describe_card(self,p_idx,inst,VerifiedRules.SpiderLily.describe_card(self, p_idx, inst, card, permitted_deck_top, not from_hand or bool(inst.get("twoFacesFromDeck",false)))))


func _source_index(p_idx: int, card: Dictionary) -> int:
	var sg_source=VerifiedRules.SerpentGhost.source_index(self,p_idx,card)
	if sg_source!=null:return int(sg_source)
	var p := player(p_idx)
	for i in p.units.size():
		if p.units[i].id == card.get("unitId"):
			return i
	return -1


func valid_targets(p_idx: int, card: Dictionary) -> Array:
	var coop_targets = VerifiedRules.CoopFirst.targets(self, p_idx, card)
	if coop_targets != null: return coop_targets
	coop_targets = VerifiedRules.CoopMiddle.targets(self, p_idx, card)
	if coop_targets != null: return coop_targets
	coop_targets = VerifiedRules.CoopLate.targets(self, p_idx, card)
	if coop_targets != null: return coop_targets
	if card.get("target") == "zen-ally-character":
		var friendly: Array = player(p_idx).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed",false)).map(func(u): return str(u.uid))
		friendly.append("avatar-%d" % p_idx)
		return friendly
	var grudge_targets = VerifiedRules.Grudge.targets(self, p_idx, card)
	if grudge_targets != null: return grudge_targets
	var blueprint_targets = VerifiedRules.Blueprint.targets(self, p_idx, card)
	if blueprint_targets != null: return blueprint_targets
	var stars_targets = VerifiedRules.StarRealms.targets(self, p_idx, card)
	if stars_targets != null: return stars_targets
	var flow_targets = VerifiedRules.DragonFlow.targets(self, p_idx, card)
	if flow_targets != null: return flow_targets
	var dusk_targets = VerifiedRules.DuskCycle.targets(self, p_idx, card)
	if dusk_targets != null: return dusk_targets
	var grove_targets = VerifiedRules.PeachGrove.targets(self, p_idx, card)
	if grove_targets != null: return grove_targets
	var abyss_targets = VerifiedRules.DragonAbyss.targets(self, p_idx, card)
	if abyss_targets != null: return abyss_targets
	var wave_targets = VerifiedRules.Wave7Reworks.targets(self, p_idx, card)
	if wave_targets != null: return wave_targets
	var luohou_targets = VerifiedRules.Luohou.targets(self, p_idx, card)
	if luohou_targets != null: return luohou_targets
	var xuan_targets = VerifiedRules.Xuan.targets(self, p_idx, card)
	if xuan_targets != null: return xuan_targets
	var yuanqi_targets = VerifiedRules.BaizeYuanqi.targets(self, p_idx, card)
	if yuanqi_targets != null: return yuanqi_targets
	var hana_targets = VerifiedRules.Hanafuda.targets(self, p_idx, card)
	if hana_targets != null: return hana_targets
	var yanmie_targets = VerifiedRules.YanmieTrio.targets(self, p_idx, card)
	if yanmie_targets != null: return yanmie_targets
	var gift_targets = VerifiedRules.GiftEnergy.targets(self, p_idx, card)
	if gift_targets != null: return gift_targets
	var neutral_targets = VerifiedRules.Insight.neutral_targets(self, p_idx, card)
	if neutral_targets != null: return neutral_targets
	var sg_targets=VerifiedRules.SerpentGhost.targets(self,p_idx,card)
	if sg_targets!=null:return sg_targets
	var coffin_targets = VerifiedRules.Coffin.targets(self, p_idx, card)
	if coffin_targets != null: return coffin_targets
	var commission_targets = VerifiedRules.Commission.targets(self, p_idx, card)
	if commission_targets != null: return commission_targets
	var solar_targets = VerifiedRules.Solar.targets(self, p_idx, card)
	if solar_targets != null: return solar_targets
	var peach_targets = VerifiedRules.Peach.targets(self, p_idx, card)
	if peach_targets != null: return peach_targets
	if card.get("neutralEssence",false):return VerifiedRules.EssenceFeast.essence_targets(self,p_idx)
	var ef_targets=VerifiedRules.EssenceFeast.targets(self,p_idx,card)
	if ef_targets!=null:return ef_targets
	if card.get("neutralFood",false):return VerifiedRules.Cooking.food_targets(self,p_idx,card)
	var wl_targets=VerifiedRules.WisdomLamp.targets(self,p_idx,card)
	if wl_targets!=null:return wl_targets
	var water_targets = VerifiedRules.WaterMoon.targets(self, p_idx, card)
	if water_targets != null: return water_targets
	var lunar_targets = VerifiedRules.LunarTrick.targets(self, p_idx, card)
	if lunar_targets != null: return lunar_targets
	var restored_targets = VerifiedRules.LineageScroll.targets(self, p_idx, card)
	if restored_targets == null: restored_targets = VerifiedRules.FactionArt.targets(self, p_idx, card)
	if restored_targets != null: return restored_targets
	for targets in [VerifiedRules.PaperDance.targets(self, p_idx, card), VerifiedRules.TwinSight.targets(self, p_idx, card), VerifiedRules.SandBook.targets(self, p_idx, card)]:
		if targets != null: return targets
	var bone_targets = VerifiedRules.Bone.targets(self, p_idx, card)
	if bone_targets != null: return bone_targets
	var rain_targets = VerifiedRules.Rain.targets(self, p_idx, card)
	if rain_targets != null: return rain_targets
	var ly_targets=VerifiedRules.Langya.targets(self,p_idx,card)
	if ly_targets!=null:return ly_targets
	var gh_targets = VerifiedRules.Guishihei.card_targets(self, p_idx, card)
	if gh_targets != null: return gh_targets
	var treasure_targets = VerifiedRules.Treasure.targets(self, p_idx, card)
	if treasure_targets != null: return treasure_targets
	var fw_targets=VerifiedRules.FearWing.targets(self,p_idx,card)
	if fw_targets!=null:return fw_targets
	var mf_targets=VerifiedRules.MusicFire.targets(self,p_idx,card)
	if mf_targets!=null:return mf_targets
	var rw_targets=VerifiedRules.RednightWalnut.targets(self,p_idx,card)
	if rw_targets!=null:return rw_targets
	var yuj_targets=VerifiedRules.Yujiazhu.targets(self,p_idx,card)
	if yuj_targets!=null:return yuj_targets
	var ark_targets=VerifiedRules.Arakawa.targets(self,p_idx,card)
	if ark_targets!=null:return ark_targets
	var ape_targets=VerifiedRules.ApeSleeve.targets(self,p_idx,card)
	if ape_targets!=null:return ape_targets
	var charged_targets=VerifiedRules.ChargedPair.targets(self,p_idx,card)
	if charged_targets!=null:return charged_targets
	var rp_targets=VerifiedRules.RedPurple.targets(self,p_idx,card)
	if rp_targets!=null:return rp_targets
	var ms_targets=VerifiedRules.MirrorSong.targets(self,p_idx,card)
	if ms_targets!=null:return ms_targets
	var yi_targets=VerifiedRules.Yi.targets(self,p_idx,card)
	if yi_targets!=null:return yi_targets
	var bg_targets=VerifiedRules.BlueGreen.targets(self,p_idx,card)
	if bg_targets!=null:return bg_targets
	var mian_targets=VerifiedRules.Mianqiling.targets(self,p_idx,card)
	if mian_targets!=null:return mian_targets
	var black_white_targets=VerifiedRules.BlackWhite.targets(self,p_idx,card)
	if black_white_targets!=null:return black_white_targets
	for targets in [VerifiedRules.TwoFaces.targets(self,p_idx,card),VerifiedRules.SeaButterfly.targets(self,p_idx,card),VerifiedRules.SilkNinja.targets(self,p_idx,card),VerifiedRules.Toxic.targets(self,p_idx,card),VerifiedRules.KoiFragrance.targets(self,p_idx,card),VerifiedRules.Susanoo.targets(self,p_idx,card),VerifiedRules.Baize.targets(self,p_idx,card),VerifiedRules.Crocodile.targets(self,p_idx,card),VerifiedRules.Whale.targets(self,p_idx,card),VerifiedRules.Jorogumo.targets(self,p_idx,card),VerifiedRules.Butterfly.targets(self,p_idx,card),VerifiedRules.Cotton.targets(self,p_idx,card),VerifiedRules.ThreeTail.targets(self,p_idx,card),VerifiedRules.Glutton.targets(self,p_idx,card),VerifiedRules.Doll.targets(self,p_idx,card),VerifiedRules.Onikiri.targets(self,p_idx,card),VerifiedRules.Otakemaru.targets(self,p_idx,card),VerifiedRules.House.targets(self,p_idx,card),VerifiedRules.Goldfish.targets(self,p_idx,card),VerifiedRules.Vine.targets(self,p_idx,card),VerifiedRules.WindRaccoon.targets(self,p_idx,card),VerifiedRules.Puppet.targets(self,p_idx,card),VerifiedRules.Enma.targets(self,p_idx,card),VerifiedRules.Weaver.targets(self,p_idx,card),VerifiedRules.Sparrow.targets(self,p_idx,card),VerifiedRules.Headless.targets(self,p_idx,card),VerifiedRules.Yaksha.targets(self,p_idx,card),VerifiedRules.StarBear.targets(self,p_idx,card),VerifiedRules.Pine.targets(self,p_idx,card),VerifiedRules.Paint.targets(self,p_idx,card),VerifiedRules.Samurai.targets(self,p_idx,card),VerifiedRules.Mountain.targets(self,p_idx,card),VerifiedRules.Maple.targets(self,p_idx,card)]:
		if targets!=null: return targets
	var raccoon_targets=VerifiedRules.Raccoon.targets(self,p_idx,card)
	if raccoon_targets!=null: return raccoon_targets
	var fox_lotus_targets=VerifiedRules.FoxLotus.targets(self,p_idx,card)
	if fox_lotus_targets!=null: return fox_lotus_targets
	var rebirth_targets=VerifiedRules.Rebirth.targets(self,p_idx,card)
	if rebirth_targets!=null: return rebirth_targets
	var moon_targets = VerifiedRules.Moon.targets(self,p_idx,card)
	if moon_targets != null: return moon_targets
	var river_targets = VerifiedRules.River.targets(self, p_idx, card)
	if river_targets != null: return river_targets
	var pipe_fox_targets = VerifiedRules.PipeFox.targets(self, p_idx, card)
	if pipe_fox_targets != null: return pipe_fox_targets
	var charm_targets = VerifiedRules.OwlInsect.targets(self,p_idx,card)
	if charm_targets != null: return charm_targets
	var tree_targets = VerifiedRules.TreeSakura.targets(self, p_idx, card)
	if tree_targets != null: return tree_targets
	var upgrade_targets = VerifiedRules.UpgradeBlessing.targets(self, p_idx, card)
	if upgrade_targets != null: return upgrade_targets
	var fox_suzuka_targets = VerifiedRules.FoxSuzuka.targets(self, p_idx, card)
	if fox_suzuka_targets != null: return fox_suzuka_targets
	var book_jue_targets = VerifiedRules.BookJue.targets(self, p_idx, card)
	if book_jue_targets != null: return book_jue_targets
	var box_targets=VerifiedRules.BoxMaiden.targets(self,p_idx,card)
	if box_targets!=null:return box_targets
	var light_targets = VerifiedRules.Light.targets(self, p_idx, card)
	if light_targets != null: return light_targets
	var rt_targets=VerifiedRules.RabbitTide.targets(self,p_idx,card)
	if rt_targets!=null:return rt_targets
	var sc_targets=VerifiedRules.SugarCat.targets(self,p_idx,card)
	if sc_targets!=null:return sc_targets
	var t: String = card.get("target", "auto")
	var own := player(p_idx)
	var foe := player(enemy_index(p_idx))
	var out: Array = []
	if t in ["any-unit", "any-living-unit", "any-character", "any-living-character"]:
		for owner in [p_idx, enemy_index(p_idx)]:
			for unit in player(owner).units:
				if int(unit.hp) > 0: out.append(unit.uid)
			if t in ["any-character", "any-living-character"]: out.append("avatar-%d" % owner)
	elif t in ["enemy-realm", "ally-realm", "any-realm"]:
		for owner in ([p_idx, enemy_index(p_idx)] if t == "any-realm" else [p_idx if t == "ally-realm" else enemy_index(p_idx)]):
			if owner != p_idx and card.get("type") != "combat" and VerifiedRules.ArmorBlood.realm_veil(self, owner): continue
			for realm in player(owner).realms: out.append(realm.uid)
	elif t == "ally-unit-any-state":
		for unit in own.units: out.append(unit.uid)
	elif t == "enemy-front-unit":
		var front := front_unit(enemy_index(p_idx))
		if not front.is_empty(): out.append(front.uid)
	elif t in ["any-unit-including-knocked", "enemy-unit-including-knocked"]:
		for owner in ([p_idx, enemy_index(p_idx)] if t == "any-unit-including-knocked" else [enemy_index(p_idx)]):
			for unit in player(owner).units:
				if int(unit.level) >= 1: out.append(unit.uid)
	elif t == "ally-unit":
		for i in own.units.size():
			var u: Dictionary = own.units[i]
			if int(u.hp) > 0 and int(u.level) >= 1:
				out.append(u.uid)
	elif t in ["knocked-ally", "knocked-ally-any-level"]:
		for i in own.units.size():
			var u: Dictionary = own.units[i]
			if int(u.hp) <= 0 and (int(u.level) >= 1 or t == "knocked-ally-any-level"):
				out.append(u.uid)
	elif t == "enemy-reserve-unit":
		for unit in foe.units:
			if int(unit.hp) > 0 and int(unit.front) == 0: out.append(unit.uid)
	elif t in ["enemy-character", "enemy-living-character"]:
		for unit in foe.units:
			if int(unit.hp) > 0: out.append(unit.uid)
		out.append("avatar-%d" % enemy_index(p_idx))
	elif t == "enemy-unit":
		for i in foe.units.size():
			var u: Dictionary = foe.units[i]
			if int(u.hp) > 0 and int(u.level) >= 1:
				out.append(u.uid)
		if card.get("combatOption", {}).get("pursuit", false) and front_index(enemy_index(p_idx)) < 0:
			out.append("avatar-%d" % enemy_index(p_idx))
	if card.get("whaleShield", false):
		var src := _source_index(p_idx, card)
		if src >= 0: out.erase(own.units[src].uid)
	out = out.filter(func(uid): return not _unit_by_uid(_all_units(), uid).get("removed", false))
	if card.get("type") != "combat":
		out = out.filter(func(uid): return _unit_index_by_uid(p_idx, uid) >= 0 or not (VerifiedRules.Combat.has(_unit_by_uid(foe.units, uid), "veil") or VerifiedRules.Movement.has_veil(_unit_by_uid(foe.units, uid))))
	if card.get("effect") == "move-unit":
		out = out.filter(func(uid):
			for owner in [p_idx, enemy_index(p_idx)]:
				var unit := _unit_by_uid(player(owner).units, uid)
				if not unit.is_empty():
					return int(unit.front) == 1 or unit.get("summoned", false) or (not VerifiedRules.Combat.has(unit, "remote") and not VerifiedRules.Bingyong.replacement_blocked(self, owner, unit))
			return false)
	if card.has("targetMaxAttack"):
		out = out.filter(func(uid): return int(_unit_by_uid(_all_units(), uid).get("attack", 99999)) <= int(card.targetMaxAttack))
	if card.get("type")!="combat" and VerifiedRules.PipeFox.avatar_veil(self,1-p_idx): out.erase("avatar-%d" % (1-p_idx))
	if card.get("effect") == "himiko-gap": out = out.filter(func(uid): return VerifiedRules.Himiko.valid_gap_target(self, p_idx, uid))
	return VerifiedRules.TomatoFire.targets(self, p_idx, out)


func card_matches_response_window(card: Dictionary) -> bool:
	if response_window.is_empty():
		return false
	if str(card.get("timing", "main")) != "response":
		return false
	var to: Array = card.get("responseTo", []) if card.get("responseTo") is Array else []
	var action := str(response_window.get("action", ""))
	return action in to


func has_playable_response(p_idx: int) -> bool:
	for i in playable_card_count(p_idx):
		var card := hand_card_def(p_idx, i)
		if card.is_empty() or not card_matches_response_window(card):
			continue
		var targets: Array = [null] if card.get("target", "auto") == "auto" else valid_targets(p_idx, card)
		for target in targets:
			if can_play_card(p_idx, i, target).ok:
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


func instant_count(p_idx: int) -> int:
	var usage: Dictionary = player(p_idx).get("keywordUsage", {}).get("instant", {})
	return int(usage.get("count", 1 if usage.get("used", false) else 0))


func instant_limit(p_idx: int) -> int:
	return 2 if VerifiedRules.Himiko.extra_instant(self, p_idx) else 1


func instant_available(p_idx: int) -> bool:
	return phase != "opening" and instant_count(p_idx) < instant_limit(p_idx)


func consume_instant(p_idx: int) -> void:
	var usage := kw_usage(p_idx, "instant")
	usage.count = instant_count(p_idx) + 1
	usage.used = true


func card_payment(p_idx: int, card: Dictionary) -> Dictionary:
	# Read-only quote shared by legality, payment, AI and presentation. A natural
	# zero-cost instant and an automatic response both use this turn's allowance.
	var instant: bool = not card.get("handCharmNoInstant",false) and (_kw(card, "instant") or VerifiedRules.Raccoon.instant(self,p_idx,card))
	var three_tail_free: bool = not card.get("neutralFood",false) and not card.get("neutralEssence",false) and VerifiedRules.ThreeTail.free_first(self,p_idx)
	var coin_free: bool = card.get("coinFirstFree", false)
	var deck_free: bool = card.get("lilyDeckFree", false) or card.get("twoFacesDeckFree",false) or card.get("yanmieFree", false)
	var treasure_discount := VerifiedRules.Treasure.discount(self, p_idx, card)
	var chen_free: bool = card.get("chenAwakenedFree", false) or card.get("chenCopyFree", false)
	var insight_free := VerifiedRules.Astral.neutral_free(self, p_idx, card) or chen_free
	var gift_fire := VerifiedRules.GiftEnergy.free_fire(self, p_idx, card)
	var forest_free := VerifiedRules.ForestSpirit.free_cast(self, p_idx, card)
	if forest_free: gift_fire.baseFree = true
	var poet_free: bool = card.get("poetFree", false) or int(player(p_idx).get("poetNextFreeTurn", -1)) == turn_counter
	var uses_instant: bool = not card.get("nineFree",false) and not poet_free and not card.get("chiliHandFree", false) and not gift_fire.get("baseFree", false) and instant and instant_available(p_idx) and not coin_free and treasure_discount == 0 and not insight_free and not card.get("yanmieFree", false)
	var payment := {"cost": (0 if three_tail_free else 0 if deck_free or card.get("headlessFree",false) or card.get("puppetFree",false) else (0 if uses_instant or coin_free or treasure_discount > 0 or insight_free or gift_fire.get("baseFree", false) or card.get("chiliHandFree", false) or poet_free else int(card.get("cost", 0))) + VerifiedRules.TomatoFire.extra_cost(self, p_idx, card)) + VerifiedRules.Jorogumo.card_tax(self,p_idx,card),
		"baseCost": int(card.get("cost", 0)), "instant": instant, "usesInstant": uses_instant, "treasureDiscount": treasure_discount, "chenAwakenedFree": card.get("chenAwakenedFree", false),
		"coinFirstFree": coin_free, "threeTailFirstFree": three_tail_free, "lilyDeckFree": deck_free,
		"instantUsed": instant_count(p_idx) >= instant_limit(p_idx), "instantLimit": instant_limit(p_idx),
		"ownTurn": current_player == p_idx, "response": not response_window.is_empty()}
	if gift_fire.get("sunny", false): payment.giftSunnyFree = true
	if forest_free: payment.forestFree = true
	payment=VerifiedRules.Cooking.payment(self,p_idx,card,payment)
	payment=VerifiedRules.Zhenjian.payment(self,p_idx,card,payment)
	payment=VerifiedRules.HairPower.quote(self,p_idx,card,payment)
	payment = VerifiedRules.Wave7Reworks.quote_lamp(self, p_idx, card, payment)
	payment = VerifiedRules.Hanafuda.chain_payment(self, p_idx, card, payment)
	payment = VerifiedRules.Focus.quote(self, p_idx, card, payment)
	payment.cost += VerifiedRules.CoopMiddle.extra_cost(self, p_idx)
	return payment


func effective_card_cost(p_idx: int, card: Dictionary) -> int:
	return int(card_payment(p_idx, card).cost)


func card_play_modes(p_idx: int, hand_index: int) -> Array:
	var card := hand_card_def(p_idx, hand_index)
	if card.get("type") == "coop": return VerifiedRules.Cooperation.modes(card)
	return VerifiedRules.GiftEnergy.modes(card)


func playable_card(p_idx: int, hand_index: int, use_origin: Variant = false) -> Dictionary:
	var card := hand_card_def(p_idx, hand_index)
	if card.get("type") == "coop":
		if use_origin is String:
			var face := VerifiedRules.Cooperation.face(self, p_idx, card, use_origin)
			if not face.is_empty():
				var inst := card_instance(p_idx, hand_index)
				face = VerifiedRules.UpgradeBlessing.describe_card(self, p_idx, inst, face)
				face = VerifiedRules.BondDream.describe_card(self, p_idx, inst, face)
				return VerifiedRules.HandBlessing.describe_card(self, p_idx, inst, face)
		return {}
	if use_origin is String:
		if use_origin in card.get("nativePlayModes", []): return VerifiedRules.ZenMisfortune.mode(card, use_origin)
		return VerifiedRules.GiftEnergy.as_gift(self, p_idx, card_instance(p_idx, hand_index), card, use_origin)
	if use_origin:
		var origin: Dictionary = card.get("originCard", {}).duplicate(true)
		if origin.is_empty(): return {}
		origin.w7Origin = true
		origin = VerifiedRules.Cotton.describe_card(self, p_idx, card_instance(p_idx, hand_index), origin)
		if card.get("chiliHandFree", false): origin.chiliHandFree = true
		var inst := card_instance(p_idx, hand_index)
		origin = VerifiedRules.LineageScroll.describe(self, p_idx, inst, origin)
		origin = VerifiedRules.FactionArt.describe(self, p_idx, inst, origin)
		if card.get("yanmieFromDeck", false): return VerifiedRules.YanmieTrio.top_card(origin)
		if card.get("yanmieFree", false): origin.yanmieFree = true
		origin = VerifiedRules.SpiderLily.describe_card(self, p_idx, inst, origin, not card.get("insightFromZone", false) and hand_index == player(p_idx).hand.size() and VerifiedRules.SpiderLily.top_available(self,p_idx), bool(inst.get("twoFacesFromDeck",false)))
		return VerifiedRules.Insight.describe(self, p_idx, inst, VerifiedRules.WaterMoon.describe(self, p_idx, origin), card.get("insightFromZone", false))
	return card


func can_play_card(p_idx: int, hand_index: int, target_id: Variant = null, use_origin: Variant = false, ignore_hand_restriction: bool = false) -> Dictionary:
	if VerifiedRules.Link.ready_hand(self,p_idx)>=0 and VerifiedRules.Link.ready_hand(self,p_idx)!=hand_index:return {"ok":false,"reason":"请先完成已选择的连引牌。"}
	if phase == "opening":
		return {"ok": false, "reason": "请先确认起手牌。"}
	if winner >= 0:
		return {"ok": false, "reason": "对局已经结束。"}
	if not pending_choice.is_empty():
		return {"ok": false, "reason": "请先完成当前选择。"}
	if not response_window.is_empty():
		if int(response_window.get("playerIndex", -1)) != p_idx:
			return {"ok": false, "reason": "等待对手决定是否响应。"}
	elif current_player != p_idx:
		return {"ok": false, "reason": "等待对手完成行动。"}
	# 响应窗口中不走升勾门槛（对手回合 isUpgradePending 恒 false；己方窗口由 JS 语义同样放行响应牌）
	if response_window.is_empty() and is_upgrade_pending(p_idx):
		return {"ok": false, "reason": "升级阶段：请先选择一名角色提升勾玉。"}
	var p := player(p_idx)
	if card_instance(p_idx, hand_index).is_empty():
		return {"ok": false, "reason": "没有找到这张牌。"}
	var card := playable_card(p_idx, hand_index, use_origin)
	if card.is_empty():
		if hand_card_def(p_idx, hand_index).get("type") == "coop":
			return {"ok": false, "reason": "请先选择协战牌的使用式神。"}
		return {"ok": false, "reason": "未知卡牌。"}
	if card.get("nonHandDerivative", false):
		return {"ok": false, "reason": "「%s」是%s，只能由对应效果产生。" % [card.name, card.typeLabel]}
	if not response_window.is_empty() and not card_matches_response_window(card):
		return {"ok": false, "reason": "响应窗口中只能使用符合触发条件的响应牌。"}
	if not VerifiedRules.Insight.allowed(self, p_idx, card): return {"ok": false, "reason": VerifiedRules.Insight.block_reason(self, p_idx, card)}
	if card.get("luohouMalefic", false):
		if not ignore_hand_restriction and VerifiedRules.KoiFragrance.restricted(self, p_idx, card): return {"ok": false, "reason": "缚梦明香：请先使用蚀印牌。"}
		return VerifiedRules.Luohou.can_play_malefic(self, p_idx, card, target_id)
	if card.get("shopNeutral", false): return VerifiedRules.BattleShop.can_play_neutral(self, p_idx, card, target_id)
	if card.get("insightNeutral", false): return VerifiedRules.Insight.can_use_neutral(self, p_idx, card, target_id)
	if card.get("neutralEssence",false):
		if not ignore_hand_restriction and VerifiedRules.KoiFragrance.restricted(self,p_idx,card):return {"ok":false,"reason":"缚梦明香：请先使用蚀印牌。"}
		return VerifiedRules.EssenceFeast.can_play_essence(self,p_idx,hand_index,target_id)
	if card.get("neutralFood",false):
		if not ignore_hand_restriction and VerifiedRules.KoiFragrance.restricted(self,p_idx,card):return {"ok":false,"reason":"缚梦明香：请先使用蚀印牌。"}
		return VerifiedRules.Cooking.can_play_food(self,p_idx,hand_index,target_id)
	var cost := effective_card_cost(p_idx, card)
	if int(p.energy) < cost:
		return {"ok": false, "reason": "鬼火不足：需要 %d，当前 %d。" % [cost, int(p.energy)]}
	var src := _source_index(p_idx, card)
	if src < 0:
		return {"ok": false, "reason": "缺少所属角色。"}
	var su: Dictionary = p.units[src]
	if VerifiedRules.UpgradeBlessing.card_blocked(self, su, card):
		return {"ok": false, "reason": "福笹：此式神本回合不能使用幻境、形态或觉醒牌。"}
	if su.get("baseRulesSuppressed", false):
		return {"ok": false, "reason": "纸人变形期间无法使用原式神的卡牌。"}
	if int(su.hp) <= 0 and not card.get("allowKnockedSource", false):
		return {"ok": false, "reason": "%s 已气绝，无法使用其牌。" % su.name}
	if int(su.level) < int(card.get("level", 1)):
		return {"ok": false, "reason": "%s 勾玉不足，需要 %d 勾。" % [su.name, int(card.get("level", 1))]}
	if VerifiedRules.Stun.blocks(self,p_idx,su,card):
		return {"ok": false, "reason": "%s 处于眩晕，无法使用此牌。" % su.name}
	if card.get("type") == "combat" and not VerifiedRules.CatSamurai.bodyless(self, su) and not su.has("waveIbarakiGhost") and not card.get("goldfishAttachmentReplacement",false) and not card.get("yitiaoReviveReplacement",false) and not (_kw(card, "remote") or VerifiedRules.Combat.has(su, "remote")) and VerifiedRules.Bingyong.replacement_blocked(self, p_idx, su):
		return {"ok": false, "reason": "尘缚之阵：战斗区式神不能被其他式神替换。"}
	if card.has("chargeCost") and not VerifiedRules.SunSmoke.can_pay_charge(self, p_idx, src, int(card.get("chargeCost", 0))):
		return {"ok": false, "reason": "充能不足：需要 %d，%s 当前为 %d。" % [int(card.chargeCost), su.name, int(su.get("charge", 0))]}
	if not VerifiedRules.GiftEnergy.can_use(self, p_idx, src, card): return {"ok":false,"reason":"赐能条件未满足，或能量不足。"}
	if not VerifiedRules.DragonAbyss.can_use(self, p_idx, card): return {"ok": false, "reason": "本牌所需条件未满足。"}
	if not VerifiedRules.HandBlessing.can_use(card): return {"ok":false,"reason":"被蚀印的形态生命不大于0。"}
	if not VerifiedRules.Yujiazhu.can_use(self,p_idx,card):return {"ok":false,"reason":"御馔津已觉醒或符箭爆能不能支付。"}
	if not VerifiedRules.FearWing.can_use(self,p_idx,card):return {"ok":false,"reason":"天逆每已经觉醒。"}
	if not VerifiedRules.WisdomLamp.can_use(self,p_idx,card):return {"ok":false,"reason":"慧明灯已经觉醒。"}
	var ly_block := VerifiedRules.Langya.play_block(self, p_idx, src, card)
	if not ly_block.is_empty(): return {"ok": false, "reason": ly_block}
	if card.get("awakeningCard", false) and su.awakened and not card.get("w7Reawaken", false) and not card.get("allowRepeatAwakening", false): return {"ok": false, "reason": "式神已经觉醒。"}
	if card.id == "c61704" and su.awakened: return {"ok": false, "reason": "荒·启命已经觉醒。"}
	if card.id == "c62305" and su.awakened and int(p.get("solarLightBonus", 0)) > 0: return {"ok": false, "reason": "天照已觉醒且天晖已强化。"}
	if card.id == "c62607" and su.awakened: return {"ok": false, "reason": "盗人神已经觉醒。"}
	if card.id == "c62805" and su.awakened: return {"ok": false, "reason": "鬼使黑已经觉醒。"}
	if not VerifiedRules.HairPower.can_use(self,p_idx,card):return {"ok":false,"reason":"食发鬼已经觉醒。"}
	if not VerifiedRules.BaizeYuanqi.can_use(self, p_idx, card): return {"ok": false, "reason": "需要一张可置顶的其他手牌。"}
	if not VerifiedRules.MusicFire.can_use(self,p_idx,card):return {"ok":false,"reason":"紧那罗已经觉醒，或当前无神火铃焰可响应。"}
	if not VerifiedRules.EssenceFeast.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}
	if not VerifiedRules.Cooking.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}
	if not VerifiedRules.SerpentGhost.can_use(self,p_idx,card):return {"ok":false,"reason":"当前身份不能手动使用此牌，或爆能无法支付。"}
	if not VerifiedRules.Coffin.can_use(self, p_idx, card): return {"ok": false, "reason": "没有可以变为棺材的气绝式神。"}
	if not VerifiedRules.Commission.can_use(self, p_idx, card): return {"ok": false, "reason": "委托条件未达成，或没有可整理的紧急委托。"}
	if not VerifiedRules.TimeRewind.can_use(self, p_idx, src, card): return {"ok": false, "reason": "没有可复原的铭刻或可复活的式神。"}
	if not VerifiedRules.SugarCat.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}
	if not VerifiedRules.RabbitTide.can_use(self,p_idx,card):return {"ok":false,"reason":"缺少海原贝戟或式神已经觉醒。"}
	if not VerifiedRules.Arakawa.can_use(self,p_idx,card):return {"ok":false,"reason":"荒川之主已有蓄力。"}
	if not VerifiedRules.RednightWalnut.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}
	if not VerifiedRules.Zhenjian.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}
	if not VerifiedRules.ChargedPair.can_use(self,p_idx,card):return {"ok":false,"reason":"该式神已有蓄力，或当前不能蓄力。"}
	if not VerifiedRules.MirrorSong.can_use(self,p_idx,card):return {"ok":false,"reason":"已经觉醒或缺少被指挥的合法式神。"}
	if not VerifiedRules.Yi.can_use(self,p_idx,card):return {"ok":false,"reason":"弈已觉醒或没有可选择的真实卡牌。"}
	if not VerifiedRules.Mianqiling.can_use(self,p_idx,card):return {"ok":false,"reason":"面灵气已经觉醒。"}
	if not VerifiedRules.Futakuchi.can_use(self,p_idx,card):return {"ok":false,"reason":"二口女已经觉醒。"}
	if not VerifiedRules.BoxMaiden.can_use(self,p_idx,card):return {"ok":false,"reason":"匣中少女已经觉醒。"}
	if not VerifiedRules.BlackWhite.can_use(self,p_idx,card):return {"ok":false,"reason":"黑白童子已经觉醒。"}
	if not VerifiedRules.TwoFaces.can_use(self,p_idx,card):return {"ok":false,"reason":"两面佛已经觉醒。"}
	if not VerifiedRules.Lantern.can_use(self,p_idx,card): return {"ok":false,"reason":"古笼火已经觉醒、正在蓄力或无法复活。"}
	if not VerifiedRules.SeaButterfly.can_use(self,p_idx,card): return {"ok":false,"reason":"灵海蝶已经觉醒。"}
	if not VerifiedRules.SilkNinja.can_use(self,p_idx,card): return {"ok":false,"reason":"此觉醒已使用。"}
	if not VerifiedRules.Toxic.can_use(self,p_idx,card): return {"ok":false,"reason":"当前不能使用此剧毒牌。"}
	if not ignore_hand_restriction and VerifiedRules.KoiFragrance.restricted(self,p_idx,card): return {"ok":false,"reason":"缚梦明香：请先使用一张可用的蚀印手牌。"}
	if not VerifiedRules.KoiFragrance.can_use(self,p_idx,card): return {"ok":false,"reason":"此式神已经觉醒。"}
	if not VerifiedRules.Susanoo.can_use(self,p_idx,card): return {"ok":false,"reason":"须佐之男无法觉醒或未满足复活条件。"}
	if not VerifiedRules.Baize.can_use(self,p_idx,card): return {"ok":false,"reason":"白泽已经觉醒。"}
	if not VerifiedRules.Crocodile.can_use(self,p_idx,card): return {"ok":false,"reason":"影鳄已经觉醒。"}
	if not VerifiedRules.Whale.can_use(self,p_idx,card): return {"ok":false,"reason":"化鲸已觉醒或所选爆能不可支付。"}
	if not VerifiedRules.Jorogumo.can_use(self,p_idx,card): return {"ok":false,"reason":"络新妇已经觉醒。"}
	if not VerifiedRules.Yitiao.can_use(self,p_idx,card): return {"ok":false,"reason":"一条已经觉醒或当前不能复活。"}
	if not VerifiedRules.Garuda.can_use(self,p_idx,card): return {"ok":false,"reason":"迦楼罗已经觉醒。"}
	if not VerifiedRules.Butterfly.can_use(self,p_idx,card): return {"ok":false,"reason":"蝴蝶精已经觉醒。"}
	if not VerifiedRules.Cotton.can_use(self,p_idx,card): return {"ok":false,"reason":"一反木绵已经觉醒。"}
	if not VerifiedRules.SpiderLily.can_use(self,p_idx,card): return {"ok":false,"reason":"彼岸花已经觉醒。"}
	if not VerifiedRules.ThreeTail.can_use(self,p_idx,card): return {"ok":false,"reason":"未满足卡牌使用条件或缺少合法目标。"}
	if not VerifiedRules.Glutton.can_use(self,p_idx,card): return {"ok":false,"reason":"未满足卡牌使用条件或缺少合法目标。"}
	if not VerifiedRules.Doll.can_use(self,p_idx,card): return {"ok":false,"reason":"未满足卡牌使用条件或缺少合法目标。"}
	if not VerifiedRules.Onikiri.can_use(self,p_idx,card): return {"ok":false,"reason":"鬼切当前不能使用此牌。"}
	if not VerifiedRules.Otakemaru.can_use(self,p_idx,card): return {"ok":false,"reason":"缺少持玉友军或合法目标。"}
	if not VerifiedRules.House.can_use(self,p_idx,card): return {"ok":false,"reason":"没有可移除的护甲或破甲。"}
	if not VerifiedRules.Goldfish.can_use(self,p_idx,card): return {"ok":false,"reason":"金鱼姬当前不能使用此牌。"}
	if not VerifiedRules.Vine.can_use(self,p_idx,card): return {"ok":false,"reason":"缺少可移除的战斗区召唤物或合法目标。"}
	if not VerifiedRules.WindRaccoon.can_use(self,p_idx,card): return {"ok":false,"reason":"风狸当前不能使用此牌。"}
	if not VerifiedRules.Puppet.can_use(self,p_idx,card): return {"ok":false,"reason":"傀儡师当前不能使用此牌。"}
	if not VerifiedRules.Enma.can_use(self,p_idx,card): return {"ok":false,"reason":"阎魔当前不能使用此牌或缺少魂鬼。"}
	if not VerifiedRules.Weaver.can_use(self,p_idx,card): return {"ok":false,"reason":"缺少可复活或可攻击的召唤物。"}
	if not VerifiedRules.Sparrow.can_use(self,p_idx,card): return {"ok":false,"reason":"入内雀当前不能觉醒或复活。"}
	if not VerifiedRules.Headless.can_use(self,p_idx,card): return {"ok":false,"reason":"首无当前不能使用此牌。"}
	if not VerifiedRules.Yaksha.can_use(self,p_idx,card): return {"ok":false,"reason":"夜叉当前不能觉醒或复活。"}
	if not VerifiedRules.StarBear.can_use(self,p_idx,card): return {"ok":false,"reason":"离间之音：激怒式神不能使用手牌。"}
	if not VerifiedRules.Pine.can_use(self,p_idx,card): return {"ok":false,"reason":"小松丸已觉醒或无法使用此牌。"}
	if not VerifiedRules.Paint.can_use(self,p_idx,card): return {"ok":false,"reason":"当前无法使用花鸟卷牌。"}
	if not VerifiedRules.Samurai.can_use(self,p_idx,card): return {"ok":false,"reason":"武士之灵当前状态不能使用此牌。"}
	if not VerifiedRules.CatSamurai.can_use(self, p_idx, card): return {"ok": false, "reason": "猫侍当前状态不能使用此牌。"}
	if not VerifiedRules.FortunateDuo.can_use(self, p_idx, card): return {"ok": false, "reason": "黄金六曜骰只能存在一个。"}
	if card.get("factionResponseOnly", false): return {"ok": false, "reason": "万阵破只能自动响应使用。"}
	if not VerifiedRules.PeachGrove.can_use(self, p_idx, card): return {"ok": false, "reason": "卡牌触发条件未满足。"}
	if not VerifiedRules.Wave7Reworks.can_use(self, p_idx, card): return {"ok": false, "reason": "当前式神形态不能使用此牌。"}
	if not VerifiedRules.Luohou.can_use(self, p_idx, card, card_instance(p_idx, hand_index)): return {"ok": false, "reason": "需要另一张可以弃置的手牌。"}
	if not VerifiedRules.Hanafuda.can_use(self, p_idx, card): return {"ok": false, "reason": "未满足此牌的气绝或觉醒条件。"}
	if not VerifiedRules.Mountain.can_use(self,p_idx,card): return {"ok":false,"reason":"场上没有可选择的不见岳幻境。"}
	if not VerifiedRules.Rebirth.can_use(self,p_idx,card): return {"ok":false,"reason":"此牌需要满足不能复活或仅气绝时可用的条件。"}
	if not VerifiedRules.Bamboo.can_use(self,p_idx,card): return {"ok":false,"reason":"牌库中没有辉夜姬幻境。"}
	if not VerifiedRules.Movement.can_use(self, p_idx, card):
		return {"ok": false, "reason": "能量不足或爆能档位无效。"}
	if not VerifiedRules.DogDemon.can_use(self, p_idx, card):
		return {"ok": false, "reason": "此牌仅在所属式神气绝时可用。"}
	if not VerifiedRules.Light.can_use(self, p_idx, card):
		return {"ok": false, "reason": "百闻一得需要弃掉一张明灯。"}
	if not VerifiedRules.Panguan.can_use(self, p_idx, card):
		return {"ok": false, "reason": "生死无常需要双方战斗区都有式神。"}
	if not VerifiedRules.Huang.can_use(self, p_idx, card):
		return {"ok": false, "reason": "余辉需要弃掉一张幻境手牌。"}
	if not VerifiedRules.MonkCleaner.can_use(self, p_idx, card):
		return {"ok": false, "reason": "此牌无法令所属式神进入战斗区。"}
	if not VerifiedRules.Crab.can_use(self, p_idx, card):
		return {"ok": false, "reason": "睡觉觉需要另一张蟹姬手牌。"}
	if not VerifiedRules.Mengpo.can_use(self, p_idx, card):
		return {"ok": false, "reason": "没有当前等级允许选择牌名的敌方式神。"}
	var t: String = card.get("target", "auto")
	if t == "auto" and target_id != null and card.get("effect") != "assault":
		return {"ok": false, "reason": "请选择一个有效目标。"}
	if t != "auto":
		var opts := valid_targets(p_idx, card)
		if target_id == null or not opts.has(target_id):
			return {"ok": false, "reason": "请选择一个有效目标。"}
	return {"ok": true, "reason": "", "card": card, "source_index": src}


func play_card(p_idx: int, hand_index: int, target_id: Variant = null, use_origin: Variant = false) -> bool:
	if not use_origin and card_instance(p_idx,hand_index).get("definitionId","")=="shengmingjinghua":return VerifiedRules.EssenceFeast.play_essence(self,p_idx,hand_index,target_id)
	if not use_origin and not VerifiedRules.Cooking.food_kind(card_instance(p_idx,hand_index)).is_empty():return VerifiedRules.Cooking.play_food(self,p_idx,hand_index,target_id)
	if not use_origin and VerifiedRules.Link.start(self,p_idx,hand_index):return true
	var check := can_play_card(p_idx, hand_index, target_id, use_origin)
	if not check.ok:
		_log(str(check.reason), TONE_DANGER)
		return false
	var card: Dictionary = check.card.duplicate(true)
	if card.get("shopNeutral", false) or card.get("luohouMalefic", false): return VerifiedRules.BattleShop.play_neutral(self, p_idx, hand_index, target_id, card)
	if card.get("insightNeutral", false): return VerifiedRules.Insight.play_neutral(self, p_idx, hand_index, target_id, card)
	var src: int = check.source_index
	var p := player(p_idx)
	var inst := card_instance(p_idx, hand_index)
	card.usedFromHand = not card.get("insightFromZone", false) and hand_index < p.hand.size() and not inst.get("linkVirtual", false)
	if card.get("insightFromZone", false) or card.get("astralReturn", false) or card.id == "c63608" or (card.usedFromHand and VerifiedRules.SandBook.source(self, 1-p_idx) >= 0): card.playedInstance = inst.duplicate(true)
	if card.get("hfBounce", false) or card.get("himikoBounce", false) or card.id == VerifiedRules.Xuan.WISH_CARD: card.playedInstance = inst.duplicate(true)
	var is_response := not response_window.is_empty()
	var response_depth := 0
	var response_ctx := response_window.duplicate(true)
	if is_response:
		response_depth = int(response_ctx.get("depth", 0)) + 1
	var record_args := {"hand": hand_index, "target": target_id, "card": inst.definitionId}
	if card.get("insightFromZone", false): record_args.merge({"sourceZone": "insight", "instanceId": inst.instanceId})
	if card.get("lilyFromDeck", false) or card.get("twoFacesFromDeck", false) or card.get("yanmieFromDeck", false): record_args.sourceZone = "deck"; record_args.instanceId = inst.instanceId
	var payment := card_payment(p_idx, card)
	if card.get("chargedSelected",false):return VerifiedRules.ChargedPair.store_hand(self,p_idx,hand_index,card,payment,target_id)
	if card.get("chargeOnly",false):return VerifiedRules.Lantern.store_card(self,p_idx,hand_index,card,payment)
	VerifiedRules.Focus.commit(self,p_idx,card,payment)
	VerifiedRules.Treasure.pay(self, p_idx, payment)
	if payment.get("chenAwakenedFree", false): p.chenNextFree = false
	VerifiedRules.HairPower.pay(self,p_idx,payment)
	VerifiedRules.Hanafuda.pay_chain(self, p_idx, card, payment)
	VerifiedRules.Wave7Reworks.pay_lamp(self, p_idx, card, payment)
	record_args.payment = payment.duplicate()
	card.paidFire = int(payment.cost)
	if card.has("coopFaceId"): record_args.coopFace = card.coopFaceId
	elif use_origin is String: record_args.giftMode = use_origin
	elif use_origin: record_args.origin = true
	if card.get("verifiedRules", false) or card.get("blessingInstant", false) or card.get("lilyFromDeck", false) or card.get("lilyRoadDamage", 0) > 0: record_args.cardView = card.duplicate(true)
	_record("play_card", record_args, p_idx)
	_set_fire(p_idx,int(p.energy)-int(payment.cost),true)
	VerifiedRules.BoxMaiden.pay_card(self,p_idx,src,card)
	VerifiedRules.Moon.consume_card(self,card)
	if payment.usesInstant:
		consume_instant(p_idx)
	take_card_instance(p_idx, hand_index)
	if card.get("yanmieFromDeck", false): p.yanmieTopUsedTurn = turn_counter
	VerifiedRules.GiftEnergy.remember(self, p_idx, inst, card.get("giftEnergyMode", false))
	VerifiedRules.GiftEnergy.used(self, p_idx, src, card, inst, payment)
	if payment.get("forestFree", false): p.forestFreeTurn = turn_counter
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
	_record("pass_response", {"player": p_idx}, p_idx)
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


func _push_card_frames(p_idx: int, definition_id: String, target_id, card: Dictionary, src: int, response_depth: int, automatic: bool = false, combat_response_id: int = -1) -> void:
	card=VerifiedRules.Focus.automatic(self,p_idx,card,automatic)
	card=VerifiedRules.Yi.prepare_instance(self,p_idx,card,automatic)
	card=VerifiedRules.ChargedPair.prepare_card(self,p_idx,src,card)
	card=VerifiedRules.Zhenjian.prepare_card(self,p_idx,src,card)
	var fire_frames := VerifiedRules.Moon.card_frames(self,p_idx)
	var rid := next_resolution_id
	next_resolution_id += 1
	var base := {
		"resolutionId": rid,
		"playerIndex": p_idx,
		"definitionId": definition_id,
		"targetId": target_id,
		"sourceIndex": src,
		"responseDepth": response_depth,
		"usedFromHand": bool(card.get("usedFromHand", false)),
		"paidFire": int(card.get("paidFire", -1)),
		"automatic": automatic,
		"combatResponseId": combat_response_id,
		"affectedUnits": [],
	}
	if automatic or card.get("verifiedRules", false) or card.has("playedInstance") or card.has("sourceZone") or str(card.get("id", "")) != definition_id: base.cardOverride = card.duplicate(true)
	var effects := _effect_list(card)
	var complete := {
		"kind": "card-complete",
		"respondable": false,
		"responseOffered": false,
	}
	complete.merge(base, true)
	if not automatic: VerifiedRules.Rebirth.queue_incarnation(self,p_idx,false)
	resolution_stack.append(complete)
	# LIFO：先压靠后的效果
	for i in range(effects.size() - 1, -1, -1):
		var fr := {
			"kind": "card-effect",
			"effectIndex": i,
			"respondable": not automatic and i == 0 and response_depth < MAX_RESPONSE_DEPTH,
			"responseOffered": false,
		}
		fr.merge(base, true)
		resolution_stack.append(fr)
	var start := {"kind": "card-start", "respondable": false}
	start.merge(base, true)
	resolution_stack.append(start)
	resolution_stack.append_array(fire_frames)
	var announce := base.duplicate(true)
	announce.kind = "card-announce"
	resolution_stack.append(announce)
	VerifiedRules.MirrorSong.pre_card_frames(self,p_idx,src,card)
	VerifiedRules.ThreeTail.card_used(self,p_idx,src,card,automatic)
	if resolution_stack.size() > MAX_RESOLUTION_STACK_LENGTH:
		_log("结算栈超过安全上限。", TONE_DANGER)
		resolution_stack.clear()


func _create_response_window(frame: Dictionary) -> Dictionary:
	var card: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.get("definitionId", ""))))
	var effects := _effect_list(card)
	var idx := int(frame.get("effectIndex", 0))
	var effect: Dictionary = effects[idx] if idx >= 0 and idx < effects.size() else {}
	# A source-specific executor still exposes the underlying effect class to
	# existing response cards. Choosing a friendly point-light target is growth.
	var action := str(effect.get("action", ""))
	action = str(card.get("responseAction", action))
	var response_actions := {"baize-projectile":"damage","baize-revive":"revive","phoenix-ignite": "damage", "damage-character": "damage", "peach-heal": "heal", "peach-revive": "revive", "peach-revive-all": "revive-all", "firefly-flash": "set-attack-zero-this-turn", "butterfly-enrage": "damage", "garuda-mark-hand": "assault", "garuda-combat": "assault", "garuda-aoe": "damage", "yitiao-skill-grow": "assault", "yitiao-combat": "assault", "yitiao-alone": "buff-stats", "yitiao-cover": "shield", "yitiao-revive": "revive", "jorogumo-needle": "damage", "jorogumo-combat": "assault", "jorogumo-aoe": "damage", "jorogumo-exterminate": "damage"}
	if action == "butterfly-dream":
		var dream_target := _unit_by_uid(player(int(frame.playerIndex)).units, frame.get("targetId"))
		action = "revive" if int(dream_target.get("hp",1)) <= 0 else "assault"
	elif action == "firefly-dual-target":
		action = "buff-stats" if _unit_index_by_uid(int(frame.playerIndex), frame.get("targetId")) >= 0 else "damage"
	else: action = str(response_actions.get(action, action))
	return {
		"id": "response-%s-%s" % [frame.get("resolutionId"), frame.get("responseDepth")],
		"playerIndex": 1 - int(frame.get("playerIndex", 0)),
		"sourcePlayerIndex": int(frame.get("playerIndex", 0)),
		"resolutionId": int(frame.get("resolutionId", -1)),
		"definitionId": str(frame.get("definitionId", "")),
		"action": action,
		"target": str(effect.get("target", "")),
		"targetId": frame.get("targetId"),
		"consecutivePasses": 0,
		"depth": int(frame.get("responseDepth", 0)),
	}


func _resolve_resolution_stack() -> void:
	if is_resolving or not response_window.is_empty() or not pending_choice.is_empty():
		return
	is_resolving = true
	while not resolution_stack.is_empty() and winner < 0:
		VerifiedRules.Yi.promote(self)
		VerifiedRules.MirrorSong.promote(self)
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
		VerifiedRules.Arakawa.refresh_hold(self)
		VerifiedRules.Crab.clear_finished_immunity(self)
		VerifiedRules.BondDream.refresh(self)
		VerifiedRules.MonkCleaner.refresh(self)
		VerifiedRules.BlueGreen.refresh(self)
		VerifiedRules.OwlInsect.refresh(self)
		VerifiedRules.Xuenv.remove_departed_walls(self)
		VerifiedRules.TomatoFire.remove_departed(self)
		VerifiedRules.SunSmoke.remove_departed(self)
		VerifiedRules.GiftEnergy.remove_departed(self)
		VerifiedRules.Bamboo.remove_departed(self)
		VerifiedRules.Paint.remove_departed(self)
		VerifiedRules.Pine.remove_departed(self)
		VerifiedRules.Rain.remove_departed(self)
		for side in players.size(): VerifiedRules.NativeSummons.remove_departed(self, side)
		VerifiedRules.Enma.remove_departed(self)
		VerifiedRules.Weaver.remove_departed(self)
		VerifiedRules.Vine.remove_departed(self)
		VerifiedRules.WindRaccoon.remove_departed(self)
		VerifiedRules.BoxMaiden.remove_departed(self)
		VerifiedRules.House.remove_departed(self)
		VerifiedRules.Doll.remove_departed(self)
		VerifiedRules.Jorogumo.remove_departed(self)
		VerifiedRules.Whale.remove_departed(self)
		VerifiedRules.MusicFire.remove_departed(self)
		VerifiedRules.SerpentGhost.refresh(self)
		VerifiedRules.SugarCat.remove_departed(self)
		VerifiedRules.EssenceFeast.remove_departed(self)
		VerifiedRules.RabbitTide.remove_departed(self)
		if not pending_choice.is_empty():
			is_resolving = false
			return
	is_resolving = false
	if response_window.is_empty():
		phase = "main"


func _resolve_frame(frame: Dictionary) -> void:
	if VerifiedRules.CoopFirst.resolve_frame(self, frame): return
	if VerifiedRules.CoopMiddle.resolve_frame(self, frame): return
	if VerifiedRules.CoopLate.resolve_frame(self, frame): return
	if VerifiedRules.Grudge.resolve_frame(self, frame): return
	if VerifiedRules.BaizeYuanqi.resolve_frame(self, frame): return
	if VerifiedRules.StarRealms.resolve_frame(self, frame): return
	if VerifiedRules.DuskCycle.resolve_frame(self, frame): return
	if VerifiedRules.PeachGrove.resolve_frame(self, frame): return
	if VerifiedRules.DragonAbyss.resolve_frame(self, frame): return
	if VerifiedRules.PaperDance.resolve_frame(self, frame): return
	if VerifiedRules.TwinSight.resolve_frame(self, frame): return
	if VerifiedRules.SandBook.resolve_frame(self, frame): return
	if VerifiedRules.Treasure.resolve_frame(self, frame): return
	if VerifiedRules.Insight.resolve_frame(self, frame): return
	if VerifiedRules.Astral.resolve_frame(self, frame): return
	if VerifiedRules.Bone.resolve_frame(self, frame): return
	if VerifiedRules.WaterMoon.resolve_frame(self, frame): return
	if VerifiedRules.LunarTrick.resolve_frame(self, frame): return
	if VerifiedRules.LineageScroll.resolve_frame(self, frame): return
	if VerifiedRules.DragonFlow.resolve_frame(self, frame): return
	if VerifiedRules.ZenMisfortune.resolve_frame(self, frame): return
	if VerifiedRules.Blueprint.resolve_frame(self, frame): return
	if VerifiedRules.NineTails.resolve_frame(self, frame): return
	if VerifiedRules.FortuneCat.resolve_frame(self, frame): return
	if VerifiedRules.WindCharm.resolve_frame(self, frame): return
	if VerifiedRules.FactionArt.resolve_frame(self, frame): return
	if VerifiedRules.Wave7Reworks.resolve_frame(self, frame): return
	if VerifiedRules.Hanafuda.resolve_frame(self, frame): return
	if VerifiedRules.Xuan.resolve_frame(self, frame): return
	if VerifiedRules.Luohou.resolve_frame(self, frame): return
	if VerifiedRules.CatSamurai.resolve_frame(self, frame): return
	if VerifiedRules.Izanami.resolve_frame(self, frame): return
	if VerifiedRules.YanmieTrio.resolve_frame(self, frame): return
	if VerifiedRules.FearWing.resolve_frame(self,frame):return
	if VerifiedRules.WisdomLamp.resolve_frame(self,frame):return
	if VerifiedRules.HairPower.resolve_frame(self,frame):return
	if VerifiedRules.MusicFire.resolve_frame(self,frame):return
	if VerifiedRules.SerpentGhost.resolve_frame(self,frame):return
	if VerifiedRules.Coffin.resolve_frame(self, frame): return
	if VerifiedRules.Commission.resolve_frame(self, frame): return
	if VerifiedRules.TimeRewind.resolve_frame(self, frame): return
	if VerifiedRules.EssenceFeast.resolve_frame(self,frame):return
	if VerifiedRules.Cooking.resolve_frame(self,frame):return
	if frame.get("kind")=="card-announce" and frame.get("cardOverride",{}).get("neutralFood",false):
		VerifiedRules.announce_neutral_food(self,frame)
		return
	if VerifiedRules.Arakawa.resolve_frame(self,frame):return
	if VerifiedRules.RednightWalnut.resolve_frame(self,frame):return
	if VerifiedRules.ApeSleeve.resolve_frame(self,frame):return
	if VerifiedRules.BlueGreen.resolve_frame(self,frame):return
	if VerifiedRules.Zhenjian.resolve_frame(self,frame):return
	if VerifiedRules.ChargedPair.resolve_frame(self,frame):return
	if VerifiedRules.MirrorSong.resolve_frame(self,frame):return
	if VerifiedRules.Yi.resolve_frame(self,frame):return
	if VerifiedRules.Yujiazhu.resolve_frame(self,frame):return
	if VerifiedRules.Link.resolve_frame(self,frame) or VerifiedRules.TwoFaces.resolve_frame(self,frame):return
	if VerifiedRules.Mianqiling.resolve_frame(self,frame):return
	if VerifiedRules.BlackWhite.resolve_frame(self,frame):return
	if VerifiedRules.BoxMaiden.resolve_frame(self,frame):return
	if VerifiedRules.Futakuchi.resolve_frame(self,frame):return
	if VerifiedRules.Lantern.resolve_frame(self,frame):return
	if VerifiedRules.Garuda.resolve_frame(self, frame): return
	if VerifiedRules.BattleSkill.resolve_frame(self, frame): return
	if VerifiedRules.Butterfly.resolve_frame(self, frame): return
	if VerifiedRules.Cotton.resolve_frame(self, frame): return
	if VerifiedRules.SpiderLily.resolve_frame(self, frame): return
	if frame.get("kind") == "charm-end-turn":
		var previous := is_resolving
		is_resolving = false
		_advance_turn(int(frame.playerIndex))
		is_resolving = previous
		return
	if VerifiedRules.OwlInsect.resolve_frame(self,frame): return
	if VerifiedRules.Incarnation.resolve_frame(self,frame): return
	if frame.get("kind")=="night-defender-ready":
		_offer_attack_responses(frame)
		return
	if VerifiedRules.ThreeTail.resolve_frame(self,frame): return
	if VerifiedRules.Glutton.resolve_frame(self,frame): return
	if VerifiedRules.Doll.resolve_frame(self,frame): return
	if VerifiedRules.Onikiri.resolve_frame(self,frame): return
	if VerifiedRules.Otakemaru.resolve_frame(self,frame): return
	if VerifiedRules.House.resolve_frame(self,frame): return
	if VerifiedRules.Goldfish.resolve_frame(self,frame): return
	if VerifiedRules.Vine.resolve_frame(self,frame): return
	if VerifiedRules.WindRaccoon.resolve_frame(self,frame): return
	if VerifiedRules.Puppet.resolve_frame(self,frame): return
	if VerifiedRules.Enma.resolve_frame(self,frame): return
	if VerifiedRules.Weaver.resolve_frame(self,frame): return
	if VerifiedRules.Sparrow.resolve_frame(self,frame): return
	if VerifiedRules.Headless.resolve_frame(self,frame): return
	if VerifiedRules.Yaksha.resolve_frame(self,frame): return
	if VerifiedRules.StarBear.resolve_frame(self,frame): return
	if VerifiedRules.Pine.resolve_frame(self,frame): return
	if VerifiedRules.Paint.resolve_frame(self,frame): return
	if VerifiedRules.Samurai.resolve_frame(self,frame): return
	if VerifiedRules.Mountain.resolve_frame(self,frame): return
	if VerifiedRules.Maple.resolve_frame(self,frame): return
	if VerifiedRules.Raccoon.resolve_frame(self,frame): return
	if VerifiedRules.FoxLotus.resolve_frame(self,frame): return
	if VerifiedRules.Rebirth.resolve_frame(self,frame): return
	if VerifiedRules.OniAsura.resolve_frame(self,frame): return
	if VerifiedRules.PipeFox.resolve_frame(self,frame): return
	if VerifiedRules.Moon.resolve_frame(self,frame): return
	if VerifiedRules.Bamboo.resolve_frame(self,frame): return
	if VerifiedRules.TreeSakura.resolve_frame(self, frame): return
	if VerifiedRules.RabbitTide.resolve_frame(self,frame): return
	if VerifiedRules.SugarCat.resolve_frame(self,frame):return
	if VerifiedRules.MonkCleaner.resolve_frame(self, frame): return
	if VerifiedRules.BondDream.resolve_frame(self, frame): return
	if VerifiedRules.Eye.resolve_frame(self, frame): return
	if VerifiedRules.Crab.resolve_frame(self, frame): return
	if frame.get("kind") == "realms-continue":
		_trigger_realm_ids(int(frame.playerIndex), frame.realmIds)
		return
	if frame.get("kind") == "turn-after-realms":
		var previous := is_resolving
		is_resolving = false
		_begin_turn_after_realms(int(frame.playerIndex), frame.ticking)
		is_resolving = previous
		return
	if frame.get("kind") == "turn-retreat-draw":
		var owner := int(frame.playerIndex)
		resolution_stack.append({"kind": "turn-normal-draw", "playerIndex": owner})
		for unit in player(owner).units:
			if not unit.get("summoned", false) and int(unit.front) == 1 and not unit.get("formRules", {}).get("treeRoot", false) and int(unit.get("wlEnteredTurn",-1))!=turn_counter:
				unit.front = 0
				_log("%s 从战斗区返回准备区。" % unit.name, TONE_NEUTRAL)
				VerifiedRules.Movement.moved(self, owner, _unit_index_by_uid(owner, unit.uid), 1)
		return
	if frame.get("kind")=="turn-transition":
		_switch_turn(int(frame.playerIndex))
		return
	if frame.get("kind") == "turn-normal-draw":
		var owner := int(frame.playerIndex)
		if not VerifiedRules.BookJue.turn_draw(self, owner) and not VerifiedRules.DragonAbyss.Travel.turn_draw(self, owner): _draw(owner, 1)
		return
	if VerifiedRules.Wind.resolve_frame(self, frame): return
	if VerifiedRules.Mask.resolve_frame(self, frame): return
	if VerifiedRules.River.resolve_frame(self, frame): return
	if frame.get("kind") == "river-combat-ready":
		_resolve_combat_ready(frame)
		return
	if VerifiedRules.IronMouse.resolve_frame(self, frame): return
	if VerifiedRules.UpgradeBlessing.resolve_frame(self, frame): return
	if VerifiedRules.Huang.resolve_frame(self, frame): return
	if VerifiedRules.ShenqiHuang.resolve_frame(self, frame): return
	if VerifiedRules.Himiko.resolve_frame(self, frame): return
	if VerifiedRules.TomatoFire.resolve_frame(self, frame): return
	if VerifiedRules.Movement.resolve_frame(self, frame): return
	if VerifiedRules.GiftEnergy.resolve_frame(self, frame): return
	if VerifiedRules.SunSmoke.resolve_frame(self, frame): return
	if VerifiedRules.FoxSuzuka.resolve_frame(self, frame): return
	if VerifiedRules.Poison.resolve_frame(self, frame): return
	if VerifiedRules.Yijin.resolve_frame(self, frame): return
	if VerifiedRules.Xuenv.resolve_frame(self, frame): return
	if VerifiedRules.DogDemon.resolve_frame(self, frame): return
	if VerifiedRules.Phoenix.resolve_frame(self, frame): return
	if frame.get("kind") == "response-complete": return
	if frame.get("kind") == "combat-entered":
		_resolve_combat_entered(frame)
		return
	if frame.get("kind") == "combat-hit":
		_resolve_combat_hit(frame)
		return
	if VerifiedRules.HandBlessing.resolve_frame(self,frame): return
	if VerifiedRules.SilkNinja.resolve_frame(self,frame): return
	if VerifiedRules.Toxic.resolve_frame(self,frame): return
	if VerifiedRules.KoiFragrance.resolve_frame(self,frame): return
	if VerifiedRules.Susanoo.resolve_frame(self,frame): return
	if VerifiedRules.Baize.resolve_frame(self,frame): return
	if VerifiedRules.Whale.resolve_frame(self,frame): return
	if VerifiedRules.Jorogumo.resolve_frame(self,frame): return
	if VerifiedRules.Yitiao.resolve_frame(self, frame): return
	if VerifiedRules.Countdown.resolve_frame(self, frame): return
	if VerifiedRules.Forms.resolve_frame(self, frame): return
	if frame.get("kind") == "countdown-change":
		VerifiedRules.Countdown.change(self, int(frame.playerIndex), int(frame.sourceIndex), int(frame.delta), int(frame.get("cardOwner", -1)))
		return
	if frame.get("kind") == "card-announce":
		VerifiedRules.announce_card(self, frame)
		return
	if frame.get("kind") == "card-counter-check":
		VerifiedRules.cancel_pending_card(self, frame)
		return
	var p_idx := int(frame.get("playerIndex", 0))
	var card: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.get("definitionId", ""))))
	var src := int(frame.get("sourceIndex", -1))
	if card.is_empty() or src < 0:
		return
	if frame.get("kind") == "card-start":
		if frame.get("automatic", false):
			_log("%s %s，自动使用「%s」。" % [player(p_idx).units[src].name, "羁绊进场" if card.get("blackWhiteBondCast",false) else "蓄力完成" if card.get("lanternReleased",false) or card.get("chargedReleased",false) else "占卜置底触发" if card.get("baizeRules",false) else "重任在肩触发" if card.get("yitiaoAutomaticTraining",false) else "出击触发" if card.get("butterflyRules",false) or card.get("garudaRules",false) else "极星结算" if card.get("xuanAutomatic", false) else "倒计时触发", card.name], TONE_CARD)
			VerifiedRules.event(self, "automatic-card", {"card": card, "uid": player(p_idx).units[src].uid, "player": p_idx, "target": frame.get("targetId")})
		VerifiedRules.card_started(self, p_idx, src, card, bool(frame.get("automatic", false)))
		return
	var target_id = frame.get("targetId")
	var target_unit := _unit_by_uid(_all_units(), target_id) if target_id != null else {}
	if str(frame.get("kind", "")) == "card-complete":
		_card_effect_context = frame if ContentLoader.is_spell(card) else {}
		if card.get("type") == "combat" and src >= 0: VerifiedRules.PeachGrove.wing_crane(self, p_idx, src)
		VerifiedRules.Arakawa.completed(self,frame,card)
		VerifiedRules.YanmieTrio.complete(self, frame, card)
		VerifiedRules.ApeSleeve.completed(self,frame,card)
		VerifiedRules.BlueGreen.completed(self,frame,card)
		VerifiedRules.HandBlessing.completed(self,p_idx,src,card)
		VerifiedRules.Hanafuda.karuta_complete(self, p_idx, card)
		VerifiedRules.Hanafuda.moon_complete(self, p_idx, card)
		VerifiedRules.Himiko.completed(self, p_idx, card, frame)
		VerifiedRules.CoopMiddle.completed(self, frame, card)
		VerifiedRules.Hanafuda.phoenix_spell(self, p_idx, card)
		VerifiedRules.Xuan.completed(self, p_idx, card, target_id)
		VerifiedRules.SpellReplay.completed(self, frame, card)
		VerifiedRules.Countdown.card_completed(self, p_idx, src, card)
		VerifiedRules.MusicFire.completed(self,frame,card)
		VerifiedRules.Cooking.completed(self,frame,card)
		VerifiedRules.Zhenjian.completed(self,frame,card)
		VerifiedRules.ChargedPair.completed(self,frame,card)
		VerifiedRules.Headless.completed(self,frame,card)
		VerifiedRules.SugarCat.completed(self,frame,card)
		VerifiedRules.TwinSight.completed(self, frame)
		VerifiedRules.LineageScroll.completed(self, frame, card)
		VerifiedRules.NineTails.focus_completed(self, int(frame.playerIndex), card)
		VerifiedRules.StarRealms.completed(self, frame, card)
		VerifiedRules.PaperDance.refresh(self, p_idx)
		if str(card.get("type", "")) == "form" and int(player(p_idx).units[src].get("hp", 0)) > 0:
			# 形态共鸣已在 _apply_form 内回满；此处补 card-played 钩子
			pass
		_fire_hooks(p_idx, src, "card-played", {"card": card, "cardType": str(card.get("type", ""))})
		_run_form_hooks(p_idx, src, "card-played", {"card": card, "cardType": str(card.get("type", ""))})
		_card_effect_context = {}
		VerifiedRules.Insight.used(self, p_idx, card, card.get("playedInstance", {}), true, target_id)
		return
	var effects := _effect_list(card)
	var idx := int(frame.get("effectIndex", 0))
	if idx < 0 or idx >= effects.size():
		return
	if int(frame.get("combatResponseId", -1)) >= 0 and card.id == VerifiedRules.Grudge.AVENGE:
		VerifiedRules.Grudge.respond(self, p_idx, src, int(frame.combatResponseId))
		return
	if int(frame.get("combatResponseId", -1)) >= 0 and card.id == "c65208":
		VerifiedRules.GoatHeist.respond_combat(self, p_idx, src, int(frame.combatResponseId), card)
		return
	if int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="mf-combat":
		if VerifiedRules.MusicFire.respond_combat(self,int(frame.combatResponseId),p_idx,src,card):return
	if int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="charged-combat":
		VerifiedRules.ChargedPair.respond_combat(self,int(frame.combatResponseId),p_idx,src,card);return
	if int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="ms-beauty":
		VerifiedRules.MirrorSong.respond_combat(self,int(frame.combatResponseId),p_idx,src,card,str(target_id));return
	if int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="yuj-talisman":
		VerifiedRules.Yujiazhu.respond_combat(self,int(frame.combatResponseId),p_idx,src,card,target_id)
		return
	if int(frame.get("combatResponseId", -1)) >= 0 and effects[idx].get("action") in ["assault", "fortune-combat", "movement-combat"]:
		if VerifiedRules.Headless.respond_combat(self,int(frame.combatResponseId),p_idx,src,card): return
		if VerifiedRules.Rebirth.respond_combat(self,int(frame.combatResponseId),p_idx,src,card): return
		if VerifiedRules.Mask.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return
		if VerifiedRules.Movement.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return
		if VerifiedRules.Fortune.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return
		if VerifiedRules.Poison.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return
		if VerifiedRules.DogDemon.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return
		VerifiedRules.ArmorBreak.respond_combat(self, int(frame.combatResponseId), p_idx, src, card)
		return
	_card_effect_context = frame if ContentLoader.is_spell(card) else {}
	var awaken_unit: Dictionary=player(p_idx).units[src]
	var was_awakened: bool=awaken_unit.awakened
	var before_awaken_attack: int=awaken_unit.attackBonus
	var before_awaken_hp: int=awaken_unit.maxHpBonus
	var outer_hand_combat_context:=_hand_combat_context
	_hand_combat_context={"playerIndex":p_idx,"sourceIndex":src,"card":card} if card.get("type")=="combat" else {}
	_resolve_one_effect(p_idx, src, card, effects[idx], target_id, target_unit)
	_hand_combat_context=outer_hand_combat_context
	# Manual awakening executors change these body modifiers in this effect.
	# Generic _awaken already recorded its exact values and does not enter here.
	if not was_awakened and awaken_unit.awakened and not awaken_unit.has("gluttonAwakenAttack"):
		VerifiedRules.Glutton.record_permanent(awaken_unit,int(awaken_unit.attackBonus)-before_awaken_attack,int(awaken_unit.maxHpBonus)-before_awaken_hp,true)
	_card_effect_context = {}


func _resolve_one_effect(p_idx: int, src: int, card: Dictionary, effect: Dictionary, target_id, target_unit: Dictionary) -> void:
	effect = VerifiedRules.FoxSuzuka.damage_effect(card, effect)
	var cond: String = str(effect.get("condition", "always"))
	if cond == "source-ready":
		var su: Dictionary = player(p_idx).units[src]
		if VerifiedRules.Stun.blocks(self,p_idx,su,card):
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
	var previous_group := _night_damage_group
	_night_damage_group = VerifiedRules.Night.group(self, card, effect)
	_resolve_action(p_idx, src, card, effect, target_id, target_unit)
	VerifiedRules.Night.finish_group(self, _night_damage_group)
	_night_damage_group = previous_group


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
			if VerifiedRules.Stun.blocks(self,p_idx,su,card):
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
			if not _fortune_success(p_idx):
				continue
		elif cond == "bestow-ready":
			if int(player(p_idx).units[src].get("charge", 0)) < 2:
				continue
		_resolve_action(p_idx, src, card, effect, target_id, target_unit)


func _resolve_action(p_idx: int, src: int, card: Dictionary, effect: Dictionary, target_id, target_unit: Dictionary) -> void:
	if VerifiedRules.resolve_action(self, p_idx, src, card, effect, target_unit, target_id): return
	var action: String = str(effect.get("action", ""))
	var value = effect.get("value", card.get("value"))
	var et: String = str(effect.get("target", card.get("target", "auto")))
	var p := player(p_idx)
	var e_idx := enemy_index(p_idx)
	var source: Dictionary = p.units[src]
	match action:
		"assault":
			var bonus := _num(value)
			if card.get("verifiedRules", false):
				var options: Dictionary = card.get("combatOption", {}).duplicate(true)
				options.combatCard = card.duplicate(true)
				if options.has("boneCombat"): options.boneDeaths = int(source.get("boneDeaths", 0))
				_grant_unit_armor(source, int(options.get("shield", 0)))
				_record("assault", {"unit": src, "target": target_id, "bonus": bonus}, p_idx)
				_resolve_combat(p_idx, src, bonus, _kw(card, "pierce"), _kw(card, "remote"), _kw(card, "combo"), _kw(card, "first-strike"), target_id, _kw(card, "crit"), options)
				return
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
		"damage-self":
			# Self-inflicted damage keeps the caster as its source, including kills.
			_damage_unit(p_idx, src, _num(value), p_idx, src)
		"heal":
			for u in _ally_targets(p_idx, et, src, target_id, target_unit):
				_heal_unit(u, _num(value))
		"buff-stats":
			var bonuses := _value_dict(value)
			var targets: Array = []
			if et == "all-enemy-units":
				targets = player(e_idx).units.filter(func(u): return int(u.hp) > 0)
			elif et == "selected-enemy":
				if not target_unit.is_empty():
					targets = [target_unit]
			elif et in ["source", "all-ally-units", "all-other-allies"] or target_id != null:
				targets = _ally_targets(p_idx, et, src, target_id, target_unit)
			for u in targets:
				if int(u.hp) > 0:
					_grow_unit(u, _num(bonuses.get("attack", 0)), _num(bonuses.get("hp", 0)))
					_log("%s 获得 +%d/+%d。" % [u.name, _num(bonuses.get("attack", 0)), _num(bonuses.get("hp", 0))], TONE_SUCCESS)
		"debuff-stats":
			# The JS baseline uses signed deltas on one selected enemy only.
			# Do not infer negation or all-enemy scope from the action's name.
			var idx := _unit_index_by_uid(e_idx, target_unit.get("uid", ""))
			if idx >= 0:
				var unit: Dictionary = player(e_idx).units[idx]
				if int(unit.hp) > 0:
					var delta := _value_dict(value)
					var hp_delta := _num(delta.get("hp", 0))
					unit.attackBonus = int(unit.attackBonus) + _num(delta.get("attack", 0))
					unit.maxHpBonus = int(unit.maxHpBonus) + hp_delta
					if hp_delta != 0:
						unit.hp = maxi(1, int(unit.hp) + hp_delta)
					_recalc(unit)
					_log("%s 数值变化：力量 %+d，生命 %+d。" % [unit.name, _num(delta.get("attack", 0)), hp_delta], TONE_DANGER)
		"bounce-to-reserve":
			var idx := _unit_index_by_uid(e_idx, target_unit.get("uid", ""))
			if idx >= 0 and int(player(e_idx).units[idx].hp) > 0:
				VerifiedRules.Movement.move_to(self, e_idx, idx, 0)
				_log("%s 被移回准备区。" % player(e_idx).units[idx].name, TONE_NEUTRAL)
		"shield-self-player":
			# Existing baseline means shields for living allies, not a new avatar shield.
			for unit in p.units:
				if int(unit.hp) > 0:
					_grant_unit_armor(unit, _num(value), false)
					_log("%s 获得 %d 点护盾。" % [unit.name, _num(value)], TONE_SUCCESS)
		"energy-gain":
			var amount := _num(value) if value != null else 1
			_set_fire(p_idx,mini(4,int(p.energy)+amount))
			_log("%s 获得 %d 点鬼火。" % [p.name, amount], TONE_SUCCESS)
		"heal-avatar":
			_heal_avatar(p_idx, _num(value))
		"shield":
			for u in _ally_targets(p_idx, et, src, target_id, target_unit):
				_grant_unit_armor(u, _num(value), card.get("verifiedRules", false))
				_log("%s 获得 %d 点护盾。" % [u.name, _num(value)], TONE_SUCCESS)
		"fortify":
			# enter front + shield source
			source.front = 1
			for u in p.units:
				if u != source:
					u.front = 0
			_grant_unit_armor(source, _num(value), false)
			_log("%s 进入前线并获得 %d 点护盾。" % [source.name, _num(value)], TONE_SUCCESS)
			_fire_hooks(p_idx, src, "unit-entered-front", {})
		"draw":
			_draw(p_idx, _num(value) if _num(value) > 0 else 1)
		"revive":
			for u in _ally_targets(p_idx, et, src, target_id, target_unit):
				if u.get("summoned", false): continue
				if int(u.hp) <= 0:
					if not VerifiedRules.YanmieTrio.can_revive(self, p_idx, u): continue
					var early := int(u.knockout) != 0
					u.hp = int(u.maxHp)
					u.knockout = 0
					u.shield = 0
					u.front = 0
					_log("%s 被余辉唤回，恢复全部生命。" % u.name, TONE_SUCCESS)
					VerifiedRules.Movement.revived(self, p_idx, _unit_index_by_uid(p_idx, u.uid), early)
				else:
					_heal_unit(u, _num(value))
		"freeze":
			for u in _enemy_targets(p_idx, et, target_unit):
				VerifiedRules.Stun.apply(self, e_idx, _unit_index_by_uid(e_idx, u.uid), maxi(1, _num(value)))
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
			resolution_stack.append({"kind": "charm-heal-avatar", "playerIndex": p_idx, "amount": 1})
			_draw(p_idx, _num(value) if _num(value) > 0 else 1)
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
				VerifiedRules.BondDream.fetched(self, inst)
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
	if et == "two-random-enemy-characters":
		var units: Array = player(e_idx).units
		var candidates := [-1]
		for i in units.size():
			if int(units[i].hp) > 0 and not units[i].get("removed", false): candidates.append(i)
		for _hit in mini(2, candidates.size()):
			if winner >= 0: break
			var idx: int = candidates.pop_at(int(randf01() * candidates.size()))
			if idx < 0: _damage_avatar(e_idx, amount, p_idx)
			elif int(units[idx].hp) > 0: _damage_unit(e_idx, idx, amount, p_idx)
	elif et in ["all-enemy-units", "all-enemies"]:
		var foe := player(e_idx)
		for i in foe.units.size():
			if int(foe.units[i].hp) > 0:
				_damage_unit(e_idx, i, amount, p_idx)
		if et == "all-enemies": _damage_avatar(e_idx, amount, p_idx)
	elif et == "enemy-avatar" or et == "ally-avatar":
		_damage_avatar(e_idx, amount, p_idx)
	elif et == "enemy-front":
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
	if unit.get("removed", false): return
	VerifiedRules.SunSmoke.grew(self, unit, atk, hp)
	unit.attackBonus = int(unit.attackBonus) + atk
	unit.maxHpBonus = int(unit.maxHpBonus) + hp
	# _recalc already grants the max-HP increase to living units exactly once.
	# Adding it again heals existing damage and can even revive a knocked-out unit.
	_recalc(unit)
	VerifiedRules.RedPurple.refresh(self)


func _recalc(unit: Dictionary) -> void:
	var old_hp := int(unit.hp)
	VerifiedRules.SunSmoke.refresh_clone(unit)
	var faction_aura := VerifiedRules.RedPurple.aura_bonus(self,unit,"attack") + VerifiedRules.BlueGreen.aura_bonus(self,unit,"attack")
	var mighty_power := VerifiedRules.RedPurple.power_bonus(self,unit)
	unit.factionAuraApplied = faction_aura
	unit.rpMightyApplied = mighty_power
	var form: Dictionary = unit.get("form", {})
	unit.attack = int(unit.baseAttack) + int(unit.attackBonus) + int(form.get("attackBonus", 0)) + int(unit.get("cranePower", 0)) + int(unit.get("permanentAttack", 0)) + int(unit.get("temporaryAttack", 0)) + int(unit.get("untilAttack", {}).get("attack", 0)) - int(unit.get("judgeInkAttack", 0)) + int(unit.get("smokeChargePower", 0))
	var dream_body := VerifiedRules.BondDream.body(self, unit)
	if dream_body >= 0: unit.attack += dream_body - int(unit.baseAttack) - int(form.get("attackBonus", 0))
	var lotus_penalty := VerifiedRules.FoxLotus.penalty(self,unit)
	if lotus_penalty>0: unit.attack=maxi(0,int(unit.attack)-lotus_penalty)
	unit.attack += 2*int(unit.get("foxPillow",0))
	unit.attack -= int(unit.get("dreamPowerPenalty", 0))
	unit.attack += VerifiedRules.OwlInsect.power(self,unit) - int(unit.get("insectCorrosion",0))
	for side in players.size():
		if player(side).units.has(unit): unit.attack-=VerifiedRules.Toxic.aura(self,side,unit)
	unit.attack += VerifiedRules.MonkCleaner.aura_power(self, unit)
	unit.attack += VerifiedRules.ArmorBlood.armor_power(self, unit)
	unit.attack += VerifiedRules.Fortune.power(self, unit)
	unit.attack += VerifiedRules.Yitiao.guard_power(self,unit) + VerifiedRules.Crocodile.bonus(self,unit,"attack")
	unit.attack += VerifiedRules.StarBear.power(unit) + int(unit.get("chenZoneAttack", 0))
	unit.attack += VerifiedRules.Glutton.power(self,unit)
	unit.attack += faction_aura + mighty_power + VerifiedRules.Wave7Reworks.extra_power(unit)
	unit.attack += int(unit.get("hfTempPower", 0)) + int(unit.get("xuanPower", 0)) + VerifiedRules.CoopFirst.power(self, unit)
	unit.attack += VerifiedRules.Onikiri.power(self,unit) + VerifiedRules.Otakemaru.power(self,unit)
	unit.attack += VerifiedRules.Puppet.base_bonus(unit) + VerifiedRules.Enma.aura(self,unit) + VerifiedRules.Vine.bonus(unit)
	unit.attack += VerifiedRules.MusicFire.power_delta(self,unit) + VerifiedRules.PaperDance.power(unit)
	unit.attack += VerifiedRules.ZenMisfortune.power(unit)
	var mist_penalty := VerifiedRules.DuskCycle.mist_power(self, unit)
	if mist_penalty > 0: unit.peacockMistPenalty = mist_penalty
	else: unit.erase("peacockMistPenalty")
	unit.attack -= mist_penalty
	unit.attack += VerifiedRules.DragonAbyss.power(self, unit)
	unit.attack += int(unit.get("starsGoatAttack", 0)) + int(unit.get("starsGoatNoticePower", 0)) + int(unit.get("starsFlutePower", 0)) - int(unit.get("starsFoxWeak", 0))
	unit.sgSnakeAuraApplied=VerifiedRules.SerpentGhost.power_delta(self,unit)
	unit.attack+=int(unit.sgSnakeAuraApplied)
	unit.attack += VerifiedRules.Movement.power(unit, turn_counter)
	unit.attack += VerifiedRules.Zhenjian.power(unit)
	unit.attack += VerifiedRules.Night.power(self, unit) + int(unit.get("windStoredPower", 0))
	if VerifiedRules.Movement.zero_power(self, unit): unit.attack = 0
	for owner in players.size():
		if player(owner).units.has(unit) and VerifiedRules.Combat.zero_power(self, owner, unit): unit.attack = 0
	for owner in players.size():
		if player(owner).units.has(unit):
			unit.poisonAuraReduction = VerifiedRules.Poison.power_reduction(self, owner, unit)
			unit.attack = int(unit.attack) - int(unit.poisonAuraReduction)
	if int(unit.get("insectCorrosion",0))>0: unit.attack = maxi(0,int(unit.attack))
	if int(unit.get("twinZeroTurn", -1)) == turn_counter: unit.attack = 0
	VerifiedRules.DogDemon.record_strength(unit)
	var new_max := int(unit.baseMaxHp) + int(unit.maxHpBonus) + int(form.get("hpBonus", 0)) - int(unit.get("judgeInkHp", 0)) - int(unit.get("insectCorrosion",0)) - 2*int(unit.get("foxPillow",0))
	new_max += VerifiedRules.Crocodile.bonus(self,unit,"hp") + int(unit.get("chenZoneHp", 0))
	new_max += faction_aura + int(unit.get("xuanHealth", 0))
	new_max += VerifiedRules.DragonAbyss.Travel.units_aura(self, unit)
	new_max += VerifiedRules.Puppet.base_bonus(unit) + VerifiedRules.Enma.aura(self,unit) + VerifiedRules.Vine.bonus(unit)
	if dream_body >= 0: new_max += dream_body - int(unit.baseMaxHp) - int(form.get("hpBonus", 0))
	if VerifiedRules.Hanafuda.shared(unit):
		for owner in players.size():
			if _unit_index_by_uid(owner, unit.uid) >= 0: new_max = int(player(owner).maxAvatarHp)
	var gain := new_max - int(unit.maxHp)
	unit.maxHp = new_max
	if gain > 0 and int(unit.hp) > 0 and not unit.get("toxicPoisoned",false):
		unit.hp = mini(int(unit.hp) + gain, new_max)
	elif int(unit.hp) > new_max and not unit.get("toxicPoisoned",false):
		unit.hp = new_max
	VerifiedRules.TreeSakura.sync_power(unit)
	if old_hp != 1 and int(unit.hp) == 1:
		for side in players.size():
			if _unit_index_by_uid(side, unit.uid) < 0: continue
			VerifiedRules.Izanami.changed(self, side, unit, old_hp)
			break
	VerifiedRules.Wave7Reworks.refresh_ghost_power(self, unit)


func _apply_form(p_idx: int, src: int, card: Dictionary, value: Dictionary = {}) -> void:
	var unit: Dictionary = player(p_idx).units[src]
	if not card.get("puppetRules",false) and not unit.get("form", {}).is_empty() and ContentLoader.unit_def(unit.id).has("formLifecycle"):
		resolution_stack.append({"kind": "form-install", "playerIndex": p_idx, "sourceIndex": src, "card": card.duplicate(true), "value": value.duplicate(true)})
		VerifiedRules.Forms.remove(self, p_idx, src, "被替换")
		return
	_install_form(p_idx, src, card, value)


func _install_form(p_idx: int, src: int, card: Dictionary, value: Dictionary = {}) -> void:
	var poison_hp:=int(player(p_idx).units[src].hp) if player(p_idx).units[src].get("toxicPoisoned",false) else -1
	var glutton_prepared := VerifiedRules.Glutton.prepare_form(self,p_idx,src,card,value)
	card=glutton_prepared.card
	value=glutton_prepared.value
	var prepared := VerifiedRules.Puppet.prepare_form(self,p_idx,src,card,value)
	card=prepared.card
	value=prepared.value
	var u: Dictionary = player(p_idx).units[src]
	VerifiedRules.YanmieTrio.remember_form(u)
	VerifiedRules.DogDemon.form_removed(u)
	var v := value if not value.is_empty() else _value_dict(card.get("value"))
	var atk := _num(v.get("attack", 0))
	var hp := _num(v.get("hp", 0))
	if v.get("setBase", false):
		atk -= int(u.baseAttack)
		hp -= int(u.baseMaxHp)
	var ability: String = str(card.get("formAbility", card.get("text", "")))
	u.form = {"attackBonus": atk, "hpBonus": hp, "name": card.get("name", "形态"), "cardId": card.get("id"), "native":card.get("verifiedRules",false)}
	if card.has("coopFaceId"): u.form.coopFaceId = card.coopFaceId
	if card.has("coopFaceArt"): u.form.coopFaceArt = card.coopFaceArt
	u.formAbility = ability
	u["formHooks"] = card.get("formHooks", []) if card.get("formHooks") is Array else []
	u["formRules"] = card.get("formRules", {}).duplicate(true)
	u.formInstalledOrder = next_rule_event_id
	VerifiedRules.Puppet.form_installed(self,p_idx,src,card)
	VerifiedRules.Yi.form_installed(self,p_idx,src,card)
	VerifiedRules.ShenqiHuang.form_entered(self, p_idx, src, card)
	VerifiedRules.MirrorSong.form_entered(self,p_idx,src,card)
	VerifiedRules.RednightWalnut.form_entered(self,p_idx,src,card)
	VerifiedRules.FearWing.form_entered(self,p_idx,src,card)
	VerifiedRules.WisdomLamp.form_entered(self,p_idx,src,card)
	VerifiedRules.Langya.form_entered(self,p_idx,src,card)
	VerifiedRules.HairPower.form_entered(self,p_idx,src,card)
	VerifiedRules.MusicFire.form_entered(self,p_idx,src,card)
	VerifiedRules.Cooking.form_entered(self,p_idx,src,card)
	VerifiedRules.ApeSleeve.form_entered(self,p_idx,src,card)
	VerifiedRules.Zhenjian.form_entered(self,p_idx,src,card)
	VerifiedRules.ChargedPair.form_entered(self,p_idx,src,card)
	VerifiedRules.event(self, "form-installed", {"player": p_idx, "uid": u.uid, "card": card})
	_recalc(u)
	if poison_hp>0: u.hp=poison_hp
	elif int(u.hp) > 0 and not card.get("puppetFusion",false):
		u.hp = int(u.maxHp)
	_log("%s 化作「%s」（+%d攻/+%d生命）。" % [u.name, card.get("name", "形态"), atk, hp], TONE_CARD)
	VerifiedRules.Forms.attach(self, p_idx, src, card)
	VerifiedRules.SugarCat.form_entered(self,p_idx,src,card)
	if card.get("formRules", {}).get("grudgeBurden", false): VerifiedRules.Grudge.attach(self, p_idx, src, 2)
	VerifiedRules.EssenceFeast.form_entered(self,p_idx,src,card)
	VerifiedRules.SerpentGhost.form_entered(self,p_idx,src,card)
	VerifiedRules.Yujiazhu.form_entered(self,p_idx,src,card)
	VerifiedRules.BlueGreen.form_entered(self,p_idx,src,card)
	VerifiedRules.RedPurple.form_entered(self,p_idx,src,card)
	VerifiedRules.Mianqiling.form_entered(self,p_idx,src,card)
	VerifiedRules.Futakuchi.form_entered(self,p_idx,src,card)
	VerifiedRules.BlackWhite.form_entered(self,p_idx,src,card)
	VerifiedRules.Butterfly.form_entered(self,p_idx,src,card)
	VerifiedRules.ThreeTail.form_entered(self,p_idx,src,card)
	VerifiedRules.Doll.form_entered(self,p_idx,src,card)
	VerifiedRules.Otakemaru.form_entered(self,p_idx,src,card)
	VerifiedRules.Goldfish.form_entered(self,p_idx,src,card)
	VerifiedRules.Vine.form_entered(self,p_idx,src,card)
	VerifiedRules.Puppet.form_entered(self,p_idx,src,card)
	VerifiedRules.Enma.form_entered(self,p_idx,src,card)
	VerifiedRules.Peach.form_entered(self, p_idx, src, card)
	VerifiedRules.Shuten.form_entered(self, p_idx, src, card)
	VerifiedRules.Bingyong.form_entered(self, p_idx, src, card)
	VerifiedRules.BookJue.form_entered(self, p_idx, src, card)
	VerifiedRules.SunSmoke.form_entered(self, p_idx, src, card)
	VerifiedRules.GiftEnergy.form_entered(self, p_idx, src, card)
	VerifiedRules.Wave7Reworks.form_entered(self, p_idx, src, card)
	VerifiedRules.Moon.form_entered(self,p_idx,src,card)
	VerifiedRules.PipeFox.form_entered(self,p_idx,src,card)
	VerifiedRules.Maple.form_entered(self,p_idx,src,card)
	VerifiedRules.Pine.form_entered(self,p_idx,src,card)
	VerifiedRules.Sparrow.form_entered(self,p_idx,src,card)
	VerifiedRules.Headless.form_entered(self,p_idx,src,card)
	VerifiedRules.Yaksha.form_entered(self,p_idx,src,card)
	VerifiedRules.OniAsura.form_entered(self,p_idx,src,card)
	VerifiedRules.BoxMaiden.form_entered(self,p_idx,src,card)
	VerifiedRules.Light.form_entered(self, p_idx, src, card)
	VerifiedRules.ArmorBlood.form_entered(self, p_idx, src, card)
	VerifiedRules.Fortune.form_entered(self, p_idx, src, card)
	VerifiedRules.HandBlessing.form_entered(self,p_idx,src,card)
	VerifiedRules.KoiFragrance.form_entered(self,p_idx,src,card)
	VerifiedRules.Toxic.form_entered(self,p_idx,src,card)
	VerifiedRules.Susanoo.form_entered(self,p_idx,src,card)
	VerifiedRules.DogDemon.form_entered(self, p_idx, src, card)
	VerifiedRules.Poison.form_entered(self, p_idx, src, card)
	VerifiedRules.Eye.form_entered(self, p_idx, src, card)
	VerifiedRules.Crab.form_entered(self, p_idx, src, card)
	VerifiedRules.MonkCleaner.form_entered(self, p_idx, src, card)
	VerifiedRules.YanmieTrio.form_entered(self, p_idx, src, card)
	VerifiedRules.DuskCycle.season_enter(self, p_idx, src, card)
	VerifiedRules.PeachGrove.form_installed(self, p_idx, src, card)
	VerifiedRules.OwlInsect.refresh(self)
	VerifiedRules.RabbitTide.refresh(self)
	VerifiedRules.TreeSakura.sync_power(u)
	if ability != "":
		_log("形态提醒：%s" % ability, TONE_NEUTRAL)


func _awaken(p_idx: int, src: int, card: Dictionary, value: Dictionary) -> void:
	var p := player(p_idx)
	var u: Dictionary = p.units[src]
	if u.get("coopFirstCrane", false):
		u.erase("coopFirstCrane")
		VerifiedRules.Glutton.record_permanent(u, _num(value.get("attack", 1)), _num(value.get("hp", 1)))
		_grow_unit(u, _num(value.get("attack", 1)), _num(value.get("hp", 1)))
		return
	if u.awakened:
		_log("%s 已经觉醒。" % u.name, TONE_NEUTRAL)
		return
	u.awakened = true
	VerifiedRules.Glutton.record_permanent(u,_num(value.get("attack",1)),_num(value.get("hp",1)),true)
	_grow_unit(u, _num(value.get("attack", 1)), _num(value.get("hp", 1)))
	if value.get("grantUnyielding", false):
		u.unyielding = true
	var def := ContentLoader.unit_def(u.id)
	u.passive_hooks = def.get("awakenedPassive", {}).get("hooks", []) if def.get("awakenedPassive") is Dictionary else u.passive_hooks
	_log("%s 觉醒！" % u.name, TONE_SUCCESS)


func _deploy_realm(p_idx: int, card: Dictionary) -> void:
	if VerifiedRules.Bamboo.deploy(self,p_idx,card): return
	var realm = card.get("realm", {})
	if not (realm is Dictionary):
		realm = {}
	var p := player(p_idx)
	if realm.get("spaceTime", false): VerifiedRules.Xuan.deploy_space_time(self, p_idx)
	if realm.get("unique", false):
		for existing in p.realms.duplicate():
			if existing.cardId == card.id: VerifiedRules.Huang.destroy(self, p_idx, existing, "被唯一幻境替换")
	var deployed := {
		"uid": "realm-%s-%d" % [p.id, next_card_id],
		"nativeRealm": str(realm.get("nativeRealm", "")),
		"sourceUnit": str(card.get("unitId", "")),
		"cardId": card.get("id"),
		"name": card.get("name", "幻境"),
		"hp": _num(realm.get("hp", 3)),
		"maxHp": _num(realm.get("hp", 3)),
		"trigger": str(realm.get("trigger", "owner-turn-start")),
		"triggerEffect": str(realm.get("triggerEffect", "")),
		"triggerValue": realm.get("triggerValue", 0),
		"triggerEffects": realm.get("triggerEffects", []),
		"countdown": _num(realm.get("countdown", 0)),
		"countdownReset": _num(realm.get("countdownReset", 0)),
		"handCountdown": _num(realm.get("handCountdown", 0)),
		"avatarLinked": bool(realm.get("avatarLinked", false)),
		"returnOnDestroy": bool(realm.get("returnOnDestroy", false)),
		"returnInstance": realm.get("returnInstance", {}).duplicate(true),
		"cardInstance": card.get("playedInstance",{}).duplicate(true),
	}
	if realm.get("spaceTime", false): deployed.spaceTime = true
	if card.has("coopFaceId"): deployed.coopFaceId = card.coopFaceId
	if realm.get("frontmost", false): p.realms.push_front(deployed)
	else: p.realms.append(deployed)
	next_card_id += 1
	VerifiedRules.HandBlessing.realm_entered(self,p_idx,card)
	VerifiedRules.YanmieTrio.realm_entered(self, p_idx, card)
	VerifiedRules.RedPurple.realm_entered(self,p_idx,card)
	_log("%s 部署幻境「%s」。" % [p.name, card.get("name", "?")], TONE_CARD)
	VerifiedRules.Night.refresh(self)
	VerifiedRules.MonkCleaner.refresh(self)
	VerifiedRules.Enma.refresh(self)
	_fire_hooks(p_idx, -1, "realm-deployed", {})
	VerifiedRules.TwinSight.realm_entered(self, p_idx, deployed)
	VerifiedRules.Blueprint.realm_entered(self, p_idx, deployed)
	VerifiedRules.Grudge.realm_tick(self, p_idx, deployed)
	VerifiedRules.ShenqiHuang.realm_entered(self, p_idx, deployed)


func _heal_unit(unit: Dictionary, amount: int) -> void:
	if unit.get("toxicPoisoned",false) or int(unit.hp)<=0 or amount<=0:return
	if VerifiedRules.Hanafuda.heal_shared(self, unit, amount): return
	var healed:=maxi(0,mini(amount,int(unit.maxHp)-int(unit.hp)))
	unit.hp=int(unit.hp)+healed
	if healed>0:
		VerifiedRules.TreeSakura.sync_power(unit)
		_log("%s 恢复 %d 点生命。"%[unit.name,healed],TONE_SUCCESS)
	VerifiedRules.MusicFire.healed(self,unit)
	for owner in 2:
		var idx:=_unit_index_by_uid(owner,str(unit.get("uid","")))
		if idx>=0:
			VerifiedRules.EssenceFeast.healed(self,owner,idx,amount,healed,amount-healed)
			VerifiedRules.Wave7Reworks.overheal(self, owner, idx, amount-healed)
			if unit.get("formRules", {}).get("w7MonkFullPower", false): _recalc(unit)
			break


func _heal_avatar(p_idx: int, amount: int) -> void:
	if player(p_idx).get("avatarToxicPoisoned",false) or amount<=0:return
	var p:=player(p_idx)
	var healed:=maxi(0,mini(amount,int(p.maxAvatarHp)-int(p.avatarHp)))
	p.avatarHp=int(p.avatarHp)+healed
	VerifiedRules.Hanafuda.sync_shared(self, p_idx)
	if healed>0:
		_log("%s 的核心恢复 %d 点生命。"%[p.name,healed],TONE_SUCCESS)
		var context:=_card_effect_context;_card_effect_context={}
		VerifiedRules.ArmorBlood.healing_recorded(self)
		for src in p.units.size():
			VerifiedRules.ArmorBlood.avatar_healed(self,p_idx,healed,src)
			VerifiedRules.Light.avatar_healed(self,p_idx,healed,src)
		_card_effect_context=context
	VerifiedRules.EssenceFeast.healed(self,p_idx,-1,amount,healed,amount-healed)


func _grant_unit_armor(unit: Dictionary, amount: int, expires: bool = true) -> int:
	if amount <= 0 or int(unit.hp) <= 0: return 0
	for owner in 2:
		if player(owner).units.has(unit): amount+=VerifiedRules.House.armor_bonus(self,owner)
	# Armor and armor break cancel immediately; barrier is a separate status.
	var cancelled := mini(amount, int(unit.get("armorBreak", 0)))
	unit.armorBreak = int(unit.get("armorBreak", 0)) - cancelled
	VerifiedRules.StarBear.consumed_break(unit,cancelled)
	var gained: int = VerifiedRules.ArmorBreak.capped_gain(int(unit.shield), amount - cancelled)
	unit.shield = int(unit.shield) + gained
	if expires: unit.shieldExpires = int(unit.get("shieldExpires", 0)) + gained
	if cancelled > 0: VerifiedRules.event(self, "armor-cancelled", {"uid": unit.uid, "amount": cancelled})
	if cancelled > 0:
		VerifiedRules.Poison.refresh_all(self)
		if int(unit.get("peacockMistPenalty",0))>0 or VerifiedRules.CoopFirst.has_miasma(self, unit): _recalc(unit)
	VerifiedRules.ArmorBlood.armor_changed(self, unit)
	VerifiedRules.MonkCleaner.armor_gained(self, unit, gained)
	VerifiedRules.YanmieTrio.armor_gained(self, unit, gained)
	return gained


func _grant_avatar_armor(owner: int, amount: int) -> int:
	if amount <= 0: return 0
	amount+=VerifiedRules.House.armor_bonus(self,owner)
	var p := player(owner)
	var cancelled := mini(amount, int(p.get("avatarArmorBreak", 0)))
	p.avatarArmorBreak = int(p.get("avatarArmorBreak", 0)) - cancelled
	var gained: int = VerifiedRules.ArmorBreak.capped_gain(int(p.get("avatarArmor", 0)), amount - cancelled)
	p.avatarArmor = int(p.get("avatarArmor", 0)) + gained
	if cancelled > 0: VerifiedRules.event(self, "armor-cancelled", {"player": owner, "uid": "", "amount": cancelled})
	return gained


func _record_spell_damage(victim: int, target: String, amount: int, blocked: bool = false) -> void:
	if _card_effect_context.is_empty(): return
	var context := _card_effect_context
	var card: Dictionary = context.get("cardOverride", ContentLoader.card_def(str(context.get("definitionId", ""))))
	if card.is_empty(): return
	var owner := int(context.playerIndex)
	var src := int(context.sourceIndex)
	VerifiedRules.event(self, "damage-resolved", {"player": owner, "uid": str(player(owner).units[src].uid) if src>=0 else "avatar-%d"%owner, "target": target, "victimPlayer": victim, "amount": amount, "blocked": blocked, "card": card, "resolutionId": int(context.get("resolutionId", -1))})


func _damage_unit(p_idx: int, unit_index: int, amount: int, _src_player: int, source_index: int = -1, combat: bool = false, knockout_extra: int = -1, transfer_pending: bool = false, critical: bool = false, shell_modified: bool = false) -> Dictionary:
	# Knockout changes the unit only; avatar damage requires its own effect.
	var p := player(p_idx)
	if unit_index < 0 or unit_index >= p.units.size():
		return {"damage": 0, "knocked": false, "overkill": 0}
	if amount < 0:
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	var u: Dictionary = p.units[unit_index]
	if (not combat and VerifiedRules.Izanami.protected(self, p_idx, u)) or VerifiedRules.PeachGrove.petal_protects(self, p_idx, u):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if (u.get("giftHiss", false) or u.get("forestSpellImmune", false)) and not combat:
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	if amount > 0 and not combat and _src_player >= 0 and _src_player != p_idx and VerifiedRules.ZenMisfortune.protect(self, p_idx, u, _src_player):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	VerifiedRules.Glutton.mark_hand(self,p_idx)
	if source_index < 0 and int(_card_effect_context.get("playerIndex", -2)) == _src_player:
		source_index = int(_card_effect_context.get("sourceIndex", -1))
	critical=VerifiedRules.MirrorSong.spell_critical(self,_src_player,source_index,combat,critical)
	var mirror_damage=VerifiedRules.MirrorSong.spell_unit(self,p_idx,unit_index,amount,_src_player,source_index,combat,knockout_extra,transfer_pending,critical,shell_modified)
	if mirror_damage!=null:return mirror_damage
	if VerifiedRules.FoxLotus.prevents_damage(self,_src_player,source_index):
		_record_spell_damage(p_idx,str(u.uid),0,true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	if not shell_modified and not transfer_pending: amount=maxi(0,amount+VerifiedRules.HandBlessing.damage_delta(self,_src_player,source_index,combat) + VerifiedRules.FoxFlame.damage_delta(self,p_idx,u,_src_player,source_index,combat) + VerifiedRules.CarFrog.spell_bonus(self,_src_player,source_index,combat))
	if int(u.hp) <= 0 or amount < 0 or (amount == 0 and not VerifiedRules.Mianqiling.positive_zero(self,p_idx,unit_index,_src_player,source_index,combat)):
		VerifiedRules.TreeSakura.dead_damage(self, _src_player, source_index, p_idx, unit_index, amount)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if not shell_modified and not transfer_pending: amount+=VerifiedRules.Maple.damage_bonus(self,_src_player,source_index,combat)
	if combat and VerifiedRules.CoopMiddle.combat_immune(self, u):
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if not shell_modified and not transfer_pending:
		amount += VerifiedRules.Hanafuda.noncombat_bonus(self, _src_player, source_index, combat)
		amount += VerifiedRules.CoopMiddle.noncombat_bonus(self, _src_player, source_index, combat)
	if not shell_modified and not transfer_pending: amount+=VerifiedRules.DragonFlow.noncombat_bonus(self,_src_player,source_index,combat)
	if amount > 0 and VerifiedRules.DragonFlow.converts_damage(self,_src_player,source_index,p_idx,unit_index):
		return VerifiedRules.ArmorBreak.give(self, _src_player if _src_player >= 0 else p_idx, source_index, p_idx, unit_index, amount)
	var mf_conversion=VerifiedRules.MusicFire.damage_replacement(self,p_idx,unit_index,amount,_src_player,source_index,combat)
	if mf_conversion!=null:return mf_conversion
	if not shell_modified:
		var special = VerifiedRules.MonkCleaner.special_damage(self, p_idx, unit_index, amount, _src_player, source_index, combat)
		if special != null: return special
	transfer_pending = VerifiedRules.ArmorBlood.take_transfer(u) or transfer_pending
	if VerifiedRules.Poison.convert_damage(self, _src_player, source_index, p_idx, unit_index, amount):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	var star_redirected = VerifiedRules.StarBear.redirect(self,p_idx,unit_index,amount,_src_player,source_index,combat,critical)
	if star_redirected != null: return star_redirected
	if VerifiedRules.OwlInsect.prevents_damage(self,u,_src_player,source_index):
		_record_spell_damage(p_idx,str(u.uid),0,true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	_resolve_damage_response(p_idx, unit_index)
	if VerifiedRules.IronMouse.prevents_damage(self, u):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	transfer_pending = VerifiedRules.ArmorBlood.take_transfer(u) or transfer_pending
	if int(u.hp) <= 0 or winner >= 0:
		return {"damage": 0, "knocked": false, "overkill": 0, "cancelled": true}
	var redirected = VerifiedRules.MonkCleaner.redirect(self, p_idx, unit_index, amount, _src_player, source_index, combat, critical)
	if redirected != null: return redirected
	var mirror_redirect=VerifiedRules.MirrorSong.redirect(self,p_idx,unit_index,amount,_src_player,source_index,combat,critical)
	if mirror_redirect!=null:return mirror_redirect
	if not _card_effect_context.is_empty() and int(_card_effect_context.playerIndex) != p_idx:
		if not _card_effect_context.affectedUnits.has(u.uid): _card_effect_context.affectedUnits.append(u.uid)
	if _src_player >= 0 and source_index >= 0 and VerifiedRules.Combat.has(player(_src_player).units[source_index], "penetration"):
		VerifiedRules.Combat.strip_protection(self, p_idx, unit_index, true)
	if VerifiedRules.Otakemaru.damage_prevent(self,p_idx,unit_index,amount):
		_record_spell_damage(p_idx,str(u.uid),0,true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	if VerifiedRules.Zhenjian.prevents_damage(self,p_idx,unit_index,amount,combat):
		_record_spell_damage(p_idx,str(u.uid),0,true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	if u.get("crabCombatImmune", false) or (combat and VerifiedRules.BlackWhite.combat_immune(u)):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if u.get("barrier", false):
		u.barrier = false
		_log("%s 的屏障抵挡了本次伤害。" % u.name, TONE_SUCCESS)
		VerifiedRules.event(self, "barrier-broken", {"uid": u.uid, "player": p_idx})
		VerifiedRules.ZenMisfortune.ward_lost(self, p_idx, u)
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "knocked": false, "overkill": 0}
	if not transfer_pending and (VerifiedRules.FoxSuzuka.immune(self, p_idx, unit_index, _src_player, source_index) or VerifiedRules.Shantong.immune(u, p_idx, _src_player, combat)):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	var preview: int = VerifiedRules.Bingyong.limit_damage(u, amount + int(u.armorBreak) + (1 if int(u.brittle) > 0 else 0))
	preview = VerifiedRules.WisdomLamp.damage_limit(self,p_idx,u,preview)
	preview = maxi(0, preview - int(u.shield))
	if critical and _src_player != p_idx: preview *= 2
	preview = VerifiedRules.Zhenjian.reduce_damage(u,preview,combat)
	preview = VerifiedRules.Jorogumo.received_damage(u,preview)
	preview = VerifiedRules.Mianqiling.modify_damage(self,p_idx,unit_index,preview,_src_player,source_index,combat)
	preview = VerifiedRules.OwlInsect.reduced(u,VerifiedRules.MonkCleaner.reduced(u, preview))
	var preview_cap := int(u.get("formRules", {}).get("damageCap", 0))
	if preview_cap > 0: preview = mini(preview, preview_cap)
	if not transfer_pending and VerifiedRules.Movement.prevents_lethal(self, p_idx, unit_index, preview):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if not transfer_pending and VerifiedRules.PipeFox.damage_amount(self, p_idx, VerifiedRules.Chen.reduce_damage(u, preview)) >= int(u.hp) and VerifiedRules.Chen.ward(self, p_idx, unit_index):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if not transfer_pending and VerifiedRules.Langya.prevents_lethal(self, p_idx, unit_index, VerifiedRules.PipeFox.damage_amount(self, p_idx, preview)):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	var house_break_snapshot := int(u.armorBreak)
	var dmg := amount + VerifiedRules.ArmorBreak.consume(self, p_idx, unit_index)
	if int(u.brittle) > 0:
		dmg += 1
		u.brittle = int(u.brittle) - 1
	dmg = VerifiedRules.Bingyong.limit_damage(u, dmg)
	dmg = VerifiedRules.WisdomLamp.damage_limit(self,p_idx,u,dmg)
	var absorbed := mini(int(u.shield), dmg)
	u.shield = int(u.shield) - absorbed
	VerifiedRules.YanmieTrio.armor_removed(self, p_idx, unit_index, absorbed)
	VerifiedRules.StarBear.consumed_armor(u,absorbed)
	u.shieldExpires = maxi(0, int(u.get("shieldExpires", 0)) - absorbed)
	VerifiedRules.ArmorBlood.armor_changed(self, u)
	var unshielded := dmg - absorbed
	if critical and _src_player != p_idx: unshielded *= 2
	unshielded = VerifiedRules.Zhenjian.reduce_damage(u,unshielded,combat)
	unshielded = VerifiedRules.Jorogumo.received_damage(u,unshielded)
	unshielded = VerifiedRules.Mianqiling.modify_damage(self,p_idx,unit_index,unshielded,_src_player,source_index,combat)
	unshielded = VerifiedRules.OwlInsect.reduced(u,VerifiedRules.MonkCleaner.reduced(u, unshielded))
	unshielded = VerifiedRules.Chen.reduce_damage(u, VerifiedRules.Langya.reduce_damage(u, unshielded))
	unshielded = VerifiedRules.PeachGrove.reduce_damage(self, p_idx, u, unshielded)
	unshielded = VerifiedRules.FactionArt.resolute(u, unshielded)
	if VerifiedRules.DragonAbyss.Curse.has_trait(u, "resolute") or u.get("forestResolute", false) or u.get("starsBondResolute", false): unshielded = maxi(0, unshielded-1)
	unshielded=VerifiedRules.PipeFox.damage_amount(self,p_idx,unshielded)
	if VerifiedRules.Bamboo.cover(self,p_idx,unit_index,unshielded):
		_record_spell_damage(p_idx,str(u.uid),0,true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	if VerifiedRules.Night.replace_damage(self, p_idx, unit_index, unshielded, combat):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if VerifiedRules.OwlInsect.replace_damage(self,p_idx,unit_index,unshielded):
		_record_spell_damage(p_idx,str(u.uid),0,true)
		return {"damage":0,"dealt":0,"knocked":int(u.hp)<=0,"overkill":0}
	if VerifiedRules.BondDream.prevent_damage(self, p_idx, unit_index, unshielded):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": int(u.hp) <= 0, "overkill": 0}
	if VerifiedRules.SerpentGhost.before_damage(self,p_idx,unit_index,unshielded):
		_record_spell_damage(p_idx,str(u.uid),0,true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	var asura_transfer=VerifiedRules.OniAsura.transfer(self,p_idx,unit_index,unshielded,_src_player,source_index,combat)
	if asura_transfer!=null: return asura_transfer
	if transfer_pending: return VerifiedRules.ArmorBlood.transfer(self, p_idx, u, unshielded, _src_player, source_index, combat)
	var ef_cap:=int(u.get("formRules",{}).get("damageCap",0))
	var ef_redirect=VerifiedRules.EssenceFeast.replace_unit_damage(self,p_idx,unit_index,mini(unshielded,ef_cap) if ef_cap>0 else unshielded,_src_player,source_index,combat)
	if ef_redirect!=null:
		unshielded=int(ef_redirect.get("remaining",0))
		if unshielded<=0:
			_record_spell_damage(p_idx,str(u.uid),0,true)
			return {"damage":0,"dealt":0,"knocked":int(u.hp)<=0,"overkill":0,"transferredDealt":int(ef_redirect.get("transferredDealt",0))}
	if VerifiedRules.Toxic.executes(self,_src_player,source_index,p_idx,unit_index,unshielded,combat):
		var deaths_before:=int(u.get("rebirthDeaths",0))
		_knockout_unit(u,_src_player,source_index,knockout_extra,house_break_snapshot)
		var body_knocked:=int(u.get("rebirthDeaths",0))>deaths_before
		if body_knocked: VerifiedRules.Yaodao.unit_killed(self,_src_player,source_index,p_idx,unit_index)
		VerifiedRules.event(self,"toxic-execution",{"player":_src_player,"victimPlayer":p_idx,"target":u.uid})
		return {"damage":0,"dealt":0,"knocked":int(u.hp)<=0,"bodyKnocked":body_knocked,"overkill":0,"poisonExecution":true}
	var cap := int(u.get("formRules", {}).get("damageCap", 0))
	if cap > 0: unshielded = mini(unshielded, cap)
	var floor_hp := maxi(VerifiedRules.Shuten.minimum_hp(self, u), VerifiedRules.Wave7Reworks.minimum_hp(self, p_idx))
	var has_unyielding: bool = u.get("akibaFireUnyielding", false) or (int(u.get("curseGauze", 0)) > 0 and u.get("curseGauzeAwake", false)) or VerifiedRules.Mianqiling.unyielding(u) or VerifiedRules.Glutton.has(u,"unyielding") or VerifiedRules.Enma.has(u,"unyielding") or bool(u.get("futakuchiUnyielding",false)) or bool(u.get("owlUnyielding",false)) or (bool(u.get("monkFormUnyielding", false)) and u.get("formRules", {}).get("monkUnyielding", false)) or bool(u.get("dragonUnyielding", false)) or u.unyielding or bool(u.get("combatUnyielding", false)) or bool(u.get("susanooCombatUnyielding",false)) or VerifiedRules.Shuten.has_unyielding(u) or VerifiedRules.Bailang.unyielding(u) or bool(u.get("formRules", {}).get("riverUnyielding", false))
	var unyielding_save: bool = floor_hp == 0 and (has_unyielding or VerifiedRules.Hanafuda.unyielding(u)) and int(u.hp) > 1 and unshielded >= int(u.hp)
	var effective: int = mini(unshielded, int(u.hp) - maxi(floor_hp, 1 if unyielding_save else 0))
	var taken: int = mini(int(u.hp), maxi(0, effective))
	var overkill: int = maxi(0, unshielded - int(u.hp))
	if VerifiedRules.CoopFirst.prevents_lethal(self, p_idx, unit_index, taken):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	if taken >= int(u.hp):
		VerifiedRules.Yijin.will_die(self, p_idx, unit_index)
		if winner >= 0: return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	var asura_heals := VerifiedRules.OniAsura.heal_count(self,p_idx,_src_player)
	if combat and taken > 0: u.yanmieDamageTaken = int(u.get("yanmieDamageTaken", 0)) + taken
	var prior_hp := int(u.hp)
	u.hp = maxi(0, prior_hp - taken)
	VerifiedRules.Hanafuda.reduce_shared(self, p_idx, u, taken)
	VerifiedRules.Commission.damage(self, _src_player, p_idx, taken, combat)
	VerifiedRules.Wave7Reworks.damage_received(self, p_idx, unit_index, taken, prior_hp)
	VerifiedRules.Grudge.damaged(self, p_idx, unit_index, _src_player, taken)
	VerifiedRules.Izanami.changed(self, p_idx, u, prior_hp)
	if u.get("formRules", {}).get("w7MonkFullPower", false): _recalc(u)
	VerifiedRules.OniAsura.damaged(self,p_idx,unit_index,_src_player,unshielded,asura_heals)
	VerifiedRules.TreeSakura.sync_power(u)
	if unyielding_save:
		VerifiedRules.Mianqiling.consume_unyielding(u)
		VerifiedRules.Hanafuda.consume_unyielding(u)
		u.erase("akibaFireUnyielding")
		u.owlUnyielding = false
		u.monkFormUnyielding = false
		u.unyielding = false
		u.erase("dragonUnyielding")
		u.erase("futakuchiUnyielding")
		u.combatUnyielding = false
		u.susanooCombatUnyielding=false
		VerifiedRules.Shuten.consume_unyielding(u)
		VerifiedRules.Enma.consume_unyielding(u)
		VerifiedRules.Glutton.consume_unyielding(u)
		if u.get("formRules", {}).get("riverUnyielding", false): u.formRules.riverUnyielding = false
		if u.has("untilAttack"): u.untilAttack.unyielding = false
		_log("%s 的不屈抵住致命伤。" % u.name, TONE_SUCCESS)
	elif taken > 0:
		_log("%s 受到 %d 点伤害%s。" % [u.name, taken, ("，护盾抵消 %d 点" % absorbed) if absorbed > 0 else ""], TONE_DANGER)
	elif absorbed > 0:
		_log("%s 的护盾抵消了伤害。" % u.name, TONE_NEUTRAL)
	VerifiedRules.RednightWalnut.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken,combat)
	VerifiedRules.ApeSleeve.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken)
	VerifiedRules.SerpentGhost.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken)
	if combat and _src_player>=0 and source_index>=0:VerifiedRules.EssenceFeast.combat_dealt(self,_src_player,source_index,{"dealt":taken})
	VerifiedRules.BlackWhite.damaged(self,p_idx,unit_index,taken)
	VerifiedRules.Lantern.damaged(self,p_idx,unit_index,taken)
	VerifiedRules.SpiderLily.unit_damaged(self,p_idx,unit_index,unshielded)
	VerifiedRules.Doll.damaged(self,p_idx,unit_index,unshielded,_src_player,source_index)
	VerifiedRules.MonkCleaner.damaged(self, p_idx, unit_index, _src_player, source_index, unshielded, combat)
	VerifiedRules.MonkCleaner.dealt(self, _src_player, source_index, p_idx, unit_index, unshielded)
	VerifiedRules.ArmorBlood.damaged(self, p_idx, unit_index, unshielded)
	VerifiedRules.Xuenv.damage_dealt(self, _src_player, source_index, p_idx, unit_index, unshielded, combat)
	VerifiedRules.Shuten.record_damage(self, p_idx, unit_index, unshielded, _src_player)
	if unshielded > 0: u.giftHurtTurn = turn_counter
	VerifiedRules.DragonAbyss.Curse.damaged(self, p_idx, unit_index, _src_player, source_index, taken)
	VerifiedRules.FoxFlame.spent(self, p_idx, u, _src_player, source_index, taken)
	VerifiedRules.CarFrog.damaged(self, p_idx, unit_index, taken)
	if combat: VerifiedRules.StarShopCards.mouse_damage(self, _src_player, source_index, taken)
	VerifiedRules.SunSmoke.damaged(self, p_idx, unit_index, unshielded)
	VerifiedRules.Poison.damaged(self, p_idx, unit_index, _src_player, source_index, unshielded, combat)
	VerifiedRules.FoxSuzuka.damage_dealt(self, _src_player, source_index, p_idx, unit_index, unshielded)
	VerifiedRules.Maple.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken,combat)
	VerifiedRules.DragonFlow.damage_dealt(self, _src_player, source_index, p_idx, unit_index, taken)
	var knocked := false
	var yuj_doom:=VerifiedRules.Yujiazhu.damaged(self,u,taken)
	var toxic_lethal:=VerifiedRules.Toxic.damaged(self,_src_player,source_index,p_idx,unit_index,taken,combat)
	var body_knocked:=false
	if int(u.hp) <= 0 or toxic_lethal or yuj_doom:
		var deaths_before:=int(u.get("rebirthDeaths",0))
		var tomb_serial:=int(u.get("susanooTombSerial",0))
		_knockout_unit(u, _src_player, source_index, knockout_extra, house_break_snapshot, prior_hp)
		knocked = int(u.hp)<=0 or int(u.get("susanooTombSerial",0))>tomb_serial
		body_knocked=int(u.get("rebirthDeaths",0))>deaths_before or int(u.get("susanooTombSerial",0))>tomb_serial
		if knocked: VerifiedRules.Yaodao.unit_killed(self, _src_player, source_index, p_idx, unit_index)
		if knocked: VerifiedRules.DragonFlow.unit_killed(self, _src_player, source_index, p_idx, unit_index)
	if VerifiedRules.WindRaccoon.damaged(self,p_idx,unit_index,_src_player,source_index,taken,house_break_snapshot):
		if not knocked: VerifiedRules.Yaodao.unit_killed(self,_src_player,source_index,p_idx,unit_index)
		knocked=true
	VerifiedRules.BookJue.damage_dealt(self, _src_player, source_index, taken)
	VerifiedRules.Bailang.damage_dealt(self, _src_player, source_index, p_idx, taken, combat)
	_record_spell_damage(p_idx, str(u.uid), taken, taken == 0)
	if not combat: VerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, unshielded)
	VerifiedRules.MirrorSong.after_spell_unit(self,_src_player,source_index,p_idx,unit_index,combat,overkill,unshielded)
	return {"damage": taken, "dealt": unshielded, "knocked": knocked, "bodyKnocked":body_knocked, "overkill": overkill}


func _resolve_damage_response(owner: int, idx: int) -> void:
	# Resolve the automatic response before this one damage event, using real
	# hand payment, spell-use abilities and opposing automatic counters. Keep
	# the interrupted spell/combat stack and its damage provenance intact.
	var outer_stack := resolution_stack
	var outer_context := _card_effect_context
	resolution_stack = []
	if VerifiedRules.automatic_response(self, owner, "source-damaged", player(owner).units[idx].uid, {"kind": "response-complete"}, MAX_RESPONSE_DEPTH):
		while not resolution_stack.is_empty() and winner < 0:
			_resolve_frame(resolution_stack.pop_back())
	resolution_stack = outer_stack
	_card_effect_context = outer_context


func _knockout_unit(u: Dictionary, source_owner: int = -1, source_index: int = -1, knockout_extra: int = -1, prior_armor_break: int = -1, prior_hp: int = -1) -> void:
	# Direct destruction uses the same lifecycle without fabricating damage.
	if int(u.get("knockout", 0)) > 0 and int(u.hp) <= 0: return
	if VerifiedRules.Susanoo.capture_kill(self,u,source_owner,source_index): return
	if VerifiedRules.Susanoo.tomb(u):
		for side in players.size():
			if _unit_index_by_uid(side,u.uid)>=0: VerifiedRules.Susanoo.restore_tomb(self,side,u,false)
	var victim := -1
	for owner in players.size():
		if _unit_index_by_uid(owner, u.uid) >= 0: victim = owner
	var fear_saved:=VerifiedRules.FearWing.knockout_snapshot(self,victim,u)
	var hair_saved:=VerifiedRules.HairPower.knockout_snapshot(victim,u)
	if victim>=0 and VerifiedRules.MusicFire.before_knockout(self,victim,u):
		VerifiedRules.FearWing.after_knockout(self,fear_saved)
		VerifiedRules.HairPower.after_knockout(self,hair_saved)
		return
	if victim>=0: VerifiedRules.Glutton.mark_hand(self,victim)
	if VerifiedRules.Sparrow.absorb_knockout(self,victim,u): return
	if VerifiedRules.Vine.absorb_knockout(self,victim,u): return
	if VerifiedRules.SerpentGhost.replace_knockout(self,victim,u):
		VerifiedRules.FearWing.after_knockout(self,fear_saved)
		VerifiedRules.HairPower.after_knockout(self,hair_saved)
		return
	var sg_saved:=VerifiedRules.SerpentGhost.death_snapshot(self,victim,u)
	var dusk_prior_hp := int(u.hp)
	var wave_saved := VerifiedRules.Wave7Reworks.before_knockout(self, victim, u, int(u.hp) if prior_hp < 0 else prior_hp)
	var hana_saved := VerifiedRules.Hanafuda.death_snapshot(u)
	u.erase("hfBloodPierce")
	VerifiedRules.Crocodile.detach(self,u,"随式神气绝",false)
	var rw_saved:=VerifiedRules.RednightWalnut.death_frames(self,victim,u)
	var sleeve_saved:=VerifiedRules.ApeSleeve.death_frames(self,victim,u)
	var charged_saved:=VerifiedRules.ChargedPair.death_frames(self,victim,u)
	var grudge_wish := VerifiedRules.Grudge.death_frame(self, victim, u)
	var lantern_saved:=VerifiedRules.Lantern.death_frames(self,victim,u)
	var jorogumo_saved := VerifiedRules.Jorogumo.death_frames(self,victim,u)
	var silk_saved:=VerifiedRules.SilkNinja.death_frames(self,victim,u)
	var silk_extra:=VerifiedRules.SilkNinja.knockout_extra(self,victim,u)
	var toxic_saved:=VerifiedRules.Toxic.death_frames(self,victim,u,source_owner,source_index)
	var cotton_saved := VerifiedRules.Cotton.knockout_snapshot(self,victim,u)
	var house_saved := VerifiedRules.House.knockout_snapshot(self,source_owner,source_index,victim,u,prior_armor_break)
	VerifiedRules.Doll.unbind_knocked_out(self,victim,u)
	VerifiedRules.Glutton.knocked_out(self,victim,u)
	VerifiedRules.Otakemaru.knocked_out(self,victim,u)
	var vine_saved := VerifiedRules.Vine.knockout_snapshot(self,victim,u)
	var weaver_saved := VerifiedRules.Weaver.knockout_snapshot(self,victim,u)
	var enma_saved := VerifiedRules.Enma.knockout_snapshot(self,victim,u)
	var sparrow_saved := VerifiedRules.Sparrow.knockout_snapshot(self,victim,u)
	var yaksha_saved := VerifiedRules.Yaksha.knockout_snapshot(u)
	if victim >= 0 and int(u.hp) > 0:
		VerifiedRules.Yijin.will_die(self, victim, _unit_index_by_uid(victim, u.uid))
		if winner >= 0: return
	var coffin_saved := VerifiedRules.Coffin.knockout_snapshot(self, victim, u)
	var commission_revive: bool = victim >= 0 and u.get("formRules", {}).get("commissionRevive", false)
	if knockout_extra < 0: knockout_extra = VerifiedRules.Panguan.extra_knockout(self, victim) if victim >= 0 else 0
	var bone_frames := VerifiedRules.Bone.death_frames(self, victim, u, source_owner, source_index)
	VerifiedRules.StarShopCards.destroyed(self, victim, u)
	VerifiedRules.ForestSpirit.knocked(self, victim, u)
	u.erase("foxFlameBlue")
	u.erase("foxFlameRed")
	if u.id == VerifiedRules.CarFrog.CAR and not u.get("baseRulesSuppressed", false): knockout_extra += 1
	VerifiedRules.DragonAbyss.Serving.knocked(self, victim, u)
	VerifiedRules.DragonAbyss.Jade.knocked(self, victim, u)
	knockout_extra += VerifiedRules.Pine.knockout_extra(u)+silk_extra
	VerifiedRules.Pine.knocked_out(u)
	VerifiedRules.StarBear.knocked_out(u)
	VerifiedRules.ShenqiHuang.knocked_out(u)
	var samurai_saved := VerifiedRules.Samurai.knockout_snapshot(u)
	VerifiedRules.Maple.knocked_out(self,victim,u)
	var dog_demon_was_front := int(u.front) == 1
	var rebirth_saved := VerifiedRules.Rebirth.knockout_snapshot(self,victim,u,dog_demon_was_front)
	VerifiedRules.FoxLotus.knocked_out(self,victim,u)
	if u.get("baseRulesSuppressed", false):
		if u.form.get("cardId") == "yanmie-small-ghost": knockout_extra -= 1
		if u.has("starsFrogTransform"):
			for key in ["starsFrogRestorePlayer", "starsFrogOldForm", "starsFrogTransform"]: u.erase(key)
		VerifiedRules.Fortune.restore(u)
		u.form = {}
		u.formRules = {}
		u.formHooks = []
		u.formAbility = ""
	VerifiedRules.ArmorBlood.knocked_out(u)
	VerifiedRules.DragonFlow.knocked(u)
	VerifiedRules.ZenMisfortune.knocked(self, victim, u)
	VerifiedRules.Movement.knocked_out(self, u)
	VerifiedRules.UpgradeBlessing.knocked_out(u)
	VerifiedRules.IronMouse.knocked_out(u)
	VerifiedRules.Wind.knocked_out(u)
	VerifiedRules.DogDemon.knocked_out(u)
	var oni_saved := VerifiedRules.OniAsura.knockout_snapshot(self,victim,u)
	var charm_saved := VerifiedRules.OwlInsect.knockout_snapshot(self,victim,u) if victim >= 0 else {}
	var light_saved := VerifiedRules.Light.knockout_snapshot(u)
	var snow_saved := VerifiedRules.MonkCleaner.knockout_snapshot(u)
	VerifiedRules.Firefly.knocked_out(u)
	VerifiedRules.Peach.knocked_out(u)
	VerifiedRules.Shuten.knocked_out(u)
	VerifiedRules.Bingyong.knocked_out(u)
	VerifiedRules.SunSmoke.knocked_out(u)
	u.erase("combatUnyielding")
	u.erase("ghSoulOwner")
	u.erase("waterLumen")
	u.erase("waterReturnLight")
	u.erase("untilAttack")
	u.erase("temporaryAttack")
	u.erase("coopLatePower")
	u.erase("grudgeVowTurn")
	VerifiedRules.Xuan.clear_temporary(u)
	u.erase("cranePower")
	u.swift = false
	u.erase("inspired")
	u.hp = 0
	u.front = 0
	u.knockout = VerifiedRules.Bone.countdown(self, victim, u, int(rules.get("knockoutCountdown", 2)) + knockout_extra)
	u.shield = 0
	u.frozen = 0
	u.brittle = 0
	u.armorBreak = 0
	if ContentLoader.unit_def(u.id).has("formLifecycle") or u.get("form",{}).get("native",false):
		for owner in 2:
			var idx := _unit_index_by_uid(owner, u.uid)
			if idx >= 0: VerifiedRules.Forms.remove(self, owner, idx, "随式神气绝")
	VerifiedRules.EssenceFeast.knocked_out(self,victim,u)
	VerifiedRules.FearWing.after_knockout(self,fear_saved)
	VerifiedRules.knocked_out(u)
	VerifiedRules.MusicFire.after_knockout(self,victim,u)
	VerifiedRules.Poison.refresh_all(self)
	u.shieldExpires = 0
	_recalc(u)
	VerifiedRules.SerpentGhost.after_knockout(self,victim,u,sg_saved)
	VerifiedRules.RedPurple.refresh(self)
	if u.get("smokeClone", false): VerifiedRules.SunSmoke.remove_clone(self, victim, u, "分身气绝")
	_log("%s 气绝，将在 %d 个己方回合后归队。" % [u.name, int(u.knockout)], TONE_DANGER)
	if victim >= 0:
		VerifiedRules.DogDemon.unit_killed(self, source_owner, source_index, victim, u, dog_demon_was_front)
		VerifiedRules.Wave7Reworks.killed(self, source_owner, source_index, victim, u)
		VerifiedRules.Panguan.destroyed(self, source_owner, source_index, victim, u)
		VerifiedRules.Light.after_knockout(self, victim, _unit_index_by_uid(victim, u.uid), light_saved)
		VerifiedRules.MonkCleaner.after_knockout(self, victim, _unit_index_by_uid(victim, u.uid), snow_saved)
	VerifiedRules.MonkCleaner.refresh(self)
	VerifiedRules.OwlInsect.after_knockout(self,charm_saved)
	if not oni_saved.is_empty(): resolution_stack.append(oni_saved)
	rebirth_saved.reverse(); resolution_stack.append_array(rebirth_saved)
	if victim>=0: VerifiedRules.Samurai.knocked_out(self,victim,u,samurai_saved)
	if victim >= 0:
		VerifiedRules.CatSamurai.knocked_out(self, victim, u, samurai_saved)
		VerifiedRules.Wave7Reworks.after_knockout(self, victim, _unit_index_by_uid(victim, u.uid), wave_saved)
		VerifiedRules.Hanafuda.died(self, victim, u, hana_saved)
		if u.get("nativeFieldSummon", false): VerifiedRules.NativeSummons.remove(self, victim, u)
	if u.get("paintSummon",false): VerifiedRules.Paint.summoned_knockout(self,victim,u)
	if u.get("pineSummon",false): VerifiedRules.Pine.summoned_knockout(self,victim,u)
	if u.get("enmaGhost",false): VerifiedRules.Enma.summoned_knockout(self,victim,u)
	if u.get("weaverSummon",false): VerifiedRules.Weaver.summoned_knockout(self,victim,u)
	if u.get("vineSummon",false): VerifiedRules.Vine.summoned_knockout(self,victim,u)
	if u.get("windRaccoonClone",false): VerifiedRules.WindRaccoon.summoned_knockout(self,victim,u)
	if u.get("boxSummon",false): VerifiedRules.BoxMaiden.summoned_knockout(self,victim,u)
	if u.get("houseSummon",false): VerifiedRules.House.summoned_knockout(self,victim,u)
	if u.get("dollSummon",false): VerifiedRules.Doll.summoned_knockout(self,victim,u)
	if u.get("mfDoll",false): VerifiedRules.MusicFire.summoned_knockout(self,victim,u)
	if u.get("scSummon",false): VerifiedRules.SugarCat.summoned_knockout(self,victim,u)
	if u.get("efPowderBoxSummon",false): VerifiedRules.EssenceFeast.remove_box(self,victim,u)
	if u.get("rtSpear",false): VerifiedRules.RabbitTide.summoned_knockout(self,victim,u)
	resolution_stack.append_array(jorogumo_saved)
	resolution_stack.append_array(toxic_saved)
	resolution_stack.append_array(silk_saved)
	resolution_stack.append_array(lantern_saved)
	resolution_stack.append_array(charged_saved)
	if not grudge_wish.is_empty(): resolution_stack.append(grudge_wish)
	resolution_stack.append_array(sleeve_saved)
	resolution_stack.append_array(rw_saved)
	VerifiedRules.Toxic.refresh(self)
	if u.get("toxicSwarm",false): VerifiedRules.Toxic.remove_swarm(self,victim,u)
	if u.get("arkFish",false):
		u.hp=0; u.front=0; u.knockout=0; u.removed=true
	if u.get("whaleGuardian",false):
		u.hp=0; u.front=0; u.knockout=0; u.removed=true
	if u.get("jorogumoSwarm",false):
		u.hp=0; u.front=0; u.knockout=0; u.removed=true
	resolution_stack.append_array(house_saved)
	resolution_stack.append_array(vine_saved)
	resolution_stack.append_array(weaver_saved)
	resolution_stack.append_array(enma_saved)
	resolution_stack.append_array(sparrow_saved)
	VerifiedRules.Yaksha.knocked_out(self,victim,u,yaksha_saved)
	VerifiedRules.DuskCycle.knockout(self, victim, u, dusk_prior_hp)
	resolution_stack.append_array(cotton_saved)
	VerifiedRules.HairPower.after_knockout(self,hair_saved)
	if u.get("bambooStone",false): resolution_stack.append({"kind":"bamboo-remove","playerIndex":victim})
	if u.id == VerifiedRules.Bone.REMAINS: VerifiedRules.Bone.remove(self, victim, u)
	if u.id == VerifiedRules.TwinSight.CAT: VerifiedRules.TwinSight.remove(self, victim, u)
	resolution_stack.append_array(bone_frames)
	VerifiedRules.YanmieTrio.knocked_out(self, victim, u)
	VerifiedRules.Coffin.knocked_out(self, victim, u, source_owner, source_index, coffin_saved)
	VerifiedRules.CoopFirst.knocked_out(self, victim, u)
	if victim >= 0:
		var idx := _unit_index_by_uid(victim, u.uid)
		if idx >= 0: VerifiedRules.CoopMiddle.knockout_changed(self, victim, idx)
	VerifiedRules.Commission.knockouts(self, source_owner, victim, u)
	if commission_revive: VerifiedRules.Commission.queue(self, victim, _unit_index_by_uid(victim, u.uid), "commission-revive")


func _damage_avatar(p_idx: int, amount: int, _src_player: int = -1, source_index: int = -1, critical: bool = false, combat: bool = false, shell_modified: bool = false, realm_loss_multiplier: int = 1) -> int:
	if not shell_modified: amount=maxi(0,amount+VerifiedRules.HandBlessing.damage_delta(self,_src_player,source_index,combat))
	var p := player(p_idx)
	if amount <= 0 or winner >= 0:
		return 0
	if source_index < 0 and int(_card_effect_context.get("playerIndex", -2)) == _src_player: source_index = int(_card_effect_context.get("sourceIndex", -1))
	critical=VerifiedRules.MirrorSong.spell_critical(self,_src_player,source_index,combat,critical)
	if VerifiedRules.FoxLotus.prevents_damage(self,_src_player,source_index):
		_record_spell_damage(p_idx,"",0,true)
		return 0
	if not shell_modified: amount+=VerifiedRules.Maple.damage_bonus(self,_src_player,source_index,combat)
	if not shell_modified: amount+=VerifiedRules.DragonFlow.noncombat_bonus(self,_src_player,source_index,combat)
	if not shell_modified: amount+=VerifiedRules.CarFrog.spell_bonus(self,_src_player,source_index,combat)
	if VerifiedRules.DragonFlow.converts_damage(self,_src_player,source_index,p_idx,-1):
		return int(VerifiedRules.ArmorBreak.give(self,_src_player,source_index,p_idx,-1,amount).damage)
	amount+=VerifiedRules.BlueGreen.avatar_bonus(self,_src_player,source_index)
	if not shell_modified:
		var special = VerifiedRules.MonkCleaner.special_damage(self, p_idx, -1, amount, _src_player, source_index, combat)
		if special != null: return int(special.damage)
	if VerifiedRules.Poison.convert_damage(self, _src_player, source_index, p_idx, -1, amount):
		_record_spell_damage(p_idx, "", 0, true)
		return 0
	var star_redirected = VerifiedRules.StarBear.redirect(self,p_idx,-1,amount,_src_player,source_index,combat,critical)
	if star_redirected != null: return int(star_redirected.get("dealt",star_redirected.damage))
	if not shell_modified:
		amount += VerifiedRules.Hanafuda.noncombat_bonus(self, _src_player, source_index, combat)
		amount += VerifiedRules.CoopMiddle.noncombat_bonus(self, _src_player, source_index, combat)
	var pending_armor := 0 if _src_player >= 0 and source_index >= 0 and VerifiedRules.Combat.has(player(_src_player).units[source_index], "penetration") else int(p.avatarArmor)
	if VerifiedRules.PipeFox.protects_avatar(self,p_idx,_src_player,combat):
		_record_spell_damage(p_idx,"",0,true)
		return 0
	if VerifiedRules.Light.prevents_avatar_damage(self, p_idx, maxi(0, amount + int(p.avatarArmorBreak) - pending_armor) * (2 if critical and _src_player != p_idx else 1)):
		_record_spell_damage(p_idx, "", 0, true)
		return 0
	var redirected = VerifiedRules.MonkCleaner.redirect(self, p_idx, -1, amount, _src_player, source_index, combat, critical)
	if redirected != null: return int(redirected.get("dealt", redirected.damage))
	if _src_player >= 0 and source_index >= 0 and VerifiedRules.Combat.has(player(_src_player).units[source_index], "penetration"):
		VerifiedRules.Combat.strip_protection(self, p_idx, -1, true)
	amount += VerifiedRules.ArmorBreak.consume(self, p_idx, -1)
	var absorbed := mini(amount, int(p.get("avatarArmor", 0)))
	p.avatarArmor = int(p.get("avatarArmor", 0)) - absorbed
	amount -= absorbed
	if critical and _src_player != p_idx: amount *= 2
	amount=VerifiedRules.PipeFox.damage_amount(self,p_idx,amount)
	if absorbed > 0: _log("%s 的牌手护甲抵挡%d点伤害。" % [p.name, absorbed], TONE_NEUTRAL)
	if amount <= 0:
		_record_spell_damage(p_idx, "", 0, true)
		return 0
	if VerifiedRules.Toxic.executes(self,_src_player,source_index,p_idx,-1,amount,combat):
		p.avatarHp=0
		VerifiedRules.event(self,"toxic-execution",{"player":_src_player,"victimPlayer":p_idx,"target":""})
		_check_winner(); return 0
	var floor_hp := 1 if VerifiedRules.ArmorBlood.protects_avatar(self, p_idx) else VerifiedRules.Wave7Reworks.minimum_hp(self, p_idx)
	if not combat and str(_card_effect_context.get("definitionId", "")) == VerifiedRules.GoatHeist.NOTICE and source_index >= 0 and _src_player != p_idx:
		return VerifiedRules.GoatHeist.avatar_steal(self, _src_player, source_index, p_idx)
	var actual_loss := mini(maxi(0, int(p.avatarHp) - floor_hp), amount)
	var asura_heals := VerifiedRules.OniAsura.heal_count(self,p_idx,_src_player)
	p.avatarHp = maxi(floor_hp, int(p.avatarHp) - amount)
	VerifiedRules.Hanafuda.sync_shared(self, p_idx)
	var realm_loss := amount * realm_loss_multiplier
	if not VerifiedRules.Night.defer_avatar_realm_damage(self, p_idx, realm_loss): VerifiedRules.ArmorBlood.damage_realm(self, p_idx, realm_loss)
	_log("%s 的核心受到 %d 点伤害。" % [p.name, amount], TONE_DANGER)
	VerifiedRules.OniAsura.damaged(self,p_idx,-1,_src_player,amount,asura_heals)
	VerifiedRules.Phoenix.avatar_damaged(self, _src_player, source_index, p_idx, amount)
	VerifiedRules.Yaodao.avatar_damaged(self, _src_player, source_index, p_idx, amount)
	VerifiedRules.CoopFirst.avatar_damaged(self, _src_player, source_index, p_idx, amount)
	VerifiedRules.BookJue.avatar_damaged(self, _src_player, source_index, p_idx, amount)
	VerifiedRules.Mengpo.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss)
	VerifiedRules.TomatoFire.avatar_damaged(self, _src_player, source_index, p_idx, amount)
	VerifiedRules.KoiFragrance.avatar_damage(self,_src_player,source_index,p_idx,actual_loss,combat)
	VerifiedRules.CatSamurai.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss, combat)
	VerifiedRules.Wave7Reworks.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss)
	VerifiedRules.Toxic.avatar_damaged(self,_src_player,source_index,p_idx,actual_loss,combat)
	VerifiedRules.Movement.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss)
	VerifiedRules.Headless.avatar_damaged(self,_src_player,source_index,p_idx,actual_loss)
	VerifiedRules.WindRaccoon.avatar_damaged(self,_src_player,source_index,p_idx,actual_loss)
	VerifiedRules.Mask.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss)
	VerifiedRules.Maple.damage_dealt(self,_src_player,source_index,p_idx,-1,actual_loss,combat)
	VerifiedRules.SerpentGhost.damage_dealt(self,_src_player,source_index,p_idx,-1,actual_loss)
	VerifiedRules.Commission.damage(self, _src_player, p_idx, actual_loss, combat)
	VerifiedRules.WisdomLamp.avatar_damaged(self,p_idx,_src_player,source_index,actual_loss,combat)
	VerifiedRules.Treasure.avatar_damaged(self, p_idx, _src_player, source_index, actual_loss, combat)
	VerifiedRules.EssenceFeast.avatar_damaged(self,p_idx,actual_loss)
	if combat and _src_player>=0 and source_index>=0:VerifiedRules.EssenceFeast.combat_dealt(self,_src_player,source_index,{"dealt":actual_loss})
	VerifiedRules.SpiderLily.avatar_damaged(self, p_idx, _src_player, amount)
	VerifiedRules.GiftEnergy.avatar_damage(self, p_idx, _src_player, source_index, actual_loss, combat)
	VerifiedRules.NineTails.avatar_dealt(self, p_idx, _src_player, source_index, actual_loss, combat)
	VerifiedRules.TimeRewind.avatar_hit(self, p_idx, _src_player, source_index, actual_loss)
	VerifiedRules.GoatHeist.avatar_hit(self, _src_player, source_index, p_idx, actual_loss)
	if combat: VerifiedRules.StarShopCards.mouse_damage(self, _src_player, source_index, actual_loss)
	VerifiedRules.SunSmoke.damaged(self, p_idx, -1, amount)
	VerifiedRules.FoxSuzuka.damage_dealt(self, _src_player, source_index, p_idx, -1, amount)
	_record_spell_damage(p_idx, "", actual_loss)
	_check_winner()
	VerifiedRules.ArmorBlood.spell_damage(self, _src_player, source_index, amount)
	VerifiedRules.MirrorSong.after_spell_avatar(self,_src_player,source_index,combat,amount)
	return amount


func _check_winner() -> void:
	if _deferred_winner_checks > 0: return
	if winner >= 0:
		return
	for i in players.size():
		if int(player(i).avatarHp) <= 0:
			winner = 1 - i
			_log("%s 稳定了界碑核心。" % player(winner).name, TONE_SUCCESS)
			match_finished.emit(winner)
			return


func basic_attack_targets(p_idx: int, unit_index: int) -> Array:
	if unit_index < 0 or unit_index >= player(p_idx).units.size(): return []
	if VerifiedRules.HairPower.guard_count(self,p_idx)>0:return [str(player(p_idx).units[unit_index].uid)]
	var skill := VerifiedRules.BattleSkill.ready(self,p_idx,unit_index)
	if not skill.is_empty():
		if skill.get("target","auto") != "auto": return valid_targets(p_idx,skill)
		if skill.get("combatOption",{}).get("directAvatar",false): return ["avatar-%d" % enemy_index(p_idx)]
		var default_front := front_unit(enemy_index(p_idx))
		return ["avatar-%d" % enemy_index(p_idx)] if default_front.is_empty() else [str(default_front.uid)]
	var forced=VerifiedRules.StarBear.basic_target(self,p_idx)
	if forced!=null: return [forced]
	var yuj_targets=VerifiedRules.Yujiazhu.prayer_targets(self,p_idx,unit_index)
	if yuj_targets!=null:return yuj_targets
	var samurai_targets=VerifiedRules.Samurai.attack_targets(self,p_idx,unit_index)
	if samurai_targets!=null: return samurai_targets
	var special = VerifiedRules.TreeSakura.attack_targets(self, p_idx, unit_index)
	if special != null: return special
	var bond_targets = VerifiedRules.StarShopCards.basic_targets(self, p_idx, player(p_idx).units[unit_index])
	if bond_targets != null: return bond_targets
	var fox_targets = VerifiedRules.FoxFlame.basic_targets(self, p_idx, player(p_idx).units[unit_index])
	if fox_targets != null: return fox_targets
	if VerifiedRules.GoatHeist.direct(self, p_idx, player(p_idx).units[unit_index]): return ["avatar-%d" % enemy_index(p_idx)]
	var gh_targets = VerifiedRules.Guishihei.attack_targets(self, p_idx, unit_index)
	if gh_targets != null: return gh_targets
	var enemy := enemy_index(p_idx)
	if VerifiedRules.Combat.has(player(p_idx).units[unit_index],"direct"): return ["avatar-%d"%enemy]
	if VerifiedRules.Combat.has(player(p_idx).units[unit_index], "pursuit"):
		return player(enemy).units.filter(func(u): return int(u.hp) > 0 and not VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	var front := front_unit(enemy)
	return ["avatar-%d" % enemy] if front.is_empty() else [str(front.uid)]


func basic_attack_requires_target(p_idx: int, unit_index: int) -> bool:
	var skill := VerifiedRules.BattleSkill.ready(self, p_idx, unit_index)
	if not skill.is_empty(): return VerifiedRules.BattleSkill.requires_target(self, p_idx, unit_index)
	var unit: Dictionary = player(p_idx).units[unit_index]
	return VerifiedRules.StarShopCards.basic_targets(self, p_idx, unit) != null or VerifiedRules.FoxFlame.basic_targets(self, p_idx, unit) != null or VerifiedRules.Combat.has(unit, "pursuit") or VerifiedRules.TreeSakura.floating(unit) or VerifiedRules.Guishihei.attack_targets(self, p_idx, unit_index) != null


func can_basic_attack(p_idx: int, unit_index: int, ignore_enrage: bool = false) -> Dictionary:
	if VerifiedRules.Link.ready_hand(self,p_idx)>=0:return {"ok":false,"reason":"请先完成已选择的连引牌。"}
	if winner >= 0 or current_player != p_idx or phase == "opening":
		return {"ok": false, "reason": "现在不是你的行动阶段。"}
	if is_upgrade_pending(p_idx):
		return {"ok": false, "reason": "升级阶段：请先选择一名角色提升勾玉。"}
	var p := player(p_idx)
	if int(p.get("avatarFrozen", 0)) > 0:
		return {"ok": false, "reason": "牌手处于眩晕状态，不能令式神普通出击。"}
	if p.attackUsed and VerifiedRules.HairPower.guard_count(self,p_idx)<=0 and VerifiedRules.Butterfly.free_realm(self,p_idx).is_empty() and (unit_index < 0 or unit_index >= p.units.size() or (not VerifiedRules.Combat.has(p.units[unit_index], "inspired") and not VerifiedRules.Movement.extra_attack(self, p_idx, p.units[unit_index]) and not VerifiedRules.Moon.extra_attack(self,p_idx))):
		return {"ok": false, "reason": "本回合已经出击过。"}
	if unit_index < 0 or unit_index >= p.units.size():
		return {"ok": false, "reason": "该角色无法出击。"}
	var u: Dictionary = p.units[unit_index]
	if VerifiedRules.Combat.has(u, "pursuit") and basic_attack_targets(p_idx, unit_index).is_empty():
		return {"ok": false, "reason": "追猎需要一个可选的敌方式神。"}
	if not VerifiedRules.SerpentGhost.can_deploy(u):return {"ok":false,"reason":"混沌化身不能手动出击。"}
	if VerifiedRules.CatSamurai.bodyless(self, u): return {"ok": false, "reason": "武魂形态不能普通出击。"}
	if u.has("waveIbarakiGhost"): return {"ok": false, "reason": "鬼蚀只能使用起源牌。"}
	if not VerifiedRules.RednightWalnut.can_deploy(u):return {"ok":false,"reason":"锁羚羊：下个己方回合不能出击。"}
	if u.get("cannotAttack", false): return {"ok": false, "reason": "冰墙不能攻击。"}
	if not VerifiedRules.Langya.can_front(u): return {"ok": false, "reason": "缚魂无法进入战斗区。"}
	var gh_targets = VerifiedRules.Guishihei.attack_targets(self, p_idx, unit_index)
	if gh_targets != null and gh_targets.is_empty() and VerifiedRules.HairPower.guard_count(self, p_idx) == 0 and VerifiedRules.BattleSkill.ready(self, p_idx, unit_index).is_empty():
		return {"ok": false, "reason": "索魂：没有可攻击的式神。"}
	if VerifiedRules.Weaver.basic_blocked(self,u): return {"ok":false,"reason":"织雪进场或融合的回合不能普通出击。"}
	var deployment_free: bool = VerifiedRules.HairPower.guard_count(self,p_idx)>0 or not VerifiedRules.Butterfly.free_realm(self,p_idx).is_empty() or VerifiedRules.Moon.extra_attack(self,p_idx) or VerifiedRules.Movement.extra_attack(self,p_idx,u)
	var required_fire: int = VerifiedRules.Jorogumo.tax(self,p_idx,u) if deployment_free else VerifiedRules.TomatoFire.basic_cost(self,p_idx,u)
	if int(p.energy) < required_fire:
		return {"ok": false, "reason": "鬼火不足。"}
	if not VerifiedRules.Samurai.available(u):
		return {"ok": false, "reason": "该角色无法出击。"}
	if VerifiedRules.Stun.blocks(self,p_idx,u):
		return {"ok": false, "reason": "该角色正处于眩晕状态。"}
	if int(u.level) < 1:
		return {"ok": false, "reason": "%s 尚未激活（0 勾）。" % u.name}
	if (VerifiedRules.BattleSkill.ready(self,p_idx,unit_index).is_empty() or VerifiedRules.BattleSkill.ready(self,p_idx,unit_index).get("type") == "combat") and not VerifiedRules.Combat.has(u, "remote") and VerifiedRules.Bingyong.replacement_blocked(self, p_idx, u):
		return {"ok": false, "reason": "尘缚之阵：战斗区式神不能被其他式神替换。"}
	if not ignore_enrage and not u.get("enraged", false):
		for i in p.units.size():
			if p.units[i].get("enraged", false) and can_basic_attack(p_idx, i, true).ok:
				return {"ok": false, "reason": "激怒：请先令可出击的激怒式神出击。"}
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
	if VerifiedRules.HairPower.guard_count(self,p_idx)>0:
		if target_id!=null and str(target_id)!=str(p.units[unit_index].uid):return false
		var guarded: bool = VerifiedRules.HairPower.guard_deploy(self,p_idx,unit_index)
		if guarded: VerifiedRules.Commission.progress(self, p_idx, "deploy")
		return guarded
	if (target_id != null or basic_attack_requires_target(p_idx, unit_index)) and not basic_attack_targets(p_idx, unit_index).has(target_id): return false
	var skill := VerifiedRules.BattleSkill.ready(self,p_idx,unit_index)
	var free_realm := VerifiedRules.Butterfly.free_realm(self,p_idx)
	var free_deployment := not free_realm.is_empty()
	var fire_depth := resolution_stack.size()
	var deployment_free: bool = free_deployment or VerifiedRules.Moon.extra_attack(self,p_idx) or VerifiedRules.Movement.extra_attack(self,p_idx,p.units[unit_index])
	if free_deployment:
		free_realm.butterflyUsedTurn = turn_counter
		VerifiedRules.event(self,"butterfly-free-basic",{"player":p_idx,"uid":p.units[unit_index].uid,"realmUid":free_realm.uid})
	elif VerifiedRules.Moon.extra_attack(self,p_idx):
		VerifiedRules.Moon.pay_extra(self,p_idx)
	elif VerifiedRules.Movement.extra_attack(self, p_idx, p.units[unit_index]):
		if not VerifiedRules.Movement.pay_extra_attack(self, p_idx, unit_index): return false
	else:
		_set_fire(p_idx,int(p.energy)-VerifiedRules.TomatoFire.basic_cost(self,p_idx,p.units[unit_index]),true)
	if deployment_free: _set_fire(p_idx,int(p.energy)-VerifiedRules.Jorogumo.tax(self,p_idx,p.units[unit_index]),true)
	var inspired: bool = VerifiedRules.Combat.has(p.units[unit_index], "inspired")
	VerifiedRules.Mianqiling.consume_swift(p.units[unit_index])
	VerifiedRules.Glutton.consume_attack_traits(p.units[unit_index])
	p.units[unit_index].swift = false
	p.units[unit_index].erase("coopFirstSnowSwift")
	p.units[unit_index].erase("coinSwiftTurn")
	p.units[unit_index].erase("dragonSwiftTurn")
	p.units[unit_index].erase("shenqiSwiftTurn")
	p.units[unit_index].erase("inspired")
	if not inspired and not free_deployment: p.attackUsed = true
	p.units[unit_index].battleSkillAttackTurn = turn_counter
	_record("basic_attack", {"unit": unit_index, "target": target_id}, p_idx)
	VerifiedRules.Commission.progress(self, p_idx, "deploy")
	resolution_stack.insert(fire_depth,{"kind":"battle-skill-begin","playerIndex":p_idx,"sourceIndex":unit_index,"targetId":target_id,"skill":skill})
	_resolve_resolution_stack()
	_check_winner()
	state_changed.emit()
	return true


func release_charge(p_idx: int, unit_index: int) -> bool:
	if winner >= 0 or is_resolving or not resolution_stack.is_empty() or is_upgrade_pending(p_idx): return false
	if not VerifiedRules.Zhenjian.can_manual_release(self,p_idx,unit_index): return false
	_record("release_charge", {"unit":unit_index}, p_idx)
	if not VerifiedRules.Zhenjian.release(self,p_idx,unit_index): return false
	_resolve_resolution_stack()
	state_changed.emit()
	return true


func basic_attack_ex(p_idx: int, unit_index: int, bonus: int, uses_action: bool, target_id = null) -> void:
	# combat card assault — free attack (already paid card cost), grants attack bonus
	if unit_index < 0 or not VerifiedRules.Samurai.available(player(p_idx).units[unit_index]):
		return
	if uses_action:
		player(p_idx).attackUsed = true
	_record("assault", {"unit": unit_index, "bonus": bonus, "target": target_id}, p_idx)
	_resolve_combat(p_idx, unit_index, bonus, false, false, false, false, target_id)


func _kw(card: Dictionary, key: String) -> bool:
	var kws = card.get("keywords", [])
	if not (kws is Array):
		return false
	for k in kws:
		if str(k).to_lower() == key:
			return true
	return false


func _resolve_combat(p_idx: int, unit_index: int, bonus: int, pierce: bool, remote: bool, combo: bool, first_strike: bool, target_id = null, crit: bool = false, options: Dictionary = {}) -> void:
	var p := player(p_idx)
	var e_idx := int(options.get("combatVictim",enemy_index(p_idx)))
	var foe := player(e_idx)
	var attacker: Dictionary = p.units[unit_index]
	if attacker.get("cannotAttack", false) or not VerifiedRules.Langya.can_front(attacker): return
	if VerifiedRules.Coffin.defer_combat(self, p_idx, unit_index, bonus, pierce, remote, combo, first_strike, target_id, crit, options): return
	if VerifiedRules.Toxic.role(attacker)=="scorpion" and VerifiedRules.Toxic.active(attacker): options.toxicAttack=true
	var charm_card: Dictionary=options.get("combatCard",{})
	if charm_card.is_empty() and int(_hand_combat_context.get("playerIndex",-1))==p_idx and int(_hand_combat_context.get("sourceIndex",-1))==unit_index and not options.get("basicAttack",false): charm_card=_hand_combat_context.get("card",{})
	bonus+=int(charm_card.get("handCharmCombatAttack",0))
	if VerifiedRules.Combat.has(attacker,"direct") or VerifiedRules.GoatHeist.direct(self,p_idx,attacker): options.directAvatar=true
	if not VerifiedRules.Samurai.available(attacker):
		return
	if options.get("basicAttack",false) and VerifiedRules.RednightWalnut.replace_basic(self,p_idx,unit_index,target_id):return
	if VerifiedRules.StarBear.before_basic_attack(self,p_idx,unit_index,bonus,pierce,remote,combo,first_strike,target_id,crit,options): return
	if VerifiedRules.StarShopCards.friendly_attack(self, p_idx, unit_index, target_id, options):
		VerifiedRules.GoatHeist.after_action(self, p_idx)
		return
	if VerifiedRules.CarFrog.replace_attack(self, p_idx, unit_index, options): return
	VerifiedRules.ForestSpirit.combat_options(attacker, options)
	if target_id != null and options.get("basicAttack", false) and attacker.get("formRules", {}).get("starsFoxHowl", false): options.pursuit = true
	if options.get("basicAttack",false) and not options.get("enmaReplacement",false) and VerifiedRules.Enma.replace_basic(self,p_idx,unit_index,target_id): return
	options=VerifiedRules.Samurai.prepare_combat(self,p_idx,unit_index,options,target_id)
	options=VerifiedRules.Headless.prepare_combat(self,p_idx,unit_index,options)
	options=VerifiedRules.WindRaccoon.prepare_combat(self,p_idx,unit_index,options)
	VerifiedRules.Vine.before_attack(self,p_idx,unit_index,options)
	if options.get("basicAttack",false): VerifiedRules.Mountain.before_basic_attack(self,p_idx,unit_index)
	if VerifiedRules.TreeSakura.floating(attacker):
		options.sakuraCombo = true
		if target_id == null:
			var default_front := front_unit(e_idx)
			target_id = str(default_front.uid) if not default_front.is_empty() else "avatar-%d" % e_idx
	if target_id != null and VerifiedRules.Combat.has(attacker, "pursuit"): options.pursuit = true
	var enc := VerifiedRules.TomatoFire.attack_encourage(self, p_idx, options)
	options = VerifiedRules.TomatoFire.merge_traits(options, enc)
	remote = remote or options.get("remote", false)
	pierce = pierce or options.get("pierce", false)
	combo = combo or options.get("combo", false)
	if options.get("basicAttack", false): VerifiedRules.TomatoFire.begin_attack(self, p_idx, unit_index, options)
	remote = remote or VerifiedRules.Combat.has(attacker, "remote")
	pierce = pierce or VerifiedRules.Combat.has(attacker, "pierce")
	combo = combo or VerifiedRules.Combat.has(attacker, "combo") or VerifiedRules.SilkNinja.attack_combo(attacker)
	first_strike = first_strike or VerifiedRules.Combat.has(attacker, "first-strike") or VerifiedRules.Crocodile.attack_first(attacker)
	first_strike = first_strike or VerifiedRules.Night.first_strike(self, attacker)
	var moves_to_front: bool = not remote and not VerifiedRules.CatSamurai.bodyless(self, attacker) and not attacker.has("waveIbarakiGhost")
	if moves_to_front and VerifiedRules.Bingyong.replacement_blocked(self, p_idx, attacker): return
	first_strike = VerifiedRules.TimeRewind.before_attack(self, attacker) or first_strike
	if options.get("crabImmuneAll", false): attacker.crabCombatImmune = true
	if options.get("unyielding", false): attacker.combatUnyielding = true
	if charm_card.get("chenCombatResolute", false): attacker.chenCombatResolute = true
	var coop_stats := VerifiedRules.CoopFirst.combat_stats(self, p_idx, unit_index, options)
	bonus += int(coop_stats.attack)
	if int(coop_stats.armor) > 0: _grant_unit_armor(attacker, int(coop_stats.armor))
	# enter front（远程不改前线）
	VerifiedRules.Rebirth.combat_started(self,p_idx,unit_index,options)
	VerifiedRules.OniAsura.combat_started(self,p_idx,unit_index,options)
	var movement_depth := resolution_stack.size()
	VerifiedRules.Langya.passive_trigger(self, p_idx, unit_index)
	if winner >= 0: return
	var was_front := int(attacker.front) == 1
	var entered_from_reserve := moves_to_front and not was_front
	var movement_old: Array = p.units.map(func(u): return int(u.front))
	if moves_to_front:
		if not attacker.get("tomatoFireSummon", false): VerifiedRules.TomatoFire.clear_summons(self, p_idx)
		VerifiedRules.Xuenv.clear_wall(self, p_idx)
		if not attacker.get("paintSummon",false): VerifiedRules.Paint.clear_summons(self,p_idx)
		if not attacker.get("pineSummon",false): VerifiedRules.Pine.clear_summons(self,p_idx)
		if not attacker.get("enmaGhost",false): VerifiedRules.Enma.clear_summons(self,p_idx)
		if not attacker.get("weaverSummon",false): VerifiedRules.Weaver.clear_summons(self,p_idx)
		if not attacker.get("vineSummon",false): VerifiedRules.Vine.clear_summons(self,p_idx)
		if not attacker.get("windRaccoonClone",false): VerifiedRules.WindRaccoon.clear_summons(self,p_idx)
		if not attacker.get("boxSummon",false): VerifiedRules.BoxMaiden.clear_summons(self,p_idx)
		if not attacker.get("houseSummon",false): VerifiedRules.House.clear_summons(self,p_idx)
		if not attacker.get("dollSummon",false): VerifiedRules.Doll.clear_summons(self,p_idx)
		if not attacker.get("whaleGuardian",false): VerifiedRules.Whale.clear_summons(self,p_idx)
		if not attacker.get("jorogumoSwarm",false): VerifiedRules.Jorogumo.clear_summons(self,p_idx)
		VerifiedRules.Langya.clear_front_souls(self, p_idx, attacker)
		attacker.front = 1
		for u in p.units:
			if u != attacker:
				u.front = 0
		VerifiedRules.Bamboo.remove_departed(self)
		VerifiedRules.SunSmoke.remove_departed(self)
		VerifiedRules.GiftEnergy.remove_departed(self)
		VerifiedRules.Bone.remove_departed(self, p_idx)
		VerifiedRules.NativeSummons.remove_departed(self, p_idx)
		VerifiedRules.TwinSight.remove_departed(self, p_idx)
		if entered_from_reserve:
			_log("%s 从准备区进入前线。" % attacker.name, TONE_TURN)
			_fire_hooks(p_idx, unit_index, "unit-entered-front", {})
			_run_form_hooks(p_idx, unit_index, "unit-entered-front", {})
	if moves_to_front:
		for i in p.units.size(): VerifiedRules.Movement.moved(self, p_idx, i, int(movement_old[i]))
	var entry := {"kind": "combat-entered", "playerIndex": p_idx, "sourceIndex": unit_index, "bonus": bonus, "pierce": pierce, "remote": remote, "combo": combo, "firstStrike": first_strike, "targetId": target_id, "crit": crit, "options": options.duplicate(true), "fromReserve": entered_from_reserve, "flashSerial": int(attacker.get("flashZeroSerial", 0)), "encourage": enc}
	if resolution_stack.size() > movement_depth:
		entry.kind = "movement-combat-entry"
		resolution_stack.insert(movement_depth, entry)
		return
	# The entering response finishes before attack power is read. Resuming a
	# serialized continuation does not move the attacker or consume inspire twice.
	if entered_from_reserve and VerifiedRules.automatic_response(self, e_idx, "enemy-entered-front", attacker.uid, entry): return
	_resolve_combat_entered(entry)


func _resolve_combat_entered(frame: Dictionary) -> void:
	if VerifiedRules.MusicFire.before_attack(self,frame):return
	if VerifiedRules.FearWing.before_attack(self,frame):return
	if not frame.get("lilyAttackOffered", false):
		frame.lilyAttackOffered = true
		var depth := resolution_stack.size()
		var attacker: Dictionary = player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
		if winner < 0 and VerifiedRules.Samurai.combat_available(attacker, frame.options) and VerifiedRules.SpiderLily.before_attack(self, int(frame.playerIndex)):
			resolution_stack.insert(depth, {"kind": "lily-attack-ready", "combat": frame.duplicate(true), "playerIndex": int(frame.playerIndex)})
			return
	if VerifiedRules.ApeSleeve.attack_started(self,frame): return
	if VerifiedRules.Mask.attack_started(self, frame): return
	if VerifiedRules.Headless.attack_started(self,frame): return
	if VerifiedRules.Futakuchi.attack_started(self,frame):return
	if VerifiedRules.LunarTrick.before_attack(self, frame): return
	var breath_depth := resolution_stack.size()
	VerifiedRules.DragonFlow.attack_started(self, frame)
	VerifiedRules.ZenMisfortune.attack_started(self, frame)
	if resolution_stack.size() > breath_depth:
		resolution_stack.insert(breath_depth, frame)
		return
	VerifiedRules.FortunateDuo.before_attack(self, frame)
	if VerifiedRules.YanmieTrio.before_attack(self, frame): return
	if not frame.get("abyssAttackStarted", false):
		frame.abyssAttackStarted = true
		var depth := resolution_stack.size()
		VerifiedRules.DragonAbyss.Serving.attack_started(self, int(frame.playerIndex), int(frame.sourceIndex))
		VerifiedRules.DragonAbyss.Jade.attack_started(self, int(frame.playerIndex), int(frame.sourceIndex))
		if resolution_stack.size() > depth:
			resolution_stack.insert(depth, frame)
			return
	var p_idx := int(frame.playerIndex)
	var unit_index := int(frame.sourceIndex)
	var e_idx := int(frame.options.get("combatVictim",1-p_idx))
	var foe := player(e_idx)
	var attacker: Dictionary = player(p_idx).units[unit_index]
	if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0:
		VerifiedRules.TomatoFire.finish_attack(self,p_idx,unit_index)
		VerifiedRules.OniAsura.combat_finished(self,p_idx,unit_index,frame.options)
		attacker.erase("combatUnyielding")
		return
	var bonus := int(frame.bonus)
	var pierce := bool(frame.pierce)
	var remote := bool(frame.remote)
	var combo := bool(frame.combo)
	var first_strike := bool(frame.firstStrike)
	var target_id = frame.targetId
	var crit := bool(frame.crit)
	var options: Dictionary = frame.options
	var entered_from_reserve := bool(frame.fromReserve)
	var enc: Dictionary = frame.encourage
	if int(attacker.get("flashZeroSerial", 0)) != int(frame.flashSerial):
		bonus = 0
		enc.attack = 0
	VerifiedRules.EssenceFeast.attack_started(self,p_idx,unit_index)
	VerifiedRules.Commission.progress(self, p_idx, "attack")
	VerifiedRules.Jorogumo.before_attack(self,p_idx,unit_index)
	if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner>=0: return
	VerifiedRules.OwlInsect.attack_started(self,p_idx,unit_index)
	VerifiedRules.CoopMiddle.attack_started(self, p_idx, unit_index)
	VerifiedRules.CoopLate.attack_started(self, p_idx, unit_index)
	VerifiedRules.Hanafuda.attack_started(self, p_idx, unit_index)
	var river_depth := resolution_stack.size()
	VerifiedRules.FoxSuzuka.before_attack(self, p_idx, unit_index)
	if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0: return
	VerifiedRules.SnowCrane.before_attack(self, p_idx, unit_index)
	bonus+=VerifiedRules.BoxMaiden.combat_bonus(self,p_idx,unit_index)
	VerifiedRules.Fortune.before_attack(self, p_idx, unit_index)
	VerifiedRules.Movement.before_attack(self, p_idx, unit_index)
	VerifiedRules.Pine.before_attack(self,p_idx,unit_index)
	if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0: return
	VerifiedRules.OniAsura.before_attack(self,p_idx,unit_index)
	if winner>=0 or not VerifiedRules.Samurai.combat_available(attacker,frame.options): return
	var light_zero := VerifiedRules.Light.before_attack(self, p_idx, unit_index)
	light_zero = light_zero or int(attacker.get("duoZeroTurn", -1)) == turn_counter
	frame.bonus = bonus + VerifiedRules.Wave7Reworks.battle_bonus(self, p_idx, unit_index)
	if options.get("hfWindFire", false): frame.bonus += VerifiedRules.Hanafuda.enter_count(self, attacker)
	frame.options = options
	VerifiedRules.River.prepare_attack(self, frame)
	frame.lightZero = light_zero
	frame.kind = "river-combat-ready"
	if resolution_stack.slice(river_depth).any(func(f): return f.get("kind") in ["river-fortune-reward","form-trigger"] or str(f.get("kind","")).begins_with("asura-")):
		resolution_stack.insert(river_depth, frame)
		return
	_resolve_combat_ready(frame)


func _resolve_combat_ready(frame: Dictionary) -> void:
	var p_idx := int(frame.playerIndex)
	var unit_index := int(frame.sourceIndex)
	var e_idx := int(frame.options.get("combatVictim",1-p_idx))
	var foe := player(e_idx)
	var attacker: Dictionary = player(p_idx).units[unit_index]
	if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0: return
	if VerifiedRules.RednightWalnut.before_attack(self,frame):return
	if VerifiedRules.SilkNinja.before_response(self,frame): return
	if VerifiedRules.MirrorSong.before_attack(self,frame):return
	if VerifiedRules.Yujiazhu.prayer_started(self,frame):return
	if VerifiedRules.DuskCycle.before_ready(self, frame): return
	if VerifiedRules.ShenqiHuang.before_attack(self, frame): return
	if winner >= 0 or not VerifiedRules.Samurai.combat_available(attacker, frame.options): return
	var bonus := int(frame.bonus)
	var pierce := bool(frame.pierce)
	var remote := bool(frame.remote)
	var combo := bool(frame.combo)
	var first_strike := bool(frame.firstStrike)
	var target_id = frame.targetId
	var crit := bool(frame.crit)
	var options: Dictionary = frame.options
	var entered_from_reserve := bool(frame.fromReserve)
	var enc: Dictionary = frame.encourage
	var light_zero := bool(frame.lightZero)
	if attacker.id == VerifiedRules.DuskCycle.PEACOCK and attacker.awakened:
		pierce = true
		first_strike = true
	if int(enc.get("battlePower", 0)) != 0: VerifiedRules.HairPower.give(self, p_idx, unit_index, int(enc.battlePower))
	if int(enc.get("shield", 0)) > 0:
		_grant_unit_armor(attacker, int(enc.shield))
	elif int(enc.get("shield",0))<0:
		VerifiedRules.ArmorBreak.give(self,p_idx,unit_index,p_idx,unit_index,-int(enc.shield),false)
	var base_power := VerifiedRules.Combat.power(self, p_idx, attacker, bonus + int(enc.get("attack", 0)))
	var power := base_power
	options.critical = crit or VerifiedRules.Combat.has(attacker, "crit")
	options.critical = options.critical or attacker.get("formRules", {}).get("windGuardCrit", false)
	if attacker.get("formRules", {}).get("towerAttackLethal", false): options.lethal = true
	if light_zero: power = 0
	options.lightZeroAttack = light_zero
	if VerifiedRules.TomatoFire.burn_attack(self, frame, power, options): return
	if VerifiedRules.TreeSakura.special_attack(self, frame, power, options): return
	var gh_targets = VerifiedRules.Guishihei.attack_targets(self, p_idx, unit_index)
	if gh_targets != null and e_idx == 1-p_idx:
		if gh_targets.is_empty(): return
		if target_id == null: target_id = gh_targets[0]
		if not gh_targets.has(target_id): return
		options.pursuit = true
		options.directAvatar = false
	var star_forced=VerifiedRules.StarBear.basic_target(self,p_idx) if options.get("basicAttack",false) else null
	if star_forced!=null:
		target_id=star_forced; options.directAvatar=false; options.reserveTarget=false; options.pursuit=true
	if options.get("sakuraCombo", false):
		if str(target_id) == "avatar-%d" % e_idx: options.directAvatar = true
		else:
			options.pursuit = true
			var target_unit := _unit_by_uid(foe.units, str(target_id))
			combo = not target_unit.is_empty() and VerifiedRules.TreeSakura.shikigami(target_unit)
	var fi: int = front_index(e_idx)
	if options.get("directAvatar", false): fi = -1
	if options.get("reserveTarget", false):
		fi = _unit_index_by_uid(e_idx, target_id)
		if fi < 0 or int(foe.units[fi].hp) <= 0 or int(foe.units[fi].front) != 0: return
	if options.get("pursuit", false):
		if str(target_id) == "avatar-%d" % e_idx:
			if fi >= 0: return
		else:
			fi = _unit_index_by_uid(e_idx, target_id)
			if fi < 0 or int(foe.units[fi].hp) <= 0: return
	if options.has("riverRedirect"):
		fi = -1 if str(options.riverRedirect) == "avatar-%d" % e_idx else _unit_index_by_uid(e_idx, options.riverRedirect)
	elif options.get("movementRedirect", false): fi = VerifiedRules.Movement.redirect_target(self, p_idx, fi)
	if star_forced!=null: fi=_unit_index_by_uid(e_idx,star_forced)
	VerifiedRules.Yujiazhu.prepare_attack(self,frame,fi)
	fi = VerifiedRules.Wave7Reworks.redirect(self, e_idx, fi)
	if fi >= 0: VerifiedRules.Movement.deer_combat(self, e_idx, fi)
	if fi >= 0 and int(foe.units[fi].hp) <= 0: fi = front_index(e_idx)
	if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0: return
	if VerifiedRules.Susanoo.prepare_attack(self,p_idx,unit_index,fi,options):
		power=VerifiedRules.Combat.power(self,p_idx,attacker,bonus+int(enc.get("attack",0)))
		if light_zero: power=0
	if fi >= 0:
		VerifiedRules.DragonAbyss.Aki.prepare_combat(self, p_idx, unit_index, e_idx, fi, options)
		var fox_bonus := VerifiedRules.FoxFlame.prepare_combat(self, p_idx, unit_index, e_idx, fi)
		bonus += fox_bonus
		if not light_zero: power += fox_bonus
		pierce = pierce or options.get("akibaPierce", false)
	pierce=pierce or options.get("pierce",false) or VerifiedRules.Izanami.protected(self, p_idx, attacker)
	pierce = pierce or int(attacker.get("abyssPierceTurn", -1)) == turn_counter
	VerifiedRules.Poison.transfer_before_combat(self, p_idx, unit_index, e_idx, fi, options)
	VerifiedRules.CoopLate.prepare_combat(self, p_idx, unit_index, e_idx, fi, options)
	options = VerifiedRules.ArmorBreak.prepare_combat(self, e_idx, fi, options)
	if fi >= 0 and attacker.get("formRules", {}).get("peacockSafe", false) and int(foe.units[fi].armorBreak) > 0: options.immuneCombat = true
	VerifiedRules.YanmieTrio.combat_ready(self, p_idx, unit_index, options)
	VerifiedRules.FactionArt.combat_ready(self, p_idx, unit_index, e_idx, fi, options)
	combo = combo or VerifiedRules.DragonFlow.attack_combo(self, frame, e_idx, fi)
	if options.get("lineageFrontCombo", false) and fi >= 0:
		var defender: Dictionary = foe.units[fi]
		combo = combo or (int(defender.front) == 1 and VerifiedRules.OwlInsect.shikigami(defender))
	VerifiedRules.LineageScroll.made_attack(self, p_idx, unit_index)
	var ambush_power := VerifiedRules.StarShopCards.ambush(self, p_idx, unit_index, fi, options)
	if not light_zero: power += ambush_power
	bonus += ambush_power
	pierce = pierce or options.get("pierce", false)
	if fi < 0:
		if VerifiedRules.SunSmoke.avatar_response(self, frame, power, options): return
		VerifiedRules.Light.avatar_attacked(self, e_idx, p_idx)
		options.whaleAttackStarted=true
		VerifiedRules.HairPower.started(self,p_idx,unit_index,{},options)
		VerifiedRules.event(self, "combat-hit", {"player": p_idx, "uid": attacker.uid, "target": ""})
		_log("%s 突破空缺前线。" % attacker.name, TONE_SUCCESS)
		var hits := (2 if combo or attacker.get("formRules", {}).get("extraFirstHit", false) else 1) + (1 if VerifiedRules.SnowCrane.extra(attacker, int(foe.get("avatarFrozen", 0)) > 0) else 0)
		for strike in hits:
			if winner >= 0 or not VerifiedRules.Samurai.combat_available(attacker,frame.options): break
			VerifiedRules.CoopMiddle.combat_snapshot(self, p_idx, unit_index, e_idx, -1, options)
			var hit := VerifiedRules.Combat.strike(self, p_idx, unit_index, e_idx, -1, power, options)
			if hits > 1: _record_combat_strike(p_idx, unit_index, e_idx, -1, hit, strike, options.get("combatCard", {}))
			if int(hit.damage) > 0 and int(options.get("countdownOnAvatarDamage", 0)) > 0:
				VerifiedRules.reduce_countdown(self, p_idx, unit_index, int(options.countdownOnAvatarDamage), p_idx if options.has("combatCard") else -1)
		_finish_combat(p_idx, unit_index, {}, entered_from_reserve, options, 0)
		return
	VerifiedRules.EssenceFeast.before_attacked(self,e_idx,fi)
	VerifiedRules.Fortune.before_attacked(self, e_idx, fi)
	var continuation := {"kind": "combat-hit", "playerIndex": p_idx, "sourceIndex": unit_index, "defenderIndex": fi, "power": power, "attackSnapshot": int(attacker.attack), "attackBaseBonus": bonus + int(enc.get("attack",0)), "powerMultiplier": 1, "remote": remote, "pierce": pierce, "combo": combo, "firstStrike": first_strike, "fromReserve": entered_from_reserve, "options": options.duplicate(true)}
	continuation.defenderBonus=VerifiedRules.BoxMaiden.combat_bonus(self,e_idx,fi)
	continuation.defenderRiverLifeSteal = VerifiedRules.River.summer(self, e_idx, fi)
	continuation.combatId = next_resolution_id
	next_resolution_id += 1
	var defense_depth := resolution_stack.size()
	VerifiedRules.Sparrow.before_attacked(self,continuation)
	if resolution_stack.size()>defense_depth:
		continuation.kind="night-defender-ready"
		resolution_stack.insert(defense_depth,continuation)
		return
	_offer_attack_responses(continuation)


func _offer_attack_responses(frame: Dictionary) -> void:
	frame.kind="combat-hit"
	var owner := int(frame.playerIndex)
	var victim := int(frame.options.get("combatVictim",1-owner))
	var idx := int(frame.defenderIndex)
	if winner>=0 or not VerifiedRules.Samurai.combat_available(player(owner).units[int(frame.sourceIndex)],frame.options) or int(player(victim).units[idx].hp)<=0:
		_resolve_combat_hit(frame)
		return
	if VerifiedRules.RabbitTide.before_combat(self,frame):return
	if VerifiedRules.PeachGrove.combat_cancel(self, frame): return
	VerifiedRules.HairPower.before_hit(self,frame)
	if VerifiedRules.RednightWalnut.before_hit(self,frame,idx):return
	if VerifiedRules.Zhenjian.defend_started(self,frame):return
	if VerifiedRules.ChargedPair.defend_started(self,frame):return
	VerifiedRules.SeaButterfly.before_responses(self,frame)
	if VerifiedRules.Cotton.before_attacked(self,frame): return
	if VerifiedRules.Mask.defend_started(self,frame): return
	if VerifiedRules.automatic_response(self,victim,"unit-attacked",player(victim).units[idx].uid,frame): return
	_resolve_combat_hit(frame)


func _finish_combat(owner: int, src: int, defender: Dictionary, from_reserve: bool, options: Dictionary, kills: int) -> void:
	kills += VerifiedRules.Grudge.finish(self, owner, src, defender, options)
	VerifiedRules.DragonAbyss.Aki.finished(self, owner, src, options)
	VerifiedRules.DragonAbyss.Jade.finished(self, owner, src, options)
	VerifiedRules.MusicFire.combat_finished(self,owner,src,defender,options)
	var context := {"defender": defender if not defender.is_empty() else null, "from_reserve": from_reserve, "killed": kills > 0}
	_fire_hooks(owner, src, "combat-resolved", context)
	_run_form_hooks(owner, src, "combat-resolved", context)
	VerifiedRules.Rebirth.combat_finished(self,owner,src,options)
	VerifiedRules.Samurai.combat_finished(self,owner,src,options)
	VerifiedRules.OniAsura.combat_finished(self,owner,src,options)
	VerifiedRules.Yaodao.combat_finished(self, owner, src, options, kills)
	VerifiedRules.DogDemon.combat_finished(self, owner, src, options, kills)
	VerifiedRules.Bailang.after_attack(self, owner, src)
	VerifiedRules.SnowCrane.after_attack(self, owner, src)
	VerifiedRules.Light.after_attack(self, owner, src)
	VerifiedRules.Fortune.combat_finished(self, owner, src, options)
	VerifiedRules.Movement.combat_finished(self, owner, src, options)
	VerifiedRules.Whale.combat_finished(self,owner,src,options)
	VerifiedRules.FoxSuzuka.combat_finished(self, owner, src, options)
	VerifiedRules.Xuenv.after_attack(self, owner, src)
	VerifiedRules.TomatoFire.finish_attack(self, owner, src)
	VerifiedRules.Wind.after_attack(self, owner, src)
	VerifiedRules.Night.after_attack(self, owner, src, options)
	VerifiedRules.Mask.after_attack(self, owner, src, options)
	VerifiedRules.TreeSakura.after_attack(self, owner, src)
	VerifiedRules.Headless.combat_finished(self,owner,src,defender)
	VerifiedRules.Enma.combat_finished(self,owner,src,options,kills)
	VerifiedRules.Onikiri.combat_finished(self,owner,src,options,kills)
	VerifiedRules.WindRaccoon.combat_finished(self,owner,src,options)
	VerifiedRules.Goldfish.combat_finished(self,owner,src,options)
	VerifiedRules.RednightWalnut.combat_finished(self,owner,src,options)
	VerifiedRules.ApeSleeve.combat_finished(self,owner,src,options)
	VerifiedRules.MirrorSong.combat_finished(self,owner,src,options)
	VerifiedRules.Zhenjian.combat_finished(self,owner,src,options,defender)
	VerifiedRules.SerpentGhost.combat_finished(self,owner,src,options)
	VerifiedRules.FearWing.combat_finished(self,owner,src,options,kills)
	VerifiedRules.WisdomLamp.combat_finished(self,owner,src,options)
	VerifiedRules.Langya.combat_finished(self, owner, src)
	VerifiedRules.Bone.combat_finished(self, owner, src, defender, options)
	VerifiedRules.Wave7Reworks.finish(self, owner, src, options, kills)
	VerifiedRules.Hanafuda.finish_combat(self, owner, src, options)
	VerifiedRules.PaperDance.refresh(self, owner)
	VerifiedRules.PaperDance.refresh(self, 1-owner)
	player(owner).units[src].erase("chenCombatResolute")
	VerifiedRules.HairPower.finished(self,owner,src,defender,options,kills)
	VerifiedRules.DuskCycle.combat_finished(self, owner, src, options, kills)
	VerifiedRules.PeachGrove.combat_finished(self, owner, src, options, kills)
	VerifiedRules.YanmieTrio.combat_finished(self, owner, src, defender, options)
	VerifiedRules.EssenceFeast.combat_finished(self,owner,src)
	VerifiedRules.Susanoo.finish_duel(self,options)
	player(owner).units[src].erase("enraged")
	player(owner).units[src].erase("combatUnyielding")
	if options.get("crabImmuneAll", false): player(owner).units[src].erase("crabCombatImmune")
	VerifiedRules.CoopFirst.combat_finished(self, owner, src, defender, options, kills)
	VerifiedRules.CoopMiddle.combat_finished(self, owner, src, options)
	VerifiedRules.event(self, "combat-complete", {"player": owner, "uid": player(owner).units[src].uid, "kills": kills})
	VerifiedRules.GoatHeist.after_combat(self, owner, options)


func _record_combat_strike(owner: int, src: int, victim: int, idx: int, result: Dictionary, step: int, played_card: Dictionary = {}) -> void:
	var source: Dictionary = player(owner).units[src]
	var card: Dictionary = played_card if not played_card.is_empty() else {"unitId": source.id, "type": "combat"}
	var transferred := result.has("transferredDealt")
	var amount := int(result.get("transferredDealt", result.damage))
	VerifiedRules.event(self, "combat-damage-resolved", {"player": owner, "uid": source.uid, "target": result.get("redirectedTarget", "" if idx < 0 or transferred else player(victim).units[idx].uid), "victimPlayer": int(result.get("redirectedPlayer",victim)), "amount": amount, "blocked": amount == 0, "transferred": transferred, "step": step, "card": card})


func _resolve_combat_hit(frame: Dictionary) -> void:
	if frame.get("movementCancelled",false):
		VerifiedRules.Susanoo.finish_duel(self,frame.options)
		VerifiedRules.OniAsura.combat_finished(self,int(frame.playerIndex),int(frame.sourceIndex),frame.options)
		return
	var owner := int(frame.playerIndex)
	var victim := int(frame.options.get("combatVictim",1-owner))
	var src := int(frame.sourceIndex)
	var idx := int(frame.defenderIndex)
	var attacker: Dictionary = player(owner).units[src]
	var defender: Dictionary = player(victim).units[idx]
	var options: Dictionary = frame.options
	var from_reserve := bool(frame.fromReserve)
	if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or int(defender.hp) <= 0:
		_finish_combat(owner, src, defender, from_reserve, options, 0)
		return
	if not frame.get("abyssJadeClash", false):
		frame.abyssJadeClash = true
		var depth := resolution_stack.size()
		VerifiedRules.DragonAbyss.Jade.clash(self, owner, src, victim, idx)
		if resolution_stack.size() > depth:
			resolution_stack.insert(depth, frame)
			return
	var remote := bool(frame.remote)
	var cotton_depth := resolution_stack.size()
	VerifiedRules.Cotton.before_hit(self,owner,victim,idx,options)
	VerifiedRules.Wave7Reworks.before_hit(self, owner, src, victim, idx, options)
	if resolution_stack.size() > cotton_depth:
		resolution_stack.insert(cotton_depth, {"kind": "cotton-hit-ready", "playerIndex": owner, "combat": frame.duplicate(true)})
		return
	VerifiedRules.SilkNinja.prepare_combat(self,frame)
	VerifiedRules.MirrorSong.combat_prepare(self,frame)
	VerifiedRules.Mianqiling.combat_prepare(self,frame)
	VerifiedRules.Susanoo.begin_duel(self,frame)
	VerifiedRules.Glutton.prepare_combat(self,owner,src,victim,idx,options)
	VerifiedRules.Guishihei.prepare_hit(self, owner, src, defender, frame)
	var a_extra: bool = frame.combo or options.get("comboAgainstUnit", false) or attacker.get("formRules", {}).get("extraFirstHit", false)
	var snow_extra := 1 if VerifiedRules.SnowCrane.extra(attacker, int(defender.frozen) > 0) else 0
	var counter_allowed := not remote
	options.immuneCombat=bool(options.get("immuneCombat",false)) or VerifiedRules.PipeFox.combat_immunity(self,owner,src,defender,true)
	options.immuneCombat = options.immuneCombat or VerifiedRules.Izanami.protected(self, owner, attacker)
	frame.defenderImmuneCombat=bool(frame.get("defenderImmuneCombat",false)) or VerifiedRules.PipeFox.combat_immunity(self,victim,idx,attacker,false)
	# Capture conditional immunity before either combatant loses statuses on death.
	options.immuneCombat = options.get("immuneCombat", false) or VerifiedRules.FoxSuzuka.immune(self, owner, src, victim, idx) or VerifiedRules.SnowCrane.immune(attacker, defender, true) or VerifiedRules.Yijin.immune(self, owner, attacker)
	frame.defenderImmuneCombat = frame.get("defenderImmuneCombat", false) or VerifiedRules.FoxSuzuka.immune(self, victim, idx, owner, src) or VerifiedRules.SnowCrane.immune(defender, attacker, false) or VerifiedRules.Yijin.immune(self, victim, defender)
	var d_extra: bool = counter_allowed and (VerifiedRules.Combat.has(defender, "combo") or defender.get("formRules", {}).get("extraFirstHit", false))
	var a_first := bool(frame.firstStrike)
	var d_first := VerifiedRules.Combat.has(defender, "first-strike")
	var kills := int(frame.get("kills",0))
	options.whaleAttackStarted=true
	VerifiedRules.HairPower.started(self,owner,src,defender,options)
	VerifiedRules.event(self, "combat-hit", {"player": owner, "uid": attacker.uid, "target": defender.uid})
	if int(attacker.get("grudgeVowTurn", -1)) == turn_counter or int(defender.get("grudgeVowTurn", -1)) == turn_counter:
		options.grudgeDuelStarted = true
	_log("%s 向 %s 发起%s出击。" % [attacker.name, defender.name, "远程" if remote else ""], TONE_TURN)
	var attack_extras := (1 if a_extra else 0) + snow_extra
	var max_extras := maxi(attack_extras, 1 if d_extra else 0)
	var shell_depth := _shell_reaction_stack.size()
	for step in range(int(frame.get("nextStep",1-max_extras)),2):
		if winner >= 0 or not VerifiedRules.Samurai.combat_available(attacker,frame.options): break
		# A skipped extra-hit phase must not delay ordinary impact feedback.
		var visual_step: int = step - (1 - max_extras)
		var power := maxi(0, int(frame.power) + (int(attacker.attack) - int(frame.get("attackSnapshot", attacker.attack))) * int(frame.get("powerMultiplier", 1)))
		if VerifiedRules.TreeSakura.health_damage(attacker): power = int(attacker.hp)
		if not VerifiedRules.TreeSakura.health_damage(attacker): power = maxi(0,power-int(options.get("seaAttackPenalty",0)))
		if options.get("lightZeroAttack", false): power = 0
		if int(defender.hp) <= 0:
			if options.get("sakuraCombo",false) and VerifiedRules.TreeSakura.delay_dead(attacker):
				var dead_hit := VerifiedRules.Combat.strike(self,owner,src,victim,idx,power,options)
				_record_combat_strike(owner,src,victim,idx,dead_hit,visual_step,options.get("combatCard",{}))
				continue
			if step == 1 and frame.pierce:
				var face_hit := VerifiedRules.Combat.strike(self, owner, src, victim, -1, power, options)
				_record_combat_strike(owner, src, victim, -1, face_hit, visual_step, options.get("combatCard", {}))
			break
		var exchange_depth := resolution_stack.size()
		VerifiedRules.MonkCleaner.begin_exchange(self)
		var a_hits: bool = step >= 1 - attack_extras
		var d_hits: bool = counter_allowed and (step == 1 or (step == 0 and d_extra))
		var counter_power := VerifiedRules.Combat.power(self, victim, defender, int(frame.get("defenderBonus", 0)))
		if not VerifiedRules.TreeSakura.health_damage(defender): counter_power=maxi(0,counter_power-int(options.get("seaDefenderPenalty",0)))
		var d_options := {"convertCombatToArmorBreak": options.get("convertCombatToArmorBreak", false), "izanamiCounterstrike": true}
		if options.has("grudgeReflectUid"): d_options.grudgeReflectUid = options.grudgeReflectUid
		d_options.hairPowerSnapshot=int(options.get("hairDefenderPowerSnapshot",0))
		d_options.silkCombatId=options.get("silkCombatId",-1)
		d_options.sourceWasPoisoned=defender.get("toxicPoisoned",false)
		d_options.toxicAttack=VerifiedRules.Toxic.traits(self,victim,idx,true).toxic
		d_options.critical = VerifiedRules.Combat.has(defender, "crit") or frame.get("starsGoatCounterCrit", false)
		if frame.get("defenderRiverLifeSteal", false): d_options.lifeSteal = true
		d_options.merge(VerifiedRules.Tide.combat_traits(self, victim, idx))
		d_options.merge(VerifiedRules.Xuenv.combat_traits(self, victim, idx))
		d_options.merge(VerifiedRules.ArmorBlood.traits(self, victim, idx))
		options.victimKnockoutExtra = VerifiedRules.Panguan.extra_knockout(self, victim)
		d_options.victimKnockoutExtra = VerifiedRules.Panguan.extra_knockout(self, owner)
		options.bgSnowStun=VerifiedRules.BlueGreen.snow_stun(self,owner,src)
		d_options.bgSnowStun=VerifiedRules.BlueGreen.snow_stun(self,victim,idx)
		VerifiedRules.RedPurple.snapshot_exchange(self,owner,src,victim,idx,options,d_options)
		VerifiedRules.Mianqiling.snapshot_exchange(self,owner,src,victim,idx,options,d_options)
		fox_flame_snapshot = VerifiedRules.FoxFlame.snapshot(attacker, defender)
		# First strike is a timing priority, not a posthumous cancellation.
		var a_priority: bool = a_first and not d_first and (not d_hits or a_hits)
		var d_priority: bool = d_first and not a_first and (not a_hits or d_hits)
		if d_hits and d_priority:
			frame.movementVisualStep = visual_step
			VerifiedRules.Movement.counterstrike(self, frame, counter_power, d_options)
			if not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0:
				fox_flame_snapshot.clear()
				break
		if a_hits:
			VerifiedRules.CoopMiddle.combat_snapshot(self, owner, src, victim, idx, options)
			var hit := VerifiedRules.Combat.strike(self, owner, src, victim, idx, power, options, bool(frame.pierce), bool(frame.get("defenderImmuneCombat", false)))
			_record_combat_strike(owner, src, victim, idx, hit, visual_step, options.get("combatCard", {}))
			if hit.knocked: kills += 1
		# Ordinary simultaneous damage retains the defender's snapshotted hit,
		# even when its body/form was removed by the attacker's damage.
		if d_hits and not d_priority and winner < 0 and VerifiedRules.Samurai.combat_available(attacker,frame.options) and (not a_priority or int(defender.hp) > 0):
			if VerifiedRules.Movement.zero_power(self, defender): counter_power = 0
			frame.movementVisualStep = visual_step
			VerifiedRules.Movement.counterstrike(self, frame, counter_power, d_options)
		fox_flame_snapshot.clear()
		VerifiedRules.MonkCleaner.flush_exchange(self)
		if resolution_stack.slice(exchange_depth).any(func(f):return str(f.get("kind","")).begins_with("oni-") or str(f.get("kind","")).begins_with("asura-") or str(f.get("kind","")).begins_with("rebirth-") or str(f.get("kind","")).begins_with("doll-") or str(f.get("kind","")).begins_with("sg-")):
			_resolve_inline_frames(exchange_depth)
			if not pending_choice.is_empty() or not response_window.is_empty():
				frame.nextStep=step+1; frame.kills=kills
				resolution_stack.insert(exchange_depth,{"kind":"oni-combat-resume","combatFrame":frame.duplicate(true)})
				return
	while _shell_reaction_stack.size() > shell_depth: VerifiedRules.MonkCleaner.flush_exchange(self)
	_finish_combat(owner, src, defender, from_reserve, options, kills)


func _fire_hooks(p_idx: int, src: int, event: String, ctx: Dictionary) -> void:
	if src>=0 and event=="unit-entered-front": VerifiedRules.SeaButterfly.entered(self,p_idx,src)
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
		_run_passive_effect(p_idx, unit_index, str(hook.get("effect", "")), hook.get("params", {}), ctx, false)


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
			_damage_unit(e_idx, fi, amount, p_idx, unit_index)
		elif "空场" in form_ability or "核心" in form_ability:
			_damage_avatar(e_idx, amount, p_idx, unit_index)


func _run_passive_effect(p_idx: int, unit_index: int, effect: String, params, ctx: Dictionary, base_ability: bool = true) -> void:
	var p := player(p_idx)
	var u: Dictionary = p.units[unit_index]
	var e_idx := enemy_index(p_idx)
	var pdict: Dictionary = params if params is Dictionary else {}
	var amount := _num(pdict.get("amount", 1))
	match effect:
		"passive-damage-enemy-front", "passive-damage-enemy-front-on-spell", "passive-damage-enemy-front-on-form":
			var fi: int = front_index(e_idx)
			if fi >= 0:
				VerifiedRules.passive_damage_unit(self,p_idx,unit_index,e_idx,fi,amount,base_ability)
			elif effect == "passive-damage-enemy-front-on-spell" or pdict.get("fallbackAvatar", false):
				VerifiedRules.passive_damage_avatar(self,p_idx,unit_index,e_idx,amount,base_ability)
		"passive-shield-self-if-front", "turn-shield", "passive-buff-self-if-front":
			if int(u.front) == 1:
				if effect == "passive-buff-self-if-front":
					_grow_unit(u, _num(pdict.get("attack", 0)), _num(pdict.get("hp", 0)))
				else:
					_grant_unit_armor(u, amount, false)
					_log("%s 获得 %d 点护盾。" % [u.name, amount], TONE_SUCCESS)
		"passive-heal-self-if-front", "turn-heal":
			if int(u.front) == 1:
				_heal_unit(u, amount)
		"passive-heal-avatar-on-own-card", "card-heal-avatar", "passive-heal-draw-avatar-on-own-card":
			_heal_avatar(p_idx, amount)
			if effect == "passive-heal-draw-avatar-on-own-card":
				_draw(p_idx, 1)
		"passive-shield-self-after-combat", "combat-aegis":
			_grant_unit_armor(u, amount, false)
			_log("%s 的护盾生效。" % u.name, TONE_SUCCESS)
		"passive-shield-self":
			_grant_unit_armor(u, amount, false)
		"passive-shield-self-heal-avatar-if-front":
			if int(u.front) == 1:
				_grant_unit_armor(u, amount, false)
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
				_heal_unit(hurt[int(floor(randf01() * hurt.size()))], amount)
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
			VerifiedRules.passive_damage_avatar(self,p_idx,unit_index,e_idx,amount,base_ability)
		"passive-damage-random-enemy":
			var enemies: Array = []
			for i in player(e_idx).units.size():
				if int(player(e_idx).units[i].hp) > 0:
					enemies.append(i)
			if enemies.is_empty():
				return
			if pdict.get("all", false):
				for ei in enemies:
					VerifiedRules.passive_damage_unit(self,p_idx,unit_index,e_idx,ei,amount,base_ability)
			else:
				for k in mini(2, enemies.size()):
					VerifiedRules.passive_damage_unit(self,p_idx,unit_index,e_idx,enemies[int(floor(randf01() * enemies.size()))],amount,base_ability)
		"passive-damage-reserve-on-kill":
			if bool(ctx.get("killed", false)):
				for i in player(e_idx).units.size():
					var eu: Dictionary = player(e_idx).units[i]
					if int(eu.hp) > 0 and int(eu.get("front", 0)) == 0:
						VerifiedRules.passive_damage_unit(self,p_idx,unit_index,e_idx,i,amount,base_ability)
		"passive-damage-freeze-defender", "passive-freeze-combat-defender", "passive-freeze-brittle-combat-defender", "form-brittle-defender", "combat-freeze":
			var defender = ctx.get("defender")
			if defender is Dictionary and int(defender.hp) > 0:
				if effect in ["passive-damage-freeze-defender"]:
					# defender lives on enemy side
					for i in player(e_idx).units.size():
						if player(e_idx).units[i].get("uid") == defender.get("uid"):
							VerifiedRules.passive_damage_unit(self,p_idx,unit_index,e_idx,i,amount,base_ability)
							break
				if effect in ["passive-freeze-combat-defender", "passive-damage-freeze-defender"]:
					for i in player(e_idx).units.size():
						if player(e_idx).units[i].get("uid") == defender.get("uid"):
							VerifiedRules.Stun.apply(self, e_idx, i)
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
				_grant_unit_armor(u, int(pdict.shield), false)
			_log("%s 退回准备区。" % u.name, TONE_NEUTRAL)
		"passive-armor-break-self-on-damaged":
			VerifiedRules.ArmorBreak.give(self, p_idx, unit_index, p_idx, unit_index, _num(ctx.get("damage", amount)))
			if pdict.get("hp", 0):
				_grow_unit(u, 0, int(pdict.hp))
		"passive-armor-break-enemy-on-damage":
			var defender = ctx.get("defender")
			if defender is Dictionary and int(defender.hp) > 0:
				for i in player(e_idx).units.size():
					if player(e_idx).units[i].get("uid") == defender.get("uid"):
						VerifiedRules.ArmorBreak.give(self, p_idx, unit_index, e_idx, i, amount)
		"passive-armor-break-enemy-avatar":
			VerifiedRules.ArmorBreak.give(self, p_idx, unit_index, e_idx, -1, amount)
		"passive-armor-break-enemy-front":
			var fi: int = front_index(e_idx)
			if fi >= 0:
				VerifiedRules.ArmorBreak.give(self, p_idx, unit_index, e_idx, fi, amount)
		"passive-armor-break-defender":
			var defender = ctx.get("defender")
			if defender is Dictionary and int(defender.hp) > 0:
				for i in player(e_idx).units.size():
					if player(e_idx).units[i].get("uid") == defender.get("uid"):
						VerifiedRules.ArmorBreak.give(self, p_idx, unit_index, e_idx, i, amount)
		"passive-armor-break-enemies-on-damaged":
			if _num(ctx.get("damage", 0)) >= _num(pdict.get("threshold", 3)):
				for eu in player(e_idx).units:
					if int(eu.hp) > 0:
						VerifiedRules.ArmorBreak.give(self, p_idx, unit_index, e_idx, _unit_index_by_uid(e_idx, eu.uid), amount)
		"passive-shield-on-overheal":
			_grant_unit_armor(u, amount, false)
			if pdict.get("attack", 0):
				_grow_unit(u, int(pdict.attack), 0)
		"passive-gain-energy":
			_set_fire(p_idx,mini(int(p.get("maxEnergy",2))+2,int(p.energy)+amount))
		"form-shield-on-spell", "form-mend-on-spell":
			if effect == "form-mend-on-spell":
				_heal_unit(u, amount)
			else:
				_grant_unit_armor(u, amount, false)
		"passive-shield-front-on-realm", "passive-shield-front-boost-realm-on-realm":
			var fi: int = front_index(p_idx)
			if fi >= 0:
				_grant_unit_armor(p.units[fi], amount, false)
		"realm-shield":
			pass
		"resonance-avatar":
			VerifiedRules.passive_damage_avatar(self,p_idx,unit_index,e_idx,amount,base_ability)
		_:
			_log("效果暂未完全结算：%s" % effect, TONE_NEUTRAL)


func end_turn(p_idx: int) -> bool:
	if VerifiedRules.Link.ready_hand(self,p_idx)>=0:return false
	if phase == "opening":
		return false
	# 与 JS endTurn 对齐：不强制先升勾（升勾只卡出牌/出击）
	if not pending_choice.is_empty():
		_log("请先完成当前的占卜选择。", TONE_DANGER)
		return false
	if not response_window.is_empty():
		_log("请先处理当前响应窗口。", TONE_DANGER)
		return false
	if winner >= 0 or current_player != p_idx:
		return false
	_record("end_turn", {}, p_idx)
	VerifiedRules.end_turn(self, p_idx)
	VerifiedRules.Insight.leave(self, p_idx)
	if winner >= 0:
		state_changed.emit()
		return true
	_resolve_resolution_stack()
	if winner >= 0:
		state_changed.emit()
		return true
	if not pending_choice.is_empty() or not response_window.is_empty():
		resolution_stack.push_front({"kind": "charm-end-turn", "playerIndex": p_idx})
	else: _advance_turn(p_idx)
	state_changed.emit()
	return true


func _advance_turn(p_idx: int) -> void:
	VerifiedRules.StarShopCards.expire(self)
	VerifiedRules.Wave7Reworks.expire(self)
	VerifiedRules.Xuan.expire(self)
	VerifiedRules.BlueGreen.expire(self)
	VerifiedRules.TwoFaces.expire(self)
	VerifiedRules.StarBear.expire_turn(self)
	VerifiedRules.PipeFox.expire_turn(self)
	VerifiedRules.OwlInsect.expire_turn(self)
	VerifiedRules.MonkCleaner.expire_turn(self)
	VerifiedRules.BondDream.expire_turn(self)
	VerifiedRules.Stun.end_turn(self, p_idx)
	var depth := resolution_stack.size()
	VerifiedRules.FoxLotus.after_stun_end(self,p_idx)
	if resolution_stack.size()>depth:
		resolution_stack.insert(depth,{"kind":"turn-transition","playerIndex":p_idx})
		_resolve_resolution_stack()
		return
	_switch_turn(p_idx)


func _switch_turn(p_idx: int) -> void:
	VerifiedRules.CoopFirst.end_turn(self)
	VerifiedRules.CoopMiddle.end_turn(self, p_idx)
	VerifiedRules.CoopLate.expire_turn(self)
	current_player = 1 - p_idx
	if int(player(p_idx).get("towerExtraTurns", 0)) > 0:
		player(p_idx).towerExtraTurns -= 1
		current_player = p_idx
	turn_counter += 1
	_begin_turn(current_player)


func _set_fire(owner: int, value: int, spent: bool = false) -> void:
	VerifiedRules.Moon.change_fire(self,owner,value,spent)


func _begin_turn(p_idx: int) -> void:
	VerifiedRules.DragonAbyss.Travel.turns_boundary(self)
	VerifiedRules.Moon.begin_snapshot(self)
	VerifiedRules.MonkCleaner.refresh(self)
	VerifiedRules.HairPower.expire(self,p_idx)
	VerifiedRules.Fortune.turn_boundary(self)
	var p := player(p_idx)
	for side in players:
		for unit in side.units:
			if unit.has("twinZeroTurn"):
				unit.erase("twinZeroTurn")
				_recalc(unit)
			if unit.get("formRules", {}).get("zeroPowerEnemyTurn", false) or unit.get("formRules",{}).get("onikiriEnemyPower",false) or unit.get("formRules",{}).get("yitiaoGuard",false): _recalc(unit)
	var old_avatar_armor := int(p.avatarArmor)
	var old_avatar_break := int(p.get("avatarArmorBreak",0))
	p.avatarArmor = 0
	if not VerifiedRules.Poison.preserves(self, p_idx, -1): p.avatarArmorBreak = 0
	VerifiedRules.House.turn_start_removed(self,p_idx,-1,old_avatar_armor,old_avatar_break-int(p.get("avatarArmorBreak",0)))
	p.attackUsed = false
	p.levelUpUsed = false
	p.cardsPlayedThisTurn = 0
	for owner in players.size():
		var instant_usage := kw_usage(owner, "instant")
		instant_usage.used = false
		instant_usage.erase("count")
	VerifiedRules.Light.refresh_fire(self, p_idx)
	VerifiedRules.StarRealms.turn_start(self, p_idx)
	VerifiedRules.Light.turn_start(self, p_idx)
	if p_idx == 0 and p.get("turnsTaken", 0) + 1 == int(rules.get("bonusUpgradeTurn", 7)):
		p.bonusUpgrades = int(p.bonusUpgrades) + 1
		_log("%s 获得一次额外升勾机会。" % p.name, TONE_SUCCESS)
	p["turnsTaken"] = int(p.get("turnsTaken", 0)) + 1
	# Remove expiring armor first. Death countdowns resolve before ability timers.
	for i in p.units.size():
		var unit: Dictionary = p.units[i]
		var old_armor := int(unit.shield)
		var old_break := int(unit.armorBreak)
		if not VerifiedRules.Poison.preserves(self, p_idx, i): unit.armorBreak = 0
		if old_break != int(unit.armorBreak) and (not VerifiedRules.DuskCycle.realms(self, 1-p_idx, "peacock-mist").is_empty() or VerifiedRules.CoopFirst.has_miasma(self, unit)): _recalc(unit)
		if not VerifiedRules.Bingyong.preserves_armor(unit):
			unit.shield = maxi(0, int(unit.shield) - int(unit.get("shieldExpires", 0)))
			unit.shieldExpires = 0
		VerifiedRules.ArmorBlood.armor_changed(self, unit)
		VerifiedRules.House.turn_start_removed(self,p_idx,i,old_armor-int(unit.shield),old_break-int(unit.armorBreak))
		VerifiedRules.YanmieTrio.armor_removed(self, p_idx, i, old_armor-int(unit.shield))
	VerifiedRules.Poison.turn_start(self, p_idx)
	VerifiedRules.SpellReplay.begin_turn(self)
	VerifiedRules.Firefly.begin_turn(self, p_idx)
	VerifiedRules.Bingyong.begin_turn(self, p_idx)
	VerifiedRules.CoopMiddle.turn_start(self, p_idx)
	# knockout countdown
	for u in p.units:
		if int(u.hp)<=0 and int(u.knockout)>0 and VerifiedRules.Rebirth.can_revive(u):
			u.knockout = int(u.knockout) - 1
			if int(u.knockout) == 0:
				VerifiedRules.Pine.countdown_zero(self,p_idx,_unit_index_by_uid(p_idx,u.uid))
				u.hp = int(u.maxHp)
				u.shield = 0
				_log("%s 自行归队，生命回复至满。" % u.name, TONE_SUCCESS)
				VerifiedRules.Movement.revived(self, p_idx, _unit_index_by_uid(p_idx, u.uid))
	# Native charge after natural revival.
	VerifiedRules.BlueGreen.refresh(self)
	VerifiedRules.SunSmoke.begin_turn_charge(self, p_idx)
	# Snapshot after natural revival; a unit revived by another timer below does
	# not get a second, artificial turn-start reduction in the same traversal.
	var ticking: Array = []
	for i in p.units.size():
		var unit: Dictionary = p.units[i]
		if int(unit.hp) > 0 and (int(unit.level) >= 1 or unit.has("jumpCoffin")) and not VerifiedRules.Countdown.timer(unit).is_empty(): ticking.append(i)
	VerifiedRules.Coffin.sort_timers(self, p_idx, ticking)
	VerifiedRules.TomatoFire.turn_start(self, p_idx)
	VerifiedRules.Bailang.turn_start(self, p_idx)
	# A realm can pause for a real choice. Preserve later realms and the rest
	# of the start phase beneath its suspended effects.
	var realm_depth := resolution_stack.size()
	if _trigger_realms(p_idx):
		if winner < 0: resolution_stack.insert(realm_depth,{"kind":"turn-after-realms","playerIndex":p_idx,"ticking":ticking})
		return
	_begin_turn_after_realms(p_idx,ticking)


func _begin_turn_after_realms(p_idx: int, ticking: Array) -> void:
	VerifiedRules.Commission.progress(self, p_idx, "turn")
	VerifiedRules.TimeRewind.turn_start(self, p_idx)
	VerifiedRules.Wave7Reworks.turn_start(self, p_idx)
	VerifiedRules.Hanafuda.turn_start(self, p_idx)
	var p := player(p_idx)
	VerifiedRules.DuskCycle.turn_start(self, p_idx)
	VerifiedRules.PeachGrove.turn_start(self, p_idx)
	VerifiedRules.MirrorSong.turn_start(self,p_idx)
	VerifiedRules.Yi.turn_start(self,p_idx)
	VerifiedRules.BlackWhite.turn_start(self,p_idx)
	VerifiedRules.Zhenjian.turn_start(self,p_idx)
	VerifiedRules.Lantern.turn_start(self,p_idx)
	VerifiedRules.SilkNinja.turn_start(self,p_idx)
	VerifiedRules.KoiFragrance.turn_start(self,p_idx)
	VerifiedRules.Glutton.turn_start(self,p_idx)
	VerifiedRules.Doll.turn_start(self,p_idx)
	VerifiedRules.Otakemaru.turn_start(self,p_idx)
	VerifiedRules.House.turn_start(self,p_idx)
	VerifiedRules.OniAsura.turn_start(self,p_idx)
	VerifiedRules.PipeFox.turn_start(self,p_idx)
	VerifiedRules.Maple.turn_start(self,p_idx)
	VerifiedRules.Paint.turn_start(self,p_idx)
	VerifiedRules.StarBear.turn_start(self,p_idx)
	VerifiedRules.Sparrow.turn_start(self,p_idx)
	VerifiedRules.Headless.turn_start(self,p_idx)
	VerifiedRules.Puppet.turn_start(self,p_idx)
	VerifiedRules.Enma.turn_start(self,p_idx)
	VerifiedRules.Goldfish.turn_start(self,p_idx)
	VerifiedRules.Vine.turn_start(self,p_idx)
	VerifiedRules.Moon.turn_start(self,p_idx)
	VerifiedRules.Bamboo.turn_start(self)
	VerifiedRules.TreeSakura.turn_start(self, p_idx)
	VerifiedRules.SerpentGhost.begin_turn(self,p_idx)
	VerifiedRules.MusicFire.begin_turn(self,p_idx)
	VerifiedRules.SugarCat.begin_turn(self,p_idx)
	VerifiedRules.EssenceFeast.begin_turn(self,p_idx)
	VerifiedRules.RabbitTide.begin_turn(self,p_idx)
	VerifiedRules.WisdomLamp.begin_turn(self,p_idx)
	VerifiedRules.Solar.turn_start(self, p_idx)
	VerifiedRules.Chen.turn_start(self, p_idx)
	VerifiedRules.Rain.turn_start(self, p_idx)
	VerifiedRules.WaterMoon.turn_start(self, p_idx)
	VerifiedRules.LineageScroll.turn_start(self, p_idx)
	VerifiedRules.FactionArt.turn_start(self, p_idx)
	VerifiedRules.DragonFlow.turn_start(self, p_idx)
	VerifiedRules.ZenMisfortune.turn_start(self, p_idx)
	VerifiedRules.Blueprint.turn_start(self, p_idx)
	VerifiedRules.NineTails.turn_start(self, p_idx)
	VerifiedRules.FortuneCat.turn_start(self, p_idx)
	VerifiedRules.FortunateDuo.turn_start(self, p_idx)
	VerifiedRules.YanmieTrio.turn_start(self, p_idx)
	VerifiedRules.HairPower.begin_turn(self,p_idx)
	VerifiedRules.FearWing.begin_turn(self,p_idx)
	VerifiedRules.Coffin.turn_start(self, p_idx)
	# The original turn-start abilities precede retreat and the normal draw.
	# An ability can win before an empty deck would cause draw-phase defeat.
	for idx in ticking:
		if winner >= 0: break
		VerifiedRules.reduce_countdown(self, p_idx, int(idx), 1,-1,false)
		_resolve_resolution_stack()
	if winner < 0:
		_log("%s 获得行动权。" % p.name, TONE_TURN)
		for i in p.units.size():
			if int(p.units[i].hp) > 0 and winner < 0:
				_run_unit_hooks(p_idx, i, "turn-started", {})
				VerifiedRules.Bingyong.unit_turn_start(self, p_idx, i)
				VerifiedRules.DogDemon.turn_start(self, p_idx, i)
				VerifiedRules.RednightWalnut.turn_start(self,p_idx,i)
				VerifiedRules.Fortune.turn_start(self, p_idx, i)
				VerifiedRules.Baize.turn_start(self,p_idx,i)
				VerifiedRules.ShenqiHuang.unit_turn_start(self, p_idx, i)
				VerifiedRules.BookJue.turn_start(self, p_idx, i)
				VerifiedRules.FoxSuzuka.turn_start(self, p_idx, i)
				VerifiedRules.ArmorBlood.turn_start(self, p_idx, i)
		# Continuous form abilities trigger in their installation order, so a
		# full-party recovery can change the injured pool of the following form.
		var forms: Array = []
		for i in p.units.size():
			if int(p.units[i].hp) > 0 and not p.units[i].get("form", {}).is_empty(): forms.append(i)
		forms.sort_custom(func(a, b): return int(p.units[a].get("formInstalledOrder", 0)) < int(p.units[b].get("formInstalledOrder", 0)))
		for i in forms:
			if int(p.units[i].hp) <= 0 or winner >= 0: continue
			_run_form_hooks(p_idx, i, "turn-started", {})
			if p.units[i].get("formRules", {}).get("starsFoxLure", false):
				resolution_stack.append({"kind":"stars-fox-lure-turn","playerIndex":p_idx,"sourceIndex":i})
			VerifiedRules.Mianqiling.form_turn_start(self,p_idx,i)
			VerifiedRules.ShenqiHuang.form_turn_start(self, p_idx, i)
			VerifiedRules.WaterMoon.form_trigger(self, p_idx, p.units[i])
			if p.units[i].id == VerifiedRules.Izanami.ID and VerifiedRules.Izanami.form(self, p_idx, "izanamiGoddess"): VerifiedRules.Izanami.strongest(self, p_idx)
			VerifiedRules.KoiFragrance.form_turn_start(self,p_idx,i)
			VerifiedRules.Susanoo.form_turn_start(self,p_idx,i)
			VerifiedRules.Garuda.form_turn_start(self,p_idx,i)
			VerifiedRules.Butterfly.form_turn_start(self,p_idx,i)
			VerifiedRules.Peach.turn_started(self, p_idx, i)
			VerifiedRules.Firefly.form_turn_start(self, p_idx, i)
			VerifiedRules.Bingyong.form_turn_start(self, p_idx, i)
			VerifiedRules.Shantong.turn_start(self, p_idx, i)
			VerifiedRules.BoxMaiden.form_turn_start(self,p_idx,i)
			VerifiedRules.Light.form_turn_start(self, p_idx, i)
			VerifiedRules.SunSmoke.form_turn_start(self, p_idx, i)
			VerifiedRules.GiftEnergy.turn_start(self, p_idx, i)
			VerifiedRules.ArmorBlood.form_turn_start(self, p_idx, i)
			VerifiedRules.OwlInsect.form_turn_start(self,p_idx,i)
			VerifiedRules.Eye.turn_start(self, p_idx, i)
			VerifiedRules.BondDream.turn_start(self, p_idx, i)
	if winner >= 0: return
	VerifiedRules.SunSmoke.enemy_turn_start(self, p_idx)
	# 选择尚未完成时暂停回合开始，完成后才回退战斗区并普通抽牌。
	VerifiedRules.Raccoon.turn_start(self,p_idx)
	VerifiedRules.Rebirth.queue_incarnation(self,p_idx,true)
	VerifiedRules.ApeSleeve.turn_start(self,p_idx)
	VerifiedRules.ThreeTail.turn_start(self,p_idx)
	VerifiedRules.Onikiri.turn_start(self,p_idx)
	VerifiedRules.SandBook.turn_start(self, p_idx)
	VerifiedRules.DragonAbyss.Aki.turn_start(self, p_idx)
	VerifiedRules.DragonAbyss.Travel.turn_start(self, p_idx)
	VerifiedRules.DragonAbyss.Serving.turn_start(self, p_idx)
	VerifiedRules.DragonAbyss.Discard.turn_start(self, p_idx)
	VerifiedRules.PaperDance.turn_start(self, p_idx)
	VerifiedRules.TwinSight.turn_start(self, p_idx)
	VerifiedRules.Xuan.turn_start(self, p_idx)
	resolution_stack.push_front({"kind": "turn-retreat-draw", "playerIndex": p_idx})
	_resolve_resolution_stack()


func _trigger_realms(p_idx: int) -> bool:
	var ids: Array = []
	for realm in player(p_idx).realms:
		# Older runtime records can predate installed-realm identities.
		if not realm.has("uid"):
			realm.uid="%s-realm-%d"%[player(p_idx).id,next_card_id]
			next_card_id+=1
		ids.append(str(realm.uid))
	return _trigger_realm_ids(p_idx,ids)


func _trigger_realm_ids(p_idx: int, ids: Array) -> bool:
	for i in ids.size():
		if winner >= 0: return false
		var depth := resolution_stack.size()
		_trigger_one_realm(p_idx,str(ids[i]))
		# Finish one installed realm before the next may observe its result.
		# Lower stack entries belong to other start-phase abilities.
		_resolve_inline_frames(depth)
		if not pending_choice.is_empty() or not response_window.is_empty():
			if i+1 < ids.size(): resolution_stack.insert(depth,{"kind":"realms-continue","playerIndex":p_idx,"realmIds":ids.slice(i+1)})
			return true
	return false


func _trigger_one_realm(p_idx: int, uid: String) -> void:
	var realm: Dictionary = {}
	for installed in player(p_idx).realms:
		if str(installed.get("uid",""))==uid: realm=installed; break
	if realm.is_empty() or int(realm.get("hp",0))<=0: return
	if VerifiedRules.StarShopCards.realm_trigger(self, p_idx, realm): return
	if VerifiedRules.FoxFlame.realm_trigger(self, p_idx, realm): return
	if VerifiedRules.DuskCycle.turn_realm(self, p_idx, realm): return
	if VerifiedRules.Blueprint.realm_tick(self, p_idx, realm): return
	if VerifiedRules.FortuneCat.income(self, p_idx, realm): return
	if VerifiedRules.Grudge.realm_tick(self, p_idx, realm): return
	if VerifiedRules.BaizeYuanqi.realm_tick(self, p_idx, realm): return
	if VerifiedRules.FearWing.trigger_realm(self,p_idx,realm):return
	if VerifiedRules.WisdomLamp.trigger_realm(self,p_idx,realm):return
	if VerifiedRules.Langya.trigger_realm(self,p_idx,realm):return
	if VerifiedRules.Chen.trigger_realm(self, p_idx, realm): return
	if VerifiedRules.Rain.trigger_realm(self, p_idx, realm): return
	if VerifiedRules.LunarTrick.trigger_realm(self, p_idx, realm): return
	if VerifiedRules.FortunateDuo.golden(self, p_idx, realm): return
	if VerifiedRules.DragonAbyss.Travel.trigger_realm(self, p_idx, realm): return
	if VerifiedRules.DragonAbyss.Jade.trigger_realm(self, p_idx, realm): return
	if VerifiedRules.Wave7Reworks.trigger_realm(self, p_idx, realm): return
	if VerifiedRules.Guishihei.turn_realm(self, p_idx, realm): return
	if VerifiedRules.HairPower.trigger_realm(self,p_idx,realm):return
	if VerifiedRules.MusicFire.trigger_realm(self,p_idx,realm):return
	if VerifiedRules.Cooking.trigger_realm(self,p_idx,realm):return
	if VerifiedRules.RednightWalnut.trigger_realm(self,p_idx,realm):return
	if VerifiedRules.RedPurple.trigger_realm(self,p_idx,realm): return
	if VerifiedRules.Sparrow.trigger_realm(self,p_idx,realm): return
	if VerifiedRules.Mountain.trigger_realm(self,p_idx,realm): return
	if VerifiedRules.PaperDance.realm_turn(self, p_idx, realm) or VerifiedRules.SandBook.realm_turn(self, p_idx, realm): return
	if VerifiedRules.Huang.trigger_realm(self,p_idx,realm): return
	if realm.get("trigger") in ["hand-card-used","native-continuous"]: return
	if int(realm.get("countdown",0))>0:
		realm.countdown=int(realm.countdown)-1
		if int(realm.countdown)>0:return
		realm.countdown=int(realm.get("countdownReset",2))
	_apply_realm_trigger(p_idx,enemy_index(p_idx),realm)
	if int(realm.get("hp",0))<=0:VerifiedRules.Huang.destroy(self,p_idx,realm,"破碎")


func _apply_realm_trigger(p_idx: int, e_idx: int, realm: Dictionary) -> void:
	_log("幻境「%s」引动。" % realm.get("name", "?"), TONE_CARD)
	var source_idx := _source_index(p_idx,{"unitId":realm.get("sourceUnit","")})
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
					_grant_unit_armor(u, _num(value), false)
					_log("%s 获得 %d 点护盾。" % [u.name, _num(value)], TONE_SUCCESS)
			"shield-all-allies":
				for u in player(p_idx).units:
					if int(u.hp) > 0:
						_grant_unit_armor(u, _num(value), false)
			"damage-enemy-front":
				var fi2: int = front_index(e_idx)
				if fi2 >= 0:
					_damage_unit(e_idx, fi2, _num(value), p_idx, source_idx)
				else:
					_damage_avatar(e_idx, _num(value), p_idx, source_idx)
			"draw":
				_draw(p_idx, _num(value) if _num(value) > 0 else 1)
			_:
				_log("效果暂未完全结算", TONE_NEUTRAL)


func snapshot() -> Dictionary:
	return {
		"seed": seed,
		"commissionDay": commission_day,
		"turn": turn_counter,
		"round": get_round(),
		"current": current_player,
		"winner": winner,
		"phase": phase,
		"responseWindow": (not response_window.is_empty()),
		"stackDepth": resolution_stack.size(),
		"pendingChoice": (not pending_choice.is_empty()),
		"pendingChoiceState": pending_choice.duplicate(true),
		"players": players,
		"log_size": log.size(),
		"commands": command_log.size(),
		"commandLog": command_log.duplicate(),
		"ruleEvents": rule_events.duplicate(true),
	}


func command_log_json() -> String:
	return JSON.stringify(command_log)
