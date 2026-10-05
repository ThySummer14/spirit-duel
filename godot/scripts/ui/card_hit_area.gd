extends Button
## 透明点击层沿用卡面的命中范围，抬起后的可见牌面仍能点选或拖拽。
func _has_point(point: Vector2) -> bool:
	var face := get_parent()
	return face.hit_test(point) if face != null and face.has_method("hit_test") else Rect2(Vector2.ZERO, size).has_point(point)
