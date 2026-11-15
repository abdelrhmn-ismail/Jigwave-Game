class_name UIKit
extends RefCounted
## Colors and small helpers to build labels, buttons and panels from code.
## The whole look lives here: change a color once, it changes everywhere.

const BG_TOP := Color("#132033")
const BG_BOTTOM := Color("#1f4150")
const PANEL := Color("#1b2c40")
const PANEL_EDGE := Color("#35577a")
const BOARD := Color("#0e1826")
const TEXT := Color("#fff6ec")
const TEXT_DIM := Color("#a9bccd")
const ACCENT := Color("#ff8c5a") # coral: main buttons
const MINT := Color("#4fd1b5") # success, snap sparkle
const GOLD := Color("#ffc845") # coins, stars
const BUTTON := Color("#2d4a68")
const OUTLINE := Color("#0a1220")
const WRONG := Color("#ff5d6c")

static var _last_action_ms := -100000


## Ignores a second press within a few ms (some setups deliver one twice).
static func accept_action(min_gap_ms: int = 250) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_action_ms < min_gap_ms:
		return false
	_last_action_ms = now
	return true


static func label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, font_size / 20))
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l


static func panel_style(color: Color, radius: int, padding: int = 0, border: int = 0, edge: Color = PANEL_EDGE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(padding)
	s.set_border_width_all(border)
	s.border_color = edge
	s.anti_aliasing = true
	return s


## Rounded button with a darker "3D" bottom edge.
static func button(text: String, min_size: Vector2, font_size: int, color: Color = BUTTON) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, TEXT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	var radius := int(min_size.y * 0.32)
	var normal := panel_style(color, radius, 18)
	normal.border_width_bottom = 8
	normal.border_color = color.darkened(0.35)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	pressed.border_width_bottom = 3
	pressed.content_margin_top = 23
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.06)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = color.darkened(0.45)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("click"))
	return b


## Coins counter: a gold coin + the number in a rounded pill.
static func coin_pill(font_size: int = 46) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := CoinIcon.new()
	coin.custom_minimum_size = Vector2(font_size, font_size)
	box.add_child(coin)
	var l := label(str(SaveData.coins), font_size, GOLD)
	l.name = "Amount"
	box.add_child(l)
	return box


## Top/bottom space taken by notches and system bars, in game units.
static func safe_insets(viewport: Viewport) -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if screen.y <= 0.0 or safe.size.y <= 0:
		return Vector2.ZERO
	var scale := viewport.get_visible_rect().size.y / screen.y
	var top := safe.position.y * scale
	var bottom := (screen.y - (safe.position.y + safe.size.y)) * scale
	return Vector2(maxf(top, 0.0), maxf(bottom, 0.0))
