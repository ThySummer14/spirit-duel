class_name VerifiedCardRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")
const Countdown := preload("res://scripts/countdown_rules.gd")
const Forms := preload("res://scripts/form_countdown_rules.gd")
const SpellReplay := preload("res://scripts/spell_replay_rules.gd")
const ArmorBreak := preload("res://scripts/armor_break_rules.gd")
const Poison := preload("res://scripts/poison_rules.gd")
const TomatoFire := preload("res://scripts/tomato_fire_rules.gd")
const Phoenix := preload("res://scripts/phoenix_rules.gd")
const Peach := preload("res://scripts/peach_rules.gd")
const Firefly := preload("res://scripts/firefly_rules.gd")
const Yaodao := preload("res://scripts/yaodao_rules.gd")
const Shuten := preload("res://scripts/shuten_rules.gd")
const Bingyong := preload("res://scripts/bingyong_rules.gd")
const Combat := preload("res://scripts/combat_keyword_rules.gd")
const Bailang := preload("res://scripts/bailang_rules.gd")
const Shantong := preload("res://scripts/shantong_rules.gd")
const Panguan := preload("res://scripts/panguan_rules.gd")
const Xuenv := preload("res://scripts/xuenv_rules.gd")
const Samurai := preload("res://scripts/samurai_rules.gd")
const Mountain := preload("res://scripts/mountain_realm_rules.gd")
const Maple := preload("res://scripts/maple_rules.gd")
const Paint := preload("res://scripts/paint_rules.gd")
const Pine := preload("res://scripts/pine_rules.gd")
const StarBear := preload("res://scripts/star_bear_rules.gd")
const Sparrow := preload("res://scripts/sparrow_rules.gd")
const Headless := preload("res://scripts/headless_rules.gd")
const Yaksha := preload("res://scripts/yaksha_rules.gd")
const Puppet := preload("res://scripts/puppet_rules.gd")
const Enma := preload("res://scripts/enma_rules.gd")
const Weaver := preload("res://scripts/weaver_rules.gd")
const Goldfish := preload("res://scripts/goldfish_rules.gd")
const Vine := preload("res://scripts/vine_rules.gd")
const WindRaccoon := preload("res://scripts/wind_raccoon_rules.gd")
const HandBlessing := preload("res://scripts/hand_blessing_rules.gd")
const Focus := preload("res://scripts/focus_rules.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const BlueGreen := preload("res://scripts/blue_green_rules.gd")
const Mianqiling := preload("res://scripts/mianqiling_rules.gd")
const Futakuchi := preload("res://scripts/futakuchi_rules.gd")
const BoxMaiden := preload("res://scripts/box_maiden_rules.gd")
const Yujiazhu := preload("res://scripts/yujiazhu_rules.gd")
const BlackWhite := preload("res://scripts/black_white_rules.gd")
const Link := preload("res://scripts/link_rules.gd")
const MirrorSong := preload("res://scripts/mirror_song_rules.gd")
const RedPurple := preload("res://scripts/red_purple_rules.gd")
const RednightWalnut := preload("res://scripts/rednight_walnut_rules.gd")
const Cooking := preload("res://scripts/cooking_rules.gd")
const Arakawa := preload("res://scripts/arakawa_rules.gd")
const Zhenjian := preload("res://scripts/zhenjian_duel_rules.gd")
const ChargedPair := preload("res://scripts/charged_pair_rules.gd")
const ApeSleeve := preload("res://scripts/ape_sleeve_rules.gd")
const Yi := preload("res://scripts/yi_rules.gd")
const TwoFaces := preload("res://scripts/two_faces_rules.gd")
const Lantern := preload("res://scripts/lantern_rules.gd")
const SeaButterfly := preload("res://scripts/sea_butterfly_rules.gd")
const SilkNinja := preload("res://scripts/silk_ninja_rules.gd")
const Toxic := preload("res://scripts/toxic_rules.gd")
const KoiFragrance := preload("res://scripts/koi_fragrance_rules.gd")
const Susanoo := preload("res://scripts/susanoo_rules.gd")
const Baize := preload("res://scripts/baize_rules.gd")
const Crocodile := preload("res://scripts/crocodile_rules.gd")
const Whale := preload("res://scripts/whale_rules.gd")
const Jorogumo := preload("res://scripts/jorogumo_rules.gd")
const Yitiao := preload("res://scripts/yitiao_rules.gd")
const Garuda := preload("res://scripts/garuda_rules.gd")
const BattleSkill := preload("res://scripts/battle_skill_rules.gd")
const Butterfly := preload("res://scripts/butterfly_rules.gd")
const Cotton := preload("res://scripts/cotton_rules.gd")
const SpiderLily := preload("res://scripts/spider_lily_rules.gd")
const ThreeTail := preload("res://scripts/three_tail_rules.gd")
const Glutton := preload("res://scripts/glutton_rules.gd")
const Doll := preload("res://scripts/doll_rules.gd")
const Onikiri := preload("res://scripts/onikiri_rules.gd")
const Otakemaru := preload("res://scripts/otakemaru_rules.gd")
const House := preload("res://scripts/house_rules.gd")
const Raccoon := preload("res://scripts/raccoon_rules.gd")
const Stun := preload("res://scripts/stun_rules.gd")
const Yijin := preload("res://scripts/yijin_rules.gd")
const SnowCrane := preload("res://scripts/snow_crane_rules.gd")
const Tide := preload("res://scripts/haifangzhu_rules.gd")
const Light := preload("res://scripts/light_healer_rules.gd")
const Fortune := preload("res://scripts/fortune_pair_rules.gd")
const Movement := preload("res://scripts/movement_rules.gd")
const DogDemon := preload("res://scripts/dog_demon_rules.gd")
const BookJue := preload("res://scripts/book_jue_rules.gd")
const SunSmoke := preload("res://scripts/sun_smoke_rules.gd")
const FoxSuzuka := preload("res://scripts/fox_suzuka_rules.gd")
const ArmorBlood := preload("res://scripts/armor_blood_rules.gd")
const Huang := preload("res://scripts/huang_rules.gd")
const Mengpo := preload("res://scripts/mengpo_rules.gd")
const UpgradeBlessing := preload("res://scripts/upgrade_blessing_rules.gd")
const IronMouse := preload("res://scripts/iron_mouse_rules.gd")
const River := preload("res://scripts/river_rules.gd")
const Divination := preload("res://scripts/native_divination_rules.gd")
const Wind := preload("res://scripts/wind_rules.gd")
const Night := preload("res://scripts/night_realm_rules.gd")
const Mask := preload("res://scripts/mask_rules.gd")
const Eye := preload("res://scripts/eye_rules.gd")
const Crab := preload("res://scripts/crab_rules.gd")
const BondDream := preload("res://scripts/bond_dream_rules.gd")
const Incarnation := preload("res://scripts/incarnation_rules.gd")
const FoxLotus := preload("res://scripts/fox_lotus_rules.gd")
const Rebirth := preload("res://scripts/rebirth_rules.gd")
const OniAsura := preload("res://scripts/oni_asura_rules.gd")
const PipeFox := preload("res://scripts/pipe_fox_rules.gd")
const Moon := preload("res://scripts/moon_rules.gd")
const Bamboo := preload("res://scripts/bamboo_rules.gd")
const OwlInsect := preload("res://scripts/owl_insect_rules.gd")
const TreeSakura := preload("res://scripts/tree_sakura_rules.gd")
const MonkCleaner := preload("res://scripts/monk_cleaner_rules.gd")
const SugarCat := preload("res://scripts/sugar_cat_rules.gd")
const RabbitTide := preload("res://scripts/rabbit_tide_rules.gd")
## Data-driven native rules verified against the reference recording/card sources.
## No card or character IDs in the executor; all capabilities live in content.

static func event(gs, kind: String, details: Dictionary) -> void:
	SugarCat.rule_event(gs,kind,details)
	RabbitTide.rule_event(gs,kind,details)
	RednightWalnut.rule_event(gs,kind,details)
	Zhenjian.rule_event(gs,kind,details)
	if kind in ["summon-removed","unit-removed"]: Crocodile.removed(gs,details)
	if kind == "realm-durability": SpiderLily.realm_lost(gs, details)
	BlueGreen.rule_event(gs, kind, details)
	SunSmoke.rule_event(gs, kind, details)
	var entry := details.duplicate(true)
	entry.kind = kind
	entry.id = gs.next_rule_event_id
	entry.commandIndex = gs.command_log.size()
	gs.next_rule_event_id += 1
	gs.rule_events.append(entry)
	if gs.rule_events.size() > 128: gs.rule_events.pop_front()

static func card_announced(gs, p_idx: int, src: int, card: Dictionary) -> void:
	RabbitTide.card_announced(gs,p_idx,src,card)
	Enma.card_announced(gs,p_idx,src,card)
	StarBear.card_announced(gs,p_idx,src,card)
	Huang.announced(gs, p_idx, card)
	Movement.announced(gs, p_idx, src)
	Yijin.announced(gs, p_idx, src, card)
	Firefly.card_announced(gs, p_idx, src, card)
	DogDemon.card_announced(gs, p_idx, src, card)
	var unit: Dictionary = gs.player(p_idx).units[src]
	var cfg: Dictionary = ContentLoader.runtime_unit_def(unit).get("spellCountdown", {})
	# This 'when used' ability still attaches when the combat card is nullified.
	if card.get("type") == cfg.get("on", "") and card.get("originCard") is Dictionary:
		var count := int(cfg.get("awakenedTurns", 1) if unit.awakened else cfg.get("turns", 2))
		unit.spellCountdown = {"remaining": count, "reset": count, "card": card.originCard.duplicate(true), "persistKnockout": bool(cfg.get("persistKnockout", false))}
		gs._log("%s 倒计时%d：%s。" % [unit.name, count, card.originCard.name], gs.TONE_CARD)
		event(gs, "countdown-set", {"uid": unit.uid, "remaining": count, "player": p_idx})

static func card_started(gs, p_idx: int, src: int, card: Dictionary, automatic: bool) -> void:
	HandBlessing.started(gs,p_idx,src,card)
	ArmorBlood.card_started(gs, p_idx, card)
	Light.card_started(gs, p_idx, card)
	var unit: Dictionary = gs.player(p_idx).units[src]
	var form: Dictionary = unit.get("formRules", {}) if int(unit.hp) > 0 else {}
	if ContentLoader.is_spell(card) and form.get("barrierOnSpell", false):
		unit.barrier = true
		gs._log("%s 获得屏障。" % unit.name, gs.TONE_SUCCESS)
		event(gs, "barrier-gained", {"uid": unit.uid, "player": p_idx})
	if card.get("type") == "combat" and int(form.get("countdownOnCombat", 0)) > 0:
		reduce_countdown(gs, p_idx, src, int(form.countdownOnCombat))
	if automatic: return
	# One use per realm, per actual turn (not per unit). Automated origin casts
	# are not hand plays and cannot spend this trigger or create an infinite loop.
	for realm in gs.player(p_idx).realms.duplicate():
		if int(realm.get("handCountdown", 0)) <= 0 or int(realm.get("usedTurn", -1)) == gs.turn_counter: continue
		realm.usedTurn = gs.turn_counter
		reduce_countdown(gs, p_idx, src, int(realm.handCountdown))

static func has_countdown(unit: Dictionary) -> bool:
	return int(unit.get("knockout", 0)) > 0 if int(unit.hp) <= 0 else (not Countdown.timer(unit).is_empty() or Glutton.satiated(unit))

static func reduce_countdown(gs, p_idx: int, src: int, amount: int, card_owner: int = -1, include_charms: bool = true) -> void:
	if amount <= 0 or gs.winner >= 0: return
	var unit: Dictionary = gs.player(p_idx).units[src]
	if int(unit.hp) <= 0:
		if not Rebirth.can_revive(unit) or int(unit.knockout) <= 0: return
		unit.knockout = maxi(0, int(unit.knockout) - amount)
		if int(unit.knockout) == 0:
			Pine.countdown_zero(gs,p_idx,src)
			unit.hp = int(unit.maxHp)
			unit.shield = 0
			gs._log("%s 气绝倒计时结束，恢复全部生命。" % unit.name, gs.TONE_SUCCESS)
			Movement.revived(gs, p_idx, src)
		return
	if int(unit.level) < 1: return
	if include_charms: Glutton.reduce_timer(gs,p_idx,src,amount)
	var timer: Dictionary = Countdown.timer(unit)
	if timer.is_empty(): return
	var before := int(timer.remaining)
	timer.remaining = maxi(0, int(timer.remaining) - amount)
	Wind.reduced(gs, p_idx, src, mini(before, amount))
	if card_owner == p_idx: Wind.mirror(gs, p_idx, src, amount)
	gs._log("%s 的倒计时降至%d。" % [unit.name, int(timer.remaining)], gs.TONE_CARD)
	event(gs, "countdown-tick", {"uid": unit.uid, "remaining": int(timer.remaining), "player": p_idx})
	if int(timer.remaining) > 0: return
	Pine.countdown_zero(gs,p_idx,src)
	# Overflow is discarded. Reset before queuing the cast; reductions that
	# occur later are separate effects and see the reset countdown.
	timer.remaining = int(timer.reset)
	if timer.get("form", false):
		Forms.queue_trigger(gs, p_idx, src, timer, "倒计时结束")
		return
	if timer.has("mode"):
		Countdown.queue_ability(gs, p_idx, src, str(timer.mode))
		return
	var card: Dictionary = timer.card
	var target = SpellReplay.random_target(gs, p_idx, card)
	if card.get("target", "auto") != "auto" and target == null: return
	gs._push_card_frames(p_idx, str(card.id), target, card, src, 0, true)

static func move_unit(gs, p_idx: int, unit: Dictionary) -> void:
	if unit.is_empty() or int(unit.hp) <= 0: return
	for owner in [p_idx, 1 - p_idx]:
		var idx: int = gs._unit_index_by_uid(owner, unit.uid)
		if idx >= 0:
			Movement.move_to(gs, owner, idx, 1 - int(unit.front))
			return

static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	if SugarCat.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if RabbitTide.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Cooking.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if Arakawa.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if RednightWalnut.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if ApeSleeve.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if BlueGreen.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if Yujiazhu.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if Zhenjian.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if ChargedPair.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if RedPurple.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if MirrorSong.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if Yi.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if Mianqiling.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if BoxMaiden.resolve_action(gs,p_idx,src,card,effect,target_id): return true
	if BlackWhite.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if TwoFaces.resolve_action(gs,p_idx,src,card,effect,target_id):return true
	if Lantern.resolve_action(gs,p_idx,src,card,effect,target_id): return true
	if SeaButterfly.resolve_action(gs,p_idx,src,card,effect,target): return true
	if SilkNinja.resolve_action(gs,p_idx,src,card,effect,target): return true
	if Toxic.resolve_action(gs,p_idx,src,card,effect,target): return true
	if KoiFragrance.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Susanoo.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Baize.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Crocodile.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Whale.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Jorogumo.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Yitiao.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Garuda.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Butterfly.resolve_action(gs,p_idx,src,card,effect,target): return true
	if Cotton.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if SpiderLily.resolve_action(gs,p_idx,src,card,effect,target): return true
	if ThreeTail.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Glutton.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Doll.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Onikiri.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Otakemaru.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if House.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Goldfish.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Vine.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if WindRaccoon.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Puppet.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Enma.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Weaver.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Sparrow.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Headless.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Yaksha.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if StarBear.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Pine.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Paint.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Samurai.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Mountain.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true
	if Maple.resolve_action(gs,p_idx,src,card,effect,target): return true
	if Raccoon.resolve_action(gs,p_idx,src,card,effect,target): return true
	if FoxLotus.resolve_action(gs,p_idx,src,card,effect,target): return true
	if Rebirth.resolve_action(gs,p_idx,src,card,effect,target_id): return true
	if OniAsura.resolve_action(gs,p_idx,src,card,effect): return true
	if PipeFox.resolve_action(gs,p_idx,src,card,effect,target): return true
	if Moon.resolve_action(gs,p_idx,src,card,effect,target): return true
	if Bamboo.resolve_action(gs,p_idx,src,card,effect): return true
	if OwlInsect.resolve_action(gs,p_idx,src,card,effect,target): return true
	if TreeSakura.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if MonkCleaner.resolve_action(gs, p_idx, src, card, effect, target): return true
	if BondDream.resolve_action(gs, p_idx, src, card, effect): return true
	if Eye.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Crab.resolve_action(gs, p_idx, src, card, effect, target_id): return true
	if Wind.resolve_action(gs, p_idx, src, card, effect): return true
	if Night.resolve_action(gs, p_idx, src, card, effect): return true
	if Mask.resolve_action(gs, p_idx, src, card, effect): return true
	if River.resolve_action(gs, p_idx, src, card, effect, target): return true
	if IronMouse.resolve_action(gs, p_idx, src, card, effect): return true
	if UpgradeBlessing.resolve_action(gs, p_idx, src, effect, target): return true
	if Mengpo.resolve_action(gs, p_idx, src, card, effect): return true
	if Huang.resolve_action(gs, p_idx, src, card, effect): return true
	if ArmorBlood.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if TomatoFire.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Movement.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if FoxSuzuka.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Fortune.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Poison.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if SunSmoke.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if BookJue.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Light.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if DogDemon.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Xuenv.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if SnowCrane.resolve_action(gs, p_idx, src, effect): return true
	if Panguan.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Yijin.resolve_action(gs, p_idx, src, card, effect, target_id): return true
	if Tide.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Bailang.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Shantong.resolve_action(gs, p_idx, src, card, effect): return true
	if Yaodao.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Shuten.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Bingyong.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Phoenix.resolve_action(gs, p_idx, src, card, effect, target): return true
	if Peach.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if Firefly.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true
	if ArmorBreak.resolve_action(gs, p_idx, src, effect, target): return true
	if Forms.resolve_action(gs, p_idx, src, card, effect): return true
	if Countdown.resolve_action(gs, p_idx, src, card, effect, target): return true
	if SpellReplay.resolve_action(gs, p_idx, src, card, effect, target): return true
	var amount := int(effect.get("value", 0)) if effect.get("value") is float or effect.get("value") is int else 0
	var enemy: int = gs.enemy_index(p_idx)
	match str(effect.get("action", "")):
		"nullify-next-card":
			gs.player(enemy).nullifyNextCardTurn = gs.turn_counter
			gs._log("本回合敌方下一张牌不会生效。", gs.TONE_CARD)
		"projectile-draw-on-kill":
			var idx: int = gs.front_index(enemy)
			if idx < 0: gs._damage_avatar(enemy, amount, p_idx)
			else:
				var hit: Dictionary = gs._damage_unit(enemy, idx, amount, p_idx)
				if hit.knocked: gs._draw(p_idx, 1)
		"move-unit":
			move_unit(gs, p_idx, target)
		"reduce-countdown-or-draw":
			if target.is_empty() or int(target.hp) <= 0: return true
			if has_countdown(target): reduce_countdown(gs, p_idx, gs._unit_index_by_uid(p_idx, target.uid), amount, p_idx if card.get("type") != "ability" else -1)
			else: gs._draw(p_idx, 1)
		"projectile-displace":
			var idx: int = gs.front_index(enemy)
			if idx < 0: gs._damage_avatar(enemy, amount, p_idx)
			else:
				var hit: Dictionary = gs._damage_unit(enemy, idx, amount, p_idx)
				var unit: Dictionary = gs.player(enemy).units[idx]
				# The original text requires actual damage, not an armor hit.
				if int(hit.damage) > 0 and int(unit.hp) > 0: move_unit(gs, enemy, unit)
		"random-damage":
			# Six individual points; re-evaluate survivors after every hit.
			for i in amount:
				if gs.winner >= 0: break
				var targets: Array = [-1]
				for idx in gs.player(enemy).units.size():
					if int(gs.player(enemy).units[idx].hp) > 0: targets.append(idx)
				var idx: int = targets[int(floor(gs.randf01() * targets.size()))]
				if idx < 0: passive_damage_avatar(gs,p_idx,src,enemy,1,card.get("type")=="ability")
				else: passive_damage_unit(gs,p_idx,src,enemy,idx,1,card.get("type")=="ability")
				event(gs, "random-hit", {"player": p_idx, "uid": gs.player(p_idx).units[src].uid, "card": card, "target": "" if idx < 0 else gs.player(enemy).units[idx].uid, "victimPlayer": enemy})
		_: return false
	return true

static func end_turn(gs, p_idx: int) -> void:
	Cooking.end_turn(gs,p_idx)
	RednightWalnut.end_turn(gs,p_idx)
	ApeSleeve.end_turn(gs,p_idx)
	BlueGreen.end_turn(gs,p_idx)
	RedPurple.end_turn(gs,p_idx)
	Yujiazhu.end_turn(gs)
	BoxMaiden.end_turn(gs,p_idx)
	KoiFragrance.end_turn(gs)
	Susanoo.end_turn(gs,p_idx)
	Baize.end_turn(gs)
	Whale.end_turn(gs)
	Jorogumo.end_turn(gs,p_idx)
	Doll.turn_end(gs,p_idx)
	Onikiri.end_turn(gs,p_idx)
	House.turn_end(gs,p_idx)
	Sparrow.end_turn(gs,p_idx)
	Headless.end_turn(gs,p_idx)
	Paint.end_turn(gs,p_idx)
	Maple.end_turn(gs,p_idx)
	Raccoon.end_turn(gs,p_idx)
	FoxLotus.end_turn(gs,p_idx)
	Rebirth.end_turn(gs,p_idx)
	PipeFox.end_turn(gs,p_idx)
	Bamboo.end_turn(gs,p_idx)
	OwlInsect.end_turn(gs,p_idx)
	TreeSakura.end_turn(gs, p_idx)
	MonkCleaner.end_turn(gs, p_idx)
	BondDream.end_turn(gs, p_idx)
	Crab.end_turn(gs, p_idx)
	IronMouse.end_turn(gs)
	Mengpo.end_turn(gs, p_idx)
	ArmorBlood.end_turn(gs)
	TomatoFire.end_turn(gs)
	Movement.end_turn(gs, p_idx)
	Fortune.end_turn(gs)
	Poison.end_turn(gs, p_idx)
	Light.end_turn(gs, p_idx)
	DogDemon.end_turn(gs, p_idx)
	Xuenv.end_turn(gs)
	Tide.end_turn(gs)
	Forms.end_turn(gs)
	Firefly.end_turn(gs, p_idx)
	Shuten.end_turn(gs, p_idx)
	SnowCrane.end_turn(gs, p_idx)
	for source in gs.player(p_idx).units:
		if int(source.hp) <= 0: continue
		var amount := int(source.get("formRules", {}).get("endTurnArmoredCountdown", 0))
		if amount <= 0: continue
		for idx in gs.player(p_idx).units.size():
			var unit: Dictionary = gs.player(p_idx).units[idx]
			if int(unit.hp) > 0 and int(unit.shield) > 0:
				reduce_countdown(gs, p_idx, idx, amount)
				gs._resolve_resolution_stack()
	UpgradeBlessing.end_turn(gs)

static func knocked_out(unit: Dictionary) -> void:
	RedPurple.knocked_out(unit)
	Toxic.knocked_out(unit)
	KoiFragrance.knocked_out(unit)
	Susanoo.knocked_out(unit)
	Baize.clear_temporary(unit)
	Whale.knocked_out(unit)
	unit.erase("msBeautyReceiver")
	unit.erase("msSwapDeltas")
	Cooking.knocked_out(unit)
	ApeSleeve.knocked_out(unit)
	ChargedPair.knocked_out(unit)
	Yujiazhu.knocked_out(unit)
	BlueGreen.knocked_out(unit)
	Mianqiling.knocked_out(unit)
	Futakuchi.knocked_out(unit)
	BlackWhite.knocked_out(unit)
	TwoFaces.knocked_out(unit)
	Lantern.knocked_out(unit)
	unit.erase("seaSpirit")
	unit.erase("spiderMark")
	unit.erase("garudaFeather")
	if not ContentLoader.runtime_unit_def(unit).get("battleSkillPersistsKnockout",false): unit.erase("battleSkillId")
	Yitiao.knocked_out(unit)
	Onikiri.knocked_out(unit)
	Goldfish.knocked_out(unit)
	OniAsura.knocked_out(unit)
	PipeFox.knocked_out(unit)
	unit.erase("moonCharm")
	OwlInsect.knocked_out(unit)
	for key in ["treeHealthCombat", "treeDisasters"]: unit.erase(key)
	for key in ["enraged", "monkEnrageTurn", "snowInstance", "monkFormUnyielding"]: unit.erase(key)
	for key in ["bondMoonPursuit", "bondMoonSwiftTurn", "bondMoonSwiftBaseline", "dreamPowerPenalty", "dreamPenaltyTurn"]: unit.erase(key)
	if unit.get("baseRulesSuppressed", false):
		Fortune.restore(unit)
		unit.form = {}
		unit.formRules = {}
		unit.formHooks = []
		unit.formAbility = ""
	unit.erase("poisonShieldTurn")
	Panguan.knocked_out(unit)
	unit.erase("tideCombatHeals")
	unit.erase("snowCombatStunTurn")
	Xuenv.summoned_knockout(unit)
	unit.barrier = false
	unit.erase("pendingShields")
	if unit.has("abilityCountdown"): unit.abilityCountdown.remaining = int(unit.abilityCountdown.reset)
	if not unit.get("spellCountdown", {}).get("persistKnockout", false): unit.erase("spellCountdown")
	# Only corrected forms use this path; legacy rules retain their baseline.
	if not unit.get("formRules", {}).is_empty():
		unit.form = {}
		unit.formRules = {}
		unit.formHooks = []
		unit.formAbility = ""

static func cancel_pending_card(gs, frame: Dictionary) -> bool:
	# Countdown casts are ability-generated, not cards used by the opposing
	# player. They neither consume a seal nor solicit a hand response.
	if frame.get("automatic", false): return false
	var p_idx := int(frame.playerIndex)
	var p: Dictionary = gs.player(p_idx)
	if int(p.get("nullifyNextCardTurn", -1)) != gs.turn_counter: return false
	p.erase("nullifyNextCardTurn")
	var rid := int(frame.resolutionId)
	gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId", -1)) != rid)
	var card: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.definitionId)))
	gs._log("「%s」被魔音扰心阻止，整张牌不生效。" % card.name, gs.TONE_DANGER)
	event(gs, "card-nullified", {"player": p_idx, "uid": str(p.units[int(frame.sourceIndex)].uid) if int(frame.sourceIndex)>=0 else "avatar-%d"%p_idx, "card": card, "resolutionId": rid})
	return true

