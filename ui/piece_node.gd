class_name PieceNode
extends Node2D
## One jigsaw piece: a Polygon2D textured with its part of the picture,
## a thin light outline, and a soft shadow while it is being dragged.
## The node's origin is the center of the piece's cell, in picture pixels,
## so scaling (tray → board) happens around the middle of the piece.
## Nothing is redrawn every frame: the GPU just moves the node.

var index := -1
var _outline := PackedVector2Array()
var _shadow: Polygon2D
var lifted := false:
	set(v):
		lifted = v
		if _shadow:
			_shadow.visible = v


func setup(piece_index: int, cut: JigsawCut, texture: Texture2D) -> void:
	index = piece_index
	var center := cut.piece_origin(index) + Vector2.ONE * cut.cell * 0.5
	var world := cut.outline(index)
	var local := PackedVector2Array()
	local.resize(world.size())
	for i in world.size():
		local[i] = world[i] - center
	# UVs are picture pixels, scaled in case the texture size differs.
	var tex_scale := float(texture.get_width()) / (cut.cell * cut.cols)
	var uv := PackedVector2Array()
	uv.resize(world.size())
	for i in world.size():
		uv[i] = world[i] * tex_scale

	_shadow = Polygon2D.new()
	_shadow.polygon = local
	_shadow.color = Color(0, 0, 0, 0.35)
	_shadow.position = Vector2(cut.cell * 0.05, cut.cell * 0.08)
	_shadow.visible = false
	add_child(_shadow)

	var poly := Polygon2D.new()
	poly.texture = texture
	poly.polygon = local
	poly.uv = uv
	poly.antialiased = true
	add_child(poly)

	_outline = local.duplicate()
	_outline.append(local[0])
	queue_redraw()


var _show_outline := true


## Hides the outline once the picture is complete (seamless picture).
func set_outline_visible(v: bool) -> void:
	_show_outline = v
	queue_redraw()


func _draw() -> void:
	if _outline.is_empty() or not _show_outline:
		return
	# Width in screen pixels stays about the same at any scale.
	var w := 2.5 / maxf(absf(global_scale.x), 0.05)
	draw_polyline(_outline, Color(1, 1, 1, 0.55), w, true)
