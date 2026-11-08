extends SceneTree
const Content:=preload("res://scripts/content_loader.gd")
const CardFace:=preload("res://scripts/ui/card_face.gd")
var checks:=0
var failures:=0
func check(ok:bool,detail:String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("SERPENT_GHOST_ASSETS_FAIL ",detail)
func _initialize() -> void:
	for id in ["sg-ghost-white","sg-snake"]:
		var path:String="res://"+str(Content.unit_def(id).art)
		check(ResourceLoader.load(path) is Texture2D,"actual derivative unit texture "+id)
	for id in ["sg-white-awaken","sg-white-soul"]:
		var face:=CardFace.new();face.data=Content.card_def(id);face.refresh_art()
		check(face._original_card!=null and face._original_card.resource_path=="res://assets/official/cards/%s.png"%id,"actual derivative original card texture "+id)
		face.free()
	print("SERPENT_GHOST_ASSETS checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
