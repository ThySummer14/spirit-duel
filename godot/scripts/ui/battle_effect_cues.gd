extends RefCounted
## 从已结算快照推导演出。牌文只选择颜色/形状，不重新执行或预测规则。

const ContentLoader := preload("res://scripts/content_loader.gd")
const PALETTES := {
	"slash": ["b78bea", "fff0cb"], "fire": ["ed7845", "ffe4a0"],
	"ice": ["80d6eb", "eefbff"], "wind": ["9edbc8", "edf5d7"],
	"thunder": ["b7a2ef", "fff4bd"], "ink": ["9082c5", "e7d6f3"],
	"heal": ["a4df9a", "f6e6bc"], "petal": ["ecadd2", "fff1d3"],
	"shield": ["81c5e4", "e0f6ff"], "awaken": ["efc981", "fff7d8"],
	"form": ["d7bd83", "f7edcf"], "realm": ["ada2d7", "e8dcff"],
	"resource": ["dec589", "fff1bf"], "seal": ["a295d6", "f0e7ff"],
	"arcane": ["ab9bdc", "f3e6ff"],
}

static func family(card: Dictionary, kind: String = "damage") -> String:
	if kind in ["shield", "awaken", "form", "realm", "resource", "seal"]: return kind
	var id := str(card.get("unitId", ""))
	var unit := ContentLoader.unit_def(id)
	var motif := "%s %s %s" % [id, unit.get("name", ""), unit.get("title", "")]
	if kind in ["heal", "revive"]: return "petal" if "桃" in motif or "樱" in motif else "heal"
	if kind == "freeze": return "ice"
	for group in [
		["ice", ["雪", "冰", "霜", "rime", "frost"]],
		["fire", ["火", "焰", "炎", "凤凰", "炭治郎", "ember"]],
		["thunder", ["雷", "鸣", "storm"]],
		["wind", ["天狗", "风", "羽", "镰鼬"]],
		["ink", ["书", "墨", "判官", "鬼使", "ink"]],
		["slash", ["刀", "剑", "斩", "茨木", "酒吞", "山童"]],
	]:
		for token in group[1]:
			if token in motif: return group[0]
	return "slash" if card.get("type") == "combat" else "arcane"

static func palette(style: String) -> Array:
	var colors: Array = PALETTES.get(style, PALETTES.arcane)
	return [Color(colors[0]), Color(colors[1])]

static func _contexts(before: Dictionary, commands: Array) -> Array:
	# 响应/占卜结束后没有新的 play_card；优先使用此前等待结算的真实帧。
	var out: Array = []
	for i in range(commands.size() - 1, -1, -1):
		var cmd: Dictionary = commands[i]
		if cmd.get("c") == "play_card":
			out.append({"card": ContentLoader.card_def(str(cmd.a.get("card", ""))), "player": int(cmd.p)})
		if cmd.get("c") in ["basic_attack", "assault"]:
			var p := int(cmd.p)
			var idx := int(cmd.a.get("unit", -1))
			if idx >= 0 and idx < before.players[p].units.size():
				out.append({"card": {"unitId": before.players[p].units[idx].id, "type": "combat", "effects": [{"action": "assault"}]}, "player": p})
	var stack: Array = before.get("presentationStack", [])
	for i in range(stack.size() - 1, -1, -1):
		var frame: Dictionary = stack[i]
		if frame.get("kind") == "card-effect":
			var card := ContentLoader.card_def(str(frame.get("definitionId", "")))
			var p := int(frame.get("playerIndex", 0))
			if not out.any(func(c): return c.card.get("id", "") == card.get("id", "") and c.player == p):
				out.append({"card": card, "player": p})
	if out.is_empty(): out.append({"card": {}, "player": int(before.get("current", 0))})
	return out

