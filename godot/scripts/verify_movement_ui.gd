extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("MOVEMENT_UI_FAIL ", text)
func click(face: Control) -> void:
 var motion := InputEventMouseMotion.new()
 motion.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
 root.push_input(motion, true)
 await process_frame
 await create_timer(0.14).timeout
 var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
 for down in [true, false]:
  var e := InputEventMouseButton.new()
  e.position = at
  e.button_index = MOUSE_BUTTON_LEFT
  e.pressed = down
  root.push_input(e, true)
func find_tile(n: Node, name: String) -> Control:
 if n is Control and n.get("data") is Dictionary and n.get("data").get("name") == name: return n
 for c in n.get_children():
  var found := find_tile(c, name)
  if found != null: return found
 return null
func texts(n: Node) -> String:
 var value := str(n.text) + "\n" if n is Label or n is RichTextLabel else ""
 for c in n.get_children(): value += texts(c)
 return value
func hand(b, ids: Array) -> void:
 b.gs.player(0).hand.clear()
 for i in ids.size(): b.gs.player(0).hand.append({"instanceId": "movement-ui-%d" % i, "definitionId": ids[i]})
 b._last_view = {}
 b._refresh()
func settled(b) -> void:
 for i in 3: await process_frame
 await create_timer(b._presentation_remaining() + 0.18).timeout
 await process_frame
func choose(b, name: String) -> void:
 await create_timer(0.25).timeout
 var tile := find_tile(b._choice_layer, name)
 check(tile != null, "real choice tile " + name)
 if tile != null:
  var bounds := Rect2(tile.global_position, tile.size)
  check(bounds.position.x >= 0 and bounds.end.x <= root.size.x and bounds.position.y >= 0 and bounds.end.y <= root.size.y, "choice tile visible inside physical screen")
  await click(tile)
 await process_frame
func capture(name: String) -> void:
 if out.is_empty(): return
 await create_timer(0.15).timeout
 await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func run() -> void:
 var stores := Support.isolate_stores()
 if not OS.get_cmdline_user_args().is_empty():
  out = OS.get_cmdline_user_args()[0]
  DirAccess.make_dir_recursive_absolute(out)
 root.theme = ThemeBuilder.build_theme()
 for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
  root.size = physical
  if not out.is_empty(): DisplayServer.window_set_size(physical)
  var b := Battle.new()
  b.setup(["xiaolunan", "lianyou", "yatiangou", "basalt"], ["xiaolunan", "lianyou", "yatiangou", "basalt"], 20261014)
  b._ai_thinking = true
  for p in b.gs.players:
   p.hand.clear()
   p.energy = 4
   p.levelUpUsed = true
   for u in p.units:
    u.level = 3
    u.charge = 0
  root.add_child(b)
  var gs = b.gs
  var p: Dictionary = gs.player(0)
  var enemy: Dictionary = gs.player(1)
  p.units[0].charge = 2
  hand(b, ["c16302"])
  await create_timer(0.25).timeout
  await click(b._hand_row.get_child(0))
  check(gs.pending_choice.get("type") == "movement-burst" and p.energy == 4 and p.units[0].charge == 2, "actual aid click opens burst before payment")
  await choose(b, "普通使用")
  check(b._pending_target_card == 0 and gs.pending_choice.is_empty(), "normal branch enters actual allied target picker")
  await click(b._unit_widget(str(enemy.units[0].uid)))
  check(p.hand.size() == 1 and p.energy == 4, "enemy target UIinput rejected without spend")
  await click(b._unit_widget(str(p.units[2].uid)))
  await settled(b)
  check(p.units[2].attack == 2 and p.units[2].maxHp == 7 and p.units[2].shield == 1 and p.units[0].charge == 2, "ordinary singleallystats+armor only noenergyconsumption")
  p.energy = 4
  hand(b, ["c16302"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  await choose(b, "爆能2")
  await settled(b)
  check(p.units[0].charge == 0 and p.hand.is_empty() and p.units.all(func(u): return int(u.shield) >= 1), "burst2 actualchoice autoallallies paysonce")
  p.units[0].charge = 2
  p.energy = 0
  hand(b, ["c16303"])
  await create_timer(0.2).timeout
  check(b._hand_playability(0).ok, "zero-fire burstinstant card is enabled")
  await click(b._hand_row.get_child(0))
  await capture("%d-01-burst-selection" % physical.x)
  await choose(b, "爆能2")
  check(b._pending_target_card == 0 and gs.hand_card_def(0, 0).keywords.has("instant"), "instantbranchquoted beforeactualtargetchoice")
  await click(b._unit_widget(str(enemy.units[0].uid)))
  await settled(b)
  check(enemy.units[0].frozen == 1 and enemy.units[0].hp == 3 and p.energy == 0 and p.units[0].charge == 0, "burstinstanttargetinput stunsthendamage nofire")
  p.energy = 4
  hand(b, ["c13903"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  await click(b._unit_widget(str(enemy.units[1].uid)))
  await settled(b)
  check(enemy.units[1].front == 1 and enemy.units[1].frozen == 1 and p.units[2].front == 1, "featheractualenemyinput forcespositionthenmovesCrow")
  await capture("%d-02-feather-movement" % physical.x)
  p.energy = 4
  hand(b, ["c13907"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  await click(b._unit_widget(str(enemy.units[3].uid)))
  await settled(b)
  check(enemy.units[3].get("movementHolders", []).size() == 1 and enemy.units[3].frozen == 1, "hero targetinput holdsstun")
  b._show_unit_popover(enemy.units[3], 1, 3)
  check("眩晕" in texts(b._tooltip), "actual inspector shows held stun")
  b._hide_tooltip()
  p.energy = 4
  hand(b, ["c13901"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  await settled(b)
  check(not enemy.units[3].has("movementHolders") and enemy.units[3].frozen == 0 and p.units[2].front == 0, "nextactualcrowcard releasesholdandmovesreserve")
  p.energy = 4
  hand(b, ["c13307"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  await settled(b)
  p.energy = 0
  p.attackUsed = true
  p.units[1].charge = 3
  enemy.units[1].front = 0
  b._last_view = {}
  b._refresh()
  await process_frame
  await click(b._unit_widget(str(p.units[1].uid)))
  check(b._selected_attacker == 1, "awakeextraordinaryattack actualunit selectableatzerofire")
  await click(b._enemy_target_btn)
  await settled(b)
  check(p.units[1].charge == 1 and p.energy == 0 and p.attackUsed, "actualawake attackpays3thengains1fromavatarhit")
  b.queue_free()
  await process_frame
 Support.cleanup_audio()
 await process_frame
 await process_frame
 Support.cleanup_stores(stores)
 print("MOVEMENT_UI checks=%d failures=%d" % [checks, failures])
 quit(0 if failures == 0 else 1)
