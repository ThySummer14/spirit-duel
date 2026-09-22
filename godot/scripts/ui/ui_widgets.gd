class_name UIWidgets
extends RefCounted

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
## Reusable control factories for unit panels, hand cards, tooltips.


static func make_unit_panel(unit: Dictionary, on_click: Callable, compact: bool = false) -> PanelContainer:
	var accent := ThemeBuilder.unit_color_of(unit)
	var pc := PanelContainer.new()
	pc.set_meta("unit_uid", unit.get("uid", ""))
	var sb := ThemeBuilder.panel(Color("0f1524"), accent.lerp(ThemeBuilder.RULE, 0.55), 10, 1)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(148, 168) if compact else Vector2(160, 190)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	pc.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)
	var name_l := ThemeBuilder.label(str(unit.get("name", "?")), 15, ThemeBuilder.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var lv := ThemeBuilder.chip("%d勾" % int(unit.get("level", 0)), ThemeBuilder.GOLD)
	top.add_child(lv)

	if not compact:
		var title := ThemeBuilder.dim_label(str(unit.get("title", "")))
		vbox.add_child(title)

	var art := _art_rect(unit, Vector2(56, 56) if compact else Vector2(72, 72))
	vbox.add_child(art)

	var hp_atk := HBoxContainer.new()
	hp_atk.add_theme_constant_override("separation", 8)
	vbox.add_child(hp_atk)
	hp_atk.add_child(ThemeBuilder.chip("攻 %d" % int(unit.get("attack", 0)), ThemeBuilder.DANGER_SOFT))
	hp_atk.add_child(ThemeBuilder.chip("命 %d/%d" % [int(unit.get("hp", 0)), int(unit.get("maxHp", 0))], ThemeBuilder.OK))

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 4)
	vbox.add_child(status)
	if int(unit.get("shield", 0)) > 0:
		status.add_child(ThemeBuilder.chip("盾%d" % int(unit.shield), ThemeBuilder.INFO))
	if int(unit.get("frozen", 0)) > 0:
		status.add_child(ThemeBuilder.chip("眩晕", ThemeBuilder.INFO))
	if int(unit.get("brittle", 0)) > 0:
		status.add_child(ThemeBuilder.chip("晶裂", ThemeBuilder.WARN))
	if unit.get("unyielding", false):
		status.add_child(ThemeBuilder.chip("不屈", ThemeBuilder.GOLD))
	if int(unit.get("knockout", 0)) > 0:
		status.add_child(ThemeBuilder.chip("气绝%d" % int(unit.knockout), ThemeBuilder.DANGER))

	if int(unit.get("hp", 0)) <= 0:
		pc.modulate = Color(1, 1, 1, 0.45)
	if int(unit.get("front", 0)) == 1:
		sb.border_color = ThemeBuilder.GOLD_BRIGHT
		sb.set_border_width_all(2)

	var btn := Button.new()
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): on_click.call(unit))
	btn.mouse_entered.connect(func(): pc.self_modulate = Color(1.08, 1.06, 1.02))
	btn.mouse_exited.connect(func(): pc.self_modulate = Color.WHITE)
	pc.add_child(btn)
	btn.raise()
	return pc


static func _art_rect(unit: Dictionary, size: Vector2) -> Control:
	var color := ThemeBuilder.unit_color_of(unit)
	var path := "res://assets/%s.svg" % unit.get("id", "ink")
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = size
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = size
		holder.add_child(tr)
	else:
		var cr := ColorRect.new()
		cr.color = Color(color.r, color.g, color.b, 0.35)
		cr.custom_minimum_size = size
		holder.add_child(cr)
	return holder


static func make_hand_card(card: Dictionary, affordable: bool, on_click: Callable, index: int = -1) -> Control:
	var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
	var tcolor := ThemeBuilder.type_color_of(str(card.get("type", "spell")))
	var pc := PanelContainer.new()
	var bg := Color("1a2133")
	if not affordable:
		bg = Color("12161f")
	var sb := ThemeBuilder.panel(bg, rarity if affordable else ThemeBuilder.RULE_SOFT, 10, 1)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(128, 188)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	pc.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var cost_sb := ThemeBuilder.panel(Color("2f2712") if affordable else Color("23273a"), ThemeBuilder.GOLD if affordable else ThemeBuilder.RULE_SOFT, 6, 1)
	var cost_p := PanelContainer.new()
	cost_p.add_theme_stylebox_override("panel", cost_sb)
	var cost_l := ThemeBuilder.label(str(int(card.get("cost", 0))), 14, ThemeBuilder.GOLD_BRIGHT if affordable else ThemeBuilder.TEXT_FAINT)
	cost_p.add_child(cost_l)
	top.add_child(cost_p)
	if index >= 0:
		top.add_child(ThemeBuilder.dim_label("[%d]" % (index + 1), 11))
	var type_l := ThemeBuilder.label(str(card.get("typeLabel", "")), 11, tcolor)
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(type_l)

	var name_l := ThemeBuilder.label(str(card.get("name", "?")), 14, ThemeBuilder.PAPER)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_l)

	var lv := ThemeBuilder.dim_label("Lv.%d" % int(card.get("level", 1)), 11)
	vbox.add_child(lv)

	var text := ThemeBuilder.dim_label(str(card.get("text", "")), 12)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(0, 64)
	vbox.add_child(text)

	var btn := Button.new()
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not affordable
	if not affordable:
		pc.modulate = Color(0.85, 0.85, 0.9)
	btn.pressed.connect(func(): on_click.call(index if index >= 0 else 0, card))
	pc.add_child(btn)
	btn.raise()
	return pc


