class_name MirrorSongRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const TRANSIENT := ["linkedUse", "linkOtherId", "linkRetrieve", "linkedByUid", "msLinked", "msLinkOtherIds", "msDreamSources"]
const EXTRA := ["msLinkTraits", "msLinkProjectiles", "msLinkDraws", "msLinkPower", "msLinkHp"]

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("mirrorSongRole", ""))

static func active(u: Dictionary) -> bool:
	return int(u.get("hp", 0)) > 0 and int(u.get("level", 0)) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func _base_member(u: Dictionary) -> bool:
	return not u.get("summoned", false) and not u.get("baseRulesSuppressed", false) and not u.get("removed", false)

static func groups(gs, owner: int, card: Dictionary) -> Array:
	if not gs.response_window.is_empty() or gs.phase == "opening" or card.get("twoFacesFromDeck", false) or card.get("chargedReleased", false): return []
	var src: int = gs._source_index(owner, card)
	if src < 0: return []
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or role(u) not in ["mirror", "song"]: return []
	var units: Array = [u] if role(u) == "mirror" else gs.player(owner).units.filter(func(a): return a != u and active(a) and _base_member(a) and (u.awakened or int(a.front) == 1))
	var result: Array = []
	for unit in units:
		var pool: Array = gs.player(owner).deck.filter(func(i): return Content.card_def(str(i.definitionId)).get("unitId") == unit.id and int(Content.card_def(str(i.definitionId)).get("level", 1)) <= int(unit.level))
		if not pool.is_empty(): result.append(pool)
	return result

static func candidates(gs, owner: int, card: Dictionary) -> Array:
	var result: Array = []
	for pool in groups(gs, owner, card): result.append_array(pool)
	return result

static func _clean(inst: Dictionary, return_to_deck: bool) -> Dictionary:
	var result := inst.duplicate(true)
	for key in TRANSIENT: result.erase(key)
	if return_to_deck and str(result.definitionId) != "c24202":
		for key in EXTRA: result.erase(key)
	return result

static func _gain_trait(inst: Dictionary, keyword: String) -> void:
	if not inst.has("msLinkTraits"): inst.msLinkTraits = []
	if keyword not in inst.msLinkTraits: inst.msLinkTraits.append(keyword)

static func enhance(gs, owner: int, options: Array) -> void:
	var ids: Array = options.map(func(i): return str(i.definitionId))
	var extra_traits: Array = []
	for id in ids:
		var granted_keyword: String = {"c24201": "lifesteal", "c24203": "pierce", "c24206": "instant", "c24207": "crit"}.get(id, "")
		if granted_keyword != "" and granted_keyword not in extra_traits: extra_traits.append(granted_keyword)
	var same_name := {}
	for id in ids: same_name[id] = int(same_name.get(id, 0)) + 1
	var mirror_awake: bool = gs.player(owner).units.any(func(u): return active(u) and role(u) == "mirror" and u.awakened)
	for option in options:
		for granted_keyword in extra_traits: _gain_trait(option, str(granted_keyword))
		if "c24205" in ids and Content.card_def(str(option.definitionId)).type == "form": _gain_trait(option, "swift")
		if mirror_awake and int(same_name.get(str(option.definitionId), 0)) > 1 and Content.card_def(str(option.definitionId)).get("unitId") == "yunwaijing": _gain_trait(option, "instant")
		if "c24204" in ids: option.msLinkProjectiles = int(option.get("msLinkProjectiles", 0)) + 1
		if "c24208" in ids: option.msLinkDraws = int(option.get("msLinkDraws", 0)) + 1
		if str(option.definitionId) == "c24202":
			option.msLinkPower = int(option.get("msLinkPower", 0)) + 1
			option.msLinkHp = int(option.get("msLinkHp", 0)) + 1

