class_name ThemeBuilder
extends RefCounted
## 视觉系统：墨夜和风。深靛墨底、暖纸文字、金与朱点缀。
## 字体随包内置（Noto Sans SC / Noto Serif SC，OFL），不依赖系统字体回退。

const ContentLoader := preload("res://scripts/content_loader.gd")

# —— 墨色阶 ——
const INK_0 := Color("070910")
const INK_1 := Color("0c1019")
const INK_2 := Color("121826")
const INK_3 := Color("1a2234")
const INK_4 := Color("243047")
const RULE := Color("2e3850")
const RULE_SOFT := Color("232b3f")
const RULE_STRONG := Color("4a5574")
const PAPER := Color("f1ead8")
const PAPER_DIM := Color("bdb6a4")
const TEXT := Color("ece6d6")
const TEXT_DIM := Color("a3aac0")
const TEXT_FAINT := Color("6f7794")
const GOLD := Color("d2ad62")
const GOLD_BRIGHT := Color("f3d99e")
const GOLD_DEEP := Color("7d6232")
const DANGER := Color("dc5a3c")
const DANGER_SOFT := Color("f29a7a")
const OK := Color("86d39a")
const INFO := Color("7cc0e8")
const WARN := Color("ecc463")
const ALLY := Color("d9b56a")
const FOE := Color("c0607a")
const FIRE := Color("7fd6ff")
const VERMILION := Color("c7432c")

const TYPE_COMBAT := Color("dd6a48")
const TYPE_SPELL := Color("64aed8")
const TYPE_FORM := Color("d2ad62")
const TYPE_REALM := Color("9d82d4")
const TYPE_AWAKEN := Color("e8c76a")

const RARITY_COMMON := Color("9aa3c4")
const RARITY_RARE := Color("5fb0e6")
const RARITY_EPIC := Color("c98fe8")
const RARITY_SSR := Color("f0c869")

# —— 宣纸（卡面正文） ——
const WASHI_BG := Color("f1ead8")
const WASHI_CARD := Color("fdfaf1")
const WASHI_CARD_2 := Color("f4eedd")
const WASHI_INK := Color("3c3524")
const WASHI_INK_DEEP := Color("2b2216")
const WASHI_DIM := Color("6b6250")
const WASHI_FAINT := Color("8d8264")
const WASHI_RULE := Color("cfc3a4")
const WASHI_RULE_2 := Color("c5b896")
const WASHI_GOLD := Color("8a6f34")
const WASHI_GOLD_2 := Color("a8863c")
const WASHI_MICRO := Color("8a6f34")

const SANS_PATH := "res://assets/fonts/NotoSansSC.ttf"
const SERIF_PATH := "res://assets/fonts/NotoSerifSC.ttf"

static var _fonts: Dictionary = {}


static func _fallback() -> SystemFont:
	if _fonts.has("fallback"): return _fonts.fallback
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Hiragino Sans GB", "Songti SC", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	_fonts.fallback = f
	return f


static func _variant(path: String, weight: int, key: String) -> Font:
	if _fonts.has(key): return _fonts[key]
	var base: Font = load(path) if ResourceLoader.exists(path) else null
	if base == null:
		_fonts[key] = _fallback()
		return _fonts[key]
	if base is FontFile:
		(base as FontFile).fallbacks = [_fallback()]
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[key] = v
	return v


## 正文字体（Noto Sans SC Regular）
static func sys_font() -> Font:
	return _variant(SANS_PATH, 420, "sans")


static func medium_font() -> Font:
	return _variant(SANS_PATH, 560, "sans-medium")


static func bold_font() -> Font:
	return _variant(SANS_PATH, 720, "sans-bold")


## 标题 / 卡名字体（Noto Serif SC Bold）
static func display_font() -> Font:
	return _variant(SERIF_PATH, 760, "serif")


static func heavy_display_font() -> Font:
	return _variant(SERIF_PATH, 900, "serif-heavy")


