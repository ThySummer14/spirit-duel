extends SceneTree

const Battle := preload("res://scripts/ui/battle_screen.gd")
const CardFace := preload("res://scripts/ui/card_face.gd")

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Store := preload("res://scripts/save_store.gd")
const Collection := preload("res://scripts/collection_store.gd")
const Audio := preload("res://scripts/ui/sfx.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YANMIE_TRIO_UI_FAIL ", message)

func hand(b: Battle, ids: Array) -> void:
	b.gs.player(0).hand.clear()
	for i in ids.size():
		b.gs.player(0).hand.append({"instanceId": "ui-%d" % i, "definitionId": ids[i]})
	b._presentation_until = 0
	b._last_view = {}
	b._refresh()

func settle(b: Battle) -> void:
	b._presentation_until = 0
	b._last_view = {}
	b._refresh()
	await process_frame

func find_face(node: Node, name: String) -> Control:
	if node == null: return null
	if node is CardFace and str(node.data.get("name", "")) == name: return node
	for child in node.get_children():
		var found := find_face(child, name)
		if found != null: return found
	return null

func choose(layer: Node, name: String) -> bool:
	var face := find_face(layer, name)
	if face == null: return false
	for c in face.get_children():
		if c is Button and not c.disabled:
			c.pressed.emit()
			return true
	return false

func run() -> void:
	var fixture_dir := ProjectSettings.globalize_path("res://.godot/yanmie-ui-check")
	Store.storage_path = fixture_dir.path_join("save.json")
	Collection.storage_path = fixture_dir.path_join("collection.json")
	Audio.storage_path = fixture_dir.path_join("settings.json")
	root.theme = ThemeBuilder.build_theme()
	root.size = Vector2i(1366, 900)
	var b := Battle.new()
	b.setup(["guishibai", "yingcao-pupu", "tongnantongnv", "fenghuanghuo"], ["taohuayao", "yimulian", "yingcao", "tongnantongnv"], 632)
	b._ai_thinking = true
	root.add_child(b)
	await process_frame
	var gs := b.gs
	var p := gs.player(0)
	p.energy = 20
	p.levelUpUsed = true
	for side in gs.players:
		for u in side.units: u.level = 3

	gs._knockout_unit(p.units[3])
	gs._resolve_resolution_stack()
	hand(b, ["c62704"])
	b._on_hand_clicked(0, gs.hand_card_def(0, 0))
	check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def) == [p.units[3].uid], "revive hand card highlights only knocked shikigami")
	b._on_unit_clicked(p.units[3], 0, 3)
	check(int(p.units[3].hp) > 0 and b._pending_target_card == -1, "board target selection resolves actual revival")

	hand(b, ["c63002"])
	b._on_hand_clicked(0, gs.hand_card_def(0, 0))
	check(is_instance_valid(b._origin_choice_layer) and find_face(b._origin_choice_layer, "洞悉之种") != null, "shape opens native two-option origin popup")
	check(choose(b._origin_choice_layer, "治愈之光"), "origin form tile clickable")
	check(p.units[1].form.get("cardId") == "c10702", "origin tile installs classic heal shape")

	hand(b, ["c63202"])
	b._on_hand_clicked(0, gs.hand_card_def(0,0))
	await settle(b)
	check(choose(b._choice_layer, "护甲"), "song exposes real armor option")
	await settle(b)
	check(choose(b._choice_layer, "童男童女"), "song exposes living target tiles")
	check(int(p.units[2].shield) > 0 and gs.pending_choice.is_empty(), "chosen ally receives armor")

	hand(b, ["c63204"])
	b._on_hand_clicked(0, gs.hand_card_def(0,0))
	await settle(b)
	p.deck.append({"definitionId":"c63202","instanceId":"visible-top"})
	gs._grant_unit_armor(p.units[2], 3)
	await settle(b)
	check(b._ally_info.text.contains("牌库顶「童羽歌」"), "top card revealed in battle UI")
	check(find_face(b._hand_row, "童羽歌") != null and gs.card_instance(0, p.hand.size()).instanceId == "visible-top", "eligible top card mounted as a real hand widget")
	b.queue_free()
	await process_frame
	print("YANMIE_TRIO_UI checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