static func start_link(gs, owner: int, index: int):
	var inst: Dictionary = gs.card_instance(owner, index)
	if inst.is_empty(): return null
	var card := Content.card_def(str(inst.definitionId)); var src: int = gs._source_index(owner, card)
	if src < 0 or role(gs.player(owner).units[src]) not in ["mirror", "song"]: return null
	if gs.VerifiedRules.Link.ready_hand(gs, owner) >= 0 or not gs.pending_choice.is_empty(): return false
	var pools := groups(gs, owner, card)
	if pools.is_empty(): return false
	var view: Dictionary = gs.hand_card_def(owner, index)
	var targets: Array = [null] if view.get("target", "auto") == "auto" else gs.valid_targets(owner, view)
	# The original must be playable before link-granted instant or enhancement.
	if not targets.any(func(t): return gs.can_play_card(owner, index, t).ok): return false
	var options: Array = [_clean(inst, true)]
	var candidates_: Array = []
	for pool in pools:
		var selected: Dictionary = pool[int(gs.next_random() % pool.size())]
		candidates_.append(selected.duplicate(true)); options.append(_clean(selected, true))
	enhance(gs, owner, options)
	for option in options:
		option.linkedUse = true; option.linkedByUid = gs.player(owner).units[src].uid
		option.linkRetrieve = false; option.msLinked = true
		option.msLinkOtherIds = options.filter(func(i): return str(i.instanceId) != str(option.instanceId)).map(func(i): return str(i.instanceId))
		option.linkOtherId = str(option.msLinkOtherIds[0])
	gs.pending_choice = {"type": "native-link", "playerIndex": owner, "hand": index, "original": inst.duplicate(true), "candidate": candidates_[0], "candidates": candidates_, "options": options, "instanceIds": options.map(func(i): return str(i.instanceId)), "originFromDeck": index >= gs.player(owner).hand.size(), "msLink": true, "heading": "连 引", "title": "选择一张使用，其余洗回牌库", "hint": "展示原牌和每个符合条件式神的真实牌；只支付最终选牌，未选牌一起洗回。"}
	gs.phase = "choice"; gs.state_changed.emit(); return true

static func ready(choice: Dictionary, selected: Dictionary) -> Dictionary:
	return {"hand": choice.hand, "selected": selected.duplicate(true), "original": choice.original.duplicate(true), "candidate": choice.candidate.duplicate(true), "candidates": choice.candidates.duplicate(true), "options": choice.options.duplicate(true), "originFromDeck": choice.originFromDeck, "msLink": true}

static func take_link(gs, owner: int, index: int):
	var p: Dictionary = gs.player(owner); var choice: Dictionary = p.get("linkReady", {})
	if not choice.get("msLink", false) or index != int(choice.get("hand", -1)): return null
	var selected: Dictionary = choice.selected.duplicate(true)
	if choice.originFromDeck: p.deck = p.deck.filter(func(i): return str(i.instanceId) != str(choice.original.instanceId))
	else: p.hand.remove_at(index)
	var all_ids: Array = choice.options.map(func(i): return str(i.instanceId))
	p.deck = p.deck.filter(func(i): return str(i.instanceId) not in all_ids)
	for option in choice.options:
		if str(option.instanceId) != str(selected.instanceId): p.deck.append(_clean(option, true))
	p.erase("linkReady"); gs._shuffle(p.deck)
	gs.VerifiedRules.event(gs, "link-used", {"player": owner, "uid": str(selected.linkedByUid), "card": str(selected.definitionId), "other": str(selected.linkOtherId), "others": selected.msLinkOtherIds.duplicate(), "participants": choice.options.size()})
	link_taken(gs, owner)
	return selected

static func link_completed(gs, owner: int, card: Dictionary) -> void:
	for iid in card.get("msLinkOtherIds", []): gs.VerifiedRules.TwoFaces.link_completed(gs, owner, str(iid))

static func link_taken(gs, owner: int) -> void:
	var sources: Array = gs.player(owner).units.filter(func(u): return active(u) and u.get("formRules", {}).get("songDream", false)).map(func(u): return str(u.uid))
	if not sources.is_empty(): gs.resolution_stack.append({"kind": "ms-link-event", "playerIndex": owner, "sourceIndex": -1, "sources": sources})

