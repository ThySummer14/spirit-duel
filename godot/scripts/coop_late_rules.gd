extends RefCounted

const Choice := preload("res://scripts/restored_card_choices.gd")
const Content := preload("res://scripts/content_loader.gd")

const OWL_FEATHER := "coop-late-owl-feather"
const OWL_SONG := "coop-late-owl-song"
const WHALE_TIDE := "coop-late-whale-tide"
const CRAB_WAVES := "coop-late-crab-waves"
const SEA_CRACK := "coop-late-sea-crack"
const SEA_JADE := "coop-late-sea-jade"
const KOI_TIDE := "coop-late-koi-tide"
const KAPPA_WAVE := "coop-late-kappa-wave"
const VINE_DANCE := "coop-late-vine-dance"
const PINE_MUSIC := "coop-late-pine-music"
const FORM_BOND := "coop-late-form-bond"
const WAVE_VALUES := [4, 1, 1, 1]


static func source(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})


static func active_realms(gs, owner: int, action: String) -> Array:
	return gs.player(owner).realms.filter(func(realm): return realm.nativeRealm == action and int(realm.hp) > 0)


static func targets(gs, owner: int, card: Dictionary):
	var action: String = card.get("effect", "")
	if action not in [SEA_JADE, KOI_TIDE]: return null
	var candidates := Choice.live_units(gs, owner)
	if action == KOI_TIDE:
		var idx := source(gs, owner, str(card.unitId))
		if idx >= 0:
			var caster: Dictionary = gs.player(owner).units[idx]
			candidates = candidates.filter(func(unit): return unit.uid != caster.uid)
	return candidates.map(func(unit): return str(unit.uid))


static func wave_values(gs, owner: int, bond: bool) -> Array:
	var values := WAVE_VALUES.duplicate()
	if bond:
		var increases: Array = gs.player(owner).get("coopLateKappaBoosts", [0, 0, 0, 0])
		for index in values.size():
			values[index] += int(increases[index])
	return values


static func koi_power(gs, owner: int, bond: bool) -> int:
	return 1 + (int(gs.player(owner).get("coopLateKappaAttacks", 0)) if bond else 0)


static func describe_face(gs, owner: int, face: Dictionary) -> void:
	var bond: bool = face.get("coopBond", false)
	match face.get("effect", ""):
		KOI_TIDE:
			face.currentCardStats = "本回合力量 +%d" % koi_power(gs, owner, bond)
		KAPPA_WAVE:
			var values := wave_values(gs, owner, bond)
			face.currentCardStats = "投射 %d · %d 个式神 +%d/+%d" % values
		CRAB_WAVES:
			face.currentCardStats = "进场 %d 个幻境" % (1 + int(gs.player(owner).get("coopLateCrabUses", 0)))


static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var bond: bool = card.get("coopBond", false)
	match str(effect.get("action", "")):
		OWL_FEATHER, OWL_SONG, WHALE_TIDE, CRAB_WAVES:
			deploy(gs, owner, src, card, str(effect.action), bond)
		SEA_CRACK:
			if bond:
				gs.VerifiedRules.Otakemaru.attach(gs, owner, source(gs, owner, "dayueling"), owner, src)
			gs._resolve_action(owner, src, card, {"action": "assault", "value": effect.value}, target_id, target)
		SEA_JADE:
			if target.is_empty(): return true
			var target_index: int = gs._unit_index_by_uid(owner, str(target.uid))
			if target_index < 0 or int(target.hp) <= 0: return true
			gs.VerifiedRules.Otakemaru.attach(gs, owner, src, owner, target_index, false, true)
			target.swift = true
			gs.player(owner).coopLateJadeActive = true
			if bond:
				var suzuka := source(gs, owner, "lingyuyuqian")
				gs.VerifiedRules.ThreeTail.projectile(gs, owner, suzuka, 1, "琼玉镇海")
		KOI_TIDE:
			if target.is_empty(): return true
			var target_index: int = gs._unit_index_by_uid(owner, str(target.uid))
			if target_index < 0 or int(target.hp) <= 0: return true
			temp_power(gs, target, koi_power(gs, owner, bond))
			Choice.attack(gs, owner, target_index)
		KAPPA_WAVE:
			var values := wave_values(gs, owner, bond)
			gs.resolution_stack.append({"kind": "coop-late-kappa-grow", "playerIndex": owner, "values": values})
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, int(values[0]), "碧波连弹")
		VINE_DANCE, PINE_MUSIC:
			if bond:
				gs.resolution_stack.append({"kind": FORM_BOND, "playerIndex": owner, "sourceIndex": src, "action": effect.action})
			gs._apply_form(owner, src, card, effect.value)
		_:
			return false
	return true


