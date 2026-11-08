class_name BattleStatus
extends RefCounted
## Read-only presentation of live rules. Never infer statuses from card names or text.
const ContentLoader := preload("res://scripts/content_loader.gd")
const Combat := preload("res://scripts/combat_keyword_rules.gd")
const Glossary := preload("res://scripts/ui/keyword_glossary.gd")
const Countdown := preload("res://scripts/countdown_rules.gd")

static func unit_view(gs, owner: int, idx: int, viewer: int) -> Dictionary:
	var view: Dictionary = gs.VerifiedRules.Bailang.unit_view(gs, owner, idx, viewer)
	view.fortuneSixes = gs.VerifiedRules.Fortune.sixes(gs, owner)
	view.fortuneDistinct = gs.player(owner).get("fortuneNumbers", []).size()
	if view.get("baseRulesSuppressed", false) and not gs.VerifiedRules.Susanoo.tomb(view):
		view.presentationId = "zhiren"
		view.art = ContentLoader.unit_def("zhiren").art
		view.awakenedArt = view.art
	if ContentLoader.unit_def(str(view.id)).get("judgeLedger", false):
		view.judgeKills = int(gs.player(owner).get("destroyedUnits", 0))
	if ContentLoader.unit_def(str(view.id)).get("snowCombat", false): view.enemyStuns = int(gs.player(owner).get("enemyStuns", 0))
	view.lightFortuneTotal = gs.VerifiedRules.Light.fortune_total(gs)
	view.lightAvatarAttacks = int(gs.player(owner).get("enemyAvatarAttacks", 0))
	view.lightImmune = int(gs.player(owner).get("monkImmuneTurn", -1)) == gs.turn_counter
	view.coinsUsed = gs.VerifiedRules.IronMouse.used(gs, owner)
	view.riverRollTotal = gs.VerifiedRules.River.total(gs, owner)
	view.riverDieBonus = gs.VerifiedRules.River.die_bonus(gs, owner)
	view.nightRealmPower = gs.VerifiedRules.Night.power(gs, view)
	view.oniFirstCard=ContentLoader.card_def(str(gs.player(owner).get("oniFirstDrawCard",""))).get("name","") if int(gs.player(owner).get("oniFirstDrawTurn",-1))==gs.turn_counter else ""
	if gs.VerifiedRules.Glutton.has(view,"swift"): view.swift=true
	if gs.VerifiedRules.Rebirth.swift(view): view.swift=true
	if gs.VerifiedRules.Yitiao.swift(view): view.swift=true
	view.incarnationConfig=gs.VerifiedRules.Incarnation.config(view,gs,owner)
	view.ignoresStun=gs.VerifiedRules.Raccoon.ignores(gs,owner,view)
	view.stunInstant=gs.VerifiedRules.Raccoon.feast(gs,owner) and int(view.frozen)>0
	view.lotusDamageBlocked=gs.VerifiedRules.FoxLotus.prevents_damage(gs,owner,idx)
	view.lotusPowerPenalty=gs.VerifiedRules.FoxLotus.penalty(gs,view)
	view.mapleNightValue=gs.VerifiedRules.Maple.night_value(gs,owner)
	view.mapleDamageBonus=gs.VerifiedRules.Maple.damage_bonus(gs,owner,idx,false)
	if gs.VerifiedRules.Samurai.ghost(view): view.attack=gs.VerifiedRules.Samurai.power(view)
	if gs.VerifiedRules.Samurai.swift(view): view.swift=true
	view.asuraReplacementReady=int(view.get("asuraTransferTurn",-1))!=gs.turn_counter
	view.foxImmunityReady=int(view.get("foxImmuneTurn",-1))!=gs.turn_counter
	view.moonExtraAttack = gs.VerifiedRules.Moon.extra_attack(gs,owner)
	view.bambooDurability = int(gs.VerifiedRules.Bamboo.field(gs,owner).get("hp",0))
	view.bambooDistinct = gs.player(owner).get("bambooHistory",[]).size()
	view.dreamCardCount = gs.VerifiedRules.BondDream.nightmare_cards(gs, 1 - owner).size()
	if gs.VerifiedRules.TreeSakura.floating(view): view.swift = true
	view.bondAffected = int(view.get("bondAffectedTurn", -1)) == gs.turn_counter
	view.eyeFlameGrowth = int(gs.player(owner).get("eyeFlameGrowth", 0))
	view.eyeDivinationBonus = gs.VerifiedRules.Eye.bonus(gs, owner)
	if gs.VerifiedRules.IronMouse.swift(gs, view): view.swift = true
	view.blessingCanOverlevel = int(view.level) >= 3 and gs.VerifiedRules.UpgradeBlessing.overlevel_realms(gs, owner) > 0
	view.poisonReduction = gs.VerifiedRules.Poison.power_reduction(gs, owner, view)
	view.poisonRetained = gs.VerifiedRules.Poison.preserves(gs, owner, idx)
	view.koiFragranceMarks=gs.VerifiedRules.KoiFragrance.unit_marks(gs,owner,idx)
	view.yujMarks=gs.VerifiedRules.Yujiazhu.marks(gs,owner,idx)
	view.hairMarks=gs.VerifiedRules.HairPower.marks(view)
	view.fearWingMarks=gs.VerifiedRules.FearWing.marks(view)
	view.mfMarks=gs.VerifiedRules.MusicFire.marks(gs,owner,view)
	view.efMarks=gs.VerifiedRules.EssenceFeast.marks(gs,owner,view)
	view.cookingMarks=gs.VerifiedRules.Cooking.marks(gs,owner,view)
	view.scMarks=gs.VerifiedRules.SugarCat.marks(gs,owner,view)
	view.rtMarks=gs.VerifiedRules.RabbitTide.marks(gs,owner,view)
	view.sgMarks=gs.VerifiedRules.SerpentGhost.marks(gs,owner,view)
	view.arkMarks=gs.VerifiedRules.Arakawa.marks(gs,owner,view)
	view.rwMarks=gs.VerifiedRules.RednightWalnut.marks(gs,owner,view)
	view.apeSleeveMarks=gs.VerifiedRules.ApeSleeve.marks(gs,owner,view)
	view.zdMarks=gs.VerifiedRules.Zhenjian.marks(gs,owner,view)
	view.chargedMarks=gs.VerifiedRules.ChargedPair.marks(gs,owner,view)
	view.rpMarks=gs.VerifiedRules.RedPurple.marks(gs,owner,idx)
	view.msMarks=gs.VerifiedRules.MirrorSong.marks(gs,owner,view)
	view.yiMarks=gs.VerifiedRules.Yi.marks(gs,owner,idx)
	view.futakuchiMarks=gs.VerifiedRules.Futakuchi.marks(gs,owner,idx)
	view.boxMaidenMarks=gs.VerifiedRules.BoxMaiden.marks(gs,owner,idx)
	view.blackWhiteMarks=gs.VerifiedRules.BlackWhite.marks(gs,owner,idx)
	view.blueGreenMarks=gs.VerifiedRules.BlueGreen.marks(gs,owner,idx)
	view.mianMarks=gs.VerifiedRules.Mianqiling.marks(gs,owner,view)
	if gs.VerifiedRules.Mianqiling.swift(view):view.swift=true
	if gs.VerifiedRules.Mianqiling.unyielding(view):view.unyielding=true
	view.twoFacesMarks=gs.VerifiedRules.TwoFaces.marks(gs,owner,idx)
	view.lanternMarks=gs.VerifiedRules.Lantern.marks(gs,owner,idx)
	view.seaSpiritMarks=gs.VerifiedRules.SeaButterfly.unit_marks(gs,owner,idx)
	view.toxicMarks=gs.VerifiedRules.Toxic.unit_marks(gs,owner,idx)+gs.VerifiedRules.SilkNinja.marks(gs,owner,idx)
	view.susanooMarks=gs.VerifiedRules.Susanoo.unit_marks(gs,owner,idx)
	view.baizeMarks=gs.VerifiedRules.Baize.unit_marks(gs,owner,idx)
	view.crocodileMarks=gs.VerifiedRules.Crocodile.unit_marks(gs,owner,idx)
	view.whaleMarks=gs.VerifiedRules.Whale.unit_marks(gs,owner,idx)
	view.jorogumoMarks=gs.VerifiedRules.Jorogumo.unit_marks(gs,owner,idx)
	view.yitiaoMarks=gs.VerifiedRules.Yitiao.unit_marks(gs,owner,idx)
	view.battleSkillMarks=gs.VerifiedRules.BattleSkill.unit_marks(gs,owner,idx)
	view.cottonMarks=gs.VerifiedRules.Cotton.unit_marks(gs,owner,idx)
	view.spiderLilyMarks=gs.VerifiedRules.SpiderLily.unit_marks(gs,owner,idx)
	view.threeTailMarks=gs.VerifiedRules.ThreeTail.unit_marks(gs,owner,idx)
	view.gluttonMarks=gs.VerifiedRules.Glutton.unit_marks(gs,owner,idx)
	view.dollMarks=gs.VerifiedRules.Doll.unit_marks(gs,owner,idx)
	view.onikiriMarks=gs.VerifiedRules.Onikiri.unit_marks(gs,owner,idx)
	view.otakemaruMarks=gs.VerifiedRules.Otakemaru.unit_marks(gs,owner,idx)
	view.houseMarks=gs.VerifiedRules.House.unit_marks(gs,owner,idx)
	view.goldfishMarks=gs.VerifiedRules.Goldfish.unit_marks(gs,owner,idx)
	view.vineMarks=gs.VerifiedRules.Vine.unit_marks(gs,owner,idx)
	view=gs.VerifiedRules.WindRaccoon.unit_view(gs.player(owner).units[idx],view)
	view.puppetMarks=gs.VerifiedRules.Puppet.unit_marks(gs,owner,idx)
	view.weaverMarks=gs.VerifiedRules.Weaver.unit_marks(gs,owner,idx)
	view=gs.VerifiedRules.Enma.unit_view(gs.player(owner).units[idx],view)
	view.headlessMarks=gs.VerifiedRules.Headless.unit_marks(gs,owner,idx)
	view.starDiscordLocked=gs.VerifiedRules.StarBear.locked(gs,owner,view)
	view.pineMarks=gs.VerifiedRules.Pine.unit_marks(gs,owner,idx)
	view = gs.VerifiedRules.Paint.unit_view(gs,owner,idx,view)
	view = gs.VerifiedRules.TomatoFire.unit_view(gs, owner, idx, view)
	if ContentLoader.unit_def(str(view.id)).get("snowWoman", false):
		view.snowballsPlayed = int(gs.player(owner).get("snowballsPlayed", 0))
		view.snowballBonus = int(gs.player(owner).get("snowballBonus", 0))
	if ContentLoader.unit_def(str(view.id)).get("goldenFeather", false):
		view.feathersPlayed = int(gs.player(owner).get("feathersPlayed", 0))
		view.featherImmune = gs.VerifiedRules.Yijin.immune(gs, owner, view)
	return view

