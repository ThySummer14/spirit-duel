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
  printerr("FORTUNE_PAIR_UI_FAIL ", text)
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
func escape() -> void:
 var e := InputEventKey.new()
 e.keycode = KEY_ESCAPE
 e.pressed = true
 root.push_input(e, true)
func texts(n: Node) -> String:
 var value := str(n.text) + "\n" if n is Label or n is RichTextLabel else ""
 for c in n.get_children(): value += texts(c)
 return value
func hand(b, ids: Array) -> void:
 b.gs.player(0).hand.clear()
 for i in ids.size(): b.gs.player(0).hand.append({"instanceId": "fortune-ui-%d" % i, "definitionId": ids[i]})
 b._last_view = {}
 b._refresh()
func settled(b) -> void:
 for i in 3: await process_frame
 await create_timer(b._presentation_remaining() + 0.18).timeout
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
  b.setup(["qingwa-ciqi", "shantu", "zuofutongzi", "fenghuanghuo"], ["qingwa-ciqi", "shantu", "zuofutongzi", "fenghuanghuo"], 20261013)
  b._ai_thinking = true
  for p in b.gs.players:
   p.hand.clear()
   p.energy = 4
   p.levelUpUsed = true
   for u in p.units: u.level = 3
  root.add_child(b)
  var gs = b.gs
  var p: Dictionary = gs.player(0)
  var enemy: Dictionary = gs.player(1)
  hand(b, ["c12604"])
  await create_timer(0.25).timeout
  await click(b._hand_row.get_child(0))
  check(b._pending_target_card == 0, "actual bomb opens target picker")
  check(gs.valid_targets(0, b._pending_target_card_def).has("avatar-1"), "enemy avatar selectable")
  escape()
  check(p.energy == 4 and p.hand.size() == 1, "cancel no spend or die")
  gs.VerifiedRules.Fortune.record_die(gs, 0, 6)
  gs._install_form(0, 1, ContentLoader.card_def("c12708"))
  b._last_view = {}
  b._refresh()
  await click(b._hand_row.get_child(0))
  await capture("%d-01-dice-targets" % physical.x)
  await click(b._enemy_target_btn)
  await settled(b)
  check(enemy.avatarHp == 24 and p.hand.is_empty(), "avatar input resolves six damage")
  p.energy = 4
  p.fortuneSixes = 3
  hand(b, ["c12702"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  check(not gs.valid_targets(0, b._pending_target_card_def).has(enemy.units[0].uid), "blessing excludes enemy after normal20210330")
  await click(b._unit_widget(str(enemy.units[0].uid)))
  check(p.hand.size() == 1 and p.energy == 4, "illegal enemy input keeps hand and cost")
  await click(b._unit_widget(str(p.units[0].uid)))
  await settled(b)
  # The earlier successful bomb also grants the frog its actual +2 power.
  check(p.units[0].attack == 7 and p.units[0].maxHp == 9 and p.units[0].swift, "allied input grants enhanced stats and swift")
  check(p.hand.size() == 1, "allied blessing input also draws after20210629")
  p.energy = 0
  p.attackUsed = false
  b._last_view = {}
  b._refresh()
  await process_frame
  await click(b._unit_widget(str(p.units[0].uid)))
  check(b._selected_attacker == 0, "allied swift selected at zero fire")
  await click(b._enemy_target_btn)
  await settled(b)
  check(p.attackUsed and p.energy == 0 and not p.units[0].get("swift", false), "actual zero-fire basic attack consumes enhanced swift")
  p.energy = 4
  enemy.units[0].front = 1
  hand(b, ["c12711"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  await settled(b)
  check(enemy.units[0].name == "小纸人" and enemy.units[0].attack == 1, "lasso click replaces enemy form")
  b._show_unit_popover(enemy.units[0], 1, 0)
  check("纸人 · 能力失效" in texts(b._tooltip), "inspector explains real ability suppression")
  await capture("%d-02-paper-transform" % physical.x)
  b._hide_tooltip()
  p.energy = 4
  enemy.units[0].front = 0
  # The preceding swift attack left the frog in front. Keep this target
  # alive through its counterstrike so forced movement is observable.
  enemy.units[3].maxHpBonus = 16
  enemy.units[3].hp = 20
  enemy.units[3].maxHp = 20
  hand(b, ["c12712"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  check(b._pending_target_card == 0, "forced attack opens enemy selector")
  await click(b._unit_widget(str(enemy.units[3].uid)))
  await settled(b)
  check(enemy.units[3].front == 1 and enemy.units[3].hp == 13 and p.hand.is_empty(), "forced enemy attack via real target input")
  p.energy = 4
  gs.VerifiedRules.Fortune.transform(gs, 0, 0, false)
  hand(b, ["c12604"])
  await create_timer(0.2).timeout
  await click(b._hand_row.get_child(0))
  check(p.hand.size() == 1 and p.energy == 4 and b._pending_target_card == -1, "paper original card actual click rejected without spending")
  p.fortuneSixes = 10
  hand(b, ["c12710"])
  await create_timer(0.2).timeout
  check(b._hand_row.get_child(0).data.level == 2, "modern win card displays second level")
  await click(b._hand_row.get_child(0))
  await settled(b)
  check(gs.winner == 0, "win card actual click special victory")
  await capture("%d-03-special-win" % physical.x)
  b.queue_free()
  await process_frame
 Support.cleanup_audio()
 await process_frame
 await process_frame
 Support.cleanup_stores(stores)
 print("FORTUNE_PAIR_UI checks=%d failures=%d" % [checks, failures])
 quit(0 if failures == 0 else 1)