static func promote(gs) -> void:
	# The shuffle ability already scheduled by returning the unchosen cards
	# resolves first; link observers then precede the selected card's use.
	if gs.resolution_stack.any(func(f): return f.get("kind") == "yi-shuffle"): return
	var markers: Array = gs.resolution_stack.filter(func(f): return f.get("kind") == "ms-link-event")
	if markers.is_empty(): return
	gs.resolution_stack = gs.resolution_stack.filter(func(f): return f.get("kind") != "ms-link-event")
	gs.resolution_stack.append_array(markers)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var view := card.duplicate(true)
	for key in EXTRA + ["msLinked", "msLinkOtherIds"]:
		if inst.has(key): view[key] = inst[key].duplicate(true) if inst[key] is Array or inst[key] is Dictionary else inst[key]
	var traits: Array = view.get("msLinkTraits", [])
	for keyword in traits:
		if keyword not in view.keywords: view.keywords.append(keyword)
	if "lifesteal" in traits: view.bloodSpellLifeSteal = true
	if view.get("type") == "combat":
		view.combatOption = view.get("combatOption", {}).duplicate(true)
		for entry in [["crit", "critical"], ["lifesteal", "lifeSteal"], ["pierce", "pierce"]]:
			if entry[0] in traits: view.combatOption[entry[1]] = true
	if view.get("type") == "form":
		view.formRules = view.get("formRules", {}).duplicate(true)
		view.formRules.msLinkTraits = traits.duplicate()
		view.formRules.msLinkProjectiles = int(view.get("msLinkProjectiles", 0))
		view.formRules.msLinkDraws = int(view.get("msLinkDraws", 0))
		view.formRules.combatKeywords = view.formRules.get("combatKeywords", []).duplicate()
		for keyword in traits:
			if keyword in ["crit", "lifesteal", "pierce"] and keyword not in view.formRules.combatKeywords: view.formRules.combatKeywords.append(keyword)
		if str(view.id) == "c24202":
			view.value = {"attack": 3 + int(view.get("msLinkPower", 0)), "hp": 5 + int(view.get("msLinkHp", 0)), "setBase": true}
			view.effects[0].value = view.value.duplicate(true)
	if not traits.is_empty() or int(view.get("msLinkPower", 0)) > 0 or int(view.get("msLinkProjectiles", 0)) > 0 or int(view.get("msLinkDraws", 0)) > 0:
		view.enhanced = true
		view.currentCardStats = "连引效果 · " + "/".join(PackedStringArray(traits.map(func(k): return str({"crit": "暴击", "lifesteal": "吸血", "pierce": "贯通", "swift": "迅捷", "instant": "瞬发"}.get(k, k)))))
		if int(view.get("msLinkPower", 0)) > 0: view.currentCardStats += " · %d/%d" % [int(view.value.attack), int(view.value.hp)]
		if int(view.get("msLinkProjectiles", 0)) > 0: view.currentCardStats += " · 使用投射2×%d" % int(view.msLinkProjectiles)
		if int(view.get("msLinkDraws", 0)) > 0: view.currentCardStats += " · 使用抽%d" % int(view.msLinkDraws)
	return view

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if "swift" in card.get("msLinkTraits", []): gs.player(owner).units[src].swift = true

static func pre_card_frames(gs, owner: int, src: int, card: Dictionary) -> void:
	var traits: Dictionary = gs.player(owner).units[src].get("formRules", {})
	var draws := int(card.get("msLinkDraws", 0)) + int(traits.get("msLinkDraws", 0))
	var projectiles := int(card.get("msLinkProjectiles", 0)) + int(traits.get("msLinkProjectiles", 0))
	if draws > 0: gs.resolution_stack.append({"kind": "ms-use-draw", "playerIndex": owner, "sourceIndex": src, "amount": draws, "card": card.duplicate(true)})
	for n in projectiles: gs.resolution_stack.append({"kind": "ms-use-projectile", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true)})

static func _damage_card(gs, owner: int, src: int) -> Dictionary:
	if owner < 0 or src < 0 or owner >= gs.players.size() or src >= gs.player(owner).units.size() or gs.get("_mirror_spell_overflow"): return {}
	var context: Dictionary = gs._card_effect_context
	if not context.is_empty() and int(context.get("playerIndex", -1)) == owner and int(context.get("sourceIndex", -1)) == src:
		return context.get("cardOverride", Content.card_def(str(context.get("definitionId", ""))))
	return {}

static func spell_critical(gs, owner: int, src: int, combat: bool, critical: bool) -> bool:
	if combat or gs.get("_mirror_spell_overflow"): return critical
	var card := _damage_card(gs, owner, src)
	if "crit" in card.get("msLinkTraits", []): return true
	return critical or (owner >= 0 and src >= 0 and active(gs.player(owner).units[src]) and "crit" in gs.player(owner).units[src].get("formRules", {}).get("msLinkTraits", []))

