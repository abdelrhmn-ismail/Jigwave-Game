class_name CoinIcon
extends Control
## A small gold coin drawn with circles (no image needed).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	draw_circle(c + Vector2(0, r * 0.08), r, UIKit.GOLD.darkened(0.35))
	draw_circle(c, r, UIKit.GOLD)
	draw_arc(c, r * 0.68, 0, TAU, 32, UIKit.GOLD.darkened(0.2), maxf(2.0, r * 0.12), true)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.6))
