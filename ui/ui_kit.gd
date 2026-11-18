class_name UIKit
extends RefCounted
## Colors and small helpers to build labels, buttons and panels from code.
## The whole look lives here: change a color once, it changes everywhere.
##
## Jigwave's own identity: a warm, light "puzzle table" — cream paper,
## a linen puzzle mat, white cards with soft shadows, ink-blue text, coral
## and teal accents. (Deliberately the opposite of Bloxo's dark neon.)

const BG_TOP := Color("#fff7ee") # cream paper
const BG_BOTTOM := Color("#fbe1cc") # warm peach
const PATTERN := Color(0.62, 0.42, 0.26, 0.10) # faint pieces on the background
const PANEL := Color("#ffffff")
const PANEL_EDGE := Color("#f0dcc8")
const BOARD := Color("#eadbc8") # linen puzzle mat
const BOARD_EDGE := Color("#ffffff")
const GUIDE := Color(0.45, 0.32, 0.2, 0.22) # cut lines on the empty mat
const TEXT := Color("#2e3a4b") # ink
const TEXT_DIM := Color("#8c7d70")
const ACCENT := Color("#ff7a59") # coral: main buttons
const MINT := Color("#22b5a5") # teal: success, snap sparkle
const GOLD := Color("#f5a623") # coins, stars
const GOLD_TEXT := Color("#c47d00") # readable gold on light backgrounds
const BUTTON := Color("#ffffff") # secondary buttons: white cards
const SHADOW := Color(0.45, 0.28, 0.12, 0.18)
const WRONG := Color("#e8505b")

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
	# Direction from the text itself (Arabic right-to-left, English left-to-
	# right), even on screens whose layout is pinned left-to-right.
	l.text_direction = Control.TEXT_DIRECTION_AUTO
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func panel_style(color: Color, radius: int, padding: int = 0, border: int = 0, edge: Color = PANEL_EDGE, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(padding)
	s.set_border_width_all(border)
	s.border_color = edge
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = SHADOW
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	return s


## Ink text on light buttons, white text on colored ones.
static func text_on(color: Color) -> Color:
	return TEXT if color.get_luminance() > 0.65 else Color.WHITE


## Soft pill button: a card that floats on a warm shadow and sinks a
## little when pressed.
static func button(text: String, min_size: Vector2, font_size: int, color: Color = BUTTON) -> Button:
	var b := Button.new()
	b.text = text
	b.text_direction = Control.TEXT_DIRECTION_AUTO
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var fg := text_on(color)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	var radius := int(min_size.y * 0.5)
	var normal := panel_style(color, radius, 18, 2 if color.get_luminance() > 0.65 else 0, PANEL_EDGE, 10)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.06)
	pressed.shadow_size = 3
	pressed.shadow_offset = Vector2(0, 1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.04)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = color.lerp(BG_BOTTOM, 0.6)
	disabled.shadow_size = 0
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
	var l := label(str(SaveData.coins), font_size, GOLD_TEXT)
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