static func after_spell_unit(gs, owner: int, src: int, victim: int, idx: int, combat: bool, overflow: int, amount: int) -> void:
	if combat or gs.get("_mirror_spell_overflow") or owner < 0 or src < 0: return
	var card := _damage_card(gs, owner, src)
	var form_traits: Array = gs.player(owner).units[src].get("formRules", {}).get("msLinkTraits", [])
	if "lifesteal" in form_traits and not card.get("bloodSpellLifeSteal", false): gs.VerifiedRules.ArmorBlood.heal(gs, owner, amount)

static func spell_unit(gs, victim: int, idx: int, amount: int, owner: int, src: int, combat: bool, knockout_extra: int, transfer_pending: bool, critical: bool, shell_modified: bool):
	if combat or gs.get("_mirror_spell_overflow") or owner < 0 or src < 0 or amount < 0 or int(gs.player(victim).units[idx].hp) <= 0: return null
	var card := _damage_card(gs, owner, src)
	var form_traits: Array = gs.player(owner).units[src].get("formRules", {}).get("msLinkTraits", [])
	if "pierce" not in card.get("msLinkTraits", []) and "pierce" not in form_traits: return null
	if gs.VerifiedRules.FoxLotus.prevents_damage(gs, owner, src): return null
	var target: Dictionary = gs.player(victim).units[idx]
	var preview := amount
	if not shell_modified and not transfer_pending: preview = maxi(0, preview + gs.VerifiedRules.HandBlessing.damage_delta(gs, owner, src, false))
	if not shell_modified and not transfer_pending: preview += gs.VerifiedRules.Maple.damage_bonus(gs, owner, src, false)
	preview = gs.VerifiedRules.Bingyong.limit_damage(target, preview + int(target.armorBreak) + (1 if int(target.brittle) > 0 else 0))
	var armor := 0 if gs.VerifiedRules.Combat.has(gs.player(owner).units[src], "penetration") else int(target.shield)
	preview = maxi(0, preview - armor) * (2 if critical and owner != victim else 1)
	preview = gs.VerifiedRules.Jorogumo.received_damage(target, preview)
	preview = gs.VerifiedRules.Mianqiling.modify_damage(gs, victim, idx, preview, owner, src, false)
	preview = gs.VerifiedRules.OwlInsect.reduced(target, gs.VerifiedRules.MonkCleaner.reduced(target, preview))
	var overflow := maxi(0, preview - int(target.hp))
	if target.get("bloodTransfer", false) or gs.VerifiedRules.OniAsura.will_transfer(gs, target): overflow = 0
	gs._mirror_spell_overflow = true
	var result: Dictionary = gs._damage_unit(victim, idx, amount, owner, src, false, knockout_extra, transfer_pending, critical, shell_modified)
	if result.get("redirected", false): overflow = 0
	if "lifesteal" in form_traits and not card.get("bloodSpellLifeSteal", false): gs.VerifiedRules.ArmorBlood.heal(gs, owner, int(result.get("dealt", result.get("damage", 0))))
	if overflow > 0 and gs.winner < 0:
		# Ordinary unit damage already credits its overkill for lifesteal.
		# A barrier may prevent that unit packet while avatar overflow still deals
		# damage; recover only the portion not credited by the unit result.
		var credited_overflow := maxi(0, int(result.get("dealt", result.get("damage", 0))) - int(result.get("damage", 0)))
		var outer_context: Dictionary = gs._card_effect_context
		if not outer_context.is_empty():
			gs._card_effect_context = outer_context.duplicate(true)
			var overflow_card := card.duplicate(true)
			overflow_card.bloodSpellLifeSteal = false
			gs._card_effect_context.cardOverride = overflow_card
		var dealt: int = gs._damage_avatar(victim, overflow, owner, src, false, false, true)
		gs._card_effect_context = outer_context
		var extra_heal := maxi(0, dealt - credited_overflow)
		if extra_heal > 0 and gs.winner < 0 and (card.get("bloodSpellLifeSteal", false) or "lifesteal" in form_traits): gs.VerifiedRules.ArmorBlood.heal(gs, owner, extra_heal)
		gs.VerifiedRules.event(gs, "ms-spell-pierce", {"player": owner, "uid": gs.player(owner).units[src].uid, "victimPlayer": victim, "amount": dealt})
	gs._mirror_spell_overflow = false
	return result

