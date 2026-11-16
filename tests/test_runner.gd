extends SceneTree
## Tests for the game rules (no graphics needed). Run from the project folder:
##   godot --headless --path . -s tests/test_runner.gd

var passed := 0
var failed := 0


func _init() -> void:
	test_cut_outlines_are_closed_and_sized()
	test_cut_neighbours_share_edges()
	test_cut_pieces_fill_the_picture()
	test_cut_is_repeatable()
	test_state_right_and_wrong_drops()
	test_state_hint_and_edges()
	test_state_save_and_restore()
	test_state_rejects_broken_saves()
	test_stars_and_rewards()
	test_levels()
	test_catalog()
	test_art_and_sounds_exist()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + message)


# --- jigsaw cut ----------------------------------------------------------------

func test_cut_outlines_are_closed_and_sized() -> void:
	for grid in [2, 3, 5, 8, 10]:
		var cut := JigsawCut.new(grid, 1000.0, 7)
		check(cut.piece_count() == grid * grid, "%dx%d has %d pieces" % [grid, grid, grid * grid])
		var ok := true
		for i in cut.piece_count():
			var pts := cut.outline(i)
			var origin := cut.piece_origin(i)
			var reach := cut.cell * JigsawCut.TAB_REACH
			var box := Rect2(origin - Vector2(reach, reach), Vector2.ONE * (cut.cell + reach * 2.0))
			for p in pts:
				if not box.has_point(p):
					ok = false
			# Corners of the cell are on the outline.
			for corner in [origin, origin + Vector2(cut.cell, 0), origin + Vector2(cut.cell, cut.cell), origin + Vector2(0, cut.cell)]:
				if not _has_point_near(pts, corner):
					ok = false
		check(ok, "grid %d: outlines stay near their cell and pass its corners" % grid)


func test_cut_neighbours_share_edges() -> void:
	var cut := JigsawCut.new(4, 400.0, 3)
	# Piece 5 (col 1, row 1): its right edge is piece 6's left edge.
	var right_of_5: PackedVector2Array = cut.v_edges[1][2]
	var a := cut.outline(5)
	var b := cut.outline(6)
	var shared := true
	for p in right_of_5:
		if not _has_point_near(a, p) or not _has_point_near(b, p):
			shared = false
	check(shared, "neighbours use the same edge curve (tab fits blank)")
	# Inner edges really have a tab (they leave the straight line).
	var bulge := 0.0
	for p in right_of_5:
		bulge = maxf(bulge, absf(p.x - 200.0))
	check(bulge > cut.cell * 0.2, "inner edge has a tab (bulge %.1f)" % bulge)
	var outer: PackedVector2Array = cut.v_edges[1][0]
	check(outer.size() == 2, "outer edge is straight")


## Tabs and blanks cancel out: all pieces together cover the picture.
func test_cut_pieces_fill_the_picture() -> void:
	var cut := JigsawCut.new(5, 500.0, 11)
	var total := 0.0
	var all_positive := true
	for i in cut.piece_count():
		var area := _area(cut.outline(i))
		if area <= 0.0:
			all_positive = false
		total += area
	check(all_positive, "every outline is clockwise with positive area")
	check(absf(total - 500.0 * 500.0) < 1.0, "pieces cover the picture exactly (%.1f)" % total)


func test_cut_is_repeatable() -> void:
	var a := JigsawCut.new(6, 600.0, 42)
	var b := JigsawCut.new(6, 600.0, 42)
	var c := JigsawCut.new(6, 600.0, 43)
	check(a.outline(14) == b.outline(14), "same seed, same pieces (for resume)")
	check(a.outline(14) != c.outline(14), "other seed, other pieces")


# --- puzzle state --------------------------------------------------------------

func test_state_right_and_wrong_drops() -> void:
	var s := PuzzleState.new()
	s.setup("nature_002", 3, 1, 5)
	check(s.tray.size() == 9 and s.placed_count() == 0, "new puzzle: all 9 in the tray")
	var sorted := s.tray.duplicate()
	sorted.sort()
	check(sorted == [0, 1, 2, 3, 4, 5, 6, 7, 8], "tray holds every piece once")
	check(not s.try_drop(4, 3), "wrong cell is refused")
	check(s.mistakes == 1 and s.tray.has(4), "wrong drop: 1 mistake, piece back in tray")
	check(not s.try_drop(4, -1) and s.mistakes == 1, "drop off the board: no mistake")
	check(s.try_drop(4, 4), "right cell is accepted")
	check(s.placed[4] and not s.tray.has(4), "placed piece leaves the tray")
	check(not s.try_drop(4, 4), "a placed piece cannot be dropped again")
	for p in s.tray.duplicate():
		s.try_drop(p, p)
	check(s.is_complete(), "all pieces placed: complete")


func test_state_hint_and_edges() -> void:
	var s := PuzzleState.new()
	s.setup("x", 4, 0, 9)
	s.sort_edges_first()
	var seen_inner := false
	var order_ok := true
	for p in s.tray:
		if not s.is_edge_piece(p):
			seen_inner = true
		elif seen_inner:
			order_ok = false
	check(order_ok, "edges first: all border pieces come before inner ones")
	check(s.tray.size() == 16, "sorting keeps every piece")
	var first := s.tray[0]
	check(s.place_by_hint(first) and s.placed[first], "hint places a piece")
	check(s.hints_used == 1 and s.mistakes == 0, "hint counted, no mistake")