static func _resolved_cue(kind: String, contexts: Array, after: Dictionary, target: String, player: int, area := "core") -> Dictionary:
	# 同一次响应结算可同时出现冰盾和原法术火伤，分别选择对应的视觉来源。
	var actions: Array = {
		"damage": ["damage", "damage-self", "damage-enemy-front", "burn-all", "assault"],
		"guard": ["damage", "damage-enemy-front", "burn-all", "assault"],
		"shield": ["shield", "fortify", "shield-self-player"], "freeze": ["freeze"],
		"heal": ["heal", "heal-avatar"], "revive": ["revive", "revive-all"],
		"form": ["form"], "awaken": ["awaken"], "realm": ["realm"],
		"seal": ["apply-brittle", "apply-armor-break", "debuff-stats", "set-attack-zero-this-turn"],
		"resource": ["draw", "chain-draw", "token-to-hand", "energy-gain", "buff-stats", "origin-shuffle", "focus-draw"],
	}.get(kind, [])
	var context: Dictionary = contexts[0]
	for candidate in contexts:
		var effects: Array = candidate.card.get("effects", [])
		if effects.any(func(e): return e.get("action", "") in actions):
			context = candidate
			break
	var source := ""
	for unit in after.players[context.player].units:
		if unit.id == context.card.get("unitId", ""): source = str(unit.uid)
	return _cue(kind, context.card, source, target, player, area)

static func build(before: Dictionary, after: Dictionary, commands: Array) -> Array:
	var out: Array = []
	# 初次挂载、布局刷新和测试初始化不是一次规则动作。
	if before.is_empty() or after.is_empty() or commands.is_empty(): return out
	var contexts := _contexts(before, commands)
	for p in 2:
		var old: Dictionary = before.players[p]
		var new: Dictionary = after.players[p]
		for i in new.units.size():
			var previous: Dictionary = old.units[i]
			var unit: Dictionary = new.units[i]
			var uid := str(unit.uid)
			var kinds: Array = []
			if int(unit.hp) < int(previous.hp): kinds.append("damage")
			elif int(unit.hp) > int(previous.hp): kinds.append("revive" if int(previous.hp) <= 0 else "heal")
			if int(unit.get("shield", 0)) > int(previous.get("shield", 0)): kinds.append("shield")
			elif int(unit.get("shield", 0)) < int(previous.get("shield", 0)): kinds.append("guard")
			if int(unit.get("frozen", 0)) > int(previous.get("frozen", 0)): kinds.append("freeze")
			if int(unit.get("armorBreak", 0)) > int(previous.get("armorBreak", 0)) or int(unit.get("brittle", 0)) > int(previous.get("brittle", 0)): kinds.append("seal")
			if int(unit.attack) < int(previous.attack) and int(unit.hp) > 0 and unit.get("form", {}).get("cardId", "") == previous.get("form", {}).get("cardId", ""): kinds.append("seal")
			if bool(unit.get("awakened", false)) and not bool(previous.get("awakened", false)): kinds.append("awaken")
			elif unit.get("form", {}).get("cardId", "") != previous.get("form", {}).get("cardId", ""): kinds.append("form")
			# 形态回满的治疗以形态纹样呈现，避免同一张牌的中心被重复光团覆盖。
			if "form" in kinds or "awaken" in kinds:
				kinds.erase("heal")
				kinds.erase("damage")
			if kinds.is_empty() and (int(unit.attack) > int(previous.attack) or int(unit.maxHp) > int(previous.maxHp)): kinds.append("resource")
			for kind in kinds: out.append(_resolved_cue(kind, contexts, after, uid, p))
		var core_delta := int(new.avatarHp) - int(old.avatarHp)
		if core_delta != 0: out.append(_resolved_cue("damage" if core_delta < 0 else "heal", contexts, after, "", p))
		var old_realms: Array = old.get("realms", [])
		for realm in new.get("realms", []):
			if not old_realms.any(func(r): return r.get("uid") == realm.get("uid")):
				var cue := _resolved_cue("realm", contexts, after, "", p)
				cue.target = cue.source
				out.append(cue)
		var added_cards: bool = new.hand.any(func(c): return not old.hand.any(func(o): return c.instanceId == o.instanceId))
		if added_cards or int(new.energy) > int(old.energy):
			out.append(_resolved_cue("resource", contexts, after, "", p, "hand" if added_cards else "energy"))
	return out

static func _cue(kind: String, card: Dictionary, source: String, target: String, player: int, area := "core") -> Dictionary:
	return {"kind": kind, "family": "shield" if kind == "guard" else family(card, kind), "source": source, "target": target, "player": player, "area": area}
