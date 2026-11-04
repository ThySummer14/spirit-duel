class_name GameAI
extends RefCounted
## Simple greedy scorer for the vertical slice AI opponent.

const ContentLoader := preload("res://scripts/content_loader.gd")


static func take_action(gs: GameState, p_idx: int) -> bool:
	## One command per presentation beat; take_turn remains the fast simulation API.
	if gs.action_player() != p_idx:
		return false
	if not gs.pending_choice.is_empty():
		return _resolve_choice(gs, p_idx)
	if not gs.response_window.is_empty():
		var actions: Array = []
		return _try_response(gs, p_idx, actions) or gs.pass_response(p_idx)
	if gs.is_upgrade_pending(p_idx):
		var unit := _best_level_up(gs, p_idx)
		return unit >= 0 and gs.level_up(p_idx, unit)
	for idx in gs.player(p_idx).units.size():
		if gs.VerifiedRules.Zhenjian.can_manual_release(gs,p_idx,idx) and gs.release_charge(p_idx,idx):return true
	var play := _best_card(gs, p_idx)
	if play.ok and gs.play_card(p_idx, play.hand, play.target, bool(play.get("origin", false))):
		return true
	var attack := _best_attack(gs, p_idx)
	if attack.ok and gs.basic_attack(p_idx, attack.unit, attack.target):
		return true
	return gs.end_turn(p_idx)


static func take_turn(gs: GameState, p_idx: int) -> Array:
	## Returns list of commands performed (already applied).
	var actions: Array = []
	if gs.winner >= 0:
		return actions
	# Only control this side. Human responses and choices must remain pending.
	var guard := 0
	while guard < 32 and gs.winner < 0 and gs.action_player() == p_idx:
		guard += 1
		if not gs.pending_choice.is_empty():
			if _resolve_choice(gs, p_idx):
				actions.append({"cmd": "divination-choice"})
				continue
			break
		if not gs.response_window.is_empty():
			if _try_response(gs, p_idx, actions):
				continue
			if gs.pass_response(p_idx):
				actions.append({"cmd": "pass_response", "player": p_idx})
				continue
			break
		if gs.is_upgrade_pending(p_idx):
			var uidx := _best_level_up(gs, p_idx)
			if uidx >= 0 and gs.level_up(p_idx, uidx):
				actions.append({"cmd": "level_up", "unit": uidx})
				continue
			break
		var released := false
		for idx in gs.player(p_idx).units.size():
			if gs.VerifiedRules.Zhenjian.can_manual_release(gs,p_idx,idx) and gs.release_charge(p_idx,idx):
				actions.append({"cmd":"release_charge", "unit":idx}); released=true; break
		if released: continue
		var play := _best_card(gs, p_idx)
		if play.ok:
			if gs.play_card(p_idx, play.hand, play.target, bool(play.get("origin", false))):
				actions.append({"cmd": "play_card", "hand": play.hand, "target": play.target, "card": play.card_id})
				continue
		var atk := _best_attack(gs, p_idx)
		if atk.ok:
			if gs.basic_attack(p_idx, atk.unit, atk.target):
				actions.append({"cmd": "basic_attack", "unit": atk.unit})
				continue
		break
	if gs.action_player() == p_idx and gs.pending_choice.is_empty() and gs.response_window.is_empty():
		if gs.end_turn(p_idx):
			actions.append({"cmd": "end_turn"})
	return actions


static func _best_level_up(gs: GameState, p_idx: int) -> int:
	var p := gs.player(p_idx)
	var best: int = -1
	var best_score: int = -999999
	for i in p.units.size():
		var u: Dictionary = p.units[i]
		if not gs.can_level_up(p_idx, i):
			continue
		var score: int = int(u.maxHp) * 2 + int(u.attack)
		if int(u.level) == 0:
			score += 40
		if int(u.hp) > 0:
			score += 8
		if score > best_score:
			best_score = score
			best = i
	return best