static func after_spell_avatar(gs, owner: int, src: int, combat: bool, amount: int) -> void:
	if combat or gs.get("_mirror_spell_overflow") or owner < 0 or src < 0: return
	if "lifesteal" in gs.player(owner).units[src].get("formRules", {}).get("msLinkTraits", []) and not _damage_card(gs, owner, src).get("bloodSpellLifeSteal", false): gs.VerifiedRules.ArmorBlood.heal(gs, owner, amount)

static func targets(gs, owner: int, card: Dictionary):
	if not card.get("mirrorSongRules", false): return null
	var out: Array = []
	if card.id == "c24201":
		out = gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
		if not gs.VerifiedRules.PipeFox.avatar_veil(gs, 1 - owner): out.append("avatar-%d" % (1 - owner))
		return out
	if card.id in ["c24203", "c24401"]:
		return gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u) and (card.id != "c24401" or int(u.front) == 0) and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	if card.id == "c24405":
		var front: int = gs.front_index(1 - owner)
		if front < 0 or not gs.VerifiedRules.OwlInsect.shikigami(gs.player(1 - owner).units[front]): return []
		for side in [owner, 1 - owner]:
			for i in gs.player(side).units.size():
				var u: Dictionary = gs.player(side).units[i]
				if side == 1 - owner and i == front: continue
				if int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side == owner or not gs.VerifiedRules.Combat.has(u, "veil")): out.append(str(u.uid))
		return out
	return null

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.id in ["c24206", "c24402"]: return not gs.player(owner).units[gs._source_index(owner, card)].awakened
	if card.id == "c24405": return not targets(gs, owner, card).is_empty()
	return true

static func combat_prepare(gs, frame: Dictionary) -> void:
	if frame.options.get("combatCard", {}).get("id") != "c24203" or frame.options.get("msSwapReady", false): return
	var owner := int(frame.playerIndex); var victim := int(frame.options.get("combatVictim", 1 - owner))
	var a: Dictionary = gs.player(owner).units[int(frame.sourceIndex)]; var d: Dictionary = gs.player(victim).units[int(frame.defenderIndex)]
	frame.options.msSwapReady = true
	var combat_id := int(frame.combatId)
	frame.options.msSwapCombatId = combat_id
	var attack := int(a.attack); var counter := int(d.attack)
	for entry in [[a, counter - attack], [d, attack - counter]]:
		var unit: Dictionary = entry[0]; var delta := int(entry[1])
		if not unit.has("msSwapDeltas"): unit.msSwapDeltas = []
		unit.msSwapDeltas.append({"combatId": combat_id, "delta": delta})
		unit.temporaryAttack = int(unit.get("temporaryAttack", 0)) + delta
		gs._recalc(unit)
	frame.power = gs.VerifiedRules.Combat.power(gs, owner, a, int(frame.attackBaseBonus))
	frame.attackSnapshot = int(a.attack)
	if frame.options.get("lightZeroAttack", false): frame.power = 0
	gs.VerifiedRules.event(gs, "ms-power-swapped", {"player": owner, "uid": a.uid, "target": d.uid, "attack": counter, "counter": attack, "currentAttack": int(a.attack), "currentCounter": int(d.attack)})

static func _combat(gs, owner: int, src: int, card: Dictionary, target_id, extra: Dictionary = {}) -> void:
	var options: Dictionary = card.get("combatOption", {}).duplicate(true); options.merge(extra, true); options.combatCard = card.duplicate(true)
	gs._grant_unit_armor(gs.player(owner).units[src], int(options.get("shield", 0)))
	gs._record("assault", {"unit": src, "bonus": int(card.value), "target": target_id}, owner)
	gs._resolve_combat(owner, src, int(card.value), false, card.id == "c24401", false, false, target_id, false, options)

static func _forced(gs, owner: int, src: int, victim: int, target_id) -> void:
	if src < 0 or not active(gs.player(owner).units[src]) or not gs.VerifiedRules.OwlInsect.shikigami(gs.player(owner).units[src]) or gs.player(owner).units[src].get("cannotAttack", false): return
	gs._resolve_combat(owner, src, 0, false, false, false, false, target_id, false, {"combatVictim": victim, "pursuit": not str(target_id).begins_with("avatar-"), "directAvatar": str(target_id).begins_with("avatar-"), "msForced": true})

