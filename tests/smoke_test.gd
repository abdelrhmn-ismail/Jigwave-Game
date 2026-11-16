extends Node
## Plays real puzzles through the touch code (no mouse needed):
## right drags snap, wrong drags count a mistake and return, a tap
## picks nothing, a sideways swipe scrolls the tray, and finishing
## shows the complete panel and pays coins.
##   godot --headless --path . res://tests/smoke_test.tscn

var errors := 0
var _saved := {}


func _ready() -> void:
	_backup_save()
	await _play_small_puzzle()
	await _replay_pays_little()
	await _scroll_big_tray()
	await _peek_and_cancel_drag()
	_parked_level_comes_back()
	_restore_save()
	print("smoke test: %s" % ("OK" if errors == 0 else "%d FAILED" % errors))
	get_tree().quit(1 if errors > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL: " + msg)


func _new_screen(level: int) -> PuzzleScreen:
	var s := PuzzleState.new()
	var pic := Catalog.picture_for_level(level)
	s.setup(pic["id"], Levels.grid_for_level(level), level, Levels.cut_seed(level))
	var screen := PuzzleScreen.new()
	screen.state = s
	add_child(screen)
	return screen


func _play_small_puzzle() -> void:
	SaveData.coins = 100
	SaveData.level = 1
	var screen := _new_screen(1)
	await get_tree().process_frame
	var st := screen.state
	_check(st.tray.size() == 9, "level 1 has 9 pieces in the tray")

	# A tap without moving picks nothing.
	_touch(screen, screen._slot_position(0), true)
	_touch(screen, screen._slot_position(0), false)
	_check(screen.drag_piece == null and st.tray.size() == 9, "a tap does not pick a piece")

	# Wrong drop: piece in slot 0 onto some other cell.
	var piece: int = st.tray[0]
	var wrong_cell := (piece + 1) % 9
	await _drag(screen, 0, wrong_cell)
	_check(st.mistakes == 1 and st.tray.has(piece), "wrong drop: 1 mistake, piece back in the tray")

	# Off the board: no mistake.
	await _drag_to(screen, 0, Vector2(screen.view_size.x * 0.5, screen.board_rect.position.y - 300.0))
	_check(st.mistakes == 1, "drop above the board: no mistake")

	# Right drops for every piece.
	var guard := 0
	while not st.tray.is_empty() and guard < 30:
		guard += 1
		await _drag(screen, 0, st.tray[0])
	_check(st.is_complete(), "all pieces placed by dragging (left %d)" % st.tray.size())
	await get_tree().create_timer(1.8).timeout
	_check(screen.completed and screen.overlay != null, "complete panel shown")
	_check(SaveData.level == 2, "next level unlocked")
	_check(SaveData.coins == 100 + Economy.reward(9, st.stars()), "coins paid (%d)" % SaveData.coins)
	_check(SaveData.current.is_empty(), "finished puzzle is not resumed")
	screen.queue_free()
	await get_tree().process_frame


func _scroll_big_tray() -> void:
	var screen := _new_screen(130) # 8x8 = 64 pieces
	await get_tree().process_frame
	var st := screen.state
	var start := Vector2(screen.view_size.x * 0.7, screen.tray_rect.get_center().y)
	_touch(screen, start, true)
	for i in 10:
		_move(screen, start + Vector2(-40.0 * (i + 1), 2.0), Vector2(-40, 0))
	_touch(screen, start + Vector2(-400, 2), false)
	_check(screen.scroll > 300.0, "sideways swipe scrolls the tray (%.0f)" % screen.scroll)
	_check(st.tray.size() == 64 and screen.drag_piece == null, "scrolling picks nothing")
	# A slanted upward drag still picks the piece (not a scroll).
	var before := screen.scroll
	var p0 := screen._slot_position(3)
	_touch(screen, p0, true)
	_move(screen, p0 + Vector2(60, -50), Vector2(60, -50))
	_check(screen.touch_mode == "drag" and screen.scroll == before, "slanted upward drag picks a piece")
	_move(screen, Vector2(p0.x, -500), Vector2(0, -300))
	_touch(screen, Vector2(p0.x, -500), false) # dropped off the board
	await get_tree().create_timer(0.3).timeout
	_check(st.tray.size() == 64 and st.mistakes == 0, "dropped off the board: back in tray, no mistake")
	# Hints: edges first, then place one with coins.
	SaveData.coins = 100
	screen._on_hint("edges")
	_check(st.is_edge_piece(st.tray[0]) and screen.scroll == 0.0, "edges hint sorts the tray")
	screen._on_hint("place")
	_check(st.placed_count() == 1 and SaveData.coins == 100 - Economy.HINT_PLACE_COST, "place hint costs coins and places one")
	SaveData.coins = 5
	screen._on_hint("place")
	_check(st.placed_count() == 1 and SaveData.coins == 5, "too poor: hint refused")
	screen.queue_free()
	await get_tree().process_frame


## Finishing the same picture/size again pays only a small amount.
func _replay_pays_little() -> void:
	var before := SaveData.coins
	var screen := _new_screen(1)
	await get_tree().process_frame
	for p in screen.state.tray.duplicate():
		screen.state.place_by_hint(p) # no mistakes: same 3 stars as before
	var won := SaveData.finish_puzzle(screen.state)
	_check(won == Economy.replay_reward(9, 3, 3) and SaveData.coins == before + won,
		"replaying level 1 pays the small replay reward (%d)" % won)
	screen.queue_free()
	await get_tree().process_frame


## Peek can't be bought twice while it shows; a drag cut off by the
## system (call, home button) puts the piece back in the tray.
func _peek_and_cancel_drag() -> void:
	SaveData.coins = 100
	var screen := _new_screen(20)
	await get_tree().process_frame
	screen._on_hint("peek")
	_check(SaveData.coins == 100 - Economy.HINT_PEEK_COST and screen.peeking, "peek charged once and showing")
	screen._refresh_hud() # e.g. after a drop
	_check(screen.hint_buttons["peek"].disabled, "peek button stays off while peeking")
	var from := screen._slot_position(0)
	_touch(screen, from, true)
	_move(screen, from + Vector2(0, -200), Vector2(0, -200))
	_check(screen.drag_piece != null, "drag started")
	screen._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().create_timer(0.3).timeout
	_check(screen.drag_piece == null and screen.touch_mode == "", "focus lost: drag cancelled")
	var back := 0
	for p in screen.state.tray:
		if screen.pieces[p].get_parent() == screen.tray_layer:
			back += 1
	_check(back == screen.state.tray.size() and screen.state.mistakes == 0, "piece back in the tray, no mistake")
	screen.queue_free()
	await get_tree().process_frame


## A level put aside for a gallery puzzle comes back with its pieces.
func _parked_level_comes_back() -> void:
	var main: Node = load("res://scenes/main.gd").new()
	var s: PuzzleState = main._level_state(5)
	s.place_by_hint(s.tray[0])
	s.place_by_hint(s.tray[0])
	SaveData.parked = s.to_dict()
	var back: PuzzleState = main._level_state(5)
	_check(back.placed_count() == 2 and SaveData.parked.is_empty(), "parked level 5 resumes with its 2 pieces")
	SaveData.parked = s.to_dict()
	var other: PuzzleState = main._level_state(6)
	_check(other.level == 6 and other.placed_count() == 0, "another level does not take the parked one")
	main.free()


## Drag tray slot `slot` and drop its piece over board cell `cell`.
func _drag(screen: PuzzleScreen, slot: int, cell: int) -> void:
	var target := screen.board_rect.position + screen._cell_center(cell) * screen.board_scale
	await _drag_to(screen, slot, target - screen._lift())


func _drag_to(screen: PuzzleScreen, slot: int, finger_end: Vector2) -> void:
	var from := screen._slot_position(slot)
	_touch(screen, from, true)
	var steps := 8
	var prev := from
	for i in steps:
		var p := from.lerp(finger_end, float(i + 1) / steps)
		_move(screen, p, p - prev)
		prev = p
	_touch(screen, finger_end, false)
	await get_tree().create_timer(0.3).timeout


func _touch(screen: PuzzleScreen, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	screen._unhandled_input(e)


func _move(screen: PuzzleScreen, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	e.velocity = rel * 60.0
	screen._unhandled_input(e)


func _backup_save() -> void:
	for k in ["coins", "level", "best_stars", "current", "parked"]:
		_saved[k] = SaveData.get(k)
	if typeof(_saved["best_stars"]) == TYPE_DICTIONARY:
		_saved["best_stars"] = _saved["best_stars"].duplicate(true)


func _restore_save() -> void:
	for k in _saved:
		SaveData.set(k, _saved[k])
	SaveData.write()
