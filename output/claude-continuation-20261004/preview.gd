extends SceneTree
## 独立验收窗口，所有阵容、收藏与音量操作都在临时数据中。
const VerifySupport := preload("res://scripts/verify_support.gd")
var fixture := ""
func _initialize() -> void:
	fixture = VerifySupport.isolate_stores()
	root.title = "灵枢战线 · 接续验收"
	_start.call_deferred()
func _start() -> void:
	root.add_child(load("res://scenes/main_menu.tscn").instantiate())
func _finalize() -> void:
	VerifySupport.cleanup_stores(fixture)
