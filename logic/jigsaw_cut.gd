class_name JigsawCut
extends RefCounted
## Cuts a square picture into an N×N grid of classic jigsaw pieces.
## Pure geometry – no drawing here.
##
## Every inner edge gets a tab that bulges to one side (chosen by the
## seed); the neighbouring piece gets the matching blank, because both
## pieces use the very same edge curve. Outer edges are straight.
##
## Coordinates are in picture pixels: piece (col, row) covers the cell
## Rect2(col * cell, row * cell, cell, cell), and its tabs reach up to
## TAB_REACH * cell outside that cell.

## Tab size (fraction of a cell). The tab reaches 3 × TAB of the cell.
const TAB := 0.1
const TAB_REACH := 3.0 * TAB + 0.05
## Points per Bezier segment (3 segments per tabbed edge).
const SEGMENT_POINTS := 8

var cols := 3
var rows := 3
var cell := 100.0
## h_edges[r][c]: edge on top of row r (r = 0..rows), column c. Each is a
## PackedVector2Array from left to right.
var h_edges: Array = []
## v_edges[r][c]: edge on the left of column c (c = 0..cols), row r.
## Each runs from top to bottom.
var v_edges: Array = []


## picture_size: width (= height) of the picture in pixels.
func _init(grid: int = 3, picture_size: float = 300.0, seed_value: int = 1) -> void:
	cols = grid
	rows = grid
	cell = picture_size / grid
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	h_edges.clear()
	for r in rows + 1:
		var line := []
		for c in cols:
			var a := Vector2(c * cell, r * cell)
			var b := Vector2((c + 1) * cell, r * cell)
			var inner := r > 0 and r < rows
			line.append(_edge(a, b, Vector2(0, 1), rng) if inner else PackedVector2Array([a, b]))
		h_edges.append(line)
	v_edges.clear()
	for r in rows:
		var line := []
		for c in cols + 1:
			var a := Vector2(c * cell, r * cell)
			var b := Vector2(c * cell, (r + 1) * cell)
			var inner := c > 0 and c < cols
			line.append(_edge(a, b, Vector2(1, 0), rng) if inner else PackedVector2Array([a, b]))
		v_edges.append(line)


func piece_count() -> int:
	return cols * rows


## Piece index → (col, row).
func piece_cell(index: int) -> Vector2i:
	return Vector2i(index % cols, index / cols)


## Top-left corner of the piece's cell, in picture pixels.
func piece_origin(index: int) -> Vector2:
	var p := piece_cell(index)
	return Vector2(p.x * cell, p.y * cell)


func is_edge_piece(index: int) -> bool:
	var p := piece_cell(index)
	return p.x == 0 or p.y == 0 or p.x == cols - 1 or p.y == rows - 1


## Closed outline of a piece in picture pixels (clockwise: top, right,
## bottom, left). The last point is not repeated.
func outline(index: int) -> PackedVector2Array:
	var p := piece_cell(index)
	var pts := PackedVector2Array()
	_append(pts, h_edges[p.y][p.x], false) # top, left → right
	_append(pts, v_edges[p.y][p.x + 1], false) # right, top → bottom
	_append(pts, h_edges[p.y + 1][p.x], true) # bottom, right → left
	_append(pts, v_edges[p.y][p.x], true) # left, bottom → top
	return pts


## Same outline relative to the piece's cell corner (for drawing).
func local_outline(index: int) -> PackedVector2Array:
	var origin := piece_origin(index)
	var pts := outline(index)
	for i in pts.size():
		pts[i] -= origin
	return pts


# --- helpers -----------------------------------------------------------------

## Adds an edge without its last point (the next edge starts there).
static func _append(out: PackedVector2Array, edge: PackedVector2Array, reverse: bool) -> void:
	var n := edge.size()
	for i in n - 1:
		out.append(edge[n - 1 - i] if reverse else edge[i])


## One tabbed edge from a to b. `side` is the direction a positive bulge
## goes; the seed picks the sign and a little jitter so pieces differ.
func _edge(a: Vector2, b: Vector2, side: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var flip := 1.0 if rng.randf() < 0.5 else -1.0
	var jb := rng.randf_range(-0.05, 0.05) # tab position along the edge
	var jc := rng.randf_range(-0.03, 0.03) # tab height
	var jd := rng.randf_range(-0.03, 0.03) # neck width
	var t := TAB
	var along := b - a
	# Control points as (fraction along the edge, bulge in cells).
	var ctrl := [
		Vector2(0.0, 0.0),
		Vector2(0.2, 0.0), Vector2(0.5 + jb + jd, -t + jc), Vector2(0.5 - t + jb, t + jc),
		Vector2(0.5 - 2.0 * t + jb - jd, 3.0 * t + jc), Vector2(0.5 + 2.0 * t + jb - jd, 3.0 * t + jc), Vector2(0.5 + t + jb, t + jc),
		Vector2(0.5 + jb + jd, -t + jc), Vector2(0.8, 0.0), Vector2(1.0, 0.0),
	]
	var world := []
	for c in ctrl:
		world.append(a + along * c.x + side * (c.y * flip * cell))
	var pts := PackedVector2Array([world[0]])
	for s in 3:
		var p0: Vector2 = world[s * 3]
		var p1: Vector2 = world[s * 3 + 1]
		var p2: Vector2 = world[s * 3 + 2]
		var p3: Vector2 = world[s * 3 + 3]
		for i in range(1, SEGMENT_POINTS + 1):
			pts.append(p0.bezier_interpolate(p1, p2, p3, float(i) / SEGMENT_POINTS))
	return pts