static func _beauty(gs, owner: int, src: int, card: Dictionary, combat_id: int = -1, attacker_uid: String = "") -> void:
	var enemy := 1 - owner
	var excluded := attacker_uid
	if excluded == "":
		var front: int = gs.front_index(enemy)
		if front >= 0: excluded = str(gs.player(enemy).units[front].uid)
	var ids: Array = gs.player(enemy).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and str(u.uid) != excluded and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	if ids.is_empty():
		if combat_id < 0: _combat(gs, owner, src, card, null)
		else: _beauty_response(gs, owner, src, combat_id, "")
		return
	gs.pending_choice = {"type": "ms-beauty", "playerIndex": owner, "sourceIndex": src, "combatId": combat_id, "card": card.duplicate(true), "instanceIds": ids, "heading": "绮 丽 · 承 伤", "hint": "选择另一个敌方式神，承受松本次战斗受到的战斗伤害。"}; gs.phase = "choice"

static func _beauty_response(gs, owner: int, src: int, combat_id: int, receiver: String) -> void:
	for frame in gs.resolution_stack:
		if int(frame.get("combatId", -2)) != combat_id: continue
		if gs.front_index(owner) != src: gs.VerifiedRules.Movement.move_to(gs, owner, src, 1)
		frame.defenderIndex = src
		frame.msBeautyDefender = true
		gs.player(owner).units[src].msBeautyReceiver = receiver
		frame.options.msBeautyUids = frame.options.get("msBeautyUids", []) + [str(gs.player(owner).units[src].uid)]
		return

static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type") != "ms-beauty" or int(gs.pending_choice.playerIndex) != owner: return null
	var unit: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, iid)
	if unit.is_empty(): return {}
	return {"id": iid, "unitId": str(unit.id), "name": str(unit.name), "type": "spell", "typeLabel": "选择承伤式神", "cost": 0, "level": int(unit.level), "text": "承受松本次战斗的战斗伤害。", "currentCardStats": "力量%d · 生命%d/%d · 护甲%d" % [int(unit.attack), int(unit.hp), int(unit.maxHp), int(unit.shield)]}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "ms-beauty" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	gs.pending_choice = {}; gs.phase = "main"
	if int(choice.combatId) >= 0: _beauty_response(gs, owner, int(choice.sourceIndex), int(choice.combatId), iid)
	else:
		gs.player(owner).units[int(choice.sourceIndex)].msBeautyReceiver = iid
		_combat(gs, owner, int(choice.sourceIndex), choice.card, null, {"msBeautyUids": [str(gs.player(owner).units[int(choice.sourceIndex)].uid)]})
	gs._record("resolve_divination_choice", {"choice": "ms-beauty", "instanceId": iid}, owner)
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true

static func redirect(gs, owner: int, idx: int, amount: int, source_owner: int, source_idx: int, combat: bool, critical: bool):
	if not combat or idx < 0 or gs.get("_mirror_redirecting"): return null
	var unit: Dictionary = gs.player(owner).units[idx]
	var receiver := str(unit.get("msBeautyReceiver", ""))
	var enemy := 1 - owner; var target: int = gs._unit_index_by_uid(enemy, receiver)
	if target < 0 or int(gs.player(enemy).units[target].hp) <= 0: return null
	var preview := maxi(0, amount + int(unit.get("armorBreak", 0)) - int(unit.get("shield", 0)))
	if critical and source_owner != owner: preview *= 2
	preview = gs.VerifiedRules.Jorogumo.received_damage(unit, preview)
	preview = gs.VerifiedRules.Mianqiling.modify_damage(gs, owner, idx, preview, source_owner, source_idx, true)
	preview = gs.VerifiedRules.OwlInsect.reduced(unit, gs.VerifiedRules.MonkCleaner.reduced(unit, preview))
	var capped := mini(int(unit.hp), preview)
	gs._mirror_redirecting = true
	var result: Dictionary = gs._damage_unit(enemy, target, capped, source_owner, source_idx, true, -1, false, false, true)
	gs._mirror_redirecting = false
	result = result.duplicate(true); result.msRedirected = true
	gs.VerifiedRules.event(gs, "ms-beauty-transfer", {"player": owner, "uid": unit.uid, "target": receiver, "amount": capped})
	return result