static func announce_card(gs, frame: Dictionary) -> void:
	var announced: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.definitionId)))
	RednightWalnut.announced(gs,frame,announced)
	Arakawa.announced(gs,frame,announced)
	BlueGreen.announced(gs,frame,announced)
	RedPurple.announced(gs,frame,announced)
	Yujiazhu.announced(gs,frame,announced)
	Link.announced(gs,frame,announced)
	KoiFragrance.announced(gs,frame,announced)
	BattleSkill.announced(gs,frame,announced)
	Yitiao.announced(gs,frame,announced)
	Butterfly.announced(gs,frame,announced)
	Cotton.announced(gs,frame,announced)
	SilkNinja.announced(gs,frame,announced)
	SpiderLily.announced(gs,frame,announced)
	ThreeTail.announced(gs,frame,announced)
	OwlInsect.announced(gs,frame,announced)
	BondDream.announced(gs, frame, announced)
	Crab.announced(gs, frame, announced)
	SugarCat.announced(gs,frame,announced)
	Paint.announced(gs,frame,announced)
	Pine.announced(gs,frame,announced)
	Headless.announced(gs,frame,announced)
	IronMouse.announced(gs, frame, announced)
	Mengpo.announced(gs, int(frame.playerIndex), announced)
	FoxSuzuka.announced(gs, frame, announced)
	BookJue.announced(gs, frame, announced)
	SunSmoke.smoke_copy(gs, frame, announced)
	Xuenv.announced(gs, frame, announced)
	FoxLotus.announced(gs,frame,announced)
	Phoenix.card_announced(gs, frame, announced)
	card_announced(gs, int(frame.playerIndex), int(frame.sourceIndex), announced)
	if frame.get("automatic", false): return
	if cancel_pending_card(gs, frame): return
	if Onikiri.enemy_spell(gs,frame,announced): return
	var owner := 1 - int(frame.playerIndex)
	var check := frame.duplicate(true)
	check.kind = "card-counter-check"
	if PipeFox.single_target(gs,owner,frame,announced) and automatic_response(gs,owner,"enemy-single-character",frame.targetId,check): return
	automatic_response(gs, owner, "opponent-card-used", null, check)