static func _best_card(gs: GameState, p_idx: int) -> Dictionary:
	gs.VerifiedRules.ChargedPair.ai_prepare(gs,p_idx)
	gs.VerifiedRules.Zhenjian.ai_prepare(gs,p_idx)
	gs.VerifiedRules.Whale.ai_prepare(gs,p_idx)
	gs.VerifiedRules.Movement.ai_prepare(gs, p_idx)
	var p := gs.player(p_idx)
	var best := {"ok": false, "hand": -1, "target": null, "score": -1, "card_id": ""}
	for h in gs.playable_card_count(p_idx):
		for origin in [false, true]:
			var card := gs.playable_card(p_idx, h, origin)
			if card.is_empty(): continue
			var targets: Array = [null] if card.get("target", "auto") == "auto" else gs.valid_targets(p_idx, card)
			for t in targets:
				var check2 := gs.can_play_card(p_idx, h, t, origin)
				if check2.ok:
					var score2: int = _score_card(gs, p_idx, card, t)
					if score2 > best.score:
						best = {"ok": true, "hand": h, "target": t, "score": score2, "card_id": card.get("id"), "origin": origin}
	return best


static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:
	var box_score=_gs.VerifiedRules.BoxMaiden.score_card(_gs,p_idx,card,_target)
	if box_score!=null:return int(box_score)
	var cook_score=_gs.VerifiedRules.Cooking.score_card(_gs,p_idx,card,_target)
	if cook_score!=null:return int(cook_score)
	var sc_score=_gs.VerifiedRules.SugarCat.score_card(_gs,p_idx,card,_target)
	if sc_score!=null:return int(sc_score)
	var rt_score=_gs.VerifiedRules.RabbitTide.score_card(_gs,p_idx,card,_target)
	if rt_score!=null:return int(rt_score)
	var ark_score=_gs.VerifiedRules.Arakawa.score_card(_gs,p_idx,card,_target)
	if ark_score!=null:return int(ark_score)
	var rw_score=_gs.VerifiedRules.RednightWalnut.score_card(_gs,p_idx,card,_target)
	if rw_score!=null:return int(rw_score)
	var ape_score=_gs.VerifiedRules.ApeSleeve.score_card(_gs,p_idx,card,_target)
	if ape_score!=null:return ape_score
	var zd_score=_gs.VerifiedRules.Zhenjian.score_card(_gs,p_idx,card,_target)
	if zd_score!=null:return int(zd_score)
	var charged_score=_gs.VerifiedRules.ChargedPair.score_card(_gs,p_idx,card,_target)
	if charged_score!=null:return int(charged_score)
	var rp_score=_gs.VerifiedRules.RedPurple.score_card(_gs,p_idx,card,_target)
	if rp_score!=null:return int(rp_score)
	var ms_score=_gs.VerifiedRules.MirrorSong.score_card(_gs,p_idx,card,_target)
	if ms_score!=null:return int(ms_score)
	var yi_score=_gs.VerifiedRules.Yi.score_card(_gs,p_idx,card,_target)
	if yi_score!=null:return int(yi_score)
	var futakuchi_score=_gs.VerifiedRules.Futakuchi.score_card(_gs,p_idx,card)
	if futakuchi_score!=null:return int(futakuchi_score)
	var bg_score=_gs.VerifiedRules.BlueGreen.score_card(_gs,p_idx,card,_target)
	if bg_score!=null:return int(bg_score)
	var mian_score=_gs.VerifiedRules.Mianqiling.score_card(_gs,p_idx,card,_target)
	if mian_score!=null:return int(mian_score)
	var black_white_score=_gs.VerifiedRules.BlackWhite.score_card(_gs,p_idx,card,_target)
	if black_white_score!=null:return int(black_white_score)
	var two_faces_score=_gs.VerifiedRules.TwoFaces.score_card(_gs,p_idx,card,_target)
	if two_faces_score!=null:return int(two_faces_score)
	var lantern_score=_gs.VerifiedRules.Lantern.score_card(_gs,p_idx,card)
	if lantern_score!=null:return int(lantern_score)
	var sea_score=_gs.VerifiedRules.SeaButterfly.score_card(_gs,p_idx,card,_target)
	if sea_score!=null:return int(sea_score)
	var silk_score=_gs.VerifiedRules.SilkNinja.score_card(_gs,p_idx,card,_target)
	if silk_score!=null:return int(silk_score)
	var toxic_score=_gs.VerifiedRules.Toxic.score_card(_gs,p_idx,card,_target)
	if toxic_score!=null: return int(toxic_score)
	var lily_score = _gs.VerifiedRules.SpiderLily.score_card(_gs,p_idx,card,_target)
	if lily_score != null: return int(lily_score)
	var pair_score = _gs.VerifiedRules.KoiFragrance.score_card(_gs,p_idx,card,_target)
	if pair_score != null: return int(pair_score)
	var susanoo_score = _gs.VerifiedRules.Susanoo.score_card(_gs,p_idx,card,_target)
	if susanoo_score != null: return int(susanoo_score)
	var baize_score = _gs.VerifiedRules.Baize.score_card(_gs,p_idx,card,_target)
	if baize_score != null: return int(baize_score)
	var croc_score = _gs.VerifiedRules.Crocodile.score_card(_gs,p_idx,card,_target)
	if croc_score != null: return int(croc_score)
	var whale_score = _gs.VerifiedRules.Whale.score_card(_gs,p_idx,card,_target)
	if whale_score != null: return int(whale_score)
	var jorogumo_score = _gs.VerifiedRules.Jorogumo.score_card(_gs,p_idx,card,_target)
	if jorogumo_score != null: return int(jorogumo_score)
	var yitiao_score = _gs.VerifiedRules.Yitiao.score_card(_gs,p_idx,card,_target)
	if yitiao_score != null: return int(yitiao_score)
	var garuda_score = _gs.VerifiedRules.Garuda.score_card(_gs,p_idx,card,_target)
	if garuda_score != null: return int(garuda_score)
	var butterfly_score = _gs.VerifiedRules.Butterfly.score_card(_gs,p_idx,card,_target)
	if butterfly_score != null: return int(butterfly_score)
	var cotton_score = _gs.VerifiedRules.Cotton.score_card(_gs,p_idx,card,_target)
	if cotton_score != null: return int(cotton_score)
	for native_score in [_gs.VerifiedRules.ThreeTail.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Glutton.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Doll.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Onikiri.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Otakemaru.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.House.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Goldfish.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Vine.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.WindRaccoon.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Puppet.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Enma.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Weaver.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Sparrow.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Headless.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Yaksha.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.StarBear.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Pine.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Paint.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Samurai.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Mountain.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Maple.score_card(_gs,p_idx,card,_target)]:
		if native_score!=null: return int(native_score)
	var raccoon_score = _gs.VerifiedRules.Raccoon.score_card(_gs,p_idx,card,_target)
	if raccoon_score != null: return int(raccoon_score)
	var fox_lotus_score=_gs.VerifiedRules.FoxLotus.score_card(_gs,p_idx,card,_target)
	if fox_lotus_score!=null: return int(fox_lotus_score)
	var rebirth_score=_gs.VerifiedRules.Rebirth.score_card(_gs,p_idx,card)
	if rebirth_score!=null: return int(rebirth_score)
	var oni_score=_gs.VerifiedRules.OniAsura.score_card(_gs,p_idx,card)
	if oni_score!=null: return int(oni_score)
	var pipe_score=_gs.VerifiedRules.PipeFox.score_card(_gs,p_idx,card,_target)
	if pipe_score!=null: return int(pipe_score)
	for score in [_gs.VerifiedRules.Moon.score_card(_gs,p_idx,card,_target),_gs.VerifiedRules.Bamboo.score_card(_gs,p_idx,card)]:
		if score != null: return int(score)
	var charm_score_native = _gs.VerifiedRules.OwlInsect.score_card(_gs,p_idx,card,_target)
	if charm_score_native != null: return int(charm_score_native)
	var tree_score = _gs.VerifiedRules.TreeSakura.score_card(_gs, p_idx, card, _target)
	if tree_score != null: return int(tree_score)
	var shell_score = _gs.VerifiedRules.MonkCleaner.score_card(_gs, p_idx, card, _target)
	if shell_score != null: return int(shell_score)
	var charm_score = _gs.VerifiedRules.BondDream.score_card(_gs, p_idx, card)
	if charm_score != null: return int(charm_score)
	for result in [_gs.VerifiedRules.Eye.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Crab.score_card(_gs, p_idx, card, _target)]:
		if result != null: return int(result)
	for score in [_gs.VerifiedRules.Wind.score_card(_gs, p_idx, card), _gs.VerifiedRules.Night.score_card(_gs, p_idx, card), _gs.VerifiedRules.Mask.score_card(_gs, p_idx, card)]:
		if score != null: return int(score)
	var river_score = _gs.VerifiedRules.River.score_card(_gs, p_idx, card, _target)
	if river_score != null: return int(river_score)
	var coin_score = _gs.VerifiedRules.IronMouse.score_card(_gs, p_idx, card)
	if coin_score != null: return int(coin_score)
	var blessing_score = _gs.VerifiedRules.UpgradeBlessing.score_card(_gs, p_idx, card, _target)
	if blessing_score != null: return int(blessing_score)
	if card.get("upgradeBlessingCard", false):
		var unit: Dictionary = _gs._unit_by_uid(_gs.player(p_idx).units, _target)
		return 42 + (20 if int(unit.get("level", 3)) < 3 else 0) + int(unit.get("attack", 0))
	if card.get("inspiredSupport", false):
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		return -100 if source.awakened else 65
	var mengpo_score = _gs.VerifiedRules.Mengpo.score_card(_gs, p_idx, card, _target)
	if mengpo_score != null: return int(mengpo_score)
	var huang_score = _gs.VerifiedRules.Huang.score_card(_gs, p_idx, card, _target)
	if huang_score != null: return int(huang_score)
	var armor_blood_score = _gs.VerifiedRules.ArmorBlood.score_card(_gs, p_idx, card, _target)
	if armor_blood_score != null: return int(armor_blood_score)
	var tomato_fire_score = _gs.VerifiedRules.TomatoFire.score_card(_gs, p_idx, card, _target)
	if tomato_fire_score != null: return int(tomato_fire_score)
	var movement_score = _gs.VerifiedRules.Movement.score_card(_gs, p_idx, card, _target)
	if movement_score != null: return int(movement_score)
	var sun_smoke_score = _gs.VerifiedRules.SunSmoke.score_card(_gs, p_idx, card, _target)
	if sun_smoke_score != null: return int(sun_smoke_score)
	var fox_suzuka_score = _gs.VerifiedRules.FoxSuzuka.score_card(_gs, p_idx, card, _target)
	if fox_suzuka_score != null: return int(fox_suzuka_score)
	var fortune_score = _gs.VerifiedRules.Fortune.score_card(_gs, p_idx, card, _target)
	if fortune_score != null: return int(fortune_score)
	var book_jue_score = _gs.VerifiedRules.BookJue.score_card(_gs, p_idx, card, _target)
	if book_jue_score != null: return int(book_jue_score)
	var poison_score = _gs.VerifiedRules.Poison.score_card(_gs, p_idx, card, _target)
	if poison_score != null: return int(poison_score)
	var light_score = _gs.VerifiedRules.Light.score_card(_gs, p_idx, card, _target)
	if light_score != null: return int(light_score)
	var dog_demon = _gs.VerifiedRules.DogDemon.score_card(_gs, p_idx, card, _target)
	if dog_demon != null: return dog_demon
	var snow_woman = _gs.VerifiedRules.Xuenv.score_card(_gs, p_idx, card, _target)
	if snow_woman != null: return int(snow_woman)
	var feather = _gs.VerifiedRules.Yijin.score_card(_gs, p_idx, card)
	if feather != null: return int(feather)
	var snow_crane = _gs.VerifiedRules.SnowCrane.score_card(_gs, p_idx, card, _target)
	if snow_crane != null: return int(snow_crane)
	for score in [_gs.VerifiedRules.Panguan.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Tide.score_card(_gs, p_idx, card, _target)]:
		if score != null: return int(score)
	for native_score in [_gs.VerifiedRules.Bailang.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Shantong.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Phoenix.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Peach.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Firefly.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Yaodao.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Shuten.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Bingyong.score_card(_gs, p_idx, card, _target)]:
		if native_score != null: return int(native_score)
	# Keep automatic counters in hand with the remaining fire; spending them in
	# the main phase without an opposing response has no benefit.
	if card.has("autoResponse") and not card.get("responseModifiesCombat", false): return -100
	var score: int = 0
	var action: String = str(card.get("effect", ""))
	var effects: Array = card.get("effects", []) if card.get("effects") is Array else []
	if not effects.is_empty():
		action = str(effects[0].get("action", action))
	match action:
		"assault", "damage", "burn-all", "brittle", "projectile-displace", "projectile-draw-on-kill", "random-damage":
			score = 50 + _num(card.get("value"))
		"heal", "shield", "fortify", "grant-unyielding", "revive":
			score = 40 + _num(card.get("value"))
		"draw", "draw-heal", "chain-draw", "focus-draw":
			score = 35
		"form", "awaken":
			score = 45
		"realm":
			score = 30
		"freeze", "apply-brittle":
			score = 42
		_:
			score = 20
	# prefer cheaper
	if action == "projectile-draw-on-kill":
		var front := _gs.front_unit(1 - p_idx)
		if not front.is_empty() and int(front.hp) + int(front.shield) <= _num(card.value): score += 30
	if card.get("combatOption", {}).get("pursuit", false):
		var target := _gs._unit_by_uid(_gs.player(1 - p_idx).units, _target)
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		if not target.is_empty():
			if int(target.hp) + int(target.shield) <= int(source.attack) + _num(card.value): score += 25
			score -= int(target.attack)
	if action == "move-unit":
		var target := _gs._unit_by_uid(_gs.player(p_idx).units, _target)
		if not target.is_empty():
			if int(target.get("spellCountdown", {}).get("remaining", 0)) == 1: score += 30
			if int(target.front) == 1 and int(target.hp) <= 3: score += 12
	if action == "countdown-change":
		var target := _gs._unit_by_uid(_gs._all_units(), _target)
		if effects[0].get("target") == "source": target = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		if not target.is_empty():
			var own := _gs._unit_index_by_uid(p_idx, target.uid) >= 0
			var delta := int(effects[0].value)
			if not _gs.VerifiedRules.has_countdown(target): score = -100
			elif (delta < 0) == own:
				var remaining := int(target.knockout) if int(target.hp) <= 0 else int(_gs.VerifiedRules.Countdown.timer(target).remaining)
				score = 60 + (30 if delta < 0 and remaining <= -delta else 0)
			else: score = -100
	if card.get("dynamicCountdownHistory", false):
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = -100 if source.get("abilityHistory", []).is_empty() else 40 + source.abilityHistory.size() * 15
	if action == "destroy-enemy-units":
		var living: int = _gs.player(1 - p_idx).units.filter(func(u): return int(u.hp) > 0).size()
		score = 70 + living * 15 if living > 0 else -100
	elif action == "generate-own-spell":
		score = 38 if _gs.player(p_idx).hand.size() < int(_gs.rules.maxHandSize) else -100
	elif action == "awaken-spell-replay":
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = 45 + (25 if int(source.get("spellCountdown", {}).get("remaining", 0)) == 1 else 0)
	if action == "destroy-own-form":
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = 32 if _gs.player(p_idx).hand.size() < int(_gs.rules.maxHandSize) - 1 else -100
		if not source.get("formCountdown", {}).is_empty(): score += 20
	elif action == "awaken-form-lifecycle":
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = 55 if not source.awakened else 25
	var combat: Dictionary = card.get("combatOption", {})
	if not combat.is_empty():
		var foe := _gs.front_unit(1 - p_idx)
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		var marked := int(foe.get("armorBreak", 0)) > 0 if not foe.is_empty() else int(_gs.player(1 - p_idx).get("avatarArmorBreak", 0)) > 0
		if marked and combat.get("immuneAgainstArmorBreak", false): score += 25
		if marked and combat.get("lifeStealAgainstArmorBreak", false): score += 25 + mini(20, int(_gs.player(p_idx).maxAvatarHp) - int(_gs.player(p_idx).avatarHp))
		if combat.get("convertCombatToArmorBreak", false):
			# Keep the response unless a real follow-up can detonate the poison,
			# or the current form converts it directly to damage.
			var can_follow: bool = int(_gs.player(p_idx).energy) > int(card.cost) and not _gs.player(p_idx).attackUsed
			if source.get("formRules", {}).get("armorBreakToDamage", false): score = 70
			else: score = 58 if can_follow else -100
	if card.get("dynamicPoisonHistory", false):
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score += 20 if not source.awakened else 0
	score -= int(card.get("cost", 0)) * 3
	return score