static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	for p in gs.players:
		for u in p.units:
			if str(u.uid) in options.get("msBeautyUids", []): u.erase("msBeautyReceiver")
			var matching: Array = u.get("msSwapDeltas", []).filter(func(e): return int(e.combatId) == int(options.get("msSwapCombatId", -1)))
			if matching.is_empty(): continue
			for entry in matching: u.temporaryAttack = int(u.get("temporaryAttack", 0)) - int(entry.delta)
			u.msSwapDeltas = u.msSwapDeltas.filter(func(e): return int(e.combatId) != int(options.msSwapCombatId))
			if u.msSwapDeltas.is_empty(): u.erase("msSwapDeltas")
			if int(u.get("temporaryAttack", 0)) == 0: u.erase("temporaryAttack")
			gs._recalc(u)

static func before_attack(gs, frame: Dictionary) -> bool:
	if frame.get("msPuppetOffered", false): return false
	frame.msPuppetOffered = true
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or not u.get("formRules", {}).get("songPuppet", false): return false
	var enemy := 1 - owner; var front: int = gs.front_index(enemy)
	if front < 0: return false
	gs.resolution_stack.append({"kind": "ms-attack-ready", "playerIndex": owner, "sourceIndex": src, "combat": frame.duplicate(true)})
	_forced(gs, enemy, front, enemy, "avatar-%d" % enemy)
	return true

