extends "res://scripts/verify_langyazi.gd"

const FOE := ["shantong", "hetong", "yaohu", "bingyong"]
const Status := preload("res://scripts/ui/battle_status.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("COOP_FIRST_FAIL ", detail)

func match_with(first: String, second: String) -> GS:
	var gs := GS.create([first, second, "shuweng", "fenghuanghuo"], FOE, 70123)
	prepare(gs)
	return gs

func face_play(gs: GS, id: String, source: String, target = null) -> bool:
	var idx := give(gs, id)
	var mode := id + ":" + source
	check(mode in gs.card_play_modes(0, idx), "列出真实分支 " + mode)
	var accepted := gs.play_card(0, idx, target, mode)
	check(accepted, "从手牌打出指定分支 " + mode)
	return accepted

func blade_and_crane() -> void:
	var gs := match_with("yaodaoji", "guniao")
	var own := gs.player(0)
	var enemy := gs.player(1)
	var blade: Dictionary = own.units[0]
	var crane: Dictionary = own.units[1]
	crane.level = 1
	var before: int = enemy.avatarHp
	if not face_play(gs, "c101109", "yaodaoji"): return
	check(blade.awakened and blade.get("coopFirstBlade", false) and enemy.avatarHp == before - int(crane.attack), "妖刀姬觉醒，低于牌勾的存活姑获鸟依然羁绊攻击")
	var iid := give(gs, "c10101")
	check("instant" not in gs.hand_card_def(0, iid).keywords, "他方式神击中牌手不触发刀影")
	gs._damage_avatar(1, 1, 0, 0)
	check("instant" in gs.hand_card_def(0, iid).keywords and not gs.hand_card_def(0, iid).get("yaodaoFreeCombat", false), "自身命中牌手后实际战斗牌获得瞬发并替换旧觉醒")
	before = int(enemy.avatarHp)
	check(gs.play_card(0, iid) and int(enemy.avatarHp) == before - int(blade.attack) - 1 and int(blade.shield) == 2, "刀影为本次实际战斗增加力量与护甲")

	gs = match_with("yaodaoji", "guniao")
	own = gs.player(0)
	enemy = gs.player(1)
	blade = own.units[0]
	crane = own.units[1]
	blade.level = 0
	if not face_play(gs, "c101109", "guniao"): return
	check(crane.awakened and not gs.VerifiedRules.Combat.has(crane, "remote") and int(enemy.avatarHp) == 30, "鹤唳替换远程觉醒，零勾妖刀不发起羁绊攻击")
	crane.hp = 1
	before = int(crane.attack)
	check(gs.basic_attack(0, 1) and int(crane.front) == 0 and int(crane.hp) == int(crane.maxHp) and int(crane.attack) == before + 1, "姑获鸟攻击后退回、获得力量并满血")

func drink_and_flame() -> void:
	var gs := match_with("jutun-tongzi", "caitongzi")
	var own := gs.player(0)
	var enemy := gs.player(1)
	var drink: Dictionary = own.units[0]
	var flame: Dictionary = own.units[1]
	flame.level = 1
	drink.hp = 2
	if not face_play(gs, "c102111", "jutun-tongzi"): return
	check(int(drink.hp) == 1 and int(drink.shield) == 1, "醉酒自伤时不屈保命并获得实际损血量的护甲")
	check(own.hand.any(func(inst):
		var card := Content.card_def(inst.definitionId)
		return card.get("unitId") == "caitongzi" and card.get("type") == "combat" and int(card.level) == 1), "羁绊获得茨木当前勾玉的原战斗牌")

	gs = match_with("jutun-tongzi", "caitongzi")
	own = gs.player(0)
	enemy = gs.player(1)
	drink = own.units[0]
	flame = own.units[1]
	var victim: Dictionary = enemy.units[1]
	victim.front = 1
	victim.hp = 1
	var before: int = drink.hp
	if not face_play(gs, "c102111", "caitongzi"): return
	var learned: Array = flame.get("coopFirstFlames", [])
	check(int(drink.hp) == before - 1 and int(victim.hp) == 0 and learned.size() == 1, "茨木羁绊使酒吞自伤且击杀习得一种豪焰")
	var marks := Status.unit_marks(Status.unit_view(gs, 0, 1, 0), gs.turn_counter)
	check(marks.any(func(mark): return mark.id == "coop-flames" and int(mark.value) == 1 and gs.VerifiedRules.CoopFirst.flame_details(flame) in mark.detail), "战场状态显示已习得豪焰及其真实效果")
	victim = enemy.units[2]
	victim.front = 1
	victim.hp = 1
	if not face_play(gs, "c102111", "caitongzi"): return
	check(learned.size() == 2 and learned[0] != learned[1], "重复击杀习得不同豪焰")
	if not face_play(gs, "c102111", "caitongzi"): return
	check(learned.size() == 2, "只命中牌手不学习豪焰")

func snow() -> void:
	var gs := match_with("xuenv", "xuetongzi")
	var own := gs.player(0)
	var enemy := gs.player(1)
	var snowboy: Dictionary = own.units[1]
	var front: Dictionary = enemy.units[0]
	var selected: Dictionary = enemy.units[1]
	selected.level = 0
	front.front = 1
	var before: int = selected.hp
	var front_before: int = front.hp
	if not face_play(gs, "c106112", "xuenv", selected.uid): return
	check(int(selected.frozen) > 0 and int(selected.hp) < before and int(front.hp) == front_before, "冰封羁绊追击实际被选的准备区式神")
	check(own.hand.any(func(inst): return inst.definitionId == "xueqiu"), "冰封将雪球放入手牌")

	gs = match_with("xuenv", "xuetongzi")
	own = gs.player(0)
	enemy = gs.player(1)
	snowboy = own.units[1]
	selected = enemy.units[1]
	selected.level = 0
	var attack_before: int = snowboy.attack
	if not face_play(gs, "c106112", "xuetongzi", selected.uid): return
	check(int(own.realms[0].hp) == 4 and int(selected.frozen) > 0 and int(snowboy.attack) == attack_before + 1, "雪刃羁绊先入场再眩晕，第一次计数加力量")
	gs.VerifiedRules.Stun.apply(gs, 1, -1, 1, 0, 0)
	var marks := Status.unit_marks(Status.unit_view(gs, 0, 1, 0), gs.turn_counter)
	check(marks.any(func(mark): return mark.id == "swift" and "迅捷" in mark.label), "雪童子获得迅捷时显示既有迅捷徽章")
	own.energy = 0
	check(int(snowboy.get("coopFirstSnowSwift", -1)) == gs.turn_counter and gs.basic_attack(0, 1) and int(own.energy) == 0, "第二个眩晕目标可为牌手，并使雪童子的出击不消耗鬼火")
	check(not snowboy.has("coopFirstSnowSwift"), "完成一次出击消费迅捷")
	gs.VerifiedRules.Stun.apply(gs, 1, 2, 1, 0, 0)
	check(gs.VerifiedRules.Combat.has(snowboy, "pierce"), "第三个眩晕目标给雪童子贯通")
	turn(gs, 0)
	check(int(snowboy.attack) == attack_before and not gs.VerifiedRules.Combat.has(snowboy, "pierce") and not snowboy.has("coopFirstSnowSwift"), "三个等级的临时增益一同在回合结束清除")

func firefly_and_arrow() -> void:
	var gs := match_with("yingcao", "bailang")
	var own := gs.player(0)
	var wolf: Dictionary = own.units[1]
	var high := {"instanceId":"first-form-high", "definitionId":"c11004"}
	own.deck.assign([high])
	gs._grow_unit(wolf, 6-int(wolf.attack), 0)
	var draw_count := int(own.get("restoredDrawCount", 0))
	if not face_play(gs, "c107110", "yingcao", wolf.uid): return
	check(own.deck.is_empty() and not own.hand.has(high) and wolf.get("form", {}).get("cardId") == "c11004", "六力量直接使用牌库中的原形态实例")
	check(int(own.get("restoredDrawCount", 0)) == draw_count, "直接使用跳过抽牌")

	gs = match_with("yingcao", "bailang")
	own = gs.player(0)
	wolf = own.units[1]
	var low := {"instanceId":"first-form-low", "definitionId":"c11004"}
	own.deck.assign([low])
	gs._grow_unit(wolf, 5-int(wolf.attack), 0)
	if not face_play(gs, "c107110", "yingcao", wolf.uid): return
	check(own.hand.has(low) and wolf.get("form", {}).is_empty(), "五力量只抽入原实例而不直接使用")

	gs = match_with("yingcao", "bailang")
	own = gs.player(0)
	var enemy := gs.player(1)
	var grass: Dictionary = own.units[0]
	wolf = own.units[1]
	grass.level = 0
	gs._apply_encourage(0, 2, 1)
	var before: int = enemy.avatarHp
	if not face_play(gs, "c107110", "bailang"): return
	check(int(enemy.avatarHp) == before - int(wolf.attack) - 1 and int(wolf.shield) == 1 and int(gs.kw_usage(0, "encourage").attack) == 2, "无羁绊时只给战斗身材并保留未消耗的出击加成")

	gs = match_with("yingcao", "bailang")
	own = gs.player(0)
	grass = own.units[0]
	wolf = own.units[1]
	enemy = gs.player(1)
	wolf.hp = 1
	gs._apply_form(0, 0, Content.card_def("c10702"))
	var base: int = wolf.attack
	gs._apply_encourage(0, 2, 1)
	play(gs, "c11001")
	before = int(enemy.avatarHp)
	if not face_play(gs, "c107110", "bailang"): return
	check(int(wolf.hp) == 3 and int(wolf.shield) == 2 and int(enemy.avatarHp) == before - base - 7, "羁绊触发治愈之光及出击加成，战斗再取法术的两点力量")

func blossoms() -> void:
	var gs := match_with("taohuayao", "yinghuayao")
	var own := gs.player(0)
	var enemy := gs.player(1)
	var peach: Dictionary = own.units[0]
	var sakura: Dictionary = own.units[1]
	var ally: Dictionary = own.units[2]
	ally.hp = 1
	if not face_play(gs, "c108184", "taohuayao"): return
	check(int(peach.attack) == 3 and int(peach.maxHp) == 6 and int(ally.hp) == 3, "桃红固定身材及樱花妖群体治疗")
	gs.VerifiedRules.Movement.move_to(gs, 0, 2, 1)
	check(int(ally.hp) == mini(5, int(ally.maxHp)), "进战斗区实时恢复两点")
	gs.VerifiedRules.Movement.move_to(gs, 0, 2, 0)
	var before: int = ally.hp
	gs._damage_unit(0, 2, 25, 1, 0)
	check(int(ally.hp) == before and peach.form.is_empty(), "准备区致命伤害被抵消且移除桃红形态")

	gs = match_with("taohuayao", "yinghuayao")
	own = gs.player(0)
	enemy = gs.player(1)
	sakura = own.units[1]
	ally = own.units[3]
	ally.hp = 1
	if not face_play(gs, "c108184", "yinghuayao"): return
	check(int(sakura.attack) == 4 and int(sakura.maxHp) == 5 and int(ally.hp) >= 4, "落英固定身材，桃花妖治疗唯一受伤目标")
	gs._knockout_unit(ally)
	var total: int = enemy.units.reduce(func(sum, unit): return sum + int(unit.hp), 0)
	gs.VerifiedRules.Peach.revive(gs, 0, 0, ally, false, false)
	gs._resolve_resolution_stack()
	check(sakura.form.name == "晚樱之意" and int(enemy.units.reduce(func(sum, unit): return sum + int(unit.hp), 0)) == total - int(ally.baseAttack), "落英按复活者基础力量逐段伤害并切换晚樱")
	gs._knockout_unit(enemy.units[1], 0, 1)
	gs._resolve_resolution_stack()
	check(sakura.form.name == "落英缤纷", "同回合满足另一形态条件后切换回落英")
	gs._knockout_unit(ally)
	gs.VerifiedRules.Peach.revive(gs, 0, 0, ally, false, false)
	gs._resolve_resolution_stack()
	check(sakura.form.name == "落英缤纷", "落英同一个己方回合最多触发一次")

func jumps() -> void:
	var gs := match_with("tiaotiaodidi", "tiaotiaogege")
	var own := gs.player(0)
	var enemy := gs.player(1)
	var brother: Dictionary = own.units[1]
	brother.jumpSlow = {"jumpKind":"jump-release", "remaining":2}
	if not face_play(gs, "c114183", "tiaotiaodidi"): return
	check(int(own.realms[0].hp) == 5 and int(brother.jumpSlow.remaining) == 1, "尸瘴为五耐久幻境并减少兄长现有倒计时")
	var prior: int = enemy.units[1].attack
	gs.VerifiedRules.ArmorBreak.give(gs, 1, 0, 0, 2, 1)
	gs._resolve_resolution_stack()
	check(int(enemy.avatarArmorBreak) == 1 and int(enemy.units[1].armorBreak) == 1 and int(enemy.units[1].attack) == prior - 1, "己方首次实际破甲给予对方全角色破甲并削减破甲式神力量")
	gs.VerifiedRules.ArmorBreak.give(gs, 1, 0, 0, 3, 1)
	gs._resolve_resolution_stack()
	check(int(enemy.avatarArmorBreak) == 1, "同回合再次获得破甲不重复全场效果")
	gs.VerifiedRules.Huang.destroy(gs, 0, own.realms[0], "测试移除")
	check(int(enemy.units[1].attack) == prior, "幻境离场即撤销力量减益")

	gs = match_with("tiaotiaodidi", "tiaotiaogege")
	own = gs.player(0)
	enemy = gs.player(1)
	var younger: Dictionary = own.units[0]
	var victim: Dictionary = enemy.units[1]
	victim.front = 1
	gs.VerifiedRules.ArmorBreak.give(gs, 1, 0, 0, 0, 2)
	if not face_play(gs, "c114183", "tiaotiaogege"): return
	check(int(victim.armorBreak) == 2 and int(younger.armorBreak) == 0, "棺葬进场将跳跳弟弟自身破甲转移至敌方战斗区")
	var ally: Dictionary = own.units[2]
	gs._knockout_unit(ally, 1, 0)
	gs._resolve_resolution_stack()
	check(ally.has("jumpCoffin") and int(own.realms[0].hp) == 3, "首个非家族初始式神死亡转棺并损失两耐久")
	gs._knockout_unit(own.units[3], 1, 0)
	gs._resolve_resolution_stack()
	check(not own.units[3].has("jumpCoffin"), "同一回合只转化一次")
	turn(gs, 0)
	var original_hp: int = younger.maxHp
	gs._knockout_unit(younger, 1, 0)
	gs._resolve_resolution_stack()
	check(younger.has("jumpCoffin") and int(younger.jumpCoffin.original.maxHp) == original_hp + 1 and int(own.realms[0].hp) == 3, "家族转化永久加生命且不扣棺葬耐久")

func _initialize() -> void:
	blade_and_crane()
	drink_and_flame()
	snow()
	firefly_and_arrow()
	blossoms()
	jumps()
	print("COOP_FIRST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
