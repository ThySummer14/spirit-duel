extends SceneTree
## 视频布局回归：错落肖像在不同前线组合下仍能独立命中，宽屏和普通窗口均可操作。

const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const ALLY := ["ember", "basalt", "lumen", "rime"]
const FOE := ["storm", "kongo", "frostblade", "ink"]
var checks := 0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _check_clear_portraits(battle: BattleScreen, scenario: String) -> void:
	var ids := battle._unit_widgets.keys()
	var intersections: PackedStringArray = []
	for i in ids.size():
		var a: Rect2 = battle._unit_widgets[ids[i]].get_global_rect().grow(4.0)
		for j in range(i + 1, ids.size()):
			var b: Rect2 = battle._unit_widgets[ids[j]].get_global_rect().grow(4.0)
			if a.intersects(b): intersections.append("%s / %s" % [ids[i], ids[j]])
	_check(intersections.is_empty(), "%s keeps full portrait frames separate: %s" % [scenario, ", ".join(intersections)])


func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
	await process_frame
	for viewport in [Vector2i(1024, 720), Vector2i(1280, 800), Vector2i(1600, 740), Vector2i(1729, 800)]:
		root.size = viewport
		var battle := BattleScreen.new()
		battle.setup(ALLY, FOE, 20261006)
		battle._ai_thinking = true
		root.add_child(battle)
		var own := battle.gs.player(0)
		own.hand = [{"instanceId": "video-layout-brace", "definitionId": "brace"}]
		for player in battle.gs.players:
			player.levelUpUsed = true
			for unit in player.units: unit.level = 3
		var reserve_centers := {}
		# 包括空前线，以及四个原槽位的全部敌我组合。
		for ally_front in range(-1, 4):
			for enemy_front in range(-1, 4):
				for side in 2:
					for i in 4:
						battle.gs.player(side).units[i].front = int(i == (ally_front if side == 0 else enemy_front))
				battle._refresh()
				await create_timer(battle._presentation_remaining() + 0.04).timeout
				await process_frame
				battle._on_hand_clicked(0, ContentLoader.card_def("brace"))
				_check(battle._unit_widgets.size() == 8, "front movement preserves exactly eight portrait widgets")
				_check_clear_portraits(battle, "%s fronts=%d/%d" % [viewport, ally_front, enemy_front])
				for uid in battle._unit_widgets:
					var face: Control = battle._unit_widgets[uid]
					var rect := face.get_global_rect()
					var context: Dictionary = battle._aim_context(rect.get_center())
					_check(context.get("target") == uid, "portrait center remains independently targetable at %s, fronts=%d/%d, uid=%s" % [viewport, ally_front, enemy_front, uid])
					_check(rect.position.x >= 0 and rect.end.x <= battle.size.x and rect.position.y >= 0 and rect.end.y <= battle.size.y, "portrait stays in viewport")
					if ally_front == -1 and enemy_front == -1: reserve_centers[uid] = rect.get_center()
					if face.get_parent() in [battle._ally_reserve, battle._enemy_reserve]:
						_check(rect.get_center().is_equal_approx(reserve_centers[uid]), "reserve vacancies never shift another unit's slot")
		var summons: Array = []
		for side in 2:
			summons.append(battle.gs.VerifiedRules.NativeSummons.summon(battle.gs, side, 0, "layout-summon", "战场召唤物", 2, 4))
		battle._refresh()
		await create_timer(0.28).timeout
		_check(battle._unit_widgets.size() == 10, "both front summons fit alongside all eight reserve units")
		_check_clear_portraits(battle, "%s two fronts and full reserves" % viewport)
		for side in 2:
			var replacement: Dictionary = battle.gs.VerifiedRules.NativeSummons.summon(battle.gs, side, 0, "layout-replacement", "接替召唤物", 3, 5)
			battle._refresh()
			await process_frame
			_check(battle._unit_widget(str(summons[side].uid)) == null and battle._unit_widget(str(replacement.uid)) != null, "a replacement summon takes the front slot once")
		_check_clear_portraits(battle, "%s replacement fronts" % viewport)
		_check(battle._enemy_reserve.get_child_count() >= 3, "reserve still displays all remaining units")
		_check(battle._end_btn.size.x == battle._end_btn.size.y, "turn seal remains circular")
		_check(battle._hand_scroll.get_global_rect().end.y <= battle.size.y, "hand area stays inside the viewport")
		root.size = Vector2i(1600, 740) if viewport.x == 1024 else Vector2i(1024, 720)
		await process_frame
		await process_frame
		_check_clear_portraits(battle, "%s resized with full reserves and both fronts" % root.size)
		root.size = viewport
		battle.queue_free()
		await process_frame
		var formation := FormationScreen.new()
		root.add_child(formation)
		formation.set_preselect(ALLY)
		await process_frame
		await process_frame
		var expected_ids := ContentLoader.playable_units().map(func(unit): return str(unit.id))
		var shown_ids := formation._unit_list.get_children().map(func(face): return str(face.data.id))
		expected_ids.sort()
		shown_ids.sort()
		_check(formation._unit_list.columns == 1 and shown_ids == expected_ids, "portrait rail keeps every playable unit accessible exactly once")
		_check(formation._deck_row.get_child_count() == 8 and formation._selected_row.get_child_count() == 4, "paper scroll and four formation slots preserve their contents")
		for slot in formation._deck_row.get_children():
			var card := slot.get_child(0) as Control
			_check(slot.get_global_rect().encloses(card.get_global_rect()), "each construction card remains inside its paper slot")
		for token in formation._selected_row.get_children():
			_check(token.get_global_rect().end.y <= formation.size.y, "formation diamond stays inside the viewport")
		formation.queue_free()
		await process_frame
	VerifySupport.cleanup_stores(fixture)
	print("VIDEO_LAYOUT checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("VIDEO_LAYOUT_OK")
	quit(0 if failures == 0 else 1)
