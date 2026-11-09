extends SceneTree

const Formation := preload("res://scripts/ui/formation_screen.gd")
const Content := preload("res://scripts/content_loader.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const Support := preload("res://scripts/verify_support.gd")
const LINEUP := ["yaodaoji", "jutun-tongzi", "bingyong", "datiangou"]
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


func _move(at: Vector2, relative := Vector2.ZERO, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.relative = relative
	if held: event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)


func _button(at: Vector2, held: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = held
	root.push_input(event, true)


func _click(control: Control) -> void:
	var at := _point(control)
	_move(at)
	_button(at, true)
	_button(at, false)
	await process_frame


func _slot(form: Formation, index: int) -> Control:
	return form._deck_row.get_child(index).get_child(0)


func _option(form: Formation, index: int) -> Control:
	return form._card_box.get_children().filter(func(face): return form._can_insert(face.data, index))[0]


func _run() -> void:
	var fixture := Support.isolate_stores()
	await process_frame
	root.size = Vector2i(1280, 800)
	var form := Formation.new()
	root.add_child(form)
	form.set_preselect(LINEUP)
	await process_frame
	await process_frame
	var original := form._cards_in_deck("yaodaoji").duplicate()
	_check(original.size() == 8 and not form._confirm_btn.disabled, "preselected starter deck is immediately usable")
	var focus_again: Control = form._unit_list.get_children().filter(func(face): return face.data.id == "yaodaoji")[0]
	await _click(focus_again)
	_check(form.selected_units() == LINEUP, "clicking the selected portrait inspects it without removing it")

	var candidate := _option(form, 0)
	var replacement: String = candidate.data.id
	var stable_slots := form._deck_row.get_children().map(func(slot): return slot.get_child(0).get_instance_id())
	await _click(candidate)
	_check(form._pending_card == replacement and form._cards_in_deck("yaodaoji") == original, "clicking a new card in a full deck selects the replacement")
	_check(_slot(form, 0).selected, "a legal replacement slot highlights")
	_check(form._deck_row.get_children().map(func(slot): return slot.get_child(0).get_instance_id()) == stable_slots, "choosing a replacement preserves all eight card widgets and their hover state")
	await _click(form._cancel_btn)
	_check(form._pending_card.is_empty() and form._cards_in_deck("yaodaoji") == original, "cancel replacement leaves the deck untouched")
	await _click(candidate)
	await _click(_slot(form, 0))
	var next := original.duplicate()
	next[0] = replacement
	_check(form._pending_card.is_empty() and form._cards_in_deck("yaodaoji") == next, "tapping the paper slot swaps exactly one card")
	_check(_slot(form, 1).get_instance_id() == stable_slots[1], "changing one card leaves the other slots alive")
	await _click(form._undo_btn)
	_check(form._cards_in_deck("yaodaoji") == original, "undo restores the exact previous eight cards")
	await _click(candidate)
	await _click(_slot(form, 0))
	await _click(_slot(form, 0))
	_check(form._cards_in_deck("yaodaoji").size() == 7 and form._confirm_btn.disabled, "removing a card opens a slot and disables an incomplete lineup")
	candidate = form._card_box.get_children().filter(func(face): return form._can_insert(face.data))[0]
	await _click(candidate)
	_check(form._cards_in_deck("yaodaoji").size() == 8 and not form._confirm_btn.disabled, "one click fills the empty slot")
	_check(SaveStore.get_deck("yaodaoji").is_empty(), "the draft leaves the saved deck untouched")

	form._card_scroll.scroll_horizontal = 160
	await process_frame
	var start := _point(form._card_scroll)
	var drag := Vector2(100, 0)
	_move(start)
	_button(start, true)
	_move(start + drag, drag, true)
	_check(form._card_scroll.scroll_horizontal < 160, "dragging right moves the visible cards to the right")
	_button(start + drag, false)
	await process_frame
	_check(form._pending_card.is_empty() and form._cards_in_deck("yaodaoji").size() == 8, "the swipe does not select or remove cards")
	form._card_scroll.scroll_horizontal = 160
	var wheel := InputEventMouseButton.new()
	wheel.position = start
	wheel.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	wheel.factor = 0.03
	wheel.pressed = true
	root.push_input(wheel, true)
	_check(form._card_scroll.scroll_horizontal > 160 and form._card_scroll.scroll_horizontal <= 164, "native wheel-right advances the viewport by a small amount, without a 72px jump")
	form._card_scroll.scroll_horizontal = 160
	var pan := InputEventPanGesture.new()
	pan.position = start
	pan.delta = Vector2(-0.3, 0.01)
	root.push_input(pan, true)
	_check(form._card_scroll.scroll_horizontal < 160, "negative native pan delta moves cards right, matching OS natural scrolling")
	_check(form._card_scroll.scroll_horizontal >= 148, "native precise pan preserves the gesture distance")
	form._card_scroll.scroll_horizontal = 160
	pan.delta = Vector2(0.003, 0)
	for i in 10: root.push_input(pan, true)
	_check(form._card_scroll.scroll_horizontal == 161, "subpixel pan updates accumulate instead of rounding each event away")
	form._inspect_card(candidate.data)
	await process_frame
	var before_modal := form._card_scroll.scroll_horizontal
	pan.delta = Vector2(1, 0)
	root.push_input(pan, true)
	_check(form._card_scroll.scroll_horizontal == before_modal, "a card inspector blocks background carousel gestures")
	for modal in get_nodes_in_group("formation_inspector"): modal.queue_free()
	await process_frame

	form._card_scroll.scroll_horizontal = 0
	await process_frame
	candidate = _option(form, 0)
	replacement = candidate.data.id
	var source := _point(candidate)
	var target := _point(_slot(form, 0))
	_move(source)
	_button(source, true)
	_move(source + Vector2(0, 38), Vector2(0, 38), true)
	_check(root.gui_is_dragging(), "vertical drag carries a card instead of panning the list")
	_move(target, target - source, true)
	_button(target, false)
	await process_frame
	_check(form._cards_in_deck("yaodaoji")[0] == replacement, "dropping on a filled paper slot replaces its card")
	var other := Content.unit_def("yingcao")
	form._card_scroll.scroll_horizontal = 180
	form._show_unit(other)
	await process_frame
	form._show_unit(Content.unit_def("yaodaoji"))
	await process_frame
	await process_frame
	_check(form._card_scroll.scroll_horizontal == 180, "returning to an inspected unit restores its card browsing position")
	form._show_unit(other)
	_check(form.selected_units() == LINEUP, "browsing an out-of-lineup unit does not edit the lineup")
	form._add_focused()
	_check(form.selected_units() == ["yingcao", "jutun-tongzi", "bingyong", "datiangou"], "explicit replace acts on the current lineup position")
	form._show_unit(Content.unit_def("yaodaoji"))
	form._add_focused()
	await _click(form._save_btn)
	_check(SaveStore.get_lineup() == LINEUP and SaveStore.get_deck("yaodaoji")[0] == replacement, "saving commits the lineup and edited deck together")
	for extent in [Vector2i(960, 600), Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = extent
		await process_frame
		await process_frame
		await process_frame
		_check(form._deck_paper.get_global_rect().end.y <= form.size.y, "deck remains in viewport at %s" % extent)
		_check(form._deck_row.get_global_rect().end.x <= form.size.x, "all eight deck slots fit at %s" % extent)
	form.queue_free()
	Support.cleanup_audio()
	await process_frame
	Support.cleanup_stores(fixture)
	print("FORMATION_EDIT checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("FORMATION_EDIT_OK")
	quit(0 if failures == 0 else 1)
