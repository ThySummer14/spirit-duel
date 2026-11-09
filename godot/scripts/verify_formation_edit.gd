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
	await _click(candidate)
	_check(form._pending_card == replacement and form._cards_in_deck("yaodaoji") == original, "clicking a new card in a full deck selects the replacement")
	_check(_slot(form, 0).selected, "a legal replacement slot highlights")
	await _click(_slot(form, 0))
	var next := original.duplicate()
	next[0] = replacement
	_check(form._pending_card.is_empty() and form._cards_in_deck("yaodaoji") == next, "tapping the paper slot swaps exactly one card")
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
	wheel.factor = 1.0
	wheel.pressed = true
	root.push_input(wheel, true)
	_check(form._card_scroll.scroll_horizontal < 160, "horizontal trackpad scrolling follows the same direction as dragging")

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
	form._show_unit(other)
	_check(form.selected_units() == LINEUP, "browsing an out-of-lineup unit does not edit the lineup")
	form._add_focused()
	_check(form.selected_units() == ["yingcao", "jutun-tongzi", "bingyong", "datiangou"], "explicit replace acts on the current lineup position")
	form._show_unit(Content.unit_def("yaodaoji"))
	form._add_focused()
	await _click(form._save_btn)
	_check(SaveStore.get_lineup() == LINEUP and SaveStore.get_deck("yaodaoji")[0] == replacement, "saving commits the lineup and edited deck together")
	form.queue_free()
	await process_frame
	Support.cleanup_stores(fixture)
	print("FORMATION_EDIT checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("FORMATION_EDIT_OK")
	quit(0 if failures == 0 else 1)
