class_name ThemeBuilder
extends RefCounted
## 视觉系统对齐浏览器版 styles.css / formation.css
## 墨夜和风（战局） + 宣纸画册（编成/图鉴/秘闻阁）

const ContentLoader := preload("res://scripts/content_loader.gd")

# —— 墨色阶（战局） ——
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

# —— 宣纸（编成/图鉴） ——
const WASHI_BG := Color("f1ead8")
const WASHI_CARD := Color("fdfaf1")
const WASHI_CARD_2 := Color("f4eedd")
const WASHI_INK := Color("3c3524")
const WASHI_INK_DEEP := Color("33291a")
const WASHI_DIM := Color("6b6250")
const WASHI_FAINT := Color("8d8264")
const WASHI_RULE := Color("cfc3a4")
const WASHI_RULE_2 := Color("c5b896")
const WASHI_GOLD := Color("8a6f34")
const WASHI_GOLD_2 := Color("a8863c")
const WASHI_MICRO := Color("8a6f34")


static func sys_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif",
	])
	return f


static func display_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Songti SC", "STSong", "Noto Serif SC", "SimSun", "PingFang SC", "serif",
	])
	return f


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


static func washi_panel(radius: int = 12, selected: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WASHI_CARD
	sb.border_color = WASHI_GOLD_2 if selected else WASHI_RULE
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.35, 0.3, 0.18, 0.12)
	sb.shadow_size = 8
	return sb


static func button_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb := panel(bg, border, radius, 1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func build_theme() -> Theme:
	return build_night_theme()


static func build_night_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = sys_font()
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


static func build_washi_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = sys_font()
	theme.default_font_size = 15
	var normal := button_style(Color("fffcf2"), WASHI_RULE_2, 10)
	normal.border_width_bottom = 1
	var hover := button_style(Color("f8f1de"), WASHI_GOLD_2, 10)
	var pressed := button_style(Color("efe6cc"), WASHI_GOLD, 10)
	var disabled := button_style(Color("ebe4d2"), WASHI_RULE, 10)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_color("font_color", "Button", WASHI_DIM)
	theme.set_color("font_hover_color", "Button", WASHI_INK_DEEP)
	theme.set_color("font_pressed_color", "Button", WASHI_GOLD)
	theme.set_color("font_disabled_color", "Button", WASHI_FAINT)
	theme.set_color("font_color", "Label", WASHI_INK)
	theme.set_color("font_color", "RichTextLabel", WASHI_INK)
	theme.set_stylebox("panel", "PanelContainer", washi_panel(12, false))
	theme.set_stylebox("panel", "Panel", washi_panel(12, false))
	var le := button_style(Color("fffcf2"), WASHI_RULE_2, 8)
	theme.set_stylebox("normal", "LineEdit", le)
	theme.set_color("font_color", "LineEdit", WASHI_INK)
	theme.set_color("default_color", "RichTextLabel", WASHI_INK)
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
	l.add_theme_font_override("font", display_font())
	return l


static func washi_title(text: String, size: int = 34) -> Label:
	var l := label(text, size, WASHI_INK_DEEP)
	l.add_theme_font_override("font", display_font())
	l.add_theme_constant_override("letter_spacing", 6)
	return l


static func dim_label(text: String, size: int = 13) -> Label:
	return label(text, size, TEXT_DIM)


static func washi_dim(text: String, size: int = 13) -> Label:
	return label(text, size, WASHI_DIM)


static func micro_label(text: String) -> Label:
	var l := label(text, 11, WASHI_GOLD)
	l.add_theme_font_override("font", display_font())
	return l


static func hline() -> Control:
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
	pc.add_child(label(text, 12, color))
	return pc


static func washi_chip(text: String, color: Color = WASHI_GOLD) -> PanelContainer:
	return chip(text, color, 0.12)


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
