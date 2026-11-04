extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BLESSING_CONTINUATION_FAIL ",detail)
func fixture() -> GS:
	var gs := GS.create(["shantu","fenghuanghuo","yingcao","yaodaoji"],["bingyong","fenghuanghuo","yingcao","shantong"],20210629)
	for p in gs.players:
		p.hand.clear(); p.energy = 4; p.levelUpUsed = true
		for u in p.units: u.level = 3
	gs.player(0).deck = [{"instanceId":"blessing-deck-bottom","definitionId":"c12801"},{"instanceId":"blessing-deck-top","definitionId":"c12802"}]
	gs.player(0).hand.append({"instanceId":"blessing-hand","definitionId":"c12702"})
	return gs
func _initialize() -> void:
	for count in [0,2,3,5]:
		var gs := fixture()
		var p: Dictionary = gs.player(0)
		p.fortuneSixes = count
		var u: Dictionary = p.units[1]
		var power := int(u.attack)
		var hp := int(u.maxHp)
		check(gs.hand_card_def(0,0).text.contains("抽一张牌"),"hand states unconditional draw at six count%d" % count)
		check(not gs.play_card(0,0,gs.player(1).units[0].uid),"enemy target rejected")
		check(p.deck.size() == 2 and p.hand.size() == 1 and p.energy == 4,"invalid enemy neither draws nor pays")
		check(not gs.play_card(0,0,"avatar-0"),"avatar target rejected")
		check(gs.play_card(0,0,u.uid),"allied target accepted")
		check(u.attack == power+(3 if count >= 3 else 1) and u.maxHp == hp+(3 if count >= 3 else 1),"growth retains exact enhancement threshold")
		check(u.get("swift",false) == (count >= 3),"swift retains exact enhancement threshold")
		check(p.hand.size() == 1 and p.hand[0].instanceId == "blessing-deck-top" and p.deck.size() == 1,"draw exactly one original top card at six count%d" % count)
		check(p.energy == 3 and p.fortuneSixes == count,"draw does not add die rolls or change cost")
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	p.deck.clear()
	var original_power := int(p.units[1].attack)
	check(gs.play_card(0,0,p.units[1].uid),"empty-deck blessing still resolves")
	check(p.units[1].attack == original_power+1 and gs.winner == 1,"growth precedes actual empty draw defeat")
	gs = fixture(); p = gs.player(0)
	p.units[1].hp = 0
	check(not gs.play_card(0,0,p.units[1].uid) and p.deck.size() == 2,"dead target cannot consume card or draw")
	gs = fixture(); p = gs.player(0)
	check(gs.play_card(0,0,p.units[0].uid) and p.hand.size() == 1,"rabbit may bless itself and draw")
	gs = fixture(); p = gs.player(0)
	p.fortuneSixes = 3
	check(AI.take_action(gs,0),"AI takes real legal card action")
	check(p.energy == 3 and p.hand.size() == 1 and p.deck.size() == 1,"AI resolves same draw rather than generating a card")
	check(p.units.any(func(u):return u.get("swift",false)),"AI selected legal allied enhanced recipient")
	check(gs.player(1).units.all(func(u):return not u.get("swift",false)),"AI cannot apply friendly blessing to enemy")
	print("BLESSING_CONTINUATION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