static func deploy(gs, owner: int, src: int, card: Dictionary, action: String, bond: bool) -> void:
	var p: Dictionary = gs.player(owner)
	if action == CRAB_WAVES:
		var uses := int(p.get("coopLateCrabUses", 0))
		p.coopLateCrabUses = uses + 1
		for count in uses + 1:
			gs._deploy_realm(owner, card)
			if bond:
				var whale: Dictionary = p.units[source(gs, owner, "jiuciliang")]
				gs._grow_unit(whale, 1, 0)
				gs._grant_unit_armor(whale, 1)
		return
	gs._deploy_realm(owner, card)
	if not bond: return
	match action:
		OWL_FEATHER:
			gs.VerifiedRules.OwlInsect.attach_guard(gs, owner, source(gs, owner, "xun"), src)
		OWL_SONG:
			gs.VerifiedRules.Countdown.change(gs, owner, source(gs, owner, "shanfeng"), -2, owner)
		WHALE_TIDE:
			var cards: Array = p.hand.filter(func(inst): return "xieji" in Content.card_unit_ids(Content.card_def(str(inst.definitionId))))
			if cards.is_empty(): return
			var selected: Dictionary = cards[int(gs.next_random() % cards.size())].duplicate(true)
			var copy: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, str(selected.definitionId))
			selected.instanceId = copy.instanceId
			gs.VerifiedRules.Baize.put_hand(gs, owner, selected)


static func announced(gs, owner: int, src: int, card: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	if card.get("type") == "realm":
		var whale_idx := source(gs, owner, "jiuciliang")
		if whale_idx >= 0 and int(p.units[whale_idx].hp) > 0:
			for realm in active_realms(gs, owner, WHALE_TIDE):
				if int(realm.get("coopLateTurn", -1)) == gs.turn_counter: continue
				realm.coopLateTurn = gs.turn_counter
				gs.VerifiedRules.Movement.move_to(gs, owner, whale_idx, 1)
				gs._grant_unit_armor(p.units[whale_idx], 1)
	if src < 0 or src >= p.units.size(): return
	if p.units[src].id != "xieji" or card.get("effect") == CRAB_WAVES: return
	for realm in active_realms(gs, owner, CRAB_WAVES):
		if int(realm.get("coopLateTurn", -1)) == gs.turn_counter: continue
		realm.coopLateTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "coop-late-crab-draw", "playerIndex": owner, "name": card.name})


static func temp_power(gs, unit: Dictionary, amount: int) -> void:
	unit.temporaryAttack = int(unit.get("temporaryAttack", 0)) + amount
	unit.coopLatePower = int(unit.get("coopLatePower", 0)) + amount
	gs._recalc(unit)


static func expire_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if not unit.has("coopLatePower"): continue
			unit.temporaryAttack = int(unit.get("temporaryAttack", 0)) - int(unit.coopLatePower)
			unit.erase("coopLatePower")
			gs._recalc(unit)


static func attack_started(gs, owner: int, src: int) -> void:
	var p: Dictionary = gs.player(owner)
	var attacker: Dictionary = p.units[src]
	if attacker.id == "hetong":
		p.coopLateKappaAttacks = int(p.get("coopLateKappaAttacks", 0)) + 1
	if not gs.VerifiedRules.OwlInsect.guarded(attacker) or not gs.VerifiedRules.OwlInsect.shikigami(attacker): return
	var count := active_realms(gs, owner, OWL_SONG).size()
	if count > 0: temp_power(gs, attacker, count)


static func prepare_combat(gs, owner: int, src: int, victim: int, idx: int, options: Dictionary) -> void:
	var attacker: Dictionary = gs.player(owner).units[src]
	var jade_owners: Array = attacker.get("otakeJades", {}).keys()
	var jade_enhanced := jade_owners.any(func(side): return gs.player(int(side)).get("coopLateJadeActive", false))
	if jade_enhanced and int(attacker.get("coopLateJadeTurn", -1)) != gs.turn_counter:
		attacker.coopLateJadeTurn = gs.turn_counter
		gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, 2)
	if options.get("combatCard", {}).get("coopFaceId", "") == "c180190:lingyuyuqian" and not options.get("coopLateCrackReady", false):
		options.coopLateCrackReady = true
		var armor: int = gs.VerifiedRules.ArmorBreak.amount(gs, victim, idx)
		if armor > 0: gs._grant_unit_armor(attacker, armor)


static func redirect_damage(gs, victim: int, idx: int, amount: int, owner: int, src: int, knockout_extra: int, critical: bool):
	if victim == owner or idx < 0 or src < 0: return null
	var attacker: Dictionary = gs.player(owner).units[src]
	if not attacker.get("formRules", {}).get("coopLatePine", false) or int(gs.player(victim).units[idx].front) != 1: return null
	var reserve := Choice.live_units(gs, victim).filter(func(unit): return int(unit.front) == 0)
	if reserve.is_empty(): return null
	var target: Dictionary = reserve[int(gs.next_random() % reserve.size())]
	var reserve_idx: int = gs._unit_index_by_uid(victim, str(target.uid))
	var result: Dictionary = gs.VerifiedRules.ArmorBreak.combat_damage(gs, owner, src, victim, reserve_idx, amount, false, false, knockout_extra, critical)
	if not result.get("redirected", false):
		result.redirected = true
		result.redirectedPlayer = victim
		result.redirectedIndex = reserve_idx
		result.redirectedTarget = target.uid
	return result