static func panel(bg: Color, border: Color = RULE, radius: int = 10, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb


## 半透明墨色浮层面板：用于覆盖在场景插画上的 HUD
static func glass(alpha: float = 0.78, border: Color = Color(0.82, 0.68, 0.4, 0.35), radius: int = 12) -> StyleBoxFlat:
	var sb := panel(Color(0.045, 0.06, 0.1, alpha), border, radius, 1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
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
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb


static func _btn(bg: Color, border: Color, glow: float = 0.0, bottom: int = 2, radius: int = 8) -> StyleBoxFlat:
	var sb := button_style(bg, border, radius)
	sb.border_width_bottom = bottom
	if glow > 0.0:
		sb.shadow_color = Color(border.r, border.g, border.b, glow)
		sb.shadow_size = 10
	else:
		sb.shadow_color = Color(0, 0, 0, 0.28)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
	return sb


static func build_theme() -> Theme:
	return build_night_theme()


static func build_night_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = sys_font()
	theme.default_font_size = 15
	# Button：墨底金边，悬停发光
	theme.set_stylebox("normal", "Button", _btn(Color(0.09, 0.11, 0.17, 0.92), Color(0.82, 0.68, 0.4, 0.45)))
	theme.set_stylebox("hover", "Button", _btn(Color(0.14, 0.15, 0.22, 0.96), GOLD, 0.28))
	theme.set_stylebox("pressed", "Button", _btn(Color(0.06, 0.07, 0.11, 0.98), GOLD_DEEP, 0.0, 1))
	theme.set_stylebox("disabled", "Button", _btn(Color(0.07, 0.08, 0.12, 0.7), Color(0.3, 0.33, 0.42, 0.5), 0.0, 1))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_hover_pressed_color", "Button", GOLD_BRIGHT)
	theme.set_color("font_disabled_color", "Button", TEXT_FAINT)
	theme.set_font("font", "Button", medium_font())
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "RichTextLabel", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font("bold_font", "RichTextLabel", bold_font())
	theme.set_stylebox("panel", "PanelContainer", glass(0.82))
	theme.set_stylebox("panel", "Panel", glass(0.82))
	# 输入框
	var le := panel(Color(0.05, 0.065, 0.1, 0.9), Color(0.82, 0.68, 0.4, 0.3), 8, 1)
	le.content_margin_left = 12
	theme.set_stylebox("normal", "LineEdit", le)
	var le_focus := panel(Color(0.06, 0.08, 0.12, 0.95), GOLD, 8, 1)
	le_focus.content_margin_left = 12
	theme.set_stylebox("focus", "LineEdit", le_focus)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)
	theme.set_color("caret_color", "LineEdit", GOLD_BRIGHT)
	theme.set_color("selection_color", "LineEdit", Color(0.82, 0.68, 0.4, 0.35))
	# 下拉菜单
	for state in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(state, "OptionButton", theme.get_stylebox(state, "Button"))
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", GOLD_BRIGHT)
	var popup := panel(Color("0e1320"), Color(0.82, 0.68, 0.4, 0.45), 8, 1)
	popup.shadow_color = Color(0, 0, 0, 0.5)
	popup.shadow_size = 14
	theme.set_stylebox("panel", "PopupMenu", popup)
	var popup_hover := panel(Color(0.82, 0.68, 0.4, 0.18), Color.TRANSPARENT, 5, 0)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_font("font", "PopupMenu", sys_font())
	theme.set_stylebox("panel", "PopupPanel", popup)
	theme.set_stylebox("panel", "TooltipPanel", popup)
	theme.set_color("font_color", "TooltipLabel", TEXT)
	# 页签
	var tab_on := panel(Color(0.14, 0.15, 0.22, 0.95), GOLD, 8, 0)
	tab_on.border_width_bottom = 2
	tab_on.content_margin_left = 22
	tab_on.content_margin_right = 22
	var tab_off := panel(Color(0.06, 0.075, 0.11, 0.72), Color.TRANSPARENT, 8, 0)
	tab_off.content_margin_left = 22
	tab_off.content_margin_right = 22
	var tab_hover := tab_off.duplicate()
	tab_hover.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	theme.set_stylebox("tab_selected", "TabContainer", tab_on)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_off)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	theme.set_stylebox("panel", "TabContainer", glass(0.72))
	theme.set_color("font_selected_color", "TabContainer", GOLD_BRIGHT)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	theme.set_color("font_hovered_color", "TabContainer", TEXT)
	theme.set_font("font", "TabContainer", medium_font())
	theme.set_font_size("font_size", "TabContainer", 15)
	# 滚动条：细金线
	for orient in ["HScrollBar", "VScrollBar"]:
		var track := panel(Color(1, 1, 1, 0.04), Color.TRANSPARENT, 4, 0)
		track.set_content_margin_all(0)
		var grab := panel(Color(0.82, 0.68, 0.4, 0.38), Color.TRANSPARENT, 4, 0)
		grab.set_content_margin_all(3)
		var grab_hi := grab.duplicate()
		grab_hi.bg_color = Color(0.95, 0.82, 0.55, 0.7)
		theme.set_stylebox("scroll", orient, track)
		theme.set_stylebox("grabber", orient, grab)
		theme.set_stylebox("grabber_highlight", orient, grab_hi)
		theme.set_stylebox("grabber_pressed", orient, grab_hi)
	# 滑块
	var slider := panel(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 3, 0)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", slider)
	var fill := panel(GOLD, Color.TRANSPARENT, 3, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_stylebox("panel", "AcceptDialog", popup)
	return theme


## 与夜色主题统一；保留旧入口以免外部调用失效。
static func build_washi_theme() -> Theme:
	return build_night_theme()


## 主按钮：金色实底、深墨字，用于每屏唯一的主行动（出战、确认、购买）。
static func primary(b: Button, size: int = 17) -> Button:
	var normal := _btn(Color("d9b46a"), Color("f6e2b0"), 0.0, 3)
	normal.border_color = Color("8a6a2e")
	normal.shadow_color = Color(0.85, 0.65, 0.3, 0.25)
	normal.shadow_size = 10
	var hover := _btn(Color("ecc983"), Color("fff0c8"), 0.55, 3)
	hover.border_color = Color("9a7834")
	hover.shadow_color = Color(1, 0.8, 0.4, 0.5)
	hover.shadow_size = 16
	var pressed := _btn(Color("b8954f"), Color("6e5424"), 0.0, 1)
	var disabled := _btn(Color(0.3, 0.27, 0.22, 0.6), Color(0.4, 0.36, 0.3, 0.6), 0.0, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, Color("2a1d0c"))
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.7, 0.6, 0.6))
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", size)
	return b


