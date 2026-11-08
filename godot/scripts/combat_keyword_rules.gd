class_name CombatKeywordRules
extends RefCounted
## Shared combat traits; card traits, forms and temporary grants keep distinct lifetimes.

static func has(unit: Dictionary, keyword: String) -> bool:
	if keyword=="pursuit" and preload("res://scripts/red_purple_rules.gd").has_pursuit(unit):return true
	if preload("res://scripts/blue_green_rules.gd").has_trait(unit,keyword):return true
	if keyword=="veil" and unit.get("randomTargetPreview",false):return false
	if keyword=="veil" and unit.get("chargedVeil",false):return true
	if keyword=="veil" and unit.get("rtSpearVeil",false) and int(unit.get("hp",0))>0:return true
	if preload("res://scripts/mianqiling_rules.gd").has_trait(unit,keyword):return true
	if keyword=="veil" and preload("res://scripts/black_white_rules.gd").veil(unit):return true
	if preload("res://scripts/glutton_rules.gd").has(unit,keyword): return true
	if preload("res://scripts/goldfish_rules.gd").has(unit,keyword): return true
	if preload("res://scripts/enma_rules.gd").has(unit,keyword): return true
	if keyword=="veil" and unit.get("foxVeil",false) and int(unit.get("hp",0))>0: return true
	if keyword == "veil" and unit.get("movementVeil", false) and int(unit.hp) > 0: return true
	if keyword == "veil" and unit.get("owlVeil",false) and int(unit.get("hp",0))>0: return true
	if keyword == "veil" and unit.get("cleanerVeil", false) and int(unit.get("hp", 0)) > 0: return true
	if int(unit.get("hp", 0)) <= 0 or int(unit.get("level", 0)) < 1: return false
	if keyword == "pierce" and preload("res://scripts/crocodile_rules.gd").has_trait(unit,"pierce"): return true
	if keyword == "pierce" and unit.get("yitiaoPierce", false): return true
	if keyword == "pursuit" and int(unit.get("twoFacesWind",0))>0:return true
	if keyword == "pursuit" and unit.get("bondMoonPursuit", false): return true
	if keyword == "inspired" and unit.get("inspired", false): return true
	if unit.get("hairGuardTraits",{}).has(keyword):return true
	var def := ContentLoader.runtime_unit_def(unit)
	for list in [def.get("combatKeywords", []), unit.get("keywords", []), unit.get("formRules", {}).get("combatKeywords", []), unit.get("formRules",{}).get("handCharmKeywords",[]), unit.get("untilAttack", {}).get("keywords", []), unit.get("swanKeywords", {}).keys()]:
		if list.any(func(k): return str(k).to_lower().replace("_", "-") == keyword): return true
	if unit.get("awakened", false) and keyword in def.get("awakenedCombatKeywords", []): return true
	return false

static func grant_inspired(gs, owner: int, idx: int) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if int(unit.hp) <= 0 or int(unit.level) < 1: return
	unit.inspired = true
	gs.VerifiedRules.event(gs, "inspired-gained", {"player": owner, "uid": unit.uid})

static func zero_power(gs, owner: int, unit: Dictionary) -> bool:
	return owner != gs.current_player and unit.get("formRules", {}).get("zeroPowerEnemyTurn", false)

static func power(gs, owner: int, unit: Dictionary, bonus: int = 0) -> int:
	if gs.VerifiedRules.TreeSakura.health_damage(unit): return int(unit.hp)
	return 0 if zero_power(gs, owner, unit) or gs.VerifiedRules.Movement.zero_power(gs, unit) else maxi(0, gs.VerifiedRules.Samurai.power(unit) + bonus)

static func strip_protection(gs, owner: int, idx: int, barrier: bool) -> void:
	if idx < 0:
		gs.player(owner).avatarArmor = 0
		return
	var unit: Dictionary = gs.player(owner).units[idx]
	gs.VerifiedRules.StarBear.consumed_armor(unit,int(unit.shield))
	unit.shield = 0
	unit.shieldExpires = 0
	gs.VerifiedRules.ArmorBlood.armor_changed(gs, unit)
	if barrier: unit.barrier = false
	gs.VerifiedRules.event(gs, "protection-removed", {"player": owner, "uid": unit.uid, "barrier": barrier})

