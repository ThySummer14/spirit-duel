class_name ThemeBuilder
extends RefCounted

const ContentLoader := preload("res://scripts/content_loader.gd")
## 墨夜和风 palette from styles.css / formation.css

const INK_0 := Color("06080d")
const INK_1 := Color("0a0e17")
const INK_2 := Color("10151f")
const INK_3 := Color("161d2c")
const INK_4 := Color("1e2739")
const RULE := Color("2a3145")
const RULE_SOFT := Color("212839")
const RULE_STRONG := Color("3b445e")
const PAPER := Color("ece6d6")
const PAPER_DIM := Color("b6b1a2")
const TEXT := Color("e9e4d4")
const TEXT_DIM := Color("9aa1b6")
const TEXT_FAINT := Color("6b7290")
const GOLD := Color("c9a45e")
const GOLD_BRIGHT := Color("eed49c")
const GOLD_DEEP := Color("7d6232")
const DANGER := Color("d95b3a")
const DANGER_SOFT := Color("ef9370")
const OK := Color("7fc48d")
const INFO := Color("6fb0d6")
const WARN := Color("e2bd5e")
const ALLY := Color("c9a45e")
const FOE := Color("a86cc8")

const TYPE_COMBAT := Color("dd6a48")
const TYPE_SPELL := Color("64aed8")
const TYPE_FORM := Color("c9a45e")
const TYPE_REALM := Color("9d82d4")
const TYPE_AWAKEN := Color("e8c76a")

const RARITY_COMMON := Color("8b93b8")
const RARITY_RARE := Color("5fa8d6")
const RARITY_EPIC := Color("c98fe8")
const RARITY_SSR := Color("f0c869")


static func panel(bg: Color, border: Color = RULE, radius: int = 10, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func button_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb := panel(bg, border, radius, 1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var normal := button_style(INK_3, RULE, 8)
	var hover := button_style(INK_4, GOLD, 8)
	var pressed := button_style(Color("2c2413"), GOLD_DEEP, 8)
	var disabled := button_style(INK_2, RULE_SOFT, 8)
	var focus := button_style(INK_3, GOLD_BRIGHT, 8)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	theme.set_color("font_pressed_color", "Button", GOLD_BRIGHT)
	theme.set_color("font_disabled_color", "Button", TEXT_FAINT)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "RichTextLabel", TEXT)
	theme.set_stylebox("panel", "PanelContainer", panel(INK_2, RULE, 10, 1))
	theme.set_stylebox("panel", "Panel", panel(INK_2, RULE, 10, 1))
	theme.set_stylebox("normal", "LineEdit", panel(INK_3, RULE, 6, 1))
	theme.set_color("default_color", "RichTextLabel", TEXT)
	return theme


static func label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title_label(text: String, size: int = 28) -> Label:
	var l := label(text, size, GOLD_BRIGHT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func dim_label(text: String, size: int = 13) -> Label:
	return label(text, size, TEXT_DIM)


static func hline() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 1)
	var sb := StyleBoxFlat.new()
	sb.bg_color = RULE
	c.draw.connect(func(): pass)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 1)
	var s := StyleBoxFlat.new()
	s.bg_color = RULE
	p.add_theme_stylebox_override("panel", s)
	return p


static func chip(text: String, color: Color, bg_alpha: float = 0.18) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, bg_alpha)
	sb.border_color = Color(color.r, color.g, color.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	var l := label(text, 12, color)
	pc.add_child(l)
	return pc


static func rounded_rect_button(text: String, min_size: Vector2 = Vector2(220, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	return b


static func rarity_color_of(rarity: String) -> Color:
	return ContentLoader.rarity_color(rarity)


static func type_color_of(card_type: String) -> Color:
	return ContentLoader.type_color(card_type)


static func unit_color_of(unit: Dictionary) -> Color:
	return ContentLoader.unit_color(unit)