static func turn_start(gs, turn_owner: int) -> void:
	for owner in 2:
		for realm in gs.player(owner).realms:
			if int(realm.hp) <= 0 or realm.get("nativeRealm") != "song-night": continue
			var src: int = gs._unit_index_by_uid(owner, str(realm.sourceUid))
			if src < 0: continue
			if owner == turn_owner: gs.resolution_stack.append({"kind": "ms-night-stun", "playerIndex": owner, "sourceIndex": src})
			else:
				for unit in gs.player(turn_owner).units:
					if int(unit.hp) > 0 and int(unit.frozen) > 0: gs.resolution_stack.append({"kind": "ms-night-damage", "playerIndex": owner, "sourceIndex": src, "victimPlayer": turn_owner, "targetUid": str(unit.uid)})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.get("action", "")):
		"ms-damage":
			if str(target_id) == "avatar-%d" % (1 - owner): gs._damage_avatar(1 - owner, 3 + int(gs.player(owner).units[src].get("spellPower", 0)), owner, src)
			else:
				var idx: int = gs._unit_index_by_uid(1 - owner, str(target_id))
				if idx >= 0: gs._damage_unit(1 - owner, idx, 3 + int(gs.player(owner).units[src].get("spellPower", 0)), owner, src)
		"ms-combat": _combat(gs, owner, src, card, target_id)
		"ms-projectile": gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 4 + int(gs.player(owner).units[src].get("spellPower", 0)), "昙无")
		"ms-area":
			gs.resolution_stack.append({"kind": "ms-area-avatar", "playerIndex": owner, "sourceIndex": src, "context": gs._card_effect_context.duplicate(true)})
			for unit in gs.player(1 - owner).units:
				if int(unit.hp) > 0: gs.resolution_stack.append({"kind": "ms-area-unit", "playerIndex": owner, "sourceIndex": src, "targetUid": str(unit.uid), "context": gs._card_effect_context.duplicate(true)})
		"ms-move-combat":
			var target: int = gs._unit_index_by_uid(1 - owner, str(target_id))
			if target >= 0:
				gs.resolution_stack.append({"kind": "ms-move-attack", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true), "targetId": target_id})
				gs.VerifiedRules.Movement.move_to(gs, 1 - owner, target, 1)
		"ms-divination":
			gs.resolution_stack.append({"kind": "ms-enemy-divine", "playerIndex": owner, "sourceIndex": src})
			gs.VerifiedRules.Divination.start(gs, owner, 1)
		"ms-beauty": _beauty(gs, owner, src, card)
		"ms-command":
			var attacker: int = gs.front_index(1 - owner)
			for victim in 2:
				if gs._unit_index_by_uid(victim, str(target_id)) >= 0: _forced(gs, 1 - owner, attacker, victim, target_id)
		"ms-night":
			gs._deploy_realm(owner, card)
			gs.player(owner).realms.back().sourceUid = str(gs.player(owner).units[src].uid)
			gs.resolution_stack.append({"kind": "ms-night-stun", "playerIndex": owner, "sourceIndex": src})
		_: return false
	return true

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary, attacker_uid: String) -> void:
	_beauty(gs, owner, src, card, combat_id, attacker_uid)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("ms-"): return false
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex)
	match kind:
		"ms-link-event":
			for uid in frame.sources:
				for target in gs.player(1 - owner).units:
					if int(target.hp) > 0: gs.resolution_stack.append({"kind": "ms-dream-hit", "playerIndex": owner, "sourceIndex": gs._unit_index_by_uid(owner, str(uid)), "targetUid": str(target.uid)})
		"ms-use-draw":
			gs._draw(owner, int(frame.amount))
		"ms-use-projectile":
			var old: Dictionary = gs._card_effect_context
			gs._card_effect_context = {"playerIndex": owner, "sourceIndex": src, "cardOverride": frame.card, "affectedUnits": []}
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2, "连引投射")
			gs._card_effect_context = old
		"ms-dream-hit":
			var target: int = gs._unit_index_by_uid(1 - owner, str(frame.targetUid))
			if src >= 0 and target >= 0: gs._damage_unit(1 - owner, target, 1, owner, src)
		"ms-area-unit", "ms-area-avatar":
			var old: Dictionary = gs._card_effect_context; gs._card_effect_context = frame.context
			var amount := 2 + int(gs.player(owner).units[src].get("spellPower", 0))
			if kind == "ms-area-avatar": gs._damage_avatar(1 - owner, amount, owner, src)
			else:
				var target: int = gs._unit_index_by_uid(1 - owner, str(frame.targetUid))
				if target >= 0: gs._damage_unit(1 - owner, target, amount, owner, src)
			gs._card_effect_context = old
		"ms-move-attack": _combat(gs, owner, src, frame.card, frame.targetId)
		"ms-enemy-divine": gs.VerifiedRules.Divination.start(gs, 1 - owner, 1, owner)
		"ms-attack-ready": gs._resolve_combat_ready(frame.combat)
		"ms-night-stun":
			var pool: Array = gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))
			if not pool.is_empty(): gs.VerifiedRules.Stun.apply(gs, 1 - owner, gs._unit_index_by_uid(1 - owner, str(pool[int(gs.next_random() % pool.size())].uid)), 1, owner)
		"ms-night-damage":
			var victim := int(frame.victimPlayer); var idx: int = gs._unit_index_by_uid(victim, str(frame.targetUid))
			if idx >= 0 and int(gs.player(victim).units[idx].hp) > 0 and int(gs.player(victim).units[idx].frozen) > 0:
				var power := int(gs.player(victim).units[idx].attack)
				var old: Dictionary = gs._card_effect_context; gs._card_effect_context = {}
				gs._damage_avatar(victim, power, victim, idx); gs._card_effect_context = old
	return true

static func marks(_gs, _owner: int, unit: Dictionary) -> Array:
	var out: Array = []
	if role(unit) == "mirror": out.append("同角色连引" + (" · 同名获得瞬发" if unit.awakened else ""))
	if role(unit) == "song": out.append("连引每个其他存活基础式神各一张" if unit.awakened else "连引己方战斗区其他式神")
	if unit.has("msBeautyReceiver"): out.append("绮丽 · 本次战斗伤害转移")
	return out

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "ms-beauty": return null
	if int(gs.pending_choice.playerIndex) != owner: return false
	var ids: Array = gs.pending_choice.instanceIds
	var best := str(ids[0]); var best_power := -999
	for id in ids:
		var u: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, str(id))
		var score := int(u.attack) * 2 - int(u.hp)
		if score > best_power: best_power = score; best = str(id)
	return resolve_choice(gs, owner, best)

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("mirrorSongRules", false): return null
	if card.id in ["c24206", "c24402"]: return 65
	if card.id == "c24405": return 50
	if card.id == "c24201": return 35 + maxi(0, int(gs.player(owner).maxAvatarHp) - int(gs.player(owner).avatarHp))
	return 45