static func _best_attack(gs: GameState, p_idx: int) -> Dictionary:
	var p := gs.player(p_idx)
	var best := {"ok": false, "unit": -1, "score": -1, "target": null}
	var enemy := gs.enemy_index(p_idx)
	for i in p.units.size():
		if not gs.can_basic_attack(p_idx, i).ok: continue
		var unit: Dictionary = p.units[i]
		for target in gs.basic_attack_targets(p_idx, i):
			var skill := gs.VerifiedRules.BattleSkill.ready(gs,p_idx,i)
			if not skill.is_empty():
				var skill_score := _score_card(gs,p_idx,skill,target)
				var garuda_attack_score = gs.VerifiedRules.Garuda.attack_score(gs,p_idx,i,skill,target)
				if garuda_attack_score != null: skill_score = int(garuda_attack_score)
				var yitiao_attack_score = gs.VerifiedRules.Yitiao.attack_score(gs,p_idx,i,skill,target)
				if yitiao_attack_score != null: skill_score = int(yitiao_attack_score)
				if skill_score > best.score: best = {"ok":true,"unit":i,"score":skill_score,"target":target}
				continue
			var yitiao_normal_score = gs.VerifiedRules.Yitiao.attack_score(gs,p_idx,i,{},target)
			if yitiao_normal_score != null:
				if int(yitiao_normal_score)>int(best.score): best = {"ok":true,"unit":i,"score":int(yitiao_normal_score),"target":target}
				continue
			var special = gs.VerifiedRules.TreeSakura.attack_score(gs,p_idx,i,target)
			if special != null:
				if int(special)>int(best.score): best = {"ok":true,"unit":i,"score":int(special),"target":target}
				continue
			var idx := gs._unit_index_by_uid(enemy, str(target))
			var power := gs.VerifiedRules.Combat.power(gs,p_idx,unit)
			if power > 0: power += gs.VerifiedRules.ArmorBreak.amount(gs, enemy, idx)
			var score := power * 10 + (5 if int(unit.front) == 1 else 0)
			if idx < 0: score += 80
			elif power >= int(gs.player(enemy).units[idx].hp) + int(gs.player(enemy).units[idx].shield): score += 40
			if score > best.score: best = {"ok": true, "unit": i, "score": score, "target": target}
	return best


