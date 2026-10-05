extends Control
## 弹层统一处理 Esc 与遮罩点击，先消费按键，避免传给下方战场。

var on_close: Callable
var _closing := false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func close() -> void:
	if _closing: return
	_closing = true
	preload("res://scripts/ui/sfx.gd").play("ui_click", 0.6)
	if on_close.is_valid(): on_close.call()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
