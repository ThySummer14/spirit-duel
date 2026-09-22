class_name UIWidgets
extends RefCounted

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
## Reusable control factories for unit panels, hand cards, tooltips.


static func make_unit_panel(unit: Dictionary, on_click: Callable, compact: bool = false, highlight: bool = false) -> PanelContainer:
	var accent := ThemeBuilder.unit_color_of(unit)
	var pc := PanelContainer.new()
	pc.set_meta("unit_uid", unit.get("uid", ""))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a2236") if highlight else Color("101624")
	sb.border_color = ThemeBuilder.GOLD_BRIGHT if highlight else accent.lerp(ThemeBuilder.RULE, 0.45)
	sb.set_border_width_all(2 if highlight else 1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if highlight:
		sb.shadow_color = Color(ThemeBuilder.GOLD.r, ThemeBuilder.GOLD.g, ThemeBuilder.GOLD.b, 0.25)
		sb.shadow_size = 10
	else:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 4
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(128, 148) if compact else Vector2(140, 168)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	pc.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	vbox.add_child(top)
	var name_l := ThemeBuilder.label(str(unit.get("name", "?")), 13, ThemeBuilder.PAPER if not highlight else ThemeBuilder.GOLD_BRIGHT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	top.add_child(name_l)
	top.add_child(ThemeBuilder.chip("%d勾" % int(unit.get("level", 0)), ThemeBuilder.GOLD if int(unit.get("level", 0)) > 0 else ThemeBuilder.TEXT_FAINT))

	var art := _art_rect(unit, Vector2(52, 52) if compact else Vector2(64, 64))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(art)

	var hp_atk := HBoxContainer.new()
	hp_atk.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_atk.add_theme_constant_override("separation", 4)
	vbox.add_child(hp_atk)
	hp_atk.add_child(ThemeBuilder.chip("攻%d" % int(unit.get("attack", 0)), ThemeBuilder.DANGER_SOFT))
	hp_atk.add_child(ThemeBuilder.chip("命%d/%d" % [int(unit.get("hp", 0)), int(unit.get("maxHp", 0))], ThemeBuilder.OK))

	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 3)
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
	if int(unit.get("armorBreak", 0)) > 0:
		status.add_child(ThemeBuilder.chip("破甲%d" % int(unit.armorBreak), ThemeBuilder.WARN))
	if int(unit.get("charge", 0)) > 0:
		status.add_child(ThemeBuilder.chip("充%d" % int(unit.charge), ThemeBuilder.INFO))
	if unit.get("form") is Dictionary and not (unit.form as Dictionary).is_empty():
		status.add_child(ThemeBuilder.chip("形态", ThemeBuilder.TYPE_FORM))

	if int(unit.get("hp", 0)) <= 0:
		pc.modulate = Color(1, 1, 1, 0.45)
	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(func(): on_click.call())
	pc.add_child(click)
	if click.get_parent() != null:
		click.get_parent().move_child(click, -1)
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


static func make_hand_card(card: Dictionary, affordable: bool, on_click: Callable, index: int = -1, block_reason: String = "") -> Control:
	var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
	var tcolor := ThemeBuilder.type_color_of(str(card.get("type", "spell")))
	var pc := PanelContainer.new()
	var bg := Color("151c2e")
	if not affordable:
		bg = Color("0f141f")
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = rarity if affordable else ThemeBuilder.RULE_SOFT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	if affordable:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(118, 176)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	pc.add_child(outer)

	# 顶栏：费用印 + 序号 + 类型
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	var top_pad := MarginContainer.new()
	top_pad.add_theme_constant_override("margin_left", 8)
	top_pad.add_theme_constant_override("margin_right", 8)
	top_pad.add_theme_constant_override("margin_top", 8)
	top_pad.add_child(top)
	outer.add_child(top_pad)

	var cost_p := PanelContainer.new()
	var cost_sb := StyleBoxFlat.new()
	cost_sb.bg_color = Color("3a2d12") if affordable else Color("23273a")
	cost_sb.border_color = ThemeBuilder.GOLD if affordable else ThemeBuilder.RULE_SOFT
	cost_sb.set_border_width_all(1)
	cost_sb.set_corner_radius_all(999)
	cost_sb.content_margin_left = 8
	cost_sb.content_margin_right = 8
	cost_sb.content_margin_top = 2
	cost_sb.content_margin_bottom = 2
	cost_p.add_theme_stylebox_override("panel", cost_sb)
	cost_p.add_child(ThemeBuilder.label(str(int(card.get("cost", 0))), 13, ThemeBuilder.GOLD_BRIGHT if affordable else ThemeBuilder.TEXT_FAINT))
	top.add_child(cost_p)
	if index >= 0:
		top.add_child(ThemeBuilder.dim_label("[%d]" % (index + 1), 10))
	var type_l := ThemeBuilder.label(str(card.get("typeLabel", "")), 10, tcolor)
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(type_l)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	var body_pad := MarginContainer.new()
	body_pad.add_theme_constant_override("margin_left", 10)
	body_pad.add_theme_constant_override("margin_right", 10)
	body_pad.add_child(body)
	outer.add_child(body_pad)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var name_l := ThemeBuilder.label(str(card.get("name", "?")), 14, ThemeBuilder.PAPER)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(name_l)
	if block_reason != "":
		var why := ThemeBuilder.label(block_reason, 10, ThemeBuilder.WARN)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(why)
	var lv := ThemeBuilder.dim_label("Lv.%d" % int(card.get("level", 1)), 10)
	body.add_child(lv)
	var text := ThemeBuilder.dim_label(str(card.get("text", "")), 11)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(0, 56)
	text.max_lines_visible = 5
	body.add_child(text)

	# 底部稀有度条
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 4)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = rarity if affordable else ThemeBuilder.RULE_SOFT
	bar.add_theme_stylebox_override("panel", bar_sb)
	outer.add_child(bar)

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
	if btn.get_parent() != null:
		btn.get_parent().move_child(btn, -1)
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
	if int(unit.get("knockout", 0)) > 0:
		vbox.add_child(ThemeBuilder.chip("气绝剩 %d 回合" % int(unit.knockout), ThemeBuilder.DANGER))
	if int(unit.get("armorBreak", 0)) > 0:
		vbox.add_child(ThemeBuilder.chip("破甲 %d" % int(unit.armorBreak), ThemeBuilder.WARN))
	if int(unit.get("charge", 0)) > 0:
		vbox.add_child(ThemeBuilder.chip("充能 %d" % int(unit.charge), ThemeBuilder.INFO))
	if unit.get("awakened", false):
		vbox.add_child(ThemeBuilder.chip("已觉醒", ThemeBuilder.TYPE_AWAKEN))
	var passive_data = unit.get("passive", {})
	if passive_data is Dictionary and passive_data.get("text"):
		var pt := ThemeBuilder.label("被动 · %s：%s" % [passive_data.get("name", ""), passive_data.get("text", "")], 12, ThemeBuilder.GOLD)
		pt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(pt)
	var awake_data = unit.get("awakenedPassive", {})
	if unit.get("awakened", false) and awake_data is Dictionary and awake_data.get("text"):
		var at := ThemeBuilder.label("觉醒 · %s：%s" % [awake_data.get("name", ""), awake_data.get("text", "")], 12, ThemeBuilder.GOLD_BRIGHT)
		at.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(at)
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