static func _num(v) -> int:
	if v is int or v is float:
		return int(v)
	if v is Dictionary:
		return 1
	return 0


static func _resolve_choice(gs: GameState, p_idx: int) -> bool:
	var sc_choice=gs.VerifiedRules.SugarCat.ai_choice(gs,p_idx)
	if sc_choice!=null:return bool(sc_choice)
	var rw_choice=gs.VerifiedRules.RednightWalnut.ai_choice(gs,p_idx)
	if rw_choice!=null:return bool(rw_choice)
	var ape_choice=gs.VerifiedRules.ApeSleeve.ai_choice(gs,p_idx)
	if ape_choice!=null:return ape_choice
	var zd_choice=gs.VerifiedRules.Zhenjian.ai_choice(gs,p_idx)
	if zd_choice!=null:return bool(zd_choice)
	var charged_choice=gs.VerifiedRules.ChargedPair.ai_choice(gs,p_idx)
	if charged_choice!=null:return bool(charged_choice)
	var rp_choice=gs.VerifiedRules.RedPurple.ai_choice(gs,p_idx)
	if rp_choice!=null:return bool(rp_choice)
	var ms_choice=gs.VerifiedRules.MirrorSong.ai_choice(gs,p_idx)
	if ms_choice!=null:return bool(ms_choice)
	var yi_choice=gs.VerifiedRules.Yi.ai_choice(gs,p_idx)
	if yi_choice!=null:return bool(yi_choice)
	var mian_choice=gs.VerifiedRules.Mianqiling.ai_choice(gs,p_idx)
	if mian_choice!=null:return bool(mian_choice)
	var link_choice=gs.VerifiedRules.Link.ai_choice(gs,p_idx)
	if link_choice!=null:return bool(link_choice)
	var black_white_choice=gs.VerifiedRules.BlackWhite.ai_choice(gs,p_idx)
	if black_white_choice!=null:return bool(black_white_choice)
	var box_choice=gs.VerifiedRules.BoxMaiden.ai_choice(gs,p_idx)
	if box_choice!=null:return bool(box_choice)
	var hand_choice=gs.VerifiedRules.HandBlessing.ai_choice(gs,p_idx)
	if hand_choice!=null: return bool(hand_choice)
	var yitiao_choice=gs.VerifiedRules.Yitiao.ai_choice(gs,p_idx)
	if yitiao_choice!=null: return bool(yitiao_choice)
	var glutton_choice=gs.VerifiedRules.Glutton.ai_choice(gs,p_idx)
	if glutton_choice!=null: return glutton_choice
	var three_tail_choice=gs.VerifiedRules.ThreeTail.ai_choice(gs,p_idx)
	if three_tail_choice!=null: return three_tail_choice
	var onikiri_choice=gs.VerifiedRules.Onikiri.ai_choice(gs,p_idx)
	if onikiri_choice!=null: return onikiri_choice
	var house_choice=gs.VerifiedRules.House.ai_choice(gs,p_idx)
	if house_choice!=null: return house_choice
	var goldfish_choice=gs.VerifiedRules.Goldfish.ai_choice(gs,p_idx)
	if goldfish_choice!=null: return goldfish_choice
	var mountain_choice=gs.VerifiedRules.Mountain.ai_choice(gs,p_idx)
	if mountain_choice!=null: return bool(mountain_choice)
	if gs.pending_choice.get("type")=="moon-hand-top": return gs.VerifiedRules.Moon.ai_choice(gs,p_idx)
	if gs.pending_choice.get("type")=="bamboo-deck": return gs.VerifiedRules.Bamboo.ai_choice(gs,p_idx)
	var eye_choice = gs.VerifiedRules.Eye.ai_choice(gs, p_idx)
	if eye_choice != null: return bool(eye_choice)
	var crab_choice = gs.VerifiedRules.Crab.ai_choice(gs, p_idx)
	if crab_choice != null: return bool(crab_choice)
	var night_choice = gs.VerifiedRules.Night.ai_choice(gs, p_idx)
	if night_choice != null: return bool(night_choice)
	var mask_choice = gs.VerifiedRules.Mask.ai_choice(gs, p_idx)
	if mask_choice != null: return bool(mask_choice)
	var mengpo_choice = gs.VerifiedRules.Mengpo.ai_choice(gs, p_idx)
	if mengpo_choice != null: return bool(mengpo_choice)
	var huang_choice = gs.VerifiedRules.Huang.ai_choice(gs, p_idx)
	if huang_choice != null: return bool(huang_choice)
	if gs.pending_choice.get("type") == "whale-awaken": return gs.VerifiedRules.Whale.ai_choice(gs,p_idx)
	if gs.pending_choice.get("type") == "movement-burst": return gs.VerifiedRules.Movement.ai_choice(gs, p_idx)
	var sun_smoke_choice = gs.VerifiedRules.SunSmoke.ai_choice(gs, p_idx)
	if sun_smoke_choice != null: return bool(sun_smoke_choice)
	var book_jue_choice = gs.VerifiedRules.BookJue.ai_choice(gs, p_idx)
	if book_jue_choice != null: return bool(book_jue_choice)
	var divination_choice = gs.VerifiedRules.Divination.ai_choice(gs, p_idx)
	if divination_choice != null: return bool(divination_choice)
	var ids: Array = gs.pending_choice.get("instanceIds", [])
	if ids.is_empty():
		return false
	# 优先选费用/等级更高、或名字非衍生的展示牌；这里取最后一张（更接近牌库顶）
	return gs.resolve_divination_choice(p_idx, str(ids[ids.size() - 1]))


static func _try_response(gs: GameState, p_idx: int, actions: Array) -> bool:
	if gs.response_window.is_empty() or int(gs.response_window.get("playerIndex", -1)) != p_idx:
		return false
	var p := gs.player(p_idx)
	for h in gs.playable_card_count(p_idx):
		var card := gs.hand_card_def(p_idx, h)
		if not gs.card_matches_response_window(card):
			continue
		var targets: Array = [null]
		if card.get("target", "auto") != "auto":
			targets = gs.valid_targets(p_idx, card)
		for t in targets:
			if gs.play_card(p_idx, h, t):
				actions.append({"cmd": "play_card", "hand": h, "target": t, "card": card.get("id")})
				return true
	return false
