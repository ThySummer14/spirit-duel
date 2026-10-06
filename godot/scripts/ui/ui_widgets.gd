class_name UIWidgets
extends RefCounted

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const KeywordGlossary := preload("res://scripts/ui/keyword_glossary.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const ModalLayer := preload("res://scripts/ui/modal_layer.gd")
## Reusable control factories for unit panels, hand cards, inspectors and modals.


const CardFace := preload("res://scripts/ui/card_face.gd")
const CardHitArea := preload("res://scripts/ui/card_hit_area.gd")

static func make_unit_panel(unit: Dictionary, on_click: Callable, compact: bool = false, highlight: bool = false) -> Control:
	var face := CardFace.new()
	face.data = unit
	face.unit_mode = true
	face.selected = highlight
	face.custom_minimum_size = Vector2(96, 140) if compact else Vector2(160, 232)
	face.set_meta("unit_uid", unit.get("uid", ""))
	attach_click(face, func(): on_click.call(unit))
	return face


static func portrait(unit: Dictionary, min_size: Vector2) -> Control:
	var face := CardFace.new()
	face.data = unit
	face.unit_mode = true
	face.custom_minimum_size = min_size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


static func unit_token(unit: Dictionary, on_click: Callable, min_size: Vector2, shape: String = "diamond", selected: bool = false) -> Control:
	var face := CardFace.new()
	face.data = unit
	face.unit_mode = true
	face.portrait_only = true
	face.portrait_shape = shape
	face.selected = selected
	face.custom_minimum_size = min_size
	face.tooltip_text = str(unit.get("name", ""))
	if on_click.is_valid(): attach_click(face, on_click)
	else: face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


static func make_card_tile(card: Dictionary, on_click: Callable, min_size: Vector2 = Vector2(164, 258), selected: bool = false, note: String = "") -> Control:
	var face := CardFace.new()
	face.data = card
	face.selected = selected
	face.note = note
	face.custom_minimum_size = min_size
	if on_click.is_valid(): attach_click(face, on_click)
	return face


static func attach_click(face: Control, action: Callable, disabled: bool = false) -> Button:
	var click := CardHitArea.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.disabled = disabled
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		click.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	face.add_child(click)
	click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(action)
	click.set_drag_forwarding(face._get_drag_data, face._can_drop_data, face._drop_data)
	if face.has_method("bind_button"): face.bind_button(click)
	return click


static func make_hand_card(card: Dictionary, affordable: bool, on_click: Callable, index: int = -1, block_reason: String = "") -> Control:
	var face := CardFace.new()
	face.data = card
	face.enabled = affordable
	face.playable = affordable
	face.custom_minimum_size = Vector2(124, 192)
	face.set_meta("kind", "card")
	face.set_meta("block_reason", block_reason)
	# 不可用时按钮禁用，但悬停仍会触发检视，可看到不可用原因
	attach_click(face, func(): on_click.call(index if index >= 0 else 0, card), not affordable)
	return face


## 大卡检视：完整卡面 + 归属/费用 + 关键词释义 + 不可用原因
static func make_tooltip(card: Dictionary, reason: String = "") -> PanelContainer:
	var rarity := ThemeBuilder.rarity_color_of(str(card.get("rarity", "common")))
	var panel := PanelContainer.new()
	panel.set_meta("kind", "card")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := ThemeBuilder.glass(0.92, Color(rarity, 0.6), 14)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(300, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var portrait_card := make_card_tile(card, Callable(), Vector2(236, 364))
	portrait_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait_card)
	var header := HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(ThemeBuilder.chip(str(card.get("typeLabel", "")), ThemeBuilder.type_color_of(str(card.get("type", "")))))
	header.add_child(ThemeBuilder.chip(ThemeBuilder.rarity_label(str(card.get("rarity", ""))), rarity))
	var owner := ContentLoader.unit_def(str(card.get("unitId", "")))
	header.add_child(ThemeBuilder.chip("%s · 需 %d 勾玉" % [owner.get("name", "?"), int(card.get("level", 1))], ThemeBuilder.GOLD))
	vbox.add_child(header)
	if card.get("formAbility"):
		vbox.add_child(_wrapped("形态能力：%s" % card.formAbility, 13, ThemeBuilder.GOLD_BRIGHT, 272))
	var keywords = card.get("keywords", [])
	if keywords is Array:
		for k in keywords:
			var name := KeywordGlossary.label(str(k))
			if name == "": continue
			var rt := RichTextLabel.new()
			rt.bbcode_enabled = true
			rt.fit_content = true
			rt.scroll_active = false
			rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rt.custom_minimum_size = Vector2(272, 0)
			rt.add_theme_font_size_override("normal_font_size", 12)
			rt.add_theme_font_size_override("bold_font_size", 12)
			rt.text = "[b][color=#%s]%s[/color][/b]  %s" % [ThemeBuilder.GOLD_BRIGHT.to_html(false), name, KeywordGlossary.detail(str(k))]
			vbox.add_child(rt)
	if reason != "":
		var warn := _wrapped("⚠ " + reason, 13, ThemeBuilder.DANGER_SOFT, 272)
		vbox.add_child(warn)
	return panel


static func _wrapped(text: String, size: int, color: Color, width: float) -> Label:
	var l := ThemeBuilder.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _stat(text: String, value: String, color: Color) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(ThemeBuilder.label(text, 12, ThemeBuilder.TEXT_DIM))
	box.add_child(ThemeBuilder.bold_label(value, 16, color))
	return box


## 式神档案：肖像、数值、被动、状态
static func make_unit_popover(unit: Dictionary) -> PanelContainer:
	var accent := ThemeBuilder.unit_color_of(unit)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.custom_minimum_size = Vector2(340, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vbox.add_child(head)
	head.add_child(portrait(unit, Vector2(84, 112)))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	head.add_child(info)
	var name_l := ThemeBuilder.label(str(unit.get("name", "?")), 22, ThemeBuilder.PAPER)
	name_l.add_theme_font_override("font", ThemeBuilder.display_font())
	info.add_child(name_l)
	info.add_child(ThemeBuilder.label("%s · %s" % [unit.get("title", ""), unit.get("role", "")], 12, accent.lightened(0.3)))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	stats.add_child(_stat("攻", str(int(unit.get("attack", 0))), Color("f2d38c")))
	stats.add_child(_stat("命", "%d/%d" % [int(unit.get("hp", 0)), int(unit.get("maxHp", 0))], Color("f2a3a0")))
	if int(unit.get("shield", 0)) > 0: stats.add_child(_stat("盾", str(int(unit.shield)), Color("9fd0ff")))
	stats.add_child(_stat("勾", str(int(unit.get("level", 0))), ThemeBuilder.GOLD_BRIGHT))
	info.add_child(stats)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	if int(unit.get("front", 0)) == 1: chips.add_child(ThemeBuilder.chip("前线", ThemeBuilder.WARN))
	if int(unit.get("knockout", 0)) > 0: chips.add_child(ThemeBuilder.chip("气绝 · %d 回合" % int(unit.knockout), ThemeBuilder.DANGER))
	if int(unit.get("frozen", 0)) > 0: chips.add_child(ThemeBuilder.chip("眩晕 ×%d" % int(unit.frozen), Color("b39ce6")))
	if int(unit.get("armorBreak", 0)) > 0: chips.add_child(ThemeBuilder.chip("破甲 %d" % int(unit.armorBreak), ThemeBuilder.WARN))
	if int(unit.get("brittle", 0)) > 0: chips.add_child(ThemeBuilder.chip("晶裂 ×%d" % int(unit.brittle), Color("e08aa2")))
	if int(unit.get("charge", 0)) > 0: chips.add_child(ThemeBuilder.chip("充能 %d" % int(unit.charge), ThemeBuilder.INFO))
	if unit.get("unyielding", false): chips.add_child(ThemeBuilder.chip("不屈", ThemeBuilder.GOLD))
	if unit.get("awakened", false): chips.add_child(ThemeBuilder.chip("已觉醒", ThemeBuilder.TYPE_AWAKEN))
	if unit.get("form") is Dictionary and not (unit.form as Dictionary).is_empty():
		chips.add_child(ThemeBuilder.chip("形态 · %s" % unit.form.get("name", "—"), ThemeBuilder.TYPE_FORM))
	if chips.get_child_count() > 0: vbox.add_child(chips)
	else: chips.free()
	vbox.add_child(ThemeBuilder.hline())
	var def := ContentLoader.unit_def(str(unit.get("id", "")))
	var passive = def.get("passive", {})
	if passive is Dictionary and passive.get("text"):
		vbox.add_child(_titled("被动 · %s" % passive.get("name", ""), str(passive.text), ThemeBuilder.GOLD, unit.get("awakened", false)))
	var awake = def.get("awakenedPassive", {})
	if awake is Dictionary and awake.get("text"):
		vbox.add_child(_titled("觉醒 · %s" % awake.get("name", ""), str(awake.text), ThemeBuilder.TYPE_AWAKEN, not unit.get("awakened", false)))
	if unit.get("formAbility"):
		vbox.add_child(_titled("形态能力", str(unit.formAbility), ThemeBuilder.TYPE_FORM, false))
	return panel


static func _titled(title: String, body: String, color: Color, dim: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.modulate.a = 0.55 if dim else 1.0
	v.add_child(ThemeBuilder.section_label(title, 13))
	var l := _wrapped(body, 13, ThemeBuilder.PAPER_DIM if not dim else ThemeBuilder.TEXT_DIM, 316)
	v.add_child(l)
	v.add_theme_color_override("font_color", color)
	return v


## 全屏遮罩弹层：点击遮罩或按 Esc 关闭。返回内容容器。
static func show_modal(host: Control, content: Control, on_close: Callable = Callable()) -> Control:
	var layer := ModalLayer.new()
	layer.on_close = on_close
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.set_meta("modal", true)
	host.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.03, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(content)
	shade.gui_input.connect(layer._on_shade_input)
	layer.set_meta("close", layer.close)
	layer.modulate.a = 0.0
	content.pivot_offset = content.get_combined_minimum_size() * 0.5
	content.scale = Vector2(0.94, 0.94)
	var tw := layer.create_tween().set_parallel(true)
	tw.tween_property(layer, "modulate:a", 1.0, 0.16)
	tw.tween_property(content, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return layer


## 卡牌大图检视弹层（替代系统对话框）
static func show_card_modal(host: Control, card: Dictionary, extra: Control = null) -> Control:
	var panel := PanelContainer.new()
	var sb := ThemeBuilder.glass(0.94, Color(ThemeBuilder.rarity_color_of(str(card.get("rarity", "common"))), 0.6), 16)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	panel.add_child(row)
	var big := make_card_tile(card, Callable(), Vector2(260, 404))
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(big)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(300, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 10)
	scroll.add_child(info)
	var title := ThemeBuilder.label(str(card.get("name", "?")), 28, ThemeBuilder.PAPER)
	title.add_theme_font_override("font", ThemeBuilder.display_font())
	info.add_child(title)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_child(ThemeBuilder.chip(str(card.get("typeLabel", "")), ThemeBuilder.type_color_of(str(card.get("type", "")))))
	chips.add_child(ThemeBuilder.chip(ThemeBuilder.rarity_label(str(card.get("rarity", ""))), ThemeBuilder.rarity_color_of(str(card.get("rarity", "")))))
	chips.add_child(ThemeBuilder.chip("%d 勾 · %d 鬼火" % [int(card.get("level", 1)), int(card.get("cost", 0))], ThemeBuilder.FIRE))
	info.add_child(chips)
	var owner := ContentLoader.unit_def(str(card.get("unitId", "")))
	info.add_child(ThemeBuilder.dim_label("所属式神：%s" % owner.get("name", "?"), 13))
	info.add_child(ThemeBuilder.hline())
	info.add_child(_wrapped(str(card.get("text", "")), 16, ThemeBuilder.PAPER, 300))
	if card.get("formAbility"):
		info.add_child(_wrapped("形态能力：%s" % card.formAbility, 14, ThemeBuilder.GOLD_BRIGHT, 300))
	var keywords = card.get("keywords", [])
	if keywords is Array:
		for k in keywords:
			if KeywordGlossary.label(str(k)) != "":
				info.add_child(_wrapped("【%s】%s" % [KeywordGlossary.label(str(k)), KeywordGlossary.detail(str(k))], 13, ThemeBuilder.TEXT_DIM, 300))
	if card.get("officialText"):
		info.add_child(_wrapped("原文：%s" % card.officialText, 12, ThemeBuilder.TEXT_FAINT, 300))
	if extra != null: info.add_child(extra)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	var close := ThemeBuilder.ghost(Button.new())
	close.text = "关闭检视 · Esc"
	info.add_child(close)
	var layer := show_modal(host, panel)
	close.pressed.connect(layer.close)
	return layer