static func strike(gs, owner: int, src: int, victim: int, idx: int, amount: int, options: Dictionary, pierce: bool = false, immune: bool = false) -> Dictionary:
	if options.get("rwNoDamage",false):return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	var source: Dictionary = gs.player(owner).units[src]
	if idx >= 0 and int(gs.player(victim).units[idx].hp) <= 0:
		gs.VerifiedRules.TreeSakura.dead_damage(gs,owner,src,victim,idx,amount)
		return {"damage":0,"dealt":0,"knocked":false,"overkill":0}
	var mian_scope: Dictionary=gs.VerifiedRules.Mianqiling.begin_strike(gs,owner,src,victim,idx,options)
	var susanoo_scope: Dictionary=gs.VerifiedRules.Susanoo.begin_strike(gs,owner,src,options)
	var tomb_before: int=0 if idx<0 else int(gs.player(victim).units[idx].get("susanooTombSerial",0))
	if not options.has("bloodLifeSteal"): options.merge(gs.VerifiedRules.ArmorBlood.traits(gs, owner, src))
	var lethal: bool = options.get("lethal", false) or has(source, "lethal")
	var snow_traits: Dictionary = options if options.has("snowCombatStun") else gs.VerifiedRules.Xuenv.combat_traits(gs, owner, src)
	var tide_traits: Dictionary = options if options.has("tideHealOthers") else gs.VerifiedRules.Tide.combat_traits(gs, owner, src)
	if options.get("removeArmor", false) or options.get("penetration",false) or has(source, "penetration"):
		strip_protection(gs, victim, idx, options.get("penetration",false) or has(source, "penetration"))
	immune=immune or gs.VerifiedRules.MusicFire.combat_immune(gs,victim,idx)
	immune=immune or (idx>=0 and gs.VerifiedRules.BlueGreen.combat_immune(gs,victim,idx))
	immune=immune or (idx>=0 and gs.VerifiedRules.SerpentGhost.combat_immune(gs.player(victim).units[idx]))
	immune=immune or (idx>=0 and gs.VerifiedRules.BlackWhite.combat_immune(gs.player(victim).units[idx])) or gs.VerifiedRules.SilkNinja.damage_immune(gs,owner,src,victim,idx,amount,options)
	amount = gs.VerifiedRules.HairPower.damage_bonus(gs,owner,src,amount,options)
	amount = gs.VerifiedRules.FoxSuzuka.strike_power(gs, owner, victim, idx, amount, options)
	var critical: bool = owner != victim and (options.get("critical", false) or has(source, "crit") or (idx>=0 and options.get("headlessUnitCrit",false)) or (idx>=0 and options.get("yujCritical",false)))
	# Overflow is allocated independently of the unit's barrier/immunity or
	# conversion. Armor and armor break participate before the HP boundary.
	var overflow := 0
	if pierce and idx >= 0 and (amount > 0 or gs.VerifiedRules.Mianqiling.positive_zero(gs,victim,idx,owner,src,true)) and not gs.player(victim).units[idx].get("bloodTransfer", false) and not gs.VerifiedRules.OniAsura.will_transfer(gs,gs.player(victim).units[idx]):
		var target: Dictionary = gs.player(victim).units[idx]
		var unit_damage: int = gs.VerifiedRules.Jorogumo.received_damage(target,maxi(0, amount + int(target.armorBreak) - int(target.shield)) * (2 if critical else 1))
		unit_damage = gs.VerifiedRules.Mianqiling.modify_damage(gs,victim,idx,unit_damage,owner,src,true)
		overflow = maxi(0,gs.VerifiedRules.OwlInsect.reduced(target,gs.VerifiedRules.MonkCleaner.reduced(target,unit_damage))-int(target.hp))
	var bamboo_reactions: Array = gs.VerifiedRules.Bamboo.retaliation(gs,victim,idx)
	var outer_toxic_context: Dictionary=gs._toxic_damage_context
	if options.get("toxicAttack",false): gs._toxic_damage_context={"playerIndex":owner,"sourceIndex":src}
	var result: Dictionary = gs.VerifiedRules.ArmorBreak.combat_damage(gs, owner, src, victim, idx, amount, bool(options.get("convertCombatToArmorBreak", false)), immune, int(options.get("victimKnockoutExtra", -1)), critical)
	gs._toxic_damage_context=outer_toxic_context
	if result.get("redirected", false):
		victim = int(result.get("redirectedPlayer", victim))
		idx = int(result.redirectedIndex)
		bamboo_reactions = gs.VerifiedRules.Bamboo.retaliation(gs,victim,idx)
		overflow = 0
	gs.VerifiedRules.ArmorBreak.after_combat_damage(gs, owner, src, victim, idx, result, options)
	gs.VerifiedRules.ArmorBlood.combat_dealt(gs, owner, result, options)
	gs.VerifiedRules.Huang.combat_dealt(gs, owner, src, result)
	gs.VerifiedRules.Xuenv.combat_dealt(gs, owner, victim, idx, result, snow_traits)
	gs.VerifiedRules.Tide.combat_dealt(gs, owner, src, result, tide_traits)
	gs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,idx,result,options)
	gs.VerifiedRules.EssenceFeast.combat_dealt(gs,owner,src,result)
	gs.VerifiedRules.Zhenjian.combat_dealt(gs,owner,src,victim,idx,result,options)
	gs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,idx,result,options)
	gs.VerifiedRules.Jorogumo.combat_dealt(gs,owner,src,victim,idx,result)
	gs.VerifiedRules.OwlInsect.combat_dealt(gs,owner,src,victim,idx,result)
	gs.VerifiedRules.BondDream.combat_dealt(gs, owner, src, victim, idx, result)
	gs.VerifiedRules.Bamboo.combat_dealt(gs,owner,src,victim,result,bamboo_reactions)
	gs.VerifiedRules.OniAsura.combat_dealt(gs,owner,src,victim,idx,result,options)
	gs.VerifiedRules.Light.combat_dealt(gs, owner, src, victim, idx, result)
	gs.VerifiedRules.IronMouse.combat_dealt(gs, owner, src, victim, idx, result, options)
	gs.VerifiedRules.Night.combat_dealt(gs, owner, victim, idx, result, options)
	gs.VerifiedRules.RedPurple.combat_dealt(gs,owner,src,victim,idx,result,options)
	gs.VerifiedRules.TwoFaces.combat_dealt(gs,owner,src,victim,idx,result,options)
	gs.VerifiedRules.FoxSuzuka.combat_dealt(options, result)
	gs.VerifiedRules.Poison.combat_dealt(gs, owner, src, victim, idx, result)
	gs.VerifiedRules.TomatoFire.combat_dealt(gs, owner, src, victim, idx, result, options)
	gs.VerifiedRules.Movement.combat_dealt(gs, owner, src, victim, idx, result, options)
	gs.VerifiedRules.SnowCrane.spread(gs, owner, src, victim, idx, result, options)
	if int(result.get("dealt", result.damage)) > 0 and lethal and not result.get("bodyKnocked",result.get("knocked",false)):
		if idx >= 0:
			if gs.VerifiedRules.Panguan.destroy(gs, owner, src, victim, idx, options.get("combatCard", {}), int(options.get("victimKnockoutExtra", -1))): result.knocked = true
		elif options.get("lethalAvatar", false) and gs.winner < 0:
			gs.player(victim).avatarHp = 0
			gs._log("夺命消灭了受到战斗伤害的牌手。", gs.TONE_DANGER)
			gs._check_winner()
	if overflow > 0 and gs.winner < 0:
		var pierce_bamboo: Array = gs.VerifiedRules.Bamboo.retaliation(gs,victim,-1)
		var dealt: int = gs._damage_avatar(victim, overflow, owner, src, false, true)
		gs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)
		gs.VerifiedRules.EssenceFeast.combat_dealt(gs,owner,src,{"dealt":dealt})
		gs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)
		gs.VerifiedRules.Bamboo.combat_dealt(gs,owner,src,victim,{"dealt":dealt},pierce_bamboo)
		gs.VerifiedRules.IronMouse.combat_dealt(gs, owner, src, victim, -1, {"dealt": dealt}, options)
		gs.VerifiedRules.BondDream.combat_dealt(gs, owner, src, victim, -1, {"dealt": dealt})
		gs.VerifiedRules.OniAsura.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)
		gs.VerifiedRules.Night.combat_dealt(gs, owner, victim, -1, {"dealt": dealt}, options)
		gs.VerifiedRules.RedPurple.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)
		gs.VerifiedRules.TwoFaces.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)
		gs.VerifiedRules.event(gs, "pierce-damage", {"player": owner, "uid": source.uid, "victimPlayer": victim, "amount": overflow})
	gs.VerifiedRules.Headless.combat_dealt(gs,owner,src,victim,idx,result,options)
	gs.VerifiedRules.Yaksha.combat_strike(gs,owner,src,victim,idx,result,options)
	if idx>=0 and int(gs.player(victim).units[idx].get("susanooTombSerial",0))>tomb_before: result.knocked=true
	gs.VerifiedRules.Susanoo.end_strike(gs,owner,src,susanoo_scope)
	gs.VerifiedRules.Mianqiling.end_strike(gs,mian_scope)
	return result
