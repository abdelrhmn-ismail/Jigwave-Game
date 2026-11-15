class_name OverlayPanel
extends Control
## Base for pop-up windows: dims the screen and shows a centered panel.
## Add rows with add_*().

var box: VBoxContainer
var panel: PanelContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.PANEL, 48, 56, 4))
	center.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	panel.add_child(box)


func _ready() -> void:
	modulate.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func add_text(text: String, font_size: int, color: Color = UIKit.TEXT) -> Label:
	var l := UIKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 660
	box.add_child(l)
	return l


func add_button(text: String, on_press: Callable, color: Color = UIKit.BUTTON) -> Button:
	var b := UIKit.button(text, Vector2(660, 136), 50, color)
	b.pressed.connect(on_press)
	box.add_child(b)
	return b


func close() -> void:
	queue_free()