static func card_view(gs, owner: int, card: Dictionary) -> Dictionary:
	var view := card.duplicate(true)
	view.payment = gs.card_payment(owner, card)
	if card.get("upgradeBlessingCard", false) or card.get("blessingRaises", false):
		view.inspiredSupport = gs.player(owner).units.any(func(u): return int(u.hp) > 0 and int(u.level) > 0 and u.awakened and ContentLoader.runtime_unit_def(u).get("upgradeBlessing", false))
	return view

static func payment_text(card: Dictionary) -> String:
	var p: Dictionary = card.get("payment", {})
	if p.is_empty(): return ""
	if p.get("lilyDeckFree", false): return "彼岸归航 · 1勾牌库顶免鬼火" + (" · 瞬发发动" if p.usesInstant else "")
	if p.get("coinFirstFree", false): return "觉醒·铁鼠 · 首枚钱币免鬼火（不占用瞬发）"
	if p.usesInstant: return "%s · 本次 %d 鬼火（全队每回合一次）" % ["瞬发发动" if p.get("applied", false) else "瞬发可用", int(p.cost)]
	if p.get("usesSwift",false):return "疾速 · 本次消耗%s，%d鬼火"%["坚守次数" if p.get("usesGuard",false) else "出击次数",int(p.cost)]
	if p.instant:
		var why := "本回合已用" if p.instantUsed else "当前阶段不可用"
		return "瞬发%s · 本次 %d 鬼火" % [why, int(p.cost)]
	return "本次 %d 鬼火%s" % [int(p.cost), " · 不占用瞬发" if int(p.cost) == 0 else ""]

static func mark(id: String, label: String, detail: String, color: String, value: int = -1, active: bool = true) -> Dictionary:
	return {"id": id, "label": label, "detail": detail, "color": Color(color), "value": value, "active": active}

