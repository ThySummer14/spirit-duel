extends "res://scripts/verify_book_jue_ui.gd"
const Mengpo := preload("res://scripts/mengpo_rules.gd")
func prepare(b, ids: Array = [], count: int = 16) -> void:
	b.setup(["mengpo","yingcao","taohuayao","yaodaoji"],["bingyong","yingcao","yaodaoji","mengpo"],17116)
	b._ai_thinking=true
	for p in b.gs.players:
		p.hand.clear();p.energy=40;p.levelUpUsed=true
		for u in p.units:u.level=3
	b.gs.player(1).deck.clear()
	for i in count:b.gs.player(1).deck.append({"instanceId":"mengpo-enemy-deck-%d"%i,"definitionId":"c10701"})
	hand(b,ids)
	await settled(b)
func tick() -> void:
	await process_frame
	await process_frame
func run() -> void:
	var stores:=Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["mengpo"],["bingyong"],17116);b._ai_thinking=true;root.add_child(b)
		await prepare(b,["c17101"])
		var gs=b.gs;var p: Dictionary=gs.player(0);var enemy: Dictionary=gs.player(1)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card==0 and gs.valid_targets(0,b._pending_target_card_def).has(enemy.units[0].uid),"soup opens enemy unit targeting")
		await click(b._unit_widget(str(p.units[0].uid)))
		check(b._pending_target_card==0 and p.energy==40,"soup rejects friendly mouse target")
		await capture("%d-01-soup-target"%physical.x)
		var hp:int=enemy.units[0].hp
		await click(b._unit_widget(str(enemy.units[0].uid)));await settled(b)
		check(enemy.units[0].hp==hp-3 and enemy.deck.size()==13 and enemy.avatarHp==30,"mouse soup does3 to selected unit and removes bottom3")
		check(b._enemy_deck_l.text.contains("13"),"enemy public deck count immediately refreshes")
		await prepare(b,["c17102","c17107"])
		gs=b.gs;p=gs.player(0);enemy=gs.player(1);p.energy=0
		p.deck=[{"instanceId":"mengpo-draw-a","definitionId":"c17101"},{"instanceId":"mengpo-draw-b","definitionId":"c10701"}]
		b._last_view={};b._refresh();await settled(b)
		check(b._hand_row.get_child(0).data.payment.usesInstant and b._hand_row.get_child(0).enabled,"threshold16 enables zero-fire surprise")
		await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.type=="mengpo-discard" and faces(b._choice_layer).size()==3,"actual surprise draws2 then offers all3 current hand instances")
		check(texts(b._choice_layer).contains("已抽两张牌"),"discard instructions explain real order")
		escape();await tick();check(gs.pending_choice.type=="mengpo-discard","paid mandatory discard cannot be skipped by Escape")
		await capture("%d-02-draw-discard"%physical.x)
		await click(choice_face(b,"c17107"));await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.size()==2 and p.deck.is_empty() and not p.units[0].awakened,"mouse discards old awakening without using it")
		await prepare(b,["c17103"])
		gs=b.gs;p=gs.player(0);enemy=gs.player(1)
		await click(b._hand_row.get_child(0));await settled(b)
		var n:int=p.deck.size()
		check(p.units[0].attack==4 and p.units[0].maxHp==5,"native falling form printed4/5")
		b._on_unit_hover(true,0,0);check(texts(b._tooltip).contains("双方牌手各将牌库底一张牌移除"),"falling form inspector explains actual end-turn removal");b._hide_tooltip()
		await click(b._end_btn);await settled(b)
		check(gs.current_player==1 and p.deck.size()==n-1 and enemy.deck.size()==14,"real end button removes bottom1 each then enemy draws")
		await prepare(b,["c17104"])
		gs=b.gs;p=gs.player(0);enemy=gs.player(1)
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.units[0].attack==8 and p.units[0].maxHp==10 and gs.VerifiedRules.Combat.has(p.units[0],"pierce"),"enhanced form installs8/10 and actual pierce")
		b._on_unit_hover(true,0,0)
		check(texts(b._tooltip).contains("此牌获得3力量和3生命"),"body inspector retains conditional form ability")
		await capture("%d-03-enhanced-body"%physical.x)
		b._hide_tooltip()
		await prepare(b,["c17105"])
		gs=b.gs;enemy=gs.player(1)
		await click(b._hand_row.get_child(0));await settled(b)
		check(enemy.avatarHp==22 and enemy.deck.size()==15,"mouse projectile doubles to8 and actual Mengpo ability removes1")
		await prepare(b,["c17106"])
		gs=b.gs;p=gs.player(0)
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.units[0].attack==4 and p.units[0].maxHp==6,"native bridge4/6")
		b._on_unit_hover(true,0,0);check(texts(b._tooltip).contains("手牌和牌库中的同名牌移除"),"bridge inspector explains exact same-name removal");b._hide_tooltip()
		p.deck=[{"instanceId":"bridge-bottom","definitionId":"c10107"},{"instanceId":"bridge-other","definitionId":"c10701"},{"instanceId":"bridge-top","definitionId":"c10107"}]
		hand(b,["c10107","c10107"]);await settled(b)
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.hand.is_empty() and p.deck.size()==1 and p.units[3].awakened,"bridge removes own same-name copies while original cast completes")
		await prepare(b,["c17107"],12)
		gs=b.gs;p=gs.player(0);enemy=gs.player(1);p.energy=1;b._refresh();await tick()
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.energy==0 and p.units[0].get("swift",false) and p.units[0].attack==5 and p.units[0].maxHp==6,"2020 stats and2024 swift both applied")
		await capture("%d-04-awaken-swift"%physical.x)
		await click(b._unit_widget(str(p.units[0].uid)));await click(b._enemy_target_btn);await settled(b)
		check(not p.units[0].get("swift",false) and p.energy==0 and enemy.deck.size()==7,"swift ordinary attack consumes no fire and awake damage removes5")
		await prepare(b,["c17108"],5)
		gs=b.gs;p=gs.player(0);enemy=gs.player(1);enemy.units[0].level=1;enemy.units[1].level=0
		enemy.hand=[{"instanceId":"name-hand-hit","definitionId":"c10301"},{"instanceId":"name-hand-keep","definitionId":"c10703"}]
		enemy.deck=[{"instanceId":"name-bottom-a","definitionId":"c10701"},{"instanceId":"name-hit-a","definitionId":"c10301"},{"instanceId":"name-bottom-b","definitionId":"c10702"},{"instanceId":"name-hit-b","definitionId":"c10301"},{"instanceId":"name-top","definitionId":"c10703"}]
		p.energy=0;b._last_view={};b._refresh();await settled(b)
		await click(b._hand_row.get_child(0));await settled(b)
		check(gs.pending_choice.type=="mengpo-name-unit" and faces(b._choice_layer).size()==3,"first choice excludes level0 enemy and displays3 public units")
		await capture("%d-05-melody-unit"%physical.x)
		await click(choice_face(b,str(enemy.units[0].uid)));await settled(b)
		check(gs.pending_choice.type=="mengpo-name" and choice_face(b,"c10301")!=null and choice_face(b,"c10309")==null,"second choice only displays target unit's level1 names")
		check(faces(b._choice_layer).size()==2,"Bingyong level1 only has two legal names regardless hidden zones")
		await capture("%d-06-melody-name"%physical.x)
		await click(choice_face(b,"c10301"));await settled(b)
		check(enemy.hand.size()==1 and enemy.deck.size()==1 and enemy.deck[0].instanceId=="name-top","mouse chosen name removed before bottom2; correct top survives")
		check(gs.pending_choice.is_empty() and b._choice_layer==null and b._enemy_deck_l.text.contains("牌库 1"),"completed name choice restores battle and public count")
		b.queue_free();await tick()
	Support.cleanup_stores(stores);Support.cleanup_audio();await tick()
	print("MENGPO_UI checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