static func automatic_response(gs, owner: int, trigger: String, target_id, continuation: Dictionary, response_depth: int = 0) -> bool:
	if Onikiri.enter_response(gs,owner,trigger,target_id,continuation): return true
	# 封魔符／封魔箭也能在己方回合被攻击时响应。
	var p: Dictionary = gs.player(owner)
	for i in gs.playable_card_count(owner):
		var card: Dictionary = gs.hand_card_def(owner, i)
		if owner == gs.current_player and not (card.get("yujiazhuRules", false) and card.id == "c18904"): continue
		var response := str(card.get("autoResponse", ""))
		if card.get("owlInterfere",false) and (trigger != "unit-attacked" or not OwlInsect.guarded(gs._unit_by_uid(p.units,target_id))): continue
		if trigger == "unit-attacked":
			if response not in ["source-attacked", "front-attacked", "other-ally-attacked", "ally-attacked"]: continue
			var defender: Dictionary = gs._unit_by_uid(p.units, target_id)
			if defender.is_empty(): continue
			if response == "front-attacked" and int(defender.front) != 1: continue
		elif response != trigger: continue
		if response=="toxic-enemy-attacking" and (target_id not in SilkNinja.targets(gs,owner,card)):continue
		var src: int = gs._source_index(owner, card)
		if src < 0: continue
		var unit: Dictionary = p.units[src]
		if unit.get("baseRulesSuppressed", false): continue
		if UpgradeBlessing.card_blocked(gs, unit, card): continue
		if response == "other-ally-attacked" and unit.uid == target_id: continue
		if response in ["source-attacked", "source-damaged", "source-lethal"] and unit.uid != target_id: continue
		if (int(unit.hp)<=0 and not card.get("allowKnockedSource",false)) or Stun.blocks(gs,owner,unit,card) or int(unit.level)<int(card.level): continue
		if not Zhenjian.can_use(gs,owner,card):continue
		if not Yitiao.can_use(gs,owner,card): continue
		if not Cotton.can_use(gs,owner,card): continue
		if not SpiderLily.can_use(gs,owner,card): continue
		if not ThreeTail.can_use(gs,owner,card) or not Glutton.can_use(gs,owner,card) or not Doll.can_use(gs,owner,card): continue
		if not Onikiri.can_use(gs,owner,card) or not Otakemaru.can_use(gs,owner,card) or not House.can_use(gs,owner,card): continue
		if not Goldfish.can_use(gs,owner,card) or not Vine.can_use(gs,owner,card) or not WindRaccoon.can_use(gs,owner,card): continue
		if not Puppet.can_use(gs,owner,card) or not Enma.can_use(gs,owner,card) or not Weaver.can_use(gs,owner,card): continue
		if not Sparrow.can_use(gs,owner,card) or not Headless.can_use(gs,owner,card) or not Yaksha.can_use(gs,owner,card): continue
		if not StarBear.can_use(gs,owner,card): continue
		if not Rebirth.can_use(gs,owner,card): continue
		if not Yujiazhu.can_use(gs,owner,card):continue
		if not DogDemon.can_use(gs, owner, card): continue
		if (card.get("dogGuard", false) or card.get("poisonGuard", false) or card.get("yitiaoCover", false) or card.id=="c24404") and Bingyong.replacement_blocked(gs, owner, unit): continue
		if not Panguan.can_use(gs, owner, card): continue
		var actual_target = target_id
		var targets_attacker: bool = card.get("owlInterfere",false) or card.id=="c24404" or (card.get("yujiazhuRules",false) and card.id=="c18904")
		if targets_attacker:
			actual_target = gs.player(int(continuation.playerIndex)).units[int(continuation.sourceIndex)].uid
			# A forced response target still has to belong to the printed side.
			# It is not a manual selection, so do not add a veil restriction.
			if card.get("target", "auto") == "enemy-unit" and gs._unit_index_by_uid(1-owner, str(actual_target)) < 0: continue
		var payment: Dictionary = gs.card_payment(owner, card)
		if int(p.energy) < int(payment.cost): continue
		gs._set_fire(owner,int(p.energy)-int(payment.cost),true)
		Moon.consume_card(gs,card)
		if payment.usesInstant: gs.kw_usage(owner, "instant").used = true
		gs.take_card_instance(owner, i)
		p.cardsPlayedThisTurn = int(p.cardsPlayedThisTurn) + 1
		if card.get("coinDamageGuard", false) and trigger == "source-damaged":
			card = card.duplicate(true)
			card.coinGuardTriggered = true
		if card.get("effect") == "wind-quick":
			card = card.duplicate(true)
			card.windResponded = true
		gs.resolution_stack.append(continuation)
		var combat_id := int(continuation.get("combatId", -1)) if card.get("responseModifiesCombat", false) else -1
		if card.get("foxCounter",false) and trigger=="enemy-single-character":
			card=card.duplicate(true); card.foxCounterId=int(continuation.resolutionId)
			card.foxCounterCard=continuation.get("cardOverride",ContentLoader.card_def(str(continuation.definitionId)))
			card.foxCounterUid=gs.player(int(continuation.playerIndex)).units[int(continuation.sourceIndex)].uid
		gs._push_card_frames(owner, str(card.id), null if card.get("target", "auto") == "auto" and card.id != "c24404" else actual_target, card, src, response_depth, false, combat_id)
		gs._log("%s 响应，自动使用「%s」。" % [unit.name, card.name], gs.TONE_CARD)
		event(gs, "response-card", {"player": owner, "uid": unit.uid, "card": card, "target": target_id, "trigger": response, "payment": payment})
		return true
	return false

