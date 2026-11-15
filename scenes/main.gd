extends Node
## Entry point: keeps the background and switches screens
## (home → puzzle → home / gallery).
##
## Developer options (after "--" on the command line), e.g.
##   godot --path . -- --screen=puzzle --level=12 --shot=/tmp/a.png
##   --screen=home|gallery|puzzle|puzzle-half|complete
##   --level=<n>       level to open with --screen=puzzle*
##   --lang=<code>     preview a language without saving it
##   --shot=<file>     save a screenshot after ~1.5 s, then quit

var current: Node
var ui_layer: CanvasLayer


## Static gradient behind every screen (drawn once).
class Background extends Node2D:
	func _ready() -> void:
		get_viewport().size_changed.connect(queue_redraw)

	func _draw() -> void:
		var s := get_viewport_rect().size
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
			PackedColorArray([UIKit.BG_TOP, UIKit.BG_TOP, UIKit.BG_BOTTOM, UIKit.BG_BOTTOM]))
		# A few faint jigsaw-like dots for texture.
		for i in 14:
			var p := Vector2(fmod(i * 397.0, s.x), fmod(i * 701.0 + 120.0, s.y))
			draw_circle(p, 40.0 + (i % 4) * 22.0, Color(1, 1, 1, 0.025))


func _ready() -> void:
	add_child(Background.new())
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	Lang.language_changed.connect(_on_language_changed)

	var screen := ""
	var shot := ""
	var level := SaveData.level
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--level="):
			level = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--lang="):
			Lang.apply(arg.trim_prefix("--lang="))
		elif arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	match screen:
		"gallery":
			show_gallery()
		"puzzle", "puzzle-half", "complete":
			var s := _level_state(level)
			if screen != "puzzle":
				# Developer preview: place some (or all but one) pieces.
				var keep := 1 if screen == "complete" else s.piece_count() / 2
				while s.tray.size() > keep:
					s.try_drop(s.tray[0], s.tray[0])
			show_puzzle(s, false)
			if screen == "complete":
				var p: PuzzleScreen = current
				p.call_deferred("_on_hint", "place")
		_:
			show_home()
	if shot != "":
		_take_screenshot(shot)


func _take_screenshot(path: String) -> void:
	await get_tree().create_timer(2.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()


func _level_state(level: int) -> PuzzleState:
	var s := PuzzleState.new()
	var pic := Catalog.picture_for_level(level)
	s.setup(pic["id"], Levels.grid_for_level(level), level, Levels.cut_seed(level))
	return s


func show_home() -> void:
	var home := HomeScreen.new()
	home.play_pressed.connect(_on_play)
	home.gallery_pressed.connect(show_gallery)
	_switch_to(home)


func show_gallery() -> void:
	var g := GalleryScreen.new()
	g.back_pressed.connect(show_home)
	g.start_puzzle.connect(_on_free_play)
	_switch_to(g)


func show_puzzle(s: PuzzleState, save_now: bool = true) -> void:
	if save_now:
		SaveData.current = s.to_dict()
		SaveData.write()
	var p := PuzzleScreen.new()
	p.state = s
	p.exit_to_home.connect(show_home)
	p.play_level.connect(func(l): show_puzzle(_level_state(l)))
	p.open_gallery.connect(show_gallery)
	_switch_to(p)


func _on_play(resume: bool) -> void:
	if resume:
		var s := PuzzleState.new()
		if s.from_dict(SaveData.current) and not Catalog.get_item(s.picture_id).is_empty():
			show_puzzle(s, false)
			return
	show_puzzle(_level_state(SaveData.level))


func _on_free_play(picture_id: String, grid: int) -> void:
	var s := PuzzleState.new()
	s.setup(picture_id, grid, 0, randi() % 1000000 + 1)
	show_puzzle(s)


func _switch_to(screen: Node) -> void:
	if current:
		current.queue_free()
	current = screen
	if screen is Control:
		ui_layer.add_child(screen)
	else:
		add_child(screen)


func _on_language_changed() -> void:
	if current is HomeScreen:
		show_home()
	elif current is GalleryScreen:
		show_gallery()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and current is HomeScreen:
		get_tree().quit()
