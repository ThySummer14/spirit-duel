extends SceneTree
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")

func _init() -> void:
	var host := Control.new()
	host.theme = ThemeBuilder.build_theme()
	host.custom_minimum_size = Vector2(1280, 800)
	root.add_child(host)
	var battle := BattleScreen.new()
	battle.setup(["ember", "basalt", "lumen", "rime"], ["storm", "kongo", "frostblade", "ink"], 20260922)
	battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(battle)
	await process_frame
	await process_frame
	print("BATTLE_DEBUG gs=", battle.gs != null, " ally_reserve_children=", battle._ally_reserve.get_child_count() if battle._ally_reserve else -1)
	if battle._ally_reserve:
		for c in battle._ally_reserve.get_children():
			print("  child ", c.get_class(), " ", c.get_meta("unit_uid", "-"), " size=", c.size, " min=", c.custom_minimum_size)
	print("HAND ", battle._hand_row.get_child_count() if battle._hand_row else -1)
	quit(0)
