class_name StarRow
extends Control
## Three stars; the first `count` are gold. `shown` animates them in.

var count := 0
var shown := 3.0:
	set(v):
		shown = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := minf(size.y * 0.5, size.x / 7.0)
	for i in 3:
		var c := Vector2(size.x * 0.5 + (i - 1) * r * 2.3, size.y * 0.5 - (r * 0.25 if i == 1 else 0.0))
		var grow := clampf(shown - i, 0.0, 1.0)
		var lit := i < count and grow > 0.0
		var rr := r * (0.85 + 0.15 * grow) if lit else r * 0.85
		_star(c + Vector2(0, rr * 0.08), rr, UIKit.SHADOW)
		_star(c, rr, UIKit.GOLD if lit else Color(UIKit.TEXT_DIM, 0.3))


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)