func test_state_save_and_restore() -> void:
	var s := PuzzleState.new()
	s.setup("animals_002", 4, 7, 123)
	s.try_drop(s.tray[0], s.tray[0])
	s.try_drop(s.tray[0], 99 if s.tray[0] != 99 else 98)
	var t := PuzzleState.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))), "save survives JSON")
	check(t.picture_id == s.picture_id and t.grid == 4 and t.level == 7 and t.cut_seed == 123, "ids restored")
	check(t.placed == s.placed and t.tray == s.tray, "pieces restored")
	check(t.mistakes == s.mistakes, "mistakes restored")


func test_state_rejects_broken_saves() -> void:
	var s := PuzzleState.new()
	s.setup("food_001", 3, 2, 1)
	var good := s.to_dict()
	var cases := {
		"tiny grid": {"grid": 1},
		"wrong placed size": {"placed": [true]},
		"piece twice": {"tray": [0, 0, 1, 2, 3, 4, 5, 6, 7]},
		"piece missing": {"tray": [0, 1, 2]},
		"piece out of range": {"tray": [0, 1, 2, 3, 4, 5, 6, 7, 42]},
		"no picture": {"picture_id": ""},
	}
	for name in cases:
		var data := good.duplicate(true)
		data.merge(cases[name], true)
		check(not PuzzleState.new().from_dict(data), "broken save rejected: %s" % name)


func test_stars_and_rewards() -> void:
	check(Economy.stars(0, 9) == 3 and Economy.stars(1, 9) == 3, "9 pieces: 0-1 mistakes = 3 stars")
	check(Economy.stars(3, 9) == 2 and Economy.stars(4, 9) == 1, "9 pieces: 3 = 2 stars, 4 = 1 star")
	check(Economy.stars(7, 64) == 3 and Economy.stars(16, 64) == 2 and Economy.stars(17, 64) == 1, "64 pieces limits")
	check(Economy.reward(9, 3) == 27, "9 pieces, 3 stars = 10 + 15 + 2")
	check(Economy.reward(64, 1) == 31, "64 pieces, 1 star = 10 + 5 + 16")


func test_levels() -> void:
	check(Levels.grid_for_level(1) == 3 and Levels.grid_for_level(5) == 3, "levels 1-5: 3x3")
	check(Levels.grid_for_level(6) == 4 and Levels.grid_for_level(35) == 5, "levels grow to 4x4, 5x5")
	check(Levels.grid_for_level(121) == 8 and Levels.grid_for_level(5000) == 10, "late levels cap at 10x10")
	var prev := 0
	var grows := true
	for l in range(1, 600):
		var g := Levels.grid_for_level(l)
		if g < prev:
			grows = false
		prev = g
	check(grows, "piece count never goes down")
	check(Levels.picture_index(1, 30) == 0 and Levels.picture_index(31, 30) == 0, "pictures repeat after the list")
	check(Levels.unlocked_count(1, 30) == 1 and Levels.unlocked_count(10, 30) == 9 and Levels.unlocked_count(99, 30) == 30, "unlocked pictures")


func test_catalog() -> void:
	check(Catalog.count() >= 20, "catalog has pictures (%d)" % Catalog.count())
	var order := Catalog.play_order()
	check(order.size() == Catalog.count(), "play order uses every picture once")
	var repeats := 0
	for i in range(1, mini(order.size(), 15)):
		if order[i]["category"] == order[i - 1]["category"]:
			repeats += 1
	check(repeats == 0, "first levels alternate categories")
	for it in Catalog.items():
		if not ["cc0", "pdm"].has(it.get("license", "")):
			check(false, "picture %s has a free license" % it["id"])
		if str(it.get("landing_url", "")) == "":
			check(false, "picture %s has a credit link" % it["id"])
	check(ResourceLoader.exists(Catalog.picture_for_level(1)["file"]), "level 1 picture exists")


## Every sound the code plays, the music tracks and the logo/icons exist
## (all made by tools/make_audio.py and tools/make_art.py).
func test_art_and_sounds_exist() -> void:
	for name in ["pick", "snap", "wrong", "click", "star", "coin", "peek", "magic", "win",
			"music_home", "music_puzzle_1", "music_puzzle_2", "music_puzzle_3"]:
		check(ResourceLoader.exists("res://assets/sounds/%s.wav" % name), "sound %s exists" % name)
	for path in ["res://icon.png", "res://assets/images/logo.png", "res://assets/images/store_icon.png",
			"res://assets/images/icon_foreground.png", "res://assets/images/icon_background.png"]:
		check(ResourceLoader.exists(path), "%s exists" % path)


# --- helpers -------------------------------------------------------------------

func _has_point_near(pts: PackedVector2Array, target: Vector2) -> bool:
	for p in pts:
		if p.distance_to(target) < 0.01:
			return true
	return false


## Shoelace area; positive for clockwise outlines in y-down coordinates.
func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
