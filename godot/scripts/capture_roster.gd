extends SceneTree
## 角色入口专项截图；仅使用隔离存档，不修改玩家阵容。

const MainScene := preload("res://scenes/main_menu.tscn")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const DeckBuilder := preload("res://scripts/ui/deck_builder.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")

var _fixture := ""
var _directory := "user://roster-shots"
var _current: Control

func _initialize() -> void:
	_fixture = VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _directory = args[0]
	DirAccess.make_dir_recursive_absolute(_directory)
	root.size = Vector2i(1280, 800)
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
	var path := _directory.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _run() -> void:
	var main := MainScene.instantiate()
	_mount(main)
	await _shot("01-classic-menu")
	var menu = main._current
	for i in range(1, menu._preset_picker.item_count):
		if menu._preset_picker.get_item_metadata(i) == "wave9":
			menu._preset_picker.select(i)
			menu._preset_picker.item_selected.emit(i)
	await _shot("02-expansion-menu")
	var form := FormationScreen.new()
	_mount(form)
	form.set_preselect(ContentLoader.recommended_lineup("classic"))
	await _shot("03-full-roster")
	form._pack_picker.select(ContentLoader.pack_ids().find("classic"))
	form._pack_picker.item_selected.emit(form._pack_picker.selected)
	form._show_unit(ContentLoader.unit_def("yaodaoji"))
	await _shot("04-classic-formation")
	form._pack_picker.select(ContentLoader.pack_ids().find("wave9"))
	form._pack_picker.item_selected.emit(form._pack_picker.selected)
	form.set_preselect(ContentLoader.recommended_lineup("wave9"))
	await _shot("05-expansion-formation")
	var deck := DeckBuilder.new()
	deck.setup("yatiangou-qiuye")
	_mount(deck)
	await _shot("06-expansion-deck")
	var battle := BattleScreen.new()
	var ally := ContentLoader.recommended_lineup("wave9")
	battle.setup(ally, ContentLoader.opponent_lineup(ally, 20261005), 20261005)
	battle._ai_thinking = true
	_mount(battle)
	await _shot("07-expansion-battle")
	root.remove_child(_current)
	_current.free()
	await process_frame
	VerifySupport.cleanup_stores(_fixture)
	print("ROSTER_CAPTURE_DONE")
	quit(0)
