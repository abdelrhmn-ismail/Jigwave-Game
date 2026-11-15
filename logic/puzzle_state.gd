class_name PuzzleState
extends RefCounted
## One puzzle in progress: which pieces are placed, what is left in the
## tray, mistakes. The screen calls try_drop() and draws what is here.

var picture_id := ""
var grid := 3
## Seed for the piece shapes, so a resumed puzzle has the same cuts.
var cut_seed := 1
## Level number, or 0 for a free-play puzzle from the gallery.
var level := 0
var placed: Array[bool] = []
## Pieces still waiting, in tray order.
var tray: Array[int] = []
var mistakes := 0
var hints_used := 0


func setup(new_picture_id: String, new_grid: int, new_level: int, seed_value: int) -> void:
	picture_id = new_picture_id
	grid = clampi(new_grid, 2, 12)
	level = new_level
	cut_seed = seed_value
	mistakes = 0
	hints_used = 0
	placed.clear()
	placed.resize(piece_count())
	placed.fill(false)
	tray.clear()
	for i in piece_count():
		tray.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	for i in range(tray.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := tray[i]
		tray[i] = tray[j]
		tray[j] = tmp


func piece_count() -> int:
	return grid * grid


func placed_count() -> int:
	return placed.count(true)


func is_complete() -> bool:
	return placed_count() == piece_count()


## The player dropped `piece` on board cell `cell_index` (-1 = not on
## the board). Right cell → placed, returns true. Wrong cell → one more
## mistake, the piece stays in the tray. Off the board → nothing happens.
func try_drop(piece: int, cell_index: int) -> bool:
	if not tray.has(piece):
		return false
	if cell_index < 0:
		return false
	if cell_index == piece:
		_place(piece)
		return true
	mistakes += 1
	return false


## Hint: places a piece for the player (no mistake counted).
func place_by_hint(piece: int) -> bool:
	if not tray.has(piece):
		return false
	hints_used += 1
	_place(piece)
	return true


## Moves border pieces to the front of the tray (keeps their order).
func sort_edges_first() -> void:
	var edges: Array[int] = []
	var inner: Array[int] = []
	for p in tray:
		if is_edge_piece(p):
			edges.append(p)
		else:
			inner.append(p)
	tray = edges + inner


func is_edge_piece(piece: int) -> bool:
	var c := piece % grid
	var r := piece / grid
	return c == 0 or r == 0 or c == grid - 1 or r == grid - 1


func stars() -> int:
	return Economy.stars(mistakes, piece_count())


func to_dict() -> Dictionary:
	return {
		"picture_id": picture_id,
		"grid": grid,
		"cut_seed": cut_seed,
		"level": level,
		"placed": Array(placed.duplicate()),
		"tray": Array(tray.duplicate()),
		"mistakes": mistakes,
		"hints_used": hints_used,
	}


## Restores a snapshot from to_dict(). Returns false (and leaves this
## state unusable) if the data is broken.
func from_dict(data: Dictionary) -> bool:
	var g := int(data.get("grid", 0))
	var p = data.get("placed")
	var t = data.get("tray")
	if g < 2 or g > 12 or typeof(p) != TYPE_ARRAY or typeof(t) != TYPE_ARRAY:
		return false
	if p.size() != g * g or str(data.get("picture_id", "")) == "":
		return false
	var new_placed: Array[bool] = []
	for v in p:
		new_placed.append(bool(v))
	var new_tray: Array[int] = []
	for v in t:
		var i := int(v)
		if i < 0 or i >= g * g or new_placed[i] or new_tray.has(i):
			return false
		new_tray.append(i)
	# Every piece must be either placed or in the tray.
	if new_tray.size() + new_placed.count(true) != g * g:
		return false
	picture_id = str(data["picture_id"])
	grid = g
	cut_seed = int(data.get("cut_seed", 1))
	level = maxi(0, int(data.get("level", 0)))
	placed = new_placed
	tray = new_tray
	mistakes = maxi(0, int(data.get("mistakes", 0)))
	hints_used = maxi(0, int(data.get("hints_used", 0)))
	return true


func _place(piece: int) -> void:
	placed[piece] = true
	tray.erase(piece)