static func unit_marks(unit: Dictionary, turn: int = -1) -> Array:
	var result: Array = []
	var alive := int(unit.get("hp", 1)) > 0 and int(unit.get("knockout", 0)) == 0
	var active := alive and int(unit.get("level", 1)) > 0
	if alive and unit.get("starDiscordLocked",false): result.append(mark("star-discord", "离间之音 · 不能用手牌", "敌方离间之音在场时，激怒式神不能使用手牌；仍可合法出击。", "b89be4"))
	if alive and int(unit.get("starBowlSerial",0))>0 and int(unit.get("frozen",0))>0: result.append(mark("star-bowl", "敌在酒碗处 · 承担全场伤害", "眩晕持续期间，所有其他角色受到的伤害由该式神承担；护甲及破甲在实际受伤者结算。", "b89be4"))
	if alive and unit.has("starTargetTurn"): result.append(mark("star-focus", "众矢之的 · 本回合出击目标", "本回合对方普通出击转向此式神；临时数值随回合结束移除。", "b89be4"))
	for detail in unit.get("koiFragranceMarks",[]): result.append(mark("koi-fragrance-rule",str(detail),str(detail),"90c8b8"))
	for detail in unit.get("yujMarks",[]):result.append(mark("yuj-rule",str(detail),str(detail),"c5b373"))
	for detail in unit.get("hairMarks",[]):result.append(mark("battle-power",str(detail),str(detail),"8ec9db"))
	for detail in unit.get("fearWingMarks",[]):result.append(mark("fear-wing",str(detail),str(detail),"ae74bb"))
	for detail in unit.get("mfMarks",[]):result.append(mark("music-fire",str(detail),str(detail),"e49871"))
	for detail in unit.get("efMarks",[]):result.append(mark("essence-feast",str(detail),str(detail),"d8b0c2"))
	for detail in unit.get("cookingMarks",[]):result.append(mark("cooking",str(detail),str(detail),"d2ad7b"))
	for detail in unit.get("scMarks",[]):result.append(mark("sugar-cat",str(detail),str(detail),"e8b0c0"))
	for detail in unit.get("rtMarks",[]):result.append(mark("rabbit-tide",str(detail),str(detail),"9bc9d6"))
	for detail in unit.get("sgMarks",[]):result.append(mark("serpent-ghost",str(detail),str(detail),"be99ca"))
	for detail in unit.get("arkMarks",[]):result.append(mark("arakawa-rule",str(detail),str(detail),"81b8de"))
	for detail in unit.get("rwMarks",[]):result.append(mark("rednight-walnut",str(detail),str(detail),"c998a6"))
	for detail in unit.get("apeSleeveMarks",[]):result.append(mark("ape-sleeve",str(detail),str(detail),"b0c898"))
	for detail in unit.get("zdMarks",[]):result.append(mark("zhenjian-rule",str(detail),str(detail),"d6b273"))
	for detail in unit.get("apeSleeveMarks",[]):result.append(mark("ape-sleeve",str(detail),str(detail),"b0c898"))
	for detail in unit.get("chargedMarks",[]):result.append(mark("charged-card",str(detail),str(detail),"97b997"))
	for detail in unit.get("rpMarks",[]):result.append(mark("red-purple",str(detail),str(detail),"c1a5bc"))
	for detail in unit.get("msMarks",[]):result.append(mark("mirror-song",str(detail),str(detail),"a9c4bf"))
	for detail in unit.get("yiMarks",[]):result.append(mark("yi-rule",str(detail),str(detail),"c7b9a0"))
	for detail in unit.get("futakuchiMarks",[]):result.append(mark("futakuchi-rule",str(detail),str(detail),"a8bf8b"))
	for detail in unit.get("boxMaidenMarks",[]):result.append(mark("box-maiden",str(detail),str(detail),"c1a1d8"))
	for detail in unit.get("blackWhiteMarks",[]):result.append(mark("black-white-rule",str(detail),str(detail),"dedbcc"))
	for detail in unit.get("blueGreenMarks",[]):result.append(mark("blue-green-rule",str(detail),str(detail),"8eb9d1"))
	for detail in unit.get("mianMarks",[]):result.append(mark("faction-rule",str(detail),str(detail),"8eb9d1"))
	for detail in unit.get("twoFacesMarks",[]):result.append(mark("two-faces-rule",str(detail),str(detail),"d8bb80"))
	for detail in unit.get("lanternMarks",[]):result.append(mark("lantern-rule",str(detail),str(detail),"e2ad70"))
	for detail in unit.get("seaSpiritMarks",[]): result.append(mark("sea-spirit",str(detail),str(detail),"80cfce"))
	for detail in unit.get("toxicMarks",[]): result.append(mark("toxic-rule",str(detail),str(detail),"b1ca70"))
	for detail in unit.get("susanooMarks",[]): result.append(mark("susanoo-rule",str(detail),str(detail),"e5d080"))
	for detail in unit.get("baizeMarks",[]): result.append(mark("baize-rule",str(detail),str(detail),"a0d0b0"))
	for detail in unit.get("crocodileMarks",[]): result.append(mark("crocodile-rule",str(detail),str(detail),"70b090"))
	for detail in unit.get("whaleMarks",[]): result.append(mark("whale-rule",str(detail),str(detail),"80c0e0"))
	for detail in unit.get("jorogumoMarks",[]): result.append(mark("spider-rule",str(detail),str(detail),"d080c0"))
	for detail in unit.get("yitiaoMarks",[]): result.append(mark("yitiao-rule",str(detail),str(detail),"d0b880"))
	for detail in unit.get("battleSkillMarks",[]): result.append(mark("battle-skill",str(detail),str(detail),"d5a3cf"))
	for detail in unit.get("cottonMarks",[]): result.append(mark("cotton-rule",str(detail),str(detail),"8ba9d8"))
	for detail in unit.get("spiderLilyMarks",[]): result.append(mark("spider-lily-rule",str(detail),str(detail),"c46e85"))
	for detail in unit.get("threeTailMarks",[]): result.append(mark("threeTail-rule",str(detail),str(detail),"bfa0b0"))
	for detail in unit.get("gluttonMarks",[]): result.append(mark("glutton-rule",str(detail),str(detail),"bfa0b0"))
	for detail in unit.get("dollMarks",[]): result.append(mark("doll-rule",str(detail),str(detail),"bfa0b0"))
	for detail in unit.get("onikiriMarks",[]): result.append(mark("onikiri-rule",str(detail),str(detail),"bc97ce"))
	for detail in unit.get("otakemaruMarks",[]): result.append(mark("otake-rule",str(detail),str(detail),"a2b3cd"))
	for detail in unit.get("houseMarks",[]): result.append(mark("house-rule",str(detail),str(detail),"c0a060"))
	for detail in unit.get("goldfishMarks",[]): result.append(mark("goldfish-rule",str(detail),str(detail),"e2b57a"))
	for detail in unit.get("vineMarks",[]): result.append(mark("vine-rule",str(detail),str(detail),"a294c5"))
	for detail in unit.get("puppetMarks",[]): result.append(mark("puppet-rule",str(detail),str(detail),"c2a5d5"))
	for detail in unit.get("weaverMarks",[]): result.append(mark("weaver-rule",str(detail),str(detail),"af97cf"))
	for detail in unit.get("headlessMarks",[]): result.append(mark("headless-rule",str(detail),str(detail),"c2a5d5"))
	if active and ContentLoader.runtime_unit_def(unit).get("sparrowNight",false): result.append(mark("sparrow-night","入夜%d/10" % int(unit.get("mapleNightValue",0)),"入夜条件成功或不足后增加1点入夜值都触发入夜时；资源不消耗。","a7bad5"))
	if active and (unit.get("formRules",{}).get("sparrowSubstitute",false) or unit.get("formRules",{}).get("substitute",false)): result.append(mark("sparrow-substitute","替身 · 免于本次气绝","将要气绝时移除形态与附加状态，恢复基础身躯；不视为气绝或复活。","a7bad5"))
	if active and ContentLoader.runtime_unit_def(unit).get("yakshaRules",false): result.append(mark("yaksha-night","入夜%d/10 · 成长%s" % [int(unit.get("mapleNightValue",0)),"不限次" if unit.awakened else ("本回合已用" if int(unit.get("yakshaStrengthTurn",-1))==turn else "本回合可用")],"每个入夜X效果结算后获得1力量；觉醒前每回合一次，直接获得入夜值不触发。","ad9bce"))
	for detail in unit.get("pineMarks",[]): result.append(mark("pine-rule",str(detail),str(detail),"c09040"))
	if active and ContentLoader.runtime_unit_def(unit).get("paintBasic",false): result.append(mark("paint-field", "画境耐久%d" % int(unit.get("paintDurability",0)), "召唤画境时融合现有画境并继承耐久；相关法术会移除画境兑现效果。", "d4a0b8"))
	if alive and unit.get("paintSummon",false): result.append(mark("paint-scroll", "丹青绘卷 · 回合开始自毁", "己方回合开始按当前生命召唤画境；离开战斗区移除。", "d4a0b8"))
	if unit.get("samuraiGhost",false) and not unit.get("baseRulesSuppressed",false): result.append(mark("samurai-ghost", "幽魂 · 直击 · 不能阻挡", "仍处于气绝，生命为0；可以出击并使用专属牌，正常计时复活后恢复肉身。", "bdacd8"))
	if unit.get("samuraiCannotRevive",false): result.append(mark("samurai-no-revive", "不能复活 · 永久迅捷", "觉醒后任何复活方式均无效；每回合普通出击不消耗鬼火，仍占出击次数。", "bdacd8"))
	if active and ContentLoader.runtime_unit_def(unit).get("mapleNight",false): result.append(mark("maple-night", "入夜%d/10" % int(unit.get("mapleNightValue",0)), "入夜条件未满足时获得1点入夜；获得入夜触发红叶投射，最多10点。", "d48b7c"))
	if active and int(unit.get("mapleDamageBonus",0))>0: result.append(mark("maple-dance", "非战斗伤害+%d" % int(unit.mapleDamageBonus), "跹舞之姿按当前每5点入夜增强红叶造成的非战斗伤害。", "d48b7c"))
	if alive and not unit.get("mapleDoll",{}).is_empty(): result.append(mark("maple-doll", "红枫娃娃 · 回合结束触发", "所属回合结束移除此灵咒并受2伤；来源方入夜10时对其他敌方角色各2伤，否则获得1入夜。", "d48b7c"))
	if active and ContentLoader.runtime_unit_def(unit).get("mapleNight",false) and unit.awakened: result.append(mark("maple-awaken-end", "觉醒入夜10 · "+("已触发" if unit.get("mapleAwakenUsed",false) else "尚未触发"), "己方回合结束时入夜10：投射10伤害，本局仅生效一次。", "d48b7c"))
	if alive and not unit.get("owlGuard",{}).is_empty(): result.append(mark("owl-guard", "鸮之守护 · 伤害-1", "护甲和暴击后每次减伤1；普通守护唯一，祈愿之翼后全体结附但不叠加。", "a3b7e8"))
	if alive and unit.get("owlUnyielding",false): result.append(mark("owl-guard", "鸮之庇佑 · 不屈", "本次守护与形态组合提供一次不屈，生效后消耗。", "a3b7e8"))
	if alive and int(unit.get("insectCorrosion",0))>0: result.append(mark("insect-corrosion", "蛊蚀×%d" % int(unit.insectCorrosion), "每层-1力量/-1生命上限及当前生命；属于灵咒，气绝移除。", "b4c58a",int(unit.insectCorrosion)))
	if alive and int(unit.get("owlBlockedTurn",-1))==turn and turn>=0: result.append(mark("owl-interfere", "干扰投掷 · 不能伤害守护目标", "持续当前回合，对没有鸮之守护的角色仍能正常造成伤害。", "a3b7e8"))
	if active and ContentLoader.runtime_unit_def(unit).get("oniAsuraRole")=="oni": result.append(mark("oni-first", "首抽 · "+str(unit.get("oniFirstCard","尚未抽牌")), "嗜杀冲动只读取本回合真正抽到的第一张牌，起手发牌不计。", "bf9bce"))
	if active and ContentLoader.runtime_unit_def(unit).get("oniAsuraRole")=="asura" and unit.awakened: result.append(mark("asura-transfer", "觉醒替伤 · "+("本回合可用" if unit.get("asuraReplacementReady",false) else "本回合已用"), "每回合第一次实际战斗伤害转为阿修罗对己方牌手的伤害。", "d58e85"))
	if active and ContentLoader.runtime_unit_def(unit).get("pipeFoxRole")=="white": result.append(mark("fox-immune", "小白免伤 · "+("本回合可用" if unit.get("foxImmunityReady",false) else "本回合已用"), "力量严格小于对手才触发；觉醒后被攻击时也可触发。", "c1d8ea"))
	if alive and not unit.get("garudaFeather",{}).is_empty(): result.append(mark("garuda-feather", "惜羽 · 出击伤害2", "所关联的迦楼罗主动出击时，对此式神造成2点伤害，然后移除此灵咒；不能叠加。", "c3ad83"))
	if alive and not unit.get("pipeMarks",[]).is_empty(): result.append(mark("pipe-mark", "狐怒印记×%d" % unit.pipeMarks.size(), "管狐倒计时触发时，每个印记使该效果额外命中此式神一次，然后移除。", "c1aedb"))
	if alive and unit.get("foxVeil",false): result.append(mark("fox-veil", "小白守护 · 帷幕", "持续至施放者的下个回合开始。", "c1d8ea"))
	if alive and not unit.get("moonCharm",{}).is_empty(): result.append(mark("moon-charm", "宵月 · "+("己方牌瞬发" if unit.awakened else "0鬼火时自身牌瞬发"), "使用符合条件的牌后移除此灵咒；瞬发仍为全队每回合一次。", "c2b4e8"))
	if active and unit.get("moonExtraAttack",false): result.append(mark("moon-extra", "清辉月华 · 宵月可换免费出击", "普通出击次数已用尽，可消耗宵月让任一合法己方式神免费出击。", "c2b4e8"))
	if active and ContentLoader.runtime_unit_def(unit).has("bambooRealmCards"): result.append(mark("bamboo-history", "竹取 · 耐久%d · 已召唤%d/5种" % [int(unit.get("bambooDurability",0)),int(unit.get("bambooDistinct",0))], "觉醒前仅耐久叠加；觉醒后能力也累积。", "adc9b3"))
	if alive and unit.get("treeHealthCombat", false): result.append(mark("health-combat", "神木庇佑 · 按生命战斗", "战斗伤害按当前生命计算，不改变力量面板。", "9ec797"))
	if alive and not unit.get("treeDisasters", []).is_empty(): result.append(mark("tree-disaster", "灾厄之花 · 下个己方回合结束自伤", "按结算时当前生命对自身造成伤害，护甲、屏障及不屈正常生效。", "bdacd8"))
	if active and unit.get("formRules", {}).get("treeRoot",false): result.append(mark("tree-root", "扎根 · 回合开始留在战斗区", "可被其他己方式神正常替换。", "9ec797"))
	if active and ContentLoader.runtime_unit_def(unit).get("treeSakuraRole") == "tree" and unit.awakened: result.append(mark("health-combat", "觉醒 · 力量等于当前生命", "受伤、恢复及形态变化时更新力量。", "9ec797"))
	if int(unit.get("blessingRestrictedTurn", -1)) == turn and turn >= 0:
		result.append(mark("blessing-limit", "福笹 · 本回合限制牌型", "不能使用幻境、形态或觉醒牌；本回合临时增加的等级在回合结束时归还。", "e2c58c"))
	if unit.get("blessingCanOverlevel", false): result.append(mark("blessing-overlevel", "十日戎 · 三勾仍可升级", "升级改为永久+5力量/+5生命，并随机获得一张本式神三勾牌。", "e2c58c"))
	if int(unit.get("blessingPermanentAttack", 0)) > 0: result.append(mark("blessing-growth", "十日戎 · 永久+%d/+%d" % [int(unit.blessingPermanentAttack), int(unit.blessingPermanentHp)], "此项永久成长在气绝后保留。", "e2c58c"))
	var definition := ContentLoader.runtime_unit_def(unit)
	if definition.get("monkCleanerRole") == "monk": result.append(mark("monk-history", "累计受伤%d/20" % int(unit.get("monkDamageTotal", 0)), "怒目金刚增强读取本局实际受伤记录；包含不屈挡下的伤害。", "e4bf79"))
	if unit.get("enraged", false): result.append(mark("enrage", "激怒 · 出击优先", "有可出击的激怒式神时只能令其普通出击，攻击后解除。", "efaa7b"))
	if unit.get("cleanerVeil", false): result.append(mark("cleaner-bath", "浴中歌 · 力量+1与帷幕", "随当前护甲和幻境存续即时更新。", "81d6d6"))
	if unit.get("monkFormUnyielding", false) and unit.get("formRules", {}).get("monkUnyielding", false): result.append(mark("unyielding", "不屈", "大于1生命时抵住一次致命伤害，生效后移除。", "e4bf79"))
	if definition.get("dreamMaster", false): result.append(mark("dream-deck", "敌库梦魇牌%d张" % int(unit.get("dreamCardCount", 0)), "抽到梦魇使牌手受3伤；支配者的身材与伤害替换读取牌库中的实际牌。", "b39ce6"))
	if unit.get("bondMoonPursuit", false): result.append(mark("bond-moon", "月下花 · 追猎", "本回合普通出击选择敌方式神；迅捷令下一次出击不消耗鬼火。", "e9baaa"))
	if int(unit.get("dreamPowerPenalty", 0)) > 0: result.append(mark("dream-penalty", "梦中低语 · 力量-%d" % int(unit.dreamPowerPenalty), "当前回合结束时移除。", "b39ce6"))
	if definition.get("eyeDivination", false): result.append(mark("eye-history", "瞳炎当前伤害%d" % (2 + int(unit.get("eyeFlameGrowth", 0))), "同名牌的永久伤害增强按实际使用记录计算。", "ba9ce6"))
	if int(unit.get("formRules", {}).get("eyeDivinationBonus", 0)) > 0: result.append(mark("eye-divination", "占卜效果+1", "也作用于由己方整理敌方牌库的占卜。", "ba9ce6"))
	if definition.get("crabSameName", false): result.append(mark("crab-instant", "已用同名牌瞬发", "觉醒后也作用于其他己方式神的手牌。" if unit.get("awakened", false) else "当前仅作用于蟹姬自己的手牌。", "e9ba86"))
	if unit.get("formRules", {}).get("crabBounce", false): result.append(mark("crab-bounce", "弹回 · 追击%s" % ("本回合已用" if int(unit.get("crabAttackTurn", -1)) == turn else "可用"), "战斗/法术牌有一次弹回；每回合首次重用同名牌后免伤攻击。", "e9ba86"))
	if definition.get("windCountdown", false) and int(unit.get("windStoredPower", 0)) > 0: result.append(mark("wind-power", "势 · 攻击结束前力量+%d" % int(unit.windStoredPower), "来源是倒计时实际减少量；攻击结束时移除。", "a4df9a"))
	if definition.get("nightRealm", false): result.append(mark("night-power", "幻境力量+%d" % int(unit.get("nightRealmPower", 0)), "随真实存续幻境实时变化；觉醒后的先攻仅主动攻击生效。", "b39ce6"))
	if unit.get("formRules", {}).get("nightCoverAll", false): result.append(mark("night-cover", "永劫轮回 · 幻境保护全队", "日轮之城承接战斗伤害，新月之哀承接非战斗伤害；范围伤害统一降低耐久。", "b39ce6"))
	if definition.get("coinMaster", false): result.append(mark("coin-history", "本回合已用%d枚钱币" % int(unit.get("coinsUsed", 0)), "钱儿响叮当与骗局读取本回合实际使用次数；天降横财逐张使用钱币。", "e2c58c"))
	if definition.get("riverFortune", false): result.append(mark("river-history", "累计骰子%d点 · 本回合骰点+%d" % [int(unit.get("riverRollTotal", 0)), int(unit.get("riverDieBonus", 0))], "每次真实掷骰和重投均计入累计；占卜完成后鲤之缘提升本回合骰点，上限6。", "81c8d6"))
	if active and unit.get("formRules", {}).get("coinDamageGuard", false): result.append(mark("coin-guard", "有鼠如宝 · 钱币响应免伤", "对手回合受伤前自动使用可支付的钱币，仅免疫当前这一段伤害。", "e2c58c"))
	if definition.get("fortuneRole", "") != "": result.append(mark("fortune-six-history", "已投6点 %d次 · %d种点数" % [int(unit.get("fortuneSixes", 0)), int(unit.get("fortuneDistinct", 0))], "记录己方实际骰面，包含重投；成功次数另外计算。", "e2c58c"))
	if unit.get("baseRulesSuppressed", false) and not unit.has("susanooOriginal"): result.append(mark("paper-transform", "纸人 · 能力失效", "失去原形态、初始和觉醒能力。", "e2c58c"))
	if definition.get("foxSuzukaRole") == "fox": result.append(mark("fox-history", "伤害 %d/25次 · 风弹+%d" % [int(unit.get("foxDamageEvents", 0)), int(unit.get("foxAbilityBonus", 0))], "狂风刃卷记录妖狐实际造成的伤害次数；聚气永久提高能力伤害，不提高法术伤害。", "e2c58c"))
	if unit.get("formRules", {}).get("suzukaImmuneMarked", false): result.append(mark("marked-immunity", "霸主 · 免疫带破甲式神伤害", "敌方式神有破甲时，其对铃鹿御前造成的伤害被免疫。", "81d6d6"))
	var light_role := str(definition.get("lightRole", ""))
	if light_role == "fortune": result.append(mark("fortune-history", "双方运势 %d/12" % int(unit.get("lightFortuneTotal", 0)), "本局双方运势判定成功次数；重投只计最终结果。", "e2c58c"))
	if light_role == "monk":
		result.append(mark("monk-history", "牌手被攻击 %d次" % int(unit.get("lightAvatarAttacks", 0)), "轮回按牌手受到敌方攻击的次数增强；法术伤害和式神交战不计。", "81d6d6"))
		if unit.get("lightImmune", false): result.append(mark("monk-immunity", "舍生 · 牌手本回合免伤", "保护持续至当前回合结束，青坊主气绝不移除。", "e2c58c"))
	if unit.has("judgeKills"):
		result.append(mark("judge-kills", "消灭进度 %d/13" % int(unit.judgeKills), "记录本局己方消灭的式神；气绝后保留。用于断罪与夺命的增强。", "e2c58c", int(unit.judgeKills)))
	if unit.has("enemyStuns"):
		result.append(mark("snow-history", "眩晕记录 %d" % int(unit.enemyStuns), "本局敌人新进入眩晕的次数，用于手牌雪融之时的增强。", "91cfe8", int(unit.enemyStuns)))
	if unit.has("snowballsPlayed"):
		result.append(mark("snow-history", "雪球已用%d · 伤害%d" % [int(unit.snowballsPlayed), 1 + int(unit.snowballBonus)], "流霰按本局从手牌使用雪球的数量增加自动施法次数；寒冬之心永久提高雪球伤害。", "91cfe8"))
	if unit.get("iceWall", false): result.append(mark("snow-immune", "冰墙 · 不能攻击", "0/4召唤物；眩晕对其造成战斗伤害的式神。离开战斗区移除；回合开始不退后。", "91cfe8"))
	if int(unit.get("snowCombatStunTurn", -1)) == turn and turn >= 0: result.append(mark("snow-immune", "寒冰之盾 · 战斗伤害眩晕", "本回合眩晕受到其战斗伤害的式神；护甲全部挡住时不触发。", "91cfe8"))
	if unit.has("feathersPlayed"): result.append(mark("crane-power", "黄金羽已用 %d" % int(unit.feathersPlayed), "本局使用黄金羽的次数，用于风之舞增强；气绝后保留。", "e2c58c"))
	if unit.get("featherImmune", false): result.append(mark("snow-immune", "不可饶恕 · 本回合免疫战斗伤害", "本回合已使用黄金羽；法术伤害与直接消灭仍正常结算。", "e2c58c"))
	if definition.get("rebirthRole")=="cat": result.append(mark("cat-lives","九命 · %d/5" % int(unit.get("catLives",0)),"第五层时不能复活并移除所属手牌和牌库牌，保留向死而生。", "e8b583",int(unit.get("catLives",0))))
	if definition.get("foxLotusRole")=="fox": result.append(mark("spell-power","永久法伤 +%d" % int(unit.get("foxSpellBonus",0)),"仅玉藻前法术，手牌外施法不增加此数值；基础投射不受此加成。","e9b277",int(unit.get("foxSpellBonus",0))))
	if not unit.get("lotusCharm",{}).is_empty(): result.append(mark("lotus-charm","莲华 · 力量-%d" % int(unit.get("lotusPowerPenalty",1)),"唯一灵咒，新的结附取代己方之前的莲华；气绝时移除。","c6aae7"))
	if unit.get("lotusDamageBlocked",false): result.append(mark("spell-immune","理想国 · 不能造成伤害","战斗、法术和能力伤害均无效，不阻止消灭或其他非伤害效果。","c6aae7"))
	var incarnation: Dictionary=unit.get("incarnationConfig",{})
	if not incarnation.is_empty() and definition.get("rebirthRole")!="skeleton": result.append(mark("incarnation","化身 · %d%% · 本回合%d/%d次" % [int(unit.get("incarnationChance",0)),int(unit.get("incarnationCount",1)) if int(unit.get("incarnationUsedTurn",-1))==turn else 0,int(incarnation.limit)],"回合开始+%d%%，出牌/出击+%d%%。自动生成合法牌，不消耗手牌或鬼火。" % [int(incarnation.start),int(incarnation.action)],"b89be4"))
	if definition.get("rebirthRole")=="skeleton" and unit.get("awakened",false) and not alive: result.append(mark("incarnation","气绝化身 · %d%%" % int(unit.get("incarnationChance",0)),"回合开始+20%，出牌/出击+8%；每回合最多一次，自动生成合法气绝法术，不耗鬼火。","b89be4"))
	if unit.get("samuraiCannotRevive",false): result.append(mark("knockout","永久气绝 · 幽魂不能复活","觉醒武士之灵保留幽魂，可出击和用牌，任何方式均不能复活。", "b89be4"))
	elif unit.get("catCannotRevive",false): result.append(mark("knockout","永久气绝 · 不能复活","向死而生可解除；通常复活和气绝倒计时无效。","b89be4"))
	elif not alive:
		result.append(mark("knockout", "气绝 · %d 回合" % int(unit.get("knockout", 0)), "气绝倒计时归零后复活。", "b89be4", int(unit.get("knockout", 0))))
	var timer: Dictionary = Countdown.timer(unit)
	if not timer.is_empty():
		var ability := str(Countdown.mode(unit).get("name", "")) if timer.has("mode") else str(timer.get("card", {}).get("name", ""))
		var pause := "（气绝暂停）" if not alive else ("（未激活）" if not active else "")
		result.append(mark("countdown", "倒计时 %d · %s%s" % [int(timer.remaining), ability, pause], "能力倒计时，与气绝倒计时独立。", "e892a8", int(timer.remaining), active))
	if active:
		if definition.get("armorBloodRole") == "whale": result.append(mark("armor-power", "护甲力量 +%d" % (int(unit.shield) if unit.get("awakened", false) else (1 if int(unit.shield) > 0 else 0)), "力量随当前护甲变化，护甲损失后立即重算。", "81c8d6"))
		if definition.get("armorBloodRole") == "vampire": result.append(mark("blood-growth", "回复成长 · 每次最多5" if unit.get("awakened", false) else "回复成长 · 每次1力量1护甲", "仅己方牌手实际恢复生命时触发；式神恢复或满血治疗不触发，气绝移除所得普通成长。", "e892a8"))
		if unit.get("bloodTransfer", false): result.append(mark("blood-transfer", "血蝠之盾 · 下次伤害转移", "先结算本式神护甲与破甲，再由本方牌手承受剩余伤害；不等于不屈。", "e892a8"))
		if int(unit.get("whaleGiftTurn", -1)) == turn and turn >= 0: result.append(mark("armor-power", "白骨之盾 · 本回合有甲+1力量", "临时获得基础能力；护甲的自然过期时间独立计算。", "81c8d6"))
		if unit.get("bloodEmbrace", []).any(func(e): return int(e.turn) == turn): result.append(mark("blood-embrace", "初拥 · 本回合战斗伤害恢复牌手", "每段战斗伤害分别按伤害量恢复施放初拥的牌手；不提供固定回血。", "e892a8"))
		if Combat.has(unit, "lifesteal"): result.append(mark("lifesteal", "吸血", Glossary.detail("lifesteal"), "e892a8"))
		if unit.get("formRules", {}).get("bloodSpellLifeSteal", false): result.append(mark("spell-power", "猩红之月 · 己方法术吸血", "包括其他己方式神的法术；能力伤害不因此获得吸血。", "e892a8"))
		if definition.get("tomatoFireRole") == "sister" and not unit.get("awakened", false): result.append(mark("extra-fire", "出击／战斗牌额外1鬼火", "费用已计入合法性与实际支付；气绝复活牌也需要额外1鬼火。", "e06040"))
		if unit.has("tomatoSplash"): result.append(mark("tomato-splash", "番茄 · 永久力量+%d · 出击叠加%d" % [int(unit.get("tomatoPower", 0)), int(unit.tomatoSplash)], "每次攻击造成伤害，向另一个随机敌方角色造成3伤；每层分别结算。", "e06040"))
		if unit.get("burnEntity", false): result.append(mark("burn-replacement", "烬染不夜 · 随机两段", "攻击改为两个随机敌方角色各受等同力量的伤害；仍消耗出击次数，可接受鼓舞。", "f08850"))
		if unit.get("poisonRetained", false): result.append(mark("armor-break-retained", "破甲保留", "己方回合开始不会清除破甲；仍会被护甲抵消或伤害引爆。", "bdacd8"))
		if int(unit.get("poisonReduction", 0)) > 0: result.append(mark("armor-break-reduction", "火吻之蛇 · 力量 -%d" % int(unit.poisonReduction), "按当前破甲动态降低力量；破甲消耗或形态离场后解除。", "bdacd8"))
		if int(unit.get("poisonShieldTurn", -1)) == turn and turn >= 0: result.append(mark("poison-shield", "剧毒之盾 · 战斗伤害后3破甲", "仅本回合；须实际对式神造成战斗伤害。", "bdacd8"))
		if light_role == "lantern" and unit.get("awakened", false): result.append(mark("lantern-retain", "鬼火保留 · 上限4", "己方回合开始额外获得2点鬼火，已有鬼火不会清除。", "e2c58c"))
		if light_role == "fortune": result.append(mark("fortune-reroll", "失败重投一次" if unit.get("awakened", false) else "掷出1重投一次", "每次判定至多重投一次，气绝时不生效。", "e2c58c"))
		if unit.get("formRules", {}).get("monkHealDraw", false): result.append(mark("monk-draw", "禅心 · 每回合首次回复抽牌", "只在牌手实际回复生命时触发。", "81d6d6"))
		if unit.get("formRules", {}).get("enemyHealingIsDamage", false): result.append(mark("monk-convert", "对敌治疗转为伤害", "己方来源给予敌方的回复效果改为伤害。", "e892a8"))
		if definition.get("snowCombat", false): result.append(mark("snow-immune", "冰雪免伤 · 攻击眩晕目标并先击一次" if unit.get("awakened", false) else "冰雪免伤 · 与眩晕单位交战", "仅符合条件时免疫战斗伤害；不免疫法术与直接消灭。", "91cfe8"))
		var cap := int(unit.get("formRules", {}).get("damageCap", 0))
		if cap > 0: result.append(mark("snow-cap", "雪融 · 每次至多受%d伤害" % cap, "护甲抵消后限制本次伤害；各段伤害分别结算。", "91cfe8", cap))
		if definition.get("craneRetreat", false) and not unit.get("awakened", false): result.append(mark("crane-retreat", "攻击后退回准备区", "仍进入战斗区并承受正常反击；觉醒后由远程取代此能力。", "c6d7a0"))
		if int(unit.get("cranePower", 0)) > 0: result.append(mark("crane-power", "影翼成长 +%d力量" % int(unit.cranePower), "每次攻击前成长；气绝后清除。", "c6d7a0", int(unit.cranePower)))
		if int(unit.get("judgeInkAttack", 0)) > 0:
			result.append(mark("judge-ink", "墨笔 · 力量 -%d / 生命 -%d" % [int(unit.judgeInkAttack), int(unit.judgeInkHp)], "减益随式神气绝移除，切换形态不会清除。", "bdacd8"))
		if unit.get("formRules", {}).get("enemyKnockoutExtra", 0) > 0:
			result.append(mark("judge-aura", "无情 · 敌方气绝倒计时 +1", "影响生效期间新发生的气绝，不追溯延长已有气绝。", "c6a1d9"))
		if definition.get("tideRestoration", false):
			result.append(mark("tide-overheal", "过量治疗 → 护甲与力量" if unit.get("awakened", false) else "过量治疗 → 护甲", "海坊主对己方造成的过量治疗按过量数值转换；牌手只能获得护甲。", "81d6d6"))
		if unit.get("formRules", {}).get("healSelfOnAvatarRestore", false):
			result.append(mark("tide-mirror", "灵能 · 治疗牌手时回复自身", "海坊主为牌手恢复生命时，为自身恢复等量生命。", "81d6d6"))
		if unit.get("formRules", {}).get("combatHealOthers", false):
			result.append(mark("tide-wave", "蹈海 · 战斗伤害治疗其他友方", "每次造成战斗伤害时，治疗己方牌手及其他式神；不包含海坊主自身。", "81d6d6"))
		var combat_heal := 0
		for entry in unit.get("tideCombatHeals", []):
			if turn < 0 or int(entry.turn) == turn: combat_heal += int(entry.amount)
		if combat_heal > 0:
			result.append(mark("tide-combat-heal", "沧海之盾 · 战斗伤害回复牌手 %d" % combat_heal, "仅本回合生效；伤害全被护甲或屏障抵挡时不触发。", "81d6d6", combat_heal))
		for keyword in ["pierce", "penetration", "remote", "combo", "first-strike", "crit"]:
			if Combat.has(unit, keyword): result.append(mark(keyword, Glossary.label(keyword), Glossary.detail(keyword), "e2c58c"))
		var buff: Dictionary = unit.get("untilAttack", {})
		if int(buff.get("attack", 0)) > 0:
			result.append(mark("spell-power", "法术强化 +%d力量" % int(buff.attack), "残心保留强化" if unit.get("formRules", {}).get("retainSpellEnhancements", false) else "下一次攻击结束后移除；跨回合保留。", "e0ba80", int(buff.attack)))
		if unit.get("formRules", {}).get("retainSpellEnhancements", false): result.append(mark("retain-spell", "残心 · 保留法术强化", "白狼的法术强化不会因攻击结束而消失。", "b4d6ce"))
		if unit.get("formRules", {}).get("zeroPowerEnemyTurn", false): result.append(mark("clumsy", "笨拙 · 敌方回合力量为0", "在对方回合，战斗牌提供的力量加成也无法生效。", "c5b7db"))
		if definition.get("mountainGrowth", false) and unit.get("awakened", false): result.append(mark("spell-immune", "免疫敌方非战斗伤害", "仍会受到战斗伤害与己方造成的伤害；不阻止直接消灭。", "84c9d5"))
		if unit.has("privateShotHints"): result.append(mark("private-shot", "会 · " + "；".join(unit.privateShotHints), "下个己方回合开始结算，目标仅己方可见。", "d8c19a", unit.privateShotHints.size()))
		if int(unit.get("frozen", 0)) > 0: result.append(mark("stun", "眩晕 ×%d" % int(unit.frozen), "保留眩晕状态，但忽略其不能出击与用牌的限制。" if unit.get("ignoresStun",false) else "不能主动出击或使用所属牌；仍能反击。持续至持有者下个回合结束。", "b39ce6", int(unit.frozen)))
		if unit.get("ignoresStun",false): result.append(mark("ignore-stun", "忽略眩晕状态效果", "眩晕并未被移除，仍满足眩晕目标条件。", "b39ce6"))
		if unit.get("stunInstant",false): result.append(mark("stun-instant", "饮啖醉饱 · 专属牌获得瞬发", "共享每个玩家回合一次瞬发额度；未眩晕的式神不获得该效果。", "b39ce6"))
		if unit.has("movementHolders"): result.append(mark("crow-stun-hold", "英雄无畏 · 保持眩晕", "直到施放此牌的鸦天狗使用牌、攻击或气绝；其他眩晕独立保留。", "b39ce6"))
		if unit.get("barrier", false): result.append(mark("barrier", "屏障 · 抵挡下一次伤害", "抵挡一次伤害后消失，与护甲和破甲分别结算。", "76d9cf"))
		if unit.get("swift", false) or buff.get("swift", false) or (definition.get("yaodaoFlurry", false) and unit.get("awakened", false)):
			var permanent: bool = (definition.get("yaodaoFlurry", false) and unit.get("awakened", false)) or unit.get("catPermanentSwift",false) or (definition.get("yitiaoRules",false) and unit.get("awakened",false))
			result.append(mark("swift", "永久迅捷 · 每回合出击免鬼火" if permanent else "迅捷 · 下次普通出击不消耗鬼火", "不增加全队普通出击次数；战斗牌不消耗迅捷。", "a4df9a"))
		if Combat.has(unit, "inspired"): result.append(mark("inspired", "昂扬 · 下次普通出击不消耗次数", "鬼火仍正常支付；战斗牌和自动攻击不消耗这次昂扬。", "ffda70"))
		if unit.get("shutenFormUnyielding", false): result.append(mark("unyielding", "不屈 · 生效后移除", "本形态抵挡一次致命伤害，生命保留为1，生效后消失。", "f0ce7b"))
		elif unit.get("unyielding", false) or unit.get("combatUnyielding", false) or unit.get("formRules", {}).get("riverUnyielding", false) or buff.get("unyielding", false): result.append(mark("unyielding", "不屈", "致命伤害保护，具体持续方式见来源牌文。", "f0ce7b"))
		if turn >= 0 and int(unit.get("shutenHowlTurn", -1)) == turn: result.append(mark("howl", "狂啸 · 本回合生命至少为1", "本回合所有伤害均不能将生命降到1以下，回合结束消失。", "f0b871"))
		for spec in [["armorBreak", "armor-break", "破甲", "e98d60"], ["charge", "charge", "充能", "65d0df"], ["brittle", "brittle", "晶裂", "e08aa2"]]:
			var amount := int(unit.get(spec[0], 0))
			if amount > 0: result.append(mark(spec[1], "%s %d" % [spec[2], amount], "%s：当前剩余 %d。" % [spec[2], amount], spec[3], amount))
		if turn >= 0 and int(unit.get("yaodaoInstantTurn", -1)) == turn: result.append(mark("instant", "战斗牌瞬发 · 本回合", "妖刀姬的战斗牌获得瞬发，共享全队本回合额度。", "87daca"))
		if turn >= 0 and int(unit.get("yaodaoFreeCombatTurn", -1)) == turn: result.append(mark("free", "战斗牌免鬼火 · 本回合", "妖刀姬本回合战斗牌不消耗鬼火。", "aedecb"))
		if unit.get("formRules", {}).get("lockEnemyFrontReplacement", false) and int(unit.get("front", 0)) == 1: result.append(mark("lock", "尘缚 · 敌方不能替换战斗区式神", "兵俑位于战斗区时生效，离开战斗区后解除。", "dfbb82"))
		if int(unit.get("flashAttackReduction", 0)) > 0 and turn >= 0 and int(unit.get("flashAppliedTurn", -1)) == turn: result.append(mark("weaken", "闪烁 · 本回合力量 -%d" % int(unit.flashAttackReduction), "本回合结束恢复这部分力量。", "c6a1d9", int(unit.flashAttackReduction)))
		if unit.has("formExpiresTurn") and (turn < 0 or int(unit.formExpiresTurn) == turn): result.append(mark("expire", "本回合结束自毁", "风符·瞬将在本回合结束时被摧毁。", "e9a782"))
		var pending := 0
		for entry in unit.get("pendingShields", []): pending += int(entry.amount)
		if pending > 0: result.append(mark("pending-armor", "下回合护甲 +%d" % pending, "预约护甲尚未获得，气绝后取消。", "8bbfe6", pending))
		if definition.has("bingyongArmor") and unit.get("awakened", false): result.append(mark("retain-armor", "护甲不会自然消失", "觉醒兵俑保留回合开始时的护甲。", "8bbfe6"))
	if unit.get("awakened", false): result.append(mark("awakened", "已觉醒", "觉醒在气绝后仍然保留。", "cea5eb"))
	return result