## 次级幽灵按钮：透明底、细边，用于工具性操作（返回、战报）。
static func ghost(b: Button, size: int = 14) -> Button:
	var normal := _btn(Color(0.04, 0.05, 0.08, 0.45), Color(1, 1, 1, 0.16), 0.0, 1, 18)
	normal.shadow_size = 0
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = Color(0.1, 0.11, 0.16, 0.75)
	hover.border_color = GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.02, 0.03, 0.05, 0.8)
	var disabled := normal.duplicate()
	disabled.border_color = Color(1, 1, 1, 0.06)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", size)
	return b


static func label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func bold_label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", bold_font())
	return l


static func title_label(text: String, size: int = 28) -> Label:
	var l := label(text, size, GOLD_BRIGHT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", display_font())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


static func washi_title(text: String, size: int = 34) -> Label:
	var l := label(text, size, WASHI_INK_DEEP)
	l.add_theme_font_override("font", display_font())
	return l


static func dim_label(text: String, size: int = 13) -> Label:
	return label(text, size, TEXT_DIM)


static func washi_dim(text: String, size: int = 13) -> Label:
	return label(text, size, WASHI_DIM)


static func micro_label(text: String) -> Label:
	var l := label(text, 11, GOLD)
	l.add_theme_font_override("font", medium_font())
	return l


## 小节标题：「— 标题 —」式金色细字
static func section_label(text: String, size: int = 13) -> Label:
	var l := label(text, size, GOLD)
	l.add_theme_font_override("font", medium_font())
	return l


## 文本外描边，用于直接压在插画上的文字
static func outline(l: Label, width: int = 6, color: Color = Color(0.02, 0.03, 0.06, 0.9)) -> Label:
	l.add_theme_color_override("font_outline_color", color)
	l.add_theme_constant_override("outline_size", width)
	return l


static func hline(color: Color = Color(0.82, 0.68, 0.4, 0.25)) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 1)
	var s := StyleBoxFlat.new()
	s.bg_color = color
	p.add_theme_stylebox_override("panel", s)
	return p


static func chip(text: String, color: Color, bg_alpha: float = 0.18) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, bg_alpha)
	sb.border_color = Color(color.r, color.g, color.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	var l := label(text, 12, color.lightened(0.15))
	l.add_theme_font_override("font", medium_font())
	pc.add_child(l)
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


static func rarity_label(rarity: String) -> String:
	return str({"common": "常见", "rare": "稀有", "epic": "史诗", "ssr": "SSR", "legendary": "SSR"}.get(rarity, rarity))


static func type_color_of(card_type: String) -> Color:
	return ContentLoader.type_color(card_type)


static func unit_color_of(unit: Dictionary) -> Color:
	return ContentLoader.unit_color(unit)