static func event(gs, kind: String, details: Dictionary) -> void:
	var owner := int(details.get("player", -1))
	if owner < 0: return
	if kind == "hand-charm-attached" and details.get("which") == "ward" and not details.get("cancelled", false):
		var p: Dictionary = gs.player(owner)
		if source(gs, owner, "hetong") >= 0:
			var increases: Array = p.get("coopLateKappaBoosts", [0, 0, 0, 0])
			increases[int(gs.next_random() % increases.size())] += 1
			p.coopLateKappaBoosts = increases
		return
	if kind == "vine-attached": vine_attached(gs, owner, str(details.uid))
	var carrier := charm_carrier(kind, details)
	if carrier.is_empty(): return
	owner = int(carrier.owner)
	var shan := source(gs, owner, "shanfeng")
	if shan < 0: return
	var target: Dictionary = gs.player(owner).units[shan]
	if int(target.hp) <= 0 or str(target.uid) != carrier.uid: return
	for realm in active_realms(gs, owner, OWL_FEATHER):
		gs.VerifiedRules.Countdown.change(gs, owner, shan, -1, owner)
		gs._grant_unit_armor(target, 1)


static func charm_carrier(kind: String, details: Dictionary) -> Dictionary:
	var owner := int(details.player)
	match kind:
		"owl-attached", "garuda-feather-attached", "sea-spirit-attached", "whale-charm-attached", "maple-doll-attached", "fox-flame-attached", "crocodile-attached", "lotus-attached", "spider-mark-attached":
			return {"owner": owner, "uid": str(details.target)}
		"pipe-mark-attached", "insect-attached":
			return {"owner": int(details.victimPlayer), "uid": str(details.target)}
		"otake-jade-attached", "soul-charm-attached":
			return {"owner": int(details.carrierPlayer), "uid": str(details.uid)}
		"charm-attached", "moon-attached", "vine-attached", "dragon-breath-attached", "cat-life-attached", "fear-attached", "water-spirit-charm", "goldfish-attached", "paper-fall-attached", "jump-slow-attached", "satiety-attached", "onikiri-charm-attached":
			return {"owner": owner, "uid": str(details.uid)}
	return {}


static func vine_attached(gs, owner: int, uid: String) -> void:
	var src := source(gs, owner, "tengji")
	var idx: int = gs._unit_index_by_uid(owner, uid)
	if src < 0 or idx < 0 or src == idx: return
	var p: Dictionary = gs.player(owner)
	var vine: Dictionary = p.units[src]
	var carrier: Dictionary = p.units[idx]
	if int(vine.hp) <= 0 or not vine.get("formRules", {}).get("coopLateVine", false): return
	if int(vine.get("coopLateVineTurn", -1)) == gs.turn_counter or not gs.VerifiedRules.OwlInsect.shikigami(carrier): return
	vine.coopLateVineTurn = gs.turn_counter
	gs.VerifiedRules.Vine.attach(gs, owner, idx)
	if carrier.id == "song" or carrier.get("vineSummon", false): carrier.swift = true


static func resolve_frame(gs, frame: Dictionary) -> bool:
	if not str(frame.kind).begins_with("coop-late-"): return false
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	match str(frame.kind):
		FORM_BOND:
			var src := int(frame.sourceIndex)
			var unit: Dictionary = p.units[src]
			if int(unit.hp) <= 0: return true
			if frame.action == VINE_DANCE and unit.get("formRules", {}).get("coopLateVine", false):
				var level := int(p.units[source(gs, owner, "song")].level)
				gs.VerifiedRules.Vine.summon(gs, owner, src, 1, level, level)
			elif frame.action == PINE_MUSIC and unit.get("formRules", {}).get("coopLatePine", false):
				gs.VerifiedRules.Vine.attach(gs, owner, src)
		"coop-late-kappa-grow":
			var values: Array = frame.values
			for ally in Choice.sample(gs, Choice.live_units(gs, owner), int(values[1])):
				gs._grow_unit(ally, int(values[2]), int(values[3]))
		"coop-late-crab-draw":
			var matches: Array = p.deck.filter(func(inst): return Content.card_def(str(inst.definitionId)).get("name") == frame.name)
			if not matches.is_empty():
				var drawn: Dictionary = matches[int(gs.next_random() % matches.size())]
				gs._draw(owner, 1, -1, {"drawInstanceId": drawn.instanceId})
		_:
			return false
	return true