static func badge_layout(marks: Array, size: Vector2) -> Array:
	# Leave the level, name flag, HP/armor and countdown unobstructed. Extra
	# statuses remain explicitly discoverable through +N and the full inspector.
	var visible: Array = marks.filter(func(m): return m.id not in ["knockout", "countdown", "awakened"])
	var count := mini(visible.size(), 6)
	var diameter := clampf(size.x * 0.17, 16, 22)
	var result: Array = []
	for i in count:
		var item: Dictionary = visible[i]
		if i == 5 and visible.size() > 6:
			item = mark("overflow", "+%d" % (visible.size() - 5), "打开式神详情查看全部状态。", "d4c9ba", visible.size() - 5)
		result.append({"mark": item, "rect": Rect2(3 + (i / 3) * (diameter + 3), size.y * 0.27 + (i % 3) * (diameter + 4), diameter, diameter)})
	return result

static func draw_symbol(canvas: CanvasItem, center: Vector2, radius: float, id: String, color: Color) -> void:
	var r := radius
	match id:
		"cat-lives":
			canvas.draw_circle(center+Vector2(0,r*0.35),r*0.5,color)
			for i in 4:
				var angle := PI*1.1+i*PI*0.27
				canvas.draw_circle(center+Vector2.from_angle(angle)*r*0.8,r*0.21,color)
		"incarnation":
			canvas.draw_arc(center,r,0,TAU,24,color,1.5,true)
			canvas.draw_arc(center,r*0.55,-PI*0.8,PI*0.4,16,color,2,true)
		"judge-kills", "judge-aura", "judge-ink":
			canvas.draw_line(center + Vector2(0, -r), center + Vector2(0, r), color, 1.6, true)
			canvas.draw_line(center + Vector2(-r, -r * 0.3), center + Vector2(r, -r * 0.3), color, 1.6, true)
			for x in [-0.65, 0.65]:
				canvas.draw_arc(center + Vector2(x, -0.1) * r, r * 0.38, 0, PI, 12, color, 1.5, true)
		"tide-overheal", "tide-mirror", "tide-wave", "tide-combat-heal":
			for y in [-0.35, 0.35]:
				canvas.draw_polyline(PackedVector2Array([center + Vector2(-1, y + 0.2) * r, center + Vector2(-0.3, y - 0.2) * r, center + Vector2(0.3, y + 0.2) * r, center + Vector2(1, y - 0.2) * r]), color, 1.6, true)
		"pierce", "penetration", "remote":
			canvas.draw_line(center + Vector2(-r, r * 0.65), center + Vector2(r, -r * 0.65), color, 1.8, true)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(r * 0.15, -r * 0.7), center + Vector2(r, -r * 0.65), center + Vector2(r * 0.75, r * 0.1)]), color, 1.8, true)
			if id == "penetration": canvas.draw_line(center + Vector2(0, -r), center + Vector2(0, r), color, 1.4, true)
			if id == "remote": canvas.draw_arc(center + Vector2(-r * 0.4, 0), r * 0.85, -PI / 2, PI / 2, 16, color, 1.4, true)
		"combo", "first-strike":
			for x in ([-0.4, 0.4] if id == "combo" else [0.0]):
				canvas.draw_line(center + Vector2(x - 0.3, 0.9) * r, center + Vector2(x + 0.3, -0.9) * r, color, 2, true)
		"private-shot":
			canvas.draw_arc(center + Vector2(0, r * 0.8), r * 1.35, -PI * 0.79, -PI * 0.21, 16, color, 1.5, true)
			canvas.draw_arc(center + Vector2(0, -r * 0.8), r * 1.35, PI * 0.21, PI * 0.79, 16, color, 1.5, true)
			canvas.draw_circle(center, r * 0.28, color)
		"spell-power":
			canvas.draw_line(center + Vector2(0, r), center + Vector2(0, -r * 0.7), color, 2, true)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-0.6, -0.1) * r, center + Vector2(0, -0.8) * r, center + Vector2(0.6, -0.1) * r]), color, 2, true)
		"spell-immune":
			var points := PackedVector2Array()
			for i in 7: points.append(center + Vector2.from_angle(i * TAU / 6) * r)
			canvas.draw_polyline(points, color, 1.6, true)
			canvas.draw_line(center + Vector2(-r * 0.45, r * 0.45), center + Vector2(r * 0.45, -r * 0.45), color, 1.6, true)
		"clumsy":
			canvas.draw_arc(center, r * 0.8, 0, TAU, 24, color, 1.6, true)
			canvas.draw_line(center + Vector2(-r, r), center + Vector2(r, -r), color, 1.6, true)
		"retain-spell":
			for x in [-0.45, 0.45]: canvas.draw_arc(center + Vector2(x * r, 0), r * 0.6, 0, TAU, 20, color, 1.5, true)
		"instant", "charge":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.2, -1) * r, center + Vector2(-0.8, 0.15) * r, center + Vector2(-0.1, 0.15) * r, center + Vector2(-0.3, 1) * r, center + Vector2(0.85, -0.3) * r, center + Vector2(0.1, -0.3) * r]), color)
		"barrier", "armor-break", "pending-armor", "retain-armor":
			var pts := PackedVector2Array([center + Vector2(-0.75, -0.85) * r, center + Vector2(0.75, -0.85) * r, center + Vector2(0.65, 0.25) * r, center + Vector2(0, 1) * r, center + Vector2(-0.65, 0.25) * r, center + Vector2(-0.75, -0.85) * r])
			canvas.draw_polyline(pts, color, 1.6, true)
			if id == "armor-break": canvas.draw_line(center + Vector2(-0.3, -0.75) * r, center + Vector2(0.35, 0.65) * r, color, 2, true)
			elif id == "barrier": canvas.draw_arc(center, r * 1.3, 0, TAU, 24, Color(color, 0.5), 1, true)
		"inspired":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.65, r * 0.55), center + Vector2(0, -r * 0.65), center + Vector2(r * 0.65, r * 0.55)]), color, 1.7, true)
			canvas.draw_line(center + Vector2(0, -r * 0.5), center + Vector2(0, r * 0.7), color, 1.4, true)
		"swift", "crane-retreat", "crane-power":
			for direction in [-1, 1]:
				canvas.draw_colored_polygon(PackedVector2Array([center, center + Vector2(direction, -0.65) * r, center + Vector2(direction * 0.65, 0.4) * r, center + Vector2(direction * 0.2, 0.75) * r]), color)
		"unyielding", "howl":
			var points := PackedVector2Array([center + Vector2(-0.85, -0.45) * r, center + Vector2(-0.45, -0.85) * r, center + Vector2(0, -0.35) * r, center + Vector2(0.45, -0.85) * r, center + Vector2(0.85, -0.45) * r, center + Vector2(0.7, 0.1) * r, center + Vector2(0, 0.95) * r, center + Vector2(-0.7, 0.1) * r, center + Vector2(-0.85, -0.45) * r])
			canvas.draw_polyline(points, color, 1.6, true)
			if id == "howl": canvas.draw_line(center + Vector2(-r * 0.35, 0), center + Vector2(r * 0.35, 0), color, 2, true)
		"stun", "snow-history", "snow-immune", "snow-cap":
			for i in 3:
				var d := Vector2.from_angle(i * PI / 3.0) * r
				canvas.draw_line(center - d, center + d, color, 1.7, true)
		"brittle":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.7, 0), center + Vector2(0, r), center + Vector2(-r * 0.7, 0), center + Vector2(0, -r)]), color, 1.5, true)
		"countdown", "knockout", "expire":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.8, -1) * r, center + Vector2(0.8, -1) * r, center + Vector2(0.2, 0) * r, center + Vector2(0.65, 1) * r, center + Vector2(-0.65, 1) * r, center + Vector2(-0.2, 0) * r]), color)
			for y in [-1, 1]: canvas.draw_line(center + Vector2(-r, y * r), center + Vector2(r, y * r), color.lightened(0.25), 2, true)
		"lock":
			canvas.draw_arc(center + Vector2(0, -r * 0.3), r * 0.65, PI, TAU, 16, color, 1.5, true)
			canvas.draw_rect(Rect2(center + Vector2(-r * 0.7, -r * 0.2), Vector2(r * 1.4, r)), color)
		"response":
			canvas.draw_arc(center, r * 0.85, -PI * 0.8, PI * 0.6, 24, color, 1.7, true)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-1, 0.6) * r, center + Vector2(0, 0.95) * r, center + Vector2(-0.2, -0.1) * r]), color)
		"enhanced":
			for i in 4:
				var d := Vector2.from_angle(i * PI / 2) * r
				canvas.draw_line(center, center + d, color, 2, true)
		"weaken":
			canvas.draw_line(center + Vector2(0, -r), center + Vector2(0, r * 0.7), color, 2, true)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-0.6, 0.1) * r, center + Vector2(0, 0.8) * r, center + Vector2(0.6, 0.1) * r]), color, 2, true)
		_:
			canvas.draw_arc(center, r, 0, TAU, 24, color, 1.5, true)