static func make_tooltip(card: Dictionary) -> PanelContainer:
	var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
	var pc := ThemeBuilder.panel(Color("141a2e"), rarity, 12, 1)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", pc)
	panel.custom_minimum_size = Vector2(320, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var header := HBoxContainer.new()
	header.add_child(ThemeBuilder.label(str(card.get("name", "?")), 16, ThemeBuilder.PAPER))
	header.add_child(ThemeBuilder.chip(str(card.get("typeLabel", "")), ThemeBuilder.type_color_of(str(card.get("type", "")))))
	header.add_child(ThemeBuilder.chip(str(card.get("rarity", "")).to_upper(), rarity))
	vbox.add_child(header)
	vbox.add_child(ThemeBuilder.dim_label("所属：%s · 等级 %d · 消耗 %d 鬼火" % [
		ContentLoader.unit_def(str(card.get("unitId", ""))).get("name", "?"),
		int(card.get("level", 1)), int(card.get("cost", 0))
	]))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(0, 80)
	body.text = str(card.get("text", ""))
	body.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(body)
	if card.get("formAbility"):
		vbox.add_child(ThemeBuilder.label("形态能力：%s" % card.formAbility, 13, ThemeBuilder.GOLD))
	var tags: Array = card.get("tags", [])
	if not tags.is_empty():
		vbox.add_child(ThemeBuilder.dim_label("标签：%s" % ", ".join(PackedStringArray(tags)), 12))
	return panel


static func make_unit_popover(unit: Dictionary) -> PanelContainer:
	var accent := ThemeBuilder.unit_color_of(unit)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.panel(Color("141a2e"), accent, 12, 1))
	panel.custom_minimum_size = Vector2(340, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	vbox.add_child(ThemeBuilder.label("%s · %s" % [unit.get("name", "?"), unit.get("title", "")], 18, ThemeBuilder.PAPER))
	vbox.add_child(ThemeBuilder.dim_label(str(unit.get("role", "")), 12))
	vbox.add_child(ThemeBuilder.label("攻 %d　命 %d/%d　盾 %d　勾 %d" % [
		int(unit.get("attack", 0)), int(unit.get("hp", 0)), int(unit.get("maxHp", 0)),
		int(unit.get("shield", 0)), int(unit.get("level", 0))
	], 14, ThemeBuilder.TEXT))
	if unit.get("formAbility"):
		vbox.add_child(ThemeBuilder.label("形态：%s" % unit.formAbility, 13, ThemeBuilder.GOLD))
	if unit.get("form") is Dictionary and not (unit.form as Dictionary).is_empty():
		vbox.add_child(ThemeBuilder.dim_label("当前形态：%s" % unit.form.get("name", "—"), 12))
	if unit.get("awakened", false):
		vbox.add_child(ThemeBuilder.chip("已觉醒", ThemeBuilder.TYPE_AWAKEN))
	var status_parts: Array = []
	if int(unit.get("frozen", 0)) > 0:
		status_parts.append("眩晕×%d" % int(unit.frozen))
	if int(unit.get("brittle", 0)) > 0:
		status_parts.append("晶裂×%d" % int(unit.brittle))
	if unit.get("unyielding", false):
		status_parts.append("不屈")
	if int(unit.get("knockout", 0)) > 0:
		status_parts.append("气绝倒计时 %d" % int(unit.knockout))
	if int(unit.get("front", 0)) == 1:
		status_parts.append("前线")
	if not status_parts.is_empty():
		vbox.add_child(ThemeBuilder.dim_label("状态：%s" % " · ".join(PackedStringArray(status_parts)), 12))
	var def := ContentLoader.unit_def(str(unit.get("id", "")))
	var passive := ContentLoader.passive_text(def, bool(unit.get("awakened", false)))
	if passive != "":
		vbox.add_child(ThemeBuilder.label(passive, 13, ThemeBuilder.PAPER_DIM))
	return panel
