extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks:=0
var failures:=0
var out:=""
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("TOMATO_FIRE_UI_FAIL ",message)
func click(face: Control) -> void:
	var at:=face.get_global_transform_with_canvas()*(face.size*0.5)
	var motion:=InputEventMouseMotion.new();motion.position=at
	root.push_input(motion,true)
	await process_frame
	await create_timer(0.14).timeout
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=face.get_global_transform_with_canvas()*(face.size*0.5)
		e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true)
func settled(b) -> void:
	for i in 3:await process_frame
	await create_timer(b._presentation_remaining()+0.18).timeout
	await process_frame
func hand(b,ids: Array) -> void:
	b.gs.player(0).hand.clear()
	for i in ids.size():b.gs.player(0).hand.append({"instanceId":"tf-ui-%d"%i,"definitionId":ids[i]})
	b._last_view={};b._refresh()
func texts(n: Node) -> String:
	var s:=str(n.text)+"\n" if n is Label or n is RichTextLabel else ""
	for child in n.get_children():s+=texts(child)
	return s
func capture(name: String) -> void:
	if out.is_empty():return
	await create_timer(0.15).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
	var stores:=Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():out=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(out)
	root.theme=ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical
		if not out.is_empty():DisplayServer.window_set_size(physical)
		var b:=Battle.new()
		b.setup(["tiaotiaomeimei","buzhinhuo","bailang","shantong"],["tiaotiaomeimei","buzhinhuo","yaodaoji","bingyong"],20261014)
		b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=20;p.levelUpUsed=true;p.avatarArmor=0;p.attackUsed=false
			for u in p.units:u.level=3;u.front=0
		root.add_child(b)
		var gs=b.gs
		var p: Dictionary=gs.player(0)
		gs.kw_usage(0,"encourage").clear()
		hand(b,["c14601"])
		p.energy=1;b._last_view={};b._refresh()
		await create_timer(0.25).timeout
		b._show_unit_popover(p.units[0],0,0)
		check("额外消耗1点鬼火" in texts(b._tooltip) and "享受跳跳妹妹法术牌" in texts(b._tooltip),"sister inspector displays initial and awakening rules")
		b._hide_tooltip()
		b._show_unit_popover(p.units[1],0,1)
		check("己方回合开始时" in texts(b._tooltip) and "鼓舞额外+1力量与+1护甲" in texts(b._tooltip),"fire inspector displays initial and awakening rules")
		b._hide_tooltip()
		await click(b._hand_row.get_child(0))
		check(p.hand.size()==1 and p.energy==1,"actual click rejects combat at1fire")
		check(b._hand_row.get_child(0).data.payment.cost==2,"card UI quotes extra cost2")
		p.energy=20
		var old: Dictionary=gs.VerifiedRules.NativeSummons.summon(gs,0,2,"tomato-ui-front","其他召唤物",2,4)
		hand(b,["c14603"])
		await settled(b)
		check(b._unit_widget(str(old.uid))!=null,"old native summon is visible before the card click")
		await click(b._hand_row.get_child(0));await settled(b)
		var t: Dictionary=gs.front_unit(0)
		check(t.get("tomatoEntity",false) and t.attack==5 and t.hp==4,"real card click creates buffed front tomato")
		check(old.get("removed",false) and b._unit_widget(str(old.uid))==null,"displaced native summon no longer appears in reserve or front")
		check(b._unit_widget(str(t.uid))!=null,"summoned tomato visible and selectable")
		await click(b._unit_widget(str(t.uid)))
		check(b._selected_attacker==p.units.size()-1,"actual summoned unit click selects basic attacker")
		await click(b._enemy_target_btn);await settled(b)
		check(p.attackUsed and p.energy==18 and gs.player(1).avatarHp==25,"real tomato basic input and payment")
		await capture("%d-01-tomato-command"%physical.x)
		p.attackUsed=false
		hand(b,["c16702"])
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card==0,"freedom real input opens ally target picker")
		check(not gs.valid_targets(0,b._pending_target_card_def).has("avatar-0"),"target UI cannot choose avatar")
		await click(b._unit_widget(str(p.units[2].uid)));await settled(b)
		check(p.units[2].swift and gs.kw_usage(0,"encourage").attack==2,"actual chosen ally swift plus encourage")
		await capture("%d-02-freedom-target"%physical.x)
		hand(b,["c16703"])
		p.attackUsed=true
		var fire:=int(p.energy)
		await click(b._hand_row.get_child(0));await settled(b)
		check(not p.attackUsed and p.energy==fire,"truth mouse instant resets action and no fabricated fire")
		hand(b,["c14608","c14603","c14607","c16705"])
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.units[0].awakened and p.units[0].tomatoEntity,"awakening mouse changes source")
		check(p.hand.size()==5 and p.hand.all(func(e):return gs.ContentLoader.card_def(e.definitionId).unitId!="tiaotiaomeimei" or gs.ContentLoader.card_def(e.definitionId).type=="combat"),"UI hand transformation and two generated combat cards")
		check(b._hand_row.get_child_count()==5,"transformed hand actual faces refreshed")
		await capture("%d-03-awaken-transform"%physical.x)
		hand(b,["c16705"])
		await click(b._hand_row.get_child(0));await settled(b)
		var burn: Dictionary=gs.front_unit(0)
		check(burn.get("burnEntity",false) and burn.attack==2 and burn.hp==2,"spark mouse creates latest2/2")
		p.attackUsed=false
		b._last_view={};b._refresh()
		await click(b._unit_widget(str(burn.uid)))
		check(b._selected_attacker==p.units.size()-1,"burn real select")
		fire=p.energy
		await click(b._enemy_target_btn);await settled(b)
		check(p.energy==fire and p.attackUsed,"burn swift actual command consumes only attack action")
		check(gs.rule_events.filter(func(e):return e.kind=="burn-random-hit").size()==2,"UI burn performs random replacement two hits")
		await capture("%d-04-burn-replacement"%physical.x)

		# Real card input for the two combat timings after awakening.
		var foe: Dictionary=gs.player(1)
		for e in foe.units:e.front=0
		var target: Dictionary=foe.units[3]
		target.front=1;target.baseMaxHp=60;target.hp=60;target.maxHp=60;target.baseAttack=1
		gs._recalc(target)
		hand(b,["c14604"])
		var count: int=gs.rule_events.filter(func(e):return e.kind=="combat-damage-resolved" and e.player==0).size()
		await click(b._hand_row.get_child(0));await settled(b)
		check(gs.rule_events.filter(func(e):return e.kind=="combat-damage-resolved" and e.player==0).size()==count+2,"actual combo card input causes extra hit before ordinary hit")
		gs._knockout_unit(p.units[0]);hand(b,["c14606"])
		fire=p.energy
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.units[0].hp>0 and p.units[0].awakened and p.units[0].tomatoEntity,"real revive input restores transformed source")
		check(p.energy==fire-1,"awake revival UI pays ordinary one fire")
		for e in foe.units:e.front=0
		foe.units[0].front=1;foe.units[0].hp=6;foe.units[0].frozen=0
		foe.hand=[{"instanceId":"enemy-guard","definitionId":"c14605"}]
		foe.energy=20;gs.kw_usage(1,"instant").used=false
		hand(b,["c14601"])
		await click(b._hand_row.get_child(0));await settled(b)
		check(foe.units[0].hp==6 and foe.hand.is_empty(),"real hostile combat mouse input triggers tomato protection")
		check(gs.rule_events.any(func(e):return e.kind=="tomato-guard"),"response redirect visible in real UI stack")
		await capture("%d-05-combo-revival-guard"%physical.x)
		root.remove_child(b);b.free();await process_frame
	Support.cleanup_audio()
	await process_frame
	await process_frame
	Support.cleanup_stores(stores)
	print("TOMATO_FIRE_UI checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
