extends SceneTree
## 重绘专项渲染截图，隔离玩家数据。

const MainScene := preload("res://scenes/main_menu.tscn")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const DeckBuilder := preload("res://scripts/ui/deck_builder.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")

const FIRST := ["yaodaoji", "jutun-tongzi", "bingyong", "datiangou"]
const SECOND := ["xuenv", "yingcao", "taohuayao", "guniao"]
var _fixture := ""
var _directory := "user://redrawn-shots"
var _current: Control
var _full_classic := false
var _wave23 := false

func _initialize() -> void:
	_fixture = VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _directory = args[0]
	_full_classic = args.size() > 1 and args[1] == "--full-classic"
	_wave23 = args.size() > 1 and args[1] == "--wave23"
	DirAccess.make_dir_recursive_absolute(_directory)
	root.size = Vector2i(1280, 800)
	root.theme = ThemeBuilder.build_theme()
	root.gui_disable_input = true
	_run.call_deferred()

func _mount(screen: Control) -> void:
	if is_instance_valid(_current):
		root.remove_child(_current)
		_current.free()
	_current = screen
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _shot(name: String) -> void:
	await create_timer(1.4).timeout
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(_directory.path_join(name + ".png"))
	print("SHOT ", name)

func _gallery(ids: Array, title_text: String) -> void:
	var gallery := Control.new()
	_mount(gallery)
	var bg := ColorRect.new()
	bg.color = Color("141b29")
	gallery.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := ThemeBuilder.label(title_text, 24, ThemeBuilder.PAPER)
	gallery.add_child(title)
	title.position = Vector2(32, 16)
	for i in ids.size():
		var face := UIWidgets.make_unit_panel(ContentLoader.unit_def(ids[i]), Callable())
		gallery.add_child(face)
		face.position = Vector2(56 + (i % 4) * 310, 72 + (i / 4) * 354)
		face.size = Vector2(220, 320)

func _run() -> void:
	if _wave23:
		await _run_wave23()
		await _finish()
		return
	if _full_classic:
		await _run_full_classic()
		await _finish()
		return
	_gallery(FIRST + SECOND, "经典式神重绘 · Godot 实际卡面")
	await _shot("01-eight-portraits")
	_mount(MainScene.instantiate())
	await _shot("02-classic-menu")
	var form := FormationScreen.new()
	_mount(form)
	form.set_preselect(FIRST)
	form._pack_picker.select(ContentLoader.pack_ids().find("classic"))
	form._pack_picker.item_selected.emit(form._pack_picker.selected)
	form._show_unit(ContentLoader.unit_def("yaodaoji"))
	await _shot("03-classic-formation")
	var deck := DeckBuilder.new()
	deck.setup("yaodaoji")
	_mount(deck)
	await _shot("04-yaodaoji-deck")
	for index in 2:
		var battle := BattleScreen.new()
		battle.setup(FIRST if index == 0 else SECOND, SECOND if index == 0 else FIRST, 20261005)
		battle._ai_thinking = true
		_mount(battle)
		await _shot("05-classic-battle" if index == 0 else "06-support-battle")
	await _finish()

func _run_full_classic() -> void:
	var ids: Array = ContentLoader.units_in_pack("classic").map(func(unit): return unit.id)
	for offset in range(0, ids.size(), 8):
		_gallery(ids.slice(offset, mini(offset + 8, ids.size())), "经典基础 · 29 位重绘 · 第 %d 页" % (offset / 8 + 1))
		await _shot("01-classic-portraits-%02d" % (offset / 8 + 1))
	_mount(MainScene.instantiate())
	await _shot("02-classic-menu")
	var form := FormationScreen.new()
	_mount(form)
	form.set_preselect(["bailang", "caitongzi", "qingxingdeng", "shantu"])
	form._pack_picker.select(ContentLoader.pack_ids().find("classic"))
	form._pack_picker.item_selected.emit(form._pack_picker.selected)
	form._search.text = "青行灯"
	form._rebuild_unit_list()
	form._show_unit(ContentLoader.unit_def("qingxingdeng"))
	await _shot("03-new-classic-formation")
	var deck := DeckBuilder.new()
	deck.setup("qingxingdeng")
	_mount(deck)
	await _shot("04-qingxingdeng-deck")
	for offset in range(0, ids.size(), 4):
		var ally: Array = []
		var foe: Array = []
		for i in 4:
			ally.append(ids[(offset + i) % ids.size()])
			foe.append(ids[(offset + i + 4) % ids.size()])
		var battle := BattleScreen.new()
		battle.setup(ally, foe, 20261005 + offset)
		battle._ai_thinking = true
		_mount(battle)
		await _shot("05-classic-battle-%02d" % (offset / 4 + 1))

