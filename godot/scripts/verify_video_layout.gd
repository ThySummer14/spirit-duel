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


func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
	await process_frame
	for viewport in [Vector2i(1280, 800), Vector2i(1729, 800)]:
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
				for uid in battle._unit_widgets:
					var face: Control = battle._unit_widgets[uid]
					var rect := face.get_global_rect()
					var context: Dictionary = battle._aim_context(rect.get_center())
					_check(context.get("target") == uid, "portrait center remains independently targetable at %s, fronts=%d/%d, uid=%s" % [viewport, ally_front, enemy_front, uid])
					_check(rect.position.x >= 0 and rect.end.x <= battle.size.x and rect.position.y >= 0 and rect.end.y <= battle.size.y, "portrait stays in viewport")
		_check(battle._enemy_reserve.get_child_count() >= 3, "reserve still displays all remaining units")
		_check(battle._end_btn.size.x == battle._end_btn.size.y, "turn seal remains circular")
		_check(battle._hand_scroll.get_global_rect().end.y <= battle.size.y, "hand area stays inside the viewport")
		battle.queue_free()
		await process_frame
		var formation := FormationScreen.new()
		root.add_child(formation)
		formation.set_preselect(ALLY)
		await process_frame
		await process_frame
		_check(formation._unit_list.columns == 1 and formation._unit_list.get_child_count() == 250, "portrait rail keeps all 250 units accessible")
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