# Base/awakened abilities carry their own damage source, outside spell context.
static func base_damage_unit(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> Dictionary:
	var old: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	var result: Dictionary = gs._damage_unit(victim,idx,amount+ApeSleeve.base_damage_bonus(gs,owner),owner,src)
	gs._card_effect_context = old
	return result

static func base_damage_avatar(gs, owner: int, src: int, victim: int, amount: int) -> int:
	var old: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	var result: int = gs._damage_avatar(victim,amount+ApeSleeve.base_damage_bonus(gs,owner),owner,src)
	gs._card_effect_context = old
	return result

static func base_damage_projectile(gs, owner: int, src: int, amount: int, reason: String = "基础能力投射") -> void:
	var old: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	ThreeTail.projectile(gs,owner,src,amount+ApeSleeve.base_damage_bonus(gs,owner),reason)
	gs._card_effect_context = old

static func passive_damage_unit(gs, owner: int, src: int, victim: int, idx: int, amount: int, base_ability: bool) -> Dictionary:
	return base_damage_unit(gs,owner,src,victim,idx,amount) if base_ability else gs._damage_unit(victim,idx,amount,owner,src)

static func passive_damage_avatar(gs, owner: int, src: int, victim: int, amount: int, base_ability: bool) -> int:
	return base_damage_avatar(gs,owner,src,victim,amount) if base_ability else gs._damage_avatar(victim,amount,owner,src)

# Food is played by the player, without an invented source shikigami.
static func announce_neutral_food(gs, frame: Dictionary) -> void:
	var card: Dictionary=frame.cardOverride
	Arakawa.announced(gs,frame,card)
	FoxSuzuka.announced(gs,frame,card)
	BondDream.announced(gs,frame,card)
	KoiFragrance.announced(gs,frame,card)
	event(gs,"neutral-card-announced",{"player":int(frame.playerIndex),"card":card.duplicate(true),"resolutionId":int(frame.resolutionId),"sourceIndex":-1})
	if frame.get("automatic",false):return
	if cancel_pending_card(gs,frame):return
	var enemy:=1-int(frame.playerIndex)
	var continuation:=frame.duplicate(true);continuation.kind="card-counter-check"
	if PipeFox.single_target(gs,enemy,frame,card) and automatic_response(gs,enemy,"enemy-single-character",frame.targetId,continuation):return
	automatic_response(gs,enemy,"opponent-card-used",null,continuation)