func _save_frame(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(_directory.path_join(name + ".png"))
	print("SHOT ", name)

func _run_wave23() -> void:
	var ids: Array = []
	for pack in ["wave2", "wave3"]:
		ids.append_array(ContentLoader.units_in_pack(pack).map(func(unit): return unit.id))
	for offset in range(0, ids.size(), 8):
		_gallery(ids.slice(offset, mini(offset + 8, ids.size())), "原版参照重绘 · 新增 28 位 · 第 %d 页" % (offset / 8 + 1))
		await _shot("01-wave23-portraits-%02d" % (offset / 8 + 1))
	for pack in ["wave2", "wave3"]:
		var form := FormationScreen.new()
		_mount(form)
		form.set_preselect(["yaohu", "buzhinhuo", "rihefang", "lianyou"])
		form._pack_picker.select(ContentLoader.pack_ids().find(pack))
		form._pack_picker.item_selected.emit(form._pack_picker.selected)
		form._show_unit(ContentLoader.unit_def("buzhinhuo" if pack == "wave2" else "huiyeji"))
		await _shot("02-%s-formation" % pack)
	var deck := DeckBuilder.new()
	deck.setup("buzhinhuo")
	_mount(deck)
	await _shot("03-buzhinhuo-deck")
	for offset in range(0, ids.size(), 4):
		var ally: Array = []
		var foe: Array = []
		for i in 4:
			ally.append(ids[(offset + i) % ids.size()])
			foe.append(ids[(offset + i + 4) % ids.size()])
		var battle := BattleScreen.new()
		battle.setup(ally, foe, 20261005 + offset)
		battle._ai_thinking = true
		_mount(battle)
		await _shot("04-wave23-battle-%02d" % (offset / 4 + 1))
	# 动效证据取实际中间帧；截完恢复正常 processing，不改游戏运行行为。
	var battle := BattleScreen.new()
	battle.setup(["yaohu", "buzhinhuo", "rihefang", "lianyou"], ["biyehua", "guiqie", "shanfeng", "huang"], 20261005)
	battle._ai_thinking = true
	_mount(battle)
	for player in battle.gs.players:
		player.levelUpUsed = true
		for unit in player.units: unit.level = 3
	battle.gs.player(1).units[0].front = 1
	battle._refresh()
	await create_timer(0.4).timeout
	battle._on_unit_clicked(battle.gs.player(0).units[0], 0, 0)
	var defender := battle._unit_widget(str(battle.gs.player(1).units[0].uid))
	var aim := battle._aim_context(defender.get_global_rect().get_center())
	battle.set_process(false)
	battle._aim.origin = aim.origin
	battle._aim.endpoint = aim.endpoint
	battle._aim.valid = aim.valid
	battle._aim.over_target = aim.over_target
	battle._aim.visible = true
	battle._aim.queue_redraw()
	await _save_frame("05-legal-target-line")
	var reserve := battle._unit_widget(str(battle.gs.player(1).units[1].uid))
	aim = battle._aim_context(reserve.get_global_rect().get_center())
	battle._aim.endpoint = aim.endpoint
	battle._aim.valid = aim.valid
	battle._aim.queue_redraw()
	await _save_frame("06-invalid-target-line")
	battle._aim.visible = false
	battle.set_process(true)
	battle._on_unit_clicked(battle.gs.player(1).units[0], 1, 0)
	await create_timer(0.4).timeout
	await _save_frame("07-attack-impact")
	await _shot("08-attack-settled")

func _finish() -> void:
	root.remove_child(_current)
	_current.free()
	await process_frame
	VerifySupport.cleanup_stores(_fixture)
	print("REDRAWN_CAPTURE_DONE")
	quit(0)
