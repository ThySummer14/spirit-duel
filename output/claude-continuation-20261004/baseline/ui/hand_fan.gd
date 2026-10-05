extends Control
## 扇形手牌：按张数收紧间距、轻微弧度与倾角；悬停的牌抬起、放大、置顶，相邻牌让位。
## 子节点即卡面，顺序与手牌下标一致（测试与键盘 1-9 依赖此顺序）。

const CARD_SIZE := Vector2(124, 192)
const HOVER_LIFT := 46.0
const HOVER_SCALE := 1.16

var _hovered: Control
var _tweens: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(relayout)


func add_card(card: Control, at_index: int, from_global: Variant = null) -> void:
	add_child(card)
	move_child(card, at_index)
	card.size = CARD_SIZE
	card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	if card.has_signal("hover_changed"):
		card.hover_changed.connect(_on_hover.bind(card))
	if from_global is Vector2:
		card.position = (from_global as Vector2) - global_position
		card.scale = Vector2(0.55, 0.55)
		card.rotation = 0.35
		card.modulate.a = 0.0


func _on_hover(hovering: bool, card: Control) -> void:
	if hovering:
		_hovered = card
	elif _hovered == card:
		_hovered = null
	relayout()


func card_rest_rect(card: Control) -> Rect2:
	return Rect2(card.global_position, card.size * card.scale)


func relayout() -> void:
	var cards: Array = get_children().filter(func(c): return c is Control and not c.is_queued_for_deletion())
	var n := cards.size()
	if n == 0: return
	var w := size.x
	var step := minf(CARD_SIZE.x + 12.0, (w - CARD_SIZE.x - 40.0) / maxf(1.0, n - 1))
	var total := step * (n - 1) + CARD_SIZE.x
	var start := (w - total) * 0.5
	var hover_index := cards.find(_hovered)
	var spread := maxf(0.0, (CARD_SIZE.x * HOVER_SCALE - step) * 0.55) if hover_index >= 0 else 0.0
	for i in n:
		var card: Control = cards[i]
		var centered := (i - (n - 1) * 0.5)
		var arc := minf(1.0, 7.0 / maxf(n, 1))
		var rot := deg_to_rad(centered * 2.6 * arc)
		var y := size.y - CARD_SIZE.y + 6.0 + absf(centered) * absf(centered) * 1.6 * arc
		var x := start + i * step
		if hover_index >= 0 and i != hover_index:
			x += spread * signf(i - hover_index)
		var lift := Vector2.ZERO
		var vscale := 1.0
		if card == _hovered:
			# 抬起与放大只作用于绘制，命中区域留在原位，避免鼠标从底边滑出造成抖动
			rot = 0.0
			vscale = HOVER_SCALE
			lift = Vector2(0, -HOVER_LIFT - CARD_SIZE.y * (HOVER_SCALE - 1.0) * 0.5)
			card.z_index = 10
		else:
			card.z_index = 0
		if _tweens.has(card) and is_instance_valid(_tweens[card]): _tweens[card].kill()
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var dur := 0.14 if card == _hovered else 0.26
		tw.tween_property(card, "position", Vector2(x, y), dur)
		tw.tween_property(card, "rotation", rot, dur)
		tw.tween_property(card, "scale", Vector2.ONE, dur)
		tw.tween_property(card, "modulate:a", 1.0, 0.2)
		if "visual_offset" in card:
			tw.tween_property(card, "visual_offset", lift, dur)
			tw.tween_property(card, "visual_scale", vscale, dur)
		_tweens[card] = tw
